class_name HiddenLayer
extends TileMapLayer
## Hidden chambers (Stage E4c): a TileMapLayer marking OPEN-AIR cells that are drawn
## as deep earth until the player digs into them. Celeste's fake walls, but opened by
## digging instead of walking in.
##
## Setup: a TileMapLayer child of a Room, named "Hidden", with this script and the
## earth tileset, painted in the editor over cells that are NOT painted on any other
## layer (a tunnel, a cave). Its collision is switched off (collision_enabled = false):
## a hidden cell is open air the moment it's revealed. In the editor it's tinted
## purple (self_modulate saved by tools/build_earth_rooms.gd) so you can see where
## the chambers are; at runtime the GroundPainter hides its own drawing.
##
## While COVERED, a hidden cell counts as solid earth for everything that asks:
##   - EarthLayer.is_solid(): earth next to it isn't "on the surface", so the bend
##     shadow doesn't crawl along the inside of an unopened chamber
##   - GroundPainter: draws it as earth (deep inside, so it's dark and hatched)
##   - GrassLayer: no blades grow under it (blades are placed once, at the start)
## Keep a chamber away from the room's open air, or the cover would be a wall you can
## walk through (no collision) before anyone dug to it.
##
## Revealing: EarthLayer emits cell_torn(cell) when a rock is torn out. If that
## (now open) cell touches a covered hidden cell, the whole connected chamber (4-way
## neighbours, flood fill) is revealed at once, and its cover CRUMBLES: each cell
## fades out a little after the one before it, spreading from the breach, and drops
## some gravel. The painter draws the fading cover (get_cover_alpha) on top of the
## freshly redrawn ground.
##
## WIDENING THE BREACH (after the E7 play-test, EarthTuning.hidden_widen_breach): the
## player is a tile wide, so a way in only one tile wide is a dead end. Right after a
## reveal, _widen_breach() crumbles the thin fresh earth beside the breach (and beside
## the dug hole, back up to the surface), on whichever side makes a 2-tile-wide way
## in. Only fresh, unhardened earth crumbles (EarthLayer.tear_out): grass, gray rock,
## spent earth and the earth under pillars and stuck rocks stay.
##
## Signals (the painter listens):
##   chamber_revealed(cells)  just before the ground's shape changes: the painter
##                            keeps a copy of the cover's look, to fade it out
##   shape_changed            covered cells became open (a reveal) or covered again
##                            (a reset): redraw the ground
##   crumble_changed          the crumble animation moved on: redraw the cover
## Room reset (death or R) covers every chamber again (we join Room.RESETTABLE_GROUP).
##
## THINGS INSIDE (after Stage E7): any object of the room standing in a covered cell
## (an enemy, spikes, a crate...) is hidden too: invisible and switched off
## (process_mode = DISABLED: it doesn't move, shoot, or collide, since a disabled
## physics body is taken out of the physics world). Each one comes back the moment
## the crumble reaches its cell. A reset hides them again.

## A chamber opened: `cells` (Array[Vector2i]) are open air from now on.
signal chamber_revealed(cells: Array[Vector2i])
## Covered cells opened or closed. See the header.
signal shape_changed
## The crumbling cover's look changed (once per frame while it crumbles).
signal crumble_changed

## Every cell this layer has, -> true while still covered (a set).
var covered_cells: Dictionary = {}
## Crumbling cells -> real seconds until (negative) / since (positive) its fade starts.
var crumble_clocks: Dictionary = {}
## Feel values (crumble timing, gravel). preload() returns the same resource the
## player holds, so Remote-tab edits reach this layer too.
var earth_tuning: EarthTuning = preload("res://resources/earth_tuning.tres")
## Objects hidden inside a covered chamber -> the cell they're in.
var hidden_objects: Dictionary = {}
## The objects placed in the room (not made during play): the only ones that can be
## hidden. Filled by the first hide_objects_in_cover().
var placed_objects: Array[Node2D] = []
var has_collected_placed_objects: bool = false
## The room's EarthLayer (the tears come from it, and the breach is widened in it).
var earth_layer: EarthLayer = null
## True while _widen_breach() tears tiles itself, so those tears don't start another
## widening.
var is_widening: bool = false


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)
	# Hidden cells are open air: never collide, even while covered.
	collision_enabled = false
	_cover_all()
	earth_layer = get_parent().get_node_or_null("Earth") as EarthLayer
	if earth_layer != null:
		earth_layer.cell_torn.connect(_on_cell_torn)
	# Nothing animates until a chamber crumbles (see _process).
	set_process(false)
	# Deferred: the room's other children (enemies...) run their own _ready() first.
	hide_objects_in_cover.call_deferred()


# --- Queries ---------------------------------------------------------------------

## True if `cell` is a hidden cell nobody has dug into yet (drawn and treated as earth).
func is_covered(cell: Vector2i) -> bool:
	return covered_cells.has(cell)


## How opaque the crumbling cover over `cell` is right now: 1 = still whole, 0 = gone.
## 0 for cells that aren't crumbling.
func get_cover_alpha(cell: Vector2i) -> float:
	if not crumble_clocks.has(cell):
		return 0.0
	var time_since_start: float = crumble_clocks[cell]
	return 1.0 - clampf(time_since_start / maxf(earth_tuning.hidden_crumble_time, 0.001), 0.0, 1.0)


## Cells whose cover is still crumbling (the painter draws these).
func get_crumbling_cells() -> Array:
	return crumble_clocks.keys()


# --- Revealing -------------------------------------------------------------------

## EarthLayer tore `cell` out: if it touches a covered chamber, open the chamber.
func _on_cell_torn(cell: Vector2i) -> void:
	if is_widening:
		return
	for direction: Vector2i in EarthLayer.FACE_NORMALS:
		if is_covered(cell + direction):
			reveal_chamber(cell + direction)
			if earth_tuning.hidden_widen_breach:
				_widen_breach(cell, direction)


## The tear at `breach_cell` opened a chamber in `direction` (one of the 4 ways). If
## the way in is only one tile wide, crumble the earth beside it on one side: the
## tile beside the breach, the chamber-side tile beside that, and the tiles beside the
## dug hole on the way back up (cells the rocks tore out, against `direction`). The
## side that needs no non-earth tile opened wins; ties go to the one needing fewer.
func _widen_breach(breach_cell: Vector2i, direction: Vector2i) -> void:
	if earth_layer == null:
		return
	# Across the way in: the two neighbours of the breach, side by side with it.
	var across: Vector2i = Vector2i(absi(direction.y), absi(direction.x))
	var best_cells: Array[Vector2i] = []
	var best_breach_count: int = 1000
	for side: Vector2i in [across, -across]:
		var hole_side: Vector2i = breach_cell + side
		var chamber_side: Vector2i = breach_cell + side + direction
		if _is_open(hole_side) and _is_open(chamber_side):
			return  # already two tiles wide: nothing to do
		# The breach pair must open up, or this side is no good.
		var cells: Array[Vector2i] = []
		var side_works: bool = true
		for cell: Vector2i in [hole_side, chamber_side]:
			if _is_open(cell):
				continue
			if not earth_layer.is_tearable(cell):
				side_works = false
				break
			cells.append(cell)
		if not side_works:
			continue
		var breach_count: int = cells.size()
		# Back up the dug hole: beside each torn cell, as far as earth allows.
		var hole_cell: Vector2i = breach_cell - direction
		while earth_layer.torn_cells.has(hole_cell):
			var beside: Vector2i = hole_cell + side
			if earth_layer.is_tearable(beside):
				cells.append(beside)
			elif not _is_open(beside):
				break  # grass, gray, spent earth: the hole narrows here, stop
			hole_cell -= direction
		if breach_count < best_breach_count:
			best_breach_count = breach_count
			best_cells = cells
	if best_cells.is_empty():
		return
	is_widening = true
	for cell: Vector2i in best_cells:
		if earth_layer.tear_out(cell):
			var center: Vector2 = earth_layer.get_cell_global_center(cell)
			FX.spawn_gravel(center, earth_tuning.hidden_breach_gravel_count, Vector2(direction))
	is_widening = false


## True if `cell` is open air for the player (not earth, not another solid, not a
## covered hidden cell).
func _is_open(cell: Vector2i) -> bool:
	return not earth_layer.is_solid(cell)


## Opens the whole covered chamber containing `start_cell`. Flood fill = BFS over the
## 4-way neighbours (like a Python deque BFS), which also gives every cell its step
## count from the breach: the crumble spreads outward in that order.
func reveal_chamber(start_cell: Vector2i) -> void:
	if not is_covered(start_cell):
		return
	var revealed: Array[Vector2i] = []
	var steps_from_breach: Dictionary = {start_cell: 0}
	var queue: Array[Vector2i] = [start_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		revealed.append(cell)
		for direction: Vector2i in EarthLayer.FACE_NORMALS:
			var neighbour: Vector2i = cell + direction
			if is_covered(neighbour) and not steps_from_breach.has(neighbour):
				steps_from_breach[neighbour] = steps_from_breach[cell] + 1
				queue.append(neighbour)
	# Tell the painter BEFORE the cells open, so it can copy the cover's look.
	chamber_revealed.emit(revealed)
	for cell: Vector2i in revealed:
		covered_cells.erase(cell)
		# Negative = waiting: the fade starts hidden_crumble_step_delay later per step.
		crumble_clocks[cell] = -float(steps_from_breach[cell]) * earth_tuning.hidden_crumble_step_delay
	shape_changed.emit()
	FX.shake(earth_tuning.hidden_crumble_shake_strength, earth_tuning.hidden_crumble_shake_time)
	FX.play_sfx(&"earth_chamber_crumble")
	set_process(true)


## Runs only while a cover crumbles. REAL time, like EarthLayer's fades: a reveal
## happens right after a tear, while the world is still in the rock's slow motion.
func _process(delta: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	var finished_cells: Array[Vector2i] = []
	for cell: Vector2i in crumble_clocks:
		var previous_clock: float = crumble_clocks[cell]
		var clock: float = previous_clock + real_delta
		crumble_clocks[cell] = clock
		# The moment this cell's fade starts, it drops its gravel.
		if previous_clock < 0.0 and clock >= 0.0:
			FX.spawn_gravel(to_global(map_to_local(cell)), earth_tuning.hidden_crumble_gravel_count, Vector2.DOWN)
			_show_objects_in(cell)
		if clock >= earth_tuning.hidden_crumble_time:
			finished_cells.append(cell)
	# Erasing from a Dictionary while looping over it is not allowed: do it after.
	for cell: Vector2i in finished_cells:
		crumble_clocks.erase(cell)
	crumble_changed.emit()
	if crumble_clocks.is_empty():
		set_process(false)


# --- Reset -----------------------------------------------------------------------

## Room reset (Room.reset_objects): every chamber covered again.
func reset() -> void:
	var was_opened: bool = covered_cells.size() != get_used_cells().size()
	crumble_clocks.clear()
	set_process(false)
	_cover_all()
	# Deferred: the objects reset themselves in this same pass (a wisp makes itself
	# visible again), so hide them once every reset() has run.
	hide_objects_in_cover.call_deferred()
	# Redrawing the ground is costly, so only when a chamber was actually opened.
	if was_opened:
		shape_changed.emit()
	crumble_changed.emit()


# --- Things inside ------------------------------------------------------------------

## Hides every object of the room that stands in a covered cell (see the header).
## Public so a test (or an object added later) can ask for it again.
func hide_objects_in_cover() -> void:
	# The first time (right after the room loads), note which objects were PLACED in
	# the room. Only those can be hidden: rocks, pillars and snakes made during play
	# are freed by a reset and must never be held on to.
	if not has_collected_placed_objects:
		has_collected_placed_objects = true
		for child: Node in get_parent().get_children():
			var candidate: Node2D = child as Node2D
			# Not the ground itself, the painter or the pebbles.
			if candidate == null or candidate is TileMapLayer or candidate is GroundPainter \
					or candidate is PebbleField:
				continue
			placed_objects.append(candidate)
	for object: Node2D in placed_objects:
		if not is_instance_valid(object) or object.is_queued_for_deletion():
			continue
		var cell: Vector2i = local_to_map(to_local(_get_object_point(object)))
		if is_covered(cell):
			hidden_objects[object] = cell
			object.visible = false
			object.process_mode = Node.PROCESS_MODE_DISABLED


## A point well inside `object`, to find its cell: the middle of its hitbox if it can
## tell us, else just above its origin (enemies and crates stand on their origin).
func _get_object_point(object: Node2D) -> Vector2:
	if object.has_method(&"get_hitbox_global_rect"):
		return (object.call(&"get_hitbox_global_rect") as Rect2).get_center()
	if object.has_method(&"get_global_rect"):
		return (object.call(&"get_global_rect") as Rect2).get_center()
	if object.has_method(&"get_eye_position"):
		return object.call(&"get_eye_position")
	return object.global_position + Vector2(0.0, -2.0)


## Lets an object added to the room after it loaded (by code, a test) be hidden like
## the placed ones: it's hidden now if it stands in a covered cell, and after resets.
func track_object(object: Node2D) -> void:
	if not placed_objects.has(object):
		placed_objects.append(object)
	hide_objects_in_cover()


## The crumble reached `cell`: the objects hidden there come back.
func _show_objects_in(cell: Vector2i) -> void:
	# Untyped loop variable: a typed one can't even hold a freed object to check it.
	for object in hidden_objects.keys():
		if not is_instance_valid(object):
			hidden_objects.erase(object)
		elif hidden_objects[object] == cell:
			(object as Node2D).visible = true
			(object as Node2D).process_mode = Node.PROCESS_MODE_INHERIT
			hidden_objects.erase(object)


## True if `object` is hidden inside a covered chamber right now.
func is_object_hidden(object: Node2D) -> bool:
	return hidden_objects.has(object)


func _cover_all() -> void:
	covered_cells.clear()
	for cell: Vector2i in get_used_cells():
		covered_cells[cell] = true

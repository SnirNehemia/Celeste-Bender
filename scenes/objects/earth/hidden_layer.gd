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
## Signals (the painter listens):
##   chamber_revealed(cells)  just before the ground's shape changes: the painter
##                            keeps a copy of the cover's look, to fade it out
##   shape_changed            covered cells became open (a reveal) or covered again
##                            (a reset): redraw the ground
##   crumble_changed          the crumble animation moved on: redraw the cover
## Room reset (death or R) covers every chamber again (we join Room.RESETTABLE_GROUP).

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


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)
	# Hidden cells are open air: never collide, even while covered.
	collision_enabled = false
	_cover_all()
	var earth_layer: EarthLayer = get_parent().get_node_or_null("Earth") as EarthLayer
	if earth_layer != null:
		earth_layer.cell_torn.connect(_on_cell_torn)
	# Nothing animates until a chamber crumbles (see _process).
	set_process(false)


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
	for direction: Vector2i in EarthLayer.FACE_NORMALS:
		if is_covered(cell + direction):
			reveal_chamber(cell + direction)


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
	# Redrawing the ground is costly, so only when a chamber was actually opened.
	if was_opened:
		shape_changed.emit()
	crumble_changed.emit()


func _cover_all() -> void:
	covered_cells.clear()
	for cell: Vector2i in get_used_cells():
		covered_cells[cell] = true

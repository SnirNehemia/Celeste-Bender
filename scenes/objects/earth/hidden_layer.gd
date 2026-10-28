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
## Fire opens them too (Stage F6): when an overgrown cover (OvergrownLayer) next to a
## covered cell collapses, the FireGrid calls reveal_chamber() on it. The painter
## then draws the chamber's cover in the look of that overgrown cover (grass or
## thicket), not as earth, so the chamber reads as part of the cover.
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
## Invisible = modulate.a 0, never `visible`: objects use `visible` themselves (a
## defeated wisp hides itself), and showing one again must not bring a dead one back.
## Anything else in a covered cell (a fireball flying in, an orb, a rock) is hidden by
## the GroundPainter's LID, which draws the covered cells over every object.
##
## WALLS OPEN THEM TOO (after Stage W2): a cracked or stone wall breaking beside a
## covered cell calls reveal_chamber(cell, true): an EARTHQUAKE (a stronger, longer
## shake) and pebbles raining onto the chamber's floor. Burnt-through thicket opens
## them like a cover does (FireGrid).
##
## PEEKING (after Stage W2): a chamber that opens straight onto the air can be walked
## into while still covered. While the player's hitbox is inside one of its cells, it
## opens up like a revealed chamber, but softly: the picture CROSS-FADES from the
## covered look to the open one over EarthTuning.hidden_peek_fade_time (eased), over
## the chamber and the ground PEEK_MARGIN cells round it, so its new edges blend in.
## The things inside wake up and fade in with it. When the player leaves, it fades
## back to covered and they're hidden again (by the lid), but keep running (an enemy
## may follow you out: the lid hides it only while it's inside). The painter draws a
## peeked cell as open air, and the old picture (a copy, as for a crumble) over the
## area at get_cover_alpha(). The cells stay covered (is_covered) the whole time: a
## dig still opens them for good.
##
## IN THE LEVEL EDITOR: RoomLook calls open_for_editing(): the chambers show open
## (the painter draws the tunnel, the editor stripes it purple) and nothing inside
## is hidden, so you can see and place what's in there. The play-test copy and the
## saved level are fresh nodes, covered as usual.

## Peeking: how many cells round a chamber also cross-fade, so the ground's new edges
## (crust, outline) blend in instead of popping. The crust is under a tile deep.
const PEEK_MARGIN: int = 1

## A chamber opened: `cells` (Array[Vector2i]) are open air from now on.
signal chamber_revealed(cells: Array[Vector2i])
## Covered cells opened or closed. See the header.
signal shape_changed
## The crumbling cover's look changed (once per frame while it crumbles).
signal crumble_changed
## A covered chamber's cover starts thinning (the player walked in): `cells` will be
## drawn from the cover copy from now on, so the painter copies the picture first.
signal peek_started(cells: Array[Vector2i])

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
## True in the level editor (open_for_editing): never covered, hides nothing.
var is_editing: bool = false
## Each covered cell -> the number of its chamber (connected covered cells), and
## each chamber's cells. Worked out when the chambers are covered (_cover_all).
var chamber_of_cell: Dictionary = {}
var chamber_cells: Dictionary = {}
## Peeked chambers -> how far their cover has thinned, 0 (whole) .. 1 (mist).
## Chambers whose cover is back to whole are dropped.
var peek_amounts: Dictionary = {}
## Each peeked chamber's cross-fade area: its cells and the ground PEEK_MARGIN cells
## round them (whose edges change when it opens). Made when the peek starts.
var peek_regions: Dictionary = {}
## Cells of those areas -> how opaque the old (covered) picture drawn over them is.
var peek_cover_alphas: Dictionary = {}
## Things that were inside a peeked chamber (awake for good): object -> chamber
## number. They fade in and out with its cross-fade while inside it; the lid hides
## them while it's covered.
var veiled_objects: Dictionary = {}


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)
	# Hidden cells are open air: never collide, even while covered.
	collision_enabled = false
	_cover_all()
	earth_layer = get_parent().get_node_or_null("Earth") as EarthLayer
	# Watching for the player walking into a chamber (see PEEKING).
	set_physics_process(true)
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


## How opaque the cover drawn over `cell` is right now: 1 = still whole, 0 = gone.
## A crumbling cell fades out; a peeked chamber (and the ground round it) cross-fades
## to the open look. 0 for other cells.
func get_cover_alpha(cell: Vector2i) -> float:
	if not crumble_clocks.has(cell):
		return peek_cover_alphas.get(cell, 0.0)
	var time_since_start: float = crumble_clocks[cell]
	return 1.0 - clampf(time_since_start / maxf(earth_tuning.hidden_crumble_time, 0.001), 0.0, 1.0)


## Cells whose cover is still crumbling.
func get_crumbling_cells() -> Array:
	return crumble_clocks.keys()


## Every cell the painter draws a cover for (from its copy of the picture): the
## crumbling ones, and the peeked chambers with PEEK_MARGIN cells round them.
func get_cover_cells() -> Array:
	var cells: Array = crumble_clocks.keys()
	for cell: Vector2i in peek_cover_alphas:
		if not crumble_clocks.has(cell):
			cells.append(cell)
	return cells


## How far `cell`'s chamber has thinned to a mist: 0 = not peeked, 1 = all the way.
func get_peek_amount(cell: Vector2i) -> float:
	if not covered_cells.has(cell):
		return 0.0
	return peek_amounts.get(chamber_of_cell.get(cell, -1), 0.0)


## True if `cell` is covered but its chamber is being peeked into: the painter draws
## it as open air (its cover comes from the copy).
func is_peeked(cell: Vector2i) -> bool:
	return covered_cells.has(cell) and peek_amounts.has(chamber_of_cell.get(cell, -1))


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
## count from the breach: the crumble spreads outward in that order. `is_quake`: a
## breaking wall opened it (an earthquake: a bigger shake, pebbles rain down).
func reveal_chamber(start_cell: Vector2i, is_quake: bool = false) -> void:
	if not is_covered(start_cell):
		return
	# A chamber being peeked into: the picture already shows it open.
	var chamber: int = chamber_of_cell.get(start_cell, -1)
	var was_peeked: bool = peek_amounts.has(chamber)
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
	# Tell the painter BEFORE the cells open, so it can copy the cover's look (a
	# peeked chamber already has its copy: the picture shows it open).
	if not was_peeked:
		chamber_revealed.emit(revealed)
	peek_amounts.erase(chamber)
	peek_regions.erase(chamber)
	_update_peek_cover()
	for cell: Vector2i in revealed:
		covered_cells.erase(cell)
		# Negative = waiting: the fade starts hidden_crumble_step_delay later per step.
		crumble_clocks[cell] = -float(steps_from_breach[cell]) * earth_tuning.hidden_crumble_step_delay
	# Things the mist had veiled again come out with the rest of the chamber.
	for object in veiled_objects.keys():  # untyped: it may hold a freed object
		if veiled_objects[object] == chamber:
			if is_instance_valid(object):
				(object as Node2D).modulate.a = 1.0
			veiled_objects.erase(object)
	shape_changed.emit()
	if is_quake:
		FX.shake(earth_tuning.hidden_quake_shake_strength, earth_tuning.hidden_quake_shake_time)
		_rain_pebbles(revealed)
	else:
		FX.shake(earth_tuning.hidden_crumble_shake_strength, earth_tuning.hidden_crumble_shake_time)
	FX.play_sfx(&"earth_chamber_crumble")
	set_process(true)


## The earthquake's pebbles: from the ceiling of each opened cell standing on
## something (its cell below isn't part of the chamber), so they land on its floor.
func _rain_pebbles(cells: Array[Vector2i]) -> void:
	var cell_set: Dictionary = {}
	for cell: Vector2i in cells:
		cell_set[cell] = true
	var half_tile: float = tile_set.tile_size.y / 2.0
	for cell: Vector2i in cells:
		if cell_set.has(cell + Vector2i.DOWN):
			continue
		var ceiling: Vector2 = to_global(map_to_local(cell)) + Vector2(0.0, -half_tile + 1.0)
		for pebble_number: int in earth_tuning.hidden_quake_pebbles_per_cell:
			PebbleField.leave_one_pebble(get_tree(), ceiling + Vector2(randf_range(-3.0, 3.0), 0.0), Vector2.DOWN)


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


# --- Peeking ---------------------------------------------------------------------

## Every physics frame: which covered chambers the player is in, and each peeked
## chamber cross-fading toward the open look (player in) or back to covered (out).
func _physics_process(delta: float) -> void:
	if is_editing or (covered_cells.is_empty() and peek_amounts.is_empty()):
		return
	if not hidden_objects.is_empty():
		_wake_chambers_with_intruders()
	var inside: Dictionary = _chambers_the_player_is_in()
	var fade_step: float = delta / maxf(earth_tuning.hidden_peek_fade_time, 0.001)
	var look_changed: bool = false
	for chamber: int in inside:
		if not peek_amounts.has(chamber):
			_start_peek(chamber)
		if peek_amounts[chamber] < 1.0:
			peek_amounts[chamber] = minf(peek_amounts[chamber] + fade_step, 1.0)
			look_changed = true
	for chamber: int in peek_amounts.keys():
		if inside.has(chamber):
			continue
		peek_amounts[chamber] -= fade_step
		look_changed = true
		if peek_amounts[chamber] <= 0.0:
			_end_peek(chamber)
	if look_changed:
		_update_peek_cover()
		crumble_changed.emit()


## WAKING (after the lid): something from outside (a fireball, an orb, a rock, a
## snake) inside a chamber whose things are still switched off wakes them up, still
## hidden under the lid, so a blind shot into a dark hole can hit what's in there.
## One physics query per such chamber: every body and area overlapping its bounding
## box; only those whose middle is in one of its covered cells count (the box also
## catches the ground and walls round it).
func _wake_chambers_with_intruders() -> void:
	var sleeping: Dictionary = {}  # chamber number -> true, a set
	for object in hidden_objects.keys():  # untyped: it may hold a freed object
		if is_instance_valid(object):
			sleeping[chamber_of_cell.get(hidden_objects[object], -1)] = true
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var player: Node = get_tree().get_first_node_in_group(Player.GROUP)
	for chamber: int in sleeping:
		if not chamber_cells.has(chamber) or peek_amounts.has(chamber):
			continue
		var cells: Array = chamber_cells[chamber]
		var bounds: Rect2i = Rect2i(cells[0], Vector2i.ONE)
		for cell: Vector2i in cells:
			bounds = bounds.expand(cell).expand(cell + Vector2i.ONE)
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(bounds.size * tile_set.tile_size)
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0.0, to_global(Vector2(bounds.position * tile_set.tile_size) + shape.size / 2.0))
		query.collide_with_areas = true
		for hit: Dictionary in space.intersect_shape(query, 16):
			var intruder: Node2D = hit.collider as Node2D
			if intruder == null or intruder == player or intruder is TileMapLayer:
				continue
			var cell: Vector2i = local_to_map(to_local(_get_object_point(intruder)))
			if covered_cells.has(cell) and chamber_of_cell.get(cell, -1) == chamber:
				_wake_chamber(chamber)
				break


## Switches `chamber`'s things on (they keep running from now on, like after a peek),
## shown at full: the lid hides them while they're inside.
func _wake_chamber(chamber: int) -> void:
	for object in hidden_objects.keys():  # untyped: it may hold a freed object
		if not is_instance_valid(object):
			hidden_objects.erase(object)
		elif chamber_of_cell.get(hidden_objects[object], -1) == chamber:
			(object as Node2D).process_mode = Node.PROCESS_MODE_INHERIT
			(object as Node2D).modulate.a = 1.0
			hidden_objects.erase(object)
			veiled_objects[object] = chamber


## How far along a peek's cross-fade is, eased (slow start and end, no pop).
func _get_peek_ease(chamber: int) -> float:
	return smoothstep(0.0, 1.0, peek_amounts.get(chamber, 0.0))


## Works out peek_cover_alphas from every peeked chamber's area and progress, and
## fades the things inside in or out with it.
func _update_peek_cover() -> void:
	peek_cover_alphas.clear()
	for chamber: int in peek_regions:
		var alpha: float = 1.0 - _get_peek_ease(chamber)
		for cell: Vector2i in peek_regions[chamber]:
			# A cell in two areas shows the more open of the two.
			peek_cover_alphas[cell] = minf(peek_cover_alphas.get(cell, 1.0), alpha)
	for object in veiled_objects.keys():  # untyped: it may hold a freed object
		if is_instance_valid(object) and peek_amounts.has(veiled_objects[object]):
			(object as Node2D).modulate.a = _get_veiled_alpha(object, veiled_objects[object])


## How opaque a veiled `object` is while `chamber` cross-fades: with the fade while it's
## inside the chamber, fully shown once it walked out.
func _get_veiled_alpha(object: Node2D, chamber: int) -> float:
	var cell: Vector2i = local_to_map(to_local(_get_object_point(object)))
	if chamber_of_cell.get(cell, -1) != chamber or not covered_cells.has(cell):
		return 1.0
	return _get_peek_ease(chamber)


## The chamber's cells and the cells within PEEK_MARGIN of them (the cross-fade area).
func _get_peek_region(chamber: int) -> Array[Vector2i]:
	var region: Dictionary = {}
	# Only cells inside the room: the painter's picture ends at its edges.
	var room_cells: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.MAX)
	var room: Room = get_parent() as Room
	if room != null:
		room_cells.size = Vector2i((room.room_size / Vector2(tile_set.tile_size)).ceil())
	for cell: Vector2i in chamber_cells[chamber]:
		for x: int in range(-PEEK_MARGIN, PEEK_MARGIN + 1):
			for y: int in range(-PEEK_MARGIN, PEEK_MARGIN + 1):
				if room_cells.has_point(cell + Vector2i(x, y)):
					region[cell + Vector2i(x, y)] = true
	var cells: Array[Vector2i] = []
	cells.assign(region.keys())
	return cells


## The chambers (numbers, as a set) with a covered cell overlapping the player's hitbox.
func _chambers_the_player_is_in() -> Dictionary:
	var inside: Dictionary = {}
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead() or not player.is_inside_tree():
		return inside
	var hitbox: Rect2 = player.get_hitbox_rect()
	# The cells under the hitbox (shrunk a hair, so touching a cell's edge from
	# outside doesn't count as being in it).
	var first: Vector2i = local_to_map(to_local(hitbox.position + Vector2.ONE * 0.5))
	var last: Vector2i = local_to_map(to_local(hitbox.end - Vector2.ONE * 0.5))
	for x: int in range(first.x, last.x + 1):
		for y: int in range(first.y, last.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if covered_cells.has(cell):
				inside[chamber_of_cell[cell]] = true
	return inside


## The player walked into `chamber`: the painter copies the picture (covered look),
## the ground is redrawn with the chamber open, and the copy is drawn over the
## chamber and its edges, fading out (_update_peek_cover): a cross-fade from the
## covered look to the open one. What's inside shows, waking up and fading in.
func _start_peek(chamber: int) -> void:
	var region: Array[Vector2i] = _get_peek_region(chamber)
	peek_started.emit(region)  # BEFORE the picture changes
	peek_amounts[chamber] = 0.0
	peek_regions[chamber] = region
	_update_peek_cover()
	shape_changed.emit()
	for object in hidden_objects.keys():  # untyped: it may hold a freed object
		if not is_instance_valid(object):
			hidden_objects.erase(object)
		elif chamber_of_cell.get(hidden_objects[object], -1) == chamber:
			(object as Node2D).process_mode = Node.PROCESS_MODE_INHERIT
			hidden_objects.erase(object)
			veiled_objects[object] = chamber
	# They fade in with the cross-fade (they were at 0, or under the lid).
	for object in veiled_objects.keys():
		if is_instance_valid(object) and veiled_objects[object] == chamber:
			(object as Node2D).modulate.a = _get_veiled_alpha(object, chamber)


## The cross-fade back is done after the player left: the picture is redrawn covered
## (it looks just like the copy that was fading in), and the lid covers the chamber
## again, hiding what's inside (which keeps running, shown at full: it's under the
## lid, and seen again if it walks out).
func _end_peek(chamber: int) -> void:
	peek_amounts.erase(chamber)
	peek_regions.erase(chamber)
	_update_peek_cover()
	shape_changed.emit()
	for object in veiled_objects.keys():
		if not is_instance_valid(object):
			veiled_objects.erase(object)
		elif veiled_objects[object] == chamber:
			(object as Node2D).modulate.a = 1.0


# --- Reset -----------------------------------------------------------------------

## Room reset (Room.reset_objects): every chamber covered again.
func reset() -> void:
	if is_editing:
		return
	var was_opened: bool = covered_cells.size() != get_used_cells().size() or not peek_amounts.is_empty()
	crumble_clocks.clear()
	peek_amounts.clear()
	peek_regions.clear()
	peek_cover_alphas.clear()
	# Everything shows again (objects don't reset their own modulate);
	# hide_objects_in_cover (below) hides and switches off the ones back in a covered
	# cell after their own reset.
	for object in veiled_objects.keys() + hidden_objects.keys():  # untyped: may hold freed objects
		if is_instance_valid(object):
			(object as Node2D).modulate.a = 1.0
			(object as Node2D).process_mode = Node.PROCESS_MODE_INHERIT
	veiled_objects.clear()
	hidden_objects.clear()
	set_process(false)
	_cover_all()
	# Deferred: the objects reset themselves in this same pass (a wisp walks back to
	# its start), so hide them once every reset() has run.
	hide_objects_in_cover.call_deferred()
	# Redrawing the ground is costly, so only when a chamber was actually opened.
	if was_opened:
		shape_changed.emit()
	crumble_changed.emit()


# --- Things inside ------------------------------------------------------------------

## Hides every object of the room that stands in a covered cell (see the header).
## Public so a test (or an object added later) can ask for it again.
func hide_objects_in_cover() -> void:
	if is_editing:
		return
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
			object.modulate.a = 0.0
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
			(object as Node2D).modulate.a = 1.0
			(object as Node2D).process_mode = Node.PROCESS_MODE_INHERIT
			hidden_objects.erase(object)


## True if `object` is hidden inside a covered chamber right now.
func is_object_hidden(object: Node2D) -> bool:
	return hidden_objects.has(object)


## The level editor (RoomLook): every chamber open for good, everything hidden in
## one shown again. Safe to call again after the cells change.
func open_for_editing() -> void:
	is_editing = true
	covered_cells.clear()
	crumble_clocks.clear()
	peek_amounts.clear()
	peek_regions.clear()
	peek_cover_alphas.clear()
	for object in veiled_objects.keys():  # untyped: it may hold a freed object
		if is_instance_valid(object):
			(object as Node2D).modulate.a = 1.0
	veiled_objects.clear()
	set_process(false)
	for object in hidden_objects.keys():  # untyped: it may hold a freed object
		if is_instance_valid(object):
			(object as Node2D).modulate.a = 1.0
			(object as Node2D).process_mode = Node.PROCESS_MODE_INHERIT
	hidden_objects.clear()


func _cover_all() -> void:
	covered_cells.clear()
	for cell: Vector2i in get_used_cells():
		covered_cells[cell] = true
	_number_chambers()


## Numbers the chambers: each connected group of covered cells (4-way flood fill).
func _number_chambers() -> void:
	chamber_of_cell.clear()
	chamber_cells.clear()
	var next_chamber: int = 0
	for start: Vector2i in covered_cells:
		if chamber_of_cell.has(start):
			continue
		var cells: Array[Vector2i] = [start]
		chamber_of_cell[start] = next_chamber
		var index: int = 0
		while index < cells.size():
			var cell: Vector2i = cells[index]
			index += 1
			for direction: Vector2i in EarthLayer.FACE_NORMALS:
				var neighbour: Vector2i = cell + direction
				if covered_cells.has(neighbour) and not chamber_of_cell.has(neighbour):
					chamber_of_cell[neighbour] = next_chamber
					cells.append(neighbour)
		chamber_cells[next_chamber] = cells
		next_chamber += 1

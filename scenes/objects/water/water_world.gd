class_name WaterWorld
extends Node2D
## WaterWorld (Stage W1, Water_bending.md §6): ALL the water of one room. It is the
## only node that moves water: every pool, puddle and falling drop of the room lives
## in it as plain data (packed arrays), never as one node per drop, which is what
## keeps water cheap enough for GDScript (§6.5).
##
## Made by Room._ready() in rooms that have a "Water" layer (WaterLayer), like the
## FireGrid. It sits at the room's origin, so its local coordinates are the room's.
## It joins Room.RESETTABLE_GROUP: death or R puts the painted water back.
##
## THE TWO FORMS OF WATER IN W1 (the third, held water, comes with the bending):
##   - BODIES (WaterBody, water_body.gd): pools and puddles as height fields, stepped
##     with the pipe model. Read water_body.gd's header for the physics.
##   - PARTICLES ("drops" in the code): loose water (a spill pouring over a lip, a
##     thrown ball, a waterfall, a splash crown). Each is a point with a velocity and
##     some water (px², 1/16 unit). Stage W2 (§6.1 part 2): gravity, air drag,
##     COHESION with their neighbours (WaterCohesion: a ball stays round, a pour
##     beads), collision with the tiles (they run down walls a little slowly) and
##     with moving solids (crates, the player: the "water_solid" group, boxes from
##     get_water_box()). One that falls into a body's water merges into it and kicks
##     a wave (or, fast, bounces back up as part of a splash CROWN); one that lands on
##     bare ground soaks into it if it's absorbent (earth, grass: up to
##     `soak_per_tile` a tile, the "wet" stub of W8), else starts a puddle there (or
##     grows the puddle next to it). They're drawn by the WaterRenderer child as
##     metaballs (soft dots merged by a threshold shader).
##   - SOURCES and SINKS (WaterSource, WaterSink; §6.2): endless water poured in at
##     a rate, and drains that take it away. Streams and waterfalls are just bodies
##     and particles fed by a source.
##
## WHERE A BODY'S ENDS ARE (_update_end, every frame for awake bodies). Look just
## past the end column, at the height of the water's surface:
##   - solid there (or outside the room): a WALL, nothing leaves.
##   - open, with ground at most `spill_drop` px lower than this end's floor (or
##     higher, but under the surface): the water can flow on, so the body GROWS a
##     column there (or MERGES with the body already lying there).
##   - open, with the ground further down: a lip over a drop. The end SPILLS: water
##     pours over it as drops (WaterBody's spill pipes + _release_spills).
## So water runs down a staircase, spreads into puddles, overflows a tank's rim and
## joins up with other water by itself, with no special objects.
##
## SLEEP: a body whose water has stopped moving is put to sleep and skipped until
## something touches it (a drop, a push, the debug keys, a reset). Most pools in a
## room are calm most of the time, so they cost nothing.
##
## THE BOOKS: water is conserved (Water_bending.md §4.1). get_total_units() is all the
## water in the bodies and drops; water in the hands is `held_area`, frozen into ice
## `ice_area` (Stage W5); water that falls out of the room or is trimmed as
## crumbs goes into `lost_area`, soaked into tiles into `soaked_area`, down a sink
## into `drained_area`, and a source's water is counted in `sourced_area`.
## get_books_units() (total + lost + soaked + drained - sourced) never changes: the
## smoke test checks it.
##
## COST: `last_step_usec` / `peak_step_usec` time the whole step; the smoke test's
## performance section holds them to the 2 ms budget of §6.5.
##
## Time: game time (physics delta), so slow motion slows the water. Only the room on
## screen moves its water (RoomManager also freezes far rooms outright).
##
## Debug keys (W1, while play-testing the simulation), on the top-row digits: 8
## `debug_water_wave` pokes the water under the player, 9 `debug_water_dump` drops a
## bucket over the player's head, 0 `debug_water_drain` takes a bucket from the water
## nearest the player. 6 `debug_water_throw` throws a ball of water in the arrow
## direction (W2). 7 `debug_water_look` cycles the look (B, C, A, B+C). (Not F6-F10: the Godot editor's embedded Game view takes F7
## as pause and F8 as stop, even while the game has the focus.)

const GROUP: StringName = &"water_world"
## Moving solids that particles bump into (crates, the player) join this group and
## have get_water_box() -> Rect2 (global; size 0 = not solid right now).
const SOLID_GROUP: StringName = &"water_solid"
const NODE_NAME: StringName = &"WaterWorld"
const TILE: int = 8
## One unit of water (Water_bending.md §4.1): one 8x8 tile full, px².
const UNIT_AREA: float = 64.0
## The look (Water_bending.md §12.1): this shader colors every pixel of the water.
## _draw() hands it depth, foam and "what is this" in each corner's color (read the
## shader's header); the colors and strengths are its uniforms, fed from WaterTuning.
const WATER_SHADER: Shader = preload("res://scenes/objects/water/water.gdshader")
## What _draw() puts in a corner's blue channel, for the shader: a body, its surface
## line, or a drop / spray speck.
const KIND_BODY: float = 0.0
const KIND_WET: float = 0.25
const KIND_SURFACE: float = 0.5
const KIND_DROP: float = 1.0
## The depth in a corner's red channel is px / this (the shader multiplies it back).
const DEPTH_ENCODE_PX: float = 64.0
## The looks (WaterTuning.look_style), for the debug overlay and the console.
const LOOK_NAMES: Array[String] = ["B: see-through", "C: pixel bands", "A: plain", "B+C: blend"]
## Columns shallower than this aren't drawn (a dry film), px.
const DRAWN_MIN_DEPTH: float = 0.3
## Most drops one spilling end releases in one frame (spreads a big release over a
## few frames instead of one spike).
const MAX_DROPS_PER_SPILL_FRAME: int = 12
## A drop that hits a wall sideways keeps this much of its speed, bouncing back.
const DROP_WALL_BOUNCE: float = 0.2
## Spawned drops get this much random speed, px/s, so a bucket isn't one column.
const DROP_JITTER_SPEED: float = 20.0
## The surface of two neighbouring wet columns may differ this much, px, and the body
## still counts as level (one of the sleep conditions).
const LEVEL_TOLERANCE: float = 0.1
## Particle cohesion runs once every this many physics frames (see _physics_process).
const COHESION_EVERY: int = 2
## Soaking wicks into absorbent tiles up to this many tiles beside a full one.
const SOAK_REACH: int = 2
## A tile with less room left than this, px², counts as full: float crumbs left by
## the last fill would otherwise keep it "open" (and keep paying for it) forever.
const SOAK_FULL_SLACK: float = 0.0001
## A breaking crest's rise is averaged over this many columns each side (_break_crests).
const CREST_HALF_WIDTH: int = 2
## A poke (key 8, poke()) pushes the water over this many px each side of the point.
const POKE_RADIUS: float = 8.0
## A loose drop (or a dot of the held ball) touches things this close, px
## (is_water_near): about the size it's drawn.
const DROP_TOUCH_RADIUS: float = 2.0
## Two drops of one stream are joined (take_loose_near) up to the distance the faster
## moves in this many seconds, on top of freeze_join_distance (W5).
const STREAM_JOIN_TIME: float = 0.06
## The crystal finds the pool under its hit this much higher, px: a surface can sit a
## hair under the point where it touched the water (W5).
const SHEET_PROBE_LIFT: float = 2.0

## preload() returns the same resource object the player holds, so F5 panel edits
## reach the water at once.
var water_tuning: WaterTuning = preload("res://resources/water_tuning.tres")
var room: Room
var water_layer: WaterLayer
var earth_layer: EarthLayer
var grass_layer: GrassLayer
## Draws the particles as metaballs (a child, made in _ready).
var renderer: WaterRenderer
## The room's tile layers that are solid ground (every TileMapLayer but the water and
## hidden chambers).
var solid_layers: Array[TileMapLayer] = []
## Room size in tiles, and one byte per tile: 1 = solid. Built once in _ready (W1:
## nothing in a water room changes its tiles yet; bending will call refresh_solid_cells).
var grid_size: Vector2i = Vector2i.ZERO
var solid_cells: PackedByteArray = PackedByteArray()
## One byte per tile too: 1 = absorbent (earth, grass), it soaks water up (W2 stub).
var absorbent_cells: PackedByteArray = PackedByteArray()
## Width of every column of every body, px: TILE divided into whole columns, so
## columns always line up with the tiles and with each other.
var column_width: float = 2.0
var bodies: Array[WaterBody] = []
## The drops, one entry per drop in each array (index i is the same drop).
var drop_positions: PackedVector2Array = PackedVector2Array()
var drop_velocities: PackedVector2Array = PackedVector2Array()
var drop_areas: PackedFloat32Array = PackedFloat32Array()
## Each drop's foam from a hit, 0..1: set to 1 when it bounces off something or is
## thrown off a splash or a breaking wave, fades over particle_foam_life. Only a
## look (the WaterRenderer draws it white); its speed adds foam on top.
var drop_foam: PackedFloat32Array = PackedFloat32Array()
## Each drop's THROW GROUP (Stage W5): the id of the release that let it go (the
## hands' throws, the debug throw), 0 for any other water (spills, sources, splashes
## of a pool). The freeze finds "the water you last threw" by it (see THROW GROUPS).
var drop_groups: PackedInt32Array = PackedInt32Array()
## The group new drops get (_spawn_drop): set around a release, else 0.
var spawn_group: int = 0
## The newest throw group: its id, how much water it let go, px² (a snake's ribbon
## adds to it while it feeds out), and the game time it was let go (s, `game_time`).
var last_group_id: int = 0
var last_group_area: float = 0.0
var last_group_time: float = -1000.0
## Game seconds since the room started (scaled by slow motion like the water).
var game_time: float = 0.0
## Water that left the room or was trimmed away as crumbs, px² (see THE BOOKS).
var lost_area: float = 0.0
## Water soaked into tiles, poured in by sources, taken by sinks, px² (THE BOOKS).
var soaked_area: float = 0.0
var sourced_area: float = 0.0
var drained_area: float = 0.0
## Soaking: water soaked into each absorbent tile so far, px² (cell -> area). A
## tile holding soak_per_tile is WET (is_wet); the stub of W8's wet layer.
var soaked_cells: Dictionary = {}
## The same amounts, one float per tile (y * grid_size.x + x): what the soak loop
## reads every frame, since a packed array read is much cheaper than a Dictionary
## lookup. soaked_cells stays the one the drawing and is_wet() read.
var soaked_per_cell: PackedFloat64Array = PackedFloat64Array()
## One byte per tile: 1 = absorbent and it or an absorbent tile within SOAK_REACH in
## its row can still take water. A column over a 0 tile skips soaking with one read
## (SPEED: pools on saturated grass used to redo the whole soak every frame, §6.5).
var soak_open: PackedByteArray = PackedByteArray()
## The tile capacity, px², soak_open was built for: an F5 change to soak_per_tile
## rebuilds it.
var soak_open_capacity: float = -1.0
## Moving solids the particles bump into this frame (crates, the player), room-local.
var solid_boxes: Array[Rect2] = []
## How many particles bounced up out of a pool this frame and in all (splash crowns).
var crown_count: int = 0
## Particles thrown off breaking crests since the room started (tests, debug).
var crest_break_count: int = 0
## Water in the player's hands (Stage W3), px²: taken out of this room's water by
## gather(), put back by release_held(). The books count it, so holding water
## changes nothing in them.
var held_area: float = 0.0
## How many resets so far: water still flying from the hands (a snake's ribbon)
## checks it, since a reset empties held_area.
var reset_count: int = 0
## The held ball as dots (room-local), drawn with the particles: by the WaterRenderer
## as metaballs, or as squares in the fallback. Set by WaterHandsAbility every frame
## (set_held_dots); empty when nothing is held.
var held_dots: PackedVector2Array = PackedVector2Array()
## Where the last gather() took water from (room-local); nothing draws it since
## the hands' tendril was removed (play-test 4), kept for debugging.
var last_gather_point: Vector2 = Vector2.ZERO
## How much water the painted tiles held when the room loaded, px².
var initial_area: float = 0.0
var last_step_usec: int = 0
var peak_step_usec: int = 0
## The same, split: the bodies' pipes and ripples, and the drops (for tuning cost).
var last_bodies_usec: int = 0
var last_drops_usec: int = 0
## Of last_drops_usec, the cohesion pass alone.
var last_cohesion_usec: int = 0
## Counts physics frames for the every-other-frame cohesion pass.
var cohesion_frame: int = 0
## Spray: white specks with no water in them, only a look (Water_bending.md §12,
## play-test 1 "foam and spray"). Same layout as the drops: index i is one speck.
var spray_positions: PackedVector2Array = PackedVector2Array()
var spray_velocities: PackedVector2Array = PackedVector2Array()
var spray_life: PackedFloat32Array = PackedFloat32Array()
## Was any of the player in water last frame (crossing the surface makes a splash)?
var player_was_in_water: bool = false
## Ice made by freezing (Stage W5): IceBlock and IcePiece nodes, oldest first (the
## ice cap melts the oldest), and the water frozen in them, px² (THE BOOKS).
var player_ice: Array[Node] = []
var ice_area: float = 0.0
## For tests and the overlay: freezes so far, and the last ice made.
var freeze_count: int = 0
var last_ice: Node = null
## Every piece the last freeze_particles() made (a splash freezes into several), and
## the id the next freeze gets (the ice cap counts freezes: _register_ice).
var last_freeze_pieces: Array[Node] = []
var freeze_id_counter: int = 0
## While freeze_particles() makes its pieces, the freeze id they share; else -1.
var current_freeze_id: int = -1


func _ready() -> void:
	room = get_parent() as Room
	water_layer = room.get_node_or_null("Water") as WaterLayer
	earth_layer = room.get_node_or_null("Earth") as EarthLayer
	grass_layer = room.get_node_or_null("Grass") as GrassLayer
	for child: Node in room.get_children():
		if child is TileMapLayer and not child is HiddenLayer and not child is WaterLayer:
			solid_layers.append(child)
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	z_index = 1  # in front of the player and crates: what's under water looks under water
	# A ShaderMaterial runs a shader for everything this node draws. Each room's
	# WaterWorld gets its own (they could share one; it's tiny either way).
	var water_material: ShaderMaterial = ShaderMaterial.new()
	water_material.shader = WATER_SHADER
	material = water_material
	_update_shader_parameters()
	renderer = WaterRenderer.new()
	renderer.name = "WaterRenderer"
	add_child(renderer)
	if water_layer != null:
		# The tiles only said where the water starts; from now on we draw it.
		water_layer.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	column_width = TILE / float(maxi(1, roundi(TILE / water_tuning.column_width)))
	refresh_solid_cells()
	_build_bodies_from_layer()


## The WaterWorld of the room containing `world_position`, or null.
## Static: called on the class, WaterWorld.find_at(get_tree(), point).
static func find_at(tree: SceneTree, world_position: Vector2) -> WaterWorld:
	for member: Node in tree.get_nodes_in_group(GROUP):
		var world: WaterWorld = member as WaterWorld
		if world != null and world.room.get_bounds().has_point(world_position):
			return world
	return null


# --- Tiles ------------------------------------------------------------------------

## Reads which tiles are solid into `solid_cells`. Call again if tiles change.
func refresh_solid_cells() -> void:
	grid_size = Vector2i((room.room_size / TILE).ceil())
	solid_cells.resize(grid_size.x * grid_size.y)
	solid_cells.fill(0)
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			if _is_solid_cell_in_layers(Vector2i(x, y)):
				solid_cells[y * grid_size.x + x] = 1
	# Old-style test rooms list solid blocks as rectangles instead of tiles.
	absorbent_cells.resize(grid_size.x * grid_size.y)
	absorbent_cells.fill(0)
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			if solid_cells[y * grid_size.x + x] == 1 and is_absorbent(Vector2i(x, y)):
				absorbent_cells[y * grid_size.x + x] = 1
	for rect: Rect2 in room.solid_rects:
		var first: Vector2i = Vector2i((rect.position / TILE).floor())
		var last: Vector2i = Vector2i((rect.end / TILE).ceil()) - Vector2i.ONE
		for y: int in range(maxi(first.y, 0), mini(last.y + 1, grid_size.y)):
			for x: int in range(maxi(first.x, 0), mini(last.x + 1, grid_size.x)):
				solid_cells[y * grid_size.x + x] = 1
	if soaked_per_cell.size() != grid_size.x * grid_size.y:
		soaked_per_cell.resize(grid_size.x * grid_size.y)
		soaked_per_cell.fill(0.0)
	_rebuild_soak_open()


func _is_solid_cell_in_layers(cell: Vector2i) -> bool:
	if earth_layer != null:
		return earth_layer.is_solid(cell)  # it knows every tile layer and the columns
	for layer: TileMapLayer in solid_layers:
		if layer.get_cell_source_id(cell) != -1:
			return true
	return false


## Is the room-local point (x, y) inside solid ground? Past the room's sides and
## bottom counts as solid (water stays in its room); above the top is open air.
func is_solid_px(x: float, y: float) -> bool:
	if x < 0.0 or x >= room.room_size.x:
		return true
	if y < 0.0:
		return false
	var cell_x: int = int(x / TILE)
	var cell_y: int = int(y / TILE)
	if cell_x >= grid_size.x or cell_y >= grid_size.y:
		return true
	return solid_cells[cell_y * grid_size.x + cell_x] == 1


## The top of the first solid tile at or below `from_y` in the pixel column `x`
## (the floor water there would rest on), px.
func floor_below(x: float, from_y: float) -> float:
	var start_row: int = maxi(floori(from_y / TILE), 0)
	for row: int in range(start_row, grid_size.y):
		if is_solid_px(x, row * TILE + 0.5):
			return row * TILE
	return grid_size.y * TILE


## The bottom of the first solid tile above `from_y` in the pixel column `x`, or
## WaterBody.NO_CEILING if it's open to the sky.
func ceiling_above(x: float, from_y: float) -> float:
	var row: int = floori((from_y - 0.5) / TILE)
	while row >= 0:
		if is_solid_px(x, row * TILE + 0.5):
			return (row + 1) * TILE
		row -= 1
	return WaterBody.NO_CEILING


# --- Building the bodies ------------------------------------------------------------

## Turns the painted water tiles into bodies: one per connected patch (4-neighbour
## flood fill). Each tile is one unit of water; in each column it settles on the
## floor under the patch's lowest tile there.
func _build_bodies_from_layer() -> void:
	bodies.clear()
	drop_positions.clear()
	drop_velocities.clear()
	drop_areas.clear()
	drop_foam.clear()
	drop_groups.clear()
	lost_area = 0.0
	if water_layer == null:
		initial_area = 0.0
		return
	var unvisited: Dictionary = {}
	for cell: Vector2i in water_layer.get_used_cells():
		# Water painted inside rock isn't water.
		if not is_solid_px(cell.x * TILE + 0.5, cell.y * TILE + 0.5):
			unvisited[cell] = true
	while not unvisited.is_empty():
		var start: Vector2i = unvisited.keys()[0]
		var patch: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		unvisited.erase(start)
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			patch.append(cell)
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbour: Vector2i = cell + step
				if unvisited.has(neighbour):
					unvisited.erase(neighbour)
					queue.append(neighbour)
		bodies.append(_make_body_from_patch(patch))
	initial_area = get_total_area()


func _make_body_from_patch(patch: Array[Vector2i]) -> WaterBody:
	# Tile column -> its rows in the patch.
	var rows_by_column: Dictionary = {}
	var first_column: int = patch[0].x
	var last_column: int = patch[0].x
	for cell: Vector2i in patch:
		if not rows_by_column.has(cell.x):
			rows_by_column[cell.x] = []
		(rows_by_column[cell.x] as Array).append(cell.y)
		first_column = mini(first_column, cell.x)
		last_column = maxi(last_column, cell.x)
	var body: WaterBody = WaterBody.new()
	body.column_width = column_width
	body.left_x = first_column * TILE
	var columns_per_tile: int = roundi(TILE / column_width)
	# A patch is connected, so every tile column between its ends has water.
	for tile_column: int in range(first_column, last_column + 1):
		var rows: Array = rows_by_column[tile_column]
		var top_y: float = float(rows.min()) * TILE
		var bottom_y: float = (float(rows.max()) + 1.0) * TILE
		for sub_column: int in columns_per_tile:
			var center_x: float = tile_column * TILE + (sub_column + 0.5) * column_width
			var column_floor: float = floor_below(center_x, bottom_y - 0.5)
			body.add_column(column_floor, ceiling_above(center_x, top_y), rows.size() * TILE, false)
	return body


# --- The books ----------------------------------------------------------------------

## All the water in the room right now, px² (bodies, water waiting to spill, drops).
func get_total_area() -> float:
	var total: float = 0.0
	for body: WaterBody in bodies:
		total += body.get_area()
	for area: float in drop_areas:
		total += area
	return total


func get_total_units() -> float:
	return get_total_area() / UNIT_AREA


func get_initial_units() -> float:
	return initial_area / UNIT_AREA


func get_lost_units() -> float:
	return lost_area / UNIT_AREA


## Everything the books know about: what's here, plus what left (lost, soaked,
## drained), minus what sources added. Never changes (the smoke test checks).
func get_books_units() -> float:
	return (get_total_area() + held_area + ice_area + lost_area + soaked_area + drained_area - sourced_area) / UNIT_AREA


func get_soaked_units() -> float:
	return soaked_area / UNIT_AREA


## Is the tile `cell` soaked full (WET)? The stub of W8's wet layer.
func is_wet(cell: Vector2i) -> bool:
	return float(soaked_cells.get(cell, 0.0)) >= water_tuning.soak_per_tile * UNIT_AREA - 0.001


## Can tile `cell` soak water up (earth or grass)?
func is_absorbent(cell: Vector2i) -> bool:
	if earth_layer != null and earth_layer.get_cell_source_id(cell) != -1:
		return true
	return grass_layer != null and grass_layer.get_cell_source_id(cell) != -1


func get_awake_count() -> int:
	var count: int = 0
	for body: WaterBody in bodies:
		if not body.is_asleep:
			count += 1
	return count


func get_drop_count() -> int:
	return drop_positions.size()


# --- Questions (floating things, tests) ----------------------------------------------

## The body whose water contains the room-local point, and its column, as
## [body, column], or [] if the point is in no water.
func find_water_at(point: Vector2) -> Array:
	for body: WaterBody in bodies:
		var column: int = body.get_column_at(point.x)
		if column < 0 or body.depth[column] <= WaterBody.DRY_DEPTH:
			continue
		var top: float = maxf(body.get_surface_y(column), body.ceiling_y[column])
		if point.y >= top and point.y <= body.floor_y[column]:
			return [body, column]
	return []


## Is there water within `radius` px of the WORLD point? A pool's water, a loose
## drop, or the ball in the player's hands (its dots) all count: to a projectile,
## water is water (after play-test 3). A fireball goes out in it, a sentry orb gets
## soaked (SentryOrb). Spray doesn't count: it's only a look.
func is_water_near(world_point: Vector2, radius: float) -> bool:
	var point: Vector2 = to_local(world_point)
	if not find_water_at(point).is_empty():
		return true
	var reach_squared: float = (radius + DROP_TOUCH_RADIUS) * (radius + DROP_TOUCH_RADIUS)
	for drop_position: Vector2 in drop_positions:
		if drop_position.distance_squared_to(point) <= reach_squared:
			return true
	for dot: Vector2 in held_dots:
		if dot.distance_squared_to(point) <= reach_squared:
			return true
	return false


## The body lying under the room-local point (its floor is at or below the point, the
## nearest such one), and its column, as [body, column], or [].
func find_body_under(point: Vector2) -> Array:
	var best: Array = []
	var best_floor: float = INF
	for body: WaterBody in bodies:
		var column: int = body.get_column_at(point.x)
		if column < 0 or body.floor_y[column] < point.y:
			continue
		if body.floor_y[column] < best_floor:
			best_floor = body.floor_y[column]
			best = [body, column]
	return best


## How much of `world_rect` is under water, 0..1: the water between the surface and
## the floor, overlapping the rect, measured at three points across it.
func get_submerged_share(world_rect: Rect2) -> float:
	var rect: Rect2 = Rect2(to_local(world_rect.position), world_rect.size)
	if rect.size.y <= 0.0:
		return 0.0
	var share: float = 0.0
	var samples: Array[float] = [rect.position.x + 1.0, rect.get_center().x, rect.end.x - 1.0]
	for sample_x: float in samples:
		var found: Array = find_body_under(Vector2(sample_x, rect.position.y))
		if found.is_empty():
			continue
		var body: WaterBody = found[0]
		var column: int = found[1]
		if body.depth[column] <= WaterBody.DRY_DEPTH:
			continue
		# Never above a ceiling (a low wall, an ice sheet): the hidden pressure water
		# there isn't water you're in.
		var water_top: float = maxf(maxf(body.get_surface_y(column), body.ceiling_y[column]), rect.position.y)
		var water_bottom: float = minf(body.floor_y[column], rect.end.y)
		share += clampf((water_bottom - water_top) / rect.size.y, 0.0, 1.0)
	return share / samples.size()


## The slope of the water's surface under the world point (px of drop per px to the
## right): positive = the surface goes down to the right. 0 if no water there.
func get_surface_slope_at(world_point: Vector2) -> float:
	var point: Vector2 = to_local(world_point)
	var found: Array = find_body_under(point)
	if found.is_empty():
		return 0.0
	var body: WaterBody = found[0]
	var column: int = found[1]
	var left: int = maxi(column - 2, 0)
	var right: int = mini(column + 2, body.get_column_count() - 1)
	if right == left or body.depth[left] <= WaterBody.DRY_DEPTH or body.depth[right] <= WaterBody.DRY_DEPTH:
		return 0.0
	return (body.get_surface_y(right) - body.get_surface_y(left)) / ((right - left) * column_width)


## Surface height of the water under the room-local point, or NAN if none.
func get_surface_y_at(point: Vector2) -> float:
	var found: Array = find_body_under(point)
	if found.is_empty():
		return NAN
	return (found[0] as WaterBody).get_surface_y(found[1])


# --- Changing the water (debug keys, floating things, later the bending) --------------

## Drops `units` of water as a loose blob around the room-local `center`, moving at
## `velocity` (plus a little jitter). It falls and lands like any drop.
func add_loose_water(center: Vector2, units: float, velocity: Vector2 = Vector2.ZERO) -> void:
	var area: float = units * UNIT_AREA
	var drop_area: float = water_tuning.drop_units * UNIT_AREA
	var wanted_drops: int = maxi(1, ceili(area / drop_area))
	# Past the cap, fewer bigger drops (never zero: the water must go somewhere).
	var room_left: int = maxi(1, water_tuning.max_drops - get_drop_count())
	var drop_count: int = mini(wanted_drops, room_left)
	var radius: float = sqrt(area / PI)
	for index: int in drop_count:
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		var jitter: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * DROP_JITTER_SPEED
		_spawn_drop(center + offset, velocity + jitter, area / drop_count)


## A ball of `units` of water centered on the room-local `center`, all moving at
## `velocity`: particles packed in a disc (their cohesion keeps it round in flight).
## The debug throw (key 6): it makes NEW water (the hands' release_held() gives back
## water taken from the room instead).
## It's a throw group of its own (Stage W5), so 2 can freeze it like a real throw.
func throw_ball(center: Vector2, velocity: Vector2, units: float) -> void:
	spawn_group = begin_throw_group(units * UNIT_AREA)
	_spawn_ball(center, velocity, units * UNIT_AREA)
	spawn_group = 0


## `area` px² of new particles packed in a disc around `center`, all at `velocity`.
func _spawn_ball(center: Vector2, velocity: Vector2, area: float) -> void:
	var drop_area: float = water_tuning.drop_units * UNIT_AREA
	var room_left: int = maxi(1, water_tuning.max_drops - get_drop_count())
	var count: int = mini(maxi(1, ceili(area / drop_area)), room_left)
	var radius: float = sqrt(area / PI)
	for index: int in count:
		# Sunflower spiral: evenly spread over the disc, no clumps or gaps.
		var along: float = sqrt((index + 0.5) / count)
		var offset: Vector2 = Vector2.from_angle(index * 2.39996) * radius * along
		_spawn_drop(center + offset, velocity, area / count)


## Puts `area` px² of water in at the room-local `point` (a source, §6.2): straight
## into the water if the point is in a body, else as one particle moving at
## `velocity`. Counted as sourced (THE BOOKS). False when the particle cap is full
## (nothing added).
func pour(point: Vector2, area: float, velocity: Vector2) -> bool:
	var found: Array = find_water_at(point)
	if not found.is_empty():
		(found[0] as WaterBody).add_water(found[1], area)
	elif get_drop_count() < water_tuning.max_drops:
		_spawn_drop(point, velocity, area)
	else:
		return false
	sourced_area += area
	return true


## A sink (§6.2): takes the water inside the room-local `rect`, up to `max_area`
## px²: every particle in it, and from each body column under it, the water above
## the rect's bottom edge. Returns the area taken (counted as drained).
func drain(rect: Rect2, max_area: float) -> float:
	var taken: float = 0.0
	var index: int = 0
	while index < drop_positions.size() and taken < max_area:
		if rect.has_point(drop_positions[index]):
			taken += drop_areas[index]
			_remove_drop(index)
		else:
			index += 1
	for body: WaterBody in bodies:
		if taken >= max_area:
			break
		var first: int = maxi(0, floori((rect.position.x - body.left_x) / column_width))
		var last: int = mini(body.get_column_count() - 1, floori((rect.end.x - body.left_x) / column_width))
		for column: int in range(first, last + 1):
			var above_drain: float = rect.end.y - body.get_surface_y(column)
			var top_of_rect: float = body.floor_y[column] - rect.position.y
			if above_drain <= 0.0 or top_of_rect <= 0.0:
				continue  # the water is all below the drain, or the drain under the floor
			var wanted: float = minf(minf(above_drain, body.depth[column]), (max_area - taken) / column_width)
			if wanted > 0.0:
				body.depth[column] -= wanted
				taken += wanted * column_width
				body.is_asleep = false
	drained_area += taken
	return taken


## Water moving through the room-local `rect` this frame, px²·px/s: each particle
## in it counts its area times its speed. What a waterwheel feels (W2 stub; the
## real wheel in W9). `along` picks the direction that counts (down by default).
func get_flow_through(rect: Rect2, along: Vector2 = Vector2.DOWN) -> float:
	var flow: float = 0.0
	for index: int in drop_positions.size():
		if rect.has_point(drop_positions[index]):
			flow += drop_areas[index] * drop_velocities[index].dot(along)
	return flow


# --- The water hands (Stage W3, Water_bending.md §5.1) -------------------------------

## Takes up to `max_area` px² of water within `reach` px of the room-local `point`
## into the hands (held_area) and returns how much it got. Loose particles in reach
## go first (whole particles: the ball eats drops, a waterfall's stream); then a body
## whose water is within reach under the point: from the column under it and its
## neighbours, so the surface dips under the ball and the dip runs out as waves
## (Water_bending.md §5.1: "the pool loses exactly what the ball gains").
## A source's water is particles (or pool water), so gathering from a waterfall or a
## stream takes nothing that wouldn't be replaced: flows never run dry.
func gather(point: Vector2, reach: float, max_area: float) -> float:
	var taken: float = 0.0
	var reach_squared: float = reach * reach
	var index: int = 0
	while index < drop_positions.size() and taken < max_area:
		if drop_positions[index].distance_squared_to(point) <= reach_squared:
			taken += drop_areas[index]
			last_gather_point = drop_positions[index]
			_remove_drop(index)  # the last particle takes this slot: look at it next
		else:
			index += 1
	if taken < max_area:
		for body: WaterBody in bodies:
			var column: int = body.get_column_at(point.x)
			if column < 0 or body.depth[column] <= WaterBody.DRY_DEPTH:
				continue
			var surface_y: float = maxf(body.get_surface_y(column), body.ceiling_y[column])
			# In reach: from `reach` above the surface down to the floor. Not through a
			# ceiling: a ball resting on an ice sheet (Stage W5) gathers nothing below it.
			if point.y < surface_y - reach or point.y > body.floor_y[column]:
				continue
			if body.ceiling_y[column] != WaterBody.NO_CEILING and point.y < body.ceiling_y[column]:
				continue
			# Two tiles' worth of columns each side share the loss: a dip, not a hole.
			taken += body.remove_water(column, max_area - taken, _radius_in_columns(TILE * 2.0))
			last_gather_point = Vector2(point.x, surface_y)
			if taken >= max_area:
				break
	held_area += taken
	return taken


## Gives `area` px² of the held water back as a ball of particles around the
## room-local `center`, all moving at `velocity` (a throw; zero = it just drops).
## The water hands' release. Like throw_ball(), but the water comes from the hands
## (held_area), so the books don't change.
func release_held(center: Vector2, velocity: Vector2, area: float, group: int = 0) -> void:
	area = minf(area, held_area)
	held_area -= area
	if area > 0.0:
		spawn_group = group
		_spawn_ball(center, velocity, area)
		spawn_group = 0


## Water for a snake (Stage W4): takes up to `area` px² from the body under the
## room-local `point` (its column there, two tiles each side sharing, so the pool
## dips around the snake's foot) into the hands (held_area). Returns what it got:
## less when the pool is running dry.
func draw_from_body_at(point: Vector2, area: float) -> float:
	var found: Array = find_body_under(point)
	if found.is_empty() or (found[0] as WaterBody).depth[found[1]] <= WaterBody.DRY_DEPTH:
		return 0.0
	var taken: float = (found[0] as WaterBody).remove_water(found[1], area, _radius_in_columns(TILE * 2.0))
	held_area += taken
	return taken


## Gives `area` px² of the held water straight back to the body under the
## room-local `point` (a snake shortening, or sinking back into its pool). No body
## there: it drops as loose water.
func return_held_to_body_at(point: Vector2, area: float) -> void:
	area = minf(area, held_area)
	if area <= 0.0:
		return
	held_area -= area
	var found: Array = find_body_under(point)
	if found.is_empty():
		_spawn_ball(point, Vector2.ZERO, area)
	else:
		# Spread like draw_from_body_at takes: one column's worth would be a spike.
		(found[0] as WaterBody).add_water_spread(found[1], area, _radius_in_columns(TILE * 2.0))


## Lets go of held water along a line (a snake released like a whip, or torn):
## `areas[i]` px² as particles around the room-local `points[i]`, moving at
## `velocities[i]`, spread `width` px across the line. The books don't change.
## `group`: the throw group the particles join (a snake's ribbon, Stage W5), or 0.
func release_held_along(points: PackedVector2Array, velocities: PackedVector2Array,
		areas: PackedFloat32Array, width: float, group: int = 0) -> void:
	spawn_group = group
	var drop_area: float = water_tuning.drop_units * UNIT_AREA
	for index: int in points.size():
		var area: float = minf(areas[index], held_area)
		if area <= 0.0:
			continue
		held_area -= area
		var room_left: int = maxi(1, water_tuning.max_drops - get_drop_count())
		var count: int = mini(maxi(1, ceili(area / drop_area)), room_left)
		for drop_index: int in count:
			var offset: Vector2 = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * width
			_spawn_drop(points[index] + offset, velocities[index], area / count)
	spawn_group = 0


## The held ball's dots for this frame (room-local); empty = nothing held.
func set_held_dots(dots: PackedVector2Array) -> void:
	held_dots = dots
	queue_redraw()
	renderer.refresh()


## A few sparkling specks of spray at the room-local `point` (an empty ball let go,
## an orb fizzling on the ball): only a look.
func sparkle(point: Vector2, count: int = 4) -> void:
	for index: int in count:
		_spawn_spray(point, Vector2.from_angle(randf() * TAU) * randf_range(20.0, 50.0))


## Takes up to `units` of water from the water nearest the room-local `point`: from
## a few columns there first, then from the rest of that body, then from the next
## nearest body (a thin puddle may not hold a whole bucket). Returns the units taken.
func remove_water_near(point: Vector2, units: float) -> float:
	# Each body's nearest wet column and its distance.
	var candidates: Array = []
	for body: WaterBody in bodies:
		var best_column: int = -1
		var best_distance: float = INF
		for column: int in body.get_column_count():
			if body.depth[column] <= WaterBody.DRY_DEPTH:
				continue
			var surface_point: Vector2 = Vector2(body.get_column_left(column) + column_width * 0.5, body.get_surface_y(column))
			var distance: float = surface_point.distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				best_column = column
		if best_column >= 0:
			candidates.append([best_distance, body, best_column])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var wanted: float = units * UNIT_AREA
	var taken: float = 0.0
	var spread: int = roundi(TILE * 2.0 / column_width)  # two tiles each side
	for candidate: Array in candidates:
		var body: WaterBody = candidate[1]
		taken += body.remove_water(candidate[2], wanted - taken, spread)
		if taken < wanted - 0.0001:
			taken += body.remove_water(candidate[2], wanted - taken, body.get_column_count())
		if taken >= wanted - 0.0001:
			break
	return taken / UNIT_AREA


## Pokes the water under the room-local `point`: a dip `dip_depth` px deep and
## POKE_RADIUS px wide, its water heaped up around it. Waves run outward from there.
## False if no water there.
func poke(point: Vector2, dip_depth: float) -> bool:
	var found: Array = find_body_under(point)
	if found.is_empty():
		return false
	(found[0] as WaterBody).displace(found[1], dip_depth, _radius_in_columns(POKE_RADIUS))
	return true


## Pushes the water at the world point by `impulse` (px/s: x shoves it sideways, +y
## pushes it down and out), over `width` px of surface. Things falling in and moving
## through water call this.
func push_at(world_point: Vector2, impulse: Vector2, width: float = TILE) -> void:
	var found: Array = find_body_under(to_local(world_point))
	if found.is_empty():
		return
	var body: WaterBody = found[0]
	body.push(found[1], impulse.x, maxf(impulse.y, 0.0), maxf(impulse.y, 0.0) * 0.02, _radius_in_columns(width * 0.5))


## How many columns `radius` px covers (at least one).
func _radius_in_columns(radius: float) -> int:
	return maxi(1, roundi(radius / column_width))


func wake_all() -> void:
	for body: WaterBody in bodies:
		body.is_asleep = false


## Death or R (Room.RESETTABLE_GROUP): the painted water comes back, drops vanish.
func reset() -> void:
	# Ice goes first (the bodies are rebuilt below, so a sheet's water isn't given
	# back: the painted water comes back instead).
	for ice: Node in player_ice:
		if is_instance_valid(ice):
			ice.queue_free()
	player_ice.clear()
	ice_area = 0.0
	last_ice = null
	last_group_id += 1  # nothing thrown before the reset is "the last throw"
	last_group_area = 0.0
	last_group_time = -1000.0
	_build_bodies_from_layer()
	soaked_cells.clear()
	soaked_per_cell.fill(0.0)
	_rebuild_soak_open()
	soaked_area = 0.0
	sourced_area = 0.0
	drained_area = 0.0
	held_area = 0.0
	reset_count += 1
	held_dots.clear()
	spray_positions.clear()
	spray_velocities.clear()
	spray_life.clear()
	peak_step_usec = 0
	player_was_in_water = false
	queue_redraw()


# --- Throw groups and freezing (Stage W5, Water_bending.md §5.3, §7) ------------------
#
# THROW GROUPS: each release from the hands (and the debug throw) is a group: its
# particles carry its id in drop_groups until they merge into a pool or soak in.
# "The water you last threw" is the newest group. FreezeAbility asks whether it is
# still LIVE (young enough and mostly still loose) and, if so, freezes all of it.
#
# WHAT FROZEN WATER BECOMES (freeze_particles): the particles' spread is measured
# along its longest direction (the principal axis of the points, like PCA):
#   - COMPACT (no longer than compact_max_size, or not twice as long as it is wide):
#     a block you can push around.
#   - LONG (a ribbon, a waterfall): a piece that lies still where it lands.
# Both are IceBlocks in EXACTLY the shape the water was drawn with (IceOutline traces
# the metaballs' outline; after the first W5 play-test), moving on at the water's
# average velocity (they keep their momentum). Only a snake frozen in the hands,
# its foot still in its pool, stays put: a static PILLAR (IcePiece).
# A pool hit by the crystal gets an ice SHEET over a stretch (freeze_body_at): the
# water above the sheet's bottom becomes ice, and the columns under it get the
# sheet's bottom as their CEILING, so the water below stays water you can't
# surface through, and a column frozen to its floor dams the flow (WaterBody).
# Every piece of ice holds exactly the water it was made of (ice_area in THE BOOKS)
# and gives it back when it melts (melt_ice): fire, the ice cap, a shattered block.

## A new throw group of `area` px² (released now). Returns its id.
func begin_throw_group(area: float) -> int:
	last_group_id += 1
	last_group_area = area
	last_group_time = game_time
	return last_group_id


## Water of throw group `group` still loose (particles), px².
func get_group_loose_area(group: int) -> float:
	var total: float = 0.0
	if group <= 0:
		return total
	for index: int in drop_groups.size():
		if drop_groups[index] == group:
			total += drop_areas[index]
	return total


## Game seconds since the last throw was let go.
func get_last_throw_age() -> float:
	return game_time - last_group_time


## The room-local positions of throw group `group`'s particles (the freeze's frost
## glints are drawn on them).
func get_group_points(group: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if group <= 0:
		return points
	for index: int in drop_groups.size():
		if drop_groups[index] == group:
			points.append(drop_positions[index])
	return points


## The throw group of a loose drop within `radius` px of the room-local `point` (0:
## water that isn't a throw), or -1 if no drop is that close. The ice crystal asks.
## `sweep_time` (s): a drop also counts if the path it moved along in that much time
## passed that close: a fast waterfall's drops are 10-20 px apart, and a thin
## crystal could otherwise fly between them.
func find_drop_group_near(point: Vector2, radius: float, sweep_time: float = 0.0) -> int:
	var radius_squared: float = (radius + DROP_TOUCH_RADIUS) * (radius + DROP_TOUCH_RADIUS)
	for index: int in drop_positions.size():
		var now: Vector2 = drop_positions[index]
		var before: Vector2 = now - drop_velocities[index] * sweep_time
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point, before, now)
		if nearest.distance_squared_to(point) <= radius_squared:
			return drop_groups[index]
	return -1


## Takes every particle of throw group `group` out of the loose water. Returns
## [points, areas, velocities] (room-local); their water is now nowhere (the caller
## turns it into ice at once).
func take_group_particles(group: int) -> Array:
	var points: PackedVector2Array = PackedVector2Array()
	var areas: PackedFloat32Array = PackedFloat32Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	var index: int = 0
	while index < drop_positions.size():
		if group > 0 and drop_groups[index] == group:
			points.append(drop_positions[index])
			areas.append(drop_areas[index])
			velocities.append(drop_velocities[index])
			_remove_drop(index)
		else:
			index += 1
	return [points, areas, velocities]


## Takes the loose water joined to the room-local `point` (the crystal hit a
## waterfall or spray): the particle nearest the point, then every particle within
## `join` px of one already taken (plus the distance the faster of the two moves in
## STREAM_JOIN_TIME: a fast waterfall's drops fall 10-20 px apart), none farther than
## `reach` from the point. Returns
## [points, areas, velocities] like take_group_particles. A flood fill: a waterfall's
## column is taken up and down from the hit, a separate splash beside it isn't.
func take_loose_near(point: Vector2, reach: float, join: float) -> Array:
	var points: PackedVector2Array = PackedVector2Array()
	var areas: PackedFloat32Array = PackedFloat32Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	var reach_squared: float = reach * reach
	# Candidates: every particle within reach.
	var candidates: Array[int] = []
	for index: int in drop_positions.size():
		if drop_positions[index].distance_squared_to(point) <= reach_squared:
			candidates.append(index)
	if candidates.is_empty():
		return [points, areas, velocities]
	var nearest: int = candidates[0]
	for index: int in candidates:
		if drop_positions[index].distance_squared_to(point) < drop_positions[nearest].distance_squared_to(point):
			nearest = index
	var taken: Dictionary = {nearest: true}
	var queue: Array[int] = [nearest]
	while not queue.is_empty():
		var here_index: int = queue.pop_back()
		var here: Vector2 = drop_positions[here_index]
		var here_speed: float = drop_velocities[here_index].length()
		for index: int in candidates:
			if taken.has(index):
				continue
			var allowed: float = join + maxf(here_speed, drop_velocities[index].length()) * STREAM_JOIN_TIME
			if drop_positions[index].distance_squared_to(here) <= allowed * allowed:
				taken[index] = true
				queue.append(index)
	# Remove from the highest index down, so the swap-with-last never moves one we want.
	var indices: Array = taken.keys()
	indices.sort()
	indices.reverse()
	for index: int in indices:
		points.append(drop_positions[index])
		areas.append(drop_areas[index])
		velocities.append(drop_velocities[index])
		_remove_drop(index)
	return [points, areas, velocities]


## Turns taken water (`points`, `areas`, `velocities`, room-local, as returned by
## take_group_particles) into ice. Water that has split into separate blobs (a
## splash, a throw that broke up) freezes into SEPARATE pieces, each with its own
## water and its own velocity (play-test 5: one piece made of several blobs left
## frozen splats hanging in the air). The blobs are the loops of the water's outline
## as it's drawn (drops stretched along their speed, so a waterfall's beads are one
## blob); each drop belongs to the loop around it, or the nearest one. All the pieces
## of one freeze count as ONE toward the ice cap. Returns the biggest piece, or null
## for no water (every piece is in `last_freeze_pieces`).
func freeze_particles(points: PackedVector2Array, areas: PackedFloat32Array,
		velocities: PackedVector2Array) -> Node:
	last_freeze_pieces.clear()
	if points.is_empty():
		return null
	var loops: Array[PackedVector2Array] = IceOutline.trace(points, velocities, water_tuning.blob_dot_radius,
		water_tuning.blob_stretch, water_tuning.blob_threshold)
	# Per loop, the indices of its drops. Plain Arrays, not PackedInt32Arrays: a
	# packed array taken out of an Array is a COPY, so appending to it would be lost.
	var members: Array[Array] = []
	for loop: PackedVector2Array in loops:
		members.append([])
	if loops.is_empty():
		members.append([])
	for index: int in points.size():
		members[_find_loop_of(points[index], loops)].append(index)
	# Every piece made below shares one freeze id (one freeze for the ice cap).
	freeze_id_counter += 1
	current_freeze_id = freeze_id_counter
	var biggest: Node = null
	var biggest_area: float = -1.0
	for loop_index: int in members.size():
		var indices: Array = members[loop_index]
		if indices.is_empty():
			continue
		var cluster_points: PackedVector2Array = PackedVector2Array()
		var cluster_areas: PackedFloat32Array = PackedFloat32Array()
		var cluster_velocities: PackedVector2Array = PackedVector2Array()
		for index: int in indices:
			cluster_points.append(points[index])
			cluster_areas.append(areas[index])
			cluster_velocities.append(velocities[index])
		var loop: PackedVector2Array = loops[loop_index] if loop_index < loops.size() else PackedVector2Array()
		var piece: Node = _freeze_blob(cluster_points, cluster_areas, cluster_velocities, loop)
		if piece == null:
			continue
		last_freeze_pieces.append(piece)
		var piece_area: float = float(piece.get(&"water_area"))
		if piece_area > biggest_area:
			biggest_area = piece_area
			biggest = piece
	current_freeze_id = -1
	return biggest


## Which of `loops` the point is in (or nearest to: a drop on the outline's very
## edge), as an index; 0 with no loops at all.
func _find_loop_of(point: Vector2, loops: Array[PackedVector2Array]) -> int:
	var nearest: int = 0
	var nearest_distance: float = INF
	for loop_index: int in loops.size():
		if Geometry2D.is_point_in_polygon(point, loops[loop_index]):
			return loop_index
		for corner: Vector2 in loops[loop_index]:
			var distance: float = corner.distance_squared_to(point)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = loop_index
	return nearest


## One blob of frozen water (its drops, and `loop`: its outline as drawn) into one
## piece of free ice: COMPACT or LONG (see the section notes), moving at its own
## water's average velocity.
func _freeze_blob(points: PackedVector2Array, areas: PackedFloat32Array, velocities: PackedVector2Array,
		loop: PackedVector2Array) -> Node:
	var area: float = 0.0
	var center: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	for index: int in points.size():
		area += areas[index]
		center += points[index] * areas[index]
		velocity += velocities[index] * areas[index]
	if area <= 0.0:
		return null
	center /= area
	velocity /= area
	var is_long: bool = _is_long_spread(points, center)
	# A long blob keeps the outline it's drawn with (stretched drops: that's what
	# makes a waterfall's beads one column). A compact one is traced again with round
	# drops: in flight its stretched dots would freeze its motion blur. If that splits
	# it, the drawn outline is kept (it's one blob).
	var outlines: Array[PackedVector2Array] = []
	if not is_long:
		outlines = IceOutline.trace(points, PackedVector2Array(), water_tuning.blob_dot_radius, 0.0,
			water_tuning.blob_threshold)
	if outlines.size() != 1 and loop.size() >= 3:
		outlines = [loop]
	return _make_free_ice(outlines, center, area, velocity, is_long)


## Is water spread like this LONG (a ribbon, a waterfall) rather than COMPACT (a
## ball)? Measured along the longest direction through the points (the principal
## axis of their spread, from the 2x2 covariance): longer than compact_max_size and
## at least twice as long as it is wide.
func _is_long_spread(points: PackedVector2Array, center: Vector2) -> bool:
	var spread_xx: float = 0.0
	var spread_yy: float = 0.0
	var spread_xy: float = 0.0
	for point: Vector2 in points:
		var offset: Vector2 = point - center
		spread_xx += offset.x * offset.x
		spread_yy += offset.y * offset.y
		spread_xy += offset.x * offset.y
	var axis: Vector2 = Vector2.from_angle(0.5 * atan2(2.0 * spread_xy, spread_xx - spread_yy))
	var across: Vector2 = axis.orthogonal()
	var along_min: float = INF
	var along_max: float = -INF
	var across_min: float = INF
	var across_max: float = -INF
	for point: Vector2 in points:
		var along: float = (point - center).dot(axis)
		var side: float = (point - center).dot(across)
		along_min = minf(along_min, along)
		along_max = maxf(along_max, along)
		across_min = minf(across_min, side)
		across_max = maxf(across_max, side)
	var length: float = along_max - along_min
	var width: float = across_max - across_min
	return length > water_tuning.compact_max_size and length >= width * 2.0


## An IceBlock of `area` px² of water as a round ball centered on the room-local
## `center` (its water packed as the hands pack a ball), moving at `velocity` (game
## px/s). Counted in ice_area.
func make_ice_block(center: Vector2, area: float, velocity: Vector2) -> Node:
	var outlines: Array[PackedVector2Array] = IceOutline.trace(_disc_dots(center, area), PackedVector2Array(),
		water_tuning.blob_dot_radius, 0.0, water_tuning.blob_threshold)
	return _make_free_ice(outlines, center, area, velocity, false)


## Free ice (an IceBlock) with these outlines; a crumb too small to trace becomes a
## small square, so the water is never just lost.
func _make_free_ice(outlines: Array[PackedVector2Array], center: Vector2, area: float, velocity: Vector2,
		is_long: bool) -> Node:
	if outlines.is_empty():
		var half: float = maxf(2.0, sqrt(area) / 2.0)
		outlines = [PackedVector2Array([center + Vector2(-half, -half), center + Vector2(half, -half),
			center + Vector2(half, half), center + Vector2(-half, half)])]
	var block: IceBlock = IceBlock.make(self, outlines, area, velocity, is_long)
	_register_ice(block, area, current_freeze_id)
	return block


## A static PILLAR along the room-local `spine`, holding `area` px² of water, in the
## shape a snake along it would be drawn with (dots every 2 px). Used by tests and
## anything that wants standing ice along a line.
func make_ice_shape(spine: PackedVector2Array, area: float) -> Node:
	var dots: PackedVector2Array = PackedVector2Array()
	for index: int in range(1, spine.size()):
		var from: Vector2 = spine[index - 1]
		var to: Vector2 = spine[index]
		var steps: int = maxi(1, ceili(from.distance_to(to) / 2.0))
		for step: int in steps + 1:
			dots.append(from.lerp(to, step / float(steps)))
	return _make_pillar(dots, area)


## A static pillar traced from the room-local `dots` (as the hands draw a snake).
func _make_pillar(dots: PackedVector2Array, area: float) -> Node:
	var outlines: Array[PackedVector2Array] = IceOutline.trace(dots, PackedVector2Array(),
		water_tuning.blob_dot_radius, 0.0, water_tuning.blob_threshold)
	if outlines.is_empty():
		return _make_free_ice(outlines, dots[0] if not dots.is_empty() else Vector2.ZERO, area, Vector2.ZERO, false)
	var piece: IcePiece = IcePiece.make_pillar(self, outlines, area)
	_register_ice(piece, area)
	return piece


## `area` px² of water as dots packed in a disc around `center` (the sunflower packing
## _spawn_ball and the hands use), for tracing a ball's outline.
func _disc_dots(center: Vector2, area: float) -> PackedVector2Array:
	var dots: PackedVector2Array = PackedVector2Array()
	var count: int = clampi(ceili(area / (water_tuning.drop_units * UNIT_AREA)), 1, 64)
	var radius: float = sqrt(maxf(area, 1.0) / PI)
	for index: int in count:
		dots.append(center + Vector2.from_angle(index * 2.39996) * radius * sqrt((index + 0.5) / count))
	return dots


## The crystal hit a pool at the room-local `point`: an ice SHEET over the body's
## surface, freeze_pool_reach px each side (see the section notes), cut short where
## the water is dry or already covered. Returns the sheet, or null (no open water).
func freeze_body_at(point: Vector2) -> Node:
	var found: Array = find_body_under(point + Vector2(0.0, -SHEET_PROBE_LIFT))
	if found.is_empty():
		return null
	var body: WaterBody = found[0]
	var hit_column: int = found[1]
	if not _is_open_water(body, hit_column):
		return null
	var reach_columns: int = _radius_in_columns(water_tuning.freeze_pool_reach)
	var first: int = hit_column
	while first > 0 and hit_column - first < reach_columns and _is_open_water(body, first - 1):
		first -= 1
	var last: int = hit_column
	while last < body.get_column_count() - 1 and last - hit_column < reach_columns and _is_open_water(body, last + 1):
		last += 1
	# The sheet's top follows the surface as it is (waves freeze too), smoothed over a
	# few columns so a one-column spike doesn't make a notch; its bottom is
	# ice_sheet_thickness lower, or the floor where the water is shallower.
	var tops: PackedFloat32Array = PackedFloat32Array()
	for column: int in range(first, last + 1):
		var sum: float = 0.0
		var count: int = 0
		for near: int in range(maxi(first, column - 2), mini(last, column + 2) + 1):
			sum += body.get_surface_y(near)
			count += 1
		tops.append(sum / count)
	var top_line: PackedVector2Array = PackedVector2Array()
	var bottom_line: PackedVector2Array = PackedVector2Array()
	var xs: PackedFloat32Array = PackedFloat32Array()
	var old_ceilings: PackedFloat32Array = PackedFloat32Array()
	var frozen_areas: PackedFloat32Array = PackedFloat32Array()
	var total: float = 0.0
	for column: int in range(first, last + 1):
		var top_here: float = tops[column - first]
		var ice_bottom_here: float = minf(top_here + water_tuning.ice_sheet_thickness, body.floor_y[column])
		var column_middle: float = body.get_column_left(column) + column_width * 0.5
		top_line.append(Vector2(column_middle, top_here))
		bottom_line.append(Vector2(column_middle, ice_bottom_here))
		# The water above the sheet's bottom becomes ice (all of it, if it's shallow:
		# then the column is frozen through, a dam).
		var frozen_depth: float = clampf(ice_bottom_here - body.get_surface_y(column), 0.0, body.depth[column])
		body.depth[column] -= frozen_depth
		xs.append(body.get_column_left(column) + column_width * 0.5)
		old_ceilings.append(body.ceiling_y[column])
		frozen_areas.append(frozen_depth * column_width)
		body.ceiling_y[column] = maxf(body.ceiling_y[column], ice_bottom_here)
		total += frozen_depth * column_width
	body.is_asleep = false
	# The outline: along the top from the stretch's left edge to its right edge, then
	# back along the bottom.
	var left_x: float = body.get_column_left(first)
	var right_x: float = body.get_column_left(last) + column_width
	var outline: PackedVector2Array = PackedVector2Array([Vector2(left_x, tops[0])])
	outline.append_array(top_line)
	outline.append(Vector2(right_x, tops[tops.size() - 1]))
	outline.append(Vector2(right_x, bottom_line[bottom_line.size() - 1].y))
	bottom_line.reverse()
	outline.append_array(bottom_line)
	outline.append(Vector2(left_x, bottom_line[bottom_line.size() - 1].y))
	outline = IceOutline.simplify(outline, 0.3)
	var sheet: IcePiece = IcePiece.make_sheet(self, outline, xs, old_ceilings, frozen_areas, total)
	_register_ice(sheet, total)
	_lift_out_of(Rect2(to_global(sheet.sheet_rect.position), sheet.sheet_rect.size))
	return sheet


## Water in `column` that a sheet can freeze: wet, and not under a ceiling (rock or
## another sheet) at its surface.
func _is_open_water(body: WaterBody, column: int) -> bool:
	return column >= 0 and column < body.get_column_count() \
		and body.depth[column] > WaterBody.DRY_DEPTH * 10.0 \
		and body.ceiling_y[column] < body.get_surface_y(column) - 0.5


## The water in the hands freezes where it is (2 while holding), in the shape it's
## drawn with: `dots` (room-local), the ball's and the snake's (held_dots). The ball
## holds `ball_area` px² at room-local `ball_center`; a snake (`has_snake`, its foot
## still in its pool) holds `snake_area` px². With a snake it all becomes one static
## PILLAR standing in the pool; a ball alone becomes a block that falls from where it
## was. Returns the ice, or null (empty hands).
func freeze_held(ball_center: Vector2, ball_area: float, has_snake: bool, snake_area: float,
		dots: PackedVector2Array) -> Node:
	var area: float = minf(ball_area + snake_area, held_area)
	if area <= 0.0:
		return null
	held_area -= area
	if has_snake and dots.size() >= 2:
		return _make_pillar(dots, area)
	if dots.is_empty():
		return make_ice_block(ball_center, area, Vector2.ZERO)
	var outlines: Array[PackedVector2Array] = IceOutline.trace(dots, PackedVector2Array(),
		water_tuning.blob_dot_radius, 0.0, water_tuning.blob_threshold)
	return _make_free_ice(outlines, ball_center, area, Vector2.ZERO, false)


## Every new piece of ice: counted (THE BOOKS), remembered, and the ice cap kept: a
## piece past max_player_ice melts the oldest (Water_bending.md §7.3).
## The pieces of one freeze share `freeze_id` (a splash frozen into several pieces);
## -1 = a freeze of its own. The cap counts FREEZES, not pieces (play-test 5: a
## frozen splash of many bits would otherwise melt all your other ice), and melting
## the oldest freeze melts all its pieces.
func _register_ice(ice: Node, area: float, freeze_id: int = -1) -> void:
	if freeze_id < 0:
		freeze_id_counter += 1
		freeze_id = freeze_id_counter
	ice.set_meta(&"freeze_id", freeze_id)
	ice_area += area
	player_ice.append(ice)
	freeze_count += 1
	last_ice = ice
	while get_ice_freeze_count() > water_tuning.max_player_ice:
		var oldest: int = int(player_ice[0].get_meta(&"freeze_id"))
		for piece: Node in player_ice.duplicate():
			if int(piece.get_meta(&"freeze_id")) == oldest:
				melt_ice(piece)


## How many FREEZES the room's player-made ice comes from (what the ice cap counts).
func get_ice_freeze_count() -> int:
	var ids: Dictionary = {}
	for piece: Node in player_ice:
		ids[piece.get_meta(&"freeze_id")] = true
	return ids.size()


## Ice melts back into water (fire, the ice cap, a shattered block): its water comes
## back exactly. A block becomes a ball of loose water moving as it did, a shape
## rains down along its line (a pillar refills its pool), a sheet sinks back into
## the columns it came from. The node goes away.
func melt_ice(ice: Node) -> void:
	if not is_instance_valid(ice) or not player_ice.has(ice):
		return
	player_ice.erase(ice)
	if ice == last_ice:
		last_ice = null
	var area: float = float(ice.get(&"water_area"))
	ice_area -= area
	if ice is IcePiece and (ice as IcePiece).is_sheet:
		_unfreeze_sheet(ice as IcePiece)
	else:
		# It comes apart where it is: each convex part's share of the water (by its
		# area) as a ball of loose water at the part's middle. A block keeps moving as
		# it did; a pillar rains down into its pool.
		var parts: Array[PackedVector2Array] = []
		var velocity: Vector2 = Vector2.ZERO
		if ice is IceBlock:
			var block: IceBlock = ice as IceBlock
			parts = IceOutline.moved(block.parts, to_local(block.global_position))
			velocity = block.velocity
		else:
			parts = (ice as IcePiece).parts
		var total: float = 0.0
		for part: PackedVector2Array in parts:
			total += absf(IceOutline.polygon_area(part))
		for part: PackedVector2Array in parts:
			var share: float = area * absf(IceOutline.polygon_area(part)) / total if total > 0.0 else area / parts.size()
			var middle: Vector2 = IceOutline.centroid([part])
			_spawn_ball(middle, velocity, share)
			sparkle(middle, 1)
	ice.queue_free()


## A sheet's water goes back into the columns it froze, with their old ceilings.
## The body may have changed since (merged, grown), so each column is found again by
## its x under the sheet; one that's gone gets its water back as a drop.
func _unfreeze_sheet(sheet: IcePiece) -> void:
	var rect: Rect2 = sheet.sheet_rect
	for index: int in sheet.sheet_xs.size():
		var x: float = sheet.sheet_xs[index]
		var area: float = sheet.sheet_areas[index]
		var found: Array = find_body_under(Vector2(x, rect.position.y))
		if found.is_empty():
			if area > 0.0:
				_spawn_drop(Vector2(x, rect.position.y - 1.0), Vector2.ZERO, area)
			continue
		var body: WaterBody = found[0]
		var column: int = found[1]
		body.ceiling_y[column] = sheet.sheet_old_ceilings[index]
		body.depth[column] += area / column_width
		body.is_asleep = false
	for point_x: float in [rect.position.x + 2.0, rect.get_center().x, rect.end.x - 2.0]:
		sparkle(Vector2(point_x, rect.position.y), 2)


## Bodies caught inside new ice (you, a floating crate) are lifted onto it: you
## swam at the surface and the pool froze around your head (W5 planning, default d).
## Something wholly below the ice stays under it.
func _lift_out_of(ice_rect_global: Rect2) -> void:
	for member: Node in get_tree().get_nodes_in_group(SOLID_GROUP):
		var body: CharacterBody2D = member as CharacterBody2D
		if body == null or member is IceBlock or not member.has_method(&"get_water_box"):
			continue
		var box: Rect2 = member.call(&"get_water_box")
		if box.size.x <= 0.0 or not box.intersects(ice_rect_global):
			continue
		# Origins are at the feet (the player, crates): stand it on the ice's top.
		body.global_position.y = ice_rect_global.position.y
		body.velocity.y = minf(body.velocity.y, 0.0)


## Is the room-local `point` inside player-made ice? (A WaterSource whose mouth is
## frozen stops pouring.)
func is_point_in_ice(point: Vector2) -> bool:
	var world_point: Vector2 = to_global(point)
	for ice: Node in player_ice:
		if not is_instance_valid(ice):
			continue
		if ice.has_method(&"get_water_boxes"):
			for box: Rect2 in ice.call(&"get_water_boxes"):
				if box.has_point(world_point):
					return true
		elif (ice.call(&"get_water_box") as Rect2).has_point(world_point):
			return true
	return false


# --- Every frame ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if GameState.current_room != room:
		return  # not the room on screen: its water waits
	var started_usec: int = Time.get_ticks_usec()
	game_time += delta
	_handle_debug_keys()
	if not player_ice.is_empty():
		var glint_player: Node2D = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
		if glint_player != null:
			IceLook.update_glint(glint_player.global_position.x)
	var was_busy: bool = get_awake_count() > 0 or get_drop_count() > 0
	_update_ends()
	var bodies_started_usec: int = Time.get_ticks_usec()
	# Each awake body's depths before the step: how fast each surface rises this frame
	# is what _break_crests() needs (a packed array copy is cheap: one memcpy).
	var depths_before: Array[PackedFloat32Array] = []
	for body: WaterBody in bodies:
		depths_before.append(PackedFloat32Array() if body.is_asleep else body.depth.duplicate())
	_step_bodies(delta)
	last_bodies_usec = Time.get_ticks_usec() - bodies_started_usec
	_break_crests(delta, depths_before)
	_release_spills()
	var drops_started_usec: int = Time.get_ticks_usec()
	_collect_solid_boxes()
	var cohesion_started_usec: int = Time.get_ticks_usec()
	# SPEED: cohesion runs every COHESION_EVERY frames with that many frames' worth of
	# time (still stable at these spring strengths): it's the costliest part of loose
	# water (§6.5), and every other frame halves it.
	cohesion_frame = (cohesion_frame + 1) % COHESION_EVERY
	if cohesion_frame == 0 and get_drop_count() >= 2 and water_tuning.cohesion_stiffness > 0.0:
		WaterCohesion.apply(drop_positions, drop_velocities, delta * COHESION_EVERY, water_tuning.cohesion_radius,
			water_tuning.cohesion_rest, water_tuning.cohesion_stiffness, water_tuning.cohesion_viscosity,
			water_tuning.cohesion_repulsion,
			int(room.room_size.x / water_tuning.cohesion_radius) + 3)
	last_cohesion_usec = Time.get_ticks_usec() - cohesion_started_usec
	_step_drops(delta)
	last_drops_usec = Time.get_ticks_usec() - drops_started_usec
	_stir_with_player(delta)
	_tidy_bodies()
	var had_spray: bool = not spray_life.is_empty()
	_step_spray(delta)
	last_step_usec = Time.get_ticks_usec() - started_usec
	peak_step_usec = maxi(peak_step_usec, last_step_usec)
	if was_busy or had_spray or get_awake_count() > 0 or get_drop_count() > 0:
		queue_redraw()
	renderer.refresh()
	_update_shader_parameters()


func _handle_debug_keys() -> void:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		return
	var feet: Vector2 = to_local(player.global_position)
	if Input.is_action_just_pressed("debug_water_wave"):
		poke(feet + Vector2(0.0, -4.0), water_tuning.debug_wave_depth)
	if Input.is_action_just_pressed("debug_water_dump"):
		add_loose_water(feet + Vector2(0.0, -28.0), water_tuning.debug_bucket_units)
	if Input.is_action_just_pressed("debug_water_drain"):
		remove_water_near(feet, water_tuning.debug_bucket_units)
	if Input.is_action_just_pressed("debug_water_throw"):
		# A ball of water, thrown in the arrow direction (no arrow: ahead and up).
		var aim: Vector2 = player.get_aim_input()
		if aim == Vector2.ZERO:
			aim = Vector2(player.facing_direction, -0.6)
		var direction: Vector2 = aim.normalized()
		throw_ball(to_local(player.get_center()) + direction * 12.0,
			direction * water_tuning.debug_throw_speed, water_tuning.debug_throw_units)
	if Input.is_action_just_pressed("debug_water_look"):
		# Cycle the look; the tuning resource is shared, so every room switches.
		water_tuning.look_style = (water_tuning.look_style + 1) % LOOK_NAMES.size()
		print("[WaterWorld] water look: %s" % get_look_name())


## Decides each awake body's two ends (see the header): wall, grow, merge or spill.
func _update_ends() -> void:
	for body: WaterBody in bodies.duplicate():
		if body.is_asleep or not bodies.has(body):
			continue  # asleep (nothing changes) or merged away this frame
		_update_end(body, true)
		if bodies.has(body):
			_update_end(body, false)


func _update_end(body: WaterBody, at_left: bool) -> void:
	var end_column: int = 0 if at_left else body.get_column_count() - 1
	var kind: WaterBody.EndKind = WaterBody.EndKind.WALL
	var outside_x: float = body.left_x - column_width * 0.5 if at_left else body.get_right_x() + column_width * 0.5
	var surface: float = body.get_surface_y(end_column)
	var probe_y: float = surface + 0.01
	# Too thin to flow anywhere (surface tension), or solid at the surface: a wall.
	if body.depth[end_column] > water_tuning.puddle_min_depth and not is_solid_px(outside_x, probe_y):
		var outside_floor: float = floor_below(outside_x, probe_y)
		if outside_floor - body.floor_y[end_column] > water_tuning.spill_drop:
			kind = WaterBody.EndKind.SPILL
		else:
			var other: WaterBody = _find_body_with_floor(outside_x, outside_floor, body)
			if other == null:
				body.add_column(outside_floor, ceiling_above(outside_x, probe_y), 0.0, at_left)
			elif other.get_column_at(outside_x) == (other.get_column_count() - 1 if at_left else 0):
				if at_left:
					_merge(other, body)
				else:
					_merge(body, other)
				return
			# else: another body overlaps there in some odd way: treat it as a wall.
	if at_left:
		body.left_end = kind
	else:
		body.right_end = kind


## A body (other than `excluding`) with a column over room-local `x` whose floor is
## at `floor_y` (within half a pixel), or null.
func _find_body_with_floor(x: float, floor_y: float, excluding: WaterBody) -> WaterBody:
	for body: WaterBody in bodies:
		if body == excluding:
			continue
		var column: int = body.get_column_at(x)
		if column >= 0 and absf(body.floor_y[column] - floor_y) < 0.5:
			return body
	return null


## `right` starts where `left` ends: they become one body (`left`).
func _merge(left: WaterBody, right: WaterBody) -> void:
	left.absorb_on_right(right)
	bodies.erase(right)


func _step_bodies(delta: float) -> void:
	var deepest: float = 0.0
	var any_awake: bool = false
	for body: WaterBody in bodies:
		if not body.is_asleep:
			any_awake = true
			deepest = maxf(deepest, body.get_max_depth())
	if not any_awake:
		return
	# Sub-steps: enough that a wave moves less than max_step_courant of a column per
	# sub-step (past one column per step the pipe model blows up).
	var wave_speed: float = sqrt(water_tuning.water_gravity * minf(deepest, water_tuning.max_wave_depth))
	var wave_steps: int = ceili(wave_speed * delta / (column_width * water_tuning.max_step_courant))
	var substeps: int = clampi(wave_steps, 1, water_tuning.max_substeps)
	var step_delta: float = delta / substeps
	for substep: int in substeps:
		for body: WaterBody in bodies:
			if body.is_asleep:
				continue
			body.step_flow(step_delta, water_tuning.water_gravity, water_tuning.max_wave_depth,
				water_tuning.flow_damping, water_tuning.flow_viscosity, water_tuning.puddle_min_depth)
	# The ripples are cosmetic: one step a frame is enough (see WaterTuning).
	for body: WaterBody in bodies:
		if not body.is_asleep:
			body.step_ripples(delta, water_tuning.ripple_stiffness, water_tuning.ripple_damping,
				water_tuning.ripple_spread, water_tuning.ripple_max_height)


## Turns water that poured over a lip into falling drops (a few per frame).
func _release_spills() -> void:
	var drop_area: float = water_tuning.drop_units * UNIT_AREA
	for body: WaterBody in bodies:
		for at_left: bool in [true, false]:
			var pending: float = body.spilled_left if at_left else body.spilled_right
			var still_spilling: bool = body.spill_flow_left > 0.0 if at_left else body.spill_flow_right > 0.0
			if pending <= 0.0 or (pending < drop_area and still_spilling):
				continue  # nothing, or not a whole drop yet
			var end_column: int = 0 if at_left else body.get_column_count() - 1
			var lip_x: float = body.left_x - 0.5 if at_left else body.get_right_x() + 0.5
			var spawn_y: float = body.get_surface_y(end_column) + 0.5
			if is_solid_px(lip_x, spawn_y):
				spawn_y -= 1.0
			var outward: float = -1.0 if at_left else 1.0
			var speed: float = sqrt(water_tuning.water_gravity * minf(body.depth[end_column] + 1.0, water_tuning.max_wave_depth)) \
				* water_tuning.spill_launch_scale
			# Near the cap, bigger drops (the same water in fewer points).
			var this_drop_area: float = drop_area
			if get_drop_count() * 4 >= water_tuning.max_drops * 3:
				this_drop_area *= 4.0
			var released: int = 0
			while pending >= this_drop_area and released < MAX_DROPS_PER_SPILL_FRAME \
					and get_drop_count() < water_tuning.max_drops:
				var velocity: Vector2 = Vector2(outward * speed * randf_range(0.7, 1.0), randf_range(0.0, 10.0))
				_spawn_drop(Vector2(lip_x, spawn_y + randf_range(0.0, 1.5)), velocity, this_drop_area)
				pending -= this_drop_area
				released += 1
				# Now and then a speck of spray flies off the lip.
				if randf() < 0.15:
					_spawn_spray(Vector2(lip_x, spawn_y), velocity * 1.2 + Vector2(0.0, -30.0))
			# The spill has stopped: the last crumb goes as one small drop, or it would
			# sit there forever (and keep the body awake).
			if not still_spilling and pending > 0.0 and pending < this_drop_area:
				_spawn_drop(Vector2(lip_x, spawn_y), Vector2(outward * speed * 0.5, 0.0), pending)
				pending = 0.0
			if at_left:
				body.spilled_left = pending
			else:
				body.spilled_right = pending


## Breaking waves (W2 play-test, WaterTuning "Breaking waves"): where a pool's surface
## rises fast, the crest throws bits of itself off as particles, so a wave slaps,
## sprays and foams like the loose water does instead of only swelling. The particles
## are taken from the body (the books still add up) and land back in it, kicking new
## waves of their own.
## `depths_before`: each body's depths before this frame's step (empty = it was
## asleep), so (depth now - depth before) / delta is how fast each surface rises.
## Only a CREST breaks: a column at least as high as both neighbours (water filling a
## basin rises everywhere at once and never breaks), on a WIDE rise: the rise is
## averaged over CREST_HALF_WIDTH columns each side, so the narrow spike a single
## landing particle makes doesn't count (or the thrown water, landing again, would
## keep breaking forever). SPEED: one pass over the columns of awake bodies.
func _break_crests(delta: float, depths_before: Array[PackedFloat32Array]) -> void:
	var throw_scale: float = water_tuning.wave_break_throw
	if throw_scale <= 0.0:
		return
	var break_speed: float = maxf(water_tuning.wave_break_speed, 1.0)
	var drop_area: float = water_tuning.drop_units * UNIT_AREA
	# Breaking crests are decoration: they only throw while the room holds under half
	# the particle cap, leaving the rest (and the 2 ms budget) to splashes, spills and
	# throws, which matter more. (The pass itself costs ~20-60 us a frame; the particles
	# it adds cost more.)
	var allowed: int = mini(water_tuning.wave_break_max_per_frame, int(water_tuning.max_drops * 0.5) - get_drop_count())
	for body_index: int in mini(bodies.size(), depths_before.size()):
		if allowed <= 0:
			return
		var body: WaterBody = bodies[body_index]
		var before: PackedFloat32Array = depths_before[body_index]
		var depths: PackedFloat32Array = body.depth
		if body.is_asleep or before.size() != depths.size():
			continue
		var floors: PackedFloat32Array = body.floor_y
		for column: int in range(CREST_HALF_WIDTH, depths.size() - CREST_HALF_WIDTH):
			var depth_here: float = depths[column]
			if depth_here < 2.0 or depth_here - before[column] <= break_speed * delta:
				continue  # shallow, or this column alone doesn't rise fast enough
			var risen: float = 0.0
			for offset: int in range(-CREST_HALF_WIDTH, CREST_HALF_WIDTH + 1):
				risen += depths[column + offset] - before[column + offset]
			var rise_speed: float = risen / (CREST_HALF_WIDTH * 2 + 1) / delta
			if rise_speed <= break_speed:
				continue
			# A crest: its surface (floor - depth; y grows down) is no lower than either
			# neighbour's.
			var surface_y: float = floors[column] - depth_here
			if surface_y > floors[column - 1] - depths[column - 1] or surface_y > floors[column + 1] - depths[column + 1]:
				continue
			# Faster rise, likelier break: wave_break_rate a second at twice the threshold.
			var chance: float = water_tuning.wave_break_rate * delta * (rise_speed / break_speed - 1.0)
			if randf() >= chance:
				continue
			if body.ceiling_y[column] > surface_y - 4.0:
				continue  # under a low wall: no room to throw anything
			var center_x: float = body.get_column_left(column) + column_width * 0.5
			if is_solid_px(center_x, surface_y - 2.0):
				continue
			# The water's own sideways speed there: flow = speed x depth / column_width
			# (water_body.gd), so speed = flow x column_width / depth.
			var sideways: float = (body.flow[column - 1] + body.flow[column]) * 0.5 * column_width / depth_here
			var taken: float = body.remove_water(column, drop_area, 1)
			if taken <= 0.0:
				continue
			var throw: Vector2 = Vector2(clampf(sideways, -120.0, 120.0) + randf_range(-15.0, 15.0),
				-rise_speed * throw_scale * randf_range(0.6, 1.0))
			_spawn_drop(Vector2(center_x, surface_y - 1.5), throw, taken, 1.0)
			crest_break_count += 1
			allowed -= 1
			if allowed <= 0:
				return


## Removes particle `index` (the last one takes its slot).
func _remove_drop(index: int) -> void:
	var last: int = drop_positions.size() - 1
	drop_positions[index] = drop_positions[last]
	drop_velocities[index] = drop_velocities[last]
	drop_areas[index] = drop_areas[last]
	drop_foam[index] = drop_foam[last]
	drop_groups[index] = drop_groups[last]
	drop_positions.resize(last)
	drop_velocities.resize(last)
	drop_areas.resize(last)
	drop_foam.resize(last)
	drop_groups.resize(last)


## The moving solids particles bump into this frame: everything in the
## "water_solid" group in this room (crates, the player, ice), as room-local boxes.
## A member has get_water_box() (one box) or get_water_boxes() (several).
func _collect_solid_boxes() -> void:
	solid_boxes.clear()
	if drop_positions.is_empty():
		return
	var room_rect: Rect2 = Rect2(Vector2.ZERO, room.room_size)
	for member: Node in get_tree().get_nodes_in_group(SOLID_GROUP):
		# A shape made of several boxes (ice shapes, Stage W5) lists them all.
		if member.has_method(&"get_water_boxes"):
			for many_box: Rect2 in member.call(&"get_water_boxes"):
				many_box.position = to_local(many_box.position)
				if many_box.size.x > 0.0 and room_rect.intersects(many_box):
					solid_boxes.append(many_box)
			continue
		if not member.has_method(&"get_water_box"):
			continue
		var box: Rect2 = member.call(&"get_water_box")
		if box.size.x <= 0.0:
			continue
		box.position = to_local(box.position)
		if room_rect.intersects(box):
			solid_boxes.append(box)


## `foam` 0..1: how white it starts (1 for water thrown off a splash or a crest).
func _spawn_drop(position_px: Vector2, velocity: Vector2, area: float, foam: float = 0.0) -> void:
	drop_positions.append(position_px)
	drop_velocities.append(velocity)
	drop_areas.append(area)
	drop_foam.append(foam)
	drop_groups.append(spawn_group)


## Moves every drop one frame. SPEED: this is the hottest loop in the water (up to
## max_drops drops a frame), so it works on local copies of the arrays, removes
## drops in place (the last one takes the removed one's slot), and looks bodies up
## inline instead of calling find_water_at() per drop.
func _step_drops(delta: float) -> void:
	var count: int = drop_positions.size()
	if count == 0:
		return
	var positions: PackedVector2Array = drop_positions
	var velocities: PackedVector2Array = drop_velocities
	var areas: PackedFloat32Array = drop_areas
	var foams: PackedFloat32Array = drop_foam
	var groups: PackedInt32Array = drop_groups
	var foam_fade: float = delta / maxf(water_tuning.particle_foam_life, 0.01)
	var gravity_step: float = water_tuning.drop_gravity * delta
	var max_fall: float = water_tuning.drop_max_fall_speed
	var room_size: Vector2 = room.room_size
	var drag_keep: float = maxf(0.0, 1.0 - water_tuning.particle_air_drag * delta)
	var wall_keep: float = 1.0 - water_tuning.wall_stick
	var crown_speed: float = water_tuning.crown_min_speed
	var crown_chance: float = water_tuning.crown_chance
	var crown_bounce: float = water_tuning.crown_bounce
	var boxes: Array[Rect2] = solid_boxes
	crown_count = 0
	# Each body's x range, read once.
	var body_count: int = bodies.size()
	var body_lefts: PackedFloat32Array = PackedFloat32Array()
	var body_rights: PackedFloat32Array = PackedFloat32Array()
	for body: WaterBody in bodies:
		body_lefts.append(body.left_x)
		body_rights.append(body.get_right_x())
	var index: int = 0
	while index < count:
		var old_position: Vector2 = positions[index]
		var velocity: Vector2 = velocities[index]
		var area: float = areas[index]
		var foam: float = maxf(0.0, foams[index] - foam_fade)
		velocity = velocity * drag_keep
		velocity.y = minf(velocity.y + gravity_step, max_fall)
		var new_position: Vector2 = old_position + velocity * delta
		# Moving solids (crates, the player): pushed out of the box by the shortest
		# way, losing the speed that went into it. On a box's top it slides off
		# toward the nearer edge (water doesn't sit on a crate).
		for box: Rect2 in boxes:
			if not box.has_point(new_position):
				continue
			foam = 1.0  # it hit something: white water
			var out_left: float = new_position.x - box.position.x
			var out_right: float = box.end.x - new_position.x
			var out_up: float = new_position.y - box.position.y
			var out_down: float = box.end.y - new_position.y
			var shortest: float = minf(minf(out_left, out_right), minf(out_up, out_down))
			if shortest == out_up:
				new_position.y = box.position.y - 0.01
				velocity.y = minf(velocity.y, 0.0) * 0.2
				velocity.x += (1.0 if new_position.x > box.get_center().x else -1.0) * 40.0 * delta * 10.0
			elif shortest == out_down:
				new_position.y = box.end.y + 0.01
				velocity.y = maxf(velocity.y, 0.0)
			elif shortest == out_left:
				new_position.x = box.position.x - 0.01
				velocity.x = minf(velocity.x, 0.0) * 0.2
			else:
				new_position.x = box.end.x + 0.01
				velocity.x = maxf(velocity.x, 0.0) * 0.2
		var is_gone: bool = false
		if new_position.y >= room_size.y or new_position.x < 0.0 or new_position.x >= room_size.x:
			# Fell out of the room: that water is gone (counted as lost).
			lost_area += area
			is_gone = true
		else:
			# Into a body's water: it joins it and kicks a wave.
			var x: float = new_position.x
			for body_index: int in body_count:
				if x < body_lefts[body_index] or x >= body_rights[body_index]:
					continue
				var body: WaterBody = bodies[body_index]
				var column: int = int((x - body_lefts[body_index]) / column_width)
				var column_depth: float = body.depth[column]
				if column_depth <= WaterBody.DRY_DEPTH:
					continue
				var column_floor: float = body.floor_y[column]
				var column_top: float = maxf(column_floor - column_depth, body.ceiling_y[column])
				if new_position.y <= column_floor and new_position.y >= column_top:
					if velocity.y > crown_speed and randf() < crown_chance:
						# Part of a splash crown: it bounces back up out of the pool
						# (it stays a particle), and still kicks the surface.
						body.push(column, 0.0, velocity.y * water_tuning.drop_splash_strength * area / UNIT_AREA, 0.0)
						velocity = Vector2(velocity.x * 0.6 + randf_range(-30.0, 30.0), -velocity.y * crown_bounce)
						new_position.y = column_top - 0.5
						foam = 1.0
						crown_count += 1
						break
					_land_in_body(body, column, area, velocity)
					is_gone = true
					break
		if not is_gone and is_solid_px(new_position.x, new_position.y):
			# Sideways into a wall: bounce back a little.
			if is_solid_px(new_position.x, old_position.y):
				# A hard hit foams; one just running down the wall doesn't.
				if absf(velocity.x) > water_tuning.particle_foam_speed_start * 0.5:
					foam = 1.0
				velocity.x = -velocity.x * DROP_WALL_BOUNCE
				new_position.x = old_position.x
				# Water clings a little: it runs down a wall slower than it falls.
				if velocity.y > 0.0:
					velocity.y *= wall_keep
			if is_solid_px(new_position.x, new_position.y):
				if velocity.y > 0.0:
					# Landed on the ground: a puddle starts (or grows) here.
					_land_on_ground(new_position.x, floor_below(new_position.x, old_position.y), area, velocity)
					is_gone = true
				else:
					velocity.y = 0.0  # hit a ceiling going up
					velocity.x *= wall_keep
					new_position.y = old_position.y
		if is_gone:
			count -= 1
			positions[index] = positions[count]
			velocities[index] = velocities[count]
			areas[index] = areas[count]
			foams[index] = foams[count]
			groups[index] = groups[count]
			continue  # the drop moved into this slot is stepped next
		positions[index] = new_position
		velocities[index] = velocity
		foams[index] = foam
		index += 1
	positions.resize(count)
	velocities.resize(count)
	areas.resize(count)
	foams.resize(count)
	groups.resize(count)
	drop_positions = positions
	drop_velocities = velocities
	drop_areas = areas
	drop_foam = foams
	drop_groups = groups


func _land_in_body(body: WaterBody, column: int, area: float, velocity: Vector2) -> void:
	body.add_water(column, area)
	var strength: float = water_tuning.drop_splash_strength * area / UNIT_AREA
	body.push(column, velocity.x * strength, maxf(velocity.y, 0.0) * strength,
		maxf(velocity.y, 0.0) * water_tuning.drop_splash_strength * 0.05)
	# A fast drop throws up a speck of spray (only a look: the water stays in the body).
	if velocity.y > water_tuning.spray_min_speed:
		var surface: Vector2 = Vector2(body.get_column_left(column) + column_width * 0.5, body.get_surface_y(column) - 1.0)
		_spawn_spray(surface, Vector2(randf_range(-0.4, 0.4), -randf_range(0.2, 0.45)) * velocity.y)


## A drop reached bare ground at room-local `x`, on the floor `floor_y`: it joins a
## body lying there, grows a body that ends right next to it, or starts a new one.
func _land_on_ground(x: float, floor_y: float, area: float, velocity: Vector2) -> void:
	# Absorbent ground (earth, grass) soaks it up first, up to soak_per_tile a tile.
	area -= _soak_into(Vector2i(floori(x / TILE), floori((floor_y + 0.5) / TILE)), area)
	if area <= 0.0:
		return
	var column_left: float = floorf(x / column_width) * column_width
	var center_x: float = column_left + column_width * 0.5
	var lying_there: WaterBody = _find_body_with_floor(center_x, floor_y, null)
	if lying_there != null:
		_land_in_body(lying_there, lying_there.get_column_at(center_x), area, velocity)
		return
	for body: WaterBody in bodies:
		var last: int = body.get_column_count() - 1
		if absf(body.get_right_x() - column_left) < 0.01 and absf(body.floor_y[last] - floor_y) < 0.5:
			body.add_column(floor_y, ceiling_above(center_x, floor_y), area / column_width, false)
			return
		if absf(body.left_x - (column_left + column_width)) < 0.01 and absf(body.floor_y[0] - floor_y) < 0.5:
			body.add_column(floor_y, ceiling_above(center_x, floor_y), area / column_width, true)
			return
	var new_body: WaterBody = WaterBody.new()
	new_body.column_width = column_width
	new_body.left_x = column_left
	new_body.add_column(floor_y, ceiling_above(center_x, floor_y), area / column_width, false)
	bodies.append(new_body)


## The player's body pushes the water (Water_bending.md §5.4): moving through it
## drags the water along (a bow wave in front, a dip behind, ripples where the body
## cuts the surface), and falling in or leaping out makes a splash with a crown of
## drops. (Swimming comes in W7; for now the player walks on the bottom.)
func _stir_with_player(delta: float) -> void:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead():
		player_was_in_water = false
		return
	var hitbox: Rect2 = Rect2(to_local(player.get_hitbox_rect().position), player.get_hitbox_rect().size)
	var center_x: float = hitbox.get_center().x
	var found: Array = find_body_under(Vector2(center_x, hitbox.position.y))
	var body: WaterBody = null if found.is_empty() else found[0]
	var column: int = -1 if found.is_empty() else found[1]
	# How much of the body is in the water here, px: the overlap of the hitbox with
	# the water between its surface and the floor.
	var submerged_height: float = 0.0
	if body != null and body.depth[column] > WaterBody.DRY_DEPTH:
		var surface_y: float = body.get_surface_y(column)
		submerged_height = maxf(0.0, minf(hitbox.end.y, body.floor_y[column]) - maxf(hitbox.position.y, surface_y))
	var is_in_water: bool = submerged_height > 0.0
	var velocity: Vector2 = player.velocity
	if is_in_water != player_was_in_water and body != null:
		# Crossing the surface: in going down, out going up.
		var crossing_speed: float = velocity.y if is_in_water else -velocity.y
		if crossing_speed > water_tuning.splash_min_speed:
			# Leaping out throws less water than falling in.
			_splash(body, column, crossing_speed * (1.0 if is_in_water else 0.5), hitbox.size.x)
	player_was_in_water = is_in_water
	if not is_in_water or absf(velocity.x) < 1.0:
		return  # standing still: leave the water be (and let it fall asleep)
	# The wake. Flow is px of depth per second through a pipe, so water moving at
	# speed u over a height h is a flow of u × h / column_width.
	var first_column: int = maxi(body.get_column_at(hitbox.position.x), 0)
	var last_column: int = body.get_column_at(hitbox.end.x - 0.01)
	if last_column < 0:
		last_column = body.get_column_count() - 1
	var target_flow: float = velocity.x * water_tuning.player_wake_strength * submerged_height / column_width
	body.drag(first_column, last_column, target_flow, minf(1.0, water_tuning.player_wake_grip * delta))
	# Ripples where the body cuts the surface: up at the leading edge, down at the
	# trailing one, so a moving body leaves rings behind it.
	if hitbox.position.y < body.get_surface_y(column):
		var kick: float = absf(velocity.x) * water_tuning.player_ripple_strength
		var leading: int = last_column if velocity.x > 0.0 else first_column
		var trailing: int = first_column if velocity.x > 0.0 else last_column
		body.push(leading, 0.0, 0.0, -kick)
		body.push(trailing, 0.0, 0.0, kick)


## A splash where something crosses the surface of `body` at `column`, moving at
## `speed` px/s, `width` px wide: the water is pushed down and away (a dip that runs
## out as waves) and a crown of drops, taken from the body's own water, is thrown up.
func _splash(body: WaterBody, column: int, speed: float, width: float) -> void:
	var radius: int = _radius_in_columns(width * 0.5)
	body.displace(column, minf(speed * water_tuning.splash_dip_per_speed, 10.0), radius)
	var drop_area: float = water_tuning.drop_units * UNIT_AREA
	var drop_count: int = mini(floori(speed * water_tuning.splash_drops_per_speed), 16)
	drop_count = mini(drop_count, water_tuning.max_drops - get_drop_count())
	var surface_y: float = body.get_surface_y(column)
	var center_x: float = body.get_column_left(column) + column_width * 0.5
	for index: int in drop_count:
		var taken: float = body.remove_water(column, drop_area, radius * 2)
		if taken <= 0.0:
			break
		# Alternate sides, thrown up and out at 20-60 degrees from the vertical.
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var angle: float = deg_to_rad(randf_range(20.0, 60.0))
		var throw_speed: float = speed * water_tuning.splash_throw_scale * randf_range(0.5, 1.0)
		var throw: Vector2 = Vector2(side * sin(angle), -cos(angle)) * throw_speed
		_spawn_drop(Vector2(center_x + side * width * 0.5, surface_y - 1.0), throw, taken, 1.0)
	# And twice as many specks of spray, faster and lighter than the drops.
	for index: int in drop_count * 2:
		var spray_angle: float = deg_to_rad(randf_range(-50.0, 50.0))
		var spray_speed: float = speed * water_tuning.splash_throw_scale * randf_range(0.6, 1.3)
		_spawn_spray(Vector2(center_x + randf_range(-0.5, 0.5) * width, surface_y - 1.0),
			Vector2(sin(spray_angle), -cos(spray_angle)) * spray_speed)


## Trims dry tails, forgets empty bodies, and puts calm, level bodies to sleep.
func _tidy_bodies() -> void:
	for body: WaterBody in bodies.duplicate():
		if body.is_asleep:
			continue
		_soak_from_body(body)
		lost_area += body.trim_dry_ends()
		if body.get_area() < WaterBody.DRY_DEPTH * column_width:
			lost_area += body.get_area()
			bodies.erase(body)
			continue
		if body.is_calm(water_tuning.sleep_flow, water_tuning.sleep_ripple) and _is_level(body) \
				and body.spilled_left <= 0.0 and body.spilled_right <= 0.0:
			body.fall_asleep()


## Water standing on absorbent ground (earth, grass) soaks in, up to soak_per_tile a
## tile: a small puddle on a lawn disappears, a big one wets it and stays (W2 stub
## of W8's wet layer). Only awake bodies; columns over rock cost one byte lookup.
## SPEED: works on local copies of the body's arrays and skips a column over a
## saturated (or not absorbent) tile with one byte read of soak_open, so a pool
## resting on full grass costs almost nothing.
func _soak_from_body(body: WaterBody) -> void:
	var capacity: float = water_tuning.soak_per_tile * UNIT_AREA
	if capacity <= 0.0:
		return
	if capacity != soak_open_capacity:
		_rebuild_soak_open()  # the F5 panel changed soak_per_tile
	var depths: PackedFloat32Array = body.depth
	var floors: PackedFloat32Array = body.floor_y
	var open: PackedByteArray = soak_open
	var grid_width: int = grid_size.x
	var grid_height: int = grid_size.y
	var changed: bool = false
	for column: int in depths.size():
		var column_depth: float = depths[column]
		if column_depth <= WaterBody.DRY_DEPTH:
			continue
		var cell_x: int = floori((body.left_x + (column + 0.5) * column_width) / TILE)
		var cell_y: int = floori((floors[column] + 0.5) / TILE)
		if cell_x < 0 or cell_y < 0 or cell_x >= grid_width or cell_y >= grid_height \
				or open[cell_y * grid_width + cell_x] == 0:
			continue
		var soaked: float = _soak_into(Vector2i(cell_x, cell_y), column_depth * column_width)
		if soaked > 0.0:
			depths[column] = column_depth - soaked / column_width
			changed = true
	if changed:
		body.depth = depths
		body.is_asleep = false


## Soaks up to `area` px² into the absorbent tile `cell`; when that tile is full,
## into the absorbent tiles beside it in its row, up to SOAK_REACH tiles away (wet
## ground wicks water sideways): itself, then 1 left, 1 right, 2 left, 2 right.
## Returns the area soaked.
func _soak_into(cell: Vector2i, area: float) -> float:
	var capacity: float = water_tuning.soak_per_tile * UNIT_AREA
	if area <= 0.0 or capacity <= 0.0 or not _is_absorbent_cell(cell):
		return 0.0
	var soaked: float = 0.0
	# One loop over the offsets 0, -1, 1, -2, 2 (no array made per call).
	for step: int in SOAK_REACH * 2 + 1:
		if soaked >= area:
			break
		var side: int = ((step + 1) >> 1) * (-1 if step % 2 == 1 else 1)  # >> 1: halved, no float
		var target: Vector2i = cell + Vector2i(side, 0)
		if not _is_absorbent_cell(target):
			continue
		var index: int = target.y * grid_size.x + target.x
		var room_in_tile: float = capacity - soaked_per_cell[index]
		if room_in_tile <= SOAK_FULL_SLACK:
			continue
		var taken: float = minf(area - soaked, room_in_tile)
		soaked_per_cell[index] += taken
		soaked_cells[target] = soaked_per_cell[index]
		soaked += taken
		if room_in_tile - taken <= SOAK_FULL_SLACK:
			_update_soak_open_around(target)  # it just filled up
	if soaked > 0.0:
		soaked_area += soaked
		queue_redraw()
	return soaked


## Rebuilds soak_open for every tile (load, reset, a new soak_per_tile).
func _rebuild_soak_open() -> void:
	soak_open_capacity = water_tuning.soak_per_tile * UNIT_AREA
	soak_open.resize(grid_size.x * grid_size.y)
	soak_open.fill(0)
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			_update_soak_open_at(Vector2i(x, y))


## A tile filled up: the tiles that could wick into it may have nothing left.
func _update_soak_open_around(filled: Vector2i) -> void:
	for side: int in range(-SOAK_REACH, SOAK_REACH + 1):
		_update_soak_open_at(filled + Vector2i(side, 0))


## soak_open for one tile: absorbent, with room in it or in an absorbent tile within
## SOAK_REACH in its row (the same tiles _soak_into would try).
func _update_soak_open_at(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return
	var is_open: bool = false
	if _is_absorbent_cell(cell):
		for side: int in range(-SOAK_REACH, SOAK_REACH + 1):
			var target: Vector2i = cell + Vector2i(side, 0)
			if _is_absorbent_cell(target) \
					and soak_open_capacity - soaked_per_cell[target.y * grid_size.x + target.x] > SOAK_FULL_SLACK:
				is_open = true
				break
	soak_open[cell.y * grid_size.x + cell.x] = 1 if is_open else 0


func _is_absorbent_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y \
		and absorbent_cells[cell.y * grid_size.x + cell.x] == 1


## True if no water could still run anywhere in the body: every pair of neighbouring
## columns is level, unless the higher side is too thin to flow (a puddle's edge).
func _is_level(body: WaterBody) -> bool:
	for column: int in body.get_column_count() - 1:
		var left_surface: float = body.get_surface_y(column)
		var right_surface: float = body.get_surface_y(column + 1)
		if absf(left_surface - right_surface) <= LEVEL_TOLERANCE:
			continue
		var higher: int = column if left_surface < right_surface else column + 1
		if body.depth[higher] > water_tuning.puddle_min_depth:
			return false
	return true


# --- Spray (a look only) ---------------------------------------------------------------

func _spawn_spray(position_px: Vector2, velocity: Vector2) -> void:
	if spray_life.size() >= water_tuning.max_spray:
		return
	spray_positions.append(position_px)
	spray_velocities.append(velocity)
	spray_life.append(water_tuning.spray_life * randf_range(0.6, 1.0))


## Moves the specks (gravity only, no collision: they live half a second) and drops
## the ones whose time is up (the last one takes the removed one's slot).
func _step_spray(delta: float) -> void:
	var count: int = spray_life.size()
	if count == 0:
		return
	var positions: PackedVector2Array = spray_positions
	var velocities: PackedVector2Array = spray_velocities
	var life: PackedFloat32Array = spray_life
	var gravity_step: float = water_tuning.drop_gravity * delta
	var index: int = 0
	while index < count:
		life[index] -= delta
		if life[index] <= 0.0:
			count -= 1
			positions[index] = positions[count]
			velocities[index] = velocities[count]
			life[index] = life[count]
			continue
		var velocity: Vector2 = velocities[index]
		velocity.y += gravity_step
		velocities[index] = velocity
		positions[index] += velocity * delta
		index += 1
	positions.resize(count)
	velocities.resize(count)
	life.resize(count)
	spray_positions = positions
	spray_velocities = velocities
	spray_life = life


func get_spray_count() -> int:
	return spray_life.size()


# --- Drawing --------------------------------------------------------------------------

## The name of the look being drawn ("B: see-through", ...).
func get_look_name() -> String:
	return LOOK_NAMES[clampi(water_tuning.look_style, 0, LOOK_NAMES.size() - 1)]


## Copies the look values from WaterTuning into the shader, so F5 edits show at once.
func _update_shader_parameters() -> void:
	var water_material: ShaderMaterial = material as ShaderMaterial
	if water_material == null:
		return
	water_material.set_shader_parameter(&"look_style", water_tuning.look_style)
	water_material.set_shader_parameter(&"band_px", water_tuning.band_px)
	water_material.set_shader_parameter(&"band_alpha", water_tuning.band_alpha)
	water_material.set_shader_parameter(&"blend_band_alpha", water_tuning.blend_band_alpha)
	water_material.set_shader_parameter(&"caustic_size", water_tuning.caustic_size)
	water_material.set_shader_parameter(&"caustic_warp", water_tuning.caustic_warp)
	water_material.set_shader_parameter(&"caustic_thickness", water_tuning.caustic_thickness)
	water_material.set_shader_parameter(&"shallow_alpha", water_tuning.shallow_alpha)
	water_material.set_shader_parameter(&"deep_alpha", water_tuning.deep_alpha)
	water_material.set_shader_parameter(&"deep_full_px", water_tuning.deep_full_depth)
	water_material.set_shader_parameter(&"wobble_px", water_tuning.wobble_px)
	water_material.set_shader_parameter(&"caustic_strength", water_tuning.caustic_strength)


## Everything is one list of triangles, drawn in one call: a quad per wet column, a
## 1 px quad for the surface line, a quad per drop and per spray speck. The colors
## aren't colors: they tell the shader the depth, the foam and what each quad is.
func _draw() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for body: WaterBody in bodies:
		_add_body_triangles(body, points, colors, indices)
	# Soaked tiles: a damp darkening along their top, deeper as they fill (the stub
	# of W8's wet look).
	var full_soak: float = maxf(water_tuning.soak_per_tile * UNIT_AREA, 0.001)
	for cell: Vector2i in soaked_cells:
		var wet_color: Color = Color(0.0, clampf(float(soaked_cells[cell]) / full_soak, 0.0, 1.0), KIND_WET)
		var top_left: Vector2 = Vector2(cell * TILE)
		_add_quad(points, colors, indices, top_left, top_left + Vector2(TILE, 0.0),
			top_left + Vector2(TILE, 3.0), top_left + Vector2(0.0, 3.0), wet_color, wet_color)
	# Particles: drawn as metaballs by the WaterRenderer; squares only as the fallback.
	var draw_particles: bool = not renderer.is_drawing_particles()
	for index: int in (drop_positions.size() if draw_particles else 0):
		var size: float = 2.0 if drop_areas[index] <= water_tuning.drop_units * UNIT_AREA * 1.5 else 3.0
		var drop_color: Color = Color(0.0, drop_foam[index], KIND_DROP)  # green = foam
		_add_square(points, colors, indices, drop_positions[index], size, drop_color)
	# The ball in the player's hands (Stage W3), the same way.
	for dot: Vector2 in (held_dots if draw_particles else PackedVector2Array()):
		_add_square(points, colors, indices, dot, 2.0, Color(0.0, 0.0, KIND_DROP))
	var spray_color: Color = Color(0.0, 1.0, KIND_DROP)  # a drop with full foam: white
	for index: int in spray_positions.size():
		_add_square(points, colors, indices, spray_positions[index], 1.0, spray_color)
	if not indices.is_empty():
		# Same as draw_colored_polygon, but it never has to cut a concave outline into
		# triangles (a staircase floor), and it's all one batch.
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)


## One quad per wet column (surface to floor) plus a 1 px quad along the open
## surface. The top corners are shared with the neighbours (their average), so the
## surface reads as one smooth line, not steps.
func _add_body_triangles(body: WaterBody, points: PackedVector2Array, colors: PackedColorArray,
		indices: PackedInt32Array) -> void:
	var count: int = body.get_column_count()
	var foam_speed_range: float = maxf(1.0, water_tuning.foam_speed_full - water_tuning.foam_speed_start)
	for column: int in count:
		if body.depth[column] < DRAWN_MIN_DEPTH:
			continue
		var left_x: float = body.get_column_left(column)
		var right_x: float = left_x + column_width
		var own_top: float = body.get_drawn_surface_y(column)
		var left_top: float = own_top
		if column > 0 and body.depth[column - 1] >= DRAWN_MIN_DEPTH:
			left_top = (own_top + body.get_drawn_surface_y(column - 1)) * 0.5
		var right_top: float = own_top
		if column < count - 1 and body.depth[column + 1] >= DRAWN_MIN_DEPTH:
			right_top = (own_top + body.get_drawn_surface_y(column + 1)) * 0.5
		var bottom: float = body.floor_y[column]
		left_top = minf(left_top, bottom)
		right_top = minf(right_top, bottom)
		# Foam: how fast the water runs here (flow is px of depth per second through
		# a pipe; times the column width over the depth, it's the water's speed), and
		# how choppy the ripples are.
		var pipe_flow: float = 0.0
		if column > 0:
			pipe_flow += absf(body.flow[column - 1]) * 0.5
		if column < count - 1:
			pipe_flow += absf(body.flow[column]) * 0.5
		var water_speed: float = pipe_flow * column_width / maxf(body.depth[column], 1.0)
		var foam: float = clampf((water_speed - water_tuning.foam_speed_start) / foam_speed_range, 0.0, 1.0)
		foam = maxf(foam, clampf(absf(body.ripple_speed[column]) / maxf(water_tuning.foam_ripple_full, 0.01), 0.0, 1.0))
		var top_color: Color = Color(0.0, foam, KIND_BODY)
		var bottom_color: Color = Color((bottom - own_top) / DEPTH_ENCODE_PX, foam, KIND_BODY)
		_add_quad(points, colors, indices, Vector2(left_x, left_top), Vector2(right_x, right_top),
			Vector2(right_x, bottom), Vector2(left_x, bottom), top_color, bottom_color)
		# The light surface line, where the water is open to the air (not pressed
		# against a ceiling).
		if body.get_surface_y(column) - body.ripple[column] > body.ceiling_y[column]:
			var line_color: Color = Color(0.0, foam, KIND_SURFACE)
			_add_quad(points, colors, indices, Vector2(left_x, left_top), Vector2(right_x, right_top),
				Vector2(right_x, minf(right_top + 1.0, bottom)), Vector2(left_x, minf(left_top + 1.0, bottom)),
				line_color, line_color)


## A `size` px square centered on `center` (snapped to whole pixels), one color.
func _add_square(points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
		center: Vector2, size: float, color: Color) -> void:
	var top_left: Vector2 = (center - Vector2.ONE * size * 0.5).round()
	_add_quad(points, colors, indices, top_left, top_left + Vector2(size, 0.0),
		top_left + Vector2(size, size), top_left + Vector2(0.0, size), color, color)


func _add_quad(points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
		top_left: Vector2, top_right: Vector2, bottom_right: Vector2, bottom_left: Vector2,
		top_color: Color, bottom_color: Color) -> void:
	var first: int = points.size()
	points.append_array([top_left, top_right, bottom_right, bottom_left])
	colors.append_array([top_color, top_color, bottom_color, bottom_color])
	indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

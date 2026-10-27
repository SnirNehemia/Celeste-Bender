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
##   - DROPS: falling water (a spill pouring over a lip, a debug bucket). Each is a
##     point with a velocity and some water (px²). Gravity, tile collision, nothing
##     else yet (W2 adds cohesion, splashes and the metaball look). A drop that falls
##     into a body's water merges into it and kicks a wave; one that lands on bare
##     ground starts a puddle there (or grows the puddle next to it).
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
## water in the bodies and drops; water that falls out of the room or is trimmed as
## crumbs goes into `lost_area`. The smoke test checks total + lost never changes.
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
## nearest the player. 7 `debug_water_look` cycles the look (B, C, A, B+C). (Not F6-F10: the Godot editor's embedded Game view takes F7
## as pause and F8 as stop, even while the game has the focus.)

const GROUP: StringName = &"water_world"
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
## A poke (key 8, poke()) pushes the water over this many px each side of the point.
const POKE_RADIUS: float = 8.0

## preload() returns the same resource object the player holds, so F5 panel edits
## reach the water at once.
var water_tuning: WaterTuning = preload("res://resources/water_tuning.tres")
var room: Room
var water_layer: WaterLayer
var earth_layer: EarthLayer
## The room's tile layers that are solid ground (every TileMapLayer but the water and
## hidden chambers).
var solid_layers: Array[TileMapLayer] = []
## Room size in tiles, and one byte per tile: 1 = solid. Built once in _ready (W1:
## nothing in a water room changes its tiles yet; bending will call refresh_solid_cells).
var grid_size: Vector2i = Vector2i.ZERO
var solid_cells: PackedByteArray = PackedByteArray()
## Width of every column of every body, px: TILE divided into whole columns, so
## columns always line up with the tiles and with each other.
var column_width: float = 2.0
var bodies: Array[WaterBody] = []
## The drops, one entry per drop in each array (index i is the same drop).
var drop_positions: PackedVector2Array = PackedVector2Array()
var drop_velocities: PackedVector2Array = PackedVector2Array()
var drop_areas: PackedFloat32Array = PackedFloat32Array()
## Water that left the room or was trimmed away as crumbs, px² (see THE BOOKS).
var lost_area: float = 0.0
## How much water the painted tiles held when the room loaded, px².
var initial_area: float = 0.0
var last_step_usec: int = 0
var peak_step_usec: int = 0
## The same, split: the bodies' pipes and ripples, and the drops (for tuning cost).
var last_bodies_usec: int = 0
var last_drops_usec: int = 0
## Spray: white specks with no water in them, only a look (Water_bending.md §12,
## play-test 1 "foam and spray"). Same layout as the drops: index i is one speck.
var spray_positions: PackedVector2Array = PackedVector2Array()
var spray_velocities: PackedVector2Array = PackedVector2Array()
var spray_life: PackedFloat32Array = PackedFloat32Array()
## Was any of the player in water last frame (crossing the surface makes a splash)?
var player_was_in_water: bool = false


func _ready() -> void:
	room = get_parent() as Room
	water_layer = room.get_node_or_null("Water") as WaterLayer
	earth_layer = room.get_node_or_null("Earth") as EarthLayer
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
	for rect: Rect2 in room.solid_rects:
		var first: Vector2i = Vector2i((rect.position / TILE).floor())
		var last: Vector2i = Vector2i((rect.end / TILE).ceil()) - Vector2i.ONE
		for y: int in range(maxi(first.y, 0), mini(last.y + 1, grid_size.y)):
			for x: int in range(maxi(first.x, 0), mini(last.x + 1, grid_size.x)):
				solid_cells[y * grid_size.x + x] = 1


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
		var water_top: float = maxf(body.get_surface_y(column), rect.position.y)
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
	_build_bodies_from_layer()
	spray_positions.clear()
	spray_velocities.clear()
	spray_life.clear()
	peak_step_usec = 0
	player_was_in_water = false
	queue_redraw()


# --- Every frame ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if GameState.current_room != room:
		return  # not the room on screen: its water waits
	var started_usec: int = Time.get_ticks_usec()
	_handle_debug_keys()
	var was_busy: bool = get_awake_count() > 0 or get_drop_count() > 0
	_update_ends()
	var bodies_started_usec: int = Time.get_ticks_usec()
	_step_bodies(delta)
	last_bodies_usec = Time.get_ticks_usec() - bodies_started_usec
	_release_spills()
	var drops_started_usec: int = Time.get_ticks_usec()
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


func _spawn_drop(position_px: Vector2, velocity: Vector2, area: float) -> void:
	drop_positions.append(position_px)
	drop_velocities.append(velocity)
	drop_areas.append(area)


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
	var gravity_step: float = water_tuning.drop_gravity * delta
	var max_fall: float = water_tuning.drop_max_fall_speed
	var room_size: Vector2 = room.room_size
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
		velocity.y = minf(velocity.y + gravity_step, max_fall)
		var new_position: Vector2 = old_position + velocity * delta
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
				if new_position.y <= column_floor \
						and new_position.y >= maxf(column_floor - column_depth, body.ceiling_y[column]):
					_land_in_body(body, column, area, velocity)
					is_gone = true
					break
		if not is_gone and is_solid_px(new_position.x, new_position.y):
			# Sideways into a wall: bounce back a little.
			if is_solid_px(new_position.x, old_position.y):
				velocity.x = -velocity.x * DROP_WALL_BOUNCE
				new_position.x = old_position.x
			if is_solid_px(new_position.x, new_position.y):
				if velocity.y > 0.0:
					# Landed on the ground: a puddle starts (or grows) here.
					_land_on_ground(new_position.x, floor_below(new_position.x, old_position.y), area, velocity)
					is_gone = true
				else:
					velocity.y = 0.0  # hit a ceiling going up
					new_position.y = old_position.y
		if is_gone:
			count -= 1
			positions[index] = positions[count]
			velocities[index] = velocities[count]
			areas[index] = areas[count]
			continue  # the drop moved into this slot is stepped next
		positions[index] = new_position
		velocities[index] = velocity
		index += 1
	positions.resize(count)
	velocities.resize(count)
	areas.resize(count)
	drop_positions = positions
	drop_velocities = velocities
	drop_areas = areas


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
		_spawn_drop(Vector2(center_x + side * width * 0.5, surface_y - 1.0), throw, taken)
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
		lost_area += body.trim_dry_ends()
		if body.get_area() < WaterBody.DRY_DEPTH * column_width:
			lost_area += body.get_area()
			bodies.erase(body)
			continue
		if body.is_calm(water_tuning.sleep_flow, water_tuning.sleep_ripple) and _is_level(body) \
				and body.spilled_left <= 0.0 and body.spilled_right <= 0.0:
			body.fall_asleep()


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
	var drop_color: Color = Color(0.0, 0.0, KIND_DROP)
	for index: int in drop_positions.size():
		var size: float = 2.0 if drop_areas[index] <= water_tuning.drop_units * UNIT_AREA * 1.5 else 3.0
		_add_square(points, colors, indices, drop_positions[index], size, drop_color)
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

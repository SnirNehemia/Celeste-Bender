extends "res://tools/build_earth_rooms.gd"
## tools/build_water_rooms.gd — generator for the Water chapter's test rooms.
##
## It EXTENDS the Earth room generator (tools/build_earth_rooms.gd, read its header),
## like the Fire one: every helper there (_begin_room, _gray, _open, _add,
## _finish_room ...) works here too. Only _ready() is replaced (no super() call), so
## the Earth rooms are NOT rebuilt.
##
## It writes (one test room per Water stage, all in tests/water_test_world.tscn):
##   - tests/rooms/room_water_a.tscn   Stage W1 water bodies: a pool with a floating
##                                     crate, a tank spilling into it, a staircase down
##                                     to a dry basin, two pools joined under a wall
##                                     (_build_room_water_a)
##   - tests/rooms/room_water_b.tscn   Stage W2 loose water: a waterfall from a
##                                     source over a waterwheel stub into a pool with
##                                     an overflow drain, a floor to splash puddles on,
##                                     an earth patch that soaks, a crate, a stream on
##                                     a stepped shelf spilling into a drained basin
##                                     (_build_room_water_b)
##   - tests/rooms/room_water_c.tscn   Stage W3 water hands: two pools either side of
##                                     a ledge to carry water between, and a sentry
##                                     whose orbs the held ball can eat
##                                     (_build_room_water_c)
##   - tests/rooms/room_water_d.tscn   Stage W4 water snake: a narrow deep pool by
##                                     the start, a crate on a low pillar past it to
##                                     sweep off with a snake, and a wide pool on the
##                                     right to practise rising, tearing and whips
##                                     (_build_room_water_d)
##   - tests/rooms/room_water_e.tscn   grid ice (Stages I1, I4): a 2x2 block frozen
##                                     at a ledge's foot as a step (it stays), a
##                                     crumbling step frozen in mid-air over a spike
##                                     chasm (_build_room_water_e)
##   - tests/rooms/room_water_f.tscn   grid ice (Stage I2): snake lines, a slide
##                                     drawn from a plateau pool over a spike pit, a
##                                     45° slope from a shelf pool that sends a crate
##                                     onto a pressure plate (_build_room_water_f)
##   - tests/rooms/room_water_g.tscn   grid ice (Stages I2, I3): a waterfall frozen
##                                     into an ice wall to wall-jump up beside a
##                                     tower, a raft on a wide clean pool
##                                     (_build_room_water_g)
##   - tests/rooms/room_water_h.tscn   Stage W7a black water and rafts: a black
##                                     channel to cross on a raft frozen from water
##                                     carried from a clean pool, a black pit to set a
##                                     ball down on and freeze as a stepping stone,
##                                     painted ice slopes (45° and 22.5°) down to a
##                                     ramp lip (_build_room_water_h)
##   - tests/rooms/room_water_i.tscn   Stage W7b currents: a stream with a floating
##                                     crate over a spiked floor, a black channel with
##                                     a loop current to surf a raft on, a deep loop
##                                     pool with a waterfall, floating leaves and a
##                                     leaf platform on a rail through the water
##                                     (_build_room_water_i)
##   - resources/tiles/ice_tileset.tres  (Stage W5) the painted ice tiles: pale cyan,
##                                     solid; the full tile and (Stage W7a) six slope
##                                     tiles (IceLayer.TILE_SHAPES). Written when
##                                     missing or missing a tile.
##   - resources/tiles/water_tileset.tres  (Stage W1) the water tiles: see-through blue
##                                     and (Stage W7a) inky black, NO collision (water
##                                     isn't solid). The picture is stored inside the
##                                     .tres. Written when missing or missing a tile.
##
## Water: _water() paints cells of the room's "Water" layer (WaterLayer), added
## through the Earth generator's _make_extra_layers() hook. Unlike the other kinds it
## doesn't replace the ground: paint it into open space. Each painted tile is one
## unit of water; in play the room's WaterWorld lets it settle onto the floor.
##
## Ground: gray rock, drawn as stone (`painted_ground`). Water won't soak into rock
## (Water_bending.md §8.2, from W8 on), so these rooms keep their water.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_water_rooms.tscn
## Running it again OVERWRITES the test rooms. Pass room names after `--` to build
## only those, e.g. `-- water_a` (names: water_a, water_b, water_c, water_d, water_e,
## water_f, water_g, water_h, water_i).

const WATER_LAYER_SCRIPT: Script = preload("res://scenes/objects/water/water_layer.gd")
const WATER_SOURCE_SCENE: PackedScene = preload("res://scenes/objects/water/water_source.tscn")
const WATER_SINK_SCENE: PackedScene = preload("res://scenes/objects/water/water_sink.tscn")
const WATER_WHEEL_SCENE: PackedScene = preload("res://scenes/objects/water/water_wheel.tscn")
const CURRENT_ZONE_SCENE: PackedScene = preload("res://scenes/objects/water/current_zone.tscn")
const LEAF_PILE_SCENE: PackedScene = preload("res://scenes/objects/leaf_pile.tscn")
const LEAF_PLATFORM_SCENE: PackedScene = preload("res://scenes/objects/leaf_platform.tscn")
## Water tile picture: the body color with a light top line (the surface), see-through
## so the editor shows what's behind it.
const WATER_TILE_COLOR: Color = Color(0.18, 0.5, 0.82, 0.6)
const WATER_TILE_LINE_COLOR: Color = Color(0.75, 0.89, 1.0, 0.8)
## Black water's tile (Stage W7a): ink with an oily violet top line.
const BLACK_WATER_TILE_COLOR: Color = Color(0.1, 0.08, 0.14, 0.85)
const BLACK_WATER_TILE_LINE_COLOR: Color = Color(0.42, 0.35, 0.5, 0.9)
const DOOR_SCENE: PackedScene = preload("res://scenes/objects/door.tscn")
const PLATE_SCENE: PackedScene = preload("res://scenes/objects/pressure_plate.tscn")
const ICE_LAYER_SCRIPT: Script = preload("res://scenes/objects/water/ice_layer.gd")
## Painted ice: pale cyan, a white top line and a white streak (Water_bending.md §7.3).
const ICE_TILE_COLOR: Color = Color("#BFEFFF")
const ICE_TILE_EDGE_COLOR: Color = Color("#7FD0EC")

## Water cells of the room being built: Vector2i -> the tile (WaterLayer.WATER_TILE,
## or BLACK_TILE for black water).
var water_cells: Dictionary = {}
## Painted ice cells of the room being built (Stage W5): Vector2i -> the tile
## (IceLayer.ICE_TILE or a slope, Stage W7a).
var ice_cells: Dictionary = {}


func _ready() -> void:
	log_prefix = "[BuildWaterRooms]"
	_load_or_create_water_tileset()
	_load_or_create_ice_tileset()
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if wanted.is_empty() or wanted.has("water_a"):
		_build_room_water_a()
	if wanted.is_empty() or wanted.has("water_b"):
		_build_room_water_b()
	if wanted.is_empty() or wanted.has("water_c"):
		_build_room_water_c()
	if wanted.is_empty() or wanted.has("water_d"):
		_build_room_water_d()
	if wanted.is_empty() or wanted.has("water_e"):
		_build_room_water_e()
	if wanted.is_empty() or wanted.has("water_f"):
		_build_room_water_f()
	if wanted.is_empty() or wanted.has("water_g"):
		_build_room_water_g()
	if wanted.is_empty() or wanted.has("water_h"):
		_build_room_water_h()
	if wanted.is_empty() or wanted.has("water_i"):
		_build_room_water_i()
	print("[BuildWaterRooms] Done.")
	get_tree().quit()


# --- Water --------------------------------------------------------------------------

## The water tiles' picture: clean water, then black water (Stage W7a), side by side.
func _make_water_image() -> Image:
	var image: Image = Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, TILE, TILE), WATER_TILE_COLOR)
	image.fill_rect(Rect2i(TILE, 0, TILE, TILE), BLACK_WATER_TILE_COLOR)
	for x: int in TILE:
		image.set_pixel(x, 0, WATER_TILE_LINE_COLOR)
		image.set_pixel(TILE + x, 0, BLACK_WATER_TILE_LINE_COLOR)
	return image


## Does the tileset at `path` exist with every one of `tiles` in its source 0?
## (Then it's left alone; else it's written again, e.g. after a stage added a tile.)
func _has_tiles(path: String, tiles: Array[Vector2i]) -> bool:
	if not ResourceLoader.exists(path):
		return false
	# Not cached: the tileset written below must be the one later load()s return.
	var existing: TileSet = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as TileSet
	var source: TileSetAtlasSource = existing.get_source(0) as TileSetAtlasSource if existing.has_source(0) else null
	if source == null:
		return false
	for tile: Vector2i in tiles:
		if not source.has_tile(tile):
			return false
	return true


func _load_or_create_water_tileset() -> void:
	if _has_tiles(WaterLayer.TILESET_PATH, [WaterLayer.WATER_TILE, WaterLayer.BLACK_TILE]):
		return
	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE, TILE)
	# No physics layer at all: the player, crates and rocks pass through water tiles.
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_make_water_image())
	source.texture_region_size = Vector2i(TILE, TILE)
	new_tile_set.add_source(source, 0)
	source.create_tile(WaterLayer.WATER_TILE)
	source.create_tile(WaterLayer.BLACK_TILE)
	ResourceSaver.save(new_tile_set, WaterLayer.TILESET_PATH)
	print("[BuildWaterRooms] Wrote %s" % WaterLayer.TILESET_PATH)


# --- Ice (Stage W5) -------------------------------------------------------------------

## The ice tiles' picture: one tile per IceLayer.TILE_SHAPES entry, at its atlas
## column. Each is its shape filled pale cyan with a darker bottom row; the full tile
## also gets a white top line and streak. (In play IceLayer hides them and draws the
## glass look; these show in the level editor's palette.)
func _make_ice_image() -> Image:
	var columns: int = 0
	for atlas: Vector2i in IceLayer.TILE_SHAPES:
		columns = maxi(columns, atlas.x + 1)
	var image: Image = Image.create(TILE * columns, TILE, false, Image.FORMAT_RGBA8)
	for atlas: Vector2i in IceLayer.TILE_SHAPES:
		var shape: PackedVector2Array = IceLayer.get_tile_shape(atlas)
		for x: int in TILE:
			for y: int in TILE:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), shape):
					image.set_pixel(atlas.x * TILE + x, y, ICE_TILE_EDGE_COLOR if y == TILE - 1 else ICE_TILE_COLOR)
	for x: int in TILE:
		image.set_pixel(x, 0, Color.WHITE)
	for step: int in 3:
		image.set_pixel(2 + step, 5 - step, Color.WHITE)
	return image


func _load_or_create_ice_tileset() -> void:
	var tiles: Array[Vector2i] = []
	for atlas: Vector2i in IceLayer.TILE_SHAPES:
		tiles.append(atlas)
	if _has_tiles(IceLayer.TILESET_PATH, tiles):
		return
	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE, TILE)
	new_tile_set.add_physics_layer()
	new_tile_set.set_physics_layer_collision_layer(0, 1)  # layer 1, "world": solid ground
	new_tile_set.set_physics_layer_collision_mask(0, 0)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_make_ice_image())
	source.texture_region_size = Vector2i(TILE, TILE)
	new_tile_set.add_source(source, 0)
	# Each tile's collision is its shape; a tile's collision points are measured from
	# the tile's CENTER, the shapes from its top-left corner.
	var half: Vector2 = Vector2(TILE, TILE) / 2.0
	for atlas: Vector2i in IceLayer.TILE_SHAPES:
		source.create_tile(atlas)
		var points: PackedVector2Array = PackedVector2Array()
		for corner: Vector2 in IceLayer.get_tile_shape(atlas):
			points.append(corner - half)
		var tile_data: TileData = source.get_tile_data(atlas, 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, points)
	ResourceSaver.save(new_tile_set, IceLayer.TILESET_PATH)
	print("[BuildWaterRooms] Wrote %s" % IceLayer.TILESET_PATH)


## Paints ice into a rectangle of tiles (erases whatever ground was there).
func _ice(column: int, row: int, width: int, height: int) -> void:
	_open(column, row, width, height)
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			ice_cells[Vector2i(x, y)] = IceLayer.ICE_TILE


## Paints one ice tile `atlas` (a slope, IceLayer.SLOPE_UP_RIGHT...) at a cell
## (Stage W7a).
func _ice_tile(column: int, row: int, atlas: Vector2i) -> void:
	_open(column, row, 1, 1)
	ice_cells[Vector2i(column, row)] = atlas


## Paints water into a rectangle of tiles (column, row, width, height); `black`
## paints black water (Stage W7a).
func _water(column: int, row: int, width: int, height: int, black: bool = false) -> void:
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			water_cells[Vector2i(x, y)] = WaterLayer.BLACK_TILE if black else WaterLayer.WATER_TILE


func _begin_room(node_name: String, title: String, description: String,
		size_px: Vector2 = Vector2(320, 180)) -> void:
	super(node_name, title, description, size_px)
	water_cells.clear()
	ice_cells.clear()


## The Earth generator's hook: our extra layers are "Ice" (Stage W5) and "Water",
## only in rooms with those painted.
func _make_extra_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	if not ice_cells.is_empty():
		var ice: TileMapLayer = TileMapLayer.new()
		ice.name = "Ice"
		ice.set_script(ICE_LAYER_SCRIPT)
		ice.tile_set = load(IceLayer.TILESET_PATH) as TileSet
		for cell: Vector2i in ice_cells:
			if not cell_kinds.has(cell):  # _open() elsewhere may have reused the cell
				ice.set_cell(cell, 0, ice_cells[cell])
		layers.append(ice)
	if water_cells.is_empty():
		return layers
	var water: TileMapLayer = TileMapLayer.new()
	water.name = "Water"
	water.set_script(WATER_LAYER_SCRIPT)
	water.tile_set = load(WaterLayer.TILESET_PATH) as TileSet
	for cell: Vector2i in water_cells:
		if not cell_kinds.has(cell):  # never water inside rock
			water.set_cell(cell, 0, water_cells[cell])
	layers.append(water)
	return layers


# --- Rooms --------------------------------------------------------------------------

## Water test room A (Stage W1): the water simulation on its own, no bending.
## 64 x 23 tiles (512 px wide: it scrolls). Ground top at row 14 (y 112). Left to right:
##   - the big pool (cols 5-26, 32 px deep, water 24 px deep) with a floating crate,
##     a step block at its right end to climb out on, and a TANK on a shelf above it
##     whose water stands 16 px over its left lip: it overflows and pours into the
##     pool until it's down to the lip (a spill).
##   - a bump (col 27), then a STAIRCASE down to the right: the ground (cols 28-29),
##     three 2-tile steps 8 px apart, and a dry BASIN (cols 36-43). Water dropped on
##     the top (9 standing there) spills down step by step and pools in the basin.
##   - two pools JOINED under a wall (cols 46-61): the wall (cols 53-54) leaves a
##     2-tile passage under water at the bottom, so draining one side (0) lowers both.
func _build_room_water_a() -> void:
	_begin_room("RoomWaterA", "Water A: bodies (W1)",
		"Stage W1 water bodies: waves (8 pokes, 9 drops a bucket, 0 drains one), a spilling tank, a staircase into a dry basin, two pools joined under a wall, a floating crate.",
		Vector2(512, 180))
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 64, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(63, 0, 1, 23)   # right wall
	_gray(0, 14, 64, 9)   # the ground, top at y 112

	# The big pool and its step block.
	_open(5, 14, 22, 4)   # rows 14-17: floor at row 18 (y 144)
	_gray(25, 16, 2, 2)   # step block, top y 128 (under the water)
	_water(5, 15, 22, 1)
	_water(5, 16, 20, 2)
	_add(CRATE_SCENE, "Crate1", Vector2(15 * TILE, 15 * TILE))  # on the surface (y 120)

	# The tank on a shelf over the pool: floor y 48, left lip top y 40, water to y 24.
	_gray(8, 6, 8, 1)     # shelf
	_gray(8, 5, 1, 1)     # left lip
	_gray(15, 2, 1, 4)    # right wall
	_water(9, 3, 6, 3)

	# The staircase into the basin.
	_gray(27, 13, 1, 1)   # bump: water poured on the top step runs right, not into the pool
	_open(30, 14, 14, 1)  # step A (cols 30-31) top y 120
	_open(32, 15, 12, 1)  # step B (cols 32-33) top y 128
	_open(34, 16, 10, 1)  # step C (cols 34-35) top y 136
	_open(36, 17, 8, 1)   # basin (cols 36-43), floor y 144
	_gray(43, 16, 1, 2)   # a block at the basin's right end to climb out on

	# Two pools joined under a wall.
	_open(46, 14, 16, 4)  # rows 14-17, floor y 144
	_gray(53, 9, 2, 7)    # the wall, rows 9-15: the passage is rows 16-17
	_gray(46, 16, 1, 2)   # climbing blocks at both ends
	_gray(61, 16, 1, 2)
	_water(46, 15, 16, 3)  # the cells inside the wall are skipped (water in rock)

	_finish_room(Vector2(3 * TILE, 14 * TILE), "res://tests/rooms/room_water_a.tscn")


## Water test room B (Stage W2): loose water. 40 x 23 tiles (one screen), ground top
## at row 20 (y 160). Left to right:
##   - a WATERFALL: a source under the ceiling (x 44) pours 2 units/s down through
##     a waterwheel stub (it turns) into a POOL (cols 1-11, walled at col 12). An
##     overflow DRAIN on the pool's right side (col 11, y 120-128) keeps its level at
##     y 128, so it never floods the room.
##   - an open floor (cols 13-29): rock to splash puddles on (6 throws a ball), a
##     crate to throw water at, and an EARTH patch (cols 21-26) that soaks water up
##     (0.25 unit a tile) before it puddles.
##   - a STREAM: a source over a two-step shelf (cols 27-37, y 72 and 80) whose water
##     really flows right and spills off the end into a BASIN (cols 31-38) with a
##     floor drain (cols 35-38).
func _build_room_water_b() -> void:
	_begin_room("RoomWaterB", "Water B: loose water (W2)",
		"Stage W2 loose water: 6 throws a ball of water (arrows aim). A waterfall turns a wheel and fills a pool with an overflow drain; a floor and a crate to splash; an earth patch that soaks; a stream on a stepped shelf spilling into a drained basin.")
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 40, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(39, 0, 1, 23)   # right wall
	_gray(0, 20, 40, 3)   # the ground, top at y 160

	# The waterfall, the wheel and the pool.
	_gray(12, 13, 1, 7)   # the pool's right wall, rows 13-19 (top y 104)
	_water(1, 16, 11, 4)  # rows 16-19: the level starts at the overflow (y 128)
	_add(WATER_SOURCE_SCENE, "WaterfallSource", Vector2(44, 13), {"rate": 2.0, "pour_width": 4.0})
	_add(WATER_WHEEL_SCENE, "WaterWheel", Vector2(40, 64))
	_add(WATER_SINK_SCENE, "OverflowDrain", Vector2(11 * TILE, 15 * TILE), {"sink_size": Vector2(8, 8)})

	# The open floor: a crate and an earth patch.
	_add(CRATE_SCENE, "Crate1", Vector2(17 * TILE, 20 * TILE))
	_earth(21, 20, 6, 1)

	# The stream: a two-step shelf, a source over its upper end, a drained basin.
	_gray(27, 9, 6, 1)    # upper step, cols 27-32, top y 72
	_gray(33, 10, 5, 1)   # lower step, cols 33-37, top y 80; its right end is the lip
	_gray(27, 8, 1, 1)    # a back stop at the upper step's left end
	_add(WATER_SOURCE_SCENE, "StreamSource", Vector2(29 * TILE, 6 * TILE), {"rate": 1.5, "pour_width": 6.0})
	_gray(30, 17, 1, 3)   # the basin's left wall, rows 17-19
	_add(WATER_SINK_SCENE, "FloorDrain", Vector2(35 * TILE, 19 * TILE), {"sink_size": Vector2(32, 8)})

	_finish_room(Vector2(14 * TILE, 20 * TILE), "res://tests/rooms/room_water_b.tscn")


## Water test room C (Stage W3): the water hands. 40 x 23 tiles (one screen), ground
## top at row 16 (y 128). You start on the LEDGE between two dug pools (cols 18-21,
## 32 px wide), both well inside the ring's reach (56 px) from its middle:
##   - the DEEP POOL on the left (cols 7-17, floor y 176, full: 66 units, 48 px deep):
##     hold 1, steer the ball down into it and it fills (4 units at most). Deep enough
##     to swim in: under water the ball pushes you (keep it leaning on you to swim fast)
##   - the BASIN on the right (cols 22-28, floor y 160) with a little water in it
##     (7 units, 8 px deep): carry water over and throw it in, and its level rises
##     while the deep pool's drops
##   - GROUND past the basin (cols 29-38, 80 px) and a SENTRY at its far end (col 37).
##     It sees you only from there (sight 110 px; the ledge is out of sight) and fires
##     every 1.5 s: stand at the basin's edge, hold a ball with water in it in front
##     of you and its orbs fizzle on the water, each costing the ball 1 unit
func _build_room_water_c() -> void:
	_begin_room("RoomWaterC", "Water C: water hands (W3)",
		"Stage W3 water hands: hold 1 for slow motion and a ball you steer with the arrows; touch water to gather (up to 4 units); let go of 1 to throw (push it out of the ring for a long throw); Jump drops it. Carry water from the deep pool to the basin. Under water the ball pushes you: keep it leaning on you to swim fast. Stand past the basin and the sentry fires: a full ball eats its orbs.")
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 40, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(39, 0, 1, 23)   # right wall
	_gray(0, 16, 40, 7)   # the ground, top at y 128

	# The deep pool (full) and the basin (a little water), either side of the ledge.
	_open(7, 16, 11, 6)   # rows 16-21: floor at row 22 (y 176)
	_water(7, 16, 11, 6)
	_open(22, 16, 7, 4)   # rows 16-19: floor at row 20 (y 160)
	_water(22, 19, 7, 1)

	# The sentry, out of sight from the ledge, in sight from the ground past the basin.
	_add(SENTRY_SCENE, "Sentry", Vector2(37 * TILE + 4, 16 * TILE), {"sight_range": 110.0, "fire_interval": 1.5})

	_finish_room(Vector2(20 * TILE, 16 * TILE), "res://tests/rooms/room_water_c.tscn")


## Water test room D (Stage W4): the water snake. 40 x 23 tiles (one screen), ground
## top at row 16 (y 128). Left to right:
##   - you start on the ground at the left (x 56)
##   - a narrow DEEP POOL (cols 9-13, floor y 176, surface y 136: 25 units): hold 1,
##     put the ball just under the surface, then ease it up (hold ↑): a snake rises
##     after it. Burst up from the bottom instead and it tears
##   - a low PILLAR (cols 14-15, top y 112) with a CRATE on it, at about your height
##     and inside the ring: raise a snake beside it and steer right, and its head
##     sweeps the crate off onto the floor past it
##   - a wide POOL on the right (cols 22-35, floor y 176, surface y 136: 70 units)
##     to practise in: tall snakes, tearing, whips flung over the floor
func _build_room_water_d() -> void:
	_begin_room("RoomWaterD", "Water D: water snake (W4)",
		"Stage W4 water snake: hold 1, put the ball just under the pool's surface and ease it up (hold up): a snake follows it. Lift from deep and it tears. Raise one beside the crate on the pillar and steer right to sweep it off. Let go to fling the snake like a whip.")
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 40, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(39, 0, 1, 23)   # right wall
	_gray(0, 16, 40, 7)   # the ground, top at y 128

	# The narrow deep pool by the start, its surface 8 px under the ground.
	_open(9, 16, 5, 6)    # rows 16-21: floor at row 22 (y 176)
	_water(9, 17, 5, 5)
	# The pillar with the crate on it, just past the pool.
	_gray(14, 14, 2, 2)   # rows 14-15: top at y 112
	_add(CRATE_SCENE, "Crate1", Vector2(15 * TILE, 14 * TILE))

	# The wide practice pool on the right.
	_open(22, 16, 14, 6)
	_water(22, 17, 14, 5)

	_finish_room(Vector2(7 * TILE, 16 * TILE), "res://tests/rooms/room_water_d.tscn")


## Water test room E (grid ice, Stages I1 and I4, Water_bending.md §16 "Re-planned:
## grid ice"): BLOCKS and CRUMBLING steps. 50 x 23 tiles (400 px: it scrolls),
## ground top at row 16 (y 128). Left to right:
##   1. A small POOL (cols 5-8) and a LEDGE (cols 13-19) 40 px over the floor, too
##      high to jump. Hold 1, gather 4 units (the ball is a square), steer it against
##      the ledge's foot: the ghost is a solid 2x2 block. Freeze it (2): a step that
##      stays (it touches rock).
##   2. Past the ledge a small POOL (cols 21-22) and a SPIKE CHASM (cols 25-36, 96 px):
##      far too wide to jump. Steer a ball out over it and freeze it there: the ghost
##      is DASHED (it would hang in mid-air), so the block crumbles 2 s after you land
##      on it. Jump on, then on to the far side before it shatters.
func _build_room_water_e() -> void:
	_begin_room("RoomWaterE", "Water E: blocks and crumbling ice (I1, I4)",
		"Grid ice. Hold 1 and gather: the ball is a square, and a ghost shows the ice 2 would make, snapped to the tiles (red cells are blocked). Freeze a 2x2 block against the ledge's foot: ice touching rock stays. Over the chasm the ghost is dashed: ice hanging in mid-air crumbles 2 s after you touch it. Freeze a step over the spikes, land on it and jump on before it breaks.",
		Vector2(400, 180))
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 50, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(49, 0, 1, 23)   # right wall
	_gray(0, 16, 50, 7)   # the ground, top at y 128

	# 1. The small pool and the ledge.
	_open(5, 16, 4, 3)    # rows 16-18: floor y 152
	_water(5, 16, 4, 3)
	_gray(13, 11, 7, 5)   # rows 11-15: top at y 88, 40 px over the floor

	# 2. A pool by the chasm, and the chasm.
	_open(21, 16, 2, 3)
	_water(21, 16, 2, 3)
	_open(25, 16, 12, 2)  # the chasm, rows 16-17
	_spikes("ChasmSpikes", 25, 17, 12)

	_finish_room(Vector2(3 * TILE, 16 * TILE), "res://tests/rooms/room_water_e.tscn")


## Water test room F (grid ice, Stage I2): SNAKE LINES. A frozen snake is the tiles
## under its trail (flat runs full tiles, 45° runs slope tiles, gentle runs the
## 22.5° pairs, upright runs a column). 60 x 23 tiles (480 px: it scrolls), ground
## top at row 16 (y 128). Left to right:
##   1. A PLATEAU (cols 1-8, top y 96) with a deep POOL in it (cols 5-7, surface
##      y 96; col 8 is its wall), then a SPIKE PIT (cols 9-18, 80 px) too wide to
##      jump. Raise a snake (1 into the water, then hold 3 and lift) a tile up, draw
##      it right and then down the slope over the pit, and freeze it (2): a slide (it
##      rests on the pool: it stays). Ride it down and jump off its end.
##   2. A SHELF (cols 30-35, top y 104) with a CRATE on it and a one-tile POOL (col 34,
##      its surface a tile under the shelf's top; its lip col 35), then a PRESSURE PLATE
##      (x 344) wired to a DOOR (col 50). Draw a snake up a tile (its column fills the
##      pool's mouth flush with the shelf), right over the lip and down at 45° to the
##      ground; freeze it; gust the crate (Z) along the shelf: it slides down the ice
##      onto the plate and the door opens.
func _build_room_water_f() -> void:
	_begin_room("RoomWaterF", "Water F: snake lines (I2)",
		"Grid ice: a frozen snake becomes the tiles under its trail (the ghost shows them): flat runs, 45 degree and gentle slopes, upright columns. Raise a snake from the plateau pool (1 in the water, hold 3, lift), draw it up, right and down over the spike pit, freeze it (2): slide down it (hold down: belly slide) and jump off its end. On the shelf, draw a 45 degree slope down to the ground and gust the crate (Z) down it onto the plate.",
		Vector2(480, 180))
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 60, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(59, 0, 1, 23)   # right wall
	_gray(0, 16, 60, 7)   # the ground, top at y 128

	# 1. Plateau with its pool, then the spike pit.
	_gray(1, 12, 8, 4)    # the plateau, rows 12-15: top at y 96
	_open(5, 12, 3, 7)    # the pool, rows 12-18: floor at y 152 (col 8 is its wall)
	_water(5, 12, 3, 7)
	_open(9, 16, 10, 2)   # the pit, rows 16-17
	_spikes("PitSpikes", 9, 17, 10)

	# 2. The shelf with the crate and its one-tile pool, the plate and its door.
	_gray(30, 13, 6, 3)   # rows 13-15: top at y 104
	_open(34, 13, 1, 5)   # the one-tile pool, into the ground: floor at y 144
	_water(34, 14, 1, 4)  # surface at y 112, a tile under the shelf's top
	_add(CRATE_SCENE, "SlideCrate", Vector2(31 * TILE, 13 * TILE))
	var plate: Node2D = _add(PLATE_SCENE, "SlidePlate", Vector2(43 * TILE, 16 * TILE), {"plate_width": 24.0})
	var door: Node2D = _add(DOOR_SCENE, "SlideDoor", Vector2(50 * TILE, 1 * TILE), {"door_size": Vector2(TILE, 15 * TILE)})
	var door_switches: Array[Switch] = [plate as Switch]
	door.set("switches", door_switches)

	_finish_room(Vector2(3 * TILE, 12 * TILE), "res://tests/rooms/room_water_f.tscn")


## Water test room G (grid ice, Stages I2 and I3): WATERFALL WALLS and RAFTS on clean
## water. 60 x 23 tiles (480 px: it scrolls), ground top at row 16 (y 128). Left to
## right:
##   1. A WATERFALL from a source under the ceiling (x 84) into a drained BASIN
##      (cols 8-11, one tile deep), and a TOWER (cols 13-18, top y 48) 80 px up, with
##      a 16 px gap between the fall and the tower. Hold 1 and steer the ball into the
##      falling water: the ghost is one tall column. Freeze it (2): an ice wall from
##      the spout to the basin (the spout stops). Wall-jump up between the ice and the
##      tower (ice gives no grip: you slide down it faster).
##   2. A wide clean POOL (cols 22-41, surface y 136). Gather, rest the ball on the
##      surface: the ghost is a flat slab. Freeze it (2): a RAFT. Ride it and gust (Z)
##      back the way you came: the raft takes the recoil.
func _build_room_water_g() -> void:
	_begin_room("RoomWaterG", "Water G: waterfall walls and rafts (I2, I3)",
		"Grid ice. Steer the ball into the waterfall: the ghost is one tall column. Freeze it (2): an ice wall from the spout to the basin, and the spout stops. Wall-jump up between the ice and the tower. Then rest a ball on the big pool's surface: the ghost is a flat slab; freeze it into a RAFT (rafts work on any water), ride it and gust back (Z) to push it across.",
		Vector2(480, 180))
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 60, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(59, 0, 1, 23)   # right wall
	_gray(0, 16, 60, 7)   # the ground, top at y 128

	# 1. The waterfall, its drained basin, and the tower.
	_add(WATER_SOURCE_SCENE, "WaterfallSource", Vector2(10 * TILE + 4, 2 * TILE), {"rate": 2.0, "pour_width": 4.0})
	_open(8, 16, 4, 1)    # the basin, row 16: floor y 136
	_add(WATER_SINK_SCENE, "BasinDrain", Vector2(8 * TILE, 16 * TILE), {"sink_size": Vector2(32, 8)})
	_gray(13, 6, 6, 10)   # the tower, rows 6-15: top at y 48

	# 2. The wide clean pool.
	_open(22, 16, 20, 4)  # rows 16-19: floor y 160
	_water(22, 17, 20, 3)  # surface at y 136

	_finish_room(Vector2(3 * TILE, 16 * TILE), "res://tests/rooms/room_water_g.tscn")


## Water test room H (Stage W7a): black water, rafts and painted ice slopes.
## 73 x 23 tiles (584 px wide: it scrolls). Ground top at row 16 (y 128). Left to right:
##   - a clean POOL (cols 3-6) by a BLACK CHANNEL (cols 9-24, 128 px wide, its surface
##     at y 136, 8 px under the ground). Stand between them (cols 7-8), gather from
##     the pool, steer the ball down onto the black surface and freeze it (2): a raft.
##     Hop on and gust back toward the start (Z): the raft takes the recoil across.
##   - a small clean pool (cols 27-28) by a BLACK PIT (cols 30-37, 64 px: too wide to
##     jump; its surface at y 144, 16 px down). Carry a ball out over it, set it down
##     on the black surface and freeze it (2): a raft, a stepping stone.
##   - painted ICE SLOPES: two steps and a plateau (y 80), then six 22.5° pairs down
##     to the ground (y 128), two tiles of flat ice, a 45° ramp two tiles high, and a
##     56 px spike pit (the ramp is ice, so you only reach it sliding). Slide down and
##     launch off the ramp.
func _build_room_water_h() -> void:
	_begin_room("RoomWaterH", "Water H: black water and rafts (W7a)",
		"Stage W7a. BLACK water kills, can't be gathered or frozen. Carry clean water to it: hold 1 by the left pool, gather, steer the ball down onto the black channel (the ghost is a flat slab) and freeze it (2) into a RAFT. Ride it and gust back (Z): the raft takes the recoil. Jumping off pushes it back too. Then carry a ball over the black pit, set it down on the surface and freeze it: a stepping stone. Last, painted ice slopes (22.5 degrees down, a 45 degree ramp): slide down, keep your speed on the flat ice and launch off the ramp over the spikes.",
		Vector2(584, 180))
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 73, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(72, 0, 1, 23)   # right wall
	_gray(0, 16, 73, 7)   # the ground, top at y 128

	# 1. The clean pool and the black channel.
	_open(3, 16, 4, 3)    # rows 16-18: floor at y 152
	_water(3, 16, 4, 3)
	_open(9, 16, 16, 4)   # rows 16-19: floor at y 160
	_water(9, 17, 16, 3, true)  # surface at y 136

	# 2. A small clean pool, then the black pit.
	_open(27, 16, 2, 3)
	_water(27, 16, 2, 3)
	_open(30, 16, 8, 4)
	_water(30, 18, 8, 2, true)  # surface at y 144: deep enough that a slick stays in it

	# 3. Painted ice slopes down to a ramp over a spike pit. Everything under the
	# slopes is ice too, so the whole run is ONE patch drawn as one piece of glass.
	# One continuous 22.5° run: a 45° drop would be a fall (you leave it running) and
	# landing throws away the speed you fell with.
	_gray(38, 14, 2, 2)   # a step, top y 112
	_gray(40, 12, 2, 4)   # a higher step, top y 96
	_gray(42, 10, 3, 6)   # the plateau, top y 80
	# Six 22.5° pairs (cols 45-56, rows 10-15), each a high then a low tile, with ice
	# under them down to the ground.
	for pair: int in 6:
		_ice_tile(45 + pair * 2, 10 + pair, IceLayer.GENTLE_UP_LEFT_HIGH)
		_ice_tile(46 + pair * 2, 10 + pair, IceLayer.GENTLE_UP_LEFT_LOW)
		_ice(45 + pair * 2, 11 + pair, 2, 5 - pair)
	_ice(45, 16, 16, 1)   # the ground under it all, and flat ice (cols 57-58)
	_ice_tile(59, 15, IceLayer.SLOPE_UP_RIGHT)  # the ramp, two 45° tiles up to y 112
	_ice_tile(60, 14, IceLayer.SLOPE_UP_RIGHT)
	_ice(60, 15, 1, 1)
	_open(61, 16, 7, 2)   # the pit, cols 61-67 (56 px)
	_spikes("PitSpikes", 61, 17, 7)

	_finish_room(Vector2(2 * TILE, 16 * TILE), "res://tests/rooms/room_water_h.tscn")


## Water test room I (Stage W7b): currents and floating things.
## 67 x 23 tiles (536 px wide: it scrolls). Ground top at row 16 (y 128). Left to right:
##   - a STREAM (cols 3-22, floor y 160, surface y 144): a source at its left end, an
##     overflow drain at its right end, a FLOW current (50 px/s, right) over all of
##     it, spikes on its floor (cols 11-15) and a crate floating at its start. Step
##     in: you drift right; ride the crate over the spikes.
##   - a clean pool (cols 25-26) by a BLACK CHANNEL (cols 28-47, surface y 136) with a
##     LOOP current (40 px/s): its surface runs right and its bottom back, so it
##     carries a raft without tilting. Freeze a raft (hold 1 at the pool, steer the
##     ball onto the black water, 2) and surf it to the far bank.
##   - a deep LOOP POOL (cols 52-62, floor y 160, surface y 112, 48 px deep) between
##     two ledges (top y 96), a loop current (40 px/s) over it: swim at the surface
##     and you drift right; dive to the bottom and you're carried back left. A
##     WATERFALL pours into its right part (a floor drain takes as much as it pours).
##     A LEAF PILE on the left ledge (gust it onto the pool: the leaves float and
##     drift), and a LEAF PLATFORM on a vertical rail from the pool's floor up: it
##     floats at the surface and bobs.
func _build_room_water_i() -> void:
	_begin_room("RoomWaterI", "Water I: currents (W7b)",
		"Stage W7b. CURRENTS move the water, and what floats rides it. Step into the stream: it carries you right; ride the floating crate over the spiked floor. On the black channel a loop current runs along the surface: freeze a raft (hold 1 at the small pool, steer the ball onto the black water, 2) and surf it across. In the deep pool the surface runs right and the bottom runs back: swim on top, then dive. Swim under the waterfall: it pushes you down. Gust the leaves onto the pool: they float and drift. The leaf platform floats on its rail.",
		Vector2(536, 180))
	room.painted_ground = true
	room.water_allowed = true
	room.earth_allowed = false
	_gray(0, 0, 67, 1)    # ceiling
	_gray(0, 0, 1, 23)    # left wall
	_gray(66, 0, 1, 23)   # right wall
	_gray(0, 16, 67, 7)   # the ground, top at y 128

	# 1. The stream: source, flow current, spikes on its floor, a crate, an overflow.
	# Real flow: a stream runs only as fast as its source feeds it (rate / depth), so
	# it's shallow (16 px) and fed hard (10 units/s ~ 40 px/s); the overflow at its end
	# takes it all back out.
	_open(3, 16, 20, 4)   # rows 16-19: floor at y 160
	_water(3, 18, 20, 2)  # surface at y 144
	_spikes("StreamSpikes", 11, 19, 5)
	_add(WATER_SOURCE_SCENE, "StreamSource", Vector2(4 * TILE + 4, 19 * TILE), {"rate": 10.0, "launch_velocity": Vector2.ZERO})
	_add(WATER_SINK_SCENE, "StreamOverflow", Vector2(22 * TILE, 143), {"sink_size": Vector2(8, 2), "max_rate": 20.0})
	_add(CURRENT_ZONE_SCENE, "StreamCurrent", Vector2(3 * TILE, 16 * TILE), {"zone_size": Vector2(20 * TILE, 4 * TILE), "strength": 50.0})
	_add(CRATE_SCENE, "StreamCrate", Vector2(6 * TILE, 17 * TILE))

	# 2. A small clean pool, then the black channel with a loop current.
	_open(25, 16, 2, 3)
	_water(25, 16, 2, 3)
	_open(28, 16, 20, 4)
	_water(28, 17, 20, 3, true)  # surface at y 136
	_add(CURRENT_ZONE_SCENE, "ChannelCurrent", Vector2(28 * TILE, 16 * TILE),
		{"zone_size": Vector2(20 * TILE, 4 * TILE), "strength": 40.0, "mode": CurrentZone.Mode.LOOP})

	# 3. The deep loop pool between two ledges, with a waterfall, leaves and a leaf platform.
	_gray(49, 12, 3, 4)   # the left ledge, rows 12-15: top at y 96
	_gray(63, 12, 3, 4)   # the right ledge
	_open(52, 12, 11, 8)  # rows 12-19: floor at y 160
	_water(52, 14, 11, 6) # surface at y 112
	_add(CURRENT_ZONE_SCENE, "PoolCurrent", Vector2(52 * TILE, 12 * TILE),
		{"zone_size": Vector2(11 * TILE, 8 * TILE), "strength": 40.0, "mode": CurrentZone.Mode.LOOP})
	_add(WATER_SOURCE_SCENE, "Waterfall", Vector2(61 * TILE, 2 * TILE), {"rate": 2.0, "pour_width": 4.0})
	_add(WATER_SINK_SCENE, "PoolDrain", Vector2(61 * TILE, 19 * TILE), {"sink_size": Vector2(8, 8), "max_rate": 2.0})
	_add(LEAF_PILE_SCENE, "LedgeLeaves", Vector2(50 * TILE + 4, 12 * TILE), {"pile_width": 20.0, "leaf_count": 30})
	_add(LEAF_PLATFORM_SCENE, "FloatingLeaf", Vector2(55 * TILE, 19 * TILE), {"leaf_width": 24.0, "travel": Vector2(0, -64)})

	_finish_room(Vector2(1 * TILE + 4, 16 * TILE), "res://tests/rooms/room_water_i.tscn")

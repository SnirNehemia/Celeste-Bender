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
##   - resources/tiles/water_tileset.tres  (Stage W1) the water tile: see-through blue,
##                                     NO collision (water isn't solid). The picture is
##                                     stored inside the .tres. Only written when missing.
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
## only those, e.g. `-- water_a` (names: water_a, water_b).

const WATER_LAYER_SCRIPT: Script = preload("res://scenes/objects/water/water_layer.gd")
const WATER_SOURCE_SCENE: PackedScene = preload("res://scenes/objects/water/water_source.tscn")
const WATER_SINK_SCENE: PackedScene = preload("res://scenes/objects/water/water_sink.tscn")
const WATER_WHEEL_SCENE: PackedScene = preload("res://scenes/objects/water/water_wheel.tscn")
## Water tile picture: the body color with a light top line (the surface), see-through
## so the editor shows what's behind it.
const WATER_TILE_COLOR: Color = Color(0.18, 0.5, 0.82, 0.6)
const WATER_TILE_LINE_COLOR: Color = Color(0.75, 0.89, 1.0, 0.8)

## Water cells of the room being built (a set: Vector2i -> true).
var water_cells: Dictionary = {}


func _ready() -> void:
	log_prefix = "[BuildWaterRooms]"
	_load_or_create_water_tileset()
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if wanted.is_empty() or wanted.has("water_a"):
		_build_room_water_a()
	if wanted.is_empty() or wanted.has("water_b"):
		_build_room_water_b()
	print("[BuildWaterRooms] Done.")
	get_tree().quit()


# --- Water --------------------------------------------------------------------------

func _make_water_image() -> Image:
	var image: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	image.fill(WATER_TILE_COLOR)
	for x: int in TILE:
		image.set_pixel(x, 0, WATER_TILE_LINE_COLOR)
	return image


func _load_or_create_water_tileset() -> void:
	if ResourceLoader.exists(WaterLayer.TILESET_PATH):
		return
	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE, TILE)
	# No physics layer at all: the player, crates and rocks pass through water tiles.
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_make_water_image())
	source.texture_region_size = Vector2i(TILE, TILE)
	new_tile_set.add_source(source, 0)
	source.create_tile(WaterLayer.WATER_TILE)
	ResourceSaver.save(new_tile_set, WaterLayer.TILESET_PATH)
	print("[BuildWaterRooms] Wrote %s" % WaterLayer.TILESET_PATH)


## Paints water into a rectangle of tiles (column, row, width, height).
func _water(column: int, row: int, width: int, height: int) -> void:
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			water_cells[Vector2i(x, y)] = true


func _begin_room(node_name: String, title: String, description: String,
		size_px: Vector2 = Vector2(320, 180)) -> void:
	super(node_name, title, description, size_px)
	water_cells.clear()


## The Earth generator's hook: our extra layer is the "Water" layer, only in rooms
## with water painted.
func _make_extra_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	if water_cells.is_empty():
		return layers
	var water: TileMapLayer = TileMapLayer.new()
	water.name = "Water"
	water.set_script(WATER_LAYER_SCRIPT)
	water.tile_set = load(WaterLayer.TILESET_PATH) as TileSet
	for cell: Vector2i in water_cells:
		if not cell_kinds.has(cell):  # never water inside rock
			water.set_cell(cell, 0, WaterLayer.WATER_TILE)
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

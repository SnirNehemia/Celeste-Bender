extends Node
## tools/build_earth_rooms.gd — generator for the Earth chapter's tiles and test rooms.
## Same idea as tools/build_rooms.gd (read its header): Godot itself paints the
## TileMapLayers and saves the scenes, so the files are what the editor would write.
##
## It writes:
##   - resources/tiles/earth_tileset.tres  the earth tile (8x8, brown-yellow with
##                                          speckles), solid on physics layer 1.
##                                          The picture is stored INSIDE the .tres
##                                          (an ImageTexture), so no PNG import step.
##                                          Only written when missing.
##   - tests/rooms/room_earth_a.tscn        Stage E1/E2 test room (see _build_room_earth_a)
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_earth_rooms.tscn
## Running it again OVERWRITES the test room (not the tileset). Once you edit a room
## in the editor, edit it there instead.
##
## Layout units: tiles (8 px), (column, row) from the room's top-left tile.

const TILE: int = 8
const EARTH_TILESET_PATH: String = "res://resources/tiles/earth_tileset.tres"
const GRAY_TILESET_PATH: String = "res://resources/tiles/placeholder_tileset.tres"
## Atlas coordinates of the gray tiles (see build_rooms.gd).
const TILE_PLAIN: Vector2i = Vector2i(0, 0)
const TILE_TOP_EDGE: Vector2i = Vector2i(1, 0)
## The single earth tile in the earth tileset.
const TILE_EARTH: Vector2i = Vector2i(0, 0)

const ROOM_SCRIPT: Script = preload("res://scenes/rooms/room_base.gd")
const EARTH_LAYER_SCRIPT: Script = preload("res://scenes/objects/earth/earth_layer.gd")

## Room being built and its cells: gray solids and earth (Dictionaries used as sets).
var room: Room
var gray_cells: Dictionary = {}
var earth_cells: Dictionary = {}


func _ready() -> void:
	_load_or_create_earth_tileset()
	_build_room_earth_a()
	print("[BuildEarthRooms] Done.")
	get_tree().quit()


# --- Tiles -----------------------------------------------------------------------

## The earth tile picture: fresh-earth color with a few darker and lighter speckles
## (fixed positions, so every tile looks the same and the ground reads as one material).
func _make_earth_image() -> Image:
	var image: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	image.fill(EarthLayer.FRESH_COLOR)
	var dark_speck: Color = EarthLayer.FRESH_COLOR.lerp(EarthLayer.USED_COLOR, 0.35)
	var light_speck: Color = EarthLayer.FRESH_COLOR.lightened(0.18)
	for pixel: Vector2i in [Vector2i(1, 1), Vector2i(5, 2), Vector2i(2, 5), Vector2i(6, 6), Vector2i(4, 4)]:
		image.set_pixelv(pixel, dark_speck)
	for pixel: Vector2i in [Vector2i(3, 1), Vector2i(0, 4), Vector2i(6, 4), Vector2i(3, 7)]:
		image.set_pixelv(pixel, light_speck)
	return image


func _load_or_create_earth_tileset() -> void:
	if ResourceLoader.exists(EARTH_TILESET_PATH):
		return
	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE, TILE)
	# Solid on layer 1 ("world"), like the gray tiles: earth IS ground.
	new_tile_set.add_physics_layer()
	new_tile_set.set_physics_layer_collision_layer(0, 1)
	new_tile_set.set_physics_layer_collision_mask(0, 0)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_make_earth_image())
	source.texture_region_size = Vector2i(TILE, TILE)
	new_tile_set.add_source(source, 0)
	var half: float = TILE / 2.0
	source.create_tile(TILE_EARTH)
	var tile_data: TileData = source.get_tile_data(TILE_EARTH, 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	]))
	ResourceSaver.save(new_tile_set, EARTH_TILESET_PATH)
	print("[BuildEarthRooms] Wrote %s" % EARTH_TILESET_PATH)


# --- Building blocks -------------------------------------------------------------

func _begin_room(node_name: String, title: String, description: String) -> void:
	room = _new_room(node_name)
	room.display_title = title
	room.room_size = Vector2(320, 180)
	room.editor_description = description
	gray_cells.clear()
	earth_cells.clear()


func _new_room(node_name: String) -> Room:
	var root: Node2D = Node2D.new()
	root.name = node_name
	root.set_script(ROOM_SCRIPT)
	return root as Room


## Gray rock rectangle (column, row, width, height). Erases earth there.
func _gray(column: int, row: int, width: int, height: int) -> void:
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			gray_cells[Vector2i(x, y)] = true
			earth_cells.erase(Vector2i(x, y))


## Earth rectangle (column, row, width, height). Replaces gray there.
func _earth(column: int, row: int, width: int, height: int) -> void:
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			earth_cells[Vector2i(x, y)] = true
			gray_cells.erase(Vector2i(x, y))


func _finish_room(spawn_px: Vector2, path: String) -> void:
	var tiles: TileMapLayer = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = load(GRAY_TILESET_PATH) as TileSet
	for cell: Vector2i in gray_cells:
		var cell_above: Vector2i = cell + Vector2i.UP
		var is_top: bool = not gray_cells.has(cell_above) and not earth_cells.has(cell_above) and cell.y > 0
		tiles.set_cell(cell, 0, TILE_TOP_EDGE if is_top else TILE_PLAIN)
	room.add_child(tiles)
	tiles.owner = room

	var earth: TileMapLayer = TileMapLayer.new()
	earth.name = "Earth"
	earth.set_script(EARTH_LAYER_SCRIPT)
	earth.tile_set = load(EARTH_TILESET_PATH) as TileSet
	for cell: Vector2i in earth_cells:
		earth.set_cell(cell, 0, TILE_EARTH)
	room.add_child(earth)
	earth.owner = room

	var spawn: Marker2D = Marker2D.new()
	spawn.name = "SpawnPoint"
	spawn.position = spawn_px
	room.add_child(spawn)
	spawn.owner = room

	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(room)
	if pack_error != OK:
		push_error("[BuildEarthRooms] Could not pack %s: %s" % [path, error_string(pack_error)])
		return
	var save_error: Error = ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("[BuildEarthRooms] Could not save %s: %s" % [path, error_string(save_error)])
		return
	print("[BuildEarthRooms] Wrote %s" % path)
	room.free()


# --- Rooms -------------------------------------------------------------------------

## Earth test room A (Stages E1-E2): one screen, Earth-only, with every surface case:
## earth floor with a gray patch, a 2x2 earth step, a floating earth block (top, sides,
## underside), earth walls left and right, earth on the ceiling meeting the right wall
## (inner corner), a gray ledge with an earth top, and a plain gray
## ledge (never bendable). Reachable by jumping: step -> stepping stone -> block ->
## earth-topped ledge -> jump right to the earth wall and slide down it.
func _build_room_earth_a() -> void:
	_begin_room("RoomEarthA", "Earth A - Ground Test",
		"Stage E1/E2 test room. Earth-only (Air off). Earth on floors, walls, ceiling. F1 shows what earth you touch. Hold A on earth to bend: the shadow crawls, release to spend the tile under it (E2 placeholder). F3 draws the path. R resets every tile.")
	room.air_allowed = false
	# Gray frame: ceiling, side walls, floor body.
	_gray(0, 0, 40, 1)
	_gray(0, 0, 1, 23)
	_gray(39, 0, 1, 23)
	_gray(0, 20, 40, 3)
	# Earth floor surface, with a 2-tile gray patch at columns 12-13 (shadow crosses it).
	_earth(1, 20, 38, 1)
	_gray(12, 20, 2, 1)
	# 2x2 earth step on the floor, with a 3-tile gap before the stepping stone so you can
	# walk back left under the stone and hop onto the step.
	_earth(16, 18, 2, 2)
	# Stepping stone up to the floating block (each hop is under a full jump, 30 px).
	_earth(21, 16, 2, 2)
	# Earth walls: left (rows 6-17, so its underside is open) and right (rows 1-19).
	_earth(1, 6, 1, 12)
	_earth(38, 1, 1, 19)
	# Earth hanging from the ceiling, meeting the right wall in an inner corner.
	_earth(26, 1, 12, 1)
	# Floating earth block: top, both sides and underside are earth faces.
	_earth(24, 13, 7, 2)
	# Gray ledge with an earth top: the shadow crosses its gray side (pale, can't erupt).
	_gray(31, 11, 5, 1)
	_earth(31, 10, 5, 1)
	# Plain gray ledge: never bendable.
	_gray(5, 12, 5, 1)
	_finish_room(Vector2(24, 160), "res://tests/rooms/room_earth_a.tscn")

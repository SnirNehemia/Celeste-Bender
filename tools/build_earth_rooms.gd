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
##   - resources/tiles/grass_tileset.tres  the grass tiles (8x8, green: a "top" tile
##                                          with bright blades and a plain one),
##                                          solid on layer 1. Same storage. Only
##                                          written when missing.
##   - tests/rooms/room_earth_a.tscn        Stage E1/E2 test room (see _build_room_earth_a)
##   - tests/rooms/room_earth_b.tscn        Stage E3 column test room (_build_room_earth_b)
##   - tests/rooms/room_earth_c.tscn        Stage E4 boulder test room (_build_room_earth_c)
##   - tests/rooms/room_earth_d.tscn        Stage E4c hidden chamber room (_build_room_earth_d)
##   - tests/rooms/room_earth_e.tscn        Stage E5 snake room (_build_room_earth_e)
##   - tests/rooms/room_earth_f.tscn        one-key column/snake experiment (_build_room_earth_f)
##   - tests/rooms/room_mixed_a.tscn        Air + Earth together (_build_room_mixed_a)
##   - tests/rooms/room_mixed_b.tscn        Air + Earth vs enemies (_build_room_mixed_b)
##                                          Both mixed rooms are in tests/mixed_test_world.tscn.
##
## Three kinds of solid ground (Earth_bending.md §2, §11):
##   earth  (layer "Earth", EarthLayer script) bendable once; the shadow crawls over it
##   grass  (layer "Grass", GrassLayer script) not bendable, but the shadow crawls
##          over it. The usual ground of Earth rooms. Blades on top sway with wind,
##          gusts and the player.
##   gray   (layer "Tiles")         not bendable and BLOCKS the shadow. Used sparingly,
##          e.g. under spikes, so a bend can't reach across a spike pit.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_earth_rooms.tscn
## Running it again OVERWRITES the test rooms (not the tileset). Once you edit a room
## in the editor, edit it there instead. Pass room names after `--` to build only
## those, e.g. `-- earth_b mixed_a` (names: earth_a, earth_b, earth_c, earth_d, earth_e,
## earth_f, mixed_a, mixed_b).
##
## Layout units: tiles (8 px), (column, row) from the room's top-left tile.

const TILE: int = 8
const EARTH_TILESET_PATH: String = "res://resources/tiles/earth_tileset.tres"
const GRAY_TILESET_PATH: String = "res://resources/tiles/placeholder_tileset.tres"
const GRASS_TILESET_PATH: String = "res://resources/tiles/grass_tileset.tres"
## Atlas coordinates of the gray tiles (see build_rooms.gd).
const TILE_PLAIN: Vector2i = Vector2i(0, 0)
const TILE_TOP_EDGE: Vector2i = Vector2i(1, 0)
## The single earth tile in the earth tileset.
const TILE_EARTH: Vector2i = Vector2i(0, 0)
## Grass tileset atlas: a top tile (open air above: bright blades) and a plain one.
const TILE_GRASS_TOP: Vector2i = Vector2i(0, 0)
const TILE_GRASS_PLAIN: Vector2i = Vector2i(1, 0)
## Grass colors: bright blades (the same green as the moving blades), the green body,
## and darker speckles.
const GRASS_BLADE_COLOR: Color = GrassLayer.BLADE_COLOR
const GRASS_BODY_COLOR: Color = Color(0.25, 0.46, 0.22)
const GRASS_SPECK_COLOR: Color = Color(0.19, 0.36, 0.17)
## Kinds of cell, for cell_kinds.
enum Kind { GRAY, EARTH, GRASS }

const ROOM_SCRIPT: Script = preload("res://scenes/rooms/room_base.gd")
const EARTH_LAYER_SCRIPT: Script = preload("res://scenes/objects/earth/earth_layer.gd")
const GRASS_LAYER_SCRIPT: Script = preload("res://scenes/objects/earth/grass_layer.gd")
const HIDDEN_LAYER_SCRIPT: Script = preload("res://scenes/objects/earth/hidden_layer.gd")
## The "Hidden" layer's tint in the EDITOR (purple, see-through), so hidden chambers
## stand out while painting. At runtime the GroundPainter hides the layer's drawing.
const HIDDEN_EDITOR_TINT: Color = Color(0.7, 0.4, 1.0, 0.6)
const SPIKES_SCENE: PackedScene = preload("res://scenes/objects/spikes.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/objects/crate.tscn")
const WISP_SCENE: PackedScene = preload("res://scenes/enemies/wisp.tscn")
const CRYSTAL_SCENE: PackedScene = preload("res://scenes/objects/wind_crystal.tscn")
const WIND_ZONE_SCENE: PackedScene = preload("res://scenes/objects/wind_zone.tscn")
const SENTRY_SCENE: PackedScene = preload("res://scenes/enemies/sentry.tscn")
## Spikes.Facing value for spikes sitting on a floor (see spikes.gd).
const FACING_UP: int = 0

## Room being built, and its solid cells: Vector2i cell -> Kind.
var room: Room
var cell_kinds: Dictionary = {}
## Hidden chamber cells of the room being built (a set: Vector2i -> true). Open air,
## drawn as earth until dug into (HiddenLayer).
var hidden_cells: Dictionary = {}


func _ready() -> void:
	_load_or_create_earth_tileset()
	_load_or_create_grass_tileset()
	# Command-line arguments after `--` pick rooms; none = build them all.
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if wanted.is_empty() or wanted.has("earth_a"):
		_build_room_earth_a()
	if wanted.is_empty() or wanted.has("earth_b"):
		_build_room_earth_b()
	if wanted.is_empty() or wanted.has("earth_c"):
		_build_room_earth_c()
	if wanted.is_empty() or wanted.has("earth_d"):
		_build_room_earth_d()
	if wanted.is_empty() or wanted.has("earth_e"):
		_build_room_earth_e()
	if wanted.is_empty() or wanted.has("earth_f"):
		_build_room_earth_f()
	if wanted.is_empty() or wanted.has("mixed_a"):
		_build_room_mixed_a()
	if wanted.is_empty() or wanted.has("mixed_b"):
		_build_room_mixed_b()
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


## The grass pictures, side by side in one 16x8 image: [top tile | plain tile].
## Top: two rows of bright blades over the green body. Plain: green with speckles.
func _make_grass_image() -> Image:
	var image: Image = Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
	image.fill(GRASS_BODY_COLOR)
	for x: int in TILE:
		image.set_pixel(x, 0, GRASS_BLADE_COLOR)
		image.set_pixel(x, 1, GRASS_BLADE_COLOR)
	# A few blades poking a pixel lower, so the edge isn't a ruler-straight line.
	for x: int in [1, 4, 6]:
		image.set_pixel(x, 2, GRASS_BLADE_COLOR)
	for pixel: Vector2i in [Vector2i(2, 5), Vector2i(6, 6), Vector2i(4, 4)]:
		image.set_pixelv(pixel, GRASS_SPECK_COLOR)
	for pixel: Vector2i in [Vector2i(1, 1), Vector2i(5, 2), Vector2i(2, 5), Vector2i(6, 6), Vector2i(3, 4)]:
		image.set_pixelv(pixel + Vector2i(TILE, 0), GRASS_SPECK_COLOR)
	return image


func _load_or_create_grass_tileset() -> void:
	if ResourceLoader.exists(GRASS_TILESET_PATH):
		return
	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE, TILE)
	new_tile_set.add_physics_layer()
	new_tile_set.set_physics_layer_collision_layer(0, 1)  # layer 1, "world"
	new_tile_set.set_physics_layer_collision_mask(0, 0)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_make_grass_image())
	source.texture_region_size = Vector2i(TILE, TILE)
	new_tile_set.add_source(source, 0)
	var half: float = TILE / 2.0
	for atlas_coords: Vector2i in [TILE_GRASS_TOP, TILE_GRASS_PLAIN]:
		source.create_tile(atlas_coords)
		var tile_data: TileData = source.get_tile_data(atlas_coords, 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
		]))
	ResourceSaver.save(new_tile_set, GRASS_TILESET_PATH)
	print("[BuildEarthRooms] Wrote %s" % GRASS_TILESET_PATH)


# --- Building blocks -------------------------------------------------------------

func _begin_room(node_name: String, title: String, description: String) -> void:
	room = _new_room(node_name)
	room.display_title = title
	room.room_size = Vector2(320, 180)
	room.editor_description = description
	cell_kinds.clear()
	hidden_cells.clear()


func _new_room(node_name: String) -> Room:
	var root: Node2D = Node2D.new()
	root.name = node_name
	root.set_script(ROOM_SCRIPT)
	return root as Room


## Rectangles (column, row, width, height) of one kind; each replaces whatever was
## painted there before.
## Gray rock: blocks the bend shadow.
func _gray(column: int, row: int, width: int, height: int) -> void:
	_paint(Kind.GRAY, column, row, width, height)


## Earth: bendable.
func _earth(column: int, row: int, width: int, height: int) -> void:
	_paint(Kind.EARTH, column, row, width, height)


## Grass: plain ground the shadow can cross.
func _grass(column: int, row: int, width: int, height: int) -> void:
	_paint(Kind.GRASS, column, row, width, height)


## Open air (pits): erases whatever was there.
func _open(column: int, row: int, width: int, height: int) -> void:
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			cell_kinds.erase(Vector2i(x, y))


## A hidden chamber: open air (erases whatever was there) that looks like earth until
## a dug hole reaches it.
func _hidden(column: int, row: int, width: int, height: int) -> void:
	_open(column, row, width, height)
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			hidden_cells[Vector2i(x, y)] = true


func _paint(kind: Kind, column: int, row: int, width: int, height: int) -> void:
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			cell_kinds[Vector2i(x, y)] = kind


## The usual frame of a one-screen room in grass: ceiling, side walls, 3-row floor body.
func _grass_frame() -> void:
	_grass(0, 0, 40, 1)
	_grass(0, 0, 1, 23)
	_grass(39, 0, 1, 23)
	_grass(0, 20, 40, 3)


## A spike pit `width` tiles wide from `column`, cut into the floor (rows 20-21),
## with spikes on its bottom and GRAY rock under them: the bend shadow can wrap
## down into the pit but not cross it, so you can't raise a column on the far side.
func _spike_pit(node_name: String, column: int, width: int) -> void:
	_open(column, 20, width, 2)
	_gray(column, 22, width, 1)
	_spikes(node_name, column, 21, width)


## Instances a scene as a child of the room and sets its properties (same as
## build_rooms.gd). `owner` must be the room root, or pack() would leave it out.
func _add(scene: PackedScene, node_name: String, position_px: Vector2, properties: Dictionary = {}) -> Node2D:
	# GEN_EDIT_STATE_INSTANCE = instance it the way the editor does, so pack() saves
	# only the properties we change, not a full copy of the object.
	var node: Node2D = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	node.name = node_name
	node.position = position_px
	for property: String in properties:
		node.set(property, properties[property])
	room.add_child(node)
	node.owner = room
	return node


## A strip of up-facing spikes starting at tile (column, row), `count` tiles long.
func _spikes(node_name: String, column: int, row: int, count: int) -> void:
	_add(SPIKES_SCENE, node_name, Vector2(column * TILE, row * TILE), {
		"facing": FACING_UP, "tile_count": count,
	})


func _finish_room(spawn_px: Vector2, path: String) -> void:
	var tiles: TileMapLayer = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = load(GRAY_TILESET_PATH) as TileSet
	var grass: TileMapLayer = TileMapLayer.new()
	grass.name = "Grass"
	grass.set_script(GRASS_LAYER_SCRIPT)  # the swaying blades
	grass.tile_set = load(GRASS_TILESET_PATH) as TileSet
	# A persistent group (second argument true) is saved in the scene file. It tells
	# EarthLayer that the bend shadow may cross this layer's tiles.
	grass.add_to_group(EarthLayer.SHADOW_PASSABLE_GROUP, true)
	var earth: TileMapLayer = TileMapLayer.new()
	earth.name = "Earth"
	earth.set_script(EARTH_LAYER_SCRIPT)
	earth.tile_set = load(EARTH_TILESET_PATH) as TileSet
	for cell: Vector2i in cell_kinds:
		# The tile under open air gets the "top" look: walkable surfaces stand out.
		var is_top: bool = not cell_kinds.has(cell + Vector2i.UP) and cell.y > 0
		match cell_kinds[cell]:
			Kind.GRAY:
				tiles.set_cell(cell, 0, TILE_TOP_EDGE if is_top else TILE_PLAIN)
			Kind.GRASS:
				grass.set_cell(cell, 0, TILE_GRASS_TOP if is_top else TILE_GRASS_PLAIN)
			Kind.EARTH:
				earth.set_cell(cell, 0, TILE_EARTH)
	var layers: Array[TileMapLayer] = [tiles, grass, earth]
	# Only rooms with hidden chambers get a "Hidden" layer.
	if not hidden_cells.is_empty():
		var hidden: TileMapLayer = TileMapLayer.new()
		hidden.name = "Hidden"
		hidden.set_script(HIDDEN_LAYER_SCRIPT)
		hidden.tile_set = load(EARTH_TILESET_PATH) as TileSet
		hidden.collision_enabled = false  # open air, even while it looks like earth
		hidden.self_modulate = HIDDEN_EDITOR_TINT
		for cell: Vector2i in hidden_cells:
			hidden.set_cell(cell, 0, TILE_EARTH)
		layers.append(hidden)
	# Drawn first (in this order), so objects appear in front of the ground.
	var layer_index: int = 0
	for layer: TileMapLayer in layers:
		room.add_child(layer)
		room.move_child(layer, layer_index)
		layer.owner = room
		layer_index += 1

	var spawn: Marker2D = Marker2D.new()
	spawn.name = "SpawnPoint"
	spawn.position = spawn_px
	room.add_child(spawn)
	room.move_child(spawn, layer_index)
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
## earth floor with a grass patch, a 2x2 earth step, a floating earth block (top, sides,
## underside), earth walls left and right, earth on the ceiling meeting the right wall
## (inner corner), a grass ledge with an earth top, and a plain gray
## ledge (never bendable, blocks the shadow). Reachable by jumping: step -> stepping stone -> block ->
## earth-topped ledge -> jump right to the earth wall and slide down it.
func _build_room_earth_a() -> void:
	_begin_room("RoomEarthA", "Earth A - Ground Test",
		"Stage E1/E2 test room. Earth-only (Air off). Earth on floors, walls, ceiling. F1 shows what earth you touch. Hold A on earth to bend: the shadow crawls over earth and grass (gray stops it), release to raise a column. F3 draws the path. R resets every tile.")
	room.air_allowed = false
	_grass_frame()
	# Earth floor surface, with a 2-tile grass patch at columns 12-13 (shadow crosses it).
	_earth(1, 20, 38, 1)
	_grass(12, 20, 2, 1)
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
	# Grass ledge with an earth top: the shadow crosses its grass side (pale, can't erupt).
	_grass(31, 11, 5, 1)
	_earth(31, 10, 5, 1)
	# Plain gray ledge: never bendable, and the shadow can't crawl onto it.
	_gray(5, 12, 5, 1)
	_finish_room(Vector2(24, 160), "res://tests/rooms/room_earth_a.tscn")


## Earth test room B (Stage E3, Earth Column). Earth-only. Left to right:
##   - a grass ledge 6 tiles up (48 px): too high for a jump (~28 px), easy for the
##     super jump (quick tap A, ~57 px)
##   - a 6-tile earth block: super-jump onto it, drop down its right side
##   - the side spring: stand between the block and the spike pit facing LEFT, hold
##     A, let the shadow climb the block's face one tile, release: the column shoots
##     out of the wall and throws you right, over the pit. (The pit's floor is gray:
##     a shadow sent right wraps into the pit and stops there.)
##   - an earth step and an overhanging earth block with a crate on top and a wisp
##     patrolling under it: from the top, send the shadow over the edge onto the
##     underside and release as the wisp passes under: the column crushes it against
##     the floor. A column under the crate throws it up.
##   - the right earth wall with a low earth ceiling against it: super-jump to it,
##     wall-slide, hold Up + A: the shadow climbs onto the ceiling and the column
##     slams you down.
func _build_room_earth_b() -> void:
	_begin_room("RoomEarthB", "Earth B - Columns",
		"Stage E3 test room. Earth-only. Quick tap A = super jump. A column out of a wall throws you sideways (only while it rises; then it's a platform you can bend from). Crush the wisp with a column from the overhang's underside. R resets.")
	room.air_allowed = false
	_grass_frame()
	# Earth floor surface.
	_earth(1, 20, 38, 1)
	# Super jump target: a grass ledge 6 tiles above the floor.
	_grass(1, 14, 5, 1)
	# The block between the start and the pit (its right face is the side spring's wall).
	_earth(10, 14, 2, 6)
	# Spike pit, 6 tiles wide (48 px): a side spring from the block's face clears it
	# (it throws you ~56 px before you drop to floor level).
	_spike_pit("PitSpikes", 15, 6)
	# Step up to the overhang, and the overhang (its underside 3 tiles above the floor).
	_earth(25, 18, 2, 2)
	_earth(29, 15, 6, 2)
	# Right earth wall with a low earth ceiling against it.
	_earth(38, 8, 1, 12)
	_earth(35, 9, 3, 1)
	_add(CRATE_SCENE, "Crate", Vector2(264, 120))
	_add(WISP_SCENE, "Wisp", Vector2(256, 160))
	_finish_room(Vector2(64, 160), "res://tests/rooms/room_earth_b.tscn")


## Earth test room C (Stages E4 + E4a, Boulder / rock). Earth-only. Left to right:
##   - a gray pillar: a rock thrown into it shatters
##   - a long earth floor to tear rocks from (each rock tears out 1 tile: a hole).
##     Columns 6-11 are THICK earth (2 tiles deep): tear the top tile, then the one
##     under it, to dig a 2-deep pit.
##   - a tall block with an EARTH left face (12 tiles = 96 px, far too high to jump):
##     throw rocks into it, they stick as one-tile steps; stand on one, stick the next
##     one higher (bend from a stuck rock, or wall-slide on the earth face and tear one
##     out of the wall itself). Grass on top: the goal.
## A column (A) raised in front of the wall makes a thrown boulder bounce back.
func _build_room_earth_c() -> void:
	_begin_room("RoomEarthC", "Earth C - Boulders",
		"Stage E4/E4a test room. Earth-only. Press S: a rock tears out of the ground ahead of you (leaving a hole) and hops over your head; press S again while it's white (coming back down level with you) for a perfect throw. Aim up-right to stick steps high on the earth wall; the gray pillar shatters rocks. Dig into the thick earth on the left. A column hardens the earth under it. R resets.")
	room.air_allowed = false
	_grass_frame()
	# Gray pillar on the left (shatter target).
	_gray(3, 12, 2, 8)
	# Earth floor to tear rocks from, thick (2 deep) at columns 6-11.
	_earth(5, 20, 23, 1)
	_earth(6, 21, 6, 1)
	# The tall block: earth face on its left side, grass body and top.
	_grass(28, 8, 11, 12)
	_earth(28, 8, 1, 12)
	_finish_room(Vector2(116, 160), "res://tests/rooms/room_earth_c.tscn")


## Earth test room D (Stage E4c, hidden chambers). Earth-only. Left to right:
##   - the start, and a grass step up onto...
##   - a wall of THICK earth (16 tiles wide, 6 deep). Buried in it, 2 tiles under its
##     top, runs a hidden tunnel (columns 13-27, rows 16-17), drawn as deep earth.
##     A BIG rock (hold S, Stage E4c2) tears out a 2x2 block: right above the tunnel
##     its hole reaches it, the cover crumbles, and the hole is wide enough to drop
##     straight in. (The player is as wide as a tile: a 1-tile hole is too narrow.
##     Small rocks can still get there, two holes side by side, 2 deep.)
##   - a gray barrier from the ceiling down to the tunnel: the only way to the right
##     is through the tunnel, which runs under it and opens into...
##   - the right chamber, its floor level with the tunnel's floor.
## R covers the tunnel again.
func _build_room_earth_d() -> void:
	_begin_room("RoomEarthD", "Earth D - Hidden Chambers",
		"Stage E4c test room. Earth-only. A tunnel is buried in the thick earth wall (purple in the editor's Hidden layer). Climb onto the wall. Facing right, HOLD S: a big rock tears a 2x2 hole that reaches the tunnel, and its cover crumbles. Drop in, walk right under the gray barrier. R hides it again.")
	room.air_allowed = false
	_grass_frame()
	# Step up onto the earth wall (24 px, then 24 px more).
	_grass(8, 17, 2, 3)
	# The thick earth wall, standing on the floor.
	_earth(10, 14, 16, 6)
	# The gray barrier, ceiling to tunnel and under the tunnel.
	_gray(26, 1, 2, 15)
	_gray(26, 18, 2, 2)
	# The right chamber's floor, level with the tunnel's floor (row 18).
	_grass(28, 18, 11, 2)
	# The hidden tunnel: 2 tiles tall (the player is 11 px), under 2 tiles of earth,
	# running under the barrier to the right chamber.
	_hidden(13, 16, 15, 2)
	_finish_room(Vector2(24, 160), "res://tests/rooms/room_earth_d.tscn")


## Earth test room E (Stage E5, the snake). Earth-only. Left to right:
##   - the start on grass
##   - a small earth patch, 6 tiles wide and 2 deep (12 tiles: one full snake), right
##     at the edge of...
##   - a spike pit 8 tiles wide, gray under the spikes, so a bend can't reach the far
##     side. Send the shadow along the patch and down the pit's near wall (hold A), release:
##     the snake comes out of the wall sideways and runs straight across, a bridge.
##     From the patch's top it comes out going UP: steer it (one up, then right).
##     Steered back into yourself, it throws you off, or crushes you against the floor.
##   - the far side on grass, and a sentry on a block at the right: raise the snake as
##     a wall (straight up) and its orbs pop against it.
## R puts the earth back and removes the snake.
func _build_room_earth_e() -> void:
	_begin_room("RoomEarthE", "Earth E - Snake",
		"Stage E5 test room. Earth-only. Hold A on the earth patch until the shadow crawls off your feet, release: a snake of earth comes out at the shadow; steer it with the arrows, press A (or Jump) to harden it. Steer it into yourself: it throws you off (or crushes you against the ground). Send the shadow down the pit's near wall for a straight bridge. The patch has 12 tiles: one full snake. Raise a wall against the sentry's orbs. R resets.")
	room.air_allowed = false
	_grass_frame()
	# The earth patch: 6 wide, 2 deep, at the pit's edge.
	_earth(8, 20, 6, 2)
	# The spike pit, gray under the spikes.
	_spike_pit("PitSpikes", 14, 8)
	# The sentry's low grass block on the right (3 tiles tall).
	_grass(32, 17, 6, 3)
	_add(SENTRY_SCENE, "Sentry", Vector2(263, 136))
	_finish_room(Vector2(24, 160), "res://tests/rooms/room_earth_e.tscn")


## Earth test room F (after Stage E5): ONE KEY (Room.one_key_column_snake on, so it
## stays on here even with EarthTuning's switch off): A does both column and snake. Earth-only. Left to right:
##   - the start, and an earth floor in front of...
##   - a ledge 6 tiles high (48 px: too high for a jump, fine for a super jump). Quick
##     tap A on the earth floor: a column under you throws you up; steer onto the ledge.
##   - the ledge's top is an earth patch (6 wide, 2 deep: 12 tiles, one full snake)
##   - a spike pit 9 tiles wide, too far to jump, then a second ledge just as high.
##     Hold A on the patch: the shadow crawls right and down the ledge's side; release:
##     a SNAKE comes out sideways and runs straight across, a bridge to the far ledge.
## R resets.
func _build_room_earth_f() -> void:
	_begin_room("RoomEarthF", "Earth F - One Key (A)",
		"One key: A does column AND snake (on everywhere; this room keeps it on even with the global switch off). Quick tap A (shadow still under your feet): a column under you, the super jump, up onto the ledge. Hold A until the shadow crawls off: releasing brings a snake out instead; steer it, A again hardens it. Bridge the spike pit from the ledge's side. R resets.")
	room.air_allowed = false
	room.one_key_column_snake = true
	_grass_frame()
	# Earth floor for the super jump.
	_earth(4, 20, 7, 1)
	# The near ledge: grass body, a 2-deep earth patch on top.
	_grass(11, 14, 6, 6)
	_earth(11, 14, 6, 2)
	# The spike pit between the ledges, gray under the spikes.
	_spike_pit("PitSpikes", 17, 9)
	# The far ledge, just as high.
	_grass(26, 14, 13, 6)
	_finish_room(Vector2(24, 160), "res://tests/rooms/room_earth_f.tscn")


## Mixed test room A: Air AND Earth both allowed, to try how they work together.
##   - a tall wall (88 px) with earth faces on both sides: too high for a super jump
##     alone. Super jump + dash (the column refills the dash), or raise a column out
##     of its face as a step, stand on it, bend again from the pillar...
##   - a wind crystal for a second dash
##   - right of the wall: a spike pit with an updraft over it. Side-spring off the
##     wall's right face and glide: the updraft carries you.
##   - a crate near the start (gust it, or throw it with a column) and a wisp on the
##     far floor (gust it, crush it, or throw it into the pit)
func _build_room_mixed_a() -> void:
	_begin_room("RoomMixedA", "Mixed A - Air + Earth",
		"Air and Earth together. Super jump + dash over the wall, column steps, side spring + glide over the updraft pit. R resets.")
	room.air_allowed = true
	room.earth_allowed = true
	_grass_frame()
	# Floor: grass at the start (crate) and past the pit (wisp, breeze), earth where
	# you bend: in front of the tall wall and in the side spring's standing spot.
	_earth(9, 20, 9, 1)
	_earth(21, 20, 4, 1)
	# The tall wall: grass core with an earth face on each side.
	_grass(18, 9, 3, 11)
	_earth(18, 9, 1, 11)
	_earth(20, 9, 1, 11)
	# Spike pit with an updraft above it.
	_spike_pit("PitSpikes", 25, 7)
	_add(WIND_ZONE_SCENE, "Updraft", Vector2(25 * TILE, 64), {
		"zone_size": Vector2(7 * TILE, 96), "wind_direction": Vector2.UP, "wind_strength": 60.0,
	})
	# A light breeze over the far grass, blowing away from the pit: it sways the blades.
	_add(WIND_ZONE_SCENE, "Breeze", Vector2(32 * TILE, 128), {
		"zone_size": Vector2(7 * TILE, 32), "wind_direction": Vector2.RIGHT, "wind_strength": 30.0,
	})
	_add(CRYSTAL_SCENE, "Crystal", Vector2(120, 64))
	_add(CRATE_SCENE, "Crate", Vector2(40, 160))
	_add(WISP_SCENE, "Wisp", Vector2(296, 160), {"start_direction": -1})
	_finish_room(Vector2(96, 160), "res://tests/rooms/room_mixed_a.tscn")


## Mixed test room B: both enemy types, Air AND Earth allowed, so there are several
## ways to deal with each:
##   - left: a wisp patrolling under a low earth overhang (2 tiles of headroom).
##     Crush it with a column from the overhang's underside (bend from on top of it,
##     reached by the step or a super jump), dash into it after a gust stuns it, or
##     gust it into the spike pit.
##   - middle: a spike pit with gray rock under the spikes, so a bend can't reach
##     the right side from the left.
##   - right: a second wisp on the floor and a sentry on an earth block. The sentry
##     fires at you from across the room: raise a column in front of you to block
##     its orbs (they pop on it, and it blocks the sentry's view too), or gust them
##     back at it. Standing next to the block, send the shadow up its face and
##     release low: the column shoots along the floor and throws the wisp into the pit.
func _build_room_mixed_b() -> void:
	_begin_room("RoomMixedB", "Mixed B - Enemies",
		"Both enemy types, Air and Earth allowed. Block sentry orbs with columns (or gust them back), crush the wisp under the overhang, throw the other into the pit with a column out of the sentry's block. R resets.")
	room.air_allowed = true
	room.earth_allowed = true
	_grass_frame()
	# Floor: grass at the start and under the sentry's block, earth from the overhang
	# to the pit and on the right where you raise columns against the orbs.
	_earth(8, 20, 8, 1)
	_earth(22, 20, 10, 1)
	# Left: a step and a low overhang (underside 16 px above the floor).
	_earth(5, 18, 2, 2)
	_earth(8, 16, 5, 2)
	# Middle: spike pit, gray under the spikes.
	_spike_pit("PitSpikes", 16, 6)
	# Right: the sentry's low earth block (2 tiles tall, so the sentry on its left
	# edge can see down to the floor).
	_earth(32, 18, 6, 2)
	_add(WISP_SCENE, "WispLeft", Vector2(96, 160))
	_add(WISP_SCENE, "WispRight", Vector2(216, 160), {"start_direction": -1})
	_add(SENTRY_SCENE, "Sentry", Vector2(263, 144))
	_finish_room(Vector2(24, 160), "res://tests/rooms/room_mixed_b.tscn")

extends Node
## tools/build_rooms.gd — ONE-OFF generator for the Milestone 1 rooms (Stage 9).
##
## It writes, from the layouts below:
##   - resources/tiles/placeholder_tiles.png     8x8 placeholder tile art (2 tiles)
##   - resources/tiles/placeholder_tileset.tres  TileSet with collision on layer 1
##   - scenes/rooms/room_01.tscn … room_07.tscn  rooms painted on a TileMapLayer,
##                                               with spikes, crystals, objects, enemies
##
## Run it from the project folder (Godot console build) by running its scene:
##   godot --headless --path . res://tools/build_rooms.tscn
## (A scene, not `--script`: only a normal run loads the autoloads FX and GameState,
## and the object scripts don't compile without them.)
## To rebuild only some rooms, list their numbers after `--`:
##   godot --headless --path . res://tools/build_rooms.tscn -- 6 7
## The very first run only writes the PNG and asks you to import it
## (godot --headless --path . --import) and run the scene again.
##
## WARNING: running it again OVERWRITES the rooms it builds, losing any edits made in
## the Godot editor. After Stage 9 the .tscn files are the source of truth: edit the
## rooms in the editor. The tileset and PNG are only written when missing.
##
## Why a script instead of writing .tscn text by hand? A TileMapLayer stores its
## cells as an encoded byte blob (tile_map_data), which isn't meant to be hand-written.
## Here Godot itself paints the cells (set_cell) and saves the scene (PackedScene.pack),
## so the files are exactly what the editor would produce.
##
## Layout units: solids and spikes are given in TILES (8 px): (column, row, width,
## height), with (0, 0) the room's top-left tile. Object positions are in PIXELS,
## relative to the room's top-left, using each object's own origin convention
## (written in its script header: spikes top-left, crate/wisp feet, windmill hub…).
## A room is 180 px tall = 22.5 tiles, so floors are painted down to row 22 and their
## last half-tile hangs below the room, where the camera never looks.

const TILE: int = 8
const TILES_PNG_PATH: String = "res://resources/tiles/placeholder_tiles.png"
const TILESET_PATH: String = "res://resources/tiles/placeholder_tileset.tres"
## Atlas coordinates of the two tiles in the PNG.
const TILE_PLAIN: Vector2i = Vector2i(0, 0)        # solid, no edge
const TILE_TOP_EDGE: Vector2i = Vector2i(1, 0)     # solid with a light top edge (walkable surface)
## Same dark gray as Room.SOLID_COLOR (GAME_DESIGN.md §2), and a lighter edge.
const SOLID_COLOR: Color = Color(0.25, 0.25, 0.28)
const EDGE_COLOR: Color = Color(0.42, 0.42, 0.47)
const SHADE_COLOR: Color = Color(0.21, 0.21, 0.24)

const ROOM_SCRIPT: Script = preload("res://scenes/rooms/room_base.gd")
const SPIKES_SCENE: PackedScene = preload("res://scenes/objects/spikes.tscn")
const CRYSTAL_SCENE: PackedScene = preload("res://scenes/objects/wind_crystal.tscn")
const WIND_ZONE_SCENE: PackedScene = preload("res://scenes/objects/wind_zone.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/objects/crate.tscn")
const PLATE_SCENE: PackedScene = preload("res://scenes/objects/pressure_plate.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/objects/door.tscn")
const WINDMILL_SCENE: PackedScene = preload("res://scenes/objects/windmill.tscn")
const LEAF_SCENE: PackedScene = preload("res://scenes/objects/leaf_platform.tscn")
const WISP_SCENE: PackedScene = preload("res://scenes/enemies/wisp.tscn")
const SENTRY_SCENE: PackedScene = preload("res://scenes/enemies/sentry.tscn")
const ENEMY_GATE_SCENE: PackedScene = preload("res://scenes/objects/enemy_gate.tscn")
const GOAL_SCENE: PackedScene = preload("res://scenes/objects/goal.tscn")
const SAIL_SCENE: PackedScene = preload("res://scenes/objects/sail_platform.tscn")
const LEAF_PILE_SCENE: PackedScene = preload("res://scenes/objects/leaf_pile.tscn")
const NO_GLIDE_SCENE: PackedScene = preload("res://scenes/objects/no_glide_zone.tscn")

## Spikes.Facing values (UP, DOWN, LEFT, RIGHT), repeated here to keep calls readable.
const FACING_UP: int = 0
const FACING_LEFT: int = 2
const FACING_RIGHT: int = 3

## Room being built: its root node and its solid cells (a Dictionary used as a set).
var room: Room
var solid_cells: Dictionary = {}
var tile_set: TileSet


func _ready() -> void:
	_build_everything()
	get_tree().quit()


func _build_everything() -> void:
	if not FileAccess.file_exists(TILES_PNG_PATH):
		_write_tiles_png()
		print("[BuildRooms] Wrote %s. Now run the import, then this script again:" % TILES_PNG_PATH)
		print("  godot --headless --path . --import")
		return
	if not ResourceLoader.exists(TILES_PNG_PATH):
		push_error("[BuildRooms] %s is not imported yet: run godot --headless --path . --import" % TILES_PNG_PATH)
		return
	tile_set = _load_or_create_tileset()
	# A Callable is a reference to a function, so the rooms can sit in a table.
	var builders: Dictionary = {
		1: _build_room_01, 2: _build_room_02, 3: _build_room_03, 4: _build_room_04,
		5: _build_room_05, 6: _build_room_06, 7: _build_room_07,
	}
	# Arguments after `--` on the command line pick rooms; none = build them all.
	var requested: PackedStringArray = OS.get_cmdline_user_args()
	for room_number: int in builders:
		if requested.is_empty() or str(room_number) in requested:
			(builders[room_number] as Callable).call()
	print("[BuildRooms] Done.")


# --- Tiles -----------------------------------------------------------------------

## Two 8x8 tiles side by side: plain solid, and solid with a 1 px light top edge.
## Both get a 1 px darker bottom row so stacked tiles show faint seams (reads as
## "built from blocks" without being noisy).
func _write_tiles_png() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/tiles"))
	var image: Image = Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
	image.fill(SOLID_COLOR)
	for x: int in TILE * 2:
		image.set_pixel(x, TILE - 1, SHADE_COLOR)
	for x: int in range(TILE, TILE * 2):
		image.set_pixel(x, 0, EDGE_COLOR)
	image.save_png(ProjectSettings.globalize_path(TILES_PNG_PATH))


func _load_or_create_tileset() -> TileSet:
	if ResourceLoader.exists(TILESET_PATH):
		return load(TILESET_PATH) as TileSet
	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE, TILE)
	# One physics layer: every tile is solid ground on layer 1 ("world"), the layer
	# the player, crates, wisps and sentry sight lines already collide with.
	new_tile_set.add_physics_layer()
	new_tile_set.set_physics_layer_collision_layer(0, 1)
	new_tile_set.set_physics_layer_collision_mask(0, 0)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = load(TILES_PNG_PATH) as Texture2D
	source.texture_region_size = Vector2i(TILE, TILE)
	new_tile_set.add_source(source, 0)
	# Collision polygon for a full tile. Tile polygons are centered on the tile.
	var half: float = TILE / 2.0
	var full_square: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	for atlas_coords: Vector2i in [TILE_PLAIN, TILE_TOP_EDGE]:
		source.create_tile(atlas_coords)
		var tile_data: TileData = source.get_tile_data(atlas_coords, 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, full_square)
	ResourceSaver.save(new_tile_set, TILESET_PATH)
	print("[BuildRooms] Wrote %s" % TILESET_PATH)
	# Load it back from disk so the rooms reference the .tres file by path instead
	# of embedding their own copy.
	return ResourceLoader.load(TILESET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as TileSet


# --- Building blocks -------------------------------------------------------------

func _begin_room(node_name: String, title: String, size_px: Vector2, description: String) -> void:
	room = _instantiate_room(node_name)
	room.display_title = title
	room.room_size = size_px
	room.editor_description = description
	solid_cells.clear()


func _instantiate_room(node_name: String) -> Room:
	var root: Node2D = Node2D.new()
	root.name = node_name
	root.set_script(ROOM_SCRIPT)
	return root as Room


## Fills a rectangle of tiles: (column, row, width, height).
func _solid(column: int, row: int, width: int, height: int) -> void:
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			solid_cells[Vector2i(x, y)] = true


## A strip of spikes starting at tile (column, row). UP strips run to the right,
## LEFT/RIGHT strips run downward (see spikes.gd).
func _spikes(node_name: String, column: int, row: int, count: int, facing: int = FACING_UP) -> void:
	_add(SPIKES_SCENE, node_name, Vector2(column * TILE, row * TILE), {
		"facing": facing, "tile_count": count,
	})


## A cosmetic leaf pile lying on a floor: `position_px` is the center of its base
## (on the floor surface). More leaves for wider piles; the seed varies the shape.
func _leaves(node_name: String, position_px: Vector2, width: float, seed: int) -> void:
	_add(LEAF_PILE_SCENE, node_name, position_px, {
		"pile_width": width, "leaf_count": int(width * 1.5), "random_seed": seed,
	})


## A "dead air" rectangle (px, top-left + size) where gliding is impossible.
func _no_glide(node_name: String, rect_px: Rect2) -> void:
	_add(NO_GLIDE_SCENE, node_name, rect_px.position, {"zone_size": rect_px.size})


## Instances a scene as a child of the room and sets its properties.
## `owner` must be the room root, or PackedScene.pack() would leave the node out.
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


## Paints the collected cells onto a TileMapLayer, adds the spawn point, and saves.
func _finish_room(spawn_px: Vector2, path: String) -> void:
	var tiles: TileMapLayer = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = tile_set
	for cell: Vector2i in solid_cells:
		# The tile under open air gets the light top edge: walkable surfaces stand out.
		var is_top: bool = not solid_cells.has(cell + Vector2i.UP) and cell.y > 0
		tiles.set_cell(cell, 0, TILE_TOP_EDGE if is_top else TILE_PLAIN)
	room.add_child(tiles)
	room.move_child(tiles, 0)  # drawn first, so objects appear in front of the ground
	tiles.owner = room

	var spawn: Marker2D = Marker2D.new()
	spawn.name = "SpawnPoint"
	spawn.position = spawn_px
	room.add_child(spawn)
	room.move_child(spawn, 1)
	spawn.owner = room

	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(room)
	if pack_error != OK:
		push_error("[BuildRooms] Could not pack %s: %s" % [path, error_string(pack_error)])
		return
	var save_error: Error = ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("[BuildRooms] Could not save %s: %s" % [path, error_string(save_error)])
		return
	print("[BuildRooms] Wrote %s" % path)
	room.free()


# --- The five rooms (GAME_DESIGN.md §8) ------------------------------------------
# World layout: all rooms sit in one row (y = 0), left to right, 1 → 5. Exits are
# gaps in the side walls; neighbouring rooms have matching gaps.
#   Room 1  x =    0, 480 wide   exit low  (rows 15-18)
#   Room 2  x =  480, 640 wide   exit low
#   Room 3  x = 1120, 480 wide   exit HIGH (rows 1-5)
#   Room 4  x = 1600, 640 wide   enters high, exits high
#   Room 5  x = 2240, 480 wide   enters high, exits high through the enemy gate
#   Room 6  x = 2720, 800 wide   enters high, exits low (rows 11-14)
#   Room 7  x = 3520, 480 wide   enters low, Goal inside

## Room 1 "First Breath": run, jump, wall jump. No bending needed.
func _build_room_01() -> void:
	_begin_room("Room01", "1 - First Breath", Vector2(480, 180),
		"Run, jump, wall jump. Hop up a step, jump two short gaps (falling in is a pit death), then climb the shaft by jumping between its two walls and drop down to the exit on the right.")
	_solid(0, 0, 60, 1)     # ceiling
	_solid(0, 0, 1, 23)     # left wall
	_solid(59, 0, 1, 15)    # right wall above the exit (exit = rows 15-18)
	_solid(0, 19, 11, 4)    # start floor
	_solid(11, 17, 6, 6)    # step up (16 px)
	_solid(21, 17, 6, 6)    # across a 32 px gap
	_solid(32, 16, 5, 7)    # across a 40 px gap, 8 px higher
	_solid(37, 19, 23, 4)   # lower floor up to the exit
	_solid(42, 1, 1, 14)    # shaft: left wall hanging from the ceiling (walk under it)
	_solid(47, 6, 4, 13)    # shaft: tall pillar to climb (top at y = 48)
	_leaves("StartLeaves", Vector2(60, 152), 32.0, 1)
	_leaves("StepLeaves", Vector2(116, 136), 20.0, 2)
	_leaves("LedgeLeaves", Vector2(276, 128), 24.0, 3)
	_leaves("ShaftLeaves", Vector2(316, 152), 36.0, 4)
	_leaves("ExitLeaves", Vector2(440, 152), 40.0, 5)
	_finish_room(Vector2(24, 152), "res://scenes/rooms/room_01.tscn")


## Room 2 "The Dash": a gap too wide to jump, the first wind crystal, then a
## crystal chain over spikes.
func _build_room_02() -> void:
	_begin_room("Room02", "2 - The Dash", Vector2(640, 180),
		"1) An 88 px gap: too wide to jump, so jump and dash (X) across. 2) A 144 px pit with the first wind crystal in the middle: dash to it, it refills you, dash again. 3) Three crystals over a spike floor: chain jump, dash, dash, dash to the exit. The chain is in dead air (mauve, hatched): no gliding there.")
	_solid(0, 0, 80, 1)     # ceiling
	_solid(0, 0, 1, 15)     # left wall above the entrance
	_solid(79, 0, 1, 15)    # right wall above the exit
	_solid(0, 19, 9, 4)     # start floor
	_solid(20, 19, 7, 4)    # after the 88 px gap
	_solid(45, 18, 5, 5)    # after the crystal pit
	_solid(50, 21, 22, 2)   # spike bed
	_spikes("SpikeFloor", 50, 20, 22)
	_solid(72, 19, 8, 4)    # exit floor
	_add(CRYSTAL_SCENE, "FirstCrystal", Vector2(280, 120))
	_add(CRYSTAL_SCENE, "Chain1", Vector2(432, 120))
	_add(CRYSTAL_SCENE, "Chain2", Vector2(488, 104))
	_add(CRYSTAL_SCENE, "Chain3", Vector2(544, 116))
	_no_glide("ChainDeadAir", Rect2(400, 8, 176, 152))
	_leaves("StartLeaves", Vector2(44, 152), 32.0, 6)
	_leaves("IslandLeaves", Vector2(188, 152), 24.0, 7)
	_leaves("ExitLeaves", Vector2(610, 152), 36.0, 8)
	_finish_room(Vector2(24, 152), "res://scenes/rooms/room_02.tscn")


## Room 3 "Updraft": glide over a long pit, ride an updraft to a high exit, walk
## into a head-wind.
func _build_room_03() -> void:
	_begin_room("Room03", "3 - Updraft", Vector2(480, 180),
		"Climb the two steps, then jump and glide (press Jump again while falling, hold it) over the 192 px spike pit. Glide inside the updraft to rise to the high ledge, then push right against the head-wind to the exit.")
	_solid(0, 0, 60, 1)     # ceiling (exit gap is rows 1-5 on the right)
	_solid(0, 0, 1, 15)     # left wall above the entrance
	_solid(0, 19, 8, 4)     # start floor
	_solid(8, 16, 4, 7)     # step 1 (top y = 128)
	_solid(12, 13, 4, 10)   # step 2 (top y = 104): the glide launch
	_solid(16, 21, 24, 2)   # spike bed under the pit
	_spikes("PitSpikes", 16, 20, 24)
	_solid(40, 19, 10, 4)   # landing, under the updraft
	_solid(50, 6, 10, 17)   # high ledge to the exit (top y = 48)
	_add(WIND_ZONE_SCENE, "Updraft", Vector2(352, 8), {
		"zone_size": Vector2(48, 144), "wind_direction": Vector2.UP, "wind_strength": 60.0,
	})
	_add(WIND_ZONE_SCENE, "HeadWind", Vector2(400, 8), {
		"zone_size": Vector2(72, 40), "wind_direction": Vector2.LEFT, "wind_strength": 50.0,
	})
	_leaves("StartLeaves", Vector2(36, 152), 28.0, 9)
	_leaves("StepLeaves", Vector2(112, 104), 24.0, 10)
	_leaves("LandingLeaves", Vector2(334, 152), 24.0, 11)
	_leaves("LedgeLeaves", Vector2(436, 48), 40.0, 12)
	_finish_room(Vector2(24, 152), "res://scenes/rooms/room_03.tscn")


## Room 4 "Gust Works": crate onto plate opens door A; windmill holds gate B open
## while you dash through; a leaf platform lifts you to the exit.
func _build_room_04() -> void:
	_begin_room("Room04", "4 - Gust Works", Vector2(640, 180),
		"1) Gust (Z) the crate right twice so it lands on the plate: door A opens. 2) Gust the windmill, then jump and dash across the spike pit before gate B closes (4 s; the ring shows the time left). The pit is dead air: no gliding. 3) Stand on the leaf and gust to ride it up, then jump to the exit ledge.")
	_solid(0, 0, 80, 1)     # ceiling
	_solid(0, 6, 10, 17)    # entrance ledge (top y = 48)
	_solid(10, 19, 22, 4)   # crate floor
	_solid(32, 1, 1, 12)    # wall above door A
	_solid(32, 19, 9, 4)    # windmill floor
	_solid(41, 21, 10, 2)   # spike bed
	_spikes("PitSpikes", 41, 20, 10)
	_solid(51, 1, 1, 12)    # wall above gate B
	_solid(51, 19, 29, 4)   # leaf floor
	_solid(70, 6, 10, 17)   # exit ledge (top y = 48), exit gap rows 1-5
	_add(CRATE_SCENE, "Crate", Vector2(128, 152))
	var plate: Node2D = _add(PLATE_SCENE, "Plate", Vector2(208, 152))
	var door_a: Node2D = _add(DOOR_SCENE, "DoorA", Vector2(256, 104), {"door_size": Vector2(8, 48)})
	var plate_switches: Array[Switch] = [plate as Switch]
	door_a.set("switches", plate_switches)
	var windmill: Node2D = _add(WINDMILL_SCENE, "Windmill", Vector2(296, 132), {"post_length": 20.0})
	var gate_b: Node2D = _add(DOOR_SCENE, "GateB", Vector2(408, 104), {"door_size": Vector2(8, 48)})
	var windmill_switches: Array[Switch] = [windmill as Switch]
	gate_b.set("switches", windmill_switches)
	_add(LEAF_SCENE, "Leaf", Vector2(536, 144), {"travel": Vector2(0, -72)})
	_no_glide("PitDeadAir", Rect2(328, 8, 80, 152))
	_leaves("EntryLeaves", Vector2(40, 48), 40.0, 13)
	_leaves("DoorLeaves", Vector2(238, 152), 24.0, 14)
	_leaves("GateLeaves", Vector2(452, 152), 48.0, 15)
	_leaves("ExitLeaves", Vector2(604, 48), 40.0, 16)
	_finish_room(Vector2(24, 48), "res://scenes/rooms/room_04.tscn")


## Room 5 "Sentry Pass": two wisps on platforms over a spike floor, a sentry
## guarding the exit. The exit gate opens only when all three are defeated.
func _build_room_05() -> void:
	_begin_room("Room05", "5 - Sentry Pass", Vector2(480, 180),
		"Drop to the low platform and deal with its wisp (gust it into the spikes, or stun it and dash into it). Down-gust jump (Z + Down in the air) up to the high platform and its wisp, then again up and over the spiked wall onto the sentry's ledge (dead air in front of the wall: no gliding). Gust an orb back at the sentry. The gate (pips above it) opens when all three enemies are beaten; the way on is behind it.")
	_solid(0, 0, 60, 1)     # ceiling
	_solid(0, 6, 8, 17)     # entrance ledge (top y = 48)
	_solid(8, 21, 30, 2)    # spike bed
	_spikes("SpikeFloor", 8, 20, 30)
	_solid(10, 14, 8, 1)    # low platform (top y = 112)
	_solid(24, 9, 8, 1)     # high platform (top y = 72)
	_solid(38, 5, 22, 18)   # sentry ledge (top y = 40)
	_spikes("WallSpikes", 37, 6, 14, FACING_LEFT)  # no wall-jumping up the ledge
	var low_wisp: Node2D = _add(WISP_SCENE, "LowWisp", Vector2(112, 112))
	var high_wisp: Node2D = _add(WISP_SCENE, "HighWisp", Vector2(224, 72), {"start_direction": -1})
	var sentry: Node2D = _add(SENTRY_SCENE, "Sentry", Vector2(392, 40))
	var gate: Node2D = _add(ENEMY_GATE_SCENE, "EnemyGate", Vector2(444, 4))
	var gate_enemies: Array[Node2D] = [low_wisp, high_wisp, sentry]
	gate.set("enemies", gate_enemies)
	var exit_door: Node2D = _add(DOOR_SCENE, "ExitDoor", Vector2(440, 8), {"door_size": Vector2(8, 32)})
	var gate_switches: Array[Switch] = [gate as Switch]
	exit_door.set("switches", gate_switches)
	_no_glide("WallDeadAir", Rect2(256, 8, 48, 152))
	_leaves("EntryLeaves", Vector2(36, 48), 32.0, 17)
	_leaves("LedgeLeaves", Vector2(334, 40), 36.0, 18)
	_finish_room(Vector2(24, 48), "res://scenes/rooms/room_05.tscn")


## A "thorn crown": a stone pillar rising from the pit, topped with spikes that
## stick up `crown_tiles` tiles above `deck_row` (the tile row a sail's deck rides
## in, i.e. deck top = deck_row * 8). The pillar stops one tile under the deck, so
## the sail slides OVER it (sails move by script and ignore solids anyway). The
## spikes are not solid, so the deck and mast pass through them. The player on the
## deck can't: they must jump the crown and land back on the moving deck.
## Each crown tile holds a left-facing AND a right-facing strip, crossed, so no
## matter which way you touch it you're moving against some of its tips.
func _thorn_crown(node_name: String, column: int, deck_row: int, crown_tiles: int, bottom_row: int) -> void:
	_solid(column, deck_row + 1, 1, bottom_row - deck_row)
	var crown_top_row: int = deck_row - crown_tiles
	_spikes(node_name + "Left", column, crown_top_row, crown_tiles + 1, FACING_LEFT)
	_spikes(node_name + "Right", column, crown_top_row, crown_tiles + 1, FACING_RIGHT)
	_spikes(node_name + "Top", column, crown_top_row - 1, 1)


## Room 6 "Sail Under Fire": ride a sail across a long spike pit, blowing it along
## with your own gusts, while sentries shoot at you. Two thorn crowns block the
## deck: jump them as the boat slides under, and land back on board.
func _build_room_06() -> void:
	_begin_room("Room06", "6 - Sail Under Fire", Vector2(800, 180),
		"Drop to the dock and hop on the sail. Gust sideways while standing on the deck: no recoil, the sail takes the push and moves the way you blew. Two thorn crowns stick up through the rail: jump over each one as the boat slides under it and land back on the deck (you keep the boat's speed in the air). Two ceiling sentries and one on the far dock shoot at you: reflect their orbs (gusting on deck also pushes the boat!) or outrun them. Jump off at the far dock, past the last sentry.")
	_solid(0, 0, 100, 1)    # ceiling
	_solid(0, 5, 10, 18)    # entrance ledge (top y = 40)
	_solid(10, 15, 6, 8)    # boarding dock (top y = 120)
	_solid(16, 21, 78, 2)   # spike bed under the whole sail route
	_spikes("PitSpikesA", 16, 20, 24)
	_spikes("PitSpikesB", 41, 20, 27)
	_spikes("PitSpikesC", 69, 20, 25)
	_thorn_crown("CrownA", 40, 15, 1, 22)
	_thorn_crown("CrownB", 68, 15, 1, 22)
	_solid(94, 15, 6, 8)    # far dock (top y = 120)
	_solid(99, 0, 1, 11)    # right wall above the exit (exit = rows 11-14)
	_add(SAIL_SCENE, "Sail", Vector2(152, 120), {
		"rail_start": Vector2(0, 0), "rail_end": Vector2(576, 0),
	})
	_add(SENTRY_SCENE, "CeilingSentryA", Vector2(232, 8), {"mounted_on_ceiling": true})
	_add(SENTRY_SCENE, "CeilingSentryB", Vector2(456, 8), {"mounted_on_ceiling": true})
	_add(SENTRY_SCENE, "DockSentry", Vector2(768, 120))
	_leaves("EntryLeaves", Vector2(44, 40), 40.0, 19)
	_leaves("DockLeaves", Vector2(100, 120), 28.0, 20)
	_finish_room(Vector2(24, 40), "res://scenes/rooms/room_06.tscn")


## Room 7 "The Gauntlet": everything at once, harder. A windmill gate you must race
## through a crystal chain in a head-wind, a down-gust climb under sentry fire, and
## a wisp guarding the goal.
func _build_room_07() -> void:
	_begin_room("Room07", "7 - The Gauntlet", Vector2(480, 180),
		"1) Gust the windmill, then race the 4 s gate: jump and dash through three crystals over spikes, against a head-wind, and through the door. 2) A sentry sits on the high platform: reflect its orbs from below, then climb (jump + down-gusts) up to it; the air below it is dead, no gliding. 3) Jump to the last ledge; a wisp patrols in front of the goal (gust it into the wall, then dash it, or just slip past). Touch the green flag to finish.")
	_solid(0, 0, 60, 1)     # ceiling
	_solid(0, 0, 1, 11)     # left wall above the entrance (entrance = rows 11-14)
	_solid(0, 15, 6, 8)     # entrance floor (top y = 120)
	_solid(6, 21, 24, 2)    # spike bed, part 1
	_spikes("PitSpikesA", 6, 20, 24)
	_solid(30, 1, 1, 10)    # wall above the gate
	_solid(30, 15, 6, 8)    # platform behind the gate (top y = 120)
	_solid(36, 21, 16, 2)   # spike bed, part 2
	_spikes("PitSpikesB", 36, 20, 16)
	_solid(40, 6, 6, 1)     # high sentry platform (top y = 48)
	_solid(52, 9, 8, 14)    # goal ledge (top y = 72)
	_solid(59, 0, 1, 9)     # right wall
	var windmill: Node2D = _add(WINDMILL_SCENE, "Windmill", Vector2(40, 100), {"post_length": 20.0})
	var gate: Node2D = _add(DOOR_SCENE, "Gate", Vector2(240, 88), {"door_size": Vector2(8, 32)})
	var windmill_switches: Array[Switch] = [windmill as Switch]
	gate.set("switches", windmill_switches)
	_add(WIND_ZONE_SCENE, "HeadWind", Vector2(48, 8), {
		"zone_size": Vector2(192, 112), "wind_direction": Vector2.LEFT, "wind_strength": 30.0,
	})
	_add(CRYSTAL_SCENE, "Crystal1", Vector2(96, 96))
	_add(CRYSTAL_SCENE, "Crystal2", Vector2(152, 80))
	_add(CRYSTAL_SCENE, "Crystal3", Vector2(208, 96))
	_add(SENTRY_SCENE, "HighSentry", Vector2(344, 48))
	_add(WISP_SCENE, "GoalWisp", Vector2(424, 72))
	_add(GOAL_SCENE, "Goal", Vector2(448, 40), {"goal_size": Vector2(24, 32)})
	_no_glide("ClimbDeadAir", Rect2(288, 56, 128, 104))
	_leaves("StartLeaves", Vector2(20, 120), 24.0, 21)
	_leaves("GateLeaves", Vector2(266, 120), 32.0, 22)
	_leaves("GoalLeaves", Vector2(428, 72), 24.0, 23)
	_finish_room(Vector2(24, 120), "res://scenes/rooms/room_07.tscn")

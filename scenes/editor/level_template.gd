class_name LevelTemplate
extends RefCounted
## LevelTemplate: builds the nodes of a brand-new editor level (Level_editor.md §3).
##
## The result has the same shape as scenes/earth_world.tscn, so RoomManager and
## the game UI work with it unchanged:
##   Level (RoomManager)
##   ├─ Room1 (Room)        one screen, 320x180, boxed in by ground tiles
##   │  ├─ Tiles            TileMapLayer with the placeholder tileset
##   │  └─ SpawnPoint       Marker2D, the player's feet on the floor
##   ├─ Player              player.tscn, standing on Room1's SpawnPoint
##   ├─ RoomCamera
##   ├─ DebugOverlay, RoomPicker, EndScreen, PauseMenu   the same UI every world has
##   └─ LevelInfo           title + start room (scenes/editor/level_info.gd)
##
## Every node is adopted (LevelStorage.adopt), so LevelStorage.save_level() writes
## all of it. The level is returned outside the scene tree; save it or add it.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/debug_overlay.tscn")
const ROOM_PICKER_SCENE: PackedScene = preload("res://scenes/ui/room_picker.tscn")
const END_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/end_screen.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const GROUND_TILESET: TileSet = preload("res://resources/tiles/placeholder_tileset.tres")

## Tile size in pixels (the placeholder tileset's cells).
const TILE: int = 8
## One screen. 180 px is 22.5 tiles: like the existing rooms, the last row of
## tiles is half below the screen edge.
const ROOM_SIZE: Vector2 = Vector2(320, 180)
## Placeholder tileset atlas cells (same as tools/build_rooms.gd): a plain solid
## tile, and one with a light top edge for surfaces you can stand on.
const TILE_PLAIN: Vector2i = Vector2i(0, 0)
const TILE_TOP_EDGE: Vector2i = Vector2i(1, 0)
## The floor's top row. Rows 21 and 22 are floor, so its surface is at y = 168.
const FLOOR_ROW: int = 21
## Where the player's feet start: the middle of tile column 2 (just in from the
## left wall), on the floor. Tile middles are where the editor puts spawn points too.
const SPAWN_POSITION: Vector2 = Vector2(2 * TILE + TILE / 2.0, FLOOR_ROW * TILE)


## A new level called `title`: one boxed room with the player in it.
static func build_new_level(title: String) -> RoomManager:
	# RoomManager has a class_name, so .new() makes a Node2D with that script on it.
	var level: RoomManager = RoomManager.new()
	level.name = "Level"

	var room: Room = build_boxed_room("Room1", "Room 1")
	level.add_child(room)

	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	player.position = room.position + SPAWN_POSITION
	level.add_child(player)

	var camera: RoomCamera = RoomCamera.new()
	camera.name = "RoomCamera"
	level.add_child(camera)
	# Exported node references: saved in the file as paths to these nodes.
	level.player = player
	level.camera = camera

	var debug_overlay: DebugOverlay = DEBUG_OVERLAY_SCENE.instantiate() as DebugOverlay
	debug_overlay.name = "DebugOverlay"
	debug_overlay.visible = false
	debug_overlay.player = player
	level.add_child(debug_overlay)
	var room_picker: RoomPicker = ROOM_PICKER_SCENE.instantiate() as RoomPicker
	room_picker.name = "RoomPicker"
	room_picker.room_manager = level
	level.add_child(room_picker)
	var end_screen: EndScreen = END_SCREEN_SCENE.instantiate() as EndScreen
	end_screen.name = "EndScreen"
	end_screen.player = player
	level.add_child(end_screen)
	var pause_menu: PauseMenu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	pause_menu.name = "PauseMenu"
	pause_menu.room_manager = level
	level.add_child(pause_menu)

	var info: LevelInfo = LevelInfo.new()
	info.name = LevelInfo.NODE_NAME
	info.level_title = title
	info.start_room = room
	level.add_child(info)

	for child: Node in level.get_children():
		LevelStorage.adopt(child, level)
	return level


## A one-screen room with ground on all four sides (2-tile floor, 1-tile walls and
## ceiling), so a new level is playable at once instead of a pit you fall through.
static func build_boxed_room(node_name: String, title: String) -> Room:
	var room: Room = Room.new()
	room.name = node_name
	room.display_title = title
	room.room_size = ROOM_SIZE

	var columns: int = int(ROOM_SIZE.x / TILE)
	var rows: int = ceili(ROOM_SIZE.y / TILE)  # 23: the half row at the bottom counts
	var tiles: TileMapLayer = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = GROUND_TILESET
	for column: int in columns:
		for row: int in rows:
			var is_wall: bool = column == 0 or column == columns - 1
			var is_ceiling: bool = row == 0
			var is_floor: bool = row >= FLOOR_ROW
			if not (is_wall or is_ceiling or is_floor):
				continue
			# The top-edge tile only where you can stand: the floor's surface.
			var is_surface: bool = row == FLOOR_ROW and not is_wall
			tiles.set_cell(Vector2i(column, row), 0, TILE_TOP_EDGE if is_surface else TILE_PLAIN)
	room.add_child(tiles)

	var spawn_point: Marker2D = Marker2D.new()
	spawn_point.name = "SpawnPoint"
	spawn_point.position = SPAWN_POSITION
	room.add_child(spawn_point)
	return room

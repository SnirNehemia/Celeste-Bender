extends Node
## Headless smoke test for the level editor track (Stages L1+). Not part of the game.
##
## Drives the editor's code directly (LevelStorage, LevelTemplate, the menus),
## never the mouse, and prints PASS/FAIL lines, then quits. Run it with:
##   godot --headless --path . res://tests/editor_smoke_test.tscn
## Every L stage adds a section here (PROMPTS.md "Level editor track").
##
## It saves levels into a throwaway folder in user:// (LevelStorage.levels_dir is
## pointed there), so it never touches the real res://levels/, and deletes the
## folder at the end.

const TEST_LEVELS_DIR: String = "user://editor_smoke_test_levels/"
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const LEVEL_LIBRARY_SCENE: PackedScene = preload("res://scenes/ui/level_library.tscn")
const LEVEL_EDITOR_SCENE: PackedScene = preload("res://scenes/editor/level_editor.tscn")

var failures: int = 0
## Names of the check sections that ran to their end. A script error inside a
## section ends it silently, so _ready() checks this list.
var finished_sections: Array[String] = []


func _ready() -> void:
	LevelStorage.levels_dir = TEST_LEVELS_DIR
	_delete_test_folder()  # leftovers from a run that crashed

	_check_l1_storage()  # waits for nothing, so no await
	await _check_l1_play()
	await _check_l1_menus()
	await _check_l2_prompt()
	await _check_l2_editor()
	await _check_l3_objects()
	await _check_l3_playtest()
	await _check_l4_air_objects()
	await _check_l5_properties()
	await _check_l6_links()
	await _check_l6b_zones_eraser_help()
	await _check_l7_map()
	await _check_l7_import()
	await _check_l8_earth()
	await _check_l8b_followups()

	_delete_test_folder()
	LevelStorage.levels_dir = LevelStorage.DEFAULT_LEVELS_DIR
	for section_name: String in ["L1 storage", "L1 play", "L1 menus", "L2 prompt", "L2 editor", "L3 objects", "L3 play-test", "L4 Air objects", "L5 properties", "L6 links", "L6b zones, eraser, help", "L7 map", "L7 import", "L8 Earth", "L8b follow-ups"]:
		_check(finished_sections.has(section_name), "section %s ran to its end" % section_name)
	print("[EditorSmokeTest] %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Stage L1: create, list, read, duplicate, rename, delete; the saved structure.
func _check_l1_storage() -> void:
	_check(LevelStorage.list_levels().is_empty(), "an empty levels folder lists no levels")

	var path: String = LevelStorage.create_level("Smoke Level!")
	_check(path == TEST_LEVELS_DIR + "smoke_level.tscn", "the file name is the title made safe, got %s" % path)
	_check(FileAccess.file_exists(path), "create_level wrote the file")
	_check(LevelStorage.list_levels() == [path], "the new level is listed")
	_check(LevelStorage.read_title(path) == "Smoke Level!", "the title reads back, got %s" % LevelStorage.read_title(path))
	var second_path: String = LevelStorage.create_level("Smoke Level")
	_check(second_path == TEST_LEVELS_DIR + "smoke_level_2.tscn", "a second level with the same name gets _2, got %s" % second_path)

	# The structure of a saved level, read back from the file.
	var level: RoomManager = LevelStorage.load_level(path).instantiate() as RoomManager
	_check(level != null, "a level's root is a RoomManager")
	var room: Room = level.get_node_or_null("Room1") as Room
	_check(room != null and room.room_size == Vector2(320, 180), "it has one 320x180 Room")
	var tiles: TileMapLayer = room.get_node_or_null("Tiles") as TileMapLayer
	_check(tiles != null and tiles.get_used_cells().size() > 0, "the room's ground tiles were saved")
	_check(room.get_node_or_null("SpawnPoint") is Marker2D, "the room has a SpawnPoint")
	var info: LevelInfo = level.get_node_or_null(NodePath(LevelInfo.NODE_NAME)) as LevelInfo
	_check(info != null and info.start_room == room, "LevelInfo's start room is Room1 (the link survived saving)")
	_check(level.player != null and level.player == level.get_node_or_null("Player"), "RoomManager.player points at the Player")
	_check(level.camera != null and level.camera == level.get_node_or_null("RoomCamera"), "RoomManager.camera points at the RoomCamera")
	for ui_name: String in ["DebugOverlay", "RoomPicker", "EndScreen", "PauseMenu"]:
		_check(level.get_node_or_null(ui_name) != null, "it has the %s every world has" % ui_name)
	level.free()

	# Duplicate: a new file with " copy" in the title, the original unchanged.
	var copy_path: String = LevelStorage.duplicate_level(path)
	_check(copy_path == TEST_LEVELS_DIR + "smoke_level_copy.tscn", "the copy gets its own file, got %s" % copy_path)
	_check(LevelStorage.read_title(copy_path) == "Smoke Level! copy", "the copy's title ends in ' copy'")
	_check(LevelStorage.read_title(path) == "Smoke Level!", "the original keeps its title")
	# A re-saved level must hold its own nodes, not point at its own file.
	var copy_text: String = FileAccess.get_file_as_string(copy_path)
	_check(not copy_text.contains(path.get_file()) and not copy_text.contains(copy_path.get_file()),
		"a copied level doesn't reference a level file")
	var copy_level: Node = LevelStorage.load_level(copy_path).instantiate()
	_check(copy_level.get_node_or_null("Room1/Tiles") != null, "the copy still has its room and tiles")
	copy_level.free()

	# Rename: new title, same file.
	_check(LevelStorage.rename_level(path, "Renamed Level") == OK, "rename_level succeeds")
	_check(LevelStorage.read_title(path) == "Renamed Level", "the new title reads back at once (no stale cache)")
	_check(FileAccess.file_exists(path), "renaming keeps the file name")

	# Delete.
	_check(LevelStorage.delete_level(second_path) == OK, "delete_level succeeds")
	_check(not FileAccess.file_exists(second_path), "the deleted file is gone")
	_check(LevelStorage.list_levels() == [path, copy_path], "the list has the two remaining levels, got %s" % [LevelStorage.list_levels()])
	finished_sections.append("L1 storage")


## Stage L1: a saved level plays: RoomManager picks the room, the player stands on the floor.
func _check_l1_play() -> void:
	var path: String = LevelStorage.list_levels()[0]
	var level: RoomManager = LevelStorage.load_level(path).instantiate() as RoomManager
	add_child(level)
	# Let the player drop onto the floor and the room manager pick the room.
	await get_tree().create_timer(0.4).timeout
	_check(level.current_room != null and level.current_room.name == &"Room1", "RoomManager starts in Room1")
	_check(level.player.is_on_floor(), "the player stands on the new room's floor")
	_check(absf(level.player.global_position.y - LevelTemplate.SPAWN_POSITION.y) < 1.0,
		"the player's feet are on the floor surface (y %.1f)" % level.player.global_position.y)
	_check(GameState.death_count == 0, "nobody died: the room is closed on all sides")
	level.queue_free()
	await get_tree().process_frame
	finished_sections.append("L1 play")


## Stage L1: the main menu pages and the level library build without errors.
func _check_l1_menus() -> void:
	var menu: MainMenu = MAIN_MENU_SCENE.instantiate() as MainMenu
	add_child(menu)
	await get_tree().process_frame
	_check(menu.main_page.visible and not menu.chapters_page.visible, "the menu opens on the main page")
	var main_texts: Array[String] = _button_texts(menu.main_page)
	_check(main_texts.size() == 3 and main_texts[0] == "Story Mode" and main_texts[1].begins_with("Level Editor")
		and main_texts[2] == "Chapters & test rooms", "main page: Story Mode, Level Editor, Chapters & test rooms, got %s" % [main_texts])
	_check(_button_texts(menu.chapters_page).size() == MainMenu.CHAPTERS.size() + 1, "the chapters page has every chapter plus Back")
	menu.chapters_button.pressed.emit()
	_check(menu.chapters_page.visible and not menu.main_page.visible, "Chapters & test rooms opens its page")
	menu._go_back()
	_check(menu.main_page.visible and menu.chapters_button.has_focus(), "Back returns to the main page, focus on the button that opened it")
	menu.queue_free()

	var library: LevelLibrary = LEVEL_LIBRARY_SCENE.instantiate() as LevelLibrary
	add_child(library)
	await get_tree().process_frame
	_check(library.level_list.item_count == 2, "the library lists the test folder's two levels")
	_check(library.level_list.get_item_text(0) == "Renamed Level", "the library shows level titles")
	library.queue_free()
	await get_tree().process_frame
	finished_sections.append("L1 menus")


## Stage L2: the shared PromptPanel (the library and the editor ask with it).
func _check_l2_prompt() -> void:
	var holder: Control = Control.new()
	add_child(holder)
	var prompt: PromptPanel = PromptPanel.new()
	holder.add_child(prompt)
	var picked: Array[String] = []
	prompt.ask("Name?", [["OK", func(text: String) -> void: picked.append("ok:" + text)],
		["Other", func(text: String) -> void: picked.append("other:" + text)]], "Typed")
	_check(prompt.visible and prompt.text_field.visible and prompt.text_field.text == "Typed", "ask() with a default shows the text field")
	_check(prompt.button_row.get_child_count() == 3, "two choices + Cancel, got %d buttons" % prompt.button_row.get_child_count())
	prompt._pick(0)
	_check(picked == ["ok:Typed"] and not prompt.visible, "picking a choice calls it with the typed text and closes")
	prompt.ask("Sure?", [["Yes", func(text: String) -> void: picked.append("yes:" + text)]])
	_check(not prompt.text_field.visible, "ask() without a default has no text field")
	prompt.close()
	_check(not prompt.visible and picked.size() == 1, "Cancel closes without calling a choice")
	holder.queue_free()
	await get_tree().process_frame
	finished_sections.append("L2 prompt")


## Stage L2: the editor screen: showing a level without running it, painting with
## edges, rectangles, undo/redo, the unsaved state, saving, zoom, the window switch.
func _check_l2_editor() -> void:
	var window: Window = get_window()
	var game_scale_mode: Window.ContentScaleMode = window.content_scale_mode
	var game_scale_size: Vector2i = window.content_scale_size
	var path: String = LevelStorage.create_level("Paint Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame

	_check(window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and window.content_scale_size == Vector2i(640, 360),
		"the editor switches the window to canvas_items at 640x360")
	_check(editor.level_root != null and editor.level_root.is_inside_tree(), "the level is shown")
	_check(editor.level_root.get_script() == null, "without its RoomManager script (it never runs)")
	_check(editor.level_root.process_mode == Node.PROCESS_MODE_DISABLED, "with processing disabled")
	_check(editor.level_root.get_node_or_null("Player") == null and editor.level_root.get_node_or_null("PauseMenu") == null,
		"Player and pause menu are set aside while editing")
	_check(editor.set_aside_nodes.size() == 6, "six nodes set aside (Player, camera, 4 UI), got %d" % editor.set_aside_nodes.size())
	_check(not editor.is_dirty(), "a freshly opened level has no unsaved changes")
	_check(editor.ui.prompt.size == Vector2(640, 360), "the editor's prompt covers the whole screen, got %s" % editor.ui.prompt.size)

	var room: Room = editor.get_rooms()[0]
	var tiles: TileMapLayer = room.get_node("Tiles") as TileMapLayer
	var plain: Vector3i = Vector3i(0, TileBrush.TILE_PLAIN.x, TileBrush.TILE_PLAIN.y)
	var top_edge: Vector3i = Vector3i(0, TileBrush.TILE_TOP_EDGE.x, TileBrush.TILE_TOP_EDGE.y)

	# A floating platform: every cell has nothing above it, so all get the top edge.
	var platform: Array[Vector2i] = [Vector2i(10, 15), Vector2i(11, 15), Vector2i(12, 15), Vector2i(13, 15)]
	editor.paint_cells(room, platform, true)
	var all_top: bool = true
	for cell: Vector2i in platform:
		all_top = all_top and TileBrush.read_cell(tiles, cell) == top_edge
	_check(all_top, "painted platform cells get the top-edge tile")
	_check(editor.is_dirty(), "painting marks the level unsaved")

	# A block on top: it becomes the surface, the cell below turns plain.
	editor.paint_cells(room, [Vector2i(12, 14)], true)
	_check(TileBrush.read_cell(tiles, Vector2i(12, 14)) == top_edge and TileBrush.read_cell(tiles, Vector2i(12, 15)) == plain,
		"painting on top moves the edge up")
	editor.undo()
	_check(TileBrush.read_cell(tiles, Vector2i(12, 14)) == TileBrush.EMPTY and TileBrush.read_cell(tiles, Vector2i(12, 15)) == top_edge,
		"undo removes the block AND gives the cell below its edge back")
	editor.redo()
	_check(TileBrush.read_cell(tiles, Vector2i(12, 14)) == top_edge and TileBrush.read_cell(tiles, Vector2i(12, 15)) == plain, "redo puts it back")
	editor.paint_cells(room, [Vector2i(12, 14)], false)
	_check(TileBrush.read_cell(tiles, Vector2i(12, 14)) == TileBrush.EMPTY and TileBrush.read_cell(tiles, Vector2i(12, 15)) == top_edge,
		"erasing a block makes the cell below a surface again")

	# Rectangles, and cells outside the room.
	editor.fill_rectangle(room, Vector2i(23, 12), Vector2i(20, 10), true)
	_check(TileBrush.read_cell(tiles, Vector2i(20, 10)) == top_edge and TileBrush.read_cell(tiles, Vector2i(23, 12)) == plain,
		"a rectangle fills between its corners in any order, edge on top")
	var filled: int = 0
	for y: int in range(10, 13):
		for x: int in range(20, 24):
			filled += 1 if TileBrush.read_cell(tiles, Vector2i(x, y)) != TileBrush.EMPTY else 0
	_check(filled == 12, "the 4x3 rectangle has 12 tiles, got %d" % filled)
	editor.undo()
	_check(TileBrush.read_cell(tiles, Vector2i(21, 11)) == TileBrush.EMPTY, "one undo removes the whole rectangle")
	var version_before: int = editor.undo_redo.get_version()
	editor.paint_cells(room, [Vector2i(45, 5), Vector2i(-1, 3), Vector2i(5, 30)], true)
	_check(editor.undo_redo.get_version() == version_before and TileBrush.read_cell(tiles, Vector2i(45, 5)) == TileBrush.EMPTY,
		"cells outside the room are ignored, and no empty undo step is made")

	# A fast drag: the stroke fills the cells between two mouse positions.
	editor.begin_stroke(room, true)
	editor.last_stroke_cell = Vector2i(2, 6)
	editor._stroke_cell(Vector2i(2, 6))
	editor._continue_stroke(Vector2i(8, 6))
	editor.end_stroke()
	var gapless: bool = true
	for x: int in range(2, 9):
		gapless = gapless and TileBrush.read_cell(tiles, Vector2i(x, 6)) != TileBrush.EMPTY
	_check(gapless, "a fast drag from tile 2 to 8 paints every tile between")

	# Zoom: whole steps, clamped.
	_check(is_equal_approx(editor.camera.get_zoom_factor(), 1.0), "a one-screen room opens at 1x: the largest zoom where it fits between the panels")
	var zoom_before: int = editor.camera.zoom_index
	editor.camera.zoom_by(1, Vector2(320, 180))
	_check(editor.camera.zoom_index == zoom_before + 1, "zooming in goes up one whole step")
	editor.camera.zoom_by(10, Vector2(320, 180))
	_check(is_equal_approx(editor.camera.get_zoom_factor(), EditorCamera.ZOOM_LEVELS[-1]), "zoom stops at the largest step")

	# Save: the file is complete again, and editing goes on.
	_check(editor.save() == OK, "save() succeeds")
	_check(not editor.is_dirty(), "saving clears the unsaved state")
	_check(editor.level_root.is_inside_tree() and editor.level_root.get_script() == null and editor.level_root.get_node_or_null("Player") == null,
		"after saving, the editor is back to showing (not running) the level")
	editor.undo()
	_check(editor.is_dirty(), "undo after saving marks it unsaved")
	editor.redo()
	_check(not editor.is_dirty(), "redo back to the saved state is clean again")

	var saved: Node = LevelStorage.load_level(path).instantiate()
	_check(saved is RoomManager, "the saved level has its RoomManager script back")
	_check(saved.process_mode == Node.PROCESS_MODE_INHERIT, "and normal processing (not the editor's disabled state)")
	var saved_tiles: TileMapLayer = saved.get_node("Room1/Tiles") as TileMapLayer
	_check(TileBrush.read_cell(saved_tiles, Vector2i(10, 15)) == top_edge and TileBrush.read_cell(saved_tiles, Vector2i(5, 6)) != TileBrush.EMPTY,
		"the painted tiles are in the file")
	_check((saved as RoomManager).player != null and saved.get_node_or_null("PauseMenu") != null and saved.get_node_or_null("LevelInfo") != null,
		"Player, pause menu and LevelInfo are in the file")
	_check((saved as RoomManager).player.position == LevelTemplate.SPAWN_POSITION, "the Player stands on the start room's SpawnPoint")
	saved.free()

	# Play the saved level: the platform painted at row 15 is solid.
	var level: RoomManager = LevelStorage.load_level(path).instantiate() as RoomManager
	add_child(level)
	await get_tree().physics_frame
	level.player.respawn_at(Vector2(12 * 8 + 4, 15 * 8 - 20))
	await get_tree().create_timer(0.4).timeout
	_check(level.player.is_on_floor() and absf(level.player.global_position.y - 15 * 8) < 1.0,
		"in play, the player lands on the painted platform (y %.1f)" % level.player.global_position.y)
	level.queue_free()

	editor.queue_free()
	await get_tree().process_frame
	_check(window.content_scale_mode == game_scale_mode and window.content_scale_size == game_scale_size,
		"leaving the editor puts the window back to the game's settings")
	finished_sections.append("L2 editor")


## Stage L3: placing, moving, turning and deleting the basics (spawn point, goal,
## spikes), all undoable, and saved.
func _check_l3_objects() -> void:
	var ids: Array[StringName] = []
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.family != "":  # tools like the eraser have no family (no tab)
			ids.append(entry.id)
	_check(ids.slice(0, 4) == [&"ground", &"spawn_point", &"goal", &"spikes"], "the palette's tabs start with Ground + the three basics, got %s" % [ids])

	var path: String = LevelStorage.create_level("Object Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	_check(editor.ui.palette_buttons.size() == PaletteCatalog.get_entries().size(), "the palette has a button per catalog entry")
	editor.choose_entry(PaletteCatalog.get_entry(&"spikes"))
	var pressed_ids: Array[StringName] = []
	for id: StringName in editor.ui.palette_buttons:
		if (editor.ui.palette_buttons[id] as Button).button_pressed:
			pressed_ids.append(id)
	_check(pressed_ids == [&"spikes"], "only the chosen palette button looks pressed, got %s" % [pressed_ids])
	var room: Room = editor.get_rooms()[0]
	var goal_entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(&"goal")
	var spikes_entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(&"spikes")

	# Goal: stands on the clicked tile, centered on it.
	var goal: Goal = editor.place_object(goal_entry, room, Vector2i(30, 20)) as Goal
	_check(goal != null and goal.get_parent() == room and goal.owner == editor.level_root, "a placed goal is in the room and part of the saved level")
	_check(goal.position == Vector2(232, 136), "the goal stands on tile (30, 20): bottom at y 168, got %s" % goal.position)
	_check(editor.selected_object == goal, "a placed object is selected")
	_check(editor.object_at(goal.global_position + Vector2(12, 16)) == goal, "object_at finds the goal under the mouse")
	editor.undo()
	_check(goal.get_parent() == null and editor.selected_object == null, "undo takes the goal out (and unselects it)")
	editor.redo()
	_check(goal.get_parent() == room and goal.owner == editor.level_root, "redo puts the same goal back")

	# Spikes: drag along a row or column; facing from the neighbouring ground.
	var floor_spikes: Spikes = editor.place_strip(spikes_entry, room, Vector2i(8, 20), Vector2i(12, 21)) as Spikes
	_check(floor_spikes.facing == Spikes.Facing.UP and floor_spikes.tile_count == 5 and floor_spikes.position == Vector2(64, 160),
		"spikes dragged over the floor: 5 tiles, pointing up, at (64, 160)")
	var ceiling_spikes: Spikes = editor.place_strip(spikes_entry, room, Vector2i(17, 1), Vector2i(15, 1)) as Spikes
	_check(ceiling_spikes.facing == Spikes.Facing.DOWN and ceiling_spikes.tile_count == 3 and ceiling_spikes.position == Vector2(120, 8),
		"spikes under the ceiling point down, dragged right to left")
	var left_wall_spikes: Spikes = editor.place_strip(spikes_entry, room, Vector2i(1, 10), Vector2i(1, 13)) as Spikes
	_check(left_wall_spikes.facing == Spikes.Facing.RIGHT and left_wall_spikes.tile_count == 4, "a column on the left wall points right")
	var right_wall_spikes: Spikes = editor.place_strip(spikes_entry, room, Vector2i(38, 6), Vector2i(38, 5)) as Spikes
	_check(right_wall_spikes.facing == Spikes.Facing.LEFT and right_wall_spikes.position == Vector2(304, 40), "a column on the right wall points left")
	_check(PaletteCatalog.get_bounds(left_wall_spikes) == Rect2(Vector2(8, 80), Vector2(8, 32)), "a vertical strip's outline is 1x4 tiles")

	_check(editor.rotate_object(floor_spikes) and floor_spikes.facing == Spikes.Facing.RIGHT, "R turns spikes a quarter turn (up -> right)")
	editor.undo()
	_check(floor_spikes.facing == Spikes.Facing.UP, "undo turns them back")
	_check(not editor.rotate_object(goal), "only spikes can be turned")

	# Move and delete.
	editor.move_object(goal, goal.position + Vector2(16, 0))
	_check(goal.position == Vector2(248, 136), "move_object moves")
	editor.undo()
	_check(goal.position == Vector2(232, 136), "undo moves it back")
	var spikes_index: int = ceiling_spikes.get_index()
	_check(editor.delete_object(ceiling_spikes) and ceiling_spikes.get_parent() == null, "delete_object takes the spikes out")
	editor.undo()
	_check(ceiling_spikes.get_parent() == room and ceiling_spikes.get_index() == spikes_index and ceiling_spikes.owner == editor.level_root,
		"undo puts the same spikes back in their place in the room")

	# The spawn point: one per room, moved, never deleted.
	var spawn_point: Marker2D = room.get_node("SpawnPoint") as Marker2D
	_check(editor.place_spawn_point(room, Vector2i(5, 20)) == spawn_point and spawn_point.position == Vector2(44, 168),
		"placing a spawn point moves the room's own one to the tile's bottom middle")
	_check(not editor.delete_object(spawn_point) and spawn_point.get_parent() == room, "the spawn point can't be deleted")
	_check(editor.object_at(spawn_point.global_position + Vector2(0, -6)) == spawn_point, "object_at finds the spawn point's marker")

	# Saved: the objects and their settings; their drawn parts are rebuilt on load.
	_check(editor.save() == OK, "saving the objects works")
	var file_text: String = FileAccess.get_file_as_string(path)
	_check(not file_text.contains("Polygon2D"), "the spikes' triangles (made in _ready) aren't saved")
	var saved: Node = LevelStorage.load_level(path).instantiate()
	var saved_room: Node = saved.get_node("Room1")
	var saved_spikes: Array[Spikes] = []
	var saved_goals: int = 0
	for child: Node in saved_room.get_children():
		if child is Spikes:
			saved_spikes.append(child)
		elif child is Goal:
			saved_goals += 1
	_check(saved_spikes.size() == 4 and saved_goals == 1, "the file has 4 spike strips and the goal, got %d and %d" % [saved_spikes.size(), saved_goals])
	var saved_ceiling: Spikes = saved_room.get_node(NodePath(ceiling_spikes.name)) as Spikes
	_check(saved_ceiling != null and saved_ceiling.facing == Spikes.Facing.DOWN and saved_ceiling.tile_count == 3, "facing and length are saved")
	_check((saved.get_node("Player") as Node2D).position == Vector2(44, 168), "the saved Player starts on the moved spawn point")
	saved.free()

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L3 objects")


## Stage L3: play-testing from the editor and coming back.
func _check_l3_playtest() -> void:
	var window: Window = get_window()
	var game_scale_mode: Window.ContentScaleMode = window.content_scale_mode
	var game_scale_size: Vector2i = window.content_scale_size
	var path: String = LevelStorage.list_levels().filter(func(level_path: String) -> bool: return level_path.ends_with("object_level.tscn"))[0]
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var room: Room = editor.get_rooms()[0]
	var goal: Goal = null
	for child: Node in room.get_children():
		if child is Goal:
			goal = child
	editor.paint_cells(room, [Vector2i(20, 10)], true)  # an unsaved change, to see it survive
	var version_before: int = editor.undo_redo.get_version()
	editor.select(goal)

	_check(editor.get_play_blocker() == "" and editor.get_play_warnings().is_empty(), "nothing blocks or warns: spawn point and goal are there")
	_check(editor.start_playtest(), "Tab starts a play-test")
	var play_root: RoomManager = editor.play_root
	_check(editor.is_playtesting and play_root != null and play_root.is_inside_tree(), "a copy of the level runs")
	_check(window.content_scale_mode == game_scale_mode and window.content_scale_size == game_scale_size, "at the game's own 320x180 settings")
	_check(not editor.visible and not editor.ui.visible, "the editor hides meanwhile")
	_check(play_root.get_node_or_null("EndScreen") == null, "the copy has no end screen (it would reload the editor)")
	var pause_menu: PauseMenu = play_root.get_node("PauseMenu") as PauseMenu
	var pause_texts: Array[String] = []
	for button: Node in pause_menu.find_children("*", "Button", true, false):
		pause_texts.append((button as Button).text)
	_check(pause_texts.has("Back to editor") and not pause_texts.has("Main menu"), "the pause menu offers Back to editor instead of Main menu, got %s" % [pause_texts])
	var painted_tiles: TileMapLayer = play_root.get_node("Room1/Tiles") as TileMapLayer
	_check(painted_tiles.get_cell_source_id(Vector2i(20, 10)) != -1, "the play-test includes the unsaved painting")
	await get_tree().create_timer(0.4).timeout
	_check(play_root.player.is_on_floor() and play_root.player.global_position == Vector2(44, 168), "the player starts on the spawn point and stands")
	pause_menu._on_back_to_editor_pressed()
	_check(not editor.is_playtesting and editor.visible and editor.ui.visible, "Back to editor ends the play-test")
	_check(window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and window.content_scale_size == Vector2i(640, 360), "the editor's window settings are back")
	_check(editor.undo_redo.get_version() == version_before and editor.is_dirty() and editor.selected_object == goal,
		"undo history, unsaved changes and selection are kept")
	await get_tree().process_frame
	_check(not is_instance_valid(play_root), "the play copy is freed")

	# Shift+Tab: from the mouse, inside a room only.
	var start_point: Vector2 = room.global_position + Vector2(100, 100)
	_check(editor.start_playtest(start_point) and editor.play_root.player.global_position == start_point, "Shift+Tab drops the player at the mouse")
	await get_tree().create_timer(0.5).timeout
	_check(editor.play_root.player.is_on_floor(), "and they fall to the floor")
	editor.stop_playtest()
	_check(not editor.start_playtest(Vector2(-500, -500)) and not editor.is_playtesting, "Shift+Tab outside every room doesn't start")

	# Reaching the goal: back in the editor with the time and deaths.
	_check(editor.start_playtest(), "play again")
	editor.play_root.player.respawn_at(goal.global_position + Vector2(12, 32))
	await get_tree().create_timer(LevelEditor.GOAL_RETURN_DELAY + 0.4).timeout
	_check(not editor.is_playtesting and editor.ui.message_label.text.begins_with("Goal reached"),
		"touching the goal returns to the editor: \"%s\"" % editor.ui.message_label.text)

	# Checks before playing: a start room without a spawn point blocks; no goal only warns.
	var spawn_point: Marker2D = room.get_node("SpawnPoint") as Marker2D
	room.remove_child(spawn_point)
	_check(editor.get_play_blocker() != "" and not editor.start_playtest(), "a start room without a spawn point can't be played")
	room.add_child(spawn_point)
	LevelStorage.adopt(spawn_point, editor.level_root)
	editor.delete_object(goal)
	var warnings: Array[String] = editor.get_play_warnings()
	_check(warnings.size() == 1 and warnings[0].begins_with("No goal"), "no goal is a warning, got %s" % [warnings])
	_check(editor.start_playtest(), "and doesn't stop the play-test")
	# One frame of play: the debug overlay adds its F5 tuning panel deferred, and a
	# copy freed in its very first frame would leave that panel behind.
	await get_tree().process_frame
	editor.stop_playtest()
	_check(editor.ui.message_label.text.contains("No goal"), "the warning shows when you come back")

	editor.queue_free()
	await get_tree().process_frame
	_check(window.content_scale_mode == game_scale_mode, "leaving the editor restores the game's window settings")
	finished_sections.append("L3 play-test")


## Stage L4: the Air objects in the catalog, palette tabs, snapped and free
## placement, copying with Ctrl+D, and a play-test with all of them.
func _check_l4_air_objects() -> void:
	_check(PaletteCatalog.get_families().slice(0, 3) == ["Terrain", "Basics", "Air"], "the palette's tabs start Terrain, Basics, Air, got %s" % [PaletteCatalog.get_families()])
	var air_ids: Array[StringName] = []
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.family == "Air":
			air_ids.append(entry.id)
	_check(air_ids == [&"wind_zone", &"wind_crystal", &"gust_diamond", &"crate", &"windmill", &"leaf_platform",
		&"sail_platform", &"door", &"pressure_plate", &"no_glide_zone"], "Air has all ten objects, got %s" % [air_ids])

	var path: String = LevelStorage.create_level("Air Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var room: Room = editor.get_rooms()[0]

	# Tabs: choosing an entry opens its family's tab.
	editor.choose_entry(PaletteCatalog.get_entry(&"crate"))
	_check(editor.ui.open_family == "Air" and (editor.ui.family_lists["Air"] as Control).visible
		and not (editor.ui.family_lists["Basics"] as Control).visible, "choosing the crate opens the Air tab and hides the others")
	editor.ui.show_family("Terrain")
	_check((editor.ui.family_lists["Terrain"] as Control).visible and not (editor.ui.family_lists["Air"] as Control).visible, "clicking a tab shows its entries")

	# Every Air object can be placed, found, and is recognised by the catalog.
	var cells: Dictionary = {
		&"wind_zone": Vector2i(5, 5), &"wind_crystal": Vector2i(20, 10), &"gust_diamond": Vector2i(22, 10),
		&"crate": Vector2i(10, 20), &"windmill": Vector2i(33, 12), &"leaf_platform": Vector2i(15, 12),
		&"sail_platform": Vector2i(26, 5), &"door": Vector2i(30, 10), &"pressure_plate": Vector2i(25, 20),
		&"no_glide_zone": Vector2i(12, 2),
	}
	var placed: Dictionary = {}
	var all_found: bool = true
	for id: StringName in air_ids:
		var entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(id)
		var node: Node2D = editor.place_object(entry, room, cells[id])
		placed[id] = node
		var outline: Rect2 = PaletteCatalog.get_bounds(node)
		var found: bool = node.get_parent() == room and PaletteCatalog.entry_for_node(node) == entry \
			and outline.has_area() and editor.object_at(outline.get_center(), true) == node
		if not found:
			print("    %s: not found under its own outline %s" % [id, outline])
		all_found = all_found and found
	_check(all_found, "all ten Air objects are placed, recognised and picked under the mouse")

	# Where they land: outlines snapped to the grid, the way each object stands.
	_check((placed[&"crate"] as Node2D).position == Vector2(88, 168), "the crate stands on the floor, its 2-tile width on tile lines, got %s" % (placed[&"crate"] as Node2D).position)
	_check(PaletteCatalog.get_bounds(placed[&"crate"]) == Rect2(80, 152, 16, 16), "so its outline covers exactly two tiles")
	_check((placed[&"wind_zone"] as Node2D).position == Vector2(40, 40), "a wind zone starts at the clicked tile's corner")
	_check((placed[&"wind_crystal"] as Node2D).position == Vector2(164, 84), "a crystal sits in the middle of its tile")
	_check((placed[&"pressure_plate"] as Node2D).position == Vector2(204, 168), "a 3-tile plate lies on the floor centered on its tile")
	_check((placed[&"leaf_platform"] as Node2D).position == Vector2(128, 96), "a leaf hangs from the tile's top, its 4-tile width on tile lines")
	_check((placed[&"door"] as Node2D).position == Vector2(240, 80), "a door starts at the clicked tile's corner")
	_check(PaletteCatalog.get_entry(&"wind_zone").editor_color.a > 0.0, "wind zones get a stand-in (they're only particles)")

	# Moving a sail or leaf takes its rail / path along (worked out once in _ready).
	var sail: SailPlatform = placed[&"sail_platform"] as SailPlatform
	editor.move_object(sail, sail.position + Vector2(0, 40))
	_check(sail.rail_start_position == sail.position + sail.rail_start and sail.rail_end_position == sail.position + sail.rail_end,
		"a moved sail's rail moves with it")
	editor.undo()
	_check(sail.rail_start_position == sail.position + sail.rail_start, "and back again on undo")
	var leaf: LeafPlatform = placed[&"leaf_platform"] as LeafPlatform
	editor.move_object(leaf, leaf.position + Vector2(-16, 8))
	_check(leaf.home_position == leaf.position, "a moved leaf's home moves with it")

	# Alt: free placement, centered right on the mouse.
	var free_crystal: Node2D = editor.place_object_at(PaletteCatalog.get_entry(&"wind_crystal"), room, Vector2(101.5, 50.25), true)
	_check(free_crystal.position == Vector2(101.5, 50.25), "with Alt, a crystal goes exactly where clicked")
	editor.undo()

	# Ctrl+D: a copy with the same settings, its own link list, undoable.
	var door: Door = placed[&"door"] as Door
	door.door_size = Vector2(8, 48)
	door.switches = [placed[&"pressure_plate"] as Switch]
	var copy: Door = editor.duplicate_object(door, room, Vector2(36 * 8 + 4, 3 * 8 + 4)) as Door
	_check(copy != null and copy != door and copy.get_parent() == room and copy.door_size == Vector2(8, 48),
		"Ctrl+D copies the door with its size")
	_check(copy.position == Vector2(288, 24), "the copy is placed like a new door, at the mouse's tile, got %s" % copy.position)
	_check(copy.switches.size() == 1 and copy.switches[0] == placed[&"pressure_plate"], "the copy keeps the door's links")
	copy.switches.clear()
	_check(door.switches.size() == 1, "but in a list of its own: changing the copy's links leaves the original's")
	_check(editor.selected_object == copy, "the copy is selected")
	editor.undo()
	_check(copy.get_parent() == null, "undo removes the copy")
	_check(editor.duplicate_object(room.get_node("SpawnPoint") as Node2D, room, Vector2(80, 80)) == null, "the spawn point can't be copied")

	# Saved, and playable with all of them in.
	_check(editor.save() == OK, "a level with every Air object saves")
	var saved: Node = LevelStorage.load_level(path).instantiate()
	var saved_ids: Array[StringName] = []
	for child: Node in saved.get_node("Room1").get_children():
		var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(child)
		if entry != null and entry.family == "Air":
			saved_ids.append(entry.id)
	saved_ids.sort()
	var expected_ids: Array[StringName] = air_ids.duplicate()
	expected_ids.sort()
	_check(saved_ids == expected_ids, "all ten are in the file, got %s" % [saved_ids])
	_check((saved.get_node("Room1/%s" % door.name) as Door).door_size == Vector2(8, 48), "with their settings")
	saved.free()
	_check(editor.start_playtest(), "the Air level play-tests")
	await get_tree().create_timer(0.5).timeout
	_check(editor.play_root.player.is_on_floor(), "and the player stands in it")
	editor.stop_playtest()

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L4 Air objects")


## Stage L5: the property panel (a widget per setting type, undoable, merged
## while scrubbing), room settings, and the drag handles' math.
func _check_l5_properties() -> void:
	var path: String = LevelStorage.create_level("Panel Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var room: Room = editor.get_rooms()[0]
	var panel: PropertyPanel = editor.ui.property_panel
	var door: Door = editor.place_object(PaletteCatalog.get_entry(&"door"), room, Vector2i(30, 10)) as Door

	# A placed object is selected, so the panel shows its settings.
	_check(panel.target == door and panel.title_label.text.begins_with("Door"), "the panel shows the selected door")
	_check(panel.widgets.keys() == [&"door_size", &"link_mode", &"open_when_off", &"retract_toward"],
		"one widget per setting the catalog lists, got %s" % [panel.widgets.keys()])
	_check(panel.widgets[&"door_size"]["kind"] == "vector" and panel.widgets[&"link_mode"]["kind"] == "enum"
		and panel.widgets[&"open_when_off"]["kind"] == "bool", "Vector2 -> x/y fields, enum -> dropdown, bool -> checkbox")

	# Vector2 field: changing x resizes the door; undo shrinks it back and the field follows.
	(panel.widgets[&"door_size"]["x"] as SpinBox).value = 16.0
	_check(door.door_size == Vector2(16, 32), "the x field changes door_size, got %s" % door.door_size)
	editor.undo()
	_check(door.door_size == Vector2(8, 32) and is_equal_approx((panel.widgets[&"door_size"]["x"] as SpinBox).value, 8.0),
		"undo puts it back, and the panel shows the old value")
	# Dropdown and checkbox.
	var retract_box: OptionButton = panel.widgets[&"retract_toward"]["control"]
	retract_box.select(retract_box.get_item_index(Door.RetractToward.DOWN))
	retract_box.item_selected.emit(retract_box.selected)
	_check(door.retract_toward == Door.RetractToward.DOWN, "the dropdown sets the enum")
	(panel.widgets[&"open_when_off"]["control"] as CheckBox).button_pressed = true
	_check(door.open_when_off, "the checkbox sets the bool")

	# Wind zone: the 8-way picker, and a float; quick changes to one setting merge.
	var wind_zone: WindZone = editor.place_object(PaletteCatalog.get_entry(&"wind_zone"), room, Vector2i(4, 4)) as WindZone
	_check(panel.widgets[&"wind_direction"]["kind"] == "direction", "wind_direction gets the 8-way picker")
	(panel.widgets[&"wind_direction"]["control"] as DirectionPicker).direction_picked.emit(Vector2.LEFT)
	_check(wind_zone.wind_direction == Vector2.LEFT, "picking left turns the wind left")
	var strength_box: SpinBox = panel.widgets[&"wind_strength"]["control"]
	var start_strength: float = wind_zone.wind_strength
	strength_box.value = start_strength + 10.0
	strength_box.value = start_strength + 20.0
	_check(is_equal_approx(wind_zone.wind_strength, start_strength + 20.0), "the number field sets wind_strength")
	editor.undo()
	_check(is_equal_approx(wind_zone.wind_strength, start_strength) and wind_zone.wind_direction == Vector2.LEFT,
		"two quick changes to one setting are ONE undo step (the direction stays)")

	# Spikes: an int with a range, as an int.
	var spikes: Spikes = editor.place_strip(PaletteCatalog.get_entry(&"spikes"), room, Vector2i(8, 20), Vector2i(12, 20)) as Spikes
	var count_box: SpinBox = panel.widgets[&"tile_count"]["control"]
	_check(is_equal_approx(count_box.max_value, 40.0), "@export_range(1, 40) sets the field's limits")
	count_box.value = 3.0
	_check(spikes.tile_count == 3 and typeof(spikes.get(&"tile_count")) == TYPE_INT, "tile_count is set as an int")

	# Nothing selected: the room's settings.
	editor.select(null)
	_check(panel.target == room and panel.widgets.keys() == LevelEditor.ROOM_SETTINGS, "with nothing selected, the panel shows the room")
	var title_field: LineEdit = panel.widgets[&"display_title"]["control"]
	title_field.text = "Windy Hall"
	title_field.text_submitted.emit(title_field.text)
	_check(room.display_title == "Windy Hall", "the room title is set on Enter")
	(panel.widgets[&"air_allowed"]["control"] as CheckBox).button_pressed = false
	_check(not room.air_allowed, "Air can be switched off for the room")
	editor.undo()
	_check(room.air_allowed and (panel.widgets[&"air_allowed"]["control"] as CheckBox).button_pressed, "undo switches it back on, in the panel too")
	_check(is_equal_approx((panel.widgets[&"fire_start_pips"]["control"] as SpinBox).max_value, 10.0), "fire start pips go 0 to 10")
	editor.select(editor.place_spawn_point(room, Vector2i(3, 20)))
	_check(panel.widgets.is_empty(), "the spawn point has no settings")

	# Handles: where they are and what dragging them gives.
	var door_handles: Array[Dictionary] = EditorHandles.get_handles(door)
	_check(door_handles.size() == 1 and door_handles[0]["position"] == door.global_position + door.door_size, "a door has a size handle on its bottom-right corner")
	_check(EditorHandles.handle_at(door, door.global_position + door.door_size + Vector2(1, -1), 1.5) == door_handles[0], "the handle is picked near its corner")
	_check(EditorHandles.value_for_drag(door, door_handles[0], door.global_position + Vector2(13, 41), false) == Vector2(16, 40),
		"dragging it snaps the size to whole tiles")
	_check(EditorHandles.value_for_drag(door, door_handles[0], door.global_position + Vector2(13, 41), true) == Vector2(13, 41),
		"with Alt, to the pixel")
	_check(EditorHandles.value_for_drag(door, door_handles[0], door.global_position + Vector2(-20, -5), false) == Vector2(8, 8),
		"never smaller than a tile")
	var crate: Crate = editor.place_object(PaletteCatalog.get_entry(&"crate"), room, Vector2i(20, 20)) as Crate
	var crate_handle: Dictionary = EditorHandles.get_handles(crate)[0]
	_check(EditorHandles.value_for_drag(crate, crate_handle, crate.global_position + Vector2(12, -28), false) == Vector2(24, 32),
		"a crate grows around its feet: twice the distance sideways, all of it up")
	var leaf: LeafPlatform = editor.place_object(PaletteCatalog.get_entry(&"leaf_platform"), room, Vector2i(15, 12)) as LeafPlatform
	var leaf_handles: Array[Dictionary] = EditorHandles.get_handles(leaf)
	_check(leaf_handles.size() == 2 and leaf_handles[0]["kind"] == EditorHandles.Kind.WIDTH and leaf_handles[1]["kind"] == EditorHandles.Kind.POINT,
		"a leaf has a width handle and a travel point")
	_check(EditorHandles.value_for_drag(leaf, leaf_handles[0], leaf.global_position + Vector2(22, 4), false) == 48.0, "the width handle sets the full width, snapped")
	_check(EditorHandles.value_for_drag(leaf, leaf_handles[1], leaf.global_position + Vector2(12, -46), false) == Vector2(16, -48), "the travel point snaps to the grid")
	var strip_handle: Dictionary = EditorHandles.get_handles(spikes)[0]
	_check(EditorHandles.value_for_drag(spikes, strip_handle, spikes.global_position + Vector2(56, 4), false) == 7, "the strip's end handle sets its length in tiles")

	# A drag, as the editor records it: changed live, then one step from the start.
	var sail: SailPlatform = editor.place_object(PaletteCatalog.get_entry(&"sail_platform"), room, Vector2i(26, 6)) as SailPlatform
	var old_rail_end: Vector2 = sail.rail_end
	editor._apply_property(sail, &"rail_end", Vector2(80, 0))
	editor._apply_property(sail, &"rail_end", Vector2(96, 0))
	editor.set_property(sail, &"rail_end", sail.rail_end, old_rail_end)
	_check(sail.rail_end == Vector2(96, 0) and sail.rail_end_position == sail.position + Vector2(96, 0), "a rail end dragged out: the rail follows")
	editor.undo()
	_check(sail.rail_end == old_rail_end and sail.rail_end_position == sail.position + old_rail_end, "one undo takes the whole drag back")

	# Saved.
	_check(editor.save() == OK, "save")
	var saved: Node = LevelStorage.load_level(path).instantiate()
	var saved_room: Room = saved.get_node("Room1") as Room
	var saved_door: Door = saved_room.get_node(NodePath(door.name)) as Door
	_check(saved_room.display_title == "Windy Hall" and saved_door.retract_toward == Door.RetractToward.DOWN and saved_door.open_when_off,
		"room and object settings are saved")
	_check((saved_room.get_node(NodePath(wind_zone.name)) as WindZone).wind_direction == Vector2.LEFT, "the wind's direction too")
	saved.free()

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L5 properties")


## Stage L6: the link tool. Linking and unlinking (undoable, never merged), what
## can be linked, deleting a target, saving, and a plate opening a door in play.
func _check_l6_links() -> void:
	var path: String = LevelStorage.create_level("Link Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var room: Room = editor.get_rooms()[0]
	var plate: PressurePlate = editor.place_object(PaletteCatalog.get_entry(&"pressure_plate"), room, Vector2i(10, 20)) as PressurePlate
	var windmill: Windmill = editor.place_object(PaletteCatalog.get_entry(&"windmill"), room, Vector2i(20, 8)) as Windmill
	var crate: Crate = editor.place_object(PaletteCatalog.get_entry(&"crate"), room, Vector2i(4, 20)) as Crate
	var door: Door = editor.place_object(PaletteCatalog.get_entry(&"door"), room, Vector2i(30, 17)) as Door

	# Link mode.
	_check(not editor.start_link_mode(plate) and editor.link_source == null, "a plate has no links: L does nothing for it")
	_check(editor.start_link_mode(door) and editor.link_source == door, "L on a door starts link mode")
	_check(editor.ui.property_panel.footer_label.text.begins_with("Links: 0"), "the panel shows the door's link count")
	_check(editor.toggle_link(door, plate) and door.switches == [plate], "clicking the plate links it")
	_check(editor.toggle_link(door, windmill) and door.switches == [plate, windmill], "a windmill too: a door can follow several switches")
	_check(not editor.toggle_link(door, crate) and door.switches.size() == 2, "a crate isn't a switch: refused")
	_check(not editor.toggle_link(door, door), "a door can't link to itself")
	_check(editor.ui.property_panel.footer_label.text.begins_with("Links: 2"), "the link count follows")
	_check(editor.toggle_link(door, plate) and door.switches == [windmill], "clicking a linked switch again unlinks it")
	editor.undo()
	_check(door.switches == [plate, windmill], "undo links it again (one step per click: link steps never merge)")
	_check(editor.get_links().size() == 2, "the overlay gets both links to draw")
	editor.end_link_mode()
	_check(editor.link_source == null, "L or Esc ends link mode")

	# Crates hang from vines only (Fire); nothing here fits.
	_check(editor.start_link_mode(crate), "a crate has links (the vines it hangs from)")
	_check(not editor.toggle_link(crate, plate) and crate.hung_from.is_empty(), "a plate isn't a vine: a crate never ends up floating on one")
	editor.end_link_mode()

	# Deleting a target drops it from every link list, in the same undo step.
	_check(editor.delete_object(windmill) and door.switches == [plate], "deleting the windmill unlinks it from the door")
	editor.undo()
	_check(windmill.get_parent() == room and door.switches == [plate, windmill], "undo brings the windmill back AND its link")
	editor.select(door)
	editor.start_link_mode(door)
	editor.delete_object(door)
	await get_tree().process_frame
	_check(editor.link_source == null, "deleting the door being linked ends link mode")
	editor.undo()

	# Saved: the links are node references, stored as paths in the scene.
	_check(editor.save() == OK, "save")
	var saved: Node = LevelStorage.load_level(path).instantiate()
	var saved_door: Door = saved.get_node("Room1/%s" % door.name) as Door
	_check(saved_door.switches.size() == 2 and saved_door.switches[0] == saved.get_node("Room1/%s" % plate.name)
		and saved_door.switches[1] == saved.get_node("Room1/%s" % windmill.name), "the saved door is linked to the saved plate and windmill")
	saved.free()

	# In play: a crate pushed onto the plate opens the door.
	_check(editor.start_playtest(), "play")
	var play_room: Node = editor.play_root.get_node("Room1")
	var play_door: Door = play_room.get_node(NodePath(door.name)) as Door
	var play_crate: Crate = play_room.get_node(NodePath(crate.name)) as Crate
	var play_plate: PressurePlate = play_room.get_node(NodePath(plate.name)) as PressurePlate
	await get_tree().create_timer(0.2).timeout
	_check(not play_plate.is_on() and play_door.open_amount < 0.1, "the door starts closed")
	play_crate.global_position = play_plate.global_position + Vector2(0, -2)
	await get_tree().create_timer(0.6).timeout
	_check(play_plate.is_on() and play_door.open_amount > 0.9, "a crate on the plate opens the linked door (open %.2f)" % play_door.open_amount)
	editor.stop_playtest()

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L6 links")


## After L6 (play-test feedback): zones are picked by their edge, so clicks
## inside reach what's in them; the eraser; the quick reference.
func _check_l6b_zones_eraser_help() -> void:
	var path: String = LevelStorage.create_level("Eraser Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var room: Room = editor.get_rooms()[0]
	var zone: Node2D = editor.place_object(PaletteCatalog.get_entry(&"no_glide_zone"), room, Vector2i(12, 2))
	var crystal: Node2D = editor.place_object(PaletteCatalog.get_entry(&"wind_crystal"), room, Vector2i(15, 6))
	var outline: Rect2 = PaletteCatalog.get_bounds(zone)
	var inside: Vector2 = outline.position + Vector2(40, 70)  # inside the zone, away from the crystal

	# Zones: the edge picks them; inside, clicks pass through.
	editor.choose_entry(PaletteCatalog.get_entry(&"crate"))
	_check(editor.object_at(inside) == null, "with another tool, a click inside a zone doesn't pick the zone")
	_check(editor.object_at(crystal.global_position) == crystal, "a crystal inside the zone is picked")
	_check(editor.object_at(outline.position + Vector2(1, 40)) == zone, "the zone is picked on its edge")
	_check(editor.object_at(inside, true) == zone, "the eraser / right-click reach it from inside")
	editor.choose_entry(PaletteCatalog.get_entry(&"no_glide_zone"))
	_check(editor.object_at(inside) == zone, "with its own tool chosen, anywhere inside picks it")
	# The reported bug: a crate placed inside the no-glide zone.
	editor.choose_entry(PaletteCatalog.get_entry(&"crate"))
	editor._on_left_pressed(inside)
	editor._on_mouse_released(inside)
	var placed: Node2D = editor.selected_object
	_check(placed is Crate and placed.get_parent() == room and outline.has_point(placed.global_position),
		"clicking inside the zone with the crate tool places a crate there")

	# Eraser: E on and off, back to the tool before.
	editor.toggle_eraser()
	_check(editor.current_entry.kind == PaletteCatalog.Kind.ERASER and editor.ui.palette_buttons[&"eraser"].button_pressed,
		"E turns the eraser on (its button shows it)")
	editor.toggle_eraser()
	_check(editor.current_entry.id == &"crate", "E again goes back to the crate tool")
	editor.toggle_eraser()
	_check(editor.ui.family_lists.size() == PaletteCatalog.get_families().size() and not editor.ui.family_lists.has(""), "the eraser has no tab of its own")

	editor.erase_at(crystal.global_position)
	_check(crystal.get_parent() == null, "the eraser removes the crystal")
	editor.erase_at(inside)
	_check(placed.get_parent() == null, "then the crate inside the zone")
	editor.erase_at(inside)
	_check(zone.get_parent() == null, "then the zone itself, clicked inside")
	editor.undo()
	_check(zone.get_parent() == room, "undo brings the zone back")
	var spawn_point: Node2D = room.get_node("SpawnPoint") as Node2D
	editor.erase_at(spawn_point.global_position + Vector2(0, -4))
	_check(spawn_point.get_parent() == room, "the spawn point stays (every room needs one)")

	# Tiles: a drag erases a row in one undo step.
	editor.paint_cells(room, [Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10)], true)
	var tiles: TileMapLayer = room.get_node("Tiles") as TileMapLayer
	var cell_center: Callable = func(cell: Vector2i) -> Vector2: return room.global_position + Vector2(cell * 8) + Vector2(4, 4)
	editor.erase_at(cell_center.call(Vector2i(5, 10)))
	editor.erase_at(cell_center.call(Vector2i(7, 10)), true)  # dragged across: 6 too
	editor.end_stroke()
	var row_empty: bool = true
	for x: int in range(5, 8):
		row_empty = row_empty and TileBrush.read_cell(tiles, Vector2i(x, 10)) == TileBrush.EMPTY
	_check(row_empty, "dragging the eraser over ground removes every tile on the way")
	editor.undo()
	_check(TileBrush.read_cell(tiles, Vector2i(6, 10)) != TileBrush.EMPTY and TileBrush.read_cell(tiles, Vector2i(5, 10)) != TileBrush.EMPTY,
		"one undo puts the whole drag back")

	# Quick reference.
	_check(not editor.ui.help.visible, "the help starts closed")
	editor.ui.help.open()
	_check(editor.ui.help.visible and editor.ui.is_over_panels(Vector2(320, 180)), "H opens it over everything")
	_check(EditorHelp.key_text("editor_undo") == "Ctrl+Z" and EditorHelp.key_text("editor_redo").begins_with("Ctrl+Y"),
		"keys are read from the InputMap: %s, %s" % [EditorHelp.key_text("editor_undo"), EditorHelp.key_text("editor_redo")])
	_check(EditorHelp.key_text("editor_paint") == "Left click" and EditorHelp.key_text("editor_eraser") == "E", "mouse buttons and plain keys read well")
	var missing: Array[String] = []
	for section: Array in EditorHelp.LEFT_SECTIONS + EditorHelp.RIGHT_SECTIONS:
		for row: Array in section[1]:
			var key: String = row[0]
			if key.begins_with("editor_") and not InputMap.has_action(key):
				missing.append(key)
	_check(missing.is_empty(), "every action the help lists exists, missing: %s" % [missing])
	editor.ui.help.close()
	_check(not editor.ui.help.visible, "and it closes")

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L6b zones, eraser, help")


## Stage L7: the map of rooms: snapping, making, moving and resizing rooms,
## refused overlaps, openings, the start room, deleting rooms (and their links).
func _check_l7_map() -> void:
	var path: String = LevelStorage.create_level("Map Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var map: MapView = editor.map_view
	var room1: Room = editor.get_rooms()[0]
	var zoom_before: float = editor.camera.get_zoom_factor()
	editor.toggle_map()
	_check(map.is_open and editor.camera.get_zoom_factor() <= zoom_before, "M opens the map, zoomed out")
	_check(InputMap.has_action("editor_map") and InputMap.has_action("editor_start_room") and InputMap.has_action("editor_import"),
		"the map's keys are InputMap actions")

	# Snapping: widths in tiles (at least 320), heights 180 + tiles.
	_check(MapView.snap_width(300.0) == 320.0 and MapView.snap_width(333.0) == 336.0, "widths snap to whole tiles, at least one screen")
	_check(MapView.snap_height(170.0) == 180.0 and MapView.snap_height(185.0) == 188.0 and MapView.snap_height(364.0) == 364.0,
		"heights snap to 180 + whole tiles")
	_check(map.snap_moved(Rect2(323, 4, 320, 180), null, 8.0).position == Vector2(320, 0), "a moved room snaps next to its neighbour")
	_check(map.snap_moved(Rect2(-3, 183, 320, 180), null, 8.0).position == Vector2(0, 180), "and under it, at y = 180 (off the 8 px grid)")
	_check(map.snap_new_room(Vector2(330, 2), Vector2(500, 40), 8.0) == Rect2(320, 0, 320, 180), "a dragged new room gets the smallest size and snaps")

	# Making rooms: an L shape.
	var room2: Room = map.create_room(Rect2(320, 0, 320, 180))
	_check(room2 != null and editor.get_rooms().size() == 2, "dragging on empty space makes a room")
	_check(room2.get_node_or_null("Tiles") == null and room2.get_node_or_null("SpawnPoint") != null and room2.owner == editor.level_root,
		"a new room is empty but for its spawn point, and part of the level")
	_check(room2.painted_ground and room2.get_node_or_null("GroundPainter") is GroundPainter, "its ground will be painted, not flat tiles")
	_check(map.create_room(Rect2(400, 0, 320, 180)) == null and editor.get_rooms().size() == 2, "an overlapping room is refused")
	var room3: Room = map.create_room(Rect2(320, 180, 320, 188))
	_check(room3 != null and room3.room_size == Vector2(320, 188), "a room under it, 188 tall")
	editor.current_room = room3
	editor.choose_entry(PaletteCatalog.get_entry(&"ground"))
	var fill_button: Button = null
	for child: Node in editor.ui.property_panel.rows.get_children():
		if child is Button and (child as Button).text.begins_with("Fill edges"):
			fill_button = child
	_check(fill_button != null and fill_button.text == "Fill edges: Ground", "the room panel has a Fill edges button for the chosen terrain")
	fill_button.pressed.emit()
	var room3_tiles: TileMapLayer = room3.get_node("Tiles") as TileMapLayer
	_check(room3_tiles.get_cell_source_id(Vector2i(5, 22)) != -1 and room3_tiles.get_cell_source_id(Vector2i(5, 23)) != -1
		and room3_tiles.get_cell_source_id(Vector2i(5, 21)) == -1 and room3_tiles.get_cell_source_id(Vector2i(0, 10)) != -1
		and room3_tiles.get_cell_source_id(Vector2i(5, 0)) != -1, "it fills walls, ceiling and a 2-row floor (the last row hangs half out)")
	editor.undo()
	_check(room3_tiles.get_used_cells().is_empty(), "one undo empties it again")
	editor.redo()
	editor.undo()
	editor.undo()
	_check(editor.get_rooms().size() == 2 and not room3.is_inside_tree(), "undo takes a new room away")
	editor.redo()
	editor.redo()
	_check(editor.get_rooms().size() == 3 and room3.is_inside_tree() and not room3_tiles.get_used_cells().is_empty(), "redo brings the same room back")
	editor.fill_room_edges(room2, PaletteCatalog.get_entry(&"ground"))

	# Openings: walled rooms have none; erasing both walls makes one.
	_check(map.get_openings().is_empty(), "walled rooms have no openings between them")
	var wall_rows: Array[Vector2i] = []
	var other_wall_rows: Array[Vector2i] = []
	for row: int in range(15, 21):
		wall_rows.append(Vector2i(39, row))
		other_wall_rows.append(Vector2i(0, row))
	editor.paint_cells(room1, wall_rows, false)
	editor.paint_cells(room2, other_wall_rows, false)
	var openings: Array[Array] = map.get_openings()
	_check(openings.size() == 1 and openings[0][0] == Vector2(320, 120) and openings[0][1] == Vector2(320, 168),
		"erasing both walls makes one opening, x 320 from y 120 to 168, got %s" % [openings])

	# Moving: refused onto another room, allowed elsewhere.
	_check(not map.set_room_rect(room3, Rect2(330, 100, 320, 188), false) and room3.position == Vector2(320, 180), "a move onto another room is refused")
	_check(map.set_room_rect(room3, Rect2(320, 400, 320, 188), false) and room3.position == Vector2(320, 400), "a move to free space works")
	editor.undo()
	_check(room3.position == Vector2(320, 180), "undo moves it back")

	# Resizing from the left keeps the contents where they are in the level.
	var goal: Goal = editor.place_object(PaletteCatalog.get_entry(&"goal"), room3, Vector2i(20, 20)) as Goal
	var goal_level_position: Vector2 = goal.global_position
	var tile_count: int = room3_tiles.get_used_cells().size()
	var wider: Rect2 = map.snap_resized(MapView.room_rect(room3), MapView.EDGE_LEFT, Vector2(243, 250), room3, 0.0)
	_check(wider == Rect2(240, 180, 400, 188), "dragging the left edge left: whole tiles, got %s" % wider)
	_check(map.set_room_rect(room3, wider), "the room grows to the left")
	_check(goal.global_position == goal_level_position, "its goal stays where it was in the level")
	_check(room3_tiles.get_used_cells().size() == tile_count and room3_tiles.get_cell_source_id(Vector2i(10, 0)) != -1
		and room3_tiles.get_cell_source_id(Vector2i(0, 0)) == -1, "its tiles too (the old left wall is 10 cells in now)")
	var narrower: Rect2 = map.snap_resized(MapView.room_rect(room3), MapView.EDGE_RIGHT, Vector2(560, 250), room3, 0.0)
	_check(map.set_room_rect(room3, narrower) and room3.room_size.x == 320.0, "the right edge shrinks it to 320")
	var max_x: int = 0
	for cell: Vector2i in room3_tiles.get_used_cells():
		max_x = maxi(max_x, cell.x)
	_check(max_x < 40, "tiles left outside are cut off, rightmost cell %d" % max_x)
	editor.undo()
	_check(room3.room_size.x == 400.0 and room3_tiles.get_cell_source_id(Vector2i(49, 0)) != -1, "undo brings size and tiles back")

	# The start room.
	_check(editor.get_start_room() == room1, "the first room starts")
	map.set_start_room(room2)
	_check(editor.level_info.start_room == room2, "S makes the selected room the start")
	editor.undo()
	_check(editor.level_info.start_room == room1, "undo gives the start back")
	map.set_start_room(room2)

	# Deleting rooms; links from other rooms into a deleted one go too.
	var door: Door = editor.place_object(PaletteCatalog.get_entry(&"door"), room1, Vector2i(20, 10)) as Door
	var plate: PressurePlate = editor.place_object(PaletteCatalog.get_entry(&"pressure_plate"), room3, Vector2i(30, 20)) as PressurePlate
	editor.toggle_link(door, plate)
	_check(not map.delete_room(room2) and room2.is_inside_tree(), "the start room can't be deleted")
	_check(map.delete_room(room3) and editor.get_rooms().size() == 2 and door.switches.is_empty(),
		"deleting a room drops links into it")
	editor.undo()
	_check(editor.get_rooms().size() == 3 and room3.is_inside_tree() and door.switches == [plate], "undo brings room and link back")

	# Double-click: the map closes on that room.
	map.close(room3)
	_check(not map.is_open and editor.current_room == room3, "double-click opens a room for editing")

	# Saved and played: the camera slides from room to room.
	_check(editor.save() == OK, "the level saves")
	_check(editor.start_playtest(), "play from the start room")
	var play_root: RoomManager = editor.play_root
	_check(play_root.rooms.size() == 3 and play_root.current_room.name == room2.name, "three rooms, starting in Room2")
	play_root.player.global_position = room1.global_position + Vector2(160, 160)
	for frame: int in 3:
		await get_tree().physics_frame
	_check(play_root.current_room.name == room1.name and play_root.is_transitioning, "walking into Room1 slides the camera there")
	editor.stop_playtest()
	await get_tree().process_frame

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L7 map")


## Stage L7: importing rooms as copies, from a chapter and from another level.
func _check_l7_import() -> void:
	var sources: Array = RoomImport.list_sources()
	var source_paths: Array = sources.map(func(source: Array) -> String: return source[1])
	_check(source_paths.has("res://scenes/world.tscn") and source_paths.has("res://scenes/earth_world.tscn")
		and source_paths.has("res://tests/fire_test_world.tscn") and source_paths.has("res://tests/test_world.tscn"),
		"the import list has the chapters and test worlds")
	var map_level_path: String = TEST_LEVELS_DIR + "map_level.tscn"
	var paths_without_map_level: Array = RoomImport.list_sources(map_level_path).map(func(source: Array) -> String: return source[1])
	_check(source_paths.has(map_level_path) and not paths_without_map_level.has(map_level_path),
		"and other levels, never the one being edited")
	var earth_rooms: Array = RoomImport.list_rooms("res://scenes/earth_world.tscn")
	_check(earth_rooms.size() == 10 and earth_rooms[2][0] == "Earth03", "Earth world: 10 rooms, the third is Earth03")

	var path: String = LevelStorage.create_level("Import Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var map: MapView = editor.map_view
	editor.toggle_map()
	# The import list (a Tree) opens a world's folder on demand.
	editor.ui.import_picker.open(path)
	var tree_root: TreeItem = editor.ui.import_picker.tree.get_root()
	_check(editor.ui.import_picker.visible and tree_root.get_child_count() == RoomImport.list_sources(path).size(),
		"I shows the import list (this level left out)")
	editor.ui.import_picker.close()

	var original: Room = (load("res://scenes/rooms/earth/earth_03.tscn") as PackedScene).instantiate() as Room
	var original_earth_cells: int = (original.get_node("Earth") as TileMapLayer).get_used_cells().size()
	_check(map.begin_import("res://scenes/earth_world.tscn", "Earth03") and map.importing_room != null, "picking Earth room 3 copies it")
	_check(map.place_import(Vector2(100, 0)) == null and map.importing_room != null, "it can't go onto the existing room")
	var copy: Room = map.place_import(Vector2(320, 0))
	_check(copy != null and copy.is_inside_tree() and copy.position == Vector2(320, 0), "it goes down next to it")
	_check(copy.scene_file_path == "" and copy.owner == editor.level_root and copy.get_node("Earth").owner == editor.level_root,
		"the copy is the level's own, not an instance of earth_03.tscn")
	_check(copy.display_title == original.display_title and copy.room_size == original.room_size
		and copy.earth_allowed == original.earth_allowed and copy.air_allowed == original.air_allowed, "with the original's settings")
	_check(copy.get_node("Earth") is EarthLayer and (copy.get_node("Earth") as TileMapLayer).get_used_cells().size() == original_earth_cells,
		"and all its earth")
	_check(copy.get_node_or_null("GroundPainter") is GroundPainter, "it's drawn as in the Earth chapter")
	_check(editor.save() == OK, "the level saves")
	var saved_text: String = FileAccess.get_file_as_string(path)
	_check(not saved_text.contains("earth_03.tscn") and not saved_text.contains("earth_world.tscn"), "the file doesn't refer to the original")
	var reloaded: Node = (LevelStorage.load_level(path) as PackedScene).instantiate()
	var reloaded_copy: Room = reloaded.get_node(NodePath(copy.name)) as Room
	_check(reloaded_copy.room_size == original.room_size and reloaded_copy.display_title == original.display_title
		and (reloaded_copy.get_node("Earth") as TileMapLayer).get_used_cells().size() == original_earth_cells, "everything survives a reload")
	reloaded.free()
	original.free()

	# From another level: a door linked to a plate in another room loses that link.
	var source_room: Room = editor.get_rooms()[0]
	var door: Door = editor.place_object(PaletteCatalog.get_entry(&"door"), source_room, Vector2i(20, 10)) as Door
	var plate: PressurePlate = editor.place_object(PaletteCatalog.get_entry(&"pressure_plate"), copy, Vector2i(10, 20)) as PressurePlate
	editor.toggle_link(door, plate)
	editor.save()
	_check(map.begin_import(path, String(source_room.name)), "a room of an editor level can be imported")
	var level_copy: Room = map.place_import(Vector2(0, 180))
	var copied_door: Door = null
	for child: Node in level_copy.get_children():
		if child is Door:
			copied_door = child
	_check(copied_door != null and copied_door.switches.is_empty(), "its door's link to a plate in another room is dropped")
	map.begin_import("res://scenes/world.tscn", "Room01")
	map.close()
	_check(map.importing_room == null, "closing the map drops a room still waiting to be placed")

	# Play through the imported Earth room.
	_check(editor.start_playtest(), "play")
	var play_root: RoomManager = editor.play_root
	var played_copy: Room = play_root.get_node(NodePath(copy.name)) as Room
	play_root.player.global_position = played_copy.get_spawn_position() - Vector2(0, 4)
	for frame: int in 3:
		await get_tree().physics_frame
	_check(play_root.current_room == played_copy and play_root.player.is_element_allowed(&"earth") == copy.earth_allowed,
		"walking into the imported room works, Earth as in the original")
	editor.stop_playtest()
	await get_tree().process_frame

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L7 import")


## Stage L8: the Earth brush (EarthLayer + GroundPainter), walls in tiles, rock spots.
func _check_l8_earth() -> void:
	var path: String = LevelStorage.create_level("Earth Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var room: Room = editor.get_rooms()[0]
	_check(PaletteCatalog.get_families().has("Earth"), "the palette has an Earth tab")
	var earth_entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(&"earth")
	_check(earth_entry != null and earth_entry.kind == PaletteCatalog.Kind.TERRAIN and earth_entry.family == "Terrain", "Earth is a Terrain brush")
	for id: StringName in [&"cracked_wall", &"stone_wall", &"boulder", &"loose_rock"]:
		_check(PaletteCatalog.get_entry(id) != null and PaletteCatalog.get_entry(id).family == "Earth", "%s is in the Earth tab" % id)

	# Painting earth: an EarthLayer, Earth turned on, drawn by a GroundPainter.
	room.earth_allowed = false
	editor.choose_entry(earth_entry)
	var cells: Array[Vector2i] = []
	for x: int in range(10, 21):
		cells.append(Vector2i(x, 15))
	editor.paint_cells(room, cells, true)
	var earth: EarthLayer = room.get_node_or_null("Earth") as EarthLayer
	_check(earth != null and earth.get_used_cells().size() == 11 and earth.owner == editor.level_root, "the brush paints an EarthLayer that's saved")
	_check(room.earth_allowed, "painting Earth turns Earth on in the room")
	var painter: GroundPainter = room.get_node_or_null("GroundPainter") as GroundPainter
	_check(painter != null and painter.get_pixel_color(Vector2i(15 * 8 + 4, 15 * 8 + 4)).a > 0.0, "a GroundPainter draws it, as in play")
	_check(earth.self_modulate.a == 0.0 and (room.get_node("Tiles") as TileMapLayer).self_modulate.a == 0.0,
		"the tiles themselves are hidden behind the picture")
	editor.undo()
	painter = room.get_node_or_null("GroundPainter") as GroundPainter
	_check(earth.get_used_cells().is_empty() and not room.earth_allowed, "undo takes the earth away and Earth back off")
	_check(painter != null and painter.get_pixel_color(Vector2i(15 * 8 + 4, 15 * 8 + 4)).a == 0.0, "and the picture follows")
	editor.redo()
	_check(earth.get_used_cells().size() == 11 and room.earth_allowed, "redo puts it back")
	editor.choose_entry(PaletteCatalog.get_entry(&"ground"))
	editor.paint_cells(room, [Vector2i(30, 10)], true)
	painter = room.get_node_or_null("GroundPainter") as GroundPainter
	_check(painter.get_pixel_color(Vector2i(30 * 8 + 4, 10 * 8 + 4)).a > 0.0, "ground painted in an earth room shows in the picture")

	# Walls: placed by the top-left corner, sized in tiles.
	var wall: CrackedWall = editor.place_object(PaletteCatalog.get_entry(&"cracked_wall"), room, Vector2i(5, 10)) as CrackedWall
	_check(wall.position == Vector2(40, 80) and PaletteCatalog.get_bounds(wall).size == Vector2(wall.wall_size_tiles) * 8.0,
		"a cracked wall sits on the tile, outline from its size in tiles")
	var handle: Dictionary = EditorHandles.get_handles(wall)[0]
	var dragged_size: Variant = EditorHandles.value_for_drag(wall, handle, wall.global_position + Vector2(21, 30), false)
	_check(dragged_size is Vector2i and dragged_size == Vector2i(3, 4), "its size handle works in whole tiles, got %s" % [dragged_size])
	editor.set_property(wall, &"wall_size_tiles", dragged_size)
	_check(PaletteCatalog.get_bounds(wall).size == Vector2(24, 32), "the outline follows")
	var stone: StoneWall = editor.place_object(PaletteCatalog.get_entry(&"stone_wall"), room, Vector2i(30, 15)) as StoneWall
	_check(stone != null and PaletteCatalog.get_bounds(stone).size == Vector2(stone.wall_size_tiles) * 8.0, "a stone wall too")

	# Rock spots: nothing runs in the editor; in play a loose rock lies there.
	var boulder_spot: RockSpot = editor.place_object(PaletteCatalog.get_entry(&"boulder"), room, Vector2i(20, 20)) as RockSpot
	var rock_spot: RockSpot = editor.place_object(PaletteCatalog.get_entry(&"loose_rock"), room, Vector2i(25, 20)) as RockSpot
	_check(boulder_spot.is_big and boulder_spot.position == Vector2(168, 160) and not rock_spot.is_big and rock_spot.position == Vector2(204, 164),
		"a boulder and a loose rock stand on the clicked tiles, got %s, %s" % [boulder_spot.position, rock_spot.position])
	_check(_boulders_in(room).is_empty(), "the editor makes no real rocks")

	_check(editor.start_playtest(), "play")
	var play_room: Room = editor.play_root.get_node("Room1") as Room
	await get_tree().create_timer(0.3).timeout
	var rocks: Array[Boulder] = _boulders_in(play_room)
	_check(rocks.size() == 2 and rocks.all(func(rock: Boulder) -> bool: return rock.is_loose()), "in play, two loose rocks lie there")
	_check(rocks.filter(func(rock: Boulder) -> bool: return rock.is_big()).size() == 1, "one of them big")
	_check(play_room.get_node("Earth") is EarthLayer and (play_room.get_node("Earth") as TileMapLayer).get_used_cells().size() == 11,
		"the painted earth is there in play")
	rocks[0].shatter()
	play_room.reset_objects()
	await get_tree().create_timer(0.1).timeout
	_check(_boulders_in(play_room).size() == 2, "after a reset both rocks are back")
	editor.stop_playtest()
	await get_tree().process_frame

	_check(editor.save() == OK, "the level saves")
	var reloaded: Node = (LevelStorage.load_level(path) as PackedScene).instantiate()
	var reloaded_earth: TileMapLayer = reloaded.get_node("Room1/Earth") as TileMapLayer
	_check(reloaded_earth is EarthLayer and reloaded_earth.get_used_cells().size() == 11, "the Earth layer and its script survive a reload")
	reloaded.free()

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L8 Earth")


## After the L7/L8 play-test: the import list opening a world, the eraser's block,
## painted ground, hints, and Earth bending in a play-test (the editor's own copy
## of the level leaves the tree, so group lookups find the play copy's earth).
func _check_l8b_followups() -> void:
	var path: String = LevelStorage.create_level("Followup Level")
	LevelEditor.path_to_open = path
	var editor: LevelEditor = LEVEL_EDITOR_SCENE.instantiate() as LevelEditor
	add_child(editor)
	await get_tree().process_frame
	var room: Room = editor.get_rooms()[0]

	# The import list: opening a world's folder fills it a moment later.
	var picker: RoomImportPicker = editor.ui.import_picker
	picker.open(path)
	var earth_world_item: TreeItem = picker.tree.get_root().get_child(1)
	earth_world_item.collapsed = false
	await get_tree().process_frame
	_check(earth_world_item.get_child_count() == 10, "opening the Earth folder lists its 10 rooms, got %d" % earth_world_item.get_child_count())
	picker.close()

	# Hints: every palette entry has one, shown as its button's tooltip.
	var without_hint: Array[StringName] = []
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.hint == "" or (editor.ui.palette_buttons[entry.id] as Button).tooltip_text == "":
			without_hint.append(entry.id)
	_check(without_hint.is_empty(), "every palette entry has a hint and a tooltip, missing: %s" % [without_hint])
	_check(not EditorUI.wrap_text(PaletteCatalog.get_entry(&"crate").hint, 48).split("\n").has(""), "tooltips are wrapped into lines")
	var crate: Crate = editor.place_object(PaletteCatalog.get_entry(&"crate"), room, Vector2i(12, 20)) as Crate
	_check(editor.ui.property_panel.description_label.text == PaletteCatalog.get_entry(&"crate").hint, "the property panel shows the selected object's hint")

	# The eraser's Shift+drag block: tiles on every layer, objects fully inside.
	editor.choose_entry(PaletteCatalog.get_entry(&"earth"))
	editor.paint_cells(room, [Vector2i(14, 18), Vector2i(15, 18)], true)
	editor.choose_entry(PaletteCatalog.get_entry(&"ground"))
	editor.paint_cells(room, [Vector2i(10, 18), Vector2i(11, 18)], true)
	var goal: Goal = editor.place_object(PaletteCatalog.get_entry(&"goal"), room, Vector2i(18, 20)) as Goal
	var tiles: TileMapLayer = room.get_node("Tiles") as TileMapLayer
	var earth: TileMapLayer = room.get_node("Earth") as TileMapLayer
	editor.erase_block(room, Vector2i(9, 17), Vector2i(17, 20))
	_check(tiles.get_cell_source_id(Vector2i(10, 18)) == -1 and earth.get_cell_source_id(Vector2i(15, 18)) == -1,
		"the block clears ground and earth")
	_check(not crate.is_inside_tree() and goal.is_inside_tree(), "and the crate inside it, not the goal sticking out")
	_check(tiles.get_cell_source_id(Vector2i(10, 21)) != -1, "the floor below it is untouched")
	editor.undo()
	_check(tiles.get_cell_source_id(Vector2i(10, 18)) != -1 and earth.get_cell_source_id(Vector2i(15, 18)) != -1 and crate.is_inside_tree(),
		"one undo brings all of it back")

	# Painted ground: on for editor rooms, can be switched off (and back).
	_check(room.painted_ground and room.get_node_or_null("GroundPainter") is GroundPainter, "a new level's room has painted ground")
	editor.set_property(room, &"painted_ground", false)
	await get_tree().process_frame
	editor.set_property(room, &"painted_ground", true)
	editor.undo()
	await get_tree().process_frame
	_check(room.get_node_or_null("GroundPainter") is GroundPainter, "with Earth painted the room keeps its painter either way")

	# Earth bending in a play-test: lookups find the play copy's earth.
	_check(editor.start_playtest(), "play")
	await get_tree().process_frame  # it leaves at the end of the frame (deferred)
	_check(not editor.level_root.is_inside_tree(), "the editor's own copy leaves the tree while playing")
	var play_room: Room = editor.play_root.get_node("Room1") as Room
	var earth_point: Vector2 = play_room.global_position + Vector2(15 * 8 + 4, 18 * 8 + 4)
	_check(EarthLayer.find_layer_at(get_tree(), earth_point) == play_room.get_node("Earth"), "the earth found at a point is the play copy's")
	editor.stop_playtest()
	_check(editor.level_root.is_inside_tree() and editor.level_root.get_index() == editor.backdrop.get_index() + 1,
		"and comes back, behind the overlay")

	editor.queue_free()
	await get_tree().process_frame
	finished_sections.append("L8b follow-ups")


## The live (not shattered, not freed) boulders directly in `room`.
func _boulders_in(room: Room) -> Array[Boulder]:
	var rocks: Array[Boulder] = []
	for child: Node in room.get_children():
		var rock: Boulder = child as Boulder
		if rock != null and not rock.is_queued_for_deletion() and rock.phase != Boulder.Phase.SHATTERED:
			rocks.append(rock)
	return rocks


func _button_texts(page: Node) -> Array[String]:
	var texts: Array[String] = []
	for child: Node in page.get_children():
		if child is Button:
			texts.append((child as Button).text)
	return texts


func _delete_test_folder() -> void:
	var dir: DirAccess = DirAccess.open(TEST_LEVELS_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(TEST_LEVELS_DIR)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS  %s" % description)
	else:
		failures += 1
		print("  FAIL  %s" % description)

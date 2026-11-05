class_name MainMenu
extends Control
## Main menu: the first screen when the game starts (it's the main scene in
## project.godot). Arrows + Enter (or C) to pick, Esc to go back a page.
##
## It has two pages, one shown at a time (Level_editor.md §10):
##   - Main:     Story Mode · Level Editor · Chapters & test rooms
##   - Chapters: every chapter and test world (CHAPTERS below) + Back
##       - Air:   scenes/world.tscn             rooms 1-7 (Milestone 1)
##       - Earth: scenes/earth_world.tscn       the Earth chapter, rooms 1-10 (Stage E7)
##       - Earth tests: tests/earth_test_world.tscn   one test room per Earth stage
##       - Mixed: tests/mixed_test_world.tscn   Air and Earth together: movement room, enemy room
##       - Fire tests: tests/fire_test_world.tscn     one test room per Fire stage (F1+)
##       - Water tests: tests/water_test_world.tscn   one test room per Water stage (W1+)
## Story Mode opens the Story screen (scenes/ui/story_screen.tscn, Stage L11).
## Level Editor opens the level library (scenes/ui/level_library.tscn). Run from the
## Godot project it saves into the project (res://levels/); in an exported or web
## build res:// is read-only, so it saves into user://levels/ instead
## (LevelStorage.get_editor_levels_dir), first copying in the project's levels it
## doesn't have yet (LevelStorage.copy_shipped_levels).
##
## The whole menu is built in _ready() from code: a title Label, then one
## VBoxContainer (a container that stacks its children vertically) per page.
## Showing a page = making its container visible and hiding the others.
## Buttons are keyboard-driven through FOCUS: the focused button reacts to
## ui_up / ui_down / ui_accept, Godot's built-in menu actions (arrows / Enter).
##
## Starting a chapter: get_tree().change_scene_to_file() unloads this scene and
## loads the chosen world in its place. GameState (an autoload) survives scene
## changes, so it's reset first: the run's timer and deaths start at zero.

## [button text, scene path] per chapter, in menu order. New chapters and test
## worlds (Fire chapter, mixed Fire rooms...) are appended here.
const CHAPTERS: Array = [
	["Air  -  Windbound (rooms 1-7)", "res://scenes/world.tscn"],
	["Earth  -  the Earth chapter (rooms 1-10)", "res://scenes/earth_world.tscn"],
	["Earth  -  test rooms (F2 to switch)", "res://tests/earth_test_world.tscn"],
	["Air + Earth  -  mixed test rooms (F2 to switch)", "res://tests/mixed_test_world.tscn"],
	["Fire  -  test rooms (F2 to switch)", "res://tests/fire_test_world.tscn"],
	["Water  -  test rooms (F2 to switch)", "res://tests/water_test_world.tscn"],
]
const LEVEL_LIBRARY_SCENE: String = "res://scenes/ui/level_library.tscn"
const STORY_SCREEN_SCENE: String = "res://scenes/ui/story_screen.tscn"
const BACKGROUND_COLOR: Color = Color(0.1, 0.1, 0.13)
## Small font: the game renders at 320x180, so default 16 px text would be huge.
const FONT_SIZE: int = 8
const TITLE_FONT_SIZE: int = 16
const HINT_ALPHA: float = 0.6

## The two pages. Only one is visible at a time.
var main_page: VBoxContainer
var chapters_page: VBoxContainer
## The button that opens the sub-page: focus goes back to it on Esc / Back.
var chapters_button: Button
## The button that opened the current sub-page (null on the main page).
var opened_from: Button = null


func _ready() -> void:
	# Back from a world (pause menu -> Main menu): a story run, if any, is over.
	StoryPlayer.stop()
	# Back from the level editor in an exported build: Story Mode reads its order
	# and levels from res://levels/ again, not the editor's user://levels/.
	# Skipped in the Godot project, where both are res://levels/ (and the smoke
	# test may have pointed levels_dir at its throwaway folder).
	if not OS.has_feature("editor"):
		LevelStorage.levels_dir = LevelStorage.DEFAULT_LEVELS_DIR
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# CenterContainer keeps its child centered on screen whatever its size.
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)

	var title: Label = Label.new()
	title.text = "WINDBOUND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)

	main_page = _build_main_page()
	column.add_child(main_page)
	chapters_page = _build_chapters_page()
	column.add_child(chapters_page)
	_show_page(main_page, null)


func _build_main_page() -> VBoxContainer:
	var page: VBoxContainer = _make_page()
	page.add_child(_make_button("Story Mode", func() -> void: get_tree().change_scene_to_file(STORY_SCREEN_SCENE)))

	page.add_child(_make_button("Level Editor", _open_level_library))

	chapters_button = _make_button("Chapters & test rooms", func() -> void: _show_page(chapters_page, chapters_button))
	page.add_child(chapters_button)
	page.add_child(_make_hint("Arrows to choose, Enter or C to start"))
	return page


func _build_chapters_page() -> VBoxContainer:
	var page: VBoxContainer = _make_page()
	for chapter: Array in CHAPTERS:
		# bind() fixes the argument now, so each button opens its own scene.
		page.add_child(_make_button(chapter[0], _start_chapter.bind(String(chapter[1]))))
	page.add_child(_make_button("Back", _go_back))
	page.add_child(_make_hint("Enter or C to start, Esc to go back"))
	return page


## Shows `page`, hides the others, and focuses its first button.
## `from_button` is the button that opened it, to return focus there on Back.
func _show_page(page: VBoxContainer, from_button: Button) -> void:
	opened_from = from_button
	for each_page: VBoxContainer in [main_page, chapters_page]:
		each_page.visible = each_page == page
	for child: Node in page.get_children():
		var button: Button = child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return


## Back to the main page, with focus on the button that opened the sub-page.
func _go_back() -> void:
	var return_focus: Button = opened_from
	_show_page(main_page, null)
	if return_focus != null:
		return_focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# C (jump) also presses the focused button, so one hand never leaves the game keys.
	if event.is_action_pressed("jump"):
		var focused: Button = get_viewport().gui_get_focus_owner() as Button
		if focused != null and not focused.disabled:
			focused.pressed.emit()
	# ui_cancel is Godot's built-in "back" action (Esc).
	elif event.is_action_pressed("ui_cancel") and not main_page.visible:
		_go_back()
		get_viewport().set_input_as_handled()


func _start_chapter(scene_path: String) -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file(scene_path)


func _open_level_library() -> void:
	LevelStorage.levels_dir = LevelStorage.get_editor_levels_dir()
	if not OS.has_feature("editor"):
		LevelStorage.copy_shipped_levels()
	get_tree().change_scene_to_file(LEVEL_LIBRARY_SCENE)


func _make_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	return page


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(on_pressed)
	return button


func _make_hint(text: String) -> Label:
	var hint: Label = Label.new()
	hint.text = text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", FONT_SIZE)
	hint.modulate = Color(1.0, 1.0, 1.0, HINT_ALPHA)
	return hint

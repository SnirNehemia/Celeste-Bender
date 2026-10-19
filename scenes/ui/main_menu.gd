class_name MainMenu
extends Control
## Main menu: the first screen when the game starts (it's the main scene in
## project.godot). Pick a chapter with the arrows + Enter (or C).
##   - Air:   scenes/world.tscn             rooms 1-7 (Milestone 1)
##   - Earth: tests/earth_test_world.tscn   Earth test rooms (until Stage E7 builds the chapter)
##   - Mixed: tests/mixed_test_world.tscn   Air and Earth together: movement room, enemy room
##
## The whole menu is built in _ready() from code: a title Label and one Button per
## chapter in a VBoxContainer (a container that stacks its children vertically).
## Buttons are keyboard-driven through FOCUS: the focused button reacts to
## ui_up / ui_down / ui_accept, Godot's built-in menu actions (arrows / Enter).
##
## Starting a chapter: get_tree().change_scene_to_file() unloads this scene and
## loads the chosen world in its place. GameState (an autoload) survives scene
## changes, so it's reset first: the run's timer and deaths start at zero.

## [button text, scene path] per chapter, in menu order.
const CHAPTERS: Array = [
	["Air  -  Windbound (rooms 1-7)", "res://scenes/world.tscn"],
	["Earth  -  test rooms (F2 to switch)", "res://tests/earth_test_world.tscn"],
	["Air + Earth  -  mixed test rooms (F2 to switch)", "res://tests/mixed_test_world.tscn"],
]
const BACKGROUND_COLOR: Color = Color(0.1, 0.1, 0.13)
## Small font: the game renders at 320x180, so default 16 px text would be huge.
const FONT_SIZE: int = 8
const TITLE_FONT_SIZE: int = 16


func _ready() -> void:
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

	var first_button: Button = null
	for chapter: Array in CHAPTERS:
		var button: Button = Button.new()
		button.text = chapter[0]
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		# bind() fixes the argument now, so each button opens its own scene.
		button.pressed.connect(_start_chapter.bind(String(chapter[1])))
		column.add_child(button)
		if first_button == null:
			first_button = button

	var hint: Label = Label.new()
	hint.text = "Arrows to choose, Enter or C to start"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", FONT_SIZE)
	hint.modulate = Color(1.0, 1.0, 1.0, 0.6)
	column.add_child(hint)

	first_button.grab_focus()


## C (jump) also starts the focused chapter, so one hand never leaves the game keys.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		var focused: Button = get_viewport().gui_get_focus_owner() as Button
		if focused != null:
			focused.pressed.emit()


func _start_chapter(scene_path: String) -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file(scene_path)

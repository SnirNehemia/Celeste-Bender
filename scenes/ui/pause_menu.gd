class_name PauseMenu
extends CanvasLayer
## Pause menu (GAME_DESIGN.md §9 / PROMPTS.md Stage 10): Esc (`pause`) stops the
## game and shows Resume / Restart room / Main menu / Quit. Esc again resumes.
##
## Keyboard only: arrows move between buttons, Enter or Jump (C) presses one.
##
## Connections:
##   - Pausing goes through FX.set_menu_pause(), which also knows about freeze
##     frames, so a freeze ending can't unpause the menu (see autoload/fx.gd).
##   - "Restart room" calls RoomManager.restart_room(), the same path as R.
##   - "Rooms" (only in worlds with an F2 room picker) closes this menu and opens
##     the picker, found through RoomPicker.GROUP. Phones have no F2.
##   - It refuses to open while another menu has the game paused (the F2 room
##     picker) or after the Goal (the end screen is up).
##
## Godot concepts used:
##   - process_mode = ALWAYS: this node keeps running while the tree is paused,
##     so it can still read Esc and its buttons still work.
##   - Focus: the focused Button reacts to ui_up/ui_down (arrows) and ui_accept
##     (Enter/Space); grab_focus() picks which one starts highlighted.
## The UI is built in code in _ready(), like the end screen and room picker.

## The world's RoomManager, for "Restart room". Set in the Inspector.
@export var room_manager: RoomManager

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const TITLE_COLOR: Color = Color(1.0, 1.0, 1.0)
const HINT_COLOR: Color = Color(0.7, 0.7, 0.75)

## Set by the level editor before a play-test starts (Level_editor.md §8): the
## menu then shows "Back to editor" instead of "Main menu", which would throw the
## editor's unsaved work away. Empty (not valid) in normal play.
var back_to_editor: Callable = Callable()

var resume_button: Button
## "Rooms": opens the world's F2 room picker. Shown only when the world has one.
var rooms_button: Button
## The whole menu (dim + buttons), shown/hidden as one.
var menu_root: Control


func _ready() -> void:
	layer = 18  # above the end screen (15), below the F2 room picker (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	menu_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if menu_root.visible:
			_set_open(false)
			get_viewport().set_input_as_handled()
		elif not FX.is_menu_open and not GameState.is_run_finished:
			_set_open(true)
			get_viewport().set_input_as_handled()
	elif menu_root.visible and event.is_action_pressed("jump"):
		# Jump (C) presses the highlighted button, like Enter. Players already have
		# a finger on C; the end screen uses it the same way.
		# Fetch the viewport BEFORE pressing: "Main menu" changes the scene, which
		# takes this node out of the tree at once, and get_viewport() would be null.
		var viewport: Viewport = get_viewport()
		var focused: Control = viewport.gui_get_focus_owner()
		if focused is Button:
			(focused as Button).pressed.emit()
		viewport.set_input_as_handled()


func _set_open(open: bool) -> void:
	menu_root.visible = open
	FX.set_menu_pause(open)
	FX.play_sfx(&"pause" if open else &"unpause")
	if open:
		# Checked on every open, not in _ready: the picker may join the scene after us.
		rooms_button.visible = _get_room_picker() != null
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	_set_open(false)


## Closes this menu, then opens the room picker (one menu at a time).
func _on_rooms_pressed() -> void:
	var picker: RoomPicker = _get_room_picker()
	_set_open(false)
	if picker != null:
		picker.open()


func _get_room_picker() -> RoomPicker:
	return get_tree().get_first_node_in_group(RoomPicker.GROUP) as RoomPicker


func _on_restart_pressed() -> void:
	# Unpause first: the death and respawn run on (pausable) game time.
	_set_open(false)
	room_manager.restart_room()


## Back to the chapter picker (scenes/ui/main_menu.tscn). The pause and any slow
## motion are global (tree pause, Engine.time_scale), so they must be switched off
## before leaving, or the menu would open frozen.
func _on_main_menu_pressed() -> void:
	_set_open(false)
	FX.clear_slow_motion()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Play-test only: hands control back to the level editor (it frees this level).
func _on_back_to_editor_pressed() -> void:
	_set_open(false)
	FX.clear_slow_motion()
	back_to_editor.call()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _build_ui() -> void:
	# One full-screen Control holds everything, so hiding it hides the whole menu.
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu_root)

	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	center.add_child(column)

	column.add_child(_make_label("Paused", 16, TITLE_COLOR))
	resume_button = _make_button("Resume", _on_resume_pressed)
	column.add_child(resume_button)
	column.add_child(_make_button("Restart room", _on_restart_pressed))
	rooms_button = _make_button("Rooms", _on_rooms_pressed)
	column.add_child(rooms_button)
	if back_to_editor.is_valid():
		column.add_child(_make_button("Back to editor", _on_back_to_editor_pressed))
	else:
		column.add_child(_make_button("Main menu", _on_main_menu_pressed))
	# A web page can't be "quit", so the button would do nothing there.
	if not OS.has_feature("web"):
		column.add_child(_make_button("Quit game", _on_quit_pressed))
	column.add_child(_make_label("Arrows + Enter/C  ·  Esc to resume", 8, HINT_COLOR))


## A Button whose `pressed` signal calls `on_pressed`. Callable = a reference to a
## function, which is how you pass a method around in GDScript.
func _make_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 8)
	button.pressed.connect(on_pressed)
	return button


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	return label

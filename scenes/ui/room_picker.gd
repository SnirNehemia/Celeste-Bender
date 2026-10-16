class_name RoomPicker
extends CanvasLayer
## Debug "jump to room" menu for fast playtesting. Press F2 (`debug_room_picker`)
## to open it: the game pauses and a list of buttons appears, one per room.
## Click one, or pick with the arrow keys + Enter. F2 or Esc closes it.
##
## It only asks RoomManager.jump_to_room() to do the teleport; it has no game logic
## of its own, so it can be deleted from a world scene without breaking anything.
##
## Godot concepts used:
##   - Pausing: get_tree().paused = true stops every node whose process_mode is
##     PAUSABLE (the default), i.e. the whole game. This node is set to ALWAYS so its
##     buttons still work while everything else is frozen.
##   - Control nodes (Button, VBoxContainer, PanelContainer) are Godot's UI nodes.
##     Containers lay out their children automatically.
##   - Focus: the focused Button reacts to ui_up/ui_down/ui_accept (arrows/Enter),
##     which is how keyboard-only menus work in Godot.
##   - ScrollContainer: shows a fixed-size window onto a taller child. With
##     follow_focus on, it scrolls by itself to keep the focused button visible, so
##     the arrow keys "scroll" the list. Only VISIBLE_ROWS rooms show at once.

## The world's RoomManager. Set in the Inspector.
@export var room_manager: RoomManager

## How many room buttons are visible at once, and the height of one row in px.
const VISIBLE_ROWS: int = 5
const ROW_HEIGHT: float = 12.0

var panel: PanelContainer
var header: Label
var scroll: ScrollContainer
var button_list: VBoxContainer
## "^ more" / "v more" hints shown when rooms are hidden above/below.
var more_above_label: Label
var more_below_label: Label


func _ready() -> void:
	layer = 20  # above the debug overlay
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_room_picker"):
		_set_open(not panel.visible)
		get_viewport().set_input_as_handled()
	elif panel.visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	panel.visible = open
	get_tree().paused = open
	if open:
		_rebuild_buttons()


## One button per room, in scene order. Rebuilt on every open (cheap) so the list
## always matches the rooms in the scene.
func _rebuild_buttons() -> void:
	for child: Node in button_list.get_children():
		child.queue_free()
	for room_index: int in room_manager.rooms.size():
		var room: Room = room_manager.rooms[room_index]
		var button: Button = Button.new()
		var title: String = room.display_title if room.display_title != "" else String(room.name)
		button.text = "%d  %s" % [room_index + 1, title]
		if room == room_manager.current_room:
			button.text += "  <"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = ROW_HEIGHT
		# Keep the header counter and more-hints in sync with the highlighted room.
		button.focus_entered.connect(_on_button_focused.bind(room_index))
		button.add_theme_font_size_override("font_size", 8)
		# bind() attaches extra arguments to the callback: pressing this button calls
		# _on_room_button_pressed(room).
		button.pressed.connect(_on_room_button_pressed.bind(room))
		button_list.add_child(button)
		if room == room_manager.current_room:
			button.grab_focus.call_deferred()


## Updates "room N/total" and the more-hints. Deferred by one frame (call_deferred)
## so the ScrollContainer has finished scrolling to the focused button first.
func _on_button_focused(room_index: int) -> void:
	header.text = "Jump to room  %d/%d  (F2/Esc close)" % [room_index + 1, room_manager.rooms.size()]
	_update_more_hints.call_deferred()


func _update_more_hints() -> void:
	var scroll_bar: VScrollBar = scroll.get_v_scroll_bar()
	more_above_label.modulate.a = 1.0 if scroll.scroll_vertical > 0 else 0.0
	more_below_label.modulate.a = 1.0 		if scroll.scroll_vertical + scroll.size.y < scroll_bar.max_value - 1.0 else 0.0


func _on_room_button_pressed(room: Room) -> void:
	_set_open(false)
	room_manager.jump_to_room(room)


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(4, 4)
	add_child(panel)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	panel.add_child(layout)
	header = _make_small_label("Jump to room  (F2/Esc close)")
	layout.add_child(header)
	# Hints are hidden with alpha (not `visible`) so the panel doesn't jump in size.
	more_above_label = _make_small_label("  ^ more")
	layout.add_child(more_above_label)

	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, VISIBLE_ROWS * ROW_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# SHOW_NEVER hides the bar but still scrolls (focus, mouse wheel).
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	layout.add_child(scroll)
	button_list = VBoxContainer.new()
	button_list.add_theme_constant_override("separation", 0)
	# Fill the scroll area's width so buttons don't shrink to their text.
	button_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(button_list)

	more_below_label = _make_small_label("  v more")
	layout.add_child(more_below_label)


func _make_small_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	return label

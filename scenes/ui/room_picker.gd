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

## The world's RoomManager. Set in the Inspector.
@export var room_manager: RoomManager

var panel: PanelContainer
var button_list: VBoxContainer


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
		button.add_theme_font_size_override("font_size", 8)
		# bind() attaches extra arguments to the callback: pressing this button calls
		# _on_room_button_pressed(room).
		button.pressed.connect(_on_room_button_pressed.bind(room))
		button_list.add_child(button)
		if room == room_manager.current_room:
			button.grab_focus.call_deferred()


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
	var header: Label = Label.new()
	header.text = "Jump to room (F2 / Esc to close)"
	header.add_theme_font_size_override("font_size", 8)
	layout.add_child(header)
	button_list = VBoxContainer.new()
	button_list.add_theme_constant_override("separation", 0)
	layout.add_child(button_list)

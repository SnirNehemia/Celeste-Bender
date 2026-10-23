class_name RoomImportPicker
extends ColorRect
## RoomImportPicker: the "Import room as a copy" list (Level_editor.md §5, Stage L7).
## A dimmed screen with a panel: every world (RoomImport.list_sources) as a folder,
## its rooms inside. Double-click a room (or select it and press Import) to pick it;
## Esc or Cancel closes. LevelEditor then lets you click where the copy goes.
##
## A Tree is Godot's folder-style list: TreeItems with children that fold open.
## Opening a world builds its nodes once to read its room titles (RoomImport.list_rooms),
## so the list only does that for worlds you actually open.
##
## Like PromptPanel, it covers the whole screen with mouse_filter STOP, so clicks
## never reach the level underneath while it's open.

## A room was picked: `world_path` is its world's scene, `room_name` its node name.
signal room_chosen(world_path: String, room_name: String)

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const PANEL_COLOR: Color = Color(0.16, 0.16, 0.2)
const LIST_SIZE: Vector2 = Vector2(260, 220)
## The Tree has one column. Its metadata holds a world folder's scene path, or a
## room's node name.
const COLUMN: int = 0
## A world's folder holds this one placeholder child until it's opened, so the
## Tree shows the fold arrow before the rooms are read.
const PLACEHOLDER_TEXT: String = "..."

var tree: Tree
var import_button: Button


func _ready() -> void:
	color = DIM_COLOR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var title: Label = Label.new()
	title.text = "Import a room as a copy: pick it, then click where it goes"
	column.add_child(title)
	tree = Tree.new()
	tree.custom_minimum_size = LIST_SIZE
	tree.hide_root = true
	# item_collapsed fires for opening too (collapsed = false): read the rooms then.
	tree.item_collapsed.connect(_on_item_folded)
	# item_activated: double-click or Enter on an item.
	tree.item_activated.connect(_pick_selected)
	tree.item_selected.connect(_update_import_button)
	column.add_child(tree)
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 4)
	column.add_child(button_row)
	import_button = Button.new()
	import_button.text = "Import"
	import_button.pressed.connect(_pick_selected)
	button_row.add_child(import_button)
	var cancel_button: Button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(close)
	button_row.add_child(cancel_button)


## Shows the list of worlds (folded), leaving out the level at `except_path`.
func open(except_path: String) -> void:
	tree.clear()
	var root: TreeItem = tree.create_item()
	for source: Array in RoomImport.list_sources(except_path):
		var world_item: TreeItem = tree.create_item(root)
		world_item.set_text(COLUMN, source[0])
		world_item.set_metadata(COLUMN, source[1])
		world_item.set_selectable(COLUMN, false)
		tree.create_item(world_item).set_text(COLUMN, PLACEHOLDER_TEXT)
		world_item.collapsed = true
	_update_import_button()
	visible = true
	tree.grab_focus()


func close() -> void:
	visible = false


## Esc closes. _input runs before the Tree, which would use Esc itself.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## A world folder was opened. Its rooms are read a moment later (call_deferred):
## the Tree refuses to make items while it's still handling the click that opened it.
func _on_item_folded(item: TreeItem) -> void:
	if not item.collapsed:
		_fill_world.call_deferred(item)


## Replaces a world folder's placeholder with its rooms (only the first time).
func _fill_world(item: TreeItem) -> void:
	# is_instance_valid: the list may have been rebuilt (and the item freed) meanwhile.
	if not is_instance_valid(item) or item.get_child_count() != 1 or item.get_first_child().get_text(COLUMN) != PLACEHOLDER_TEXT:
		return
	item.get_first_child().free()
	var world_path: String = item.get_metadata(COLUMN)
	var rooms: Array = RoomImport.list_rooms(world_path)
	if rooms.is_empty():
		var empty_item: TreeItem = tree.create_item(item)
		empty_item.set_text(COLUMN, "(no rooms)")
		empty_item.set_selectable(COLUMN, false)
	for room: Array in rooms:
		var room_item: TreeItem = tree.create_item(item)
		room_item.set_text(COLUMN, room[1])
		room_item.set_metadata(COLUMN, room[0])  # a room item keeps its node name


func _update_import_button() -> void:
	import_button.disabled = _selected_room() == null


## The selected room's TreeItem, or null if no room is selected.
func _selected_room() -> TreeItem:
	var selected: TreeItem = tree.get_selected()
	if selected == null or selected.get_parent() == null or selected.get_parent() == tree.get_root():
		return null
	return selected


func _pick_selected() -> void:
	var room_item: TreeItem = _selected_room()
	if room_item == null:
		return
	var world_path: String = room_item.get_parent().get_metadata(COLUMN)
	var room_name: String = room_item.get_metadata(COLUMN)
	close()
	room_chosen.emit(world_path, room_name)

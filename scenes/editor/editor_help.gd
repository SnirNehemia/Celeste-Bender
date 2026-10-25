class_name EditorHelp
extends ColorRect
## EditorHelp: the level editor's quick reference: every key and what it does,
## opened with H or the "?" button in the top bar, closed with H, Esc or Close.
##
## The key names are read from the InputMap (project.godot) when it opens, not
## typed here: if a key is ever rebound, this list shows the new one.
## Rows whose "key" isn't an action name (like "Drag a handle") show as written.
##
## Like PromptPanel, it's a full-screen dim ColorRect: mouse_filter STOP keeps
## clicks from reaching the level while it's open.

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.7)
const PANEL_COLOR: Color = Color(0.14, 0.14, 0.18)
const SECTION_COLOR: Color = Color(1.0, 0.85, 0.2)
const KEY_COLOR: Color = Color(0.75, 0.92, 1.0)
const KEY_COLUMN_WIDTH: float = 78.0
const TEXT_COLUMN_WIDTH: float = 150.0

## [section title, [[action name or key text, what it does], ...]], in two columns.
const LEFT_SECTIONS: Array = [
	["Painting (Terrain tab)", [
		["editor_paint", "paint tiles (drag for more)"],
		["editor_erase", "erase tiles"],
		["editor_rectangle", "+ drag: fill / clear a rectangle"],
	]],
	["Objects (Basics, Air tabs)", [
		["editor_paint", "place, or pick up and drag"],
		["editor_free_place", "+ place / drag: free, to the pixel"],
		["editor_erase", "delete the object under the mouse"],
		["editor_delete", "delete the selected object"],
		["editor_duplicate", "copy the selected object to the mouse"],
		["editor_rotate", "turn the selected spikes or plank"],
		["Drag a handle", "resize, or move a point (leaf, rail)"],
		["Zones", "pick a zone by its edge; inside, clicks reach what's in it"],
	]],
	["Eraser", [
		["editor_eraser", "eraser on / off"],
		["Click or drag", "remove objects, else tiles"],
		["editor_rectangle", "+ drag: clear a block (tiles and objects)"],
	]],
	["Map of rooms", [
		["editor_map", "map on / off"],
		["Drag", "empty space: new room; room: move; edge: resize"],
		["Fill edges", "room panel button: wall a room in"],
		["Double-click", "edit that room"],
		["editor_start_room", "make the selected room the start"],
		["editor_delete", "delete the selected room"],
		["editor_import", "import a room as a copy"],
	]],
]
const RIGHT_SECTIONS: Array = [
	["Links (doors)", [
		["editor_link", "link mode for the selected door"],
		["Click a switch", "link / unlink it (plates, windmills)"],
		["editor_back", "end link mode"],
	]],
	["View", [
		["editor_pan", "pan (drag)"],
		["editor_pan_hold", "+ left drag: pan"],
		["editor_zoom_in", "zoom in (on the mouse)"],
		["editor_zoom_out", "zoom out"],
		["editor_toggle_grid", "grid on / off"],
	]],
	["Play-test", [
		["editor_playtest", "play from the start / back to editor"],
		["editor_playtest_here", "play from the mouse"],
		["pause", "in play: pause menu, Back to editor"],
		["restart_room", "in play: restart the room"],
	]],
	["File", [
		["editor_undo", "undo"],
		["editor_redo", "redo"],
		["editor_save", "save"],
		["editor_back", "back to the level list (asks if unsaved)"],
		["editor_help", "this help"],
	]],
]

## Mouse buttons by name: InputEventMouseButton.as_text() says "Left Mouse Button".
const MOUSE_BUTTON_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_MIDDLE: "Middle mouse", MOUSE_BUTTON_WHEEL_UP: "Wheel up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
}

var close_button: Button


func _ready() -> void:
	color = DIM_COLOR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	panel.add_child(page)

	var title: Label = Label.new()
	title.text = "Level editor: quick reference"
	title.add_theme_font_size_override("font_size", 12)
	page.add_child(title)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	page.add_child(columns)
	columns.add_child(_build_column(LEFT_SECTIONS))
	columns.add_child(_build_column(RIGHT_SECTIONS))

	close_button = Button.new()
	close_button.text = "Close (H or Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	page.add_child(close_button)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


## H and Esc close it. _input runs before anything else gets the key, so the
## editor behind never sees it (Esc would otherwise leave the editor).
func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("editor_help") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


## One column of sections: a colored title, then a grid of key | what it does.
func _build_column(sections: Array) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	for section: Array in sections:
		var section_title: Label = Label.new()
		section_title.text = section[0]
		section_title.modulate = SECTION_COLOR
		column.add_child(section_title)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("v_separation", 0)
		column.add_child(grid)
		for row: Array in section[1]:
			var key_label: Label = Label.new()
			key_label.text = key_text(row[0])
			key_label.modulate = KEY_COLOR
			key_label.custom_minimum_size = Vector2(KEY_COLUMN_WIDTH, 0)
			grid.add_child(key_label)
			var what_label: Label = Label.new()
			what_label.text = row[1]
			what_label.custom_minimum_size = Vector2(TEXT_COLUMN_WIDTH, 0)
			what_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			grid.add_child(what_label)
	return column


## The keys bound to `action` ("Ctrl+Z / Ctrl+Y"), or `action` itself when it
## isn't an InputMap action (a description like "Drag a handle").
static func key_text(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	var names: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			names.append(MOUSE_BUTTON_NAMES.get((event as InputEventMouseButton).button_index, event.as_text()))
		elif event is InputEventKey:
			# as_text_physical_keycode(): "Ctrl+Z" for a key bound by its position.
			var key_event: InputEventKey = event as InputEventKey
			names.append(key_event.as_text_physical_keycode() if key_event.physical_keycode != KEY_NONE else key_event.as_text())
		else:
			names.append(event.as_text())
	return " / ".join(names)

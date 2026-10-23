class_name EditorUI
extends CanvasLayer
## EditorUI: the level editor's panels (Level_editor.md §4). Only shows things;
## LevelEditor tells it what to show and owns all the logic.
##   - top bar:     level title, unsaved dot, current tool, zoom
##   - help:        the quick reference (EditorHelp), from the top bar's "?" or H
##   - palette:     left column: tools without a family (the Eraser) at the very
##                  top, then a tab per family (Terrain, Basics, Air...),
##                  below it one button per PaletteCatalog entry of the open tab;
##                  emits `entry_chosen` when an entry is clicked
##   - property panel: right column, the selected object's (or room's) settings
##                  (PropertyPanel, Stage L5)
##   - status line: room + tile under the mouse, the last message, key hints
## It also holds the PromptPanel the editor asks questions with, and the import
## list (RoomImportPicker, Stage L7).
##
## A CanvasLayer draws its Controls fixed on screen, ignoring the editor camera.
## Sizes are in the editor's 640x360 space (LevelEditor switches the window to it).
## The middle of the screen is left empty with mouse_filter IGNORE, so clicks
## there fall through to LevelEditor._unhandled_input() and paint the level;
## the panels use STOP, so clicking a panel never paints behind it.

## A palette button was clicked: LevelEditor switches to that brush or object.
signal entry_chosen(entry: PaletteCatalog.Entry)

const FONT_SIZE: int = 8
const PANEL_COLOR: Color = Color(0.12, 0.12, 0.15, 0.92)
const DIRTY_COLOR: Color = Color(1.0, 0.65, 0.2)
const ERROR_COLOR: Color = Color(1.0, 0.45, 0.4)
const HINT_ALPHA: float = 0.55
const BAR_HEIGHT: float = 14.0
const PALETTE_WIDTH: float = 92.0
const PROPERTY_PANEL_WIDTH: float = 124.0
## Family tabs per row at the top of the palette.
const TAB_COLUMNS: int = 2
const DIRTY_DOT_SIZE: Vector2 = Vector2(5, 5)
## Palette tooltips are broken into lines of at most this many characters.
const TOOLTIP_LINE_LENGTH: int = 48
## How long a status message stays before the key hints come back.
const MESSAGE_SECONDS: float = 4.0
## Key hints per kind of palette entry, then the ones that always apply.
const TERRAIN_HINTS: String = "Left: paint  Right: erase  Shift+drag: rectangle"
const OBJECT_HINTS: String = "Left: place / drag  Alt: free  Right: delete  Del  Ctrl+D: copy  L: link"
const STRIP_HINTS: String = "Drag along a row or column: spikes  R: turn selected  Right: delete"
const ERASER_HINTS: String = "Click or drag: remove objects (zones too), else tiles  Shift+drag: a block  E: eraser off"
const MAP_HINTS: String = "Drag empty: new room  Drag room / edge: move / resize  Double-click: edit  S: start  Del  I: import  M: back"
const COMMON_HINTS: String = "H: all keys  M: map  Tab: play  Space/Middle: pan  Wheel: zoom  G: grid  E: eraser  Ctrl+Z/Y  Ctrl+S"

var title_label: Label
var dirty_dot: ColorRect
var tool_label: Label
var zoom_label: Label
var cursor_label: Label
var message_label: Label
var top_bar: PanelContainer
var palette: PanelContainer
var property_panel: PropertyPanel
var status_bar: PanelContainer
var prompt: PromptPanel
var help: EditorHelp
## The "Import room as a copy" list (Stage L7).
var import_picker: RoomImportPicker
## The hints for the current tool (set_tool_hints), shown when there's no message.
var key_hints: String = TERRAIN_HINTS + "    " + COMMON_HINTS
## Palette button per entry id, to show which one is chosen.
var palette_buttons: Dictionary = {}
## Tab button and entry list per family name; only the open family's list shows.
var family_tabs: Dictionary = {}
var family_lists: Dictionary = {}
var open_family: String = ""
## Seconds until the status line goes back to the key hints (0 = showing hints).
var message_time_left: float = 0.0


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A Theme set on a Control applies to all its children: one font size for all.
	var theme_for_all: Theme = Theme.new()
	theme_for_all.default_font_size = FONT_SIZE
	root.theme = theme_for_all
	add_child(root)

	top_bar = _make_panel()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	root.add_child(top_bar)
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	top_bar.add_child(top_row)
	title_label = Label.new()
	top_row.add_child(title_label)
	# The unsaved dot: a tiny square, centered vertically in the bar.
	var dot_holder: CenterContainer = CenterContainer.new()
	dirty_dot = ColorRect.new()
	dirty_dot.color = DIRTY_COLOR
	dirty_dot.custom_minimum_size = DIRTY_DOT_SIZE
	dot_holder.add_child(dirty_dot)
	top_row.add_child(dot_holder)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var help_button: Button = Button.new()
	help_button.text = "? Help"
	help_button.focus_mode = Control.FOCUS_NONE  # Space must pan, not press it
	help_button.pressed.connect(func() -> void: help.open())
	top_row.add_child(help_button)
	tool_label = Label.new()
	top_row.add_child(tool_label)
	zoom_label = Label.new()
	top_row.add_child(zoom_label)

	palette = _make_panel()
	palette.position = Vector2(0, BAR_HEIGHT)
	palette.custom_minimum_size = Vector2(PALETTE_WIDTH, 0)
	root.add_child(palette)
	var palette_column: VBoxContainer = VBoxContainer.new()
	palette.add_child(palette_column)
	_build_palette(palette_column)

	property_panel = PropertyPanel.new()
	property_panel.custom_minimum_size = Vector2(PROPERTY_PANEL_WIDTH, 0)
	root.add_child(property_panel)

	status_bar = _make_panel()
	status_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	status_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN  # grows up from the bottom edge
	root.add_child(status_bar)
	var status_row: HBoxContainer = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	status_bar.add_child(status_row)
	cursor_label = Label.new()
	cursor_label.custom_minimum_size = Vector2(110, 0)
	status_row.add_child(cursor_label)
	message_label = Label.new()
	message_label.clip_text = true
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(message_label)

	prompt = PromptPanel.new()
	root.add_child(prompt)
	help = EditorHelp.new()
	root.add_child(help)
	import_picker = RoomImportPicker.new()
	root.add_child(import_picker)
	show_message("")
	# The palette's height follows the screen: stretch it between the two bars.
	get_viewport().size_changed.connect(_fit_palette)
	_fit_palette()


func set_title(text: String) -> void:
	title_label.text = text


func set_dirty(is_dirty: bool) -> void:
	dirty_dot.visible = is_dirty
	dirty_dot.tooltip_text = "Unsaved changes" if is_dirty else ""


func set_tool(text: String) -> void:
	tool_label.text = text


## Shows `entry` as the chosen palette button, its name in the top bar, and its
## key hints in the status line.
func show_chosen_entry(entry: PaletteCatalog.Entry) -> void:
	if entry.family != "":
		show_family(entry.family)  # the eraser keeps whatever tab is open
	# set_pressed_no_signal() skips the ButtonGroup's "release the others", so set all.
	for id: StringName in palette_buttons:
		(palette_buttons[id] as Button).set_pressed_no_signal(id == entry.id)
	match entry.kind:
		PaletteCatalog.Kind.TERRAIN:
			set_tool("Brush: " + entry.display_name)
		PaletteCatalog.Kind.ERASER:
			set_tool("Eraser")
		_:
			set_tool("Place: " + entry.display_name)
	var tool_hints: String = TERRAIN_HINTS
	if entry.kind == PaletteCatalog.Kind.ERASER:
		tool_hints = ERASER_HINTS
	elif entry.kind == PaletteCatalog.Kind.STRIP:
		tool_hints = STRIP_HINTS
	elif entry.kind != PaletteCatalog.Kind.TERRAIN:
		tool_hints = OBJECT_HINTS
	set_key_hints(tool_hints)


## Shows `tool_hints` (then the hints that always apply) when there's no message.
func set_key_hints(tool_hints: String) -> void:
	key_hints = tool_hints + "    " + COMMON_HINTS
	if message_time_left <= 0.0:
		show_message("")


func set_zoom(zoom_factor: float) -> void:
	zoom_label.text = "zoom %sx" % str(zoom_factor)


## The room and tile under the mouse ("" when it's outside every room).
func set_cursor_info(text: String) -> void:
	cursor_label.text = text


## Shows a message in the status line for MESSAGE_SECONDS; "" shows the key hints.
func show_message(text: String, is_error: bool = false) -> void:
	if text == "":
		message_label.text = key_hints
		message_label.modulate = Color(1.0, 1.0, 1.0, HINT_ALPHA)
		message_time_left = 0.0
	else:
		message_label.text = text
		message_label.modulate = ERROR_COLOR if is_error else Color.WHITE
		message_time_left = MESSAGE_SECONDS


## Counts down the current message, then brings the key hints back.
func _process(delta: float) -> void:
	if message_time_left > 0.0:
		message_time_left -= delta
		if message_time_left <= 0.0:
			show_message("")


## True if `screen_point` (viewport coordinates) is over a panel, where clicks
## must not paint. LevelEditor uses it for the hover square.
func is_over_panels(screen_point: Vector2) -> bool:
	for panel: Control in [top_bar, palette, property_panel, status_bar]:
		if panel.get_global_rect().has_point(screen_point):
			return true
	return prompt.visible or help.visible or import_picker.visible


## LevelEditor changes the window back while leaving, which fires size_changed;
## by then this node is out of the tree, so stop listening first.
func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_fit_palette)


## Opens a family's tab: its entries show, the other families' hide.
func show_family(family: String) -> void:
	open_family = family
	for family_name: String in family_lists:
		(family_lists[family_name] as Control).visible = family_name == family
		(family_tabs[family_name] as Button).set_pressed_no_signal(family_name == family)


## The family tabs (a grid), then one list of entry buttons per family. Each set
## is a ButtonGroup: toggle buttons that work like radio buttons, pressing one
## releases the others.
func _build_palette(column: VBoxContainer) -> void:
	# Tools (entries without a family) first, one per row, then a line.
	var entry_group: ButtonGroup = ButtonGroup.new()
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.family == "":
			column.add_child(_make_entry_button(entry, entry_group))
	column.add_child(HSeparator.new())

	var tab_grid: GridContainer = GridContainer.new()
	tab_grid.columns = TAB_COLUMNS
	column.add_child(tab_grid)
	var tab_group: ButtonGroup = ButtonGroup.new()
	for family: String in PaletteCatalog.get_families():
		var tab: Button = _make_toggle(family, tab_group)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(show_family.bind(family))
		tab_grid.add_child(tab)
		family_tabs[family] = tab
		var entry_list: VBoxContainer = VBoxContainer.new()
		column.add_child(entry_list)
		family_lists[family] = entry_list
	var separator: HSeparator = HSeparator.new()
	column.add_child(separator)
	column.move_child(separator, tab_grid.get_index() + 1)  # under the tabs

	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.family != "":
			(family_lists[entry.family] as VBoxContainer).add_child(_make_entry_button(entry, entry_group))
	show_family(PaletteCatalog.get_families()[0])


func _make_entry_button(entry: PaletteCatalog.Entry, group: ButtonGroup) -> Button:
	var button: Button = _make_toggle(entry.display_name, group)
	# tooltip_text: Godot shows it in a small floating box when the mouse rests
	# on the button (what the thing does, what triggers or breaks it).
	# Godot doesn't wrap tooltips, so the lines are broken here.
	button.tooltip_text = wrap_text(entry.hint, TOOLTIP_LINE_LENGTH)
	button.pressed.connect(func() -> void: entry_chosen.emit(entry))
	palette_buttons[entry.id] = button
	return button


## `text` with line breaks between words, so no line is longer than `line_length`
## characters (unless one word is).
static func wrap_text(text: String, line_length: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in text.split(" ", false):
		if line != "" and line.length() + 1 + word.length() > line_length:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return "\n".join(lines)


func _make_toggle(text: String, group: ButtonGroup) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE  # Space must pan, not press a button
	return button


## The side columns fill the height between the two bars; the property panel
## hugs the right edge.
func _fit_palette() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var column_height: float = screen_size.y - 2.0 * BAR_HEIGHT
	palette.size = Vector2(PALETTE_WIDTH, column_height)
	property_panel.position = Vector2(screen_size.x - PROPERTY_PANEL_WIDTH, BAR_HEIGHT)
	property_panel.size = Vector2(PROPERTY_PANEL_WIDTH, column_height)


func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel

class_name EditorUI
extends CanvasLayer
## EditorUI: the level editor's panels (Level_editor.md §4). Only shows things;
## LevelEditor tells it what to show and owns all the logic.
##   - top bar:     level title, unsaved dot, current tool, zoom
##   - help:        the quick reference (EditorHelp), from the top bar's "?" or H
##   - backdrop_preview: every backdrop look on its own (BackdropPreview), from K
##   - palette:     left column: the tools without a family (Select, Eraser,
##                  Brush, Fill) in a row at the very top, the search box
##                  (PaletteSearch: its matches replace the tabs while it has
##                  text), then a tab per family
##                  (Terrain, Basics, Triggers...), below it one button per
##                  PaletteCatalog entry of the open tab (a scrolling list when it
##                  is taller than the screen); emits `entry_chosen` when an entry
##                  is clicked. Each button shows a small picture of its thing
##                  (PaletteIcons) and is tinted in its element's color (Air cyan,
##                  Earth tan, Fire orange), with a stripe of it on the left.
##                  At the bottom, the QuickBar: the 9 things used last (keys 1-9).
##   - menu:        a pop-up list at the mouse (show_menu): the Select tool's
##                  "which one?" and the map's right-click room menu
##   - property panel: right column, the selected object's (or room's) settings
##                  (PropertyPanel, Stage L5)
##   - status line: room + tile under the mouse, the last message, key hints, and
##     the DEPTH SLIDER (Level_editor.md §5a): drag it to edit another depth
##     (depth_chosen; LevelEditor.show_depth). It reaches one past the deepest
##     depth, to start a new one.
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
## The depth slider was moved to `depth` (LevelEditor.show_depth).
signal depth_chosen(depth: int)

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
const SELECT_HINTS: String = "Left: select, drag to move  Shift+drag: region  Ctrl+C/X/V: copy, cut, paste  Ctrl+Shift+V: mirrored"
const FILL_HINTS: String = "Left: fill the connected area  Shift: all over the room  Right: clear it  B: back to the brush"
const MAP_HINTS: String = "Drag empty: select rooms  Ctrl+click: add  Drag room / edge: move / resize  Double-click: edit  Right: new room, backdrop, copy, depth  K: backdrops  S: start  Del  PgDn/PgUp: depth  M: back"
## How strongly a palette button is tinted in its element's color: resting,
## under the mouse, chosen.
const ELEMENT_TINT: Array[float] = [0.22, 0.34, 0.6]
## The element stripe on a button's left edge, px.
const ELEMENT_STRIPE_WIDTH: int = 2
## The depth slider's width, px.
const DEPTH_SLIDER_WIDTH: float = 60.0
const COMMON_HINTS: String = "H: all keys  M: map  Tab: play  J: jump reach  P: pick  Ctrl+F: find  1-9: recent  E: eraser  Ctrl+Z/Y  Ctrl+S"

var title_label: Label
var dirty_dot: ColorRect
var tool_label: Label
var zoom_label: Label
var cursor_label: Label
var message_label: Label
## The depth slider and its "Depth N" label (see the header).
var depth_label: Label
var depth_slider: HSlider
var top_bar: PanelContainer
var palette: PanelContainer
var property_panel: PropertyPanel
var status_bar: PanelContainer
var prompt: PromptPanel
var help: EditorHelp
var backdrop_preview: BackdropPreview
## The "Import room as a copy" list (Stage L7).
var import_picker: RoomImportPicker
## The hints for the current tool (set_tool_hints), shown when there's no message.
var key_hints: String = TERRAIN_HINTS + "    " + COMMON_HINTS
## Palette button per entry id, to show which one is chosen.
var palette_buttons: Dictionary = {}
## menu_group name -> Array of its entries, and -> the one Button that opens its list.
var menu_groups: Dictionary = {}
var menu_group_buttons: Dictionary = {}
var menu_group_button_group: ButtonGroup = null
## The second buttons of entries shown in more than one tab (catalog `extra_tabs`):
## entry id -> Array of Buttons. They're pressed together with the main one.
var extra_palette_buttons: Dictionary = {}
## Tab button and entry list per family name; only the open family's list shows.
var family_tabs: Dictionary = {}
var family_lists: Dictionary = {}
var open_family: String = ""
## Seconds until the status line goes back to the key hints (0 = showing hints).
var message_time_left: float = 0.0
## The pop-up list (show_menu) and what to call with the chosen row's index.
var menu: PopupMenu
var menu_callback: Callable = Callable()
## The palette's search box (Ctrl+F) and recent-things row (1-9), and the parts
## the search hides while it shows its matches.
var search: PaletteSearch
var quick_bar: QuickBar
var palette_tab_grid: GridContainer
var palette_scroll: ScrollContainer


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
	depth_label = Label.new()
	status_row.add_child(depth_label)
	depth_slider = HSlider.new()
	depth_slider.custom_minimum_size = Vector2(DEPTH_SLIDER_WIDTH, 0)
	depth_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	depth_slider.step = 1.0
	depth_slider.tick_count = 2
	depth_slider.ticks_on_borders = true
	# Never keyboard focus: the arrows must keep moving the camera, Page Down / Up
	# step depths themselves.
	depth_slider.focus_mode = Control.FOCUS_NONE
	# value_changed: a Range's signal when the value moves (dragged or clicked).
	depth_slider.value_changed.connect(func(value: float) -> void: depth_chosen.emit(roundi(value)))
	status_row.add_child(depth_slider)

	prompt = PromptPanel.new()
	root.add_child(prompt)
	help = EditorHelp.new()
	root.add_child(help)
	backdrop_preview = BackdropPreview.new()
	root.add_child(backdrop_preview)
	import_picker = RoomImportPicker.new()
	root.add_child(import_picker)
	# A PopupMenu is a small window of clickable rows; it closes itself when a row
	# is clicked or the mouse clicks elsewhere.
	menu = PopupMenu.new()
	menu.add_theme_font_size_override("font_size", FONT_SIZE)
	menu.id_pressed.connect(_on_menu_row_pressed)
	root.add_child(menu)
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
## key hints in the status line. `fill_terrain` (the Fill tool): the terrain it
## fills with, shown pressed too, and its tab opened.
func show_chosen_entry(entry: PaletteCatalog.Entry, fill_terrain: PaletteCatalog.Entry = null) -> void:
	# The tools keep whatever tab is open; so does an entry the open tab shows too
	# (a hidden chamber picked in the Breakable tab stays there).
	if entry.family != "":
		if not entry.extra_tabs.has(open_family):
			show_family(entry.family)
	elif fill_terrain != null and fill_terrain.family != open_family and not fill_terrain.extra_tabs.has(open_family):
		show_family(fill_terrain.family)
	# set_pressed_no_signal() skips the ButtonGroup's "release the others", so set all.
	for id: StringName in palette_buttons:
		var pressed: bool = id == entry.id or (fill_terrain != null and id == fill_terrain.id)
		# The Brush tool is pressed while any terrain paints (it stands for "painting").
		pressed = pressed or (id == &"brush" and entry.kind == PaletteCatalog.Kind.TERRAIN)
		(palette_buttons[id] as Button).set_pressed_no_signal(pressed)
		for extra_button: Button in extra_palette_buttons.get(id, []):
			extra_button.set_pressed_no_signal(pressed)
	# A group's button stands for whichever of its entries is chosen: pressed, and
	# showing that entry's picture.
	for group_name: String in menu_group_buttons:
		var group_button: Button = menu_group_buttons[group_name]
		var holds_chosen: bool = false
		for member: PaletteCatalog.Entry in menu_groups[group_name]:
			holds_chosen = holds_chosen or member.id == entry.id or (fill_terrain != null and member.id == fill_terrain.id)
			if member.id == entry.id:
				group_button.icon = PaletteIcons.get_icon(member)
		group_button.set_pressed_no_signal(holds_chosen)
		group_button.set_meta(&"chosen", holds_chosen)
	match entry.kind:
		PaletteCatalog.Kind.TERRAIN:
			set_tool("Brush: " + entry.display_name)
		PaletteCatalog.Kind.ERASER:
			set_tool("Eraser")
		PaletteCatalog.Kind.SELECT:
			set_tool("Select")
		PaletteCatalog.Kind.FILL:
			set_tool("Fill: " + (fill_terrain.display_name if fill_terrain != null else "Ground"))
		_:
			set_tool("Place: " + entry.display_name)
	var tool_hints: String = TERRAIN_HINTS
	match entry.kind:
		PaletteCatalog.Kind.ERASER:
			tool_hints = ERASER_HINTS
		PaletteCatalog.Kind.SELECT:
			tool_hints = SELECT_HINTS
		PaletteCatalog.Kind.FILL:
			tool_hints = FILL_HINTS
		PaletteCatalog.Kind.STRIP:
			tool_hints = STRIP_HINTS
		PaletteCatalog.Kind.TERRAIN:
			tool_hints = TERRAIN_HINTS
		_:
			tool_hints = OBJECT_HINTS
	set_key_hints(tool_hints)


## Opens the pop-up list with `rows` at `screen_point` (viewport coordinates);
## clicking row i calls `on_chosen` with i. Clicking elsewhere closes it, calling
## nothing.
func show_menu(rows: Array[String], screen_point: Vector2, on_chosen: Callable) -> void:
	menu.clear()
	for row_index: int in rows.size():
		menu.add_item(rows[row_index], row_index)
	menu_callback = on_chosen
	menu.reset_size()  # shrink to the new rows
	menu.popup(Rect2i(Vector2i(screen_point), Vector2i.ZERO))


func _on_menu_row_pressed(row_id: int) -> void:
	if menu_callback.is_valid():
		menu_callback.call(row_id)


## Shows `tool_hints` (then the hints that always apply) when there's no message.
func set_key_hints(tool_hints: String) -> void:
	key_hints = tool_hints + "    " + COMMON_HINTS
	if message_time_left <= 0.0:
		show_message("")


## Shows `shown` on the depth slider, which reaches `depth_count` (one past the
## deepest: a new depth). Doesn't emit depth_chosen.
func set_depth(shown: int, depth_count: int) -> void:
	depth_slider.max_value = depth_count
	depth_slider.tick_count = depth_count + 1
	depth_slider.set_value_no_signal(shown)
	depth_label.text = "Depth %d" % shown


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
	return prompt.visible or help.visible or import_picker.visible or menu.visible or backdrop_preview.visible


## LevelEditor changes the window back while leaving, which fires size_changed;
## by then this node is out of the tree, so stop listening first.
func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_fit_palette)


## While the search box has text, its matches replace the tabs and their lists.
func _on_search_changed() -> void:
	var searching: bool = search.is_searching()
	palette_tab_grid.visible = not searching
	palette_scroll.visible = not searching


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
	# Tools (entries without a family) first, side by side in one row, then a line.
	var entry_group: ButtonGroup = ButtonGroup.new()
	var tool_row: HBoxContainer = HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 1)
	column.add_child(tool_row)
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.family == "":
			var tool_button: Button = _make_entry_button(entry, entry_group)
			tool_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Icon only (the row is narrow); the name is in the tooltip.
			tool_button.tooltip_text = entry.display_name + "\n" + tool_button.tooltip_text
			tool_button.text = ""
			tool_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tool_row.add_child(tool_button)
	column.add_child(HSeparator.new())
	search = PaletteSearch.new()
	search.entry_chosen.connect(func(entry: PaletteCatalog.Entry) -> void: entry_chosen.emit(entry))
	search.search_changed.connect(_on_search_changed)
	column.add_child(search)

	var tab_grid: GridContainer = GridContainer.new()
	palette_tab_grid = tab_grid
	tab_grid.columns = TAB_COLUMNS
	column.add_child(tab_grid)
	column.add_child(HSeparator.new())  # under the tabs
	# The open tab's buttons scroll (after the L10 play-test: the Air list ran under
	# the status line). A ScrollContainer shows as much of its child as fits and
	# scrolls the rest with the mouse wheel; EXPAND_FILL makes it take the height
	# left between the tabs and the bottom bar, so the palette never grows past it.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	palette_scroll = scroll
	# The recent things, at the very bottom (keys 1-9).
	column.add_child(HSeparator.new())
	quick_bar = QuickBar.new()
	quick_bar.entry_chosen.connect(func(entry: PaletteCatalog.Entry) -> void: entry_chosen.emit(entry))
	column.add_child(quick_bar)
	var lists: VBoxContainer = VBoxContainer.new()
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lists)
	var tab_group: ButtonGroup = ButtonGroup.new()
	for family: String in PaletteCatalog.get_families():
		var tab: Button = _make_toggle(family, tab_group)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(show_family.bind(family))
		tab_grid.add_child(tab)
		family_tabs[family] = tab
		var entry_list: VBoxContainer = VBoxContainer.new()
		lists.add_child(entry_list)
		family_lists[family] = entry_list

	menu_group_button_group = entry_group
	for entry: PaletteCatalog.Entry in PaletteCatalog.get_entries():
		if entry.menu_group != "":
			_add_to_menu_group(entry)
			continue
		if entry.family != "":
			(family_lists[entry.family] as VBoxContainer).add_child(_make_entry_button(entry, entry_group))
			# Its other tabs get a button of their own (made after the main one, so
			# palette_buttons keeps the main one).
			var main_button: Button = palette_buttons[entry.id]
			var extra_buttons: Array[Button] = []
			for tab: String in entry.extra_tabs:
				var extra_button: Button = _make_entry_button(entry, entry_group)
				(family_lists[tab] as VBoxContainer).add_child(extra_button)
				extra_buttons.append(extra_button)
			palette_buttons[entry.id] = main_button
			if not extra_buttons.is_empty():
				extra_palette_buttons[entry.id] = extra_buttons
	show_family(PaletteCatalog.get_families()[0])


## Entries with a `menu_group` share one button, made for the first of them: it drops
## down a list of the group (clicking a row chooses that entry). The others get no
## button of their own, so palette_buttons holds only the group's first entry.
func _add_to_menu_group(entry: PaletteCatalog.Entry) -> void:
	if menu_groups.has(entry.menu_group):
		(menu_groups[entry.menu_group] as Array).append(entry)
		palette_buttons[entry.id] = menu_group_buttons[entry.menu_group]  # the group's one button
		return
	menu_groups[entry.menu_group] = [entry]
	var button: Button = _make_entry_button(entry, menu_group_button_group)
	button.text = entry.menu_group + " ▾"  # the name and a little down arrow
	button.tooltip_text = "Click for a list of the %ss.\n" % entry.menu_group.to_lower() + button.tooltip_text
	# The helper wired it to choose `entry`; open the list instead.
	for connection: Dictionary in button.pressed.get_connections():
		button.pressed.disconnect(connection["callable"])
	button.pressed.connect(_open_menu_group.bind(entry.menu_group, button))
	menu_group_buttons[entry.menu_group] = button
	(family_lists[entry.family] as VBoxContainer).add_child(button)


func _open_menu_group(group_name: String, button: Button) -> void:
	var members: Array = menu_groups[group_name]
	var rows: Array[String] = []
	for member: PaletteCatalog.Entry in members:
		rows.append(member.display_name)
	# A toggle button flips itself when clicked: put it back until a row is chosen.
	button.set_pressed_no_signal(bool(button.get_meta(&"chosen", false)))
	var rect: Rect2 = button.get_global_rect()
	show_menu(rows, Vector2(rect.end.x, rect.position.y),
		func(row: int) -> void: entry_chosen.emit(members[row]))


func _make_entry_button(entry: PaletteCatalog.Entry, group: ButtonGroup) -> Button:
	var button: Button = _make_toggle(entry.display_name, group)
	# tooltip_text: Godot shows it in a small floating box when the mouse rests
	# on the button (what the thing does, what triggers or breaks it).
	# Godot doesn't wrap tooltips, so the lines are broken here.
	button.tooltip_text = wrap_text(entry.hint, TOOLTIP_LINE_LENGTH)
	button.pressed.connect(func() -> void: entry_chosen.emit(entry))
	button.icon = PaletteIcons.get_icon(entry)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if entry.element != "":
		_tint_button(button, PaletteIcons.element_color(entry.element))
	palette_buttons[entry.id] = button
	return button


## Gives `button` a background in `color` (stronger under the mouse and when
## chosen) with a stripe of it on the left edge. A StyleBoxFlat is a plain colored
## box; a Button draws one per state ("normal", "hover", "pressed"...).
func _tint_button(button: Button, color: Color) -> void:
	var states: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed"]
	var strengths: Array[float] = [ELEMENT_TINT[0], ELEMENT_TINT[1], ELEMENT_TINT[2], ELEMENT_TINT[2]]
	for state_index: int in states.size():
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(color.darkened(0.35), strengths[state_index])
		style.border_width_left = ELEMENT_STRIPE_WIDTH
		style.border_color = color
		style.content_margin_left = 3
		style.content_margin_right = 2
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		button.add_theme_stylebox_override(states[state_index], style)


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

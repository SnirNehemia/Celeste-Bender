class_name TuningPanel
extends CanvasLayer
## In-game tuning panel (Fire_bending.md §10, PROMPTS.md Stage F2). F5
## (`debug_tuning_panel`) opens it over the paused game; it edits the player's tuning
## resources (PlayerTuning, EarthTuning, FireTuning), one tab each.
##
## It is GENERIC: it never names a tuning value. It asks each resource for its
## property list (get_property_list()) and shows every `@export` var under its
## `@export_group`, so values added by later stages appear here by themselves.
##
## Keys (all through InputMap actions, never raw keys):
##   Up/Down (ui_up/ui_down)          pick a value
##   Left/Right (ui_left/ui_right)    change it; hold Shift (`debug_tuning_big_step`) for ×10
##   R (`debug_tuning_reset`)         put the value back to the one saved in the .tres
##   PageUp/PageDown, Tab             switch tabs
##   F5 or Esc                        close
## F4 (`debug_save_tuning`, handled by DebugOverlay) writes all three to their .tres.
##
## Who creates it: DebugOverlay adds one next to itself in _ready and hands it the
## player, so every world that has the overlay gets the panel without scene edits.
##
## Changes are LIVE: the panel edits the very Resource objects the player holds, and
## the movement/bending code reads `tuning.x` fresh every frame. On close it also
## calls emit_changed() on each edited resource, for any code that caches a value
## and wants to hear about edits (Resource's built-in `changed` signal).
##
## Godot concepts used:
##   - get_property_list(): every Object can describe its properties as Dictionaries
##     (name, type, hint, hint_string, usage). `usage` flags tell exported script
##     vars (PROPERTY_USAGE_SCRIPT_VARIABLE + EDITOR) apart from built-in ones, and
##     export groups show up as fake entries flagged PROPERTY_USAGE_GROUP.
##   - get()/set() by name: read and write a property whose name is only known at
##     run time (the panel has no idea `max_run_speed` exists).
##   - _input vs _unhandled_input: _input sees key presses FIRST, so the open panel
##     can swallow the arrows before anything else reacts to them.
##   - process_mode ALWAYS: keeps this node running while the tree is paused.

## Emitted when the panel opens or closes (the smoke test listens).
signal open_changed(is_open: bool)

## The player whose tuning resources are edited. Set by DebugOverlay.
var player: Player

## How many value rows fit in the panel at once (font size 8, 320×180 screen).
const VISIBLE_ROWS: int = 13
## Shown for values the panel can't edit (Curves, Colors, ...).
const READ_ONLY_NOTE: String = "edit in Inspector"

## One tab per resource: display name + the live Resource the player holds.
var tab_names: Array[String] = []
var tab_resources: Array[Resource] = []
## A fresh copy of each resource as saved on disk, for "reset" and the * marks.
var saved_copies: Array[Resource] = []
var current_tab: int = 0
## The rows of the current tab. Each row is a Dictionary, see _build_rows().
var rows: Array[Dictionary] = []
## Index into `rows` of the highlighted value (never a group header).
var selected_row: int = 0
## First row drawn; moves so the selected row stays inside the visible window.
var first_visible_row: int = 0
## Tabs whose values were changed since the panel opened (they get emit_changed()).
var edited_tabs: Dictionary = {}

var background: PanelContainer
var tabs_label: RichTextLabel
var body_label: RichTextLabel
var footer_label: Label


func _ready() -> void:
	layer = 25  # above the debug overlay (10) and the room picker (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"tuning_panel")
	_build_panel()
	background.visible = false


func is_open() -> bool:
	return background.visible


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_tuning_panel"):
		# Another menu (pause menu, room picker) has the game paused: stay closed.
		if not is_open() and FX.is_menu_open:
			return
		set_open(not is_open())
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	# allow_echo = true: holding a key repeats the step (the OS key-repeat).
	if event.is_action_pressed("ui_cancel"):
		set_open(false)
	elif event.is_action_pressed("ui_up", true):
		move_selection(-1)
	elif event.is_action_pressed("ui_down", true):
		move_selection(1)
	elif event.is_action_pressed("ui_left", true):
		change_selected(-1, Input.is_action_pressed("debug_tuning_big_step"))
	elif event.is_action_pressed("ui_right", true):
		change_selected(1, Input.is_action_pressed("debug_tuning_big_step"))
	elif event.is_action_pressed("debug_tuning_reset"):
		reset_selected()
	elif event.is_action_pressed("ui_page_up"):
		switch_tab(-1)
	elif event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_focus_next"):
		switch_tab(1)
	elif event.is_action_pressed("debug_save_tuning"):
		return  # let DebugOverlay save; it tells us through saved_to_disk()
	else:
		return
	# Swallow every key the panel used, so the paused game never sees it.
	get_viewport().set_input_as_handled()


## Opens (pausing the game) or closes (resuming it) the panel.
func set_open(open: bool) -> void:
	if open == is_open():
		return
	if open:
		_collect_resources()
		edited_tabs.clear()
		_show_tab(clampi(current_tab, 0, maxi(tab_resources.size() - 1, 0)))
	else:
		# "Changes apply as soon as it closes": tell anyone listening to `changed`.
		for tab_index: int in edited_tabs:
			tab_resources[tab_index].emit_changed()
	background.visible = open
	# Through FX, not get_tree().paused, so a freeze frame ending can't unpause us.
	FX.set_menu_pause(open)
	open_changed.emit(open)


## Called by DebugOverlay after F4 wrote the resources to disk: what's saved now
## is what's live, so reload the saved copies (clears every * mark).
## `message` is the overlay's "Tuning saved: ..." line, shown in the footer because
## the panel covers the overlay's own text.
func saved_to_disk(message: String = "") -> void:
	saved_copies.clear()
	for resource: Resource in tab_resources:
		saved_copies.append(_load_saved_copy(resource))
	if is_open():
		_redraw()
		if message != "":
			footer_label.text = message  # until the next key press redraws the footer


# --- Tabs and rows -----------------------------------------------------------------

## Reads the player's three tuning resources. Done on every open so a player that
## got a different .tres (Inspector, test) is picked up.
func _collect_resources() -> void:
	tab_names.clear()
	tab_resources.clear()
	if player == null:
		return
	var candidates: Dictionary = {
		"Player": player.tuning,
		"Earth": player.earth_tuning,
		"Fire": player.fire_tuning,
	}
	for tab_name: String in candidates:
		var resource: Resource = candidates[tab_name]
		if resource != null:
			tab_names.append(tab_name)
			tab_resources.append(resource)
	saved_to_disk()


## Loads the .tres again, bypassing Godot's resource cache. A normal load() would
## hand back the SAME object the player holds (with our edits in it); CACHE_MODE_IGNORE
## reads the file into a brand-new object instead.
func _load_saved_copy(resource: Resource) -> Resource:
	if resource.resource_path == "" or not ResourceLoader.exists(resource.resource_path):
		return null
	return ResourceLoader.load(resource.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)


func switch_tab(direction: int) -> void:
	if tab_resources.is_empty():
		return
	_show_tab(wrapi(current_tab + direction, 0, tab_resources.size()))


## Switches to the tab with this display name ("Player", "Earth", "Fire").
func show_tab_named(tab_name: String) -> void:
	var tab_index: int = tab_names.find(tab_name)
	if tab_index >= 0:
		_show_tab(tab_index)


func _show_tab(tab_index: int) -> void:
	current_tab = tab_index
	rows = _build_rows(tab_resources[tab_index]) if tab_index < tab_resources.size() else []
	first_visible_row = 0
	selected_row = -1
	move_selection(1)  # lands on the first value row (row 0 is usually a group header)


## Turns a resource's property list into display rows. Each row is a Dictionary:
##   {kind = "group", text}                          an @export_group header
##   {kind = "value", property, component, type, hint, hint_string, label}
## `component` is "" for a plain value, or "x"/"y" for one half of a Vector2 (each
## half gets its own row so it can be stepped like a float).
func _build_rows(resource: Resource) -> Array[Dictionary]:
	var new_rows: Array[Dictionary] = []
	for property: Dictionary in resource.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			new_rows.append({"kind": "group", "text": String(property["name"])})
			continue
		# Only exported script vars: skips Resource's own fields (resource_name, script...)
		# and plain `var`s that aren't @export.
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var row: Dictionary = {
			"kind": "value",
			"property": String(property["name"]),
			"component": "",
			"type": property["type"],
			"hint": property["hint"],
			"hint_string": String(property["hint_string"]),
			"label": String(property["name"]),
		}
		if property["type"] == TYPE_VECTOR2:
			for component: String in ["x", "y"]:
				var half: Dictionary = row.duplicate()
				half["component"] = component
				half["type"] = TYPE_FLOAT
				half["label"] = "%s.%s" % [row["label"], component]
				new_rows.append(half)
		else:
			new_rows.append(row)
	# Drop group headers with no values under them, e.g. Resource's own "Resource"
	# group (its fields were skipped above).
	var kept_rows: Array[Dictionary] = []
	for row_index: int in new_rows.size():
		var is_empty_group: bool = new_rows[row_index]["kind"] == "group" 				and (row_index + 1 == new_rows.size() or new_rows[row_index + 1]["kind"] == "group")
		if not is_empty_group:
			kept_rows.append(new_rows[row_index])
	return kept_rows


# --- Selection and editing ---------------------------------------------------------

## Moves the highlight to the next value row up (-1) or down (+1), skipping group
## headers, and scrolls the window to keep it (and its group header) in view.
func move_selection(direction: int) -> void:
	var row_index: int = selected_row + direction
	while row_index >= 0 and row_index < rows.size():
		if rows[row_index]["kind"] == "value":
			selected_row = row_index
			break
		row_index += direction
	if selected_row < 0:
		_redraw()
		return
	# Show the group header right above the first value of a group, too.
	var top_wanted: int = selected_row
	if selected_row > 0 and rows[selected_row - 1]["kind"] == "group":
		top_wanted = selected_row - 1
	if top_wanted < first_visible_row:
		first_visible_row = top_wanted
	elif selected_row >= first_visible_row + VISIBLE_ROWS:
		first_visible_row = selected_row - VISIBLE_ROWS + 1
	_redraw()


## Highlights the row of this property (and Vector2 component) in the current tab.
func select_property(property_name: String, component: String = "") -> bool:
	for row_index: int in rows.size():
		var row: Dictionary = rows[row_index]
		if row["kind"] == "value" and row["property"] == property_name and row["component"] == component:
			selected_row = row_index - 1
			move_selection(1)
			return true
	return false


## Steps the selected value: direction is -1 or +1, big_step multiplies the step by 10.
## Bools flip, enums cycle, Curves and other types are read-only.
func change_selected(direction: int, big_step: bool = false) -> void:
	var row: Dictionary = _get_selected_row()
	if row.is_empty() or not _is_editable(row):
		return
	var resource: Resource = tab_resources[current_tab]
	var value: Variant = _read_row(resource, row)
	match int(row["type"]):
		TYPE_BOOL:
			value = not value
		TYPE_INT:
			if row["hint"] == PROPERTY_HINT_ENUM:
				value = _step_enum(int(value), direction, row["hint_string"])
			else:
				var int_step: int = maxi(1, roundi(_get_step(row)))
				value = _clamp_to_range(int(value) + direction * int_step * (10 if big_step else 1), row)
		TYPE_FLOAT:
			var float_step: float = _get_step(row) * (10.0 if big_step else 1.0)
			# snappedf to 1e-4 only removes float noise (0.1 + 0.2 = 0.30000000000000004).
			value = _clamp_to_range(snappedf(float(value) + direction * float_step, 0.0001), row)
	_write_row(resource, row, value)
	edited_tabs[current_tab] = true
	_redraw()


## Puts the selected value back to the one in the saved .tres.
func reset_selected() -> void:
	var row: Dictionary = _get_selected_row()
	var saved: Resource = saved_copies[current_tab] if current_tab < saved_copies.size() else null
	if row.is_empty() or saved == null or not _is_editable(row):
		return
	_write_row(tab_resources[current_tab], row, _read_row(saved, row))
	edited_tabs[current_tab] = true
	_redraw()


func _get_selected_row() -> Dictionary:
	if selected_row < 0 or selected_row >= rows.size():
		return {}
	return rows[selected_row]


func _is_editable(row: Dictionary) -> bool:
	return int(row["type"]) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]


## Reads a row's value (one component for a Vector2 half).
func _read_row(resource: Resource, row: Dictionary) -> Variant:
	var value: Variant = resource.get(row["property"])
	if row["component"] == "x":
		return (value as Vector2).x
	if row["component"] == "y":
		return (value as Vector2).y
	return value


func _write_row(resource: Resource, row: Dictionary, value: Variant) -> void:
	if row["component"] == "":
		resource.set(row["property"], value)
		return
	# Vector2 is a value type: read it, change one half, write the whole thing back.
	var vector: Vector2 = resource.get(row["property"])
	if row["component"] == "x":
		vector.x = value
	else:
		vector.y = value
	resource.set(row["property"], vector)


## The step for one press. From the @export_range hint if it gives one
## ("min,max,step"), else 1 for ints, else one tenth of the SAVED value's order of
## magnitude for floats: 90 → 1, 900 → 10, 0.65 → 0.01. Using the saved value (not
## the live one) keeps the step steady while you walk a value across 100 or 1.
func _get_step(row: Dictionary) -> float:
	if row["hint"] == PROPERTY_HINT_RANGE:
		var parts: PackedStringArray = String(row["hint_string"]).split(",")
		if parts.size() >= 3 and parts[2].is_valid_float():
			return parts[2].to_float()
	if int(row["type"]) == TYPE_INT:
		return 1.0
	var saved: Resource = saved_copies[current_tab] if current_tab < saved_copies.size() else null
	var reference: float = absf(float(_read_row(saved if saved != null else tab_resources[current_tab], row)))
	if reference < 0.0001:
		return 0.1  # a value saved as 0 has no magnitude to go by
	return clampf(pow(10.0, floorf(log(reference) / log(10.0)) - 1.0), 0.001, 100.0)


## Keeps a value inside its @export_range, unless the hint says or_greater/or_less.
func _clamp_to_range(value: Variant, row: Dictionary) -> Variant:
	if row["hint"] != PROPERTY_HINT_RANGE:
		return value
	var parts: PackedStringArray = String(row["hint_string"]).split(",")
	if parts.size() < 2:
		return value
	var lowest: float = parts[0].to_float()
	var highest: float = parts[1].to_float()
	if not parts.has("or_less"):
		value = maxf(value, lowest) if value is float else maxi(value, int(lowest))
	if not parts.has("or_greater"):
		value = minf(value, highest) if value is float else mini(value, int(highest))
	return value


## Moves an @export_enum int to the next/previous option. The hint string is
## "A,B,C" (values 0,1,2) or "A:0,B:5" (explicit values).
func _step_enum(value: int, direction: int, hint_string: String) -> int:
	var option_values: Array[int] = _enum_option_values(hint_string)
	if option_values.is_empty():
		return value
	var index: int = maxi(option_values.find(value), 0)
	return option_values[wrapi(index + direction, 0, option_values.size())]


func _enum_option_values(hint_string: String) -> Array[int]:
	var option_values: Array[int] = []
	var next_value: int = 0
	for option: String in hint_string.split(","):
		if option.contains(":"):
			next_value = option.get_slice(":", 1).to_int()
		option_values.append(next_value)
		next_value += 1
	return option_values


# --- Drawing -------------------------------------------------------------------------

func _redraw() -> void:
	var tab_texts: PackedStringArray = []
	for tab_index: int in tab_names.size():
		if tab_index == current_tab:
			tab_texts.append("[color=#ffd75e][ %s ][/color]" % tab_names[tab_index])
		else:
			tab_texts.append("[color=#8a8a8a]%s[/color]" % tab_names[tab_index])
	tabs_label.text = "Tuning   " + "  ".join(tab_texts) + "   [color=#8a8a8a]PgUp/PgDn[/color]"

	var lines: PackedStringArray = []
	var last_row: int = mini(first_visible_row + VISIBLE_ROWS, rows.size())
	for row_index: int in range(first_visible_row, last_row):
		lines.append(_format_row(rows[row_index], row_index == selected_row))
	if rows.is_empty():
		lines.append("(no tuning resource)")
	body_label.text = "\n".join(lines)

	var more: String = ""
	if first_visible_row > 0:
		more += "^"
	if last_row < rows.size():
		more += "v"
	footer_label.text = "Arrows pick/change  Shift x10  R reset  F4 save  F5 close  %s" % more


func _format_row(row: Dictionary, is_selected: bool) -> String:
	if row["kind"] == "group":
		return "[color=#7fb4ff]%s[/color]" % row["text"]
	var resource: Resource = tab_resources[current_tab]
	var value: Variant = _read_row(resource, row)
	var value_text: String
	if not _is_editable(row):
		var type_name: String = type_string(typeof(value))
		if value is Object and value != null:
			type_name = (value as Object).get_class()
		value_text = "[color=#8a8a8a](%s: %s)[/color]" % [type_name, READ_ONLY_NOTE]
	elif int(row["type"]) == TYPE_FLOAT:
		value_text = String.num(float(value), 4)
	elif row["hint"] == PROPERTY_HINT_ENUM:
		value_text = _enum_name(int(value), row["hint_string"])
	else:
		value_text = str(value)
	# * = differs from the saved .tres (F4 saves it, R puts it back).
	var saved: Resource = saved_copies[current_tab] if current_tab < saved_copies.size() else null
	var changed_mark: String = " "
	if saved != null and _is_editable(row) and _read_row(saved, row) != value:
		changed_mark = "*"
	var line: String = "%s %s  %s" % [changed_mark, row["label"], value_text]
	if is_selected:
		return "[bgcolor=#3a3f6a][color=#ffffff]>%s[/color][/bgcolor]" % line
	return " " + line


func _enum_name(value: int, hint_string: String) -> String:
	var option_values: Array[int] = _enum_option_values(hint_string)
	var options: PackedStringArray = hint_string.split(",")
	var index: int = option_values.find(value)
	return options[index].get_slice(":", 0) if index >= 0 else str(value)


func _build_panel() -> void:
	background = PanelContainer.new()
	background.position = Vector2(6, 4)
	background.custom_minimum_size = Vector2(308, 172)
	# A dark, mostly opaque box so the values read over any room.
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color(0.05, 0.05, 0.08, 0.97)
	box_style.border_color = Color(0.35, 0.35, 0.45)
	box_style.set_border_width_all(1)
	box_style.set_content_margin_all(3)
	background.add_theme_stylebox_override("panel", box_style)
	add_child(background)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 1)
	background.add_child(layout)
	tabs_label = _make_rich_label(1)
	layout.add_child(tabs_label)
	body_label = _make_rich_label(VISIBLE_ROWS)
	layout.add_child(body_label)
	footer_label = Label.new()
	footer_label.add_theme_font_size_override("font_size", 8)
	footer_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	layout.add_child(footer_label)


## RichTextLabel understands BBCode ([color], [bgcolor]) for the highlights.
func _make_rich_label(line_count: int) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("normal_font_size", 8)
	label.add_theme_constant_override("line_separation", 0)
	label.custom_minimum_size = Vector2(300, line_count * 11)
	return label

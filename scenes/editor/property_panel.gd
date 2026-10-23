class_name PropertyPanel
extends PanelContainer
## PropertyPanel: the level editor's right-hand column (Level_editor.md §7). Shows
## the settings of the selected object, or of the current room when nothing is
## selected, with a widget per setting, and reports every change.
##
## It doesn't change anything itself: it emits `property_changed`, and
## LevelEditor makes the change as an undoable action. When values change
## elsewhere (undo, redo, a drag handle), LevelEditor calls refresh().
##
## Which widget: from the property's TYPE and HINT, found in the object's
## get_property_list() (the same info Godot's own Inspector reads):
##   bool                       -> CheckBox
##   int with an enum hint      -> OptionButton (a dropdown)
##   int / float                -> SpinBox (type, arrows, or drag up/down)
##   String                     -> LineEdit (applied on Enter or leaving the field)
##   Vector2                    -> two SpinBoxes, x and y
##   Vector2 in `direction_properties` -> a DirectionPicker
## The `hint_string` gives an enum's names ("Up:0,Down:1") and a range's limits
## ("1.0,40.0") for @export_range.

## A widget changed `property` of `target` to `value`.
signal property_changed(target: Object, property: StringName, value: Variant)

const PANEL_COLOR: Color = Color(0.12, 0.12, 0.15, 0.92)
const HINT_ALPHA: float = 0.55
const FIELD_WIDTH: float = 52.0
## Limits for numbers without an @export_range: wide, the editor isn't the judge.
const NUMBER_LIMIT: float = 10000.0
const FLOAT_STEP: float = 0.5

var title_label: Label
var rows: VBoxContainer
## A last line under the settings (the editor shows an object's links there).
var footer_label: Label
## What's shown: the object (or room), and per property its widget(s) and kind.
var target: Object = null
var widgets: Dictionary = {}


func _ready() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# A ScrollContainer: a long list scrolls instead of running off the screen.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_label)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	column.add_child(rows)
	footer_label = _make_hint("")
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(footer_label)


## Shows `properties` of `new_target` under `title`. `direction_properties` get
## the 8-way picker instead of x/y fields.
func show_target(new_target: Object, title: String, properties: Array[StringName],
		direction_properties: Array[StringName] = []) -> void:
	target = new_target
	title_label.text = title
	footer_label.text = ""
	widgets = {}
	for old_row: Node in rows.get_children():
		rows.remove_child(old_row)
		old_row.queue_free()
	if target == null:
		return
	if properties.is_empty():
		rows.add_child(_make_hint("No settings."))
	for property: StringName in properties:
		var info: Dictionary = _find_property(property)
		if info.is_empty():
			continue  # the catalog names a property this object doesn't have
		rows.add_child(_make_hint(String(property).capitalize()))
		rows.add_child(_make_widget(property, info, direction_properties.has(property)))
	refresh()


func set_footer(text: String) -> void:
	footer_label.text = text


## Re-reads every shown value into its widget, without emitting anything.
func refresh() -> void:
	if target == null or not is_instance_valid(target):
		return
	for property: StringName in widgets:
		var widget: Dictionary = widgets[property]
		var value: Variant = target.get(property)
		match widget["kind"]:
			"bool":
				(widget["control"] as CheckBox).set_pressed_no_signal(value)
			"enum":
				var option_button: OptionButton = widget["control"]
				option_button.select(option_button.get_item_index(int(value)))
			"number":
				(widget["control"] as SpinBox).set_value_no_signal(value)
			"text":
				var line_edit: LineEdit = widget["control"]
				if not line_edit.has_focus():  # don't overwrite what's being typed
					line_edit.text = value
			"vector":
				(widget["x"] as SpinBox).set_value_no_signal((value as Vector2).x)
				(widget["y"] as SpinBox).set_value_no_signal((value as Vector2).y)
			"direction":
				(widget["control"] as DirectionPicker).set_direction(value)


func _find_property(property: StringName) -> Dictionary:
	for info: Dictionary in target.get_property_list():
		if info["name"] == property:
			return info
	return {}


func _make_widget(property: StringName, info: Dictionary, is_direction: bool) -> Control:
	var emit: Callable = func(value: Variant) -> void: property_changed.emit(target, property, value)
	match info["type"]:
		TYPE_BOOL:
			var check_box: CheckBox = CheckBox.new()
			check_box.text = "on"
			check_box.focus_mode = Control.FOCUS_NONE
			check_box.toggled.connect(emit)
			widgets[property] = {"kind": "bool", "control": check_box}
			return check_box
		TYPE_INT when info["hint"] == PROPERTY_HINT_ENUM:
			var option_button: OptionButton = OptionButton.new()
			option_button.focus_mode = Control.FOCUS_NONE
			# hint_string "Up:0,Down:1,...": name and value per choice.
			for choice: String in String(info["hint_string"]).split(","):
				var parts: PackedStringArray = choice.split(":")
				var value: int = int(parts[1]) if parts.size() > 1 else option_button.item_count
				option_button.add_item(parts[0].capitalize(), value)
			option_button.item_selected.connect(func(index: int) -> void: emit.call(option_button.get_item_id(index)))
			widgets[property] = {"kind": "enum", "control": option_button}
			return option_button
		TYPE_INT, TYPE_FLOAT:
			var is_int: bool = info["type"] == TYPE_INT
			var spin_box: SpinBox = _make_spin_box(is_int, info)
			spin_box.value_changed.connect(func(value: float) -> void:
				# An int setting must get an int: the SpinBox always reports a float.
				if is_int:
					emit.call(int(value))
				else:
					emit.call(value))
			widgets[property] = {"kind": "number", "control": spin_box}
			return spin_box
		TYPE_STRING:
			var line_edit: LineEdit = LineEdit.new()
			line_edit.text_submitted.connect(func(text: String) -> void:
				emit.call(text)
				line_edit.release_focus())
			line_edit.focus_exited.connect(func() -> void:
				if is_instance_valid(target) and line_edit.text != target.get(property):
					emit.call(line_edit.text))
			widgets[property] = {"kind": "text", "control": line_edit}
			return line_edit
		TYPE_VECTOR2 when is_direction:
			var picker: DirectionPicker = DirectionPicker.new()
			picker.direction_picked.connect(emit)
			widgets[property] = {"kind": "direction", "control": picker}
			return picker
		TYPE_VECTOR2:
			var row: HBoxContainer = HBoxContainer.new()
			var x_box: SpinBox = _make_spin_box(false, {})
			var y_box: SpinBox = _make_spin_box(false, {})
			x_box.step = 1.0
			y_box.step = 1.0
			var emit_vector: Callable = func(_value: float) -> void: emit.call(Vector2(x_box.value, y_box.value))
			x_box.value_changed.connect(emit_vector)
			y_box.value_changed.connect(emit_vector)
			row.add_child(x_box)
			row.add_child(y_box)
			widgets[property] = {"kind": "vector", "x": x_box, "y": y_box}
			return row
	return _make_hint("(can't edit this kind of setting here)")


## A SpinBox; @export_range's "min,max" hint sets its limits.
func _make_spin_box(is_int: bool, info: Dictionary) -> SpinBox:
	var spin_box: SpinBox = SpinBox.new()
	spin_box.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	spin_box.step = 1.0 if is_int else FLOAT_STEP
	spin_box.min_value = -NUMBER_LIMIT
	spin_box.max_value = NUMBER_LIMIT
	if not info.is_empty() and info["hint"] == PROPERTY_HINT_RANGE:
		var limits: PackedStringArray = String(info["hint_string"]).split(",")
		spin_box.min_value = float(limits[0])
		spin_box.max_value = float(limits[1])
	return spin_box


func _make_hint(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.modulate = Color(1.0, 1.0, 1.0, HINT_ALPHA)
	return label

class_name PromptPanel
extends ColorRect
## PromptPanel: a small "are you sure?" / "type a name" box drawn over the screen.
## Used by the level library and the level editor.
##
## How to use: add it as a child of a full-screen Control (or CanvasLayer), then
##   prompt.ask("Name of the new level:", [["OK", on_ok]], "New level")
##   prompt.ask("Unsaved changes.", [["Save", on_save], ["Leave", on_leave]])
## Each choice is [button text, Callable]; the Callable gets the text field's text
## (a String, "" when there's no text field). A Cancel button is always added last.
## Enter in the text field picks the first choice; Esc cancels.
##
## It's a full-screen dim ColorRect itself: mouse_filter STOP keeps clicks from
## reaching whatever is underneath while it's open. Hidden when not asking.

## Emitted when the prompt closes (a choice was picked or it was cancelled), so the
## owner can give keyboard focus back to its own controls.
signal closed

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const PANEL_COLOR: Color = Color(0.16, 0.16, 0.2)
const TEXT_FIELD_WIDTH: float = 160.0

## Font size of the question, field and buttons. 8 suits the game's 320x180
## screens; the editor (640x360) still uses 8, drawn twice as sharp.
@export var font_size: int = 8

var question_label: Label
var text_field: LineEdit
var button_row: HBoxContainer
## The current choices, as passed to ask().
var choices: Array = []


func _ready() -> void:
	color = DIM_COLOR
	# ..._and_offsets_: also resets the offsets, so it fills the parent even when
	# the parent already has a size (plain set_anchors_preset keeps the old rect).
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

	question_label = Label.new()
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.add_theme_font_size_override("font_size", font_size)
	column.add_child(question_label)
	text_field = LineEdit.new()
	text_field.custom_minimum_size = Vector2(TEXT_FIELD_WIDTH, 0)
	text_field.add_theme_font_size_override("font_size", font_size)
	# text_submitted: Enter pressed inside the LineEdit.
	text_field.text_submitted.connect(func(_text: String) -> void: _pick(0))
	column.add_child(text_field)
	button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 4)
	column.add_child(button_row)


## Shows the prompt. `text_field_default` = null means no text field.
func ask(question: String, new_choices: Array, text_field_default: Variant = null) -> void:
	question_label.text = question
	choices = new_choices
	for old_button: Node in button_row.get_children():
		button_row.remove_child(old_button)  # gone from the row now, freed at frame end
		old_button.queue_free()
	for index: int in choices.size():
		button_row.add_child(_make_button(String(choices[index][0]), _pick.bind(index)))
	var cancel_button: Button = _make_button("Cancel", close)
	button_row.add_child(cancel_button)

	var has_text_field: bool = text_field_default != null
	text_field.visible = has_text_field
	text_field.text = String(text_field_default) if has_text_field else ""
	visible = true
	if has_text_field:
		text_field.grab_focus()
		text_field.select_all()
	else:
		(button_row.get_child(0) as Button).grab_focus()  # the first choice


## _input runs BEFORE the UI gets the event, so Esc reaches us even while the
## LineEdit has focus (it would otherwise use Esc itself).
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Hides the prompt without picking anything (Cancel / Esc).
func close() -> void:
	if not visible:
		return
	visible = false
	choices = []
	closed.emit()


func _pick(index: int) -> void:
	var on_pick: Callable = choices[index][1]
	var typed_text: String = text_field.text if text_field.visible else ""
	close()
	on_pick.call(typed_text)


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(on_pressed)
	return button

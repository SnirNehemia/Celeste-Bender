class_name TouchDrawing
extends Node2D
## Draws the touch controls: see-through outlined buttons (filled while pressed)
## with a short label, and the d-pad ring with its four arrows and the thumb's knob.
## Pure drawing: TouchControls (autoload/touch_controls.gd) owns the state, fills
## the fields below every frame and calls queue_redraw().
##
## _draw() is Godot's custom drawing callback: it runs after queue_redraw(), and
## the draw_* calls inside it paint this node's picture until the next redraw.

## Every button to draw (grid and top-right ones).
var buttons: Array[TouchControlButton] = []
## Actions held right now (keys), to fill pressed buttons and d-pad arrows.
var held_actions: Dictionary = {}
var tuning: TouchTuning = null
var dpad_center: Vector2 = Vector2.ZERO
## Where the d-pad thumb is, relative to the center; only drawn when has_knob.
var knob_offset: Vector2 = Vector2.ZERO
var has_knob: bool = false

## Arrow tip distance from the d-pad center, as a share of its radius.
const ARROW_TIP_SHARE: float = 0.85
## Arrow size (half its base and its length), in game pixels.
const ARROW_SIZE: float = 5.0
## Knob radius, as a share of the d-pad's radius.
const KNOB_SHARE: float = 0.3
## The four arrows: action, direction.
const ARROWS: Array = [
	[&"move_right", Vector2.RIGHT], [&"move_left", Vector2.LEFT],
	[&"move_down", Vector2.DOWN], [&"move_up", Vector2.UP],
]


func _draw() -> void:
	if tuning == null:
		return
	for button: TouchControlButton in buttons:
		_draw_button(button)
	_draw_dpad()


func _draw_button(button: TouchControlButton) -> void:
	# The full-screen button has no action; it never shows as held.
	var is_held: bool = button.action != &"" and held_actions.has(button.action)
	if is_held:
		draw_rect(button.rect, Color(button.color, tuning.pressed_alpha), true)
	draw_rect(button.rect, Color(button.color, tuning.idle_alpha), false, 1.0)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = tuning.label_font_size
	var text_size: Vector2 = font.get_string_size(button.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	# draw_string's position is the text's baseline start; ascent - half the height
	# centers it vertically. Rounded: text between pixels smears.
	var baseline: Vector2 = button.rect.get_center() + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	var label_alpha: float = 1.0 if is_held else minf(tuning.idle_alpha * 2.0, 1.0)
	draw_string(font, baseline.round(), button.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Color.WHITE, label_alpha))


func _draw_dpad() -> void:
	var ring_color: Color = Color(Color.WHITE, tuning.idle_alpha)
	draw_arc(dpad_center, tuning.dpad_radius, 0.0, TAU, 48, ring_color, 1.0)
	for arrow: Array in ARROWS:
		var direction: Vector2 = arrow[1]
		var tip: Vector2 = dpad_center + direction * tuning.dpad_radius * ARROW_TIP_SHARE
		var base_center: Vector2 = tip - direction * ARROW_SIZE
		var side: Vector2 = direction.orthogonal() * ARROW_SIZE
		var triangle: PackedVector2Array = PackedVector2Array([tip, base_center + side, base_center - side])
		var alpha: float = 0.9 if held_actions.has(arrow[0]) else tuning.idle_alpha
		draw_colored_polygon(triangle, Color(Color.WHITE, alpha))
	if has_knob:
		# The knob stays inside the ring even when the thumb slides past it.
		var knob: Vector2 = dpad_center + knob_offset.limit_length(tuning.dpad_radius)
		draw_circle(knob, tuning.dpad_radius * KNOB_SHARE, Color(Color.WHITE, tuning.pressed_alpha))

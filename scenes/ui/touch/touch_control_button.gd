class_name TouchControlButton
extends RefCounted
## One on-screen touch button: which input action it presses, what it shows, where
## it is. Plain data (RefCounted = an object freed once nothing refers to it, no node):
## TouchLayout makes them, TouchControls (autoload/touch_controls.gd) hit-tests them,
## TouchDrawing draws them.

## The InputMap action the button presses (`jump`, `gust`...). Empty for the
## full-screen button, which TouchControls handles itself.
var action: StringName = &""
## Short text drawn on the button.
var label: String = ""
## Element color (outline, fill while pressed).
var color: Color = Color.WHITE
## Where the button is drawn, in game pixels.
var rect: Rect2 = Rect2()
## Where a touch counts for it: `rect` grown into the gaps between buttons and past
## the screen's edges (the thumb often lands in the black bars beside the game).
var hit_rect: Rect2 = Rect2()


func _init(button_action: StringName, button_label: String, button_color: Color) -> void:
	action = button_action
	label = button_label
	color = button_color

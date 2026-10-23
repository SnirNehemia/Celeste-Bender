class_name DirectionPicker
extends Control
## DirectionPicker: a 3x3 grid of arrows for choosing one of 8 directions, used
## by the property panel for direction settings like a wind zone's `wind_direction`
## (Level_editor.md §7). Click a cell; the middle cell does nothing.
##
## It draws itself in _draw() and reads clicks in _gui_input(): a Control's own
## input callback, which gets mouse events inside its rectangle before
## _unhandled_input() does.

## A direction was clicked: a unit vector (diagonals are normalized too).
signal direction_picked(direction: Vector2)

const CELL_SIZE: float = 14.0
const ARROW_LENGTH: float = 9.0
const ARROW_HEAD: float = 3.0
const CELL_COLOR: Color = Color(0.2, 0.2, 0.25)
const CHOSEN_COLOR: Color = Color(0.35, 0.55, 0.8)
const ARROW_COLOR: Color = Color(0.9, 0.9, 0.95)

## The direction shown as chosen.
var direction: Vector2 = Vector2.UP


func _init() -> void:
	custom_minimum_size = Vector2.ONE * CELL_SIZE * 3.0
	mouse_filter = Control.MOUSE_FILTER_STOP


## Shows `new_direction` as chosen (the nearest of the 8), without emitting.
func set_direction(new_direction: Vector2) -> void:
	direction = new_direction
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell: Vector2i = Vector2i((click.position / CELL_SIZE).floor()).clamp(Vector2i.ZERO, Vector2i(2, 2))
	var picked: Vector2 = Vector2(cell - Vector2i.ONE)  # -1, 0 or 1 on each axis
	if picked == Vector2.ZERO:
		return
	direction = picked.normalized()
	queue_redraw()
	direction_picked.emit(direction)
	accept_event()  # handled here: the level behind the panel doesn't see it


func _draw() -> void:
	# The chosen cell: the one whose direction is nearest to `direction`.
	var chosen: Vector2i = Vector2i(direction.normalized().round()) + Vector2i.ONE
	for row: int in 3:
		for column: int in 3:
			var cell_rect: Rect2 = Rect2(Vector2(column, row) * CELL_SIZE, Vector2.ONE * CELL_SIZE).grow(-1.0)
			draw_rect(cell_rect, CHOSEN_COLOR if Vector2i(column, row) == chosen else CELL_COLOR)
			var cell_direction: Vector2 = Vector2(column - 1, row - 1).normalized()
			if cell_direction != Vector2.ZERO:
				_draw_arrow(cell_rect.get_center(), cell_direction)


func _draw_arrow(center: Vector2, arrow_direction: Vector2) -> void:
	var tip: Vector2 = center + arrow_direction * ARROW_LENGTH / 2.0
	draw_line(center - arrow_direction * ARROW_LENGTH / 2.0, tip, ARROW_COLOR, 1.0)
	draw_line(tip, tip - arrow_direction.rotated(PI / 5.0) * ARROW_HEAD, ARROW_COLOR, 1.0)
	draw_line(tip, tip - arrow_direction.rotated(-PI / 5.0) * ARROW_HEAD, ARROW_COLOR, 1.0)

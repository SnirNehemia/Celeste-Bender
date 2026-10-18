@tool
class_name Goal
extends Area2D
## Goal: the green exit at the end of the last room (GAME_DESIGN.md §2: checkpoint /
## room exit = green). Touching it ends the run: GameState.finish_run() stops the
## timer and emits `run_finished`, and the EndScreen shows deaths and time.
##
## Place the node at the TOP-LEFT of the goal area and set `goal_size`.
## The goal doesn't know about the end screen: it only tells GameState, and the end
## screen listens to GameState. Either can be swapped out without touching the other.
##
## Physics: an Area2D on no layer that watches layer 2 ("player").

const FILL_COLOR: Color = Color(0.3, 0.85, 0.4, 0.25)
const EDGE_COLOR: Color = Color(0.3, 0.85, 0.4, 0.8)
const FLAG_COLOR: Color = Color(0.4, 0.95, 0.5)

## Size of the goal area, px.
@export var goal_size: Vector2 = Vector2(24, 32):
	set(value):
		goal_size = value
		_resize_shape()
		queue_redraw()

var collision_shape_node: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # bit value of layer 2, "player"
	collision_shape_node = CollisionShape2D.new()
	collision_shape_node.shape = RectangleShape2D.new()
	add_child(collision_shape_node)
	_resize_shape()
	if Engine.is_editor_hint():
		return
	# body_entered is a built-in Area2D signal: fires when a body starts overlapping.
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not GameState.is_run_finished:
		FX.play_sfx(&"goal")
		GameState.finish_run()


func _resize_shape() -> void:
	if collision_shape_node == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(collision_shape_node.shape as RectangleShape2D).size = goal_size
	collision_shape_node.position = goal_size / 2.0  # shapes are positioned by center


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, goal_size), FILL_COLOR)
	draw_rect(Rect2(Vector2.ZERO, goal_size).grow(-0.5), EDGE_COLOR, false, 1.0)
	# A little flag on a pole, standing on the bottom edge, so it reads as "the end".
	var pole_base: Vector2 = Vector2(goal_size.x / 2.0, goal_size.y)
	var pole_top: Vector2 = pole_base - Vector2(0.0, minf(goal_size.y - 4.0, 18.0))
	draw_line(pole_base, pole_top, EDGE_COLOR, 1.0)
	draw_colored_polygon(PackedVector2Array([
		pole_top, pole_top + Vector2(7.0, 2.5), pole_top + Vector2(0.0, 5.0),
	]), FLAG_COLOR)

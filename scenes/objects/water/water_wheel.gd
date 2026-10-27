class_name WaterWheel
extends Node2D
## WaterWheel, the Stage W2 TEST STUB (Water_bending.md §14 W2: "the waterwheel test
## stub turns"): a wheel that falling water turns. Only in the Water test rooms,
## not in the editor's palette yet: the real waterwheel (a switch, §8.4) comes in
## Stage W9.
##
## Each frame it asks its room's WaterWorld how much water is falling through the
## wheel's right half (get_flow_through), and its spin speed eases toward that
## times `spin_per_flow`; with no water it slows down (`spin_friction`). Positive
## spin = clockwise (water pushing the right side down).

const WHEEL_COLOR: Color = Color("#7A5233")
const SPOKE_COLOR: Color = Color("#4A3020")
const HUB_COLOR: Color = Color("#3A2416")

## The wheel's radius, px.
@export var radius: float = 12.0
## Spin (radians/s) per unit of flow (px²·px/s of falling water).
@export var spin_per_flow: float = 0.0004
## How fast the spin eases toward what the water gives, per second.
@export var spin_response: float = 2.0
## Spin lost per second with no water, radians/s².
@export var spin_friction: float = 1.5

var world: WaterWorld
## Current spin, radians/s (tests read it), and the wheel's angle.
var angular_speed: float = 0.0
var angle: float = 0.0


func _physics_process(delta: float) -> void:
	if world == null:
		world = WaterWorld.find_at(get_tree(), global_position)
		if world == null:
			return
	if GameState.current_room != world.room:
		return
	# The right half of the wheel: water falling there turns it clockwise.
	var paddles: Rect2 = Rect2(world.to_local(global_position) + Vector2(0.0, -radius), Vector2(radius, radius * 2.0))
	var flow: float = world.get_flow_through(paddles)
	var wanted: float = flow * spin_per_flow
	if wanted > angular_speed:
		angular_speed = lerpf(angular_speed, wanted, minf(1.0, spin_response * delta))
	else:
		angular_speed = move_toward(angular_speed, wanted, spin_friction * delta)
	angle = fmod(angle + angular_speed * delta, TAU)
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, WHEEL_COLOR, 2.0)
	for spoke: int in 6:
		var direction: Vector2 = Vector2.from_angle(angle + spoke * TAU / 6.0)
		draw_line(Vector2.ZERO, direction * radius, SPOKE_COLOR, 1.0)
		# A paddle at each spoke's end.
		draw_line(direction * (radius - 3.0), direction * (radius + 2.0), WHEEL_COLOR, 2.0)
	draw_circle(Vector2.ZERO, 2.0, HUB_COLOR)

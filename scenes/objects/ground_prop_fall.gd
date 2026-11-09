class_name GroundPropFall
extends Node
## GroundPropFall: drops PROPS (braziers, fire diamonds: GroundProps) whose crumbling
## ground just broke away, with gravity, until each lands on the floor below
## (FallProbe). Made by CrumblePatches.break_patches; one per broken patch that had
## props on it. It frees itself when they've all landed, or when the room resets
## (Room.RESETTABLE_GROUP: the layer's reset puts the props back home).
##
## The props have no physics body of their own, so this moves them by hand: each
## frame the fall speed grows by the gravity, and a ray from the prop's foot says how
## far the floor is; a prop that would pass it stops on it.

## The fall's gravity and top speed: the falling block's (WaterTuning), which are a
## crate's, so a brazier and a crate dropped together land together.
const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")
## A prop that falls this far without landing (into a pit) stops falling, px.
const MAX_FALL_DISTANCE: float = 400.0

var props: Array[Node2D] = []
var fall_speeds: PackedFloat32Array = PackedFloat32Array()
var fallen_distances: PackedFloat32Array = PackedFloat32Array()
var is_stopped: bool = false


## Starts `props` falling (nothing if the list is empty).
static func spawn(layer: Node, props_to_drop: Array[Node2D]) -> void:
	if props_to_drop.is_empty():
		return
	var fall: GroundPropFall = GroundPropFall.new()
	fall.name = "GroundPropFall"
	for prop: Node2D in props_to_drop:
		GroundProps.remember_home(prop)
		fall.props.append(prop)
	fall.fall_speeds.resize(props_to_drop.size())
	fall.fall_speeds.fill(0.0)
	fall.fallen_distances.resize(props_to_drop.size())
	fall.fallen_distances.fill(0.0)
	layer.add_child(fall)


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)


func _physics_process(delta: float) -> void:
	if is_stopped:
		return
	var still_falling: bool = false
	for index: int in props.size():
		var prop: Node2D = props[index]
		if fall_speeds[index] < 0.0 or not is_instance_valid(prop):
			continue  # landed (speed -1) or gone
		fall_speeds[index] = minf(fall_speeds[index] + WATER_TUNING.falling_block_gravity * delta,
			WATER_TUNING.falling_block_max_speed)
		var step: float = fall_speeds[index] * delta
		var floor_distance: float = FallProbe.find_floor(prop, GroundProps.get_foot(prop), step + 0.5)
		if floor_distance >= 0.0:
			prop.global_position.y += floor_distance
			fall_speeds[index] = -1.0  # landed
			continue
		prop.global_position.y += step
		fallen_distances[index] += step
		if fallen_distances[index] > MAX_FALL_DISTANCE:
			fall_speeds[index] = -1.0
			continue
		still_falling = true
	if not still_falling:
		queue_free()


## Room reset: the props go home (the layer's reset does that); this stops.
func reset() -> void:
	is_stopped = true
	queue_free()

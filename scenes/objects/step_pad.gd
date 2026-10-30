@tool
class_name StepPad
extends Switch
## Step pad: a switch the PLAYER turns on by standing on it. Unlike a pressure plate
## (which wants a heavy crate) it stays on once stepped on, until death or R, so a
## door linked to several pads (link mode ALL) opens after you have visited every
## platform they sit on.
##
## Place the node ON the floor surface, at the CENTER of the pad (like a pressure
## plate). One tile wide by default; `pad_width` changes it (the editor's width handle).
##
## Detection: a thin Area2D just above the floor looks at physics layer 2 ("player").
## Flying over it does nothing: you have to be on it. It joins the room's reset group,
## so death or R switches it off again (and the door closes).

## Not in the §2 color key: tan when waiting, the "go" green once stepped on.
const PAD_COLOR_OFF: Color = Color(0.7, 0.56, 0.36)
const PAD_COLOR_ON: Color = Color(0.4, 0.95, 0.5)
const PAD_BASE_COLOR: Color = Color(0.4, 0.32, 0.2)
## Drawn height above the floor, px.
const PAD_HEIGHT: float = 2.0
## Height of the sensor box above the floor, px: only a player resting on the pad counts.
const SENSOR_HEIGHT: float = 4.0

## Width of the pad, px (8 = one tile).
@export var pad_width: float = 8.0:
	set(value):
		pad_width = value
		_resize_sensor()
		queue_redraw()

var sensor: Area2D
var sensor_shape_node: CollisionShape2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(Room.RESETTABLE_GROUP)
	sensor = Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2  # bit value of layer 2, "player"
	sensor.monitorable = false
	sensor_shape_node = CollisionShape2D.new()
	sensor_shape_node.shape = RectangleShape2D.new()
	sensor.add_child(sensor_shape_node)
	add_child(sensor)
	_resize_sensor()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or is_on():
		return  # once stepped on it stays on
	if not sensor.get_overlapping_bodies().is_empty():
		set_on(true)


## Called by Room.reset_objects() (death or R): waiting again.
func reset() -> void:
	set_on(false)


func _resize_sensor() -> void:
	if sensor_shape_node == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(sensor_shape_node.shape as RectangleShape2D).size = Vector2(pad_width - 2.0, SENSOR_HEIGHT)
	sensor_shape_node.position = Vector2(0.0, -SENSOR_HEIGHT / 2.0)


func _draw() -> void:
	var color: Color = PAD_COLOR_ON if is_on() else PAD_COLOR_OFF
	var half_width: float = pad_width / 2.0
	draw_rect(Rect2(-half_width, -PAD_HEIGHT, pad_width, PAD_HEIGHT), color)
	draw_rect(Rect2(-half_width, -1.0, pad_width, 1.0), PAD_BASE_COLOR)

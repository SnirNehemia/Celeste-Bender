@tool
class_name PressurePlate
extends Switch
## Pressure plate (GAME_DESIGN.md §6): ON while something heavy sits on it.
##
## Place the node ON the floor surface, at the CENTER of the plate (like the
## player, whose origin is at the feet). The plate is drawn as a thin slab
## sticking up from the floor; it sinks and turns green while pressed.
##
## "Heavy" = any body in the group "heavy" (HEAVY_GROUP). Crates join it. The
## player deliberately does NOT: if standing on the plate counted, a "move the
## crate onto the plate" puzzle would be pointless.
##
## Detection: an Area2D child (a thin box just above the floor) looks at physics
## layer 1 ("world"), where crates live. Every physics frame it checks the bodies
## overlapping it. The plate isn't solid: crates and the player stand on the
## floor underneath, the plate is only a sensor plus a drawing.
##
## Doors listen to the `switched` signal it inherits from Switch.

## The group a body must be in to press plates.
const HEAVY_GROUP: StringName = &"heavy"

## Not in the §2 color key: tan when off, the "go" green when pressed.
const PLATE_COLOR_OFF: Color = Color(0.7, 0.56, 0.36)
const PLATE_COLOR_ON: Color = Color(0.4, 0.95, 0.5)
## Darker line along the bottom so the plate reads as separate from the floor.
const PLATE_BASE_COLOR: Color = Color(0.4, 0.32, 0.2)
## Drawn height above the floor, px: raised when free, nearly flush when pressed.
const RAISED_HEIGHT: float = 3.0
const PRESSED_HEIGHT: float = 1.0
## Height of the sensor box above the floor, px. Small, so only things actually
## resting on the plate count, not things flying over it.
const SENSOR_HEIGHT: float = 4.0

## Width of the plate, px. The setter resizes the sensor when edited in the Inspector.
@export var plate_width: float = 24.0:
	set(value):
		plate_width = value
		_resize_sensor()
		queue_redraw()

var sensor: Area2D
var sensor_shape_node: CollisionShape2D


func _ready() -> void:
	sensor = Area2D.new()
	sensor.collision_layer = 0  # nothing needs to find the sensor itself
	sensor.collision_mask = 1   # bit value of layer 1, "world" (crates)
	sensor.monitorable = false
	sensor_shape_node = CollisionShape2D.new()
	sensor_shape_node.shape = RectangleShape2D.new()
	sensor.add_child(sensor_shape_node)
	add_child(sensor)
	_resize_sensor()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Re-checked every frame (not only on body_entered/exited) so the plate is
	# always right even after a crate is teleported back by a room reset.
	var is_pressed: bool = false
	for body: Node2D in sensor.get_overlapping_bodies():
		if body.is_in_group(HEAVY_GROUP):
			is_pressed = true
			break
	set_on(is_pressed)  # only emits `switched` if it changed


## The sensor box: the plate's width (1 px in from each end, so a crate merely
## touching the plate's edge doesn't count) and SENSOR_HEIGHT tall, sitting on the floor.
func _resize_sensor() -> void:
	if sensor_shape_node == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(sensor_shape_node.shape as RectangleShape2D).size = Vector2(plate_width - 2.0, SENSOR_HEIGHT)
	# CollisionShape2D is positioned by its center; y is negative = above the floor.
	sensor_shape_node.position = Vector2(0.0, -SENSOR_HEIGHT / 2.0)


func _draw() -> void:
	var height: float = PRESSED_HEIGHT if is_on() else RAISED_HEIGHT
	var color: Color = PLATE_COLOR_ON if is_on() else PLATE_COLOR_OFF
	var half_width: float = plate_width / 2.0
	draw_rect(Rect2(-half_width, -height, plate_width, height), color)
	draw_rect(Rect2(-half_width, -1.0, plate_width, 1.0), PLATE_BASE_COLOR)

@tool
class_name StepPad
extends Switch
## Step pad: a switch the PLAYER turns on by standing on it (a pressure plate wants
## a heavy crate). Two kinds (`stays_on`, a checkbox in the editor's panel):
##   - STAYS ON (the default): once stepped on it stays on, until death or R, so a
##     door linked to several pads (link mode ALL) opens after you have visited
##     every platform they sit on.
##   - HOLD (stays_on off): on only while you stand on it, off when you step off.
##     Each landing turns it on again: a rail platform's forward or backward
##     switch that works every time, or a door held open while you wait on it.
##     Drawn with notches at its ends, like a button, so the two read apart.
##   - TIMED (on_seconds above 0; the palette's "Timed step pad"): on while you
##     stand on it and for on_seconds after you step off, then off again: a door to
##     race to. Stepping on it again refills the time. A bright bar on the pad
##     shrinks as the time runs out. `stays_on` is ignored then.
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

## On for good once stepped on (true), or only while the player stands on it.
@export var stays_on: bool = true:
	set(value):
		stays_on = value
		queue_redraw()  # the hold pad's notches
## Timed pad: seconds it stays on after you step off (0 = not timed, see the header).
@export var on_seconds: float = 0.0:
	set(value):
		on_seconds = maxf(value, 0.0)
		queue_redraw()
## Width of the pad, px (8 = one tile).
@export var pad_width: float = 8.0:
	set(value):
		pad_width = value
		_resize_sensor()
		queue_redraw()

## Physics frames after a reset during which the sensor isn't trusted.
const RESET_GRACE_FRAMES: int = 3
var reset_grace_left: int = 0
## Timed pad: seconds left before it switches off (refilled while stood on).
var on_seconds_left: float = 0.0
## The timed pad's shrinking bar (not in the §2 color key): near white.
const TIMER_BAR_COLOR: Color = Color(1.0, 1.0, 0.85)
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


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if reset_grace_left > 0:
		# Just reset: the sensor may still list the player from before (overlaps
		# refresh a frame late), which would switch it straight back on.
		reset_grace_left -= 1
		return
	if on_seconds > 0.0:
		# Timed: full while stood on, then it runs down (game time, so slow motion
		# and the assist game speed slow the countdown with everything else).
		if not sensor.get_overlapping_bodies().is_empty():
			on_seconds_left = on_seconds
		else:
			on_seconds_left = maxf(on_seconds_left - delta, 0.0)
		set_on(on_seconds_left > 0.0)
		queue_redraw()  # the bar
		return
	if stays_on:
		if not is_on() and not sensor.get_overlapping_bodies().is_empty():
			set_on(true)  # and it stays on
		return
	# Hold: on exactly while someone stands on it (set_on only signals changes).
	set_on(not sensor.get_overlapping_bodies().is_empty())


## Called by Room.reset_objects() (death or R): waiting again.
func reset() -> void:
	set_on(false)
	on_seconds_left = 0.0
	reset_grace_left = RESET_GRACE_FRAMES


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
	if on_seconds > 0.0:
		# A timed pad: a clock mark in the middle while waiting (and in the editor),
		# and the time left as a bar that shrinks toward the middle.
		draw_rect(Rect2(-0.5, -PAD_HEIGHT - 2.0, 1.0, 2.0), PAD_BASE_COLOR)
		if on_seconds_left > 0.0:
			var bar_width: float = maxf(roundf(pad_width * on_seconds_left / on_seconds), 1.0)
			draw_rect(Rect2(-bar_width / 2.0, -PAD_HEIGHT, bar_width, 1.0), TIMER_BAR_COLOR)
	elif not stays_on:
		# A hold pad: notches at both ends, so it reads as a button you hold down.
		draw_rect(Rect2(-half_width, -PAD_HEIGHT, 1.0, PAD_HEIGHT - 1.0), PAD_BASE_COLOR)
		draw_rect(Rect2(half_width - 1.0, -PAD_HEIGHT, 1.0, PAD_HEIGHT - 1.0), PAD_BASE_COLOR)

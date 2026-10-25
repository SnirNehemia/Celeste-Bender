@tool
class_name Windmill
extends Switch
## Windmill (GAME_DESIGN.md §5.3, §6): gust it and it spins for `spin_time` seconds.
## While spinning it is ON, so a linked door stays open. A new gust restarts the timer.
##
## Place the node at the center of the hub. A post is drawn straight down from it
## (`post_length` px), so put the hub that far above the floor for it to "stand".
##
## How the gust finds it (the Pushable contract, scenes/objects/pushable.gd):
##   1. this node joins the "pushable" group
##   2. it has receive_gust(direction, strength)
##   3. a child Area2D on physics layer 4 ("pushable") is what the gust's shape
##      query actually touches; Pushable.find_pushable() then checks its parent (us)
##
## Readability: a thin ring around the hub shrinks as the time runs out, and the
## blades slow down over the last `slow_down_time` seconds, so you can see when the
## door is about to close.

## Yellow, per the color key (GAME_DESIGN.md §2). The post is a darker yellow.
const BLADE_COLOR: Color = Color(0.95, 0.8, 0.2)
const POST_COLOR: Color = Color(0.55, 0.45, 0.15)
const TIMER_RING_COLOR: Color = Color(1.0, 0.95, 0.6, 0.8)
const BLADE_COUNT: int = 4
## Blade length from the hub, and half of the blade's width at its tip, px.
const BLADE_LENGTH: float = 9.0
const BLADE_TIP_HALF_WIDTH: float = 2.5
## Radius of the gust hitbox around the hub, px. A bit bigger than the blades:
## aiming at a small spinning thing should be forgiving.
const HIT_RADIUS: float = 11.0

## How long one gust keeps it spinning (and the linked door open), seconds.
@export var spin_time: float = 4.0
## Blade speed while spinning, degrees per second.
@export var max_spin_speed_degrees: float = 900.0
## Over this many final seconds the blades slow down to a stop, as a warning.
@export var slow_down_time: float = 1.0
## Length of the post drawn below the hub, px. 0 = no post (e.g. on a wall).
@export var post_length: float = 28.0:
	set(value):
		post_length = value
		queue_redraw()

## Seconds of spinning left. > 0 means ON.
var spin_remaining: float = 0.0
## +1 clockwise, -1 counter-clockwise (picked from the gust's direction, for looks).
var spin_direction: float = 1.0
## Current blade rotation, radians.
var blade_angle: float = 0.0


func _ready() -> void:
	var hit_area: Area2D = Area2D.new()
	hit_area.collision_layer = 8  # bit value of layer 4, "pushable"
	hit_area.collision_mask = 0   # it doesn't need to detect anything itself
	hit_area.monitoring = false
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = HIT_RADIUS
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = circle
	hit_area.add_child(hitbox)
	add_child(hit_area)
	if Engine.is_editor_hint():
		return
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)


## The Pushable contract: called by the gust when it hits us.
## The strength doesn't matter: any gust spins it fully.
func receive_gust(direction: Vector2, _strength: float) -> void:
	spin_remaining = spin_time
	# Air blowing right spins it clockwise, left counter-clockwise. Purely visual.
	spin_direction = -1.0 if direction.x < 0.0 else 1.0
	set_on(true)


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	spin_remaining = 0.0
	set_on(false)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or spin_remaining <= 0.0:
		return
	spin_remaining = maxf(spin_remaining - delta, 0.0)
	if spin_remaining == 0.0:
		set_on(false)
	# Full speed until the last slow_down_time seconds, then a linear ramp to 0.
	# clampf keeps the ratio in 0..1 (and avoids dividing by 0 if slow_down_time is 0).
	var speed_ratio: float = clampf(spin_remaining / maxf(slow_down_time, 0.001), 0.0, 1.0)
	blade_angle += deg_to_rad(max_spin_speed_degrees) * speed_ratio * spin_direction * delta
	queue_redraw()


func _draw() -> void:
	if post_length > 0.0:
		draw_line(Vector2.ZERO, Vector2(0.0, post_length), POST_COLOR, 2.0)
	# Each blade is a thin triangle from the hub to its tip, rotated around the hub.
	for blade_index: int in BLADE_COUNT:
		var angle: float = blade_angle + TAU * blade_index / BLADE_COUNT
		var blade: PackedVector2Array = Transform2D(angle, Vector2.ZERO) * PackedVector2Array([
			Vector2.ZERO,
			Vector2(BLADE_LENGTH, -BLADE_TIP_HALF_WIDTH),
			Vector2(BLADE_LENGTH, BLADE_TIP_HALF_WIDTH),
		])
		draw_colored_polygon(blade, BLADE_COLOR)
	draw_circle(Vector2.ZERO, 1.5, POST_COLOR)
	# Time-left ring: a full circle right after a gust, shrinking clockwise to nothing.
	if spin_remaining > 0.0:
		var start_angle: float = -PI / 2.0  # 12 o'clock
		var end_angle: float = start_angle + TAU * spin_remaining / spin_time
		draw_arc(Vector2.ZERO, BLADE_LENGTH + 2.0, start_angle, end_angle, 24, TIMER_RING_COLOR, 1.0)

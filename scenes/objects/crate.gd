@tool
class_name Crate
extends CharacterBody2D
## Crate (GAME_DESIGN.md §6): a heavy box the gust can shove around. It slides along
## the ground and slows to a stop, falls with gravity, can rest on pressure plates,
## and the player can stand on it.
##
## Place the node ON the floor, at the bottom-center of the crate (same as the
## player: origin at the feet).
##
## Why a CharacterBody2D and not a RigidBody2D? A rigid body would tumble, bounce
## and spin, which is hard to aim at a plate. With our own few lines of movement
## code, a gust of the same strength always slides it the same distance
## (distance = speed² / (2 × ground_friction): 160² / 640 = 40 px).
##
## The player can't push it by walking into it: the gust is the only way to move
## it (pillar 2: the air verbs ARE the puzzle tools).
##
## Groups (tags other code looks for):
##   - "pushable"        (Pushable.GROUP): the gust finds it and calls receive_gust()
##   - "heavy"           (PressurePlate.HEAVY_GROUP): it presses plates
##   - "room_resettable" (Room.RESETTABLE_GROUP): it returns to its start when the
##                       player dies or restarts the room
##
## Physics layers: it IS on layer 1 ("world"), so the player stands on it and doors
## and plates see it, and also on layer 4 ("pushable"). It collides with the world
## and with the player (so a sliding crate stops against you, it doesn't overlap you).

## Brown, per the color key (GAME_DESIGN.md §2), with darker planks.
const CRATE_COLOR: Color = Color(0.6, 0.38, 0.2)
const PLANK_COLOR: Color = Color(0.4, 0.24, 0.12)

## Crate size, px. 16x16 = 2x2 tiles.
@export var crate_size: Vector2 = Vector2(16, 16):
	set(value):
		crate_size = value
		_resize_hitbox()
		queue_redraw()
## Same gravity and max fall speed as the player (GAME_DESIGN.md §4), so it falls
## the way you'd expect next to you.
@export var gravity: float = 900.0
@export var max_fall_speed: float = 300.0
## How fast a sliding crate slows down on the ground / in the air, px/s².
@export var ground_friction: float = 320.0
@export var air_friction: float = 60.0
## Fraction of the gust's push turned into upward speed when gusted from below.
## 160 x 0.8 = 128 px/s, a small hop of about 9 px (v² / 2g).
@export var upward_push_multiplier: float = 0.8
## If it falls this far below its start (a pit), it puts itself back.
@export var fall_out_distance: float = 400.0

## Where it was placed, in world coordinates. reset() puts it back here.
var start_position: Vector2
var hitbox: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 | 8  # bit values of layer 1 "world" and layer 4 "pushable"
	collision_mask = 1 | 2   # stops against the world and the player
	hitbox = CollisionShape2D.new()
	hitbox.shape = RectangleShape2D.new()
	add_child(hitbox)
	_resize_hitbox()
	if Engine.is_editor_hint():
		return
	start_position = global_position
	add_to_group(Pushable.GROUP)
	add_to_group(PressurePlate.HEAVY_GROUP)
	add_to_group(Room.RESETTABLE_GROUP)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	# Friction: slide toward a stop, faster on the ground than in the air.
	var friction: float = ground_friction if is_on_floor() else air_friction
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	# move_and_slide() also zeroes the part of velocity that runs into a wall,
	# so a crate shoved into a wall just stops.
	move_and_slide()
	if global_position.y > start_position.y + fall_out_distance:
		reset()


## The Pushable contract: called by the gust (and the dash wake) when it hits us.
## Sideways: sets the slide speed (replacing it, so a gust can also stop or reverse
## a moving crate). Upward: a small hop. Downward: slams it down if it's in the air.
func receive_gust(direction: Vector2, strength: float) -> void:
	velocity.x = direction.x * strength
	if direction.y < -0.1:
		# minf because "up" is negative y: keep whichever upward speed is bigger.
		velocity.y = minf(velocity.y, direction.y * strength * upward_push_multiplier)
	elif direction.y > 0.1:
		velocity.y = maxf(velocity.y, direction.y * strength)


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	global_position = start_position
	velocity = Vector2.ZERO


func _resize_hitbox() -> void:
	if hitbox == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(hitbox.shape as RectangleShape2D).size = crate_size
	# Origin is at the bottom-center, and a shape is positioned by its center.
	hitbox.position = Vector2(0.0, -crate_size.y / 2.0)


func _draw() -> void:
	var box: Rect2 = Rect2(-crate_size.x / 2.0, -crate_size.y, crate_size.x, crate_size.y)
	draw_rect(box, CRATE_COLOR)
	# Outline plus a diagonal brace: reads as "crate" even as a placeholder.
	draw_rect(box.grow(-0.5), PLANK_COLOR, false, 1.0)
	draw_line(box.position + Vector2(1.0, 1.0), box.end - Vector2(1.0, 1.0), PLANK_COLOR, 1.0)

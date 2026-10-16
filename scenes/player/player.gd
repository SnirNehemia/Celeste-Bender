class_name Player
extends CharacterBody2D
## The player character: a CharacterBody2D that moves with custom code.
##
## CharacterBody2D is Godot's node for bodies YOU control (as opposed to RigidBody2D,
## which the physics engine controls). You set `velocity`, call move_and_slide(),
## and Godot moves the body, stops it against solids, and updates is_on_floor() etc.
##
## Node layout (see player.tscn):
##   Player (this script)
##   ├─ CollisionShape2D   8x11 hitbox
##   ├─ Visual (ColorRect) white 8x11 rectangle
##   ├─ DeathBurst         CPUParticles2D, one-shot burst played by the Dead state
##   └─ StateMachine       children: Idle, Run, Jump, Fall, WallSlide, Dead (one script each)
##
## Collision: the player is on physics layer 2 ("player") and collides with layer 1
## ("world"). Hazards (spikes) look for layer 2 to find the player.
##
## Death: anything deadly calls die(). The player switches to the Dead state and
## emits `died`. It does NOT respawn itself: RoomManager listens to `died`, waits,
## and calls respawn_at() with the current room's spawn point.
##
## The origin (0,0) of this node is at the player's FEET, centered horizontally.
## That makes placing the player on a surface trivial: put it at the surface's y.
##
## This script holds the shared movement helpers and the "forgiveness" timers
## (coyote time, jump buffer, wall-jump input lock). The states decide WHEN to use them.
## The debug overlay (scenes/ui/debug_overlay) reads the public vars below to display them.

## All feel values (speeds, gravity...). Edit player_tuning.tres, or this field
## in the Inspector, even while the game runs (Remote tab).
@export var tuning: PlayerTuning

## Emitted once when the player dies (spikes, pit, or R). RoomManager handles the respawn.
signal died

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hitbox: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual
@onready var death_burst: CPUParticles2D = $DeathBurst

## Counts down after leaving the ground. While > 0 a ground jump is still allowed.
## Refilled to tuning.coyote_time every frame we stand on the floor.
var coyote_time_remaining: float = 0.0
## Counts down after the jump button is pressed. While > 0 the press is "remembered"
## and any state that can jump will do so.
var jump_buffer_remaining: float = 0.0
## Counts down after a wall jump. While > 0 horizontal input is ignored.
var wall_jump_lock_remaining: float = 0.0


func _ready() -> void:
	# _ready() runs after all children are ready, so the states exist now.
	state_machine.setup(self)


## _physics_process runs at a fixed rate (60 times/s by default), independent of the
## frame rate. All movement code belongs here so behaviour is the same on any
## machine. `delta` is the time step (1/60 s).
func _physics_process(delta: float) -> void:
	# 1) Tick the timers first so every state sees this frame's values.
	_update_timers(delta)
	# 2) The active state reads input and updates `velocity` (and may change state).
	state_machine.physics_update(delta)
	# 3) If we're about to clip a ceiling corner, shift sideways to slip past it.
	_apply_ceiling_corner_correction(delta)
	# 4) Godot moves the body by velocity * delta, sliding along any solids it hits
	#    and refreshing is_on_floor() / is_on_ceiling() / is_on_wall().
	move_and_slide()


func _update_timers(delta: float) -> void:
	# is_on_floor() reports the result of LAST frame's move_and_slide().
	if is_on_floor():
		coyote_time_remaining = tuning.coyote_time
	else:
		coyote_time_remaining = maxf(coyote_time_remaining - delta, 0.0)

	# is_action_just_pressed is true only on the one physics frame the key went down.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_remaining = tuning.jump_buffer_time
	else:
		jump_buffer_remaining = maxf(jump_buffer_remaining - delta, 0.0)

	wall_jump_lock_remaining = maxf(wall_jump_lock_remaining - delta, 0.0)


# --- Death, respawn, freezing -------------------------------------------------

## Kills the player. Safe to call repeatedly (e.g. spikes touching every frame):
## only the first call does anything until the player respawns.
func die() -> void:
	if is_dead():
		return
	state_machine.transition_to(&"Dead")
	died.emit()


## The middle of the hitbox in world coordinates (the node's origin is at the feet).
func get_center() -> Vector2:
	return hitbox.global_position


## The hitbox as a rectangle in world coordinates (at the player's CURRENT position).
func get_hitbox_rect() -> Rect2:
	var hitbox_size: Vector2 = (hitbox.shape as RectangleShape2D).size
	return Rect2(get_center() - hitbox_size / 2.0, hitbox_size)


func is_dead() -> bool:
	return state_machine.current_state.name == &"Dead"


## Puts the player back at `spawn_position` (feet position), standing still, alive.
func respawn_at(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	coyote_time_remaining = 0.0
	jump_buffer_remaining = 0.0
	wall_jump_lock_remaining = 0.0
	# Idle switches to Fall by itself on the next frame if there's no floor below.
	state_machine.transition_to(&"Idle")


## Stops (or resumes) all player movement and input, keeping the current velocity.
## Used during room transitions. set_physics_process(false) tells Godot to stop
## calling this node's _physics_process(), so nothing moves or reads input.
func set_frozen(frozen: bool) -> void:
	set_physics_process(not frozen)


# --- Input -------------------------------------------------------------------

## Horizontal input as -1 (left), 0 (none) or +1 (right) from the InputMap actions.
func get_move_input() -> float:
	return Input.get_axis("move_left", "move_right")


# --- Jumping -----------------------------------------------------------------

## True if a jump was pressed recently AND we are (or just were) on the ground.
## Both conditions use timers, which is what makes jumping forgiving:
##   - jump buffer: pressed up to 0.1 s BEFORE landing still counts
##   - coyote time: pressed up to 0.1 s AFTER leaving a ledge still counts
func can_ground_jump() -> bool:
	return jump_buffer_remaining > 0.0 and coyote_time_remaining > 0.0


## True if a jump was pressed recently and a wall is within reach on either side.
func can_wall_jump() -> bool:
	return jump_buffer_remaining > 0.0 and get_wall_direction() != 0.0


## Launches a normal jump. The Jump state then holds this upward speed while jump is held.
func start_ground_jump() -> void:
	_consume_jump()
	velocity.y = tuning.jump_velocity


## Launches a wall jump away from the wall on side `wall_direction` (-1 left, +1 right).
func start_wall_jump(wall_direction: float) -> void:
	_consume_jump()
	velocity.x = -wall_direction * tuning.wall_jump_horizontal_speed
	velocity.y = tuning.wall_jump_vertical_speed
	# Ignore input briefly: otherwise holding toward the wall (which you usually are,
	# since you were sliding on it) would cancel the push away on the very next frame.
	wall_jump_lock_remaining = tuning.wall_jump_input_lock_time


## Uses up the buffered press and the coyote window so one press = one jump.
func _consume_jump() -> void:
	jump_buffer_remaining = 0.0
	coyote_time_remaining = 0.0


# --- Walls -------------------------------------------------------------------

## Returns -1 if there's a wall within reach on the left, +1 on the right, 0 if none.
## If walls are on both sides (narrow shaft), the side you're pressing toward wins.
func get_wall_direction() -> float:
	var held_direction: float = signf(get_move_input())
	if held_direction != 0.0 and is_wall_on_side(held_direction):
		return held_direction
	if is_wall_on_side(1.0):
		return 1.0
	if is_wall_on_side(-1.0):
		return -1.0
	return 0.0


## True if moving `wall_jump_check_distance` px toward `side` would hit something.
## test_move() asks the physics engine "would this motion collide?" without moving.
func is_wall_on_side(side: float) -> bool:
	return test_move(global_transform, Vector2(side * tuning.wall_jump_check_distance, 0.0))


## True while airborne, holding toward a wall that is within reach, and not in the
## wall-jump input lock. This is the condition for entering/staying in WallSlide.
func is_pressing_into_wall() -> bool:
	var held_direction: float = signf(get_move_input())
	return held_direction != 0.0 \
		and wall_jump_lock_remaining <= 0.0 \
		and not is_on_floor() \
		and is_wall_on_side(held_direction)


# --- Shared movement ---------------------------------------------------------

## Pulls the player down, capped at terminal speed.
## move_toward(a, b, step) moves `a` toward `b` by at most `step`, never overshooting.
func apply_gravity(delta: float) -> void:
	var gravity_scale: float = 1.0
	# Apex half-gravity: near the top of the arc (vertical speed close to 0) and still
	# holding jump, fall more gently. This gives a moment of hang time to line up a landing.
	if Input.is_action_pressed("jump") and absf(velocity.y) < tuning.apex_gravity_threshold:
		gravity_scale = tuning.apex_gravity_multiplier

	# Fast-fall: holding Down raises the terminal speed. Releasing Down brings it back
	# down gradually (move_toward approaches max_fall_speed at the gravity rate, no sudden stop).
	var fall_speed_cap: float = tuning.max_fall_speed
	if Input.is_action_pressed("move_down"):
		fall_speed_cap = tuning.fast_fall_max_speed

	velocity.y = move_toward(velocity.y, fall_speed_cap, tuning.gravity * gravity_scale * delta)


## Accelerates toward the held direction, or slows down if nothing is held.
## Airborne, acceleration is scaled by air_acceleration_multiplier for less control.
## During the wall-jump input lock, horizontal speed is left untouched (the push away
## from the wall plays out in full).
func apply_horizontal_movement(delta: float) -> void:
	if wall_jump_lock_remaining > 0.0:
		return

	var input_direction: float = get_move_input()
	var air_multiplier: float = 1.0 if is_on_floor() else tuning.air_acceleration_multiplier

	if input_direction != 0.0:
		# Speed up toward full speed in the held direction. Reversing direction passes
		# through zero, so turning around happens at the same acceleration rate.
		var target_speed: float = input_direction * tuning.max_run_speed
		velocity.x = move_toward(velocity.x, target_speed, tuning.run_acceleration * air_multiplier * delta)
	else:
		# Nothing held: slow toward zero.
		velocity.x = move_toward(velocity.x, 0.0, tuning.run_deceleration_ground * air_multiplier * delta)


## Ceiling corner correction: if we're moving up and this frame's motion would hit a
## ceiling, check whether shifting 1..N px sideways would clear it. If so, shift.
## Result: clipping the edge of a platform with your head slides you around it
## instead of killing the jump. A head-on bonk (more than N px of overlap) still bonks.
func _apply_ceiling_corner_correction(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var upward_motion: Vector2 = Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, upward_motion):
		return  # nothing above us, no correction needed

	# Try the side we're moving toward first, so the nudge goes with our momentum.
	var first_side: float = signf(velocity.x) if velocity.x != 0.0 else 1.0
	for offset_pixels: int in range(1, tuning.corner_correction_pixels + 1):
		for side: float in [first_side, -first_side]:
			var sideways_shift: Vector2 = Vector2(side * offset_pixels, 0.0)
			# The shift itself must be free (don't nudge into a wall)...
			if test_move(global_transform, sideways_shift):
				continue
			# ...and from the shifted spot, the upward motion must be clear.
			if not test_move(global_transform.translated(sideways_shift), upward_motion):
				position += sideways_shift
				return

extends PlayerState
## Jump: rising after a ground jump or a wall jump, until upward speed runs out.
##
## Whoever starts the jump (Idle/Run/Fall/WallSlide, via player.start_ground_jump()
## or player.start_wall_jump()) sets the launch velocity BEFORE switching here.
## This state only handles the rise, so ground and wall jumps share the same feel.
##
## Variable jump height: for up to `variable_jump_time` seconds we hold the launch
## speed constant instead of letting gravity slow it, but ONLY while jump is held.
## Releasing the button ends the hold, and normal gravity takes over at once.
## (-105 px/s under 900 px/s² gravity alone rises ~6 px; a full 0.2 s hold adds ~21 px.)

## Seconds of "held" upward speed still left in this jump.
var hold_time_remaining: float = 0.0
## The upward speed being held (the launch speed: ground or wall jump).
var hold_velocity_y: float = 0.0


func enter() -> void:
	hold_velocity_y = player.velocity.y
	hold_time_remaining = player.tuning.variable_jump_time


func physics_update(delta: float) -> void:
	player.apply_horizontal_movement(delta)

	# Letting go of jump ends the hold early: this is the variable jump height.
	if not Input.is_action_pressed("jump"):
		hold_time_remaining = 0.0

	if hold_time_remaining > 0.0:
		# Holding phase: keep the launch speed, skip gravity.
		hold_time_remaining -= delta
		player.velocity.y = hold_velocity_y
	else:
		# apply_gravity also handles apex half-gravity near the top of the arc.
		player.apply_gravity(delta)

	if player.can_wall_jump():
		# A fresh jump press next to a wall mid-rise: wall jump. Switching Jump -> Jump
		# re-runs enter(), restarting the hold with the new launch speed.
		player.start_wall_jump(player.get_wall_direction())
		transition_requested.emit(&"Jump")
	elif player.is_on_ceiling():
		# Bonked our head (corner correction didn't save us): stop rising.
		player.velocity.y = 0.0
		transition_requested.emit(&"Fall")
	elif player.velocity.y >= 0.0:
		# Upward speed used up: we're at the top, now falling.
		transition_requested.emit(&"Fall")

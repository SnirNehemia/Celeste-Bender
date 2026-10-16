extends PlayerState
## Run: on the ground and moving horizontally (accelerating, at speed, or sliding to a stop).

## Below this speed (px/s) a sliding player counts as stopped.
const STOPPED_SPEED_THRESHOLD: float = 1.0


func physics_update(delta: float) -> void:
	# Dash beats everything else this frame (Dash.enter() sets the velocity).
	if player.wants_to_dash():
		transition_requested.emit(&"Dash")
		return
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta)

	if player.can_ground_jump():
		player.start_ground_jump()
		transition_requested.emit(&"Jump")
	elif not player.is_on_floor():
		# Ran off a ledge. Coyote time keeps a jump possible from Fall.
		transition_requested.emit(&"Fall")
	elif player.get_move_input() == 0.0 and absf(player.velocity.x) < STOPPED_SPEED_THRESHOLD:
		# No input and the slide has finished.
		player.velocity.x = 0.0
		transition_requested.emit(&"Idle")

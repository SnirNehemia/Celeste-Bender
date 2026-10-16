extends PlayerState
## Fall: in the air and moving downward (or walked off a ledge).
##
## From here we can still:
##   - ground jump, during coyote time (just left a ledge) or when landing with a
##     buffered press (pressed jump just before touching down)
##   - wall jump, if a wall is within reach
##   - start a wall slide, if holding into a wall

func physics_update(delta: float) -> void:
	# Dash beats everything else this frame (Dash.enter() sets the velocity).
	if player.wants_to_dash():
		transition_requested.emit(&"Dash")
		return
	# apply_gravity handles apex half-gravity and fast-fall (holding Down).
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta)

	# Order matters: a ground jump (coyote / buffered landing) beats a wall jump.
	if player.can_ground_jump():
		player.start_ground_jump()
		transition_requested.emit(&"Jump")
	elif player.can_wall_jump():
		player.start_wall_jump(player.get_wall_direction())
		transition_requested.emit(&"Jump")
	elif player.is_on_floor():
		# Landed. Go to Run if still moving sideways, otherwise Idle.
		if absf(player.velocity.x) > 0.0:
			transition_requested.emit(&"Run")
		else:
			transition_requested.emit(&"Idle")
	elif player.velocity.y > 0.0 and player.is_pressing_into_wall():
		transition_requested.emit(&"WallSlide")

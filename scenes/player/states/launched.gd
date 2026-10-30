extends PlayerState
## Launched: flying after a RISING Earth Column threw us (Earth_bending.md §5, §11).
##
## Entered only through player.launch_from_column(), which sets the launch velocity
## first (super jump up, a throw down, or sideways with a lift).
##
## Like Fall, with two differences that make a throw feel like a throw:
##   - Steering lock: after a SIDEWAYS launch (faster than run speed), the arrows are
##     ignored for launch_steer_lock_time. Otherwise holding toward the column (which
##     you often are) would brake the 220 px/s away within ~0.2 s.
##   - Overspeed fade: after the lock, speed above max run speed fades at the gentle
##     launch_overspeed_deceleration (unless you steer against it), instead of normal
##     air control snapping it down to run speed.
## No ground jump from here: coyote time was spent by the launch, so a jump press in
## flight is a wall jump (near a wall) or a glide.
## Hands over to Fall once falling at normal speed, so all the usual air rules return.

## Seconds left in which the arrows don't steer.
var steer_lock_remaining: float = 0.0


func enter() -> void:
	var is_sideways_throw: bool = absf(player.velocity.x) > player.tuning.max_run_speed
	steer_lock_remaining = player.earth_tuning.launch_steer_lock_time if is_sideways_throw else 0.0


func physics_update(delta: float) -> void:
	if player.wants_to_gust():
		transition_requested.emit(player.get_gust_start_state())
		return
	if player.try_start_jet():
		transition_requested.emit(&"Jetting")
		return
	if player.try_start_fireball():
		transition_requested.emit(&"GustAim")
		return
	if player.try_start_water_hands():
		transition_requested.emit(&"WaterHolding")
		return
	if player.try_start_freeze():
		transition_requested.emit(player.get_freeze_start_state())
		return

	steer_lock_remaining = maxf(steer_lock_remaining - delta, 0.0)
	# apply_gravity: apex half-gravity while jump is held, fast-fall on Down.
	player.apply_gravity(delta)
	if steer_lock_remaining <= 0.0:
		player.apply_horizontal_movement(delta, false, player.earth_tuning.launch_overspeed_deceleration)

	if player.can_wall_jump():
		player.start_wall_jump(player.get_wall_direction())
		transition_requested.emit(&"Jump")
	elif player.wants_to_glide():
		player.consume_jump_press()  # one press = one action
		transition_requested.emit(&"Glide")
	elif player.is_on_floor() and player.velocity.y >= 0.0:
		# Landed. (velocity.y >= 0: right after a launch from the floor,
		# is_on_floor() still reports last frame's floor.)
		transition_requested.emit(&"Run" if player.velocity.x != 0.0 else &"Idle")
	elif player.velocity.y > 0.0 and steer_lock_remaining <= 0.0:
		if player.is_pressing_into_wall():
			transition_requested.emit(&"WallSlide")
		elif absf(player.velocity.x) <= player.tuning.max_run_speed:
			# A normal fall now: Fall takes over.
			transition_requested.emit(&"Fall")

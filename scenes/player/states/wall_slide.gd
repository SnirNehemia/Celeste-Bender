extends PlayerState
## WallSlide: falling while holding toward a wall. Fall speed is capped low
## (wall_slide_max_speed) so you have time to line up a wall jump.
##
## Entered from Fall. Leaves when you jump (wall jump), land, let go of the
## direction, or slide past the bottom of the wall.

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
		transition_requested.emit(&"GustAim")
		return
	if player.try_tear_rock():
		transition_requested.emit(&"BoulderHold")
		return
	if player.wants_to_bend():
		transition_requested.emit(&"EarthBend")
		return
	# Keep pressing into the wall: horizontal input stays live so letting go is noticed,
	# and move_and_slide() stops us at the wall each frame.
	player.apply_horizontal_movement(delta)

	# Same gravity as normal, but approaching the much lower slide cap (higher on an
	# ice wall: no grip, Stage W5). Arriving fast,
	# you decelerate to the slide speed over a few frames instead of stopping dead.
	player.velocity.y = move_toward(
		player.velocity.y, player.get_wall_slide_max_speed(), player.tuning.gravity * delta)

	if player.can_wall_jump():
		player.start_wall_jump(player.get_wall_direction())
		transition_requested.emit(&"Jump")
	elif player.is_on_floor():
		transition_requested.emit(&"Idle")
	elif not player.is_pressing_into_wall():
		transition_requested.emit(&"Fall")

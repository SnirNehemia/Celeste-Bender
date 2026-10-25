extends PlayerState
## Idle: standing on the ground with no horizontal input.
##
## Still applies gravity and horizontal slow-down so a leftover slide finishes
## naturally and the body keeps pressing into the floor (keeps is_on_floor() stable).

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
	if player.try_tear_rock():
		transition_requested.emit(&"BoulderHold")
		return
	if player.wants_to_bend():
		transition_requested.emit(&"EarthBend")
		return
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta)

	# Jump check comes first and uses the buffer, so a press from a few frames ago counts.
	if player.can_ground_jump():
		player.start_ground_jump()
		transition_requested.emit(&"Jump")
	elif not player.is_on_floor():
		# Walked/slid off a ledge. Coyote time keeps a jump possible from Fall.
		transition_requested.emit(&"Fall")
	elif player.get_move_input() != 0.0:
		transition_requested.emit(&"Run")

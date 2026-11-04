extends PlayerState
## WallSlide: falling while holding toward a wall. Fall speed is capped low
## (wall_slide_max_speed) so you have time to line up a wall jump.
##
## Entered from Fall. Leaves when you jump (wall jump), land, let go of the
## direction, or slide past the bottom of the wall.
##
## A MUD wall (Stage W8a, MudContact): you CLING instead. The fall is braked to a
## stop (mud_cling_brake) and you stay put while you hold toward it. A hand print
## marks the spot. Wall jumps work as usual.
## CLIMBING (after the W8c play-test, Celeste's climb without stamina): clinging, Up
## climbs and Down slides down at mud_climb_speed. Up stops where the mud ends under
## dry wall; where the wall itself ends (a ledge), a small hop (mud_climb_hop_speed)
## lifts you over its top, and Fall takes over with you still holding toward it.

## On a mud wall since the cling began: it stays a climb even while you move up
## (the cling only starts falling, velocity.y >= 0, but climbing up rises).
var is_on_mud_wall: bool = false


func enter() -> void:
	is_on_mud_wall = false

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
	if player.try_tear_rock():
		transition_requested.emit(&"BoulderHold")
		return
	if player.wants_to_bend():
		transition_requested.emit(&"EarthBend")
		return
	# Keep pressing into the wall: horizontal input stays live so letting go is noticed,
	# and move_and_slide() stops us at the wall each frame.
	player.apply_horizontal_movement(delta)

	var wall_side: float = player.get_wall_direction()
	var tuning: WaterTuning = player.water_tuning
	# A cling starts only falling (a jump still rises past mud), but once on the wall,
	# climbing up (rising) keeps it a climb.
	is_on_mud_wall = player.mud.is_mud_wall(wall_side) and (player.velocity.y >= 0.0 or is_on_mud_wall)
	if is_on_mud_wall:
		var climb: float = Input.get_axis("move_up", "move_down")  # -1 = up
		if climb < 0.0:
			match player.mud.get_wall_above(wall_side):
				MudContact.Above.MUD:
					player.velocity.y = -tuning.mud_climb_speed
					player.mud.leave_hand_print(wall_side)
				MudContact.Above.OPEN:
					# The wall's top: hop over it (still holding toward it, Fall carries
					# you onto the ledge).
					player.velocity.y = -tuning.mud_climb_hop_speed
					transition_requested.emit(&"Fall")
					return
				MudContact.Above.DRY_WALL:
					player.velocity.y = 0.0  # no mud above: hang on where it ends
		elif climb > 0.0:
			player.velocity.y = tuning.mud_climb_speed
			player.mud.leave_hand_print(wall_side)
		else:
			# Clinging: stop fast and stay.
			if player.velocity.y > 0.0:
				player.mud.leave_hand_print(wall_side)
			player.velocity.y = move_toward(player.velocity.y, 0.0, tuning.mud_cling_brake * delta)
	else:
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

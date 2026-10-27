extends PlayerState
## WaterHolding: holding 1, steering the waterball in slow motion (Water_bending.md
## §5.1, §11). Entered from Idle/Run/Jump/Fall/WallSlide/Glide/Launched when
## player.try_start_water_hands() is true.
##
## While here:
##   - the world runs at hold_time_scale (0.3x) for at most max_hold_time real
##     seconds (FX's safety limit is a little longer: we normally clear it in exit())
##   - the ARROWS BELONG TO THE BALL (WaterHandsAbility steers it), so you don't
##     steer: on the ground you slide to a stop and stand, in the air you keep your
##     arc (slowed by the slow motion), like the gust aim
##   - except UNDER WATER: a ball moving into you shoves you once, the way it moves,
##     like a gust (WaterHandsAbility._shove_touched sets your velocity)
## Ways out:
##   - 1 comes up             -> release(true): the water flies on, boosted (a throw;
##                               a ball you weren't moving just drops)
##   - Jump                   -> release(false): the ball drops where it is, and you
##                               jump (from the ground; in the air the press is left
##                               for Fall, so a swimmer strokes)
##   - the ability let go by itself (the ball left the ring, or time ran out) -> leave
##   - death (Dead state)     -> exit() drops the ball (the room reset clears it)


func enter() -> void:
	var tuning: WaterTuning = player.water_tuning
	FX.set_slow_motion(tuning.hold_time_scale, tuning.max_hold_time + 0.3)
	player.water_hands.begin_hold()


func exit() -> void:
	# Runs on every way out, including death, so slow motion never sticks and the
	# ball is never left hanging (a drop, no boost).
	FX.clear_slow_motion()
	player.water_hands.release(false)


func physics_update(delta: float) -> void:
	# Movement keeps playing out (slowed: delta is scaled), the arrows don't steer.
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta, true)
	var hands: WaterHandsAbility = player.water_hands
	if not hands.is_holding():
		_leave()
		return
	# Jump: the ball drops and you jump. jump_buffer_remaining is set the frame Jump
	# is pressed.
	if player.jump_buffer_remaining > 0.0:
		hands.release(false)
		if player.can_ground_jump():
			player.start_ground_jump()
			transition_requested.emit(&"Jump")
			return
		_leave()
		return
	# Let go: is_action_pressed (not just_released) on purpose, so a release between
	# two (rare, slow-motion) physics frames can't be missed.
	if not Input.is_action_pressed("water_hands"):
		hands.release(true)
		_leave()


## Back to normal movement: on the ground Idle/Run, in the air Fall.
func _leave() -> void:
	if player.is_on_floor():
		transition_requested.emit(&"Run" if player.get_move_input() != 0.0 else &"Idle")
	else:
		transition_requested.emit(&"Fall")

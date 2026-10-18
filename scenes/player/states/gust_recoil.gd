extends PlayerState
## GustRecoil: the moment right after a gust, while the air reacts on the player.
##
## Entered from Idle/Run/Jump/Fall/WallSlide/Glide when player.wants_to_gust() is true
## (or from GustAim when the gust key is released, in hold-to-aim mode).
## The GustAbility component does the hit, cooldown and effects; this state only
## does the MOVEMENT (GAME_DESIGN.md §5.3). It runs in one of three phases:
##
##   RECOIL (aimed gust, an arrow held)
##     enter():  shoved the opposite way at gust_recoil_speed; a down-gust in mid-air
##               is an "extra jump" (up to gust_down_boosts_per_airtime per airtime);
##               an up-gust pushes you down. On the ground the sideways shove is
##               weaker (gust_ground_recoil_multiplier) and braked hard by friction
##               (gust_ground_recoil_friction), so you stay planted near a ledge
##               while the enemy flies. Exception: standing on a floor that
##               catches wind (a sail, see Player.get_wind_catching_floor), the sideways shove
##               goes into that floor instead and you stay planted.
##     update:   gravity as normal, horizontal input ignored for
##               gust_recoil_input_lock_time (aiming right = holding Right, which would
##               otherwise steer you straight back into the gust). Pressing jump starts
##               a glide right away, carrying the shove's speed into it.
##
##   BRAKE (neutral gust, no arrow held; the air goes out in every direction, so no shove)
##     update:   for gust_neutral_brake_time, gravity is off and BOTH speed axes slow
##               toward zero. On the ground that's a hard stop and the state ends.
##
##   FLOAT (after a mid-air BRAKE)
##     update:   for gust_neutral_float_time you ride the air cushion: light gravity,
##               a slow fall cap and full steering, so the stall feels powerful and
##               you're in control when it ends (you leave at a gentle drift, not
##               from a standstill). Glide, gust, wall slide, landing and jumps can
##               all cut it short.
##
##   end:      Fall in the air, Idle/Run on the ground
##
## Dash, ground jump and wall jump work in every phase, so the gust never eats an input.

enum Phase { RECOIL, BRAKE, FLOAT }

var phase: Phase = Phase.RECOIL
## Seconds left in the current phase.
var phase_time_remaining: float = 0.0


func enter() -> void:
	var tuning: PlayerTuning = player.tuning
	# The direction GustAim locked in (hold-to-aim), or the live arrows (instant gust).
	# ZERO = no arrow = neutral gust.
	var direction: Vector2 = player.gust.take_gust_direction()
	player.gust.begin_gust(direction)

	if direction == Vector2.ZERO:
		phase = Phase.BRAKE
		phase_time_remaining = tuning.gust_neutral_brake_time
		return

	phase = Phase.RECOIL
	phase_time_remaining = tuning.gust_recoil_input_lock_time
	# Horizontal recoil SETS the speed (not adds): the gust always throws you at the
	# same speed, whatever you were doing. Purely vertical gusts leave x alone.
	if direction.x != 0.0:
		var wind_catcher: Object = player.get_wind_catching_floor()
		if wind_catcher != null:
			# Standing on something that catches the shove (a sail): your feet stay
			# planted and IT takes the push, so you can blow your own boat along.
			# The input lock below still runs, so you don't walk off mid-gust.
			player.velocity.x = 0.0
			wind_catcher.call(Player.WIND_CATCHER_METHOD, direction, tuning.gust_push_strength)
		else:
			var recoil_speed: float = tuning.gust_recoil_speed
			if player.is_on_floor():
				recoil_speed *= tuning.gust_ground_recoil_multiplier
			player.velocity.x = -direction.x * recoil_speed

	if direction.y > 0.0:
		# Down-gust (straight or diagonal) in mid-air: the extra jump. It sets the upward
		# speed so it also works mid-fall; minf keeps a faster rise you already had.
		if not player.is_on_floor() and player.gust.spend_down_boost():
			player.velocity.y = minf(player.velocity.y, -tuning.gust_down_boost_speed * direction.y)
	elif direction.y < 0.0:
		# Up-gust: shoved down. maxf keeps a faster fall you already had.
		player.velocity.y = maxf(player.velocity.y, -direction.y * tuning.gust_recoil_speed)


func physics_update(delta: float) -> void:
	# Dash beats everything else this frame (Dash.enter() sets the velocity).
	if player.wants_to_dash():
		transition_requested.emit(&"Dash")
		return

	phase_time_remaining -= delta
	match phase:
		Phase.RECOIL:
			player.apply_gravity(delta)
			# During the lock the recoil plays out untouched (in the air) or braked by
			# extra friction (on the ground); after it, normal control.
			if phase_time_remaining <= 0.0:
				player.apply_horizontal_movement(delta)
			elif player.is_on_floor():
				player.velocity.x = move_toward(player.velocity.x, 0.0,
					player.tuning.gust_ground_recoil_friction * delta)
		Phase.BRAKE:
			# No gravity, and the whole velocity shrinks toward zero. Vector2.move_toward
			# shortens the vector by at most `step`, keeping its direction.
			player.velocity = player.velocity.move_toward(Vector2.ZERO,
				player.tuning.gust_neutral_brake_deceleration * delta)
		Phase.FLOAT:
			_update_float(delta)

	if player.can_ground_jump():
		player.start_ground_jump()
		transition_requested.emit(&"Jump")
	elif player.can_wall_jump():
		player.start_wall_jump(player.get_wall_direction())
		transition_requested.emit(&"Jump")
	elif phase == Phase.RECOIL and player.wants_to_glide():
		# Glide right out of the shove (no waiting for the lock to end), so the recoil
		# speed goes straight into the glide, which keeps it (glide_overspeed_deceleration).
		player.consume_jump_press()
		transition_requested.emit(&"Glide")
	elif phase == Phase.FLOAT and _float_interrupted():
		return  # _float_interrupted() already asked for the next state
	elif phase_time_remaining > 0.0:
		return  # still recoiling / braking / floating
	elif phase == Phase.BRAKE and not player.is_on_floor():
		# Mid-air brake finished: ride the cushion.
		phase = Phase.FLOAT
		phase_time_remaining = player.tuning.gust_neutral_float_time
	elif player.is_on_floor():
		transition_requested.emit(&"Run" if player.velocity.x != 0.0 else &"Idle")
	else:
		# Fall, even while still rising from a down-boost: Fall applies gravity and
		# handles everything else in the air. (Jump would "hold" the rise while jump
		# is held, which would stretch the boost into a full jump.)
		transition_requested.emit(&"Fall")


## Floating on the air cushion: like a very soft glide with full steering.
func _update_float(delta: float) -> void:
	var tuning: PlayerTuning = player.tuning
	# Wind still counts: an updraft lowers the cap (you may even rise), a downdraft raises it.
	var fall_speed_cap: float = tuning.gust_neutral_float_max_fall_speed + player.get_wind_velocity().y
	player.velocity.y = move_toward(player.velocity.y, fall_speed_cap,
		tuning.gravity * tuning.gust_neutral_float_gravity_multiplier * delta)
	player.apply_horizontal_movement(delta)


## The float ends early when the player does something else. Returns true (after
## requesting the new state) if so.
func _float_interrupted() -> bool:
	if player.wants_to_gust():
		transition_requested.emit(player.get_gust_start_state())
	elif player.wants_to_glide():
		player.consume_jump_press()  # same as Fall: one press = one action
		transition_requested.emit(&"Glide")
	elif player.is_on_floor():
		transition_requested.emit(&"Run" if player.velocity.x != 0.0 else &"Idle")
	elif player.velocity.y > 0.0 and player.is_pressing_into_wall():
		transition_requested.emit(&"WallSlide")
	else:
		return false
	return true

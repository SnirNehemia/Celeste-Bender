extends PlayerState
## GustAim: choosing a gust direction in slow motion (EXPERIMENT, tuning.gust_hold_to_aim).
##
## Why: the arrows both move and aim. Running right and wanting to gust left means
## pressing Left, which also wrecks your run. Here, holding the gust key:
##   - slows the whole game (FX.set_slow_motion, tuning.gust_aim_time_scale)
##   - makes the arrows AIM ONLY: you keep your momentum (drift in the air, slide to
##     a stop on the ground) instead of steering
##   - shows the cone where the gust will go (GustAbility's aim preview)
## Releasing the gust key fires: the direction is locked into GustAbility and we
## switch to GustRecoil, which does the gust and the shove back. A quick tap fires
## almost at once. Holding past tuning.gust_aim_max_real_time (real seconds) fires
## by itself, so slow motion can't be used to hang around.
## The gust charge is checked on the PRESS (player.wants_to_gust()), so any
## direction chosen here is allowed; GustRecoil spends the charge when it fires.
##
## Entered from Idle/Run/Jump/Fall/WallSlide/Glide via player.get_gust_start_state().
## No dash or jump while aiming: the moment is short, and it keeps the state simple.

## The direction the gust will go. Starts at the held arrows; ZERO (nothing held,
## and nothing pressed while aiming) = a neutral, all-around gust.
var aim_direction: Vector2 = Vector2.ZERO
## Real-time clock (ms) when aiming started. Time.get_ticks_msec() is NOT slowed by
## Engine.time_scale, unlike `delta`, so it measures how long the player really held.
var aim_start_msec: int = 0


func enter() -> void:
	var tuning: PlayerTuning = player.tuning
	aim_direction = player.get_forgiving_aim_input()
	aim_start_msec = Time.get_ticks_msec()
	player.gust.begin_aim(aim_direction)
	# The safety limit is a little longer than ours: we normally clear it ourselves
	# in exit(); FX only steps in if something skipped that (e.g. a room transition).
	FX.set_slow_motion(tuning.gust_aim_time_scale, tuning.gust_aim_max_real_time + 0.1)


func exit() -> void:
	# Runs on every way out, including death, so slow motion never sticks.
	FX.clear_slow_motion()
	player.gust.end_aim()


func physics_update(delta: float) -> void:
	# Movement keeps playing out (slowed by time_scale, since delta is scaled),
	# but the arrows don't steer.
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta, true)

	# Any arrows held = new aim. Letting go of every arrow keeps the last aim, so you
	# can pick a direction and then release the arrows before the gust key.
	# (So once you've aimed, you can't go back to neutral in this same press.)
	# get_forgiving_aim_input() keeps a diagonal for a moment when one of its two keys
	# comes up first (the diagonal grace window), so diagonals don't turn sideways.
	var held: Vector2 = player.get_forgiving_aim_input()
	if held != Vector2.ZERO:
		aim_direction = held
		player.gust.update_aim(aim_direction)

	# Fire on release, or when the real-time limit runs out. is_action_pressed (not
	# just_released) on purpose: in slow motion physics ticks are rarer, and checking
	# the held state can't miss a release that happened between ticks.
	var held_real_seconds: float = (Time.get_ticks_msec() - aim_start_msec) / 1000.0
	if not Input.is_action_pressed("gust") or held_real_seconds >= player.tuning.gust_aim_max_real_time:
		player.gust.lock_aim(aim_direction)
		transition_requested.emit(&"GustRecoil")

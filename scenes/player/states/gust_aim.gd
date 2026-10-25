extends PlayerState
## GustAim: choosing a direction in slow motion. Started by the gust (Z, with
## tuning.gust_hold_to_aim) and, since Stage F4, by the fireball (Q).
##
## Why: the arrows both move and aim. Running right and wanting to gust left means
## pressing Left, which also wrecks your run. Here, holding the key:
##   - slows the whole game (FX.set_slow_motion)
##   - makes the arrows AIM ONLY: you keep your momentum (drift in the air, slide to
##     a stop on the ground) instead of steering
##   - shows a preview of where the shot goes (drawn by the ability)
## Releasing the key fires. A quick tap fires almost at once. Holding past the
## ability's max real time (real seconds) fires by itself, so slow motion can't be
## used to hang around.
##
## AIM SOURCE: which ability is aiming. Player.aim_source is set just before the
## switch (Player.get_gust_start_state() sets the gust, Player.try_start_fireball()
## the fireball); nothing set = the gust. This state talks to it only through the
## aim source methods (the contract is written out in fireball_ability.gd), called by
## name with call(), so the state doesn't care which ability it is:
##   gust:     time scale/limit from PlayerTuning; release locks the direction and
##             goes to GustRecoil (which spends the charge and blows)
##   fireball: time scale/limit from FireTuning; release throws (spends the pip) and
##             goes to Fall/Idle/Run; Jump cancels without spending anything
## The resource (charge / pip) is checked on the PRESS, so any direction chosen here
## is allowed.
##
## Entered from Idle/Run/Jump/Fall/WallSlide/Glide/Launched. No jump while
## aiming: the moment is short, and it keeps the state simple.

## The direction chosen so far. Starts at the held arrows; ZERO (nothing held, and
## nothing pressed while aiming) = neutral for the gust, facing for the fireball.
var aim_direction: Vector2 = Vector2.ZERO
## Real-time clock (ms) when aiming started. Time.get_ticks_msec() is NOT slowed by
## Engine.time_scale, unlike `delta`, so it measures how long the player really held.
var aim_start_msec: int = 0
## The ability doing the aiming (GustAbility or FireballAbility).
var aim_source: Node


func enter() -> void:
	aim_source = player.aim_source if player.aim_source != null else player.gust
	aim_direction = aim_source.call(&"get_initial_aim")
	aim_start_msec = Time.get_ticks_msec()
	aim_source.call(&"begin_aim", aim_direction)
	# The safety limit is a little longer than ours: we normally clear it ourselves
	# in exit(); FX only steps in if something skipped that (e.g. a room transition).
	FX.set_slow_motion(aim_source.call(&"get_aim_time_scale"),
		float(aim_source.call(&"get_aim_max_real_time")) + 0.1)


func exit() -> void:
	# Runs on every way out, including death, so slow motion never sticks.
	FX.clear_slow_motion()
	aim_source.call(&"end_aim")
	player.aim_source = null


func physics_update(delta: float) -> void:
	# Movement keeps playing out (slowed by time_scale, since delta is scaled),
	# but the arrows don't steer.
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta, true)

	# Jump cancels, if this ability allows it (the fireball does). The press is eaten
	# so it doesn't also jump (or glide) right after.
	if aim_source.call(&"can_cancel_aim") and Input.is_action_just_pressed("jump"):
		player.consume_jump_press()
		aim_source.call(&"cancel_aim")
		transition_requested.emit(_get_resting_state())
		return

	# Any arrows held = new aim. Letting go of every arrow keeps the last aim, so you
	# can pick a direction and then release the arrows before the key.
	# (So once you've aimed, you can't go back to neutral in this same press.)
	# get_forgiving_aim_input() keeps a diagonal for a moment when one of its two keys
	# comes up first (the diagonal grace window), so diagonals don't turn sideways.
	var held: Vector2 = player.get_forgiving_aim_input()
	if held != Vector2.ZERO:
		aim_direction = held
		aim_source.call(&"update_aim", aim_direction)

	# Fire on release, or when the real-time limit runs out. is_action_pressed (not
	# just_released) on purpose: in slow motion physics ticks are rarer, and checking
	# the held state can't miss a release that happened between ticks.
	var held_real_seconds: float = (Time.get_ticks_msec() - aim_start_msec) / 1000.0
	var aim_action: StringName = aim_source.call(&"get_aim_action")
	if not Input.is_action_pressed(aim_action) \
			or held_real_seconds >= float(aim_source.call(&"get_aim_max_real_time")):
		transition_requested.emit(aim_source.call(&"finish_aim", aim_direction))


## Where to go after a cancel: on the ground Idle/Run, in the air Fall.
func _get_resting_state() -> StringName:
	if player.is_on_floor():
		return &"Run" if player.velocity.x != 0.0 else &"Idle"
	return &"Fall"

extends PlayerState
## Jetting: the flame jet's movement (Fire_bending.md §5.2 and §8). One burst = one
## pip = jet_burst_time seconds that always runs to its end.
##
## Entered from Idle/Run/Jump/Fall/WallSlide/Glide/Launched when
## player.try_start_jet() is true (the pip is already spent by then).
## FlameJetAbility owns the pips, the thrust curve and every visual; this state only
## moves the body:
##   - gravity is OFF for the whole burst
##   - the arrows steer live in 8 directions; no arrow = straight up
##   - the speed ALONG the steered direction chases jet_max_speed × thrust at
##     jet_accel × thrust (thrust = the tapering multiplier)
##   - the rest of the velocity (sideways, or backwards) is bled off at
##     jet_turn_accel, which is what makes a turn quick
## It ends:
##   - when the burst time is up: W still held + a pip left = the next burst chains
##     (pump flare, curve restarts); W held with no pip = a sputter, then the end
##   - on Jump: cut short at once (the pip stays spent, and the press doesn't jump)
##   - on a head-on ceiling hit (thrusting straight up): a bonk
## Q during a burst throws a fireball at once toward the steered direction (no aim,
## the burst doesn't stop).
## At the end, jet_end_carry of the velocity is kept and Fall (or Idle/Run) takes over
## with normal gravity, apex half-gravity included.

## The steered direction this frame (unit vector).
var thrust_direction: Vector2 = Vector2.UP
## Seconds since the current burst (ignition or last chain) started.
var burst_elapsed: float = 0.0
## Set just before leaving, so exit() knows how the flight ended.
var was_cancelled: bool = false


func enter() -> void:
	# Flying into water with your head under puts the flame out (after the W8c
	# play-test): a cough, and you keep what's left of the speed.
	if player.flame_jet.is_under_water():
		player.flame_jet.start_sputter()
		_finish()
		return

	thrust_direction = _read_steer_direction()
	burst_elapsed = 0.0
	was_cancelled = false
	# Taking off from the ground: forget the coyote window, so a Jump press during the
	# burst is read as a cancel, never as a late ground jump afterwards.
	player.coyote_time_remaining = 0.0
	player.flame_jet.begin_burst(thrust_direction, false)


func exit() -> void:
	player.flame_jet.end_jet(was_cancelled)


func physics_update(delta: float) -> void:
	var tuning: FireTuning = player.fire_tuning

	# Jump cuts the burst short. consume_jump_press() eats the press, so it neither
	# jumps now nor waits in the jump buffer to jump on landing.
	if Input.is_action_just_pressed("jump"):
		player.consume_jump_press()
		was_cancelled = true
		_finish()
		return

	# Bonk: thrusting straight up and the last move hit a ceiling. (A diagonal just
	# slides along the ceiling, and the corner correction in Player slips us past
	# edges, so only a head-on hit ends the burst.)
	if player.is_on_ceiling() and thrust_direction == Vector2.UP:
		player.velocity.y = 0.0
		FX.shake(1.0, 0.08)
		_finish()
		return

	thrust_direction = _read_steer_direction()
	if thrust_direction.x != 0.0:
		player.facing_direction = signf(thrust_direction.x)

	# Q mid-jet (after the F4 play-test): an instant throw in the steered direction,
	# no slow-motion aim, and the burst keeps going. It costs a pip like any throw
	# (throw() fizzles with none), so it competes with hold-to-chain for fuel.
	if Input.is_action_just_pressed("fireball") and player.is_element_allowed(Player.ELEMENT_FIRE):
		player.fireball.throw(thrust_direction)

	burst_elapsed += delta
	var progress: float = burst_elapsed / maxf(tuning.jet_burst_time, 0.001)
	var thrust: float = player.flame_jet.get_thrust_multiplier(progress)
	_steer(delta, thrust)
	player.flame_jet.update_thrust(thrust_direction, thrust)

	if burst_elapsed < tuning.jet_burst_time:
		return
	# The burst is over. Holding W chains the next one (try_chain spends the pip, or
	# sputters when there's none).
	if Input.is_action_pressed("flame_jet") and player.flame_jet.try_chain():
		burst_elapsed = 0.0
		player.flame_jet.begin_burst(thrust_direction, true)
		return
	_finish()


## The 8-way steer: held arrows as a unit vector (diagonals normalized), or straight
## up when nothing is held.
func _read_steer_direction() -> Vector2:
	var aim: Vector2 = player.get_aim_input()
	return aim if aim != Vector2.ZERO else Vector2.UP


## Splits the velocity into the part along the steered direction and the rest.
##   along: speeds up toward max_speed × thrust at accel × thrust. Above that (the
##          taper, or a fast entry), it eases down at the same rate. If it points
##          BACKWARDS (falling when you steer up), it's a turn: bled off at turn_accel.
##   rest:  the sideways part, bled to zero at turn_accel, so the path bends quickly
##          toward the new direction instead of drifting.
func _steer(delta: float, thrust: float) -> void:
	var tuning: FireTuning = player.fire_tuning
	var target_speed: float = tuning.jet_max_speed * thrust
	var along_speed: float = player.velocity.dot(thrust_direction)
	var sideways_velocity: Vector2 = player.velocity - thrust_direction * along_speed
	if along_speed < 0.0:
		along_speed = move_toward(along_speed, target_speed, tuning.jet_turn_accel * delta)
	else:
		along_speed = move_toward(along_speed, target_speed, tuning.jet_accel * thrust * delta)
	sideways_velocity = sideways_velocity.move_toward(Vector2.ZERO, tuning.jet_turn_accel * delta)
	player.velocity = thrust_direction * along_speed + sideways_velocity


## Keeps jet_end_carry of the velocity and hands over to the right state.
func _finish() -> void:
	player.velocity *= player.fire_tuning.jet_end_carry
	if player.is_on_floor() and player.velocity.y >= 0.0:
		transition_requested.emit(&"Run" if player.velocity.x != 0.0 else &"Idle")
	else:
		transition_requested.emit(&"Fall")

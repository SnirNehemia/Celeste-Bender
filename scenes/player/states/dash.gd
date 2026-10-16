extends PlayerState
## Dash: a short burst in the aimed direction, ignoring gravity.
##
## Entered from Idle/Run/Jump/Fall/WallSlide when player.wants_to_dash() is true.
## The AirDashAbility component owns the charge and all the air-bending effects;
## this state only does the movement:
##   enter():  lock in the direction (aim is read ONCE, at the start), tell the
##             ability the dash began (spends the charge, plays start effects)
##   update:   velocity = direction * speed for dash_duration seconds, leaving wind
##             streaks along the way
##   end:      keep some momentum (dash_end_* tuning) and hand off to Fall, or
##             Idle/Run on the ground
##   exit():   body shape back to normal (also runs if we die mid-dash)
##
## Experimental "Ride the Current" mode (tuning.ride_current_enabled):
##   - the speed starts high and eases down over the dash (same total distance)
##   - afterwards, player.ride_current_remaining opens a short window of lighter
##     gravity and stronger air control (handled in Player's movement helpers)

## The locked-in unit direction of this dash.
var dash_direction: Vector2 = Vector2.RIGHT
## Seconds of dash left.
var dash_time_remaining: float = 0.0
## Counts down to the next wind streak.
var trail_time_remaining: float = 0.0


func enter() -> void:
	dash_direction = player.air_dash.get_aim_direction()
	dash_time_remaining = player.tuning.dash_duration
	trail_time_remaining = 0.0  # first streak right away, at the start point
	player.ride_current_remaining = 0.0  # a new dash cancels any leftover ride window
	player.velocity = dash_direction * _get_current_speed()
	# Dashing sideways also turns you around.
	if dash_direction.x != 0.0:
		player.facing_direction = signf(dash_direction.x)
	# Spend the charge, freeze frames, shake, air burst, stretch the body. Called after
	# setting velocity so the frozen frame already "points" the right way.
	player.air_dash.begin_dash(dash_direction)


func exit() -> void:
	player.air_dash.restore_body()


func physics_update(delta: float) -> void:
	# Velocity is SET every frame: no gravity, no air control. move_and_slide() still
	# stops us at walls, and slides us along them on diagonals.
	player.velocity = dash_direction * _get_current_speed()

	trail_time_remaining -= delta
	if trail_time_remaining <= 0.0:
		player.air_dash.spawn_trail_streak(dash_direction)
		trail_time_remaining = player.tuning.dash_trail_interval

	dash_time_remaining -= delta
	if dash_time_remaining > 0.0:
		return

	_apply_end_momentum()
	player.air_dash.finish_dash(dash_direction)
	if player.tuning.ride_current_enabled:
		player.ride_current_remaining = player.tuning.ride_current_time
	if player.is_on_floor():
		transition_requested.emit(&"Run" if player.velocity.x != 0.0 else &"Idle")
	else:
		transition_requested.emit(&"Fall")


## Dash speed right now. Normally constant. In Ride the Current mode it slides
## linearly from the start multiplier to the end multiplier over the dash, so it
## feels like a burst that relaxes into a glide.
func _get_current_speed() -> float:
	var tuning: PlayerTuning = player.tuning
	if not tuning.ride_current_enabled:
		return tuning.dash_speed
	# 0 at the start of the dash, 1 at the end.
	var progress: float = 1.0 - clampf(dash_time_remaining / tuning.dash_duration, 0.0, 1.0)
	return tuning.dash_speed * lerpf(
		tuning.ride_current_dash_start_multiplier, tuning.ride_current_dash_end_multiplier, progress)


## Instead of stopping dead, carry speed into the next state. Horizontal speed is
## kept (air control then eases it back to run speed); upward speed is trimmed so
## an up-dash ends in a short rise instead of a rocket launch.
func _apply_end_momentum() -> void:
	player.velocity.x *= player.tuning.dash_end_horizontal_multiplier
	if player.velocity.y < 0.0:
		player.velocity.y *= player.tuning.dash_end_upward_multiplier

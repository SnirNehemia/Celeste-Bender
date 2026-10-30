extends PlayerState
## IceBall (after Stage W7a, developer's idea): 2 pressed while wholly under water
## (FreezeAbility rule 3) freezes the water around you into a ball of ice you sit in.
## FreezeAbility owns the ball itself (its water, start_ice_ball / shatter_ice_ball,
## and draws it); this state moves you in it:
##   - water lifts it like a floating crate, but harder (ice_ball_buoyancy, 3: it
##     floats a third under), so from deep down it shoots up (capped at
##     ice_ball_max_rise_speed, less as it breaks the surface) and then bobs there;
##     water drag (ice_ball_water_drag) calms the bobbing;
##   - out of water it falls with your gravity;
##   - the arrows ROLL it sideways (ice_ball_roll_speed, ice_ball_roll_accel), in the
##     water, on the surface and on the ground;
##   - 2 again SHATTERS it: its water goes back as loose water, you pop up a little
##     and swim (Fall). Leaving any other way (death, a reset) shatters it too.
## Inside the ball black water can't touch you (WaterWorld._is_in_black_water): a
## lifeboat, if you roll from clean water onto black.
##
## Entered from Fall (and the other states that ask player.try_start_freeze(), but
## only Fall can be wholly under water) when FreezeAbility.start_state is IceBall.

## Shattering pops you up at this speed, px/s (out of the ice and swimming).
const SHATTER_POP_SPEED: float = 60.0

## Physics frames spent in this state: the press of 2 that started it must not
## shatter it in the same frame.
var frames_in_state: int = 0


func enter() -> void:
	frames_in_state = 0
	if not player.freeze.start_ice_ball():
		return  # no water around after all: physics_update leaves at once
	# The ice grabs you: most of your sideways speed goes, and you stop sinking.
	player.velocity = Vector2(player.velocity.x * 0.3, minf(player.velocity.y, 0.0))


func exit() -> void:
	player.freeze.shatter_ice_ball()  # death, a reset, a room change: no ball left behind


func physics_update(delta: float) -> void:
	frames_in_state += 1
	var freeze: FreezeAbility = player.freeze
	if not freeze.has_ice_ball():
		transition_requested.emit(&"Fall")
		return
	if frames_in_state > 1 and Input.is_action_just_pressed("water_freeze"):
		freeze.shatter_ice_ball()
		player.velocity.y = minf(player.velocity.y, -SHATTER_POP_SPEED)
		transition_requested.emit(&"Fall")
		return

	var water_tuning: WaterTuning = player.water_tuning
	var gravity: float = player.tuning.gravity
	var radius: float = water_tuning.ice_ball_radius
	var ball_box: Rect2 = Rect2(player.get_center() - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	var world: WaterWorld = freeze.ice_ball_world
	var share: float = world.get_submerged_share(ball_box) if is_instance_valid(world) else 0.0
	# Buoyancy: gravity minus the water's lift (the lift is buoyancy x the share under
	# x gravity, so it floats with 1 / buoyancy of it under).
	player.velocity.y += (gravity - gravity * water_tuning.ice_ball_buoyancy * share) * delta
	# Water drag on both axes (it calms the bob); none in the air.
	player.velocity *= maxf(0.0, 1.0 - water_tuning.ice_ball_water_drag * share * delta)
	# Rising is capped by how deep it still is (share squared): deep down it shoots up
	# at ice_ball_max_rise_speed, and it slows as it breaks the surface, so it settles
	# into a bob instead of leaping out (the first version flew 27 px clear of the
	# water and bounced for seconds: the drag only works in water).
	var max_rise: float = water_tuning.ice_ball_max_rise_speed * share * share
	player.velocity.y = clampf(player.velocity.y, -max_rise, player.tuning.max_fall_speed)
	# Rolling with the arrows.
	player.velocity.x = move_toward(player.velocity.x, player.get_move_input() * water_tuning.ice_ball_roll_speed,
		water_tuning.ice_ball_roll_accel * delta)
	player.move_and_slide()

extends PlayerState
## Sliding (Stage W6, Water_bending.md §7.2): on ice steeper than slide_min_angle.
## Slopes exist only as ice (painted slope tiles, and the slope tiles of a frozen
## snake's trail: grid ice), and you can't walk on them: gravity pulls you down
## along the slope.
##
## Entered from Idle and Run (player.wants_to_slide(): standing on steep ice). Each
## frame:
##   - the speed ALONG the slope (`along`, signed: + = to the right) is read back from
##     the velocity's horizontal part (IceSlope.get_speed_along: move_and_slide drops
##     the vertical part on a floor). So a bend in the ice carries the speed round
##     it, and a wall that stopped us stops the slide too. The slope is the ice's own
##     surface under us (player.get_slide_normal).
##   - gravity adds g x sin(angle) x slide_gravity_scale (tangent.y is the signed
##     sine: positive when the right is downhill);
##   - the arrows lean ±slide_lean_accel (far weaker than gravity on a 15° slope:
##     you can't climb a slide);
##   - ice friction (the run brake x ice_friction_scale), and a top speed;
##   - holding DOWN is the BELLY SLIDE: no lean, gravity and top speed x
##     belly_slide_scale, and the hitbox half as tall (player.set_tucked).
## The velocity is then the tangent x that speed, and move_and_slide() keeps us on
## the ice with a longer floor snap (slide_snap_length) and floor_stop_on_slope off.
##
## Leaving:
##   - Jump keeps the velocity along the slope and adds the jump (start_slide_jump);
##   - off the end, or off a lip that curves up (a RAMP), Fall: the velocity carries
##     on, and speed above run speed fades gently (carries_ice_speed, as a long jump
##     off ice: Godot never snaps a body moving up back to the floor, so the lip
##     launches you);
##   - onto flatter ice or onto ground, Run, with the slide's whole speed sideways
##     (on flat ice it isn't braked: ice keeps any speed, Stage I5).

var normal_snap_length: float = 1.0


func enter() -> void:
	normal_snap_length = player.floor_snap_length
	player.floor_stop_on_slope = false
	player.floor_snap_length = player.water_tuning.slide_snap_length


func exit() -> void:
	player.floor_stop_on_slope = true
	player.floor_snap_length = normal_snap_length


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
	if not player.is_on_floor():
		# Off the end or off a ramp's lip: the velocity carries on.
		transition_requested.emit(&"Fall")
		return
	if not player.wants_to_slide():
		# Onto flatter ice or ground: run on with the whole speed, sideways.
		player.velocity = Vector2(signf(player.velocity.x) * player.velocity.length(), 0.0)
		transition_requested.emit(&"Run")
		return

	var water_tuning: WaterTuning = player.water_tuning
	var tangent: Vector2 = IceSlope.get_tangent(player.get_slide_normal())
	var along: float = IceSlope.get_speed_along(player.velocity, tangent)
	# set_tucked(true) always works; un-tucking waits for room to stand.
	player.set_tucked(Input.is_action_pressed("move_down"))
	var belly_scale: float = water_tuning.belly_slide_scale if player.is_tucked else 1.0
	along += player.tuning.gravity * tangent.y * water_tuning.slide_gravity_scale * belly_scale * delta
	if not player.is_tucked:
		along += player.get_move_input() * water_tuning.slide_lean_accel * delta
	along = move_toward(along, 0.0,
		player.tuning.run_deceleration_ground * water_tuning.ice_friction_scale * delta)
	var top_speed: float = water_tuning.slide_max_speed * belly_scale
	along = clampf(along, -top_speed, top_speed)
	player.velocity = tangent * along

	if player.can_ground_jump():
		player.start_slide_jump()
		transition_requested.emit(&"Jump")

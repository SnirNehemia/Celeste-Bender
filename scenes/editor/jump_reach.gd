class_name JumpReach
extends RefCounted
## JumpReach: where the player's jump can take them, worked out from PlayerTuning,
## for the level editor's reach overlay (hold J: EditorOverlay draws it from the
## tile under the mouse).
##
## It replays the player's own airborne math frame by frame (60 frames a second,
## like the physics), with the feet as the traced point:
##   - a running start: horizontal speed max_run_speed the whole way (in the air,
##     holding the direction keeps you at run speed);
##   - a FULL jump: jump held, so the launch speed is held for variable_jump_time,
##     then gravity, halved near the apex (apex_gravity_threshold), up to
##     max_fall_speed (Player.apply_gravity, the Jump state);
##   - with `glide`: at the top of the arc a glide starts (jump pressed again), the
##     fall eases to glide_max_fall_speed (glide_vertical_acceleration) until
##     glide_stamina_time runs out, then a normal fall (the Glide state);
##   - with a gust (trace_gust): one mid-air gust aimed `gust_aim`, fired at the
##     moment that reaches farthest (every frame of the jump is tried). Its shove is
##     GustRecoil's: sideways gust_recoil_speed (gust_diagonal_recoil_share of it for
##     a diagonal), untouched for gust_recoil_input_lock_time, then fading gently
##     (gust_overspeed_fade) for gust_overspeed_time, then air control back to run
##     speed; a down-gust sets the rise to gust_down_boost_speed (times its down share).
## Not included: wind, water, ice, wall jumps, gust diamonds (a second gust). The
## trace is the middle of the feet: the hitbox reaches half its width further each side.

const FRAME_TIME: float = 1.0 / 60.0
## Give up after this long in the air, s (a long glide is ~2 s).
const MAX_TIME: float = 4.0
## "Never gust" for _simulate's gust_frame.
const NO_GUST: int = -1


## The feet's path from `start` running in `direction` (-1 left, 1 right), until
## they're `max_drop` px below the start (or MAX_TIME passed).
static func trace(tuning: PlayerTuning, start: Vector2, direction: float, glide: bool, max_drop: float) -> PackedVector2Array:
	return _simulate(tuning, start, direction, glide, Vector2.ZERO, NO_GUST, max_drop)


## The farthest-reaching path with one gust aimed `gust_aim` (a unit vector: the way
## the AIR goes, so a gust to the left shoves you right). Every frame of the plain
## jump is tried as the gust's moment; the path that comes back down to the start
## height farthest across wins (ties: the higher one).
static func trace_gust(tuning: PlayerTuning, start: Vector2, direction: float, gust_aim: Vector2, max_drop: float) -> PackedVector2Array:
	var plain_frames: int = trace(tuning, start, direction, false, max_drop).size()
	var best_points: PackedVector2Array = PackedVector2Array()
	var best_reach: Vector2 = Vector2(-1.0, -1.0)
	# From frame 1: a gust on the ground (frame 0) is a different, weaker shove.
	for gust_frame: int in range(1, plain_frames):
		var points: PackedVector2Array = _simulate(tuning, start, direction, false, gust_aim, gust_frame, max_drop)
		var reach: Vector2 = summary(points)
		if reach.x > best_reach.x or (is_equal_approx(reach.x, best_reach.x) and reach.y > best_reach.y):
			best_reach = reach
			best_points = points
	return best_points


## One replay: the jump, the glide (if `glide`), and a gust aimed `gust_aim` on frame
## `gust_frame` (NO_GUST = none).
static func _simulate(tuning: PlayerTuning, start: Vector2, direction: float, glide: bool,
		gust_aim: Vector2, gust_frame: int, max_drop: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([start])
	var feet: Vector2 = start
	var velocity: Vector2 = Vector2(direction * tuning.max_run_speed, tuning.jump_velocity)
	var hold_time_remaining: float = tuning.variable_jump_time
	var glide_time: float = 0.0
	var input_lock_remaining: float = 0.0
	var overspeed_remaining: float = 0.0
	var time: float = 0.0
	var frame: int = 0
	while time < MAX_TIME and feet.y <= start.y + max_drop:
		time += FRAME_TIME
		frame += 1
		if frame == gust_frame:
			# The gust ends the Jump state, so its launch-speed hold ends too.
			hold_time_remaining = 0.0
			if gust_aim.x != 0.0:
				var sideways_share: float = tuning.gust_diagonal_recoil_share if gust_aim.y != 0.0 else 1.0
				velocity.x = -signf(gust_aim.x) * tuning.gust_recoil_speed * sideways_share
				input_lock_remaining = tuning.gust_recoil_input_lock_time
				overspeed_remaining = tuning.gust_overspeed_time
			if gust_aim.y > 0.0:
				velocity.y = minf(velocity.y, -tuning.gust_down_boost_speed * gust_aim.y)
		# Vertical.
		if hold_time_remaining > 0.0:
			hold_time_remaining -= FRAME_TIME  # launch speed held: no gravity yet
		elif glide and velocity.y >= 0.0 and glide_time < tuning.glide_stamina_time:
			glide_time += FRAME_TIME
			velocity.y = move_toward(velocity.y, tuning.glide_max_fall_speed, tuning.glide_vertical_acceleration * FRAME_TIME)
		else:
			# Jump still held: half gravity near the apex, as in Player.apply_gravity.
			var gravity_scale: float = tuning.apex_gravity_multiplier if absf(velocity.y) < tuning.apex_gravity_threshold else 1.0
			velocity.y = move_toward(velocity.y, tuning.max_fall_speed, tuning.gravity * gravity_scale * FRAME_TIME)
		# Horizontal (Player.apply_horizontal_movement, holding `direction`): the shove
		# plays out untouched during the input lock, then fades gently while it's
		# above run speed and the overspeed window lasts, then air control takes over.
		if input_lock_remaining > 0.0:
			input_lock_remaining -= FRAME_TIME
		elif overspeed_remaining > 0.0 and absf(velocity.x) > tuning.max_run_speed and signf(velocity.x) == direction:
			velocity.x = move_toward(velocity.x, direction * tuning.max_run_speed, tuning.gust_overspeed_fade * FRAME_TIME)
		else:
			velocity.x = move_toward(velocity.x, direction * tuning.max_run_speed,
				tuning.run_acceleration * tuning.air_acceleration_multiplier * FRAME_TIME)
		overspeed_remaining = maxf(overspeed_remaining - FRAME_TIME, 0.0)
		feet += velocity * FRAME_TIME
		points.append(feet)
	return points


## How high the trace rises (px above its start), and how far across it is when it
## comes back down to its start height (px; the whole trace's width if it never does).
static func summary(points: PackedVector2Array) -> Vector2:
	var start: Vector2 = points[0]
	var highest: float = start.y
	var across: float = absf(points[points.size() - 1].x - start.x)
	var has_risen: bool = false
	for index: int in range(1, points.size()):
		highest = minf(highest, points[index].y)
		has_risen = has_risen or points[index].y < start.y
		if has_risen and points[index].y >= start.y:
			across = absf(points[index].x - start.x)
			break
	return Vector2(across, start.y - highest)

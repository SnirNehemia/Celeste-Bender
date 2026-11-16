class_name AimSweep
extends RefCounted
## AimSweep: turns an aim TOWARD the direction the arrows ask for at a steady speed,
## instead of snapping to it. A static helper (never instanced), shared by:
##   - the GustAim state, for aim sources that ask for it (the fireball:
##     FireballAbility.get_aim_sweep_speed; the gust returns 0 and still snaps)
##   - BoulderAbility.update_hover_aim (the hovering rock)
##
## How it plays: the arrows still name one of 8 directions, but the aim only starts
## moving there, the short way round. Hold the arrows until it arrives and you get
## the exact 8-way direction, as before. Let go on the way and the aim STOPS where it
## is (the callers only call step() while an arrow is held), so any angle in between
## can be thrown. The speeds are in the tuning resources, in degrees per REAL second:
## aiming happens in slow motion, and the hand shouldn't slow down with the world.

## Two aims this close to exactly opposite (radians) count as a half turn, where
## "the short way" is a coin toss: step() then picks the side itself (see there).
const HALF_TURN_TOLERANCE: float = 0.02


## The REAL seconds one physics tick lasts. In slow motion Godot still runs 60 physics
## ticks per real second and only scales the `delta` each tick is given, so the tick
## rate (not delta) is the real clock.
static func get_real_tick_seconds() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


## `current` turned toward `target` by at most degrees_per_second * seconds, the short
## way round. Both are unit vectors. Returns `target` itself once it's within reach, so
## a finished sweep is exactly the 8-way direction (no rounding left over).
## A half turn (Right -> Left) goes OVER THE TOP, the useful side for a lobbed throw;
## Up -> Down goes round the `facing_direction` side (-1 left, +1 right).
static func step(current: Vector2, target: Vector2, degrees_per_second: float, seconds: float,
		facing_direction: float) -> Vector2:
	var max_turn: float = deg_to_rad(degrees_per_second) * seconds
	# angle_to() is the signed angle from current to target, in -PI..PI: its sign says
	# which way round is shorter.
	var turn: float = current.angle_to(target)
	if absf(turn) <= max_turn:
		return target
	if absf(turn) > PI - HALF_TURN_TOLERANCE:
		# Mostly sideways aim: turn through Up. Mostly vertical: through the facing side.
		var through: Vector2 = Vector2.UP if absf(current.x) > absf(current.y) \
			else Vector2(facing_direction, 0.0)
		# cross() is positive when `through` lies clockwise of `current` (the same sign
		# convention as angle_to), so it names the side to turn to.
		var side: float = signf(current.cross(through))
		if side != 0.0:
			turn = absf(turn) * side
	return current.rotated(signf(turn) * max_turn)

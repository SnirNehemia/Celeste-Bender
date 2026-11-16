class_name AimSweep
extends RefCounted
## AimSweep: turns an aim TOWARD the direction the arrows ask for, instead of snapping
## to it. One instance per aim (made by the GustAim state for the fireball, and kept
## by BoulderAbility for the hovering rock); it is plain data and code, not a node.
## The ability fills in the numbers from its tuning resource (configure_aim_sweep()).
##
## How it plays:
##   - RAMP: the aim TURNS toward the arrows at a speed that starts at `start_speed`
##     and grows to `max_speed` over `ramp_time` of holding (degrees per REAL second).
##     A short tap is a fine nudge, a long hold is a quick big turn. (A "snap first"
##     jump on the first press was tried and felt wrong, so there is none.)
##   - Let go of the arrows (release()) and the aim STOPS where it is, the ramp starts
##     over; hold them until it arrives and the aim is exactly the 8-way direction.
## Speeds are in real seconds: aiming happens in slow motion, and the hand shouldn't
## slow down with the world.

## Two aims this close to exactly opposite (radians) count as a half turn, where
## "the short way" is a coin toss: _turn_toward then picks the side itself.
const HALF_TURN_TOLERANCE: float = 0.02

## False = no sweep, the aim snaps to the arrows (the gust, or both speeds at 0).
var enabled: bool = false
## Turn speed when the arrows have just been pressed, degrees per real second.
var start_speed: float = 120.0
## Turn speed once the ramp is done.
var max_speed: float = 720.0
## Real seconds of holding it takes to go from start_speed to max_speed.
var ramp_time: float = 0.3

## Real seconds the arrows have been held (for the ramp); reset by release().
var held_seconds: float = 0.0


## The REAL seconds one physics tick lasts. In slow motion Godot still runs 60 physics
## ticks per real second and only scales the `delta` each tick is given, so the tick
## rate (not delta) is the real clock.
static func get_real_tick_seconds() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


## A new aim begins: the ramp starts over.
func start_aim() -> void:
	held_seconds = 0.0


## The arrows were let go: the aim stays, the ramp starts over.
func release() -> void:
	held_seconds = 0.0


## The aim after one physics tick with the arrows asking for `target` (a unit vector).
## `current` is the aim now. `facing_direction` (-1 / +1) is the side a vertical half
## turn (Up <-> Down) goes round. Returns `target` itself once it's within reach, so a
## finished sweep is exactly the 8-way direction. Not enabled: just `target`.
func step(current: Vector2, target: Vector2, facing_direction: float) -> Vector2:
	if not enabled:
		return target
	var seconds: float = get_real_tick_seconds()
	held_seconds += seconds
	var ramp_progress: float = clampf(held_seconds / maxf(ramp_time, 0.001), 0.0, 1.0)
	var speed: float = lerpf(start_speed, max_speed, ramp_progress)
	return _turn_toward(current, target, deg_to_rad(speed) * seconds, facing_direction)


## `current` turned toward `target` by at most `max_turn` radians, the short way
## round (target itself if it's within reach). A half turn (Right -> Left) goes OVER
## THE TOP, the useful side for a lobbed throw; Up -> Down goes round the
## `facing_direction` side.
static func _turn_toward(current: Vector2, target: Vector2, max_turn: float,
		facing_direction: float) -> Vector2:
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

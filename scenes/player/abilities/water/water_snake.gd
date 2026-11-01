class_name WaterSnake
extends RefCounted
## WaterSnake: the column of water that follows the ball up out of a pool
## (Water_bending.md §5.1 "The water snake", Stage W4; a TRAIL since the re-planned
## ice, snapped to the tile angles since the grid ice, Stage I2).
##
## Not a node: WaterHandsAbility makes one with WaterSnake.new() when the ball leaves
## a pool with a snake wanted, calls update() every rendered frame (real time, like
## the ball), and drops it when update() says it tore or sank back. Released (a
## throw), it FLIES as a ribbon: the ability keeps calling update_flight() until all
## of it has fed out.
## It never draws itself: get_dots() gives its water as dots, which the ability hands
## to the WaterWorld with the ball's, so the metaball renderer draws ball and snake
## as one water.
##
## The model, a TRAIL:
##   - its body lies exactly along the path the ball took since it left the pool: a
##     list of CORNERS (trail_corners, the FOOT first) and a RUN from the last corner
##     toward the ball. Each run's direction is snapped to the tile angles (flat, the
##     gentle 1:2 slope, 45°, straight up or down: IcePlan.TRAIL_ANGLES), judged once
##     the ball is snake_trail_min_segment px from the run's start (the average
##     direction over that stretch). The ball straying more than snake_trail_tolerance
##     off the run's line makes a corner there. Steering back along the last run
##     REWINDS it (the corner goes). `points` is the trail with its corners rounded
##     (snake_trail_corner_radius), which is what's drawn, doused with and thrown.
##   - the FOOT stays at the x where the ball left the pool, riding its surface.
##   - its WATER is its length x snake_width, taken from the pool at the foot as it
##     grows and given back as it shortens (WaterWorld.draw_from_body_at /
##     return_held_to_body_at), so the pool drops while a snake rises. That water is
##     in the WaterWorld's held_area, like the ball's: the books never change.
##   - FROZEN (2), the hands' ice plan (IcePlan.for_trail) turns the trail, corners
##     snapped to the 8 px grid, into the tiles under it (get_trail_path).
##   - in GENTLE (WaterTuning.snake_trigger), it TEARS when the ball rises faster
##     than snake_max_rise_speed, the pool can't feed it or it gets too long: the
##     water rains back as particles. With the other triggers it never tears: the
##     hands keep the ball on a leash (snake_max_length along the trail).
##   - it SINKS BACK (no tear) once it's been rewound to a stub at the surface: its
##     water goes straight back into the pool.
##   - RELEASED (the throw), it's a RIBBON (after play-test 4): the trail's shape
##     freezes, and its water flows along it into the point where the ball was let
##     go, leaving there as particles at the ball's throw velocity. Every bit leaves
##     from the same point at the same velocity, so it follows the head's path: a
##     ribbon of water along one arc. The part at the foot falls back into the pool.
##   - DRAWN as rows of dots across the trail, widening over its last TAPER_LENGTH px
##     to the ball's width (no "ball on a stick"), with a ripple running up toward
##     the head so it looks like it flows.
##
## Positions are in WORLD coordinates (the ability's), converted to the WaterWorld's
## room-local ones at its calls. Speeds are px per REAL second while held; the flight
## runs on game time (the particles it feeds do).

enum Status { RISING, TORE, SANK }

## Drawn as dots: rows across the snake, px apart along it.
const DOT_SPACING: float = 2.0
## Released, the bit of trail this close to the foot (px) just falls back into the pool.
const FOOT_FALL_BACK_LENGTH: float = 8.0
## The foot rides the surface smoothed: averaged over this many px each side, and
## following it at FOOT_FOLLOW_RATE (share per second). Taking water makes waves
## under the foot, and a foot pinned to every crest would jerk the trail's length.
const FOOT_SAMPLE_REACH: float = 6.0
const FOOT_FOLLOW_RATE: float = 8.0
## Over its last TAPER_LENGTH px the snake widens to HEAD_WIDTH_SHARE of the ball's
## width, so the two read as one body of water.
const TAPER_LENGTH: float = 16.0
const HEAD_WIDTH_SHARE: float = 0.8
## The ripple running up the drawn snake: px across, radians per real second, and
## radians per px along (one wave every ~16 px).
const FLOW_AMPLITUDE: float = 0.8
const FLOW_SPEED: float = 12.0
const FLOW_WAVENUMBER: float = 0.4
## Thrown slower than this (px/s), there's no ribbon: the water just falls.
const RIBBON_MIN_SPEED: float = 40.0
## The ribbon leaves as pieces at most this many px of trail long.
const RIBBON_PIECE_LENGTH: float = 2.0
## A rounded corner is drawn as this many short straight bits.
const CORNER_STEPS: int = 4

var world: WaterWorld
var tuning: WaterTuning
## The trail, corners rounded (world coordinates), the foot first.
var points: PackedVector2Array = PackedVector2Array()
## The water in the snake, px² (also in world.held_area).
var area: float = 0.0
## Length along the trail, px.
var length: float = 0.0
## Why it tore, for the overlay and tests ("" while it hasn't).
var tear_reason: String = ""
## Flying (released as a ribbon): the trail's shape at release (world, foot to head),
## how far along it the water starts (the foot's bit fell back), how much has fed
## out through the head, the water per px, where and how fast it leaves, and the
## world's reset count then (a reset empties the hands' water: the flight ends).
var flight_path: PackedVector2Array = PackedVector2Array()
var flight_start: float = 0.0
var flight_fed: float = 0.0
var area_per_length: float = 0.0
var launch_point: Vector2 = Vector2.ZERO
var launch_velocity: Vector2 = Vector2.ZERO
var flight_reset_count: int = 0
## The corners, world coordinates, the foot first.
var trail_corners: PackedVector2Array = PackedVector2Array()
## The current run's snapped direction (unit), ZERO while not judged yet.
var run_direction: Vector2 = Vector2.ZERO
## Where the current run ends: the ball, projected onto its line (world).
var run_end: Vector2 = Vector2.ZERO


## Starts a snake whose foot is on the surface at `foot` and whose head is at `head`
## (world).
func _init(water_world: WaterWorld, foot: Vector2, head: Vector2) -> void:
	world = water_world
	tuning = water_world.water_tuning
	trail_corners = PackedVector2Array([foot])
	run_end = head
	points = PackedVector2Array([foot, head])


## One real-time step. `head` is the ball's new position, `head_velocity` its
## velocity (px/s). Returns RISING (still a snake), TORE or SANK; after TORE or SANK
## its water is already back in the world (rained or poured back).
func update(real_delta: float, head: Vector2, head_velocity: Vector2) -> Status:
	if real_delta <= 0.0:
		return Status.RISING
	var can_tear: bool = tuning.snake_trigger == WaterTuning.SnakeTrigger.GENTLE
	# GENTLE: rising too fast tears it (keeping it slow is the player's job there).
	if can_tear and -head_velocity.y > tuning.snake_max_rise_speed + 1.0:
		return _tear("too fast")
	# The foot stays at its x, riding the pool's surface (smoothed).
	var foot: Vector2 = points[0]
	if not _has_water_under(foot.x, foot.y):
		return _tear("no water under the foot")
	var surface_y: float = _get_smoothed_surface_y(foot.x, foot.y)
	if is_nan(surface_y):
		return _tear("no water under the foot")
	var follow: float = minf(1.0, FOOT_FOLLOW_RATE * real_delta)
	_step_trail(Vector2(foot.x, lerpf(foot.y, surface_y, follow)), head)
	# Water: as long as the trail, as thick as snake_width. Grow from the pool, give
	# back when shorter.
	length = _polyline_length(points)
	var wanted_area: float = length * tuning.snake_width
	var foot_local: Vector2 = world.to_local(points[0])
	if wanted_area > area:
		var missing: float = wanted_area - area
		var got: float = world.draw_from_body_at(foot_local, missing)
		area += got
		if got < missing * 0.9 - 0.01 and can_tear:
			return _tear("the pool ran dry")  # (else: it just runs thinner)
	elif wanted_area < area:
		world.return_held_to_body_at(foot_local, area - wanted_area)
		area = wanted_area
	# Not GENTLE, the hands keep the ball within reach of the foot (a leash), so this
	# can only be a frame's overshoot.
	if length > tuning.snake_max_length and can_tear:
		return _tear("too long")
	# Rewound to a stub at the foot, the ball at or under the surface and not rising:
	# it sinks back into its pool. (A trail may run along or below its pool's level on
	# purpose, a slide down from the pool, so the height alone doesn't sink it.)
	var sinks_back: bool = head.y >= points[0].y - tuning.snake_min_length and head_velocity.y >= 0.0 \
		and length <= tuning.snake_trail_min_segment
	if sinks_back:
		world.return_held_to_body_at(foot_local, area)
		area = 0.0
		return Status.SANK
	return Status.RISING


## True if a pool with water in it (not a dry column) is right under world x `x`,
## looking down from world y `near_y`.
func _has_water_under(x: float, near_y: float) -> bool:
	var found: Array = world.find_body_under(world.to_local(Vector2(x, near_y)))
	return not found.is_empty() and (found[0] as WaterBody).depth[found[1]] > WaterBody.DRY_DEPTH


## The pool's surface (world y) under world x `x`, averaged over three points
## FOOT_SAMPLE_REACH apart (only those with water). NAN when there's none.
func _get_smoothed_surface_y(x: float, near_y: float) -> float:
	var total: float = 0.0
	var count: int = 0
	for offset: float in [-FOOT_SAMPLE_REACH, 0.0, FOOT_SAMPLE_REACH]:
		var local_y: float = world.get_surface_y_at(world.to_local(Vector2(x + offset, near_y)))
		if not is_nan(local_y):
			total += world.to_global(Vector2(0.0, local_y)).y
			count += 1
	return total / count if count > 0 else NAN


## Follows the ball (`head`, world) with the snapped runs (see the header). The foot
## (corner 0) is `foot`. Then `points` = the trail, corners rounded.
func _step_trail(foot: Vector2, head: Vector2) -> void:
	trail_corners[0] = foot
	var tolerance: float = tuning.snake_trail_tolerance
	var start: Vector2 = trail_corners[trail_corners.size() - 1]
	var to_head: Vector2 = head - start
	if run_direction != Vector2.ZERO:
		var along: float = to_head.dot(run_direction)
		if along < tuning.snake_trail_min_segment:
			# Back near the run's start: judge it again (and maybe rewind onto the run
			# before it, below).
			run_direction = Vector2.ZERO
		elif absf(run_direction.cross(to_head)) > tolerance:
			# Off the line: a corner where the ball left it, and a new run from there.
			start = start + run_direction * along
			trail_corners.append(start)
			run_direction = Vector2.ZERO
			to_head = head - start
	if run_direction == Vector2.ZERO:
		if to_head.length() < tuning.snake_trail_min_segment:
			_rewind_onto_last_run(head)
			start = trail_corners[trail_corners.size() - 1]
			to_head = head - start
		if to_head.length() >= tuning.snake_trail_min_segment and run_direction == Vector2.ZERO:
			run_direction = snap_direction(to_head)
	# The run ends at the ball projected onto its line (not yet judged: onto the line
	# the ball's direction snaps to now, so even a short stub is on a snapped angle).
	var direction: Vector2 = run_direction if run_direction != Vector2.ZERO else snap_direction(to_head)
	run_end = start + direction * maxf(0.0, to_head.dot(direction))
	points = round_corners(get_trail_path(), tuning.snake_trail_corner_radius)


## The trail as a plain path, world coordinates: the foot, the corners, then the end
## of the current run (no rounding). The ice plan snaps it to the grid.
func get_trail_path() -> PackedVector2Array:
	var path: PackedVector2Array = trail_corners.duplicate()
	if run_end.distance_to(path[path.size() - 1]) > 0.01:
		path.append(run_end)
	if path.size() < 2:
		path.append(path[0])
	return path


## The ball came back to the last corner along the run before it: that corner goes,
## and the run before it is the current run again (the trail rewinds).
func _rewind_onto_last_run(head: Vector2) -> void:
	while trail_corners.size() >= 2:
		var corner: Vector2 = trail_corners[trail_corners.size() - 1]
		var before: Vector2 = trail_corners[trail_corners.size() - 2]
		var run: Vector2 = corner - before
		if run.length() < 0.01:
			trail_corners.remove_at(trail_corners.size() - 1)
			continue
		var direction: Vector2 = run.normalized()
		var from_before: Vector2 = head - before
		var along: float = from_before.dot(direction)
		if absf(direction.cross(from_before)) > tuning.snake_trail_tolerance or along > run.length():
			return  # not back along that run
		trail_corners.remove_at(trail_corners.size() - 1)
		run_direction = direction
		return


## `vector`'s direction snapped to the nearest tile angle (IcePlan.TRAIL_ANGLES, any
## quadrant): flat, the gentle 1:2 slope, 45° or straight up/down (unit).
static func snap_direction(vector: Vector2) -> Vector2:
	if vector.length() < 0.0001:
		return Vector2.UP
	var degrees: float = rad_to_deg(atan2(absf(vector.y), absf(vector.x)))
	var best: float = 0.0
	for angle: float in IcePlan.TRAIL_ANGLES:
		if absf(degrees - angle) < absf(degrees - best):
			best = angle
	var radians: float = deg_to_rad(best)
	# (A flat run has no y sign to keep, a vertical one no x sign: either is fine.)
	var x_sign: float = signf(vector.x) if vector.x != 0.0 else 1.0
	var y_sign: float = signf(vector.y) if vector.y != 0.0 else -1.0
	return Vector2(cos(radians) * x_sign, sin(radians) * y_sign)


## `path` with each inner corner replaced by a curve (a quadratic Bézier from
## `radius` px before the corner to `radius` px after it, at most half of each side).
static func round_corners(path: PackedVector2Array, radius: float) -> PackedVector2Array:
	if path.size() < 3 or radius <= 0.0:
		return path
	var rounded: PackedVector2Array = PackedVector2Array([path[0]])
	for index: int in range(1, path.size() - 1):
		var corner: Vector2 = path[index]
		var to_before: Vector2 = path[index - 1] - corner
		var to_after: Vector2 = path[index + 1] - corner
		var cut: float = minf(radius, minf(to_before.length(), to_after.length()) * 0.5)
		if cut < 0.5:
			rounded.append(corner)
			continue
		var curve_start: Vector2 = corner + to_before.normalized() * cut
		var curve_end: Vector2 = corner + to_after.normalized() * cut
		for step: int in CORNER_STEPS + 1:
			var t: float = float(step) / CORNER_STEPS
			# Quadratic Bézier with the corner as its control point.
			rounded.append(curve_start.lerp(corner, t).lerp(corner.lerp(curve_end, t), t))
	rounded.append(path[path.size() - 1])
	return rounded


## How long the trail would be with the ball at `head` (world): its corners, then
## straight to `head`. The hands' leash.
func get_trail_length_to(head: Vector2) -> float:
	return _polyline_length(trail_corners) + trail_corners[trail_corners.size() - 1].distance_to(head)


static func _polyline_length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for index: int in path.size() - 1:
		total += path[index].distance_to(path[index + 1])
	return total


## Torn: its water rains back as loose particles, falling from where each bit was.
func _tear(reason: String) -> Status:
	tear_reason = reason
	_let_go()
	return Status.TORE


## Released (WaterHandsAbility.release) with the ball's throw velocity (zero: Jump
## dropped it). Fast enough, it becomes a ribbon and returns true: keep calling
## update_flight() until it returns false. Too slow, its water just falls (false).
func release(throw_velocity: Vector2) -> bool:
	length = _polyline_length(points)
	if throw_velocity.length() < RIBBON_MIN_SPEED or length < 0.0001:
		_let_go()
		return false
	area_per_length = area / length
	# The bit at the foot falls back into its pool.
	flight_start = minf(FOOT_FALL_BACK_LENGTH, length)
	world.return_held_to_body_at(world.to_local(points[0]), area_per_length * flight_start)
	area -= area_per_length * flight_start
	flight_path = points.duplicate()
	flight_fed = 0.0
	launch_point = points[points.size() - 1]
	launch_velocity = throw_velocity
	flight_reset_count = world.reset_count
	return true


## One step of the ribbon (game time, like the particles it feeds): the water flows
## along the frozen trail into the launch point at the throw speed and leaves there.
## False once it's all out (or a reset emptied the hands).
func update_flight(delta: float) -> bool:
	if not is_instance_valid(world) or world.reset_count != flight_reset_count:
		area = 0.0
		return false
	var remaining: float = _polyline_length(flight_path) - flight_start - flight_fed
	var fed_now: float = minf(launch_velocity.length() * delta, remaining)
	_feed_out(fed_now)
	flight_fed += fed_now
	if remaining - fed_now <= 0.001:
		_finish_flight()
		return false
	return true


## Lets the rest of the ribbon go at once (a new hold starts before it's out).
func finish_flight() -> void:
	_feed_out(_polyline_length(flight_path) - flight_start - flight_fed)
	_finish_flight()


func _finish_flight() -> void:
	# Rounding leftovers leave with the last piece.
	if area > 0.0:
		world.release_held_along(PackedVector2Array([world.to_local(launch_point)]),
			PackedVector2Array([launch_velocity]), PackedFloat32Array([area]), tuning.snake_width)
	area = 0.0
	flight_fed = _polyline_length(flight_path) - flight_start


## `fed_length` px of trail leave through the launch point this step. A piece fed
## earlier in the step has already moved on, so the pieces are laid out ahead of the
## launch point along the throw: one continuous ribbon, not a clump per frame.
func _feed_out(fed_length: float) -> void:
	if fed_length <= 0.0:
		return
	var piece_count: int = maxi(1, ceili(fed_length / RIBBON_PIECE_LENGTH))
	var piece_length: float = fed_length / piece_count
	var direction: Vector2 = launch_velocity.normalized()
	var local_points: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	var areas: PackedFloat32Array = PackedFloat32Array()
	for piece: int in piece_count:
		var ahead: float = fed_length - (piece + 0.5) * piece_length
		local_points.append(world.to_local(launch_point + direction * ahead))
		velocities.append(launch_velocity)
		var piece_area: float = minf(area_per_length * piece_length, area)
		areas.append(piece_area)
		area -= piece_area
	world.release_held_along(local_points, velocities, areas, tuning.snake_width)


## Its water out as still particles along the trail at once (a tear, or a throw too
## slow for a ribbon): each segment's share at its middle. They fall from there.
func _let_go() -> void:
	var local_points: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	var areas: PackedFloat32Array = PackedFloat32Array()
	var total_length: float = maxf(_polyline_length(points), 0.0001)
	for index: int in points.size() - 1:
		var segment_length: float = points[index].distance_to(points[index + 1])
		local_points.append(world.to_local((points[index] + points[index + 1]) * 0.5))
		velocities.append(Vector2.ZERO)
		areas.append(area * segment_length / total_length)
	world.release_held_along(local_points, velocities, areas, tuning.snake_width)
	area = 0.0


## True while it flies as a ribbon (released, not all out yet).
func is_flying() -> bool:
	return not flight_path.is_empty()


## Its water as dots (room-local), for the metaball renderer. Held: the whole trail,
## widening into the ball's width (`head_radius` px each side) at the head. Flying:
## what's left of the ribbon's path. `time` (real s) moves the ripple.
func get_dots(head_radius: float, time: float) -> PackedVector2Array:
	if is_flying():
		return _make_dots(flight_path, flight_start + flight_fed, 0.0, time)
	return _make_dots(points, 0.0, head_radius, time)


## Rows of dots across the polyline `path` (world) every DOT_SPACING px, from
## `start_length` px along it to its end. Each row is as wide as the snake, widening
## over the last TAPER_LENGTH px to the ball's width, with as many dots as that
## width holds drops; the ripple shifts every row across.
func _make_dots(path: PackedVector2Array, start_length: float, head_radius: float, time: float) -> PackedVector2Array:
	var dots: PackedVector2Array = PackedVector2Array()
	var drop_area: float = tuning.drop_units * WaterWorld.UNIT_AREA
	var head_width: float = maxf(tuning.snake_width, head_radius * 2.0 * HEAD_WIDTH_SHARE)
	var total: float = _polyline_length(path)
	var along: float = start_length + DOT_SPACING * 0.5
	var segment_start: float = 0.0  # length along the path where segment `index` starts
	var index: int = 0
	while along < total and index < path.size() - 1:
		var a: Vector2 = path[index]
		var b: Vector2 = path[index + 1]
		var segment_length: float = a.distance_to(b)
		if along > segment_start + segment_length or segment_length < 0.0001:
			segment_start += segment_length
			index += 1
			continue
		var tangent: Vector2 = (b - a) / segment_length
		var center: Vector2 = a + tangent * (along - segment_start)
		# Widening toward the head: 0 along most of it, 1 at the ball.
		var blend: float = 1.0 - smoothstep(0.0, TAPER_LENGTH, total - along)
		var width: float = lerpf(tuning.snake_width, head_width, blend)
		var per_row: int = maxi(1, roundi(width * DOT_SPACING / drop_area))
		# The ripple: a sine travelling toward the head (its phase grows with time
		# and falls with distance along), fading out into the ball.
		var ripple: float = sin(time * FLOW_SPEED - along * FLOW_WAVENUMBER) * FLOW_AMPLITUDE * (1.0 - blend)
		var across: Vector2 = tangent.orthogonal()
		for column: int in per_row:
			var offset: float = ((column + 0.5) / per_row - 0.5) * width * 0.7
			dots.append(world.to_local(center + across * (offset + ripple)))
		along += DOT_SPACING
	return dots


## The head (world): where the ball is.
func get_head() -> Vector2:
	return points[points.size() - 1]


## The foot (world): on the surface.
func get_foot() -> Vector2:
	return points[0]

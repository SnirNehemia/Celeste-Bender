class_name WaterSnake
extends RefCounted
## WaterSnake: the column of water that follows the ball up out of a pool
## (Water_bending.md §5.1 "The water snake", Stage W4).
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
## The model:
##   - a ROPE of POINT_COUNT points (verlet: each point remembers where it was last
##     frame, so its speed is position - previous). Point 0 is the FOOT, pinned to
##     the pool's surface; the last point is the HEAD, pinned to the ball. The points
##     between sag under snake_sag and swing behind the ball as it moves sideways.
##   - the foot SLIDES along the surface toward under the ball at snake_foot_speed,
##     pushing the water as it goes (a wave dragged along).
##   - its WATER is its length x snake_width, taken from the pool at the foot as it
##     grows and given back as it shortens (WaterWorld.draw_from_body_at /
##     return_held_to_body_at), so the pool drops while a snake rises. That water is
##     in the WaterWorld's held_area, like the ball's: the books never change.
##   - it TEARS when the pool can't feed it (dry), it gets longer than
##     snake_max_length or the foot leaves the water (and in GENTLE, when the ball
##     rises faster than snake_max_rise_speed): the water rains back as particles.
##   - it SINKS BACK (no tear) when the ball returns to the surface: its water goes
##     straight back into the pool.
##   - RELEASED (the throw), it's a RIBBON (after play-test 4): the rope's shape
##     freezes, and its water flows along it into the point where the ball was let
##     go, leaving there as particles at the ball's throw velocity. Every bit leaves
##     from the same point at the same velocity, so it follows the head's path: a
##     ribbon of water along one arc. The part at the foot falls back into the pool.
##   - DRAWN as rows of dots across the rope, widening over its last TAPER_LENGTH px
##     to the ball's width (no "ball on a stick"), with a ripple running up toward
##     the head so it looks like it flows.
##
## TWO SHAPES (WaterTuning.snake_shape; the re-planned ice, Water_bending.md §16):
##   - TRAIL (the default): no rope physics. The body lies exactly along the path the
##     ball took since it left the pool: a list of CORNERS (trail_corners, the foot
##     first) and a RUN from the last corner toward the ball. Each run's direction is
##     snapped to a multiple of snake_trail_angle_step, judged once the ball is
##     snake_trail_min_segment px from the run's start (the average direction over
##     that stretch). The ball straying more than snake_trail_tolerance off the run's
##     line makes a corner there. Steering back along the last run REWINDS it (the
##     corner goes). The foot stays at the x where the ball left the pool, riding the
##     surface. `points` is the trail with its corners rounded
##     (snake_trail_corner_radius), so everything that reads the rope (dots, dousing,
##     the ribbon, the freeze) reads the trail the same way.
##   - ROPE: the W4 model below.
##
## Positions are in WORLD coordinates (the ability's), converted to the WaterWorld's
## room-local ones at its calls. Speeds are px per REAL second while held; the flight
## runs on game time (the particles it feeds do).

enum Status { RISING, TORE, SANK }

## Rope points, foot to head. 10 is enough for a bend that reads as a rope at 64 px.
const POINT_COUNT: int = 10
## The rope steps at a FIXED rate (play-test 4: verlet takes a point's speed from
## where it was one step ago, so uneven real frames, common in the slow motion, made
## it overshoot and snap back). Each frame runs as many ROPE_STEP steps as the real
## time covers (at most MAX_ROPE_STEPS), the ends moving smoothly between frames.
const ROPE_STEP: float = 1.0 / 120.0
const MAX_ROPE_STEPS: int = 8
## Constraint passes per step: more = stiffer rope.
const ROPE_ITERATIONS: int = 8
## Rope points keep this share of their speed per 1/60 s (a little air damping).
const ROPE_DAMPING: float = 0.96
## The rope's rest length is the straight distance foot-head times this: a little
## slack, so it can bend instead of standing ruler-straight.
const ROPE_SLACK: float = 1.05
## How fast the rest length follows its target (share per real second).
const REST_FOLLOW_RATE: float = 10.0
## Drawn as dots: rows across the snake, px apart along it.
const DOT_SPACING: float = 2.0
## Released, the bit of rope this close to the foot (px) just falls back into the pool.
const FOOT_FALL_BACK_LENGTH: float = 8.0
## Torn, its water rains back at this share of each point's speed.
const TEAR_SPEED_SHARE: float = 0.2
## The foot rides the surface smoothed: averaged over this many px each side, and
## following it at FOOT_FOLLOW_RATE (share per second). Taking water makes waves
## under the foot, and a foot pinned to every crest would jerk the rope's length.
const FOOT_SAMPLE_REACH: float = 6.0
const FOOT_FOLLOW_RATE: float = 8.0
## Over its last TAPER_LENGTH px the snake widens to HEAD_WIDTH_SHARE of the ball's
## diameter, so the two read as one body of water.
const TAPER_LENGTH: float = 16.0
const HEAD_WIDTH_SHARE: float = 0.8
## The ripple running up the drawn snake: px across, radians per real second, and
## radians per px along (one wave every ~16 px).
const FLOW_AMPLITUDE: float = 0.8
const FLOW_SPEED: float = 12.0
const FLOW_WAVENUMBER: float = 0.4
## The rope doesn't go through rock (play-test 4): after each step, an inner point
## inside a solid goes back toward where it was at the step's start (still open), to
## the rock's face, and stops there. Always the side it came from, so it can't flip
## sides of a thin wall from frame to frame (that was a 20 px jitter). A point with
## no open start (the rope born across rock) takes the nearest open spot instead,
## ROPE_PUSH_OUT_DISTANCES px away in PUSH_OUT_DIRECTIONS (up first).
const ROCK_BACK_OFF_ITERATIONS: int = 5
## Fine steps close by (most points are just inside), coarser further out (a rope
## from a low foot across a bank starts deep in it).
const ROPE_PUSH_OUT_DISTANCES: Array[float] = [1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 11.0, 14.0, 18.0, 24.0]
const PUSH_OUT_DIRECTIONS: Array[Vector2] = [
	Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-0.7071, -0.7071),
	Vector2(0.7071, -0.7071), Vector2(0, 1), Vector2(-0.7071, 0.7071), Vector2(0.7071, 0.7071),
]
## Thrown slower than this (px/s), there's no ribbon: the water just falls.
const RIBBON_MIN_SPEED: float = 40.0
## The ribbon leaves as pieces at most this many px of rope long.
const RIBBON_PIECE_LENGTH: float = 2.0
## TRAIL: a rounded corner is drawn as this many short straight bits.
const CORNER_STEPS: int = 4

var world: WaterWorld
var tuning: WaterTuning
## The rope, world coordinates, and where each point was last frame (its speed).
var points: PackedVector2Array = PackedVector2Array()
var previous_points: PackedVector2Array = PackedVector2Array()
## Each point's speed last frame, px/s (for a tear).
var point_velocities: PackedVector2Array = PackedVector2Array()
## The water in the snake, px² (also in world.held_area).
var area: float = 0.0
## Length along the rope, px.
var length: float = 0.0
## Why it tore, for the overlay and tests ("" while it hasn't).
var tear_reason: String = ""
## Real time not yet stepped (less than a ROPE_STEP).
var rope_time: float = 0.0
## Each segment's rest length, px: eased toward the straight distance foot-head (x
## the slack), or toward the rope's own length while it wraps around rock (a rope
## too short for the way around would keep snapping through the corner).
var segment_rest: float = -1.0
## Some point was stopped by rock in the last frame's steps.
var touched_rock: bool = false
## The rope's points at the start of the current step (where rock sends them back).
var step_start_points: PackedVector2Array = PackedVector2Array()
## Flying (released as a ribbon): the rope's shape at release (world, foot to head),
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
## The throw group its water joins when released (Stage W5; set by the hands before
## release(), 0 for a tear): the freeze finds "the last throw" by it.
var group_id: int = 0
## TRAIL (see the header): its shape is fixed for the snake's life (a mid-hold change
## in F5 applies to the next one).
var is_trail: bool = false
## TRAIL: the corners, world coordinates, the foot first.
var trail_corners: PackedVector2Array = PackedVector2Array()
## TRAIL: the current run's snapped direction (unit), ZERO while not judged yet.
var run_direction: Vector2 = Vector2.ZERO
## TRAIL: where the current run ends: the ball, projected onto its line (world).
var run_end: Vector2 = Vector2.ZERO


## Starts a snake whose foot is on the surface under `foot` and whose head is at
## `head` (world). A rope straight between them, with its water drawn from the pool.
func _init(water_world: WaterWorld, foot: Vector2, head: Vector2) -> void:
	world = water_world
	tuning = water_world.water_tuning
	is_trail = tuning.snake_shape == WaterTuning.SnakeShape.TRAIL
	if is_trail:
		trail_corners = PackedVector2Array([foot])
		run_end = head
		points = PackedVector2Array([foot, head])
		previous_points = points.duplicate()
		point_velocities = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
		return
	for index: int in POINT_COUNT:
		var point: Vector2 = foot.lerp(head, float(index) / float(POINT_COUNT - 1))
		points.append(point)
		previous_points.append(point)
		point_velocities.append(Vector2.ZERO)


## One real-time step. `head` is the ball's new position, `head_velocity` its
## velocity (px/s). Returns RISING (still a snake), TORE or SANK; after TORE or SANK
## its water is already back in the world (rained or poured back).
func update(real_delta: float, head: Vector2, head_velocity: Vector2) -> Status:
	if real_delta <= 0.0:
		return Status.RISING
	# GENTLE: rising too fast tears it (keeping it slow is the player's job there).
	if tuning.snake_trigger == WaterTuning.SnakeTrigger.GENTLE \
			and -head_velocity.y > tuning.snake_max_rise_speed + 1.0:
		return _tear("too fast")
	# The foot slides along the surface toward under the head, dragging a wave.
	var foot: Vector2 = points[0]
	# Only GENTLE tears it (play-test 4: with the other triggers a snake you raised
	# stays until you let go or lower it back).
	var can_tear: bool = tuning.snake_trigger == WaterTuning.SnakeTrigger.GENTLE
	# (A TRAIL's foot stays where the ball left the pool: the trail starts there.)
	var new_foot_x: float = foot.x if is_trail else move_toward(foot.x, head.x, tuning.snake_foot_speed * real_delta)
	# The foot needs water right under ITSELF (the smoothed surface below finds water
	# if any of its three samples does, which let a foot at a pool's edge walk 6 px
	# into the wall, play-test 4).
	if not _has_water_under(new_foot_x, foot.y):
		if can_tear:
			return _tear("no water under the foot")
		new_foot_x = foot.x  # it would slide off the water: it stays where it was
	var surface_y: float = _get_smoothed_surface_y(new_foot_x, foot.y)
	if is_nan(surface_y):
		return _tear("no water under the foot")
	var follow: float = minf(1.0, FOOT_FOLLOW_RATE * real_delta)
	var new_foot: Vector2 = Vector2(new_foot_x, lerpf(foot.y, surface_y, follow))
	var foot_speed_x: float = (new_foot.x - foot.x) / real_delta
	if absf(foot_speed_x) > 1.0:
		world.push_at(new_foot, Vector2(foot_speed_x * tuning.snake_foot_wake, 0.0))
	if is_trail:
		_step_trail(new_foot, head)
	else:
		_step_rope(real_delta, new_foot, head)
	# Water: as long as the rope, as thick as snake_width. Grow from the pool, give
	# back when shorter.
	length = _measure_length()
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
	# Not GENTLE: the hands keep the ball within reach of the foot (a leash), so
	# this can only be a frame's overshoot.
	if length > tuning.snake_max_length and can_tear:
		return _tear("too long")
	# Back down within snake_min_length of the surface, or under it, and not rising (a
	# snake just born is that close too, but rising): it sinks into its pool. By the
	# ball's height, not the rope's length: the eased rest length lets the rope lag
	# a moment behind a ball coming down, so its length can miss the moment.
	var sinks_back: bool = head.y >= points[0].y - tuning.snake_min_length and head_velocity.y >= 0.0
	# A TRAIL can run along or below its pool's level on purpose (a slide down from the
	# pool): it sinks back only once it's been rewound to a stub at the foot.
	if is_trail:
		sinks_back = sinks_back and length <= tuning.snake_trail_min_segment
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


## TRAIL: follows the ball (`head`, world) with the snapped runs (see the header). The
## foot (corner 0) is `foot`. Then `points` = the trail, corners rounded.
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
			run_direction = snap_direction(to_head, tuning.snake_trail_angle_step)
	# The run ends at the ball projected onto its line (not yet judged: onto the line
	# the ball's direction snaps to now, so even a short stub is on a snapped angle).
	var direction: Vector2 = run_direction if run_direction != Vector2.ZERO \
		else snap_direction(to_head, tuning.snake_trail_angle_step)
	run_end = start + direction * maxf(0.0, to_head.dot(direction))
	var path: PackedVector2Array = trail_corners.duplicate()
	if run_end.distance_to(start) > 0.01:
		path.append(run_end)
	if path.size() < 2:
		path.append(start)
	points = round_corners(path, tuning.snake_trail_corner_radius)
	previous_points = points.duplicate()
	point_velocities.resize(points.size())
	point_velocities.fill(Vector2.ZERO)


## TRAIL: the ball came back to the last corner along the run before it: that corner
## goes, and the run before it is the current run again (the trail rewinds).
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


## `vector`'s direction snapped to the nearest multiple of `step_degrees` (unit).
static func snap_direction(vector: Vector2, step_degrees: float) -> Vector2:
	if vector.length() < 0.0001:
		return Vector2.UP
	var step: float = deg_to_rad(maxf(step_degrees, 1.0))
	return Vector2.from_angle(roundf(vector.angle() / step) * step)


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


## TRAIL: how long the trail would be with the ball at `head` (world): its corners,
## then straight to `head`. The hands' leash.
func get_trail_length_to(head: Vector2) -> float:
	return _polyline_length(trail_corners) + trail_corners[trail_corners.size() - 1].distance_to(head)


## Steps the rope over `real_delta` with fixed ROPE_STEP steps; the ends move from
## where they were to `foot` and `head` evenly across the steps.
func _step_rope(real_delta: float, foot: Vector2, head: Vector2) -> void:
	var last: int = POINT_COUNT - 1
	# Rest length: the straight distance with slack, or the rope's own length while it
	# wraps around rock, eased so a quick ball doesn't jerk it.
	var target_rest: float = foot.distance_to(head) * ROPE_SLACK / float(last)
	if touched_rock:
		target_rest = maxf(target_rest, _measure_length() / float(last))
	if segment_rest < 0.0:
		segment_rest = target_rest
	else:
		segment_rest = lerpf(segment_rest, target_rest, minf(1.0, REST_FOLLOW_RATE * real_delta))
	rope_time += real_delta
	var steps: int = mini(floori(rope_time / ROPE_STEP), MAX_ROPE_STEPS)
	rope_time = minf(rope_time - steps * ROPE_STEP, ROPE_STEP)
	var from_foot: Vector2 = points[0]
	var from_head: Vector2 = points[last]
	if steps == 0:
		points[0] = foot
		points[last] = head
		return
	touched_rock = false
	for step: int in steps:
		var share: float = float(step + 1) / float(steps)
		_verlet_step(from_foot.lerp(foot, share), from_head.lerp(head, share))
	for index: int in POINT_COUNT:
		point_velocities[index] = (points[index] - previous_points[index]) / ROPE_STEP


## One fixed step. Verlet: inner points move on with their speed and sag; both ends
## are pinned (the foot on the surface, the head on the ball); each segment is pulled
## toward segment_rest a few times; then points in rock go back out of it.
func _verlet_step(foot: Vector2, head: Vector2) -> void:
	var sag_step: Vector2 = Vector2(0.0, tuning.snake_sag * ROPE_STEP * ROPE_STEP)
	var damping: float = pow(ROPE_DAMPING, ROPE_STEP * 60.0)
	var last: int = POINT_COUNT - 1
	step_start_points = points.duplicate()
	for index: int in POINT_COUNT:
		var before: Vector2 = points[index]
		if index == 0:
			points[index] = foot
		elif index == last:
			points[index] = head
		else:
			points[index] += (points[index] - previous_points[index]) * damping + sag_step
		previous_points[index] = before
	for iteration: int in ROPE_ITERATIONS:
		for index: int in last:
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			var between: Vector2 = b - a
			var distance: float = between.length()
			if distance < 0.0001:
				continue
			var correction: Vector2 = between * ((distance - segment_rest) / distance)
			# Pinned ends don't move: the other point takes the whole correction.
			if index == 0:
				points[index + 1] = b - correction
			elif index + 1 == last:
				points[index] = a + correction
			else:
				points[index] = a + correction * 0.5
				points[index + 1] = b - correction * 0.5
	_push_rope_out_of_rock()


## (Stage W6: "rock" here also means pin tips, IcePins' layer 7 "ice_catch": the rope
## DRAPES over a pin bed, so a snake can be laid along it and frozen into a slide.)
## Inner points inside rock (physics layer 1, what stops the ball) go back out (see
## ROCK_BACK_OFF_ITERATIONS): halving the way between the open start of the step and
## the point in rock. They stop there (their speed into the rock is gone).
func _push_rope_out_of_rock() -> void:
	var space: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1 | IcePins.CATCH_LAYER_BIT
	for index: int in range(1, POINT_COUNT - 1):
		if not _is_rock(space, query, points[index]):
			continue
		touched_rock = true
		var open_point: Vector2 = step_start_points[index]
		if _is_rock(space, query, open_point):
			open_point = _find_open_spot(space, query, points[index])
		else:
			# Binary search for the rock's face between the open start and the point.
			var in_rock: Vector2 = points[index]
			for iteration: int in ROCK_BACK_OFF_ITERATIONS:
				var middle: Vector2 = (open_point + in_rock) * 0.5
				if _is_rock(space, query, middle):
					in_rock = middle
				else:
					open_point = middle
		points[index] = open_point
		previous_points[index] = open_point


func _is_rock(space: PhysicsDirectSpaceState2D, query: PhysicsPointQueryParameters2D, point: Vector2) -> bool:
	query.position = point
	return not space.intersect_point(query, 1).is_empty()


## The nearest open spot around `point` (rings of PUSH_OUT_DIRECTIONS at
## ROPE_PUSH_OUT_DISTANCES), or `point` itself if there's none within reach.
func _find_open_spot(space: PhysicsDirectSpaceState2D, query: PhysicsPointQueryParameters2D, point: Vector2) -> Vector2:
	for distance: float in ROPE_PUSH_OUT_DISTANCES:
		for direction: Vector2 in PUSH_OUT_DIRECTIONS:
			var candidate: Vector2 = point + direction * distance
			if not _is_rock(space, query, candidate):
				return candidate
	return point


func _measure_length() -> float:
	return _polyline_length(points)


static func _polyline_length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for index: int in path.size() - 1:
		total += path[index].distance_to(path[index + 1])
	return total


## Torn: its water rains back as loose particles, falling from where each bit was.
func _tear(reason: String) -> Status:
	tear_reason = reason
	_let_go(TEAR_SPEED_SHARE)
	return Status.TORE


## Released (WaterHandsAbility.release) with the ball's throw velocity (zero: Jump
## dropped it). Fast enough, it becomes a ribbon and returns true: keep calling
## update_flight() until it returns false. Too slow, its water just falls (false).
func release(throw_velocity: Vector2) -> bool:
	length = _measure_length()
	if throw_velocity.length() < RIBBON_MIN_SPEED or length < 0.0001:
		_let_go(0.0)
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
## along the frozen rope into the launch point at the throw speed and leaves there.
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
			PackedVector2Array([launch_velocity]), PackedFloat32Array([area]), tuning.snake_width, group_id)
	area = 0.0
	flight_fed = _polyline_length(flight_path) - flight_start


## `fed_length` px of rope leave through the launch point this step. A piece fed
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
	world.release_held_along(local_points, velocities, areas, tuning.snake_width, group_id)


## Its water out as particles along the rope at once (a tear, or a throw too slow
## for a ribbon): each segment's share at its middle, at the speed of its points
## times `speed_share`.
func _let_go(speed_share: float) -> void:
	var local_points: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	var areas: PackedFloat32Array = PackedFloat32Array()
	var total_length: float = maxf(_measure_length(), 0.0001)
	var along: float = 0.0
	for index: int in points.size() - 1:
		var segment_length: float = points[index].distance_to(points[index + 1])
		var middle: Vector2 = (points[index] + points[index + 1]) * 0.5
		var velocity: Vector2 = (point_velocities[index] + point_velocities[index + 1]) * 0.5 * speed_share
		if along + segment_length * 0.5 < FOOT_FALL_BACK_LENGTH:
			velocity = Vector2.ZERO  # the foot falls back into its pool
		local_points.append(world.to_local(middle))
		velocities.append(velocity)
		areas.append(area * segment_length / total_length)
		along += segment_length
	world.release_held_along(local_points, velocities, areas, tuning.snake_width, group_id)
	area = 0.0


## True while it flies as a ribbon (released, not all out yet).
func is_flying() -> bool:
	return not flight_path.is_empty()


## Its water as dots (room-local), for the metaball renderer. Held: the whole rope,
## widening into a ball of `head_radius` px at the head. Flying: what's left of the
## ribbon's path. `time` (real s) moves the ripple; `with_ripple` false leaves it out
## (the freeze: ice takes the trail's exact shape, no wobble).
func get_dots(head_radius: float, time: float, with_ripple: bool = true) -> PackedVector2Array:
	if is_flying():
		return _make_dots(flight_path, flight_start + flight_fed, 0.0, time, with_ripple)
	return _make_dots(points, 0.0, head_radius, time, with_ripple)


## Rows of dots across the polyline `path` (world) every DOT_SPACING px, from
## `start_length` px along it to its end. Each row is as wide as the snake, widening
## over the last TAPER_LENGTH px to the ball's width, with as many dots as that
## width holds drops; the ripple shifts every row across.
func _make_dots(path: PackedVector2Array, start_length: float, head_radius: float, time: float,
		with_ripple: bool = true) -> PackedVector2Array:
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
		var ripple: float = 0.0
		if with_ripple:
			ripple = sin(time * FLOW_SPEED - along * FLOW_WAVENUMBER) * FLOW_AMPLITUDE * (1.0 - blend)
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

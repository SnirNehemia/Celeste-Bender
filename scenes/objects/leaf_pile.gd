@tool
class_name LeafPile
extends Node2D
## Leaf pile: a mound of loose leaves lying on the floor. Cosmetic, but useful for
## level design: it's drawn IN FRONT of other objects, so it can hide a pressure
## plate, a crate's goal, or the entrance to a secret path. Wind blows it away.
##
## Place the node ON the floor, at the CENTER of the mound's base.
##
## What moves the leaves:
##   - a gust (or dash wake) blows the leaves within `gust_reach` of where it came
##     from (the Pushable contract's optional receive_gust_from(), pushable.gd)
##   - anything walking or sliding through the pile (the player, a crate) kicks the
##     leaves it touches a little
## Kicked or blown leaves then FALL LIKE LEAVES (see _fly_leaf):
##   - air drag soon eats up the launch speed, and the fall speed is capped very low
##   - once slow, each leaf swings side to side like a pendulum, left-right-left,
##     dropping fastest in the middle of each swing and almost hanging at the ends,
##     tilting with the swing
##   - it lands on whatever solid it meets (floors, crates, doors, platforms)
## A landed leaf remembers what it landed on (its SUPPORT): it rides along when that
## moves (a sail, a leaf platform, a gusted crate), and starts falling again when
## nothing is under it any more (the crate slid away, the door opened).
## A leaf that ends up INSIDE something solid (a crate slid over it, a door closed
## on it) pops out through the nearest free side and flutters from there, so a
## sliding crate shoves leaves ahead of it like a snowplow (see _unbury_leaf).
##
## Why not one node or particle per leaf? 60 RigidBody2Ds would be heavy and would
## tumble like stones, and CPUParticles2D can't land on floors. Instead this one node
## keeps a few arrays (position, velocity, rotation... per leaf), moves them with its
## own small simulation, asks the physics world "is this point solid?" to land them,
## and draws them all in one _draw().
##
## Physics: a sensor Area2D on layer 4 ("pushable") so gusts find it, looking at
## layers 1 and 2 to notice crates and the player passing through. It grows to
## cover wherever the leaves have landed, so scattered leaves can be blown again.
## A room reset (death / R) puts every leaf back in the pile.

## Not in the §2 color key: dry, muted greens and golds (kept clear of the windmill
## yellow, projectile orange and crate brown).
const LEAF_COLORS: Array[Color] = [
	Color(0.62, 0.6, 0.32), Color(0.5, 0.55, 0.28), Color(0.7, 0.63, 0.38),
	Color(0.42, 0.5, 0.3), Color(0.6, 0.48, 0.32),
]
## Above this speed a leaf is "being blown" (tumbles); below it, it flutters.
const FLUTTER_START_SPEED: float = 50.0
## Leaves that fall this far below the pile (a pit) stop being simulated.
const LOST_DISTANCE: float = 400.0
## A buried leaf looks this far (px) for a free spot, in these directions. Nearest
## exit wins; no downward exit, since that's normally the floor.
const MAX_UNBURY_DISTANCE: int = 24
const UNBURY_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.LEFT, Vector2.RIGHT]

## Size of the mound, px.
@export var pile_width: float = 36.0:
	set(value):
		pile_width = value
		_generate_leaves()
@export var pile_height: float = 6.0:
	set(value):
		pile_height = value
		_generate_leaves()
@export_range(1, 200) var leaf_count: int = 60:
	set(value):
		leaf_count = value
		_generate_leaves()
## Change to get a differently shuffled pile (same seed = same pile every time).
@export var random_seed: int = 7:
	set(value):
		random_seed = value
		_generate_leaves()

@export_group("Leaf physics")
## Gravity on a leaf, px/s². Low: leaves are light.
@export var gravity: float = 120.0
## Top fall speed while fluttering, px/s (mid-swing; slower at the ends).
@export var fall_speed: float = 14.0
## Peak sideways speed of the swing, px/s.
@export var sway_speed: float = 22.0
## Swings per second (each leaf gets ±20% so they don't move in lockstep).
@export var sway_frequency: float = 0.9
## Air drag, 1/s: the launch speed shrinks by a factor e^(-drag × t).
## 2.0 = only 14% left after 1 s.
@export var air_drag: float = 2.0
## Gusts blow leaves this far from the gust's origin, px.
@export var gust_reach: float = 44.0
## A body must move at least this fast to kick leaves, px/s.
@export var kick_min_speed: float = 30.0

## Per-leaf state, all in this node's local coordinates. Index i = leaf i.
var leaf_positions: PackedVector2Array = PackedVector2Array()
var leaf_velocities: PackedVector2Array = PackedVector2Array()
var leaf_rotations: PackedFloat32Array = PackedFloat32Array()
## Position in the swing cycle (radians) and how fast it advances (radians/s).
var leaf_sway_phases: PackedFloat32Array = PackedFloat32Array()
var leaf_sway_rates: PackedFloat32Array = PackedFloat32Array()
## 1 = in the air (simulated), 0 = resting.
var leaf_is_flying: PackedByteArray = PackedByteArray()
var leaf_colors: PackedColorArray = PackedColorArray()
## The body each landed leaf rests on, and where that body was last frame (world
## space), so we can move the leaf by however much the body moved. null = no support
## to follow: leaves still in the untouched pile (they lie on each other, not on a
## solid, so they must not be checked), and leaves lost in a pit.
var leaf_supports: Array[Node2D] = []
var leaf_support_positions: PackedVector2Array = PackedVector2Array()
## What each body touching the pile looked like last frame (its position, or a
## door's open_amount), keyed by the body's instance id. Lets us tell "a crate is
## sitting in the pile" (nothing to do) from "a crate is moving through it".
var last_body_states: Dictionary = {}
## Where each leaf lies in the untouched pile, for reset().
var home_positions: PackedVector2Array = PackedVector2Array()
var home_rotations: PackedFloat32Array = PackedFloat32Array()

## One leaf's shape: a 4x2 px diamond, drawn rotated at each leaf's position.
var leaf_shape: PackedVector2Array = PackedVector2Array([
	Vector2(-2.0, 0.0), Vector2(0.0, -1.0), Vector2(2.0, 0.0), Vector2(0.0, 1.0)])

## Randomness for launches. Separate from the pile layout's seeded generator.
var launch_random: RandomNumberGenerator = RandomNumberGenerator.new()
## Reused for every "is this point solid?" question (saves allocating one per leaf).
var point_query: PhysicsPointQueryParameters2D

var sensor: Area2D
var sensor_shape_node: CollisionShape2D


func _ready() -> void:
	z_index = 1  # in front of plates, crates and the player's feet
	sensor = Area2D.new()
	sensor.collision_layer = 8  # bit value of layer 4, "pushable"
	sensor.collision_mask = 1 | 2  # crates ("world") and the player
	sensor_shape_node = CollisionShape2D.new()
	sensor_shape_node.shape = RectangleShape2D.new()
	sensor.add_child(sensor_shape_node)
	add_child(sensor)
	_generate_leaves()
	if Engine.is_editor_hint():
		return
	point_query = PhysicsPointQueryParameters2D.new()
	point_query.collision_mask = 1  # land on "world": floors, crates, doors, platforms
	point_query.collide_with_areas = false
	launch_random.randomize()
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Resting leaves can only be disturbed by something that moves (a crate, the
	# player, a platform, a door) touching the pile, so when nothing like that is
	# around (the usual case) we skip all of their checks: an idle pile costs ~nothing.
	var any_changed: bool = false
	if _kick_from_moving_bodies():
		any_changed = _update_resting_leaves()
	for leaf_index: int in leaf_positions.size():
		if leaf_is_flying[leaf_index] == 1:
			any_changed = true
			_fly_leaf(leaf_index, delta)
	if any_changed:
		_update_sensor_bounds()
		queue_redraw()


## The Pushable contract (fallback when the gust's origin is unknown): blow every leaf.
func receive_gust(direction: Vector2, strength: float) -> void:
	receive_gust_from(direction, strength, Pushable.NO_SOURCE)


## The Pushable contract, with the gust's origin: only leaves within gust_reach are
## blown, harder the closer they are, and spread a bit away from the origin.
func receive_gust_from(direction: Vector2, strength: float, source_position: Vector2) -> void:
	var has_source: bool = source_position.is_finite()
	# The all-around (neutral) gust hands each object "away from the player, toward
	# YOUR origin" as its direction (AirBlast.push_around). If that's what we got,
	# blow each leaf straight away from the player instead, and don't skip leaves
	# "behind" the gust (an all-around gust has no behind).
	var is_all_around: bool = has_source and global_position != source_position \
		and direction.is_equal_approx((global_position - source_position).normalized())
	for leaf_index: int in leaf_positions.size():
		var push_direction: Vector2 = direction
		var falloff: float = 1.0
		if has_source:
			var from_source: Vector2 = to_global(leaf_positions[leaf_index]) - source_position
			var distance: float = from_source.length()
			if distance > gust_reach:
				continue
			var outward: Vector2 = from_source / distance if distance > 0.01 else direction
			if is_all_around:
				push_direction = outward
			else:
				if outward.dot(direction) < -0.2:
					continue  # behind an aimed gust
				# Mostly along the gust, fanned out a little: air spreads.
				push_direction = (direction * 0.6 + outward * 0.4).normalized()
			falloff = 1.0 - 0.5 * distance / gust_reach
		var launch_speed: float = strength * falloff * launch_random.randf_range(0.35, 0.9)
		# Plus a little upward puff: air gets under leaves even in a sideways gust.
		_launch_leaf(leaf_index, push_direction * launch_speed
			+ Vector2(0.0, -launch_random.randf_range(60.0, 120.0)))


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	leaf_positions = home_positions.duplicate()
	leaf_rotations = home_rotations.duplicate()
	leaf_is_flying.fill(0)
	leaf_velocities.fill(Vector2.ZERO)
	leaf_supports.fill(null)
	_update_sensor_bounds()
	queue_redraw()


## One leaf, one physics step.
func _fly_leaf(leaf_index: int, delta: float) -> void:
	var velocity: Vector2 = leaf_velocities[leaf_index]
	# Air drag on the launch speed (exponential decay), then gravity.
	velocity *= exp(-air_drag * delta)
	velocity.y += gravity * delta

	var phase: float = leaf_sway_phases[leaf_index] + leaf_sway_rates[leaf_index] * delta
	leaf_sway_phases[leaf_index] = phase
	# 0 while being blown fast, 1 once slow enough to flutter: the swing fades in.
	# Only the THROW counts (sideways speed and upward speed), not falling: a leaf
	# that has stopped rising starts fluttering right away.
	var throw_speed: float = maxf(absf(velocity.x), -velocity.y)
	var flutter: float = clampf(1.0 - throw_speed / FLUTTER_START_SPEED, 0.0, 1.0)

	# Pendulum fall: x = A·sin(phase), so sideways speed ∝ cos(phase): fastest in the
	# middle of a swing, zero at its ends. Falling follows the same rhythm (|cos|):
	# the leaf swoops down through the middle and almost hangs at each end.
	var swing: float = cos(phase)
	var sway_velocity_x: float = sway_speed * swing * flutter
	var fall_cap: float = lerpf(fall_speed * 1.5, fall_speed * (0.2 + 0.8 * absf(swing)), flutter)
	velocity.y = minf(velocity.y, fall_cap)

	# Rotation: tumbles with its sideways speed while blown; while fluttering it
	# tilts with the swing (most tilted at the ends, like a real leaf "catching" air).
	var tumbled: float = leaf_rotations[leaf_index] + velocity.x * 0.08 * delta
	leaf_rotations[leaf_index] = lerpf(tumbled, 0.6 * sin(phase), flutter * minf(6.0 * delta, 1.0))

	var position_now: Vector2 = leaf_positions[leaf_index]
	var motion: Vector2 = (velocity + Vector2(sway_velocity_x, 0.0)) * delta
	var position_next: Vector2 = position_now + motion
	if _find_solid(position_next) != null:
		# Blocked. First: are we INSIDE something (a crate caught up with a leaf it
		# kicked)? From in there every direction looks blocked and the leaf would
		# "land" inside, so get out first. Only checked when blocked, to save a query.
		if _unbury_leaf(leaf_index):
			return
		# Try the sideways part alone (slide along a floor or ceiling)...
		var position_sideways: Vector2 = position_now + Vector2(motion.x, 0.0)
		if motion.x != 0.0 and _find_solid(position_sideways) == null:
			position_now = position_sideways
		else:
			velocity.x *= -0.3  # bumped a wall: bounce back a little
		# ...and if what's in the way is BELOW a falling leaf, it has landed.
		var below: Node2D = _find_solid(position_now + Vector2(0.0, maxf(motion.y, 0.5)))
		if motion.y > 0.0 and below != null:
			_land_leaf(leaf_index, position_now, below)
			return
		elif motion.y < 0.0:
			velocity.y = 0.0  # hit a ceiling
	else:
		position_now = position_next

	leaf_positions[leaf_index] = position_now
	leaf_velocities[leaf_index] = velocity
	if position_now.y > LOST_DISTANCE:
		leaf_is_flying[leaf_index] = 0  # fell into a pit: stop simulating it


func _land_leaf(leaf_index: int, landing_position: Vector2, support: Node2D) -> void:
	leaf_positions[leaf_index] = landing_position
	leaf_velocities[leaf_index] = Vector2.ZERO
	leaf_is_flying[leaf_index] = 0
	leaf_supports[leaf_index] = support
	leaf_support_positions[leaf_index] = support.global_position
	# Lands mostly flat, keeping a hint of its last tilt.
	leaf_rotations[leaf_index] *= 0.3


func _launch_leaf(leaf_index: int, launch_velocity: Vector2) -> void:
	leaf_is_flying[leaf_index] = 1
	leaf_velocities[leaf_index] = launch_velocity
	leaf_supports[leaf_index] = null


## Resting leaves: landed ones follow their support and fall again if it's gone
## from under them; any resting leaf (untouched pile leaves too) that got buried
## inside something pops out. Returns true if any leaf moved (so we redraw).
func _update_resting_leaves() -> bool:
	var any_changed: bool = false
	# These checks cost a physics query or two per leaf, so a resting leaf is only
	# re-checked every 4th frame (each on a different frame, so the work is spread
	# out), unless its support just moved. 4 frames = 1/15 s: too short to notice.
	var check_slot: int = Engine.get_physics_frames() % 4
	for leaf_index: int in leaf_positions.size():
		if leaf_is_flying[leaf_index] == 1:
			continue
		var support: Node2D = leaf_supports[leaf_index]
		var has_support: bool = support != null
		# is_instance_valid: the support may have been deleted (queue_free) since.
		if has_support and not is_instance_valid(support):
			_launch_leaf(leaf_index, Vector2.ZERO)
			any_changed = true
			continue
		var support_moved: bool = false
		if has_support:
			var support_motion: Vector2 = support.global_position - leaf_support_positions[leaf_index]
			support_moved = support_motion != Vector2.ZERO
			if support_moved:
				# The pile isn't rotated or scaled, so a world-space shift is the same
				# shift in our local coordinates.
				leaf_positions[leaf_index] += support_motion
				leaf_support_positions[leaf_index] = support.global_position
				any_changed = true
		if not support_moved and leaf_index % 4 != check_slot:
			continue
		if _unbury_leaf(leaf_index):
			any_changed = true
		elif has_support and _find_solid(leaf_positions[leaf_index] + Vector2(0.0, 1.0)) == null:
			# Nothing just under the leaf any more (landed leaves stop at most 0.5 px
			# above a surface, so 1 px down always reaches it). Launching with zero
			# speed = just let go: it flutters straight down.
			_launch_leaf(leaf_index, Vector2.ZERO)
			any_changed = true
	return any_changed


## If the leaf is inside something solid, moves it to the nearest free spot (up,
## left or right, 1 px at a time) and lets it flutter off with a little push out.
## Returns true if it was buried. Untouched pile leaves never need this unless
## something moves into them, so the common case is one query that finds nothing.
func _unbury_leaf(leaf_index: int) -> bool:
	var buried_position: Vector2 = leaf_positions[leaf_index]
	if _find_solid(buried_position) == null:
		return false
	for step: int in range(1, MAX_UNBURY_DISTANCE + 1):
		for exit_direction: Vector2 in UNBURY_DIRECTIONS:
			var candidate: Vector2 = buried_position + exit_direction * step
			if _find_solid(candidate) == null:
				leaf_positions[leaf_index] = candidate
				_launch_leaf(leaf_index, exit_direction * launch_random.randf_range(10.0, 30.0)
					+ Vector2(0.0, -launch_random.randf_range(10.0, 30.0)))
				return true
	return true  # deeply buried (inside a big solid): leave it, nothing sensible to do


## Players and crates moving through the pile kick up the resting leaves they touch.
## Returns true if anything touching the pile MOVED since last frame (so could have
## disturbed resting leaves): a player or crate, a moving platform, or a door that
## is opening/closing. Plain room solids and things standing still don't count.
func _kick_from_moving_bodies() -> bool:
	var any_moved: bool = false
	var current_states: Dictionary = {}
	for body: Node2D in sensor.get_overlapping_bodies():
		if not (body is CharacterBody2D or body is AnimatableBody2D or body is Door):
			continue  # a plain room solid: never moves
		var door: Door = body as Door
		# A door doesn't move, it changes size; anything else, compare positions.
		# (if/else, not a ternary: the two values have different types, float and
		# Vector2, and debug builds reject a ternary whose branches don't match.)
		var state: Variant
		if door != null:
			state = door.open_amount
		else:
			state = body.global_position
		var body_id: int = body.get_instance_id()
		current_states[body_id] = state
		if last_body_states.get(body_id) != state:
			any_moved = true
		var mover: CharacterBody2D = body as CharacterBody2D
		if mover == null or mover.velocity.length() < kick_min_speed:
			continue
		# Both the player and crates have their origin at the feet / bottom-center.
		var feet: Vector2 = to_local(mover.global_position)
		var half_width: float = _get_body_half_width(mover) + 2.0
		for leaf_index: int in leaf_positions.size():
			if leaf_is_flying[leaf_index] == 1:
				continue
			var offset: Vector2 = leaf_positions[leaf_index] - feet
			if absf(offset.x) < half_width and offset.y > -12.0 and offset.y < 2.0:
				_launch_leaf(leaf_index, Vector2(
					mover.velocity.x * launch_random.randf_range(0.4, 0.9),
					-launch_random.randf_range(40.0, 80.0)))
	# Only bodies still touching the pile are remembered, so this stays tiny.
	last_body_states = current_states
	return any_moved


## Half the width of a body's first rectangle collision shape (8 px fallback).
func _get_body_half_width(body: CharacterBody2D) -> float:
	for child: Node in body.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			return (shape_node.shape as RectangleShape2D).size.x / 2.0
	return 4.0


## "What solid is at this point (local coordinates)?" asked of the physics world.
## Returns the body there, or null if the point is in open air.
func _find_solid(local_point: Vector2) -> Node2D:
	point_query.position = to_global(local_point)
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(point_query, 1)
	if results.is_empty():
		return null
	return results[0]["collider"] as Node2D


## Builds the untouched pile: leaves scattered under a parabola-shaped mound,
## mostly lying flat. Uses its own seeded generator so the pile looks the same in
## the editor and in game.
func _generate_leaves() -> void:
	if not is_inside_tree():
		return  # setters run while the scene loads; _ready() calls us after that
	var layout_random: RandomNumberGenerator = RandomNumberGenerator.new()
	layout_random.seed = random_seed
	home_positions = PackedVector2Array()
	home_rotations = PackedFloat32Array()
	leaf_sway_phases = PackedFloat32Array()
	leaf_sway_rates = PackedFloat32Array()
	leaf_colors = PackedColorArray()
	var half_width: float = pile_width / 2.0
	for leaf_index: int in leaf_count:
		var x: float = layout_random.randf_range(-half_width, half_width)
		# Mound height at x: pile_height in the middle, 0 at the edges (1 - t²).
		var relative_x: float = x / half_width
		var mound_height: float = maxf(pile_height * (1.0 - relative_x * relative_x), 1.0)
		home_positions.append(Vector2(x, -layout_random.randf_range(0.5, mound_height)))
		home_rotations.append(layout_random.randf_range(-0.5, 0.5))
		leaf_sway_phases.append(layout_random.randf_range(0.0, TAU))
		leaf_sway_rates.append(TAU * sway_frequency * layout_random.randf_range(0.8, 1.2))
		leaf_colors.append(LEAF_COLORS[layout_random.randi_range(0, LEAF_COLORS.size() - 1)])
	leaf_positions = home_positions.duplicate()
	leaf_rotations = home_rotations.duplicate()
	leaf_velocities = PackedVector2Array()
	leaf_velocities.resize(leaf_count)
	leaf_is_flying = PackedByteArray()
	leaf_is_flying.resize(leaf_count)  # resize() fills with zeros: all resting
	leaf_supports.resize(leaf_count)  # all null: untouched pile leaves follow nothing
	leaf_supports.fill(null)
	leaf_support_positions = PackedVector2Array()
	leaf_support_positions.resize(leaf_count)
	_update_sensor_bounds()
	queue_redraw()


## Makes the sensor cover every leaf (plus a margin), wherever they've ended up.
func _update_sensor_bounds() -> void:
	if sensor_shape_node == null or leaf_positions.is_empty():
		return
	var bounds: Rect2 = Rect2(leaf_positions[0], Vector2.ZERO)
	for leaf_position: Vector2 in leaf_positions:
		bounds = bounds.expand(leaf_position)
	bounds = bounds.grow(3.0)
	(sensor_shape_node.shape as RectangleShape2D).size = bounds.size
	sensor_shape_node.position = bounds.get_center()


func _draw() -> void:
	for leaf_index: int in leaf_positions.size():
		# draw_set_transform moves and rotates everything drawn after it, so the
		# same 4-point diamond can be drawn at every leaf's position and angle.
		draw_set_transform(leaf_positions[leaf_index], leaf_rotations[leaf_index])
		draw_colored_polygon(leaf_shape, leaf_colors[leaf_index])
	draw_set_transform(Vector2.ZERO, 0.0)

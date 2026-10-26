@tool
class_name LeafPile
extends Node2D
## Leaf pile: a mound of loose leaves lying on the floor. Cosmetic, but useful for
## level design: it's drawn IN FRONT of other objects, so it can hide a pressure
## plate, a crate's goal, or the entrance to a secret path. Wind blows it away.
##
## Place the node ON the floor, at the CENTER of the mound's base. A pile placed in
## the air pours down when its room starts running (and after every reset), like
## leaves that lost what they lay on.
##
## What moves the leaves:
##   - a gust blows the leaves within `gust_reach` of where it came
##     from (the Pushable contract's optional receive_gust_from(), pushable.gd)
##   - anything walking or sliding through the pile (the player, a crate) kicks the
##     leaves it touches a little
## Kicked or blown leaves then FALL LIKE LEAVES (see _fly_leaf):
##   - air drag soon eats up the launch speed, and the fall speed is capped very low
##   - once slow, each leaf swings side to side like a pendulum, left-right-left,
##     dropping fastest in the middle of each swing and almost hanging at the ends,
##     tilting with the swing
##   - it lands on whatever solid it meets (floors, crates, doors, platforms), or ON
##     ANOTHER LEAF (F7 play-test): leaves pile up instead of all lying in one layer
## A landed leaf remembers what it landed on (its SUPPORT): it rides along when that
## moves (a sail, a leaf platform, a gusted crate), and starts falling again when
## nothing is under it any more (the crate slid away, the door opened, the leaf under
## it blew away or burnt).
## A leaf that ends up INSIDE something solid (a crate slid over it, a door closed
## on it) pops out through the nearest free side and flutters from there, so a
## sliding crate shoves leaves ahead of it like a snowplow (see _unbury_leaf).
##
## Why not one node or particle per leaf? 60 RigidBody2Ds would be heavy and would
## tumble like stones, and CPUParticles2D can't land on floors. Instead this one node
## keeps a few arrays (position, velocity, rotation... per leaf), moves them with its
## own small simulation, asks the physics world "is this point solid?" to land them,
## and draws them all in one _draw().
## Leaves landing on leaves: resting leaves are kept in 4 px buckets (`resting_buckets`),
## so a falling leaf only looks at the few leaves right under it, not at all of them.
## Leaves overlap a little when they stack (stack_spacing < a leaf's 2 px height).
## They heap up like sand: a leaf landing off-center on another only stays if
## something also holds up its overhanging side, otherwise it slides off outward and
## keeps falling, so heaps get rounded slopes instead of lacy twig-like chains. And
## whenever something moved, resting leaves with nothing under them settle (fall
## again): no leaves hanging in the air after you run through the pile.
## Drawn ground_sink px LOWER than where they physically lie, so the bottom leaves
## overlap the ground's ragged painted edge instead of showing a strip of sky under
## the pile. Only the drawing moves: wind, kicks and landing use the real positions.
##
## The untouched pile is laid out on a jittered grid under the mound (F7 play-test:
## purely random spots left holes), so it reads as one dense heap.
##
## Physics: a sensor Area2D on layer 4 ("pushable") so gusts find it, looking at
## layers 1 and 2 to notice crates and the player passing through. It grows to
## cover wherever the leaves have landed, so scattered leaves can be blown again.
## A room reset (death / R) puts every leaf back in the pile.
##
## FIRE (Stage F7, Fire_bending.md §6.2; reworked after the F7 play-test): the LEAVES
## burn, each on its own. The pile is FLAMMABLE (flammable.gd: group "flammable",
## ignite()/ignite_at()/is_burning()/snuff()/get_fire_rect()). It has NO catch area on
## layer 6: a fireball doesn't stop at leaves, it lights the ones it flies through
## and keeps going (Fireball._light_leaves_passed). The first flame makes a
## LeafFire child (scenes/objects/fire/leaf_fire.gd) that owns every leaf's fire:
## lone burning leaves are harmless embers that light what they touch and burn away,
## and a heap of them lying together becomes a Bonfire. Burning leaves still blow,
## fall and get kicked like any leaf (that's the ember rain). Burnt leaves are gone
## until R.

## Not in the §2 color key: dry, muted greens and golds (kept clear of the windmill
## yellow, projectile orange and crate brown).
const LEAF_COLORS: Array[Color] = [
	Color(0.62, 0.6, 0.32), Color(0.5, 0.55, 0.28), Color(0.7, 0.63, 0.38),
	Color(0.42, 0.5, 0.3), Color(0.6, 0.48, 0.32),
]
## Burning leaves (Fire_bending.md §9.1): they flicker between ember red and yellow,
## and a lone one chars toward black at the end of its burn.
const LEAF_EMBER_COLOR: Color = Color("#8A2410")
const LEAF_HOT_COLOR: Color = Color("#FFD34D")
const LEAF_CHAR_COLOR: Color = Color(0.1, 0.08, 0.07)
## Above this speed a leaf is "being blown" (tumbles); below it, it flutters.
const FLUTTER_START_SPEED: float = 50.0
## Leaves that fall this far below the pile (a pit) stop being simulated.
const LOST_DISTANCE: float = 400.0
## A buried leaf looks this far (px) for a free spot, in these directions. Nearest
## exit wins; no downward exit, since that's normally the floor.
const MAX_UNBURY_DISTANCE: int = 24
const UNBURY_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
## Size of the resting-leaf buckets, px.
const STACK_BUCKET: float = 4.0
## No support leaf: resting on a solid (or untouched in the pile).
const NO_LEAF: int = -1

## Size of the mound, px.
@export var pile_width: float = 36.0:
	set(value):
		pile_width = value
		_generate_leaves()
@export var pile_height: float = 6.0:
	set(value):
		pile_height = value
		_generate_leaves()
@export_range(1, 300) var leaf_count: int = 60:
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
## Leaves landing on leaves: a leaf comes to rest this many px above the leaf under it
## (less than a leaf's 2 px height, so they overlap a little: no air between them),
## and lands on it if their middles are at most stack_reach px apart sideways
## (further out it slides off and keeps falling, so heaps get sloped sides).
@export var stack_spacing: float = 0.6
@export var stack_reach: float = 2.0
## Like sand: a leaf landing within stack_center_reach px of the middle of the leaf
## under it stays. Further out it overhangs, and stays only if another leaf (or the
## ground) is under its overhanging side; otherwise it slides off that way by
## slide_step px a frame and keeps falling.
@export var stack_center_reach: float = 1.0
@export var slide_step: float = 0.8
## A resting leaf stays put while there's a leaf at most settle_reach px to the side
## and settle_depth px under it, or the ground within settle_depth; otherwise it
## settles (falls again). Looser than landing, so a leaf that just landed never
## settles at once.
@export var settle_reach: float = 2.5
@export var settle_depth: float = 3.0

@export_group("Leaf look")
## Leaves are drawn this many px below where they physically lie, so the pile's
## bottom overlaps the ground's painted edge (it's ragged: sky shows through the top
## pixel rows of the floor tiles). Look only.
@export var ground_sink: float = 2.0:
	set(value):
		ground_sink = value
		queue_redraw()

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
## solid, so they must not be checked), leaves resting on a leaf, and leaves lost in
## a pit.
var leaf_supports: Array[Node2D] = []
var leaf_support_positions: PackedVector2Array = PackedVector2Array()
## The leaf each landed leaf rests ON (NO_LEAF = a solid, or untouched in the pile).
var leaf_support_leaves: PackedInt32Array = PackedInt32Array()
## Resting leaves by STACK_BUCKET bucket: Vector2i -> Array of leaf indices. Rebuilt
## when `resting_buckets_dirty` (a leaf left its spot) and a falling leaf asks.
var resting_buckets: Dictionary = {}
var resting_buckets_dirty: bool = true
## A leaf took off or burnt away: leaves resting on it must check whether they fall.
var leaf_supports_dirty: bool = false
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

## Reused by _draw() every frame: the drawn leaves' corners and colors, and the
## triangle list joining them (built once per leaf count).
var draw_points: PackedVector2Array = PackedVector2Array()
var draw_colors: PackedColorArray = PackedColorArray()
var draw_indices: PackedInt32Array = PackedInt32Array()

## Randomness for launches. Separate from the pile layout's seeded generator.
var launch_random: RandomNumberGenerator = RandomNumberGenerator.new()
## Reused for every "is this point solid?" question (saves allocating one per leaf).
var point_query: PhysicsPointQueryParameters2D

var sensor: Area2D
var sensor_shape_node: CollisionShape2D

## Fire (Stage F7): made the first time anything lights a leaf (so Air rooms never
## pay for it). null = nothing ever burnt here.
var fire: LeafFire


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
	add_to_group(Flammable.GROUP)
	# Check once, on our first physics frame (when our room wakes up, see
	# RoomManager), whether the pile has something under it: a pile placed in the
	# air (play-test, editor levels) pours down instead of hanging there. On the
	# floor nothing moves and it costs one check per leaf, once.
	leaf_supports_dirty = true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Resting leaves can only be disturbed by something that moves (a crate, the
	# player, a platform, a door) touching the pile, so when nothing like that is
	# around (the usual case) we skip all of their checks: an idle pile costs ~nothing.
	var any_changed: bool = false
	if fire != null and (fire.burning_count > 0 or fire.primed_count > 0):
		fire.update(delta)
		any_changed = true  # embers flicker (primed leaves glow): redraw every frame
	if _kick_from_moving_bodies():
		any_changed = _update_resting_leaves() or any_changed
	if leaf_supports_dirty:
		any_changed = _drop_unsupported_leaves() or any_changed
	for leaf_index: int in leaf_positions.size():
		if leaf_is_flying[leaf_index] == 1 and not _is_gone(leaf_index):
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
## Burning leaves: a lone ember the gust reaches is blown OUT and turns to ash (F7
## play-test). A gust that reaches any leaf of a bonfire's heap blows the WHOLE heap
## apart ("a close gust turns a bonfire off", even a heap wider than gust_reach), and
## those leaves fly on still burning, as embers (a second gust puts them out).
func receive_gust_from(direction: Vector2, strength: float, source_position: Vector2) -> void:
	var has_source: bool = source_position.is_finite()
	# Bonfires (indices into fire.bonfires) whose heap this gust reaches.
	var reached_bonfires: Array[int] = []
	# The all-around (neutral) gust hands each object "away from the player, toward
	# YOUR origin" as its direction (AirBlast.push_around). If that's what we got,
	# blow each leaf straight away from the player instead, and don't skip leaves
	# "behind" the gust (an all-around gust has no behind).
	var is_all_around: bool = has_source and global_position != source_position \
		and direction.is_equal_approx((global_position - source_position).normalized())
	for leaf_index: int in leaf_positions.size():
		if _is_gone(leaf_index):
			continue
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
		if fire != null and fire.is_leaf_burning(leaf_index):
			if fire.held_by[leaf_index] < 0:
				fire.snuff_leaf(leaf_index)  # a lone ember: blown out, ash
				continue
			if not reached_bonfires.has(fire.held_by[leaf_index]):
				reached_bonfires.append(fire.held_by[leaf_index])
		_blow_leaf(leaf_index, push_direction, strength * falloff)
	if reached_bonfires.is_empty():
		return
	# The rest of each reached heap goes too, along the gust (and a little up).
	for leaf_index: int in leaf_positions.size():
		if leaf_is_flying[leaf_index] == 0 and reached_bonfires.has(fire.held_by[leaf_index]):
			_blow_leaf(leaf_index, direction, strength * 0.6)


## Throws one leaf along `push_direction` at about `speed` px/s (randomized), plus a
## little upward puff: air gets under leaves even in a sideways gust.
func _blow_leaf(leaf_index: int, push_direction: Vector2, speed: float) -> void:
	var launch_speed: float = speed * launch_random.randf_range(0.35, 0.9)
	_launch_leaf(leaf_index, push_direction * launch_speed
		+ Vector2(0.0, -launch_random.randf_range(60.0, 120.0)))


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	leaf_positions = home_positions.duplicate()
	leaf_rotations = home_rotations.duplicate()
	leaf_is_flying.fill(0)
	leaf_velocities.fill(Vector2.ZERO)
	leaf_supports.fill(null)
	leaf_support_leaves.fill(NO_LEAF)
	resting_buckets_dirty = true
	leaf_supports_dirty = true  # back home: a pile placed in the air pours down again
	if fire != null:
		fire.reset()
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
	# A burning leaf curls up and drops faster (the ember rain reaches the ground lit).
	if fire != null and fire.leaf_states[leaf_index] == LeafFire.LeafState.BURNING:
		fall_cap *= fire.fire_tuning.leaf_ember_fall_scale
	velocity.y = minf(velocity.y, fall_cap)

	# Rotation: tumbles with its sideways speed while blown; while fluttering it
	# tilts with the swing (most tilted at the ends, like a real leaf "catching" air).
	var tumbled: float = leaf_rotations[leaf_index] + velocity.x * 0.08 * delta
	leaf_rotations[leaf_index] = lerpf(tumbled, 0.6 * sin(phase), flutter * minf(6.0 * delta, 1.0))

	var position_now: Vector2 = leaf_positions[leaf_index]
	var motion: Vector2 = (velocity + Vector2(sway_velocity_x, 0.0)) * delta
	var position_next: Vector2 = position_now + motion
	# Falling onto another leaf: it comes to rest on top of it (a heap builds up), or,
	# if it would only overhang its edge, slides off outward (see _is_cradled).
	if motion.y > 0.0:
		var leaf_below: int = _find_leaf_below(leaf_index, position_next)
		if leaf_below != NO_LEAF:
			var resting_point: Vector2 = Vector2(position_next.x, leaf_positions[leaf_below].y - stack_spacing)
			if _is_cradled(leaf_index, resting_point, leaf_below):
				_land_on_leaf(leaf_index, resting_point, leaf_below)
				return
			var slide_side: float = signf(position_next.x - leaf_positions[leaf_below].x)
			if slide_side == 0.0:
				slide_side = 1.0 if launch_random.randf() < 0.5 else -1.0
			position_next.x += slide_side * slide_step
			motion.x += slide_side * slide_step
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


## Lands on a solid (`support`).
func _land_leaf(leaf_index: int, landing_position: Vector2, support: Node2D) -> void:
	_come_to_rest(leaf_index, landing_position)
	leaf_supports[leaf_index] = support
	leaf_support_positions[leaf_index] = support.global_position


## Lands on another leaf (`support_leaf`).
func _land_on_leaf(leaf_index: int, landing_position: Vector2, support_leaf: int) -> void:
	_come_to_rest(leaf_index, landing_position)
	leaf_support_leaves[leaf_index] = support_leaf


func _come_to_rest(leaf_index: int, landing_position: Vector2) -> void:
	leaf_positions[leaf_index] = landing_position
	leaf_velocities[leaf_index] = Vector2.ZERO
	leaf_is_flying[leaf_index] = 0
	leaf_supports[leaf_index] = null
	leaf_support_leaves[leaf_index] = NO_LEAF
	# Lands mostly flat, keeping a hint of its last tilt.
	leaf_rotations[leaf_index] *= 0.3
	# Straight into its bucket, so the next leaf this frame can land on it.
	if not resting_buckets_dirty:
		_add_to_bucket(leaf_index)


func _launch_leaf(leaf_index: int, launch_velocity: Vector2) -> void:
	if leaf_is_flying[leaf_index] == 0:
		# It leaves its spot: the buckets are out of date, and whatever lay on it
		# must check whether it still has something under it.
		resting_buckets_dirty = true
		leaf_supports_dirty = true
	leaf_is_flying[leaf_index] = 1
	leaf_velocities[leaf_index] = launch_velocity
	leaf_supports[leaf_index] = null
	leaf_support_leaves[leaf_index] = NO_LEAF


## LeafFire: leaf `leaf_index` burnt away. It's gone (not simulated, drawn or
## bucketed); leaves lying on it fall.
func remove_leaf(leaf_index: int) -> void:
	leaf_is_flying[leaf_index] = 0
	leaf_support_leaves[leaf_index] = NO_LEAF
	leaf_supports[leaf_index] = null
	resting_buckets_dirty = true
	leaf_supports_dirty = true


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
		if leaf_is_flying[leaf_index] == 1 or _is_gone(leaf_index):
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
				# The leaves stacked on this one now lie off it: let them check.
				resting_buckets_dirty = true
				leaf_supports_dirty = true
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


## Resting leaves with nothing under them any more (the leaf below took off, burnt
## away or moved, or they were part of the untouched pile and their neighbours got
## kicked out) start falling again. Only leaves lying on a solid that we follow
## (leaf_supports) are skipped: _update_resting_leaves checks those. One layer per
## frame: the leaves on THOSE leaves follow next frame, so a heap whose bottom is
## pulled out crumbles from the bottom up, and the pile never has leaves hanging in
## the air with a gap under them.
func _drop_unsupported_leaves() -> bool:
	leaf_supports_dirty = false
	if resting_buckets_dirty:
		_rebuild_resting_buckets()
	var falling: Array[int] = []
	for leaf_index: int in leaf_positions.size():
		if leaf_is_flying[leaf_index] == 1 or leaf_supports[leaf_index] != null or _is_gone(leaf_index):
			continue
		if leaf_positions[leaf_index].y > LOST_DISTANCE:
			continue  # lost in a pit: let it be
		if not _has_something_under(leaf_index):
			falling.append(leaf_index)
	# Launched after the loop, so this frame's checks all see the same heap.
	for leaf_index: int in falling:
		_launch_leaf(leaf_index, Vector2.ZERO)  # sets leaf_supports_dirty: next layer next frame
	return not falling.is_empty()


## True if a resting leaf has another resting leaf under it (settle_reach to the side,
## settle_depth down) or the ground within settle_depth. The leaf check comes first:
## it's a few array lookups, the ground check is a physics query.
func _has_something_under(leaf_index: int) -> bool:
	var point: Vector2 = leaf_positions[leaf_index]
	if _find_leaf_under(leaf_index, point, settle_reach, settle_depth) != NO_LEAF:
		return true
	return _find_solid(point + Vector2(0.0, settle_depth)) != null


## True if a leaf coming to rest at `point` on `leaf_below` would stay there: it's
## near the middle of that leaf, or something else holds up its overhanging side (a
## second leaf, or the ground, under the spot one stack_reach further out).
func _is_cradled(leaf_index: int, point: Vector2, leaf_below: int) -> bool:
	var overhang: float = point.x - leaf_positions[leaf_below].x
	if absf(overhang) <= stack_center_reach:
		return true
	var outer_point: Vector2 = point + Vector2(signf(overhang) * stack_reach, 0.0)
	var outer_leaf: int = _find_leaf_under(leaf_index, outer_point, stack_center_reach + 0.5, stack_spacing + 1.0)
	if outer_leaf != NO_LEAF and outer_leaf != leaf_below:
		return true
	return _find_solid(outer_point + Vector2(0.0, stack_spacing + 1.0)) != null


## The resting leaf a leaf falling to `point` lands on, or NO_LEAF: one whose middle
## is at most stack_reach px to the side and just below (within stack_spacing + 0.6).
func _find_leaf_below(leaf_index: int, point: Vector2) -> int:
	return _find_leaf_under(leaf_index, point, stack_reach, stack_spacing + 0.6)


## The nearest resting leaf under `point`: at most `reach` px to the side and between
## 0 and `depth` px down. NO_LEAF if there's none.
func _find_leaf_under(leaf_index: int, point: Vector2, reach: float, depth: float) -> int:
	if resting_buckets_dirty:
		_rebuild_resting_buckets()
	var best_leaf: int = NO_LEAF
	var best_gap: float = INF
	var first_bucket: Vector2i = _bucket_of(point - Vector2(reach, 0.0))
	var last_bucket: Vector2i = _bucket_of(point + Vector2(reach, depth))
	for bucket_x: int in range(first_bucket.x, last_bucket.x + 1):
		for bucket_y: int in range(first_bucket.y, last_bucket.y + 1):
			var bucket: Vector2i = Vector2i(bucket_x, bucket_y)
			if not resting_buckets.has(bucket):
				continue  # (no .get(bucket, []): that would make an empty array each time)
			for other: int in resting_buckets[bucket]:
				if other == leaf_index:
					continue
				var offset: Vector2 = leaf_positions[other] - point
				if absf(offset.x) <= reach and offset.y > 0.0 \
						and offset.y <= depth and offset.y < best_gap:
					best_leaf = other
					best_gap = offset.y
	return best_leaf


func _rebuild_resting_buckets() -> void:
	resting_buckets.clear()
	resting_buckets_dirty = false
	for leaf_index: int in leaf_positions.size():
		if leaf_is_flying[leaf_index] == 0 and not _is_gone(leaf_index):
			_add_to_bucket(leaf_index)


func _add_to_bucket(leaf_index: int) -> void:
	var bucket: Vector2i = _bucket_of(leaf_positions[leaf_index])
	if resting_buckets.has(bucket):
		(resting_buckets[bucket] as Array).append(leaf_index)
	else:
		resting_buckets[bucket] = [leaf_index]


func _bucket_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / STACK_BUCKET), floori(point.y / STACK_BUCKET))


## True if the leaf burnt away (only possible once a LeafFire exists).
func _is_gone(leaf_index: int) -> bool:
	return fire != null and fire.leaf_states[leaf_index] == LeafFire.LeafState.GONE


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
		var body_height: float = _get_body_height(mover)
		var mover_speed: float = mover.velocity.length()
		for leaf_index: int in leaf_positions.size():
			if _is_gone(leaf_index):
				continue
			var offset: Vector2 = leaf_positions[leaf_index] - feet
			if leaf_is_flying[leaf_index] == 1:
				# A leaf in the air that the body passes through (play-test: you jumped
				# through falling leaves and they ignored you) is swept along with it.
				# Only while it's slower than that, so it isn't pushed again every frame.
				if absf(offset.x) < half_width and offset.y > -body_height - 2.0 and offset.y < 2.0 \
						and leaf_velocities[leaf_index].length() < mover_speed * 0.5:
					leaf_velocities[leaf_index] = mover.velocity * launch_random.randf_range(0.5, 0.9) \
						+ Vector2(launch_random.randf_range(-15.0, 15.0), -launch_random.randf_range(10.0, 30.0))
				continue
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


## Height of a body's first rectangle collision shape (12 px fallback).
func _get_body_height(body: CharacterBody2D) -> float:
	for child: Node in body.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			return (shape_node.shape as RectangleShape2D).size.y
	return 12.0


## "What solid is at this point (local coordinates)?" asked of the physics world.
## Returns the body there, or null if the point is in open air.
func _find_solid(local_point: Vector2) -> Node2D:
	point_query.position = to_global(local_point)
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(point_query, 1)
	if results.is_empty():
		return null
	return results[0]["collider"] as Node2D


## Builds the untouched pile: leaves on a JITTERED GRID under a parabola-shaped
## mound (F7 play-test: purely random spots left air pockets), mostly lying flat.
## The grid's spacing is picked so leaf_count leaves fill the mound's area; cells are
## wider than tall because leaves are (4x2 px). Uses its own seeded generator so the
## pile looks the same in the editor and in game.
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
	# A parabola's area is 2/3 of its bounding box. One cell per leaf, 1.4:1 wide.
	var mound_area: float = maxf(pile_width * pile_height * 2.0 / 3.0, 1.0)
	var cell_area: float = mound_area / leaf_count
	var cell_size: Vector2 = Vector2(sqrt(cell_area * 1.4), sqrt(cell_area / 1.4))
	var spots: PackedVector2Array = PackedVector2Array()
	var y: float = 0.5
	while y <= pile_height:
		var x: float = -half_width + cell_size.x * 0.5
		while x <= half_width:
			var spot: Vector2 = Vector2(
				x + layout_random.randf_range(-0.5, 0.5) * cell_size.x,
				y + layout_random.randf_range(-0.4, 0.4) * cell_size.y)
			if spot.y >= 0.5 and spot.y <= _get_mound_height(spot.x):
				spots.append(spot)
			x += cell_size.x
		y += cell_size.y
	# Shuffle (Fisher-Yates, with the seeded generator), then take leaf_count; if the
	# grid came up short, the rest go anywhere under the mound.
	for spot_index: int in range(spots.size() - 1, 0, -1):
		var other: int = layout_random.randi_range(0, spot_index)
		var kept: Vector2 = spots[spot_index]
		spots[spot_index] = spots[other]
		spots[other] = kept
	for leaf_index: int in leaf_count:
		var spot: Vector2
		if leaf_index < spots.size():
			spot = spots[leaf_index]
		else:
			var x: float = layout_random.randf_range(-half_width, half_width)
			spot = Vector2(x, layout_random.randf_range(0.5, _get_mound_height(x)))
		home_positions.append(Vector2(spot.x, -spot.y))
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
	leaf_support_leaves = PackedInt32Array()
	leaf_support_leaves.resize(leaf_count)
	leaf_support_leaves.fill(NO_LEAF)
	resting_buckets_dirty = true
	_update_sensor_bounds()
	queue_redraw()


## Mound height at x (local px): pile_height in the middle, 1 px at the edges (1 - t²).
func _get_mound_height(x: float) -> float:
	var relative_x: float = x / maxf(pile_width / 2.0, 0.01)
	return maxf(pile_height * (1.0 - relative_x * relative_x), 1.0)


## Makes the sensor cover every live leaf (plus a margin), wherever they've ended up.
func _update_sensor_bounds() -> void:
	if sensor_shape_node == null or leaf_positions.is_empty():
		return
	var bounds: Rect2 = Rect2()
	var has_live: bool = false
	for leaf_index: int in leaf_positions.size():
		if _is_gone(leaf_index):
			continue
		var leaf_position: Vector2 = leaf_positions[leaf_index]
		bounds = bounds.expand(leaf_position) if has_live else Rect2(leaf_position, Vector2.ZERO)
		has_live = true
	if has_live:
		bounds = bounds.grow(3.0)
		(sensor_shape_node.shape as RectangleShape2D).size = bounds.size
		sensor_shape_node.position = bounds.get_center()


## Every live leaf as ONE triangle list (two triangles per diamond), the way
## ThicketLeaves draws (see its _draw): one draw_colored_polygon per leaf made Godot
## cut every leaf into triangles again on every redraw, ~20 µs a leaf, and a
## 300-leaf pile redraws every frame while leaves fly or burn.
func _draw() -> void:
	var total_leaves: int = leaf_positions.size()
	if total_leaves == 0:
		return
	draw_points.resize(total_leaves * 4)
	draw_colors.resize(total_leaves * 4)
	if draw_indices.size() != total_leaves * 6:
		draw_indices.resize(total_leaves * 6)
		for leaf_index: int in total_leaves:
			var first_vertex: int = leaf_index * 4
			var first_index: int = leaf_index * 6
			# Corners 0-1-2 and 0-2-3 of leaf_shape.
			draw_indices[first_index] = first_vertex
			draw_indices[first_index + 1] = first_vertex + 1
			draw_indices[first_index + 2] = first_vertex + 2
			draw_indices[first_index + 3] = first_vertex
			draw_indices[first_index + 4] = first_vertex + 2
			draw_indices[first_index + 5] = first_vertex + 3
	var drawn_count: int = 0
	for leaf_index: int in total_leaves:
		var color: Color = leaf_colors[leaf_index]
		var leaf_scale: float = 1.0
		if fire != null:
			var state: int = fire.leaf_states[leaf_index]
			if state == LeafFire.LeafState.GONE:
				continue
			if state == LeafFire.LeafState.BURNING:
				# An ember: flickers between deep red and yellow, out of step with its
				# neighbours. A lone one chars and shrinks as it burns out.
				var flicker: float = 0.5 + 0.5 * sin(fire.clock * 18.0 + leaf_index * 2.3)
				var ember: Color = LEAF_EMBER_COLOR.lerp(LEAF_HOT_COLOR, flicker * 0.8)
				var burnt: float = fire.get_burn_share(leaf_index)
				color = color.lerp(ember, 0.9)
				color = color.lerp(LEAF_CHAR_COLOR, clampf(burnt * 2.0 - 1.0, 0.0, 1.0))
				leaf_scale = 1.0 - 0.5 * burnt
			elif fire.primed_count > 0:
				# Touched by the jet, about to catch: warming up toward ember red.
				color = color.lerp(LEAF_EMBER_COLOR, 0.7 * fire.get_prime_share(leaf_index))
		# The diamond moved to the leaf, turned and scaled: corner = position
		# + x * long_axis + y * short_axis (what draw_set_transform would do).
		var leaf_position: Vector2 = leaf_positions[leaf_index] + Vector2(0.0, ground_sink)
		var long_axis: Vector2 = Vector2.from_angle(leaf_rotations[leaf_index]) * leaf_scale
		var short_axis: Vector2 = Vector2(-long_axis.y, long_axis.x)  # turned +90°
		var first_vertex: int = drawn_count * 4
		for corner: int in 4:
			var shape_point: Vector2 = leaf_shape[corner]
			draw_points[first_vertex + corner] = leaf_position + long_axis * shape_point.x + short_axis * shape_point.y
			draw_colors[first_vertex + corner] = color
		drawn_count += 1
	if drawn_count == 0:
		return
	draw_points.resize(drawn_count * 4)
	draw_colors.resize(drawn_count * 4)
	var indices: PackedInt32Array = draw_indices
	if drawn_count < total_leaves:
		indices = draw_indices.slice(0, drawn_count * 6)  # some burnt away
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, draw_points, draw_colors)


# --- Fire (Stage F7) ----------------------------------------------------------------

## The Flammable contract, without a point: a flame touched the pile. The leaf nearest
## the flame's source catches (a fireball's thrower, a bonfire, the jet). Burning
## grass (the FireGrid has no useful position) uses ignite_at instead; without a
## usable source, the bottom leaves catch.
func ignite(source: Node) -> void:
	var leaf_fire: LeafFire = _get_fire()
	var source_2d: Node2D = source as Node2D
	if source_2d != null and not source is FireGrid:
		var nearest: int = _find_nearest_unlit_leaf(to_local(source_2d.global_position))
		if nearest != NO_LEAF:
			leaf_fire.light_leaf(nearest)
		return
	var lowest: float = -INF
	for leaf_index: int in leaf_positions.size():
		if not _is_gone(leaf_index):
			lowest = maxf(lowest, leaf_positions[leaf_index].y)
	for leaf_index: int in leaf_positions.size():
		if not _is_gone(leaf_index) and leaf_positions[leaf_index].y >= lowest - 2.0:
			leaf_fire.light_leaf(leaf_index)


## The Flammable contract's optional part: lights the leaves within `radius` px of
## `world_point` (a fireball's splash, the jet plume, a burning grass cell, an ember
## from another pile). Returns true if any caught.
func ignite_at(world_point: Vector2, radius: float, source: Node) -> bool:
	var point: Vector2 = to_local(world_point)
	# Quick no: nowhere near any live leaf (the sensor covers them all, +3 px). Burning
	# leaves ask every pile in the room several times a second, so this matters.
	var live_area: Rect2 = Rect2(sensor_shape_node.position - (sensor_shape_node.shape as RectangleShape2D).size / 2.0,
		(sensor_shape_node.shape as RectangleShape2D).size)
	if not live_area.grow(radius).has_point(point):
		return false
	# The jet's flame catches a moment later (LeafFire's "LIT BY THE JET").
	var catch_delay: float = 0.0
	if source is FlameJetAbility:
		catch_delay = _get_fire().fire_tuning.leaf_jet_catch_delay
	return _get_fire().light_near(point, radius, catch_delay)


func is_burning() -> bool:
	return fire != null and fire.burning_count > 0


## Wind against fire is the gust's push itself (receive_gust_from): it scatters the
## heap, so the bonfire goes out and the leaves fly on as embers.
func snuff() -> void:
	pass


## Where the live leaves are, in world coordinates.
func get_fire_rect() -> Rect2:
	var local_rect: Rect2 = Rect2()
	var has_live: bool = false
	for leaf_index: int in leaf_positions.size():
		if _is_gone(leaf_index):
			continue
		var leaf_position: Vector2 = leaf_positions[leaf_index]
		local_rect = local_rect.expand(leaf_position) if has_live else Rect2(leaf_position, Vector2.ZERO)
		has_live = true
	if not has_live:
		return Rect2(global_position, Vector2.ZERO)
	return Rect2(to_global(local_rect.position), local_rect.size).grow(1.0)


func _get_fire() -> LeafFire:
	if fire == null:
		fire = LeafFire.new()
		add_child(fire)
		fire.setup(self)
	return fire


func _find_nearest_unlit_leaf(point: Vector2) -> int:
	var nearest: int = NO_LEAF
	var nearest_distance: float = INF
	for leaf_index: int in leaf_positions.size():
		if fire.leaf_states[leaf_index] != LeafFire.LeafState.UNLIT:
			continue
		var distance: float = leaf_positions[leaf_index].distance_squared_to(point)
		if distance < nearest_distance:
			nearest = leaf_index
			nearest_distance = distance
	return nearest

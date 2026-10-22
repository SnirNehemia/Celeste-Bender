@tool
class_name Vine
extends Switch
## Vine (Fire_bending.md §6.2, Stage F8): a rope of living vine from this node (its
## ANCHOR, in a ceiling or wall) to `end_point`, where it is usually tied round
## something it holds. Not climbable, no new movement verb: it only HOLDS things,
## and fire cuts it.
##
## The rope is simulated (F8 play-test: "vines following approximated physics"): a
## chain of points PARTICLE_SPACING px apart, moved by "Verlet integration" (each
## point remembers where it was last frame; its velocity is simply now - before,
## plus gravity) and then pulled back to their spacing a few times per frame
## ("distance constraints", only when stretched: a rope can go slack, not stretch).
## The anchor point never moves; the last point follows what the vine is tied to
## (tie_to(), called every frame by a HangingPlatform or a Crate), or stays at
## end_point if nothing ties it. So a vine holding a swinging plank swings with it.
## A rope that has stopped moving sleeps (no simulation) until something moves it.
##
## Burning:
##   - Lit at a point, the fire runs both ways along the rope at `vine_burn_speed`
##     (FireTuning). Every piece it reaches glows, chars black and drops off
##     `vine_char_time` later, as loose falling bits.
##   - The piece where it was lit burns through after `vine_cut_time`: the vine
##     SNAPS there and turns ON. What it held is let go at that moment; the two
##     halves keep burning while they dangle (one from the anchor, one from what it
##     held) until nothing is left.
##   - Where the fire reaches an end, it lights grass and leaves there (flammables
##     that burn in parts, with ignite_at), never whole objects: a crate hung on a
##     vine falls, it isn't set on fire by the vine that held it.
##   - The vine's flame doesn't kill (not a FireHazard). Gusts don't put it out
##     until Stage F10.
##
## Why a Switch? "What it held falls" is the switch → listener wiring (switch.gd): a
## vine is a switch that turns on when it snaps. HangingPlatform.vines and
## Crate.hung_from connect to its `switched` signal; the vine never knows what it holds.
##
## Flammable contract (scenes/objects/fire/flammable.gd): group "flammable",
## ignite() / is_burning() / snuff() / get_fire_rect(), and ignite_at(), so a flame
## is checked against the rope's actual line. Fireballs hit a child Area2D on layer 6
## ("flammable") whose segment shape follows the rope; it is switched off as soon as
## the vine is lit (a burnt vine must not stop fireballs).
##
## The tie (F8 play-test: "curl around the bridge more"): when tied to something
## with a thickness (a plank), the vine draws coils round it and tendrils winding
## along it, which burn too when the fire gets there.
##
## Place the node at the anchor and set `end_point` to the other end, relative to it.
## It joins the room reset group: death or R grows it back.

enum BurnState { INTACT, BURNING, BURNT }

## Not in the §2 color key: a dark leafy green, lighter leaves.
const VINE_COLOR: Color = Color(0.24, 0.42, 0.16)
const VINE_DARK_COLOR: Color = Color(0.15, 0.28, 0.1)
const LEAF_COLOR: Color = Color(0.36, 0.58, 0.22)
## Burning (fire palette, Fire_bending.md §9.1): yellow where the fire just got to,
## red, then black char.
const BURNT_COLOR: Color = Color(0.1, 0.08, 0.08)
const GLOW_COLOR: Color = Color("#FFD34D")
const EMBER_COLOR: Color = Color("#E8431A")

## The rope: points this far apart, px, and this much longer than the straight line
## between its ends (a little slack, so it sags a hair instead of looking like a rod).
const PARTICLE_SPACING: float = 3.0
const ROPE_SLACK: float = 1.02
## Rope physics. Lighter than the player's 900 gravity, so it falls and swings like
## a rope, not a stone; damping bleeds off a bit of speed every frame.
const ROPE_GRAVITY: float = 500.0
const ROPE_DAMPING: float = 0.985
const CONSTRAINT_ITERATIONS: int = 10
## A rope whose points all moved less than this (px per frame) for SLEEP_FRAMES in a
## row stops simulating until something moves it.
const SLEEP_MOTION: float = 0.02
const SLEEP_FRAMES: int = 20
## Loose burnt bits fall and fade out over this many seconds.
const BIT_LIFETIME: float = 0.6
## Width of the line a flame must touch to light the vine, px (forgiving: it's thin).
const CATCH_THICKNESS: float = 4.0
## A front reaching an end lights grass and leaves within this many px of it.
const END_IGNITE_REACH: float = 3.0
## The coils round what it's tied to: how many, how far apart along it (px), and the
## tendrils winding on along it to each side (px long, zigzag step px).
const WRAP_TURNS: int = 4
const WRAP_SPACING: float = 1.6
const TENDRIL_LENGTH: float = 12.0
const OUTER_TENDRIL_LENGTH: float = 2.5
const TENDRIL_STEP: float = 2.5

## The other end of the vine, relative to this node, px.
@export var end_point: Vector2 = Vector2(0, 32):
	set(value):
		end_point = value
		_build_rope()
		_update_catch_shape()
		queue_redraw()

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var burn_state: BurnState = BurnState.INTACT

## The rope's points (local coordinates) and where each was last frame.
var points: PackedVector2Array = PackedVector2Array()
var previous_points: PackedVector2Array = PackedVector2Array()
## Segment i joins points i and i + 1. Burnt-off segments are no longer alive.
var segment_alive: Array[bool] = []
## Seconds after lighting when the fire reaches each segment (INF before it's lit).
var segment_burn_at: PackedFloat32Array = PackedFloat32Array()
## For each point: seconds after lighting when it came loose (no segment left), or -1.
var loose_since: PackedFloat32Array = PackedFloat32Array()
## Rest length of a segment (with the slack), and the length used to measure how far
## along the rope a point is (without it), px.
var segment_rest_length: float = 0.0
var segment_arc_length: float = 0.0
var is_awake: bool = true
var still_frames: int = 0

## Burning: seconds since lit, where along the rope it was lit (px from the anchor),
## which segment burns through, whether it has snapped, which ends have lit the ground.
var burn_clock: float = 0.0
var lit_arc: float = 0.0
var cut_segment: int = 0
var has_snapped: bool = false
var lit_anchor_end: bool = false
var lit_tied_end: bool = false
## A small flame riding each front: [toward the anchor, toward the tied end].
var front_flames: Array[FlameTongue] = []

## What it's tied to (set every frame by tie_to()): the point, local; the holder's
## long axis (for the coils) and thickness (0 = no coils).
var is_tied: bool = false
var tie_point: Vector2 = Vector2.ZERO
var tie_axis: Vector2 = Vector2.RIGHT
var tie_thickness: float = 0.0

var catch_shape_node: CollisionShape2D


func _ready() -> void:
	z_index = 1  # over what it holds, so the coils wrap visibly round it
	var catch_area: Area2D = Area2D.new()
	catch_area.name = "CatchArea"
	catch_area.collision_layer = Flammable.LAYER_BIT
	catch_area.collision_mask = 0
	catch_area.monitoring = false  # it is only found, it doesn't look for anything
	catch_shape_node = CollisionShape2D.new()
	catch_shape_node.shape = SegmentShape2D.new()
	catch_area.add_child(catch_shape_node)
	add_child(catch_area)
	_build_rope()
	_update_catch_shape()
	if Engine.is_editor_hint():
		return
	add_to_group(Flammable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	var flame_merge: FlameMerge = FlameMerge.make(self)
	for flame_number: int in 2:
		var flame: FlameTongue = FlameTongue.new()
		flame.length = 5.0
		flame.base_width = 3.0
		flame.fan_width = 3.5
		flame.heat = 0.6
		flame.fork_amount = 0.4
		flame.lick_rate = 6.0
		flame.lick_size = 2.0
		flame.lick_speed = 20.0
		flame.smoke_rate = 6.0
		flame.smoke_lifetime = 0.6
		flame.visible = false
		add_child(flame)
		flame_merge.add_tongue(flame)
		front_flames.append(flame)


## A straight, untouched rope from the anchor to end_point.
func _build_rope() -> void:
	var straight_length: float = end_point.length()
	var segment_count: int = maxi(int(ceilf(straight_length / PARTICLE_SPACING)), 1)
	points.resize(segment_count + 1)
	for point_index: int in points.size():
		points[point_index] = end_point * (float(point_index) / segment_count)
	previous_points = points.duplicate()
	segment_arc_length = straight_length / segment_count
	segment_rest_length = segment_arc_length * ROPE_SLACK
	segment_alive.resize(segment_count)
	segment_alive.fill(true)
	segment_burn_at.resize(segment_count)
	segment_burn_at.fill(INF)
	loose_since.resize(points.size())
	loose_since.fill(-1.0)
	still_frames = 0
	is_awake = true


# --- What it's tied to --------------------------------------------------------------

## Called every physics frame by what the vine holds: the rope's last point follows
## `world_point`. `axis` is the holder's long direction, pointing toward its middle
## (the long tendril winds that way), and `thickness` its thickness, px, for drawing
## the coils (0 = no coils, e.g. a crate).
func tie_to(world_point: Vector2, axis: Vector2, thickness: float) -> void:
	var new_tie_point: Vector2 = to_local(world_point)
	if not is_tied or new_tie_point.distance_squared_to(tie_point) > 0.0001:
		is_awake = true  # the holder moved: the rope follows
	is_tied = true
	tie_point = new_tie_point
	tie_axis = axis.normalized() if axis.length() > 0.0 else Vector2.RIGHT
	tie_thickness = thickness


# --- The Flammable contract ----------------------------------------------------------

## Lit by something that touched the vine (a fireball hitting its catch area): it
## catches at the point nearest that thing.
func ignite(source: Node) -> void:
	if burn_state != BurnState.INTACT:
		return
	var source_2d: Node2D = source as Node2D
	var touch_point: Vector2 = source_2d.global_position if source_2d != null else to_global(end_point / 2.0)
	_light_at(_get_nearest_arc(to_local(touch_point))[0])


## A flame at `world_point` reaching `radius` px: lights the vine if the flame
## touches its line. Returns true if it caught just now.
## Fire near the coils and tendrils round what it holds lights it too, at its tied
## end (F8 play-test: a fireball bursting on the plank by the knot burns the vine).
func ignite_at(world_point: Vector2, radius: float, _source: Node) -> bool:
	if burn_state != BurnState.INTACT:
		return false
	var local_point: Vector2 = to_local(world_point)
	var nearest: Array[float] = _get_nearest_arc(local_point)
	if nearest[1] <= radius + CATCH_THICKNESS / 2.0:
		_light_at(nearest[0])
		return true
	if _get_distance_to_wrap(local_point) <= radius:
		_light_at(segment_arc_length * segment_alive.size())
		return true
	return false


func is_burning() -> bool:
	return burn_state == BurnState.BURNING


## Gusts put out a vine burn only from Stage F10 (§5.4).
func snuff() -> void:
	pass


## The rope's bounding box, a little grown, world coordinates. Only used by code
## without an ignite_at path; Flammable's helpers use ignite_at.
func get_fire_rect() -> Rect2:
	var box: Rect2 = Rect2(to_global(points[0]), Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(to_global(point))
	return box.grow(CATCH_THICKNESS / 2.0)


# --- Burning -----------------------------------------------------------------------

func _light_at(arc: float) -> void:
	burn_state = BurnState.BURNING
	burn_clock = 0.0
	lit_arc = arc
	has_snapped = false
	lit_anchor_end = false
	lit_tied_end = false
	is_awake = true
	# The fire reaches each segment when the front gets to its nearer end.
	var speed: float = maxf(fire_tuning.vine_burn_speed, 1.0)
	for segment_index: int in segment_alive.size():
		var segment_start: float = segment_index * segment_arc_length
		var segment_end: float = segment_start + segment_arc_length
		var distance: float = maxf(maxf(segment_start - arc, arc - segment_end), 0.0)
		segment_burn_at[segment_index] = distance / speed
	cut_segment = clampi(int(arc / segment_arc_length), 0, segment_alive.size() - 1)
	# A lit vine can't be lit again, and must not stop fireballs any more.
	catch_shape_node.set_deferred("disabled", true)
	for flame: FlameTongue in front_flames:
		flame.visible = true
	_place_front_flames()
	EmberEmitter.burst(get_parent(), to_global(_get_point_at_arc(arc)), 5, Vector2.UP, 120.0, 40.0)
	FX.play_sfx(&"fire_ignite")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if burn_state == BurnState.BURNING:
		_advance_burn(delta)
	if is_awake:
		_simulate_rope(delta)
		queue_redraw()


func _advance_burn(delta: float) -> void:
	burn_clock += delta
	var char_time: float = fire_tuning.vine_char_time
	# Burn through where it was lit: the vine snaps.
	if not has_snapped and burn_clock >= fire_tuning.vine_cut_time:
		has_snapped = true
		_remove_segment(cut_segment)
		SmokePuff.spawn(get_parent(), to_global(points[cut_segment]), 3)
		set_on(true)  # what it held is let go now
		FX.play_sfx(&"vine_snap")
	# Charred pieces drop off.
	var any_left: bool = false
	for segment_index: int in segment_alive.size():
		if not segment_alive[segment_index]:
			continue
		if segment_index != cut_segment and burn_clock >= segment_burn_at[segment_index] + char_time:
			_remove_segment(segment_index)
		else:
			any_left = true
	# The fronts reaching the ends light the ground there.
	var speed: float = maxf(fire_tuning.vine_burn_speed, 1.0)
	var rope_arc: float = segment_arc_length * segment_alive.size()
	if not lit_anchor_end and burn_clock * speed >= lit_arc:
		lit_anchor_end = true
		_light_ground_at(to_global(points[0]))
	if not lit_tied_end and burn_clock * speed >= rope_arc - lit_arc:
		lit_tied_end = true
		_light_ground_at(to_global(points[points.size() - 1]))
	_place_front_flames()
	# Done when nothing is left: no segment, no falling bit, no coil.
	var bits_falling: bool = false
	for loose_time: float in loose_since:
		if loose_time >= 0.0 and burn_clock - loose_time < BIT_LIFETIME:
			bits_falling = true
	if not any_left and not bits_falling and burn_clock > _get_wrap_burn_at() + char_time:
		burn_state = BurnState.BURNT
		for flame: FlameTongue in front_flames:
			flame.visible = false
		queue_redraw()


## A burnt piece drops off; a point with no piece left on either side comes loose.
func _remove_segment(segment_index: int) -> void:
	segment_alive[segment_index] = false
	for point_index: int in [segment_index, segment_index + 1]:
		if _is_pinned(point_index) or loose_since[point_index] >= 0.0:
			continue
		var has_segment: bool = (point_index > 0 and segment_alive[point_index - 1]) \
			or (point_index < segment_alive.size() and segment_alive[point_index])
		if not has_segment:
			loose_since[point_index] = burn_clock


## Lights the things that burn in parts (grass cells, leaves) at an end of the vine.
func _light_ground_at(world_point: Vector2) -> void:
	for target: Node in get_tree().get_nodes_in_group(Flammable.GROUP):
		if target != self and target.has_method(Flammable.METHOD_IGNITE_AT):
			target.call(Flammable.METHOD_IGNITE_AT, world_point, END_IGNITE_REACH, self)


## Each front's flame sits where the fire is now, while that front is still on rope.
func _place_front_flames() -> void:
	if front_flames.size() < 2:
		return
	var travelled: float = burn_clock * fire_tuning.vine_burn_speed
	var rope_arc: float = segment_arc_length * segment_alive.size()
	var front_arcs: Array[float] = [lit_arc - travelled, lit_arc + travelled]
	for front_index: int in 2:
		var arc: float = front_arcs[front_index]
		var on_rope: bool = arc >= 0.0 and arc <= rope_arc and burn_state == BurnState.BURNING
		front_flames[front_index].visible = on_rope
		if on_rope:
			front_flames[front_index].position = _get_point_at_arc(arc)


## When the fire reaches the coils at the tied end, seconds after lighting.
func _get_wrap_burn_at() -> float:
	var rope_arc: float = segment_arc_length * segment_alive.size()
	return (rope_arc - lit_arc) / maxf(fire_tuning.vine_burn_speed, 1.0)


# --- Rope physics --------------------------------------------------------------------

func _is_pinned(point_index: int) -> bool:
	return point_index == 0 or point_index == points.size() - 1


func _simulate_rope(delta: float) -> void:
	var last_index: int = points.size() - 1
	var end_pin: Vector2 = tie_point if is_tied else end_point
	var biggest_motion: float = 0.0
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	# 1. Verlet: carry on moving the way it moved last frame, plus gravity.
	for point_index: int in range(1, last_index):
		if _is_dead_bit(point_index):
			continue
		var velocity: Vector2 = (points[point_index] - previous_points[point_index]) * ROPE_DAMPING
		previous_points[point_index] = points[point_index]
		points[point_index] += velocity + Vector2(0.0, ROPE_GRAVITY) * delta * delta
	points[0] = Vector2.ZERO
	points[last_index] = end_pin
	# 2. Pull stretched segments back to their length. Several passes, because fixing
	#    one segment stretches its neighbours a little.
	for iteration: int in CONSTRAINT_ITERATIONS:
		for segment_index: int in segment_alive.size():
			if not segment_alive[segment_index]:
				continue
			var from_point: Vector2 = points[segment_index]
			var to_point: Vector2 = points[segment_index + 1]
			var difference: Vector2 = to_point - from_point
			var distance: float = difference.length()
			if distance <= segment_rest_length:
				continue  # slack: a rope doesn't push
			var correction: Vector2 = difference * ((distance - segment_rest_length) / distance)
			var from_pinned: bool = _is_pinned(segment_index)
			var to_pinned: bool = _is_pinned(segment_index + 1)
			if from_pinned and to_pinned:
				continue
			if from_pinned:
				points[segment_index + 1] -= correction
			elif to_pinned:
				points[segment_index] += correction
			else:
				points[segment_index] += correction * 0.5
				points[segment_index + 1] -= correction * 0.5
	# 3. Loose burnt bits stop on the ground instead of falling through it.
	for point_index: int in range(1, last_index):
		if loose_since[point_index] < 0.0 or _is_dead_bit(point_index):
			continue
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = to_global(points[point_index])
		query.collision_mask = 1  # layer 1, "world"
		if not space.intersect_point(query, 1).is_empty():
			points[point_index] = previous_points[point_index]
	for point_index: int in points.size():
		biggest_motion = maxf(biggest_motion, points[point_index].distance_to(previous_points[point_index]))
	# 4. Sleep once it hangs still (a burning rope stays awake until it's gone).
	still_frames = still_frames + 1 if biggest_motion < SLEEP_MOTION else 0
	if burn_state != BurnState.BURNING and still_frames >= SLEEP_FRAMES:
		is_awake = false
	if burn_state == BurnState.INTACT:
		_update_catch_shape()


func _is_dead_bit(point_index: int) -> bool:
	return loose_since[point_index] >= 0.0 and burn_clock - loose_since[point_index] >= BIT_LIFETIME


## The catch area runs straight from the anchor to the tied end (an intact rope is
## nearly taut).
func _update_catch_shape() -> void:
	if catch_shape_node == null or points.is_empty():
		return
	var segment: SegmentShape2D = catch_shape_node.shape as SegmentShape2D
	segment.a = points[0]
	segment.b = points[points.size() - 1]


## Called by Room.reset_objects() on death or R: the vine grows back.
func reset() -> void:
	burn_state = BurnState.INTACT
	burn_clock = 0.0
	has_snapped = false
	_build_rope()
	if is_tied:
		points[points.size() - 1] = tie_point
	_update_catch_shape()
	catch_shape_node.set_deferred("disabled", false)
	for flame: FlameTongue in front_flames:
		flame.visible = false
	set_on(false)
	queue_redraw()


# --- Geometry ----------------------------------------------------------------------

## [arc length from the anchor, distance] of the rope point nearest `local_point`
## (along the rope's current shape).
func _get_nearest_arc(local_point: Vector2) -> Array[float]:
	var best_arc: float = 0.0
	var best_distance: float = INF
	for segment_index: int in segment_alive.size():
		var from_point: Vector2 = points[segment_index]
		var to_point: Vector2 = points[segment_index + 1]
		var along: Vector2 = to_point - from_point
		var fraction: float = 0.0
		if along.length_squared() > 0.0:
			fraction = clampf((local_point - from_point).dot(along) / along.length_squared(), 0.0, 1.0)
		var distance: float = local_point.distance_to(from_point + along * fraction)
		if distance < best_distance:
			best_distance = distance
			best_arc = (segment_index + fraction) * segment_arc_length
	return [best_arc, best_distance]


## How far `local_point` is from the coils and tendrils (0 inside them, INF if the
## vine isn't wound round anything): a band along the holder from the outer stub's
## tip to the long tendril's tip, as thick as the coils.
func _get_distance_to_wrap(local_point: Vector2) -> float:
	if not is_tied or tie_thickness <= 0.0:
		return INF
	var start_offset: float = (WRAP_TURNS / 2.0) * WRAP_SPACING
	var from_point: Vector2 = tie_point - tie_axis * (start_offset + OUTER_TENDRIL_LENGTH)
	var to_point: Vector2 = tie_point + tie_axis * (start_offset + TENDRIL_LENGTH)
	var along: Vector2 = to_point - from_point
	var fraction: float = clampf((local_point - from_point).dot(along) / along.length_squared(), 0.0, 1.0)
	var half_height: float = tie_thickness / 2.0 + 0.7
	return maxf(local_point.distance_to(from_point + along * fraction) - half_height, 0.0)


## The rope's point `arc` px along it from the anchor, local, as it hangs now.
func _get_point_at_arc(arc: float) -> Vector2:
	var position_along: float = clampf(arc / segment_arc_length, 0.0, float(points.size() - 1))
	var index: int = mini(int(position_along), points.size() - 2)
	return points[index].lerp(points[index + 1], position_along - index)


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	var char_time: float = maxf(fire_tuning.vine_char_time, 0.01)
	for segment_index: int in segment_alive.size():
		if not segment_alive[segment_index]:
			continue
		draw_line(points[segment_index], points[segment_index + 1], _get_segment_color(segment_index, char_time), 1.0)
	# Leaves, alternating sides, on the pieces the fire hasn't reached.
	for segment_index: int in range(1, segment_alive.size(), 3):
		if not segment_alive[segment_index] or _get_burn_age(segment_index) >= 0.0:
			continue
		var base: Vector2 = points[segment_index]
		var along: Vector2 = (points[segment_index + 1] - base).normalized()
		var flip: float = 1.0 if int(segment_index / 3.0) % 2 == 0 else -1.0
		_draw_leaf(base, base + along.orthogonal() * flip * 2.5 + along * 1.5, LEAF_COLOR)
	# Loose burnt bits, falling and fading.
	for point_index: int in points.size():
		if loose_since[point_index] < 0.0 or _is_dead_bit(point_index):
			continue
		var fade: float = 1.0 - (burn_clock - loose_since[point_index]) / BIT_LIFETIME
		var fall_direction: Vector2 = points[point_index] - previous_points[point_index]
		var tail: Vector2 = fall_direction.normalized() * 1.5 if fall_direction.length() > 0.0 else Vector2.UP
		draw_line(points[point_index] - tail, points[point_index], Color(BURNT_COLOR, fade), 1.0)
	_draw_wrap(char_time)


## Before the fire: green (a darker stripe now and then, so it reads as twisted).
## Then glowing yellow → red → black over vine_char_time.
func _get_segment_color(segment_index: int, char_time: float) -> Color:
	var age: float = _get_burn_age(segment_index)
	if age < 0.0:
		return VINE_DARK_COLOR if segment_index % 3 == 0 else VINE_COLOR
	return _get_burning_color(age / char_time)


## Seconds since the fire reached this segment, or -1 if it hasn't.
func _get_burn_age(segment_index: int) -> float:
	if burn_state == BurnState.INTACT or burn_clock < segment_burn_at[segment_index]:
		return -1.0
	return burn_clock - segment_burn_at[segment_index]


## 0 = just caught (bright yellow), 1 = charred black.
func _get_burning_color(charred: float) -> Color:
	var heat: float = 1.0 - clampf(charred, 0.0, 1.0)
	return BURNT_COLOR.lerp(EMBER_COLOR, clampf(heat * 2.0, 0.0, 1.0)).lerp(GLOW_COLOR, clampf(heat * 2.0 - 1.0, 0.0, 1.0))


func _draw_leaf(base: Vector2, tip: Vector2, color: Color) -> void:
	var across: Vector2 = (tip - base).orthogonal().normalized() * 0.8
	draw_colored_polygon(PackedVector2Array([base, (base + tip) / 2.0 + across, tip,
		(base + tip) / 2.0 - across]), color)


## Coils round the thing it's tied to, and a tendril winding along it to each side,
## ending in a leaf. They burn when the fire reaches the tied end.
func _draw_wrap(char_time: float) -> void:
	if not is_tied or tie_thickness <= 0.0:
		return
	var color: Color = VINE_COLOR
	if burn_state != BurnState.INTACT:
		var age: float = burn_clock - _get_wrap_burn_at()
		if age >= char_time:
			return  # burnt away
		if age >= 0.0:
			color = _get_burning_color(age / char_time)
	var across: Vector2 = tie_axis.orthogonal()
	var half_height: float = tie_thickness / 2.0 + 0.7
	# The coils: slanted turns side by side, like a rope wound round a plank.
	for turn_index: int in WRAP_TURNS:
		var center: Vector2 = tie_point + tie_axis * ((turn_index - (WRAP_TURNS - 1) / 2.0) * WRAP_SPACING)
		draw_line(center - across * half_height - tie_axis * 0.7, center + across * half_height + tie_axis * 0.7,
			color if turn_index % 2 == 0 else color.darkened(0.3), 1.0)
	# The tendrils: zigzag from one face to the other as they wind along it. The long
	# one goes toward the holder's middle (+tie_axis), a stub the other way.
	var start_offset: float = (WRAP_TURNS / 2.0) * WRAP_SPACING
	for side: float in [-1.0, 1.0]:
		var previous: Vector2 = tie_point + tie_axis * side * start_offset
		var step_count: int = int((TENDRIL_LENGTH if side > 0.0 else OUTER_TENDRIL_LENGTH) / TENDRIL_STEP)
		for step_index: int in step_count:
			var face: float = 1.0 if step_index % 2 == 0 else -1.0
			# The tendril thins out toward its tip: it reaches less far round the plank.
			var reach: float = half_height * (1.0 - float(step_index) / (step_count + 1))
			var next: Vector2 = tie_point + tie_axis * side * (start_offset + (step_index + 1) * TENDRIL_STEP) \
				+ across * face * reach
			draw_line(previous, next, color, 1.0)
			previous = next
		if color == VINE_COLOR:
			_draw_leaf(previous, previous + tie_axis * side * 2.5 - across * 1.5, LEAF_COLOR)

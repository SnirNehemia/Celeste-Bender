@tool
class_name HangingPlatform
extends AnimatableBody2D
## Hanging platform (Fire_bending.md §6.2, Stage F8): a wooden plank held up by one
## or more Vines, with simple physics (F8 play-test: "like in real life"):
##   - while two or more vines hold it, it stays exactly as placed (asleep, no
##     simulation). Lying on ONE vine it's awake from the start (after the L9
##     play-test): it hangs from that one point as a real plank would, level if
##     tied in the middle, swinging down if tied off-center, then sleeps once still.
##     Stood on end (a drawbridge) one vine and the ground hold it: it sleeps.
##   - when a vine snaps, the plank wakes up: gravity pulls it, the vines that still
##     hold it keep it on a leash, so with one side let go it SWINGS round the other
##     vine; with all of them gone it falls, lands on the ground, tips over edges
##     and comes to rest. Then it sleeps again until something else lets go.
## It can also stand on end, held upright by a vine (a DRAWBRIDGE): cut the vine and
## it topples over, its foot staying put, and falls across a gap.
##
## The physics is "position-based" (the same idea as the vine rope): the plank is
## two points, its ends, each moved by Verlet integration (velocity = where it is -
## where it was last frame, plus gravity), then a few passes of corrections:
##   1. the ends stay platform_width apart (a stiff plank)
##   2. each holding vine: the point of the plank it's tied to stays within the
##      vine's length of the vine's anchor (a rope pulls, it never pushes)
##   3. the ground: points along the plank's underside are pushed back up out of
##      the floor (short rays down, layer 1 "world"); an end resting on the ground
##      doesn't slide (simple friction), which is what makes a drawbridge pivot.
## Moving a point in the middle of the plank moves both ends, each by its share
## (_move_point), so a push near one end mostly moves that end.
##
## Wiring is by SIGNAL, like a door: `vines` lists the Vine nodes holding it (picked
## in the Inspector), and in _ready() the plank connects to each one's `switched`
## signal to wake up. Every frame it's awake it tells each vine where its tie is
## (Vine.tie_to), so the vines (and their burning stubs) move with it and draw
## their coils round it. Where a vine is tied is worked out from the vine's
## end_point: the nearest point of the plank's middle line.
##
## Body: an AnimatableBody2D (a solid moved by script, see LeafPlatform) on layer 1
## ("world") with a ONE-WAY surface: you stand on it, jump up through it, and a
## falling plank passes over a player under it instead of crushing them. Its
## rotation follows the plank, flipped so that its one-way side always faces up.
##
## Place the node at the CENTER of the plank and set its rotation in the editor
## (0 = flat, about -90 = standing on end). It joins the room reset group.
##
## Swinging and bumping (after the L10 play-test):
##   - it's Pushable (group "pushable", layer 4 too): a gust wakes it and pushes
##     both ends, so a plank on two vines swings on them like a playground swing (the
##     leashes keep each tie on its circle round its anchor), and a plank on one vine
##     swings round it
##   - it doesn't pass through things: points every SAMPLE_SPACING px along it
##     (_get_sample_fractions; five points at first, but a 2-tile block fitted
##     between them and the plank sank into it, play-test round 4) each cast a ray from where they were last frame to where they are now (layer 1:
##     walls, ground, crates). A point that ran into something is put back on the
##     surface and its speed into it turned round, keeping collision_bounce of it.
##     Only that point is stopped, so a plank resting by one end on a block tips over
##     and falls the rest of the way, as a board would. (The first version undid the
##     whole move whenever any part overlapped: a plank lying half on a block froze
##     in mid-air. Floors are still handled by _push_out_of_ground, with friction.)
##
## VINE COVERED (`vine_covered`, after the L10 play-test): vines wound round the
## plank, joining it to every vine that holds it. It's then Flammable: fire on the
## plank (a fireball, a flame) or on ANY of its vines lights the cover, and the cover
## lights every vine still holding it at its knot in that same frame (play-test
## round 4: at once, not after the cover's burn): they snap together and the plank
## drops as it hangs, level. The cover chars away for cover_burn_time (only a look).

## Not in the §2 color key: a pale wood plank with darker grain.
const PLANK_COLOR: Color = Color(0.62, 0.47, 0.29)
const GRAIN_COLOR: Color = Color(0.42, 0.3, 0.17)
## Thickness of the plank, px.
const PLANK_THICKNESS: float = 4.0
## A little air drag on every frame of motion, so a swing slowly dies down.
const AIR_DAMPING: float = 0.998
const CONSTRAINT_ITERATIONS: int = 8
## It checks for ground and for running into things at points this many px apart
## along the plank, ends included (_get_sample_fractions): closer than the smallest
## thing it can land on (a single tile).
const SAMPLE_SPACING: float = 4.0
## Steeper than this (radians from flat, about 25 degrees) with both ends resting on
## something, its ends slide (see _push_out_of_ground).
const MAX_GRIP_SLOPE: float = 0.44
## The ground check looks from this far above each sample down to it, px. More than
## the farthest it can move in a frame (300 px/s ÷ 60 = 5 px), so it can't skip a floor.
const GROUND_PROBE_HEIGHT: float = 6.0
## It goes back to sleep once both ends moved less than this, px per frame, for
## SLEEP_FRAMES frames in a row.
const SLEEP_MOTION: float = 0.02
const SLEEP_FRAMES: int = 20
## A point bounces only when it hits faster than this, px per frame (60 px/s).
const MIN_BOUNCE_STEP: float = 1.0
## Contact friction (collision rays): the fraction of a point's slide along a surface
## it presses on that's lost each frame, and the slide (px per frame) below which it
## stops dead.
const CONTACT_FRICTION: float = 0.2
const STATIC_FRICTION_STEP: float = 0.1
## The fraction of its motion a plank touching something loses each frame.
const CONTACT_DAMPING: float = 0.1
## A steep plank held at two places slides downhill with this share of gravity's
## pull along it (see _apply_ground_friction).
const STEEP_SLIDE: float = 0.6
## See middle_rest_frames_left and end_rest_frames_left.
const MIDDLE_REST_MEMORY_FRAMES: int = 6
## The cover: vine colors (Vine's), wound every this many px, its flames' spacing.
const COVER_WRAP_SPACING: float = 6.0
const COVER_FLAME_SPACING: float = 12.0

enum CoverState { INTACT, BURNING, BURNT }

## Length of the plank, px.
@export var platform_width: float = 48.0:
	set(value):
		platform_width = value
		_resize_surface()
		queue_redraw()
## The vines holding it up.
@export var vines: Array[Switch] = []
## Falling: the player's gravity and top fall speed (GAME_DESIGN.md §4).
@export var gravity: float = 900.0
@export var max_fall_speed: float = 300.0
## Gusts: the fraction of the gust's strength (px/s) the plank's ends take on.
@export var gust_push_factor: float = 0.6
## Running into something: the fraction of its speed it bounces back with.
@export var collision_bounce: float = 0.3
## Vines wound round it: a fireball on it drops it whole (see the header).
@export var vine_covered: bool = false:
	set(value):
		vine_covered = value
		queue_redraw()
## Seconds the burning cover takes to char away (it lights the vines at once).
@export var cover_burn_time: float = 0.5
## Fallen this far below where it hung (out of the room), it's gone until R.
@export var fall_out_distance: float = 400.0

## The two ends of the plank's middle line, world coordinates, and where they were
## last frame (Verlet).
var plank_ends: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var previous_ends: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
## Each holding vine, where along the plank it's tied (0..1), and its leash length.
var held_vines: Array[Vine] = []
var tie_fractions: Array[float] = []
var leash_lengths: Array[float] = []
## How it was placed, for reset().
var start_transform: Transform2D
var is_awake: bool = false
## True once a vine has let go (it has moved since it was placed).
var has_fallen: bool = false
var is_gone: bool = false
var still_frames: int = 0
## Friction: the x an end resting on the ground is held at (NAN = not resting), and
## whether it touched the ground this frame.
var ground_pin_x: Array[float] = [NAN, NAN]
var touched_ground: Array[bool] = [false, false]
## True if a collision ray (_collide_points) hit anything this frame, or last frame
## (a contact found late in one frame still counts at the start of the next).
var has_contact: bool = false
var had_contact: bool = false
## Fractions along the plank that rested on the ground this frame (for friction).
var ground_contacts: Dictionary = {}
## Frames left in which a middle contact still counts: a point resting on a corner
## touches only now and then (it settles a hair, then rests again), so a contact
## counts for MIDDLE_REST_MEMORY_FRAMES frames.
var middle_rest_frames_left: int = 0
## The same memory for each end's touch of the ground (touched_ground).
var end_rest_frames_left: Array[int] = [0, 0]
var surface: CollisionShape2D
var cover_state: CoverState = CoverState.INTACT
var cover_burn_remaining: float = 0.0
var cover_flames: Array[FlameTongue] = []


func _ready() -> void:
	collision_layer = 1 | 8  # layer 1 "world": you stand on it; layer 4 "pushable": gusts find it
	collision_mask = 0   # it moves by script and never needs to detect anything
	surface = CollisionShape2D.new()
	surface.shape = RectangleShape2D.new()
	surface.one_way_collision = true  # solid only from above
	add_child(surface)
	_resize_surface()
	if Engine.is_editor_hint():
		return
	start_transform = global_transform
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(Pushable.GROUP)
	if vine_covered:
		add_to_group(Flammable.GROUP)
		_make_cover_flames()
	_place_ends_from_transform()
	for vine_switch: Switch in vines:
		var vine: Vine = vine_switch as Vine
		if vine == null:
			continue
		held_vines.append(vine)
		var tie_fraction: float = _get_fraction_nearest(vine.to_global(vine.end_point))
		tie_fractions.append(tie_fraction)
		leash_lengths.append(vine.global_position.distance_to(_get_point_at(tie_fraction)))
		vine.switched.connect(_on_vine_switched)
	is_awake = _hangs_on_one_vine()
	_tie_vines()


## True if exactly one vine holds it lying down: one point can't hold a plank
## still. A plank stood on end (more up than across: a drawbridge) rests on its
## foot, so its one vine is enough.
func _hangs_on_one_vine() -> bool:
	var is_on_end: bool = absf(start_transform.x.normalized().x) < 0.5
	return held_vines.size() == 1 and not is_on_end


## The plank's ends from the node's placement (its center and rotation).
func _place_ends_from_transform() -> void:
	var axis: Vector2 = start_transform.x.normalized()
	var center: Vector2 = start_transform.origin
	plank_ends[0] = center - axis * platform_width / 2.0
	plank_ends[1] = center + axis * platform_width / 2.0
	previous_ends = plank_ends.duplicate()


## A vine snapped (turned on): wake up and let physics take over.
func _on_vine_switched(is_now_on: bool) -> void:
	if is_now_on and not is_gone:
		is_awake = true
		has_fallen = true
		still_frames = 0


## True once it has been let go and has come to rest again.
func is_resting() -> bool:
	return has_fallen and not is_awake


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if cover_state == CoverState.BURNING:
		_advance_cover_burn(delta)  # also while it hangs asleep
	elif vine_covered and cover_state == CoverState.INTACT and _is_a_vine_burning():
		ignite(self)  # one of its vines caught: the cover takes the fire to the rest
	if not is_awake or is_gone:
		return
	# Where it was, for the collision rays below.
	var old_ends: PackedVector2Array = plank_ends.duplicate()
	# 1. Verlet: keep moving the way it moved last frame, plus gravity, with the fall
	#    speed capped like the player's.
	for end_index: int in 2:
		var velocity: Vector2 = (plank_ends[end_index] - previous_ends[end_index]) * AIR_DAMPING
		velocity.y = minf(velocity.y + gravity * delta * delta, max_fall_speed * delta)
		previous_ends[end_index] = plank_ends[end_index]
		plank_ends[end_index] += velocity
	# 2. Corrections, several passes (fixing one undoes a little of another).
	for end_index: int in 2:
		end_rest_frames_left[end_index] = MIDDLE_REST_MEMORY_FRAMES if touched_ground[end_index] else maxi(end_rest_frames_left[end_index] - 1, 0)
	touched_ground = [false, false]
	had_contact = has_contact
	has_contact = false
	if _rested_in_the_middle_this_frame():
		middle_rest_frames_left = MIDDLE_REST_MEMORY_FRAMES
	else:
		middle_rest_frames_left = maxi(middle_rest_frames_left - 1, 0)
	ground_contacts.clear()
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for iteration: int in CONSTRAINT_ITERATIONS:
		_keep_length()
		_keep_vine_leashes()
		_push_out_of_ground(space, old_ends)
		_collide_points(space, old_ends)
	for end_index: int in 2:
		if not touched_ground[end_index]:
			ground_pin_x[end_index] = NAN
	_apply_ground_friction(delta)
	_apply_to_body()
	_tie_vines()
	# 3. Back to sleep once still; gone once it has fallen out of the room.
	# How far the ends really moved this frame. (Not against previous_ends: friction and
	# bounces shift those to set the next frame's speed, which isn't motion.)
	var motion: float = maxf(plank_ends[0].distance_to(old_ends[0]), plank_ends[1].distance_to(old_ends[1]))
	still_frames = still_frames + 1 if motion < SLEEP_MOTION else 0
	if still_frames >= SLEEP_FRAMES:
		is_awake = false
	if global_position.y > start_transform.origin.y + fall_out_distance:
		is_gone = true
		is_awake = false
		visible = false
		surface.set_deferred("disabled", true)


## Each sample point that went into something solid this frame (a ray from where
## it was, in `old_ends`, to where it is) goes back onto the surface, and its speed
## into the surface is turned round, keeping collision_bounce of it. Moving one
## point moves both ends by their shares (_move_point), so only that part stops.
## Verlet: a point's velocity is now - before, so turning it round means moving its
## "before" (the ends' previous positions) to the other side.
func _collide_points(space: PhysicsDirectSpaceState2D, old_ends: PackedVector2Array) -> void:
	# A steep plank gets no friction from what it touches: it slides off (see
	# _apply_ground_friction).
	var is_steep: bool = absf((plank_ends[1] - plank_ends[0]).normalized().y) > sin(MAX_GRIP_SLOPE)
	for fraction: float in _get_sample_fractions():
		var from: Vector2 = old_ends[0].lerp(old_ends[1], fraction)
		var to: Vector2 = _get_point_at(fraction)
		if from.distance_squared_to(to) < 0.0001:
			continue
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 1, [get_rid()]))
		if hit.is_empty():
			continue
		has_contact = true
		var normal: Vector2 = hit.normal
		var surface_point: Vector2 = (hit.position as Vector2) + normal * 0.05
		_move_point(fraction, surface_point - to)
		var before: Vector2 = previous_ends[0].lerp(previous_ends[1], fraction)
		var step: Vector2 = surface_point - before
		var into: float = step.dot(normal)
		if into < 0.0:
			# Wanted step: the same along the surface, (1 + bounce) less into it. A soft
			# touch (resting, sliding) only loses its speed into the surface: bouncing
			# it too would jiggle a resting plank forever, and it would never sleep.
			var bounce: float = collision_bounce if -into > MIN_BOUNCE_STEP else 0.0
			_move_previous(fraction, normal * into * (1.0 + bounce))
			# Friction while pressing on it: part of the slide along the surface is
			# lost every frame, all of it once it's slow (it stops instead of creeping).
			if not is_steep:
				var slide: Vector2 = step - normal * into
				var grip: float = 1.0 if slide.length() < STATIC_FRICTION_STEP else CONTACT_FRICTION
				_move_previous(fraction, slide * grip)


## Where along the plank (0 = first end, 1 = other end) it checks for ground and
## collisions: both ends and every SAMPLE_SPACING px between.
func _get_sample_fractions() -> Array[float]:
	var count: int = maxi(int(ceilf(platform_width / SAMPLE_SPACING)), 1)
	var fractions: Array[float] = []
	for sample_index: int in count + 1:
		fractions.append(float(sample_index) / count)
	return fractions


## Like _move_point, for the ends' previous positions (their Verlet "before").
func _move_previous(fraction: float, offset: Vector2) -> void:
	var first_share: float = 1.0 - fraction
	var second_share: float = fraction
	var share_scale: float = 1.0 / (first_share * first_share + second_share * second_share)
	previous_ends[0] += offset * first_share * share_scale
	previous_ends[1] += offset * second_share * share_scale


# --- The vine cover (Flammable contract) ------------------------------------------

## Lights the cover (once). A plank without one isn't in the flammable group at all.
func ignite(_source: Node) -> void:
	if not vine_covered or cover_state != CoverState.INTACT:
		return
	cover_state = CoverState.BURNING
	cover_burn_remaining = cover_burn_time
	for flame: FlameTongue in cover_flames:
		flame.visible = true
	# Every vine still holding it, lit at its knot now: they snap together.
	for vine_index: int in held_vines.size():
		var vine: Vine = held_vines[vine_index]
		if not vine.is_on():
			vine.ignite_at(_get_point_at(tie_fractions[vine_index]), 1.0, self)
	EmberEmitter.burst(get_parent(), global_position, 6, Vector2.UP, 120.0, 40.0)
	FX.play_sfx(&"fire_ignite")


func is_burning() -> bool:
	return cover_state == CoverState.BURNING


## Gusts don't put it out (like the vines themselves).
func snuff() -> void:
	pass


## The plank's box, world coordinates, a little grown: where fire catches it.
func get_fire_rect() -> Rect2:
	var local_box: Rect2 = Rect2(-platform_width / 2.0, -PLANK_THICKNESS / 2.0, platform_width, PLANK_THICKNESS)
	return (global_transform * local_box).grow(1.0)


## True if any vine holding it has caught fire.
func _is_a_vine_burning() -> bool:
	for vine: Vine in held_vines:
		if vine.is_burning():
			return true
	return false


## The cover chars away, then it's gone (the vines were lit when it caught).
func _advance_cover_burn(delta: float) -> void:
	cover_burn_remaining -= delta
	queue_redraw()
	if cover_burn_remaining > 0.0:
		return
	cover_state = CoverState.BURNT
	for flame: FlameTongue in cover_flames:
		flame.visible = false
	SmokePuff.spawn(get_parent(), global_position, 4)


## Small flames along the plank, hidden until the cover burns (a FlameMerge draws
## them as one fire, like the crate's).
func _make_cover_flames() -> void:
	var flame_merge: FlameMerge = FlameMerge.make(self)
	var count: int = maxi(2, int(platform_width / COVER_FLAME_SPACING))
	for flame_index: int in count:
		var flame: FlameTongue = FlameTongue.new()
		flame.position = Vector2((flame_index + 0.5) / count * platform_width - platform_width / 2.0, -PLANK_THICKNESS / 2.0)
		flame.length = 6.0
		flame.base_width = 4.0
		flame.fan_width = 4.0
		flame.heat = 0.55
		flame.lick_rate = 5.0
		flame.lick_size = 2.0
		flame.lick_speed = 18.0
		flame.smoke_rate = 3.0 if flame_index == 0 else 0.0
		flame.visible = false
		add_child(flame)
		flame_merge.add_tongue(flame)
		cover_flames.append(flame)


## The Pushable contract: a gust (or the dash wake) hit it. It wakes up and both
## ends get the push as speed (Verlet: moving `previous_ends` back is a velocity).
func receive_gust(direction: Vector2, strength: float) -> void:
	if is_gone:
		return
	var push: Vector2 = direction * strength * gust_push_factor * get_physics_process_delta_time()
	for end_index: int in 2:
		previous_ends[end_index] -= push
	is_awake = true
	still_frames = 0


## The ends stay platform_width apart: each moves half of the error.
func _keep_length() -> void:
	var difference: Vector2 = plank_ends[1] - plank_ends[0]
	var distance: float = difference.length()
	if distance <= 0.0:
		return
	var correction: Vector2 = difference * ((distance - platform_width) / distance) * 0.5
	plank_ends[0] += correction
	plank_ends[1] -= correction


## Each vine still holding: its tie point stays within the leash of its anchor.
func _keep_vine_leashes() -> void:
	for vine_index: int in held_vines.size():
		if held_vines[vine_index].is_on():
			continue  # snapped: it holds nothing any more
		var tie_point: Vector2 = _get_point_at(tie_fractions[vine_index])
		var from_anchor: Vector2 = tie_point - held_vines[vine_index].global_position
		var distance: float = from_anchor.length()
		if distance > leash_lengths[vine_index]:
			_move_point(tie_fractions[vine_index], -from_anchor * ((distance - leash_lengths[vine_index]) / distance))


## Points along the underside that went into the floor are pushed back up onto it.
## An end resting on the floor keeps its x (it doesn't slide).
func _push_out_of_ground(space: PhysicsDirectSpaceState2D, old_ends: PackedVector2Array) -> void:
	var axis: Vector2 = (plank_ends[1] - plank_ends[0]).normalized()
	var old_axis: Vector2 = (old_ends[1] - old_ends[0]).normalized()
	# Grip is finite (play-test round 4): when the plank is steeper than
	# MAX_GRIP_SLOPE and something besides one end holds it up too (its other end on
	# the ground, or any point touching a block, a corner, a wall: has_contact), its
	# ends slide instead of being pinned. So a plank caught on the edge or corner of a
	# block slides off and lies down. One end alone on the ground (a drawbridge's
	# foot while it topples) keeps its grip.
	var is_steep: bool = absf(axis.y) > sin(MAX_GRIP_SLOPE)
	# The underside is half the thickness below the middle line when flat, and right
	# at the ends' tips when standing on end.
	var underside_offset: Vector2 = Vector2(0.0, absf(axis.x) * PLANK_THICKNESS / 2.0)
	for fraction: float in _get_sample_fractions():
		var sample: Vector2 = _get_point_at(fraction) + underside_offset
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			sample - Vector2(0.0, GROUND_PROBE_HEIGHT), sample, 1, [get_rid()])
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector2).y > -0.5:
			continue  # nothing there, or a wall/ceiling rather than a floor
		# Only a point that came down onto this surface lands on it: one that was
		# already below its top last frame is beside the block (a steep plank sliding
		# past its corner), and lifting it onto the top made planks climb blocks and
		# hang off their corners (play-test round 4). The collision rays handle it.
		var old_sample: Vector2 = old_ends[0].lerp(old_ends[1], fraction) + Vector2(0.0, absf(old_axis.x) * PLANK_THICKNESS / 2.0)
		if old_sample.y > (hit.position as Vector2).y + 0.5:
			continue
		_move_point(fraction, Vector2(0.0, (hit.position as Vector2).y - sample.y))
		ground_contacts[fraction] = true
		if fraction == 0.0 or fraction == 1.0:
			var end_index: int = int(fraction)
			touched_ground[end_index] = true
			if is_steep and (_end_rests(1 - end_index) or has_contact or had_contact or _rests_in_the_middle()):
				ground_pin_x = [NAN, NAN]  # held at two places on a slant: it slides
			elif is_nan(ground_pin_x[end_index]):
				ground_pin_x[end_index] = plank_ends[end_index].x
			else:
				plank_ends[end_index].x = ground_pin_x[end_index]


## Friction where it rests on the ground (once a frame, after the corrections):
## every point that rested on the ground this frame loses part of its sideways
## slide, all of it once slow, so a plank lying on a slope or across a ledge stops
## instead of creeping. Not on a steep plank: that one slides off (see
## _push_out_of_ground). The ends' grip (ground_pin_x) comes on top.
func _apply_ground_friction(delta: float) -> void:
	# Touching anything costs a little of all its motion (contacts lose energy), so a
	# plank balanced on a ledge's edge stops rocking like a seesaw and settles.
	if not ground_contacts.is_empty() or has_contact:
		for end_index: int in 2:
			previous_ends[end_index] += (plank_ends[end_index] - previous_ends[end_index]) * CONTACT_DAMPING
	var axis: Vector2 = (plank_ends[1] - plank_ends[0]).normalized()
	if absf(axis.y) > sin(MAX_GRIP_SLOPE):
		# Steep and held up at two places (both ends, or an end and a corner): it
		# slides downhill along itself, as a board resting on a block's edge slips off
		# it (play-test round 4: it stayed leaning on the corner). Gravity's share
		# along the plank, times STEEP_SLIDE, added as speed (Verlet: via previous_ends).
		var held_at_two_places: bool = (_end_rests(0) and _end_rests(1)) 			or ((_end_rests(0) or _end_rests(1)) and (has_contact or had_contact or _rests_in_the_middle()))
		if held_at_two_places:
			var downhill: Vector2 = axis if axis.y > 0.0 else -axis
			var push: Vector2 = downhill * gravity * delta * delta * absf(axis.y) * STEEP_SLIDE
			for end_index: int in 2:
				previous_ends[end_index] -= push
		return
	for fraction: float in ground_contacts:
		var before: Vector2 = previous_ends[0].lerp(previous_ends[1], fraction)
		var slide_x: float = _get_point_at(fraction).x - before.x
		var grip: float = 1.0 if absf(slide_x) < STATIC_FRICTION_STEP else CONTACT_FRICTION
		_move_previous(fraction, Vector2(slide_x * grip, 0.0))


## True if a point between the ends rested on the ground this frame (the plank lies
## across a ledge or a block's corner), or last frame.
## True if end `end_index` rests on the ground now or did a few frames ago.
func _end_rests(end_index: int) -> bool:
	return touched_ground[end_index] or end_rest_frames_left[end_index] > 0


func _rests_in_the_middle() -> bool:
	return middle_rest_frames_left > 0 or _rested_in_the_middle_this_frame()


func _rested_in_the_middle_this_frame() -> bool:
	for fraction: float in ground_contacts:
		if fraction > 0.0 and fraction < 1.0:
			return true
	return false


## Moves the plank's point at `fraction` by `offset`, sharing it between the ends:
## the nearer end moves more. The weights are worked out so that the point itself
## ends up moved by exactly `offset` (position-based dynamics on a segment).
func _move_point(fraction: float, offset: Vector2) -> void:
	var first_share: float = 1.0 - fraction
	var second_share: float = fraction
	var share_scale: float = 1.0 / (first_share * first_share + second_share * second_share)
	plank_ends[0] += offset * first_share * share_scale
	plank_ends[1] += offset * second_share * share_scale


func _get_point_at(fraction: float) -> Vector2:
	return plank_ends[0].lerp(plank_ends[1], fraction)


## 0..1: where along the plank the point nearest `world_point` is.
func _get_fraction_nearest(world_point: Vector2) -> float:
	var along: Vector2 = plank_ends[1] - plank_ends[0]
	if along.length_squared() <= 0.0:
		return 0.5
	return clampf((world_point - plank_ends[0]).dot(along) / along.length_squared(), 0.0, 1.0)


## Puts the body on the plank: centered between the ends, turned along them. Turned
## half a turn more when its first end is on the right, so the one-way side faces up.
func _apply_to_body() -> void:
	var axis: Vector2 = plank_ends[1] - plank_ends[0]
	var angle: float = axis.angle()
	if axis.x < 0.0:
		angle += PI
	# One assignment for both: setting global_position and then global_rotation on a
	# synced AnimatableBody2D put the old position back (the rotation setter rebuilt
	# the transform from the body's last synced one).
	global_transform = Transform2D(angle, (plank_ends[0] + plank_ends[1]) / 2.0)


## Tells every vine where it's tied now (they follow it and draw their coils). The
## axis given points toward the plank's middle, so a vine tied near an end winds its
## long tendril along the plank, not off its end.
func _tie_vines() -> void:
	var axis: Vector2 = plank_ends[1] - plank_ends[0]
	for vine_index: int in held_vines.size():
		var toward_middle: Vector2 = axis if tie_fractions[vine_index] <= 0.5 else -axis
		held_vines[vine_index].tie_to(_get_point_at(tie_fractions[vine_index]), toward_middle, PLANK_THICKNESS)


## Called by Room.reset_objects() on death or R: back where it was placed.
func reset() -> void:
	is_awake = false
	has_fallen = false
	is_gone = false
	still_frames = 0
	ground_pin_x = [NAN, NAN]
	end_rest_frames_left = [0, 0]
	middle_rest_frames_left = 0
	has_contact = false
	had_contact = false
	global_transform = start_transform
	_place_ends_from_transform()
	visible = true
	surface.set_deferred("disabled", false)
	is_awake = _hangs_on_one_vine()
	cover_state = CoverState.INTACT
	for flame: FlameTongue in cover_flames:
		flame.visible = false
	queue_redraw()
	_tie_vines()


func _resize_surface() -> void:
	if surface == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(surface.shape as RectangleShape2D).size = Vector2(platform_width, PLANK_THICKNESS)
	surface.position = Vector2.ZERO


func _draw() -> void:
	var half_width: float = platform_width / 2.0
	var half_thickness: float = PLANK_THICKNESS / 2.0
	draw_rect(Rect2(-half_width, -half_thickness, platform_width, PLANK_THICKNESS), PLANK_COLOR)
	draw_line(Vector2(-half_width, half_thickness - 0.5), Vector2(half_width, half_thickness - 0.5), GRAIN_COLOR, 1.0)
	# A grain line and the plank seams every 16 px, so it reads as boards.
	draw_line(Vector2(-half_width + 2.0, 0.0), Vector2(half_width - 6.0, 0.0), GRAIN_COLOR, 1.0)
	var seam_x: float = -half_width + 16.0
	while seam_x < half_width:
		draw_line(Vector2(seam_x, -half_thickness), Vector2(seam_x, half_thickness), GRAIN_COLOR, 1.0)
		seam_x += 16.0
	if vine_covered and cover_state != CoverState.BURNT:
		_draw_cover(half_width, half_thickness)


## The vine cover: strands wound slantwise round the plank, a leaf on every other
## turn. While it burns it chars from green to black and glows ember red.
func _draw_cover(half_width: float, half_thickness: float) -> void:
	var char_amount: float = 0.0
	if cover_state == CoverState.BURNING:
		char_amount = 1.0 - clampf(cover_burn_remaining / maxf(cover_burn_time, 0.01), 0.0, 1.0)
	var strand_color: Color = Vine.VINE_COLOR.lerp(Vine.EMBER_COLOR, minf(char_amount * 2.0, 1.0)).lerp(Vine.BURNT_COLOR, char_amount)
	var leaf_color: Color = Vine.LEAF_COLOR.lerp(Vine.BURNT_COLOR, char_amount)
	var wrap_index: int = 0
	var x: float = -half_width + COVER_WRAP_SPACING / 2.0
	while x < half_width - 2.0:
		draw_line(Vector2(x, -half_thickness - 0.5), Vector2(x + 2.0, half_thickness + 0.5), strand_color, 1.0)
		if wrap_index % 2 == 0:
			draw_rect(Rect2(x - 1.0, -half_thickness - 2.0, 2.0, 1.0), leaf_color)
		x += COVER_WRAP_SPACING
		wrap_index += 1

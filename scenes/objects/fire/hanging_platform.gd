@tool
class_name HangingPlatform
extends AnimatableBody2D
## Hanging platform (Fire_bending.md §6.2, Stage F8): a wooden plank held up by one
## or more Vines, with simple physics (F8 play-test: "like in real life"):
##   - while every vine holds, it stays exactly as placed (asleep, no simulation)
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

## Not in the §2 color key: a pale wood plank with darker grain.
const PLANK_COLOR: Color = Color(0.62, 0.47, 0.29)
const GRAIN_COLOR: Color = Color(0.42, 0.3, 0.17)
## Thickness of the plank, px.
const PLANK_THICKNESS: float = 4.0
## A little air drag on every frame of motion, so a swing slowly dies down.
const AIR_DAMPING: float = 0.998
const CONSTRAINT_ITERATIONS: int = 8
## Where along the plank (0 = first end, 1 = other end) it checks for ground.
const GROUND_SAMPLES: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
## The ground check looks from this far above each sample down to it, px. More than
## the farthest it can move in a frame (300 px/s ÷ 60 = 5 px), so it can't skip a floor.
const GROUND_PROBE_HEIGHT: float = 6.0
## It goes back to sleep once both ends moved less than this, px per frame, for
## SLEEP_FRAMES frames in a row.
const SLEEP_MOTION: float = 0.02
const SLEEP_FRAMES: int = 20

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
var surface: CollisionShape2D


func _ready() -> void:
	collision_layer = 1  # bit value of layer 1, "world": you stand on it
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
	_tie_vines()


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
	if Engine.is_editor_hint() or not is_awake or is_gone:
		return
	# 1. Verlet: keep moving the way it moved last frame, plus gravity, with the fall
	#    speed capped like the player's.
	for end_index: int in 2:
		var velocity: Vector2 = (plank_ends[end_index] - previous_ends[end_index]) * AIR_DAMPING
		velocity.y = minf(velocity.y + gravity * delta * delta, max_fall_speed * delta)
		previous_ends[end_index] = plank_ends[end_index]
		plank_ends[end_index] += velocity
	# 2. Corrections, several passes (fixing one undoes a little of another).
	touched_ground = [false, false]
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for iteration: int in CONSTRAINT_ITERATIONS:
		_keep_length()
		_keep_vine_leashes()
		_push_out_of_ground(space)
	for end_index: int in 2:
		if not touched_ground[end_index]:
			ground_pin_x[end_index] = NAN
	_apply_to_body()
	_tie_vines()
	# 3. Back to sleep once still; gone once it has fallen out of the room.
	var motion: float = maxf(plank_ends[0].distance_to(previous_ends[0]), plank_ends[1].distance_to(previous_ends[1]))
	still_frames = still_frames + 1 if motion < SLEEP_MOTION else 0
	if still_frames >= SLEEP_FRAMES:
		is_awake = false
	if global_position.y > start_transform.origin.y + fall_out_distance:
		is_gone = true
		is_awake = false
		visible = false
		surface.set_deferred("disabled", true)


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
func _push_out_of_ground(space: PhysicsDirectSpaceState2D) -> void:
	var axis: Vector2 = (plank_ends[1] - plank_ends[0]).normalized()
	# The underside is half the thickness below the middle line when flat, and right
	# at the ends' tips when standing on end.
	var underside_offset: Vector2 = Vector2(0.0, absf(axis.x) * PLANK_THICKNESS / 2.0)
	for fraction: float in GROUND_SAMPLES:
		var sample: Vector2 = _get_point_at(fraction) + underside_offset
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			sample - Vector2(0.0, GROUND_PROBE_HEIGHT), sample, 1, [get_rid()])
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector2).y > -0.5:
			continue  # nothing there, or a wall/ceiling rather than a floor
		_move_point(fraction, Vector2(0.0, (hit.position as Vector2).y - sample.y))
		if fraction == 0.0 or fraction == 1.0:
			var end_index: int = int(fraction)
			touched_ground[end_index] = true
			if is_nan(ground_pin_x[end_index]):
				ground_pin_x[end_index] = plank_ends[end_index].x
			else:
				plank_ends[end_index].x = ground_pin_x[end_index]


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
	global_transform = start_transform
	_place_ends_from_transform()
	visible = true
	surface.set_deferred("disabled", false)
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

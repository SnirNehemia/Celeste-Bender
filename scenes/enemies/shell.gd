@tool
class_name Shell
extends CharacterBody2D
## Shell (Fire_bending.md §7.2, Stage F12): the armored crawler, Earth's own enemy,
## built in the Fire chapter as an obstacle fire can't touch. A squat 12x8 crawler of
## slate-gray plates with ochre seams. ONLY A BIG ROCK KILLS IT: a thrown 16x16 rock,
## or a loose big rock dropped onto it from 2+ tiles (Boulder._drop_onto_enemies).
##
## Place the node ON the floor, at the bottom-center of the Shell (origin at the feet,
## like the wisp and the monkey).
##
## States:
##   WALK      a slow patrol at shell_walk_speed, turning at walls, ledges and spikes
##             (it never walks off or onto them by itself). Gravity: when the floor
##             under it goes (a thicket floor burns away) it FALLS, and walks on
##             wherever it lands. Deadly to touch. On an ice slope (Stage W6) it
##             can't walk or stop: it slides down it (IceSlope.slide_object).
##   STAGGER   a small rock clonked it: it stops for shell_stagger_time, knocked back
##             shell_stagger_knockback px. Still deadly (it's armored, not stunned).
##   DEFEATED  a big rock cracked it open, or it was CRUSHED: slate and ochre pebbles,
##             gone until reset.
##
## CRUSHED (after the F12 plan, the developer's call): its armor holds against any hit,
## but not against being squeezed. Each is a CRUSH hit or ends in _crack_open():
##   - the snake's head ramming it into a wall: EarthSnake carries bodies a tile and,
##     when a wall is in the way, crushes the ones whose table says CRUSH kills
##   - a small rock with a wall within shell_crush_reach (one tile) behind it
##     (_stagger; it patrols turning a pixel before walls, so the 4 px knockback alone
##     would almost never reach one: play-test)
##   - a rising column pressing it against a ceiling (EarthColumn, Pushable.try_crush)
## A knockback that a wall stops is a crush too (_physics_process).
##
## Everything else is shrugged off (its ElementImmunity row, _make_immunity):
##   - a fireball sparks off its plates and BOUNCES (REFLECT; the pip is still spent)
##   - flames, the jet and burning grass do nothing (it walks through fire)
##   - spikes do nothing
##   - a column's tip lifts it; the snake's head carries it one tile (into a wall:
##     crushed, see CRUSHED)
##   - a gust barely nudges it (shell_gust_nudge_speed, it's heavy)
##   - sentry orbs, reflected or not, bounce off its plates (REFLECTS_GROUP)
##
## Contracts: EnemyHit (group "enemies" + receive_hit), Pushable (group "pushable" +
## receive_gust: the gust), EnemyHit.REFLECTS_GROUP (orbs bounce),
## Room.RESETTABLE_GROUP + reset(), the `defeated` signal (EnemyGate counts it).
## Not Flammable, not a heat receiver: fire has nothing to hold on to.
##
## Physics: like the wisp, a body on layers 4 ("pushable") and 5 ("enemies"),
## colliding only with layer 1 ("world"). Touching the player is a rectangle check
## every frame (_check_player).
##
## Look: flat rects on the pixel grid, like the thicket elephant: a stepped slate dome
## (light top row, dark rim), ochre seams between the plates, a small head with one
## enemy-purple eye, two pairs of stubby feet that step. The drawing is snapped to
## whole pixels and never rotated. Its collision box is the dome + head's outline.
##
## Every number that changes the feel is in FireTuning, group "Shell" (F5 panel).

enum State { WALK, STAGGER, DEFEATED }

## Emitted once when a big rock cracks it open. EnemyGate listens.
signal defeated

const SLATE_COLOR: Color = Color(0.36, 0.4, 0.46)
const SLATE_LIGHT_COLOR: Color = Color(0.52, 0.56, 0.63)
const SLATE_DARK_COLOR: Color = Color(0.22, 0.25, 0.3)
const SEAM_COLOR: Color = Color(0.8, 0.6, 0.24)
const SKIN_COLOR: Color = Color(0.45, 0.42, 0.36)
const EYE_COLOR: Color = Color(0.69, 0.42, 0.94)
const SPARK_COLOR: Color = Color(1.0, 0.95, 0.75)
const PEBBLE_COLORS: Array[Color] = [SLATE_COLOR, SLATE_DARK_COLOR, SEAM_COLOR]
## Its size, px (origin at the bottom-center). The collision box.
const BODY_SIZE: Vector2 = Vector2(12, 8)
## The drawing, facing right, origin at the feet, back to front. The dome steps in a
## pixel per row (a rounded top), the head pokes out in front.
const BODY_RECTS: Array = [
	[Rect2(-4, -8, 8, 1), SLATE_LIGHT_COLOR],
	[Rect2(-5, -7, 10, 1), SLATE_LIGHT_COLOR],
	[Rect2(-6, -6, 11, 3), SLATE_COLOR],
	[Rect2(-6, -3, 11, 1), SLATE_DARK_COLOR],
	[Rect2(4, -5, 2, 3), SKIN_COLOR],      # the head
	[Rect2(5, -5, 1, 1), EYE_COLOR],
	# Ochre seams between the plates.
	[Rect2(-2, -7, 1, 4), SEAM_COLOR],
	[Rect2(1, -7, 1, 4), SEAM_COLOR],
	[Rect2(-5, -5, 3, 1), SEAM_COLOR],
	[Rect2(2, -5, 2, 1), SEAM_COLOR],
]
## Feet: x of each (two pairs), 2x2 under the rim; they lift a pixel in turn.
const FEET_X: Array[float] = [-5.0, -2.0, 1.0, 3.0]
const FOOT_SIZE: Vector2 = Vector2(2, 2)
## Bit value of the spikes' layer (3, "hazards"): it turns before them.
const SPIKES_MASK: int = 4
## How far ahead of its front it looks for walls, ledges and spikes, px.
const LOOK_AHEAD: float = 1.0
const GRAVITY: float = 900.0
const MAX_FALL_SPEED: float = 300.0
## Below its start by this much: it fell out of the room (a pit): gone.
const FALL_OUT_DISTANCE: float = 200.0

## Which way it starts walking: 1 = right, -1 = left.
@export_enum("Left:-1", "Right:1") var start_direction: int = 1:
	set(value):
		start_direction = value
		queue_redraw()
## What each kind of hit does to it. Empty = the table in _make_immunity().
@export var immunity: ElementImmunity

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var state: State = State.WALK
## 1 = walking right, -1 = left.
var walk_direction: float = 1.0
var stagger_remaining: float = 0.0
## A slide on top of its walk (a gust's nudge), px/s, dying out at shell_push_decel.
var push_speed: float = 0.0
## A shove in progress (the snake, a small rock's knockback): px still to go and which
## way, at shell_shove_speed.
var shove_remaining: float = 0.0
var shove_direction: float = 0.0
var home_room: Room = null
var start_position: Vector2
var stride_distance: float = 0.0
## Sparks off its plates (a fireball): seconds left of the glint.
var glint_remaining: float = 0.0
var hitbox: CollisionShape2D


func _ready() -> void:
	collision_layer = 8 | 16  # bit values of layer 4 "pushable" and layer 5 "enemies"
	collision_mask = 1        # stands on and bumps into "world" only
	hitbox = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = BODY_SIZE
	hitbox.shape = box
	hitbox.position = Vector2(0.0, -BODY_SIZE.y / 2.0)
	add_child(hitbox)
	if Engine.is_editor_hint():
		return
	start_position = global_position
	walk_direction = float(start_direction)
	if immunity == null:
		immunity = _make_immunity()
	add_to_group(EnemyHit.GROUP)
	add_to_group(EnemyHit.REFLECTS_GROUP)
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	home_room = Room.find_room_of(self)


## The Shell's row of the §7.2 table: a big rock and crushing kill it. A small rock
## (sloppy or perfect) staggers it, a gust and the column/snake push it (into a wall:
## crushed, see _physics_process), fireballs and reflected orbs bounce off. Fire,
## spikes and the whip do nothing.
static func _make_immunity() -> ElementImmunity:
	var push: ElementImmunity.Response = ElementImmunity.Response.PUSH
	var stagger: ElementImmunity.Response = ElementImmunity.Response.STAGGER
	var reflect: ElementImmunity.Response = ElementImmunity.Response.REFLECT
	return ElementImmunity.from_table({
		EnemyHit.Type.BIG_ROCK: ElementImmunity.Response.KILL, EnemyHit.Type.CRUSH: ElementImmunity.Response.KILL,
		EnemyHit.Type.PERFECT_ROCK: stagger, EnemyHit.Type.SMALL_ROCK: stagger,
		EnemyHit.Type.GUST: push, EnemyHit.Type.EARTH_PUSH: push,
		EnemyHit.Type.FIREBALL: reflect, EnemyHit.Type.REFLECTED_ORB: reflect,
	})


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or state == State.DEFEATED or not _is_awake():
		return
	glint_remaining = maxf(glint_remaining - delta, 0.0)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if state == State.STAGGER:
		stagger_remaining -= delta
		if stagger_remaining <= 0.0:
			state = State.WALK
	var walk_speed: float = 0.0
	if state == State.WALK and is_on_floor() and shove_remaining <= 0.0:
		if _should_turn():
			walk_direction = -walk_direction
		walk_speed = walk_direction * fire_tuning.shell_walk_speed
	var shove_speed: float = 0.0
	var is_shoved: bool = shove_remaining > 0.0
	if is_shoved:
		# The last frame only covers what's left, so a shove is exactly its distance.
		var shove_step_speed: float = minf(fire_tuning.shell_shove_speed, shove_remaining / delta)
		shove_speed = shove_direction * shove_step_speed
		shove_remaining -= shove_step_speed * delta
	push_speed = move_toward(push_speed, 0.0, fire_tuning.shell_push_decel * delta)
	if IceSlope.slide_object(self, GRAVITY, delta):
		# On an ice slope (Stage W6) it can't walk or stop: it slides down it.
		walk_speed = 0.0
	else:
		velocity.x = walk_speed + shove_speed + push_speed
	move_and_slide()
	if is_on_wall():
		# Shoved into the wall (the snake, a small rock's knockback): crushed.
		if is_shoved and get_wall_normal().x * shove_direction < 0.0:
			_crack_open(Vector2(shove_direction, 0.0))
			return
		push_speed = 0.0
	stride_distance += absf(walk_speed) * delta
	_keep_inside_room()
	if global_position.y > start_position.y + FALL_OUT_DISTANCE:
		defeat()
		return
	_check_player()
	queue_redraw()


## Turn here? A wall or step ahead, no floor ahead (a ledge; not on top of a column,
## which it walks off), or spikes ahead. The wall is checked first: against a step the
## ledge ray would start inside it (the monkey's fix).
func _should_turn() -> bool:
	var front_x: float = global_position.x + walk_direction * (BODY_SIZE.x / 2.0 + LOOK_AHEAD)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var point_query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	point_query.position = Vector2(front_x, global_position.y - 2.0)
	point_query.collision_mask = 1
	point_query.exclude = [get_rid()]
	if not space.intersect_point(point_query, 1).is_empty():
		return true
	# Spikes: an Area2D on the hazards layer, in the cell just ahead at foot height.
	var spikes_query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	spikes_query.position = Vector2(front_x + walk_direction * 2.0, global_position.y - 1.0)
	spikes_query.collision_mask = SPIKES_MASK
	spikes_query.collide_with_areas = true
	spikes_query.collide_with_bodies = false
	for result: Dictionary in space.intersect_point(spikes_query, 4):
		if result["collider"] is Spikes:
			return true
	var ray_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(front_x, global_position.y - 2.0), Vector2(front_x, global_position.y + 4.0), 1)
	ray_query.exclude = [get_rid()]
	return space.intersect_ray(ray_query).is_empty() and not _is_standing_on_column()


## On top of an Earth Column it doesn't turn at the edge (no route up there), like
## the wisp and the monkey: it walks off and drops back down.
func _is_standing_on_column() -> bool:
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision.get_normal().y < -0.7 and collision.get_collider() is EarthColumn:
			return true
	return false


## Deadly to touch, always (armor doesn't get dizzy).
func _check_player() -> void:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player != null and not player.is_dead() and get_hitbox_global_rect().intersects(player.get_hitbox_rect()):
		player.die()


# --- Hits -------------------------------------------------------------------------------

## The EnemyHit contract: every hit lands here (see _make_immunity for the table).
func receive_hit(hit: EnemyHit) -> ElementImmunity.Response:
	if state == State.DEFEATED:
		return ElementImmunity.Response.IGNORE
	var response: ElementImmunity.Response = immunity.get_response(hit.type)
	match response:
		ElementImmunity.Response.KILL:
			_crack_open(hit.push_velocity)
		ElementImmunity.Response.STAGGER:
			_stagger(hit)
		ElementImmunity.Response.PUSH:
			_be_pushed(hit)
		ElementImmunity.Response.REFLECT:
			_spark(hit)
	return response


## A small rock: stops, knocked back a few px along the rock's flight.
func _stagger(hit: EnemyHit) -> void:
	state = State.STAGGER
	stagger_remaining = fire_tuning.shell_stagger_time
	var away: float = signf(hit.push_velocity.x)
	if away == 0.0:
		away = -walk_direction
	# A wall within a tile behind it: nowhere to go, crushed. test_move asks "would
	# moving this far hit something?" without moving.
	if test_move(global_transform, Vector2(away * fire_tuning.shell_crush_reach, 0.0)):
		_crack_open(Vector2(away, 0.0))
		return
	_start_shove(away, fire_tuning.shell_stagger_knockback)
	FX.spawn_gravel(_get_center(), 2, Vector2(away, -1.0).normalized())
	FX.play_sfx(&"shell_clonk")


## A gust nudges it; a column's tip (an upward push) lifts it as given. A sideways
## push is the snake's head, which has already carried it a tile (EarthSnake moves
## the bodies in its way itself): nothing more, or it would slide a second tile.
func _be_pushed(hit: EnemyHit) -> void:
	var push: Vector2 = hit.push_velocity
	if hit.type == EnemyHit.Type.GUST:
		push_speed = signf(push.x) * fire_tuning.shell_gust_nudge_speed
	elif absf(push.y) > absf(push.x):
		velocity.y = push.y


func _start_shove(direction: float, distance: float) -> void:
	shove_direction = direction
	shove_remaining = distance


## A fireball (or any reflected hit) glances off its plates: a few sparks, a glint.
func _spark(hit: EnemyHit) -> void:
	var at: Vector2 = hit.world_position if hit.world_position != EnemyHit.NO_POSITION else _get_center()
	EmberEmitter.burst(get_parent(), at, 5, Vector2.UP, 160.0, 50.0)
	glint_remaining = 0.12
	FX.play_sfx(&"shell_spark")


## A big rock: the plates crack open into slate and ochre pebbles, and it's gone.
func _crack_open(push: Vector2) -> void:
	var center: Vector2 = _get_center()
	var direction: Vector2 = push.normalized() if push != Vector2.ZERO else Vector2.UP
	PebbleField.leave_colored_pebbles(get_tree(), center, 6, direction, PEBBLE_COLORS)
	FX.spawn_gravel(center, 6, Vector2.UP)
	FX.shake(2.0, 0.12)
	FX.freeze(0.05)
	defeat()


## The Pushable contract (gust): a GUST hit.
func receive_gust(direction: Vector2, strength: float) -> void:
	receive_hit(EnemyHit.make(EnemyHit.Type.GUST, direction * strength))


# --- Room ------------------------------------------------------------------------------

## Only the room the player is in is awake (like the other creatures). Not in a Room
## (a test scene): always awake.
func _is_awake() -> bool:
	return home_room == null or GameState.current_room == null or GameState.current_room == home_room


## Gone until the room resets: hidden, no collision.
func defeat() -> void:
	if state == State.DEFEATED:
		return
	state = State.DEFEATED
	velocity = Vector2.ZERO
	visible = false
	collision_layer = 0
	FX.play_sfx(&"shell_defeated")
	defeated.emit()


## Called by Room.reset_objects() (death or R) and on entering its room: back at its
## start, walking.
func reset() -> void:
	global_position = start_position
	velocity = Vector2.ZERO
	walk_direction = float(start_direction)
	state = State.WALK
	stagger_remaining = 0.0
	push_speed = 0.0
	shove_remaining = 0.0
	glint_remaining = 0.0
	visible = true
	collision_layer = 8 | 16
	queue_redraw()


## The room's left and right edges are walls for it, like for the monkey.
func _keep_inside_room() -> void:
	if home_room == null:
		return
	var bounds: Rect2 = home_room.get_bounds()
	var half_width: float = BODY_SIZE.x / 2.0
	if global_position.x - half_width < bounds.position.x:
		global_position.x = bounds.position.x + half_width
		walk_direction = 1.0
	elif global_position.x + half_width > bounds.end.x:
		global_position.x = bounds.end.x - half_width
		walk_direction = -1.0


func get_hitbox_global_rect() -> Rect2:
	return Rect2(global_position + Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y), BODY_SIZE)


func _get_center() -> Vector2:
	return global_position + Vector2(0.0, -BODY_SIZE.y / 2.0)


# --- Look --------------------------------------------------------------------------------

## Feet, then the dome, seams and head; mirrored to its facing and snapped to whole
## pixels (it moves in fractions of one). Staggered it jitters a pixel; a fireball
## glancing off makes the plates flash pale.
func _draw() -> void:
	var facing: float = float(start_direction) if Engine.is_editor_hint() else walk_direction
	var snap: Vector2 = global_position.round() - global_position
	var jitter: float = 0.0
	if not Engine.is_editor_hint() and state == State.STAGGER:
		jitter = 1.0 if int(stagger_remaining * 30.0) % 2 == 0 else -1.0
	draw_set_transform_matrix(Transform2D(0.0, Vector2(facing, 1.0), 0.0, snap + Vector2(jitter, 0.0)))
	var walking: bool = not Engine.is_editor_hint() and state == State.WALK
	for foot_index: int in FEET_X.size():
		var phase: float = stride_distance * 0.5 + (PI if foot_index % 2 == 1 else 0.0)
		var lift: float = 1.0 if walking and sin(phase) > 0.0 else 0.0
		draw_rect(Rect2(Vector2(FEET_X[foot_index], -FOOT_SIZE.y - lift), FOOT_SIZE), SLATE_DARK_COLOR)
	var glinting: bool = glint_remaining > 0.0
	for part: Array in BODY_RECTS:
		var color: Color = part[1]
		if glinting and color != EYE_COLOR:
			color = color.lerp(SPARK_COLOR, 0.6)
		draw_rect(part[0], color)
	draw_set_transform_matrix(Transform2D.IDENTITY)

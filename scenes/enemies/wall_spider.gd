@tool
class_name WallSpider
extends CharacterBody2D
## Wall spider: a wisp-like purple critter that CRAWLS round the outside of whatever
## it's on (floor, wall, ceiling, a platform's underside), never letting go. At an
## outer corner (an edge) it wraps round onto the next face; at an inner corner (a
## wall ahead) it climbs onto the wall. So on a floating platform it circles it
## forever. Touching it kills the player.
##
## It walks right over SPIKES: they're on the hazards layer, not the ground it holds,
## and they don't hurt it (its table ignores SPIKES).
##
## Place it next to any surface (the editor puts its 8x8 box in a tile): on its first
## frame it grabs the floor under it, or else the ceiling above, or a wall beside it.
## Nothing there: it falls until it lands on a floor, then crawls.
##
## crawl_direction: CLOCKWISE goes round a platform clockwise, which on a floor is
## walking RIGHT (on a ceiling, left). A room's left or right edge turns it back.
##
## How the crawl works (the classic "zoomer"): its body is a CRAWL_HALF*2 box around
## its origin. `surface_normal` points away from the surface it holds (UP on a floor),
## `move_direction` along it. It moves one whole pixel at a time and, at each, asks
## the physics world two questions with POINT queries against layer 1 ("world"):
##   - is there solid just ahead of the body?  -> inner corner: turn onto that wall
##       (new normal = -move, new move = old normal), don't move this pixel
##   - after the step, is there still solid under the body's back half?
##       no -> outer corner: wrap round it (step round the corner, new normal = old
##       move, new move = -old normal). Still nothing under it: it lost its grip (a
##       crate pushed away, a door opened): it falls.
## Probes sit half a pixel off tile lines so they never land exactly on an edge.
## Its position is kept on whole pixels so tile edges (multiples of 8) line up.
## The picture turns smoothly to the new surface and slides into place
## (draw_angle, draw_offset), while the logic snaps.
##
## Hits (EnemyHit, Stage F11 contract; table in _make_immunity): fire, big and
## perfect rocks, crushing, a reflected orb and the whip kill it. A GUST (or an earth
## push, a sloppy rock) knocks it OFF its surface: it flies, falls, and crawls on
## from wherever it lands (into a pit: defeated). A gust pushing it INTO its surface
## does nothing. It stays deadly while flying.
##
## Contracts: Pushable (group + receive_gust), Room.RESETTABLE_GROUP + reset(),
## EnemyHit (group "enemies" + receive_hit, `defeated` signal for EnemyGate),
## Flammable (ignite), SentryOrb.TARGET_GROUP, FireHazard.touches_fire.
##
## Physics: like the wisp, a CharacterBody2D on layer 4 ("pushable") and 5
## ("enemies") that collides with nothing (mask 0): it moves by setting its
## position. A child Area2D watches the player (layer 2).

enum State { CRAWL, AIRBORNE, DEFEATED }
enum CrawlDirection { COUNTER_CLOCKWISE = -1, CLOCKWISE = 1 }

## Emitted once when defeated (EnemyGate listens).
signal defeated

## Purple enemy body, darker legs, per the color key.
const BODY_COLOR: Color = Color(0.62, 0.3, 0.85)
const LEG_COLOR: Color = Color(0.32, 0.14, 0.45)
const EYE_COLOR: Color = Color(1.0, 0.85, 0.95)
## Half the crawl box: its body fills one 8 px tile.
const CRAWL_HALF: float = 4.0
## The hitbox for touching the player: a little smaller than the crawl box (fair).
const HITBOX_SIZE: Vector2 = Vector2(6, 6)
## How fast the picture turns to a new surface (radians/s) and slides into place
## after a corner (px/s).
const DRAW_TURN_SPEED: float = 14.0
const DRAW_SLIDE_SPEED: float = 40.0
## A pixel walk turns at most this many times in place (boxed in a one-tile hole).
const MAX_TURNS_IN_PLACE: int = 4

## Which way it goes round (see the header).
@export var crawl_direction: CrawlDirection = CrawlDirection.CLOCKWISE:
	set(value):
		crawl_direction = value
		queue_redraw()
## Crawling speed, px/s.
@export var crawl_speed: float = 28.0
## Gravity and top fall speed while knocked off, like the wisp.
@export var gravity: float = 900.0
@export var max_fall_speed: float = 300.0
## Upward pop added to a sideways gust (px/s), so it leaves the floor.
@export var knockback_hop_speed: float = 90.0
## What each kind of hit does to it. Empty = the table in _make_immunity().
@export var immunity: ElementImmunity

var state: State = State.CRAWL
## Away from the surface it holds (UP on a floor), and its way along it.
var surface_normal: Vector2 = Vector2.UP
var move_direction: Vector2 = Vector2.RIGHT
## +1 clockwise, -1 counter-clockwise; flipped at a room's side edge.
var turn_sign: float = 1.0
## Pixels of travel not yet taken (it moves whole pixels at a time).
var move_remainder: float = 0.0
## Airborne: fractional pixels not yet taken, per axis.
var fall_remainder: Vector2 = Vector2.ZERO
## False until its first frame has looked for a surface (the tiles' collision may
## not exist yet in _ready).
var has_found_surface: bool = false
var start_position: Vector2
var home_room: Room = null
## The picture: its angle (0 = standing on a floor) and its lag behind the logic
## position after a corner snap.
var draw_angle: float = 0.0
var draw_offset: Vector2 = Vector2.ZERO
var animation_time: float = 0.0

var contact_area: Area2D


func _ready() -> void:
	collision_layer = 8 | 16  # bit values of layer 4 "pushable" and layer 5 "enemies"
	collision_mask = 0        # moves itself; never collides
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = RectangleShape2D.new()
	(hitbox.shape as RectangleShape2D).size = HITBOX_SIZE
	add_child(hitbox)
	contact_area = Area2D.new()
	contact_area.collision_layer = 0
	contact_area.collision_mask = 2  # bit value of layer 2 "player"
	var contact_shape: CollisionShape2D = CollisionShape2D.new()
	contact_shape.shape = RectangleShape2D.new()
	(contact_shape.shape as RectangleShape2D).size = HITBOX_SIZE + Vector2(2.0, 2.0)
	contact_area.add_child(contact_shape)
	add_child(contact_area)
	if Engine.is_editor_hint():
		return
	start_position = global_position.round()
	if immunity == null:
		immunity = _make_immunity()
	add_to_group(EnemyHit.GROUP)
	add_to_group(Flammable.GROUP)
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(SentryOrb.TARGET_GROUP)
	home_room = Room.find_room_of(self)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or state == State.DEFEATED:
		return
	animation_time += delta
	if not has_found_surface:
		has_found_surface = true
		_grab_nearest_surface()
	match state:
		State.CRAWL:
			_crawl(delta)
		State.AIRBORNE:
			_fly(delta)
	if state == State.DEFEATED:
		return
	if home_room != null and global_position.y - CRAWL_HALF > home_room.get_bounds().end.y:
		defeat()  # fell out of the bottom of the room
		return
	_update_picture(delta)
	_check_contacts()
	queue_redraw()


# --- Crawling ---------------------------------------------------------------------

## First frame (and after a reset): hold the floor below, else the ceiling above,
## else a wall to the right or left. None: fall.
func _grab_nearest_surface() -> void:
	global_position = global_position.round()
	turn_sign = float(crawl_direction)
	for normal: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		if _is_solid(global_position - normal * (CRAWL_HALF + 0.5)):
			_hold_surface(normal)
			draw_angle = Vector2.UP.angle_to(normal)
			return
	state = State.AIRBORNE


## Starts crawling on the surface whose outward normal is `normal`; clockwise is
## the normal turned a quarter clockwise (on a floor, UP -> RIGHT).
func _hold_surface(normal: Vector2) -> void:
	state = State.CRAWL
	surface_normal = normal
	move_direction = normal.rotated(turn_sign * PI / 2.0).round()
	velocity = Vector2.ZERO
	move_remainder = 0.0


func _crawl(delta: float) -> void:
	move_remainder += crawl_speed * delta
	while move_remainder >= 1.0:
		move_remainder -= 1.0
		if not _crawl_one_pixel():
			# Lost its grip: falls from here (and lands on a floor).
			state = State.AIRBORNE
			velocity = Vector2.ZERO
			fall_remainder = Vector2.ZERO
			return


## One pixel along the surface, handling corners (see the header). False if it has
## nothing to hold any more.
func _crawl_one_pixel() -> bool:
	# A room's side edge: turn back instead of crawling into the next room.
	if home_room != null:
		var bounds: Rect2 = home_room.get_bounds()
		var next_x: float = global_position.x + move_direction.x
		if next_x - CRAWL_HALF < bounds.position.x or next_x + CRAWL_HALF > bounds.end.x:
			move_direction = -move_direction
			turn_sign = -turn_sign
			return true
	# Inner corner: something solid right ahead -> climb onto it (no step this pixel).
	var turns: int = 0
	while _is_solid(global_position + move_direction * (CRAWL_HALF + 0.5)):
		var old_normal: Vector2 = surface_normal
		surface_normal = -move_direction
		move_direction = old_normal
		turns += 1
		if turns >= MAX_TURNS_IN_PLACE:
			return true  # boxed in on every side: sit still
	if turns > 0:
		return true
	global_position += move_direction
	if _has_ground_under():
		return true
	# Outer corner: wrap round it. The step puts the body's center half a body past
	# the corner on the new face (worked out so the new ground probe lands inside
	# the corner's tile); the picture slides there instead of jumping.
	var old_move: Vector2 = move_direction
	var new_move: Vector2 = -surface_normal
	var corner_step: Vector2 = old_move * (CRAWL_HALF - 1.0) + new_move * (CRAWL_HALF + 1.0)
	global_position += corner_step
	draw_offset -= corner_step
	surface_normal = old_move
	move_direction = new_move
	return _has_ground_under()


## Solid under the body's back half (behind the middle, so it wraps once the middle
## is past the edge, not before).
func _has_ground_under() -> bool:
	return _is_solid(global_position - surface_normal * (CRAWL_HALF + 0.5) - move_direction * 0.5)


## A point query against layer 1 ("world": tiles, crates, doors, sentries...).
func _is_solid(world_point: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = world_point
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


# --- Knocked off -------------------------------------------------------------------

## Airborne: gravity, then whole-pixel steps per axis. A wall stops the sideways
## speed, a ceiling the upward speed, and a floor catches it: it crawls on there.
func _fly(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	fall_remainder += velocity * delta
	while absf(fall_remainder.x) >= 1.0:
		var step_x: float = signf(fall_remainder.x)
		fall_remainder.x -= step_x
		if _is_solid(global_position + Vector2(step_x * (CRAWL_HALF + 0.5), 0.0)):
			velocity.x = 0.0
			fall_remainder.x = 0.0
			break
		global_position.x += step_x
	while absf(fall_remainder.y) >= 1.0:
		var step_y: float = signf(fall_remainder.y)
		fall_remainder.y -= step_y
		if _is_solid(global_position + Vector2(0.0, step_y * (CRAWL_HALF + 0.5))):
			if step_y > 0.0:
				_hold_surface(Vector2.UP)  # landed on a floor
				return
			velocity.y = 0.0  # bumped a ceiling
			fall_remainder.y = 0.0
			break
		global_position.y += step_y


## Thrown off its surface at `push` (px/s). Pushing it into the surface it holds
## does nothing: it's pressed against it.
func _knock_off(push: Vector2) -> void:
	if state == State.CRAWL and push.normalized().dot(surface_normal) < -0.5:
		return
	state = State.AIRBORNE
	velocity = push
	# A sideways push also pops it up a little, so it leaves a floor (minf: up is -y).
	velocity.y = minf(velocity.y, -knockback_hop_speed)
	fall_remainder = Vector2.ZERO
	FX.shake(1.0, 0.08)


# --- Hits and contacts --------------------------------------------------------------

## Fire, big and perfect rocks, crushing, reflected orbs and the whip kill it; gusts,
## earth pushes and a sloppy small rock knock it off; spikes don't touch it.
static func _make_immunity() -> ElementImmunity:
	var kill: ElementImmunity.Response = ElementImmunity.Response.KILL
	var push: ElementImmunity.Response = ElementImmunity.Response.PUSH
	var ignore: ElementImmunity.Response = ElementImmunity.Response.IGNORE
	return ElementImmunity.from_table({
		EnemyHit.Type.FIREBALL: kill, EnemyHit.Type.FLAME: kill,
		EnemyHit.Type.BIG_ROCK: kill, EnemyHit.Type.PERFECT_ROCK: kill, EnemyHit.Type.SMALL_ROCK: push,
		EnemyHit.Type.GUST: push, EnemyHit.Type.EARTH_PUSH: push, EnemyHit.Type.CRUSH: kill,
		EnemyHit.Type.SPIKES: ignore, EnemyHit.Type.REFLECTED_ORB: kill, EnemyHit.Type.WHIP: kill,
	})


## The EnemyHit contract: every hit lands here.
func receive_hit(hit: EnemyHit) -> ElementImmunity.Response:
	if state == State.DEFEATED:
		return ElementImmunity.Response.IGNORE
	var response: ElementImmunity.Response = immunity.get_response(hit.type)
	match response:
		ElementImmunity.Response.KILL:
			if hit.type == EnemyHit.Type.FIREBALL or hit.type == EnemyHit.Type.FLAME:
				EmberEmitter.burst(get_parent(), global_position, 8, Vector2.UP, 180.0, 50.0)
				SmokePuff.spawn(get_parent(), global_position, 2)
			defeat()
		ElementImmunity.Response.PUSH, ElementImmunity.Response.STAGGER:
			_knock_off(hit.push_velocity)
	return response


## The Pushable contract: called by the gust. Becomes a GUST hit.
func receive_gust(direction: Vector2, strength: float) -> void:
	receive_hit(EnemyHit.make(EnemyHit.Type.GUST, direction * strength))


## The player (always deadly) and fire it crawls into.
func _check_contacts() -> void:
	var my_rect: Rect2 = get_hitbox_global_rect()
	if FireHazard.touches_fire(get_tree(), my_rect):
		receive_hit(EnemyHit.make(EnemyHit.Type.FLAME))
		if state == State.DEFEATED:
			return
	for body: Node2D in contact_area.get_overlapping_bodies():
		var touched_player: Player = body as Player
		if touched_player == null or touched_player.is_dead():
			continue
		# Overlap lists are a step old: confirm with the real rectangles.
		if my_rect.intersects(touched_player.get_hitbox_rect()):
			touched_player.die()
			return


# --- The Flammable contract: being lit is a FLAME hit --------------------------------

func ignite(source: Node) -> void:
	receive_hit(EnemyHit.make(EnemyHit.Type.FLAME, Vector2.ZERO, source))


func is_burning() -> bool:
	return false


func snuff() -> void:
	pass


func get_fire_rect() -> Rect2:
	return get_hitbox_global_rect()


# --- Defeat, reset, targets --------------------------------------------------------

func defeat() -> void:
	if state == State.DEFEATED:
		return
	state = State.DEFEATED
	visible = false
	collision_layer = 0
	_spawn_burst()
	FX.shake(2.0, 0.12)
	FX.play_sfx(&"wisp_defeated")
	defeated.emit()


## Called by Room.reset_objects(): back where it was placed, grabbing its surface
## again on the next frame.
func reset() -> void:
	global_position = start_position
	velocity = Vector2.ZERO
	draw_offset = Vector2.ZERO
	has_found_surface = false
	state = State.CRAWL
	visible = true
	collision_layer = 8 | 16


func get_orb_target_position() -> Vector2:
	return global_position


func is_valid_orb_target() -> bool:
	return state != State.DEFEATED


## The touch hitbox in world coordinates (centered on the origin).
func get_hitbox_global_rect() -> Rect2:
	return Rect2(global_position - HITBOX_SIZE / 2.0, HITBOX_SIZE)


## The editor's outline: the crawl box around the origin.
func get_local_outline() -> Rect2:
	return Rect2(-Vector2.ONE * CRAWL_HALF, Vector2.ONE * CRAWL_HALF * 2.0)


func _spawn_burst() -> void:
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 14
	burst.lifetime = 0.4
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 200.0)
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 90.0
	burst.color = BODY_COLOR
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.1, false).timeout.connect(burst.queue_free)


# --- Drawing -----------------------------------------------------------------------

## The picture catches up with the logic: turns toward the surface's angle and
## slides the corner snap away.
func _update_picture(delta: float) -> void:
	var target_angle: float = Vector2.UP.angle_to(surface_normal) if state == State.CRAWL else draw_angle
	draw_angle = rotate_toward(draw_angle, target_angle, DRAW_TURN_SPEED * delta)
	draw_offset = draw_offset.move_toward(Vector2.ZERO, DRAW_SLIDE_SPEED * delta)


## Drawn as if standing on a floor (feet at y = +CRAWL_HALF), then turned by
## draw_angle so its feet are on whatever it holds.
func _draw() -> void:
	draw_set_transform(draw_offset.round(), draw_angle)
	var front: float = float(crawl_direction) if Engine.is_editor_hint() or state != State.CRAWL else turn_sign
	# Four legs a side, stepping in turn while it crawls (two phases, like a gait).
	var step: float = sin(animation_time * crawl_speed * 0.5)
	for leg_index: int in 4:
		var phase: float = step if leg_index % 2 == 0 else -step
		var root_x: float = -1.5 + leg_index
		var knee: Vector2 = Vector2(root_x * 1.8, -1.5 - absf(phase))
		var foot: Vector2 = Vector2(root_x * 2.4 + phase, CRAWL_HALF)
		draw_line(Vector2(root_x, 0.0), knee, LEG_COLOR, 1.0)
		draw_line(knee, foot, LEG_COLOR, 1.0)
	# The body: a round abdomen and a smaller head at the front.
	draw_circle(Vector2(-front * 1.0, 0.5), 3.0, BODY_COLOR)
	draw_circle(Vector2(front * 2.5, 1.0), 2.0, BODY_COLOR)
	# Two eye pixels on the head.
	draw_rect(Rect2(Vector2(front * 2.5 - 0.5 + front, 0.0), Vector2.ONE), EYE_COLOR)
	draw_rect(Rect2(Vector2(front * 2.5 - 0.5, 0.0), Vector2.ONE), EYE_COLOR)
	draw_set_transform(Vector2.ZERO)

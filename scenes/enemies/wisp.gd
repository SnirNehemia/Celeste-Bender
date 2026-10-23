@tool
class_name Wisp
extends CharacterBody2D
## Wisp (GAME_DESIGN.md §7): a small purple enemy that patrols back and forth on a
## platform. Touching it kills the player.
##
## Place the node ON the floor, at the bottom-center of the wisp (origin at the feet,
## same as the player and the crate).
##
## It has three states:
##   PATROL   walks at patrol_speed, turns around at walls and at ledges. Deadly to touch.
##            On top of an Earth Column it does NOT turn at the edge: a pillar is no
##            patrol route, so it walks off and drops back to the ground.
##   STUNNED  knocked back by a gust (or the dash wake) and dizzy for stun_time.
##            HARMLESS to touch while stunned (it turns pale and wobbles), so going
##            for the dash finish never kills you by a frame. Doesn't turn at ledges,
##            so a gust can knock it off its platform.
##   DEFEATED gone (hidden, no collision) until the room resets.
##
## The impact rule (§7, no HP): the gust never damages it, only pushes. What it hits
## decides the outcome:
##   - slammed into a wall while flying fast  -> stunned longer (wall_slam_stun_time)
##   - knocked into spikes (or into a pit)    -> defeated
##   - a STUNNED wisp hit by a dashing player -> defeated (freeze frame + shake, and
##                                              with tuning.dash_defeat_refills the
##                                              player gets their dash back)
##   - hit by a thrown rock (Stage E6)        -> knocked back along the throw and
##                                              defeated a moment later (it flies,
##                                              harmless, then pops). Since E7 only a
##                                              BIG or PERFECTLY thrown rock kills; a
##                                              sloppy small one only shoves (stunned)
##
## It never leaves its ROOM (after Stage E7): the room's side edges count as walls,
## so it turns at a wall gap instead of walking into the next room, and a knockback
## stops there (_keep_inside_room).
## Earth moves that only PUSH it (a rising column's tip, the snake's head) throw it
## and stun it like a gust: the same "what it hits decides" rule then applies.
##   - FIRE (Stage F11) kills it: a fireball, the jet plume, burning grass and thicket,
##     bonfires, a burning crate or monkey. It doesn't avoid fire, so a grass fuse can
##     be timed to meet its patrol. It burns up in a puff of embers and smoke.
##
## Every hit goes through ONE path (Stage F11): receive_hit(EnemyHit) looks the hit up
## in `immunity` (ElementImmunity, see _make_immunity for the table) and calls
## _be_killed() or _be_pushed(). The gust (receive_gust), the column and snake
## (through Pushable), rocks, spikes, flames, reflected orbs and the dash all arrive
## there.
##
## It talks to other objects only through small, existing contracts:
##   - Pushable (group "pushable" + receive_gust): the gust and dash wake find it
##   - Room.RESETTABLE_GROUP + reset(): dying or R brings it back
##   - Player.die() / Player.is_dashing(): touching the player
##   - Spikes.get_hitbox_global_rect(): the same fair hitbox the player gets
##   - SentryOrb.TARGET_GROUP: a reflected orb aims at it and defeats it on hit
##   - EnemyHit (group "enemies" + receive_hit): every hit (Stage F11)
##   - Flammable (group "flammable" + ignite): flames that light what they touch
##     (plume, splash, bonfires) reach it with no special code
##   - FireHazard.touches_fire(): it walks into burning grass or a bonfire
##
## Physics layers: the body is on layer 4 ("pushable", so the gust's shape query
## sees it) and layer 5 ("enemies"), and collides only with layer 1 ("world"). The
## player is NOT in its mask, so the two never block each other; contact is found
## by a child Area2D (ContactArea) that watches the player (layer 2) and hazards
## (layer 3, spikes).

enum State { PATROL, STUNNED, DEFEATED }

## Emitted once when the wisp is defeated (by spikes, a pit, a dash or a reflected
## orb). EnemyGate listens to it to open "beat every enemy" doors.
signal defeated

## Purple, per the color key (GAME_DESIGN.md §2). Pale purple while stunned.
const BODY_COLOR: Color = Color(0.62, 0.3, 0.85)
const STUNNED_COLOR: Color = Color(0.82, 0.7, 0.92)
const EYE_COLOR: Color = Color(0.12, 0.05, 0.18)
## Little stars circling a stunned wisp's head.
const DIZZY_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)

## What each kind of hit does to it (Stage F11). Empty = the table in _make_immunity().
@export var immunity: ElementImmunity

## Body size, px. Smaller than a tile in height so it reads as a critter.
@export var body_size: Vector2 = Vector2(10, 8):
	set(value):
		body_size = value
		_resize_shapes()
		queue_redraw()
## Which way it starts walking: 1 = right, -1 = left.
@export_enum("Left:-1", "Right:1") var start_direction: int = 1
## Walking speed, px/s. Slow: the player has time to read its route.
@export var patrol_speed: float = 30.0
## Same gravity and max fall speed as the player and crate, so knockbacks arc the
## way you'd expect.
@export var gravity: float = 900.0
@export var max_fall_speed: float = 300.0
## How fast a knocked-back wisp slows down on the ground / in the air, px/s².
## Ground: 160² / (2 × 320) = 40 px slide from a gust, like a crate.
@export var ground_friction: float = 320.0
@export var air_friction: float = 60.0
## A sideways gust also pops it slightly off the ground (px/s, upward), so it flies
## a little instead of only sliding: easier to knock off a platform edge.
@export var knockback_hop_speed: float = 90.0
## Fraction of the gust's push turned into upward speed when gusted from below.
@export var upward_push_multiplier: float = 0.8
## Seconds stunned after a gust.
@export var stun_time: float = 1.5
## Seconds stunned after being slammed into a wall (counted from the slam).
@export var wall_slam_stun_time: float = 2.5
## Hitting a wall slower than this (px/s) doesn't count as a slam.
@export var wall_slam_min_speed: float = 60.0
## If it falls this far below where it was placed (a pit), it's defeated.
@export var fall_out_distance: float = 200.0

var state: State = State.PATROL
## 1 = walking right, -1 = walking left.
var patrol_direction: float = 1.0
var stun_time_remaining: float = 0.0
## True once this knockback has already slammed into a wall (one slam per knockback).
var has_slammed_this_knockback: bool = false
## Hit by a thrown rock: seconds until it pops (defeated). Negative = not hit.
var rock_defeat_remaining: float = -1.0
## The room we belong to (the nearest Room above us), found in _ready(); null in a
## scene with no rooms.
var home_room: Room = null
## Where it was placed, in world coordinates. reset() puts it back here.
var start_position: Vector2
## Seconds since start; drives the bob and dizzy-stars animations.
var animation_time: float = 0.0

var hitbox: CollisionShape2D
var contact_area: Area2D
var contact_shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 8 | 16  # bit values of layer 4 "pushable" and layer 5 "enemies"
	collision_mask = 1        # stands on and bumps into "world" only
	hitbox = CollisionShape2D.new()
	hitbox.shape = RectangleShape2D.new()
	add_child(hitbox)

	# A separate sensor for "what am I touching": the player and spikes. An Area2D
	# only detects; it never pushes anything.
	contact_area = Area2D.new()
	contact_area.collision_layer = 0
	contact_area.collision_mask = 2 | 4  # bit values of layer 2 "player" and layer 3 "hazards"
	contact_shape = CollisionShape2D.new()
	contact_shape.shape = RectangleShape2D.new()
	contact_area.add_child(contact_shape)
	add_child(contact_area)
	_resize_shapes()

	if Engine.is_editor_hint():
		return
	start_position = global_position
	patrol_direction = float(start_direction)
	if immunity == null:
		immunity = _make_immunity()
	add_to_group(EnemyHit.GROUP)
	add_to_group(Flammable.GROUP)
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(SentryOrb.TARGET_GROUP)
	home_room = Room.find_room_of(self)


func _physics_process(delta: float) -> void:
	animation_time += delta
	if Engine.is_editor_hint() or state == State.DEFEATED:
		return

	if rock_defeat_remaining >= 0.0:
		rock_defeat_remaining -= delta
		if rock_defeat_remaining <= 0.0:
			defeat()
			return
	match state:
		State.PATROL:
			_patrol(delta)
		State.STUNNED:
			_be_stunned(delta)

	_keep_inside_room()
	if global_position.y > start_position.y + fall_out_distance:
		defeat()
		return
	_check_contacts()
	queue_redraw()  # it animates (bob, wobble, stars), so redraw every frame


func _patrol(delta: float) -> void:
	_apply_gravity(delta)
	# Turn BEFORE stepping off a ledge, so it never walks off by itself (except off
	# a pillar, see the header).
	if is_on_floor() and not _has_floor_ahead() and not _is_standing_on_column():
		patrol_direction = -patrol_direction
	velocity.x = patrol_direction * patrol_speed
	move_and_slide()
	# is_on_wall() is refreshed by the move_and_slide() just above.
	if is_on_wall():
		patrol_direction = -patrol_direction


func _be_stunned(delta: float) -> void:
	_apply_gravity(delta)
	var friction: float = ground_friction if is_on_floor() else air_friction
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	# Remember the speed BEFORE moving: move_and_slide() zeroes the part of
	# velocity that runs into a wall, so afterwards we couldn't tell a slam from a bump.
	var speed_before_move: float = absf(velocity.x)
	move_and_slide()
	if is_on_wall() and speed_before_move >= wall_slam_min_speed and not has_slammed_this_knockback:
		has_slammed_this_knockback = true
		stun_time_remaining = maxf(stun_time_remaining, wall_slam_stun_time)
		FX.shake(1.5, 0.1)

	stun_time_remaining -= delta
	# Only wake up once landed, so it doesn't start "walking" in mid-air.
	if stun_time_remaining <= 0.0 and is_on_floor():
		state = State.PATROL


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


## True if the floor under us is an Earth Column. move_and_slide() keeps every
## contact it made as a "slide collision"; the floor is the one facing up.
func _is_standing_on_column() -> bool:
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision.get_normal().y < -0.7 and collision.get_collider() is EarthColumn:
			return true
	return false


## Is there ground just past our front edge? A ray from slightly above the feet,
## 1 px beyond the front, pointing down 4 px. Asks the physics world directly
## (the same "direct space state" the gust uses).
func _has_floor_ahead() -> bool:
	var front_x: float = global_position.x + patrol_direction * (body_size.x / 2.0 + 1.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(front_x, global_position.y - 2.0), Vector2(front_x, global_position.y + 4.0), 1)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## The wisp's row of the §7.2 table: fire, big and perfect rocks, spikes, crushing,
## reflected orbs, a dash (while stunned) and the elephant's tail whip kill it; gusts, earth pushes and a
## sloppy small rock push it.
static func _make_immunity() -> ElementImmunity:
	var kill: ElementImmunity.Response = ElementImmunity.Response.KILL
	var push: ElementImmunity.Response = ElementImmunity.Response.PUSH
	return ElementImmunity.from_table({
		EnemyHit.Type.FIREBALL: kill, EnemyHit.Type.FLAME: kill,
		EnemyHit.Type.BIG_ROCK: kill, EnemyHit.Type.PERFECT_ROCK: kill, EnemyHit.Type.SMALL_ROCK: push,
		EnemyHit.Type.GUST: push, EnemyHit.Type.EARTH_PUSH: push, EnemyHit.Type.CRUSH: kill,
		EnemyHit.Type.SPIKES: kill, EnemyHit.Type.REFLECTED_ORB: kill, EnemyHit.Type.DASH: kill,
		EnemyHit.Type.WHIP: kill,
	})


## Touching the player, spikes or fire. Checked every frame (like spikes do), not only
## on "entered", because what touching means changes with our state.
func _check_contacts() -> void:
	var my_rect: Rect2 = get_hitbox_global_rect()
	# Spikes: the same fair hitbox the player gets. Area-to-area overlaps come from
	# get_overlapping_areas(); spikes are Area2Ds on layer 3.
	for area: Area2D in contact_area.get_overlapping_areas():
		var spikes: Spikes = area as Spikes
		if spikes != null and spikes.get_hitbox_global_rect().intersects(my_rect):
			receive_hit(EnemyHit.make(EnemyHit.Type.SPIKES))
			if state == State.DEFEATED:
				return
	# Fire it walked into (burning grass, a bonfire, a burning crate or monkey).
	if FireHazard.touches_fire(get_tree(), my_rect):
		receive_hit(EnemyHit.make(EnemyHit.Type.FLAME))
		if state == State.DEFEATED:
			return

	for body: Node2D in contact_area.get_overlapping_bodies():
		var touched_player: Player = body as Player
		if touched_player == null or touched_player.is_dead():
			continue
		# Overlap lists are refreshed once per physics step; confirm with the real
		# rectangles at their current positions (same reason as in spikes.gd).
		if not my_rect.intersects(touched_player.get_hitbox_rect()):
			continue
		if state == State.STUNNED:
			if touched_player.is_dashing():
				receive_hit(EnemyHit.make(EnemyHit.Type.DASH, Vector2.ZERO, touched_player))
			# A stunned wisp that isn't dashed is harmless: nothing happens.
		else:
			touched_player.die()
		return


## The Pushable contract: called by the gust and the dash wake. Becomes a GUST hit.
func receive_gust(direction: Vector2, strength: float) -> void:
	receive_hit(EnemyHit.make(EnemyHit.Type.GUST, direction * strength))


## The EnemyHit contract (Stage F11): every hit lands here. The table says what it
## does; _be_killed / _be_pushed say how. Returns the table's answer (IGNORE once
## defeated, or while a rock hit is already about to pop it).
func receive_hit(hit: EnemyHit) -> ElementImmunity.Response:
	if state == State.DEFEATED or rock_defeat_remaining >= 0.0:
		return ElementImmunity.Response.IGNORE
	var response: ElementImmunity.Response = immunity.get_response(hit.type)
	match response:
		ElementImmunity.Response.KILL:
			_be_killed(hit)
		ElementImmunity.Response.PUSH, ElementImmunity.Response.STAGGER:
			_be_pushed(hit)
	return response


## How a killing hit kills it.
func _be_killed(hit: EnemyHit) -> void:
	match hit.type:
		EnemyHit.Type.BIG_ROCK, EnemyHit.Type.PERFECT_ROCK, EnemyHit.Type.SMALL_ROCK:
			# A thrown rock (Stage E6): knocked back along the throw (stunned, so
			# harmless while it flies), popped kill_delay seconds later.
			_knock_back(hit.push_velocity)
			if hit.kill_delay <= 0.0:
				defeat()
				return
			rock_defeat_remaining = hit.kill_delay
			FX.shake(1.5, 0.1)
		EnemyHit.Type.DASH:
			_defeat_by_dash(hit.source as Player)
		EnemyHit.Type.FIREBALL, EnemyHit.Type.FLAME:
			_burn_up()
		_:
			defeat()


## How a pushing hit moves it: always thrown and stunned (the "what it hits decides"
## rule then applies); the details depend on what pushed.
func _be_pushed(hit: EnemyHit) -> void:
	match hit.type:
		EnemyHit.Type.GUST:
			_be_gusted(hit.push_velocity.normalized(), hit.push_velocity.length())
		EnemyHit.Type.BIG_ROCK, EnemyHit.Type.PERFECT_ROCK, EnemyHit.Type.SMALL_ROCK:
			_knock_back(hit.push_velocity)
			FX.shake(1.0, 0.08)  # shoved: a bump, it lives
		_:
			# A column's tip or the snake's head: exactly that velocity.
			_launch(hit.push_velocity)


## Knocked back by the gust: the way the air blows, plus a hop. Same shape as
## Crate.receive_gust.
func _be_gusted(direction: Vector2, strength: float) -> void:
	velocity.x = direction.x * strength
	if direction.y > 0.1:
		# Gusted from above: slam it down (only matters in the air).
		velocity.y = maxf(velocity.y, direction.y * strength)
	else:
		# minf because "up" is negative y: keep whichever upward speed is bigger.
		var upward_speed: float = maxf(-direction.y * strength * upward_push_multiplier, knockback_hop_speed)
		velocity.y = minf(velocity.y, -upward_speed)
	state = State.STUNNED
	stun_time_remaining = maxf(stun_time_remaining, stun_time)
	has_slammed_this_knockback = false


## Thrown at exactly `launch_velocity` and stunned (a rising Earth Column, Stage E3:
## thrown into spikes or a pit, it's defeated by the usual rules).
func _launch(launch_velocity: Vector2) -> void:
	velocity = launch_velocity
	state = State.STUNNED
	stun_time_remaining = maxf(stun_time_remaining, stun_time)
	has_slammed_this_knockback = false


## A rock's knockback: thrown along it, with a small hop up as well (like a gust),
## so a sideways hit lifts it off the floor instead of skidding it.
func _knock_back(knockback_velocity: Vector2) -> void:
	_launch(knockback_velocity)
	# minf because "up" is negative y.
	velocity.y = minf(velocity.y, -knockback_hop_speed)


## Caught fire: it doesn't burn for a while, it flares and is gone (embers and smoke
## along with the purple puff).
func _burn_up() -> void:
	var center: Vector2 = global_position + Vector2(0.0, -body_size.y / 2.0)
	EmberEmitter.burst(get_parent(), center, 10, Vector2.UP, 180.0, 50.0)
	SmokePuff.spawn(get_parent(), center, 3)
	defeat()


# --- The Flammable contract (Stage F11) ---------------------------------------------
# Flames that light what they touch (the jet plume, a fireball's splash, bonfires,
# burning crates and monkeys) find the wisp in the "flammable" group: being lit is a
# FLAME hit.

func ignite(source: Node) -> void:
	receive_hit(EnemyHit.make(EnemyHit.Type.FLAME, Vector2.ZERO, source))


## It never burns for a while: it's gone at once.
func is_burning() -> bool:
	return false


func snuff() -> void:
	pass


func get_fire_rect() -> Rect2:
	return get_hitbox_global_rect()


## Gone until the room resets: hidden, no collision (so gusts ignore it). The
## contact sensor stays on, but _physics_process skips everything while DEFEATED.
func defeat() -> void:
	if state == State.DEFEATED:
		return
	state = State.DEFEATED
	rock_defeat_remaining = -1.0
	velocity = Vector2.ZERO
	visible = false
	collision_layer = 0
	_spawn_burst()
	FX.shake(2.0, 0.12)
	FX.play_sfx(&"wisp_defeated")
	defeated.emit()


## The room's left and right edges act as walls: if our body pokes past one, it's
## put back, turned around (patrolling) and stopped sideways (knocked back).
func _keep_inside_room() -> void:
	if home_room == null:
		return
	var bounds: Rect2 = home_room.get_bounds()
	var half_width: float = body_size.x / 2.0
	var push_back: float = 0.0
	if global_position.x - half_width < bounds.position.x:
		push_back = bounds.position.x - (global_position.x - half_width)
	elif global_position.x + half_width > bounds.end.x:
		push_back = bounds.end.x - (global_position.x + half_width)
	if push_back == 0.0:
		return
	global_position.x += push_back
	# push_back > 0 = we were past the LEFT edge: from now on head right, and back.
	patrol_direction = signf(push_back)
	velocity.x = 0.0


## SentryOrb aim assist: where a reflected orb should fly to hit us.
func get_orb_target_position() -> Vector2:
	return global_position + Vector2(0.0, -body_size.y / 2.0)


## SentryOrb aim assist: can a reflected orb still hit us?
func is_valid_orb_target() -> bool:
	return state != State.DEFEATED


## Dashed into while stunned: a crunchy hit (freeze frame, §9) and, optionally, the
## dash comes back so you can keep moving (Celeste-style).
func _defeat_by_dash(dashing_player: Player) -> void:
	defeat()
	FX.freeze(0.06)
	if dashing_player.tuning.dash_defeat_refills:
		dashing_player.refill_from_crystal()


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	global_position = start_position
	velocity = Vector2.ZERO
	patrol_direction = float(start_direction)
	stun_time_remaining = 0.0
	rock_defeat_remaining = -1.0
	state = State.PATROL
	visible = true
	collision_layer = 8 | 16


## The body's rectangle in world coordinates.
func get_hitbox_global_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x / 2.0, -body_size.y), body_size)


func _resize_shapes() -> void:
	if hitbox == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	# Origin is at the bottom-center, and a shape is positioned by its center.
	(hitbox.shape as RectangleShape2D).size = body_size
	hitbox.position = Vector2(0.0, -body_size.y / 2.0)
	# The contact sensor is 1 px bigger on each side than the body, so it notices
	# spikes it's resting right next to (the body itself never overlaps a solid).
	(contact_shape.shape as RectangleShape2D).size = body_size + Vector2(2.0, 2.0)
	contact_shape.position = hitbox.position


## A puff of purple squares where it was, added to the room (we're about to hide).
func _spawn_burst() -> void:
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 16
	burst.lifetime = 0.4
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 200.0)
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 90.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	burst.color = BODY_COLOR
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector2(0.0, -body_size.y / 2.0)
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.1, false).timeout.connect(burst.queue_free)


func _draw() -> void:
	var is_stunned: bool = state == State.STUNNED
	# Patrolling: a gentle 1 px bob (it's a wisp). Stunned: a sideways wobble.
	var offset: Vector2 = Vector2.ZERO
	if is_stunned:
		offset.x = roundf(sin(animation_time * 30.0))
	else:
		offset.y = -roundf((sin(animation_time * 5.0) + 1.0) * 0.5)
	var box: Rect2 = Rect2(Vector2(-body_size.x / 2.0, -body_size.y) + offset, body_size)
	draw_rect(box, STUNNED_COLOR if is_stunned else BODY_COLOR)

	# Two eye pixels near the front, so you can see which way it walks.
	var eye_y: float = box.position.y + 2.0
	var front_x: float = box.get_center().x + patrol_direction * 2.0
	if is_stunned:
		# "x x" eyes: two short crosses read as dizzy.
		for eye_x: float in [front_x - 2.0, front_x + 1.0]:
			draw_line(Vector2(eye_x, eye_y), Vector2(eye_x + 1.0, eye_y + 1.0), EYE_COLOR, 1.0)
			draw_line(Vector2(eye_x + 1.0, eye_y), Vector2(eye_x, eye_y + 1.0), EYE_COLOR, 1.0)
		# Three stars circling above its head.
		var head_center: Vector2 = Vector2(box.get_center().x, box.position.y - 3.0)
		for star_index: int in 3:
			var angle: float = animation_time * 6.0 + TAU * star_index / 3.0
			var star: Vector2 = head_center + Vector2(cos(angle) * 5.0, sin(angle) * 1.5)
			draw_rect(Rect2(star.round(), Vector2.ONE), DIZZY_COLOR)
	else:
		draw_rect(Rect2(Vector2(front_x - 2.0, eye_y), Vector2(1, 2)), EYE_COLOR)
		draw_rect(Rect2(Vector2(front_x + 1.0, eye_y), Vector2(1, 2)), EYE_COLOR)

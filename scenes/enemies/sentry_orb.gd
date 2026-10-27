class_name SentryOrb
extends Area2D
## The Sentry's projectile (GAME_DESIGN.md §7): a slow orange orb that flies in a
## straight line. Never placed by hand: Sentry._fire() instances it and calls launch().
##
##   - hits the player       -> the player dies (unless it's been reflected)
##   - hit by a gust         -> REFLECTED: turns pale gold, flies 1.5x faster, and can't
##                              hurt the player any more. Aim assist: if an enemy
##                              (any member of TARGET_GROUP, e.g. the sentry that fired
##                              it, another sentry, a wisp) is within
##                              reflect_assist_degrees of the gust's direction and in
##                              clear view, it flies straight at the closest-angle one;
##                              otherwise along the gust.
##   - reflected, hits an enemy -> a REFLECTED_ORB hit (EnemyHit, Stage F11): its
##                              table decides (a sentry or wisp is destroyed); an
##                              enemy that ignores orbs (the vine monkey) lets it by
##   - hits anything solid   -> BOUNCES (Stage F12): walls, floors, crates, doors,
##                              rocks, mirrored off the surface (Ricochet), up to
##                              max_bounces times, then pops on the next one.
##                              Another sentry still pops it. Unreflected orbs fly
##                              past walking enemies.
##   - hits the Shell         -> bounces off its plates, reflected or not (group
##                              EnemyHit.REFLECTS_GROUP)
##   - meets a fireball      -> both burst (Stage F11, the fireball pops it)
##   - touches any WATER      -> SOAKED (after W3 play-test 3): a pool, loose drops
##                              or the ball in the player's hands
##                              (WaterWorld.is_water_near). It keeps
##                              orb_soaked_speed_keep of its speed and from then on
##                              falls (orb_soaked_gravity); inside water it sinks
##                              slowly (orb_sink_gravity, orb_water_drag). Soaked,
##                              it doesn't bounce: the next solid pops it. It still
##                              kills. Values in WaterTuning ("Water and projectiles")
##   - after max_lifetime     -> pops
##   - leaves its room         -> pops (after Stage E7: orbs never fly into the next room)
##
## Enemies opt in as reflection targets by joining TARGET_GROUP and having:
##     func get_orb_target_position() -> Vector2   (where to aim, world space)
##     func is_valid_orb_target() -> bool          (false once defeated)
##
## Contracts: Pushable (group "pushable" + receive_gust / receive_gust_from), so the
## gust reflects it with no special code in the gust. Room
## RESETTABLE_GROUP + reset(): a room reset removes orbs in flight.
##
## Physics: an Area2D (detects, never blocks) on layer 4 ("pushable", so the gust
## finds it) and layer 5 ("enemies", Stage F11: so a fireball, which looks at
## enemies, meets it), looking at layers 1 ("world", includes sentries), 2 ("player")
## and 5 ("enemies", wisps and monkeys).
## It moves itself by script; no physics body needed for a straight line.

## Group of things a reflected orb can aim at (see the header).
const TARGET_GROUP: StringName = &"orb_target"
## Orange, per the color key (GAME_DESIGN.md §2). Reflected: pale gold, "yours now".
const ORB_COLOR: Color = Color(1.0, 0.55, 0.1)
const ORB_CORE_COLOR: Color = Color(1.0, 0.85, 0.5)
const REFLECTED_COLOR: Color = Color(1.0, 0.9, 0.55)
const REFLECTED_CORE_COLOR: Color = Color(1.0, 1.0, 1.0)
## Mixed into the colors once it's soaked by water.
const SOAKED_TINT: Color = Color("#7FC8FF")
## Drawn radius, px. The hitbox is smaller (fair, like the spikes).
const DRAW_RADIUS: float = 3.0
const HITBOX_RADIUS: float = 2.0

## Reflected orbs fly this much faster.
@export var reflected_speed_multiplier: float = 1.5
## Aim assist cone around the gust's direction, degrees either side.
@export var reflect_assist_degrees: float = 45.0
## Seconds before it pops by itself (also restarted when reflected).
@export var max_lifetime: float = 8.0
## Bounces off walls, floors and the Shell before the next solid pops it (Stage F12).
@export var max_bounces: int = 3

var velocity: Vector2 = Vector2.ZERO
var is_reflected: bool = false
## The sentry that fired it. Its own shot doesn't hit it until reflected.
var shooter: Sentry = null
var lifetime_remaining: float = 0.0
## Set once it pops, so it can't hit two things in the same frame.
var is_popped: bool = false
var bounce_count: int = 0
var hit_shape: CircleShape2D
## Soaked by water (see the header): falls from then on, and pops on any solid.
var is_soaked: bool = false
## The room's water, looked up on the first frame (null: a room without water).
var water_world: WaterWorld = null
var has_looked_for_water: bool = false


func _ready() -> void:
	collision_layer = 8 | 16  # bit values of layer 4 "pushable" and layer 5 "enemies"
	collision_mask = 1 | 2 | 16  # bit values of layers 1 "world", 2 "player", 5 "enemies"
	hit_shape = CircleShape2D.new()
	hit_shape.radius = HITBOX_RADIUS
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = hit_shape
	add_child(hitbox)
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)


## Starts the orb at `world_position`, moving at `start_velocity` (px/s).
func launch(world_position: Vector2, start_velocity: Vector2, fired_by: Sentry) -> void:
	global_position = world_position
	velocity = start_velocity
	shooter = fired_by
	lifetime_remaining = max_lifetime


func _physics_process(delta: float) -> void:
	if is_popped:
		return
	var previous_position: Vector2 = global_position
	_update_water(delta)
	global_position += velocity * delta
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0 or not _is_inside_room():
		pop()
		return
	_check_hits(previous_position)
	queue_redraw()


## Water (after W3 play-test 3): the first touch of any water soaks the orb (it
## slows right down); soaked, it falls, and inside water it sinks slowly.
func _update_water(delta: float) -> void:
	if not has_looked_for_water:
		has_looked_for_water = true
		water_world = WaterWorld.find_at(get_tree(), global_position)
	if water_world == null:
		return
	var tuning: WaterTuning = water_world.water_tuning
	var in_water: bool = water_world.is_water_near(global_position, HITBOX_RADIUS)
	if in_water and not is_soaked:
		is_soaked = true
		velocity *= tuning.orb_soaked_speed_keep
		water_world.sparkle(water_world.to_local(global_position), 5)
		queue_redraw()
	if not is_soaked:
		return
	if in_water:
		# Held up by the water and braked by it, like a crate (velocity *= 1 - drag dt).
		velocity *= maxf(0.0, 1.0 - tuning.orb_water_drag * delta)
		velocity.y += tuning.orb_sink_gravity * delta
	else:
		velocity.y += tuning.orb_soaked_gravity * delta


## What are we touching? Polled every frame instead of using the body_entered signal,
## so an orb reflected while still inside its sentry (you gusted point-blank) still
## counts as hitting it.
## `previous_position`: where it was before this frame's move (to find a bounce's angle).
func _check_hits(previous_position: Vector2) -> void:
	for body: Node2D in get_overlapping_bodies():
		var touched_player: Player = body as Player
		if touched_player != null:
			if not is_reflected and not touched_player.is_dead():
				touched_player.die()
				pop()
				return
			continue  # reflected orbs pass harmlessly through the player
		var enemy: Node = EnemyHit.find_enemy(body)
		if enemy != null and enemy.is_in_group(EnemyHit.REFLECTS_GROUP):
			# Armor (the Shell): it glances off, reflected or not.
			if not _try_bounce(body, previous_position):
				pop()
			return
		if enemy != null:
			if is_reflected:
				var response: ElementImmunity.Response = EnemyHit.send(enemy, EnemyHit.Type.REFLECTED_ORB,
					velocity, self)
				if response == ElementImmunity.Response.IGNORE:
					continue  # an enemy that shrugs orbs off: fly on
				if not enemy is Sentry:
					FX.freeze(0.04)  # a sentry's own destroy() freezes already
				pop()
				return
			# Unreflected: the sentry's shots fly past walking enemies and out of their
			# own sentry; another sentry is solid (it falls through to pop below).
			if enemy is CharacterBody2D or enemy == shooter:
				continue
		# Anything else on layer 1 is solid: walls, floors, crates, doors and rocks
		# bounce it (Stage F12); another sentry pops it.
		if enemy != null or not _try_bounce(body, previous_position):
			pop()
		return


## Mirrors the flight off `body`'s surface (Ricochet: the move from
## `previous_position` swept against it gives the angle) and steps back out of it.
## False once max_bounces is used up (or soaked: a wet orb doesn't bounce): it pops.
func _try_bounce(body: Node2D, previous_position: Vector2) -> bool:
	if bounce_count >= max_bounces or is_soaked:
		return false
	var exclude: Array[RID] = []
	if shooter != null and is_instance_valid(shooter):
		exclude.append(shooter.get_rid())
	var contact: Dictionary = Ricochet.find_contact(get_world_2d().direct_space_state, hit_shape,
		previous_position, global_position - previous_position, 1 | 16, exclude)
	var normal: Vector2 = -velocity.normalized()
	if not contact.is_empty() and contact["collider"] == body:
		normal = contact["normal"]
		global_position = contact["safe_position"]
	else:
		global_position = previous_position
	velocity = Ricochet.bounce(velocity, normal)
	bounce_count += 1
	FX.play_sfx(&"orb_bounce")
	return true


## True while we're inside the room we were fired into (our parent). Not a Room
## (a test scene): always true.
func _is_inside_room() -> bool:
	var room: Room = get_parent() as Room
	return room == null or room.get_bounds().has_point(global_position)


## The Pushable contract (simple form). We prefer the version with a source.
func receive_gust(direction: Vector2, strength: float) -> void:
	receive_gust_from(direction, strength, Pushable.NO_SOURCE)


## The Pushable contract: a gust hit us. Reflect.
func receive_gust_from(direction: Vector2, _strength: float, _source_position: Vector2) -> void:
	if is_popped:
		return
	var new_direction: Vector2 = _find_assisted_direction(direction)
	# Keep the original launch speed, not the gust's push strength: reflect, then speed up.
	var base_speed: float = velocity.length() / (reflected_speed_multiplier if is_reflected else 1.0)
	velocity = new_direction * base_speed * reflected_speed_multiplier
	is_reflected = true
	lifetime_remaining = max_lifetime
	FX.shake(1.0, 0.08)
	FX.play_sfx(&"orb_reflected")


## Aim assist: of every target within reflect_assist_degrees of `gust_direction`
## that the orb can see, the one closest to the gust's line wins, and the orb flies
## straight at it. No target in the cone: the orb just follows the gust.
## 8-direction aiming is coarse; this keeps reflecting about choosing a target,
## not about pixel-perfect angles.
func _find_assisted_direction(gust_direction: Vector2) -> Vector2:
	var best_direction: Vector2 = gust_direction
	var best_angle: float = deg_to_rad(reflect_assist_degrees)
	# Our parent is the room the sentry fired us into: only aim at enemies in it.
	var room: Node = get_parent()
	for target: Node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not room.is_ancestor_of(target) or not target.call(&"is_valid_orb_target"):
			continue
		var target_position: Vector2 = target.call(&"get_orb_target_position")
		var to_target: Vector2 = (target_position - global_position).normalized()
		var angle: float = absf(gust_direction.angle_to(to_target))
		if angle <= best_angle and _has_clear_path_to(target, target_position):
			best_angle = angle
			best_direction = to_target
	return best_direction


## True if nothing solid (layer 1) is between us and the target. The target itself
## is excluded (a sentry is on layer 1 too).
func _has_clear_path_to(target: Node, target_position: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, target_position, 1)
	var target_body: CollisionObject2D = target as CollisionObject2D
	if target_body != null:
		query.exclude = [target_body.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Bursts into a few sparks and frees itself.
func pop() -> void:
	if is_popped:
		return
	is_popped = true
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 8
	sparks.lifetime = 0.25
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 30.0
	sparks.initial_velocity_max = 60.0
	sparks.color = REFLECTED_COLOR if is_reflected else ORB_COLOR
	get_parent().add_child(sparks)
	sparks.global_position = global_position
	sparks.emitting = true
	get_tree().create_timer(sparks.lifetime + 0.1, false).timeout.connect(sparks.queue_free)
	queue_free()


## Called by Room.reset_objects(): orbs in flight just disappear.
func reset() -> void:
	is_popped = true
	queue_free()


func _draw() -> void:
	var outer: Color = REFLECTED_COLOR if is_reflected else ORB_COLOR
	var core: Color = REFLECTED_CORE_COLOR if is_reflected else ORB_CORE_COLOR
	if is_soaked:
		# Doused: duller, with a blue sheen (still orange enough to read as danger).
		outer = outer.lerp(SOAKED_TINT, 0.4)
		core = core.lerp(SOAKED_TINT, 0.5)
	draw_circle(Vector2.ZERO, DRAW_RADIUS, outer)
	draw_circle(Vector2.ZERO, 1.5, core)

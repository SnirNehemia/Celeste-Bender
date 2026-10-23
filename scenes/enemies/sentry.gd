@tool
class_name Sentry
extends StaticBody2D
## Sentry (GAME_DESIGN.md §7): a stationary purple turret. While it can see the
## player it fires a slow orange orb (SentryOrb) at them every fire_interval seconds.
## The gust reflects orbs; a reflected orb that hits the sentry destroys it. So does
## a thrown big or perfect rock (Stage E6) and a fireball (Stage F11). It's metal: the
## jet plume and burning grass do nothing to it.
##
## Every hit arrives through receive_hit (the EnemyHit contract, Stage F11), looked
## up in `immunity` (the table is in _make_immunity).
##
## Place the node ON the floor (or a ledge), at the bottom-center of the turret.
## With mounted_on_ceiling, place it on the CEILING instead (top-center): it hangs
## down and watches the floor below.
## With can_fire off it never shoots: a passive TARGET for reflection practice.
##
## Firing rhythm, fair and readable:
##   - it only counts down while the player is in the same room, within
##     sight_range, and in line of sight (a ray to the player not blocked by
##     anything on layer 1: walls, crates, doors)
##   - the first shot comes first_shot_delay after it spots you, not instantly
##   - for the last telegraph_time before each shot its eye glows orange, so you
##     can time your gust
##
## Physics: a solid StaticBody2D on layer 1 ("world") so you can stand on it and it
## blocks crates, plus layer 5 ("enemies"). It is NOT Pushable: the gust doesn't
## move it; only its own reflected orb can hurt it.
##
## Contracts: Room.RESETTABLE_GROUP + reset() (a destroyed sentry comes back when
## the room resets). EnemyHit (group "enemies" + receive_hit). SentryOrb.TARGET_GROUP + get_orb_target_position(): reflected
## orbs aim at it. It finds the player through the "player" group
## (Player.GROUP), so it needs no NodePath to set up.

## Purple (enemy), per the color key. Its eye blends to orange (projectile) as it charges.
const BODY_COLOR: Color = Color(0.5, 0.24, 0.7)
const BODY_DARK_COLOR: Color = Color(0.32, 0.14, 0.45)
const EYE_IDLE_COLOR: Color = Color(0.2, 0.08, 0.28)
const EYE_CHARGED_COLOR: Color = Color(1.0, 0.6, 0.15)
## Preloaded once: the orb scene to instance for every shot.
const ORB_SCENE: PackedScene = preload("res://scenes/enemies/sentry_orb.tscn")

## Emitted once when a reflected orb destroys the sentry. Same name as Wisp.defeated,
## so EnemyGate can treat every enemy the same way (duck typing).
signal defeated

## Hang from the ceiling (origin = top-center) instead of sitting on the floor.
@export var mounted_on_ceiling: bool = false:
	set(value):
		mounted_on_ceiling = value
		_resize_hitbox()
		queue_redraw()
## Off = never fires (a practice target that a reflected orb can still destroy).
@export var can_fire: bool = true:
	set(value):
		can_fire = value
		queue_redraw()
## Turret size, px.
@export var body_size: Vector2 = Vector2(12, 12):
	set(value):
		body_size = value
		_resize_hitbox()
		queue_redraw()
## Seconds between shots (GAME_DESIGN.md §7: 2 s).
@export var fire_interval: float = 2.0
## Seconds from first spotting the player to the first shot.
@export var first_shot_delay: float = 1.0
## Seconds the eye glows before each shot.
@export var telegraph_time: float = 0.4
## How far it can see, px.
@export var sight_range: float = 220.0
## Speed of its orbs, px/s. Slow: they're meant to be reflected.
@export var orb_speed: float = 60.0
## What each kind of hit does to it (Stage F11). Empty = the table in _make_immunity().
@export var immunity: ElementImmunity

## Seconds left until the next shot (counts only while it sees the player).
var time_until_shot: float = 0.0
var is_destroyed: bool = false
## True this frame if it can see the player (also used for drawing the aim).
var can_see_player: bool = false
## Unit direction from the eye to the player, for aiming and for drawing the pupil.
var aim_direction: Vector2 = Vector2.LEFT

var hitbox: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 | 16  # bit values of layer 1 "world" and layer 5 "enemies"
	collision_mask = 0        # a static body never needs to detect anything
	hitbox = CollisionShape2D.new()
	hitbox.shape = RectangleShape2D.new()
	add_child(hitbox)
	_resize_hitbox()
	if Engine.is_editor_hint():
		return
	time_until_shot = first_shot_delay
	if immunity == null:
		immunity = _make_immunity()
	add_to_group(EnemyHit.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(SentryOrb.TARGET_GROUP)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_destroyed or not can_fire:
		return
	var target: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	can_see_player = target != null and _can_see(target)
	if can_see_player:
		aim_direction = (target.get_center() - get_eye_position()).normalized()
		time_until_shot -= delta
		if time_until_shot <= 0.0:
			_fire()
			time_until_shot = fire_interval
	else:
		# Lost sight: hold off, but never stay mid-glow, and when it spots you again
		# you get at least the first-shot delay.
		time_until_shot = maxf(time_until_shot, first_shot_delay)
	queue_redraw()


## The middle of the turret's eye in world space: where orbs come from.
func get_eye_position() -> Vector2:
	return global_position + _get_local_center()


## The middle of the body relative to the origin: above it on a floor, below it on
## a ceiling.
func _get_local_center() -> Vector2:
	return Vector2(0.0, body_size.y / 2.0 if mounted_on_ceiling else -body_size.y / 2.0)


## SentryOrb aim assist: where a reflected orb should fly to hit us.
func get_orb_target_position() -> Vector2:
	return get_eye_position()


## SentryOrb aim assist: can a reflected orb still hit us?
func is_valid_orb_target() -> bool:
	return not is_destroyed


## Same room, close enough, alive, and nothing solid in between.
func _can_see(target: Player) -> bool:
	if target.is_dead():
		return false
	# Only the room the player is in is "awake": sentries in other rooms stay quiet.
	if GameState.current_room == null or not GameState.current_room.is_ancestor_of(self):
		return false
	var eye: Vector2 = get_eye_position()
	var target_center: Vector2 = target.get_center()
	if eye.distance_to(target_center) > sight_range:
		return false
	# A ray against layer 1 ("world"). Exclude ourselves: the ray starts inside us.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(eye, target_center, 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _fire() -> void:
	var orb: SentryOrb = ORB_SCENE.instantiate() as SentryOrb
	# The orb lives in the room (our parent), not under us, so the room's reset can
	# find it and it keeps flying if we're destroyed.
	get_parent().add_child(orb)
	orb.launch(get_eye_position(), aim_direction * orb_speed, self)


## Hit by a reflected orb (SentryOrb calls this). Gone until the room resets.
func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	visible = false
	collision_layer = 0  # no longer solid, no longer blocks orbs or the player
	_spawn_burst()
	FX.freeze(0.06)
	FX.shake(3.0, 0.2)
	FX.play_sfx(&"sentry_destroyed")
	defeated.emit()


## The sentry's row of the §7.2 table: a fireball, a big or perfect rock and a
## reflected orb destroy it. It's bolted down and metal: everything else (a sloppy
## small rock, flames, gusts, earth pushes) does nothing.
static func _make_immunity() -> ElementImmunity:
	var kill: ElementImmunity.Response = ElementImmunity.Response.KILL
	return ElementImmunity.from_table({
		EnemyHit.Type.FIREBALL: kill, EnemyHit.Type.BIG_ROCK: kill,
		EnemyHit.Type.PERFECT_ROCK: kill, EnemyHit.Type.REFLECTED_ORB: kill,
	})


## The EnemyHit contract (Stage F11): every hit lands here. A kill destroys it at
## once (it's bolted down, so the knockback and delay a wisp gets don't apply).
func receive_hit(hit: EnemyHit) -> ElementImmunity.Response:
	if is_destroyed:
		return ElementImmunity.Response.IGNORE
	var response: ElementImmunity.Response = immunity.get_response(hit.type)
	if response == ElementImmunity.Response.KILL:
		destroy()
	elif hit.type == EnemyHit.Type.SMALL_ROCK:
		FX.shake(0.5, 0.06)  # a clonk off the armour
	return response


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	is_destroyed = false
	visible = true
	collision_layer = 1 | 16
	time_until_shot = first_shot_delay


func _resize_hitbox() -> void:
	if hitbox == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(hitbox.shape as RectangleShape2D).size = body_size
	# Origin is at the mounting surface, and a shape is positioned by its center.
	hitbox.position = _get_local_center()


## Purple and orange chunks flying out.
func _spawn_burst() -> void:
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 24
	burst.lifetime = 0.5
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 250.0)
	burst.initial_velocity_min = 50.0
	burst.initial_velocity_max = 110.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 3.0
	# A gradient from orange to purple: each particle picks a random color along it.
	var colors: Gradient = Gradient.new()
	colors.set_color(0, EYE_CHARGED_COLOR)
	colors.set_color(1, BODY_COLOR)
	burst.color_initial_ramp = colors
	get_parent().add_child(burst)
	burst.global_position = get_eye_position()
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.1, false).timeout.connect(burst.queue_free)


func _draw() -> void:
	var box: Rect2 = Rect2(_get_local_center() - body_size / 2.0, body_size)
	draw_rect(box, BODY_COLOR)
	# A darker base strip on the mounting side, so it reads as "mounted", not as a crate.
	var base_y: float = box.position.y if mounted_on_ceiling else box.end.y - 3.0
	draw_rect(Rect2(box.position.x, base_y, box.size.x, 3.0), BODY_DARK_COLOR)

	# The eye: dark normally, blending to orange during the telegraph.
	var charge: float = 0.0
	if can_see_player and time_until_shot < telegraph_time:
		charge = 1.0 - time_until_shot / telegraph_time
	var eye_center: Vector2 = _get_local_center()
	draw_circle(eye_center, 3.5, EYE_IDLE_COLOR.lerp(EYE_CHARGED_COLOR, charge))
	if not can_fire:
		# A practice target: a bullseye ring instead of a pupil.
		draw_arc(eye_center, 2.0, 0.0, TAU, 12, BODY_COLOR, 1.0)
		return
	# The pupil looks at the player while it can see them.
	var pupil_offset: Vector2 = (aim_direction * 1.5).round() if can_see_player else Vector2.ZERO
	draw_rect(Rect2(eye_center + pupil_offset - Vector2.ONE, Vector2(2, 2)),
		Color.WHITE if charge > 0.0 else BODY_COLOR)

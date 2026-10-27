class_name Fireball
extends Area2D
## Fireball (Fire_bending.md §5.1, §9.3): thrown by FireballAbility (Q). Made in code
## with Fireball.new(); no scene file.
##
## Flight: thrown at FireTuning.fireball_speed in `direction`, then pulled down by a
## little gravity (fireball_gravity_scale x the player's gravity), with a lift on
## level throws so they arc instead of diving (get_launch_velocity). After
## fireball_max_range px along its path it gutters out (shrinks, puff of smoke) and
## lights nothing.
##
## Hits: an 8×8 Area2D that watches physics layer 1 ("world": tiles, doors, crates,
## sentries), layer 5 ("enemies": wisps, vine monkeys and sentry orbs, Stage F11) and
## layer 6 ("flammable": the catch areas of braziers, vines...). On the first thing it
## touches:
##   - an enemy: a FIREBALL hit (EnemyHit): its table decides (a wisp burns up, a
##     sentry is destroyed, a vine monkey becomes a torch)
##   - a sentry orb: both cancel out (the orb pops, the fireball bursts)
##   - a flammable: lit (Flammable.try_ignite)
##   - plus every flammable within fireball_splash px of the hit (Flammable.ignite_near)
##   - then it bursts: flash, a ring of sparks, smoke, 1-2 embers stuck to the wall
## WATER (after W3 play-test 3): flying into any water (a pool, loose drops, the
## held waterball) puts it out with a puff of steam: nothing lit, no burst.
## The player (layer 2) isn't watched, so it never hits you (not even bouncing back
## at you). It isn't a FireHazard either.
## HOSTILE fireballs (after the L10 play-test): a Sentry with fire_orbs on throws
## this very fireball, then calls make_hostile(): its sweep also looks at layer 2,
## touching the player kills them (and bursts it), and it never meets the sentry
## that threw it. Everything else (flight, bounces, lighting, burst) is the same.
##
## Ricochets (Stage F12): solid things (world and enemy BODIES) are found by sweeping
## the hitbox along each frame's move (Ricochet.find_contact) before moving, so it
## knows the surface's angle. On a solid it:
##   - an enemy: a FIREBALL hit; if its table says REFLECT (the Shell), it bounces
##     off with a few sparks, else it bursts as above
##   - anything else: lights it and everything in the splash; if anything caught
##     (grass or thicket ground, a crate, a brazier...) it bursts there, as before
##     F12. If nothing burns (bare earth, stone, ash) it BOUNCES: mirrored off the
##     surface, keeping fireball_bounce_keep of its speed, and flies on until its
##     range is used up (bounces count toward fireball_max_range). Too slow off the
##     surface (skimming, rolling: fireball_min_bounce_speed) or past
##     fireball_max_bounces: it bursts there.
## Areas (orbs, the catch areas of braziers and vines) still come in through
## area_entered, as before.
##
## Look: a bright 6 px core, 3 FlameTongues orbiting it and trailing behind, embers
## and smoke streaming off. It wobbles a little as it flies; that's only the drawing
## (the `visual` child moves), the hitbox stays on its path.
##
## Godot concepts used:
##   - Area2D signals body_entered / area_entered: emitted when another body or area
##     starts overlapping. A TileMapLayer counts as a body.
##   - set_deferred(): changing physics state (monitoring) from inside a physics
##     callback isn't allowed; deferring it applies the change after the step.

const CORE_COLOR: Color = Color("#FFF6CC")
const INNER_COLOR: Color = Color("#FFD34D")
const HITBOX_SIZE: Vector2 = Vector2(8, 8)
const CORE_RADIUS: float = 3.0
const TONGUE_COUNT: int = 3
## Orbit of the tongues around the core: radius px, turns per second.
const ORBIT_RADIUS: float = 1.5
const ORBIT_SPEED: float = 2.5
const TONGUE_LENGTH: float = 7.0
## Visual wobble across the flight line: px and radians per second.
const WOBBLE_AMOUNT: float = 1.0
const WOBBLE_SPEED: float = 22.0
## Guttering out at the end of the range, seconds.
const GUTTER_TIME: float = 0.15
## Bit values: layer 1 "world" + layer 5 "enemies" (Stage F11) + layer 6 "flammable".
const HIT_MASK: int = 1 | 16 | Flammable.LAYER_BIT
## The bodies the move sweep looks for (Stage F12): "world" and "enemies".
const SOLID_MASK: int = 1 | 16
## Sparks off a bounce.
const BOUNCE_SPARK_COUNT: int = 4

## Emitted once when it bursts on something (`hit_node`: what it touched) or gutters
## out (hit_node null).
signal finished(hit_node: Node)

var tuning: FireTuning
## The unit direction it was THROWN in (the aim). It curves away from this as it falls.
var direction: Vector2 = Vector2.RIGHT
## Current velocity, px/s, and the gravity pulling on it, px/s^2 (not `gravity`:
## Area2D already has a property by that name, for its gravity-zone feature).
var velocity: Vector2 = Vector2.ZERO
var fall_gravity: float = 0.0
## What threw it (the FireballAbility), passed on to ignite() as the source.
var source: Node
var distance_flown: float = 0.0
var flight_time: float = 0.0
## > 0 while guttering out (counts down); the fireball is harmless by then.
var gutter_remaining: float = 0.0
## The room's water (after W3 play-test 3): any water puts the fireball out.
## Looked up on the first frame; null in a room without water.
var water_world: WaterWorld = null
var has_looked_for_water: bool = false
var has_finished: bool = false
var bounce_count: int = 0
## True for a sentry's fireball (make_hostile): it kills the player it touches.
var hurts_player: bool = false
## The hitbox shape, also swept along each move to find what it would hit.
var hit_shape: RectangleShape2D

## The drawing: a child that wobbles while the Area2D flies straight.
var visual: Node2D
var tongues: Array[FlameTongue] = []
var trail: EmberEmitter


## Makes a fireball at `world_position`, thrown along `throw_direction`.
## `fall_gravity`: the gravity on it, px/s^2 (FireballAbility passes the player's
## gravity x fireball_gravity_scale).
static func launch(parent: Node, world_position: Vector2, throw_direction: Vector2,
		fire_tuning: FireTuning, thrower: Node, fall_gravity: float = 0.0) -> Fireball:
	var fireball: Fireball = Fireball.new()
	fireball.tuning = fire_tuning
	fireball.direction = throw_direction.normalized()
	fireball.fall_gravity = fall_gravity
	fireball.velocity = get_launch_velocity(fireball.direction, fire_tuning, fall_gravity)
	fireball.source = thrower
	parent.add_child(fireball)
	fireball.global_position = world_position
	return fireball


## The velocity a throw starts with: the aim x fireball_speed, plus the arc lift.
## The lift is what gravity takes away over the flight to max range. With the flight
## time T = range / speed, a lift L gains L*T of height and gravity loses g*T*T/2,
## so L = g*T/2 brings it back to hand height at max range. Scaled by how sideways
## the throw is. Shared with the aim preview, so the dotted arc shows exactly where
## the fireball will go.
static func get_launch_velocity(throw_direction: Vector2, fire_tuning: FireTuning, fall_gravity: float) -> Vector2:
	var launch_velocity: Vector2 = throw_direction * fire_tuning.fireball_speed
	if fire_tuning.fireball_arc_lift and fire_tuning.fireball_speed > 0.0:
		var flight_time: float = fire_tuning.fireball_max_range / fire_tuning.fireball_speed
		launch_velocity.y -= 0.5 * fall_gravity * flight_time * absf(throw_direction.x)
	return launch_velocity


func _ready() -> void:
	collision_layer = 0  # nothing needs to find the fireball itself
	collision_mask = HIT_MASK
	# Must stay monitorable (the default), even though nothing looks for it: Godot's 2D
	# physics files a NON-monitorable area as static, and two static things are never
	# checked against each other, so the fireball flew straight through the tile
	# walls (static bodies). Found in Stage F5.
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	hit_shape = RectangleShape2D.new()
	hit_shape.size = HITBOX_SIZE
	shape_node.shape = hit_shape
	add_child(shape_node)
	area_entered.connect(_on_touched)
	z_index = 5
	_build_visual()


## Turns this into a sentry's fireball (see the header).
func make_hostile() -> void:
	hurts_player = true


func _build_visual() -> void:
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	# The orbiting tongues are one flame (FlameMerge: no outlines between them).
	var flame_merge: FlameMerge = FlameMerge.make(visual)
	for tongue_index: int in TONGUE_COUNT:
		var tongue: FlameTongue = FlameTongue.new()
		tongue.length = TONGUE_LENGTH
		tongue.base_width = 4.0
		tongue.fan_width = 5.0
		tongue.heat = 0.6
		tongue.flicker_speed = 2.5
		tongue.fork_amount = 0.4
		tongue.lick_rate = 6.0
		tongue.lick_size = 3.0
		tongue.lick_speed = 15.0
		tongue.smoke_rate = tuning.fireball_smoke_per_second / TONGUE_COUNT
		tongue.smoke_lifetime = 0.5
		visual.add_child(tongue)
		flame_merge.add_tongue(tongue)
		tongues.append(tongue)
	trail = EmberEmitter.new()
	trail.amount = maxi(1, roundi(tuning.fireball_trail_embers_per_second * trail.lifetime))
	trail.direction = -direction
	trail.spread = 30.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 30.0
	trail.emitting = true
	add_child(trail)
	# The core is drawn by this node's _draw(), on top through an additive child.
	var core: Node2D = Node2D.new()
	core.name = "Core"
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	core.material = additive
	visual.add_child(core)
	core.draw.connect(_draw_core.bind(core))


func _physics_process(delta: float) -> void:
	if has_finished:
		return
	if gutter_remaining > 0.0:
		gutter_remaining -= delta
		var fade: float = clampf(gutter_remaining / GUTTER_TIME, 0.0, 1.0)
		visual.scale = Vector2.ONE * fade
		if gutter_remaining <= 0.0:
			_finish(null)
		return
	velocity.y += fall_gravity * delta
	var step: Vector2 = velocity * delta
	# Sweep the move first: a solid in the way is met at its surface, with its angle.
	var sweep_mask: int = SOLID_MASK | 2 if hurts_player else SOLID_MASK  # 2: layer 2, "player"
	var exclude: Array[RID] = []
	if hurts_player and source is CollisionObject2D and is_instance_valid(source):
		exclude.append((source as CollisionObject2D).get_rid())  # never its own sentry
	var contact: Dictionary = Ricochet.find_contact(get_world_2d().direct_space_state, hit_shape,
		global_position, step, sweep_mask, exclude)
	if not contact.is_empty():
		var safe_position: Vector2 = contact["safe_position"]
		distance_flown += global_position.distance_to(safe_position)
		global_position = safe_position
		_on_solid_contact(contact["collider"], contact["normal"], contact["point"])
		return
	global_position += step
	if _is_in_water():
		_douse()
		return
	_light_leaves_passed()
	distance_flown += step.length()
	flight_time += delta
	if distance_flown >= tuning.fireball_max_range:
		_start_gutter()


## Water puts it out (after W3 play-test 3): a pool, loose drops or the ball in the
## player's hands (WaterWorld.is_water_near). The room's water is looked up once.
func _is_in_water() -> bool:
	if not has_looked_for_water:
		has_looked_for_water = true
		water_world = WaterWorld.find_at(get_tree(), global_position)
	return water_world != null and water_world.is_water_near(global_position, HITBOX_SIZE.x / 2.0)


## Put out by water: a hiss of steam and a few sparkles, nothing lit, no burst.
func _douse() -> void:
	SmokePuff.spawn(get_parent(), global_position, 4)
	water_world.sparkle(water_world.to_local(global_position), 6)
	FX.play_sfx(&"fireball_doused")
	_finish(null)


## Flying through leaves lights the ones it passes WITHOUT stopping (F7 play-test):
## a heap on the floor or a cloud a gust threw up, it burns its way through and keeps
## going (leaf piles have no catch area, so nothing here bursts it). Cheap: a handful
## of piles, each a quick bounding-box check before looking at its leaves.
func _light_leaves_passed() -> void:
	for target: Node in get_tree().get_nodes_in_group(Flammable.GROUP):
		if target is LeafPile:
			(target as LeafPile).ignite_at(global_position, HITBOX_SIZE.x / 2.0, source)


func _process(_delta: float) -> void:
	# The wobble and the orbit: visual only (the Area2D itself flies its path).
	# Everything follows the CURRENT heading, so the tongues trail along the arc.
	var heading: Vector2 = velocity.normalized() if velocity != Vector2.ZERO else direction
	trail.direction = -heading
	var across: Vector2 = heading.orthogonal()
	visual.position = across * sin(flight_time * WOBBLE_SPEED) * WOBBLE_AMOUNT
	for tongue_index: int in tongues.size():
		var tongue: FlameTongue = tongues[tongue_index]
		var angle: float = flight_time * ORBIT_SPEED * TAU + tongue_index * TAU / TONGUE_COUNT
		tongue.position = Vector2.from_angle(angle) * ORBIT_RADIUS
		# Tongues stream backward from the core (FlameTongue draws toward local -Y),
		# fanned a little apart.
		var spread_angle: float = (tongue_index - 1) * 0.35
		tongue.rotation = (-heading).angle() + PI / 2.0 + spread_angle
	visual.get_node("Core").queue_redraw()


func _draw_core(core: Node2D) -> void:
	core.draw_circle(Vector2.ZERO, CORE_RADIUS, Color(INNER_COLOR, 0.9))
	core.draw_circle(Vector2.ZERO, CORE_RADIUS * 0.6, CORE_COLOR)


func _on_touched(touched: Node) -> void:
	if has_finished or gutter_remaining > 0.0:
		return
	# Solid bodies are the move sweep's job (_on_solid_contact, Stage F12): it stops the
	# fireball touching them, and the overlap signal would then burst it on top of the
	# sweep's bounce. Only areas (orbs, catch areas) are handled here.
	if not touched is Area2D:
		return
	var hit_point: Vector2 = global_position
	var heading: Vector2 = velocity.normalized() if velocity != Vector2.ZERO else direction
	# Head-on into a sentry orb: both are gone (Stage F11).
	var orb: SentryOrb = touched as SentryOrb
	if orb != null:
		orb.pop()
	else:
		# An enemy takes the fireball itself (its table decides); the splash below
		# then counts as a flame for every flammable around, enemies included.
		EnemyHit.send(touched, EnemyHit.Type.FIREBALL, heading * tuning.fireball_speed, source, 0.0, hit_point)
	# Light what we hit, then everything within the splash radius.
	Flammable.try_ignite(touched, source)
	Flammable.ignite_near(get_tree(), hit_point, tuning.fireball_splash, source)
	_burst(hit_point)
	_finish(touched)


## The sweep met a solid body (Stage F12): an enemy gets the hit and may reflect it;
## anything else is lit if it can burn (then the fireball bursts, as ever), and if
## nothing caught, it bounces.
func _on_solid_contact(collider: Object, normal: Vector2, point: Vector2) -> void:
	var touched: Node = collider as Node
	if touched == null:
		return
	if touched is Player:
		# Only a hostile fireball looks at the player at all.
		if not (touched as Player).is_dead():
			(touched as Player).die()
		_end_on(touched, point)
		return
	if EnemyHit.is_enemy(touched):
		var heading: Vector2 = velocity.normalized()
		var response: ElementImmunity.Response = EnemyHit.send(touched, EnemyHit.Type.FIREBALL,
			heading * tuning.fireball_speed, source, 0.0, point)
		if response == ElementImmunity.Response.REFLECT and _try_bounce(normal, point):
			return
		_end_on(touched, point)
		return
	var caught: bool = Flammable.try_ignite(touched, source)
	if Flammable.ignite_near(get_tree(), point, tuning.fireball_splash, source) > 0:
		caught = true
	if caught or not _try_bounce(normal, point):
		_burst(point)
		_finish(touched)


## Mirrors the flight off a surface facing `normal`. False (no bounce) when it would
## leave too slowly off the surface, or the bounce cap is reached: it bursts instead.
func _try_bounce(normal: Vector2, point: Vector2) -> bool:
	if tuning.fireball_max_bounces >= 0 and bounce_count >= tuning.fireball_max_bounces:
		return false
	var bounced: Vector2 = Ricochet.bounce(velocity, normal, tuning.fireball_bounce_keep)
	if bounced.dot(normal) < tuning.fireball_min_bounce_speed:
		return false
	velocity = bounced
	bounce_count += 1
	EmberEmitter.burst(get_parent(), point, BOUNCE_SPARK_COUNT, normal, 120.0, 50.0)
	FX.play_sfx(&"fireball_bounce")
	return true


## An enemy took it (its table didn't reflect it): the splash, then the burst.
func _end_on(touched: Node, hit_point: Vector2) -> void:
	Flammable.try_ignite(touched, source)
	Flammable.ignite_near(get_tree(), hit_point, tuning.fireball_splash, source)
	_burst(hit_point)
	_finish(touched)


## The burst on a hit: a spark ring, smoke, and the flash + stuck embers.
func _burst(hit_point: Vector2) -> void:
	var effects_parent: Node = get_parent()
	var heading: Vector2 = velocity.normalized() if velocity != Vector2.ZERO else direction
	EmberEmitter.burst(effects_parent, hit_point, tuning.fireball_impact_spark_count,
		-heading, 180.0, 70.0)
	SmokePuff.spawn(effects_parent, hit_point, 4)
	# The wall we hit faces back along our flight.
	FireImpact.spawn(effects_parent, hit_point, -heading, tuning.fireball_stuck_ember_time)
	FX.shake(1.0, 0.08)
	FX.play_sfx(&"fireball_hit")


func _start_gutter() -> void:
	gutter_remaining = GUTTER_TIME
	SmokePuff.spawn(get_parent(), global_position, 3)


func _finish(hit_node: Node) -> void:
	has_finished = true
	set_deferred(&"monitoring", false)
	finished.emit(hit_node)
	# Let the trail's embers live on in the world: hand the emitter to the parent,
	# stop it, and free it once its last ember is gone.
	trail.emitting = false
	trail.reparent(get_parent())
	get_tree().create_timer(trail.lifetime * 2.0).timeout.connect(trail.queue_free)
	queue_free()

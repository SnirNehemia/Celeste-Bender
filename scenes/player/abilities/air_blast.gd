class_name AirBlast
extends RefCounted
## Shared "blast of air" toolkit used by every air move that shoves the world:
##   - GustAbility: the gust cone in front of the player (Z)
##   - AirDashAbility: the dash's WAKE, a smaller cone of air left behind at dash start
##
## It does three things, all as static functions (called on the class itself,
## like AirBlast.build_cone(...); this class is never instantiated):
##   1. build_cone() / build_circle(): the blast's shape, as world-space points
##   2. push_in_cone():   push everything Pushable inside a cone one way
##      push_around():    push everything Pushable inside a circle straight away
##                        from its center (the neutral, all-around gust)
##                        (the Pushable contract: scenes/objects/pushable.gd)
##   3. spawn_fan() / spawn_wave() / spawn_ring(): the look, so dash wake and gust
##                        read as the same power (particles, pressure waves, rings)
##
## Why a helper class and not code inside GustAbility? Both abilities need it, and
## an ability shouldn't call into another ability. Each one stays a separate
## component (CLAUDE.md), and the shared part lives here.

## Color of all air effects (same pale cyan-white as dash and glide: one power).
const AIR_COLOR: Color = Color(0.85, 0.95, 1.0, 0.8)
## Physics layers a blast looks at: every layer except 2 ("player").
## 0xFFFFFFFF has all 32 layer bits set; & ~2 clears the player's bit.
const QUERY_COLLISION_MASK: int = 0xFFFFFFFF & ~2


## The cone as 4 world-space points: a narrow edge at `origin`, a wide edge
## `length` px away. Built pointing along +x, then rotated to `direction`.
static func build_cone(origin: Vector2, direction: Vector2, length: float,
		half_angle_degrees: float, near_half_width: float) -> PackedVector2Array:
	var far_half_width: float = length * tan(deg_to_rad(half_angle_degrees))
	var local_points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -near_half_width),
		Vector2(length, -far_half_width),
		Vector2(length, far_half_width),
		Vector2(0.0, near_half_width),
	])
	# A Transform2D (rotation, position) maps local points to world points:
	# rotate by the aim angle, then move to the origin.
	return Transform2D(direction.angle(), origin) * local_points


## A circle approximated by `segment_count` world-space points. A polygon (not a
## CircleShape2D) so the same query and debug drawing work for cones and circles.
static func build_circle(center: Vector2, radius: float, segment_count: int = 16) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in segment_count:
		points.append(center + Vector2.from_angle(TAU * point_index / segment_count) * radius)
	return points


## Pushes every Pushable object overlapping `cone_points` toward `direction`.
## `body` is the node doing the blast (the player). Returns the pushed objects.
static func push_in_cone(body: CollisionObject2D, cone_points: PackedVector2Array,
		direction: Vector2, strength: float) -> Array[Node]:
	var targets: Array[Node] = find_pushables(body, cone_points)
	# The cone's origin is the middle of its narrow edge (points 0 and 3, see build_cone).
	var source_position: Vector2 = (cone_points[0] + cone_points[3]) / 2.0
	for target: Node in targets:
		Pushable.try_push(target, direction, strength, source_position)
	return targets


## Pushes every Pushable object within `radius` of `center` straight AWAY from the
## center (each one in its own direction). Returns the pushed objects.
static func push_around(body: CollisionObject2D, center: Vector2, radius: float,
		strength: float) -> Array[Node]:
	var targets: Array[Node] = find_pushables(body, build_circle(center, radius))
	for target: Node in targets:
		var outward: Vector2 = Vector2.UP  # fallback: no position, or exactly on the center
		var target_2d: Node2D = target as Node2D
		if target_2d != null and target_2d.global_position != center:
			outward = (target_2d.global_position - center).normalized()
		Pushable.try_push(target, outward, strength, center)
	return targets


## Every Pushable object overlapping the convex polygon `points` (world space), once
## each. `body` (the player) gives us the physics world and is excluded.
static func find_pushables(body: CollisionObject2D, points: PackedVector2Array) -> Array[Node]:
	var polygon_shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	polygon_shape.points = points  # already in world space, so the transform stays identity

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = polygon_shape
	query.collision_mask = QUERY_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [body.get_rid()]

	# The "direct space state" is the physics world, queried immediately. Safe
	# because blasts happen inside the player's _physics_process.
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var results: Array[Dictionary] = space.intersect_shape(query, 64)

	# A node with two collision shapes is reported twice: keep it only once.
	var pushables: Array[Node] = []
	for result: Dictionary in results:
		var target: Node = Pushable.find_pushable(result["collider"] as Node)
		if target != null and not pushables.has(target):
			pushables.append(target)
	return pushables


## A fan of air particles blown along `direction` within ±`spread_degrees`, added to
## `world` (so it stays put while the player moves on). Speed and damping are picked
## so particles travel about `length` before stalling: distance ≈ speed² / (2 × damping).
static func spawn_fan(world: Node, world_position: Vector2, direction: Vector2,
		spread_degrees: float, length: float, particle_count: int) -> void:
	var fan: CPUParticles2D = CPUParticles2D.new()
	fan.one_shot = true
	fan.explosiveness = 0.9  # almost all at once; a tiny stagger looks more like air
	fan.amount = particle_count
	fan.lifetime = 0.3
	fan.direction = direction
	fan.spread = spread_degrees
	fan.gravity = Vector2.ZERO
	fan.damping_min = 300.0
	fan.damping_max = 400.0
	# Solve distance = v² / (2 × damping) for v, at the average damping (350).
	var average_speed: float = sqrt(2.0 * 350.0 * length)
	fan.initial_velocity_min = average_speed * 0.75
	fan.initial_velocity_max = average_speed * 1.25
	# Curl sideways a little: swirling air, not a shotgun blast.
	fan.tangential_accel_min = -80.0
	fan.tangential_accel_max = 80.0
	fan.scale_amount_min = 1.0
	fan.scale_amount_max = 2.0
	fan.color = AIR_COLOR
	world.add_child(fan)
	fan.global_position = world_position
	fan.emitting = true
	# Free it once every particle has died (game time, so freeze frames don't cut it short).
	world.get_tree().create_timer(fan.lifetime + 0.1, false).timeout.connect(fan.queue_free)


## A curved ")" line that rolls outward along the cone, widening and fading: the
## visible front of the pushed air. `delay` staggers a second wave behind the first.
static func spawn_wave(world: Node, world_position: Vector2, direction: Vector2,
		length: float, near_half_width: float, far_half_width: float, delay: float) -> void:
	var wave: Line2D = Line2D.new()
	# Line2D width is scaled with the node. The arc runs mostly along local y, so its
	# thickness lies along local x, which gets scaled ~2.5x below: 0.4 ends up ~1 px.
	wave.width = 0.4
	wave.default_color = AIR_COLOR
	# An arc bulging forward, drawn along +x and then rotated to the aim.
	# Its half-height is 1 here; scaling y widens it as it travels.
	wave.points = PackedVector2Array([
		Vector2(-1.5, -1.0), Vector2(-0.3, -0.6), Vector2(0.0, 0.0), Vector2(-0.3, 0.6), Vector2(-1.5, 1.0)])
	wave.rotation = direction.angle()
	wave.scale = Vector2(2.0, near_half_width + 1.0)
	wave.modulate.a = 0.0 if delay > 0.0 else 1.0
	world.add_child(wave)
	wave.global_position = world_position + direction * 4.0

	var travel_time: float = 0.2
	var wave_tween: Tween = wave.create_tween()
	if delay > 0.0:
		wave_tween.tween_interval(delay)
		wave_tween.tween_property(wave, "modulate:a", 1.0, 0.0)
	wave_tween.set_parallel(true)
	wave_tween.tween_property(wave, "global_position", world_position + direction * length, travel_time) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	wave_tween.tween_property(wave, "scale", Vector2(3.0, far_half_width), travel_time) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	wave_tween.tween_property(wave, "modulate:a", 0.0, travel_time).set_delay(travel_time * 0.4)
	wave_tween.chain().tween_callback(wave.queue_free)


## An expanding, fading circle outline: a shockwave. Used by the dash start and the
## neutral (all-around) gust.
static func spawn_ring(world: Node, world_position: Vector2, start_radius: float,
		end_radius: float, duration: float) -> void:
	var ring: Line2D = Line2D.new()
	ring.default_color = AIR_COLOR
	ring.closed = true
	# A circle of radius 1; growing it is just scaling the node.
	ring.points = build_circle(Vector2.ZERO, 1.0, 12)
	ring.scale = Vector2.ONE * start_radius
	# Line2D width is scaled too; divide so the outline stays ~1 px thick.
	ring.width = 1.0 / start_radius
	world.add_child(ring)
	ring.global_position = world_position

	var grow_tween: Tween = ring.create_tween().set_parallel(true)
	grow_tween.tween_property(ring, "scale", Vector2.ONE * end_radius, duration) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	grow_tween.tween_property(ring, "width", 1.0 / end_radius, duration)
	grow_tween.tween_property(ring, "modulate:a", 0.0, duration)
	grow_tween.chain().tween_callback(ring.queue_free)

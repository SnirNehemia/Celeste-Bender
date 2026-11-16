@tool
class_name WindZone
extends Area2D
## Wind zone (GAME_DESIGN.md §6): a rectangle of constant wind. Horizontal currents
## push the player sideways; updrafts (direction up) lift a gliding player.
##
## The node's position is the zone's TOP-LEFT corner (same convention as a room's
## solid_rects), and `zone_size` sets its size. Everything else (hitbox, drifting
## particles) is built in code, so wind_zone.tscn is one node.
##
## THE LOOK (art pass): no box. A faint cyan patch that fades out toward its edge in
## steps (ZoneFill), specks drifting with the wind, and a few longer STREAKS racing
## the same way (_draw), so the zone is read by what moves in it. The patch still
## ends exactly at the zone's edge: that's where the wind stops.
##
## How it pushes: this zone does NOT change the player's velocity itself. It only
## tells the player "you're inside me" (enter_wind_zone / exit_wind_zone). The
## player's movement helpers then ask get_wind_velocity() and shift their target
## speeds by it. That keeps all movement math in one place (player.gd).
##
## Godot concept — Area2D: a region that detects bodies overlapping it but doesn't
## block them. Its body_entered / body_exited SIGNALS fire when a body crosses its edge.
## Physics: layer none, mask 2 ("player"): it only looks for the player.
## Other things that ride the wind (SailPlatform) find zones through the group
## GROUP instead and check the zone's rectangle themselves (see contains_point()).
## @tool: the script also runs in the editor, so you see the zone while placing it.
##
## HOT UPDRAFTS (Stage F7, Fire_bending.md §5.3): with `heat` on, the zone is hot air
## rising, not wind. It pushes NOTHING through get_wind_velocity() (that returns zero,
## so the player on foot, the jet, sails, grass, pebbles and crates ignore it without
## knowing about heat). Instead it is a heat source (scenes/objects/fire/heat.gd):
## the glide asks Heat.get_lift_at() and rises by wind_strength, and every node in the
## "heat_receiver" group inside it gets apply_heat(wind_strength, delta) each physics
## frame. It looks warm: a faint orange tint and rising embers instead of cyan specks.
## A Bonfire makes one above its flame; one can also be placed by hand.

## Translucent cyan (GAME_DESIGN.md §2) and the brighter particle color.
const FILL_COLOR: Color = Color(0.4, 0.9, 1.0, 0.1)
const PARTICLE_COLOR: Color = Color(0.7, 0.95, 1.0, 0.6)
## Hot air (heat on): a barely-there warm tint and ember-orange specks (§9.1 body).
const HEAT_FILL_COLOR: Color = Color(1.0, 0.55, 0.15, 0.06)
const HEAT_PARTICLE_COLOR: Color = Color(1.0, 0.6, 0.2, 0.7)
## Upper limit on drifting specks per zone, for performance.
const MAX_SPECKS: int = 400
## Streaks: thin lines racing with the wind. About one per this much zone, px²,
## between STREAK_MIN_COUNT and STREAK_MAX_COUNT...
const STREAK_AREA: float = 700.0
const STREAK_MIN_COUNT: int = 2
const STREAK_MAX_COUNT: int = 28
## ...each STREAK_MIN_LENGTH..STREAK_MAX_LENGTH px long, moving this many times the
## wind's speed (faster than the specks: they're what the eye follows)...
const STREAK_MIN_LENGTH: float = 5.0
const STREAK_MAX_LENGTH: float = 11.0
const STREAK_SPEED_FACTOR: float = 1.6
## ...in this color (hot updrafts: HEAT_STREAK_COLOR), fading in and out over this
## fraction of the zone's length at each end.
const STREAK_COLOR: Color = Color(0.82, 0.97, 1.0, 0.5)
const HEAT_STREAK_COLOR: Color = Color(1.0, 0.7, 0.3, 0.45)
const STREAK_FADE_FRACTION: float = 0.25
## Every wind zone joins this group, so non-player objects can find them.
const GROUP: StringName = &"wind_zones"

## Size of the zone in px. Changing it in the Inspector rebuilds the zone.
@export var zone_size: Vector2 = Vector2(32, 64):
	set(value):
		zone_size = value
		_rebuild()
## Which way the wind blows. Use (0, -1) for an updraft, (1, 0) / (-1, 0) for currents.
@export var wind_direction: Vector2 = Vector2.UP:
	set(value):
		wind_direction = value
		_rebuild()
## Wind speed in px/s. A horizontal current of 50 lets you walk against it at
## 90 - 50 = 40 px/s. An updraft of 60 lifts a glider (see PlayerTuning > Glide).
@export var wind_strength: float = 60.0:
	set(value):
		wind_strength = value
		_rebuild()

## Hot updraft (see the header): lifts only gliders and heat receivers, by
## wind_strength px/s, and blows nothing.
@export var heat: bool = false:
	set(value):
		heat = value
		_update_heat_group()
		_rebuild()

var collision_shape: CollisionShape2D
var drift_particles: CPUParticles2D
## Seconds since the zone appeared: moves the streaks.
var streak_clock: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # bit value of layer 2, "player"
	_rebuild()
	# Connecting signals in code: when a body enters/exits, call our function.
	# In the editor (@tool) we skip it: no gameplay there.
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
		_update_heat_group()
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if heat and not Engine.is_editor_hint():
		Heat.heat_receivers(get_tree(), self, delta)


## Moves the streaks (a look only, so _process: once per drawn frame).
func _process(delta: float) -> void:
	streak_clock += delta
	queue_redraw()


## The patch of air and its streaks (see THE LOOK). Each streak's lane, length and
## head start come from a hash of its number, so they're the same every run; its
## place along the wind is the clock, wrapped round the zone's length.
func _draw() -> void:
	ZoneFill.draw_soft_rect(self, Rect2(Vector2.ZERO, zone_size), HEAT_FILL_COLOR if heat else FILL_COLOR)
	var direction: Vector2 = wind_direction.normalized()
	if direction == Vector2.ZERO:
		return
	# The wind runs along x or along y (whichever is bigger); the lanes are spread
	# over the other one.
	var is_vertical: bool = absf(direction.y) > absf(direction.x)
	var length_along: float = zone_size.y if is_vertical else zone_size.x
	var width_across: float = zone_size.x if is_vertical else zone_size.y
	var heading: float = signf(direction.y) if is_vertical else signf(direction.x)
	var speed: float = maxf(wind_strength, 10.0) * STREAK_SPEED_FACTOR
	var count: int = clampi(int(zone_size.x * zone_size.y / STREAK_AREA), STREAK_MIN_COUNT, STREAK_MAX_COUNT)
	var base_color: Color = HEAT_STREAK_COLOR if heat else STREAK_COLOR
	for streak_index: int in count:
		# & 0x7FFFFFFF keeps the hash positive, so % never goes negative.
		var roll: int = hash(Vector2i(streak_index * 31 + 7, 53)) & 0x7FFFFFFF
		var lane: float = 2.0 + float(roll % 1000) / 1000.0 * maxf(width_across - 4.0, 0.0)
		var streak_length: float = minf(lerpf(STREAK_MIN_LENGTH, STREAK_MAX_LENGTH, float((roll >> 10) % 100) / 100.0), length_along)
		var travel: float = length_along + streak_length
		var along: float = fposmod(streak_clock * speed * (0.8 + float((roll >> 17) % 40) / 100.0) + float((roll >> 5) % 997), travel) - streak_length
		# Faint near both ends of the zone, so a streak never pops in or out.
		var middle: float = (along + streak_length / 2.0) / length_along
		var fade: float = clampf(minf(middle, 1.0 - middle) / STREAK_FADE_FRACTION, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var from_along: float = clampf(along, 0.0, length_along)
		var to_along: float = clampf(along + streak_length, 0.0, length_along)
		if heading < 0.0:
			from_along = length_along - from_along
			to_along = length_along - to_along
		var from: Vector2 = Vector2(lane, from_along) if is_vertical else Vector2(from_along, lane)
		var to: Vector2 = Vector2(lane, to_along) if is_vertical else Vector2(to_along, lane)
		draw_line(from.round() + Vector2(0.5, 0.5), to.round() + Vector2(0.5, 0.5), Color(base_color, base_color.a * fade), 1.0)


## The wind this zone applies, px/s. Hot air is not wind: zero.
func get_wind_velocity() -> Vector2:
	if heat:
		return Vector2.ZERO
	return wind_direction.normalized() * wind_strength


## The heat-source contract (heat.gd): the lift at `world_point`, px/s.
func get_heat_lift_at(world_point: Vector2) -> float:
	if heat and contains_point(world_point):
		return wind_strength
	return 0.0


## Joins or leaves the heat sources as `heat` changes (game only).
func _update_heat_group() -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	if heat:
		add_to_group(Heat.SOURCE_GROUP)
	elif is_in_group(Heat.SOURCE_GROUP):
		remove_from_group(Heat.SOURCE_GROUP)


## True if `world_point` is inside this zone (for objects that aren't the player).
func contains_point(world_point: Vector2) -> bool:
	return Rect2(global_position, zone_size).has_point(world_point)


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if player != null:
		player.enter_wind_zone(self)


func _on_body_exited(body: Node2D) -> void:
	var player: Player = body as Player
	if player != null:
		player.exit_wind_zone(self)


## (Re)builds the hitbox and visuals from the exported values. Setters call this,
## so it must cope with being called before _ready() (is_inside_tree() check).
func _rebuild() -> void:
	if not is_inside_tree():
		return
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)
		drift_particles = CPUParticles2D.new()
		add_child(drift_particles)

	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = zone_size
	collision_shape.shape = rectangle
	collision_shape.position = zone_size / 2.0  # shapes are positioned by their center

	queue_redraw()  # the patch and the streaks follow the new size
	_setup_particles()


## Small specks drifting with the wind, spawned anywhere in the zone. Lifetime is
## set so a speck crosses roughly the whole zone before vanishing; it fades out
## (color_ramp) so it doesn't pop at the edge.
func _setup_particles() -> void:
	var direction: Vector2 = wind_direction.normalized()
	var speck_speed: float = maxf(wind_strength, 10.0)
	# Zone length measured along the wind direction.
	var length_along_wind: float = absf(direction.x) * zone_size.x + absf(direction.y) * zone_size.y
	drift_particles.position = zone_size / 2.0
	drift_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drift_particles.emission_rect_extents = zone_size / 2.0
	drift_particles.direction = direction
	drift_particles.spread = 4.0
	drift_particles.gravity = Vector2.ZERO
	drift_particles.initial_velocity_min = speck_speed * 0.8
	drift_particles.initial_velocity_max = speck_speed * 1.2
	drift_particles.lifetime = clampf(length_along_wind / speck_speed * 0.6, 0.3, 4.0)
	# About one speck per 64 px² of zone, between 4 and MAX_SPECKS (a huge zone
	# would otherwise simulate thousands of specks, mostly off-screen).
	drift_particles.amount = clampi(int(zone_size.x * zone_size.y / 64.0), 4, MAX_SPECKS)
	# preprocess simulates this many seconds up front, so the zone is already full of
	# specks when the room appears instead of starting empty.
	drift_particles.preprocess = drift_particles.lifetime
	drift_particles.color = HEAT_PARTICLE_COLOR if heat else PARTICLE_COLOR
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	drift_particles.color_ramp = fade
	drift_particles.emitting = true

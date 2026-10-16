@tool
class_name WindZone
extends Area2D
## Wind zone (GAME_DESIGN.md §6): a rectangle of constant wind. Horizontal currents
## push the player sideways; updrafts (direction up) lift a gliding player.
##
## The node's position is the zone's TOP-LEFT corner (same convention as a room's
## solid_rects), and `zone_size` sets its size. Everything else (hitbox, translucent
## cyan fill, drifting particles) is built in code, so wind_zone.tscn is one node.
##
## How it pushes: this zone does NOT change the player's velocity itself. It only
## tells the player "you're inside me" (enter_wind_zone / exit_wind_zone). The
## player's movement helpers then ask get_wind_velocity() and shift their target
## speeds by it. That keeps all movement math in one place (player.gd).
##
## Godot concept — Area2D: a region that detects bodies overlapping it but doesn't
## block them. Its body_entered / body_exited SIGNALS fire when a body crosses its edge.
## Physics: layer none, mask 2 ("player"): it only looks for the player.
## @tool: the script also runs in the editor, so you see the zone while placing it.

## Translucent cyan (GAME_DESIGN.md §2) and the brighter particle color.
const FILL_COLOR: Color = Color(0.4, 0.9, 1.0, 0.15)
const PARTICLE_COLOR: Color = Color(0.7, 0.95, 1.0, 0.6)
## Upper limit on drifting specks per zone, for performance.
const MAX_SPECKS: int = 400

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

var collision_shape: CollisionShape2D
var fill_rect: ColorRect
var drift_particles: CPUParticles2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # bit value of layer 2, "player"
	_rebuild()
	# Connecting signals in code: when a body enters/exits, call our function.
	# In the editor (@tool) we skip it: no gameplay there.
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


## The wind this zone applies, px/s.
func get_wind_velocity() -> Vector2:
	return wind_direction.normalized() * wind_strength


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
		fill_rect = ColorRect.new()
		# The fill is decoration: don't let it swallow mouse input.
		fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fill_rect)
		drift_particles = CPUParticles2D.new()
		add_child(drift_particles)

	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = zone_size
	collision_shape.shape = rectangle
	collision_shape.position = zone_size / 2.0  # shapes are positioned by their center

	fill_rect.size = zone_size
	fill_rect.color = FILL_COLOR

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
	drift_particles.color = PARTICLE_COLOR
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	drift_particles.color_ramp = fade
	drift_particles.emitting = true

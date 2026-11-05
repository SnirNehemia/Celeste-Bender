class_name SmokeColumn
extends CPUParticles2D
## SmokeColumn (Stage F13, Fire_bending.md §9.3 "Bonfire"): a tall, thin column of
## smoke rising from a big fire, that BENDS WITH THE WIND: a wind zone it rises
## through leans it over, and a gust blowing across it throws it sideways for a
## moment. It also shows where a bonfire's hot updraft is, without any debug view.
##
## A child of the fire (the Bonfire makes one), placed at the flame's top: the owner
## moves it there every frame (set_source) and switches `emitting` on and off.
##
## The bend: CPUParticles2D's `gravity` is a constant acceleration on EVERY live
## particle, and changing it changes it for the ones already in the air too. So a
## sideways gravity tilts the whole column at once, the older (higher) puffs further
## over, which is exactly how a smoke column leans.
##
## Gusts: Flammable.snuff_in_area tells every member of GUST_GROUP (on_gust) when a
## gust blows; the column takes a sideways push that dies away over
## smoke_column_gust_time.
##
## Godot concepts used:
##   - CPUParticles2D: particles simulated on the CPU, set up entirely in code.
##     local_coords = false: a puff stays where it was let go in the WORLD, so the
##     column trails behind a moving source.
##   - Groups as a broadcast: get_tree().call_group(name, method, ...) calls a method
##     on every member, without anyone holding a list of them.

## Gusts reach every member of this group (see the header).
const GUST_GROUP: StringName = &"gust_listeners"
## A warm gray, lighter than the §9.1 smoke so it reads on the dark test skies (the
## same reason as FlameTongue.SMOKE_COLOR).
const SMOKE_COLOR: Color = Color(0.55, 0.5, 0.52)
## How fast the smoke rises, px/s², and how hard wind leans it (share of the wind's
## speed taken as sideways acceleration).
const RISE_ACCELERATION: float = 6.0
const WIND_LEAN: float = 0.6

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
## The sideways push from the last gust, px/s², and seconds it has left.
var gust_push: Vector2 = Vector2.ZERO
var gust_time_left: float = 0.0


func _init() -> void:
	amount = 18
	lifetime = 2.4
	lifetime_randomness = 0.25
	local_coords = false
	emitting = false
	direction = Vector2.UP
	spread = 8.0
	initial_velocity_min = 10.0
	initial_velocity_max = 18.0
	gravity = Vector2(0.0, -RISE_ACCELERATION)
	damping_min = 2.0
	damping_max = 4.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(2.0, 1.0)
	scale_amount_min = 2.0
	scale_amount_max = 3.0
	# scale_amount_curve: puffs grow as they rise (x = age 0..1).
	var growth: Curve = Curve.new()
	growth.add_point(Vector2(0.0, 0.6))
	growth.add_point(Vector2(1.0, 2.2))
	scale_amount_curve = growth
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(SMOKE_COLOR, 0.0))
	fade.set_color(1, Color(SMOKE_COLOR, 0.0))
	fade.add_point(0.12, Color(SMOKE_COLOR, 0.45))  # fades in fast over the flame...
	fade.add_point(0.6, Color(SMOKE_COLOR, 0.25))   # ...and thins out slowly
	color_ramp = fade
	z_index = 4


func _ready() -> void:
	add_to_group(GUST_GROUP)


## The owner's fire: where the smoke leaves it (world) and how wide it is there, px.
func set_source(world_top: Vector2, width: float) -> void:
	global_position = world_top
	emission_rect_extents = Vector2(maxf(width * 0.15, 1.0), 1.0)


func _physics_process(delta: float) -> void:
	if gust_time_left > 0.0:
		gust_time_left = maxf(gust_time_left - delta, 0.0)
	var gust_share: float = gust_time_left / maxf(fire_tuning.smoke_column_gust_time, 0.01)
	var lean: Vector2 = _get_wind_at(global_position + Vector2(0.0, -16.0)) * WIND_LEAN + gust_push * gust_share
	gravity = Vector2(lean.x, -RISE_ACCELERATION + minf(lean.y, 0.0))


## The wind where the column rises: the sum of every wind zone holding `world_point`
## (a hot updraft points up, so it only makes the column rise faster).
func _get_wind_at(world_point: Vector2) -> Vector2:
	var wind: Vector2 = Vector2.ZERO
	for member: Node in get_tree().get_nodes_in_group(WindZone.GROUP):
		var zone: WindZone = member as WindZone
		if zone != null and zone.contains_point(world_point):
			wind += zone.get_wind_velocity()
	return wind


## A gust blew (Flammable.snuff_in_area): `world_polygon` is its cone or circle,
## `gust_direction` its way (ZERO = all around: away from the polygon's middle).
## If the column's foot or the air just above it is inside, it's thrown sideways.
func on_gust(world_polygon: PackedVector2Array, gust_direction: Vector2) -> void:
	if not emitting:
		return
	var touched: bool = false
	for height: float in [0.0, -12.0, -24.0]:
		if Geometry2D.is_point_in_polygon(global_position + Vector2(0.0, height), world_polygon):
			touched = true
			break
	if not touched:
		return
	var push_direction: Vector2 = gust_direction
	if push_direction == Vector2.ZERO:
		var middle: Vector2 = Vector2.ZERO
		for point: Vector2 in world_polygon:
			middle += point
		middle /= maxf(float(world_polygon.size()), 1.0)
		push_direction = (global_position - middle).normalized()
	gust_push = push_direction * fire_tuning.smoke_column_gust_push
	gust_time_left = fire_tuning.smoke_column_gust_time

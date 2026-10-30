@tool
class_name LeafPlatform
extends AnimatableBody2D
## Leaf platform (GAME_DESIGN.md §5.3, §6): a one-way platform on a fixed RAIL.
## Any gust sends it to the far end of its rail, always the same way, whatever
## direction the gust came from. It waits there, then slowly drifts back home.
##
## Readability: the rail is drawn (RailTrack), and a little pinwheel under the leaf
## spins while the wind drives it out (and turns slowly backwards on the way home),
## so it reads as "wind-powered, goes one way". Compare SailPlatform, which goes
## WHICHEVER way the wind blows.
##
## Place the node at the CENTER of the leaf's top surface (where your feet go), at
## the HOME end of the rail. `travel` is the vector to the far end: (0, -32) = 32 px
## straight up (an elevator), (48, 0) = 48 px to the right, (32, -32) = diagonal.
##
## One-way: you can jump up through it from below and land on top, like Celeste's
## jump-through platforms (CollisionShape2D.one_way_collision).
##
## Any gust moves it, from any side, including from above, so you can stand on it
## and puff (neutral gust) to ride it.
##
## Why AnimatableBody2D? It's Godot's body for solids that MOVE by script (moving
## platforms). With sync_to_physics on (the default), Godot works out its velocity
## from how far we moved it, so a player standing on it is carried along smoothly.
##
## The body is on physics layer 1 ("world", so you can stand on it) and layer 4
## ("pushable"), and it is the node the gust finds (Pushable contract, pushable.gd).
##
## Fire (Fire_bending.md §6.2, Stage F8): the leaf is FLAMMABLE (contract in
## scenes/objects/fire/flammable.gd; fireballs hit its body on layer 1). Lit, it
## burns away in `leaf_platform_burn_time` (FireTuning, 0.8 s): it blackens and curls
## from both tips while flames run along it, then it crumbles to ash and is gone
## (no collision) until death or R. It is NOT a FireHazard: the burn is your time to
## jump off (decided in Stage F8). It keeps riding its rail while it burns.
##
## WATER (Stage W7b, Water_bending.md §16 "Planned in Stage W7b"): the leaf FLOATS
## ON ITS RAIL. Where its rail runs through water, it can't sink below the surface:
## it rises along the rail until its top floats leaf_platform_float_lift px above
## the water (at up to leaf_platform_float_speed), and follows the surface down a
## little as waves pass, so it bobs. A current pushes it along its rail
## (leaf_platform_current_share of the water's speed, along the rail's direction),
## like a gust that never stops. The rail stays the level's guarantee: the leaf
## never leaves it. All values in WaterTuning ("Currents").

## Not in the §2 color key: an olive-green leaf, paler while away from home.
const LEAF_COLOR: Color = Color(0.5, 0.72, 0.28)
const LEAF_AWAY_COLOR: Color = Color(0.68, 0.88, 0.42)
const VEIN_COLOR: Color = Color(0.32, 0.48, 0.16)
## The pinwheel is pale cyan-white, the color of all air effects (AirBlast.AIR_COLOR).
const PINWHEEL_COLOR: Color = Color(0.85, 0.95, 1.0)
## Thickness of the solid top surface, px.
const SURFACE_THICKNESS: float = 4.0
## Where the pinwheel hub sits (under the leaf's belly) and its blade length, px.
const PINWHEEL_HUB: Vector2 = Vector2(0.0, 8.0)
const PINWHEEL_BLADE_LENGTH: float = 3.5
## Pinwheel spin speeds, radians/s: driven out by the wind, and drifting home.
const PINWHEEL_DRIVEN_SPEED: float = 25.0
const PINWHEEL_RETURN_SPEED: float = -4.0
## A burning leaf blackens toward this.
const CHARRED_COLOR: Color = Color(0.12, 0.1, 0.08)
const ASH_FLAKE_COLORS: Array[Color] = [Color("#4A4545"), Color("#7A7470"), Color("#5E5858")]
## Flame tongues spread along a burning leaf.
const FLAME_COUNT: int = 3

enum BurnState { LEAF, BURNING, GONE }

## Width of the leaf, px.
@export var leaf_width: float = 32.0:
	set(value):
		leaf_width = value
		_resize_surface()
		queue_redraw()
## From home to the far end of the rail, px. Any direction.
@export var travel: Vector2 = Vector2(0, -32):
	set(value):
		travel = value
		queue_redraw()
## Speed going out after a gust, px/s. Fast, so the gust feels like it threw the leaf.
@export var travel_speed: float = 120.0
## Seconds it waits at the far end before drifting back.
@export var hover_time: float = 1.5
## Speed drifting home, px/s. Slow: you have time to jump off anywhere along the way.
@export var return_speed: float = 12.0

## Home, in the parent's coordinates (the room).
var home_position: Vector2
## How far along the rail it is, px (0 = home .. travel.length() = far end).
var distance_along_rail: float = 0.0
## True while being blown out after a gust.
var is_driven: bool = false
## Seconds of waiting left at the far end.
var hover_remaining: float = 0.0
## Pinwheel rotation and its current spin speed (eases toward a target, see below).
var pinwheel_angle: float = 0.0
var pinwheel_speed: float = 0.0

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var burn_state: BurnState = BurnState.LEAF
var burn_remaining: float = 0.0
var flames: Array[FlameTongue] = []

var surface: CollisionShape2D

## The room's water (Stage W7b), looked up on the first physics frame; null = none.
var water_world: WaterWorld = null
var has_looked_for_water: bool = false
## Is the leaf on (or in) water this frame? (Tests read it.)
var is_floating: bool = false


func _ready() -> void:
	collision_layer = 1 | 8  # bit values of layer 1 "world" and layer 4 "pushable"
	collision_mask = 0       # it moves by script; it doesn't need to detect anything
	surface = CollisionShape2D.new()
	surface.shape = RectangleShape2D.new()
	surface.one_way_collision = true  # solid only from above
	add_child(surface)
	_resize_surface()
	if Engine.is_editor_hint():
		return
	home_position = position
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(Flammable.GROUP)
	var flame_merge: FlameMerge = FlameMerge.make(self)
	for flame_index: int in FLAME_COUNT:
		var flame: FlameTongue = FlameTongue.new()
		flame.position = Vector2(((flame_index + 0.5) / FLAME_COUNT - 0.5) * leaf_width * 0.8, 1.0)
		flame.length = 7.0
		flame.base_width = 5.0
		flame.fan_width = 6.0
		flame.heat = 0.5
		flame.lick_rate = 4.0
		flame.lick_size = 2.5
		flame.smoke_rate = 3.0 if flame_index == 1 else 0.0
		flame.z_index = 1
		flame.visible = false
		add_child(flame)
		flame_merge.add_tongue(flame)
		flames.append(flame)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or burn_state == BurnState.GONE:
		return
	if burn_state == BurnState.BURNING:
		burn_remaining -= delta
		if burn_remaining <= 0.0:
			_crumble()
			return
	var rail_length: float = travel.length()
	var target_pinwheel_speed: float = 0.0
	if is_driven:
		distance_along_rail = move_toward(distance_along_rail, rail_length, travel_speed * delta)
		target_pinwheel_speed = PINWHEEL_DRIVEN_SPEED
		if distance_along_rail >= rail_length:
			is_driven = false
			hover_remaining = hover_time
	elif hover_remaining > 0.0:
		hover_remaining -= delta
	elif distance_along_rail > 0.0:
		distance_along_rail = move_toward(distance_along_rail, 0.0, return_speed * delta)
		target_pinwheel_speed = PINWHEEL_RETURN_SPEED
	# The pinwheel eases toward its target speed (lerp = blend 8 x delta of the way
	# per frame), so it spins up and coasts down instead of starting/stopping instantly.
	pinwheel_speed = lerpf(pinwheel_speed, target_pinwheel_speed, minf(8.0 * delta, 1.0))
	pinwheel_angle += pinwheel_speed * delta
	distance_along_rail = _float_on_water(distance_along_rail, rail_length, delta)

	# Moving an AnimatableBody2D = just setting its position inside _physics_process.
	# round() keeps it on whole pixels, so the leaf and a player standing on it
	# don't shimmer by a sub-pixel at our 320x180 resolution.
	var offset: Vector2 = Vector2.ZERO
	if rail_length > 0.0:
		offset = travel * (distance_along_rail / rail_length)
	position = home_position + offset.round()
	queue_redraw()  # the rail and the pinwheel change every frame


## Water (Stage W7b, see the header): the rail distance after floating on the water
## and riding its current, from `distance` (what the rail logic wanted this frame).
func _float_on_water(distance: float, rail_length: float, delta: float) -> float:
	if not has_looked_for_water:
		has_looked_for_water = true
		water_world = WaterWorld.find_at(get_tree(), global_position)
	is_floating = false
	if water_world == null or rail_length <= 0.0:
		return distance
	var tuning: WaterTuning = water_world.water_tuning
	var rail_axis: Vector2 = travel / rail_length
	# Where the leaf's top would be, in the water's coordinates (not rounded).
	var top: Vector2 = water_world.to_local(get_parent().to_global(home_position + rail_axis * distance))
	var found: Array = water_world.find_body_under(top - Vector2(0.0, SURFACE_THICKNESS))
	if found.is_empty() or (found[0] as WaterBody).depth[found[1]] <= 1.0:
		return distance
	var body: WaterBody = found[0]
	var float_y: float = body.get_drawn_surface_y(found[1]) - tuning.leaf_platform_float_lift
	# Above the water (by more than a wave's dip): the water doesn't touch it.
	if top.y < float_y - SURFACE_THICKNESS * 0.5:
		return distance
	is_floating = true
	# Float: move along the rail until the top is at float_y (only a rail that goes
	# up or down can lift it), no faster than leaf_platform_float_speed.
	if absf(rail_axis.y) > 0.05:
		var along_change: float = (float_y - top.y) / rail_axis.y
		var max_change: float = tuning.leaf_platform_float_speed * delta / absf(rail_axis.y)
		distance += clampf(along_change, -max_change, max_change)
	# The current: along the rail, by the rail's sideways part.
	var water_speed: float = water_world.get_water_velocity_at(Vector2(top.x, float_y + tuning.leaf_platform_float_lift + 0.5))
	distance += water_speed * tuning.leaf_platform_current_share * rail_axis.x * delta
	return clampf(distance, 0.0, rail_length)


## The Pushable contract: any gust (direction and strength don't matter) sends it
## to the far end again, even if it's partway home.
func receive_gust(_direction: Vector2, _strength: float) -> void:
	if burn_state == BurnState.GONE:
		return
	is_driven = true
	hover_remaining = 0.0


# --- The Flammable contract (Stage F8) -----------------------------------------------

func ignite(_source: Node) -> void:
	if burn_state != BurnState.LEAF:
		return
	burn_state = BurnState.BURNING
	burn_remaining = fire_tuning.leaf_platform_burn_time
	for flame: FlameTongue in flames:
		flame.visible = true
	EmberEmitter.burst(get_parent(), global_position, 6, Vector2.UP, 160.0, 50.0)
	FX.play_sfx(&"fire_ignite")


func is_burning() -> bool:
	return burn_state == BurnState.BURNING


## Gusts against fire come in Stage F10.
func snuff() -> void:
	pass


## The leaf, in world coordinates (top surface down to its belly).
func get_fire_rect() -> Rect2:
	if burn_state == BurnState.GONE:
		return Rect2()
	return Rect2(global_position + Vector2(-leaf_width / 2.0, -1.0), Vector2(leaf_width, 6.0))


## Burnt away: ash falls, and the leaf is gone (no collision) until death or R.
func _crumble() -> void:
	burn_state = BurnState.GONE
	for flame: FlameTongue in flames:
		flame.visible = false
	# Deferred: physics shapes can't change in the middle of a physics step.
	surface.set_deferred("disabled", true)
	AshFall.spawn(get_parent(), global_position + Vector2(0.0, 2.0), 16, Vector2(leaf_width, 4.0), 0.3)
	PebbleField.leave_ash(get_tree(), global_position, 4, Vector2(leaf_width, 2.0), ASH_FLAKE_COLORS)
	SmokePuff.spawn(get_parent(), global_position, 3)
	queue_redraw()


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	if burn_state != BurnState.LEAF:
		burn_state = BurnState.LEAF
		for flame: FlameTongue in flames:
			flame.visible = false
		surface.set_deferred("disabled", false)
	is_driven = false
	hover_remaining = 0.0
	distance_along_rail = 0.0
	pinwheel_speed = 0.0
	position = home_position
	queue_redraw()


func _resize_surface() -> void:
	if surface == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(surface.shape as RectangleShape2D).size = Vector2(leaf_width, SURFACE_THICKNESS)
	# Origin is the top surface; the solid part hangs below it.
	surface.position = Vector2(0.0, SURFACE_THICKNESS / 2.0)


func _draw() -> void:
	# The rail first, so it's behind the leaf. It runs through the pinwheel hub.
	# In the editor home is simply "here"; in game, home is where we started.
	var home_local: Vector2 = Vector2.ZERO
	if not Engine.is_editor_hint():
		home_local = home_position - position
	RailTrack.draw(self, home_local + PINWHEEL_HUB, home_local + travel + PINWHEEL_HUB)
	if burn_state == BurnState.GONE:
		return  # only the rail is left

	# Burning: the leaf shrinks in from both tips as it curls, and blackens.
	var burnt_amount: float = 0.0
	if burn_state == BurnState.BURNING:
		burnt_amount = 1.0 - clampf(burn_remaining / maxf(fire_tuning.leaf_platform_burn_time, 0.01), 0.0, 1.0)
	var half_width: float = leaf_width / 2.0 * (1.0 - burnt_amount * 0.4)
	# A leaf shape: flat top (the walkable surface), curved belly underneath.
	var leaf: PackedVector2Array = PackedVector2Array([
		Vector2(-half_width, 1.0), Vector2(-half_width * 0.6, 0.0),
		Vector2(half_width * 0.6, 0.0), Vector2(half_width, 1.0),
		Vector2(half_width * 0.6, 3.5), Vector2(0.0, 4.5), Vector2(-half_width * 0.6, 3.5),
	])
	var is_away: bool = distance_along_rail > 0.0 or is_driven
	var leaf_color: Color = LEAF_AWAY_COLOR if is_away else LEAF_COLOR
	draw_colored_polygon(leaf, leaf_color.lerp(CHARRED_COLOR, burnt_amount))
	draw_line(Vector2(-half_width + 2.0, 2.0), Vector2(half_width - 2.0, 2.0),
		VEIN_COLOR.lerp(Color("#E8431A"), burnt_amount), 1.0)
	# A little stem off the right tip.
	draw_line(Vector2(half_width, 1.0), Vector2(half_width + 3.0, -1.0), VEIN_COLOR, 1.0)

	# Pinwheel: a short stalk from the belly, and 4 bent blades (each a triangle
	# whose tip is swept sideways, which is what makes it read as a PINwheel).
	draw_line(Vector2(0.0, 4.0), PINWHEEL_HUB, VEIN_COLOR, 1.0)
	for blade_index: int in 4:
		var blade_rotation: Transform2D = Transform2D(pinwheel_angle + TAU * blade_index / 4.0, PINWHEEL_HUB)
		draw_colored_polygon(blade_rotation * PackedVector2Array([
			Vector2.ZERO,
			Vector2(PINWHEEL_BLADE_LENGTH, 0.0),
			Vector2(PINWHEEL_BLADE_LENGTH * 0.7, PINWHEEL_BLADE_LENGTH * 0.7),
		]), PINWHEEL_COLOR)

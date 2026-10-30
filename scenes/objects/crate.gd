@tool
class_name Crate
extends CharacterBody2D
## Crate (GAME_DESIGN.md §6): a heavy box the gust can shove around. It slides along
## the ground and slows to a stop, falls with gravity, can rest on pressure plates,
## and the player can stand on it.
##
## Place the node ON the floor, at the bottom-center of the crate (same as the
## player: origin at the feet).
##
## Why a CharacterBody2D and not a RigidBody2D? A rigid body would tumble, bounce
## and spin, which is hard to aim at a plate. With our own few lines of movement
## code, a gust of the same strength always slides it the same distance
## (distance = speed² / (2 × ground_friction): 160² / 640 = 40 px).
##
## The player can't push it by walking into it: the gust is the only way to move
## it (pillar 2: the air verbs ARE the puzzle tools).
##
## Groups (tags other code looks for):
##   - "pushable"        (Pushable.GROUP): the gust finds it and calls receive_gust()
##   - "heavy"           (PressurePlate.HEAVY_GROUP): it presses plates
##   - "room_resettable" (Room.RESETTABLE_GROUP): it returns to its start when the
##                       player dies or restarts the room
##
## Physics layers: it IS on layer 1 ("world"), so the player stands on it and doors
## and plates see it, and also on layer 4 ("pushable"). It collides with the world
## and with the player (so a sliding crate stops against you, it doesn't overlap you).
##
## Fire (Fire_bending.md §6.2, Stage F8): crates are FLAMMABLE (group "flammable",
## the contract in scenes/objects/fire/flammable.gd). Fireballs hit its body (it's on
## layer 1, which fireballs already hit), the jet and splashes touch its fire rect.
## Lit, it burns for `crate_burn_time` (FireTuning, 1.5 s): a FireHazard over it kills
## on touch, and it lights grass and leaves under and beside it. A gust still slides
## it, so a burning crate can carry fire across a grass floor. Then it COLLAPSES into
## a little ash heap: no collision, it stops being heavy (a plate under it lifts),
## and it is gone until death or R.
##
## Hung crates: `hung_from` lists Vines (Switches) holding it up. Held by two or
## more intact vines, it hangs still: no gravity, gusts don't move it. Held by ONE
## (after the L9 play-test), it's a real PENDULUM: its center moves on a circle
## round the vine's anchor (radius: the vine plus half the crate), and it tilts so
## its top always points at the anchor. The swing is worked out as an angle
## (`swing_angle`, 0 = straight down) and its speed: each frame gravity speeds it
## toward the bottom by g / radius x sin(angle). Gusts push it along the circle. If
## the swing runs into something (a wall, the ground, the player), it bounces back
## with `swing_bounce` of its speed. The vine coils round its top (a knot).
## When the last vine burns through, it falls, keeping its swing speed, and turns
## upright again as it falls. Wired by signal, like a door.
## Falling or flung through the air (not sliding on the ground), it bounces a
## little off walls instead of stopping dead (`air_wall_bounce`).
##
## METAL crates (`is_metal`, after the L10 play-test): steel gray with rivets. They
## don't burn (not in the flammable group, ignite() does nothing) and are heavier:
## gusts, a rising column's throw and swing pushes move them `metal_push_factor` as
## much. Gravity is the same (everything falls alike).
##
## WATER (Stage W1, Water_bending.md §8.5): wooden crates FLOAT. Each frame the
## crate asks its room's WaterWorld how much of its box is under water (0..1). The
## water lifts it with `buoyancy` (WaterTuning) times that share of gravity, so with
## buoyancy 2 it settles half under. Water drag slows it (no bouncing out again),
## and it slides down the slope of a passing wave, so it bobs and drifts on waves.
## CURRENTS (Stage W7b): the drag pulls it toward the WATER's speed, not toward a
## stop (WaterWorld.get_water_velocity_at, in the middle of its wet part), and while
## afloat its air friction slows it toward that speed too: it rides a stream. A
## waterfall falling on it pushes it down (WaterWorld.get_falling_push).
##
## ICE SLOPES (Stage W6, Water_bending.md §7.2): standing on ice steep enough to slide
## on, it slides down (IceSlope.slide_object), so a slide can deliver a crate or an
## ice block onto a pressure plate.
## Falling in pushes a wave (WaterWorld.push_at). Metal crates sink: drag only.

## Brown, per the color key (GAME_DESIGN.md §2), with darker planks.
const CRATE_COLOR: Color = Color(0.6, 0.38, 0.2)
const PLANK_COLOR: Color = Color(0.4, 0.24, 0.12)
## Metal crates: steel gray, a darker frame and lighter rivets.
const METAL_COLOR: Color = Color(0.5, 0.53, 0.57)
const METAL_FRAME_COLOR: Color = Color(0.3, 0.32, 0.36)
const METAL_RIVET_COLOR: Color = Color(0.75, 0.78, 0.82)
## A burning crate chars toward this (fully at the end of its burn).
const CHARRED_COLOR: Color = Color(0.13, 0.09, 0.08)
## The collapsed crate: a low heap of ash (Fire_bending.md §9.1), drawn only.
const ASH_HEAP_COLOR: Color = Color("#4A4545")
const ASH_HEAP_FLECK_COLOR: Color = Color("#7A7470")
const ASH_FLAKE_COLORS: Array[Color] = [Color("#4A4545"), Color("#7A7470"), Color("#5E5858")]
## A burning crate looks for grass and leaves to light this often, seconds.
const IGNITE_INTERVAL: float = 0.15
## Flame tongues along the top of a burning crate, and the middle ones' length, px.
const FLAME_COUNT: int = 4
const FLAME_LENGTH: float = 10.0
## The knot: the vine coils round the crate's top this thick, px.
const KNOT_THICKNESS: float = 4.0

enum BurnState { SOLID, BURNING, GONE }

## Crate size, px. 16x16 = 2x2 tiles.
@export var crate_size: Vector2 = Vector2(16, 16):
	set(value):
		crate_size = value
		_resize_hitbox()
		queue_redraw()
## Same gravity and max fall speed as the player (GAME_DESIGN.md §4), so it falls
## the way you'd expect next to you.
@export var gravity: float = 900.0
@export var max_fall_speed: float = 300.0
## How fast a sliding crate slows down on the ground / in the air, px/s².
@export var ground_friction: float = 320.0
@export var air_friction: float = 60.0
## Fraction of the gust's push turned into upward speed when gusted from below.
## 160 x 0.8 = 128 px/s, a small hop of about 9 px (v² / 2g).
@export var upward_push_multiplier: float = 0.8
## If it falls this far below its start (a pit), it puts itself back.
@export var fall_out_distance: float = 400.0
## Vines holding it up (Stage F8). Empty = it stands on the ground like always.
@export var hung_from: Array[Switch] = []
## Swinging on one vine: the fraction of its speed kept every physics frame, so a
## swing slowly dies down (0.996 at 60 fps keeps about 79% after a second).
@export var swing_damping: float = 0.996
## A metal crate: doesn't burn, and pushes move it less (see the header).
@export var is_metal: bool = false:
	set(value):
		is_metal = value
		queue_redraw()
## How much of a push (gust, column, swing push) a metal crate takes.
@export var metal_push_factor: float = 0.5
## Swinging into something: the fraction of its swing speed it bounces back with.
@export var swing_bounce: float = 0.35
## Off the ground and hitting a wall faster than this, px/s, it bounces back with
## air_wall_bounce of its speed (slow touches just stop, as a gusted slide does).
@export var air_wall_bounce: float = 0.3
@export var air_wall_bounce_min_speed: float = 40.0
## How fast a released crate turns upright again while it falls, radians/s.
@export var upright_turn_speed: float = 8.0

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var burn_state: BurnState = BurnState.SOLID
var burn_remaining: float = 0.0
var ignite_timer: float = 0.0
## Lit by the jet: seconds until it really catches (-1 = not catching).
var catch_remaining: float = -1.0
var fire_hazard: FireHazard
var flames: Array[FlameTongue] = []
## True while a vine in hung_from still holds it.
var is_hanging: bool = false
## Vine -> how far its anchor may be from the crate's top: the distance when placed.
var vine_lengths: Dictionary = {}
## False once it burnt out off the ground: then no ash heap is drawn (see _collapse).
var ash_heap_visible: bool = true
## The pendulum (one vine holds it): the vine, the angle from straight down
## (radians, positive = to the right of the anchor) and its speed (radians/s).
## swing_vine is null while it isn't swinging.
var swing_vine: Vine = null
var swing_angle: float = 0.0
var swing_speed: float = 0.0

## The WaterWorld of its room, looked up on the first physics frame (the room makes
## it in its own _ready, which runs after ours), and how much of the crate was under
## water last frame (a splash when it goes from 0 to more).
var water_world: WaterWorld = null
var has_looked_for_water: bool = false
var submerged_share: float = 0.0
## The water's speed where it floats, px/s (Stage W7b): what friction and the water's
## drag slow it toward while it's in water.
var water_speed_x: float = 0.0

## Where it was placed, in world coordinates. reset() puts it back here.
var start_position: Vector2
var hitbox: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 | 8  # bit values of layer 1 "world" and layer 4 "pushable"
	collision_mask = 1 | 2   # stops against the world and the player
	# A CharacterBody2D standing on another body moves along with it (a moving
	# platform carries what stands on it). It must never ride on the PLAYER, or
	# jumping or swimming up under a crate picks it up and carries it (W1 play-test
	# "I can grab the crate"): the player can't move crates, only the gust can. So
	# every layer but the player's (layer 2, bit value 2) carries it.
	platform_floor_layers = 0xFFFFFFFF & ~2
	hitbox = CollisionShape2D.new()
	hitbox.shape = RectangleShape2D.new()
	add_child(hitbox)
	_resize_hitbox()
	if Engine.is_editor_hint():
		return
	start_position = global_position
	add_to_group(Pushable.GROUP)
	add_to_group(PressurePlate.HEAVY_GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(WaterWorld.SOLID_GROUP)  # loose water bumps into it (get_water_box)
	if not is_metal:
		add_to_group(Flammable.GROUP)  # metal doesn't burn
	_make_fire()
	for vine: Switch in hung_from:
		if vine != null:
			vine.switched.connect(_on_vine_switched)
			vine_lengths[vine] = vine.global_position.distance_to(_get_knot_point())
	is_hanging = _is_held_by_a_vine()


## The flame and its deadly area, off until it burns.
func _make_fire() -> void:
	fire_hazard = FireHazard.new()
	fire_hazard.name = "FireHazard"
	# A bit bigger than the box, flames' feet included: touching a burning crate kills.
	fire_hazard.hazard_size = crate_size + Vector2(2.0, 4.0)
	fire_hazard.position = Vector2(0.0, -crate_size.y / 2.0 - 1.0)
	fire_hazard.active = false
	add_child(fire_hazard)
	var flame_merge: FlameMerge = FlameMerge.make(self)
	for flame_index: int in FLAME_COUNT:
		var flame: FlameTongue = FlameTongue.new()
		var across: float = (flame_index + 0.5) / FLAME_COUNT - 0.5  # -0.375 .. 0.375
		flame.position = Vector2(across * crate_size.x, -crate_size.y + 2.0)
		flame.length = FLAME_LENGTH * (1.0 - absf(across))  # tallest in the middle
		flame.base_width = 5.0
		flame.fan_width = 6.0
		flame.heat = 0.55
		flame.lick_rate = 4.0
		flame.lick_size = 3.0
		flame.lick_speed = 22.0
		# One smoking tongue reads as one column of smoke.
		flame.smoke_rate = 3.0 if flame_index == 1 else 0.0
		flame.z_index = 1
		flame.visible = false
		add_child(flame)
		flame_merge.add_tongue(flame)
		flames.append(flame)


func _is_held_by_a_vine() -> bool:
	for vine: Switch in hung_from:
		if vine != null and not vine.is_on():
			return true
	return false


## The one intact Vine holding it, or null if none or several do (still then).
func _get_single_holding_vine() -> Vine:
	var holding: Vine = null
	for vine_switch: Switch in hung_from:
		var vine: Vine = vine_switch as Vine
		if vine == null or vine.is_on():
			continue
		if holding != null:
			return null  # two hold it: it hangs still
		holding = vine
	return holding


## Where its vines are tied: the knot, half KNOT_THICKNESS down from the middle of
## its top, world coordinates (turned with it while it swings). Each vine's length is
## measured to here, so a vine holding the crate is at full length: taut.
func _get_knot_point() -> Vector2:
	return global_transform * Vector2(0.0, -crate_size.y + KNOT_THICKNESS / 2.0)


## One of our vines burnt through (or grew back on reset).
func _on_vine_switched(_is_now_on: bool) -> void:
	is_hanging = _is_held_by_a_vine()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# The vines' tied ends follow the crate's top, and coil round it there: the knot
	# sits half its thickness into the crate, along the crate's (turned) top edge.
	var knot: Vector2 = _get_knot_point()
	for vine_switch: Switch in hung_from:
		var vine: Vine = vine_switch as Vine
		if vine != null:
			vine.tie_to(knot, global_transform.x, KNOT_THICKNESS)
	if burn_state == BurnState.GONE:
		return
	if burn_state == BurnState.SOLID and catch_remaining >= 0.0:
		catch_remaining -= delta
		queue_redraw()  # its edges glow brighter as it's about to catch
		if catch_remaining <= 0.0:
			_catch_fire()
	if burn_state == BurnState.BURNING:
		_advance_burn(delta)
		if burn_state == BurnState.GONE:
			return
	var holding_vine: Vine = _get_single_holding_vine() if is_hanging else null
	if holding_vine != swing_vine:
		_change_swing(holding_vine)
	if swing_vine != null:
		_swing(delta)
		return
	if is_hanging:
		velocity = Vector2.ZERO  # several vines: it hangs still
		return
	# Let go (or never hung): back upright while it falls.
	rotation = move_toward(rotation, 0.0, upright_turn_speed * delta)
	var was_on_floor: bool = is_on_floor()
	var lift: float = _float_in_water(delta)
	# In water, gravity minus the water's lift; that can be negative (it rises, even
	# off a pool's floor).
	var net_gravity: float = gravity - lift
	# On an ice slope (Stage W6) it slides down it instead (IceSlope.slide_object
	# sets the velocity along the slope).
	var is_sliding_on_ice: bool = lift <= 0.0 and can_slide_on_ice() and IceSlope.slide_object(self, gravity, delta)
	if not is_sliding_on_ice:
		if not was_on_floor or net_gravity < 0.0:
			velocity.y = minf(velocity.y + net_gravity * delta, max_fall_speed)
		# Friction: slide toward a stop, faster on the ground than in the air.
		var friction: float = ground_friction if was_on_floor else air_friction
		# Afloat, it settles at the water's speed (a stream carries it), not at rest.
		var rest_speed: float = water_speed_x if submerged_share > 0.0 and not was_on_floor else 0.0
		velocity.x = move_toward(velocity.x, rest_speed, friction * delta)
	var speed_before: Vector2 = velocity
	# move_and_slide() also zeroes the part of velocity that runs into a wall,
	# so a crate shoved into a wall just stops...
	move_and_slide()
	# ...unless it flew into it: then it bounces back a little.
	if is_on_wall() and not was_on_floor and absf(speed_before.x) > air_wall_bounce_min_speed:
		velocity.x = -speed_before.x * air_wall_bounce
	if global_position.y > start_position.y + fall_out_distance:
		reset()


## Does it slide down ice slopes (Stage W6)? Crates do; IceBlock says no for long
## pieces (they lie where they land).
func can_slide_on_ice() -> bool:
	return true


## The box loose water bumps into (WaterWorld.SOLID_GROUP), global. None once it
## has burnt away.
func get_water_box() -> Rect2:
	if burn_state == BurnState.GONE:
		return Rect2()
	return Rect2(global_position - Vector2(crate_size.x / 2.0, crate_size.y), crate_size)


## Water (see the header): how much of the crate is under water, the drag and the
## drift down a wave's slope. Returns the water's upward push this frame, px/s².
func _float_in_water(delta: float) -> float:
	if not has_looked_for_water:
		has_looked_for_water = true
		var room: Room = Room.find_room_of(self)
		if room != null:
			water_world = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	if water_world == null:
		return 0.0
	var box: Rect2 = Rect2(global_position - Vector2(crate_size.x / 2.0, crate_size.y), crate_size)
	var share: float = water_world.get_submerged_share(box)
	var water_tuning: WaterTuning = water_world.water_tuning
	# A waterfall falling on it pushes it down (Stage W7b), in water or out.
	var fall_push: float = water_world.get_falling_push(box)
	if fall_push > 0.0:
		velocity.y = minf(velocity.y + fall_push * water_tuning.waterfall_grip * delta, max_fall_speed)
	if share > 0.0 and submerged_share <= 0.0:
		water_world.push_at(Vector2(global_position.x, box.end.y), velocity * water_tuning.entry_splash_strength, crate_size.x)
	submerged_share = share
	if share <= 0.0:
		water_speed_x = 0.0
		return 0.0
	# The water's speed in the middle of the crate's wet part (Stage W7b).
	var wet_middle: Vector2 = Vector2(global_position.x, box.end.y - share * box.size.y * 0.5)
	water_speed_x = water_world.get_water_velocity_at(water_world.to_local(wet_middle))
	# Drag: sideways toward the water's speed (a current carries it), up and down
	# toward rest (no bouncing out again).
	var drag_keep: float = maxf(0.0, 1.0 - _get_water_drag() * share * delta)
	velocity.x = water_speed_x + (velocity.x - water_speed_x) * drag_keep
	velocity.y *= drag_keep
	if is_metal:
		return 0.0  # steel sinks: the water only slows it
	if not is_on_floor():
		velocity.x += water_world.get_surface_slope_at(Vector2(global_position.x, box.position.y)) \
			* water_tuning.wave_slope_push * delta
	return gravity * _get_buoyancy() * share


## How strongly water lifts it (2 = it floats half under; an ice raft overrides it:
## it floats higher, after the W7a play-test).
func _get_buoyancy() -> float:
	return water_world.water_tuning.buoyancy


## How much of its speed the water takes per second at full depth (an ice raft
## overrides it: it drifts far, Stage W7a).
func _get_water_drag() -> float:
	return water_world.water_tuning.water_drag


## Starts swinging on `vine` (or stops, null). Starting: the angle comes from where
## its top is now (it tilts to point at the anchor, turning round its top), and any
## speed it had becomes swing speed. Stopping (the vine snapped): the swing speed
## becomes a velocity along the circle, so it flies off the way it was going.
func _change_swing(vine: Vine) -> void:
	if vine == null:
		if swing_vine != null:
			velocity = _get_swing_tangent() * swing_speed * _get_swing_radius()
		swing_vine = null
		return
	var from_anchor: Vector2 = _get_knot_point() - vine.global_position
	swing_vine = vine
	# The angle from straight down: atan2(x, y), so a point to the right is positive.
	swing_angle = atan2(from_anchor.x, from_anchor.y)
	swing_speed = velocity.dot(_get_swing_tangent()) / _get_swing_radius()
	global_transform = _get_swing_transform(swing_angle)


## Anchor to the crate's center, px: the vine's length plus knot to center.
func _get_swing_radius() -> float:
	return maxf(float(vine_lengths.get(swing_vine, 0.0)) + crate_size.y / 2.0 - KNOT_THICKNESS / 2.0, 1.0)


## The direction the center moves in when the angle grows (along the circle).
func _get_swing_tangent() -> Vector2:
	return Vector2(cos(swing_angle), -sin(swing_angle))


## The crate on the circle at `angle`: its center there, turned so its top points at
## the anchor (rotation = -angle). The feet (the origin) are half the crate below the
## center, in the turned frame.
func _get_swing_transform(angle: float) -> Transform2D:
	var center: Vector2 = swing_vine.global_position + Vector2(sin(angle), cos(angle)) * _get_swing_radius()
	var turned: Transform2D = Transform2D(-angle, Vector2.ZERO)
	return Transform2D(-angle, center + turned * Vector2(0.0, crate_size.y / 2.0))


## One frame of the pendulum. It moves with move_and_collide toward its next spot on
## the circle: if something is in the way it stops there and bounces back.
func _swing(delta: float) -> void:
	swing_speed -= gravity / _get_swing_radius() * sin(swing_angle) * delta
	swing_speed *= swing_damping
	var next_angle: float = swing_angle + swing_speed * delta
	var target: Transform2D = _get_swing_transform(next_angle)
	rotation = -next_angle  # turn first (a small turn, not checked), then move
	var collision: KinematicCollision2D = move_and_collide(target.origin - global_position)
	if collision == null:
		swing_angle = next_angle
		return
	# Blocked: bounce back, staying on the circle where it stopped.
	swing_speed = -swing_speed * swing_bounce
	var center: Vector2 = global_transform * Vector2(0.0, -crate_size.y / 2.0)
	var from_anchor: Vector2 = center - swing_vine.global_position
	swing_angle = atan2(from_anchor.x, from_anchor.y)
	rotation = -swing_angle


## The Pushable contract: called by the gust when it hits us.
## Sideways: sets the slide speed (replacing it, so a gust can also stop or reverse
## a moving crate). Upward: a small hop. Downward: slams it down if it's in the air.
func receive_gust(direction: Vector2, strength: float) -> void:
	# Hanging still from several vines: gusts can't move it.
	if (is_hanging and _get_single_holding_vine() == null) or burn_state == BurnState.GONE:
		return
	strength *= _get_push_factor()
	if swing_vine != null:
		# On one vine: the part of the push along the circle swings it.
		swing_speed += direction.dot(_get_swing_tangent()) * strength / _get_swing_radius()
		return
	velocity.x = direction.x * strength
	if direction.y < -0.1:
		# minf because "up" is negative y: keep whichever upward speed is bigger.
		velocity.y = minf(velocity.y, direction.y * strength * upward_push_multiplier)
	elif direction.y > 0.1:
		velocity.y = maxf(velocity.y, direction.y * strength)


## The Pushable contract's Earth extra: a rising Earth Column threw us. Take its
## velocity as is (a spring throws everything the same way). No receive_crush():
## a crate is never crushed, the column stops short of it instead.
func receive_launch(launch_velocity: Vector2) -> void:
	if burn_state == BurnState.GONE:
		return
	velocity = launch_velocity * _get_push_factor()


## 1 for wood; metal_push_factor for a heavier metal crate.
func _get_push_factor() -> float:
	return metal_push_factor if is_metal else 1.0


# --- The Flammable contract (Stage F8) -----------------------------------------------

## Catches fire (called again and again while a flame touches: only the first call
## does anything). The jet's flame catches crate_jet_catch_delay later (it smokes and
## glows meanwhile), so jetting up off a crate doesn't kill you (F8 play-test); any
## other fire lights it at once, even one that's already catching.
func ignite(source: Node) -> void:
	if burn_state != BurnState.SOLID or is_metal:
		return
	if source is FlameJetAbility:
		if catch_remaining < 0.0:
			catch_remaining = fire_tuning.crate_jet_catch_delay
			SmokePuff.spawn(get_parent(), global_position + Vector2(0.0, -crate_size.y), 2)
		return
	_catch_fire()


func _catch_fire() -> void:
	catch_remaining = -1.0
	burn_state = BurnState.BURNING
	burn_remaining = fire_tuning.crate_burn_time
	ignite_timer = 0.0
	fire_hazard.active = true
	for flame: FlameTongue in flames:
		flame.visible = true
	var center: Vector2 = global_position + Vector2(0.0, -crate_size.y / 2.0)
	FireRing.spawn(get_parent(), center, 12.0, 0.2)
	EmberEmitter.burst(get_parent(), center, 8, Vector2.UP, 160.0, 60.0)
	FX.play_sfx(&"fire_ignite")


func is_burning() -> bool:
	return burn_state == BurnState.BURNING


## A gust chars a burning crate from Stage F10 (§5.4); nothing yet.
func snuff() -> void:
	pass


## The box, in world coordinates. Nothing catches once it's gone.
func get_fire_rect() -> Rect2:
	if burn_state == BurnState.GONE:
		return Rect2()
	return Rect2(global_position + Vector2(-crate_size.x / 2.0, -crate_size.y), crate_size)


func _advance_burn(delta: float) -> void:
	burn_remaining -= delta
	ignite_timer -= delta
	if ignite_timer <= 0.0:
		ignite_timer = IGNITE_INTERVAL
		# The grass under it and anything flammable touching it (but not itself).
		Flammable.ignite_in_rect(get_tree(), get_fire_rect().grow(fire_tuning.crate_ignite_reach),
			self, self, fire_tuning.crate_ignite_reach)
	queue_redraw()  # it chars as it burns
	if burn_remaining <= 0.0:
		_collapse()


## Burnt out: a burst of ash and embers, and the crate is gone. A heap of ash stays
## drawn where it was, but it has no collision and presses nothing.
func _collapse() -> void:
	burn_state = BurnState.GONE
	# Burnt out hanging or in mid-air: its ash just falls (AshFall below), no heap
	# is left floating where it was.
	ash_heap_visible = is_on_floor() and not is_hanging
	rotation = 0.0
	fire_hazard.active = false
	for flame: FlameTongue in flames:
		flame.visible = false
	velocity = Vector2.ZERO
	# Disabling the shape takes it out of plates' sensors and the player's way. It's a
	# deferred set: physics shapes can't change in the middle of a physics step.
	hitbox.set_deferred("disabled", true)
	remove_from_group(PressurePlate.HEAVY_GROUP)
	var center: Vector2 = global_position + Vector2(0.0, -crate_size.y / 2.0)
	AshFall.spawn(get_parent(), center, 24, crate_size, 0.35)
	PebbleField.leave_ash(get_tree(), center, 6, crate_size, ASH_FLAKE_COLORS)
	SmokePuff.spawn(get_parent(), center, 5)
	EmberEmitter.burst(get_parent(), center, 6, Vector2.UP, 120.0, 40.0)
	FX.shake(1.5, 0.12)
	FX.play_sfx(&"crate_collapse")
	queue_redraw()


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	global_position = start_position
	rotation = 0.0
	ash_heap_visible = true
	velocity = Vector2.ZERO
	swing_vine = null  # its vines grow back below: the next frame starts the swing again
	swing_speed = 0.0
	catch_remaining = -1.0
	if burn_state != BurnState.SOLID:
		burn_state = BurnState.SOLID
		fire_hazard.active = false
		for flame: FlameTongue in flames:
			flame.visible = false
		hitbox.set_deferred("disabled", false)
		add_to_group(PressurePlate.HEAVY_GROUP)
	# Its vines grow back on reset too (each resets itself), so it hangs again.
	is_hanging = not hung_from.is_empty()
	queue_redraw()


func _resize_hitbox() -> void:
	if hitbox == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(hitbox.shape as RectangleShape2D).size = crate_size
	# Origin is at the bottom-center, and a shape is positioned by its center.
	hitbox.position = Vector2(0.0, -crate_size.y / 2.0)


func _draw() -> void:
	if burn_state == BurnState.GONE:
		if not ash_heap_visible:
			return
		# A low heap of ash where it collapsed.
		var half: float = crate_size.x / 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(-half + 1.0, 0.0), Vector2(-half * 0.4, -3.0),
			Vector2(half * 0.3, -3.5), Vector2(half - 1.0, 0.0)]), ASH_HEAP_COLOR)
		draw_rect(Rect2(-2.0, -3.0, 1.0, 1.0), ASH_HEAP_FLECK_COLOR)
		draw_rect(Rect2(3.0, -2.0, 1.0, 1.0), ASH_HEAP_FLECK_COLOR)
		return
	# Chars from brown to black over its burn, its planks glowing red.
	var char_amount: float = 0.0
	if burn_state == BurnState.BURNING:
		char_amount = 1.0 - clampf(burn_remaining / maxf(fire_tuning.crate_burn_time, 0.01), 0.0, 1.0)
	elif catch_remaining >= 0.0:
		# Catching from the jet: the planks start to glow before the flames come.
		char_amount = 0.3 * (1.0 - catch_remaining / maxf(fire_tuning.crate_jet_catch_delay, 0.01))
	var box: Rect2 = Rect2(-crate_size.x / 2.0, -crate_size.y, crate_size.x, crate_size.y)
	if is_metal:
		# Steel: a plate, a frame, a cross brace and a rivet in each corner.
		draw_rect(box, METAL_COLOR)
		draw_rect(box.grow(-0.5), METAL_FRAME_COLOR, false, 1.0)
		draw_line(box.position + Vector2(1.0, 1.0), box.end - Vector2(1.0, 1.0), METAL_FRAME_COLOR, 1.0)
		draw_line(Vector2(box.end.x - 1.0, box.position.y + 1.0), Vector2(box.position.x + 1.0, box.end.y - 1.0), METAL_FRAME_COLOR, 1.0)
		for corner: Vector2 in [box.position + Vector2(2, 2), Vector2(box.end.x - 3, box.position.y + 2),
				Vector2(box.position.x + 2, box.end.y - 3), box.end - Vector2(3, 3)]:
			draw_rect(Rect2(corner, Vector2.ONE), METAL_RIVET_COLOR)
		return
	draw_rect(box, CRATE_COLOR.lerp(CHARRED_COLOR, char_amount))
	# Outline plus a diagonal brace: reads as "crate" even as a placeholder.
	var plank_color: Color = PLANK_COLOR.lerp(Color("#E8431A"), char_amount * 0.7)
	draw_rect(box.grow(-0.5), plank_color, false, 1.0)
	draw_line(box.position + Vector2(1.0, 1.0), box.end - Vector2(1.0, 1.0), plank_color, 1.0)

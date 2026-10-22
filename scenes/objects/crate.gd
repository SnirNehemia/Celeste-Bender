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
## Hung crates: `hung_from` lists Vines (Switches) holding it up. While any of them
## is intact (off), it hangs still: no gravity, gusts don't move it. When one burns
## through, it falls. Wired by signal, like a door.

## Brown, per the color key (GAME_DESIGN.md §2), with darker planks.
const CRATE_COLOR: Color = Color(0.6, 0.38, 0.2)
const PLANK_COLOR: Color = Color(0.4, 0.24, 0.12)
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

## Where it was placed, in world coordinates. reset() puts it back here.
var start_position: Vector2
var hitbox: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 | 8  # bit values of layer 1 "world" and layer 4 "pushable"
	collision_mask = 1 | 2   # stops against the world and the player
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
	add_to_group(Flammable.GROUP)
	_make_fire()
	for vine: Switch in hung_from:
		if vine != null:
			vine.switched.connect(_on_vine_switched)
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


## One of our vines burnt through (or grew back on reset).
func _on_vine_switched(_is_now_on: bool) -> void:
	is_hanging = _is_held_by_a_vine()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# The vines' tied ends follow the crate's top (no coils: thickness 0).
	for vine_switch: Switch in hung_from:
		var vine: Vine = vine_switch as Vine
		if vine != null:
			vine.tie_to(global_position + Vector2(0.0, -crate_size.y), Vector2.RIGHT, 0.0)
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
	if is_hanging:
		velocity = Vector2.ZERO
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	# Friction: slide toward a stop, faster on the ground than in the air.
	var friction: float = ground_friction if is_on_floor() else air_friction
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	# move_and_slide() also zeroes the part of velocity that runs into a wall,
	# so a crate shoved into a wall just stops.
	move_and_slide()
	if global_position.y > start_position.y + fall_out_distance:
		reset()


## The Pushable contract: called by the gust (and the dash wake) when it hits us.
## Sideways: sets the slide speed (replacing it, so a gust can also stop or reverse
## a moving crate). Upward: a small hop. Downward: slams it down if it's in the air.
func receive_gust(direction: Vector2, strength: float) -> void:
	if is_hanging or burn_state == BurnState.GONE:
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
	velocity = launch_velocity


# --- The Flammable contract (Stage F8) -----------------------------------------------

## Catches fire (called again and again while a flame touches: only the first call
## does anything). The jet's flame catches crate_jet_catch_delay later (it smokes and
## glows meanwhile), so jetting up off a crate doesn't kill you (F8 play-test); any
## other fire lights it at once, even one that's already catching.
func ignite(source: Node) -> void:
	if burn_state != BurnState.SOLID:
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
	velocity = Vector2.ZERO
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
	draw_rect(box, CRATE_COLOR.lerp(CHARRED_COLOR, char_amount))
	# Outline plus a diagonal brace: reads as "crate" even as a placeholder.
	var plank_color: Color = PLANK_COLOR.lerp(Color("#E8431A"), char_amount * 0.7)
	draw_rect(box.grow(-0.5), plank_color, false, 1.0)
	draw_line(box.position + Vector2(1.0, 1.0), box.end - Vector2(1.0, 1.0), plank_color, 1.0)

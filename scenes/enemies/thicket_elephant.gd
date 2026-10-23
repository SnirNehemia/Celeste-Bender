@tool
class_name ThicketElephant
extends AnimatableBody2D
## Thicket elephant (Fire_bending.md §7.2, Stage F11b): the heavy leafling. A huge,
## slow, blocky creature of STONE (96x60, a walking heap of boulders) with three
## burnable parts, each a "spot" you must burn from its own side:
##   TRUNK  thicket, at the front (dangerous: you're in its path)
##   BACK   grass growing on top (you have to get up there: a gust, a wall, the jet
##          or the snake; then a fireball down, or the jet over it)
##   TAIL   a vine at the back (reach it between whips)
## A burnt spot stays burnt until R. All three burnt: it crumbles into a big heap of ash.
##
## Place the node ON the floor, at the bottom-center of the body (origin at the feet).
##
## What it does:
##   WALK     a slow patrol, turning at walls, ledges and its room's edges. It CHARGES
##            whenever it can hit you: you're in front of it, on its level, in range
##            and in clear view (_can_charge_player).
##   REAR     the tell before every charge: it rears up on its hind legs for
##            elephant_rear_time. A burnt trunk makes it rear too.
##   CHARGE   runs at elephant_charge_speed: at you (sight), forward (trunk burnt) or
##            away from the fire (tail burnt, a "bolt", no rear). A charge set off by
##            a burn is elephant_hit_charge_multiplier (2x) faster. It smashes cracked
##            walls, STONE walls (only it can) and thicket in its way, brakes to a stop
##            at ledges, and is stunned by any other wall.
##   STUNNED  ran into a wall: dazed for elephant_wall_stun_time.
##   DEFEATED crumbled to ash. Gone until the room resets.
## Its FRONT (head, tusks, trunk) kills on touch; the rest is safe. Its back is a
## MOVING PLATFORM: ride it over spikes (it walks over them) or up to high diamonds.
## You can stand under its belly, between its legs.
##
## TAIL WHIP (_update_whip): every elephant_whip_interval while it walks, the tail
## WIGGLES, is RAISED high (the tell), then STRIKES down behind it like a whip, with a
## crack at the tip. The strike kills anything it touches: the player, wisps, monkeys
## (an EnemyHit WHIP). When its back catches fire, or someone stands on its BURNT
## back, the raised tail strikes FORWARD over its back instead. A burnt tail can't
## whip.
##
## Other hits (its ElementImmunity table, _make_immunity): fire burns a spot; a big
## rock pushes it back (no stagger) and stops a charge; a gust barely nudges it; small
## rocks bounce off; spikes do nothing; an Earth column or the snake BREAKS on it (it
## joins EnemyHit.BREAKS_EARTH_GROUP, EarthColumn and EarthSnake check that).
##
## Godot concept, AnimatableBody2D: a solid body moved by script (like LeafPlatform).
## With sync_to_physics on (the default), Godot works out its velocity from how its
## position changes, so a player standing on it is carried along: that's the ride.
## It moves only by setting its position in _physics_process. Before each step it
## asks the physics server "how far can I go?" (PhysicsServer2D.body_test_motion,
## _test_motion), so it never enters a wall. (move_and_collide() refuses to run on a
## body synced to physics, even as a test.) Setting a synced body's position only asks
## the physics server to move it, so it keeps its own body_position, moves that, and
## writes it to the node once per frame; reset() switches the sync off to jump home.
##
## Look: flat rectangles on the tile grid, like the wisp (option C, "stepped"). See "Look".
##
## Collision: three symmetric boxes (torso, hind legs, fore legs), mirrored when it
## turns, leaving a gap under its belly. Layer 1 ("world": solid to the player, rocks, wisps),
## layer 4 ("pushable": the gust finds it) and layer 5 ("enemies": columns and snakes
## find it), mask 1.
##
## Contracts: EnemyHit (receive_hit), Pushable (receive_gust), Flammable (ignite_at:
## it burns in parts, like the FireGrid), Room.RESETTABLE_GROUP + reset(), `defeated`.
## Every number that changes the feel is in FireTuning, group "Thicket elephant".

enum State { WALK, REAR, CHARGE, STUNNED, DEFEATED }
enum Spot { TRUNK, BACK, TAIL }
enum SpotState { WHOLE, BURNING, BURNT }
enum Whip { IDLE, WIGGLE, RAISE, STRIKE }

## Emitted once when it crumbles. EnemyGate listens.
signal defeated

## Flat colors (option C, "stepped", see "Look"): stone grays, the enemy-purple eyes,
## moss green for the parts that burn, ember and char for burning.
const STONE_COLOR: Color = Color(0.56, 0.545, 0.51)
const STONE_LIGHT_COLOR: Color = Color(0.66, 0.643, 0.604)
const STONE_DARK_COLOR: Color = Color(0.43, 0.42, 0.39)
const EYE_COLOR: Color = Color(0.69, 0.42, 0.94)
const EYE_WHITE_COLOR: Color = Color(0.96, 0.95, 0.92)
const TUSK_COLOR: Color = Color(0.92, 0.89, 0.82)
const MOSS_COLOR: Color = Color(0.36, 0.58, 0.2)
const EMBER_COLOR: Color = Color(0.85, 0.3, 0.07)
const CHAR_COLOR: Color = Color(0.1, 0.07, 0.05)
const ASH_FLAKE_COLORS: Array[Color] = [Color("#4A4545"), Color("#7A7470"), Color("#5E5858")]
const STONE_PEBBLE_COLORS: Array[Color] = [Color(0.5, 0.5, 0.47), Color(0.36, 0.36, 0.34), Color(0.66, 0.66, 0.62)]
const DIZZY_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)

## Its size, px (origin at the bottom-center).
const BODY_SIZE: Vector2 = Vector2(96, 60)
## Collision boxes, in drawing coordinates (facing right, origin at the feet): the
## SAME rects the body is drawn with (see "Look"), so what you see is what you bump
## into and stand on. Every row is SYMMETRIC (a mirror image left to right): when it
## turns at a wall, a low step or a ledge, the side that now faces it reaches exactly
## as far as the side that touched it, so it never turns into it. (Uneven boxes made
## it turn back and forth on the spot.) The art is drawn to fit: the body + head row
## is -48..48, the belly -40..40 (a rounded rump below the tail, the trunk in front).
## Its back: the moss strip at -58, 60 px up counting the tufts.
const BACK_TOP_RECT: Rect2 = Rect2(-24.0, -58.0, 48.0, 10.0)
const BODY_ROW_RECT: Rect2 = Rect2(-48.0, -48.0, 96.0, 24.0)
const BELLY_RECT: Rect2 = Rect2(-40.0, -24.0, 80.0, 8.0)
## Legs: hip x of each (hind far, hind near, fore far, fore near; symmetric), where
## they meet the body, and their size.
const LEG_HIPS: Array[float] = [-36.0, -24.0, 24.0, 36.0]
const LEG_TOP: float = -16.0
const LEG_SIZE: Vector2 = Vector2(8, 16)
const SHAPE_RECTS: Array[Rect2] = [BACK_TOP_RECT, BODY_ROW_RECT, BELLY_RECT,
	Rect2(-40.0, -16.0, 8.0, 16.0), Rect2(-28.0, -16.0, 8.0, 16.0), Rect2(20.0, -16.0, 8.0, 16.0), Rect2(32.0, -16.0, 8.0, 16.0)]
## The outer edge of its front feet (for ledges) and the box ahead of it that a charge
## smashes through.
const FRONT_FOOT_X: float = 40.0
const SMASH_RECT: Rect2 = Rect2(48.0, -56.0, 8.0, 54.0)
## The deadly front is exactly what's drawn there: the head's front face (1 px out, so
## touching counts; its top 2 px left out, so standing on the head is safe), the tusk
## and the trunk (both 1 px out too). See _get_front_kill_rects().
const HEAD_KILL_RECT: Rect2 = Rect2(40.0, -46.0, 9.0, 22.0)
## Each spot's area (the tail's follows its rope).
const TRUNK_RECT: Rect2 = Rect2(42.0, -26.0, 20.0, 26.0)
const BACK_RECT: Rect2 = Rect2(-26.0, -64.0, 52.0, 10.0)
## Where its eye looks from (for seeing the player).
const EYE_POINT: Vector2 = Vector2(42.0, -41.0)
## The tail rope.
const TAIL_ROOT: Vector2 = Vector2(-48.0, -36.0)
const TAIL_POINT_COUNT: int = 15
const TAIL_SEGMENT: float = 5.0
## Tail pose angles, radians from "straight back" (positive = down, negative = up and
## on round to forward over its back).
const TAIL_HANG_ANGLE: float = 0.45
const TAIL_RAISED_ANGLE: float = -1.35
const TAIL_STRIKE_BEHIND_ANGLE: float = 1.45
const TAIL_STRIKE_BACK_ANGLE: float = -2.95
## Flames per spot while it burns (the tail's ride these rope points).
const TRUNK_FLAMES: Array[Vector2] = [Vector2(48, -20), Vector2(48, -10), Vector2(54, -4)]
const BACK_FLAMES: Array[Vector2] = [Vector2(-18, -58), Vector2(-6, -58), Vector2(6, -58), Vector2(18, -58)]
const TAIL_FLAME_POINTS: Array[int] = [4, 8, 12]
## A burning spot lights flammables touching it this often, seconds, reaching px.
const SPOT_IGNITE_INTERVAL: float = 0.15
const SPOT_IGNITE_REACH: float = 3.0
## A burning back only kills after this long: time to jump off.
const BACK_HAZARD_DELAY: float = 0.3
## Rearing lifts its front up to REAR_LIFT px, nothing at REAR_PIVOT_X (its hind feet)
## and more toward the front, in whole pixels per 8 px column: a tilt drawn as steps
## (a real rotation would smear the rects off the game's pixel grid).
const REAR_LIFT: float = 10.0
const REAR_PIVOT_X: float = -40.0
const REAR_COLUMN: float = 8.0
const WALK_ACCEL: float = 120.0
const GRAVITY: float = 900.0
const MAX_FALL_SPEED: float = 300.0

## Which way it starts walking: 1 = right, -1 = left.
@export_enum("Left:-1", "Right:1") var start_direction: int = 1:
	set(value):
		start_direction = value
		facing = float(value)
		_apply_facing_to_shapes()
		queue_redraw()
## What each kind of hit does to it. Empty = the table in _make_immunity().
@export var immunity: ElementImmunity

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var earth_tuning: EarthTuning = preload("res://resources/earth_tuning.tres")
var state: State = State.WALK
## 1 = facing right, -1 = left.
var facing: float = 1.0
## Its own horizontal speed (walk or charge), the charge's top speed this time, a push
## on top (a rock, a gust) that slides out, px/s; and its fall speed.
var walk_speed_now: float = 0.0
var charge_speed_now: float = 0.0
var push_speed: float = 0.0
var fall_speed: float = 0.0
var state_time_remaining: float = 0.0
## Seconds until it may charge at the player again.
var charge_cooldown: float = 0.0
## The top speed of the charge that starts when the rear ends.
var pending_charge_speed: float = 0.0
var spot_states: Array[SpotState] = [SpotState.WHOLE, SpotState.WHOLE, SpotState.WHOLE]
var spot_burn_remaining: Array[float] = [0.0, 0.0, 0.0]
var spot_ignite_cooldown: Array[float] = [0.0, 0.0, 0.0]
var whip_phase: Whip = Whip.IDLE
var whip_time_remaining: float = 0.0
## True while this whip strikes forward over the back (else down behind).
var whip_over_back: bool = false
## The tail rope (world coordinates): Verlet points and where each was last frame.
var tail_points: PackedVector2Array = PackedVector2Array()
var tail_previous: PackedVector2Array = PackedVector2Array()
## How long someone has stood on its burnt back.
var rider_time: float = 0.0
## Where it is, px (world). The one true position: every move in a frame works on
## this, and it's written to the node once, at the end of _physics_process. (With
## sync_to_physics on, setting global_position only asks the physics server to move
## the body: reading global_position back in the same frame still gives the old spot,
## so two moves in one frame would undo each other.)
var body_position: Vector2
var home_room: Room = null
var start_position: Vector2
var animation_time: float = 0.0
## Distance walked, px: drives the legs, the bob and the ear.
var stride_distance: float = 0.0

var shapes: Array[CollisionShape2D] = []
var spot_hazards: Array[FireHazard] = []
## Each spot's flame tongues (one FlameMerge per spot).
var spot_flames: Array = [[], [], []]
func _ready() -> void:
	collision_layer = 1 | 8 | 16  # "world", "pushable", "enemies" (see the header)
	collision_mask = 1
	for rect: Rect2 in SHAPE_RECTS:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = rect.size
		shape_node.shape = box
		add_child(shape_node)
		shapes.append(shape_node)
	facing = float(start_direction)
	_apply_facing_to_shapes()
	if Engine.is_editor_hint():
		return
	start_position = global_position
	body_position = global_position
	if immunity == null:
		immunity = _make_immunity()
	_make_spot_fires()
	_reset_tail()
	whip_time_remaining = fire_tuning.elephant_whip_interval
	add_to_group(EnemyHit.GROUP)
	add_to_group(EnemyHit.BREAKS_EARTH_GROUP)
	add_to_group(Pushable.GROUP)
	add_to_group(Flammable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	home_room = Room.find_room_of(self)


## The elephant's row of the §7.2 table: fire burns a spot (KILL: all three kill it),
## a big rock and a gust push it, everything else does nothing.
static func _make_immunity() -> ElementImmunity:
	var push: ElementImmunity.Response = ElementImmunity.Response.PUSH
	return ElementImmunity.from_table({
		EnemyHit.Type.FIREBALL: ElementImmunity.Response.KILL, EnemyHit.Type.FLAME: ElementImmunity.Response.KILL,
		EnemyHit.Type.BIG_ROCK: push, EnemyHit.Type.GUST: push,
	})


## A FireHazard and a few flame tongues per spot, off until that spot burns.
func _make_spot_fires() -> void:
	for spot: int in 3:
		var hazard: FireHazard = FireHazard.new()
		hazard.name = "SpotHazard%d" % spot
		hazard.active = false
		add_child(hazard)
		spot_hazards.append(hazard)
		var flame_merge: FlameMerge = FlameMerge.make(self)
		var flame_count: int = [TRUNK_FLAMES.size(), BACK_FLAMES.size(), TAIL_FLAME_POINTS.size()][spot]
		for flame_index: int in flame_count:
			var flame: FlameTongue = FlameTongue.new()
			flame.length = 15.0 if spot == Spot.BACK else 11.0
			flame.base_width = 7.0
			flame.fan_width = 9.0
			flame.heat = 0.6
			flame.lick_rate = 5.0
			flame.lick_size = 4.0
			flame.lick_speed = 26.0
			flame.smoke_rate = 3.0 if flame_index % 2 == 0 else 0.0
			flame.z_index = 1
			flame.visible = false
			add_child(flame)
			flame_merge.add_tongue(flame)
			spot_flames[spot].append(flame)


## Mirrors the collision boxes to the way it faces.
func _apply_facing_to_shapes() -> void:
	for shape_index: int in shapes.size():
		shapes[shape_index].position = _mirror(SHAPE_RECTS[shape_index].get_center())


func _physics_process(delta: float) -> void:
	animation_time += delta
	if Engine.is_editor_hint():
		return
	if state == State.DEFEATED or not _is_awake():
		return
	_update_state(delta)
	_move(delta)
	_keep_inside_room()
	_update_tail(delta)
	_update_whip(delta)
	_update_spots(delta)
	if state == State.DEFEATED:
		return  # crumbled this frame
	_check_riders(delta)
	_check_front()
	# The one write to the node this frame (see body_position).
	global_position = body_position
	queue_redraw()


# --- Behavior ----------------------------------------------------------------------------

## Timers of the timed states, the charge on sight, and the speed each state aims for.
func _update_state(delta: float) -> void:
	charge_cooldown = maxf(charge_cooldown - delta, 0.0)
	var target_speed: float = 0.0
	var accel: float = WALK_ACCEL
	match state:
		State.WALK:
			target_speed = facing * fire_tuning.elephant_walk_speed
			if _can_charge_player():
				_start_rear(fire_tuning.elephant_charge_speed)
		State.REAR, State.STUNNED:
			state_time_remaining -= delta
			if state_time_remaining <= 0.0:
				if state == State.REAR:
					_start_charge(facing, pending_charge_speed)
				else:
					_end_charge()
			accel = fire_tuning.elephant_brake_decel
		State.CHARGE:
			target_speed = facing * charge_speed_now
			accel = fire_tuning.elephant_charge_accel * charge_speed_now / maxf(fire_tuning.elephant_charge_speed, 1.0)
			if _is_ledge_within(_get_braking_distance() + 1.0):
				# A ledge ahead: brake so it stops at the edge.
				target_speed = 0.0
				accel = fire_tuning.elephant_brake_decel
				if absf(walk_speed_now) < 1.0 or _is_ledge_within(1.0):
					walk_speed_now = 0.0
					_end_charge()
	walk_speed_now = move_toward(walk_speed_now, target_speed, accel * delta)
	push_speed = move_toward(push_speed, 0.0, fire_tuning.elephant_push_decel * delta)


## It charges whenever it can hit you: you're alive, not riding it, in front of it
## within elephant_sight_range, on its level (your feet between its back and a little
## below its feet), and nothing solid is between its eye and you.
func _can_charge_player() -> bool:
	if charge_cooldown > 0.0:
		return false
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead() or player.get_floor_body() == self:
		return false
	var ahead: float = (player.global_position.x - body_position.x) * facing
	if ahead < HEAD_KILL_RECT.position.x or ahead > fire_tuning.elephant_sight_range:
		return false
	var height: float = body_position.y - player.global_position.y
	if height < -8.0 or height > BODY_SIZE.y:
		return false
	var eye: Vector2 = _get_world_point(EYE_POINT)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(eye, player.get_center(), 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## How far it would roll before stopping from its current speed: v² / (2 · decel).
func _get_braking_distance() -> float:
	return walk_speed_now * walk_speed_now / (2.0 * maxf(fire_tuning.elephant_brake_decel, 1.0))


## The rear before a charge (the tell): `speed` is the charge's top speed.
func _start_rear(speed: float) -> void:
	state = State.REAR
	state_time_remaining = fire_tuning.elephant_rear_time
	pending_charge_speed = speed
	_cancel_whip()
	FX.shake(1.0, 0.1)
	FX.play_sfx(&"elephant_trumpet")


## A charge (`direction` = which way, `speed` = top speed): it turns that way and runs.
func _start_charge(direction: float, speed: float) -> void:
	if direction != facing:
		_turn_to(direction)
	state = State.CHARGE
	charge_speed_now = speed
	_cancel_whip()
	FX.shake(1.5, 0.15)
	FX.play_sfx(&"elephant_charge")


## A charge is over (a wall, a ledge, a big rock): back to walking, and no new charge
## for elephant_charge_cooldown.
func _end_charge() -> void:
	state = State.WALK
	charge_cooldown = fire_tuning.elephant_charge_cooldown


## Falls if nothing holds it up, then moves sideways. Walls stop it (a charge smashes
## cracked walls, stone walls and thicket instead, or is stunned); walking, it turns
## at walls and ledges.
func _move(delta: float) -> void:
	# Down: test a 1 px drop to know whether there's floor.
	if _test_motion(Vector2(0.0, 1.0)) == null:
		fall_speed = minf(fall_speed + GRAVITY * delta, MAX_FALL_SPEED)
		var drop: PhysicsTestMotionResult2D = _test_motion(Vector2(0.0, fall_speed * delta))
		body_position.y += fall_speed * delta if drop == null else drop.get_travel().y
		if drop != null:
			fall_speed = 0.0
	else:
		fall_speed = 0.0

	if state == State.WALK and walk_speed_now * facing > 0.0 and _is_ledge_within(1.0):
		_turn_to(-facing)
		return
	var horizontal: float = (walk_speed_now + push_speed) * delta
	if horizontal == 0.0:
		return
	var collision: PhysicsTestMotionResult2D = _test_motion(Vector2(horizontal, 0.0))
	if collision == null:
		body_position.x += horizontal
		stride_distance += absf(horizontal)
		return
	body_position.x += collision.get_travel().x
	stride_distance += absf(collision.get_travel().x)
	var moving_forward: bool = signf(horizontal) == facing
	if state == State.CHARGE and moving_forward:
		if _smash(collision.get_collider()):
			return
		# A real wall: dazed.
		state = State.STUNNED
		state_time_remaining = fire_tuning.elephant_wall_stun_time
		walk_speed_now = 0.0
		FX.shake(3.0, 0.2)
		FX.spawn_gravel(_get_world_point(Vector2(50.0, -30.0)), 12, Vector2(-facing, -0.5))
		FX.play_sfx(&"elephant_wall")
	elif state == State.WALK and moving_forward:
		_turn_to(-facing)
	else:
		push_speed = 0.0


## Would moving by `motion` from here hit something solid (layer 1)? The collision
## (travel, collider, normal), or null if the way is free. Asks the physics server
## directly, which a body synced to physics may do.
func _test_motion(motion: Vector2) -> PhysicsTestMotionResult2D:
	var parameters: PhysicsTestMotionParameters2D = PhysicsTestMotionParameters2D.new()
	parameters.from = Transform2D(0.0, body_position)
	parameters.motion = motion
	var result: PhysicsTestMotionResult2D = PhysicsTestMotionResult2D.new()
	if PhysicsServer2D.body_test_motion(get_rid(), parameters, result):
		return result
	return null


## A charge hit `collider`: smashes it if it's a cracked wall, a stone wall or
## thicket. Returns true if it did (the charge goes on).
func _smash(collider: Object) -> bool:
	var cracked_wall: CrackedWall = collider as CrackedWall
	if cracked_wall != null:
		cracked_wall.break_open(Vector2(facing, 0.0), earth_tuning)
		FX.freeze(0.05)
		return true
	var stone_wall: StoneWall = collider as StoneWall
	if stone_wall != null:
		stone_wall.break_open(Vector2(facing, 0.0))
		return true
	if collider is ThicketLayer:
		var grid: FireGrid = FireGrid.find_grid_at(get_tree(), body_position)
		if grid != null and grid.crush_thicket_in(_get_world_rect(SMASH_RECT)):
			FX.shake(1.5, 0.1)
			return true
	return false


## Turns to face `direction` (its collision boxes mirror with it).
func _turn_to(direction: float) -> void:
	facing = direction
	walk_speed_now = 0.0
	_apply_facing_to_shapes()


## True if there's no floor `distance` px past its front feet (a ledge ahead). Something
## solid right there at foot height is a wall (or a step), not a ledge: the ray down
## would start inside it and find nothing.
func _is_ledge_within(distance: float) -> bool:
	var front_x: float = body_position.x + facing * (FRONT_FOOT_X + distance)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var point_query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	point_query.position = Vector2(front_x, body_position.y - 2.0)
	point_query.collision_mask = 1
	point_query.exclude = [get_rid()]
	if not space.intersect_point(point_query, 1).is_empty():
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(front_x, body_position.y - 2.0), Vector2(front_x, body_position.y + 4.0), 1)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


## The room's left and right edges are walls for it, like for the wisp.
func _keep_inside_room() -> void:
	if home_room == null:
		return
	var bounds: Rect2 = home_room.get_bounds()
	var half_width: float = BODY_SIZE.x / 2.0
	if body_position.x - half_width < bounds.position.x:
		body_position.x = bounds.position.x + half_width
	elif body_position.x + half_width > bounds.end.x:
		body_position.x = bounds.end.x - half_width
	else:
		return
	if state == State.WALK:
		_turn_to(signf(bounds.get_center().x - body_position.x))
	walk_speed_now = 0.0
	push_speed = 0.0


## The player standing on it, or null.
func _get_rider() -> Player:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player != null and not player.is_dead() and player.get_floor_body() == self:
		return player
	return null


## Someone standing on its BURNT back for elephant_back_strike_delay gets the tail
## struck forward over the back.
func _check_riders(delta: float) -> void:
	if spot_states[Spot.BACK] == SpotState.WHOLE or whip_phase != Whip.IDLE or _get_rider() == null:
		rider_time = 0.0
		return
	rider_time += delta
	if rider_time >= fire_tuning.elephant_back_strike_delay:
		rider_time = 0.0
		_start_back_strike()


## Its front (head, tusks, trunk) kills the player on touch, in every state.
func _check_front() -> void:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead():
		return
	var player_rect: Rect2 = player.get_hitbox_rect()
	for kill_rect: Rect2 in _get_front_kill_rects():
		if _get_world_rect(kill_rect).intersects(player_rect):
			player.die()
			return


## The deadly front this frame, drawing coordinates: the head's front face, the tusk
## and the trunk as drawn now (hanging, raised or a stub), lifted with a rear.
func _get_front_kill_rects() -> Array[Rect2]:
	var kill_rects: Array[Rect2] = [HEAD_KILL_RECT, TUSK_RECT.grow(1.0)]
	for trunk_rect: Rect2 in _get_trunk_rects():
		kill_rects.append(trunk_rect.grow(1.0))
	for rect_index: int in kill_rects.size():
		kill_rects[rect_index].position.y -= _get_rear_lift(kill_rects[rect_index].get_center().x)
	return kill_rects


# --- Tail and whip ----------------------------------------------------------------------

## The tail as a rope: Verlet points (each keeps its speed as "where it is minus where
## it was"), pulled toward a pose, then held TAIL_SEGMENT apart from the root out.
## During a strike the pull is strong at the root and weak at the tip, so the root
## leads and the tip lashes after it: a whip. Wiggling adds a fast wave running down
## the tail; idle, a slow sway.
func _update_tail(delta: float) -> void:
	var root: Vector2 = _get_world_point(TAIL_ROOT)
	var pose_angle: float = _get_tail_angle()
	var pull: float = 0.1
	match whip_phase:
		Whip.WIGGLE:
			pull = 0.3
		Whip.RAISE:
			pull = 0.25
		Whip.STRIKE:
			pull = 0.6
	var gravity_step: Vector2 = Vector2(0.0, 300.0 * delta * delta)
	tail_points[0] = root
	for point_index: int in range(1, TAIL_POINT_COUNT):
		var moved: Vector2 = (tail_points[point_index] - tail_previous[point_index]) * 0.9
		tail_previous[point_index] = tail_points[point_index]
		tail_points[point_index] += moved + gravity_step
		var along: float = float(point_index) / (TAIL_POINT_COUNT - 1)
		# The pose: along the angle, curling a little toward the tip.
		var angle: float = pose_angle + along * (0.6 if whip_phase != Whip.STRIKE else 0.2)
		if whip_phase == Whip.WIGGLE:
			angle += sin(animation_time * 28.0 - point_index * 0.9) * 0.35 * along
		elif whip_phase == Whip.IDLE:
			angle += sin(animation_time * 2.0 - point_index * 0.4) * 0.12
		var target: Vector2 = root + _tail_direction(angle) * TAIL_SEGMENT * point_index
		var point_pull: float = pull * (1.0 - along * 0.6) if whip_phase == Whip.STRIKE else pull * (0.4 + along)
		tail_points[point_index] = tail_points[point_index].lerp(target, point_pull)
	for iteration: int in 3:
		for point_index: int in range(1, TAIL_POINT_COUNT):
			var previous: Vector2 = tail_points[point_index - 1]
			var offset: Vector2 = tail_points[point_index] - previous
			if offset.length() > 0.001:
				tail_points[point_index] = previous + offset.normalized() * TAIL_SEGMENT
	# The long tail trails on the ground behind it, never through it.
	for point_index: int in range(1, TAIL_POINT_COUNT):
		tail_points[point_index].y = minf(tail_points[point_index].y, body_position.y - 1.0)


## A tail angle (see TAIL_HANG_ANGLE) as a world direction: 0 = straight back.
func _tail_direction(angle: float) -> Vector2:
	return Vector2(-cos(angle) * facing, sin(angle))


## The tail's pose angle for this moment of the whip.
func _get_tail_angle() -> float:
	match whip_phase:
		Whip.WIGGLE:
			return TAIL_HANG_ANGLE - 0.3
		Whip.RAISE:
			var raise_share: float = 1.0 - whip_time_remaining / maxf(fire_tuning.elephant_whip_raise_time, 0.01)
			return lerpf(TAIL_HANG_ANGLE - 0.3, TAIL_RAISED_ANGLE, ease(raise_share, 0.5))
		Whip.STRIKE:
			var strike_share: float = 1.0 - whip_time_remaining / maxf(fire_tuning.elephant_whip_strike_time, 0.01)
			var target: float = TAIL_STRIKE_BACK_ANGLE if whip_over_back else TAIL_STRIKE_BEHIND_ANGLE
			return lerpf(TAIL_RAISED_ANGLE, target, ease(strike_share, 0.4))
	return TAIL_HANG_ANGLE


## The whip's rhythm: wait, wiggle, raise, strike. The strike kills what it touches.
## A strike over the back may run in any state; the rhythm only while it walks.
func _update_whip(delta: float) -> void:
	if spot_states[Spot.TAIL] != SpotState.WHOLE or (state != State.WALK and not whip_over_back):
		_cancel_whip()
		return
	whip_time_remaining -= delta
	if whip_phase == Whip.STRIKE:
		_whip_hits()
	if whip_time_remaining > 0.0:
		return
	match whip_phase:
		Whip.IDLE:
			whip_phase = Whip.WIGGLE
			whip_time_remaining = fire_tuning.elephant_whip_wiggle_time
		Whip.WIGGLE:
			whip_phase = Whip.RAISE
			whip_time_remaining = fire_tuning.elephant_whip_raise_time
		Whip.RAISE:
			whip_phase = Whip.STRIKE
			whip_time_remaining = fire_tuning.elephant_whip_strike_time
			FX.play_sfx(&"elephant_whip")
		Whip.STRIKE:
			_crack_whip()
			whip_phase = Whip.IDLE
			whip_over_back = false
			whip_time_remaining = fire_tuning.elephant_whip_interval


## Its back burnt or ridden while burnt: the tail goes straight up (no wiggle) and
## strikes forward over the back.
func _start_back_strike() -> void:
	if spot_states[Spot.TAIL] != SpotState.WHOLE:
		return
	whip_over_back = true
	whip_phase = Whip.RAISE
	whip_time_remaining = fire_tuning.elephant_whip_raise_time


func _cancel_whip() -> void:
	whip_phase = Whip.IDLE
	whip_over_back = false
	whip_time_remaining = maxf(whip_time_remaining, fire_tuning.elephant_whip_wiggle_time)


## The crack at the end of a strike: a flash of sparks and dust at the tip.
func _crack_whip() -> void:
	var tip: Vector2 = tail_points[TAIL_POINT_COUNT - 1]
	EmberEmitter.burst(get_parent(), tip, 6, Vector2.UP, 180.0, 50.0)
	FX.spawn_gravel(tip, 4, Vector2.UP, 0.0)
	FX.shake(1.0, 0.06)


## During the strike: the player touching the tail dies; enemies touching it get a
## WHIP hit (their table decides: wisps and monkeys die).
func _whip_hits() -> void:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	var player_rect: Rect2 = Rect2() if player == null else player.get_hitbox_rect().grow(1.5)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for point_index: int in range(3, TAIL_POINT_COUNT):
		var point: Vector2 = tail_points[point_index]
		if player != null and not player.is_dead() and player_rect.has_point(point):
			player.die()
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = point
		query.collision_mask = 16  # bit value of layer 5, "enemies"
		query.exclude = [get_rid()]
		for result: Dictionary in space.intersect_point(query, 4):
			EnemyHit.send(result.collider, EnemyHit.Type.WHIP, Vector2(-facing * 120.0, -60.0), self)


func _reset_tail() -> void:
	tail_points.clear()
	tail_previous.clear()
	var root: Vector2 = _get_world_point(TAIL_ROOT)
	for point_index: int in TAIL_POINT_COUNT:
		var point: Vector2 = root + _tail_direction(TAIL_HANG_ANGLE) * TAIL_SEGMENT * point_index
		tail_points.append(point)
		tail_previous.append(point)


# --- Burn spots -------------------------------------------------------------------------

## Lights `spot` (if it's still whole) and plays its reaction. `fire_origin`: where
## the fire came from (world), for which way a tail burn bolts. Returns true if it lit.
func _light_spot(spot: Spot, fire_origin: Vector2) -> bool:
	if spot_states[spot] != SpotState.WHOLE or state == State.DEFEATED:
		return false
	spot_states[spot] = SpotState.BURNING
	spot_burn_remaining[spot] = fire_tuning.elephant_spot_burn_time
	spot_ignite_cooldown[spot] = 0.0
	for flame: FlameTongue in spot_flames[spot]:
		flame.visible = true
		flame.scale = Vector2.ONE
	var center: Vector2 = _get_spot_rect(spot).get_center()
	FireRing.spawn(get_parent(), center, 16.0, 0.2)
	EmberEmitter.burst(get_parent(), center, 12, Vector2.UP, 160.0, 60.0)
	FX.play_sfx(&"elephant_spot_lit")
	var hit_speed: float = fire_tuning.elephant_charge_speed * fire_tuning.elephant_hit_charge_multiplier
	match spot:
		Spot.TRUNK:
			# It rears, then charges forward (at you, most likely), twice as fast.
			_start_rear(hit_speed)
		Spot.TAIL:
			# Spooked: it bolts away from where the fire came from, twice as fast.
			var away: float = facing
			if fire_origin != EnemyHit.NO_POSITION and absf(fire_origin.x - body_position.x) > 1.0:
				away = signf(body_position.x - fire_origin.x)
			_start_charge(away, hit_speed)
		Spot.BACK:
			# The tail strikes forward over its back (if it still has one).
			_start_back_strike()
	return true


## Burning spots count down, light what they touch, and turn BURNT. All three burnt:
## it crumbles.
func _update_spots(delta: float) -> void:
	for spot: int in 3:
		var hazard: FireHazard = spot_hazards[spot]
		var rect: Rect2 = _get_spot_rect(spot)
		if spot_states[spot] != SpotState.BURNING:
			# A whole spot walking into fire (burning grass, a bonfire) catches.
			if spot_states[spot] == SpotState.WHOLE and FireHazard.touches_fire(get_tree(), rect, self):
				_light_spot(spot as Spot, EnemyHit.NO_POSITION)
			continue
		spot_burn_remaining[spot] -= delta
		# The deadly flame follows the spot (the tail moves); the back only kills once
		# you've had time to jump off.
		hazard.global_position = rect.get_center()
		hazard.hazard_size = rect.size
		var burnt_for: float = fire_tuning.elephant_spot_burn_time - spot_burn_remaining[spot]
		hazard.active = spot != Spot.BACK or burnt_for >= BACK_HAZARD_DELAY
		spot_ignite_cooldown[spot] -= delta
		if spot_ignite_cooldown[spot] <= 0.0:
			spot_ignite_cooldown[spot] = SPOT_IGNITE_INTERVAL
			Flammable.ignite_in_rect(get_tree(), rect.grow(SPOT_IGNITE_REACH), self, self, SPOT_IGNITE_REACH)
		_place_spot_flames(spot)
		if spot_burn_remaining[spot] <= 0.0:
			spot_states[spot] = SpotState.BURNT
			hazard.active = false
			for flame: FlameTongue in spot_flames[spot]:
				flame.visible = false
			SmokePuff.spawn(get_parent(), rect.get_center(), 5)
			PebbleField.leave_ash(get_tree(), rect.get_center(), 6, rect.size, ASH_FLAKE_COLORS)
	if spot_states.count(SpotState.BURNT) == 3:
		_crumble()


## Puts a burning spot's flames where they belong this frame (mirrored with the
## facing; the tail's ride its rope), shrinking as the spot burns out.
func _place_spot_flames(spot: int) -> void:
	var fade: float = clampf(spot_burn_remaining[spot] / (fire_tuning.elephant_spot_burn_time * 0.3), 0.2, 1.0)
	var flames: Array = spot_flames[spot]
	for flame_index: int in flames.size():
		var flame: FlameTongue = flames[flame_index]
		match spot:
			Spot.TRUNK:
				flame.position = _mirror(TRUNK_FLAMES[flame_index])
			Spot.BACK:
				flame.position = _mirror(BACK_FLAMES[flame_index])
			Spot.TAIL:
				flame.position = to_local(tail_points[TAIL_FLAME_POINTS[flame_index]])
		flame.scale = Vector2.ONE * fade


## All three spots burnt: it falls apart into a big heap of ash and earth.
func _crumble() -> void:
	var center: Vector2 = body_position + Vector2(0.0, -BODY_SIZE.y / 2.0)
	AshFall.spawn(get_parent(), center, 80, BODY_SIZE, 0.5)
	PebbleField.leave_ash(get_tree(), center, 40, BODY_SIZE, ASH_FLAKE_COLORS)
	PebbleField.leave_colored_pebbles(get_tree(), center, 24, Vector2.UP, STONE_PEBBLE_COLORS)
	FX.spawn_gravel(center, 30, Vector2.UP)
	SmokePuff.spawn(get_parent(), center, 12)
	EmberEmitter.burst(get_parent(), center, 20, Vector2.UP, 160.0, 50.0)
	FX.shake(4.0, 0.3)
	FX.freeze(0.08)
	FX.play_sfx(&"elephant_defeated")
	state = State.DEFEATED
	visible = false
	collision_layer = 0
	for hazard: FireHazard in spot_hazards:
		hazard.active = false
	defeated.emit()


# --- Hits ---------------------------------------------------------------------------------

## The EnemyHit contract. Fire lights the spots near where it landed; a big rock
## pushes it back (and stops a charge); a gust nudges it.
func receive_hit(hit: EnemyHit) -> ElementImmunity.Response:
	if state == State.DEFEATED:
		return ElementImmunity.Response.IGNORE
	var response: ElementImmunity.Response = immunity.get_response(hit.type)
	match response:
		ElementImmunity.Response.KILL:
			# Fire: only the spots near where it landed catch. A fireball's own hit
			# reaches as far as its splash.
			if hit.world_position != EnemyHit.NO_POSITION:
				var reach: float = fire_tuning.fireball_splash if hit.type == EnemyHit.Type.FIREBALL else 2.0
				ignite_at(hit.world_position, reach, hit.source)
		ElementImmunity.Response.PUSH, ElementImmunity.Response.STAGGER:
			var direction: float = signf(hit.push_velocity.x) if absf(hit.push_velocity.x) > 0.01 else -facing
			if hit.type == EnemyHit.Type.BIG_ROCK:
				push_speed = direction * fire_tuning.elephant_rock_push_speed
				if state == State.CHARGE or state == State.REAR:
					# A big rock stops a charge dead (no stagger: it walks on).
					walk_speed_now = 0.0
					_end_charge()
				FX.shake(2.0, 0.12)
			else:
				push_speed += direction * fire_tuning.elephant_gust_nudge_speed
		ElementImmunity.Response.IGNORE:
			if hit.type == EnemyHit.Type.SMALL_ROCK or hit.type == EnemyHit.Type.PERFECT_ROCK:
				FX.shake(0.5, 0.06)  # it bounces off the hide
	return response


## The Pushable contract (gust, dash wake): a GUST hit.
func receive_gust(direction: Vector2, strength: float) -> void:
	receive_hit(EnemyHit.make(EnemyHit.Type.GUST, direction * strength))


# --- The Flammable contract ----------------------------------------------------------------
# It burns in parts, like the FireGrid: flames call ignite_at() with where they are,
# and only the spots there catch. A flame on its earth body does nothing.

func ignite_at(world_point: Vector2, radius: float, _source: Node) -> bool:
	var any_lit: bool = false
	for spot: int in 3:
		if spot_states[spot] == SpotState.WHOLE and _get_spot_rect(spot).grow(radius).has_point(world_point):
			any_lit = _light_spot(spot as Spot, world_point) or any_lit
	return any_lit


## Lighting it as a whole means nothing: it's the spots that burn (see ignite_at).
func ignite(_source: Node) -> void:
	pass


func is_burning() -> bool:
	return spot_states.has(SpotState.BURNING)


func snuff() -> void:
	pass


func get_fire_rect() -> Rect2:
	return _get_world_rect(Rect2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y))


func is_spot_burnt(spot: Spot) -> bool:
	return spot_states[spot] == SpotState.BURNT


# --- Room ---------------------------------------------------------------------------------

## Only the room the player is in is awake (like the sentries): creatures in other
## rooms stand still. Not in a Room (a test scene): always awake.
func _is_awake() -> bool:
	return home_room == null or GameState.current_room == null or GameState.current_room == home_room


## Called by Room.reset_objects() (death, R) and Room.reset_enemies() (walking in).
func reset() -> void:
	# The jump home: body_position (what the next frames move from), and the node and
	# the physics server at once, with the sync off so the move is instant instead of
	# a request for the next physics step.
	body_position = start_position
	sync_to_physics = false
	global_position = start_position
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
	sync_to_physics = true
	_turn_to(float(start_direction))
	state = State.WALK
	walk_speed_now = 0.0
	push_speed = 0.0
	fall_speed = 0.0
	rider_time = 0.0
	charge_cooldown = 0.0
	whip_phase = Whip.IDLE
	whip_over_back = false
	whip_time_remaining = fire_tuning.elephant_whip_interval
	for spot: int in 3:
		spot_states[spot] = SpotState.WHOLE
		spot_hazards[spot].active = false
		for flame: FlameTongue in spot_flames[spot]:
			flame.visible = false
			flame.scale = Vector2.ONE
	visible = true
	collision_layer = 1 | 8 | 16
	_reset_tail()


# --- Geometry -------------------------------------------------------------------------------

## A point in drawing coordinates (facing right) -> local (mirrored with the facing).
func _mirror(drawing_point: Vector2) -> Vector2:
	return Vector2(drawing_point.x * facing, drawing_point.y)


func _get_world_point(drawing_point: Vector2) -> Vector2:
	return body_position + _mirror(drawing_point)


## A rectangle in drawing coordinates -> world (mirrored with the facing).
func _get_world_rect(drawing_rect: Rect2) -> Rect2:
	var corner_a: Vector2 = _get_world_point(drawing_rect.position)
	var corner_b: Vector2 = _get_world_point(drawing_rect.end)
	return Rect2(Vector2(minf(corner_a.x, corner_b.x), corner_a.y), Vector2(absf(corner_b.x - corner_a.x), drawing_rect.size.y))


## A spot's area in world coordinates (the tail's: around its rope).
func _get_spot_rect(spot: int) -> Rect2:
	match spot:
		Spot.TRUNK:
			return _get_world_rect(TRUNK_RECT)
		Spot.BACK:
			return _get_world_rect(BACK_RECT)
	var tail_rect: Rect2 = Rect2(tail_points[2], Vector2.ZERO)
	for point_index: int in range(3, TAIL_POINT_COUNT):
		tail_rect = tail_rect.expand(tail_points[point_index])
	return tail_rect.grow(3.0)


# --- Look ----------------------------------------------------------------------------------
#
# Option C, "stepped" (chosen by the developer from four minimalist designs): flat
# rectangles on the 8 px tile grid, like the wisp. A stepped stone silhouette (a lighter
# top, a darker belly band), a block ear, two eyes (white with an enemy-purple pupil), a
# pale tusk, legs that step, and the burnable parts in moss green: tufts on its back, a
# blocky trunk with a foot, the long vine tail. A burning part glows ember and chars;
# a burnt one shrinks to a charred stub. No outlines, no textures: about thirty rects.
#
# On the game's pixel grid, always: the drawing is snapped to whole pixels (the body
# moves in fractions of a pixel), nothing is ever rotated (the rear is drawn as
# whole-pixel steps, the raised trunk is its own pose), and the tail is drawn as
# 3x3 pixel squares along its rope. The silhouette rects are the collision boxes.

## Every rect of the body that doesn't burn, in drawing coordinates (facing right,
## origin at the feet), back to front, each with its color. The stone silhouette is
## the collision boxes (BACK_TOP_RECT minus its moss strip, BODY_ROW_RECT with the
## head, BELLY_RECT).
const BODY_RECTS: Array = [
	[Rect2(-48, -48, 88, 24), STONE_COLOR],
	[Rect2(-24, -56, 48, 8), STONE_LIGHT_COLOR],
	[Rect2(-48, -48, 88, 3), STONE_LIGHT_COLOR],
	[Rect2(-40, -24, 80, 8), STONE_DARK_COLOR],
]
## The head (its top on the shoulder row, its front face at 48), the ear behind it,
## the eyes: whites with purple pupils looking forward.
const HEAD_RECTS: Array = [
	[Rect2(24, -44, 8, 20), STONE_DARK_COLOR],   # the ear
	[Rect2(32, -48, 16, 24), STONE_COLOR],
	[Rect2(32, -48, 16, 3), STONE_LIGHT_COLOR],
	[Rect2(36, -43, 4, 4), EYE_WHITE_COLOR],
	[Rect2(42, -43, 4, 4), EYE_WHITE_COLOR],
	[Rect2(38, -42, 2, 2), EYE_COLOR],
	[Rect2(44, -42, 2, 2), EYE_COLOR],
]
## The burnable parts: the moss on its back (a strip it stands on, tufts poking 2 px
## above), and the trunk: a column hanging from the face, a foot, a toe turned up.
## Raised (while it rears): out from the face and up in front of it, tip curled back.
const MOSS_RECTS: Array[Rect2] = [Rect2(-24, -58, 48, 2), Rect2(-24, -60, 6, 2), Rect2(-12, -60, 6, 2),
	Rect2(0, -60, 6, 2), Rect2(12, -60, 6, 2), Rect2(-18, -59, 6, 1), Rect2(-6, -59, 6, 1), Rect2(6, -59, 6, 1),
	Rect2(18, -59, 6, 1)]
const MOSS_BURNT_RECTS: Array[Rect2] = [Rect2(-24, -58, 48, 2)]
const TRUNK_RECTS: Array[Rect2] = [Rect2(44, -24, 8, 16), Rect2(44, -8, 16, 8), Rect2(56, -16, 4, 8)]
const TRUNK_RAISED_RECTS: Array[Rect2] = [Rect2(44, -32, 16, 8), Rect2(56, -52, 8, 20), Rect2(52, -56, 8, 4)]
const TRUNK_BURNT_RECTS: Array[Rect2] = [Rect2(44, -24, 8, 8)]
const TUSK_RECT: Rect2 = Rect2(48, -28, 8, 4)


## The draw transform for this frame: mirrored to its facing, snapped to whole pixels
## (its body_position moves in fractions of a pixel; drawn as is, its edges would fall
## between the game's pixels), bobbing a pixel with the walk. Never rotated.
func _get_draw_transform() -> Transform2D:
	var draw_facing: float = float(start_direction) if Engine.is_editor_hint() else facing
	var bob: float = 0.0
	if not Engine.is_editor_hint() and (state == State.WALK or state == State.CHARGE):
		bob = -roundf(absf(sin(stride_distance * 0.12)))
	var snap: Vector2 = global_position.round() - global_position
	return Transform2D(0.0, Vector2(draw_facing, 1.0), 0.0, snap + Vector2(0.0, bob))


## How far into its rear it is, eased, 0..1.
func _get_rear_share() -> float:
	var rear_share: float = 1.0 - state_time_remaining / maxf(fire_tuning.elephant_rear_time, 0.01)
	return sin(minf(rear_share * 1.3, 1.0) * PI * 0.5)


## While it rears: how many whole pixels the column at drawing x `x` is lifted (none at
## its hind feet, REAR_LIFT at its front). 0 otherwise.
func _get_rear_lift(x: float) -> float:
	if Engine.is_editor_hint() or state != State.REAR:
		return 0.0
	var column_x: float = floorf(x / REAR_COLUMN) * REAR_COLUMN + REAR_COLUMN / 2.0
	var front_share: float = clampf((column_x - REAR_PIVOT_X) / (BODY_SIZE.x / 2.0 - REAR_PIVOT_X), 0.0, 1.0)
	return roundf(REAR_LIFT * front_share * _get_rear_share())


## The trunk's rects right now: a stub once burnt, raised while it rears, else hanging.
func _get_trunk_rects() -> Array[Rect2]:
	if not Engine.is_editor_hint():
		if spot_states[Spot.TRUNK] == SpotState.BURNT:
			return TRUNK_BURNT_RECTS
		if state == State.REAR and _get_rear_share() > 0.4:
			return TRUNK_RAISED_RECTS
	return TRUNK_RECTS


## One rect of the body. Rearing: cut into REAR_COLUMN-wide columns, each lifted by its
## own whole-pixel amount, so the tilt is drawn as steps on the pixel grid.
func _draw_part(rect: Rect2, color: Color) -> void:
	if Engine.is_editor_hint() or state != State.REAR:
		draw_rect(rect, color)
		return
	var column_left: float = rect.position.x
	while column_left < rect.end.x:
		var column_right: float = minf(floorf(column_left / REAR_COLUMN) * REAR_COLUMN + REAR_COLUMN, rect.end.x)
		var lift: float = _get_rear_lift(column_left)
		draw_rect(Rect2(column_left, rect.position.y - lift, column_right - column_left, rect.size.y), color)
		column_left = column_right


## Far legs, the tail, the body, the moss, near legs, the head, the trunk, the tusk.
func _draw() -> void:
	var body_transform: Transform2D = _get_draw_transform()
	var stride: float = stride_distance * 0.12
	draw_set_transform_matrix(body_transform)
	_draw_leg(0, stride, STONE_DARK_COLOR)
	_draw_leg(2, stride, STONE_DARK_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_tail()
	draw_set_transform_matrix(body_transform)
	for part: Array in BODY_RECTS:
		_draw_part(part[0], part[1])
	_draw_burnable_rects(MOSS_RECTS, MOSS_BURNT_RECTS, Spot.BACK)
	_draw_leg(1, stride, STONE_COLOR)
	_draw_leg(3, stride, STONE_COLOR)
	for part: Array in HEAD_RECTS:
		_draw_part(part[0], part[1])
	_draw_burnable_rects(_get_trunk_rects(), TRUNK_BURNT_RECTS, Spot.TRUNK)
	_draw_part(TUSK_RECT, TUSK_COLOR)
	if not Engine.is_editor_hint() and state == State.STUNNED:
		var stars_center: Vector2 = Vector2(40.0, -54.0)
		for star_index: int in 4:
			var angle: float = animation_time * 6.0 + TAU * star_index / 4.0
			draw_rect(Rect2((stars_center + Vector2(cos(angle) * 9.0, sin(angle) * 2.5)).round(), Vector2(2, 2)), DIZZY_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A burnable part's rects (`whole` until burnt, then `burnt`): moss green while whole,
## glowing ember then char while it burns, char once burnt.
func _draw_burnable_rects(whole: Array[Rect2], burnt: Array[Rect2], spot: int) -> void:
	var spot_state: SpotState = spot_states[spot] if not Engine.is_editor_hint() else SpotState.WHOLE
	var rects: Array[Rect2] = burnt if spot_state == SpotState.BURNT else whole
	var color: Color = _get_spot_color(spot)
	for rect: Rect2 in rects:
		_draw_part(rect, color)


## A burnable spot's color right now: moss green, ember then char while it burns, char.
func _get_spot_color(spot: int) -> Color:
	var spot_state: SpotState = spot_states[spot] if not Engine.is_editor_hint() else SpotState.WHOLE
	match spot_state:
		SpotState.BURNING:
			var burn_share: float = _get_burn_share(spot)
			return MOSS_COLOR.lerp(EMBER_COLOR, minf(burn_share * 2.0, 1.0)).lerp(CHAR_COLOR, burn_share)
		SpotState.BURNT:
			return CHAR_COLOR
	return MOSS_COLOR


## A leg, stepping in diagonal pairs (far hind with near fore, near hind with far
## fore): it lifts and swings a pixel or two. Rearing, the front legs come up too.
func _draw_leg(leg_index: int, stride: float, color: Color) -> void:
	var walking: bool = not Engine.is_editor_hint() and (state == State.WALK or state == State.CHARGE)
	var phase: float = stride + (0.0 if leg_index == 0 or leg_index == 3 else PI)
	var lift: float = roundf(maxf(sin(phase), 0.0) * 2.0) if walking else 0.0
	var swing: float = roundf(cos(phase) * 2.0) if walking else 0.0
	var hip: float = LEG_HIPS[leg_index]
	lift += _get_rear_lift(hip)
	draw_rect(Rect2(Vector2(hip - LEG_SIZE.x / 2.0 + swing, LEG_TOP - lift), LEG_SIZE), color)


## The long vine tail along its rope: a 3x3 pixel square at every whole pixel along it,
## each at a rounded WORLD position (drawn in local space so the rope's lag shows), so
## it sits on the pixel grid like everything else. A tuft at the tip; raised for the
## strike, the tuft glints: the warning. Burnt: a charred stub.
func _draw_tail() -> void:
	if tail_points.size() < 2:
		return
	var tail_state: SpotState = spot_states[Spot.TAIL] if not Engine.is_editor_hint() else SpotState.WHOLE
	var shown: int = TAIL_POINT_COUNT if tail_state != SpotState.BURNT else 3
	var color: Color = _get_spot_color(Spot.TAIL)
	for point_index: int in range(1, shown):
		var from_point: Vector2 = tail_points[point_index - 1]
		var to_point: Vector2 = tail_points[point_index]
		var steps: int = maxi(ceili(from_point.distance_to(to_point)), 1)
		for step: int in steps:
			var pixel: Vector2 = from_point.lerp(to_point, float(step) / steps).round()
			draw_rect(Rect2(pixel - global_position - Vector2(1, 1), Vector2(3, 3)), color)
	if tail_state == SpotState.BURNT:
		return
	var tip: Vector2 = tail_points[shown - 1].round() - global_position
	draw_rect(Rect2(tip - Vector2(3, 3), Vector2(6, 6)), color)
	if whip_phase == Whip.RAISE:
		var glint: float = 0.5 + 0.5 * sin(animation_time * 30.0)
		draw_rect(Rect2(tip - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 1.0, 0.85, glint))


## How far a burning spot has burnt, 0..1.
func _get_burn_share(spot: int) -> float:
	return 1.0 - spot_burn_remaining[spot] / maxf(fire_tuning.elephant_spot_burn_time, 0.01)

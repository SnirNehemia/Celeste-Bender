@tool
class_name VineMonkey
extends CharacterBody2D
## Vine monkey (Fire_bending.md §7.2, Stage F11): the agile leafling. A small monkey,
## its body a ball of thicket with vine arms and a curled vine tail. Only FIRE kills
## it, and when it burns it becomes a living torch: a moving fuse.
##
## Place the node ON the floor, at the bottom-center of the monkey (origin at the
## feet, like the wisp and the player).
##
## States:
##   RUN      runs its route at monkey_run_speed. Turns at walls; at a ledge it HOPS
##            the gap if there's a rim within reach (monkey_hop_max_gap wide, level
##            or up to monkey_hop_max_rise higher) and `hops_gaps` is on, else turns.
##            So the route is the same loop every time: readable, never chasing.
##            Deadly to touch.
##   HOP      in the air on a hop, aimed to land on the far rim. Deadly.
##   PUSHED   thrown by a gust, a rock, a column or the snake; stunned and harmless
##            for monkey_push_stun_time, like a stunned wisp.
##   TORCH    lit: panics for leafling_torch_time, running at monkey_torch_speed in
##            its current direction, turning at walls AND ledges (no hops: it's
##            panicking). It lights every flammable it touches (grass, thicket, leaf
##            piles, vines, air diamonds, wisps) and kills on touch (a FireHazard over
##            it, so wisps walking into it burn too). The flame CREEPS across it from
##            the side it was lit on, the brambles under it turn to glowing ember,
##            then the fire dies down to gray ash, and it crumbles (see "Look").
##   SMOLDER  a gust blew its fire out: charred and smoking, stunned (harmless) for
##            monkey_snuff_stun_time, then it carries on its route. It can be lit again.
##   DEFEATED crumbled to ash, whipped by the elephant's tail (Stage F11b), or fell out
##            of the room. Gone until the room resets.
##
## It's LIGHT: hot updrafts lift it (a heat receiver, so it drifts up over a bonfire),
## wind zones carry it, a gust blows it further than a wisp. Spikes don't hurt it (it
## lands on them harmlessly and runs across). Rocks, columns and the snake only push.
## All of that is its ElementImmunity table (_make_immunity) and _be_pushed().
##
## Hit by the jet or a fireball while it hops a gap: it keeps flying, lands on the far
## rim and runs on burning there. That's the way to carry fire across its gap.
##
## Contracts (no special code anywhere else):
##   - EnemyHit (group "enemies" + receive_hit): every hit
##   - Pushable (group "pushable" + receive_gust): the gust, dash wake, column, snake
##   - Flammable (group "flammable" + ignite/is_burning/snuff/get_fire_rect): every flame
##   - Heat receiver (group "heat_receiver" + apply_heat): hot updrafts lift it
##   - Room.RESETTABLE_GROUP + reset(); the `defeated` signal (EnemyGate counts it)
##   - FireHazard.touches_fire(): it catches when it runs into fire
##
## Physics: like the wisp, body on layers 4 ("pushable") and 5 ("enemies"), colliding
## only with layer 1 ("world"). The player isn't in its mask; touching is checked by
## rectangles every frame (_check_contacts).
##
## Every number that changes the feel is in FireTuning, group "Vine monkey" (F5 panel).

enum State { RUN, HOP, PUSHED, TORCH, SMOLDER, DEFEATED }

## Emitted once when it's defeated (crumbled to ash, or fell out). EnemyGate listens.
signal defeated

## Thicket colors (the same family as the thicket tiles and their leaves), so it reads
## as "made of the stuff that burns", under a dark outline that reads on any sky.
const OUTLINE_COLOR: Color = Color(0.04, 0.07, 0.05)
const BODY_COLOR: Color = Color(0.16, 0.32, 0.14)
const BODY_SHADE_COLOR: Color = Color(0.09, 0.19, 0.1)
const LEAF_DARK_COLOR: Color = Color(0.24, 0.47, 0.18)
const LEAF_LIGHT_COLOR: Color = Color(0.46, 0.68, 0.25)
const VINE_COLOR: Color = Color(0.42, 0.56, 0.22)
## A pale capuchin face patch.
const FACE_COLOR: Color = Color(0.8, 0.7, 0.47)
## Its eye glows enemy purple (GAME_DESIGN.md §2), so you know it bites.
const EYE_COLOR: Color = Color(0.92, 0.55, 1.0)
## Burning: green -> glowing ember (with bright cracks) -> gray ash.
const EMBER_BODY_COLOR: Color = Color(0.82, 0.27, 0.07)
const EMBER_GLOW_COLOR: Color = Color(1.0, 0.78, 0.35)
const ASH_COLOR: Color = Color(0.55, 0.53, 0.5)
const ASH_DARK_COLOR: Color = Color(0.32, 0.31, 0.3)
## After a snuff it stays a little charred until R.
const CHAR_COLOR: Color = Color(0.16, 0.1, 0.07)
const ASH_FLAKE_COLORS: Array[Color] = [Color("#4A4545"), Color("#7A7470"), Color("#5E5858")]
const LEAF_BURST_COLORS: Array[Color] = [Color(0.24, 0.47, 0.18), Color(0.46, 0.68, 0.25), Color(0.09, 0.19, 0.1)]

## The skeleton, in drawing coordinates (facing right, origin at the feet).
const BODY_CENTER: Vector2 = Vector2(-0.6, -5.2)
const BODY_RADII: Vector2 = Vector2(4.4, 3.2)
const BODY_ANGLE: float = -0.18
const HEAD_CENTER: Vector2 = Vector2(3.8, -8.4)
const HEAD_RADIUS: float = 3.0
const SHOULDER_POINT: Vector2 = Vector2(1.9, -6.0)
const HIP_POINT: Vector2 = Vector2(-3.0, -4.0)
const FRONT_HIP_POINT: Vector2 = Vector2(0.4, -3.4)
const TAIL_BASE: Vector2 = Vector2(-4.6, -5.4)
const TAIL_STEPS: int = 9
const TAIL_STEP_LENGTH: float = 1.5
## Leaves along its back, relative to BODY_CENTER.
const BACK_LEAVES: Array[Vector2] = [Vector2(-3.2, -1.6), Vector2(-1.6, -2.6), Vector2(0.2, -3.0),
	Vector2(1.9, -2.6), Vector2(-0.8, -0.6)]
## Glowing cracks while it burns, and ash specks as it burns out (drawing coordinates).
const EMBER_CRACKS: Array[PackedVector2Array] = [
	[Vector2(-4.0, -5.0), Vector2(-2.0, -4.0), Vector2(-0.5, -5.5), Vector2(1.5, -4.5)],
	[Vector2(-2.5, -7.0), Vector2(-1.0, -6.5), Vector2(0.5, -7.5)],
	[Vector2(2.5, -9.5), Vector2(3.5, -8.0), Vector2(5.0, -8.5)],
]
const ASH_SPECKS: Array[Vector2] = [Vector2(-3, -5), Vector2(0, -7), Vector2(3, -9), Vector2(-1, -4),
	Vector2(2, -6), Vector2(-3, -7), Vector2(4, -7), Vector2(1, -3)]

## The creeping burn (drawing x, px): the flame starts this far out on the side it
## came from, crosses the body in the first BURN_CREEP_SHARE of the torch run, and
## from BURN_ASH_START on the fire dies down to ash.
const BURN_HALF_WIDTH: float = 6.0
const BURN_CREEP_SHARE: float = 0.35
const BURN_ASH_START: float = 0.68
## Torch flames: where each sits (drawing coordinates) and its full length, px. The
## flames grow as the creeping fire reaches them and shrink away as it turns to ash.
const TORCH_FLAME_SPOTS: Array[Vector2] = [Vector2(-3.0, -7.0), Vector2(0.0, -8.0), Vector2(3.5, -10.5)]
const TORCH_FLAME_LENGTHS: Array[float] = [7.0, 10.0, 7.0]
## Smoke puffs while smoldering, seconds apart.
const SMOLDER_SMOKE_INTERVAL: float = 0.3

@export var body_size: Vector2 = Vector2(10, 10):
	set(value):
		body_size = value
		_resize_shapes()
		queue_redraw()
## Which way it starts running: 1 = right, -1 = left.
@export_enum("Left:-1", "Right:1") var start_direction: int = 1:
	set(value):
		start_direction = value
		queue_redraw()
## On: it hops gaps on its route (see the header). Off: it turns at every ledge.
@export var hops_gaps: bool = true
## What each kind of hit does to it. Empty = the table in _make_immunity().
@export var immunity: ElementImmunity
## Same gravity and fall cap as the player, wisp and crate.
@export var gravity: float = 900.0
@export var max_fall_speed: float = 300.0
## How fast a pushed monkey slows down on the ground / in the air, px/s².
@export var ground_friction: float = 320.0
@export var air_friction: float = 60.0
## A push along the ground also pops it a little into the air, px/s (like the wisp).
@export var knockback_hop_speed: float = 90.0
## Falling this far below where it was placed (a pit) = defeated.
@export var fall_out_distance: float = 200.0

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var state: State = State.RUN
## 1 = running right, -1 = left.
var run_direction: float = 1.0
## Seconds left stunned (PUSHED, SMOLDER) or burning (TORCH).
var stun_time_remaining: float = 0.0
var torch_time_remaining: float = 0.0
var ignite_cooldown: float = 0.0
var smoke_cooldown: float = 0.0
## Seconds since this hop started (it only counts as landed once it's been airborne).
var hop_time: float = 0.0
## Hot-air lift handed to us by heat sources this frame (apply_heat adds it up), and
## the one we act on (last frame's: sources may run before or after us).
var heat_lift_incoming: float = 0.0
## The torch run so far, 0..1, and the side the fire came from (WORLD terms: -1 =
## from the left, 1 = from the right, 0 = from below or unknown). Drive the look.
var burn_progress: float = 0.0
var burn_from_side: float = 0.0
## How charred it stays after a gust put it out, 0..1 (until R).
var scorch_amount: float = 0.0
var home_room: Room = null
var start_position: Vector2
var animation_time: float = 0.0
## Distance run, px: drives the stride (legs, arms, bob).
var stride_distance: float = 0.0

var hitbox: CollisionShape2D
var fire_hazard: FireHazard
var torch_flames: Array[FlameTongue] = []
var torch_embers: EmberEmitter


func _ready() -> void:
	collision_layer = 8 | 16  # bit values of layer 4 "pushable" and layer 5 "enemies"
	collision_mask = 1        # stands on and bumps into "world" only
	hitbox = CollisionShape2D.new()
	hitbox.shape = RectangleShape2D.new()
	add_child(hitbox)
	_resize_shapes()
	if Engine.is_editor_hint():
		return
	start_position = global_position
	run_direction = float(start_direction)
	if immunity == null:
		immunity = _make_immunity()
	_make_torch()
	add_to_group(EnemyHit.GROUP)
	add_to_group(Pushable.GROUP)
	add_to_group(Flammable.GROUP)
	add_to_group(Heat.RECEIVER_GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	home_room = Room.find_room_of(self)


## The monkey's row of the §7.2 table: only fire kills it (and, Stage F11b, the
## elephant's tail whip, which kills anything); rocks, gusts and earth push it. Spikes, crushing, orbs and dashes do nothing (a column under it stops
## short instead of crushing it).
static func _make_immunity() -> ElementImmunity:
	var kill: ElementImmunity.Response = ElementImmunity.Response.KILL
	var push: ElementImmunity.Response = ElementImmunity.Response.PUSH
	return ElementImmunity.from_table({
		EnemyHit.Type.FIREBALL: kill, EnemyHit.Type.FLAME: kill,
		EnemyHit.Type.BIG_ROCK: push, EnemyHit.Type.PERFECT_ROCK: push, EnemyHit.Type.SMALL_ROCK: push,
		EnemyHit.Type.GUST: push, EnemyHit.Type.EARTH_PUSH: push, EnemyHit.Type.WHIP: kill,
	})


## The flames on its back and its deadly area, off until it burns.
func _make_torch() -> void:
	fire_hazard = FireHazard.new()
	fire_hazard.name = "FireHazard"
	# The body plus the flames' feet: touching a burning monkey kills.
	fire_hazard.hazard_size = body_size + Vector2(2.0, 4.0)
	fire_hazard.position = Vector2(0.0, -body_size.y / 2.0 - 1.0)
	fire_hazard.active = false
	add_child(fire_hazard)
	var flame_merge: FlameMerge = FlameMerge.make(self)
	for flame_index: int in TORCH_FLAME_SPOTS.size():
		var flame: FlameTongue = FlameTongue.new()
		flame.base_width = 4.0
		flame.fan_width = 5.0
		flame.heat = 0.65
		flame.flicker_speed = 1.8  # panicky
		flame.lick_rate = 5.0
		flame.lick_size = 2.5
		flame.lick_speed = 25.0
		flame.smoke_rate = 3.0 if flame_index == 1 else 0.0
		flame.z_index = 1
		flame.visible = false
		add_child(flame)
		flame_merge.add_tongue(flame)
		torch_flames.append(flame)
	torch_embers = EmberEmitter.new()
	torch_embers.amount = 8
	torch_embers.direction = Vector2.UP
	torch_embers.spread = 50.0
	torch_embers.initial_velocity_min = 10.0
	torch_embers.initial_velocity_max = 30.0
	torch_embers.position = Vector2(0.0, -body_size.y * 0.6)
	torch_embers.emitting = false
	add_child(torch_embers)


func _physics_process(delta: float) -> void:
	animation_time += delta
	if Engine.is_editor_hint() or state == State.DEFEATED:
		return
	if not _is_awake():
		return
	var heat_lift: float = heat_lift_incoming
	heat_lift_incoming = 0.0

	match state:
		State.RUN:
			_run(delta, heat_lift, fire_tuning.monkey_run_speed)
		State.HOP:
			_hop(delta, heat_lift)
		State.TORCH:
			_burn(delta)
			if state != State.TORCH:
				return  # crumbled
			_run(delta, heat_lift, fire_tuning.monkey_torch_speed)
			_update_torch_flames()
		State.PUSHED, State.SMOLDER:
			_be_stunned(delta, heat_lift)

	_keep_inside_room()
	if global_position.y > start_position.y + fall_out_distance:
		defeat()
		return
	_check_contacts()
	queue_redraw()  # it animates every frame


## Running the route (RUN) or panicking (TORCH, which never hops).
func _run(delta: float, heat_lift: float, speed: float) -> void:
	_apply_vertical_forces(delta, heat_lift)
	if is_on_floor():
		if _is_wall_ahead():
			# Checked first: against a step the ledge ray below starts inside the
			# wall and finds no floor, which would read as a gap to hop.
			run_direction = -run_direction
		elif not _has_floor_ahead() and not _is_standing_on_column():
			if state == State.RUN and hops_gaps and _try_start_hop():
				return
			run_direction = -run_direction
		velocity.x = run_direction * speed
	else:
		# Lifted or thrown into the air: it flails, drifting to a stop sideways.
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
	var was_on_floor: bool = is_on_floor()
	_move(delta)
	# is_on_wall() is refreshed by the move just above.
	if is_on_wall() and was_on_floor:
		run_direction = -run_direction
	stride_distance += absf(velocity.x) * delta


func _hop(delta: float, heat_lift: float) -> void:
	hop_time += delta
	_apply_vertical_forces(delta, heat_lift)
	_move(delta)
	stride_distance += absf(velocity.x) * delta
	# Landed (not on the frame it took off, when it's still touching the near rim).
	if hop_time > 0.05 and is_on_floor():
		state = State.RUN


## Stunned (PUSHED) or put out (SMOLDER): slides to a stop, wakes up once landed.
func _be_stunned(delta: float, heat_lift: float) -> void:
	_apply_vertical_forces(delta, heat_lift)
	var friction: float = ground_friction if is_on_floor() else air_friction
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	_move(delta)
	if state == State.SMOLDER:
		smoke_cooldown -= delta
		if smoke_cooldown <= 0.0:
			smoke_cooldown = SMOLDER_SMOKE_INTERVAL
			SmokePuff.spawn(get_parent(), _get_center() + Vector2(0.0, -3.0), 1)
	stun_time_remaining -= delta
	if stun_time_remaining <= 0.0 and is_on_floor():
		state = State.RUN


## Gravity, or hot air lifting it: inside an updraft it eases toward rising at the
## lift x monkey_heat_lift_multiplier instead of falling, and its sideways speed dies
## down (the hot air carries it straight up instead of letting it sail through).
func _apply_vertical_forces(delta: float, heat_lift: float) -> void:
	if heat_lift > 0.0:
		var heat_accel_step: float = fire_tuning.monkey_heat_accel * delta
		velocity.y = move_toward(velocity.y, -heat_lift * fire_tuning.monkey_heat_lift_multiplier, heat_accel_step)
		velocity.x = move_toward(velocity.x, 0.0, heat_accel_step)
	elif not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


## move_and_slide(), then the wind carries it on top. The wind moves it as a separate
## step (move_and_collide) instead of being added to velocity, so a wall stopping the
## wind's push can't leave a backwards speed behind.
func _move(delta: float) -> void:
	move_and_slide()
	var wind: Vector2 = _get_wind() * fire_tuning.monkey_wind_carry
	if wind != Vector2.ZERO:
		move_and_collide(wind * delta)


## The wind at its middle, px/s: every (non-hot) wind zone it's in, added up.
func _get_wind() -> Vector2:
	var wind: Vector2 = Vector2.ZERO
	for zone: WindZone in get_tree().get_nodes_in_group(WindZone.GROUP):
		if zone.contains_point(_get_center()):
			wind += zone.get_wind_velocity()
	return wind


## A ledge ahead: is there a rim to hop to? If so, hops and returns true.
## Looks down every 2 px past the front edge, from monkey_hop_max_rise above the feet
## to 1 px below them: the first floor found is the far rim (the gap's own bottom is
## lower, so it's never mistaken for one). The hop is aimed so the whole body lands
## on it.
func _try_start_hop() -> bool:
	var half_width: float = body_size.x / 2.0
	var max_rise: float = fire_tuning.monkey_hop_max_rise
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var gap: float = 2.0
	while gap <= fire_tuning.monkey_hop_max_gap + 2.0:
		var probe_x: float = global_position.x + run_direction * (half_width + gap)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			Vector2(probe_x, global_position.y - max_rise), Vector2(probe_x, global_position.y + 1.0), 1)
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty() and (hit["normal"] as Vector2).y < -0.5:
			var rim: Vector2 = hit["position"]
			var landing: Vector2 = Vector2(rim.x + run_direction * (half_width + 2.0), rim.y)
			return _start_hop(landing)
		gap += 2.0
	return false


## Jumps at monkey_hop_speed upward with the sideways speed that lands on `landing`.
## Flight time from y(t) = -v0·t + g·t²/2 = drop: t = (v0 + sqrt(v0² + 2·g·drop)) / g
## (drop > 0 = the rim is lower). Returns false if the rim is too high to reach.
func _start_hop(landing: Vector2) -> bool:
	var hop_speed: float = fire_tuning.monkey_hop_speed
	var drop: float = landing.y - global_position.y
	var under_root: float = hop_speed * hop_speed + 2.0 * gravity * drop
	if under_root < 0.0:
		return false
	var flight_time: float = (hop_speed + sqrt(under_root)) / gravity
	velocity = Vector2((landing.x - global_position.x) / flight_time, -hop_speed)
	state = State.HOP
	hop_time = 0.0
	FX.play_sfx(&"monkey_hop")
	return true


## Is there something solid just past our front edge, at foot height? (A step or a
## wall: turn around, don't hop.)
func _is_wall_ahead() -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = Vector2(global_position.x + run_direction * (body_size.x / 2.0 + 1.0), global_position.y - 2.0)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


## Is there ground just past our front edge? Same ray as the wisp's.
func _has_floor_ahead() -> bool:
	var front_x: float = global_position.x + run_direction * (body_size.x / 2.0 + 1.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(front_x, global_position.y - 2.0), Vector2(front_x, global_position.y + 4.0), 1)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## On top of an Earth Column it doesn't turn at the edge (no route up there), like
## the wisp: it runs off and drops back down.
func _is_standing_on_column() -> bool:
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision.get_normal().y < -0.7 and collision.get_collider() is EarthColumn:
			return true
	return false


# --- Burning --------------------------------------------------------------------------

## Lit: the torch run starts (from any state but DEFEATED; again after a snuff).
## `fire_origin`: where the fire came from (world), so the flame creeps across from
## that side; NO_POSITION = from below (it walked into burning grass).
func _catch_fire(fire_origin: Vector2) -> void:
	if state == State.TORCH:
		return
	# It bolts the way it was going. A hop in progress keeps flying (the torch run
	# only steers on the ground), so a monkey lit mid-hop lands on the far rim.
	if absf(velocity.x) > 1.0:
		run_direction = signf(velocity.x)
	burn_from_side = 0.0
	if fire_origin != EnemyHit.NO_POSITION:
		var side_offset: float = fire_origin.x - global_position.x
		if absf(side_offset) > 2.0:
			burn_from_side = signf(side_offset)
	state = State.TORCH
	burn_progress = 0.0
	torch_time_remaining = fire_tuning.leafling_torch_time
	ignite_cooldown = 0.0
	fire_hazard.active = true
	torch_embers.emitting = true
	_update_torch_flames()
	var spark_point: Vector2 = _get_center() + Vector2(burn_from_side * BURN_HALF_WIDTH * 0.6, 0.0)
	EmberEmitter.burst(get_parent(), spark_point, 8, Vector2.UP, 160.0, 60.0)
	FireRing.spawn(get_parent(), spark_point, 8.0, 0.2)
	FX.shake(1.0, 0.08)
	FX.play_sfx(&"monkey_ignite")


## Each frame of the torch run: count down and light what it touches.
func _burn(delta: float) -> void:
	torch_time_remaining -= delta
	burn_progress = 1.0 - clampf(torch_time_remaining / maxf(fire_tuning.leafling_torch_time, 0.01), 0.0, 1.0)
	ignite_cooldown -= delta
	if ignite_cooldown <= 0.0:
		ignite_cooldown = fire_tuning.monkey_ignite_interval
		var reach: float = fire_tuning.monkey_ignite_reach
		Flammable.ignite_in_rect(get_tree(), get_hitbox_global_rect().grow(reach), self, self, reach)
	if torch_time_remaining <= 0.0:
		_crumble()


## Places and sizes the torch flames for this frame: mirrored with the facing, each
## one grown as far as the creeping fire has reached it, all shrinking as it turns
## to ash.
func _update_torch_flames() -> void:
	var fade: float = 1.0 - _get_ash_amount() * 0.95
	for flame_index: int in torch_flames.size():
		var flame: FlameTongue = torch_flames[flame_index]
		var spot: Vector2 = TORCH_FLAME_SPOTS[flame_index]
		var lit: float = _get_lit_amount(spot.x)
		flame.length = TORCH_FLAME_LENGTHS[flame_index] * lit * fade
		flame.visible = state == State.TORCH and flame.length > 0.8
		flame.position = Vector2(spot.x * run_direction, spot.y)
		# Panicking forward: the flames stream back off it.
		flame.rotation = -run_direction * 0.35


## A gust blew the fire out: charred, smoking, stunned for a moment. `push`: the
## gust (it still blows it about a bit).
func _snuff(push: Vector2) -> void:
	scorch_amount = maxf(scorch_amount, clampf(burn_progress / BURN_CREEP_SHARE, 0.3, 1.0))
	state = State.SMOLDER
	stun_time_remaining = fire_tuning.monkey_snuff_stun_time
	smoke_cooldown = 0.0
	_set_torch_visible(false)
	velocity = push * 0.5
	velocity.y = minf(velocity.y, -knockback_hop_speed * 0.5)
	SmokePuff.spawn(get_parent(), _get_center(), 3)
	FX.play_sfx(&"monkey_snuffed")


## Burnt out: a shower of ash, smoke and embers, and it's gone.
func _crumble() -> void:
	var center: Vector2 = _get_center()
	AshFall.spawn(get_parent(), center, 14, body_size, 0.3)
	PebbleField.leave_ash(get_tree(), center, 6, body_size, ASH_FLAKE_COLORS)
	SmokePuff.spawn(get_parent(), center, 4)
	EmberEmitter.burst(get_parent(), center, 6, Vector2.UP, 120.0, 40.0)
	FX.shake(1.0, 0.1)
	defeat()


## Whipped by the elephant's tail (Stage F11b): it bursts into leaves, no fire.
func _burst_into_leaves() -> void:
	var center: Vector2 = _get_center()
	PebbleField.leave_ash(get_tree(), center, 6, body_size, LEAF_BURST_COLORS)
	var leaves: CPUParticles2D = CPUParticles2D.new()
	leaves.one_shot = true
	leaves.explosiveness = 1.0
	leaves.amount = 14
	leaves.lifetime = 0.6
	leaves.spread = 180.0
	leaves.gravity = Vector2(0.0, 120.0)
	leaves.initial_velocity_min = 30.0
	leaves.initial_velocity_max = 80.0
	leaves.scale_amount_min = 1.0
	leaves.scale_amount_max = 2.0
	leaves.color = LEAF_LIGHT_COLOR
	get_parent().add_child(leaves)
	leaves.global_position = center
	leaves.emitting = true
	get_tree().create_timer(leaves.lifetime + 0.1, false).timeout.connect(leaves.queue_free)
	FX.shake(1.5, 0.1)
	defeat()


func _set_torch_visible(burning: bool) -> void:
	fire_hazard.active = burning
	torch_embers.emitting = burning
	for flame: FlameTongue in torch_flames:
		flame.visible = burning and flame.length > 0.8


# --- Hits -------------------------------------------------------------------------------

## The EnemyHit contract: every hit lands here (see _make_immunity for the table).
func receive_hit(hit: EnemyHit) -> ElementImmunity.Response:
	if state == State.DEFEATED:
		return ElementImmunity.Response.IGNORE
	# Wind against fire (§5.4): a gust puts a burning monkey out instead of pushing it.
	if hit.type == EnemyHit.Type.GUST and state == State.TORCH:
		_snuff(hit.push_velocity)
		return ElementImmunity.Response.PUSH
	var response: ElementImmunity.Response = immunity.get_response(hit.type)
	match response:
		ElementImmunity.Response.KILL:
			if hit.type == EnemyHit.Type.WHIP:
				_burst_into_leaves()
			else:
				_catch_fire(hit.get_origin())
		ElementImmunity.Response.PUSH, ElementImmunity.Response.STAGGER:
			_be_pushed(hit)
	return response


## Thrown by the hit and stunned. It's light: a gust throws it monkey_gust_multiplier
## harder than a wisp, a big rock monkey_big_rock_multiplier harder than a small one.
## A burning monkey keeps burning (only a gust puts it out): it's thrown, then runs on.
func _be_pushed(hit: EnemyHit) -> void:
	var push: Vector2 = hit.push_velocity
	match hit.type:
		EnemyHit.Type.GUST:
			push *= fire_tuning.monkey_gust_multiplier
		EnemyHit.Type.BIG_ROCK:
			push *= fire_tuning.monkey_big_rock_multiplier
	velocity = push
	if hit.type != EnemyHit.Type.EARTH_PUSH and push.y > -knockback_hop_speed:
		# Pushed along the ground (or down): a little hop too, so it flies instead of
		# skidding. A column's or snake's push is taken exactly as given.
		velocity.y = minf(velocity.y, -knockback_hop_speed)
	if state != State.TORCH:
		state = State.PUSHED
		stun_time_remaining = maxf(stun_time_remaining, fire_tuning.monkey_push_stun_time)


## The Pushable contract (gust, dash wake): a GUST hit.
func receive_gust(direction: Vector2, strength: float) -> void:
	receive_hit(EnemyHit.make(EnemyHit.Type.GUST, direction * strength))


## Touching the player (deadly unless stunned) or fire (it catches).
func _check_contacts() -> void:
	var my_rect: Rect2 = get_hitbox_global_rect()
	if state != State.TORCH and FireHazard.touches_fire(get_tree(), my_rect, self):
		receive_hit(EnemyHit.make(EnemyHit.Type.FLAME))
	if not is_deadly():
		return
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player != null and not player.is_dead() and my_rect.intersects(player.get_hitbox_rect()):
		player.die()


## Deadly to touch right now: running, hopping or burning (not while stunned).
func is_deadly() -> bool:
	return state == State.RUN or state == State.HOP or state == State.TORCH


# --- The Flammable contract -------------------------------------------------------------

## Any flame touching it (the plume, a splash, a bonfire, burning grass) is a FLAME hit.
func ignite(source: Node) -> void:
	receive_hit(EnemyHit.make(EnemyHit.Type.FLAME, Vector2.ZERO, source))


func is_burning() -> bool:
	return state == State.TORCH


func snuff() -> void:
	if state == State.TORCH:
		_snuff(Vector2.ZERO)


func get_fire_rect() -> Rect2:
	if state == State.DEFEATED:
		return Rect2()
	return get_hitbox_global_rect()


# --- The heat receiver contract (heat.gd) ----------------------------------------------

## Called by every heat source it's inside, once per physics frame.
func apply_heat(strength: float, _delta: float) -> void:
	if state != State.DEFEATED:
		heat_lift_incoming += strength


## It feels heat at its middle.
func get_heat_point() -> Vector2:
	return _get_center()


# --- Room ------------------------------------------------------------------------------

## Only the room the player is in is awake (like the sentries): creatures in other
## rooms stand still, so a world full of them costs nothing until you get there.
## Not in a Room (a test scene): always awake.
func _is_awake() -> bool:
	return home_room == null or GameState.current_room == null or GameState.current_room == home_room


## Gone until the room resets: hidden, no collision.
func defeat() -> void:
	if state == State.DEFEATED:
		return
	state = State.DEFEATED
	velocity = Vector2.ZERO
	visible = false
	collision_layer = 0
	_set_torch_visible(false)
	FX.play_sfx(&"monkey_defeated")
	defeated.emit()


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	global_position = start_position
	velocity = Vector2.ZERO
	run_direction = float(start_direction)
	state = State.RUN
	stun_time_remaining = 0.0
	torch_time_remaining = 0.0
	heat_lift_incoming = 0.0
	burn_progress = 0.0
	scorch_amount = 0.0
	visible = true
	collision_layer = 8 | 16
	_set_torch_visible(false)


## The room's left and right edges are walls (like the wisp): it never leaves its room.
func _keep_inside_room() -> void:
	if home_room == null:
		return
	var bounds: Rect2 = home_room.get_bounds()
	var half_width: float = body_size.x / 2.0
	var push_back: float = 0.0
	if global_position.x - half_width < bounds.position.x:
		push_back = bounds.position.x - (global_position.x - half_width)
	elif global_position.x + half_width > bounds.end.x:
		push_back = bounds.end.x - (global_position.x + half_width)
	if push_back == 0.0:
		return
	global_position.x += push_back
	run_direction = signf(push_back)
	velocity.x = 0.0


func get_hitbox_global_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x / 2.0, -body_size.y), body_size)


func _get_center() -> Vector2:
	return global_position + Vector2(0.0, -body_size.y / 2.0)


func _resize_shapes() -> void:
	if hitbox == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(hitbox.shape as RectangleShape2D).size = body_size
	hitbox.position = Vector2(0.0, -body_size.y / 2.0)


# --- Look --------------------------------------------------------------------------------

## The monkey is drawn from a few outlined shapes (ellipses, leaf diamonds and vine
## polylines), posed every frame from its state and stride, facing right and mirrored
## with draw_set_transform when it faces left:
##   tail     a vine curling back and up into a spiral, swaying, a leaf at the tip
##   body     a leaning oval of brambles, darker underneath, leaves along its back
##   head     a round bramble head with a pale face patch, a leaf ear, a leaf tuft
##            and one glowing enemy-purple eye
##   limbs    vine arms and legs, knuckle-walking with the stride
## A dark outline goes round every shape, so it reads against any background.
## Burning recolors each part by how far the creeping flame has reached it
## (_get_burn_color): bramble green -> glowing ember -> gray ash.
func _draw() -> void:
	var facing: float = float(start_direction) if Engine.is_editor_hint() else run_direction
	if not Engine.is_editor_hint() and absf(velocity.x) > 1.0 and (state == State.PUSHED or state == State.SMOLDER):
		facing = signf(velocity.x)
	var pose: Dictionary = _get_pose()
	draw_set_transform(Vector2(0.0, pose["bob"]), pose["lean"] * facing, Vector2(facing, 1.0))

	# Tail (behind everything).
	var tail: PackedVector2Array = _get_tail_points(pose["tail_stream"])
	_draw_vine(tail, _get_burn_color(VINE_COLOR, -6.0))
	_draw_leaf(tail[tail.size() - 1], -PI / 2.0 + sin(animation_time * 2.5) * 0.4, 3.0, _get_burn_color(LEAF_LIGHT_COLOR, -6.0))
	_draw_leaf(tail[tail.size() / 2], PI * 0.75, 2.4, _get_burn_color(LEAF_DARK_COLOR, -6.0))

	# Back leg and back arm (darker: they're behind the body).
	var back_vine: Color = _get_burn_color(VINE_COLOR.darkened(0.3), -2.0)
	_draw_vine(PackedVector2Array([HIP_POINT, pose["back_knee"], pose["back_foot"]]), back_vine)
	_draw_vine(PackedVector2Array([SHOULDER_POINT, pose["back_hand"]]), back_vine)

	# Body: outline, a shaded bramble oval, its lit upper part, leaves along the back.
	_fill_ellipse(BODY_CENTER, BODY_RADII + Vector2.ONE, BODY_ANGLE, OUTLINE_COLOR)
	_fill_ellipse(BODY_CENTER, BODY_RADII, BODY_ANGLE, _get_burn_color(BODY_SHADE_COLOR, 0.0))
	_fill_ellipse(BODY_CENTER + Vector2(-0.3, -0.7), BODY_RADII - Vector2(0.7, 0.9), BODY_ANGLE,
		_get_burn_color(BODY_COLOR, 0.0))
	for leaf_index: int in BACK_LEAVES.size():
		var leaf_spot: Vector2 = BODY_CENTER + BACK_LEAVES[leaf_index]
		var leaf_color: Color = LEAF_LIGHT_COLOR if leaf_index % 2 == 0 else LEAF_DARK_COLOR
		_draw_leaf(leaf_spot, -PI * 0.75 + leaf_index * 0.15, 2.6, _get_burn_color(leaf_color, leaf_spot.x))

	# Front leg.
	var front_vine: Color = _get_burn_color(VINE_COLOR, 1.0)
	_draw_vine(PackedVector2Array([FRONT_HIP_POINT, pose["front_knee"], pose["front_foot"]]), front_vine)

	# Head: outline, brambles, the ear, the tuft, the face patch, the eye.
	_fill_ellipse(HEAD_CENTER, Vector2.ONE * (HEAD_RADIUS + 1.0), 0.0, OUTLINE_COLOR)
	_fill_ellipse(HEAD_CENTER, Vector2.ONE * HEAD_RADIUS, 0.0, _get_burn_color(BODY_COLOR, HEAD_CENTER.x))
	_draw_leaf(HEAD_CENTER + Vector2(-2.4, -1.6), -PI * 0.8, 3.0, _get_burn_color(LEAF_LIGHT_COLOR, 2.0))
	for tuft_index: int in 3:
		var tuft_angle: float = -PI / 2.0 + (tuft_index - 1) * 0.45 + sin(animation_time * 4.0 + tuft_index) * 0.08
		_draw_leaf(HEAD_CENTER + Vector2((tuft_index - 1) * 1.1, -3.2), tuft_angle, 2.6,
			_get_burn_color(LEAF_DARK_COLOR if tuft_index == 1 else LEAF_LIGHT_COLOR, HEAD_CENTER.x))
	_fill_ellipse(HEAD_CENTER + Vector2(1.2, 0.7), Vector2(1.9, 1.6), 0.0, _get_burn_color(FACE_COLOR, 5.0))
	var eye: Vector2 = (HEAD_CENTER + Vector2(1.0, -0.6)).floor()
	if state == State.PUSHED or state == State.SMOLDER:
		# Dizzy "x" eye.
		draw_line(eye + Vector2(-0.5, -0.5), eye + Vector2(1.5, 1.5), OUTLINE_COLOR, 1.0)
		draw_line(eye + Vector2(1.5, -0.5), eye + Vector2(-0.5, 1.5), OUTLINE_COLOR, 1.0)
	else:
		draw_rect(Rect2(eye + Vector2(-1.0, 0.0), Vector2(1, 1)), OUTLINE_COLOR)
		draw_rect(Rect2(eye, Vector2(1, 1)), EYE_COLOR)

	# Front arm (in front of everything).
	_draw_vine(PackedVector2Array([SHOULDER_POINT, pose["front_elbow"], pose["front_hand"]]),
		_get_burn_color(VINE_COLOR, 2.0))

	_draw_embers_and_ash()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The pose for this frame: where the feet, knees and hands are, how far the body
## leans and bobs, and how much the tail streams back.
func _get_pose() -> Dictionary:
	var stride: float = stride_distance * 0.42
	var swing: float = sin(stride)
	var pose: Dictionary = {
		"bob": 0.0, "lean": -0.12, "tail_stream": 0.0,
		"back_knee": HIP_POINT + Vector2(0.5, 2.0), "back_foot": Vector2(-3.5 - swing * 2.2, 0.0),
		"front_knee": FRONT_HIP_POINT + Vector2(1.0, 1.8), "front_foot": Vector2(1.2 + swing * 2.2, 0.0),
		"back_hand": SHOULDER_POINT + Vector2(-1.5 - swing * 2.0, 5.0),
		"front_elbow": SHOULDER_POINT + Vector2(1.6 + swing, 2.6),
		"front_hand": SHOULDER_POINT + Vector2(2.6 + swing * 2.0, 5.0),
	}
	if Engine.is_editor_hint():
		return pose
	var in_air: bool = state == State.HOP or not is_on_floor()
	match state:
		State.RUN:
			pose["bob"] = -absf(sin(stride)) * 1.0
			pose["tail_stream"] = 0.3
		State.HOP:
			# Tucked: legs swept back, arms reaching forward for the far rim.
			pose["lean"] = -0.3
			pose["back_foot"] = Vector2(-5.0, -1.5)
			pose["front_foot"] = Vector2(-1.5, -0.5)
			pose["front_elbow"] = SHOULDER_POINT + Vector2(2.5, -0.5)
			pose["front_hand"] = SHOULDER_POINT + Vector2(4.5, -1.0)
			pose["back_hand"] = SHOULDER_POINT + Vector2(3.5, 0.5)
			pose["tail_stream"] = 0.8
		State.TORCH:
			# Panic: leaning hard, arms flailing over its head, tail streaming.
			pose["lean"] = -0.32
			pose["bob"] = -absf(sin(stride * 1.5)) * 1.5
			var flail: float = sin(animation_time * 26.0)
			pose["front_elbow"] = SHOULDER_POINT + Vector2(1.5, -2.5)
			pose["front_hand"] = SHOULDER_POINT + Vector2(1.5 + flail * 1.5, -5.5)
			pose["back_hand"] = SHOULDER_POINT + Vector2(-1.5 - flail * 1.5, -5.0)
			pose["tail_stream"] = 1.0
		State.PUSHED, State.SMOLDER:
			# Dazed: a wobble, limbs loose.
			pose["lean"] = sin(animation_time * 22.0) * 0.12
			pose["tail_stream"] = 0.5 if in_air else 0.0
	if in_air and state != State.HOP and state != State.TORCH:
		pose["back_foot"] = Vector2(-4.0, -1.0)
		pose["front_foot"] = Vector2(1.5, -1.0)
	return pose


## The tail: a vine from the rump curling back and up into a spiral. `stream` 0..1
## uncurls it (running fast, it trails behind). It sways on its own.
func _get_tail_points(stream: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([TAIL_BASE])
	var angle: float = PI + 0.15 - stream * 0.1
	var curl_per_step: float = lerpf(0.55, 0.22, stream)
	var point: Vector2 = TAIL_BASE
	for step: int in TAIL_STEPS:
		var along: float = float(step) / TAIL_STEPS
		# The curl tightens toward the tip; the sway travels down the tail.
		angle += curl_per_step * (0.4 + along * 1.4) + sin(animation_time * 3.0 - along * 3.0) * 0.06
		point += Vector2.from_angle(angle) * TAIL_STEP_LENGTH
		points.append(point)
	return points


## A vine: a dark outline under a thinner colored line.
func _draw_vine(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, OUTLINE_COLOR, 2.4)
	draw_polyline(points, color, 1.0)


## A leaf: a diamond `length` px long pointing along `angle`, outlined.
func _draw_leaf(center: Vector2, angle: float, length: float, color: Color) -> void:
	var along: Vector2 = Vector2.from_angle(angle) * length * 0.5
	var across: Vector2 = along.orthogonal() * 0.55
	var outline: PackedVector2Array = PackedVector2Array([center - along * 1.35, center + across * 1.6,
		center + along * 1.35, center - across * 1.6])
	draw_colored_polygon(outline, OUTLINE_COLOR)
	draw_colored_polygon(PackedVector2Array([center - along, center + across, center + along, center - across]), color)


## A filled ellipse (a 16-sided polygon) with radii `radii`, turned by `angle`.
func _fill_ellipse(center: Vector2, radii: Vector2, angle: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for corner: int in 16:
		var around: float = TAU * corner / 16.0
		points.append(center + Vector2(cos(around) * radii.x, sin(around) * radii.y).rotated(angle))
	draw_colored_polygon(points, color)


## Glowing cracks while it burns (brightest where the fire has been longest), then
## pale ash specks as it burns out.
func _draw_embers_and_ash() -> void:
	if state != State.TORCH and scorch_amount <= 0.0:
		return
	var ash: float = _get_ash_amount()
	for crack: PackedVector2Array in EMBER_CRACKS:
		var lit: float = _get_lit_amount(crack[0].x)
		if state != State.TORCH:
			lit = 0.0
		var glow: float = lit * (1.0 - ash) * (0.65 + 0.35 * sin(animation_time * 14.0 + crack[0].x))
		if glow > 0.05:
			draw_polyline(crack, Color(EMBER_GLOW_COLOR, glow), 1.0)
	if ash > 0.0:
		for speck_index: int in ASH_SPECKS.size():
			if float(speck_index) / ASH_SPECKS.size() < ash:
				draw_rect(Rect2(ASH_SPECKS[speck_index], Vector2.ONE), ASH_DARK_COLOR)


## `color` as burnt at drawing-x `local_x` (facing-right coordinates): charred a
## little after a snuff; while it burns, glowing ember where the flame has reached,
## then gray ash as it burns out.
func _get_burn_color(color: Color, local_x: float) -> Color:
	var burnt: Color = color.lerp(CHAR_COLOR, scorch_amount * 0.6)
	if state != State.TORCH:
		return burnt
	burnt = burnt.lerp(EMBER_BODY_COLOR, _get_lit_amount(local_x) * 0.85)
	return burnt.lerp(ASH_COLOR, _get_ash_amount())


## How far the creeping flame has taken the part at drawing-x `local_x`, 0..1. The
## flame starts on the side it came from (burn_from_side: -1 left, 1 right, 0 from
## below, in WORLD terms) and crosses the body in the first BURN_CREEP_SHARE of the
## torch run.
func _get_lit_amount(local_x: float) -> float:
	if state != State.TORCH:
		return 0.0
	var world_offset: float = local_x * run_direction
	var start_x: float = burn_from_side * BURN_HALF_WIDTH
	var span: float = BURN_HALF_WIDTH * (2.0 if burn_from_side != 0.0 else 1.0)
	var distance_share: float = absf(world_offset - start_x) / span
	var creep: float = burn_progress / BURN_CREEP_SHARE
	return clampf((creep - distance_share) * 3.0, 0.0, 1.0)


## How far it has burnt down to ash, 0..1 (the last part of the torch run).
func _get_ash_amount() -> float:
	if state != State.TORCH:
		return 0.0
	return clampf((burn_progress - BURN_ASH_START) / (1.0 - BURN_ASH_START), 0.0, 1.0)

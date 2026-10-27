class_name Player
extends CharacterBody2D
## The player character: a CharacterBody2D that moves with custom code.
##
## CharacterBody2D is Godot's node for bodies YOU control (as opposed to RigidBody2D,
## which the physics engine controls). You set `velocity`, call move_and_slide(),
## and Godot moves the body, stops it against solids, and updates is_on_floor() etc.
##
## Node layout (see player.tscn):
##   Player (this script)
##   ├─ CollisionShape2D   8x11 hitbox
##   ├─ SquashPivot        Node2D at the feet, scaled for squash & stretch
##   │  └─ Visual (ColorRect) white 8x11 rectangle
##   ├─ DeathBurst         CPUParticles2D, one-shot burst played by the Dead state
##   ├─ GlideAbility       glide stamina, stamina bar, glide effects (abilities/glide_ability.gd)
##   ├─ GustAbility        gust charges + pips, cooldown, cone hit, gust effects (abilities/gust_ability.gd)
##   ├─ AirBlastDebugDraw  F3 debug drawing of gust cones (abilities/air_blast_debug_draw.gd)
##   ├─ MovementEffects    squash & stretch and dust on jump / land / respawn (movement_effects.gd)
##   ├─ EarthBendAbility   shared Earth core: finds the earth we touch, runs the bend
##   │                     shadow (abilities/earth/earth_bend_ability.gd)
##   ├─ EarthColumnAbility Earth move A: raises a column at the bend's target
##   │                     (abilities/earth/earth_column_ability.gd)
##   ├─ BoulderAbility     Earth move S: tears a rock out right next to the feet and
##   │                     throws it (abilities/earth/boulder_ability.gd)
##   ├─ EarthSnakeAbility  the snake: a long A bend brings it out at the shadow, and
##   │                     it's steered (abilities/earth/earth_snake_ability.gd)
##   ├─ FireBar            the fire pips shared by the fire moves (abilities/fire/fire_bar.gd)
##   ├─ FirePipsDisplay    draws the pips as little flames over the head
##   │                     (abilities/fire/fire_pips_display.gd)
##   ├─ FlameJetAbility    Fire move W: pays the pip, thrust curve, plume and sputter
##   │                     (abilities/fire/flame_jet_ability.gd); Jetting moves the body
##   ├─ FireballAbility    Fire move Q: pip check, fizzle, aim preview, throw
##   │                     (abilities/fire/fireball_ability.gd); aims in GustAim
##   ├─ SwimAbility        how much of us is under water: slower runs, lower jumps,
##   │                     strokes (abilities/water/swim_ability.gd, Water §5.4)
##   └─ StateMachine       children: Idle, Run, Jump, Fall, WallSlide, Glide,
##                         GustAim, GustRecoil, EarthBend, Launched, BoulderHold,
##                         SnakeSteer, Jetting, Dead
##
## Elements: rooms say which elements work in them (Room.air_allowed / earth_allowed /
## fire_allowed).
## The wants_to_*() checks below ask is_element_allowed() before starting a move.
##
## Wind: WindZone areas call enter_wind_zone()/exit_wind_zone() on the player.
## get_wind_velocity() sums every zone we're in; the movement helpers below shift
## their target speeds by it (see apply_horizontal_movement / apply_gravity).
##
## Collision: the player is on physics layer 2 ("player") and collides with layer 1
## ("world"). Hazards (spikes) look for layer 2 to find the player.
##
## Death: anything deadly calls die(). The player switches to the Dead state and
## emits `died`. It does NOT respawn itself: RoomManager listens to `died`, waits,
## and calls respawn_at() with the current room's spawn point.
##
## The origin (0,0) of this node is at the player's FEET, centered horizontally.
## That makes placing the player on a surface trivial: put it at the surface's y.
##
## This script holds the shared movement helpers and the "forgiveness" timers
## (coyote time, jump buffer, wall-jump input lock). The states decide WHEN to use them.
## The debug overlay (scenes/ui/debug_overlay) reads the public vars below to display them.

## All feel values (speeds, gravity...). Edit player_tuning.tres, or this field
## in the Inspector, even while the game runs (Remote tab).
@export var tuning: PlayerTuning
## Earth bending feel values (Earth_bending.md). Same idea as `tuning`, kept in its
## own resource so each element's numbers stay together.
@export var earth_tuning: EarthTuning
## Fire bending feel values (Fire_bending.md), the third element's own resource.
@export var fire_tuning: FireTuning
## Water bending feel values (Water_bending.md), the fourth element's own resource.
## Rooms' WaterWorlds read the same .tres, so the F5 "Water" tab reaches them too.
@export var water_tuning: WaterTuning

## Floors with this method catch wind (duck typing, like the Pushable contract):
##   func absorb_gust_recoil(direction: Vector2, strength: float) -> void
## See get_wind_catching_floor().
const WIND_CATCHER_METHOD: StringName = &"absorb_gust_recoil"
## The group the player joins, so enemies (Sentry) can find it without a NodePath:
## get_tree().get_first_node_in_group(Player.GROUP).
const GROUP: StringName = &"player"
## Element names for is_element_allowed().
const ELEMENT_AIR: StringName = &"air"
const ELEMENT_EARTH: StringName = &"earth"
const ELEMENT_FIRE: StringName = &"fire"
const ELEMENT_WATER: StringName = &"water"

## Emitted once when the player dies (spikes, pit, or R). RoomManager handles the respawn.
signal died

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hitbox: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $SquashPivot/Visual
@onready var death_burst: CPUParticles2D = $DeathBurst
@onready var glide: GlideAbility = $GlideAbility
@onready var gust: GustAbility = $GustAbility
@onready var blast_debug: AirBlastDebugDraw = $AirBlastDebugDraw
@onready var movement_effects: MovementEffects = $MovementEffects
@onready var earth_bend: EarthBendAbility = $EarthBendAbility
@onready var earth_column: EarthColumnAbility = $EarthColumnAbility
@onready var boulder: BoulderAbility = $BoulderAbility
@onready var earth_snake: EarthSnakeAbility = $EarthSnakeAbility
@onready var fire_bar: FireBar = $FireBar
@onready var flame_jet: FlameJetAbility = $FlameJetAbility
@onready var fireball: FireballAbility = $FireballAbility
@onready var swim: SwimAbility = $SwimAbility

## Counts down after leaving the ground. While > 0 a ground jump is still allowed.
## Refilled to tuning.coyote_time every frame we stand on the floor.
var coyote_time_remaining: float = 0.0
## Counts down after the jump button is pressed. While > 0 the press is "remembered"
## and any state that can jump will do so.
var jump_buffer_remaining: float = 0.0
## Counts down after a wall jump. While > 0 horizontal input is ignored.
var wall_jump_lock_remaining: float = 0.0
## Which way the player faces: -1 left, +1 right. Follows the last held direction.
## Used as the gust direction when no arrow is held.
var facing_direction: float = 1.0
## Wind zones the player is currently inside. Filled by the zones themselves.
var active_wind_zones: Array[WindZone] = []
## The last DIAGONAL aim held, and when (real-time ms), for the diagonal grace window
## (see get_forgiving_aim_input). Updated every physics frame in _update_timers.
var last_diagonal_aim: Vector2 = Vector2.ZERO
var last_diagonal_msec: int = -100000
## Which ability the GustAim state aims for (GustAbility or FireballAbility), set just
## before switching to it. GustAim clears it on exit. See states/gust_aim.gd.
var aim_source: Node = null


func _ready() -> void:
	add_to_group(GROUP)
	# _ready() runs after all children are ready, so the states exist now.
	state_machine.setup(self)
	# Earth moves: each one tells the shared bend which key starts it. (Done here,
	# not in the moves' own _ready(): a parent's @onready vars, like earth_bend, are
	# only filled in just before the PARENT's _ready(), after its children's.)
	earth_bend.register_move(earth_column)
	# The snake has no key of its own (D is free): a long A bend brings it out.
	earth_bend.snake_move = earth_snake


## _physics_process runs at a fixed rate (60 times/s by default), independent of the
## frame rate. All movement code belongs here so behaviour is the same on any
## machine. `delta` is the time step (1/60 s).
func _physics_process(delta: float) -> void:
	# 1) Tick the timers first so every state sees this frame's values.
	_update_timers(delta)
	# 2) The active state reads input and updates `velocity` (and may change state).
	state_machine.physics_update(delta)
	# 3) If we're about to clip a ceiling corner, shift sideways to slip past it.
	_apply_ceiling_corner_correction(delta)
	# 4) Godot moves the body by velocity * delta, sliding along any solids it hits
	#    and refreshing is_on_floor() / is_on_ceiling() / is_on_wall().
	#    Remember the state BEFORE moving: after a landing, move_and_slide() has
	#    already zeroed velocity.y, so the impact speed is only known here.
	var was_on_floor: bool = is_on_floor()
	var fall_speed_before_move: float = velocity.y
	_move_without_wall_floor_snap()
	# 5) Landing = "not on the floor last frame, on it now". Checked here, in one
	#    place, instead of in every state that can land (Fall, Glide, Jetting...).
	if not was_on_floor and is_on_floor() and not is_dead():
		movement_effects.on_landed(fall_speed_before_move)


func _update_timers(delta: float) -> void:
	# How deep in water we are, for this frame's gravity, run speed and jumps.
	swim.update_submersion()
	# is_on_floor() reports the result of LAST frame's move_and_slide().
	if is_on_floor():
		coyote_time_remaining = tuning.coyote_time
	else:
		coyote_time_remaining = maxf(coyote_time_remaining - delta, 0.0)

	# is_action_just_pressed is true only on the one physics frame the key went down.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_remaining = tuning.jump_buffer_time
	else:
		jump_buffer_remaining = maxf(jump_buffer_remaining - delta, 0.0)

	wall_jump_lock_remaining = maxf(wall_jump_lock_remaining - delta, 0.0)

	# Remember diagonals for the gust's diagonal grace window. Real time (not delta)
	# because keys are released in real time, also during slow-motion aiming.
	var aim_input: Vector2 = get_aim_input()
	if aim_input.x != 0.0 and aim_input.y != 0.0:
		last_diagonal_aim = aim_input
		last_diagonal_msec = Time.get_ticks_msec()

	# Turn to face the held direction (not during the wall-jump lock, where input is ignored).
	var held_direction: float = signf(get_move_input())
	if held_direction != 0.0 and wall_jump_lock_remaining <= 0.0:
		facing_direction = held_direction


# --- Death, respawn, freezing -------------------------------------------------

## Kills the player. Safe to call repeatedly (e.g. spikes touching every frame):
## only the first call does anything until the player respawns.
func die() -> void:
	if is_dead():
		return
	state_machine.transition_to(&"Dead")
	FX.play_sfx(&"death")
	died.emit()


## The middle of the hitbox in world coordinates (the node's origin is at the feet).
func get_center() -> Vector2:
	return hitbox.global_position


## The hitbox as a rectangle in world coordinates (at the player's CURRENT position).
func get_hitbox_rect() -> Rect2:
	var hitbox_size: Vector2 = (hitbox.shape as RectangleShape2D).size
	return Rect2(get_center() - hitbox_size / 2.0, hitbox_size)


func is_dead() -> bool:
	return state_machine.current_state.name == &"Dead"


## Puts the player back at `spawn_position` (feet position), standing still, alive.
func respawn_at(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	coyote_time_remaining = 0.0
	jump_buffer_remaining = 0.0
	wall_jump_lock_remaining = 0.0
	glide.refill()
	gust.reset()
	# Fire pips are per room: back to what this room starts you with.
	fire_bar.reset_to_room_start()
	# Idle switches to Fall by itself on the next frame if there's no floor below.
	state_machine.transition_to(&"Idle")
	movement_effects.on_respawned()


## Stops (or resumes) all player movement and input, keeping the current velocity.
## Used during room transitions. set_physics_process(false) tells Godot to stop
## calling this node's _physics_process(), so nothing moves or reads input.
func set_frozen(frozen: bool) -> void:
	set_physics_process(not frozen)


# --- Input -------------------------------------------------------------------

## Horizontal input as -1 (left), 0 (none) or +1 (right) from the InputMap actions.
func get_move_input() -> float:
	return Input.get_axis("move_left", "move_right")


## The 8-way aim from the held arrows, as a unit vector, or ZERO when no arrow is
## held. normalized() makes diagonals the same length as straight aims (otherwise
## (1,1) would be ~1.41x stronger). The gust uses ZERO for its all-around burst.
func get_aim_input() -> Vector2:
	var aim: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	return aim.normalized()


## get_aim_input() with a DIAGONAL GRACE WINDOW, used by the gust. Releasing two keys
## at exactly the same moment is hard: Down usually comes up a few ms before Right,
## and the aim would snap to Right. So if a diagonal was held within the last
## tuning.gust_diagonal_grace_time seconds and only ONE of its two keys is held now,
## we still answer with the diagonal. Holding that one key longer than the window
## really switches to it. Nothing held still means ZERO (neutral gust).
func get_forgiving_aim_input() -> Vector2:
	var aim: Vector2 = get_aim_input()
	var is_single_axis: bool = (aim.x == 0.0) != (aim.y == 0.0)  # exactly one axis held
	if not is_single_axis or last_diagonal_aim == Vector2.ZERO:
		return aim
	var seconds_since_diagonal: float = (Time.get_ticks_msec() - last_diagonal_msec) / 1000.0
	if seconds_since_diagonal > tuning.gust_diagonal_grace_time:
		return aim
	# Is the held key one of the diagonal's two keys? (e.g. Right after Down+Right)
	var shares_horizontal: bool = aim.x != 0.0 and signf(aim.x) == signf(last_diagonal_aim.x)
	var shares_vertical: bool = aim.y != 0.0 and signf(aim.y) == signf(last_diagonal_aim.y)
	if shares_horizontal or shares_vertical:
		return last_diagonal_aim
	return aim


## Like get_aim_input(), but with nothing held, aim the way the player faces.
func get_aim_direction() -> Vector2:
	var aim: Vector2 = get_aim_input()
	if aim == Vector2.ZERO:
		return Vector2(facing_direction, 0.0)
	return aim


# --- Jumping -----------------------------------------------------------------

## True if a jump was pressed recently AND we are (or just were) on the ground.
## Both conditions use timers, which is what makes jumping forgiving:
##   - jump buffer: pressed up to 0.1 s BEFORE landing still counts
##   - coyote time: pressed up to 0.1 s AFTER leaving a ledge still counts
func can_ground_jump() -> bool:
	return jump_buffer_remaining > 0.0 and coyote_time_remaining > 0.0


## True if a jump was pressed recently and a wall is within reach on either side.
func can_wall_jump() -> bool:
	return jump_buffer_remaining > 0.0 and get_wall_direction() != 0.0


## Launches a normal jump. The Jump state then holds this upward speed while jump is held.
func start_ground_jump() -> void:
	consume_jump_press()
	# Standing in water, the jump is weaker the deeper we are (1 on dry land).
	velocity.y = tuning.jump_velocity * swim.get_jump_multiplier()
	movement_effects.on_jumped()


## Launches a wall jump away from the wall on side `wall_direction` (-1 left, +1 right).
func start_wall_jump(wall_direction: float) -> void:
	consume_jump_press()
	velocity.x = -wall_direction * tuning.wall_jump_horizontal_speed
	facing_direction = -wall_direction
	velocity.y = tuning.wall_jump_vertical_speed
	# Ignore input briefly: otherwise holding toward the wall (which you usually are,
	# since you were sliding on it) would cancel the push away on the very next frame.
	wall_jump_lock_remaining = tuning.wall_jump_input_lock_time
	movement_effects.on_wall_jumped(wall_direction)


## Uses up the buffered press and the coyote window so one press = one jump.
## Public because Fall also spends the press when it starts a glide.
func consume_jump_press() -> void:
	jump_buffer_remaining = 0.0
	coyote_time_remaining = 0.0


## Jump in deep water, not standing (Water_bending.md §5.4). Head under: a STROKE,
## our upward speed becomes swim_stroke_speed, so tapping jump swims us up. Head out
## (at the surface): a LEAP out, a full jump. Returns the state to switch to: &"Fall"
## after a stroke, &"Jump" after a leap, &"" if there was no swim move.
func try_swim_move() -> StringName:
	if jump_buffer_remaining <= 0.0 or is_on_floor() or not swim.is_in_water():
		return &""
	consume_jump_press()
	if swim.is_swimming():
		velocity.y = minf(velocity.y, -water_tuning.swim_stroke_speed)
		return &"Fall"
	velocity.y = tuning.jump_velocity * water_tuning.surface_leap_scale
	movement_effects.on_jumped()
	return &"Jump"


# --- Glide -------------------------------------------------------------------

## True when jump was pressed recently (buffered) and is still held, in the air,
## with stamina left. Fall checks this AFTER the coyote/wall jump checks, so a
## press that could jump still jumps. Holding jump from the original jump does
## NOT glide: that press was already spent by the jump.
func wants_to_glide() -> bool:
	return jump_buffer_remaining > 0.0 \
		and Input.is_action_pressed("jump") \
		and not is_on_floor() \
		and not swim.is_in_water() \
		and is_element_allowed(ELEMENT_AIR) \
		and glide.can_glide()


# --- Refills ------------------------------------------------------------------

## A wind crystal was touched: refill the breath (glide stamina) and the gust charge. Returns true if ANYTHING was restored, so the crystal
## is only used up when it helped. Lives here so the crystal doesn't need to know
## about each ability.
func refill_from_crystal() -> bool:
	# Both calls must run: `or` would skip the second one if the first returned true.
	var breath_restored: bool = glide.refill()
	var gust_restored: bool = gust.refill_charges()
	return breath_restored or gust_restored


## A gust diamond was touched: two gust charges for this airtime (GAME_DESIGN.md §5.3).
## Returns true if it helped (false on the ground, or already at two), so the
## diamond is only used up when it did.
func overcharge_from_diamond() -> bool:
	return gust.overcharge()


## A fire diamond was touched: `amount` pips (1 or 2), up to the cap. Returns true if
## at least one pip was added, so a diamond touched with a full bar stays where it is
## (like a wind crystal). Does nothing where fire isn't allowed.
func gain_fire_pips(amount: int) -> bool:
	if not is_element_allowed(ELEMENT_FIRE):
		return false
	return fire_bar.gain(amount) > 0


# --- Fire --------------------------------------------------------------------

## On the frame W (flame_jet) is pressed where fire is allowed: spends a pip and
## returns true, and the caller switches to the Jetting state. With no pip the jet
## sputters (smoke, no thrust) and this returns false, so nothing else changes.
## States that allow jetting check this right after the gust check.
func try_start_jet() -> bool:
	return flame_jet.try_start()


func is_jetting() -> bool:
	return state_machine.current_state.name == &"Jetting"


## On the frame Q (fireball) is pressed where fire is allowed, with a pip: makes the
## fireball the aim source and returns true, and the caller switches to GustAim
## (slow-motion aim; release throws). With no pip it fizzles and returns false.
## States that allow it check this right after the jet.
func try_start_fireball() -> bool:
	if not fireball.try_start():
		return false
	aim_source = fireball
	return true


# --- Gust --------------------------------------------------------------------

## True on the frame gust is pressed, if the cooldown is over and the gust can be
## paid for (a charge in the air, plus breath if that toggle is on).
## States that allow gusting check this first and switch to get_gust_start_state().
func wants_to_gust() -> bool:
	return Input.is_action_just_pressed("gust") and is_element_allowed(ELEMENT_AIR) \
		and gust.can_gust()


## Which state a gust press leads to: GustAim (slow-motion aiming, then fire on
## release) when tuning.gust_hold_to_aim is on, else straight to GustRecoil (fire now).
## Also makes the gust GustAim's aim source (the fireball shares that state).
func get_gust_start_state() -> StringName:
	aim_source = gust
	return &"GustAim" if tuning.gust_hold_to_aim else &"GustRecoil"


# --- Elements ----------------------------------------------------------------

## True if the current room lets us use `element` (ELEMENT_AIR, _EARTH, _FIRE or _WATER).
## Rooms store the flags (Room.air_allowed / earth_allowed / fire_allowed); GameState knows which
## room we're in. No room yet (a bare test scene) = everything allowed.
func is_element_allowed(element: StringName) -> bool:
	var room: Room = GameState.current_room
	if room == null:
		return true
	match element:
		ELEMENT_AIR:
			return room.air_allowed
		ELEMENT_EARTH:
			return room.earth_allowed
		ELEMENT_FIRE:
			return room.fire_allowed
		ELEMENT_WATER:
			return room.water_allowed
	return true


# --- Earth -------------------------------------------------------------------

## True if A does both column and snake here (the one-key experiment): on in every room
## through EarthTuning.one_key_column_snake, or in rooms with Room.one_key_column_snake.
func is_one_key_column_snake() -> bool:
	if earth_tuning.one_key_column_snake:
		return true
	var room: Room = GameState.current_room
	return room != null and room.one_key_column_snake


## True on the frame an earth key is pressed while we're touching fresh earth
## (standing on it or wall-sliding on it). Idle, Run and WallSlide check this
## after the gust check and switch to the EarthBend state.
## On true, the key and the start face are remembered (EarthBendAbility.queue_bend)
## for EarthBend.enter(): once the state has switched we're no longer "in WallSlide",
## so the wall face couldn't be found again from there.
func wants_to_bend() -> bool:
	return is_element_allowed(ELEMENT_EARTH) and earth_bend.queue_bend()


## On the frame S is pressed while touching fresh earth: tears a rock out of the
## tile just ahead of the feet (BoulderAbility.try_tear). Returns true if it did, and
## the caller (Idle, Run, WallSlide) switches to BoulderHold. No bend shadow and no
## slow motion: the rock always comes out right next to you (Earth_bending.md §11).
func try_tear_rock() -> bool:
	# A loose rock's press waiting to become a tap (shatter) or a hold (lift) is
	# settled here, every frame (BoulderAbility.take_ready_lift).
	if boulder.take_ready_lift():
		return true
	return Input.is_action_just_pressed(boulder.get_action()) 		and is_element_allowed(ELEMENT_EARTH) and boulder.try_tear()


## A RISING Earth Column's tip hit us (EarthColumn calls this once per column):
## thrown away from the tip, `direction` = the column's normal.
##   up (column under you):     the super jump, column_super_jump_speed straight up
##   down (from a ceiling):     column_launch_speed down
##   sideways (from a wall):    column_launch_speed sideways plus a lift upward, like
##                              Celeste's side springs (Earth_bending.md §11)
## Refills the breath (for mixed Earth + Air rooms), and the Launched state takes over.
func launch_from_column(direction: Vector2) -> void:
	if is_dead():
		return
	if direction.y < 0.0:
		# Sideways speed is kept: you can super-jump while running.
		velocity.y = -earth_tuning.column_super_jump_speed
	elif direction.y > 0.0:
		# maxf: keep a faster fall you already had.
		velocity.y = maxf(velocity.y, earth_tuning.column_launch_speed)
	else:
		velocity.x = direction.x * earth_tuning.column_launch_speed
		velocity.y = minf(velocity.y, -earth_tuning.column_side_launch_lift)
		facing_direction = signf(direction.x)
	# A buffered jump or coyote time must not turn the launch into a small jump.
	consume_jump_press()
	glide.refill()
	movement_effects.play_squash(tuning.jump_squash)
	state_machine.transition_to(&"Launched")


## Thrown by something (Stage F11b: a bucking elephant throws its rider up): takes
## `launch_velocity` as it is, like a column launch.
func launch_by(launch_velocity: Vector2) -> void:
	if is_dead():
		return
	velocity = launch_velocity
	consume_jump_press()
	glide.refill()
	movement_effects.play_squash(tuning.jump_squash)
	state_machine.transition_to(&"Launched")


# --- Wind --------------------------------------------------------------------

func enter_wind_zone(zone: WindZone) -> void:
	if not active_wind_zones.has(zone):
		active_wind_zones.append(zone)


func exit_wind_zone(zone: WindZone) -> void:
	active_wind_zones.erase(zone)


## Sum of the wind from every zone we're in, px/s. Overlapping zones add up.
## Standing on a wind-catching floor (a sail) shelters you: the sail catches the
## wind and carries you, so the wind doesn't also blow you along its deck.
func get_wind_velocity() -> Vector2:
	if get_wind_catching_floor() != null:
		return Vector2.ZERO
	var total_wind: Vector2 = Vector2.ZERO
	for zone: WindZone in active_wind_zones:
		total_wind += zone.get_wind_velocity()
	return total_wind


# --- Floor -------------------------------------------------------------------

## Floor normals must point at least this much "up" (dot with up_direction) to be
## real ground. 0.7 ~ 45 degrees, the same test get_floor_body() uses.
const MIN_FLOOR_NORMAL_UP: float = 0.7


## move_and_slide(), but never let a WALL pass for our floor.
## When we were on the floor last frame, move_and_slide() tries to keep us there:
##  - floor snapping pulls us down by up to floor_snap_length (1 px), and
##  - floor_block_on_wall (on by default) counts a wall that stops us as floor,
##    so a body standing at a wall's foot doesn't climb it.
## If the ground vanishes while we're pressed against a wall (teleported by a
## respawn, or the earth tile under us torn out), both kick in with no ground
## below: the wall becomes "our floor", normal (-1, 0), and we creep down it in Run
## instead of falling. On Godot 4.4 the seam between two wall tiles broke this by
## luck; since 4.5 TileMapLayer merges tiles into one collision shape, so nothing
## did. Fix: when our "floor" doesn't face up, switch both off for this one move.
func _move_without_wall_floor_snap() -> void:
	var is_floor_a_wall: bool = is_on_floor() and get_floor_normal().dot(up_direction) < MIN_FLOOR_NORMAL_UP
	if not is_floor_a_wall:
		move_and_slide()
		return
	var normal_snap_length: float = floor_snap_length
	var normal_block_on_wall: bool = floor_block_on_wall
	floor_snap_length = 0.0
	floor_block_on_wall = false
	move_and_slide()
	floor_snap_length = normal_snap_length
	floor_block_on_wall = normal_block_on_wall


## The body we're standing on (a floor, crate, platform...), or null in the air.
## move_and_slide() records every contact it made last frame as a "slide collision";
## the floor is the one whose normal points up (the surface faces up_direction).
func get_floor_body() -> Object:
	if not is_on_floor():
		return null
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision.get_normal().dot(up_direction) > MIN_FLOOR_NORMAL_UP:
			return collision.get_collider()
	return null


## The floor we stand on if it CATCHES WIND (has WIND_CATCHER_METHOD), else null.
## Such a floor takes the sideways recoil of our gusts (GustRecoil state) and
## shelters us from wind zones (get_wind_velocity). SailPlatform is one.
func get_wind_catching_floor() -> Object:
	var floor_body: Object = get_floor_body()
	if floor_body != null and floor_body.has_method(WIND_CATCHER_METHOD):
		return floor_body
	return null


# --- Walls -------------------------------------------------------------------

## Returns -1 if there's a wall within reach on the left, +1 on the right, 0 if none.
## If walls are on both sides (narrow shaft), the side you're pressing toward wins.
func get_wall_direction() -> float:
	var held_direction: float = signf(get_move_input())
	if held_direction != 0.0 and is_wall_on_side(held_direction):
		return held_direction
	if is_wall_on_side(1.0):
		return 1.0
	if is_wall_on_side(-1.0):
		return -1.0
	return 0.0


## True if moving `wall_jump_check_distance` px toward `side` would hit something.
## test_move() asks the physics engine "would this motion collide?" without moving.
func is_wall_on_side(side: float) -> bool:
	return test_move(global_transform, Vector2(side * tuning.wall_jump_check_distance, 0.0))


## True while airborne, holding toward a wall that is within reach, and not in the
## wall-jump input lock. This is the condition for entering/staying in WallSlide.
func is_pressing_into_wall() -> bool:
	var held_direction: float = signf(get_move_input())
	return held_direction != 0.0 \
		and wall_jump_lock_remaining <= 0.0 \
		and not is_on_floor() \
		and is_wall_on_side(held_direction)


# --- Shared movement ---------------------------------------------------------

## Pulls the player down, capped at terminal speed.
## move_toward(a, b, step) moves `a` toward `b` by at most `step`, never overshooting.
func apply_gravity(delta: float) -> void:
	var gravity_scale: float = 1.0
	# Apex half-gravity: near the top of the arc (vertical speed close to 0) and still
	# holding jump, fall more gently. This gives a moment of hang time to line up a landing.
	if Input.is_action_pressed("jump") and absf(velocity.y) < tuning.apex_gravity_threshold:
		gravity_scale = tuning.apex_gravity_multiplier

	# Fast-fall: holding Down raises the terminal speed. Releasing Down brings it back
	# down gradually (move_toward approaches max_fall_speed at the gravity rate, no sudden stop).
	var fall_speed_cap: float = tuning.max_fall_speed
	if Input.is_action_pressed("move_down"):
		fall_speed_cap = tuning.fast_fall_max_speed
	# Wind shifts the terminal speed: an updraft (negative y) lowers it a little.
	# Without gliding that only softens a fall; the Glide state is what rides it.
	fall_speed_cap += get_wind_velocity().y

	if swim.is_in_water():
		# In water (Water_bending.md §5.4): gravity and the fastest fall blend toward
		# the swimming values by how much of us is under, with no apex hang. Falling
		# in faster than that, the water brakes us hard: a plunge, not a stop.
		var share: float = swim.submerged_share
		var water_gravity: float = lerpf(tuning.gravity, water_tuning.swim_gravity, share)
		var water_sink_cap: float = lerpf(fall_speed_cap, water_tuning.swim_max_sink, share)
		if velocity.y > water_sink_cap:
			velocity.y = move_toward(velocity.y, water_sink_cap, water_tuning.swim_brake * share * delta)
		else:
			velocity.y = move_toward(velocity.y, water_sink_cap, water_gravity * delta)
		return

	velocity.y = move_toward(velocity.y, fall_speed_cap, tuning.gravity * gravity_scale * delta)


## Accelerates toward the held direction, or slows down if nothing is held.
## Airborne, acceleration is scaled by air_acceleration_multiplier for less control.
## During the wall-jump input lock, horizontal speed is left untouched (the push away
## from the wall plays out in full).
## `ignore_input` = behave as if nothing is held (used while aiming a gust, when the
## arrows aim instead of steering): you slow down on the ground, drift in the air.
## `overspeed_deceleration` (>= 0, airborne only): speed above max_run_speed fades at
## this gentler rate instead of normal air control, unless you steer against it.
## The Glide state uses it so a gust shove carries into the glide.
func apply_horizontal_movement(delta: float, ignore_input: bool = false,
		overspeed_deceleration: float = -1.0) -> void:
	if wall_jump_lock_remaining > 0.0:
		return

	var input_direction: float = 0.0 if ignore_input else get_move_input()
	var wind_x: float = get_wind_velocity().x
	if overspeed_deceleration >= 0.0 and not is_on_floor():
		# Speed relative to the wind, so a current isn't counted as "extra" speed.
		var own_speed: float = velocity.x - wind_x
		var is_overspeed: bool = absf(own_speed) > tuning.max_run_speed
		var is_steering_against: bool = input_direction != 0.0 and signf(input_direction) != signf(own_speed)
		if is_overspeed and not is_steering_against:
			# Fade toward run speed in the same direction, gently. Once at run speed,
			# the normal rules below take over again.
			var cruise_speed: float = signf(own_speed) * tuning.max_run_speed + wind_x
			velocity.x = move_toward(velocity.x, cruise_speed, overspeed_deceleration * delta)
			return
	var air_multiplier: float = 1.0 if is_on_floor() else tuning.air_acceleration_multiplier

	# Wind shifts the speed we settle at instead of adding a raw force. Standing
	# still in a 50 px/s current you drift at 50 px/s; running against it you make
	# 90 - 50 = 40 px/s; with it, 140 px/s. Air control still decides how fast we
	# get there, so wind catches you gradually.
	var wind_speed_x: float = get_wind_velocity().x

	if input_direction != 0.0:
		# Speed up toward full speed in the held direction. Reversing direction passes
		# through zero, so turning around happens at the same acceleration rate.
		# Water holds us back by how much of us is in it (1 on dry land).
		var target_speed: float = input_direction * tuning.max_run_speed * swim.get_speed_multiplier() + wind_speed_x
		velocity.x = move_toward(velocity.x, target_speed, tuning.run_acceleration * air_multiplier * delta)
	else:
		# Nothing held: slow toward the wind's speed (zero when there's no wind).
		velocity.x = move_toward(velocity.x, wind_speed_x, tuning.run_deceleration_ground * air_multiplier * delta)


## Ceiling corner correction: if we're moving up and this frame's motion would hit a
## ceiling, check whether shifting 1..N px sideways would clear it. If so, shift.
## Result: clipping the edge of a platform with your head slides you around it
## instead of killing the jump. A head-on bonk (more than N px of overlap) still bonks.
func _apply_ceiling_corner_correction(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var upward_motion: Vector2 = Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, upward_motion):
		return  # nothing above us, no correction needed

	# Try the side we're moving toward first, so the nudge goes with our momentum.
	var first_side: float = signf(velocity.x) if velocity.x != 0.0 else 1.0
	for offset_pixels: int in range(1, tuning.corner_correction_pixels + 1):
		for side: float in [first_side, -first_side]:
			var sideways_shift: Vector2 = Vector2(side * offset_pixels, 0.0)
			# The shift itself must be free (don't nudge into a wall)...
			if test_move(global_transform, sideways_shift):
				continue
			# ...and from the shifted spot, the upward motion must be clear.
			if not test_move(global_transform.translated(sideways_shift), upward_motion):
				position += sideways_shift
				return

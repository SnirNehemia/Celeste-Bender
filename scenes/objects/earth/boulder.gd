class_name Boulder
extends CharacterBody2D
## Boulder (Earth_bending.md §6, §11, Stages E4 + E4a): since E4a an 8x8 ROCK torn
## out of one earth tile (which becomes a hole), popped out, and thrown. Small: a
## ranged attack, or a one-tile step stuck into a far earth wall.
## BIG ROCK (Stage E4c2): holding S through the tear grows it into a 16x16 rock
## (BoulderAbility tears out the 2x2 block and calls grow(), which restarts the tear
## from the bigger hole). All size math uses `size`, so the code works for any size.
##
## Phases (`phase`):
##   POPPING  the time between the tear and the throw (the player can throw it all
##            through this phase). Three steps, all in game time:
##              1. TEAR: starts inside the hole it was torn from and rumbles slowly
##                 out of it, one tile along the surface's normal (boulder_tear_time)
##              2. HOP: jumps up boulder_hop_height (its bottom ends above the
##                 player's head) and drifts AWAY from the player (from a wall: away
##                 from the wall, faster), under gravity
##              3. lands with a thud and RESTS for boulder_land_rest_time, then
##                 settles as a LOOSE rock. (Hits a wall on the way: slides down it.)
##            PERFECT WINDOW: the moment the rock's middle comes back DOWN level
##            with the player's middle (± boulder_perfect_window; on the way up it
##            doesn't count, changed after the E4a play-test). Worked out in advance
##            from the hop's math (get_perfect_time); the player is rooted, so it holds.
##            The rest after landing is what keeps the way-down window open: a floor
##            rock lands almost exactly at the player's middle height.
##            Never thrown (the rest ran out, boulder_hold_time ran out, or the player
##            let go with Jump, drop()) = it settles as a LOOSE rock once it's down.
##            LIFTED (lift(), Stage E4c3): a loose rock jumps straight into step 2,
##            exactly like a fresh rock out of its hole.
##   FLYING   thrown. Flies straight for float_time_remaining (no gravity), then falls.
##            On impact:
##              - an EARTH face (the "Earth" layer, fresh or used): STUCK
##              - a risen Earth Column: bounces off it, keeps flying
##              - a CRACKED WALL (Stage E6): a BIG rock breaks it open; either size
##                shatters on it (a small rock is too light to break it)
##              - an ENEMY (Stage E6): hits it (an EnemyHit since F11: a wisp is knocked
##                back and defeated, a sentry destroyed), and shatters. Since E7 that
##                takes a BIG rock or a PERFECT throw; a sloppy small rock only shoves
##                a wisp (stunned) and clonks off a sentry
##              - anything else (gray rock, grass, a crate, a stuck boulder): shatters
##   STUCK    snapped onto the tile grid against the earth face it hit (and that
##            tile hardens, so it can't be torn out from under it): a solid
##            one-tile block on physics layer 1 ("world"), so you stand on it and wall-jump off
##            it. It tells the EarthLayer which cells it fills (like a risen column),
##            so the bend shadow crawls over it and you can start a bend standing on it.
##   LOOSE    (Stage E4c3) lying on the ground, never thrown: solid ("world", you can
##            stand on it), falls if the ground under it goes. Pressing S next to it
##            lifts it again (BoulderAbility, lift()): back to POPPING, no earth used.
##            At most loose_rock_max_per_room per room: the oldest crumbles.
##   SHATTERED a gravel burst, then the node is freed.
##
## HOVER AIM (the default since E7, EarthTuning.boulder_hover_aim, set per rock with
## set_hover_mode()): POPPING's step 2 is replaced. Out of its hole, the rock glides to
## a spot BESIDE the player at chest height (boulder_hover_rise_time) and hovers there
## while the arrows aim (BoulderAbility keeps the aim; aim_direction is only for
## drawing the aim ghosts). A faint contour of the rock starts wide and closes in
## on it over boulder_hover_ring_time: perfect_time is when it fits. Not thrown by
## boulder_hover_hold_time = it falls (the hop's step 2 without the jump) and lies loose.
##
## Created by BoulderAbility.try_tear(): Boulder.new(), setup(), then added as a child of
## the ROOM so Room.reset_objects() finds it (RESETTABLE_GROUP) and reset() frees it.
##
## Why a CharacterBody2D? move_and_collide() moves it and reports exactly what it hit
## (which node, which way the surface faces), which is all the impact rules need.
## While moving it's on NO physics layer (collision_layer = 0): nothing collides with
## it, so the player isn't bumped by a boulder flying past. Its mask is layer 1
## ("world"), so it hits tiles, columns, crates, stuck boulders, cracked walls and
## sentries (they're on layer 1 too), but passes through the player. A THROWN rock
## also looks at layer 5 ("enemies"), so it hits wisps (Stage E6); a hopping or loose
## rock doesn't, so tearing a rock next to a wisp never kills it by accident.
## Sentry orbs: every rock blocks them. Resting (loose, stuck) it's solid "world", so
## orbs pop on it; moving it pops the orbs it touches itself (_pop_touching_orbs).
##
## Origin: the CENTER of the boulder (unlike the player and crates, whose origin is at
## the feet), since it pops and flies in every direction.
##
## LOOK (Stage E4e): drawn as a lumpy stone, not a square: a polygon outline with
## random dents (made once per rock, _build_look), a crack and a few speckles, lit
## from the top-left. It TUMBLES while moving: `visual_angle` turns the drawing only
## (draw_set_transform). The hitbox never rotates, it stays an axis-aligned box,
## so the impact and sticking rules above don't change. Once it rests it turns back
## to the nearest quarter turn, so a stuck or loose rock sits square on the grid. A
## moving rock sheds a pebble now and then (PebbleField.leave_one_pebble).

enum Phase { POPPING, FLYING, STUCK, LOOSE, SHATTERED }

## Physics layer bit value of the player (layer 2): a rock doesn't turn solid while
## overlapping them.
const PLAYER_MASK: int = 2
## Physics layer bit values a moving rock collides with: world (1) always, enemies
## (layer 5) only once thrown (see the header).
const WORLD_MASK: int = 1
const ENEMY_MASK: int = 16
## Sentry orbs are Area2Ds on layer 4 ("pushable"): a moving rock pops them
## (_pop_touching_orbs). Max overlaps one check reports.
const ORB_MASK: int = 8
const MAX_ORB_RESULTS: int = 8
## Enemies are hit through the EnemyHit contract (Stage F11, scenes/enemies/enemy_hit.gd):
## the rock sends a BIG_ROCK, PERFECT_ROCK or SMALL_ROCK hit with its knockback and
## boulder_enemy_defeat_delay, and the enemy's ElementImmunity table decides (a wisp
## dies to a big or perfect rock and is only shoved by a sloppy small one; a sentry is
## destroyed; a vine monkey is only knocked back).

## The tear phase is over: the rock is out of its hole and about to hop. BoulderAbility
## listens: if S is still held, it grows the rock right then (grow()).
signal tore_free

## Group of every boulder, for tests and future enemy code.
const GROUP: StringName = &"boulder"
## Drawn in used-earth color (Earth_bending.md §2: creations are used earth), with a
## darker outline and a lighter top-left edge so it reads as a lump, not a tile.
const BODY_COLOR: Color = EarthLayer.USED_COLOR
const OUTLINE_COLOR: Color = Color(0.2, 0.13, 0.08)
const HIGHLIGHT_COLOR: Color = Color(0.48, 0.34, 0.2)
## The crack line and the dark speckles.
const CRACK_COLOR: Color = Color(0.17, 0.11, 0.06)
## Light comes from the top-left: outline edges facing this way get the highlight.
const LIGHT_DIRECTION: Vector2 = Vector2(-0.7071, -0.7071)
## An edge is "lit" when its outward direction is at least this close to the light
## (dot product: 1 = facing it exactly, 0 = side-on).
const LIT_EDGE_MIN_DOT: float = 0.35
## How long the boulder stays white after a perfect throw, seconds.
const PERFECT_FLASH_TIME: float = 0.12
## Physics layers checked when looking for a free spot to stick into: world (1),
## player (2) and enemies (5), so a boulder never sticks inside someone.
const STICK_BLOCKING_MASK: int = 1 | 2 | 16
## The free-spot check uses a box this much smaller on each side, px, so touching the
## earth face it sticks to doesn't count as overlapping it.
const STICK_CHECK_INSET: float = 0.5
## While moving, the hitbox is this much smaller than the rock on each side, px. A
## rock exactly as wide as its hole touches both neighbouring tiles, and Godot's
## collision safety margin (~0.08 px) then counts those as blocking: it couldn't pop
## out. Stuck, it gets its full size back (flush, solid ground).
const MOVING_HITBOX_INSET: float = 0.25

## Feel values (sizes, timings, speeds). The player's EarthTuning, passed in setup().
var earth_tuning: EarthTuning
## Side length, px: size, or big_rock_size once grown.
var size: float = 8.0
var phase: Phase = Phase.POPPING
## Unit vector out of the surface it was torn from: the tear direction.
var pop_normal: Vector2 = Vector2.UP
## Center position at the start of the tear (inside the hole: where the tile was).
var pop_start_position: Vector2
## Sideways speed of the hop, px/s (signed): away from the player, or the wall.
var hop_velocity_x: float = 0.0
## The player's middle (world y) when the rock was torn out. The player stays rooted
## while holding, so the perfect windows can be worked out once, in setup().
var player_center_y: float = 0.0
## Seconds (game time) since the tear started. The throw timing is measured on this.
var pop_elapsed: float = 0.0
## The pop_elapsed moment the rock's middle comes down level with the player's
## (the middle of the perfect window), or INF if it never does.
var perfect_time: float = INF
## POPPING steps: true once the hop has started / once it has landed.
var is_hopping: bool = false
var is_resting: bool = false
## Seconds of rest left after landing.
var rest_remaining: float = 0.0
## True once the player let go without throwing (Jump during BoulderHold): it can't
## be thrown any more, it just drops and shatters.
var is_dropped: bool = false
## FLYING: seconds of "no gravity" left, and seconds flown so far.
var float_time_remaining: float = 0.0
var flight_time: float = 0.0
## Seconds left of the white flash after a perfect throw.
var perfect_flash_remaining: float = 0.0
## True if the throw was perfect (in the window). Decides kill vs shove on enemies.
var thrown_perfectly: bool = false
## STUCK: the EarthLayer we registered our cells with (to unregister on reset).
var stuck_layer: EarthLayer = null
## LOOSE: the order it settled in (higher = newer), so the oldest crumbles first.
var loose_order: int = 0
## LOOSE and falling: the height it started falling from (INF while it's held up).
## A big rock that drops loose_rock_kill_drop px onto an enemy hits it (Stage F12).
var loose_fall_start_y: float = INF
## Shared by every boulder: the next loose_order to hand out. `static` = one value for
## the whole class, like a Python class attribute.
static var next_loose_order: int = 0

var hitbox: CollisionShape2D

## LOOK (Stage E4e, see the header). Its own random numbers, so every rock is
## shaped differently. All points are relative to the center, before rotation.
var look_random: RandomNumberGenerator = RandomNumberGenerator.new()
## The lumpy outline (a closed polygon, in order around the center).
var outline_points: PackedVector2Array = PackedVector2Array()
## The crack: a short zigzag from the edge toward the middle.
var crack_points: PackedVector2Array = PackedVector2Array()
## Speckles: single pixels, light or dark (1 = light).
var speckle_points: PackedVector2Array = PackedVector2Array()
var speckle_is_light: PackedByteArray = PackedByteArray()
## How far the drawing is turned, radians. Looks only: the hitbox never rotates.
var visual_angle: float = 0.0
## Seconds until a moving rock sheds its next pebble.
var pebble_shed_remaining: float = 0.0

## HOVER AIM (see the header). True = this rock hovers instead of hopping.
var is_hover_mode: bool = false
## The player's middle and which side the rock hovers on (-1 left, +1 right), and half
## the player's size, px: the hover spot is worked out from these (get_hover_target).
var hover_anchor: Vector2 = Vector2.ZERO
var hover_side: float = 1.0
var hover_body_half_size: Vector2 = Vector2(4.0, 5.5)
## True while gliding to / hovering at the hover spot.
var is_hovering: bool = false
## Where the glide started, where it ends, and the pop_elapsed it started at.
var hover_from: Vector2 = Vector2.ZERO
var hover_target: Vector2 = Vector2.ZERO
var hover_start_time: float = 0.0
## The way a throw would go now (unit vector), for the aim ghosts. Set by
## BoulderAbility every frame while it hovers.
var aim_direction: Vector2 = Vector2.ZERO


## Call before adding to the tree. `start_center` = where the rock's center starts
## (the middle of the torn tile), `normal` = the surface's outward direction,
## `away_velocity_x` = the hop's sideways speed (signed, away from the player or the
## wall), `player_middle_y` = the player's middle (world y), for the perfect window.
func setup(start_center: Vector2, normal: Vector2, away_velocity_x: float, player_middle_y: float,
		tuning: EarthTuning) -> void:
	earth_tuning = tuning
	size = tuning.boulder_size
	pop_start_position = start_center
	pop_normal = normal
	hop_velocity_x = away_velocity_x
	player_center_y = player_middle_y
	perfect_time = get_perfect_time()


func _ready() -> void:
	collision_layer = 0  # nothing collides with a moving boulder (see the header)
	collision_mask = WORLD_MASK
	global_position = pop_start_position
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2.ONE * (size - MOVING_HITBOX_INSET * 2.0)
	hitbox = CollisionShape2D.new()
	hitbox.shape = shape
	add_child(hitbox)
	z_index = 4  # in front of tiles, behind the bend shadow (6) and gravel (5)
	look_random.randomize()
	_build_look()
	pebble_shed_remaining = _pick_pebble_shed_wait()


# --- Questions the ability asks ------------------------------------------------------

## Upward speed of the hop, px/s: enough to rise boulder_hop_height under gravity
## (v² = 2·g·h, the same formula as a jump).
func get_hop_speed() -> float:
	return sqrt(2.0 * earth_tuning.boulder_gravity * earth_tuning.boulder_hop_height)


## The pop_elapsed moment the rock's middle (y) comes back DOWN level with the
## player's, from the planned hop (a parabola). INF if the hop never gets that high.
## Collisions aren't predicted; the player is rooted, so this stays true unless the
## rock hits something on the way.
func get_perfect_time() -> float:
	var tear_time: float = maxf(earth_tuning.boulder_tear_time, 0.001)
	if is_hover_mode:
		# Hovering: out of the hole, glide over, then the contour closes in.
		return tear_time + earth_tuning.boulder_hover_rise_time + earth_tuning.boulder_hover_ring_time
	var hop_start_y: float = pop_start_position.y + pop_normal.y * size
	# During the hop: y(s) = hop_start_y - v·s + g·s²/2 (s = time since the hop
	# started; y grows downward). Level when y(s) = player_center_y, a quadratic:
	# (g/2)·s² - v·s + (hop_start_y - player_center_y) = 0. Its larger root is the
	# way down (the smaller one is the way up, which doesn't count).
	var gravity: float = earth_tuning.boulder_gravity
	var hop_speed: float = get_hop_speed()
	var discriminant: float = hop_speed * hop_speed - 2.0 * gravity * (hop_start_y - player_center_y)
	if discriminant < 0.0:
		return INF
	return tear_time + (hop_speed + sqrt(discriminant)) / gravity


## Seconds from now to the perfect moment (INF if there is none). BoulderAbility
## turns this into the throw quality.
func get_time_from_perfect() -> float:
	return absf(pop_elapsed - perfect_time)


## True once it grew into a big rock.
func is_big() -> bool:
	return size > earth_tuning.boulder_size


## True while lying loose on the ground (can be lifted again).
func is_loose() -> bool:
	return phase == Phase.LOOSE


## True while the player can still throw it.
func is_throwable() -> bool:
	return phase == Phase.POPPING and not is_dropped \
		and pop_elapsed < get_hold_time()


## How long after the tear it can be thrown, s (game time): longer while hovering.
func get_hold_time() -> float:
	return earth_tuning.boulder_hover_hold_time if is_hover_mode else earth_tuning.boulder_hold_time


## True inside the perfect window (±boulder_perfect_window around perfect_time).
func is_in_perfect_window() -> bool:
	return get_time_from_perfect() <= earth_tuning.boulder_perfect_window


# --- Actions -------------------------------------------------------------------------

## Throws it toward `direction` (unit vector) at `speed`, ignoring gravity for
## `float_time` seconds. `is_perfect` adds the white flash. Called by BoulderAbility.
func throw(direction: Vector2, speed: float, float_time: float, is_perfect: bool) -> void:
	if not is_throwable():
		return
	if not is_hopping and not is_hovering:
		# Still tearing out of its hole: yank it the rest of the way out first, or the
		# throw would slam it into the side of its own hole. (The way-up perfect window
		# starts while it's still coming out.)
		move_and_collide(pop_start_position + pop_normal * size - global_position)
	phase = Phase.FLYING
	collision_mask = WORLD_MASK | ENEMY_MASK  # thrown: now it hits wisps too
	velocity = direction * speed
	float_time_remaining = float_time
	flight_time = 0.0
	thrown_perfectly = is_perfect
	if is_perfect:
		perfect_flash_remaining = PERFECT_FLASH_TIME
	queue_redraw()


## Grows into a big rock: `new_center` = the middle of the 2x2 hole BoulderAbility
## just tore out, `new_size` its side length, px. The tear starts over from there (it
## rumbles out of the big hole, then hops), with its perfect moment worked out anew.
func grow(new_center: Vector2, new_size: float) -> void:
	size = new_size
	pop_start_position = new_center
	# Set directly, not move_and_collide: the rock jumps back into the (now empty) hole.
	global_position = new_center
	(hitbox.shape as RectangleShape2D).size = Vector2.ONE * (size - MOVING_HITBOX_INSET * 2.0)
	pop_elapsed = 0.0
	perfect_time = get_perfect_time()
	_build_look()  # a new, bigger stone shape
	queue_redraw()


## The player let go without throwing: it settles as a loose rock once it's down.
func drop() -> void:
	is_dropped = true


## HOVER AIM: `enabled` = this rock hovers beside the player instead of hopping.
## `player_middle` = the player's middle, `side` = -1 / +1 (which side it hovers on),
## `body_half_size` = half the player's size, px. Call before it leaves its hole
## (BoulderAbility does, right after setup() or before lift()).
func set_hover_mode(enabled: bool, player_middle: Vector2, side: float, body_half_size: Vector2) -> void:
	is_hover_mode = enabled
	hover_anchor = player_middle
	hover_side = side
	hover_body_half_size = body_half_size
	aim_direction = Vector2(side, 0.0)
	perfect_time = get_perfect_time()


## Lifts a LOOSE rock again (BoulderAbility, Stage E4c3): it hops exactly like a rock
## just out of its hole. `away_velocity_x` and `player_middle_y` as in setup().
func lift(away_velocity_x: float, player_middle_y: float) -> void:
	if phase != Phase.LOOSE:
		return
	phase = Phase.POPPING
	loose_fall_start_y = INF
	collision_layer = 0  # moving again: nothing collides with it
	(hitbox.shape as RectangleShape2D).size = Vector2.ONE * (size - MOVING_HITBOX_INSET * 2.0)
	# Pretend it just came out of a hole right under where it lies, so the hop and the
	# perfect-window math (get_perfect_time) work unchanged.
	pop_normal = Vector2.UP
	pop_start_position = global_position + Vector2.DOWN * size
	hop_velocity_x = away_velocity_x
	player_center_y = player_middle_y
	pop_elapsed = earth_tuning.boulder_tear_time
	perfect_time = get_perfect_time()
	is_resting = false
	is_dropped = false
	is_hopping = false
	if is_hover_mode:
		_start_hover()
	else:
		_start_hop()
	set_physics_process(true)


# --- Movement ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	perfect_flash_remaining = maxf(perfect_flash_remaining - delta, 0.0)
	match phase:
		Phase.POPPING:
			_update_pop(delta)
		Phase.FLYING:
			_update_flight(delta)
		Phase.LOOSE:
			_update_loose(delta)
	# A moving rock is on no physics layer, so orbs can't see it: it pops them itself.
	# (Resting rocks, loose or stuck, are solid "world" and orbs pop on them already.)
	if phase == Phase.POPPING or phase == Phase.FLYING:
		_pop_touching_orbs()
	queue_redraw()  # the white flash and the window tint change over time


## The pop: tear, hop, land and rest (see the header). Not thrown = loose once down.
func _update_pop(delta: float) -> void:
	pop_elapsed += delta
	var tear_time: float = maxf(earth_tuning.boulder_tear_time, 0.001)
	if is_hovering:
		_update_hover(delta)
	elif not is_hopping:
		# 1) Tear: slowly out of the hole, one tile along the normal. A straight
		#    line; the rumble is only drawn (see _draw).
		var progress: float = minf(pop_elapsed / tear_time, 1.0)
		var target: Vector2 = pop_start_position + pop_normal * size * progress
		move_and_collide(target - global_position)
		if progress >= 1.0:
			tore_free.emit()
			# Still out of the hole? A grow() during the signal restarted the tear instead.
			if pop_elapsed >= tear_time:
				if is_hover_mode:
					_start_hover()
				else:
					_start_hop()
	elif is_resting:
		# 3) Landed: rest a moment (still throwable), then lie there loose.
		_turn_toward_square(delta)
		rest_remaining -= delta
		if rest_remaining <= 0.0 or not is_throwable():
			_settle()
	else:
		# 2) Hop: a small jump under gravity, drifting away from the player.
		#    It turns gently the way it drifts, and sheds a pebble now and then.
		visual_angle = wrapf(visual_angle + _get_spin_sign(hop_velocity_x) * earth_tuning.rock_hop_spin_speed * delta, 0.0, TAU)
		_shed_pebbles(delta)
		velocity.y = move_toward(velocity.y, earth_tuning.boulder_max_fall_speed, earth_tuning.boulder_gravity * delta)
		# Coming down unthrown (off a ledge, or let go): a big one dropping far enough
		# onto an enemy hits it, like a loose rock (Stage F12).
		if velocity.y > 0.0 and loose_fall_start_y == INF:
			loose_fall_start_y = global_position.y
		if velocity.y > 0.0 and _drop_onto_enemies(velocity * delta):
			return
		var collision: KinematicCollision2D = move_and_collide(velocity * delta)
		if collision != null:
			_on_pop_contact(collision)
		elif pop_elapsed >= get_hold_time() + earth_tuning.boulder_max_flight_time:
			shatter()  # fell out of the room (a pit): don't fall forever


## HOVER AIM: out of the ground (or lifted), it starts gliding to its hover spot.
func _start_hover() -> void:
	is_hovering = true
	velocity = Vector2.ZERO
	hover_from = global_position
	hover_start_time = pop_elapsed
	hover_target = get_hover_target()
	FX.spawn_gravel(global_position, 3, Vector2.UP)


## Where it hovers: beside the player at their middle height, on hover_side, just
## clear of their body. A BIG rock is taller than half the player, so at their middle
## its bottom would sink into the floor: it's raised until its bottom is just above
## their feet (that sinking used to block both sides and send it over the head).
## If the spot is inside something solid (the player faces a wall), the other side;
## if that's blocked too, above their head.
func get_hover_target() -> Vector2:
	var side_offset: float = hover_body_half_size.x + earth_tuning.boulder_hover_gap + size / 2.0
	var feet_y: float = hover_anchor.y + hover_body_half_size.y
	var center_y: float = minf(hover_anchor.y, feet_y - size / 2.0 - 0.5)
	for side: float in [hover_side, -hover_side]:
		var spot: Vector2 = Vector2(hover_anchor.x + side * side_offset, center_y)
		if _is_hover_spot_free(spot):
			return spot
	return hover_anchor + Vector2(0.0, -(size + earth_tuning.boulder_hover_gap * 3.0))


## True if a rock centered at `center` would overlap no solid ("world").
func _is_hover_spot_free(center: Vector2) -> bool:
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	check_shape.size = Vector2.ONE * (size - STICK_CHECK_INSET * 2.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = WORLD_MASK
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## HOVER AIM: glide to the spot (fast, then easing in), hover, and when the hold time
## is over fall like a dropped rock (the hop code, with no jump: it lands loose).
func _update_hover(delta: float) -> void:
	if not is_throwable():
		is_hovering = false
		is_hopping = true
		velocity = Vector2.ZERO
		return
	var rise_time: float = maxf(earth_tuning.boulder_hover_rise_time, 0.001)
	var progress: float = clampf((pop_elapsed - hover_start_time) / rise_time, 0.0, 1.0)
	# Ease out: 1 - (1 - p)^2 starts fast and settles gently into place.
	var eased: float = 1.0 - (1.0 - progress) * (1.0 - progress)
	# Set directly: it floats, nothing pushes it (it's on no physics layer anyway).
	global_position = hover_from.lerp(hover_target, eased)
	_turn_toward_square(delta)


## HOVER AIM: how far the contour has closed, 0 (just appeared, widest) .. 1 (fits).
func get_hover_ring_progress() -> float:
	var ring_time: float = maxf(earth_tuning.boulder_hover_ring_time, 0.001)
	return clampf(1.0 - (perfect_time - pop_elapsed) / ring_time, 0.0, 1.0)


## Out of the ground: the hop starts, with a little burst of gravel from the hole.
func _start_hop() -> void:
	is_hopping = true
	velocity = Vector2(hop_velocity_x, -get_hop_speed())
	FX.spawn_gravel(global_position, 3, Vector2.UP)


## The hopping rock touched something. Ground under it: land and rest (or shatter, if
## the player let go). A wall: slide down it. A ceiling: stop rising.
func _on_pop_contact(collision: KinematicCollision2D) -> void:
	var surface_normal: Vector2 = collision.get_normal()
	if surface_normal.y < -0.7:
		if not is_throwable():
			_settle()  # let go of, or out of hold time: no rest, just lie there
			return
		is_resting = true
		rest_remaining = earth_tuning.boulder_land_rest_time
		velocity = Vector2.ZERO
		FX.spawn_gravel(collision.get_position(), 2, Vector2.UP)
		FX.play_sfx(&"boulder_land")
	else:
		velocity = velocity.slide(surface_normal)


## Down and never thrown: becomes a LOOSE rock (see the header).
func _settle() -> void:
	phase = Phase.LOOSE
	loose_fall_start_y = INF
	is_resting = false
	velocity = Vector2.ZERO
	loose_order = next_loose_order
	next_loose_order += 1
	_crumble_oldest_loose_rocks()


## Lying loose: solid once the player isn't overlapping it (it was passing through
## them while it moved), and falling if nothing holds it up.
func _update_loose(delta: float) -> void:
	_turn_toward_square(delta)
	if collision_layer == 0 and not _overlaps_player():
		collision_layer = 1  # solid "world": standable
		(hitbox.shape as RectangleShape2D).size = Vector2.ONE * size
	# test_move: "would moving this little bit down hit something?" without moving.
	if test_move(global_transform, Vector2.DOWN * 0.5):
		velocity = Vector2.ZERO
		loose_fall_start_y = INF
		return
	if loose_fall_start_y == INF:
		loose_fall_start_y = global_position.y
	velocity.y = move_toward(velocity.y, earth_tuning.boulder_max_fall_speed, earth_tuning.boulder_gravity * delta)
	if _drop_onto_enemies(velocity * delta):
		return
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision != null and collision.get_normal().y < -0.7:
		velocity = Vector2.ZERO


## A loose BIG rock that has fallen loose_rock_kill_drop px or more lands on the
## enemies under this frame's move like a thrown big rock (Stage F12): a BIG_ROCK hit
## each (their tables decide: a Shell or wisp dies, a monkey is knocked about), then
## it shatters, like a thrown rock that hits. Returns true if it did. A shorter drop,
## or a small rock: nothing (a loose rock passes through enemies, as ever).
func _drop_onto_enemies(motion: Vector2) -> bool:
	if not is_big() or global_position.y - loose_fall_start_y < earth_tuning.loose_rock_kill_drop:
		return false
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	check_shape.size = Vector2.ONE * size
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, global_position + motion)
	query.collision_mask = ENEMY_MASK
	query.exclude = [get_rid()]
	var hit_any: bool = false
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, MAX_ORB_RESULTS):
		var enemy: Node = EnemyHit.find_enemy(result["collider"])
		if enemy == null:
			continue
		EnemyHit.send(enemy, EnemyHit.Type.BIG_ROCK, Vector2(0.0, velocity.y), self,
			earth_tuning.boulder_enemy_defeat_delay)
		hit_any = true
	if hit_any:
		FX.freeze(0.05)
		shatter()
	return hit_any


## Pops every sentry orb (reflected or not) overlapping the rock: a rock you're holding
## or throwing is a shield, like a snake wall. Orbs are Area2Ds on layer 4
## ("pushable"), so the query looks at areas only.
func _pop_touching_orbs() -> void:
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	check_shape.size = Vector2.ONE * size
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = ORB_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	# The room's PebbleField sensor is on that layer too (it covers the whole room),
	# so ask for a few results and keep only the orbs.
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, MAX_ORB_RESULTS):
		var orb: SentryOrb = result.collider as SentryOrb
		if orb != null and not orb.is_popped:
			orb.pop()


## True if the player's body overlaps this rock right now.
func _overlaps_player() -> bool:
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	check_shape.size = Vector2.ONE * size
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = PLAYER_MASK
	query.collide_with_areas = false
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Keeps at most loose_rock_max_per_room loose rocks in our room (our parent): the
## oldest ones crumble.
func _crumble_oldest_loose_rocks() -> void:
	var loose_rocks: Array[Boulder] = []
	for sibling: Node in get_parent().get_children():
		var rock: Boulder = sibling as Boulder
		if rock != null and rock.is_loose():
			loose_rocks.append(rock)
	loose_rocks.sort_custom(func(a: Boulder, b: Boulder) -> bool: return a.loose_order < b.loose_order)
	while loose_rocks.size() > earth_tuning.loose_rock_max_per_room:
		loose_rocks.pop_front().shatter()


## Thrown: straight while floating, then gravity. Reacts to the first thing it hits.
func _update_flight(delta: float) -> void:
	flight_time += delta
	# Tumbles the way it flies (rolling forward); a big rock turns slower.
	var spin_speed: float = earth_tuning.rock_flight_spin_speed * earth_tuning.boulder_size / size
	visual_angle = wrapf(visual_angle + _get_spin_sign(velocity.x) * spin_speed * delta, 0.0, TAU)
	_shed_pebbles(delta)
	if float_time_remaining > 0.0:
		float_time_remaining -= delta
	else:
		velocity.y = move_toward(velocity.y, earth_tuning.boulder_max_fall_speed, earth_tuning.boulder_gravity * delta)
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision != null:
		_on_impact(collision)
	elif flight_time >= earth_tuning.boulder_max_flight_time:
		shatter()  # thrown out of the room: don't fly forever


## What happens on impact depends on WHAT it hit (the collider node).
func _on_impact(collision: KinematicCollision2D) -> void:
	var collider: Object = collision.get_collider()
	var surface_normal: Vector2 = collision.get_normal()  # points from the surface back at us
	if collider is EarthColumn:
		_bounce_off(surface_normal, collision.get_position())
	elif collider is CrackedWall:
		# Only a BIG rock breaks it; a small one is too light and just shatters on it.
		if is_big():
			(collider as CrackedWall).break_open(velocity.normalized(), earth_tuning)
		shatter()
	elif EnemyHit.is_enemy(collider):
		# An enemy: its table decides what the rock does (see the constants above).
		# move_and_collide() doesn't change `velocity`, so it's still the throw's.
		var rock_type: EnemyHit.Type = EnemyHit.Type.SMALL_ROCK
		if is_big():
			rock_type = EnemyHit.Type.BIG_ROCK
		elif thrown_perfectly:
			rock_type = EnemyHit.Type.PERFECT_ROCK
		var response: ElementImmunity.Response = EnemyHit.send(collider, rock_type,
			velocity.normalized() * earth_tuning.boulder_enemy_knockback_speed, self,
			earth_tuning.boulder_enemy_defeat_delay)
		if response == ElementImmunity.Response.KILL:
			FX.freeze(0.05)  # a crunchy hit (freeze frame)
		shatter()
	elif collider is EarthLayer:
		if not _stick_into(collider as EarthLayer, surface_normal, collision.get_position()):
			shatter()
	else:
		shatter()


## A risen column springs it away (Earth_bending.md §5): mirror the velocity off the
## column's face, and leave it at least boulder_column_bounce_speed along the normal.
func _bounce_off(surface_normal: Vector2, contact_point: Vector2) -> void:
	velocity = velocity.bounce(surface_normal)
	var speed_off_face: float = velocity.dot(surface_normal)
	if speed_off_face < earth_tuning.boulder_column_bounce_speed:
		velocity += surface_normal * (earth_tuning.boulder_column_bounce_speed - speed_off_face)
	FX.spawn_gravel(contact_point, earth_tuning.column_hit_gravel_count, surface_normal)
	FX.play_sfx(&"column_launch")


## Snaps onto the tile grid against the earth face it hit and becomes solid.
## Returns false (the caller shatters it) if no free spot is found there.
func _stick_into(earth_layer: EarthLayer, surface_normal: Vector2, contact_point: Vector2) -> bool:
	var spot: Vector2 = _find_stick_spot(earth_layer, surface_normal)
	if spot == Vector2.INF:
		return false
	phase = Phase.STUCK
	# Back to rock color: once stuck, _physics_process stops, so a perfect throw's
	# white flash would never count down and the rock would stay white.
	perfect_flash_remaining = 0.0
	velocity = Vector2.ZERO
	global_position = spot
	# Snap the tumble square at once: _physics_process (which eases it) stops below.
	visual_angle = _get_nearest_square_angle()
	collision_layer = 1  # solid "world" now: standable, wall-jumpable
	(hitbox.shape as RectangleShape2D).size = Vector2.ONE * size
	set_physics_process(false)
	stuck_layer = earth_layer
	earth_layer.register_column(self, _get_covered_cells(earth_layer))
	# Harden the earth it's stuck into, so a rock can't tear it out from under this one
	# and leave it floating: every tile just past our side that touched the face (one
	# for a small rock, two for a big one).
	# The hit normal snapped to the nearest axis (pointing out of the face, at us).
	var out_of_face: Vector2 = Vector2(signf(surface_normal.x), 0.0) if absf(surface_normal.x) > absf(surface_normal.y) \
		else Vector2(0.0, signf(surface_normal.y))
	var along_face: Vector2 = Vector2(-out_of_face.y, out_of_face.x)
	var tile_size: float = earth_layer.get_half_tile_size() * 2.0
	var tiles_across: int = roundi(size / tile_size)
	for tile_index: int in tiles_across:
		var offset_along: float = -size / 2.0 + tile_size * (tile_index + 0.5)
		var behind_point: Vector2 = global_position - out_of_face * (size / 2.0 + 1.0) + along_face * offset_along
		earth_layer.harden(earth_layer.get_cell_at(behind_point))
	FX.spawn_gravel(contact_point, earth_tuning.boulder_stick_gravel_count, surface_normal)
	FX.shake(earth_tuning.boulder_impact_shake_strength, earth_tuning.boulder_impact_shake_time)
	FX.play_sfx(&"boulder_stick")
	queue_redraw()
	return true


## A grid-aligned center for the stuck boulder, or Vector2.INF if none is free.
## Along the hit normal, the boulder's edge is rounded onto the face's grid line
## (it was touching it, give or take Godot's ~0.08 px safety margin). Across it, the
## nearest grid line is tried first, then the one on the other side.
func _find_stick_spot(earth_layer: EarthLayer, surface_normal: Vector2) -> Vector2:
	var tile_size: float = earth_layer.get_half_tile_size() * 2.0
	var half_size: float = size / 2.0
	# Work in the layer's own coordinates, where tile corners are multiples of tile_size.
	var corner: Vector2 = earth_layer.to_local(global_position) - Vector2.ONE * half_size
	var is_horizontal_hit: bool = absf(surface_normal.x) > absf(surface_normal.y)
	var along_normal: float = corner.x if is_horizontal_hit else corner.y
	var across: float = corner.y if is_horizontal_hit else corner.x
	var snapped_along: float = roundf(along_normal / tile_size) * tile_size
	var across_options: Array[float] = [roundf(across / tile_size) * tile_size]
	for other: float in [floorf(across / tile_size) * tile_size, ceilf(across / tile_size) * tile_size]:
		if not across_options.has(other):
			across_options.append(other)
	for snapped_across: float in across_options:
		var snapped_corner: Vector2 = Vector2(snapped_along, snapped_across) if is_horizontal_hit \
			else Vector2(snapped_across, snapped_along)
		var center: Vector2 = earth_layer.to_global(snapped_corner + Vector2.ONE * half_size)
		if _is_spot_free(center):
			return center
	return Vector2.INF


## True if a boulder centered at `center` would overlap no solid, player or enemy.
func _is_spot_free(center: Vector2) -> bool:
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	check_shape.size = Vector2.ONE * (size - STICK_CHECK_INSET * 2.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = STICK_BLOCKING_MASK
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## The tile cells the stuck rock fills (1 for an 8x8 rock), in `earth_layer`'s map
## coordinates.
func _get_covered_cells(earth_layer: EarthLayer) -> Array[Vector2i]:
	var half_size: float = size / 2.0
	# Just inside the top-left corner, so the cell lookup can't land on a neighbour.
	var top_left_cell: Vector2i = earth_layer.get_cell_at(global_position - Vector2.ONE * (half_size - 1.0))
	var tiles_across: int = roundi(size / (earth_layer.get_half_tile_size() * 2.0))
	var cells: Array[Vector2i] = []
	for x: int in tiles_across:
		for y: int in tiles_across:
			cells.append(top_left_cell + Vector2i(x, y))
	return cells


## Breaks into gravel and disappears. Also a STUCK rock (tap S, after Stage E7): it
## stops being part of the ground for the bend shadow first.
func shatter() -> void:
	if phase == Phase.SHATTERED:
		return
	phase = Phase.SHATTERED
	set_physics_process(false)
	if stuck_layer != null:
		stuck_layer.unregister_column(self)
		stuck_layer = null
	# A big rock breaks into more gravel (by area: 4x for 2x the size).
	var area_factor: int = roundi(pow(size / earth_tuning.boulder_size, 2.0))
	FX.spawn_gravel(global_position, earth_tuning.boulder_shatter_gravel_count * area_factor, Vector2.ZERO)
	FX.shake(earth_tuning.boulder_impact_shake_strength, earth_tuning.boulder_impact_shake_time)
	FX.play_sfx(&"boulder_shatter")
	queue_free()


## Called by Room.reset_objects() (death or R): boulders don't survive a reset.
func reset() -> void:
	if stuck_layer != null:
		stuck_layer.unregister_column(self)
	phase = Phase.SHATTERED
	queue_free()


# --- Look (Stage E4e) ----------------------------------------------------------------

## Makes this rock's shape: the lumpy outline, the crack and the speckles (see the
## header). Called once in _ready(), and again by grow() for the bigger size.
func _build_look() -> void:
	var half_size: float = size / 2.0
	# 8 corners for a small rock, 12 for a big one: more lumps on a bigger stone.
	var point_count: int = 8 + roundi(size - earth_tuning.boulder_size) / 2
	outline_points = PackedVector2Array()
	for point_index: int in point_count:
		# Evenly around the circle, each nudged a little so the lumps aren't regular.
		var angle: float = (point_index + look_random.randf_range(-0.25, 0.25)) * TAU / point_count
		# A "squircle" radius: half_size straight out (the tile's edge), a bit more
		# toward the corners (but well short of the square's corner), so the stone
		# still fills its tile like a foothold should. It's the superellipse
		# |x|^4 + |y|^4 = r^4, solved for the distance at this angle.
		var squircle_radius: float = half_size / pow(pow(absf(cos(angle)), 4.0) + pow(absf(sin(angle)), 4.0), 0.25)
		# Dents: each corner pulled in by up to 22%.
		outline_points.append(Vector2.from_angle(angle) * squircle_radius * look_random.randf_range(0.78, 1.0))
	# The crack: starts just inside a random corner and zigzags toward the middle,
	# stopping short of it (2 steps for a small rock, 3 for a big one).
	var crack_start: Vector2 = outline_points[look_random.randi() % point_count] * 0.85
	var crack_steps: int = 2 if not is_big() else 3
	crack_points = PackedVector2Array([crack_start])
	for step: int in crack_steps:
		var along: Vector2 = crack_start * (1.0 - 0.6 * float(step + 1) / crack_steps)
		var sideways: Vector2 = crack_start.orthogonal().normalized() * look_random.randf_range(-1.2, 1.2)
		crack_points.append(along + sideways)
	# Speckles: about one per 20 px² (3 on a small rock, ~13 on a big one), on whole
	# pixels (floor + 0.5 = a pixel's center), in the middle part of the stone.
	speckle_points = PackedVector2Array()
	speckle_is_light = PackedByteArray()
	for speckle_index: int in roundi(size * size / 20.0):
		var spot: Vector2 = Vector2.from_angle(look_random.randf() * TAU) * look_random.randf() * half_size * 0.6
		speckle_points.append(spot.floor() + Vector2.ONE * 0.5)
		speckle_is_light.append(1 if look_random.randf() < 0.5 else 0)


## +1 or -1: which way to turn for a sideways speed. Moving right turns clockwise,
## which is a POSITIVE angle in Godot (y points down), so it rolls forward.
func _get_spin_sign(sideways_speed: float) -> float:
	return -1.0 if sideways_speed < 0.0 else 1.0


## The quarter turn (0, 90°, 180°, 270°, 360°) closest to the current visual_angle.
func _get_nearest_square_angle() -> float:
	return roundf(visual_angle / (PI / 2.0)) * (PI / 2.0)


## Resting: turns the drawing back toward the nearest quarter turn.
func _turn_toward_square(delta: float) -> void:
	visual_angle = move_toward(visual_angle, _get_nearest_square_angle(), earth_tuning.rock_settle_spin_speed * delta)


## While moving: counts down, then drops one pebble off the back of the rock.
func _shed_pebbles(delta: float) -> void:
	pebble_shed_remaining -= delta
	if pebble_shed_remaining > 0.0:
		return
	pebble_shed_remaining = _pick_pebble_shed_wait()
	var backward: Vector2 = -velocity.normalized() if velocity != Vector2.ZERO else Vector2.ZERO
	PebbleField.leave_one_pebble(get_tree(), global_position + backward * size / 2.0, backward)


func _pick_pebble_shed_wait() -> float:
	return look_random.randf_range(earth_tuning.rock_pebble_shed_interval_min,
		earth_tuning.rock_pebble_shed_interval_max)


# --- Drawing -------------------------------------------------------------------------

## The lumpy stone (see "LOOK" in the header), turned by visual_angle: body, speckles,
## crack, a light rim on the edges facing the top-left, a dark outline. White while
## it can be thrown perfectly (the timing cue) and for a moment after a perfect throw.
func _draw() -> void:
	var rumble_offset: Vector2 = Vector2.ZERO
	if phase == Phase.POPPING and not is_hopping:
		# Tearing: rumble sideways along the surface (drawn only; the body moves straight).
		var along_surface: Vector2 = Vector2(-pop_normal.y, pop_normal.x)
		rumble_offset = along_surface * roundf(sin(pop_elapsed * 90.0) * earth_tuning.boulder_tear_rumble)
	# draw_set_transform: everything drawn after it is shifted and turned, like drawing
	# on a rotated sheet of paper. It changes only the picture, not the node.
	if is_hovering:
		# Hovering: a gentle bob (drawn only, like the rumble).
		rumble_offset.y += roundf(sin(pop_elapsed * 9.0) * earth_tuning.boulder_hover_bob)
	draw_set_transform(rumble_offset, visual_angle)
	var is_white: bool = perfect_flash_remaining > 0.0 or (is_throwable() and is_in_perfect_window())
	draw_colored_polygon(outline_points, Color.WHITE if is_white else BODY_COLOR)
	if not is_white:
		for speckle_index: int in speckle_points.size():
			var speckle_color: Color = HIGHLIGHT_COLOR if speckle_is_light[speckle_index] == 1 else CRACK_COLOR
			draw_rect(Rect2(speckle_points[speckle_index] - Vector2.ONE * 0.5, Vector2.ONE), speckle_color)
		draw_polyline(crack_points, CRACK_COLOR, 1.0)
		# The light rim: edges whose outward side faces the light in the WORLD (so the
		# lit side stays top-left while the stone tumbles), drawn 1 px inside.
		for point_index: int in outline_points.size():
			var edge_start: Vector2 = outline_points[point_index]
			var edge_end: Vector2 = outline_points[(point_index + 1) % outline_points.size()]
			var outward: Vector2 = ((edge_start + edge_end) / 2.0).normalized().rotated(visual_angle)
			if outward.dot(LIGHT_DIRECTION) >= LIT_EDGE_MIN_DOT:
				draw_line(edge_start - edge_start.normalized(), edge_end - edge_end.normalized(), HIGHLIGHT_COLOR, 1.0)
	# The outline: the polygon's points with the first one repeated, to close the loop.
	var closed_outline: PackedVector2Array = outline_points.duplicate()
	closed_outline.append(outline_points[0])
	draw_polyline(closed_outline, OUTLINE_COLOR, 1.0)
	if is_hovering and is_throwable():
		_draw_hover_guides(closed_outline)


## HOVER AIM: the timing contour closing in on the rock, and the aim ghosts.
## `closed_outline` = the rock's outline as a closed loop (drawn already).
func _draw_hover_guides(closed_outline: PackedVector2Array) -> void:
	var ring_progress: float = get_hover_ring_progress()
	# The contour: the rock's own outline, scaled from ring_start_scale down to 1. It
	# disappears once the perfect moment is past (late throws only get weaker).
	if pop_elapsed <= perfect_time + earth_tuning.boulder_perfect_window:
		var ring_scale: float = lerpf(earth_tuning.boulder_hover_ring_start_scale, 1.0, ring_progress)
		var ring_points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in closed_outline:
			ring_points.append(point * ring_scale)
		# Faint while wide, clearer as it closes in.
		draw_polyline(ring_points, Color(1.0, 1.0, 1.0, lerpf(0.15, 0.6, ring_progress)), 1.0)
	# The aim GHOSTS: faint copies of the rock's outline in the throw direction, each
	# fainter than the last, like the rock's path frozen in time. Drawn from the rock's
	# real middle (not the bob), turned like the rock so they match its shape.
	var direction: Vector2 = aim_direction.normalized()
	var spacing: float = size + earth_tuning.boulder_hover_ghost_gap
	var ghost_count: int = maxi(earth_tuning.boulder_hover_ghost_count, 0)
	for ghost_index: int in ghost_count:
		var ghost_offset: Vector2 = (direction * spacing * (ghost_index + 1)).round()
		draw_set_transform(ghost_offset, visual_angle)
		var fade: float = 1.0 - float(ghost_index) / maxf(ghost_count, 1)
		draw_colored_polygon(outline_points, Color(1.0, 1.0, 1.0, 0.08 * fade))
		draw_polyline(closed_outline, Color(1.0, 1.0, 1.0, 0.4 * fade), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0)

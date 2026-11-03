class_name WaterHandsAbility
extends Node2D
## WaterHandsAbility: the water hands (Water_bending.md §5.1, hold 1). A component
## under the player like the fireball:
##   Player > WaterHandsAbility
##
## Flow:
##   Idle/Run/Jump/Fall/WallSlide/Glide/Launched ask player.try_start_water_hands()
##   every frame -> try_start(): true on the frame 1 is pressed where Water is allowed,
##   and the state switches to WaterHolding (states/water_holding.gd), which:
##     - slows the world to hold_time_scale and calls begin_hold()
##     - lets go of the ball with release(true) when 1 comes up (a throw), or drops it
##       with release(false) on Jump (no boost, and you jump)
##     - leaves when is_holding() turns false (this node let go by itself: the ball
##       left the ring, or max_hold_time ran out)
##
## While holding, THIS node (in _process, on real time) does the rest:
##   - steers the BALL with the arrows: a world position with a velocity that
##     accelerates toward ball_move_speed in the held direction and drags to a stop
##     with none held; it stops at walls (it's water, it doesn't go through rock)
##   - GATHERS: WaterWorld.gather() takes water within gather_reach of the ball's edge
##     (loose drops first, then a pool under it) at gather_rate units a real second,
##     up to ball_max_units. That water is in the world's `held_area` while held, so
##     the books don't change
##   - hands the ball's dots to the WaterWorld (set_held_dots), which draws them with
##     the loose water as metaballs: a soft SQUARE as big as its water (its side is
##     the square root of its area: 4 units is exactly 2x2 tiles), wobbling (grid ice,
##     Stage I1: what you hold looks like the block it freezes into)
##   - works out the ICE PLAN (IcePlan: what 2 would make right now: a block, a
##     snake's tiles, a waterfall's wall or a raft) and draws it as the GHOST: the
##     tiles' outlines, dashed where the ice would hang in mid-air (it would crumble),
##     red where a cell is blocked (Stage I1)
##   - draws the RING (control_radius around you) and the empty ball's spark
##     (the W3 tendril to where it gathered from was removed in play-test 4: a
##     thin white line under the ball read as a glitch)
##   - lets go by itself when the ball leaves the ring (a throw) or after
##     max_hold_time real seconds
## Release gives the water back as loose particles moving at the steering velocity
## times throw_multiplier (WaterWorld.release_held).
##
## WHY _process and real time: in slow motion physics frames are rare (18 a second at
## 0.3x), so steering in _physics_process would be choppy. _process runs every
## rendered frame; its `delta` is slowed by Engine.time_scale too, so the real time
## comes from Time.get_ticks_usec() instead (the fireball's aim preview does the same).
##
## Projectiles: the ball's dots are water like any other (WaterWorld.is_water_near),
## so a fireball goes out in it and a sentry orb gets soaked (SentryOrb). No code
## here for that.
##
## Shoving (after play-test 3, _shove_touched): under water, a ball with water in it
## moving INTO something in WaterWorld.SOLID_GROUP (you, a floating crate) shoves it
## once the way the ball moves, like a gust: you get the velocity, a crate takes it
## through the Pushable contract (receive_launch). The ball stops (it gave its speed
## away) and can't shove the same thing again until it has left it.
##
## The SNAKE (Stage W4, Water_bending.md §5.1-5.2; the rope itself is WaterSnake):
##   - the ball steers as it always does (W3); HOW you ask for a snake is
##     WaterTuning.snake_trigger, a switch for play-testing (_is_snake_wanted): hold
##     3 (KEY), a double-tapped hold (DOUBLE_TAP), a slow lift (GENTLE) or a full
##     ball rested in the pool (REST). The ring turns green while a snake is ready
##   - the frame the ball's center comes up out of a pool, a snake wanted: a
##     WaterSnake starts (its foot on the surface under the ball). In GENTLE, a lift
##     too fast TEARS at once instead: a splash of the pool rains back
##   - with a snake, the ball moves at snake_speed_share of its speed (the water's
##     weight, a little slower)
##   - the snake tears by itself (too long, pool dry, foot out of water) or sinks
##     back (the ball back at the surface); after a tear the ball gathers nothing
##     until it has left the water's reach (gather_blocked)
##   - release() throws it as a RIBBON (WaterSnake.release): its water flows out
##     through the point the ball left from, along the ball's path. This node keeps
##     feeding it (flying_snake, _update_flying) after the hold ends. Jump drops it
##   - its head (the ball) SHOVES what it moves into once per touch, like a gust
##     (Pushable.try_push: crates, leaf piles, wisps; _shove_with_head)
##   - the snake is a TRAIL: it lies along the ball's own path in runs snapped to the
##     tile angles; its leash is its length along that path (snake_max_length): at
##     full length the ball stops unless it comes back. Frozen (2), it becomes the
##     tiles under its trail (the ghost shows them)
## The FROST CURSOR (Stage W8b, Water_bending.md §16 "Planned in Stage W8"): while the
## ball is EMPTY (nothing gathered yet, no snake) it's drawn as a frost cursor
## instead of the spark, and steers the same way. Where it touches a wet tile
## (frost_cursor_reach), the room's SurfaceGrid finds the CONNECTED WET PATCH
## (find_wet_patch, at most wet_freeze_max_tiles) and the ghost shows the coat on its
## open faces. 2 then coats it in ice (coat_held, asked by FreezeAbility before
## freeze_held) and the hold ends. As soon as the ball gathers water it's a ball again.
##
## Water DOUSES (Stage W4): the ball (with water in it) and every point of a snake
## put out what burns where they are (Flammable.douse_near).
##
## top_level = true: this node ignores the player's transform and draws in world
## coordinates.

## The ring: #7FC8FF at 25% alpha (Water_bending.md §12.1), brighter near its edge
## when the ball is about to leave it.
const RING_COLOR: Color = Color(0.498, 0.784, 1.0, 0.25)
const RING_WARN_COLOR: Color = Color(0.75, 0.89, 1.0, 0.7)
## The ring while a snake is ready (the next lift out of a pool raises one).
const RING_SNAKE_COLOR: Color = Color(0.55, 1.0, 0.8, 0.5)
## The empty ball: a small blue spark.
const SPARK_COLOR: Color = Color("#BFE4FF")
## Physics layers the snake's head shoves through (Pushable): 4 "pushable" and 5
## "enemies" (bit values).
const HEAD_SHOVE_MASK: int = 8 | 16
## The ghost of the ice plan (after the grid-ice play-test: quieter): a faint fill
## per tile and ONE faint outline round the whole shape; where the ice would hang in
## mid-air the outline pulses (between GHOST_PULSE_LOW and full, GHOST_PULSE_SPEED
## per real second); blocked cells a faint red fill, no lines.
const GHOST_COLOR: Color = Color(0.75, 0.95, 1.0, 0.45)
const GHOST_FILL_COLOR: Color = Color(0.75, 0.95, 1.0, 0.18)
const GHOST_BLOCKED_COLOR: Color = Color(1.0, 0.35, 0.35, 0.2)
const GHOST_PULSE_LOW: float = 0.25
const GHOST_PULSE_SPEED: float = 5.0
## How many px the drawn ball wobbles, and how fast (per real second).
const WOBBLE_PX: float = 0.6
const WOBBLE_SPEED: float = 7.0
## The frost cursor: a small snowflake this many px from its middle to each tip.
const FROST_CURSOR_SIZE: float = 2.5
## How fast it turns, radians per real second (slow: it reads as a snowflake, not a
## spinner).
const FROST_CURSOR_SPIN: float = 1.5
## The coat's ghost: this deep on each open face of the patch, px.
const COAT_GHOST_DEPTH: float = 2.0
## At most this many dots draw the ball (4 units would be 64 at drop size).
const MAX_BALL_DOTS: int = 64
## The ball starts warning (the ring brightens) past this share of the radius.
const RING_WARN_SHARE: float = 0.8

## Emitted when the ball is let go: the units, and the velocity they left with.
signal released(units: float, velocity: Vector2)

var player: Player
var holding: bool = false
## The ball, in world coordinates; its velocity in px per REAL second.
var ball_position: Vector2 = Vector2.ZERO
var ball_velocity: Vector2 = Vector2.ZERO
## Water in the ball, units (also in the world's held_area, in px²).
var ball_units: float = 0.0
## The room's water the ball belongs to (null in a room without water).
var world: WaterWorld
## Real time since the hold began, s, and the clock reading of the last _process.
var hold_real_time: float = 0.0
var last_usec: int = 0
## Gathered something this frame.
var is_gathering: bool = false
## For tests and the overlay: what the last release threw.
var last_release_units: float = 0.0
var last_release_velocity: Vector2 = Vector2.ZERO
## Things the ball shoved and is still touching (no second shove until it leaves),
## and the last shove's velocity (for tests).
var shoved_this_touch: Array[Node2D] = []
var last_shove_velocity: Vector2 = Vector2.ZERO
## The water snake hanging from the ball (Stage W4), or null.
var snake: WaterSnake = null
## A released snake still flying out as a ribbon, or null.
var flying_snake: WaterSnake = null
## The ball's center was inside a pool's water last frame (the snake starts when it
## comes out).
var was_in_water: bool = false
## After a tear the ball gathers nothing until it has left the water's reach.
var gather_blocked: bool = false
## Pushables the snake's head touched last frame (each is shoved once per touch).
var head_touching: Array[Node] = []
## For tests and the overlay: snakes raised, the last tear's reason, the last thing
## the head shoved, and how many burning things water put out.
var snakes_raised: int = 0
var last_tear_reason: String = ""
var last_head_shoved: Node = null
## Everything the head shoved this hold (tests: the crate, not the pebbles after it).
var head_shoved_this_hold: Array[Node] = []
var doused_count: int = 0
## The splash the last too-fast lift threw up, px² (tests).
var last_tear_splash_area: float = 0.0
## DOUBLE_TAP: 1 was down last frame, and when (real µs) it was pressed the last two
## times; this hold began with a double tap.
var was_hands_key_down: bool = false
var last_hands_press_usec: int = -1000000000
var previous_hands_press_usec: int = -1000000000
var is_snake_hold: bool = false
## REST: real seconds the full ball has sat still in the pool, and armed.
var rest_time: float = 0.0
var is_rest_armed: bool = false
## What 2 would freeze right now (grid ice, Stage I1), refreshed every frame while
## holding; null when not holding.
var plan: IcePlan = null
## The wet patch the frost cursor touches (Stage W8b): what 2 would coat in ice now,
## SurfaceGrid cells; empty when the ball isn't empty or touches nothing wet.
var coat_patch: Array[Vector2i] = []
## For tests and the overlay: tiles the last coat froze.
var last_coat_tiles: int = 0


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	global_position = Vector2.ZERO
	z_index = 40


## On the frame 1 is pressed in a room where Water is allowed. True = go to WaterHolding.
func try_start() -> bool:
	return Input.is_action_just_pressed("water_hands") and player.is_element_allowed(Player.ELEMENT_WATER)


func is_holding() -> bool:
	return holding


## Half the ball's side, px: it's a square whose area is its water (4 units = 16 px
## across). An empty ball is a 1.5 px spark.
func get_ball_radius() -> float:
	return maxf(1.5, sqrt(ball_units * WaterWorld.UNIT_AREA) * 0.5)


## Called by WaterHolding.enter(): an empty ball at your hands.
func begin_hold() -> void:
	var tuning: WaterTuning = player.water_tuning
	# Last throw's ribbon still flying: the rest of it goes at once.
	if flying_snake != null:
		flying_snake.finish_flight()
		flying_snake = null
	holding = true
	ball_units = 0.0
	ball_velocity = Vector2.ZERO
	hold_real_time = 0.0
	last_usec = Time.get_ticks_usec()
	ball_position = player.get_center() + Vector2(player.facing_direction * tuning.ball_start_distance, 0.0)
	if _is_solid(ball_position):
		ball_position = player.get_center()  # facing a wall: the ball starts at your chest
	world = WaterWorld.find_at(get_tree(), player.get_center())
	is_gathering = false
	shoved_this_touch.clear()
	snake = null
	was_in_water = false
	gather_blocked = false
	head_touching.clear()
	head_shoved_this_hold.clear()
	# The state starts the hold in a physics step, before this frame's _process saw
	# the press: note it here so the double tap counts this press.
	_track_hands_key()
	is_snake_hold = last_hands_press_usec - previous_hands_press_usec \
		<= int(tuning.snake_double_tap_window * 1000000.0)
	rest_time = 0.0
	is_rest_armed = false
	_update_ball(0.0)  # gathers at once if the hands start in water (swimming)
	queue_redraw()


## Lets go of the ball. `throw` true: the water keeps its steering velocity times
## throw_multiplier; false: it just drops (Jump). Safe to call when not holding.
func release(throw: bool) -> void:
	if not holding:
		return
	holding = false
	var tuning: WaterTuning = player.water_tuning
	var velocity: Vector2 = ball_velocity * tuning.throw_multiplier if throw else Vector2.ZERO
	last_release_units = ball_units
	last_release_velocity = velocity
	plan = null
	coat_patch.clear()
	if snake != null:
		# A ribbon: it flows out after the ball along the same path (or just falls).
		if snake.release(velocity):
			flying_snake = snake
		snake = null
	if world != null:
		var center: Vector2 = world.to_local(ball_position)
		if ball_units > 0.0:
			world.release_held(center, velocity, ball_units * WaterWorld.UNIT_AREA)
		else:
			world.sparkle(center)  # an empty ball fizzles
		world.set_held_dots(PackedVector2Array() if flying_snake == null
			else flying_snake.get_dots(0.0, hold_real_time))
	ball_units = 0.0
	is_gathering = false
	released.emit(last_release_units, velocity)
	queue_redraw()


## 2 while holding (grid ice, Stage I1): the ICE PLAN (the ghost) is made real by the
## WaterWorld: a block, a snake's tiles, a waterfall's wall or a raft. The hold ends
## (WaterHolding leaves when is_holding() turns false). Returns the freeze's id, or -1
## when the plan makes nothing (an empty ball, every cell blocked): nothing happens,
## the hold goes on.
func freeze_held() -> int:
	if not holding or world == null or plan == null or plan.is_empty():
		return -1
	var snake_area: float = snake.area if snake != null else 0.0
	var foot: Vector2 = world.to_local(snake.get_foot()) if snake != null else Vector2.ZERO
	var freeze_id: int = world.apply_ice_plan(plan, world.to_local(ball_position),
		ball_units * WaterWorld.UNIT_AREA, snake_area, foot)
	if freeze_id < 0:
		return -1
	if snake != null:
		snake.area = 0.0  # its water is ice now (or back in its pool)
		snake = null
	plan = null
	holding = false
	ball_units = 0.0
	is_gathering = false
	world.set_held_dots(PackedVector2Array() if flying_snake == null
		else flying_snake.get_dots(0.0, hold_real_time))
	queue_redraw()
	return freeze_id


## The EMPTY ball is a frost cursor (Stage W8b): no water in it and no snake.
func is_frost_cursor() -> bool:
	return holding and ball_units <= 0.0 and snake == null


## 2 while the frost cursor touches a wet patch (Stage W8b): the patch gets its icy
## coat (SurfaceGrid.coat) and the hold ends. Returns how many tiles were coated: 0 =
## no patch, the hold goes on (FreezeAbility then tries freeze_held).
func coat_held() -> int:
	if not is_frost_cursor() or coat_patch.is_empty() or world == null or world.surface_grid == null:
		return 0
	var count: int = world.surface_grid.coat(coat_patch)
	if count == 0:
		return 0
	last_coat_tiles = count
	coat_patch.clear()
	plan = null
	holding = false
	world.sparkle(world.to_local(ball_position), 4)
	world.set_held_dots(PackedVector2Array() if flying_snake == null
		else flying_snake.get_dots(0.0, hold_real_time))
	queue_redraw()
	return count


## Under water, the ball moving into you or a floating crate shoves it once (see the
## header). Each thing in WaterWorld.SOLID_GROUP has get_water_box(): its box.
## `push_velocity`: the ball's steering velocity this frame, from before walls
## stopped it (a crate is a wall to the ball: moving into one stops it, but it
## still shoves it).
func _shove_touched(push_velocity: Vector2) -> void:
	# Forget what the ball has left: it can be shoved again next time.
	for index: int in range(shoved_this_touch.size() - 1, -1, -1):
		var shoved: Node2D = shoved_this_touch[index]
		if not is_instance_valid(shoved) or not _ball_touches(shoved.call(&"get_water_box")):
			shoved_this_touch.remove_at(index)
	if ball_units <= 0.0 or push_velocity == Vector2.ZERO or world == null:
		return
	var tuning: WaterTuning = player.water_tuning
	for member: Node in get_tree().get_nodes_in_group(WaterWorld.SOLID_GROUP):
		var thing: Node2D = member as Node2D
		if thing == null or shoved_this_touch.has(thing):
			continue
		var box: Rect2 = thing.call(&"get_water_box")
		if box.size == Vector2.ZERO or not _ball_touches(box):
			continue
		# Moving INTO it: a ball moving away or past doesn't shove (so you can steer it
		# around yourself, from in front of you to behind you).
		if push_velocity.dot(box.get_center() - ball_position) <= 0.0:
			continue
		# In the water: you from ball_push_min_share under (the shove scaled by how much
		# of you is under); anything else while it FLOATS (wet and not standing on a
		# floor: a wave lapping at a crate on a ledge doesn't count).
		var share: float = world.get_submerged_share(box)
		if share <= 0.0 or (thing == player and share < tuning.ball_push_min_share):
			continue
		var body: CharacterBody2D = thing as CharacterBody2D
		if thing != player and body != null and body.is_on_floor():
			continue
		var shove: Vector2 = push_velocity.normalized() * tuning.ball_push_speed
		if thing == player:
			shove *= share
			player.velocity = shove
		else:
			Pushable.try_launch(thing, shove)  # a crate takes it as its new velocity
		shoved_this_touch.append(thing)
		last_shove_velocity = shove
		# The ball gave its speed away: it stops, and shoves one thing at a time.
		ball_velocity = Vector2.ZERO
		world.sparkle(world.to_local(ball_position), 4)
		return


## The snake's head moving into a pushable (a crate on a ledge, a leaf pile, a
## wisp) shoves it once, like a gust: Pushable.try_push in the way the ball moves.
## Out of water too (under water, _shove_touched does you and floating crates).
## `push_velocity`: the steering velocity from before walls stopped the ball.
func _shove_with_head(push_velocity: Vector2) -> void:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = get_ball_radius() + 1.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, ball_position)
	query.collision_mask = HEAD_SHOVE_MASK
	query.collide_with_areas = true
	var touching: Array[Node] = []
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var target: Node = Pushable.find_pushable(hit["collider"])
		# Orbs are soaked by the water, not pushed; you're never shoved by your own snake.
		if target == null or target is SentryOrb or target == player or touching.has(target):
			continue
		touching.append(target)
		var target_2d: Node2D = target as Node2D
		if head_touching.has(target) or push_velocity == Vector2.ZERO or target_2d == null:
			continue
		# Moving INTO it, as for the shove under water.
		if push_velocity.dot(target_2d.global_position - ball_position) <= 0.0:
			continue
		Pushable.try_push(target, push_velocity.normalized(), player.water_tuning.snake_shove_strength, ball_position)
		last_head_shoved = target
		head_shoved_this_hold.append(target)
		world.sparkle(world.to_local(ball_position), 4)
	head_touching = touching


## Water puts out what burns where it is: the ball (with water in it) and every
## point of a snake (Flammable.douse_near).
func _douse() -> void:
	var tuning: WaterTuning = player.water_tuning
	if ball_units > 0.0:
		doused_count += Flammable.douse_near(get_tree(), ball_position, get_ball_radius())
	if snake != null:
		for point: Vector2 in snake.points:
			doused_count += Flammable.douse_near(get_tree(), point, tuning.snake_width * 0.5)


## True if a pool's water reaches the ball: its surface under the ball is within
## the ball's radius plus gather_reach below it (or the ball is in it).
func _is_near_pool() -> bool:
	var surface_y: float = world.get_surface_y_at(world.to_local(ball_position))
	if is_nan(surface_y):
		return false
	var surface_world_y: float = world.to_global(Vector2(0.0, surface_y)).y
	return ball_position.y + get_ball_radius() + player.water_tuning.gather_reach >= surface_world_y


## The ball's center is inside a pool's water.
func _is_ball_in_pool() -> bool:
	return world != null and not world.find_water_at(world.to_local(ball_position)).is_empty()


## Notes presses of 1 (an edge: down now, up last time), for the double tap. Called
## every frame and from begin_hold; a second call in the same frame changes nothing.
func _track_hands_key() -> void:
	var is_down: bool = Input.is_action_pressed(&"water_hands")
	if is_down and not was_hands_key_down:
		previous_hands_press_usec = last_hands_press_usec
		last_hands_press_usec = Time.get_ticks_usec()
	was_hands_key_down = is_down


## Does the player want a snake on the next lift out of a pool? Per
## WaterTuning.snake_trigger (see the header). GENTLE has no "ready": its rule is the
## speed, checked in _on_left_pool.
func is_snake_ready() -> bool:
	match player.water_tuning.snake_trigger:
		WaterTuning.SnakeTrigger.KEY:
			return Input.is_action_pressed(&"water_snake")
		WaterTuning.SnakeTrigger.DOUBLE_TAP:
			return is_snake_hold
		WaterTuning.SnakeTrigger.REST:
			return is_rest_armed
	return false


## REST: the ball resting in a pool (no arrow held) for snake_rest_time arms the
## snake. It stays armed until the ball leaves the pool. Neither a full ball nor a
## stopped one is needed (play-test 4): filling (~0.7 s) and drifting to a stop
## (~0.4 s) hid the rest time, so tuning it changed nothing you could feel.
func _update_rest(real_delta: float, in_pool: bool) -> void:
	var tuning: WaterTuning = player.water_tuning
	if not in_pool:
		rest_time = 0.0
		is_rest_armed = false
		return
	if player.get_aim_input() == Vector2.ZERO:
		rest_time += real_delta
		if rest_time >= tuning.snake_rest_time:
			is_rest_armed = true
	else:
		rest_time = 0.0


## The ball came up out of a pool: a snake wanted, it follows the ball up. In
## GENTLE, slow enough raises one and too fast tears at once (a splash of the pool
## rains back); in the other modes, without a snake wanted the ball just leaves.
func _on_left_pool() -> void:
	var tuning: WaterTuning = player.water_tuning
	var local_ball: Vector2 = world.to_local(ball_position)
	var surface_y: float = world.get_surface_y_at(local_ball)
	if is_nan(surface_y) or world.is_black_at(local_ball):
		return  # no pool, or black water (Stage W7a): no snake rises from ink
	var surface_point: Vector2 = world.to_global(Vector2(local_ball.x, surface_y))
	var is_gentle: bool = tuning.snake_trigger == WaterTuning.SnakeTrigger.GENTLE
	if is_snake_ready() or (is_gentle and -ball_velocity.y <= tuning.snake_max_rise_speed):
		snake = WaterSnake.new(world, surface_point, ball_position)
		snakes_raised += 1
		return
	if not is_gentle:
		return
	last_tear_reason = "too fast"
	gather_blocked = true
	var got: float = world.draw_from_body_at(world.to_local(surface_point),
		tuning.snake_tear_splash_units * WaterWorld.UNIT_AREA)
	last_tear_splash_area = got
	if got > 0.0:
		world.release_held_along(PackedVector2Array([world.to_local(surface_point)]),
			PackedVector2Array([ball_velocity * 0.5]), PackedFloat32Array([got]), tuning.snake_width)


## True if the ball's circle overlaps `box` (world): the nearest point of the box
## is within its radius.
func _ball_touches(box: Rect2) -> bool:
	var nearest: Vector2 = ball_position.clamp(box.position, box.end)
	return nearest.distance_to(ball_position) <= get_ball_radius() + 1.0


func _process(delta: float) -> void:
	_track_hands_key()
	if flying_snake != null:
		_update_flying(delta)
	if not holding:
		return
	var now_usec: int = Time.get_ticks_usec()
	# Real seconds since the last frame, capped so a hitch can't fling the ball.
	var real_delta: float = minf((now_usec - last_usec) / 1000000.0, 0.05)
	last_usec = now_usec
	_update_ball(real_delta)
	queue_redraw()


## Feeds the thrown snake's ribbon out. `delta` is GAME time (_process's, slowed by
## Engine.time_scale), like the particles it turns into, so the ribbon stays one
## piece even while the slow motion eases out.
func _update_flying(delta: float) -> void:
	hold_real_time += delta  # keeps the ripple moving
	if not flying_snake.update_flight(delta):
		flying_snake = null
	if holding or not is_instance_valid(world):
		return  # a hold draws its own dots
	world.set_held_dots(PackedVector2Array() if flying_snake == null
		else flying_snake.get_dots(0.0, hold_real_time))


## One real-time step of the held ball: steer, stop at walls, gather, let go by
## itself if it left the ring or the time ran out, hand its dots to the world.
func _update_ball(real_delta: float) -> void:
	var tuning: WaterTuning = player.water_tuning
	hold_real_time += real_delta
	# Steering: toward full speed in the held direction, or drag to a stop.
	var input: Vector2 = player.get_aim_input()
	# A snake hanging from it: a little slower (the water's weight).
	var move_speed: float = tuning.ball_move_speed * (tuning.snake_speed_share if snake != null else 1.0)
	if input != Vector2.ZERO:
		ball_velocity = ball_velocity.move_toward(input * move_speed, tuning.ball_accel * real_delta)
	else:
		ball_velocity = ball_velocity.move_toward(Vector2.ZERO, tuning.ball_drag * real_delta)
	# Just caught by a new snake at full speed: down to the snake's speed at once.
	if snake != null:
		ball_velocity = ball_velocity.limit_length(move_speed)
	var push_velocity: Vector2 = ball_velocity
	# A snake is a LEASH along its trail: at full length the ball can only come back
	# along it (or turn: a new run starts shorter).
	if snake != null:
		var next_on_trail: Vector2 = ball_position + ball_velocity * real_delta
		var next_length: float = snake.get_trail_length_to(next_on_trail)
		if next_length > tuning.snake_max_length - 2.0 and next_length > snake.get_trail_length_to(ball_position):
			ball_velocity = Vector2.ZERO
	# Move one axis at a time, so a ball pushed into a floor still slides along it.
	# Only moving INTO rock is blocked: a ball that's somehow in rock (the player
	# pressed against a wall) can always move out of it.
	var step: Vector2 = ball_velocity * real_delta
	var starts_in_rock: bool = _is_solid(ball_position)
	if not starts_in_rock and _is_solid(ball_position + Vector2(step.x, 0.0)):
		ball_velocity.x = 0.0
	else:
		ball_position.x += step.x
	if not starts_in_rock and _is_solid(ball_position + Vector2(0.0, step.y)):
		ball_velocity.y = 0.0
	else:
		ball_position.y += step.y
	# Under water, moving into you or a crate: one shove.
	_shove_touched(push_velocity)
	# The snake: starts when the ball comes up out of a pool, then follows it.
	var in_pool: bool = _is_ball_in_pool()
	if world != null and real_delta > 0.0:
		if snake == null and was_in_water and not in_pool and ball_velocity.y < 0.0 and not gather_blocked:
			_on_left_pool()
		elif snake != null:
			match snake.update(real_delta, ball_position, ball_velocity):
				WaterSnake.Status.TORE:
					last_tear_reason = snake.tear_reason
					snake = null
					gather_blocked = true
				WaterSnake.Status.SANK:
					snake = null
		if snake != null:
			_shove_with_head(push_velocity)
		if gather_blocked and not in_pool and not _is_near_pool():
			gather_blocked = false  # out of the water's reach: it can gather again
		_douse()
		_update_rest(real_delta, in_pool)
	was_in_water = in_pool
	# Gathering.
	is_gathering = false
	if world != null and not gather_blocked and ball_units < tuning.ball_max_units and real_delta > 0.0:
		var wanted_units: float = minf(tuning.gather_rate * real_delta, tuning.ball_max_units - ball_units)
		var got_area: float = world.gather(world.to_local(ball_position), get_ball_radius() + tuning.gather_reach,
			wanted_units * WaterWorld.UNIT_AREA)
		if got_area > 0.0:
			ball_units += got_area / WaterWorld.UNIT_AREA
			is_gathering = true
	# Let go by itself: out of the ring (a throw: that's how you throw far), or time up.
	if ball_position.distance_to(player.get_center()) > tuning.control_radius \
			or hold_real_time >= tuning.max_hold_time:
		release(true)
		return
	_update_plan()
	if world != null:
		var dots: PackedVector2Array = _make_ball_dots()
		if snake != null:
			dots.append_array(snake.get_dots(get_ball_radius() if ball_units > 0.0 else 0.0, hold_real_time))
		if flying_snake != null:
			dots.append_array(flying_snake.get_dots(0.0, hold_real_time))
		world.set_held_dots(dots)


## What 2 would freeze now (grid ice): the snake's tiles, a waterfall's wall, or the
## ball as a block or a raft (IcePlan). The ghost draws it.
func _update_plan() -> void:
	coat_patch.clear()
	if world == null:
		plan = null
		return
	# The empty ball, a frost cursor: the wet patch it touches (Stage W8b).
	if is_frost_cursor() and world.surface_grid != null:
		var tuning: WaterTuning = player.water_tuning
		coat_patch = world.surface_grid.find_wet_patch(ball_position,
			get_ball_radius() + tuning.frost_cursor_reach, tuning.wet_freeze_max_tiles)
	var center: Vector2 = world.to_local(ball_position)
	if snake != null:
		var path: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in snake.get_trail_path():
			path.append(world.to_local(point))
		plan = IcePlan.for_trail(world, path)
		return
	var waterfall: WaterSource = world.find_waterfall_at(center, get_ball_radius())
	if waterfall != null:
		plan = IcePlan.for_wall(world, waterfall)
	else:
		plan = IcePlan.for_ball(world, center, ball_units * WaterWorld.UNIT_AREA, get_ball_radius())


## The ball as dots, room-local: a grid filling a SQUARE as big as its water (grid
## ice: it looks like the block it freezes into; the metaballs round its corners a
## little), each dot wobbling on its own phase.
func _make_ball_dots() -> PackedVector2Array:
	var dots: PackedVector2Array = PackedVector2Array()
	if ball_units <= 0.0:
		return dots  # the empty ball is a spark, drawn in _draw()
	var count: int = clampi(ceili(ball_units / player.water_tuning.drop_units), 1, MAX_BALL_DOTS)
	var per_row: int = ceili(sqrt(float(count)))
	# The dots are drawn as soft blobs blob_dot_radius px round: pulled in a little,
	# the drawn square is about as big as the water.
	var inset: float = player.water_tuning.blob_dot_radius * 0.6
	var side: float = maxf(get_ball_radius() * 2.0 - inset * 2.0, 0.0)
	var center: Vector2 = world.to_local(ball_position)
	var wobble_phase: float = hold_real_time * WOBBLE_SPEED
	for index: int in count:
		var grid_x: int = index % per_row
		var grid_y: int = floori(index / float(per_row))
		var offset: Vector2 = (Vector2(grid_x + 0.5, grid_y + 0.5) / per_row - Vector2(0.5, 0.5)) * side
		# Each dot sways on its own phase: the ball's outline wobbles like water.
		var phase: float = index * 2.39996
		offset += Vector2(sin(wobble_phase + phase), cos(wobble_phase * 1.3 + phase)) * WOBBLE_PX
		dots.append(center + offset)
	return dots


## Solid for the ball: anything on physics layer 1 ("world": walls, floors, crates,
## doors, ice) at that world point.
func _is_solid(world_point: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = world_point
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _draw() -> void:
	if not holding:
		return
	var tuning: WaterTuning = player.water_tuning
	var center: Vector2 = player.get_center()
	# The ring (green while a snake is ready), brightening where the ball nears its edge.
	var ring_color: Color = RING_SNAKE_COLOR if snake == null and is_snake_ready() else RING_COLOR
	draw_arc(center, tuning.control_radius, 0.0, TAU, 48, ring_color, 1.0)
	var reach_share: float = ball_position.distance_to(center) / tuning.control_radius
	if reach_share > RING_WARN_SHARE:
		var toward: float = (ball_position - center).angle()
		var warn: Color = RING_WARN_COLOR
		warn.a *= (reach_share - RING_WARN_SHARE) / (1.0 - RING_WARN_SHARE)
		draw_arc(center, tuning.control_radius, toward - 0.4, toward + 0.4, 12, warn, 1.0)
	if ball_units <= 0.0 and snake == null:
		_draw_frost_cursor()
	elif ball_units <= 0.0:
		# The empty ball with a snake hanging from it: a small spark, twinkling.
		var twinkle: float = 1.0 + 0.5 * sin(hold_real_time * 20.0)
		draw_circle(ball_position, 1.5 * twinkle, SPARK_COLOR)
	if world == null and ball_units > 0.0:
		draw_circle(ball_position, get_ball_radius(), SPARK_COLOR)  # never: no world, no water
	_draw_ghost()
	_draw_coat_ghost()


## The frost cursor (Stage W8b): a small six-armed snowflake, turning slowly, brighter
## when it touches a wet patch.
func _draw_frost_cursor() -> void:
	var color: Color = GHOST_COLOR if coat_patch.is_empty() else SPARK_COLOR
	var turn: float = hold_real_time * FROST_CURSOR_SPIN
	for arm: int in 3:
		var direction: Vector2 = Vector2.from_angle(turn + arm * PI / 3.0) * FROST_CURSOR_SIZE
		draw_line(ball_position - direction, ball_position + direction, color, 1.0)


## The ghost of the icy coat (Stage W8b): the coat on the patch's open faces, a faint
## band with a line along its edge, pulsing gently like the ice ghost.
func _draw_coat_ghost() -> void:
	if coat_patch.is_empty() or world == null or world.surface_grid == null:
		return
	var grid: SurfaceGrid = world.surface_grid
	var line_color: Color = GHOST_COLOR
	line_color.a *= lerpf(GHOST_PULSE_LOW, 1.0, 0.5 + 0.5 * sin(hold_real_time * GHOST_PULSE_SPEED))
	var tile: float = float(SurfaceGrid.TILE)
	for cell: Vector2i in coat_patch:
		var origin: Vector2 = grid.to_global(Vector2(cell * SurfaceGrid.TILE))
		if not world.is_cell_solid(cell + Vector2i.UP):
			draw_rect(Rect2(origin, Vector2(tile, COAT_GHOST_DEPTH)), GHOST_FILL_COLOR)
			draw_line(origin, origin + Vector2(tile, 0.0), line_color, 1.0)
		if not world.is_cell_solid(cell + Vector2i.DOWN):
			draw_rect(Rect2(origin + Vector2(0.0, tile - COAT_GHOST_DEPTH), Vector2(tile, COAT_GHOST_DEPTH)), GHOST_FILL_COLOR)
			draw_line(origin + Vector2(0.0, tile), origin + Vector2(tile, tile), line_color, 1.0)
		if not world.is_cell_solid(cell + Vector2i.LEFT):
			draw_rect(Rect2(origin, Vector2(COAT_GHOST_DEPTH, tile)), GHOST_FILL_COLOR)
			draw_line(origin, origin + Vector2(0.0, tile), line_color, 1.0)
		if not world.is_cell_solid(cell + Vector2i.RIGHT):
			draw_rect(Rect2(origin + Vector2(tile - COAT_GHOST_DEPTH, 0.0), Vector2(COAT_GHOST_DEPTH, tile)), GHOST_FILL_COLOR)
			draw_line(origin + Vector2(tile, 0.0), origin + Vector2(tile, tile), line_color, 1.0)


## The GHOST of the ice plan (grid ice): a faint fill per tile, one faint outline
## round the shape (IceLayer.trace_tiles), pulsing where the ice would hang in mid-air
## (it would crumble); blocked cells a faint red fill; a raft as its slab.
func _draw_ghost() -> void:
	if plan == null or world == null or plan.kind == IcePlan.Kind.NONE:
		return
	var outline_color: Color = GHOST_COLOR
	if plan.is_brittle:
		var pulse: float = 0.5 + 0.5 * sin(hold_real_time * GHOST_PULSE_SPEED)
		outline_color.a *= lerpf(GHOST_PULSE_LOW, 1.0, pulse)
	if plan.kind == IcePlan.Kind.RAFT:
		var slab: Rect2 = Rect2(world.to_global(plan.raft_rect.position), plan.raft_rect.size)
		draw_rect(slab, GHOST_FILL_COLOR)
		draw_rect(slab, outline_color, false, 1.0)
		return
	var free_cells: Array[Vector2i] = []
	var free_atlases: Array[Vector2i] = []
	for index: int in plan.cells.size():
		var shape: PackedVector2Array = IceLayer.get_tile_shape(plan.atlases[index])
		var origin: Vector2 = world.to_global(Vector2(plan.cells[index] * WaterWorld.TILE))
		var corners: PackedVector2Array = PackedVector2Array()
		for corner: Vector2 in shape:
			corners.append(origin + corner)
		draw_colored_polygon(corners, GHOST_BLOCKED_COLOR if plan.blocked[index] else GHOST_FILL_COLOR)
		if not plan.blocked[index]:
			free_cells.append(plan.cells[index])
			free_atlases.append(plan.atlases[index])
	# One outline round the ice (not one per tile, which read as a busy grid).
	var tile_px: Vector2i = Vector2i(WaterWorld.TILE, WaterWorld.TILE)
	for loop: PackedVector2Array in IceLayer.trace_tiles(free_cells, free_atlases, tile_px):
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in loop:
			points.append(world.to_global(point))
		points.append(points[0])  # closed
		draw_polyline(points, outline_color, 1.0)

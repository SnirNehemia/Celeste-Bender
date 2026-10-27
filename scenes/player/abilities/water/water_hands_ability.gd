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
##     the loose water as metaballs: a sunflower disc as big as its water, wobbling
##   - draws the RING (control_radius around you), the empty ball's spark and the
##     tendril to where it's gathering from
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
## top_level = true: this node ignores the player's transform and draws in world
## coordinates.

## The ring: #7FC8FF at 25% alpha (Water_bending.md §12.1), brighter near its edge
## when the ball is about to leave it.
const RING_COLOR: Color = Color(0.498, 0.784, 1.0, 0.25)
const RING_WARN_COLOR: Color = Color(0.75, 0.89, 1.0, 0.7)
## The empty ball: a small blue spark.
const SPARK_COLOR: Color = Color("#BFE4FF")
const TENDRIL_COLOR: Color = Color(0.75, 0.89, 1.0, 0.8)
## How many px the drawn ball wobbles, and how fast (per real second).
const WOBBLE_PX: float = 0.6
const WOBBLE_SPEED: float = 7.0
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
## Gathered something this frame (draws the tendril from where).
var is_gathering: bool = false
## For tests and the overlay: what the last release threw.
var last_release_units: float = 0.0
var last_release_velocity: Vector2 = Vector2.ZERO
## Things the ball shoved and is still touching (no second shove until it leaves),
## and the last shove's velocity (for tests).
var shoved_this_touch: Array[Node2D] = []
var last_shove_velocity: Vector2 = Vector2.ZERO


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


## The ball's radius, px: its area is its water (4 units = about 18 px across).
## An empty ball is a 1.5 px spark.
func get_ball_radius() -> float:
	return maxf(1.5, sqrt(ball_units * WaterWorld.UNIT_AREA / PI))


## Called by WaterHolding.enter(): an empty ball at your hands.
func begin_hold() -> void:
	var tuning: WaterTuning = player.water_tuning
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
	if world != null:
		var center: Vector2 = world.to_local(ball_position)
		if ball_units > 0.0:
			world.release_held(center, velocity, ball_units * WaterWorld.UNIT_AREA)
		else:
			world.sparkle(center)  # an empty ball fizzles
		world.set_held_dots(PackedVector2Array())
	ball_units = 0.0
	is_gathering = false
	released.emit(last_release_units, velocity)
	queue_redraw()


## Under water, the ball moving into you or a floating crate shoves it once (see the
## header). Each thing in WaterWorld.SOLID_GROUP has get_water_box(): its box.
func _shove_touched() -> void:
	# Forget what the ball has left: it can be shoved again next time.
	for index: int in range(shoved_this_touch.size() - 1, -1, -1):
		var shoved: Node2D = shoved_this_touch[index]
		if not is_instance_valid(shoved) or not _ball_touches(shoved.call(&"get_water_box")):
			shoved_this_touch.remove_at(index)
	if ball_units <= 0.0 or ball_velocity == Vector2.ZERO or world == null:
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
		if ball_velocity.dot(box.get_center() - ball_position) <= 0.0:
			continue
		# In the water: you from ball_push_min_share under (the shove scaled by how much
		# of you is under); a floating crate (about half under) whenever it's wet.
		var share: float = world.get_submerged_share(box)
		if share <= 0.0 or (thing == player and share < tuning.ball_push_min_share):
			continue
		var shove: Vector2 = ball_velocity.normalized() * tuning.ball_push_speed
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


## True if the ball's circle overlaps `box` (world): the nearest point of the box
## is within its radius.
func _ball_touches(box: Rect2) -> bool:
	var nearest: Vector2 = ball_position.clamp(box.position, box.end)
	return nearest.distance_to(ball_position) <= get_ball_radius() + 1.0


func _process(_delta: float) -> void:
	if not holding:
		return
	var now_usec: int = Time.get_ticks_usec()
	# Real seconds since the last frame, capped so a hitch can't fling the ball.
	var real_delta: float = minf((now_usec - last_usec) / 1000000.0, 0.05)
	last_usec = now_usec
	_update_ball(real_delta)
	queue_redraw()


## One real-time step of the held ball: steer, stop at walls, gather, let go by
## itself if it left the ring or the time ran out, hand its dots to the world.
func _update_ball(real_delta: float) -> void:
	var tuning: WaterTuning = player.water_tuning
	hold_real_time += real_delta
	# Steering: toward full speed in the held direction, or drag to a stop.
	var input: Vector2 = player.get_aim_input()
	if input != Vector2.ZERO:
		ball_velocity = ball_velocity.move_toward(input * tuning.ball_move_speed, tuning.ball_accel * real_delta)
	else:
		ball_velocity = ball_velocity.move_toward(Vector2.ZERO, tuning.ball_drag * real_delta)
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
	_shove_touched()
	# Gathering.
	is_gathering = false
	if world != null and ball_units < tuning.ball_max_units and real_delta > 0.0:
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
	if world != null:
		world.set_held_dots(_make_ball_dots())


## The ball as dots, room-local: a sunflower disc as big as its water (the same
## packing a released ball's particles start in), wobbling a little.
func _make_ball_dots() -> PackedVector2Array:
	var dots: PackedVector2Array = PackedVector2Array()
	if ball_units <= 0.0:
		return dots  # the empty ball is a spark, drawn in _draw()
	var count: int = clampi(ceili(ball_units / player.water_tuning.drop_units), 1, MAX_BALL_DOTS)
	var radius: float = get_ball_radius()
	var center: Vector2 = world.to_local(ball_position)
	var wobble_phase: float = hold_real_time * WOBBLE_SPEED
	for index: int in count:
		var along: float = sqrt((index + 0.5) / count)
		var angle: float = index * 2.39996
		var offset: Vector2 = Vector2.from_angle(angle) * radius * along
		# Each dot sways on its own phase: the ball's outline wobbles like water.
		offset += Vector2(sin(wobble_phase + angle), cos(wobble_phase * 1.3 + angle)) * WOBBLE_PX
		dots.append(center + offset)
	return dots


## Solid for the ball: anything on physics layer 1 ("world": walls, floors, crates,
## doors) at that world point.
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
	# The ring, brightening where the ball nears its edge.
	draw_arc(center, tuning.control_radius, 0.0, TAU, 48, RING_COLOR, 1.0)
	var reach_share: float = ball_position.distance_to(center) / tuning.control_radius
	if reach_share > RING_WARN_SHARE:
		var toward: float = (ball_position - center).angle()
		var warn: Color = RING_WARN_COLOR
		warn.a *= (reach_share - RING_WARN_SHARE) / (1.0 - RING_WARN_SHARE)
		draw_arc(center, tuning.control_radius, toward - 0.4, toward + 0.4, 12, warn, 1.0)
	if ball_units <= 0.0:
		# The empty ball: a small spark, twinkling.
		var twinkle: float = 1.0 + 0.5 * sin(hold_real_time * 20.0)
		draw_circle(ball_position, 1.5 * twinkle, SPARK_COLOR)
	if is_gathering and world != null:
		draw_line(ball_position, world.to_global(world.last_gather_point), TENDRIL_COLOR, 1.0)
	if world == null and ball_units > 0.0:
		draw_circle(ball_position, get_ball_radius(), SPARK_COLOR)  # never: no world, no water

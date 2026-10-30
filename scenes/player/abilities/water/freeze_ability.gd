class_name FreezeAbility
extends Node2D
## FreezeAbility: the freeze (Water_bending.md §5.3, tap 2; Stage W5). A component
## under the player like the fireball. It turns water into ICE, picking what to
## freeze in this order (refined in the W5 planning: the "water you're touching" rule
## became a thrown crystal):
##   1. HOLDING water (in WaterHolding): the ball, and its snake, freeze where they
##      are (try_freeze_held -> WaterHandsAbility.freeze_held): a ball becomes a block
##      that falls, a snake a pillar standing in its pool. The hold ends.
##   2. else your LAST THROW, while it's LIVE: at most freeze_live_time game seconds
##      old and at least freeze_live_share of it still loose (in the air or running,
##      not merged into a pool). ALL of it freezes at once, no aim, in the shape it
##      has (WaterWorld.freeze_particles: compact -> a block that keeps its momentum,
##      long -> a static shape). Shown while live: frost glints on the water and a
##      shrinking frost ring over your head (the window closing).
##   3. else, WHOLLY UNDER WATER (at least ice_ball_min_share of you): an ICE BALL
##      around you (the IceBall state: start_ice_ball / shatter_ice_ball). It floats
##      up fast, bobs at the surface, the arrows roll it; 2 again shatters it.
##   4. else a SNOW PUFF (SnowPuff; it replaced the W5 ice crystal after the W7a
##      play-test): the player switches to GustAim with this node as the AIM SOURCE
##      (the contract in fireball_ability.gd). A TAP (shorter than snow_tap_time
##      real seconds) bursts the puff around you; HOLDING 2 aims in slow motion (a
##      dotted frost line to where the puff will land, and its ring) and tosses it
##      snow_toss_distance px that way. Jump cancels. Its flakes rain gently down and
##      freeze the water they touch.
## A cooldown (freeze_cooldown, game time) follows every freeze, puff and ice ball.
##
## Flow: Idle/Run/Jump/Fall/WallSlide/Glide/Launched ask player.try_start_freeze()
## every frame -> try_start(); WaterHolding asks try_freeze_held().
##
## top_level = true: this node ignores the player's transform and draws its aim line
## and the live indicator in world coordinates.

## Frost: the aim line, glints and the window ring (pale cyan and white, §12.1).
const FROST_COLOR: Color = Color("#DFF8FF")
const FROST_DIM_COLOR: Color = Color(0.6, 0.85, 1.0, 0.7)
## The aim line: a dot every AIM_DOT_SPACING px, marching out (px per REAL second).
const AIM_DOT_SPACING: float = 5.0
const AIM_MARCH_SPEED: float = 20.0
## The aim line starts this far from the player's center.
const SPAWN_DISTANCE: float = 5.0
## The ice ball's glass: a see-through pale body, a white rim and a shine (§12.1).
const ICE_BALL_COLOR: Color = Color(0.66, 0.94, 1.0, 0.45)
const ICE_BALL_RIM_COLOR: Color = Color(0.9, 0.98, 1.0, 0.9)
## The live indicator: a ring this big this far above the player's center, and at
## most this many glints on the water.
const WINDOW_RING_RADIUS: float = 3.0
const WINDOW_RING_OFFSET: Vector2 = Vector2(0.0, -12.0)
const MAX_GLINTS: int = 10

## Emitted when water froze (a held ball, the last throw, or by a snow puff).
signal froze(ice: Node)
## Emitted when a snow puff leaves the hands.
signal puffed(puff: SnowPuff)

var player: Player
var cooldown_remaining: float = 0.0
var is_aiming: bool = false
## The aim being previewed (ZERO = none held: facing is used).
var aim_preview_direction: Vector2 = Vector2.ZERO
## Real seconds since the aim began (the dots march), and the last _process clock.
var aim_real_time: float = 0.0
var last_process_msec: int = 0
## Where the aimed puff will land (world): the end of the dotted line.
var predicted_end: Vector2 = Vector2.ZERO
## The live indicator, refreshed every frame: is the last throw live, the share of
## its window left (1 -> 0), and where to draw glints (world points).
var is_live: bool = false
var window_left: float = 0.0
var glint_points: PackedVector2Array = PackedVector2Array()
## For tests and the overlay.
var last_ice: Node = null
var last_puff: SnowPuff = null
## The state 2 starts (try_start true): &"GustAim" (the puff) or &"IceBall".
var start_state: StringName = &"GustAim"
## The ICE BALL around you (the IceBall state): the water frozen in it, px² (0 = none).
## It's taken out of the pool into the room's held water (WaterWorld.held_area), as
## the hands do, so the books balance; shattering lets it go as loose water.
var ice_ball_area: float = 0.0
var ice_ball_world: WaterWorld = null


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	global_position = Vector2.ZERO
	z_index = 40
	last_process_msec = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


## The WaterWorld of the room we're in, or null.
func _get_world() -> WaterWorld:
	return WaterWorld.find_at(get_tree(), player.get_center())


## On the frame 2 is pressed where Water is allowed (not while holding). A live last
## throw freezes here and now (false: no state change). True = the caller switches
## to `start_state`: IceBall (wholly under water) or GustAim (the snow puff).
func try_start() -> bool:
	if not Input.is_action_just_pressed("water_freeze") or not player.is_element_allowed(Player.ELEMENT_WATER):
		return false
	if cooldown_remaining > 0.0:
		return false
	if is_last_throw_live():
		freeze_last_throw()
		return false
	start_state = &"IceBall" if can_make_ice_ball() else &"GustAim"
	return true


## Wholly under water, in clean water (black water kills first anyway)?
func can_make_ice_ball() -> bool:
	var world: WaterWorld = _get_world()
	return world != null and player.swim.submerged_share >= player.water_tuning.ice_ball_min_share \
		and not world.is_black_at(world.to_local(player.get_center()))


## While holding (WaterHolding asks every frame): on the frame 2 is pressed, the
## water in the hands freezes. True = it froze (the hold is over).
func try_freeze_held() -> bool:
	if not Input.is_action_just_pressed("water_freeze") or cooldown_remaining > 0.0:
		return false
	var ice: Node = player.water_hands.freeze_held()
	if ice == null:
		return false  # empty hands: nothing to freeze, the hold goes on
	_after_freeze(ice)
	return true


## Is the last throw LIVE (see the header, rule 2)?
func is_last_throw_live() -> bool:
	var world: WaterWorld = _get_world()
	if world == null or world.last_group_id <= 0 or world.last_group_area <= 0.0:
		return false
	var tuning: WaterTuning = player.water_tuning
	if world.get_last_throw_age() > tuning.freeze_live_time:
		return false
	var loose: float = world.get_group_loose_area(world.last_group_id) + _get_flying_area(world.last_group_id)
	return loose > 0.0 and loose >= tuning.freeze_live_share * world.last_group_area


## Water of throw group `group` still flowing out of a released snake (its ribbon),
## px²: it's loose water that just hasn't left yet.
func _get_flying_area(group: int) -> float:
	var flying: WaterSnake = player.water_hands.flying_snake
	return flying.area if flying != null and flying.group_id == group else 0.0


## Freezes all of the last throw, where it is now (rule 2). Returns the ice.
func freeze_last_throw() -> Node:
	var world: WaterWorld = _get_world()
	var group: int = world.last_group_id
	var hands: WaterHandsAbility = player.water_hands
	if hands.flying_snake != null and hands.flying_snake.group_id == group:
		# A ribbon still feeding out: the rest of it goes at once, to freeze with it.
		hands.flying_snake.finish_flight()
		hands.flying_snake = null
		if not hands.is_holding():
			world.set_held_dots(PackedVector2Array())
	var taken: Array = world.take_group_particles(group)
	var ice: Node = world.freeze_particles(taken[0], taken[1], taken[2])
	world.last_group_area = 0.0  # frozen: nothing of it is live any more
	_after_freeze(ice)
	return ice


func _after_freeze(ice: Node) -> void:
	cooldown_remaining = player.water_tuning.freeze_cooldown
	last_ice = ice
	FX.play_sfx(&"freeze")
	froze.emit(ice)


# --- The aim source contract (states/gust_aim.gd) -----------------------------------

func get_aim_action() -> StringName:
	return &"water_freeze"


func get_aim_time_scale() -> float:
	return player.water_tuning.snow_aim_time_scale


func get_aim_max_real_time() -> float:
	return player.water_tuning.snow_aim_max_real_time


func get_initial_aim() -> Vector2:
	return player.get_forgiving_aim_input()


func begin_aim(direction: Vector2) -> void:
	is_aiming = true
	aim_preview_direction = direction
	aim_real_time = 0.0


func update_aim(direction: Vector2) -> void:
	aim_preview_direction = direction


func end_aim() -> void:
	is_aiming = false


func can_cancel_aim() -> bool:
	return true


## Jump while aiming: no puff (and nothing spent: the freeze costs nothing).
func cancel_aim() -> void:
	var world: WaterWorld = _get_world()
	if world != null:
		world.sparkle(world.to_local(player.get_center()), 2)


## Release (or the time limit): the puff, and which state comes next. A TAP bursts it
## around you whatever the arrows say; a longer hold tosses it along the aim.
func finish_aim(direction: Vector2) -> StringName:
	if aim_real_time < player.water_tuning.snow_tap_time:
		puff(Vector2.ZERO)
	else:
		puff(get_throw_direction(direction))
	if player.is_on_floor():
		return &"Run" if player.velocity.x != 0.0 else &"Idle"
	return &"Fall"


## The throw direction for an aim: the aim itself, or facing for ZERO.
func get_throw_direction(aim: Vector2) -> Vector2:
	return aim.normalized() if aim != Vector2.ZERO else Vector2(player.facing_direction, 0.0)


## A snow puff around you, tossed along `direction` (a unit vector; ZERO = no toss,
## it bursts around you). Returns it.
func puff(direction: Vector2) -> SnowPuff:
	if direction.x != 0.0:
		player.facing_direction = signf(direction.x)
	var tuning: WaterTuning = player.water_tuning
	last_puff = SnowPuff.burst(player.get_parent(), player.get_center(), direction * tuning.snow_toss_distance, tuning)
	last_puff.froze.connect(_on_puff_froze)
	cooldown_remaining = tuning.freeze_cooldown
	FX.play_sfx(&"snow_puff")
	puffed.emit(last_puff)
	return last_puff


func _on_puff_froze(ice: Node) -> void:
	last_ice = ice
	froze.emit(ice)


# --- The ice ball (the IceBall state) -------------------------------------------------

## Freezes ice_ball_units of the water around you into the ball. False if there was
## no water to take (the state then leaves at once).
func start_ice_ball() -> bool:
	var world: WaterWorld = _get_world()
	if world == null:
		return false
	var tuning: WaterTuning = player.water_tuning
	var local_center: Vector2 = world.to_local(player.get_center())
	ice_ball_area = world.gather(local_center, tuning.ice_ball_radius + 4.0, tuning.ice_ball_units * WaterWorld.UNIT_AREA)
	ice_ball_world = world
	cooldown_remaining = tuning.freeze_cooldown
	if ice_ball_area <= 0.0:
		ice_ball_world = null
		return false
	world.sparkle(local_center, 6)
	FX.play_sfx(&"freeze")
	return true


## Shatters the ball: its water goes back as loose water around you (falling in, it
## joins the pool), with a burst of frost. Safe to call with no ball.
func shatter_ice_ball() -> void:
	if ice_ball_area <= 0.0:
		return
	if is_instance_valid(ice_ball_world):
		var local_center: Vector2 = ice_ball_world.to_local(player.get_center())
		ice_ball_world.release_held(local_center, Vector2(0.0, -30.0), ice_ball_area)
		ice_ball_world.sparkle(local_center, 8)
	ice_ball_area = 0.0
	ice_ball_world = null
	cooldown_remaining = player.water_tuning.freeze_cooldown
	FX.play_sfx(&"ice_shatter")


func has_ice_ball() -> bool:
	return ice_ball_area > 0.0


# --- Looks -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Real time, not delta: the aim runs in slow motion, its dots shouldn't crawl.
	var now_msec: int = Time.get_ticks_msec()
	var real_delta: float = (now_msec - last_process_msec) / 1000.0
	last_process_msec = now_msec
	if is_aiming:
		aim_real_time += real_delta
		_predict_landing()
	_update_live_indicator()
	queue_redraw()


## Is the last throw live, how much of its window is left, and where its water is
## (a few of its drops, for the glints).
func _update_live_indicator() -> void:
	is_live = is_last_throw_live()
	glint_points.clear()
	if not is_live:
		window_left = 0.0
		return
	var world: WaterWorld = _get_world()
	window_left = clampf(1.0 - world.get_last_throw_age() / maxf(player.water_tuning.freeze_live_time, 0.01), 0.0, 1.0)
	var points: PackedVector2Array = world.get_group_points(world.last_group_id)
	# Every n-th drop: the same drops each frame (their order is stable enough), so
	# the glints ride the water instead of jumping around.
	var every: int = maxi(1, ceili(points.size() / float(MAX_GLINTS)))
	for index: int in range(0, points.size(), every):
		glint_points.append(world.to_global(points[index]))


## Where an aimed puff will land: the toss along the aim, stopped short by rock
## (physics layer 1).
func _predict_landing() -> void:
	var direction: Vector2 = get_throw_direction(aim_preview_direction)
	var start: Vector2 = player.get_center()
	predicted_end = start + direction * player.water_tuning.snow_toss_distance
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, predicted_end, SnowPuff.SOLID_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		predicted_end = hit["position"]


func _draw() -> void:
	if is_live:
		_draw_live_indicator()
	if has_ice_ball():
		_draw_ice_ball()
	if not is_aiming:
		return
	# Held under the tap time it's still a tap (a puff around you): no line yet.
	if aim_real_time < player.water_tuning.snow_tap_time:
		return
	var direction: Vector2 = get_throw_direction(aim_preview_direction)
	var start: Vector2 = player.get_center() + direction * SPAWN_DISTANCE
	var length: float = start.distance_to(predicted_end)
	var dot_at: float = fmod(aim_real_time * AIM_MARCH_SPEED, AIM_DOT_SPACING) + AIM_DOT_SPACING
	while dot_at < length:
		var color: Color = FROST_COLOR
		color.a = lerpf(0.9, 0.4, dot_at / maxf(length, 1.0))
		draw_rect(Rect2((start + direction * dot_at).round(), Vector2.ONE), color)
		dot_at += AIM_DOT_SPACING
	# Where the puff lands, and how far its flakes spread: a dotted ring.
	_draw_flake(predicted_end.round(), 2.0, FROST_COLOR)
	var radius: float = player.water_tuning.snow_puff_radius
	for step: int in 16:
		var ring_point: Vector2 = predicted_end + Vector2.from_angle(step * TAU / 16.0 + aim_real_time) * radius
		draw_rect(Rect2(ring_point.round(), Vector2.ONE), FROST_DIM_COLOR)


## The ice ball around you: see-through glass, a light rim and a shine.
func _draw_ice_ball() -> void:
	var center: Vector2 = player.get_center().round()
	var radius: float = player.water_tuning.ice_ball_radius
	draw_circle(center, radius, ICE_BALL_COLOR)
	draw_arc(center, radius, 0.0, TAU, 24, ICE_BALL_RIM_COLOR, 1.0)
	draw_arc(center, radius - 3.0, PI * 1.1, PI * 1.45, 6, Color.WHITE, 1.0)


## The last throw is live: frost glints twinkle on its water, and a ring over your
## head runs down as its window closes.
func _draw_live_indicator() -> void:
	var seconds: float = Time.get_ticks_msec() / 1000.0
	for index: int in glint_points.size():
		var twinkle: float = 0.5 + 0.5 * sin(seconds * 14.0 + index * 1.7)
		if twinkle > 0.35:
			_draw_flake(glint_points[index].round(), 1.0, Color(FROST_COLOR, twinkle))
	var ring_center: Vector2 = (player.get_center() + WINDOW_RING_OFFSET).round()
	draw_arc(ring_center, WINDOW_RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * window_left, 16, FROST_COLOR, 1.0)
	draw_rect(Rect2(ring_center, Vector2.ONE), FROST_COLOR)


## A small snowflake: a center pixel and four arms `arm` px long.
func _draw_flake(center: Vector2, arm: float, color: Color) -> void:
	draw_rect(Rect2(center, Vector2.ONE), color)
	for arm_direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		for step: int in range(1, int(arm) + 1):
			draw_rect(Rect2(center + arm_direction * step, Vector2.ONE), Color(color, color.a * 0.7))

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
##   3. else an ICE CRYSTAL (IceCrystal): the player switches to GustAim with this
##      node as the AIM SOURCE (the contract in fireball_ability.gd). A tap throws it
##      at once in the arrow direction (facing with none); holding 2 aims it in slow
##      motion with a dotted frost line; Jump cancels. It freezes the first water it
##      touches: a pool's surface (a sheet over a stretch), a waterfall (a column),
##      an older throw.
## A cooldown (freeze_cooldown, game time) follows every freeze and crystal.
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
## The crystal starts this far from the player's center along the throw.
const SPAWN_DISTANCE: float = 5.0
## The live indicator: a ring this big this far above the player's center, and at
## most this many glints on the water.
const WINDOW_RING_RADIUS: float = 3.0
const WINDOW_RING_OFFSET: Vector2 = Vector2(0.0, -12.0)
const MAX_GLINTS: int = 10

## Emitted when water froze (a held ball, the last throw, or by the crystal).
signal froze(ice: Node)
## Emitted when a crystal leaves the hand.
signal crystal_thrown(crystal: IceCrystal)

var player: Player
var cooldown_remaining: float = 0.0
var is_aiming: bool = false
## The aim being previewed (ZERO = none held: facing is used).
var aim_preview_direction: Vector2 = Vector2.ZERO
## Real seconds since the aim began (the dots march), and the last _process clock.
var aim_real_time: float = 0.0
var last_process_msec: int = 0
## The previewed line's end (world) and whether it ends in water.
var predicted_end: Vector2 = Vector2.ZERO
var predicted_hits_water: bool = false
## The live indicator, refreshed every frame: is the last throw live, the share of
## its window left (1 -> 0), and where to draw glints (world points).
var is_live: bool = false
var window_left: float = 0.0
var glint_points: PackedVector2Array = PackedVector2Array()
## For tests and the overlay.
var last_ice: Node = null
var last_crystal: IceCrystal = null


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
## throw freezes here and now (false: no state change). True = throw a crystal: the
## caller switches to GustAim.
func try_start() -> bool:
	if not Input.is_action_just_pressed("water_freeze") or not player.is_element_allowed(Player.ELEMENT_WATER):
		return false
	if cooldown_remaining > 0.0:
		return false
	if is_last_throw_live():
		freeze_last_throw()
		return false
	return true


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
	return player.water_tuning.crystal_aim_time_scale


func get_aim_max_real_time() -> float:
	return player.water_tuning.crystal_aim_max_real_time


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


## Jump while aiming: no crystal (and nothing spent: the freeze costs nothing).
func cancel_aim() -> void:
	var world: WaterWorld = _get_world()
	if world != null:
		world.sparkle(world.to_local(player.get_center()), 2)


## Release (or the time limit): throw the crystal and say which state comes next.
func finish_aim(direction: Vector2) -> StringName:
	throw_crystal(direction)
	if player.is_on_floor():
		return &"Run" if player.velocity.x != 0.0 else &"Idle"
	return &"Fall"


## The throw direction for an aim: the aim itself, or facing for ZERO.
func get_throw_direction(aim: Vector2) -> Vector2:
	return aim.normalized() if aim != Vector2.ZERO else Vector2(player.facing_direction, 0.0)


## Throws an ice crystal toward `direction` (facing if ZERO). Returns it.
func throw_crystal(direction: Vector2) -> IceCrystal:
	var throw_direction: Vector2 = get_throw_direction(direction)
	if throw_direction.x != 0.0:
		player.facing_direction = signf(throw_direction.x)
	var start: Vector2 = player.get_center() + throw_direction * SPAWN_DISTANCE
	last_crystal = IceCrystal.launch(player.get_parent(), start, throw_direction, player.water_tuning)
	last_crystal.froze.connect(_on_crystal_froze)
	cooldown_remaining = player.water_tuning.freeze_cooldown
	FX.play_sfx(&"crystal_throw")
	crystal_thrown.emit(last_crystal)
	return last_crystal


func _on_crystal_froze(ice: Node) -> void:
	last_ice = ice
	froze.emit(ice)


# --- Looks -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Real time, not delta: the aim runs in slow motion, its dots shouldn't crawl.
	var now_msec: int = Time.get_ticks_msec()
	var real_delta: float = (now_msec - last_process_msec) / 1000.0
	last_process_msec = now_msec
	if is_aiming:
		aim_real_time += real_delta
		_predict_line()
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


## Steps the crystal's straight path until it would hit rock (physics layer 1),
## reach water (a pool) or run out of range.
func _predict_line() -> void:
	var direction: Vector2 = get_throw_direction(aim_preview_direction)
	var start: Vector2 = player.get_center() + direction * SPAWN_DISTANCE
	var range_end: Vector2 = start + direction * player.water_tuning.crystal_range
	predicted_end = range_end
	predicted_hits_water = false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, range_end, IceCrystal.HIT_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		predicted_end = hit["position"]
	var world: WaterWorld = _get_world()
	if world == null:
		return
	var length: float = start.distance_to(predicted_end)
	var along: float = 0.0
	while along <= length:
		var point: Vector2 = start + direction * along
		if not world.find_water_at(world.to_local(point)).is_empty():
			predicted_end = point
			predicted_hits_water = true
			return
		along += 2.0


func _draw() -> void:
	if is_live:
		_draw_live_indicator()
	if not is_aiming:
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
	_draw_flake(predicted_end.round(), 2.0 if predicted_hits_water else 1.0,
		FROST_COLOR if predicted_hits_water else FROST_DIM_COLOR)


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

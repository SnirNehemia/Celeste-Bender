class_name FireballAbility
extends Node2D
## FireballAbility: the fireball (Fire_bending.md §5.1, Q). A component under the
## player like the jet. It owns the pip check, the fizzle, the aim preview and the
## throw; the Fireball object (scenes/objects/fire/fireball.gd) does the flying.
##
## Flow:
##   Idle/Run/Jump/Fall/WallSlide/Glide/Launched ask player.try_start_fireball() every
##   frame -> try_start(): on the frame Q is pressed where fire is allowed:
##     - no pip: fizzle (smoke puff, 2 dull sparks), nothing else
##     - a pip: the player becomes the GustAim state's AIM SOURCE and switches to
##       GustAim. That state is shared with the gust (the "aim source" contract
##       below): slow motion, arrows aim, release throws. A tap throws almost at once.
##   On release, GustAim calls finish_aim(): the pip is spent HERE, at the throw, so
##   Jump during the aim cancels it for free (cancel_aim()).
##
## The aim source contract (duck typing, called by states/gust_aim.gd with call()):
##   get_aim_action() -> StringName       the key being held (fireball)
##   get_aim_time_scale() -> float        world speed while aiming
##   get_aim_max_real_time() -> float     real seconds before it fires by itself
##   get_initial_aim() -> Vector2         the aim at the press
##   begin_aim(dir), update_aim(dir), end_aim()   the preview
##   can_cancel_aim() -> bool             Jump cancels? (yes for the fireball)
##   cancel_aim()                         Jump was pressed
##   finish_aim(dir) -> StringName        fire, and name the state to go to
## GustAbility implements the same methods.
##
## Direction: the held arrows (8 ways), or the facing direction when none are held.
## top_level = true: this node ignores the player's transform, so it draws the aim
## preview in world coordinates.
##
## While aiming (after the Stage F4 play-test):
##   - the player HOLDS the fireball: a small dancing flame at the hand, on the aim
##     side (HeldFlame, two FlameTongues and a glowing core)
##   - the aim preview is an ARC OF EMBERS along the path the fireball will really
##     fly (same gravity and lift as Fireball.get_launch_velocity), marching outward,
##     yellow near the hand cooling to red. Where it would hit a wall or a flammable,
##     a little flame star; where it would gutter out, a puff of gray.

## The aim preview's ember colors (near the hand -> far end) and the end marks.
const AIM_NEAR_COLOR: Color = Color("#FFD34D")
const AIM_FAR_COLOR: Color = Color("#E8431A")
const AIM_SMOKE_COLOR: Color = Color(0.55, 0.5, 0.5)
## Path length between two embers, px, and how fast they march outward (px per
## REAL second: the world is slowed while aiming, the preview isn't).
const AIM_DOT_SPACING: float = 6.0
const AIM_MARCH_SPEED: float = 24.0
## The predicted path is stepped at 60 Hz, at most this many steps.
const AIM_MAX_STEPS: int = 120
## The held flame: how far from the center toward the aim, its bob (px, per real s).
const HELD_DISTANCE: float = 6.0
const HELD_BOB_AMOUNT: float = 1.0
const HELD_BOB_SPEED: float = 9.0
const HELD_CORE_RADIUS: float = 2.0
## The fireball starts this far from the player's center along the throw.
const SPAWN_DISTANCE: float = 5.0
## Fizzle: smoke puff size and its 2 dull sparks.
const FIZZLE_SMOKE_COUNT: int = 4
const FIZZLE_SPARK_COUNT: int = 2

## Emitted when a fireball leaves the hand.
signal thrown(fireball: Fireball)
## Emitted when Q found no pip.
signal fizzled

var player: Player
var fire_bar: FireBar
var is_aiming: bool = false
## The aim being previewed (ZERO = none held: the facing direction is used).
var aim_preview_direction: Vector2 = Vector2.ZERO
## The last fireball thrown (for tests and the debug overlay); may be freed.
var last_fireball: Fireball
## The fireball in the hand while aiming, and its parts.
var held_flame: Node2D
var held_tongues: Array[FlameTongue] = []
## Real seconds since the aim began (the held flame grows in, the embers march).
var aim_real_time: float = 0.0
var last_process_msec: int = 0
## The predicted path (world points) and how it ends, refreshed every frame.
var predicted_path: PackedVector2Array = PackedVector2Array()
var predicted_hit: bool = false


func _ready() -> void:
	player = get_parent() as Player
	fire_bar = player.get_node("FireBar") as FireBar
	top_level = true
	global_position = Vector2.ZERO
	z_index = 40
	last_process_msec = Time.get_ticks_msec()
	_build_held_flame()


## On the frame Q is pressed where fire is allowed. True = go aim (GustAim);
## false = nothing (not pressed, or it fizzled).
func try_start() -> bool:
	if not Input.is_action_just_pressed("fireball") or not player.is_element_allowed(Player.ELEMENT_FIRE):
		return false
	if fire_bar.pips <= 0:
		_fizzle()
		return false
	return true


# --- The aim source contract (states/gust_aim.gd) -----------------------------------

func get_aim_action() -> StringName:
	return &"fireball"


func get_aim_time_scale() -> float:
	return player.fire_tuning.fireball_aim_time_scale


func get_aim_max_real_time() -> float:
	return player.fire_tuning.fireball_aim_max_real_time


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


## Jump during the aim: nothing is thrown and the pip stays (it's only spent on a
## throw), so there's nothing to give back.
func cancel_aim() -> void:
	SmokePuff.spawn(player.get_parent(), player.get_center(), 2)


## Release (or the time limit): throw toward `direction` and say which state comes
## next. The pip is checked again (it could be gone if the bar was reset meanwhile).
func finish_aim(direction: Vector2) -> StringName:
	throw(direction)
	if player.is_on_floor():
		return &"Run" if player.velocity.x != 0.0 else &"Idle"
	return &"Fall"


## The gravity on a thrown fireball, px/s^2: the player's gravity x fireball_gravity_scale.
func get_fireball_gravity() -> float:
	return player.tuning.gravity * player.fire_tuning.fireball_gravity_scale


## The throw direction for an aim: the aim itself, or the facing direction for ZERO.
func get_throw_direction(aim: Vector2) -> Vector2:
	return aim if aim != Vector2.ZERO else Vector2(player.facing_direction, 0.0)


## Spends a pip and throws a fireball toward `direction` (facing if ZERO).
## Returns the fireball, or null (and a fizzle) with no pip.
func throw(direction: Vector2) -> Fireball:
	if not fire_bar.spend():
		_fizzle()
		return null
	var throw_direction: Vector2 = get_throw_direction(direction)
	if throw_direction.x != 0.0:
		player.facing_direction = signf(throw_direction.x)
	var start: Vector2 = player.get_center() + throw_direction * SPAWN_DISTANCE
	last_fireball = Fireball.launch(player.get_parent(), start, throw_direction, player.fire_tuning, self,
		get_fireball_gravity())
	# A small kick of sparks from the hand.
	EmberEmitter.burst(player.get_parent(), start, 5, throw_direction, 40.0, 60.0)
	FX.play_sfx(&"fireball_throw")
	thrown.emit(last_fireball)
	return last_fireball


# --- Looks -------------------------------------------------------------------------

## The fireball in the hand: a glowing core with two small tongues licking UP (a
## held flame rises, whichever way you aim), shedding licks and smoke.
func _build_held_flame() -> void:
	held_flame = Node2D.new()
	held_flame.name = "HeldFlame"
	held_flame.visible = false
	add_child(held_flame)
	var core: Node2D = Node2D.new()
	core.name = "Core"
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	core.material = additive
	held_flame.add_child(core)
	core.draw.connect(_draw_held_core.bind(core))
	for tongue_index: int in 2:
		var tongue: FlameTongue = FlameTongue.new()
		tongue.position = Vector2(-1.0 + tongue_index * 2.0, 0.0)
		tongue.length = 6.0 if tongue_index == 0 else 8.0
		tongue.base_width = 3.0
		tongue.fan_width = 4.0
		tongue.heat = 0.7
		tongue.wobble_amount = 0.45
		tongue.fork_amount = 0.6
		tongue.lick_rate = 5.0
		tongue.lick_size = 2.5
		tongue.lick_speed = 14.0
		tongue.smoke_rate = 3.0
		tongue.smoke_lifetime = 0.5
		held_flame.add_child(tongue)
		held_tongues.append(tongue)


func _draw_held_core(core: Node2D) -> void:
	core.draw_circle(Vector2.ZERO, HELD_CORE_RADIUS + 0.5, Color(AIM_NEAR_COLOR, 0.8))
	core.draw_circle(Vector2.ZERO, HELD_CORE_RADIUS * 0.6, Color("#FFF6CC"))


func _process(_delta: float) -> void:
	# Real time, not delta: the world runs at 0.3x while aiming, the hand flame and
	# the preview shouldn't crawl.
	var now_msec: int = Time.get_ticks_msec()
	var real_delta: float = (now_msec - last_process_msec) / 1000.0
	last_process_msec = now_msec
	held_flame.visible = is_aiming
	if is_aiming:
		aim_real_time += real_delta
		_update_held_flame()
		_predict_path()
	queue_redraw()


func _update_held_flame() -> void:
	var throw_direction: Vector2 = get_throw_direction(aim_preview_direction)
	var bob: Vector2 = Vector2(sin(aim_real_time * HELD_BOB_SPEED * 0.7) * 0.6,
		sin(aim_real_time * HELD_BOB_SPEED) * HELD_BOB_AMOUNT)
	held_flame.global_position = (player.get_center() + throw_direction * HELD_DISTANCE + bob).round()
	# It grows into the hand over the first 0.1 s (a quick tap barely shows it).
	held_flame.scale = Vector2.ONE * clampf(aim_real_time / 0.1, 0.3, 1.0)
	# The tongues live on game time: speed them up by 1 / time_scale so they still
	# dance at full speed while the world is slowed.
	for tongue: FlameTongue in held_tongues:
		tongue.flicker_speed = 2.5 / maxf(Engine.time_scale, 0.05)
	held_flame.get_node("Core").queue_redraw()


## Steps the throw forward (60 Hz, the fireball's own gravity and lift) until it
## reaches its range or a ray between two steps hits a wall or a flammable area.
func _predict_path() -> void:
	var tuning: FireTuning = player.fire_tuning
	var throw_direction: Vector2 = get_throw_direction(aim_preview_direction)
	var position_now: Vector2 = player.get_center() + throw_direction * SPAWN_DISTANCE
	var velocity: Vector2 = Fireball.get_launch_velocity(throw_direction, tuning, get_fireball_gravity())
	var gravity: float = get_fireball_gravity()
	var step_time: float = 1.0 / 60.0
	var flown: float = 0.0
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	predicted_path = PackedVector2Array([position_now])
	predicted_hit = false
	for step: int in AIM_MAX_STEPS:
		velocity.y += gravity * step_time
		var next_position: Vector2 = position_now + velocity * step_time
		# A ray between the two points: does the fireball's path cross anything?
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			position_now, next_position, Fireball.HIT_MASK)
		query.collide_with_areas = true
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			predicted_path.append(hit["position"])
			predicted_hit = true
			return
		flown += position_now.distance_to(next_position)
		position_now = next_position
		predicted_path.append(position_now)
		if flown >= tuning.fireball_max_range:
			return


func _draw() -> void:
	if not is_aiming or predicted_path.size() < 2:
		return
	# Total path length, so the colors cool from the hand to the far end.
	var total_length: float = 0.0
	for point_index: int in range(1, predicted_path.size()):
		total_length += predicted_path[point_index - 1].distance_to(predicted_path[point_index])
	# Embers every AIM_DOT_SPACING px along the path, marching outward with time.
	var march_offset: float = fmod(aim_real_time * AIM_MARCH_SPEED, AIM_DOT_SPACING)
	var next_dot_at: float = march_offset + AIM_DOT_SPACING  # skip the one inside the hand
	var walked: float = 0.0
	for point_index: int in range(1, predicted_path.size()):
		var segment_start: Vector2 = predicted_path[point_index - 1]
		var segment_end: Vector2 = predicted_path[point_index]
		var segment_length: float = segment_start.distance_to(segment_end)
		while next_dot_at <= walked + segment_length:
			var along: float = (next_dot_at - walked) / maxf(segment_length, 0.001)
			var dot_position: Vector2 = segment_start.lerp(segment_end, along).round()
			var progress: float = next_dot_at / maxf(total_length, 1.0)
			var color: Color = AIM_NEAR_COLOR.lerp(AIM_FAR_COLOR, progress)
			# Flicker like embers, fading out a little toward the end.
			color.a = randf_range(0.55, 1.0) * lerpf(1.0, 0.6, progress)
			draw_rect(Rect2(dot_position, Vector2.ONE), color)
			next_dot_at += AIM_DOT_SPACING
		walked += segment_length
	_draw_path_end(predicted_path[predicted_path.size() - 1])


## The end of the predicted path: a flickering flame star where it would hit, a
## faint gray puff where it would gutter out in the air.
func _draw_path_end(end_point: Vector2) -> void:
	var center: Vector2 = end_point.round()
	if not predicted_hit:
		var puff_alpha: float = 0.35 + 0.15 * sin(aim_real_time * 6.0)
		draw_rect(Rect2(center - Vector2(1, 1), Vector2(2, 2)), Color(AIM_SMOKE_COLOR, puff_alpha))
		return
	var flicker: float = randf_range(0.7, 1.0)
	var arm: float = 2.0 if fmod(aim_real_time * 8.0, 2.0) < 1.0 else 3.0
	draw_rect(Rect2(center, Vector2.ONE), Color("#FFF6CC", flicker))
	for arm_direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		for arm_step: int in range(1, int(arm) + 1):
			var arm_color: Color = AIM_NEAR_COLOR.lerp(AIM_FAR_COLOR, float(arm_step) / arm)
			arm_color.a = flicker
			draw_rect(Rect2(center + arm_direction * arm_step, Vector2.ONE), arm_color)


## No pip: a puff of smoke from the hand and 2 dull sparks, no projectile.
func _fizzle() -> void:
	var hand: Vector2 = player.get_center() + player.get_aim_direction() * 4.0
	SmokePuff.spawn(player.get_parent(), hand, FIZZLE_SMOKE_COUNT)
	var sparks: EmberEmitter = EmberEmitter.burst(player.get_parent(), hand, FIZZLE_SPARK_COUNT,
		player.get_aim_direction(), 40.0, 25.0)
	sparks.modulate = Color(0.6, 0.5, 0.45)  # dull, not bright embers
	FX.play_sfx(&"fizzle")
	fizzled.emit()

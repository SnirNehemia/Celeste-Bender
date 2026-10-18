class_name GustAbility
extends Node2D
## Gust component (GAME_DESIGN.md §5.3). Lives as a child of the Player:
##   Player > GustAbility
##
## Responsibilities (and only these):
##   - the COOLDOWN (one gust every tuning.gust_cooldown seconds)
##   - the BREATH cost (tuning.gust_uses_stamina): a gust spends shared glide/dash
##     stamina; pressing gust without enough plays a small "fizzle" puff instead
##   - the DOWN-BOOSTS: a down-gust in mid-air acts as an extra jump, up to
##     tuning.gust_down_boosts_per_airtime times, refilled on the ground
##   - the HIT and the look, built with the shared AirBlast helper (abilities/air_blast.gd):
##       aimed gust   (an arrow held): a cone in that direction
##       neutral gust (no arrow held): a burst in ALL directions, pushing everything
##                    nearby straight away from the player (the GustRecoil state
##                    turns it into an air brake)
##     plus a small screen shake
##   - the AIM PREVIEW while hold-to-aim is active (GustAim state): a pale outline
##     of the cone (or circle, for neutral) showing where the gust will go
##
## Direction convention: Vector2.ZERO means "neutral" everywhere in the gust code.
##
## The MOVEMENT is in two states (states own movement, abilities own resources/effects):
##   GustAim    (only with tuning.gust_hold_to_aim): slow motion while choosing a
##              direction; it hands the chosen direction over with lock_aim()
##   GustRecoil the gust itself and the shove back; calls begin_gust() once
##
## Why a Node2D with top_level = true? top_level makes this node ignore its parent's
## transform, so its own coordinates ARE world coordinates, which keeps the aim
## preview drawing simple.

## Aim preview look (while holding gust in hold-to-aim mode). Grayed out when the
## aimed gust isn't allowed (straight down, no down-boosts left): releasing does nothing.
const AIM_PREVIEW_COLOR: Color = Color(0.85, 0.95, 1.0, 0.6)
const AIM_BLOCKED_COLOR: Color = Color(0.5, 0.5, 0.55, 0.4)

## Emitted after every gust, with how many pushable things were hit (for later FX/sfx).
signal gusted(direction: Vector2, hit_count: int)

## Seconds until the next gust is allowed.
var cooldown_remaining: float = 0.0
## Down-boosts left this airtime. Refilled on the ground. Unused when the tuning
## allows unlimited boosts (gust_down_boosts_per_airtime = 0).
var down_boosts_remaining: int = 0
## The player this ability belongs to. The parent node, set in _ready().
var player: Player
## True while the GustAim state is choosing a direction (draws the preview).
var is_aiming: bool = false
## The direction shown by the aim preview (ZERO = neutral: a circle).
var aim_preview_direction: Vector2 = Vector2.RIGHT
## Direction chosen by GustAim for the next gust (ZERO = neutral), valid while
## has_locked_aim is true. A flag is needed because ZERO is a real choice here.
var locked_aim: Vector2 = Vector2.ZERO
var has_locked_aim: bool = false


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	global_position = Vector2.ZERO
	z_index = 40  # aim preview above the room
	down_boosts_remaining = player.tuning.gust_down_boosts_per_airtime


## Runs after the player's move_and_slide() (children run after their parent), so
## is_on_floor() is this frame's value.
func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if player.is_on_floor():
		down_boosts_remaining = player.tuning.gust_down_boosts_per_airtime
	# Out of breath: the press does nothing, but say so with a tiny puff (instead of
	# silently ignoring the key, which feels like a dropped input).
	if Input.is_action_just_pressed("gust") and cooldown_remaining <= 0.0 \
			and not _can_afford() and not player.is_dead():
		_fizzle()
	if is_aiming:
		queue_redraw()


# --- Cooldown, breath and boost -------------------------------------------------

func can_gust() -> bool:
	return cooldown_remaining <= 0.0 and _can_afford()


## True if there's enough shared stamina for a gust (always true with the toggle off).
func _can_afford() -> bool:
	if not player.tuning.gust_uses_stamina:
		return true
	return player.glide.stamina_remaining >= player.tuning.gust_stamina_cost


## Uses one down-boost. Returns true if one was left (always true when unlimited).
func spend_down_boost() -> bool:
	if player.tuning.gust_down_boosts_per_airtime <= 0:
		return true
	if down_boosts_remaining <= 0:
		return false
	down_boosts_remaining -= 1
	return true


## Refills the down-boosts (wind crystal). Returns true if any were missing.
func refill_down_boosts() -> bool:
	var boost_count: int = player.tuning.gust_down_boosts_per_airtime
	if boost_count <= 0 or down_boosts_remaining >= boost_count:
		return false
	down_boosts_remaining = boost_count
	return true


## False for a gust that would do NOTHING for the player: straight down in the air
## with no down-boosts left (no lift, no sideways recoil). Such a press is ignored
## entirely, with no air, so it doesn't look like a broken extra jump.
## (Diagonal-down still recoils sideways, so it's allowed.)
func is_gust_allowed(direction: Vector2) -> bool:
	var is_straight_down: bool = direction.x == 0.0 and direction.y > 0.0
	if not is_straight_down or player.is_on_floor():
		return true
	if player.tuning.gust_down_boosts_per_airtime <= 0:
		return true
	return down_boosts_remaining > 0


## For the debug overlay: "2", or "inf" when unlimited.
func get_down_boosts_text() -> String:
	if player.tuning.gust_down_boosts_per_airtime <= 0:
		return "inf"
	return str(down_boosts_remaining)


## Back to a fresh state (called on respawn).
func reset() -> void:
	cooldown_remaining = 0.0
	down_boosts_remaining = player.tuning.gust_down_boosts_per_airtime
	has_locked_aim = false
	end_aim()


# --- Aiming (called by the GustAim state) ------------------------------------------

func begin_aim(direction: Vector2) -> void:
	is_aiming = true
	aim_preview_direction = direction


func update_aim(direction: Vector2) -> void:
	aim_preview_direction = direction


func end_aim() -> void:
	is_aiming = false
	queue_redraw()  # clear the preview


## GustAim fixes the direction for the gust it's about to fire (ZERO = neutral).
func lock_aim(direction: Vector2) -> void:
	locked_aim = direction
	has_locked_aim = true


## The direction for the gust starting now: the one GustAim locked in, or else the
## live arrows (ZERO when none are held = neutral gust). Clears the lock, so it's used once.
func take_gust_direction() -> Vector2:
	var direction: Vector2 = locked_aim if has_locked_aim else player.get_forgiving_aim_input()
	has_locked_aim = false
	return direction


# --- The gust itself (called by the GustRecoil state) -------------------------------

## The gust's area as world-space points: a cone toward `direction`, or a circle
## around the player for a neutral gust (ZERO). Public so the debug drawer can preview it.
func build_gust_shape(direction: Vector2) -> PackedVector2Array:
	var tuning: PlayerTuning = player.tuning
	if direction == Vector2.ZERO:
		return AirBlast.build_circle(player.get_center(), tuning.gust_neutral_radius)
	return AirBlast.build_cone(player.get_center(), direction, tuning.gust_range,
		tuning.gust_cone_half_angle_degrees, tuning.gust_cone_near_half_width)


## Starts the cooldown, spends breath, pushes everything Pushable in the gust's area
## (toward `direction`, or outward for a neutral gust), and plays the effects.
## Returns how many pushable objects were hit.
func begin_gust(direction: Vector2) -> int:
	var tuning: PlayerTuning = player.tuning
	cooldown_remaining = tuning.gust_cooldown
	if tuning.gust_uses_stamina:
		player.glide.spend(tuning.gust_stamina_cost)
	FX.shake(tuning.gust_shake_strength, tuning.gust_shake_duration)
	FX.play_sfx(&"gust")

	var hit_nodes: Array[Node]
	if direction == Vector2.ZERO:
		hit_nodes = _blow_neutral()
	else:
		hit_nodes = _blow_aimed(direction)
	gusted.emit(direction, hit_nodes.size())
	return hit_nodes.size()


## Neutral gust: everything nearby is pushed straight away from the player, with a
## full-circle burst of air and a shockwave ring.
func _blow_neutral() -> Array[Node]:
	var tuning: PlayerTuning = player.tuning
	var origin: Vector2 = player.get_center()
	var hit_nodes: Array[Node] = AirBlast.push_around(player, origin, tuning.gust_neutral_radius,
		tuning.gust_push_strength)
	var world: Node = player.get_parent()
	# A spread of 180 degrees on each side of the direction = a full circle.
	AirBlast.spawn_fan(world, origin, Vector2.UP, 180.0, tuning.gust_neutral_radius, 28)
	AirBlast.spawn_ring(world, origin, 4.0, tuning.gust_neutral_radius, 0.22)
	player.blast_debug.record_blast(build_gust_shape(Vector2.ZERO), hit_nodes)
	return hit_nodes


## Aimed gust: a cone toward `direction`.
func _blow_aimed(direction: Vector2) -> Array[Node]:
	var tuning: PlayerTuning = player.tuning
	var origin: Vector2 = player.get_center()
	var cone_points: PackedVector2Array = build_gust_shape(direction)
	var hit_nodes: Array[Node] = AirBlast.push_in_cone(player, cone_points, direction, tuning.gust_push_strength)
	var world: Node = player.get_parent()
	var far_half_width: float = tuning.gust_range * tan(deg_to_rad(tuning.gust_cone_half_angle_degrees))
	AirBlast.spawn_fan(world, origin, direction, tuning.gust_cone_half_angle_degrees, tuning.gust_range, 20)
	AirBlast.spawn_wave(world, origin, direction, tuning.gust_range,
		tuning.gust_cone_near_half_width, far_half_width, 0.0)
	AirBlast.spawn_wave(world, origin, direction, tuning.gust_range,
		tuning.gust_cone_near_half_width, far_half_width, 0.06)
	player.blast_debug.record_blast(cone_points, hit_nodes)
	return hit_nodes


# --- Drawing (aim preview) -----------------------------------------------------------

## Coordinates here are world coordinates (top_level, positioned at 0,0).
func _draw() -> void:
	if not is_aiming:
		return
	var shape_points: PackedVector2Array = build_gust_shape(aim_preview_direction)
	var closed_points: PackedVector2Array = shape_points.duplicate()
	closed_points.append(shape_points[0])
	var preview_color: Color = AIM_PREVIEW_COLOR if is_gust_allowed(aim_preview_direction) else AIM_BLOCKED_COLOR
	draw_polyline(closed_points, preview_color, 1.0)
	if aim_preview_direction == Vector2.ZERO:
		return  # neutral: the circle says it all
	# A short line down the middle so the exact direction is easy to read.
	var center: Vector2 = player.get_center()
	draw_line(center, center + aim_preview_direction * player.tuning.gust_range, preview_color, 1.0)


# --- Effects -----------------------------------------------------------------------

## Out of breath: a weak, short puff in the aim direction, and no push.
func _fizzle() -> void:
	AirBlast.spawn_fan(player.get_parent(), player.get_center(), player.get_aim_direction(),
		player.tuning.gust_cone_half_angle_degrees, 8.0, 5)

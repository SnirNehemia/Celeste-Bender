class_name GustAbility
extends Node2D
## Gust component (GAME_DESIGN.md §5.3). Lives as a child of the Player:
##   Player > GustAbility
##
## Responsibilities (and only these):
##   - the CHARGES: tuning.gust_charges_per_airtime gusts (normally ONE) between
##     leaving the ground and landing again. Landing refills them; a wind crystal
##     tops them back up; a gust diamond overcharges to tuning.gust_diamond_charges
##     for this airtime only. Ground gusts are free (no charge spent).
##     Shown as small white pips above the player while airborne.
##   - the COOLDOWN (one gust every tuning.gust_cooldown seconds)
##   - the BREATH cost (tuning.gust_uses_stamina, off by default): a gust spends
##     shared glide/dash stamina
##   - pressing gust with no charge (or no breath) plays a small "fizzle" puff instead
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

## Aim preview look (while holding gust in hold-to-aim mode).
const AIM_PREVIEW_COLOR: Color = Color(0.85, 0.95, 1.0, 0.6)

## Charge pips above the player's head (placeholder art, like the glide bar):
## one small square per charge, white when ready, faint when spent.
const PIP_SIZE: float = 2.0
## Distance between the left edges of two neighbouring pips, px (1 px gap).
const PIP_SPACING: float = 3.0
## Pips sit just above the glide bar (the bar's top is 15 px above the feet).
const PIP_OFFSET_Y: float = -19.0
const PIP_READY_COLOR: Color = Color(1, 1, 1, 0.95)
const PIP_SPENT_COLOR: Color = Color(1, 1, 1, 0.25)

## Emitted after every gust, with how many pushable things were hit (for later FX/sfx).
signal gusted(direction: Vector2, hit_count: int)

## Seconds until the next gust is allowed.
var cooldown_remaining: float = 0.0
## Gusts left this airtime. Set back to gust_charges_per_airtime on the ground
## (which also drops an unused diamond bonus). Unused when the tuning allows
## unlimited gusts (gust_charges_per_airtime = 0).
var charges_remaining: int = 0
## How many pips to draw: the most charges held this airtime (1 normally, 2 after
## a diamond), so a SPENT charge still shows as a faint pip.
var pip_count: int = 0
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
	z_index = 40  # aim preview and charge pips above the room
	_refill_on_ground()


## Runs after the player's move_and_slide() (children run after their parent), so
## is_on_floor() is this frame's value.
func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if player.is_on_floor():
		_refill_on_ground()
	# No charge left (or no breath): the press does nothing, but say so with a tiny
	# puff (instead of silently ignoring the key, which feels like a dropped input).
	if Input.is_action_just_pressed("gust") and cooldown_remaining <= 0.0 \
			and not _can_afford() and not player.is_dead() \
			and player.is_element_allowed(Player.ELEMENT_AIR):
		_fizzle()
	# Redraw every frame: the charge pips follow the player, and this node sits still
	# at the world origin (top_level), so nothing else would trigger a redraw.
	queue_redraw()


# --- Charges, cooldown and breath ----------------------------------------------

func can_gust() -> bool:
	return cooldown_remaining <= 0.0 and _can_afford()


## True if a gust can be paid for right now: a charge (or standing on the ground,
## where gusts are free) and, with the breath toggle on, enough shared stamina.
func _can_afford() -> bool:
	if not _has_charge():
		return false
	if not player.tuning.gust_uses_stamina:
		return true
	return player.glide.stamina_remaining >= player.tuning.gust_stamina_cost


## True on the ground (free), with unlimited charges, or with a charge left.
func _has_charge() -> bool:
	if player.tuning.gust_charges_per_airtime <= 0 or player.is_on_floor():
		return true
	return charges_remaining > 0


## Uses one charge, for a gust started in the air. Ground gusts are free.
func _spend_charge() -> void:
	if player.tuning.gust_charges_per_airtime <= 0 or player.is_on_floor():
		return
	charges_remaining = maxi(charges_remaining - 1, 0)


## Landing (and respawn): back to the normal number of charges. This SETS the count
## rather than topping it up, so an unused diamond bonus is lost on landing: the
## diamond is for the current airtime only.
func _refill_on_ground() -> void:
	charges_remaining = player.tuning.gust_charges_per_airtime
	pip_count = charges_remaining


## Wind crystal: tops the charges back up to the normal amount (an unused diamond
## bonus above that is kept). Returns true if any were missing, so the crystal is
## only used up when it helped.
func refill_charges() -> bool:
	var normal_count: int = player.tuning.gust_charges_per_airtime
	if normal_count <= 0 or charges_remaining >= normal_count:
		return false
	charges_remaining = normal_count
	pip_count = maxi(pip_count, charges_remaining)
	return true


## Gust diamond: sets the charges to gust_diamond_charges for this airtime.
## Refused on the ground (the landing refill would take the bonus straight back)
## and when you already have that many. Returns true if it helped, so the diamond
## is only used up when it did.
func overcharge() -> bool:
	var diamond_count: int = player.tuning.gust_diamond_charges
	if player.is_on_floor() or player.tuning.gust_charges_per_airtime <= 0 \
			or charges_remaining >= diamond_count:
		return false
	charges_remaining = diamond_count
	pip_count = maxi(pip_count, charges_remaining)
	return true


## For the debug overlay: "1", or "inf" when unlimited.
func get_charges_text() -> String:
	if player.tuning.gust_charges_per_airtime <= 0:
		return "inf"
	return str(charges_remaining)


## Back to a fresh state (called on respawn).
func reset() -> void:
	cooldown_remaining = 0.0
	_refill_on_ground()
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


## Starts the cooldown, spends a charge (in the air) and breath (if on), pushes
## everything Pushable in the gust's area (toward `direction`, or outward for a
## neutral gust), and plays the effects. Returns how many pushable objects were hit.
func begin_gust(direction: Vector2) -> int:
	var tuning: PlayerTuning = player.tuning
	cooldown_remaining = tuning.gust_cooldown
	_spend_charge()
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


# --- Drawing (charge pips and aim preview) -------------------------------------------

## Coordinates here are world coordinates (top_level, positioned at 0,0).
func _draw() -> void:
	_draw_charge_pips()
	if not is_aiming:
		return
	var shape_points: PackedVector2Array = build_gust_shape(aim_preview_direction)
	var closed_points: PackedVector2Array = shape_points.duplicate()
	closed_points.append(shape_points[0])
	draw_polyline(closed_points, AIM_PREVIEW_COLOR, 1.0)
	if aim_preview_direction == Vector2.ZERO:
		return  # neutral: the circle says it all
	# A short line down the middle so the exact direction is easy to read.
	var center: Vector2 = player.get_center()
	draw_line(center, center + aim_preview_direction * player.tuning.gust_range, AIM_PREVIEW_COLOR, 1.0)


## One small square per charge above the head: white = ready, faint = spent.
## Only shown in the air, where charges count (ground gusts are free), and only
## in rooms that allow Air.
func _draw_charge_pips() -> void:
	if player.is_on_floor() or player.is_dead() or pip_count <= 0 \
			or player.tuning.gust_charges_per_airtime <= 0 \
			or not player.is_element_allowed(Player.ELEMENT_AIR):
		return
	# Center the row over the player (origin = feet), rounded to whole pixels so the
	# squares stay crisp at 320x180.
	var row_width: float = PIP_SPACING * (pip_count - 1) + PIP_SIZE
	var row_origin: Vector2 = (player.global_position + Vector2(-row_width / 2.0, PIP_OFFSET_Y)).round()
	for pip_index: int in pip_count:
		var pip_color: Color = PIP_READY_COLOR if pip_index < charges_remaining else PIP_SPENT_COLOR
		var pip_position: Vector2 = row_origin + Vector2(PIP_SPACING * pip_index, 0.0)
		draw_rect(Rect2(pip_position, Vector2(PIP_SIZE, PIP_SIZE)), pip_color)


# --- Effects -----------------------------------------------------------------------

## No charge (or out of breath): a weak, short puff in the aim direction, and no push.
func _fizzle() -> void:
	AirBlast.spawn_fan(player.get_parent(), player.get_center(), player.get_aim_direction(),
		player.tuning.gust_cone_half_angle_degrees, 8.0, 5)

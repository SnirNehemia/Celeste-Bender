@tool
class_name SailPlatform
extends AnimatableBody2D
## Sail platform: a one-way platform with a mast and sail, on a straight RAIL.
## Wind moves it along the rail in the direction the wind blows:
##   - a gust gives it a shove; only the part of the gust that runs
##     ALONG the rail counts (a gust across the rail does nothing, like real sails
##     on a track). It then coasts and slows down with friction.
##   - inside a WindZone, it is pulled toward the zone's wind speed, so a current
##     carries it along by itself.
## At the ends of the rail it stops with a small bounce.
##
## Compare LeafPlatform: that one always goes the SAME way whatever the gust.
## The sail is the "points the way the wind goes" one, and its cloth bulges toward
## the way it's being blown.
##
## Placement: put the node at the CENTER of the deck's top surface (where your feet
## go). `rail_start` and `rail_end` are the rail's two ends relative to that spot;
## the platform starts where you put it (moved onto the rail if it's off it).
##
## Riding it: it's an AnimatableBody2D (a solid moved by script, see LeafPlatform),
## so a player standing on it is carried. Blow your own boat: a sideways gust made
## while standing on the deck has NO recoil. The sail takes the shove instead
## (absorb_gust_recoil(), called by the player's GustRecoil state), so you stay
## planted and sail off in the gust's direction. The deck also shelters you from
## wind zones (the sail catches that wind), so a current carries you WITH the sail
## instead of blowing you off its front. (Both: Player.get_wind_catching_floor().) Jumping off a moving sail keeps its
## speed (CharacterBody2D adds the platform's velocity when you leave it).
##
## Deck railings: short posts at both ends of the deck, decoration only (no
## collision), so you can see where the deck ends and that you're "aboard".
##
## Physics: the deck is a one-way surface on layer 1 ("world") + layer 4
## ("pushable"). One-way also means it never shoves the player sideways into a wall.
## A child Area2D covering the sail (layer 4) makes the gust easy to land: you can
## aim at the cloth, not just the thin deck.
##
## Fire (Fire_bending.md §6.2, Stage F8): the SAIL is flammable (contract in
## scenes/objects/fire/flammable.gd). The sail's Area2D is also on layer 6
## ("flammable"), so fireballs hit the cloth. Lit, the cloth stops catching wind AT
## ONCE (gusts and wind zones no longer move it), burns for `sail_burn_time`
## (FireTuning) and leaves a bare mast with a few black tatters. With no sail, the
## platform COASTS: it keeps the speed it had, with no friction, to the end of its
## rail, and stops dead there. A sail that was standing still stays where it is. The
## deck doesn't burn and the flame doesn't kill. R gives it a new sail.

## Not in the §2 color key: a slate deck, cream sail, darker mast.
const DECK_COLOR: Color = Color(0.4, 0.46, 0.55)
const DECK_EDGE_COLOR: Color = Color(0.58, 0.65, 0.75)
const MAST_COLOR: Color = Color(0.3, 0.33, 0.38)
const SAIL_COLOR: Color = Color(0.93, 0.87, 0.72)
## Decorative railings: post height and how far the top bar reaches inward, px.
const RAILING_HEIGHT: float = 5.0
const RAILING_BAR_LENGTH: float = 4.0
## Thickness of the solid deck, px.
const DECK_THICKNESS: float = 4.0
## Mast height above the deck and how far the sail's belly bulges, px.
const MAST_HEIGHT: float = 16.0
const SAIL_BULGE: float = 9.0
## Smallest bulge drawn, as a fraction, so a sail in still air isn't a flat line.
const SAIL_MIN_BULGE_FRACTION: float = 0.35
## A burning sail chars toward this; the burnt tatters are drawn in it.
const CHARRED_COLOR: Color = Color(0.12, 0.1, 0.09)
## Flame tongues up the burning cloth.
const SAIL_FLAME_COUNT: int = 3

## The sail's Area2D: layer 4 "pushable" (gusts find it) and layer 6 "flammable"
## (fireballs hit it). A burnt sail drops the flammable layer.
const SAIL_AREA_LAYERS: int = 8 | Flammable.LAYER_BIT

enum SailState { CLOTH, BURNING, BURNT }

## Width of the deck, px.
@export var deck_width: float = 32.0:
	set(value):
		deck_width = value
		_resize_shapes()
		queue_redraw()
## The rail's two ends, relative to where the platform is placed, px.
@export var rail_start: Vector2 = Vector2(-48, 0):
	set(value):
		rail_start = value
		queue_redraw()
@export var rail_end: Vector2 = Vector2(48, 0):
	set(value):
		rail_end = value
		queue_redraw()
## Fraction of the gust's push turned into sail speed. 160 x 0.6 = 96 px/s.
@export var gust_speed_multiplier: float = 0.6
## Top speed along the rail, px/s (several gusts in a row add up to this).
@export var max_speed: float = 140.0
## How fast it slows down in still air, px/s². 96 px/s coasts 96² / (2 x 60) ≈ 77 px.
@export var friction: float = 60.0
## How fast a wind zone brings it up to the wind's speed, px/s².
@export var wind_acceleration: float = 150.0
## Fraction of the speed kept (reversed) when hitting the end of the rail.
@export var end_bounce: float = 0.2

## The rail ends in the parent's (room's) coordinates, fixed at startup.
var rail_start_position: Vector2
var rail_end_position: Vector2
## Where along the rail we are, px from rail_start (0 .. rail length).
var distance_along_rail: float = 0.0
## Where it started, for reset().
var start_distance: float = 0.0
## Speed along the rail, px/s; positive = toward rail_end.
var rail_speed: float = 0.0
## -1..1: which way the sail bulges (+1 = toward rail_end's side). Eases toward the
## current motion so the cloth "flips" smoothly when the wind changes.
var sail_billow: float = 1.0
## Physics frame of the last gust that hit the sail directly (see absorb_gust_recoil).
var last_gust_frame: int = -1

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var sail_state: SailState = SailState.CLOTH
var sail_burn_remaining: float = 0.0
var sail_flames: Array[FlameTongue] = []

var deck_shape: CollisionShape2D
var sail_hit_shape: CollisionShape2D
var sail_area: Area2D


func _ready() -> void:
	collision_layer = 1 | 8  # bit values of layer 1 "world" and layer 4 "pushable"
	collision_mask = 0       # it moves by script; it doesn't need to detect anything
	deck_shape = CollisionShape2D.new()
	deck_shape.shape = RectangleShape2D.new()
	deck_shape.one_way_collision = true
	add_child(deck_shape)

	sail_area = Area2D.new()
	sail_area.collision_layer = SAIL_AREA_LAYERS
	sail_area.collision_mask = 0
	sail_area.monitoring = false
	sail_hit_shape = CollisionShape2D.new()
	sail_hit_shape.shape = RectangleShape2D.new()
	sail_area.add_child(sail_hit_shape)
	add_child(sail_area)
	_resize_shapes()
	if Engine.is_editor_hint():
		return

	rail_start_position = position + rail_start
	rail_end_position = position + rail_end
	# Project the placed spot onto the rail, in case it was placed slightly off it.
	var rail_vector: Vector2 = rail_end_position - rail_start_position
	if rail_vector.length() > 0.0:
		start_distance = clampf((position - rail_start_position).dot(rail_vector.normalized()),
			0.0, rail_vector.length())
	distance_along_rail = start_distance
	sail_billow = 1.0
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(Flammable.GROUP)
	var flame_merge: FlameMerge = FlameMerge.make(self)
	for flame_index: int in SAIL_FLAME_COUNT:
		var flame: FlameTongue = FlameTongue.new()
		flame.position = Vector2(2.0, -3.0 - flame_index * (MAST_HEIGHT - 4.0) / SAIL_FLAME_COUNT)
		flame.length = 7.0
		flame.base_width = 4.0
		flame.fan_width = 5.0
		flame.heat = 0.5
		flame.lick_rate = 4.0
		flame.lick_size = 2.5
		flame.smoke_rate = 3.0 if flame_index == SAIL_FLAME_COUNT - 1 else 0.0
		flame.z_index = 1
		flame.visible = false
		add_child(flame)
		flame_merge.add_tongue(flame)
		sail_flames.append(flame)
	_apply_position()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var rail_axis: Vector2 = _get_rail_axis()
	var rail_length: float = rail_start_position.distance_to(rail_end_position)
	if sail_state != SailState.CLOTH:
		_coast(delta, rail_length)
		return

	# Wind zones pull the speed toward the wind's speed along the rail; in still air,
	# friction brings it to a stop.
	var wind_along_rail: float = 0.0
	var is_in_wind: bool = false
	var sail_center: Vector2 = global_position + Vector2(0.0, -MAST_HEIGHT / 2.0)
	for zone: Node in get_tree().get_nodes_in_group(WindZone.GROUP):
		var wind_zone: WindZone = zone as WindZone
		if wind_zone != null and wind_zone.contains_point(sail_center):
			wind_along_rail += wind_zone.get_wind_velocity().dot(rail_axis)
			is_in_wind = true
	if is_in_wind:
		rail_speed = move_toward(rail_speed, wind_along_rail, wind_acceleration * delta)
	else:
		rail_speed = move_toward(rail_speed, 0.0, friction * delta)

	distance_along_rail += rail_speed * delta
	# The ends of the rail: stop there, bouncing back a little.
	if distance_along_rail < 0.0:
		distance_along_rail = 0.0
		rail_speed = -rail_speed * end_bounce
	elif distance_along_rail > rail_length:
		distance_along_rail = rail_length
		rail_speed = -rail_speed * end_bounce

	# The cloth leans the way it's moving (or the way the wind pushes in a zone).
	var push_sign: float = signf(wind_along_rail) if is_in_wind else signf(rail_speed)
	if push_sign != 0.0:
		sail_billow = move_toward(sail_billow, push_sign, 6.0 * delta)
	_apply_position()


## The Pushable contract. Only the part of the gust that runs along the rail counts:
## dot() of two unit vectors is 1 when they point the same way, 0 when crossing.
func receive_gust(direction: Vector2, strength: float) -> void:
	if sail_state != SailState.CLOTH:
		return  # no cloth, nothing for the wind to push
	last_gust_frame = Engine.get_physics_frames()
	var push_along_rail: float = direction.dot(_get_rail_axis()) * strength * gust_speed_multiplier
	rail_speed = clampf(rail_speed + push_along_rail, -max_speed, max_speed)


## Called by the player's GustRecoil state when they gust sideways while standing on
## the deck: the sail takes the recoil, pushed along the gust's direction.
## The gust's cone usually hits the sail itself in the same frame (receive_gust ran
## first, the gust pushes before the recoil happens); only push if it didn't, e.g.
## when gusting outward from the very end of the deck, so it's never pushed twice.
func absorb_gust_recoil(direction: Vector2, strength: float) -> void:
	if last_gust_frame != Engine.get_physics_frames():
		receive_gust(direction, strength)


## A burning or burnt sail: the cloth burns down, and the platform keeps its speed
## (no friction, no wind) until the end of the rail, where it stops dead.
func _coast(delta: float, rail_length: float) -> void:
	if sail_state == SailState.BURNING:
		sail_burn_remaining -= delta
		if sail_burn_remaining <= 0.0:
			sail_state = SailState.BURNT
			# The cloth is gone: fireballs fly through where it was.
			sail_area.collision_layer = SAIL_AREA_LAYERS & ~Flammable.LAYER_BIT
			for flame: FlameTongue in sail_flames:
				flame.visible = false
			SmokePuff.spawn(get_parent(), global_position + Vector2(0.0, -MAST_HEIGHT / 2.0), 3)
	distance_along_rail += rail_speed * delta
	if distance_along_rail <= 0.0 or distance_along_rail >= rail_length:
		distance_along_rail = clampf(distance_along_rail, 0.0, rail_length)
		rail_speed = 0.0
	_apply_position()


# --- The Flammable contract (Stage F8): the sail burns ---------------------------------

func ignite(_source: Node) -> void:
	if sail_state != SailState.CLOTH:
		return
	sail_state = SailState.BURNING
	sail_burn_remaining = fire_tuning.sail_burn_time
	for flame: FlameTongue in sail_flames:
		flame.visible = true
	EmberEmitter.burst(get_parent(), global_position + Vector2(3.0, -MAST_HEIGHT / 2.0), 6,
		Vector2.UP, 160.0, 50.0)
	FX.play_sfx(&"fire_ignite")


func is_burning() -> bool:
	return sail_state == SailState.BURNING


## Gusts against fire come in Stage F10.
func snuff() -> void:
	pass


## The sail's cloth, world coordinates (as wide as it can bulge both ways). Nothing
## left to catch once it has burnt.
func get_fire_rect() -> Rect2:
	if sail_state == SailState.BURNT:
		return Rect2()
	var size: Vector2 = Vector2(SAIL_BULGE * 2.0 + 4.0, MAST_HEIGHT)
	return Rect2(global_position + Vector2(-size.x / 2.0, -MAST_HEIGHT), size)


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	sail_state = SailState.CLOTH
	sail_area.collision_layer = SAIL_AREA_LAYERS
	for flame: FlameTongue in sail_flames:
		flame.visible = false
	distance_along_rail = start_distance
	rail_speed = 0.0
	sail_billow = 1.0
	_apply_position()


## Unit vector from rail_start to rail_end (falls back to "right" for a zero rail).
func _get_rail_axis() -> Vector2:
	var rail_vector: Vector2 = rail_end - rail_start
	return rail_vector.normalized() if rail_vector.length() > 0.0 else Vector2.RIGHT


## Puts the body at its spot on the rail (whole pixels, see LeafPlatform) and redraws.
func _apply_position() -> void:
	position = (rail_start_position + _get_rail_axis() * distance_along_rail).round()
	queue_redraw()


func _resize_shapes() -> void:
	if deck_shape == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(deck_shape.shape as RectangleShape2D).size = Vector2(deck_width, DECK_THICKNESS)
	deck_shape.position = Vector2(0.0, DECK_THICKNESS / 2.0)
	# The sail's hitbox: the mast's height, and as wide as the sail can bulge both ways.
	(sail_hit_shape.shape as RectangleShape2D).size = Vector2(SAIL_BULGE * 2.0 + 4.0, MAST_HEIGHT)
	sail_hit_shape.position = Vector2(0.0, -MAST_HEIGHT / 2.0)


func _draw() -> void:
	# Rail first (behind). In the editor the rail is relative to "here"; in game, its
	# ends are fixed in the room, so draw them relative to where we are now.
	if Engine.is_editor_hint():
		RailTrack.draw(self, rail_start + Vector2(0.0, 2.0), rail_end + Vector2(0.0, 2.0))
	else:
		RailTrack.draw(self, rail_start_position - position + Vector2(0.0, 2.0),
			rail_end_position - position + Vector2(0.0, 2.0))

	var half_width: float = deck_width / 2.0
	var deck: Rect2 = Rect2(-half_width, 0.0, deck_width, DECK_THICKNESS)
	draw_rect(deck, DECK_COLOR)
	draw_line(Vector2(-half_width, 0.5), Vector2(half_width, 0.5), DECK_EDGE_COLOR, 1.0)
	# Railings: a post at each end with a short top bar pointing inward.
	for side: float in [-1.0, 1.0]:
		var post_x: float = side * (half_width - 0.5)
		draw_line(Vector2(post_x, 0.0), Vector2(post_x, -RAILING_HEIGHT), DECK_EDGE_COLOR, 1.0)
		draw_line(Vector2(post_x, -RAILING_HEIGHT + 0.5),
			Vector2(post_x - side * RAILING_BAR_LENGTH, -RAILING_HEIGHT + 0.5), DECK_EDGE_COLOR, 1.0)
	draw_line(Vector2.ZERO, Vector2(0.0, -MAST_HEIGHT), MAST_COLOR, 1.0)

	# The sail: a curved triangle hanging off the mast, bulging sideways toward the
	# way it's blown. Always sideways (never up/down along the mast, which would make
	# a flat, invalid polygon), so on a vertical rail "toward rail_end" = right.
	var axis: Vector2 = _get_rail_axis()
	var end_side: float = signf(axis.x) if absf(axis.x) > 0.3 else 1.0
	var bulge_fraction: float = signf(sail_billow) * maxf(absf(sail_billow), SAIL_MIN_BULGE_FRACTION)
	if sail_billow == 0.0:
		bulge_fraction = SAIL_MIN_BULGE_FRACTION
	var bulge: Vector2 = Vector2(end_side * SAIL_BULGE * bulge_fraction, 0.0)
	var top: Vector2 = Vector2(0.0, -MAST_HEIGHT + 1.0)
	var bottom: Vector2 = Vector2(0.0, -3.0)
	if sail_state == SailState.BURNT:
		# A bare mast with a few black tatters hanging off it.
		for tatter_index: int in 3:
			var tatter_top: Vector2 = top.lerp(bottom, 0.15 + tatter_index * 0.3)
			draw_line(tatter_top, tatter_top + Vector2(end_side * (2.0 + tatter_index), 3.0), CHARRED_COLOR, 1.0)
		return
	# A burning sail goes limp and chars as it burns.
	var burnt_amount: float = 0.0
	if sail_state == SailState.BURNING:
		burnt_amount = 1.0 - clampf(sail_burn_remaining / maxf(fire_tuning.sail_burn_time, 0.01), 0.0, 1.0)
		bulge *= 1.0 - burnt_amount * 0.6
	draw_colored_polygon(PackedVector2Array([
		top,
		top.lerp(bottom, 0.3) + bulge * 0.7,
		top.lerp(bottom, 0.65) + bulge,
		bottom + bulge * 0.8,
		bottom,
	]), SAIL_COLOR.lerp(CHARRED_COLOR, burnt_amount))

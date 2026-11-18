@tool
class_name SkyShip
extends AnimatableBody2D
## Sky ship: a big wooden ship with sails that FLIES FREELY, in any direction, on the
## wind. No rail (compare SailPlatform, which rides one).
##
## THE SHAPE (a tile is 8 px; the origin is the bottom-middle of the keel, like a
## crate, so it's placed standing on the floor):
##   - the HULL: 7 tiles wide on top, 5 at the keel, 2 tiles deep. SOLID from every
##     side: you stand on its deck, bump into its sides, and it pushes you.
##   - the MAST: 7 tiles tall, from the middle of the deck. Not solid (you walk past it).
##   - the CROW'S NEST: a 3-tile one-way platform halfway up the mast. Stand there:
##     gusts from up here push harder than from the deck (nest_push_multiplier).
##   - LIPS: a 2 px raised edge at both ends of the deck and of the crow's nest, so
##     walking or being carried never slides you off by accident. Jump to get off.
##     A lip is solid ONLY while you stand on its own floor (the nest's lips while
##     you're on the nest, the deck's while you're on the deck): coming from below or
##     the side you pass through it, so it never snags you on the way up.
##   - two COURSE SAILS, one each side of the mast between the deck and the crow's
##     nest, hanging from a YARD (a spar across the mast): they belly out sideways on
##     a sideways gust.
##   - one TOPSAIL above the crow's nest, across the mast like the upper sail of a
##     square-rigged ship (the mast in front of it): it puffs up on an upward gust and spills
##     their air (sag) on a downward one.
##   All drawn in _draw() with placeholder shapes (no sprite).
##
## HOW IT MOVES (the numbers are in ShipTuning, resources/ship_tuning.tres):
##   - It has MOMENTUM: a 2D `velocity` that pushes only ADD to. In the air it loses
##     its sideways speed slowly (low drag: a heavy ship coasting), and its vertical
##     speed eases toward a slow SINK: with nothing lifting it, it settles to the
##     ground and rests there (dragging its keel: more friction).
##   - Standing aboard (on the deck or the crow's nest) and gusting: your feet stay
##     put and the SHIP takes the gust (absorb_gust_recoil, the wind-catcher contract
##     the player's GustRecoil state calls, see Player.get_wind_catching_floor).
##     Sideways sails it that way, up lifts it, down brings it down faster; a
##     diagonal does both. A neutral gust (no arrow) brakes it.
##   - A gust from OFF the ship that hits it pushes it too (the Pushable contract).
##   - WIND ZONES pull its speed toward the wind's (slowly: it's heavy). Updrafts
##     lift it. While you're aboard, the ship takes the wind, not you (Player.
##     get_wind_velocity is zero on a wind-catching floor).
##   - It stops against terrain (walls, ceilings, the ground), bouncing back a little
##     when it hits hard, and the room's edges stop it too: it stays in its room.
##   - It never crushes you: if it would push you into something solid, it stops.
##   - JUMPING OFF keeps its speed: the player is handed the ship's sideways speed as
##     a short tailwind (Player.start_floor_carry, ShipTuning "Jumping off"), so a
##     jump off a fast ship doesn't fall behind it.
##   - Death or R puts it back where it was placed (Room.RESETTABLE_GROUP).
##
## HOW THE MOVE WORKS: each physics frame it works out where it wants to go
## (velocity x delta) and moves one axis at a time, x then y, so a ship scraping
## along the ground keeps sliding instead of sticking. For each axis it:
##   1. sweeps its shapes against the world (PhysicsDirectSpaceState2D.cast_motion:
##      "how far can this shape travel before it hits something?"),
##   2. stops at the room's edge,
##   3. checks its rider (the player aboard) has room to be carried that far,
##   4. shoves the player if it runs into them, and stops if they can't move.
## Then it sets `position`. NOT rounded to whole pixels (after the first play-test):
## a rounded body moved in 0/1/2 px jerks, and the rider kept losing touch with it.
## Only the DRAWING snaps to whole pixels (_draw), so the art stays crisp.
##
## THE SAILS (drawn only) are springs: each has a fill (-1..1, how far it bellies out
## which way) pulled toward what the ship's speed (or the wind, if stronger) fills it
## to, with a little overshoot. A gust KICKS the spring, so the cloth snaps full,
## overshoots and settles; slack cloth flutters. The pennant streams with the apparent
## wind and speed lines trail behind a fast ship.
##
## Godot concept: AnimatableBody2D is a solid body moved by code (not by physics
## forces). When its position changes, Godot works out its speed, and a
## CharacterBody2D standing on it (the player) is carried along by move_and_slide().
##
## Physics layers: the body is on layer 1 ("world": the player stands on it and
## bumps into it) and layer 4 ("pushable": gusts find it). An Area2D over the sails,
## also on layer 4, makes gusts aimed at the cloth land.

## Wood and cloth (not in the GAME_DESIGN.md §2 color key: a new kind of object).
const HULL_COLOR: Color = Color(0.47, 0.29, 0.16)
const HULL_DARK_COLOR: Color = Color(0.34, 0.2, 0.11)
const HULL_RIM_COLOR: Color = Color(0.68, 0.47, 0.27)
const KEEL_COLOR: Color = Color(0.22, 0.13, 0.08)
const PLANK_LINE_COLOR: Color = Color(0.36, 0.22, 0.12)
const WINDOW_COLOR: Color = Color(0.16, 0.12, 0.1)
const WINDOW_RIM_COLOR: Color = Color(0.8, 0.64, 0.36)
const MAST_COLOR: Color = Color(0.4, 0.26, 0.15)
const MAST_LIGHT_COLOR: Color = Color(0.56, 0.38, 0.22)
const SAIL_COLOR: Color = Color(0.93, 0.87, 0.72)
const SAIL_SHADE_COLOR: Color = Color(0.8, 0.72, 0.57)
const SAIL_LIGHT_COLOR: Color = Color(1.0, 0.97, 0.88)
const SPEED_LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)
const SAIL_EDGE_COLOR: Color = Color(0.58, 0.5, 0.38)
const ROPE_COLOR: Color = Color(0.27, 0.21, 0.16, 0.85)
const PENNANT_COLOR: Color = Color(0.8, 0.25, 0.2)

## The hull's outline, keel-bottom-middle at (0, 0): 56 px (7 tiles) across the deck,
## 40 px (5 tiles) across the keel, 16 px (2 tiles) deep, with slightly rounded sides.
## Listed clockwise from the deck's left end. The collision uses it too.
const HULL_OUTLINE: PackedVector2Array = [
	Vector2(-28, -16), Vector2(28, -16), Vector2(27, -11), Vector2(24, -5), Vector2(20, 0),
	Vector2(-20, 0), Vector2(-24, -5), Vector2(-27, -11),
]
## The deck's height above the keel, px (the hull's top).
const DECK_HEIGHT: float = 16.0
## The mast: 7 tiles above the deck.
const MAST_HEIGHT: float = 56.0
## How wide the mast is to terrain, px (drawn 2 px wide): see rig_sweep_shape.
const MAST_SWEEP_WIDTH: float = 2.0
## The crow's nest: 3 tiles wide, its top halfway up the mast, this thick.
const NEST_WIDTH: float = 24.0
const NEST_THICKNESS: float = 3.0
## The nest is one-way, and Godot moves the ship a frame ahead of the player standing
## on it: rising fast, it overlaps your feet by over a pixel. The default 1 px of
## one-way forgiveness let you sink through it (found in the first play-test), so
## it forgives this much.
const NEST_ONE_WAY_MARGIN: float = 4.0
## The lips at the ends of the deck and the nest: this tall and wide, px.
const LIP_HEIGHT: float = 2.0
const LIP_WIDTH: float = 2.0
## Course sails: their yard (top) and foot (bottom), px above the keel, and how far
## from the mast they start and end. Both are mirror images, one each side.
const COURSE_TOP: float = 39.0
const COURSE_FOOT: float = 21.0
const COURSE_INNER_X: float = 3.0
const COURSE_OUTER_X: float = 25.0
## How far a full course sail bellies out sideways, px.
const COURSE_BULGE: float = 6.0
## The course sails' yard: a spar 2 px thick right under the crow's nest, reaching
## this far each side of the mast (past the sails), its arms tapering to 1 px.
const COURSE_YARD_HALF: float = 27.0
## A diagonal gust lifts the course sails' foot (bottom edge) this many px at most
## (a downward one lets it sag), so their belly leans up or down too.
const COURSE_FOOT_LIFT: float = 3.0
## The topsail: one sail across the mast above the crow's nest, WIDE and SHORT (after
## the second play-test: 5 tiles across, under 1.5 tall), like the upper sails of an
## old square-rigger. Its foot and head (top) above the keel, and half-widths: a
## little wider at the foot than at the head.
const TOPSAIL_FOOT: float = 50.0
const TOPSAIL_HEAD: float = 61.0
const TOPSAIL_FOOT_HALF: float = 20.0
const TOPSAIL_HEAD_HALF: float = 17.0
## How far a full topsail domes up, px (and how far a spilled one sags).
const TOPSAIL_BULGE: float = 4.0
const TOPSAIL_SAG: float = 2.0
## A sideways gust leans the topsail's dome and swells its leeward side this much, px.
const TOPSAIL_LEAN: float = 2.5
## Points along each bowed sail edge (more = smoother curve).
const SAIL_EDGE_STEPS: int = 5
## The sails' springs (a look, not feel: no tuning). Stiffness pulls the fill toward
## its target (1/s²); damping slows it (1/s). These overshoot a little and settle in
## about half a second. A gust kicks the fill's speed by SAIL_GUST_KICK (fill/s).
const SAIL_SPRING_STIFFNESS: float = 60.0
const SAIL_SPRING_DAMPING: float = 7.0
const SAIL_GUST_KICK: float = 9.0
## Drawn fill is clamped to this (the overshoot can billow past "full").
const SAIL_MAX_DRAWN_FILL: float = 1.35
## Moving this fast (px/s), or in wind this fast, fills the sails all the way.
const SAIL_FULL_SPEED: float = 60.0
## Slack cloth flutters: this many px at most, this fast (radians/s), in waves this
## long along the edge (radians per edge).
const FLUTTER_SIZE: float = 1.3
const FLUTTER_RATE: float = 11.0
const FLUTTER_WAVES: float = 5.0
## Speed lines behind a fast ship: shown above this speed, px/s, this long at most.
const SPEED_LINE_MIN_SPEED: float = 45.0
const SPEED_LINE_MAX_LENGTH: float = 14.0
## The pennant at the masthead: its length, and the apparent wind (px/s) that
## streams it out fully (less: it droops).
const PENNANT_LENGTH: float = 7.0
const PENNANT_FULL_WIND: float = 40.0

## The world's collision layers the ship stops against: layer 1, "world".
const WORLD_MASK: int = 1
## The player's layer (2), for "did we run into the player?".
const PLAYER_MASK: int = 2
## The sweep shapes are this much smaller than the real hull on every side, px, so a
## ship RESTING on the ground (touching it) can still slide along it: a shape that
## touches counts as hitting, and it would be stuck. Rounding to whole pixels is
## covered by this too.
const SWEEP_INSET: float = 0.5
## The rider's gap check counts a blocked carry below this length, px, as "fits".
const MIN_MOVE: float = 0.01

## The tuning every ship shares (the F5 panel's "Ship" tab edits this one).
var ship_tuning: ShipTuning = preload("res://resources/ship_tuning.tres")
## Current speed, px/s.
var velocity: Vector2 = Vector2.ZERO
## Where it really is (room coordinates). `position` is the same (it was rounded once).
var exact_position: Vector2 = Vector2.ZERO
## Where it was placed, for reset().
var home_position: Vector2 = Vector2.ZERO
## True while its keel rests on something (the last downward move was blocked).
var is_resting: bool = false
## How full the sails look. Course: -1 (bellied left) .. +1 (bellied right).
## Sky (the topsail): -1 (spilled, sagging) .. +1 (puffed up). Drawn only, springs
## (see the header). A diagonal gust kicks both, so the cloth bellies diagonally:
## each has its own speed, fill per second.
var course_fill: float = 0.0
var course_fill_speed: float = 0.0
var sky_fill: float = 0.0
var sky_fill_speed: float = 0.0
## Seconds since it was made: drives the flutter and the pennant's flapping.
var sail_time: float = 0.0
## The wind where the sails are this frame (sum of the wind zones), px/s.
var sail_wind: Vector2 = Vector2.ZERO
## The room it belongs to (its edges stop it), or null outside a room (editor).
var room: Room = null
## The player standing on it last frame, or null: when they leave, they get its speed.
var last_rider: Player = null

var hull_shape: CollisionPolygon2D
var nest_shape: CollisionShape2D
## The lips' shapes (see _update_lips): the deck's two and the nest's two.
var deck_lips: Array[CollisionShape2D] = []
var nest_lips: Array[CollisionShape2D] = []
var sail_area: Area2D
## The shapes swept against the world: the hull, and the mast (a thin strip; the
## sails pass through terrain, see rig_sweep_shape).
var hull_sweep_shape: ConvexPolygonShape2D
## The hull a little BIGGER than the real one, swept toward the player: the body is
## drawn and collides at the rounded position, up to half a pixel further on, and must
## never end up inside you (the player's own move would then shove you into a wall).
var hull_contact_shape: ConvexPolygonShape2D
## The MAST swept against the world, a thin strip: only the wood is solid to terrain.
## The sails and yards pass through walls and ledges (a box round them made the empty
## air beside the mast snag on things), but a low ceiling still stops the masthead.
var rig_sweep_shape: RectangleShape2D
## The mast strip's center, relative to the origin.
var rig_sweep_offset: Vector2


func _ready() -> void:
	collision_layer = 1 | 8  # bit values of layer 1 "world" and layer 4 "pushable"
	collision_mask = 0       # it moves by script and does its own sweeps

	hull_shape = CollisionPolygon2D.new()
	hull_shape.polygon = HULL_OUTLINE
	add_child(hull_shape)

	# The crow's nest: one-way, so you jump up through it and land on top.
	nest_shape = CollisionShape2D.new()
	var nest_rect: RectangleShape2D = RectangleShape2D.new()
	nest_rect.size = Vector2(NEST_WIDTH, NEST_THICKNESS)
	nest_shape.shape = nest_rect
	nest_shape.position = Vector2(0.0, -_get_nest_top() + NEST_THICKNESS / 2.0)
	nest_shape.one_way_collision = true
	nest_shape.one_way_collision_margin = NEST_ONE_WAY_MARGIN
	add_child(nest_shape)

	# The lips: little blocks at both ends of the deck and of the nest, off until
	# you stand on their floor (_update_lips).
	for side: float in [-1.0, 1.0]:
		deck_lips.append(_add_lip(Vector2(side * (HULL_OUTLINE[1].x - LIP_WIDTH / 2.0), -DECK_HEIGHT - LIP_HEIGHT / 2.0)))
		nest_lips.append(_add_lip(Vector2(side * (NEST_WIDTH - LIP_WIDTH) / 2.0, -_get_nest_top() - LIP_HEIGHT / 2.0)))

	# The sails' gust target: everything above the deck, as wide as the hull.
	sail_area = Area2D.new()
	sail_area.collision_layer = 8  # layer 4 "pushable"
	sail_area.collision_mask = 0
	sail_area.monitoring = false
	var sail_hit_shape: CollisionShape2D = CollisionShape2D.new()
	var sail_rect: RectangleShape2D = RectangleShape2D.new()
	sail_rect.size = Vector2(HULL_OUTLINE[1].x * 2.0, MAST_HEIGHT)
	sail_hit_shape.shape = sail_rect
	sail_hit_shape.position = Vector2(0.0, -DECK_HEIGHT - MAST_HEIGHT / 2.0)
	sail_area.add_child(sail_hit_shape)
	add_child(sail_area)
	if Engine.is_editor_hint():
		return

	# The sweep shapes, a little smaller than the real ones (see SWEEP_INSET).
	hull_sweep_shape = _make_hull_shape(-SWEEP_INSET)
	hull_contact_shape = _make_hull_shape(SWEEP_INSET)
	rig_sweep_shape = RectangleShape2D.new()
	rig_sweep_shape.size = Vector2(MAST_SWEEP_WIDTH, MAST_HEIGHT - SWEEP_INSET * 2.0)
	rig_sweep_offset = Vector2(0.0, -DECK_HEIGHT - MAST_HEIGHT / 2.0)

	room = Room.find_room_of(self)
	home_position = position
	exact_position = position
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var tuning: ShipTuning = ship_tuning
	sail_wind = _get_sail_wind()

	# Sideways: pulled toward the wind's speed in a zone, else drag (more on the ground).
	if sail_wind.x != 0.0:
		velocity.x = move_toward(velocity.x, sail_wind.x * tuning.wind_speed_share, tuning.wind_acceleration * delta)
	else:
		var drag: float = tuning.ground_friction if is_resting else tuning.air_drag
		velocity.x = move_toward(velocity.x, 0.0, drag * delta)
	# Up and down: an updraft (or downdraft) pulls toward its speed; otherwise it eases
	# toward the slow sink. move_toward also bleeds off a gust's rise.
	if sail_wind.y != 0.0:
		velocity.y = move_toward(velocity.y, sail_wind.y * tuning.wind_speed_share, tuning.wind_acceleration * delta)
	else:
		velocity.y = move_toward(velocity.y, tuning.sink_speed, tuning.vertical_drag * delta)
	_clamp_speed()

	# One axis at a time (see the header).
	var rider: Player = _get_rider()
	_hand_speed_to_leaving_rider(rider)
	_update_lips(rider)
	_move_axis(Vector2(velocity.x * delta, 0.0), rider)
	is_resting = false
	_move_axis(Vector2(0.0, velocity.y * delta), rider)
	position = exact_position  # NOT rounded: see _draw (a rounded body jerked the rider off it)

	_animate_sails(delta)
	queue_redraw()


## Moves `motion` (along one axis) as far as nothing stops it, and handles the hit.
func _move_axis(motion: Vector2, rider: Player) -> void:
	if motion.length() < MIN_MOVE:
		return
	var allowed: Vector2 = motion * _get_world_fraction(motion)
	allowed = _clamp_to_room(allowed)
	if rider != null:
		allowed = _clamp_for_rider(allowed, rider)
	allowed = _shove_player(allowed, rider)
	exact_position += allowed
	if allowed.length() < motion.length() - MIN_MOVE:
		_bump(motion)


## How much of `motion` (0..1) the hull and the mast can travel before they hit
## the world. cast_motion() returns [safe, unsafe]: "safe" is the last fraction with
## no overlap.
func _get_world_fraction(motion: Vector2) -> float:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var origin: Vector2 = _get_global_exact_position()
	var fraction: float = 1.0
	for shape_and_offset: Array in [[hull_sweep_shape, Vector2.ZERO], [rig_sweep_shape, rig_sweep_offset]]:
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = shape_and_offset[0]
		query.transform = Transform2D(0.0, origin + shape_and_offset[1])
		query.motion = motion
		query.collision_mask = WORLD_MASK
		query.exclude = [get_rid()]
		var result: PackedFloat32Array = space.cast_motion(query)
		if result.size() == 2:
			fraction = minf(fraction, result[0])
	return fraction


## The room's edges are walls for the ship: it stays in its room.
func _clamp_to_room(motion: Vector2) -> Vector2:
	if room == null:
		return motion
	var bounds: Rect2 = room.get_bounds()
	var origin: Vector2 = _get_global_exact_position()
	var half_width: float = HULL_OUTLINE[1].x
	var lowest_x: float = bounds.position.x + half_width
	var highest_x: float = bounds.end.x - half_width
	var lowest_y: float = bounds.position.y + DECK_HEIGHT + MAST_HEIGHT
	var highest_y: float = bounds.end.y
	var target: Vector2 = origin + motion
	# clampf, but never pull it backward if it was already past an edge (placed there).
	if motion.x < 0.0:
		target.x = maxf(target.x, minf(lowest_x, origin.x))
	elif motion.x > 0.0:
		target.x = minf(target.x, maxf(highest_x, origin.x))
	if motion.y < 0.0:
		target.y = maxf(target.y, minf(lowest_y, origin.y))
	elif motion.y > 0.0:
		target.y = minf(target.y, maxf(highest_y, origin.y))
	return target - origin


## The player aboard is carried along; if they'd be carried into a wall or a ceiling
## (their head above the crow's nest is the highest point, past the masthead
## only a little), the ship stops where they still fit.
func _clamp_for_rider(motion: Vector2, rider: Player) -> Vector2:
	var collision: KinematicCollision2D = KinematicCollision2D.new()
	# Ignore the ship itself for this check (the rider stands on it).
	rider.add_collision_exception_with(self)
	var is_blocked: bool = rider.test_move(rider.global_transform, motion, collision)
	rider.remove_collision_exception_with(self)
	if not is_blocked:
		return motion
	return collision.get_travel()


## Running into the player (not the rider): push them along. If they can't go (a wall
## behind them), the ship stops against them instead: it never crushes you.
func _shove_player(motion: Vector2, rider: Player) -> Vector2:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player == rider or player.is_dead():
		return motion
	# Moving away from them: nothing to push.
	var origin: Vector2 = _get_global_exact_position()
	var hull_middle: Vector2 = origin + Vector2(0.0, -DECK_HEIGHT / 2.0)
	if (player.get_center() - hull_middle).dot(motion) <= 0.0:
		return motion
	# Already touching them (pushed them last frame)? Then the whole move pushes.
	# Otherwise sweep the hull toward them: how far until it touches? (cast_motion
	# ignores what the shape already overlaps at its start, hence the first check.)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = hull_contact_shape
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = PLAYER_MASK
	var touch_fraction: float = 0.0
	if space.intersect_shape(query, 1).is_empty():
		query.motion = motion
		var result: PackedFloat32Array = space.cast_motion(query)
		if result.size() < 2 or result[0] >= 1.0:
			return motion  # never touches them
		touch_fraction = result[0]
	# The rest of the move, past the touch, the player is pushed along. Their own move
	# stops at walls (move_and_collide); whatever they couldn't go, the ship doesn't go
	# either.
	var to_touch: Vector2 = motion * touch_fraction
	var push: Vector2 = motion - to_touch
	player.add_collision_exception_with(self)
	var collision: KinematicCollision2D = player.move_and_collide(push)
	player.remove_collision_exception_with(self)
	if collision == null:
		return motion
	return to_touch + push - collision.get_remainder()


## Hit something along `motion`'s axis: bounce back a little if it was fast, else
## stop. Landing (moving down) means resting on the ground.
func _bump(motion: Vector2) -> void:
	var tuning: ShipTuning = ship_tuning
	if motion.x != 0.0:
		velocity.x = -velocity.x * tuning.wall_bounce if absf(velocity.x) > tuning.bounce_min_speed else 0.0
	else:
		if motion.y > 0.0:
			is_resting = true
		velocity.y = -velocity.y * tuning.wall_bounce if absf(velocity.y) > tuning.bounce_min_speed else 0.0


func _clamp_speed() -> void:
	var tuning: ShipTuning = ship_tuning
	velocity.x = clampf(velocity.x, -tuning.max_side_speed, tuning.max_side_speed)
	velocity.y = clampf(velocity.y, -tuning.max_rise_speed, tuning.max_fall_speed)


## The wind where the sails are: sideways wind is caught by the course sails (their
## middle), up and down wind by the topsail (its middle). Hot updrafts give zero here
## (WindZone.get_wind_velocity), so heat doesn't move the ship.
func _get_sail_wind() -> Vector2:
	var origin: Vector2 = _get_global_exact_position()
	var course_point: Vector2 = origin + Vector2(0.0, -(COURSE_TOP + COURSE_FOOT) / 2.0)
	var sky_point: Vector2 = origin + Vector2(0.0, -(TOPSAIL_HEAD + TOPSAIL_FOOT) / 2.0)
	var wind: Vector2 = Vector2.ZERO
	for zone_node: Node in get_tree().get_nodes_in_group(WindZone.GROUP):
		var zone: WindZone = zone_node as WindZone
		if zone == null:
			continue
		if zone.contains_point(course_point):
			wind.x += zone.get_wind_velocity().x
		if zone.contains_point(sky_point):
			wind.y += zone.get_wind_velocity().y
	return wind


## The rider left since last frame (jumped off, mostly): they keep the ship's sideways
## speed for a moment, as a tailwind (see the header).
func _hand_speed_to_leaving_rider(rider: Player) -> void:
	if rider == null and last_rider != null and is_instance_valid(last_rider) and not last_rider.is_dead():
		last_rider.start_floor_carry(velocity.x, ship_tuning.rider_carry_time, ship_tuning.rider_carry_fade)
	last_rider = rider


## The player if they stand on the ship (its deck or the crow's nest), else null.
func _get_rider() -> Player:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player != null and not player.is_dead() and player.is_on_floor() and player.get_floor_body() == self:
		return player
	return null


# --- Gusts ---------------------------------------------------------------------------

## The wind-catcher contract (Player.WIND_CATCHER_METHOD): the player standing aboard
## gusted with an arrow held. Their feet stay put; the ship takes the gust and moves
## the way it blew (into its own sails).
## From the crow's nest it pushes harder (nest_push_multiplier).
func absorb_gust_recoil(direction: Vector2, strength: float) -> void:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	var multiplier: float = ship_tuning.nest_push_multiplier if _is_on_nest(player) else 1.0
	_push(direction, strength * multiplier)


## The Pushable contract, with the gust's origin (Pushable.METHOD_WITH_SOURCE).
## Blown from ABOARD: an aimed gust's push is absorb_gust_recoil (the GustRecoil state
## calls it in the same frame), so it's ignored here; a neutral gust brakes the ship.
## From anywhere else it pushes, a bit less than from aboard (outside_push_share).
func receive_gust_from(direction: Vector2, strength: float, source_position: Vector2) -> void:
	var rider: Player = _get_rider()
	if rider == null or not source_position.is_finite():
		receive_gust(direction, strength)
		return
	# The neutral gust pushes everything straight away from its center
	# (AirBlast.push_around); an aimed one, along its aim.
	var is_neutral: bool = direction.is_equal_approx((global_position - source_position).normalized())
	if is_neutral:
		var brake: float = ship_tuning.neutral_brake
		velocity = Vector2(move_toward(velocity.x, 0.0, brake), move_toward(velocity.y, 0.0, brake))


## The Pushable contract (a gust from off the ship, or something without an origin).
func receive_gust(direction: Vector2, strength: float) -> void:
	_push(direction, strength * ship_tuning.outside_push_share)


## Adds a gust to the ship's speed and fills the sails it hit. Sideways goes into the
## course sails, up into the topsail, down spills it; a diagonal does both.
func _push(direction: Vector2, strength: float) -> void:
	var tuning: ShipTuning = ship_tuning
	velocity.x += direction.x * strength * tuning.side_push_share
	if direction.y < 0.0:
		velocity.y += direction.y * strength * tuning.lift_push_share
	else:
		velocity.y += direction.y * strength * tuning.descend_push_share
	_clamp_speed()
	# Kick the sails' springs: the cloth snaps full the way the gust blew, overshoots
	# and settles toward what the new speed fills it to (_animate_sails).
	course_fill_speed += direction.x * SAIL_GUST_KICK
	sky_fill_speed -= direction.y * SAIL_GUST_KICK
	queue_redraw()


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	exact_position = home_position
	position = home_position
	velocity = Vector2.ZERO
	is_resting = false
	last_rider = null
	course_fill = 0.0
	course_fill_speed = 0.0
	sky_fill = 0.0
	sky_fill_speed = 0.0
	queue_redraw()


# --- Helpers -------------------------------------------------------------------------

## The unrounded position in world coordinates (the sweeps start from here).
func _get_global_exact_position() -> Vector2:
	var parent_node: Node2D = get_parent() as Node2D
	return parent_node.to_global(exact_position) if parent_node != null else exact_position


## The hull's outline grown outward by `grow` px on every side (negative: shrunk).
## Each point moves away from the hull's middle, sideways and up or down.
func _make_hull_shape(grow: float) -> ConvexPolygonShape2D:
	var outline: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in HULL_OUTLINE:
		outline.append(point + Vector2(signf(point.x), signf(point.y + DECK_HEIGHT / 2.0)) * grow)
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = outline
	return shape


## A lip (see LIP_HEIGHT) centered at `center`, off to start with (_update_lips).
func _add_lip(center: Vector2) -> CollisionShape2D:
	var lip: CollisionShape2D = CollisionShape2D.new()
	var lip_rect: RectangleShape2D = RectangleShape2D.new()
	lip_rect.size = Vector2(LIP_WIDTH, LIP_HEIGHT)
	lip.shape = lip_rect
	lip.position = center
	lip.disabled = true
	add_child(lip)
	return lip


## Each lip is solid only while the rider stands on its own floor: then it keeps them
## from walking or sliding off. Otherwise it's off, so jumping up past the nest's
## edge, or onto the deck from the side, never snags on it. (A shape can't change in
## the middle of the physics step, hence set_deferred: it takes effect next frame.)
func _update_lips(rider: Player) -> void:
	var on_nest: bool = _is_on_nest(rider)
	for lip: CollisionShape2D in nest_lips:
		if lip.disabled == on_nest:
			lip.set_deferred("disabled", not on_nest)
	var on_deck: bool = rider != null and not on_nest
	for lip: CollisionShape2D in deck_lips:
		if lip.disabled == on_deck:
			lip.set_deferred("disabled", not on_deck)


## Is `player` standing (or just was, coyote time) on the crow's nest, not the deck?
func _is_on_nest(player: Player) -> bool:
	if player == null:
		return false
	var nest_top_y: float = global_position.y - _get_nest_top()
	return player.global_position.y <= nest_top_y + NEST_ONE_WAY_MARGIN \
		and absf(player.global_position.x - global_position.x) <= NEST_WIDTH / 2.0 + 4.0


## The crow's nest's top, px above the keel: halfway up the mast.
func _get_nest_top() -> float:
	return DECK_HEIGHT + MAST_HEIGHT / 2.0


## The sails' springs: each fill is pulled toward what the ship's speed fills it to
## (or the wind's, if that's stronger: a ship held against a wall in a wind zone
## still has full sails), with damping, so a gust's kick overshoots and settles.
## Sideways speed fills the course sails; rising puffs the topsail up, sinking lets
## it sag a little.
func _animate_sails(delta: float) -> void:
	sail_time += delta
	var push_x: float = sail_wind.x if absf(sail_wind.x) > absf(velocity.x) else velocity.x
	var lift: float = -sail_wind.y if absf(sail_wind.y) > absf(velocity.y) else -velocity.y
	var course_target: float = clampf(push_x / SAIL_FULL_SPEED, -1.0, 1.0)
	var sky_target: float = clampf(lift / SAIL_FULL_SPEED, -1.0, 1.0)
	course_fill_speed += ((course_target - course_fill) * SAIL_SPRING_STIFFNESS - course_fill_speed * SAIL_SPRING_DAMPING) * delta
	sky_fill_speed += ((sky_target - sky_fill) * SAIL_SPRING_STIFFNESS - sky_fill_speed * SAIL_SPRING_DAMPING) * delta
	course_fill = clampf(course_fill + course_fill_speed * delta, -SAIL_MAX_DRAWN_FILL, SAIL_MAX_DRAWN_FILL)
	sky_fill = clampf(sky_fill + sky_fill_speed * delta, -SAIL_MAX_DRAWN_FILL, SAIL_MAX_DRAWN_FILL)


# --- Drawing ---------------------------------------------------------------------------

## Back to front: speed lines, rigging ropes, the sails, the mast, the crow's nest,
## the hull. The body moves by fractions of a pixel; the drawing is shifted back onto
## whole pixels (draw_set_transform), and every bulge is rounded, so edges stay crisp.
func _draw() -> void:
	if not Engine.is_editor_hint():
		draw_set_transform(global_position.round() - global_position)
	var mast_top: float = -DECK_HEIGHT - MAST_HEIGHT
	_draw_speed_lines()
	# Stays: ropes from the masthead down to both ends of the deck.
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(0.0, mast_top + 1.0), Vector2(side * 26.5, -DECK_HEIGHT), ROPE_COLOR, 1.0)
	_draw_course_sails()
	_draw_topsail()
	_draw_mast(mast_top)
	_draw_nest()
	_draw_hull()


## How slack the cloth is (0 = full, 1 = hanging), for the flutter and sagging ropes.
func _get_slack(fill: float) -> float:
	return 1.0 - clampf(absf(fill), 0.0, 1.0)


## A fast ship trails a few faint lines of wind behind it (opposite its motion), which
## slide along so they read as rushing past.
func _draw_speed_lines() -> void:
	var speed: float = velocity.length()
	if speed < SPEED_LINE_MIN_SPEED:
		return
	var strength: float = clampf((speed - SPEED_LINE_MIN_SPEED) / SAIL_FULL_SPEED, 0.0, 1.0)
	var behind: Vector2 = -velocity / speed
	var anchors: Array[Vector2] = [Vector2(0.0, -7.0), Vector2(0.0, -30.0), Vector2(0.0, -58.0)]
	for line_index: int in anchors.size():
		# Start just past the ship's edge on its trailing side, sliding back and repeating.
		var drift: float = fmod(sail_time * 80.0 + line_index * 23.0, 16.0)
		var start: Vector2 = anchors[line_index] + behind * (30.0 + drift)
		var line_end: Vector2 = start + behind * SPEED_LINE_MAX_LENGTH * strength
		var color: Color = SPEED_LINE_COLOR
		color.a *= strength * (1.0 - drift / 16.0)
		draw_line(start.round() + Vector2(0.5, 0.5), line_end.round() + Vector2(0.5, 0.5), color, 1.0)


## The two course sails and their yard. Sideways fill bellies the upright edges;
## the topsail's (vertical) fill lifts or sags the foot, so a diagonal gust bellies
## the cloth diagonally and draws a tension crease across it.
func _draw_course_sails() -> void:
	var fill: float = course_fill
	var bulge: float = roundf(fill * COURSE_BULGE)
	var lift: float = roundf(clampf(sky_fill, -1.0, SAIL_MAX_DRAWN_FILL) * COURSE_FOOT_LIFT)
	var slack: float = _get_slack(maxf(absf(fill), absf(sky_fill) * 0.5))
	var flutter: float = FLUTTER_SIZE * slack
	var top_y: float = -COURSE_TOP
	var foot_y: float = -COURSE_FOOT
	# Lifts: ropes from the yard's arms up to the mast, behind everything else.
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(side * (COURSE_YARD_HALF - 1.5), top_y - 1.0), Vector2(side * 1.0, -TOPSAIL_FOOT - 8.0), ROPE_COLOR, 1.0)
	for side: float in [-1.0, 1.0]:
		var left_x: float = minf(side * COURSE_INNER_X, side * COURSE_OUTER_X)
		var right_x: float = maxf(side * COURSE_INNER_X, side * COURSE_OUTER_X)
		var phase: float = side * 1.7  # the two sails don't flutter in step
		# Both upright edges bow the same way: the whole cloth bellies downwind. The
		# foot lifts (or sags) with the vertical fill and ripples when slack.
		var right_edge: PackedVector2Array = _sail_edge(Vector2(right_x, top_y), Vector2(right_x, foot_y), Vector2(bulge, 0.0), flutter, phase)
		var foot: PackedVector2Array = _sail_edge(Vector2(right_x, foot_y), Vector2(left_x, foot_y), Vector2(0.0, -lift), flutter, phase + 1.0)
		var left_edge: PackedVector2Array = _sail_edge(Vector2(left_x, foot_y), Vector2(left_x, top_y), Vector2(bulge, 0.0), flutter * 0.5, phase + 2.0)
		var outline: PackedVector2Array = right_edge + foot.slice(1, foot.size() - 1) + left_edge
		draw_colored_polygon(outline, SAIL_COLOR)
		# Volume: shade along the hollow (windward) edge, wider the fuller the sail, and
		# a bright line inside the bellied (leeward) edge.
		if absf(bulge) >= 1.0:
			var hollow_x: float = left_x if bulge > 0.0 else right_x
			var shade_width: float = roundf(1.0 + absf(bulge) * 0.4) * signf(bulge)
			var hollow: PackedVector2Array = _sail_edge(Vector2(hollow_x, top_y), Vector2(hollow_x, foot_y), Vector2(bulge, 0.0), 0.0, 0.0)
			var hollow_inner: PackedVector2Array = _sail_edge(Vector2(hollow_x + shade_width, foot_y), Vector2(hollow_x + shade_width, top_y), Vector2(bulge, 0.0), 0.0, 0.0)
			draw_colored_polygon(hollow + hollow_inner, SAIL_SHADE_COLOR)
		if absf(bulge) >= 2.0:
			var belly_x: float = (right_x - 1.0) if bulge > 0.0 else (left_x + 1.0)
			draw_polyline(_sail_edge(Vector2(belly_x, top_y + 1.0), Vector2(belly_x, foot_y - 1.0), Vector2(bulge, 0.0), 0.0, 0.0), SAIL_LIGHT_COLOR, 1.0)
		# Two seams that follow the belly, ending on the lifted foot.
		for seam_share: float in [0.33, 0.67]:
			var seam_x: float = roundf(lerpf(left_x, right_x, seam_share))
			var seam_foot_y: float = foot_y - roundf(lift * 4.0 * seam_share * (1.0 - seam_share))
			draw_polyline(_sail_edge(Vector2(seam_x, top_y), Vector2(seam_x, seam_foot_y), Vector2(bulge, 0.0), 0.0, 0.0), SAIL_SHADE_COLOR, 1.0)
		_draw_crease(Vector2(left_x, top_y), Vector2(right_x, foot_y), Vector2(bulge, -lift))
		# A row of reef points under the yard.
		var reef_shift: float = roundf(bulge * 0.4)
		var reef_x: float = left_x + 3.0
		while reef_x <= right_x - 3.0:
			draw_rect(Rect2(reef_x + reef_shift, top_y + 3.0, 1.0, 1.0), SAIL_EDGE_COLOR)
			reef_x += 4.0
		outline.append(outline[0])
		draw_polyline(outline, SAIL_EDGE_COLOR, 1.0)
		# Sheets: ropes from the sail's outer foot corner down to the deck, sagging when
		# the sail is slack and pulled straight when it's full.
		var corner: Vector2 = Vector2(side * COURSE_OUTER_X, foot_y)
		var deck_point: Vector2 = Vector2(side * 22.5, -DECK_HEIGHT)
		var sag: Vector2 = Vector2(0.0, roundf(slack * 2.0))
		draw_polyline(PackedVector2Array([corner, (corner + deck_point) / 2.0 + sag, deck_point]), ROPE_COLOR, 1.0)
	_draw_yard(top_y, COURSE_YARD_HALF)


## A yard: a spar 2 px thick whose bottom is at `bottom_y`, reaching `half_length`
## each side of the mast. Its arms taper to 1 px for the last 3 px, it has a light
## top edge, and an iron band where it crosses the mast.
func _draw_yard(bottom_y: float, half_length: float) -> void:
	var arm_start: float = half_length - 3.0
	draw_rect(Rect2(-arm_start, bottom_y - 2.0, arm_start * 2.0, 2.0), MAST_COLOR)
	draw_line(Vector2(-arm_start, bottom_y - 1.5), Vector2(arm_start, bottom_y - 1.5), MAST_LIGHT_COLOR, 1.0)
	for side: float in [-1.0, 1.0]:
		var arm_left: float = arm_start if side > 0.0 else -half_length
		draw_rect(Rect2(arm_left, bottom_y - 1.0, 3.0, 1.0), MAST_COLOR)
	draw_rect(Rect2(-1.5, bottom_y - 2.0, 3.0, 2.0), HULL_DARK_COLOR)


## A tension crease across a sail: a diagonal fold from one corner toward the other
## when the cloth is pulled diagonally (both bulges at least 1 px), drawn from the
## windward foot corner to the leeward head corner. `corner_a` and `corner_b` are the
## sail's top-left and bottom-right corners; `bulge` is (sideways bulge, vertical bulge
## with up negative).
func _draw_crease(corner_a: Vector2, corner_b: Vector2, bulge: Vector2) -> void:
	if absf(bulge.x) < 1.0 or absf(bulge.y) < 1.0:
		return
	# Pulled right: from the left; pulled up: from the bottom. The crease runs WITH
	# the pull, from the pinned corner it pulls away from.
	var from_x: float = corner_a.x + 2.0 if bulge.x > 0.0 else corner_b.x - 2.0
	var to_x: float = corner_b.x - 2.0 if bulge.x > 0.0 else corner_a.x + 2.0
	var from_y: float = corner_b.y - 2.0 if bulge.y < 0.0 else corner_a.y + 2.0
	var to_y: float = corner_a.y + 3.0 if bulge.y < 0.0 else corner_b.y - 3.0
	var crease: PackedVector2Array = _sail_edge(Vector2(from_x, from_y), Vector2(to_x, to_y), bulge * 0.4, 0.0, 0.0)
	draw_polyline(crease, SAIL_SHADE_COLOR, 1.0)


## The topsail: one sail across the mast (the mast is drawn over it). Vertical fill
## domes its head up (or sags it); sideways fill leans the dome and swells the
## leeward side while the windward side pulls in, so a diagonal gust shows on it as
## a belly pushed up and over.
func _draw_topsail() -> void:
	var fill: float = sky_fill
	var lean: float = roundf(clampf(course_fill, -SAIL_MAX_DRAWN_FILL, SAIL_MAX_DRAWN_FILL) * TOPSAIL_LEAN)
	var dome: float = roundf(fill * TOPSAIL_BULGE) if fill > 0.0 else roundf(fill * TOPSAIL_SAG)
	var puff: float = maxf(fill, 0.0) * TOPSAIL_BULGE * 0.5
	var swell_right: float = maxf(roundf(puff + lean), -2.0)
	var swell_left: float = maxf(roundf(puff - lean), -2.0)
	var slack: float = _get_slack(maxf(absf(fill), absf(course_fill) * 0.5))
	var flutter: float = FLUTTER_SIZE * slack
	var foot_left: Vector2 = Vector2(-TOPSAIL_FOOT_HALF, -TOPSAIL_FOOT)
	var foot_right: Vector2 = Vector2(TOPSAIL_FOOT_HALF, -TOPSAIL_FOOT)
	var head_right: Vector2 = Vector2(TOPSAIL_HEAD_HALF, -TOPSAIL_HEAD)
	var head_left: Vector2 = Vector2(-TOPSAIL_HEAD_HALF, -TOPSAIL_HEAD)
	var foot_lift: float = roundf(maxf(fill, 0.0) * 1.5)
	var foot: PackedVector2Array = _sail_edge(foot_left, foot_right, Vector2(0.0, -foot_lift), flutter * 0.6, 0.4)
	var right_edge: PackedVector2Array = _sail_edge(foot_right, head_right, Vector2(swell_right, 0.0), flutter, 1.3)
	var head: PackedVector2Array = _sail_edge(head_right, head_left, Vector2(lean, -dome), flutter, 2.1)
	var left_edge: PackedVector2Array = _sail_edge(head_left, foot_left, Vector2(-swell_left, 0.0), flutter, 2.9)
	var outline: PackedVector2Array = foot.slice(0, foot.size() - 1) + right_edge.slice(0, right_edge.size() - 1) \
		+ head.slice(0, head.size() - 1) + left_edge.slice(0, left_edge.size() - 1)
	draw_colored_polygon(outline, SAIL_COLOR)
	# Volume: the underside in shade along the foot, the hollow (windward) side in
	# shade when it leans, and a bright line under the dome.
	var under_foot: PackedVector2Array = _sail_edge(foot_right + Vector2(-1.0, -2.0), foot_left + Vector2(1.0, -2.0), Vector2(0.0, -foot_lift), 0.0, 0.0)
	draw_colored_polygon(foot + under_foot, SAIL_SHADE_COLOR)
	if absf(lean) >= 1.0:
		var hollow_foot: Vector2 = foot_left if lean > 0.0 else foot_right
		var hollow_head: Vector2 = head_left if lean > 0.0 else head_right
		var hollow_swell: float = -swell_left if lean > 0.0 else swell_right
		var inward: Vector2 = Vector2(signf(lean) * roundf(1.0 + absf(lean) * 0.5), 0.0)
		var hollow: PackedVector2Array = _sail_edge(hollow_foot, hollow_head, Vector2(hollow_swell, 0.0), 0.0, 0.0)
		var hollow_inner: PackedVector2Array = _sail_edge(hollow_head + inward, hollow_foot + inward, Vector2(hollow_swell, 0.0), 0.0, 0.0)
		draw_colored_polygon(hollow + hollow_inner, SAIL_SHADE_COLOR)
	if dome >= 2.0:
		var under_dome: PackedVector2Array = _sail_edge(head_right + Vector2(-1.0, 1.0), head_left + Vector2(1.0, 1.0), Vector2(lean, -dome), 0.0, 0.0)
		draw_polyline(under_dome, SAIL_LIGHT_COLOR, 1.0)
	# Seams: two running up the sail (real sails are sewn from upright cloths), leaning
	# with it, and a row of reef points under the head, curved like it.
	for seam_x: float in [-12.0, -5.0, 5.0, 12.0]:
		var seam_foot: Vector2 = Vector2(seam_x, -TOPSAIL_FOOT - roundf(foot_lift * 0.8))
		var seam_head: Vector2 = Vector2(roundf(seam_x * TOPSAIL_HEAD_HALF / TOPSAIL_FOOT_HALF) + roundf(lean * 0.5), -TOPSAIL_HEAD - roundf(dome * 0.8))
		draw_polyline(_sail_edge(seam_foot, seam_head, Vector2(roundf(lean * 0.5), 0.0), 0.0, 0.0), SAIL_SHADE_COLOR, 1.0)
	var reef_row: PackedVector2Array = _sail_edge(head_left + Vector2(2.0, 3.0), head_right + Vector2(-2.0, 3.0), Vector2(lean, -dome), 0.0, 0.0)
	for reef_index: int in range(0, reef_row.size()):
		draw_rect(Rect2(reef_row[reef_index], Vector2.ONE), SAIL_EDGE_COLOR)
	_draw_crease(head_left, foot_right, Vector2(lean, -dome))
	outline.append(outline[0])
	draw_polyline(outline, SAIL_EDGE_COLOR, 1.0)
	# Sheets from the foot's corners down to the crow's nest's ends.
	var nest_top: float = -_get_nest_top()
	for side: float in [-1.0, 1.0]:
		var corner: Vector2 = Vector2(side * TOPSAIL_FOOT_HALF, -TOPSAIL_FOOT)
		draw_line(corner, Vector2(side * (NEST_WIDTH / 2.0 - 1.5), nest_top - LIP_HEIGHT), ROPE_COLOR, 1.0)
	# Lifts: ropes from the topsail yard's arms up to the masthead.
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(side * TOPSAIL_HEAD_HALF, -TOPSAIL_HEAD - 2.0), Vector2(side * 1.0, -DECK_HEIGHT - MAST_HEIGHT + 2.0), ROPE_COLOR, 1.0)
	_draw_yard(-TOPSAIL_HEAD, TOPSAIL_HEAD_HALF + 3.0)


func _draw_mast(mast_top: float) -> void:
	draw_rect(Rect2(-1.0, mast_top, 2.0, MAST_HEIGHT), MAST_COLOR)
	draw_line(Vector2(-0.5, mast_top), Vector2(-0.5, -DECK_HEIGHT), MAST_LIGHT_COLOR, 1.0)
	draw_rect(Rect2(-1.5, mast_top - 1.0, 3.0, 1.0), MAST_LIGHT_COLOR)
	# The pennant streams with the APPARENT wind (the wind minus the ship's own motion:
	# sailing right in still air, it flies left), longer and flapping faster the
	# stronger it is; in still air it droops.
	var apparent_wind: Vector2 = sail_wind - velocity
	var stream: float = clampf(absf(apparent_wind.x) / PENNANT_FULL_WIND, 0.0, 1.0)
	var tip_side: float = signf(apparent_wind.x) if apparent_wind.x != 0.0 else 1.0
	var length: float = PENNANT_LENGTH * (0.45 + 0.65 * stream)
	var flap: float = sin(sail_time * (6.0 + 10.0 * stream)) * (0.5 + stream)
	var droop: float = (1.0 - stream) * 4.0
	var middle: Vector2 = Vector2(roundf(tip_side * length * 0.5), roundf(mast_top + 1.0 + droop * 0.5 - flap * 0.5))
	var tip: Vector2 = Vector2(roundf(tip_side * length), roundf(mast_top + 1.5 + droop + flap))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, mast_top), middle, tip, middle + Vector2(0.0, 2.0), Vector2(0.0, mast_top + 3.0),
	]), PENNANT_COLOR)


func _draw_nest() -> void:
	var top: float = -_get_nest_top()
	var half: float = NEST_WIDTH / 2.0
	draw_rect(Rect2(-half, top, NEST_WIDTH, NEST_THICKNESS), HULL_COLOR)
	draw_line(Vector2(-half, top + 0.5), Vector2(half, top + 0.5), HULL_RIM_COLOR, 1.0)
	draw_line(Vector2(-half, top + NEST_THICKNESS - 0.5), Vector2(half, top + NEST_THICKNESS - 0.5), HULL_DARK_COLOR, 1.0)
	for side: float in [-1.0, 1.0]:
		# Struts from the mast up to the platform's ends.
		draw_line(Vector2(side * 1.5, top + 9.0), Vector2(side * (half - 1.5), top + NEST_THICKNESS), MAST_COLOR, 1.0)
		# The lip (solid, see _add_lip) and a short rail post on it.
		var lip_x: float = half - LIP_WIDTH if side > 0.0 else -half
		_draw_lip(Vector2(lip_x, top - LIP_HEIGHT))
		var post_x: float = side * (half - 0.5)
		draw_line(Vector2(post_x, top - LIP_HEIGHT), Vector2(post_x, top - LIP_HEIGHT - 3.0), HULL_RIM_COLOR, 1.0)


## One lip block, its top-left corner at `corner`: wood with a light top.
func _draw_lip(corner: Vector2) -> void:
	draw_rect(Rect2(corner, Vector2(LIP_WIDTH, LIP_HEIGHT)), HULL_COLOR)
	draw_rect(Rect2(corner, Vector2(LIP_WIDTH, 1.0)), HULL_RIM_COLOR)


func _draw_hull() -> void:
	draw_colored_polygon(HULL_OUTLINE, HULL_COLOR)
	# The lower hull in shade: the same outline cut off 6 px above the keel.
	var shade_top: float = -6.0
	var shade_half: float = _hull_half_width(shade_top)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-shade_half, shade_top), Vector2(shade_half, shade_top),
		Vector2(24, -5), Vector2(20, 0), Vector2(-20, 0), Vector2(-24, -5),
	]), HULL_DARK_COLOR)
	# Planks: a line every 4 px, as wide as the hull is at that height.
	for plank_y: float in [-12.5, -8.5]:
		var half: float = _hull_half_width(plank_y) - 0.5
		draw_line(Vector2(-half, plank_y), Vector2(half, plank_y), PLANK_LINE_COLOR, 1.0)
	# The gunwale: a light rim along the deck; the lips at both ends with a rail post
	# and a short top bar each.
	var deck_half: float = HULL_OUTLINE[1].x
	draw_line(Vector2(-deck_half, -DECK_HEIGHT + 0.5), Vector2(deck_half, -DECK_HEIGHT + 0.5), HULL_RIM_COLOR, 1.0)
	for side: float in [-1.0, 1.0]:
		var lip_x: float = deck_half - LIP_WIDTH if side > 0.0 else -deck_half
		_draw_lip(Vector2(lip_x, -DECK_HEIGHT - LIP_HEIGHT))
		var post_x: float = side * (deck_half - 0.5)
		var post_top: float = -DECK_HEIGHT - LIP_HEIGHT - 4.0
		draw_line(Vector2(post_x, -DECK_HEIGHT - LIP_HEIGHT), Vector2(post_x, post_top), HULL_RIM_COLOR, 1.0)
		draw_line(Vector2(post_x, post_top + 0.5), Vector2(post_x - side * 4.5, post_top + 0.5), HULL_RIM_COLOR, 1.0)
	# Portholes: brass rims round dark glass.
	for window_x: float in [-12.0, 0.0, 12.0]:
		draw_rect(Rect2(window_x - 2.0, -12.0, 4.0, 4.0), WINDOW_RIM_COLOR)
		draw_rect(Rect2(window_x - 1.0, -11.0, 2.0, 2.0), WINDOW_COLOR)
	# The keel: a dark strip along the bottom.
	draw_rect(Rect2(-20.0, -2.0, 40.0, 2.0), KEEL_COLOR)


## Half the hull's width at height `y` (negative = above the keel), read off the
## outline's right side by straight lines between its points.
func _hull_half_width(y: float) -> float:
	for point_index: int in range(1, 4):
		var upper: Vector2 = HULL_OUTLINE[point_index]
		var lower: Vector2 = HULL_OUTLINE[point_index + 1]
		if y >= upper.y and y <= lower.y:
			return lerpf(upper.x, lower.x, (y - upper.y) / (lower.y - upper.y))
	return HULL_OUTLINE[1].x


## Points of a sail's edge from `from` to `to`: the middle pushed by `bulge` (a
## parabola: none at the ends, all of it halfway), plus a FLUTTER, a wave running
## along the edge (sideways to it) of up to `flutter` px, also zero at the pinned
## ends. Each point is rounded to whole pixels.
func _sail_edge(from: Vector2, to: Vector2, bulge: Vector2, flutter: float, phase: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var across: Vector2 = (to - from).normalized().orthogonal()
	for step: int in SAIL_EDGE_STEPS:
		var along: float = float(step) / float(SAIL_EDGE_STEPS - 1)
		var push: float = 4.0 * along * (1.0 - along)
		var wave: float = sin(sail_time * FLUTTER_RATE + along * FLUTTER_WAVES + phase) * flutter * push
		points.append((from.lerp(to, along) + bulge * push + across * wave).round())
	return points

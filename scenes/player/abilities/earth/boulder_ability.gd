class_name BoulderAbility
extends Node
## Boulder, move 2 of Earth (Earth_bending.md §6, §11, Stages E4 + E4a). Lives under
## the player:  Player > BoulderAbility
## Since E4a the "boulder" is an 8x8 ROCK, torn out of the ground RIGHT NEXT TO the
## player: no bend shadow, no slow motion. (So unlike the column it's not an
## EarthMoveAbility and isn't registered with EarthBendAbility.)
##
## Flow: press S while touching fresh earth (Idle, Run or WallSlide call
## player.try_tear_rock()) -> try_tear() here TEARS one earth tile out (it becomes
## open air, EarthLayer.tear_out) and a rock (Boulder) rumbles out of the hole and
## hops up, away from the player (from a wall: away from the wall) -> the player is
## rooted in BoulderHold, in slow motion -> press S again -> throw() here, away from
## the player (get_throw_direction).
##
## Which tile (Earth_bending.md §11): the one just AHEAD of the feet, the way the bend
## shadow would set off (EarthBendAbility.get_start_tangent: the facing direction on a
## floor; down a wall, or up with Up held), then the one after it. Never a tile the
## player stands on or leans against, and the space in front of it must be free of
## solids and of the player. Next to a hole, "ahead" wraps down into it, so standing
## at a hole's edge digs it deeper.
##
## Throw timing: quality 1 within ±boulder_perfect_window of the moment the rock comes
## back down level with the player (Boulder.get_time_from_perfect), then falling
## linearly to 0 over boulder_throw_falloff_time. Speed and "no gravity" time scale
## with it.
##
## BIG ROCK (Stage E4c2): a tap of S tears the small rock as above. If S is still held
## when the rock is out of its hole (Boulder.tore_free, the end of its tear), the rock
## GROWS: _try_grow() tears out the 2x2 block made of its own tile, the next tile along
## the surface (away from the player) and the two tiles behind those, and
## Boulder.grow() starts the tear over from the 2x2 hole. Can't tear all four = it
## stays small. A big rock throws big_rock_throw_speed_scale slower.
## The charge is tracked here (is_charging): BoulderHold calls stop_charging() as soon
## as S is up.
##
## LOOSE ROCKS (Stage E4c3): a rock that comes down without being thrown lies there
## (Boulder's LOOSE phase). Pressing S next to one lifts it again (_lift): it hops like
## a fresh rock, perfect window and all, and no earth is used.
##
## SHATTERING CREATIONS (after the E7 play-test): S while TOUCHING a creation (a
## stuck or loose rock, a hardened snake, a risen pillar: standing on it, or within
## loose_rock_lift_reach of your sides, _find_touched_creation) breaks it into
## pebbles instead of tearing earth. Touching wins over tearing. A loose rock BESIDE
## you is the one case that waits: released within shatter_tap_time it shatters,
## still held it's lifted (pending_lift_rock, settled in take_ready_lift(), which the
## player's Idle/Run/WallSlide call every frame through player.try_tear_rock()).
##
## Only the rock being HELD is tracked here: a thrown one flies on by itself, so you
## can tear the next one while the last is still in the air.
##
## HOVER AIM (the default since E7, EarthTuning.boulder_hover_aim): the rock hovers beside the
## player instead of hopping (Boulder.set_hover_mode). While it hovers BoulderHold
## feeds the arrows to update_hover_aim(): the aim sticks like the gust's (letting go
## of the arrows keeps it), starts at straight ahead, and get_chosen_throw_direction()
## throws that way. The timing is the same perfect window, at the contour's close.
##
## The rock itself (tear, hop, flight, sticking, shattering) is
## scenes/objects/earth/boulder.gd.

## The player this belongs to (the parent node), set in _ready().
var player: Player
## The rock out of the ground right now, waiting to be thrown, or null.
var held_boulder: Boulder = null
## The wall the player was sliding on when it tore the held rock out: -1 left, +1
## right, 0 if standing on a floor. Throws never go into this wall.
var held_wall_direction: float = 0.0
## The face the held rock was torn from, and the way "ahead" ran along it (away from
## the player): where a big rock's 2x2 block extends to.
var held_source_face: EarthFace = null
var held_source_tangent: Vector2i = Vector2i.ZERO
## True from the tear while S stays held: the rock grows when it's out of its hole.
var is_charging: bool = false
## HOVER AIM: the way the held rock will be thrown (a unit vector).
var hover_aim: Vector2 = Vector2.RIGHT
## A loose rock beside the player whose S press hasn't been decided yet: a tap
## shatters it, a hold lifts it. Null when nothing is pending.
var pending_lift_rock: Boulder = null
## Real clock (ms) when that press started.
var pending_press_msec: int = 0

## Physics layer bit value of "world" (layer 1): creations are solid on it.
const WORLD_MASK: int = 1
## Max bodies one touch check reports.
const MAX_TOUCH_RESULTS: int = 8


func _ready() -> void:
	player = get_parent() as Player


## The InputMap action for this move.
func get_action() -> StringName:
	return &"earth_boulder"


## True while a rock we tore out can still be thrown.
func is_holding() -> bool:
	return is_instance_valid(held_boulder) and held_boulder.is_throwable()


## Tears a rock out of the tile ahead of the feet, if there's one that fits. Returns
## true if it did (the caller then switches to BoulderHold). Called by
## player.try_tear_rock() on the frame S is pressed.
## A LOOSE rock next to the player comes first (Stage E4c3): it's lifted instead, and
## no earth is used. That works anywhere, not only on earth.
func try_tear() -> bool:
	var loose_rock: Boulder = _find_loose_rock_in_reach()
	if loose_rock != null:
		# Tap or hold? Decided in take_ready_lift() over the next few frames.
		pending_lift_rock = loose_rock
		pending_press_msec = Time.get_ticks_msec()
		return false
	var creation: Node2D = _find_touched_creation()
	if creation != null:
		shatter_creation(creation)
		return false
	var start_face: EarthFace = player.earth_bend.find_start_surface()
	if start_face == null:
		return false
	var source: Array = _pick_source_face(start_face)
	if source.is_empty():
		FX.play_sfx(&"earth_fizzle")  # no room for a rock here: no earth used
		return false
	var source_face: EarthFace = source[0]
	held_source_face = source_face
	held_source_tangent = source[1]
	is_charging = true  # S is down right now; BoulderHold stops it when S comes up
	var tuning: EarthTuning = player.earth_tuning
	var hole_center: Vector2 = source_face.layer.get_cell_global_center(source_face.cell)
	source_face.layer.tear_out(source_face.cell)
	# On a wall (the face we stand on points sideways), remember which side it's on.
	held_wall_direction = float(-start_face.normal.x)
	# From a wall the rock hops clearly away from it; from a floor it drifts a little.
	var hop_away_speed: float = tuning.boulder_wall_hop_away_speed if held_wall_direction != 0.0 \
		else tuning.boulder_hop_away_speed
	var boulder: Boulder = Boulder.new()
	boulder.setup(hole_center, Vector2(source_face.normal),
		_get_away_direction_x(hole_center, source_face) * hop_away_speed, player.get_center().y, tuning)
	# A child of the ROOM, like columns: it stays in the world and the reset removes it.
	source_face.layer.get_parent().add_child(boulder)
	boulder.tore_free.connect(_on_held_boulder_tore_free.bind(boulder))
	# Hover aim: beside the player on the side they face (away from the wall on one).
	var hover_side: float = -held_wall_direction if held_wall_direction != 0.0 else player.facing_direction
	_set_hover_mode(boulder, hover_side)
	held_boulder = boulder
	# Pebble fraction 0: the pebbles go by the ground used (one tile), just below.
	FX.spawn_gravel(source_face.get_global_center(), tuning.eruption_gravel_count, Vector2(source_face.normal), 0.0)
	PebbleField.leave_pebbles_for_tiles(get_tree(), source_face.get_global_center(), 1,
		Vector2(source_face.normal))
	FX.shake(tuning.eruption_shake_strength, tuning.eruption_shake_time)
	FX.play_sfx(&"earth_boulder")
	return true


## A loose rock's S press, decided (see SHATTERING CREATIONS in the header): S already
## up = a tap, shatter it; held for shatter_tap_time = lift it and return true (the
## caller switches to BoulderHold, like after try_tear()). False while undecided.
func take_ready_lift() -> bool:
	if pending_lift_rock == null:
		return false
	var rock: Boulder = pending_lift_rock
	if not is_instance_valid(rock) or not rock.is_loose():
		pending_lift_rock = null
		return false
	var held_seconds: float = (Time.get_ticks_msec() - pending_press_msec) / 1000.0
	if not Input.is_action_pressed(get_action()):
		pending_lift_rock = null
		shatter_creation(rock)
		return false
	if held_seconds < player.earth_tuning.shatter_tap_time:
		return false
	pending_lift_rock = null
	# Still next to it? (The player may have walked away meanwhile.)
	if _find_loose_rock_in_reach() != rock:
		return false
	_lift(rock)
	return true


## Breaks `creation` (a Boulder, EarthSnake or EarthColumn) into gravel and pebbles.
func shatter_creation(creation: Node2D) -> void:
	var snake: EarthSnake = creation as EarthSnake
	if snake != null:
		snake.shatter(snake.get_nearest_cell(player.get_center()))
		return
	var rock: Boulder = creation as Boulder
	if rock != null:
		# More pebbles than a thrown rock's shatter: the gravel per tile of rock.
		var tiles: int = roundi(pow(rock.size / player.earth_tuning.boulder_size, 2.0))
		FX.spawn_gravel(rock.global_position, player.earth_tuning.shatter_gravel_per_tile * tiles, Vector2.UP)
		rock.shatter()
		return
	var column: EarthColumn = creation as EarthColumn
	if column != null:
		column.shatter()


## The creation the player touches (see the header), nearest first, or null: a rock
## stuck or lying loose, a hardened snake, a risen pillar. "Touching" = in a box
## around the body, loose_rock_lift_reach wider on each side and 1 px under the feet.
## A shape query on "world" finds them (all creations are solid there).
func _find_touched_creation() -> Node2D:
	var reach: float = player.earth_tuning.loose_rock_lift_reach
	var touch_rect: Rect2 = player.get_hitbox_rect().grow_individual(reach, 0.0, reach, 1.0)
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	check_shape.size = touch_rect.size
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, touch_rect.get_center())
	query.collision_mask = WORLD_MASK
	query.collide_with_areas = false
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for result: Dictionary in player.get_world_2d().direct_space_state.intersect_shape(query, MAX_TOUCH_RESULTS):
		var body: Node2D = result.collider as Node2D
		var distance: float = _get_creation_distance(body)
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance
	return nearest


## How far `body` is from the player's middle if it's a creation that can shatter,
## or INF if it isn't one (a tile layer, a crate, a door, a rising pillar...).
func _get_creation_distance(body: Node2D) -> float:
	var center: Vector2 = player.get_center()
	var rock: Boulder = body as Boulder
	if rock != null and (rock.phase == Boulder.Phase.STUCK or rock.phase == Boulder.Phase.LOOSE):
		return rock.global_position.distance_to(center)
	var snake: EarthSnake = body as EarthSnake
	if snake != null and snake.phase == EarthSnake.Phase.HARDENED and not snake.segment_cells.is_empty():
		return snake.earth_layer.get_cell_global_center(snake.get_nearest_cell(center)).distance_to(center)
	var column: EarthColumn = body as EarthColumn
	if column != null and column.is_risen():
		return column.hitbox.global_position.distance_to(center)
	return INF


## Which way a throw goes for the held arrows `aim` (a unit vector, or ZERO): away
## from the player. No arrows: horizontally toward the rock's side of the player.
## On a wall, an arrow pointing INTO the wall is mirrored away from it (you're usually
## still holding toward the wall from the slide, and a throw can't go through it).
func get_throw_direction(aim: Vector2) -> Vector2:
	if aim == Vector2.ZERO:
		var away_x: float = player.facing_direction
		if is_instance_valid(held_boulder):
			var offset_x: float = held_boulder.global_position.x - player.get_center().x
			if absf(offset_x) >= 1.0:
				away_x = signf(offset_x)
		if held_wall_direction != 0.0:
			away_x = -held_wall_direction
		return Vector2(away_x, 0.0)
	if held_wall_direction != 0.0 and signf(aim.x) == held_wall_direction:
		aim.x = -aim.x
	return aim


## True while the held rock hovers and the arrows aim it (hover aim mode).
func is_hover_aiming() -> bool:
	return is_holding() and held_boulder.is_hover_mode


## HOVER AIM: the arrows `held` (unit vector, or ZERO) aim the hovering rock. ZERO
## keeps the last aim, like the gust. Never into the wall you're on (get_throw_direction).
func update_hover_aim(held: Vector2) -> void:
	if held != Vector2.ZERO:
		hover_aim = get_throw_direction(held)
	if is_instance_valid(held_boulder):
		held_boulder.aim_direction = hover_aim


## The direction S throws the held rock now: the hover aim in hover mode, else the
## arrows held right now (get_throw_direction).
func get_chosen_throw_direction() -> Vector2:
	if is_hover_aiming():
		return hover_aim
	return get_throw_direction(player.get_aim_input())


## Turns hover aim on or off for `rock` (from EarthTuning, read at every tear/lift, so
## the Inspector toggle works mid-game), and starts the aim straight out on `side`.
func _set_hover_mode(rock: Boulder, side: float) -> void:
	var enabled: bool = player.earth_tuning.boulder_hover_aim
	rock.set_hover_mode(enabled, player.get_center(), side, player.get_hitbox_rect().size / 2.0)
	hover_aim = Vector2(side, 0.0)


## Throws the held rock toward `direction` (a unit vector, 8 directions; see
## get_throw_direction). Called by BoulderHold when S is pressed again.
func throw(direction: Vector2) -> void:
	if not is_holding():
		return
	var tuning: EarthTuning = player.earth_tuning
	var quality: float = get_throw_quality(held_boulder.get_time_from_perfect())
	var speed: float = lerpf(tuning.boulder_min_throw_speed, tuning.boulder_perfect_throw_speed, quality)
	if held_boulder.is_big():
		speed *= tuning.big_rock_throw_speed_scale
	var is_perfect: bool = held_boulder.is_in_perfect_window()
	held_boulder.throw(direction, speed, tuning.boulder_perfect_float_time * quality, is_perfect)
	FX.play_sfx(&"boulder_perfect_throw" if is_perfect else &"boulder_throw")
	held_boulder = null


## The player lets go without throwing (Jump): the rock lies loose once it lands.
func let_go() -> void:
	if is_instance_valid(held_boulder):
		held_boulder.drop()
	held_boulder = null


## Throw quality 0..1 for a throw `time_from_perfect` seconds away from the perfect
## moment (the rock coming down level with the player): 1 inside the perfect window,
## then down to 0 over boulder_throw_falloff_time.
func get_throw_quality(time_from_perfect: float) -> float:
	var tuning: EarthTuning = player.earth_tuning
	var time_off_window: float = time_from_perfect - tuning.boulder_perfect_window
	if time_off_window <= 0.0:
		return 1.0
	return clampf(1.0 - time_off_window / maxf(tuning.boulder_throw_falloff_time, 0.001), 0.0, 1.0)


# --- Choosing the tile ------------------------------------------------------------

## The face the rock tears out of: the first tile ahead of `start_face` that fits,
## then the one after it. Returns [face, tangent] (tangent = the way "ahead" runs
## along that face, a Vector2i), or [] if neither fits.
func _pick_source_face(start_face: EarthFace) -> Array:
	var bend: EarthBendAbility = player.earth_bend
	var first_ahead: Array = bend.find_next_face(start_face, bend.get_start_tangent(start_face))
	if first_ahead.is_empty():
		return []  # gray rock right ahead
	if _does_face_fit(first_ahead[0]):
		return first_ahead
	var second_ahead: Array = bend.find_next_face(first_ahead[0], first_ahead[1])
	if not second_ahead.is_empty() and _does_face_fit(second_ahead[0]):
		return second_ahead
	return []


# --- Loose rocks (Stage E4c3) ----------------------------------------------------

## The nearest loose rock beside the player (within loose_rock_lift_reach of their
## sides, level with their body), or null. Not one they stand on: lifting that would
## pull the ground from under their feet.
func _find_loose_rock_in_reach() -> Boulder:
	var reach: float = player.earth_tuning.loose_rock_lift_reach
	# grow_individual(left, top, right, bottom): wider on both sides, and 1 px short
	# at the bottom so a rock under the feet doesn't count.
	var reach_rect: Rect2 = player.get_hitbox_rect().grow_individual(reach, 0.0, reach, -1.0)
	var nearest: Boulder = null
	var nearest_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Boulder.GROUP):
		var rock: Boulder = node as Boulder
		if rock == null or not rock.is_loose():
			continue
		var rock_rect: Rect2 = Rect2(rock.global_position - Vector2.ONE * rock.size / 2.0, Vector2.ONE * rock.size)
		if not reach_rect.intersects(rock_rect):
			continue
		var distance: float = rock.global_position.distance_to(player.get_center())
		if distance < nearest_distance:
			nearest = rock
			nearest_distance = distance
	return nearest


## Lifts `rock` off the ground: it hops away from the player like a fresh rock, and
## we hold it (BoulderHold) until the throw.
func _lift(rock: Boulder) -> void:
	var tuning: EarthTuning = player.earth_tuning
	held_wall_direction = 0.0
	held_source_face = null
	is_charging = false  # a lifted rock never grows
	var offset_x: float = rock.global_position.x - player.get_center().x
	var away_x: float = signf(offset_x) if absf(offset_x) >= 1.0 else player.facing_direction
	_set_hover_mode(rock, away_x)
	rock.lift(away_x * tuning.boulder_hop_away_speed, player.get_center().y)
	held_boulder = rock
	FX.spawn_gravel(rock.global_position + Vector2.DOWN * rock.size / 2.0, 3, Vector2.UP)
	FX.play_sfx(&"boulder_lift")


# --- Big rock (Stage E4c2) -------------------------------------------------------

## S came up: a rock out of its hole from now on stays small. Called by BoulderHold.
func stop_charging() -> void:
	is_charging = false


## The rock we tore is out of its hole (Boulder.tore_free). Still holding S: grow it.
## The rock is bound in at connect time, so a rock we already let go of is ignored.
func _on_held_boulder_tore_free(boulder: Boulder) -> void:
	if boulder != held_boulder or not is_charging:
		return
	is_charging = false  # one growth per rock (its second tear emits tore_free again)
	var block: Array[Vector2i] = _find_big_block()
	if block.is_empty():
		FX.play_sfx(&"earth_fizzle")  # no room for a big rock: it stays small
		return
	var tuning: EarthTuning = player.earth_tuning
	var layer: EarthLayer = held_source_face.layer
	var block_center: Vector2 = Vector2.ZERO
	var torn_count: int = 0
	for cell: Vector2i in block:
		# The source tile is already gone: tear_out skips it (returns false).
		if layer.tear_out(cell):
			torn_count += 1
		block_center += layer.get_cell_global_center(cell) / block.size()
	boulder.grow(block_center, tuning.big_rock_size)
	# Pebbles by the ground used: the 3 extra tiles (the first one left its own).
	FX.spawn_gravel(block_center, tuning.big_rock_grow_gravel_count, Vector2(held_source_face.normal), 0.0)
	PebbleField.leave_pebbles_for_tiles(get_tree(), block_center, torn_count, Vector2(held_source_face.normal))
	FX.shake(tuning.big_rock_grow_shake_strength, tuning.big_rock_grow_shake_time)
	FX.play_sfx(&"earth_big_rock")


## The 2x2 block a big rock tears out of: the source tile, the next tile along the
## surface, and the two tiles behind those (into the ground). Tries "ahead" (away from
## the player) first, then the other way. Every new tile must be tearable earth not
## touching the player, and the space in front of the new surface tile must be free
## (the big rock comes out through it). Returns the 4 cells, or [] if neither fits.
func _find_big_block() -> Array[Vector2i]:
	var layer: EarthLayer = held_source_face.layer
	var source_cell: Vector2i = held_source_face.cell
	var normal: Vector2i = held_source_face.normal
	var tangent: Vector2i = held_source_tangent
	# The tangent should run along the surface; if not (a corner wrap), take the
	# direction perpendicular to the normal.
	if tangent.x * normal.x + tangent.y * normal.y != 0 or tangent == Vector2i.ZERO:
		tangent = Vector2i(-normal.y, normal.x)
	for side: Vector2i in [tangent, -tangent]:
		var new_cells: Array[Vector2i] = [source_cell + side, source_cell - normal, source_cell + side - normal]
		var fits: bool = true
		for cell: Vector2i in new_cells:
			if not layer.is_tearable(cell) or _is_touching_player(EarthFace.new(layer, cell, normal)):
				fits = false
				break
		if fits and _is_space_free(layer.get_cell_global_center(source_cell + side + normal)):
			var block: Array[Vector2i] = [source_cell]
			block.append_array(new_cells)
			return block
	return []


## Which way (-1 / +1) the hop drifts. Out of a wall face: away from that wall (its
## normal). The rock starts INSIDE the wall, so "away from the player" would point
## into it. Out of a floor: away from the player.
func _get_away_direction_x(rock_center: Vector2, source_face: EarthFace) -> float:
	if source_face.normal.x != 0:
		return float(source_face.normal.x)
	var offset_x: float = rock_center.x - player.get_center().x
	return signf(offset_x) if absf(offset_x) >= 1.0 else player.facing_direction


## True if a rock can tear out of `face`: tearable earth (fresh, not hardened) whose
## side faces open air, not a tile the player stands on or leans against, with the
## tile of space in front of it free of solids and of the player (the rock comes out
## through it).
func _does_face_fit(face: EarthFace) -> bool:
	if face == null or not face.layer.is_tearable(face.cell) or not face.is_fresh():
		return false
	if _is_touching_player(face):
		return false
	return _is_space_free(face.layer.get_cell_global_center(face.cell + face.normal))


## True if the player's body touches `face`'s tile (stands on it, or is pressed
## against it). Needed besides the front-space check: next to a hole, the "tile ahead"
## can be the SIDE face of the very tile under your feet (the path wraps over the
## hole's edge), whose front space is the empty hole.
func _is_touching_player(face: EarthFace) -> bool:
	var tile_size: float = face.layer.get_half_tile_size() * 2.0
	var tile_rect: Rect2 = Rect2(face.layer.get_cell_global_center(face.cell) - Vector2.ONE * tile_size / 2.0,
		Vector2.ONE * tile_size)
	# Two thin probes around the body: one just under the feet (standing on the tile)
	# and one just beside it (leaning against a wall tile). Not the whole hitbox grown
	# on every side, which would also catch the floor tile NEXT to the feet.
	# grow_individual(left, top, right, bottom) grows each side separately.
	var hitbox_rect: Rect2 = player.get_hitbox_rect()
	var under_feet: Rect2 = hitbox_rect.grow_individual(-0.5, 0.0, -0.5, 1.0)
	var beside_body: Rect2 = hitbox_rect.grow_individual(1.0, -0.5, 1.0, -0.5)
	return tile_rect.intersects(under_feet) or tile_rect.intersects(beside_body)


## True if a rock centered at `center` would overlap no solid and not the player.
## A physics shape query (like the column's sweep): "what overlaps this box now?"
func _is_space_free(center: Vector2) -> bool:
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	# Slightly smaller, so touching the surface beside it doesn't count as overlapping.
	check_shape.size = Vector2.ONE * (player.earth_tuning.boulder_size - 1.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 1 | 2  # bit values of layer 1 "world" and layer 2 "player"
	query.collide_with_areas = false
	return player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

class_name EarthBendAbility
extends Node2D
## The shared core of Earth bending (Earth_bending.md §4, §8, §11), used by all three
## earth moves. Lives under the player:  Player > EarthBendAbility
##
## Two jobs:
##   1. "What earth am I touching?" — find_start_surface() returns the fresh earth
##      (or Earth Column) face under the feet (standing) or beside the body
##      (wall-sliding), or null. A bend can only start there.
##   2. The bend SHADOW — begin_bend() puts a dark oval under the feet; after
##      shadow_start_delay it crawls along the surface, wrapping around corners.
##      It crosses used earth, columns and GRASS too (Earth_bending.md §11), but
##      GRAY rock stops it: it waits at the last face before the gray. It can only
##      ERUPT from fresh earth: over anything else it turns pale, and releasing
##      there fizzles. release_bend() fires at wherever it is; cancel_bend() stops
##      without using any earth.
## The EarthBend player STATE decides when to call these (key pressed / released,
## jump pressed, time up). The moves themselves (EarthMoveAbility components:
## column now, boulder and snake in E4-E5) register here with register_move();
## release_bend() hands the target face to the move whose key started the bend.
##
## REAL TIME: the world runs at bend_time_scale (0.3x) while bending, but the shadow
## must feel the same every time (Earth_bending.md §4). So it moves in _process()
## (every rendered frame) using real seconds = delta / Engine.time_scale. Physics only
## ticks ~18 times per real second at 0.3x; moving the shadow there would stutter.
##
## THE PATH: a list of EarthFace (tile + the side facing open air). Every step from
## one face to the next is 8 px along the surface, in one of three ways
## (n = the face's normal, t = the crawl direction along it):
##   - inner corner: the tile at cell + n + t is solid  -> climb onto ITS face -t
##                   (floor running into a wall: now on the wall, going up)
##   - straight:     the tile at cell + t is solid      -> same side of that tile
##   - outer corner: neither                            -> wrap onto our own side t
##                   (walking off a ledge: now on its side, going down)
## The next face's tile may be earth, used earth, a column or grass. If it's GRAY
## rock the step is refused and the shadow waits where it is until the bend ends.
## Each step passes through the same "corner point" (face center + t * half tile),
## which is what makes the drawn shadow slide smoothly round corners.
##
## Drawing: top_level = true, so this node ignores the player's transform and its
## own coordinates are world coordinates (like AirBlastDebugDraw).

## Shadow look: a dark oval lying on the surface, px (length along the surface, thickness).
## Over gray rock or used earth (can't erupt there) it's drawn pale instead.
const SHADOW_SIZE: Vector2 = Vector2(12.0, 5.0)
const SHADOW_COLOR: Color = Color(0.08, 0.04, 0.02, 0.9)
const SHADOW_PALE_COLOR: Color = Color(0.08, 0.04, 0.02, 0.35)
## F3 debug colors: the path, and the target face.
const DEBUG_PATH_COLOR: Color = Color(1.0, 0.85, 0.3, 0.9)
const DEBUG_TARGET_COLOR: Color = Color(1.0, 0.3, 0.9, 1.0)

## The player this belongs to (the parent node), set in _ready().
var player: Player
## The registered moves: bend key (StringName) -> EarthMoveAbility. Filled by
## register_move(); its keys are the earth keys that start a bend.
var moves: Dictionary = {}

## Set by queue_bend() (from player.wants_to_bend), read by EarthBend.enter().
var queued_action: StringName = &""
var queued_start_face: EarthFace = null
## True between begin_bend() and release_bend() / cancel_bend().
var is_bending: bool = false
## The snake (Stage E5). It has no key of its own (D is free since the one-key
## decision): a long A bend brings it out (get_release_move). Set by Player._ready().
var snake_move: EarthMoveAbility = null
## Which earth key started this bend (a key of `moves`). The state watches it.
var bend_action: StringName = &""
## The move the last release_bend() fired (or tried to), or null. EarthBend asks it
## for a follow-up state. Usually the move of bend_action, but see get_release_move().
var fired_move: EarthMoveAbility = null
## Real seconds since the bend started.
var bend_real_time: float = 0.0
## The faces the shadow has reached, in order. path[0] = under the player.
var path: Array[EarthFace] = []
## path_tangents[i] = the crawl direction on path[i] (toward path[i + 1]).
## The last entry is the direction it will try next.
var path_tangents: Array[Vector2i] = []
## How far the shadow has crawled along the path, px (0 = under the player).
var shadow_distance: float = 0.0
## Countdowns (real seconds) for the "while crawling" gravel.
var shadow_gravel_timer: float = 0.0
var feet_gravel_timer: float = 0.0


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	global_position = Vector2.ZERO
	z_index = 6  # above tiles and objects, under the debug drawing (50)


# --- Finding the earth we touch --------------------------------------------------

## The face a bend can start from, or null. Earth_bending.md §4: you must be
## touching fresh earth (standing on it or wall-sliding on it), or an Earth Column
## (§11: you can bend from a pillar, though nothing erupts from the pillar itself).
func find_start_surface() -> EarthFace:
	var face: EarthFace = find_touched_face()
	if face == null or not face.is_bend_start():
		return null
	return face


## The earth face we touch (fresh, used or a column), or null: the floor under the
## feet when standing, the wall beside the body when wall-sliding. Used tiles count
## here (the debug label shows them); find_start_surface() filters them out.
func find_touched_face() -> EarthFace:
	if player.is_on_floor():
		return _find_floor_face()
	if player.state_machine.current_state.name == &"WallSlide":
		return _find_wall_face(player.get_wall_direction())
	return null


## The floor tile under the feet. The body is 8 px wide, so it can stand on two tiles
## at once: try under the middle of the feet first, then each foot's edge, preferring
## a fresh tile, then a column (standing half on used earth and half on fresh still
## lets you bend).
func _find_floor_face() -> EarthFace:
	# 1 px below the feet is inside the floor tile.
	var feet: Vector2 = player.global_position + Vector2(0.0, 1.0)
	var half_width: float = _get_body_half_size().x - 0.5
	var faces: Array[EarthFace] = []
	for offset_x: float in [0.0, -half_width, half_width]:
		faces.append(_face_at(feet + Vector2(offset_x, 0.0), Vector2i.UP))
	return _pick_best_face(faces)


## The wall tile beside the body on side `wall_direction` (-1 left, +1 right).
## Checked at the body's middle, then near its top and bottom, preferring fresh tiles.
func _find_wall_face(wall_direction: float) -> EarthFace:
	if wall_direction == 0.0:
		return null
	var body_half_size: Vector2 = _get_body_half_size()
	# Just past the body's side edge, inside the wall tile we're pressed against.
	var probe_x: float = player.get_center().x + wall_direction * (body_half_size.x + 1.5)
	var normal: Vector2i = Vector2i(-int(wall_direction), 0)  # the wall faces back at us
	var faces: Array[EarthFace] = []
	for offset_y: float in [0.0, -body_half_size.y + 1.0, body_half_size.y - 1.0]:
		faces.append(_face_at(Vector2(probe_x, player.get_center().y + offset_y), normal))
	return _pick_best_face(faces)


## The best of the probed faces (nulls allowed): the first fresh one, else the first
## a bend can start from (a column), else the first at all (used earth, for the label).
func _pick_best_face(faces: Array[EarthFace]) -> EarthFace:
	var startable_face: EarthFace = null
	var any_face: EarthFace = null
	for face: EarthFace in faces:
		if face == null:
			continue
		if face.is_fresh():
			return face
		if startable_face == null and face.is_bend_start():
			startable_face = face
		if any_face == null:
			any_face = face
	return startable_face if startable_face != null else any_face


## The face with `normal` of the earth tile (or column) at `world_position`, or null
## if there's no earth there or that side of it isn't open to the air.
func _face_at(world_position: Vector2, normal: Vector2i) -> EarthFace:
	var earth_layer: EarthLayer = EarthLayer.find_layer_at(get_tree(), world_position)
	if earth_layer == null:
		return null
	var cell: Vector2i = earth_layer.get_cell_at(world_position)
	if not earth_layer.is_earthen(cell) or earth_layer.is_solid(cell + normal):
		return null
	return EarthFace.new(earth_layer, cell, normal)


func _get_body_half_size() -> Vector2:
	return (player.hitbox.shape as RectangleShape2D).size / 2.0


## Checks for a bend start THIS frame: an earth key just pressed while touching
## fresh earth or a column. If so, remembers both for EarthBend.enter() and returns true.
func queue_bend() -> bool:
	var action: StringName = get_just_pressed_bend_action()
	if action == &"":
		return false
	var start_face: EarthFace = find_start_surface()
	if start_face == null:
		return false
	queued_action = action
	queued_start_face = start_face
	return true


## Adds an earth move: its key now starts a bend, and releasing that bend calls
## its erupt(). Called by Player._ready() for each move component.
func register_move(move: EarthMoveAbility) -> void:
	moves[move.get_bend_action()] = move


## The earth key pressed THIS frame (a registered move's key), or &"" if none.
func get_just_pressed_bend_action() -> StringName:
	for action: StringName in moves:
		if Input.is_action_just_pressed(action):
			return action
	return &""


# --- The bend: start, release, cancel --------------------------------------------

## Starts a bend from `start_face` with the key `action`: shadow under the feet,
## crouch, gravel. Called by EarthBend.enter() (which also starts the slow motion).
func begin_bend(action: StringName, start_face: EarthFace) -> void:
	var tuning: EarthTuning = player.earth_tuning
	is_bending = true
	bend_action = action
	bend_real_time = 0.0
	shadow_distance = 0.0
	path = [start_face]
	path_tangents = [get_start_tangent(start_face)]
	shadow_gravel_timer = 0.0
	feet_gravel_timer = tuning.shadow_gravel_interval * 2.0
	player.movement_effects.hold_squash(tuning.bend_squash)
	# Bits pop off the ground at the feet: the bend has started.
	FX.spawn_gravel(start_face.get_global_center(), tuning.feet_gravel_count, Vector2(start_face.normal))
	FX.play_sfx(&"earth_bend_start")
	queue_redraw()


## Ends the bend and fires the move whose key started it at the face the shadow is
## on (the move's erupt() spends the tile). Returns that face, or null if the shadow
## is over gray rock or used earth: then the bend fizzles and no earth is used.
## Called by EarthBend when the key is released or time runs out.
func release_bend() -> EarthFace:
	var target_face: EarthFace = get_target_face()
	var move: EarthMoveAbility = get_release_move()
	fired_move = move
	_end_bend()
	if target_face == null:
		# Nothing to bend here (gray rock or used earth): no gravel, it isn't earth.
		FX.play_sfx(&"earth_fizzle")
		return null
	if move != null:
		move.erupt(target_face)
	return target_face


## The move a release would fire right now: the one whose key started the bend, except
## with ONE KEY (Player.is_one_key_column_snake, on by default): an A bend whose shadow
## has crawled off the feet (path index > 0) brings out the snake instead of a column.
## A quick tap (shadow still under the feet) stays a column: the super jump.
func get_release_move() -> EarthMoveAbility:
	if bend_action == &"earth_column" and player.is_one_key_column_snake() \
			and get_shadow_index() > 0 and snake_move != null:
		return snake_move
	return moves.get(bend_action) as EarthMoveAbility


## Ends the bend without using any earth (jump pressed, death, room change).
func cancel_bend() -> void:
	if is_bending:
		_end_bend()


func _end_bend() -> void:
	is_bending = false
	bend_action = &""
	player.movement_effects.release_squash()
	queue_redraw()  # clears the shadow


# --- The shadow ----------------------------------------------------------------------

## The first crawl direction: along a floor or ceiling, the way the player faces.
## On a wall, DOWN by default, so a wall-sliding player can raise something to land
## on; holding Up sends it up instead (Earth_bending.md §11, changed from §4).
## (For walls this is checked again when the crawl actually starts, so Up can be
## pressed while the shadow waits under the feet.) Public: the rock uses it too, to
## find the tile "ahead" of the feet.
func get_start_tangent(start_face: EarthFace) -> Vector2i:
	if start_face.normal.y != 0:
		return Vector2i(int(player.facing_direction), 0)
	return Vector2i.UP if Input.is_action_pressed("move_up") else Vector2i.DOWN


## _process runs every rendered frame. While bending, the shadow advances in real time.
func _process(delta: float) -> void:
	if not is_bending:
		if player != null and player.blast_debug.enabled:
			queue_redraw()  # F3: keep the last path drawing fresh (it clears when off)
		return
	var tuning: EarthTuning = player.earth_tuning
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	var was_waiting: bool = bend_real_time < tuning.shadow_start_delay
	bend_real_time += real_delta

	if bend_real_time >= tuning.shadow_start_delay:
		if was_waiting:
			# The crawl starts now: on a wall, Up may have been pressed meanwhile.
			path_tangents[0] = get_start_tangent(path[0])
		shadow_distance += tuning.shadow_speed * real_delta
		_extend_path_to_shadow()
		_spawn_crawl_gravel(real_delta)

	# Gravel keeps trickling at the feet the whole time (energy leaving the player).
	feet_gravel_timer -= real_delta
	if feet_gravel_timer <= 0.0:
		feet_gravel_timer = tuning.shadow_gravel_interval * 2.0
		# Pebble fraction 0: this trickle runs all bend long and would pile up pebbles
		# at the feet. The bend's start burst already leaves some there.
		FX.spawn_gravel(path[0].get_global_center(), 1, Vector2(path[0].normal), 0.0)
	queue_redraw()


## Adds faces to the path until it reaches the shadow. If gray rock blocks the
## next step, the shadow stops on the last face and waits there.
func _extend_path_to_shadow() -> void:
	var step_length: float = _get_step_length()
	while shadow_distance > (path.size() - 1) * step_length:
		var current_face: EarthFace = path[path.size() - 1]
		var tangent: Vector2i = path_tangents[path_tangents.size() - 1]
		var next: Array = _find_next_face(current_face, tangent)
		if next.is_empty():
			shadow_distance = (path.size() - 1) * step_length  # blocked: wait here
			return
		var next_face: EarthFace = next[0]
		path.append(next_face)
		path_tangents.append(next[1])
		_on_shadow_entered_face(next_face)


## The face after `face` when crawling in direction `tangent`, as [EarthFace, new
## tangent], or [] if GRAY rock blocks the way. See "THE PATH" in the header. The
## new face may be used earth, a column or grass: the shadow crosses those, it just
## can't erupt there.
## (The face's tile may then be a GRASS tile from another layer; it still lives in
## the earth layer's map coordinates, which match, so EarthFace works.)
func _find_next_face(face: EarthFace, tangent: Vector2i) -> Array:
	var earth_layer: EarthLayer = face.layer
	var inner_corner_cell: Vector2i = face.cell + face.normal + tangent
	if earth_layer.is_solid(inner_corner_cell):
		if earth_layer.is_shadow_blocking(inner_corner_cell):
			return []
		# Running into a wall (or a ceiling's wall...): climb onto its face toward us.
		return [EarthFace.new(earth_layer, inner_corner_cell, -tangent), face.normal]
	var straight_cell: Vector2i = face.cell + tangent
	if earth_layer.is_solid(straight_cell):
		if earth_layer.is_shadow_blocking(straight_cell):
			return []
		# The surface continues flat.
		return [EarthFace.new(earth_layer, straight_cell, face.normal), tangent]
	# Nothing ahead: wrap around our own tile's edge onto its side.
	return [EarthFace.new(earth_layer, face.cell, tangent), -face.normal]


## A new face reached: its tile shivers and drops a few bits behind the shadow.
## Grass does neither: it isn't earth, the energy only passes under it.
func _on_shadow_entered_face(face: EarthFace) -> void:
	if not face.layer.is_earthen(face.cell):
		return
	var tuning: EarthTuning = player.earth_tuning
	face.layer.shiver(face.cell, tuning.shiver_time)
	# Only a few pebbles along the path (shadow_path_pebble_fraction), not per tile.
	FX.spawn_gravel(face.get_global_center(), tuning.path_gravel_count, Vector2(face.normal),
		tuning.shadow_path_pebble_fraction)


## While the shadow moves over EARTH (fresh, used or a column), it sheds a bit or
## two now and then. Over grass: nothing, gravel only comes out of earth.
func _spawn_crawl_gravel(real_delta: float) -> void:
	shadow_gravel_timer -= real_delta
	if shadow_gravel_timer > 0.0:
		return
	shadow_gravel_timer = player.earth_tuning.shadow_gravel_interval
	var shadow_face: EarthFace = get_shadow_face()
	if not shadow_face.layer.is_earthen(shadow_face.cell):
		return
	# No pebbles from this trickle: the faces it crosses already drop a few.
	FX.spawn_gravel(get_shadow_position(), 1 + randi() % 2, get_shadow_normal(), 0.0)


## One step along the surface = one tile, px.
func _get_step_length() -> float:
	return path[0].layer.get_half_tile_size() * 2.0


## The face nearest to the shadow (fresh or not).
func get_shadow_face() -> EarthFace:
	return path[get_shadow_index()]


## Index in `path` of the face nearest to the shadow (0 = still under the player).
func get_shadow_index() -> int:
	return clampi(roundi(shadow_distance / _get_step_length()), 0, path.size() - 1)


## The face after `face` when crawling in `tangent`, as [EarthFace, new tangent], or
## [] if gray rock blocks the way. Same step as the shadow takes (see "THE PATH").
## Public for the rock (BoulderAbility), which tears out the tile ahead of the feet.
func find_next_face(face: EarthFace, tangent: Vector2i) -> Array:
	return _find_next_face(face, tangent)


## The face the move would erupt from right now: the shadow's face if it's fresh
## earth, else null (over grass, a column or used earth nothing can erupt).
func get_target_face() -> EarthFace:
	var shadow_face: EarthFace = get_shadow_face()
	return shadow_face if shadow_face.is_fresh() else null


## The shadow's position in world space, sliding smoothly along the path: the first
## half of each step heads to the corner point, the second half away from it.
func get_shadow_position() -> Vector2:
	var step_length: float = _get_step_length()
	var step_index: int = int(shadow_distance / step_length)
	if step_index >= path.size() - 1:
		return path[path.size() - 1].get_global_center()
	var step_fraction: float = shadow_distance / step_length - step_index
	var from_center: Vector2 = path[step_index].get_global_center()
	var corner_point: Vector2 = from_center + Vector2(path_tangents[step_index]) * step_length / 2.0
	if step_fraction < 0.5:
		return from_center.lerp(corner_point, step_fraction * 2.0)
	return corner_point.lerp(path[step_index + 1].get_global_center(), (step_fraction - 0.5) * 2.0)


## Which way the surface under the shadow faces (for drawing and gravel).
func get_shadow_normal() -> Vector2:
	var step_length: float = _get_step_length()
	var step_index: int = mini(roundi(shadow_distance / step_length), path.size() - 1)
	return Vector2(path[step_index].normal)


# --- Drawing --------------------------------------------------------------------------

## World coordinates (top_level). The shadow: a dark oval lying along the surface,
## sunk 1 px into the tile so it reads as a mark ON the earth, not floating.
func _draw() -> void:
	if is_bending:
		var normal: Vector2 = get_shadow_normal()
		var center: Vector2 = get_shadow_position() - normal
		var color: Color = SHADOW_COLOR if get_target_face() != null else SHADOW_PALE_COLOR
		_draw_oval(center, normal, SHADOW_SIZE, color)
	if player != null and player.blast_debug.enabled and not path.is_empty():
		_draw_debug_path()


## A filled oval lying along the surface whose normal is `normal`: long side
## along the surface (perpendicular to the normal), short side along the normal.
func _draw_oval(center: Vector2, normal: Vector2, size: Vector2, color: Color) -> void:
	var along: Vector2 = Vector2(-normal.y, normal.x)  # the normal turned 90°
	var points: PackedVector2Array = PackedVector2Array()
	var point_count: int = 16
	for point_index: int in point_count:
		var angle: float = TAU * point_index / point_count
		points.append(center + along * cos(angle) * size.x / 2.0 + normal * sin(angle) * size.y / 2.0)
	draw_colored_polygon(points, color)


## F3 (debug_gust_hitbox, shared with the gust's debug drawing): the shadow's path
## through face centers and corner points, a tick for each face's normal, and a box
## on the target face. Stays on screen after the bend until the next one.
func _draw_debug_path() -> void:
	var step_length: float = _get_step_length()
	var line_points: PackedVector2Array = PackedVector2Array()
	for face_index: int in path.size():
		var face_center: Vector2 = path[face_index].get_global_center()
		line_points.append(face_center)
		if face_index < path.size() - 1:
			line_points.append(face_center + Vector2(path_tangents[face_index]) * step_length / 2.0)
		draw_line(face_center, face_center + Vector2(path[face_index].normal) * 3.0, DEBUG_PATH_COLOR, 1.0)
	if line_points.size() >= 2:
		draw_polyline(line_points, DEBUG_PATH_COLOR, 1.0)
	var target_center: Vector2 = get_shadow_face().get_global_center()
	draw_rect(Rect2(target_center - Vector2(2, 2), Vector2(4, 4)), DEBUG_TARGET_COLOR, false, 1.0)


## For the debug label: what earth we touch, e.g. "fresh floor (12, 20)" or "-",
## or the shadow's progress while bending.
func describe_contact() -> String:
	if is_bending:
		return "bending %.1fs, shadow %d px%s" % [
			bend_real_time, int(shadow_distance), "" if get_target_face() != null else " (can't erupt here)"]
	var face: EarthFace = find_touched_face()
	if face == null:
		return "-"
	if face.layer.is_column(face.cell):
		return face.describe()  # "pillar floor (x, y)"
	return "%s %s" % ["fresh" if face.is_fresh() else "used", face.describe()]

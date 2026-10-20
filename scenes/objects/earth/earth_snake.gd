class_name EarthSnake
extends StaticBody2D
## Earth Snake (Earth_bending.md §7, §11, Stage E5): a ribbon of earth that comes out
## of an earth face and is steered over the tile grid, then hardens into a platform.
##
## Created by EarthSnakeAbility.erupt(): EarthSnake.new(), setup(), then added as a
## child of the ROOM, so Room.reset_objects() finds it (RESETTABLE_GROUP) and reset()
## deletes it. The player steers it from the SnakeSteer state (queue_turn, harden).
##
## Two phases:
##   MOVING    the head crawls one tile at a time in `head_direction`, at snake_speed
##             (REAL time, like the bend shadow: Earth_bending.md §11), so it moves in
##             _process() with delta / Engine.time_scale. Every tile it enters:
##               - spends one tile of the earth BUDGET (the patch it came out of, in
##                 order outward from the emergence point: the patch darkens tile by
##                 tile, like earth being pulled out)
##               - shoves crates, wisps and loose rocks out of the way, one tile along
##               - becomes solid at once (a collision box per tile)
##             It HARDENS (harden()) when A or Jump is pressed (SnakeSteer), the budget
##             runs out, the next tile is solid or already snake, something it pushes
##             is stuck, the head runs into the player, or snake_max_time passes.
##
## THE PLAYER IN THE WAY (after the E5 play-test): the player is rooted while steering,
## so you can steer the head into yourself. It shoves you out of its next tile along
## its direction and THROWS you that way, like a rising column's tip
## (Player.launch_from_column: up = the super jump, sideways = a side spring), and
## hardens. If you can't be shoved (the ground or a wall right behind you, e.g. the
## head coming down on you), you're CRUSHED (Player.die), like under a column.
##   HARDENED  a plain solid platform in used-earth color. It stays until room reset.
##
## Steering: queue_turn() remembers the last arrow pressed; the head turns when it
## reaches the next tile (a press between two tiles isn't lost). A turn straight back
## onto itself is ignored.
##
## Its tiles register with the EarthLayer like a pillar's (register_column): to the
## bend shadow they're solid used earth, so the shadow crawls over a snake and you can
## start a bend standing on one, but nothing erupts from it.
##
## It's a StaticBody2D on physics layer 1 ("world"), so the player stands on it,
## crates rest on it, wisps bump into it and sentry orbs pop on it (they all look at
## layer 1), exactly like tiles.
##
## Coordinates: the node sits at the room's origin (position 0), so its local
## coordinates are the room's. Tiles are drawn and collide at their cell's center.

enum Phase { MOVING, HARDENED }

## Emitted once when it hardens. `reason` says why (for the debug label and tests):
## "key", "budget", "solid", "player", "blocked" or "time".
signal hardened(reason: String)

## Every snake joins this group (tests, later enemy code).
const GROUP: StringName = &"earth_snake"
## While moving: earth that's still loose, between fresh and used. Hardened: used earth.
const MOVING_COLOR: Color = Color(0.6, 0.45, 0.22)
const HARDENED_COLOR: Color = EarthLayer.USED_COLOR
const OUTLINE_COLOR: Color = Color(0.2, 0.13, 0.08)
## Speckles: light chips on the hardened snake, dark ones on the moving one.
const LIGHT_SPECKLE_COLOR: Color = Color(0.48, 0.34, 0.2)
const DARK_SPECKLE_COLOR: Color = Color(0.17, 0.11, 0.06)
## Physics layers checked for things in the head's way: world (1: crates, loose rocks,
## other solids), pushable (4) and enemies (5: wisps). The player (2) is checked apart.
const BLOCKING_MASK: int = 1 | 8 | 16
const PLAYER_MASK: int = 2
## The "is something in this tile?" checks use a box this much smaller on each side,
## px, so things merely touching the tile's edge (standing next to it) don't count.
const OVERLAP_INSET: float = 0.5
## Max bodies one check reports.
const MAX_QUERY_RESULTS: int = 8

## Feel values (speed, budget, time). The player's EarthTuning, passed in setup().
var earth_tuning: EarthTuning
## The earth layer the snake came out of: its grid, its solid tiles, its budget.
var earth_layer: EarthLayer
## The face it came out of. The first tile is the open cell in front of it.
var source_face: EarthFace
var phase: Phase = Phase.MOVING
## The snake's tiles, in order: [0] = right in front of the face, last = the head.
var segment_cells: Array[Vector2i] = []
## The way the head is moving (one of the 4 directions).
var head_direction: Vector2i = Vector2i.UP
## The last turn asked for (Vector2i.ZERO = none), used when the head reaches a tile.
var queued_direction: Vector2i = Vector2i.ZERO
## 0..1: how far the head has crawled from its tile toward the next one.
var step_progress: float = 0.0
## The earth it may spend, in order (outward from the emergence point). One per tile.
var budget_cells: Array[Vector2i] = []
## How many of budget_cells are spent so far (= how many tiles it has).
var spent_count: int = 0
## Real seconds since it came out.
var moving_real_time: float = 0.0
## Why it hardened ("" while moving). See the `hardened` signal.
var harden_reason: String = ""
## Per-tile look: a few speckle offsets, made from the cell (so a tile always looks
## the same, moving or hardened).
var speckle_random: RandomNumberGenerator = RandomNumberGenerator.new()
## The player the head just shoved out of a tile it entered: thrown (and the snake
## hardened) once that tile is in (_throw_shoved_player). Null otherwise.
var shoved_player: Player = null


## Call before adding to the tree. `face` = the face it comes out of, `patch_cells` =
## the earth it may spend, in order (the face's own tile first). The ability already
## checked that the first tile is free (can_emerge_at).
func setup(face: EarthFace, tuning: EarthTuning, patch_cells: Array[Vector2i]) -> void:
	earth_tuning = tuning
	source_face = face
	earth_layer = face.layer
	budget_cells = patch_cells
	head_direction = face.normal  # straight out of the surface


func _ready() -> void:
	collision_layer = 1  # bit value of layer 1, "world": solid like the tiles
	collision_mask = 0   # a static body never needs to detect anything
	position = Vector2.ZERO  # at the room's origin (see the header)
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	z_index = 3  # in front of the ground, behind rocks (4) and gravel (5)
	# The first tile comes out right away, in front of the face.
	if not _try_enter(source_face.cell + source_face.normal, source_face.normal):
		harden(harden_reason)
	else:
		_throw_shoved_player(source_face.normal)


# --- Questions -------------------------------------------------------------------------

## True while it's still being steered.
func is_moving() -> bool:
	return phase == Phase.MOVING


## True if a snake could come out of `face`: its first tile (in front of the face) is
## open and the player isn't standing in it. Asked by EarthSnakeAbility before erupting,
## so a release with the shadow right under your own feet fizzles instead of spending
## earth. (With one key that can't happen: the shadow under the feet is a column.)
## Static: asked before any snake exists.
static func can_emerge_at(face: EarthFace) -> bool:
	var first_cell: Vector2i = face.cell + face.normal
	if face.layer.is_solid(first_cell):
		return false
	return _query_cell(face.layer, first_cell, PLAYER_MASK, []).is_empty()


# --- Steering --------------------------------------------------------------------------

## Asks the head to turn toward `direction` (one of the 4 directions) when it reaches
## the next tile. Called by the SnakeSteer state when an arrow is pressed.
func queue_turn(direction: Vector2i) -> void:
	queued_direction = direction


## Stops moving and becomes a plain platform. `reason`: see the `hardened` signal.
func harden(reason: String) -> void:
	if phase == Phase.HARDENED:
		return
	phase = Phase.HARDENED
	harden_reason = reason
	set_process(false)
	# A puff of gravel along its length and a small shake: it sets.
	var bits_per_tile: int = maxi(earth_tuning.snake_harden_gravel_count / maxi(segment_cells.size(), 1), 1)
	for cell: Vector2i in segment_cells:
		FX.spawn_gravel(earth_layer.get_cell_global_center(cell), bits_per_tile, Vector2.UP, 0.0)
	FX.shake(earth_tuning.snake_harden_shake_strength, earth_tuning.snake_harden_shake_time)
	FX.play_sfx(&"earth_snake_harden")
	queue_redraw()
	hardened.emit(reason)


# --- Moving ----------------------------------------------------------------------------

## _process runs every rendered frame: the head moves in real time (see the header).
func _process(delta: float) -> void:
	if phase != Phase.MOVING:
		return
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	moving_real_time += real_delta
	if moving_real_time >= earth_tuning.snake_max_time:
		harden("time")
		return
	step_progress += earth_tuning.snake_speed * real_delta / _get_tile_size()
	# A slow frame may cover more than one tile: take every step it owes.
	while step_progress >= 1.0 and phase == Phase.MOVING:
		step_progress -= 1.0
		_advance()
	queue_redraw()


## The head reached the next tile: turn if asked, then try to move in.
func _advance() -> void:
	if queued_direction != Vector2i.ZERO and queued_direction != -head_direction:
		head_direction = queued_direction
	queued_direction = Vector2i.ZERO
	if spent_count >= budget_cells.size():
		harden("budget")
		return
	var next_cell: Vector2i = segment_cells[segment_cells.size() - 1] + head_direction
	if not _try_enter(next_cell, head_direction):
		harden(harden_reason)
	else:
		_throw_shoved_player(head_direction)


## Tries to grow into `cell`, moving in `direction`. On success: the tile is solid,
## registered, and one tile of budget is spent (and a player in it was shoved out:
## shoved_player). On failure: returns false and leaves the reason in harden_reason
## (the caller hardens); a player pinned in the tile is crushed.
func _try_enter(cell: Vector2i, direction: Vector2i) -> bool:
	if earth_layer.is_solid(cell) or segment_cells.has(cell):
		harden_reason = "solid"
		return false
	var player_in_way: Player = _find_player_in(cell)
	if player_in_way != null:
		if not _shove_player_out_of(player_in_way, cell, direction):
			# Pinned against the ground or a wall: crushed, like under a column. Harden
			# BEFORE the death: dying leaves SnakeSteer, which would harden it as "key".
			harden_reason = "player"
			harden(harden_reason)
			player_in_way.die()
			return false
		shoved_player = player_in_way
	if not _shove_bodies_out_of(cell, direction):
		harden_reason = "blocked"
		return false
	segment_cells.append(cell)
	_add_tile_hitbox(cell)
	var new_cells: Array[Vector2i] = [cell]
	earth_layer.register_column(self, new_cells)
	# Spend the next tile of the patch: it darkens (EarthLayer fades it).
	earth_layer.mark_used(budget_cells[spent_count])
	spent_count += 1
	FX.spawn_gravel(earth_layer.get_cell_global_center(cell), earth_tuning.snake_head_gravel_count, Vector2(direction))
	return true


## The live player overlapping `cell`, or null.
func _find_player_in(cell: Vector2i) -> Player:
	for result: Dictionary in _query_cell(earth_layer, cell, PLAYER_MASK, []):
		var player: Player = result.collider as Player
		if player != null and not player.is_dead():
			return player
	return null


## Moves `player` along `direction` just far enough that their body is out of `cell`.
## Returns false (and doesn't move them) if a solid is in the way: they'd be squeezed.
func _shove_player_out_of(player: Player, cell: Vector2i, direction: Vector2i) -> bool:
	var push_direction: Vector2 = Vector2(direction)
	var body_size: Vector2 = (player.hitbox.shape as RectangleShape2D).size
	# Along the push: the cell's far side, and the player's near side (facing the head).
	# dot(push_direction) measures a position along the push (x for right, -y for up...).
	var cell_far_side: float = earth_layer.get_cell_global_center(cell).dot(push_direction) + earth_layer.get_half_tile_size()
	var player_near_side: float = player.hitbox.global_position.dot(push_direction) - absf(body_size.dot(push_direction)) / 2.0
	var push_distance: float = cell_far_side - player_near_side
	if push_distance <= 0.0:
		return true
	var motion: Vector2 = push_direction * push_distance
	# test_only = true: "how far could they move?" without moving them.
	var collision: KinematicCollision2D = player.move_and_collide(motion, true)
	if collision != null and collision.get_travel().length() < push_distance - 0.01:
		return false
	player.global_position += motion
	return true


## After the head took a tile the player was in: the snake hardens and the player is
## thrown along `direction`, like off a rising column's tip. (Hardening first, so the
## player leaving SnakeSteer finds nothing left to harden.)
func _throw_shoved_player(direction: Vector2i) -> void:
	if shoved_player == null:
		return
	var player: Player = shoved_player
	shoved_player = null
	harden("player")
	player.launch_from_column(Vector2(direction))
	FX.spawn_gravel(player.get_center(), earth_tuning.snake_head_gravel_count * 2, Vector2(direction))


## Pushes everything in `cell` one tile along `direction` (crates, wisps, loose rocks).
## Returns false if something there can't be moved (stuck against a solid) or isn't
## movable at all (a door, a stuck rock): then the head can't go in.
func _shove_bodies_out_of(cell: Vector2i, direction: Vector2i) -> bool:
	var motion: Vector2 = Vector2(direction) * _get_tile_size()
	for result: Dictionary in _query_cell(earth_layer, cell, BLOCKING_MASK, [get_rid()]):
		var body: CharacterBody2D = result.collider as CharacterBody2D
		if body == null:
			return false  # a static solid (door, another creation): not movable
		var rock: Boulder = body as Boulder
		if rock != null and not rock.is_loose():
			return false  # a stuck rock is part of the wall
		if rock == null and Pushable.find_pushable(body) == null:
			return false
		# move_and_collide(..., test_only = true): "how far could it move?" without
		# moving it. Only a full tile clears the way.
		var collision: KinematicCollision2D = body.move_and_collide(motion, true)
		if collision != null and collision.get_travel().length() < motion.length() - 0.01:
			return false
		body.global_position += motion
	return true


## Bodies on `mask` overlapping `cell` (a box OVERLAP_INSET smaller than the tile),
## excluding the RIDs in `exclude`. Static, so can_emerge_at() can use it too.
static func _query_cell(layer: EarthLayer, cell: Vector2i, mask: int, exclude: Array[RID]) -> Array[Dictionary]:
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	check_shape.size = Vector2.ONE * (layer.get_half_tile_size() * 2.0 - OVERLAP_INSET * 2.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, layer.get_cell_global_center(cell))
	query.collision_mask = mask
	query.collide_with_areas = false
	query.exclude = exclude
	return layer.get_world_2d().direct_space_state.intersect_shape(query, MAX_QUERY_RESULTS)


## One tile-sized collision box at `cell`.
func _add_tile_hitbox(cell: Vector2i) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2.ONE * _get_tile_size()
	var tile_hitbox: CollisionShape2D = CollisionShape2D.new()
	tile_hitbox.shape = shape
	tile_hitbox.position = to_local(earth_layer.get_cell_global_center(cell))
	add_child(tile_hitbox)


func _get_tile_size() -> float:
	return earth_layer.get_half_tile_size() * 2.0


## Called by Room.reset_objects() (death or R): snakes don't survive a reset.
func reset() -> void:
	earth_layer.unregister_column(self)
	phase = Phase.HARDENED
	queue_free()


# --- Drawing ---------------------------------------------------------------------------

## Each tile as a block of earth: its outline only on the sides that aren't snake, so
## the tiles read as one ribbon, with corners cut where two outer sides meet. While
## moving, the head also pokes into the next tile as it crawls (when that tile is
## open), so the ribbon grows smoothly instead of jumping a tile at a time.
## The first tile GROWS OUT OF THE GROUND it came from: no outline or cut corners on
## that side, a ragged root reaching into the ground tile, and a small fillet where
## it meets the surface on each side (EarthBaseLook), so there's no seam.
func _draw() -> void:
	var tile_size: float = _get_tile_size()
	for segment_index: int in segment_cells.size():
		var cell: Vector2i = segment_cells[segment_index]
		var top_left: Vector2 = to_local(earth_layer.get_cell_global_center(cell)) - Vector2.ONE * tile_size / 2.0
		# The first tile is joined to the ground on the face's side, like to a neighbour.
		var ground_side: Vector2i = -source_face.normal if segment_index == 0 else Vector2i.ZERO
		_draw_tile(cell, top_left, tile_size, _get_tile_color(segment_index), ground_side)
	if not segment_cells.is_empty():
		# Root and fillets where it leaves the ground (shared with the pillar).
		EarthBaseLook.draw(self, source_face, tile_size, _get_tile_color(0), OUTLINE_COLOR, segment_cells)
	if phase == Phase.MOVING and not segment_cells.is_empty():
		_draw_growing_head(tile_size)


## A tile's fill: loose earth while moving. Hardened, layered BANDS along the snake
## like a pillar's strata (EarthColumn's colors), 2 tiles per band.
func _get_tile_color(segment_index: int) -> Color:
	if phase == Phase.MOVING:
		return MOVING_COLOR
	var band_colors: Array[Color] = [HARDENED_COLOR, EarthColumn.BAND_LIGHT_COLOR, HARDENED_COLOR, EarthColumn.BAND_DARK_COLOR]
	return band_colors[(segment_index / 2) % band_colors.size()]


## One snake tile at `top_left`. See _draw(). Where two outer sides meet, the corner
## pixel is left out and the outline steps in diagonally: a rough, rounded corner.
## `ground_side`: a side joined to the ground (the first tile's), treated like a
## neighbouring snake tile: no outline, no cut corners. ZERO = none.
func _draw_tile(cell: Vector2i, top_left: Vector2, tile_size: float, fill_color: Color,
		ground_side: Vector2i) -> void:
	var open_up: bool = ground_side != Vector2i.UP and not segment_cells.has(cell + Vector2i.UP)
	var open_down: bool = ground_side != Vector2i.DOWN and not segment_cells.has(cell + Vector2i.DOWN)
	var open_left: bool = ground_side != Vector2i.LEFT and not segment_cells.has(cell + Vector2i.LEFT)
	var open_right: bool = ground_side != Vector2i.RIGHT and not segment_cells.has(cell + Vector2i.RIGHT)
	# 1 = that corner is cut (both its sides are outer sides).
	var cut_top_left: float = 1.0 if open_up and open_left else 0.0
	var cut_top_right: float = 1.0 if open_up and open_right else 0.0
	var cut_bottom_left: float = 1.0 if open_down and open_left else 0.0
	var cut_bottom_right: float = 1.0 if open_down and open_right else 0.0
	# The fill: the middle columns whole, the outer columns shortened at cut corners.
	draw_rect(Rect2(top_left + Vector2(1.0, 0.0), Vector2(tile_size - 2.0, tile_size)), fill_color)
	draw_rect(Rect2(top_left + Vector2(0.0, cut_top_left), Vector2(1.0, tile_size - cut_top_left - cut_bottom_left)), fill_color)
	draw_rect(Rect2(top_left + Vector2(tile_size - 1.0, cut_top_right),
		Vector2(1.0, tile_size - cut_top_right - cut_bottom_right)), fill_color)
	# Outline on the outer sides (1 px inside the tile), stopping short of cut corners...
	if open_up:
		draw_rect(Rect2(top_left + Vector2(cut_top_left, 0.0), Vector2(tile_size - cut_top_left - cut_top_right, 1.0)), OUTLINE_COLOR)
	if open_down:
		draw_rect(Rect2(top_left + Vector2(cut_bottom_left, tile_size - 1.0),
			Vector2(tile_size - cut_bottom_left - cut_bottom_right, 1.0)), OUTLINE_COLOR)
	if open_left:
		draw_rect(Rect2(top_left + Vector2(0.0, cut_top_left), Vector2(1.0, tile_size - cut_top_left - cut_bottom_left)), OUTLINE_COLOR)
	if open_right:
		draw_rect(Rect2(top_left + Vector2(tile_size - 1.0, cut_top_right),
			Vector2(1.0, tile_size - cut_top_right - cut_bottom_right)), OUTLINE_COLOR)
	# ...and one pixel in from each cut corner, so the outline stays closed.
	for corner: Vector2 in [Vector2(cut_top_left, cut_top_left), Vector2(tile_size - 2.0, 1.0) * cut_top_right,
			Vector2(1.0, tile_size - 2.0) * cut_bottom_left, Vector2(tile_size - 2.0, tile_size - 2.0) * cut_bottom_right]:
		if corner != Vector2.ZERO:
			draw_rect(Rect2(top_left + corner, Vector2.ONE), OUTLINE_COLOR)
	# Speckles: 2 per tile, placed from the cell itself (seed), so they never flicker.
	speckle_random.seed = hash(cell)
	var speckle_color: Color = DARK_SPECKLE_COLOR if phase == Phase.MOVING else LIGHT_SPECKLE_COLOR
	for speckle_index: int in 2:
		var spot: Vector2 = Vector2(speckle_random.randi_range(2, int(tile_size) - 3), speckle_random.randi_range(2, int(tile_size) - 3))
		draw_rect(Rect2(top_left + spot, Vector2.ONE), speckle_color)
	if phase == Phase.HARDENED:
		# A short diagonal crack (3 px), like the ones the GroundPainter draws on used
		# earth, so the snake reads as the same spent earth as the patch it came from.
		var crack_start: Vector2 = Vector2(speckle_random.randi_range(2, 3), speckle_random.randi_range(2, 3))
		var crack_step_x: float = 1.0 if speckle_random.randf() < 0.5 else -1.0
		if crack_step_x < 0.0:
			crack_start.x += 2.0
		for step: int in 3:
			draw_rect(Rect2(top_left + crack_start + Vector2(crack_step_x * step, step), Vector2.ONE), GroundPainter.CRACK_COLOR)


## While moving: the head's front edge crawls into the next tile (step_progress of
## the way), if that tile is open, with a lighter rim on the front.
func _draw_growing_head(tile_size: float) -> void:
	var head_cell: Vector2i = segment_cells[segment_cells.size() - 1]
	var direction: Vector2i = queued_direction if queued_direction != Vector2i.ZERO and queued_direction != -head_direction \
		else head_direction
	var next_cell: Vector2i = head_cell + direction
	if earth_layer.is_solid(next_cell) or segment_cells.has(next_cell) or spent_count >= budget_cells.size():
		return
	var head_center: Vector2 = to_local(earth_layer.get_cell_global_center(head_cell))
	var reach: float = floorf(step_progress * tile_size)
	if reach < 1.0:
		return
	# The rectangle from the head tile's front edge, `reach` px into the next tile.
	var front_edge_center: Vector2 = head_center + Vector2(direction) * tile_size / 2.0
	var across: Vector2 = Vector2(absf(direction.y), absf(direction.x)) * (tile_size - 2.0)
	var growth: Rect2 = Rect2(front_edge_center - across / 2.0, Vector2.ZERO).expand(
		front_edge_center + across / 2.0 + Vector2(direction) * reach)
	draw_rect(growth, MOVING_COLOR)
	draw_rect(growth, OUTLINE_COLOR, false, 1.0)

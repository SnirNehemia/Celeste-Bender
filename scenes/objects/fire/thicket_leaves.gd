class_name ThicketLeaves
extends Node2D
## Thicket leaves (after the F6 play-test): a bush of leaves over every open face of
## a plant tile layer. They sway, lean in the wind, part round the player and whip in
## a gust, then blacken, shrink and drop off one by one as their tile burns.
##
## Made by ThicketLayer (all its cells) and OvergrownLayer (only its cells that pass
## for thicket) in their _ready(): `layer` is that TileMapLayer, `grows_on` a
## Callable(cell) -> bool saying which cells get leaves. We're its child, so our
## local coordinates are the layer's.
##
## THE LOOK (second F6 play-test: "bigger, like the leaf piles, a bit past the tiles,
## like a bush"): each leaf is the leaf pile's diamond (LEAF_SHAPE, 4x2 px), scaled
## 0.9-1.4x and turned to splay out from its face. They sit in a band from a little
## inside the tile's edge to leaf_bush_reach px past it, so the thicket's outline is a
## leafy, uneven bush, not the tile grid. Leaves over the crust are darker and drawn
## first; the ones sticking out are brighter and drawn on top, which gives the bush
## some depth. Under all of them, leaves_per_cell leaves are spread over every tile
## (buried ones too), so the whole mass reads as a bush with brambles showing
## through.
##
## THE MOTION is the grass blades' (GrassLayer): each leaf has a 2D bend (px) pulled
## toward a target by a damped spring, and turns a little as it bends. The target is
##   - a slow idle sway along the face (each leaf at its own phase)
##   - wind: the WindZones the leaf is in (looked up once: zones don't move)
##   - the player: a leaf the body touches is pushed away from the body's middle and
##     dragged along with its speed
## A gust KICKS the bend speed instead (the Pushable contract, through one sensor
## Area2D over the whole layer), so leaves whip over and spring back.
## The numbers are in FireTuning's "Thicket leaves" group.
##
## Kept in packed arrays and drawn in one _draw() (a few hundred leaves). z_index 1:
## in front of the player's feet and the ground, like the grass blades. Only the room
## on screen moves.

## One leaf: the leaf pile's 4x2 px diamond (scaled per leaf), long axis along +x.
const LEAF_SHAPE: PackedVector2Array = [Vector2(-2.0, 0.0), Vector2(0.0, -1.0), Vector2(2.0, 0.0), Vector2(0.0, 1.0)]
## Leaves over the crust (darker) and sticking out of it (brighter): deep, saturated
## greens that go with the brambles (the leaf piles' are drier).
## Leaves spread over the tiles themselves: between the bramble inside and the edge
## leaves in shade, so the bush has a body.
const COVER_COLORS: Array[Color] = [Color(0.11, 0.25, 0.11), Color(0.14, 0.3, 0.13), Color(0.18, 0.36, 0.15)]
const INNER_COLORS: Array[Color] = [Color(0.13, 0.3, 0.13), Color(0.16, 0.34, 0.15), Color(0.12, 0.26, 0.12)]
const OUTER_COLORS: Array[Color] = [Color(0.24, 0.46, 0.19), Color(0.3, 0.54, 0.21),
	Color(0.2, 0.4, 0.17), Color(0.38, 0.55, 0.2)]
## Leaves this far inside the tile's edge or less count as "inner" (darker), px.
const INNER_DEPTH: float = 0.5
## The deepest a leaf sits inside the edge, px (over the crust).
const MAX_INSET: float = 2.5
## How much a leaf turns per px it's bent sideways, radians.
const TURN_PER_BEND: float = 0.3
## A burning leaf goes this dark and shrinks; each drops off somewhere between these
## shares of its cell's burn (one by one, not all at once).
const CHAR_COLOR: Color = Color(0.09, 0.07, 0.07)
const BURN_DROP_EARLIEST: float = 0.35
const BURN_DROP_LATEST: float = 0.65

## Dry brown that a cover's leaves are pulled toward (see `is_cover`).
const COVER_HINT_BROWN: Color = Color(0.42, 0.3, 0.14)

var layer: TileMapLayer
var grows_on: Callable
## True for an overgrown cover's leaves (OvergrownLayer): every leaf is pulled
## FireTuning.cover_leaf_brownness of the way toward COVER_HINT_BROWN, a hint that
## something is hidden behind this bush.
var is_cover: bool = false
var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
## The room's FireGrid, found on first use (it's made after the layers), or null.
var fire_grid: FireGrid
var fire_grid_looked_up: bool = false

## Per leaf (same index in every array), in our local coordinates: its rest position,
## the face's outward direction (unit; the sway runs across it), its rest rotation,
## size, idle phase, bend and bend speed, the wind there, its color, and its cell.
var leaf_anchors: PackedVector2Array = PackedVector2Array()
var leaf_directions: PackedVector2Array = PackedVector2Array()
var leaf_rotations: PackedFloat32Array = PackedFloat32Array()
var leaf_scales: PackedFloat32Array = PackedFloat32Array()
var leaf_phases: PackedFloat32Array = PackedFloat32Array()
var leaf_bends: PackedVector2Array = PackedVector2Array()
var leaf_bend_speeds: PackedVector2Array = PackedVector2Array()
var leaf_winds: PackedVector2Array = PackedVector2Array()
var leaf_colors: PackedColorArray = PackedColorArray()
var leaf_cells: Array[Vector2i] = []
var winds_found: bool = false
var sway_clock: float = 0.0
## Reused by _draw() every frame (so it doesn't allocate new arrays 60 times a
## second): every drawn leaf's 4 corners and their color, and the triangle list
## that joins them (see _build_draw_indices).
var draw_points: PackedVector2Array = PackedVector2Array()
var draw_colors: PackedColorArray = PackedColorArray()
var draw_indices: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	z_index = 1
	add_to_group(Pushable.GROUP)
	_generate_leaves()
	_add_gust_sensor()


## A bush on every open face of every cell `grows_on` accepts: tops get
## leaves_per_face + 1, sides and undersides leaves_per_face. Each leaf is placed
## along the face (a little past its ends, so corners are covered), from MAX_INSET
## inside the edge to leaf_bush_reach outside it, turned to splay out. Seeded per
## cell and face, so the bush is the same every run. Inner leaves are stored (and so
## drawn) before outer ones.
func _generate_leaves() -> void:
	var tile_size: float = float(layer.tile_set.tile_size.x)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	var cover_leaves: Array[Array] = []
	var inner_leaves: Array[Array] = []
	var outer_leaves: Array[Array] = []
	for cell: Vector2i in layer.get_used_cells():
		if not grows_on.call(cell):
			continue
		var center: Vector2 = layer.map_to_local(cell)
		# Leaves over the tile itself (third F6 play-test: "more like a bush"), buried
		# cells too: anywhere on the cell, any angle, in the darkest greens, so the
		# brambles show through the gaps. Drawn first, under the edge leaves.
		random.seed = hash(cell + Vector2i(97, 41))
		for leaf_index: int in fire_tuning.leaves_per_cell:
			var spot: Vector2 = center + Vector2(random.randf_range(-0.5, 0.5), random.randf_range(-0.5, 0.5)) * tile_size
			cover_leaves.append([spot, Vector2.UP, random.randf_range(0.0, TAU), random.randf_range(1.0, 1.4),
				random.randf_range(0.0, TAU), COVER_COLORS[random.randi() % COVER_COLORS.size()], cell])
		for normal: Vector2i in EarthLayer.FACE_NORMALS:
			if _is_solid_anywhere(cell + normal):
				continue
			random.seed = hash(Vector3i(cell.x, cell.y, normal.x * 3 + normal.y))
			var count: int = fire_tuning.leaves_per_face + (1 if normal == Vector2i.UP else 0)
			var outward: Vector2 = Vector2(normal)
			var along_axis: Vector2 = Vector2(absf(normal.y), absf(normal.x))
			for leaf_index: int in count:
				var along: float = random.randf_range(-0.6, 0.6) * tile_size
				var out: float = random.randf_range(-MAX_INSET, fire_tuning.leaf_bush_reach)
				var anchor: Vector2 = center + outward * (tile_size / 2.0 + out) + along_axis * along
				# Splayed: mostly pointing out of the face, any way within ±70°.
				var rotation_at_rest: float = outward.angle() + random.randf_range(-1.2, 1.2)
				var is_inner: bool = out < INNER_DEPTH
				var colors: Array[Color] = INNER_COLORS if is_inner else OUTER_COLORS
				var leaf: Array = [anchor, outward, rotation_at_rest, random.randf_range(0.9, 1.4),
					random.randf_range(0.0, TAU), colors[random.randi() % colors.size()], cell]
				if is_inner:
					inner_leaves.append(leaf)
				else:
					outer_leaves.append(leaf)
	for leaf: Array in cover_leaves + inner_leaves + outer_leaves:
		leaf_anchors.append(leaf[0])
		leaf_directions.append(leaf[1])
		leaf_rotations.append(leaf[2])
		leaf_scales.append(leaf[3])
		leaf_phases.append(leaf[4])
		var color: Color = leaf[5]
		if is_cover:
			color = color.lerp(COVER_HINT_BROWN, fire_tuning.cover_leaf_brownness)
		leaf_colors.append(color)
		leaf_cells.append(leaf[6])
		leaf_bends.append(Vector2.ZERO)
		leaf_bend_speeds.append(Vector2.ZERO)
		leaf_winds.append(Vector2.ZERO)


## True if any tile layer of the room has a tile at `cell` (then that face is buried).
func _is_solid_anywhere(cell: Vector2i) -> bool:
	for sibling: Node in layer.get_parent().get_children():
		var other: TileMapLayer = sibling as TileMapLayer
		if other != null and other.get_cell_source_id(cell) != -1:
			return true
	return false


## One sensor Area2D on layer 4 ("pushable") over all the leaves, so the gust's shape
## query finds us (Pushable.find_pushable checks the touched node's parent: us).
func _add_gust_sensor() -> void:
	if leaf_anchors.is_empty():
		return
	var bounds: Rect2 = Rect2(leaf_anchors[0], Vector2.ZERO)
	for anchor: Vector2 in leaf_anchors:
		bounds = bounds.expand(anchor)
	bounds = bounds.grow(4.0)
	var sensor: Area2D = Area2D.new()
	sensor.collision_layer = 8  # bit value of layer 4, "pushable"
	sensor.collision_mask = 0
	sensor.monitoring = false
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = bounds.size
	shape_node.shape = rectangle
	shape_node.position = bounds.get_center()
	sensor.add_child(shape_node)
	add_child(sensor)


func _physics_process(delta: float) -> void:
	var room: Room = layer.get_parent() as Room
	if leaf_anchors.is_empty() or (room != null and GameState.current_room != room):
		return  # not the room on screen: keep still
	if not winds_found:
		_find_winds()
	sway_clock += delta
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	var player_rect: Rect2 = Rect2()
	var player_velocity: Vector2 = Vector2.ZERO
	if player != null and not player.is_dead():
		# In our local coordinates, grown 2 px: a leaf is about that big around its middle.
		player_rect = Rect2(to_local(player.get_hitbox_rect().position), player.get_hitbox_rect().size).grow(2.0)
		player_velocity = player.velocity
	var stiffness: float = fire_tuning.leaf_stiffness
	var damping: float = fire_tuning.leaf_damping
	var max_bend: float = fire_tuning.leaf_max_bend
	for leaf_index: int in leaf_anchors.size():
		var target: Vector2 = _get_target_bend(leaf_index, player_rect, player_velocity)
		var bend: Vector2 = leaf_bends[leaf_index]
		var bend_speed: Vector2 = leaf_bend_speeds[leaf_index]
		# A damped spring, per axis: accelerate toward the target, lose some speed.
		bend_speed += ((target - bend) * stiffness - bend_speed * damping) * delta
		bend = (bend + bend_speed * delta).limit_length(max_bend)
		leaf_bends[leaf_index] = bend
		leaf_bend_speeds[leaf_index] = bend_speed
	queue_redraw()


## Where leaf `leaf_index` wants to be, relative to rest (see the header).
func _get_target_bend(leaf_index: int, player_rect: Rect2, player_velocity: Vector2) -> Vector2:
	var across: Vector2 = leaf_directions[leaf_index].orthogonal()
	var target: Vector2 = across * sin(sway_clock * fire_tuning.leaf_idle_sway_speed + leaf_phases[leaf_index]) \
		* fire_tuning.leaf_idle_sway
	target += leaf_winds[leaf_index] * fire_tuning.leaf_wind_bend_per_speed
	if player_rect.size != Vector2.ZERO and player_rect.has_point(leaf_anchors[leaf_index]):
		var away: Vector2 = (leaf_anchors[leaf_index] - player_rect.get_center()).normalized()
		target += away * fire_tuning.leaf_player_push + player_velocity * fire_tuning.leaf_player_drag_per_speed
	return target


## The wind at each leaf, from the WindZones in the game (they don't move).
func _find_winds() -> void:
	winds_found = true
	var zones: Array[Node] = get_tree().get_nodes_in_group(WindZone.GROUP)
	for leaf_index: int in leaf_anchors.size():
		var leaf_position: Vector2 = to_global(leaf_anchors[leaf_index])
		var wind: Vector2 = Vector2.ZERO
		for zone: Node in zones:
			var wind_zone: WindZone = zone as WindZone
			if wind_zone != null and wind_zone.contains_point(leaf_position):
				wind += wind_zone.get_wind_velocity()
		leaf_winds[leaf_index] = wind


## The Pushable contract (fallback when the gust's origin is unknown): nothing to aim
## by, so leave the leaves alone (every gust in the game passes its origin).
func receive_gust(_direction: Vector2, _strength: float) -> void:
	pass


## The Pushable contract, with the gust's origin: leaves within leaf_gust_reach are
## kicked along the gust (fanned a little away from its origin), less with distance.
func receive_gust_from(direction: Vector2, strength: float, source_position: Vector2) -> void:
	if not source_position.is_finite():
		return
	var reach: float = fire_tuning.leaf_gust_reach
	for leaf_index: int in leaf_anchors.size():
		var from_source: Vector2 = to_global(leaf_anchors[leaf_index]) - source_position
		var distance: float = from_source.length()
		if distance > reach:
			continue
		var outward: Vector2 = from_source / distance if distance > 0.01 else direction
		if outward.dot(direction) < -0.2:
			continue  # behind an aimed gust
		var falloff: float = 1.0 - 0.6 * distance / reach
		var push: Vector2 = (direction * 0.7 + outward * 0.3).normalized()
		leaf_bend_speeds[leaf_index] += push * strength * fire_tuning.leaf_gust_kick_per_strength * falloff


## Every leaf whose tile is still there: LEAF_SHAPE moved to its bent position (whole
## pixels, so it stays crisp), turned by its rotation plus a little for the bend, and
## scaled. On a burning cell a leaf blackens and shrinks as the fire works through
## it, and drops off at its own moment between BURN_DROP_EARLIEST and _LATEST of the
## burn.
##
## All the leaves go to the renderer as ONE triangle list (two triangles per leaf
## diamond), not one polygon per leaf. Measured in a 544-leaf room: one
## draw_colored_polygon per leaf cost ~11 ms a frame (Godot re-triangulates every
## polygon on every redraw, and each is its own draw command), the triangle list well
## under 1 ms. So we turn and scale the 4 corners ourselves instead of using
## draw_set_transform.
func _draw() -> void:
	if not fire_grid_looked_up:
		fire_grid_looked_up = true
		fire_grid = layer.get_parent().get_node_or_null("FireGrid") as FireGrid
	var leaf_count: int = leaf_anchors.size()
	if leaf_count == 0:
		return
	# Sized for every leaf; cut down to the leaves actually drawn at the end.
	draw_points.resize(leaf_count * 4)
	draw_colors.resize(leaf_count * 4)
	if draw_indices.size() != leaf_count * 6:
		_build_draw_indices(leaf_count)
	var drawn_count: int = 0
	for leaf_index: int in leaf_count:
		var cell: Vector2i = leaf_cells[leaf_index]
		if layer.get_cell_source_id(cell) == -1:
			continue  # burnt away
		var color: Color = leaf_colors[leaf_index]
		var leaf_scale: float = leaf_scales[leaf_index]
		if fire_grid != null and fire_grid.get_state(cell) == FireGrid.State.BURNING:
			var drop_at: float = lerpf(BURN_DROP_EARLIEST, BURN_DROP_LATEST, leaf_phases[leaf_index] / TAU)
			var burn: float = fire_grid.get_burn_progress(cell)
			if burn >= drop_at:
				continue  # burnt off
			var char_share: float = clampf(burn / drop_at * 1.3, 0.0, 1.0)
			color = color.lerp(CHAR_COLOR, char_share)
			leaf_scale *= 1.0 - 0.4 * char_share
		var bend: Vector2 = leaf_bends[leaf_index]
		var across: Vector2 = leaf_directions[leaf_index].orthogonal()
		var leaf_rotation: float = leaf_rotations[leaf_index] + bend.dot(across) * TURN_PER_BEND
		var leaf_position: Vector2 = (leaf_anchors[leaf_index] + bend).round()
		# The diamond's long axis (LEAF_SHAPE's x) and short axis (its y), turned and
		# scaled: each corner is position + x * long_axis + y * short_axis.
		var long_axis: Vector2 = Vector2.from_angle(leaf_rotation) * leaf_scale
		var short_axis: Vector2 = Vector2(-long_axis.y, long_axis.x)  # turned +90°
		var first_vertex: int = drawn_count * 4
		for corner: int in 4:
			var shape_point: Vector2 = LEAF_SHAPE[corner]
			draw_points[first_vertex + corner] = leaf_position + long_axis * shape_point.x + short_axis * shape_point.y
			draw_colors[first_vertex + corner] = color
		drawn_count += 1
	if drawn_count == 0:
		return
	draw_points.resize(drawn_count * 4)
	draw_colors.resize(drawn_count * 4)
	var indices: PackedInt32Array = draw_indices
	if drawn_count < leaf_count:
		indices = draw_indices.slice(0, drawn_count * 6)  # some burnt off
	# The RenderingServer is the engine's drawing backend that every draw_* call goes
	# through; this one takes a whole triangle list at once. Called inside _draw(), it
	# is cleared and redone with every queue_redraw(), like the draw_* calls.
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, draw_points, draw_colors)


## Two triangles per leaf diamond (corners 0-1-2 and 0-2-3), for `leaf_count`
## leaves. Leaf i's corners are vertices 4i..4i+3, so this never changes for a
## given count: built once, not every frame.
func _build_draw_indices(leaf_count: int) -> void:
	draw_indices.resize(leaf_count * 6)
	for leaf_index: int in leaf_count:
		var first_vertex: int = leaf_index * 4
		var first_index: int = leaf_index * 6
		draw_indices[first_index] = first_vertex
		draw_indices[first_index + 1] = first_vertex + 1
		draw_indices[first_index + 2] = first_vertex + 2
		draw_indices[first_index + 3] = first_vertex
		draw_indices[first_index + 4] = first_vertex + 2
		draw_indices[first_index + 5] = first_vertex + 3

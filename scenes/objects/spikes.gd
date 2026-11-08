@tool
class_name Spikes
extends Area2D
## A strip of spikes: red triangles that kill the player.
##
## Place the node at the TOP-LEFT corner of the 8x8 tile cell(s) it occupies, then set:
##   - facing:     which way the tips point (UP = sitting on a floor, DOWN = hanging
##                 from a ceiling, LEFT/RIGHT = stuck to a wall)
##   - tile_count: how many 8 px tiles long the strip is
## The triangles and hitbox are generated from those two values.
##
## Fairness (like Celeste):
##   - The hitbox is smaller than the drawing: 1 px in from each end, and only the
##     bottom 3 px of the 5 px tall triangles.
##   - Spikes only kill if you're NOT moving the way their tips point. So you can
##     graze up-spikes while jumping upward, or slide past wall spikes moving away.
##
## Area2D detects overlapping bodies without blocking them. This one sits on physics
## layer 3 ("hazards") and only looks at layer 2 ("player").
##
## @tool makes this script also run in the editor, so the triangles show up (and
## update) while you place spikes in a room, not only when the game runs.

enum Facing { UP, DOWN, LEFT, RIGHT }

## Spike color (GAME_DESIGN.md §2: red).
const SPIKE_COLOR: Color = Color(0.9, 0.2, 0.2)
## Looks: stone teeth that grow out of the ground (the same gray as the gray terrain,
## so they blend into it), a lighter left facet, and a bright red tip that says
## "danger". Drawing only: the hitbox below is unchanged.
const STONE_COLOR: Color = Color(0.36, 0.37, 0.43)
const STONE_LIGHT_COLOR: Color = Color(0.52, 0.52, 0.58)
## One slim tooth per tile: narrower than the tile by TOOTH_INSET px on each side, so
## it reads as an elegant thorn with the rocky lip between neighbours.
const TEETH_PER_TILE: int = 1
const TOOTH_INSET: float = 1.0
## Drawn heights, repeating along a strip so it looks hand-made but never changes
## between redraws. All stay above HITBOX_HEIGHT, so every tip is still fair.
const SPIKE_HEIGHTS: Array[float] = [7.0, 6.0, 7.0, 7.0, 6.0, 7.0, 6.0]
## How far the stone base reaches INTO the surface the spikes are mounted on, px:
## terrain textures have dents along their edge, and this fills the gaps under the
## spikes so they grow out of something instead of floating over holes.
const BASE_SINK: float = 3.0
## How far the stone base rises above the surface between the teeth, px (a rocky lip).
const BASE_LIP: float = 1.0
## Where the red tip starts, as a fraction of the spike's height.
const RED_TIP_START: float = 0.45
## One tile, in pixels.
const TILE_SIZE: float = 8.0
## Drawn height of each triangle, measured from its base.
const SPIKE_HEIGHT: float = 5.0  # the base height; each spike varies, see SPIKE_HEIGHTS
## Deadly part of the triangle, measured from its base (smaller than drawn = fair).
const HITBOX_HEIGHT: float = 3.0
## Hitbox inset at both ends of the strip, in pixels.
const HITBOX_END_INSET: float = 1.0

## Which way the spike tips point. The setter rebuilds the shape when changed in the editor.
@export var facing: Facing = Facing.UP:
	set(value):
		facing = value
		_rebuild()
## Length of the strip in tiles.
@export_range(1, 40) var tile_count: int = 1:
	set(value):
		tile_count = value
		_rebuild()

## The deadly rectangle relative to this node (set by _rebuild()).
var hitbox_local_rect: Rect2 = Rect2()


func _ready() -> void:
	collision_layer = 4  # bit value of layer 3, "hazards"
	collision_mask = 2   # bit value of layer 2, "player"
	_rebuild()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return  # in the editor: draw only, never kill
	# Checked every frame (not just on entry) so that if you rise into up-spikes
	# safely and then start falling while still touching them, you die.
	for body: Node2D in get_overlapping_bodies():
		var touched_player: Player = body as Player
		if touched_player == null:
			continue
		# get_overlapping_bodies() is only refreshed once per physics step, so right
		# after a respawn teleport it can still list the player. Confirm with the
		# actual rectangles at their current positions before killing.
		if not get_hitbox_global_rect().intersects(touched_player.get_hitbox_rect()):
			continue
		# dot() > 0 means "moving in the direction the tips point" = safe.
		if touched_player.velocity.dot(get_tip_direction()) <= 0.0:
			touched_player.die()


## The deadly area in world coordinates.
func get_hitbox_global_rect() -> Rect2:
	return Rect2(global_position + hitbox_local_rect.position, hitbox_local_rect.size)


## Unit vector the tips point toward (Godot 2D: +y is down).
func get_tip_direction() -> Vector2:
	match facing:
		Facing.UP:
			return Vector2.UP
		Facing.DOWN:
			return Vector2.DOWN
		Facing.LEFT:
			return Vector2.LEFT
		_:
			return Vector2.RIGHT


## Deletes the old triangles/hitbox and builds new ones for the current settings.
func _rebuild() -> void:
	if not is_inside_tree():
		return  # setters also run while the scene loads; _ready() rebuilds after that
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	# The rocky base along the whole strip: stone sunk into the surface (fills the dents
	# in the terrain's edge) and a lip above it with a lit top edge, joining the teeth.
	var length: float = tile_count * TILE_SIZE
	_add_quad_polygon(STONE_COLOR, -BASE_SINK, BASE_LIP, 0.0, length)
	_add_quad_polygon(STONE_LIGHT_COLOR, BASE_LIP - 1.0, BASE_LIP, 0.0, length)  # the lip catches light

	# Teeth: slim triangles side by side, each stone with a lighter left facet and a
	# red tip, their heights varying a little along the strip.
	var tooth_pitch: float = TILE_SIZE / TEETH_PER_TILE
	var tooth_width: float = tooth_pitch - 2.0 * TOOTH_INSET
	# The height pattern is counted from the room's grid, not the strip's start, so
	# cutting a strip in two (the editor erases spikes tile by tile) or growing it
	# leaves every remaining tooth exactly as it was.
	var first_cell: int = roundi((position.x if facing == Facing.UP or facing == Facing.DOWN else position.y) / TILE_SIZE)
	for tooth_index: int in tile_count * TEETH_PER_TILE:
		var tooth_start: float = tooth_index * tooth_pitch + TOOTH_INSET
		var tooth_middle: float = tooth_start + tooth_width / 2.0
		var pattern_index: int = posmod(first_cell * TEETH_PER_TILE + tooth_index, SPIKE_HEIGHTS.size())
		var tooth_height: float = SPIKE_HEIGHTS[pattern_index]
		_add_triangle(STONE_COLOR, tooth_start, tooth_start + tooth_width, BASE_LIP, tooth_middle, tooth_height)
		_add_triangle(STONE_LIGHT_COLOR, tooth_start, tooth_middle, BASE_LIP, tooth_middle, tooth_height)
		var tip_start: float = roundf(tooth_height * RED_TIP_START)  # whole pixels: crisp, same every time
		var tip_inset: float = tooth_width / 2.0 * (tip_start / tooth_height)
		_add_triangle(SPIKE_COLOR, tooth_start + tip_inset, tooth_start + tooth_width - tip_inset,
			tip_start, tooth_middle, tooth_height)

	# One rectangular hitbox for the whole strip.
	var corner_a: Vector2 = _to_local_point(HITBOX_END_INSET, 0.0)
	var corner_b: Vector2 = _to_local_point(tile_count * TILE_SIZE - HITBOX_END_INSET, HITBOX_HEIGHT)
	hitbox_local_rect = Rect2(corner_a, Vector2.ZERO).expand(corner_b)
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = hitbox_local_rect.size
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = rectangle
	hitbox.position = hitbox_local_rect.get_center()
	add_child(hitbox)


## A rectangle in strip coordinates: from `height_a` to `height_b` above the surface,
## from `along_a` to `along_b` along it.
func _add_quad_polygon(color: Color, height_a: float, height_b: float, along_a: float, along_b: float) -> void:
	var quad: Polygon2D = Polygon2D.new()
	quad.color = color
	quad.polygon = PackedVector2Array([
		_to_local_point(along_a, height_a), _to_local_point(along_b, height_a),
		_to_local_point(along_b, height_b), _to_local_point(along_a, height_b),
	])
	add_child(quad)


## One triangle in strip coordinates: base from `along_a` to `along_b` at `base_height`,
## tip at (`tip_along`, `tip_height`).
func _add_triangle(color: Color, along_a: float, along_b: float, base_height: float,
		tip_along: float, tip_height: float) -> void:
	var triangle: Polygon2D = Polygon2D.new()
	triangle.color = color
	triangle.polygon = PackedVector2Array([
		_to_local_point(along_a, base_height),
		_to_local_point(along_b, base_height),
		_to_local_point(tip_along, tip_height),
	])
	add_child(triangle)


## Converts "strip coordinates" to this node's local pixels:
##   along  = distance along the strip (0 .. tile_count * 8)
##   height = distance from the mounting surface toward the tips (0 .. 8)
## Writing the shapes once in strip coordinates and converting per facing avoids
## four copies of the geometry code.
func _to_local_point(along: float, height: float) -> Vector2:
	match facing:
		Facing.UP:     # base on the bottom edge of the cell (sitting on a floor)
			return Vector2(along, TILE_SIZE - height)
		Facing.DOWN:   # base on the top edge (hanging from a ceiling)
			return Vector2(along, height)
		Facing.LEFT:   # base on the right edge (stuck to a wall on the right)
			return Vector2(TILE_SIZE - height, along)
		_:             # RIGHT: base on the left edge (stuck to a wall on the left)
			return Vector2(height, along)

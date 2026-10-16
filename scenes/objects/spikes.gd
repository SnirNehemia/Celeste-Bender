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
## One tile, in pixels.
const TILE_SIZE: float = 8.0
## Drawn height of each triangle, measured from its base.
const SPIKE_HEIGHT: float = 5.0
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

	# Triangles, one per tile: base corners on the mounting surface, tip pointing out.
	for tile_index: int in tile_count:
		var base_start: float = tile_index * TILE_SIZE
		var triangle: Polygon2D = Polygon2D.new()
		triangle.color = SPIKE_COLOR
		triangle.polygon = PackedVector2Array([
			_to_local_point(base_start, 0.0),
			_to_local_point(base_start + TILE_SIZE, 0.0),
			_to_local_point(base_start + TILE_SIZE / 2.0, SPIKE_HEIGHT),
		])
		add_child(triangle)

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

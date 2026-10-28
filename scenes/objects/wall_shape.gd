@tool
class_name WallShape
extends RefCounted
## WallShape: the shared shape code of the breakable walls (CrackedWall, StoneWall).
##
## A wall is a set of whole tiles. It used to be one rectangle (`wall_size_tiles`);
## since walls became terrain brushes in the level editor (WallLayer), a wall is any
## connected shape of painted cells (`wall_cells`). A rectangle wall placed by the
## build scripts is still just its rectangle of cells, so both kinds share this code:
##   - get_cells(): the wall's cells, from either form
##   - get_rectangles(): the cells cut into a few rectangles (row runs stacked into
##     blocks), for the hitboxes and for drawing (a rectangle wall is ONE rectangle,
##     so it looks exactly as before)
##   - make_hitboxes(): one CollisionShape2D per rectangle
##   - is_open_side(): for outlines drawn only where the wall meets air
##   - reveal_chambers_next_to(): a broken wall opens the hidden chambers it touched,
##     with an earthquake (HiddenLayer.reveal_chamber with is_quake on)

const TILE_SIZE: int = 8
## The four ways out of a cell.
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## The wall's cells (tiles, relative to its origin): `wall_cells` if it has any,
## else every cell of the `size_tiles` rectangle.
static func get_cells(wall_cells: Array[Vector2i], size_tiles: Vector2i) -> Array[Vector2i]:
	if not wall_cells.is_empty():
		return wall_cells
	var cells: Array[Vector2i] = []
	for row: int in size_tiles.y:
		for column: int in size_tiles.x:
			cells.append(Vector2i(column, row))
	return cells


## `cells` cut into rectangles: each row's runs of cells, then a run stacked onto the
## block above it when that block spans exactly the same columns. Greedy, not the
## fewest possible, but a rectangle stays one rectangle and an L is two.
static func get_rectangles(cells: Array[Vector2i]) -> Array[Rect2i]:
	var cell_set: Dictionary = {}
	for cell: Vector2i in cells:
		cell_set[cell] = true
	var sorted_cells: Array[Vector2i] = cells.duplicate()
	# Row by row, left to right (like reading), so runs come out whole.
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var rectangles: Array[Rect2i] = []
	# The block each run can extend: its columns (x, width) -> index in rectangles,
	# only for blocks whose bottom row is the row just above.
	var open_blocks: Dictionary = {}
	var row: int = -2147483648
	var next_open_blocks: Dictionary = {}
	var index: int = 0
	while index < sorted_cells.size():
		var start: Vector2i = sorted_cells[index]
		if start.y != row:
			open_blocks = next_open_blocks if start.y == row + 1 else {}
			next_open_blocks = {}
			row = start.y
		var width: int = 1
		while cell_set.has(start + Vector2i(width, 0)):
			width += 1
		var key: Vector2i = Vector2i(start.x, width)
		if open_blocks.has(key):
			var block_index: int = open_blocks[key]
			# Rect2i is a value: change a copy, then store it back.
			var block: Rect2i = rectangles[block_index]
			block.size.y += 1
			rectangles[block_index] = block
			next_open_blocks[key] = block_index
		else:
			rectangles.append(Rect2i(start, Vector2i(width, 1)))
			next_open_blocks[key] = rectangles.size() - 1
		index += width
	return rectangles


## One CollisionShape2D per rectangle, added to `body` (the old shapes go first).
## Returns them.
static func make_hitboxes(body: CollisionObject2D, rectangles: Array[Rect2i]) -> Array[CollisionShape2D]:
	for child: Node in body.get_children():
		if child is CollisionShape2D:
			body.remove_child(child)
			child.queue_free()
	var hitboxes: Array[CollisionShape2D] = []
	for rectangle: Rect2i in rectangles:
		var hitbox: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(rectangle.size * TILE_SIZE)
		hitbox.shape = shape
		# A shape is positioned by its center.
		hitbox.position = Vector2(rectangle.position * TILE_SIZE) + shape.size / 2.0
		body.add_child(hitbox)
		hitboxes.append(hitbox)
	return hitboxes


## True if `cell`'s side facing `side` is on the wall's edge (no wall cell there).
static func is_open_side(cell_set: Dictionary, cell: Vector2i, side: Vector2i) -> bool:
	return not cell_set.has(cell + side)


## The bounding rectangle of `cells`, in tiles.
static func get_bounds(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var bounds: Rect2i = Rect2i(cells[0], Vector2i.ONE)
	for cell: Vector2i in cells:
		bounds = bounds.expand(cell).expand(cell + Vector2i.ONE)
	return bounds


## The wall `wall` (its `cells`, relative to its origin) just broke: every covered
## hidden chamber of its room touching one of those cells opens, with a quake.
static func reveal_chambers_next_to(wall: Node2D, cells: Array[Vector2i]) -> void:
	var room: Room = Room.find_room_of(wall)
	if room == null:
		return
	var hidden_layer: HiddenLayer = room.get_node_or_null("Hidden") as HiddenLayer
	if hidden_layer == null:
		return
	for cell: Vector2i in cells:
		var center: Vector2 = wall.to_global((Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE)
		var hidden_cell: Vector2i = hidden_layer.local_to_map(hidden_layer.to_local(center))
		for side: Vector2i in SIDES:
			if hidden_layer.is_covered(hidden_cell + side):
				hidden_layer.reveal_chamber(hidden_cell + side, true)

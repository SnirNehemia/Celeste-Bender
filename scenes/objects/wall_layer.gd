class_name WallLayer
extends TileMapLayer
## WallLayer: breakable walls painted as terrain (after Stage W2, Level_editor.md §6).
## The level editor's Cracked wall and Stone wall brushes paint the room's
## "CrackedWalls" / "StoneWalls" layer (CrackedWallLayer, StoneWallLayer: this script
## with the wall scene each one makes).
##
## The tiles are only the wall's SHAPE: each connected group of painted cells (4-way)
## becomes one wall node (a CrackedWall or StoneWall with `wall_cells` set), made in
## _ready() as a child that is never saved (owner null). That node is what collides,
## draws itself, and breaks all at once, exactly like a wall placed as an object, so
## Boulder, ThicketElephant and the room resets need nothing new. The layer's own
## tiles neither collide nor show.
##
## In the level editor the same walls are built, so you see them as in play; RoomLook
## calls build_walls() again after each change to the tiles.

## Groups of painted cells become walls of this scene (set by the subclass).
func get_wall_scene() -> PackedScene:
	return null


func _ready() -> void:
	# The wall nodes collide and draw; the tiles are only their shape.
	collision_enabled = false
	build_walls()


## Throws the old wall nodes away and makes one per connected group of cells.
func build_walls() -> void:
	self_modulate = Color.TRANSPARENT
	for child: Node in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()
	var scene: PackedScene = get_wall_scene()
	if scene == null:
		return
	var grouped: Dictionary = {}
	for start: Vector2i in get_used_cells():
		if grouped.has(start):
			continue
		# One wall: the cells connected to `start` (breadth-first flood fill).
		var cells: Array[Vector2i] = [start]
		grouped[start] = true
		var index: int = 0
		while index < cells.size():
			var cell: Vector2i = cells[index]
			index += 1
			for side: Vector2i in WallShape.SIDES:
				var neighbour: Vector2i = cell + side
				if not grouped.has(neighbour) and get_cell_source_id(neighbour) != -1:
					grouped[neighbour] = true
					cells.append(neighbour)
		_add_wall(scene, cells)


## A wall node for the group `cells` (layer cells): its origin on the group's
## top-left corner, its cells relative to that.
func _add_wall(scene: PackedScene, cells: Array[Vector2i]) -> void:
	var corner: Vector2i = WallShape.get_bounds(cells).position
	var relative_cells: Array[Vector2i] = []
	for cell: Vector2i in cells:
		relative_cells.append(cell - corner)
	var wall: Node2D = scene.instantiate() as Node2D
	wall.set(&"wall_cells", relative_cells)
	wall.position = Vector2(corner * WallShape.TILE_SIZE)
	wall.name = "Wall%d_%d" % [corner.x, corner.y]
	add_child(wall)
	# The wall draws itself, so the layer's see-through self_modulate (which only
	# tints the layer itself) doesn't hide it.


## The wall node holding layer cell `cell`, or null (tests).
func get_wall_at(cell: Vector2i) -> Node2D:
	for child: Node in get_children():
		var wall: Node2D = child as Node2D
		if wall != null and child.owner == null:
			var cells: Array[Vector2i] = wall.call(&"get_cells")
			if cells.has(cell - Vector2i(wall.position / WallShape.TILE_SIZE)):
				return wall
	return null

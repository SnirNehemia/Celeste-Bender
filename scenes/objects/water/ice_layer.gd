class_name IceLayer
extends TileMapLayer
## IceLayer (Stage W5, Water_bending.md §7.1, §13): ice PAINTED into a level. A
## TileMapLayer named "Ice", painted with resources/tiles/ice_tileset.tres: one pale
## cyan tile, solid on physics layer 1 ("world") like rock.
##
## It's ground you slide on: the player treats anything in IceBlock.ICE_GROUP as ice
## (slow to start and stop, long jumps; no grip on its walls), and this layer joins
## that group. Painted ice is part of the level: it never melts, and it doesn't count
## toward the ice cap (only ice the freeze makes does, WaterWorld.player_ice).
##
## THE LOOK (play-test 5: "the terrain ice is still in the older design"): it's drawn
## like the ice the freeze makes, glass (IceLook), not as tiles. The tiles stay for
## collision and for the level editor's data, but are hidden (self_modulate); a child
## node draws each connected patch of ice as one outline, with icicles under its edges
## that hang over open air (not over rock). The outline is the patch's boundary on the
## tile grid (_trace_patches); it's rebuilt when the tiles change (the editor paints).
##
## The tileset is made by tools/build_water_rooms.gd (only when missing).

const TILESET_PATH: String = "res://resources/tiles/ice_tileset.tres"
## The single tile of the ice tileset.
const ICE_TILE: Vector2i = Vector2i(0, 0)

## Draws the glass look (a child: the layer's own drawing is its hidden tiles).
var look_node: Node2D
var look: IceLook
var is_rebuild_queued: bool = false


func _ready() -> void:
	add_to_group(IceBlock.ICE_GROUP)
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)  # hide the tiles; children still draw
	look_node = Node2D.new()
	look_node.name = "IceLook"
	look_node.material = IceLook.get_material()
	look_node.draw.connect(_draw_look)
	add_child(look_node)
	changed.connect(_queue_rebuild)
	_rebuild()


func _queue_rebuild() -> void:
	if is_rebuild_queued:
		return
	is_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	is_rebuild_queued = false
	look = IceLook.build(_trace_patches(), true, _is_open_below)
	look_node.queue_redraw()


func _draw_look() -> void:
	if look != null:
		look.draw(look_node)


## The outline of every connected patch of painted ice (local px): the boundary edges
## of its tiles (the sides with no ice tile next to them), each walked clockwise
## around its tile, linked end to start into closed loops. Loops that wind the other
## way are holes, left out (a hole in painted ice draws filled; collision is right).
func _trace_patches() -> Array[PackedVector2Array]:
	var size: Vector2 = Vector2(tile_set.tile_size)
	var used: Dictionary = {}
	for cell: Vector2i in get_used_cells():
		used[cell] = true
	# Corner -> the corners the boundary goes on to from there.
	var next_corners: Dictionary = {}
	for cell: Vector2i in used:
		var top_left: Vector2i = cell
		var top_right: Vector2i = cell + Vector2i(1, 0)
		var bottom_right: Vector2i = cell + Vector2i(1, 1)
		var bottom_left: Vector2i = cell + Vector2i(0, 1)
		if not used.has(cell + Vector2i.UP):
			_add_edge(next_corners, top_left, top_right)
		if not used.has(cell + Vector2i.RIGHT):
			_add_edge(next_corners, top_right, bottom_right)
		if not used.has(cell + Vector2i.DOWN):
			_add_edge(next_corners, bottom_right, bottom_left)
		if not used.has(cell + Vector2i.LEFT):
			_add_edge(next_corners, bottom_left, top_left)
	var loops: Array[PackedVector2Array] = []
	while not next_corners.is_empty():
		var start: Vector2i = next_corners.keys()[0]
		var loop: PackedVector2Array = PackedVector2Array()
		var corner: Vector2i = start
		while next_corners.has(corner):
			var onward: Array = next_corners[corner]
			var next: Vector2i = onward.pop_back()
			if onward.is_empty():
				next_corners.erase(corner)
			loop.append(Vector2(corner) * size)
			corner = next
			if corner == start:
				break
		loop = IceOutline.simplify(loop, 0.01)  # drops the corners along straight runs
		if loop.size() >= 3 and IceOutline.polygon_area(loop) > 0.0:
			loops.append(loop)
	return loops


func _add_edge(next_corners: Dictionary, from: Vector2i, to: Vector2i) -> void:
	if not next_corners.has(from):
		next_corners[from] = []
	(next_corners[from] as Array).append(to)


## An icicle may hang at the local point `root` (on a downward edge) only if the tile
## under it is open air in every tile layer of the room (not over rock or other ground).
func _is_open_below(root: Vector2) -> bool:
	var below: Vector2i = local_to_map(root + Vector2(0.0, 1.0))
	for sibling: Node in get_parent().get_children():
		var layer: TileMapLayer = sibling as TileMapLayer
		if layer != null and not layer is WaterLayer and layer.get_cell_source_id(below) != -1:
			return false
	return true

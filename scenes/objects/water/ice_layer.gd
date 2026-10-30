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
## SLOPES (Stage W7a, from the re-planned ice): besides the full tile, the tileset
## has ice SLOPE tiles, the fixed, learnable slides a level is built around: 45° both
## ways, and 22.5° made of two tiles side by side (a LOW one and a HIGH one). Each
## tile's solid part is a polygon (TILE_SHAPES), used for its collision and for the
## outline. The player and objects slide down them like any ice slope (IceSlope reads
## the slope from the collision's normal) and launch off their lips. Painted slopes
## are fully solid (not one-way: that's only the player's own slides).
##
## The tileset is made by tools/build_water_rooms.gd (when missing or out of date).

const TILESET_PATH: String = "res://resources/tiles/ice_tileset.tres"
## The full (square) ice tile.
const ICE_TILE: Vector2i = Vector2i(0, 0)
## 45° slopes: rising to the right (◢) and to the left (◣).
const SLOPE_UP_RIGHT: Vector2i = Vector2i(1, 0)
const SLOPE_UP_LEFT: Vector2i = Vector2i(2, 0)
## 22.5° slopes, two tiles each: rising to the right, the LOW tile then the HIGH one;
## rising to the left, the HIGH tile then the LOW one.
const GENTLE_UP_RIGHT_LOW: Vector2i = Vector2i(3, 0)
const GENTLE_UP_RIGHT_HIGH: Vector2i = Vector2i(4, 0)
const GENTLE_UP_LEFT_HIGH: Vector2i = Vector2i(5, 0)
const GENTLE_UP_LEFT_LOW: Vector2i = Vector2i(6, 0)
## The solid part of each tile, px from its top-left corner (y down), walked
## clockwise on screen like every ice outline. Every corner is on a 4 px grid, which
## is what lets the outline tracer cancel the edges two tiles share.
const TILE_SHAPES: Dictionary = {
	ICE_TILE: [Vector2(0, 0), Vector2(8, 0), Vector2(8, 8), Vector2(0, 8)],
	SLOPE_UP_RIGHT: [Vector2(8, 0), Vector2(8, 8), Vector2(0, 8)],
	SLOPE_UP_LEFT: [Vector2(0, 0), Vector2(8, 8), Vector2(0, 8)],
	GENTLE_UP_RIGHT_LOW: [Vector2(8, 4), Vector2(8, 8), Vector2(0, 8)],
	GENTLE_UP_RIGHT_HIGH: [Vector2(0, 4), Vector2(8, 0), Vector2(8, 8), Vector2(0, 8)],
	GENTLE_UP_LEFT_HIGH: [Vector2(0, 0), Vector2(8, 4), Vector2(8, 8), Vector2(0, 8)],
	GENTLE_UP_LEFT_LOW: [Vector2(0, 4), Vector2(8, 8), Vector2(0, 8)],
}
## The outline tracer splits straight edges into pieces this long (px), so a full
## tile's side and a half-height slope's side cancel where they touch.
const EDGE_PIECE: int = 4


## The solid polygon of the tile at `atlas` (TILE_SHAPES; the full tile for any other).
static func get_tile_shape(atlas: Vector2i) -> PackedVector2Array:
	return PackedVector2Array(TILE_SHAPES.get(atlas, TILE_SHAPES[ICE_TILE]))

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


## The outline of every connected patch of painted ice (local px). Every tile's
## polygon (TILE_SHAPES) is walked clockwise as EDGES (straight ones cut into
## EDGE_PIECE px pieces); an edge two tiles share is walked once each way, so the
## pair cancels and only the patch's boundary is left. Those edges are linked end to
## start into closed loops. Loops that wind the other way are holes, left out (a
## hole in painted ice draws filled; collision is right).
func _trace_patches() -> Array[PackedVector2Array]:
	var tile_px: Vector2i = tile_set.tile_size
	# Every boundary edge as Vector4i(from.x, from.y, to.x, to.y), in whole px.
	var edges: Dictionary = {}
	for cell: Vector2i in get_used_cells():
		var shape: PackedVector2Array = get_tile_shape(get_cell_atlas_coords(cell))
		var origin: Vector2i = cell * tile_px
		for index: int in shape.size():
			var from: Vector2i = origin + Vector2i(shape[index])
			var to: Vector2i = origin + Vector2i(shape[(index + 1) % shape.size()])
			var pieces: int = 1
			if from.x == to.x or from.y == to.y:
				pieces = maxi(1, floori((absi(to.x - from.x) + absi(to.y - from.y)) / float(EDGE_PIECE)))
			for piece: int in pieces:
				var piece_from: Vector2i = from + Vector2i((Vector2(to - from) * piece / pieces).round())
				var piece_to: Vector2i = from + Vector2i((Vector2(to - from) * (piece + 1) / pieces).round())
				var reverse: Vector4i = Vector4i(piece_to.x, piece_to.y, piece_from.x, piece_from.y)
				if edges.has(reverse):
					edges.erase(reverse)  # shared with the tile next door: inside the patch
				else:
					edges[Vector4i(piece_from.x, piece_from.y, piece_to.x, piece_to.y)] = true
	# Corner -> the corners the boundary goes on to from there.
	var next_corners: Dictionary = {}
	for edge: Vector4i in edges:
		_add_edge(next_corners, Vector2i(edge.x, edge.y), Vector2i(edge.z, edge.w))
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
			loop.append(Vector2(corner))
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

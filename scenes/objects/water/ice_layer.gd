class_name IceLayer
extends TileMapLayer
## IceLayer (Stage W5, Water_bending.md §7.1, §13): ice PAINTED into a level. A
## TileMapLayer named "Ice", painted with resources/tiles/ice_tileset.tres: one pale
## cyan tile, solid on physics layer 1 ("world") like rock.
##
## It's ground you slide on: the player treats anything in ICE_GROUP as ice (slow to
## start and stop, speed above run speed kept, long jumps; no grip on its walls), and
## this layer joins that group. Painted ice is part of the level: it never melts, and
## it doesn't count toward the ice cap. Ice the FREEZE makes (grid ice, Stages I1-I5)
## is the same tiles in the room's PlayerIceLayer (player_ice_layer.gd, a subclass).
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
## Everything the player (and crates, shells) treat as ice: both ice layers and rafts
## (Player.is_ice, IceSlope).
const ICE_GROUP: StringName = &"ice"
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


## Each slope tile and its left-right mirror image (the level editor's mirrored
## paste). A rising-right LOW tile mirrors to a rising-left LOW one, and so on.
const MIRRORED_TILES: Dictionary = {
	SLOPE_UP_RIGHT: SLOPE_UP_LEFT, SLOPE_UP_LEFT: SLOPE_UP_RIGHT,
	GENTLE_UP_RIGHT_LOW: GENTLE_UP_LEFT_LOW, GENTLE_UP_LEFT_LOW: GENTLE_UP_RIGHT_LOW,
	GENTLE_UP_RIGHT_HIGH: GENTLE_UP_LEFT_HIGH, GENTLE_UP_LEFT_HIGH: GENTLE_UP_RIGHT_HIGH,
}


## The tile at `atlas` seen in a mirror (the same tile for the full one).
static func get_mirrored_tile(atlas: Vector2i) -> Vector2i:
	return MIRRORED_TILES.get(atlas, atlas)


## The solid polygon of the tile at `atlas` (TILE_SHAPES; the full tile for any other).
static func get_tile_shape(atlas: Vector2i) -> PackedVector2Array:
	return PackedVector2Array(TILE_SHAPES.get(atlas, TILE_SHAPES[ICE_TILE]))

## Draws the glass look (a child: the layer's own drawing is its hidden tiles).
var look_node: Node2D
var look: IceLook
var is_rebuild_queued: bool = false


func _ready() -> void:
	add_to_group(ICE_GROUP)
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


## The outline of every connected patch of painted ice (local px): _trace_cells over
## every tile of the layer.
func _trace_patches() -> Array[PackedVector2Array]:
	return _trace_cells(get_used_cells())


## The outline of the ice in `cells` (local px). Every tile's polygon (TILE_SHAPES) is
## walked clockwise as EDGES (straight ones cut into EDGE_PIECE px pieces); an edge
## two tiles share is walked once each way, so the pair cancels and only the patch's
## boundary is left. Those edges are linked end to start into closed loops. Loops
## that wind the other way are holes, left out (a hole in ice draws filled;
## collision is right).
func _trace_cells(cells: Array[Vector2i]) -> Array[PackedVector2Array]:
	var atlases: Array[Vector2i] = []
	for cell: Vector2i in cells:
		atlases.append(get_cell_atlas_coords(cell))
	return trace_tiles(cells, atlases, tile_set.tile_size)


## _trace_cells for tiles that aren't in a layer: `cells` with the tile shapes
## `atlases` (same order), `tile_px` a tile. The ice ghost (WaterHandsAbility) draws
## an ice plan's outline with it.
static func trace_tiles(cells: Array[Vector2i], atlases: Array[Vector2i], tile_px: Vector2i) -> Array[PackedVector2Array]:
	# Every boundary edge as Vector4i(from.x, from.y, to.x, to.y), in whole px.
	var edges: Dictionary = {}
	for cell_index: int in cells.size():
		var cell: Vector2i = cells[cell_index]
		var shape: PackedVector2Array = get_tile_shape(atlases[cell_index])
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
		for piece: PackedVector2Array in _split_at_pinches(loop):
			piece = IceOutline.simplify(piece, 0.01)  # drops the corners along straight runs
			if piece.size() >= 3 and IceOutline.polygon_area(piece) > 0.0:
				loops.append(piece)
	return loops


## A loop that passes through the same corner twice (two parts of the ice meeting
## only at that corner: a snake that turns back on itself) cut there into simple
## loops. Godot can't fill a polygon that touches itself (draw_colored_polygon draws
## nothing), so such ice showed only its rim and bands, hollow (after the grid-ice
## play-test; 1 snake shape in 9 did it). Each repeat closes off the stretch since the
## corner's first visit as its own loop.
static func _split_at_pinches(loop: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	var stack: PackedVector2Array = PackedVector2Array()
	var index_in_stack: Dictionary = {}  # corner -> its index in stack
	for point: Vector2 in loop:
		if index_in_stack.has(point):
			var first: int = index_in_stack[point]
			var piece: PackedVector2Array = stack.slice(first)
			for cut_point: Vector2 in piece:
				index_in_stack.erase(cut_point)
			pieces.append(piece)
			stack = stack.slice(0, first)
		index_in_stack[point] = stack.size()
		stack.append(point)
	pieces.append(stack)
	return pieces


static func _add_edge(next_corners: Dictionary, from: Vector2i, to: Vector2i) -> void:
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

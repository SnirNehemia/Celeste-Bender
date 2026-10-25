class_name TileBrush
extends RefCounted
## TileBrush: paints and erases one terrain layer of a room, and records each
## stroke so it can be undone (Level_editor.md §4 and §6).
##
## One brush per terrain entry of the palette catalog: Ground (the room's "Tiles"
## TileMapLayer with the placeholder tileset, the layer every room has) since
## Stage L2, Earth (an "Earth" layer with the EarthLayer script) since Stage L8.
## A layer the room doesn't have yet is made by the first stroke, with the
## entry's tileset and script.
##
## Edges: a tileset may have two tiles, plain and "top edge" (the placeholder's
## light line on top = a surface you can stand on). The brush picks one itself: a
## cell gets the top edge when the cell above it is empty. Painting or erasing a
## cell can change the cell below too, so the brush updates both. A tileset with
## one tile (earth: the GroundPainter draws the surfaces) gives the same atlas
## cell for both, and there's nothing to pick.
##
## A stroke (one press-drag-release, or one rectangle) works like this:
##   begin_stroke(layer)  ->  paint_cell() / erase_cell() many times  ->  end_stroke()
## Before a cell first changes, its old value goes into `stroke_before`.
## end_stroke() returns {cell: old value} and {cell: new value} for the cells that
## really changed; LevelEditor turns those into one undo step (set_cells both ways).
##
## A cell value is a Vector3i(source id, atlas x, atlas y); source -1 = empty.

const EMPTY: Vector3i = Vector3i(-1, -1, -1)
## The atlas source the brush paints from.
const SOURCE_ID: int = 0
## The Ground brush's tiles, the defaults: placeholder tileset atlas cells (same as
## tools/build_rooms.gd), plain and with a top edge.
const TILE_PLAIN: Vector2i = Vector2i(0, 0)
const TILE_TOP_EDGE: Vector2i = Vector2i(1, 0)

## Name of the layer node inside a room, and the tileset and script a new layer gets.
var layer_name: StringName
var tile_set: TileSet
var layer_script: Script
## The atlas cells it paints: a plain tile and one with a top edge (may be the same).
var tile_plain: Vector2i
var tile_top_edge: Vector2i

## The layer the current stroke paints on (null between strokes).
var stroke_layer: TileMapLayer = null
## Old values of every cell the current stroke touched, recorded before the first change.
var stroke_before: Dictionary = {}


## The defaults are the Ground brush's: no layer script, the placeholder tiles.
func _init(new_layer_name: StringName, new_tile_set: TileSet, new_layer_script: Script = null,
		new_tile_plain: Vector2i = TILE_PLAIN, new_tile_top_edge: Vector2i = TILE_TOP_EDGE) -> void:
	layer_name = new_layer_name
	tile_set = new_tile_set
	layer_script = new_layer_script
	tile_plain = new_tile_plain
	tile_top_edge = new_tile_top_edge


## The room's layer for this brush. With `create`, makes it if missing (owned by
## `level_root`, so it's saved, and drawn first, behind the room's objects).
func get_layer(room: Room, level_root: Node, create: bool) -> TileMapLayer:
	var layer: TileMapLayer = room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
	if layer == null and create:
		layer = TileMapLayer.new()
		layer.name = layer_name
		if layer_script != null:
			layer.set_script(layer_script)  # before it enters the tree: its _ready runs
		layer.tile_set = tile_set
		room.add_child(layer)
		room.move_child(layer, 0)
		# Only the layer itself is saved: the children its _ready() just built (a
		# grass layer's blades, a thicket's leaves) are rebuilt on every load.
		layer.owner = level_root
	return layer


func begin_stroke(layer: TileMapLayer) -> void:
	stroke_layer = layer
	stroke_before = {}


func paint_cell(cell: Vector2i) -> void:
	if _read(stroke_layer, cell) != EMPTY:
		return  # already ground: nothing to do (its edge is already right)
	_write(cell, Vector3i(SOURCE_ID, tile_plain.x, tile_plain.y))
	_refresh_edge(cell)
	_refresh_edge(cell + Vector2i.DOWN)  # it just got covered


func erase_cell(cell: Vector2i) -> void:
	if _read(stroke_layer, cell) == EMPTY:
		return
	_write(cell, EMPTY)
	_refresh_edge(cell + Vector2i.DOWN)  # it's now a surface


## Ends the stroke. Returns {"before": {cell: value}, "after": {cell: value}} for
## the cells that changed, or an empty Dictionary if nothing did.
func end_stroke() -> Dictionary:
	var before: Dictionary = {}
	var after: Dictionary = {}
	for cell: Vector2i in stroke_before:
		var new_value: Vector3i = _read(stroke_layer, cell)
		if new_value != stroke_before[cell]:
			before[cell] = stroke_before[cell]
			after[cell] = new_value
	stroke_layer = null
	stroke_before = {}
	if before.is_empty():
		return {}
	return {"before": before, "after": after}


## Sets every cell in `values` ({cell: value}) on `layer`. Undo and redo call this.
func set_cells(layer: TileMapLayer, values: Dictionary) -> void:
	for cell: Vector2i in values:
		_set_value(layer, cell, values[cell])


## A cell's value on `layer`.
static func read_cell(layer: TileMapLayer, cell: Vector2i) -> Vector3i:
	return _read(layer, cell)


## Gives a ground cell the top edge if nothing is above it, the plain tile if
## something is. Empty cells and other kinds of tiles are left alone.
func _refresh_edge(cell: Vector2i) -> void:
	var value: Vector3i = _read(stroke_layer, cell)
	var atlas: Vector2i = Vector2i(value.y, value.z)
	if tile_plain == tile_top_edge or value.x != SOURCE_ID or not (atlas == tile_plain or atlas == tile_top_edge):
		return
	var is_surface: bool = _read(stroke_layer, cell + Vector2i.UP) == EMPTY
	var wanted: Vector2i = tile_top_edge if is_surface else tile_plain
	if wanted != atlas:
		_write(cell, Vector3i(SOURCE_ID, wanted.x, wanted.y))


## Changes a cell during a stroke, recording its old value the first time.
func _write(cell: Vector2i, value: Vector3i) -> void:
	if not stroke_before.has(cell):
		stroke_before[cell] = _read(stroke_layer, cell)
	_set_value(stroke_layer, cell, value)


static func _read(layer: TileMapLayer, cell: Vector2i) -> Vector3i:
	var source_id: int = layer.get_cell_source_id(cell)
	if source_id == -1:
		return EMPTY
	var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
	return Vector3i(source_id, atlas.x, atlas.y)


static func _set_value(layer: TileMapLayer, cell: Vector2i, value: Vector3i) -> void:
	if value.x == -1:
		layer.erase_cell(cell)
	else:
		layer.set_cell(cell, value.x, Vector2i(value.y, value.z))

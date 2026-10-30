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
## cell for both, and there's nothing to pick. For a room's top row, "the cell
## above" is in the room above (outside_reader, set by LevelEditor).
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
## "No tile": a brush's tile_odd_column when it paints the same tile everywhere.
const NO_TILE: Vector2i = Vector2i(-1, -1)

## Name of the layer node inside a room, and the tileset and script a new layer gets.
var layer_name: StringName
var tile_set: TileSet
var layer_script: Script
## The atlas cells it paints: a plain tile and one with a top edge (may be the same).
var tile_plain: Vector2i
var tile_top_edge: Vector2i
## Painted on odd columns instead of tile_plain, or NO_TILE (Stage W7a: a 22.5° ice
## slope is a low tile and a high tile side by side).
var tile_odd_column: Vector2i = NO_TILE

## The layer the current stroke paints on (null between strokes).
var stroke_layer: TileMapLayer = null
## Old values of every cell the current stroke touched, recorded before the first change.
var stroke_before: Dictionary = {}
## Rooms side by side (strokes cross them): the cells inside the layer's room, and
## func(cell) -> value that reads the same layer in the room above, for a cell just
## outside the top. Unset (invalid Callable) = everything outside counts as empty.
var room_cells: Rect2i = Rect2i()
var outside_reader: Callable = Callable()


## The defaults are the Ground brush's: no layer script, the placeholder tiles.
func _init(new_layer_name: StringName, new_tile_set: TileSet, new_layer_script: Script = null,
		new_tile_plain: Vector2i = TILE_PLAIN, new_tile_top_edge: Vector2i = TILE_TOP_EDGE,
		new_tile_odd_column: Vector2i = NO_TILE) -> void:
	layer_name = new_layer_name
	tile_set = new_tile_set
	layer_script = new_layer_script
	tile_plain = new_tile_plain
	tile_top_edge = new_tile_top_edge
	tile_odd_column = new_tile_odd_column


## A new brush painting the same tiles, with no stroke going: a stroke over
## several rooms has one brush per layer it touches.
func make_twin() -> TileBrush:
	return TileBrush.new(layer_name, tile_set, layer_script, tile_plain, tile_top_edge, tile_odd_column)


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
	var tile: Vector2i = tile_plain
	if tile_odd_column != NO_TILE and posmod(cell.x, 2) == 1:
		tile = tile_odd_column
	var old_value: Vector3i = _read(stroke_layer, cell)
	if old_value.x == SOURCE_ID and (Vector2i(old_value.y, old_value.z) == tile or Vector2i(old_value.y, old_value.z) == tile_top_edge):
		return  # already this terrain: nothing to do (its edge is already right)
	# Another brush's tile on the same layer (the other cover look) is replaced.
	_write(cell, Vector3i(SOURCE_ID, tile.x, tile.y))
	_refresh_edge(cell)
	_refresh_edge(cell + Vector2i.DOWN)  # it just got covered


func erase_cell(cell: Vector2i) -> void:
	if _read(stroke_layer, cell) == EMPTY:
		return
	_write(cell, EMPTY)
	_refresh_edge(cell + Vector2i.DOWN)  # it's now a surface


## Sets `cell` to exactly `value` (a pasted tile), then fixes the top edges of it
## and of the cell below, as painting would.
func write_value(cell: Vector2i, value: Vector3i) -> void:
	if _read(stroke_layer, cell) != value:
		_write(cell, value)
	_refresh_edge(cell)
	_refresh_edge(cell + Vector2i.DOWN)


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
## something is. Empty cells and other kinds of tiles are left alone. Public: a
## stroke in the room above changes what's above this room's top row.
func refresh_edge(cell: Vector2i) -> void:
	_refresh_edge(cell)


func _refresh_edge(cell: Vector2i) -> void:
	var value: Vector3i = _read(stroke_layer, cell)
	var atlas: Vector2i = Vector2i(value.y, value.z)
	if tile_plain == tile_top_edge or value.x != SOURCE_ID or not (atlas == tile_plain or atlas == tile_top_edge):
		return
	var is_surface: bool = _read_above(cell) == EMPTY
	var wanted: Vector2i = tile_top_edge if is_surface else tile_plain
	if wanted != atlas:
		_write(cell, Vector3i(SOURCE_ID, wanted.x, wanted.y))


## The cell above `cell`: on this layer, or, above the room's top row, in the
## room above (outside_reader), so ground running on up into it gets no edge line.
func _read_above(cell: Vector2i) -> Vector3i:
	var above: Vector2i = cell + Vector2i.UP
	if outside_reader.is_valid() and not room_cells.has_point(above):
		return outside_reader.call(above)
	return _read(stroke_layer, above)


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

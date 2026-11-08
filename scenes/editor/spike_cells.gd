class_name SpikeCells
extends RefCounted
## SpikeCells: lets the level editor treat SPIKES like terrain tiles.
##
## In the game, spikes are still Spikes nodes: strips with a `facing` and a
## `tile_count` (one hitbox per strip; enemies, the shell's look-ahead and saved
## levels all keep working as before). In the editor, though, you paint spike CELLS
## with a brush, fill an area with Shift+drag and erase single cells. This helper is
## the bridge between the two views:
##   - read(): a room's strips -> a map {cell: facing}
##   - to_runs(): a map -> the fewest strips that cover it (runs of neighbouring cells
##     with the same facing: along a row for UP/DOWN, a column for LEFT/RIGHT)
##   - auto_facing(): which way a spike on a cell points, from the ground next to it
## LevelEditor edits the map and then swaps only the strips that changed (undoable),
## so erasing one cell of a 10-tile strip leaves two strips, and painting next to a
## strip grows it into one.
##
## Static functions only: nothing here is a node or keeps state.

## One tile, px (the rooms' grid).
const TILE: int = 8
## "No spike here" in a change map passed to LevelEditor.set_spike_cells().
const NONE: int = -1


## The room-local cells a strip covers.
static func cells_of(spikes: Spikes) -> Array[Vector2i]:
	var first: Vector2i = Vector2i((spikes.position / TILE).floor())
	var step: Vector2i = Vector2i.RIGHT if is_row_facing(spikes.facing) else Vector2i.DOWN
	var cells: Array[Vector2i] = []
	for index: int in spikes.tile_count:
		cells.append(first + step * index)
	return cells


## Spikes pointing up or down lie along a row; left or right, along a column.
static func is_row_facing(facing: int) -> bool:
	return facing == Spikes.Facing.UP or facing == Spikes.Facing.DOWN


## Every spike strip directly in `room`, in child order.
static func strips_of(room: Room) -> Array[Spikes]:
	var strips: Array[Spikes] = []
	for child: Node in room.get_children():
		if child is Spikes:
			strips.append(child as Spikes)
	return strips


## `room`'s spikes as a map {Vector2i cell: Spikes.Facing}. Where two strips overlap
## (only possible from older levels or turning a strip with R), the later one wins.
static func read(room: Room) -> Dictionary:
	var cells: Dictionary = {}
	for strip: Spikes in strips_of(room):
		for cell: Vector2i in cells_of(strip):
			cells[cell] = strip.facing
	return cells


## The fewest strips covering `cells` ({cell: facing}): each is a Dictionary
## {"start": Vector2i, "facing": int, "count": int}. Sorted, so the same map always
## gives the same strips in the same order.
static func to_runs(cells: Dictionary) -> Array[Dictionary]:
	var sorted_cells: Array = cells.keys()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var covered: Dictionary = {}
	var runs: Array[Dictionary] = []
	for cell: Vector2i in sorted_cells:
		if covered.has(cell):
			continue
		var facing: int = cells[cell]
		var step: Vector2i = Vector2i.RIGHT if is_row_facing(facing) else Vector2i.DOWN
		# Sorted top-left first, so the first uncovered cell of a run is its start.
		var count: int = 0
		while cells.get(cell + step * count, NONE) == facing:
			covered[cell + step * count] = true
			count += 1
		runs.append({"start": cell, "facing": facing, "count": count})
	return runs


## A strip's identity for comparing old and new strips: same start, facing, length.
static func run_key(start: Vector2i, facing: int, count: int) -> String:
	return "%d,%d,%d,%d" % [start.x, start.y, facing, count]


static func strip_key(strip: Spikes) -> String:
	return run_key(Vector2i((strip.position / TILE).floor()), strip.facing, strip.tile_count)


## True if `cell` of `room` holds ground spikes can grow out of: any tile layer
## except open-air ones (hidden chambers), storm clouds and water.
static func is_ground(room: Room, cell: Vector2i) -> bool:
	for child: Node in room.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer == null or layer is HiddenLayer or layer is StormCloudLayer or layer is WaterLayer:
			continue
		if layer.get_cell_source_id(cell) != -1:
			return true
	return false


## Which way a spike on `cell` points: away from the ground next to it. Floor below
## -> UP, ceiling above -> DOWN, wall on the left -> RIGHT, wall on the right -> LEFT.
## A cell with ground on two sides (a corner) is settled by `prefer_rows`: true (a
## stroke or area wider than tall) checks floor and ceiling first, false the walls.
## NONE if there's no ground on any side.
static func auto_facing(room: Room, cell: Vector2i, prefer_rows: bool) -> int:
	var row_facing: int = NONE
	if is_ground(room, cell + Vector2i.DOWN):
		row_facing = Spikes.Facing.UP
	elif is_ground(room, cell + Vector2i.UP):
		row_facing = Spikes.Facing.DOWN
	var column_facing: int = NONE
	if is_ground(room, cell + Vector2i.LEFT):
		column_facing = Spikes.Facing.RIGHT
	elif is_ground(room, cell + Vector2i.RIGHT):
		column_facing = Spikes.Facing.LEFT
	if prefer_rows:
		return row_facing if row_facing != NONE else column_facing
	return column_facing if column_facing != NONE else row_facing

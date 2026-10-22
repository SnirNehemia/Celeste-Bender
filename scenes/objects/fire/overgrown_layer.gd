class_name OvergrownLayer
extends GrassLayer
## Overgrown covers (Stage F6, Fire_bending.md §6.1b): plant growth that passes for
## ordinary ground. Each cell looks like grass-topped ground or like a thicket wall,
## and is solid like them, but fire reaching ANY cell of a cover flashes the whole
## connected cover over and burns it away at once, revealing what's behind it: a
## passage, or a hidden chamber (a HiddenLayer, opened by the FireGrid).
##
## Setup: a TileMapLayer child of a Room, named "Overgrown", with this script and
## resources/tiles/thicket_tileset.tres. Paint ThicketLayer.GRASS_LOOK_TILE for a
## cover that looks like grass ground, ThicketLayer.THICKET_TILE for one that looks
## like a thicket wall. tools/build_fire_rooms.gd makes it.
##
## It EXTENDS GrassLayer, so grass-looking cells grow the same swaying blades as real
## grass (no bare top giving the secret away); thicket-looking ones grow none
## (_grows_blades). The GroundPainter draws the cells as grass or thicket, a shade off.
##
## THE TELL: besides that shade, a few root tendrils hang from the cover's undersides
## and poke out of its sides (drawn on the "Roots" child). Small, but there. A cover
## that passes for thicket also grows thicket's bush of leaves (ThicketLeaves), a
## little browner than the real thing (FireTuning.cover_leaf_brownness).
##
## Who does what (like ThicketLayer): the FireGrid owns the fire and the flash-over
## and calls remove_cells() when the cover collapses; this layer erases the tiles and
## puts them back on reset(). The painter repaints on shape_changed.

## Tiles appeared or disappeared (the cover burnt away, or a reset put it back).
signal shape_changed

## Root tendril color: a dry, pale brown, so it reads against green and earth.
const ROOT_COLOR: Color = Color(0.55, 0.42, 0.26)
const ROOT_DARK_COLOR: Color = Color(0.38, 0.28, 0.17)
## Root tendrils hanging under an exposed underside: one in this many cells gets 2,
## the rest 1. Their length, px.
const ROOT_MIN_LENGTH: int = 2
const ROOT_MAX_LENGTH: int = 5

## Cells that burnt away -> [source id, atlas coords], for reset().
var removed_cells: Dictionary = {}
## Child that draws the root tendrils (in front of the ground, like the blades).
var roots_canvas: Node2D


func _ready() -> void:
	super()  # GrassLayer's setup: blades, gust sensors, shadow-passable group
	add_to_group(Room.RESETTABLE_GROUP)
	roots_canvas = Node2D.new()
	roots_canvas.name = "Roots"
	roots_canvas.z_index = 1
	add_child(roots_canvas)
	roots_canvas.draw.connect(_draw_roots)
	# Covers that pass for thicket get thicket's bush of leaves too (no bare
	# giveaway), a little browner: part of the tell.
	var leaves: ThicketLeaves = ThicketLeaves.new()
	leaves.name = "Leaves"
	leaves.layer = self
	leaves.grows_on = is_thicket_look
	leaves.is_cover = true
	add_child(leaves)


## True if `cell` is part of a cover right now (not burnt away).
func has_cover(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) != -1


## True if the cover cell is painted to look like thicket (else it looks like grass).
func is_thicket_look(cell: Vector2i) -> bool:
	return get_cell_atlas_coords(cell) == ThicketLayer.THICKET_TILE


## Only grass-looking cells grow blades.
func _grows_blades(cell: Vector2i) -> bool:
	return not is_thicket_look(cell)


## The FireGrid's flash-over is done: the cover's cells become open air.
func remove_cells(cells: Array[Vector2i]) -> void:
	var any_removed: bool = false
	for cell: Vector2i in cells:
		if not has_cover(cell):
			continue
		removed_cells[cell] = [get_cell_source_id(cell), get_cell_atlas_coords(cell)]
		erase_cell(cell)
		any_removed = true
	if not any_removed:
		return
	update_internals()  # collision gone this frame, not at the end of it
	roots_canvas.queue_redraw()
	shape_changed.emit()


## Room reset (death or R): every cover is whole again.
func reset() -> void:
	if removed_cells.is_empty():
		return
	for cell: Vector2i in removed_cells:
		var tile: Array = removed_cells[cell]
		set_cell(cell, tile[0], tile[1])
	removed_cells.clear()
	update_internals()
	roots_canvas.queue_redraw()
	shape_changed.emit()


## The tell: on every cover cell, roots out of each side that faces open air.
##   underside: 1-2 tendrils hanging straight down, ROOT_MIN..MAX_LENGTH px, with a
##              1 px kink, so they read as roots and not as a drip
##   left/right: one cell in two pokes a short root out sideways that droops
## Placed by a hash of the cell, so they're the same every run.
func _draw_roots() -> void:
	var tile_size: Vector2 = Vector2(tile_set.tile_size)
	for cell: Vector2i in get_used_cells():
		# & 0x7FFFFFFF keeps it positive, so the % below never goes negative.
		var seed_value: int = hash(cell + Vector2i(31, 17)) & 0x7FFFFFFF
		var top_left: Vector2 = map_to_local(cell) - tile_size / 2.0
		if not _is_solid_anywhere(cell + Vector2i.DOWN):
			var count: int = 2 if seed_value % 3 == 0 else 1
			for root_index: int in count:
				var x: float = 1.0 + float((seed_value >> (root_index * 4)) % 6) + 0.5
				var length: int = ROOT_MIN_LENGTH + (seed_value >> (root_index * 4 + 8)) % (ROOT_MAX_LENGTH - ROOT_MIN_LENGTH + 1)
				var base: Vector2 = top_left + Vector2(x, tile_size.y - 1.0)
				var kink: float = 1.0 if (seed_value >> (root_index + 16)) % 2 == 0 else -1.0
				roots_canvas.draw_line(base, base + Vector2(0.0, ceilf(length / 2.0)), ROOT_COLOR, 1.0)
				roots_canvas.draw_line(base + Vector2(kink, ceilf(length / 2.0)), base + Vector2(kink, length), ROOT_DARK_COLOR, 1.0)
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			if _is_solid_anywhere(cell + side) or (seed_value >> (side.x + 20)) % 2 != 0:
				continue
			var y: float = 2.0 + float((seed_value >> 24) % 4) + 0.5
			var edge_x: float = 0.0 if side.x < 0 else tile_size.x
			var root_start: Vector2 = top_left + Vector2(edge_x, y)
			roots_canvas.draw_line(root_start, root_start + Vector2(side.x * 2.0, 0.0), ROOT_COLOR, 1.0)
			roots_canvas.draw_line(root_start + Vector2(side.x * 2.0, 0.0), root_start + Vector2(side.x * 3.0, 2.0), ROOT_DARK_COLOR, 1.0)

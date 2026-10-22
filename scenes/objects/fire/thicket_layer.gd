class_name ThicketLayer
extends TileMapLayer
## Thicket (Stage F6, Fire_bending.md §6.1b): dark tangled brambles. Solid ground
## (walls, floors, ceilings) that fire burns THROUGH: a burnt thicket cell crumbles
## into falling ash and is open air until the room resets.
##
## Setup: a TileMapLayer child of a Room, named "Thicket", with this script and
## resources/tiles/thicket_tileset.tres (tile THICKET_TILE). tools/build_fire_rooms.gd
## makes it. Its tiles collide on physics layer 1 ("world") like any ground.
##
## Who does what:
##   - the room's FireGrid owns the fire (which cells burn, spread, when they crumble)
##     and calls remove_cells() when cells have burnt out
##   - this layer only erases those tiles (so their collision is gone at once) and
##     paints them back on reset()
##   - the GroundPainter draws the brambles (this layer's own tile drawing is
##     switched off) and repaints when shape_changed fires
##   - a ThicketLeaves child draws the leaves on its open faces (they sway, react to
##     wind, gusts and the player, and burn off)
## The Earth shadow crawls over thicket (SHADOW_PASSABLE_GROUP, like grass); it can't
## be bent or torn. Thrown rocks shatter on it (a Boulder only sticks to an
## EarthLayer, so nothing extra is needed for that).

## Tiles appeared or disappeared (cells burnt away, or a reset painted them back).
signal shape_changed

const TILESET_PATH: String = "res://resources/tiles/thicket_tileset.tres"
## The thicket tileset's atlas: the bramble tile, and a grass-looking tile used only
## by overgrown covers (OvergrownLayer) that pass for grass ground.
const THICKET_TILE: Vector2i = Vector2i(0, 0)
const GRASS_LOOK_TILE: Vector2i = Vector2i(1, 0)

## Cells that burnt away -> [source id, atlas coords] of their tile, for reset().
var removed_cells: Dictionary = {}


func _ready() -> void:
	add_to_group(EarthLayer.SHADOW_PASSABLE_GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	# Leaves on every open face, moving with wind, gusts and the player.
	var leaves: ThicketLeaves = ThicketLeaves.new()
	leaves.name = "Leaves"
	leaves.layer = self
	leaves.grows_on = has_thicket
	add_child(leaves)


## True if `cell` holds a thicket tile right now (not burnt away).
func has_thicket(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) != -1


## The FireGrid is done with these cells: they become open air.
func remove_cells(cells: Array[Vector2i]) -> void:
	var any_removed: bool = false
	for cell: Vector2i in cells:
		if not has_thicket(cell):
			continue
		removed_cells[cell] = [get_cell_source_id(cell), get_cell_atlas_coords(cell)]
		erase_cell(cell)
		any_removed = true
	if not any_removed:
		return
	# A layer normally rebuilds its collision at the end of the frame. Do it now, so
	# whatever stood on the cells starts falling this very frame.
	update_internals()
	shape_changed.emit()


## Room reset (death or R): every burnt cell is thicket again.
func reset() -> void:
	if removed_cells.is_empty():
		return
	for cell: Vector2i in removed_cells:
		var tile: Array = removed_cells[cell]
		set_cell(cell, tile[0], tile[1])
	removed_cells.clear()
	update_internals()
	shape_changed.emit()

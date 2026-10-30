class_name WaterLayer
extends TileMapLayer
## WaterLayer (Stage W1, Water_bending.md §8.1): the water PAINTED into a room. A
## TileMapLayer named "Water", painted with resources/tiles/water_tileset.tres: one
## see-through blue tile with no collision (water isn't solid).
##
## The tiles only say where water is when the room starts. In play, the room's
## WaterWorld reads them once in its _ready(), turns each connected patch into a
## WaterBody (a height field that sloshes and flows) and hides the tiles: from then
## on the WaterWorld draws the water. Each painted tile is one unit (64 px²) of
## water, and the water settles onto the floor under it, so a tile painted in mid-air
## falls. In the level editor (no WaterWorld while editing) the tiles show as they are.
##
## The tileset is made by tools/build_water_rooms.gd (only when missing).

const TILESET_PATH: String = "res://resources/tiles/water_tileset.tres"
## The clean water tile.
const WATER_TILE: Vector2i = Vector2i(0, 0)
## BLACK WATER (Stage W7a): the same water, inky. Each connected patch of it becomes
## a black body (WaterBody.is_black): it kills the player, can't be gathered or
## frozen. Paint it apart from clean water: touching pools join, and black wins.
const BLACK_TILE: Vector2i = Vector2i(1, 0)


## Is the painted tile at `cell` black water?
func is_black_cell(cell: Vector2i) -> bool:
	return get_cell_atlas_coords(cell) == BLACK_TILE

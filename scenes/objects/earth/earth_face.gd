class_name EarthFace
extends RefCounted
## One exposed FACE of one earth tile: the tile, plus which side of it touches open air.
##
## Why faces and not tiles? Earth bending travels along the SURFACE (Earth_bending.md
## §4, §11). A corner tile has two surfaces, its top and its side, and the shadow
## crawling over a ledge goes from one to the other. So a place on the surface is
## (tile, side), and the shadow path is a list of these.
##
## `normal` points from the tile into the open air: UP for a floor's top face,
## LEFT for the left side of a wall, DOWN for a ceiling's underside.
##
## RefCounted = a plain data object that frees itself when nothing references it
## (like a Python object). It's not a Node, so it never goes in the scene tree.
## Used by EarthBendAbility (start face, shadow path) and EarthLayer (queries).

## The layer the tile belongs to (one per room).
var layer: EarthLayer
## The tile, in the layer's map coordinates.
var cell: Vector2i
## Which side faces open air: one of Vector2i.UP / DOWN / LEFT / RIGHT.
var normal: Vector2i


func _init(face_layer: EarthLayer, face_cell: Vector2i, face_normal: Vector2i) -> void:
	layer = face_layer
	cell = face_cell
	normal = face_normal


## The middle of this face in world coordinates: the tile's center pushed half a tile
## toward the open side. For a floor tile that's the middle of its top edge.
func get_global_center() -> Vector2:
	return layer.get_cell_global_center(cell) + Vector2(normal) * layer.get_half_tile_size()


## True if this face is still on the surface (open air outside) and its tile is fresh.
func is_fresh() -> bool:
	return layer.is_fresh(cell) and layer.is_face_exposed(cell, normal)


## True if a bend can START here: fresh earth, or the surface of a risen Earth
## Column (a pillar is earth you stand on; nothing can erupt from it, though).
func is_bend_start() -> bool:
	if is_fresh():
		return true
	return layer.is_column(cell) and not layer.is_solid(cell + normal)


## One step along a surface (Earth_bending.md §11 "THE PATH"; shared since Stage F5 by
## the bend shadow and the FireGrid's spreading grass fire). From the face (`cell`,
## `normal`) moving along `tangent` (one of the two directions along the face), one of:
##   - inner corner: the cell at cell + normal + tangent is solid -> climb onto ITS
##     face pointing back at us (-tangent); the new tangent is our normal
##   - flat: the cell at cell + tangent is solid -> its face on the same side
##   - outer corner: nothing ahead -> wrap round our own cell onto its `tangent` side;
##     the new tangent is -normal
## Returns [next cell, next normal, next tangent]. `is_solid` is a Callable(cell) ->
## bool, so each user decides what counts as ground. Callers decide what may be
## stepped ONTO (the shadow stops at gray rock, fire at anything that isn't grass).
## Static: EarthFace.step_along_surface(layer.is_solid, ...), no face object needed.
static func step_along_surface(is_solid: Callable, cell: Vector2i, normal: Vector2i,
		tangent: Vector2i) -> Array:
	var inner_corner_cell: Vector2i = cell + normal + tangent
	if is_solid.call(inner_corner_cell):
		return [inner_corner_cell, -tangent, normal]
	var straight_cell: Vector2i = cell + tangent
	if is_solid.call(straight_cell):
		return [straight_cell, normal, tangent]
	return [cell, tangent, -normal]


func is_same_as(other: EarthFace) -> bool:
	return other != null and other.layer == layer and other.cell == cell and other.normal == normal


## Readable form for the debug label, e.g. "floor (12, 20)" or "pillar floor (12, 17)".
func describe() -> String:
	var surface_name: String = "wall"
	if normal == Vector2i.UP:
		surface_name = "floor"
	elif normal == Vector2i.DOWN:
		surface_name = "ceiling"
	if layer.is_column(cell):
		# A risen column, a stuck boulder or a snake (all register their cells as "column").
		var creation: Node = layer.column_cells[cell]
		var creation_name: String = "pillar "
		if creation is Boulder:
			creation_name = "boulder "
		elif creation is EarthSnake:
			creation_name = "snake "
		surface_name = creation_name + surface_name
	return "%s (%d, %d)" % [surface_name, cell.x, cell.y]

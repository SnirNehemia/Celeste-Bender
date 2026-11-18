class_name HiddenChamberSettings
extends PaintedPatchSettings
## HiddenChamberSettings: the property panel's stand-in for ONE hidden chamber (a
## connected patch of the "Hidden" layer), picked with the Select tool. Its one
## setting is `cover_look`: what the chamber's fake wall is drawn as in play (earth,
## grey rock, grass, thicket, or the ground round it), so a chamber can hide in any
## terrain, not only in earth (HiddenLayer COVER LOOK).
##
## The look itself lives on the layer (HiddenLayer.chamber_cover_looks, saved with the
## level). This object only remembers WHICH chamber: the layer and one of its cells;
## the chamber is looked up again on every read, so it stays right when it's painted
## bigger or smaller. A change goes through LevelEditor.set_property: one undo step.

var layer: HiddenLayer
var anchor_cell: Vector2i

## What the fake wall looks like. A property with a getter and a setter: reading asks
## the layer, setting writes the layer's dictionary.
@export var cover_look: HiddenLayer.CoverLook:
	get:
		if not is_instance_valid(layer):
			return HiddenLayer.CoverLook.AUTO
		return layer.get_cover_look(layer.get_chamber_cells_at(anchor_cell))
	set(value):
		if is_valid():
			layer.set_cover_look(layer.get_chamber_cells_at(anchor_cell), value)


## The hidden chamber at `world_point` in `room`, or null.
static func find_at(room: Room, world_point: Vector2) -> HiddenChamberSettings:
	if room == null:
		return null
	var found_layer: HiddenLayer = room.get_node_or_null(NodePath(PaletteCatalog.HIDDEN_LAYER_NAME)) as HiddenLayer
	if found_layer == null:
		return null
	var cell: Vector2i = found_layer.local_to_map(found_layer.to_local(world_point))
	if found_layer.get_cell_source_id(cell) == -1:
		return null
	var settings: HiddenChamberSettings = HiddenChamberSettings.new()
	settings.layer = found_layer
	settings.anchor_cell = cell
	return settings


func is_valid() -> bool:
	return is_instance_valid(layer) and layer.is_inside_tree() and layer.get_cell_source_id(anchor_cell) != -1


func get_title() -> String:
	return "Hidden chamber\n%d tiles" % layer.get_chamber_cells_at(anchor_cell).size()


func get_panel_properties() -> Array[StringName]:
	return [&"cover_look"]


func get_panel_hint() -> String:
	return "What this chamber's fake wall is drawn as in play. Auto: earth (or the grass/thicket cover it touches). Surroundings: the most common ground right round it. Or pick earth, rock, grass or thicket. Click another chamber to set its own."


## The chamber's border: one 2-point line per cell edge facing outside it.
func get_world_loops() -> Array[PackedVector2Array]:
	var loops: Array[PackedVector2Array] = []
	if not is_valid():
		return loops
	var cells: Array[Vector2i] = layer.get_chamber_cells_at(anchor_cell)
	var cell_set: Dictionary = {}
	for cell: Vector2i in cells:
		cell_set[cell] = true
	var tile: Vector2 = Vector2(layer.tile_set.tile_size)
	for cell: Vector2i in cells:
		var top_left: Vector2 = Vector2(cell) * tile
		# Each side: the neighbour it faces, and the side's two corners.
		var sides: Array = [
			[Vector2i.UP, top_left, top_left + Vector2(tile.x, 0.0)],
			[Vector2i.DOWN, top_left + Vector2(0.0, tile.y), top_left + tile],
			[Vector2i.LEFT, top_left, top_left + Vector2(0.0, tile.y)],
			[Vector2i.RIGHT, top_left + Vector2(tile.x, 0.0), top_left + tile],
		]
		for side: Array in sides:
			if not cell_set.has(cell + (side[0] as Vector2i)):
				loops.append(layer.global_transform * PackedVector2Array([side[1], side[2]]))
	return loops

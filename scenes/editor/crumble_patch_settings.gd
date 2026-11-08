class_name CrumblePatchSettings
extends RefCounted
## CrumblePatchSettings: the property panel's stand-in for ONE patch of painted
## crumbling rock or ice (after the W8c play-test: "choose a platform and decide how
## long it takes for it to fall").
##
## A patch isn't a node, so the Select tool can't select it like an object. When a
## click with the Select tool finds no object but a crumbling tile, LevelEditor makes
## one of these (find_at) and shows it in the PropertyPanel. The panel reads its
## `crumble_time` like any setting (get_property_list), and a change goes through
## LevelEditor.set_property, so it's one undo step like any other.
##
## The time itself lives on the layer (CrumbleRockLayer / CrumbleIceLayer
## `patch_crumble_times`: one of the patch's cells -> seconds), so it's saved with the
## level. This object only remembers WHICH patch: the layer and one cell of it
## (`anchor_cell`); the patch is looked up again on every read, so it stays right
## when the tiles around it change.

## The painted layers that crumble, by node name (PaletteCatalog layer_name).
const LAYER_NAMES: Array[StringName] = [&"CrumbleRock", &"CrumbleIce"]
const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")

## The patch's layer (a CrumbleRockLayer or CrumbleIceLayer: both have `crumble`
## and `patch_crumble_times`) and one of its cells, the layer's map coordinates.
var layer: TileMapLayer
var anchor_cell: Vector2i

## Seconds from the first touch until the patch falls. A property with a getter and
## a setter: reading it asks the layer, setting it writes the layer's dictionary.
@export_range(0.1, 30.0) var crumble_time: float:
	get:
		var patch: Dictionary = get_patch()
		return CrumblePatches.get_time(patch, WATER_TUNING.crumble_time)
	set(value):
		var patch: Dictionary = get_patch()
		if patch.is_empty():
			return
		var times: Dictionary = CrumblePatches.with_patch_time(layer.get(&"patch_crumble_times"),
			patch[&"cells"], value, WATER_TUNING.crumble_time)
		# Through a typed Dictionary[Vector2i, float] export: assign() keeps its type.
		var typed_times: Dictionary[Vector2i, float] = {}
		typed_times.assign(times)
		layer.set(&"patch_crumble_times", typed_times)


## The patch of painted crumbling tiles at `world_point` in `room`, or null.
static func find_at(room: Room, world_point: Vector2) -> CrumblePatchSettings:
	if room == null:
		return null
	for layer_name: StringName in LAYER_NAMES:
		var found_layer: TileMapLayer = room.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if found_layer == null or found_layer.get(&"crumble") == null:
			continue
		var cell: Vector2i = found_layer.local_to_map(found_layer.to_local(world_point))
		if found_layer.get_cell_source_id(cell) == -1:
			continue
		var settings: CrumblePatchSettings = CrumblePatchSettings.new()
		settings.layer = found_layer
		settings.anchor_cell = cell
		return settings
	return null


## Still a patch there (an undo or an erase may have taken it away)?
func is_valid() -> bool:
	return is_instance_valid(layer) and layer.is_inside_tree() and not get_patch().is_empty()


## The patch the anchor cell is in now ({} if none).
func get_patch() -> Dictionary:
	if not is_instance_valid(layer):
		return {}
	var crumble: CrumblePatches = layer.get(&"crumble")
	var index: int = crumble.get_patch_index(anchor_cell)
	return crumble.patches[index] if index >= 0 else {}


## The panel's title: which kind, and how big.
func get_title() -> String:
	var kind: String = "Crumbling ice" if layer is CrumbleIceLayer else "Crumbling rock"
	var patch: Dictionary = get_patch()
	var tile_count: int = (patch[&"cells"] as Array).size() if not patch.is_empty() else 0
	return "%s patch\n%d tiles" % [kind, tile_count]


## The patch's outline in world px (the overlay draws it as the selection).
func get_world_loops() -> Array[PackedVector2Array]:
	var loops: Array[PackedVector2Array] = []
	var patch: Dictionary = get_patch()
	if patch.is_empty():
		return loops
	for loop: PackedVector2Array in patch[&"loops"]:
		var world_loop: PackedVector2Array = layer.global_transform * loop
		world_loop.append(world_loop[0])  # closed
		loops.append(world_loop)
	return loops

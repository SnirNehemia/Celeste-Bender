class_name CrumbleRockLayer
extends TileMapLayer
## CrumbleRockLayer (Stage W8c, Water_bending.md §16 "Decided in Stage W8c"): grey
## CRUMBLING ROCK painted into a level. A TileMapLayer named "CrumbleRock", painted
## with the placeholder (grey rock) tileset; its tiles are solid on physics layer 1
## ("world") like any rock, and water runs over them like rock (the room's WaterWorld
## counts every tile layer as solid). They never get wet: the wet layer only knows
## the Tiles, Earth, Grass and Thicket layers.
##
## Each connected patch (8 neighbours) crumbles as one, exactly like brittle player
## ice (Stage I4), with the same helper (CrumblePatches, scenes/objects/crumble_patches.gd):
## the first touch by you or a crate starts WaterTuning.crumble_time (2 s); the patch
## shakes while a bright contour runs round it and closes; then it breaks off
## and its tiles are gone (CrumblePatches.take_away) until the room resets (reset(),
## Room.RESETTABLE_GROUP), while its picture FALLS away (CrumbleFall, a look only).
## It releases no water: it's terrain, not frozen water.
##
## THE LOOK: the tiles are hidden (self_modulate) and a child node draws each patch
## as its own picture in the ground's style (CrumbleRockPainter: crust, rim, edge
## line, hatched inside; after the W8c play-test), with a few cracks, so a crumbling
## patch can shake on its own. A patch's picture is painted once and kept
## (patch_textures) until its cells change.
## In the level editor nothing crumbles (GameState.current_room is never the room
## being edited), and the patches are rebuilt whenever the tiles change (the editor
## also calls rebuild_look() after every stroke and undo: TileMapLayer's `changed`
## signal doesn't fire for every cell edit, e.g. erasing inside a patch).
##
## Each patch may have its OWN crumble time (patch_crumble_times, set by clicking the
## patch with the editor's Select tool); patches without one use the tuning's.

const TILESET_PATH: String = "res://resources/tiles/placeholder_tileset.tres"
const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")
## The cracks over the picture (the edge line's color: they read as more crust).
const CRACK_COLOR: Color = CrumbleRockPainter.EDGE_COLOR
## Gravel per tile when a patch breaks off (dust; the patch itself falls, CrumbleFall).
const GRAVEL_PER_TILE: int = 1
const GRAVEL_COLOR: Color = Color(0.5, 0.47, 0.43)

var crumble: CrumblePatches = CrumblePatches.new()
## Patches with their own crumble time: one of the patch's cells -> seconds (level
## editor, CrumblePatchSettings). Saved with the level. A setter: the patches take
## the new times at once.
@export var patch_crumble_times: Dictionary[Vector2i, float] = {}:
	set(value):
		patch_crumble_times = value
		crumble.apply_custom_times(value)
		if look_node != null:
			look_node.queue_redraw()
## Cells that crumbled away -> [source id, atlas coords], for reset().
var removed_cells: Dictionary = {}
var look_node: Node2D
var is_rebuild_queued: bool = false
## Painted patch pictures, by the patch's cells (str of the sorted list) -> the
## painter's [texture, origin]: a patch that's still there isn't painted again.
var patch_textures: Dictionary = {}


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)  # hide the tiles; the child draws
	look_node = Node2D.new()
	look_node.name = "RockLook"
	look_node.draw.connect(_draw_look)
	add_child(look_node)
	# `changed` fires when the tiles change (the editor paints, a patch breaks).
	changed.connect(_queue_rebuild)
	_rebuild()


func _queue_rebuild() -> void:
	if is_rebuild_queued:
		return
	is_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	is_rebuild_queued = false
	crumble.rebuild(get_used_cells(), func(_cells: Array[Vector2i]) -> bool: return true, _trace)
	var kept: Dictionary = {}
	for patch: Dictionary in crumble.patches:
		var cells: Array[Vector2i] = patch[&"cells"]
		var sorted_cells: Array[Vector2i] = cells.duplicate()
		sorted_cells.sort()
		var key: String = str(sorted_cells)
		if not patch_textures.has(key):
			patch_textures[key] = CrumbleRockPainter.paint(cells, tile_set.tile_size, _is_other_ground)
		kept[key] = patch_textures[key]
		patch[&"picture"] = kept[key]
	patch_textures = kept  # patches gone (crumbled, repainted) let their pictures go
	crumble.apply_custom_times(patch_crumble_times)
	look_node.queue_redraw()


## The level editor, after a stroke or an undo: the tiles may have changed (and the
## editor may have shown them while painting), so they're hidden and the patches redone.
func rebuild_look() -> void:
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	_queue_rebuild()


## Is there a tile of another solid layer of the room at `cell` (the crust doesn't
## run along rock the patch leans on)? Water, hidden chambers and storm clouds aren't solid.
func _is_other_ground(cell: Vector2i) -> bool:
	for sibling: Node in get_parent().get_children():
		var layer: TileMapLayer = sibling as TileMapLayer
		if layer != null and layer != self and not layer is WaterLayer and not layer is HiddenLayer \
				and not layer is StormCloudLayer \
				and layer.get_cell_source_id(cell) != -1:
			return true
	return false


## A patch's outline: the same tracer as ice (every tile here is a full square).
func _trace(cells: Array[Vector2i]) -> Array[PackedVector2Array]:
	var atlases: Array[Vector2i] = []
	atlases.resize(cells.size())
	atlases.fill(IceLayer.ICE_TILE)
	return IceLayer.trace_tiles(cells, atlases, tile_set.tile_size)


func _physics_process(delta: float) -> void:
	if crumble.patches.is_empty() or GameState.current_room != get_parent():
		return
	var done: Array[Array] = crumble.advance(self, delta, WATER_TUNING.crumble_time, &"crumble_crack")
	if crumble.has_crumbling() or not done.is_empty():
		look_node.queue_redraw()  # the shake and the contour move every frame
	if crumble.break_patches(self, done, removed_cells, GRAVEL_COLOR, GRAVEL_PER_TILE, &"crumble_break", _draw_patch):
		_rebuild()  # now, not at the end of the frame: the next frame's touch reads it


## Room reset (death or R): every crumbled patch is back, whole and still.
func reset() -> void:
	if crumble.reset_painted(self, removed_cells):
		_rebuild()
	else:
		look_node.queue_redraw()


# --- The look ------------------------------------------------------------------------

func _draw_look() -> void:
	for patch: Dictionary in crumble.patches:
		look_node.draw_set_transform(crumble.get_shake(patch))
		_draw_patch(look_node, patch)
		crumble.draw_contour(look_node, patch, WATER_TUNING.crumble_time)
	look_node.draw_set_transform(Vector2.ZERO)


## One patch's picture and cracks on `canvas`, in this layer's local px (also what a
## crumbled patch's CrumbleFall draws as it falls away).
func _draw_patch(canvas: CanvasItem, patch: Dictionary) -> void:
	var tile_px: Vector2 = Vector2(tile_set.tile_size)
	var picture: Array = patch[&"picture"]
	canvas.draw_texture(picture[0], picture[1])
	for cell: Vector2i in patch[&"cells"]:
		CrumblePatches.draw_cracks(canvas, Vector2(cell) * tile_px, cell, CRACK_COLOR)

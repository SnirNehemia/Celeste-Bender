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
## shakes (harder near the end) and drips grit (CrumbleDrips) while a bright
## contour runs round it and closes; then it breaks off and its tiles are gone (CrumblePatches.take_away)
## until the room resets (reset(), Room.RESETTABLE_GROUP), while it breaks into
## PEBBLES of the room's PebbleField (after the falling-block play-test): they fall,
## land, get kicked by you and crates, and fall again if the ground under them goes.
## Props on it fall (GroundPropFall); crates resting on it at the start don't start it.
## It releases no water: it's terrain, not frozen water.
##
## THE LOOK: the tiles are hidden (self_modulate) and a child node draws each patch
## as its own picture in the ground's style (PatchPainter: dented crust, rim, edge
## line, hatched inside, with a hair crack per tile as its texture), so a crumbling
## patch can shake on its own. A patch's picture is painted once and kept
## (patch_textures) until its cells change; a frame of shaking only draws each
## patch's one picture.
## In the level editor nothing crumbles (GameState.current_room is never the room
## being edited), and the patches are rebuilt whenever the tiles change (the editor
## also calls rebuild_look() after every stroke and undo: TileMapLayer's `changed`
## signal doesn't fire for every cell edit, e.g. erasing inside a patch).
##
## Each patch may have its OWN crumble time (patch_crumble_times, set by clicking the
## patch with the editor's Select tool); patches without one use the tuning's.

const TILESET_PATH: String = "res://resources/tiles/placeholder_tileset.tres"
const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")
## Dust per tile when a patch breaks off (a puff; the patch itself becomes pebbles).
const GRAVEL_PER_TILE: int = 1
const GRAVEL_COLOR: Color = Color(0.5, 0.47, 0.43)
## Pebbles per tile a broken patch leaves in the room's PebbleField (capped there by
## EarthTuning.pebble_max_per_room, oldest first), and their colors (the rock's).
const PEBBLES_PER_TILE: int = 2
const PEBBLE_COLORS: Array[Color] = [PatchPainter.ROCK_PALETTE[PatchPainter.CRUST],
	PatchPainter.ROCK_PALETTE[PatchPainter.RIM], PatchPainter.ROCK_PALETTE[PatchPainter.FLECK]]
## GRIT trickling from a crumbling patch's underside: specks per second per patch,
## how fast they fall, px/s², how long they last, s, and their color.
const GRIT_PER_SECOND: float = 14.0
const GRIT_GRAVITY: float = 300.0
const GRIT_LIFETIME: float = 0.5
const GRIT_COLOR: Color = Color(0.55, 0.5, 0.45)

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
## Grit specks in the air under crumbling patches (drawn by look_node).
var grit: CrumbleDrips = CrumbleDrips.new(GRIT_COLOR, GRIT_PER_SECOND, GRIT_GRAVITY, GRIT_LIFETIME)
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
	# Patches gone (crumbled, repainted) let their pictures go.
	patch_textures = PatchPainter.paint_patches(crumble.patches, patch_textures, tile_set.tile_size,
		_is_other_ground, PatchPainter.ROCK_PALETTE, PatchPainter.Grain.CRACKED)
	crumble.apply_custom_times(patch_crumble_times)
	look_node.queue_redraw()


## The level editor, after a stroke or an undo: the tiles may have changed (and the
## editor may have shown them while painting), so they're hidden and the patches redone.
func rebuild_look() -> void:
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	_queue_rebuild()


func _is_other_ground(cell: Vector2i) -> bool:
	return has_other_ground(self, cell)


## Is there a tile of another solid layer of `layer`'s room at `cell` (the crust doesn't
## run along rock the patch leans on)? Water, hidden chambers and storm clouds aren't
## solid. Static: CrumbleIceLayer asks it too.
static func has_other_ground(layer: TileMapLayer, cell: Vector2i) -> bool:
	for sibling: Node in layer.get_parent().get_children():
		var other: TileMapLayer = sibling as TileMapLayer
		if other != null and other != layer and not other is WaterLayer and not other is HiddenLayer \
				and not other is NonSolidLayer \
				and other.get_cell_source_id(cell) != -1:
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
	grit.advance(self, crumble, delta)
	if crumble.has_crumbling() or not done.is_empty() or not grit.is_empty():
		look_node.queue_redraw()  # the shake, the contour and the grit move every frame
	for cells: Array in done:
		_leave_pebbles(cells)
	# No picture to drop (Callable()): the pebbles are the patch falling.
	if crumble.break_patches(self, done, removed_cells, GRAVEL_COLOR, GRAVEL_PER_TILE, &"crumble_break", Callable()):
		_rebuild()  # now, not at the end of the frame: the next frame's touch reads it


## A broken patch's PEBBLES: PEBBLES_PER_TILE per tile, each starting at a random
## spot of its tile with a small sideways drift, falling from there (the tiles are
## gone by the time they move). Rooms without a PebbleField get none.
func _leave_pebbles(cells: Array) -> void:
	var tile_px: Vector2 = Vector2(tile_set.tile_size)
	var spots: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in cells:
		for pebble_number: int in PEBBLES_PER_TILE:
			spots.append(to_global(Vector2(cell) * tile_px + Vector2(randf_range(1.0, tile_px.x - 1.0),
				randf_range(2.0, tile_px.y - 1.0))))
	PebbleField.leave_falling_pebbles(get_tree(), spots, PEBBLE_COLORS)


## A falling block landed on the global `world_point`: the patch there starts
## crumbling (a direct hit, whatever was resting on it before).
func touch_at_world(world_point: Vector2) -> void:
	crumble.start_patch(crumble.get_patch_index(local_to_map(to_local(world_point))),
		WATER_TUNING.crumble_time, &"crumble_crack")


## The crumble time of a patch with none of its own (the editor's Select panel shows it).
func get_default_crumble_time() -> float:
	return WATER_TUNING.crumble_time


## Room reset (death or R): every crumbled patch is back, whole and still.
func reset() -> void:
	grit.reset()
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
	grit.draw(look_node)


## One patch's picture (its cracks are painted in) on `canvas`, in this layer's local px.
func _draw_patch(canvas: CanvasItem, patch: Dictionary) -> void:
	var picture: Array = patch[&"picture"]
	canvas.draw_texture(picture[0], picture[1])

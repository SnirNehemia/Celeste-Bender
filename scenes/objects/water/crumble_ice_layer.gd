class_name CrumbleIceLayer
extends IceLayer
## CrumbleIceLayer (Stage W8c, Water_bending.md §16 "Decided in Stage W8c"):
## CRUMBLING ICE painted into a level. A TileMapLayer named "CrumbleIce", painted with
## the ice tileset (resources/tiles/ice_tileset.tres), full tiles only.
##
## It's an IceLayer (extends it): solid, in IceLayer.ICE_GROUP (slippery, keeps speed,
## no grip on its walls). What it adds is the crumbling of CrumbleRockLayer
## (scenes/objects/crumble_rock_layer.gd), with the same helpers: each connected patch
## (8 neighbours) crumbles as one (CrumblePatches), crumble_time after the first touch
## by you or a crate, shaking and dripping WATER (CrumbleDrips) while a bright contour
## runs round it (the countdown); then it breaks: its tiles are gone until the room
## resets.
##
## After the crumbling-ice play-test ("match the crumbling rocks, keep the icicles,
## drop some water or ice shards when it falls"):
##   - THE LOOK is the crumbling rock's: each patch painted once in the ground's style
##     (PatchPainter: dented crust, rim, edge line, hatched inside, hair cracks) but in
##     ICE colors (PatchPainter.ICE_PALETTE), with the glass ICICLES (IceLook) still
##     hanging under it over open air. The shared ice material's glint still crosses it.
##   - BREAKING, like the rock it doesn't fall away as one picture: it breaks into ICE
##     SHARDS (pale pebbles of the room's PebbleField: they fall, land, get kicked) and
##     melts a little: MELT_UNITS_PER_TILE of loose water per tile, in rooms with a
##     WaterWorld (water from nowhere, but the room's reset takes it away again).
##
## Each patch may have its OWN crumble time (patch_crumble_times, set by clicking the
## patch with the editor's Select tool); patches without one use the tuning's.

const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")
## A puff of ice dust per tile when a patch breaks (the shards are the patch itself).
const SHARDS_PER_TILE: int = 1
const SHARD_COLOR: Color = Color(0.85, 0.97, 1.0)
## Ice shards per tile a broken patch leaves in the room's PebbleField, and their
## colors (the ice picture's crust, rim and glint).
const PEBBLES_PER_TILE: int = 2
const PEBBLE_COLORS: Array[Color] = [PatchPainter.ICE_PALETTE[PatchPainter.CRUST],
	PatchPainter.ICE_PALETTE[PatchPainter.RIM], PatchPainter.ICE_PALETTE[PatchPainter.FLECK]]
## Water a broken patch melts into, units per tile (a tile full of water is 1 unit).
const MELT_UNITS_PER_TILE: float = 0.1
## Water drops trickling from a crumbling patch: drops per second per patch, their
## fall (px/s²), life (s) and color (the water's blue).
const DRIP_PER_SECOND: float = 10.0
const DRIP_GRAVITY: float = 300.0
const DRIP_LIFETIME: float = 0.6
const DRIP_COLOR: Color = Color(0.45, 0.75, 0.95, 0.9)
## Icicles are drawn this far up, px: their roots tuck into the picture's dented
## bottom edge instead of floating under a dent.
const ICICLE_TUCK: Vector2 = Vector2(0.0, -1.0)

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
## Cells that shattered -> [source id, atlas coords], for reset().
var removed_cells: Dictionary = {}
## Painted patch pictures, by the patch's cells (PatchPainter.get_key) -> picture.
var patch_textures: Dictionary = {}
## Water drops under crumbling patches (drawn by look_node).
var drips: CrumbleDrips = CrumbleDrips.new(DRIP_COLOR, DRIP_PER_SECOND, DRIP_GRAVITY, DRIP_LIFETIME)


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)
	super()


## IceLayer's hook (on start and when the tiles change): the patches, their pictures
## and their icicles.
func _rebuild() -> void:
	is_rebuild_queued = false
	crumble.rebuild(get_used_cells(), func(_cells: Array[Vector2i]) -> bool: return true, _trace_cells)
	patch_textures = PatchPainter.paint_patches(crumble.patches, patch_textures, tile_set.tile_size,
		_is_other_ground, PatchPainter.ICE_PALETTE, PatchPainter.Grain.CRACKED)
	for patch: Dictionary in crumble.patches:
		patch[&"look"] = IceLook.build(patch[&"loops"], true, _is_open_below)
	crumble.apply_custom_times(patch_crumble_times)
	look_node.queue_redraw()


func _is_other_ground(cell: Vector2i) -> bool:
	return CrumbleRockLayer.has_other_ground(self, cell)


func _physics_process(delta: float) -> void:
	if crumble.patches.is_empty() or GameState.current_room != get_parent():
		return
	var done: Array[Array] = crumble.advance(self, delta, WATER_TUNING.crumble_time, &"ice_crack")
	drips.advance(self, crumble, delta)
	if crumble.has_crumbling() or not done.is_empty() or not drips.is_empty():
		look_node.queue_redraw()  # the shake, the contour and the drips move every frame
	for cells: Array in done:
		_leave_shards_and_water(cells)
	# No picture to drop (Callable()): the shards are the patch falling.
	if crumble.break_patches(self, done, removed_cells, SHARD_COLOR, SHARDS_PER_TILE, &"ice_shatter", Callable()):
		_rebuild()  # now, not at the end of the frame: the next frame's touch reads it


## A broken patch's ICE SHARDS (PEBBLES_PER_TILE per tile, dropping from random spots
## of its tiles: PebbleField, rooms without one get none) and its MELT water (rooms
## without a WaterWorld get none).
func _leave_shards_and_water(cells: Array) -> void:
	var tile_px: Vector2 = Vector2(tile_set.tile_size)
	var spots: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in cells:
		for shard_number: int in PEBBLES_PER_TILE:
			spots.append(to_global(Vector2(cell) * tile_px + Vector2(randf_range(1.0, tile_px.x - 1.0),
				randf_range(2.0, tile_px.y - 1.0))))
	PebbleField.leave_falling_pebbles(get_tree(), spots, PEBBLE_COLORS)
	var world: WaterWorld = get_parent().get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	if world == null or not world.is_node_ready():
		return
	# One blob per tile, from the tile's middle (the WaterWorld's coordinates are the room's).
	for cell: Vector2i in cells:
		world.add_loose_water(world.to_local(to_global(map_to_local(cell))), MELT_UNITS_PER_TILE)


## A falling block landed on the global `world_point`: the patch there starts
## crumbling (a direct hit, whatever was resting on it before).
func touch_at_world(world_point: Vector2) -> void:
	crumble.start_patch(crumble.get_patch_index(local_to_map(to_local(world_point))),
		WATER_TUNING.crumble_time, &"ice_crack")


## The crumble time of a patch with none of its own (the editor's Select panel shows it).
func get_default_crumble_time() -> float:
	return WATER_TUNING.crumble_time


## Room reset (death or R): every shattered patch is back, whole and still.
func reset() -> void:
	drips.reset()
	if crumble.reset_painted(self, removed_cells):
		_rebuild()
	else:
		look_node.queue_redraw()


func _draw_look() -> void:
	for patch: Dictionary in crumble.patches:
		look_node.draw_set_transform(crumble.get_shake(patch))
		_draw_patch(look_node, patch)
		crumble.draw_contour(look_node, patch, WATER_TUNING.crumble_time)
	look_node.draw_set_transform(Vector2.ZERO)
	drips.draw(look_node)


## One patch on `canvas`, in this layer's local px: its icicles, then its picture over
## their roots.
func _draw_patch(canvas: CanvasItem, patch: Dictionary) -> void:
	(patch[&"look"] as IceLook).draw_icicles(canvas, ICICLE_TUCK)
	var picture: Array = patch[&"picture"]
	canvas.draw_texture(picture[0], picture[1])

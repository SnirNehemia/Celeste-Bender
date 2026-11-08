class_name CrumbleIceLayer
extends IceLayer
## CrumbleIceLayer (Stage W8c, Water_bending.md §16 "Decided in Stage W8c"):
## CRUMBLING ICE painted into a level. A TileMapLayer named "CrumbleIce", painted with
## the ice tileset (resources/tiles/ice_tileset.tres).
##
## It's an IceLayer (extends it): solid, in IceLayer.ICE_GROUP (slippery, keeps speed,
## no grip on its walls), drawn in the glass look. What it adds is the crumbling of
## CrumbleRockLayer (scenes/objects/crumble_rock_layer.gd), with the same helper
## (CrumblePatches): each connected patch (8 neighbours) crumbles as one, crumble_time
## after the first touch by you or a crate, shaking while a bright contour runs round
## it; then it breaks off and FALLS away (CrumbleFall, a look only), gone until the
## room resets. Unlike brittle player ice it releases NO water: it's terrain, not
## frozen water, and it never melts (painted ice doesn't). Water runs over it like rock.
##
## The look: each patch has its own glass look (IceLook), so a crumbling one can
## shake alone, with hairline cracks drawn on every tile.
##
## Each patch may have its OWN crumble time (patch_crumble_times, set by clicking the
## patch with the editor's Select tool); patches without one use the tuning's.

const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")
## Hairline cracks on every tile, so crumbling ice reads apart from plain ice.
const CRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
## Ice shards per tile when a patch breaks off (the patch itself falls, CrumbleFall).
const SHARDS_PER_TILE: int = 1
const SHARD_COLOR: Color = Color(0.85, 0.97, 1.0)

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


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)
	super()


## IceLayer's hook (on start and when the tiles change): the patches and their looks.
func _rebuild() -> void:
	is_rebuild_queued = false
	crumble.rebuild(get_used_cells(), func(_cells: Array[Vector2i]) -> bool: return true, _trace_cells)
	for patch: Dictionary in crumble.patches:
		patch[&"look"] = IceLook.build(patch[&"loops"], true, _is_open_below)
	crumble.apply_custom_times(patch_crumble_times)
	look_node.queue_redraw()


func _physics_process(delta: float) -> void:
	if crumble.patches.is_empty() or GameState.current_room != get_parent():
		return
	var done: Array[Array] = crumble.advance(self, delta, WATER_TUNING.crumble_time, &"ice_crack")
	if crumble.has_crumbling() or not done.is_empty():
		look_node.queue_redraw()  # the shake and the contour move every frame
	if crumble.break_patches(self, done, removed_cells, SHARD_COLOR, SHARDS_PER_TILE, &"ice_shatter", _draw_patch):
		_rebuild()  # now, not at the end of the frame: the next frame's touch reads it


## Room reset (death or R): every shattered patch is back, whole and still.
func reset() -> void:
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


## One patch's glass look and cracks on `canvas`, in this layer's local px (also what
## a shattered patch's CrumbleFall draws as it falls away).
func _draw_patch(canvas: CanvasItem, patch: Dictionary) -> void:
	(patch[&"look"] as IceLook).draw(canvas)
	for cell: Vector2i in patch[&"cells"]:
		CrumblePatches.draw_cracks(canvas, Vector2(cell * tile_set.tile_size), cell, CRACK_COLOR)

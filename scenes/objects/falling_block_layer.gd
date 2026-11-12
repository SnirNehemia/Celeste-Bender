class_name FallingBlockLayer
extends TileMapLayer
## FallingBlockLayer: FALLING BLOCKS painted into a level (after the W8c play-test:
## "walls that fall instead of crumble"). A TileMapLayer named "FallingBlock", painted
## from the editor's Terrain tab with the placeholder (grey rock) tileset, so its tiles
## are solid on physics layer 1 ("world"); they're drawn as dark BASALT instead.
##
## Each connected patch (8 neighbours) is one block. Like crumbling rock (the same
## helper, CrumblePatches): the first touch by you (or a crate or a block landing on
## it later; not what rests on it from the start) starts its time,
## WaterTuning.falling_block_time (0.6 s; each patch may have its own, set by
## clicking it with the editor's Select tool), while it shakes and a pale contour runs
## round it. Then it DROPS as one solid piece: its tiles are taken away and a
## FallingBlock body (scenes/objects/falling_block.gd) falls in their place, straight
## down, carrying you, crates, braziers and fire diamonds standing on it, killing you
## and breaking crates under it, splashing into water.
##
## LANDED: a block that lands on the tile grid becomes tiles of this layer again,
## where it landed (so water, the editor's map of solids, everything treats it as
## ground). Landed tiles are left out of the patches (they never fall on their own
## again), but if the ground under ALL of a landed block goes away (it landed on
## crumbling rock that then broke), it falls again. A block that lands off the grid
## (on a platform) stays a body, resting, and falls on when its support goes.
## Death or R puts every block back where it was painted (reset()).
##
## THE LOOK: the ground's look in basalt (PatchPainter, BASALT_PALETTE: a very dark
## crust with a faint blue in it, a cold blue rim, a near-black hatched inside, column
## joints and pale glints as its texture). Each block is one picture, painted once:
## the layer draws it shaking, the falling body draws the same picture, and a landed
## block keeps it. The layer's own tiles are hidden (self_modulate). A block never
## leans on other ground in its picture (crust all round): it's a loose piece.
##
## FALLING ICE (FallingIceLayer, scenes/objects/water/falling_ice_layer.gd) is this
## layer with another look and slippery: it overrides the hooks under "Kinds" below
## (node name, palette, grain, colors), nothing else.

const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")
## The contour running round a block about to drop: pale blue, not crumbling's white.
const CONTOUR_COLOR: Color = Color(0.7, 0.85, 1.0)
## Dust when a block lets go, per tile.
const DUST_PER_TILE: int = 1
const DUST_COLOR: Color = Color(0.3, 0.32, 0.38)
## The tile a landed block is painted back with (the placeholder tileset's plain rock,
## what the editor paints: TileBrush.SOURCE_ID and TILE_PLAIN).
const LANDED_SOURCE_ID: int = 0
const LANDED_ATLAS: Vector2i = Vector2i(0, 0)

## The tiles a layer made at run time is painted with (the editor's: placeholder rock).
const TILESET: TileSet = preload("res://resources/tiles/placeholder_tileset.tres")
const NODE_NAME: StringName = &"FallingBlock"

var crumble: CrumblePatches = CrumblePatches.new()
## Patches with their own drop time: one of the patch's cells -> seconds (level
## editor, CrumblePatchSettings). Saved with the level. A setter: the patches take
## the new times at once.
@export var patch_crumble_times: Dictionary[Vector2i, float] = {}:
	set(value):
		patch_crumble_times = value
		crumble.apply_custom_times(value)
		if look_node != null:
			look_node.queue_redraw()

## Cells that dropped away -> [source id, atlas coords], for reset().
var removed_cells: Dictionary = {}
## Landed blocks, now tiles of this layer: each an Array[Vector2i] of its cells, and
## its picture (PatchPainter's [texture, origin], moved down with it) in
## landed_pictures. landed_cells: every landed cell.
var landed_groups: Array[Array] = []
var landed_pictures: Array[Array] = []
var landed_cells: Dictionary = {}
## Painted block pictures, by the block's cells (PatchPainter.get_key) -> picture.
var patch_textures: Dictionary = {}
var look_node: Node2D
var is_rebuild_queued: bool = false


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)  # hide the tiles; the child draws
	look_node = Node2D.new()
	look_node.name = "BasaltLook"
	look_node.draw.connect(_draw_look)
	add_child(look_node)
	changed.connect(_queue_rebuild)
	_rebuild()


## `room`'s falling-block layer, made (empty, after its other tile layers) if it has
## none: a block falling into a room from the one above is handed to it
## (FallingBlock._hand_over), and lands as ITS tiles, so they stay solid while you're
## in that room. A layer made here is solid ground for the room's water too.
## The layer is of the same kind as this one (falling ice goes to falling ice):
## get_script().new() makes a node with this node's script, a subclass's too.
func ensure_twin_in(room: Room) -> FallingBlockLayer:
	var found: FallingBlockLayer = room.get_node_or_null(NodePath(get_layer_name())) as FallingBlockLayer
	if found != null:
		return found
	var made: FallingBlockLayer = get_script().new() as FallingBlockLayer
	made.name = get_layer_name()
	made.tile_set = tile_set  # before _ready: _rebuild reads the tile size
	var last_layer_index: int = 0
	for child: Node in room.get_children():
		if child is TileMapLayer:
			last_layer_index = child.get_index()
	room.add_child(made)
	room.move_child(made, last_layer_index + 1)
	var world: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	if world != null and world.is_node_ready():
		world.solid_layers.append(made)
	return made


func _queue_rebuild() -> void:
	if is_rebuild_queued:
		return
	is_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	is_rebuild_queued = false
	var cells: Array[Vector2i] = []
	for cell: Vector2i in get_used_cells():
		if not landed_cells.has(cell):
			cells.append(cell)
	crumble.rebuild(cells, func(_cells: Array[Vector2i]) -> bool: return true, _trace)
	crumble.apply_custom_times(patch_crumble_times)
	patch_textures = PatchPainter.paint_patches(crumble.patches, patch_textures, tile_set.tile_size,
		func(_cell: Vector2i) -> bool: return false, get_palette(), get_grain())
	look_node.queue_redraw()


## The level editor, after a stroke or an undo: the tiles may have changed (and the
## editor may have shown them while painting), so they're hidden and the patches redone.
func rebuild_look() -> void:
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	_queue_rebuild()


## A patch's outline: the ice tracer (every tile here is a full square).
func _trace(cells: Array) -> Array[PackedVector2Array]:
	var typed_cells: Array[Vector2i] = []
	typed_cells.assign(cells)
	var atlases: Array[Vector2i] = []
	atlases.resize(typed_cells.size())
	atlases.fill(IceLayer.ICE_TILE)
	return IceLayer.trace_tiles(typed_cells, atlases, tile_set.tile_size)


func _physics_process(delta: float) -> void:
	if GameState.current_room != get_parent():
		return
	if not crumble.patches.is_empty():
		var done: Array[Array] = crumble.advance(self, delta, WATER_TUNING.falling_block_time, &"crumble_crack")
		if crumble.has_crumbling() or not done.is_empty():
			look_node.queue_redraw()  # the shake and the contour move every frame
		for cells: Array in done:
			var patch: Dictionary = crumble.patches[crumble.get_patch_index(cells[0])]
			_let_go(cells, true, patch[&"picture"])
		if not done.is_empty():
			_rebuild()  # now: the next frame's touch reads it
	_check_landed_support()


## The block made of `cells` drops: its tiles go (remembered for the reset when
## `was_painted`; a landed block's tiles just go) and a FallingBlock falls in their
## place with the block's `picture`, carrying the props standing on it.
func _let_go(cells: Array, was_painted: bool, picture: Array) -> void:
	var props: Array[Node2D] = GroundProps.find_on(self, cells)
	for prop: Node2D in props:
		GroundProps.remember_home(prop)
	if was_painted:
		CrumblePatches.take_away(self, cells, removed_cells)
	else:
		for cell: Vector2i in cells:
			erase_cell(cell)
		update_internals()
		CrumblePatches.take_away(self, [], {})  # tells the water the ground went
	CrumblePatches.burst_over(self, cells, get_dust_color(), DUST_PER_TILE)
	var block_cells: Array[Vector2i] = []
	block_cells.assign(cells)
	FallingBlock.spawn(self, block_cells, picture, props)
	GroundProps.wake_leaf_piles(get_parent())
	FX.play_sfx(&"crumble_break")


## A block landed (FallingBlock calls this) with its cells now at `cells` (this
## layer's map coords, on the grid) and its `picture` moved down with it: it becomes
## tiles here, and the water hears of it.
func land(cells: Array[Vector2i], picture: Array) -> void:
	for cell: Vector2i in cells:
		set_cell(cell, LANDED_SOURCE_ID, LANDED_ATLAS)
		landed_cells[cell] = true
	landed_groups.append(cells)
	landed_pictures.append(picture)
	update_internals()
	var world: WaterWorld = get_parent().get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	if world != null and world.is_node_ready():
		var room_cells: Array[Vector2i] = []
		for cell: Vector2i in cells:
			room_cells.append(Vector2i((to_global(map_to_local(cell)) - (get_parent() as Node2D).global_position) / float(WaterWorld.TILE)))
		world.solid_landed(room_cells)
	_rebuild()


## A landed block with nothing under ANY of its bottom cells falls again.
func _check_landed_support() -> void:
	for index: int in range(landed_groups.size() - 1, -1, -1):
		var group: Array = landed_groups[index]
		if _is_supported(group):
			continue
		var picture: Array = landed_pictures[index]
		landed_groups.remove_at(index)
		landed_pictures.remove_at(index)
		for cell: Vector2i in group:
			landed_cells.erase(cell)
		_let_go(group, false, picture)
		_rebuild()


## Is something solid under any bottom cell of `group` (a tile of any solid layer, or
## a body: a door, a platform, another block)?
func _is_supported(group: Array) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	var tile_px: Vector2 = Vector2(tile_set.tile_size)
	for cell: Vector2i in group:
		var below: Vector2i = cell + Vector2i.DOWN
		if group.has(below):
			continue  # not a bottom cell
		# Just under the cell's bottom edge, in its middle.
		query.position = to_global(Vector2(below) * tile_px + Vector2(tile_px.x / 2.0, 1.0))
		for hit: Dictionary in space.intersect_point(query, 4):
			if not hit["collider"] is CharacterBody2D:
				return true  # tiles (any layer, this one too) or a solid body
	return false


## A falling block landed on the global `world_point`: the block there starts
## shaking (a chain: a block dropped on a block drops it too).
func touch_at_world(world_point: Vector2) -> void:
	var cell: Vector2i = local_to_map(to_local(world_point))
	crumble.start_patch(crumble.get_patch_index(cell), WATER_TUNING.falling_block_time, &"crumble_crack")


## The drop time of a patch with none of its own (the editor's Select panel shows it).
func get_default_crumble_time() -> float:
	return WATER_TUNING.falling_block_time


## Room reset (death or R): falling and landed blocks go, every block is back where it
## was painted, whole and still; the props they carried go home.
func reset() -> void:
	for child: Node in get_children():
		if child is FallingBlock:
			remove_child(child)
			child.queue_free()
	for cell: Vector2i in landed_cells:
		erase_cell(cell)
	var had_landed: bool = not landed_cells.is_empty()
	landed_cells.clear()
	landed_groups.clear()
	landed_pictures.clear()
	if crumble.reset_painted(self, removed_cells) or had_landed:
		update_internals()
		var world: WaterWorld = get_parent().get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
		if world != null and world.is_node_ready():
			world.refresh_solid_cells()
	_rebuild()


# --- The look ------------------------------------------------------------------------

func _draw_look() -> void:
	for patch: Dictionary in crumble.patches:
		look_node.draw_set_transform(crumble.get_shake(patch))
		draw_picture(look_node, patch[&"picture"])
		crumble.draw_contour(look_node, patch, WATER_TUNING.falling_block_time, get_contour_color())
	look_node.draw_set_transform(Vector2.ZERO)
	for picture: Array in landed_pictures:
		draw_picture(look_node, picture)


## A block's picture (PatchPainter's [texture, origin in this layer's px]) on `canvas`
## (also what a falling FallingBlock draws, in its own coordinates).
static func draw_picture(canvas: CanvasItem, picture: Array) -> void:
	canvas.draw_texture(picture[0], picture[1])


# --- Kinds (FallingIceLayer overrides these) ------------------------------------------

## The node name this kind of layer has in a room ("FallingBlock").
func get_layer_name() -> StringName:
	return NODE_NAME


## The colors and texture of the blocks' pictures (PatchPainter).
func get_palette() -> Array[Color]:
	return PatchPainter.BASALT_PALETTE


func get_grain() -> PatchPainter.Grain:
	return PatchPainter.Grain.COLUMNS


## The dust when a block lets go and when it lands.
func get_dust_color() -> Color:
	return DUST_COLOR


## The contour running round a block about to drop.
func get_contour_color() -> Color:
	return CONTOUR_COLOR

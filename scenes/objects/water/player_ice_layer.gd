class_name PlayerIceLayer
extends IceLayer
## PlayerIceLayer (grid ice, Stages I1-I5, Water_bending.md §16 "Re-planned: grid
## ice"): the ice the FREEZE makes, as tiles. One per room with water, made by the
## room's WaterWorld (as the room's "PlayerIce" layer) and never saved: the level
## editor never sees it.
##
## It's an IceLayer (extends it): the same tileset (full tiles and slope tiles), the
## same collision (solid, physics layer 1), the same ice group (Player.is_ice: you
## slide on it) and the same glass look. What it adds:
##   - BOOKKEEPING: which FREEZE made each cell (cell_freeze: the ice cap melts a whole
##     freeze) and how much water each holds (cell_area, px²: a full tile 1 unit, a
##     45° slope half). The WaterWorld places and removes cells (place / remove) and
##     owns the water; this node never makes or spends water itself.
##   - PATCHES: connected cells (8 neighbours: a 45° trail's slope tiles touch only at
##     their corners). A patch that touches no TERRAIN (rock, earth, painted ice or any
##     other solid tile beside one of its cells; or a pool's surface right under one)
##     is BRITTLE: hanging in mid-air, it's drawn cracked.
##   - CRUMBLING (Stage I4): the first time you or a crate (anything in
##     WaterWorld.SOLID_GROUP) touches a brittle patch, it shakes for crumble_time game
##     seconds while a bright contour runs around it and closes; then it SHATTERS: the
##     WaterWorld gives its water back as loose water (shatter_cells). The patches, the
##     touch, the countdown and the contour are CrumblePatches (crumble_patches.gd,
##     Stage W8c), shared with the painted crumbling platforms.
##   - FIRE (the Flammable contract, scenes/objects/fire/flammable.gd): a flame
##     touching player ice melts the whole freeze it belongs to (ignite_at).
##
## Patches and their looks are rebuilt in commit(), which the WaterWorld calls after
## every change (after refreshing its solid grid: anchoring reads it).

## A brittle patch is drawn with hairline cracks in this color.
const CRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
## How many white shard specks each shattering tile throws (a look only).
const SHARDS_PER_TILE: int = 3
## Half a tile, px (map_to_local gives a tile's center).
const TILE_HALF: float = 4.0

var world: WaterWorld
## cell -> the freeze id that made it.
var cell_freeze: Dictionary = {}
## cell -> the water frozen in it, px².
var cell_area: Dictionary = {}
## The connected patches (rebuilt by commit()): CrumblePatches' Dictionaries, where
## can_crumble = brittle, plus `look`: the patch's IceLook.
var crumble: CrumblePatches = CrumblePatches.new()
## For tests: how many patches have shattered.
var shatter_count: int:
	get:
		return crumble.shatter_count


## A new layer for `owner_world`'s room (the caller adds it to the room).
static func create(owner_world: WaterWorld) -> PlayerIceLayer:
	var layer: PlayerIceLayer = PlayerIceLayer.new()
	layer.name = "PlayerIce"
	layer.world = owner_world
	layer.tile_set = load(TILESET_PATH) as TileSet
	return layer


func _ready() -> void:
	super()
	add_to_group(Flammable.GROUP)


# --- Cells (the WaterWorld's calls) --------------------------------------------------

## Puts an ice tile `atlas` (IceLayer's tiles) at `cell`, holding `area` px² of
## water, made by freeze `freeze_id`. Call commit() after a batch of changes.
func place(cell: Vector2i, atlas: Vector2i, area: float, freeze_id: int) -> void:
	set_cell(cell, 0, atlas)
	cell_freeze[cell] = freeze_id
	cell_area[cell] = area


## Takes the tile at `cell` away. Returns the water it held, px² (0 if none).
func remove(cell: Vector2i) -> float:
	if not cell_freeze.has(cell):
		return 0.0
	var area: float = cell_area[cell]
	erase_cell(cell)
	cell_freeze.erase(cell)
	cell_area.erase(cell)
	return area


func has_ice(cell: Vector2i) -> bool:
	return cell_freeze.has(cell)


## The cells freeze `freeze_id` made that are still there.
func get_cells_of(freeze_id: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in cell_freeze:
		if cell_freeze[cell] == freeze_id:
			cells.append(cell)
	return cells


## Is any cell of freeze `freeze_id` still there?
func has_freeze(freeze_id: int) -> bool:
	return cell_freeze.values().has(freeze_id)


## Every cell, every freeze: gone (a reset; the WaterWorld settles the books).
func clear_ice() -> void:
	clear()
	cell_freeze.clear()
	cell_area.clear()
	commit()


## After a batch of place/remove (and the WaterWorld's solid grid refresh): the
## collision is updated now (not at the end of the frame, so a freeze stands at once)
## and the patches and their looks are rebuilt.
func commit() -> void:
	update_internals()
	_rebuild()


# --- Patches and anchoring ------------------------------------------------------------

## IceLayer's hook, run by commit() (and by the tiles' `changed` signal): the patches
## and their looks.
func _rebuild() -> void:
	is_rebuild_queued = false
	if world == null:
		return
	var cells: Array[Vector2i] = []
	cells.assign(cell_freeze.keys())
	crumble.rebuild(cells, func(patch_cells: Array[Vector2i]) -> bool: return not is_anchored(patch_cells), _trace_cells)
	for patch: Dictionary in crumble.patches:
		patch[&"look"] = IceLook.build(patch[&"loops"], true, _is_open_below)
	look_node.queue_redraw()


## Does any of `cells` touch terrain (a solid tile that isn't player ice, beside it:
## 4 neighbours) or rest on a pool (water's surface within the tile under it)?
func is_anchored(cells: Array[Vector2i]) -> bool:
	var own: Dictionary = {}
	for cell: Vector2i in cells:
		own[cell] = true
	for cell: Vector2i in cells:
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + side
			if not own.has(next) and world.is_terrain_cell(next):
				return true
		if world.is_pool_under_cell(cell):
			return true
	return false


## The ghost asks: would ice in `new_cells` (with the player ice already joined to
## them) hang in mid-air?
func would_be_brittle(new_cells: Array[Vector2i]) -> bool:
	if new_cells.is_empty():
		return false
	var joined: Dictionary = {}
	for cell: Vector2i in new_cells:
		joined[cell] = true
	# Existing ice joined to them (8 neighbours), flooded outward.
	var queue: Array[Vector2i] = new_cells.duplicate()
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var next: Vector2i = cell + Vector2i(dx, dy)
				if not joined.has(next) and cell_freeze.has(next):
					joined[next] = true
					queue.append(next)
	var all_cells: Array[Vector2i] = []
	all_cells.assign(joined.keys())
	return not is_anchored(all_cells)


func is_brittle(cell: Vector2i) -> bool:
	return crumble.can_crumble(cell)


func is_crumbling(cell: Vector2i) -> bool:
	return crumble.is_crumbling(cell)


# --- Crumbling (Stage I4) -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or crumble.patches.is_empty() or GameState.current_room != world.room:
		return
	var done: Array[Array] = crumble.advance(self, delta, world.water_tuning.crumble_time, &"ice_crack")
	if crumble.has_crumbling() or not done.is_empty():
		look_node.queue_redraw()  # the shake and the contour move every frame
	var to_shatter: Array[Vector2i] = []
	for cells: Array in done:
		to_shatter.append_array(cells)
	if not to_shatter.is_empty():
		world.shatter_cells(to_shatter)


# --- Fire: the Flammable contract ------------------------------------------------------

## A flame at `world_point` reaching `radius` px melts every freeze with a tile there.
func ignite_at(world_point: Vector2, radius: float, _source: Node) -> bool:
	var local_point: Vector2 = to_local(world_point)
	# 1 px past the flame's reach: a flame licking a tile's face counts.
	var reach: float = radius + 1.0
	var first: Vector2i = local_to_map(local_point - Vector2(reach, reach))
	var last: Vector2i = local_to_map(local_point + Vector2(reach, reach))
	var freeze_ids: Dictionary = {}
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not cell_freeze.has(cell):
				continue
			var cell_rect: Rect2 = Rect2(map_to_local(cell) - Vector2(TILE_HALF, TILE_HALF), Vector2(TILE_HALF, TILE_HALF) * 2.0)
			if cell_rect.grow(reach).has_point(local_point):
				freeze_ids[cell_freeze[cell]] = true
	for freeze_id: int in freeze_ids:
		world.melt_freeze(freeze_id)
	return not freeze_ids.is_empty()


func ignite(_source: Node) -> void:
	pass  # only ignite_at: fire melts the tiles it touches


func is_burning() -> bool:
	return false


func snuff() -> void:
	pass


# --- The look ------------------------------------------------------------------------

## IceLayer's hook: each patch in the glass look; brittle ones cracked; a crumbling
## one shaking, with its contour running round.
func _draw_look() -> void:
	for patch: Dictionary in crumble.patches:
		look_node.draw_set_transform(crumble.get_shake(patch))
		(patch[&"look"] as IceLook).draw(look_node)
		if bool(patch[&"can_crumble"]):
			for cell: Vector2i in patch[&"cells"]:
				CrumblePatches.draw_cracks(look_node, Vector2(cell * tile_set.tile_size), cell, CRACK_COLOR)
		crumble.draw_contour(look_node, patch, world.water_tuning.crumble_time)
	look_node.draw_set_transform(Vector2.ZERO)

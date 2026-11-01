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
##     WaterWorld gives its water back as loose water (shatter_cells).
##   - FIRE (the Flammable contract, scenes/objects/fire/flammable.gd): a flame
##     touching player ice melts the whole freeze it belongs to (ignite_at).
##
## Patches and their looks are rebuilt in commit(), which the WaterWorld calls after
## every change (after refreshing its solid grid: anchoring reads it).

## A brittle patch is drawn with hairline cracks in this color.
const CRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
## The contour that runs around a crumbling patch, and how far it shakes, px.
const CONTOUR_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const SHAKE_PX: float = 1.0
## How many white shard specks each shattering tile throws (a look only).
const SHARDS_PER_TILE: int = 3
## Half a tile, px (map_to_local gives a tile's center).
const TILE_HALF: float = 4.0

var world: WaterWorld
## cell -> the freeze id that made it.
var cell_freeze: Dictionary = {}
## cell -> the water frozen in it, px².
var cell_area: Dictionary = {}
## The connected patches (rebuilt by commit()). Each is a Dictionary:
##   cells: Array[Vector2i]; brittle: bool; crack_left: float (game s of crumbling
##   left, -1 = not crumbling); look: IceLook; loops: Array[PackedVector2Array]
##   (its outline, for the contour); perimeter: float (px).
var patches: Array[Dictionary] = []
## For tests: how many patches have shattered.
var shatter_count: int = 0


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
	# Crumbling carries over: a patch keeps the least time left of any of its cells
	# (cells are 8-connected: a patch can only merge with another or lose cells).
	var old_crack_left: Dictionary = {}
	for patch: Dictionary in patches:
		if float(patch[&"crack_left"]) >= 0.0:
			for cell: Vector2i in patch[&"cells"]:
				old_crack_left[cell] = patch[&"crack_left"]
	patches.clear()
	var unvisited: Dictionary = cell_freeze.duplicate()
	while not unvisited.is_empty():
		var start: Vector2i = unvisited.keys()[0]
		var cells: Array[Vector2i] = _flood(start, unvisited)
		var brittle: bool = not is_anchored(cells)
		var crack_left: float = -1.0
		if brittle:
			for cell: Vector2i in cells:
				if old_crack_left.has(cell):
					crack_left = float(old_crack_left[cell]) if crack_left < 0.0 \
						else minf(crack_left, float(old_crack_left[cell]))
		var loops: Array[PackedVector2Array] = _trace_cells(cells)
		var perimeter: float = 0.0
		for loop: PackedVector2Array in loops:
			for index: int in loop.size():
				perimeter += loop[index].distance_to(loop[(index + 1) % loop.size()])
		patches.append({
			&"cells": cells, &"brittle": brittle, &"crack_left": crack_left,
			&"look": IceLook.build(loops, true, _is_open_below), &"loops": loops, &"perimeter": perimeter,
		})
	look_node.queue_redraw()


## The cells 8-connected to `start` among `unvisited` (taken out of it).
func _flood(start: Vector2i, unvisited: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	unvisited.erase(start)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		cells.append(cell)
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var next: Vector2i = cell + Vector2i(dx, dy)
				if unvisited.has(next):
					unvisited.erase(next)
					queue.append(next)
	return cells


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


## The patch `cell` is in, as an index into `patches`, or -1.
func get_patch_index(cell: Vector2i) -> int:
	for index: int in patches.size():
		if (patches[index][&"cells"] as Array).has(cell):
			return index
	return -1


func is_brittle(cell: Vector2i) -> bool:
	var index: int = get_patch_index(cell)
	return index >= 0 and bool(patches[index][&"brittle"])


func is_crumbling(cell: Vector2i) -> bool:
	var index: int = get_patch_index(cell)
	return index >= 0 and float(patches[index][&"crack_left"]) >= 0.0


# --- Crumbling (Stage I4) -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or patches.is_empty() or GameState.current_room != world.room:
		return
	var has_waiting: bool = false
	var has_crumbling: bool = false
	for patch: Dictionary in patches:
		if bool(patch[&"brittle"]):
			if float(patch[&"crack_left"]) < 0.0:
				has_waiting = true
			else:
				has_crumbling = true
	if has_waiting:
		_start_crumbling_where_touched()
	if not has_crumbling:
		return
	var to_shatter: Array[Vector2i] = []
	for patch: Dictionary in patches:
		var crack_left: float = patch[&"crack_left"]
		if crack_left < 0.0:
			continue
		crack_left -= delta
		patch[&"crack_left"] = crack_left
		if crack_left <= 0.0:
			to_shatter.append_array(patch[&"cells"])
	look_node.queue_redraw()  # the shake and the contour move every frame
	if not to_shatter.is_empty():
		shatter_count += 1
		world.shatter_cells(to_shatter)


## Brittle patches that you or a crate touch (their box grown by 1 px: standing on
## the ice, your feet are on its top edge) start crumbling.
func _start_crumbling_where_touched() -> void:
	for member: Node in get_tree().get_nodes_in_group(WaterWorld.SOLID_GROUP):
		if not member.has_method(&"get_water_box"):
			continue
		var box: Rect2 = member.call(&"get_water_box")
		if box.size.x <= 0.0:
			continue
		box = Rect2(to_local(box.position), box.size).grow(1.0)
		var first: Vector2i = local_to_map(box.position)
		var last: Vector2i = local_to_map(box.end - Vector2(0.01, 0.01))
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var index: int = get_patch_index(Vector2i(x, y)) if cell_freeze.has(Vector2i(x, y)) else -1
				if index >= 0 and bool(patches[index][&"brittle"]) and float(patches[index][&"crack_left"]) < 0.0:
					patches[index][&"crack_left"] = world.water_tuning.crumble_time
					FX.play_sfx(&"ice_crack")


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
	for patch: Dictionary in patches:
		var crack_left: float = patch[&"crack_left"]
		var offset: Vector2 = Vector2.ZERO
		if crack_left >= 0.0:
			offset = Vector2(randi_range(-1, 1), randi_range(-1, 1)) * SHAKE_PX
		look_node.draw_set_transform(offset)
		(patch[&"look"] as IceLook).draw(look_node)
		if bool(patch[&"brittle"]):
			for cell: Vector2i in patch[&"cells"]:
				_draw_cracks(cell)
		if crack_left >= 0.0:
			# How far round the contour has run: 0 at the touch, 1 when it shatters.
			var share: float = 1.0 - crack_left / maxf(world.water_tuning.crumble_time, 0.01)
			_draw_contour(patch[&"loops"], float(patch[&"perimeter"]) * clampf(share, 0.0, 1.0))
	look_node.draw_set_transform(Vector2.ZERO)


## Hairline cracks across a brittle tile: a short zigzag, its shape picked by a hash
## of the cell (the same tile always cracks the same way).
func _draw_cracks(cell: Vector2i) -> void:
	var origin: Vector2 = Vector2(cell * tile_set.tile_size)
	var hash_value: int = absi(cell.x * 73856093 ^ cell.y * 19349663)
	var start: Vector2 = origin + Vector2(1 + hash_value % 3, 2 + floori(hash_value / 3.0) % 3)
	var middle: Vector2 = start + Vector2(3, 2 - floori(hash_value / 9.0) % 3)
	var end: Vector2 = middle + Vector2(2, 2)
	look_node.draw_line(start, middle, CRACK_COLOR, 1.0)
	look_node.draw_line(middle, end, CRACK_COLOR, 1.0)


## The crumbling contour: a bright line along the patch's outline, `length` px of it
## from where it starts; when it has gone all the way round, the ice shatters.
func _draw_contour(loops: Array[PackedVector2Array], length: float) -> void:
	var left: float = length
	for loop: PackedVector2Array in loops:
		for index: int in loop.size():
			if left <= 0.0:
				return
			var from: Vector2 = loop[index]
			var to: Vector2 = loop[(index + 1) % loop.size()]
			var edge_length: float = from.distance_to(to)
			var drawn_to: Vector2 = to if edge_length <= left else from.lerp(to, left / edge_length)
			look_node.draw_line(from, drawn_to, CONTOUR_COLOR, 1.0)
			left -= edge_length

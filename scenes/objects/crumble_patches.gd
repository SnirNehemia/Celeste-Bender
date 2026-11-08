class_name CrumblePatches
extends RefCounted
## CrumblePatches (Stage W8c, Water_bending.md §16 "Decided in Stage W8c"): the
## crumbling that brittle player ice (Stage I4) and the painted crumbling platforms
## share. It isn't a node: a layer owns one (`var crumble: CrumblePatches`) and calls
## it from its own _rebuild(), _physics_process() and drawing.
##
## Who uses it:
##   - PlayerIceLayer (scenes/objects/water/player_ice_layer.gd): only its BRITTLE
##     patches (hanging in mid-air) crumble; when one is done the WaterWorld gives its
##     water back as loose water.
##   - CrumbleRockLayer and CrumbleIceLayer (scenes/objects/crumble_rock_layer.gd,
##     scenes/objects/water/crumble_ice_layer.gd): painted terrain, every patch
##     crumbles; when one is done its tiles are erased until the room resets.
##
## What it does:
##   - PATCHES: rebuild() cuts the cells into connected patches (8 neighbours: a 45°
##     ice trail's slope tiles touch only at their corners) and traces each one's
##     outline (for the contour). A patch is a Dictionary:
##       cells: Array[Vector2i]; can_crumble: bool; crack_left: float (game s of
##       crumbling left, -1 = not crumbling); loops: Array[PackedVector2Array] (its
##       outline, the layer's local px); perimeter: float (px).
##     The owner may add its own keys (PlayerIceLayer adds its glass look). The
##     painted layers may give a patch its own crumble time (key `time`, seconds;
##     apply_custom_times, set in the level editor), else the tuning's time is used.
##   - THE TOUCH: the first time you or a crate (anything in WaterWorld.SOLID_GROUP,
##     whose get_water_box() is its box) touches a patch that can crumble, its
##     crack_left starts at crumble_time.
##   - THE COUNTDOWN: advance() runs it down and returns the patches that are done.
##   - THE LOOK: get_shake() for a crumbling patch (a 1 px jitter), and draw_contour():
##     a bright line running round the outline, closing as the time runs out.

## The contour that runs round a crumbling patch, and how far it shakes, px.
const CONTOUR_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const SHAKE_PX: float = 1.0
## The pieces a crumbled platform breaks into (burst): how long they live, s, how fast
## they fly, px/s, and how hard they fall, px/s². A look only.
const BURST_LIFETIME: float = 0.6
const BURST_MIN_SPEED: float = 20.0
const BURST_MAX_SPEED: float = 60.0
const BURST_GRAVITY: float = 420.0

var patches: Array[Dictionary] = []
## cell -> its patch's index in `patches` (rebuilt with them): finding a cell's patch
## is one lookup, not a search through every patch.
var patch_of_cell: Dictionary = {}
## For tests: how many patches have finished crumbling.
var shatter_count: int = 0


## Cuts `cells` into patches. `crumble_test(cells: Array[Vector2i]) -> bool` says
## whether a patch may crumble at all; `trace(cells) -> Array[PackedVector2Array]` gives
## its outline. Crumbling carries over: a patch keeps the least time left of any of its
## cells (cells only merge or go away, so a crumbling patch never "un-crumbles").
func rebuild(cells: Array[Vector2i], crumble_test: Callable, trace: Callable) -> void:
	var old_crack_left: Dictionary = {}
	for patch: Dictionary in patches:
		if float(patch[&"crack_left"]) >= 0.0:
			for cell: Vector2i in patch[&"cells"]:
				old_crack_left[cell] = patch[&"crack_left"]
	patches.clear()
	patch_of_cell.clear()
	var unvisited: Dictionary = {}
	for cell: Vector2i in cells:
		unvisited[cell] = true
	while not unvisited.is_empty():
		var patch_cells: Array[Vector2i] = _flood(unvisited.keys()[0], unvisited)
		var crumbles: bool = crumble_test.call(patch_cells)
		var crack_left: float = -1.0
		if crumbles:
			for cell: Vector2i in patch_cells:
				if not old_crack_left.has(cell):
					continue
				var old_left: float = old_crack_left[cell]
				crack_left = old_left if crack_left < 0.0 else minf(crack_left, old_left)
		var loops: Array[PackedVector2Array] = trace.call(patch_cells)
		# The outline's length, px: the contour runs round it at a steady speed.
		var perimeter: float = 0.0
		for loop: PackedVector2Array in loops:
			for index: int in loop.size():
				perimeter += loop[index].distance_to(loop[(index + 1) % loop.size()])
		for cell: Vector2i in patch_cells:
			patch_of_cell[cell] = patches.size()
		patches.append({
			&"cells": patch_cells, &"can_crumble": crumbles, &"crack_left": crack_left,
			&"loops": loops, &"perimeter": perimeter,
		})


## The cells 8-connected to `start` among `unvisited` (taken out of it).
static func _flood(start: Vector2i, unvisited: Dictionary) -> Array[Vector2i]:
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


## The patch `cell` is in, as an index into `patches`, or -1.
func get_patch_index(cell: Vector2i) -> int:
	return patch_of_cell.get(cell, -1)


func can_crumble(cell: Vector2i) -> bool:
	var index: int = get_patch_index(cell)
	return index >= 0 and bool(patches[index][&"can_crumble"])


func is_crumbling(cell: Vector2i) -> bool:
	var index: int = get_patch_index(cell)
	return index >= 0 and float(patches[index][&"crack_left"]) >= 0.0


func has_crumbling() -> bool:
	for patch: Dictionary in patches:
		if float(patch[&"crack_left"]) >= 0.0:
			return true
	return false


## One physics frame for `layer` (the TileMapLayer whose cells these are): patches
## that can crumble start where something touches them (playing `crack_sound`), and
## crumbling ones count down. Returns the cells of each patch that is done (one array
## per patch); the caller takes them away. Nothing to do costs one pass over the patches.
func advance(layer: TileMapLayer, delta: float, crumble_time: float, crack_sound: StringName) -> Array[Array]:
	var has_waiting: bool = false
	for patch: Dictionary in patches:
		if bool(patch[&"can_crumble"]) and float(patch[&"crack_left"]) < 0.0:
			has_waiting = true
			break
	if has_waiting:
		_start_where_touched(layer, crumble_time, crack_sound)
	var done: Array[Array] = []
	for patch: Dictionary in patches:
		var crack_left: float = patch[&"crack_left"]
		if crack_left < 0.0:
			continue
		crack_left -= delta
		patch[&"crack_left"] = crack_left
		if crack_left <= 0.0:
			done.append(patch[&"cells"])
	shatter_count += done.size()
	return done


## Patches that can crumble and that you or a crate touch start crumbling. Each box is
## grown by 1 px: standing on a platform, your feet are on its top edge, not in it.
func _start_where_touched(layer: TileMapLayer, crumble_time: float, crack_sound: StringName) -> void:
	for member: Node in layer.get_tree().get_nodes_in_group(WaterWorld.SOLID_GROUP):
		if not member.has_method(&"get_water_box"):
			continue
		var box: Rect2 = member.call(&"get_water_box")
		if box.size.x <= 0.0:
			continue
		box = Rect2(layer.to_local(box.position), box.size).grow(1.0)
		var first: Vector2i = layer.local_to_map(box.position)
		# Just inside the far edge: a box ending exactly on a tile line doesn't reach the next tile.
		var last: Vector2i = layer.local_to_map(box.end - Vector2(0.01, 0.01))
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var index: int = get_patch_index(Vector2i(x, y))
				if index >= 0 and bool(patches[index][&"can_crumble"]) and float(patches[index][&"crack_left"]) < 0.0:
					patches[index][&"crack_left"] = get_time(patches[index], crumble_time)
					FX.play_sfx(crack_sound)


## How long `patch` takes to crumble, s: its own time if the level gave it one, else
## `default_time` (the tuning's).
static func get_time(patch: Dictionary, default_time: float) -> float:
	return float(patch.get(&"time", default_time))


## Painted platforms: gives each patch its own crumble time from `custom_times`
## (cell -> seconds, the layer's patch_crumble_times, set in the level editor). A
## patch takes the shortest time set on any of its cells; one with none set keeps
## the tuning's time. Call it after rebuild() (and whenever the times change).
func apply_custom_times(custom_times: Dictionary) -> void:
	for patch: Dictionary in patches:
		patch.erase(&"time")
		for cell: Vector2i in patch[&"cells"]:
			if custom_times.has(cell):
				patch[&"time"] = minf(float(patch.get(&"time", INF)), float(custom_times[cell]))


## A copy of `custom_times` where the patch made of `cells` crumbles in `seconds`:
## every entry on its cells goes, and one is set on its first cell, unless `seconds`
## is `default_time` (then the patch simply follows the tuning, and nothing is saved).
static func with_patch_time(custom_times: Dictionary, cells: Array, seconds: float,
		default_time: float) -> Dictionary:
	var result: Dictionary = custom_times.duplicate()
	for cell: Vector2i in cells:
		result.erase(cell)
	if not is_equal_approx(seconds, default_time) and not cells.is_empty():
		result[cells[0]] = seconds
	return result


## Where a patch is drawn this frame: shaking while it crumbles.
func get_shake(patch: Dictionary) -> Vector2:
	if float(patch[&"crack_left"]) < 0.0:
		return Vector2.ZERO
	return Vector2(randi_range(-1, 1), randi_range(-1, 1)) * SHAKE_PX


## The crumbling contour of `patch` on `canvas`: a bright line along its outline, as
## much of it as the time gone (0 at the touch, all the way round when it's done).
func draw_contour(canvas: CanvasItem, patch: Dictionary, crumble_time: float) -> void:
	var crack_left: float = patch[&"crack_left"]
	if crack_left < 0.0:
		return
	var share: float = clampf(1.0 - crack_left / maxf(get_time(patch, crumble_time), 0.01), 0.0, 1.0)
	var left: float = float(patch[&"perimeter"]) * share
	for loop: PackedVector2Array in patch[&"loops"]:
		for index: int in loop.size():
			if left <= 0.0:
				return
			var from: Vector2 = loop[index]
			var to: Vector2 = loop[(index + 1) % loop.size()]
			var edge_length: float = from.distance_to(to)
			var drawn_to: Vector2 = to if edge_length <= left else from.lerp(to, left / edge_length)
			canvas.draw_line(from, drawn_to, CONTOUR_COLOR, 1.0)
			left -= edge_length


## Hairline cracks across the tile whose top-left corner is `origin`, on `canvas`: a
## short zigzag, its shape picked by a hash of `cell` (the same tile always cracks the
## same way).
static func draw_cracks(canvas: CanvasItem, origin: Vector2, cell: Vector2i, color: Color) -> void:
	var hash_value: int = absi(cell.x * 73856093 ^ cell.y * 19349663)
	# Each "% 3" takes one base-3 digit of the hash: the crack's start and bend, 0-2 px each.
	var start: Vector2 = origin + Vector2(1 + hash_value % 3, 2 + floori(hash_value / 3.0) % 3)
	var middle: Vector2 = start + Vector2(3, 2 - floori(hash_value / 9.0) % 3)
	canvas.draw_line(start, middle, color, 1.0)
	canvas.draw_line(middle, middle + Vector2(2, 2), color, 1.0)


# --- Painted platforms: taking tiles away until the reset --------------------------

## The painted layers' end of a frame: each patch in `done` (advance's result) FALLS
## (after the W8c play-test: it used to vanish). `draw_patch(canvas: CanvasItem,
## patch: Dictionary)` is the layer's own drawing of one patch, in its local px: a
## CrumbleFall drops that picture away while the tiles (and their collision) are
## taken away at once, until the reset. A little dust (`pieces_per_tile` bits of
## `piece_color` per tile) and `break_sound` go with it. Returns true if any broke
## (the caller rebuilds its patches now, so the next frame's touch reads them).
## Call it BEFORE that rebuild: it reads the done patches from `patches`.
func break_patches(layer: TileMapLayer, done: Array[Array], removed: Dictionary,
		piece_color: Color, pieces_per_tile: int, break_sound: StringName, draw_patch: Callable) -> bool:
	for cells: Array in done:
		var index: int = get_patch_index(cells[0])
		if index >= 0:
			var patch: Dictionary = patches[index]
			# bind() adds the patch AFTER the arguments of the call: CrumbleFall calls it
			# with the canvas, so draw_patch gets (canvas, patch).
			CrumbleFall.spawn(layer, draw_patch.bind(patch), _get_center(layer, cells))
		for cell: Vector2i in cells:
			burst(layer, layer.map_to_local(cell), piece_color, pieces_per_tile)
		take_away(layer, cells, removed)
		FX.play_sfx(break_sound)
	return not done.is_empty()


## The middle of the box round `cells`, in `layer`'s local px (a falling patch spins round it).
static func _get_center(layer: TileMapLayer, cells: Array) -> Vector2:
	var box: Rect2 = Rect2(layer.map_to_local(cells[0]), Vector2.ZERO)
	for cell: Vector2i in cells:
		box = box.expand(layer.map_to_local(cell))
	return box.get_center()


## The painted layers' room reset (death or R): every patch caught mid-crumble stops
## (its countdown is cleared FIRST: the rebuild after put_back would otherwise carry it
## over and the patch would still fall, the bug found after the W8c play-test), and
## every broken patch is painted back (returns true: the caller rebuilds its patches).
func reset_painted(layer: TileMapLayer, removed: Dictionary) -> bool:
	for patch: Dictionary in patches:
		patch[&"crack_left"] = -1.0
	return put_back(layer, removed)


## Erases `cells` from `layer`, remembering each tile (source id and atlas coords) in
## `removed` for put_back(). The collision goes at once (update_internals), so what
## stood there falls this very frame; the room's water hears of it (_tell_water).
static func take_away(layer: TileMapLayer, cells: Array, removed: Dictionary) -> void:
	for cell: Vector2i in cells:
		if layer.get_cell_source_id(cell) == -1:
			continue
		removed[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell)]
		layer.erase_cell(cell)
	layer.update_internals()
	_tell_water(layer, true)


## Room reset: every tile in `removed` is painted back. Returns true if any was.
static func put_back(layer: TileMapLayer, removed: Dictionary) -> bool:
	if removed.is_empty():
		return false
	for cell: Vector2i in removed:
		var tile: Array = removed[cell]
		layer.set_cell(cell, tile[0], tile[1])
	removed.clear()
	layer.update_internals()
	_tell_water(layer, false)
	return true


## The room's WaterWorld (if it has water) re-reads which tiles are solid; when ground
## went away (`ground_lost`), water standing on it falls and loose water wakes up.
static func _tell_water(layer: TileMapLayer, ground_lost: bool) -> void:
	var world: WaterWorld = layer.get_parent().get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	if world == null or not world.is_node_ready():
		return
	if ground_lost:
		world.terrain_changed()
	else:
		world.refresh_solid_cells()


## A one-shot burst of `amount` bits of `color` at `layer`-local `point` (a crumbled
## platform's pieces). Added to the current scene, so the bits stay where they were made.
static func burst(layer: Node2D, point: Vector2, color: Color, amount: int) -> void:
	var scene: Node = layer.get_tree().current_scene
	if scene == null or amount <= 0:
		return
	var bits: CPUParticles2D = CPUParticles2D.new()
	bits.one_shot = true
	bits.explosiveness = 1.0  # all at once
	bits.amount = amount
	bits.lifetime = BURST_LIFETIME
	bits.direction = Vector2.UP
	bits.spread = 180.0
	bits.gravity = Vector2(0.0, BURST_GRAVITY)  # pieces fall
	bits.initial_velocity_min = BURST_MIN_SPEED
	bits.initial_velocity_max = BURST_MAX_SPEED
	bits.scale_amount_min = 1.0
	bits.scale_amount_max = 2.0
	bits.color = color
	bits.global_position = layer.to_global(point)
	scene.add_child(bits)
	bits.emitting = true
	bits.finished.connect(bits.queue_free)

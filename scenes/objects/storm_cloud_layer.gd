class_name StormCloudLayer
extends TileMapLayer
## StormCloudLayer: STORM CLOUD painted into a level, a deadly area that only stops
## the player (asked for after the W8c play-test: "a deadly obstacle that objects can
## pass through"). A TileMapLayer named "StormCloud", painted from the editor's Terrain
## tab with resources/tiles/storm_cloud_tileset.tres: one see-through slate tile with
## NO collision, so crates, rocks, fireballs, water, enemies and gusts all pass
## through. Touching it kills YOU.
##
## Why a cloud (and not poison gas)? It's the air bender's world: a thundercloud
## reads as "soft, things go through it" and its dark slate as "but it hurts", and
## its slate-violet doesn't clash with the green of grass and thicket.
##
## The kill (_physics_process, only in the room you're in): the player's hitbox,
## shrunk by KILL_INSET px on each side (fair, like spikes: grazing the fluffy edge is
## safe), is checked against the painted cells. A hit calls Player.die(), which
## respects the play-test's invincibility cheat.
##
## Not solid ANYWHERE: the room's WaterWorld, FireGrid, earth, grass, ice and crumbling
## layers skip it when they collect the room's solid tiles (they check
## `is StormCloudLayer`, like they skip WaterLayer and HiddenLayer); the editor map
## and RoomEdgeRim only count layers with collision, which it has none of.
##
## THE LOOK: the tiles themselves are drawn invisible (self_modulate); a child node
## (CloudLook) draws the whole layer as a picture (one per cluster of cells, see
## PERFORMANCE) in the ground's style (GroundPainter,
## PatchPainter): a lit CRUST along the open edges (lightest on top), a dark EDGE LINE
## where it ends, then a darker HATCHED inside, all see-through. The shape isn't the
## tile grid: the painted cells are blurred and cut off at a noisy level, so edges
## bulge and dip in soft puffs and corners round off (no bricks). The picture is
## painted when the cells change, and the node's alpha breathes slowly. It shows in the
## level editor too, so the hazard reads while you build.

## Shrinks the player's hitbox before the check, px per side: grazing is safe.
const KILL_INSET: float = 1.5
## Palette (all see-through, no outline): lit top rim, crust, underside, inside, inside hatch.
const RIM_COLOR: Color = Color8(168, 84, 214, 150)
const CRUST_COLOR: Color = Color8(128, 52, 178, 140)
const UNDERSIDE_COLOR: Color = Color8(100, 34, 150, 140)
const INSIDE_COLOR: Color = Color8(84, 22, 124, 150)
const HATCH_COLOR: Color = Color8(98, 30, 142, 150)
## The outermost pixels' share of full opacity: the fog thins out toward the air.
const EDGE_ALPHA: float = 0.3
## Margin round the cells for the puffs that bulge outward, px.
const MARGIN: int = 8
## The puff lobes' radius range, px (one per open tile side).
const PUFF_MIN_RADIUS: float = 2.5
const PUFF_MAX_RADIUS: float = 4.0
## The blur radius (px, box blur run twice) that rounds the corners and softens the edge.
const BLUR_RADIUS: int = 2
## The cut level at a straight edge (below 0.5: the cloud bulges a little past its cells,
## so thin strips keep their body) and how far the noise moves it either way.
const CUT_LEVEL: float = 0.5
const PUFF_STRENGTH: float = 0.18
## The puff noise's grid spacing, px (bigger = broader puffs).
const PUFF_SPACING: float = 7.0
## Crust thickness, px, plus up to CRUST_WOBBLE where the noise is high.
const CRUST_WIDTH: float = 3.0
const CRUST_WOBBLE: float = 1.5
## Diagonal hatch: a stripe HATCH_WIDTH px wide every HATCH_PERIOD px.
const HATCH_PERIOD: int = 6
const HATCH_WIDTH: int = 2
## The inside darkens to this fraction over INSIDE_FADE_DEPTH px.
const INSIDE_DEEPEST_BRIGHTNESS: float = 0.55
const INSIDE_FADE_DEPTH: float = 8.0
## Breathing: the look's alpha swings between 1 - BREATH_DEPTH and 1, one cycle per BREATH_PERIOD s.
const BREATH_DEPTH: float = 0.12
const BREATH_PERIOD: float = 4.0
## Distance given to cloud pixels before the sweeps (bigger than any real distance).
const FAR: float = 1000.0
## Cells this many tiles apart (or closer) belong to the same CLUSTER (see PERFORMANCE):
## a cell's puffs and blur reach MARGIN px past it, so cells with 2 empty tiles or more
## between them never touch the same pixel.
const CLUSTER_REACH: int = 3
## How many cluster pictures the cache keeps (oldest dropped first). A big room's
## picture is a few MB at most; most are tiny.
const PICTURE_CACHE_SIZE: int = 256

## PERFORMANCE (the editor got slow on a level with big storm rooms): painting is
## per-pixel GDScript, ~5 µs a pixel, and one picture of the whole layer's bounding
## box was mostly empty air (a tall room: 400 000 pixels for 600 cells, 4 s). So:
##   - the cells are split into CLUSTERS that can't affect each other's pixels, each
##     painted as its own small picture (the same pixels as one big picture);
##   - each cluster's picture is CACHED by its exact cells (a static dictionary shared
##     by every StormCloudLayer): a stroke elsewhere in the room, an undo back, and the
##     play-test's copy of the level all reuse it instead of painting it again;
##   - the slow noise is only worked out on the soft edge (see _paint_cluster).
## Static = belongs to the class, not to one layer (like a Python class attribute).
static var picture_cache: Dictionary = {}

## The painted cells, cached (rebuilt when the tiles change).
var cells: Array[Vector2i] = []
var look_node: Node2D
## One [ImageTexture, origin (Vector2, layer-local px)] per cluster.
var pictures: Array[Array] = []
var breath_time: float = 0.0
var is_rebuild_queued: bool = false


func _ready() -> void:
	# The tile's own square is not drawn; CloudLook draws the cloud instead.
	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	look_node = Node2D.new()
	look_node.name = "CloudLook"
	look_node.draw.connect(_draw_look)
	add_child(look_node)
	# `changed` fires when the tiles change (the editor paints or erases).
	changed.connect(_queue_rebuild)
	_rebuild()


## The level editor, after a stroke or an undo: the cells may have changed
## (TileMapLayer's `changed` signal doesn't fire for every cell edit).
func rebuild_look() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if is_rebuild_queued:
		return
	is_rebuild_queued = true
	_rebuild.call_deferred()


## Caches the cells and paints the picture (unless the cells are what they were:
## the editor asks after every stroke, most of which don't touch this layer).
func _rebuild() -> void:
	is_rebuild_queued = false
	var new_cells: Array[Vector2i] = get_used_cells()
	new_cells.sort()  # the same cells in any order compare equal
	if new_cells == cells and (cells.is_empty() or not pictures.is_empty()):
		return
	cells = new_cells
	_paint_picture()
	look_node.queue_redraw()


func _process(delta: float) -> void:
	if cells.is_empty():
		return
	breath_time += delta
	# A slow swell of the whole cloud's alpha.
	look_node.modulate.a = 1.0 - BREATH_DEPTH * (0.5 + 0.5 * sin(TAU * breath_time / BREATH_PERIOD))


func _physics_process(_delta: float) -> void:
	# Only the room you're in can kill (in the level editor that's never).
	if cells.is_empty() or GameState.current_room != get_parent():
		return
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead():
		return
	if touches_cloud(player.get_hitbox_rect().grow(-KILL_INSET)):
		player.die()


## Does `global_box` overlap any painted cell? (The player check; tests use it too.)
func touches_cloud(global_box: Rect2) -> bool:
	var local_box: Rect2 = Rect2(to_local(global_box.position), global_box.size)
	var first: Vector2i = local_to_map(local_box.position)
	# Just inside the far edge: a box ending exactly on a tile line doesn't reach the next tile.
	var last: Vector2i = local_to_map(local_box.end - Vector2(0.01, 0.01))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			if get_cell_source_id(Vector2i(x, y)) != -1:
				return true
	return false


# --- The look ------------------------------------------------------------------------

func _draw_look() -> void:
	if cells.is_empty():
		return
	for picture: Array in pictures:
		look_node.draw_texture(picture[0] as ImageTexture, picture[1] as Vector2)


## Paints the layer (see THE LOOK and PERFORMANCE): one picture per cluster, from
## the cache when that cluster was painted before.
func _paint_picture() -> void:
	pictures.clear()
	if cells.is_empty():
		return
	var tile: int = tile_set.tile_size.x
	for cluster: Array[Vector2i] in _find_clusters(cells, tile):
		var key: int = cluster.hash()
		var cached: Array = picture_cache.get(key, [])
		# The cells are stored too: two different clusters could share a hash.
		if cached.is_empty() or cached[0] != cluster or cached[3] != tile:
			cached = [cluster] + _paint_cluster(cluster, tile) + [tile]
			if picture_cache.size() >= PICTURE_CACHE_SIZE:
				picture_cache.erase(picture_cache.keys()[0])  # dictionaries keep insertion order
			picture_cache[key] = cached
		pictures.append([cached[1], cached[2]])


## Splits `all_cells` (sorted) into clusters whose pictures can't overlap: cells within
## CLUSTER_REACH tiles of each other join one cluster (a flood fill), then clusters
## whose pictures (bounding boxes plus MARGIN) would overlap are merged, so a cloud
## ring and the air it walls in are always painted together. Each cluster comes back
## sorted, so the same cells always give the same cache key.
static func _find_clusters(all_cells: Array[Vector2i], tile: int) -> Array[Array]:
	var remaining: Dictionary = {}
	for cell: Vector2i in all_cells:
		remaining[cell] = true
	var groups: Array[Array] = []  # [cells, picture rect in px]
	for start: Vector2i in all_cells:
		if not remaining.has(start):
			continue
		remaining.erase(start)
		var group: Array[Vector2i] = [start]
		var to_visit: Array[Vector2i] = [start]
		while not to_visit.is_empty():
			var cell: Vector2i = to_visit.pop_back()
			for dy: int in range(-CLUSTER_REACH, CLUSTER_REACH + 1):
				for dx: int in range(-CLUSTER_REACH, CLUSTER_REACH + 1):
					var neighbour: Vector2i = cell + Vector2i(dx, dy)
					if remaining.has(neighbour):
						remaining.erase(neighbour)
						group.append(neighbour)
						to_visit.append(neighbour)
		groups.append([group, _picture_rect(group, tile)])
	# Merge clusters whose pictures overlap, until none do.
	var merged_any: bool = true
	while merged_any:
		merged_any = false
		for a: int in groups.size():
			for b: int in range(a + 1, groups.size()):
				if (groups[a][1] as Rect2i).intersects(groups[b][1] as Rect2i):
					var joined: Array[Vector2i] = []
					joined.append_array(groups[a][0])
					joined.append_array(groups[b][0])
					groups[a] = [joined, _picture_rect(joined, tile)]
					groups.remove_at(b)
					merged_any = true
					break
			if merged_any:
				break
	var clusters: Array[Array] = []
	for group: Array in groups:
		var cluster: Array[Vector2i] = []
		cluster.assign(group[0])
		cluster.sort()
		clusters.append(cluster)
	return clusters


## The picture a cluster paints, in layer px: its cells' bounding box plus MARGIN.
static func _picture_rect(cluster: Array[Vector2i], tile: int) -> Rect2i:
	var first: Vector2i = cluster[0]
	var last: Vector2i = cluster[0]
	for cell: Vector2i in cluster:
		first = first.min(cell)
		last = last.max(cell)
	return Rect2i(first * tile - Vector2i.ONE * MARGIN, (last - first + Vector2i.ONE) * tile + Vector2i.ONE * MARGIN * 2)


## Paints one cluster as one picture (see THE LOOK): mask from the cells, blur,
## noisy threshold, distance from the air, colors. Returns [ImageTexture, origin].
static func _paint_cluster(cluster: Array[Vector2i], tile: int) -> Array:
	var rect: Rect2i = _picture_rect(cluster, tile)
	var origin: Vector2i = rect.position
	var size: Vector2i = rect.size
	# 1. The mask: 1.0 on every pixel of a painted cell.
	var density: PackedFloat32Array = PackedFloat32Array()
	density.resize(size.x * size.y)
	for cell: Vector2i in cluster:
		var corner: Vector2i = cell * tile - origin
		for y: int in tile:
			for x: int in tile:
				density[(corner.y + y) * size.x + corner.x + x] = 1.0
	# 1b. PUFFS: a couple of round lobes of varying size on every open side of a cell,
	# stamped into the mask, so the outline bulges like a cloud instead of following the grid.
	var painted: Dictionary = {}
	for cell: Vector2i in cluster:
		painted[cell] = true
	for cell: Vector2i in cluster:
		for outward: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if painted.has(cell + outward):
				continue  # more cloud there: no edge
			var along: Vector2 = Vector2.RIGHT if outward.y != 0 else Vector2.DOWN
			var side_middle: Vector2 = Vector2(cell * tile - origin) + Vector2.ONE * (tile * 0.5) + Vector2(outward) * (tile * 0.5)
			# One lobe per side, about as wide as the side so neighbours leave a dip
			# between them (smaller lobes close together would merge into a flat edge).
			var roll: float = _hash01(cell * 4 + outward * 2 + Vector2i(1, 5))
			var roll_size: float = _hash01(cell * 6 + outward * 3 + Vector2i(2, 9))
			var radius: float = PUFF_MIN_RADIUS + roll_size * (PUFF_MAX_RADIUS - PUFF_MIN_RADIUS)
			# Centered on the cell's edge (so it never reaches further out than its radius),
			# nudged along the side.
			_stamp_disc(density, size, side_middle + along * ((roll - 0.5) * 0.5 * tile), radius)
	# 2. Blur twice (a soft, roundish falloff), then cut at a noisy level: the puffs.
	density = _box_blur(density, size, BLUR_RADIUS)
	density = _box_blur(density, size, BLUR_RADIUS)
	var is_cloud: PackedByteArray = PackedByteArray()
	is_cloud.resize(size.x * size.y)
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(size.x * size.y)
	# The noisy cut level always lies between these two, so the noise (the slow part,
	# eight hashes a pixel) is only worked out on the soft edge in between: far out in
	# the air or deep inside, the answer is the same whatever the noise says.
	var lowest_cut: float = CUT_LEVEL - PUFF_STRENGTH
	var highest_cut: float = CUT_LEVEL + PUFF_STRENGTH
	for y: int in size.y:
		for x: int in size.x:
			var index: int = y * size.x + x
			var value: float = density[index]
			if value <= lowest_cut:
				continue  # air whatever the noise
			if value <= highest_cut:
				var level: float = CUT_LEVEL + (_puff_noise(origin + Vector2i(x, y)) - 0.5) * PUFF_STRENGTH * 2.0
				if value <= level:
					continue
			is_cloud[index] = 1
			distances[index] = FAR
	_fill_enclosed_air(is_cloud, distances, size)
	# 3. Distance from the air (two sweeps: each pixel takes its neighbours' smallest + 1).
	_sweep_forward(distances, size)
	_sweep_backward(distances, size)
	# 4. Colors.
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var index: int = y * size.x + x
			if is_cloud[index] == 0:
				continue
			var pixel: Vector2i = origin + Vector2i(x, y)
			var is_top: bool = y > 0 and is_cloud[index - size.x] == 0
			var is_bottom: bool = y < size.y - 1 and is_cloud[index + size.x] == 0
			image.set_pixel(x, y, _get_color(pixel, distances[index], is_top, is_bottom))
	return [ImageTexture.create_from_image(image), Vector2(origin)]


## The color of a cloud pixel `distance` px from the air.
static func _get_color(pixel: Vector2i, distance: float, is_top: bool, is_bottom: bool) -> Color:
	var depth: float = distance - 1.0  # 0 on the outermost pixel
	var crust_end: float = CRUST_WIDTH + _noise(pixel) * CRUST_WOBBLE
	# Fog, not rock: no edge line. The rim/crust tint blends into the inside, and the
	# whole thing fades to transparent toward the open air.
	var inside: Color = HATCH_COLOR if posmod(pixel.x + pixel.y, HATCH_PERIOD) < HATCH_WIDTH else INSIDE_COLOR
	var depth_in: float = smoothstep(0.0, crust_end + 1.0, depth)
	var rim: Color = RIM_COLOR if is_top else (UNDERSIDE_COLOR if is_bottom else CRUST_COLOR)
	var result: Color = rim.lerp(inside, depth_in)
	var deep: float = smoothstep(0.0, INSIDE_FADE_DEPTH, depth - crust_end)
	# darkened(), not `color * factor`: multiplying a Color would scale its alpha too.
	result = result.darkened(1.0 - lerpf(1.0, INSIDE_DEEPEST_BRIGHTNESS, deep))
	result.a *= lerpf(EDGE_ALPHA, 1.0, depth_in)
	return result


## Air the puffs wall in (a pinhole in a notch) would show as a ring: finds the air
## reachable from the picture's border and turns all other air into cloud.
static func _fill_enclosed_air(is_cloud: PackedByteArray, distances: PackedFloat32Array, size: Vector2i) -> void:
	var is_outside: PackedByteArray = PackedByteArray()
	is_outside.resize(size.x * size.y)
	var to_visit: Array[int] = []
	for x: int in size.x:
		to_visit.append(x)
		to_visit.append((size.y - 1) * size.x + x)
	for y: int in size.y:
		to_visit.append(y * size.x)
		to_visit.append(y * size.x + size.x - 1)
	while not to_visit.is_empty():
		var index: int = to_visit.pop_back()
		if is_outside[index] == 1 or is_cloud[index] == 1:
			continue
		is_outside[index] = 1
		var x: int = index % size.x
		if x > 0:
			to_visit.append(index - 1)
		if x < size.x - 1:
			to_visit.append(index + 1)
		if index >= size.x:
			to_visit.append(index - size.x)
		if index < size.x * (size.y - 1):
			to_visit.append(index + size.x)
	for index: int in is_cloud.size():
		if is_cloud[index] == 0 and is_outside[index] == 0:
			is_cloud[index] = 1
			distances[index] = FAR


## Sets every pixel within `radius` of `center` (picture px) to 1.0.
static func _stamp_disc(values: PackedFloat32Array, size: Vector2i, center: Vector2, radius: float) -> void:
	var first_y: int = maxi(floori(center.y - radius), 0)
	var last_y: int = mini(ceili(center.y + radius), size.y - 1)
	var first_x: int = maxi(floori(center.x - radius), 0)
	var last_x: int = mini(ceili(center.x + radius), size.x - 1)
	for y: int in range(first_y, last_y + 1):
		for x: int in range(first_x, last_x + 1):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(center) <= radius * radius:
				values[y * size.x + x] = 1.0


## A box blur of `values` (a `size` picture) with the given radius: separable (rows,
## then columns), each with a running sum, edges counted as empty.
static func _box_blur(values: PackedFloat32Array, size: Vector2i, radius: int) -> PackedFloat32Array:
	var width: float = float(radius * 2 + 1)
	var across: PackedFloat32Array = PackedFloat32Array()
	across.resize(values.size())
	for y: int in size.y:
		var running: float = 0.0
		for x: int in range(0, radius):
			running += values[y * size.x + x]
		for x: int in size.x:
			if x + radius < size.x:
				running += values[y * size.x + x + radius]
			if x - radius - 1 >= 0:
				running -= values[y * size.x + x - radius - 1]
			across[y * size.x + x] = running / width
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(values.size())
	for x: int in size.x:
		var running: float = 0.0
		for y: int in range(0, radius):
			running += across[y * size.x + x]
		for y: int in size.y:
			if y + radius < size.y:
				running += across[(y + radius) * size.x + x]
			if y - radius - 1 >= 0:
				running -= across[(y - radius - 1) * size.x + x]
			result[y * size.x + x] = running / width
	return result


## Distance transform, forward sweep (top-left to bottom-right): each pixel takes its
## already-passed neighbours' smallest distance + 1 (+ 1.41 diagonally).
static func _sweep_forward(distances: PackedFloat32Array, size: Vector2i) -> void:
	for y: int in size.y:
		for x: int in size.x:
			var index: int = y * size.x + x
			var best: float = distances[index]
			if best <= 0.0:
				continue
			if x > 0:
				best = minf(best, distances[index - 1] + 1.0)
			if y > 0:
				best = minf(best, distances[index - size.x] + 1.0)
				if x > 0:
					best = minf(best, distances[index - size.x - 1] + 1.41)
				if x < size.x - 1:
					best = minf(best, distances[index - size.x + 1] + 1.41)
			distances[index] = best


## The backward sweep: the mirror of _sweep_forward.
static func _sweep_backward(distances: PackedFloat32Array, size: Vector2i) -> void:
	for y: int in range(size.y - 1, -1, -1):
		for x: int in range(size.x - 1, -1, -1):
			var index: int = y * size.x + x
			var best: float = distances[index]
			if best <= 0.0:
				continue
			if x < size.x - 1:
				best = minf(best, distances[index + 1] + 1.0)
			if y < size.y - 1:
				best = minf(best, distances[index + size.x] + 1.0)
				if x < size.x - 1:
					best = minf(best, distances[index + size.x + 1] + 1.41)
				if x > 0:
					best = minf(best, distances[index + size.x - 1] + 1.41)
			distances[index] = best


## Smooth 0..1 "value noise" at `pixel`: random numbers on a coarse grid, blended
## between its points (the same every run, so the cloud never jumps).
static func _noise(pixel: Vector2i) -> float:
	var grid_x: float = float(pixel.x) / PUFF_SPACING
	var grid_y: float = float(pixel.y) / PUFF_SPACING
	var corner: Vector2i = Vector2i(floori(grid_x), floori(grid_y))
	var share_x: float = smoothstep(0.0, 1.0, grid_x - corner.x)
	var share_y: float = smoothstep(0.0, 1.0, grid_y - corner.y)
	var top: float = lerpf(_hash01(corner), _hash01(corner + Vector2i.RIGHT), share_x)
	var bottom: float = lerpf(_hash01(corner + Vector2i.DOWN), _hash01(corner + Vector2i.ONE), share_x)
	return lerpf(top, bottom, share_y)


## The puffs' noise: two sizes blended, broad lobes with smaller bumps on them.
static func _puff_noise(pixel: Vector2i) -> float:
	return 0.65 * _noise(pixel) + 0.35 * _noise(pixel * 2 + Vector2i(31, 17))


## A steady 0..1 number for a grid point (the same every run).
static func _hash01(point: Vector2i) -> float:
	return float(absi(point.x * 73856093 ^ point.y * 19349663) % 1000) / 999.0

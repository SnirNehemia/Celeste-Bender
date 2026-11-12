class_name PatchPainter
extends RefCounted
## PatchPainter: paints ONE patch of a self-drawn ground layer (crumbling rock, falling
## blocks) as a small picture that looks like the room's ground (GroundPainter,
## scenes/objects/earth/ground_painter.gd), in the patch's own palette. After the
## falling-block play-test: "make it the same as the ground ... add some texture in
## the middle too".
##
## Used by CrumbleRockLayer, CrumbleIceLayer, FallingBlockLayer and FallingIceLayer:
## one picture per patch, so a patch
## can shake (and a block fall) on its own; the GroundPainter paints the whole room as
## one picture. Static functions only: paint() makes one picture, paint_patches() gives
## every patch of a CrumblePatches its picture and keeps the ones already painted.
##
## HOW (the GroundPainter's three steps, at patch size):
##   1. MASK: which pixels are the patch. Sides open to the air are DENTED 1-2 px at
##      hashed spots and bottom corners are ROUNDED, like the ground; a pixel outside
##      the patch is GROUND too if another solid layer has a tile there (no crust
##      against rock it leans on), else AIR.
##   2. DISTANCE from the air, px, by a distance transform (two sweeps, each pixel
##      taking its neighbours' smallest distance + 1, or + 1.41 diagonally).
##   3. COLOR from the distance: a bright CRUST with a lighter RIM on top, a darker
##      EDGE LINE where the crust ends, then a dark HATCHED inside darkening further in.
##      Over that, the patch's GRAIN, the texture in the middle (Grain): cracks for
##      crumbling rock, basalt's column joints for falling blocks, so even a one tile
##      tall platform (all crust) isn't one flat color.
## A patch is a few hundred tiles at most: a few thousand to some ten thousand pixels,
## painted once when the patch is built (the layers keep the picture until its cells
## change). The work per pixel is kept small: "is other ground there?" is asked once
## per CELL, not per pixel, and the sweeps make no arrays.

## The texture over the patch (step 3).
enum Grain {
	CRACKED,  ## crumbling rock: a hair crack per tile, zigzagging
	COLUMNS,  ## basalt: vertical joints between columns, short cross joints, glints
}

## Palette indexes (each palette below is in this order).
const CRUST: int = 0
const RIM: int = 1
const EDGE: int = 2
const INSIDE: int = 3
const HATCH: int = 4
## Flecks in the crust: darker specks for rock, pale glints for basalt.
const FLECK: int = 5
## The grain's lines in the dark inside (lighter than the inside, so they show).
const GRAIN_INSIDE: int = 6

## Crumbling rock (after the W8c play-test): the grey rock's colors, a little warmer
## and lighter, so it reads as the same kind of ground but not the same ground.
const ROCK_PALETTE: Array[Color] = [Color(0.5, 0.46, 0.42), Color(0.66, 0.61, 0.55),
	Color(0.22, 0.19, 0.18), Color(0.2, 0.17, 0.16), Color(0.28, 0.24, 0.22),
	Color(0.38, 0.34, 0.31), Color(0.42, 0.37, 0.33)]
## Falling blocks: basalt, a very dark crust with a faint blue in it, a cold blue rim.
const BASALT_PALETTE: Array[Color] = [Color(0.12, 0.13, 0.19), Color(0.31, 0.36, 0.49),
	Color(0.04, 0.04, 0.07), Color(0.07, 0.075, 0.11), Color(0.1, 0.105, 0.15),
	Color(0.36, 0.43, 0.58), Color(0.19, 0.21, 0.3)]

## Crumbling ice (after the crumbling-ice play-test: "match the crumbling rocks"): the
## same ground look in ice colors, a pale blue crust with a near-white rim, a deep blue
## hatched inside, white glints for flecks (with the CRACKED grain, like the rock).
const ICE_PALETTE: Array[Color] = [Color(0.55, 0.78, 0.9), Color(0.86, 0.96, 1.0),
	Color(0.2, 0.4, 0.58), Color(0.13, 0.28, 0.43), Color(0.19, 0.36, 0.53),
	Color(0.95, 1.0, 1.0), Color(0.36, 0.58, 0.75)]
## Falling ice: DARKER ice, a steel-blue crust, a cold pale rim, an inky inside (with
## the COLUMNS grain: the joints read as stacked blocks of ice).
const DARK_ICE_PALETTE: Array[Color] = [Color(0.22, 0.38, 0.55), Color(0.52, 0.72, 0.87),
	Color(0.05, 0.1, 0.18), Color(0.06, 0.13, 0.22), Color(0.09, 0.18, 0.29),
	Color(0.75, 0.9, 1.0), Color(0.2, 0.34, 0.5)]

## Crust thickness, px (from open air to where the edge line starts), plus up to
## CRUST_WOBBLE more where the noise is high: the ground's values.
const CRUST_WIDTH: float = 5.0
const CRUST_WOBBLE: float = 2.0
## The wobble's random grid, px apart (the ground's).
const CRUST_NOISE_SPACING: int = 5
## Diagonal hatch on the inside: a stripe HATCH_WIDTH px wide every HATCH_PERIOD px.
const HATCH_PERIOD: int = 6
const HATCH_WIDTH: int = 2
## Right past the edge line the inside is this fraction of its color, darkening over
## INSIDE_FADE_DEPTH px down to INSIDE_DEEPEST_BRIGHTNESS (the ground's values).
const INSIDE_EDGE_BRIGHTNESS: float = 0.7
const INSIDE_FADE_DEPTH: float = 10.0
const INSIDE_DEEPEST_BRIGHTNESS: float = 0.12
## Dents on sides open to the air, like the ground's: the chance (0..1) that a 2 px
## stretch is dented 1 px in, and 2 px in (never 2 on top: feet would float).
const EDGE_DENT_CHANCE: float = 0.35
const DEEP_DENT_CHANCE: float = 0.15
## Bottom convex corners: pixels with (distance from the corner along x + along y)
## below this are cut off.
const CORNER_CUT: int = 3
## About one crust pixel in this many is a fleck: rock's dark specks are common,
## basalt's bright glints rare.
const FLECK_EVERY: Dictionary = {Grain.CRACKED: 23, Grain.COLUMNS: 61}
## The grain's lines in the inside darken less deep in than the inside does (down to
## this fraction), so the middle of a big patch keeps its texture.
const GRAIN_DEEPEST_BRIGHTNESS: float = 0.45
## COLUMNS: a joint every COLUMN_WIDTH px across, shifted by up to 2 px per band of
## COLUMN_BAND_HEIGHT px (columns aren't perfectly straight), with a cross joint at
## the top of about one band in CROSS_JOINT_EVERY.
const COLUMN_WIDTH: int = 6
const COLUMN_BAND_HEIGHT: int = 9
const CROSS_JOINT_EVERY: int = 3
## Distance given to pixels not reached from any air (deep in, or no air at all).
const FAR: float = 1000.0

## Mask values.
const AIR: int = 0
const PATCH: int = 1
const OTHER_GROUND: int = 2


## Gives every patch of `patches` (CrumblePatches.patches) its picture,
## patch[&"picture"], reusing the ones in `cache` (the cells as a sorted string ->
## picture) and painting the rest. Returns the new cache: pictures of patches that
## are gone (crumbled, repainted) are let go.
static func paint_patches(patches: Array[Dictionary], cache: Dictionary, tile_px: Vector2i,
		is_other_ground: Callable, palette: Array[Color], grain: Grain) -> Dictionary:
	var kept: Dictionary = {}
	for patch: Dictionary in patches:
		var key: String = get_key(patch[&"cells"])
		if not cache.has(key):
			cache[key] = paint(patch[&"cells"], tile_px, is_other_ground, palette, grain)
		kept[key] = cache[key]
		patch[&"picture"] = kept[key]
	return kept


## A patch's cells as one string, the same whatever their order: the cache's key.
static func get_key(cells: Array) -> String:
	var sorted_cells: Array = cells.duplicate()
	sorted_cells.sort()
	return str(sorted_cells)


## The picture of the patch `cells` (cells of a TileMapLayer of `tile_px` tiles), as
## [texture: ImageTexture, origin: Vector2 (layer-local px of its top-left)].
## `is_other_ground(cell) -> bool`: is a tile of another solid layer there?
static func paint(cells: Array, tile_px: Vector2i, is_other_ground: Callable,
		palette: Array[Color], grain: Grain) -> Array:
	var tile: int = tile_px.x  # tiles are square
	var in_patch: Dictionary = {}
	var first: Vector2i = cells[0]
	var last: Vector2i = cells[0]
	for cell: Vector2i in cells:
		in_patch[cell] = true
		first = first.min(cell)
		last = last.max(cell)
	# The cells round the patch: other ground or air? Asked once per cell here.
	var other_ground: Dictionary = {}
	for y: int in range(first.y - 1, last.y + 2):
		for x: int in range(first.x - 1, last.x + 2):
			var cell: Vector2i = Vector2i(x, y)
			if not in_patch.has(cell) and is_other_ground.call(cell):
				other_ground[cell] = true
	# One px of margin round the patch: the air (or ground) its faces look out on.
	var origin_px: Vector2i = first * tile - Vector2i.ONE
	var size: Vector2i = (last - first + Vector2i.ONE) * tile + Vector2i.ONE * 2
	# 1. The mask.
	var kinds: PackedByteArray = PackedByteArray()
	kinds.resize(size.x * size.y)  # all AIR (0)
	for y: int in size.y:
		for x: int in size.x:
			var pixel: Vector2i = origin_px + Vector2i(x, y)
			var cell: Vector2i = Vector2i(floori(float(pixel.x) / tile), floori(float(pixel.y) / tile))
			if other_ground.has(cell):
				kinds[y * size.x + x] = OTHER_GROUND
	for cell: Vector2i in cells:
		_mask_cell(kinds, size, origin_px, cell, tile, in_patch, other_ground)
	# 2. The distances: 0 in the air, FAR on ground, then the two sweeps.
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(size.x * size.y)
	for index: int in kinds.size():
		distances[index] = 0.0 if kinds[index] == AIR else FAR
	_sweep_forward(distances, size)
	_sweep_backward(distances, size)
	# 3. The colors, for the patch's pixels only.
	var grain_pixels: Dictionary = _find_crack_pixels(cells, tile) if grain == Grain.CRACKED else {}
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var index: int = y * size.x + x
			if kinds[index] != PATCH:
				continue
			# The pixel straight above is air: a top surface, it gets the rim.
			var is_top: bool = y > 0 and kinds[index - size.x] == AIR
			var pixel: Vector2i = origin_px + Vector2i(x, y)
			var is_grain: bool = grain_pixels.has(pixel) if grain == Grain.CRACKED else _is_column_joint(pixel)
			image.set_pixel(x, y, _get_color(pixel, distances[index], is_top, is_grain, palette, grain))
	return [ImageTexture.create_from_image(image), Vector2(origin_px)]


## One patch cell's pixels: all PATCH if no side is open to the air; else dented and
## (bottom corners) rounded like the ground's (GroundPainter._make_inside_test).
static func _mask_cell(kinds: PackedByteArray, size: Vector2i, origin_px: Vector2i, cell: Vector2i,
		tile: int, in_patch: Dictionary, other_ground: Dictionary) -> void:
	var is_open: Callable = func(next: Vector2i) -> bool:
		return not in_patch.has(next) and not other_ground.has(next)
	var open_up: bool = is_open.call(cell + Vector2i.UP)
	var open_down: bool = is_open.call(cell + Vector2i.DOWN)
	var open_left: bool = is_open.call(cell + Vector2i.LEFT)
	var open_right: bool = is_open.call(cell + Vector2i.RIGHT)
	var corner: Vector2i = cell * tile  # the cell's top-left, layer px
	var last: int = tile - 1
	# Dent depth per pixel along each side: top/bottom per column, left/right per row.
	var top: PackedInt32Array = PackedInt32Array()
	var bottom: PackedInt32Array = PackedInt32Array()
	var left: PackedInt32Array = PackedInt32Array()
	var right: PackedInt32Array = PackedInt32Array()
	for i: int in tile:
		top.append(_get_dent(open_up, corner.x + i, corner.y, 0))
		bottom.append(_get_dent(open_down, corner.x + i, corner.y + tile, 1))
		left.append(_get_dent(open_left, corner.y + i, corner.x, 2))
		right.append(_get_dent(open_right, corner.y + i, corner.x + tile, 3))
	# No dents on the two outermost pixels of a top surface at a platform's edge:
	# that's exactly where an edge-standing player's feet are.
	if open_up and open_left:
		top[0] = 0
		top[1] = 0
	if open_up and open_right:
		top[last] = 0
		top[last - 1] = 0
	var cut_bottom_left: bool = open_down and open_left
	var cut_bottom_right: bool = open_down and open_right
	for y: int in tile:
		for x: int in tile:
			if y < top[x] or last - y < bottom[x] or x < left[y] or last - x < right[y]:
				continue
			if cut_bottom_left and x + (last - y) < CORNER_CUT:
				continue
			if cut_bottom_right and (last - x) + (last - y) < CORNER_CUT:
				continue
			var image_pixel: Vector2i = corner + Vector2i(x, y) - origin_px
			kinds[image_pixel.y * size.x + image_pixel.x] = PATCH


## How deep (0, 1 or 2 px) one pixel of an open side is dented, the same every run
## (a hash of its place; the ground's rule). `along` = the pixel's position along the
## side, `line` = the side's own coordinate, `side` = 0 top, 1 bottom, 2 left, 3 right.
## along / 2: dents are 2 px wide.
static func _get_dent(is_open: bool, along: int, line: int, side: int) -> int:
	if not is_open:
		return 0
	var roll: int = hash(Vector3i(floori(along / 2.0), line, side)) % 1000
	if side != 0 and roll < int(DEEP_DENT_CHANCE * 1000.0):
		return 2
	return 1 if roll < int(EDGE_DENT_CHANCE * 1000.0) else 0


## The forward sweep of the distance transform: top-left to bottom-right, each pixel
## looking at the neighbours already passed (left, up-left, up, up-right).
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


## The backward sweep: bottom-right to top-left, the mirror of _sweep_forward.
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


## The color of the patch pixel `pixel` (layer-local px), `distance` px from the air.
static func _get_color(pixel: Vector2i, distance: float, is_top: bool, is_grain: bool,
		palette: Array[Color], grain: Grain) -> Color:
	var depth: float = distance - 1.0  # 0 on the outermost pixel
	var crust_end: float = CRUST_WIDTH + _noise(pixel) * CRUST_WOBBLE
	if depth < crust_end - 1.0:
		if is_top:
			return palette[RIM]
		if is_grain:
			# The grain in the crust: a darker shade of it (cracks, joints).
			return palette[CRUST].darkened(0.45 if grain == Grain.CRACKED else 0.35)
		if posmod(hash(Vector2i(pixel.x * 7, pixel.y * 13)), int(FLECK_EVERY[grain])) == 0:
			return palette[FLECK]
		return palette[CRUST]
	if depth < crust_end:
		return palette[EDGE]  # the edge line where the crust ends
	# Inside: dark, hatched, darker the deeper it goes; the grain shows as lighter lines.
	var inside: Color = palette[HATCH] if posmod(pixel.x + pixel.y, HATCH_PERIOD) < HATCH_WIDTH else palette[INSIDE]
	var fade: float = smoothstep(0.0, INSIDE_FADE_DEPTH, depth - crust_end)
	if is_grain:
		return palette[GRAIN_INSIDE].darkened(1.0 - lerpf(INSIDE_EDGE_BRIGHTNESS, GRAIN_DEEPEST_BRIGHTNESS, fade))
	# darkened(), not `color * factor`: multiplying a Color scales its alpha too.
	return inside.darkened(1.0 - lerpf(INSIDE_EDGE_BRIGHTNESS, INSIDE_DEEPEST_BRIGHTNESS, fade))


## CRACKED: the pixels of each cell's hair crack (layer px -> true). Per cell, from a
## hash of it: a start near its left side, a bend, and an end 2-3 px further on, each
## segment stepped one pixel at a time.
static func _find_crack_pixels(cells: Array, tile: int) -> Dictionary:
	var pixels: Dictionary = {}
	for cell: Vector2i in cells:
		var hash_value: int = absi(cell.x * 73856093 ^ cell.y * 19349663)
		# Each "% 3" takes one base-3 digit of the hash.
		var start: Vector2i = cell * tile + Vector2i(1 + hash_value % 3, 2 + floori(hash_value / 3.0) % 3)
		var bend: Vector2i = start + Vector2i(3, 2 - floori(hash_value / 9.0) % 3)
		var finish: Vector2i = bend + Vector2i(2 + floori(hash_value / 27.0) % 2, 2 - floori(hash_value / 54.0) % 3)
		for segment: Array in [[start, bend], [bend, finish]]:
			var from: Vector2i = segment[0]
			var to: Vector2i = segment[1]
			var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
			for step: int in steps + 1:
				pixels[Vector2i((Vector2(from).lerp(Vector2(to), float(step) / maxf(steps, 1.0))).round())] = true
	return pixels


## COLUMNS: is `pixel` on a joint between basalt columns? Vertical joints every
## COLUMN_WIDTH px, shifted per band of COLUMN_BAND_HEIGHT px; a cross joint along the
## top of some column pieces.
static func _is_column_joint(pixel: Vector2i) -> bool:
	var band: int = floori(float(pixel.y) / COLUMN_BAND_HEIGHT)
	var column: int = floori(float(pixel.x) / COLUMN_WIDTH)
	var shift: int = posmod(hash(Vector2i(column, band)), 3) - 1  # -1, 0 or 1 px
	if posmod(pixel.x + shift, COLUMN_WIDTH) == 0:
		return true
	return posmod(pixel.y, COLUMN_BAND_HEIGHT) == 0 \
		and posmod(hash(Vector2i(column * 31, band * 17)), CROSS_JOINT_EVERY) == 0


## Smooth 0..1 "value noise" at `pixel`: random numbers on a coarse grid, blended
## between its points (the crust's blobby inner edge).
static func _noise(pixel: Vector2i) -> float:
	var grid_x: float = float(pixel.x) / CRUST_NOISE_SPACING
	var grid_y: float = float(pixel.y) / CRUST_NOISE_SPACING
	var corner: Vector2i = Vector2i(floori(grid_x), floori(grid_y))
	var share_x: float = smoothstep(0.0, 1.0, grid_x - corner.x)
	var share_y: float = smoothstep(0.0, 1.0, grid_y - corner.y)
	var top: float = lerpf(_hash01(corner), _hash01(corner + Vector2i.RIGHT), share_x)
	var bottom: float = lerpf(_hash01(corner + Vector2i.DOWN), _hash01(corner + Vector2i.ONE), share_x)
	return lerpf(top, bottom, share_y)


## A steady 0..1 number for a grid point (the same every run).
static func _hash01(point: Vector2i) -> float:
	var hash_value: int = absi(point.x * 73856093 ^ point.y * 19349663)
	return float(hash_value % 1000) / 1000.0

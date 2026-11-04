class_name CrumbleRockPainter
extends RefCounted
## CrumbleRockPainter (after the W8c play-test: "make the crumbling platforms more
## like the terrain in texture"): paints one patch of crumbling rock as a small
## picture in the GroundPainter's style (scenes/objects/earth/ground_painter.gd): a
## bright CRUST along the faces open to the air, with a lighter RIM on top, a darker
## EDGE LINE where it ends, and a dark, HATCHED inside that darkens further in. Its own
## warmer palette, so crumbling rock reads apart from plain grey rock.
##
## Used by CrumbleRockLayer (crumble_rock_layer.gd), one picture per patch, so a
## crumbling patch can shake on its own (the GroundPainter paints the whole room as
## one picture). Static: paint() is all there is.
##
## HOW (the GroundPainter's three steps, at patch size):
##   1. MASK: the patch's tiles are ground; a pixel outside it is GROUND too if another
##      solid layer has a tile there (no crust against rock it leans on), else AIR.
##   2. DISTANCE from the air, px, by a distance transform: two sweeps over the
##      picture, each pixel taking its neighbours' smallest distance + 1 (+1.41
##      diagonally).
##   3. COLOR from the distance (_get_color).
## A patch is a few dozen tiles at most, so this is a few thousand pixels: painted once
## when the patch is built (the layer keeps it until its cells change).

## Crust thickness, px, wobbling by up to CRUST_WOBBLE either way (narrower than the
## ground's 5 px: platforms here are often one tile tall, and need their dark inside).
const CRUST_WIDTH: float = 2.0
const CRUST_WOBBLE: float = 0.6
## The wobble's random grid, px apart.
const CRUST_NOISE_SPACING: int = 4
## Diagonal hatch on the inside: a stripe HATCH_WIDTH px wide every HATCH_PERIOD px.
const HATCH_PERIOD: int = 6
const HATCH_WIDTH: int = 2
## The inside right past the edge line is this fraction of its color, darkening over
## INSIDE_FADE_DEPTH px down to INSIDE_DEEPEST_BRIGHTNESS.
const INSIDE_EDGE_BRIGHTNESS: float = 0.8
const INSIDE_FADE_DEPTH: float = 6.0
const INSIDE_DEEPEST_BRIGHTNESS: float = 0.3
## The palette (the grey rock's, a little warmer and lighter, so it reads as the same
## kind of ground but not the same ground): crust, rim, edge line, inside, hatch stripe.
const CRUST_COLOR: Color = Color(0.5, 0.46, 0.42)
const RIM_COLOR: Color = Color(0.66, 0.61, 0.55)
const EDGE_COLOR: Color = Color(0.22, 0.19, 0.18)
const INSIDE_COLOR: Color = Color(0.2, 0.17, 0.16)
const HATCH_COLOR: Color = Color(0.28, 0.24, 0.22)
## Distance given to pixels not reached from any air (deep in, or no air at all).
const FAR: float = 1000.0


## The picture of the patch `cells` (cells of `layer`, a TileMapLayer of `tile_px`
## tiles), as [texture: ImageTexture, origin: Vector2 (layer-local px of its top-left)].
## `is_other_ground(cell) -> bool`: is a tile of another solid layer there?
static func paint(cells: Array[Vector2i], tile_px: Vector2i, is_other_ground: Callable) -> Array:
	var in_patch: Dictionary = {}
	var first: Vector2i = cells[0]
	var last: Vector2i = cells[0]
	for cell: Vector2i in cells:
		in_patch[cell] = true
		first = first.min(cell)
		last = last.max(cell)
	# One px of margin round the patch: the air (or ground) its faces look out on.
	var origin_px: Vector2i = first * tile_px - Vector2i.ONE
	var size: Vector2i = (last - first + Vector2i.ONE) * tile_px + Vector2i.ONE * 2
	# 1. The mask: 1 = the patch, 2 = other ground, 0 = air; distances start at 0 in
	# the air and FAR on ground.
	var kinds: PackedByteArray = PackedByteArray()
	kinds.resize(size.x * size.y)
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			var pixel: Vector2i = origin_px + Vector2i(x, y)
			var cell: Vector2i = Vector2i(floori(float(pixel.x) / tile_px.x), floori(float(pixel.y) / tile_px.y))
			var kind: int = 1 if in_patch.has(cell) else (2 if is_other_ground.call(cell) else 0)
			kinds[y * size.x + x] = kind
			distances[y * size.x + x] = 0.0 if kind == 0 else FAR
	# 2. The distance transform: forward (from the top-left), then backward.
	_sweep(distances, size, 1)
	_sweep(distances, size, -1)
	# 3. The colors, for the patch's pixels only.
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var index: int = y * size.x + x
			if kinds[index] != 1:
				continue
			# The pixel straight above is air: a top surface, it gets the rim.
			var is_top: bool = y > 0 and kinds[index - size.x] == 0
			image.set_pixel(x, y, _get_color(origin_px + Vector2i(x, y), distances[index], is_top))
	return [ImageTexture.create_from_image(image), Vector2(origin_px)]


## One sweep of the distance transform, `direction` 1 (top-left to bottom-right,
## looking at the neighbours already passed: left, up-left, up, up-right) or -1 (the
## other way round).
static func _sweep(distances: PackedFloat32Array, size: Vector2i, direction: int) -> void:
	var y_range: Array = range(size.y) if direction > 0 else range(size.y - 1, -1, -1)
	var x_range: Array = range(size.x) if direction > 0 else range(size.x - 1, -1, -1)
	for y: int in y_range:
		for x: int in x_range:
			var index: int = y * size.x + x
			var best: float = distances[index]
			if best <= 0.0:
				continue
			# Each offset: x, y = the neighbour (mirrored on the backward sweep), z = the step's length.
			for offset: Vector3 in [Vector3(-1, 0, 1.0), Vector3(-1, -1, 1.41), Vector3(0, -1, 1.0), Vector3(1, -1, 1.41)]:
				var next_x: int = x + int(offset.x) * direction
				var next_y: int = y + int(offset.y) * direction
				if next_x < 0 or next_y < 0 or next_x >= size.x or next_y >= size.y:
					continue
				best = minf(best, distances[next_y * size.x + next_x] + offset.z)
			distances[index] = best


## The color of the ground pixel `pixel` (layer-local px), `distance` px from the air.
static func _get_color(pixel: Vector2i, distance: float, is_top: bool) -> Color:
	var crust: float = CRUST_WIDTH + (_noise(pixel) * 2.0 - 1.0) * CRUST_WOBBLE
	if is_top:
		return RIM_COLOR
	if distance <= crust:
		return CRUST_COLOR
	if distance <= crust + 1.0:
		return EDGE_COLOR
	var depth_share: float = clampf((distance - crust - 1.0) / INSIDE_FADE_DEPTH, 0.0, 1.0)
	var brightness: float = lerpf(INSIDE_EDGE_BRIGHTNESS, INSIDE_DEEPEST_BRIGHTNESS, depth_share)
	var is_hatch: bool = posmod(pixel.x + pixel.y, HATCH_PERIOD) < HATCH_WIDTH
	var color: Color = HATCH_COLOR if is_hatch else INSIDE_COLOR
	return Color(color.r * brightness, color.g * brightness, color.b * brightness)


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

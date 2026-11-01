class_name BackdropTerrain
extends RefCounted
## BackdropTerrain: paints backdrop shapes in the style of our GROUND
## (GroundPainter): a bright CRUST along every edge whose inner side wobbles, a
## lighter RIM on top surfaces, a 1 px darker EDGE LINE where the crust ends, and
## a dark INSIDE with diagonal HATCH stripes that sinks into a DEEP color the
## further in it goes. Used by the looks built in that style (Sanctum, Deepwood)
## for their faint background platforms, ledges, hills, roots and even tree crowns
## (a crown is a "ground" of leaves). Static helpers, like BackdropPaint.
##
## HOW, the same three steps as GroundPainter, on a small box instead of a room:
##   1. MASK (a Mask: which pixels of a box are solid). Built from rectangles,
##      circles and skylines, then roughen()-ed: exposed sides and undersides get
##      1-2 px dents, tops stay flat (you could stand on them).
##   2. DISTANCE from open air, per solid pixel (a "chamfer" distance transform:
##      two sweeps, each pixel taking its neighbours' distance + 2 straight or
##      + 3 diagonally; halved: 1 px straight, 1.5 px diagonally).
##   3. COLOR from the distance and a PALETTE (see below).
## A shape far away gets a HAZED palette (hazed(): every color pulled toward the
## air's color), so faint platforms in the back read as far, not just as dim.
##
## Palette: [crust, rim, edge line, inside, hatch stripe, deep], the order
## GroundPainter.PALETTE uses plus the color the inside fades to deep in.
##
## Speed: the loops over a box work on the mask's byte array directly (a method
## call per pixel was most of the cost; some boxes are a whole mountain).

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## Palette indices.
const CRUST: int = 0
const RIM: int = 1
const EDGE: int = 2
const INSIDE: int = 3
const HATCH: int = 4
const DEEP: int = 5

## Diagonal hatch: one stripe every HATCH_PERIOD px, HATCH_WIDTH px wide (as the ground's).
const HATCH_PERIOD: int = 6
const HATCH_WIDTH: int = 2
## How far the crust's inner edge wobbles (px, for a 5 px crust), and the size of
## its noise cells.
const CRUST_WOBBLE: float = 2.0
const CRUST_NOISE_CELL: float = 5.0
## Chamfer steps: straight and diagonal (2 and 3 approximate 1 and 1.41, halved later).
const STRAIGHT_STEP: int = 2
const DIAGONAL_STEP: int = 3
## Spare columns each side of a band (new_band): more than any crust + fade.
const BAND_SPARE: int = 24


## Which pixels of a box are solid. `origin` is the box's top-left in the image
## (x may be anywhere: painting wraps it around the strip).
class Mask:
	extends RefCounted
	var origin: Vector2i
	var size: Vector2i
	var cells: PackedByteArray

	func _init(box_origin: Vector2i, box_size: Vector2i) -> void:
		origin = box_origin
		size = box_size
		cells = PackedByteArray()
		cells.resize(size.x * size.y)

	## Is image pixel (x, y) solid? (False outside the box.)
	func is_solid(x: int, y: int) -> bool:
		var local_x: int = x - origin.x
		var local_y: int = y - origin.y
		if local_x < 0 or local_y < 0 or local_x >= size.x or local_y >= size.y:
			return false
		return cells[local_y * size.x + local_x] != 0

	## A filled rectangle, image pixels (clipped to the box).
	func add_rect(rect: Rect2i) -> void:
		var clipped: Rect2i = Rect2i(rect.position - origin, rect.size).intersection(Rect2i(Vector2i.ZERO, size))
		for local_y: int in range(clipped.position.y, clipped.end.y):
			var row_start: int = local_y * size.x
			for local_x: int in range(clipped.position.x, clipped.end.x):
				cells[row_start + local_x] = 1

	## A filled circle, image pixels.
	func add_circle(center: Vector2, radius: float) -> void:
		var reach: int = ceili(radius)
		for dy: int in range(-reach, reach + 1):
			var half_width: float = sqrt(maxf(0.0, radius * radius - dy * dy))
			var left: int = roundi(center.x - half_width)
			add_rect(Rect2i(left, roundi(center.y) + dy, roundi(center.x + half_width) - left + 1, 1))

	## Solid from `tops[x]` down to the box's bottom, for every column of the box
	## (tops indexed by strip x: wraps).
	func add_below(tops: PackedFloat32Array) -> void:
		for local_x: int in size.x:
			var top: int = ceili(tops[posmod(origin.x + local_x, BackdropPaint.STRIP_WIDTH)]) - origin.y
			for local_y: int in range(maxi(top, 0), size.y):
				cells[local_y * size.x + local_x] = 1

	## Solid from the box's top down to `bottoms[x]` (a hanging ceiling).
	func add_above(bottoms: PackedFloat32Array) -> void:
		for local_x: int in size.x:
			var bottom: int = floori(bottoms[posmod(origin.x + local_x, BackdropPaint.STRIP_WIDTH)]) - origin.y
			for local_y: int in range(0, mini(bottom + 1, size.y)):
				cells[local_y * size.x + local_x] = 1

	## A thick line (roots, branches, trunks that lean), `width` px across.
	func add_line(from: Vector2, to: Vector2, width: float) -> void:
		var steps: int = maxi(1, ceili(from.distance_to(to) / maxf(1.0, width * 0.25)))
		for step: int in steps + 1:
			add_circle(from.lerp(to, float(step) / steps), width * 0.5)

	## A box at least a strip wide (a band all the way round, given spare columns
	## each side so its edges aren't mistaken for open air): only its columns
	## inside [0, STRIP_WIDTH) are painted, the spare ones are just context.
	func is_spare_column(x: int) -> bool:
		return size.x >= BackdropPaint.STRIP_WIDTH and (x < 0 or x >= BackdropPaint.STRIP_WIDTH)


## A new, empty mask over `box` (image pixels).
static func new_mask(box: Rect2i) -> Mask:
	return Mask.new(box.position, box.size)


## A new, empty mask for a band all the way round the strip, rows `from_row` to
## `to_row` (Mask.is_spare_column: BAND_SPARE columns of context each side).
static func new_band(from_row: int, to_row: int) -> Mask:
	return Mask.new(Vector2i(-BAND_SPARE, from_row), Vector2i(BackdropPaint.STRIP_WIDTH + BAND_SPARE * 2, to_row - from_row))


## A palette whose colors are all pulled `amount` (0-1) toward `haze`: further away.
static func hazed(palette: Array[Color], haze: Color, amount: float) -> Array[Color]:
	var result: Array[Color] = []
	for color: Color in palette:
		result.append(color.lerp(haze, amount))
	return result


## A floating chunk of level, the way a room's platforms look: `width_tiles` tiles of
## `tile` px wide with a flat top at `top_row` (image px) from `left`; under it the
## columns hang down a random 1..`depth_tiles` tiles each (a ragged, rocky
## underside, deeper toward the middle), and maybe a step up on one end.
static func add_chunk(mask: Mask, left: int, top_row: int, width_tiles: int, depth_tiles: int, tile: int,
		seed_value: int) -> void:
	for column: int in width_tiles:
		var middle_weight: float = 1.0 - absf((column + 0.5) / width_tiles * 2.0 - 1.0)  # 0 at the ends, 1 in the middle
		var hang: int = 1 + roundi((depth_tiles - 1) * (0.35 + 0.65 * middle_weight) * (0.55 + 0.45 * BackdropPaint.random01(column, 1, seed_value)))
		mask.add_rect(Rect2i(left + column * tile, top_row, tile, hang * tile))
	# A step: one end a tile higher, on about half the chunks.
	if width_tiles >= 4 and BackdropPaint.random01(0, 2, seed_value) < 0.5:
		var step_tiles: int = 1 + roundi(BackdropPaint.random01(0, 3, seed_value) * (width_tiles / 3))
		var step_left: int = left if BackdropPaint.random01(0, 4, seed_value) < 0.5 else left + (width_tiles - step_tiles) * tile
		mask.add_rect(Rect2i(step_left, top_row - tile, step_tiles * tile, tile))


## Dents along exposed sides and undersides, like GroundPainter's edges: every
## solid pixel with air to its left, right or below may lose 1 or 2 px (a hash of
## its position, the same every run). Tops stay flat. Bottom corners get rounded
## off by `corner` px.
static func roughen(mask: Mask, seed_value: int, corner: int = 2) -> void:
	var width: int = mask.size.x
	var height: int = mask.size.y
	var cells: PackedByteArray = mask.cells
	var removals: PackedInt32Array = PackedInt32Array()
	for local_y: int in height:
		var row_start: int = local_y * width
		for local_x: int in width:
			var index: int = row_start + local_x
			if cells[index] == 0:
				continue
			var air_below: bool = local_y == height - 1 or cells[index + width] == 0
			var air_left: bool = local_x == 0 or cells[index - 1] == 0
			var air_right: bool = local_x == width - 1 or cells[index + 1] == 0
			if not (air_below or air_left or air_right):
				continue
			var air_above: bool = local_y == 0 or cells[index - width] == 0
			# Rounded bottom corners (top corners stay square: a ledge's edge).
			if air_below and (air_left or air_right) and not air_above:
				var inward: int = 1 if air_left else -1
				for cut: int in corner:
					if local_x + inward * cut >= 0 and local_x + inward * cut < width:
						removals.append(index + inward * cut)
					if local_y - cut >= 0:
						removals.append(index - width * cut)
				continue
			if air_above:
				continue
			# Dents come in 2 px stretches (a hash per stretch), so they read as bites.
			var x: int = mask.origin.x + local_x
			var y: int = mask.origin.y + local_y
			var roll: float = BackdropPaint.random01(x / 2 if air_below else x, y / 2, seed_value)
			if roll < 0.15:
				removals.append(index)
				if air_below:
					removals.append(index - width)
				elif air_left and local_x + 1 < width:
					removals.append(index + 1)
				elif local_x > 0:
					removals.append(index - 1)
			elif roll < 0.4:
				removals.append(index)
	for index: int in removals:
		cells[index] = 0
	mask.cells = cells


## Paints `mask` onto `image` in the ground's style (see the header) with `palette`.
## `crust_width` px of crust (thinner for far shapes: they're smaller), `fade` px
## over which the inside sinks from INSIDE to DEEP, `rim_rows` rows of rim on tops.
## Pixels outside the image are skipped; x wraps around the strip.
##
## Fast path: past the crust and the fade, every pixel is plain DEEP (the hatch
## fades into it too), so those pixels are gathered into runs along each row and
## filled as one rectangle each, and their distance is never worked out exactly.
static func paint(image: Image, mask: Mask, palette: Array[Color], crust_width: float = 5.0, fade: float = 10.0,
		rim_rows: int = 1, seed_value: int = 1) -> void:
	var wobble: float = CRUST_WOBBLE * (crust_width / 5.0)
	# Deeper than this (half px) is plain DEEP: the distances stop counting there.
	var deep_from: int = ceili((crust_width + wobble + fade + 1.0) * 2.0) + 2
	var distances: PackedInt32Array = _distances(mask, deep_from)
	var width: int = mask.size.x
	var cells: PackedByteArray = mask.cells
	var image_height: int = image.get_height()
	var deep: Color = palette[DEEP]
	# The inside's colors at each half px of depth past the crust, worked out once.
	var inside_steps: Array[Color] = []
	var hatch_steps: Array[Color] = []
	for step: int in ceili(fade * 2.0) + 2:
		var sink: float = smoothstep(0.0, fade, step * 0.5)
		inside_steps.append(palette[INSIDE].lerp(deep, sink))
		hatch_steps.append(palette[HATCH].lerp(deep, sink))
	var last_step: int = inside_steps.size() - 1
	var speck: Color = palette[CRUST].lerp(palette[EDGE], 0.35)
	for local_y: int in mask.size.y:
		var y: int = mask.origin.y + local_y
		if y < 0 or y >= image_height:
			continue
		var row_start: int = local_y * width
		var run_start: int = -1  # local x where the current run of DEEP pixels began
		for local_x: int in width + 1:
			var index: int = row_start + local_x
			var is_deep: bool = local_x < width and cells[index] != 0 and distances[index] >= deep_from
			if is_deep:
				if run_start < 0:
					run_start = local_x
				continue
			if run_start >= 0:
				_fill_run(image, mask, mask.origin.x + run_start, mask.origin.x + local_x, y, deep)
				run_start = -1
			if local_x == width or cells[index] == 0:
				continue
			var x: int = mask.origin.x + local_x
			if mask.is_spare_column(x):
				continue
			var depth: float = distances[index] * 0.5 - 1.0  # 0 on the outermost pixel
			var color: Color
			var crust_end: float = crust_width + wobble
			# Only pixels near the crust need the (slow) noise for its wobbly edge.
			if depth < crust_width + wobble:
				crust_end = crust_width + (noise_2d(x, y, CRUST_NOISE_CELL, seed_value) - 0.5) * 2.0 * wobble
			if depth < crust_end - 1.0:
				color = palette[CRUST]
				for lift: int in range(1, rim_rows + 1):
					if local_y - lift < 0 or cells[index - width * lift] == 0:
						color = palette[RIM]
						break
				# A few darker specks in the crust, as on the ground.
				if color == palette[CRUST] and hash(Vector2i(x * 7, y * 13)) % 29 == 0:
					color = speck
			elif depth < crust_end:
				color = palette[EDGE]
			else:
				var step: int = mini(roundi((depth - crust_end) * 2.0), last_step)
				color = hatch_steps[step] if posmod(x + y, HATCH_PERIOD) < HATCH_WIDTH else inside_steps[step]
			image.set_pixel(posmod(x, BackdropPaint.STRIP_WIDTH), y, color)


## Fills image row `y` from x `from_x` up to (not including) `to_x` with `color`,
## wrapping round the strip and leaving out a band's spare columns.
static func _fill_run(image: Image, mask: Mask, from_x: int, to_x: int, y: int, color: Color) -> void:
	if mask.size.x >= BackdropPaint.STRIP_WIDTH:
		from_x = maxi(from_x, 0)
		to_x = mini(to_x, BackdropPaint.STRIP_WIDTH)
	var x: int = from_x
	while x < to_x:
		var wrapped: int = posmod(x, BackdropPaint.STRIP_WIDTH)
		var length: int = mini(to_x - x, BackdropPaint.STRIP_WIDTH - wrapped)
		image.fill_rect(Rect2i(wrapped, y, length, 1), color)
		x += length


## Grass blades (or moss tufts, flowers...) standing on the mask's top surfaces:
## about one top pixel in `every` gets a blade 1..`max_height` px tall in one of
## `colors`.
static func paint_blades(image: Image, mask: Mask, colors: Array[Color], every: int, max_height: int, seed_value: int) -> void:
	for spot: Vector2i in _edge_pixels(mask, -1):
		if BackdropPaint.random01(spot.x, spot.y, seed_value) * every >= 1.0:
			continue
		var height: int = 1 + roundi(BackdropPaint.random01(spot.x, spot.y + 7, seed_value) * (max_height - 1))
		var color: Color = colors[int(BackdropPaint.random01(spot.x, spot.y + 13, seed_value) * colors.size()) % colors.size()]
		for lift: int in height:
			BackdropPaint.put_pixel(image, spot.x, spot.y - 1 - lift, color)


## Things hanging from the mask's undersides: moss, roots, vines. About one bottom
## pixel in `every` gets a strand up to `max_length` px long in `color`; every
## `bead_every` px of a strand a `bead` pixel (a leaf, a blossom). bead_every 0: none.
static func paint_hanging(image: Image, mask: Mask, color: Color, every: int, max_length: int, bead: Color,
		bead_every: int, seed_value: int) -> void:
	for spot: Vector2i in _edge_pixels(mask, 1):
		if BackdropPaint.random01(spot.x, spot.y, seed_value) * every >= 1.0:
			continue
		var length: int = 2 + roundi(BackdropPaint.random01(spot.x, spot.y + 5, seed_value) * (max_length - 2))
		for drop: int in length:
			# A gentle sway: strands drift a px sideways now and then.
			var sway: int = roundi(sin((drop + spot.x) * 0.35) * 0.7)
			var strand_color: Color = bead if bead_every > 0 and drop % bead_every == bead_every - 1 else color
			BackdropPaint.put_pixel(image, spot.x + sway, spot.y + 1 + drop, strand_color)


## Inside a shape made of round clumps (a tree crown, a bush), the TOP of each
## clump gets its own crust: an arc `thickness` px thick in the palette's CRUST
## with its RIM on the outside and an EDGE line under it, over the upper part of
## the clump. Without these a crown is one flat blob with a crust only round the
## outside; with them it reads as a heap of leafy clumps. `clumps` are
## Vector3(x, y, radius) in the order they were added: a later clump is in front,
## so an arc is left out where one of the next LOOKAHEAD clumps covers it (clumps
## are added tree by tree: further ones are far away). Only on solid pixels. A
## clump whose middle is off the strip is left out: it's a wrapped copy of one
## that's on it, which draws the same pixels (put_pixel wraps).
static func paint_clump_tops(image: Image, mask: Mask, clumps: Array[Vector3], palette: Array[Color], thickness: float) -> void:
	const LOOKAHEAD: int = 40
	for clump_index: int in clumps.size():
		var clump: Vector3 = clumps[clump_index]
		if clump.x < 0.0 or clump.x >= BackdropPaint.STRIP_WIDTH:
			continue
		var reach: int = ceili(clump.z)
		for dy: int in range(-reach, 1):
			for dx: int in range(-reach, reach + 1):
				var distance: float = sqrt(float(dx * dx + dy * dy))
				var inset: float = clump.z - distance  # px in from the clump's edge
				if inset < 0.0 or inset > thickness + 1.0:
					continue
				# Only the upper part: from about 10 o'clock round to 2 o'clock, a
				# little more on the lit (left) side.
				if dy > -clump.z * 0.35 + (dx * 0.25):
					continue
				var x: int = roundi(clump.x) + dx
				var y: int = roundi(clump.y) + dy
				if not mask.is_solid(x, y):
					continue
				var covered: bool = false
				for later: int in range(clump_index + 1, mini(clumps.size(), clump_index + 1 + LOOKAHEAD)):
					var other: Vector3 = clumps[later]
					if Vector2(x - other.x, y - other.y).length_squared() < other.z * other.z:
						covered = true
						break
				if covered:
					continue
				var color: Color = palette[CRUST]
				if inset < 1.0:
					color = palette[RIM]
				elif inset >= thickness:
					color = palette[EDGE]
				BackdropPaint.put_pixel(image, x, y, color)


## Smooth 2D value noise in [0, 1], repeating sideways every STRIP_WIDTH px (a
## grid of random values `cell` px apart, blended): the crust's wobble.
static func noise_2d(x: float, y: float, cell: float, seed_value: int) -> float:
	var columns: int = maxi(1, roundi(BackdropPaint.STRIP_WIDTH / cell))
	var grid_x: float = x * columns / BackdropPaint.STRIP_WIDTH
	var grid_y: float = y / cell
	var cell_x: int = floori(grid_x)
	var cell_y: int = floori(grid_y)
	var fraction_x: float = grid_x - cell_x
	var fraction_y: float = grid_y - cell_y
	fraction_x = fraction_x * fraction_x * (3.0 - 2.0 * fraction_x)
	fraction_y = fraction_y * fraction_y * (3.0 - 2.0 * fraction_y)
	var top: float = lerpf(BackdropPaint.random01(posmod(cell_x, columns), cell_y, seed_value),
		BackdropPaint.random01(posmod(cell_x + 1, columns), cell_y, seed_value), fraction_x)
	var bottom: float = lerpf(BackdropPaint.random01(posmod(cell_x, columns), cell_y + 1, seed_value),
		BackdropPaint.random01(posmod(cell_x + 1, columns), cell_y + 1, seed_value), fraction_x)
	return lerpf(top, bottom, fraction_y)


## The mask's solid pixels (image coordinates) with air right above them
## (`side` -1: tops) or right below (`side` 1: undersides), spare columns left out.
static func _edge_pixels(mask: Mask, side: int) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	var width: int = mask.size.x
	var height: int = mask.size.y
	var cells: PackedByteArray = mask.cells
	for local_y: int in height:
		var neighbour_y: int = local_y + side
		var has_neighbour_row: bool = neighbour_y >= 0 and neighbour_y < height
		for local_x: int in width:
			var index: int = local_y * width + local_x
			if cells[index] == 0:
				continue
			if has_neighbour_row and cells[index + side * width] != 0:
				continue
			var x: int = mask.origin.x + local_x
			if not mask.is_spare_column(x):
				spots.append(Vector2i(x, mask.origin.y + local_y))
	return spots


## The chamfer distance of every solid pixel of the mask from the nearest air
## (header, step 2), in half-px units (2 per straight px), counted only up to
## `cap`: every pixel deeper gets `cap`. Outside the box is air.
static func _distances(mask: Mask, cap: int) -> PackedInt32Array:
	var width: int = mask.size.x
	var height: int = mask.size.y
	var cells: PackedByteArray = mask.cells
	var distances: PackedInt32Array = PackedInt32Array()
	distances.resize(width * height)
	for index: int in width * height:
		distances[index] = cap if cells[index] != 0 else 0
	# Forward sweep: from the top-left, each pixel looks at its left and upper
	# neighbours. The box's first row and column touch the outside: air.
	for y: int in height:
		var row_start: int = y * width
		for x: int in width:
			var index: int = row_start + x
			var best: int = distances[index]
			if best == 0:
				continue
			if x == 0 or y == 0:
				distances[index] = STRAIGHT_STEP
				continue
			var above: int = index - width
			best = mini(best, distances[index - 1] + STRAIGHT_STEP)
			best = mini(best, distances[above] + STRAIGHT_STEP)
			best = mini(best, distances[above - 1] + DIAGONAL_STEP)
			if x < width - 1:
				best = mini(best, distances[above + 1] + DIAGONAL_STEP)
			distances[index] = best
	# Backward sweep: from the bottom-right, its right and lower neighbours.
	for y: int in range(height - 1, -1, -1):
		var row_start: int = y * width
		for x: int in range(width - 1, -1, -1):
			var index: int = row_start + x
			var best: int = distances[index]
			if best <= STRAIGHT_STEP:
				continue
			if x == width - 1 or y == height - 1:
				distances[index] = STRAIGHT_STEP
				continue
			var below: int = index + width
			best = mini(best, distances[index + 1] + STRAIGHT_STEP)
			best = mini(best, distances[below] + STRAIGHT_STEP)
			best = mini(best, distances[below + 1] + DIAGONAL_STEP)
			if x > 0:
				best = mini(best, distances[below - 1] + DIAGONAL_STEP)
			distances[index] = best
	return distances

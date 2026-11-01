class_name BackdropPaint
extends RefCounted
## BackdropPaint: static helpers that paint the pictures of a backdrop's layers
## (scenes/backdrop/), pixel by pixel, the way GroundPainter paints the ground.
## Nothing here is a node: the theme scripts (themes/*.gd) call these functions to
## fill an Image, and BackdropTheme turns the Image into a texture once per run.
##
## Every layer picture is a STRIP: STRIP_WIDTH x STRIP_HEIGHT pixels that repeat
## sideways without a seam (BackdropLayer draws it twice, side by side). Seamless
## because all the randomness here wraps around: the noise repeats every STRIP_WIDTH
## pixels, and shapes drawn near one end continue at the other (put_pixel wraps x).
##
## Rows: the strip is taller than the screen (180) by SCREEN_TOP_ROW above and
## below, so a layer can shift up or down a little with the camera (vertical
## parallax, BackdropLayer.MAX_VERTICAL_SHIFT) without showing its edge, and the
## soft seam of a change between looks has rows to blend over (Backdrop). Row SCREEN_TOP_ROW is the top of the screen
## when the camera is where it started; row SCREEN_TOP_ROW + 180 is the bottom.
##
## TALL pictures (new_tall()): one look's three altitudes stacked as one picture,
## skyline on top, surface under it, underground at the bottom, TALL_HEIGHT rows.
## Each altitude shows its own strip-sized slice (BackdropTheme.add_tall_layer),
## so a sky, a far range or a giant tree painted once runs on unbroken from one
## altitude into the next: the look reads as one scene. tall_row() turns an
## altitude's screen row into a row of the tall picture. Every helper here works
## on strips and tall pictures alike (they ask the image for its height).
##
## Style, like Celeste's backgrounds (and our ground): flat shapes, a bright rim
## along every top, LIT faces on the side the light comes from (upper left), colors
## in a few hard BANDS with a 1-2 row checker DITHER between them instead of smooth
## gradients, and further layers painted in hazier colors, closer to the sky.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const STRIP_WIDTH: int = 640
const STRIP_HEIGHT: int = 260
## The strip's row at the top of the screen when the layer is at rest.
const SCREEN_TOP_ROW: int = 40
## A tall picture: three screens stacked (skyline, surface, underground) plus the
## strip's spare rows above the first and below the last.
const SCREEN_HEIGHT: int = 180
const TALL_HEIGHT: int = STRIP_HEIGHT + SCREEN_HEIGHT * 2
## paint_section's faded edge: how many rows it thins out over, and the ordered
## (Bayer) dither it thins out in: each pixel of a 4x4 tile goes at its own step,
## so the fade is an even pattern, not noise.
const FADE_ROWS: int = 16
const BAYER_4X4: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


## A new, fully transparent strip.
static func new_strip() -> Image:
	return Image.create_empty(STRIP_WIDTH, STRIP_HEIGHT, false, Image.FORMAT_RGBA8)


## A screen row (0 = top of the screen at rest) as a strip row.
static func row(screen_y: float) -> int:
	return int(screen_y) + SCREEN_TOP_ROW


## A new, fully transparent tall picture (see the header).
static func new_tall() -> Image:
	return Image.create_empty(STRIP_WIDTH, TALL_HEIGHT, false, Image.FORMAT_RGBA8)


## Screen row `screen_y` of `section` (BackdropTheme.SKYLINE_SECTION, SURFACE_SECTION,
## UNDERGROUND_SECTION: 0, 1, 2) as a row of a tall picture.
static func tall_row(screen_y: float, section: int) -> int:
	return int(screen_y) + SCREEN_TOP_ROW + section * SCREEN_HEIGHT


## The slice of a tall picture that `section` shows: a normal strip.
static func tall_slice(tall: Image, section: int) -> Image:
	return tall.get_region(Rect2i(0, section * SCREEN_HEIGHT, STRIP_WIDTH, STRIP_HEIGHT))


## Copies `strip` (painted for one altitude, in row() rows) into `section` of a
## tall picture, over what's there (BackdropTheme.add_split_layer): only that
## section's own screen rows, plus its spare rows above when `with_top_margin` and
## below when `with_bottom_margin` (where no other altitude's screen is). So two
## altitudes' strips meet exactly at the screen edge between them, and neither
## one's spare rows show in the other's screen. `fade_edge`: the strip's side that
## meets the other altitude (its bottom, or its top when it has no top margin)
## thins out over FADE_ROWS rows in an ordered dither instead of ending in a
## straight cut, the way a thing sinks into mist or shadow. Changes `strip`.
static func paint_section(tall: Image, strip: Image, section: int, with_top_margin: bool, with_bottom_margin: bool,
		fade_edge: bool = false) -> void:
	var from_row: int = 0 if with_top_margin else SCREEN_TOP_ROW
	var to_row: int = STRIP_HEIGHT if with_bottom_margin else SCREEN_TOP_ROW + SCREEN_HEIGHT
	if fade_edge:
		var fades_bottom: bool = not with_bottom_margin
		for band_row: int in FADE_ROWS:
			var y: int = to_row - 1 - band_row if fades_bottom else from_row + band_row
			# How much is kept: nothing at the edge, all of it FADE_ROWS in.
			var keep: float = (band_row + 0.5) / FADE_ROWS
			for x: int in STRIP_WIDTH:
				if BAYER_4X4[(y % 4) * 4 + x % 4] / 16.0 >= keep:
					strip.set_pixel(x, y, Color(0, 0, 0, 0))
	tall.blend_rect(strip, Rect2i(0, from_row, STRIP_WIDTH, to_row - from_row), Vector2i(0, from_row + section * SCREEN_HEIGHT))


## A repeatable random number in [0, 1) for the integers (a, b) and a seed: a hash,
## so the same inputs always give the same backdrop.
static func random01(a: int, b: int, seed_value: int) -> float:
	return float(hash(Vector3i(a, b, seed_value)) & 0x7FFFFF) / float(0x800000)


## Smooth "value noise" in [0, 1] along x that repeats every STRIP_WIDTH pixels:
## random values on a coarse grid (one every `cell_size` px, rounded so a whole
## number of cells fits the strip), smoothly blended in between. The grid index
## wraps (posmod), which is what makes the strip seamless.
static func periodic_noise(x: float, cell_size: float, seed_value: int) -> float:
	var cell_count: int = maxi(1, roundi(STRIP_WIDTH / cell_size))
	var cells: float = x * cell_count / STRIP_WIDTH
	var index: int = floori(cells)
	var fraction: float = cells - index
	# smoothstep: no kinks where two cells meet.
	fraction = fraction * fraction * (3.0 - 2.0 * fraction)
	var left: float = random01(posmod(index, cell_count), 0, seed_value)
	var right: float = random01(posmod(index + 1, cell_count), 0, seed_value)
	return lerpf(left, right, fraction)


## A skyline: for every column, the row of the top of the shape. `octaves` lists
## Vector2(cell_size, height_in_px) noise layers that are added up (big slow hills
## plus small fast bumps). `peaky` folds each noise value (1 - |2n - 1|), which turns
## smooth hills into sharp peaks: mountains.
static func ridge(base_row: float, octaves: Array[Vector2], seed_value: int, peaky: bool) -> PackedFloat32Array:
	var tops: PackedFloat32Array = PackedFloat32Array()
	tops.resize(STRIP_WIDTH)
	for x: int in STRIP_WIDTH:
		var height: float = 0.0
		for octave_index: int in octaves.size():
			var octave: Vector2 = octaves[octave_index]
			var value: float = periodic_noise(x, octave.x, seed_value + octave_index * 31)
			if peaky:
				value = 1.0 - absf(2.0 * value - 1.0)
			height += value * octave.y
		tops[x] = base_row - height
	return tops


## Fills every column from its top row down to the strip's bottom with `color`.
static func fill_below(image: Image, tops: PackedFloat32Array, color: Color) -> void:
	for x: int in STRIP_WIDTH:
		var top: int = clampi(ceili(tops[x]), 0, image.get_height())
		image.fill_rect(Rect2i(x, top, 1, image.get_height() - top), color)


## Sets one pixel, wrapping x around the strip (so shapes cross the seam) and
## ignoring rows outside it.
static func put_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if y < 0 or y >= image.get_height():
		return
	image.set_pixel(posmod(x, STRIP_WIDTH), y, color)


## Paints a see-through `color` OVER the pixel that's there (wraps x like put_pixel).
static func blend_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if y < 0 or y >= image.get_height():
		return
	var wrapped_x: int = posmod(x, STRIP_WIDTH)
	# base.blend(over): `over` painted on top of `base`, alpha included.
	image.set_pixel(wrapped_x, y, image.get_pixel(wrapped_x, y).blend(color))


## A filled rectangle that wraps around the strip sideways.
static func put_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var top: int = clampi(rect.position.y, 0, image.get_height())
	var bottom: int = clampi(rect.end.y, 0, image.get_height())
	if bottom <= top:
		return
	for x: int in range(rect.position.x, rect.end.x):
		image.fill_rect(Rect2i(posmod(x, STRIP_WIDTH), top, 1, bottom - top), color)


## A filled pixel circle (wraps sideways), cut off below `max_row` if given (-1:
## the image's bottom).
static func put_circle(image: Image, center: Vector2, radius: float, color: Color, max_row: int = -1) -> void:
	if max_row < 0:
		max_row = image.get_height()
	var reach: int = ceili(radius)
	for dy: int in range(-reach, mini(reach, max_row - roundi(center.y)) + 1):
		# Half the width of the circle at this row (Pythagoras).
		var half_width: float = sqrt(maxf(0.0, radius * radius - dy * dy))
		var left: int = roundi(center.x - half_width)
		var right: int = roundi(center.x + half_width)
		put_rect(image, Rect2i(left, roundi(center.y) + dy, right - left + 1, 1), color)


## A line of square "pen" dots from `from` to `to` (wraps sideways).
static func put_line(image: Image, from: Vector2, to: Vector2, color: Color, width: int = 1) -> void:
	var steps: int = maxi(1, ceili(from.distance_to(to)))
	for step: int in steps + 1:
		var point: Vector2 = from.lerp(to, float(step) / steps)
		put_rect(image, Rect2i(roundi(point.x - width * 0.5), roundi(point.y - width * 0.5), width, width), color)


## True on the "dark" squares of a checkerboard: the dither pattern between bands.
static func checker(x: int, y: int) -> bool:
	return (x + y) % 2 == 0


## A sky (or any backdrop's back wall of color): `colors` from top to bottom as hard
## bands between `from_row` and `to_row`, each border softened by two dithered rows
## (a checkerboard row, then a sparse one), the pixel-art way to fake a gradient.
static func paint_bands(image: Image, colors: Array[Color], from_row: int, to_row: int) -> void:
	var band_height: float = float(to_row - from_row) / colors.size()
	image.fill_rect(Rect2i(0, 0, STRIP_WIDTH, image.get_height()), colors[colors.size() - 1])
	image.fill_rect(Rect2i(0, 0, STRIP_WIDTH, from_row), colors[0])
	for band_index: int in colors.size():
		var top: int = from_row + roundi(band_index * band_height)
		var bottom: int = from_row + roundi((band_index + 1) * band_height)
		image.fill_rect(Rect2i(0, top, STRIP_WIDTH, bottom - top), colors[band_index])
		if band_index == 0:
			continue
		# Dither the border: the band above reaches 2 rows down into this one.
		var above: Color = colors[band_index - 1]
		for x: int in STRIP_WIDTH:
			if checker(x, top):
				image.set_pixel(x, top, above)
			if x % 4 == top % 4 and top + 1 < image.get_height():
				image.set_pixel(x, top + 1, above)


## Mountains in Celeste's style: a body color, the faces turned toward the light
## (upper left: where the skyline RISES to the right) in a lighter color down to a
## wobbly depth, a 1 px rim along the whole top, and snow above `snowline_row`
## (thick on the lit side, a thin shadowed line on the other).
##
## Which pixels are lit: a pixel `depth` px below the top asks about the slope a
## little to its LEFT (SPINE_LEAN px per px of depth). Right under a peak that
## lookup lands on the rising (lit) flank, so the lit face reaches past the peak
## the deeper it goes: the edge between light and shadow runs from each peak down
## and to the right, a slanted "spine" like a real ridge, not a vertical cut.
## The slope is measured over SLOPE_REACH px each way, so small bumps don't
## flicker between lit and shadow.
static func paint_mountains(image: Image, tops: PackedFloat32Array, body: Color, lit: Color, rim: Color,
		snow: Color, snow_shadow: Color, snowline_row: int, lit_depth: float, seed_value: int) -> void:
	const SPINE_LEAN: float = 0.6
	const SLOPE_REACH: int = 4
	fill_below(image, tops, body)
	var slopes: PackedFloat32Array = PackedFloat32Array()
	slopes.resize(STRIP_WIDTH)
	for x: int in STRIP_WIDTH:
		# Negative = rising to the right = facing the light.
		slopes[x] = tops[posmod(x + SLOPE_REACH, STRIP_WIDTH)] - tops[posmod(x - SLOPE_REACH, STRIP_WIDTH)]
	for x: int in STRIP_WIDTH:
		var top: int = ceili(tops[x])
		var is_lit: bool = slopes[x] < -0.5
		var face_depth: int = roundi(lit_depth * (0.6 + 0.4 * periodic_noise(x, 24.0, seed_value)))
		for y: int in range(maxi(top, 0), mini(top + face_depth, image.get_height())):
			var depth: int = y - top
			if slopes[posmod(x - roundi(depth * SPINE_LEAN), STRIP_WIDTH)] >= -0.5:
				continue
			# The last rows of the lit face dither into the body.
			var rows_left: int = face_depth - depth
			if (rows_left <= 2 and not checker(x, y)) or (rows_left <= 5 and x % 4 != y % 4 and rows_left > 2):
				continue
			image.set_pixel(x, y, lit)
		if top >= 0 and top < image.get_height():
			image.set_pixel(x, top, rim)
		if top < snowline_row:
			# More snow the higher the peak; a little per-column wobble makes it ragged.
			var snow_depth: int = 1 + roundi((snowline_row - top) * 0.12 + random01(x, 5, seed_value) * 2.0)
			if not is_lit:
				snow_depth = maxi(1, snow_depth / 3)
			for y: int in range(top, mini(top + snow_depth, image.get_height())):
				image.set_pixel(x, y, snow if is_lit else snow_shadow)


## A rim (light top line, `thickness` rows) along a skyline.
static func paint_rim(image: Image, tops: PackedFloat32Array, color: Color, thickness: int = 1) -> void:
	for x: int in STRIP_WIDTH:
		var top: int = ceili(tops[x])
		for y: int in range(maxi(top, 0), mini(top + thickness, image.get_height())):
			image.set_pixel(x, y, color)


## Diagonal hatch lines inside a silhouette, starting `start_depth` px below its
## top: the same stripes our ground's dark inside has, faint here.
static func paint_hatch(image: Image, tops: PackedFloat32Array, color: Color, spacing: int, start_depth: int) -> void:
	for x: int in STRIP_WIDTH:
		for y: int in range(maxi(ceili(tops[x]) + start_depth, 0), image.get_height()):
			if (x + y) % spacing == 0:
				image.set_pixel(x, y, color)


## A pine tree: tiers of triangles that get wider toward the bottom, with a jagged
## step at each tier, standing with its foot at (center_x, foot_row).
static func paint_pine(image: Image, center_x: int, foot_row: int, height: int, color: Color, rim: Color) -> void:
	var tier_count: int = maxi(2, height / 7)
	var tier_height: float = float(height) / tier_count
	for dy: int in height:
		var tier_position: float = fmod(dy, tier_height) / tier_height
		var tier_index: int = int(dy / tier_height)
		# Each tier is a triangle; lower tiers are wider.
		var half_width: int = roundi((tier_index + 1) * 1.1 + tier_position * 2.5)
		var y: int = foot_row - height + dy
		put_rect(image, Rect2i(center_x - half_width, y, half_width * 2 + 1, 1), color)
		# Light on the left edge of each tier (light from the upper left).
		put_pixel(image, center_x - half_width, y, rim)
	put_rect(image, Rect2i(center_x, foot_row - 1, 1, 3), color)


## A CEILING line, the mirror of ridge(): for every column, the row of the BOTTOM
## of a shape hanging from the top. `peaky` makes it hang in points (cave rock).
static func hanging(base_row: float, octaves: Array[Vector2], seed_value: int, peaky: bool) -> PackedFloat32Array:
	var bottoms: PackedFloat32Array = ridge(base_row, octaves, seed_value, peaky)
	for x: int in STRIP_WIDTH:
		bottoms[x] = base_row + (base_row - bottoms[x])
	return bottoms


## Fills every column from the strip's top down to its bottom row with `color`.
static func fill_above(image: Image, bottoms: PackedFloat32Array, color: Color) -> void:
	for x: int in STRIP_WIDTH:
		var bottom: int = clampi(floori(bottoms[x]) + 1, 0, image.get_height())
		image.fill_rect(Rect2i(x, 0, 1, bottom), color)


## A rim along the underside of a ceiling, `thickness` rows (light bouncing up
## from the floor catches the bottom edges in caves).
static func paint_bottom_rim(image: Image, bottoms: PackedFloat32Array, color: Color, thickness: int = 1) -> void:
	for x: int in STRIP_WIDTH:
		var bottom: int = floori(bottoms[x])
		for y: int in range(maxi(bottom - thickness + 1, 0), mini(bottom + 1, image.get_height())):
			image.set_pixel(x, y, color)


## Spikes of rock or ice along a line: hanging DOWN from a ceiling (`direction` 1,
## stalactites; `edge_rows` = the ceiling's bottoms) or standing UP from a floor
## (`direction` -1, stalagmites; `edge_rows` = the floor's tops). Each spike is a
## narrow triangle with a lit left edge; `count` of them, 4 to `max_length` px long.
static func paint_spikes(image: Image, edge_rows: PackedFloat32Array, direction: int, count: int, max_length: float,
		body: Color, lit: Color, seed_value: int) -> void:
	for spike_index: int in count:
		var center_x: int = roundi(random01(spike_index, 1, seed_value) * STRIP_WIDTH)
		var length: float = 4.0 + random01(spike_index, 2, seed_value) * (max_length - 4.0)
		var half_width: float = 1.0 + length * 0.12
		var root_row: float = edge_rows[posmod(center_x, STRIP_WIDTH)] - direction * 2.0
		for step: int in ceili(length):
			var width_here: int = roundi(half_width * (1.0 - float(step) / length))
			var y: int = roundi(root_row + direction * step)
			put_rect(image, Rect2i(center_x - width_here, y, width_here * 2 + 1, 1), body)
			put_pixel(image, center_x - width_here, y, lit)


## Rounded bumps: for every column, the top of the highest of many overlapping
## circles (a skyline of tree crowns, cloud tops, bushes), centers about `spacing`
## px apart, radii in `radius_range`, some lifted higher than others.
static func bumps(base_row: float, radius_range: Vector2, spacing: int, seed_value: int) -> PackedFloat32Array:
	var tops: PackedFloat32Array = PackedFloat32Array()
	tops.resize(STRIP_WIDTH)
	tops.fill(base_row)
	var bump_index: int = 0
	for center_x: int in range(0, STRIP_WIDTH, spacing):
		var radius: float = lerpf(radius_range.x, radius_range.y, random01(bump_index, 1, seed_value))
		var lift: float = random01(bump_index, 2, seed_value) * radius * 0.8
		var shifted_x: float = center_x + (random01(bump_index, 3, seed_value) - 0.5) * spacing
		for dx: int in range(-ceili(radius), ceili(radius) + 1):
			var column: int = posmod(roundi(shifted_x) + dx, STRIP_WIDTH)
			var top: float = base_row - lift - sqrt(maxf(0.0, radius * radius - dx * dx))
			tops[column] = minf(tops[column], top)
		bump_index += 1
	return tops


## Mesas and buttes: a flat top, a steep cliff down to about half the height, then
## a gentler skirt of fallen rock (talus) out to the ground. `count` of them spread
## along the strip, half-widths of the top and heights picked from the ranges.
static func mesas(base_row: float, count: int, width_range: Vector2, height_range: Vector2, seed_value: int) -> PackedFloat32Array:
	var tops: PackedFloat32Array = PackedFloat32Array()
	tops.resize(STRIP_WIDTH)
	tops.fill(base_row)
	for mesa_index: int in count:
		var center: float = (mesa_index + random01(mesa_index, 1, seed_value) * 0.6) * STRIP_WIDTH / count
		var half_top: float = lerpf(width_range.x, width_range.y, random01(mesa_index, 2, seed_value))
		var height: float = lerpf(height_range.x, height_range.y, random01(mesa_index, 3, seed_value))
		var cliff_width: float = 2.0 + height * 0.08
		var skirt_width: float = height * 0.6
		for dx: int in range(-ceili(half_top + cliff_width + skirt_width), ceili(half_top + cliff_width + skirt_width) + 1):
			var distance: float = absf(dx) - half_top
			var rise: float = 1.0
			if distance > cliff_width:
				rise = 0.5 * maxf(0.0, 1.0 - (distance - cliff_width) / skirt_width)
			elif distance > 0.0:
				rise = 1.0 - 0.5 * distance / cliff_width
			var column: int = posmod(roundi(center) + dx, STRIP_WIDTH)
			tops[column] = minf(tops[column], base_row - height * rise)
	return tops


## Layered rock: thin darker lines at uneven spacing (some layers thick, some thin),
## each wobbling gently along x, the same layers across the whole strip. Only below
## `tops` (a skyline; flat_line(-10) for all of it), and only on painted pixels.
static func paint_strata(image: Image, tops: PackedFloat32Array, color: Color, seed_value: int) -> void:
	# Which rows (before the wobble) carry a line: a random gap of 3-8 rows each time.
	var is_line_row: Dictionary = {}
	var line_row: int = 0
	while line_row < image.get_height() + 8:
		is_line_row[line_row] = true
		line_row += 3 + roundi(random01(line_row, 7, seed_value) * 5.0)
	for x: int in STRIP_WIDTH:
		var wobble: int = roundi(periodic_noise(x, 50.0, seed_value) * 3.0)
		for y: int in range(maxi(ceili(tops[x]) + 2, 0), image.get_height()):
			# Only on rock: open (transparent) pixels stay open.
			if is_line_row.has(y + wobble) and image.get_pixel(x, y).a > 0.0:
				image.set_pixel(x, y, color)


## A cave: rock hanging from the top down to about `ceiling_row` and rising from
## the bottom up to about `floor_row` (both rough by `roughness` px), rims where
## the light catches them, and `spike_count` stalactites and as many stalagmites
## up to `spike_length` px. Returns [ceiling bottoms, floor tops] so a theme can
## put more things along them.
static func paint_cave(image: Image, ceiling_row: float, floor_row: float, roughness: float, body: Color, rim: Color,
		spike_count: int, spike_length: float, seed_value: int) -> Array[PackedFloat32Array]:
	var octaves: Array[Vector2] = [Vector2(110.0, roughness), Vector2(30.0, roughness * 0.4), Vector2(9.0, 2.0)]
	var bottoms: PackedFloat32Array = hanging(ceiling_row, octaves, seed_value, true)
	var tops: PackedFloat32Array = ridge(floor_row, octaves, seed_value + 1, false)
	fill_above(image, bottoms, body)
	fill_below(image, tops, body)
	paint_bottom_rim(image, bottoms, rim)
	paint_rim(image, tops, rim)
	paint_spikes(image, bottoms, 1, spike_count, spike_length, body, rim, seed_value + 2)
	paint_spikes(image, tops, -1, spike_count / 2, spike_length * 0.6, body, rim, seed_value + 3)
	return [bottoms, tops]


## A straight skyline at `row_value` (for helpers that take one).
static func flat_line(row_value: float) -> PackedFloat32Array:
	var line: PackedFloat32Array = PackedFloat32Array()
	line.resize(STRIP_WIDTH)
	line.fill(row_value)
	return line


## A puffy cloud about `half_width` px each side of `center`: a row of overlapping
## circles, biggest in the middle, all cut off at a flat base (clouds have flat
## bottoms). Each circle is drawn twice: in `lit` first, then in `body` 1 px right
## and 2 px down, which leaves a bright crescent on the upper left of every puff
## (light from the upper left). A `shade` line along the base.
static func paint_cloud(image: Image, center: Vector2, half_width: float, body: Color, lit: Color, shade: Color, seed_value: int) -> void:
	var puff_count: int = maxi(3, roundi(half_width / 5.0))
	var base_row: int = roundi(center.y + half_width * 0.12)
	var puffs: Array[Vector3] = []  # x, y, radius
	for puff_index: int in puff_count:
		var along: float = (float(puff_index) / (puff_count - 1)) * 2.0 - 1.0  # -1..1
		var radius: float = half_width * 0.35 * (1.0 - absf(along) * 0.55) * (0.8 + random01(puff_index, 1, seed_value) * 0.4)
		puffs.append(Vector3(center.x + along * half_width * 0.75, center.y - radius * 0.4, radius))
	for puff: Vector3 in puffs:
		put_circle(image, Vector2(puff.x, puff.y), puff.z, lit, base_row)
	for puff: Vector3 in puffs:
		put_circle(image, Vector2(puff.x + 1.0, puff.y + 2.0), puff.z - 1.0, body, base_row)
	# The shade line: the bottom row under every puff.
	var left: float = puffs[0].x - puffs[0].z
	var right: float = puffs[puffs.size() - 1].x + puffs[puffs.size() - 1].z
	put_rect(image, Rect2i(roundi(left) + 1, base_row, roundi(right - left) - 1, 1), shade)


## A crystal shard: a long thin triangle from `foot` toward `angle` (radians),
## `length` px long, `half_width` px wide at the foot; its left half `lit`, right
## half `body`, so every shard has a bright face and a dark one.
static func paint_shard(image: Image, foot: Vector2, angle: float, length: float, half_width: float, body: Color, lit: Color) -> void:
	var direction: Vector2 = Vector2(cos(angle), sin(angle))
	var across: Vector2 = Vector2(-direction.y, direction.x)
	for step: int in ceili(length) + 1:
		var spine: Vector2 = foot + direction * step
		var width_here: float = half_width * (1.0 - float(step) / length)
		put_line(image, spine - across * width_here, spine, lit)
		put_line(image, spine, spine + across * width_here, body)


## A point along a curve that leaves `from` heading for `control` and bends toward
## `to` (a quadratic Bezier; `along` 0..1): palm trunks, lianas, fronds.
static func curve_point(from: Vector2, control: Vector2, to: Vector2, along: float) -> Vector2:
	return from.lerp(control, along).lerp(control.lerp(to, along), along)


## A broad leaf (banana, monstera): a pointed oval from `base` toward `angle`
## (radians), `length` px long and `half_width` at its widest, bending by `bend`
## radians along its length (a drooping tip). Like a shard: one half `lit`, the
## other `body`, and a `rib` line down the middle.
static func paint_leaf(image: Image, base: Vector2, angle: float, length: float, half_width: float,
		bend: float, body: Color, lit: Color, rib: Color) -> void:
	var spine: Vector2 = base
	for step: int in ceili(length) + 1:
		var along: float = float(step) / length
		var heading: float = angle + bend * along
		var direction: Vector2 = Vector2(cos(heading), sin(heading))
		var across: Vector2 = Vector2(-direction.y, direction.x)
		# Widest a little past the middle, pointed at both ends.
		var width_here: float = half_width * sin(PI * minf(1.0, along * 1.1)) * (1.0 - along * 0.25)
		put_line(image, spine - across * width_here, spine, lit)
		put_line(image, spine, spine + across * width_here, body)
		if step > 1 and step < length - 2:
			put_pixel(image, roundi(spine.x), roundi(spine.y), rib)
		spine += direction


## A frond (palm, fern): a curved stem from `base` toward `angle`, bending by
## `bend` radians, with thin leaflets every 2 px on both sides that hang back and
## down; leaflets get shorter toward the tip. `leaflet_length` is the longest.
static func paint_frond(image: Image, base: Vector2, angle: float, length: float, bend: float,
		leaflet_length: float, color: Color, lit: Color) -> void:
	var spine: Vector2 = base
	for step: int in ceili(length) + 1:
		var along: float = float(step) / length
		var heading: float = angle + bend * along
		var direction: Vector2 = Vector2(cos(heading), sin(heading))
		put_pixel(image, roundi(spine.x), roundi(spine.y), lit)
		if step % 2 == 0 and step > 2:
			var leaflet: float = leaflet_length * (1.0 - along * 0.7)
			for side: int in [-1, 1]:
				# Out to the side, swept back along the stem and pulled down a little.
				var out: Vector2 = Vector2(-direction.y, direction.x) * side
				var tip: Vector2 = spine + (out * 0.8 - direction * 0.45 + Vector2(0.0, 0.5)).normalized() * leaflet
				# Mostly the body color; every fourth leaflet catches the light.
				put_line(image, spine, tip, lit if step % 8 == 0 and side < 0 else color)
		spine += direction


## A volcano's cone, added to the skyline `tops` (where it's higher than what's
## there, so cones can overlap): a flat crater `half_crater` px each side of
## `center` at `crater_row`, slopes down to `base_row` `half_base` px out, steep at
## the top and flattening toward the foot (concave), a little rough.
static func cone(tops: PackedFloat32Array, center: float, crater_row: float, base_row: float, half_crater: float,
		half_base: float, seed_value: int) -> void:
	for dx: int in range(-ceili(half_base), ceili(half_base) + 1):
		var distance: float = maxf(0.0, absf(dx) - half_crater) / (half_base - half_crater)
		# Concave: steep near the top, flattening out at the foot.
		var rise: float = 1.0 - sqrt(minf(1.0, distance))
		var bumpy: float = (periodic_noise(center + dx, 12.0, seed_value) - 0.5) * 4.0 * (1.0 - rise)
		var column: int = posmod(roundi(center) + dx, STRIP_WIDTH)
		tops[column] = minf(tops[column], lerpf(base_row, crater_row, rise) + bumpy)


## A round billow of smoke or ash: a few overlapping circles around `center`, each
## drawn `lit` and then `body` 1 px right and down (a bright crescent on the upper
## left, like paint_cloud's puffs) but with no flat base: smoke is round all over.
static func paint_puff(image: Image, center: Vector2, radius: float, body: Color, lit: Color, seed_value: int) -> void:
	var circles: Array[Vector3] = [Vector3(center.x, center.y, radius)]
	for circle_index: int in 3:
		var angle: float = random01(circle_index, 1, seed_value) * TAU
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.55
		circles.append(Vector3(center.x + offset.x, center.y + offset.y, radius * (0.5 + random01(circle_index, 2, seed_value) * 0.25)))
	for circle: Vector3 in circles:
		put_circle(image, Vector2(circle.x, circle.y), circle.z, lit)
	for circle: Vector3 in circles:
		put_circle(image, Vector2(circle.x + 1.0, circle.y + 1.5), circle.z - 1.0, body)


## A clump of `count` broad leaves (paint_leaf) fanning out from `base`: centered
## on `angle`, spread over `spread` radians, lengths in `length_range`, each one
## drooping by `droop` (radians, toward the outside of the fan). The big foreground
## leaves of the green looks.
static func paint_leaf_clump(image: Image, base: Vector2, count: int, angle: float, spread: float, length_range: Vector2,
		droop: float, body: Color, lit: Color, rib: Color, seed_value: int) -> void:
	for leaf_index: int in count:
		var along: float = float(leaf_index) / maxf(1.0, count - 1.0) - 0.5  # -0.5..0.5 across the fan
		var length: float = lerpf(length_range.x, length_range.y, random01(leaf_index, 1, seed_value))
		var heading: float = angle + along * spread + (random01(leaf_index, 2, seed_value) - 0.5) * 0.2
		paint_leaf(image, base + Vector2(along * 6.0, 0.0), heading, length, 5.0 + length * 0.14, signf(along) * droop,
			body, lit, rib)


## A big crag rising from the bottom edge of `image`: a jagged rock `half_width`
## px each side of `foot_x`, `height` px tall, a lit left face, and `cap` lying on
## its tops and ledges (snow, sand, moss; pass `lit` for none). For foregrounds.
static func paint_crag(image: Image, foot_x: float, half_width: float, height: float, body: Color, lit: Color,
		cap: Color, seed_value: int) -> void:
	var tops: PackedFloat32Array = flat_line(image.get_height() + 4.0)
	for dx: int in range(-ceili(half_width), ceili(half_width) + 1):
		var shape: float = 1.0 - pow(absf(dx) / half_width, 1.6)
		var rough: float = (periodic_noise(foot_x + dx, 8.0, seed_value) - 0.5) * 10.0
		var column: int = posmod(roundi(foot_x) + dx, STRIP_WIDTH)
		tops[column] = minf(tops[column], image.get_height() - height * shape + rough * shape)
	paint_mountains(image, tops, body, lit, lit, cap, lit, image.get_height(), 10.0, seed_value)


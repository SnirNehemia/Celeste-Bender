class_name SanctumBuildings
extends RefCounted
## SanctumBuildings: paints the buildings of the SANCTUM looks (SanctumStyle), a
## few small temples in the Tibetan manner, as the air nomads might build them:
##   air towers   round white towers under steep blue cone roofs, gold spires
##   dzong walls  whitewashed walls that lean inward as they rise, rows of dark
##                trapezoid windows with black frames, a deep red band along the top
##                with gold discs, flat roofs
##   stupas       white domes on stepped bases under a gold spire
##   prayer flags strings of blue, white, red, green and yellow flags
## Every painter takes `haze` (0 near .. 1 gone into the air: SanctumStyle.far) and
## paints on any strip or tall picture (BackdropPaint). Static helpers, no node.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const WALL: Color = Color(0.96, 0.94, 0.88)
const WALL_LIT: Color = Color(1.0, 0.99, 0.95)
const WALL_SHADE: Color = Color(0.8, 0.78, 0.79)
const WALL_LINE: Color = Color(0.64, 0.6, 0.6)
const WINDOW: Color = Color(0.22, 0.17, 0.2)
const WINDOW_FRAME: Color = Color(0.1, 0.08, 0.1)
const BAND: Color = Color(0.55, 0.18, 0.16)
const BAND_DARK: Color = Color(0.42, 0.12, 0.12)
const ROOF: Color = Color(0.24, 0.44, 0.68)
const ROOF_LIT: Color = Color(0.4, 0.62, 0.84)
const ROOF_LINE: Color = Color(0.15, 0.29, 0.5)
const GOLD: Color = Color(0.88, 0.66, 0.24)
const GOLD_LIT: Color = Color(1.0, 0.87, 0.48)
const GOLD_SHADE: Color = Color(0.66, 0.46, 0.16)
const PILLAR: Color = Color(0.62, 0.2, 0.17)
const PILLAR_LIT: Color = Color(0.78, 0.3, 0.22)
## Prayer flags, in their order.
const FLAG_COLORS: Array[Color] = [Color(0.25, 0.48, 0.82), Color(0.97, 0.96, 0.92), Color(0.86, 0.26, 0.22),
	Color(0.3, 0.64, 0.36), Color(0.97, 0.8, 0.26)]


## A round tower: walls from `base_row` up to `wall_top_row`, `half_width` px each
## side of `center_x`, lit on the left and shaded on the right (it's round), a red
## band with a balcony near the top, little arched windows up the middle; then a
## cone roof `cone_height` tall and a gold spire.
static func paint_air_tower(image: Image, center_x: int, base_row: int, wall_top_row: int, half_width: int,
		cone_height: int, haze: float) -> void:
	var wall: Color = SanctumStyle.far(WALL, haze)
	var lit: Color = SanctumStyle.far(WALL_LIT, haze)
	var shade: Color = SanctumStyle.far(WALL_SHADE, haze)
	var line: Color = SanctumStyle.far(WALL_LINE, haze)
	var width: int = half_width * 2
	var left: int = center_x - half_width
	BackdropPaint.put_rect(image, Rect2i(left, wall_top_row, width, base_row - wall_top_row), wall)
	BackdropPaint.put_rect(image, Rect2i(left, wall_top_row, maxi(1, width / 6), base_row - wall_top_row), lit)
	BackdropPaint.put_rect(image, Rect2i(left + width - maxi(2, width / 4), wall_top_row, maxi(2, width / 4), base_row - wall_top_row), shade)
	BackdropPaint.put_rect(image, Rect2i(left + width - 1, wall_top_row, 1, base_row - wall_top_row), line)
	# Rings round the tower every so often, and windows between them.
	var ring_spacing: int = maxi(12, half_width * 3)
	for ring_row: int in range(base_row - ring_spacing, wall_top_row + 8, -ring_spacing):
		BackdropPaint.put_rect(image, Rect2i(left, ring_row, width, 1), line)
		if half_width >= 4:
			var window_height: int = maxi(2, half_width / 2 + 1)
			_paint_window(image, center_x, ring_row - ring_spacing / 2 - window_height / 2, maxi(1, half_width / 3), window_height, haze)
	# The red band and a balcony ledge just under the roof.
	var band_height: int = maxi(2, half_width / 3)
	BackdropPaint.put_rect(image, Rect2i(left, wall_top_row + 2, width, band_height), SanctumStyle.far(BAND, haze))
	BackdropPaint.put_rect(image, Rect2i(left - 1, wall_top_row + 2 + band_height, width + 2, 1), lit)
	if half_width >= 6:
		for disc_x: int in range(left + 3, left + width - 2, 5):
			BackdropPaint.put_pixel(image, disc_x, wall_top_row + 2 + band_height / 2, SanctumStyle.far(GOLD, haze))
	paint_cone_roof(image, center_x, wall_top_row + 1, half_width + maxi(2, half_width / 3), cone_height, haze)


## A steep cone roof whose eave (`eave_row`, `half_width` px each side) flares out a
## little, lit on the left, with rings of tiles; a gold spire with an orb on top.
static func paint_cone_roof(image: Image, center_x: int, eave_row: int, half_width: int, height: int, haze: float) -> void:
	var roof: Color = SanctumStyle.far(ROOF, haze)
	var lit: Color = SanctumStyle.far(ROOF_LIT, haze)
	var line: Color = SanctumStyle.far(ROOF_LINE, haze)
	for lift: int in height:
		var along: float = float(lift) / height
		# Concave: wide at the eave, pulled in quickly, then a long slim point.
		var half: float = half_width * pow(1.0 - along, 1.6)
		var y: int = eave_row - lift
		var row_left: int = roundi(center_x - half)
		var row_width: int = maxi(1, roundi(half * 2.0))
		var row_color: Color = line if lift > 1 and lift % 5 == 0 else roof
		BackdropPaint.put_rect(image, Rect2i(row_left, y, row_width, 1), row_color)
		BackdropPaint.put_rect(image, Rect2i(row_left, y, maxi(1, row_width * 2 / 5), 1), lit if row_color == roof else line)
	# The eave's lip, a shade under it.
	BackdropPaint.put_rect(image, Rect2i(center_x - half_width - 1, eave_row, half_width * 2 + 2, 1), lit)
	BackdropPaint.put_rect(image, Rect2i(center_x - half_width, eave_row + 1, half_width * 2, 1), line)
	# The spire: a gold rod with a ring and an orb.
	var spire_height: int = maxi(4, height / 3)
	var top: int = eave_row - height
	BackdropPaint.put_rect(image, Rect2i(center_x, top - spire_height, 1, spire_height + 2), SanctumStyle.far(GOLD, haze))
	BackdropPaint.put_rect(image, Rect2i(center_x - 1, top - spire_height / 2, 3, 1), SanctumStyle.far(GOLD_LIT, haze))
	BackdropPaint.put_circle(image, Vector2(center_x, top - spire_height - 1), maxf(1.0, spire_height / 6.0), SanctumStyle.far(GOLD_LIT, haze))


## A dzong wall: a block from `left` to `right` (at its foot) standing on
## `base_row`, up to `top_row`, its sides leaning inward as they rise (`lean` px
## per 10 rows), white with rows of trapezoid windows, a deep red band with gold
## discs along the top, a flat roof edge.
static func paint_dzong(image: Image, left: int, right: int, base_row: int, top_row: int, lean: float, haze: float) -> void:
	var wall: Color = SanctumStyle.far(WALL, haze)
	var lit: Color = SanctumStyle.far(WALL_LIT, haze)
	var shade: Color = SanctumStyle.far(WALL_SHADE, haze)
	var band_height: int = clampi((base_row - top_row) / 7, 3, 12)
	for y: int in range(top_row, base_row):
		var inset: int = roundi((base_row - y) * lean / 10.0)
		var row_left: int = left + inset
		var row_right: int = right - inset
		var color: Color = wall
		if y < top_row + band_height:
			color = SanctumStyle.far(BAND if (y - top_row) % 3 != 2 else BAND_DARK, haze)
		BackdropPaint.put_rect(image, Rect2i(row_left, y, row_right - row_left, 1), color)
		if y >= top_row + band_height:
			BackdropPaint.put_pixel(image, row_left, y, lit)
			BackdropPaint.put_rect(image, Rect2i(row_right - 3, y, 3, 1), shade)
	# The roof edge and gold discs in the band.
	var top_inset: int = roundi((base_row - top_row) * lean / 10.0)
	BackdropPaint.put_rect(image, Rect2i(left + top_inset - 1, top_row - 1, right - left - top_inset * 2 + 2, 1), lit)
	for disc_x: int in range(left + top_inset + 6, right - top_inset - 4, 12):
		BackdropPaint.put_circle(image, Vector2(disc_x, top_row + band_height / 2), maxf(1.0, band_height / 3.0), SanctumStyle.far(GOLD, haze))
	# Windows: rows from just under the band down to near the foot, in columns.
	var window_rows: int = maxi(1, (base_row - top_row - band_height - 10) / 20)
	for window_row: int in window_rows:
		var y: int = top_row + band_height + 6 + window_row * 20
		var inset: int = roundi((base_row - y) * lean / 10.0)
		for window_x: int in range(left + inset + 8, right - inset - 8, 16):
			_paint_window(image, window_x, y, 3, 7, haze)


## A Tibetan window: a dark opening a little wider at the bottom, framed in black
## that widens toward the bottom (the trapezoid frame), under a small lintel.
static func _paint_window(image: Image, center_x: int, top_row: int, half_width: int, height: int, haze: float) -> void:
	var frame: Color = SanctumStyle.far(WINDOW_FRAME, haze)
	var window: Color = SanctumStyle.far(WINDOW, haze)
	BackdropPaint.put_rect(image, Rect2i(center_x - half_width - 1, top_row - 1, half_width * 2 + 3, 1), SanctumStyle.far(BAND, haze))
	for y: int in height:
		var widen: int = y * 2 / maxi(1, height)
		BackdropPaint.put_rect(image, Rect2i(center_x - half_width - widen, top_row + y, half_width * 2 + 1 + widen * 2, 1), frame)
		BackdropPaint.put_rect(image, Rect2i(center_x - half_width + 1, top_row + y, maxi(1, half_width * 2 - 1), 1), window)


## A stupa (chorten): a stepped white base, a round dome, a red-and-gold neck of
## rings and a gold tip, standing on `base_row`, `size` px wide at its base.
static func paint_stupa(image: Image, center_x: int, base_row: int, size: int, haze: float) -> void:
	var wall: Color = SanctumStyle.far(WALL, haze)
	var shade: Color = SanctumStyle.far(WALL_SHADE, haze)
	var half: int = size / 2
	var row: int = base_row
	for step: int in 3:
		var step_half: int = half - step * maxi(1, size / 10)
		BackdropPaint.put_rect(image, Rect2i(center_x - step_half, row - 2, step_half * 2, 2), wall)
		BackdropPaint.put_rect(image, Rect2i(center_x + step_half - 2, row - 2, 2, 2), shade)
		row -= 2
	var dome_radius: float = size * 0.3
	BackdropPaint.put_circle(image, Vector2(center_x, row), dome_radius, wall, row)
	BackdropPaint.put_circle(image, Vector2(center_x + dome_radius * 0.4, row), dome_radius * 0.6, shade, row)
	BackdropPaint.put_circle(image, Vector2(center_x, row), dome_radius * 0.75, wall, row)
	var neck: int = row - roundi(dome_radius)
	BackdropPaint.put_rect(image, Rect2i(center_x - 1, neck - 2, 3, 2), SanctumStyle.far(BAND, haze))
	var rings: int = maxi(3, size / 4)
	for ring: int in rings:
		var ring_half: int = maxi(0, 2 - ring * 2 / rings)
		BackdropPaint.put_rect(image, Rect2i(center_x - ring_half, neck - 3 - ring, ring_half * 2 + 1, 1),
			SanctumStyle.far(GOLD if ring % 2 == 0 else GOLD_SHADE, haze))
	BackdropPaint.put_pixel(image, center_x, neck - 4 - rings, SanctumStyle.far(GOLD_LIT, haze))


## A string of prayer flags sagging from `from` to `to` (its lowest point near
## `sag`), a flag every `spacing` px, `flag_size` px square; `haze` far.
static func paint_prayer_flags(image: Image, from: Vector2, to: Vector2, sag: Vector2, spacing: int, flag_size: int,
		haze: float) -> void:
	var string_color: Color = SanctumStyle.far(Color(0.45, 0.4, 0.38), haze)
	var steps: int = ceili(from.distance_to(sag) + sag.distance_to(to))
	var flag_index: int = 0
	for step: int in steps:
		var point: Vector2 = BackdropPaint.curve_point(from, sag, to, float(step) / steps)
		BackdropPaint.put_pixel(image, roundi(point.x), roundi(point.y), string_color)
		if step % spacing == spacing / 2:
			var color: Color = SanctumStyle.far(FLAG_COLORS[flag_index % FLAG_COLORS.size()], haze)
			BackdropPaint.put_rect(image, Rect2i(roundi(point.x) - flag_size / 2, roundi(point.y) + 1, flag_size, flag_size), color)
			# A darker fold down one side: they flutter.
			BackdropPaint.put_rect(image, Rect2i(roundi(point.x) + flag_size / 2 - 1, roundi(point.y) + 1, 1, flag_size), color.darkened(0.15))
			flag_index += 1


## A slim cypress (juniper, up here): a dark spindle lit on its left edge.
static func paint_cypress(image: Image, center_x: int, foot_row: int, height: int, haze: float) -> void:
	var body: Color = SanctumStyle.far(SanctumStyle.CYPRESS, haze)
	var lit: Color = SanctumStyle.far(SanctumStyle.CYPRESS_LIT, haze)
	for lift: int in height:
		var along: float = float(lift) / height
		var half: int = roundi(2.0 + 1.5 * sin(PI * minf(1.0, along * 1.25 + 0.05)))
		if lift > height - 3:
			half = 0
		var y: int = foot_row - 1 - lift
		BackdropPaint.put_rect(image, Rect2i(center_x - half, y, half * 2 + 1, 1), body)
		BackdropPaint.put_pixel(image, center_x - half, y, lit)


## A blossom tree: a short crooked trunk and a crown of pink clumps, lit upper left.
static func paint_blossom_tree(image: Image, center_x: int, foot_row: int, size: float, haze: float, seed_value: int) -> void:
	var trunk: Color = SanctumStyle.far(Color(0.38, 0.28, 0.27), haze)
	BackdropPaint.put_line(image, Vector2(center_x, foot_row), Vector2(center_x + size * 0.15, foot_row - size * 0.7), trunk, 2)
	for clump_index: int in 7:
		var clump: Vector2 = Vector2(center_x + size * 0.15 + (BackdropPaint.random01(clump_index, 1, seed_value) - 0.5) * size * 1.3,
			foot_row - size * 0.8 - BackdropPaint.random01(clump_index, 2, seed_value) * size * 0.5)
		var radius: float = size * (0.22 + BackdropPaint.random01(clump_index, 3, seed_value) * 0.12)
		BackdropPaint.put_circle(image, clump + Vector2(-1.0, -1.0), radius, SanctumStyle.far(SanctumStyle.BLOSSOM_LIT, haze))
		BackdropPaint.put_circle(image, clump, radius - 1.0, SanctumStyle.far(SanctumStyle.BLOSSOM, haze))
		BackdropPaint.put_circle(image, clump + Vector2(1.0, 1.5), radius - 2.0, SanctumStyle.far(SanctumStyle.BLOSSOM_SHADE, haze))

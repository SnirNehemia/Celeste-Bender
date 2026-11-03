class_name CavernStyle
extends RefCounted
## CavernStyle: what the three CAVERN looks (themes/cavern/*.gd) share. A vast
## cave inside a mountain range: the upper cave (SURFACE, still underground, lit
## from cracks in the ceiling, bats about), the deep (UNDERGROUND, very dark, an
## old carved face and eyes in the dark) and, out through the rock, the open ridge
## of the mountains the cave is in (SKYLINE, daytime, brown crags). Not a node:
## static painters, colors and helpers.
##
## The other way round from most looks: the upper cave and the deep are ONE space
## (their change is SOFT, like underwater's), and the skyline is where you BREAK
## out of the rock (Backdrop.BREAK_SKYLINE_LOOKS). So the upper cave and the deep
## share their TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer),
## and the skyline paints its own.
##
## Colors: violet air, brown rock. The cave's air darkens from a dusky mauve under
## the ceiling to pitch black in the deep (AIR_BANDS); rock is painted in the
## ground's style (BackdropTerrain) in brown, then pulled toward the air AT ITS
## OWN HEIGHT and darkened the deeper it is (sink_into_air), so a wall that runs
## from the upper cave into the deep sinks into the dark as it goes down.
##
## TALL layers, shared by the upper cave and the deep (add_shared_layers):
##   Air        the cave's air, in bands from the ceiling down
##   Frame0..3  four walls of rock, far to near (FRAME_LAYERS), each holed with big
##              cave openings that frame the walls behind it: frames within
##              frames. A wall is mostly openings, one per slot in each view: the
##              rock between them runs from the top of the screen to the bottom.
##              In the upper cave they're round caves: a floor that's a flat
##              ledge or a slope, now and then a floating ledge, stalactites from
##              the roof. In the deep they're sheer chasms: stepped cliffs that
##              drop out of sight into the black, thin ledges jutting from them.
##              Further walls have smaller holes and sink deeper into the air;
##              through the furthest openings, the air itself
##   Front      right in front: stalactite clusters hanging into the upper cave, a
##              great dark pillar along the left edge (a stalagmite rising in the
##              upper cave's corner, a column down the whole deep), stalagmites
##              rising in the deep
## Each altitude adds its own things between them (slots in add_shared_layers):
## the upper cave its light shafts and bats, the deep its carved face and eyes.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "cavern"

## The cave's air, from just under the ceiling (top of the upper cave) down to the
## floor of the deep. The deep's air falls off fast to PITCH BLACK (bands 8-10),
## so its furthest walls, which fade into the air, are swallowed by the dark: the
## deep reads by its nearer walls' faint rims, and what's far back is barely there.
const AIR_BANDS: Array[Color] = [Color(0.45, 0.37, 0.49), Color(0.41, 0.33, 0.46), Color(0.36, 0.29, 0.42),
	Color(0.31, 0.24, 0.37), Color(0.26, 0.2, 0.32), Color(0.17, 0.12, 0.23), Color(0.07, 0.05, 0.1),
	Color(0.025, 0.018, 0.035), Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0)]
## The air's bands run from this screen row of the upper cave to this one of the deep.
const AIR_TOP_SCREEN_ROW: int = 0
const AIR_BOTTOM_SCREEN_ROW: int = 180
## What deep rock darkens toward, and how much at the deep's floor (it starts at 0
## at the top of the upper cave).
const DARK: Color = Color(0.0, 0.0, 0.0)
const MAX_DARKNESS: float = 0.8

## Brown rock in the ground's style: [crust, rim, edge, inside, hatch, deep]; the
## deep has a violet shade.
const ROCK: Array[Color] = [Color(0.55, 0.4, 0.31), Color(0.72, 0.58, 0.45), Color(0.29, 0.19, 0.18),
	Color(0.2, 0.13, 0.15), Color(0.25, 0.17, 0.18), Color(0.1, 0.07, 0.1)]
## The front: near-black rock with a faint lit crust.
const FRONT_ROCK: Array[Color] = [Color(0.17, 0.12, 0.15), Color(0.27, 0.2, 0.21), Color(0.07, 0.045, 0.07),
	Color(0.05, 0.035, 0.055), Color(0.07, 0.05, 0.075), Color(0.03, 0.02, 0.035)]
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## The walls of rock, far to near: Vector4(slots per strip, opening width from,
## to, haze). Every slot has an opening in the upper cave and one in the deep, so
## a wall is mostly openings: its rock is pillars between them, from the top of the
## screen to the bottom, and a band between the two views. Nearer walls have fewer,
## bigger openings, so near rock frames the screen and far rock shows through.
const FRAME_LAYERS: Array[Vector4] = [Vector4(5.0, 88.0, 112.0, 0.8), Vector4(4.0, 112.0, 138.0, 0.64),
	Vector4(3.0, 148.0, 178.0, 0.47), Vector4(2.0, 226.0, 262.0, 0.3)]
## Each wall's openings are this tall (from, to), out of the 180 rows of a view.
const FRAME_HEIGHTS: Array[Vector2] = [Vector2(108.0, 138.0), Vector2(122.0, 150.0), Vector2(136.0, 164.0),
	Vector2(150.0, 176.0)]
## An opening's middle sits about this screen row of its view (per wall, far to
## near: nearer walls' openings sit lower, so their floors stay near the bottom of
## the screen instead of filling it), give or take OPENING_ROW_SPREAD / 2.
const OPENING_ROWS: Array[float] = [84.0, 90.0, 98.0, 108.0]
const OPENING_ROW_SPREAD: float = 24.0
## The deep's openings are CHASMS instead (_carve_chasm), DEEP_GROWTH times as
## wide as an opening: a roof somewhere in CHASM_ROOF_ROWS (screen rows of the
## deep), arching out over CHASM_ARCH_ROWS, then sheer cliffs straight down out
## of the screen into the black: no floor. Each cliff face sits CHASM_FACE_RANGE
## (from, plus up to) of the half width from the middle, wandering slowly with a
## noise CHASM_FACE_NOISE_ROWS rows across, cut CHASM_FACE_ROWS rows at a time;
## every CHASM_STEP_ROWS rows (from, to), CHASM_LEDGE_SHARE of the time, a thin
## ledge juts into the drop. So the deep reads as dramatic cliffs, the upper cave
## as rounded caves.
const DEEP_GROWTH: float = 1.15
const CHASM_ROOF_ROWS: Vector2 = Vector2(4.0, 30.0)
const CHASM_ARCH_ROWS: float = 30.0
const CHASM_FACE_RANGE: Vector2 = Vector2(0.8, 0.18)
const CHASM_FACE_NOISE_ROWS: float = 120.0
const CHASM_FACE_ROWS: int = 3
## Sudden cliff steps: every CHASM_STEP_EVERY rows a face jumps in or out by up
## to CHASM_STEP_DEPTH / 2 of the half width.
const CHASM_STEP_EVERY: float = 64.0
const CHASM_STEP_DEPTH: float = 0.32
const CHASM_STEP_ROWS: Vector2i = Vector2i(26, 44)
const CHASM_LEDGE_SHARE: float = 0.55
## Shelves: how far they reach (share of the half width, from, to) and how thick.
const CHASM_SHELF_REACH: Vector2 = Vector2(0.28, 0.55)
const CHASM_SHELF_ROWS: int = 4
## Stalactites: under each roof, and their length (from, to); a stalagmite on
## CHASM_STALAGMITE_SHARE of the shelves.
const CHASM_ROOF_TIPS: int = 4
const CHASM_TIP_LENGTH: Vector2 = Vector2(12.0, 28.0)
const CHASM_STALAGMITE_SHARE: float = 0.25
## An opening's floor: its high end this far below the opening's middle (a share of
## its height, from, to); a slope's low end anywhere from level with it to
## SLOPE_DROP lower; SLOPE_SHARE of floors slope, the others are flat ledges.
const FLOOR_DEPTH: Vector2 = Vector2(0.12, 0.3)
const SLOPE_DROP: float = 0.26
const SLOPE_SHARE: float = 0.6
const FRAME_SCROLLS: Array[Vector2] = [Vector2(0.05, 0.018), Vector2(0.09, 0.03), Vector2(0.15, 0.05), Vector2(0.24, 0.08)]
const FRAME_CRUSTS: Array[float] = [2.0, 2.5, 3.0, 4.0]
## Each wall's openings are shifted this far along the strip from the last one's,
## so the holes of one wall don't line up with the holes behind it.
const FRAME_STAGGER: int = 57
## Rows the front's pillar is built from, each its own width.
const SLAB_ROWS: int = 6

## A tall picture of the air in bands, each with alpha `alpha` (sink_into_air),
## by alpha: made once per run.
static var _air_overlays: Dictionary = {}


## The tall row of the air's top and bottom (AIR_BANDS).
static func air_top_row() -> int:
	return BackdropPaint.tall_row(AIR_TOP_SCREEN_ROW, BackdropTheme.SURFACE_SECTION)


static func air_bottom_row() -> int:
	return BackdropPaint.tall_row(AIR_BOTTOM_SCREEN_ROW, BackdropTheme.UNDERGROUND_SECTION)


## The air's color at tall row `tall_y` (no dither: for single shapes' palettes).
static func air_at(tall_y: int) -> Color:
	var along: float = clampf(float(tall_y - air_top_row()) / (air_bottom_row() - air_top_row()), 0.0, 0.999)
	return AIR_BANDS[floori(along * AIR_BANDS.size())]


## The Air layer: the bands.
static func paint_air(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, AIR_BANDS, air_top_row(), air_bottom_row())


## Pulls every solid pixel of `tall` `haze` (0-1) toward the air at its own row,
## then darkens it toward DARK the deeper it is (`darkening` 0-1 of the full
## amount). Two Image.blend_rect_mask calls (blends only where the mask's pixels
## aren't see-through, in C++: a GDScript loop over the picture would take long),
## with the picture itself as the mask, so the air around the rock stays clear.
static func sink_into_air(tall: Image, haze: float, darkening: float) -> void:
	var whole: Rect2i = Rect2i(0, 0, BackdropPaint.STRIP_WIDTH, tall.get_height())
	var mask: Image = tall.duplicate() as Image
	if haze > 0.0:
		var key: int = roundi(haze * 100.0)
		if not _air_overlays.has(key):
			var bands: Array[Color] = []
			for band: Color in AIR_BANDS:
				bands.append(Color(band, haze))
			var overlay: Image = BackdropPaint.new_tall()
			BackdropPaint.paint_bands(overlay, bands, air_top_row(), air_bottom_row())
			_air_overlays[key] = overlay
		tall.blend_rect_mask(_air_overlays[key], mask, whole, Vector2i.ZERO)
	if darkening > 0.0:
		var shade: Image = BackdropPaint.new_tall()
		for y: int in range(air_top_row(), tall.get_height()):
			var depth: float = clampf(float(y - air_top_row()) / (air_bottom_row() - air_top_row()), 0.0, 1.0)
			shade.fill_rect(Rect2i(0, y, BackdropPaint.STRIP_WIDTH, 1), Color(DARK, depth * MAX_DARKNESS * darkening))
		tall.blend_rect_mask(shade, mask, whole, Vector2i.ZERO)


## One wall of rock (FRAME_LAYERS[layer_index]): solid from above the upper
## cave's screen to the bottom of the deep, then its openings carved out (round
## caves in the upper cave, _carve_opening; sheer chasms in the deep,
## _carve_chasm), painted in the ground's style and sunk into the air.
static func paint_frame(tall: Image, layer_index: int) -> void:
	var spec: Vector4 = FRAME_LAYERS[layer_index]
	var heights: Vector2 = FRAME_HEIGHTS[layer_index]
	var seed_value: int = 6100 + layer_index * 40
	var top_row: int = BackdropPaint.tall_row(-BackdropPaint.SCREEN_TOP_ROW, BackdropTheme.SURFACE_SECTION)
	var wall: BackdropTerrain.Mask = BackdropTerrain.new_band(top_row, tall.get_height())
	wall.add_rect(Rect2i(wall.origin, wall.size))
	var slot_count: int = roundi(spec.x)
	var slot_width: float = float(BackdropPaint.STRIP_WIDTH) / slot_count
	for slot: int in slot_count:
		for section: int in [BackdropTheme.SURFACE_SECTION, BackdropTheme.UNDERGROUND_SECTION]:
			var opening: int = slot * 2 + section  # its own random numbers
			var is_deep: bool = section == BackdropTheme.UNDERGROUND_SECTION
			var size: Vector2 = Vector2(lerpf(spec.y, spec.z, BackdropPaint.random01(opening, 1, seed_value)),
				lerpf(heights.x, heights.y, BackdropPaint.random01(opening, 2, seed_value))) * (DEEP_GROWTH if is_deep else 1.0)
			var center_x: float = (slot + 0.5) * slot_width + layer_index * FRAME_STAGGER \
				+ (BackdropPaint.random01(opening, 3, seed_value) - 0.5) * (slot_width - size.x) * 0.8  # 0.8: never quite into the next slot's pillar
			if is_deep:
				_carve_chasm(wall, fposmod(center_x, BackdropPaint.STRIP_WIDTH), size.x * 0.5, seed_value + opening + 1)
				continue
			var center_y: float = BackdropPaint.tall_row(OPENING_ROWS[layer_index]
				+ (BackdropPaint.random01(opening, 4, seed_value) - 0.5) * OPENING_ROW_SPREAD, section)
			_carve_opening(wall, Vector2(fposmod(center_x, BackdropPaint.STRIP_WIDTH), center_y), size, seed_value + opening + 1)
	BackdropTerrain.roughen(wall, seed_value)
	BackdropTerrain.paint(tall, wall, ROCK, FRAME_CRUSTS[layer_index], 12.0, 2, seed_value)
	# Far walls take the air's color (pitch black in the deep), near walls the dark: the
	# less a wall is hazed, the more it's darkened.
	sink_into_air(tall, spec.w, 1.0 - spec.w)


## Carves one cave opening about `size` big around `center` out of `wall`: a few
## overlapping ellipses (a blobby hole, not a perfect oval), then a floor put back
## in its lower part, flat (a ledge) or slanted (a slope), now and then a ledge
## floating in it, and stalactites on its roof. Each shape is also made a strip to
## each side, so an opening at the strip's end carries on at the other.
static func _carve_opening(wall: BackdropTerrain.Mask, center: Vector2, size: Vector2, seed_value: int) -> void:
	const LOBES: int = 4
	var wraps: Array[float] = [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]
	for lobe: int in LOBES:
		var along: float = (lobe + 0.5) / LOBES - 0.5  # -0.5..0.5 across the opening
		var lobe_center: Vector2 = center + Vector2(along * size.x * 0.6,
			(BackdropPaint.random01(lobe, 1, seed_value) - 0.5) * size.y * 0.25)
		var radii: Vector2 = Vector2(size.x * (0.22 + 0.1 * BackdropPaint.random01(lobe, 2, seed_value)),
			size.y * (0.32 + 0.14 * BackdropPaint.random01(lobe, 3, seed_value)))
		for wrap_shift: float in wraps:
			wall.cut_ellipse(lobe_center + Vector2(wrap_shift, 0.0), radii)
	# The floor: from the left end to the right end, flat or a slope.
	var left: float = center.x - size.x * 0.5
	var right: float = center.x + size.x * 0.5
	var floor_high: float = center.y + size.y * lerpf(FLOOR_DEPTH.x, FLOOR_DEPTH.y, BackdropPaint.random01(0, 5, seed_value))
	var floor_low: float = floor_high
	if BackdropPaint.random01(0, 6, seed_value) < SLOPE_SHARE:
		floor_low = floor_high + size.y * SLOPE_DROP * (0.4 + 0.6 * BackdropPaint.random01(0, 7, seed_value))
	# Which way it slopes: down to the left or to the right.
	var slopes_left: bool = BackdropPaint.random01(0, 13, seed_value) < 0.5
	var floor_left: float = floor_low if slopes_left else floor_high
	var floor_right: float = floor_high if slopes_left else floor_low
	var below: int = roundi(center.y + size.y * 0.6)
	for x: int in range(roundi(left), roundi(right) + 1):
		var floor_row: int = roundi(lerpf(floor_left, floor_right, (x - left) / (right - left)))
		for wrap_shift: float in wraps:
			wall.add_rect(Rect2i(x + roundi(wrap_shift), floor_row, 1, maxi(0, below - floor_row)))
	# Now and then a ledge floating in the upper part.
	if BackdropPaint.random01(0, 8, seed_value) < 0.5:
		var ledge_tiles: int = 3 + roundi(BackdropPaint.random01(0, 9, seed_value) * 3.0)
		var ledge_left: int = roundi(center.x + (BackdropPaint.random01(0, 10, seed_value) - 0.5) * size.x * 0.4) - ledge_tiles * 3
		var ledge_row: int = roundi(center.y - size.y * 0.08)
		for wrap_shift: float in wraps:
			BackdropTerrain.add_chunk(wall, ledge_left + roundi(wrap_shift), ledge_row, ledge_tiles, 2, 6, seed_value + 3)
	# Stalactites from the roof: find the roof above a few spots and hang a spike.
	for tip: int in 3:
		var x: int = roundi(lerpf(left + size.x * 0.15, right - size.x * 0.15, BackdropPaint.random01(tip, 11, seed_value)))
		var roof: int = roundi(center.y - size.y * 0.1)
		while roof > wall.origin.y and not wall.is_solid(posmod(x, BackdropPaint.STRIP_WIDTH), roof):
			roof -= 1
		var length: float = 6.0 + BackdropPaint.random01(tip, 12, seed_value) * size.y * 0.12
		for step: int in roundi(length):
			# Wider for longer spikes, narrowing evenly to a point at the tip.
			var half_width: float = (2.0 + length * 0.15) * (1.0 - float(step) / length)
			if half_width < 0.5:
				break
			for wrap_shift: float in wraps:
				wall.add_rect(Rect2i(roundi(x + wrap_shift - half_width), roof + step, maxi(1, roundi(half_width * 2.0)), 1))


## Carves one chasm of the deep around `center_x` out of `wall`, about
## `half_width` each side (see CHASM_ROOF_ROWS for its shape): an arched roof,
## then two sheer cliff faces all the way down that step in and out now and
## then, shelves jutting from them with stalactites under them (and the odd
## stalagmite on top), stalactites from the roof. Wraps like _carve_opening.
static func _carve_chasm(wall: BackdropTerrain.Mask, center_x: float, half_width: float, seed_value: int) -> void:
	var wraps: Array[float] = [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]
	var roof: int = BackdropPaint.tall_row(lerpf(CHASM_ROOF_ROWS.x, CHASM_ROOF_ROWS.y, BackdropPaint.random01(0, 1, seed_value)),
		BackdropTheme.UNDERGROUND_SECTION)
	var bottom: int = wall.origin.y + wall.size.y
	# The cliff faces, a few rows at a time.
	for row: int in range(roof, bottom, CHASM_FACE_ROWS):
		# sqrt: the arch opens fast just under the roof, then slowly.
		var arch: float = sqrt(clampf(float(row - roof) / CHASM_ARCH_ROWS, 0.25, 1.0))
		var left: float = _chasm_face(half_width, row, seed_value) * arch
		var right: float = _chasm_face(half_width, row, seed_value + 1) * arch
		for wrap_shift: float in wraps:
			wall.cut_rect(Rect2i(roundi(center_x - left + wrap_shift), row, roundi(left + right), CHASM_FACE_ROWS))
	# Stalactites hanging from the roof's arch.
	for tip: int in CHASM_ROOF_TIPS:
		var x: float = center_x + (BackdropPaint.random01(tip, 8, seed_value) - 0.5) * half_width * 0.9
		var length: float = lerpf(CHASM_TIP_LENGTH.x, CHASM_TIP_LENGTH.y, BackdropPaint.random01(tip, 9, seed_value))
		_add_spike(wall, x, _find_edge(wall, x, roof + 8, -1), length, 1, wraps)
	# Shelves out from the cliffs into the drop, below the arch: thick plates with
	# stalactites dripping under them and, now and then, a stalagmite on top.
	var row: int = roof + roundi(CHASM_ARCH_ROWS)
	var shelf: int = 0
	while row < bottom:
		row += CHASM_STEP_ROWS.x + floori(BackdropPaint.random01(shelf, 2, seed_value) * (CHASM_STEP_ROWS.y - CHASM_STEP_ROWS.x + 1))
		shelf += 1
		if BackdropPaint.random01(shelf, 5, seed_value) >= CHASM_LEDGE_SHARE:
			continue
		var from_left: bool = BackdropPaint.random01(shelf, 7, seed_value) < 0.5
		var face: float = _chasm_face(half_width, row, seed_value + (0 if from_left else 1))
		var reach: int = roundi(half_width * lerpf(CHASM_SHELF_REACH.x, CHASM_SHELF_REACH.y, BackdropPaint.random01(shelf, 6, seed_value)))
		var shelf_x: int = roundi(center_x - face) - 2 if from_left else roundi(center_x + face) - reach + 2
		for wrap_shift: float in wraps:
			wall.add_rect(Rect2i(shelf_x + roundi(wrap_shift), row, reach, CHASM_SHELF_ROWS))
			# Thicker where it leaves the cliff: a wedge, not a plank.
			var root_x: int = shelf_x if from_left else shelf_x + reach - reach / 2
			wall.add_rect(Rect2i(root_x + roundi(wrap_shift), row + CHASM_SHELF_ROWS, reach / 2, CHASM_SHELF_ROWS))
		for drip: int in 1 + floori(BackdropPaint.random01(shelf, 10, seed_value) * 3.0):
			var x: float = shelf_x + reach * (0.2 + 0.6 * BackdropPaint.random01(drip, 11 + shelf, seed_value))
			var length: float = lerpf(CHASM_TIP_LENGTH.x, CHASM_TIP_LENGTH.y, BackdropPaint.random01(drip, 12 + shelf, seed_value))
			_add_spike(wall, x, _find_edge(wall, x, row + 1, 1), length, 1, wraps)
		if BackdropPaint.random01(shelf, 13, seed_value) < CHASM_STALAGMITE_SHARE:
			var x: float = shelf_x + reach * (0.3 + 0.4 * BackdropPaint.random01(shelf, 14, seed_value))
			_add_spike(wall, x, row, CHASM_TIP_LENGTH.x * 0.8, -1, wraps)


## A chasm's cliff face on one side at tall row `row`: its distance from the
## middle. A gentle noise (barely wiggling) plus sudden STEPS every so often,
## where the cliff juts out or falls back: sheer faces, not wobbly ones.
static func _chasm_face(half_width: float, row: int, seed_value: int) -> float:
	var step_index: int = floori(row / CHASM_STEP_EVERY)
	var step: float = (BackdropPaint.random01(step_index, 20, seed_value) - 0.5) * CHASM_STEP_DEPTH
	return half_width * (CHASM_FACE_RANGE.x + CHASM_FACE_RANGE.y
		* BackdropPaint.periodic_noise(row, CHASM_FACE_NOISE_ROWS, seed_value) + step)


## The first solid row from `from_row` going `direction` (-1 up, 1 down) at x:
## where a spike can hang from or stand on.
static func _find_edge(wall: BackdropTerrain.Mask, x: float, from_row: int, direction: int) -> int:
	var column: int = posmod(roundi(x), BackdropPaint.STRIP_WIDTH)
	var row: int = from_row
	while row > wall.origin.y and row < wall.origin.y + wall.size.y - 1 and not wall.is_solid(column, row):
		row -= direction
	return row


## A tapering spike `length` long from tall row `base_row` at x: hanging down
## (`direction` 1, a stalactite) or standing up (-1, a stalagmite).
static func _add_spike(wall: BackdropTerrain.Mask, x: float, base_row: int, length: float, direction: int,
		wraps: Array[float]) -> void:
	for step: int in roundi(length):
		var half_width: float = (2.0 + length * 0.16) * (1.0 - float(step) / length)
		if half_width < 0.5:
			break
		for wrap_shift: float in wraps:
			wall.add_rect(Rect2i(roundi(x + wrap_shift - half_width), base_row + direction * step, maxi(1, roundi(half_width * 2.0)), 1))


## The front (see the header): stalactite clusters hanging into the upper cave
## from above, a great dark pillar along the left edge (rising to a point in the
## upper cave's bottom corner, a wide column all the way down the deep), and
## stalagmites rising at the deep's foot.
static func paint_front(tall: Image) -> void:
	var surface: int = BackdropTheme.SURFACE_SECTION
	var deep: int = BackdropTheme.UNDERGROUND_SECTION
	# Stalactite clusters: a lip of rock from above the screen with spikes under it.
	var clusters: Array[Vector3i] = [Vector3i(0, 70, 54), Vector3i(250, 60, 34), Vector3i(420, 90, 46)]  # (left, width, longest)
	for cluster_index: int in clusters.size():
		var cluster: Vector3i = clusters[cluster_index]
		var seed_value: int = 6301 + cluster_index
		var lip_row: int = BackdropPaint.tall_row(4, surface)
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(cluster.x - 6, 0, cluster.y + 12, lip_row + cluster.z + 4))
		var bottoms: PackedFloat32Array = BackdropPaint.hanging(lip_row, [Vector2(40.0, 6.0), Vector2(11.0, 2.0)] as Array[Vector2],
			seed_value, false)
		for x: int in range(cluster.x, cluster.x + cluster.y):
			var edge_share: float = 1.0 - absf(float(x - cluster.x) / cluster.y * 2.0 - 1.0)  # thicker in the middle
			mask.add_rect(Rect2i(x, 0, 1, roundi(bottoms[posmod(x, BackdropPaint.STRIP_WIDTH)] - 6.0 + edge_share * 8.0)))
		for spike: int in 4:
			var spike_x: float = cluster.x + (spike + 0.5) * cluster.y / 4.0
			var length: float = cluster.z * (0.4 + 0.6 * BackdropPaint.random01(spike, 1, seed_value))
			var base: float = lip_row + 2.0
			for step: int in roundi(length):
				var half_width: float = (3.5 + length * 0.12) * (1.0 - float(step) / length)
				if half_width < 0.5:
					break
				mask.add_rect(Rect2i(roundi(spike_x - half_width), roundi(base) + step, maxi(1, roundi(half_width * 2.0)), 1))
		BackdropTerrain.roughen(mask, seed_value)
		BackdropTerrain.paint(tall, mask, FRONT_ROCK, 3.0, 8.0, 1, seed_value)
	# The great pillar along the left edge: a point in the upper cave's bottom
	# corner, widening as it goes down, a column all the way down the deep (one
	# tall layer: no seam between the two views).
	var pillar_top: int = BackdropPaint.tall_row(104, surface)
	var pillar_bottom: int = tall.get_height()
	const WIDEST_AFTER: float = 70.0  # rows below its tip where it reaches its full width
	var pillar: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(-30, pillar_top - 4, 110, pillar_bottom - pillar_top + 4))
	var row: int = pillar_top
	while row < pillar_bottom:
		var grown: float = minf(1.0, (row - pillar_top) / WIDEST_AFTER)
		var half_width: float = 3.0 + 24.0 * sqrt(grown) + 5.0 * BackdropPaint.periodic_noise(row, 24.0, 6311)
		var middle: float = 26.0 + 5.0 * BackdropPaint.periodic_noise(row, 40.0, 6312)
		var slab_rows: int = 2 if grown < 1.0 else SLAB_ROWS  # thin slabs while it widens: a smooth point, not steps
		pillar.add_rect(Rect2i(roundi(middle - half_width), row, roundi(half_width * 2.0), slab_rows))
		row += slab_rows
	BackdropTerrain.roughen(pillar, 6313)
	BackdropTerrain.paint(tall, pillar, FRONT_ROCK, 3.5, 10.0, 2, 6313)
	# Stalagmites at the deep's foot.
	var foot_row: int = BackdropPaint.tall_row(BackdropPaint.SCREEN_HEIGHT + 24, deep)
	var mounds: Array[Vector3] = [Vector3(300.0, 26.0, 84.0), Vector3(340.0, 14.0, 46.0), Vector3(560.0, 22.0, 66.0)]  # (x, half width, height)
	var ground: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(260, foot_row - 100, 360, tall.get_height() - foot_row + 100))
	for mound: Vector3 in mounds:
		for step: int in roundi(mound.z):
			var half_width: float = mound.y * pow(1.0 - float(step) / mound.z, 1.3)
			if half_width < 0.5:
				break
			ground.add_rect(Rect2i(roundi(mound.x - half_width), foot_row - step, maxi(1, roundi(half_width * 2.0)), 1))
	BackdropTerrain.roughen(ground, 6321)
	BackdropTerrain.paint(tall, ground, FRONT_ROCK, 3.0, 10.0, 1, 6321)


## Adds the layers the upper cave and the deep share, far to near, to `theme`
## showing `section`. `after_far` and `after_middle` (func() -> void) add the
## altitude's own layers there: after wall 0, and between wall 2 and wall 3.
static func add_shared_layers(theme: BackdropTheme, section: int, after_far: Callable, after_middle: Callable) -> void:
	theme.add_tall_layer(NAME, "Air", Vector2(0.01, 0.0), paint_air, section)
	theme.add_tall_layer(NAME, "Frame0", FRAME_SCROLLS[0], paint_frame.bind(0), section)
	after_far.call()
	theme.add_tall_layer(NAME, "Frame1", FRAME_SCROLLS[1], paint_frame.bind(1), section)
	theme.add_tall_layer(NAME, "Frame2", FRAME_SCROLLS[2], paint_frame.bind(2), section)
	after_middle.call()
	theme.add_tall_layer(NAME, "Frame3", FRAME_SCROLLS[3], paint_frame.bind(3), section)
	theme.add_tall_layer(NAME, "Front", FRONT_SCROLL, paint_front, section)

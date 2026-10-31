class_name JungleStyle
extends RefCounted
## JungleStyle: what the three JUNGLE looks (themes/jungle/*.gd) share, so they
## read as one rainforest seen from three heights. Not a node: static painters
## and colors.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer):
##   Sky     a pale morning sky high up (the skyline, among the karst pillars)
##           that turns into the green canopy light of the forest floor below
##   Canopy  the rainforest roof between the two: the skyline looks down on its
##           crowns, wrapped in mist; the surface looks up at its dark underside,
##           lianas hanging from it, the giant trunks going up into it
## Each look adds nearer layers and a FOREGROUND of BIG leaves (the look the
## jungle is known for: BackdropPaint.paint_leaf_clump) right in front.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "jungle"

## Skyline: morning sky, lightest low down where the mist is.
const SKY_BANDS: Array[Color] = [Color(0.42, 0.55, 0.68), Color(0.5, 0.61, 0.7), Color(0.6, 0.68, 0.72),
	Color(0.7, 0.75, 0.72), Color(0.8, 0.82, 0.72)]
## Surface: the green light under the canopy, lighter at the top.
const AIR_BANDS: Array[Color] = [Color(0.6, 0.72, 0.52), Color(0.5, 0.65, 0.5), Color(0.41, 0.57, 0.46),
	Color(0.33, 0.49, 0.42), Color(0.26, 0.41, 0.37)]
const SUN_COLOR: Color = Color(0.98, 0.94, 0.78)
const SUN_RING: Color = Color(0.92, 0.88, 0.74)

const MIST_BODY: Color = Color(0.8, 0.83, 0.79)
const MIST_LIT: Color = Color(0.9, 0.91, 0.85)
const CANOPY_BODY: Color = Color(0.13, 0.27, 0.18)
const CANOPY_LIT: Color = Color(0.22, 0.38, 0.23)
const CANOPY_RIM: Color = Color(0.34, 0.5, 0.3)
const CANOPY_UNDER: Color = Color(0.09, 0.2, 0.15)
const VINE_COLOR: Color = Color(0.17, 0.3, 0.17)

## The forest floor: the surface's ground, and the earth the cenote breaks
## through (BackdropTheme.crust_colors).
const GROUND_BODY: Color = Color(0.13, 0.24, 0.2)
const GROUND_RIM: Color = Color(0.21, 0.34, 0.25)
const FRONT_BODY: Color = Color(0.04, 0.1, 0.07)
const FRONT_LIT: Color = Color(0.09, 0.19, 0.1)
const FRONT_RIB: Color = Color(0.13, 0.25, 0.12)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## Where the sky gives way to the canopy light (skyline screen row): hidden
## inside the canopy band, so neither look shows the change.
const SKY_ENDS_SCREEN_ROW: int = 175


static func paint_sky(tall: Image) -> void:
	var sky_end: int = BackdropPaint.tall_row(SKY_ENDS_SCREEN_ROW, BackdropTheme.SKYLINE_SECTION)
	BackdropPaint.paint_bands(tall, AIR_BANDS, sky_end, BackdropPaint.tall_row(170, BackdropTheme.SURFACE_SECTION))
	var sky: Image = BackdropPaint.new_tall()
	BackdropPaint.paint_bands(sky, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION), sky_end)
	tall.blit_rect(sky, Rect2i(0, 0, BackdropPaint.STRIP_WIDTH, sky_end), Vector2i.ZERO)
	BackdropPaint.put_circle(tall, Vector2(420.0, BackdropPaint.tall_row(70, BackdropTheme.SKYLINE_SECTION)), 20.0, SUN_RING)
	BackdropPaint.put_circle(tall, Vector2(420.0, BackdropPaint.tall_row(70, BackdropTheme.SKYLINE_SECTION)), 14.0, SUN_COLOR)


## The canopy band (see the header): mist on its crowns in the skyline, its
## underside and hanging lianas in the surface.
static func paint_canopy(tall: Image) -> void:
	var seam: float = BackdropPaint.tall_row(0, BackdropTheme.SURFACE_SECTION)
	var tops: PackedFloat32Array = BackdropPaint.bumps(seam - 28.0, Vector2(9.0, 18.0), 18, 1231)
	var under_base: float = seam + 14.0
	var undersides: PackedFloat32Array = BackdropPaint.bumps(under_base, Vector2(10.0, 20.0), 16, 1232)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		var bottom: int = roundi(2.0 * under_base - undersides[x])
		for y: int in range(top, bottom + 1):
			var color: Color = CANOPY_BODY
			if y < top + 2:
				color = CANOPY_RIM if y == top else CANOPY_LIT
			elif y > bottom - 2:
				color = CANOPY_LIT
			elif y > bottom - 12 and (y > bottom - 5 or BackdropPaint.checker(x, y)):
				color = CANOPY_UNDER
			BackdropPaint.put_pixel(tall, x, y, color)
	# Mist lying in the crowns' hollows (the skyline sees it): wisps a few rows
	# deep where the crowns dip lowest, thinning out in a dither.
	var mist: PackedFloat32Array = BackdropPaint.bumps(seam - 16.0, Vector2(4.0, 8.0), 21, 1233)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var mist_top: int = ceili(mist[x])
		if mist_top < ceili(tops[x]) + 3:
			continue  # a crown pokes up through here
		for depth: int in 5:
			if depth < 2 or (depth < 4 and BackdropPaint.checker(x, mist_top + depth)) or (x + depth) % 4 == 0:
				BackdropPaint.put_pixel(tall, x, mist_top + depth, MIST_LIT if depth == 0 else MIST_BODY)
	# Lianas hanging from the underside, some long, swinging in loops between.
	for vine_index: int in 14:
		var x: float = (vine_index + BackdropPaint.random01(vine_index, 1, 1234)) * BackdropPaint.STRIP_WIDTH / 14.0
		var top_row: float = 2.0 * under_base - undersides[posmod(roundi(x), BackdropPaint.STRIP_WIDTH)]
		var length: float = 14.0 + BackdropPaint.random01(vine_index, 2, 1234) * 60.0
		for y: int in range(roundi(top_row), roundi(top_row + length)):
			BackdropPaint.put_pixel(tall, roundi(x) + (1 if (y / 9) % 2 == 0 else 0), y, VINE_COLOR)
		if vine_index % 3 == 0:
			var other: float = x + 40.0
			var control: Vector2 = Vector2((x + other) / 2.0, top_row + length * 0.8)
			for step: int in 60:
				var point: Vector2 = BackdropPaint.curve_point(Vector2(x, top_row), control, Vector2(other, top_row), step / 59.0)
				BackdropPaint.put_pixel(tall, roundi(point.x), roundi(point.y), VINE_COLOR)


## Big leaves for a look's front: a clump at each of `bases` (Vector3: x, row,
## angle) with sizes in `length_range`.
static func paint_big_leaves(image: Image, bases: Array[Vector3], length_range: Vector2, seed_value: int) -> void:
	for clump_index: int in bases.size():
		var base: Vector3 = bases[clump_index]
		BackdropPaint.paint_leaf_clump(image, Vector2(base.x, base.y), 4 + clump_index % 2, base.z, 1.4, length_range, 0.8,
			FRONT_BODY, FRONT_LIT, FRONT_RIB, seed_value + clump_index)

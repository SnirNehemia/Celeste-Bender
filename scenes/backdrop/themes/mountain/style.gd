class_name MountainStyle
extends RefCounted
## MountainStyle: what the three MOUNTAIN looks (themes/mountain/*.gd) share, so
## they read as one mountain seen from three heights. Not a node: static painters
## and colors.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer): painted once
## for skyline and surface together, each showing its slice:
##   Sky        one dusk gradient: deep blue high up, violet, a pink glow at the
##              surface's horizon; stars above, the moon in the surface's sky
##   Peaks      the great range: from the surface you see their snowy flanks rise
##              out of view; from the skyline their summits stand above the clouds
##   CloudBank  the clouds between the two: the skyline looks down on their tops,
##              the surface up at their undersides
## Each look adds its own nearer layers, and a FOREGROUND of big dark shapes close
## to the camera (pine boughs, crags, icicles) painted with the helpers below.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The name tall pictures are cached under (BackdropTheme.add_tall_layer).
const NAME: String = "mountain"

## Top of the skyline down to the surface's horizon (BackdropPaint.paint_bands).
const SKY_BANDS: Array[Color] = [Color(0.05, 0.06, 0.16), Color(0.07, 0.08, 0.2), Color(0.09, 0.1, 0.24),
	Color(0.12, 0.13, 0.28), Color(0.15, 0.15, 0.31), Color(0.19, 0.17, 0.35), Color(0.24, 0.2, 0.38),
	Color(0.3, 0.23, 0.41), Color(0.37, 0.27, 0.44), Color(0.45, 0.31, 0.47)]
const STAR_COLOR: Color = Color(0.75, 0.78, 0.95)
const MOON_COLOR: Color = Color(0.86, 0.86, 0.95)
const MOON_SHADE: Color = Color(0.7, 0.7, 0.85)

## The great range's two highest summits: strip x and screen row in the skyline.
const GREAT_SUMMITS: Array[Vector2] = [Vector2(190.0, 88.0), Vector2(500.0, 112.0)]
const PEAK_BODY: Color = Color(0.21, 0.19, 0.35)
const PEAK_LIT: Color = Color(0.3, 0.27, 0.45)
const PEAK_RIM: Color = Color(0.46, 0.42, 0.62)
const PEAK_SNOW: Color = Color(0.68, 0.68, 0.84)
const PEAK_SNOW_SHADOW: Color = Color(0.46, 0.44, 0.64)

const CLOUD_BODY: Color = Color(0.36, 0.31, 0.5)
const CLOUD_LIT: Color = Color(0.52, 0.47, 0.66)
const CLOUD_SHADE: Color = Color(0.29, 0.25, 0.43)

## The near pines and the ground: the surface's front, and the rock the
## underground breaks through (BackdropTheme.crust_colors).
const GROUND_BODY: Color = Color(0.07, 0.08, 0.15)
const GROUND_RIM: Color = Color(0.13, 0.14, 0.24)
## Foreground: darker than anything behind, so the play layer reads first.
const FRONT_BODY: Color = Color(0.035, 0.04, 0.09)
const FRONT_LIT: Color = Color(0.09, 0.1, 0.18)
const FRONT_SNOW: Color = Color(0.3, 0.31, 0.45)

## Every look's foreground layer moves with this share of the camera (nearer than
## all the rest, still far slower than the rooms).
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)


## The dusk sky over all three screens, stars, and the moon.
static func paint_sky(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(120, BackdropTheme.SURFACE_SECTION))
	# Stars: many high up, thinning out toward the horizon.
	var star_top: int = BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION)
	var star_span: float = BackdropPaint.tall_row(90, BackdropTheme.SURFACE_SECTION) - star_top
	for star_index: int in 260:
		var x: int = roundi(BackdropPaint.random01(star_index, 1, 101) * BackdropPaint.STRIP_WIDTH)
		var depth: float = BackdropPaint.random01(star_index, 2, 101)
		var y: int = star_top + roundi(depth * depth * star_span)
		var brightness: float = BackdropPaint.random01(star_index, 3, 101)
		BackdropPaint.blend_pixel(tall, x, y, Color(STAR_COLOR, 0.35 + brightness * 0.5))
		if brightness > 0.94:
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				BackdropPaint.blend_pixel(tall, x + offset.x, y + offset.y, Color(STAR_COLOR, 0.35))
	# The moon, in the surface's sky (one per strip: two would show on a wide screen).
	var moon_center: Vector2 = Vector2(250.0, BackdropPaint.tall_row(40, BackdropTheme.SURFACE_SECTION))
	BackdropPaint.put_circle(tall, moon_center, 11.0, MOON_COLOR)
	BackdropPaint.put_circle(tall, moon_center + Vector2(-3, -2), 3.0, MOON_SHADE)
	BackdropPaint.put_circle(tall, moon_center + Vector2(4, 3), 2.0, MOON_SHADE)
	BackdropPaint.put_circle(tall, moon_center + Vector2(2, -5), 1.0, MOON_SHADE)


## The great range: feet low in the surface's view, summits up in the skyline's.
static func paint_peaks(tall: Image) -> void:
	var octaves: Array[Vector2] = [Vector2(213.0, 190.0), Vector2(60.0, 40.0), Vector2(16.0, 6.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.tall_row(160, BackdropTheme.SURFACE_SECTION), octaves, 201, true)
	# Two giant summits that stand well above the cloud bank in the skyline's view.
	for summit: Vector2 in GREAT_SUMMITS:
		add_summit(tops, summit.x, BackdropPaint.tall_row(summit.y, BackdropTheme.SKYLINE_SECTION), 0.8, 202)
	BackdropPaint.paint_mountains(tall, tops, PEAK_BODY, PEAK_LIT, PEAK_RIM, PEAK_SNOW, PEAK_SNOW_SHADOW,
		BackdropPaint.tall_row(70, BackdropTheme.SURFACE_SECTION), 80.0, 201)


## Raises `tops` (a skyline) to a sharp peak at strip x `center` and row
## `top_row`, its flanks falling `slope` px per px sideways, a little rough.
static func add_summit(tops: PackedFloat32Array, center: float, top_row: float, slope: float, seed_value: int) -> void:
	for dx: int in range(-BackdropPaint.STRIP_WIDTH / 2, BackdropPaint.STRIP_WIDTH / 2):
		var rough: float = (BackdropPaint.periodic_noise(center + dx, 14.0, seed_value) - 0.5) * 8.0
		var column: int = posmod(roundi(center) + dx, BackdropPaint.STRIP_WIDTH)
		tops[column] = minf(tops[column], top_row + absf(dx) * slope + rough * minf(1.0, absf(dx) / 10.0))


## The bank of cloud between the skyline and the surface: a billowy top (what the
## skyline looks down on) and a hanging, shaded underside (what the surface looks
## up at), with a dithered middle.
static func paint_cloud_bank(tall: Image) -> void:
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.tall_row(150, BackdropTheme.SKYLINE_SECTION),
		Vector2(6.0, 14.0), 12, 622)
	var bottoms: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.tall_row(22, BackdropTheme.SURFACE_SECTION),
		Vector2(5.0, 11.0), 15, 623)
	for x: int in BackdropPaint.STRIP_WIDTH:
		# bumps() rises from its base: mirror it to hang down instead.
		var bottom: int = roundi(2.0 * BackdropPaint.tall_row(22, BackdropTheme.SURFACE_SECTION) - bottoms[x])
		var top: int = ceili(tops[x])
		for y: int in range(top, bottom + 1):
			var color: Color = CLOUD_BODY
			if y < top + 2:
				color = CLOUD_LIT
			elif y > bottom - 2:
				color = CLOUD_SHADE
			elif y > bottom - 10 and BackdropPaint.checker(x, y):
				color = CLOUD_SHADE
			BackdropPaint.put_pixel(tall, x, y, color)


## A big pine bough reaching in from the edge: a branch from `root` to `tip`
## sagging in the middle, thick at the root, with fans of needles all along it
## and snow lying on top.
static func paint_bough(image: Image, root: Vector2, tip: Vector2, sag: float, seed_value: int) -> void:
	var control: Vector2 = (root + tip) / 2.0 + Vector2(0.0, sag)
	var steps: int = ceili(root.distance_to(tip))
	for step: int in steps + 1:
		var along: float = float(step) / steps
		var point: Vector2 = BackdropPaint.curve_point(root, control, tip, along)
		var thickness: int = maxi(1, roundi(5.0 * (1.0 - along)))
		BackdropPaint.put_rect(image, Rect2i(roundi(point.x), roundi(point.y) - thickness / 2, 1, thickness), FRONT_BODY)
		# Needles: every 3 px a fan of short lines hanging down and out.
		if step % 3 == 0 and along > 0.08:
			var length: float = 7.0 + 5.0 * sin(along * PI) + BackdropPaint.random01(step, 1, seed_value) * 3.0
			for needle: int in 5:
				var angle: float = PI * 0.5 + (needle - 2) * 0.32 + (BackdropPaint.random01(step, needle, seed_value) - 0.5) * 0.2
				BackdropPaint.put_line(image, point, point + Vector2(cos(angle), sin(angle)) * length,
					FRONT_LIT if needle == 0 else FRONT_BODY)
			# Snow along the top of the branch.
			BackdropPaint.put_rect(image, Rect2i(roundi(point.x) - 1, roundi(point.y) - thickness / 2 - 1, 3, 1), FRONT_SNOW)


## A big crag rising from the bottom edge, in the mountain's front colors with
## snow on its ledges (BackdropPaint.paint_crag).
static func paint_crag(image: Image, foot_x: float, half_width: float, height: float, seed_value: int) -> void:
	BackdropPaint.paint_crag(image, foot_x, half_width, height, FRONT_BODY, FRONT_LIT, FRONT_SNOW, seed_value)

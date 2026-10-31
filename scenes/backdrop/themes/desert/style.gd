class_name DesertStyle
extends RefCounted
## DesertStyle: what the three DESERT looks (themes/desert/*.gd) share, so they
## read as one desert seen from three heights. Not a node: static painters and
## colors.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer):
##   Sky     one dusk: deep violet high up, rose, then orange at the surface's
##           horizon, where the big striped sun is setting; thin wisps up high
##   Spires  giant banded rock towers and a natural arch: their feet stand in the
##           surface's view, their tops rise into the skyline's
##   Clouds  warm clouds, most up in the skyline's sky, a few drifting low
##           across where the two meet
## Each look adds nearer layers, and a FOREGROUND of big dark shapes (saguaros,
## yucca, crags) right in front.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "desert"

const SKY_BANDS: Array[Color] = [Color(0.12, 0.12, 0.28), Color(0.16, 0.15, 0.32), Color(0.22, 0.18, 0.35),
	Color(0.3, 0.21, 0.36), Color(0.39, 0.25, 0.36), Color(0.48, 0.3, 0.35), Color(0.57, 0.36, 0.34),
	Color(0.66, 0.43, 0.34)]
const SUN_COLOR: Color = Color(0.92, 0.62, 0.38)
const WISP_COLOR: Color = Color(0.8, 0.6, 0.55, 0.3)

const SPIRE_BODY: Color = Color(0.25, 0.15, 0.2)
const SPIRE_LIT: Color = Color(0.36, 0.22, 0.25)
const SPIRE_RIM: Color = Color(0.48, 0.3, 0.3)
const SPIRE_STRATA: Color = Color(0.21, 0.13, 0.17)

const CLOUD_BODY: Color = Color(0.6, 0.45, 0.46)
const CLOUD_LIT: Color = Color(0.78, 0.6, 0.52)
const CLOUD_SHADE: Color = Color(0.5, 0.36, 0.4)

## The near buttes and rocky floor: the surface's front, and the rock the
## underground breaks through (BackdropTheme.crust_colors).
const GROUND_BODY: Color = Color(0.14, 0.08, 0.11)
const GROUND_RIM: Color = Color(0.32, 0.19, 0.18)
const FRONT_BODY: Color = Color(0.07, 0.04, 0.06)
const FRONT_LIT: Color = Color(0.14, 0.08, 0.1)
const FRONT_RIM: Color = Color(0.22, 0.13, 0.13)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## The towers: strip x, half width, top (screen row in the skyline).
const SPIRES: Array[Vector3] = [Vector3(80.0, 13.0, 74.0), Vector3(250.0, 9.0, 112.0), Vector3(560.0, 16.0, 60.0)]
## The arch: strip x of its middle, the hole's half width, its top (skyline row).
const ARCH: Vector3 = Vector3(400.0, 28.0, 120.0)


static func paint_sky(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(125, BackdropTheme.SURFACE_SECTION))
	# Long thin wisps of high cloud in the skyline's sky, a dashed line or two each.
	for wisp_index: int in 9:
		var start: Vector2 = Vector2(BackdropPaint.random01(wisp_index, 1, 912) * BackdropPaint.STRIP_WIDTH,
			BackdropPaint.tall_row(16 + BackdropPaint.random01(wisp_index, 2, 912) * 110.0, BackdropTheme.SKYLINE_SECTION))
		var length: int = 40 + roundi(BackdropPaint.random01(wisp_index, 3, 912) * 80.0)
		for offset: int in length:
			if (offset / 9 + wisp_index) % 4 != 0:
				BackdropPaint.blend_pixel(tall, roundi(start.x) + offset, roundi(start.y) + offset / 40, WISP_COLOR)
	# The big setting sun in the surface's sky, with bars of sky cut through its
	# lower half (thicker further down): the classic striped sunset.
	var sun_center: Vector2 = Vector2(150.0, BackdropPaint.tall_row(102, BackdropTheme.SURFACE_SECTION))
	var radius: float = 30.0
	for dy: int in range(-ceili(radius), 1):
		var y: int = roundi(sun_center.y) + dy
		var gap_height: int = 0 if dy < -14 else (1 if dy < -6 else 2)
		if gap_height > 0 and posmod(dy, 5) < gap_height:
			continue
		var half_width: float = sqrt(maxf(0.0, radius * radius - dy * dy))
		BackdropPaint.put_rect(tall, Rect2i(roundi(sun_center.x - half_width), y, roundi(half_width * 2.0), 1), SUN_COLOR)


## The towers and the arch, from the surface's horizon up into the skyline.
static func paint_spires(tall: Image) -> void:
	var foot: float = BackdropPaint.tall_row(150, BackdropTheme.SURFACE_SECTION)
	var tops: PackedFloat32Array = BackdropPaint.flat_line(tall.get_height() + 4.0)
	for spire: Vector3 in SPIRES:
		var top: float = BackdropPaint.tall_row(spire.z, BackdropTheme.SKYLINE_SECTION)
		for dx: int in range(-ceili(spire.y * 3.0), ceili(spire.y * 3.0) + 1):
			# Straight sides that flare out into a talus skirt near the foot.
			var distance: float = absf(dx) - spire.y
			var row_here: float = top
			if distance > 0.0:
				row_here = foot - (foot - top) * maxf(0.0, 1.0 - distance / (spire.y * 2.0)) * 0.12
			var column: int = posmod(roundi(spire.x) + dx, BackdropPaint.STRIP_WIDTH)
			tops[column] = minf(tops[column], row_here + (BackdropPaint.periodic_noise(spire.x + dx, 6.0, 941) - 0.5) * 3.0)
	# The arch: two legs and a span across the top, with a round-topped hole.
	var arch_top: float = BackdropPaint.tall_row(ARCH.z, BackdropTheme.SKYLINE_SECTION)
	for dx: int in range(-ceili(ARCH.y + 14.0), ceili(ARCH.y + 14.0) + 1):
		var column: int = posmod(roundi(ARCH.x) + dx, BackdropPaint.STRIP_WIDTH)
		tops[column] = minf(tops[column], arch_top + absf(dx) * 0.08)
	BackdropPaint.paint_mountains(tall, tops, SPIRE_BODY, SPIRE_LIT, SPIRE_RIM, SPIRE_RIM, SPIRE_RIM, 0, 200.0, 942)
	for dx: int in range(-ceili(ARCH.y), ceili(ARCH.y) + 1):
		var hole_top: int = roundi(arch_top + 16.0 + (ARCH.y - sqrt(maxf(0.0, ARCH.y * ARCH.y - dx * dx))) * 0.8)
		var x: int = roundi(ARCH.x) + dx
		BackdropPaint.put_rect(tall, Rect2i(x, hole_top, 1, roundi(foot) - hole_top), Color(0.0, 0.0, 0.0, 0.0))
		BackdropPaint.put_pixel(tall, x, hole_top - 1, SPIRE_LIT)
	BackdropPaint.paint_strata(tall, BackdropPaint.flat_line(-10.0), SPIRE_STRATA, 943)
	# Nothing below the horizon: the surface's mesas and dunes stand in front there.
	tall.fill_rect(Rect2i(0, roundi(foot) + 6, BackdropPaint.STRIP_WIDTH, tall.get_height() - roundi(foot) - 6), Color(0.0, 0.0, 0.0, 0.0))


static func paint_clouds(tall: Image) -> void:
	for cloud_index: int in 9:
		var center: Vector2 = Vector2((cloud_index + BackdropPaint.random01(cloud_index, 1, 931) * 0.5) * BackdropPaint.STRIP_WIDTH / 9.0,
			BackdropPaint.tall_row(50 + BackdropPaint.random01(cloud_index, 2, 931) * 160.0, BackdropTheme.SKYLINE_SECTION))
		BackdropPaint.paint_cloud(tall, center, 14.0 + BackdropPaint.random01(cloud_index, 3, 931) * 20.0,
			CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 932)


## A big saguaro right in front: a round-topped trunk `half_width` px each side of
## `center_x`, `height` px tall from `foot_row`, two arms bending up, ribs.
static func paint_big_cactus(image: Image, center_x: float, foot_row: float, height: float, half_width: float, seed_value: int) -> void:
	_paint_cactus_column(image, center_x, foot_row, height, half_width)
	for side: float in [-1.0, 1.0]:
		var arm_row: float = foot_row - height * (0.4 + BackdropPaint.random01(seed_value, int(side) + 5, 96) * 0.2)
		var reach: float = half_width * 2.2
		var arm_x: float = center_x + side * reach
		var arm_height: float = height * (0.3 + BackdropPaint.random01(seed_value, int(side) + 8, 96) * 0.15)
		# Out sideways (a thick bar), then up (a smaller column).
		BackdropPaint.put_rect(image, Rect2i(roundi(minf(center_x, arm_x)), roundi(arm_row - half_width * 0.6),
			roundi(reach) + 1, roundi(half_width * 1.2)), FRONT_BODY)
		_paint_cactus_column(image, arm_x, arm_row + half_width * 0.6, arm_height, half_width * 0.7)


static func _paint_cactus_column(image: Image, center_x: float, foot_row: float, height: float, half_width: float) -> void:
	for dy: int in roundi(height):
		var y: int = roundi(foot_row) - dy
		# Round top: narrower over the last half-width.
		var from_top: float = height - dy
		var width_here: float = half_width if from_top > half_width else sqrt(maxf(0.0, half_width * half_width - (half_width - from_top) * (half_width - from_top)))
		var left: int = roundi(center_x - width_here)
		var right: int = roundi(center_x + width_here)
		BackdropPaint.put_rect(image, Rect2i(left, y, right - left + 1, 1), FRONT_BODY)
		BackdropPaint.put_pixel(image, left, y, FRONT_RIM)
		# Ribs: dark vertical lines down the trunk.
		for rib: int in range(left + 3, right - 1, 3):
			BackdropPaint.put_pixel(image, rib, y, FRONT_LIT if (rib - left) % 6 == 0 else FRONT_BODY)


## A yucca or agave: a burst of long narrow spiky leaves from `base`.
static func paint_spiky_plant(image: Image, base: Vector2, count: int, length: float, seed_value: int) -> void:
	for leaf_index: int in count:
		var along: float = float(leaf_index) / maxf(1.0, count - 1.0) - 0.5
		var leaf_length: float = length * (0.6 + BackdropPaint.random01(leaf_index, 1, seed_value) * 0.4) * (1.0 - absf(along) * 0.6)
		BackdropPaint.paint_leaf(image, base, -PI * 0.5 + along * 2.6, leaf_length, 2.5, along * 0.4, FRONT_BODY, FRONT_RIM, FRONT_BODY)

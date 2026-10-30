extends BackdropTheme
## DESERT backdrop (the Earth chapter's look): a dusk sky over a setting sun cut
## by bars of haze, far flat-topped mesas with layered rock, rolling dunes with a
## lit crest, and near buttes in dark banded stone with saguaro cacti; sand
## blows past. Layers far to near; see BackdropTheme.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const SKY_BANDS: Array[Color] = [Color(0.12, 0.11, 0.24), Color(0.18, 0.14, 0.3), Color(0.27, 0.18, 0.33),
	Color(0.38, 0.23, 0.33), Color(0.5, 0.3, 0.32), Color(0.6, 0.38, 0.33)]
const SUN_COLOR: Color = Color(0.9, 0.6, 0.38)

const MESA_BODY: Color = Color(0.36, 0.22, 0.3)
const MESA_LIT: Color = Color(0.46, 0.29, 0.34)
const MESA_STRATA: Color = Color(0.31, 0.19, 0.27)
const MESA_RIM: Color = Color(0.55, 0.36, 0.38)

const DUNE_BODY: Color = Color(0.27, 0.16, 0.22)
const DUNE_LIT: Color = Color(0.4, 0.25, 0.27)
const DUNE_RIM: Color = Color(0.5, 0.33, 0.3)

const NEAR_BODY: Color = Color(0.14, 0.08, 0.11)
const NEAR_STRATA: Color = Color(0.19, 0.11, 0.13)
const NEAR_LIT: Color = Color(0.24, 0.14, 0.15)
const NEAR_RIM: Color = Color(0.32, 0.19, 0.18)


func _build_layers() -> void:
	add_painted_layer("Sky", Vector2(0.01, 0.0), _paint_sky)
	add_painted_layer("Mesas", Vector2(0.06, 0.03), _paint_mesas)
	add_painted_layer("Dunes", Vector2(0.18, 0.07), _paint_dunes)
	add_painted_layer("Buttes", Vector2(0.38, 0.12), _paint_buttes)

	var sand: BackdropMotes = BackdropMotes.new()
	sand.shape = BackdropMotes.Shape.STREAK
	sand.mote_count = 22
	sand.colors = [Color(0.85, 0.62, 0.45, 0.2), Color(0.85, 0.62, 0.45, 0.32)]
	sand.velocity = Vector2(55.0, 2.0)
	sand.sway_amplitude = 3.0
	sand.sway_speed = 0.6
	sand.size_range = Vector2i(1, 3)
	sand.scroll_factor = 0.6
	sand.seed_value = 41
	add_motes(sand)

	var grains: BackdropMotes = BackdropMotes.new()
	grains.mote_count = 20
	grains.colors = [Color(0.9, 0.7, 0.5, 0.35)]
	grains.velocity = Vector2(35.0, 3.0)
	grains.sway_amplitude = 4.0
	grains.sway_speed = 0.8
	grains.scroll_factor = 0.7
	grains.seed_value = 42
	add_motes(grains)


func _paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(125))
	# A big setting sun, with horizontal bars of sky cut through its lower half
	# (thicker further down): the classic striped sunset.
	var sun_center: Vector2 = Vector2(150.0, BackdropPaint.row(102))
	var radius: float = 30.0
	for dy: int in range(-ceili(radius), 1):
		var y: int = roundi(sun_center.y) + dy
		var gap_height: int = 0 if dy < -14 else (1 if dy < -6 else 2)
		if gap_height > 0 and posmod(dy, 5) < gap_height:
			continue
		var half_width: float = sqrt(maxf(0.0, radius * radius - dy * dy))
		BackdropPaint.put_rect(image, Rect2i(roundi(sun_center.x - half_width), y, roundi(half_width * 2.0), 1), SUN_COLOR)
	return image


func _paint_mesas() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var base_row: float = BackdropPaint.row(132)
	var tops: PackedFloat32Array = BackdropPaint.mesas(base_row, 5, Vector2(14.0, 40.0), Vector2(24.0, 52.0), 71)
	# Low rolling ground between them.
	var ground: PackedFloat32Array = BackdropPaint.ridge(base_row + 4.0, [Vector2(90.0, 10.0)] as Array[Vector2], 72, false)
	for x: int in BackdropPaint.STRIP_WIDTH:
		tops[x] = minf(tops[x], ground[x])
	BackdropPaint.paint_mountains(image, tops, MESA_BODY, MESA_LIT, MESA_RIM, MESA_RIM, MESA_RIM, 0, 60.0, 73)
	BackdropPaint.paint_strata(image, tops, MESA_STRATA, 73)
	return image


func _paint_dunes() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# Dunes: long smooth swells, then folded (peaky) for the sharp crest.
	var octaves: Array[Vector2] = [Vector2(210.0, 26.0), Vector2(70.0, 10.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(170), octaves, 81, true)
	BackdropPaint.paint_mountains(image, tops, DUNE_BODY, DUNE_LIT, DUNE_RIM, DUNE_RIM, DUNE_RIM, 0, 26.0, 81)
	# Ripples: short dithered dashes across the dune faces.
	for x: int in BackdropPaint.STRIP_WIDTH:
		for y: int in range(ceili(tops[x]) + 6, BackdropPaint.STRIP_HEIGHT, 6):
			if (x + y * 3) % 11 < 4:
				BackdropPaint.put_pixel(image, x, y, DUNE_BODY.darkened(0.12))
	return image


## Near rocks: a few narrow buttes in dark banded stone on a rocky floor, with
## saguaro cacti standing between them.
func _paint_buttes() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.mesas(BackdropPaint.row(184), 3, Vector2(8.0, 20.0), Vector2(36.0, 80.0), 91)
	var floor_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(180), [Vector2(60.0, 8.0), Vector2(15.0, 3.0)] as Array[Vector2], 92, false)
	for x: int in BackdropPaint.STRIP_WIDTH:
		tops[x] = minf(tops[x], floor_tops[x])
	BackdropPaint.paint_mountains(image, tops, NEAR_BODY, NEAR_LIT, NEAR_RIM, NEAR_RIM, NEAR_RIM, 0, 90.0, 93)
	BackdropPaint.paint_strata(image, tops, NEAR_STRATA, 94)
	for cactus_index: int in 5:
		var cactus_x: int = roundi((cactus_index + 0.5) * BackdropPaint.STRIP_WIDTH / 5.0 + (BackdropPaint.random01(cactus_index, 1, 95) - 0.5) * 50.0)
		var foot_row: int = ceili(tops[posmod(cactus_x, BackdropPaint.STRIP_WIDTH)]) + 2
		var height: int = 18 + roundi(BackdropPaint.random01(cactus_index, 2, 95) * 16.0)
		_paint_cactus(image, cactus_x, foot_row, height, cactus_index)
	return image


## A saguaro: a round-topped trunk with one or two arms that bend up.
func _paint_cactus(image: Image, center_x: int, foot_row: int, height: int, seed_value: int) -> void:
	const TRUNK_WIDTH: int = 5
	var left: int = center_x - TRUNK_WIDTH / 2
	BackdropPaint.put_rect(image, Rect2i(left, foot_row - height + 1, TRUNK_WIDTH, height), NEAR_BODY)
	BackdropPaint.put_rect(image, Rect2i(left + 1, foot_row - height, TRUNK_WIDTH - 2, 1), NEAR_BODY)
	BackdropPaint.put_rect(image, Rect2i(left, foot_row - height + 1, 1, height), NEAR_LIT)
	BackdropPaint.put_rect(image, Rect2i(left + 1, foot_row - height, TRUNK_WIDTH - 2, 1), NEAR_RIM)
	for side: int in [-1, 1]:
		if side == 1 and BackdropPaint.random01(seed_value, 3, 96) < 0.4:
			continue  # some have only one arm
		var arm_row: int = foot_row - roundi(height * (0.35 + BackdropPaint.random01(seed_value, side + 5, 96) * 0.2))
		var reach: int = 4
		var arm_height: int = 6 + roundi(BackdropPaint.random01(seed_value, side + 8, 96) * 6.0)
		var elbow_x: int = (left - reach) if side < 0 else (left + TRUNK_WIDTH)
		# Out sideways, then up.
		BackdropPaint.put_rect(image, Rect2i(elbow_x, arm_row, reach, 3), NEAR_BODY)
		var arm_x: int = elbow_x if side < 0 else elbow_x + reach - 3
		BackdropPaint.put_rect(image, Rect2i(arm_x, arm_row - arm_height, 3, arm_height + 3), NEAR_BODY)
		BackdropPaint.put_rect(image, Rect2i(arm_x, arm_row - arm_height, 1, arm_height + 3), NEAR_LIT)
		BackdropPaint.put_pixel(image, arm_x + 1, arm_row - arm_height - 1, NEAR_RIM)

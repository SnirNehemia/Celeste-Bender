extends BackdropTheme
## DESERT, SKYLINE: high above the desert, on top of the tallest rock towers. A
## wide dusk sky with the sun still up and wisps of cloud, the desert far below
## with tiny mesas on the horizon, nearer puffy clouds drifting past, and near
## the tops of rock spires and a natural arch; warm wind. Layers far to near; see
## BackdropTheme. (Surface: surface.gd; beneath the sand: underground.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const SKY_BANDS: Array[Color] = [Color(0.15, 0.16, 0.34), Color(0.22, 0.22, 0.4), Color(0.32, 0.27, 0.42),
	Color(0.45, 0.33, 0.41), Color(0.58, 0.41, 0.4), Color(0.7, 0.5, 0.42)]
const SUN_COLOR: Color = Color(0.95, 0.72, 0.48)
const SUN_RING: Color = Color(0.82, 0.58, 0.44)
const WISP_COLOR: Color = Color(0.8, 0.6, 0.55, 0.3)

const FAR_BODY: Color = Color(0.48, 0.33, 0.37)
const FAR_LIT: Color = Color(0.56, 0.4, 0.4)

const CLOUD_BODY: Color = Color(0.6, 0.45, 0.46)
const CLOUD_LIT: Color = Color(0.78, 0.6, 0.52)
const CLOUD_SHADE: Color = Color(0.5, 0.36, 0.4)

const NEAR_BODY: Color = Color(0.16, 0.09, 0.11)
const NEAR_STRATA: Color = Color(0.21, 0.12, 0.13)
const NEAR_LIT: Color = Color(0.27, 0.16, 0.16)
const NEAR_RIM: Color = Color(0.36, 0.22, 0.2)


func _build_layers() -> void:
	add_painted_layer("Sky", Vector2(0.01, 0.0), _paint_sky)
	add_painted_layer("FarDesert", Vector2(0.03, 0.01), _paint_far_desert)
	add_painted_layer("Clouds", Vector2(0.14, 0.05), _paint_clouds, 4.0)
	add_painted_layer("Spires", Vector2(0.42, 0.13), _paint_spires)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 18
	wind.colors = [Color(1.0, 0.8, 0.6, 0.16), Color(1.0, 0.8, 0.6, 0.24)]
	wind.velocity = Vector2(80.0, 2.0)
	wind.sway_amplitude = 2.0
	wind.sway_speed = 0.5
	wind.size_range = Vector2i(2, 6)
	wind.scroll_factor = 0.55
	wind.seed_value = 911
	add_motes(wind)


func _paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(150))
	var sun_center: Vector2 = Vector2(470.0, BackdropPaint.row(60))
	BackdropPaint.put_circle(image, sun_center, 22.0, SUN_RING)
	BackdropPaint.put_circle(image, sun_center, 16.0, SUN_COLOR)
	# Long thin wisps of high cloud, a dashed line or two each.
	for wisp_index: int in 8:
		var start: Vector2 = Vector2(BackdropPaint.random01(wisp_index, 1, 912) * BackdropPaint.STRIP_WIDTH,
			BackdropPaint.row(20 + BackdropPaint.random01(wisp_index, 2, 912) * 90.0))
		var length: int = 40 + roundi(BackdropPaint.random01(wisp_index, 3, 912) * 80.0)
		for offset: int in length:
			if (offset / 9 + wisp_index) % 4 != 0:
				BackdropPaint.blend_pixel(image, roundi(start.x) + offset, roundi(start.y) + offset / 40, WISP_COLOR)
	return image


func _paint_far_desert() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.mesas(BackdropPaint.row(156), 9, Vector2(3.0, 9.0), Vector2(4.0, 12.0), 921)
	BackdropPaint.fill_below(image, tops, FAR_BODY)
	BackdropPaint.paint_rim(image, tops, FAR_LIT)
	return image


func _paint_clouds() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for cloud_index: int in 7:
		var center: Vector2 = Vector2((cloud_index + BackdropPaint.random01(cloud_index, 1, 931) * 0.5) * BackdropPaint.STRIP_WIDTH / 7.0,
			BackdropPaint.row(70 + BackdropPaint.random01(cloud_index, 2, 931) * 80.0))
		BackdropPaint.paint_cloud(image, center, 14.0 + BackdropPaint.random01(cloud_index, 3, 931) * 20.0, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 932)
	return image


## Spires rising from far below (their bases are off the bottom of the screen),
## and a natural arch: two spires joined by a band of rock with a hole under it.
func _paint_spires() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.mesas(BackdropPaint.row(240), 4, Vector2(6.0, 16.0), Vector2(70.0, 130.0), 941)
	BackdropPaint.paint_mountains(image, tops, NEAR_BODY, NEAR_LIT, NEAR_RIM, NEAR_RIM, NEAR_RIM, 0, 120.0, 942)
	# The arch, between strip x 380 and 470: a block of rock with a round-topped
	# hole through it, leaving a band on top and two legs going down.
	var arch_top: int = BackdropPaint.row(118)
	var hole_half_width: float = 30.0
	for x: int in range(380, 471):
		BackdropPaint.put_rect(image, Rect2i(x, arch_top, 1, BackdropPaint.STRIP_HEIGHT - arch_top), NEAR_BODY)
		BackdropPaint.put_pixel(image, x, arch_top, NEAR_RIM)
		var dx: float = x - 425.0
		if absf(dx) < hole_half_width:
			# Round top: highest in the middle (a flattened half circle).
			var hole_top: int = arch_top + 12 + roundi((hole_half_width - sqrt(hole_half_width * hole_half_width - dx * dx)) * 0.7)
			BackdropPaint.put_rect(image, Rect2i(x, hole_top, 1, BackdropPaint.STRIP_HEIGHT - hole_top), Color(0, 0, 0, 0))
			BackdropPaint.put_pixel(image, x, hole_top - 1, NEAR_LIT)
	# Banded rock over the spires and the arch alike.
	BackdropPaint.paint_strata(image, BackdropPaint.flat_line(-10.0), NEAR_STRATA, 943)
	return image

extends BackdropTheme
## MOUNTAIN backdrop (the Air chapter's look): a dusk sky with stars and a moon,
## a far range of snowy peaks, a bank of mist drifting between the ranges, a nearer
## range, and a dark ridge of pines; wind streaks and a few snowflakes blow past.
## Layers far to near; see BackdropTheme for how they're built and cached.

const SKY_BANDS: Array[Color] = [Color(0.07, 0.08, 0.18), Color(0.1, 0.11, 0.24), Color(0.14, 0.14, 0.3),
	Color(0.2, 0.17, 0.35), Color(0.28, 0.21, 0.39), Color(0.37, 0.26, 0.42)]
const STAR_COLOR: Color = Color(0.75, 0.78, 0.95)
const MOON_COLOR: Color = Color(0.86, 0.86, 0.95)
const MOON_SHADE: Color = Color(0.7, 0.7, 0.85)

const FAR_BODY: Color = Color(0.21, 0.19, 0.35)
const FAR_LIT: Color = Color(0.3, 0.27, 0.45)
const FAR_RIM: Color = Color(0.46, 0.42, 0.62)
const FAR_SNOW: Color = Color(0.66, 0.66, 0.82)
const FAR_SNOW_SHADOW: Color = Color(0.46, 0.44, 0.64)

const MIST_COLOR: Color = Color(0.36, 0.3, 0.48)
const MIST_RIM: Color = Color(0.46, 0.4, 0.58)

const MID_BODY: Color = Color(0.15, 0.14, 0.27)
const MID_LIT: Color = Color(0.2, 0.18, 0.33)
const MID_RIM: Color = Color(0.3, 0.27, 0.45)
const MID_SNOW: Color = Color(0.48, 0.48, 0.64)
const MID_SNOW_SHADOW: Color = Color(0.3, 0.29, 0.45)

const NEAR_BODY: Color = Color(0.07, 0.08, 0.15)
const NEAR_RIM: Color = Color(0.13, 0.14, 0.24)


func _build_layers() -> void:
	add_painted_layer("Sky", Vector2(0.01, 0.0), _paint_sky)
	add_painted_layer("FarPeaks", Vector2(0.05, 0.03), _paint_far_peaks)
	add_painted_layer("Mist", Vector2(0.1, 0.05), _paint_mist, 3.0)
	add_painted_layer("MidPeaks", Vector2(0.18, 0.08), _paint_mid_peaks)
	add_painted_layer("Pines", Vector2(0.35, 0.14), _paint_pines)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 14
	wind.colors = [Color(0.75, 0.78, 0.95, 0.14), Color(0.75, 0.78, 0.95, 0.22)]
	wind.velocity = Vector2(70.0, 4.0)
	wind.sway_amplitude = 2.0
	wind.sway_speed = 0.4
	wind.size_range = Vector2i(2, 5)
	wind.scroll_factor = 0.5
	wind.seed_value = 11
	add_motes(wind)

	var snow: BackdropMotes = BackdropMotes.new()
	snow.mote_count = 26
	snow.colors = [Color(0.85, 0.87, 1.0, 0.45), Color(0.85, 0.87, 1.0, 0.25)]
	snow.velocity = Vector2(14.0, 9.0)
	snow.sway_amplitude = 3.0
	snow.sway_speed = 0.3
	snow.scroll_factor = 0.6
	snow.seed_value = 12
	add_motes(snow)


func _paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(120))
	# Stars: most are one dim pixel; a few bright ones get a small cross. Fewer lower down.
	for star_index: int in 140:
		var x: int = roundi(BackdropPaint.random01(star_index, 1, 101) * BackdropPaint.STRIP_WIDTH)
		var depth: float = BackdropPaint.random01(star_index, 2, 101)
		var y: int = BackdropPaint.row(depth * depth * 80.0)
		var brightness: float = BackdropPaint.random01(star_index, 3, 101)
		BackdropPaint.blend_pixel(image, x, y, Color(STAR_COLOR, 0.35 + brightness * 0.5))
		if brightness > 0.93:
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				BackdropPaint.blend_pixel(image, x + offset.x, y + offset.y, Color(STAR_COLOR, 0.35))
	# The moon: a pale disc with a few darker "seas". Two in the strip would show
	# two moons on a wide screen, so only one.
	var moon_center: Vector2 = Vector2(250.0, BackdropPaint.row(34))
	BackdropPaint.put_circle(image, moon_center, 11.0, MOON_COLOR)
	BackdropPaint.put_circle(image, moon_center + Vector2(-3, -2), 3.0, MOON_SHADE)
	BackdropPaint.put_circle(image, moon_center + Vector2(4, 3), 2.0, MOON_SHADE)
	BackdropPaint.put_circle(image, moon_center + Vector2(2, -5), 1.0, MOON_SHADE)
	return image


func _paint_far_peaks() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(160.0, 55.0), Vector2(53.0, 22.0), Vector2(16.0, 5.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(132), octaves, 201, true)
	BackdropPaint.paint_mountains(image, tops, FAR_BODY, FAR_LIT, FAR_RIM, FAR_SNOW, FAR_SNOW_SHADOW,
		BackdropPaint.row(95), 70.0, 201)
	return image


func _paint_mist() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# A billowy top: big slow swells plus small round puffs.
	var octaves: Array[Vector2] = [Vector2(110.0, 10.0), Vector2(18.0, 5.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(128), octaves, 301, false)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		# Solid for 10 rows, then thinning out by dithering, gone by 26 rows down.
		for y: int in range(top, mini(top + 26, BackdropPaint.STRIP_HEIGHT)):
			var depth: int = y - top
			var keep: bool = depth < 10 or (depth < 18 and BackdropPaint.checker(x, y)) \
				or (x % 4 == y % 4)
			if keep:
				image.set_pixel(x, y, MIST_RIM if depth == 0 else MIST_COLOR)
	return image


func _paint_mid_peaks() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(128.0, 42.0), Vector2(40.0, 16.0), Vector2(12.0, 4.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(165), octaves, 401, true)
	BackdropPaint.paint_mountains(image, tops, MID_BODY, MID_LIT, MID_RIM, MID_SNOW, MID_SNOW_SHADOW,
		BackdropPaint.row(128), 50.0, 401)
	return image


func _paint_pines() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(213.0, 22.0), Vector2(64.0, 8.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(190), octaves, 501, false)
	BackdropPaint.fill_below(image, tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, tops, NEAR_RIM)
	# Pines along the ridge, in clumps: a noise decides where the forest is thick.
	var x: int = 0
	while x < BackdropPaint.STRIP_WIDTH:
		var thickness: float = BackdropPaint.periodic_noise(x, 80.0, 502)
		if thickness > 0.35:
			var height: int = 10 + roundi(BackdropPaint.random01(x, 1, 503) * 16.0 * thickness)
			BackdropPaint.paint_pine(image, x, ceili(tops[x]) + 2, height, NEAR_BODY, NEAR_RIM)
		x += 4 + roundi(BackdropPaint.random01(x, 2, 503) * 6.0)
	return image

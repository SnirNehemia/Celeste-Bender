class_name MountainSurface
extends BackdropTheme
## MOUNTAIN backdrop (the Air chapter's look): a dusk sky with stars and a moon,
## the great snowy range rising up out of view under a ceiling of cloud (both
## shared with the skyline: MountainStyle), a bank of mist, a nearer range, a dark
## ridge of pines, and big pine boughs and a crag right in front; wind streaks and
## snowflakes blow past. Layers far to near; see BackdropTheme.

const MIST_COLOR: Color = Color(0.36, 0.3, 0.48)
const MIST_RIM: Color = Color(0.46, 0.4, 0.58)

const MID_BODY: Color = Color(0.15, 0.14, 0.27)
const MID_LIT: Color = Color(0.2, 0.18, 0.33)
const MID_RIM: Color = Color(0.3, 0.27, 0.45)
const MID_SNOW: Color = Color(0.48, 0.48, 0.64)
const MID_SNOW_SHADOW: Color = Color(0.3, 0.29, 0.45)



func _build_layers() -> void:
	MountainStyle.add_shared_layers(self, SURFACE_SECTION)

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


static func paint_mist() -> Image:
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


static func paint_mid_peaks() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(128.0, 42.0), Vector2(40.0, 16.0), Vector2(12.0, 4.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(165), octaves, 401, true)
	BackdropPaint.paint_mountains(image, tops, MID_BODY, MID_LIT, MID_RIM, MID_SNOW, MID_SNOW_SHADOW,
		BackdropPaint.row(128), 50.0, 401)
	return image


static func paint_pines() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(213.0, 22.0), Vector2(64.0, 8.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(190), octaves, 501, false)
	BackdropPaint.fill_below(image, tops, MountainStyle.GROUND_BODY)
	BackdropPaint.paint_rim(image, tops, MountainStyle.GROUND_RIM)
	# Pines along the ridge, in clumps: a noise decides where the forest is thick.
	var x: int = 0
	while x < BackdropPaint.STRIP_WIDTH:
		var thickness: float = BackdropPaint.periodic_noise(x, 80.0, 502)
		if thickness > 0.35:
			var height: int = 10 + roundi(BackdropPaint.random01(x, 1, 503) * 16.0 * thickness)
			BackdropPaint.paint_pine(image, x, ceili(tops[x]) + 2, height, MountainStyle.GROUND_BODY, MountainStyle.GROUND_RIM)
		x += 4 + roundi(BackdropPaint.random01(x, 2, 503) * 6.0)
	return image


## Right in front: pine boughs reaching in from trees just off the top of the
## screen, and a snowy crag rising from the bottom.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	MountainStyle.paint_bough(image, Vector2(-10.0, BackdropPaint.row(-8)), Vector2(96.0, BackdropPaint.row(26)), 16.0, 131)
	MountainStyle.paint_bough(image, Vector2(-4.0, BackdropPaint.row(-16)), Vector2(60.0, BackdropPaint.row(4)), 8.0, 132)
	MountainStyle.paint_bough(image, Vector2(330.0, BackdropPaint.row(-12)), Vector2(236.0, BackdropPaint.row(18)), 14.0, 133)
	MountainStyle.paint_crag(image, 470.0, 50.0, 44.0, 134)
	return image

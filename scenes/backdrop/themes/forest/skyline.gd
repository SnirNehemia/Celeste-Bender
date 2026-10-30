extends BackdropTheme
## FOREST, SKYLINE: up in the treetops at sunset. An open sky with a low sun and
## soft clouds, a sea of tree crowns far below, nearer crowns with a few giant
## trees rising above the rest, and a big near branch with leaf clumps; leaves
## blow past. Layers far to near; see BackdropTheme. (Surface: surface.gd; under
## the roots: underground.gd.)

const SKY_BANDS: Array[Color] = [Color(0.12, 0.17, 0.28), Color(0.18, 0.23, 0.33), Color(0.27, 0.29, 0.35),
	Color(0.4, 0.36, 0.35), Color(0.54, 0.43, 0.35), Color(0.65, 0.5, 0.37)]
const SUN_COLOR: Color = Color(0.92, 0.72, 0.42)
const SUN_RING: Color = Color(0.75, 0.57, 0.38)
const CLOUD_BODY: Color = Color(0.5, 0.42, 0.4)
const CLOUD_LIT: Color = Color(0.7, 0.58, 0.46)
const CLOUD_SHADE: Color = Color(0.4, 0.34, 0.36)

const FAR_BODY: Color = Color(0.28, 0.32, 0.28)
const FAR_RIM: Color = Color(0.38, 0.4, 0.31)

const MID_BODY: Color = Color(0.14, 0.2, 0.14)
const MID_LIT: Color = Color(0.22, 0.29, 0.17)
const MID_RIM: Color = Color(0.3, 0.36, 0.2)

const NEAR_BODY: Color = Color(0.05, 0.08, 0.05)
const NEAR_LIT: Color = Color(0.1, 0.15, 0.08)
const NEAR_BARK: Color = Color(0.08, 0.06, 0.04)


func _build_layers() -> void:
	add_painted_layer("Sky", Vector2(0.01, 0.0), _paint_sky)
	add_painted_layer("FarCanopy", Vector2(0.04, 0.02), _paint_far_canopy)
	add_painted_layer("MidCanopy", Vector2(0.15, 0.06), _paint_mid_canopy)
	add_painted_layer("Branch", Vector2(0.42, 0.13), _paint_branch)

	var leaves: BackdropMotes = BackdropMotes.new()
	leaves.shape = BackdropMotes.Shape.LEAF
	leaves.mote_count = 16
	leaves.colors = [Color(0.45, 0.55, 0.22, 0.75), Color(0.6, 0.48, 0.2, 0.7), Color(0.35, 0.45, 0.2, 0.7)]
	leaves.velocity = Vector2(28.0, 6.0)
	leaves.sway_amplitude = 6.0
	leaves.sway_speed = 0.35
	leaves.scroll_factor = 0.65
	leaves.seed_value = 811
	add_motes(leaves)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 8
	wind.colors = [Color(1.0, 0.9, 0.7, 0.14)]
	wind.velocity = Vector2(60.0, 2.0)
	wind.size_range = Vector2i(2, 5)
	wind.scroll_factor = 0.5
	wind.seed_value = 812
	add_motes(wind)


func _paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(135))
	var sun_center: Vector2 = Vector2(180.0, BackdropPaint.row(112))
	BackdropPaint.put_circle(image, sun_center, 24.0, SUN_RING)
	BackdropPaint.put_circle(image, sun_center, 17.0, SUN_COLOR)
	for cloud_index: int in 5:
		var center: Vector2 = Vector2((cloud_index + 0.4) * BackdropPaint.STRIP_WIDTH / 5.0, BackdropPaint.row(30 + (cloud_index % 3) * 22))
		BackdropPaint.paint_cloud(image, center, 16.0 + (cloud_index % 2) * 10.0, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 813)
	return image


func _paint_far_canopy() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(146), Vector2(4.0, 8.0), 7, 821)
	BackdropPaint.fill_below(image, tops, FAR_BODY)
	BackdropPaint.paint_rim(image, tops, FAR_RIM)
	return image


func _paint_mid_canopy() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(166), Vector2(8.0, 15.0), 13, 831)
	# A few giant trees stand above the rest: a trunk and a tall, lumpy crown made
	# of many overlapping round clumps.
	for giant_index: int in 3:
		var center_x: int = roundi((giant_index + 0.3 + BackdropPaint.random01(giant_index, 1, 832) * 0.4) * BackdropPaint.STRIP_WIDTH / 3.0)
		var crown_row: float = BackdropPaint.row(100 + BackdropPaint.random01(giant_index, 2, 832) * 20.0)
		BackdropPaint.put_rect(image, Rect2i(center_x - 2, roundi(crown_row), 5, BackdropPaint.STRIP_HEIGHT), MID_BODY)
		for clump_index: int in 9:
			var clump: Vector2 = Vector2(center_x + (BackdropPaint.random01(giant_index, clump_index + 10, 832) - 0.5) * 34.0,
				crown_row + BackdropPaint.random01(giant_index, clump_index + 20, 832) * 22.0)
			var radius: float = 5.0 + BackdropPaint.random01(giant_index, clump_index + 30, 832) * 5.0
			for dx: int in range(-ceili(radius), ceili(radius) + 1):
				var column: int = posmod(roundi(clump.x) + dx, BackdropPaint.STRIP_WIDTH)
				tops[column] = minf(tops[column], clump.y - sqrt(maxf(0.0, radius * radius - dx * dx)))
	BackdropPaint.fill_below(image, tops, MID_BODY)
	# A 2-row rim: the brightest color on top, a softer one under it.
	BackdropPaint.paint_rim(image, tops, MID_LIT, 2)
	BackdropPaint.paint_rim(image, tops, MID_RIM, 1)
	return image


## A thick branch crossing the bottom of the view, with twigs and leaf clumps,
## and leaf clumps hanging in from the top corners of the strip.
func _paint_branch() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var branch_row: float = BackdropPaint.row(172)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var y: float = branch_row + sin(x * TAU / BackdropPaint.STRIP_WIDTH) * 8.0 + BackdropPaint.periodic_noise(x, 40.0, 841) * 4.0
		var thickness: int = 7 + roundi(BackdropPaint.periodic_noise(x, 80.0, 842) * 4.0)
		BackdropPaint.put_rect(image, Rect2i(x, roundi(y), 1, thickness), NEAR_BARK)
		BackdropPaint.put_pixel(image, x, roundi(y), NEAR_LIT)
	for clump_index: int in 9:
		var clump_x: float = (clump_index + BackdropPaint.random01(clump_index, 1, 843)) * BackdropPaint.STRIP_WIDTH / 9.0
		var is_top: bool = clump_index % 3 == 0
		var clump_y: float = float(BackdropPaint.row(4)) if is_top else branch_row - 4.0
		if not is_top:
			# A twig from the branch up to the clump.
			BackdropPaint.put_line(image, Vector2(clump_x - 8.0, branch_row + 2.0), Vector2(clump_x, clump_y), NEAR_BARK, 2)
		for leaf_index: int in 7:
			var offset: Vector2 = Vector2((BackdropPaint.random01(clump_index, leaf_index, 844) - 0.5) * 22.0,
				(BackdropPaint.random01(clump_index, leaf_index + 10, 844) - 0.5) * 12.0)
			var radius: float = 4.0 + BackdropPaint.random01(clump_index, leaf_index + 20, 844) * 3.0
			BackdropPaint.put_circle(image, Vector2(clump_x, clump_y) + offset + Vector2(-1, -1), radius, NEAR_LIT)
			BackdropPaint.put_circle(image, Vector2(clump_x, clump_y) + offset, radius - 1.0, NEAR_BODY)
	return image

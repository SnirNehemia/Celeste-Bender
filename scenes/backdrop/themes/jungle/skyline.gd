extends BackdropTheme
## JUNGLE, SKYLINE: high among karst pillars, tall stone towers rising out of the
## rainforest mist. A pale morning sky, far pillars in the haze, a sea of mist
## between them, nearer pillars with jungle on their flat tops and vines down their
## sides, more mist below, and treetops with fronds right in front; birds pass far
## off. Layers far to near; see BackdropTheme. (Surface: surface.gd, the rainforest
## floor; under it: underground.gd.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const SKY_BANDS: Array[Color] = [Color(0.42, 0.55, 0.68), Color(0.52, 0.62, 0.71), Color(0.63, 0.7, 0.73),
	Color(0.75, 0.78, 0.73), Color(0.85, 0.84, 0.72)]
const SUN_COLOR: Color = Color(0.98, 0.94, 0.78)
const SUN_RING: Color = Color(0.92, 0.88, 0.74)

const FAR_BODY: Color = Color(0.55, 0.62, 0.67)
const FAR_LIT: Color = Color(0.63, 0.69, 0.71)
const FAR_CROWN: Color = Color(0.5, 0.6, 0.6)

const MIST_BODY: Color = Color(0.8, 0.83, 0.79)
const MIST_LIT: Color = Color(0.9, 0.91, 0.85)
const MIST_SHADE: Color = Color(0.72, 0.76, 0.74)

const MID_BODY: Color = Color(0.25, 0.34, 0.36)
const MID_LIT: Color = Color(0.36, 0.45, 0.43)
const MID_DARK: Color = Color(0.19, 0.27, 0.3)
const CROWN_BODY: Color = Color(0.19, 0.34, 0.23)
const CROWN_RIM: Color = Color(0.32, 0.48, 0.3)

const NEAR_BODY: Color = Color(0.06, 0.13, 0.09)
const NEAR_LIT: Color = Color(0.12, 0.23, 0.13)


func _build_layers() -> void:
	add_painted_layer("Sky", Vector2(0.01, 0.0), _paint_sky)
	add_painted_layer("FarPillars", Vector2(0.03, 0.01), _paint_far_pillars)
	add_painted_layer("Mist", Vector2(0.07, 0.02), _paint_mist, 3.0)
	add_painted_layer("Pillars", Vector2(0.15, 0.05), _paint_near_pillars)
	add_painted_layer("LowMist", Vector2(0.22, 0.07), _paint_low_mist, 6.0)
	add_painted_layer("Treetops", Vector2(0.42, 0.13), _paint_treetops)

	var birds: BackdropMotes = BackdropMotes.new()
	birds.shape = BackdropMotes.Shape.BIRD
	birds.mote_count = 5
	birds.colors = [Color(0.2, 0.25, 0.28, 0.8)]
	birds.velocity = Vector2(14.0, -1.0)
	birds.sway_amplitude = 3.0
	birds.sway_speed = 0.2
	birds.size_range = Vector2i(1, 2)
	birds.scroll_factor = 0.15
	birds.vertical_range = Vector2(20.0, 110.0)
	birds.seed_value = 1411
	add_motes(birds)

	var leaves: BackdropMotes = BackdropMotes.new()
	leaves.shape = BackdropMotes.Shape.LEAF
	leaves.mote_count = 8
	leaves.colors = [Color(0.3, 0.5, 0.22, 0.75), Color(0.45, 0.55, 0.2, 0.7)]
	leaves.velocity = Vector2(18.0, 7.0)
	leaves.sway_amplitude = 6.0
	leaves.sway_speed = 0.3
	leaves.scroll_factor = 0.65
	leaves.seed_value = 1412
	add_motes(leaves)


func _paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(150))
	BackdropPaint.put_circle(image, Vector2(420.0, BackdropPaint.row(70)), 20.0, SUN_RING)
	BackdropPaint.put_circle(image, Vector2(420.0, BackdropPaint.row(70)), 14.0, SUN_COLOR)
	return image


## Karst pillars: `count` stone towers with wobbly sides, a lit left edge, a dark
## right one, and a cap of jungle (round clumps) on top, standing down to the
## bottom of the strip. Widths (half) and top rows picked from the ranges.
static func paint_pillars(image: Image, count: int, half_width_range: Vector2, top_range: Vector2, body: Color,
		lit: Color, dark: Color, crown: Color, crown_rim: Color, seed_value: int) -> void:
	for pillar_index: int in count:
		var center: float = (pillar_index + BackdropPaint.random01(pillar_index, 1, seed_value) * 0.7) * BackdropPaint.STRIP_WIDTH / count
		var half_width: float = lerpf(half_width_range.x, half_width_range.y, BackdropPaint.random01(pillar_index, 2, seed_value))
		var top: float = lerpf(top_range.x, top_range.y, BackdropPaint.random01(pillar_index, 3, seed_value))
		for y: int in range(maxi(0, roundi(top)), BackdropPaint.STRIP_HEIGHT):
			# Sides bulge and pinch with the rock layers; a little wider further down.
			var wobble: float = (BackdropPaint.periodic_noise(y * 7.0 + pillar_index * 97.0, 40.0, seed_value) - 0.5) * half_width * 0.35
			var spread: float = (y - top) * 0.06
			var left: int = roundi(center - half_width - spread + wobble)
			var right: int = roundi(center + half_width + spread + wobble * 0.5)
			BackdropPaint.put_rect(image, Rect2i(left, y, right - left + 1, 1), body)
			BackdropPaint.put_rect(image, Rect2i(left, y, maxi(1, roundi(half_width * 0.25)), 1), lit)
			BackdropPaint.put_pixel(image, right, y, dark)
			# Ledges: now and then a dark crack part way across, the strata of the stone.
			if posmod(y + pillar_index * 5, 11) == 0 and BackdropPaint.random01(pillar_index, y, seed_value) > 0.45:
				var crack: int = roundi((right - left) * (0.3 + BackdropPaint.random01(pillar_index, y + 1, seed_value) * 0.5))
				BackdropPaint.put_rect(image, Rect2i(right - crack, y, crack, 1), dark)
		# The jungle cap: clumps over the top, a little wider than the pillar.
		for clump_index: int in 6:
			var clump: Vector2 = Vector2(center + (BackdropPaint.random01(pillar_index, clump_index + 10, seed_value) - 0.5) * half_width * 2.2,
				top + 1.0 - BackdropPaint.random01(pillar_index, clump_index + 20, seed_value) * 3.0)
			var radius: float = 2.0 + half_width * 0.25 + BackdropPaint.random01(pillar_index, clump_index + 30, seed_value) * 2.0
			BackdropPaint.put_circle(image, clump + Vector2(-1.0, -1.0), radius, crown_rim)
			BackdropPaint.put_circle(image, clump, radius - 1.0, crown)
		# Vines down the sides from the cap.
		for vine_index: int in 3:
			var vine_x: int = roundi(center + (vine_index - 1) * half_width * 0.7)
			var length: int = 6 + roundi(BackdropPaint.random01(pillar_index, vine_index + 40, seed_value) * half_width * 1.5)
			BackdropPaint.put_rect(image, Rect2i(vine_x, roundi(top), 1, length), crown)


func _paint_far_pillars() -> Image:
	var image: Image = BackdropPaint.new_strip()
	paint_pillars(image, 9, Vector2(5.0, 11.0), Vector2(BackdropPaint.row(36), BackdropPaint.row(96)),
		FAR_BODY, FAR_LIT, FAR_BODY, FAR_CROWN, FAR_LIT, 1421)
	return image


## A sea of mist between the far and near pillars.
func _paint_mist() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(128), Vector2(6.0, 14.0), 13, 1431)
	BackdropPaint.fill_below(image, tops, MIST_BODY)
	BackdropPaint.paint_rim(image, tops, MIST_LIT, 2)
	for x: int in BackdropPaint.STRIP_WIDTH:
		for y: int in range(ceili(tops[x]) + 16, BackdropPaint.STRIP_HEIGHT):
			if y > ceili(tops[x]) + 24 or BackdropPaint.checker(x, y):
				image.set_pixel(x, y, MIST_SHADE)
	return image


func _paint_near_pillars() -> Image:
	var image: Image = BackdropPaint.new_strip()
	paint_pillars(image, 5, Vector2(12.0, 20.0), Vector2(BackdropPaint.row(24), BackdropPaint.row(80)),
		MID_BODY, MID_LIT, MID_DARK, CROWN_BODY, CROWN_RIM, 1441)
	return image


## Mist again, lower and nearer, hiding the near pillars' feet.
func _paint_low_mist() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(160), Vector2(8.0, 16.0), 17, 1451)
	BackdropPaint.fill_below(image, tops, MIST_SHADE)
	BackdropPaint.paint_rim(image, tops, MIST_BODY, 2)
	return image


## The tops of the trees we stand in: round crowns along the bottom with fronds
## sticking up out of them.
func _paint_treetops() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(194), Vector2(9.0, 18.0), 22, 1461)
	BackdropPaint.fill_below(image, tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, tops, NEAR_LIT)
	for frond_index: int in 10:
		var x: float = (frond_index + BackdropPaint.random01(frond_index, 1, 1462)) * BackdropPaint.STRIP_WIDTH / 10.0
		var foot: Vector2 = Vector2(x, tops[posmod(roundi(x), BackdropPaint.STRIP_WIDTH)] + 3.0)
		var side: float = 1.0 if frond_index % 2 == 0 else -1.0
		BackdropPaint.paint_frond(image, foot, -PI * 0.5 + side * 0.4, 26.0 + BackdropPaint.random01(frond_index, 2, 1462) * 14.0,
			side * 1.1, 6.0, NEAR_BODY, NEAR_LIT)
	return image

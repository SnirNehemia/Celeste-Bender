extends BackdropTheme
## JUNGLE, SURFACE: the floor of a rainforest, denser and wetter than the Forest.
## Green light filters down from a canopy you never see the top of: misty far
## trunks, slanting sun shafts, near giant trunks with buttress roots tied together
## by sagging lianas, and big broad leaves and fronds right in front; pollen drifts
## and a leaf falls now and then. Layers far to near; see BackdropTheme.
## (Under it: underground.gd, a cenote; high up: skyline.gd, the karst pillars.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## Lighter at the top, where the light comes through the canopy.
const AIR_BANDS: Array[Color] = [Color(0.6, 0.72, 0.52), Color(0.5, 0.65, 0.5), Color(0.41, 0.57, 0.46),
	Color(0.33, 0.49, 0.42), Color(0.26, 0.41, 0.37)]

const FAR_BODY: Color = Color(0.36, 0.5, 0.43)
const FAR_LIT: Color = Color(0.44, 0.58, 0.47)

const SHAFT_COLOR: Color = Color(1.0, 0.96, 0.7, 0.07)

const MID_BODY: Color = Color(0.13, 0.24, 0.2)
const MID_LIT: Color = Color(0.21, 0.34, 0.25)
const MID_DARK: Color = Color(0.09, 0.17, 0.15)
const CANOPY_BODY: Color = Color(0.12, 0.26, 0.18)
const CANOPY_LIT: Color = Color(0.2, 0.36, 0.22)
const VINE_COLOR: Color = Color(0.17, 0.3, 0.17)

const NEAR_BODY: Color = Color(0.05, 0.12, 0.08)
const NEAR_LIT: Color = Color(0.1, 0.21, 0.11)
const NEAR_RIB: Color = Color(0.14, 0.27, 0.13)

## The giant trunks of the middle layer: strip x and half width.
const TRUNKS: Array[Vector2] = [Vector2(40, 9), Vector2(175, 6), Vector2(290, 11), Vector2(430, 7), Vector2(560, 10)]


func _build_layers() -> void:
	add_painted_layer("Air", Vector2(0.01, 0.0), _paint_air)
	var far: BackdropLayer = add_painted_layer("FarTrees", Vector2(0.05, 0.02), _paint_far_trees)
	far.draw_extra = _draw_shafts
	add_painted_layer("Trunks", Vector2(0.2, 0.07), _paint_trunks)
	add_painted_layer("Leaves", Vector2(0.42, 0.13), _paint_leaves)

	var pollen: BackdropMotes = BackdropMotes.new()
	pollen.mote_count = 26
	pollen.colors = [Color(1.0, 0.95, 0.65, 0.35), Color(0.85, 1.0, 0.7, 0.25)]
	pollen.velocity = Vector2(2.0, 2.5)
	pollen.sway_amplitude = 3.0
	pollen.sway_speed = 0.15
	pollen.scroll_factor = 0.35
	pollen.seed_value = 1211
	add_motes(pollen)

	var leaves: BackdropMotes = BackdropMotes.new()
	leaves.shape = BackdropMotes.Shape.LEAF
	leaves.mote_count = 5
	leaves.colors = [Color(0.35, 0.55, 0.22, 0.8), Color(0.55, 0.6, 0.2, 0.7)]
	leaves.velocity = Vector2(3.0, 9.0)
	leaves.sway_amplitude = 7.0
	leaves.sway_speed = 0.3
	leaves.scroll_factor = 0.6
	leaves.seed_value = 1212
	add_motes(leaves)


func _paint_air() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, AIR_BANDS, BackdropPaint.row(0), BackdropPaint.row(170))
	return image


## A hanging canopy line: bumps() turned upside down around `base_row`.
static func hanging_bumps(base_row: float, radius_range: Vector2, spacing: int, seed_value: int) -> PackedFloat32Array:
	var bottoms: PackedFloat32Array = BackdropPaint.bumps(base_row, radius_range, spacing, seed_value)
	for x: int in BackdropPaint.STRIP_WIDTH:
		bottoms[x] = base_row + (base_row - bottoms[x])
	return bottoms


## Misty far trunks under a canopy, and the ground.
func _paint_far_trees() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for trunk_index: int in 16:
		var x: int = roundi((trunk_index + BackdropPaint.random01(trunk_index, 1, 1221) * 0.7) * BackdropPaint.STRIP_WIDTH / 16.0)
		var half_width: int = 1 + roundi(BackdropPaint.random01(trunk_index, 2, 1221) * 3.0)
		BackdropPaint.put_rect(image, Rect2i(x - half_width, 0, half_width * 2 + 1, BackdropPaint.STRIP_HEIGHT), FAR_BODY)
		BackdropPaint.put_rect(image, Rect2i(x - half_width, 0, 1, BackdropPaint.STRIP_HEIGHT), FAR_LIT)
	var canopy: PackedFloat32Array = hanging_bumps(BackdropPaint.row(26), Vector2(8.0, 16.0), 12, 1222)
	BackdropPaint.fill_above(image, canopy, FAR_BODY)
	BackdropPaint.paint_bottom_rim(image, canopy, FAR_LIT)
	var ground: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(160), [Vector2(120.0, 8.0), Vector2(30.0, 3.0)] as Array[Vector2], 1223, false)
	BackdropPaint.fill_below(image, ground, FAR_BODY)
	BackdropPaint.paint_rim(image, ground, FAR_LIT)
	return image


## Sun shafts slanting down through the canopy gaps.
func _draw_shafts(layer: BackdropLayer, copy_x: float, time: float) -> void:
	BackdropTheme.draw_light_shafts(layer, copy_x, time, [70.0, 205.0, 340.0, 470.0, 575.0] as Array[float],
		9.0, 0.32, 200.0, SHAFT_COLOR)


## Giant trunks with buttress roots, the canopy above them, lianas sagging from
## trunk to trunk, and ferns on the ground.
func _paint_trunks() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var ground_row: float = BackdropPaint.row(170)
	for trunk: Vector2 in TRUNKS:
		var center: int = int(trunk.x)
		for y: int in range(0, ceili(ground_row) + 4):
			# Buttress roots: the trunk flares out over its last 34 px.
			var flare: float = maxf(0.0, (y - (ground_row - 34.0)) / 34.0)
			var half_width: int = roundi(trunk.y + flare * flare * trunk.y * 1.8)
			BackdropPaint.put_rect(image, Rect2i(center - half_width, y, half_width * 2 + 1, 1), MID_BODY)
			BackdropPaint.put_rect(image, Rect2i(center - half_width, y, 2, 1), MID_LIT)
			BackdropPaint.put_pixel(image, center + half_width, y, MID_DARK)
			# The roots' dark gaps between flanges.
			if flare > 0.3:
				BackdropPaint.put_pixel(image, center - half_width / 2, y, MID_DARK)
				BackdropPaint.put_pixel(image, center + half_width / 2, y, MID_DARK)
	var canopy: PackedFloat32Array = hanging_bumps(BackdropPaint.row(6), Vector2(10.0, 20.0), 16, 1231)
	BackdropPaint.fill_above(image, canopy, CANOPY_BODY)
	BackdropPaint.paint_bottom_rim(image, canopy, CANOPY_LIT, 2)
	# Lianas: sagging curves between neighbouring trunks, a few hanging straight down.
	for trunk_index: int in TRUNKS.size():
		var from: Vector2 = Vector2(TRUNKS[trunk_index].x, BackdropPaint.row(18 + BackdropPaint.random01(trunk_index, 1, 1232) * 30.0))
		var next_x: float = TRUNKS[(trunk_index + 1) % TRUNKS.size()].x
		if next_x < from.x:
			next_x += BackdropPaint.STRIP_WIDTH
		var to: Vector2 = Vector2(next_x, BackdropPaint.row(24 + BackdropPaint.random01(trunk_index, 2, 1232) * 30.0))
		var sag: float = 40.0 + BackdropPaint.random01(trunk_index, 3, 1232) * 50.0
		var control: Vector2 = (from + to) / 2.0 + Vector2(0.0, sag)
		for step: int in 80:
			var point: Vector2 = BackdropPaint.curve_point(from, control, to, step / 79.0)
			BackdropPaint.put_pixel(image, roundi(point.x), roundi(point.y), VINE_COLOR)
		var drop_x: int = roundi((from.x + next_x) / 2.0 + 20.0)
		var drop_length: int = 30 + roundi(BackdropPaint.random01(trunk_index, 4, 1232) * 60.0)
		for y: int in range(ceili(canopy[posmod(drop_x, BackdropPaint.STRIP_WIDTH)]), BackdropPaint.row(drop_length)):
			BackdropPaint.put_pixel(image, drop_x + (1 if (y / 9) % 2 == 0 else 0), y, VINE_COLOR)
	var ground: PackedFloat32Array = BackdropPaint.ridge(ground_row, [Vector2(90.0, 6.0), Vector2(20.0, 2.0)] as Array[Vector2], 1233, false)
	BackdropPaint.fill_below(image, ground, MID_BODY)
	BackdropPaint.paint_rim(image, ground, MID_LIT)
	for fern_index: int in 22:
		var x: float = BackdropPaint.random01(fern_index, 1, 1234) * BackdropPaint.STRIP_WIDTH
		var foot: Vector2 = Vector2(x, ground[posmod(roundi(x), BackdropPaint.STRIP_WIDTH)] + 1.0)
		for side: int in [-1, 1]:
			BackdropPaint.paint_frond(image, foot, -PI * 0.5 + side * 0.7, 10.0 + BackdropPaint.random01(fern_index, 2, 1234) * 6.0,
				side * 0.9, 3.0, MID_BODY, MID_LIT)
	return image


## Big broad leaves rising from the bottom in clumps, more hanging in from the top.
func _paint_leaves() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for clump_index: int in 5:
		var clump_x: float = (clump_index + BackdropPaint.random01(clump_index, 1, 1241) * 0.6) * BackdropPaint.STRIP_WIDTH / 5.0
		var leaf_count: int = 3 + roundi(BackdropPaint.random01(clump_index, 2, 1241) * 2.0)
		for leaf_index: int in leaf_count:
			var spread: float = (float(leaf_index) / maxf(1.0, leaf_count - 1.0) - 0.5) * 1.3
			var length: float = 38.0 + BackdropPaint.random01(clump_index, leaf_index + 10, 1241) * 30.0
			var base: Vector2 = Vector2(clump_x + spread * 8.0, BackdropPaint.row(194))
			BackdropPaint.paint_leaf(image, base, -PI * 0.5 + spread, length, 7.0 + length * 0.12, spread * 0.9,
				NEAR_BODY, NEAR_LIT, NEAR_RIB)
	for top_index: int in 3:
		var top_x: float = (top_index + 0.3) * BackdropPaint.STRIP_WIDTH / 3.0
		for leaf_index: int in 2:
			var side: float = -1.0 if leaf_index == 0 else 1.0
			BackdropPaint.paint_leaf(image, Vector2(top_x + side * 4.0, BackdropPaint.row(-8)), PI * 0.5 - side * 0.5,
				34.0 + leaf_index * 8.0, 7.0, side * 0.7, NEAR_BODY, NEAR_LIT, NEAR_RIB)
	return image

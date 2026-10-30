extends BackdropTheme
## FOREST backdrop (the Fire chapter's look): a warm evening sky, a hazy far tree
## line, a mid forest of slim trunks under a canopy, golden light shafts, and near
## dark trunks with roots, an overhanging canopy and hanging vines; fireflies blink
## and leaves fall. Layers far to near; see BackdropTheme.

const SKY_BANDS: Array[Color] = [Color(0.08, 0.13, 0.14), Color(0.13, 0.18, 0.16), Color(0.22, 0.24, 0.17),
	Color(0.34, 0.3, 0.18), Color(0.46, 0.36, 0.2), Color(0.55, 0.42, 0.22)]
const SUN_COLOR: Color = Color(0.85, 0.66, 0.34)
const SUN_RING: Color = Color(0.66, 0.5, 0.26)

const FAR_BODY: Color = Color(0.22, 0.25, 0.17)
const FAR_RIM: Color = Color(0.32, 0.33, 0.2)

const MID_BODY: Color = Color(0.11, 0.16, 0.12)
const MID_LIT: Color = Color(0.17, 0.23, 0.14)
const MID_RIM: Color = Color(0.23, 0.29, 0.15)

const SHAFT_COLOR: Color = Color(1.0, 0.82, 0.45, 0.07)

const NEAR_BODY: Color = Color(0.05, 0.08, 0.06)
const NEAR_LIT: Color = Color(0.1, 0.14, 0.08)
const NEAR_BARK: Color = Color(0.03, 0.05, 0.04)
const VINE_COLOR: Color = Color(0.08, 0.13, 0.07)
const VINE_LEAF: Color = Color(0.12, 0.2, 0.09)


func _build_layers() -> void:
	add_painted_layer("Sky", Vector2(0.01, 0.0), _paint_sky)
	add_painted_layer("FarTrees", Vector2(0.06, 0.03), _paint_far_trees)
	add_painted_layer("MidForest", Vector2(0.16, 0.07), _paint_mid_forest)
	var shaft_xs: Array[float] = [30.0, 150.0, 330.0, 470.0]
	add_drawn_layer("Shafts", Vector2(0.22, 0.08), func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		BackdropTheme.draw_light_shafts(layer, copy_x, time, shaft_xs, 10.0, 0.35, 210.0, SHAFT_COLOR))
	add_painted_layer("NearTrees", Vector2(0.42, 0.13), _paint_near_trees)

	var fireflies: BackdropMotes = BackdropMotes.new()
	fireflies.shape = BackdropMotes.Shape.FIREFLY
	fireflies.mote_count = 16
	fireflies.colors = [Color(1.0, 0.85, 0.4, 0.9), Color(0.85, 1.0, 0.45, 0.8)]
	fireflies.velocity = Vector2(3.0, -2.0)
	fireflies.sway_amplitude = 4.0
	fireflies.sway_speed = 0.25
	fireflies.scroll_factor = 0.55
	fireflies.seed_value = 31
	add_motes(fireflies)

	var leaves: BackdropMotes = BackdropMotes.new()
	leaves.shape = BackdropMotes.Shape.LEAF
	leaves.mote_count = 10
	leaves.colors = [Color(0.55, 0.45, 0.18, 0.7), Color(0.4, 0.42, 0.16, 0.7), Color(0.6, 0.3, 0.12, 0.6)]
	leaves.velocity = Vector2(6.0, 11.0)
	leaves.sway_amplitude = 6.0
	leaves.sway_speed = 0.35
	leaves.scroll_factor = 0.65
	leaves.seed_value = 32
	add_motes(leaves)


func _paint_sky() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, SKY_BANDS, BackdropPaint.row(0), BackdropPaint.row(130))
	# A low sun: a warm disc in a fainter ring, half behind the trees.
	var sun_center: Vector2 = Vector2(200.0, BackdropPaint.row(108))
	BackdropPaint.put_circle(image, sun_center, 26.0, SUN_RING)
	BackdropPaint.put_circle(image, sun_center, 19.0, SUN_COLOR)
	return image


func _paint_far_trees() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(118), Vector2(8.0, 16.0), 14, 41)
	BackdropPaint.fill_below(image, tops, FAR_BODY)
	BackdropPaint.paint_rim(image, tops, FAR_RIM)
	return image


func _paint_mid_forest() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# Slim trunks from the canopy down, each with a lit left edge.
	for trunk_index: int in 22:
		var x: int = roundi((trunk_index + BackdropPaint.random01(trunk_index, 1, 51) * 0.6) * BackdropPaint.STRIP_WIDTH / 22.0)
		var width: int = 3 + roundi(BackdropPaint.random01(trunk_index, 2, 51) * 4.0)
		BackdropPaint.put_rect(image, Rect2i(x, 0, width, BackdropPaint.STRIP_HEIGHT), MID_BODY)
		BackdropPaint.put_rect(image, Rect2i(x, 0, 1, BackdropPaint.STRIP_HEIGHT), MID_LIT)
		# A branch or two reaching out.
		var branch_row: int = BackdropPaint.row(40 + BackdropPaint.random01(trunk_index, 3, 51) * 50.0)
		var reach: float = 8.0 + BackdropPaint.random01(trunk_index, 4, 51) * 10.0
		var direction: float = -1.0 if trunk_index % 2 == 0 else 1.0
		BackdropPaint.put_line(image, Vector2(x + width * 0.5, branch_row), Vector2(x + width * 0.5 + reach * direction, branch_row - reach * 0.6), MID_BODY, 2)
	# The canopy: a ceiling of crowns hanging down from the top (crowns flipped).
	var canopy_bottoms: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(-5), Vector2(10.0, 20.0), 16, 52)
	for x: int in BackdropPaint.STRIP_WIDTH:
		# Mirror: a crown's "top" measured upward from row(-5) becomes a bottom edge
		# hanging down from the top of the strip.
		var bottom: int = BackdropPaint.row(-5) + (BackdropPaint.row(-5) - ceili(canopy_bottoms[x])) + 8
		image.fill_rect(Rect2i(x, 0, 1, clampi(bottom, 0, BackdropPaint.STRIP_HEIGHT)), MID_BODY)
		BackdropPaint.put_pixel(image, x, bottom, MID_RIM)
	# Undergrowth along the bottom.
	var bush_tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(170), Vector2(6.0, 12.0), 12, 53)
	BackdropPaint.fill_below(image, bush_tops, MID_BODY)
	BackdropPaint.paint_rim(image, bush_tops, MID_RIM)
	return image


func _paint_near_trees() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var trunk_lefts: Array[int] = [20, 230, 410]
	for trunk_index: int in trunk_lefts.size():
		var left: int = trunk_lefts[trunk_index]
		var width: int = 18 + trunk_index * 3
		BackdropPaint.put_rect(image, Rect2i(left, 0, width, BackdropPaint.STRIP_HEIGHT), NEAR_BODY)
		BackdropPaint.put_rect(image, Rect2i(left, 0, 2, BackdropPaint.STRIP_HEIGHT), NEAR_LIT)
		# Bark: short dark vertical strokes.
		for stroke_index: int in 40:
			var stroke_x: int = left + 3 + roundi(BackdropPaint.random01(stroke_index, trunk_index, 61) * (width - 5))
			var stroke_y: int = roundi(BackdropPaint.random01(stroke_index, trunk_index + 9, 61) * BackdropPaint.STRIP_HEIGHT)
			BackdropPaint.put_rect(image, Rect2i(stroke_x, stroke_y, 1, 4 + stroke_index % 5), NEAR_BARK)
		# Roots: lines spreading out from the foot of the trunk.
		var foot_row: float = BackdropPaint.row(160)
		for root_index: int in 4:
			var side: float = -1.0 if root_index < 2 else 1.0
			var start_x: float = left + (2.0 if side < 0.0 else width - 2.0)
			var spread: float = 10.0 + root_index % 2 * 9.0
			BackdropPaint.put_line(image, Vector2(start_x, foot_row - 6.0 + root_index % 2 * 4.0),
				Vector2(start_x + side * spread, BackdropPaint.row(182)), NEAR_BODY, 3)
	# The overhanging canopy across the top, with leafy clumps hanging lower.
	var canopy_tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(-10), Vector2(8.0, 16.0), 12, 62)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var bottom: int = BackdropPaint.row(-10) + (BackdropPaint.row(-10) - ceili(canopy_tops[x]))
		image.fill_rect(Rect2i(x, 0, 1, clampi(bottom, 0, BackdropPaint.STRIP_HEIGHT)), NEAR_BODY)
		BackdropPaint.put_pixel(image, x, bottom, NEAR_LIT)
	# Hanging vines with leaves, from the canopy.
	for vine_index: int in 9:
		var vine_x: float = (vine_index + 0.5) * BackdropPaint.STRIP_WIDTH / 9.0 + (BackdropPaint.random01(vine_index, 1, 63) - 0.5) * 30.0
		var vine_length: float = 30.0 + BackdropPaint.random01(vine_index, 2, 63) * 60.0
		var previous: Vector2 = Vector2(vine_x, BackdropPaint.row(0))
		for segment: int in ceili(vine_length / 6.0):
			var next: Vector2 = Vector2(vine_x + sin(segment * 0.9 + vine_index) * 2.0, previous.y + 6.0)
			BackdropPaint.put_line(image, previous, next, VINE_COLOR)
			if segment % 2 == 1:
				BackdropPaint.put_rect(image, Rect2i(roundi(next.x) + (1 if segment % 4 == 1 else -3), roundi(next.y), 3, 2), VINE_LEAF)
			previous = next
	# Ferns and undergrowth along the bottom.
	var fern_tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(186), Vector2(5.0, 10.0), 9, 64)
	BackdropPaint.fill_below(image, fern_tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, fern_tops, NEAR_LIT)
	return image

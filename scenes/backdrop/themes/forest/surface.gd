class_name ForestSurface
extends BackdropTheme
## FOREST backdrop (the Fire chapter's look): a warm evening sky with a low sun
## and the forest roof overhead with giant trunks going up into it (both shared
## with the skyline: ForestStyle), a hazy far tree line, slim trunks, golden light
## shafts, near dark trunks with roots and hanging vines, and big leaves and ferns
## right in front; fireflies blink and leaves fall. Layers far to near; see
## BackdropTheme.

const FAR_BODY: Color = Color(0.22, 0.25, 0.17)
const FAR_RIM: Color = Color(0.32, 0.33, 0.2)

const MID_BODY: Color = Color(0.11, 0.16, 0.12)
const MID_LIT: Color = Color(0.17, 0.23, 0.14)
const MID_RIM: Color = Color(0.23, 0.29, 0.15)

const SHAFT_COLOR: Color = Color(1.0, 0.82, 0.45, 0.07)
## Where the light shafts start (strip x).
const SHAFT_XS: Array[float] = [30.0, 150.0, 330.0, 470.0]

const NEAR_BODY: Color = Color(0.05, 0.08, 0.06)
const NEAR_LIT: Color = Color(0.1, 0.14, 0.08)
const NEAR_BARK: Color = Color(0.03, 0.05, 0.04)
const VINE_COLOR: Color = Color(0.08, 0.13, 0.07)
const VINE_LEAF: Color = Color(0.12, 0.2, 0.09)


func _build_layers() -> void:
	ForestStyle.add_shared_layers(self, SURFACE_SECTION)

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


## Slanted light shafts through the gaps (BackdropTheme.draw_light_shafts), a draw_extra.
static func draw_shafts(layer: BackdropLayer, copy_x: float, time: float) -> void:
	BackdropTheme.draw_light_shafts(layer, copy_x, time, SHAFT_XS, 10.0, 0.35, 210.0, SHAFT_COLOR)


static func paint_far_trees() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(118), Vector2(8.0, 16.0), 14, 41)
	BackdropPaint.fill_below(image, tops, FAR_BODY)
	BackdropPaint.paint_rim(image, tops, FAR_RIM)
	return image


static func paint_mid_forest() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# Slim trunks from the canopy (ForestStyle's Canopy layer) down, each with a lit left edge.
	for trunk_index: int in 22:
		var x: int = roundi((trunk_index + BackdropPaint.random01(trunk_index, 1, 51) * 0.6) * BackdropPaint.STRIP_WIDTH / 22.0)
		var width: int = 3 + roundi(BackdropPaint.random01(trunk_index, 2, 51) * 4.0)
		BackdropPaint.put_rect(image, Rect2i(x, BackdropPaint.row(6), width, BackdropPaint.STRIP_HEIGHT), MID_BODY)
		BackdropPaint.put_rect(image, Rect2i(x, BackdropPaint.row(6), 1, BackdropPaint.STRIP_HEIGHT), MID_LIT)
		# A branch or two reaching out.
		var branch_row: int = BackdropPaint.row(40 + BackdropPaint.random01(trunk_index, 3, 51) * 50.0)
		var reach: float = 8.0 + BackdropPaint.random01(trunk_index, 4, 51) * 10.0
		var direction: float = -1.0 if trunk_index % 2 == 0 else 1.0
		BackdropPaint.put_line(image, Vector2(x + width * 0.5, branch_row), Vector2(x + width * 0.5 + reach * direction, branch_row - reach * 0.6), MID_BODY, 2)
	# Undergrowth along the bottom.
	var bush_tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.row(170), Vector2(6.0, 12.0), 12, 53)
	BackdropPaint.fill_below(image, bush_tops, MID_BODY)
	BackdropPaint.paint_rim(image, bush_tops, MID_RIM)
	return image


static func paint_near_trees() -> Image:
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


## Right in front: clumps of big leaves rising from the bottom, tall fern fronds,
## and a leafy bough hanging in from the top.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var bottom: float = BackdropPaint.row(194)
	BackdropPaint.paint_leaf_clump(image, Vector2(40.0, bottom), 5, -PI * 0.5, 1.6, Vector2(30.0, 52.0), 0.7,
		ForestStyle.FRONT_BODY, ForestStyle.FRONT_LIT, ForestStyle.FRONT_RIB, 71)
	BackdropPaint.paint_leaf_clump(image, Vector2(300.0, bottom + 4.0), 3, -PI * 0.5, 1.2, Vector2(24.0, 40.0), 0.6,
		ForestStyle.FRONT_BODY, ForestStyle.FRONT_LIT, ForestStyle.FRONT_RIB, 72)
	for side: float in [-1.0, 1.0]:
		BackdropPaint.paint_frond(image, Vector2(470.0, bottom), -PI * 0.5 + side * 0.35, 64.0, side * 0.9, 9.0,
			ForestStyle.FRONT_BODY, ForestStyle.FRONT_LIT)
		BackdropPaint.paint_frond(image, Vector2(476.0, bottom), -PI * 0.5 + side * 0.15, 48.0, side * 0.6, 7.0,
			ForestStyle.FRONT_BODY, ForestStyle.FRONT_LIT)
	BackdropPaint.paint_leaf_clump(image, Vector2(190.0, BackdropPaint.row(-10)), 4, PI * 0.5, 1.4, Vector2(26.0, 40.0), -0.6,
		ForestStyle.FRONT_BODY, ForestStyle.FRONT_LIT, ForestStyle.FRONT_RIB, 73)
	return image

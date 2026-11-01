class_name UnderwaterSurface
extends BackdropTheme
## UNDERWATER backdrop (the Water chapter's look): the middle of one column of sea
## (shared with the surface above and the deep below: UnderwaterStyle), water
## darkening downward, swaying light rays, rock towers rising past, a mid bed of
## kelp that sways, near coral and rocks, and big kelp blades and a sea fan right
## in front; bubbles rise and specks of "marine snow" sink. Layers far to near;
## see BackdropTheme.

const KELP_COLOR: Color = Color(0.07, 0.2, 0.18)
const KELP_LEAF: Color = Color(0.1, 0.26, 0.2)
const SEABED_BODY: Color = Color(0.04, 0.11, 0.16)
const SEABED_RIM: Color = Color(0.08, 0.19, 0.23)

const NEAR_BODY: Color = Color(0.02, 0.07, 0.11)
const NEAR_LIT: Color = Color(0.05, 0.13, 0.18)
const CORAL_COLOR: Color = Color(0.08, 0.12, 0.19)
const CORAL_TIP: Color = Color(0.2, 0.14, 0.24)
const NEAR_KELP: Color = Color(0.03, 0.11, 0.1)

## Kelp stalks per strip, mid bed and near rocks.
const MID_KELP_COUNT: int = 18
const NEAR_KELP_COUNT: int = 5


func _build_layers() -> void:
	UnderwaterStyle.add_shared_layers(self, SURFACE_SECTION)

	var bubbles: BackdropMotes = BackdropMotes.new()
	bubbles.shape = BackdropMotes.Shape.BUBBLE
	bubbles.mote_count = 14
	bubbles.colors = [Color(0.6, 0.9, 1.0, 0.35), Color(0.6, 0.9, 1.0, 0.22)]
	bubbles.velocity = Vector2(0.0, -16.0)
	bubbles.sway_amplitude = 2.0
	bubbles.sway_speed = 0.8
	bubbles.size_range = Vector2i(1, 2)
	bubbles.scroll_factor = 0.5
	bubbles.seed_value = 51
	add_motes(bubbles)

	var marine_snow: BackdropMotes = BackdropMotes.new()
	marine_snow.mote_count = 34
	marine_snow.colors = [Color(0.7, 0.85, 0.85, 0.22), Color(0.7, 0.85, 0.85, 0.12)]
	marine_snow.velocity = Vector2(1.5, 3.0)
	marine_snow.sway_amplitude = 2.0
	marine_snow.sway_speed = 0.1
	marine_snow.scroll_factor = 0.45
	marine_snow.seed_value = 52
	add_motes(marine_snow)


## The kelp of the seabed and of the near coral, swaying (draw_kelp), as draw_extras.
static func draw_mid_kelp(layer: BackdropLayer, copy_x: float, time: float) -> void:
	draw_kelp(layer, copy_x, time, MID_KELP_COUNT, 71, 168.0, Vector2(30.0, 90.0), KELP_COLOR, KELP_LEAF, 1.0)


static func draw_near_kelp(layer: BackdropLayer, copy_x: float, time: float) -> void:
	draw_kelp(layer, copy_x, time, NEAR_KELP_COUNT, 72, 200.0, Vector2(60.0, 130.0), NEAR_KELP, NEAR_LIT, 2.0)


static func paint_seabed() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(172), [Vector2(120.0, 12.0), Vector2(25.0, 4.0)] as Array[Vector2], 91, false)
	BackdropPaint.fill_below(image, tops, SEABED_BODY)
	BackdropPaint.paint_rim(image, tops, SEABED_RIM)
	# Round stones half buried in the bed.
	for stone_index: int in 16:
		var stone_x: float = BackdropPaint.random01(stone_index, 1, 92) * BackdropPaint.STRIP_WIDTH
		var radius: float = 2.0 + BackdropPaint.random01(stone_index, 2, 92) * 4.0
		var stone_y: float = tops[posmod(roundi(stone_x), BackdropPaint.STRIP_WIDTH)] + 1.0
		BackdropPaint.put_circle(image, Vector2(stone_x, stone_y), radius, SEABED_BODY)
		BackdropPaint.put_rect(image, Rect2i(roundi(stone_x - radius * 0.6), roundi(stone_y - radius), roundi(radius), 1), SEABED_RIM)
	return image


## Near rocks with branching coral on them.
static func paint_coral() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(186), [Vector2(160.0, 24.0), Vector2(40.0, 8.0)] as Array[Vector2], 101, false)
	BackdropPaint.fill_below(image, tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, tops, NEAR_LIT)
	for coral_index: int in 7:
		var foot_x: float = (coral_index + BackdropPaint.random01(coral_index, 1, 102)) * BackdropPaint.STRIP_WIDTH / 7.0
		var foot: Vector2 = Vector2(foot_x, tops[posmod(roundi(foot_x), BackdropPaint.STRIP_WIDTH)] + 2.0)
		paint_coral_branch(image, foot, -PI * 0.5, 16.0 + BackdropPaint.random01(coral_index, 2, 102) * 10.0, 3, coral_index * 10)
	return image


## One coral branch: a line that splits in two, each part shorter, `depth` times
## (a tiny recursive tree). Tips get a lighter, pinkish dot.
static func paint_coral_branch(image: Image, start: Vector2, angle: float, length: float, depth: int, seed_value: int) -> void:
	var end: Vector2 = start + Vector2(cos(angle), sin(angle)) * length
	BackdropPaint.put_line(image, start, end, CORAL_COLOR, 2 if depth >= 2 else 1)
	if depth == 0:
		BackdropPaint.put_rect(image, Rect2i(roundi(end.x) - 1, roundi(end.y) - 1, 2, 2), CORAL_TIP)
		return
	for side: int in [-1, 1]:
		var turn: float = side * (0.35 + BackdropPaint.random01(seed_value, side + depth * 3, 103) * 0.35)
		paint_coral_branch(image, end, angle + turn, length * 0.68, depth - 1, seed_value * 2 + side + 7)


## Kelp: stalks from the bottom, each a chain of segments whose sway grows toward
## the tip (the base is anchored), with a leaf every other segment.
static func draw_kelp(layer: BackdropLayer, copy_x: float, time: float, count: int, seed_value: int, base_row: float,
		height_range: Vector2, stalk_color: Color, leaf_color: Color, width: float) -> void:
	for stalk_index: int in count:
		var base_x: float = copy_x + (stalk_index + BackdropPaint.random01(stalk_index, 1, seed_value) * 0.8) * BackdropPaint.STRIP_WIDTH / count
		var height: float = lerpf(height_range.x, height_range.y, BackdropPaint.random01(stalk_index, 2, seed_value))
		var phase: float = BackdropPaint.random01(stalk_index, 3, seed_value) * TAU
		var segment_count: int = ceili(height / 8.0)
		var previous: Vector2 = Vector2(base_x, base_row)
		for segment: int in segment_count:
			var along: float = float(segment + 1) / segment_count
			var sway: float = sin(time * 0.8 + phase + along * 2.0) * along * along * 9.0
			var next: Vector2 = Vector2(roundf(base_x + sway), roundf(previous.y - height / segment_count))
			layer.draw_line(previous, next, stalk_color, width)
			if segment % 2 == 1:
				var leaf_side: float = 1.0 if segment % 4 == 1 else -1.0
				layer.draw_rect(Rect2(next + Vector2(leaf_side * 2.0 - (2.0 if leaf_side < 0.0 else 0.0), 0.0), Vector2(3.0, 2.0)), leaf_color)
			previous = next


## Right in front: big kelp blades from below and a sea fan, a flat lacy fan of
## branches, in a bottom corner.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for blade: Vector3 in [Vector3(16.0, 110.0, 0.15), Vector3(36.0, 74.0, -0.05), Vector3(290.0, 96.0, -0.1), Vector3(306.0, 64.0, 0.18)]:
		UnderwaterStyle.paint_kelp_blade(image, Vector2(blade.x, BackdropPaint.STRIP_HEIGHT), blade.y, blade.z, int(blade.x))
	UnderwaterStyle.paint_giant_kelp(image, BackdropTheme.SURFACE_SECTION)
	var fan_foot: Vector2 = Vector2(500.0, BackdropPaint.row(196))
	for branch: int in 9:
		var angle: float = -PI * 0.5 + (branch - 4) * 0.17
		var tip: Vector2 = fan_foot + Vector2(cos(angle), sin(angle)) * (46.0 + (branch % 3) * 6.0)
		BackdropPaint.put_line(image, fan_foot, tip, UnderwaterStyle.FRONT_BODY, 2)
		# Cross-links between neighbouring branches: the fan's lace.
		for link: int in range(1, 6):
			var along: float = link / 6.0
			var next_angle: float = angle + 0.17
			var here: Vector2 = fan_foot + Vector2(cos(angle), sin(angle)) * 46.0 * along
			var there: Vector2 = fan_foot + Vector2(cos(next_angle), sin(next_angle)) * 46.0 * along
			if branch < 8:
				BackdropPaint.put_line(image, here, there, UnderwaterStyle.FRONT_LIT)
	BackdropPaint.paint_crag(image, 500.0, 26.0, 18.0, UnderwaterStyle.FRONT_BODY, UnderwaterStyle.FRONT_LIT, UnderwaterStyle.FRONT_LIT, 104)
	return image

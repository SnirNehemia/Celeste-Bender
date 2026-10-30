extends BackdropTheme
## UNDERWATER backdrop (the Water chapter's look): deep water darkening downward
## under a rippling bright surface, swaying light rays, far rock spires, a mid bed
## of kelp that sways, and near coral and rocks; bubbles rise and specks of "marine
## snow" sink. Layers far to near; see BackdropTheme.

const WATER_BANDS: Array[Color] = [Color(0.12, 0.33, 0.43), Color(0.09, 0.27, 0.38), Color(0.07, 0.21, 0.32),
	Color(0.05, 0.16, 0.26), Color(0.04, 0.12, 0.21), Color(0.03, 0.09, 0.16), Color(0.02, 0.06, 0.12)]
const SURFACE_LIGHT: Color = Color(0.35, 0.6, 0.65)

const RAY_COLOR: Color = Color(0.6, 0.9, 0.95, 0.06)

const SPIRE_BODY: Color = Color(0.06, 0.18, 0.26)
const SPIRE_LIT: Color = Color(0.09, 0.24, 0.32)
const SPIRE_RIM: Color = Color(0.13, 0.31, 0.38)

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
	add_painted_layer("Water", Vector2(0.0, 0.0), _paint_water)
	add_drawn_layer("Rays", Vector2(0.05, 0.02), _draw_rays)
	add_painted_layer("Spires", Vector2(0.07, 0.03), _paint_spires)
	var seabed: BackdropLayer = add_painted_layer("Seabed", Vector2(0.18, 0.07), _paint_seabed)
	seabed.draw_extra = func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		_draw_kelp(layer, copy_x, time, MID_KELP_COUNT, 71, 168.0, Vector2(30.0, 90.0), KELP_COLOR, KELP_LEAF, 1.0)
	var near: BackdropLayer = add_painted_layer("Coral", Vector2(0.4, 0.12), _paint_coral)
	near.draw_extra = func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		_draw_kelp(layer, copy_x, time, NEAR_KELP_COUNT, 72, 200.0, Vector2(60.0, 130.0), NEAR_KELP, NEAR_LIT, 2.0)

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


func _paint_water() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, WATER_BANDS, BackdropPaint.row(0), BackdropPaint.row(185))
	# The surface far above: a wavy band of light along the very top, broken into
	# dashes (the ripples), dithered below.
	for x: int in BackdropPaint.STRIP_WIDTH:
		var wave: int = roundi(BackdropPaint.periodic_noise(x, 20.0, 61) * 4.0)
		var surface_row: int = BackdropPaint.row(2) + wave
		image.fill_rect(Rect2i(x, 0, 1, surface_row), SURFACE_LIGHT)
		if BackdropPaint.checker(x, surface_row):
			image.set_pixel(x, surface_row, SURFACE_LIGHT)
		if BackdropPaint.periodic_noise(x, 9.0, 62) > 0.55:
			image.set_pixel(x, surface_row + 2, SURFACE_LIGHT)
	return image


## Light rays from the surface: wide, faint, swaying side to side.
func _draw_rays(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for ray_index: int in 5:
		var top_x: float = copy_x + ray_index * 128.0 + 30.0
		var sway: float = sin(time * 0.35 + ray_index * 1.3) * 10.0
		var breathing: float = 0.6 + 0.4 * sin(time * 0.5 + ray_index * 2.1)
		var color: Color = Color(RAY_COLOR, RAY_COLOR.a * breathing)
		var top_width: float = 18.0 + ray_index % 3 * 8.0
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(top_x, BackdropPaint.row(0)), Vector2(top_x + top_width, BackdropPaint.row(0)),
			Vector2(top_x + top_width * 2.2 + sway + 40.0, BackdropPaint.row(190)),
			Vector2(top_x + sway + 40.0, BackdropPaint.row(190))])
		layer.draw_colored_polygon(points, color)


func _paint_spires() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# Tall, narrow rock towers: a peaky ridge, steep (big, short noise cells).
	var octaves: Array[Vector2] = [Vector2(90.0, 60.0), Vector2(30.0, 25.0), Vector2(9.0, 4.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(175), octaves, 81, true)
	BackdropPaint.paint_mountains(image, tops, SPIRE_BODY, SPIRE_LIT, SPIRE_RIM, SPIRE_RIM, SPIRE_RIM, 0, 22.0, 81)
	return image


func _paint_seabed() -> Image:
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
func _paint_coral() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(186), [Vector2(160.0, 24.0), Vector2(40.0, 8.0)] as Array[Vector2], 101, false)
	BackdropPaint.fill_below(image, tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, tops, NEAR_LIT)
	for coral_index: int in 7:
		var foot_x: float = (coral_index + BackdropPaint.random01(coral_index, 1, 102)) * BackdropPaint.STRIP_WIDTH / 7.0
		var foot: Vector2 = Vector2(foot_x, tops[posmod(roundi(foot_x), BackdropPaint.STRIP_WIDTH)] + 2.0)
		_paint_coral_branch(image, foot, -PI * 0.5, 16.0 + BackdropPaint.random01(coral_index, 2, 102) * 10.0, 3, coral_index * 10)
	return image


## One coral branch: a line that splits in two, each part shorter, `depth` times
## (a tiny recursive tree). Tips get a lighter, pinkish dot.
func _paint_coral_branch(image: Image, start: Vector2, angle: float, length: float, depth: int, seed_value: int) -> void:
	var end: Vector2 = start + Vector2(cos(angle), sin(angle)) * length
	BackdropPaint.put_line(image, start, end, CORAL_COLOR, 2 if depth >= 2 else 1)
	if depth == 0:
		BackdropPaint.put_rect(image, Rect2i(roundi(end.x) - 1, roundi(end.y) - 1, 2, 2), CORAL_TIP)
		return
	for side: int in [-1, 1]:
		var turn: float = side * (0.35 + BackdropPaint.random01(seed_value, side + depth * 3, 103) * 0.35)
		_paint_coral_branch(image, end, angle + turn, length * 0.68, depth - 1, seed_value * 2 + side + 7)


## Kelp: stalks from the bottom, each a chain of segments whose sway grows toward
## the tip (the base is anchored), with a leaf every other segment.
func _draw_kelp(layer: BackdropLayer, copy_x: float, time: float, count: int, seed_value: int, base_row: float,
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

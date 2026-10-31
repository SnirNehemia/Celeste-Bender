extends BackdropTheme
## TEMPLE backdrop (an ancient hall, for rooms set indoors): an open arcade of
## arches looking out on the dusk sky, the low sun and the cloud sea, with the
## hall's roof beams overhead (all shared with the skyline, up on that roof:
## TempleStyle), slanted light shafts, near pillars with hanging banners and
## flickering torches, and a big lantern on a chain right in front; dust drifts
## in the air. Layers far to near; see BackdropTheme.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const ARCADE_BODY: Color = Color(0.15, 0.12, 0.2)
const ARCADE_LIT: Color = Color(0.21, 0.17, 0.27)
const ARCADE_DARK: Color = Color(0.1, 0.08, 0.14)
## Arches per strip and their size (px).
const ARCH_COUNT: int = 8
const ARCH_PILLAR_WIDTH: int = 16
const ARCH_TOP_ROW_SCREEN: int = 40
const ARCH_FLOOR_ROW_SCREEN: int = 150

const SHAFT_COLOR: Color = Color(0.95, 0.8, 0.55, 0.06)

const PILLAR_BODY: Color = Color(0.07, 0.06, 0.1)
const PILLAR_LIT: Color = Color(0.13, 0.11, 0.17)
const PILLAR_FLUTE: Color = Color(0.05, 0.04, 0.07)
const BANNER_COLOR: Color = Color(0.3, 0.09, 0.13)
const BANNER_DARK: Color = Color(0.2, 0.06, 0.09)
const BANNER_TRIM: Color = Color(0.55, 0.42, 0.2)
## Near pillars per strip; every other gap has a banner.
const PILLAR_COUNT: int = 3
const PILLAR_WIDTH: int = 24

const TORCH_FLAME: Color = Color(1.0, 0.7, 0.3)
const TORCH_GLOW: Color = Color(1.0, 0.55, 0.2, 0.08)


func _build_layers() -> void:
	add_tall_layer(TempleStyle.NAME, "Sky", Vector2(0.01, 0.0), TempleStyle.paint_sky, SURFACE_SECTION)
	add_tall_layer(TempleStyle.NAME, "Towers", Vector2(0.04, 0.02), TempleStyle.paint_towers, SURFACE_SECTION)
	add_tall_layer(TempleStyle.NAME, "Clouds", Vector2(0.12, 0.05), TempleStyle.paint_clouds, SURFACE_SECTION, 3.0)
	add_painted_layer("Arcade", Vector2(0.14, 0.06), _paint_arcade)
	var shaft_xs: Array[float] = [60.0, 250.0, 420.0]
	add_drawn_layer("Shafts", Vector2(0.2, 0.08), func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		BackdropTheme.draw_light_shafts(layer, copy_x, time, shaft_xs, 14.0, 0.45, 200.0, SHAFT_COLOR))
	var pillars: BackdropLayer = add_painted_layer("Pillars", Vector2(0.4, 0.12), _paint_pillars)
	pillars.draw_extra = _draw_torches
	add_tall_layer(TempleStyle.NAME, "Roof", Vector2(0.42, 0.13), TempleStyle.paint_roof, SURFACE_SECTION)
	add_drawn_layer("Front", TempleStyle.FRONT_SCROLL, func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		TempleStyle.draw_big_lantern(layer, Vector2(copy_x + 180.0, BackdropPaint.row(-10)), 44.0, time))

	var dust: BackdropMotes = BackdropMotes.new()
	dust.mote_count = 30
	dust.colors = [Color(0.95, 0.85, 0.65, 0.3), Color(0.95, 0.85, 0.65, 0.15)]
	dust.velocity = Vector2(2.0, -2.0)
	dust.sway_amplitude = 3.0
	dust.sway_speed = 0.15
	dust.scroll_factor = 0.5
	dust.seed_value = 21
	add_motes(dust)


func _paint_arcade() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var top_row: int = BackdropPaint.row(ARCH_TOP_ROW_SCREEN)
	var floor_row: int = BackdropPaint.row(ARCH_FLOOR_ROW_SCREEN)
	var spacing: int = BackdropPaint.STRIP_WIDTH / ARCH_COUNT
	# The wall the arches are cut into: from a bit above the arch tops to the bottom.
	image.fill_rect(Rect2i(0, top_row - 22, BackdropPaint.STRIP_WIDTH, BackdropPaint.STRIP_HEIGHT - top_row + 22), ARCADE_BODY)
	# A cornice: a lit ledge along the top, and a dark line under it.
	image.fill_rect(Rect2i(0, top_row - 24, BackdropPaint.STRIP_WIDTH, 2), ARCADE_LIT)
	image.fill_rect(Rect2i(0, top_row - 18, BackdropPaint.STRIP_WIDTH, 1), ARCADE_DARK)
	for arch_index: int in ARCH_COUNT:
		var left: int = arch_index * spacing + ARCH_PILLAR_WIDTH / 2
		var width: int = spacing - ARCH_PILLAR_WIDTH
		var radius: float = width * 0.5
		var spring_row: int = top_row + roundi(radius)
		# The opening: a round top (half circle) over a rectangle, cut right
		# through, so the sky and clouds behind (TempleStyle) show.
		for y: int in range(top_row, floor_row):
			var half_width: float = radius
			if y < spring_row:
				var dy: float = spring_row - y
				half_width = sqrt(maxf(0.0, radius * radius - dy * dy))
			var center_x: float = left + radius
			for x: int in range(roundi(center_x - half_width), roundi(center_x + half_width)):
				image.set_pixel(posmod(x, BackdropPaint.STRIP_WIDTH), y, Color(0.0, 0.0, 0.0, 0.0))
			# The arch's lit inner edge on the right (light from the upper left
			# falls on the far side of the opening).
			BackdropPaint.put_pixel(image, roundi(center_x + half_width) - 1, y, ARCADE_LIT)
			BackdropPaint.put_pixel(image, roundi(center_x - half_width), y, ARCADE_DARK)
		# A keystone over each arch.
		BackdropPaint.put_rect(image, Rect2i(roundi(left + radius) - 2, top_row - 4, 5, 5), ARCADE_LIT)
		# Steps across the floor of the opening.
		BackdropPaint.put_rect(image, Rect2i(left, floor_row - 3, width, 1), ARCADE_LIT)
		BackdropPaint.put_rect(image, Rect2i(left, floor_row - 2, width, 2), ARCADE_DARK)
	# The floor in front of the arcade.
	image.fill_rect(Rect2i(0, floor_row, BackdropPaint.STRIP_WIDTH, 1), ARCADE_LIT)
	BackdropPaint.paint_hatch(image, _flat_tops(floor_row + 2), ARCADE_DARK, 5, 0)
	return image


func _paint_pillars() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var spacing: int = BackdropPaint.STRIP_WIDTH / PILLAR_COUNT
	for pillar_index: int in PILLAR_COUNT:
		var left: int = pillar_index * spacing + 40
		# Shaft: body, a lit left side, dark flutes (vertical grooves).
		BackdropPaint.put_rect(image, Rect2i(left, 0, PILLAR_WIDTH, BackdropPaint.STRIP_HEIGHT), PILLAR_BODY)
		BackdropPaint.put_rect(image, Rect2i(left, 0, 3, BackdropPaint.STRIP_HEIGHT), PILLAR_LIT)
		for flute_x: int in [7, 12, 17]:
			BackdropPaint.put_rect(image, Rect2i(left + flute_x, 0, 1, BackdropPaint.STRIP_HEIGHT), PILLAR_FLUTE)
		# A capital at the top and a base at the bottom: wider blocks with lit tops.
		for block_row: int in [BackdropPaint.row(14), BackdropPaint.row(166)]:
			BackdropPaint.put_rect(image, Rect2i(left - 4, block_row, PILLAR_WIDTH + 8, 7), PILLAR_BODY)
			BackdropPaint.put_rect(image, Rect2i(left - 4, block_row, PILLAR_WIDTH + 8, 1), PILLAR_LIT)
			BackdropPaint.put_rect(image, Rect2i(left - 4, block_row + 6, PILLAR_WIDTH + 8, 1), PILLAR_FLUTE)
		# Every other gap: a banner hanging from a rod, with a pointed bottom.
		if pillar_index % 2 == 0:
			_paint_banner(image, left + PILLAR_WIDTH + 40, BackdropPaint.row(22))
	# Rubble along the floor.
	var rubble_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(176), [Vector2(20.0, 4.0), Vector2(7.0, 2.0)] as Array[Vector2], 41, false)
	BackdropPaint.fill_below(image, rubble_tops, PILLAR_BODY)
	BackdropPaint.paint_rim(image, rubble_tops, PILLAR_LIT)
	return image


func _paint_banner(image: Image, left: int, top_row: int) -> void:
	var width: int = 22
	var length: int = 70
	BackdropPaint.put_rect(image, Rect2i(left - 3, top_row - 2, width + 6, 2), PILLAR_LIT)
	for y: int in length + width / 2:
		# The bottom is a V: rows past `length` get narrower from both sides.
		var cut: int = maxi(0, y - length)
		BackdropPaint.put_rect(image, Rect2i(left + cut, top_row + y, width - cut * 2, 1), BANNER_COLOR)
		# A darker fold on the right, gold trim down both edges and a band near the top.
		BackdropPaint.put_rect(image, Rect2i(left + width - 6 - cut, top_row + y, 3, 1), BANNER_DARK)
		BackdropPaint.put_pixel(image, left + cut + 1, top_row + y, BANNER_TRIM)
		BackdropPaint.put_pixel(image, left + width - cut - 2, top_row + y, BANNER_TRIM)
	BackdropPaint.put_rect(image, Rect2i(left, top_row + 8, width, 1), BANNER_TRIM)
	# A simple emblem: a ring with a dot (a wind sigil).
	BackdropPaint.put_circle(image, Vector2(left + width * 0.5, top_row + 30), 5.0, BANNER_TRIM)
	BackdropPaint.put_circle(image, Vector2(left + width * 0.5, top_row + 30), 3.0, BANNER_COLOR)
	BackdropPaint.put_pixel(image, left + width / 2, top_row + 30, BANNER_TRIM)


## A torch on the right side of each pillar: a soft flickering glow and a small
## flame (drawn every frame, so it's a draw_extra, not part of the picture).
func _draw_torches(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var spacing: int = BackdropPaint.STRIP_WIDTH / PILLAR_COUNT
	for pillar_index: int in PILLAR_COUNT:
		var spot: Vector2 = Vector2(copy_x + pillar_index * spacing + 40 + PILLAR_WIDTH + 3, BackdropPaint.row(78))
		# Flicker: two sines at odd speeds make an uneven, lively wobble.
		var flicker: float = 0.8 + 0.12 * sin(time * 9.0 + pillar_index * 2.0) + 0.08 * sin(time * 23.0 + pillar_index)
		for ring_index: int in 3:
			layer.draw_circle(spot, (22.0 - ring_index * 7.0) * flicker, TORCH_GLOW)
		layer.draw_rect(Rect2(spot + Vector2(-1, 2), Vector2(3, 6)), PILLAR_LIT)
		var flame_height: float = roundf(3.0 + 2.0 * flicker)
		layer.draw_rect(Rect2(spot + Vector2(-1, 2 - flame_height), Vector2(3, flame_height)), TORCH_FLAME)
		layer.draw_rect(Rect2(spot + Vector2(0, 1 - flame_height), Vector2(1, 1)), Color(1.0, 0.95, 0.7))


## A flat skyline at `top_row` (for paint_hatch on a floor).
static func _flat_tops(top_row: int) -> PackedFloat32Array:
	var tops: PackedFloat32Array = PackedFloat32Array()
	tops.resize(BackdropPaint.STRIP_WIDTH)
	tops.fill(top_row)
	return tops

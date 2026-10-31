extends BackdropTheme
## UNDERWATER, UNDERGROUND: the abyss, the bottom of the same column of sea as
## the reef above (UnderwaterStyle): near-black water, the last faint rays dying
## out, the dark feet of the rock towers, glowing jellyfish drifting up, near
## rock with tube worms whose tips glow, and a great dark anemone right in front;
## glowing specks and a few bubbles. Layers far to near; see BackdropTheme.
## (Surface: surface.gd, the reef; high up: skyline.gd, at the water's surface.)

const JELLY_COLORS: Array[Color] = [Color(0.95, 0.5, 0.85), Color(0.5, 0.9, 1.0), Color(0.75, 0.6, 1.0)]

const NEAR_BODY: Color = Color(0.01, 0.035, 0.06)
const NEAR_RIM: Color = Color(0.04, 0.1, 0.15)
const TUBE_COLOR: Color = Color(0.05, 0.12, 0.16)
const TUBE_TIP_COLORS: Array[Color] = [Color(0.4, 1.0, 0.85), Color(0.85, 0.5, 1.0)]

const JELLY_COUNT: int = 6
## Tube worm clumps on the near floor: strip x.
const TUBE_XS: Array[int] = [40, 170, 300, 430, 560]
const NEAR_FLOOR_ROW: float = BackdropPaint.SCREEN_TOP_ROW + 186.0  # BackdropPaint.row(186)
const NEAR_ROUGHNESS: float = 16.0
const NEAR_SEED: int = 531

## Where each tube's tip is, strip px (worked out in _build_layers, because the
## painting itself runs only once per game and the glow needs it every time).
var _tube_tips: Array[Vector2] = []


func _build_layers() -> void:
	# The same floor line paint_cave makes (same octaves and seed + 1).
	var octaves: Array[Vector2] = [Vector2(110.0, NEAR_ROUGHNESS), Vector2(30.0, NEAR_ROUGHNESS * 0.4), Vector2(9.0, 2.0)]
	var floor_tops: PackedFloat32Array = BackdropPaint.ridge(NEAR_FLOOR_ROW, octaves, NEAR_SEED + 1, false)
	for clump_index: int in TUBE_XS.size():
		for tube_index: int in 5:
			var x: int = TUBE_XS[clump_index] + tube_index * 4 - 8
			_tube_tips.append(Vector2(x, ceili(floor_tops[posmod(x, BackdropPaint.STRIP_WIDTH)]) + 2 - _tube_height(clump_index, tube_index)))
	add_tall_layer(UnderwaterStyle.NAME, "Water", Vector2(0.01, 0.0), UnderwaterStyle.paint_water, UNDERGROUND_SECTION)
	add_drawn_layer("Rays", Vector2(0.06, 0.0), func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		UnderwaterStyle.draw_rays(layer, copy_x, time, UNDERGROUND_SECTION))
	add_tall_layer(UnderwaterStyle.NAME, "Spires", Vector2(0.07, 0.0), UnderwaterStyle.paint_spires, UNDERGROUND_SECTION)
	add_drawn_layer("Jellies", Vector2(0.18, 0.06), _draw_jellies)
	var near: BackdropLayer = add_painted_layer("Tubes", Vector2(0.42, 0.13), _paint_tubes)
	near.draw_extra = _draw_tube_tips
	add_painted_layer("Front", UnderwaterStyle.FRONT_SCROLL, _paint_front)

	var specks: BackdropMotes = BackdropMotes.new()
	specks.shape = BackdropMotes.Shape.FIREFLY
	specks.mote_count = 20
	specks.colors = [Color(0.5, 0.95, 1.0, 0.7), Color(0.8, 0.6, 1.0, 0.6)]
	specks.velocity = Vector2(1.5, -1.5)
	specks.sway_amplitude = 3.0
	specks.sway_speed = 0.15
	specks.scroll_factor = 0.45
	specks.seed_value = 511
	add_motes(specks)

	var bubbles: BackdropMotes = BackdropMotes.new()
	bubbles.shape = BackdropMotes.Shape.BUBBLE
	bubbles.mote_count = 5
	bubbles.colors = [Color(0.5, 0.8, 0.9, 0.25)]
	bubbles.velocity = Vector2(0.0, -14.0)
	bubbles.sway_amplitude = 2.0
	bubbles.sway_speed = 0.8
	bubbles.size_range = Vector2i(1, 2)
	bubbles.scroll_factor = 0.5
	bubbles.seed_value = 512
	add_motes(bubbles)


## Jellyfish: each a glowing bell that squeezes and relaxes (the pulse), with
## wavy tentacles, drifting slowly up and wrapping from the top back to the bottom.
func _draw_jellies(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for jelly_index: int in JELLY_COUNT:
		var color: Color = JELLY_COLORS[jelly_index % JELLY_COLORS.size()]
		var base_x: float = copy_x + (jelly_index + 0.5) * BackdropPaint.STRIP_WIDTH / JELLY_COUNT
		var rise_speed: float = 4.0 + jelly_index % 3 * 1.5
		var y: float = fposmod(BackdropPaint.row(190) - time * rise_speed - jelly_index * 41.0, 230.0) - 10.0
		var x: float = base_x + sin(time * 0.3 + jelly_index) * 8.0
		var pulse: float = 0.5 + 0.5 * sin(time * 2.0 + jelly_index * 1.3)
		var bell_width: float = 4.0 + pulse
		var center: Vector2 = Vector2(x, y).round()
		BackdropTheme.draw_glow(layer, center, 16.0, Color(color, 0.05), 0.7 + 0.3 * pulse)
		# Bell: a half disc (rows getting narrower toward the top).
		for dy: int in 4:
			var half_width: float = bell_width * sqrt(1.0 - (dy / 4.0) * (dy / 4.0))
			layer.draw_rect(Rect2(center.x - roundf(half_width), center.y - dy, roundf(half_width) * 2.0 + 1.0, 1.0), Color(color, 0.55))
		layer.draw_rect(Rect2(center.x - 1.0, center.y - 3.0, 2.0, 1.0), Color(1.0, 1.0, 1.0, 0.6))
		# Tentacles: three wavy lines hanging below.
		for tentacle_index: int in 3:
			var tentacle_x: float = center.x - 2.0 + tentacle_index * 2.0
			for segment: int in 4:
				var wave: float = roundf(sin(time * 2.5 + segment * 0.9 + tentacle_index) * 1.0)
				layer.draw_rect(Rect2(tentacle_x + wave, center.y + 1.0 + segment * 2.0, 1.0, 2.0), Color(color, 0.35 - segment * 0.06))


func _paint_tubes() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# Only the floor (the same line paint_cave would make, so the tube tips found in
	# _build_layers sit on it): no ceiling, the sea goes on up.
	var octaves: Array[Vector2] = [Vector2(110.0, NEAR_ROUGHNESS), Vector2(30.0, NEAR_ROUGHNESS * 0.4), Vector2(9.0, 2.0)]
	var floor_tops: PackedFloat32Array = BackdropPaint.ridge(NEAR_FLOOR_ROW, octaves, NEAR_SEED + 1, false)
	BackdropPaint.fill_below(image, floor_tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, floor_tops, NEAR_RIM)
	BackdropPaint.paint_spikes(image, floor_tops, -1, 7, 16.0, NEAR_BODY, NEAR_RIM, NEAR_SEED + 3)
	for tip: Vector2 in _tube_tips:
		BackdropPaint.put_rect(image, Rect2i(int(tip.x), int(tip.y), 2, 30), TUBE_COLOR)
	return image


static func _tube_height(clump_index: int, tube_index: int) -> int:
	return 8 + roundi(BackdropPaint.random01(clump_index, tube_index, 532) * 16.0)


## The tube worms' tips: a glowing dot on each tube, pulsing in a wave along the clump.
func _draw_tube_tips(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for clump_index: int in TUBE_XS.size():
		var tip_color: Color = TUBE_TIP_COLORS[clump_index % TUBE_TIP_COLORS.size()]
		var clump_tip: Vector2 = _tube_tips[clump_index * 5 + 2]
		BackdropTheme.draw_glow(layer, Vector2(copy_x + clump_tip.x, clump_tip.y), 20.0, Color(tip_color, 0.05), 0.6 + 0.4 * sin(time * 0.8 + clump_index))
		for tube_index: int in 5:
			var tip: Vector2 = _tube_tips[clump_index * 5 + tube_index]
			var glow: float = 0.5 + 0.5 * sin(time * 1.5 - tube_index * 0.8 + clump_index)
			layer.draw_rect(Rect2(copy_x + tip.x, tip.y - 1.0, 2.0, 2.0), Color(tip_color, 0.4 + 0.5 * glow))


## Right in front: a great dark anemone on a rock in a bottom corner, its
## tentacles curling up, the tips faintly lit.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var foot: Vector2 = Vector2(110.0, BackdropPaint.row(186))
	BackdropPaint.paint_crag(image, foot.x, 46.0, 30.0, UnderwaterStyle.FRONT_BODY, UnderwaterStyle.FRONT_LIT, UnderwaterStyle.FRONT_LIT, 541)
	for tentacle: int in 13:
		var angle: float = -PI * 0.5 + (tentacle - 6) * 0.19
		var length: float = 26.0 + BackdropPaint.random01(tentacle, 1, 542) * 16.0
		var curl: float = (tentacle - 6) * 0.05
		var point: Vector2 = foot + Vector2(0.0, -2.0)
		for step: int in roundi(length):
			var heading: float = angle + curl * step * 0.2
			var next: Vector2 = point + Vector2(cos(heading), sin(heading))
			BackdropPaint.put_line(image, point, next, UnderwaterStyle.FRONT_BODY, 3 if step < length * 0.6 else 2)
			point = next
		BackdropPaint.put_rect(image, Rect2i(roundi(point.x) - 1, roundi(point.y) - 1, 2, 2), TUBE_TIP_COLORS[tentacle % 2].darkened(0.6))
	return image

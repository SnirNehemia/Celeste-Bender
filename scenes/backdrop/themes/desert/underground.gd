extends BackdropTheme
## DESERT, UNDERGROUND: sandstone caverns with buried ruins. Warm dark depths,
## far banded cave walls, half-buried columns with thin falls of sand pouring
## from cracks in the ceiling, and near rock with stalactites; dust sinks. Layers
## far to near; see BackdropTheme. (Surface: surface.gd; high up: skyline.gd.)

const DEPTH_BANDS: Array[Color] = [Color(0.06, 0.035, 0.04), Color(0.09, 0.05, 0.05), Color(0.12, 0.07, 0.06),
	Color(0.09, 0.05, 0.05), Color(0.06, 0.035, 0.04)]

const FAR_BODY: Color = Color(0.15, 0.09, 0.08)
const FAR_STRATA: Color = Color(0.12, 0.07, 0.07)
const FAR_RIM: Color = Color(0.22, 0.13, 0.1)

const COLUMN_BODY: Color = Color(0.2, 0.13, 0.1)
const COLUMN_LIT: Color = Color(0.3, 0.2, 0.14)
const COLUMN_DARK: Color = Color(0.14, 0.09, 0.07)
const SAND_BODY: Color = Color(0.27, 0.18, 0.12)
const SAND_RIM: Color = Color(0.38, 0.26, 0.16)
const SANDFALL_COLOR: Color = Color(0.55, 0.4, 0.25, 0.55)

const NEAR_BODY: Color = Color(0.07, 0.04, 0.04)
const NEAR_STRATA: Color = Color(0.1, 0.06, 0.05)
const NEAR_RIM: Color = Color(0.17, 0.1, 0.08)

## Ruined columns: strip x and how much of the column is left (0-1).
const COLUMNS: Array[Vector2] = [Vector2(50, 0.9), Vector2(150, 0.5), Vector2(260, 1.0), Vector2(380, 0.35), Vector2(500, 0.75)]
## Sand falls: strip x of each stream.
const SANDFALL_XS: Array[float] = [105.0, 330.0, 555.0]


func _build_layers() -> void:
	add_painted_layer("Depths", Vector2(0.01, 0.0), _paint_depths)
	add_painted_layer("FarCave", Vector2(0.07, 0.03), _paint_far_cave)
	var ruins: BackdropLayer = add_painted_layer("Ruins", Vector2(0.2, 0.07), _paint_ruins)
	ruins.draw_extra = _draw_sandfalls
	add_painted_layer("NearCave", Vector2(0.42, 0.13), _paint_near_cave)

	var dust: BackdropMotes = BackdropMotes.new()
	dust.mote_count = 24
	dust.colors = [Color(0.8, 0.6, 0.4, 0.25), Color(0.8, 0.6, 0.4, 0.12)]
	dust.velocity = Vector2(2.0, 6.0)
	dust.sway_amplitude = 2.0
	dust.sway_speed = 0.2
	dust.scroll_factor = 0.5
	dust.seed_value = 411
	add_motes(dust)


func _paint_depths() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, DEPTH_BANDS, 0, BackdropPaint.STRIP_HEIGHT)
	return image


func _paint_far_cave() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_cave(image, BackdropPaint.row(20), BackdropPaint.row(150), 20.0, FAR_BODY, FAR_RIM, 30, 18.0, 421)
	BackdropPaint.paint_strata(image, BackdropPaint.flat_line(-10.0), FAR_STRATA, 422)
	return image


func _paint_ruins() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var floor_row: int = BackdropPaint.row(160)
	for column: Vector2 in COLUMNS:
		var left: int = int(column.x)
		var full_height: int = 120
		var height: int = roundi(full_height * column.y)
		var top: int = floor_row - height
		BackdropPaint.put_rect(image, Rect2i(left, top, 16, height), COLUMN_BODY)
		BackdropPaint.put_rect(image, Rect2i(left, top, 2, height), COLUMN_LIT)
		BackdropPaint.put_rect(image, Rect2i(left + 13, top, 3, height), COLUMN_DARK)
		for flute_x: int in [5, 9]:
			BackdropPaint.put_rect(image, Rect2i(left + flute_x, top, 1, height), COLUMN_DARK)
		if column.y >= 0.99:
			# Whole: a capital and a piece of the lintel it held.
			BackdropPaint.put_rect(image, Rect2i(left - 4, top - 6, 24, 6), COLUMN_BODY)
			BackdropPaint.put_rect(image, Rect2i(left - 4, top - 6, 24, 1), COLUMN_LIT)
			BackdropPaint.put_rect(image, Rect2i(left - 20, top - 14, 60, 8), COLUMN_BODY)
			BackdropPaint.put_rect(image, Rect2i(left - 20, top - 14, 60, 1), COLUMN_LIT)
		else:
			# Broken: a jagged top.
			for x: int in range(left, left + 16):
				var bite: int = roundi(BackdropPaint.random01(x, height, 423) * 5.0)
				BackdropPaint.put_rect(image, Rect2i(x, top, 1, bite), Color(0, 0, 0, 0))
	# Sand drifted over the floor and the columns' feet, in dunes.
	var sand_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(170), [Vector2(160.0, 18.0), Vector2(40.0, 5.0)] as Array[Vector2], 424, false)
	BackdropPaint.fill_below(image, sand_tops, SAND_BODY)
	BackdropPaint.paint_rim(image, sand_tops, SAND_RIM)
	# A little cone of sand under each fall.
	for fall_x: float in SANDFALL_XS:
		var tip_row: float = sand_tops[roundi(fall_x)] - 6.0
		for dx: int in range(-12, 13):
			var top: float = tip_row + absf(dx) * 0.5
			BackdropPaint.put_rect(image, Rect2i(roundi(fall_x) + dx, roundi(top), 1, 10), SAND_BODY)
			BackdropPaint.put_pixel(image, roundi(fall_x) + dx, roundi(top), SAND_RIM)
	return image


## Sand pouring from the ceiling: a thin stream of dashes falling down.
func _draw_sandfalls(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for fall_index: int in SANDFALL_XS.size():
		var x: float = copy_x + SANDFALL_XS[fall_index]
		layer.draw_rect(Rect2(x, 0.0, 1.0, BackdropPaint.row(150)), Color(SANDFALL_COLOR, SANDFALL_COLOR.a * 0.5))
		# Grains: dashes sliding down; fposmod repeats them every 12 px.
		var scroll: float = fposmod(time * 60.0 + fall_index * 5.0, 12.0)
		for y: float in range(0, BackdropPaint.row(150), 12):
			layer.draw_rect(Rect2(x - 1.0 + fmod(y, 24.0) / 24.0 * 2.0, y + scroll, 1.0, 4.0), SANDFALL_COLOR)


func _paint_near_cave() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var edges: Array[PackedFloat32Array] = BackdropPaint.paint_cave(image, BackdropPaint.row(0), BackdropPaint.row(188), 14.0, NEAR_BODY, NEAR_RIM, 20, 30.0, 431)
	BackdropPaint.paint_strata(image, edges[1], NEAR_STRATA, 432)
	return image

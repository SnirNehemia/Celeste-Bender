extends BackdropTheme
## SHORE, SURFACE: a beach on the open sea at midday. A blue sky with clouds over
## a wide sea that glitters, a far island with a lighthouse on the horizon, a rocky
## headland with sea stacks in the surf, a sandy beach where the waves wash in and
## out, and palm trees and dunes in front; gulls drift by. Layers far to near; see
## BackdropTheme. (Under it: underground.gd, a sea cave; high up: skyline.gd, the
## cliff top.)
##
## The sea's layers move only sideways (vertical factor 0), so the horizon stays
## level with the islands on it.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const HORIZON_SCREEN_ROW: int = 96

const SKY_BANDS: Array[Color] = [Color(0.3, 0.5, 0.76), Color(0.38, 0.58, 0.8), Color(0.48, 0.66, 0.84),
	Color(0.6, 0.75, 0.86), Color(0.74, 0.84, 0.88)]
const SEA_BANDS: Array[Color] = [Color(0.2, 0.42, 0.62), Color(0.18, 0.46, 0.63), Color(0.17, 0.51, 0.63),
	Color(0.19, 0.57, 0.63), Color(0.23, 0.63, 0.64)]
const HORIZON_LINE: Color = Color(0.55, 0.72, 0.82)
const CLOUD_BODY: Color = Color(0.86, 0.9, 0.93)
const CLOUD_LIT: Color = Color(0.98, 0.98, 0.98)
const CLOUD_SHADE: Color = Color(0.72, 0.8, 0.88)
const GLITTER: Color = Color(1.0, 1.0, 0.95)

const ISLAND_BODY: Color = Color(0.42, 0.56, 0.7)
const ISLAND_RIM: Color = Color(0.52, 0.65, 0.76)
const TOWER_WHITE: Color = Color(0.9, 0.9, 0.88)
const TOWER_RED: Color = Color(0.75, 0.3, 0.28)

const ROCK_BODY: Color = Color(0.42, 0.36, 0.34)
const ROCK_LIT: Color = Color(0.58, 0.5, 0.42)
const ROCK_RIM: Color = Color(0.7, 0.62, 0.5)
const GRASS_TOP: Color = Color(0.42, 0.58, 0.3)
const FOAM: Color = Color(0.94, 0.97, 0.97)

const SAND: Color = Color(0.86, 0.77, 0.57)
const SAND_LIT: Color = Color(0.94, 0.87, 0.68)
const WET_SAND: Color = Color(0.7, 0.62, 0.48)
const WASH: Color = Color(0.5, 0.78, 0.78, 0.55)

const NEAR_BODY: Color = Color(0.12, 0.24, 0.2)
const NEAR_LIT: Color = Color(0.2, 0.36, 0.25)
const TRUNK: Color = Color(0.32, 0.25, 0.2)
const TRUNK_LIT: Color = Color(0.45, 0.36, 0.27)
const DUNE: Color = Color(0.6, 0.5, 0.36)
const DUNE_LIT: Color = Color(0.74, 0.63, 0.45)

## Where the beach's sand starts (screen row) and the headland's foot in the sea.
const SAND_SCREEN_ROW: int = 156
const HEADLAND_FOOT_SCREEN_ROW: int = 128
## The palms: strip x of their feet and how far each leans (px at the top).
const PALMS: Array[Vector2] = [Vector2(90, 30), Vector2(130, -18), Vector2(420, 26)]


func _build_layers() -> void:
	var sky: BackdropLayer = add_painted_layer("SkyAndSea", Vector2(0.01, 0.0), _paint_sky_and_sea)
	sky.draw_extra = _draw_glitter
	add_painted_layer("Clouds", Vector2(0.03, 0.0), _paint_clouds, 3.0)
	add_painted_layer("Island", Vector2(0.04, 0.0), _paint_island)
	var headland: BackdropLayer = add_painted_layer("Headland", Vector2(0.14, 0.0), _paint_headland)
	headland.draw_extra = _draw_surf
	var beach: BackdropLayer = add_painted_layer("Beach", Vector2(0.28, 0.08), _paint_beach)
	beach.draw_extra = _draw_waves
	add_painted_layer("Palms", Vector2(0.45, 0.14), _paint_palms)

	var gulls: BackdropMotes = BackdropMotes.new()
	gulls.shape = BackdropMotes.Shape.BIRD
	gulls.mote_count = 4
	gulls.colors = [Color(0.97, 0.97, 0.97, 0.9), Color(0.85, 0.88, 0.9, 0.8)]
	gulls.velocity = Vector2(-9.0, 0.0)
	gulls.sway_amplitude = 4.0
	gulls.sway_speed = 0.15
	gulls.size_range = Vector2i(1, 2)
	gulls.scroll_factor = 0.2
	gulls.vertical_range = Vector2(16.0, 80.0)
	gulls.seed_value = 1511
	add_motes(gulls)


func _paint_sky_and_sea() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var horizon: int = BackdropPaint.row(HORIZON_SCREEN_ROW)
	BackdropPaint.paint_bands(image, SEA_BANDS, horizon, BackdropPaint.row(170))
	var sky: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(sky, SKY_BANDS, BackdropPaint.row(-10), horizon)
	image.blit_rect(sky, Rect2i(0, 0, BackdropPaint.STRIP_WIDTH, horizon), Vector2i.ZERO)
	image.fill_rect(Rect2i(0, horizon, BackdropPaint.STRIP_WIDTH, 1), HORIZON_LINE)
	return image


## Sun glitter on the sea: short bright dashes that blink, more of them near shore.
func _draw_glitter(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var horizon: float = BackdropPaint.row(HORIZON_SCREEN_ROW)
	for glint_index: int in 40:
		var depth: float = BackdropPaint.random01(glint_index, 2, 1512)
		var shimmer: float = sin(time * (1.5 + depth * 2.0) + glint_index * 2.3)
		if shimmer < 0.55:
			continue
		var x: float = copy_x + BackdropPaint.random01(glint_index, 1, 1512) * BackdropPaint.STRIP_WIDTH
		var y: float = horizon + 3.0 + floorf(depth * depth * 60.0)
		layer.draw_rect(Rect2(x, y, 1.0 + roundf(depth * 3.0), 1.0), Color(GLITTER, 0.8))


func _paint_clouds() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for cloud_index: int in 6:
		var center: Vector2 = Vector2((cloud_index + BackdropPaint.random01(cloud_index, 1, 1521) * 0.6) * BackdropPaint.STRIP_WIDTH / 6.0,
			BackdropPaint.row(18 + BackdropPaint.random01(cloud_index, 2, 1521) * 50.0))
		var half_width: float = 14.0 + BackdropPaint.random01(cloud_index, 3, 1521) * 20.0
		BackdropPaint.paint_cloud(image, center, half_width, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 1522)
	return image


## A low far island on the horizon with a lighthouse on it.
func _paint_island() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var horizon: float = BackdropPaint.row(HORIZON_SCREEN_ROW)
	var tops: PackedFloat32Array = BackdropPaint.flat_line(horizon + 1.0)
	var island_tops: PackedFloat32Array = BackdropPaint.bumps(horizon + 1.0, Vector2(4.0, 9.0), 9, 1531)
	for x: int in range(230, 330):
		tops[x] = island_tops[x]
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		if top < horizon:
			image.fill_rect(Rect2i(x, top, 1, int(horizon) - top), ISLAND_BODY)
			image.set_pixel(x, top, ISLAND_RIM)
	var tower_x: int = 286
	var tower_foot: int = ceili(tops[tower_x])
	for y: int in range(tower_foot - 10, tower_foot):
		BackdropPaint.put_rect(image, Rect2i(tower_x, y, 2, 1), TOWER_RED if (y / 2) % 2 == 0 else TOWER_WHITE)
	BackdropPaint.put_rect(image, Rect2i(tower_x, tower_foot - 12, 2, 2), TOWER_WHITE)
	return image


## A rocky headland standing in the sea, grass on top, and sea stacks.
func _paint_headland() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var foot: float = BackdropPaint.row(HEADLAND_FOOT_SCREEN_ROW)
	var tops: PackedFloat32Array = BackdropPaint.flat_line(BackdropPaint.STRIP_HEIGHT + 4.0)
	var land: PackedFloat32Array = BackdropPaint.mesas(foot, 3, Vector2(30.0, 60.0), Vector2(26.0, 46.0), 1541)
	for x: int in BackdropPaint.STRIP_WIDTH:
		# Only where the land rises out of the sea; the rest stays open water.
		if land[x] < foot - 1.0:
			tops[x] = land[x]
	BackdropPaint.paint_mountains(image, tops, ROCK_BODY, ROCK_LIT, ROCK_RIM, GRASS_TOP, GRASS_TOP, BackdropPaint.STRIP_HEIGHT, 18.0, 1542)
	BackdropPaint.paint_strata(image, tops, Color(ROCK_BODY.darkened(0.15)), 1543)
	# The sea in front of the headland's foot: cut the rock off at the waterline.
	image.fill_rect(Rect2i(0, roundi(foot), BackdropPaint.STRIP_WIDTH, BackdropPaint.STRIP_HEIGHT - roundi(foot)), Color(0, 0, 0, 0))
	return image


## White surf at the headland's foot, breaking in and sliding back.
func _draw_surf(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var foot: float = BackdropPaint.row(HEADLAND_FOOT_SCREEN_ROW)
	for x: int in range(0, BackdropPaint.STRIP_WIDTH, 3):
		var swell: float = sin(x * 0.05 + time * 1.4)
		if swell > -0.3:
			layer.draw_rect(Rect2(copy_x + x, foot - roundf(swell), 2.0, 1.0), Color(FOAM, 0.6 + swell * 0.3))


## The beach: wet sand along the water's edge, dry sand behind.
func _paint_beach() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(SAND_SCREEN_ROW), [Vector2(200.0, 6.0), Vector2(50.0, 2.0)] as Array[Vector2], 1551, false)
	BackdropPaint.fill_below(image, tops, SAND)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		image.fill_rect(Rect2i(x, top, 1, 4), WET_SAND)
		if BackdropPaint.checker(x, top + 4):
			BackdropPaint.put_pixel(image, x, top + 4, WET_SAND)
		BackdropPaint.put_pixel(image, x, top + 9, SAND_LIT if x % 5 != 0 else SAND)
	return image


## The waves washing up the wet sand and back: a see-through sheet with a foam edge.
func _draw_waves(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var sand_row: float = BackdropPaint.row(SAND_SCREEN_ROW)
	for x: int in range(0, BackdropPaint.STRIP_WIDTH, 2):
		var reach: float = 2.0 + roundf((sin(time * 0.8 + x * 0.012) * 0.5 + 0.5) * 4.0 + sin(x * 0.09 + time) * 1.0)
		var edge: float = sand_row - 3.0 + reach
		layer.draw_rect(Rect2(copy_x + x, sand_row - 6.0, 2.0, edge - sand_row + 6.0), WASH)
		layer.draw_rect(Rect2(copy_x + x, edge, 2.0, 1.0), FOAM)


## Palms leaning over the beach, and dunes with beach grass in front.
func _paint_palms() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var dunes: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(186), [Vector2(160.0, 12.0), Vector2(40.0, 4.0)] as Array[Vector2], 1561, false)
	for palm_index: int in PALMS.size():
		var palm: Vector2 = PALMS[palm_index]
		var foot: Vector2 = Vector2(palm.x, dunes[int(palm.x)] + 4.0)
		var height: float = 100.0 + BackdropPaint.random01(palm_index, 1, 1562) * 30.0
		var top: Vector2 = foot + Vector2(palm.y, -height)
		var control: Vector2 = foot + Vector2(palm.y * 0.1, -height * 0.6)
		paint_palm(image, foot, control, top, palm_index + 1563)
	BackdropPaint.fill_below(image, dunes, DUNE)
	BackdropPaint.paint_rim(image, dunes, DUNE_LIT)
	for tuft_index: int in 30:
		var x: int = floori(BackdropPaint.random01(tuft_index, 1, 1564) * BackdropPaint.STRIP_WIDTH)
		var root: Vector2 = Vector2(x, dunes[x] + 1.0)
		for blade: int in 3:
			BackdropPaint.put_line(image, root, root + Vector2((blade - 1) * 3, -5.0 - blade % 2 * 3.0), NEAR_LIT)
	return image


## One palm: a curved trunk from `foot` to `top` (bent toward `control`), ringed,
## thicker at the foot, and a crown of drooping fronds and coconuts at the top.
static func paint_palm(image: Image, foot: Vector2, control: Vector2, top: Vector2, seed_value: int) -> void:
	var steps: int = ceili(foot.distance_to(top))
	for step: int in steps + 1:
		var along: float = float(step) / steps
		var point: Vector2 = BackdropPaint.curve_point(foot, control, top, along)
		var width: int = 4 if along < 0.3 else 3
		var x: int = roundi(point.x - width * 0.5)
		BackdropPaint.put_rect(image, Rect2i(x, roundi(point.y), width, 1), TRUNK if step % 5 != 0 else TRUNK.darkened(0.3))
		BackdropPaint.put_pixel(image, x, roundi(point.y), TRUNK_LIT)
	for frond_index: int in 7:
		var angle: float = -PI + frond_index * PI / 6.0 + (BackdropPaint.random01(frond_index, 1, seed_value) - 0.5) * 0.3
		var bend: float = 0.9 if cos(angle) > 0.0 else -0.9
		BackdropPaint.paint_frond(image, top, angle, 26.0 + BackdropPaint.random01(frond_index, 2, seed_value) * 10.0, bend, 6.0,
			NEAR_BODY, NEAR_LIT)
	for coconut: int in 3:
		BackdropPaint.put_circle(image, top + Vector2(coconut * 3 - 3, 3 + coconut % 2), 1.5, TRUNK.darkened(0.2))

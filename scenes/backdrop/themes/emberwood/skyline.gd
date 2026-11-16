class_name EmberwoodSkyline
extends BackdropTheme
## EMBERWOOD, SKYLINE: above the treeline on the volcano's flank, at dusk. Mostly
## open sky: plum dark with stars, the plume of ash from the crater below rising
## through all of it, and the roof of the wood low along the bottom (all shared
## with the surface: EmberwoodStyle); dark ash clouds lit ember from below,
## drifting; a burnt slope of bare black snags rising behind the treetops; the
## charred, broken tops of the surface's giant trunks standing out of the
## treetops, embers still glowing in their cracks; and right in front black
## crags and a charred dead tree; embers blow past and ash streaks by on the wind.
## Layers far to near; see BackdropTheme. (Below: surface.gd, in the wood;
## under that: underground.gd, the root caves.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const CLOUD_BODY: Color = Color(0.15, 0.08, 0.1)
const CLOUD_LIT: Color = Color(0.24, 0.12, 0.13)
## The clouds' undersides catch the lava's light.
const CLOUD_UNDERGLOW: Color = Color(0.46, 0.17, 0.1)

const SLOPE_HAZE: float = 0.36
## The burnt slope's top (screen row) and how many snags stand on it.
const SLOPE_SCREEN_ROW: int = 112
const SNAG_COUNT: int = 16

## Charred bark: the giants' dead tops. [crust, rim, edge, inside, hatch, deep].
const CHAR: Array[Color] = [Color(0.17, 0.11, 0.1), Color(0.62, 0.28, 0.12), Color(0.09, 0.06, 0.06),
	Color(0.06, 0.04, 0.045), Color(0.09, 0.06, 0.06), Color(0.03, 0.02, 0.025)]
## How high each giant's broken top reaches (screen row), in EmberwoodSurface.GIANTS' order.
const SNAG_TOP_ROWS: Array[int] = [112, 132]
## Embers still glowing in the cracks of each snag.
const EMBERS_PER_SNAG: int = 4


func _build_layers() -> void:
	EmberwoodStyle.add_shared_layers(self, SKYLINE_SECTION)

	var embers: BackdropMotes = BackdropMotes.new()
	embers.shape = BackdropMotes.Shape.FIREFLY
	embers.mote_count = 14
	embers.colors = [Color(1.0, 0.6, 0.2, 0.9), Color(1.0, 0.8, 0.35, 0.8)]
	embers.velocity = Vector2(12.0, -9.0)
	embers.sway_amplitude = 3.0
	embers.sway_speed = 0.4
	embers.scroll_factor = 0.5
	embers.seed_value = 7301
	add_motes(embers)

	var ash: BackdropMotes = BackdropMotes.new()
	ash.shape = BackdropMotes.Shape.STREAK
	ash.mote_count = 14
	ash.colors = [Color(0.5, 0.4, 0.4, 0.22), Color(0.34, 0.27, 0.28, 0.3)]
	ash.velocity = Vector2(46.0, 4.0)
	ash.size_range = Vector2i(2, 5)
	ash.scroll_factor = 0.45
	ash.seed_value = 7302
	add_motes(ash)


## Dark ash clouds at different heights, their flat undersides lit by the lava.
static func paint_ash_clouds() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for cloud_index: int in 6:
		var center: Vector2 = Vector2((cloud_index + BackdropPaint.random01(cloud_index, 1, 7311) * 0.6) * BackdropPaint.STRIP_WIDTH / 6.0,
			BackdropPaint.row(34 + BackdropPaint.random01(cloud_index, 2, 7311) * 70.0))
		var half_width: float = 18.0 + BackdropPaint.random01(cloud_index, 3, 7311) * 24.0
		BackdropPaint.paint_cloud(image, center, half_width, CLOUD_BODY, CLOUD_LIT, CLOUD_UNDERGLOW, cloud_index + 7312)
	return image


## The burnt slope: a far swell of bare lava rock, hazed, with thin black snags
## (dead trunks with a couple of stubs) standing along its top.
static func paint_burnt_slope() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var octaves: Array[Vector2] = [Vector2(170.0, 20.0), Vector2(44.0, 6.0), Vector2(10.0, 2.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(SLOPE_SCREEN_ROW), octaves, 7321, false)
	var body: Color = EmberwoodStyle.far(EmberwoodStyle.ROCK[BackdropTerrain.EDGE], SLOPE_HAZE)
	var lit: Color = EmberwoodStyle.far(EmberwoodStyle.ROCK[BackdropTerrain.CRUST], SLOPE_HAZE)
	var rim: Color = EmberwoodStyle.far(EmberwoodStyle.ROCK[BackdropTerrain.RIM], SLOPE_HAZE)
	var snag_color: Color = EmberwoodStyle.far(EmberwoodStyle.FRONT_BODY, SLOPE_HAZE)
	# Snags first, so the slope's rim covers their feet.
	for snag_index: int in SNAG_COUNT:
		var x: float = (snag_index + BackdropPaint.random01(snag_index, 1, 7322) * 0.7) * BackdropPaint.STRIP_WIDTH / SNAG_COUNT
		var foot: Vector2 = Vector2(roundf(x), tops[posmod(roundi(x), BackdropPaint.STRIP_WIDTH)] + 2.0)
		var height: float = 14.0 + BackdropPaint.random01(snag_index, 2, 7322) * 26.0
		var top: Vector2 = foot + Vector2((BackdropPaint.random01(snag_index, 3, 7322) - 0.5) * 6.0, -height)
		BackdropPaint.put_line(image, foot, top, snag_color, 2)
		for stub: int in 2:
			var side: float = -1.0 if (stub + snag_index) % 2 == 0 else 1.0
			var start: Vector2 = foot.lerp(top, 0.45 + stub * 0.25)
			BackdropPaint.put_line(image, start, start + Vector2(side * (4.0 + height * 0.14), -3.0 - height * 0.1), snag_color)
	BackdropPaint.paint_mountains(image, tops, body, lit, rim, rim, rim, -100, 14.0, 7323)
	BackdropPaint.paint_hatch(image, tops, lit, 7, 8)
	return image


## The charred, broken tops of the surface's giant trunks standing out of the
## treetops (same strip x as EmberwoodSurface.GIANTS: one tree, seen from the
## wood below and from up here): a trunk ending in splinters of different
## heights, one broken limb still reaching out, embers glowing in its cracks.
static func paint_snags() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for giant_index: int in EmberwoodSurface.GIANTS.size():
		var giant: Vector2i = EmberwoodSurface.GIANTS[giant_index]
		var top_row: int = BackdropPaint.row(SNAG_TOP_ROWS[giant_index])
		var snag: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(giant.x - 30, top_row - 30, giant.y + 60, BackdropPaint.STRIP_HEIGHT - top_row + 36))
		snag.add_rect(Rect2i(giant.x, top_row, giant.y, BackdropPaint.STRIP_HEIGHT - top_row + 6))
		var splinter_count: int = giant.y / 6
		for splinter: int in splinter_count:
			var splinter_x: float = giant.x + 3.0 + splinter * 6.0
			var splinter_height: float = 6.0 + BackdropPaint.random01(splinter, giant_index, 7331) * 20.0
			snag.add_line(Vector2(splinter_x, top_row + 4.0), Vector2(splinter_x + 1.0, top_row - splinter_height), 5.0)
		var limb_side: float = -1.0 if giant_index % 2 == 0 else 1.0
		var limb_start: Vector2 = Vector2(giant.x + giant.y * 0.5, top_row + 26.0)
		snag.add_line(limb_start, limb_start + Vector2(limb_side * (giant.y * 0.5 + 16.0), -12.0), 6.0)
		BackdropTerrain.roughen(snag, 7332 + giant_index)
		BackdropTerrain.paint(image, snag, CHAR, 3.0, 10.0, 1, 7332 + giant_index)
		for ember_index: int in EMBERS_PER_SNAG:
			var spot: Vector2 = _ember_spot(giant_index * EMBERS_PER_SNAG + ember_index)
			BackdropPaint.put_rect(image, Rect2i(roundi(spot.x), roundi(spot.y), 2, 1 + ember_index % 2), EmberwoodStyle.FRONT_EMBER)
	return image


## Where ember `ember_index` glows in its snag (strip px; EMBERS_PER_SNAG per giant).
static func _ember_spot(ember_index: int) -> Vector2:
	var giant_index: int = ember_index / EMBERS_PER_SNAG
	var giant: Vector2i = EmberwoodSurface.GIANTS[giant_index]
	var across: float = 4.0 + BackdropPaint.random01(ember_index, 1, 7336) * (giant.y - 8.0)
	var down: float = 8.0 + BackdropPaint.random01(ember_index, 2, 7336) * 50.0
	return Vector2(giant.x + across, BackdropPaint.row(SNAG_TOP_ROWS[giant_index]) + down)


## Each ember in the snags glows, out of step with the others.
static func draw_ember_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for ember_index: int in EmberwoodSurface.GIANTS.size() * EMBERS_PER_SNAG:
		var pulse: float = 0.5 + 0.5 * sin(time * 1.2 + ember_index * 1.9)
		BackdropTheme.draw_glow(layer, _ember_spot(ember_index) + Vector2(copy_x + 1.0, 0.0), 8.0, EmberwoodStyle.LAVA_GLOW, pulse)


## Right in front, at the edges: black crags rising from below and a charred
## dead tree, embers still glowing in its cracks.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_crag(image, 36.0, 28.0, 104.0, EmberwoodStyle.FRONT_BODY, EmberwoodStyle.FRONT_LIT, EmberwoodStyle.CONE_RIM, 7341)
	BackdropPaint.paint_crag(image, 70.0, 16.0, 62.0, EmberwoodStyle.FRONT_BODY, EmberwoodStyle.FRONT_LIT, EmberwoodStyle.CONE_RIM, 7342)
	EmberwoodStyle.paint_dead_tree(image, Vector2(470.0, BackdropPaint.STRIP_HEIGHT), 130.0, 0.14, 7343)
	return image

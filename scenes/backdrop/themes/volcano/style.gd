class_name VolcanoStyle
extends RefCounted
## VolcanoStyle: what the three VOLCANO looks (themes/volcano/*.gd) share, so they
## read as one mountain of fire seen from three heights. Not a node: static
## painters and colors.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer):
##   Sky       a dark starry sky high up, reddening down to an ash-red glow at the
##             surface's horizon, with a dim sun low down
##   Volcano   the great cone: its crater erupts in the skyline's view, high above
##             the ash; its flanks, lava running down them, rise out of the
##             surface's view; its plume of ash leans away downwind
##   AshBank   the ash cloud between the two: dark tops (the skyline looks down on
##             them) and an underside glowing red from the lava (the surface looks
##             up at it)
## Each altitude adds nearer layers and a FOREGROUND (charred dead trees, black rock
## spires, obsidian) right in front.
## The surface and the skyline share EVERY layer, the nearer ones too
## (add_shared_layers, at the end; the ones only one of them paints are split
## layers, BackdropTheme.add_split_layer), so the soft change between them is one
## picture scrolling on: nothing appears or vanishes at the seam.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "volcano"

const SKY_BANDS: Array[Color] = [Color(0.04, 0.03, 0.08), Color(0.06, 0.04, 0.1), Color(0.09, 0.05, 0.12),
	Color(0.13, 0.06, 0.12), Color(0.18, 0.08, 0.12), Color(0.25, 0.1, 0.11), Color(0.34, 0.13, 0.1),
	Color(0.46, 0.18, 0.1)]
const STAR_COLOR: Color = Color(0.9, 0.8, 0.85)
const SUN_COLOR: Color = Color(0.68, 0.3, 0.17)

const CONE_BODY: Color = Color(0.15, 0.07, 0.1)
const CONE_LIT: Color = Color(0.23, 0.1, 0.12)
const CONE_RIM: Color = Color(0.5, 0.19, 0.1)
const LAVA: Color = Color(1.0, 0.5, 0.12)
const LAVA_CORE: Color = Color(1.0, 0.8, 0.4)
const ASH_BODY: Color = Color(0.17, 0.12, 0.14)
const ASH_LIT: Color = Color(0.28, 0.19, 0.2)
const ASH_GLOW: Color = Color(0.45, 0.16, 0.1)

const BANK_BODY: Color = Color(0.2, 0.11, 0.12)
const BANK_TOP: Color = Color(0.32, 0.17, 0.17)
const BANK_UNDERGLOW: Color = Color(0.46, 0.15, 0.09)

## The black basalt of the slopes: the surface's ground, and the rock the magma
## chamber breaks through (BackdropTheme.crust_colors).
const GROUND_BODY: Color = Color(0.09, 0.05, 0.07)
const GROUND_RIM: Color = Color(0.52, 0.17, 0.08)
const FRONT_BODY: Color = Color(0.035, 0.02, 0.03)
const FRONT_LIT: Color = Color(0.08, 0.04, 0.05)
const FRONT_EMBER: Color = Color(0.9, 0.35, 0.1)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## The crater: strip x, and the skyline's screen row of its lip.
const CRATER_X: int = 210
const CRATER_SCREEN_ROW: int = 92


static func paint_sky(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(150, BackdropTheme.SURFACE_SECTION))
	for star_index: int in 70:
		var x: int = roundi(BackdropPaint.random01(star_index, 1, 2021) * BackdropPaint.STRIP_WIDTH)
		var depth: float = BackdropPaint.random01(star_index, 2, 2021)
		BackdropPaint.blend_pixel(tall, x, BackdropPaint.tall_row(depth * depth * 100.0, BackdropTheme.SKYLINE_SECTION),
			Color(STAR_COLOR, 0.25 + BackdropPaint.random01(star_index, 3, 2021) * 0.5))
	BackdropPaint.put_circle(tall, Vector2(520.0, BackdropPaint.tall_row(64, BackdropTheme.SURFACE_SECTION)), 11.0, SUN_COLOR)


## The cone, its lava flows and its plume (see the header).
static func paint_volcano(tall: Image) -> void:
	var crater_row: float = BackdropPaint.tall_row(CRATER_SCREEN_ROW, BackdropTheme.SKYLINE_SECTION)
	var tops: PackedFloat32Array = BackdropPaint.flat_line(tall.get_height() + 4.0)
	BackdropPaint.cone(tops, CRATER_X, crater_row, BackdropPaint.tall_row(165, BackdropTheme.SURFACE_SECTION), 11.0, 300.0, 1822)
	BackdropPaint.paint_mountains(tall, tops, CONE_BODY, CONE_LIT, CONE_RIM, CONE_RIM, CONE_RIM, -100, 50.0, 1823)
	# Lava flows: wandering lines from the crater lip far down the flanks.
	for flow_index: int in 5:
		var side: float = -1.0 if flow_index % 2 == 0 else 1.0
		var x: float = CRATER_X + side * (4.0 + flow_index * 2.0)
		var length: int = 110 + roundi(BackdropPaint.random01(flow_index, 1, 1824) * 160.0)
		for step: int in length:
			x += side * (0.5 + BackdropPaint.random01(flow_index, step, 1825) * 0.6) * (1.0 - float(step) / length * 0.4)
			var y: int = ceili(tops[posmod(roundi(x), BackdropPaint.STRIP_WIDTH)]) + 2
			BackdropPaint.put_rect(tall, Rect2i(roundi(x), y, 2, 1), LAVA)
			if step < length * 0.5:
				BackdropPaint.put_pixel(tall, roundi(x), y, LAVA_CORE)
	BackdropPaint.put_rect(tall, Rect2i(CRATER_X - 9, roundi(crater_row), 19, 2), LAVA)
	# The plume: billows of ash rising from the crater, leaning downwind; the
	# lowest glow red from the crater under them.
	for puff_index: int in 9:
		var center: Vector2 = Vector2(CRATER_X + puff_index * puff_index * 1.6, crater_row - 8.0 - puff_index * 11.0)
		BackdropPaint.paint_puff(tall, center, 8.0 + puff_index * 2.5, ASH_GLOW if puff_index < 2 else ASH_BODY, ASH_LIT, puff_index + 2024)


## The ash cloud between the two views (see the header).
static func paint_ash_bank(tall: Image) -> void:
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.tall_row(132, BackdropTheme.SKYLINE_SECTION), Vector2(6.0, 15.0), 13, 2031)
	var under_base: float = BackdropPaint.tall_row(24, BackdropTheme.SURFACE_SECTION)
	var undersides: PackedFloat32Array = BackdropPaint.bumps(under_base, Vector2(6.0, 13.0), 15, 2032)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		var bottom: int = roundi(2.0 * under_base - undersides[x])
		for y: int in range(top, bottom + 1):
			var color: Color = BANK_BODY
			if y < top + 2:
				color = BANK_TOP
			elif y > bottom - 3 or (y > bottom - 16 and BackdropPaint.checker(x, y)):
				color = BANK_UNDERGLOW
			BackdropPaint.put_pixel(tall, x, y, color)


## A charred dead tree for a foreground: a black trunk from `foot` leaning a
## little, bare branches forking off it, and embers glowing in its cracks.
static func paint_dead_tree(image: Image, foot: Vector2, height: float, lean: float, seed_value: int) -> void:
	var top: Vector2 = foot + Vector2(lean * height, -height)
	BackdropPaint.put_line(image, foot, top, FRONT_BODY, 5)
	BackdropPaint.put_line(image, foot + Vector2(-2.0, 0.0), top + Vector2(-2.0, 0.0), FRONT_LIT)
	for branch: int in 6:
		var along: float = 0.35 + branch * 0.11
		var start: Vector2 = foot.lerp(top, along)
		var side: float = -1.0 if branch % 2 == 0 else 1.0
		var length: float = (30.0 - branch * 3.0) * (0.7 + BackdropPaint.random01(branch, 1, seed_value) * 0.6)
		var end: Vector2 = start + Vector2(side * length, -length * 0.55)
		BackdropPaint.put_line(image, start, end, FRONT_BODY, 2)
		# A twig off each branch.
		BackdropPaint.put_line(image, start.lerp(end, 0.6), start.lerp(end, 0.6) + Vector2(side * 6.0, -8.0), FRONT_BODY)
	for ember: int in 5:
		var spot: Vector2 = foot.lerp(top, 0.1 + BackdropPaint.random01(ember, 2, seed_value) * 0.7)
		BackdropPaint.put_rect(image, Rect2i(roundi(spot.x) - 1, roundi(spot.y), 2, 1 + ember % 2), FRONT_EMBER)


## Adds every layer of the surface and the skyline, far to near, to `theme`
## showing `section`: both call this, so their layers, scrolls and order are the
## same and the soft change between them is one picture scrolling on. A layer only
## one of them paints is a split layer (BackdropTheme.add_split_layer): in the
## other it sits just off the screen and scrolls in with everything else.
static func add_shared_layers(theme: BackdropTheme, section: int) -> void:
	var skyline: int = BackdropTheme.SKYLINE_SECTION
	var surface: int = BackdropTheme.SURFACE_SECTION
	# add_split_layer(..., section, drift px/s, {section: moving things}, [sections
	# that fade out at the seam instead of ending in a straight cut]).
	theme.add_tall_layer(NAME, "Sky", Vector2(0.01, 0.0), paint_sky, section)
	var cone: BackdropLayer = theme.add_tall_layer(NAME, "Volcano", Vector2(0.03, 0.01), paint_volcano, section)
	cone.draw_extra = BackdropTheme.section_extras({skyline: VolcanoSkyline.draw_eruption}, section)
	theme.add_tall_layer(NAME, "AshBank", Vector2(0.08, 0.03), paint_ash_bank, section, 2.0)
	theme.add_split_layer(NAME, "Ridges", Vector2(0.14, 0.05), {surface: VolcanoSurface.paint_ridges}, section)
	theme.add_split_layer(NAME, "AshClouds", Vector2(0.2, 0.07), {skyline: VolcanoSkyline.paint_ash_clouds}, section, 6.0)
	theme.add_split_layer(NAME, "LavaRiver", Vector2(0.24, 0.08), {surface: VolcanoSurface.paint_river}, section, 0.0,
		{surface: VolcanoSurface.draw_river_flow})
	# The skyline's crater rim and the surface's near rock: one layer of near ground.
	theme.add_split_layer(NAME, "NearRock", Vector2(0.42, 0.13), {skyline: VolcanoSkyline.paint_crater_rim,
		surface: VolcanoSurface.paint_near_rock}, section, 0.0,
		{skyline: VolcanoSkyline.draw_crack_glow, surface: VolcanoSurface.draw_crack_glow}, [skyline])
	theme.add_split_layer(NAME, "Front", FRONT_SCROLL, {skyline: VolcanoSkyline.paint_front, surface: VolcanoSurface.paint_front}, section, 0.0, {}, [skyline])

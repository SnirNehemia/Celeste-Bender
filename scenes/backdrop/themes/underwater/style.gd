class_name UnderwaterStyle
extends RefCounted
## UnderwaterStyle: what the three UNDERWATER looks (themes/underwater/*.gd)
## share: one column of sea from the surface down to the abyss, so the three read
## as one dive, and every change between them is SOFT (Backdrop.SOFT_UNDERGROUND_LOOKS:
## there's no ground to break through, only deeper water). Not a node: static
## painters and colors.
##
## TALL layers over ALL THREE altitudes (BackdropPaint header):
##   Water   the dusk sky above the waterline (skyline only), then water from
##           bright teal just under the surface to near black in the abyss
##   Spires  rock towers rising from the abyss: their feet in the deep, their
##           peaks just under the surface in the skyline's view
## and light RAYS from the waterline that reach down into the dark, fading
## (draw_rays, drawn live by each look for its own slice).
## Each altitude adds nearer layers and a FOREGROUND of big kelp blades, sea fans or
## tube worms right in front.
## The surface and the skyline share EVERY layer, the nearer ones too
## (add_shared_layers, at the end; the ones only one of them paints are split
## layers, BackdropTheme.add_split_layer), so the soft change between them is one
## picture scrolling on: nothing appears or vanishes at the seam.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "underwater"

## The waterline, as a screen row of the skyline.
const WATERLINE_SCREEN_ROW: int = 64
const SKY_BANDS: Array[Color] = [Color(0.16, 0.2, 0.36), Color(0.26, 0.28, 0.44), Color(0.4, 0.37, 0.5),
	Color(0.56, 0.47, 0.52), Color(0.7, 0.56, 0.5)]
## From just under the waterline down to the abyss floor.
const WATER_BANDS: Array[Color] = [Color(0.15, 0.4, 0.48), Color(0.13, 0.36, 0.45), Color(0.11, 0.31, 0.41),
	Color(0.09, 0.27, 0.37), Color(0.07, 0.22, 0.32), Color(0.06, 0.17, 0.27), Color(0.04, 0.13, 0.21),
	Color(0.03, 0.09, 0.16), Color(0.02, 0.06, 0.11), Color(0.015, 0.04, 0.08), Color(0.01, 0.03, 0.06)]
const SUN_COLOR: Color = Color(0.95, 0.75, 0.5)

const SPIRE_BODY: Color = Color(0.05, 0.15, 0.22)
const SPIRE_LIT: Color = Color(0.08, 0.21, 0.29)
const SPIRE_RIM: Color = Color(0.12, 0.28, 0.35)
const RAY_COLOR: Color = Color(0.65, 0.92, 1.0, 0.07)

const FRONT_BODY: Color = Color(0.01, 0.05, 0.07)
const FRONT_LIT: Color = Color(0.03, 0.1, 0.12)
const FRONT_RIB: Color = Color(0.04, 0.12, 0.13)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)
## The giant kelp in front (paint_giant_kelp): x = strip x of the root, y = length
## from the reef up (px), z = lean.
const GIANT_KELP: Array[Vector3] = [Vector3(64.0, 330.0, 0.04), Vector3(420.0, 300.0, -0.03)]

## The rays: how many per strip, and down to which screen row of the
## underground they reach (fading all the way).
const RAY_COUNT: int = 5
const RAY_END_UNDERGROUND_ROW: int = 60


static func paint_water(tall: Image) -> void:
	var waterline: int = BackdropPaint.tall_row(WATERLINE_SCREEN_ROW, BackdropTheme.SKYLINE_SECTION)
	BackdropPaint.paint_bands(tall, WATER_BANDS, waterline, BackdropPaint.tall_row(170, BackdropTheme.UNDERGROUND_SECTION))
	var sky: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(sky, SKY_BANDS, 0, waterline)
	tall.blit_rect(sky, Rect2i(0, 0, BackdropPaint.STRIP_WIDTH, waterline), Vector2i.ZERO)
	# A sun about to touch the sea, and its glittering path on the water below it.
	var sun_center: Vector2 = Vector2(250.0, waterline - 8)
	BackdropPaint.put_circle(tall, sun_center, 13.0, SUN_COLOR)
	for y: int in range(waterline, waterline + 26, 2):
		var half_width: int = 10 - (y - waterline) / 4
		for x: int in range(250 - half_width, 250 + half_width):
			if (x + y / 2) % 3 != 0:
				BackdropPaint.blend_pixel(tall, x, y, Color(SUN_COLOR, 0.5))


## Rock towers from the abyss floor up toward the surface.
static func paint_spires(tall: Image) -> void:
	var octaves: Array[Vector2] = [Vector2(120.0, 230.0), Vector2(40.0, 60.0), Vector2(11.0, 8.0)]
	var tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.tall_row(180, BackdropTheme.UNDERGROUND_SECTION), octaves, 81, true)
	BackdropPaint.paint_mountains(tall, tops, SPIRE_BODY, SPIRE_LIT, SPIRE_RIM, SPIRE_RIM, SPIRE_RIM, 0, 30.0, 81)
	# Deeper down the rock fades into the dark with the water around it: from the
	# surface's middle on, every 24 rows a step darker (lit faces and rims too).
	var dark_from: int = BackdropPaint.tall_row(90, BackdropTheme.SURFACE_SECTION)
	for y: int in range(dark_from, tall.get_height()):
		var darkness: float = minf(0.75, floorf((y - dark_from) / 24.0) * 0.1)
		for x: int in BackdropPaint.STRIP_WIDTH:
			var rock: Color = tall.get_pixel(x, y)
			if rock.a > 0.0:
				tall.set_pixel(x, y, rock.darkened(darkness))


## The light rays for a draw_extra in `section`'s slice: wide, faint, swaying,
## from the waterline down into the deep, fainter the deeper (drawn in four
## pieces, each fainter than the one above).
static func draw_rays(layer: BackdropLayer, copy_x: float, time: float, section: int) -> void:
	var offset: float = section * BackdropPaint.SCREEN_HEIGHT
	var top: float = BackdropPaint.tall_row(WATERLINE_SCREEN_ROW, BackdropTheme.SKYLINE_SECTION) + 2.0 - offset
	var bottom: float = BackdropPaint.tall_row(RAY_END_UNDERGROUND_ROW, BackdropTheme.UNDERGROUND_SECTION) - offset
	for ray_index: int in RAY_COUNT:
		var top_x: float = copy_x + ray_index * 128.0 + 30.0
		var sway: float = sin(time * 0.35 + ray_index * 1.3) * 10.0
		var breathing: float = 0.6 + 0.4 * sin(time * 0.5 + ray_index * 2.1)
		var top_width: float = 16.0 + ray_index % 3 * 8.0
		for piece: int in 4:
			var from: float = float(piece) / 4.0
			var to: float = float(piece + 1) / 4.0
			var from_y: float = lerpf(top, bottom, from)
			var to_y: float = lerpf(top, bottom, to)
			if to_y < -10.0 or from_y > BackdropPaint.STRIP_HEIGHT + 10.0:
				continue  # not in this slice
			# The ray widens and leans as it goes down.
			var lean: float = 90.0 + sway
			layer.draw_colored_polygon(PackedVector2Array([
				Vector2(top_x + lean * from, from_y), Vector2(top_x + top_width * (1.0 + 2.0 * from) + lean * from, from_y),
				Vector2(top_x + top_width * (1.0 + 2.0 * to) + lean * to, to_y), Vector2(top_x + lean * to, to_y)]),
				Color(RAY_COLOR, RAY_COLOR.a * breathing * (1.0 - from * 0.8)))


## A big kelp plant for foregrounds: a thin stalk from `base` going up `length`
## px, swaying a little, with long narrow blades on alternate sides all the way
## up and a round float at each blade's foot.
static func paint_kelp_blade(image: Image, base: Vector2, length: float, lean: float, seed_value: int) -> void:
	var point: Vector2 = base
	var steps: int = roundi(length)
	for step: int in steps:
		var along: float = float(step) / steps
		var heading: float = -PI * 0.5 + lean + sin(along * 5.0 + seed_value) * 0.25
		var next: Vector2 = point + Vector2(cos(heading), sin(heading))
		BackdropPaint.put_line(image, point, next, FRONT_BODY, 2)
		if step % 9 == 4 and along < 0.95:
			var side: float = 1.0 if (step / 9) % 2 == 0 else -1.0
			var blade_length: float = 16.0 + BackdropPaint.random01(step, 1, seed_value) * 12.0
			BackdropPaint.paint_leaf(image, next, heading + side * 0.7, blade_length, 3.0, side * 0.6, FRONT_BODY, FRONT_LIT, FRONT_RIB)
			BackdropPaint.put_circle(image, next + Vector2(side * 2.0, 0.0), 1.5, FRONT_LIT)
		point = next



## The giant kelp right in front (the Front layer): GIANT_KELP plants rooted on
## the reef below the surface's screen, reaching all the way up through it to the
## sea's surface in the skyline. Each altitude paints its own strip of the same
## plants (`section`: whose strip; the root is a screen further down from the
## skyline's), so the soft change between them scrolls up the same stalks.
static func paint_giant_kelp(image: Image, section: int) -> void:
	# The root is at the bottom of the surface's strip; the skyline's strip starts a
	# screen higher up, so there the same root is a screen further down.
	var root_row: float = BackdropPaint.STRIP_HEIGHT + (BackdropTheme.SURFACE_SECTION - section) * BackdropPaint.SCREEN_HEIGHT
	for plant: Vector3 in GIANT_KELP:
		paint_kelp_blade(image, Vector2(plant.x, root_row), plant.y, plant.z, int(plant.x))

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
	theme.add_tall_layer(NAME, "Water", Vector2(0.01, 0.0), paint_water, section)
	theme.add_split_layer(NAME, "Islands", Vector2(0.04, 0.0), {skyline: UnderwaterSkyline.paint_islands}, section)
	# The rays already run on from one altitude's water into the next.
	theme.add_drawn_layer("Rays", Vector2(0.06, 0.0), func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		draw_rays(layer, copy_x, time, section))
	theme.add_tall_layer(NAME, "Spires", Vector2(0.07, 0.0), paint_spires, section)
	theme.add_split_layer(NAME, "Seabed", Vector2(0.18, 0.07), {surface: UnderwaterSurface.paint_seabed}, section, 0.0,
		{surface: UnderwaterSurface.draw_mid_kelp})
	theme.add_split_layer(NAME, "Waterline", Vector2(0.3, 0.0), {}, section, 0.0, {skyline: UnderwaterSkyline.draw_surface})
	theme.add_split_layer(NAME, "Coral", Vector2(0.4, 0.12), {surface: UnderwaterSurface.paint_coral}, section, 0.0,
		{surface: UnderwaterSurface.draw_near_kelp})
	theme.add_split_layer(NAME, "Front", FRONT_SCROLL, {skyline: UnderwaterSkyline.paint_front, surface: UnderwaterSurface.paint_front}, section)

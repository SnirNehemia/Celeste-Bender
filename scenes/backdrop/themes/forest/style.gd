class_name ForestStyle
extends RefCounted
## ForestStyle: what the three FOREST looks (themes/forest/*.gd) share, so they
## read as one forest seen from three heights. Not a node: static painters and
## colors.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer):
##   Sky     one sunset: dusky blue high up, warming to gold at the surface's
##           horizon, where the low sun sits behind the trees
##   Canopy  the forest roof between the two: the skyline looks down on its
##           crowns, with three giant trees standing above the rest; the surface
##           looks up at its dark underside and at the giants' trunks going up
##           into it
## Each altitude adds nearer layers, and a FOREGROUND of big dark leaves and ferns
## (BackdropPaint.paint_leaf_clump, paint_frond) right in front.
## The surface and the skyline share EVERY layer, the nearer ones too
## (add_shared_layers, at the end; the ones only one of them paints are split
## layers, BackdropTheme.add_split_layer), so the soft change between them is one
## picture scrolling on: nothing appears or vanishes at the seam.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "forest"

const SKY_BANDS: Array[Color] = [Color(0.1, 0.14, 0.26), Color(0.13, 0.18, 0.3), Color(0.18, 0.22, 0.32),
	Color(0.25, 0.26, 0.33), Color(0.33, 0.3, 0.32), Color(0.41, 0.34, 0.3), Color(0.49, 0.39, 0.27),
	Color(0.56, 0.43, 0.24), Color(0.62, 0.47, 0.24)]
const SUN_COLOR: Color = Color(0.9, 0.7, 0.38)
const SUN_RING: Color = Color(0.72, 0.55, 0.3)
const CLOUD_BODY: Color = Color(0.45, 0.38, 0.38)
const CLOUD_LIT: Color = Color(0.66, 0.54, 0.44)
const CLOUD_SHADE: Color = Color(0.36, 0.31, 0.34)

const CANOPY_BODY: Color = Color(0.13, 0.19, 0.13)
const CANOPY_LIT: Color = Color(0.22, 0.29, 0.17)
const CANOPY_RIM: Color = Color(0.32, 0.37, 0.2)
const CANOPY_UNDER: Color = Color(0.09, 0.13, 0.1)
const TRUNK: Color = Color(0.1, 0.13, 0.1)
const TRUNK_LIT: Color = Color(0.16, 0.2, 0.13)

## The near trunks and ground: the surface's front, and the rock and soil the
## underground breaks through (BackdropTheme.crust_colors).
const GROUND_BODY: Color = Color(0.05, 0.08, 0.06)
const GROUND_RIM: Color = Color(0.1, 0.14, 0.08)
const FRONT_BODY: Color = Color(0.025, 0.045, 0.03)
const FRONT_LIT: Color = Color(0.07, 0.11, 0.06)
const FRONT_RIB: Color = Color(0.1, 0.15, 0.07)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## The giant trees: strip x of the trunk, half width, and the crown's top (screen
## row in the skyline).
const GIANTS: Array[Vector3] = [Vector3(110.0, 6.0, 92.0), Vector3(330.0, 8.0, 76.0), Vector3(520.0, 5.0, 104.0)]


static func paint_sky(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(135, BackdropTheme.SURFACE_SECTION))
	# High soft clouds in the skyline's sky.
	for cloud_index: int in 5:
		var center: Vector2 = Vector2((cloud_index + 0.4) * BackdropPaint.STRIP_WIDTH / 5.0,
			BackdropPaint.tall_row(26 + (cloud_index % 3) * 24, BackdropTheme.SKYLINE_SECTION))
		BackdropPaint.paint_cloud(tall, center, 16.0 + (cloud_index % 2) * 10.0, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 813)
	# The low sun, in the surface's sky.
	var sun_center: Vector2 = Vector2(200.0, BackdropPaint.tall_row(104, BackdropTheme.SURFACE_SECTION))
	BackdropPaint.put_circle(tall, sun_center, 26.0, SUN_RING)
	BackdropPaint.put_circle(tall, sun_center, 19.0, SUN_COLOR)


## The canopy band with the giant trees (see the header).
static func paint_canopy(tall: Image) -> void:
	var seam: float = BackdropPaint.tall_row(0, BackdropTheme.SURFACE_SECTION)
	# The giants first, so the canopy's crowns overlap their lower trunks.
	for giant: Vector3 in GIANTS:
		var crown_top: float = BackdropPaint.tall_row(giant.z, BackdropTheme.SKYLINE_SECTION)
		var trunk_bottom: int = BackdropPaint.tall_row(190, BackdropTheme.SURFACE_SECTION)
		BackdropPaint.put_rect(tall, Rect2i(roundi(giant.x - giant.y), roundi(crown_top), roundi(giant.y * 2.0) + 1,
			trunk_bottom - roundi(crown_top)), TRUNK)
		BackdropPaint.put_rect(tall, Rect2i(roundi(giant.x - giant.y), roundi(crown_top), 2, trunk_bottom - roundi(crown_top)), TRUNK_LIT)
		# A few branches off the trunk in the surface's view, up into the dark.
		for branch: int in 3:
			var branch_row: float = BackdropPaint.tall_row(16 + branch * 26, BackdropTheme.SURFACE_SECTION)
			var side: float = -1.0 if branch % 2 == 0 else 1.0
			BackdropPaint.put_line(tall, Vector2(giant.x, branch_row + 14.0), Vector2(giant.x + side * (18.0 + branch * 4.0), branch_row), TRUNK, 2)
		# The crown: many round clumps, lit on their upper left.
		for clump_index: int in 12:
			var clump: Vector2 = Vector2(giant.x + (BackdropPaint.random01(int(giant.x), clump_index, 831) - 0.5) * 46.0,
				crown_top + 8.0 + BackdropPaint.random01(int(giant.x), clump_index + 20, 831) * 34.0)
			var radius: float = 6.0 + BackdropPaint.random01(int(giant.x), clump_index + 40, 831) * 6.0
			BackdropPaint.put_circle(tall, clump + Vector2(-1.0, -1.0), radius, CANOPY_RIM)
			BackdropPaint.put_circle(tall, clump, radius - 1.0, CANOPY_LIT)
			BackdropPaint.put_circle(tall, clump + Vector2(1.0, 2.0), radius - 2.0, CANOPY_BODY)
	# The canopy: crowns on top (the skyline's view) down to a hanging underside
	# (the surface's), the inside darkening toward the underside.
	var tops: PackedFloat32Array = BackdropPaint.bumps(seam - 34.0, Vector2(8.0, 15.0), 13, 832)
	var undersides: PackedFloat32Array = BackdropPaint.bumps(seam + 16.0, Vector2(8.0, 18.0), 16, 833)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		var bottom: int = roundi(2.0 * (seam + 16.0) - undersides[x])
		for y: int in range(top, bottom + 1):
			var color: Color = CANOPY_BODY
			if y < top + 2:
				color = CANOPY_RIM if y == top else CANOPY_LIT
			elif y > bottom - 14 and (y > bottom - 6 or BackdropPaint.checker(x, y)):
				color = CANOPY_UNDER
			BackdropPaint.put_pixel(tall, x, y, color)


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
	theme.add_split_layer(NAME, "FarCanopy", Vector2(0.04, 0.02), {skyline: ForestSkyline.paint_far_canopy}, section, 0.0, {}, [skyline])
	theme.add_split_layer(NAME, "FarTrees", Vector2(0.06, 0.03), {surface: ForestSurface.paint_far_trees}, section)
	theme.add_tall_layer(NAME, "Canopy", Vector2(0.15, 0.06), paint_canopy, section)
	theme.add_split_layer(NAME, "MidForest", Vector2(0.16, 0.07), {surface: ForestSurface.paint_mid_forest}, section)
	theme.add_split_layer(NAME, "Shafts", Vector2(0.22, 0.08), {}, section, 0.0, {surface: ForestSurface.draw_shafts})
	# The surface's near trunks go up into the skyline's big branch: one layer.
	theme.add_split_layer(NAME, "NearTrees", Vector2(0.42, 0.13), {skyline: ForestSkyline.paint_branch,
		surface: ForestSurface.paint_near_trees}, section, 0.0, {}, [skyline, surface])
	theme.add_split_layer(NAME, "Front", FRONT_SCROLL, {skyline: ForestSkyline.paint_front, surface: ForestSurface.paint_front}, section, 0.0, {}, [skyline])

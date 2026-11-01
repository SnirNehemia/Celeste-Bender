class_name ShoreStyle
extends RefCounted
## ShoreStyle: what the three SHORE looks (themes/shore/*.gd) share, so they read
## as one coast on one bright day. Not a node: static painters and colors.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer):
##   SkyAndSea  the same blue sky and open sea seen twice: from the cliff top (the
##              skyline: horizon high, sea far below) and from the beach (the
##              surface); the change from one to the other is hidden in the cloud
##              bank between them
##   CloudBank  low white clouds over the sea: the cliff top looks down on their
##              tops, the beach up at their shaded undersides
## The sea cave (underground) looks out at the same sky and sea through its arches.
## Each altitude adds nearer layers and a FOREGROUND (palm fronds, dune grass,
## seaweed-hung rock) right in front.
## The surface and the skyline share EVERY layer, the nearer ones too
## (add_shared_layers, at the end; the ones only one of them paints are split
## layers, BackdropTheme.add_split_layer), so the soft change between them is one
## picture scrolling on: nothing appears or vanishes at the seam.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "shore"

const SKY_BANDS: Array[Color] = [Color(0.3, 0.5, 0.76), Color(0.38, 0.58, 0.8), Color(0.48, 0.66, 0.84),
	Color(0.6, 0.75, 0.86), Color(0.74, 0.84, 0.88)]
## The open sea, darker toward the horizon's far side, lighter near the shore.
const SEA_BANDS: Array[Color] = [Color(0.2, 0.42, 0.62), Color(0.18, 0.46, 0.63), Color(0.17, 0.51, 0.63),
	Color(0.19, 0.57, 0.63), Color(0.23, 0.63, 0.64)]
const HORIZON_LINE: Color = Color(0.55, 0.72, 0.82)

const CLOUD_BODY: Color = Color(0.86, 0.9, 0.93)
const CLOUD_LIT: Color = Color(0.98, 0.98, 0.98)
const CLOUD_SHADE: Color = Color(0.72, 0.8, 0.88)

## The horizon in each view (screen rows).
const SKYLINE_HORIZON_SCREEN_ROW: int = 104
const SURFACE_HORIZON_SCREEN_ROW: int = 96

## The dunes behind the beach: the surface's front, and the sand the sea cave
## breaks through (BackdropTheme.crust_colors).
const DUNE_BODY: Color = Color(0.6, 0.5, 0.36)
const DUNE_LIT: Color = Color(0.74, 0.63, 0.45)
const FRONT_BODY: Color = Color(0.08, 0.17, 0.14)
const FRONT_LIT: Color = Color(0.15, 0.28, 0.2)
const FRONT_ROCK: Color = Color(0.06, 0.07, 0.09)
const FRONT_ROCK_LIT: Color = Color(0.14, 0.17, 0.2)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)


## One sky over one sea, painted for the skyline's view and again for the
## surface's (see the header).
static func paint_sky_and_sea(tall: Image) -> void:
	for section: int in [BackdropTheme.SURFACE_SECTION, BackdropTheme.SKYLINE_SECTION]:
		var horizon_screen_row: int = SKYLINE_HORIZON_SCREEN_ROW if section == BackdropTheme.SKYLINE_SECTION else SURFACE_HORIZON_SCREEN_ROW
		var horizon: int = BackdropPaint.tall_row(horizon_screen_row, section)
		var view: Image = BackdropPaint.new_strip()
		BackdropPaint.paint_bands(view, SEA_BANDS, BackdropPaint.row(horizon_screen_row), BackdropPaint.row(170))
		var sky: Image = BackdropPaint.new_strip()
		BackdropPaint.paint_bands(sky, SKY_BANDS, BackdropPaint.row(-10), BackdropPaint.row(horizon_screen_row))
		view.blit_rect(sky, Rect2i(0, 0, BackdropPaint.STRIP_WIDTH, BackdropPaint.row(horizon_screen_row)), Vector2i.ZERO)
		view.fill_rect(Rect2i(0, BackdropPaint.row(horizon_screen_row), BackdropPaint.STRIP_WIDTH, 1), HORIZON_LINE)
		# The skyline's view is pasted on top (painted last), but only down to its
		# screen's bottom: under that the surface's own sky goes on (its spare rows),
		# and the cloud bank hides where the two meet.
		var rows: int = BackdropPaint.row(BackdropPaint.SCREEN_HEIGHT - 5) if section == BackdropTheme.SKYLINE_SECTION else BackdropPaint.STRIP_HEIGHT
		tall.blit_rect(view, Rect2i(0, 0, BackdropPaint.STRIP_WIDTH, rows), Vector2i(0, horizon - BackdropPaint.row(horizon_screen_row)))
		if section == BackdropTheme.SURFACE_SECTION:
			# Below the surface's slice, more sea (the cave's arches look out on it).
			var below: int = horizon - BackdropPaint.row(horizon_screen_row) + BackdropPaint.STRIP_HEIGHT
			tall.fill_rect(Rect2i(0, below, BackdropPaint.STRIP_WIDTH, tall.get_height() - below), SEA_BANDS[SEA_BANDS.size() - 1])


## The low cloud bank between the two views.
static func paint_cloud_bank(tall: Image) -> void:
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.tall_row(140, BackdropTheme.SKYLINE_SECTION), Vector2(7.0, 15.0), 13, 1731)
	var under_base: float = BackdropPaint.tall_row(24, BackdropTheme.SURFACE_SECTION)
	var undersides: PackedFloat32Array = BackdropPaint.bumps(under_base, Vector2(6.0, 12.0), 15, 1732)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		var bottom: int = roundi(2.0 * under_base - undersides[x])
		for y: int in range(top, bottom + 1):
			var color: Color = CLOUD_BODY
			if y < top + 2:
				color = CLOUD_LIT
			elif y > bottom - 2 or (y > bottom - 12 and BackdropPaint.checker(x, y)):
				color = CLOUD_SHADE
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
	var sky: BackdropLayer = theme.add_tall_layer(NAME, "SkyAndSea", Vector2(0.01, 0.0), paint_sky_and_sea, section)
	sky.draw_extra = BackdropTheme.section_extras({surface: ShoreSurface.draw_glitter}, section)
	theme.add_split_layer(NAME, "Clouds", Vector2(0.03, 0.0), {surface: ShoreSurface.paint_clouds}, section, 3.0)
	theme.add_split_layer(NAME, "SeaStacks", Vector2(0.03, 0.0), {skyline: ShoreSkyline.paint_sea_stacks}, section, 0.0,
		{skyline: ShoreSkyline.draw_stack_foam})
	theme.add_tall_layer(NAME, "CloudBank", Vector2(0.05, 0.0), paint_cloud_bank, section, 4.0)
	theme.add_split_layer(NAME, "Island", Vector2(0.04, 0.0), {surface: ShoreSurface.paint_island}, section)
	theme.add_split_layer(NAME, "Headland", Vector2(0.14, 0.0), {surface: ShoreSurface.paint_headland}, section, 0.0,
		{surface: ShoreSurface.draw_surf})
	theme.add_split_layer(NAME, "Beach", Vector2(0.28, 0.08), {surface: ShoreSurface.paint_beach}, section, 0.0,
		{surface: ShoreSurface.draw_waves})
	theme.add_split_layer(NAME, "CliffTop", Vector2(0.42, 0.13), {skyline: ShoreSkyline.paint_cliff_top}, section, 0.0,
		{skyline: ShoreSkyline.draw_lighthouse_beam}, [skyline])
	theme.add_split_layer(NAME, "Palms", Vector2(0.45, 0.14), {surface: ShoreSurface.paint_palms}, section)
	theme.add_split_layer(NAME, "Front", FRONT_SCROLL, {skyline: ShoreSkyline.paint_front, surface: ShoreSurface.paint_front}, section, 0.0, {}, [skyline])

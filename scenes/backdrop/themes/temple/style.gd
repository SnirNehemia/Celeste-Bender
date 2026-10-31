class_name TempleStyle
extends RefCounted
## TempleStyle: what the three TEMPLE looks (themes/temple/*.gd) share, so they
## read as one temple: its hall, its roofs above, its catacombs below. Not a
## node: static painters and colors.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer):
##   Sky     one dusk: dark blue high up to a warm glow low down, where the big low
##           sun shows through the hall's open arcade
##   Towers  distant tiered pagodas standing on the cloud sea (seen from the roofs)
##   Clouds  that sea of cloud: the roofs look down on its tops, the hall's arcade
##           looks out under its hanging underside; a few puffs higher up
##   Roof    the hall's own roof: from above, tiles down to the eave; from inside,
##           the rafters and beams overhead
## Each look adds nearer layers and a FOREGROUND (a hanging lantern, chains, a
## great column) right in front.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "temple"

const SKY_BANDS: Array[Color] = [Color(0.08, 0.1, 0.19), Color(0.11, 0.14, 0.24), Color(0.16, 0.18, 0.28),
	Color(0.23, 0.22, 0.31), Color(0.32, 0.27, 0.33), Color(0.43, 0.33, 0.34), Color(0.54, 0.39, 0.35),
	Color(0.63, 0.45, 0.36)]
const SUN_COLOR: Color = Color(0.92, 0.66, 0.42)
const SUN_RING: Color = Color(0.72, 0.5, 0.37)

const TOWER_BODY: Color = Color(0.27, 0.22, 0.3)
const TOWER_LIT: Color = Color(0.36, 0.28, 0.34)

const CLOUD_BODY: Color = Color(0.46, 0.36, 0.4)
const CLOUD_LIT: Color = Color(0.64, 0.5, 0.46)
const CLOUD_SHADE: Color = Color(0.36, 0.28, 0.34)

const ROOF_BODY: Color = Color(0.1, 0.07, 0.11)
const ROOF_LIT: Color = Color(0.2, 0.13, 0.17)
const ROOF_TILE_LINE: Color = Color(0.06, 0.04, 0.07)

## The hall's stone: the floor in front, and the rock the catacombs break
## through (BackdropTheme.crust_colors).
const STONE_BODY: Color = Color(0.07, 0.06, 0.1)
const STONE_LIT: Color = Color(0.13, 0.11, 0.17)
const FRONT_BODY: Color = Color(0.035, 0.03, 0.05)
const FRONT_LIT: Color = Color(0.09, 0.07, 0.11)
const LANTERN_COLOR: Color = Color(0.8, 0.32, 0.2)
const LANTERN_LIGHT: Color = Color(1.0, 0.72, 0.4)
const LANTERN_GLOW: Color = Color(1.0, 0.55, 0.25, 0.07)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## The roof's eave: the skyline's screen row of its edge; it curls up at every
## section corner, ROOF_SECTION px apart.
const EAVE_SCREEN_ROW: int = 150
const ROOF_SECTION: int = 160
## The rafters seen from inside: how far down the surface's screen they reach.
const RAFTERS_SCREEN_ROW: int = 14


static func paint_sky(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(135, BackdropTheme.SURFACE_SECTION))
	var sun_center: Vector2 = Vector2(420.0, BackdropPaint.tall_row(104, BackdropTheme.SURFACE_SECTION))
	BackdropPaint.put_circle(tall, sun_center, 30.0, SUN_RING)
	BackdropPaint.put_circle(tall, sun_center, 23.0, SUN_COLOR)


## Distant towers on the cloud sea: tiers of roofs getting smaller toward the
## top, each roof wider than the walls under it with tips curling up, a spire.
static func paint_towers(tall: Image) -> void:
	for tower_index: int in 4:
		var center_x: int = roundi((tower_index + 0.2 + BackdropPaint.random01(tower_index, 1, 721) * 0.6) * BackdropPaint.STRIP_WIDTH / 4.0)
		var tier_count: int = 3 + roundi(BackdropPaint.random01(tower_index, 2, 721) * 3.0)
		var y: int = BackdropPaint.tall_row(156, BackdropTheme.SKYLINE_SECTION)
		var half_width: int = 16
		for tier_index: int in tier_count:
			var wall_height: int = 9
			BackdropPaint.put_rect(tall, Rect2i(center_x - half_width + 3, y - wall_height, (half_width - 3) * 2, wall_height), TOWER_BODY)
			y -= wall_height
			BackdropPaint.put_rect(tall, Rect2i(center_x - half_width - 2, y - 3, half_width * 2 + 4, 3), TOWER_BODY)
			BackdropPaint.put_rect(tall, Rect2i(center_x - half_width - 2, y - 3, half_width * 2 + 4, 1), TOWER_LIT)
			BackdropPaint.put_pixel(tall, center_x - half_width - 3, y - 4, TOWER_BODY)
			BackdropPaint.put_pixel(tall, center_x + half_width + 2, y - 4, TOWER_BODY)
			y -= 3
			half_width = maxi(5, half_width - 3)
		BackdropPaint.put_rect(tall, Rect2i(center_x, y - 10, 1, 10), TOWER_BODY)


## The cloud sea: billowy tops in the skyline, a hanging underside in the
## surface's view through the arcade; and puffs high up.
static func paint_clouds(tall: Image) -> void:
	var tops: PackedFloat32Array = BackdropPaint.bumps(BackdropPaint.tall_row(146, BackdropTheme.SKYLINE_SECTION), Vector2(5.0, 12.0), 11, 731)
	var under_base: float = BackdropPaint.tall_row(30, BackdropTheme.SURFACE_SECTION)
	var undersides: PackedFloat32Array = BackdropPaint.bumps(under_base, Vector2(5.0, 11.0), 14, 734)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		var bottom: int = roundi(2.0 * under_base - undersides[x])
		for y: int in range(top, bottom + 1):
			var color: Color = CLOUD_BODY
			if y < top + 2:
				color = CLOUD_LIT
			elif y > bottom - 2 or (y > bottom - 10 and BackdropPaint.checker(x, y)):
				color = CLOUD_SHADE
			BackdropPaint.put_pixel(tall, x, y, color)
	for cloud_index: int in 4:
		var center: Vector2 = Vector2((cloud_index + 0.5) * BackdropPaint.STRIP_WIDTH / 4.0,
			BackdropPaint.tall_row(50 + cloud_index % 2 * 30, BackdropTheme.SKYLINE_SECTION))
		BackdropPaint.paint_cloud(tall, center, 18.0 + cloud_index % 3 * 6.0, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, cloud_index + 732)


## The hall's roof (see the header): tiles from the curled eave down to where the
## skyline ends, then, from inside, a dark band of roof with beams and rafter ends.
static func paint_roof(tall: Image) -> void:
	var eave_row: int = BackdropPaint.tall_row(EAVE_SCREEN_ROW, BackdropTheme.SKYLINE_SECTION)
	var inside_bottom: int = BackdropPaint.tall_row(RAFTERS_SCREEN_ROW, BackdropTheme.SURFACE_SECTION)
	for x: int in BackdropPaint.STRIP_WIDTH:
		# The eave curls up toward every section's corner.
		var along: float = float(posmod(x, ROOF_SECTION)) / ROOF_SECTION
		var top: int = roundi(eave_row - pow(absf(along * 2.0 - 1.0), 6.0) * 10.0) - 6
		tall.fill_rect(Rect2i(x, top, 1, inside_bottom - top), ROOF_BODY)
		tall.set_pixel(x, top, ROOF_LIT)
		# Rows of tiles: a lit lip and a dark groove every few px.
		for y: int in range(top + 4, inside_bottom - 12, 6):
			tall.set_pixel(x, y, ROOF_TILE_LINE)
			if x % 6 == 0:
				tall.fill_rect(Rect2i(x, y, 1, 6), ROOF_TILE_LINE)
	# Inside: a beam along the bottom, rafter ends sticking out under it.
	tall.fill_rect(Rect2i(0, inside_bottom - 6, BackdropPaint.STRIP_WIDTH, 1), ROOF_LIT)
	tall.fill_rect(Rect2i(0, inside_bottom - 1, BackdropPaint.STRIP_WIDTH, 1), ROOF_TILE_LINE)
	for x: int in range(4, BackdropPaint.STRIP_WIDTH, 16):
		BackdropPaint.put_rect(tall, Rect2i(x, inside_bottom, 6, 5), ROOF_BODY)
		BackdropPaint.put_rect(tall, Rect2i(x, inside_bottom, 6, 1), ROOF_LIT)


## A big lantern hanging on a chain from above the screen, swinging slowly, for
## a draw_extra: the chain, the lantern's frame and its flickering light.
static func draw_big_lantern(layer: BackdropLayer, anchor: Vector2, chain_length: float, time: float) -> void:
	var swing: float = sin(time * 0.9 + anchor.x) * 0.06
	var body: Vector2 = (anchor + Vector2(sin(swing), cos(swing)) * chain_length).round()
	for link: int in roundi(chain_length / 4.0):
		var point: Vector2 = anchor.lerp(body, link * 4.0 / chain_length).round()
		layer.draw_rect(Rect2(point + Vector2(-1.0 if link % 2 == 0 else 0.0, 0.0), Vector2(2.0 if link % 2 == 0 else 1.0, 3.0)), FRONT_LIT)
	var flicker: float = 0.85 + 0.1 * sin(time * 7.0 + anchor.x) + 0.05 * sin(time * 19.0)
	BackdropTheme.draw_glow(layer, body + Vector2(0.0, 12.0), 34.0, LANTERN_GLOW, flicker)
	layer.draw_rect(Rect2(body + Vector2(-9.0, 0.0), Vector2(19.0, 3.0)), FRONT_BODY)
	layer.draw_rect(Rect2(body + Vector2(-8.0, 3.0), Vector2(17.0, 18.0)), LANTERN_COLOR.darkened(0.3))
	layer.draw_rect(Rect2(body + Vector2(-6.0, 4.0), Vector2(13.0, 16.0)), Color(LANTERN_LIGHT, flicker))
	for rib: float in [-3.0, 1.0, 5.0]:
		layer.draw_rect(Rect2(body + Vector2(rib, 3.0), Vector2(1.0, 18.0)), FRONT_BODY)
	layer.draw_rect(Rect2(body + Vector2(-9.0, 21.0), Vector2(19.0, 3.0)), FRONT_BODY)
	layer.draw_rect(Rect2(body + Vector2(0.0, 24.0), Vector2(1.0, 6.0)), LANTERN_COLOR)

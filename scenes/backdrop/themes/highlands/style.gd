class_name HighlandsStyle
extends RefCounted
## HighlandsStyle: what the three HIGHLANDS looks (themes/highlands/*.gd) share,
## so they read as one green valley on a bright midday, seen from three heights:
## down among its meadows (underground.gd), from platforms floating over its
## hills (surface.gd), and up among the cliffs that wall it in (skyline.gd). The
## Air chapter's look. Not a node: static painters, colors and helpers.
##
## Painted in the style of our GROUND (BackdropTerrain): hills are swells of turf
## (a bright grassy crust, a hatched green inside), cliffs are rock with grass on
## top. There is no ground to break through here (the "underground" is the
## valley's floor, under the same sky), so every change between the three is
## SOFT (Backdrop.SOFT_UNDERGROUND_LOOKS) and the tall layers run over all three.
##
## TALL layers over ALL THREE altitudes (BackdropPaint header, add_tall_layers):
##   Sky       midday blue, deepest at the top of the skyline, palest at the
##             horizon behind the hills; below the horizon the valley's green
##   Clouds    a few white fair-weather clouds, drifting
##   Cliffs    far rock massifs stepping down in terraces, cracked sheer faces:
##             their grassy tops crisp in the skyline, their lower flanks sinking
##             into the valley's haze (sink_into_haze) behind the surface's hills
##   Hill0..3  four swells of turf, far to near (HILL_BASE_ROWS), each a few big
##             soft waves with a tree here and there; the nearest runs on down
##             into the valley floor, behind the underground's meadows
## The surface and the skyline share EVERY layer, the nearer ones too
## (add_shared_layers, at the end; the ones only one of them paints are split
## layers, BackdropTheme.add_split_layer), so the soft change between them is one
## picture scrolling on: nothing appears or vanishes at the seam. Those layers,
## far to near: Peaks (the skyline's sheer near cliffs, cabins on top, chimney
## smoke), Islands (floating islands in both), Near (the surface's meadow swell,
## the skyline's cliff edge with a cabin), Haze (a bank of mist over the seam
## between the two, hiding where the skyline's cliffs fade out; a tall layer),
## Front (grass and broad leaves rising in the surface, boughs hanging in the
## skyline: neither reaches the seam).
## Painters shared with the altitude scripts: hill_tops, paint_swell,
## sink_into_haze, paint_tree, paint_cabin + cabin_chimney + draw_smoke,
## paint_islands, paint_fence, add_pillar, paint_cracks, paint_grass_tuft.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "highlands"

## Top of the skyline down to the horizon.
const SKY_BANDS: Array[Color] = [Color(0.22, 0.47, 0.84), Color(0.27, 0.53, 0.87), Color(0.33, 0.59, 0.9),
	Color(0.4, 0.65, 0.92), Color(0.48, 0.71, 0.93), Color(0.56, 0.77, 0.94), Color(0.64, 0.82, 0.95),
	Color(0.71, 0.87, 0.95), Color(0.78, 0.91, 0.95)]
## The horizon, as a screen row of the surface: the sky's bands end here.
const HORIZON_SURFACE_ROW: int = 130
## The pale blue haze far things fade into.
const AIR: Color = Color(0.76, 0.9, 0.95)
## Under the horizon, behind everything: far meadow green.
const VALLEY_BACK: Color = Color(0.5, 0.74, 0.5)

const CLOUD_BODY: Color = Color(0.93, 0.96, 0.99)
const CLOUD_LIT: Color = Color(1.0, 1.0, 1.0)
const CLOUD_SHADE: Color = Color(0.74, 0.85, 0.95)
## Each cloud: Vector4(strip x, section, screen row in that section, half width).
const CLOUDS: Array[Vector4] = [Vector4(60.0, 0.0, 34.0, 38.0), Vector4(250.0, 0.0, 78.0, 26.0),
	Vector4(430.0, 0.0, 22.0, 46.0), Vector4(560.0, 0.0, 120.0, 30.0), Vector4(150.0, 0.0, 150.0, 22.0),
	Vector4(350.0, 1.0, 22.0, 40.0), Vector4(40.0, 1.0, 58.0, 24.0), Vector4(540.0, 1.0, 50.0, 32.0),
	Vector4(200.0, 1.0, 84.0, 30.0), Vector4(460.0, 1.0, 100.0, 22.0)]

## Turf, rock, earth and leaves in the ground's style: [crust, rim, edge, inside,
## hatch, deep]. Sunny: the insides stay green, not the near-black of a cave's.
const TURF: Array[Color] = [Color(0.42, 0.72, 0.3), Color(0.66, 0.88, 0.42), Color(0.2, 0.47, 0.22),
	Color(0.26, 0.55, 0.26), Color(0.3, 0.6, 0.28), Color(0.19, 0.44, 0.24)]
## The cliffs: pale rock whose RIM is grass (every top is a meadow).
const ROCK: Array[Color] = [Color(0.72, 0.68, 0.6), Color(0.58, 0.82, 0.4), Color(0.42, 0.4, 0.4),
	Color(0.5, 0.49, 0.5), Color(0.56, 0.54, 0.54), Color(0.4, 0.4, 0.45)]
## Floating islands: brown earth under a grass rim.
const EARTH: Array[Color] = [Color(0.62, 0.5, 0.36), Color(0.6, 0.85, 0.4), Color(0.36, 0.27, 0.2),
	Color(0.45, 0.35, 0.26), Color(0.5, 0.4, 0.3), Color(0.34, 0.27, 0.22)]
const LEAVES: Array[Color] = [Color(0.3, 0.6, 0.26), Color(0.55, 0.82, 0.36), Color(0.13, 0.36, 0.18),
	Color(0.16, 0.42, 0.2), Color(0.2, 0.48, 0.22), Color(0.1, 0.3, 0.17)]
const BARK: Color = Color(0.36, 0.27, 0.2)
## Roots hanging under floating islands.
const ROOT_COLOR: Color = Color(0.4, 0.32, 0.24)
## A floating island is built of tiles this many px wide (BackdropTerrain.add_chunk).
const ISLAND_TILE: int = 6
## Cracks down a rock face: a shade of the rock's inside.
const CRACK_COLOR: Color = Color(0.36, 0.35, 0.38)
## Cabins: log walls, a red-brown shingle roof lit on the left, a warm window, a
## stone chimney; chimney smoke (draw_smoke).
const LOG: Color = Color(0.58, 0.4, 0.25)
const LOG_DARK: Color = Color(0.44, 0.29, 0.18)
const LOG_LIT: Color = Color(0.7, 0.52, 0.34)
## Brown shingles, not red (art pass: red is kept for what kills you, BACKDROP_GUIDE.md §2).
const ROOF: Color = Color(0.46, 0.31, 0.24)
const ROOF_LIT: Color = Color(0.62, 0.44, 0.33)
const ROOF_EAVE: Color = Color(0.3, 0.2, 0.16)
const WINDOW: Color = Color(1.0, 0.88, 0.5)
const DOOR: Color = Color(0.28, 0.18, 0.12)
const CHIMNEY: Color = Color(0.5, 0.48, 0.48)
const SMOKE: Color = Color(0.95, 0.96, 0.98, 0.5)
## Fences: posts and two rails.
const FENCE_COLOR: Color = Color(0.5, 0.4, 0.3)
const FENCE_LIT: Color = Color(0.68, 0.58, 0.44)
const BLADES: Array[Color] = [Color(0.66, 0.88, 0.42), Color(0.52, 0.8, 0.36), Color(0.76, 0.92, 0.5)]
const FLOWERS: Array[Color] = [Color(1.0, 1.0, 0.95), Color(1.0, 0.9, 0.4), Color(1.0, 0.72, 0.8)]

## The foreground: tall grass and leafy boughs, dark against the bright valley.
const FRONT_BODY: Color = Color(0.07, 0.2, 0.13)
const FRONT_LIT: Color = Color(0.13, 0.32, 0.16)
const FRONT_RIB: Color = Color(0.17, 0.38, 0.18)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## The four hills, far to near. Each one's lowest point (a screen row of the
## surface), how high its big waves rise above that (px), its haze, how many
## trees stand on it and their crown radius (px).
const HILL_BASE_ROWS: Array[int] = [128, 144, 160, 178]
const HILL_WAVE_HEIGHTS: Array[float] = [26.0, 34.0, 40.0, 46.0]
## How many waves each hill has along the strip, and where its first one starts
## (radians): different per hill, so the crests of one stand in the dips of the next.
const HILL_WAVE_COUNTS: Array[int] = [3, 2, 3, 2]
const HILL_WAVE_PHASES: Array[float] = [0.5, 2.4, 4.0, 5.6]
const HILL_HAZES: Array[float] = [0.68, 0.52, 0.36, 0.22]
const HILL_TREE_COUNTS: Array[int] = [0, 3, 3, 2]
const HILL_TREE_RADII: Array[float] = [0.0, 4.0, 6.0, 8.0]
const HILL_SCROLLS: Array[Vector2] = [Vector2(0.06, 0.02), Vector2(0.09, 0.03), Vector2(0.13, 0.04), Vector2(0.18, 0.06)]
## Small ripples ride on a hill's big waves: this many px long, this share of
## the waves' height.
const HILL_RIPPLE_LENGTH: float = 128.0
const HILL_RIPPLE_SHARE: float = 0.2
## How many rows of a far hill are painted under its lowest point: the next hill
## covers the rest.
const HILL_DEPTH: int = 70

## The far cliffs. Each massif: Vector3(strip x of its middle, half width, the
## screen row of the SKYLINE its top is at).
const CLIFF_MASSIFS: Array[Vector3] = [Vector3(90.0, 60.0, 58.0), Vector3(300.0, 40.0, 96.0), Vector3(480.0, 70.0, 40.0)]
## The cliffs' own haze (their summits), and how much more they sink into the
## valley's haze toward their feet (sink_into_haze): from nothing at
## CLIFF_SINK_FROM_SKYLINE_ROW down to all of it at the horizon.
const CLIFF_HAZE: float = 0.45
const CLIFF_SINK: float = 0.6
const CLIFF_SINK_FROM_SKYLINE_ROW: int = 70
## The mist bank over the skyline/surface seam (paint_seam_mist): how far it
## reaches above and below the seam (px), and its dithered edge.
const MIST: Color = Color(0.9, 0.95, 0.98, 0.8)
const MIST_THIN: Color = Color(0.9, 0.95, 0.98, 0.45)
const MIST_ABOVE_SEAM: int = 26
const MIST_BELOW_SEAM: int = 6
const MIST_DITHER_ROWS: int = 3
## Haze added in this many hard steps (bands, never a smooth gradient).
const HAZE_STEPS: int = 6
## Cracks per massif down its faces.
const CLIFF_CRACKS: int = 14
## A massif steps down on each side in terraces: where each one starts (share of
## the half width), and the least and most each steps down (px).
const CLIFF_STEP_STARTS: Array[float] = [0.36, 0.6, 0.82]
const CLIFF_STEP_DROPS: Vector2 = Vector2(34.0, 78.0)
## The cliffs' band ends at this screen row of the surface: behind the far hill.
const CLIFF_FOOT_SURFACE_ROW: int = 156


## `color` pulled `amount` toward the haze: further away.
static func far(color: Color, amount: float) -> Color:
	return color.lerp(AIR, amount)


## The sky (see the header), and the valley's green under the horizon.
static func paint_sky(tall: Image) -> void:
	var horizon: int = BackdropPaint.tall_row(HORIZON_SURFACE_ROW, BackdropTheme.SURFACE_SECTION)
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION), horizon)
	tall.fill_rect(Rect2i(0, horizon, BackdropPaint.STRIP_WIDTH, tall.get_height() - horizon), VALLEY_BACK)


## The clouds (CLOUDS), on their own see-through layer so they can drift.
static func paint_clouds(tall: Image) -> void:
	for cloud_index: int in CLOUDS.size():
		var cloud: Vector4 = CLOUDS[cloud_index]
		var center: Vector2 = Vector2(cloud.x, BackdropPaint.tall_row(cloud.z, int(cloud.y)))
		BackdropPaint.paint_cloud(tall, center, cloud.w, CLOUD_BODY, CLOUD_LIT, CLOUD_SHADE, 8171 + cloud_index)


## Paints a swell of ground in the ground's style: solid from `tops` (a row per
## strip column) down to `bottom_row`, and returns its mask (for grass blades).
## Only the band near its top is painted in the ground's style (slow); below
## that it's all the palette's DEEP color, filled in one go. Painting the whole
## swell made the look take 4 s to load.
static func paint_swell(image: Image, tops: PackedFloat32Array, bottom_row: int, palette: Array[Color],
		crust_width: float, fade: float, rim_rows: int, seed_value: int) -> BackdropTerrain.Mask:
	var top_row: int = bottom_row
	var lowest_top: int = 0
	for top: float in tops:
		top_row = mini(top_row, floori(top))
		lowest_top = maxi(lowest_top, ceili(top))
	# How deep the crust and its fade reach in from any edge: past that, every
	# pixel is plain DEEP.
	var covered_rows: int = ceili(crust_width + BackdropTerrain.CRUST_WOBBLE + fade) + 3
	# Only the band where the top's crust and fade are goes through the (slow)
	# painter; the rest is filled with DEEP in one call. A mask's bottom edge gets
	# a crust too, so the band reaches a covered_rows further, painted over below.
	var painted_to: int = mini(bottom_row, lowest_top + covered_rows * 2)
	var swell: BackdropTerrain.Mask = BackdropTerrain.new_band(top_row - 2, painted_to)
	swell.add_below(tops)
	BackdropTerrain.paint(image, swell, palette, crust_width, fade, rim_rows, seed_value)
	var deep_from: int = painted_to - covered_rows
	var deep_to: int = mini(bottom_row, image.get_height())
	if deep_to > deep_from:
		image.fill_rect(Rect2i(0, deep_from, BackdropPaint.STRIP_WIDTH, deep_to - deep_from), palette[BackdropTerrain.DEEP])
	return swell


## A small round tree standing at `foot` (its trunk sinks a little below it, so
## paint the ground it stands on afterwards): a crown of three leafy clumps,
## `radius` px the biggest, on a short trunk.
static func paint_tree(image: Image, foot: Vector2, radius: float, haze: float, seed_value: int) -> void:
	var trunk_height: int = roundi(radius * 1.3)
	var trunk_width: int = maxi(1, roundi(radius * 0.3))
	BackdropPaint.put_rect(image, Rect2i(roundi(foot.x) - trunk_width / 2, roundi(foot.y) - trunk_height, trunk_width, trunk_height + 4),
		far(BARK, haze))
	var crown_middle: Vector2 = foot + Vector2(0.0, -trunk_height - radius * 0.5)
	var clumps: Array[Vector3] = [Vector3(crown_middle.x, crown_middle.y, radius),
		Vector3(crown_middle.x - radius * 0.75, crown_middle.y + radius * 0.4, radius * 0.7),
		Vector3(crown_middle.x + radius * 0.8, crown_middle.y + radius * 0.5, radius * 0.65)]
	var reach: int = ceili(radius * 2.0) + 2
	var crown: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(roundi(crown_middle.x) - reach, roundi(crown_middle.y) - reach, reach * 2, reach * 2))
	for clump: Vector3 in clumps:
		crown.add_circle(Vector2(clump.x, clump.y), clump.z)
	var leaves: Array[Color] = BackdropTerrain.hazed(LEAVES, AIR, haze)
	BackdropTerrain.paint(image, crown, leaves, clampf(radius * 0.3, 1.5, 3.0), radius * 0.8, 1, seed_value)


## The line of a hill's top: `wave_count` big soft waves along the strip (a sine,
## so every wave is a full one; noise gave flat stretches), the first starting
## at `phase` radians, `wave_height` px high, with small ripples riding on them.
## Never below `base_row`.
static func hill_tops(base_row: float, wave_height: float, wave_count: int, phase: float, seed_value: int) -> PackedFloat32Array:
	var tops: PackedFloat32Array = PackedFloat32Array()
	tops.resize(BackdropPaint.STRIP_WIDTH)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var wave: float = 0.5 + 0.5 * sin(TAU * wave_count * x / BackdropPaint.STRIP_WIDTH + phase)
		var ripple: float = BackdropPaint.periodic_noise(x, HILL_RIPPLE_LENGTH, seed_value)
		tops[x] = base_row - wave_height * (wave * (1.0 - HILL_RIPPLE_SHARE) + ripple * HILL_RIPPLE_SHARE)
	return tops


## One hill (HILL_BASE_ROWS[row_index]): its trees, then the turf over their feet,
## then grass and a few flowers along its top.
static func paint_hill(tall: Image, row_index: int) -> void:
	var haze: float = HILL_HAZES[row_index]
	var seed_value: int = 8110 + row_index * 10
	var base_row: int = BackdropPaint.tall_row(HILL_BASE_ROWS[row_index], BackdropTheme.SURFACE_SECTION)
	var tops: PackedFloat32Array = hill_tops(base_row, HILL_WAVE_HEIGHTS[row_index], HILL_WAVE_COUNTS[row_index],
		HILL_WAVE_PHASES[row_index], seed_value)
	for tree_index: int in HILL_TREE_COUNTS[row_index]:
		# One tree per equal stretch of the strip, anywhere inside its stretch.
		var stretch: float = float(BackdropPaint.STRIP_WIDTH) / HILL_TREE_COUNTS[row_index]
		var tree_x: int = roundi((tree_index + 0.15 + BackdropPaint.random01(tree_index, 1, seed_value) * 0.7) * stretch)
		var radius: float = HILL_TREE_RADII[row_index] * (0.8 + BackdropPaint.random01(tree_index, 2, seed_value) * 0.5)
		paint_tree(tall, Vector2(tree_x, tops[posmod(tree_x, BackdropPaint.STRIP_WIDTH)]), radius, haze, seed_value + tree_index)
	# The nearest hill is the valley's floor too: solid to past the picture's end.
	var is_nearest: bool = row_index == HILL_BASE_ROWS.size() - 1
	var bottom_row: int = tall.get_height() + 40 if is_nearest else base_row + HILL_DEPTH
	var turf: Array[Color] = BackdropTerrain.hazed(TURF, AIR, haze)
	var hill: BackdropTerrain.Mask = paint_swell(tall, tops, bottom_row, turf, 3.0 + row_index * 0.6, 14.0, 1 + row_index / 2, seed_value)
	BackdropTerrain.paint_blades(tall, hill, BackdropTerrain.hazed(BLADES, AIR, haze), 3, 1 + row_index, seed_value + 1)
	if row_index >= 1:
		BackdropTerrain.paint_blades(tall, hill, BackdropTerrain.hazed(FLOWERS, AIR, haze), 22 - row_index * 3, 1, seed_value + 2)


## The far cliffs (CLIFF_MASSIFS): each a narrow summit of rock with sheer faces,
## stepping down on each side in terraces (CLIFF_STEP_STARTS), grass on every top.
static func paint_cliffs(tall: Image) -> void:
	var foot_row: int = BackdropPaint.tall_row(CLIFF_FOOT_SURFACE_ROW, BackdropTheme.SURFACE_SECTION)
	# No cliff: a top below the band, which add_below leaves as open air.
	var tops: PackedFloat32Array = BackdropPaint.flat_line(foot_row + 10.0)
	for massif_index: int in CLIFF_MASSIFS.size():
		var massif: Vector3 = CLIFF_MASSIFS[massif_index]
		var top_row: float = BackdropPaint.tall_row(massif.z, BackdropTheme.SKYLINE_SECTION)
		for dx: int in range(-ceili(massif.y), ceili(massif.y) + 1):
			var side: int = 0 if dx < 0 else 1
			# Every terrace this column is past adds its own drop (its own per side).
			var step_down: float = 0.0
			for step_index: int in CLIFF_STEP_STARTS.size():
				var step_start: float = CLIFF_STEP_STARTS[step_index] + (BackdropPaint.random01(massif_index, step_index * 2 + side, 8150) - 0.5) * 0.12
				if absf(dx) / massif.y > step_start:
					step_down += lerpf(CLIFF_STEP_DROPS.x, CLIFF_STEP_DROPS.y, BackdropPaint.random01(massif_index, step_index * 2 + side, 8151))
			# A slow noise along the top: uneven, but no bricks (BACKDROP_GUIDE.md §9).
			var wander: float = (BackdropPaint.periodic_noise(massif.x + dx, 40.0, 8152) - 0.5) * 8.0
			var column: int = posmod(roundi(massif.x) + dx, BackdropPaint.STRIP_WIDTH)
			tops[column] = minf(tops[column], top_row + step_down + wander)
	var top_limit: int = foot_row
	for top: float in tops:
		top_limit = mini(top_limit, floori(top))
	var cliffs: BackdropTerrain.Mask = BackdropTerrain.new_band(top_limit - 2, foot_row)
	cliffs.add_below(tops)
	BackdropTerrain.roughen(cliffs, 8153)
	var rock: Array[Color] = BackdropTerrain.hazed(ROCK, AIR, CLIFF_HAZE)
	BackdropTerrain.paint(tall, cliffs, rock, 4.0, 14.0, 2, 8153)
	BackdropTerrain.paint_blades(tall, cliffs, BackdropTerrain.hazed(BLADES, AIR, CLIFF_HAZE), 3, 2, 8154)
	paint_cracks(tall, cliffs, far(CRACK_COLOR, CLIFF_HAZE), CLIFF_CRACKS * CLIFF_MASSIFS.size(), 8155)
	# Lower down, deeper into the valley's haze: the surface sees pale flanks, not
	# grey slabs, and the skyline crisp summits.
	sink_into_haze(tall, BackdropPaint.tall_row(CLIFF_SINK_FROM_SKYLINE_ROW, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(HORIZON_SURFACE_ROW, BackdropTheme.SURFACE_SECTION), CLIFF_SINK)


## Pulls every painted pixel of `image` toward the haze (AIR), more the lower it
## is: nothing above `from_row`, `amount` from `to_row` down, in HAZE_STEPS hard
## steps between. One Image.blend_rect_mask call (in C++; a GDScript pixel loop
## would be slow), with the picture itself as the mask so the air around the
## rock stays see-through.
static func sink_into_haze(image: Image, from_row: int, to_row: int, amount: float) -> void:
	var overlay: Image = Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var step_height: float = float(to_row - from_row) / HAZE_STEPS
	for step: int in HAZE_STEPS:
		var top: int = from_row + roundi(step * step_height)
		var step_color: Color = Color(AIR, amount * (step + 1) / HAZE_STEPS)
		overlay.fill_rect(Rect2i(0, top, image.get_width(), image.get_height() - top), step_color)
		# One checker row above each step, like every band in a backdrop: without it
		# the steps were ruler lines across the cliffs, and a hazed cliff read as a
		# see-through box laid over the sky (art pass).
		if top > 0:
			for x: int in range(step % 2, image.get_width(), 2):
				overlay.set_pixel(x, top - 1, step_color)
	var mask: Image = image.duplicate() as Image
	image.blend_rect_mask(overlay, mask, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)


## A sheer pillar of rock (a near cliff) into `mask`: a flat top at `top_row`,
## `half_width` px each side of `center_x`, widening a little toward
## `bottom_row`. Its sides wander slowly down the height and step out now and
## then at a ledge (a slow noise plus rare steps reads as cliffs; random edges
## per row read as bricks, BACKDROP_GUIDE.md §9).
static func add_pillar(mask: BackdropTerrain.Mask, center_x: float, half_width: float, top_row: int, bottom_row: int,
		seed_value: int) -> void:
	const WANDER: float = 5.0
	const WANDER_CELL: float = 26.0
	const WIDENING: float = 0.3
	# Each side's ledge: the row it steps out at and how far (px).
	var ledge_rows: Array[float] = []
	var ledge_widths: Array[float] = []
	for side: int in 2:
		ledge_rows.append(lerpf(top_row, bottom_row, 0.25 + BackdropPaint.random01(side, 1, seed_value) * 0.4))
		ledge_widths.append(5.0 + BackdropPaint.random01(side, 2, seed_value) * 9.0)
	for y: int in range(top_row, bottom_row):
		var along: float = float(y - top_row) / maxf(1.0, bottom_row - top_row)
		var width_here: float = half_width * (1.0 + WIDENING * along)
		var left: float = center_x - width_here - (BackdropTerrain.noise_2d(center_x, y, WANDER_CELL, seed_value) - 0.5) * 2.0 * WANDER
		var right: float = center_x + width_here + (BackdropTerrain.noise_2d(center_x, y, WANDER_CELL, seed_value + 1) - 0.5) * 2.0 * WANDER
		if y > ledge_rows[0]:
			left -= ledge_widths[0]
		if y > ledge_rows[1]:
			right += ledge_widths[1]
		mask.add_rect(Rect2i(roundi(left), y, roundi(right - left), 1))


## `count` thin dark cracks running down the faces of the rock in `mask`, each
## starting a little under the top it falls from, jogging a px sideways now and
## then, and stopping where the rock does (they keep 3 px from any edge).
static func paint_cracks(image: Image, mask: BackdropTerrain.Mask, color: Color, count: int, seed_value: int) -> void:
	const EDGE_KEEP: int = 3
	const BELOW_TOP: int = 8
	for crack: int in count:
		var x: int = mask.origin.x + roundi(BackdropPaint.random01(crack, 1, seed_value) * (mask.size.x - 1))
		var y: int = mask.origin.y
		while y < mask.origin.y + mask.size.y and not mask.is_solid(x, y):
			y += 1
		y += BELOW_TOP + roundi(BackdropPaint.random01(crack, 2, seed_value) * 20.0)
		var length: int = 10 + roundi(BackdropPaint.random01(crack, 3, seed_value) * 40.0)
		for step: int in length:
			if not (mask.is_solid(x - EDGE_KEEP, y) and mask.is_solid(x + EDGE_KEEP, y) and mask.is_solid(x, y + EDGE_KEEP)):
				break
			BackdropPaint.put_pixel(image, x, y, color)
			if step % 6 == 5:
				x += 1 if BackdropPaint.random01(crack, step, seed_value) < 0.5 else -1
			y += 1


## A log cabin standing on `foot` (the middle of its floor), `width` px wide,
## pulled `haze` toward the air: log walls, a pitched shingle roof lit on the
## left, a door, a warm window, a stone chimney (cabin_chimney: where its smoke
## starts).
static func paint_cabin(image: Image, foot: Vector2, width: int, haze: float) -> void:
	var wall_height: int = maxi(4, roundi(width * 0.5))
	var left: int = roundi(foot.x) - width / 2
	var wall_top: int = roundi(foot.y) - wall_height
	# The chimney first: the roof covers its foot.
	var chimney: Vector2i = Vector2i(cabin_chimney(foot, width))
	BackdropPaint.put_rect(image, Rect2i(chimney.x, chimney.y, maxi(2, width / 8), wall_top - chimney.y + 1), far(CHIMNEY, haze))
	# Walls: a log every 2 rows, the lit left end.
	for y: int in range(wall_top, roundi(foot.y)):
		var log_color: Color = LOG if (y - wall_top) % 2 == 0 else LOG_DARK
		BackdropPaint.put_rect(image, Rect2i(left, y, width, 1), far(log_color, haze))
		BackdropPaint.put_pixel(image, left, y, far(LOG_LIT, haze))
	# The roof: a triangle over the walls, 2 px of eave each side.
	var roof_height: int = maxi(3, roundi(width * 0.42))
	for row_index: int in roof_height:
		var y: int = wall_top - roof_height + row_index
		var half: int = roundi((width / 2 + 2) * float(row_index + 1) / roof_height)
		var middle: int = roundi(foot.x)
		BackdropPaint.put_rect(image, Rect2i(middle - half, y, half, 1), far(ROOF_LIT, haze))
		BackdropPaint.put_rect(image, Rect2i(middle, y, half, 1), far(ROOF, haze))
	BackdropPaint.put_rect(image, Rect2i(left - 2, wall_top, width + 4, 1), far(ROOF_EAVE, haze))
	# A door on the right half, a window on the left.
	var door_height: int = maxi(2, wall_height - 2)
	BackdropPaint.put_rect(image, Rect2i(left + width * 2 / 3, roundi(foot.y) - door_height, maxi(1, width / 7), door_height), far(DOOR, haze))
	var window_size: int = maxi(1, width / 8)
	BackdropPaint.put_rect(image, Rect2i(left + width / 4, wall_top + 2, window_size, window_size), far(WINDOW, haze))


## Where the chimney of a cabin painted by paint_cabin(foot, width) has its top.
static func cabin_chimney(foot: Vector2, width: int) -> Vector2:
	var wall_height: int = maxi(4, roundi(width * 0.5))
	return Vector2(roundi(foot.x) + width / 4, roundi(foot.y) - wall_height - roundi(width * 0.42))


## Smoke puffing from chimney tops `chimneys` (strip px), for a draw_extra: a
## few puffs at a time, each rising and drifting with the wind, growing and
## fading as it goes.
static func draw_smoke(layer: BackdropLayer, copy_x: float, time: float, chimneys: Array[Vector2]) -> void:
	const PUFFS: int = 4
	const RISE: float = 24.0
	const DRIFT: float = 12.0
	for chimney_index: int in chimneys.size():
		for puff: int in PUFFS:
			var age: float = fposmod(time * 0.25 + float(puff) / PUFFS + chimney_index * 0.37, 1.0)
			var center: Vector2 = chimneys[chimney_index] + Vector2(copy_x + DRIFT * age * age, -RISE * age)
			layer.draw_circle(center.round(), 1.0 + age * 3.0, Color(SMOKE, SMOKE.a * (1.0 - age)))


## Floating islands: chunks of earth with grass on top and roots hanging under
## them, the kind of platform the level is made of. `islands`: Vector3i(left
## strip x, top screen row, width in tiles).
static func paint_islands(islands: Array[Vector3i], haze: float, seed_value: int) -> Image:
	var image: Image = BackdropPaint.new_strip()
	var palette: Array[Color] = BackdropTerrain.hazed(EARTH, AIR, haze)
	for island_index: int in islands.size():
		var island: Vector3i = islands[island_index]
		var top_row: int = BackdropPaint.row(island.y)
		var island_seed: int = seed_value + island_index
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(island.x - 2, top_row - ISLAND_TILE - 4,
			island.z * ISLAND_TILE + 4, ISLAND_TILE * 6))
		BackdropTerrain.add_chunk(mask, island.x, top_row, island.z, 3, ISLAND_TILE, island_seed)
		BackdropTerrain.roughen(mask, island_seed)
		BackdropTerrain.paint(image, mask, palette, 3.0, 8.0, 2, island_seed)
		BackdropTerrain.paint_blades(image, mask, BackdropTerrain.hazed(BLADES, AIR, haze), 2, 3, island_seed)
		BackdropTerrain.paint_hanging(image, mask, far(ROOT_COLOR, haze), 4, 10, far(BLADES[1], haze), 4, island_seed + 10)
	return image


## A fence following a ground's top `tops` from strip x `from_x` to `to_x`: a
## post every `post_every` px, two rails. `size` scales it (1: posts 9 px tall).
static func paint_fence(image: Image, tops: PackedFloat32Array, from_x: int, to_x: int, post_every: int, size: float,
		haze: float) -> void:
	var post_height: int = roundi(9.0 * size)
	for x: int in range(from_x, to_x):
		var top: int = ceili(tops[posmod(x, BackdropPaint.STRIP_WIDTH)])
		if (x - from_x) % post_every == 0:
			BackdropPaint.put_rect(image, Rect2i(x, top - post_height + 2, maxi(1, roundi(2.0 * size)), post_height), far(FENCE_COLOR, haze))
			BackdropPaint.put_pixel(image, x, top - post_height + 2, far(FENCE_LIT, haze))
		else:
			BackdropPaint.put_pixel(image, x, top - roundi(6.0 * size), far(FENCE_LIT, haze))
			BackdropPaint.put_pixel(image, x, top - roundi(3.0 * size), far(FENCE_COLOR, haze))


## A tuft of tall grass rising from `base` (foreground): long narrow blades
## fanned out, all bent the same way by the wind (to the right).
static func paint_grass_tuft(image: Image, base: Vector2, size: float, seed_value: int) -> void:
	const BLADE_COUNT: int = 9
	for blade: int in BLADE_COUNT:
		var along: float = float(blade) / (BLADE_COUNT - 1) - 0.5  # -0.5..0.5 across the fan
		var length: float = size * (0.55 + BackdropPaint.random01(blade, 1, seed_value) * 0.55)
		BackdropPaint.paint_leaf(image, base + Vector2(along * 22.0, 0.0), -PI * 0.5 + along * 0.8, length, 2.0 + size * 0.025,
			0.7 + BackdropPaint.random01(blade, 2, seed_value) * 0.5, FRONT_BODY, FRONT_LIT, FRONT_RIB)


## Adds the tall layers (see the header), far to near, to `theme` showing
## `section`. All three altitudes call this (the underground directly).
static func add_tall_layers(theme: BackdropTheme, section: int) -> void:
	theme.add_tall_layer(NAME, "Sky", Vector2(0.01, 0.0), paint_sky, section)
	theme.add_tall_layer(NAME, "Clouds", Vector2(0.02, 0.0), paint_clouds, section, 1.5)
	theme.add_tall_layer(NAME, "Cliffs", Vector2(0.04, 0.012), paint_cliffs, section)
	for row_index: int in HILL_BASE_ROWS.size():
		theme.add_tall_layer(NAME, "Hill%d" % row_index, HILL_SCROLLS[row_index], paint_hill.bind(row_index), section)


## Adds every layer of the surface and the skyline, far to near, to `theme`
## showing `section`: both call this, so their layers, scrolls and order are the
## same and the soft change between them is one picture scrolling on. A layer only
## one of them paints is a split layer (BackdropTheme.add_split_layer): in the
## other it sits just off the screen and scrolls in with everything else.
static func add_shared_layers(theme: BackdropTheme, section: int) -> void:
	var skyline: int = BackdropTheme.SKYLINE_SECTION
	var surface: int = BackdropTheme.SURFACE_SECTION
	add_tall_layers(theme, section)
	# add_split_layer(..., section, drift px/s, {section: moving things}, [sections
	# that fade out at the seam instead of ending in a straight cut]).
	theme.add_split_layer(NAME, "Peaks", Vector2(0.2, 0.07), {skyline: HighlandsSkyline.paint_peaks}, section, 0.0,
		{skyline: HighlandsSkyline.draw_peak_smoke}, [skyline])
	theme.add_split_layer(NAME, "Islands", Vector2(0.26, 0.09), {skyline: HighlandsSkyline.paint_islands,
		surface: HighlandsSurface.paint_islands}, section)
	theme.add_split_layer(NAME, "Near", Vector2(0.36, 0.12), {skyline: HighlandsSkyline.paint_near,
		surface: HighlandsSurface.paint_near}, section, 0.0, {skyline: HighlandsSkyline.draw_near_smoke}, [skyline])
	# The skyline's cliffs fade out at its bottom: a bank of valley mist over the
	# seam hides where they thin out.
	theme.add_tall_layer(NAME, "Haze", Vector2(0.36, 0.12), paint_seam_mist, section, 4.0)
	theme.add_split_layer(NAME, "Front", FRONT_SCROLL, {skyline: HighlandsSkyline.paint_front,
		surface: HighlandsSurface.paint_front}, section)


## The valley's mist over the seam between the skyline and the surface (layer
## Haze): a see-through bank, its top lumpy like cloud tops and its edges
## thinning out in a dither, mostly on the skyline's side.
static func paint_seam_mist(tall: Image) -> void:
	var seam: int = BackdropPaint.tall_row(0, BackdropTheme.SURFACE_SECTION)
	var tops: PackedFloat32Array = BackdropPaint.bumps(seam - MIST_ABOVE_SEAM, Vector2(8.0, 16.0), 20, 8161)
	var bottom: int = seam + MIST_BELOW_SEAM
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		for y: int in range(top, bottom + 1):
			var edge: int = mini(y - top, bottom - y)
			if edge < MIST_DITHER_ROWS and not BackdropPaint.checker(x, y):
				continue
			BackdropPaint.put_pixel(tall, x, y, MIST_THIN if edge < MIST_DITHER_ROWS * 2 else MIST)

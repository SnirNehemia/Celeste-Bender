class_name DeepwoodStyle
extends RefCounted
## DeepwoodStyle: what the three DEEPWOOD looks (themes/deepwood/*.gd) share, so
## they read as one very dense old forest: its floor, its roof of crowns, the
## roots under it. Not a node: static painters, colors and helpers.
##
## Painted in the style of our GROUND (BackdropTerrain): crowns are "ground" made
## of leaves (a bright mossy crust, a hatched dark inside), trunks are bark
## pillars, the forest floor is turf. Depth comes from MANY rows of trees, each
## further one pulled more into the green morning mist (hazed), with drifting mist
## between them.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer):
##   Sky       a dawn: deep teal high up to pale gold at the skyline's horizon,
##             then the luminous green mist the surface sees through the leaves
##   Row0..3   four rows of trees, far to near (TREE_ROWS): the skyline looks down
##             on their crowns, the surface looks up at the crowns' undersides
##             and along their trunks to the forest floor. Each row is one layer
##             with its own scroll, so they slide past each other
##   Mist1, 2  soft bands of mist between rows, drifting
## Each altitude adds nearer layers: faint mossy ledges, giant trunks or an emergent
## crown, and a FOREGROUND of huge ferns, big leaves and hanging moss.
## The surface and the skyline share EVERY layer, the nearer ones too
## (add_shared_layers, at the end; the ones only one of them paints are split
## layers, BackdropTheme.add_split_layer), so the soft change between them is one
## picture scrolling on: nothing appears or vanishes at the seam.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "deepwood"

const SKY_BANDS: Array[Color] = [Color(0.17, 0.32, 0.4), Color(0.22, 0.38, 0.44), Color(0.3, 0.45, 0.46),
	Color(0.4, 0.53, 0.48), Color(0.52, 0.61, 0.5), Color(0.64, 0.69, 0.53), Color(0.75, 0.76, 0.56),
	Color(0.8, 0.8, 0.6), Color(0.74, 0.8, 0.6), Color(0.66, 0.77, 0.58), Color(0.6, 0.73, 0.55)]
## The mist far things fade into.
const AIR: Color = Color(0.63, 0.74, 0.55)
const SUN_CORE: Color = Color(1.0, 0.96, 0.78)
const SUN_GLOW: Color = Color(0.9, 0.88, 0.64)
const MIST: Color = Color(0.82, 0.88, 0.72, 0.5)
const MIST_THIN: Color = Color(0.82, 0.88, 0.72, 0.25)

## Leaves, bark and turf in the ground's style: [crust, rim, edge, inside, hatch, deep].
const LEAVES: Array[Color] = [Color(0.31, 0.56, 0.24), Color(0.56, 0.78, 0.35), Color(0.1, 0.29, 0.13),
	Color(0.06, 0.2, 0.11), Color(0.09, 0.27, 0.14), Color(0.02, 0.08, 0.05)]
const BARK: Array[Color] = [Color(0.4, 0.31, 0.22), Color(0.42, 0.62, 0.27), Color(0.21, 0.14, 0.1),
	Color(0.15, 0.1, 0.08), Color(0.2, 0.14, 0.1), Color(0.06, 0.05, 0.04)]
const TURF: Array[Color] = [Color(0.33, 0.6, 0.25), Color(0.56, 0.78, 0.36), Color(0.1, 0.3, 0.13),
	Color(0.05, 0.19, 0.11), Color(0.08, 0.26, 0.14), Color(0.02, 0.07, 0.04)]
const BLADES: Array[Color] = [Color(0.56, 0.78, 0.36), Color(0.45, 0.68, 0.3), Color(0.66, 0.84, 0.42)]
const MOSS: Color = Color(0.36, 0.55, 0.24)
const MOSS_TIP: Color = Color(0.55, 0.74, 0.33)

## The foreground: huge leaves and ferns, dark against the light.
const FRONT_BODY: Color = Color(0.04, 0.1, 0.06)
const FRONT_LIT: Color = Color(0.1, 0.2, 0.09)
const FRONT_RIB: Color = Color(0.13, 0.25, 0.1)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## The rows of trees, far to near: Vector4(spacing between trees, trunk half
## width, crown half width, haze). Their scroll factors in ROW_SCROLLS.
const TREE_ROWS: Array[Vector4] = [Vector4(30.0, 2.0, 24.0, 0.74), Vector4(42.0, 3.0, 32.0, 0.56),
	Vector4(58.0, 5.0, 40.0, 0.38), Vector4(80.0, 8.0, 50.0, 0.2)]
const ROW_SCROLLS: Array[Vector2] = [Vector2(0.04, 0.015), Vector2(0.07, 0.025), Vector2(0.11, 0.04), Vector2(0.16, 0.055)]
## Per row: the crowns' tops (skyline screen row), their undersides and the
## forest floor (surface screen rows).
const CROWN_TOP_ROWS: Array[int] = [92, 106, 120, 136]
const CROWN_UNDER_ROWS: Array[int] = [12, 24, 38, 54]
const FLOOR_ROWS: Array[int] = [122, 134, 148, 164]


## `color` pulled `amount` toward the mist: further away.
static func far(color: Color, amount: float) -> Color:
	return color.lerp(AIR, amount)


## The sky (see the header): bands, the low sun, thin gold-lit clouds.
static func paint_sky(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(120, BackdropTheme.SURFACE_SECTION))
	# The low sun, glowing through the far crowns of the skyline.
	var sun: Vector2 = Vector2(250.0, BackdropPaint.tall_row(96, BackdropTheme.SKYLINE_SECTION))
	BackdropPaint.put_circle(tall, sun, 30.0, SKY_BANDS[6])
	BackdropPaint.put_circle(tall, sun, 22.0, SUN_GLOW)
	BackdropPaint.put_circle(tall, sun, 14.0, SUN_CORE)
	# A few long thin clouds lit gold from below.
	for cloud_index: int in 6:
		var row: int = BackdropPaint.tall_row(24 + (cloud_index * 23) % 70, BackdropTheme.SKYLINE_SECTION)
		var left: int = roundi(BackdropPaint.random01(cloud_index, 1, 5101) * BackdropPaint.STRIP_WIDTH)
		var length: int = 40 + roundi(BackdropPaint.random01(cloud_index, 2, 5101) * 50.0)
		BackdropPaint.put_rect(tall, Rect2i(left, row, length, 2), SKY_BANDS[3])
		BackdropPaint.put_rect(tall, Rect2i(left + 6, row + 2, length - 12, 1), SKY_BANDS[6])


## One row of trees (TREE_ROWS[row_index]): trunks, then the floor over their feet,
## then the crowns over their tops, all in the ground's style.
static func paint_row(tall: Image, row_index: int) -> void:
	var tree_row: Vector4 = TREE_ROWS[row_index]
	var haze: float = tree_row.w
	var seed_value: int = 5110 + row_index * 10
	var crown_top: int = BackdropPaint.tall_row(CROWN_TOP_ROWS[row_index], BackdropTheme.SKYLINE_SECTION)
	var crown_under: int = BackdropPaint.tall_row(CROWN_UNDER_ROWS[row_index], BackdropTheme.SURFACE_SECTION)
	var floor_row: int = BackdropPaint.tall_row(FLOOR_ROWS[row_index], BackdropTheme.SURFACE_SECTION)
	var tree_count: int = roundi(BackdropPaint.STRIP_WIDTH / tree_row.x)
	var spacing: float = float(BackdropPaint.STRIP_WIDTH) / tree_count
	var tree_xs: Array[float] = []
	for tree_index: int in tree_count:
		tree_xs.append((tree_index + 0.2 + BackdropPaint.random01(tree_index, 1, seed_value) * 0.6) * spacing)
	# Trunks: a small mask each (painting wraps x round the strip by itself).
	var crust: float = clampf(tree_row.y * 0.6, 1.5, 4.0)
	var bark: Array[Color] = BackdropTerrain.hazed(BARK, AIR, haze)
	for tree_index: int in tree_count:
		var x: float = tree_xs[tree_index]
		var half: float = tree_row.y * (0.8 + BackdropPaint.random01(tree_index, 2, seed_value) * 0.5)
		var lean: float = (BackdropPaint.random01(tree_index, 3, seed_value) - 0.5) * 6.0
		# The box: as wide as the roots and branches reach, from just above the
		# trunk's top (the crowns hide it there anyway) to below the floor.
		var reach: int = ceili(half * 4.6) + 4
		var trunk: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(roundi(x) - reach, crown_under - 32,
			reach * 2, floor_row - crown_under + 48))
		_add_trunk(trunk, Vector2(x + lean, crown_under - 30), Vector2(x, floor_row + 6), half, tree_index, seed_value)
		BackdropTerrain.roughen(trunk, seed_value + tree_index)
		BackdropTerrain.paint(tall, trunk, bark, crust, 8.0, 1, seed_value)
	# The forest floor: low mossy mounds, down past the lowest row a layer shows.
	var ground_bottom: int = BackdropPaint.tall_row(BackdropPaint.SCREEN_HEIGHT + BackdropPaint.SCREEN_TOP_ROW + 4, BackdropTheme.SURFACE_SECTION)
	# Further rows' floors are covered a little way down by the next row's floor.
	if row_index < TREE_ROWS.size() - 1:
		ground_bottom = mini(ground_bottom, floor_row + 44)
	var ground: BackdropTerrain.Mask = BackdropTerrain.new_band(floor_row - 16, ground_bottom)
	ground.add_below(BackdropPaint.bumps(floor_row, Vector2(6.0, 4.0 + row_index * 3.0), 18 + row_index * 6, seed_value + 1))
	BackdropTerrain.roughen(ground, seed_value + 1)
	var ground_palette: Array[Color] = BackdropTerrain.hazed(TURF, AIR, haze)
	BackdropTerrain.paint(tall, ground, ground_palette, crust + 1.0, 10.0, 2, seed_value + 1)
	BackdropTerrain.paint_blades(tall, ground, BackdropTerrain.hazed(BLADES, AIR, haze), 3, 2 + row_index, seed_value + 1)
	# Crowns: overlapping clusters of round clumps, one cluster per tree, all one mask.
	var crowns: BackdropTerrain.Mask = BackdropTerrain.new_band(crown_top - 10, crown_under + 24)
	var clumps: Array[Vector3] = []
	# Far rows keep a lit top only on each crown's top clump: with one on every
	# clump they blurred into a froth of arcs.
	var tops_only: bool = haze >= 0.5
	for tree_index: int in tree_count:
		for wrap_offset: float in [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]:
			var crown_clumps: Array[Vector3] = _add_crown(crowns, tree_xs[tree_index] + wrap_offset, crown_top, crown_under, tree_row.z,
				tree_index, seed_value)
			clumps.append_array(crown_clumps.slice(0, 1) if tops_only else crown_clumps)
	# No roughen(): round clumps are irregular enough, and the band is big.
	var leaves: Array[Color] = BackdropTerrain.hazed(LEAVES, AIR, haze)
	BackdropTerrain.paint(tall, crowns, leaves, crust + 1.0, 14.0, 2, seed_value + 2)
	# Lit clump tops only on the crowns' upper parts: the surface looks up at the
	# shaded undersides, where no light falls.
	var upper_clumps: Array[Vector3] = []
	var lit_below: float = lerpf(crown_top, crown_under, 0.55)
	for clump: Vector3 in clumps:
		if clump.y < lit_below:
			upper_clumps.append(clump)
	BackdropTerrain.paint_clump_tops(tall, crowns, upper_clumps, leaves, crust)
	# Moss hanging from the crowns' undersides (only the nearer rows: far off it's lost).
	if row_index >= 1:
		BackdropTerrain.paint_hanging(tall, crowns, far(MOSS, haze), 5 - row_index, 4 + row_index * 4, far(MOSS_TIP, haze), 3, seed_value + 3)


## A trunk from `top` down to `foot`, `half` px each side, flaring into roots at the
## foot, with two branches reaching up into the crown.
static func _add_trunk(mask: BackdropTerrain.Mask, top: Vector2, foot: Vector2, half: float, tree_index: int,
		seed_value: int) -> void:
	mask.add_line(top, foot, half * 2.0)
	# Root flare: two wedges spreading at the foot.
	for side: float in [-1.0, 1.0]:
		var spread: float = half * (2.0 + BackdropPaint.random01(tree_index, 4 + int(side), seed_value) * 1.5)
		mask.add_line(foot + Vector2(side * half * 0.5, -half * 3.0), foot + Vector2(side * spread, 2.0), maxf(2.0, half * 1.2))
	# Branches into the crown.
	for branch: int in 2:
		var along: float = 0.15 + branch * 0.12
		var start: Vector2 = top.lerp(foot, along)
		var side: float = -1.0 if (branch + tree_index) % 2 == 0 else 1.0
		mask.add_line(start, start + Vector2(side * half * 4.0, -half * 5.0), maxf(1.5, half * 0.8))


## One tree's crown: round clumps stacked from `crown_top` to `crown_under`, about
## `half_width` px each side of `x`, a bit wider in the middle. Returns the clumps
## (x, y, radius), top first, for BackdropTerrain.paint_clump_tops.
static func _add_crown(mask: BackdropTerrain.Mask, x: float, crown_top: int, crown_under: int, half_width: float,
		tree_index: int, seed_value: int) -> Array[Vector3]:
	var clumps: Array[Vector3] = []
	var height: float = crown_under - crown_top
	var clump_count: int = 4 + roundi(height / half_width * 2.0)
	# The top clump: a crown's rounded top, varied per tree so the skyline is lumpy.
	var top_drop: float = BackdropPaint.random01(tree_index, 7, seed_value) * half_width * 0.6
	clumps.append(Vector3(x, crown_top + top_drop + half_width * 0.55, half_width * 0.6))
	for clump: int in clump_count:
		var along: float = (clump + 0.5) / clump_count
		var width_here: float = half_width * (0.75 + 0.35 * sin(PI * along))
		var clump_x: float = x + (BackdropPaint.random01(tree_index, clump + 10, seed_value) - 0.5) * width_here * 0.9
		var clump_y: float = lerpf(crown_top + top_drop + half_width * 0.6, crown_under - half_width * 0.35, along)
		var radius: float = width_here * (0.5 + BackdropPaint.random01(tree_index, clump + 40, seed_value) * 0.25)
		clumps.append(Vector3(clump_x, clump_y, radius))
	for clump: Vector3 in clumps:
		mask.add_circle(Vector2(clump.x, clump.y), clump.z)
	return clumps


## Soft mist between rows of trees: a see-through band with lumpy top and bottom
## edges that thin out in a dither, around tall row `middle` (`half_height` px each
## way). Painted on its own (see-through) layer that drifts.
static func paint_mist_band(tall: Image, middle: int, half_height: float, seed_value: int) -> void:
	var tops: PackedFloat32Array = BackdropPaint.bumps(middle - half_height, Vector2(8.0, 18.0), 22, seed_value)
	var bottoms: PackedFloat32Array = BackdropPaint.bumps(middle + half_height, Vector2(6.0, 12.0), 18, seed_value + 1)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		var bottom: int = roundi(2.0 * (middle + half_height) - bottoms[x])
		for y: int in range(top, bottom + 1):
			var edge: int = mini(y - top, bottom - y)
			if edge < 3 and not BackdropPaint.checker(x, y):
				continue
			BackdropPaint.put_pixel(tall, x, y, MIST_THIN if edge < 7 else MIST)


## The mist between rows 1 and 2 (layer Mist1).
static func paint_mist_high(tall: Image) -> void:
	# Between rows 1 and 2: in the skyline's valleys between crowns, and low over
	# the surface's far floor.
	paint_mist_band(tall, BackdropPaint.tall_row(CROWN_TOP_ROWS[2] + 4, BackdropTheme.SKYLINE_SECTION), 5.0, 5151)
	paint_mist_band(tall, BackdropPaint.tall_row(FLOOR_ROWS[1] + 2, BackdropTheme.SURFACE_SECTION), 9.0, 5152)


## The mist between rows 2 and 3 (layer Mist2).
static func paint_mist_low(tall: Image) -> void:
	paint_mist_band(tall, BackdropPaint.tall_row(CROWN_TOP_ROWS[3] + 6, BackdropTheme.SKYLINE_SECTION), 5.0, 5153)
	paint_mist_band(tall, BackdropPaint.tall_row(FLOOR_ROWS[2] + 4, BackdropTheme.SURFACE_SECTION), 8.0, 5154)


## A huge fern rising from `base` (foreground): a fan of long fronds.
static func paint_big_fern(image: Image, base: Vector2, size: float, seed_value: int) -> void:
	for frond: int in 7:
		var along: float = frond / 6.0 - 0.5  # -0.5..0.5 across the fan
		var length: float = size * (0.7 + BackdropPaint.random01(frond, 1, seed_value) * 0.4) * (1.0 - absf(along) * 0.6)
		BackdropPaint.paint_frond(image, base + Vector2(along * 8.0, 0.0), -PI * 0.5 + along * 2.2, length, along * 1.6,
			size * 0.16, FRONT_BODY, FRONT_LIT)


## Moss and thin roots hanging in from the top of a foreground strip, between x
## `from_x` and `to_x`: strands of different lengths with a few leaves.
static func paint_front_moss(image: Image, from_x: int, to_x: int, max_length: int, seed_value: int) -> void:
	var curtain: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(from_x, 0, to_x - from_x, BackdropPaint.SCREEN_TOP_ROW - 2))
	curtain.add_rect(Rect2i(from_x, 0, to_x - from_x, BackdropPaint.SCREEN_TOP_ROW - 2))
	BackdropTerrain.paint_hanging(image, curtain, FRONT_BODY, 3, max_length, FRONT_LIT, 4, seed_value)


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
	for row_index: int in TREE_ROWS.size():
		theme.add_tall_layer(NAME, "Row%d" % row_index, ROW_SCROLLS[row_index], paint_row.bind(row_index), section)
		if row_index == 1:
			theme.add_tall_layer(NAME, "Mist1", ROW_SCROLLS[1], paint_mist_high, section, 3.0)
		elif row_index == 2:
			theme.add_tall_layer(NAME, "Mist2", ROW_SCROLLS[2], paint_mist_low, section, -4.0)
	theme.add_split_layer(NAME, "MossLedges", Vector2(0.2, 0.07), {surface: DeepwoodSurface.paint_moss_ledges}, section)
	theme.add_split_layer(NAME, "Giant", Vector2(0.22, 0.07), {skyline: DeepwoodSkyline.paint_giant}, section, 0.0, {}, [skyline])
	theme.add_split_layer(NAME, "Shafts", Vector2(0.22, 0.08), {}, section, 0.0, {surface: DeepwoodSurface.draw_shafts})
	# The surface's giant trunks hold up the skyline's near crowns: one layer.
	theme.add_split_layer(NAME, "Giants", Vector2(0.36, 0.12), {skyline: DeepwoodSkyline.paint_near_canopy,
		surface: DeepwoodSurface.paint_giants}, section, 0.0, {}, [skyline, surface])
	theme.add_split_layer(NAME, "Front", FRONT_SCROLL, {skyline: DeepwoodSkyline.paint_front, surface: DeepwoodSurface.paint_front}, section, 0.0, {}, [skyline])

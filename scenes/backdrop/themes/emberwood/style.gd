class_name EmberwoodStyle
extends RefCounted
## EmberwoodStyle: what the three EMBERWOOD looks (themes/emberwood/*.gd) share, so
## they read as one place: an old forest growing up the flank of a live volcano,
## at dusk. Its roots (underground), its wood (surface), and the burnt ground
## above the treeline under the crater's plume (skyline). Not a node: static
## painters, colors and helpers.
##
## ONE PICTURE over all three altitudes: every change between them is SOFT
## (Backdrop.SOFT_UNDERGROUND_LOOKS), and all three share EVERY layer, so going
## down into the caves scrolls on through the forest floor as a cut-away: the near
## trees' roots grow down through it into the cave, the giant trunks' roots hang
## from the cave's ceiling, and the sky's bands carry on as the cave's dark.
##
## MIXED style: the sky, the cone and its smoke are PAINTED (BackdropPaint, like
## the volcano look); the trees, the forest floor and the rock are in the style of
## our GROUND (BackdropTerrain, like deepwood). Everything is lit from the lava:
## rims are ember gold instead of moss green, and far things fade into a dark
## red-brown haze (AIR), so a far row of trees is a ruddy silhouette.
##
## TALL layers (BackdropPaint header, BackdropTheme.add_tall_layer):
##   Sky       a dusk: near-black plum high up, reddening down to an ember glow at
##             the surface's horizon, a few stars high in the skyline; under the
##             forest floor, the caves' dark, lit from below, with far walls of
##             lava rock
##   Volcano   the cone, far behind the trees: its crater glows in the surface's
##             view, between and under the crowns, with lava running down its
##             flanks and a dark wooded ridge at its foot; its plume of ash rises
##             through the whole skyline, leaning downwind
##   Row0..3   four rows of trees, far to near (TREE_ROWS): the skyline looks down
##             on their crowns, the surface looks along their trunks to the forest
##             floor. The far rows leave a GAP round the cone (GAP_HALF_WIDTHS), so
##             the wood opens onto the volcano. A lava creek winds along row 1's floor.
##             The nearest row's floor is a cut-away down into the underground: the
##             caves' first ceiling, its trees' roots growing down out of it
##   Smoke1, 2 thin bands of smoke between rows, drifting
## Nearer, each altitude paints its own parts of the split layers. The surface: faint turf-topped basalt ledges,
## giant near trunks on a bank split by lava veins, and a FOREGROUND of a huge
## fern, a charred dead tree and big dark leaves. The skyline: ash clouds lit
## from below, a burnt slope of bare snags rising behind the treetops, the
## giants' charred tops standing out of the treetops, and a FOREGROUND of crags
## and a dead tree. The underground: curtains of fine roots far back, lava-rock
## ledges with lava falls, great roots winding down, the giants' roots hanging
## from a near ceiling over a floor of lava pools, and a FOREGROUND of dangling
## roots and crags.
## The three altitudes share EVERY layer, the nearer ones too (add_shared_layers,
## at the end; the ones only some of them paint are split layers,
## BackdropTheme.add_split_layer), so each soft change is one picture scrolling
## on: nothing appears or vanishes at a seam.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const NAME: String = "emberwood"

## Top of the skyline down to the surface's horizon: plum dark to an ember glow.
## Kept dim (no band brighter than a dull orange) so the rooms' own fire reads first.
const SKY_BANDS: Array[Color] = [Color(0.05, 0.04, 0.08), Color(0.07, 0.04, 0.1), Color(0.1, 0.05, 0.11),
	Color(0.14, 0.06, 0.11), Color(0.19, 0.08, 0.11), Color(0.25, 0.1, 0.1), Color(0.32, 0.12, 0.1),
	Color(0.4, 0.15, 0.1), Color(0.48, 0.19, 0.1), Color(0.55, 0.24, 0.11), Color(0.5, 0.21, 0.11),
	Color(0.42, 0.17, 0.11)]
## The warm haze far things fade into.
const AIR: Color = Color(0.4, 0.17, 0.11)
const STAR_COLOR: Color = Color(0.95, 0.8, 0.75)

const CONE_BODY: Color = Color(0.2, 0.09, 0.1)
const CONE_LIT: Color = Color(0.28, 0.12, 0.11)
const CONE_RIM: Color = Color(0.6, 0.25, 0.12)
const LAVA: Color = Color(1.0, 0.5, 0.12)
const LAVA_CORE: Color = Color(1.0, 0.8, 0.4)
const LAVA_GLOW: Color = Color(1.0, 0.45, 0.1, 0.09)
const ASH_BODY: Color = Color(0.17, 0.1, 0.12)
const ASH_LIT: Color = Color(0.27, 0.15, 0.15)
const ASH_GLOW: Color = Color(0.5, 0.19, 0.1)
const SMOKE: Color = Color(0.2, 0.11, 0.11, 0.5)
const SMOKE_THIN: Color = Color(0.2, 0.11, 0.11, 0.25)

## Leaves, bark, turf and basalt in the ground's style: [crust, rim, edge, inside,
## hatch, deep]. The rims are ember gold: lit by the lava, not the sun.
const LEAVES: Array[Color] = [Color(0.2, 0.36, 0.17), Color(0.64, 0.5, 0.22), Color(0.08, 0.18, 0.1),
	Color(0.05, 0.12, 0.08), Color(0.08, 0.17, 0.1), Color(0.02, 0.05, 0.04)]
const BARK: Array[Color] = [Color(0.3, 0.2, 0.16), Color(0.72, 0.38, 0.16), Color(0.16, 0.09, 0.08),
	Color(0.1, 0.06, 0.06), Color(0.15, 0.09, 0.08), Color(0.04, 0.03, 0.03)]
const TURF: Array[Color] = [Color(0.22, 0.38, 0.17), Color(0.64, 0.5, 0.22), Color(0.08, 0.19, 0.1),
	Color(0.05, 0.12, 0.08), Color(0.08, 0.17, 0.1), Color(0.02, 0.05, 0.04)]
## Black lava rock under a strip of turf: the wood's faint ledges.
const BASALT: Array[Color] = [Color(0.21, 0.35, 0.16), Color(0.62, 0.48, 0.22), Color(0.15, 0.08, 0.08),
	Color(0.09, 0.05, 0.06), Color(0.14, 0.08, 0.08), Color(0.04, 0.03, 0.03)]
## Bare lava rock, no turf: the ground above the treeline and the root caves' walls.
const ROCK: Array[Color] = [Color(0.28, 0.15, 0.13), Color(0.7, 0.32, 0.13), Color(0.15, 0.08, 0.08),
	Color(0.09, 0.05, 0.06), Color(0.14, 0.08, 0.08), Color(0.04, 0.03, 0.03)]
const BLADES: Array[Color] = [Color(0.5, 0.48, 0.22), Color(0.3, 0.44, 0.2), Color(0.66, 0.5, 0.22)]
## Roots, in the ground's style, and the fine rootlets hanging off them.
const ROOT: Array[Color] = [Color(0.36, 0.24, 0.18), Color(0.7, 0.36, 0.15), Color(0.2, 0.12, 0.1),
	Color(0.13, 0.08, 0.07), Color(0.18, 0.11, 0.09), Color(0.05, 0.035, 0.035)]
const ROOTLET: Color = Color(0.26, 0.16, 0.13)
const MOSS: Color = Color(0.22, 0.34, 0.16)
const MOSS_TIP: Color = Color(0.56, 0.44, 0.2)

## The foreground: a huge fern, big leaves and a charred tree, dark against the glow.
const FRONT_BODY: Color = Color(0.04, 0.045, 0.035)
const FRONT_LIT: Color = Color(0.12, 0.09, 0.06)
const FRONT_RIB: Color = Color(0.2, 0.12, 0.07)
const FRONT_EMBER: Color = Color(0.9, 0.35, 0.1)
const FRONT_SCROLL: Vector2 = Vector2(0.62, 0.18)

## The crater: strip x, and the SURFACE's screen row of its lip (it shows under
## the crowns, between the trunks).
const CRATER_X: int = 180
const CRATER_SCREEN_ROW: int = 58
const CONE_SCROLL: Vector2 = Vector2(0.03, 0.01)

## The rows of trees, far to near: Vector4(spacing between trees, trunk half
## width, crown half width, haze). Their scroll factors in ROW_SCROLLS.
const TREE_ROWS: Array[Vector4] = [Vector4(30.0, 2.0, 22.0, 0.72), Vector4(42.0, 3.0, 30.0, 0.54),
	Vector4(58.0, 5.0, 38.0, 0.36), Vector4(80.0, 8.0, 48.0, 0.18)]
const ROW_SCROLLS: Array[Vector2] = [Vector2(0.05, 0.015), Vector2(0.08, 0.025), Vector2(0.12, 0.04), Vector2(0.17, 0.055)]
## Per row: the crowns' tops (skyline screen row: low, the skyline is mostly open
## sky above the treeline), their undersides and the forest floor (surface rows).
const CROWN_TOP_ROWS: Array[int] = [128, 140, 152, 166]
const CROWN_UNDER_ROWS: Array[int] = [6, 14, 24, 36]
const FLOOR_ROWS: Array[int] = [120, 132, 146, 162]
## Per row: no tree stands within this many px of the crater's x, so the wood
## opens onto the cone. Narrower for nearer rows: the opening is a funnel.
const GAP_HALF_WIDTHS: Array[float] = [80.0, 68.0, 56.0, 44.0]
## The row whose floor the lava creek runs along, and how far under its floor row.
const CREEK_ROW_INDEX: int = 1
const CREEK_DROP: int = 6

## The caves' air under the forest floor: what far things there fade into. Warm,
## because the light is lava.
const CAVE_AIR: Color = Color(0.16, 0.07, 0.06)
## The caves' dark, from just under the surface's horizon down: darkest at the
## top, brightest low down, where the lava is.
const CAVE_BANDS: Array[Color] = [Color(0.05, 0.03, 0.04), Color(0.07, 0.035, 0.045), Color(0.09, 0.04, 0.05),
	Color(0.12, 0.05, 0.05), Color(0.16, 0.065, 0.055), Color(0.21, 0.085, 0.06), Color(0.26, 0.105, 0.065)]
const CAVE_WALLS_HAZE: float = 0.76
## The nearest tree row's floor reaches down to this UNDERGROUND screen row: the
## caves' first ceiling.
const ROOT_CEILING_ROW: int = 14
## How far that row's trees' roots reach below the ceiling (px, shortest..longest).
const TREE_ROOT_REACH: Vector2 = Vector2(60.0, 130.0)


## `color` pulled `amount` toward the haze: further away.
static func far(color: Color, amount: float) -> Color:
	return color.lerp(AIR, amount)


## How far strip x `x` is from the crater's x, the short way round the strip.
static func distance_from_crater(x: float) -> float:
	var half_strip: float = BackdropPaint.STRIP_WIDTH * 0.5
	return absf(fposmod(x - CRATER_X + half_strip, BackdropPaint.STRIP_WIDTH) - half_strip)


## The sky (see the header): bands, and a few faint stars high up.
static func paint_sky(tall: Image) -> void:
	BackdropPaint.paint_bands(tall, SKY_BANDS, BackdropPaint.tall_row(0, BackdropTheme.SKYLINE_SECTION),
		BackdropPaint.tall_row(160, BackdropTheme.SURFACE_SECTION))
	for star_index: int in 50:
		var x: int = roundi(BackdropPaint.random01(star_index, 1, 7001) * BackdropPaint.STRIP_WIDTH)
		var depth: float = BackdropPaint.random01(star_index, 2, 7001)
		# depth squared: most stars near the top, where the sky is darkest.
		BackdropPaint.blend_pixel(tall, x, BackdropPaint.tall_row(depth * depth * 90.0, BackdropTheme.SKYLINE_SECTION),
			Color(STAR_COLOR, 0.2 + BackdropPaint.random01(star_index, 3, 7001) * 0.45))
	# Under the forest floor: the caves' dark, starting where the floor already
	# hides the sky, and far walls of lava rock almost lost in it.
	var cave_top: int = BackdropPaint.tall_row(160, BackdropTheme.SURFACE_SECTION)
	BackdropPaint.paint_bands(tall, CAVE_BANDS, cave_top, tall.get_height())
	var walls: BackdropTerrain.Mask = BackdropTerrain.new_band(cave_top, tall.get_height() + 6)
	var wall_ceiling: Array[Vector2] = [Vector2(120.0, 26.0), Vector2(30.0, 8.0)]
	var wall_floor: Array[Vector2] = [Vector2(140.0, 26.0), Vector2(36.0, 8.0)]
	walls.add_above(BackdropPaint.ridge(BackdropPaint.tall_row(36, BackdropTheme.UNDERGROUND_SECTION), wall_ceiling, 7411, false))
	walls.add_below(BackdropPaint.ridge(BackdropPaint.tall_row(168, BackdropTheme.UNDERGROUND_SECTION), wall_floor, 7412, false))
	BackdropTerrain.roughen(walls, 7411)
	BackdropTerrain.paint(tall, walls, BackdropTerrain.hazed(ROCK, CAVE_AIR, CAVE_WALLS_HAZE), 3.0, 10.0, 1, 7411)


## The cone, its lava, the wooded ridge at its foot and its plume (see the header).
static func paint_volcano(tall: Image) -> void:
	var crater_row: float = BackdropPaint.tall_row(CRATER_SCREEN_ROW, BackdropTheme.SURFACE_SECTION)
	var tops: PackedFloat32Array = BackdropPaint.flat_line(tall.get_height() + 4.0)
	BackdropPaint.cone(tops, CRATER_X, crater_row, BackdropPaint.tall_row(150, BackdropTheme.SURFACE_SECTION), 12.0, 250.0, 7011)
	BackdropPaint.paint_mountains(tall, tops, CONE_BODY, CONE_LIT, CONE_RIM, CONE_RIM, CONE_RIM, -100, 40.0, 7012)
	# Lava flows: wandering lines from the crater lip down the flanks.
	for flow_index: int in 4:
		var side: float = -1.0 if flow_index % 2 == 0 else 1.0
		var x: float = CRATER_X + side * (3.0 + flow_index * 2.5)
		var length: int = 50 + roundi(BackdropPaint.random01(flow_index, 1, 7013) * 80.0)
		for step: int in length:
			# Flows spread sideways faster near the top, where the cone is steep.
			x += side * (0.5 + BackdropPaint.random01(flow_index, step, 7014) * 0.6) * (1.0 - float(step) / length * 0.4)
			var y: int = ceili(tops[posmod(roundi(x), BackdropPaint.STRIP_WIDTH)]) + 2
			BackdropPaint.put_rect(tall, Rect2i(roundi(x), y, 2, 1), LAVA)
			if step < length * 0.5:
				BackdropPaint.put_pixel(tall, roundi(x), y, LAVA_CORE)
	BackdropPaint.put_rect(tall, Rect2i(CRATER_X - 10, roundi(crater_row), 21, 2), LAVA)
	BackdropPaint.put_rect(tall, Rect2i(CRATER_X - 6, roundi(crater_row), 13, 1), LAVA_CORE)
	# The plume: billows of ash rising from the crater through the crowns and the
	# whole skyline, leaning downwind and growing; the lowest glow from the crater.
	for puff_index: int in 16:
		var center: Vector2 = Vector2(CRATER_X + puff_index * puff_index * 0.55, crater_row - 8.0 - puff_index * 13.0)
		BackdropPaint.paint_puff(tall, center, 8.0 + puff_index * 2.2, ASH_GLOW if puff_index < 2 else ASH_BODY, ASH_LIT, puff_index + 7020)
	# The wooded ridge at the cone's foot: a dark line of far pines, almost haze.
	var ridge_octaves: Array[Vector2] = [Vector2(140.0, 10.0), Vector2(36.0, 4.0)]
	var ridge_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.tall_row(112, BackdropTheme.SURFACE_SECTION), ridge_octaves, 7040, false)
	var ridge_color: Color = far(LEAVES[BackdropTerrain.EDGE], 0.78)
	BackdropPaint.fill_below(tall, ridge_tops, ridge_color)
	for pine_index: int in 90:
		var pine_x: int = pine_index * 7 + roundi(BackdropPaint.random01(pine_index, 1, 7041) * 4.0)
		var pine_height: int = 7 + roundi(BackdropPaint.random01(pine_index, 2, 7041) * 8.0)
		BackdropPaint.paint_pine(tall, pine_x, ceili(ridge_tops[posmod(pine_x, BackdropPaint.STRIP_WIDTH)]) + 1, pine_height,
			ridge_color, far(LEAVES[BackdropTerrain.RIM], 0.8))


## One row of trees (TREE_ROWS[row_index]): trunks, then the floor over their feet
## (and the lava creek along it), then the crowns over their tops, all in the
## ground's style. No tree stands in the gap round the cone.
static func paint_row(tall: Image, row_index: int) -> void:
	var tree_row: Vector4 = TREE_ROWS[row_index]
	var haze: float = tree_row.w
	var seed_value: int = 7110 + row_index * 10
	var crown_top: int = BackdropPaint.tall_row(CROWN_TOP_ROWS[row_index], BackdropTheme.SKYLINE_SECTION)
	var crown_under: int = BackdropPaint.tall_row(CROWN_UNDER_ROWS[row_index], BackdropTheme.SURFACE_SECTION)
	var floor_row: int = BackdropPaint.tall_row(FLOOR_ROWS[row_index], BackdropTheme.SURFACE_SECTION)
	var slot_count: int = roundi(BackdropPaint.STRIP_WIDTH / tree_row.x)
	var spacing: float = float(BackdropPaint.STRIP_WIDTH) / slot_count
	# One tree per slot, jittered inside it; slots in the gap stay empty.
	var tree_xs: Array[float] = []
	for slot_index: int in slot_count:
		var x: float = (slot_index + 0.2 + BackdropPaint.random01(slot_index, 1, seed_value) * 0.6) * spacing
		if distance_from_crater(x) >= GAP_HALF_WIDTHS[row_index]:
			tree_xs.append(x)
	# Trunks: a small mask each (painting wraps x round the strip by itself).
	var crust: float = clampf(tree_row.y * 0.6, 1.5, 4.0)
	var bark: Array[Color] = BackdropTerrain.hazed(BARK, AIR, haze)
	for tree_index: int in tree_xs.size():
		var x: float = tree_xs[tree_index]
		var half: float = tree_row.y * (0.8 + BackdropPaint.random01(tree_index, 2, seed_value) * 0.5)
		var lean: float = (BackdropPaint.random01(tree_index, 3, seed_value) - 0.5) * 6.0
		# The box: as wide as the roots and branches reach, from just above the
		# trunk's top (the crowns hide it there anyway) to below the floor.
		var reach: int = ceili(half * 4.6) + 4
		var trunk: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(roundi(x) - reach, crown_under - 32,
			reach * 2, floor_row - crown_under + 48))
		add_trunk(trunk, Vector2(x + lean, crown_under - 30), Vector2(x, floor_row + 6), half, tree_index, seed_value)
		BackdropTerrain.roughen(trunk, seed_value + tree_index)
		BackdropTerrain.paint(tall, trunk, bark, crust, 8.0, 1, seed_value)
	# The forest floor: low mounds. Further rows' floors are covered a little way
	# down by the next row's floor; the nearest row's goes on down into the
	# underground as the caves' first ceiling, its trees' roots growing out of it.
	var ground_bottom: int = floor_row + 44
	var is_nearest: bool = row_index == TREE_ROWS.size() - 1
	if is_nearest:
		ground_bottom = BackdropPaint.tall_row(ROOT_CEILING_ROW, BackdropTheme.UNDERGROUND_SECTION)
		_paint_tree_roots(tall, tree_xs, tree_row, floor_row, ground_bottom, seed_value)
	var ground: BackdropTerrain.Mask = BackdropTerrain.new_band(floor_row - 16, ground_bottom)
	ground.add_below(BackdropPaint.bumps(floor_row, Vector2(6.0, 4.0 + row_index * 3.0), 18 + row_index * 6, seed_value + 1))
	if is_nearest:
		# The cut-away's underside: lumps of earth hanging below the band's
		# straight bottom, so the caves' first ceiling is ragged, not a ruled line.
		var band_box: BackdropTerrain.Mask = BackdropTerrain.new_band(floor_row - 16, ground_bottom + 30)
		band_box.add_below(BackdropPaint.bumps(floor_row, Vector2(6.0, 4.0 + row_index * 3.0), 18 + row_index * 6, seed_value + 1))
		# add_below fills to the box's bottom: open the room under the band again.
		band_box.cut_rect(Rect2i(-BackdropTerrain.BAND_SPARE, ground_bottom, BackdropPaint.STRIP_WIDTH + BackdropTerrain.BAND_SPARE * 2, 40))
		for lump_index: int in BackdropPaint.STRIP_WIDTH / 12:
			var lump_x: float = lump_index * 12.0 + BackdropPaint.random01(lump_index, 1, seed_value + 7) * 8.0
			var radius: float = 4.0 + BackdropPaint.random01(lump_index, 2, seed_value + 7) * 12.0
			for wrap_offset: float in [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]:
				band_box.add_circle(Vector2(lump_x + wrap_offset, ground_bottom - 4.0), radius)
		ground = band_box
	BackdropTerrain.roughen(ground, seed_value + 1)
	BackdropTerrain.paint(tall, ground, BackdropTerrain.hazed(TURF, AIR, haze), crust + 1.0, 10.0, 2, seed_value + 1)
	BackdropTerrain.paint_blades(tall, ground, BackdropTerrain.hazed(BLADES, AIR, haze), 3, 2 + row_index, seed_value + 1)
	if is_nearest:
		_paint_underside(tall, ground, ground_bottom - 40, ground_bottom + 30, haze)
		BackdropTerrain.paint_hanging(tall, ground, ROOTLET.lerp(CAVE_AIR, haze), 3, 18, ROOTLET.lerp(CAVE_AIR, haze), 0, seed_value + 4)
	if row_index == CREEK_ROW_INDEX:
		_paint_creek(tall, floor_row + CREEK_DROP)
	# Crowns: overlapping clusters of round clumps, one cluster per tree, all one mask.
	var crowns: BackdropTerrain.Mask = BackdropTerrain.new_band(crown_top - 10, crown_under + 24)
	var clumps: Array[Vector3] = []
	# Far rows keep a lit top only on each crown's top clump: with one on every
	# clump they blur into a froth of arcs.
	var tops_only: bool = haze >= 0.5
	for tree_index: int in tree_xs.size():
		for wrap_offset: float in [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]:
			var crown_clumps: Array[Vector3] = add_crown(crowns, tree_xs[tree_index] + wrap_offset, crown_top, crown_under, tree_row.z,
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


## The lava creek: a thin glowing line wandering up and down around tall row
## `base_row`, broken into stretches (a slow noise hides the rest under the
## ground), with a bright core where it runs widest. The next row's mounds hide
## more of it, so it reads as winding between them, not as a flat bar.
static func _paint_creek(tall: Image, base_row: int) -> void:
	var creek_octaves: Array[Vector2] = [Vector2(110.0, 8.0), Vector2(28.0, 3.0)]
	var creek_rows: PackedFloat32Array = BackdropPaint.ridge(base_row, creek_octaves, 7150, false)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var flow: float = BackdropPaint.periodic_noise(x, 46.0, 7151)
		# Below this the creek runs under the ground: a gap.
		if flow < 0.34:
			continue
		var y: int = roundi(creek_rows[x])
		var is_wide: bool = flow > 0.6
		BackdropPaint.put_rect(tall, Rect2i(x, y, 1, 3 if is_wide else 2), LAVA if flow > 0.42 else CONE_RIM)
		if is_wide:
			BackdropPaint.put_pixel(tall, x, y + 1, LAVA_CORE)


## Repaints the underside of the cut-away floor (`mask`, searched between tall
## rows `from_row` and `to_row`) as earth seen from below: BackdropTerrain.paint
## gives every edge the turf's green crust, which under the floor read as grass
## growing downward. Per column: a lit lip on the lowest row, darker earth above it.
static func _paint_underside(tall: Image, mask: BackdropTerrain.Mask, from_row: int, to_row: int, haze: float) -> void:
	var lip: Color = ROOT[BackdropTerrain.CRUST].lerp(CAVE_AIR, haze)
	var earth: Color = ROOT[BackdropTerrain.EDGE].lerp(CAVE_AIR, haze)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var bottom: int = -1
		for y: int in range(to_row, from_row, -1):
			if mask.is_solid(x, y):
				bottom = y
				break
		if bottom < 0:
			continue
		BackdropPaint.put_rect(tall, Rect2i(x, bottom - 5, 1, 5), earth)
		BackdropPaint.put_pixel(tall, x, bottom, lip)


## The nearest row's trees' roots: from each tree's foot down through the floor
## (which then covers their tops) into the cave under it, winding and branching,
## hazed like their row.
static func _paint_tree_roots(tall: Image, tree_xs: Array[float], tree_row: Vector4, floor_row: int, ceiling_row: int,
		seed_value: int) -> void:
	var reach_bottom: int = ceiling_row + roundi(TREE_ROOT_REACH.y) + 20
	var roots: BackdropTerrain.Mask = BackdropTerrain.new_band(floor_row, reach_bottom)
	for tree_index: int in tree_xs.size():
		var reach: float = lerpf(TREE_ROOT_REACH.x, TREE_ROOT_REACH.y, BackdropPaint.random01(tree_index, 20, seed_value))
		# Long enough to get from the foot through the floor, then `reach` below it.
		var length: float = ceiling_row - floor_row + reach
		add_root(roots, Vector2(tree_xs[tree_index], floor_row + 4.0), tree_row.y * 1.6, length, tree_index, 2, 7170)
	BackdropTerrain.roughen(roots, seed_value + 5)
	var palette: Array[Color] = BackdropTerrain.hazed(ROOT, CAVE_AIR, tree_row.w + 0.12)
	BackdropTerrain.paint(tall, roots, palette, 2.0, 6.0, 1, seed_value + 5)
	BackdropTerrain.paint_hanging(tall, roots, ROOTLET.lerp(CAVE_AIR, tree_row.w + 0.12), 6, 10, ROOTLET, 0, seed_value + 6)


## One root from `start`, `width` px thick, `length` px long: its heading swings
## either side of straight down (smooth noise, not a random walk, so it curves in
## S bends instead of drifting off), and `branches` times it puts out a thinner
## side root of its own. Each `root_index` (with `seed_value`) winds its own way.
static func add_root(roots: BackdropTerrain.Mask, start: Vector2, width: float, length: float, root_index: int,
		branches: int, seed_value: int) -> void:
	var point: Vector2 = start
	var travelled: float = 0.0
	var next_branch: float = length * 0.3
	while travelled < length:
		var swing: float = (BackdropPaint.periodic_noise(travelled * 4.0 + root_index * 131.0, 60.0, seed_value) - 0.5) * 2.2
		var heading: float = PI * 0.5 + swing
		var next: Vector2 = point + Vector2(cos(heading), sin(heading)) * 4.0
		# Thins to a fifth of its width by the tip, never under 2 px.
		var width_here: float = maxf(2.0, width * (1.0 - travelled / length * 0.8))
		for wrap_offset: float in [-BackdropPaint.STRIP_WIDTH, 0.0, BackdropPaint.STRIP_WIDTH]:
			roots.add_line(point + Vector2(wrap_offset, 0.0), next + Vector2(wrap_offset, 0.0), width_here)
		point = next
		travelled += 4.0
		if branches > 0 and travelled >= next_branch:
			add_root(roots, point, width_here * 0.55, length * 0.45, root_index * 7 + branches, branches - 1, seed_value)
			next_branch += length * 0.3
			branches -= 1


## A trunk from `top` down to `foot`, `half` px each side, flaring into roots at the
## foot, with two branches reaching up into the crown.
static func add_trunk(mask: BackdropTerrain.Mask, top: Vector2, foot: Vector2, half: float, tree_index: int,
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
static func add_crown(mask: BackdropTerrain.Mask, x: float, crown_top: int, crown_under: int, half_width: float,
		tree_index: int, seed_value: int) -> Array[Vector3]:
	var clumps: Array[Vector3] = []
	var height: float = crown_under - crown_top
	var clump_count: int = 4 + roundi(height / half_width * 2.0)
	# The top clump: a crown's rounded top, varied per tree so the roof is lumpy.
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


## Thin smoke between rows of trees: a see-through band with lumpy top and bottom
## edges that thin out in a dither, around tall row `middle` (`half_height` px each
## way). Painted on its own (see-through) layer that drifts.
static func paint_smoke_band(tall: Image, middle: int, half_height: float, seed_value: int) -> void:
	var tops: PackedFloat32Array = BackdropPaint.bumps(middle - half_height, Vector2(8.0, 18.0), 22, seed_value)
	var bottoms: PackedFloat32Array = BackdropPaint.bumps(middle + half_height, Vector2(6.0, 12.0), 18, seed_value + 1)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var top: int = ceili(tops[x])
		# bumps() only bulges upward: mirror it round the band's lower edge.
		var bottom: int = roundi(2.0 * (middle + half_height) - bottoms[x])
		for y: int in range(top, bottom + 1):
			var edge: int = mini(y - top, bottom - y)
			if edge < 3 and not BackdropPaint.checker(x, y):
				continue
			BackdropPaint.put_pixel(tall, x, y, SMOKE_THIN if edge < 7 else SMOKE)


## The smoke between rows 1 and 2 (layer Smoke1): low over the far floor.
static func paint_smoke_far(tall: Image) -> void:
	paint_smoke_band(tall, BackdropPaint.tall_row(FLOOR_ROWS[1] - 14, BackdropTheme.SURFACE_SECTION), 6.0, 7161)


## The smoke between rows 2 and 3 (layer Smoke2): among the trunks, higher up.
static func paint_smoke_near(tall: Image) -> void:
	paint_smoke_band(tall, BackdropPaint.tall_row(FLOOR_ROWS[2] - 46, BackdropTheme.SURFACE_SECTION), 5.0, 7163)


## A huge fern rising from `base` (foreground): a fan of long fronds.
static func paint_big_fern(image: Image, base: Vector2, size: float, seed_value: int) -> void:
	for frond: int in 7:
		var along: float = frond / 6.0 - 0.5  # -0.5..0.5 across the fan
		var length: float = size * (0.7 + BackdropPaint.random01(frond, 1, seed_value) * 0.4) * (1.0 - absf(along) * 0.6)
		BackdropPaint.paint_frond(image, base + Vector2(along * 8.0, 0.0), -PI * 0.5 + along * 2.2, length, along * 1.6,
			size * 0.16, FRONT_BODY, FRONT_LIT)


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


## Adds every layer of the look, far to near, to `theme` showing `section`: all
## three altitudes call this, so their layers, scrolls and order are the same and
## every soft change between them is one picture scrolling on. A layer only some
## of them paint is a split layer (BackdropTheme.add_split_layer): in the others
## it sits just off the screen and scrolls in with everything else.
static func add_shared_layers(theme: BackdropTheme, section: int) -> void:
	var skyline: int = BackdropTheme.SKYLINE_SECTION
	var surface: int = BackdropTheme.SURFACE_SECTION
	var underground: int = BackdropTheme.UNDERGROUND_SECTION
	# add_split_layer(..., section, drift px/s, {section: moving things}, [sections
	# that fade out at the seam instead of ending in a straight cut]).
	theme.add_tall_layer(NAME, "Sky", Vector2(0.01, 0.0), paint_sky, section)
	var cone: BackdropLayer = theme.add_tall_layer(NAME, "Volcano", CONE_SCROLL, paint_volcano, section)
	cone.draw_extra = BackdropTheme.section_extras({surface: EmberwoodSurface.draw_crater_glow}, section)
	# The skyline's burnt slope above the treeline: behind the rows, so the crowns
	# hide its foot; it thins out in a dither before the seam to the surface.
	theme.add_split_layer(NAME, "Slope", Vector2(0.04, 0.012), {skyline: EmberwoodSkyline.paint_burnt_slope}, section, 0.0, {}, [skyline])
	theme.add_split_layer(NAME, "FarRoots", Vector2(0.06, 0.02), {underground: EmberwoodUnderground.paint_far_roots}, section)
	for row_index: int in TREE_ROWS.size():
		var row_layer: BackdropLayer = theme.add_tall_layer(NAME, "Row%d" % row_index, ROW_SCROLLS[row_index], paint_row.bind(row_index), section)
		if row_index == CREEK_ROW_INDEX:
			row_layer.draw_extra = BackdropTheme.section_extras({surface: EmberwoodSurface.draw_creek_glow}, section)
			theme.add_tall_layer(NAME, "Smoke1", ROW_SCROLLS[1], paint_smoke_far, section, 3.0)
		elif row_index == 2:
			theme.add_tall_layer(NAME, "Smoke2", ROW_SCROLLS[2], paint_smoke_near, section, -4.0)
	theme.add_split_layer(NAME, "AshClouds", Vector2(0.1, 0.035), {skyline: EmberwoodSkyline.paint_ash_clouds}, section, 3.0)
	theme.add_split_layer(NAME, "Ledges", Vector2(0.21, 0.07), {surface: EmberwoodSurface.paint_ledges,
		underground: EmberwoodUnderground.paint_ledges}, section, 0.0, {underground: EmberwoodUnderground.draw_fall_glow})
	theme.add_split_layer(NAME, "Roots", Vector2(0.26, 0.09), {underground: EmberwoodUnderground.paint_roots}, section)
	# One giant tree in all three views: its charred top over the skyline's
	# treetops, its trunk in the wood, its roots hanging into the caves.
	theme.add_split_layer(NAME, "Giants", Vector2(0.36, 0.12), {skyline: EmberwoodSkyline.paint_snags,
		surface: EmberwoodSurface.paint_giants, underground: EmberwoodUnderground.paint_near}, section, 0.0,
		{skyline: EmberwoodSkyline.draw_ember_glow, surface: EmberwoodSurface.draw_vein_glow,
		underground: EmberwoodUnderground.draw_pool_glow}, [skyline])
	theme.add_split_layer(NAME, "Front", FRONT_SCROLL, {skyline: EmberwoodSkyline.paint_front,
		surface: EmberwoodSurface.paint_front, underground: EmberwoodUnderground.paint_front}, section, 0.0, {},
		[skyline, surface, underground])

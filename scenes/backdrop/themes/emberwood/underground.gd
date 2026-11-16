class_name EmberwoodUnderground
extends BackdropTheme
## EMBERWOOD, UNDERGROUND: the root caves under the wood, lit by lava from below.
## Shared with the wood and the treeline (EmberwoodStyle: the three are one
## picture, and the change up to the wood is SOFT, scrolling on through the forest
## floor): the caves' dark with far walls of lava rock, the forest floor overhead
## as the first ceiling with the near trees' roots growing down out of it. All of
## EmberwoodStyle.add_shared_layers shows here; what this altitude paints itself
## (its parts of the split layers), far to near: curtains of fine roots hanging from the far ceiling;
## faint lava-rock ledges, lava dripping from two of them in thin glowing falls;
## great roots winding down; a near ceiling with the giant trunks' roots hanging
## from it (the same giants that stand in the wood above), over a floor of lava
## rock with lava pools dug into it; and right in front dangling roots and black
## crags. The falls and pools glow, embers rise and dust hangs in the air.
## Rock and roots are painted the way our ground is (BackdropTerrain).
## Layers far to near; see BackdropTheme. (Above: surface.gd, in the wood.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const FAR_HAZE: float = 0.66
const LEDGES_HAZE: float = 0.42
const ROOTS_HAZE: float = 0.2
## The faint ledges: (left x, top screen row, width in tiles).
const LEDGES: Array[Vector3i] = [Vector3i(40, 96, 6), Vector3i(190, 58, 5), Vector3i(330, 114, 7), Vector3i(500, 76, 5)]
## Which ledges lava drips from (indices into LEDGES).
const FALL_LEDGES: Array[int] = [1, 3]
## The near ceiling's underside (screen row).
const CEILING_SCREEN_ROW: int = 8
## How far the giants' roots reach down (screen rows below the top).
const GIANT_ROOT_LENGTH: float = 120.0
## The near floor's base row (screen).
const FLOOR_SCREEN_ROW: int = 166
## The lava pools in the near floor: Vector2(strip x of the middle, half width).
const POOLS: Array[Vector2] = [Vector2(70.0, 26.0), Vector2(330.0, 18.0), Vector2(450.0, 34.0)]
## How deep a pool's bowl is in its middle, px.
const POOL_DEPTH: float = 5.0


func _build_layers() -> void:
	EmberwoodStyle.add_shared_layers(self, UNDERGROUND_SECTION)

	var embers: BackdropMotes = BackdropMotes.new()
	embers.shape = BackdropMotes.Shape.FIREFLY
	embers.mote_count = 16
	embers.colors = [Color(1.0, 0.6, 0.2, 0.9), Color(1.0, 0.8, 0.35, 0.8)]
	embers.velocity = Vector2(1.5, -7.0)
	embers.sway_amplitude = 4.0
	embers.sway_speed = 0.3
	embers.scroll_factor = 0.45
	embers.seed_value = 7401
	add_motes(embers)

	var dust: BackdropMotes = BackdropMotes.new()
	dust.mote_count = 18
	dust.colors = [Color(0.5, 0.36, 0.3, 0.3), Color(0.36, 0.25, 0.22, 0.35)]
	dust.velocity = Vector2(1.5, 1.0)
	dust.sway_amplitude = 4.0
	dust.sway_speed = 0.15
	dust.scroll_factor = 0.35
	dust.seed_value = 7402
	add_motes(dust)


## Curtains of fine roots hanging from the far ceiling into the dark (layer FarRoots).
static func paint_far_roots() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var ceiling: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.row(36))
	ceiling.add_above(BackdropPaint.ridge(BackdropPaint.row(24), [Vector2(80.0, 10.0)] as Array[Vector2], 7421, false))
	BackdropTerrain.roughen(ceiling, 7421)
	var air: Color = EmberwoodStyle.CAVE_AIR
	BackdropTerrain.paint(image, ceiling, BackdropTerrain.hazed(EmberwoodStyle.ROCK, air, FAR_HAZE), 3.0, 8.0, 1, 7421)
	BackdropTerrain.paint_hanging(image, ceiling, EmberwoodStyle.ROOTLET.lerp(air, FAR_HAZE - 0.15), 2, 90,
		EmberwoodStyle.ROOTLET.lerp(air, FAR_HAZE - 0.3), 7, 7422)
	return image


## Faint lava-rock ledges at different heights; from FALL_LEDGES lava drips in a
## thin fall down out of view (painted first, so the ledge covers its top).
static func paint_ledges() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var air: Color = EmberwoodStyle.CAVE_AIR
	var palette: Array[Color] = BackdropTerrain.hazed(EmberwoodStyle.ROCK, air, LEDGES_HAZE)
	for ledge_index: int in FALL_LEDGES:
		var fall: Vector2 = _fall_top(ledge_index)
		for y: int in range(roundi(fall.y), BackdropPaint.STRIP_HEIGHT):
			# The fall wavers a pixel sideways on its way down, and breaks into drops.
			var sway: int = roundi((BackdropPaint.periodic_noise(y, 14.0, 7480 + ledge_index) - 0.5) * 2.0)
			if BackdropPaint.periodic_noise(y, 9.0, 7490 + ledge_index) < 0.2:
				continue
			BackdropPaint.put_rect(image, Rect2i(roundi(fall.x) + sway, y, 2, 1), EmberwoodStyle.LAVA)
			BackdropPaint.put_pixel(image, roundi(fall.x) + sway, y, EmberwoodStyle.LAVA_CORE)
	for ledge_index: int in LEDGES.size():
		var ledge: Vector3i = LEDGES[ledge_index]
		var top_row: int = BackdropPaint.row(ledge.y)
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(ledge.x - 2, top_row - 10, ledge.z * 6 + 4, 40))
		BackdropTerrain.add_chunk(mask, ledge.x, top_row, ledge.z, 4, 6, 7431 + ledge_index)
		BackdropTerrain.roughen(mask, 7431 + ledge_index)
		BackdropTerrain.paint(image, mask, palette, 3.0, 8.0, 2, 7431 + ledge_index)
		var rootlet: Color = EmberwoodStyle.ROOTLET.lerp(air, LEDGES_HAZE)
		BackdropTerrain.paint_hanging(image, mask, rootlet, 3, 14, rootlet, 0, 7441 + ledge_index)
	return image


## Where the lava fall of LEDGES[ledge_index] starts: under the ledge's middle (strip px).
static func _fall_top(ledge_index: int) -> Vector2:
	var ledge: Vector3i = LEDGES[ledge_index]
	# The ledge's tiles are 6 px wide (add_chunk below), so z * 3 is its middle.
	return Vector2(ledge.x + ledge.z * 3, BackdropPaint.row(ledge.y) + 4)


## Each lava fall's glow where it leaves its ledge, pulsing slowly.
static func draw_fall_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for fall_index: int in FALL_LEDGES.size():
		var fall: Vector2 = _fall_top(FALL_LEDGES[fall_index])
		var pulse: float = 0.6 + 0.4 * sin(time * 0.9 + fall_index * 1.7)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + fall.x, fall.y + 10.0), 14.0, EmberwoodStyle.LAVA_GLOW, pulse)


## Great roots winding down from above the screen in S curves, thinning as they
## go, each putting out a few side roots, with fine rootlets hanging from them
## (layer Roots).
static func paint_roots() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var roots: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.STRIP_HEIGHT)
	for root_index: int in 4:
		var x: float = (root_index + 0.5 + BackdropPaint.random01(root_index, 1, 7451) * 0.5) * BackdropPaint.STRIP_WIDTH / 4.0
		var length: float = BackdropPaint.row(60) + BackdropPaint.random01(root_index, 3, 7451) * 100.0
		EmberwoodStyle.add_root(roots, Vector2(x, 0.0), 10.0 + BackdropPaint.random01(root_index, 2, 7451) * 5.0, length,
			root_index, 2, 7452)
	BackdropTerrain.roughen(roots, 7453)
	var air: Color = EmberwoodStyle.CAVE_AIR
	BackdropTerrain.paint(image, roots, BackdropTerrain.hazed(EmberwoodStyle.ROOT, air, ROOTS_HAZE), 3.0, 6.0, 1, 7453)
	BackdropTerrain.paint_hanging(image, roots, EmberwoodStyle.ROOTLET.lerp(air, ROOTS_HAZE), 6, 16, EmberwoodStyle.ROOTLET, 0, 7454)
	return image


## The near cave (the underground's part of layer Giants): a ceiling of lava rock
## carrying on from the wood's bank above, the giant trunks' roots hanging from it
## (same strip x as EmberwoodSurface.GIANTS: the trees standing up there), and a
## floor of lava rock with lava pools dug into it (painted first: the rock's own
## edge then lies over the pools' ends).
static func paint_near() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# The giants' roots: each trunk splits into three thick roots fanning down,
	# each with one side root (more read as a tangle).
	var roots: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.STRIP_HEIGHT)
	for giant_index: int in EmberwoodSurface.GIANTS.size():
		var giant: Vector2i = EmberwoodSurface.GIANTS[giant_index]
		for root: int in 3:
			var start: Vector2 = Vector2(giant.x + giant.y * (0.2 + root * 0.3), 0.0)
			var length: float = BackdropPaint.row(GIANT_ROOT_LENGTH) * (0.75 + BackdropPaint.random01(root, giant_index, 7464) * 0.4)
			EmberwoodStyle.add_root(roots, start, giant.y * 0.4, length, giant_index * 3 + root, 1, 7465)
	BackdropTerrain.roughen(roots, 7466)
	BackdropTerrain.paint(image, roots, EmberwoodStyle.ROOT, 4.0, 8.0, 1, 7466)
	BackdropTerrain.paint_hanging(image, roots, EmberwoodStyle.ROOTLET, 8, 12, EmberwoodStyle.ROOT[BackdropTerrain.CRUST], 0, 7467)
	var floor_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(FLOOR_SCREEN_ROW), [Vector2(110.0, 12.0), Vector2(26.0, 4.0)] as Array[Vector2], 7462, false)
	# Each pool: a bowl dug into the floor, its surface level with the lower of
	# the floor's two rims, filled with lava up to it.
	for pool: Vector2 in POOLS:
		var left: int = roundi(pool.x - pool.y)
		var right: int = roundi(pool.x + pool.y)
		var surface: int = ceili(maxf(floor_tops[posmod(left, BackdropPaint.STRIP_WIDTH)], floor_tops[posmod(right, BackdropPaint.STRIP_WIDTH)])) + 1
		for x: int in range(left + 1, right):
			var column: int = posmod(x, BackdropPaint.STRIP_WIDTH)
			var bowl: float = 1.0 - pow((x - pool.x) / pool.y, 2.0)  # 1 in the middle, 0 at the rims
			var bottom: float = surface + 2.0 + bowl * POOL_DEPTH
			floor_tops[column] = maxf(floor_tops[column], bottom)
			BackdropPaint.put_rect(image, Rect2i(column, surface, 1, ceili(bottom) - surface + 4), EmberwoodStyle.LAVA)
			BackdropPaint.put_pixel(image, column, surface, EmberwoodStyle.LAVA_CORE)
	# The ceiling (thin: the wood's bank above already covers the top) and the floor.
	var rock: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.STRIP_HEIGHT + 6)
	rock.add_above(BackdropPaint.hanging(BackdropPaint.row(CEILING_SCREEN_ROW), [Vector2(90.0, 5.0), Vector2(24.0, 3.0)] as Array[Vector2], 7461, false))
	rock.add_below(floor_tops)
	BackdropTerrain.roughen(rock, 7461)
	BackdropTerrain.paint(image, rock, EmberwoodStyle.ROCK, 5.0, 10.0, 2, 7461)
	BackdropTerrain.paint_hanging(image, rock, EmberwoodStyle.ROOTLET, 4, 22, EmberwoodStyle.ROOT[BackdropTerrain.CRUST], 0, 7463)
	return image


## The lava pools' glow: soft light along the floor, out of step from place to place.
static func draw_pool_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for pool_index: int in POOLS.size():
		var pulse: float = 0.55 + 0.45 * sin(time * 0.8 + pool_index * 2.1)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + POOLS[pool_index].x, BackdropPaint.row(FLOOR_SCREEN_ROW - 6)), 10.0 + POOLS[pool_index].y,
			EmberwoodStyle.LAVA_GLOW, pulse)


## Right in front, at the edges: roots dangling in from above and black crags
## rising from a bottom corner.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# Each: (left x, right x, longest strand).
	var curtain_spans: Array[Vector3i] = [Vector3i(20, 96, 80), Vector3i(410, 480, 56)]
	for curtain_index: int in curtain_spans.size():
		var curtain_span: Vector3i = curtain_spans[curtain_index]
		var curtain_box: Rect2i = Rect2i(curtain_span.x, 0, curtain_span.y - curtain_span.x, BackdropPaint.SCREEN_TOP_ROW - 2)
		var curtain: BackdropTerrain.Mask = BackdropTerrain.new_mask(curtain_box)
		curtain.add_rect(curtain_box)
		BackdropTerrain.paint_hanging(image, curtain, EmberwoodStyle.FRONT_BODY, 3, curtain_span.z, EmberwoodStyle.FRONT_LIT, 4, 7475 + curtain_index)
	BackdropPaint.paint_crag(image, 560.0, 30.0, 96.0, EmberwoodStyle.FRONT_BODY, EmberwoodStyle.FRONT_LIT, EmberwoodStyle.CONE_RIM, 7473)
	BackdropPaint.paint_crag(image, 598.0, 18.0, 58.0, EmberwoodStyle.FRONT_BODY, EmberwoodStyle.FRONT_LIT, EmberwoodStyle.CONE_RIM, 7474)
	return image

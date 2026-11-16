class_name EmberwoodSurface
extends BackdropTheme
## EMBERWOOD, SURFACE: in the wood on the volcano's flank, at dusk. A dark plum
## sky reddening to an ember glow; far behind, the cone with its glowing crater,
## lava down its flanks and a wooded ridge at its foot; four rows of trees going
## back into the red haze, parting round the cone, a lava creek winding along the
## far floor and thin smoke drifting between the rows (all shared with the
## skyline: EmberwoodStyle); faint turf-topped basalt ledges, giant near trunks
## on a bank split by glowing lava veins, and right in front a huge fern, a
## charred dead tree and big dark leaves; embers rise, ash and a few leaves fall.
## Everything solid is painted the way our ground is (BackdropTerrain).
## Layers far to near; see BackdropTheme. (Under it: underground.gd, the root
## caves; high up: skyline.gd, above the treeline.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const LEDGES_HAZE: float = 0.34
## The giant near trunks: strip x of each one's left edge and its width.
const GIANTS: Array[Vector2i] = [Vector2i(250, 30), Vector2i(560, 36)]
const NEAR_FLOOR_ROW: int = 174
## Lava veins in the near bank: how many, spread along the strip.
const VEIN_COUNT: int = 7
const VEIN_COLOR: Color = Color(0.95, 0.4, 0.1)


func _build_layers() -> void:
	EmberwoodStyle.add_shared_layers(self, SURFACE_SECTION)

	var embers: BackdropMotes = BackdropMotes.new()
	embers.shape = BackdropMotes.Shape.FIREFLY
	embers.mote_count = 16
	embers.colors = [Color(1.0, 0.6, 0.2, 0.9), Color(1.0, 0.8, 0.35, 0.8)]
	embers.velocity = Vector2(4.0, -12.0)
	embers.sway_amplitude = 4.0
	embers.sway_speed = 0.35
	embers.scroll_factor = 0.5
	embers.seed_value = 7201
	add_motes(embers)

	var ash: BackdropMotes = BackdropMotes.new()
	ash.mote_count = 22
	ash.colors = [Color(0.5, 0.42, 0.4, 0.4), Color(0.32, 0.26, 0.27, 0.45)]
	ash.velocity = Vector2(5.0, 8.0)
	ash.sway_amplitude = 3.0
	ash.sway_speed = 0.2
	ash.scroll_factor = 0.4
	ash.seed_value = 7202
	add_motes(ash)

	var leaves: BackdropMotes = BackdropMotes.new()
	leaves.shape = BackdropMotes.Shape.LEAF
	leaves.mote_count = 6
	leaves.colors = [Color(0.34, 0.46, 0.2, 0.8), Color(0.6, 0.38, 0.16, 0.75)]
	leaves.velocity = Vector2(4.0, 10.0)
	leaves.sway_amplitude = 6.0
	leaves.sway_speed = 0.35
	leaves.scroll_factor = 0.65
	leaves.seed_value = 7203
	add_motes(leaves)


## The crater's glow, breathing slowly (a draw_extra on the cone's layer).
static func draw_crater_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var pulse: float = 0.7 + 0.3 * sin(time * 0.6)
	var crater: Vector2 = Vector2(copy_x + EmberwoodStyle.CRATER_X, BackdropPaint.row(EmberwoodStyle.CRATER_SCREEN_ROW) - 3.0)
	BackdropTheme.draw_glow(layer, crater, 36.0, EmberwoodStyle.LAVA_GLOW, pulse)
	BackdropTheme.draw_glow(layer, crater, 16.0, EmberwoodStyle.LAVA_GLOW, pulse)


## The lava creek's glow: soft pools of light along it, out of step with each other.
static func draw_creek_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var creek_row: float = BackdropPaint.row(EmberwoodStyle.FLOOR_ROWS[EmberwoodStyle.CREEK_ROW_INDEX] + EmberwoodStyle.CREEK_DROP)
	for glow_index: int in 5:
		var pulse: float = 0.6 + 0.4 * sin(time * 0.8 + glow_index * 1.7)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + 64.0 + glow_index * 128.0, creek_row), 22.0, EmberwoodStyle.LAVA_GLOW, pulse)


## Faint ledges between the trunks: floating chunks of black basalt with turf on
## top, in the ground's style, hazed well into the air so they don't look walkable.
static func paint_ledges() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var palette: Array[Color] = BackdropTerrain.hazed(EmberwoodStyle.BASALT, EmberwoodStyle.AIR, LEDGES_HAZE)
	# Each: (left x, top screen row, width in tiles).
	var ledges: Array[Vector3i] = [Vector3i(24, 96, 5), Vector3i(118, 64, 4), Vector3i(330, 84, 6), Vector3i(452, 110, 4),
		Vector3i(556, 58, 5)]
	for ledge_index: int in ledges.size():
		var ledge: Vector3i = ledges[ledge_index]
		var top_row: int = BackdropPaint.row(ledge.y)
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(ledge.x - 2, top_row - 10, ledge.z * 6 + 4, 40))
		BackdropTerrain.add_chunk(mask, ledge.x, top_row, ledge.z, 3, 6, 7211 + ledge_index)
		BackdropTerrain.roughen(mask, 7211 + ledge_index)
		BackdropTerrain.paint(image, mask, palette, 3.0, 9.0, 2, 7211 + ledge_index)
		BackdropTerrain.paint_blades(image, mask, BackdropTerrain.hazed(EmberwoodStyle.BLADES, EmberwoodStyle.AIR, LEDGES_HAZE), 2, 3, 7211 + ledge_index)
		BackdropTerrain.paint_hanging(image, mask, EmberwoodStyle.far(EmberwoodStyle.MOSS, LEDGES_HAZE), 2, 12,
			EmberwoodStyle.far(EmberwoodStyle.MOSS_TIP, LEDGES_HAZE), 4, 7221 + ledge_index)
	return image


## The giant near trunks: bark pillars in the ground's style going up out of view,
## roots sprawling into a turf bank along the bottom, and lava veins glowing in
## cracks of the bank.
static func paint_giants() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var floor_row: int = BackdropPaint.row(NEAR_FLOOR_ROW)
	var trunks: BackdropTerrain.Mask = BackdropTerrain.new_band(-10, floor_row + 12)
	for giant: Vector2i in GIANTS:
		trunks.add_rect(Rect2i(giant.x, -10, giant.y, floor_row + 20))
		# Roots: thick curves out to both sides.
		for root: int in 3:
			var side: float = -1.0 if root % 2 == 0 else 1.0
			var start: Vector2 = Vector2(giant.x + giant.y * (0.5 + side * 0.35), floor_row - 18 - root * 6)
			var reach: float = giant.y * (0.9 + root * 0.35)
			var middle: Vector2 = start + Vector2(side * reach * 0.6, 4.0)
			trunks.add_line(start, middle, 9.0 - root)
			trunks.add_line(middle, Vector2(start.x + side * reach, floor_row + 6), 7.0 - root)
	BackdropTerrain.roughen(trunks, 7231)
	BackdropTerrain.paint(image, trunks, EmberwoodStyle.BARK, 4.0, 10.0, 2, 7231)
	# The turf bank they stand in.
	var bank: BackdropTerrain.Mask = BackdropTerrain.new_band(floor_row - 14, BackdropPaint.STRIP_HEIGHT + 6)
	var bank_tops: PackedFloat32Array = BackdropPaint.bumps(floor_row, Vector2(6.0, 12.0), 30, 7233)
	bank.add_below(bank_tops)
	BackdropTerrain.roughen(bank, 7233)
	BackdropTerrain.paint(image, bank, EmberwoodStyle.TURF, 5.0, 10.0, 2, 7233)
	BackdropTerrain.paint_blades(image, bank, EmberwoodStyle.BLADES, 2, 4, 7233)
	# Lava veins: short jagged cracks running down from under the turf.
	for vein_index: int in VEIN_COUNT:
		var point: Vector2 = Vector2(_vein_x(vein_index), 0.0)
		point.y = bank_tops[posmod(roundi(point.x), BackdropPaint.STRIP_WIDTH)] + 9.0
		for segment: int in 5:
			var next: Vector2 = point + Vector2((BackdropPaint.random01(vein_index, segment, 7234) - 0.5) * 8.0, 3.0 + segment)
			BackdropPaint.put_line(image, point, next, VEIN_COLOR)
			point = next
	return image


## Where vein `vein_index` starts (strip x).
static func _vein_x(vein_index: int) -> float:
	return (vein_index + 0.2 + BackdropPaint.random01(vein_index, 1, 7235) * 0.6) * BackdropPaint.STRIP_WIDTH / VEIN_COUNT


## Each lava vein glows, out of step with the others.
static func draw_vein_glow(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for vein_index: int in VEIN_COUNT:
		var pulse: float = 0.5 + 0.5 * sin(time * 1.1 + vein_index * 2.1)
		BackdropTheme.draw_glow(layer, Vector2(copy_x + _vein_x(vein_index), BackdropPaint.row(NEAR_FLOOR_ROW + 12)), 14.0,
			EmberwoodStyle.LAVA_GLOW, pulse)


## Right in front, at the edges: a huge fern from the bottom left, a charred dead
## tree further along, and big dark leaves hanging in from the top.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var bottom: float = BackdropPaint.row(198)
	EmberwoodStyle.paint_big_fern(image, Vector2(26.0, bottom), 84.0, 7241)
	EmberwoodStyle.paint_big_fern(image, Vector2(520.0, bottom), 64.0, 7242)
	EmberwoodStyle.paint_dead_tree(image, Vector2(396.0, BackdropPaint.STRIP_HEIGHT), 140.0, -0.14, 7243)
	BackdropPaint.paint_leaf_clump(image, Vector2(300.0, BackdropPaint.row(-8)), 5, PI * 0.5, 1.8, Vector2(26.0, 42.0), -0.6,
		EmberwoodStyle.FRONT_BODY, EmberwoodStyle.FRONT_LIT, EmberwoodStyle.FRONT_RIB, 7244)
	BackdropPaint.paint_leaf_clump(image, Vector2(610.0, BackdropPaint.row(-8)), 4, PI * 0.5, 1.6, Vector2(24.0, 38.0), 0.6,
		EmberwoodStyle.FRONT_BODY, EmberwoodStyle.FRONT_LIT, EmberwoodStyle.FRONT_RIB, 7245)
	return image

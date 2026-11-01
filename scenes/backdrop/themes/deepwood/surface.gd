class_name DeepwoodSurface
extends BackdropTheme
## DEEPWOOD, SURFACE: the floor of a very dense old forest at dawn. Through the
## leaves, luminous green mist; four rows of trees going back into it, each
## further one paler, with mist drifting between them (all shared with the
## skyline: DeepwoodStyle); faint mossy ledges hung with moss between the
## trunks, sunbeams slanting down, giant near trunks with roots on a turf bank,
## and right in front huge ferns, big leaves and moss hanging from above;
## spores glow and leaves fall. Everything solid is painted the way our ground is
## (BackdropTerrain). Layers far to near; see BackdropTheme.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const LEDGES_HAZE: float = 0.3
const SHAFT_COLOR: Color = Color(1.0, 0.95, 0.7, 0.09)
## Where the light shafts start (strip x).
const SHAFT_XS: Array[float] = [40.0, 170.0, 300.0, 480.0, 560.0]
## The giant near trunks: strip x of each one's left edge and its width.
const GIANTS: Array[Vector2i] = [Vector2i(60, 30), Vector2i(370, 38)]
const NEAR_FLOOR_ROW: int = 174


func _build_layers() -> void:
	DeepwoodStyle.add_shared_layers(self, SURFACE_SECTION)

	var spores: BackdropMotes = BackdropMotes.new()
	spores.shape = BackdropMotes.Shape.FIREFLY
	spores.mote_count = 18
	spores.colors = [Color(0.85, 1.0, 0.55, 0.9), Color(1.0, 0.92, 0.55, 0.8)]
	spores.velocity = Vector2(2.0, -2.5)
	spores.sway_amplitude = 4.0
	spores.sway_speed = 0.25
	spores.scroll_factor = 0.5
	spores.seed_value = 5201
	add_motes(spores)

	var leaves: BackdropMotes = BackdropMotes.new()
	leaves.shape = BackdropMotes.Shape.LEAF
	leaves.mote_count = 10
	leaves.colors = [Color(0.5, 0.7, 0.28, 0.8), Color(0.66, 0.6, 0.22, 0.75), Color(0.38, 0.55, 0.22, 0.8)]
	leaves.velocity = Vector2(4.0, 10.0)
	leaves.sway_amplitude = 6.0
	leaves.sway_speed = 0.35
	leaves.scroll_factor = 0.65
	leaves.seed_value = 5202
	add_motes(leaves)


## Slanted light shafts through the gaps (BackdropTheme.draw_light_shafts), a draw_extra.
static func draw_shafts(layer: BackdropLayer, copy_x: float, time: float) -> void:
	BackdropTheme.draw_light_shafts(layer, copy_x, time, SHAFT_XS, 9.0, 0.42, 230.0, SHAFT_COLOR)


## Faint mossy ledges between the trunks: floating chunks of turf in the ground's
## style, hung with moss, with ferns on top.
static func paint_moss_ledges() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var palette: Array[Color] = BackdropTerrain.hazed(DeepwoodStyle.TURF, DeepwoodStyle.AIR, LEDGES_HAZE)
	# Each: (left x, top screen row, width in tiles).
	var ledges: Array[Vector3i] = [Vector3i(20, 70, 6), Vector3i(150, 104, 4), Vector3i(250, 52, 5), Vector3i(420, 88, 7),
		Vector3i(540, 118, 4)]
	for ledge_index: int in ledges.size():
		var ledge: Vector3i = ledges[ledge_index]
		var top_row: int = BackdropPaint.row(ledge.y)
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(ledge.x - 2, top_row - 10, ledge.z * 6 + 4, 40))
		BackdropTerrain.add_chunk(mask, ledge.x, top_row, ledge.z, 3, 6, 5211 + ledge_index)
		BackdropTerrain.roughen(mask, 5211 + ledge_index)
		BackdropTerrain.paint(image, mask, palette, 3.0, 9.0, 2, 5211 + ledge_index)
		BackdropTerrain.paint_blades(image, mask, BackdropTerrain.hazed(DeepwoodStyle.BLADES, DeepwoodStyle.AIR, LEDGES_HAZE), 2, 3, 5211 + ledge_index)
		BackdropTerrain.paint_hanging(image, mask, DeepwoodStyle.far(DeepwoodStyle.MOSS, LEDGES_HAZE), 2, 16,
			DeepwoodStyle.far(DeepwoodStyle.MOSS_TIP, LEDGES_HAZE), 4, 5221 + ledge_index)
		# A little fern on top.
		var fern_base: Vector2 = Vector2(ledge.x + ledge.z * 3, top_row)
		for frond: int in 3:
			BackdropPaint.paint_frond(image, fern_base, -PI * 0.5 + (frond - 1) * 0.6, 9.0, (frond - 1) * 0.8, 3.0,
				DeepwoodStyle.far(DeepwoodStyle.TURF[BackdropTerrain.EDGE], LEDGES_HAZE),
				DeepwoodStyle.far(DeepwoodStyle.TURF[BackdropTerrain.CRUST], LEDGES_HAZE))
	return image


## The giant near trunks: bark pillars in the ground's style going up out of view,
## mossy shelf fungi on them, roots sprawling into a turf bank along the bottom.
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
	BackdropTerrain.roughen(trunks, 5231)
	BackdropTerrain.paint(image, trunks, DeepwoodStyle.BARK, 4.0, 10.0, 2, 5231)
	# Shelf fungi and moss tufts up the trunks (rim on their tops).
	for giant: Vector2i in GIANTS:
		for shelf: int in 3:
			var shelf_row: int = BackdropPaint.row(30 + shelf * 38 + (giant.x % 13))
			var side: int = -1 if (shelf + giant.x) % 2 == 0 else 1
			var shelf_x: int = giant.x - 6 if side < 0 else giant.x + giant.y - 2
			var fungus: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(shelf_x - 2, shelf_row - 2, 12, 8))
			fungus.add_circle(Vector2(shelf_x + 4, shelf_row + 3), 4.0)
			fungus.add_rect(Rect2i(shelf_x, shelf_row + 2, 9, 2))
			BackdropTerrain.paint(image, fungus, [Color(0.78, 0.66, 0.42), Color(0.92, 0.82, 0.55), Color(0.4, 0.3, 0.18),
				Color(0.3, 0.22, 0.14), Color(0.34, 0.25, 0.16), Color(0.2, 0.15, 0.1)] as Array[Color], 2.0, 3.0, 1, 5232 + shelf)
	# The turf bank they stand in.
	var bank: BackdropTerrain.Mask = BackdropTerrain.new_band(floor_row - 14, BackdropPaint.STRIP_HEIGHT + 6)
	bank.add_below(BackdropPaint.bumps(floor_row, Vector2(6.0, 12.0), 30, 5233))
	BackdropTerrain.roughen(bank, 5233)
	BackdropTerrain.paint(image, bank, DeepwoodStyle.TURF, 5.0, 10.0, 2, 5233)
	BackdropTerrain.paint_blades(image, bank, DeepwoodStyle.BLADES, 2, 4, 5233)
	return image


## Right in front: huge ferns rising from the bottom corners, a clump of big
## leaves, and moss and roots hanging in from above.
static func paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var bottom: float = BackdropPaint.row(198)
	DeepwoodStyle.paint_big_fern(image, Vector2(30.0, bottom), 90.0, 5241)
	DeepwoodStyle.paint_big_fern(image, Vector2(470.0, bottom), 70.0, 5242)
	BackdropPaint.paint_leaf_clump(image, Vector2(250.0, bottom + 4.0), 4, -PI * 0.5, 1.5, Vector2(30.0, 46.0), 0.7,
		DeepwoodStyle.FRONT_BODY, DeepwoodStyle.FRONT_LIT, DeepwoodStyle.FRONT_RIB, 5243)
	DeepwoodStyle.paint_front_moss(image, 120, 210, 70, 5244)
	DeepwoodStyle.paint_front_moss(image, 520, 600, 50, 5245)
	BackdropPaint.paint_leaf_clump(image, Vector2(160.0, BackdropPaint.row(-8)), 5, PI * 0.5, 1.8, Vector2(28.0, 44.0), -0.6,
		DeepwoodStyle.FRONT_BODY, DeepwoodStyle.FRONT_LIT, DeepwoodStyle.FRONT_RIB, 5246)
	return image

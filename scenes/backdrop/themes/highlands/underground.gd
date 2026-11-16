class_name HighlandsUnderground
extends BackdropTheme
## HIGHLANDS, "UNDERGROUND": down among the valley's meadows, at midday. There
## is no ground to break through here (the valley's floor is under the same
## sky), so every change to and from it is SOFT (Backdrop.SOFT_UNDERGROUND_LOOKS)
## and the tall layers run on from the surface (HighlandsStyle.add_tall_layers):
## the nearest hill's green fills the back. In front of it, four terraces of
## meadow going down and nearer, each greener and bigger than the one behind,
## with hedgerows, round trees, a fence and drifts of flowers; and right in front
## tall grass bent by the wind, wildflowers and broad leaves. Pollen floats,
## petals blow past, the wind streaks by. Everything solid is painted the way our
## ground is (BackdropTerrain). Layers far to near; see BackdropTheme.
## (Above: surface.gd, over the hills; higher: skyline.gd, the cliffs.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The meadow terraces, far to near: their lowest top (screen row), how high
## their waves rise (px), how many waves along the strip and where the first
## starts (radians), their haze and scroll.
const MEADOW_TOP_ROWS: Array[int] = [18, 60, 104, 152]
const MEADOW_WAVE_HEIGHTS: Array[float] = [10.0, 14.0, 18.0, 22.0]
const MEADOW_WAVE_COUNTS: Array[int] = [4, 3, 3, 2]
const MEADOW_WAVE_PHASES: Array[float] = [1.0, 3.1, 0.2, 4.4]
const MEADOW_HAZES: Array[float] = [0.5, 0.36, 0.2, 0.06]
const MEADOW_SCROLLS: Array[Vector2] = [Vector2(0.22, 0.07), Vector2(0.28, 0.09), Vector2(0.36, 0.12), Vector2(0.46, 0.15)]
## Per terrace: how many trees and their crown radius, one flower per how many
## top pixels and their tallest stalk, whether hedgerows run along it.
const MEADOW_TREE_COUNTS: Array[int] = [3, 2, 1, 1]
const MEADOW_TREE_RADII: Array[float] = [5.0, 7.0, 10.0, 14.0]
const MEADOW_FLOWER_EVERY: Array[int] = [10, 7, 5, 4]
const MEADOW_FLOWER_HEIGHTS: Array[int] = [1, 1, 2, 3]
const MEADOW_HEDGES: Array[bool] = [true, true, false, false]
## A hedgerow bush every so many px, where the hedge noise is over HEDGE_SHARE.
const HEDGE_SPACING: int = 9
const HEDGE_SHARE: float = 0.45
## The fence on terrace 2: from and to strip x, a post every so many px.
const FENCE_TERRACE: int = 2
const FENCE_FROM_X: int = 360
const FENCE_TO_X: int = 540
const FENCE_POST_EVERY: int = 14
const FENCE_SIZE: float = 1.2

## Wildflowers in front: Vector3(strip x of the foot, height, head radius).
const FRONT_FLOWERS: Array[Vector3] = [Vector3(118.0, 42.0, 4.0), Vector3(140.0, 32.0, 3.0), Vector3(452.0, 46.0, 4.0)]


func _build_layers() -> void:
	HighlandsStyle.add_tall_layers(self, UNDERGROUND_SECTION)
	for terrace: int in MEADOW_TOP_ROWS.size():
		add_painted_layer("Meadow%d" % terrace, MEADOW_SCROLLS[terrace], _paint_meadow.bind(terrace))
	add_painted_layer("Front", HighlandsStyle.FRONT_SCROLL, _paint_front)

	var pollen: BackdropMotes = BackdropMotes.new()
	pollen.shape = BackdropMotes.Shape.DOT
	pollen.mote_count = 24
	pollen.colors = [Color(1.0, 1.0, 0.85, 0.7), Color(1.0, 0.95, 0.6, 0.6)]
	pollen.velocity = Vector2(6.0, -2.0)
	pollen.sway_amplitude = 4.0
	pollen.sway_speed = 0.3
	pollen.scroll_factor = 0.5
	pollen.seed_value = 8401
	add_motes(pollen)

	var petals: BackdropMotes = BackdropMotes.new()
	petals.shape = BackdropMotes.Shape.LEAF
	petals.mote_count = 10
	petals.colors = [Color(1.0, 0.75, 0.85, 0.85), Color(1.0, 1.0, 0.95, 0.85), Color(1.0, 0.9, 0.45, 0.8)]
	petals.velocity = Vector2(22.0, 6.0)
	petals.sway_amplitude = 6.0
	petals.sway_speed = 0.35
	petals.scroll_factor = 0.65
	petals.seed_value = 8402
	add_motes(petals)

	var wind: BackdropMotes = BackdropMotes.new()
	wind.shape = BackdropMotes.Shape.STREAK
	wind.mote_count = 6
	wind.colors = [Color(1.0, 1.0, 1.0, 0.18), Color(1.0, 1.0, 1.0, 0.28)]
	wind.velocity = Vector2(55.0, 2.0)
	wind.size_range = Vector2i(3, 6)
	wind.scroll_factor = 0.5
	wind.seed_value = 8403
	add_motes(wind)


## One meadow terrace (MEADOW_TOP_ROWS[terrace]): its trees, the turf over their
## feet (down past the strip's bottom: the next terrace covers it), hedgerows,
## a fence on one, grass and flowers.
static func _paint_meadow(terrace: int) -> Image:
	var image: Image = BackdropPaint.new_strip()
	var haze: float = MEADOW_HAZES[terrace]
	var seed_value: int = 8410 + terrace * 10
	var tops: PackedFloat32Array = HighlandsStyle.hill_tops(BackdropPaint.row(MEADOW_TOP_ROWS[terrace]), MEADOW_WAVE_HEIGHTS[terrace],
		MEADOW_WAVE_COUNTS[terrace], MEADOW_WAVE_PHASES[terrace], seed_value)
	var tree_count: int = MEADOW_TREE_COUNTS[terrace]
	for tree_index: int in tree_count:
		var stretch: float = float(BackdropPaint.STRIP_WIDTH) / tree_count
		var tree_x: int = roundi((tree_index + 0.15 + BackdropPaint.random01(tree_index, 1, seed_value) * 0.7) * stretch)
		var radius: float = MEADOW_TREE_RADII[terrace] * (0.8 + BackdropPaint.random01(tree_index, 2, seed_value) * 0.4)
		HighlandsStyle.paint_tree(image, Vector2(tree_x, tops[posmod(tree_x, BackdropPaint.STRIP_WIDTH)]), radius, haze, seed_value + tree_index)
	if terrace == FENCE_TERRACE:
		HighlandsStyle.paint_fence(image, tops, FENCE_FROM_X, FENCE_TO_X, FENCE_POST_EVERY, FENCE_SIZE, haze)
	var turf: Array[Color] = BackdropTerrain.hazed(HighlandsStyle.TURF, HighlandsStyle.AIR, haze)
	var meadow: BackdropTerrain.Mask = HighlandsStyle.paint_swell(image, tops, BackdropPaint.STRIP_HEIGHT + 40, turf,
		3.0 + terrace * 0.7, 14.0, 1 + terrace / 2, seed_value)
	if MEADOW_HEDGES[terrace]:
		_paint_hedges(image, tops, haze, seed_value + 5)
	BackdropTerrain.paint_blades(image, meadow, BackdropTerrain.hazed(HighlandsStyle.BLADES, HighlandsStyle.AIR, haze), 2, 2 + terrace,
		seed_value + 1)
	BackdropTerrain.paint_blades(image, meadow, BackdropTerrain.hazed(HighlandsStyle.FLOWERS, HighlandsStyle.AIR, haze),
		MEADOW_FLOWER_EVERY[terrace], MEADOW_FLOWER_HEIGHTS[terrace], seed_value + 2)
	return image


## Hedgerows along a terrace's top `tops`: runs of round leafy bushes where a slow
## noise says so (gaps between them), in the ground's style.
static func _paint_hedges(image: Image, tops: PackedFloat32Array, haze: float, seed_value: int) -> void:
	var hedges: BackdropTerrain.Mask = BackdropTerrain.new_band(BackdropPaint.row(-20), BackdropPaint.STRIP_HEIGHT)
	var any_bush: bool = false
	for x: int in range(0, BackdropPaint.STRIP_WIDTH, HEDGE_SPACING):
		if BackdropPaint.periodic_noise(x, 80.0, seed_value) < HEDGE_SHARE:
			continue
		var radius: float = 4.0 + BackdropPaint.random01(x, 1, seed_value) * 2.5
		for wrap_offset: int in [-BackdropPaint.STRIP_WIDTH, 0, BackdropPaint.STRIP_WIDTH]:
			hedges.add_circle(Vector2(x + wrap_offset, tops[x] - radius * 0.5), radius)
		any_bush = true
	if not any_bush:
		return
	BackdropTerrain.paint(image, hedges, BackdropTerrain.hazed(HighlandsStyle.LEAVES, HighlandsStyle.AIR, haze), 2.0, 5.0, 1, seed_value)


## Right in front: tufts of tall grass bent by the wind, a few wildflowers on
## long stalks, and a clump of broad leaves, all rising from the bottom.
static func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var bottom: float = BackdropPaint.row(200)
	# Short: the strip scrolls, so anything tall crosses the middle of the screen.
	HighlandsStyle.paint_grass_tuft(image, Vector2(40.0, bottom), 46.0, 8441)
	HighlandsStyle.paint_grass_tuft(image, Vector2(330.0, bottom), 38.0, 8442)
	BackdropPaint.paint_leaf_clump(image, Vector2(540.0, bottom + 4.0), 4, -PI * 0.5, 1.4, Vector2(30.0, 44.0), 0.6,
		HighlandsStyle.FRONT_BODY, HighlandsStyle.FRONT_LIT, HighlandsStyle.FRONT_RIB, 8443)
	for flower: Vector3 in FRONT_FLOWERS:
		# A stalk curving with the wind, a round head with a lit top-left pixel.
		var foot: Vector2 = Vector2(flower.x, bottom)
		var head: Vector2 = foot + Vector2(flower.y * 0.18, -flower.y)
		var control: Vector2 = foot + Vector2(-2.0, -flower.y * 0.5)
		var steps: int = roundi(flower.y)
		for step: int in steps:
			var point: Vector2 = BackdropPaint.curve_point(foot, control, head, float(step) / steps)
			BackdropPaint.put_rect(image, Rect2i(roundi(point.x), roundi(point.y), 2, 1), HighlandsStyle.FRONT_BODY)
		BackdropPaint.put_circle(image, head, flower.z, HighlandsStyle.FRONT_LIT)
		BackdropPaint.put_pixel(image, roundi(head.x - flower.z * 0.5), roundi(head.y - flower.z * 0.5), HighlandsStyle.FRONT_RIB)
	return image

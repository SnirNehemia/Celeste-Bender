extends BackdropTheme
## SANCTUM, UNDERGROUND: the undercroft beneath the courtyards, light, not gloomy.
## Pale sandstone halls lit from above through light wells: a warm back wall with
## tall arches into further halls, sunlight falling in shafts, faint stone ledges
## with urns and candles (in the ground's style, BackdropTerrain), a still
## reflecting pool along the bottom that ripples and glints, carved pillars banded
## with gold, and right in front ivy pouring down from a well and a fallen arch
## stone; dust hangs in the light. Layers far to near; see BackdropTheme.

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The undercroft's air: what far things fade into, warm and bright.
const HAZE: Color = Color(0.82, 0.74, 0.62)
const WALL_BANDS: Array[Color] = [Color(0.88, 0.8, 0.66), Color(0.84, 0.76, 0.62), Color(0.79, 0.71, 0.58),
	Color(0.74, 0.65, 0.54), Color(0.68, 0.59, 0.5), Color(0.62, 0.53, 0.46)]
## Sandstone in the ground's style: [crust, rim, edge, inside, hatch, deep].
const SANDSTONE: Array[Color] = [Color(0.9, 0.8, 0.62), Color(0.98, 0.92, 0.76), Color(0.62, 0.49, 0.37),
	Color(0.66, 0.54, 0.44), Color(0.71, 0.59, 0.48), Color(0.54, 0.43, 0.37)]
const ARCH_FAR: Color = Color(0.94, 0.88, 0.74)
const ARCH_DEEP: Color = Color(0.72, 0.62, 0.52)
const WELL_LIGHT: Color = Color(1.0, 0.98, 0.88)
const SHAFT_COLOR: Color = Color(1.0, 0.96, 0.8, 0.16)
const POOL: Color = Color(0.36, 0.62, 0.62)
const POOL_DEEP: Color = Color(0.25, 0.47, 0.5)
const POOL_GLINT: Color = Color(0.9, 1.0, 0.95, 0.85)
const CANDLE_FLAME: Color = Color(1.0, 0.82, 0.4)
const CANDLE_GLOW: Color = Color(1.0, 0.8, 0.45, 0.12)
const URN: Color = Color(0.56, 0.4, 0.32)
const URN_LIT: Color = Color(0.72, 0.54, 0.4)
const PILLAR: Color = Color(0.72, 0.62, 0.5)
const PILLAR_LIT: Color = Color(0.86, 0.77, 0.62)
const PILLAR_SHADE: Color = Color(0.56, 0.47, 0.4)
const FRONT_STONE: Color = Color(0.36, 0.3, 0.3)
const FRONT_STONE_LIT: Color = Color(0.48, 0.4, 0.38)

const ARCHES_HAZE: float = 0.25
const LEDGES_HAZE: float = 0.4
## The light wells: strip x of each opening in the ceiling.
const WELL_XS: Array[float] = [90.0, 300.0, 470.0]
## The pool's surface (screen row) and the candles' flames (strip x, screen row).
const POOL_ROW: int = 160
const CANDLES: Array[Vector2] = [Vector2(48.0, 96.0), Vector2(196.0, 62.0), Vector2(372.0, 104.0), Vector2(560.0, 78.0)]


func _build_layers() -> void:
	# The band broken through on the way up: [body, lit rim] (BackdropTheme).
	crust_colors = [SanctumStyle.BARE_MARBLE[BackdropTerrain.EDGE], SanctumStyle.BARE_MARBLE[BackdropTerrain.CRUST]]
	add_painted_layer("BackWall", Vector2(0.03, 0.01), _paint_back_wall)
	add_painted_layer("Arches", Vector2(0.08, 0.03), _paint_arches)
	add_drawn_layer("Shafts", Vector2(0.1, 0.03), func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		BackdropTheme.draw_light_shafts(layer, copy_x, time, WELL_XS, 16.0, 0.12, 230.0, SHAFT_COLOR))
	var ledges: BackdropLayer = add_painted_layer("Ledges", Vector2(0.18, 0.06), _paint_ledges)
	ledges.draw_extra = _draw_candles
	var pool: BackdropLayer = add_painted_layer("Pool", Vector2(0.26, 0.08), _paint_pool)
	pool.draw_extra = _draw_ripples
	add_painted_layer("Pillars", Vector2(0.4, 0.13), _paint_pillars)
	add_painted_layer("Front", SanctumStyle.FRONT_SCROLL, _paint_front)

	var dust: BackdropMotes = BackdropMotes.new()
	dust.mote_count = 26
	dust.colors = [Color(1.0, 0.97, 0.85, 0.7), Color(1.0, 0.9, 0.7, 0.5)]
	dust.velocity = Vector2(1.0, 1.5)
	dust.sway_amplitude = 3.0
	dust.sway_speed = 0.15
	dust.scroll_factor = 0.35
	dust.seed_value = 4401
	add_motes(dust)


## The far wall: warm bands, brighter up high where the wells let light in, faint
## courses of big blocks; the vaulted ceiling across the top in the ground's style,
## pierced by the light wells: round openings full of bright sky.
func _paint_back_wall() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, WALL_BANDS, BackdropPaint.row(0), BackdropPaint.row(180))
	# Courses of big stone blocks: a faint line every 18 rows, joints staggered.
	for course_row: int in range(BackdropPaint.row(30), BackdropPaint.STRIP_HEIGHT, 18):
		var joint_color: Color = Color(WALL_BANDS[5], 0.18)
		for x: int in BackdropPaint.STRIP_WIDTH:
			BackdropPaint.blend_pixel(image, x, course_row, joint_color)
		var offset: int = 0 if (course_row / 18) % 2 == 0 else 26
		for joint_x: int in range(offset, BackdropPaint.STRIP_WIDTH, 52):
			for y: int in range(course_row + 1, course_row + 18):
				BackdropPaint.blend_pixel(image, joint_x, y, joint_color)
	# The ceiling: a heavy vault hanging down to around row 24, lower between wells.
	var ceiling: PackedFloat32Array = PackedFloat32Array()
	ceiling.resize(BackdropPaint.STRIP_WIDTH)
	for x: int in BackdropPaint.STRIP_WIDTH:
		var to_well: float = 999.0
		for well_x: float in WELL_XS:
			var gap: float = absf(x - (well_x + 8.0))
			to_well = minf(to_well, minf(gap, BackdropPaint.STRIP_WIDTH - gap))
		# Vaults: arcs that sag lowest halfway between two wells.
		ceiling[x] = BackdropPaint.row(14) + minf(to_well, 90.0) * 0.16 + (BackdropPaint.periodic_noise(x, 30.0, 4412) - 0.5) * 3.0
	var mask: BackdropTerrain.Mask = BackdropTerrain.new_band(0, BackdropPaint.row(40))
	mask.add_above(ceiling)
	BackdropTerrain.roughen(mask, 4411)
	BackdropTerrain.paint(image, mask, BackdropTerrain.hazed(SANDSTONE, HAZE, 0.15), 4.0, 10.0, 1, 4411)
	BackdropTerrain.paint_hanging(image, mask, SanctumStyle.IVY.lerp(HAZE, 0.2), 7, 14, SanctumStyle.BLOSSOM, 5, 4413)
	for well_x: float in WELL_XS:
		# The opening: sky blue fading to white at its bottom, framed in pale stone.
		var middle: Vector2 = Vector2(well_x + 8.0, BackdropPaint.row(6))
		BackdropPaint.put_circle(image, middle, 13.0, SANDSTONE[BackdropTerrain.RIM])
		BackdropPaint.put_circle(image, middle, 11.0, SanctumStyle.SKY_BANDS[4])
		BackdropPaint.put_circle(image, middle + Vector2(0.0, 3.0), 9.0, SanctumStyle.SKY_BANDS[7])
		BackdropPaint.put_circle(image, middle + Vector2(0.0, 6.0), 6.0, WELL_LIGHT)
	return image


## Tall arches into further halls: bright openings (the next hall is lit too) with
## a deeper shade at their foot, set in the wall between pilasters.
func _paint_arches() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var spacing: int = 80
	for arch_index: int in BackdropPaint.STRIP_WIDTH / spacing:
		var middle: int = arch_index * spacing + spacing / 2
		var half: int = 14
		var spring_row: int = BackdropPaint.row(64)
		var foot_row: int = BackdropPaint.row(150)
		var far: Color = ARCH_FAR.lerp(HAZE, ARCHES_HAZE)
		BackdropPaint.put_rect(image, Rect2i(middle - half, spring_row, half * 2, foot_row - spring_row), far)
		BackdropPaint.put_circle(image, Vector2(middle, spring_row), half, far, spring_row)
		# The far hall's floor and a far arch inside it.
		BackdropPaint.put_rect(image, Rect2i(middle - half, foot_row - 22, half * 2, 22), ARCH_DEEP.lerp(HAZE, ARCHES_HAZE))
		BackdropPaint.put_rect(image, Rect2i(middle - 5, spring_row + 20, 10, foot_row - spring_row - 42), ARCH_DEEP.lerp(HAZE, 0.5))
		BackdropPaint.put_circle(image, Vector2(middle, spring_row + 20), 5.0, ARCH_DEEP.lerp(HAZE, 0.5), spring_row + 20)
		# The arch's frame: voussoirs (wedge stones) round the top, a rim down the sides.
		var frame: Color = SANDSTONE[BackdropTerrain.CRUST].lerp(HAZE, ARCHES_HAZE)
		var frame_line: Color = SANDSTONE[BackdropTerrain.EDGE].lerp(HAZE, ARCHES_HAZE + 0.2)
		for angle_step: int in 13:
			var angle: float = PI + angle_step * PI / 12.0
			var inner: Vector2 = Vector2(middle, spring_row) + Vector2(cos(angle), sin(angle)) * (half + 1)
			var outer: Vector2 = Vector2(middle, spring_row) + Vector2(cos(angle), sin(angle)) * (half + 5)
			BackdropPaint.put_line(image, inner, outer, frame_line if angle_step % 2 == 0 else frame, 2)
		for side: int in [-1, 1]:
			BackdropPaint.put_rect(image, Rect2i(middle + side * (half + 1) - (3 if side < 0 else 0), spring_row, 3, foot_row - spring_row), frame)
	return image


## Faint stone ledges at different heights in the ground's style, with urns.
func _paint_ledges() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var palette: Array[Color] = BackdropTerrain.hazed(SANDSTONE, HAZE, LEDGES_HAZE)
	for candle_index: int in CANDLES.size():
		var candle: Vector2 = CANDLES[candle_index]
		var top_row: int = BackdropPaint.row(candle.y + 6.0)
		var width_tiles: int = 5 + candle_index % 3
		var left: int = roundi(candle.x) - 14
		var mask: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(left - 2, top_row - 8, width_tiles * 6 + 4, 40))
		BackdropTerrain.add_chunk(mask, left, top_row, width_tiles, 4, 6, 4421 + candle_index)
		BackdropTerrain.roughen(mask, 4421 + candle_index)
		BackdropTerrain.paint(image, mask, palette, 3.0, 9.0, 1, 4421 + candle_index)
		BackdropTerrain.paint_hanging(image, mask, SanctumStyle.IVY.lerp(HAZE, LEDGES_HAZE), 7, 10,
			SanctumStyle.BLOSSOM.lerp(HAZE, LEDGES_HAZE), 0, 4421 + candle_index)
		# A candle on a holder and an urn beside it.
		BackdropPaint.put_rect(image, Rect2i(roundi(candle.x), top_row - 5, 2, 5), Color(0.96, 0.92, 0.82).lerp(HAZE, LEDGES_HAZE))
		var urn_x: int = roundi(candle.x) + 10
		BackdropPaint.put_circle(image, Vector2(urn_x, top_row - 5), 4.0, URN.lerp(HAZE, LEDGES_HAZE))
		BackdropPaint.put_circle(image, Vector2(urn_x - 1, top_row - 6), 2.0, URN_LIT.lerp(HAZE, LEDGES_HAZE))
		BackdropPaint.put_rect(image, Rect2i(urn_x - 2, top_row - 11, 5, 2), URN.lerp(HAZE, LEDGES_HAZE))
	return image


## The candles' flames, flickering, with a soft glow.
func _draw_candles(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for candle_index: int in CANDLES.size():
		var candle: Vector2 = CANDLES[candle_index]
		var flame: Vector2 = Vector2(copy_x + candle.x + 1.0, BackdropPaint.row(candle.y))
		var flicker: float = 0.75 + 0.25 * sin(time * 9.0 + candle_index * 2.3) * sin(time * 3.7 + candle_index)
		BackdropTheme.draw_glow(layer, flame, 9.0, CANDLE_GLOW, flicker)
		layer.draw_rect(Rect2(flame + Vector2(-0.5, -1.0 - roundf(flicker)), Vector2(1.0, 2.0 + roundf(flicker))), CANDLE_FLAME)


## The reflecting pool along the bottom: still water with the arches' pale
## reflections in it, under a stone lip.
func _paint_pool() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var surface: int = BackdropPaint.row(POOL_ROW)
	BackdropPaint.put_rect(image, Rect2i(0, surface, BackdropPaint.STRIP_WIDTH, BackdropPaint.STRIP_HEIGHT - surface), POOL)
	BackdropPaint.put_rect(image, Rect2i(0, surface + 12, BackdropPaint.STRIP_WIDTH, BackdropPaint.STRIP_HEIGHT), POOL_DEEP)
	for x: int in BackdropPaint.STRIP_WIDTH:
		if BackdropPaint.checker(x, surface + 11):
			BackdropPaint.put_pixel(image, x, surface + 11, POOL_DEEP)
	# Reflections of the light wells: pale broken columns in the water.
	for well_x: float in WELL_XS:
		for y: int in range(surface + 1, surface + 22):
			if (y / 2) % 2 == 0:
				BackdropPaint.put_rect(image, Rect2i(roundi(well_x) + (y % 3) - 1, y, 14 - (y - surface) / 3, 1), POOL.lightened(0.35))
	# The stone lip, in the ground's style, with breaks where steps go down.
	var lip: BackdropTerrain.Mask = BackdropTerrain.new_band(surface - 6, surface + 2)
	for x: int in range(-BackdropTerrain.BAND_SPARE, BackdropPaint.STRIP_WIDTH + BackdropTerrain.BAND_SPARE):
		if posmod(x, 160) < 120:
			lip.add_rect(Rect2i(x, surface - 4, 1, 6))
	BackdropTerrain.roughen(lip, 4431)
	BackdropTerrain.paint(image, lip, SANDSTONE, 2.0, 4.0, 1, 4431)
	return image


## Ripples: short bright lines that slide and blink on the water.
func _draw_ripples(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for ripple_index: int in 18:
		var row_offset: int = 3 + (ripple_index * 7) % 26
		var drift: float = fposmod(ripple_index * 37.0 + time * (4.0 + ripple_index % 3), BackdropPaint.STRIP_WIDTH)
		var shimmer: float = 0.5 + 0.5 * sin(time * 1.6 + ripple_index * 1.3)
		var length: float = 3.0 + (ripple_index % 4) * 2.0
		layer.draw_rect(Rect2(copy_x + roundf(drift), BackdropPaint.row(POOL_ROW) + row_offset, length, 1.0),
			Color(POOL_GLINT, POOL_GLINT.a * shimmer))


## Carved pillars: lit left faces, gold bands, ivy; set far apart.
func _paint_pillars() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for pillar_x: int in [150, 410]:
		BackdropPaint.put_rect(image, Rect2i(pillar_x, 0, 22, BackdropPaint.STRIP_HEIGHT), PILLAR)
		BackdropPaint.put_rect(image, Rect2i(pillar_x, 0, 3, BackdropPaint.STRIP_HEIGHT), PILLAR_LIT)
		BackdropPaint.put_rect(image, Rect2i(pillar_x + 17, 0, 5, BackdropPaint.STRIP_HEIGHT), PILLAR_SHADE)
		for band_row: int in [BackdropPaint.row(40), BackdropPaint.row(118)]:
			BackdropPaint.put_rect(image, Rect2i(pillar_x - 1, band_row, 24, 4), SanctumStyle.GOLD)
			BackdropPaint.put_rect(image, Rect2i(pillar_x - 1, band_row, 24, 1), SanctumStyle.GOLD_LIT)
			# Glyphs carved in the band.
			for glyph: int in 4:
				BackdropPaint.put_rect(image, Rect2i(pillar_x + 2 + glyph * 5, band_row + 2, 2, 1), SanctumStyle.GOLD.darkened(0.3))
		var ivy: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(pillar_x, BackdropPaint.row(40), 22, 4))
		ivy.add_rect(Rect2i(pillar_x, BackdropPaint.row(40), 22, 4))
		BackdropTerrain.paint_hanging(image, ivy, SanctumStyle.IVY, 3, 40, SanctumStyle.BLOSSOM, 5, 4441 + pillar_x)
	return image


## Right in front: ivy pouring down from a well above, and a fallen arch stone in a
## bottom corner, both in shade.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var curtain: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(46, 0, 56, BackdropPaint.row(-2)))
	curtain.add_rect(Rect2i(46, 0, 56, BackdropPaint.row(-2)))
	BackdropTerrain.paint_hanging(image, curtain, SanctumStyle.FRONT_LEAF, 3, 100, SanctumStyle.FRONT_LEAF_LIT, 3, 4451)
	BackdropPaint.paint_leaf_clump(image, Vector2(75.0, BackdropPaint.row(-6)), 6, PI * 0.5, 1.8, Vector2(18.0, 34.0), -0.5,
		SanctumStyle.FRONT_LEAF, SanctumStyle.FRONT_LEAF_LIT, SanctumStyle.FRONT_LEAF_RIB, 4452)
	# The fallen stone: a wedge of arch in the ground's style, dark.
	var stone: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(430, BackdropPaint.row(140), 120, 70))
	stone.add_line(Vector2(450.0, BackdropPaint.row(190)), Vector2(520.0, BackdropPaint.row(168)), 30.0)
	stone.add_rect(Rect2i(470, BackdropPaint.row(176), 70, 40))
	BackdropTerrain.roughen(stone, 4453)
	var palette: Array[Color] = [FRONT_STONE_LIT, SanctumStyle.FRONT_LEAF_LIT, FRONT_STONE.darkened(0.3), FRONT_STONE.darkened(0.45),
		FRONT_STONE.darkened(0.35), FRONT_STONE.darkened(0.7)]
	BackdropTerrain.paint(image, stone, palette, 4.0, 8.0, 2, 4453)
	BackdropTerrain.paint_blades(image, stone, [SanctumStyle.FRONT_LEAF, SanctumStyle.FRONT_LEAF_LIT] as Array[Color], 2, 5, 4453)
	return image

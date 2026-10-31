extends BackdropTheme
## TEMPLE, UNDERGROUND: the catacombs under the temple. A wall of burial niches,
## some with candles, a row of low vaults on thin columns, and near hanging chains,
## stone coffins and rubble; dust hangs in the air. Layers far to near; see
## BackdropTheme. (Surface: surface.gd, the hall; high up: skyline.gd, the roofs.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

const WALL_BANDS: Array[Color] = [Color(0.04, 0.03, 0.05), Color(0.06, 0.05, 0.07), Color(0.08, 0.06, 0.09),
	Color(0.06, 0.05, 0.07), Color(0.04, 0.03, 0.05)]
const BRICK_LINE: Color = Color(0.03, 0.02, 0.04)
const NICHE_DARK: Color = Color(0.015, 0.01, 0.02)
const NICHE_LIP: Color = Color(0.12, 0.1, 0.13)
const BONE_COLOR: Color = Color(0.22, 0.2, 0.18)

const VAULT_BODY: Color = Color(0.09, 0.07, 0.11)
const VAULT_LIT: Color = Color(0.15, 0.12, 0.17)
const VAULT_DARK: Color = Color(0.05, 0.04, 0.06)

const NEAR_BODY: Color = Color(0.035, 0.03, 0.045)
const NEAR_LIT: Color = Color(0.1, 0.08, 0.11)

const CANDLE_FLAME: Color = Color(1.0, 0.78, 0.4)
const CANDLE_GLOW: Color = Color(1.0, 0.6, 0.25, 0.07)

## Niche grid on the far wall: columns per strip, rows, size and spacing.
const NICHE_COLUMNS: int = 16
const NICHE_ROWS: int = 4
const NICHE_SIZE: Vector2i = Vector2i(22, 12)
const NICHE_FIRST_SCREEN_ROW: int = 30
const NICHE_ROW_SPACING: int = 30


func _build_layers() -> void:
	crust_colors = [TempleStyle.STONE_BODY, TempleStyle.STONE_LIT]
	var wall: BackdropLayer = add_painted_layer("Niches", Vector2(0.05, 0.02), _paint_niches)
	wall.draw_extra = _draw_candles
	add_painted_layer("Vaults", Vector2(0.18, 0.06), _paint_vaults)
	add_painted_layer("Crypt", Vector2(0.42, 0.13), _paint_crypt)
	add_painted_layer("Front", TempleStyle.FRONT_SCROLL, _paint_front)

	var dust: BackdropMotes = BackdropMotes.new()
	dust.mote_count = 20
	dust.colors = [Color(0.9, 0.8, 0.65, 0.2), Color(0.9, 0.8, 0.65, 0.1)]
	dust.velocity = Vector2(1.0, 1.5)
	dust.sway_amplitude = 2.0
	dust.sway_speed = 0.12
	dust.scroll_factor = 0.5
	dust.seed_value = 211
	add_motes(dust)


## Is there a candle in this niche? (Every few, by hash, the same every run.)
static func _has_candle(column: int, niche_row: int) -> bool:
	return BackdropPaint.random01(column, niche_row, 212) > 0.8


func _paint_niches() -> Image:
	var image: Image = BackdropPaint.new_strip()
	BackdropPaint.paint_bands(image, WALL_BANDS, 0, BackdropPaint.STRIP_HEIGHT)
	# Stone courses: a dark line every 10 rows, joints staggered.
	for y: int in range(0, BackdropPaint.STRIP_HEIGHT, 10):
		image.fill_rect(Rect2i(0, y, BackdropPaint.STRIP_WIDTH, 1), BRICK_LINE)
		for x: int in range((y / 10) % 2 * 12, BackdropPaint.STRIP_WIDTH, 24):
			image.fill_rect(Rect2i(x, y, 1, 10), BRICK_LINE)
	var spacing: int = BackdropPaint.STRIP_WIDTH / NICHE_COLUMNS
	for niche_row: int in NICHE_ROWS:
		var top: int = BackdropPaint.row(NICHE_FIRST_SCREEN_ROW + niche_row * NICHE_ROW_SPACING)
		for column: int in NICHE_COLUMNS:
			var left: int = column * spacing + (spacing - NICHE_SIZE.x) / 2
			# A dark opening with a rounded top and a lit lip along its bottom.
			BackdropPaint.put_rect(image, Rect2i(left + 2, top, NICHE_SIZE.x - 4, 1), NICHE_DARK)
			BackdropPaint.put_rect(image, Rect2i(left, top + 1, NICHE_SIZE.x, NICHE_SIZE.y - 1), NICHE_DARK)
			BackdropPaint.put_rect(image, Rect2i(left - 1, top + NICHE_SIZE.y, NICHE_SIZE.x + 2, 1), NICHE_LIP)
			# Old bones inside some: a skull and a long bone.
			if not _has_candle(column, niche_row) and BackdropPaint.random01(column, niche_row, 213) > 0.5:
				BackdropPaint.put_rect(image, Rect2i(left + 3, top + NICHE_SIZE.y - 4, 4, 3), BONE_COLOR)
				BackdropPaint.put_pixel(image, left + 4, top + NICHE_SIZE.y - 3, NICHE_DARK)
				BackdropPaint.put_rect(image, Rect2i(left + 9, top + NICHE_SIZE.y - 2, 10, 1), BONE_COLOR)
	return image


## A small candle flame and glow in some niches, flickering.
func _draw_candles(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var spacing: int = BackdropPaint.STRIP_WIDTH / NICHE_COLUMNS
	for niche_row: int in NICHE_ROWS:
		var floor_row: float = BackdropPaint.row(NICHE_FIRST_SCREEN_ROW + niche_row * NICHE_ROW_SPACING) + NICHE_SIZE.y
		for column: int in NICHE_COLUMNS:
			if not _has_candle(column, niche_row):
				continue
			var spot: Vector2 = Vector2(copy_x + column * spacing + spacing * 0.5, floor_row)
			var flicker: float = 0.75 + 0.15 * sin(time * 11.0 + column) + 0.1 * sin(time * 27.0 + niche_row * 3.0)
			BackdropTheme.draw_glow(layer, spot + Vector2(0, -5), 14.0, CANDLE_GLOW, flicker)
			layer.draw_rect(Rect2(spot + Vector2(-1, -4), Vector2(2, 4)), NICHE_LIP)
			layer.draw_rect(Rect2(spot + Vector2(-1, -6 - roundf(flicker)), Vector2(1, 2)), CANDLE_FLAME)


## Low vaults: a ceiling cut into a row of round arches, resting on thin columns.
func _paint_vaults() -> Image:
	var image: Image = BackdropPaint.new_strip()
	var arch_count: int = 8
	var spacing: int = BackdropPaint.STRIP_WIDTH / arch_count
	var spring_row: int = BackdropPaint.row(34)
	var bottoms: PackedFloat32Array = PackedFloat32Array()
	bottoms.resize(BackdropPaint.STRIP_WIDTH)
	for x: int in BackdropPaint.STRIP_WIDTH:
		# Distance from the nearest column, 0..1: the arch is a half ellipse.
		var along: float = float(posmod(x, spacing)) / spacing * 2.0 - 1.0
		bottoms[x] = spring_row - sqrt(maxf(0.0, 1.0 - along * along)) * 22.0
	BackdropPaint.fill_above(image, bottoms, VAULT_BODY)
	BackdropPaint.paint_bottom_rim(image, bottoms, VAULT_LIT)
	for column_index: int in arch_count:
		var x: int = column_index * spacing
		BackdropPaint.put_rect(image, Rect2i(x - 4, spring_row, 9, BackdropPaint.STRIP_HEIGHT - spring_row), VAULT_BODY)
		BackdropPaint.put_rect(image, Rect2i(x - 4, spring_row, 2, BackdropPaint.STRIP_HEIGHT - spring_row), VAULT_LIT)
		BackdropPaint.put_rect(image, Rect2i(x + 3, spring_row, 1, BackdropPaint.STRIP_HEIGHT - spring_row), VAULT_DARK)
		# Capital where the arches spring from the column.
		BackdropPaint.put_rect(image, Rect2i(x - 6, spring_row - 2, 13, 3), VAULT_LIT)
	var floor_tops: PackedFloat32Array = BackdropPaint.flat_line(BackdropPaint.row(168))
	BackdropPaint.fill_below(image, floor_tops, VAULT_BODY)
	BackdropPaint.paint_rim(image, floor_tops, VAULT_LIT)
	return image


func _paint_crypt() -> Image:
	var image: Image = BackdropPaint.new_strip()
	# Ceiling stones along the top.
	var ceiling: PackedFloat32Array = BackdropPaint.hanging(BackdropPaint.row(4), [Vector2(40.0, 6.0), Vector2(12.0, 2.0)] as Array[Vector2], 221, false)
	BackdropPaint.fill_above(image, ceiling, NEAR_BODY)
	BackdropPaint.paint_bottom_rim(image, ceiling, NEAR_LIT)
	# Chains hanging from it: alternating tall and wide links.
	for chain_index: int in 5:
		var chain_x: int = roundi((chain_index + 0.3) * BackdropPaint.STRIP_WIDTH / 5.0)
		var length: int = 30 + roundi(BackdropPaint.random01(chain_index, 1, 222) * 50.0)
		var y: int = roundi(ceiling[chain_x])
		var link: int = 0
		while y < BackdropPaint.row(0) + length:
			if link % 2 == 0:
				BackdropPaint.put_rect(image, Rect2i(chain_x - 1, y, 3, 5), NEAR_LIT)
				BackdropPaint.put_pixel(image, chain_x, y + 2, NEAR_BODY)
			else:
				BackdropPaint.put_rect(image, Rect2i(chain_x, y, 1, 5), NEAR_LIT)
			y += 4
			link += 1
	# Stone coffins on the floor: a block with a lid and a lit top.
	var floor_tops: PackedFloat32Array = BackdropPaint.ridge(BackdropPaint.row(184), [Vector2(30.0, 4.0), Vector2(8.0, 2.0)] as Array[Vector2], 223, false)
	BackdropPaint.fill_below(image, floor_tops, NEAR_BODY)
	BackdropPaint.paint_rim(image, floor_tops, NEAR_LIT)
	for coffin_index: int in 2:
		var left: int = 90 + coffin_index * 300
		var top: int = BackdropPaint.row(160)
		BackdropPaint.put_rect(image, Rect2i(left, top, 46, 30), NEAR_BODY)
		BackdropPaint.put_rect(image, Rect2i(left - 3, top - 4, 52, 5), NEAR_BODY)
		BackdropPaint.put_rect(image, Rect2i(left - 3, top - 4, 52, 1), NEAR_LIT)
		BackdropPaint.put_rect(image, Rect2i(left, top + 6, 46, 1), NEAR_LIT)
	return image


## Right in front: two heavy chains hanging from above with a hook, and a broken
## column standing in a bottom corner.
func _paint_front() -> Image:
	var image: Image = BackdropPaint.new_strip()
	for chain: Vector2 in [Vector2(120.0, 96.0), Vector2(470.0, 60.0)]:
		var y: int = 0
		var link: int = 0
		while y < BackdropPaint.row(chain.y):
			if link % 2 == 0:
				BackdropPaint.put_rect(image, Rect2i(roundi(chain.x) - 3, y, 7, 9), TempleStyle.FRONT_BODY)
				BackdropPaint.put_rect(image, Rect2i(roundi(chain.x) - 1, y + 2, 3, 5), Color(0.0, 0.0, 0.0, 0.0))
				BackdropPaint.put_pixel(image, roundi(chain.x) - 3, y + 1, TempleStyle.FRONT_LIT)
			else:
				BackdropPaint.put_rect(image, Rect2i(roundi(chain.x) - 1, y, 2, 9), TempleStyle.FRONT_BODY)
			y += 7
			link += 1
		# The hook at the end.
		BackdropPaint.put_line(image, Vector2(chain.x, y), Vector2(chain.x, y + 8), TempleStyle.FRONT_BODY, 3)
		BackdropPaint.put_line(image, Vector2(chain.x, y + 8), Vector2(chain.x + 6, y + 4), TempleStyle.FRONT_BODY, 3)
	# The broken column: a fluted shaft with a jagged top, on a base block.
	var bottom: int = BackdropPaint.row(190)
	for x: int in range(300, 330):
		var top: int = bottom - 70 + roundi(BackdropPaint.periodic_noise(x * 5.0, 12.0, 231) * 16.0)
		BackdropPaint.put_rect(image, Rect2i(x, top, 1, BackdropPaint.STRIP_HEIGHT - top),
			TempleStyle.FRONT_LIT if x < 302 or (x - 300) % 6 == 3 else TempleStyle.FRONT_BODY)
	BackdropPaint.put_rect(image, Rect2i(292, bottom, 46, BackdropPaint.STRIP_HEIGHT - bottom), TempleStyle.FRONT_BODY)
	BackdropPaint.put_rect(image, Rect2i(292, bottom, 46, 1), TempleStyle.FRONT_LIT)
	return image

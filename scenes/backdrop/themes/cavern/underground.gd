class_name CavernUnderground
extends BackdropTheme
## CAVERN, UNDERGROUND: the deep, the bottom of the same cave as the upper cave
## (CavernStyle: the same walls of rock, one soft change down, sinking into
## pitch black: the furthest walls are gone in it; here the walls' openings are
## sheer stepped chasms dropping out of sight, not the upper cave's round caves).
## Far back, through the chasms, an old carved face is BARELY there in the dark, between two pillars
## covered in glyphs: a grin of jagged teeth, and in its empty sockets two dim
## red pinpricks that slowly swell and fade, as if it were looking back. You
## should hardly notice it. Out in that same far black, pairs of eyes open,
## blink, and are gone again, wherever the walls in front don't hide them; faint
## specks drift. Stalagmites rise in front and the great pillar runs down the
## left edge (shared).
## Layers far to near; see BackdropTheme.
## (Above it: surface.gd, the upper cave.)

# Pixel math: whole-pixel divisions (e.g. width / 2) are meant to drop the fraction.
@warning_ignore_start("integer_division")

## The carved face: its middle (strip x, screen row) and size.
const FACE_CENTER: Vector2 = Vector2(200.0, 92.0)
const FACE_SIZE: Vector2 = Vector2(110.0, 128.0)
## The glyph pillars, either side of the face: px from its middle, and their size.
const PILLAR_OFFSET: float = 86.0
const PILLAR_SIZE: Vector2i = Vector2i(22, 128)
## How far the ruins are sunk into the (pitch black) air: very far, so the face
## is only just there. Their scroll: between wall 0 and wall 1.
const RUINS_HAZE: float = 0.8
const RUINS_SCROLL: Vector2 = Vector2(0.07, 0.024)
## Carved stone, a little paler than the cave's rock: [crust, rim, edge, inside, hatch, deep].
const CARVED: Array[Color] = [Color(0.62, 0.5, 0.42), Color(0.78, 0.68, 0.56), Color(0.32, 0.22, 0.22),
	Color(0.26, 0.18, 0.2), Color(0.3, 0.22, 0.23), Color(0.14, 0.1, 0.13)]
## The cuts in the stone (eyes, mouth, glyphs).
const CUT: Color = Color(0.08, 0.05, 0.08)
## The face's eye sockets, from its middle (a share of its half size), and the
## pinpricks in them: their color, how bright at most, and the seconds of one
## slow swell and fade (they stay dark for part of it).
const SOCKET_OFFSET: Vector2 = Vector2(0.42, -0.18)
const PUPIL_COLOR: Color = Color(0.85, 0.16, 0.12)
const PUPIL_MAX_ALPHA: float = 0.4
const PUPIL_CYCLE: float = 8.0
## The grin: half its width and height (px), and the px between its teeth.
const GRIN_HALF: Vector2 = Vector2(26.0, 6.0)
const TOOTH_SPACING: int = 5

## The eyes in the dark, far back with the face (every wall hides them where it
## passes in front): Vector4(strip x, screen row, seconds per appearance, phase).
const EYES: Array[Vector4] = [Vector4(40.0, 120.0, 11.0, 0.0), Vector4(150.0, 64.0, 14.0, 5.5),
	Vector4(330.0, 76.0, 13.0, 4.0), Vector4(410.0, 150.0, 10.0, 8.5), Vector4(480.0, 104.0, 9.0, 7.5),
	Vector4(590.0, 96.0, 15.0, 2.0)]
const EYE_COLORS: Array[Color] = [Color(0.88, 0.96, 0.55), Color(1.0, 0.62, 0.42)]
## Each appearance: the eyes show for this share of their cycle, fading in and out
## over EYE_FADE seconds, shut for EYE_BLINK seconds every EYE_BLINK_EVERY.
const EYE_SHOW_SHARE: float = 0.4
const EYE_FADE: float = 0.6
const EYE_BLINK: float = 0.15
const EYE_BLINK_EVERY: float = 2.7
## Px between a pair's two eyes.
const EYE_SPACING: float = 4.0


func _build_layers() -> void:
	# The rock band of a break straight out to the ridge (Backdrop.BREAK_SKYLINE_LOOKS).
	crust_colors = [CavernStyle.ROCK[BackdropTerrain.INSIDE], CavernStyle.ROCK[BackdropTerrain.CRUST]]
	CavernStyle.add_shared_layers(self, UNDERGROUND_SECTION, _add_far_things, func() -> void: pass)

	var specks: BackdropMotes = BackdropMotes.new()
	specks.shape = BackdropMotes.Shape.DOT
	specks.mote_count = 14
	specks.colors = [Color(0.6, 0.5, 0.75, 0.3), Color(0.75, 0.6, 0.55, 0.22)]
	specks.velocity = Vector2(1.0, -1.2)
	specks.sway_amplitude = 2.0
	specks.sway_speed = 0.15
	specks.scroll_factor = 0.4
	specks.seed_value = 6501
	add_motes(specks)


## After wall 0 (CavernStyle.add_shared_layers' slot), far back in the black: the
## ruins, then the eyes (same scroll: they're as far away), so every wall in front
## hides them where it passes.
func _add_far_things() -> void:
	var ruins: BackdropLayer = add_tall_layer(CavernStyle.NAME, "Ruins", RUINS_SCROLL, paint_ruins, UNDERGROUND_SECTION)
	ruins.draw_extra = draw_pupils
	add_drawn_layer("Eyes", RUINS_SCROLL, draw_eyes)


## The carved face between its glyph pillars, painted on a tall picture (so it
## sinks into the air at its own depth, CavernStyle.sink_into_air).
static func paint_ruins(tall: Image) -> void:
	var section: int = UNDERGROUND_SECTION
	var center: Vector2 = Vector2(FACE_CENTER.x, BackdropPaint.tall_row(FACE_CENTER.y, section))
	var half: Vector2 = FACE_SIZE / 2.0
	# The face: a slab with a rounded crown and a squared jaw, its eyes and mouth
	# cut right through (open air: they're dark holes onto the wall behind).
	var face: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(roundi(center.x - half.x) - 4, roundi(center.y - half.y) - 4,
		roundi(FACE_SIZE.x) + 8, roundi(FACE_SIZE.y) + 8))
	face.add_circle(center + Vector2(0.0, -half.y * 0.25), half.x)
	face.add_rect(Rect2i(roundi(center.x - half.x * 0.86), roundi(center.y - half.y * 0.2), roundi(half.x * 1.72), roundi(half.y * 1.2)))
	for side: float in [-1.0, 1.0]:
		face.cut_ellipse(center + Vector2(side * half.x * SOCKET_OFFSET.x, half.y * SOCKET_OFFSET.y), Vector2(11.0, 7.0))
	# The grin: a wide mouth whose corners turn up, then jagged teeth put back,
	# hanging from the top and rising from the bottom by turns.
	var mouth: Vector2 = center + Vector2(0.0, half.y * 0.52)
	face.cut_ellipse(mouth, GRIN_HALF)
	for side: float in [-1.0, 1.0]:
		face.cut_ellipse(mouth + Vector2(side * GRIN_HALF.x * 0.85, -GRIN_HALF.y * 0.9), Vector2(5.0, 4.0))
	for tooth: int in range(-roundi(GRIN_HALF.x) + 4, roundi(GRIN_HALF.x) - 3, TOOTH_SPACING):
		var from_top: bool = posmod(tooth / TOOTH_SPACING, 2) == 0
		var length: int = 3 + roundi(BackdropPaint.random01(tooth, 1, 6515) * 3.0)
		for step: int in length:
			var width: int = 2 if step < length - 1 else 1  # a point at the tip
			var row: int = roundi(mouth.y - GRIN_HALF.y) + step if from_top else roundi(mouth.y + GRIN_HALF.y) - step
			face.add_rect(Rect2i(roundi(mouth.x) + tooth, row, width, 1))
	BackdropTerrain.roughen(face, 6511)
	BackdropTerrain.paint(tall, face, CARVED, 3.0, 12.0, 2, 6511)
	# Carved lines: a heavy brow over each eye, the nose, a band across the crown.
	for side: float in [-1.0, 1.0]:
		var brow: Vector2 = center + Vector2(side * half.x * 0.42, -half.y * 0.32)
		BackdropPaint.put_line(tall, brow + Vector2(-14.0, 2.0 * side), brow + Vector2(14.0, -2.0 * side), CUT, 2)
	BackdropPaint.put_rect(tall, Rect2i(roundi(center.x) - 3, roundi(center.y - half.y * 0.1), 6, roundi(half.y * 0.45)), CUT)
	BackdropPaint.put_rect(tall, Rect2i(roundi(center.x) - 2, roundi(center.y - half.y * 0.1), 1, roundi(half.y * 0.45)), CARVED[BackdropTerrain.RIM])
	BackdropPaint.put_rect(tall, Rect2i(roundi(center.x - half.x * 0.7), roundi(center.y - half.y * 0.72), roundi(half.x * 1.4), 2), CUT)
	_paint_glyph_row(tall, Vector2i(roundi(center.x - half.x * 0.6), roundi(center.y - half.y * 0.68)), roundi(half.x * 1.2), 6512)
	# A crack down one cheek.
	var crack: Vector2 = center + Vector2(half.x * 0.62, -half.y * 0.05)
	for step: int in 6:
		var next: Vector2 = crack + Vector2((BackdropPaint.random01(step, 1, 6513) - 0.5) * 6.0, 7.0)
		BackdropPaint.put_line(tall, crack, next, CUT)
		crack = next
	# The glyph pillars either side.
	for side: float in [-1.0, 1.0]:
		var pillar_x: int = roundi(center.x + side * PILLAR_OFFSET) - PILLAR_SIZE.x / 2
		var pillar_top: int = roundi(center.y) - PILLAR_SIZE.y / 2 + 6
		var pillar: BackdropTerrain.Mask = BackdropTerrain.new_mask(Rect2i(pillar_x - 4, pillar_top - 6, PILLAR_SIZE.x + 8, PILLAR_SIZE.y + 12))
		pillar.add_rect(Rect2i(pillar_x, pillar_top, PILLAR_SIZE.x, PILLAR_SIZE.y))
		pillar.add_rect(Rect2i(pillar_x - 3, pillar_top - 4, PILLAR_SIZE.x + 6, 5))  # its capital
		BackdropTerrain.roughen(pillar, 6514 + roundi(side))
		BackdropTerrain.paint(tall, pillar, CARVED, 2.5, 8.0, 1, 6514 + roundi(side))
		for glyph_row: int in 9:
			_paint_glyph_row(tall, Vector2i(pillar_x + 4, pillar_top + 8 + glyph_row * 13), PILLAR_SIZE.x - 8, 6520 + glyph_row + roundi(side) * 20)
	CavernStyle.sink_into_air(tall, RUINS_HAZE, 1.0)


## A row of small carved glyphs from `start`, `width` px long: each a little mark
## of 2-4 strokes picked by a hash.
static func _paint_glyph_row(tall: Image, start: Vector2i, width: int, seed_value: int) -> void:
	const GLYPH_WIDTH: int = 5
	for glyph: int in width / (GLYPH_WIDTH + 2):
		var left: int = start.x + glyph * (GLYPH_WIDTH + 2)
		var kind: int = floori(BackdropPaint.random01(glyph, 1, seed_value) * 4.0)
		BackdropPaint.put_rect(tall, Rect2i(left, start.y, GLYPH_WIDTH, 1), CUT)  # every glyph hangs from a line
		match kind:
			0:
				BackdropPaint.put_rect(tall, Rect2i(left + 2, start.y, 1, 5), CUT)
			1:
				BackdropPaint.put_rect(tall, Rect2i(left, start.y, 1, 4), CUT)
				BackdropPaint.put_rect(tall, Rect2i(left + 4, start.y + 2, 1, 3), CUT)
			2:
				BackdropPaint.put_rect(tall, Rect2i(left + 1, start.y + 3, 3, 1), CUT)
				BackdropPaint.put_rect(tall, Rect2i(left + 2, start.y + 1, 1, 2), CUT)
			_:
				BackdropPaint.put_line(tall, Vector2(left, start.y + 4), Vector2(left + 4, start.y + 1), CUT)


## The dim red pinpricks in the face's sockets, a draw_extra on the Ruins layer:
## they slowly swell and fade, and stay dark for part of each PUPIL_CYCLE.
static func draw_pupils(layer: BackdropLayer, copy_x: float, time: float) -> void:
	# A slow swell: lit for a bit over half the cycle, dark for the rest.
	var strength: float = clampf(sin(time * TAU / PUPIL_CYCLE) * 1.4 - 0.4, 0.0, 1.0)
	if strength <= 0.0:
		return
	var half: Vector2 = FACE_SIZE / 2.0
	for side: float in [-1.0, 1.0]:
		var spot: Vector2 = Vector2(roundf(copy_x + FACE_CENTER.x + side * half.x * SOCKET_OFFSET.x),
			BackdropPaint.row(FACE_CENTER.y + half.y * SOCKET_OFFSET.y))
		BackdropTheme.draw_glow(layer, spot + Vector2(0.5, 0.5), 2.5, Color(PUPIL_COLOR, 0.08), strength)
		layer.draw_rect(Rect2(spot, Vector2.ONE), Color(PUPIL_COLOR, PUPIL_MAX_ALPHA * strength))


## The eyes in the dark (EYES), a draw_extra: each pair fades in, blinks now and
## then, and fades out again, then stays away for the rest of its cycle.
static func draw_eyes(layer: BackdropLayer, copy_x: float, time: float) -> void:
	for pair_index: int in EYES.size():
		var pair: Vector4 = EYES[pair_index]
		var shown_for: float = pair.z * EYE_SHOW_SHARE
		var age: float = fposmod(time + pair.w, pair.z)
		if age > shown_for:
			continue
		var strength: float = minf(1.0, minf(age, shown_for - age) / EYE_FADE)
		if fposmod(age, EYE_BLINK_EVERY) > EYE_BLINK_EVERY - EYE_BLINK:
			continue  # blinking
		var color: Color = EYE_COLORS[pair_index % EYE_COLORS.size()]
		var left: Vector2 = Vector2(roundf(copy_x + pair.x), BackdropPaint.row(pair.y))
		for eye: int in 2:
			var spot: Vector2 = left + Vector2(eye * EYE_SPACING, 0.0)
			BackdropTheme.draw_glow(layer, spot + Vector2(0.5, 0.5), 3.0, Color(color, 0.18), strength)
			layer.draw_rect(Rect2(spot, Vector2(2.0, 1.0)), Color(color, strength))

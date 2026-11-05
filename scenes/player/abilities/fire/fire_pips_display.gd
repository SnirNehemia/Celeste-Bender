class_name FirePipsDisplay
extends Node2D
## Draws the fire bar (FireBar) as a row of small round glowing dots over the player's head
## (Fire_bending.md §4.2, §13). A child of the player, next to FireBar; it only
## READS the bar and listens to its `pips_changed` signal, so it can be removed
## without breaking anything.
##
## The look, all in whole pixels so it stays crisp at 320x180:
##   - one slot per pip held: a 4x4 px round dot (its corners cut: at this size that
##     reads as a circle), 2 px apart. Simple and round like the white gust pips; a
##     dancing flame per pip was too busy (play-test).
##   - CENTERED on the player's body (play-test: it wasn't). The body is 8 px wide,
##     so a centered row must be an EVEN number of px wide: even dots, even spacing,
##     any count. (The old 3 px dots made every row odd: always half a pixel off.)
##     And the row is anchored where the body really lands on the pixel grid
##     (_get_body_middle_x), not floored on its own.
##   - a held pip keeps its shape and only FLICKERS IN COLOR, like an ember: its
##     middle drifts between yellow and white-hot, its rim between orange and red,
##     each slot on its own rhythm, so the row never pulses in step
##   - empty slots are not drawn: the row is only as long as the pips you hold
##     (play-test), centered over the head, so it grows and shrinks like the gust pips
##   - a spent pip snuffs out AT ONCE: a 2-frame white flash, then a puff of smoke
##     (never a slow drain: the bar only ever shows whole pips)
##   - a gained pip starts as a spark (just the middle 2x2) and flares white-hot before
##     it settles
##
## Always shown where fire is allowed (pips are a budget you plan with, on the ground
## too), hidden while dead. In rooms that also allow Air it sits one row higher, above
## the white gust pips (GustAbility draws those at 19 px above the feet).
##
## Timing uses REAL time (Time.get_ticks_msec), not the game's delta: the HUD keeps
## flickering at the same speed during slow motion (gust aim, earth bends).
##
## top_level = true: this node ignores the player's transform, so its coordinates are
## world coordinates (same trick as GustAbility). It follows the player by reading
## player.global_position every frame.

## Fire palette (Fire_bending.md §9.1).
const CORE_COLOR: Color = Color("#FFF6CC")
const INNER_COLOR: Color = Color("#FFD34D")
const BODY_COLOR: Color = Color("#FF8A1E")
const EDGE_COLOR: Color = Color("#E8431A")
const EMBER_COLOR: Color = Color("#8A2410")
## HUD smoke is a lighter gray than the world's smoke (§9.1), or it would vanish
## against the dark background at this tiny size.
const PUFF_COLOR: Color = Color(0.6, 0.56, 0.56, 0.7)

## One slot: a 4x4 dot, and the next one starts 6 px further right. Both EVEN, so
## the row's width is even for any number of pips and centers exactly (header).
const SLOT_SIZE: int = 4
const SLOT_SPACING: int = 6
## The dot's pixels: the 2x2 middle, and the rim around it without the 4 corners.
const MIDDLE_PIXELS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
const RIM_PIXELS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(3, 1),
	Vector2i(0, 2), Vector2i(3, 2), Vector2i(1, 3), Vector2i(2, 3)]
## The player's body is this wide, its left edge this far left of its origin (the
## Visual ColorRect in player.tscn).
const BODY_LEFT: float = -4.0
## Top of the row above the feet (the player is 11 px tall). Fire-only rooms: in the
## gust pips' slot, just above the head. Rooms with Air too: one row above the gust pips.
const ROW_TOP_FIRE_ONLY: int = -19
const ROW_TOP_WITH_AIR: int = -25

## The snuff flash lasts 2 frames at 60 fps, real seconds.
const SNUFF_FLASH_TIME: float = 2.0 / 60.0
## How long a gained pip takes to flare up and settle, real seconds. The first 30% of
## it is just a spark.
const FLARE_TIME: float = 0.25
const FLARE_SPARK_PART: float = 0.3
## Smoke puff from a snuffed pip: pixels per puff, how long they live (real s), how
## fast they rise (px/s).
const PUFF_PIXEL_COUNT: int = 2
const PUFF_LIFETIME: float = 0.4
const PUFF_RISE_SPEED: float = 12.0
## Color flicker speed, radians per second (a little faster or slower per slot, see
## _get_flicker). Slow enough to read as a glow, not a blink.
const FLICKER_RATE: float = 6.0

## The bar we draw. Set in _ready() from the sibling node.
var fire_bar: FireBar
var player: Player
## Per slot, real seconds left of its snuff flash / its flare-up. Index = slot.
var snuff_flash_remaining: Array[float] = []
var flare_remaining: Array[float] = []
## Smoke pixels from snuffed pips: each entry is [world position (Vector2),
## velocity (Vector2), age in real seconds (float)].
var puffs: Array = []
## Real time of the last _process, in ms, to measure real deltas.
var last_msec: int = 0


func _ready() -> void:
	player = get_parent() as Player
	fire_bar = player.get_node("FireBar") as FireBar
	fire_bar.pips_changed.connect(_on_pips_changed)
	top_level = true
	global_position = Vector2.ZERO
	z_index = 40  # over the room, like the gust pips
	last_msec = Time.get_ticks_msec()


## _process runs once per drawn frame. Only visuals here, nothing gameplay-related.
func _process(_delta: float) -> void:
	var now_msec: int = Time.get_ticks_msec()
	var real_delta: float = (now_msec - last_msec) / 1000.0
	last_msec = now_msec
	_resize_slot_arrays()
	for slot: int in snuff_flash_remaining.size():
		snuff_flash_remaining[slot] = maxf(snuff_flash_remaining[slot] - real_delta, 0.0)
		flare_remaining[slot] = maxf(flare_remaining[slot] - real_delta, 0.0)
	_update_puffs(real_delta)
	# Nothing else redraws a node that sits still at the world origin.
	queue_redraw()


## Keeps one timer per slot, even if max_pips is changed while the game runs.
func _resize_slot_arrays() -> void:
	var slot_count: int = fire_bar.get_max_pips()
	if snuff_flash_remaining.size() != slot_count:
		snuff_flash_remaining.resize(slot_count)
		flare_remaining.resize(slot_count)


## The bar changed: snuff the slots that lost their pip, flare the ones that got one.
func _on_pips_changed(pips: int, change: int) -> void:
	_resize_slot_arrays()
	var old_pips: int = pips - change
	if change < 0:
		for slot: int in range(pips, mini(old_pips, snuff_flash_remaining.size())):
			snuff_flash_remaining[slot] = SNUFF_FLASH_TIME
			flare_remaining[slot] = 0.0
			_spawn_puff(slot)
	else:
		for slot: int in range(old_pips, mini(pips, flare_remaining.size())):
			flare_remaining[slot] = FLARE_TIME
			snuff_flash_remaining[slot] = 0.0


# --- Smoke puffs ---------------------------------------------------------------

func _spawn_puff(slot: int) -> void:
	var slot_top: Vector2 = Vector2(_get_slot_origin(slot)) + Vector2(1.5, 0)
	for pixel_index: int in PUFF_PIXEL_COUNT:
		# A small random sideways drift, so two puffs never look alike.
		var drift: float = randf_range(-6.0, 6.0)
		puffs.append([slot_top + Vector2(pixel_index - 0.5, 0), Vector2(drift, -PUFF_RISE_SPEED), 0.0])


func _update_puffs(real_delta: float) -> void:
	for puff: Array in puffs:
		puff[0] += puff[1] * real_delta
		puff[2] += real_delta
	puffs = puffs.filter(func(puff: Array) -> bool: return float(puff[2]) < PUFF_LIFETIME)


# --- Drawing ---------------------------------------------------------------------

## Coordinates are world coordinates (top_level at the origin).
func _draw() -> void:
	if player.is_dead() or not player.is_element_allowed(Player.ELEMENT_FIRE):
		return
	for slot: int in snuff_flash_remaining.size():
		var origin: Vector2i = _get_slot_origin(slot)
		if snuff_flash_remaining[slot] > 0.0:
			_draw_dot(origin, CORE_COLOR, CORE_COLOR)
		elif slot < fire_bar.pips:
			_draw_held_pip(origin, slot)
	for puff: Array in puffs:
		var fade: float = 1.0 - float(puff[2]) / PUFF_LIFETIME
		_pixel(Vector2(puff[0]).floor(), Color(PUFF_COLOR, PUFF_COLOR.a * fade))


## How many slots the row shows right now: the held pips, plus a pip that is still
## flashing as it snuffs out (it keeps its place for those 2 frames).
func _get_shown_slot_count() -> int:
	var shown_count: int = fire_bar.pips
	for slot: int in snuff_flash_remaining.size():
		if snuff_flash_remaining[slot] > 0.0:
			shown_count = maxi(shown_count, slot + 1)
	return shown_count


## The top-left pixel of slot `slot` this frame: the shown row is centered over the feet.
func _get_slot_origin(slot: int) -> Vector2i:
	var slot_count: int = maxi(_get_shown_slot_count(), 1)
	var row_width: int = SLOT_SPACING * (slot_count - 1) + SLOT_SIZE
	var row_top: int = ROW_TOP_WITH_AIR if player.is_element_allowed(Player.ELEMENT_AIR) \
		else ROW_TOP_FIRE_ONLY
	# Even width (see SLOT_SIZE), so half of it is a whole number of pixels.
	var row_left: int = _get_body_middle_x() - (row_width >> 1)
	return Vector2i(row_left + SLOT_SPACING * slot, floori(player.global_position.y) + row_top)


## The pixel line down the middle of the player's body as drawn. The body's left
## edge is at a fractional x; the renderer fills the pixels whose centers are inside
## the rect, so its first pixel is the rounded edge, and its middle is 4 px on.
func _get_body_middle_x() -> int:
	return roundi(player.global_position.x + BODY_LEFT) + int(-BODY_LEFT)


## A held pip: the round dot, its middle and rim each drifting in color. While it
## flares up after a gain: first only a white spark in the middle, then the whole dot
## white-hot in the middle and yellow on the rim, fading into the normal glow.
func _draw_held_pip(origin: Vector2i, slot: int) -> void:
	var flare_progress: float = 1.0 - flare_remaining[slot] / FLARE_TIME if flare_remaining[slot] > 0.0 else 1.0
	if flare_progress < FLARE_SPARK_PART:
		for pixel: Vector2i in MIDDLE_PIXELS:
			_pixel(Vector2(origin + pixel), CORE_COLOR)
		return
	var flicker: Vector2 = _get_flicker(slot)
	var middle_color: Color = INNER_COLOR.lerp(CORE_COLOR, flicker.x)
	var rim_color: Color = EDGE_COLOR.lerp(BODY_COLOR, flicker.y)
	if flare_progress < 1.0:
		# How far through the flare (after the spark) we are: 0 = white-hot, 1 = normal.
		var settle: float = (flare_progress - FLARE_SPARK_PART) / (1.0 - FLARE_SPARK_PART)
		middle_color = CORE_COLOR.lerp(middle_color, settle)
		rim_color = INNER_COLOR.lerp(rim_color, settle)
	_draw_dot(origin, middle_color, rim_color)


## The round 4x4 dot: a 2x2 middle, eight rim pixels.
func _draw_dot(origin: Vector2i, middle_color: Color, rim_color: Color) -> void:
	for pixel: Vector2i in MIDDLE_PIXELS:
		_pixel(Vector2(origin + pixel), middle_color)
	for pixel: Vector2i in RIM_PIXELS:
		_pixel(Vector2(origin + pixel), rim_color)


## How hot slot `slot` glows right now: x = the middle (0 = yellow, 1 = white-hot),
## y = the rim (0 = red, 1 = orange), both 0..1. Two sines at different speeds,
## mixed, give a drift that looks random but never jumps. Each slot gets its own
## speed and phase from its index, so neighbours never glow in step.
func _get_flicker(slot: int) -> Vector2:
	var seconds: float = Time.get_ticks_msec() / 1000.0
	var rate: float = FLICKER_RATE * (0.8 + 0.13 * float(slot % 3))
	var phase: float = float(slot) * 2.39  # the golden angle, spreads phases evenly
	var middle_wave: float = sin(seconds * rate + phase) * 0.7 + sin(seconds * rate * 1.7 + phase * 1.3) * 0.3
	var rim_wave: float = sin(seconds * rate * 1.3 + phase * 0.7) * 0.6 + sin(seconds * rate * 0.6) * 0.4
	# The middle stays mostly yellow (white-hot only at the peaks); the rim swings wider.
	return Vector2(clampf(middle_wave, 0.0, 1.0) * 0.6, 0.5 + 0.5 * rim_wave)


func _pixel(position_px: Vector2, color: Color) -> void:
	draw_rect(Rect2(position_px, Vector2.ONE), color)

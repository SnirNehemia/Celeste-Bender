class_name FirePipsDisplay
extends Node2D
## Draws the fire bar (FireBar) as a row of tiny flames over the player's head
## (Fire_bending.md §4.2, §13). A child of the player, next to FireBar; it only
## READS the bar and listens to its `pips_changed` signal, so it can be removed
## without breaking anything.
##
## The look, all in whole pixels so it stays crisp at 320x180:
##   - one slot per possible pip (FireTuning.max_pips), 3x4 px, 1 px apart
##   - a held pip is a little flame that flickers on its own rhythm (each slot has
##     its own phase), so the row never pulses in step
##   - an empty slot is a dim ember outline
##   - a spent pip snuffs out AT ONCE: a 2-frame white flash, then a puff of smoke
##     (never a slow drain: the bar only ever shows whole pips)
##   - a gained pip starts as a spark and flares up taller before it settles
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
## The empty-slot outline: ember red, a little see-through so it reads as "off".
const EMPTY_COLOR: Color = Color(EMBER_COLOR, 0.75)
## HUD smoke is a lighter gray than the world's smoke (§9.1), or it would vanish
## against the dark background at this tiny size.
const PUFF_COLOR: Color = Color(0.6, 0.56, 0.56, 0.7)

## One slot: 3 px wide, 4 px tall, and the next one starts 4 px further right.
const SLOT_WIDTH: int = 3
const SLOT_HEIGHT: int = 4
const SLOT_SPACING: int = 4
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
## Flicker speed: each slot's flame changes shape about this many times per second
## (a little faster or slower per slot, see _get_flicker).
const FLICKER_RATE: float = 9.0

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
	var slot_top: Vector2 = Vector2(_get_slot_origin(slot)) + Vector2(1, 0)
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
			draw_rect(Rect2(origin, Vector2(SLOT_WIDTH, SLOT_HEIGHT)), CORE_COLOR)
		elif slot < fire_bar.pips:
			_draw_flame(origin, slot)
		else:
			_draw_empty_slot(origin)
	for puff: Array in puffs:
		var fade: float = 1.0 - float(puff[2]) / PUFF_LIFETIME
		_pixel(Vector2(puff[0]).floor(), Color(PUFF_COLOR, PUFF_COLOR.a * fade))


## The top-left pixel of slot `slot` this frame: the row is centered over the feet.
func _get_slot_origin(slot: int) -> Vector2i:
	var slot_count: int = fire_bar.get_max_pips()
	var row_width: int = SLOT_SPACING * (slot_count - 1) + SLOT_WIDTH
	var row_top: int = ROW_TOP_WITH_AIR if player.is_element_allowed(Player.ELEMENT_AIR) \
		else ROW_TOP_FIRE_ONLY
	# floori: whole pixels, so the flames never blur between two pixels.
	var row_left: int = floori(player.global_position.x - row_width / 2.0)
	return Vector2i(row_left + SLOT_SPACING * slot, floori(player.global_position.y) + row_top)


## A held pip: a 3x4 flame, red-orange edges, orange body, yellow middle, with a tip
## that sways and comes and goes. Pixel rows from the bottom (y = 3) to the top (y = 0):
##   y=3  edge  body  edge
##   y=2  body  inner body
##   y=1        inner         (+ a body pixel on the side the flame sways to)
##   y=0        tip           (on the sway side; only on the "tall" beats)
func _draw_flame(origin: Vector2i, slot: int) -> void:
	var flicker: Vector2 = _get_flicker(slot)
	var sway: int = int(flicker.x)  # -1, 0 or +1 px
	var is_tall: bool = flicker.y > 0.35
	# Flaring up after a gain: first only a spark, then a flame with an extra-tall,
	# white-hot tip that settles into the normal flame.
	var flare_progress: float = 1.0 - flare_remaining[slot] / FLARE_TIME if flare_remaining[slot] > 0.0 else 1.0
	if flare_progress < FLARE_SPARK_PART:
		_pixel(Vector2(origin + Vector2i(1, 3)), CORE_COLOR)
		_pixel(Vector2(origin + Vector2i(1, 2)), INNER_COLOR)
		return
	var is_flaring: bool = flare_progress < 1.0
	var middle_color: Color = CORE_COLOR if is_flaring else INNER_COLOR
	_pixel(Vector2(origin + Vector2i(0, 3)), EDGE_COLOR)
	_pixel(Vector2(origin + Vector2i(1, 3)), BODY_COLOR)
	_pixel(Vector2(origin + Vector2i(2, 3)), EDGE_COLOR)
	_pixel(Vector2(origin + Vector2i(0, 2)), BODY_COLOR)
	_pixel(Vector2(origin + Vector2i(1, 2)), middle_color)
	_pixel(Vector2(origin + Vector2i(2, 2)), BODY_COLOR)
	_pixel(Vector2(origin + Vector2i(1, 1)), middle_color)
	if sway != 0:
		_pixel(Vector2(origin + Vector2i(1 + sway, 1)), BODY_COLOR)
	if is_tall or is_flaring:
		_pixel(Vector2(origin + Vector2i(1 + sway, 0)), INNER_COLOR if is_flaring else EDGE_COLOR)
	if is_flaring:
		# The overshoot: one pixel above the slot while it flares.
		_pixel(Vector2(origin + Vector2i(1, -1)), EDGE_COLOR)


## An empty slot: the flame's outline in dim ember red (bottom row, sides, a dot on top).
func _draw_empty_slot(origin: Vector2i) -> void:
	for pixel: Vector2i in [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
			Vector2i(0, 2), Vector2i(2, 2), Vector2i(1, 1)]:
		_pixel(Vector2(origin + pixel), EMPTY_COLOR)


## The flame shape for `slot` right now: x = sway (-1, 0 or +1 px), y = height
## (0..1, the tip shows above 0.35). Two sines at different speeds per slot, mixed,
## give a flicker that looks random but never jumps around wildly. Each slot gets its
## own speed and phase from its index, so neighbors never flicker in step.
func _get_flicker(slot: int) -> Vector2:
	var seconds: float = Time.get_ticks_msec() / 1000.0
	var rate: float = FLICKER_RATE * (0.8 + 0.13 * float(slot % 3))
	var phase: float = float(slot) * 2.39  # the golden angle, spreads phases evenly
	var wave_a: float = sin(seconds * rate + phase)
	var wave_b: float = sin(seconds * rate * 1.7 + phase * 1.3)
	var sway: float = roundf(clampf(wave_a * 0.8 + wave_b * 0.4, -1.0, 1.0))
	var height: float = 0.5 + 0.5 * sin(seconds * rate * 1.3 + phase * 0.7) * cos(seconds * rate * 0.6)
	return Vector2(sway, height)


func _pixel(position_px: Vector2, color: Color) -> void:
	draw_rect(Rect2(position_px, Vector2.ONE), color)

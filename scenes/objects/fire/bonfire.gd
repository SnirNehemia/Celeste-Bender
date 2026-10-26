class_name Bonfire
extends Node2D
## Bonfire (Stage F7, Fire_bending.md §5.3, §6.2, §9.3): the big fire that stands
## where enough burning LEAVES lie together. The leaves are what burns (F7 play-test):
## a LeafPile watches its burning leaves, and wherever at least bonfire_min_leaves of
## them lie in a heap it puts a Bonfire there (LeafPile._update_bonfires). Scatter
## the heap (a close gust) and the pile puts the bonfire out.
##
## It GROWS (F7 play-test), so you can light a heap from above and ride its hot air:
##   AMBER  bonfire_amber_time   the heap glows: coals and a warm glow only.
##                               Harmless, no lift.
##   LOW    bonfire_low_time     a low flame (bonfire_low_height_share of full
##                               height) breaks out: it kills, and the updraft starts
##                               above it. A shake and a flash.
##   GROW   bonfire_grow_time    the flame rises to bonfire_flame_height.
##   FULL                        until bonfire_duration runs out (0 = until R): then
##                               `burnt_out` is emitted and the pile burns the
##                               leaves away.
##
## While its flame is up it:
##   - KILLS on touch: a FireHazard as wide as the heap and as tall as the flame
##   - gives a HOT UPDRAFT above the flame: a WindZone with `heat` on,
##     bonfire_updraft_height tall, lifting gliders and heat receivers
##   - LIGHTS what it touches every IGNITE_INTERVAL: flammables in its flame and the
##     grass along its base (Flammable.ignite_in_rect)
##
## The pile places it with set_footprint(): our origin is the middle of the heap's
## base, flames grow up -Y, and the width follows the heap (bonfire_min_width to
## bonfire_max_width). The pile owns it (puts it out on reset), so the bonfire
## isn't in the reset group.
##
## Look: FlameTongues spread over the width (more for a wider fire), each as tall as
## the burning leaves under it are dense (set_leaf_spread; play-test: a wide pile
## burnt with one fixed-width flame): full height where there are
## bonfire_full_density leaves per px or more, lower where the heap thins out.
## Without leaf positions the middle ones are tallest. Drawn through a FlameMerge so
## they share one outline: one fire with many
## tips, not a row of separate flames (F7 play-test). Plus coals, a soft additive
## glow, smoke and sparks popping up in bursts. The full look pass (smoke column,
## shimmer) is Stage F13.

## Emitted when bonfire_duration runs out. The pile then burns its leaves away.
signal burnt_out(bonfire: Bonfire)

enum Stage { OUT, AMBER, LOW, GROWING, FULL }

## One tongue per this many px of width, between MIN_TONGUES and MAX_TONGUES...
const PX_PER_TONGUE: float = 5.0
## ...or this many in a bonfire that is part of a row along a long pile (see
## LeafFire._split_wide_heap): a row of 5 bonfires would be 50 tongues, and each
## tongue costs ~0.2 ms a frame to draw. Wider apart, the merged fire still reads
## as one flame with many tips.
const ROW_PX_PER_TONGUE: float = 8.0
const MIN_TONGUES: int = 3
const MAX_TONGUES: int = 10
## The shortest a tongue gets (a share of the full height), however few leaves.
const MIN_TONGUE_HEIGHT_SHARE: float = 0.3
## How often it lights what it touches, seconds (a flame standing still doesn't need
## to check every frame).
const IGNITE_INTERVAL: float = 0.25
## The updraft is only resized when the width changes by at least this much, px:
## resizing a WindZone rebuilds its particles.
const RESIZE_STEP: float = 2.0
## Coals and glow (Fire_bending.md §9.1).
const COAL_COLOR: Color = Color(0.12, 0.08, 0.07)
const EMBER_COLOR: Color = Color("#8A2410")
const EMBER_HOT_COLOR: Color = Color("#FF8A1E")
const GLOW_COLOR: Color = Color(1.0, 0.45, 0.12)
const FLASH_COLOR: Color = Color(1.0, 0.55, 0.15, 0.12)
## Coal specks per px of width.
const COAL_SPECKS_PER_PX: float = 0.35

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var stage: Stage = Stage.OUT
## Seconds since the heap formed (drives the stages, the coal flicker and the glow).
var lit_time: float = 0.0
## The heap's width, px (already clamped).
var width: float = 16.0
## Seconds until it next lights what it touches, and until the next spark burst.
var ignite_timer: float = 0.0
var spark_timer: float = 0.0
## MAX_TONGUES made; the first tongue_heights.size() are in use.
var flames: Array[FlameTongue] = []
## Each tongue's share of the full height, set when the tongues are laid out.
var tongue_heights: Array[float] = []
## Tongue spacing, px: PX_PER_TONGUE, or ROW_PX_PER_TONGUE in a row (set_in_row).
var px_per_tongue: float = PX_PER_TONGUE
## Where the heap's leaves lie across the fire: x relative to our origin, px (see
## set_leaf_spread). Empty = not known.
var leaf_offsets: PackedFloat32Array = PackedFloat32Array()
var hazard: FireHazard
var updraft: WindZone
## The additive child the glow is drawn into.
var glow_layer: Node2D


func _ready() -> void:
	z_index = 1  # flames in front of the leaves and the player's feet
	# One fire: the tongues share an outline (FlameMerge).
	var flame_merge: FlameMerge = FlameMerge.make(self)
	for tongue_index: int in MAX_TONGUES:
		var flame: FlameTongue = FlameTongue.new()
		flame.base_width = 6.0
		flame.fan_width = 7.0
		flame.flicker_speed = 1.3
		flame.wobble_amount = 0.4
		flame.breath_amount = 0.25
		flame.fork_amount = 0.6
		flame.lick_rate = 6.0
		flame.lick_size = 4.0
		flame.lick_speed = 30.0
		flame.heat = 0.6
		flame.visible = false
		add_child(flame)
		flame_merge.add_tongue(flame)
		flames.append(flame)
	hazard = FireHazard.new()
	hazard.active = false
	add_child(hazard)
	updraft = WindZone.new()
	updraft.name = "HotUpdraft"
	updraft.heat = true
	updraft.wind_direction = Vector2.UP
	updraft.wind_strength = 0.0  # no lift until the flame breaks out
	updraft.visible = false
	add_child(updraft)
	glow_layer = Node2D.new()
	glow_layer.name = "Glow"
	glow_layer.show_behind_parent = true
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = additive
	add_child(glow_layer)
	glow_layer.draw.connect(_draw_glow)


# --- Driven by the pile ------------------------------------------------------------

## A heap has formed: start glowing (AMBER) at `base` (the pile's local px), `heap_width`
## px wide.
func start(base: Vector2, heap_width: float) -> void:
	stage = Stage.AMBER
	lit_time = 0.0
	ignite_timer = 0.0
	spark_timer = randf_range(fire_tuning.bonfire_spark_interval.x, fire_tuning.bonfire_spark_interval.y)
	set_footprint(base, heap_width)
	visible = true
	queue_redraw()


## Follows the heap: where its base is and how wide it is.
func set_footprint(base: Vector2, heap_width: float) -> void:
	position = base
	var clamped: float = clampf(heap_width, fire_tuning.bonfire_min_width, fire_tuning.bonfire_max_width)
	if absf(clamped - width) >= 0.5 or tongue_heights.is_empty():
		width = clamped
		_lay_out_tongues()


## The pile tells us whether we're one of a row of bonfires along a long pile:
## then our tongues stand further apart (ROW_PX_PER_TONGUE).
func set_in_row(in_row: bool) -> void:
	var spacing: float = ROW_PX_PER_TONGUE if in_row else PX_PER_TONGUE
	if spacing != px_per_tongue:
		px_per_tongue = spacing
		_lay_out_tongues()


## The pile tells us where the heap's leaves lie (x relative to our origin, px), so
## the tongues can follow how dense it is. Only re-laid out when the heap changed
## (a bonfire's leaves are held: usually they don't move).
func set_leaf_spread(offsets: PackedFloat32Array) -> void:
	if offsets == leaf_offsets:
		return
	leaf_offsets = offsets
	_lay_out_tongues()


## Goes out. `instant` (a room reset): no smoke.
func put_out(instant: bool) -> void:
	stage = Stage.OUT
	for flame: FlameTongue in flames:
		flame.visible = false
	hazard.active = false
	updraft.wind_strength = 0.0
	updraft.visible = false
	visible = false
	if not instant:
		SmokePuff.spawn(_get_effects_parent(), global_position + Vector2(0.0, -4.0), 4)


## Glowing or burning (any stage but OUT).
func is_lit() -> bool:
	return stage != Stage.OUT


## Its flame is up: it kills and lifts (LOW and later).
func is_flaming() -> bool:
	return stage == Stage.LOW or stage == Stage.GROWING or stage == Stage.FULL


## The flame's height right now, px (0 while AMBER).
func get_flame_height() -> float:
	var full_height: float = fire_tuning.bonfire_flame_height
	var low_height: float = full_height * fire_tuning.bonfire_low_height_share
	match stage:
		Stage.LOW:
			# The low flame breaks out of the coals over its first 0.1 s.
			var since_low: float = lit_time - fire_tuning.bonfire_amber_time
			return low_height * clampf(since_low / 0.1, 0.3, 1.0)
		Stage.GROWING:
			var since_grow: float = lit_time - fire_tuning.bonfire_amber_time - fire_tuning.bonfire_low_time
			var t: float = clampf(since_grow / maxf(fire_tuning.bonfire_grow_time, 0.01), 0.0, 1.0)
			return lerpf(low_height, full_height, ease(t, 0.5))  # rises fast, then settles
		Stage.FULL:
			return full_height
	return 0.0


# --- Every frame ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if stage == Stage.OUT:
		return
	lit_time += delta
	var previous_stage: Stage = stage
	stage = _get_stage_for(lit_time)
	if previous_stage == Stage.AMBER and is_flaming():
		_on_flame_breaks_out()
	var duration: float = fire_tuning.bonfire_duration
	if duration > 0.0 and lit_time >= duration:
		burnt_out.emit(self)
		return
	_update_flame()
	if is_flaming():
		ignite_timer -= delta
		if ignite_timer <= 0.0:
			ignite_timer = IGNITE_INTERVAL
			_ignite_touching()
		_pop_sparks(delta)
	queue_redraw()
	glow_layer.queue_redraw()


func _get_stage_for(time: float) -> Stage:
	var amber_end: float = fire_tuning.bonfire_amber_time
	var low_end: float = amber_end + fire_tuning.bonfire_low_time
	if time < amber_end:
		return Stage.AMBER
	if time < low_end:
		return Stage.LOW
	if time < low_end + fire_tuning.bonfire_grow_time:
		return Stage.GROWING
	return Stage.FULL


## The flame breaks out of the amber: the lighting effects (§9.4).
func _on_flame_breaks_out() -> void:
	var effects_parent: Node = _get_effects_parent()
	var flame_middle: Vector2 = global_position + Vector2(0.0, -4.0)
	FireRing.spawn(effects_parent, flame_middle, width / 2.0 + 4.0, 0.25)
	EmberEmitter.burst(effects_parent, flame_middle, 16, Vector2.UP, 70.0, 90.0)
	FX.shake(fire_tuning.bonfire_light_shake, 0.2)
	FX.flash_screen(FLASH_COLOR, 0.08)
	FX.play_sfx(&"fire_ignite")
	_ignite_touching()


## Flames, kill zone and updraft follow the flame's height and the heap's width.
func _update_flame() -> void:
	var flame_height: float = get_flame_height()
	var flaming: bool = is_flaming()
	for tongue_index: int in flames.size():
		var flame: FlameTongue = flames[tongue_index]
		var in_use: bool = flaming and tongue_index < tongue_heights.size()
		flame.visible = in_use
		if not in_use:
			continue
		flame.length = flame_height * tongue_heights[tongue_index]
		# Smoke from the tallest tongues only.
		flame.smoke_rate = fire_tuning.bonfire_smoke_per_second / 2.0 if tongue_heights[tongue_index] >= 0.95 else 0.0
	hazard.active = flaming
	if flaming:
		# As tall as the tallest tongue (a thin heap's fire is low all along).
		var kill_height: float = flame_height * float(tongue_heights.max()) if not tongue_heights.is_empty() else flame_height
		hazard.hazard_size = Vector2(width, kill_height)
		hazard.position = Vector2(0.0, -kill_height / 2.0)
	# The updraft: as wide as the fire, standing on the flame's top (the zone's
	# position is its top-left corner). Resized only on a real change (see RESIZE_STEP).
	var wanted_size: Vector2 = Vector2(width, fire_tuning.bonfire_updraft_height)
	if absf(updraft.zone_size.x - wanted_size.x) >= RESIZE_STEP or updraft.zone_size.y != wanted_size.y:
		updraft.zone_size = wanted_size
	updraft.position = Vector2(-updraft.zone_size.x / 2.0, -flame_height - updraft.zone_size.y)
	var lift: float = fire_tuning.hot_updraft_lift if flaming else 0.0
	if updraft.wind_strength != lift:
		updraft.wind_strength = lift
	updraft.visible = flaming


## Spreads the tongues over the width: one per PX_PER_TONGUE. Each one's height:
## from the density of the leaves around it (leaves per px within one tongue spacing
## either side, over bonfire_full_density), or without leaf positions 1.0 in the
## middle down to 0.5 at the ends. Plus a little irregularity either way.
func _lay_out_tongues() -> void:
	var tongue_count: int = clampi(roundi(width / px_per_tongue), MIN_TONGUES, MAX_TONGUES)
	var spacing: float = (width - 4.0) / tongue_count
	tongue_heights.clear()
	for tongue_index: int in tongue_count:
		# -1 at the left end, +1 at the right end.
		var across: float = (float(tongue_index) + 0.5) / tongue_count * 2.0 - 1.0
		var tongue_x: float = across * (width / 2.0 - 2.0)
		flames[tongue_index].position = Vector2(tongue_x, 0.0)
		var height_share: float = 1.0 - 0.5 * across * across
		if not leaf_offsets.is_empty():
			var leaves_near: int = 0
			for offset: float in leaf_offsets:
				if absf(offset - tongue_x) <= spacing:
					leaves_near += 1
			var density: float = leaves_near / (spacing * 2.0)
			height_share = density / maxf(fire_tuning.bonfire_full_density, 0.01)
		height_share += 0.06 if tongue_index % 2 == 0 else -0.06
		tongue_heights.append(clampf(height_share, MIN_TONGUE_HEIGHT_SHARE, 1.0))


## Lights what the flame touches: flammables in it (grown by bonfire_ignite_reach)
## and grass along its base and sides. Our own pile's leaves are lit directly (its
## LeafFire), only the ones in reach: leaf-to-leaf spread alone stops at the gaps
## of a pile's thin ends (play-test: a wide pile burnt only near where it was lit).
func _ignite_touching() -> void:
	var flame_height: float = maxf(get_flame_height(), 2.0)
	var flame_rect: Rect2 = Rect2(global_position + Vector2(-width / 2.0, -flame_height), Vector2(width, flame_height))
	var reach_rect: Rect2 = flame_rect.grow(fire_tuning.bonfire_ignite_reach)
	Flammable.ignite_in_rect(get_tree(), reach_rect, self, get_parent(), fire_tuning.bonfire_ignite_reach)
	var pile: LeafPile = get_parent() as LeafPile
	if pile != null and pile.fire != null:
		# The pile isn't rotated or scaled: a world rect moves into its coordinates.
		pile.fire.light_in_rect(Rect2(pile.to_local(reach_rect.position), reach_rect.size))


## Sparks pop upward in bursts at random intervals (§9.3).
func _pop_sparks(delta: float) -> void:
	spark_timer -= delta
	if spark_timer > 0.0:
		return
	spark_timer = randf_range(fire_tuning.bonfire_spark_interval.x, fire_tuning.bonfire_spark_interval.y)
	var top: Vector2 = global_position + Vector2(randf_range(-width / 4.0, width / 4.0), -get_flame_height())
	EmberEmitter.burst(_get_effects_parent(), top, fire_tuning.bonfire_spark_count, Vector2.UP, 25.0, 60.0)


## Effects go to the room (the pile's parent), so they outlive a reset of the pile.
func _get_effects_parent() -> Node:
	var pile: Node = get_parent()
	return pile.get_parent() if pile != null and pile.get_parent() != null else self


## Coals: a low dark mound with ember specks that pulse. While AMBER they glow brighter
## and faster: that's the whole fire for now.
func _draw() -> void:
	if stage == Stage.OUT:
		return
	var half_width: float = width / 2.0 + 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half_width, 0.0), Vector2(-half_width * 0.6, -2.0), Vector2(0.0, -3.0),
		Vector2(half_width * 0.6, -2.0), Vector2(half_width, 0.0)]), COAL_COLOR)
	var speck_count: int = maxi(roundi(width * COAL_SPECKS_PER_PX), 4)
	var pulse_speed: float = 11.0 if stage == Stage.AMBER else 7.0
	for speck_index: int in speck_count:
		var x: float = lerpf(-half_width + 2.0, half_width - 2.0, float(speck_index) / (speck_count - 1))
		var y: float = -1.0 - float(speck_index % 3) * 0.6
		var pulse: float = 0.5 + 0.5 * sin(lit_time * pulse_speed + speck_index * 1.9)
		draw_rect(Rect2(x - 0.5, y - 0.5, 1.0, 1.0), EMBER_COLOR.lerp(EMBER_HOT_COLOR, pulse))


## A soft warm glow round the fire's foot (additive, under the flames): small and
## pulsing while AMBER, big and flickering once the flame is up.
func _draw_glow() -> void:
	if stage == Stage.OUT:
		return
	var flicker: float = 0.85 + 0.15 * sin(lit_time * 11.0) * sin(lit_time * 4.3)
	var flame_height: float = get_flame_height()
	var radius: float = maxf(width * 0.6, (flame_height + width * 0.5) * 0.8) * flicker
	var alpha: float = 0.05 if stage == Stage.AMBER else 0.07
	var center: Vector2 = Vector2(0.0, -flame_height * 0.3 - 1.0)
	# Three stacked circles = a soft edge (a few bonfires at most, so the cost is nothing).
	for ring_index: int in 3:
		var ring_scale: float = 1.0 - ring_index * 0.3
		glow_layer.draw_circle(center, radius * ring_scale, Color(GLOW_COLOR, alpha))

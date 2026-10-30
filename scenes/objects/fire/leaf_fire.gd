class_name LeafFire
extends Node
## LeafFire (Stage F7, F7 play-test): the fire of ONE LeafPile. The leaves are what
## burns, not the pile: every leaf has its own fire state, wherever it is (still in
## the heap, blown across the room, falling).
##
##   UNLIT -> BURNING -> GONE
##            a little ember: harmless to the player, lights unlit leaves within
##            leaf_spread_radius after ~leaf_spread_delay, and every
##            leaf_ignite_interval lights flammables within leaf_ignite_reach
##            (grass, air diamonds, other piles). A lone one burns out after
##            leaf_burn_time (± leaf_burn_jitter); then it's gone (a flake of ash).
##
## BONFIRES: wherever at least bonfire_min_leaves burning leaves LIE together
## (resting, not falling: in touching cells of bonfire_cluster_cell px), a Bonfire
## stands over them, as wide as the heap. A heap much wider than bonfire_max_width
## (a long pile along a floor) gets a ROW of bonfires side by side, one per
## bonfire_max_width stretch of the pile (fixed stretches, so they don't jump around
## while the fire spreads), so flames rise along the whole pile. Each bonfire's
## tongues are as tall as the leaves under them are dense (Bonfire.set_leaf_spread):
## low where the pile thins out. Its leaves are HELD: they don't burn out
## while it lasts (bonfire_duration, 0 = until R); when it runs out they all burn
## away at once. Blow the heap apart (a close gust launches its leaves) and the
## bonfire goes out, while the leaves fly on, still burning, as a spray of embers
## that may light grass or form a new bonfire where enough land together. Gust a
## cloud of leaves up and light it, and it rains embers.
##
## The pile makes this node (its child) the first time anything lights it, so piles
## that never burn (Air rooms) never pay for it. The pile keeps moving the leaves
## (flying, landing, stacking); this node only reads their positions and tells the
## pile when one is gone (LeafPile.remove_leaf).
##
## LIT BY THE JET (play-test: jetting along a floor of leaves got you killed by the
## fire you'd just lit): leaves the flame jet touches are PRIMED, not lit. They catch
## leaf_jet_catch_delay later (glowing meanwhile), so you're past before a bonfire
## forms behind you. Like a crate (crate_jet_catch_delay). Fireballs and other fires
## light leaves at once.
##
## Cost (see Fire_bending.md §13 "F7 play-test"): nothing while no leaf burns. While
## some do, per physics frame: one pass over the live leaves to bucket them (spread
## lookups and heap detection), a flood fill over the heap's cells, and the ignite
## checks of the burning leaves (each leaf only every leaf_ignite_interval).

enum LeafState { UNLIT, BURNING, GONE }

## Buckets for "which leaves are near this point", px. Bigger than the spread radius,
## so a lookup only needs the 3x3 buckets around a leaf.
const SPREAD_BUCKET: float = 4.0
## Every this many burnt-out leaves leaves a flake of ash in the room's PebbleField.
const LEAVES_PER_ASH_FLAKE: int = 3
## Two heaps closer than this (px, between centers) are the same bonfire from frame
## to frame (so a bonfire that shifts a little doesn't restart its growth).
const BONFIRE_MATCH_DISTANCE: float = 12.0
## A heap wider than this many bonfire_max_width gets a row of bonfires (see
## _split_wide_heap); up to it, one bonfire (clamped to bonfire_max_width) covers it.
const WIDE_HEAP_SHARE: float = 1.25
## "Not part of a row" (see bonfire_stretches).
const NO_STRETCH: int = -1000000

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var pile: LeafPile
## Per leaf (same index as the pile's arrays).
var leaf_states: PackedByteArray = PackedByteArray()
## Seconds left for a burning leaf (paused while held by a bonfire).
var burn_left: PackedFloat32Array = PackedFloat32Array()
## Seconds until a burning leaf lights its neighbours (< 0: done) / its next ignite check.
var spread_left: PackedFloat32Array = PackedFloat32Array()
var ignite_left: PackedFloat32Array = PackedFloat32Array()
## The bonfire holding each leaf this frame (index into `bonfires`), -1 = none.
var held_by: PackedInt32Array = PackedInt32Array()
## How many leaves burn right now.
var burning_count: int = 0
## Per leaf: seconds until a leaf primed by the jet catches; < 0 = not primed.
var catch_left: PackedFloat32Array = PackedFloat32Array()
## How many leaves are primed right now.
var primed_count: int = 0
## Seconds of fire time (drives the embers' flicker in the pile's drawing).
var clock: float = 0.0
## Bonfires made so far (reused; the pile's children). Put-out ones wait for a heap.
var bonfires: Array[Bonfire] = []
## Bonfire -> the pile's stretch it burns over, when it is part of a row (see
## _split_wide_heap); NO_STRETCH for a bonfire over a whole heap.
var bonfire_stretches: Dictionary = {}
var burnt_leaf_count: int = 0
## Live leaves (not gone) by SPREAD_BUCKET bucket, rebuilt each frame while burning.
var buckets: Dictionary = {}


func setup(owner_pile: LeafPile) -> void:
	pile = owner_pile
	name = "LeafFire"
	var count: int = pile.leaf_positions.size()
	leaf_states.resize(count)
	burn_left.resize(count)
	spread_left.resize(count)
	ignite_left.resize(count)
	held_by.resize(count)
	catch_left.resize(count)
	reset()


# --- Questions -------------------------------------------------------------------

func is_gone(leaf_index: int) -> bool:
	return leaf_states[leaf_index] == LeafState.GONE


func is_leaf_burning(leaf_index: int) -> bool:
	return leaf_states[leaf_index] == LeafState.BURNING


func is_held(leaf_index: int) -> bool:
	return held_by[leaf_index] >= 0


## 0..1: how far a lone burning leaf has burnt (1 = about to go). Held leaves: 0.
func get_burn_share(leaf_index: int) -> float:
	if held_by[leaf_index] >= 0 or leaf_states[leaf_index] != LeafState.BURNING:
		return 0.0
	return 1.0 - clampf(burn_left[leaf_index] / maxf(fire_tuning.leaf_burn_time, 0.01), 0.0, 1.0)


## Any bonfire standing right now (glowing or flaming).
func get_lit_bonfires() -> Array[Bonfire]:
	var lit: Array[Bonfire] = []
	for bonfire: Bonfire in bonfires:
		if bonfire.is_lit():
			lit.append(bonfire)
	return lit


# --- Lighting --------------------------------------------------------------------

## Lights every unlit leaf within `radius` px (plus the leaf's own size) of `point`
## (the pile's local px). Returns true if any caught. `catch_delay` > 0 (the jet):
## they're primed instead, and catch that many seconds later.
func light_near(point: Vector2, radius: float, catch_delay: float = 0.0) -> bool:
	var reach: float = radius + 2.0  # a leaf is 4 px long: touch its tip, it catches
	var any_caught: bool = false
	for leaf_index: int in leaf_states.size():
		if leaf_states[leaf_index] == LeafState.UNLIT \
				and pile.leaf_positions[leaf_index].distance_to(point) <= reach:
			if catch_delay > 0.0:
				prime_leaf(leaf_index, catch_delay)
			else:
				light_leaf(leaf_index)
			any_caught = true
	return any_caught


## Lights every unlit leaf inside `local_rect` (the pile's local px): a bonfire's
## flame lighting the leaves of its own pile it reaches.
func light_in_rect(local_rect: Rect2) -> void:
	for leaf_index: int in leaf_states.size():
		if leaf_states[leaf_index] == LeafState.UNLIT and local_rect.has_point(pile.leaf_positions[leaf_index]):
			light_leaf(leaf_index)


## The leaf catches `delay` seconds from now (unless something lights it sooner).
## Priming it again doesn't push its moment back: the jet touches it every frame.
func prime_leaf(leaf_index: int, delay: float) -> void:
	if leaf_states[leaf_index] != LeafState.UNLIT or catch_left[leaf_index] >= 0.0 			or pile.leaf_is_flying[leaf_index] == LeafPile.FLOATING:
		return
	catch_left[leaf_index] = delay
	primed_count += 1


## 0..1: how close a primed leaf is to catching (it glows hotter), 0 if not primed.
func get_prime_share(leaf_index: int) -> float:
	if catch_left[leaf_index] < 0.0:
		return 0.0
	return 1.0 - clampf(catch_left[leaf_index] / maxf(fire_tuning.leaf_jet_catch_delay, 0.01), 0.0, 1.0)


func light_leaf(leaf_index: int) -> void:
	# A leaf floating on water can't catch (Stage W7b).
	if leaf_states[leaf_index] != LeafState.UNLIT or pile.leaf_is_flying[leaf_index] == LeafPile.FLOATING:
		return
	if catch_left[leaf_index] >= 0.0:
		catch_left[leaf_index] = -1.0
		primed_count -= 1
	leaf_states[leaf_index] = LeafState.BURNING
	var jitter: float = fire_tuning.leaf_burn_jitter
	burn_left[leaf_index] = fire_tuning.leaf_burn_time * randf_range(1.0 - jitter, 1.0 + jitter)
	spread_left[leaf_index] = fire_tuning.leaf_spread_delay * randf_range(0.5, 1.5)
	ignite_left[leaf_index] = randf() * fire_tuning.leaf_ignite_interval  # spread the checks over frames
	burning_count += 1


## Death / R: every leaf unlit, every bonfire out.
func reset() -> void:
	leaf_states.fill(LeafState.UNLIT)
	held_by.fill(-1)
	catch_left.fill(-1.0)
	primed_count = 0
	burning_count = 0
	burnt_leaf_count = 0
	buckets.clear()
	for bonfire: Bonfire in bonfires:
		bonfire.put_out(true)


# --- Every frame (called by the pile's _physics_process) ----------------------------

func update(delta: float) -> void:
	if primed_count > 0:
		_catch_primed_leaves(delta)
	if burning_count == 0:
		return
	clock += delta
	_fill_buckets()
	var flammables: Array[Node] = get_tree().get_nodes_in_group(Flammable.GROUP)
	var burnt_out: Array[int] = []
	for leaf_index: int in leaf_states.size():
		if leaf_states[leaf_index] != LeafState.BURNING:
			continue
		# Spread: once, a moment after catching.
		if spread_left[leaf_index] >= 0.0:
			spread_left[leaf_index] -= delta
			if spread_left[leaf_index] < 0.0:
				_spread_from(leaf_index)
		# Light what's around it (grass, air diamonds, other piles).
		ignite_left[leaf_index] -= delta
		if ignite_left[leaf_index] <= 0.0:
			ignite_left[leaf_index] = fire_tuning.leaf_ignite_interval
			_ignite_around(leaf_index, flammables)
		# Burn down, unless a bonfire holds it.
		if held_by[leaf_index] < 0:
			burn_left[leaf_index] -= delta
			if burn_left[leaf_index] <= 0.0:
				burnt_out.append(leaf_index)
	for leaf_index: int in burnt_out:
		_burn_away(leaf_index)
	_update_bonfires()


## Primed leaves count down; the ones whose time is up catch.
func _catch_primed_leaves(delta: float) -> void:
	for leaf_index: int in catch_left.size():
		if catch_left[leaf_index] < 0.0:
			continue
		if leaf_states[leaf_index] != LeafState.UNLIT:
			catch_left[leaf_index] = -1.0  # (can't happen: lighting clears it; just in case)
			primed_count -= 1
			continue
		catch_left[leaf_index] -= delta
		if catch_left[leaf_index] <= 0.0:
			light_leaf(leaf_index)


## Buckets every live leaf (falling ones too: embers light a falling cloud).
func _fill_buckets() -> void:
	buckets.clear()
	for leaf_index: int in leaf_states.size():
		if leaf_states[leaf_index] == LeafState.GONE:
			continue
		var key: Vector2i = _bucket_of(pile.leaf_positions[leaf_index])
		if buckets.has(key):
			(buckets[key] as Array).append(leaf_index)
		else:
			buckets[key] = [leaf_index]


func _bucket_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / SPREAD_BUCKET), floori(point.y / SPREAD_BUCKET))


## Lights the unlit leaves within leaf_spread_radius of leaf `from_index`.
func _spread_from(from_index: int) -> void:
	var origin: Vector2 = pile.leaf_positions[from_index]
	var center: Vector2i = _bucket_of(origin)
	var radius: float = fire_tuning.leaf_spread_radius
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var bucket: Vector2i = center + Vector2i(dx, dy)
			if not buckets.has(bucket):
				continue
			for leaf_index: int in buckets[bucket]:
				if leaf_states[leaf_index] == LeafState.UNLIT \
						and pile.leaf_positions[leaf_index].distance_to(origin) <= radius:
					light_leaf(leaf_index)


## One burning leaf's ignite check: flammables within leaf_ignite_reach of it. Not our
## own pile (its leaves spread above), and not through ignite_near (which would ask
## our own pile too).
func _ignite_around(leaf_index: int, flammables: Array[Node]) -> void:
	var world_point: Vector2 = pile.to_global(pile.leaf_positions[leaf_index])
	for target: Node in flammables:
		if target != pile:
			Flammable.ignite_if_near(target, world_point, fire_tuning.leaf_ignite_reach, pile)


## A gust blew a lone burning leaf out (F7 play-test): it turns to ash at once (a
## flake of ash every time, and a puff of smoke) and is gone from the pile.
func snuff_leaf(leaf_index: int) -> void:
	if leaf_states[leaf_index] != LeafState.BURNING:
		return
	var world_point: Vector2 = pile.to_global(pile.leaf_positions[leaf_index])
	PebbleField.leave_ash(get_tree(), world_point, 1, Vector2(2, 2), FireGrid.ASH_FLAKE_COLORS)
	SmokePuff.spawn(pile.get_parent(), world_point, 1)
	_burn_away(leaf_index, false)


## A leaf burnt away: gone from the pile (the leaves on it fall), and a flake of ash
## now and then (`leave_ash`: false when the caller already left one).
func _burn_away(leaf_index: int, leave_ash: bool = true) -> void:
	leaf_states[leaf_index] = LeafState.GONE
	held_by[leaf_index] = -1
	burning_count -= 1
	burnt_leaf_count += 1
	var world_point: Vector2 = pile.to_global(pile.leaf_positions[leaf_index])
	if leave_ash and burnt_leaf_count % LEAVES_PER_ASH_FLAKE == 0:
		PebbleField.leave_ash(get_tree(), world_point, 1, Vector2(2, 2), FireGrid.ASH_FLAKE_COLORS)
	pile.remove_leaf(leaf_index)


# --- Bonfires ----------------------------------------------------------------------

## Finds the heaps of burning leaves lying together and keeps one bonfire on each:
## new heap -> a bonfire starts (amber); heap gone or too small -> its bonfire goes
## out. Heap leaves are held (they don't burn down).
func _update_bonfires() -> void:
	var heaps: Array = _find_heaps()
	held_by.fill(-1)
	var kept: Array[Bonfire] = []
	for whole_heap: Array in heaps:
		var parts: Array = _split_wide_heap(whole_heap)
		for heap: Array in parts:
			var bounds: Rect2 = _get_heap_bounds(heap)
			# The base: the middle of the heap's bottom (leaves lie ~1 px above what they
			# rest on, so +1 puts the coals on the floor).
			var base: Vector2 = Vector2(bounds.get_center().x, bounds.end.y + 1.0)
			var heap_width: float = bounds.size.x + 4.0  # + a leaf's half length each side
			# A part of a row keeps the bonfire of its stretch, however far its middle
			# moves as the fire spreads through it; a whole heap, the nearest bonfire.
			var stretch: int = NO_STRETCH
			if parts.size() > 1:
				stretch = floori(base.x / maxf(fire_tuning.bonfire_max_width, 1.0))
			var bonfire: Bonfire = _find_bonfire_for(base, stretch, kept)
			if bonfire == null:
				bonfire = _get_free_bonfire(kept)
				bonfire.start(base, heap_width)
			else:
				bonfire.set_footprint(base, heap_width)
			bonfire_stretches[bonfire] = stretch
			bonfire.set_in_row(stretch != NO_STRETCH)
			# Where its leaves lie, across it: the tongues are tall where they're dense.
			var leaf_offsets: PackedFloat32Array = PackedFloat32Array()
			for leaf_index: int in heap:
				leaf_offsets.append(pile.leaf_positions[leaf_index].x - base.x)
			bonfire.set_leaf_spread(leaf_offsets)
			kept.append(bonfire)
			var bonfire_index: int = bonfires.find(bonfire)
			for leaf_index: int in heap:
				held_by[leaf_index] = bonfire_index
	for bonfire: Bonfire in bonfires:
		if bonfire.is_lit() and not kept.has(bonfire):
			bonfire.put_out(false)


## Groups of resting burning leaves in touching cells, at least bonfire_min_leaves
## each. Returns Array of Array[int] (leaf indices).
func _find_heaps() -> Array:
	var cell_size: float = maxf(fire_tuning.bonfire_cluster_cell, 1.0)
	var cells: Dictionary = {}  # Vector2i -> Array of leaf indices
	for leaf_index: int in leaf_states.size():
		if leaf_states[leaf_index] != LeafState.BURNING or pile.leaf_is_flying[leaf_index] == 1:
			continue
		var point: Vector2 = pile.leaf_positions[leaf_index]
		var cell: Vector2i = Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
		if cells.has(cell):
			(cells[cell] as Array).append(leaf_index)
		else:
			cells[cell] = [leaf_index]
	var heaps: Array = []
	var visited: Dictionary = {}
	for start_cell: Vector2i in cells:
		if visited.has(start_cell):
			continue
		# Flood fill over the 8 neighbouring cells.
		var heap: Array[int] = []
		var to_visit: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		while not to_visit.is_empty():
			var cell: Vector2i = to_visit.pop_back()
			for leaf_index: int in cells[cell]:
				heap.append(leaf_index)
			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					var neighbour: Vector2i = cell + Vector2i(dx, dy)
					if cells.has(neighbour) and not visited.has(neighbour):
						visited[neighbour] = true
						to_visit.append(neighbour)
		if heap.size() >= fire_tuning.bonfire_min_leaves:
			heaps.append(heap)
	return heaps


## A heap no wider than WIDE_HEAP_SHARE x bonfire_max_width stays one bonfire (a
## little too wide for it is covered well enough). A wider one is cut into the
## pile's fixed stretches of bonfire_max_width px (x / bonfire_max_width, in the
## pile's own coordinates, so a stretch's bonfire stays put while the fire spreads).
## A stretch with fewer than bonfire_min_leaves burning leaves joins the stretch
## before it (or after it, for the first), so no leaves of the heap go unheld.
## Returns Array of Array[int], left to right.
func _split_wide_heap(heap: Array) -> Array:
	var span: float = maxf(fire_tuning.bonfire_max_width, 1.0)
	if _get_heap_bounds(heap).size.x + 4.0 <= span * WIDE_HEAP_SHARE:
		return [heap]
	var stretches: Dictionary = {}  # stretch number -> Array of leaf indices
	for leaf_index: int in heap:
		var stretch: int = floori(pile.leaf_positions[leaf_index].x / span)
		if stretches.has(stretch):
			(stretches[stretch] as Array).append(leaf_index)
		else:
			stretches[stretch] = [leaf_index]
	var numbers: Array = stretches.keys()
	numbers.sort()
	var parts: Array = []
	for number: int in numbers:
		var part: Array = stretches[number]
		if part.size() < fire_tuning.bonfire_min_leaves and not parts.is_empty():
			(parts[parts.size() - 1] as Array).append_array(part)
		else:
			parts.append(part)
	# The first stretch may still be too small (nothing before it to join).
	if parts.size() > 1 and (parts[0] as Array).size() < fire_tuning.bonfire_min_leaves:
		(parts[1] as Array).append_array(parts[0])
		parts.remove_at(0)
	return parts


func _get_heap_bounds(heap: Array) -> Rect2:
	var bounds: Rect2 = Rect2(pile.leaf_positions[heap[0]], Vector2.ZERO)
	for leaf_index: int in heap:
		bounds = bounds.expand(pile.leaf_positions[leaf_index])
	return bounds


## The lit bonfire that goes on burning over this heap, not already given a heap
## this frame: the one of the same stretch of a row (`stretch`), else the one
## standing nearest `base` (within BONFIRE_MATCH_DISTANCE).
func _find_bonfire_for(base: Vector2, stretch: int, taken: Array[Bonfire]) -> Bonfire:
	if stretch != NO_STRETCH:
		for bonfire: Bonfire in bonfires:
			if bonfire.is_lit() and not taken.has(bonfire) and bonfire_stretches.get(bonfire, NO_STRETCH) == stretch:
				return bonfire
	var best: Bonfire = null
	var best_distance: float = BONFIRE_MATCH_DISTANCE
	for bonfire: Bonfire in bonfires:
		if not bonfire.is_lit() or taken.has(bonfire):
			continue
		var distance: float = bonfire.position.distance_to(base)
		if distance < best_distance:
			best = bonfire
			best_distance = distance
	return best


## A bonfire that isn't burning, or a new one.
func _get_free_bonfire(taken: Array[Bonfire]) -> Bonfire:
	for bonfire: Bonfire in bonfires:
		if not bonfire.is_lit() and not taken.has(bonfire):
			return bonfire
	var bonfire: Bonfire = Bonfire.new()
	bonfire.name = "Bonfire%d" % bonfires.size()
	pile.add_child(bonfire)
	bonfire.burnt_out.connect(_on_bonfire_burnt_out)
	bonfires.append(bonfire)
	return bonfire


## A bonfire's time ran out (bonfire_duration): its leaves burn away and it goes out.
func _on_bonfire_burnt_out(bonfire: Bonfire) -> void:
	var bonfire_index: int = bonfires.find(bonfire)
	for leaf_index: int in held_by.size():
		if held_by[leaf_index] == bonfire_index and leaf_states[leaf_index] == LeafState.BURNING:
			_burn_away(leaf_index)
	bonfire.put_out(false)

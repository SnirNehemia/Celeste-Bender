extends Node
## Headless smoke test for the Water chapter (Stages W1+). Not part of the game.
##
## Loads tests/water_test_world.tscn and checks, by script, what can be checked
## without a person at the keyboard. Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/water_smoke_test.tscn
## Every Water stage adds a section here (Water_bending.md §13).
##
## W1 waits for the water to settle a few times, so it takes about a minute.

const WORLD_SCENE: PackedScene = preload("res://tests/water_test_world.tscn")
## Water is conserved to within this many units (float crumbs).
const CONSERVATION_TOLERANCE: float = 0.02
## The §6.5 budget: the whole water step, in microseconds per physics frame.
const BUDGET_USEC: int = 2000
## How long to wait for the water to settle, seconds.
const SETTLE_TIMEOUT: float = 20.0

var failures: int = 0
## Names of the check sections that ran to their end. A script error inside a
## section ends it silently, so _ready() checks this list.
var finished_sections: Array[String] = []


func _ready() -> void:
	# Drops get random jitter (and splashes random angles): a fixed seed makes every
	# run the same, so a check near its limit can't pass on one run and fail the next.
	seed(20261027)
	var world: RoomManager = WORLD_SCENE.instantiate() as RoomManager
	add_child(world)
	# Let the player drop onto the floor and the room manager pick the room.
	await get_tree().create_timer(0.3).timeout
	await _check_w1_bodies(world, world.player)
	await _check_swimming(world, world.player)

	for section_name: String in ["W1", "Swim"]:
		_check(finished_sections.has(section_name), "section %s ran to its end" % section_name)
	print("[WaterSmokeTest] %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Stage W1: water bodies (Water_bending.md §6.1, §14).
func _check_w1_bodies(world: RoomManager, player: Player) -> void:
	var room: Room = world.current_room
	_check(room.name == &"RoomWaterA", "the world starts in RoomWaterA, got %s" % room.name)

	# Keys, flags, tuning.
	_check(_action_has_key("debug_water_wave", KEY_8), "debug_water_wave is on 8")
	_check(_action_has_key("debug_water_dump", KEY_9), "debug_water_dump is on 9")
	_check(_action_has_key("debug_water_drain", KEY_0), "debug_water_drain is on 0")
	_check(_action_has_key("debug_water_look", KEY_7), "debug_water_look is on 7")
	_check(room.water_allowed and player.is_element_allowed(Player.ELEMENT_WATER), "Water is on in Water A")
	var plain_room: Room = Room.new()
	_check(not plain_room.water_allowed, "water is off by default, so older rooms are unchanged")
	plain_room.free()
	_check(player.water_tuning != null and player.water_tuning.resource_path == "res://resources/water_tuning.tres",
		"the player holds water_tuning.tres")

	# The room's WaterWorld and its bodies.
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "a room with a Water layer gets a WaterWorld")
	if water == null:
		return
	var layer: WaterLayer = room.get_node("Water") as WaterLayer
	_check(water.water_tuning == player.water_tuning, "the WaterWorld reads the same tuning resource as the player (F5 reaches it)")
	_check(layer.self_modulate.a == 0.0, "the painted tiles are hidden in play (the WaterWorld draws the water)")
	_check(is_equal_approx(water.column_width, 2.0), "columns are 2 px wide, got %s" % water.column_width)
	_check(is_equal_approx(water.get_initial_units(), float(layer.get_used_cells().size())),
		"one unit per painted tile: %.2f units for %d tiles" % [water.get_initial_units(), layer.get_used_cells().size()])
	_check(water.bodies.size() == 3, "three bodies: the pool, the tank and the joined pools, got %d" % water.bodies.size())
	var passage: Array = water.find_body_under(Vector2(54 * 8 + 4, 140))
	_check(not passage.is_empty() and is_equal_approx((passage[0] as WaterBody).ceiling_y[passage[1]], 128.0),
		"the passage under the wall is part of a body, with the wall as its ceiling")
	_check(water.find_body_under(Vector2(40 * 8, 120)).is_empty(), "the basin starts dry")

	# Conservation while the tank overflows into the pool, and everything settles.
	var books_at_start: float = water.get_total_units() + water.get_lost_units()
	var settled: bool = await _wait_until_calm(water)
	_check(settled, "the water settles and every body falls asleep (awake %d, drops %d)" % [water.get_awake_count(), water.get_drop_count()])
	var books_settled: float = water.get_total_units() + water.get_lost_units()
	_check(absf(books_settled - books_at_start) < CONSERVATION_TOLERANCE,
		"water is conserved while it spills and sloshes: %.3f -> %.3f units" % [books_at_start, books_settled])
	_check(water.get_lost_units() < CONSERVATION_TOLERANCE, "no water left the room, lost %.3f" % water.get_lost_units())
	var tank_surface: float = water.get_surface_y_at(Vector2(12 * 8, 30))
	# It ends a little BELOW its lip: the water rushing to the outlet sloshes, the
	# heap above the lip pours over, the backswing leaves the rest lower (a real
	# dam-break does that). Never far above it: that water would still be spilling.
	_check(tank_surface >= 40.0 - water.water_tuning.puddle_min_depth - 0.6 and tank_surface <= 44.0,
		"the tank spilled down to about its lip (y 40), its surface is at %.1f" % tank_surface)
	var pool_surface: float = water.get_surface_y_at(Vector2(15 * 8, 125))
	_check(pool_surface < 119.0 and pool_surface > 112.0, "the pool rose from y 120 with the tank's water, now %.1f" % pool_surface)
	var pool: WaterBody = water.find_body_under(Vector2(15 * 8, 125))[0]
	_check(_surface_spread(pool) < 0.3, "the pool is level once calm (spread %.2f px)" % _surface_spread(pool))

	# The crate floats, about half under.
	var crate: Crate = room.get_node("Crate1") as Crate
	var crate_bottom: float = crate.global_position.y
	_check(not crate.is_on_floor() and crate_bottom > pool_surface + 4.0 and crate_bottom < pool_surface + 12.0,
		"the crate floats about half under: bottom %.1f, surface %.1f" % [crate_bottom, pool_surface])
	_check(crate.velocity.length() < 5.0, "the floating crate comes to rest, speed %.1f" % crate.velocity.length())

	# A wave: poke the pool's right side; the ripple reaches the far left end.
	var left_end_x: float = 6 * 8
	var far_before: float = pool.get_surface_y(pool.get_column_at(left_end_x))
	_check(water.poke(Vector2(22 * 8, 120), 6.0), "poke() finds the pool")
	_check(not pool.is_asleep, "a poke wakes the pool")
	var far_moved: float = 0.0
	var crate_moved: float = 0.0
	for frame: int in 120:
		await get_tree().physics_frame
		far_moved = maxf(far_moved, absf(pool.get_surface_y(pool.get_column_at(left_end_x)) - far_before))
		crate_moved = maxf(crate_moved, absf(crate.global_position.y - crate_bottom))
	_check(far_moved > 0.5, "the wave crosses the pool: the far end moved %.2f px" % far_moved)
	_check(crate_moved > 0.5, "the crate bobs on the wave (moved %.2f px)" % crate_moved)
	_check(await _wait_until_calm(water), "the wave dies down and the pool sleeps again")

	# The staircase: water dropped on the top step runs down into the basin.
	water.add_loose_water(Vector2(29 * 8, 96), 6.0)
	_check(water.get_drop_count() > 0, "add_loose_water() makes falling drops")
	_check(await _wait_until_calm(water), "the staircase water settles")
	var basin_units: float = _units_in(water, 36 * 8, 43 * 8, 144.0)
	# Not all of it: each step keeps a film (surface tension) and some runs back
	# into the pool, depending on how the drops happen to land.
	_check(basin_units > 2.5, "a good part of 6 units ran down the steps into the basin: %.2f units there" % basin_units)
	_check(_bodies_on_floor(water, 36 * 8, 43 * 8, 144.0) == 1,
		"the drops that landed apart in the basin merged into one body, got %d" % _bodies_on_floor(water, 36 * 8, 43 * 8, 144.0))
	books_settled = water.get_total_units() + water.get_lost_units()
	_check(absf(books_settled - books_at_start - 6.0) < CONSERVATION_TOLERANCE,
		"conserved down the stairs: %.3f units (start + 6 = %.3f)" % [books_settled, books_at_start + 6.0])

	# The joined pools: draining one side lowers both, through the passage.
	var left_side: Vector2 = Vector2(49 * 8, 130)
	var right_side: Vector2 = Vector2(58 * 8, 130)
	var level_before: float = water.get_surface_y_at(left_side)
	var taken: float = water.remove_water_near(Vector2(49 * 8, level_before), 4.0)
	_check(is_equal_approx(taken, 4.0), "remove_water_near() takes 4 units, got %.3f" % taken)
	_check(await _wait_until_calm(water), "the joined pools settle")
	var left_level: float = water.get_surface_y_at(left_side)
	var right_level: float = water.get_surface_y_at(right_side)
	_check(absf(left_level - right_level) < 0.3 and right_level > level_before + 1.0,
		"both sides end at the same level, lower than before: left %.2f, right %.2f, before %.2f" % [left_level, right_level, level_before])
	books_settled = water.get_total_units() + water.get_lost_units()
	_check(absf(books_settled - (books_at_start + 2.0)) < CONSERVATION_TOLERANCE,
		"conserved through the passage: %.3f units (expected %.3f)" % [books_settled, books_at_start + 2.0])

	# Debug keys. 9: a bucket of drops over the player's head.
	var drops_before: int = water.get_drop_count()
	await _press(&"debug_water_dump")
	var bucket_drops: int = roundi(player.water_tuning.debug_bucket_units / player.water_tuning.drop_units)
	_check(water.get_drop_count() >= drops_before + bucket_drops - 1, "9 drops a bucket (%d drops)" % (water.get_drop_count() - drops_before))
	await _wait_until_calm(water)
	# 0: takes a bucket from the nearest water.
	var units_before_drain: float = water.get_total_units()
	await _press(&"debug_water_drain")
	_check(absf(water.get_total_units() - (units_before_drain - player.water_tuning.debug_bucket_units)) < CONSERVATION_TOLERANCE,
		"0 drains a bucket (%.2f -> %.2f units)" % [units_before_drain, water.get_total_units()])
	await _wait_until_calm(water)
	# 8: pokes the water at the player's feet (the player stands in the pool).
	player.global_position = Vector2(12 * 8, 143)
	player.velocity = Vector2.ZERO
	await _wait_until_calm(water)
	await _press(&"debug_water_wave")
	_check(water.get_awake_count() > 0, "8 pokes the water the player stands in")

	# The player's body pushes the water (§5.4): wading leaves a wake...
	player.global_position = Vector2(8 * 8, 143)
	player.velocity = Vector2.ZERO
	await _wait_until_calm(water)
	var waded_pool: WaterBody = water.find_body_under(water.to_local(Vector2(8 * 8, 130)))[0]
	Input.action_press(&"move_right")
	var wake_height: float = 0.0
	for frame: int in 45:
		await get_tree().physics_frame
		# Only the pool's own columns: a wet film on the stairs can join the same body.
		wake_height = maxf(wake_height, _surface_spread(waded_pool, 5 * 8, 27 * 8))
	Input.action_release(&"move_right")
	print("[WaterSmokeTest] wading wake: %.2f px" % wake_height)
	_check(wake_height > 1.0, "wading through the pool raises a wake (%.1f px)" % wake_height)
	# ...and falling in throws up a splash of the pool's own water.
	await _wait_until_calm(water)
	var units_before_splash: float = water.get_total_units()
	player.global_position = Vector2(22 * 8, 40)
	player.velocity = Vector2.ZERO
	var splash_drops: int = 0
	for frame: int in 60:
		await get_tree().physics_frame
		splash_drops = maxi(splash_drops, water.get_drop_count())
	print("[WaterSmokeTest] splash: %d drops" % splash_drops)
	_check(splash_drops >= 4, "falling into the pool splashes (%d drops thrown)" % splash_drops)
	_check(absf(water.get_total_units() - units_before_splash) < CONSERVATION_TOLERANCE,
		"the splash conserves water (%.3f -> %.3f units)" % [units_before_splash, water.get_total_units()])

	# Reset: the painted water comes back, the drops go.
	player.respawn_at(room.get_spawn_position())
	water.add_loose_water(Vector2(100, 40), 2.0)
	room.reset_objects()
	_check(water.bodies.size() == 3 and water.get_drop_count() == 0, "a reset brings back the three painted bodies and clears the drops")
	_check(is_equal_approx(water.get_total_units(), water.get_initial_units()) and water.get_lost_units() == 0.0,
		"a reset restores exactly the painted water (%.2f units)" % water.get_total_units())

	# Metal crates sink.
	crate.is_metal = true
	crate.reset()
	await get_tree().create_timer(2.5).timeout
	_check(crate.is_on_floor() and absf(crate.global_position.y - 144.0) < 1.0,
		"a metal crate sinks to the pool's floor (y %.1f)" % crate.global_position.y)
	crate.is_metal = false
	room.reset_objects()

	# Performance (Water_bending.md §6.5): every body sloshing and the drop cap full.
	await _wait_until_calm(water)
	water.wake_all()
	for poke_x: float in [60.0, 120.0, 180.0, 400.0, 460.0]:
		water.poke(Vector2(poke_x, 110), 8.0)
	for blob_index: int in 12:
		water.add_loose_water(Vector2(48 + blob_index * 36, 30), 2.5)
	var cap: int = player.water_tuning.max_drops
	_check(water.get_drop_count() <= cap + 12, "the drop cap holds (%d drops, cap %d)" % [water.get_drop_count(), cap])
	var total_usec: int = 0
	var bodies_usec: int = 0
	var drops_usec: int = 0
	var peak_usec: int = 0
	var most_drops: int = 0
	for frame: int in 120:
		await get_tree().physics_frame
		total_usec += water.last_step_usec
		bodies_usec += water.last_bodies_usec
		drops_usec += water.last_drops_usec
		peak_usec = maxi(peak_usec, water.last_step_usec)
		most_drops = maxi(most_drops, water.get_drop_count())
	var average_usec: float = total_usec / 120.0
	print("[WaterSmokeTest] water step under stress: %.0f us average (bodies %.0f, drops %.0f), %d us peak, up to %d drops, %d bodies" \
		% [average_usec, bodies_usec / 120.0, drops_usec / 120.0, peak_usec, most_drops, water.bodies.size()])
	_check(average_usec < BUDGET_USEC, "the water step stays under the 2 ms budget: %.0f us average" % average_usec)
	room.reset_objects()

	finished_sections.append("W1")


## Swimming (Water_bending.md §5.4), moved up from W7 after play-test 1: the water
## slows you by how much of you is in it, jumps off the bottom are lower, jump
## strokes you up when your head is under, and leaps you out at the surface.
func _check_swimming(world: RoomManager, player: Player) -> void:
	var room: Room = world.current_room
	var water: WaterWorld = room.get_node(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	var tuning: WaterTuning = player.water_tuning
	room.reset_objects()
	await _wait_until_calm(water)
	_check(player.swim != null, "the player has a SwimAbility")

	# A dry-land jump, held, for comparison.
	var dry_rise: float = await _measure_held_jump(player, Vector2(24, 112))
	_check(not player.swim.is_in_water(), "on the dry ledge the player isn't in water")

	# Standing on the pool's floor (24 px of water over an 11 px player): fully under.
	var bottom: Vector2 = Vector2(19 * 8, 144)
	await _stand_at(player, bottom)
	var surface_y: float = water.get_surface_y_at(water.to_local(Vector2(bottom.x, 130)))
	_check(player.swim.submerged_share > 0.95 and player.swim.is_swimming(),
		"on the pool's floor the player is under water (share %.2f)" % player.swim.submerged_share)

	# The water holds you back: run speed x (1 - water_resistance x share).
	Input.action_press(&"move_right")
	for frame: int in 15:
		await get_tree().physics_frame
	var wading_speed: float = player.velocity.x
	Input.action_release(&"move_right")
	var expected_speed: float = player.tuning.max_run_speed * (1.0 - tuning.water_resistance)
	_check(absf(wading_speed - expected_speed) < 3.0,
		"under water you run at %.0f px/s (expected %.0f, dry %.0f)" % [wading_speed, expected_speed, player.tuning.max_run_speed])

	# A jump off the bottom is lower.
	var water_rise: float = await _measure_held_jump(player, bottom)
	_check(water_rise < dry_rise * 0.75 and water_rise > 4.0,
		"a jump off the pool's floor rises %.1f px, on dry land %.1f px" % [water_rise, dry_rise])

	# Strokes: tapping jump swims up until the head is out...
	await _stand_at(player, bottom)
	var head_came_out: bool = false
	for tap: int in 16:
		await _press(&"jump")
		for frame: int in 6:
			await get_tree().physics_frame
			head_came_out = head_came_out or player.get_hitbox_rect().position.y < surface_y
		if head_came_out:
			break
	_check(head_came_out, "tapping jump strokes the player up until the head is out of the water")
	# ...and a jump there, held, leaps out like a jump on land (a tap is a small hop).
	var highest_feet: float = player.global_position.y
	Input.action_press(&"jump")
	for frame: int in 40:
		await get_tree().physics_frame
		highest_feet = minf(highest_feet, player.global_position.y)
	Input.action_release(&"jump")
	_check(highest_feet < surface_y - 12.0,
		"a held jump at the surface leaps out of the water (feet reached %.1f, surface %.1f)" % [highest_feet, surface_y])

	# Left alone under water, you sink slowly down to the floor. (Started still, mid-
	# water: falling in from a leap is a plunge, braked from full speed.)
	for frame: int in 90:
		await get_tree().physics_frame
	player.global_position = Vector2(bottom.x, bottom.y - 12.0)
	player.velocity = Vector2.ZERO
	var fastest_sink: float = 0.0
	for frame: int in 120:
		await get_tree().physics_frame
		if player.swim.is_swimming():
			fastest_sink = maxf(fastest_sink, player.velocity.y)
	_check(player.is_on_floor() and absf(player.global_position.y - bottom.y) < 1.0,
		"without strokes the player sinks back to the floor (y %.1f)" % player.global_position.y)
	_check(fastest_sink <= tuning.swim_max_sink + 1.0,
		"under water the player sinks at most %.0f px/s (saw %.0f)" % [tuning.swim_max_sink, fastest_sink])

	# Swimming up under the floating crate and away doesn't carry it off: the crate
	# never rides on the player (play-test 1, "I can grab the crate").
	room.reset_objects()
	await _wait_until_calm(water)
	var crate: Crate = room.get_node("Crate1") as Crate
	var crate_x: float = crate.global_position.x
	await _stand_at(player, Vector2(crate_x, 144))
	for tap: int in 5:
		await _press(&"jump")
		for frame: int in 8:
			await get_tree().physics_frame
	Input.action_press(&"move_right")
	for frame: int in 30:
		if frame % 8 == 0:
			Input.action_press(&"jump")
		elif frame % 8 == 2:
			Input.action_release(&"jump")
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	_check(player.global_position.x - crate_x > 15.0 and absf(crate.global_position.x - crate_x) < 3.0,
		"swimming away from under the floating crate leaves it behind (crate moved %.1f px, player %.1f px)" 		% [crate.global_position.x - crate_x, player.global_position.x - crate_x])

	# The look toggle: 7 cycles B, C, A, B+C and back, and the shader gets it.
	var look_before: int = tuning.look_style
	var looks_seen: Array[int] = []
	for press: int in WaterWorld.LOOK_NAMES.size():
		await _press(&"debug_water_look")
		looks_seen.append(tuning.look_style)
	var water_material: ShaderMaterial = water.material as ShaderMaterial
	_check(water_material != null and water_material.shader != null, "the water draws through the water shader")
	var all_looks_seen: bool = looks_seen.back() == look_before
	for look: int in WaterWorld.LOOK_NAMES.size():
		all_looks_seen = all_looks_seen and looks_seen.has(look)
	_check(all_looks_seen, "7 cycles every look and back (%s)" % [looks_seen])
	await _press(&"debug_water_look")
	_check(int(water_material.get_shader_parameter(&"look_style")) == tuning.look_style,
		"the shader draws the chosen look (%s)" % water.get_look_name())
	tuning.look_style = look_before
	room.reset_objects()
	finished_sections.append("Swim")


## Puts the player at `feet` (standing), still, and lets a few frames pass.
func _stand_at(player: Player, feet: Vector2) -> void:
	player.global_position = feet
	player.velocity = Vector2.ZERO
	for frame: int in 20:
		await get_tree().physics_frame


## Stands the player at `feet`, holds jump for half a second, and returns how high
## the feet rose, px.
func _measure_held_jump(player: Player, feet: Vector2) -> float:
	await _stand_at(player, feet)
	var start_y: float = player.global_position.y
	var highest: float = start_y
	Input.action_press(&"jump")
	for frame: int in 40:
		await get_tree().physics_frame
		highest = minf(highest, player.global_position.y)
	Input.action_release(&"jump")
	for frame: int in 60:
		await get_tree().physics_frame
	return start_y - highest


# --- Helpers ----------------------------------------------------------------------

## Waits physics frames until every body sleeps and no drop is falling, or the
## timeout. True if it settled.
func _wait_until_calm(water: WaterWorld) -> bool:
	var deadline: int = Time.get_ticks_msec() + roundi(SETTLE_TIMEOUT * 1000.0)
	# At least a few frames, so a body that was just woken gets stepped.
	for frame: int in 3:
		await get_tree().physics_frame
	while Time.get_ticks_msec() < deadline:
		if water.get_awake_count() == 0 and water.get_drop_count() == 0:
			return true
		await get_tree().physics_frame
	return false


## The biggest difference between two wet columns' surfaces, px (only columns
## between room-local x `from_x` and `to_x`, when given). Thin films (a wave
## that slopped over the rim leaves one) don't count: surface tension holds them.
func _surface_spread(body: WaterBody, from_x: float = -INF, to_x: float = INF) -> float:
	var highest: float = INF
	var lowest: float = -INF
	var film_depth: float = body.column_width  # anything deeper than a film
	for column: int in body.get_column_count():
		var x: float = body.get_column_left(column)
		if body.depth[column] > film_depth and x >= from_x and x < to_x:
			highest = minf(highest, body.get_surface_y(column))
			lowest = maxf(lowest, body.get_surface_y(column))
	return lowest - highest


## Units of water in columns between room-local x `from_x` and `to_x` whose floor is
## at `floor_y`.
func _units_in(water: WaterWorld, from_x: float, to_x: float, floor_y: float) -> float:
	var area: float = 0.0
	for body: WaterBody in water.bodies:
		for column: int in body.get_column_count():
			var x: float = body.get_column_left(column)
			if x >= from_x and x < to_x and absf(body.floor_y[column] - floor_y) < 0.5:
				area += body.depth[column] * body.column_width
	return area / WaterWorld.UNIT_AREA


## How many bodies have wet columns there (see _units_in).
func _bodies_on_floor(water: WaterWorld, from_x: float, to_x: float, floor_y: float) -> int:
	var count: int = 0
	for body: WaterBody in water.bodies:
		for column: int in body.get_column_count():
			var x: float = body.get_column_left(column)
			if x >= from_x and x < to_x and absf(body.floor_y[column] - floor_y) < 0.5 and body.depth[column] > 0.5:
				count += 1
				break
	return count


func _press(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _action_has_key(action: StringName, key: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and (key_event.physical_keycode == key or key_event.keycode == key):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("[WaterSmokeTest] PASS %s" % description)
	else:
		failures += 1
		print("[WaterSmokeTest] FAIL %s" % description)

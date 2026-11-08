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
## Each budget check repeats its stress this many times and judges the MEDIAN of the
## rounds' averages: one round slowed by the machine (a laptop CPU dropping out of
## turbo doubles every number at once) can't fail it alone, but a real slowdown
## shows in every round, so it still fails (§6.5 perf pass, 28 Oct 2026).
const BUDGET_ROUNDS: int = 5
## Physics frames timed per round (2 s).
const BUDGET_FRAMES: int = 120
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
	# `-- W3` (any of W1 Swim W2 W3 W4 Ice Lines W7a W7b W8a W8b W8c W8play) runs only those sections: quicker while working on one.
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var sections: Array[String] = ["W1", "Swim", "W2", "W3", "W4", "Ice", "Lines", "W7a", "W7b", "W8a", "W8b", "W8c", "W8play"]
	if not wanted.is_empty():
		sections.assign(Array(wanted))
	if sections.has("W1"):
		await _check_w1_bodies(world, world.player)
	if sections.has("Swim"):
		await _check_swimming(world, world.player)
	if sections.has("W2"):
		await _check_w2_loose_water(world, world.player)
	if sections.has("W3"):
		await _check_w3_water_hands(world, world.player)
	if sections.has("W4"):
		await _check_w4_water_snake(world, world.player)
	# Grid ice (Stages I1-I5, Water_bending.md §16 "Re-planned: grid ice") replaced
	# the W5/W6 ice, the predictable ice and the snow puff sections.
	if sections.has("Ice"):
		await _check_grid_ice(world, world.player)
	if sections.has("Lines"):
		await _check_snake_lines(world, world.player)
	if sections.has("W7a"):
		await _check_w7a_black_water(world, world.player)
	if sections.has("W7b"):
		await _check_w7b_currents(world, world.player)
	if sections.has("W8a"):
		await _check_w8a_wet_tiles(world, world.player)
	if sections.has("W8b"):
		await _check_w8b_icy_coat(world, world.player)
	if sections.has("W8c"):
		await _check_w8c_crumbling(world, world.player)
	if sections.has("W8play"):
		await _check_w8_playtest_fixes(world, world.player)

	for section_name: String in sections:
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
	# Half a pixel over 170 px is level to the eye (a calm body may sleep with a tilt
	# that small: each pair of columns is within LEVEL_TOLERANCE).
	_check(_surface_spread(pool) < 0.5, "the pool is level once calm (spread %.2f px)" % _surface_spread(pool))

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
	var make_slosh: Callable = func() -> void:
		water.wake_all()
		for poke_x: float in [60.0, 120.0, 180.0, 400.0, 460.0]:
			water.poke(Vector2(poke_x, 110), 8.0)
		for blob_index: int in 12:
			water.add_loose_water(Vector2(48 + blob_index * 36, 30), 2.5)
	var cap: int = player.water_tuning.max_drops
	var slosh: Dictionary = await _measure_water_step(room, water, make_slosh, true)
	_check(int(slosh["most_drops"]) <= cap + 12, "the drop cap holds (%d drops, cap %d)" % [slosh["most_drops"], cap])
	_print_budget("water step under stress", slosh, water)
	_check_budget(float(slosh["median_usec"]),
		"the water step stays under the 2 ms budget: %.0f us (median of %d rounds)" % [slosh["median_usec"], BUDGET_ROUNDS])

	# The same stress with every pool resting on grass (§6.5 perf pass): absorbent
	# ground under awake water is soaked from every frame, the case a room mixing
	# Fire's meadows and Water's pools makes. Grass is painted under each pool for
	# this check only, then taken away again.
	var grass: TileMapLayer = room.get_node("Grass") as TileMapLayer
	var tiles: TileMapLayer = room.get_node("Tiles") as TileMapLayer
	var painted_grass: Array[Vector2i] = []
	for water_cell: Vector2i in layer.get_used_cells():
		var below: Vector2i = water_cell + Vector2i.DOWN
		if layer.get_cell_source_id(below) == -1 and tiles.get_cell_source_id(below) != -1 \
				and grass.get_cell_source_id(below) == -1:
			grass.set_cell(below, 0, Vector2i(0, 0))
			painted_grass.append(below)
	water.refresh_solid_cells()  # re-reads which tiles are absorbent
	var on_grass: Dictionary = await _measure_water_step(room, water, make_slosh, true)
	_check(painted_grass.size() >= 20 and water.get_soaked_units() > 0.0,
		"the pools rest on grass and soak into it (%d grass tiles, %.2f units soaked)" % [painted_grass.size(), water.get_soaked_units()])
	_print_budget("water step on grass", on_grass, water)
	_check_budget(float(on_grass["median_usec"]),
		"pools on grass stay under the 2 ms budget: %.0f us (median of %d rounds)" % [on_grass["median_usec"], BUDGET_ROUNDS])
	for cell: Vector2i in painted_grass:
		grass.erase_cell(cell)
	water.refresh_solid_cells()
	room.reset_objects()

	finished_sections.append("W1")


## Swimming (Water_bending.md §5.4), moved up from W7 after play-test 1: the water
## slows you by how much of you is in it, jumps off the bottom are lower, jump
## strokes you up when your head is under, and leaps you out at the surface.
func _check_swimming(world: RoomManager, player: Player) -> void:
	var room: Room = world.current_room
	var water: WaterWorld = room.get_node(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	var tuning: WaterTuning = player.water_tuning
	# Breaking waves are off while swimming is measured: the stroking churns the
	# pool, and random crests made the heights depend on the random sequence.
	var break_throw: float = tuning.wave_break_throw
	tuning.wave_break_throw = 0.0
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
	# A jump's height goes with its launch speed squared, so the 12 px a full leap
	# clears shrinks with surface_leap_scale² (0.5 in play-test 2: a quarter).
	var leap_clearance: float = 12.0 * tuning.surface_leap_scale * tuning.surface_leap_scale
	_check(highest_feet < surface_y - leap_clearance,
		"a held jump at the surface leaps out of the water (feet reached %.1f, surface %.1f, needs %.1f px clear)"
			% [highest_feet, surface_y, leap_clearance])

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
		"swimming away from under the floating crate leaves it behind (crate moved %.1f px, player %.1f px)" \
		% [crate.global_position.x - crate_x, player.global_position.x - crate_x])

	# Standing on the FLOATING crate, a gust to the right throws you both LEFT (it takes
	# the recoil, like a raft; after the grid-ice play-test it carried you right).
	room.reset_objects()
	await _wait_until_calm(water)
	crate_x = crate.global_position.x
	player.state_machine.transition_to(&"Fall")
	player.global_position = Vector2(crate_x, crate.global_position.y - crate.crate_size.y - 0.5)
	player.velocity = Vector2.ZERO
	for frame: int in 30:
		await get_tree().physics_frame
	_check(player.get_floor_body() == crate, "you stand on the floating crate")
	player.gust.cooldown_remaining = 0.0
	var player_x: float = player.global_position.x
	Input.action_press(&"move_right")
	await _press(&"gust")
	Input.action_release(&"move_right")
	for frame: int in 30:
		await get_tree().physics_frame
	_check(crate.global_position.x < crate_x - 8.0 and player.global_position.x < player_x - 8.0,
		"gusting right on it moves the crate and you left (crate %.1f px, you %.1f px)"
			% [crate.global_position.x - crate_x, player.global_position.x - player_x])

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
	tuning.wave_break_throw = break_throw
	finished_sections.append("Swim")


## Stage W7b, in room Water I: currents (FLOW moves water, LOOP doesn't), riders
## (a swimmer drifts, a diver goes back, a crate rides the stream, a raft carries its
## rider), the waterfall's push, floating leaves, the leaf platform on its rail, the
## streak look's speeds, and the budget with all of it running.
func _check_w7b_currents(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterI") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water I is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "Water I has a WaterWorld")
	if water == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var origin: Vector2 = room.global_position
	_check(PaletteCatalog.get_entry(&"current_zone") != null, "the palette has the current zone")
	_check(water.current_zones.size() == 3, "the WaterWorld found the room's 3 current zones (%d)" % water.current_zones.size())
	await _stand_at(player, origin + Vector2(12.0, 128.0))
	var waterfall: WaterSource = room.get_node("Waterfall") as WaterSource
	var pool_current: CurrentZone = room.get_node("PoolCurrent") as CurrentZone

	# FLOW: the stream's water runs right at a good share of the zone's 50 px/s, and
	# a body under a flow zone stays awake.
	for frame: int in 180:
		await get_tree().physics_frame
	var stream_speed: float = water.get_water_velocity_at(Vector2(100.0, 152.0))
	print("[WaterSmokeTest] W7b: stream water speed %.1f px/s" % stream_speed)
	_check(stream_speed > 25.0 and stream_speed < 80.0, "the flow current runs the stream right (%.1f px/s)" % stream_speed)
	var stream_body: WaterBody = water.find_water_at(Vector2(100.0, 152.0))[0]
	_check(stream_body.is_in_current and not stream_body.is_asleep, "a body under a flow current never sleeps")

	# The crate floating at the stream's start rides it over the spikes (from a reset:
	# it gets there within the first seconds).
	var crate: Crate = room.get_node("StreamCrate") as Crate
	room.reset_objects()
	await get_tree().physics_frame
	var crate_start_x: float = crate.global_position.x
	for frame: int in 180:
		await get_tree().physics_frame
	var crate_moved: float = crate.global_position.x - crate_start_x
	print("[WaterSmokeTest] W7b: crate drifted %.1f px in 3 s (speed %.1f, water %.1f)" % [crate_moved, crate.velocity.x, crate.water_speed_x])
	_check(crate_moved > 80.0 and crate.submerged_share > 0.0, "a floating crate rides the stream past the spikes (%.1f px in 3 s)" % crate_moved)

	# A swimmer in the stream drifts right at about current_push of the water's speed.
	room.reset_objects()
	for frame: int in 120:
		await get_tree().physics_frame
	player.global_position = origin + Vector2(40.0, 158.0)
	player.velocity = Vector2.ZERO
	var swim_start_x: float = player.global_position.x
	for frame: int in 45:
		await get_tree().physics_frame
	var swim_moved: float = player.global_position.x - swim_start_x
	print("[WaterSmokeTest] W7b: swimmer drifted %.1f px in 0.75 s (carry %.1f px/s)" % [swim_moved, player.swim.current_speed_x])
	_check(swim_moved > 8.0 and not player.is_dead(), "a swimmer in the stream drifts with it (%.1f px)" % swim_moved)
	await _stand_at(player, origin + Vector2(12.0, 128.0))

	# LOOP: no tilt, the surface runs right and the bottom left. The waterfall is off
	# for this, so its waves don't hide the level.
	var pool_drain: WaterSink = room.get_node("PoolDrain") as WaterSink
	waterfall.rate = 0.0
	pool_drain.max_rate = 0.0
	room.reset_objects()
	for frame: int in 240:
		await get_tree().physics_frame
	var pool_body: WaterBody = water.find_water_at(Vector2(460.0, 140.0))[0]
	var level_spread: float = _surface_spread(pool_body)
	var top_speed: float = water.get_water_velocity_at(Vector2(460.0, 115.0))
	var bottom_speed: float = water.get_water_velocity_at(Vector2(460.0, 159.0))
	print("[WaterSmokeTest] W7b: loop pool: surface %.1f px/s, bottom %.1f px/s, level spread %.2f px" % [top_speed, bottom_speed, level_spread])
	_check(top_speed > 25.0 and bottom_speed < -25.0, "a loop current runs the surface right and the bottom left (%.1f / %.1f px/s)" % [top_speed, bottom_speed])
	_check(level_spread < 0.5, "a loop current moves no water: the pool stays level (%.2f px)" % level_spread)

	# A diver near the loop's bottom is carried back left; near the top, right.
	player.global_position = origin + Vector2(470.0, 160.0)
	player.velocity = Vector2.ZERO
	var dive_start_x: float = player.global_position.x
	for frame: int in 60:
		await get_tree().physics_frame
	var dive_moved: float = player.global_position.x - dive_start_x
	player.global_position = origin + Vector2(440.0, 126.0)
	player.velocity = Vector2.ZERO
	var top_start_x: float = player.global_position.x
	for frame: int in 20:
		await get_tree().physics_frame
	var top_moved: float = player.global_position.x - top_start_x
	print("[WaterSmokeTest] W7b: loop: diver %.1f px in 1 s, swimmer at the top %.1f px in 0.33 s" % [dive_moved, top_moved])
	_check(dive_moved < -5.0, "the loop carries a diver at the bottom back left (%.1f px)" % dive_moved)
	_check(top_moved > 2.0, "the loop carries a swimmer at the top right (%.1f px)" % top_moved)

	# FLOW in a closed pool tilts it (real flow), and the water is all still there.
	var books: float = water.get_books_units()
	pool_current.mode = CurrentZone.Mode.FLOW
	for frame: int in 240:
		await get_tree().physics_frame
	var left_surface: float = pool_body.get_surface_y(pool_body.get_column_at(424.0))
	var right_surface: float = pool_body.get_surface_y(pool_body.get_column_at(496.0))
	print("[WaterSmokeTest] W7b: flow in the closed pool: surface %.2f (left) vs %.2f (right)" % [left_surface, right_surface])
	_check(left_surface - right_surface > 1.0, "a flow current tilts a closed pool: it piles up downstream (%.2f px)" % (left_surface - right_surface))
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "the books still balance with a current running")
	pool_current.mode = CurrentZone.Mode.LOOP

	# Swimming in water with no current doesn't carry you faster than you swim (the
	# player's own wake isn't ridden).
	pool_current.strength = 0.0
	room.reset_objects()
	for frame: int in 60:
		await get_tree().physics_frame
	player.global_position = origin + Vector2(424.0, 150.0)
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_right")
	var fastest_swim: float = 0.0
	for frame: int in 50:
		await get_tree().physics_frame
		fastest_swim = maxf(fastest_swim, player.velocity.x)
	Input.action_release(&"move_right")
	var swim_cap: float = player.tuning.max_run_speed * (1.0 - tuning.water_resistance)
	print("[WaterSmokeTest] W7b: swimming in still water: top %.1f px/s (no-current cap %.1f)" % [fastest_swim, swim_cap])
	_check(fastest_swim < swim_cap * 1.15, "swimming in still water isn't sped up by your own wake (%.1f px/s)" % fastest_swim)
	pool_current.strength = 40.0

	# The waterfall pushes a swimmer under it down.
	waterfall.rate = 2.0
	pool_drain.max_rate = 2.0
	room.reset_objects()
	for frame: int in 150:
		await get_tree().physics_frame
	player.global_position = origin + Vector2(490.0, 140.0)
	player.velocity = Vector2.ZERO
	var most_push: float = 0.0
	for frame: int in 30:
		await get_tree().physics_frame
		most_push = maxf(most_push, player.swim.fall_push)
	player.global_position = origin + Vector2(440.0, 140.0)
	player.velocity = Vector2.ZERO
	for frame: int in 40:
		await get_tree().physics_frame
	print("[WaterSmokeTest] W7b: waterfall push under it %.1f px/s, away from it %.1f px/s" % [most_push, player.swim.fall_push])
	_check(most_push > 10.0, "a waterfall pushes a swimmer under it down (%.1f px/s)" % most_push)
	_check(player.swim.fall_push < 1.0, "no push away from the waterfall (%.1f px/s)" % player.swim.fall_push)
	await _stand_at(player, origin + Vector2(12.0, 128.0))

	# Floating leaves: blown off the ledge, they float on the pool and drift right on
	# the loop's surface; a floating leaf can't be lit.
	var pile: LeafPile = room.get_node("LedgeLeaves") as LeafPile
	for leaf_index: int in pile.leaf_positions.size():
		pile._launch_leaf(leaf_index, Vector2(randf_range(90.0, 180.0), -randf_range(40.0, 70.0)))
	for frame: int in 180:
		await get_tree().physics_frame
	var floating: Array[int] = []
	for leaf_index: int in pile.leaf_positions.size():
		if pile.leaf_is_flying[leaf_index] == LeafPile.FLOATING:
			floating.append(leaf_index)
	_check(floating.size() >= 5, "leaves blown onto the pool float (%d of %d)" % [floating.size(), pile.leaf_positions.size()])
	if not floating.is_empty():
		var leaf: int = floating[0]
		var leaf_world: Vector2 = pile.to_global(pile.leaf_positions[leaf])
		var surface_here: float = water.get_surface_y_at(water.to_local(leaf_world))
		_check(absf(water.to_local(leaf_world).y - surface_here) < 3.0,
			"a floating leaf lies on the surface (y %.1f, surface %.1f)" % [water.to_local(leaf_world).y, surface_here])
		var mean_before: float = 0.0
		for index: int in floating:
			mean_before += pile.leaf_positions[index].x
		mean_before /= floating.size()
		for frame: int in 30:
			await get_tree().physics_frame
		var mean_after: float = 0.0
		for index: int in floating:
			mean_after += pile.leaf_positions[index].x
		mean_after /= floating.size()
		print("[WaterSmokeTest] W7b: %d floating leaves drifted %.1f px in 0.5 s" % [floating.size(), mean_after - mean_before])
		_check(mean_after - mean_before > 2.0, "floating leaves drift with the surface current (%.1f px)" % (mean_after - mean_before))
		pile._get_fire().light_leaf(leaf)
		_check(not pile.fire.is_leaf_burning(leaf), "a floating leaf can't be lit")

	# The leaf platform on its rail floats at the surface.
	var leaf_platform: LeafPlatform = room.get_node("FloatingLeaf") as LeafPlatform
	var platform_top: float = water.to_local(leaf_platform.global_position).y
	var pool_surface: float = water.get_surface_y_at(Vector2(440.0, 140.0))
	print("[WaterSmokeTest] W7b: leaf platform top %.1f, surface %.1f, floating %s" % [platform_top, pool_surface, leaf_platform.is_floating])
	_check(leaf_platform.is_floating and absf(platform_top - (pool_surface - tuning.leaf_platform_float_lift)) < 2.5,
		"the leaf platform floats on its rail at the surface (top %.1f, surface %.1f)" % [platform_top, pool_surface])

	# Surfing: a raft on the black channel's loop current carries whoever stands on it.
	room.reset_objects()
	for frame: int in 30:
		await get_tree().physics_frame
	var raft: IceRaft = _make_test_raft(water, 260.0, 136.0, 4.0)
	for frame: int in 20:
		await get_tree().physics_frame
	var raft_box: Rect2 = raft.get_water_box()
	player.global_position = Vector2(raft_box.get_center().x, raft_box.position.y)
	player.velocity = Vector2.ZERO
	var raft_start_x: float = raft.global_position.x
	var rider_start_x: float = player.global_position.x
	for frame: int in 180:
		await get_tree().physics_frame
	var raft_moved: float = raft.global_position.x - raft_start_x
	var rider_moved: float = player.global_position.x - rider_start_x
	print("[WaterSmokeTest] W7b: surfing: raft %.1f px, rider %.1f px in 3 s, dead %s" % [raft_moved, rider_moved, player.is_dead()])
	_check(raft_moved > 20.0, "a raft drifts with the black channel's current (%.1f px in 3 s)" % raft_moved)
	_check(rider_moved > 20.0 and not player.is_dead(), "the raft carries its rider: surfing (%.1f px in 3 s)" % rider_moved)
	await _wait_for_respawn(player)
	room.reset_objects()
	await _stand_at(player, origin + Vector2(12.0, 128.0))

	# The look: the water's corners carry their speed to the shader (the streaks).
	_check(water.draw_uvs.size() > 0, "the water's corners carry their speed for the streaks (%d)" % water.draw_uvs.size())

	# The budget, with the stream, the loops, the waterfall and the leaves running.
	var result: Dictionary = await _measure_water_step(room, water, func() -> void: pass, false)
	_print_budget("W7b budget (currents, waterfall)", result, water)
	_check_budget(result["median_usec"], "Water I with currents stays under the 2 ms budget (median %.0f us)" % result["median_usec"])
	finished_sections.append("W7b")


## Stage W8a: wet tiles and mud (Water_bending.md §16 "Planned in Stage W8"), in
## room Water J.
func _check_w8a_wet_tiles(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterJ") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water J is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	var fire_grid: FireGrid = room.get_node_or_null("FireGrid") as FireGrid
	_check(water != null and fire_grid != null, "Water J has a WaterWorld and a FireGrid")
	if water == null or fire_grid == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var surface: SurfaceGrid = water.surface_grid
	var origin: Vector2 = room.global_position
	_check(surface != null and SurfaceGrid.find_at(get_tree(), origin + Vector2(40.0, 40.0)) == surface,
		"the WaterWorld made the room's SurfaceGrid")
	await _stand_at(player, origin + Vector2(20.0, 128.0))

	# What each tile is made of.
	_check(surface.get_ground(Vector2i(12, 16)) == SurfaceGrid.Ground.ROCK, "the grey floor is ROCK")
	_check(surface.get_ground(Vector2i(23, 8)) == SurfaceGrid.Ground.EARTH, "the shaft wall is EARTH")
	_check(surface.get_ground(Vector2i(30, 16)) == SurfaceGrid.Ground.GRASS, "the strip is GRASS")
	_check(surface.get_ground(Vector2i(45, 16)) == SurfaceGrid.Ground.NONE, "painted ice never gets wet")

	# Grey rock (since the second W8c play-test): never wet, and it soaks nothing (the
	# water puddles).
	_check(not surface.is_wet(Vector2i(5, 19)), "the rock under the start pool isn't wet")
	var soaked_before: float = water.get_soaked_units()
	water.throw_ball(Vector2(100.0, 110.0), Vector2(0.0, 40.0), 1.0)
	for frame: int in 60:
		await get_tree().physics_frame
	_check(not surface.is_wet(Vector2i(12, 16)) and not surface.wet(Vector2i(12, 16)),
		"a ball thrown on grey floor doesn't wet it, and wet() refuses rock")
	_check(absf(water.get_soaked_units() - soaked_before) < 0.001,
		"grey rock soaks nothing (%.3f units)" % (water.get_soaked_units() - soaked_before))

	# Earth: soaked full, it's MUD. A ball thrown at the shaft's right wall.
	water.throw_ball(Vector2(168.0, 60.0), Vector2(160.0, -20.0), 2.0)
	for frame: int in 60:
		await get_tree().physics_frame
	var mud_rows: int = 0
	for row: int in range(3, 13):
		if surface.is_mud(Vector2i(23, row)):
			mud_rows += 1
	_check(mud_rows > 0, "a ball thrown at an earth wall turns the tiles it hits to mud (%d rows)" % mud_rows)

	# Cling: a mud wall stops your fall while you hold toward it; a dry one doesn't.
	for row: int in range(3, 16):
		surface.wet(Vector2i(23, row))
	var wall_feet: Vector2 = origin + Vector2(23.0 * 8.0 - 4.0, 90.0)
	player.global_position = wall_feet
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_right")
	for frame: int in 40:
		await get_tree().physics_frame
	var cling_y: float = player.global_position.y
	for frame: int in 30:
		await get_tree().physics_frame
	var cling_drop: float = player.global_position.y - cling_y
	print("[WaterSmokeTest] W8a: on the mud wall: state %s, fell %.2f px in 0.5 s" % [player.state_machine.current_state.name, cling_drop])
	_check(player.state_machine.current_state.name == &"WallSlide" and cling_drop < 0.5,
		"holding toward a mud wall you cling: no sliding (%.2f px)" % cling_drop)
	_check(surface.hand_prints.size() > 0, "clinging leaves a hand print")
	Input.action_press(&"jump")
	for frame: int in 3:
		await get_tree().physics_frame
	Input.action_release(&"jump")
	_check(player.velocity.x < 0.0 and player.velocity.y < 0.0, "you can wall-jump off mud")
	Input.action_release(&"move_right")
	# The same wall dry: you slide down it.
	surface.reset()
	player.global_position = wall_feet
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_right")
	for frame: int in 40:
		await get_tree().physics_frame
	var dry_y: float = player.global_position.y
	for frame: int in 15:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	_check(player.global_position.y - dry_y > 3.0, "a dry earth wall still slides (%.1f px)" % (player.global_position.y - dry_y))

	# Mud floor: slower runs, lower jumps.
	for column: int in range(54, 62):
		surface.wet(Vector2i(column, 17))
	await _stand_at(player, origin + Vector2(55.0 * 8.0, 136.0))
	_check(player.mud.is_on_mud, "standing on the wet earth floor is standing on mud")
	Input.action_press(&"move_right")
	for frame: int in 30:
		await get_tree().physics_frame
	var mud_speed: float = player.velocity.x
	Input.action_release(&"move_right")
	var mud_top: float = player.tuning.max_run_speed * tuning.mud_run_multiplier
	_check(mud_speed > mud_top * 0.8 and mud_speed <= mud_top + 0.5,
		"mud slows your run to %.0f px/s (%.1f)" % [mud_top, mud_speed])
	var mud_jump: float = await _measure_held_jump(player, origin + Vector2(55.0 * 8.0, 136.0))
	var dry_jump: float = await _measure_held_jump(player, origin + Vector2(12.0 * 8.0, 128.0))
	print("[WaterSmokeTest] W8a: jump on mud %.1f px, on rock %.1f px" % [mud_jump, dry_jump])
	_check(mud_jump < dry_jump * 0.8, "jumps off mud are lower (%.1f vs %.1f px)" % [mud_jump, dry_jump])

	# Landing on mud kills your sideways speed (the brake after an ice runway).
	player.global_position = origin + Vector2(54.0 * 8.0 + 4.0, 112.0)
	player.velocity = Vector2(220.0, 0.0)
	player.carries_ice_speed = true
	for frame: int in 30:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	await get_tree().physics_frame
	_check(player.is_on_floor() and absf(player.velocity.x) < 1.0 and not player.is_dead(),
		"landing on mud at 220 px/s stops you dead (%.1f px/s)" % player.velocity.x)

	# Heat dries mud (a steam puff) and lets it soak again.
	Flammable.ignite_near(get_tree(), origin + Vector2(56.0 * 8.0 + 4.0, 136.0), 2.0, null)
	_check(not surface.is_wet(Vector2i(56, 17)), "a direct flame dries mud back to earth")
	_check(surface.is_wet(Vector2i(60, 17)), "only the tile the flame touched dries")

	# Wet grass won't burn: the first flame dries it, the second lights it. Fire
	# spreading never crosses a wet tile.
	# A ball at the strip's right end soaks in there (wicking 2 tiles each way: the
	# grass tiles 34-36), which is the firebreak; tile 30 is wetted by hand.
	await _stand_at(player, origin + Vector2(20.0, 128.0))
	water.throw_ball(Vector2(292.0, 100.0), Vector2(0.0, 40.0), 1.0)
	for frame: int in 60:
		await get_tree().physics_frame
	_check(surface.is_wet(Vector2i(36, 16)) and surface.is_wet(Vector2i(34, 16)) and not surface.is_mud(Vector2i(36, 16)),
		"water soaks into grass and wets it")
	surface.wet(Vector2i(30, 16))
	var grass_top: Vector2 = origin + Vector2(30.0 * 8.0 + 4.0, 128.0)
	Flammable.ignite_near(get_tree(), grass_top, 2.0, null)
	_check(fire_grid.get_state(Vector2i(30, 16)) == FireGrid.State.GRASS and not surface.is_wet(Vector2i(30, 16)),
		"the first flame on wet grass dries it (no fire)")
	Flammable.ignite_near(get_tree(), grass_top, 2.0, null)
	_check(fire_grid.get_state(Vector2i(30, 16)) == FireGrid.State.BURNING, "the second flame lights it")
	var fire_tuning: FireTuning = player.fire_tuning
	var wait_frames: int = int((fire_tuning.spread_delay * 8.0 + fire_tuning.burn_time + fire_tuning.smolder_time) * 60.0)
	for frame: int in wait_frames:
		await get_tree().physics_frame
	_check(fire_grid.get_state(Vector2i(33, 16)) != FireGrid.State.GRASS, "the fire spread along the dry grass")
	_check(fire_grid.get_state(Vector2i(34, 16)) == FireGrid.State.GRASS and fire_grid.get_state(Vector2i(36, 16)) == FireGrid.State.GRASS,
		"a wet tile is a firebreak: the fire stopped there")

	# Ash wets into mud too.
	_check(fire_grid.get_state(Vector2i(31, 16)) == FireGrid.State.ASH, "burnt grass is ash")
	surface.wet(Vector2i(31, 16))
	_check(surface.get_ground(Vector2i(31, 16)) == SurfaceGrid.Ground.ASH and surface.is_mud(Vector2i(31, 16)), "wet ash is mud")

	# Reset: everything is dry.
	room.reset_objects()
	await get_tree().physics_frame
	_check(not surface.is_wet(Vector2i(12, 16)) and not surface.is_wet(Vector2i(31, 16)), "R dries every wet tile")
	_check(surface.hand_prints.is_empty(), "R wipes the hand prints")
	finished_sections.append("W8a")


## Stage W8b: freezing wet ground, the frost cursor and the icy coat
## (Water_bending.md §16 "Planned in Stage W8"), in room Water J.
func _check_w8b_icy_coat(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterJ") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	var fire_grid: FireGrid = room.get_node_or_null("FireGrid") as FireGrid
	_check(water != null and fire_grid != null, "W8b: Water J has a WaterWorld and a FireGrid")
	if water == null or fire_grid == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var hands: WaterHandsAbility = player.water_hands
	var surface: SurfaceGrid = water.surface_grid
	var origin: Vector2 = room.global_position
	room.reset_objects()
	await _stand_at(player, origin + Vector2(76.0 * 8.0, 128.0))
	await _wait_until_calm(water)
	surface.reset()

	# The wet runway (cols 73-83), and one wet tile past the gap that isn't joined to it.
	var runway: Array[Vector2i] = []
	for column: int in range(73, 84):
		runway.append(Vector2i(column, 16))
		surface.wet(Vector2i(column, 16))
	surface.wet(Vector2i(95, 16))
	var books: float = water.get_books_units()
	var ice_cells_before: int = water.ice_layer.cell_freeze.size()
	var freezes_before: int = water.freeze_order.size()

	# Hold 1 with no water near: the empty ball is a frost cursor.
	await _start_hold(player)
	_check(hands.is_holding() and hands.is_frost_cursor(), "holding 1 with no water near shows the frost cursor")
	# Steer it onto the wet floor (put there: steering is the W3 test's).
	hands.ball_position = origin + Vector2(78.0 * 8.0 + 4.0, 126.0)
	hands.ball_velocity = Vector2.ZERO
	for frame: int in 3:
		await get_tree().physics_frame
	var ghost: Dictionary = {}
	for cell: Vector2i in hands.coat_patch:
		ghost[cell] = true
	var matches: bool = ghost.size() == runway.size()
	for cell: Vector2i in runway:
		matches = matches and ghost.has(cell)
	_check(matches, "the ghost covers exactly the connected wet patch (%d tiles, want %d)" % [ghost.size(), runway.size()])

	# The cap: of a bigger patch, the tiles nearest the cursor.
	var cap_before: int = tuning.wet_freeze_max_tiles
	tuning.wet_freeze_max_tiles = 4
	for frame: int in 3:
		await get_tree().physics_frame
	var near_cursor: bool = hands.coat_patch.size() == 4
	for cell: Vector2i in hands.coat_patch:
		near_cursor = near_cursor and absi(cell.x - 78) <= 2
	_check(near_cursor, "wet_freeze_max_tiles caps a patch to the tiles nearest the cursor (%s)" % [hands.coat_patch])
	tuning.wet_freeze_max_tiles = cap_before
	for frame: int in 3:
		await get_tree().physics_frame

	# 2: the patch is coated, the hold ends, no water is used, no ice cap is spent.
	var coats_before: int = player.freeze.coat_count
	player.freeze.cooldown_remaining = 0.0
	await _press(&"water_freeze")
	Input.action_release(&"water_hands")
	for frame: int in 3:
		await get_tree().physics_frame
	var all_coated: bool = true
	for cell: Vector2i in runway:
		all_coated = all_coated and surface.is_coated(cell)
	_check(all_coated and surface.get_coated_count() == runway.size() and player.freeze.coat_count == coats_before + 1,
		"2 coats the whole patch (%d coated)" % surface.get_coated_count())
	_check(not surface.is_coated(Vector2i(95, 16)), "a wet tile not joined to the patch isn't coated")
	_check(not hands.is_holding() and player.state_machine.current_state.name != &"WaterHolding", "coating ends the hold")
	_check(water.ice_layer.cell_freeze.size() == ice_cells_before and water.freeze_order.size() == freezes_before,
		"a coat isn't player ice: no ice cap used")
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "a coat uses no water: the books are unchanged")

	# Coated ground is ice: slippery, and it keeps speed above run speed (I5).
	await _stand_at(player, origin + Vector2(74.0 * 8.0, 128.0))
	_check(player.is_on_ice and player.mud.is_on_coat, "standing on the coat is standing on ice")
	player.velocity = Vector2(200.0, 0.0)
	Input.action_press(&"move_right")
	for frame: int in 15:
		await get_tree().physics_frame
	var coat_speed: float = player.velocity.x
	Input.action_release(&"move_right")
	await _stand_at(player, origin + Vector2(12.0 * 8.0, 128.0))
	player.velocity = Vector2(200.0, 0.0)
	Input.action_press(&"move_right")
	for frame: int in 15:
		await get_tree().physics_frame
	var rock_speed: float = player.velocity.x
	Input.action_release(&"move_right")
	print("[WaterSmokeTest] W8b: 0.25 s after 200 px/s: on the coat %.1f px/s, on rock %.1f px/s" % [coat_speed, rock_speed])
	_check(coat_speed > player.tuning.max_run_speed + 20.0 and coat_speed > rock_speed + 20.0,
		"the coat keeps speed above run speed (%.1f vs %.1f px/s on rock)" % [coat_speed, rock_speed])

	# Coated mud: no cling. The shaft's right wall wet, then coated.
	for row: int in range(3, 16):
		surface.wet(Vector2i(23, row))
	surface.coat(surface.find_wet_patch(origin + Vector2(23.0 * 8.0 - 1.0, 60.0), 2.0, 64))
	_check(surface.is_coated(Vector2i(23, 8)) and not surface.is_mud(Vector2i(23, 8)), "coated mud isn't mud")
	var wall_feet: Vector2 = origin + Vector2(23.0 * 8.0 - 4.0, 90.0)
	player.global_position = wall_feet
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_right")
	for frame: int in 40:
		await get_tree().physics_frame
	var wall_y: float = player.global_position.y
	for frame: int in 15:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	_check(player.global_position.y - wall_y > 3.0, "no cling on coated mud: you slide (%.1f px)" % (player.global_position.y - wall_y))

	# Fire melts the coat back to WET (the whole patch), and the next flame dries it.
	await _stand_at(player, origin + Vector2(20.0, 128.0))
	var flame_at: Vector2 = origin + Vector2(76.0 * 8.0 + 4.0, 128.0)
	Flammable.ignite_near(get_tree(), flame_at, 2.0, null)
	var all_melted: bool = true
	for cell: Vector2i in runway:
		all_melted = all_melted and surface.is_wet(cell) and not surface.is_coated(cell)
	_check(all_melted, "a flame melts the whole coated patch back to wet, not dry")
	await get_tree().physics_frame
	Flammable.ignite_near(get_tree(), flame_at, 2.0, null)
	_check(not surface.is_wet(Vector2i(76, 16)) and surface.is_wet(Vector2i(80, 16)), "the next flame dries the tile it touches")

	# Coated grass won't burn: the flame melts the coat, the grass stays.
	surface.wet(Vector2i(28, 16))
	surface.coat(surface.find_wet_patch(origin + Vector2(28.0 * 8.0 + 4.0, 127.0), 2.0, 64))
	_check(surface.is_coated(Vector2i(28, 16)), "wet grass can be coated")
	Flammable.ignite_near(get_tree(), origin + Vector2(28.0 * 8.0 + 4.0, 128.0), 2.0, null)
	_check(fire_grid.get_state(Vector2i(28, 16)) == FireGrid.State.GRASS and surface.is_wet(Vector2i(28, 16)),
		"coated grass doesn't burn: the flame only melts the coat")

	# Near water, 1 gathers as before: a ball, not a cursor.
	await _stand_at(player, origin + Vector2(73.0 * 8.0, 128.0))
	await _start_hold(player)
	hands.ball_position = origin + Vector2(69.0 * 8.0, 140.0)
	for frame: int in 6:
		await get_tree().physics_frame
	_check(hands.ball_units > 0.0 and not hands.is_frost_cursor(),
		"in reach of water the hands gather: no frost cursor (%.2f units)" % hands.ball_units)
	Input.action_release(&"water_hands")
	for frame: int in 30:
		await get_tree().physics_frame

	# Reset: coats gone with the wet.
	room.reset_objects()
	await get_tree().physics_frame
	_check(surface.get_coated_count() == 0 and not surface.is_wet(Vector2i(78, 16)), "R clears every coat")
	finished_sections.append("W8b")


## Stage W8c: crumbling platforms (painted Crumbling rock and Crumbling ice), in room
## Water J past the W8b gap: two rock patches (cols 101-103, 106-108) and an ice run
## (cols 111-120) over a spike pit.
func _check_w8c_crumbling(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterJ") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	var rock: CrumbleRockLayer = room.get_node_or_null("CrumbleRock") as CrumbleRockLayer
	var ice: CrumbleIceLayer = room.get_node_or_null("CrumbleIce") as CrumbleIceLayer
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(rock != null and ice != null and water != null, "W8c: Water J has a CrumbleRock and a CrumbleIce layer")
	if rock == null or ice == null or water == null:
		return
	room.reset_objects()
	var origin: Vector2 = room.global_position
	var crumble_time: float = player.water_tuning.crumble_time
	# Game seconds as physics frames (the countdown runs on game time).
	var crumble_frames: int = ceili(crumble_time * Engine.physics_ticks_per_second)
	var patch_a: Vector2i = Vector2i(102, 16)
	var patch_b: Vector2i = Vector2i(107, 16)
	var safe_feet: Vector2 = origin + Vector2(96.0 * 8.0, 128.0)
	_check(rock.crumble.patches.size() == 2 and rock.crumble.get_patch_index(patch_a) != rock.crumble.get_patch_index(patch_b),
		"the two rock rows are two patches (%d)" % rock.crumble.patches.size())
	_check(ice.is_in_group(IceLayer.ICE_GROUP), "crumbling ice is ice (IceLayer.ICE_GROUP)")
	_check(water.is_cell_solid(patch_a) and water.is_cell_solid(Vector2i(115, 16)) and not water.surface_grid.is_absorbent(patch_a),
		"water treats crumbling tiles as solid ground that soaks nothing")

	# Landing on patch A starts it; B waits. Step off before it goes (spikes below).
	var shatters_before: int = rock.crumble.shatter_count
	await _stand_at(player, origin + Vector2(102.0 * 8.0 + 4.0, 128.0))
	_check(player.is_on_floor() and rock.crumble.is_crumbling(patch_a) and not rock.crumble.is_crumbling(patch_b),
		"standing on rock patch A starts its crumble; patch B waits")
	await _stand_at(player, safe_feet)
	for frame: int in floori(crumble_frames / 2.0) - 40:
		await get_tree().physics_frame
	_check(rock.get_cell_source_id(patch_a) != -1, "halfway through crumble_time it still stands")
	for frame: int in floori(crumble_frames / 2.0) + 20:
		await get_tree().physics_frame
	_check(rock.get_cell_source_id(patch_a) == -1 and rock.get_cell_source_id(Vector2i(101, 16)) == -1
		and rock.get_cell_source_id(Vector2i(103, 16)) == -1 and rock.crumble.shatter_count == shatters_before + 1,
		"crumble_time after the landing, all of patch A is gone")
	_check(rock.get_cell_source_id(patch_b) != -1 and not rock.crumble.is_crumbling(patch_b), "patch B is untouched")
	# Patch A's picture falls away instead of vanishing (after the W8c play-test).
	var falls: Array[Node] = rock.get_children().filter(func(child: Node) -> bool: return child is CrumbleFall)
	_check(falls.size() == 1 and (falls[0] as CrumbleFall).position.y > (falls[0] as CrumbleFall).pivot.y,
		"the crumbled patch falls (%d falling pieces)" % falls.size())
	_check(not water.is_cell_solid(patch_a), "the water's solid grid knows patch A is gone")

	# Patch B crumbles on its own.
	await _stand_at(player, origin + Vector2(107.0 * 8.0 + 4.0, 128.0))
	_check(rock.crumble.is_crumbling(patch_b), "landing on patch B starts it separately")
	await _stand_at(player, origin + Vector2(124.0 * 8.0 + 4.0, 128.0))
	for frame: int in crumble_frames:
		await get_tree().physics_frame
	_check(rock.get_cell_source_id(patch_b) == -1 and rock.crumble.shatter_count == shatters_before + 2, "patch B is gone too")

	# Reset: both back, whole and still.
	room.reset_objects()
	await get_tree().physics_frame
	_check(rock.get_cell_source_id(patch_a) != -1 and rock.get_cell_source_id(patch_b) != -1
		and not rock.crumble.is_crumbling(patch_a) and rock.crumble.patches.size() == 2 and water.is_cell_solid(patch_a),
		"R brings the crumbled rock back")
	await get_tree().process_frame  # queue_free() lands at the end of the frame
	_check(not rock.get_children().any(func(child: Node) -> bool: return child is CrumbleFall),
		"and its falling pieces are gone")

	# A reset stops a countdown too, even when another patch had already broken (after
	# the W8c play-test: the rebuild after painting A back carried B's countdown over).
	await _stand_at(player, origin + Vector2(102.0 * 8.0 + 4.0, 128.0))
	await _stand_at(player, safe_feet)
	for frame: int in crumble_frames + 5:
		await get_tree().physics_frame
	await _stand_at(player, origin + Vector2(107.0 * 8.0 + 4.0, 128.0))
	_check(rock.get_cell_source_id(patch_a) == -1 and rock.crumble.is_crumbling(patch_b), "A broke and B is crumbling")
	room.reset_objects()
	await _stand_at(player, origin + Vector2(124.0 * 8.0 + 4.0, 128.0))
	for frame: int in crumble_frames + 5:
		await get_tree().physics_frame
	_check(rock.get_cell_source_id(patch_a) != -1 and rock.get_cell_source_id(patch_b) != -1
		and not rock.crumble.is_crumbling(patch_b), "a reset stops B's countdown: it never falls")

	# A patch's own crumble time (set in the level editor): B falls after 0.5 s.
	var quick_times: Dictionary[Vector2i, float] = {patch_b: 0.5}
	rock.patch_crumble_times = quick_times
	await _stand_at(player, origin + Vector2(107.0 * 8.0 + 4.0, 128.0))
	await _stand_at(player, origin + Vector2(124.0 * 8.0 + 4.0, 128.0))
	for frame: int in ceili(0.5 * Engine.physics_ticks_per_second) + 5:
		await get_tree().physics_frame
	_check(rock.get_cell_source_id(patch_b) == -1 and rock.get_cell_source_id(patch_a) != -1,
		"a patch with its own 0.5 s crumble time falls after 0.5 s")
	rock.patch_crumble_times = {} as Dictionary[Vector2i, float]
	room.reset_objects()
	await get_tree().physics_frame

	# Crumbling ice: slippery, keeps speed above run speed (I5), then shatters, and
	# gives no water.
	var books: float = water.get_books_units()
	await _stand_at(player, origin + Vector2(112.0 * 8.0, 128.0))
	_check(player.is_on_ice, "standing on crumbling ice is standing on ice")
	player.velocity = Vector2(200.0, 0.0)
	Input.action_press(&"move_right")
	for frame: int in 15:
		await get_tree().physics_frame
	var ice_speed: float = player.velocity.x
	Input.action_release(&"move_right")
	_check(ice_speed > player.tuning.max_run_speed + 20.0,
		"crumbling ice keeps speed above run speed (%.1f px/s)" % ice_speed)
	_check(ice.crumble.is_crumbling(Vector2i(115, 16)), "the ice run is crumbling")
	await _stand_at(player, safe_feet)
	for frame: int in crumble_frames:
		await get_tree().physics_frame
	var ice_left: int = ice.get_used_cells().size()
	_check(ice_left == 0 and ice.crumble.shatter_count == 1, "the whole ice run shattered (%d tiles left)" % ice_left)
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "shattered crumbling ice gives no water")

	room.reset_objects()
	await get_tree().physics_frame
	_check(ice.get_used_cells().size() == 10 and not ice.crumble.has_crumbling(), "R brings the ice run back")
	finished_sections.append("W8c")


## After the W8c play-tests, in room Water J: the held ball soaks into the earth it
## touches while 1 is still held, freezing a ball that touches wet ground coats that
## ground too (a ball too small for one ice tile coats it like the frost cursor), the
## mud climb, and the flame jet (W) doesn't light with your head under water.
func _check_w8_playtest_fixes(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterJ") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "W8play: Water J has a WaterWorld")
	if water == null:
		return
	var hands: WaterHandsAbility = player.water_hands
	var surface: SurfaceGrid = water.surface_grid
	var origin: Vector2 = room.global_position
	room.reset_objects()
	# On the earth floor past the ice slope (cols 54-61, top y 136).
	await _stand_at(player, origin + Vector2(55.0 * 8.0, 136.0))
	await _wait_until_calm(water)
	await _start_hold(player)
	_check(hands.is_holding(), "holding 1 on the earth floor")
	# A ball of 2 units (put in the hands, books and all), resting on the earth.
	var units: float = 2.0
	hands.ball_units = units
	water.held_area += units * WaterWorld.UNIT_AREA
	var books: float = water.get_books_units()
	var floor_cell: Vector2i = Vector2i(57, 17)
	hands.ball_position = origin + Vector2(57.0 * 8.0 + 4.0, 136.0 - hands.get_ball_radius() - 0.5)
	hands.ball_velocity = Vector2.ZERO
	for frame: int in 20:
		await get_tree().physics_frame
	_check(hands.is_holding() and hands.ball_units < units - 0.1 and surface.is_mud(floor_cell),
		"while 1 is held, the ball soaks into the earth it touches (%.2f units left, mud: %s)" % [hands.ball_units, surface.is_mud(floor_cell)])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "soaking from the hands keeps the books")
	_check(not hands.coat_patch.is_empty() and hands.coat_patch.has(floor_cell),
		"the ball touching the wet floor ghosts its coat (%d tiles)" % hands.coat_patch.size())
	# 2: the ball freezes and the wet floor it touches gets its coat.
	player.freeze.cooldown_remaining = 0.0
	await _press(&"water_freeze")
	Input.action_release(&"water_hands")
	for frame: int in 3:
		await get_tree().physics_frame
	_check(surface.is_coated(floor_cell) and not hands.is_holding(),
		"freezing a ball that touches wet ground coats the ground too")
	room.reset_objects()
	for frame: int in 10:
		await get_tree().physics_frame

	# A ball too small for one ice tile: 2 coats the wet ground like the frost cursor.
	await _stand_at(player, origin + Vector2(55.0 * 8.0, 136.0))
	surface.wet(floor_cell)
	await _start_hold(player)
	var tiny_units: float = 0.3
	hands.ball_units = tiny_units
	water.held_area += tiny_units * WaterWorld.UNIT_AREA
	books = water.get_books_units()
	hands.ball_position = origin + Vector2(57.0 * 8.0 + 4.0, 136.0 - hands.get_ball_radius() - 0.5)
	hands.ball_velocity = Vector2.ZERO
	for frame: int in 3:
		await get_tree().physics_frame
	player.freeze.cooldown_remaining = 0.0
	await _press(&"water_freeze")
	Input.action_release(&"water_hands")
	for frame: int in 3:
		await get_tree().physics_frame
	_check(surface.is_coated(floor_cell) and not hands.is_holding() and hands.ball_units == 0.0,
		"a ball too small for an ice tile coats the wet ground it touches")
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "its few drops fall: the books hold")
	room.reset_objects()
	for frame: int in 30:
		await get_tree().physics_frame

	# The mud climb, on the shaft's right wall (col 23, rows 3-15; open above row 3).
	# Distances and waits follow the tuning (it's tuned in play: F5, F4 saves it).
	var climb_speed: float = player.water_tuning.mud_climb_speed
	var ticks: float = Engine.physics_ticks_per_second
	for row: int in range(6, 16):
		surface.wet(Vector2i(23, row))
	var wall_feet: Vector2 = origin + Vector2(23.0 * 8.0 - 4.0, 100.0)
	player.global_position = wall_feet
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_right")
	for frame: int in 20:
		await get_tree().physics_frame
	var cling_y: float = player.global_position.y
	Input.action_press(&"move_up")
	for frame: int in 20:
		await get_tree().physics_frame
	var climbed: float = cling_y - player.global_position.y
	_check(player.state_machine.current_state.name == &"WallSlide" and climbed > climb_speed * 20.0 / ticks * 0.8,
		"holding Up on a mud wall climbs it (%.1f px in 1/3 s at %.0f px/s)" % [climbed, climb_speed])
	# On up to where the mud ends (the head at row 6's top, y 48): long enough at any speed.
	for frame: int in ceili(maxf(cling_y - origin.y - 48.0, 0.0) / maxf(climb_speed, 1.0) * ticks) + 20:
		await get_tree().physics_frame
	var stop_y: float = player.global_position.y
	for frame: int in 10:
		await get_tree().physics_frame
	_check(absf(player.global_position.y - stop_y) < 0.5 and player.global_position.y > origin.y + 48.0
		and not player.is_on_floor(), "where the mud ends under dry wall, the climb stops (feet at y %.1f)" % (player.global_position.y - origin.y))
	Input.action_release(&"move_up")
	Input.action_press(&"move_down")
	var before_down: float = player.global_position.y
	for frame: int in 15:
		await get_tree().physics_frame
	Input.action_release(&"move_down")
	_check(player.global_position.y - before_down > climb_speed * 15.0 / ticks * 0.8,
		"holding Down slides down the mud (%.1f px)" % (player.global_position.y - before_down))
	# Mud to the top: the climb ends in a hop onto it.
	for row: int in range(3, 6):
		surface.wet(Vector2i(23, row))
	Input.action_press(&"move_up")
	for frame: int in ceili(80.0 / maxf(climb_speed, 1.0) * ticks) + 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	Input.action_release(&"move_up")
	Input.action_release(&"move_right")
	_check(player.is_on_floor() and absf(player.global_position.y - (origin.y + 24.0)) < 1.0,
		"climbing past the top of the wall hops onto it (feet at y %.1f, want 24)" % (player.global_position.y - origin.y))
	room.reset_objects()
	for frame: int in 10:
		await get_tree().physics_frame

	# W with your head under water: a sputter, no jet, no pip spent.
	await _stand_at(player, origin + Vector2(20.0 * 8.0 + 4.0, 144.0))
	for frame: int in 20:
		await get_tree().physics_frame
	_check(player.swim.is_swimming(), "standing in the shaft's pool, your head is under")
	var pips_before: int = player.fire_bar.pips
	await _press(&"flame_jet")
	for frame: int in 5:
		await get_tree().physics_frame
	_check(player.state_machine.current_state.name != &"Jetting" and player.fire_bar.pips == pips_before,
		"W under water doesn't jet (state %s, pips %d -> %d)" % [player.state_machine.current_state.name, pips_before, player.fire_bar.pips])
	room.reset_objects()
	finished_sections.append("W8play")


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


## Stage W2: loose water (Water_bending.md §6.1 part 2, §6.2, §6.3), in room Water B.
func _check_w2_loose_water(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterB") as Room
	world.jump_to_room(room)
	for frame: int in 10:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water B is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "Water B has a WaterWorld")
	if water == null:
		return
	var tuning: WaterTuning = player.water_tuning
	_check(_action_has_key("debug_water_throw", KEY_6), "debug_water_throw is on 6")
	_check(water.renderer != null, "the WaterWorld has a WaterRenderer (metaballs; off in headless runs)")
	# Debug throws make new water (in W3 the hands take it from pools): the books
	# expect it, `thrown` units so far.
	var books: float = water.get_books_units()
	var thrown: float = 1.0

	# Breaking waves are off for the soak and flight checks: the waterfall pool's
	# crests throw foam sideways onto the earth and into the ball's area, which
	# isn't what those check. (Waves get their own check below.)
	var break_throw: float = tuning.wave_break_throw
	tuning.wave_break_throw = 0.0
	for frame: int in 40:
		await get_tree().physics_frame  # the foam already in the air lands

	# The dry earth patch soaks a small ball up entirely (wicking into the tiles
	# beside where it lands): no puddle.
	water.throw_ball(Vector2(196, 130), Vector2(0, 40), 1.0)
	for frame: int in 60:
		await get_tree().physics_frame
	var soaked: float = water.get_soaked_units()
	_check(soaked > 0.98 and soaked <= 1.01, "the earth patch soaks up a 1-unit ball (%.2f units)" % soaked)
	_check(water.is_wet(Vector2i(24, 20)), "the earth under it is wet")
	thrown += 4.0

	# A thrown ball holds together in flight (cohesion), over the open floor.
	var ball_area: Rect2 = Rect2(104, 0, 100, 150)
	water.throw_ball(Vector2(150, 70), Vector2(0, -60), 4.0)
	var start_spread: float = _particle_spread(water, ball_area)
	for frame: int in 18:
		await get_tree().physics_frame
	var flight_spread: float = _particle_spread(water, ball_area)
	tuning.wave_break_throw = break_throw
	# Neither flying apart nor squeezed into a dot: about the size of its water.
	_check(flight_spread > start_spread * 0.6 and flight_spread < start_spread * 1.4,
		"a thrown ball holds together in flight, its own size (spread %.1f px, at the throw %.1f px)" % [flight_spread, start_spread])
	# It splats on the rock floor and spreads into a thin puddle.
	for frame: int in 150:
		await get_tree().physics_frame
	var puddle: WaterBody = null
	for body: WaterBody in water.bodies:
		if is_equal_approx(body.floor_y[0], 160.0) and body.left_x < 160.0 and body.get_right_x() > 140.0:
			puddle = body
	_check(puddle != null and puddle.get_max_depth() <= tuning.puddle_min_depth + 1.5 and puddle.get_right_x() - puddle.left_x >= 48.0,
		"on the floor the ball spreads into a thin puddle (%s)" % ("none" if puddle == null else "%.0f px wide, %.1f px deep" % [puddle.get_right_x() - puddle.left_x, puddle.get_max_depth()]))
	_check(absf(water.get_books_units() - books - thrown) < CONSERVATION_TOLERANCE,
		"water is conserved through the throw and the splat (books %.3f + %.0f thrown -> %.3f)" % [books, thrown, water.get_books_units()])

	# Particles bump into the crate (a moving solid): none ends up inside it.
	var crate: Crate = room.get_node("Crate1") as Crate
	var crate_box: Rect2 = crate.get_water_box().grow(-0.6)
	crate_box.position = water.to_local(crate_box.position)
	water.throw_ball(Vector2(112, 140), Vector2(140, -20), 2.0)
	thrown += 2.0
	var inside_seen: int = 0
	for frame: int in 40:
		await get_tree().physics_frame
		for position_px: Vector2 in water.drop_positions:
			if crate_box.has_point(position_px):
				inside_seen += 1
	_check(inside_seen == 0, "loose water splashes off the crate, never through it (%d inside)" % inside_seen)

	# A ball into the pool throws up a crown of its own water.
	var crowns_before: int = 0
	for frame: int in 40:
		await get_tree().physics_frame
		crowns_before += water.crown_count
	water.throw_ball(Vector2(72, 60), Vector2(0, 120), 4.0)
	thrown += 4.0
	var crowns_after: int = 0
	for frame: int in 40:
		await get_tree().physics_frame
		crowns_after += water.crown_count
	_check(crowns_after > crowns_before + 3,
		"a ball dropped into the pool throws up a splash crown (%d crown drops, %d from the waterfall alone)" % [crowns_after, crowns_before])

	# The waterfall turns the wheel; the overflow drain holds the pool's level.
	var wheel: WaterWheel = room.get_node("WaterWheel") as WaterWheel
	for frame: int in 120:
		await get_tree().physics_frame
	_check(wheel.angular_speed > 0.5, "the waterfall turns the waterwheel (%.2f rad/s)" % wheel.angular_speed)
	var pool_surface: float = water.get_surface_y_at(Vector2(40, 140))
	# Not exactly: the water must stand a little higher to flow over to the drain,
	# and the waterfall keeps it rippling.
	_check(pool_surface > 123.0 and pool_surface < 130.0, "the overflow drain holds the pool near y 128 (surface %.1f)" % pool_surface)
	_check((room.get_node("OverflowDrain") as WaterSink).drained_units > 0.0, "the overflow drain takes the waterfall's water")

	# The stream: water really flows right along the lower step and spills into the
	# drained basin.
	var stream: Array = water.find_body_under(Vector2(290, 76))
	var stream_flow: float = 0.0
	if not stream.is_empty():
		var stream_body: WaterBody = stream[0]
		for pipe: int in stream_body.flow.size():
			stream_flow += stream_body.flow[pipe]
	_check(not stream.is_empty() and stream_flow > 0.0, "the stream on the shelf flows toward its lip (total flow %.1f)" % stream_flow)
	_check((room.get_node("FloorDrain") as WaterSink).drained_units > 0.0, "the basin's floor drain takes the stream's water")
	_check(absf(water.get_books_units() - books - thrown) < CONSERVATION_TOLERANCE,
		"the books balance with sources and drains running (%.3f + %.0f thrown -> %.3f units)" % [books, thrown, water.get_books_units()])

	# Reset clears the loose water and the soaking.
	room.reset_objects()
	_check(water.get_drop_count() == 0 and water.get_soaked_units() == 0.0 and not water.is_wet(Vector2i(24, 20)),
		"a reset clears the particles and dries the earth")

	# Breaking waves (play-test 2): a big poke into the waterfall's pool makes crests
	# that throw off particles, and the thrown water doesn't keep re-breaking forever.
	var breaks_before: int = water.crest_break_count
	water.poke(Vector2(56, 130), 12.0)
	for frame: int in 60:
		await get_tree().physics_frame
	var breaks: int = water.crest_break_count - breaks_before
	_check(breaks > 0, "a poked pool's crests break into particles (%d thrown)" % breaks)
	_check(breaks < 120, "breaking waves die down instead of feeding themselves (%d in 1 s)" % breaks)
	room.reset_objects()

	# Performance (§6.5): the particle cap full in one clump (cohesion's worst case),
	# with both sources running.
	# (The sources never let the room calm down, so no wait: the ball is thrown
	# right after each reset.)
	var make_ball: Callable = func() -> void:
		water.throw_ball(Vector2(170, 60), Vector2(0, -30), 30.0)
	var ball: Dictionary = await _measure_water_step(room, water, make_ball, false)
	_print_budget("W2 loose water under stress", ball, water)
	_check(int(ball["fewest_most_drops"]) >= tuning.max_drops - 20,
		"every round of the stress test fills the particle cap (at least %d of %d)" % [ball["fewest_most_drops"], tuning.max_drops])
	_check_budget(float(ball["median_usec"]),
		"loose water stays under the 2 ms budget: %.0f us (median of %d rounds)" % [ball["median_usec"], BUDGET_ROUNDS])
	room.reset_objects()
	finished_sections.append("W2")


## Stage W3: the water hands (Water_bending.md §5.1), in room Water C. Drives the
## real keys (Input.action_press), so it runs through the states like a player.
func _check_w3_water_hands(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterC") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water C is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "Water C has a WaterWorld")
	if water == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var hands: WaterHandsAbility = player.water_hands
	# No snakes here (W4 tests them): with the KEY trigger and 3 never pressed, every
	# lift out of a pool just leaves it, as it did when W3 was built. Restored at the
	# end of the section.
	var saved_trigger: WaterTuning.SnakeTrigger = tuning.snake_trigger
	tuning.snake_trigger = WaterTuning.SnakeTrigger.KEY
	_check(_action_has_key("water_hands", KEY_1) and _action_has_key("water_freeze", KEY_2),
		"water_hands is on 1 and water_freeze on 2")
	_check(hands != null and player.state_machine.has_node("WaterHolding"), "the player has WaterHandsAbility and a WaterHolding state")
	await _wait_until_calm(water)
	var books: float = water.get_books_units()
	var pool_before: float = _units_in(water, 56, 144, 176)
	var basin_before: float = _units_in(water, 176, 232, 160)

	# Hold 1: slow motion, an empty ball at the hands.
	await _start_hold(player)
	_check(player.state_machine.current_state.name == &"WaterHolding" and hands.is_holding(),
		"holding 1 enters WaterHolding with a ball (state %s)" % player.state_machine.current_state.name)
	_check(is_equal_approx(Engine.time_scale, tuning.hold_time_scale),
		"the world slows to %.2fx (got %.2f)" % [tuning.hold_time_scale, Engine.time_scale])
	_check(hands.ball_units == 0.0, "the ball starts empty")

	# Steer it down-left into the deep pool: it gathers up to 4 units, the pool loses
	# exactly that, and the books (which count the held water) don't change.
	await _steer_ball_until([&"move_left", &"move_down"],
		func() -> bool: return hands.ball_position.y > room.global_position.y + 138.0, 2.0)
	var filled: bool = await _steer_ball_until([],
		func() -> bool: return hands.ball_units >= tuning.ball_max_units - 0.001, 2.0)
	_check(filled, "steered into the pool, the ball gathers %.0f units (%.2f)" % [tuning.ball_max_units, hands.ball_units])
	var pool_while_held: float = _units_in(water, 56, 144, 176)
	_check(absf(pool_before - pool_while_held - hands.ball_units) < 0.05,
		"the pool lost what the ball holds (%.2f -> %.2f, ball %.2f)" % [pool_before, pool_while_held, hands.ball_units])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "the books count the water in the hands")
	_check(not water.held_dots.is_empty(), "the held ball is drawn with the loose water (%d dots)" % water.held_dots.size())

	# Up out of the pool, then right over the basin; stop, and let go: it drops in.
	await _steer_ball_until([&"move_up"], func() -> bool: return hands.ball_position.y < room.global_position.y + 112.0, 2.0)
	await _steer_ball_until([&"move_right"], func() -> bool: return hands.ball_position.x > room.global_position.x + 190.0, 3.0)
	await get_tree().create_timer(0.4, true, false, true).timeout  # drag to a stop (real time)
	_check(hands.is_holding(), "the ball is still held over the basin, inside the ring")
	Input.action_release(&"water_hands")
	for frame: int in 4:
		await get_tree().physics_frame
	_check(not hands.is_holding() and player.state_machine.current_state.name != &"WaterHolding"
		and is_equal_approx(Engine.time_scale, 1.0), "letting go of 1 releases the ball and ends the slow motion")
	_check(hands.last_release_units >= tuning.ball_max_units - 0.01, "the release lets go of all %.2f units" % hands.last_release_units)
	for frame: int in 240:
		await get_tree().physics_frame
	var pool_after: float = _units_in(water, 56, 144, 176)
	var basin_after: float = _units_in(water, 176, 232, 160)
	# Some of it splashes out of the shallow basin onto the floor (crowns): about 1 unit.
	_check(pool_after < pool_before - 3.0 and basin_after > basin_before + 2.5,
		"4 units carried from the pool to the basin: pool %.2f -> %.2f, basin %.2f -> %.2f" % [pool_before, pool_after, basin_before, basin_after])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the books balance after the carry (%.3f -> %.3f)" % [books, water.get_books_units()])

	# A throw: moving when you let go, the water flies on at throw_multiplier x.
	await _start_hold(player)
	await _steer_ball_until([&"move_up"], func() -> bool: return hands.ball_velocity.length() > tuning.ball_move_speed * 0.9, 1.0)
	var steer_speed: float = hands.ball_velocity.length()
	Input.action_press(&"move_up")
	Input.action_release(&"water_hands")
	for frame: int in 3:
		await get_tree().physics_frame
	Input.action_release(&"move_up")
	_check(not hands.is_holding() and absf(hands.last_release_velocity.length() - steer_speed * tuning.throw_multiplier) < steer_speed * 0.3,
		"a moving ball is thrown at %.1fx its speed (%.0f -> %.0f px/s)" % [tuning.throw_multiplier, steer_speed, hands.last_release_velocity.length()])

	# Out of the ring: it lets go by itself.
	await _start_hold(player)
	var left_ring: bool = await _steer_ball_until([&"move_up"], func() -> bool: return not hands.is_holding(), 3.0)
	Input.action_release(&"water_hands")
	for frame: int in 3:
		await get_tree().physics_frame  # the state leaves on its next physics frame
	_check(left_ring and player.state_machine.current_state.name != &"WaterHolding",
		"the ball leaving the ring is let go by itself (let go: %s, state %s, ball %.0f px from you)"
			% [left_ring, player.state_machine.current_state.name, hands.ball_position.distance_to(player.get_center())])

	# The time limit.
	await _start_hold(player)
	var held_msec: int = Time.get_ticks_msec()
	while hands.is_holding() and Time.get_ticks_msec() - held_msec < int(tuning.max_hold_time * 1000.0) + 1500:
		await get_tree().process_frame
	var held_for: float = (Time.get_ticks_msec() - held_msec) / 1000.0
	Input.action_release(&"water_hands")
	for frame: int in 3:
		await get_tree().physics_frame
	_check(not hands.is_holding() and absf(held_for - tuning.max_hold_time) < 0.5 and is_equal_approx(Engine.time_scale, 1.0),
		"after %.1f real s the ball is let go by itself (held %.2f s)" % [tuning.max_hold_time, held_for])

	# Jump cancels: the ball just drops (no boost) and the player jumps.
	await _start_hold(player)
	await _steer_ball_until([&"move_up"], func() -> bool: return hands.ball_velocity.length() > 40.0, 1.0)
	await _press(&"jump")
	Input.action_release(&"water_hands")
	_check(not hands.is_holding() and hands.last_release_velocity == Vector2.ZERO and player.velocity.y < 0.0,
		"Jump drops the ball (no throw) and jumps (state %s)" % player.state_machine.current_state.name)
	for frame: int in 60:
		await get_tree().physics_frame

	# Orbs (after play-test 3): the held ball is water like any other, so an orb
	# flying into it gets SOAKED: it slows right down and falls; the ball keeps its water.
	await _start_hold(player)
	await _steer_ball_until([&"move_left", &"move_down"],
		func() -> bool: return hands.ball_position.y > room.global_position.y + 138.0, 2.0)
	await _steer_ball_until([], func() -> bool: return hands.ball_units >= 2.0, 2.0)
	# Well above the pool, so no stray drop from it is gathered during the check.
	await _steer_ball_until([&"move_up"], func() -> bool: return hands.ball_position.y < room.global_position.y + 96.0, 2.0)
	await get_tree().create_timer(0.4, true, false, true).timeout  # the ball drifts to a stop
	var units_before_orb: float = hands.ball_units
	var orb: SentryOrb = (load("res://scenes/enemies/sentry_orb.tscn") as PackedScene).instantiate() as SentryOrb
	room.add_child(orb)
	orb.launch(hands.ball_position + Vector2(hands.get_ball_radius() + 10.0, 0.0), Vector2(-60.0, 0.0), null)
	# Slow motion scales each physics frame's delta: at 0.2x the orb moves 0.2 px a frame.
	for frame: int in 150:
		await get_tree().physics_frame
		if not is_instance_valid(orb) or orb.is_soaked:
			break
	var soaked: bool = is_instance_valid(orb) and orb.is_soaked
	_check(soaked and absf(orb.velocity.x) <= 60.0 * tuning.orb_soaked_speed_keep + 0.5
		and absf(hands.ball_units - units_before_orb) < 0.01 and not player.is_dead(),
		"an orb flying into the held ball is soaked: slowed to %.0f px/s, the ball keeps its %.2f units"
			% [absf(orb.velocity.x) if is_instance_valid(orb) else -1.0, hands.ball_units])
	Input.action_release(&"water_hands")
	var orb_start_y: float = orb.global_position.y if is_instance_valid(orb) else 0.0
	var orb_fell: bool = false
	var orb_gone: bool = false
	for frame: int in 400:
		await get_tree().physics_frame
		if not is_instance_valid(orb):
			orb_gone = true
			break
		if orb.global_position.y > orb_start_y + 16.0:
			orb_fell = true
	_check(orb_fell and orb_gone, "the soaked orb falls (and sinks) and pops on the ground (fell: %s, popped: %s)" % [orb_fell, orb_gone])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the books balance after throws and orbs (%.3f -> %.3f)" % [books, water.get_books_units()])

	# Fireballs (after play-test 3): any water puts them out. One thrown down into the
	# deep pool is gone without bursting on the floor.
	var fireball: Fireball = Fireball.launch(room, room.global_position + Vector2(100.0, 100.0), Vector2.DOWN,
		Sentry.FIRE_TUNING, null, 0.0)
	var fireball_hit: Array = []
	fireball.finished.connect(func(hit_node: Node) -> void: fireball_hit.append(hit_node))
	for frame: int in 60:
		await get_tree().physics_frame
		if not is_instance_valid(fireball):
			break
	_check(not is_instance_valid(fireball) and fireball_hit.size() == 1 and fireball_hit[0] == null,
		"a fireball flying into the pool goes out (finished on: %s)" % [fireball_hit])

	# Under water, the ball moving into you SHOVES you once (after play-test 3): at the
	# bottom of the deep pool, the ball behind you (facing left), steered right.
	await _stand_at(player, room.global_position + Vector2(72.0, 175.0))
	for frame: int in 40:
		await get_tree().physics_frame
	_check(player.swim.submerged_share >= tuning.ball_push_min_share,
		"standing in the deep pool, you're under water (share %.2f)" % player.swim.submerged_share)
	# No air gust under water.
	_check(player.gust.is_under_water() and not player.gust.can_gust(),
		"no gust with the water above your middle (share %.2f)" % player.swim.submerged_share)
	await _press(&"gust")
	_check(player.state_machine.current_state.name not in [&"GustAim", &"GustRecoil"],
		"pressing gust under water does nothing (state %s)" % player.state_machine.current_state.name)
	for frame: int in 20:
		await get_tree().physics_frame
	player.facing_direction = -1.0  # the ball starts on your left, behind you
	await _start_hold(player)
	hands.last_shove_velocity = Vector2.ZERO
	var push_start_x: float = player.global_position.x
	var shoved: bool = await _steer_ball_until([&"move_right"],
		func() -> bool: return hands.last_shove_velocity != Vector2.ZERO, 2.0)
	var shove_speed: float = player.velocity.x
	_check(shoved and hands.last_shove_velocity.x > tuning.ball_push_speed * tuning.ball_push_min_share
		and hands.ball_velocity == Vector2.ZERO and hands.is_holding(),
		"the ball steered into you under water shoves you once (%.0f px/s) and stops" % hands.last_shove_velocity.x)
	# Once: holding the arrow on, the ball (still touching) doesn't shove again.
	hands.last_shove_velocity = Vector2.ZERO
	await _steer_ball_until([&"move_right"], func() -> bool: return false, 0.3)
	_check(hands.last_shove_velocity == Vector2.ZERO and player.global_position.x > push_start_x + 1.0,
		"one shove per touch, and you moved (%.1f px; started at %.0f px/s)"
			% [player.global_position.x - push_start_x, shove_speed])
	Input.action_release(&"water_hands")
	for frame: int in 60:
		await get_tree().physics_frame

	await _start_hold(player)
	# A floating crate takes the same shove (Pushable.try_launch). Set up by hand: the
	# ball just touching the crate's left side, moving right.
	var crate: Node2D = (load("res://scenes/objects/crate.tscn") as PackedScene).instantiate() as Node2D
	room.add_child(crate)
	crate.global_position = room.global_position + Vector2(112.0, 150.0)
	for frame: int in 90:
		await get_tree().physics_frame  # it floats up to the surface
	var crate_box: Rect2 = crate.call(&"get_water_box")
	hands.ball_position = Vector2(crate_box.position.x - hands.get_ball_radius() + 0.5, crate_box.get_center().y)
	hands.ball_velocity = Vector2(tuning.ball_move_speed, 0.0)
	hands.last_shove_velocity = Vector2.ZERO
	hands._shove_touched(hands.ball_velocity)
	var crate_speed: float = (crate as CharacterBody2D).velocity.x
	_check(hands.last_shove_velocity.x > 0.0 and crate_speed > 0.0,
		"the ball shoves a floating crate too (%.0f px/s; the crate is %.2f under)" % [crate_speed, water.get_submerged_share(crate_box)])
	Input.action_release(&"water_hands")
	for frame: int in 60:
		await get_tree().physics_frame
	crate.queue_free()

	room.reset_objects()
	_check(water.held_area == 0.0, "a reset leaves nothing held")
	tuning.snake_trigger = saved_trigger
	finished_sections.append("W3")


## Stage W4: the water snake (Water_bending.md §5.1-5.2), in room Water D. Drives
## the real keys, like W3. The narrow pool is local x 72-112 (surface y 136, floor
## y 176); the crate sits on the pillar at x 112-128, y 96-112. Each snake trigger
## (WaterTuning.snake_trigger) gets a check; the player's own choice is restored.
func _check_w4_water_snake(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterD") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water D is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "Water D has a WaterWorld")
	if water == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var hands: WaterHandsAbility = player.water_hands
	var origin: Vector2 = room.global_position
	var crate: Crate = room.get_node("Crate1") as Crate
	var saved_trigger: WaterTuning.SnakeTrigger = tuning.snake_trigger
	tuning.snake_trigger = WaterTuning.SnakeTrigger.KEY
	_check(_action_has_key("water_snake", KEY_3), "water_snake is on 3")
	await _wait_until_calm(water)
	var books: float = water.get_books_units()
	var pool_before: float = _units_in(water, 72, 112, 176)
	var snakes_at_start: int = hands.snakes_raised

	# KEY: dip the ball into the pool and fill it, then hold 3 and lift: a snake.
	await _start_hold(player)
	await _dip_and_fill(hands, origin, 140.0)
	_check(hands._is_ball_in_pool() and not hands.is_snake_hold,
		"the ball sits in the pool (y %.1f), a plain hold" % (hands.ball_position.y - origin.y))
	Input.action_press(&"water_snake")
	var raised: bool = await _steer_ball_until([&"move_up"], func() -> bool: return hands.snake != null, 1.5)
	Input.action_release(&"water_snake")
	_check(raised and hands.snakes_raised == snakes_at_start + 1,
		"KEY: lifting the ball out with 3 held raises a snake (snakes %d, last tear '%s')" % [hands.snakes_raised, hands.last_tear_reason])
	if not raised:
		Input.action_release(&"water_hands")
		tuning.snake_trigger = saved_trigger
		return
	# Up to the crate's height: the snake grows, and the pool pays for it.
	await _steer_ball_until([&"move_up"],
		func() -> bool: return hands.ball_position.y < origin.y + 104.0 or hands.snake == null, 2.5)
	var lift_speed: float = hands.ball_velocity.length()
	# Brake: let go of ↑ and the ball drifts on up ~26 px while the drag stops it
	# (far more on a slow machine, where it then sweeps over the crate).
	await _steer_ball_until([&"move_down"], func() -> bool: return hands.ball_velocity.y >= 0.0, 0.5)
	var snake: WaterSnake = hands.snake
	if snake != null:
		print("[WaterSmokeTest] snake: length %.1f px, foot %s, head %s" % [snake.length, snake.get_foot() - origin, snake.get_head() - origin])
	_check(snake != null and snake.length > 20.0
		and lift_speed > 1.0 and lift_speed <= tuning.ball_move_speed * tuning.snake_speed_share + 0.01,
		"holding up lifts the snake, a little slower than the ball (length %.0f px, %.0f px/s, last tear '%s', ball y %.1f)"
			% [snake.length if snake != null else -1.0, lift_speed, hands.last_tear_reason,
				hands.ball_position.y - origin.y])
	if snake == null:
		Input.action_release(&"water_hands")
		tuning.snake_trigger = saved_trigger
		return
	var held_units: float = hands.ball_units + snake.area / WaterWorld.UNIT_AREA
	var pool_now: float = _units_in(water, 72, 112, 176)
	# The pool paid at least what's held: a fast ball dipped in splashes a little more
	# out over the edge (the books check below counts that too).
	_check(absf(water.held_area / WaterWorld.UNIT_AREA - held_units) < 0.01
		and pool_before - pool_now > held_units - 0.3,
		"the snake's water comes from the pool (pool %.2f -> %.2f, held %.2f: ball %.2f + snake %.2f)"
			% [pool_before, pool_now, held_units, hands.ball_units, snake.area / WaterWorld.UNIT_AREA])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "the books count the snake's water")
	_check(water.held_dots.size() > 64, "the snake is drawn with the ball (%d dots)" % water.held_dots.size())

	# Dousing: a burning thing where the snake is goes out.
	var fire: Node2D = (load("res://tests/douse_test_receiver.gd") as GDScript).new() as Node2D
	room.add_child(fire)
	fire.global_position = snake.points[floori(snake.points.size() / 2.0)]
	for frame: int in 5:
		await get_tree().process_frame
	_check(not fire.call(&"is_burning") and hands.doused_count > 0, "the snake douses a fire it touches")
	fire.queue_free()

	# Sweep right: the head shoves the crate off its pillar.
	var crate_start: Vector2 = crate.global_position
	var shoved: bool = await _steer_ball_until([&"move_right"], func() -> bool: return hands.head_shoved_this_hold.has(crate), 1.5)
	_check(shoved and crate.velocity.x > 0.0,
		"the snake's head sweeps into the crate and shoves it (%.0f px/s; shoved %s, snake %s, last tear '%s', ball %s)"
			% [crate.velocity.x, hands.last_head_shoved, hands.snake != null, hands.last_tear_reason, hands.ball_position - origin])

	# Let go: a ribbon. The snake's water flows out after the ball over several
	# frames, then nothing is held any more.
	Input.action_release(&"water_hands")
	# The hold ends in a physics step, rare in slow motion: wait for it first.
	for frame: int in 30:
		await get_tree().physics_frame
		if not hands.is_holding():
			break
	var flying_frames: int = 0
	for frame: int in 120:
		await get_tree().process_frame
		if hands.flying_snake == null:
			break
		flying_frames += 1
	_check(flying_frames >= 2, "letting go throws the snake as a ribbon that feeds out over %d frames" % flying_frames)
	for frame: int in 4:
		await get_tree().physics_frame
	_check(not hands.is_holding() and hands.snake == null and hands.flying_snake == null and water.held_area < 0.01
		and water.get_drop_count() > 0,
		"the ribbon ends as loose water (held %.2f px², %d particles)" % [water.held_area, water.get_drop_count()])
	for frame: int in 120:
		await get_tree().physics_frame
	_check(crate.global_position.x > crate_start.x + 8.0 and crate.global_position.y > crate_start.y + 8.0,
		"the crate fell off the pillar (%s -> %s)" % [crate_start - origin, crate.global_position - origin])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the books balance after the whip (%.3f -> %.3f)" % [books, water.get_books_units()])

	# A trail's foot stays where it left the pool, however far the head goes (driven
	# directly: past the pool's right wall at x 112, out of the ring's reach here).
	var surface_y: float = water.to_global(Vector2(0.0, water.get_surface_y_at(Vector2(100.0, 130.0)))).y
	var wall_snake: WaterSnake = WaterSnake.new(water, Vector2(origin.x + 100.0, surface_y), Vector2(origin.x + 100.0, surface_y - 30.0))
	for step: int in 40:
		wall_snake.update(0.05, Vector2(origin.x + 160.0, surface_y - 30.0), Vector2.ZERO)
	var foot_x: float = wall_snake.get_foot().x - origin.x
	_check(absf(foot_x - 100.0) < 0.01, "a trail's foot stays where it left the pool (foot x %.1f)" % foot_x)
	wall_snake.release(Vector2.ZERO)
	for frame: int in 120:
		await get_tree().physics_frame
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the books balance after it (%.3f -> %.3f)" % [books, water.get_books_units()])

	# KEY without 3: the ball comes out alone (no snake, no splash), as in W3.
	room.reset_objects()
	await _wait_until_calm(water)
	var snakes_before: int = hands.snakes_raised
	hands.last_tear_splash_area = 0.0
	await _start_hold(player)
	await _dip_and_fill(hands, origin, 140.0)
	var left_pool: bool = await _steer_ball_until([&"move_up"],
		func() -> bool: return hands.ball_position.y < origin.y + 124.0, 1.5)
	_check(left_pool and hands.snake == null and hands.snakes_raised == snakes_before and hands.last_tear_splash_area == 0.0
		and hands.ball_units > tuning.ball_max_units - 0.01,
		"KEY: without 3 the full ball just comes out (snakes %d, splash %.1f, units %.2f)"
			% [hands.snakes_raised - snakes_before, hands.last_tear_splash_area, hands.ball_units])
	Input.action_release(&"water_hands")
	for frame: int in 60:
		await get_tree().physics_frame

	# GENTLE, lifted from deep: the ball crosses the surface too fast, and it tears.
	tuning.snake_trigger = WaterTuning.SnakeTrigger.GENTLE
	room.reset_objects()
	await _wait_until_calm(water)
	books = water.get_books_units()
	snakes_before = hands.snakes_raised
	await _start_hold(player)
	await _steer_ball_until([&"move_right", &"move_down"],
		func() -> bool: return hands.ball_position.y > origin.y + 166.0, 2.5)
	hands.last_tear_splash_area = 0.0
	await _steer_ball_until([&"move_up"], func() -> bool: return hands.ball_position.y < origin.y + 124.0, 2.0)
	_check(hands.snakes_raised == snakes_before and hands.snake == null and hands.last_tear_reason == "too fast"
		and hands.last_tear_splash_area > 0.0,
		"GENTLE: lifted fast from deep, it tears: no snake, a splash rains back (tear '%s', splash %.1f px²)"
			% [hands.last_tear_reason, hands.last_tear_splash_area])
	Input.action_release(&"water_hands")
	for frame: int in 120:
		await get_tree().physics_frame
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the books balance after a tear (%.3f -> %.3f)" % [books, water.get_books_units()])

	# KEY: raise a snake and lower it again: it sinks back into its pool (no tear).
	tuning.snake_trigger = WaterTuning.SnakeTrigger.KEY
	await _wait_until_calm(water)
	await _start_hold(player)
	await _dip_and_fill(hands, origin, 140.0)
	var tear_before: String = hands.last_tear_reason
	Input.action_press(&"water_snake")
	var raised_again: bool = await _steer_ball_until([&"move_up"],
		func() -> bool: return hands.snake != null and hands.snake.length > 8.0, 2.0)
	Input.action_release(&"water_snake")
	var sank: bool = await _steer_ball_until([&"move_down"], func() -> bool: return hands.snake == null, 2.0)
	_check(raised_again and sank and hands.last_tear_reason == tear_before and hands.is_holding(),
		"lowered back to the surface, the snake sinks into its pool (no tear; raised %s, sank %s, tear '%s' -> '%s', snakes %d, ball %s, units %.2f, holding %s)"
			% [raised_again, sank, tear_before, hands.last_tear_reason, hands.snakes_raised, hands.ball_position - origin,
				hands.ball_units, hands.is_holding()])
	Input.action_release(&"water_hands")
	for frame: int in 60:
		await get_tree().physics_frame

	# DOUBLE_TAP: tap 1, then press it again at once: that hold raises a snake with no
	# other key.
	tuning.snake_trigger = WaterTuning.SnakeTrigger.DOUBLE_TAP
	room.reset_objects()
	await _wait_until_calm(water)
	snakes_before = hands.snakes_raised
	await _start_hold(player)
	for frame: int in 3:
		await get_tree().process_frame
	Input.action_release(&"water_hands")
	for frame: int in 3:
		await get_tree().physics_frame
	Input.action_press(&"water_hands")
	for frame: int in 10:
		await get_tree().physics_frame
		if hands.is_holding():
			break
	_check(hands.is_holding() and hands.is_snake_hold and hands.is_snake_ready(),
		"DOUBLE_TAP: a double tap of 1 starts a snake hold (holding %s, snake hold %s)" % [hands.is_holding(), hands.is_snake_hold])
	await _dip_and_fill(hands, origin, 140.0)
	raised = await _steer_ball_until([&"move_up"], func() -> bool: return hands.snake != null, 1.5)
	_check(raised and hands.snakes_raised == snakes_before + 1, "DOUBLE_TAP: lifting out of the pool raises a snake")
	Input.action_release(&"water_hands")
	for frame: int in 60:
		await get_tree().physics_frame

	# REST: a full ball held still in the pool arms; then the lift raises a snake.
	tuning.snake_trigger = WaterTuning.SnakeTrigger.REST
	room.reset_objects()
	await _wait_until_calm(water)
	snakes_before = hands.snakes_raised
	await _start_hold(player)
	_check(not hands.is_snake_ready(), "REST: a fresh hold isn't armed")
	await _dip_and_fill(hands, origin, 140.0)
	var armed: bool = await _steer_ball_until([], func() -> bool: return hands.is_rest_armed, 1.5)
	_check(armed and hands.is_snake_ready(), "REST: a full ball resting in the pool arms the snake (rest %.2f s)" % hands.rest_time)
	raised = await _steer_ball_until([&"move_up"], func() -> bool: return hands.snake != null, 1.5)
	_check(raised and hands.snakes_raised == snakes_before + 1, "REST: armed, lifting out raises a snake")
	Input.action_release(&"water_hands")
	for frame: int in 60:
		await get_tree().physics_frame

	tuning.snake_trigger = saved_trigger
	room.reset_objects()
	_check(water.held_area == 0.0 and hands.snake == null, "a reset leaves no snake")
	finished_sections.append("W4")


## Grid ice (Stages I1, I4 and I5; Water_bending.md §16 "Re-planned: grid ice"), in
## room Water E. Room-local layout: ground top y 128; the small pool x 40-72 (floor
## 152); the ledge x 104-160 (top y 88); the chasm pool x 168-184; the spike chasm
## x 200-296; flat ground x 296-392.
func _check_grid_ice(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterE") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water E is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "Water E has a WaterWorld")
	if water == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var hands: WaterHandsAbility = player.water_hands
	var origin: Vector2 = room.global_position
	var unit: float = WaterWorld.UNIT_AREA
	var layer: PlayerIceLayer = water.ice_layer
	_check(layer != null and layer.get_parent() == room and layer.is_in_group(IceLayer.ICE_GROUP),
		"the room has a PlayerIce layer, in the ice group")

	# The block a ball freezes into: the most square rectangle its whole units fill.
	var sizes: Dictionary = {1: Vector2i(1, 1), 2: Vector2i(2, 1), 3: Vector2i(2, 1), 4: Vector2i(2, 2),
		6: Vector2i(3, 2), 9: Vector2i(3, 3)}
	var sizes_right: bool = true
	for units: int in sizes:
		sizes_right = sizes_right and IcePlan.block_size(units) == sizes[units]
	_check(sizes_right, "1/2/3/4/6/9 units freeze as 1x1/2x1/2x1/2x2/3x2/3x3 blocks")

	# 2 with nothing held only fizzles.
	await _stand_at(player, origin + Vector2(24.0, 128.0))
	await _wait_until_calm(water)
	var fizzles_before: int = player.freeze.fizzle_count
	var freezes_before: int = water.freeze_count
	await _press(&"water_freeze")
	_check(player.freeze.fizzle_count == fizzles_before + 1 and water.freeze_count == freezes_before,
		"2 with nothing held fizzles, no ice")

	# Hold, fill the ball from the small pool: it's drawn as a square.
	await _stand_at(player, origin + Vector2(84.0, 128.0))
	var books: float = water.get_books_units()
	await _start_hold(player)
	await _steer_ball_until([&"move_left", &"move_down"], func() -> bool: return hands.ball_position.y > origin.y + 136.0, 2.0)
	await _steer_ball_until([], func() -> bool: return hands.ball_units >= tuning.ball_max_units - 0.001, 2.0)
	_check(hands.ball_units >= tuning.ball_max_units - 0.01, "the ball fills to %.0f units (%.2f)" % [tuning.ball_max_units, hands.ball_units])
	var dot_box: Rect2 = Rect2(water.held_dots[0], Vector2.ZERO)
	for dot: Vector2 in water.held_dots:
		dot_box = dot_box.expand(dot)
	_check(absf(dot_box.size.x - dot_box.size.y) < 2.0 and dot_box.size.x > 6.0,
		"the full ball is a square (its dots span %.1f x %.1f px)" % [dot_box.size.x, dot_box.size.y])

	# At the ledge's foot the ghost is a solid 2x2 block on the ground, against the rock.
	hands.ball_position = origin + Vector2(96.0, 116.0)
	hands.ball_velocity = Vector2.ZERO
	for frame: int in 3:
		await get_tree().process_frame
	var plan: IcePlan = hands.plan
	var expected: Array[Vector2i] = [Vector2i(11, 14), Vector2i(12, 14), Vector2i(11, 15), Vector2i(12, 15)]
	var plan_right: bool = plan != null and plan.kind == IcePlan.Kind.BLOCK and plan.get_free_cells().size() == 4
	if plan_right:
		for cell: Vector2i in expected:
			plan_right = plan_right and plan.cells.has(cell)
	_check(plan_right and not plan.is_brittle,
		"the ghost is a 2x2 block at the ledge's foot, solid (anchored): %s" % [plan.cells if plan != null else []])
	player.freeze.cooldown_remaining = 0.0
	await _press(&"water_freeze")
	Input.action_release(&"water_hands")
	var placed: bool = true
	for cell: Vector2i in expected:
		placed = placed and layer.has_ice(cell) and layer.get_cell_atlas_coords(cell) == IceLayer.ICE_TILE
	_check(not hands.is_holding() and placed, "2 freezes exactly the ghost's four tiles, and the hold ends")
	_check(absf(water.ice_area - 4.0 * unit) < 0.01 and water.held_area < 0.01
		and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the block holds the ball's 4 units (ice %.2f units, held %.2f, books balance)" % [water.ice_area / unit, water.held_area / unit])
	_check(not layer.is_brittle(Vector2i(11, 15)), "touching rock, the block is anchored")
	_check(water.is_solid_px(100.0, 120.0), "the water sees the block as solid")
	# Stand on it a while: anchored ice never crumbles.
	await _stand_at(player, origin + Vector2(96.0, 112.0))
	for frame: int in int(tuning.crumble_time * 60.0) + 30:
		await get_tree().physics_frame
	_check(player.is_on_floor() and absf(player.global_position.y - origin.y - 112.0) < 1.0 and layer.has_ice(Vector2i(11, 14)),
		"you stand on the block and it stays (feet y %.1f)" % (player.global_position.y - origin.y))
	_check(player.is_ice(player.get_floor_body()), "the block is ice to stand on")

	# Blocked cells: a block half in the ledge's rock freezes only its free half; the
	# rest of its water drips off. (You step away first: you'd block a cell too.)
	await _stand_at(player, origin + Vector2(24.0, 128.0))
	var half_plan: IcePlan = IcePlan.for_ball(water, Vector2(104.0, 100.0), 4.0 * unit, 8.0)
	var blocked_count: int = 0
	for is_blocked: bool in half_plan.blocked:
		blocked_count += 1 if is_blocked else 0
	_check(half_plan.kind == IcePlan.Kind.BLOCK and blocked_count == 2, "a block half in rock has 2 blocked (red) cells")
	books = water.get_books_units()
	var drops_before: int = water.get_drop_count()
	var ice_before: float = water.ice_area
	_inject_held(water, 4.0 * unit)
	var half_id: int = water.apply_ice_plan(half_plan, Vector2(104.0, 100.0), 4.0 * unit)
	_check(half_id >= 0 and absf(water.ice_area - ice_before - 2.0 * unit) < 0.01 and water.get_drop_count() > drops_before
		and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"its free 2 tiles freeze, the other 2 units drip off as loose water (books balance)")

	# CRUMBLING (Stage I4): a block hanging over the chasm.
	var air_plan: IcePlan = IcePlan.for_ball(water, Vector2(248.0, 112.0), 4.0 * unit, 8.0)
	_check(air_plan.kind == IcePlan.Kind.BLOCK and air_plan.get_free_cells().size() == 4 and air_plan.is_brittle,
		"over the chasm the ghost says the block would hang (dashed)")
	_inject_held(water, 4.0 * unit)
	water.apply_ice_plan(air_plan, Vector2(248.0, 112.0), 4.0 * unit)
	var air_cell: Vector2i = air_plan.cells[0]
	_check(layer.is_brittle(air_cell), "frozen in mid-air, it's brittle")
	# A puddle on it, as a freeze's drips make (it must fall with the ice, after the
	# grid-ice play-test: it used to float where the ice had been).
	var block_top: float = air_cell.y * 8.0
	var block_left: float = air_cell.x * 8.0
	water.add_loose_water(Vector2(block_left + 8.0, block_top - 4.0), 0.5)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(layer.has_ice(air_cell) and not layer.is_crumbling(air_cell), "untouched, it waits")
	_check(_bodies_on_floor(water, block_left, block_left + 16.0, block_top) > 0, "a puddle lies on it")
	books = water.get_books_units()
	var shatters_before: int = layer.shatter_count
	player.state_machine.transition_to(&"Fall")
	player.global_position = origin + Vector2(248.0, air_cell.y * 8.0 - 0.5)
	player.velocity = Vector2.ZERO
	for frame: int in 5:
		await get_tree().physics_frame
	_check(layer.is_crumbling(air_cell), "landing on it starts the crumble")
	var frames_to_shatter: int = 0
	for frame: int in int(tuning.crumble_time * 60.0) + 60:
		await get_tree().physics_frame
		frames_to_shatter += 1
		if not layer.has_ice(air_cell):
			break
	_check(not layer.has_ice(air_cell) and layer.shatter_count == shatters_before + 1
		and frames_to_shatter >= int(tuning.crumble_time * 60.0) - 10,
		"%.1f s later it shatters (after %d frames)" % [tuning.crumble_time, frames_to_shatter])
	_check(_bodies_on_floor(water, block_left, block_left + 16.0, block_top) == 0,
		"the puddle falls with it (no water left standing in the air)")
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"its water falls as loose water, none lost (%.3f -> %.3f)" % [books, water.get_books_units()])
	await _wait_for_respawn(player)

	# The ICE CAP: with room for 2 freezes, a third melts the oldest (the step block).
	var saved_cap: int = tuning.max_player_ice
	tuning.max_player_ice = 2
	books = water.get_books_units()
	var small_plan: IcePlan = IcePlan.for_ball(water, Vector2(340.0, 124.0), unit, 4.0)
	_inject_held(water, unit)
	water.apply_ice_plan(small_plan, Vector2(340.0, 124.0), unit)
	_check(water.get_ice_freeze_count() == 2 and not layer.has_ice(Vector2i(11, 14))
		and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"a third freeze with a cap of 2 melts the oldest back into water (%d freezes)" % water.get_ice_freeze_count())
	tuning.max_player_ice = saved_cap

	# FIRE melts the freeze it touches.
	var fire_cell: Vector2i = small_plan.get_free_cells()[0]
	Flammable.ignite_near(get_tree(), water.to_global(Vector2(fire_cell * 8) + Vector2(4.0, 4.0)), 2.0, null)
	_check(not layer.has_ice(fire_cell) and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"fire melts it into water")

	# ICE KEEPS ANY SPEED (Stage I5): a runway of ice on the floor past the chasm.
	var runway: IcePlan = IcePlan.new()
	runway.kind = IcePlan.Kind.BLOCK
	for column: int in range(37, 49):
		runway.cells.append(Vector2i(column, 15))
		runway.atlases.append(IceLayer.ICE_TILE)
		runway.blocked.append(false)
	_inject_held(water, 12.0 * unit)
	water.apply_ice_plan(runway, Vector2(340.0, 120.0), 12.0 * unit)
	await _stand_at(player, origin + Vector2(300.0, 120.0))
	var ice_top_speed: float = player.tuning.max_run_speed * tuning.ice_max_run_scale
	player.velocity.x = ice_top_speed * 1.6
	for frame: int in 15:
		await get_tree().physics_frame
	_check(player.is_on_floor() and player.velocity.x > ice_top_speed * 1.6 - 1.0,
		"on ice, speed above run speed isn't braked (%.0f px/s after 0.25 s, started at %.0f)"
			% [player.velocity.x, ice_top_speed * 1.6])

	room.reset_objects()
	for frame: int in 3:
		await get_tree().physics_frame
	_check(layer.cell_freeze.is_empty() and water.ice_area == 0.0 and water.get_ice_freeze_count() == 0,
		"a reset clears all player ice")
	finished_sections.append("Ice")


## Snake lines, waterfall walls and rafts on clean water (grid ice, Stages I2, I3),
## in rooms Water F and G. Water F, room-local: the plateau x 8-72 (top y 96) with its
## pool x 40-64 (surface y 96); the spike pit x 72-152; the shelf x 240-288 (top y
## 104) with its pool x 272-280 (surface y 112) and crate; the plate at x 344.
## Water G: the waterfall's source at x 84, y 16; the basin x 64-96 (floor y 136); the
## tower x 104-152 (top y 48); the clean pool x 176-336 (surface y 136).
func _check_snake_lines(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterF") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water F is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "Water F has a WaterWorld")
	if water == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var hands: WaterHandsAbility = player.water_hands
	var origin: Vector2 = room.global_position
	var unit: float = WaterWorld.UNIT_AREA
	var layer: PlayerIceLayer = water.ice_layer
	await _stand_at(player, origin + Vector2(24.0, 96.0))
	await _wait_until_calm(water)

	# The trail snaps to the tile angles: a 22° lean is the gentle slope, 42° is 45°.
	var gentle: Vector2 = WaterSnake.snap_direction(Vector2(10.0, 4.0))
	var steep: Vector2 = WaterSnake.snap_direction(Vector2(10.0, 9.0))
	_check(absf(gentle.y / gentle.x - 0.5) < 0.01 and absf(steep.y / steep.x - 1.0) < 0.01,
		"a trail run snaps to the gentle 1:2 slope or 45 degrees (%s, %s)" % [gentle, steep])

	# A trail up a tile, right, then down at 45°: a column, a flat tile, then slope tiles
	# under the line.
	var path: PackedVector2Array = PackedVector2Array([Vector2(52.0, 96.0), Vector2(52.0, 79.0),
		Vector2(70.0, 79.0), Vector2(100.0, 108.0)])
	var trail: IcePlan = IcePlan.for_trail(water, path)
	var slope_cells: int = 0
	for atlas: Vector2i in trail.atlases:
		slope_cells += 1 if atlas == IceLayer.SLOPE_UP_LEFT else 0
	_check(trail.kind == IcePlan.Kind.TRAIL and trail.cells.has(Vector2i(7, 11)) and trail.cells.has(Vector2i(7, 10))
		and trail.cells.has(Vector2i(8, 10)) and slope_cells == 4 and not trail.is_brittle,
		"the trail plan: a column, a flat tile, four 45 degree slope tiles, resting on the pool (%s)" % [trail.cells])
	# BACKED SLOPES (after the grid-ice play-test): a full tile under every slope tile,
	# so the ramp's tiles share edges, not just corners.
	var backed: int = 0
	for index: int in trail.cells.size():
		if trail.atlases[index] == IceLayer.SLOPE_UP_LEFT:
			var below: int = trail.cells.find(trail.cells[index] + Vector2i.DOWN)
			backed += 1 if below >= 0 and trail.atlases[below] == IceLayer.ICE_TILE else 0
	_check(backed == slope_cells, "every slope tile is backed by a full tile under it (%d of %d)" % [backed, slope_cells])
	# Frozen: the pool pays for the tiles past what the snake held.
	var books: float = water.get_books_units()
	var pool_before: float = _units_in(water, 40, 64, 152)
	var foot: Vector2 = Vector2(52.0, 96.0)
	var trail_id: int = water.apply_ice_plan(trail, Vector2(100.0, 104.0), 0.0, 0.0, foot)
	var trail_cost: float = trail.get_cost()
	_check(trail_id >= 0 and layer.has_ice(Vector2i(9, 10)) and layer.get_cell_atlas_coords(Vector2i(9, 10)) == IceLayer.SLOPE_UP_LEFT,
		"freezing it makes those tiles (cost %.1f units)" % (trail_cost / unit))
	_check(pool_before - _units_in(water, 40, 64, 152) > trail_cost / unit - 0.3
		and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the pool paid for the tiles (%.2f -> %.2f units)" % [pool_before, _units_in(water, 40, 64, 152)])
	# Slide down it.
	player.state_machine.transition_to(&"Fall")
	player.global_position = origin + Vector2(76.0, 83.5)
	player.velocity = Vector2.ZERO
	var slid: bool = false
	var fastest: float = 0.0
	for frame: int in 40:
		await get_tree().physics_frame
		slid = slid or player.state_machine.current_state.name == &"Sliding"
		fastest = maxf(fastest, player.velocity.length())
	_check(slid and fastest > 100.0, "you slide down the frozen trail (top speed %.0f px/s)" % fastest)
	await _wait_for_respawn(player)

	# Through the hands: raise a snake from the plateau pool, draw it, freeze it.
	await _stand_at(player, origin + Vector2(24.0, 96.0))
	room.reset_objects()
	await _wait_until_calm(water)
	var saved_trigger: WaterTuning.SnakeTrigger = tuning.snake_trigger
	tuning.snake_trigger = WaterTuning.SnakeTrigger.KEY
	books = water.get_books_units()
	await _start_hold(player)
	await _steer_ball_until([&"move_right", &"move_down"], func() -> bool:
		return hands.ball_position.x > origin.x + 44.0 and hands.ball_position.y > origin.y + 104.0, 2.0)
	await _steer_ball_until([], func() -> bool: return hands.ball_units >= 1.0, 1.0)
	Input.action_press(&"water_snake")
	# Up to y 72: a 24 px run from the surface (y 96), 3 tiles. (It stopped at 76 once:
	# 20 px, halfway between 2 and 3 tiles, so a tiny drift changed the plan.)
	await _steer_ball_until([&"move_up"], func() -> bool: return hands.ball_position.y < origin.y + 72.0, 2.0)
	Input.action_release(&"water_snake")
	await _steer_ball_until([&"move_right"], func() -> bool: return hands.ball_position.x > origin.x + 76.0, 2.0)
	# Stop the ball: drifting on, its trail (and the ghost) would grow before 2 lands.
	hands.ball_velocity = Vector2.ZERO
	for frame: int in 3:
		await get_tree().process_frame
	var hand_plan: IcePlan = hands.plan
	_check(hands.snake != null and hand_plan != null and hand_plan.kind == IcePlan.Kind.TRAIL and not hand_plan.is_empty(),
		"a held snake's ghost is its trail's tiles (snake %s, %d cells)" % [hands.snake != null, hand_plan.cells.size() if hand_plan != null else 0])
	var hand_cells: Array[Vector2i] = hand_plan.get_free_cells() if hand_plan != null else []
	player.freeze.cooldown_remaining = 0.0
	await _press(&"water_freeze")
	Input.action_release(&"water_hands")
	var all_there: bool = not hand_cells.is_empty()
	for cell: Vector2i in hand_cells:
		all_there = all_there and layer.has_ice(cell)
	_check(not hands.is_holding() and all_there and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"2 freezes the snake into exactly those tiles, books balanced (holding %s, cells %s, ice now %s, books %.3f -> %.3f)"
			% [hands.is_holding(), hand_cells, layer.cell_freeze.keys(), books, water.get_books_units()])
	tuning.snake_trigger = saved_trigger
	await _wait_for_respawn(player)

	# A 45° slope from the shelf pool down to the ground sends the crate onto the plate.
	room.reset_objects()
	await _wait_until_calm(water)
	var shelf_trail: IcePlan = IcePlan.for_trail(water, PackedVector2Array([Vector2(275.0, 112.0),
		Vector2(275.0, 104.0), Vector2(288.0, 104.0), Vector2(312.0, 128.0)]))
	water.apply_ice_plan(shelf_trail, Vector2(300.0, 116.0), 0.0, 0.0, Vector2(275.0, 112.0))
	_check(layer.has_ice(Vector2i(34, 13)) and layer.has_ice(Vector2i(36, 13)) and layer.has_ice(Vector2i(38, 15)),
		"the shelf's trail fills the pool's mouth and runs down to the ground")
	var crate: Crate = room.get_node("SlideCrate") as Crate
	var plate: PressurePlate = room.get_node("SlidePlate") as PressurePlate
	crate.receive_gust(Vector2.RIGHT, 300.0)
	var crate_fastest: float = 0.0
	for frame: int in 240:
		await get_tree().physics_frame
		crate_fastest = maxf(crate_fastest, crate.velocity.length())
		if plate.is_on():
			break
	_check(plate.is_on(), "gusted along the shelf, the crate slides down the ice onto the plate (top %.0f px/s, crate x %.0f)"
		% [crate_fastest, crate.global_position.x - origin.x])
	room.reset_objects()

	# --- Water G: the waterfall wall and a raft on clean water.
	room = world.get_node("RoomWaterG") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	water = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(GameState.current_room == room and water != null, "room Water G is the current room, with water")
	if water == null:
		return
	origin = room.global_position
	layer = water.ice_layer
	await _stand_at(player, origin + Vector2(40.0, 128.0))
	for frame: int in 90:
		await get_tree().physics_frame  # the fall reaches the basin
	var source: WaterSource = room.get_node("WaterfallSource") as WaterSource
	_check(water.find_waterfall_at(Vector2(84.0, 100.0), 8.0) == source, "a ball in the falling water is in the waterfall")
	var wall: IcePlan = IcePlan.for_wall(water, source)
	var one_column: bool = wall.kind == IcePlan.Kind.WALL and wall.get_free_cells().size() >= 12
	for cell: Vector2i in wall.cells:
		one_column = one_column and cell.x == 10
	_check(one_column and not wall.is_brittle, "the ghost is one tall column from the spout down (%d cells)" % wall.cells.size())
	books = water.get_books_units()
	water.apply_ice_plan(wall, Vector2(84.0, 100.0), 0.0)
	var mouth: Vector2 = water.to_local(source.global_position)
	_check(water.is_point_in_ice(mouth + Vector2(0.0, WaterSource.FROZEN_CHECK_BELOW))
		and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"freezing it makes an ice wall up to the spout (books balanced)")
	var sourced_before: float = water.sourced_area
	for frame: int in 60:
		await get_tree().physics_frame
	_check(absf(water.sourced_area - sourced_before) < 0.01, "the spout stops while the wall stands")
	Flammable.ignite_near(get_tree(), water.to_global(Vector2(84.0, 100.0)), 2.0, null)
	for frame: int in 60:
		await get_tree().physics_frame
	_check(not water.is_point_in_ice(mouth + Vector2(0.0, WaterSource.FROZEN_CHECK_BELOW)) and water.sourced_area > sourced_before + 1.0,
		"fire melts the wall and the waterfall starts again")

	# A raft on the clean pool.
	room.reset_objects()
	await _wait_until_calm(water)
	var raft_plan: IcePlan = IcePlan.for_ball(water, Vector2(256.0, 130.0), 4.0 * unit, 8.0)
	_check(raft_plan.kind == IcePlan.Kind.RAFT and absf(raft_plan.raft_rect.size.x - 32.0) < 0.5,
		"a ball resting on a clean pool's surface plans a 32 px raft (%s)" % raft_plan.raft_rect)
	_inject_held(water, 4.0 * unit)
	books = water.get_books_units()
	water.apply_ice_plan(raft_plan, Vector2(256.0, 130.0), 4.0 * unit)
	var raft: IceRaft = water.rafts.back() if not water.rafts.is_empty() else null
	_check(raft != null and absf(raft.water_area - 4.0 * unit) < 0.01 and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"freezing it makes a raft holding the 4 units")
	if raft != null:
		for frame: int in 90:
			await get_tree().physics_frame
		var raft_bottom: float = raft.global_position.y - origin.y
		_check(raft_bottom > 136.0 and raft_bottom < 136.0 + tuning.raft_thickness, "it floats at the clean pool's surface (bottom y %.1f)" % raft_bottom)
		# SAILING (after the grid-ice play-test): a diagonal gust on it. From the pool's
		# left part (it's 160 px wide; a hop goes ~75 px), hop right, then dive back left.
		raft.global_position.x = origin.x + 216.0
		raft.velocity = Vector2.ZERO
		player.state_machine.transition_to(&"Fall")
		player.global_position = Vector2(raft.global_position.x, raft.global_position.y - raft.crate_size.y - 0.5)
		player.velocity = Vector2.ZERO
		for frame: int in 40:
			await get_tree().physics_frame
		_check(player.get_floor_body() == raft, "you stand on the clean raft")
		var hop: Dictionary = await _sail(player, raft, [&"move_left", &"move_down"])
		_check(hop.rise > 12.0 and hop.raft_rise > 8.0 and hop.forward > 16.0 and hop.max_gap < 6.0,
			"gusting down-left on it hops you and the raft up and right together (%s)" % hop)
		_check(hop.landed, "you land back on the raft")
		_check(hop.lowest_feet - origin.y < 136.0 + tuning.black_kill_depth,
			"landing from the hop, your feet don't sink deeper than black water allows (lowest %.1f, surface 136)"
				% (hop.lowest_feet - origin.y))
		# The raft keeps its speed now (after the second sailing play-test): stopped first,
		# or the hop's speed to the right would cancel the dive's push left.
		raft.velocity.x = 0.0
		var dive: Dictionary = await _sail(player, raft, [&"move_right", &"move_up"])
		_check(dive.lowest_head - origin.y > 136.0 and dive.forward < -16.0 and dive.landed,
			"gusting up-right dives: the raft takes you wholly under and left, then back up on it (%s)" % dive)
		# A neutral gust in the air GRIPS the landing (after the sailing play-test): falling
		# onto the raft at run speed you stop dead on its deck instead of sliding off.
		# The raft held still under you (the dive left it drifting: it slid out from under
		# the air cushion's slow fall).
		raft.global_position.x = origin.x + 216.0
		raft.velocity = Vector2.ZERO
		for frame: int in 30:
			await get_tree().physics_frame
		player.state_machine.transition_to(&"Fall")
		player.global_position = Vector2(raft.global_position.x - 12.0, raft.global_position.y - raft.crate_size.y - 20.0)
		player.velocity = Vector2(player.tuning.max_run_speed, 0.0)
		player.gust.cooldown_remaining = 0.0
		player.gust.refill_charges()
		await _press(&"gust")
		for frame: int in 90:
			await get_tree().physics_frame
		var deck_x: float = player.global_position.x - raft.global_position.x
		for frame: int in 30:
			await get_tree().physics_frame
		_check(player.get_floor_body() == raft and absf(player.global_position.x - raft.global_position.x - deck_x) < 1.0,
			"a neutral gust in the air grips the landing: you stand still on the raft (moved %.1f px on it)"
				% (player.global_position.x - raft.global_position.x - deck_x))
		# STRAIGHT down hops, straight up dives (after the second sailing play-test), and
		# both keep the raft's speed.
		raft.velocity.x = 0.0
		var straight_hop: Dictionary = await _sail(player, raft, [&"move_down"])
		_check(straight_hop.rise > 12.0 and straight_hop.landed and absf(straight_hop.forward) < 8.0,
			"gusting straight down on it hops you and the raft straight up together (%s)" % straight_hop)
		_shift_raft_with_rider(raft, player, origin.x + 216.0)
		raft.velocity.x = 0.0
		for frame: int in 20:
			await get_tree().physics_frame
		var straight_dive: Dictionary = await _sail(player, raft, [&"move_up"])
		_check(straight_dive.lowest_head - origin.y > 136.0 and straight_dive.landed,
			"gusting straight up on it dives you and the raft under and back up (%s)" % straight_dive)
		_shift_raft_with_rider(raft, player, origin.x + 216.0)
		raft.velocity.x = 60.0
		await _wait_on_raft(player, raft)
		var moving_hop: Dictionary = await _sail(player, raft, [&"move_down"])
		_check(moving_hop.forward > 20.0 and moving_hop.landed,
			"hopping off a raft moving right, you two go on right and land on it (%s)" % moving_hop)
		# The diagonal's arrows HELD all along (after the third sailing play-test: the
		# held arrow steered you off the hopping raft, and walked you off its ice deck).
		# (The hop goes right ~80 px, the dive left ~100: each starts where it has room.)
		for aim: Array[StringName] in [[&"move_left", &"move_down"], [&"move_right", &"move_up"]] as Array[Array]:
			_shift_raft_with_rider(raft, player, origin.x + (216.0 if aim[1] == &"move_down" else 300.0))
			raft.velocity.x = 0.0
			await _wait_on_raft(player, raft)
			var aim_arrows: Array[StringName] = []
			aim_arrows.assign(aim)  # a typed array, as _sail wants
			var held: Dictionary = await _sail(player, raft, aim_arrows, true)
			for frame: int in 30:
				await get_tree().physics_frame  # still holding them, standing on it
			var still_on: bool = player.get_floor_body() == raft
			var deck_offset: float = absf(player.global_position.x - raft.global_position.x)
			for action: StringName in aim:
				Input.action_release(action)
			_check(held.landed and held.max_gap < 6.0 and still_on and deck_offset < raft.crate_size.x * 0.5,
				"sailing %s with the arrows held, you stay on the raft (on it %s, %.1f px from its middle, %s)"
					% [aim, still_on, deck_offset, held])
		# MOMENTUM: each sideways gust adds to the raft's speed; a neutral gust brakes it.
		_shift_raft_with_rider(raft, player, origin.x + 216.0)
		raft.velocity.x = 0.0
		for frame: int in 20:
			await get_tree().physics_frame
		var speeds: Array[float] = []
		for arrows: Array[StringName] in [[&"move_left"], [&"move_left"], []] as Array[Array]:
			for frame: int in 20:
				await get_tree().physics_frame  # out of the last gust's recoil
			# Back to the pool's left part, speed kept (at 245 px/s it reaches the wall).
			_shift_raft_with_rider(raft, player, origin.x + 200.0)
			await _wait_on_raft(player, raft)
			player.gust.cooldown_remaining = 0.0
			player.gust.refill_charges()
			for action: StringName in arrows:
				Input.action_press(action)
			await _press(&"gust")
			for action: StringName in arrows:
				Input.action_release(action)
			for frame: int in 2:
				await get_tree().physics_frame
			speeds.append(raft.velocity.x)
		_check(speeds[0] > 60.0 and speeds[1] > speeds[0] + 60.0 and speeds[2] < speeds[1] - 60.0 and speeds[2] > 40.0,
			"two gusts left speed the raft up right, a neutral gust slows it (%s px/s)" % [speeds])
		# Alone on the water, kicked down, it settles in a bob or two (raft_bob_damping:
		# it bounced for seconds).
		player.set_physics_process(false)
		var player_spot: Vector2 = player.global_position
		player.global_position = origin + Vector2(-400.0, -400.0)
		for frame: int in 60:
			await get_tree().physics_frame
		raft.velocity.y = 60.0
		for frame: int in 40:
			await get_tree().physics_frame
		var bob_top: float = INF
		var bob_bottom: float = -INF
		for frame: int in 30:
			await get_tree().physics_frame
			bob_top = minf(bob_top, raft.global_position.y)
			bob_bottom = maxf(bob_bottom, raft.global_position.y)
		_check(bob_bottom - bob_top < 0.5, "kicked, a lone raft settles fast (still bobbing %.2f px after 0.7 s)" % (bob_bottom - bob_top))
		player.global_position = player_spot
		player.set_physics_process(true)
		# ON DRY GROUND it's just ground (after the third sailing play-test): gusting up or
		# down on it neither dives nor hops it.
		raft.global_position = origin + Vector2(40.0, 120.0)
		raft.velocity = Vector2.ZERO
		for frame: int in 40:
			await get_tree().physics_frame
		_check(raft.is_on_floor() and raft.submerged_share == 0.0, "a raft moved onto the dry floor rests there")
		player.state_machine.transition_to(&"Fall")
		player.global_position = Vector2(raft.global_position.x, raft.global_position.y - raft.crate_size.y - 0.5)
		player.velocity = Vector2.ZERO
		await _wait_on_raft(player, raft)
		var land_up: Dictionary = await _sail(player, raft, [&"move_up"])
		var land_down: Dictionary = await _sail(player, raft, [&"move_down"])
		_check(land_up.stood_on_it and land_up.raft_rise < 1.0 and not land_up.dipped
			and land_down.raft_rise < 1.0 and land_down.rise < 4.0 and raft.sail == IceRaft.Sail.NONE,
			"on dry ground, gusting up or down on a raft neither dives nor hops it (up %s, down %s)" % [land_up, land_down])
	room.reset_objects()
	finished_sections.append("Lines")


## Gusts with `arrows` held while standing on `raft`, then watches 90 frames: how high
## you rose (px, from your feet before), how high the raft rose, how far right you
## went, the widest sideways gap between you and the raft while you were in the air,
## whether the raft first dipped, whether you ended up standing on it, and the
## lowest your feet and the top of your head went (global y). `keep_held`: the arrows
## stay pressed afterwards (the caller lets go of them).
func _sail(player: Player, raft: IceRaft, arrows: Array[StringName], keep_held: bool = false) -> Dictionary:
	player.gust.cooldown_remaining = 0.0
	var feet_y: float = player.global_position.y
	var feet_x: float = player.global_position.x
	var raft_y: float = raft.global_position.y
	var result: Dictionary = {"rise": 0.0, "raft_rise": 0.0, "forward": 0.0, "max_gap": 0.0, "dipped": false, "landed": false,
		"lowest_feet": -INF, "lowest_head": -INF}
	result.stood_on_it = player.get_floor_body() == raft
	for action: StringName in arrows:
		Input.action_press(action)
	await _press(&"gust")
	if not keep_held:
		for action: StringName in arrows:
			Input.action_release(action)
	for frame: int in 90:
		await get_tree().physics_frame
		if not is_instance_valid(raft):
			break
		result.lowest_feet = maxf(result.lowest_feet, player.global_position.y)
		result.lowest_head = maxf(result.lowest_head, player.get_hitbox_rect().position.y)
		result.rise = maxf(result.rise, feet_y - player.global_position.y)
		result.raft_rise = maxf(result.raft_rise, raft_y - raft.global_position.y)
		result.dipped = result.dipped or raft.global_position.y > raft_y + 1.0
		if not player.is_on_floor():
			result.max_gap = maxf(result.max_gap, absf(player.get_center().x - raft.global_position.x))
	result.forward = player.global_position.x - feet_x
	result.landed = is_instance_valid(raft) and player.get_floor_body() == raft
	return result


## Waits (up to 30 frames) until `player` stands on `raft`: right after a teleport
## you may not be on its deck yet, and a gust then isn't a sail.
func _wait_on_raft(player: Player, raft: IceRaft) -> void:
	for frame: int in 30:
		await get_tree().physics_frame
		if player.get_floor_body() == raft:
			return


## Moves `raft` to x `raft_x` (global) and `player` standing on it along with it,
## keeping both speeds (moving only the raft could pull it out from under you).
func _shift_raft_with_rider(raft: IceRaft, player: Player, raft_x: float) -> void:
	var shift: float = raft_x - raft.global_position.x
	raft.global_position.x += shift
	player.global_position.x += shift


## The loose drops that aren't black (a slick, room-local) and their water, px².
func _clean_drop_points(water: WaterWorld) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in water.get_drop_count():
		if water.drop_groups[index] != WaterWorld.BLACK_GROUP:
			points.append(water.drop_positions[index])
	return points


func _clean_drop_area(water: WaterWorld) -> float:
	var area: float = 0.0
	for index: int in water.get_drop_count():
		if water.drop_groups[index] != WaterWorld.BLACK_GROUP:
			area += water.drop_areas[index]
	return area


## Puts `area` px² of new water straight into the hands' books (as if gathered),
## counted as sourced so the books don't change: the tests freeze ice without steering
## a ball.
func _inject_held(water: WaterWorld, area: float) -> void:
	water.held_area += area
	water.sourced_area += area


## A raft of `units` units at room-local `center_x` on the surface `surface_y` (as a
## held ball frozen there would make).
func _make_test_raft(water: WaterWorld, center_x: float, surface_y: float, units: float) -> IceRaft:
	var plan: IcePlan = IcePlan.new()
	plan.kind = IcePlan.Kind.RAFT
	plan.raft_area = units * WaterWorld.UNIT_AREA
	plan.raft_rect = water.fit_raft_rect(center_x, surface_y, units * WaterWorld.TILE)
	_inject_held(water, plan.raft_area)
	water.apply_ice_plan(plan, Vector2(center_x, surface_y), plan.raft_area)
	return water.rafts.back() as IceRaft


## Stage W7a in room Water H: black water (kills, can't be gathered or frozen, its
## drops are ink), slicks (clean water floating on black), rafts (from the hands and
## from a slick), riding one (rider weight, gust recoil, jump recoil), and painted
## ice slopes (one glass patch, slide down, launch off the lip over the spikes).
func _check_w7a_black_water(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterH") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water H is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "Water H has a WaterWorld")
	if water == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var origin: Vector2 = room.global_position
	var unit: float = WaterWorld.UNIT_AREA
	await _stand_at(player, origin + Vector2(16.0, 128.0))
	await _wait_until_calm(water)

	# The painted water: two clean pools and two black ones (black tiles don't join
	# the clean patches next to them).
	var black_count: int = 0
	for body: WaterBody in water.bodies:
		if body.is_black:
			black_count += 1
	_check(water.bodies.size() == 4 and black_count == 2,
		"Water H has 2 clean and 2 black pools (%d bodies, %d black)" % [water.bodies.size(), black_count])
	for id: StringName in [&"black_water", &"ice_slope_up_right", &"ice_slope_up_left",
			&"gentle_ice_slope_up_right", &"gentle_ice_slope_up_left"]:
		_check(PaletteCatalog.get_entry(id) != null, "the palette has %s" % id)

	# Black water can't be gathered, drawn into a snake or frozen.
	var channel_point: Vector2 = Vector2(136.0, 148.0)  # room-local, inside the channel
	var books: float = water.get_books_units()
	_check(water.is_black_at(channel_point), "the channel is black water")
	_check(water.gather(channel_point, 6.0, 4.0 * unit) == 0.0, "the ball gathers nothing from black water")
	_check(water.draw_from_body_at(Vector2(136.0, 120.0), unit) == 0.0, "a snake draws nothing from black water")
	var black_plan: IcePlan = IcePlan.for_ball(water, channel_point, 4.0 * unit, 8.0)
	_check(black_plan.kind == IcePlan.Kind.RAFT, "a ball in black water plans a raft: black water itself never freezes")
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "nothing left the books")

	# It kills: the player dropped into the channel dies.
	var deaths_before: int = GameState.death_count
	player.global_position = origin + Vector2(136.0, 150.0)
	player.velocity = Vector2.ZERO
	for frame: int in 10:
		await get_tree().physics_frame
	_check(GameState.death_count == deaths_before + 1, "falling into black water kills (deaths %d -> %d)" % [deaths_before, GameState.death_count])
	await _wait_for_respawn(player)
	await _stand_at(player, origin + Vector2(16.0, 128.0))

	# A SLICK: a ball thrown onto the black pit floats on it, then sinks in and turns black.
	var pit_body: WaterBody = water.find_body_under(Vector2(272.0, 140.0))[0]
	var pit_area_before: float = pit_body.get_area()
	water.throw_ball(Vector2(272.0, 100.0), Vector2.ZERO, 4.0)
	for frame: int in 60:
		await get_tree().physics_frame
	var slick_points: PackedVector2Array = _clean_drop_points(water)
	var lowest: float = -INF
	for point: Vector2 in slick_points:
		lowest = maxf(lowest, point.y)
	var pit_surface: float = pit_body.get_surface_y(pit_body.get_column_at(272.0))
	_check(_clean_drop_area(water) > 3.9 * unit and lowest <= pit_surface + WaterWorld.SLICK_MAX_DEPTH + 0.5,
		"clean water thrown on black floats on it as a slick (%.2f units loose, lowest y %.1f, surface %.1f)"
			% [_clean_drop_area(water) / unit, lowest, pit_surface])
	var min_x: float = INF
	var max_x: float = -INF
	for point: Vector2 in slick_points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	_check(max_x - min_x < 48.0, "the slick stays a lens, not a film over the whole pit (%.0f px wide)" % (max_x - min_x))
	var slick_books: float = water.get_books_units()
	for frame: int in int(tuning.black_slick_time * 60.0) + 30:
		await get_tree().physics_frame
	# Sinking in all at once makes a small wave, and its crest throws a few black drops
	# that may still be in the air: they count with the pit (a drop or two may land on
	# the bank: 0.15 units of slack; the books check says nothing is lost).
	var ink_in_air: float = 0.0
	for index: int in water.get_drop_count():
		if water.drop_groups[index] == WaterWorld.BLACK_GROUP:
			ink_in_air += water.drop_areas[index]
	var pit_gain: float = (pit_body.get_area() + ink_in_air - pit_area_before) / unit
	_check(_clean_drop_area(water) < 0.01 and pit_body.is_black and pit_gain > 3.85
		and absf(water.get_books_units() - slick_books) < CONSERVATION_TOLERANCE,
		"after black_slick_time it sinks in: the pit (and its ink in the air) is black and 4 units fuller (+%.2f), none lost" % pit_gain)

	# A RAFT on the black pit (as a ball set down on it and frozen makes one).
	books = water.get_books_units()
	var pit_raft: IceRaft = _make_test_raft(water, 272.0, pit_body.get_surface_y(pit_body.get_column_at(272.0)), 4.0)
	var expected_width: float = clampf(4.0 * WaterWorld.TILE, tuning.raft_min_width, tuning.raft_max_width)
	_check(absf(pit_raft.crate_size.x - expected_width) < 0.5 and absf(pit_raft.crate_size.y - tuning.raft_thickness) < 0.5,
		"a 4-unit raft is %.0f x %.0f px (%.0f x %.0f)" % [expected_width, tuning.raft_thickness, pit_raft.crate_size.x, pit_raft.crate_size.y])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "the raft holds the ball's water")
	var raft_mid_sum: float = 0.0
	for frame: int in 120:
		await get_tree().physics_frame
		if frame >= 60:
			raft_mid_sum += pit_raft.global_position.y - origin.y - tuning.raft_thickness * 0.5
	# Averaged over a second (it bobs), 1 / raft_buoyancy of it is under (after the
	# W7a play-test: rafts float high, a quarter under).
	var raft_mid: float = raft_mid_sum / 60.0
	var surface_now: float = pit_body.get_surface_y(pit_body.get_column_at(pit_raft.global_position.x - origin.x))
	var under: float = raft_mid + tuning.raft_thickness * 0.5 - surface_now
	var expected_under: float = tuning.raft_thickness / tuning.raft_buoyancy
	_check(absf(under - expected_under) < 1.0,
		"it floats high on the black water: %.1f px under (expected %.1f)" % [under, expected_under])

	# The HANDS: gather from the left pool, steer the ball down onto the black channel,
	# freeze it (2): a raft.
	await _stand_at(player, origin + Vector2(64.0, 128.0))
	var hands: WaterHandsAbility = player.water_hands
	await _start_hold(player)
	_check(hands.is_holding(), "1 starts a hold by the pools")
	await _steer_ball_until([&"move_left", &"move_down"], func() -> bool:
		return hands.ball_position.x < origin.x + 48.0 and hands.ball_position.y > origin.y + 136.0, 2.0)
	await _steer_ball_until([], func() -> bool: return hands.ball_units >= 2.0, 2.0)
	_check(hands.ball_units >= 2.0, "the ball fills from the clean pool (%.2f units)" % hands.ball_units)
	await _steer_ball_until([&"move_right", &"move_up"], func() -> bool:
		return hands.ball_position.x > origin.x + 92.0, 2.0)
	await _steer_ball_until([&"move_down"], func() -> bool:
		return hands.ball_position.y + hands.get_ball_radius() > origin.y + 133.0, 2.0)
	var held_units: float = hands.ball_units
	_check(hands.ball_units >= 2.0, "the ball over the channel still holds its water (%.2f units)" % hands.ball_units)
	books = water.get_books_units()
	player.freeze.cooldown_remaining = 0.0
	var rafts_before: int = water.rafts.size()
	await _press(&"water_freeze")
	var hand_raft: IceRaft = water.rafts.back() if water.rafts.size() > rafts_before else null
	_check(not hands.is_holding() and hand_raft != null,
		"2 freezes the held ball at the black surface into a raft (%s)" % hand_raft)
	Input.action_release(&"water_hands")
	if hand_raft == null:
		return
	var whole_units: float = floorf(held_units + 0.02)
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE
		and absf(hand_raft.water_area - whole_units * unit) < 0.01,
		"the raft holds the ball's %.0f whole units (the rest drips off; it held %.2f)" % [whole_units, held_units])
	for frame: int in 60:
		await get_tree().physics_frame

	# RIDING it: it carries you (pressed down a little), and you don't die.
	# Its height averaged over half a second (it bobs), alone and then with you on it.
	var raft_y_alone: float = 0.0
	for frame: int in 30:
		await get_tree().physics_frame
		raft_y_alone += hand_raft.global_position.y / 30.0
	player.state_machine.transition_to(&"Fall")
	player.global_position = Vector2(hand_raft.global_position.x, hand_raft.global_position.y - hand_raft.crate_size.y - 0.5)
	player.velocity = Vector2.ZERO
	var raft_y_ridden: float = 0.0
	for frame: int in 90:
		await get_tree().physics_frame
		if frame >= 60:
			raft_y_ridden += hand_raft.global_position.y / 30.0 if is_instance_valid(hand_raft) else 0.0
	_check(not player.is_dead() and player.get_floor_body() == hand_raft,
		"you stand on the raft over black water, alive")
	var channel_body: WaterBody = water.find_body_under(water.to_local(hand_raft.global_position))[0]
	var channel_surface: float = channel_body.get_surface_y(channel_body.get_column_at(hand_raft.global_position.x - origin.x))
	_check(player.global_position.y - origin.y < channel_surface - 2.0,
		"your feet stay clear above the black water (feet y %.1f, surface %.1f)" % [player.global_position.y - origin.y, channel_surface])
	# Settled (raft_bob_damping, after the sailing play-test) it rests ~0.4 px lower: the
	# water it pushes aside lifts the channel a little. Undamped it bobbed +-1 px, and
	# the old 0.4 threshold only passed on the average of a bob.
	_check(raft_y_ridden > raft_y_alone + 0.25,
		"your weight presses it down (%.2f px)" % (raft_y_ridden - raft_y_alone))
	# A gust to the LEFT while standing on it: the raft takes the recoil, to the right.
	var raft_x_before: float = hand_raft.global_position.x
	Input.action_press(&"move_left")
	await _press(&"gust")
	Input.action_release(&"move_left")
	for frame: int in 40:
		await get_tree().physics_frame
	var drift: float = hand_raft.global_position.x - raft_x_before
	_check(drift > 16.0 and not player.is_dead() and player.get_floor_body() == hand_raft,
		"gusting left on it pushes the raft right, you on it (%.1f px)" % drift)
	# Jumping off to the right pushes it back to the left.
	hand_raft.velocity = Vector2.ZERO
	Input.action_press(&"move_right")
	for frame: int in 6:
		await get_tree().physics_frame
	await _press(&"jump")
	var recoil: float = hand_raft.velocity.x
	Input.action_release(&"move_right")
	_check(recoil < -5.0, "jumping off pushes the raft back (%.0f px/s)" % recoil)
	await _wait_for_respawn(player)

	# A black DROP is ink: it turns clean water black (then the room is reset).
	var small_pool: WaterBody = water.find_body_under(Vector2(220.0, 140.0))[0]
	_check(not small_pool.is_black, "the small pool starts clean")
	water.spawn_group = WaterWorld.BLACK_GROUP
	water.add_loose_water(Vector2(220.0, 110.0), 0.25)
	water.spawn_group = 0
	for frame: int in 40:
		await get_tree().physics_frame
	_check(small_pool.is_black or water.find_body_under(Vector2(220.0, 140.0))[0].is_black,
		"a black drop landing in clean water turns it black")
	water.reset()
	await _stand_at(player, origin + Vector2(16.0, 128.0))

	# Painted ICE SLOPES: one glass patch; slide from the plateau, launch off the lip.
	var ice_layer: IceLayer = room.get_node("Ice") as IceLayer
	# The water sees a slope tile's real shape, not its square (fix after play-test:
	# a pool beside a slope stopped at the tile tops in a staircase).
	_check(not water.is_solid_px(372.0, 85.0) and water.is_solid_px(372.0, 87.0),
		"to the water, a 22.5 degree slope tile is solid only below its slope line")
	_check(absf(water.floor_below(372.0, 60.0) - 86.0) < 0.01,
		"the floor under a point over the slope is the slope line (%.2f, expected 86)" % water.floor_below(372.0, 60.0))
	water.add_loose_water(Vector2(372.0, 70.0), 1.0)
	for frame: int in 300:
		await get_tree().physics_frame
	var stuck_on_slope: float = 0.0
	for body: WaterBody in water.bodies:
		for column: int in body.get_column_count():
			var column_x: float = body.get_column_left(column)
			if column_x >= 360.0 and column_x < 448.0 and body.depth[column] > 0.05:
				stuck_on_slope += body.depth[column] * body.column_width
	_check(stuck_on_slope < 0.05 * unit and water.get_drop_count() == 0,
		"water poured on the slope runs down it, none stuck on the way (%.3f units left on it)" % (stuck_on_slope / unit))
	water.reset()
	var loops: Array[PackedVector2Array] = ice_layer._trace_patches()
	_check(loops.size() == 1, "the slopes and the ice under them are one outline (%d loops)" % loops.size())
	await _stand_at(player, origin + Vector2(352.0, 80.0))
	_check(player.is_on_floor(), "standing on the plateau")
	Input.action_press(&"move_right")
	var slid: bool = false
	var fastest: float = 0.0
	var cleared: bool = false
	for frame: int in 150:
		await get_tree().physics_frame
		slid = slid or player.state_machine.current_state.name == &"Sliding"
		fastest = maxf(fastest, player.velocity.length())
		if player.global_position.x > origin.x + 552.0 and player.is_on_floor() and not player.is_dead():
			cleared = true
			break
		if player.is_dead():
			break
	Input.action_release(&"move_right")
	print("[WaterSmokeTest] slopes: slid %s, top speed %.0f px/s, x %.0f" % [slid, fastest, player.global_position.x - origin.x])
	_check(slid, "you slide down the painted slopes")
	_check(cleared, "off the ramp you clear the 56 px spike pit (top speed %.0f px/s)" % fastest)
	await _wait_for_respawn(player)
	finished_sections.append("W7a")


## Waits (up to 2 s) until the player is alive and standing again, after a death.
func _wait_for_respawn(player: Player) -> void:
	for frame: int in 120:
		await get_tree().physics_frame
		if not player.is_dead() and player.is_on_floor():
			return


## Steers the held ball into the narrow pool of Water D, right then down past
## local y `depth` (so it rises clear of the crate's pillar), and waits until it's full.
func _dip_and_fill(hands: WaterHandsAbility, origin: Vector2, depth: float) -> void:
	var tuning: WaterTuning = hands.player.water_tuning
	await _steer_ball_until([&"move_right"], func() -> bool: return hands.ball_position.x > origin.x + 72.0, 1.0)
	await _steer_ball_until([&"move_down"], func() -> bool: return hands.ball_position.y > origin.y + depth, 2.0)
	await _steer_ball_until([], func() -> bool: return hands.ball_units >= tuning.ball_max_units - 0.001, 2.0)


## Presses 1 once the player is back on the ledge and settled, and waits until the
## hold has really started (a press is only seen by a state that checks for it).
func _start_hold(player: Player) -> void:
	Input.action_release(&"water_hands")
	for frame: int in 60:
		await get_tree().physics_frame
		if player.is_on_floor() and player.state_machine.current_state.name in [&"Idle", &"Run"]:
			break
	Input.action_press(&"water_hands")
	for frame: int in 10:
		await get_tree().physics_frame
		if player.water_hands.is_holding():
			return


## Holds `actions` (arrows) until `condition` is true or `timeout` REAL seconds pass
## (the hold's slow motion makes physics frames rare), then lets go of them. True if
## the condition came true.
func _steer_ball_until(actions: Array[StringName], condition: Callable, timeout: float) -> bool:
	for action: StringName in actions:
		Input.action_press(action)
	var start_msec: int = Time.get_ticks_msec()
	var met: bool = false
	while Time.get_ticks_msec() - start_msec < int(timeout * 1000.0):
		await get_tree().process_frame
		if condition.call():
			met = true
			break
	for action: StringName in actions:
		Input.action_release(action)
	return met


## The farthest particle inside `area` from their average position, px (0 if none).
func _particle_spread(water: WaterWorld, area: Rect2) -> float:
	var inside: PackedVector2Array = PackedVector2Array()
	for position_px: Vector2 in water.drop_positions:
		if area.has_point(position_px):
			inside.append(position_px)
	if inside.is_empty():
		return 0.0
	var center: Vector2 = Vector2.ZERO
	for position_px: Vector2 in inside:
		center += position_px
	center /= inside.size()
	var farthest: float = 0.0
	for position_px: Vector2 in inside:
		farthest = maxf(farthest, position_px.distance_to(center))
	return farthest


# --- Helpers ----------------------------------------------------------------------

## Waits physics frames until every body sleeps and no drop is falling, or the
## timeout. True if it settled.
func _wait_until_calm(water: WaterWorld) -> bool:
	# The timeout counts physics frames, not real time: a slow machine then waits
	# just as many water steps as a fast one.
	var frames_left: int = roundi(SETTLE_TIMEOUT * Engine.physics_ticks_per_second)
	# At least a few frames, so a body that was just woken gets stepped.
	for frame: int in 3:
		await get_tree().physics_frame
	while frames_left > 0:
		if water.get_awake_count() == 0 and water.get_drop_count() == 0:
			return true
		await get_tree().physics_frame
		frames_left -= 1
	return false


## The §6.5 budget, measured so machine noise can't decide it: BUDGET_ROUNDS times,
## reset the room (and, if `wait_calm`, let it settle), reseed the random numbers so
## every round and every run does the same work, call `make_stress`, and time the
## water step (WaterWorld.last_step_usec, wall clock around the whole step) for
## BUDGET_FRAMES frames. Returns:
##   median_usec: the median of the rounds' average step (what the check judges)
##   round_usec: each round's average; peak_usec: the slowest single frame
##   bodies_usec / drops_usec / cohesion_usec: the split, averaged over all rounds
##   most_drops / fewest_most_drops: the most particles at once, over all rounds and
##     in the round that had the fewest
##   calibration_usec: a fixed GDScript loop timed before the rounds (bigger = this
##     run's machine was slower; compare it between runs to read the numbers)
func _measure_water_step(room: Room, water: WaterWorld, make_stress: Callable, wait_calm: bool) -> Dictionary:
	var calibration_usec: int = _time_calibration_loop()
	var round_usec: Array[float] = []
	var bodies_total: int = 0
	var drops_total: int = 0
	var cohesion_total: int = 0
	var peak_usec: int = 0
	var most_drops: int = 0
	var fewest_most_drops: int = 1 << 30
	for round_index: int in BUDGET_ROUNDS:
		room.reset_objects()
		if wait_calm:
			await _wait_until_calm(water)
		seed(20261028 + round_index)
		make_stress.call()
		var total_usec: int = 0
		var round_most_drops: int = 0
		for frame: int in BUDGET_FRAMES:
			await get_tree().physics_frame
			total_usec += water.last_step_usec
			bodies_total += water.last_bodies_usec
			drops_total += water.last_drops_usec
			cohesion_total += water.last_cohesion_usec
			peak_usec = maxi(peak_usec, water.last_step_usec)
			round_most_drops = maxi(round_most_drops, water.get_drop_count())
		round_usec.append(float(total_usec) / BUDGET_FRAMES)
		most_drops = maxi(most_drops, round_most_drops)
		fewest_most_drops = mini(fewest_most_drops, round_most_drops)
	var sorted_usec: Array[float] = round_usec.duplicate()
	sorted_usec.sort()
	var frames: float = float(BUDGET_ROUNDS * BUDGET_FRAMES)
	return {
		"median_usec": sorted_usec[sorted_usec.size() >> 1],  # >> 1: the middle one
		"round_usec": round_usec,
		"peak_usec": peak_usec,
		"bodies_usec": bodies_total / frames,
		"drops_usec": drops_total / frames,
		"cohesion_usec": cohesion_total / frames,
		"most_drops": most_drops,
		"fewest_most_drops": fewest_most_drops,
		"calibration_usec": calibration_usec,
	}


## One line with everything _measure_water_step found.
func _print_budget(label: String, result: Dictionary, water: WaterWorld) -> void:
	var rounds: PackedStringArray = PackedStringArray()
	for usec: float in result["round_usec"]:
		rounds.append("%.0f" % usec)
	print("[WaterSmokeTest] %s: %.0f us median of %d rounds (%s) (bodies %.0f, drops %.0f, of it cohesion %.0f), %d us peak, up to %d drops, %d bodies; machine check %d us" \
		% [label, result["median_usec"], BUDGET_ROUNDS, ", ".join(rounds), result["bodies_usec"], result["drops_usec"],
		result["cohesion_usec"], result["peak_usec"], result["most_drops"], water.bodies.size(), result["calibration_usec"]])


## Times a fixed bit of GDScript (float math in a loop, about 10 ms on this machine
## at full speed). It does no water work: it only says how fast the machine ran
## GDScript just now, so a slow run can be told apart from slow code.
func _time_calibration_loop() -> int:
	var started_usec: int = Time.get_ticks_usec()
	var total: float = 0.0
	for index: int in 100000:
		total += sqrt(float(index)) * 0.5
	if total < 0.0:
		print(total)  # never: keeps the loop from looking unused
	return Time.get_ticks_usec() - started_usec


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


## A §6.5 budget check: the median must be under BUDGET_USEC, except with a
## debugger attached (`-d`, or run from the editor), which makes all GDScript about
## a third slower (the "machine check" shows it): then the numbers are still printed
## but the check is skipped. The budget is judged in plain runs only.
func _check_budget(median_usec: float, description: String) -> void:
	if EngineDebugger.is_active():
		print("[WaterSmokeTest] SKIP %s: skipped: debugger attached" % description)
		return
	_check(median_usec < BUDGET_USEC, description)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("[WaterSmokeTest] PASS %s" % description)
	else:
		failures += 1
		print("[WaterSmokeTest] FAIL %s" % description)

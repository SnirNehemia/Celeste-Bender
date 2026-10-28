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
	# `-- W3` (any of W1 Swim W2 W3 W4 W5 W6 Ice) runs only those sections: quicker while working on one.
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var sections: Array[String] = ["W1", "Swim", "W2", "W3", "W4", "W5", "W6", "Ice"]
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
	# W4-W6 were built for the W4 rope and the W5 ice that keeps its momentum; the
	# re-planned ice (section Ice) made a trail snake and hanging ice the defaults, so
	# those sections switch the old behaviour back on (both are still F5 options).
	_use_w5_ice(world.player, true)
	if sections.has("W4"):
		await _check_w4_water_snake(world, world.player)
	if sections.has("W5"):
		await _check_w5_freeze(world, world.player)
	if sections.has("W6"):
		await _check_w6_slides(world, world.player)
	_use_w5_ice(world.player, false)
	if sections.has("Ice"):
		await _check_predictable_ice(world, world.player)

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
	fire.global_position = snake.points[floori(WaterSnake.POINT_COUNT / 2.0)]
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

	# A snake whose head goes past the pool's right wall (x 112, out of the ring's
	# reach here, so driven directly): its foot stays on the water, never on rock.
	var surface_y: float = water.to_global(Vector2(0.0, water.get_surface_y_at(Vector2(100.0, 130.0)))).y
	var wall_snake: WaterSnake = WaterSnake.new(water, Vector2(origin.x + 100.0, surface_y), Vector2(origin.x + 100.0, surface_y - 30.0))
	for step: int in 40:
		wall_snake.update(0.05, Vector2(origin.x + 160.0, surface_y - 30.0), Vector2.ZERO)
	var foot_x: float = wall_snake.get_foot().x - origin.x
	_check(foot_x >= 72.0 and foot_x <= 112.0,
		"a snake pulled past the pool's wall keeps its foot on the water (foot x %.1f)" % foot_x)
	# Its straight line from the foot to the head crosses the wall and pillar: the
	# rope bends over them instead.
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	var points_in_rock: int = 0
	for point: Vector2 in wall_snake.points:
		query.position = point
		if not water.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty():
			points_in_rock += 1
	var middle: Vector2 = wall_snake.points[floori(WaterSnake.POINT_COUNT / 2.0)]
	var straight_y: float = lerpf(wall_snake.get_foot().y, wall_snake.get_head().y, 0.5)
	_check(points_in_rock == 0 and middle.y < straight_y - 2.0,
		"its rope drapes over the rim, not through it (%d points in rock; middle y %.1f, straight line %.1f)"
			% [points_in_rock, middle.y - origin.y, straight_y - origin.y])
	wall_snake.release(Vector2.ZERO)

	# Held still with the pillar (a thin wall) between the head and its pool, with
	# frame times as uneven as the slow motion's (play-test 4: it jittered there):
	# once settled, the rope stays put.
	var still_head: Vector2 = Vector2(origin.x + 138.0, origin.y + 118.0)
	var shake_snake: WaterSnake = WaterSnake.new(water, Vector2(origin.x + 104.0, surface_y), still_head)
	var frame_times: Array[float] = [0.008, 0.05, 0.02, 0.033]
	for step: int in 120:
		shake_snake.update(frame_times[step % frame_times.size()], still_head, Vector2.ZERO)
	var max_shake: float = 0.0
	for step: int in 40:
		var before: PackedVector2Array = shake_snake.points.duplicate()
		shake_snake.update(frame_times[step % frame_times.size()], still_head, Vector2.ZERO)
		for index: int in WaterSnake.POINT_COUNT:
			max_shake = maxf(max_shake, before[index].distance_to(shake_snake.points[index]))
	var shake_in_rock: int = 0
	for point: Vector2 in shake_snake.points:
		query.position = point
		if not water.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty():
			shake_in_rock += 1
	print("[WaterSmokeTest] snake over the pillar: shake %.2f px, %d points in rock, length %.1f" % [max_shake, shake_in_rock, shake_snake.length])
	_check(max_shake < 0.5 and shake_in_rock == 0,
		"held still over a thin wall, the snake doesn't jitter (moves at most %.2f px a frame, %d points in rock)"
			% [max_shake, shake_in_rock])
	shake_snake.release(Vector2.ZERO)
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


## Stage W5: freeze and ice (Water_bending.md §5.3, §7, refined in the W5 planning),
## in room Water E. Room-local layout: ground top y 128; the small pool x 40-72
## (floor 152); the pool x 192-264 (floor 152, surface 128), an ice rim x 264-272 and
## the spike pit x 272-336; the narrow pool x 352-384 (floor 168) by the shelf (top y 64); painted
## ice x 456-520; the channel x 528-624 (floor 136) under the source (x 572, y 16),
## drained at x 608-624.
func _check_w5_freeze(world: RoomManager, player: Player) -> void:
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
	var freeze: FreezeAbility = player.freeze
	var hands: WaterHandsAbility = player.water_hands
	var origin: Vector2 = room.global_position
	_check(_action_has_key("water_freeze", KEY_2), "water_freeze is on 2")
	await _stand_at(player, origin + Vector2(24.0, 128.0))
	await _wait_until_calm(water)

	# Rule 2: the last throw, while live, freezes at once, keeping its momentum. (The
	# debug throw makes NEW water: the books are read after it.) Thrown left over the
	# ledge, it lands on the ledge's top.
	var throw_velocity: Vector2 = Vector2(-90.0, -60.0)
	water.throw_ball(Vector2(186.0, 64.0), throw_velocity, 4.0)
	var books: float = water.get_books_units()
	await get_tree().physics_frame
	_check(freeze.is_last_throw_live(), "a ball just thrown is live (2 would freeze it)")
	var freezes_before: int = water.freeze_count
	await _press(&"water_freeze")
	var block: IceBlock = water.last_ice as IceBlock
	_check(water.freeze_count == freezes_before + 1 and block != null,
		"2 freezes the live throw into an ice block (%s)" % water.last_ice)
	if block != null:
		_check(absf(block.water_area / WaterWorld.UNIT_AREA - 4.0) < 0.01 and not block.is_long
			and block.crate_size.x > 12.0 and block.crate_size.x < 26.0
			and absf(block.crate_size.x - block.crate_size.y) < 5.0 and block.outlines.size() == 1,
			"the block holds the ball's 4 units in the ball's round shape (%.2f units, %s px, %d outline)"
				% [block.water_area / WaterWorld.UNIT_AREA, block.crate_size, block.outlines.size()])
		_check(block.velocity.x < throw_velocity.x * 0.6,
			"the block flies on with the ball's momentum (%.0f px/s)" % block.velocity.x)
	_check(water.get_group_loose_area(water.last_group_id) == 0.0 and not freeze.is_last_throw_live(),
		"nothing of the frozen throw is loose or live any more")
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the books count the ice (%.3f -> %.3f, ice %.2f units)" % [books, water.get_books_units(), water.ice_area / WaterWorld.UNIT_AREA])
	for frame: int in 60:
		await get_tree().physics_frame
	_check(is_instance_valid(block) and block.is_on_floor(), "the block lands and stays a block")

	# The live window closes: freeze_live_time later, 2 throws a crystal instead.
	water.throw_ball(Vector2(60.0, 60.0), Vector2(0.0, -40.0), 1.0)
	_check(freeze.is_last_throw_live(), "a second throw is live")
	books += 1.0  # that throw's new water
	var waited: float = 0.0
	while waited < tuning.freeze_live_time + 0.1:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_check(not freeze.is_last_throw_live(), "after %.1f s it isn't live any more" % tuning.freeze_live_time)
	freeze.last_crystal = null
	freeze.cooldown_remaining = 0.0
	await _press(&"water_freeze")
	for frame: int in 10:
		await get_tree().physics_frame
		if freeze.last_crystal != null:
			break
	_check(freeze.last_crystal != null, "with nothing live, a tap of 2 throws an ice crystal")

	# Rule 1, with the real keys: a ball in the hands freezes where it is.
	await _stand_at(player, origin + Vector2(36.0, 128.0))
	player.facing_direction = 1.0
	await _start_hold(player)
	await _steer_ball_until([&"move_down"], func() -> bool: return hands.ball_units >= 1.0, 2.0)
	var held_units: float = hands.ball_units  # it may still gather a little before 2 lands
	freeze.cooldown_remaining = 0.0
	Input.action_press(&"water_freeze")
	for frame: int in 20:
		await get_tree().physics_frame
		if not hands.is_holding():
			break
	Input.action_release(&"water_freeze")
	Input.action_release(&"water_hands")
	_check(not hands.is_holding() and water.last_ice is IceBlock
		and (water.last_ice as IceBlock).water_area / WaterWorld.UNIT_AREA >= held_units - 0.001,
		"2 while holding freezes the ball into a block and ends the hold (%.2f units held, %s)" % [held_units, water.last_ice])
	_check(water.held_area < 0.01 and absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE,
		"the frozen ball's water left the hands, the books balance")

	# The crystal freezes a stretch of the big pool into a sheet.
	water.wake_all()
	await _wait_until_calm(water)
	var crystal: IceCrystal = IceCrystal.launch(room, origin + Vector2(184.0, 112.0), Vector2(1.0, 0.5).normalized(), tuning)
	var sheet_ice: Array[Node] = []
	crystal.froze.connect(func(ice: Node) -> void: sheet_ice.append(ice))
	for frame: int in 30:
		await get_tree().physics_frame
	var sheet: IcePiece = null if sheet_ice.is_empty() else sheet_ice[0] as IcePiece
	_check(sheet != null and sheet.is_sheet, "a crystal into the pool freezes a sheet on it (%s)" % [sheet_ice])
	if sheet == null or not sheet.is_sheet:
		return
	print("[WaterSmokeTest] sheet: %s, %.2f units" % [sheet.sheet_rect, sheet.water_area / WaterWorld.UNIT_AREA])
	_check(sheet.sheet_rect.size.x >= 64.0 and sheet.sheet_rect.end.x <= 264.5
		and absf(sheet.sheet_rect.position.y - 128.0) < 2.0,
		"the sheet covers the pool's surface (x %.0f-%.0f, top y %.1f)"
			% [sheet.sheet_rect.position.x, sheet.sheet_rect.end.x, sheet.sheet_rect.position.y])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "the sheet's water is in the books")
	var under: Array = water.find_body_under(Vector2(230.0, 140.0))
	_check(not under.is_empty() and (under[0] as WaterBody).ceiling_y[under[1]] >= sheet.sheet_rect.end.y - 0.5,
		"the water under the sheet has the sheet as its ceiling")

	# Ice ground: speeding up is slow (about 3 s to run speed, after the first W5
	# play-test), so the speed for the long jump comes from elsewhere: here a shove
	# like a gust's, which the ice keeps. Then jump the spike pit off its end.
	await _stand_at(player, origin + Vector2(200.0, 128.0))
	var on_ice_seen: bool = false
	Input.action_press(&"move_right")
	for frame: int in 60:
		await get_tree().physics_frame
		on_ice_seen = on_ice_seen or player.is_on_ice
		if player.global_position.x > origin.x + 250.0:
			break
	Input.action_release(&"move_right")
	var speed_after_second: float = player.velocity.x
	_check(on_ice_seen and speed_after_second < 45.0,
		"speeding up on ice is slow (%.0f px/s after a second, run speed %.0f)" % [speed_after_second, player.tuning.max_run_speed])
	await _stand_at(player, origin + Vector2(196.0, 128.0))
	player.velocity.x = 140.0  # as a gust shove would leave it
	var fastest: float = 0.0
	var jumped: bool = false
	var landed_x: float = -1.0
	Input.action_press(&"move_right")
	for frame: int in 180:
		await get_tree().physics_frame
		fastest = maxf(fastest, player.velocity.x)
		if not jumped and player.global_position.x > origin.x + 268.0:
			jumped = true
			Input.action_press(&"jump")
		if jumped and player.is_on_floor() and player.global_position.x > origin.x + 272.0:
			landed_x = player.global_position.x - origin.x
			break
		if player.is_dead():
			break
	Input.action_release(&"jump")
	Input.action_release(&"move_right")
	print("[WaterSmokeTest] ice run: fastest %.1f px/s, landed at x %.1f, dead %s" % [fastest, landed_x, player.is_dead()])
	_check(on_ice_seen, "standing on the sheet counts as ice")
	_check(fastest > player.tuning.max_run_speed + 15.0,
		"the ice keeps speed past run speed (%.0f px/s, run speed %.0f)" % [fastest, player.tuning.max_run_speed])
	_check(landed_x > 332.0 and not player.is_dead(),
		"a long jump off the ice clears the spike pit (landed at x %.0f)" % landed_x)
	if player.is_dead():
		for frame: int in 90:
			await get_tree().physics_frame

	# Painted ice is ice too.
	await _stand_at(player, origin + Vector2(488.0, 128.0))
	_check(player.is_on_ice, "the painted Ice layer counts as ice")

	# A snake frozen in the hands becomes a pillar in its pool; melting it refills
	# the pool. (Driven through the WaterWorld: W4 checks raising snakes by keys.)
	var pool_before: float = _units_in(water, 352, 384, 168)
	var snake_area: float = water.draw_from_body_at(Vector2(368.0, 140.0), 4.0 * WaterWorld.UNIT_AREA)
	var ball_area: float = water.draw_from_body_at(Vector2(368.0, 140.0), 2.0 * WaterWorld.UNIT_AREA)
	var dots: PackedVector2Array = PackedVector2Array()
	for index: int in 32:
		dots.append(Vector2(368.0 + randf_range(-1.5, 1.5), 130.0 - index * 2.0))
	var pillar: IcePiece = water.freeze_held(Vector2(368.0, 66.0), ball_area, true, snake_area, dots) as IcePiece
	_check(pillar != null and not pillar.is_sheet and water.held_area < 0.01,
		"a snake frozen in the hands is a static pillar (%s)" % pillar)
	await get_tree().physics_frame
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.position = origin + Vector2(368.0, 100.0)
	_check(not water.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty(),
		"the pillar is solid")
	await get_tree().physics_frame
	var pool_frozen: float = _units_in(water, 352, 384, 168)
	water.melt_ice(pillar)
	for frame: int in 150:
		await get_tree().physics_frame
	var pool_after: float = _units_in(water, 352, 384, 168)
	_check(pool_after > pool_before - 0.3 and pool_frozen < pool_before - 5.0,
		"a melted pillar refills its pool (%.2f -> %.2f frozen -> %.2f)" % [pool_before, pool_frozen, pool_after])
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "the books balance after the melt")

	# A block dropped hard into the pool hits its floor but doesn't shatter: water
	# breaks the fall (first W5 play-test: blocks under water turned to water).
	var sunk_block: IceBlock = water.make_ice_block(Vector2(368.0, 60.0), WaterWorld.UNIT_AREA, Vector2(0.0, 250.0)) as IceBlock
	books += 1.0  # made from nothing
	for frame: int in 90:
		await get_tree().physics_frame
	_check(is_instance_valid(sunk_block) and water.player_ice.has(sunk_block),
		"a block dropped into a pool stays ice")
	if is_instance_valid(sunk_block):
		water.melt_ice(sunk_block)

	# A long piece (a frozen ribbon) keeps the water's momentum, then lies still where
	# it lands.
	var ribbon_points: PackedVector2Array = PackedVector2Array()
	var ribbon_areas: PackedFloat32Array = PackedFloat32Array()
	var ribbon_velocities: PackedVector2Array = PackedVector2Array()
	for index: int in 24:
		ribbon_points.append(Vector2(470.0 + index * 1.5, 60.0 - index * 0.8))
		ribbon_areas.append(4.0)
		ribbon_velocities.append(Vector2(80.0, -40.0))
	var ribbon: IceBlock = water.freeze_particles(ribbon_points, ribbon_areas, ribbon_velocities) as IceBlock
	books += 96.0 / WaterWorld.UNIT_AREA
	_check(ribbon != null and ribbon.is_long and ribbon.velocity.x > 60.0,
		"a frozen ribbon is long ice that flies on (%s, %.0f px/s)" % [ribbon, ribbon.velocity.x if ribbon != null else 0.0])
	for frame: int in 120:
		await get_tree().physics_frame
	_check(is_instance_valid(ribbon) and ribbon.is_on_floor() and absf(ribbon.velocity.x) < 1.0,
		"it lands and lies still")
	if is_instance_valid(ribbon):
		water.melt_ice(ribbon)

	# A throw that has split into two blobs freezes into two pieces, each moving with
	# its own water, counted as one freeze for the ice cap (play-test 5).
	var split_points: PackedVector2Array = PackedVector2Array()
	var split_areas: PackedFloat32Array = PackedFloat32Array()
	var split_velocities: PackedVector2Array = PackedVector2Array()
	for index: int in 16:
		var offset: Vector2 = Vector2.from_angle(index * 2.39996) * 4.0 * sqrt((index + 0.5) / 16.0)
		split_points.append(Vector2(470.0, 40.0) + offset)
		split_velocities.append(Vector2(-60.0, 0.0))
		split_points.append(Vector2(500.0, 40.0) + offset)
		split_velocities.append(Vector2(60.0, 0.0))
		split_areas.append(4.0)
		split_areas.append(4.0)
	var freezes_before_split: int = water.get_ice_freeze_count()
	water.freeze_particles(split_points, split_areas, split_velocities)
	books += 128.0 / WaterWorld.UNIT_AREA
	var split_pieces: Array[Node] = water.last_freeze_pieces.duplicate()
	_check(split_pieces.size() == 2 and water.get_ice_freeze_count() == freezes_before_split + 1
		and (split_pieces[0] as IceBlock).velocity.x * (split_pieces[1] as IceBlock).velocity.x < 0.0,
		"two separate blobs freeze into two pieces moving their own ways, one freeze (%d pieces)" % split_pieces.size())
	for piece: Node in split_pieces:
		water.melt_ice(piece)

	# Painted ice is drawn as glass: one outline for the strip of painted tiles.
	var ice_layer: IceLayer = room.get_node("Ice") as IceLayer
	_check(ice_layer.look != null and ice_layer.look.bodies.size() >= 1 and ice_layer.self_modulate.a == 0.0,
		"painted ice draws in the glass look (%d outlines)" % (ice_layer.look.bodies.size() if ice_layer.look != null else 0))

	# Fire melts ice (the Flammable contract): a block lit by a fire melts into water.
	var fire_block: IceBlock = water.make_ice_block(Vector2(420.0, 40.0), 0.0, Vector2.ZERO) as IceBlock
	# (0 water: only the contract is tested here; the books are checked elsewhere.)
	Flammable.try_ignite(fire_block, null)
	_check(not is_instance_valid(fire_block) or not water.player_ice.has(fire_block),
		"fire melts an ice block (Flammable.ignite)")

	# A block that falls far shatters into loose water.
	var high_block: IceBlock = water.make_ice_block(Vector2(488.0, 20.0), WaterWorld.UNIT_AREA, Vector2.ZERO) as IceBlock
	books += 1.0  # that block was made from nothing (no water was frozen for it)
	for frame: int in 90:
		await get_tree().physics_frame
	_check(not is_instance_valid(high_block) or not water.player_ice.has(high_block),
		"a block dropped %.0f px shatters" % (128.0 - 20.0))
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "the books balance after it shatters")

	# The waterfall fills the channel first: a stream runs to the drain.
	for frame: int in 240:
		await get_tree().physics_frame
	# The waterfall: a crystal into the falling water freezes a column of it.
	var fall_crystal: IceCrystal = IceCrystal.launch(room, origin + Vector2(540.0, 70.0), Vector2.RIGHT, tuning)
	var fall_ice: Array[Node] = []
	var fall_kind: Array[String] = []
	fall_crystal.froze.connect(func(ice: Node) -> void:
		fall_ice.append(ice)
		fall_kind.append("%s %s" % [ice.get_class(), ice.get_script().get_global_name()]))
	for frame: int in 30:
		await get_tree().physics_frame
	var column: IceBlock = null
	if not fall_ice.is_empty() and is_instance_valid(fall_ice[0]):
		column = fall_ice[0] as IceBlock
	_check(column != null and column.is_long and column.crate_size.y > column.crate_size.x * 2.0,
		"a crystal into the waterfall freezes an ice column (%s, %s px)" % [fall_kind, column.crate_size if column != null else Vector2.ZERO])
	# Melted again (it reaches the spout and would stop the pour), for the stream.
	if column != null:
		water.melt_ice(column)
	for frame: int in 120:
		await get_tree().physics_frame

	# The stream: freeze a stretch of the channel through: the water backs up behind
	# the dam.
	books = water.get_books_units()  # the source has poured since (sourced water is in the books' formula)
	var dam: IcePiece = water.freeze_body_at(Vector2(592.0, 134.0)) as IcePiece
	_check(dam != null and dam.is_sheet, "the channel freezes (%s)" % dam)
	var frozen_through: bool = false
	if dam != null:
		var dam_found: Array = water.find_body_under(Vector2(592.0, 130.0))
		frozen_through = not dam_found.is_empty() \
			and (dam_found[0] as WaterBody).ceiling_y[dam_found[1]] >= (dam_found[0] as WaterBody).floor_y[dam_found[1]] - WaterBody.FROZEN_GAP
	_check(frozen_through, "the shallow stream freezes to its floor: a dam")
	var upstream_before: float = _units_in(water, 528, 576, 136)
	for frame: int in 120:
		await get_tree().physics_frame
	var upstream_after: float = _units_in(water, 528, 576, 136)
	var downstream: float = _units_in(water, 612, 624, 136)
	_check(upstream_after > upstream_before + 0.5 and downstream < 0.2,
		"the water backs up behind the dam (upstream %.2f -> %.2f, below it %.2f)" % [upstream_before, upstream_after, downstream])

	# Ice over the spout's mouth stops the pour.
	var cap_spine: PackedVector2Array = PackedVector2Array([Vector2(572.0, 18.0), Vector2(572.0, 40.0)])
	water.held_area += WaterWorld.UNIT_AREA  # the plug's water, from nowhere: taken back below
	water.make_ice_shape(cap_spine, WaterWorld.UNIT_AREA)
	water.held_area -= WaterWorld.UNIT_AREA
	var sourced_before: float = water.sourced_area
	for frame: int in 30:
		await get_tree().physics_frame
	_check(water.sourced_area == sourced_before, "ice at the spout's mouth stops the waterfall")

	# The ice cap: making more than max_player_ice pieces melts the oldest.
	# (The room already holds several pieces, so max_player_ice more must melt it.)
	var oldest: Node = water.player_ice[0]
	for piece: int in tuning.max_player_ice:
		water.make_ice_block(Vector2(100.0, 40.0 - piece * 10.0), 0.0, Vector2.ZERO)
	_check(water.get_ice_freeze_count() == tuning.max_player_ice and not water.player_ice.has(oldest),
		"the ice cap holds %d freezes: a new one melted the oldest" % tuning.max_player_ice)

	# Reset: every piece of ice goes.
	room.reset_objects()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ice_left: int = get_tree().get_nodes_in_group(IceBlock.ICE_GROUP).filter(
		func(node: Node) -> bool: return node is IceBlock or node is IcePiece).size()
	_check(water.player_ice.is_empty() and water.ice_area == 0.0 and ice_left == 0,
		"a reset clears all ice (%d pieces left)" % ice_left)
	finished_sections.append("W5")


## Stage W6: ice slides and pins (Water_bending.md §7.2, §16 "Planned in Stage W6"),
## in room Water F. Room-local layout: ground top y 128; the plateau x 8-56 (top y 96),
## its pool x 56-72 (surface y 96), the wall x 72-80 (top y 96), the slide pins x 80-128
## (tips y 121), the spike pit x 128-192; a pool x 216-232, the step pins x 240-304;
## the shelf x 320-368 (top y 104) with the crate (x 328) and a one-tile pool x 344-352,
## the shelf pins x 368-400, the plate and the door further right.
func _check_w6_slides(world: RoomManager, player: Player) -> void:
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
	var origin: Vector2 = room.global_position
	_check(room.get_node("SlidePins") is IcePins and room.get_node("StepPins") is IcePins,
		"Water F has its pin beds")
	_check(ProjectSettings.get_setting("layer_names/2d_physics/layer_7") == "ice_catch",
		"physics layer 7 is named ice_catch")
	_check(player.state_machine.has_node("Sliding"), "the player has a Sliding state")

	# Pins kill: dropped onto them, the player dies (then respawns on the plateau).
	player.global_position = origin + Vector2(100.0, 110.0)
	player.velocity = Vector2.ZERO
	var died_on_pins: bool = false
	for frame: int in 40:
		await get_tree().physics_frame
		if player.is_dead():
			died_on_pins = true
			break
	_check(died_on_pins, "touching ice pins kills the player")
	await _wait_for_respawn(player)
	await _wait_until_calm(water)

	# A compact block (a frozen ball) dropped on pins is IMPALED: it stops on the
	# tips and stays there, a step.
	var block: IceBlock = water.make_ice_block(Vector2(272.0, 70.0), 4.0 * WaterWorld.UNIT_AREA, Vector2.ZERO) as IceBlock
	for frame: int in 60:
		await get_tree().physics_frame
	var block_bottom: float = block.global_position.y - origin.y if is_instance_valid(block) else -1.0
	_check(is_instance_valid(block) and block.is_impaled and absf(block_bottom - 121.0) < 1.5
		and not block.is_in_group(Pushable.GROUP),
		"a frozen ball dropped on pins sticks on their tips (bottom y %.1f, impaled %s)"
			% [block_bottom, is_instance_valid(block) and block.is_impaled])
	if is_instance_valid(block):
		var block_position: Vector2 = block.global_position
		block.velocity = Vector2(200.0, -100.0)  # as a gust would push it: nothing moves it now
		for frame: int in 20:
			await get_tree().physics_frame
		_check(block.global_position == block_position, "an impaled block doesn't move")
		var block_top: float = block.get_slide_top_y(block.global_position.x)
		await _stand_at(player, Vector2(block.global_position.x, block_top - 0.5))
		_check(player.is_on_floor() and not player.is_dead()
			and absf(player.global_position.y - block_top) < 2.0,
			"you can stand on the impaled block over the pins (feet y %.1f, top y %.1f)"
				% [player.global_position.y - origin.y, block_top - origin.y])

	# A falling frozen RIBBON lying at an angle: the pins catch it at that angle, and
	# a long piece that flat is a SLIDE.
	var ribbon_outline: PackedVector2Array = PackedVector2Array([Vector2(84.0, 40.0), Vector2(124.0, 60.0),
		Vector2(124.0, 66.0), Vector2(84.0, 46.0)])
	var ribbon_outlines: Array[PackedVector2Array] = [ribbon_outline]
	var ribbon: IceBlock = water._make_free_ice(ribbon_outlines, Vector2(104.0, 53.0),
		240.0, Vector2.ZERO, true) as IceBlock
	for frame: int in 60:
		await get_tree().physics_frame
	_check(is_instance_valid(ribbon) and ribbon.is_impaled and ribbon.is_slide
		and absf(ribbon.global_position.y - origin.y - 121.0) < 1.5
		and ribbon.is_in_group(IceBlock.SLIDE_GROUP),
		"a falling frozen ribbon is caught by the pins at its angle, and it's a slide (%.1f deg, bottom y %.1f)"
			% [IceOutline.lying_angle_degrees(ribbon.outlines), ribbon.global_position.y - origin.y])
	var upright: IcePiece = water.make_ice_shape(PackedVector2Array([Vector2(204.0, 126.0), Vector2(206.0, 90.0)]),
		1.5 * WaterWorld.UNIT_AREA) as IcePiece
	_check(upright != null and not upright.is_slide, "a standing pillar is solid, not a slide")
	room.reset_objects()
	for frame: int in 3:
		await get_tree().physics_frame

	# The snake DRAPES over pins: stand on the wall, raise a snake from the pool, lay
	# it down to the right over the pins and freeze it there.
	var saved_trigger: WaterTuning.SnakeTrigger = tuning.snake_trigger
	tuning.snake_trigger = WaterTuning.SnakeTrigger.KEY
	var hands: WaterHandsAbility = player.water_hands
	await _stand_at(player, origin + Vector2(76.0, 96.0))
	await _wait_until_calm(water)
	player.facing_direction = -1.0
	await _start_hold(player)
	await _steer_ball_until([&"move_left", &"move_down"], func() -> bool: return hands.ball_position.y > origin.y + 110.0, 1.5)
	await _steer_ball_until([], func() -> bool: return hands.ball_units >= tuning.ball_max_units - 0.001, 2.0)
	Input.action_press(&"water_snake")
	var raised: bool = await _steer_ball_until([&"move_up"],
		func() -> bool: return hands.snake != null and hands.ball_position.y < origin.y + 84.0, 2.0)
	Input.action_release(&"water_snake")
	await _steer_ball_until([&"move_right"], func() -> bool: return hands.ball_position.x > origin.x + 100.0 or hands.snake == null, 1.5)

	await _steer_ball_until([&"move_down"],
		func() -> bool: return hands.ball_position.y > origin.y + 118.0 or hands.snake == null, 1.5)

	# Let the rope settle on the tips.
	await _steer_ball_until([], func() -> bool: return false, 0.4)
	var snake: WaterSnake = hands.snake
	var lowest_rope: float = -INF
	if snake != null:
		for point: Vector2 in snake.points:
			var local: Vector2 = point - origin
			if local.x > 82.0 and local.x < 126.0:
				lowest_rope = maxf(lowest_rope, local.y)
	print("[WaterSmokeTest] drape: raised %s, snake %s, ball %s, rope lowest y over the pins %.1f, last tear '%s'"
		% [raised, snake != null, hands.ball_position - origin, lowest_rope, hands.last_tear_reason])
	_check(lowest_rope > 112.0 and lowest_rope < 121.5,
		"the held snake's rope drapes over the pin tips (lowest y %.1f over the pins, tips at 121)" % lowest_rope)
	player.freeze.cooldown_remaining = 0.0
	Input.action_press(&"water_freeze")
	for frame: int in 20:
		await get_tree().physics_frame
		if not hands.is_holding():
			break
	Input.action_release(&"water_freeze")
	Input.action_release(&"water_hands")
	tuning.snake_trigger = saved_trigger
	var draped: IcePiece = water.last_ice as IcePiece
	# Its top over the pins, just above the tips (its head's round ball reaches a
	# little below them, as the held ball overlaps a wall it rests against).
	var draped_top: float = draped.get_slide_top_y(origin.x + 100.0) - origin.y if draped != null else -1.0
	_check(draped != null and draped.is_slide and draped_top > 100.0 and draped_top < 121.0,
		"frozen, the draped snake is a slide resting on the pins (%s, %.1f deg, its top over the pins y %.1f)"
			% [water.last_ice, IceOutline.lying_angle_degrees(draped.outlines) if draped != null else -1.0, draped_top])
	room.reset_objects()
	for frame: int in 3:
		await get_tree().physics_frame

	# SLIDING down a slide from the pool over the pins: faster and faster, can't climb.
	var slide: IcePiece = water.make_ice_shape(PackedVector2Array([Vector2(60.0, 86.0), Vector2(124.0, 116.0)]),
		7.0 * WaterWorld.UNIT_AREA) as IcePiece
	_check(slide != null and slide.is_slide, "a snake shape lying at 25 degrees is a slide")
	if slide == null:
		return
	var speed_normal: float = await _slide_speed_at(player, slide, origin, false)
	var speed_belly: float = await _slide_speed_at(player, slide, origin, true)
	print("[WaterSmokeTest] slide speed at x 104: %.0f px/s, belly slide %.0f px/s" % [speed_normal, speed_belly])
	_check(speed_normal > tuning.slide_lean_accel and speed_normal < tuning.slide_max_speed + 1.0,
		"on the slide you slide down by yourself (%.0f px/s 40 px further down)" % speed_normal)
	_check(speed_belly > speed_normal + 5.0, "holding down (the belly slide) is faster (%.0f vs %.0f px/s)" % [speed_belly, speed_normal])
	_check(not player.is_tucked and absf(player.get_hitbox_rect().size.y - 11.0) < 0.01, "standing again after the belly slide")
	# Pressing up the slope (left) doesn't climb it.
	_place_on_slide(player, slide, origin, 96.0)
	Input.action_press(&"move_left")
	var sliding_seen: bool = false
	for frame: int in 20:
		await get_tree().physics_frame
		sliding_seen = sliding_seen or player.state_machine.current_state.name == &"Sliding"
	Input.action_release(&"move_left")
	_check(sliding_seen and player.velocity.x > 0.0, "you can't walk up a slide: it slides you down (%.0f px/s)" % player.velocity.x)
	await _wait_for_respawn(player)

	# Ride it and jump off its end: the slide's speed carries you over the spike pit,
	# which a jump from standing can't clear.
	_place_on_slide(player, slide, origin, 64.0)
	var jumped_at: float = -1.0
	var landed_x: float = -1.0
	for frame: int in 180:
		await get_tree().physics_frame
		if jumped_at < 0.0 and player.global_position.x > origin.x + 112.0 and player.state_machine.current_state.name == &"Sliding":
			jumped_at = player.global_position.x - origin.x
			Input.action_press(&"jump")
		if player.is_dead():
			break
		if jumped_at >= 0.0 and player.global_position.x > origin.x + 140.0 and (player.is_on_floor() or player.swim.is_in_water()):
			landed_x = player.global_position.x - origin.x
			break
	Input.action_release(&"jump")
	_check(jumped_at >= 0.0 and not player.is_dead() and landed_x >= 192.0,
		"a jump off the slide's end clears the spike pit (jumped at x %.0f, landed at x %.0f, dead %s)"
			% [jumped_at, landed_x, player.is_dead()])
	# Stop there (the speed would carry on into the next pin bed).
	player.global_position = origin + Vector2(200.0, 128.0)
	player.velocity = Vector2.ZERO
	await _wait_for_respawn(player)

	# ONE-WAY: from under a slide you jump up through it and land on top.
	room.reset_objects()
	await get_tree().physics_frame
	var low_slide: IcePiece = water.make_ice_shape(PackedVector2Array([Vector2(192.0, 108.0), Vector2(220.0, 112.0)]),
		2.5 * WaterWorld.UNIT_AREA) as IcePiece
	await _stand_at(player, origin + Vector2(205.0, 128.0))
	Input.action_press(&"jump")
	var stood_on_top: bool = false
	for frame: int in 60:
		await get_tree().physics_frame
		if player.is_on_floor() and player.global_position.y < origin.y + 112.0:
			stood_on_top = true
			break
	Input.action_release(&"jump")
	_check(low_slide != null and low_slide.is_slide and stood_on_top,
		"slides are one-way: you jump up through one from below and land on top (feet y %.1f)"
			% (player.global_position.y - origin.y))

	# A RAMP: a slide that curves up at its end launches you.
	room.reset_objects()
	await get_tree().physics_frame
	var ramp: IcePiece = water.make_ice_shape(PackedVector2Array([Vector2(240.0, 70.0), Vector2(284.0, 100.0),
		Vector2(296.0, 98.0), Vector2(304.0, 92.0)]), 7.0 * WaterWorld.UNIT_AREA) as IcePiece
	var launched: bool = false
	if ramp != null:
		_place_on_slide(player, ramp, origin, 246.0)
		var was_sliding: bool = false
		for frame: int in 90:
			await get_tree().physics_frame
			was_sliding = was_sliding or player.state_machine.current_state.name == &"Sliding"
			if was_sliding and not player.is_on_floor() and player.velocity.y < -20.0 and player.global_position.x > origin.x + 285.0:
				launched = true
				break
	_check(ramp != null and launched, "a slide curving up at its end launches you off its lip (vy %.0f)" % player.velocity.y)
	await _wait_for_respawn(player)

	# Things slide too: a crate set on a slide over the shelf pins slides down, off its
	# end and onto the plate: the door opens.
	room.reset_objects()
	await get_tree().physics_frame
	await _stand_at(player, origin + Vector2(24.0, 96.0))
	var crate: Crate = room.get_node("SlideCrate") as Crate
	var plate: PressurePlate = room.get_node("SlidePlate") as PressurePlate
	var crate_slide: IcePiece = water.make_ice_shape(PackedVector2Array([Vector2(350.0, 100.0), Vector2(398.0, 117.0)]),
		4.0 * WaterWorld.UNIT_AREA) as IcePiece
	if crate_slide != null:
		crate.global_position = Vector2(origin.x + 360.0, crate_slide.get_slide_top_y(origin.x + 360.0) - 1.0)
		crate.velocity = Vector2.ZERO
	var crate_max_speed: float = 0.0
	for frame: int in 180:
		await get_tree().physics_frame
		crate_max_speed = maxf(crate_max_speed, crate.velocity.length())
		if plate.is_on():
			break
	print("[WaterSmokeTest] crate down the slide: at x %.0f, top speed %.0f px/s" % [crate.global_position.x - origin.x, crate_max_speed])
	_check(crate_slide != null and crate_max_speed > 60.0 and plate.is_on(),
		"a crate on a slide slides down it and onto the plate, which opens the door (crate x %.0f)"
			% (crate.global_position.x - origin.x))

	room.reset_objects()
	for frame: int in 3:
		await get_tree().physics_frame
	finished_sections.append("W6")


## The re-planned ice (Water_bending.md §16 "Re-planned: predictable ice"), in room
## Water G: frozen water hangs where it froze as one piece, a push makes a compact
## block a puck (it drops straight in the air, glides on ice, stops on rock), and the
## snake is a TRAIL snapped to 22.5° runs that rewinds and freezes in its exact shape.
func _check_predictable_ice(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomWaterG") as Room
	world.jump_to_room(room)
	for frame: int in 30:
		await get_tree().physics_frame
	_check(GameState.current_room == room, "room Water G is the current room")
	var water: WaterWorld = room.get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	_check(water != null, "Water G has a WaterWorld")
	if water == null:
		return
	var tuning: WaterTuning = player.water_tuning
	var freeze: FreezeAbility = player.freeze
	var origin: Vector2 = room.global_position
	_check(tuning.ice_hangs and tuning.snake_shape == WaterTuning.SnakeShape.TRAIL
		and is_equal_approx(tuning.snake_trail_angle_step, 22.5),
		"the defaults: ice hangs, the snake is a trail, runs snap to 22.5 degrees")
	await _stand_at(player, origin + Vector2(24.0, 96.0))
	await _wait_until_calm(water)

	# A live throw frozen in flight HANGS: no momentum, no fall, one piece.
	water.throw_ball(Vector2(208.0, 70.0), Vector2(60.0, -80.0), 4.0)
	var books: float = water.get_books_units()
	for frame: int in 6:
		await get_tree().physics_frame
	freeze.cooldown_remaining = 0.0
	var thrown_ice: Node = freeze.freeze_last_throw()
	var block: IceBlock = thrown_ice as IceBlock
	_check(block != null and block.is_frozen_in_place and water.last_freeze_pieces.size() == 1,
		"the live throw freezes into ONE block frozen in place (%s, %d piece(s))" % [thrown_ice, water.last_freeze_pieces.size()])
	if block == null:
		return
	var hang_position: Vector2 = block.global_position
	for frame: int in 60:
		await get_tree().physics_frame
	_check(is_instance_valid(block) and block.global_position == hang_position,
		"it hangs where it froze (moved %.2f px in 1 s)" % (block.global_position.distance_to(hang_position) if is_instance_valid(block) else -1.0))
	_check(absf(water.get_books_units() - books) < CONSERVATION_TOLERANCE, "the books count the hanging ice")
	var block_top: float = block.get_slide_top_y(block.global_position.x)
	await _stand_at(player, Vector2(block.global_position.x, block_top - 0.5))
	_check(player.is_on_floor() and absf(player.global_position.y - block_top) < 2.0
		and block.global_position == hang_position,
		"you can stand on it in the air and it stays put (feet y %.1f, top y %.1f)"
			% [player.global_position.y - origin.y, block_top - origin.y])
	# Knocked loose in the air: it drops straight down, its sideways push dropped.
	await _stand_at(player, origin + Vector2(24.0, 96.0))
	block.receive_gust(Vector2.RIGHT, 160.0)
	for frame: int in 60:
		await get_tree().physics_frame
	_check(is_instance_valid(block) and not block.is_frozen_in_place and block.is_on_floor()
		and absf(block.global_position.x - hang_position.x) < 0.5,
		"a gust knocks it loose: it falls straight down and lands (x moved %.2f px)"
			% (block.global_position.x - hang_position.x if is_instance_valid(block) else -1.0))

	# PUCKS: freeze the big pool into a sheet, freeze a ball resting on its left end,
	# gust it: it glides along the ice without slowing and stops on the rock past it,
	# on the plate.
	var crystal: IceCrystal = IceCrystal.launch(room, origin + Vector2(328.0, 104.0), Vector2(0.0, 1.0), tuning)
	var crystal_ice: Array[Node] = []
	crystal.froze.connect(func(ice: Node) -> void: crystal_ice.append(ice))
	for frame: int in 30:
		await get_tree().physics_frame
	var sheet: IcePiece = null if crystal_ice.is_empty() else crystal_ice[0] as IcePiece
	_check(sheet != null and sheet.is_sheet and sheet.sheet_rect.position.x <= 296.0 and sheet.sheet_rect.end.x >= 364.0,
		"a crystal freezes the big pool into a sheet (%s)" % (sheet.sheet_rect if sheet != null else Rect2()))
	if sheet == null or not sheet.is_sheet:
		return
	var sheet_top: float = sheet.get_slide_top_y(origin.x + 300.0) - origin.y
	var puck: IceBlock = water.make_ice_block(Vector2(300.0, sheet_top - 9.5), 4.0 * WaterWorld.UNIT_AREA, Vector2.ZERO) as IceBlock
	for frame: int in 10:
		await get_tree().physics_frame
	_check(puck != null and puck.is_frozen_in_place, "a ball frozen on the sheet is frozen in place too")
	puck.receive_gust(Vector2.RIGHT, 120.0)
	for frame: int in 15:
		await get_tree().physics_frame
	var glide_speed: float = puck.velocity.x
	_check(not puck.is_frozen_in_place and glide_speed > 115.0,
		"gusted, it's a puck: it glides on the ice without slowing (%.0f px/s after 0.25 s, pushed at 120)" % glide_speed)
	for frame: int in 120:
		await get_tree().physics_frame
	var plate: PressurePlate = room.get_node("PuckPlate") as PressurePlate
	var puck_x: float = puck.global_position.x - origin.x
	_check(absf(puck.velocity.x) < 1.0 and puck_x > sheet.sheet_rect.end.x and puck_x < sheet.sheet_rect.end.x + 24.0,
		"off the ice it stops at once, just past the sheet's end (x %.0f, sheet ends at %.0f)" % [puck_x, sheet.sheet_rect.end.x])
	_check(plate.is_on(), "the puck stopped on the plate: it's pressed")

	# The TRAIL snake, driven directly (WaterSnake.update with chosen ball positions):
	# straight up out of the plateau pool, then out to the right at 22.5 degrees.
	var surface_local_y: float = water.get_surface_y_at(water.to_local(origin + Vector2(52.0, 100.0)))
	var foot: Vector2 = Vector2(origin.x + 52.0, water.to_global(Vector2(0.0, surface_local_y)).y)
	var snake: WaterSnake = WaterSnake.new(water, foot, foot + Vector2(0.0, -2.0))
	_check(snake.is_trail, "a new snake is a trail")
	var head: Vector2 = foot + Vector2(0.0, -2.0)
	for step: int in 20:
		head += Vector2(0.0, -1.0)
		snake.update(1.0 / 60.0, head, Vector2(0.0, -60.0))
	var rise_corners: int = snake.trail_corners.size()
	var slope: Vector2 = Vector2.from_angle(deg_to_rad(22.5))
	for step: int in 50:
		# A wobbly hand: the ball wanders a little either side of the line.
		head += slope + slope.orthogonal() * sin(step * 0.7) * 0.3
		snake.update(1.0 / 60.0, head, slope * 60.0)
	var run_angle: float = rad_to_deg(snake.run_direction.angle())
	print("[WaterSmokeTest] trail: %d corners %s, run %.2f deg, length %.1f" % [snake.trail_corners.size(), snake.trail_corners, run_angle, snake.length])
	_check(rise_corners == 1 and snake.trail_corners.size() == 2 and absf(run_angle - 22.5) < 0.01,
		"the trail is one rise and one run snapped to exactly 22.5 degrees (%d corners, %.3f deg)" % [snake.trail_corners.size(), run_angle])
	_check(snake.trail_corners.size() >= 2 and absf(snake.trail_corners[1].x - foot.x) < 0.01,
		"the rise is snapped straight up from the foot")
	if snake.trail_corners.size() < 2:
		return
	var off_line: float = 0.0
	for point: Vector2 in snake.points:
		if point.x > snake.trail_corners[1].x + 8.0:
			off_line = maxf(off_line, absf(snake.run_direction.cross(point - snake.trail_corners[1])))
	_check(off_line < 0.01, "past the rounded corner, the trail is a straight line (%.3f px off)" % off_line)
	# Rewind: steered back down the run to the corner, then down the rise.
	var corner: Vector2 = snake.trail_corners[1]
	var length_before_rewind: float = snake.length
	while head.distance_to(corner) > 1.0:
		head = head.move_toward(corner, 1.0)
		snake.update(1.0 / 60.0, head, -slope * 60.0)
	head += Vector2(0.0, 3.0)
	snake.update(1.0 / 60.0, head, Vector2(0.0, 60.0))
	_check(snake.trail_corners.size() == 1 and snake.length < length_before_rewind * 0.6,
		"steered back along it, the trail rewinds (%d corner(s), %.1f px)" % [snake.trail_corners.size(), snake.length])
	# Out again at 22.5 degrees, then FREEZE it: the ice has the trail's exact slope.
	for step: int in 50:
		head += slope
		snake.update(1.0 / 60.0, head, slope * 60.0)
	var trail_area: float = snake.area
	var trail_dots: PackedVector2Array = snake.get_dots(0.0, 0.0, false)
	snake.area = 0.0
	var books_before_freeze: float = water.get_books_units()
	var slide: IcePiece = water.freeze_held(water.to_local(head), 0.0, true, trail_area, trail_dots) as IcePiece
	_check(slide != null and slide.is_slide and slide.is_in_group(IceBlock.SLIDE_GROUP),
		"the frozen trail is static ice, and a slide (%s)" % slide)
	if slide == null:
		return
	var run_start_x: float = snake.trail_corners[snake.trail_corners.size() - 1].x + 12.0
	var top_a: float = slide.get_slide_top_y(run_start_x)
	var top_b: float = slide.get_slide_top_y(run_start_x + 24.0)
	var ice_slope_degrees: float = rad_to_deg(atan2(top_b - top_a, 24.0))
	_check(absf(ice_slope_degrees - 22.5) < 3.0,
		"the slide's top runs at the trail's angle (%.1f degrees)" % ice_slope_degrees)
	_check(absf(water.get_books_units() - books_before_freeze) < CONSERVATION_TOLERANCE,
		"the trail's water is all in the ice (books %.3f -> %.3f)" % [books_before_freeze, water.get_books_units()])
	# You slide down it.
	_place_on_slide(player, slide, origin, run_start_x - origin.x)
	var fastest: float = 0.0
	var slid: bool = false
	for frame: int in 40:
		await get_tree().physics_frame
		slid = slid or player.state_machine.current_state.name == &"Sliding"
		fastest = maxf(fastest, player.velocity.length())
	_check(slid and fastest > 80.0, "you slide down the frozen trail (%.0f px/s)" % fastest)
	await _wait_for_respawn(player)
	finished_sections.append("Ice")


## W4-W6's behaviour (`on`): the W4 rope and the W5 ice that keeps its momentum; off:
## the re-planned defaults (a trail, hanging ice).
func _use_w5_ice(player: Player, on: bool) -> void:
	player.water_tuning.snake_shape = WaterTuning.SnakeShape.ROPE if on else WaterTuning.SnakeShape.TRAIL
	player.water_tuning.ice_hangs = not on


## Waits (up to 2 s) until the player is alive and standing again, after a death.
func _wait_for_respawn(player: Player) -> void:
	for frame: int in 120:
		await get_tree().physics_frame
		if not player.is_dead() and player.is_on_floor():
			return


## Puts the player on `slide` at room-local x `local_x`, standing still.
func _place_on_slide(player: Player, slide: IcePiece, origin: Vector2, local_x: float) -> void:
	player.state_machine.transition_to(&"Fall")
	player.global_position = Vector2(origin.x + local_x, slide.get_slide_top_y(origin.x + local_x) - 0.5)
	player.velocity = Vector2.ZERO


## Starts the player still on `slide` near its top (x 64) and returns its speed as it
## passes room-local x 104, belly-sliding (down held) or not. Off the end it falls on
## the pins: waits for the respawn.
func _slide_speed_at(player: Player, slide: IcePiece, origin: Vector2, belly: bool) -> float:
	_place_on_slide(player, slide, origin, 64.0)
	if belly:
		Input.action_press(&"move_down")
	var speed: float = 0.0
	for frame: int in 120:
		await get_tree().physics_frame
		if player.global_position.x > origin.x + 104.0:
			speed = player.velocity.length()
			break
	Input.action_release(&"move_down")
	await _wait_for_respawn(player)
	return speed


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

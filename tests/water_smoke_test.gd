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
	# `-- W3` (any of W1 Swim W2 W3) runs only those sections: quicker while working on one.
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var sections: Array[String] = ["W1", "Swim", "W2", "W3"]
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
	water.throw_ball(Vector2(170, 60), Vector2(0, -30), 30.0)
	var total_usec: int = 0
	var drops_usec: int = 0
	var cohesion_usec: int = 0
	var peak_usec: int = 0
	var most_particles: int = 0
	for frame: int in 120:
		await get_tree().physics_frame
		total_usec += water.last_step_usec
		drops_usec += water.last_drops_usec
		cohesion_usec += water.last_cohesion_usec
		peak_usec = maxi(peak_usec, water.last_step_usec)
		most_particles = maxi(most_particles, water.get_drop_count())
	var average_usec: float = total_usec / 120.0
	print("[WaterSmokeTest] W2 loose water under stress: %.0f us average (particles %.0f, of it cohesion %.0f), %d us peak, up to %d particles" \
		% [average_usec, drops_usec / 120.0, cohesion_usec / 120.0, peak_usec, most_particles])
	_check(most_particles >= tuning.max_drops - 20, "the stress test fills the particle cap (%d of %d)" % [most_particles, tuning.max_drops])
	_check(average_usec < BUDGET_USEC, "loose water stays under the 2 ms budget: %.0f us average" % average_usec)
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
	_check(pool_after < pool_before - 3.5 and basin_after > basin_before + 3.5,
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
	hands._shove_touched()
	var crate_speed: float = (crate as CharacterBody2D).velocity.x
	_check(hands.last_shove_velocity.x > 0.0 and crate_speed > 0.0,
		"the ball shoves a floating crate too (%.0f px/s; the crate is %.2f under)" % [crate_speed, water.get_submerged_share(crate_box)])
	Input.action_release(&"water_hands")
	for frame: int in 60:
		await get_tree().physics_frame
	crate.queue_free()

	room.reset_objects()
	_check(water.held_area == 0.0, "a reset leaves nothing held")
	finished_sections.append("W3")


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

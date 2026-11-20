extends Node
## Headless smoke test for the small features added after the level tools: the
## signpost, the timed step pad, the lantern, the one-way teleport doors, the pause
## menu's "Restart level" and options page (AssistOptions: game speed, extra coyote
## time), the ghost of each room's fastest run (GhostRuns), Room.grass_burns
## (grass that burns with Fire off), the sky ship (SkyShip) and the gust's tuck
## (an Up-aimed gust curls you to half height). Not part of the game.
##
## It builds a two-room level in memory with LevelKit (tools/level_kit.gd), packs it
## the way the editor does for a play-test, and plays it:
##   Room1: a floor, the signpost, the timed pad, the lantern, a blue teleport
##          entrance and a red one (red has no exit).
##   Room2: to the right, DARK, the blue teleport exit, a strip of grass that can't burn.
##   Room3: apart, a grass floor with Grass Burns on and Fire off.
##   Room4: apart, the sky ship in mid-air over a floor, a wall on the right, and a
##          tiny wind zone in a corner (grown to fill the room for the wind check).
##   Room5: apart, a floor and low blocks over it leaving 1-tile tunnels
##          (x 160..208 px, and a 2-tile one at 256..272 for the tuck slide; the gap
##          is the tile row just above the floor).
## The options and the ghosts are written to throwaway files in user://, never the
## player's real ones.
## Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/features_smoke_test.tscn

const TEST_OPTIONS_PATH: String = "user://features_smoke_test_options.cfg"
const TEST_GHOST_PATH: String = "user://features_smoke_test_ghosts.cfg"
const GHOST_LEVEL_KEY: String = "test://features"
const ROOM_SIZE: Vector2 = Vector2(320, 184)
## The floor's top, px from the room's top (row 21 of 23).
const FLOOR_Y: float = 168.0

var failures: int = 0
var level: RoomManager = null
var player: Player = null


func _ready() -> void:
	AssistOptions.options_path = TEST_OPTIONS_PATH
	GhostRuns.record_path = TEST_GHOST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_GHOST_PATH))
	_check_catalog()
	await _open_level()
	await _check_signpost()
	await _check_timed_pad()
	await _check_lantern()
	await _check_assist_options()
	await _check_pause_menu()
	await _check_ghost()
	await _check_teleport()
	await _check_grass_burns()
	await _check_sky_ship()
	await _check_gust_tuck()
	# Leave the global switches as we found them.
	AssistOptions.game_speed = 1.0
	AssistOptions.extra_coyote_time = 0.0
	AssistOptions.show_ghost = false
	FX.set_assist_speed(1.0)
	AssistOptions.options_path = AssistOptions.DEFAULT_OPTIONS_PATH
	print("[FeaturesSmokeTest] %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Every new thing has a palette entry (CLAUDE.md working rule 7).
func _check_catalog() -> void:
	for id: StringName in [&"signpost", &"timed_step_pad", &"lantern", &"teleport_door", &"teleport_exit"]:
		var entry: PaletteCatalog.Entry = PaletteCatalog.get_entry(id)
		_check(entry != null and entry.scene != null and entry.hint != "", "catalog: %s has an entry with a scene and a hint" % id)


func _open_level() -> void:
	var kit: LevelKit = LevelKit.create("Features test")
	var first: Room = kit.add_room("Room1", "First", Vector2.ZERO, ROOM_SIZE)
	var second: Room = kit.add_room("Room2", "Second", Vector2(ROOM_SIZE.x, 0), ROOM_SIZE)
	second.is_dark = true
	for room: Room in [first, second]:
		kit.fill(room, &"ground", 0, 21, 40, 2)
		kit.set_spawn(room, 3, 20)
	kit.place(first, &"signpost", "Signpost", Vector2(64, FLOOR_Y), {&"text": "Hold Jump to jump higher."})
	kit.place(first, &"timed_step_pad", "TimedPad", Vector2(100, FLOOR_Y), {&"on_seconds": 0.5})
	kit.place(first, &"step_pad", "PlainPad", Vector2(120, FLOOR_Y))
	kit.place(first, &"lantern", "Lantern", Vector2(150, FLOOR_Y - 12))
	kit.place(first, &"teleport_door", "BlueDoor", Vector2(200, FLOOR_Y - 24))
	kit.place(first, &"teleport_door", "RedDoor", Vector2(240, FLOOR_Y - 24), {&"door_color": KeyColors.Name.RED})
	kit.place(second, &"teleport_exit", "BlueExit", Vector2(200, FLOOR_Y - 24))
	# Room3, apart from the others: a grass floor that burns with Fire off.
	var third: Room = kit.add_room("Room3", "Grass burns", Vector2(0, ROOM_SIZE.y * 3), ROOM_SIZE)
	kit.fill(third, &"grass", 0, 21, 40, 2)
	kit.set_spawn(third, 3, 20)
	third.grass_burns = true
	# Room2 gets grass too, but burns nothing (neither switch on).
	kit.fill(second, &"grass", 30, 20, 4, 1)
	# Room4, apart too: the sky ship, keel 48 px over the floor, and a wall on the right.
	var fourth: Room = kit.add_room("Room4", "Sky ship", Vector2(0, ROOM_SIZE.y * 6), ROOM_SIZE)
	fourth.air_allowed = true
	kit.fill(fourth, &"ground", 0, 21, 40, 2)
	kit.fill(fourth, &"ground", 38, 0, 2, 21)
	kit.set_spawn(fourth, 3, 20)
	kit.place(fourth, &"sky_ship", "Ship", Vector2(120, FLOOR_Y - 48))
	kit.place(fourth, &"wind_zone", "ShipWind", Vector2(0, 0),
		{&"zone_size": Vector2(8, 8), &"wind_direction": Vector2.LEFT, &"wind_strength": 80.0})
	# Room5, apart: a 1-tile-high tunnel (tile rows 0-19 solid over columns 20-25, row
	# 20 open, the floor at row 21) for the gust's tuck.
	var fifth: Room = kit.add_room("Room5", "Gust tuck", Vector2(0, ROOM_SIZE.y * 9), ROOM_SIZE)
	fifth.air_allowed = true
	kit.fill(fifth, &"ground", 0, 21, 40, 2)
	kit.fill(fifth, &"ground", 20, 0, 6, 20)
	# A short one, 2 tiles long (x 256..272 px), for the tuck slide.
	kit.fill(fifth, &"ground", 32, 0, 2, 20)
	kit.set_spawn(fifth, 3, 20)
	# Room6, apart: an ice floor, for a tuck slide on ice.
	var sixth: Room = kit.add_room("Room6", "Ice slide", Vector2(0, ROOM_SIZE.y * 12), ROOM_SIZE)
	sixth.air_allowed = true
	kit.fill(sixth, &"ice", 0, 21, 40, 2)
	kit.set_spawn(sixth, 3, 20)
	kit.set_start_room(first)
	# An object is matched to its palette entry by its scene: the two pads and the
	# two door ends must not be mixed up.
	_check(PaletteCatalog.entry_for_node(first.get_node("TimedPad")).id == &"timed_step_pad", "catalog: a timed pad is recognised as one")
	_check(PaletteCatalog.entry_for_node(first.get_node("PlainPad")).id == &"step_pad", "catalog: a plain step pad still is one")
	_check(PaletteCatalog.entry_for_node(second.get_node("BlueExit")).id == &"teleport_exit", "catalog: a teleport exit is recognised as one")
	# Packed and instantiated, like the editor's play-test copy.
	var packed: PackedScene = LevelStorage.pack_level(kit.level)
	kit.level.free()
	GameState.reset_run()
	level = packed.instantiate() as RoomManager
	level.ghost_level_key = GHOST_LEVEL_KEY
	add_child(level)
	player = level.player
	await _frames(3)
	_check(level.current_room == level.get_node("Room1"), "the test level starts in Room1")


func _check_signpost() -> void:
	var sign_node: Signpost = level.get_node("Room1/Signpost") as Signpost
	_check(not sign_node.text_label.visible, "signpost: no text while nobody stands by it")
	_stand(Vector2(64, FLOOR_Y))
	await _wait(0.5)
	_check(sign_node.text_label.visible and sign_node.text_label.modulate.a > 0.9, "signpost: the text shows while the player stands by it")
	_check(sign_node.text_label.text == "Hold Jump to jump higher.", "signpost: it shows its own text")
	var box_left: float = sign_node.text_label.global_position.x
	_check(box_left >= 0.0 and box_left + sign_node.text_label.size.x <= ROOM_SIZE.x, "signpost: the box stays inside the room")
	_stand(Vector2(20, FLOOR_Y))
	await _wait(0.5)
	_check(not sign_node.text_label.visible, "signpost: the text hides when the player walks off")


func _check_timed_pad() -> void:
	var pad: StepPad = level.get_node("Room1/TimedPad") as StepPad
	_check(not pad.is_on(), "timed pad: starts off")
	_stand(Vector2(100, FLOOR_Y))
	await _wait(0.2)
	_check(pad.is_on(), "timed pad: on while stood on")
	_stand(Vector2(20, FLOOR_Y))
	await _wait(0.25)
	_check(pad.is_on(), "timed pad: still on a quarter second after stepping off (0.5 s pad)")
	await _wait(0.5)
	_check(not pad.is_on(), "timed pad: off once its time ran out")


func _check_lantern() -> void:
	var lantern: Lantern = level.get_node("Room1/Lantern") as Lantern
	var lights: Array[Vector4] = lantern.get_dark_lights()
	_check(lights.size() == 1 and is_equal_approx(lights[0].z, lantern.fire_tuning.dark_lantern_light_radius),
		"lantern: a light of the tuned radius while waiting")
	_stand(Vector2(150, FLOOR_Y))
	await _wait(0.3)
	_check(lantern.state == TrailingPickup.State.FOLLOWING, "lantern: follows the player after a touch")
	_stand(Vector2(40, FLOOR_Y))
	await _wait(0.8)
	_check(lantern.global_position.distance_to(player.global_position) < 30.0, "lantern: stays near the player as they move")
	player.die(true)
	await _wait(player.tuning.death_respawn_delay + TrailingPickup.RETURN_TIME + 0.5)
	_check(lantern.state == TrailingPickup.State.HOME, "lantern: back where it was placed after a death")
	_check(lantern.get_parent() == level.get_node("Room1"), "lantern: back in its own room's branch")


func _check_assist_options() -> void:
	AssistOptions.game_speed = 1.0
	AssistOptions.cycle_game_speed()
	_check(is_equal_approx(Engine.time_scale, 0.9), "assist: one step of game speed is 90%% (time scale %.2f)" % Engine.time_scale)
	FX.set_slow_motion(0.5, 5.0)
	_check(is_equal_approx(Engine.time_scale, 0.45), "assist: slow motion multiplies with the game speed")
	FX.clear_slow_motion()
	_check(is_equal_approx(Engine.time_scale, 0.9), "assist: the game speed stays when slow motion ends")
	var saved: ConfigFile = ConfigFile.new()
	_check(saved.load(TEST_OPTIONS_PATH) == OK and is_equal_approx(saved.get_value(AssistOptions.SECTION, "game_speed", 0.0), 0.9),
		"assist: the game speed is saved")
	AssistOptions.game_speed = 1.0
	FX.set_assist_speed(1.0)
	_stand(Vector2(40, FLOOR_Y))
	await _frames(4)
	var plain_coyote: float = player.coyote_time_remaining
	AssistOptions.extra_coyote_time = 0.2
	await _frames(2)
	_check(is_equal_approx(player.coyote_time_remaining, plain_coyote + 0.2), "assist: extra coyote time is added on the floor")
	AssistOptions.extra_coyote_time = 0.0


func _check_pause_menu() -> void:
	var menu: PauseMenu = level.get_node("PauseMenu") as PauseMenu
	menu._set_open(true)
	_check(menu.main_page.visible and not menu.options_page.visible, "pause: opens on the main page")
	_check(menu.main_page.get_combined_minimum_size().y <= 180.0,
		"pause: the main page fits the 180 px screen (%d px)" % int(menu.main_page.get_combined_minimum_size().y))
	menu.options_button.pressed.emit()
	_check(menu.options_page.visible and not menu.main_page.visible, "pause: Options shows the options page")
	menu.speed_button.pressed.emit()
	_check(menu.speed_button.text.contains("90%"), "pause: pressing Game speed steps it (%s)" % menu.speed_button.text)
	menu.ghost_button.pressed.emit()
	_check(AssistOptions.show_ghost and menu.ghost_button.text.ends_with("on"), "pause: pressing Ghost switches it on")
	AssistOptions.game_speed = 1.0
	FX.set_assist_speed(1.0)
	# "Restart level" in an editor play-test calls the editor's hook instead of
	# reloading the running scene (here that would reload this test).
	var restarts: Array[int] = [0]
	menu.restart_level = func() -> void: restarts[0] += 1
	menu._on_restart_level_pressed()
	_check(restarts[0] == 1, "pause: Restart level calls the play-test's hook")
	_check(not get_tree().paused, "pause: the game runs again after Restart level")
	await _frames(2)


## A run through Room1 from its spawn point: recorded, saved, and replayed.
func _check_ghost() -> void:
	var ghosts: GhostRuns = level.ghost_runs
	var first: Room = level.get_node("Room1") as Room
	level.jump_to_room(first)  # also throws the current run away
	await _frames(2)
	_check(ghosts.get_best_time(first, GhostRuns.START_FROM_SPAWN) < 0.0, "ghost: no best run of Room1 yet")
	Input.action_press("move_right")
	var waited: float = 0.0
	while level.current_room == first and waited < 10.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	Input.action_release("move_right")
	await _wait(0.6)  # the camera slide
	var best: float = ghosts.get_best_time(first, GhostRuns.START_FROM_SPAWN)
	_check(best > 1.0 and best < 10.0, "ghost: walking out of Room1 records a run (%.2f s)" % best)
	var saved: ConfigFile = ConfigFile.new()
	_check(saved.load(TEST_GHOST_PATH) == OK and saved.has_section(GHOST_LEVEL_KEY), "ghost: the run is saved under the level's key")
	# Walking back in and out the way you came is not a run through Room2.
	Input.action_press("move_left")
	waited = 0.0
	while level.current_room != first and waited < 5.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	Input.action_release("move_left")
	await _wait(0.6)
	_check(ghosts.best_runs.size() == 1, "ghost: leaving Room2 the way you came records nothing (%d runs)" % ghosts.best_runs.size())
	# From the spawn again: the ghost replays the saved run from the same start.
	player.die(true)
	await _wait(player.tuning.death_respawn_delay + 0.3)
	_check(not ghosts.ghost_run.is_empty() and ghosts.is_recording, "ghost: after a respawn the best run from the spawn is replayed")
	# The ghost has walked on while we stand at the spawn: compare its first position.
	var ghost_center: Vector2 = ghosts._get_ghost_center(0.0)
	_check(first.get_bounds().has_point(ghosts._get_ghost_center(ghosts.run_time)) and ghost_center.distance_to(player.get_center()) < 16.0,
		"ghost: it starts where the run started")
	# A run with a play-test cheat on is not kept.
	ghosts.best_runs.clear()
	level.jump_to_room(first)
	player.is_invincible = true
	_stand(Vector2(300, FLOOR_Y))
	Input.action_press("move_right")
	await _wait(1.2)
	Input.action_release("move_right")
	player.is_invincible = false
	_check(level.current_room != first and ghosts.best_runs.is_empty(), "ghost: a run made while invincible is thrown away")


func _check_teleport() -> void:
	var first: Room = level.get_node("Room1") as Room
	var second: Room = level.get_node("Room2") as Room
	var blue_door: TeleportDoor = first.get_node("BlueDoor") as TeleportDoor
	var red_door: TeleportDoor = first.get_node("RedDoor") as TeleportDoor
	var blue_exit: TeleportDoor = second.get_node("BlueExit") as TeleportDoor
	_check(blue_door.find_exit() == blue_exit, "teleport: the blue entrance finds the blue exit in the other room")
	_check(red_door.find_exit() == null, "teleport: the red entrance has no exit")
	_check(blue_exit.find_exit() == null or blue_exit.is_exit, "teleport: an exit is an exit")
	level.jump_to_room(first)
	# The red door: Up does nothing.
	_stand(red_door.position + Vector2(8, 24))
	await _press_up()
	_check(level.current_room == first, "teleport: an entrance without an exit does nothing")
	_stand(blue_door.position + Vector2(8, 24))
	await _press_up()
	_check(level.current_room == second, "teleport: Up in the blue entrance moves to the exit's room")
	_check(player.global_position.distance_to(blue_exit.get_feet_position()) < 4.0, "teleport: the player stands in the exit")
	_check(GameState.death_count == 2, "teleport: it doesn't count a death (the test's two deaths only, found %d)" % GameState.death_count)
	# One way: Up in the exit leads nowhere.
	await _press_up()
	_check(level.current_room == second and player.global_position.distance_to(blue_exit.get_feet_position()) < 4.0,
		"teleport: Up in the exit does nothing")


## Room.grass_burns: with Fire off, Room3's grass still gets a FireGrid and catches
## fire, while the player still can't bend fire there. Room2's grass (neither
## switch on) gets no grid.
func _check_grass_burns() -> void:
	var second: Room = level.get_node("Room2") as Room
	var third: Room = level.get_node("Room3") as Room
	_check(second.get_node_or_null("FireGrid") == null, "grass burns: grass in a room with Fire off and no Grass Burns gets no FireGrid")
	var grid: FireGrid = third.get_node_or_null("FireGrid") as FireGrid
	_check(grid != null, "grass burns: Room3 (Grass Burns on, Fire off) has a FireGrid")
	level.jump_to_room(third)
	await _frames(2)
	_check(not player.is_element_allowed(Player.ELEMENT_FIRE), "grass burns: the player still can't bend fire there")
	if grid == null:
		return
	var floor_point: Vector2 = third.global_position + Vector2(200, FLOOR_Y + 4)
	_check(grid.ignite_at(floor_point, 2.0, null), "grass burns: the grass catches fire")
	await _wait(0.5)
	_check(grid.is_burning(), "grass burns: and burns")


## The sky ship: it sinks slowly, a gust from aboard sails it (sideways and up) and
## carries the rider, the room's wall stops it, a wind zone carries it, it never
## crushes the player, and a reset puts it back.
func _check_sky_ship() -> void:
	var ship_room: Room = level.get_node("Room4") as Room
	var ship: SkyShip = ship_room.get_node("Ship") as SkyShip
	_check(PaletteCatalog.get_entry(&"sky_ship") != null and PaletteCatalog.get_entry(&"sky_ship").hint != "", "sky ship: has a palette entry with a hint")
	level.jump_to_room(ship_room)
	await _frames(2)
	var home: Vector2 = ship.global_position
	await _wait(1.0)
	_check(ship.global_position.y > home.y + 4.0 and ship.global_position.y < home.y + 20.0,
		"sky ship: sinks slowly with nothing lifting it (%.1f px in 1 s)" % (ship.global_position.y - home.y))

	# Aboard: stand on the crow's nest (its top is 44 px above the keel).
	ship_room.reset_objects()
	player.global_position = ship.global_position + Vector2(0.0, -44.0)
	player.velocity = Vector2.ZERO
	await _frames(4)
	_check(player.get_floor_body() == ship, "sky ship: the player stands on the crow's nest")
	await _gust_toward("move_right")
	_check(ship.velocity.x > 20.0, "sky ship: a sideways gust from aboard sails it that way (%.0f px/s)" % ship.velocity.x)
	var ship_x_before: float = ship.global_position.x
	var player_x_before: float = player.global_position.x
	await _wait(0.5)
	var ship_moved: float = ship.global_position.x - ship_x_before
	_check(ship_moved > 8.0 and absf((player.global_position.x - player_x_before) - ship_moved) < 2.0,
		"sky ship: it carries the rider along (ship %.1f px, player %.1f px)" % [ship_moved, player.global_position.x - player_x_before])
	_check(player.get_floor_body() == ship, "sky ship: the rider stays aboard while it sails")
	await _gust_toward("move_up")
	_check(ship.velocity.y < -10.0, "sky ship: an up gust from aboard lifts it (%.0f px/s)" % ship.velocity.y)

	# Jumping off a moving ship keeps its speed (after the second play-test): with no
	# arrow held you keep pace with it; holding the arrow, you run ahead of it.
	for arrow: String in ["", "move_right"]:
		ship_room.reset_objects()
		await _board_ship(ship, 16.0)
		ship.velocity = Vector2(100.0, 0.0)
		await _wait(0.2)
		var ship_start_x: float = ship.global_position.x
		var player_start_x: float = player.global_position.x
		if arrow != "":
			Input.action_press(arrow)
		Input.action_press("jump")
		await _frames(3)
		Input.action_release("jump")
		await _frames(24)  # 0.4 s, counted in physics frames: timers were flaky here
		if arrow != "":
			Input.action_release(arrow)
		var ship_moved_x: float = ship.global_position.x - ship_start_x
		var player_moved_x: float = player.global_position.x - player_start_x
		if arrow == "":
			_check(absf(player_moved_x - ship_moved_x) < 6.0,
				"sky ship: jumping off it, you keep its speed (ship %.1f px, you %.1f px)" % [ship_moved_x, player_moved_x])
		else:
			_check(player_moved_x > ship_moved_x + 10.0,
				"sky ship: jumping off holding the arrow, you run on top of its speed (ship %.1f px, you %.1f px)" % [ship_moved_x, player_moved_x])

	# The lips: walking right on the nest for a second doesn't take you off its end.
	ship_room.reset_objects()
	await _board_ship(ship, 44.0)
	Input.action_press("move_right")
	await _wait(1.0)
	Input.action_release("move_right")
	await _frames(2)
	_check(player.get_floor_body() == ship, "sky ship: the crow's nest's lip stops you walking off its end")
	ship_room.reset_objects()
	await _board_ship(ship, 16.0)
	Input.action_press("move_left")
	await _wait(1.5)
	Input.action_release("move_left")
	await _frames(2)
	_check(player.get_floor_body() == ship, "sky ship: the deck's lip stops you walking off its end")

	# The crow's nest pushes harder than the deck (nest_push_multiplier).
	ship_room.reset_objects()
	await _board_ship(ship, 16.0)
	ship.velocity = Vector2.ZERO
	ship.absorb_gust_recoil(Vector2.RIGHT, player.tuning.gust_push_strength)
	var deck_push: float = ship.velocity.x
	ship_room.reset_objects()
	await _board_ship(ship, 44.0)
	ship.velocity = Vector2.ZERO
	ship.absorb_gust_recoil(Vector2.RIGHT, player.tuning.gust_push_strength)
	_check(ship.velocity.x > deck_push * 1.2, "sky ship: a gust from the crow's nest pushes harder than from the deck (%.0f vs %.0f px/s)" % [ship.velocity.x, deck_push])

	# A barrage of gusts every way, diagonals too (after the first play-test: the
	# rider kept losing the floor and their own gust threw them off). Never off the
	# ship for more than a couple of frames, and still aboard at the end.
	ship_room.reset_objects()
	await _board_ship(ship, 44.0)
	var longest_off: int = 0
	var off_run: int = 0
	for arrows: String in ["move_right", "move_right", "move_up", "move_up+move_right", "move_up", "move_down+move_left",
			"move_down", "move_left", "move_left", "move_up+move_left", "move_down", "move_right"]:
		for part: String in arrows.split("+"):
			Input.action_press(part)
		for frame: int in 12:
			if frame == 2:
				Input.action_press("gust")
			elif frame == 5:
				Input.action_release("gust")
			elif frame == 7:
				for part: String in arrows.split("+"):
					Input.action_release(part)
			await get_tree().physics_frame
			off_run = 0 if player.get_floor_body() == ship else off_run + 1
			longest_off = maxi(longest_off, off_run)
	await _frames(10)
	_check(longest_off <= 3 and player.get_floor_body() == ship and not player.is_dead(),
		"sky ship: twelve quick gusts every way and the rider stays aboard (off at most %d frames in a row)" % longest_off)

	# The wall on the right stops it: sailing fast at it, it ends up against it.
	ship_room.reset_objects()
	player.global_position = ship_room.global_position + Vector2(24, FLOOR_Y)
	player.velocity = Vector2.ZERO
	ship.velocity = Vector2(110.0, 0.0)
	var wall_left: float = ship_room.global_position.x + 38.0 * 8.0
	var furthest_right: float = -INF
	for frame: int in 150:
		await get_tree().physics_frame
		furthest_right = maxf(furthest_right, ship.global_position.x + 28.0)
	_check(furthest_right <= wall_left + 1.0 and furthest_right > wall_left - 2.0,
		"sky ship: a wall stops it (hull's right side got to %.1f, wall %.1f)" % [furthest_right, wall_left])
	_check(ship.velocity.x <= 0.0, "sky ship: and it bounces back off it or stops (%.0f px/s)" % ship.velocity.x)

	# A wind zone over the room's upper part (the player on the floor stays out of
	# it), blowing left, carries it left.
	ship_room.reset_objects()
	var wind: WindZone = ship_room.get_node("ShipWind") as WindZone
	wind.zone_size = Vector2(300, 130)
	await _wait(1.5)
	_check(ship.velocity.x < -20.0 and ship.global_position.x < home.x - 10.0,
		"sky ship: a wind zone carries it (%.0f px/s)" % ship.velocity.x)
	wind.zone_size = Vector2(8, 8)

	# Never crushed: the player stands against the wall, the ship sails into them.
	ship_room.reset_objects()
	# Resting on the floor, its hull's right side 14 px from the player's middle (the
	# player is 8 px wide), sliding at them faster than the ground's friction stops it.
	var player_x: float = 38.0 * 8.0 - 5.0
	ship.exact_position = Vector2(player_x - 14.0 - 28.0, FLOOR_Y)
	ship.position = ship.exact_position
	player.global_position = ship_room.global_position + Vector2(player_x, FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _frames(2)
	ship.velocity = Vector2(100.0, 0.0)
	await _wait(1.5)
	_check(not player.is_dead(), "sky ship: sailing into the player against a wall doesn't kill them")
	# The player is 7.6 px wide; the ship bumps off them a little, like off a wall.
	var hull_right: float = ship.global_position.x + 28.0
	var player_left: float = player.global_position.x - 3.8
	_check(hull_right <= player_left + 0.6 and hull_right > player_left - 6.0 and player.global_position.x + 3.8 <= wall_left + 0.1,
		"sky ship: it stops against the player instead of passing through (hull %.1f, player's left side %.1f)" % [hull_right, player_left])

	ship_room.reset_objects()
	# An AnimatableBody2D synced to physics shows a new position after the next
	# physics step, so look a moment later (it has sunk a fraction of a pixel by then).
	await _frames(2)
	_check(ship.position.distance_to(ship.home_position) <= 1.0 and ship.velocity.length() < 2.0,
		"sky ship: a reset puts it back where it was placed, at rest")


## Puts the player on the ship, feet `height` px above its keel (16 = the deck, 44 =
## the crow's nest), at rest, and lets them settle.
## The gust's tuck (PlayerTuning.gust_tuck_*): an Up-aimed gust halves the hitbox;
## under a 1-tile ceiling you stay tucked and run slower; out of it you stand up.
func _check_gust_tuck() -> void:
	var tuck_room: Room = level.get_node("Room5") as Room
	level.jump_to_room(tuck_room)
	await _frames(2)
	var tunnel_left: float = tuck_room.global_position.x + 160.0
	var tunnel_right: float = tuck_room.global_position.x + 208.0
	var standing_height: float = player.standing_shape.size.y

	# Standing, the tunnel is a wall.
	_stand(Vector2(120.0, FLOOR_Y))
	await _frames(2)
	Input.action_press("move_right")
	await _wait(0.6)
	Input.action_release("move_right")
	_check(player.global_position.x < tunnel_left and not player.is_tucked,
		"gust tuck: standing, the 1-tile tunnel blocks you (x %.1f)" % (player.global_position.x - tuck_room.global_position.x))

	# A straight up-gust on open ground: tucked, then standing again.
	_stand(Vector2(60.0, FLOOR_Y))
	await _frames(2)
	await _gust_toward("move_up")
	_check(player.is_tucked and player.get_hitbox_rect().size.y < standing_height,
		"gust tuck: an up-gust curls you to half height")
	await _wait(player.tuning.gust_tuck_time + 0.2)
	_check(not player.is_tucked, "gust tuck: with room overhead you stand up when the tuck ends")

	# Tucked at the tunnel's mouth: run in, slower, and stay tucked under the ceiling.
	_stand(Vector2(150.0, FLOOR_Y))
	await _frames(2)
	await _gust_toward("move_up")
	Input.action_press("move_right")
	await _wait(0.5)
	var inside_x: float = player.global_position.x
	var speed_inside: float = player.velocity.x
	_check(inside_x > tunnel_left + 4.0 and player.is_tucked,
		"gust tuck: tucked, you run into the 1-tile tunnel and stay tucked past the tuck time")
	var expected_speed: float = player.tuning.max_run_speed * player.tuning.tucked_run_scale
	_check(absf(speed_inside - expected_speed) < 2.0,
		"gust tuck: tucked running is slower (%.0f px/s, expected %.0f)" % [speed_inside, expected_speed])
	await _wait(1.6)
	Input.action_release("move_right")
	await _frames(4)
	_check(player.global_position.x > tunnel_right and not player.is_tucked,
		"gust tuck: out the far end you stand up again")

	# A diagonal up-gust in the air shoots you sideways into the tunnel.
	_stand(Vector2(140.0, FLOOR_Y - 10.0))
	await _frames(1)
	await _gust_diagonal("move_up", "move_left")
	await _wait(0.2)
	_check(player.global_position.x > tunnel_left + 4.0 and player.is_tucked,
		"gust tuck: a diagonal up-gust in the air shoots you into the tunnel (x %.1f)" % (player.global_position.x - tuck_room.global_position.x))

	# The tuck slide: an up-diagonal gust on the ground, at the mouth of the 2-tile
	# tunnel, carries you through it and out the far end in one go.
	_stand(Vector2(251.0, FLOOR_Y))
	await _wait(0.4)
	await _gust_diagonal("move_up", "move_left")
	await _wait(0.5)
	var slide_x: float = player.global_position.x - tuck_room.global_position.x
	_check(slide_x > 276.0, "gust tuck: a tuck slide crosses a 2-tile tunnel (x %.1f, exit at 272)" % slide_x)
	await _wait(0.3)
	_check(not player.is_tucked, "gust tuck: and you stand up past it")
	# Holding the arrow the slide goes: it slows only to run speed and you run on.
	_stand(Vector2(40.0, FLOOR_Y))
	await _wait(0.4)
	await _gust_diagonal("move_up", "move_left")
	Input.action_press("move_right")
	await _wait(0.6)
	var run_on_speed: float = player.velocity.x
	Input.action_release("move_right")
	_check(run_on_speed > player.tuning.max_run_speed * player.tuning.tucked_run_scale - 1.0,
		"gust tuck: holding on, the slide flows into a run (%.0f px/s after 0.6 s)" % run_on_speed)

	# A plain sideways ground gust still barely moves you.
	_stand(Vector2(60.0, FLOOR_Y))
	await _wait(0.4)
	await _gust_toward("move_left")
	await _wait(0.3)
	var plain_x: float = player.global_position.x - tuck_room.global_position.x
	_check(plain_x < 70.0, "gust tuck: a plain sideways ground gust still keeps you planted (%.1f px)" % (plain_x - 60.0))

	# On ice the slide keeps going (the ice's own overspeed rules).
	var ice_room: Room = level.get_node("Room6") as Room
	level.jump_to_room(ice_room)
	await _frames(2)
	_stand(Vector2(40.0, FLOOR_Y))
	await _wait(0.4)
	await _gust_diagonal("move_up", "move_left")
	await _wait(0.5)
	_check(player.velocity.x > player.tuning.max_run_speed,
		"gust tuck: a tuck slide on ice keeps its speed (%.0f px/s after 0.5 s)" % player.velocity.x)
	level.jump_to_room(tuck_room)
	await _frames(2)

	# Off switch: no tuck.
	player.tuning.gust_tuck_enabled = false
	_stand(Vector2(60.0, FLOOR_Y))
	await _wait(player.tuning.gust_tuck_time + 0.1)
	await _gust_toward("move_up")
	_check(not player.is_tucked, "gust tuck: gust_tuck_enabled off, an up-gust doesn't tuck")
	player.tuning.gust_tuck_enabled = true


func _board_ship(ship: SkyShip, height: float) -> void:
	await _frames(2)
	player.global_position = ship.global_position + Vector2(0.0, -height)
	player.velocity = Vector2.ZERO
	await _frames(4)


## Gusts with an arrow held: press the arrow, tap gust (hold-to-aim fires on release),
## let go of the arrow.
func _gust_toward(arrow_action: String) -> void:
	Input.action_press(arrow_action)
	await _frames(2)
	Input.action_press("gust")
	await _frames(3)
	Input.action_release("gust")
	await _frames(3)

	Input.action_release(arrow_action)
	await _frames(2)


## A gust aimed at a diagonal: both arrows held through it.
func _gust_diagonal(first_action: String, second_action: String) -> void:
	Input.action_press(first_action)
	Input.action_press(second_action)
	await _frames(2)
	Input.action_press("gust")
	await _frames(3)
	Input.action_release("gust")
	await _frames(3)
	Input.action_release(first_action)
	Input.action_release(second_action)
	await _frames(2)


# --- Helpers -----------------------------------------------------------------------

## Stands the player's feet at `local_px` of the CURRENT room.
func _stand(local_px: Vector2) -> void:
	player.global_position = level.current_room.global_position + local_px
	player.velocity = Vector2.ZERO


## Taps Up (move_up) for a few physics frames, after letting the areas notice the player.
func _press_up() -> void:
	await _frames(4)
	Input.action_press("move_up")
	await _frames(3)
	Input.action_release("move_up")
	await _frames(3)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS  %s" % description)
	else:
		failures += 1
		print("FAIL  %s" % description)

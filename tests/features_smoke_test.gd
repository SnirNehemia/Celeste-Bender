extends Node
## Headless smoke test for the small features added after the level tools: the
## signpost, the timed step pad, the lantern, the one-way teleport doors, the pause
## menu's "Restart level" and options page (AssistOptions: game speed, extra coyote
## time), and the ghost of each room's fastest run (GhostRuns). Not part of the game.
##
## It builds a two-room level in memory with LevelKit (tools/level_kit.gd), packs it
## the way the editor does for a play-test, and plays it:
##   Room1: a floor, the signpost, the timed pad, the lantern, a blue teleport
##          entrance and a red one (red has no exit).
##   Room2: to the right, DARK, the blue teleport exit.
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

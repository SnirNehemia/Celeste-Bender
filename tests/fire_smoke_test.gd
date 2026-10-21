extends Node
## Headless smoke test for the Fire chapter (Stages F1+). Not part of the game.
##
## Loads tests/fire_test_world.tscn and checks, by script, what can be checked
## without a person at the keyboard. Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/fire_smoke_test.tscn
## Every Fire stage adds a section here (Fire_bending.md §13).

const WORLD_SCENE: PackedScene = preload("res://tests/fire_test_world.tscn")

var failures: int = 0
## Names of the check sections that ran to their end. A script error inside a
## section ends it silently, so _ready() checks this list.
var finished_sections: Array[String] = []


func _ready() -> void:
	var world: RoomManager = WORLD_SCENE.instantiate() as RoomManager
	add_child(world)
	# Let the player drop onto the floor and the room manager pick the room.
	await get_tree().create_timer(0.3).timeout
	await _check_f1_fire_bar(world, world.player)

	for section_name: String in ["F1"]:
		_check(finished_sections.has(section_name), "section %s ran to its end" % section_name)
	print("[FireSmokeTest] %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Stage F1: input actions, room flags, the fire bar, per-room pips, fire diamonds.
func _check_f1_fire_bar(world: RoomManager, player: Player) -> void:
	var room: Room = world.current_room
	var bar: FireBar = player.fire_bar
	var max_pips: int = player.fire_tuning.max_pips

	# Keys: D and F are the fire keys, and the unused earth_snake action is gone.
	_check(InputMap.has_action("fireball") and _action_has_key("fireball", KEY_D), "fireball is on D")
	_check(InputMap.has_action("flame_jet") and _action_has_key("flame_jet", KEY_F), "flame_jet is on F")
	_check(not InputMap.has_action("earth_snake"), "the unused earth_snake action was removed")

	# Room flags.
	_check(room.name == &"RoomFireA", "the world starts in RoomFireA, got %s" % room.name)
	_check(player.is_element_allowed(Player.ELEMENT_FIRE), "Fire is on in Fire A")
	_check(not player.is_element_allowed(Player.ELEMENT_AIR), "Air is off in Fire A")
	_check(not player.is_element_allowed(Player.ELEMENT_EARTH), "Earth is off in Fire A")
	var plain_room: Room = Room.new()
	_check(not plain_room.fire_allowed, "fire is off by default, so Air and Earth rooms are unchanged")
	_check(max_pips == 5, "max_pips starts at 5, got %d" % max_pips)

	# Starting pips come from the room.
	_check(bar.pips == room.fire_start_pips and bar.pips == 2, "spawned with the room's 2 starting pips, got %d" % bar.pips)

	# spend() and its signals.
	var signal_log: Array = []
	var on_changed: Callable = func(pips: int, change: int) -> void: signal_log.append([pips, change])
	var dry_count: Array[int] = [0]
	var on_dry: Callable = func() -> void: dry_count[0] += 1
	bar.pips_changed.connect(on_changed)
	bar.ran_dry.connect(on_dry)
	_check(bar.spend() and bar.pips == 1, "spend() takes one pip")
	_check(signal_log.size() == 1 and signal_log[0] == [1, -1], "pips_changed(1, -1) after a spend, got %s" % [signal_log])
	_check(bar.spend() and bar.pips == 0, "spend() takes the last pip")
	_check(not bar.spend() and bar.pips == 0, "spend() at 0 pips fails and leaves 0")
	_check(dry_count[0] == 1, "ran_dry fires when spending at 0")

	# gain() and the cap.
	_check(bar.gain(3) == 3 and bar.pips == 3, "gain(3) adds three")
	_check(bar.gain(4) == 2 and bar.pips == max_pips, "gain past the cap stops at %d (the extra is lost)" % max_pips)
	_check(bar.gain(1) == 0, "gain at the cap adds nothing")
	bar.pips_changed.disconnect(on_changed)
	bar.ran_dry.disconnect(on_dry)

	# The temporary debug key (F) spends a pip, like the jet will.
	var pips_before_key: int = bar.pips
	Input.action_press("flame_jet")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("flame_jet")
	await get_tree().physics_frame
	_check(bar.pips == pips_before_key - 1, "the F debug key spends one pip (%d -> %d)" % [pips_before_key, bar.pips])

	# A reset (death or R) brings back the room's starting pips.
	room.reset_objects()
	player.respawn_at(room.get_spawn_position())
	_check(bar.pips == 2, "respawn resets the bar to the room's starting pips, got %d" % bar.pips)

	# Entering another room sets the bar to THAT room's starting pips (per room).
	var other_room: Room = Room.new()
	other_room.fire_allowed = true
	other_room.fire_start_pips = 4
	GameState.current_room = other_room
	_check(bar.pips == 4, "entering a room with 4 starting pips gives 4, got %d" % bar.pips)
	other_room.fire_allowed = false
	GameState.current_room = room
	other_room.fire_start_pips = 9
	GameState.current_room = other_room
	_check(bar.pips == 0, "a room without fire gives 0 pips, got %d" % bar.pips)
	GameState.current_room = room
	_check(bar.pips == 2, "coming back to Fire A gives its 2 starting pips again, got %d" % bar.pips)
	other_room.free()
	plain_room.free()

	# Fire diamonds: single +1, double +2, single use until reset, kept when full.
	var single: FireDiamond = room.get_node("FireDiamondSingle1") as FireDiamond
	var double: FireDiamond = room.get_node("FireDiamondDouble1") as FireDiamond
	var high_double: FireDiamond = room.get_node("FireDiamondDouble2") as FireDiamond
	_check(single.pip_amount == 1 and double.pip_amount == 2, "the room has single and double diamonds")
	await _touch(player, single)
	_check(bar.pips == 3 and not single.is_available, "a single diamond adds 1 pip and is used up")
	await _touch(player, double)
	_check(bar.pips == 5 and not double.is_available, "a double diamond adds 2 pips and is used up")
	# Wait past the wind crystal's respawn time: a fire diamond must NOT come back.
	await get_tree().create_timer(single.respawn_time + 0.3).timeout
	_check(not single.is_available and not double.is_available, "used fire diamonds don't respawn by themselves")
	# Full bar: the diamond stays.
	await _touch(player, high_double)
	_check(bar.pips == max_pips and high_double.is_available, "a diamond touched with a full bar stays")
	bar.spend()
	await _touch(player, high_double)
	_check(bar.pips == max_pips and not high_double.is_available, "with room for one pip, a double fills the bar and is used up (one lost)")

	# Death/R: diamonds back, pips back to the start.
	room.reset_objects()
	player.respawn_at(room.get_spawn_position())
	await get_tree().physics_frame
	_check(single.is_available and double.is_available and high_double.is_available, "room reset brings every fire diamond back")
	_check(bar.pips == 2, "room reset brings back the 2 starting pips")
	finished_sections.append("F1")


# --- Helpers ---------------------------------------------------------------------

## Puts the player's feet just under `diamond` for a few physics frames, then back at
## the spawn (standing still, so it doesn't walk into the other diamonds).
func _touch(player: Player, diamond: Node2D) -> void:
	player.global_position = diamond.global_position + Vector2(0, 5)
	player.velocity = Vector2.ZERO
	for frame: int in 3:
		await get_tree().physics_frame
	player.global_position = player.get_parent().get_node("RoomFireA/SpawnPoint").global_position
	player.velocity = Vector2.ZERO
	# A few frames: an Area2D's list of overlapping bodies only catches up with a
	# teleport after a physics step or two.
	for frame: int in 3:
		await get_tree().physics_frame


func _action_has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and (key_event.physical_keycode == key or key_event.keycode == key):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS  %s" % description)
	else:
		failures += 1
		print("  FAIL  %s" % description)

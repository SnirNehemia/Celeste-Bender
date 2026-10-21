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
	await _check_f2_tuning_panel(world.player)
	await _check_f3_flame_jet(world, world.player)

	for section_name: String in ["F1", "F2", "F3"]:
		_check(finished_sections.has(section_name), "section %s ran to its end" % section_name)
	print("[FireSmokeTest] %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Stage F1: input actions, room flags, the fire bar, per-room pips, fire diamonds.
func _check_f1_fire_bar(world: RoomManager, player: Player) -> void:
	var room: Room = world.current_room
	var bar: FireBar = player.fire_bar
	var max_pips: int = player.fire_tuning.max_pips

	# Keys: Q and W are the fire keys (moved from D/F in Stage F3), and the unused earth_snake action is gone.
	_check(InputMap.has_action("fireball") and _action_has_key("fireball", KEY_Q), "fireball is on Q")
	_check(InputMap.has_action("flame_jet") and _action_has_key("flame_jet", KEY_W), "flame_jet is on W")
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

	# W (the flame jet, Stage F3; a debug key in F1) spends a pip.
	var pips_before_key: int = bar.pips
	Input.action_press("flame_jet")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("flame_jet")
	await get_tree().physics_frame
	_check(bar.pips == pips_before_key - 1, "W spends one pip (%d -> %d)" % [pips_before_key, bar.pips])

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


## Stage F2: the F5 tuning panel. Drives it through its methods (and one real key
## press for F5), and puts every value it touched back, so no test leaks into play.
## It never presses F4: the test must not write the real .tres files.
func _check_f2_tuning_panel(player: Player) -> void:
	_check(InputMap.has_action("debug_tuning_panel") and _action_has_key("debug_tuning_panel", KEY_F5), "debug_tuning_panel is on F5")
	_check(_action_has_key("debug_tuning_big_step", KEY_SHIFT), "Shift is the big-step key")
	_check(_action_has_key("debug_tuning_reset", KEY_R), "R resets a value in the panel")
	var panel: TuningPanel = get_tree().get_first_node_in_group(&"tuning_panel") as TuningPanel
	_check(panel != null, "the debug overlay created a TuningPanel")
	if panel == null:
		return

	# F5 opens it and pauses the game.
	var f5_press: InputEventAction = InputEventAction.new()
	f5_press.action = &"debug_tuning_panel"
	f5_press.pressed = true
	get_viewport().push_input(f5_press)
	_check(panel.is_open() and get_tree().paused, "F5 opens the panel and pauses the game")
	_check(panel.tab_names == ["Player", "Earth", "Fire"], "three tabs: Player, Earth, Fire, got %s" % [panel.tab_names])

	# Rows come from the property list: groups, exported vars, no Resource internals.
	var labels: Array[String] = []
	var groups: Array[String] = []
	for row: Dictionary in panel.rows:
		if row["kind"] == "group":
			groups.append(row["text"])
		else:
			labels.append(row["label"])
	_check(groups.has("Run") and labels.has("max_run_speed"), "the Player tab lists the Run group and max_run_speed")
	_check(not labels.has("resource_name") and not labels.has("script"), "Resource's own fields are not listed")
	_check(labels.has("jump_squash.x") and labels.has("jump_squash.y"), "a Vector2 gets an x row and a y row")

	# Stepping a float: magnitude step (90 -> 1), Shift x10, R back to the saved value.
	var tuning: PlayerTuning = player.tuning
	var saved_speed: float = tuning.max_run_speed
	panel.select_property("max_run_speed")
	panel.change_selected(1)
	_check(is_equal_approx(tuning.max_run_speed, saved_speed + 1.0), "Right raises max_run_speed by 1 (live on the resource)")
	panel.change_selected(1, true)
	_check(is_equal_approx(tuning.max_run_speed, saved_speed + 11.0), "Shift+Right raises it by 10 more")
	panel.reset_selected()
	_check(is_equal_approx(tuning.max_run_speed, saved_speed), "R puts it back to the saved value")

	# Vector2 half, bool flip.
	var saved_squash: Vector2 = tuning.jump_squash
	panel.select_property("jump_squash", "y")
	panel.change_selected(-1)
	_check(is_equal_approx(tuning.jump_squash.x, saved_squash.x) and tuning.jump_squash.y < saved_squash.y, "a Vector2 row changes only its own half")
	panel.reset_selected()
	var saved_flag: bool = tuning.dash_uses_stamina
	panel.select_property("dash_uses_stamina")
	panel.change_selected(1)
	_check(tuning.dash_uses_stamina != saved_flag, "Left/Right flips a bool")
	panel.reset_selected()

	# Fire tab: an int with an @export_range clamps at its max.
	panel.show_tab_named("Fire")
	var fire_tuning: FireTuning = player.fire_tuning
	var saved_pips: int = fire_tuning.max_pips
	panel.select_property("max_pips")
	for press: int in 20:
		panel.change_selected(1)
	_check(fire_tuning.max_pips == 10, "max_pips stops at its range max (10), got %d" % fire_tuning.max_pips)
	panel.reset_selected()
	_check(fire_tuning.max_pips == saved_pips, "R puts max_pips back")
	panel.switch_tab(1)
	_check(panel.tab_names[panel.current_tab] == "Player", "PageDown wraps from Fire to Player")

	# Closing resumes the game and tells listeners through Resource.changed.
	var heard_changed: Array[bool] = [false]
	var on_changed: Callable = func() -> void: heard_changed[0] = true
	fire_tuning.changed.connect(on_changed)
	panel.set_open(false)
	fire_tuning.changed.disconnect(on_changed)
	_check(not panel.is_open() and not get_tree().paused, "closing the panel resumes the game")
	_check(heard_changed[0], "closing emits `changed` on an edited resource")
	finished_sections.append("F2")


## Stage F3: the flame jet. Presses W/arrows/C through Input.action_press(), so it
## goes through the real states, and measures what one burst does.
func _check_f3_flame_jet(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var bar: FireBar = player.fire_bar
	var room_b: Room = world.get_node("RoomFireB") as Room
	world.jump_to_room(room_b)
	await _physics_frames(10)  # land on the floor
	_check(GameState.current_room == room_b and bar.pips == 0, "Fire B starts with 0 pips, got %d" % bar.pips)
	_check(player.has_node("FlameJetAbility") and player.state_machine.has_node("Jetting"), "the player has FlameJetAbility and a Jetting state")

	# No pip: a sputter, no state change.
	var sputter_count: Array[int] = [0]
	var on_sputter: Callable = func() -> void: sputter_count[0] += 1
	player.flame_jet.sputtered.connect(on_sputter)
	await _tap(&"flame_jet")
	_check(sputter_count[0] == 1 and not player.is_jetting(), "W with 0 pips sputters and doesn't jet")

	# One burst straight up (no arrow): pip spent, gravity off, ends after jet_burst_time.
	bar.gain(1)
	var start_y: float = player.global_position.y
	await _tap(&"flame_jet")
	_check(player.is_jetting() and bar.pips == 0, "W with a pip starts Jetting and spends it")
	var burst_frames: int = 1  # the tap's second frame was already a burst frame
	var lowest_upward_speed: float = -INF  # the largest velocity.y seen (closest to falling)
	while player.is_jetting() and burst_frames < 120:
		await get_tree().physics_frame
		burst_frames += 1
		if burst_frames > 6:
			lowest_upward_speed = maxf(lowest_upward_speed, player.velocity.y)
	var rise: float = start_y - player.global_position.y
	var expected_frames: int = roundi(tuning.jet_burst_time * Engine.physics_ticks_per_second)
	_check(absi(burst_frames - expected_frames) <= 2, "a burst lasts jet_burst_time (%d frames, expected ~%d)" % [burst_frames, expected_frames])
	_check(lowest_upward_speed < 0.0, "no arrow = up, and gravity never wins during the burst (slowest rise %.1f px/s)" % -lowest_upward_speed)
	_check(player.state_machine.current_state.name == &"Fall", "after the burst: Fall (normal gravity), got %s" % player.state_machine.current_state.name)
	print("  INFO  one burst from standing rises %.1f px (Fire_bending.md §5.2 guide: 80-90)" % rise)
	_check(rise > 60.0 and rise < 120.0, "one burst carries roughly 80-90 px, got %.1f" % rise)
	await _physics_frames(60)  # fall back down

	# Hold W: a second pip chains at the end of the first burst.
	player.respawn_at(room_b.get_spawn_position())
	await _physics_frames(5)
	bar.gain(2)
	var chain_count: Array[int] = [0]
	var on_burst: Callable = func(is_chain: bool) -> void: chain_count[0] += 1 if is_chain else 0
	player.flame_jet.burst_started.connect(on_burst)
	Input.action_press(&"flame_jet")
	await _physics_frames(expected_frames + 5)
	_check(player.is_jetting() and bar.pips == 0 and chain_count[0] == 1, "holding W chains the next pip (pump), pips now %d" % bar.pips)
	# Held to the end with no pip left: a sputter and the flight ends.
	sputter_count[0] = 0
	await _physics_frames(expected_frames)
	_check(not player.is_jetting() and sputter_count[0] == 1, "a chain that runs dry ends in a sputter")
	Input.action_release(&"flame_jet")
	player.flame_jet.burst_started.disconnect(on_burst)
	await _physics_frames(90)

	# Jump cancels at once; the pip stays spent and the press doesn't jump.
	player.respawn_at(room_b.get_spawn_position())
	await _physics_frames(5)
	bar.gain(1)
	await _tap(&"flame_jet")
	await _physics_frames(5)
	Input.action_press(&"jump")
	await _physics_frames(2)
	_check(not player.is_jetting() and bar.pips == 0, "C cuts the burst short and the pip stays spent")
	await get_tree().physics_frame
	_check(player.state_machine.current_state.name == &"Fall" and player.jump_buffer_remaining == 0.0,
		"the cancel press doesn't also jump or glide (state %s)" % player.state_machine.current_state.name)
	Input.action_release(&"jump")
	await _physics_frames(60)

	# Steering: Right held = thrust right, and the jet collects a diamond mid-burst.
	player.respawn_at(room_b.get_spawn_position())
	await _physics_frames(5)
	bar.gain(1)
	Input.action_press(&"move_right")
	await _tap(&"flame_jet")
	await _physics_frames(4)
	_check(player.velocity.x > 100.0 and absf(player.velocity.y) < 5.0, "Right steers the burst right, velocity %s" % player.velocity)
	# The diamond is 60 px ahead of the spawn: well inside one burst.
	await _physics_frames(20)
	_check(bar.pips == 1, "the gap diamond is collected mid-burst (pips %d)" % bar.pips)
	Input.action_release(&"move_right")
	await _physics_frames(30)

	# Bonk: straight up into the ledge's underside ends the burst early.
	player.respawn_at(room_b.global_position + Vector2(290, 160))  # 20 px under the ledge
	bar.reset_to_room_start()
	bar.gain(1)
	await _tap(&"flame_jet")
	var frames_until_end: int = 0
	while player.is_jetting() and frames_until_end < 120:
		await get_tree().physics_frame
		frames_until_end += 1
	_check(frames_until_end < expected_frames - 5, "hitting a ceiling head-on ends the burst early (after %d frames)" % frames_until_end)

	# Every jet value is in FireTuning, so the F5 panel lists it.
	_check(tuning.jet_burst_time == 0.5 and tuning.jet_max_speed == 170.0 and tuning.jet_end_carry == 1.0, "jet values start at the spec numbers")
	var panel: TuningPanel = get_tree().get_first_node_in_group(&"tuning_panel") as TuningPanel
	panel.set_open(true)
	panel.show_tab_named("Fire")
	var has_jet_rows: bool = panel.select_property("jet_accel") and panel.select_property("jet_thrust_curve")
	panel.set_open(false)
	_check(has_jet_rows, "the panel's Fire tab lists the jet values (jet_thrust_curve read-only)")
	player.flame_jet.sputtered.disconnect(on_sputter)
	finished_sections.append("F3")


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


## Presses an action, lets the player see it, then releases it. Two frames: the
## tree's physics_frame signal fires BEFORE the nodes' _physics_process, so after one
## await the player hasn't read the press yet.
func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)


func _physics_frames(count: int) -> void:
	for frame: int in count:
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

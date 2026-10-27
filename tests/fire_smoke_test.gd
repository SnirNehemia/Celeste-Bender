extends Node
## Headless smoke test for the Fire chapter (Stages F1+). Not part of the game.
##
## Loads tests/fire_test_world.tscn and checks, by script, what can be checked
## without a person at the keyboard. Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/fire_smoke_test.tscn
## Every Fire stage adds a section here (Fire_bending.md §13).

const WORLD_SCENE: PackedScene = preload("res://tests/fire_test_world.tscn")
const HEAT_RECEIVER_SCRIPT: Script = preload("res://tests/heat_test_receiver.gd")

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
	await _check_f4_fireball(world, world.player)
	await _check_f5_burning_grass(world, world.player)
	await _check_f6_thicket(world, world.player)
	await _check_f7_bonfire(world, world.player)
	await _check_f8_burning_objects(world, world.player)
	await _check_f11_enemies(world, world.player)
	await _check_f11b_elephant(world, world.player)
	await _check_f12_shell(world, world.player)

	for section_name: String in ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F11", "F11b", "F12"]:
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
	# Every element is on in the Fire TEST rooms (F7 play-test); the chapter rooms
	# (Stage F14) will be Fire-only.
	_check(player.is_element_allowed(Player.ELEMENT_AIR), "Air is on in Fire A (test room)")
	_check(player.is_element_allowed(Player.ELEMENT_EARTH), "Earth is on in Fire A (test room)")
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
	_check(panel.tab_names == ["Player", "Earth", "Fire", "Water"], "four tabs: Player, Earth, Fire, Water (since W1), got %s" % [panel.tab_names])

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
	var saved_flag: bool = tuning.gust_uses_stamina
	panel.select_property("gust_uses_stamina")
	panel.change_selected(1)
	_check(tuning.gust_uses_stamina != saved_flag, "Left/Right flips a bool")
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
	panel.switch_tab(2)
	_check(panel.tab_names[panel.current_tab] == "Player", "PageDown from Fire goes to Water, then wraps to Player")

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


## Stage F4: fireball (Q) through the shared GustAim state, the Flammable contract,
## braziers opening doors, the jet plume lighting things, FireHazard.
func _check_f4_fireball(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var bar: FireBar = player.fire_bar
	var room_c: Room = world.get_node("RoomFireC") as Room
	var pit_brazier: Brazier = room_c.get_node("BrazierPit") as Brazier
	var pit_door: Door = room_c.get_node("DoorPit") as Door
	var timed_brazier: Brazier = room_c.get_node("BrazierTimed") as Brazier
	var tunnel_brazier: Brazier = room_c.get_node("BrazierTunnel") as Brazier
	world.jump_to_room(room_c)
	await _physics_frames(10)
	_check(bar.pips == 2, "Fire C starts with 2 pips, got %d" % bar.pips)
	_check(pit_brazier.is_in_group(Flammable.GROUP) and not pit_brazier.is_on() and pit_door.open_amount == 0.0,
		"braziers start unlit and flammable, the pit door closed")

	# 0 pips: Q fizzles, no aim.
	var fizzle_count: Array[int] = [0]
	var on_fizzle: Callable = func() -> void: fizzle_count[0] += 1
	player.fireball.fizzled.connect(on_fizzle)
	bar.spend()
	bar.spend()
	await _tap(&"fireball")
	_check(fizzle_count[0] == 1 and player.state_machine.current_state.name != &"GustAim",
		"Q with 0 pips fizzles and doesn't aim")
	player.fireball.fizzled.disconnect(on_fizzle)

	# Hold Q: slow-motion aim (the shared GustAim state); C cancels and keeps the pip.
	bar.gain(1)
	Input.action_press(&"fireball")
	await _physics_frames(4)
	_check(player.state_machine.current_state.name == &"GustAim" and player.aim_source == player.fireball,
		"holding Q aims in GustAim with the fireball as its aim source")
	_check(is_equal_approx(Engine.time_scale, tuning.fireball_aim_time_scale),
		"the world slows to fireball_aim_time_scale (%.2f), got %.2f" % [tuning.fireball_aim_time_scale, Engine.time_scale])
	Input.action_press(&"jump")
	await _physics_frames(2)
	Input.action_release(&"jump")
	Input.action_release(&"fireball")
	await _physics_frames(2)
	_check(player.state_machine.current_state.name != &"GustAim" and bar.pips == 1 and is_equal_approx(Engine.time_scale, 1.0),
		"C cancels the aim: pip kept (%d), normal speed, state %s" % [bar.pips, player.state_machine.current_state.name])
	_check(player.state_machine.current_state.name != &"Jump", "the cancel press doesn't also jump")
	await _physics_frames(20)

	# Tap Q facing right: the fireball flies over the pit and lights the brazier,
	# which opens its door.
	player.facing_direction = 1.0
	var thrown_balls: Array[Fireball] = []
	var on_thrown: Callable = func(ball: Fireball) -> void: thrown_balls.append(ball)
	player.fireball.thrown.connect(on_thrown)
	await _tap(&"fireball")
	await _physics_frames(3)
	player.fireball.thrown.disconnect(on_thrown)
	_check(thrown_balls.size() == 1 and bar.pips == 0, "a tap of Q throws one fireball and spends the pip (pips %d)" % bar.pips)
	if thrown_balls.size() == 1:
		var ball: Fireball = thrown_balls[0]
		_check(ball.direction == Vector2.RIGHT, "no arrow held: thrown the way the player faces, got %s" % ball.direction)
	await _wait_until(func() -> bool: return pit_brazier.is_on(), 1.5)
	_check(pit_brazier.is_on(), "the fireball lights the brazier across the pit")
	await _physics_frames(20)
	_check(pit_door.open_amount > 0.9, "the lit brazier opens its door (open %.2f)" % pit_door.open_amount)

	# Range: a fireball in open air gutters out after fireball_max_range.
	var short_tuning: FireTuning = tuning.duplicate() as FireTuning
	short_tuning.fireball_max_range = 20.0
	var finish_log: Array = []
	var stray: Fireball = Fireball.launch(world, room_c.global_position + Vector2(100, 60), Vector2.RIGHT, short_tuning, null)
	stray.finished.connect(func(hit_node: Node) -> void: finish_log.append(hit_node))
	await _wait_until(func() -> bool: return not finish_log.is_empty(), 1.0)
	_check(finish_log.size() == 1 and finish_log[0] == null, "a fireball gutters out at its max range without hitting anything")

	# Splash: lighting near a brazier (within fireball_splash) lights it too.
	var splash_point: Vector2 = timed_brazier.get_fire_rect().position + Vector2(-tuning.fireball_splash + 1.0, 4.0)
	Flammable.ignite_near(get_tree(), splash_point, tuning.fireball_splash, null)
	_check(timed_brazier.is_on(), "a flame within fireball_splash px lights a flammable")

	# Timed brazier: goes out after burn_time; the door follows.
	var timed_door: Door = room_c.get_node("DoorTimed") as Door
	await _physics_frames(10)
	_check(timed_door.wants_open, "the timed brazier opens its door while lit")
	await _wait_until(func() -> bool: return not timed_brazier.is_on(), timed_brazier.burn_time + 0.5)
	_check(not timed_brazier.is_on() and not timed_door.wants_open, "the timed brazier goes out after %.1f s and its door closes" % timed_brazier.burn_time)

	# The jet plume lights what it touches: hover just above the tunnel brazier and
	# jet up (no arrow), so the plume points down onto it.
	player.respawn_at(tunnel_brazier.global_position + Vector2(0, -26))
	bar.gain(1)
	await _tap(&"flame_jet")
	await _physics_frames(4)
	_check(tunnel_brazier.is_on(), "the jet plume lights a brazier it touches")
	await _physics_frames(40)

	# Q mid-jet: an instant throw along the steered direction; the burst goes on.
	player.respawn_at(room_c.get_spawn_position())
	await _physics_frames(5)
	var pips_before_flight: int = bar.pips
	var mid_jet_balls: Array[Fireball] = []
	var on_mid_jet_throw: Callable = func(ball: Fireball) -> void: mid_jet_balls.append(ball)
	player.fireball.thrown.connect(on_mid_jet_throw)
	await _tap(&"flame_jet")
	await _physics_frames(3)
	await _tap(&"fireball")
	player.fireball.thrown.disconnect(on_mid_jet_throw)
	_check(mid_jet_balls.size() == 1 and mid_jet_balls[0].direction == Vector2.UP,
		"Q mid-jet throws at once along the steered direction (up)")
	_check(player.is_jetting() and bar.pips == pips_before_flight - 2,
		"the burst goes on; jet + throw cost a pip each (%d -> %d)" % [pips_before_flight, bar.pips])
	await _physics_frames(60)

	# FireHazard kills the player through die(); the player's own fire never counts.
	player.respawn_at(room_c.get_spawn_position())
	await _physics_frames(5)
	_check(not player.is_dead(), "standing next to your own fire is safe")
	var hazard: FireHazard = FireHazard.new()
	hazard.hazard_size = Vector2(12, 12)
	room_c.add_child(hazard)
	hazard.global_position = player.get_center()
	await _physics_frames(3)
	_check(player.is_dead() and hazard.is_in_group(FireHazard.GROUP), "touching a FireHazard kills the player")
	hazard.queue_free()
	await get_tree().create_timer(player.tuning.death_respawn_delay + 0.3).timeout

	# Death / R: every brazier goes out and the doors close.
	_check(not pit_brazier.is_on() and not tunnel_brazier.is_on(), "a room reset puts every brazier out")
	_check(bar.pips == 2, "and brings back the 2 starting pips")
	finished_sections.append("F4")


## Stage F5: burning grass (FireGrid). Fire D's fuse runs from cols 6-30 on the floor
## (row 20), over the grassy step at cols 16-21 (rows 18-19), under the gray shelter
## (cols 24-27, row 17) to the brazier at col 30. The jet run's patches are cols 38-41,
## 43-46 and 49-52.
func _check_f5_burning_grass(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var bar: FireBar = player.fire_bar
	var room_d: Room = world.get_node("RoomFireD") as Room
	var grid: FireGrid = room_d.get_node_or_null("FireGrid") as FireGrid
	var painter: GroundPainter = room_d.get_node("GroundPainter") as GroundPainter
	var brazier: Brazier = room_d.get_node("BrazierFuse") as Brazier
	var door: Door = room_d.get_node("DoorFuse") as Door
	_check(grid != null, "a room with fire and grass gets a FireGrid")
	if grid == null:
		return
	_check(grid.is_in_group(Flammable.GROUP) and grid.is_in_group(FireHazard.GROUP) and grid.is_in_group(Room.RESETTABLE_GROUP),
		"the grid is flammable, a fire hazard and resettable")
	var room_a: Room = world.get_node("RoomFireA") as Room
	_check((room_a.get_node("Grass") as TileMapLayer).get_used_cells().is_empty(),
		"Fire A-C are built of earth now, so a jet take-off doesn't light their floors")
	_check(tuning.spread_delay == 0.32 and tuning.burn_time == 1.6 and tuning.smolder_time == 2.5 and tuning.max_burning_tiles == 96,
		"burning grass values start at the play-tested numbers (spread 0.32 s, burn 1.6 s, smolder 2.5 s)")
	world.jump_to_room(room_d)
	await _physics_frames(10)
	_check(bar.pips == 2, "Fire D starts with 2 pips, got %d" % bar.pips)

	# Surface neighbours: along the floor, up the step's wall (not into buried grass),
	# and never onto earth.
	var foot_neighbours: Array[Vector2i] = grid.get_spread_neighbours(Vector2i(15, 20))
	_check(foot_neighbours.has(Vector2i(14, 20)) and foot_neighbours.has(Vector2i(16, 19)) and not foot_neighbours.has(Vector2i(16, 20)),
		"fire spreads along the floor and up a grassy wall, got %s" % [foot_neighbours])
	var corner_neighbours: Array[Vector2i] = grid.get_spread_neighbours(Vector2i(16, 18))
	_check(corner_neighbours.has(Vector2i(16, 19)) and corner_neighbours.has(Vector2i(17, 18)),
		"and round the step's outer corner onto its top, got %s" % [corner_neighbours])
	_check(not grid.get_spread_neighbours(Vector2i(6, 20)).has(Vector2i(5, 20)), "it never steps onto earth")
	_check(not grid.can_catch(Vector2i(16, 20)), "buried grass (no open side) can't catch")

	# The fuse: stand on the gray shelter, fireball the step.
	var ash_pixel: Vector2i = Vector2i(17 * 8 + 3, 18 * 8 + 1)  # the step's top crust
	var grass_color: Color = painter.get_pixel_color(ash_pixel)
	player.respawn_at(room_d.global_position + Vector2(26 * 8, 17 * 8))
	await _physics_frames(5)
	Fireball.launch(world, room_d.global_position + Vector2(100, 150), Vector2.RIGHT, tuning, null)
	await _wait_until(func() -> bool: return grid.burning_count > 0, 1.0)
	_check(grid.get_state(Vector2i(16, 18)) == FireGrid.State.BURNING or grid.get_state(Vector2i(16, 19)) == FireGrid.State.BURNING,
		"a fireball into the grassy step lights it at once")
	# The look follows the fire, not the tiles: it creeps across a cell from where it
	# came in, and cells get different numbers of flames at random spots.
	var lit_cell: Vector2i = Vector2i(16, 18) if grid.get_state(Vector2i(16, 18)) == FireGrid.State.BURNING else Vector2i(16, 19)
	var lit_rect: Rect2 = grid.get_cell_rect(lit_cell)
	var entry: Vector2 = grid.ignite_origin[lit_cell]
	var far_corner: Vector2 = Vector2(lit_rect.end.x if entry.x < lit_rect.get_center().x else lit_rect.position.x, lit_rect.end.y)
	_check(grid.get_creep_delay(lit_cell, far_corner) > grid.get_creep_delay(lit_cell, entry) + 0.1,
		"the fire creeps across a cell from where it came in")
	await _wait_until(func() -> bool: return grid.get_state(Vector2i(17, 18)) != FireGrid.State.GRASS, 3.0)
	var flame_counts: Dictionary = {}
	for burning_cell: Vector2i in grid.flames:
		flame_counts[(grid.flames[burning_cell] as Array).size()] = true
	_check(flame_counts.size() > 1, "burning cells get different numbers of flames, got counts %s" % [flame_counts.keys()])
	_check(grid.get_state(Vector2i(17, 18)) != FireGrid.State.GRASS, "the fire climbs the step and runs along its top")
	await _wait_until(func() -> bool: return grid.get_state(Vector2i(25, 20)) == FireGrid.State.BURNING, 8.0)
	_check(grid.get_state(Vector2i(25, 20)) == FireGrid.State.BURNING and not player.is_dead(),
		"the front passes under the gray shelter and the player on it is safe")
	await _wait_until(func() -> bool: return brazier.is_on(), 5.0)
	_check(brazier.is_on(), "the fuse lights the brazier at its end")
	await _physics_frames(30)
	_check(door.open_amount > 0.9, "and the brazier opens its door (open %.2f)" % door.open_amount)
	await _wait_until(func() -> bool: return grid.get_state(Vector2i(6, 20)) != FireGrid.State.GRASS, 4.0)
	_check(grid.get_state(Vector2i(6, 20)) != FireGrid.State.GRASS and grid.get_state(Vector2i(5, 20)) == FireGrid.State.GRASS,
		"the fire also runs back to the fuse's start and stops at the earth")
	_check(grid.peak_burning_count <= tuning.max_burning_tiles, "never more than max_burning_tiles burning (peak %d)" % grid.peak_burning_count)

	# Smolder, then ash: a firebreak painted gray.
	await _wait_until(func() -> bool: return grid.get_state(Vector2i(17, 18)) == FireGrid.State.ASH, 7.0)
	_check(grid.get_state(Vector2i(17, 18)) == FireGrid.State.ASH, "a burnt cell smolders, then turns to ash")
	_check(not grid.can_catch(Vector2i(17, 18)) and not grid.ignite_at(room_d.global_position + Vector2(17 * 8 + 4, 18 * 8), 2.0, null),
		"ash never burns again")
	var ash_color: Color = painter.get_pixel_color(ash_pixel)
	_check(absf(ash_color.r - ash_color.b) < 0.06 and ash_color.r < 0.6 and ash_color != grass_color,
		"burnt ground is painted charred or gray, got %s (grass was %s)" % [ash_color, grass_color])

	# R puts every cell back.
	room_d.reset_objects()
	await get_tree().physics_frame
	_check(grid.cell_states.is_empty() and grid.pending.is_empty() and grid.burning_count == 0 and grid.flames.is_empty(),
		"a room reset turns every cell back into grass")
	_check(painter.get_pixel_color(ash_pixel) == grass_color, "and repaints it as grass")
	_check(not brazier.is_on(), "and puts the fuse brazier out")

	# The cap: with max_burning_tiles = 3 the rest waits in the queue.
	var saved_cap: int = tuning.max_burning_tiles
	tuning.max_burning_tiles = 3
	grid.peak_burning_count = 0
	player.respawn_at(room_d.global_position + Vector2(26 * 8, 17 * 8))
	grid.ignite_at(room_d.global_position + Vector2(10 * 8 + 4, 160), 0.0, null)
	var saw_waiting: bool = false
	for frame: int in 90:
		await get_tree().physics_frame
		if grid.burning_count == 3 and not grid.pending.is_empty():
			saw_waiting = true
	tuning.max_burning_tiles = saved_cap
	_check(grid.peak_burning_count <= 3 and saw_waiting, "at the cap, extra ignitions wait in the queue (peak %d)" % grid.peak_burning_count)
	room_d.reset_objects()
	await get_tree().physics_frame

	# Burning grass kills.
	player.respawn_at(room_d.global_position + Vector2(10 * 8 + 4, 160))
	await _physics_frames(3)
	grid.ignite_at(room_d.global_position + Vector2(10 * 8 + 4, 161), 0.0, null)
	await _physics_frames(3)
	_check(player.is_dead(), "standing on burning grass kills")
	await get_tree().create_timer(player.tuning.death_respawn_delay + 0.3).timeout
	_check(grid.cell_states.is_empty() and not player.is_dead(), "dying resets the grass")

	# Jet take-off from grass: the cell under you catches a moment later, not at once.
	var take_off_cell: Vector2i = Vector2i(40, 20)
	player.respawn_at(room_d.global_position + Vector2(40 * 8 + 4, 160))
	await _physics_frames(5)
	bar.gain(1)
	await _tap(&"flame_jet")
	await _physics_frames(2)
	_check(grid.get_state(take_off_cell) == FireGrid.State.GRASS and grid.pending.has(take_off_cell),
		"taking off from grass queues the cell under you")
	await get_tree().create_timer(tuning.spread_delay + 0.1).timeout
	_check(grid.get_state(take_off_cell) == FireGrid.State.BURNING and not player.is_dead(),
		"it catches spread_delay later, when you're already up and away")
	room_d.reset_objects()
	await _physics_frames(60)

	# Jetting right along the floor lights all three patches behind you.
	player.respawn_at(room_d.global_position + Vector2(36 * 8 + 4, 160))
	await _physics_frames(5)
	bar.gain(2)
	Input.action_press(&"move_right")
	Input.action_press(&"flame_jet")
	await _physics_frames(roundi(tuning.jet_burst_time * Engine.physics_ticks_per_second) * 2 + 5)
	Input.action_release(&"flame_jet")
	Input.action_release(&"move_right")
	await get_tree().create_timer(tuning.spread_delay + 0.1).timeout
	var lit_patches: int = 0
	for patch_start: int in [38, 43, 49]:
		for column: int in range(patch_start, patch_start + 4):
			if grid.get_state(Vector2i(column, 20)) != FireGrid.State.GRASS:
				lit_patches += 1
				break
	_check(lit_patches == 3, "jetting along the floor lights every patch behind you (%d of 3)" % lit_patches)
	room_d.reset_objects()
	player.respawn_at(room_d.get_spawn_position())
	await _physics_frames(5)
	finished_sections.append("F5")


## Stage F6: thicket burns through and crumbles to open air, grass and thicket light
## each other, an overgrown cover flashes over as one and opens its hidden chamber,
## burning thicket kills (after its glow), and R brings it all back.
func _check_f6_thicket(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var room_e: Room = world.get_node("RoomFireE") as Room
	var grid: FireGrid = room_e.get_node_or_null("FireGrid") as FireGrid
	var thicket: ThicketLayer = room_e.get_node_or_null("Thicket") as ThicketLayer
	var overgrown: OvergrownLayer = room_e.get_node_or_null("Overgrown") as OvergrownLayer
	var hidden: HiddenLayer = room_e.get_node_or_null("Hidden") as HiddenLayer
	var earth: EarthLayer = room_e.get_node("Earth") as EarthLayer
	var painter: GroundPainter = room_e.get_node("GroundPainter") as GroundPainter
	var diamond: Node2D = room_e.get_node("ChamberDiamond") as Node2D
	_check(grid != null and thicket != null and overgrown != null and hidden != null,
		"Fire E has a FireGrid, a Thicket, an Overgrown and a Hidden layer")
	if grid == null or thicket == null or overgrown == null or hidden == null:
		return
	_check(tuning.thicket_spread_delay == 0.15 and tuning.thicket_burn_time == 0.8 and tuning.overgrown_flashover_time == 0.3,
		"thicket values start at the spec's numbers (spread 0.15 s, burn 0.8 s, flash-over 0.3 s)")
	world.jump_to_room(room_e)
	await _physics_frames(10)
	_check(player.fire_bar.pips == 3, "Fire E starts with 3 pips, got %d" % player.fire_bar.pips)

	# Thicket is solid ground the Earth shadow crosses, painted as brambles.
	var wall_cell: Vector2i = Vector2i(12, 10)
	_check(grid.get_fuel(wall_cell) == FireGrid.Fuel.THICKET and grid.is_solid(wall_cell) and not earth.is_shadow_blocking(wall_cell),
		"thicket is solid, burnable, and the Earth shadow may cross it")
	_check(painter.kinds.get(wall_cell) == GroundPainter.Kind.THICKET, "the painter draws it as thicket")
	_check(grid.can_catch(Vector2i(12, 10)), "buried thicket can catch (it burns through its volume)")
	# Spread: thicket to its 4 neighbours, grass into a touching cover.
	var floor_targets: Array[Vector2i] = []
	for target: Array in grid.get_spread_targets(Vector2i(22, 14)):
		floor_targets.append(target[0])
	_check(floor_targets.has(Vector2i(23, 14)) and floor_targets.has(Vector2i(22, 15)) and not floor_targets.has(Vector2i(21, 14)),
		"thicket spreads to its thicket neighbours, never into earth, got %s" % [floor_targets])
	var tuft_targets: Array[Vector2i] = []
	for target: Array in grid.get_spread_targets(Vector2i(40, 19)):
		tuft_targets.append(target[0])
	# (40, 20) under the tuft is buried: the surface walk goes round to (39, 20).
	_check(tuft_targets.has(Vector2i(41, 19)) and tuft_targets.has(Vector2i(39, 20)),
		"the grass tuft spreads along the fuse and into the touching cover, got %s" % [tuft_targets])

	# 1. A fireball into the wall: it glows, burns through, crumbles to open air.
	player.respawn_at(room_e.get_spawn_position())
	await _physics_frames(5)
	Fireball.launch(world, room_e.global_position + Vector2(60, 150), Vector2.RIGHT, tuning, null)
	await _wait_until(func() -> bool: return grid.burning_count > 0, 1.0)
	var first_lit: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in grid.cell_states:
		first_lit = cell
	_check(grid.burning_count > 0 and not grid.is_deadly(first_lit),
		"a fireball lights the thicket wall, which first only glows (harmless)")
	await _wait_until(func() -> bool: return grid.is_deadly(first_lit), 1.0)
	_check(grid.is_deadly(first_lit), "then its flames break out and kill on touch")
	var wall_gone: Callable = func() -> bool:
		for x: int in range(12, 14):
			for y: int in range(1, 20):
				if thicket.has_thicket(Vector2i(x, y)):
					return false
		return true
	await _wait_until(wall_gone, 8.0)
	_check(wall_gone.call(), "the whole wall burns through and crumbles")
	_check(grid.get_state(wall_cell) == FireGrid.State.GONE and not grid.is_solid(wall_cell),
		"a crumbled cell is open air")
	await get_tree().process_frame  # the painter's batched redraw
	_check(not painter.kinds.has(wall_cell), "and the painter draws it as air")
	_check(grid.peak_burning_count <= tuning.max_burning_tiles, "never more than max_burning_tiles burning (peak %d)" % grid.peak_burning_count)
	_check(not player.is_dead(), "the player at the start stayed safe")

	# Ash that stays (F6 play-test): light flakes that drift down slowly and swirl
	# round the player.
	var field: PebbleField = room_e.get_node("PebbleField") as PebbleField
	_check(field.ash_count > 0, "the crumbled wall leaves ash flakes in the room (%d)" % field.ash_count)
	var fastest_fall: float = 0.0
	for frame: int in 30:
		await get_tree().physics_frame
		for flake_index: int in field.pebble_positions.size():
			if field.pebble_is_ash[flake_index] == 1 and field.pebble_is_grounded[flake_index] == 0:
				fastest_fall = maxf(fastest_fall, field.pebble_velocities[flake_index].y)
	_check(fastest_fall < 45.0, "flakes fall slowly (fastest %.0f px/s; a pebble falls at hundreds)" % fastest_fall)
	await _wait_until(func() -> bool:
		for flake_index: int in field.pebble_positions.size():
			if field.pebble_is_ash[flake_index] == 1 and field.pebble_is_moving[flake_index] == 1:
				return false
		return true, 6.0)
	var settled_positions: PackedVector2Array = field.pebble_positions.duplicate()
	player.respawn_at(room_e.global_position + Vector2(9 * 8, 160))
	await _physics_frames(3)
	Input.action_press(&"move_right")
	await _physics_frames(30)
	Input.action_release(&"move_right")
	var stirred: int = 0
	for flake_index: int in mini(field.pebble_positions.size(), settled_positions.size()):
		if field.pebble_is_ash[flake_index] == 1 and field.pebble_positions[flake_index].distance_to(settled_positions[flake_index]) > 1.0:
			stirred += 1
	_check(stirred > 0, "walking through the ash stirs it (%d flakes moved)" % stirred)

	# 2. The thicket floor burns away; standing over the hole, you drop to the corridor.
	grid.ignite_at(room_e.global_position + Vector2(22 * 8, 14 * 8 + 4), 1.0, null)
	var floor_gone: Callable = func() -> bool:
		for x: int in range(22, 28):
			for y: int in range(14, 16):
				if thicket.has_thicket(Vector2i(x, y)):
					return false
		return true
	await _wait_until(floor_gone, 6.0)
	_check(floor_gone.call(), "the thicket floor burns away")
	await _wait_until(func() -> bool: return grid.burning_count == 0, 3.0)
	player.respawn_at(room_e.global_position + Vector2(25 * 8, 13 * 8))
	await _physics_frames(45)
	_check(player.global_position.y > room_e.global_position.y + 19 * 8 and not player.is_dead(),
		"over the hole you drop to the corridor below (feet at y %.0f)" % (player.global_position.y - room_e.global_position.y))

	# 3. The overgrown cover: a thicket bush with browner leaves and roots; the diamond
	# behind it hidden.
	_check(painter.overgrown_cells.has(Vector2i(41, 17)) and painter.kinds.get(Vector2i(41, 17)) == GroundPainter.Kind.THICKET,
		"the cover is painted as thicket")
	var cover_leaves: ThicketLeaves = overgrown.get_node_or_null("Leaves") as ThicketLeaves
	var thicket_leaves: ThicketLeaves = thicket.get_node("Leaves") as ThicketLeaves
	var cover_redness: float = 0.0
	var thicket_redness: float = 0.0
	if cover_leaves != null and not cover_leaves.leaf_colors.is_empty():
		for color: Color in cover_leaves.leaf_colors:
			cover_redness += color.r / color.g
		cover_redness /= cover_leaves.leaf_colors.size()
		for color: Color in thicket_leaves.leaf_colors:
			thicket_redness += color.r / color.g
		thicket_redness /= thicket_leaves.leaf_colors.size()
	_check(cover_leaves != null and cover_leaves.leaf_anchors.size() > 20 and cover_redness > thicket_redness + 0.1,
		"it grows the thicket's bush, its leaves browner (red/green %.2f vs %.2f)" % [cover_redness, thicket_redness])
	_check(hidden.is_object_hidden(diamond) and not diamond.visible, "the diamond in the chamber is hidden")
	_check(painter.kinds.get(Vector2i(45, 17)) == GroundPainter.Kind.THICKET, "the covered chamber looks like the cover, not earth")
	grid.ignite_at(room_e.global_position + Vector2(37 * 8, 20 * 8), 1.0, null)
	await _wait_until(func() -> bool: return grid.get_state(Vector2i(41, 19)) == FireGrid.State.BURNING, 6.0)
	var all_flashing: bool = true
	for x: int in range(41, 43):
		for y: int in range(15, 20):
			all_flashing = all_flashing and grid.get_state(Vector2i(x, y)) == FireGrid.State.BURNING
	_check(all_flashing, "the fuse reaches the cover and the WHOLE cover flashes over at once")
	await _wait_until(func() -> bool: return not overgrown.has_cover(Vector2i(41, 19)), 1.0)
	var all_gone: bool = true
	for x: int in range(41, 43):
		for y: int in range(15, 20):
			all_gone = all_gone and not overgrown.has_cover(Vector2i(x, y))
	_check(all_gone, "it collapses all at once, within overgrown_flashover_time")
	_check(not hidden.is_covered(Vector2i(45, 17)), "and the chamber behind it opens")
	await get_tree().create_timer(1.0).timeout
	_check(not hidden.is_object_hidden(diamond) and diamond.visible, "the fire diamond inside appears")

	# R: thicket, cover, chamber and diamond all back.
	room_e.reset_objects()
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(thicket.has_thicket(wall_cell) and thicket.has_thicket(Vector2i(24, 14)) and overgrown.has_cover(Vector2i(41, 17)),
		"a room reset puts the thicket and the cover back")
	_check(hidden.is_covered(Vector2i(45, 17)) and hidden.is_object_hidden(diamond), "and covers the chamber, hiding the diamond again")
	_check(grid.cell_states.is_empty() and grid.burning_count == 0 and grid.pending.is_empty(), "and the grid forgets every fire")
	await get_tree().process_frame
	_check(painter.kinds.get(wall_cell) == GroundPainter.Kind.THICKET, "and the painter draws the thicket again")

	# Burning thicket kills (once its flames are out).
	player.respawn_at(room_e.global_position + Vector2(11 * 8 + 4, 160))
	await _physics_frames(3)
	grid.ignite_at(room_e.global_position + Vector2(12 * 8, 18 * 8 + 4), 0.5, null)
	await _physics_frames(2)
	_check(not player.is_dead(), "touching thicket that only glows is safe")
	# Game time (physics frames), not a wall-clock timer: a busy frame must not let the
	# check run before the fire has had its time.
	await _wait_until(func() -> bool: return player.is_dead(), tuning.thicket_burn_time * 0.5)
	_check(player.is_dead(), "touching burning thicket kills")
	await get_tree().create_timer(player.tuning.death_respawn_delay + 0.3).timeout
	_check(grid.cell_states.is_empty() and thicket.has_thicket(Vector2i(12, 18)) and not player.is_dead(),
		"dying resets the thicket")
	room_e.reset_objects()
	await _physics_frames(5)

	# Leaves (F6 play-test): on every open face, pushed by the player and by gusts.
	var leaves: ThicketLeaves = thicket.get_node_or_null("Leaves") as ThicketLeaves
	_check(leaves != null and leaves.leaf_anchors.size() > 40, "thicket grows leaves on its open faces (%d)" % (leaves.leaf_anchors.size() if leaves != null else 0))
	if leaves != null:
		player.respawn_at(room_e.global_position + Vector2(11 * 8 + 4, 160))
		await _physics_frames(20)
		var most_bent: float = 0.0
		for leaf_index: int in leaves.leaf_anchors.size():
			if leaves.leaf_cells[leaf_index].y >= 18:
				most_bent = maxf(most_bent, leaves.leaf_bends[leaf_index].length())
		_check(most_bent > tuning.leaf_idle_sway + 0.3, "the player standing against the wall pushes its leaves (%.1f px)" % most_bent)
		leaves.receive_gust_from(Vector2.RIGHT, 160.0, room_e.global_position + Vector2(80, 80))
		var kicked: int = 0
		for leaf_index: int in leaves.leaf_anchors.size():
			if leaves.leaf_bend_speeds[leaf_index].x > 20.0:
				kicked += 1
		_check(kicked > 10, "a gust whips the leaves near it (%d)" % kicked)

	# The jet's take-off only scorches the floor when the flame points at it: standing
	# on the thicket floor, flame pointing UP (thrust down) leaves it alone.
	player.respawn_at(room_e.global_position + Vector2(24 * 8 + 4, 14 * 8))
	await _physics_frames(5)
	player.fire_bar.gain(1)
	# Down held through the whole burst (let go and it steers up: the flame then
	# points down and rightly lights the floor).
	Input.action_press(&"move_down")
	await _tap(&"flame_jet")
	await get_tree().create_timer(tuning.jet_burst_time + 0.1).timeout
	Input.action_release(&"move_down")
	_check(grid.get_state(Vector2i(24, 14)) == FireGrid.State.GRASS and not grid.pending.has(Vector2i(24, 14)),
		"a flame pointing up doesn't scorch the thicket floor under you")
	room_e.reset_objects()
	player.respawn_at(room_e.global_position + Vector2(24 * 8 + 4, 14 * 8))
	await _physics_frames(5)
	player.fire_bar.gain(1)
	await _tap(&"flame_jet")
	await _physics_frames(3)
	_check(grid.pending.has(Vector2i(24, 14)) or grid.get_state(Vector2i(24, 14)) != FireGrid.State.GRASS,
		"a flame pointing down (thrust up) still lights the floor you take off from")
	await get_tree().create_timer(1.5).timeout
	room_e.reset_objects()
	player.respawn_at(room_e.get_spawn_position())
	await _physics_frames(5)
	finished_sections.append("F6")



## Stage F7: hot updrafts (WindZone.heat) lift only gliders and heat receivers; the
## LEAVES burn (F7 play-test): a lone burning leaf is a harmless ember, a heap of them
## becomes a bonfire that grows amber -> low -> tall, a close gust scatters it; leaves
## stack; burning grass gives a weak updraft; flames turn a wind crystal into a +1 and
## a gust diamond into a +2 fire diamond; R puts it all back.
func _check_f7_bonfire(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var room_f: Room = world.get_node("RoomFireF") as Room
	var elevator_pile: LeafPile = room_f.get_node("ElevatorPile") as LeafPile
	var hiding_pile: LeafPile = room_f.get_node("HidingPile") as LeafPile
	var rain_pile: LeafPile = room_f.get_node("RainPile") as LeafPile
	var crystal: WindCrystal = room_f.get_node("HiddenCrystal") as WindCrystal
	var gust_diamond: GustDiamond = room_f.get_node("GapGustDiamond") as GustDiamond
	var grid: FireGrid = room_f.get_node_or_null("FireGrid") as FireGrid
	_check(room_f.air_allowed and room_f.fire_allowed and room_f.earth_allowed and room_f.fire_start_pips == 5,
		"Fire F allows every element and starts with 5 pips")
	var all_elements: bool = true
	for room_name: String in ["RoomFireA", "RoomFireB", "RoomFireC", "RoomFireD", "RoomFireE"]:
		var test_room: Room = world.get_node(room_name) as Room
		all_elements = all_elements and test_room.air_allowed and test_room.earth_allowed and test_room.fire_allowed
	_check(all_elements, "every Fire test room allows Air, Earth and Fire")
	_check(grid != null, "Fire F has a FireGrid (its grass patches)")
	if grid == null:
		return
	_check(tuning.hot_updraft_lift > 60.0 * player.tuning.glide_updraft_lift_multiplier,
		"a hot updraft lifts a glider harder than an Air updraft (%.0f px/s)" % tuning.hot_updraft_lift)
	_check(elevator_pile.is_in_group(Flammable.GROUP) and crystal.is_in_group(Flammable.GROUP)
		and gust_diamond.is_in_group(Flammable.GROUP),
		"leaf piles, wind crystals and gust diamonds are flammable")
	world.jump_to_room(room_f)
	await _physics_frames(10)
	_check(player.fire_bar.pips == 5, "Fire F gives 5 pips, got %d" % player.fire_bar.pips)

	# A hand-made heat zone: no wind, lift only by asking, and heat receivers get it.
	var zone: WindZone = WindZone.new()
	zone.heat = true
	zone.zone_size = Vector2(16, 48)
	zone.wind_strength = 100.0
	room_f.add_child(zone)
	zone.position = Vector2(150, 100)
	var receiver: Node2D = HEAT_RECEIVER_SCRIPT.new() as Node2D
	room_f.add_child(receiver)
	receiver.position = Vector2(158, 120)
	await _physics_frames(5)
	var inside: Vector2 = room_f.global_position + Vector2(158, 120)
	_check(zone.get_wind_velocity() == Vector2.ZERO and zone.is_in_group(Heat.SOURCE_GROUP),
		"a heat zone blows no wind and is a heat source")
	_check(is_equal_approx(Heat.get_lift_at(get_tree(), inside), 100.0)
		and Heat.get_lift_at(get_tree(), inside + Vector2(30, 0)) == 0.0,
		"its lift is wind_strength inside and 0 outside")
	_check(float(receiver.get("strongest")) == 100.0, "a heat receiver inside it gets apply_heat(100)")
	# On foot (falling, not gliding) hot air does nothing.
	player.respawn_at(room_f.global_position + Vector2(158, 130))
	player.velocity = Vector2.ZERO
	player.state_machine.transition_to(&"Fall")
	await _physics_frames(10)
	_check(player.velocity.y > 0.0, "a player who isn't gliding falls through hot air (vy %.0f)" % player.velocity.y)
	zone.queue_free()
	receiver.queue_free()

	# Leaves stack: a leaf dropped over the pile comes to rest ON the pile, not on
	# the floor under it.
	var dropped_leaf: int = 0
	elevator_pile.leaf_positions[dropped_leaf] = Vector2(0, -30)
	elevator_pile._launch_leaf(dropped_leaf, Vector2.ZERO)
	await _wait_until(func() -> bool: return elevator_pile.leaf_is_flying[dropped_leaf] == 0, 4.0)
	var rest_y: float = elevator_pile.leaf_positions[dropped_leaf].y
	_check(elevator_pile.leaf_is_flying[dropped_leaf] == 0 and rest_y < -3.0
		and elevator_pile.leaf_support_leaves[dropped_leaf] != LeafPile.NO_LEAF,
		"a falling leaf lands on top of the heap (rests at y %.1f on another leaf)" % rest_y)
	# Density: no column of the untouched mound is left bare.
	var bare_columns: int = 0
	var half_width: int = int(rain_pile.pile_width / 2.0) - 2
	for column: int in range(-half_width, half_width + 1):
		var covered: bool = false
		for home: Vector2 in rain_pile.home_positions:
			if absf(home.x - column) <= 2.0:
				covered = true
				break
		if not covered:
			bare_columns += 1
	_check(bare_columns == 0, "the untouched pile has no bare columns (%d)" % bare_columns)
	# Running through the pile (a kick through its middle column): when the leaves
	# have settled, none hangs in the air with nothing under it.
	for leaf_index: int in rain_pile.leaf_positions.size():
		if absf(rain_pile.leaf_positions[leaf_index].x) < 4.0:
			rain_pile._launch_leaf(leaf_index, Vector2(randf_range(40.0, 80.0), -randf_range(40.0, 80.0)))
	await get_tree().create_timer(5.0).timeout
	var hanging: int = 0
	for leaf_index: int in rain_pile.leaf_positions.size():
		if rain_pile.leaf_is_flying[leaf_index] == 0 and rain_pile.leaf_supports[leaf_index] == null \
				and not rain_pile._has_something_under(leaf_index):
			hanging += 1
	_check(hanging == 0, "after a kick through the pile, no leaf hangs in the air (%d)" % hanging)
	rain_pile.reset()
	elevator_pile.reset()

	# 1. A fireball into the elevator pile: the leaves catch, the heap glows amber,
	# then a low flame breaks out and grows into a full bonfire.
	player.respawn_at(room_f.get_spawn_position())
	await _physics_frames(5)
	var through_ball: Fireball = Fireball.launch(world, room_f.global_position + Vector2(36, 153), Vector2.RIGHT, tuning, null)
	var through_hit: Array[Node] = []
	through_ball.finished.connect(func(hit: Node) -> void: through_hit.append(hit))
	await _wait_until(func() -> bool: return elevator_pile.is_burning(), 1.0)
	_check(elevator_pile.is_burning(), "a fireball lights the pile's leaves")
	# Past the pile, done, or bounced (since Stage F12 it bounces off the bare wall just
	# beyond and would fly back in: either way it didn't stop on the leaves).
	var pile_right: float = elevator_pile.global_position.x + 16.0
	await _wait_until(func() -> bool: return not through_hit.is_empty() \
		or (is_instance_valid(through_ball) and (through_ball.global_position.x > pile_right or through_ball.bounce_count > 0)), 1.0)
	_check(through_hit.is_empty() or (through_hit[0] != elevator_pile and through_hit[0].get_parent() != elevator_pile),
		"and flies on through it (it bursts on %s, not on the leaves)" % [through_hit])
	# Gone now: bouncing back off the wall it would fly into the young bonfire.
	if is_instance_valid(through_ball):
		through_ball.queue_free()
	await _wait_until(func() -> bool: return elevator_pile.fire != null and not elevator_pile.fire.get_lit_bonfires().is_empty(), 1.0)
	var bonfire: Bonfire = null
	if elevator_pile.fire != null and not elevator_pile.fire.get_lit_bonfires().is_empty():
		bonfire = elevator_pile.fire.get_lit_bonfires()[0]
	_check(bonfire != null and bonfire.stage == Bonfire.Stage.AMBER and not bonfire.hazard.active,
		"the burning heap becomes a bonfire that starts amber (harmless)")
	if bonfire == null:
		return
	_check(bonfire.width >= tuning.bonfire_min_width and bonfire.width <= tuning.bonfire_max_width,
		"the bonfire is as wide as the heap (%.0f px, pile 24 px)" % bonfire.width)
	await _wait_until(func() -> bool: return bonfire.stage == Bonfire.Stage.LOW, 1.5)
	var low_height: float = bonfire.get_flame_height()
	_check(bonfire.stage == Bonfire.Stage.LOW and bonfire.hazard.active and low_height < tuning.bonfire_flame_height * 0.5,
		"then a LOW flame breaks out (%.0f px) that kills" % low_height)
	_check(Heat.get_lift_at(get_tree(), bonfire.global_position + Vector2(0, -low_height - 8)) > 0.0,
		"and its hot air already lifts")
	await _wait_until(func() -> bool: return bonfire.stage == Bonfire.Stage.FULL, 2.0)
	var merged_tongues: int = 0
	for flame: FlameTongue in bonfire.flames:
		if flame.visible and flame.merge != null:
			merged_tongues += 1
	_check(merged_tongues >= 3, "the bonfire's tongues are drawn as one merged fire (%d tongues)" % merged_tongues)
	_check(is_equal_approx(bonfire.get_flame_height(), tuning.bonfire_flame_height), "then it grows to full height")
	var flame_top: Vector2 = bonfire.global_position + Vector2(0, -tuning.bonfire_flame_height)
	_check(is_equal_approx(Heat.get_lift_at(get_tree(), flame_top + Vector2(0, -20)), tuning.hot_updraft_lift),
		"a hot updraft of hot_updraft_lift stands above the flame")
	_check(grid.burning_count > 0 or not grid.cell_states.is_empty(), "the burning leaves light the grass under the pile")
	# The weak updraft over a burning cell (a fresh one at the end of the rain patch).
	var burning_cell: Vector2i = Vector2i(36, 20)
	grid.ignite_at(grid.to_global(grid.get_cell_rect(burning_cell).get_center()), 0.0, null)
	var above_cell: Vector2 = grid.to_global(grid.get_cell_rect(burning_cell).get_center() + Vector2(0, -8))
	_check(grid.get_heat_lift_at(above_cell) == tuning.grass_updraft_lift
		and grid.get_heat_lift_at(above_cell + Vector2(0, -tuning.grass_updraft_height - 4)) == 0.0,
		"burning grass gives a short, weak updraft")
	# Gliding over the bonfire lifts you; the same glide in still air sinks.
	var glide_speeds: Array[float] = []
	var glide_states: Array[String] = []
	for glide_start: Vector2 in [flame_top + Vector2(0, -24), room_f.global_position + Vector2(140, 100)]:
		player.respawn_at(glide_start)
		player.velocity = Vector2.ZERO
		# A few frames of falling first: just after the teleport the player still
		# counts as grounded (coyote time), and the press would jump instead.
		await _physics_frames(4)
		Input.action_press(&"jump")
		player.state_machine.transition_to(&"Glide")
		await _physics_frames(12)
		glide_speeds.append(player.velocity.y)
		glide_states.append(String(player.state_machine.current_state.name))
		Input.action_release(&"jump")
	_check(glide_states == ["Glide", "Glide"] and glide_speeds[0] < -60.0 and glide_speeds[1] > 0.0 and not player.is_dead(),
		"gliding over the bonfire rises (vy %.0f), gliding in still air sinks (vy %.0f) %s" % [glide_speeds[0], glide_speeds[1], glide_states])
	# The elevator's height: glide in the column for a while and note the highest
	# the feet get. Fire F's wall top (row 13, y 104) must be below that.
	player.respawn_at(flame_top + Vector2(0, -24))
	player.velocity = Vector2.ZERO
	await _physics_frames(4)
	Input.action_press(&"jump")
	player.state_machine.transition_to(&"Glide")
	var highest_feet: float = INF
	for frame: int in 90:
		await get_tree().physics_frame
		highest_feet = minf(highest_feet, player.global_position.y - room_f.global_position.y)
	Input.action_release(&"jump")
	print("  [F7] bonfire elevator: feet reach y %.0f (%.0f px above the floor), wall top y 104" % [highest_feet, 160.0 - highest_feet])
	_check(highest_feet < 100.0, "the bonfire elevator lifts the feet above Fire F's wall top")
	# The heap's leaves are held: still burning, none gone, after all this time.
	_check(elevator_pile.fire.burning_count > tuning.bonfire_min_leaves and bonfire.is_lit(),
		"a bonfire holds its leaves: they don't burn out (%d burning)" % elevator_pile.fire.burning_count)
	# Touching the flame kills.
	player.respawn_at(bonfire.global_position)
	await _physics_frames(3)
	_check(player.is_dead(), "touching the bonfire kills")
	await get_tree().create_timer(player.tuning.death_respawn_delay + 0.3).timeout
	_check(not elevator_pile.is_burning() and not bonfire.is_lit() and grid.cell_states.is_empty(),
		"dying puts the bonfire out and brings the pile and the grass back")

	# 2. The ember rain: gust the small pile up and sweep a flame through the cloud
	# (like a jet pass: a row of small ignitions). The fire spreads leaf to leaf where
	# they're close, no bonfire forms in the air, the embers don't hurt, lone leaves
	# burn away, and where they land the grass catches.
	rain_pile.receive_gust_from(Vector2.UP, 260.0, rain_pile.global_position + Vector2(0, 6))
	await _physics_frames(30)
	var cloud_y: float = 0.0
	var cloud_count: int = 0
	for leaf_index: int in rain_pile.leaf_positions.size():
		if rain_pile.leaf_is_flying[leaf_index] == 1:
			cloud_y += rain_pile.leaf_positions[leaf_index].y
			cloud_count += 1
	_check(cloud_count > 20, "a gust from below throws the small pile's leaves up (%d in the air)" % cloud_count)
	cloud_y /= maxf(cloud_count, 1.0)
	var sweep_x: float = -60.0
	while sweep_x <= 60.0:
		rain_pile.ignite_at(rain_pile.to_global(Vector2(sweep_x, cloud_y)), 6.0, null)
		sweep_x += 4.0
	await _physics_frames(10)
	var rain_fire: LeafFire = rain_pile.fire
	var burning_in_air: int = 0
	for leaf_index: int in rain_pile.leaf_positions.size():
		if rain_fire.is_leaf_burning(leaf_index) and rain_pile.leaf_is_flying[leaf_index] == 1:
			burning_in_air += 1
	_check(burning_in_air > 5 and rain_fire.get_lit_bonfires().is_empty(),
		"a flame swept through the cloud makes an ember rain (%d embers), no bonfire in the air" % burning_in_air)
	var first_ember: Vector2 = rain_pile.global_position
	# A player in the cloud of embers is fine.
	var ember_spot: Vector2 = first_ember
	for leaf_index: int in rain_pile.leaf_positions.size():
		if rain_fire.is_leaf_burning(leaf_index):
			ember_spot = rain_pile.to_global(rain_pile.leaf_positions[leaf_index])
			break
	player.respawn_at(ember_spot + Vector2(0, 5))
	await _physics_frames(3)
	_check(not player.is_dead(), "a lone burning leaf is a harmless ember")
	player.respawn_at(room_f.get_spawn_position())
	await _wait_until(func() -> bool: return rain_fire.burnt_leaf_count > 0, 3.0)
	_check(rain_fire.burnt_leaf_count > 0, "lone burning leaves burn away (%d gone)" % rain_fire.burnt_leaf_count)
	await _wait_until(func() -> bool:
		for cell: Vector2i in grid.cell_states:
			if cell.x >= 30 and cell.x <= 37:
				return true
		return false, 8.0)
	var rain_lit_grass: bool = false
	for cell: Vector2i in grid.cell_states:
		if cell.x >= 30 and cell.x <= 37:
			rain_lit_grass = true
	_check(rain_lit_grass, "the falling embers light the grass where they land")
	room_f.reset_objects()
	await _physics_frames(2)

	# 3. The hiding pile: its burning leaves convert the crystal under them; a close
	# gust scatters the heap: the bonfire goes out and its leaves fly on as embers.
	hiding_pile.ignite_at(hiding_pile.global_position + Vector2(-20, -2), 3.0, null)
	await _wait_until(func() -> bool: return crystal.is_converted, 3.0)
	var crystal_fire: FireDiamond = crystal.converted_diamond as FireDiamond
	_check(crystal.is_converted and crystal_fire != null and crystal_fire.pip_amount == 1 and not crystal.diamond.visible,
		"the burning leaves turn the hidden crystal into a +1 fire diamond")
	await _wait_until(func() -> bool: return hiding_pile.fire.get_lit_bonfires().size() > 0 \
		and hiding_pile.fire.get_lit_bonfires()[0].is_flaming(), 3.0)
	var hiding_bonfires: Array[Bonfire] = hiding_pile.fire.get_lit_bonfires()
	_check(hiding_bonfires.size() == 1 and hiding_bonfires[0].width > 30.0,
		"one wide bonfire stands on the wide heap (%s)" % [hiding_bonfires.map(func(b: Bonfire) -> float: return b.width)])
	hiding_pile.receive_gust_from(Vector2.RIGHT, 300.0, hiding_pile.global_position + Vector2(-30, -4))
	await _physics_frames(3)
	var flying_embers: int = 0
	for leaf_index: int in hiding_pile.leaf_positions.size():
		if hiding_pile.fire.is_leaf_burning(leaf_index) and hiding_pile.leaf_is_flying[leaf_index] == 1:
			flying_embers += 1
	_check(hiding_pile.fire.get_lit_bonfires().is_empty(), "a close gust scatters the heap and the bonfire goes out")
	_check(flying_embers > 10, "its leaves fly on, still burning (%d embers)" % flying_embers)
	# A gust on the embers themselves (they're lone now) blows them out into ash.
	await _physics_frames(10)
	var burning_before: int = hiding_pile.fire.burning_count
	var gone_before: int = hiding_pile.fire.burnt_leaf_count
	var ember_center: Vector2 = Vector2.ZERO
	var ember_count: int = 0
	for leaf_index: int in hiding_pile.leaf_positions.size():
		if hiding_pile.fire.is_leaf_burning(leaf_index):
			ember_center += hiding_pile.to_global(hiding_pile.leaf_positions[leaf_index])
			ember_count += 1
	ember_center /= maxf(ember_count, 1.0)
	hiding_pile.receive_gust_from(Vector2.RIGHT, 300.0, ember_center + Vector2(-10, 0))
	var blown_out: int = hiding_pile.fire.burnt_leaf_count - gone_before
	_check(blown_out > 0 and hiding_pile.fire.burning_count == burning_before - blown_out,
		"a gust on embers blows them out: %d turn to ash" % blown_out)
	# Where the scattered embers land is random, and 6+ landing together make a new
	# bonfire (as designed), which could kill the player in the steps below: put the
	# leaves back (only this pile: the crystal stays converted).
	hiding_pile.reset()
	await _physics_frames(2)
	# respawn_at() resets the pips to the room's 5 (the cap), so: respawn beside it,
	# spend two for room, then step onto it.
	player.respawn_at(crystal_fire.global_position + Vector2(24, 5))
	await _physics_frames(3)
	player.fire_bar.spend()
	player.fire_bar.spend()
	var pips_before: int = player.fire_bar.pips
	player.global_position = crystal_fire.global_position + Vector2(5, 5)
	player.velocity = Vector2.ZERO
	await _physics_frames(4)
	_check(player.fire_bar.pips == pips_before + 1 and not player.is_dead(),
		"then the crystal's fire diamond can be taken (%d -> %d)" % [pips_before, player.fire_bar.pips])

	# A gust across a grass fire puts out the burning cells it blows over (ash) and
	# stops the front there. On Fire D's first jet-run patch (cols 38-41, bare grass:
	# Fire F's patches have leaf piles on them, which would carry the fire on).
	var room_d: Room = world.get_node("RoomFireD") as Room
	var grid_d: FireGrid = room_d.get_node("FireGrid") as FireGrid
	world.jump_to_room(room_d)
	player.respawn_at(room_d.get_spawn_position())
	await _physics_frames(5)
	grid_d.ignite_at(grid_d.to_global(grid_d.get_cell_rect(Vector2i(38, 20)).get_center()), 0.0, null)
	await _wait_until(func() -> bool: return grid_d.get_state(Vector2i(39, 20)) == FireGrid.State.BURNING, 2.0)
	# A cone over columns 37-40, from the left (like a gust aimed right along the floor).
	var cone: PackedVector2Array = AirBlast.build_cone(grid_d.to_global(Vector2(37 * 8, 156)), Vector2.RIGHT, 30.0, 25.0, 6.0)
	var snuffed_cells: int = Flammable.snuff_in_area(get_tree(), cone, Vector2.RIGHT)
	_check(snuffed_cells >= 2 and grid_d.get_state(Vector2i(38, 20)) == FireGrid.State.ASH
		and grid_d.get_state(Vector2i(39, 20)) == FireGrid.State.ASH,
		"a gust over burning grass turns it to ash at once (%d cells)" % snuffed_cells)
	await get_tree().create_timer(tuning.spread_delay * 4.0 + 0.5).timeout
	_check(grid_d.get_state(Vector2i(41, 20)) == FireGrid.State.GRASS and grid_d.burning_count == 0,
		"and the fire stops there (the cell past the gust never caught)")
	room_d.reset_objects()
	world.jump_to_room(room_f)
	player.respawn_at(room_f.get_spawn_position())
	await _physics_frames(5)

	# 4. A fireball across the gap turns the gust diamond into a +2.
	player.respawn_at(room_f.global_position + Vector2(36 * 8, 160))
	await _physics_frames(5)
	Fireball.launch(world, room_f.global_position + Vector2(36 * 8 + 6, 150), Vector2.RIGHT, tuning, null)
	await _wait_until(func() -> bool: return gust_diamond.is_converted, 1.5)
	var gust_fire: FireDiamond = gust_diamond.converted_diamond as FireDiamond
	_check(gust_diamond.is_converted and gust_fire != null and gust_fire.pip_amount == 2,
		"a fireball turns the gust diamond into a +2 fire diamond")
	_check(gust_fire.fire_pip_value == 0 and not gust_fire.is_in_group(Flammable.GROUP),
		"a fire diamond can't be converted again")

	# R puts the piles and diamonds back.
	room_f.reset_objects()
	await _physics_frames(2)
	var all_home: bool = true
	for leaf_index: int in hiding_pile.leaf_positions.size():
		all_home = all_home and hiding_pile.leaf_positions[leaf_index] == hiding_pile.home_positions[leaf_index] \
			and hiding_pile.fire.leaf_states[leaf_index] == LeafFire.LeafState.UNLIT
	_check(all_home and not hiding_pile.is_burning() and hiding_pile.fire.get_lit_bonfires().is_empty(),
		"R puts every leaf back, unlit, and the bonfires out")
	_check(not crystal.is_converted and crystal.is_available and crystal.diamond.visible
		and not is_instance_valid(crystal_fire) and not gust_diamond.is_converted and not is_instance_valid(gust_fire),
		"R turns the fire diamonds back into the crystal and the gust diamond")
	player.respawn_at(room_f.get_spawn_position())
	await _physics_frames(5)
	finished_sections.append("F7")


## Stage F8: vines (burning ropes), a drawbridge and a swinging plank, burning
## crates, leaf platforms and sails.
func _check_f8_burning_objects(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var room_g: Room = world.get_node("RoomFireG") as Room
	var bridge_vine: Vine = room_g.get_node("DrawbridgeVine") as Vine
	var drawbridge: HangingPlatform = room_g.get_node("Drawbridge") as HangingPlatform
	var left_vine: Vine = room_g.get_node("SwingVineLeft") as Vine
	var right_vine: Vine = room_g.get_node("SwingVineRight") as Vine
	var swing_plank: HangingPlatform = room_g.get_node("SwingPlank") as HangingPlatform
	var plate: PressurePlate = room_g.get_node("CratePlate") as PressurePlate
	var crate: Crate = room_g.get_node("PlateCrate") as Crate
	var plate_door: Door = room_g.get_node("PlateDoor") as Door
	var leaf: LeafPlatform = room_g.get_node("BurnLeaf") as LeafPlatform
	var sail: SailPlatform = room_g.get_node("BurnSail") as SailPlatform
	var grid: FireGrid = room_g.get_node_or_null("FireGrid") as FireGrid
	var origin: Vector2 = room_g.global_position
	world.jump_to_room(room_g)
	await _physics_frames(10)
	_check(player.fire_bar.pips == 5, "Fire G gives 5 pips, got %d" % player.fire_bar.pips)
	var all_flammable: bool = true
	for node: Node in [bridge_vine, crate, leaf, sail]:
		all_flammable = all_flammable and node.is_in_group(Flammable.GROUP)
	_check(all_flammable, "vines, crates, leaf platforms and sails are flammable")
	_check(tuning.crate_burn_time == 1.5 and tuning.leaf_platform_burn_time == 0.8,
		"crate and leaf platform burn times start at the spec numbers (1.5, 0.8 s)")
	_check(not room_g.has_node("VineGate"), "the vine gate is gone (F8 play-test)")
	_check(not drawbridge.is_awake and not swing_plank.is_awake, "planks sleep while their vines hold")

	# A flame only lights a vine where it touches its line.
	_check(not left_vine.ignite_at(origin + Vector2(156 + 20, 30), 2.0, null) and not left_vine.is_burning(),
		"a flame 20 px from a vine doesn't light it")

	# 1. The drawbridge: a fireball over the plank's top cuts its vine, and the fire
	#    runs both ways from where it hit.
	Fireball.launch(world, origin + Vector2(20, 40), Vector2.RIGHT, tuning, null)
	await _wait_until(func() -> bool: return bridge_vine.is_burning(), 1.0)
	var lit_ms: int = Time.get_ticks_msec()
	await _physics_frames(3)
	_check(bridge_vine.is_burning() and bridge_vine.front_flames[0].visible and bridge_vine.front_flames[1].visible,
		"a fireball lights the vine mid-way and the fire runs both ways")
	await _wait_until(func() -> bool: return bridge_vine.is_on(), 1.0)
	var cut_seconds: float = (Time.get_ticks_msec() - lit_ms) / 1000.0
	_check(bridge_vine.is_on() and cut_seconds < tuning.vine_cut_time + 0.12,
		"it burns through where it was lit after about vine_cut_time (%.2f s)" % cut_seconds)
	_check(bridge_vine.is_burning(), "the two halves keep burning after the snap")
	await _wait_until(func() -> bool: return drawbridge.is_resting(), 4.0)
	var low_x: float = minf(drawbridge.plank_ends[0].x, drawbridge.plank_ends[1].x) - origin.x
	var high_x: float = maxf(drawbridge.plank_ends[0].x, drawbridge.plank_ends[1].x) - origin.x
	var top_y: float = drawbridge.global_position.y - origin.y - HangingPlatform.PLANK_THICKNESS / 2.0
	_check(drawbridge.is_resting() and absf(sin(drawbridge.global_rotation)) < 0.08 and absf(top_y - 156.0) < 1.5
		and low_x < 48.0 and high_x > 120.0,
		"the drawbridge topples and lies flat across the pit (x %.0f-%.0f, top y %.1f)" % [low_x, high_x, top_y])
	player.respawn_at(origin + Vector2(84, 150))
	await _physics_frames(20)
	_check(not player.is_dead() and player.is_on_floor(), "the fallen drawbridge is a bridge over the spikes")
	await _wait_until(func() -> bool: return bridge_vine.burn_state == Vine.BurnState.BURNT, 3.0)
	_check(bridge_vine.burn_state == Vine.BurnState.BURNT, "both halves burn away to nothing")
	# A burnt vine doesn't stop fireballs (F8 play-test bug).
	var through: Fireball = Fireball.launch(world, origin + Vector2(146, 20), Vector2.LEFT, tuning, null)
	await _physics_frames(12)
	_check(is_instance_valid(through) and through.global_position.x < origin.x + 120.0,
		"a fireball flies through where the burnt vine was")

	# 2. The swinging plank: one vine cut, it swings on the other; both cut, it falls.
	player.respawn_at(room_g.get_spawn_position())
	left_vine.ignite_at(origin + Vector2(156, 30), 2.0, null)
	await _wait_until(func() -> bool: return swing_plank.has_fallen, 1.0)
	await get_tree().create_timer(0.6).timeout
	var right_tie: Vector2 = swing_plank._get_point_at(swing_plank.tie_fractions[1])
	_check(swing_plank.has_fallen and left_vine.is_on()
		and right_tie.distance_to(right_vine.global_position) <= swing_plank.leash_lengths[1] + 1.0,
		"with one vine cut, the plank still hangs from the other")
	_check(swing_plank.plank_ends[0].y > swing_plank.plank_ends[1].y + 30.0,
		"its free end has swung down (%.0f px below the tied end)" % (swing_plank.plank_ends[0].y - swing_plank.plank_ends[1].y))
	right_vine.ignite(null)  # it has swung away from where it hung: light it wherever it is
	await _wait_until(func() -> bool: return swing_plank.is_resting() or swing_plank.is_gone, 6.0)
	_check(swing_plank.is_resting() and swing_plank.global_position.y > origin.y + 100.0,
		"with both cut it falls and comes to rest below (y %.0f)" % (swing_plank.global_position.y - origin.y))

	# 3. The crate on the plate: lit, it kills, lights the grass, collapses; the plate lifts, the door opens.
	# Planks bump into things since the L10 play-test: the fallen plank now rests
	# leaning on the crate, in the fireball's way. R hangs it back up first.
	room_g.reset_objects()
	await _physics_frames(10)
	_check(plate.is_on() and plate_door.open_amount == 0.0, "the crate holds the plate down and its door shut")
	player.respawn_at(origin + Vector2(244, 160))
	await _physics_frames(5)
	Fireball.launch(world, origin + Vector2(250, 150), Vector2.RIGHT, tuning, null)
	await _wait_until(func() -> bool: return crate.is_burning(), 1.0)
	_check(crate.is_burning() and crate.fire_hazard.active, "a fireball sets the crate burning (a deadly flame)")
	await _wait_until(func() -> bool: return grid != null and grid.get_state(Vector2i(35, 20)) == FireGrid.State.BURNING, 1.0)
	_check(grid != null and grid.get_state(Vector2i(35, 20)) == FireGrid.State.BURNING,
		"the burning crate lights the grass under it")
	await _wait_until(func() -> bool: return crate.burn_state == Crate.BurnState.GONE, 2.5)
	_check(crate.burn_state == Crate.BurnState.GONE and not crate.is_in_group(PressurePlate.HEAVY_GROUP),
		"after crate_burn_time it collapses and is gone")
	await _wait_until(func() -> bool: return plate_door.open_amount >= 1.0, 1.5)
	_check(not plate.is_on() and plate_door.open_amount >= 1.0, "with the crate gone the plate lifts and the door opens")
	_check(not player.is_dead(), "standing on the earth next to the grass is safe")
	await get_tree().create_timer(tuning.burn_time * 1.3 + 0.5).timeout  # let the grass burn out

	# R brings everything back.
	room_g.reset_objects()
	await _physics_frames(10)
	_check(bridge_vine.burn_state == Vine.BurnState.INTACT and not bridge_vine.is_on()
		and not left_vine.is_on() and not right_vine.is_on(), "R grows the vines back")
	_check(drawbridge.global_transform.is_equal_approx(drawbridge.start_transform)
		and swing_plank.global_transform.is_equal_approx(swing_plank.start_transform)
		and not drawbridge.is_awake and not swing_plank.has_fallen, "R puts both planks back where they were")
	_check(plate_door.open_amount == 0.0, "R shuts the door")
	_check(crate.burn_state == Crate.BurnState.SOLID and plate.is_on() and crate.is_in_group(PressurePlate.HEAVY_GROUP),
		"R brings the crate back onto its plate")

	# A burning crate kills on touch.
	player.respawn_at(origin + Vector2(284, 144))
	await _physics_frames(10)
	crate.ignite(null)
	await _physics_frames(3)
	_check(player.is_dead(), "standing on a burning crate kills")
	await get_tree().create_timer(player.tuning.death_respawn_delay + 0.3).timeout
	_check(crate.burn_state == Crate.BurnState.SOLID and not crate.fire_hazard.active, "dying puts the crate out")

	# The jet's flame catches a crate late (F8 play-test: jetting up off a crate killed you).
	crate.ignite(player.get_node("FlameJetAbility"))
	await _physics_frames(5)
	_check(not crate.is_burning() and crate.catch_remaining > 0.0, "the jet's flame makes a crate glow first, not burn")
	await get_tree().create_timer(tuning.crate_jet_catch_delay).timeout
	_check(crate.is_burning(), "it catches crate_jet_catch_delay later (%.2f s)" % tuning.crate_jet_catch_delay)

	# Fire by the coils round the plank lights the vine (F8 play-test).
	room_g.reset_objects()
	await _physics_frames(5)
	right_vine.ignite_at(origin + Vector2(226, 50), 3.0, null)
	_check(right_vine.is_burning(), "fire on the plank by a vine's coils lights the vine")
	room_g.reset_objects()
	await _physics_frames(5)

	# 4. A leaf platform burns away under you without killing you; then you fall.
	player.respawn_at(origin + Vector2(360, 135))
	await _physics_frames(10)
	_check(player.is_on_floor(), "standing on the leaf platform")
	leaf.ignite(null)
	await get_tree().create_timer(tuning.leaf_platform_burn_time * 0.5).timeout
	_check(leaf.is_burning() and not player.is_dead() and player.is_on_floor(), "a burning leaf holds you and doesn't kill")
	await _wait_until(func() -> bool: return leaf.burn_state == LeafPlatform.BurnState.GONE, 1.0)
	await _physics_frames(5)
	_check(leaf.burn_state == LeafPlatform.BurnState.GONE and not player.is_on_floor(),
		"after leaf_platform_burn_time it's gone and you fall")

	# 5. A burning sail stops catching wind and coasts, without friction, to the end of its rail.
	player.respawn_at(room_g.get_spawn_position())
	sail.receive_gust(Vector2.RIGHT, 160.0)
	await _physics_frames(5)
	sail.ignite(null)
	var coast_speed: float = sail.rail_speed
	await _physics_frames(10)
	_check(sail.is_burning() and coast_speed > 0.0 and is_equal_approx(sail.rail_speed, coast_speed),
		"a burning sail keeps its speed (no friction): %.1f px/s" % sail.rail_speed)
	sail.receive_gust(Vector2.LEFT, 160.0)
	_check(is_equal_approx(sail.rail_speed, coast_speed), "a gust no longer moves a burning sail")
	await _wait_until(func() -> bool: return sail.rail_speed == 0.0, 3.0)
	_check(is_equal_approx(sail.distance_along_rail, 128.0) and sail.sail_state == SailPlatform.SailState.BURNT,
		"it coasts to the end of its rail and stops there, the sail burnt")
	_check(sail.sail_area.collision_layer & Flammable.LAYER_BIT == 0, "a burnt sail no longer stops fireballs")

	room_g.reset_objects()
	await _physics_frames(5)
	_check(leaf.burn_state == LeafPlatform.BurnState.LEAF and sail.sail_state == SailPlatform.SailState.CLOTH
		and is_equal_approx(sail.distance_along_rail, sail.start_distance)
		and sail.sail_area.collision_layer & Flammable.LAYER_BIT != 0,
		"R brings back the leaf and the sail")
	player.respawn_at(room_g.get_spawn_position())
	await _physics_frames(5)
	finished_sections.append("F8")


## Stage F11: ElementImmunity (one damage path), fire against the wisp, sentry and
## orbs, and the vine monkey (spikes, pushes, hot air, torch run, snuff, hops).
func _check_f11_enemies(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var room_j: Room = world.get_node("RoomFireJ") as Room
	var wisp: Wisp = room_j.get_node("FuseWisp") as Wisp
	var sentry: Sentry = room_j.get_node("FireSentry") as Sentry
	var spike_monkey: VineMonkey = room_j.get_node("SpikeMonkey") as VineMonkey
	var ledge_monkey: VineMonkey = room_j.get_node("LedgeMonkey") as VineMonkey
	var fuse_monkey: VineMonkey = room_j.get_node("FuseMonkey") as VineMonkey
	var updraft_pile: LeafPile = room_j.get_node("UpdraftPile") as LeafPile
	var far_pile: LeafPile = room_j.get_node("FarPile") as LeafPile
	var grid: FireGrid = room_j.get_node_or_null("FireGrid") as FireGrid
	var origin: Vector2 = room_j.global_position
	world.jump_to_room(room_j)
	await _physics_frames(10)
	_check(grid != null, "Fire J has a FireGrid (it has grass)")

	# The tables (§7.2). Every enemy is in the "enemies" group with receive_hit.
	var kill: ElementImmunity.Response = ElementImmunity.Response.KILL
	var push: ElementImmunity.Response = ElementImmunity.Response.PUSH
	var ignore: ElementImmunity.Response = ElementImmunity.Response.IGNORE
	for enemy: Node in [wisp, sentry, fuse_monkey]:
		_check(EnemyHit.is_enemy(enemy), "%s takes hits through EnemyHit" % enemy.name)
	var wisp_table: ElementImmunity = wisp.immunity
	_check(wisp_table.get_response(EnemyHit.Type.FIREBALL) == kill and wisp_table.get_response(EnemyHit.Type.FLAME) == kill
		and wisp_table.get_response(EnemyHit.Type.SPIKES) == kill and wisp_table.get_response(EnemyHit.Type.SMALL_ROCK) == push
		and wisp_table.get_response(EnemyHit.Type.GUST) == push, "wisp table: fire and spikes kill, a sloppy rock and a gust push")
	var sentry_table: ElementImmunity = sentry.immunity
	_check(sentry_table.get_response(EnemyHit.Type.FIREBALL) == kill and sentry_table.get_response(EnemyHit.Type.FLAME) == ignore
		and sentry_table.get_response(EnemyHit.Type.SMALL_ROCK) == ignore,
		"sentry table: a fireball kills it, flames and a sloppy rock don't (metal)")
	var monkey_table: ElementImmunity = fuse_monkey.immunity
	var only_fire_kills: bool = true
	for hit_type: int in EnemyHit.Type.values():
		# Fire, and the elephant's whip (Stage F11b: it kills anything).
		var kills: bool = hit_type in [EnemyHit.Type.FIREBALL, EnemyHit.Type.FLAME, EnemyHit.Type.WHIP]
		if (monkey_table.get_response(hit_type) == kill) != kills:
			only_fire_kills = false
	_check(only_fire_kills, "monkey table: only fire (and the elephant's whip) kills it")
	_check(monkey_table.get_response(EnemyHit.Type.SPIKES) == ignore and monkey_table.get_response(EnemyHit.Type.BIG_ROCK) == push,
		"monkey table: spikes do nothing, a big rock pushes")
	_check(tuning.leafling_torch_time == 1.5 and tuning.monkey_torch_speed == 120.0,
		"torch run starts at the spec numbers (1.5 s, 120 px/s)")

	# Wisp: rocks still behave as before (now through the table).
	EnemyHit.send(wisp, EnemyHit.Type.SMALL_ROCK, Vector2(60, 0), null, 0.1)
	_check(wisp.state == Wisp.State.STUNNED, "a sloppy small rock only shoves a wisp")
	EnemyHit.send(wisp, EnemyHit.Type.BIG_ROCK, Vector2(60, 0), null, 0.1)
	await _wait_until(func() -> bool: return wisp.state == Wisp.State.DEFEATED, 1.0)
	_check(wisp.state == Wisp.State.DEFEATED, "a big rock still kills a wisp (after its delay)")
	room_j.reset_objects()
	await _physics_frames(3)

	# Wisp: a fireball kills it.
	Fireball.launch(world, wisp.global_position + Vector2(-30, -4), Vector2.RIGHT, tuning, null)
	await _wait_until(func() -> bool: return wisp.state == Wisp.State.DEFEATED, 1.0)
	_check(wisp.state == Wisp.State.DEFEATED, "a fireball kills a wisp")
	room_j.reset_objects()
	await _physics_frames(3)

	# Wisp: it walks into burning grass and burns up.
	_check(wisp.state == Wisp.State.PATROL, "R brings the wisp back")
	grid.ignite_at(origin + Vector2(8 * 8 + 4, 160), 2.0, null)
	await _wait_until(func() -> bool: return wisp.state == Wisp.State.DEFEATED, 8.0)
	_check(wisp.state == Wisp.State.DEFEATED, "a wisp dies in burning grass")
	room_j.reset_objects()
	await _physics_frames(3)

	# Sentry: a fireball destroys it; the plume doesn't light orbs.
	Fireball.launch(world, origin + Vector2(230, 138), Vector2.RIGHT, tuning, null)
	await _wait_until(func() -> bool: return sentry.is_destroyed, 1.0)
	_check(sentry.is_destroyed, "a fireball destroys a sentry")
	room_j.reset_objects()
	await _physics_frames(2)
	_check(not sentry.is_destroyed, "R brings the sentry back")

	# Fireball against an orb head-on: both burst.
	var orb: SentryOrb = Sentry.ORB_SCENE.instantiate() as SentryOrb
	room_j.add_child(orb)
	orb.launch(origin + Vector2(220, 80), Vector2(-60, 0), sentry)
	_check(not orb.is_in_group(Flammable.GROUP), "orbs aren't flammable: they pass through the plume")
	var orb_fireball: Fireball = Fireball.launch(world, origin + Vector2(160, 80), Vector2.RIGHT, tuning, null)
	orb_fireball.fall_gravity = 0.0
	orb_fireball.velocity = Vector2(tuning.fireball_speed, 0.0)
	await _wait_until(func() -> bool: return not is_instance_valid(orb) or orb.is_popped, 1.0)
	await _physics_frames(2)  # queue_free() lands at the end of the frame
	_check((not is_instance_valid(orb) or orb.is_popped) and not is_instance_valid(orb_fireball),
		"a fireball and an orb cancel out")

	# A reflected orb flies past a monkey (it ignores orbs).
	var reflected: SentryOrb = Sentry.ORB_SCENE.instantiate() as SentryOrb
	room_j.add_child(reflected)
	reflected.launch(spike_monkey.global_position + Vector2(-20, -5), Vector2(60, 0), null)
	reflected.is_reflected = true
	await _physics_frames(30)
	_check(is_instance_valid(reflected) and not reflected.is_popped and spike_monkey.state != VineMonkey.State.DEFEATED,
		"a reflected orb flies through a monkey")
	room_j.reset_objects()
	await _physics_frames(2)

	# Spike monkey: runs back and forth over the spikes for 3 s, unharmed.
	var turned: Array[bool] = [false]
	var first_direction: float = spike_monkey.run_direction
	for frame: int in 180:
		await get_tree().physics_frame
		if spike_monkey.run_direction != first_direction:
			turned[0] = true
	_check(spike_monkey.state == VineMonkey.State.RUN and turned[0], "a monkey runs back and forth over spikes unharmed")

	# Pushes: a big rock, a gust and the column only move it; it can't be crushed.
	EnemyHit.send(spike_monkey, EnemyHit.Type.BIG_ROCK, Vector2(100, 0))
	_check(spike_monkey.state == VineMonkey.State.PUSHED and spike_monkey.velocity.x > 100.0,
		"a big rock knocks a monkey back further (%.0f px/s), it lives" % spike_monkey.velocity.x)
	_check(not Pushable.try_crush(spike_monkey) and spike_monkey.state != VineMonkey.State.DEFEATED,
		"a column can't crush a monkey (it stops short)")
	await _wait_until(func() -> bool: return spike_monkey.state == VineMonkey.State.RUN, 2.0)
	_check(spike_monkey.state == VineMonkey.State.RUN, "a pushed monkey wakes up and runs on")
	# Touching a running monkey kills the player.
	player.respawn_at(spike_monkey.global_position)
	await _physics_frames(2)
	_check(player.is_dead(), "touching a monkey kills you")
	await _wait_until(func() -> bool: return not player.is_dead(), 2.0)
	room_j.reset_objects()
	player.respawn_at(room_j.get_spawn_position())
	await _physics_frames(2)

	# Hot air: over a tall bonfire, a monkey rises instead of falling.
	updraft_pile.ignite_at(updraft_pile.global_position + Vector2(0, -2), 12.0, null)
	var column_point: Vector2 = updraft_pile.global_position + Vector2(0, -50)
	await _wait_until(func() -> bool: return Heat.get_lift_at(get_tree(), column_point) > 0.0, 8.0)
	_check(Heat.get_lift_at(get_tree(), column_point) > 0.0, "the leaf pile's bonfire makes a hot updraft")
	ledge_monkey.global_position = column_point + Vector2(0, 5)
	ledge_monkey.velocity = Vector2.ZERO
	var start_y: float = ledge_monkey.global_position.y
	await _physics_frames(30)
	_check(ledge_monkey.state != VineMonkey.State.DEFEATED and ledge_monkey.global_position.y < start_y + 4.0
		and ledge_monkey.state != VineMonkey.State.TORCH,
		"a monkey drifts in the hot air over a bonfire instead of falling (%.0f px from where it was put)"
			% (ledge_monkey.global_position.y - start_y))
	room_j.reset_objects()
	await _physics_frames(2)

	# The fuse monkey hops its pit to the far side on its own.
	var far_x: float = origin.x + 71 * 8
	var is_across: Callable = func() -> bool: return fuse_monkey.global_position.x > far_x + 6.0 and fuse_monkey.state == VineMonkey.State.RUN
	await _wait_until(is_across, 8.0)
	_check(fuse_monkey.global_position.x > far_x + 6.0 and fuse_monkey.state == VineMonkey.State.RUN,
		"the monkey hops the pit to the far side")

	# Lit there, it runs as a torch: it lights the far grass and the leaf pile, then crumbles.
	var defeated_count: Array[int] = [0]
	var on_defeated: Callable = func() -> void: defeated_count[0] += 1
	fuse_monkey.defeated.connect(on_defeated)
	Fireball.launch(world, fuse_monkey.global_position + Vector2(-24, -5), Vector2.RIGHT, tuning, null)
	await _wait_until(func() -> bool: return fuse_monkey.is_burning(), 1.0)
	_check(fuse_monkey.is_burning() and fuse_monkey.fire_hazard.active, "a fireball lights the monkey: a deadly torch")
	var lit_ms: int = Time.get_ticks_msec()
	await _wait_until(func() -> bool: return far_pile.is_burning(), tuning.leafling_torch_time)
	_check(far_pile.is_burning(), "the torch run lights the leaf pile on the far side")
	_check(grid.burning_count > 0, "the torch run lights the grass")
	await _wait_until(func() -> bool: return fuse_monkey.state == VineMonkey.State.DEFEATED, 2.0)
	var torch_seconds: float = (Time.get_ticks_msec() - lit_ms) / 1000.0
	_check(fuse_monkey.state == VineMonkey.State.DEFEATED and defeated_count[0] == 1,
		"it crumbles to ash after its torch time and is defeated (%.1f s)" % torch_seconds)
	fuse_monkey.defeated.disconnect(on_defeated)
	player.respawn_at(room_j.get_spawn_position())
	room_j.reset_objects()
	await _physics_frames(3)
	_check(fuse_monkey.state == VineMonkey.State.RUN and fuse_monkey.visible and not far_pile.is_burning()
		and grid.burning_count == 0, "R brings the monkey back and puts the fire out")

	# A gust puts a burning monkey out: it smolders, stunned, then carries on. (The
	# spike monkey: no grass under it, which it would light and catch again from.)
	spike_monkey.ignite(null)
	await _physics_frames(2)
	spike_monkey.receive_gust(Vector2.LEFT, 160.0)
	_check(spike_monkey.state == VineMonkey.State.SMOLDER and not spike_monkey.is_burning()
		and not spike_monkey.fire_hazard.active and not spike_monkey.is_deadly(),
		"a gust snuffs a burning monkey: it smolders, harmless")
	await _wait_until(func() -> bool: return spike_monkey.state == VineMonkey.State.RUN, 2.0)
	_check(spike_monkey.state == VineMonkey.State.RUN, "after its stun it carries on its route")
	spike_monkey.ignite(null)
	_check(spike_monkey.is_burning(), "it can be lit again")
	room_j.reset_objects()
	player.respawn_at(room_j.get_spawn_position())
	await _physics_frames(3)
	finished_sections.append("F11")


## Stage F11b: the thicket elephant (size, ride, front kill, charge on sight, burn
## spots and their reactions, stone wall, thicket, big rock, tail whip and back
## strike, column, crumble, reset to its start).
func _check_f11b_elephant(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var room_l: Room = world.get_node("RoomFireL") as Room
	var rider: ThicketElephant = room_l.get_node("RideElephant") as ThicketElephant
	var charger: ThicketElephant = room_l.get_node("ChargeElephant") as ThicketElephant
	var smasher: ThicketElephant = room_l.get_node("ThicketElephant") as ThicketElephant
	var stone_wall: StoneWall = room_l.get_node("StoneWall") as StoneWall
	var grid: FireGrid = room_l.get_node_or_null("FireGrid") as FireGrid
	var origin: Vector2 = room_l.global_position
	world.jump_to_room(room_l)
	await _physics_frames(10)

	# The table, the size and the Earth breaking.
	var table: ElementImmunity = rider.immunity
	var kill: ElementImmunity.Response = ElementImmunity.Response.KILL
	var push: ElementImmunity.Response = ElementImmunity.Response.PUSH
	var ignore: ElementImmunity.Response = ElementImmunity.Response.IGNORE
	_check(table.get_response(EnemyHit.Type.FIREBALL) == kill and table.get_response(EnemyHit.Type.BIG_ROCK) == push
		and table.get_response(EnemyHit.Type.SMALL_ROCK) == ignore and table.get_response(EnemyHit.Type.SPIKES) == ignore
		and table.get_response(EnemyHit.Type.EARTH_PUSH) == ignore and table.get_response(EnemyHit.Type.CRUSH) == ignore,
		"elephant table: fire burns it, a big rock pushes, small rocks, spikes and earth do nothing")
	_check(EnemyHit.breaks_earth(rider) and not Pushable.try_crush(rider), "columns and snakes break on it; it can't be crushed")
	_check(ThicketElephant.BODY_SIZE == Vector2(96, 60), "it's 96x60, its back out of jumping reach")

	# The ride: standing on its back, you're carried over the spikes.
	player.respawn_at(rider.global_position + Vector2(0, -ThicketElephant.BODY_SIZE.y - 1))
	await _physics_frames(5)
	var ride_start_x: float = player.global_position.x
	var elephant_start_x: float = rider.global_position.x
	await get_tree().create_timer(2.0).timeout
	var carried: float = player.global_position.x - ride_start_x
	var walked: float = rider.global_position.x - elephant_start_x
	_check(not player.is_dead() and player.get_floor_body() == rider and absf(carried - walked) < 2.0 and absf(walked) > 8.0,
		"you ride its back over the spikes (it walked %.0f px, you moved %.0f px)" % [walked, carried])
	_check(rider.state != ThicketElephant.State.DEFEATED, "it walks over spikes unharmed")

	# Its back catching fire: the tail rises and strikes forward over its back.
	rider.ignite_at(rider._get_spot_rect(ThicketElephant.Spot.BACK).get_center(), 2.0, null)
	_check(rider.whip_over_back and rider.whip_phase == ThicketElephant.Whip.RAISE,
		"a burning back makes the tail rise to strike over it (no buck)")
	room_l.reset_objects()
	await _physics_frames(3)

	# A rider on a BURNT back: the tail strikes over the back and kills them.
	rider.spot_states[ThicketElephant.Spot.BACK] = ThicketElephant.SpotState.BURNT
	player.respawn_at(rider.global_position + Vector2(0, -ThicketElephant.BODY_SIZE.y - 1))
	await _wait_until(func() -> bool: return player.is_dead(),
		tuning.elephant_back_strike_delay + tuning.elephant_whip_raise_time + tuning.elephant_whip_strike_time + 0.5)
	_check(player.is_dead() and rider.whip_over_back, "on its burnt back, the tail strikes you")
	await _wait_until(func() -> bool: return not player.is_dead(), 2.0)
	await _physics_frames(2)  # the node shows its new spot after one physics step

	# Reset puts it back where it was placed (a synced body ignores a plain move).
	_check(rider.global_position.distance_to(rider.start_position) < 0.5 and not rider.is_spot_burnt(ThicketElephant.Spot.BACK),
		"dying puts the elephant back at its start, whole (it was %.0f px away)" % rider.global_position.distance_to(rider.start_position))
	await _physics_frames(30)
	var walked_away: float = rider.global_position.distance_to(rider.start_position)
	room_l.reset_enemies()
	await _physics_frames(2)
	_check(walked_away > 2.0 and rider.global_position.distance_to(rider.start_position) < 1.0,
		"walking into the room puts its enemies back at their start")

	# It never gets stuck turning at the ends of its patrol: its collision boxes are
	# mirror images, so after a turn nothing of it is inside the wall it turned at.
	# (Uneven boxes made it turn back the very next frame, over and over.)
	room_l.reset_objects()
	player.respawn_at(origin + Vector2(37 * 8 + 4, 80))  # up on a ledge, out of sight
	await _physics_frames(3)
	var turn_frames: Array[int] = []
	var last_facing: float = rider.facing
	for frame: int in 1200:
		await get_tree().physics_frame
		if rider.facing != last_facing:
			turn_frames.append(frame)
			last_facing = rider.facing
	var turned_straight_back: bool = false
	for turn_index: int in range(1, turn_frames.size()):
		if turn_frames[turn_index] - turn_frames[turn_index - 1] < 10:
			turned_straight_back = true
	_check(turn_frames.size() >= 2 and not turned_straight_back,
		"it patrols between the walls without getting stuck (%d turns in 20 s)" % turn_frames.size())
	room_l.reset_objects()
	await _physics_frames(3)

	# Its front kills.
	player.respawn_at(charger.global_position + Vector2(charger.facing * 50.0, 0))
	await _physics_frames(2)
	_check(player.is_dead(), "touching its front (head, tusks, trunk) kills you")
	await _wait_until(func() -> bool: return not player.is_dead(), 2.0)
	room_l.reset_objects()
	await _physics_frames(3)
	# The deadly front is only what's drawn: 2 px clear of the face (above the tusk) is
	# safe, touching the trunk's foot is not.
	var hitbox_size: Vector2 = player.get_hitbox_rect().size
	var touches_front: Callable = func(drawing_rect: Rect2) -> bool:
		var world_rect: Rect2 = charger._get_world_rect(drawing_rect)
		for kill_rect: Rect2 in charger._get_front_kill_rects():
			if charger._get_world_rect(kill_rect).intersects(world_rect):
				return true
		return false
	_check(not touches_front.call(Rect2(Vector2(50, -46), hitbox_size)), "2 px clear of its face is safe")
	_check(touches_front.call(Rect2(Vector2(60, -hitbox_size.y), hitbox_size)), "touching its trunk's foot kills")

	# It charges whenever it sees you in front, on its level: rear, then run at you.
	# 90 px ahead: right of the low wall (behind it, the wall hides you from its eye).
	player.respawn_at(charger.global_position + Vector2(charger.facing * 90.0, 0))
	await _wait_until(func() -> bool: return charger.state == ThicketElephant.State.REAR, 0.5)
	_check(charger.state == ThicketElephant.State.REAR, "it sees you ahead on its level and rears (the tell)")
	player.respawn_at(origin + Vector2(37 * 8 + 4, 80))  # up on the dodge ledge
	await _wait_until(func() -> bool: return charger.state == ThicketElephant.State.CHARGE, tuning.elephant_rear_time + 0.2)
	_check(charger.state == ThicketElephant.State.CHARGE and is_equal_approx(charger.charge_speed_now, tuning.elephant_charge_speed),
		"then charges at its normal speed")
	await _wait_until(func() -> bool: return charger.state == ThicketElephant.State.STUNNED, 3.0)
	_check(charger.state == ThicketElephant.State.STUNNED, "a charge into a wall stuns it")
	_check(not player.is_dead(), "up on the ledge, it can't reach you")
	room_l.reset_objects()
	player.respawn_at(room_l.get_spawn_position())
	await _physics_frames(3)

	# Trunk: it rears, then charges forward twice as fast.
	charger.ignite_at(charger._get_spot_rect(ThicketElephant.Spot.TRUNK).get_center(), 1.0, null)
	_check(charger.state == ThicketElephant.State.REAR, "a burning trunk makes it rear")
	await _wait_until(func() -> bool: return charger.state == ThicketElephant.State.CHARGE, tuning.elephant_rear_time + 0.2)
	_check(charger.state == ThicketElephant.State.CHARGE and is_equal_approx(charger.charge_speed_now,
		tuning.elephant_charge_speed * tuning.elephant_hit_charge_multiplier), "then charges forward twice as fast")
	room_l.reset_objects()
	await _physics_frames(3)

	# Tail, lit from behind (the left) while it faces right: it bolts right, twice as
	# fast, and smashes the stone wall (only an elephant can).
	charger._turn_to(1.0)
	charger._reset_tail()
	await _physics_frames(5)
	charger.ignite_at(charger._get_spot_rect(ThicketElephant.Spot.TAIL).get_center(), 1.0, null)
	_check(charger.state == ThicketElephant.State.CHARGE and charger.facing > 0.0
		and charger.charge_speed_now > tuning.elephant_charge_speed, "a burning tail makes it bolt away from the fire, fast")
	await _wait_until(func() -> bool: return stone_wall.is_broken, 3.0)
	_check(stone_wall.is_broken, "its charge smashes the stone wall")
	room_l.reset_objects()
	await _physics_frames(3)
	_check(not stone_wall.is_broken and charger.state == ThicketElephant.State.WALK, "R mends the wall and calms it")

	# A big rock stops a charge (pushes it back, no stagger); small rocks bounce off.
	charger.ignite_at(charger._get_spot_rect(ThicketElephant.Spot.TRUNK).get_center(), 1.0, null)
	await _wait_until(func() -> bool: return charger.state == ThicketElephant.State.CHARGE, 1.0)
	await _physics_frames(5)
	EnemyHit.send(charger, EnemyHit.Type.BIG_ROCK, Vector2(-charger.facing * 150.0, 0.0))
	_check(charger.state == ThicketElephant.State.WALK and signf(charger.push_speed) == -charger.facing,
		"a big rock pushes it back and stops its charge")
	EnemyHit.send(charger, EnemyHit.Type.SMALL_ROCK, Vector2(-150.0, 0.0))
	_check(charger.state == ThicketElephant.State.WALK, "a small rock bounces off")
	room_l.reset_objects()
	await _physics_frames(3)

	# Thicket: lit from the left, the third elephant bolts right through the thicket wall.
	var thicket_cell: Vector2i = Vector2i(82, 18)
	smasher.ignite_at(smasher._get_spot_rect(ThicketElephant.Spot.TAIL).get_center(), 1.0, null)
	await _wait_until(func() -> bool: return grid != null and grid.get_state(thicket_cell) == FireGrid.State.GONE, 3.0)
	_check(grid != null and grid.get_state(thicket_cell) == FireGrid.State.GONE, "its charge smashes through thicket")

	# The tail whip: it wiggles, rises (the tell), then strikes down behind it.
	room_l.reset_objects()
	player.respawn_at(room_l.get_spawn_position())
	await _physics_frames(3)
	await _wait_until(func() -> bool: return smasher.whip_phase == ThicketElephant.Whip.WIGGLE, tuning.elephant_whip_interval + 1.0)
	_check(smasher.whip_phase == ThicketElephant.Whip.WIGGLE, "the tail wiggles first")
	await _wait_until(func() -> bool: return smasher.whip_phase == ThicketElephant.Whip.RAISE, tuning.elephant_whip_wiggle_time + 0.1)
	_check(smasher.whip_phase == ThicketElephant.Whip.RAISE, "then rises (the tell)")
	var root: Vector2 = smasher._get_world_point(ThicketElephant.TAIL_ROOT)
	player.respawn_at(Vector2(root.x - smasher.facing * 18.0, smasher.global_position.y))
	player.set_frozen(true)
	await _wait_until(func() -> bool: return player.is_dead(), tuning.elephant_whip_raise_time + tuning.elephant_whip_strike_time + 0.3)
	_check(player.is_dead(), "then strikes down behind it: the whip kills you")
	player.set_frozen(false)
	await _wait_until(func() -> bool: return not player.is_dead(), 2.0)

	# An Earth Column rising under its belly shatters instead of lifting it.
	room_l.reset_objects()
	await _physics_frames(3)
	var earth: EarthLayer = room_l.get_node("Earth") as EarthLayer
	var under_cell: Vector2i = earth.local_to_map(earth.to_local(smasher.global_position + Vector2(0, 4)))
	var elephant_y: float = smasher.global_position.y
	player.earth_column.erupt(EarthFace.new(earth, under_cell, Vector2i.UP))
	await _physics_frames(12)
	var columns_left: int = 0
	for child: Node in room_l.get_children():
		if child is EarthColumn and not child.is_queued_for_deletion():
			columns_left += 1
	_check(columns_left == 0 and absf(smasher.global_position.y - elephant_y) < 1.0,
		"a column rising under it shatters (it isn't lifted)")

	# All three spots burnt: it crumbles to ash and counts as defeated.
	room_l.reset_objects()
	player.respawn_at(room_l.get_spawn_position())
	await _physics_frames(3)
	var defeated_count: Array[int] = [0]
	var on_defeated: Callable = func() -> void: defeated_count[0] += 1
	smasher.defeated.connect(on_defeated)
	for spot: int in 3:
		smasher.ignite_at(smasher._get_spot_rect(spot).get_center(), 1.0, null)
	_check(smasher.is_burning(), "all three spots burn")
	await _wait_until(func() -> bool: return smasher.state == ThicketElephant.State.DEFEATED, tuning.elephant_spot_burn_time + 0.5)
	_check(smasher.state == ThicketElephant.State.DEFEATED and defeated_count[0] == 1 and smasher.collision_layer == 0,
		"with all three burnt it crumbles to ash")
	smasher.defeated.disconnect(on_defeated)
	room_l.reset_objects()
	await _physics_frames(3)
	_check(smasher.state == ThicketElephant.State.WALK and smasher.visible and not smasher.is_spot_burnt(ThicketElephant.Spot.TAIL),
		"R brings it back whole")
	player.respawn_at(room_l.get_spawn_position())
	await _physics_frames(3)
	finished_sections.append("F11b")


## Stage F12: the Shell (only a big rock kills it), every enemy's row of the §7.2
## table, and ricochets (fireballs off what doesn't burn and off the Shell, orbs off
## walls and the Shell).
func _check_f12_shell(world: RoomManager, player: Player) -> void:
	var tuning: FireTuning = player.fire_tuning
	var earth_tuning: EarthTuning = player.earth_tuning
	var room_m: Room = world.get_node("RoomFireM") as Room
	var armor_shell: Shell = room_m.get_node("ArmorShell") as Shell
	var drop_shell: Shell = room_m.get_node("DropShell") as Shell
	var bridge_shell: Shell = room_m.get_node("BridgeShell") as Shell
	var orb_shell: Shell = room_m.get_node("OrbShell") as Shell
	var sentry: Sentry = room_m.get_node("OrbSentry") as Sentry
	var wisp: Wisp = room_m.get_node("TableWisp") as Wisp
	var monkey: VineMonkey = room_m.get_node("TableMonkey") as VineMonkey
	var elephant: ThicketElephant = room_m.get_node("TableElephant") as ThicketElephant
	var grid: FireGrid = room_m.get_node_or_null("FireGrid") as FireGrid
	var origin: Vector2 = room_m.global_position
	sentry.can_fire = false  # its orbs would hit the player mid-test; orbs are launched by hand
	world.jump_to_room(room_m)
	await _physics_frames(10)

	# 1. The §7.2 table, every cell (rows: fire, big rock, small rock, gust, spikes).
	# The small-rock row follows the Earth chapter: a sloppy small rock shoves a wisp
	# and clonks off a sentry, a perfect one kills them.
	var kill: ElementImmunity.Response = ElementImmunity.Response.KILL
	var push: ElementImmunity.Response = ElementImmunity.Response.PUSH
	var stagger: ElementImmunity.Response = ElementImmunity.Response.STAGGER
	var ignore: ElementImmunity.Response = ElementImmunity.Response.IGNORE
	var reflect: ElementImmunity.Response = ElementImmunity.Response.REFLECT
	var fire: EnemyHit.Type = EnemyHit.Type.FIREBALL
	var big: EnemyHit.Type = EnemyHit.Type.BIG_ROCK
	var small: EnemyHit.Type = EnemyHit.Type.SMALL_ROCK
	var perfect: EnemyHit.Type = EnemyHit.Type.PERFECT_ROCK
	var gust: EnemyHit.Type = EnemyHit.Type.GUST
	var spikes: EnemyHit.Type = EnemyHit.Type.SPIKES
	var table_rows: Array = [
		["wisp", wisp.immunity, {fire: kill, big: kill, small: push, perfect: kill, gust: push, spikes: kill}],
		["sentry", sentry.immunity, {fire: kill, big: kill, small: ignore, perfect: kill}],
		["vine monkey", monkey.immunity, {fire: kill, big: push, small: push, gust: push, spikes: ignore}],
		["elephant", elephant.immunity, {fire: kill, big: push, small: ignore, gust: push, spikes: ignore}],
		["shell", armor_shell.immunity, {fire: reflect, EnemyHit.Type.FLAME: ignore, big: kill, small: stagger,
			perfect: stagger, gust: push, spikes: ignore, EnemyHit.Type.CRUSH: kill,
			EnemyHit.Type.EARTH_PUSH: push, EnemyHit.Type.REFLECTED_ORB: reflect}],
	]
	for row: Array in table_rows:
		var table: ElementImmunity = row[1]
		var expected: Dictionary = row[2]
		var wrong: Array[String] = []
		for hit_type: EnemyHit.Type in expected:
			if table.get_response(hit_type) != expected[hit_type]:
				wrong.append("%s=%s" % [EnemyHit.Type.keys()[hit_type], ElementImmunity.Response.keys()[table.get_response(hit_type)]])
		_check(wrong.is_empty(), "§7.2 table, %s row as written %s" % [row[0], wrong])
	_check(armor_shell.is_in_group(EnemyHit.REFLECTS_GROUP) and not armor_shell.is_in_group(Flammable.GROUP),
		"the Shell reflects orbs and can't burn")
	_check(Shell.BODY_SIZE == Vector2(12, 8), "the Shell is 12x8")

	# 2. Its patrol: slow, turning before the spikes (never on them), kills on touch.
	var spikes_left: float = origin.x + 16 * 8
	var turns: int = 0
	var last_direction: float = armor_shell.walk_direction
	var furthest_right: float = -INF
	for frame: int in 60 * 8:
		await get_tree().physics_frame
		furthest_right = maxf(furthest_right, armor_shell.get_hitbox_global_rect().end.x)
		if armor_shell.walk_direction != last_direction:
			turns += 1
			last_direction = armor_shell.walk_direction
	_check(turns >= 2 and furthest_right <= spikes_left and armor_shell.state == Shell.State.WALK,
		"the Shell patrols, turning before the spikes (%d turns, front reached x %.0f, spikes at %.0f)" % [turns, furthest_right, spikes_left])
	player.respawn_at(armor_shell.global_position + Vector2(0, -1))
	await _physics_frames(2)
	_check(player.is_dead(), "touching the Shell kills you")
	await _wait_until(func() -> bool: return not player.is_dead(), 2.0)
	room_m.reset_objects()
	await _physics_frames(3)
	# (3 frames of walking since the reset: under 2 px.)
	_check(armor_shell.global_position.distance_to(origin + Vector2(80, 160)) < 2.0, "reset puts the Shell back at its start")

	# 3. Ricochets. A fireball down onto the grass lights it and ends there (no bounce).
	var grass_ball: Fireball = Fireball.launch(world, origin + Vector2(60, 140), Vector2.DOWN, tuning, null)
	var grass_result: Array[int] = [-1]
	grass_ball.finished.connect(func(_hit: Node) -> void: grass_result[0] = grass_ball.bounce_count)
	await _wait_until(func() -> bool: return grass_result[0] >= 0, 1.0)
	_check(grass_result[0] == 0 and grid != null and grid.get_state(Vector2i(7, 20)) != FireGrid.State.GRASS,
		"a fireball onto grass lights it and bursts there (no bounce)")
	# The Shell walks through the burning grass, unharmed.
	await _wait_game(2.0)
	_check(armor_shell.state == Shell.State.WALK and armor_shell.visible, "the Shell walks through burning grass unharmed")
	# A fireball into a bare earth wall (the room's left wall, up in open air) bounces
	# back and flies on. Projectiles are held in arrays: a lambda that captured a node
	# directly complains once it's freed.
	var wall_ball: Array[Fireball] = [Fireball.launch(world, origin + Vector2(40, 100), Vector2.LEFT, tuning, null)]
	await _wait_until(func() -> bool: return not is_instance_valid(wall_ball[0]) or wall_ball[0].bounce_count > 0, 1.0)
	_check(is_instance_valid(wall_ball[0]) and wall_ball[0].bounce_count == 1 and wall_ball[0].velocity.x > 0.0
		and not wall_ball[0].has_finished, "a fireball bounces off a bare earth wall and flies on")
	await _wait_until(func() -> bool: return not is_instance_valid(wall_ball[0]), 2.0)
	_check(not is_instance_valid(wall_ball[0]), "and gutters out at the end of its range")
	# A fireball at the Shell sparks off and bounces; the Shell is unharmed. (The orb
	# lane's Shell, held still: open floor on both sides.)
	orb_shell.set_physics_process(false)
	var shell_ball: Array[Fireball] = [Fireball.launch(world, orb_shell.global_position + Vector2(30, -6), Vector2.LEFT, tuning, null)]
	await _wait_until(func() -> bool: return not is_instance_valid(shell_ball[0]) or shell_ball[0].bounce_count > 0, 1.0)
	_check(is_instance_valid(shell_ball[0]) and shell_ball[0].bounce_count >= 1 and shell_ball[0].velocity.x > 0.0
		and orb_shell.state != Shell.State.DEFEATED, "a fireball bounces off the Shell, which is unharmed")
	if is_instance_valid(shell_ball[0]):
		shell_ball[0].queue_free()
	# An orb bounces off the Shell's plates, and off the ceiling.
	var orb_scene: PackedScene = load("res://scenes/enemies/sentry_orb.tscn") as PackedScene
	var shell_orb: Array[SentryOrb] = [orb_scene.instantiate() as SentryOrb]
	room_m.add_child(shell_orb[0])
	shell_orb[0].launch(orb_shell.global_position + Vector2(24, -4), Vector2(-60, 0), null)
	await _wait_until(func() -> bool: return not is_instance_valid(shell_orb[0]) or shell_orb[0].bounce_count > 0, 1.5)
	_check(is_instance_valid(shell_orb[0]) and shell_orb[0].bounce_count == 1 and shell_orb[0].velocity.x > 0.0
		and orb_shell.state != Shell.State.DEFEATED, "a sentry orb bounces off the Shell")
	if is_instance_valid(shell_orb[0]):
		shell_orb[0].pop()
	orb_shell.set_physics_process(true)
	var ceiling_orb: Array[SentryOrb] = [orb_scene.instantiate() as SentryOrb]
	room_m.add_child(ceiling_orb[0])
	ceiling_orb[0].launch(origin + Vector2(100, 40), Vector2(0, -80), null)
	await _wait_until(func() -> bool: return not is_instance_valid(ceiling_orb[0]) or ceiling_orb[0].bounce_count > 0, 1.5)
	_check(is_instance_valid(ceiling_orb[0]) and ceiling_orb[0].bounce_count == 1 and ceiling_orb[0].velocity.y > 0.0
		and not ceiling_orb[0].is_popped, "a sentry orb bounces off the ceiling")
	if is_instance_valid(ceiling_orb[0]):
		ceiling_orb[0].pop()
	room_m.reset_objects()
	await _physics_frames(3)

	# 4. Hits on the Shell, with its walk stopped so only the hit moves it.
	var walk_speed: float = tuning.shell_walk_speed
	tuning.shell_walk_speed = 0.0
	var before: Vector2 = drop_shell.global_position
	_check(EnemyHit.send(drop_shell, small, Vector2(150, 0)) == stagger and drop_shell.state == Shell.State.STAGGER,
		"a small rock staggers the Shell")
	await _wait_game(tuning.shell_stagger_time * 0.6)
	_check(drop_shell.state == Shell.State.STAGGER and absf(drop_shell.global_position.x - before.x - tuning.shell_stagger_knockback) < 1.0,
		"it stops and is knocked back %.0f px (%.1f)" % [tuning.shell_stagger_knockback, drop_shell.global_position.x - before.x])
	await _wait_game(tuning.shell_stagger_time * 0.6)
	_check(drop_shell.state == Shell.State.WALK, "then walks on")
	# The snake's head: its REAL shove (EarthSnake._shove_bodies_out_of, the step a
	# head takes into a cell), on a snake that isn't in the tree.
	var earth_layer: EarthLayer = null
	for child: Node in room_m.get_children():
		if child is EarthLayer:
			earth_layer = child as EarthLayer
			break
	var ram: Callable = func(shell: Shell, direction: Vector2i) -> bool:
		var snake: EarthSnake = EarthSnake.new()
		snake.earth_layer = earth_layer
		snake.earth_tuning = earth_tuning
		var cell: Vector2i = earth_layer.local_to_map(earth_layer.to_local(shell._get_center()))
		var entered: bool = snake._shove_bodies_out_of(cell, direction)
		snake.free()
		return entered
	before = drop_shell.global_position
	var head_entered: bool = ram.call(drop_shell, Vector2i(-1, 0))
	await _wait_game(0.4)
	_check(head_entered and absf(before.x - drop_shell.global_position.x - 8.0) < 0.5 and drop_shell.state == Shell.State.WALK,
		"the snake's head carries it exactly one tile (%.1f px)" % (before.x - drop_shell.global_position.x))
	before = drop_shell.global_position
	EnemyHit.send(drop_shell, gust, Vector2(300, 0))
	await _wait_game(0.5)
	var nudge: float = drop_shell.global_position.x - before.x
	_check(nudge > 0.0 and nudge < 4.0, "a gust barely nudges it (%.1f px)" % nudge)
	EnemyHit.send(drop_shell, EnemyHit.Type.EARTH_PUSH, Vector2(0, -150))
	await _physics_frames(3)
	_check(not drop_shell.is_on_floor() and drop_shell.velocity.y < 0.0, "a column's tip lifts it")
	await _wait_until(func() -> bool: return drop_shell.is_on_floor(), 1.0)
	for harmless: EnemyHit.Type in [spikes, EnemyHit.Type.FLAME, EnemyHit.Type.WHIP]:
		EnemyHit.send(drop_shell, harmless, Vector2(100, 0))
	_check(drop_shell.state == Shell.State.WALK and drop_shell.visible, "spikes, flames and the whip do nothing")
	# Crushing kills it: the snake's head ramming it into a wall, a small rock with a
	# wall within a tile behind it, a column squeezing it. (The orb lane's Shell, next
	# to the low wall at col 42.)
	var wall_side: float = origin.x + 43 * 8
	orb_shell.global_position = Vector2(wall_side + Shell.BODY_SIZE.x / 2.0 + 1.0, orb_shell.global_position.y)
	await _physics_frames(2)
	head_entered = ram.call(orb_shell, Vector2i(-1, 0))
	_check(head_entered and orb_shell.state == Shell.State.DEFEATED,
		"the snake's head ramming it into a wall crushes it (and goes in)")
	room_m.reset_objects()
	await _physics_frames(3)
	# 5 px from the wall: past the 4 px knockback, inside the tile.
	orb_shell.global_position = Vector2(wall_side + Shell.BODY_SIZE.x / 2.0 + 5.0, orb_shell.global_position.y)
	await _physics_frames(2)
	EnemyHit.send(orb_shell, small, Vector2(-150, 0))
	await _wait_until(func() -> bool: return orb_shell.state == Shell.State.DEFEATED, 0.5)
	_check(orb_shell.state == Shell.State.DEFEATED, "a small rock with a wall a tile behind it crushes it")
	room_m.reset_objects()
	await _physics_frames(3)
	# 12 px from the wall: just staggered.
	orb_shell.global_position = Vector2(wall_side + Shell.BODY_SIZE.x / 2.0 + 12.0, orb_shell.global_position.y)
	await _physics_frames(2)
	EnemyHit.send(orb_shell, small, Vector2(-150, 0))
	await _wait_game(0.2)
	_check(orb_shell.state == Shell.State.STAGGER, "further from the wall, a small rock only staggers it")
	room_m.reset_objects()
	await _physics_frames(3)
	_check(Pushable.try_crush(orb_shell) and orb_shell.state == Shell.State.DEFEATED, "a column squeezing it crushes it")
	tuning.shell_walk_speed = walk_speed
	room_m.reset_objects()
	await _physics_frames(3)

	# 5. Big rocks. A small loose rock dropped on it does nothing; a big one dropped
	# from 2+ tiles kills it; a thrown big rock kills it.
	# (The orb lane's Shell, held still, open air above it.)
	orb_shell.set_physics_process(false)
	var small_rock: Boulder = Boulder.new()
	small_rock.setup(orb_shell.global_position + Vector2(0, -40), Vector2.UP, 0.0, 0.0, earth_tuning)
	room_m.add_child(small_rock)
	small_rock.drop()
	await _wait_game(1.0)
	_check(orb_shell.state != Shell.State.DEFEATED, "a small rock dropped on the Shell does nothing")
	var big_rock: Array[Boulder] = [Boulder.new()]
	var big_center: Vector2 = orb_shell.global_position + Vector2(0, -48)
	big_rock[0].setup(big_center, Vector2.UP, 0.0, 0.0, earth_tuning)
	room_m.add_child(big_rock[0])
	big_rock[0].grow(big_center, 16.0)
	big_rock[0].drop()
	await _wait_until(func() -> bool: return orb_shell.state == Shell.State.DEFEATED, 1.5)
	_check(orb_shell.state == Shell.State.DEFEATED and not is_instance_valid(big_rock[0]),
		"a big rock dropped on it from 2+ tiles cracks it open (and shatters)")
	orb_shell.set_physics_process(true)
	_check(EnemyHit.send(armor_shell, big, Vector2(200, 0), null, earth_tuning.boulder_enemy_defeat_delay) == kill
		and armor_shell.state == Shell.State.DEFEATED, "a thrown big rock kills it")
	room_m.reset_objects()
	await _physics_frames(3)
	_check(orb_shell.visible and orb_shell.state == Shell.State.WALK and armor_shell.state == Shell.State.WALK,
		"R brings the Shells back")

	# 6. Burn the thicket bridge under a Shell (standing still on it, at its start over
	# the thicket): it drops into the pocket, alive.
	tuning.shell_walk_speed = 0.0
	var bridge_y: float = bridge_shell.global_position.y
	if grid != null:
		grid.ignite_at(origin + Vector2(35 * 8 + 4, 18 * 8 + 4), 4.0, null)
	await _wait_until(func() -> bool: return bridge_shell.global_position.y > bridge_y + 12.0, 8.0)
	_check(bridge_shell.global_position.y > bridge_y + 12.0 and bridge_shell.state == Shell.State.WALK,
		"burning the thicket under a Shell drops it out of the way (%.0f px down)" % (bridge_shell.global_position.y - bridge_y))
	tuning.shell_walk_speed = walk_speed
	room_m.reset_objects()
	await _physics_frames(3)
	sentry.can_fire = true
	player.respawn_at(room_m.get_spawn_position())
	await _physics_frames(3)
	finished_sections.append("F12")


## Waits this many seconds of game time (physics frames).
func _wait_game(seconds: float) -> void:
	await _physics_frames(roundi(seconds * Engine.physics_ticks_per_second))


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


## Waits physics frames until `condition` returns true, or `max_seconds` of game time
## pass (then the check that follows reports the failure).
func _wait_until(condition: Callable, max_seconds: float) -> void:
	var waited: float = 0.0
	while not condition.call() and waited < max_seconds:
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second


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

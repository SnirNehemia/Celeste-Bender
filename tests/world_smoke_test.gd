extends Node
## Headless smoke test for the Milestone 1 world (Stage 9). Not part of the game.
##
## Loads scenes/world.tscn (rooms 1-7), teleports the player into each room in turn (the same
## way the F2 room picker does), defeats room 5's enemies by script to check the
## EnemyGate opens the exit door, checks the gust charges and the gust diamond in
## room 7 (one gust per airtime, two after a diamond), the Stage 10 polish (squash on jump/land,
## pause menu, freeze vs. menu pause), then finishes the run and checks the end screen.
## Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/world_smoke_test.tscn

const WORLD_SCENE: PackedScene = preload("res://scenes/world.tscn")

var failures: int = 0


func _ready() -> void:
	var world: RoomManager = WORLD_SCENE.instantiate() as RoomManager
	add_child(world)
	await get_tree().physics_frame

	_check(world.rooms.size() == 7, "world has 7 rooms (found %d)" % world.rooms.size())
	for room: Room in world.rooms:
		world.jump_to_room(room)
		await get_tree().create_timer(0.5).timeout
		_check(not world.player.is_dead(), "player alive after spawning in %s" % room.display_title)
		_check(room.get_bounds().has_point(world.player.get_center()), "spawn of %s is inside the room" % room.display_title)

	var gate_room: Room = world.rooms[4]
	var gate: EnemyGate = gate_room.get_node("EnemyGate") as EnemyGate
	_check(not gate.is_on(), "enemy gate starts off")
	(gate_room.get_node("LowWisp") as Wisp).defeat()
	(gate_room.get_node("HighWisp") as Wisp).defeat()
	_check(not gate.is_on(), "enemy gate still off with the sentry alive")
	(gate_room.get_node("Sentry") as Sentry).destroy()
	_check(gate.is_on(), "enemy gate on after all three are defeated")
	gate_room.reset_objects()
	_check(not gate.is_on(), "enemy gate off again after a room reset")

	# No-glide zone: gliding allowed outside, refused inside (room 2's crystal chain).
	var chain_room: Room = world.rooms[1]
	world.jump_to_room(chain_room)
	await get_tree().create_timer(0.2).timeout
	_check(world.player.glide.can_glide(), "can glide outside dead air")
	var dead_air: NoGlideZone = chain_room.get_node("ChainDeadAir") as NoGlideZone
	world.player.respawn_at(dead_air.global_position + dead_air.zone_size / 2.0)
	await get_tree().physics_frame
	_check(not world.player.glide.can_glide(), "can't glide inside dead air")

	# Regression (freeze bug): a sentry destroyed while the player rides the sail
	# used to leave the player at a NaN position (frozen grey screen).
	var sail_room: Room = world.rooms[5]
	world.jump_to_room(sail_room)
	await get_tree().create_timer(0.2).timeout
	var sail: SailPlatform = sail_room.get_node("Sail") as SailPlatform
	world.player.respawn_at(sail.global_position + Vector2(0, -1))
	await get_tree().create_timer(0.2).timeout
	sail.rail_speed = 60.0
	(sail_room.get_node("CeilingSentryA") as Sentry).destroy()
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check(world.player.global_position.is_finite(), "player position stays finite after a sentry kill on the sail")
	_check(not get_tree().paused, "hit-stop freeze ends (tree unpaused)")

	# Gust charges (GAME_DESIGN.md §5.3): one per airtime, a diamond makes it two for
	# this airtime only, a wind crystal tops it back up, landing resets it.
	var climb_room: Room = world.rooms[6]
	world.jump_to_room(climb_room)
	await get_tree().create_timer(0.3).timeout
	var gust: GustAbility = world.player.gust
	_check(gust.charges_remaining == 1, "one gust charge on the ground (found %d)" % gust.charges_remaining)
	_check(not world.player.overcharge_from_diamond(), "a gust diamond does nothing on the ground")
	var diamond: GustDiamond = climb_room.get_node("ClimbDiamond") as GustDiamond
	# Feet just under the diamond's center, in mid-air over the spike pit: touching it.
	world.player.respawn_at(diamond.global_position + Vector2(0, 4))
	for frame: int in 5:
		await get_tree().physics_frame
	_check(gust.charges_remaining == 2 and not diamond.is_available,
		"touching the diamond in the air gives two charges and uses it up (found %d)" % gust.charges_remaining)
	gust.begin_gust(Vector2.DOWN)
	_check(gust.charges_remaining == 1, "an air gust spends one charge (found %d)" % gust.charges_remaining)
	gust.begin_gust(Vector2.DOWN)
	_check(gust.charges_remaining == 0 and not gust.can_gust(), "no charge left: no third gust")
	_check(world.player.refill_from_crystal() and gust.charges_remaining == 1, "a wind crystal gives the charge back")
	# Move away first: an Area2D's overlap list only updates on the next physics step,
	# so a diamond reset while we're still on it would be grabbed again at once.
	world.player.respawn_at(climb_room.get_spawn_position() + Vector2(0, -24))
	await get_tree().physics_frame
	await get_tree().physics_frame
	climb_room.reset_objects()
	_check(diamond.is_available, "a room reset brings the diamond back at once")
	# The diamond bonus is for this airtime only: landing takes it back, unused.
	_check(world.player.overcharge_from_diamond() and gust.charges_remaining == 2, "test setup: two charges in the air")
	for frame: int in 60:
		await get_tree().physics_frame
		if world.player.is_on_floor():
			break
	await get_tree().physics_frame
	_check(gust.charges_remaining == 1, "landing drops an unused diamond bonus back to one (found %d)" % gust.charges_remaining)
	# Respawn timer: use the diamond, go stand safely on the floor, wait it out.
	world.player.respawn_at(diamond.global_position + Vector2(0, 4))
	for frame: int in 5:
		await get_tree().physics_frame
	_check(not diamond.is_available, "test setup: diamond used again")
	world.player.respawn_at(climb_room.get_spawn_position())
	await get_tree().create_timer(diamond.respawn_time + 0.2).timeout
	_check(diamond.is_available, "the diamond respawns after %.1f s" % diamond.respawn_time)

	# Polish (Stage 10): squash on jump and on a hard landing.
	var player: Player = world.player
	var squash_pivot: Node2D = player.get_node("SquashPivot") as Node2D
	world.jump_to_room(world.rooms[0])
	await get_tree().create_timer(0.3).timeout
	player.start_ground_jump()
	_check(squash_pivot.scale.y > 1.0, "jump stretches the body tall")
	player.respawn_at(world.rooms[0].get_spawn_position() + Vector2(0, -40))
	await get_tree().create_timer(0.2).timeout  # let the respawn pop settle
	for frame: int in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	_check(squash_pivot.scale.y < 1.0, "hard landing squashes the body flat")

	# A freeze frame ending while a menu is open must not unpause the menu.
	await get_tree().create_timer(0.3).timeout
	FX.freeze(0.05)
	FX.set_menu_pause(true)
	await get_tree().create_timer(0.15, true, false, true).timeout
	_check(get_tree().paused, "menu stays paused after a freeze ends")
	FX.set_menu_pause(false)
	_check(not get_tree().paused, "closing the menu unpauses")

	# Pause menu: Esc opens it (game paused), Esc again closes it.
	var pause_menu: PauseMenu = world.get_node("PauseMenu") as PauseMenu
	_press_action(&"pause")
	await get_tree().process_frame
	_check(pause_menu.menu_root.visible and get_tree().paused, "Esc opens the pause menu and pauses")
	_press_action(&"pause")
	await get_tree().process_frame
	_check(not pause_menu.menu_root.visible and not get_tree().paused, "Esc again closes it and resumes")

	_check(world.rooms[6].get_node_or_null("Goal") != null, "the goal is in the last room")
	GameState.finish_run()
	await get_tree().process_frame
	_check((world.get_node("EndScreen") as EndScreen).visible, "end screen visible after finish_run")

	print("[SmokeTest] %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(failures)


## Sends a key press for `action_name` through the normal input path, as if typed.
func _press_action(action_name: StringName) -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
	print("[SmokeTest] %s: %s" % ["ok  " if condition else "FAIL", description])

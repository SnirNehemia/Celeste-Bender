extends Node
## Headless smoke test for the Earth chapter (Stage E7, scenes/earth_world.tscn).
## Run: godot --headless --path . res://tests/earth_chapter_smoke_test.tscn
## Prints PASS/FAIL per check and quits with exit code 1 if anything failed.
##
## It can't play the rooms like a person, so it checks two things:
##   1. STRUCTURE: 10 rooms in order, Earth-only, an Earth layer each, every spawn on
##      solid ground, the wall gaps between neighbours line up, the Goal ends the run.
##   2. KEY MOVES: the one move each room is built around really works there, with
##      the player placed right before it (a super jump clears room 1's ledge, the
##      snake bridges in room 6 are exactly long enough, the crate reaches the
##      plate in room 8...). Enemies that would get in the way are defeated first.
## Whether a room is FUN, or fair from its spawn, is for play-testing.

const WORLD_SCENE: PackedScene = preload("res://scenes/earth_world.tscn")
const TILE: int = 8
## The tile layers that make a cell solid (the "Hidden" layer is open air).
const TILE_LAYER_NAMES: Array[String] = ["Tiles", "Grass", "Earth"]

var failures: int = 0
var world: RoomManager
var player: Player


func _ready() -> void:
	world = WORLD_SCENE.instantiate() as RoomManager
	add_child(world)
	await get_tree().create_timer(0.3).timeout
	player = world.player
	# Test the chapter's defaults, whatever earth_tuning.tres has saved for the toggles.
	player.earth_tuning.shadow_steerable = false
	player.earth_tuning.boulder_hover_aim = true
	_check_structure()
	await _check_spawns()
	await _check_room_01()
	await _check_room_02()
	await _check_room_03()
	await _check_room_04()
	await _check_room_06()
	await _check_room_07()
	await _check_room_08()
	await _check_room_10()
	await _check_room_edges()
	await _check_one_tile_gap()
	await _check_goal()
	print("[EarthChapterTest] %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


# --- Structure ---------------------------------------------------------------------

func _check_structure() -> void:
	_check(world.rooms.size() == 10, "the chapter has 10 rooms (%d)" % world.rooms.size())
	for room_index: int in world.rooms.size():
		var room: Room = world.rooms[room_index]
		_check(room.get_node_or_null("Earth") is EarthLayer, "%s has an Earth layer" % room.display_title)
		_check(not room.air_allowed and room.earth_allowed, "%s is Earth-only" % room.display_title)
		if room_index == 0:
			continue
		# Neighbours touch edge to edge, and their wall gaps line up row by row.
		var previous: Room = world.rooms[room_index - 1]
		_check(is_equal_approx(previous.get_bounds().end.x, room.get_bounds().position.x),
			"%s starts where the previous room ends" % room.display_title)
		var last_column: int = int(previous.room_size.x) / TILE - 1
		var gaps_match: bool = true
		var open_rows: int = 0
		for row: int in range(1, 22):
			var previous_open: bool = not _is_tile(previous, Vector2i(last_column, row))
			var next_open: bool = not _is_tile(room, Vector2i(0, row))
			gaps_match = gaps_match and previous_open == next_open
			if previous_open and next_open:
				open_rows += 1
		_check(gaps_match and open_rows >= 2, "the gap into %s lines up (%d rows open)" % [room.display_title, open_rows])
	var last_room: Room = world.rooms[world.rooms.size() - 1]
	_check(last_room.get_node_or_null("Goal") is Goal, "the last room has the Goal")


## Every spawn point stands on solid ground: the player lands and stays alive.
func _check_spawns() -> void:
	for room: Room in world.rooms:
		world.jump_to_room(room)
		_quiet_enemies(room)
		await _wait_game(0.4)
		_check(player.is_on_floor() and not player.is_dead() and room.get_bounds().has_point(player.global_position),
			"%s: the spawn point is on solid ground" % room.display_title)


# --- Key moves ---------------------------------------------------------------------

## Room 1: a super jump from the patch's last tile clears the 7-tile ledge.
func _check_room_01() -> void:
	var room: Room = await _enter(0)
	await _super_jump_onto(room, Vector2i(21, 20), 13, "room 1: a super jump from the patch lands on the ledge")


## Room 2: one super jump per tower.
func _check_room_02() -> void:
	var room: Room = await _enter(1)
	await _super_jump_onto(room, Vector2i(16, 20), 13, "room 2: tower A's tile super-jumps you onto tower A")
	await _super_jump_onto(room, Vector2i(23, 13), 6, "room 2: tower B's tile (on tower A) super-jumps you onto tower B")


## Room 3: under the overhang a super jump only bonks: it neither kills you (crushed)
## nor skips the rock footholds by reaching the tower top.
func _check_room_03() -> void:
	var room: Room = await _enter(2)
	await _place(room, Vector2i(25, 20))
	await _press_action(&"earth_column")
	Input.action_press(&"move_right")
	await _wait_game(1.2)
	Input.action_release(&"move_right")
	var feet_row: float = (player.global_position.y - room.global_position.y) / TILE
	_check(not player.is_dead() and feet_row > 13.5,
		"room 3: a super jump under the overhang bonks, no crush, no tower (feet on row %.1f)" % feet_row)


## Room 4: a big rock breaks the cracked wall; a big rock out of ledge B opens the
## tunnel, and the tunnel leads to room 5.
func _check_room_04() -> void:
	var room: Room = await _enter(3)
	var wall: CrackedWall = room.get_node("CrackedWall") as CrackedWall
	await _place(room, Vector2i(7, 13))
	var rock: Boulder = await _tear_big_rock()
	_check(rock != null and rock.is_big(), "room 4: a big rock can be torn out of ledge A")
	if rock != null:
		await _wait_until(func() -> bool: return rock.is_in_perfect_window(), 1.0)
		await _press_action(&"earth_boulder")
		await _wait_until(func() -> bool: return wall.is_broken, 2.0)
	_check(wall.is_broken, "room 4: the big rock breaks the cracked wall")
	await _place(room, Vector2i(21, 13))
	var hidden: HiddenLayer = room.get_node("Hidden") as HiddenLayer
	rock = await _tear_big_rock()
	await _wait_physics_frames(2)
	_check(rock != null and rock.is_big() and not hidden.is_covered(Vector2i(22, 16)),
		"room 4: a big rock out of ledge B opens the hidden tunnel")
	if rock != null and is_instance_valid(rock):
		rock.drop()
	await _wait_game(1.5)
	await _check_room_04_breach(room)
	await _place(room, Vector2i(21, 13))
	rock = await _tear_big_rock()
	await _wait_physics_frames(2)
	if rock != null and is_instance_valid(rock):
		rock.drop()
	await _wait_game(1.5)
	# Drop into the 2x2 hole and walk the tunnel out.
	player.respawn_at(room.global_position + Vector2(23 * TILE, 13 * TILE - 2))
	Input.action_press(&"move_right")
	await _wait_until(func() -> bool: return world.current_room == world.rooms[4], 4.0)
	Input.action_release(&"move_right")
	_check(world.current_room == world.rooms[4], "room 4: the tunnel leads out into room 5")


## Room 4, after the E7 play-test: a hole that reaches the tunnel only one tile wide is
## widened to two (the breach crumbles), so you can always drop in.
func _check_room_04_breach(room: Room) -> void:
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	# A big rock one column too far left: its 2x2 hole (columns 21-22) overlaps the
	# 2-wide shaft (22-23) by only one column.
	room.reset_objects()
	await _wait_physics_frames(3)
	await _place(room, Vector2i(20, 13))
	var rock: Boulder = await _tear_big_rock()
	await _wait_physics_frames(2)
	_check(not earth.is_solid(Vector2i(23, 13)) and not earth.is_solid(Vector2i(23, 14)),
		"room 4: a big rock off by one column: the breach widens to two tiles (column 23 crumbles)")
	if rock != null and is_instance_valid(rock):
		rock.drop()
	await _wait_game(1.0)
	# Two small rocks straight down (a 1-tile shaft): widened the same way.
	room.reset_objects()
	await _wait_physics_frames(3)
	for dig: int in 2:
		await _place(room, Vector2i(21, 13))
		await _press_action(&"earth_boulder")
		# Throw it straight up, PERFECTLY, into the ceiling (it shatters there): a weak
		# throw would fall back, stick in the hole and plug it.
		var small_rock: Boulder = player.boulder.held_boulder
		Input.action_press(&"move_up")
		if small_rock != null:
			await _wait_until(func() -> bool: return small_rock.is_in_perfect_window(), 1.5)
		await _press_action(&"earth_boulder")
		Input.action_release(&"move_up")
		await _wait_game(1.0)
	var opened: bool = not earth.is_solid(Vector2i(22, 14)) and not earth.is_solid(Vector2i(23, 14)) \
		and not earth.is_solid(Vector2i(23, 13))
	_check(opened, "room 4: a 1-tile hole dug down into the tunnel widens to two tiles")
	room.reset_objects()
	await _wait_physics_frames(3)


## Room 6: two snake bridges, each exactly long enough, then walk to the far ledge.
func _check_room_06() -> void:
	var room: Room = await _enter(5)
	await _place(room, Vector2i(7, 17))
	var snake: EarthSnake = await _bend_snake_at(Vector2i(9, 17), Vector2i.RIGHT)
	await _wait_until(func() -> bool: return snake == null or not snake.is_moving(), 3.0)
	_check(snake != null and snake.segment_cells.size() == 9 and snake.harden_reason == "solid",
		"room 6: the near ledge's snake spans the first gap to the island (%s)" % _describe(snake))
	await _wait_real(0.3)
	await _place(room, Vector2i(19, 17))
	snake = await _bend_snake_at(Vector2i(20, 17), Vector2i.RIGHT)
	await _wait_until(func() -> bool: return snake == null or not snake.is_moving(), 3.0)
	var reaches_far_ledge: bool = snake != null and snake.segment_cells.size() == 6 \
		and snake.segment_cells.has(Vector2i(26, 17))
	_check(reaches_far_ledge, "room 6: the island's 6 tiles bridge the second gap exactly (%s)" % _describe(snake))
	await _wait_real(0.3)
	Input.action_press(&"move_right")
	await _wait_game(1.5)
	Input.action_release(&"move_right")
	_check(not player.is_dead() and player.global_position.x > room.global_position.x + 27 * TILE,
		"room 6: walk over both bridges to the far ledge")


## Room 7: a super jump reaches the floating platform, a straight throw from it
## destroys the ledge sentry, and the exit door opens once all three are beaten.
func _check_room_07() -> void:
	var room: Room = await _enter(6)
	await _super_jump_onto(room, Vector2i(18, 20), 14, "room 7: a super jump from the floor lands on the floating platform", 0.6)
	var ledge_sentry: Sentry = room.get_node("LedgeSentry") as Sentry
	await _place(room, Vector2i(21, 14))
	await _press_action(&"earth_boulder")
	var rock: Boulder = player.boulder.held_boulder
	if rock != null:
		await _wait_until(func() -> bool: return rock.is_in_perfect_window(), 1.5)
		await _press_action(&"earth_boulder")
		await _wait_until(func() -> bool: return ledge_sentry.is_destroyed, 1.5)
	_check(ledge_sentry.is_destroyed, "room 7: a straight throw from the platform destroys the ledge sentry")
	room.reset_objects()
	await _wait_physics_frames(2)
	_quiet_enemies(room)
	var door: Door = room.get_node("ExitDoor") as Door
	_check(door.open_amount == 0.0, "room 7: the exit door starts closed")
	(room.get_node("Wisp") as Wisp).defeat()
	(room.get_node("FloorSentry") as Sentry).destroy()
	await _wait_game(0.3)
	_check(door.open_amount == 0.0, "room 7: ...and stays closed while a sentry is left")
	(room.get_node("LedgeSentry") as Sentry).destroy()
	await _wait_game(0.5)
	_check(door.open_amount > 0.9, "room 7: all three beaten: the door opens")


## Room 8: a snake up one tile and then right pushes the crate onto the plate.
func _check_room_08() -> void:
	var room: Room = await _enter(7)
	var plate: Switch = room.get_node("Plate") as Switch
	var door: Door = room.get_node("Door") as Door
	await _place(room, Vector2i(7, 20))
	var snake: EarthSnake = await _bend_snake_at(Vector2i(8, 20), Vector2i.UP)
	if snake != null:
		snake.queue_turn(Vector2i.RIGHT)
		await _wait_until(func() -> bool: return not snake.is_moving(), 4.0)
	await _wait_game(0.5)
	_check(plate.is_on(), "room 8: the snake pushes the crate onto the plate (%s)" % _describe(snake))
	_check(door.open_amount > 0.9, "room 8: the plate opens the door")


## Room 10: the bridge from ledge B spans the chasm with all 12 tiles.
func _check_room_10() -> void:
	var room: Room = await _enter(9)
	await _place(room, Vector2i(18, 8))
	var snake: EarthSnake = await _bend_snake_at(Vector2i(20, 8), Vector2i.RIGHT)
	await _wait_until(func() -> bool: return snake == null or not snake.is_moving(), 4.0)
	_check(snake != null and snake.segment_cells.size() == 12 and snake.segment_cells.has(Vector2i(32, 8)),
		"room 10: ledge B's 12 tiles bridge the chasm to the far ledge (%s)" % _describe(snake))


## Enemies stay in their room: a wisp walking at a wall gap turns round there, and an
## orb flying out through a gap pops.
func _check_room_edges() -> void:
	var room: Room = await _enter(4)
	var wisp: Wisp = room.get_node("FloorWisp") as Wisp
	wisp.reset()
	wisp.global_position = room.global_position + Vector2(10.0, 160.0)
	wisp.patrol_direction = -1.0
	player.respawn_at(room.global_position + Vector2(300.0, 160.0))
	await _wait_game(1.0)
	_check(wisp.state == Wisp.State.PATROL and room.get_bounds().has_point(wisp.global_position + Vector2(0.0, -2.0)) \
		and wisp.patrol_direction > 0.0,
		"a wisp walking into room 5's left gap turns round inside the room (x %.1f)" % (wisp.global_position.x - room.global_position.x))
	room = await _enter(8)
	var orb: SentryOrb = (load("res://scenes/enemies/sentry_orb.tscn") as PackedScene).instantiate() as SentryOrb
	room.add_child(orb)
	orb.launch(room.global_position + Vector2(12.0, 15 * TILE), Vector2(-60.0, 0.0), null)
	await _wait_game(0.5)
	_check(not is_instance_valid(orb), "an orb flying out through room 9's left gap pops at the edge")


## A snake raised one tile from a wall, with the player in the gap (after the E7
## play-test): the player used to be exactly a tile wide and got wedged there, unable
## to fall or jump. The hitbox is now a little narrower than a tile.
func _check_one_tile_gap() -> void:
	var room: Room = await _enter(0)
	# Room 1: earth columns 17-21, the ledge wall at column 22. Stand at 21 facing left.
	await _place(room, Vector2i(21, 20))
	player.facing_direction = -1.0
	var snake: EarthSnake = await _bend_snake_at(Vector2i(20, 20), Vector2i.UP)
	await _wait_until(func() -> bool: return snake == null or not snake.is_moving(), 3.0)
	await _wait_physics_frames(10)
	_check(snake != null and snake.segment_cells.has(Vector2i(20, 19)) and player.is_on_floor(),
		"a snake one tile from the wall: the player in the gap still stands on the floor")
	var feet_before: float = player.global_position.y
	await _press_action(&"jump")
	await _wait_game(0.15)
	_check(player.global_position.y < feet_before - 8.0,
		"...and can jump up the 1-tile gap (rose %.1f px)" % (feet_before - player.global_position.y))
	await _wait_game(0.6)


## Touching the Goal ends the run (the end screen listens to GameState.run_finished).
func _check_goal() -> void:
	var room: Room = world.rooms[9]
	var goal: Goal = room.get_node("Goal") as Goal
	player.respawn_at(goal.global_position + Vector2(12.0, 32.0))
	await _wait_game(0.3)
	_check(GameState.is_run_finished, "touching the Goal ends the run")


# --- Helpers -----------------------------------------------------------------------

## Jumps to room `room_index` (0-based) with its enemies out of the way.
func _enter(room_index: int) -> Room:
	var room: Room = world.rooms[room_index]
	# jump_to_room() is ignored during a camera slide between rooms: let it finish.
	await _wait_until(func() -> bool: return not world.is_transitioning, 2.0)
	world.jump_to_room(room)
	await _wait_physics_frames(2)
	_quiet_enemies(room)
	await _wait_physics_frames(2)
	return room


## Defeats wisps and silences sentries, so a move check isn't ended by an enemy.
func _quiet_enemies(room: Room) -> void:
	for child: Node in room.get_children():
		if child is Wisp:
			(child as Wisp).defeat()
		elif child is Sentry:
			(child as Sentry).can_fire = false


## Stands the player on tile `cell`'s top (its top row = the floor), facing right.
func _place(room: Room, cell: Vector2i) -> void:
	player.respawn_at(room.global_position + Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE))
	player.facing_direction = 1.0
	await _wait_game(0.15)


## From the top of `cell`: tap A (super jump), hold right for `hold_right_seconds`,
## and check the player ends standing on a floor at tile row `target_row` (and alive).
## A short platform needs a short press, or you run off its far end.
func _super_jump_onto(room: Room, cell: Vector2i, target_row: int, description: String,
		hold_right_seconds: float = 0.9) -> void:
	await _place(room, cell)
	await _press_action(&"earth_column")
	Input.action_press(&"move_right")
	await _wait_game(hold_right_seconds)
	Input.action_release(&"move_right")
	await _wait_game(0.3)
	var feet_row: float = (player.global_position.y - room.global_position.y) / TILE
	_check(player.is_on_floor() and not player.is_dead() and absf(feet_row - target_row) < 0.1,
		"%s (feet on row %.1f)" % [description, feet_row])


func _describe(snake: EarthSnake) -> String:
	if snake == null:
		return "no snake"
	return "%d tiles, %s" % [snake.segment_cells.size(), snake.harden_reason]


## True if `cell` (room tile coordinates) has a solid tile in any tile layer.
func _is_tile(room: Room, cell: Vector2i) -> bool:
	for layer_name: String in TILE_LAYER_NAMES:
		var layer: TileMapLayer = room.get_node_or_null(layer_name) as TileMapLayer
		if layer != null and layer.get_cell_source_id(cell) != -1:
			return true
	return false


## Holds S until the rock is out of its hole (it grows big), releases. The held rock.
func _tear_big_rock() -> Boulder:
	Input.parse_input_event(_make_action_event(&"earth_boulder", true))
	await get_tree().process_frame
	await _wait_game(player.earth_tuning.boulder_tear_time + 0.05)
	Input.parse_input_event(_make_action_event(&"earth_boulder", false))
	await get_tree().process_frame
	await get_tree().physics_frame
	return player.boulder.held_boulder


## Holds A until the shadow is on `cell`'s `normal` face, releases: the snake (or null).
func _bend_snake_at(cell: Vector2i, normal: Vector2i) -> EarthSnake:
	Input.action_press(&"earth_column")
	await _wait_physics_frames(2)
	var waited: float = 0.0
	while waited < 3.0 and player.earth_bend.is_bending:
		var face: EarthFace = player.earth_bend.get_shadow_face()
		if face.cell == cell and face.normal == normal:
			break
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	Input.action_release(&"earth_column")
	await _wait_physics_frames(2)
	return player.earth_snake.active_snake


## Presses an action like a real key: as input events, a few frames apart (see
## tests/earth_smoke_test.gd for why).
func _press_action(action: StringName) -> void:
	Input.parse_input_event(_make_action_event(action, true))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.parse_input_event(_make_action_event(action, false))
	await get_tree().process_frame
	await get_tree().physics_frame


func _make_action_event(action: StringName, pressed: bool) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


## Waits physics frames until `condition` is true, at most `seconds` of game time.
func _wait_until(condition: Callable, seconds: float) -> void:
	var waited: float = 0.0
	while waited < seconds:
		if condition.call():
			return
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()


func _wait_game(seconds: float) -> void:
	await _wait_until(func() -> bool: return false, seconds)


func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _wait_physics_frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS  %s" % description)
	else:
		failures += 1
		print("FAIL  %s" % description)

extends Node
## Headless smoke test for the Earth chapter (Stages E1+). Not part of the game.
##
## Loads tests/earth_test_world.tscn and checks, by script, what can be checked
## without a person at the keyboard. Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/earth_smoke_test.tscn

const WORLD_SCENE: PackedScene = preload("res://tests/earth_test_world.tscn")

var failures: int = 0


func _ready() -> void:
	var world: RoomManager = WORLD_SCENE.instantiate() as RoomManager
	add_child(world)
	# Let the player drop onto the floor and the room manager pick the room.
	await get_tree().create_timer(0.3).timeout
	var player: Player = world.player
	var room: Room = world.current_room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer

	await _check_e1_earth_ground(player, room, earth)
	await _check_e2_bend_core(player, room, earth)
	# Let FX's slow-motion safety timer run out before quitting (a timer still pending
	# at quit is reported as a leak).
	await _wait_real(player.earth_tuning.bend_max_time + 0.5)

	print("[EarthSmokeTest] %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Stage E1: earth tiles, faces, fresh/used state, reset, element flags.
func _check_e1_earth_ground(player: Player, room: Room, earth: EarthLayer) -> void:
	_check(player.is_on_floor(), "player stands on the floor after spawning")
	_check(not player.is_element_allowed(Player.ELEMENT_AIR), "Air is off in the Earth test room")
	_check(player.is_element_allowed(Player.ELEMENT_EARTH), "Earth is on in the Earth test room")

	# Faces: which sides of which tiles touch open air.
	_check(earth.is_face_exposed(Vector2i(24, 13), Vector2i.UP), "floating block: top face exposed")
	_check(not earth.is_face_exposed(Vector2i(24, 13), Vector2i.DOWN), "floating block: inner face hidden")
	_check(earth.is_face_exposed(Vector2i(24, 14), Vector2i.DOWN), "floating block: underside exposed")
	_check(earth.is_face_exposed(Vector2i(24, 13), Vector2i.LEFT), "floating block: left side exposed")
	_check(earth.is_face_exposed(Vector2i(38, 5), Vector2i.LEFT), "right earth wall faces left")
	_check(not earth.is_face_exposed(Vector2i(38, 5), Vector2i.RIGHT), "right earth wall's back is against gray rock")
	_check(earth.is_face_exposed(Vector2i(37, 1), Vector2i.DOWN), "ceiling earth faces down")
	_check(not earth.is_earth(Vector2i(12, 20)), "the floor gap at column 12 is gray, not earth")

	# The face under the feet (spawn x = 24 px: feet span columns 2 and 3).
	var start_face: EarthFace = player.earth_bend.find_start_surface()
	_check(start_face != null and start_face.normal == Vector2i.UP, "player touches a fresh earth floor face")
	if start_face == null:
		return
	_check(start_face.cell == Vector2i(3, 20), "the face under the middle of the feet is (3, 20), got %s" % start_face.cell)

	# Spend both tiles under the feet: no fresh earth to bend from any more.
	_check(earth.mark_used(Vector2i(3, 20)), "mark_used on a fresh tile succeeds")
	_check(not earth.mark_used(Vector2i(3, 20)), "a used tile can't be used again")
	var other_foot: EarthFace = player.earth_bend.find_start_surface()
	_check(other_foot != null and other_foot.cell == Vector2i(2, 20), "standing half on used earth still finds the fresh tile")
	earth.mark_used(Vector2i(2, 20))
	_check(player.earth_bend.find_start_surface() == null, "no start face when both tiles under the feet are used")
	_check(player.earth_bend.describe_contact().begins_with("used floor"), "debug label reads 'used floor ...'")
	# The fade runs in real time: after the fade time it's fully dark.
	await get_tree().create_timer(player.earth_tuning.used_fade_time + 0.1).timeout
	_check(is_equal_approx(float(earth.used_fade_progress[Vector2i(3, 20)]), 1.0), "used tile fully faded after used_fade_time")

	# Room reset (death or R) makes every tile fresh again.
	room.reset_objects()
	_check(earth.is_fresh(Vector2i(3, 20)) and earth.is_fresh(Vector2i(2, 20)), "room reset makes used tiles fresh")
	_check(player.earth_bend.find_start_surface() != null, "fresh earth under the feet again after reset")


## Stage E2: the bend state, real-time shadow, path rules, cancel, auto-fire.
## Keys are "pressed" with Input.action_press(), which the game reads like a real key.
func _check_e2_bend_core(player: Player, room: Room, earth: EarthLayer) -> void:
	var tuning: EarthTuning = player.earth_tuning
	var bend: EarthBendAbility = player.earth_bend
	player.respawn_at(room.get_spawn_position())
	player.facing_direction = 1.0
	await _wait_real(0.2)

	# Air is off here: X does nothing.
	Input.action_press("dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dash")
	_check(player.state_machine.current_state.name != &"Dash", "dash refused in an Earth-only room")

	# Hold A: rooted bend in slow motion, shadow waits under the feet.
	Input.action_press("earth_column")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.state_machine.current_state.name == &"EarthBend", "holding A on earth enters EarthBend")
	_check(is_equal_approx(Engine.time_scale, tuning.bend_time_scale), "world slowed to bend_time_scale (%.2f)" % Engine.time_scale)
	await _wait_real(0.3)
	_check(bend.shadow_distance == 0.0, "shadow still under the feet before shadow_start_delay")
	# 60 px/s after the 0.5 s wait: at ~1.2 s real it has crawled ~40 px (5 tiles).
	await _wait_real(0.9)
	var crawled: float = bend.shadow_distance
	_check(crawled > 25.0 and crawled < 60.0, "shadow crawls in real time (%.0f px after ~1.2 s)" % crawled)
	_check(player.velocity == Vector2.ZERO, "player rooted while bending")
	var target_cell: Vector2i = bend.get_target_face().cell
	Input.action_release("earth_column")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.state_machine.current_state.name != &"EarthBend", "releasing A ends the bend")
	_check(is_equal_approx(Engine.time_scale, 1.0), "normal speed after the bend")
	_check(not earth.is_fresh(target_cell), "the tile under the shadow (%s) is used" % target_cell)
	_check(earth.is_fresh(Vector2i(4, 20)), "tiles the shadow only passed over stay fresh")

	# Jump cancels: no earth used, no jump.
	Input.action_press("earth_column")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait_real(0.8)
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	_check(player.state_machine.current_state.name != &"EarthBend", "jump cancels the bend")
	_check(earth.used_fade_progress.size() == 1, "cancel used no earth (still only one used tile)")
	await get_tree().physics_frame
	_check(player.velocity.y >= 0.0, "the cancelling jump press didn't also jump")
	Input.action_release("earth_column")
	await get_tree().physics_frame

	# Holding past bend_max_time fires by itself.
	Input.action_press("earth_column")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait_real(tuning.bend_max_time + 0.2)
	_check(player.state_machine.current_state.name != &"EarthBend", "the bend fires by itself after bend_max_time")
	_check(earth.used_fade_progress.size() == 2, "the auto-fire used one tile")
	Input.action_release("earth_column")
	await get_tree().physics_frame

	# Quick tap: release before the shadow moves = the tile under the feet.
	room.reset_objects()
	await get_tree().physics_frame
	var feet_face: EarthFace = bend.find_start_surface()
	Input.action_press("earth_column")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("earth_column")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not earth.is_fresh(feet_face.cell), "a quick tap uses the tile under the feet")

	# Path rules, checked on the path itself (no waiting): outer corners on the
	# floating block, inner corners where the floor meets the right wall and the wall
	# meets the ceiling.
	room.reset_objects()
	var block_top: EarthFace = EarthFace.new(earth, Vector2i(29, 13), Vector2i.UP)
	var expected_wrap: Array = [
		[Vector2i(29, 13), Vector2i.UP], [Vector2i(30, 13), Vector2i.UP],
		[Vector2i(30, 13), Vector2i.RIGHT], [Vector2i(30, 14), Vector2i.RIGHT],
		[Vector2i(30, 14), Vector2i.DOWN], [Vector2i(29, 14), Vector2i.DOWN],
	]
	_check(_path_matches(bend, block_top, expected_wrap), "shadow wraps the floating block: top -> side -> underside")
	var floor_end: EarthFace = EarthFace.new(earth, Vector2i(36, 20), Vector2i.UP)
	var expected_climb: Array = [
		[Vector2i(36, 20), Vector2i.UP], [Vector2i(37, 20), Vector2i.UP],
		[Vector2i(38, 19), Vector2i.LEFT], [Vector2i(38, 18), Vector2i.LEFT],
	]
	_check(_path_matches(bend, floor_end, expected_climb), "shadow climbs from the floor onto the right wall")
	var wall_top: EarthFace = EarthFace.new(earth, Vector2i(38, 3), Vector2i.LEFT)
	var expected_ceiling: Array = [
		[Vector2i(38, 3), Vector2i.LEFT], [Vector2i(38, 2), Vector2i.LEFT],
		[Vector2i(37, 1), Vector2i.DOWN], [Vector2i(36, 1), Vector2i.DOWN],
	]
	_check(_path_matches(bend, wall_top, expected_ceiling, Vector2i.UP), "shadow climbs the wall onto the ceiling")

	# The shadow crosses gray rock (columns 12-13) and used earth, but can't erupt there.
	earth.mark_used(Vector2i(15, 20))
	var before_gray: EarthFace = EarthFace.new(earth, Vector2i(9, 20), Vector2i.UP)
	var expected_crossing: Array = [
		[Vector2i(9, 20), Vector2i.UP], [Vector2i(10, 20), Vector2i.UP],
		[Vector2i(11, 20), Vector2i.UP], [Vector2i(12, 20), Vector2i.UP],
		[Vector2i(13, 20), Vector2i.UP], [Vector2i(14, 20), Vector2i.UP],
		[Vector2i(15, 20), Vector2i.UP],
	]
	_check(_path_matches(bend, before_gray, expected_crossing), "shadow crosses gray rock and used earth")
	# Release over gray: fizzle, no earth used.
	var used_before: int = earth.used_fade_progress.size()
	bend.begin_bend(&"earth_column", before_gray)
	bend.path_tangents[0] = Vector2i.RIGHT
	bend.shadow_distance = 3 * 8.0  # on (12, 20), gray
	bend._extend_path_to_shadow()
	_check(bend.get_target_face() == null, "no target while the shadow is over gray rock")
	_check(bend.release_bend() == null, "releasing over gray rock fizzles")
	_check(earth.used_fade_progress.size() == used_before, "a fizzle uses no earth")
	room.reset_objects()

	# A real wall bend: wall-sliding on the right earth wall, then A.
	player.respawn_at(Vector2(296, 100))
	# Hold Right in the air: the player drifts into the wall and Fall turns into
	# WallSlide by itself, like in play.
	Input.action_press("move_right")
	for frame_index: int in 15:
		await get_tree().physics_frame
	_check(player.state_machine.current_state.name == &"WallSlide", "test setup: wall-sliding on the right earth wall")
	Input.action_press("earth_column")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.state_machine.current_state.name == &"EarthBend", "A while wall-sliding on earth starts a bend (state %s)" % player.state_machine.current_state.name)
	_check(bend.is_bending and bend.path[0].normal == Vector2i.LEFT, "the wall bend starts on the wall's face")
	_check(is_equal_approx(Engine.time_scale, player.earth_tuning.bend_time_scale), "wall bend slows the world")
	Input.action_release("earth_column")
	Input.action_release("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	room.reset_objects()
	player.respawn_at(room.get_spawn_position())

	# Wall bends crawl DOWN by default (Up held = up).
	var wall_face: EarthFace = EarthFace.new(earth, Vector2i(38, 10), Vector2i.LEFT)
	bend.begin_bend(&"earth_column", wall_face)
	_check(bend.path_tangents[0] == Vector2i.DOWN, "a wall bend crawls down by default")
	bend.cancel_bend()
	_check(bend.is_bending == false, "path checks left no bend running")


## Starts a bend at `start_face` crawling in `start_tangent` (default: facing right),
## pushes the shadow forward by enough steps, and compares the path with `expected`
## ([cell, normal] pairs). Cancels the bend afterwards.
func _path_matches(bend: EarthBendAbility, start_face: EarthFace, expected: Array,
		start_tangent: Vector2i = Vector2i.RIGHT) -> bool:
	bend.begin_bend(&"earth_column", start_face)
	bend.path_tangents[0] = start_tangent
	bend.shadow_distance = (expected.size() - 1) * 8.0
	bend._extend_path_to_shadow()
	var matches: bool = bend.path.size() >= expected.size()
	for step_index: int in mini(expected.size(), bend.path.size()):
		var face: EarthFace = bend.path[step_index]
		if face.cell != expected[step_index][0] or face.normal != expected[step_index][1]:
			print("      step %d: got %s %s, expected %s %s" % [step_index, face.cell, face.normal,
				expected[step_index][0], expected[step_index][1]])
			matches = false
	bend.cancel_bend()
	return matches


## Waits `seconds` of REAL time (not slowed by Engine.time_scale).
func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS  %s" % description)
	else:
		failures += 1
		print("FAIL  %s" % description)

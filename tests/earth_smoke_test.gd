extends Node
## Headless smoke test for the Earth chapter (Stages E1+). Not part of the game.
##
## Loads tests/earth_test_world.tscn and checks, by script, what can be checked
## without a person at the keyboard. Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/earth_smoke_test.tscn

const WORLD_SCENE: PackedScene = preload("res://tests/earth_test_world.tscn")
const MIXED_WORLD_SCENE: PackedScene = preload("res://tests/mixed_test_world.tscn")
const WIND_ZONE_SCENE: PackedScene = preload("res://scenes/objects/wind_zone.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/objects/crate.tscn")

var failures: int = 0
## Names of the check sections that ran to their end. A script error inside a
## section (say, a null rock) ends it silently, so _ready() checks this list.
var finished_sections: Array[String] = []


func _ready() -> void:
	var world: RoomManager = WORLD_SCENE.instantiate() as RoomManager
	add_child(world)
	# Let the player drop onto the floor and the room manager pick the room.
	await get_tree().create_timer(0.3).timeout
	var player: Player = world.player
	var room: Room = world.current_room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer

	# The rock sections below (E4-E6) were written for the HOP. Hover aim is the default
	# since E7: off for them; _check_hover_aim turns it on for its own checks.
	player.earth_tuning.boulder_hover_aim = false
	# The shadow sections need the crawling shadow, whatever earth_tuning.tres says
	# (the steerable one is a toggle you may have saved on while trying it).
	player.earth_tuning.shadow_steerable = false
	await _check_e1_earth_ground(player, room, earth)
	# E2 and E3 test the bend and the column AT THE SHADOW with long A bends. With one
	# key (the default since E5) those would be snakes, so it's off for these two.
	player.earth_tuning.one_key_column_snake = false
	await _check_e2_bend_core(player, room, earth)
	await _check_e3_column(world, player)
	player.earth_tuning.one_key_column_snake = true
	await _check_e4_boulder(world, player)
	await _check_e4b_ground(world)
	await _check_e4c_hidden(world, player)
	await _check_e4c2_big_rock(world, player)
	await _check_e4c3_loose_rocks(world, player)
	await _check_e4d_pebbles(world, player)
	await _check_e4e_rock_pillar_look(world, player)
	await _check_e5_snake(world, player)
	await _check_one_key_column_snake(world, player)
	await _check_e6_walls_enemies(world, player)
	await _check_hover_aim(world, player)
	await _check_steered_shadow(world, player)
	await _check_hidden_objects(world, player)
	await _check_shatter_creations(world, player)
	await _check_grass_blades(world, player)
	# Let FX's slow-motion safety timer run out before switching worlds (a timer still
	# pending at quit is reported as a leak).
	await _wait_real(player.earth_tuning.bend_max_time + 0.5)
	world.queue_free()
	await get_tree().process_frame
	await _check_mixed_enemies()

	for section_name: String in ["E1", "E2", "E3", "E4", "E4b", "E4c", "E4c2", "E4c3", "E4d", "E4e", "E5", "one-key", "E6", "hover-aim", "steered-shadow", "hidden-objects", "shatter", "grass", "mixed"]:
		_check(finished_sections.has(section_name), "section %s ran to its end" % section_name)
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
	_check(not earth.is_earth(Vector2i(12, 20)), "the floor patch at column 12 is grass, not earth")
	_check(not earth.is_shadow_blocking(Vector2i(12, 20)), "grass doesn't block the shadow")
	_check(earth.is_shadow_blocking(Vector2i(5, 12)), "the plain gray ledge blocks the shadow")

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
	# Visually too: its tint is back to plain white.
	_check(earth.get_cell_modulate(Vector2i(3, 20)) == Color.WHITE,
		"a reset tile is drawn fresh again (modulate %s)" % earth.get_cell_modulate(Vector2i(3, 20)))
	_check(player.earth_bend.find_start_surface() != null, "fresh earth under the feet again after reset")
	finished_sections.append("E1")


## Stage E2: the bend state, real-time shadow, path rules, cancel, auto-fire.
## Keys are "pressed" with Input.action_press(), which the game reads like a real key.
func _check_e2_bend_core(player: Player, room: Room, earth: EarthLayer) -> void:
	var tuning: EarthTuning = player.earth_tuning
	var bend: EarthBendAbility = player.earth_bend
	player.respawn_at(room.get_spawn_position())
	player.facing_direction = 1.0
	await _wait_real(0.2)

	# Air is off here: Z does nothing.
	Input.action_press("gust")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("gust")
	var state_after_gust: StringName = player.state_machine.current_state.name
	_check(state_after_gust != &"GustAim" and state_after_gust != &"GustRecoil", "gust refused in an Earth-only room")

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

	# Holding past bend_max_time fires by itself. (Reset first: the first column is a
	# pillar now, and the long shadow would climb it and fizzle there.)
	room.reset_objects()
	await get_tree().physics_frame
	Input.action_press("earth_column")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait_real(tuning.bend_max_time + 0.2)
	_check(player.state_machine.current_state.name != &"EarthBend", "the bend fires by itself after bend_max_time")
	_check(earth.used_fade_progress.size() == 1, "the auto-fire used one tile")
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

	# The shadow crosses grass (columns 12-13) and used earth, but can't erupt there.
	earth.mark_used(Vector2i(15, 20))
	var before_gray: EarthFace = EarthFace.new(earth, Vector2i(9, 20), Vector2i.UP)
	var expected_crossing: Array = [
		[Vector2i(9, 20), Vector2i.UP], [Vector2i(10, 20), Vector2i.UP],
		[Vector2i(11, 20), Vector2i.UP], [Vector2i(12, 20), Vector2i.UP],
		[Vector2i(13, 20), Vector2i.UP], [Vector2i(14, 20), Vector2i.UP],
		[Vector2i(15, 20), Vector2i.UP],
	]
	_check(_path_matches(bend, before_gray, expected_crossing), "shadow crosses grass and used earth")
	# Release over grass: fizzle, no earth used.
	var used_before: int = earth.used_fade_progress.size()
	bend.begin_bend(&"earth_column", before_gray)
	bend.path_tangents[0] = Vector2i.RIGHT
	bend.shadow_distance = 3 * 8.0  # on (12, 20), grass
	bend._extend_path_to_shadow()
	_check(bend.get_target_face() == null, "no target while the shadow is over grass")
	_check(bend.release_bend() == null, "releasing over grass fizzles")
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
	finished_sections.append("E2")


## Stage E3: the Earth Column, in RoomEarthB (tests/rooms/room_earth_b.tscn, at x 320).
func _check_e3_column(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthB") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	var tuning: EarthTuning = player.earth_tuning
	var bend: EarthBendAbility = player.earth_bend
	world.jump_to_room(room)
	await _wait_physics_frames(10)
	_check(player.is_on_floor() and world.current_room == room, "test setup: standing in RoomEarthB")
	var floor_y: float = player.global_position.y

	# A regular full jump, for comparison.
	Input.action_press("jump")
	var jump_peak: float = floor_y - await _track_highest_feet(player, 0.6)
	Input.action_release("jump")
	await _wait_physics_frames(30)

	# Quick tap A: the column rises under the feet and throws us up (super jump).
	var feet_cell: Vector2i = bend.find_start_surface().cell
	Input.action_press("earth_column")
	await _wait_physics_frames(2)
	Input.action_release("earth_column")
	await _wait_physics_frames(3)
	_check(player.state_machine.current_state.name == &"Launched", "quick tap: thrown into the Launched state (got %s)" % player.state_machine.current_state.name)
	var super_peak: float = floor_y - await _track_highest_feet(player, 0.6)
	var ratio: float = super_peak / maxf(jump_peak, 1.0)
	_check(ratio > 1.7 and ratio < 2.4, "super jump ~2x a regular jump (%.0f px vs %.0f px, x%.2f)" % [super_peak, jump_peak, ratio])
	_check(not earth.is_fresh(feet_cell), "the super jump used the tile under the feet")
	var columns: Array[EarthColumn] = _find_columns(room)
	_check(columns.size() == 1 and is_equal_approx(columns[0].length, tuning.column_length), "one full-length column stands in the room")
	# It's a platform now: we land on its top and stay there (no second throw).
	await _wait_real(1.0)
	var column_top: float = floor_y - tuning.column_length
	_check(player.is_on_floor() and absf(player.global_position.y - column_top) < 0.5,
		"landed on top of the risen column (feet y %.1f, top %.1f)" % [player.global_position.y, column_top])
	_check(player.state_machine.current_state.name == &"Idle", "a risen column is a platform, not a spring (state %s)" % player.state_machine.current_state.name)
	# Standing on the pillar, A starts a bend (the shadow starts on the pillar's top).
	var pillar_face: EarthFace = bend.find_start_surface()
	_check(pillar_face != null and earth.is_column(pillar_face.cell), "standing on a pillar is a bend start")
	_check(bend.describe_contact().begins_with("pillar floor"), "debug label reads 'pillar floor ...' (%s)" % bend.describe_contact())
	var used_before_pillar: int = earth.used_fade_progress.size()
	Input.action_press("earth_column")
	await _wait_physics_frames(2)
	_check(player.state_machine.current_state.name == &"EarthBend", "A on a pillar enters EarthBend")
	Input.action_release("earth_column")
	await _wait_physics_frames(2)
	_check(earth.used_fade_progress.size() == used_before_pillar and _find_columns(room).size() == 1,
		"a quick tap on a pillar fizzles (nothing erupts from the pillar itself)")
	# Room reset removes it.
	room.reset_objects()
	await get_tree().physics_frame
	_check(_find_columns(room).is_empty(), "room reset removes columns")
	_check(earth.column_cells.is_empty(), "room reset clears the pillars' cells")
	# Gray rock under the pit's spikes stops the shadow: from the pit's left edge it
	# wraps down the pit wall (earth, then grass) and waits there.
	var pit_edge: EarthFace = EarthFace.new(earth, Vector2i(14, 20), Vector2i.UP)
	bend.begin_bend(&"earth_column", pit_edge)
	bend.path_tangents[0] = Vector2i.RIGHT
	bend.shadow_distance = 10 * 8.0
	bend._extend_path_to_shadow()
	var last_face: EarthFace = bend.path[bend.path.size() - 1]
	_check(bend.path.size() == 3 and last_face.cell == Vector2i(14, 21) and last_face.normal == Vector2i.RIGHT,
		"gray rock under the spikes stops the shadow (path %d faces, ends at %s)" % [bend.path.size(), last_face.cell])
	_check(is_equal_approx(bend.shadow_distance, 2 * 8.0), "the blocked shadow waits on its last face")
	bend.cancel_bend()

	# Side spring: between the block (columns 10-11) and the pit, facing left. The
	# shadow climbs onto the block's right face and the column throws us right.
	player.respawn_at(room.global_position + Vector2(13 * 8 + 4, 160))
	player.facing_direction = -1.0
	await _wait_physics_frames(5)
	Input.action_press("earth_column")
	var waited: float = 0.0
	while waited < 2.0 and not (bend.is_bending and bend.get_target_face() != null \
			and bend.get_target_face().normal == Vector2i.RIGHT):
		await _wait_real(0.02)
		waited += 0.02
	_check(bend.is_bending and bend.get_target_face().cell == Vector2i(11, 19), "test setup: shadow on the block's right face")
	Input.action_release("earth_column")
	# The release lands between physics frames on a real-time timer, so the column
	# reaches us 3-4 frames later: wait for the launch instead of a fixed frame count.
	await _wait_until(func() -> bool: return player.state_machine.current_state.name == &"Launched", 10.0 / 60.0)
	_check(player.state_machine.current_state.name == &"Launched" and player.velocity.x > 150.0 and player.velocity.y < 0.0,
		"the wall column throws us right and up (velocity %s)" % player.velocity)
	await _wait_real(1.2)
	var landed_x: float = player.global_position.x - room.global_position.x
	_check(not player.is_dead() and landed_x > 21 * 8, "the side spring clears the 6-tile pit (landed at x %.0f)" % landed_x)
	room.reset_objects()

	# Crush: a column from the overhang's underside onto the wisp below.
	var wisp: Wisp = room.get_node("Wisp") as Wisp
	wisp.global_position = room.global_position + Vector2(31 * 8 + 4, 160)
	wisp.velocity = Vector2.ZERO
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(31, 16), Vector2i.DOWN))
	await _wait_physics_frames(12)
	_check(wisp.state == Wisp.State.DEFEATED, "a column squeezing a wisp against the floor crushes it")

	# The player gets crushed too.
	room.reset_objects()
	wisp.defeat()  # it patrols under the overhang and would kill the player there
	player.respawn_at(room.global_position + Vector2(33 * 8 + 4, 160))
	await _wait_physics_frames(5)
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(33, 16), Vector2i.DOWN))
	await _wait_physics_frames(12)
	_check(player.is_dead(), "a column squeezing the player against the floor crushes them")
	# Let the room manager respawn us (and reset the room) before going on.
	await _wait_real(player.tuning.death_respawn_delay + 0.3)
	_check(not player.is_dead(), "test setup: respawned after the crush")

	# A wisp on top of a pillar walks off it, back down to the floor.
	room.reset_objects()
	await get_tree().physics_frame
	player.respawn_at(room.global_position + Vector2(27 * 8 + 4, 160))  # out of its way
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(7, 20), Vector2i.UP))
	await _wait_physics_frames(12)
	wisp.global_position = room.global_position + Vector2(7 * 8 + 4, 160 - tuning.column_length)
	wisp.velocity = Vector2.ZERO
	await _wait_real(1.5)
	var wisp_feet: float = wisp.global_position.y - room.global_position.y
	_check(wisp.state != Wisp.State.DEFEATED and absf(wisp_feet - 160.0) < 0.5,
		"a wisp on a pillar walks off it back to the floor (feet y %.1f)" % wisp_feet)
	room.reset_objects()
	player.respawn_at(room.get_spawn_position())

	# A column under the crate on the overhang throws it up.
	await _wait_physics_frames(2)
	var crate: Crate = room.get_node("Crate") as Crate
	var crate_start_y: float = crate.global_position.y
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(32, 15), Vector2i.UP))
	var crate_highest: float = crate_start_y
	var fastest_rise: float = 0.0
	for frame_index: int in 30:
		await get_tree().physics_frame
		crate_highest = minf(crate_highest, crate.global_position.y)
		fastest_rise = minf(fastest_rise, crate.velocity.y)
	_check(fastest_rise <= -tuning.column_launch_speed + 1.0, "a rising column throws the crate up (vy %.0f)" % fastest_rise)
	_check(crate_highest < crate_start_y - tuning.column_length - 5.0,
		"the crate flies above the column's top (%.0f px up)" % (crate_start_y - crate_highest))
	room.reset_objects()
	await get_tree().physics_frame
	finished_sections.append("E3")


## Stages E4 + E4a: the rock (8x8, torn out of the ground right next to the player),
## in RoomEarthC (tests/rooms/room_earth_c.tscn, at x 640). Floor surface: row 20
## (earth from column 5 to 27, 2 deep at columns 6-11). Earth wall face: column 28,
## rows 8-19, facing left. Gray pillar: columns 3-4, rows 12-19.
func _check_e4_boulder(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthC") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	var tuning: EarthTuning = player.earth_tuning
	world.jump_to_room(room)
	player.facing_direction = 1.0
	await _wait_physics_frames(10)
	_check(player.is_on_floor() and world.current_room == room, "test setup: standing in RoomEarthC")
	var feet_cell: Vector2i = player.earth_bend.find_start_surface().cell

	# Press S: no bend and no slow motion; the rock tears out of the tile AHEAD.
	var boulder: Boulder = await _rip_boulder(player)
	_check(boulder != null, "pressing S tears out a rock")
	if boulder == null:
		return
	_check(player.state_machine.current_state.name == &"BoulderHold", "rooted in BoulderHold (got %s)" % player.state_machine.current_state.name)
	_check(not player.earth_bend.is_bending, "no bend shadow for a rock")
	_check(is_equal_approx(Engine.time_scale, tuning.boulder_time_scale), "slow motion while the rock is held (%.2f)" % Engine.time_scale)
	_check(earth.is_fresh(feet_cell), "the tile under the feet is not torn")
	_check(not earth.is_earth(feet_cell + Vector2i(1, 0)), "the rock tears out the tile ahead of the feet (a hole)")
	_check(earth.is_fresh(feet_cell + Vector2i(2, 0)) and earth.torn_cells.size() == 1, "only one tile is torn")
	_check(boulder.perfect_time < INF, "the rock comes back down level with the player (at %.2f s)" % boulder.perfect_time)
	var peak_time: float = tuning.boulder_tear_time + boulder.get_hop_speed() / tuning.boulder_gravity
	# Watch the whole pop: tear, hop above the head and away, white twice, land, rest.
	var player_head_y: float = player.get_hitbox_rect().position.y
	var start_x: float = boulder.global_position.x
	var highest_bottom: float = INF
	var window_count: int = 0
	var was_in_window: bool = false
	var first_white_time: float = INF
	for frame_index: int in 300:
		if not is_instance_valid(boulder) or boulder.is_resting:
			break
		highest_bottom = minf(highest_bottom, boulder.global_position.y + tuning.boulder_size / 2.0)
		if boulder.is_in_perfect_window() and not was_in_window:
			window_count += 1
			first_white_time = minf(first_white_time, boulder.pop_elapsed)
		was_in_window = boulder.is_in_perfect_window()
		await get_tree().physics_frame
	_check(highest_bottom < player_head_y, "the rock hops above the player's head (bottom %.1f, head %.1f)" % [highest_bottom, player_head_y])
	_check(is_instance_valid(boulder) and boulder.global_position.x > start_x + 4.0, "the hop drifts away from the player")
	_check(window_count == 1 and first_white_time > peak_time,
		"the rock turns white once, on the way down (%d time(s), first at %.2f s, peak %.2f s)" % [window_count, first_white_time, peak_time])
	_check(is_instance_valid(boulder) and boulder.is_resting and boulder.is_throwable(), "an un-thrown rock lands and rests, still throwable")
	_check(player.velocity == Vector2.ZERO, "the player stays rooted while holding")
	await _wait_game(tuning.boulder_land_rest_time + 0.1)
	_check(is_instance_valid(boulder) and boulder.is_loose(), "an un-thrown rock lies loose after its rest (E4c3)")
	_check(player.state_machine.current_state.name == &"Idle", "the player is free once the rock is down, standing (state %s)" % player.state_machine.current_state.name)
	room.reset_objects()
	await _wait_physics_frames(2)

	# Perfect throw on the way UP (no arrow: facing right), into the earth wall.
	boulder = await _rip_boulder(player)
	await _wait_until(func() -> bool: return boulder.is_in_perfect_window(), 1.0)
	_check(boulder.is_in_perfect_window() and boulder.pop_elapsed > peak_time, "test setup: in the (way-down) perfect window")
	await _press_action("earth_boulder")
	_check(boulder.phase == Boulder.Phase.FLYING, "S again throws the rock")
	_check(absf(boulder.velocity.x - tuning.boulder_perfect_throw_speed) < 1.0 and absf(boulder.velocity.y) < 1.0,
		"a perfect throw flies straight at %.0f px/s (velocity %s)" % [tuning.boulder_perfect_throw_speed, boulder.velocity])
	_check(boulder.perfect_flash_remaining > 0.0, "a perfect throw flashes white")
	_check(player.state_machine.current_state.name != &"BoulderHold", "the throw frees the player")
	_check(is_equal_approx(Engine.time_scale, 1.0), "the throw ends the slow motion")
	await _wait_until(func() -> bool: return not is_instance_valid(boulder) or boulder.phase != Boulder.Phase.FLYING, 2.0)
	_check(is_instance_valid(boulder) and boulder.phase == Boulder.Phase.STUCK, "a rock thrown into an earth wall sticks")
	if not is_instance_valid(boulder) or boulder.phase != Boulder.Phase.STUCK:
		return
	var local_center: Vector2 = boulder.global_position - room.global_position
	_check(is_equal_approx(local_center.x, 28 * 8 - 4.0) and is_equal_approx(fmod(local_center.y, 8.0), 4.0),
		"the stuck rock is flush with the wall and on the tile grid (center %s)" % local_center)
	_check(boulder.collision_layer == 1, "a stuck rock is solid world")
	_check(boulder.perfect_flash_remaining == 0.0, "a stuck rock is back to rock color (no white left over)")
	var boulder_cell: Vector2i = earth.get_cell_at(boulder.global_position)
	_check(earth.is_column(boulder_cell), "the stuck rock's cell is registered as used earth")
	_check(earth.is_hardened(boulder_cell + Vector2i(1, 0)) and not earth.is_tearable(boulder_cell + Vector2i(1, 0)),
		"the wall tile holding the rock hardens (can't be torn out)")
	# Stand on it.
	player.respawn_at(boulder.global_position + Vector2(0, -20))
	await _wait_game(0.4)
	var boulder_top: float = boulder.global_position.y - tuning.boulder_size / 2.0
	_check(player.is_on_floor() and absf(player.global_position.y - boulder_top) < 0.5,
		"you can stand on a stuck rock (feet %.1f, top %.1f)" % [player.global_position.y, boulder_top])
	_check(player.earth_bend.describe_contact().begins_with("boulder floor"), "debug label reads 'boulder floor ...' (%s)" % player.earth_bend.describe_contact())
	# A straight perfect throw flies at chest height, so that step is at floor level.
	# For a higher step, aim diagonally up (Up + Right held while pressing S). From
	# column 20, 7 tiles from the wall (from further away it sails over the wall).
	player.respawn_at(room.global_position + Vector2(20 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	var low_step: Boulder = boulder
	boulder = await _rip_boulder(player)
	await _wait_until(func() -> bool: return boulder.is_in_perfect_window(), 1.0)
	Input.action_press("move_up")
	Input.action_press("move_right")
	await _press_action("earth_boulder")
	Input.action_release("move_up")
	Input.action_release("move_right")
	_check(boulder.velocity.x > 0.0 and boulder.velocity.y < 0.0, "Up + Right aims the throw diagonally up (velocity %s)" % boulder.velocity)
	await _wait_until(func() -> bool: return not is_instance_valid(boulder) or boulder.phase != Boulder.Phase.FLYING, 2.0)
	_check(is_instance_valid(boulder) and boulder.phase == Boulder.Phase.STUCK and boulder.global_position.y < low_step.global_position.y - 24.0,
		"a diagonal throw sticks a step higher up the wall")
	if not is_instance_valid(boulder) or boulder.phase != Boulder.Phase.STUCK:
		return
	# And wall-jump off it: drop beside its left side holding right, then jump.
	player.respawn_at(boulder.global_position + Vector2(-8.5, 4))
	Input.action_press("move_right")
	await _wait_until(func() -> bool: return player.state_machine.current_state.name == &"WallSlide", 1.0)
	_check(player.state_machine.current_state.name == &"WallSlide", "you can wall-slide on a stuck rock")
	await _press_action("jump")
	Input.action_release("move_right")
	_check(player.velocity.x < 0.0 and player.velocity.y < 0.0, "you can wall-jump off a stuck rock (velocity %s)" % player.velocity)
	await _wait_game(0.6)
	# Reset removes it, fills the hole and softens the hardened tile.
	room.reset_objects()
	await get_tree().physics_frame
	_check(_find_boulders(room).is_empty() and earth.column_cells.is_empty(), "room reset removes rocks and their cells")
	_check(earth.is_fresh(feet_cell + Vector2i(1, 0)) and earth.torn_cells.is_empty() and earth.hardened_cells.is_empty(),
		"room reset fills torn holes and clears hardening")
	player.respawn_at(room.get_spawn_position())
	player.facing_direction = 1.0
	await _wait_physics_frames(5)

	# Passing the player on the way UP doesn't count any more.
	boulder = await _rip_boulder(player)
	await _wait_until(func() -> bool: return boulder.is_hopping, 1.0)
	await _press_action("earth_boulder")
	_check(boulder.phase == Boulder.Phase.FLYING and boulder.velocity.x < tuning.boulder_perfect_throw_speed - 50.0
		and boulder.perfect_flash_remaining == 0.0,
		"a throw as the rock passes you on the way up is not perfect (%.0f px/s)" % boulder.velocity.x)
	await _wait_game(1.0)
	room.reset_objects()
	player.respawn_at(room.get_spawn_position())
	player.facing_direction = 1.0
	await _wait_physics_frames(5)

	# A throw at the top of the hop (between the windows) is weak and droops at once.
	boulder = await _rip_boulder(player)
	await _wait_until(func() -> bool: return boulder.pop_elapsed >= peak_time, 1.0)
	await _press_action("earth_boulder")
	_check(boulder.phase == Boulder.Phase.FLYING and boulder.velocity.x < tuning.boulder_min_throw_speed + 50.0,
		"a throw at the top of the hop is weak (%.0f px/s)" % boulder.velocity.x)
	_check(boulder.float_time_remaining < 0.1, "a weak throw falls at once (float %.2f s)" % boulder.float_time_remaining)
	await _wait_game(1.5)
	room.reset_objects()
	await _wait_physics_frames(2)

	# Jump lets go: no jump, and the rock lies loose once it lands (E4c3).
	boulder = await _rip_boulder(player)
	await _press_action("jump")
	_check(player.state_machine.current_state.name != &"BoulderHold" and player.velocity.y >= 0.0,
		"Jump lets go of the rock without jumping (state %s, velocity %s, rock %s)" % [player.state_machine.current_state.name,
			player.velocity, "none" if boulder == null else ("gone" if not is_instance_valid(boulder) else "dropped %s" % boulder.is_dropped)])
	_check(not is_instance_valid(boulder) or boulder.is_dropped, "the let-go rock is dropped")
	await _wait_game(0.8)
	_check(is_instance_valid(boulder) and boulder.is_loose(), "the let-go rock lies loose once it lands")

	# Digging: in the thick earth (columns 6-11), tear the tile ahead, then from the
	# same spot the one under it. Never the tile under the feet.
	room.reset_objects()
	player.respawn_at(room.global_position + Vector2(7 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	boulder = await _rip_boulder(player)
	_check(boulder != null and not earth.is_earth(Vector2i(8, 20)), "dig: the first rock tears out (8, 20)")
	_check(earth.is_face_exposed(Vector2i(8, 21), Vector2i.UP) and earth.is_fresh(Vector2i(8, 21)),
		"dig: the earth under the hole is exposed and fresh")
	await _wait_game(tuning.boulder_hold_time + 0.2)  # let it settle
	boulder = await _rip_boulder(player)
	_check(boulder != null and not earth.is_earth(Vector2i(8, 21)), "dig: the second rock tears out the hole's bottom (8, 21)")
	_check(earth.is_fresh(Vector2i(7, 20)), "dig: the tile under the feet (beside the hole) is never torn")
	await _wait_game(tuning.boulder_hold_time + 0.2)
	room.reset_objects()
	await get_tree().physics_frame
	_check(earth.is_earth(Vector2i(8, 20)) and earth.is_earth(Vector2i(8, 21)), "room reset fills a dug pit")

	# A pillar's foot hardens in a pyramid, so it can't be dug loose.
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(9, 20), Vector2i.UP))
	await _wait_physics_frames(12)
	var foot: Array[Vector2i] = [Vector2i(9, 20), Vector2i(8, 21), Vector2i(9, 21), Vector2i(10, 21)]
	var is_foot_hardened: bool = true
	for cell: Vector2i in foot:
		is_foot_hardened = is_foot_hardened and earth.is_hardened(cell)
	_check(is_foot_hardened, "a pillar hardens the earth under its base in a pyramid")
	_check(not earth.is_hardened(Vector2i(8, 20)) and not earth.is_hardened(Vector2i(7, 21)), "the pyramid is only 1, then 3 tiles wide")
	_check(earth.is_fresh(Vector2i(9, 21)), "hardened earth is still fresh (it can still be bent)")
	player.respawn_at(room.global_position + Vector2(7 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	boulder = await _rip_boulder(player)
	_check(boulder != null and not earth.is_earth(Vector2i(8, 20)), "pillar foot: the tile beside the pillar can still be torn")
	await _wait_game(tuning.boulder_hold_time + 0.2)
	var torn_before: int = earth.torn_cells.size()
	await _press_action("earth_boulder")
	_check(earth.torn_cells.size() == torn_before and earth.is_earth(Vector2i(8, 21)),
		"pillar foot: the hardened tile under the hole can't be torn out")
	room.reset_objects()
	await get_tree().physics_frame

	# Thrown into gray rock (the pillar on the left): shatters.
	player.respawn_at(room.get_spawn_position())
	player.facing_direction = -1.0
	await _wait_physics_frames(5)
	boulder = await _rip_boulder(player)
	await _wait_until(func() -> bool: return boulder.is_in_perfect_window(), 1.0)
	await _press_action("earth_boulder")
	_check(boulder.velocity.x < -300.0, "test setup: thrown left")
	await _wait_game(1.0)
	_check(not is_instance_valid(boulder) and _find_boulders(room).is_empty(), "a rock thrown into gray rock shatters")

	# A risen column bounces it back.
	room.reset_objects()
	player.respawn_at(room.get_spawn_position())
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(22, 20), Vector2i.UP))
	await _wait_physics_frames(12)
	boulder = await _rip_boulder(player)
	await _wait_until(func() -> bool: return boulder.is_in_perfect_window(), 1.0)
	await _press_action("earth_boulder")
	await _wait_until(func() -> bool: return not is_instance_valid(boulder) or boulder.velocity.x < 0.0, 1.0)
	_check(is_instance_valid(boulder) and boulder.velocity.x <= -tuning.boulder_column_bounce_speed + 1.0,
		"a rock bounces off a column (vx %.0f)" % (boulder.velocity.x if is_instance_valid(boulder) else 0.0))
	await _wait_game(1.5)

	# A thrown rock keeps flying while the next one is torn out (two at once).
	room.reset_objects()
	player.respawn_at(room.get_spawn_position())
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	var first: Boulder = await _rip_boulder(player)
	await _wait_until(func() -> bool: return first.pop_elapsed >= 0.3, 1.0)
	await _press_action("earth_boulder")
	player.facing_direction = -1.0
	await _wait_physics_frames(2)
	var second: Boulder = await _rip_boulder(player)
	_check(is_instance_valid(first) and second != null and second != first, "a new rock doesn't destroy the one in flight")
	await _wait_game(1.5)

	# Wall-sliding on the earth wall: the rock tears out of the wall below you, hops
	# AWAY from the wall, and a throw goes away from you, even with the arrow still
	# held into the wall.
	room.reset_objects()
	player.respawn_at(room.global_position + Vector2(27 * 8 + 4, 100))
	Input.action_press("move_right")
	await _wait_until(func() -> bool: return player.state_machine.current_state.name == &"WallSlide", 1.0)
	_check(player.state_machine.current_state.name == &"WallSlide", "test setup: wall-sliding on the earth wall")
	boulder = await _rip_boulder(player)
	_check(boulder != null and player.state_machine.current_state.name == &"BoulderHold", "S while wall-sliding tears a rock out of the wall")
	if boulder != null:
		await _wait_until(func() -> bool: return boulder.is_hopping, 1.0)
		await _wait_physics_frames(2)
		_check(boulder.velocity.x <= -tuning.boulder_wall_hop_away_speed + 1.0,
			"a rock from the wall hops away from the wall (vx %.0f)" % boulder.velocity.x)
		await _press_action("earth_boulder")  # Right is still held, into the wall
		_check(boulder.phase == Boulder.Phase.FLYING and boulder.velocity.x < 0.0,
			"a throw from the wall goes away from it, not into it (velocity %s)" % boulder.velocity)
	Input.action_release("move_right")
	await _wait_game(1.0)

	# No room for a rock: nothing torn. (Standing against the wall, facing it: the
	# tiles ahead are on the wall right beside the body.)
	room.reset_objects()
	player.respawn_at(room.global_position + Vector2(27 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	await _press_action("earth_boulder")
	await _wait_physics_frames(2)
	_check(earth.torn_cells.is_empty() and _find_boulders(room).is_empty() \
		and player.state_machine.current_state.name != &"BoulderHold",
		"no room for a rock: nothing is torn")
	room.reset_objects()
	await get_tree().physics_frame
	finished_sections.append("E4")


## Stage E4b: the GroundPainter in RoomEarthC (thick earth at columns 6-11, rows 20-21).
func _check_e4b_ground(world: RoomManager) -> void:
	var room: Room = world.get_node("RoomEarthC") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	var painter: GroundPainter = room.get_node_or_null("GroundPainter") as GroundPainter
	_check(painter != null, "an Earth room gets a GroundPainter")
	if painter == null:
		return
	room.reset_objects()
	await get_tree().process_frame
	_check(earth.self_modulate.a == 0.0 and (room.get_node("Grass") as TileMapLayer).self_modulate.a == 0.0,
		"the tile layers' own drawing is hidden (collision stays)")
	_check(painter.get_index() > room.get_node("Earth").get_index(), "the painter draws after the tile layers")
	# Pixels: the surface is a bright crust, deep inside a dark hatched color (not black).
	var surface_pixel: Vector2i = Vector2i(9 * 8 + 4, 20 * 8 + 2)
	var deep_pixel: Vector2i = Vector2i(34 * 8, 14 * 8)  # middle of the big grass block
	_check(painter.get_pixel_distance(surface_pixel) <= 4.0 and painter.get_pixel_color(surface_pixel).get_luminance() > 0.4,
		"the surface is a bright crust (luminance %.2f)" % painter.get_pixel_color(surface_pixel).get_luminance())
	var deep_color: Color = painter.get_pixel_color(deep_pixel)
	_check(painter.get_pixel_distance(deep_pixel) > 20.0 and deep_color.get_luminance() < 0.15 and deep_color.get_luminance() > 0.01,
		"deep inside is dark but not black (luminance %.3f)" % deep_color.get_luminance())
	_check(painter.get_pixel_color(deep_pixel) != painter.get_pixel_color(deep_pixel + Vector2i(3, 0)),
		"the inside is hatched (neighbouring stripes differ)")
	_check(painter.get_pixel_color(Vector2i(100, 80)).a == 0.0, "open air is left transparent")
	# Tearing a tile out redraws: the earth under the hole becomes bright crust.
	var under_hole: Vector2i = Vector2i(9 * 8 + 4, 21 * 8 + 1)
	var before_tear: float = painter.get_pixel_color(under_hole).get_luminance()
	earth.tear_out(Vector2i(9, 20))
	var after_tear: float = painter.get_pixel_color(under_hole).get_luminance()
	_check(after_tear > before_tear + 0.15 and painter.get_pixel_color(surface_pixel).a == 0.0,
		"a tear turns the newly exposed earth into bright crust (%.2f -> %.2f)" % [before_tear, after_tear])
	room.reset_objects()
	_check(is_equal_approx(painter.get_pixel_color(under_hole).get_luminance(), before_tear),
		"room reset restores the ground's drawing")
	# Used earth is drawn on the overlay, darker.
	earth.mark_used(Vector2i(14, 20))
	_check(earth.get_state_cells().has(Vector2i(14, 20)), "a used tile is drawn on the state overlay")
	await _wait_real(earth.earth_tuning.used_fade_time + 0.1)
	_check(earth.get_cell_modulate(Vector2i(14, 20)).get_luminance() < 0.6, "the overlay tint for used earth is dark")
	room.reset_objects()
	# Rooms without earth (the Air chapter) keep their tiles.
	var air_room_scene: PackedScene = load("res://scenes/rooms/room_01.tscn") as PackedScene
	var air_room: Room = air_room_scene.instantiate() as Room
	add_child(air_room)
	_check(air_room.get_node_or_null("GroundPainter") == null, "Air rooms keep their tile look (no painter)")
	air_room.queue_free()
	await get_tree().process_frame
	finished_sections.append("E4b")


## Stage E4c: the hidden tunnel in RoomEarthD (tests/rooms/room_earth_d.tscn, at
## x 960): columns 13-27, rows 16-17, under 2 tiles of earth (top surface row 14).
func _check_e4c_hidden(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthD") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	var hidden: HiddenLayer = room.get_node_or_null("Hidden") as HiddenLayer
	var painter: GroundPainter = room.get_node("GroundPainter") as GroundPainter
	var tuning: EarthTuning = player.earth_tuning
	_check(hidden != null and not hidden.collision_enabled, "RoomEarthD has a Hidden layer without collision")
	if hidden == null:
		return
	var tunnel_cell: Vector2i = Vector2i(20, 16)
	var tunnel_pixel: Vector2i = tunnel_cell * 8 + Vector2i(4, 4)
	_check(hidden.is_covered(tunnel_cell), "the tunnel starts covered")
	_check(not earth.is_face_exposed(Vector2i(20, 15), Vector2i.DOWN),
		"earth above a covered tunnel is not on the surface (the shadow can't crawl in)")
	_check(painter.get_pixel_color(tunnel_pixel).a == 1.0 and painter.get_pixel_distance(tunnel_pixel) > 10.0
		and painter.get_pixel_color(tunnel_pixel).get_luminance() < 0.15,
		"the covered tunnel is drawn as deep earth")
	_check(hidden.self_modulate.a == 0.0, "the Hidden layer's own drawing is hidden at runtime")

	# From the top of the wall (feet on column 17, facing right), a small rock's hole
	# (1 deep) doesn't reach the tunnel 2 tiles down.
	# jump_to_room (the F2 picker's move): no camera slide, which would freeze the player.
	world.jump_to_room(room)
	player.respawn_at(room.global_position + Vector2(17 * 8 + 4, 14 * 8))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	var boulder: Boulder = await _rip_boulder(player)
	_check(boulder != null and not earth.is_earth(Vector2i(18, 14)) and hidden.is_covered(tunnel_cell),
		"a small rock's hole (18, 14) doesn't reach the tunnel")
	await _wait_game(tuning.boulder_hold_time + 0.2)
	room.reset_objects()
	await _wait_physics_frames(2)

	# A big rock (hold S) tears out (18-19, 14-15): its hole reaches the tunnel.
	boulder = await _tear_big_rock(player)
	_check(boulder != null and boulder.is_big() and not earth.is_earth(Vector2i(19, 15)),
		"a big rock tears out a 2x2 block down to the tunnel")
	_check(not hidden.is_covered(tunnel_cell) and not hidden.is_covered(Vector2i(13, 17)) and not hidden.is_covered(Vector2i(27, 17)),
		"the hole reaching the tunnel reveals the whole connected tunnel")
	_check(earth.is_face_exposed(Vector2i(20, 15), Vector2i.DOWN), "the tunnel's ceiling is on the surface now")
	_check(painter.get_pixel_color(tunnel_pixel).a == 0.0, "the ground is redrawn with the tunnel open")
	_check(hidden.get_cover_alpha(Vector2i(25, 17)) > 0.0 and not hidden.get_crumbling_cells().is_empty(),
		"the cover crumbles (still partly visible right after the reveal)")
	await _wait_real(tuning.hidden_crumble_time + 15 * tuning.hidden_crumble_step_delay + 0.2)
	_check(hidden.get_crumbling_cells().is_empty(), "the cover is gone after the crumble")
	await _wait_game(tuning.boulder_hold_time + 0.2)

	# Drop down the 2x2 hole into the tunnel, then walk right under the barrier.
	player.respawn_at(room.global_position + Vector2(19 * 8, 14 * 8))
	await _wait_game(0.6)
	_check(player.is_on_floor() and absf(player.global_position.y - (room.global_position.y + 18 * 8)) < 1.0,
		"the player drops down the hole onto the tunnel floor (feet y %.1f)" % (player.global_position.y - room.global_position.y))
	Input.action_press("move_right")
	await _wait_game(1.5)
	Input.action_release("move_right")
	_check(player.global_position.x > room.global_position.x + 29 * 8,
		"the player walks through the tunnel into the right chamber (x %.0f)" % (player.global_position.x - room.global_position.x))

	# Reset covers it again.
	room.reset_objects()
	await get_tree().physics_frame
	_check(hidden.is_covered(tunnel_cell) and earth.is_earth(Vector2i(18, 14)) and earth.is_earth(Vector2i(19, 15)), "room reset fills the hole and covers the tunnel")
	_check(painter.get_pixel_color(tunnel_pixel).a == 1.0, "room reset draws the tunnel as earth again")
	finished_sections.append("E4c")


## Stage E4c2: the big rock, in RoomEarthC (earth floor row 20, thick at columns 6-11
## where row 21 is earth too; grass under the rest).
func _check_e4c2_big_rock(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthC") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	var tuning: EarthTuning = player.earth_tuning
	world.jump_to_room(room)

	# A tap is still a small rock.
	player.respawn_at(room.global_position + Vector2(7 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	var boulder: Boulder = await _rip_boulder(player)
	await _wait_game(tuning.boulder_tear_time + 0.05)
	_check(is_instance_valid(boulder) and not boulder.is_big() and earth.torn_cells.size() == 1,
		"a tap of S still tears out one small rock")
	await _wait_game(tuning.boulder_hold_time + 0.2)
	room.reset_objects()
	await _wait_physics_frames(2)

	# Hold S in the thick earth: the rock grows out of a 2x2 hole ahead and under it.
	boulder = await _tear_big_rock(player)
	_check(boulder != null and boulder.is_big() and is_equal_approx(boulder.size, tuning.big_rock_size),
		"holding S grows the rock into a big rock")
	var block_torn: bool = true
	for cell: Vector2i in [Vector2i(8, 20), Vector2i(9, 20), Vector2i(8, 21), Vector2i(9, 21)]:
		block_torn = block_torn and earth.torn_cells.has(cell)
	_check(block_torn and earth.torn_cells.size() == 4, "the big rock tears out the 2x2 block (8-9, 20-21)")
	_check(earth.is_fresh(Vector2i(7, 20)), "never the tile under the feet")
	# Perfect throw: a little slower than a small rock's, and it sticks as a 2x2 block.
	await _wait_until(func() -> bool: return is_instance_valid(boulder) and boulder.is_in_perfect_window(), 1.5)
	await _press_action("earth_boulder")
	_check(is_instance_valid(boulder) and boulder.phase == Boulder.Phase.FLYING and absf(boulder.velocity.length()
		- tuning.boulder_perfect_throw_speed * tuning.big_rock_throw_speed_scale) < 1.0,
		"a big rock throws at big_rock_throw_speed_scale of the speed (velocity %s)" % (boulder.velocity if is_instance_valid(boulder) else Vector2.ZERO))
	await _wait_until(func() -> bool: return not is_instance_valid(boulder) or boulder.phase != Boulder.Phase.FLYING, 2.0)
	_check(is_instance_valid(boulder) and boulder.phase == Boulder.Phase.STUCK, "a big rock thrown at earth sticks")
	if is_instance_valid(boulder) and boulder.phase == Boulder.Phase.STUCK:
		var stuck_cells: int = 0
		for cell: Vector2i in earth.column_cells:
			if earth.column_cells[cell] == boulder:
				stuck_cells += 1
		_check(stuck_cells == 4, "a stuck big rock fills 4 cells (%d)" % stuck_cells)
		_check(earth.hardened_cells.size() == 2, "both tiles behind a stuck big rock harden (%d)" % earth.hardened_cells.size())
	room.reset_objects()
	await _wait_physics_frames(2)

	# Where the 2x2 block doesn't fit (grass under the floor at column 15), it stays small.
	player.respawn_at(room.global_position + Vector2(14 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	boulder = await _tear_big_rock(player)
	_check(boulder != null and not boulder.is_big() and earth.torn_cells.size() == 1,
		"no room for a 2x2 block: the held rock stays small")
	await _wait_game(tuning.boulder_hold_time + 0.2)
	room.reset_objects()
	await _wait_physics_frames(2)
	finished_sections.append("E4c2")


## Stage E4c3: loose rocks, in RoomEarthC (floor surface row 20, y 160).
func _check_e4c3_loose_rocks(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthC") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	var tuning: EarthTuning = player.earth_tuning
	world.jump_to_room(room)
	player.respawn_at(room.global_position + Vector2(14 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)

	# Not thrown: it lands and lies there, solid.
	var rock: Boulder = await _rip_boulder(player)
	await _wait_until(func() -> bool: return is_instance_valid(rock) and rock.is_loose(), tuning.boulder_hold_time + 0.5)
	_check(is_instance_valid(rock) and rock.is_loose(), "an un-thrown rock lies loose")
	if not is_instance_valid(rock) or not rock.is_loose():
		return
	await _wait_physics_frames(2)
	_check(rock.collision_layer == 1, "a loose rock is solid")
	_check(player.state_machine.current_state.name != &"BoulderHold", "the player is free while the rock lies there")

	# S right next to it lifts it: no new earth torn, and it hops like a fresh rock.
	var rock_left_edge: float = rock.global_position.x - rock.size / 2.0
	player.respawn_at(Vector2(rock_left_edge - 4.0 - 2.0, room.global_position.y + 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	var torn_before: int = earth.torn_cells.size()
	# HELD S lifts it (a tap would shatter it, after E7).
	await _hold_action("earth_boulder", player.earth_tuning.shatter_tap_time + 0.1)
	_check(player.boulder.held_boulder == rock and rock.phase == Boulder.Phase.POPPING and rock.is_hopping,
		"holding S next to a loose rock lifts it (state %s)" % player.state_machine.current_state.name)
	_check(earth.torn_cells.size() == torn_before, "lifting uses no earth")
	_check(player.state_machine.current_state.name == &"BoulderHold", "the player holds the lifted rock")
	await _wait_until(func() -> bool: return is_instance_valid(rock) and rock.is_in_perfect_window(), 1.0)
	_check(is_instance_valid(rock) and rock.is_in_perfect_window(), "a lifted rock has the perfect window")
	await _press_action("earth_boulder")
	_check(is_instance_valid(rock) and rock.phase == Boulder.Phase.FLYING, "a lifted rock can be thrown")
	room.reset_objects()
	await _wait_physics_frames(2)

	# A loose rock is a step: stand on it. A tap of S on top of it shatters it (after
	# E7: touching a creation + tap = pebbles), it can't be lifted from under the feet.
	rock = await _rip_boulder(player)
	await _press_action("jump")  # let go: it lies loose once it lands
	await _wait_until(func() -> bool: return is_instance_valid(rock) and rock.is_loose(), 1.5)
	await _wait_physics_frames(2)
	if is_instance_valid(rock) and rock.is_loose():
		var rock_top: float = rock.global_position.y - rock.size / 2.0
		player.respawn_at(Vector2(rock.global_position.x, rock_top - 1.0))
		await _wait_game(0.3)
		_check(player.is_on_floor() and absf(player.global_position.y - rock_top) < 1.0,
			"the player stands on a loose rock (feet %.1f, rock top %.1f)" % [player.global_position.y, rock_top])
		await _press_action("earth_boulder")
		_check(not is_instance_valid(rock) or rock.phase == Boulder.Phase.SHATTERED,
			"a tap of S standing on a loose rock shatters it (never lifts it from under the feet)")
	else:
		_check(false, "test setup: a let-go rock lies loose")
	room.reset_objects()
	await _wait_physics_frames(2)
	_check(_find_boulders(room).is_empty(), "room reset clears loose rocks")

	# At most loose_rock_max_per_room: the oldest crumbles. Rocks dropped from the air
	# over the floor, away from the player.
	var rocks: Array[Boulder] = []
	for rock_index: int in tuning.loose_rock_max_per_room + 1:
		var dropped: Boulder = Boulder.new()
		dropped.setup(room.global_position + Vector2((20 + rock_index * 2) * 8 + 4, 140), Vector2.UP, 0.0, 0.0, tuning)
		room.add_child(dropped)
		dropped.drop()
		rocks.append(dropped)
		await _wait_game(0.15)  # one after another, so they settle in order
	await _wait_game(1.0)
	var loose_count: int = 0
	for dropped: Boulder in rocks:
		if is_instance_valid(dropped) and dropped.is_loose():
			loose_count += 1
	_check(loose_count == tuning.loose_rock_max_per_room and not is_instance_valid(rocks[0]),
		"at most %d loose rocks per room, the oldest crumbles (%d loose)" % [tuning.loose_rock_max_per_room, loose_count])
	room.reset_objects()
	await _wait_physics_frames(2)
	finished_sections.append("E4c3")


## HOLDS S through the rock's tear (a big rock, Stage E4c2), then lets go. Returns the
## held rock, or null.
## Stage E4d: pebbles. Earth C's flat floor (top at y = 160) right of the start.
func _check_e4d_pebbles(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthC") as Room
	var field: PebbleField = room.get_node_or_null("PebbleField") as PebbleField
	var tuning: EarthTuning = player.earth_tuning
	_check(field != null, "an Earth room has a PebbleField")
	if field == null:
		return
	world.jump_to_room(room)
	player.respawn_at(room.global_position + Vector2(14 * 8 + 4, 160))
	await _wait_physics_frames(5)
	_check(field.pebble_positions.is_empty(), "no pebbles after a room reset")

	# A tear leaves pebbles that stay after the gravel is gone.
	player.facing_direction = 1.0
	await _rip_boulder(player)
	await _press_action("jump")  # let the rock go
	await _wait_game(1.0)
	_check(not field.pebble_positions.is_empty(), "tearing a rock leaves pebbles (%d)" % field.pebble_positions.size())
	room.reset_objects()
	await _wait_physics_frames(2)
	_check(field.pebble_positions.is_empty(), "room reset clears the pebbles")

	# A gravel burst over the floor: the pebbles fall and come to rest ON the floor.
	var drop_point: Vector2 = room.global_position + Vector2(22 * 8, 150)
	FX.spawn_gravel(drop_point, 20, Vector2.UP)
	await _wait_game(1.5)
	var resting_count: int = 0
	for pebble_index: int in field.pebble_positions.size():
		var bottom: Vector2 = field.pebble_positions[pebble_index]
		if field.pebble_is_moving[pebble_index] == 0 and absf(bottom.y - 159.5) < 0.01:
			resting_count += 1
	_check(resting_count == field.pebble_positions.size() and resting_count > 0,
		"pebbles come to rest on the floor (%d of %d)" % [resting_count, field.pebble_positions.size()])

	# Running through them scatters them.
	var before_run: PackedVector2Array = field.pebble_positions.duplicate()
	player.respawn_at(room.global_position + Vector2(18 * 8, 160))
	await _wait_physics_frames(3)
	Input.parse_input_event(_make_action_event(&"move_right", true))
	await _wait_game(0.6)
	Input.parse_input_event(_make_action_event(&"move_right", false))
	await _wait_physics_frames(2)
	_check(_count_moved(before_run, field.pebble_positions) > 0, "running through pebbles kicks them")
	await _wait_game(1.5)

	# A gust blows the ones near its origin away along the gust.
	player.respawn_at(room.global_position + Vector2(8 * 8, 160))  # out of the way
	await _wait_physics_frames(3)
	# Blown LEFT, from just right of the pebbles: the run above kicks them right, often
	# up against the earth wall at x 224, where a rightward gust has no room to move
	# them. Only pebbles within the gust's reach of its origin are measured (ones past
	# it rightly don't move).
	var rightmost_x: float = -INF
	for point: Vector2 in field.pebble_positions:
		rightmost_x = maxf(rightmost_x, point.x)
	var gust_origin_local: Vector2 = Vector2(rightmost_x + 8.0, 156)
	var reached_indices: Array[int] = []
	for pebble_index: int in field.pebble_positions.size():
		if field.pebble_positions[pebble_index].distance_to(gust_origin_local) <= tuning.pebble_gust_reach:
			reached_indices.append(pebble_index)
	var before_gust: float = _average_x_of(field.pebble_positions, reached_indices)
	field.receive_gust_from(Vector2.LEFT, 260.0, room.to_global(gust_origin_local))
	await _wait_game(1.0)
	var after_gust: float = _average_x_of(field.pebble_positions, reached_indices)
	_check(not reached_indices.is_empty() and after_gust < before_gust - 4.0,
		"a gust blows pebbles away (%d in reach, average x %.1f -> %.1f)" % [reached_indices.size(), before_gust, after_gust])

	# A sideways wind zone rolls them along the floor.
	room.reset_objects()
	await _wait_physics_frames(2)
	FX.spawn_gravel(drop_point, 20, Vector2.UP)
	await _wait_game(1.5)
	var wind: WindZone = WIND_ZONE_SCENE.instantiate() as WindZone
	wind.zone_size = Vector2(80, 24)
	wind.wind_direction = Vector2.RIGHT
	wind.wind_strength = 50.0
	room.add_child(wind)
	wind.position = Vector2(19 * 8, 160 - 24)
	field.room_wind_zones.append(wind)  # zones are normally found once at startup
	var before_wind: float = _average_x(field.pebble_positions)
	await _wait_game(0.5)
	_check(_average_x(field.pebble_positions) > before_wind + 6.0,
		"a wind zone rolls pebbles along (average x %.1f -> %.1f)" % [before_wind, _average_x(field.pebble_positions)])
	field.room_wind_zones.erase(wind)
	wind.queue_free()

	# The cap: the oldest go first.
	FX.spawn_gravel(drop_point, 1000, Vector2.UP)
	_check(field.pebble_positions.size() == tuning.pebble_max_per_room,
		"pebbles are capped per room (%d)" % field.pebble_positions.size())

	# Only the current room simulates: a pebble in the air in another room hangs there.
	var other_room: Room = world.get_node("RoomEarthA") as Room
	world.jump_to_room(other_room)
	await _wait_physics_frames(2)
	room.reset_objects()
	field.add_pebble(room.global_position + Vector2(22 * 8, 100), Vector2.UP)
	var frozen_position: Vector2 = field.pebble_positions[0]
	await _wait_physics_frames(10)
	_check(field.pebble_positions[0] == frozen_position, "pebbles outside the current room don't simulate")
	room.reset_objects()
	world.jump_to_room(room)
	await _wait_physics_frames(2)
	finished_sections.append("E4d")


## Stage E4e: rock and pillar look. Earth C's flat floor again; the open air above it
## (x 16-24 tiles, y ~110) for a free flight.
func _check_e4e_rock_pillar_look(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthC") as Room
	var field: PebbleField = room.get_node("PebbleField") as PebbleField
	var tuning: EarthTuning = player.earth_tuning
	world.jump_to_room(room)
	player.respawn_at(room.global_position + Vector2(8 * 8 + 4, 160))
	await _wait_physics_frames(5)

	# A rock thrown through open air: a lumpy outline, it tumbles, and it sheds pebbles.
	var flyer: Boulder = Boulder.new()
	flyer.setup(room.global_position + Vector2(16 * 8 + 4, 110), Vector2.UP, 0.0, 0.0, tuning)
	room.add_child(flyer)
	var half_size: float = flyer.size / 2.0
	var within_tile: bool = true
	for point: Vector2 in flyer.outline_points:
		within_tile = within_tile and absf(point.x) <= half_size + 0.01 and absf(point.y) <= half_size + 0.01
	_check(flyer.outline_points.size() >= 8 and within_tile, "a rock has a lumpy outline inside its tile (%d points)" % flyer.outline_points.size())
	await _wait_physics_frames(1)
	var pebbles_before_flight: int = field.pebble_positions.size()
	flyer.throw(Vector2.RIGHT, 120.0, 0.5, false)
	await _wait_game(0.35)
	_check(is_instance_valid(flyer) and flyer.phase == Boulder.Phase.FLYING and flyer.visual_angle > 0.5,
		"a thrown rock tumbles the way it flies (%.2f rad)" % (flyer.visual_angle if is_instance_valid(flyer) else 0.0))
	_check(field.pebble_positions.size() > pebbles_before_flight,
		"a flying rock sheds pebbles (%d -> %d)" % [pebbles_before_flight, field.pebble_positions.size()])
	room.reset_objects()
	await _wait_physics_frames(2)

	# A rock that comes to rest turns back square on the grid.
	player.facing_direction = 1.0
	var rock: Boulder = await _rip_boulder(player)
	await _press_action("jump")  # let it go
	await _wait_until(func() -> bool: return is_instance_valid(rock) and rock.is_loose(), 1.5)
	await _wait_game(0.5)
	if is_instance_valid(rock) and rock.is_loose():
		var quarter_turn: float = PI / 2.0
		var off_square: float = absf(rock.visual_angle - roundf(rock.visual_angle / quarter_turn) * quarter_turn)
		_check(off_square < 0.01, "a loose rock lies square (%.3f rad off)" % off_square)
	else:
		_check(false, "test setup: a let-go rock lies loose")
	room.reset_objects()
	await _wait_physics_frames(2)

	# A pillar: banded rows, a crack at the tip, pebbles crumbled while rising.
	Input.action_press("earth_column")
	await _wait_physics_frames(2)
	Input.action_release("earth_column")
	await _wait_game(tuning.column_rise_time + 0.1)
	var columns: Array[EarthColumn] = _find_columns(room)
	_check(columns.size() == 1, "test setup: a quick tap raised one pillar")
	if columns.size() == 1:
		var column: EarthColumn = columns[0]
		var distinct_colors: Array[Color] = []
		for row_color: Color in column.row_colors:
			if not distinct_colors.has(row_color):
				distinct_colors.append(row_color)
		_check(column.row_colors.size() > ceili(tuning.column_length) and distinct_colors.size() >= 2,
			"a pillar has layered bands (%d colors)" % distinct_colors.size())
		_check(column.crack_pixel_xs.size() >= EarthColumn.CRACK_MIN_ROWS, "a pillar's tip is cracked")
		_check(column.pebbles_crumbled == tuning.column_rise_pebble_count,
			"a rising pillar crumbles pebbles (%d)" % column.pebbles_crumbled)
	await _wait_real(1.0)  # land from the super jump
	room.reset_objects()
	await _wait_physics_frames(2)
	finished_sections.append("E4e")


## Stage E5: the Earth Snake. Room E: an earth patch at columns 8-13 (rows 20-21, 12
## tiles), a spike pit at columns 14-21, grass beyond, a sentry on the right.
func _check_e5_snake(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthE") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	var sentry: Sentry = room.get_node("Sentry") as Sentry
	sentry.can_fire = false  # no orbs until the wall check at the end
	world.jump_to_room(room)
	var near_wall_cell: Vector2i = Vector2i(13, 20)
	player.respawn_at(room.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)

	# The bridge: a long A bend, shadow down the pit's near wall, release, no steering.
	var snake: EarthSnake = await _bend_snake_at(player, near_wall_cell, Vector2i.RIGHT)
	_check(snake != null and player.state_machine.current_state.name == &"SnakeSteer",
		"releasing a long A bend brings a snake out and the player steers it (state %s)" % player.state_machine.current_state.name)
	if snake == null:
		return
	_check(snake.segment_cells[0] == near_wall_cell + Vector2i.RIGHT and not earth.is_fresh(near_wall_cell),
		"the snake comes out of the wall sideways, using the wall's own tile first")
	await _wait_until(func() -> bool: return not snake.is_moving(), 2.0)
	_check(snake.harden_reason == "solid" and snake.segment_cells.size() == 8,
		"unsteered it runs straight across and hardens against the far side (%s, %d tiles)" % [snake.harden_reason, snake.segment_cells.size()])
	await _wait_physics_frames(2)
	_check(player.state_machine.current_state.name != &"SnakeSteer", "the player is free once it hardens")
	# The patch darkened outward from the emergence point, one tile per snake tile.
	var spent: Array = earth.used_fade_progress.keys()  # in the order they were used
	var outward: bool = spent.size() == snake.segment_cells.size()
	for spent_index: int in range(1, spent.size()):
		var previous_distance: int = absi(spent[spent_index - 1].x - near_wall_cell.x) + absi(spent[spent_index - 1].y - near_wall_cell.y)
		var distance: int = absi(spent[spent_index].x - near_wall_cell.x) + absi(spent[spent_index].y - near_wall_cell.y)
		outward = outward and distance >= previous_distance
	_check(outward and spent[0] == near_wall_cell, "one patch tile per snake tile, darkening outward (%d used)" % spent.size())
	# It's a bridge: stand on it. And a bend can start from it.
	player.respawn_at(room.global_position + Vector2(17 * 8 + 4, 159))
	await _wait_game(0.3)
	_check(player.is_on_floor() and absf(player.global_position.y - (room.global_position.y + 160)) < 0.5 and not player.is_dead(),
		"the hardened snake is a bridge you stand on (feet y %.1f)" % player.global_position.y)
	_check(player.earth_bend.find_start_surface() != null and player.earth_bend.describe_contact().begins_with("snake floor"),
		"standing on a snake is a bend start (%s)" % player.earth_bend.describe_contact())
	room.reset_objects()
	await _wait_physics_frames(2)
	_check(_find_snakes(room).is_empty() and earth.is_fresh(near_wall_cell), "room reset removes the snake and puts the earth back")

	# A again hardens it at once.
	player.respawn_at(room.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	snake = await _bend_snake_at(player, near_wall_cell, Vector2i.RIGHT)
	await _press_action("earth_column")
	_check(snake != null and snake.harden_reason == "key" and snake.segment_cells.size() < 8,
		"pressing A again hardens it early (%d tiles)" % (snake.segment_cells.size() if snake != null else 0))
	await _wait_physics_frames(2)
	room.reset_objects()
	await _wait_physics_frames(2)

	# Jump hardens it too, and doesn't jump.
	snake = await _bend_snake_at(player, near_wall_cell, Vector2i.RIGHT)
	await _press_action("jump")
	await _wait_physics_frames(2)
	_check(snake != null and snake.harden_reason == "key" and player.is_on_floor(),
		"Jump hardens it and the press is spent (no jump)")
	room.reset_objects()
	await _wait_physics_frames(2)

	# The head pushes a crate: a snake out of the floor going up lifts the crate on it.
	var crate: Crate = CRATE_SCENE.instantiate() as Crate
	crate.position = Vector2(80, 160)  # in the room, on columns 9-10
	room.add_child(crate)
	player.respawn_at(room.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = -1.0
	await _wait_physics_frames(5)
	var crate_start_y: float = crate.global_position.y
	snake = await _bend_snake_at(player, Vector2i(9, 20), Vector2i.UP)
	if snake != null:
		await _wait_until(func() -> bool: return not snake.is_moving(), 2.0)
	_check(snake != null and crate.global_position.y < crate_start_y - 16.0,
		"the head pushes a crate along (crate y %.0f -> %.0f)" % [crate_start_y, crate.global_position.y])
	room.reset_objects()
	crate.queue_free()
	await _wait_physics_frames(2)

	# Steered back into the player (rooted at column 11): up one, then left along row
	# 19 into the player's tile. It shoves them out and throws them left, and hardens.
	player.respawn_at(room.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	snake = await _bend_snake_at(player, near_wall_cell, Vector2i.RIGHT)
	if snake != null:
		await _steer_snake(snake, {1: Vector2i.UP, 2: Vector2i.LEFT})
	await get_tree().physics_frame
	_check(snake != null and snake.harden_reason == "player" and not player.is_dead()
		and player.state_machine.current_state.name == &"Launched" and player.velocity.x < 0.0,
		"the head running into the player throws them off it and hardens (%s, state %s, velocity %s)" % [
			snake.harden_reason if snake != null else "-", player.state_machine.current_state.name, player.velocity])
	await _wait_real(1.0)
	room.reset_objects()
	await _wait_physics_frames(2)

	# Coming DOWN onto the player standing on the floor: pinned against the ground, the
	# player is crushed. Up 3, left along row 17 over the player, then down.
	player.respawn_at(room.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	snake = await _bend_snake_at(player, near_wall_cell, Vector2i.RIGHT)
	if snake != null:
		await _steer_snake(snake, {1: Vector2i.UP, 4: Vector2i.LEFT, 7: Vector2i.DOWN})
	_check(snake != null and snake.harden_reason == "player" and player.is_dead(),
		"the head pinning the player against the ground crushes them (%s)" % (snake.harden_reason if snake != null else "-"))
	# Let the room manager respawn us (and reset the room) before going on.
	await _wait_real(player.tuning.death_respawn_delay + 0.3)
	_check(not player.is_dead() and _find_snakes(room).is_empty(), "test setup: respawned after the crush")

	# Steering + the budget, and a wall against the sentry: with Up held the snake
	# turns up at its first step and climbs until the 12-tile patch runs out. An orb
	# already flying at us pops against it.
	player.respawn_at(room.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = 1.0
	sentry.can_fire = true
	await _wait_physics_frames(5)
	var orb: SentryOrb = null
	var waited_frames: int = 0
	while orb == null and waited_frames < 200:
		await get_tree().physics_frame
		waited_frames += 1
		for child: Node in room.get_children():
			if child is SentryOrb and not child.is_queued_for_deletion():
				orb = child as SentryOrb
	_check(orb != null, "test setup: the sentry fires at the player")
	Input.action_press("move_up")
	snake = await _bend_snake_at(player, near_wall_cell, Vector2i.RIGHT)
	if snake != null:
		await _wait_until(func() -> bool: return not snake.is_moving(), 2.0)
	Input.action_release("move_up")
	var climbed_straight: bool = snake != null and snake.segment_cells.size() == player.earth_tuning.snake_max_tiles
	if climbed_straight:
		for cell: Vector2i in snake.segment_cells:
			climbed_straight = climbed_straight and cell.x == near_wall_cell.x + 1
	_check(climbed_straight and snake.harden_reason == "budget",
		"Up turns the head, and it stops when the patch runs out (%s, %d tiles)" % [
			snake.harden_reason if snake != null else "-", snake.segment_cells.size() if snake != null else 0])
	if orb != null:
		# Watched by its id: a lambda holding the orb itself complains once it's freed.
		var orb_id: int = orb.get_instance_id()
		await _wait_until(func() -> bool: return not is_instance_id_valid(orb_id) or player.is_dead(), 6.0)
		_check(not player.is_dead() and not is_instance_id_valid(orb_id), "a snake wall blocks the sentry's orb (it pops)")
	room.reset_objects()
	await _wait_physics_frames(2)
	finished_sections.append("E5")


## One key for column and snake (on everywhere by default since E5; Room F also turns
## it on for itself): a quick tap of A raises a column under the feet, a long A bend
## whose shadow crawled off brings out a snake, and A hardens it. With the global
## switch off, other rooms go back to "a long A bend = a column at the shadow".
func _check_one_key_column_snake(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthF") as Room
	var tuning: EarthTuning = player.earth_tuning
	world.jump_to_room(room)
	player.respawn_at(room.global_position + Vector2(6 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	_check(tuning.one_key_column_snake and player.is_one_key_column_snake(), "one key is on by default")
	# The rest runs with the global switch OFF, so room F's own flag is what's tested.
	tuning.one_key_column_snake = false
	_check(player.is_one_key_column_snake(), "room F turns one key on for itself")

	# Quick tap A: a column under the feet, the super jump.
	Input.action_press("earth_column")
	await _wait_physics_frames(2)
	Input.action_release("earth_column")
	await _wait_physics_frames(3)
	_check(_find_columns(room).size() == 1 and _find_snakes(room).is_empty()
		and player.state_machine.current_state.name == &"Launched",
		"one key: a quick tap of A is a column under you (state %s)" % player.state_machine.current_state.name)
	await _wait_real(1.0)
	room.reset_objects()
	await _wait_physics_frames(2)

	# Long A on the ledge: the shadow crawls down its side, the release brings a snake.
	player.respawn_at(room.global_position + Vector2(14 * 8 + 4, 112))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	var snake: EarthSnake = await _bend_at(player, &"earth_column", Vector2i(16, 14), Vector2i.RIGHT)
	_check(snake != null and _find_columns(room).is_empty() and player.state_machine.current_state.name == &"SnakeSteer",
		"one key: releasing A once the shadow crawled off brings out a snake (state %s)" % player.state_machine.current_state.name)
	if snake != null:
		await _wait_until(func() -> bool: return not snake.is_moving(), 2.0)
		_check(snake.harden_reason == "solid" and snake.segment_cells.size() == 9,
			"one key: it bridges the pit to the far ledge (%s, %d tiles)" % [snake.harden_reason, snake.segment_cells.size()])
	room.reset_objects()
	await _wait_physics_frames(2)
	# A again hardens it.
	snake = await _bend_at(player, &"earth_column", Vector2i(16, 14), Vector2i.RIGHT)
	await _press_action("earth_column")
	_check(snake != null and snake.harden_reason == "key", "one key: A again hardens the snake")
	await _wait_physics_frames(2)
	room.reset_objects()
	await _wait_physics_frames(2)

	# Room E (experiment off): the same long A bend down the pit wall is a column.
	var room_e: Room = world.get_node("RoomEarthE") as Room
	(room_e.get_node("Sentry") as Sentry).can_fire = false
	world.jump_to_room(room_e)
	player.respawn_at(room_e.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	_check(not player.is_one_key_column_snake(), "with the switch off, other rooms have separate keys")
	await _bend_at(player, &"earth_column", Vector2i(13, 20), Vector2i.RIGHT)
	await _wait_game(0.2)
	_check(_find_columns(room_e).size() == 1 and _find_snakes(room_e).is_empty(),
		"with the switch off, a long A bend is a column at the shadow")
	room_e.reset_objects()
	await _wait_physics_frames(2)
	tuning.one_key_column_snake = true
	(room_e.get_node("Sentry") as Sentry).can_fire = true
	finished_sections.append("one-key")


## A long A bend (one key): holds A until the shadow is on `cell`'s `normal` face,
## releases. Returns the snake that came out, or null.
func _bend_snake_at(player: Player, cell: Vector2i, normal: Vector2i) -> EarthSnake:
	return await _bend_at(player, &"earth_column", cell, normal)


## Steers `snake` until it hardens: `turns` maps a tile count to a direction, queued as
## soon as the snake has that many tiles (so it turns on the next one).
func _steer_snake(snake: EarthSnake, turns: Dictionary) -> void:
	while is_instance_valid(snake) and snake.is_moving():
		var tile_count: int = snake.segment_cells.size()
		if turns.has(tile_count):
			snake.queue_turn(turns[tile_count])
			turns.erase(tile_count)
		await get_tree().process_frame


## Holds `action`, waits (real time) until the shadow is on `cell`'s `normal` face,
## releases it. Returns the snake being steered afterwards, or null.
func _bend_at(player: Player, action: StringName, cell: Vector2i, normal: Vector2i) -> EarthSnake:
	Input.action_press(action)
	await _wait_physics_frames(2)
	var waited: float = 0.0
	while waited < 2.0 and player.earth_bend.is_bending:
		var face: EarthFace = player.earth_bend.get_shadow_face()
		if face.cell == cell and face.normal == normal:
			break
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	Input.action_release(action)
	await _wait_physics_frames(2)
	return player.earth_snake.active_snake


func _find_snakes(room: Room) -> Array[EarthSnake]:
	var snakes: Array[EarthSnake] = []
	for child: Node in room.get_children():
		var snake: EarthSnake = child as EarthSnake
		if snake != null and not snake.is_queued_for_deletion():
			snakes.append(snake)
	return snakes


func _count_moved(before: PackedVector2Array, after: PackedVector2Array) -> int:
	var moved: int = 0
	for pebble_index: int in mini(before.size(), after.size()):
		if before[pebble_index].distance_to(after[pebble_index]) > 0.5:
			moved += 1
	return moved


func _average_x(points: PackedVector2Array) -> float:
	if points.is_empty():
		return 0.0
	var total: float = 0.0
	for point: Vector2 in points:
		total += point.x
	return total / points.size()


## Average x of the points at `indices`.
func _average_x_of(points: PackedVector2Array, indices: Array[int]) -> float:
	if indices.is_empty():
		return 0.0
	var total: float = 0.0
	for point_index: int in indices:
		total += points[point_index].x
	return total / indices.size()


func _min_x(points: PackedVector2Array) -> float:
	var smallest: float = INF
	for point: Vector2 in points:
		smallest = minf(smallest, point.x)
	return smallest


func _tear_big_rock(player: Player) -> Boulder:
	Input.parse_input_event(_make_action_event(&"earth_boulder", true))
	await get_tree().process_frame
	await _wait_game(player.earth_tuning.boulder_tear_time + 0.05)
	Input.parse_input_event(_make_action_event(&"earth_boulder", false))
	await get_tree().process_frame
	await get_tree().physics_frame
	return player.boulder.held_boulder


## Presses S for one frame and returns the rock it tore out, or null.
func _rip_boulder(player: Player) -> Boulder:
	await _press_action("earth_boulder")
	return player.boulder.held_boulder


## Presses an action for one physics frame, the way a real key does: as an input
## EVENT (Input.parse_input_event), which is what the game receives from a keyboard.
## Held for 2 physics ticks (still faster than any human). Events are handed to the
## game at the start of a FRAME, and after a slow frame Godot runs several physics
## ticks in a row, so a press and its release sent between those ticks could both
## arrive at once and is_action_just_pressed would never see the press. Waiting for a
## new frame (process_frame) after each event avoids that.
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


## Waits physics frames until `condition` returns true, at most `seconds` of GAME
## time. In slow motion physics still ticks at its usual rate but each tick's delta is
## scaled down, so game time is added up tick by tick rather than counted in frames.
func _wait_until(condition: Callable, seconds: float) -> void:
	var waited: float = 0.0
	while waited < seconds:
		if condition.call():
			return
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()


func _find_boulders(room: Room) -> Array[Boulder]:
	var boulders: Array[Boulder] = []
	for child: Node in room.get_children():
		var boulder: Boulder = child as Boulder
		if boulder != null and not boulder.is_queued_for_deletion():
			boulders.append(boulder)
	return boulders


## Grass blades (room A's grass patch, columns 12-13): they lean the way the player
## runs, whip over in a gust, and lean with the wind.
func _check_grass_blades(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthA") as Room
	var grass: GrassLayer = room.get_node("Grass") as GrassLayer
	world.jump_to_room(room)
	await _wait_physics_frames(5)
	var patch_blades: Array[int] = []
	for blade_index: int in grass.blade_bases.size():
		var base: Vector2 = grass.blade_bases[blade_index]
		if base.y == 20 * 8 and base.x > 12 * 8 and base.x < 14 * 8:
			patch_blades.append(blade_index)
	_check(patch_blades.size() == 2 * grass.blades_per_tile, "blades grow on the grass patch (%d)" % patch_blades.size())

	# Run right across the patch.
	player.respawn_at(room.global_position + Vector2(80, 160))
	await _wait_physics_frames(3)
	Input.action_press("move_right")
	var most_lean: float = 0.0
	for frame_index: int in 30:
		await get_tree().physics_frame
		for blade_index: int in patch_blades:
			most_lean = maxf(most_lean, grass.blade_bends[blade_index])
	Input.action_release("move_right")
	_check(most_lean > 1.5, "running right leans the blades right (%.1f px)" % most_lean)
	await _wait_physics_frames(90)

	# A gust blowing left from just right of the patch.
	grass.receive_gust_from(Vector2.LEFT, player.tuning.gust_push_strength, room.global_position + Vector2(120, 155))
	var gust_lean: float = 0.0
	for frame_index: int in 10:
		await get_tree().physics_frame
		for blade_index: int in patch_blades:
			gust_lean = minf(gust_lean, grass.blade_bends[blade_index])
	_check(gust_lean < -1.5, "a gust blowing left whips the blades left (%.1f px)" % gust_lean)

	# A wind zone blowing right over the patch.
	var wind: WindZone = WIND_ZONE_SCENE.instantiate() as WindZone
	wind.zone_size = Vector2(24, 24)
	wind.wind_direction = Vector2.RIGHT
	wind.wind_strength = 60.0
	room.add_child(wind)
	wind.position = Vector2(12 * 8 - 4, 20 * 8 - 20)
	grass.winds_found = false  # look for wind zones again
	await _wait_physics_frames(60)
	var average_lean: float = 0.0
	for blade_index: int in patch_blades:
		average_lean += grass.blade_bends[blade_index] / patch_blades.size()
	_check(average_lean > 1.0, "wind blowing right leans the blades right (%.1f px)" % average_lean)
	wind.queue_free()
	grass.winds_found = false
	await get_tree().physics_frame
	finished_sections.append("grass")


## Mixed world, room B (enemies): a column blocks a sentry orb.
func _check_mixed_enemies() -> void:
	var world: RoomManager = MIXED_WORLD_SCENE.instantiate() as RoomManager
	add_child(world)
	await _wait_physics_frames(10)
	var player: Player = world.player
	var room: Room = world.get_node("RoomMixedB") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	world.jump_to_room(room)
	await _wait_physics_frames(2)
	_check(player.is_element_allowed(Player.ELEMENT_AIR) and player.is_element_allowed(Player.ELEMENT_EARTH),
		"mixed enemy room allows Air and Earth")
	_check(earth.is_shadow_blocking(Vector2i(18, 22)), "mixed enemy room: gray under the pit's spikes")
	# Out of the way: the right wisp would walk into the test spot.
	(room.get_node("WispRight") as Wisp).defeat()
	(room.get_node("WispLeft") as Wisp).defeat()
	player.respawn_at(room.global_position + Vector2(196, 160))
	# Wait for the sentry's first shot (first_shot_delay 1 s + a little).
	var orb: SentryOrb = null
	var waited_frames: int = 0
	while orb == null and waited_frames < 150:
		await get_tree().physics_frame
		waited_frames += 1
		for child: Node in room.get_children():
			if child is SentryOrb and not child.is_queued_for_deletion():
				orb = child as SentryOrb
	_check(orb != null, "test setup: the sentry fires at the player")
	if orb == null:
		world.queue_free()
		return
	# Raise a column between the orb and the player.
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(28, 20), Vector2i.UP))
	await _wait_real(2.0)
	_check(not player.is_dead() and not is_instance_valid(orb), "a column blocks the sentry's orb (it pops)")
	# Stage E6: a column out of the sentry block's side throws a wisp along the floor
	# into the spike pit (made in code: with one key, A only raises columns under you).
	room.reset_objects()
	await _wait_physics_frames(2)
	(room.get_node("Sentry") as Sentry).can_fire = false
	(room.get_node("WispLeft") as Wisp).defeat()
	player.respawn_at(room.global_position + Vector2(24, 160))
	var thrown_wisp: Wisp = room.get_node("WispRight") as Wisp
	thrown_wisp.global_position = room.global_position + Vector2(32 * 8 - 6, 160)
	await _wait_physics_frames(1)
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(32, 19), Vector2i.LEFT))
	await _wait_until(func() -> bool: return thrown_wisp.state == Wisp.State.DEFEATED, 2.0)
	_check(thrown_wisp.state == Wisp.State.DEFEATED and thrown_wisp.global_position.x < room.global_position.x + 22 * 8,
		"a column throws a wisp into the spike pit (x %.1f)" % (thrown_wisp.global_position.x - room.global_position.x))
	world.queue_free()
	await get_tree().process_frame
	finished_sections.append("mixed")


## The highest the player's feet get (smallest y) over `seconds` of game time.
func _track_highest_feet(player: Player, seconds: float) -> float:
	var highest: float = player.global_position.y
	var frames: int = int(seconds * Engine.physics_ticks_per_second)
	for frame_index: int in frames:
		await get_tree().physics_frame
		highest = minf(highest, player.global_position.y)
	return highest


func _find_columns(room: Room) -> Array[EarthColumn]:
	var columns: Array[EarthColumn] = []
	for child: Node in room.get_children():
		var column: EarthColumn = child as EarthColumn
		if column != null and not column.is_queued_for_deletion():
			columns.append(column)
	return columns


func _wait_physics_frames(count: int) -> void:
	for frame_index: int in count:
		await get_tree().physics_frame


## Stage E6 (RoomEarthG): cracked walls, thrown rocks vs enemies, the snake head
## ramming a wisp into spikes, and slow motion slowing enemies and orbs.
## (The column throwing a wisp into spikes is in _check_mixed_enemies: with one key a
## column only rises under the player, so it's tested with a column made in code.)
func _check_e6_walls_enemies(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthG") as Room
	var tuning: EarthTuning = player.earth_tuning
	var wall: CrackedWall = room.get_node("CrackedWall") as CrackedWall
	var wisp: Wisp = room.get_node("Wisp") as Wisp
	var sentry: Sentry = room.get_node("Sentry") as Sentry
	world.jump_to_room(room)
	sentry.can_fire = false  # no orbs except in the slow-motion check
	await _wait_physics_frames(5)
	_check(wall.collision_layer == 1 and not wall.is_broken, "a cracked wall is solid ground (layer 1) until broken")

	# A SMALL rock is too light: it shatters on the wall, which stays whole.
	var wall_center: Vector2 = wall.get_global_rect().get_center()
	var rock: Boulder = _throw_test_rock(room, Vector2(wall.global_position.x - 20.0, wall_center.y), Vector2.RIGHT, tuning)
	await _wait_game(0.3)
	_check(not wall.is_broken and wall.collision_layer == 1, "a small rock doesn't break a cracked wall")
	_check(not is_instance_valid(rock) or rock.phase == Boulder.Phase.SHATTERED, "the small rock shatters on it")

	# A real throw: hold S for a BIG rock, throw it right at the perfect moment.
	var field: PebbleField = room.get_node("PebbleField") as PebbleField
	player.respawn_at(room.global_position + Vector2(6 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	rock = await _tear_big_rock(player)
	_check(rock != null and rock.is_big(), "test setup: a big rock is torn out in front of the cracked wall")
	if rock == null:
		return
	await _wait_until(func() -> bool: return rock.is_in_perfect_window(), 1.0)
	field.reset()  # count only the wall's pebbles below
	await _press_action("earth_boulder")
	# (The condition looks at the wall, not the rock: a lambda must not hold a freed node.)
	await _wait_until(func() -> bool: return wall.is_broken, 2.0)
	_check(wall.is_broken and wall.collision_layer == 0 and not wall.visible, "a thrown big rock breaks the cracked wall open")
	_check(not is_instance_valid(rock) or rock.phase == Boulder.Phase.SHATTERED, "the big rock shatters on the wall")
	var wall_pebbles: int = 0
	for pebble_color: Color in field.pebble_colors:
		if CrackedWall.PEBBLE_COLORS.has(pebble_color):
			wall_pebbles += 1
	var wall_tiles: int = wall.wall_size_tiles.x * wall.wall_size_tiles.y
	_check(wall_pebbles == wall_tiles * tuning.cracked_wall_pebbles_per_tile,
		"the wall crumbles into gray pebbles, %d per tile (%d for %d tiles)" % [tuning.cracked_wall_pebbles_per_tile, wall_pebbles, wall_tiles])
	await _wait_physics_frames(1)
	room.reset_objects()
	await _wait_physics_frames(2)
	_check(not wall.is_broken and wall.collision_layer == 1 and wall.visible, "room reset puts the cracked wall back")

	# A SLOPPY small rock only shoves the wisp: stunned and knocked back, still alive.
	player.respawn_at(room.global_position + Vector2(24, 160))
	wisp.global_position = room.global_position + Vector2(20 * 8, 160)
	_throw_test_rock(room, wisp.global_position + Vector2(-24.0, -4.0), Vector2.RIGHT, tuning, false)
	await _wait_until(func() -> bool: return wisp.state == Wisp.State.STUNNED, 0.5)
	await _wait_game(tuning.boulder_enemy_defeat_delay + 0.1)
	_check(wisp.state == Wisp.State.STUNNED and wisp.rock_defeat_remaining < 0.0,
		"a sloppy small rock only shoves the wisp (stunned, alive)")
	room.reset_objects()
	await _wait_physics_frames(2)
	# A BIG rock always kills, even thrown sloppily.
	wisp.global_position = room.global_position + Vector2(20 * 8, 160)
	_throw_test_rock(room, wisp.global_position + Vector2(-30.0, -9.0), Vector2.RIGHT, tuning, false, true)
	await _wait_game(tuning.boulder_enemy_defeat_delay + 0.3)
	_check(wisp.state == Wisp.State.DEFEATED, "a big rock defeats the wisp even when thrown sloppily")
	room.reset_objects()
	await _wait_physics_frames(2)
	# A PERFECT small rock vs the wisp: knocked back along the throw, harmless, then defeated.
	wisp.global_position = room.global_position + Vector2(20 * 8, 160)
	var wisp_start_x: float = wisp.global_position.x
	rock = _throw_test_rock(room, wisp.global_position + Vector2(-24.0, -4.0), Vector2.RIGHT, tuning)
	await _wait_until(func() -> bool: return wisp.rock_defeat_remaining >= 0.0 or wisp.state == Wisp.State.DEFEATED, 0.5)
	_check(wisp.rock_defeat_remaining >= 0.0 and wisp.state == Wisp.State.STUNNED and wisp.velocity.x > 0.0,
		"a thrown rock knocks the wisp back along the throw (stunned, velocity %s)" % wisp.velocity)
	_check(not is_instance_valid(rock) or rock.phase == Boulder.Phase.SHATTERED, "the rock shatters on the wisp")
	await _wait_game(tuning.boulder_enemy_defeat_delay + 0.05)
	_check(wisp.state == Wisp.State.DEFEATED and wisp.global_position.x > wisp_start_x,
		"...and the wisp is defeated a moment later (flew %.1f px)" % (wisp.global_position.x - wisp_start_x))

	# A sloppy small rock clonks off the sentry; a perfect one destroys it at once.
	_throw_test_rock(room, sentry.get_eye_position() + Vector2(-30.0, 0.0), Vector2.RIGHT, tuning, false)
	await _wait_game(0.3)
	_check(not sentry.is_destroyed, "a sloppy small rock doesn't destroy the sentry")
	rock = _throw_test_rock(room, sentry.get_eye_position() + Vector2(-30.0, 0.0), Vector2.RIGHT, tuning)
	await _wait_until(func() -> bool: return sentry.is_destroyed, 0.5)
	_check(sentry.is_destroyed, "a perfectly thrown rock destroys the sentry")
	room.reset_objects()
	await _wait_physics_frames(2)
	_check(wisp.state == Wisp.State.PATROL and not sentry.is_destroyed, "room reset brings the wisp and the sentry back")
	# A rock that's only hopping (not thrown) passes through a wisp: no accidental kills.
	var hopping: Boulder = Boulder.new()
	hopping.setup(wisp.global_position + Vector2(0.0, -4.0), Vector2.UP, 0.0, wisp.global_position.y, tuning)
	room.add_child(hopping)
	await _wait_game(0.2)
	_check(wisp.state == Wisp.State.PATROL, "a hopping (unthrown) rock doesn't hit a wisp")
	room.reset_objects()
	await _wait_physics_frames(2)

	# Rocks block orbs: a hopping rock is a shield, a thrown one knocks orbs out of the air.
	var shield_rock: Boulder = Boulder.new()
	var shield_center: Vector2 = room.global_position + Vector2(160, 100)
	shield_rock.setup(shield_center, Vector2.UP, 0.0, shield_center.y, tuning)
	room.add_child(shield_rock)
	var shield_orb: SentryOrb = _launch_test_orb(room, shield_center + Vector2(12.0, -8.0), Vector2(-60.0, 0.0))
	await _wait_game(0.4)
	_check(not is_instance_valid(shield_orb), "an orb flying into a hopping rock pops")
	var air_orb: SentryOrb = _launch_test_orb(room, room.global_position + Vector2(200, 60), Vector2(-60.0, 0.0))
	_throw_test_rock(room, room.global_position + Vector2(120, 60), Vector2.RIGHT, tuning)
	await _wait_game(0.4)
	_check(not is_instance_valid(air_orb), "a thrown rock pops an orb in mid-air")
	room.reset_objects()
	await _wait_physics_frames(2)

	# Slow motion during a bend slows enemies and orbs (they move in game time).
	sentry.can_fire = true
	# Within the sentry's sight_range (220 px), still on the earth floor.
	player.respawn_at(room.global_position + Vector2(11 * 8 + 4, 160))
	wall.break_open(Vector2.RIGHT, tuning)  # so the sentry sees the player and fires
	var orb: SentryOrb = null
	var waited_frames: int = 0
	while orb == null and waited_frames < 150:
		await get_tree().physics_frame
		waited_frames += 1
		for child: Node in room.get_children():
			if child is SentryOrb and not child.is_queued_for_deletion():
				orb = child as SentryOrb
	sentry.can_fire = false
	_check(orb != null, "test setup: the sentry fires once the wall is open")
	wisp.global_position = room.global_position + Vector2(19 * 8, 160)
	wisp.patrol_direction = 1.0
	await _wait_physics_frames(3)
	Input.action_press(&"earth_column")
	await _wait_physics_frames(3)
	var bend_scale: float = Engine.time_scale
	var wisp_before: float = wisp.global_position.x
	var orb_before: Vector2 = orb.global_position if is_instance_valid(orb) else Vector2.ZERO
	var measured_frames: int = 20
	await _wait_physics_frames(measured_frames)
	var frame_time: float = 1.0 / Engine.physics_ticks_per_second
	var expected_wisp: float = wisp.patrol_speed * frame_time * measured_frames * tuning.bend_time_scale
	var wisp_moved: float = absf(wisp.global_position.x - wisp_before)
	_check(is_equal_approx(bend_scale, tuning.bend_time_scale) and absf(wisp_moved - expected_wisp) < 0.5,
		"a bend slows the wisp to %.1fx (moved %.2f px in %d frames, expected %.2f)" % [bend_scale, wisp_moved, measured_frames, expected_wisp])
	if is_instance_valid(orb):
		var expected_orb: float = sentry.orb_speed * frame_time * measured_frames * tuning.bend_time_scale
		var orb_moved: float = orb.global_position.distance_to(orb_before)
		_check(absf(orb_moved - expected_orb) < 0.5,
			"a bend slows the sentry's orb too (moved %.2f px, expected %.2f)" % [orb_moved, expected_orb])
	else:
		_check(false, "the orb was still flying during the bend")
	Input.action_release(&"earth_column")
	await _wait_physics_frames(3)
	room.reset_objects()
	await _wait_real(0.3)

	# The snake head rams the wisp off the floor's edge into the spike pit.
	player.respawn_at(room.global_position + Vector2(9 * 8 + 4, 160))
	player.facing_direction = 1.0
	wall.break_open(Vector2.RIGHT, tuning)
	wisp.global_position = room.global_position + Vector2(19 * 8, 160)
	await _wait_physics_frames(5)
	var snake: EarthSnake = await _bend_snake_at(player, Vector2i(13, 20), Vector2i.UP)
	_check(snake != null, "test setup: a snake comes out of the floor where the wall stood")
	if snake == null:
		return
	snake.queue_turn(Vector2i.RIGHT)  # out of the floor, then right along it
	var was_knocked: bool = false
	var waited: float = 0.0
	while waited < 4.0 and wisp.state != Wisp.State.DEFEATED:
		was_knocked = was_knocked or wisp.state == Wisp.State.STUNNED
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_check(was_knocked, "the snake head knocks the wisp back (stunned)")
	_check(wisp.state == Wisp.State.DEFEATED and wisp.global_position.x > room.global_position.x + 25 * 8,
		"the snake head rams the wisp into the spike pit (x %.1f)" % (wisp.global_position.x - room.global_position.x))
	_check(not player.is_dead(), "the player survives ramming the wisp")
	await _wait_real(0.5)
	room.reset_objects()
	await _wait_physics_frames(2)
	finished_sections.append("E6")


## EXPERIMENT (EarthTuning.boulder_hover_aim): the rock hovers beside the player at
## chest height, the arrows aim it (the aim sticks), the contour closes at the perfect
## moment, and S throws it the aimed way. Not thrown, it drops and lies loose.
func _check_hover_aim(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthC") as Room
	var tuning: EarthTuning = player.earth_tuning
	world.jump_to_room(room)
	player.facing_direction = 1.0
	await _wait_physics_frames(10)
	tuning.boulder_hover_aim = true
	var rock: Boulder = await _rip_boulder(player)
	_check(rock != null and rock.is_hover_mode, "hover aim: S tears out a hovering rock")
	if rock == null:
		tuning.boulder_hover_aim = false
		return
	await _wait_game(tuning.boulder_tear_time + tuning.boulder_hover_rise_time + 0.05)
	var offset: Vector2 = rock.global_position - player.get_center()
	_check(rock.is_hovering and offset.x > 0.0 and absf(offset.y) < 1.0,
		"hover aim: it hovers beside the player at chest height (offset %s)" % offset)
	# Up+Right aims diagonally; letting go keeps the aim (like the gust).
	Input.action_press(&"move_right")
	Input.action_press(&"move_up")
	await _wait_physics_frames(3)
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	await _wait_physics_frames(6)
	_check(player.boulder.hover_aim.x > 0.5 and player.boulder.hover_aim.y < -0.5,
		"hover aim: the arrows aim it, and the aim sticks after letting go (%s)" % player.boulder.hover_aim)
	_check(not rock.is_in_perfect_window() and rock.get_hover_ring_progress() < 1.0,
		"hover aim: the contour is still closing in (%.2f)" % rock.get_hover_ring_progress())
	await _wait_until(func() -> bool: return rock.is_in_perfect_window(), 1.0)
	_check(rock.is_in_perfect_window() and rock.get_hover_ring_progress() > 0.6,
		"hover aim: the perfect moment is when the contour fits (%.2f)" % rock.get_hover_ring_progress())
	await _press_action("earth_boulder")
	_check(rock.phase == Boulder.Phase.FLYING and rock.velocity.x > 0.0 and rock.velocity.y < 0.0 \
		and absf(rock.velocity.length() - tuning.boulder_perfect_throw_speed) < 1.0,
		"hover aim: S throws it the aimed way at perfect speed (velocity %s)" % rock.velocity)
	room.reset_objects()
	await _wait_physics_frames(2)
	# Never thrown: after its hold time it drops and lies loose.
	rock = await _rip_boulder(player)
	await _wait_until(func() -> bool: return is_instance_valid(rock) and rock.is_loose(), tuning.boulder_hover_hold_time + 1.0)
	_check(is_instance_valid(rock) and rock.is_loose(), "hover aim: an unthrown rock drops and lies loose")
	room.reset_objects()
	await _wait_physics_frames(2)
	# The hover has its own, slower slow motion.
	rock = await _rip_boulder(player)
	_check(is_equal_approx(Engine.time_scale, tuning.boulder_hover_time_scale),
		"hover aim: slow motion while it hovers (%.2f)" % Engine.time_scale)
	room.reset_objects()
	await _wait_physics_frames(2)
	# A BIG rock hovers beside the player too (it used to go over the head), its
	# bottom just above the feet. In the thick earth (columns 6-11).
	player.respawn_at(room.global_position + Vector2(7 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	rock = await _tear_big_rock(player)
	_check(rock != null and rock.is_big(), "hover aim: holding S still grows a big rock")
	if rock != null:
		await _wait_game(tuning.boulder_tear_time + tuning.boulder_hover_rise_time + 0.05)
		var big_offset: Vector2 = rock.global_position - player.get_center()
		var big_bottom: float = rock.global_position.y + rock.size / 2.0
		_check(rock.is_hovering and big_offset.x > 8.0 and big_bottom <= player.global_position.y,
			"hover aim: a big rock hovers BESIDE the player, not overhead (offset %s)" % big_offset)
	tuning.boulder_hover_aim = false
	room.reset_objects()
	await _wait_physics_frames(2)
	finished_sections.append("hover-aim")


## EXPERIMENT (EarthTuning.shadow_steerable): the shadow moves only while an arrow is
## held, goes back when the opposite arrow is held, and past the feet the other way.
func _check_steered_shadow(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthE") as Room
	var tuning: EarthTuning = player.earth_tuning
	world.jump_to_room(room)
	player.respawn_at(room.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	tuning.shadow_steerable = true
	var bend: EarthBendAbility = player.earth_bend
	Input.action_press(&"earth_column")
	await _wait_real(tuning.shadow_start_delay + 0.2)
	_check(bend.is_bending and bend.shadow_distance == 0.0, "steered shadow: it doesn't move by itself")
	Input.action_press(&"move_right")
	await _wait_real(0.2)
	Input.action_release(&"move_right")
	var moved_right: float = bend.shadow_distance
	await _wait_real(0.2)
	_check(moved_right > 8.0 and is_equal_approx(bend.shadow_distance, moved_right),
		"steered shadow: Right moves it along the floor, letting go stops it (%.1f px)" % moved_right)
	Input.action_press(&"move_left")
	await _wait_real(0.5)
	Input.action_release(&"move_left")
	var shadow_x: float = bend.get_shadow_position().x - player.global_position.x
	_check(bend.path_tangents[0] == Vector2i.LEFT and shadow_x < -4.0,
		"steered shadow: Left brings it back and out the other side (%.1f px left of the feet)" % -shadow_x)
	# Cancel with Jump (no earth used), and the press is spent.
	Input.action_release(&"earth_column")
	tuning.shadow_steerable = false
	await _wait_physics_frames(3)
	if player.state_machine.current_state.name == &"SnakeSteer":
		await _press_action("earth_column")
	room.reset_objects()
	await _wait_real(0.3)
	finished_sections.append("steered-shadow")


## After E7: objects inside a covered hidden chamber are hidden and switched off until
## the crumble reaches them; a room reset hides them again.
func _check_hidden_objects(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthD") as Room
	var hidden: HiddenLayer = room.get_node("Hidden") as HiddenLayer
	world.jump_to_room(room)
	await _wait_physics_frames(2)
	var wisp: Wisp = (load("res://scenes/enemies/wisp.tscn") as PackedScene).instantiate() as Wisp
	# Placed BEFORE it enters the tree: _ready() remembers this as its reset position.
	wisp.position = Vector2(22 * 8 + 4, 18 * 8)  # on the tunnel floor (room coordinates)
	room.add_child(wisp)
	hidden.track_object(wisp)
	await _wait_physics_frames(5)
	var start_x: float = wisp.global_position.x
	_check(hidden.is_object_hidden(wisp) and not wisp.visible and wisp.process_mode == Node.PROCESS_MODE_DISABLED,
		"a wisp inside a covered chamber is hidden and switched off")
	await _wait_physics_frames(20)
	_check(wisp.global_position.x == start_x, "...so it doesn't patrol")
	hidden.reveal_chamber(Vector2i(13, 16))
	await _wait_real(2.0)
	_check(not hidden.is_object_hidden(wisp) and wisp.visible and wisp.process_mode == Node.PROCESS_MODE_INHERIT,
		"the crumble reaching it brings the wisp back")
	room.reset_objects()
	await _wait_physics_frames(3)
	_check(hidden.is_object_hidden(wisp) and not wisp.visible, "a room reset hides it again")
	wisp.queue_free()
	await _wait_physics_frames(2)
	finished_sections.append("hidden-objects")


## After E7: a TAP of S while touching a creation shatters it into pebbles: a loose rock
## beside you (a hold still lifts it), a stuck rock, a hardened snake (all of it), a
## risen pillar. Away from creations S still tears earth.
func _check_shatter_creations(world: RoomManager, player: Player) -> void:
	var room: Room = world.get_node("RoomEarthC") as Room
	var earth: EarthLayer = room.get_node("Earth") as EarthLayer
	var field: PebbleField = room.get_node("PebbleField") as PebbleField
	var tuning: EarthTuning = player.earth_tuning
	tuning.boulder_hover_aim = false
	world.jump_to_room(room)
	player.facing_direction = 1.0
	await _wait_physics_frames(10)
	# A loose rock beside the player: tap = shatter, into pebbles.
	var rock: Boulder = await _rip_boulder(player)
	await _press_action("jump")  # let go: it lies loose
	await _wait_until(func() -> bool: return is_instance_valid(rock) and rock.is_loose(), 1.5)
	await _wait_physics_frames(2)
	if is_instance_valid(rock):
		player.respawn_at(Vector2(rock.global_position.x - rock.size / 2.0 - 6.0, room.global_position.y + 160))
		await _wait_physics_frames(5)
		field.reset()
		var torn_before: int = earth.torn_cells.size()
		await _press_action("earth_boulder")
		await _wait_real(tuning.shatter_tap_time + 0.05)
		await _wait_physics_frames(2)
		_check(not is_instance_valid(rock) and earth.torn_cells.size() == torn_before and field.pebble_positions.size() > 0,
			"a tap of S beside a loose rock shatters it into pebbles (no earth torn, %d pebbles)" % field.pebble_positions.size())
	# A stuck rock (a foothold made in code) next to the player.
	room.reset_objects()
	await _wait_physics_frames(2)
	player.respawn_at(room.global_position + Vector2(7 * 8 + 4, 160))
	await _wait_physics_frames(5)
	var stuck: Boulder = _throw_test_rock(room, player.get_center() + Vector2(16.0, -16.0), Vector2.DOWN, tuning)
	await _wait_until(func() -> bool: return not is_instance_valid(stuck) or stuck.phase != Boulder.Phase.FLYING, 1.0)
	if is_instance_valid(stuck) and stuck.phase == Boulder.Phase.STUCK:
		player.respawn_at(Vector2(stuck.global_position.x - 4.0 - 4.0 - 2.0, room.global_position.y + 160))
		await _wait_physics_frames(5)
		var stuck_cell: Vector2i = earth.get_cell_at(stuck.global_position)
		await _press_action("earth_boulder")
		await _wait_physics_frames(2)
		_check(not is_instance_valid(stuck) and not earth.is_column(stuck_cell),
			"a tap of S beside a stuck rock shatters it (and it's no longer ground)")
	else:
		_check(false, "test setup: a stuck rock beside the player")
	# A risen pillar: stand on it and tap S.
	room.reset_objects()
	await _wait_physics_frames(2)
	player.respawn_at(room.global_position + Vector2(5 * 8 + 4, 160))
	await _wait_physics_frames(5)
	player.earth_column.erupt(EarthFace.new(earth, Vector2i(7, 20), Vector2i.UP))
	await _wait_game(0.3)
	var columns: Array[EarthColumn] = _find_columns(room)
	if not columns.is_empty():
		player.respawn_at(room.global_position + Vector2(7 * 8 + 4, 160 - tuning.column_length))
		await _wait_game(0.2)
		await _press_action("earth_boulder")
		await _wait_physics_frames(2)
		_check(_find_columns(room).is_empty() and not earth.is_fresh(Vector2i(7, 20)),
			"a tap of S standing on a pillar shatters it (its tile stays spent)")
	else:
		_check(false, "test setup: a risen pillar")
	# A hardened snake (RoomEarthE): stand on the ledge right beside the bridge's first
	# tile (not on the bridge: you'd fall into the spikes) and tap S: all of it crumbles.
	room.reset_objects()
	await _wait_physics_frames(2)
	var snake_room: Room = world.get_node("RoomEarthE") as Room
	var snake_earth: EarthLayer = snake_room.get_node("Earth") as EarthLayer
	(snake_room.get_node("Sentry") as Sentry).can_fire = false
	world.jump_to_room(snake_room)
	player.respawn_at(snake_room.global_position + Vector2(11 * 8 + 4, 160))
	player.facing_direction = 1.0
	await _wait_physics_frames(5)
	var snake: EarthSnake = await _bend_snake_at(player, Vector2i(13, 20), Vector2i.RIGHT)
	await _wait_until(func() -> bool: return snake == null or not snake.is_moving(), 3.0)
	await _wait_physics_frames(3)
	if snake != null and not snake.is_moving():
		player.respawn_at(snake_room.global_position + Vector2(13 * 8 + 4, 160))
		await _wait_game(0.3)
		var spent: int = snake_earth.used_fade_progress.size()
		await _press_action("earth_boulder")
		_check(snake.phase == EarthSnake.Phase.CRUMBLING and not snake_earth.is_column(Vector2i(16, 20)),
			"a tap of S beside a snake makes it crumble (not solid any more)")
		await _wait_real(0.6)
		_check(not is_instance_valid(snake) and snake_earth.used_fade_progress.size() >= spent,
			"the whole snake crumbles away, its earth stays spent")
	else:
		_check(false, "test setup: a hardened snake bridge")
	snake_room.reset_objects()
	await _wait_physics_frames(2)
	finished_sections.append("shatter")


## Holds `action` for `real_seconds` (real time), then releases it, as input events.
func _hold_action(action: StringName, real_seconds: float) -> void:
	Input.parse_input_event(_make_action_event(action, true))
	await get_tree().process_frame
	await _wait_real(real_seconds)
	Input.parse_input_event(_make_action_event(action, false))
	await get_tree().process_frame
	await get_tree().physics_frame


## A rock made in code and thrown at once at perfect speed, so its path is exact: it
## flies from `center` along `direction`. `is_perfect` = counts as a perfect throw
## (kills enemies even when small); `is_big` = a big rock. Returns it.
func _throw_test_rock(room: Room, center: Vector2, direction: Vector2, tuning: EarthTuning,
		is_perfect: bool = true, is_big: bool = false) -> Boulder:
	var rock: Boulder = Boulder.new()
	rock.setup(center, Vector2.UP, 0.0, center.y, tuning)
	room.add_child(rock)
	if is_big:
		rock.grow(center, tuning.big_rock_size)
	# As if it had already hopped out: then throw() doesn't yank it out of a hole first.
	rock.is_hopping = true
	rock.throw(direction, tuning.boulder_perfect_throw_speed, tuning.boulder_perfect_float_time, is_perfect)
	return rock


## A sentry orb made in code (no sentry fired it), flying from `world_position` at
## `orb_velocity`, px/s.
func _launch_test_orb(room: Room, world_position: Vector2, orb_velocity: Vector2) -> SentryOrb:
	var orb: SentryOrb = (load("res://scenes/enemies/sentry_orb.tscn") as PackedScene).instantiate() as SentryOrb
	room.add_child(orb)
	orb.launch(world_position, orb_velocity, null)
	return orb


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


## Waits `seconds` of GAME time (slowed by Engine.time_scale; see _wait_until).
func _wait_game(seconds: float) -> void:
	await _wait_until(func() -> bool: return false, seconds)


## Waits `seconds` of REAL time (not slowed by Engine.time_scale).
func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS  %s" % description)
	else:
		failures += 1
		print("FAIL  %s" % description)

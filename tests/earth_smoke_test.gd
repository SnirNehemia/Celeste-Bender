extends Node
## Headless smoke test for the Earth chapter (Stages E1+). Not part of the game.
##
## Loads tests/earth_test_world.tscn and checks, by script, what can be checked
## without a person at the keyboard. Prints PASS/FAIL lines and quits. Run it with:
##   godot --headless --path . res://tests/earth_smoke_test.tscn

const WORLD_SCENE: PackedScene = preload("res://tests/earth_test_world.tscn")
const MIXED_WORLD_SCENE: PackedScene = preload("res://tests/mixed_test_world.tscn")
const WIND_ZONE_SCENE: PackedScene = preload("res://scenes/objects/wind_zone.tscn")

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

	await _check_e1_earth_ground(player, room, earth)
	await _check_e2_bend_core(player, room, earth)
	await _check_e3_column(world, player)
	await _check_e4_boulder(world, player)
	await _check_e4b_ground(world)
	await _check_e4c_hidden(world, player)
	await _check_e4c2_big_rock(world, player)
	await _check_e4c3_loose_rocks(world, player)
	await _check_grass_blades(world, player)
	# Let FX's slow-motion safety timer run out before switching worlds (a timer still
	# pending at quit is reported as a leak).
	await _wait_real(player.earth_tuning.bend_max_time + 0.5)
	world.queue_free()
	await get_tree().process_frame
	await _check_mixed_enemies()

	for section_name: String in ["E1", "E2", "E3", "E4", "E4b", "E4c", "E4c2", "E4c3", "grass", "mixed"]:
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
	await _press_action("earth_boulder")
	_check(player.boulder.held_boulder == rock and rock.phase == Boulder.Phase.POPPING and rock.is_hopping,
		"S next to a loose rock lifts it (state %s)" % player.state_machine.current_state.name)
	_check(earth.torn_cells.size() == torn_before, "lifting uses no earth")
	_check(player.state_machine.current_state.name == &"BoulderHold", "the player holds the lifted rock")
	await _wait_until(func() -> bool: return is_instance_valid(rock) and rock.is_in_perfect_window(), 1.0)
	_check(is_instance_valid(rock) and rock.is_in_perfect_window(), "a lifted rock has the perfect window")
	await _press_action("earth_boulder")
	_check(is_instance_valid(rock) and rock.phase == Boulder.Phase.FLYING, "a lifted rock can be thrown")
	room.reset_objects()
	await _wait_physics_frames(2)

	# A loose rock is a step: stand on it. S on top of it doesn't lift it.
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
		_check(is_instance_valid(rock) and rock.is_loose(), "S standing on a loose rock doesn't lift it from under the feet")
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

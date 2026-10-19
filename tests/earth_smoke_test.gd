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
	await _check_grass_blades(world, player)
	# Let FX's slow-motion safety timer run out before switching worlds (a timer still
	# pending at quit is reported as a leak).
	await _wait_real(player.earth_tuning.bend_max_time + 0.5)
	world.queue_free()
	await get_tree().process_frame
	await _check_mixed_enemies()

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
	# Visually too: the tile is still adjusted at runtime, back to plain white.
	var reset_tile_data: TileData = TileData.new()
	reset_tile_data.modulate = Color.BLACK
	earth._tile_data_runtime_update(Vector2i(3, 20), reset_tile_data)
	_check(earth._use_tile_data_runtime_update(Vector2i(3, 20)) and reset_tile_data.modulate == Color.WHITE,
		"a reset tile is drawn fresh again (modulate %s)" % reset_tile_data.modulate)
	reset_tile_data.free()  # TileData is a plain Object, not reference-counted
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
	await _wait_physics_frames(4)
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


## Waits `seconds` of REAL time (not slowed by Engine.time_scale).
func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS  %s" % description)
	else:
		failures += 1
		print("FAIL  %s" % description)

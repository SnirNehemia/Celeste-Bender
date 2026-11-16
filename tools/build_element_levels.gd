extends Node
## tools/build_element_levels.gd: writes one editor level per element, in the
## spirit of "Chapter 0 - Basics": a short run of rooms, a Key orb that lights a Key
## light for the Grand door in front of the Goal, a room BEHIND the last one (a
## depth gate), and collectibles in out-of-the-way places (the element's relic in
## four shards, a golden feather). See Collectibles.md.
##
##   levels/air_the_high_road.tscn     glide, updrafts, a crate onto a plate, storm clouds
##   levels/earth_the_deep_dig.tscn    super jump, big rock + hidden tunnel, snake bridge
##   levels/fire_the_ember_wood.tscn   fireball + brazier, thicket, a fuse in a DARK room
##   levels/water_the_thaw.tscn        ice block step, crumbling ice over a chasm, thin ice
##
## Each level has four rooms in a row (1 to 4) and room S behind room 4.
## The rooms' key moves are the ones the chapters' and test rooms' generators
## already use (tools/build_rooms.gd, build_earth_chapter.gd, build_fire_rooms.gd,
## build_water_rooms.gd), with the same sizes, so their distances are known to work.
## What's new is how they're put together, and it has NOT been play-tested.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_element_levels.tscn
## Add `-- air` (or earth, fire, water) to write only that level. It OVERWRITES the
## level files: once one is edited in the editor, stop rebuilding it.
##
## Units: tiles (8 px), (column, row). A one-screen room is 40 x 23 tiles.

const LEVELS_DIR: String = "res://levels/"
const TILE: int = LevelKit.TILE
const SCREEN_HEIGHT: float = 180.0
## A gap in a side wall is this many tiles tall, right above the floor it leads onto.
const GAP_HEIGHT: int = 4
## Rows of a one-screen room (row 22 is the half row at the bottom).
const ROWS: int = 23
const GRAND_DOOR_SIZE: Vector2 = Vector2(16, 64)
const GOAL_SIZE: Vector2 = Vector2(24, 32)
## "No gap in this wall" for _frame.
const NO_GAP: int = -1

var kit: LevelKit = null
## Where the next room of the level being built goes on the map (px): rooms sit
## side by side, left to right.
var next_room_x: float = 0.0


func _ready() -> void:
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var builders: Dictionary = {"air": _build_air, "earth": _build_earth, "fire": _build_fire, "water": _build_water}
	for level_key: String in builders:
		if wanted.is_empty() or wanted.has(level_key):
			(builders[level_key] as Callable).call()
	print("[BuildElementLevels] Done.")
	get_tree().quit()


# --- Helpers -----------------------------------------------------------------------

func _begin_level(title: String) -> void:
	kit = LevelKit.create(title)
	next_room_x = 0.0


func _save_level(file_name: String) -> void:
	for problem: String in kit.find_problems():
		print("[BuildElementLevels] PROBLEM in %s: %s" % [file_name, problem])
	var error: Error = kit.save(LEVELS_DIR + file_name)
	print("[BuildElementLevels] %s %s" % ["Wrote" if error == OK else "FAILED to write", LEVELS_DIR + file_name])


## The next room in the row, `columns` tiles wide (one screen tall).
func _next_room(node_name: String, title: String, columns: int = 40) -> Room:
	var room: Room = kit.add_room(node_name, title, Vector2(next_room_x, 0.0), Vector2(columns * TILE, SCREEN_HEIGHT))
	next_room_x += columns * TILE
	return room


## A room one depth BEHIND `front_room`, at the same place on the map and as big.
func _room_behind(front_room: Room, node_name: String, title: String) -> Room:
	return kit.add_room(node_name, title, front_room.position, front_room.room_size, 1)


## The room's shell in the terrain `terrain`: a ceiling, two side walls and the
## ground from `floor_row` down. `entry_floor` / `exit_floor`: the floor row a gap in
## the left / right wall leads onto (NO_GAP = a closed wall).
func _frame(room: Room, terrain: StringName, floor_row: int, entry_floor: int, exit_floor: int) -> void:
	var columns: int = int(room.room_size.x / TILE)
	kit.fill(room, terrain, 0, 0, columns, 1)
	kit.fill(room, terrain, 0, 0, 1, ROWS)
	kit.fill(room, terrain, columns - 1, 0, 1, ROWS)
	kit.fill(room, terrain, 0, floor_row, columns, ROWS - floor_row)
	if entry_floor != NO_GAP:
		kit.clear(room, 0, entry_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	if exit_floor != NO_GAP:
		kit.clear(room, columns - 1, exit_floor - GAP_HEIGHT, 1, GAP_HEIGHT)


## A spike pit cut into the ground: `depth` rows of open air from `top_row`, spikes
## on its bottom row.
func _spike_pit(room: Room, column: int, width: int, top_row: int, depth: int) -> void:
	kit.clear(room, column, top_row, width, depth)
	kit.spikes(room, column, top_row + depth - 1, width)


## Which elements work in `room` (all others off).
func _allow(room: Room, air: bool, earth: bool, fire: bool, water: bool) -> void:
	room.air_allowed = air
	room.earth_allowed = earth
	room.fire_allowed = fire
	room.water_allowed = water


## The end of every level, in `room` on the floor row `floor_row`: a Key light of
## `key_color` (lit once that Key orb is collected), a depth gate at `gate_column`,
## a wall with the Grand door in it, and the Goal behind the door.
func _finale(room: Room, wall_terrain: StringName, floor_row: int, key_color: KeyColors.Name, gate_column: int) -> void:
	var light: Node2D = kit.place(room, &"key_light", "KeyLight", LevelKit.corner(12, floor_row), {&"key_color": key_color})
	kit.depth_gate(room, "DepthGate", gate_column, floor_row)
	var door_rows: int = int(GRAND_DOOR_SIZE.y / TILE)
	kit.fill(room, wall_terrain, 30, 1, 2, floor_row - door_rows - 1)
	var door: Node2D = kit.place(room, &"grand_door", "GrandDoor", Vector2(30 * TILE, (floor_row - door_rows) * TILE),
		{&"door_size": GRAND_DOOR_SIZE, &"link_mode": Door.LinkMode.ALL})
	kit.link(door, &"switches", [light])
	kit.place(room, &"goal", "Goal", Vector2(34 * TILE, floor_row * TILE - GOAL_SIZE.y), {&"goal_size": GOAL_SIZE})


func _shard(room: Room, slot: int, element: RelicShard.Element, column: int, row: int) -> void:
	kit.place(room, &"relic_shard", "RelicShard%d" % slot, LevelKit.corner(column, row), {&"slot": slot, &"element": element})


## An updraft (a WindZone blowing up) from the ceiling down to the floor row 20,
## six tiles wide from `column`: glide inside it to rise (tools/build_rooms.gd room 3).
func _updraft(room: Room, node_name: String, column: int) -> void:
	kit.place(room, &"wind_zone", node_name, Vector2(column * TILE, TILE),
		{&"zone_size": Vector2(48, 152), &"wind_direction": Vector2.UP, &"wind_strength": 60.0})


# --- Air: The High Road ------------------------------------------------------------

func _build_air() -> void:
	_begin_level("Air - The High Road")
	var air: RelicShard.Element = RelicShard.Element.AIR

	# 1 "First Glide": two steps up, then jump and glide (Jump again in the air, hold)
	# over a 144 px spike pit. The feather hangs in the glide's path; a shard high over
	# the launch step wants a down-gust (Z + Down in the air: an extra jump).
	var glide_room: Room = _next_room("Room1", "First Glide")
	_allow(glide_room, true, false, false, false)
	_frame(glide_room, &"ground", 20, NO_GAP, 20)
	kit.fill(glide_room, &"ground", 8, 17, 4, 3)
	kit.fill(glide_room, &"ground", 12, 14, 4, 6)
	_spike_pit(glide_room, 16, 18, 20, 2)
	kit.set_spawn(glide_room, 2, 19)
	kit.place(glide_room, &"golden_feather", "GoldenFeather", LevelKit.corner(25, 13))
	_shard(glide_room, 1, air, 14, 6)

	# 2 "Lift": an updraft carries a glide up to a high ledge with a crate on it. Gust
	# (Z) the crate off the far end: it drops onto the plate below and the door opens.
	# A shard at the very top of the updraft; the Key orb behind the door.
	var lift_room: Room = _next_room("Room2", "Lift")
	_allow(lift_room, true, false, false, false)
	_frame(lift_room, &"ground", 20, 20, 20)
	_updraft(lift_room, "Updraft", 6)
	kit.fill(lift_room, &"ground", 12, 7, 16, 13)
	kit.place(lift_room, &"crate", "Crate", Vector2(20 * TILE, 7 * TILE))
	var plate: Node2D = kit.place(lift_room, &"pressure_plate", "Plate", Vector2(31 * TILE, 20 * TILE), {&"plate_width": 48.0})
	kit.fill(lift_room, &"ground", 34, 1, 1, 15)
	var lift_door: Node2D = kit.place(lift_room, &"door", "Door", Vector2(34 * TILE, 16 * TILE), {&"door_size": Vector2(8, 32)})
	kit.link(lift_door, &"switches", [plate])
	kit.set_spawn(lift_room, 2, 19)
	_shard(lift_room, 2, air, 9, 3)
	kit.place(lift_room, &"key_orb", "KeyOrb", LevelKit.corner(37, 18), {&"key_color": KeyColors.Name.RED})

	# 3 "Storm Crossing" (60 tiles: the camera scrolls): up an updraft to a pillar,
	# then a long glide over spikes, under a storm cloud, through a wind crystal that
	# refills the breath. A shard waits low over the spikes, for those who dare drop.
	var storm_room: Room = _next_room("Room3", "Storm Crossing", 60)
	_allow(storm_room, true, false, false, false)
	_frame(storm_room, &"ground", 20, 20, 20)
	_updraft(storm_room, "Updraft", 2)
	kit.fill(storm_room, &"ground", 8, 8, 4, 12)
	_spike_pit(storm_room, 12, 28, 20, 2)
	kit.fill(storm_room, &"storm_cloud", 28, 1, 9, 4)
	kit.place(storm_room, &"wind_crystal", "WindCrystal", Vector2(208, 56))
	kit.set_spawn(storm_room, 1, 19)
	_shard(storm_room, 3, air, 34, 16)

	# 4 "The Gate", and S behind it: an updraft to a high shelf with the last shard.
	var gate_room: Room = _next_room("Room4", "The Gate")
	_allow(gate_room, true, false, false, false)
	_frame(gate_room, &"ground", 20, 20, NO_GAP)
	_finale(gate_room, &"ground", 20, KeyColors.Name.RED, 16)
	kit.set_spawn(gate_room, 2, 19)
	var behind: Room = _room_behind(gate_room, "RoomS", "Behind the Gate")
	_allow(behind, true, false, false, false)
	_frame(behind, &"ground", 20, NO_GAP, NO_GAP)
	kit.depth_gate(behind, "DepthGate", 16, 20)
	_updraft(behind, "Updraft", 22)
	kit.fill(behind, &"ground", 28, 7, 11, 2)
	kit.set_spawn(behind, 14, 19)
	_shard(behind, 4, air, 34, 5)

	kit.set_start_room(glide_room)
	_save_level("air_the_high_road.tscn")


# --- Earth: The Deep Dig -----------------------------------------------------------

func _build_earth() -> void:
	_begin_level("Earth - The Deep Dig")
	var earth: RelicShard.Element = RelicShard.Element.EARTH

	# 1 "Solid Ground" (Earth chapter room 1): the ledge is 7 tiles up, too high to
	# jump: tap A on the earth at its foot for a super jump. One more earth tile on the
	# ledge's edge throws you up to a floating island with a shard.
	var jump_room: Room = _next_room("Room1", "Solid Ground")
	_allow(jump_room, false, true, false, false)
	_frame(jump_room, &"grass", 20, NO_GAP, 13)
	kit.fill(jump_room, &"grass", 9, 18, 3, 2)
	kit.fill(jump_room, &"earth", 17, 20, 5, 1)
	kit.fill(jump_room, &"grass", 22, 13, 18, 7)
	kit.clear(jump_room, 39, 13 - GAP_HEIGHT, 1, GAP_HEIGHT)
	kit.fill(jump_room, &"earth", 22, 13, 1, 1)
	kit.fill(jump_room, &"grass", 16, 7, 5, 2)
	kit.set_spawn(jump_room, 2, 19)
	kit.place(jump_room, &"golden_feather", "GoldenFeather", LevelKit.corner(10, 15))
	_shard(jump_room, 1, earth, 18, 5)

	# 2 "Breakthrough" (Earth chapter room 4): a cracked wall only a BIG rock (hold S)
	# breaks, then thick earth hiding a tunnel: dig a big rock out over it and drop
	# in. The tunnel leads right, to the Key orb and out; its dead end on the left
	# holds a shard.
	var dig_room: Room = _next_room("Room2", "Breakthrough")
	_allow(dig_room, false, true, false, false)
	_frame(dig_room, &"grass", 13, 13, NO_GAP)
	kit.fill(dig_room, &"earth", 4, 13, 9, 2)
	kit.fill(dig_room, &"cracked_wall", 14, 1, 2, 12)
	kit.fill(dig_room, &"earth", 16, 13, 12, 2)
	kit.fill(dig_room, &"hidden_chamber", 22, 15, 2, 1)
	kit.fill(dig_room, &"hidden_chamber", 22, 16, 17, 4)
	kit.fill(dig_room, &"hidden_chamber", 39, 16, 1, 4)   # the exit: earth until the tunnel opens
	kit.fill(dig_room, &"hidden_chamber", 17, 17, 5, 3)   # the dead end
	kit.set_spawn(dig_room, 2, 12)
	_shard(dig_room, 2, earth, 19, 18)
	kit.place(dig_room, &"key_orb", "KeyOrb", LevelKit.corner(34, 18), {&"key_color": KeyColors.Name.YELLOW})

	# 3 "The Long Bridge" (Earth chapter room 6): two spike chasms, each crossed on a
	# snake (hold A until the shadow leaves your feet) with exactly enough earth. Gray
	# rock under the spikes stops the shadow. A shard hangs over the second chasm.
	var bridge_room: Room = _next_room("Room3", "The Long Bridge")
	_allow(bridge_room, false, true, false, false)
	_frame(bridge_room, &"grass", 20, 20, NO_GAP)
	kit.fill(bridge_room, &"grass", 5, 17, 5, 3)
	kit.fill(bridge_room, &"earth", 5, 17, 5, 2)
	kit.fill(bridge_room, &"grass", 19, 17, 2, 3)
	kit.fill(bridge_room, &"earth", 19, 17, 2, 2)
	kit.fill(bridge_room, &"earth", 20, 19, 1, 2)
	kit.fill(bridge_room, &"grass", 27, 17, 13, 3)
	kit.clear(bridge_room, 39, 17 - GAP_HEIGHT, 1, GAP_HEIGHT)
	for chasm: Vector2i in [Vector2i(10, 9), Vector2i(21, 6)]:  # (column, width)
		kit.clear(bridge_room, chasm.x, 17, chasm.y, 5)
		kit.fill(bridge_room, &"ground", chasm.x, 22, chasm.y, 1)
		kit.spikes(bridge_room, chasm.x, 21, chasm.y)
	kit.set_spawn(bridge_room, 2, 19)
	_shard(bridge_room, 3, earth, 24, 13)

	# 4 "The Gate", and S behind it: one more super jump, to the last shard.
	var gate_room: Room = _next_room("Room4", "The Gate")
	_allow(gate_room, false, true, false, false)
	_frame(gate_room, &"grass", 17, 17, NO_GAP)
	_finale(gate_room, &"grass", 17, KeyColors.Name.YELLOW, 16)
	kit.set_spawn(gate_room, 2, 16)
	var behind: Room = _room_behind(gate_room, "RoomS", "Behind the Gate")
	_allow(behind, false, true, false, false)
	_frame(behind, &"grass", 17, NO_GAP, NO_GAP)
	kit.depth_gate(behind, "DepthGate", 16, 17)
	kit.fill(behind, &"earth", 20, 17, 5, 1)
	kit.fill(behind, &"grass", 25, 10, 14, 7)
	kit.set_spawn(behind, 14, 16)
	_shard(behind, 4, earth, 32, 8)

	kit.set_start_room(jump_room)
	_save_level("earth_the_deep_dig.tscn")


# --- Fire: The Ember Wood ----------------------------------------------------------

func _build_fire() -> void:
	_begin_level("Fire - The Ember Wood")
	var fire: RelicShard.Element = RelicShard.Element.FIRE

	# 1 "Spark" (Fire test room C, part 1; room E, part 1), 2 pips: a fireball (Q)
	# over the spike pit lights the brazier, which opens the door; a jet (W) carries
	# you over. A fire diamond, then a thicket wall to burn through. A shard high over
	# the pit takes a jet aimed up.
	var spark_room: Room = _next_room("Room1", "Spark")
	_allow(spark_room, false, false, true, false)
	_frame(spark_room, &"ground", 20, NO_GAP, 20)
	_spike_pit(spark_room, 8, 8, 20, 2)
	var pit_brazier: Node2D = kit.place(spark_room, &"brazier", "Brazier", LevelKit.corner(18, 20))
	var pit_door: Node2D = kit.place(spark_room, &"door", "Door", Vector2(21 * TILE, TILE), {&"door_size": Vector2(8, 152)})
	kit.link(pit_door, &"switches", [pit_brazier])
	kit.place(spark_room, &"fire_diamond", "FireDiamond", Vector2(24 * TILE + 4, 152))
	kit.fill(spark_room, &"thicket", 30, 1, 2, 19)
	spark_room.fire_start_pips = 2
	kit.set_spawn(spark_room, 2, 19)
	kit.place(spark_room, &"golden_feather", "GoldenFeather", LevelKit.corner(12, 15))
	_shard(spark_room, 1, fire, 12, 10)

	# 2 "Undergrowth" (Fire test room E, parts 2 and 3), 3 pips: the upper floor is a
	# dead end. Burn the thicket floor and drop into the corridor under it (the Key
	# orb is there). The dead end's wall is an overgrown cover: fire on it flashes the
	# whole cover away and opens a hidden chamber with a shard.
	var thicket_room: Room = _next_room("Room2", "Undergrowth")
	_allow(thicket_room, false, false, true, false)
	_frame(thicket_room, &"ground", 20, 20, 20)
	kit.fill(thicket_room, &"ground", 4, 17, 2, 3)
	kit.fill(thicket_room, &"ground", 6, 14, 6, 6)
	kit.fill(thicket_room, &"thicket", 12, 14, 6, 2)
	kit.fill(thicket_room, &"ground", 18, 14, 6, 2)
	kit.fill(thicket_room, &"ground", 24, 1, 7, 15)
	kit.fill(thicket_room, &"overgrown_thicket", 24, 11, 2, 3)
	kit.fill(thicket_room, &"hidden_chamber", 26, 11, 4, 3)
	_allow(thicket_room, false, false, true, false)  # the chamber brush turned Earth on
	thicket_room.fire_start_pips = 3
	kit.set_spawn(thicket_room, 2, 19)
	_shard(thicket_room, 2, fire, 28, 12)
	kit.place(thicket_room, &"key_orb", "KeyOrb", LevelKit.corner(21, 18), {&"key_color": KeyColors.Name.ORANGE})

	# 3 "Night Wood" (Fire test room D, part 1), DARK, 2 pips: a grass fuse runs along
	# the floor, over a grassy step, to a brazier that opens the door. One fireball
	# lights it, and the fire shows you the room. The second pip is a jet up to a
	# ledge in the dark, over the entrance, with a shard.
	var night_room: Room = _next_room("Room3", "Night Wood")
	_allow(night_room, false, false, true, false)
	_frame(night_room, &"ground", 20, 20, 20)
	kit.fill(night_room, &"grass", 6, 20, 25, 1)
	kit.fill(night_room, &"grass", 16, 18, 6, 2)
	kit.fill(night_room, &"ground", 24, 17, 4, 1)   # a stone shelter over the fuse
	var fuse_brazier: Node2D = kit.place(night_room, &"brazier", "Brazier", LevelKit.corner(30, 20))
	var fuse_door: Node2D = kit.place(night_room, &"door", "Door", Vector2(33 * TILE, TILE), {&"door_size": Vector2(8, 152)})
	kit.link(fuse_door, &"switches", [fuse_brazier])
	kit.fill(night_room, &"ground", 1, 12, 4, 1)
	night_room.is_dark = true
	night_room.fire_start_pips = 2
	kit.set_spawn(night_room, 2, 19)
	_shard(night_room, 3, fire, 3, 10)

	# 4 "The Gate", and S behind it (Fire test room B, part 1): a fire diamond, a
	# 10-tile spike pit one jet burst wide, the shard, and a diamond for the way back.
	var gate_room: Room = _next_room("Room4", "The Gate")
	_allow(gate_room, false, false, true, false)
	_frame(gate_room, &"ground", 20, 20, NO_GAP)
	_finale(gate_room, &"ground", 20, KeyColors.Name.ORANGE, 5)
	kit.set_spawn(gate_room, 2, 19)
	var behind: Room = _room_behind(gate_room, "RoomS", "Behind the Gate")
	_allow(behind, false, false, true, false)
	_frame(behind, &"ground", 20, NO_GAP, NO_GAP)
	kit.depth_gate(behind, "DepthGate", 5, 20)
	kit.place(behind, &"fire_diamond", "DiamondOut", Vector2(10 * TILE + 4, 152))
	_spike_pit(behind, 13, 10, 20, 2)
	kit.place(behind, &"fire_diamond", "DiamondBack", Vector2(32 * TILE + 4, 152))
	kit.set_spawn(behind, 3, 19)
	_shard(behind, 4, fire, 28, 18)

	kit.set_start_room(spark_room)
	_save_level("fire_the_ember_wood.tscn")


# --- Water: The Thaw ---------------------------------------------------------------

func _build_water() -> void:
	_begin_level("Water - The Thaw")
	var water: RelicShard.Element = RelicShard.Element.WATER
	# The ground's top row in every room: deep enough for pools to be cut into it.
	var ground_row: int = 16

	# 1 "First Frost" (Water test room E, part 1): a ledge 40 px up, too high to jump.
	# Hold 1 at the pool to gather a ball, steer it to the ledge's foot, 2 freezes it
	# into a block: a step that stays. A second block ON the ledge reaches the shard.
	var frost_room: Room = _next_room("Room1", "First Frost")
	_allow(frost_room, false, false, false, true)
	_frame(frost_room, &"ground", ground_row, NO_GAP, ground_row)
	_pool(frost_room, 5, ground_row, 4, 3)
	kit.fill(frost_room, &"ground", 13, 11, 7, 5)
	kit.set_spawn(frost_room, 2, ground_row - 1)
	kit.place(frost_room, &"golden_feather", "GoldenFeather", LevelKit.corner(16, 8))
	_shard(frost_room, 1, water, 17, 5)

	# 2 "Thin Air" (Water test room E, part 2; 50 tiles): a 96 px spike chasm. A ball
	# frozen in mid-air is a block that crumbles 2 s after you land on it: one step in
	# the middle is enough. A shard hangs high over the chasm; the Key orb past it.
	var chasm_room: Room = _next_room("Room2", "Thin Air", 50)
	_allow(chasm_room, false, false, false, true)
	_frame(chasm_room, &"ground", ground_row, ground_row, ground_row)
	_pool(chasm_room, 6, ground_row, 2, 3)
	_spike_pit(chasm_room, 10, 12, ground_row, 2)
	kit.set_spawn(chasm_room, 2, ground_row - 1)
	_shard(chasm_room, 2, water, 16, 9)
	kit.place(chasm_room, &"key_orb", "KeyOrb", LevelKit.corner(30, 14), {&"key_color": KeyColors.Name.BLUE})

	# 3 "Breaking Up" (Water test room J, part 6): a spike pit crossed on two patches
	# of crumbling rock and a run of crumbling ice: keep moving. A shard over the ice.
	var crumble_room: Room = _next_room("Room3", "Breaking Up")
	_allow(crumble_room, false, false, false, true)
	_frame(crumble_room, &"ground", ground_row, ground_row, ground_row)
	_spike_pit(crumble_room, 5, 24, ground_row, 2)
	kit.fill(crumble_room, &"crumble_rock", 6, ground_row, 3, 1)
	kit.fill(crumble_room, &"crumble_rock", 11, ground_row, 3, 1)
	kit.fill(crumble_room, &"crumble_ice", 16, ground_row, 10, 1)
	kit.set_spawn(crumble_room, 2, ground_row - 1)
	_shard(crumble_room, 3, water, 21, 12)

	# 4 "The Gate", and S behind it: a pool, a ledge, the last shard on top.
	var gate_room: Room = _next_room("Room4", "The Gate")
	_allow(gate_room, false, false, false, true)
	_frame(gate_room, &"ground", ground_row, ground_row, NO_GAP)
	_finale(gate_room, &"ground", ground_row, KeyColors.Name.BLUE, 5)
	kit.set_spawn(gate_room, 2, ground_row - 1)
	var behind: Room = _room_behind(gate_room, "RoomS", "Behind the Gate")
	_allow(behind, false, false, false, true)
	_frame(behind, &"ground", ground_row, NO_GAP, NO_GAP)
	kit.depth_gate(behind, "DepthGate", 5, ground_row)
	_pool(behind, 10, ground_row, 4, 3)
	kit.fill(behind, &"ground", 18, 11, 21, 5)
	kit.set_spawn(behind, 3, ground_row - 1)
	_shard(behind, 4, water, 28, 9)

	kit.set_start_room(frost_room)
	_save_level("water_the_thaw.tscn")


## A pool cut into the ground and filled to the brim.
func _pool(room: Room, column: int, row: int, width: int, depth: int) -> void:
	kit.clear(room, column, row, width, depth)
	kit.fill(room, &"water", column, row, width, depth)

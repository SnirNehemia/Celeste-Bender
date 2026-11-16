extends Node
## tools/build_basics_level.gd: finishes a COPY of "Chapter 0 - Basics".
##
## It opens the hand-made, unfinished level (SOURCE_PATH, never written to), fills
## in what was still empty, and saves the result as a new level (TARGET_PATH).
## Every room the designer built is kept as it is; this tool only adds:
##   - the hub (Room14): girders up to the plateau and out to the two upper wings
##   - the four wings' ends, each with the Key orb of one of the hub's Key lights:
##       crumbling wing   red     (already there, Room17)
##       platform wing    orange  Room39 (the sky ride) + Room40 (the descent)
##       enemy wing       yellow  Room42: falling blocks to drop on the wisps
##       dark wing        green   Room29: a dark room with a fake wall
##   - the way back down (Room35) and the sanctum behind the Grand door (Room15),
##     with the Goal
##   - collectibles in easter-egg places: the Air relic's four shards and the
##     golden feather (Collectibles.md)
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_basics_level.tscn
## It OVERWRITES TARGET_PATH: once that level is edited in the editor, stop running it.
##
## Reach numbers used below (PlayerTuning: jump 28 px high, about 58 px across):
## steps are at most 3 tiles up, gaps at most 3 tiles when climbing, 5 on the level.

const SOURCE_PATH: String = "res://levels/chapter_1_air_copy.tscn"
const TARGET_PATH: String = "res://levels/chapter_0_basics_finished.tscn"
const TARGET_TITLE: String = "Chapter 0 - Basics (finished)"
## The backdrop every room of the level uses (Room.backdrop_theme, as saved).
const LEVEL_LOOK: int = 12
const SCREEN: Vector2 = Vector2(320, 180)

var kit: LevelKit = null


func _ready() -> void:
	kit = LevelKit.open(SOURCE_PATH)
	kit.set_title(TARGET_TITLE)
	_build_secret_start()
	_build_hub()
	_build_way_down()
	_build_secret_shaft()
	_build_sanctum()
	_build_dark_wing()
	_build_enemy_wing()
	_build_sky_ride()
	_build_descent()
	for problem: String in kit.find_problems():
		print("[BuildBasics] PROBLEM: %s" % problem)
	var error: Error = kit.save(TARGET_PATH)
	print("[BuildBasics] %s %s" % ["Wrote" if error == OK else "FAILED to write", TARGET_PATH])
	get_tree().quit()


## Room1 (the start): the golden feather over the first pillar, and a fake wall
## right behind the spawn point. It leads to a new room, Room0, with a relic shard:
## the "go left at the start" secret.
func _build_secret_start() -> void:
	var start: Room = kit.get_room("Room1")
	kit.place(start, &"golden_feather", "GoldenFeather", LevelKit.corner(11, 15))
	kit.fill(start, &"hidden_chamber", 0, 18, 1, 3)
	start.earth_allowed = false  # the chamber brush turns Earth on: not in this level

	var cave: Room = kit.add_room("Room0", "Behind the start", start.position - Vector2(SCREEN.x, 0.0), SCREEN)
	cave.backdrop_theme = LEVEL_LOOK as Backdrop.Look
	cave.backdrop_altitude = start.backdrop_altitude
	var cave_map: PackedStringArray = PackedStringArray()
	for row: int in 9:
		cave_map.append("########################################")
	for row: int in 3:
		cave_map.append("####..........................##########")
	for row: int in 3:
		cave_map.append("##############................##########")
	for row: int in 3:
		cave_map.append("##############..####..........##########")
	cave_map.append("##############..####..####..............")
	cave_map.append("##############..####..####..............")
	cave_map.append("##############..####..####........@.....")
	cave_map.append("########################################")
	cave_map.append("########################################")
	kit.paint_map(cave, cave_map)
	kit.place(cave, &"relic_shard", "RelicShard2", LevelKit.corner(7, 10), {&"slot": 2})


## Room14 (the hub). Girders (one-way metal platforms) zigzag up the right shaft to
## the plateau over the Key lights, then on to a new ledge into the dark wing
## (right) and to the opening into the crumbling wing (left). Falling back in from
## above lands on them; their gaps let you down. Two bits of wall close the top
## corners, where a fall along the edge left the level.
func _build_hub() -> void:
	var hub: Room = kit.get_room("Room14")
	kit.fill(hub, &"ground", 39, 0, 1, 5)
	kit.fill(hub, &"ground", 0, 0, 1, 4)
	kit.fill(hub, &"ground", 36, 25, 4, 2)  # the ledge into the dark wing (Room29's floor)
	# [left column, top y px, width in tiles]: from the hall up to the plateau (4),
	# on to the dark wing's ledge (2), and the two up to the crumbling wing.
	var girders: Array = [
		[33, 344, 4], [29, 320, 4], [33, 296, 4], [29, 272, 4],
		[33, 248, 4], [31, 224, 4],
		[6, 216, 4], [2, 192, 4],
	]
	for index: int in girders.size():
		var girder: Array = girders[index]
		var width_px: float = girder[2] * LevelKit.TILE
		kit.place(hub, &"metal_platform", "HubGirder%d" % (index + 1),
			Vector2(girder[0] * LevelKit.TILE + width_px / 2.0, girder[1]), {&"platform_width": width_px})


## Room35, over the hub: the way back down from both key rooms above. Walls, and a
## small ledge under its spawn point; everything else falls through into the hub.
func _build_way_down() -> void:
	var chute: Room = kit.get_room("Room35")
	chute.display_title = "The way down"
	kit.fill(chute, &"ground", 0, 0, 1, 25)
	kit.fill(chute, &"ground", 39, 0, 1, 25)
	kit.fill(chute, &"ground", 1, 23, 3, 2)


## Room17's right shaft (the platform wing's way down) gets a 2-tile ledge and a
## fake wall beside it: through it, Room18 holds a relic shard in a sealed alcove.
func _build_secret_shaft() -> void:
	var key_room: Room = kit.get_room("Room17")
	kit.fill(key_room, &"ground", 36, 12, 2, 1)
	kit.fill(key_room, &"hidden_chamber", 38, 9, 2, 3)
	key_room.earth_allowed = false
	# Its spawn point was still where a new room puts it, now inside the hill: R
	# (or a death) in this room put the player in solid rock. On the way in instead.
	kit.set_spawn(key_room, 1, 13)

	var alcove: Room = kit.get_room("Room18")
	alcove.display_title = "Behind the shaft"
	kit.clear(alcove, 0, 9, 1, 3)
	kit.fill(alcove, &"ground", 1, 4, 9, 1)
	kit.fill(alcove, &"ground", 1, 12, 9, 2)
	kit.set_spawn(alcove, 3, 11)
	kit.place(alcove, &"relic_shard", "RelicShard1", LevelKit.corner(6, 10), {&"slot": 1})


## Room15, behind the hub (one depth back): a hall around the Grand door, and the
## Goal behind it. The door's links to the hub's four Key lights were already made.
func _build_sanctum() -> void:
	var sanctum: Room = kit.get_room("Room15")
	sanctum.display_title = "The sanctum"
	kit.fill(sanctum, &"ground", 0, 8, 40, 1)
	kit.fill(sanctum, &"ground", 0, 9, 1, 12)
	kit.fill(sanctum, &"ground", 39, 9, 1, 12)
	kit.place(sanctum, &"goal", "Goal", Vector2(35 * LevelKit.TILE, 21 * LevelKit.TILE - 32))


## Room29 "darkness and hidden chambers": a dark room that looks like a dead end.
## The lit brazier stands beside a fake wall: through it, a spike run lit only at
## its ends leads to the green Key orb. A second chamber, higher in the same wall
## and off the path, hides a relic shard.
func _build_dark_wing() -> void:
	var dark: Room = kit.get_room("Room29")
	var plain: String = "#...............######.................#"
	var dark_map: PackedStringArray = PackedStringArray([
		"########################################",
		plain, plain, plain, plain, plain, plain, plain,
		"#...............HHHHH#.................#",
		"#...............HHHHH#.................#",
		"#...............HHHHH#.................#",
		"#............#########.................#",
		plain, plain,
		"#........###....######.................#",
		plain,
		"................######.................#",
		"....###.........HHHHHH.....##...##..####",
		"................HHHHHH.....##...##..####",
		"..@.............HHHHHH...^^##^^^##^^####",
		"########################################",
		"########################################",
		"########################################",
	])
	kit.paint_map(dark, dark_map)
	dark.is_dark = true
	dark.earth_allowed = false
	for brazier_corner: Vector2 in [LevelKit.corner(14, 20), LevelKit.corner(23, 20), LevelKit.corner(33, 17), LevelKit.corner(38, 17)]:
		kit.place(dark, &"brazier", "Brazier%d" % int(brazier_corner.x), brazier_corner, {&"starts_lit": true})
	dark.fire_start_pips = 0  # the braziers are lights here, not targets
	kit.place(dark, &"key_orb", "KeyOrbGreen", LevelKit.corner(36, 15), {&"key_color": KeyColors.Name.GREEN})
	kit.place(dark, &"relic_shard", "RelicShard4", LevelKit.corner(19, 10), {&"slot": 4})


## Room42 (wisps, sentries, the enemy gate's door): three falling blocks hang over
## the wisps' lanes. Touch one and it drops 0.6 s later, crushing what's under it,
## and lands as the new floor. All six wisps beaten opens the door over the stairs;
## the yellow Key orb waits on the ledge behind it.
func _build_enemy_wing() -> void:
	var arena: Room = kit.get_room("Room42")
	arena.display_title = "Drop the ceiling"
	kit.fill(arena, &"falling_block", 3, 37, 4, 1)    # over the lane beside the entrance
	kit.fill(arena, &"falling_block", 7, 39, 19, 1)   # over the long lane (four wisps)
	kit.fill(arena, &"falling_block", 26, 37, 5, 1)   # over the pit
	kit.place(arena, &"key_orb", "KeyOrbYellow", Vector2(304, 192), {&"key_color": KeyColors.Name.YELLOW})


## Room39, the sky ride: the rail platform carries you past three small storm
## clouds (hop them), under a girder with a relic shard over it (up, across, and
## back down onto the moving platform), to an island. Crumbling stones lead on to
## the shaft down into Room40.
func _build_sky_ride() -> void:
	var ride: Room = kit.get_room("Room39")
	ride.display_title = "The sky ride"
	for cloud_column: int in [22, 56, 66]:
		kit.fill(ride, &"storm_cloud", cloud_column, 18, 1, 1)
	kit.fill(ride, &"storm_cloud", 50, 8, 20, 3)  # a cloud bank overhead: don't jump high here
	kit.place(ride, &"metal_platform", "ShardGirder", Vector2(41 * LevelKit.TILE, 128), {&"platform_width": 16.0})
	kit.place(ride, &"relic_shard", "RelicShard3", LevelKit.corner(44, 13), {&"slot": 3})
	kit.fill(ride, &"ground", 78, 19, 6, 4)       # the island where the rail ends
	for stone_column: int in [86, 92, 98]:
		kit.fill(ride, &"crumble_rock", stone_column, 19, 3, 1)
	kit.fill(ride, &"ground", 104, 19, 9, 4)      # the last island, over Room40's left end
	kit.fill(ride, &"ground", 119, 0, 29, 23)     # solid to the right: the shaft is cols 113-118


## Room40, the descent: four ledges to drop between, each drop with a storm cloud
## on one side (near, near, far, far: look before you leap). The orange Key orb sits
## on the floor at the bottom, beside the hole into Room17's right shaft.
func _build_descent() -> void:
	var descent: Room = kit.get_room("Room40")
	descent.display_title = "The descent"
	kit.fill(descent, &"ground", 0, 0, 1, 79)
	kit.fill(descent, &"ground", 39, 0, 1, 79)
	kit.fill(descent, &"ground", 1, 12, 26, 2)
	kit.fill(descent, &"ground", 13, 26, 26, 2)
	kit.fill(descent, &"ground", 1, 40, 26, 2)
	kit.fill(descent, &"ground", 13, 54, 26, 2)
	kit.fill(descent, &"ground", 1, 74, 29, 5)
	kit.fill(descent, &"ground", 38, 74, 1, 5)
	kit.fill(descent, &"storm_cloud", 27, 17, 6, 4)   # near side: jump out past it
	kit.fill(descent, &"storm_cloud", 8, 31, 5, 4)    # near side again, mirrored
	kit.fill(descent, &"storm_cloud", 33, 45, 6, 4)   # far side: just step off
	kit.fill(descent, &"storm_cloud", 1, 59, 6, 4)    # far side, mirrored
	kit.set_spawn(descent, 3, 11)
	kit.place(descent, &"key_orb", "KeyOrbOrange", LevelKit.corner(26, 72), {&"key_color": KeyColors.Name.ORANGE})

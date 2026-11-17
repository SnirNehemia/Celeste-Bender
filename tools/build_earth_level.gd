extends Node
## tools/build_earth_level.gd: writes "Earth - Bedrock", the Earth level that comes
## right after the Air chapter. Planned with the developer (16 Nov 2026) by
## LEVEL_DESIGN_GUIDE.md, with one big difference from the other levels: this one
## goes DOWN. It starts on the surface in daylight and every room is entered high
## on the left and left low on the right, so the ceilings close in as you go.
##
## THE PLAN (29 rooms, three acts):
##   Act 1, the run-in (Earth only): six rooms from the surface into the caves.
##   Act 2: the hub, a long low tunnel with four shafts in its floor. Each shaft
##     drops to a wing of four rooms (The Burrows: digging; The Roots: the snake;
##     The Nest: enemies in tunnels; The Deep: dark rooms and cave-ins). Each wing
##     ends in a Key orb in an earth tone and a teleport door back to its shaft.
##     The Grand door closes the tunnel's far end.
##   Act 3: The Heart (Air comes back), the Chimney (a hot updraft to the surface)
##     and four rooms mixing Earth and Air, with the Goal in the last one.
##
## BUILT SO FAR (stage 1):
##   Room1 Topsoil          the super jump (+ the golden feather, and a fake wall
##                          in the ridge's far side with relic shard 1)
##   Room2 The Sinkhole     each earth tile works once
##   Room3 Stone Throw      rocks as footholds
##   Room4 Breakthrough     the big rock, a cracked wall, digging down
##   Room5 First Snake      the snake as a bridge
##   Room6 Last Daylight    a calm way down
##   Room7 The Long Vein    the hub: four shaft mouths (still closed pits), the Key
##                          lights, the Grand door, and a chimney to relic shard 4
##   RoomHeart The Heart    a stub that holds the Goal until Act 3 is built
## STILL TO COME: the four wings and their Key orbs, Act 3 (the Goal moves to its
## last room), relic slots 2 and 3, and the level's own backdrop ("strata": until
## then the desert look stands in on the surface and the cavern look below).
## Until then the Grand door stays shut and find_problems() reports the relic.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_earth_level.tscn
## It OVERWRITES TARGET_PATH: once that level is edited in the editor, stop running it.
##
## Units: tiles (8 px), (column, row) from a room's top-left tile.
## Reach numbers the rooms are sized by:
##   jump 29 px up (3.5 tiles), 51 px across (measured for the Air chapter)
##   super jump (tap A): EarthTuning.column_super_jump_speed 350 px/s against
##     900 px/s2 gravity = 68 px, 8.5 tiles. Ledges here are 7 tiles (82%), the
##     height the Earth chapter's rooms use and its smoke test replays.
##   snake: at most 12 tiles (EarthTuning.snake_max_tiles), one per fresh tile of
##     the patch it comes out of.
## Rooms 1 to 4 are the Earth chapter's rooms 1 to 4 (tools/build_earth_chapter.gd),
## which were play-tested, set into taller rooms that lead downward.

const TARGET_PATH: String = "res://levels/earth_bedrock.tscn"
const LEVEL_TITLE: String = "Earth - Bedrock"
const TILE: int = LevelKit.TILE
const SCREEN_SIZE: Vector2 = Vector2(320, 180)
## Rows of a one-screen room (row 22 is the half row at the bottom).
const SCREEN_ROWS: int = 23
## A gap in a side wall is this many tiles tall, right above the floor it leads onto.
const GAP_HEIGHT: int = 4
const GRAND_DOOR_SIZE: Vector2 = Vector2(16, 64)
const GOAL_SIZE: Vector2 = Vector2(24, 32)
const EARTH: RelicShard.Element = RelicShard.Element.EARTH
## The four wings, in the order of their shafts along the hub (left to right):
## [name, Key color]. The colors are KeyColors' earth tones.
const WINGS: Array = [
	["The Burrows", KeyColors.Name.OCHRE], ["The Roots", KeyColors.Name.RUST],
	["The Nest", KeyColors.Name.MOSS], ["The Deep", KeyColors.Name.SLATE],
]
## The hub's size and floor row, and the left column of each wing's shaft mouth
## (4 tiles wide). The shafts are 40 tiles apart: each wing's first room is one
## screen wide, hangs right under its shaft (the shaft lands on its columns 4-7),
## and so has a column of the map to itself. The Burrows then go on down to the
## LEFT and The Deep down to the RIGHT; The Roots and The Nest go straight down.
const HUB_COLUMNS: int = 160
const HUB_FLOOR: int = 17
const SHAFT_COLUMNS: Array[int] = [12, 52, 92, 132]
const SHAFT_WIDTH: int = 4
## Where a wing's first room's ceiling opens under its shaft.
const WING_ENTRY_COLUMN: int = 4
## A teleport door's frame: TeleportDoor.DOOR_SIZE, px (its node is its top-left).
const DOOR_FRAME_HEIGHT: int = 24
## The Warren's spike islands: their left columns and their grass row.
const WARREN_ISLAND_1: int = 13
const WARREN_ISLAND_2: int = 8
const WARREN_ISLAND_ROW: int = 24

var kit: LevelKit = null
## Where the next room of the chain goes: its left edge on the map (px), and the
## map height (px) of the floor the last room's exit leads onto. The next room is
## placed so its entry floor is that same height: the two wall gaps line up.
var chain_left_px: float = 0.0
var chain_floor_px: float = 0.0


func _ready() -> void:
	kit = LevelKit.create(LEVEL_TITLE)
	var start_room: Room = _build_topsoil()
	_build_sinkhole()
	_build_stone_throw()
	_build_breakthrough()
	_build_first_snake()
	_build_last_daylight()
	var hub: Room = _build_hub()
	_build_heart_stub()
	_build_burrows(hub)
	kit.set_start_room(start_room)
	for problem: String in kit.find_problems():
		print("[BuildEarthLevel] PROBLEM: %s" % problem)
	var error: Error = kit.save(TARGET_PATH)
	print("[BuildEarthLevel] %s %s" % ["Wrote" if error == OK else "FAILED to write", TARGET_PATH])
	get_tree().quit()


# --- Helpers -----------------------------------------------------------------------

## The next room of the chain: `columns` x `rows` tiles, entered through a gap in
## its left wall onto the floor row `entry_floor`. Earth only. `under_sky` rooms
## have no ceiling and the surface backdrop; the others are caves.
## It comes with its shell (see _shell); call _exit_right when its floors are painted.
func _chain_room(node_name: String, title: String, columns: int, rows: int, entry_floor: int,
		under_sky: bool = false, has_entry: bool = true) -> Room:
	var map_px: Vector2 = Vector2(chain_left_px, chain_floor_px - entry_floor * TILE)
	var room: Room = _make_room(node_name, title, map_px, columns, rows, under_sky)
	if has_entry:
		kit.clear(room, 0, entry_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	chain_left_px += columns * TILE
	return room


## A room anywhere on the map: `columns` x `rows` tiles, its top-left at `map_px`.
## Earth only, with its shell (see _shell). `under_sky`: no ceiling, the surface
## backdrop; otherwise a cave.
func _make_room(node_name: String, title: String, map_px: Vector2, columns: int, rows: int, under_sky: bool) -> Room:
	# A one-screen room is 180 px tall: its 23rd row is half off screen.
	var height_px: float = SCREEN_SIZE.y if rows == SCREEN_ROWS else float(rows * TILE)
	var room: Room = kit.add_room(node_name, title, map_px, Vector2(columns * TILE, height_px))
	room.earth_allowed = true
	# Stand-ins until the level's own "strata" look exists.
	room.backdrop_theme = Backdrop.Look.DESERT if under_sky else Backdrop.Look.CAVERN
	room.backdrop_altitude = Backdrop.Altitude.SURFACE if under_sky else Backdrop.Altitude.UNDERGROUND
	_shell(room, columns, rows, not under_sky)
	return room


## A room's height on the map, px (a one-screen room is 180, not 23 x 8).
func _height_px(room: Room) -> float:
	return room.room_size.y


## A room's shell, in grass (the plain ground of Earth rooms: the bend shadow
## crawls over it): two side walls, and a one-tile ceiling unless it's under the sky.
## Floors are each room's own.
func _shell(room: Room, columns: int, rows: int, has_ceiling: bool) -> void:
	if has_ceiling:
		_grass(room, 0, 0, columns, 1)
	_grass(room, 0, 0, 1, rows)
	_grass(room, columns - 1, 0, 1, rows)


## Remembers that the room's way out leads onto `exit_floor` (its map height is
## where the next room's entry floor goes) and, if `open_gap`, opens the gap in the
## right wall. Breakthrough's exit is a hidden tunnel that paints its own gap.
func _exit_right(room: Room, exit_floor: int, open_gap: bool = true) -> void:
	if open_gap:
		var last_column: int = int(room.room_size.x / TILE) - 1
		kit.clear(room, last_column, exit_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	chain_floor_px = room.position.y + exit_floor * TILE


func _grass(room: Room, column: int, row: int, width: int, height: int) -> void:
	kit.fill(room, &"grass", column, row, width, height)


func _earth(room: Room, column: int, row: int, width: int, height: int) -> void:
	kit.fill(room, &"earth", column, row, width, height)


func _hidden(room: Room, column: int, row: int, width: int, height: int) -> void:
	kit.fill(room, &"hidden_chamber", column, row, width, height)


## A signpost standing on `floor_row`, its post on the left edge of `column`.
func _sign(room: Room, node_name: String, column: int, floor_row: int, text: String) -> void:
	kit.place(room, &"signpost", node_name, Vector2(column * TILE, floor_row * TILE), {&"text": text})


func _shard(room: Room, slot: int, column: int, row: int) -> void:
	kit.place(room, &"relic_shard", "RelicShard%d" % slot, LevelKit.corner(column, row), {&"slot": slot, &"element": EARTH})


# --- Act 1: from the surface into the caves ----------------------------------------

## Room1 "Topsoil" (under the sky): the super jump. A small step to jump, then a
## ridge 7 tiles high: too high to jump. Tap A on the earth at its foot. Past the
## ridge the floor carries on to the way out.
## The golden feather hangs over the step. The secret: the ridge's FAR side is a
## fake wall (rows 21-23). Drop off the ridge, turn back and walk into it.
func _build_topsoil() -> Room:
	chain_floor_px = 24 * TILE
	var room: Room = _chain_room("Room1", "Topsoil", 40, 31, 24, true, false)
	_grass(room, 1, 24, 38, 7)
	_grass(room, 9, 22, 3, 2)           # a 2-tile step to jump
	_earth(room, 17, 24, 5, 1)          # the earth patch at the ridge's foot
	_grass(room, 22, 17, 10, 7)         # the ridge: its top on row 17, 7 above the floor
	_hidden(room, 27, 21, 5, 3)         # the chamber inside it, open on the right
	kit.set_spawn(room, 2, 23)
	_sign(room, "SignSuperJump", 13, 24,
		"Stand on earth (yellow-brown) and TAP A to leap high.")
	kit.place(room, &"golden_feather", "GoldenFeather", LevelKit.corner(10, 19))
	_shard(room, 1, 28, 21)
	_exit_right(room, 24)
	return room


## Room2 "The Sinkhole" (under the sky, 38 rows): each earth tile works once. You
## walk in on a high ledge and drop 24 tiles into the pit. The way out is two
## towers, each 7 tiles above the last, with ONE earth tile at the foot of each.
## Wasting a tile means R. The exit (row 16) is 10 rows below where you came in.
func _build_sinkhole() -> void:
	var room: Room = _chain_room("Room2", "The Sinkhole", 40, 38, 6, true)
	_grass(room, 1, 6, 6, 32)           # the ledge you walk in on
	_grass(room, 7, 30, 32, 8)          # the pit's floor
	_earth(room, 16, 30, 1, 1)          # tower A's earth tile
	_grass(room, 17, 23, 7, 7)          # tower A: its top on row 23
	_earth(room, 23, 23, 1, 1)          # tower B's earth tile, on tower A's edge
	_grass(room, 24, 16, 15, 22)        # tower B: its top on row 16, out to the exit
	kit.set_spawn(room, 2, 5)
	_sign(room, "SignSpend", 3, 6,
		"Earth bends once, then goes dark until you die or press R.")
	_exit_right(room, 16)


## Room3 "Stone Throw": rocks as footholds, in the first room with a ceiling. A
## tower 7 tiles high with an earth face. The earth patch on the floor sits under
## a low overhang, so a super jump just bonks. S tears out a rock, S again throws
## it: stuck in the tower's face it is a step. Earth chapter room 3.
func _build_stone_throw() -> void:
	var room: Room = _chain_room("Room3", "Stone Throw", 40, SCREEN_ROWS, 6)
	_grass(room, 1, 6, 4, 17)           # the high ledge you walk in on: drop down
	_grass(room, 5, 20, 34, 3)          # the floor
	_grass(room, 17, 1, 11, 14)         # the low overhang over the patch
	_earth(room, 19, 20, 7, 1)          # the rock patch, under the overhang
	_grass(room, 30, 13, 9, 10)         # the tower: its top on row 13
	_earth(room, 30, 13, 1, 7)          # its earth face
	kit.set_spawn(room, 2, 5)
	_sign(room, "SignRock", 1, 6,
		"S: lift a rock. S again: throw it. It sticks to earth.")
	_exit_right(room, 13)


## Room4 "Breakthrough": the big rock, and the first way DOWN through the ground.
## A cracked wall blocks the ledge: only a BIG rock (hold S) breaks it. Past it,
## thick earth hides a tunnel: tear a big rock out over it and drop into the hole.
## The tunnel is the way out (its end in the right wall stays covered until the
## tunnel is opened, or a pocket of open air would give it away). Earth chapter room 4.
func _build_breakthrough() -> void:
	var room: Room = _chain_room("Room4", "Breakthrough", 40, SCREEN_ROWS, 13)
	_grass(room, 1, 13, 38, 10)         # one solid mass under both ledges
	_earth(room, 4, 13, 9, 2)           # ledge A's earth, 2 deep: big rocks need that
	kit.fill(room, &"cracked_wall", 14, 1, 2, 12)
	_earth(room, 16, 13, 12, 2)         # ledge B's earth
	_hidden(room, 22, 15, 2, 1)         # the shaft under the earth
	_hidden(room, 22, 16, 17, 4)        # the tunnel, 4 tiles high
	_hidden(room, 39, 16, 1, 4)         # its way out through the wall
	kit.set_spawn(room, 2, 12)
	_sign(room, "SignBigRock", 1, 13,
		"HOLD S: a big rock. Smash the wall, then dig a hole.")
	_exit_right(room, 20, false)


## Room5 "First Snake": the snake as a bridge. An 8-tile spike pit (a jump crosses
## 6). The ledge before it has 12 earth tiles, a full snake: out of the ledge's top
## it needs 1 tile up and up to 11 across, out of the ledge's side just the 8.
## Gray rock under the spikes stops the bend shadow from crossing the pit.
func _build_first_snake() -> void:
	var room: Room = _chain_room("Room5", "First Snake", 40, SCREEN_ROWS, 17)
	_grass(room, 1, 17, 9, 6)           # the near ledge
	_earth(room, 4, 17, 6, 2)           # its earth: 12 tiles
	kit.fill(room, &"ground", 10, 22, 8, 1)
	kit.spikes(room, 10, 21, 8)
	_grass(room, 18, 17, 21, 6)         # the far ledge
	kit.set_spawn(room, 2, 16)
	_sign(room, "SignSnake", 1, 17,
		"HOLD A till the shadow leaves you: a snake. A sets it.")
	_exit_right(room, 17)


## Room6 "Last Daylight" (34 rows): a calm room. Four big steps down, nothing that
## can kill, and a hole in the ceiling far out of reach: the last sky before the hub.
func _build_last_daylight() -> void:
	var room: Room = _chain_room("Room6", "Last Daylight", 40, 34, 6)
	kit.clear(room, 17, 0, 6, 1)        # the crack of sky (the top step is 14 rows below it)
	_grass(room, 1, 6, 10, 28)
	_grass(room, 11, 14, 8, 20)
	_grass(room, 19, 22, 8, 12)
	_grass(room, 27, 30, 12, 4)
	kit.set_spawn(room, 2, 5)
	_sign(room, "SignDaylight", 4, 6, "The last daylight. From here on, only earth.")
	_exit_right(room, 30)


# --- Act 2: the hub ----------------------------------------------------------------

## Room7 "The Long Vein": the hub, a tunnel 160 tiles long (four screens) in solid
## ground. It is 7 tiles high, pinched to 3 in three places. Four shaft mouths in
## its floor lead down to the wings, each with its wing's Key light and a sign
## beside it, and a teleport exit in the wing's color where the wing brings you
## back. A wing not built yet has a closed pit 3 tiles deep for a mouth. At the far
## end the four Key lights stand in a row before the Grand door, and past the door
## the tunnel leads on to the Heart. Before the second pinch a 3-tile chimney goes
## up into the ceiling: a super jump from the earth under it reaches a pocket with
## relic shard 4.
func _build_hub() -> Room:
	var hub: Room = _chain_room("Room7", "The Long Vein", HUB_COLUMNS, SCREEN_ROWS, HUB_FLOOR)
	_grass(hub, 0, 0, HUB_COLUMNS, SCREEN_ROWS)
	kit.clear(hub, 0, HUB_FLOOR - GAP_HEIGHT, 1, GAP_HEIGHT)
	kit.clear(hub, 1, 10, HUB_COLUMNS - 2, 7)     # the tunnel: rows 10-16
	_grass(hub, 26, 10, 11, 4)                    # pinch 1: 3 tiles of headroom
	_grass(hub, 66, 10, 13, 4)                    # pinch 2
	_grass(hub, 104, 10, 11, 4)                   # pinch 3
	# The chimney, rows 3-9, 3 tiles wide: 2 left no room to stand off-center.
	kit.clear(hub, 63, 3, 3, 7)
	kit.clear(hub, 66, 7, 6, 3)                   # the pocket: its floor is pinch 2's top, 7 above the tunnel floor
	_earth(hub, 63, HUB_FLOOR, 3, 1)              # the earth under the chimney
	_shard(hub, 4, 69, 8)
	for index: int in WINGS.size():
		var column: int = SHAFT_COLUMNS[index]
		var wing_name: String = WINGS[index][0]
		var is_open: bool = index == 0            # the wings built so far
		if is_open:
			# The mouth goes right through the floor: the wing's first room is below.
			kit.clear(hub, column, HUB_FLOOR, SHAFT_WIDTH, SCREEN_ROWS - HUB_FLOOR)
			kit.place(hub, &"teleport_exit", "WingExit%d" % (index + 1),
				Vector2((column + SHAFT_WIDTH + 2) * TILE, HUB_FLOOR * TILE - DOOR_FRAME_HEIGHT),
				{&"door_color": WINGS[index][1], &"is_exit": true})
		else:
			kit.clear(hub, column, HUB_FLOOR, SHAFT_WIDTH, 3)
		# The wing's light stands just before its mouth (seen while walking right),
		# its sign before that: after the mouth the next one is already in sight.
		_sign(hub, "SignWing%d" % (index + 1), column - 5, HUB_FLOOR,
			("%s. Down you go." if is_open else "%s. Not open yet.") % wing_name)
		kit.place(hub, &"key_light", "ShaftLight%d" % (index + 1),
			LevelKit.corner(column - 2, HUB_FLOOR), {&"key_color": WINGS[index][1]})
	# The door's end: one tile more headroom (8), the height of the Grand door.
	var door_rows: int = int(GRAND_DOOR_SIZE.y / TILE)
	var door_top: int = HUB_FLOOR - door_rows
	var door_column: int = HUB_COLUMNS - 12
	kit.clear(hub, door_column - 10, door_top, 21, 1)
	_grass(hub, door_column, 1, 2, door_top - 1)  # the wall the door hangs under
	var lights: Array = []
	for index: int in WINGS.size():
		lights.append(kit.place(hub, &"key_light", "KeyLight%d" % (index + 1),
			LevelKit.corner(door_column - 9 + index * 2, HUB_FLOOR), {&"key_color": WINGS[index][1]}))
	var door: Node2D = kit.place(hub, &"grand_door", "GrandDoor", Vector2(door_column * TILE, door_top * TILE),
		{&"door_size": GRAND_DOOR_SIZE, &"link_mode": Door.LinkMode.ALL})
	kit.link(door, &"switches", lights)
	kit.set_spawn(hub, 2, HUB_FLOOR - 1)
	_exit_right(hub, HUB_FLOOR)
	return hub


## RoomHeart "The Heart": a stub. It holds the Goal so the level can be finished
## and tested; Act 3 turns it into the room where Air comes back and moves the Goal
## to the surface.
func _build_heart_stub() -> void:
	var room: Room = _chain_room("RoomHeart", "The Heart", 40, SCREEN_ROWS, HUB_FLOOR)
	_grass(room, 1, HUB_FLOOR, 38, SCREEN_ROWS - HUB_FLOOR)
	kit.set_spawn(room, 2, HUB_FLOOR - 1)
	_sign(room, "SignHeart", 6, HUB_FLOOR, "The Heart. The way back up is still to be built.")
	kit.place(room, &"goal", "Goal", Vector2(30 * TILE, HUB_FLOOR * TILE - GOAL_SIZE.y), {&"goal_size": GOAL_SIZE})


# --- Act 2: Wing 1, The Burrows (digging) --------------------------------------------
# Four rooms that go down and to the LEFT of the hub's first shaft. One idea: earth
# can be hollow. Under thick earth (2 deep: a big rock fits) there may be a covered
# chamber, and a big rock torn out over it opens it: drop through. A covered
# chamber that touches open air can also simply be walked into ("peeking": it's a
# fake wall). The tell: a covered chamber is drawn as deep earth, while solid
# ground under earth is grass.
# Every dig is over a covered chamber at least as wide as the earth over it, so a
# 2x2 hole anywhere in that earth opens onto 2 open cells: wide enough to drop.

## Builds the wing under `hub`'s first shaft.
func _build_burrows(hub: Room) -> void:
	var shaft_px: float = hub.position.x + SHAFT_COLUMNS[0] * TILE
	var first_px: Vector2 = Vector2(shaft_px - WING_ENTRY_COLUMN * TILE, hub.position.y + _height_px(hub))
	var dig_here: Room = _build_dig_here(first_px)
	var down_the_shaft: Room = _build_down_the_shaft(dig_here.position + Vector2(0.0, _height_px(dig_here)))
	# Down the Shaft leaves through its LEFT wall onto row 42; Peeking is entered
	# through its RIGHT wall onto row 12, and leaves left onto row 20; the Warren is
	# entered right onto row 8.
	var peeking_px: Vector2 = Vector2(down_the_shaft.position.x - 40 * TILE, down_the_shaft.position.y + (42 - 12) * TILE)
	var peeking: Room = _build_peeking(peeking_px)
	_build_warren(Vector2(peeking.position.x - 40 * TILE, peeking.position.y + (20 - 8) * TILE))


## RoomB1 "Dig Here": the smallest room that shows the idea. You fall in from the
## hub onto a floor with nothing on it but a wide strip of thick earth. Under it a
## covered chamber, and from the chamber a covered shaft out through the floor of
## the room to the next one. No way back up: the wing is one-way.
func _build_dig_here(map_px: Vector2) -> Room:
	var room: Room = _make_room("RoomB1", "Dig Here", map_px, 40, SCREEN_ROWS, false)
	_grass(room, 0, 0, 40, SCREEN_ROWS)
	kit.clear(room, WING_ENTRY_COLUMN, 0, 4, 6)   # the shaft you fall in through
	kit.clear(room, 1, 6, 30, 6)                  # the cave: rows 6-11
	_earth(room, 14, 12, 12, 2)                   # the thick earth
	_hidden(room, 14, 14, 12, 5)                  # the chamber under all of it
	_hidden(room, 22, 19, 4, 4)                   # its way down, out through the bottom
	kit.set_spawn(room, 5, 11)
	_sign(room, "SignHollow", 9, 12,
		"Hollow under here. HOLD S, throw the big rock, drop in.")
	return room


## RoomB2 "Down the Shaft" (two screens tall): dig through three floors in a row,
## each one lower and with less headroom than the last (7, 6, 5 rows). Each
## floor's thick earth is on the other side from where you land, so the way down
## zigzags. Out through the left wall at the bottom.
func _build_down_the_shaft(map_px: Vector2) -> Room:
	var room: Room = _make_room("RoomB2", "Down the Shaft", map_px, 40, 46, false)
	_grass(room, 0, 0, 40, 46)
	kit.clear(room, 22, 0, 4, 1)                  # in from Dig Here's covered shaft
	kit.clear(room, 1, 1, 38, 7)                  # cave 1: rows 1-7
	_earth(room, 6, 8, 8, 2)                      # floor 1: dig on the left
	_hidden(room, 6, 10, 8, 4)
	kit.clear(room, 1, 14, 38, 6)                 # cave 2: rows 14-19
	_earth(room, 26, 20, 8, 2)                    # floor 2: dig on the right
	_hidden(room, 26, 22, 8, 4)
	kit.clear(room, 1, 26, 38, 5)                 # cave 3: rows 26-30
	_earth(room, 12, 31, 8, 2)                    # floor 3: dig in the middle
	_hidden(room, 12, 33, 8, 4)
	kit.clear(room, 1, 37, 38, 5)                 # cave 4: rows 37-41
	kit.clear(room, 0, 38, 1, 4)                  # the way out, left
	kit.set_spawn(room, 23, 7)
	return room


## RoomB3 "Peeking": covered chambers you can walk into. A corridor 4 tiles high
## runs into what looks like its end wall: a covered chamber, open at both ends.
## Walk into it. Past it two patches of earth: the first is solid ground (grass
## under it), the second is hollow; dig it and drop to the lower corridor.
## Entered from the right, left on the left.
func _build_peeking(map_px: Vector2) -> Room:
	var room: Room = _make_room("RoomB3", "Peeking", map_px, 40, SCREEN_ROWS, false)
	_grass(room, 0, 0, 40, SCREEN_ROWS)
	kit.clear(room, 25, 8, 15, 4)                 # corridor 1, in through the right wall
	_hidden(room, 21, 8, 4, 4)                    # the wall you can walk into
	# Corridor 2, one row higher: over earth, 4 rows of headroom would let a
	# stray tap of A (a pillar 3 tall under you) crush you against the ceiling.
	kit.clear(room, 9, 7, 12, 5)
	_earth(room, 16, 12, 4, 2)                    # solid: grass under it
	_earth(room, 9, 12, 6, 2)                     # hollow
	_hidden(room, 9, 14, 6, 2)
	kit.clear(room, 0, 16, 36, 4)                 # corridor 3, out through the left wall
	kit.set_spawn(room, 37, 11)
	_sign(room, "SignPeek", 30, 12, "Not every wall is solid. Walk into this one.")
	return room


## RoomB4 "The Warren" (two screens tall, the exam). Four tiers, top to bottom:
##   A  a floor of three thick-earth patches, only some hollow (the wing's idea, as
##      before): solid on the left, the way on in the middle, the shard pocket right.
##   B  SPIKE ISLANDS: you land on a ledge with a strip of earth. Beyond it a pit of
##      spikes, and over it two islands covered in spikes on every side. Throw rocks
##      onto them: a rock is caught on spikes and stays as a one-tile step. Two steps,
##      then the far ledge, whose thick earth is hollow: dig down.
##   C  THE GUARDED DOOR: two wisps patrol the corridor in front of a door, and an
##      enemy gate opens the door once both are beaten. A wisp only falls to a big
##      rock or a perfect one (the earth here is 2 deep: big rocks fit). Notches in
##      the floor keep each wisp in its stretch. Past the door, hollow earth again.
##   D  the Key orb and the teleport door home.
## Relic shard 2 (the secret): the RIGHT patch of floor A is hollow too, but its
## chamber is a closed pocket with the shard. Its floor is thick earth: dig through
## it onto ledge B, the same way on.
## Every cave over earth is at least 5 rows high: a stray tap of A (a pillar 3
## tall under you) crushes you under 4.
func _build_warren(map_px: Vector2) -> Room:
	var room: Room = _make_room("RoomB4", "The Warren", map_px, 40, 48, false)
	var key_color: KeyColors.Name = WINGS[0][1]
	_grass(room, 0, 0, 40, 48)
	# Tier A: cave A, rows 3-7, in through the right wall; its floor on row 8.
	kit.clear(room, 9, 3, 31, 5)
	_earth(room, 9, 8, 6, 2)                      # solid: grass under it
	_earth(room, 18, 8, 6, 2)                     # hollow: the way on
	_hidden(room, 18, 10, 6, 5)
	_earth(room, 28, 8, 6, 2)                     # hollow: the shard pocket
	_hidden(room, 28, 10, 6, 3)
	_earth(room, 28, 13, 6, 2)                    # the pocket's floor: dig on through it
	_shard(room, 2, 30, 11)
	# Tier B: cave B, rows 15-21. The ledge you land on (columns 17-38, floor row 22)
	# with a strip of earth 1 deep: small rocks only, one per tile.
	kit.clear(room, 1, 15, 38, 7)
	_earth(room, 17, 22, 8, 1)
	# The pit, columns 6-16, spikes along its bottom.
	kit.clear(room, 6, 22, 11, 6)
	kit.spikes(room, 6, 27, 11)
	# Two islands, 2 tiles of grass with spikes all round, their tops 2 rows under
	# the ledge: a rock caught on top is a step 1 row under the ledge.
	for island_column: int in [WARREN_ISLAND_1, WARREN_ISLAND_2]:
		_spiked_island(room, island_column, WARREN_ISLAND_ROW)
	# The far ledge (columns 1-5): thick earth, hollow under it, down to tier C.
	_earth(room, 1, 22, 4, 2)
	_hidden(room, 1, 24, 4, 5)
	_sign(room, "SignSpikeSteps", 27, 22, "Thrown rocks stick in spikes.")
	# Tier C: cave C, rows 29-35, floor row 36.
	kit.clear(room, 1, 29, 38, 7)
	_earth(room, 6, 36, 5, 2)                     # where you land: rocks, big ones too
	kit.clear(room, 12, 36, 1, 1)                 # notch: wisp 1 turns here
	kit.clear(room, 22, 36, 1, 1)                 # notch: between the two wisps
	_earth(room, 23, 36, 3, 2)                    # more earth, once wisp 1 is gone
	var wisp_1: Node2D = kit.place(room, &"wisp", "Wisp1", LevelKit.corner(17, 36), {&"start_direction": -1})
	var wisp_2: Node2D = kit.place(room, &"wisp", "Wisp2", LevelKit.corner(27, 36), {&"start_direction": 1})
	var gate: Node2D = kit.place(room, &"enemy_gate", "EnemyGate", LevelKit.corner(28, 30))
	kit.link(gate, &"enemies", [wisp_1, wisp_2])
	var door: Node2D = kit.place(room, &"door", "GuardedDoor", LevelKit.corner(30, 29),
		{&"door_size": Vector2(2 * TILE, 7 * TILE)})
	kit.link(door, &"switches", [gate])
	_sign(room, "SignWisps", 3, 36, "Big or perfect rocks beat wisps.")
	_earth(room, 33, 36, 5, 2)                    # past the door: hollow, down to D
	_hidden(room, 33, 38, 5, 4)
	# Tier D: cave D, rows 42-45.
	kit.clear(room, 9, 42, 30, 4)
	kit.place(room, &"key_orb", "KeyOrb", LevelKit.corner(14, 45), {&"key_color": key_color})
	kit.place(room, &"teleport_door", "WayHome", Vector2(10 * TILE, 46 * TILE - DOOR_FRAME_HEIGHT),
		{&"door_color": key_color})
	kit.set_spawn(room, 37, 7)
	return room


## A 2x1 block of grass at (column, row) with spikes on all four sides (the top
## strip on row - 1, the bottom on row + 1, one each side).
func _spiked_island(room: Room, column: int, row: int) -> void:
	_grass(room, column, row, 2, 1)
	kit.spikes(room, column, row - 1, 2, Spikes.Facing.UP)
	kit.spikes(room, column, row + 1, 2, Spikes.Facing.DOWN)
	kit.spikes(room, column - 1, row, 1, Spikes.Facing.LEFT)
	kit.spikes(room, column + 2, row, 1, Spikes.Facing.RIGHT)

extends Node
## tools/build_fire_level.gd: writes "Fire - The Burning Ascent", the Fire level that
## comes right after the Basics, Air and Earth chapters. Planned with the developer
## (16 Nov 2026) by LEVEL_DESIGN_GUIDE.md, set in the EMBERWOOD backdrop (a forest on
## the flank of a live volcano at dusk): the level climbs from the edge of the wood,
## through the great hollow tree of the hub, out to its four wings: the dry
## undergrowth (Wildfire), the canopy (Ropes and Weights), above the treeline
## (Sky of Embers) and down in the root caves (Wild Things), with the Goal on the
## crater's rim behind the Grand door.
##
## BUILT SO FAR (stages 1-3 of the plan). Stage 1, the run-in, "the edge of the wood", six rooms,
## each teaching one Fire move, Fire only:
##     Room1 Kindling       the fireball (Q) lights a brazier; the golden feather
##     Room2 Spent          pips run out: one pip, two braziers, a fire diamond
##     Room3 The Fuse       grass burns, burning grass kills, ash is a firebreak
##     Room4 First Burst    the flame jet (W): a pit you can't die in, a high ledge
##     Room5 Chain          hold W to chain bursts, over spikes
##     Room6 Ash Walk       jetting off grass sets it alight behind you
##   Room7 Ember Hall (the hub, inside a great hollow tree): four Key lights over the
##     depth gate, a zigzag of girders up the middle, the four wing ledges (Wildfire open since stage 2, Ropes and Weights since stage 3).
##   RoomSanctum, one depth behind the hub: the Grand door, the Goal and relic shard 4.
## Stage 2, wing 1 WILDFIRE ("the dry undergrowth", red key), four rooms going LEFT
## from the hub's left ledge (row 28) and stepping down; Fire only:
##     WildRoom1 Dry Grass    fire climbs grass: a brazier in a stone shrine on a
##                            grass mound, reached only by fire climbing the mound
##     WildRoom2 Undergrowth  thicket burns through and crumbles: a wall, then a
##                            floor that drops you to the lower corridor
##     WildRoom3 Overgrown    covers (hanging roots) hide passages: the exit, and
##                            relic shard 2 under a grass cover in the floor
##     WildRoom4 Wildfire     the exam (80 tiles): a thicket wall on grass, a jet
##                            over spikes, a thicket floor, a cover in front of the Key orb;
##                            a red teleport door home to the hub
## Stage 3, wing 2 ROPES AND WEIGHTS ("the canopy", orange key), four rooms going
## RIGHT from the hub's right ledge (row 25), all on floor row 13 and OPEN SKY under
## the ledges (a fall out of the room is death); Fire only:
##     RopeRoom1 Drawbridge      one pip: burn the vine holding a plank on end and
##                               it topples across the gap
##     RopeRoom2 Dead Weight     a metal crate on a vine over a pressure plate: cut
##                               the vine and its weight opens the door; standing on
##                               it reaches relic shard 3 (the element puzzle)
##     RopeRoom3 Lowered         a plank grown over with vines: set the plank alight
##                               and every vine snaps at once, so it drops level onto
##                               the gap's rims as a bridge
##     RopeRoom4 Counterweights  the exam (60 tiles): all three in a row, the orange
##                               Key orb and an orange teleport door home
## Their tops stay at or under the hub's row 12 (map y -384): the Sky of Embers wing
## will go right from the hub's top ledge, above them.
## STILL TO COME: the wings Sky of Embers and Wild Things and their Key orbs, relic
## slot 1, and the crater's rim as the Goal's own room. Until then the Grand door
## stays shut and find_problems() reports the unfinished relic.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_fire_level.tscn
## It OVERWRITES TARGET_PATH: once that level is edited in the editor, stop running it.
##
## Units: tiles (8 px), (column, row) from a room's top-left tile.
## Reach numbers the rooms are sized by, MEASURED (16 Nov 2026) with simulated keys on
## flat ground, landing at the height of the take-off (FireTuning as saved):
##   running jump                 51 px across (6.4 tiles), 29 px up (3.7)
##   one burst from standing      up 89 px (11.1 tiles), or right 86 px (10.8)
##   jump + one burst right       125-137 px across (16-17 tiles)
##   jump + one burst up+right    135 px across, 91 px up (11.4 tiles)
##   jump + two bursts up         212 px up (26.6 tiles)
##   fireball                     FireTuning.fireball_max_range = 300 px (37 tiles)
## Every gap and ledge here is about 80% of the move it asks for, and more than the
## move before it can manage. tests/built_levels_smoke_test (ascent) replays them.

const TARGET_PATH: String = "res://levels/fire_burning_ascent.tscn"
const LEVEL_TITLE: String = "Fire - The Burning Ascent"
const TILE: int = LevelKit.TILE
const SCREEN_SIZE: Vector2 = Vector2(320, 180)
## Rows of a one-screen room (row 22 is the half row at the bottom).
const SCREEN_ROWS: int = 23
## A gap in a side wall is this many tiles tall, right above the floor it leads onto.
const GAP_HEIGHT: int = 4
## A door that closes a wall gap: one tile wide, as tall as the gap.
const DOOR_SIZE: Vector2 = Vector2(8, 32)
## Hub girders: GIRDER_WIDTH px wide, a jump (3 rows) apart.
const GIRDER_WIDTH: float = 32.0
const GRAND_DOOR_SIZE: Vector2 = Vector2(16, 64)
const GOAL_SIZE: Vector2 = Vector2(24, 32)
const FIRE: RelicShard.Element = RelicShard.Element.FIRE
## The hub's Key lights, left to right, one per wing (warm colors for a fire level).
const KEY_COLORS: Array[KeyColors.Name] = [
	KeyColors.Name.RED, KeyColors.Name.ORANGE, KeyColors.Name.YELLOW, KeyColors.Name.GREEN,
]
## The hub's left ledge, where the Wildfire wing opens (its floor row).
const WILDFIRE_LEDGE_ROW: int = 28
## The hub's right ledge, where the Ropes and Weights wing opens (its floor row).
const ROPES_LEDGE_ROW: int = 25
## Every Ropes and Weights room's ledges stand on this row, with open sky under them.
const CANOPY_FLOOR: int = 13
## A plank standing on end leans this many degrees toward the gap it will fall
## across (the Fire G test room's drawbridge: -92 = 2 degrees past upright).
const DRAWBRIDGE_ROTATION: float = -92.0

var kit: LevelKit = null
## Where the next room of the run-in goes: its left edge on the map (px), and the
## map height (px) of the floor the last room's exit leads onto. The next room is
## placed so its entry floor is that same height: the two wall gaps line up.
var chain_left_px: float = 0.0
var chain_floor_px: float = 0.0
## The same for a wing that goes LEFT: the right edge (px) of the next room on the
## map, and the map height of the floor the last room's left exit leads onto.
var wing_right_px: float = 0.0
var wing_floor_px: float = 0.0


func _ready() -> void:
	kit = LevelKit.create(LEVEL_TITLE)
	var start_room: Room = _build_kindling()
	_build_spent()
	_build_fuse()
	_build_first_burst()
	_build_chain()
	_build_ash_walk()
	var hub: Room = _build_hub()
	_build_wildfire(hub)
	_build_ropes(hub)
	kit.set_start_room(start_room)
	for problem: String in kit.find_problems():
		print("[BuildFireLevel] PROBLEM: %s" % problem)
	var error: Error = kit.save(TARGET_PATH)
	print("[BuildFireLevel] %s %s" % ["Wrote" if error == OK else "FAILED to write", TARGET_PATH])
	get_tree().quit()


# --- Helpers -----------------------------------------------------------------------

## The next room of the run-in: `columns` x `rows` tiles, entered through a gap in
## its left wall onto the floor row `entry_floor`. It comes with its shell (see
## _fire_room); call _exit_right when its floors are painted.
func _chain_room(node_name: String, title: String, columns: int, rows: int, entry_floor: int, start_pips: int,
		has_entry: bool = true) -> Room:
	var map_px: Vector2 = Vector2(chain_left_px, chain_floor_px - entry_floor * TILE)
	var room: Room = _fire_room(node_name, title, map_px, columns, rows, 0, start_pips)
	if has_entry:
		kit.clear(room, 0, entry_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	chain_left_px += columns * TILE
	return room


## A Fire-only room in the emberwood backdrop (the wood: SURFACE), with its shell:
## a one-tile ceiling and two side walls. Floors are each room's own.
func _fire_room(node_name: String, title: String, map_px: Vector2, columns: int, rows: int, depth: int,
		start_pips: int) -> Room:
	# A one-screen room is 180 px tall: its 23rd row is half off screen.
	var height_px: float = SCREEN_SIZE.y if rows == SCREEN_ROWS else float(rows * TILE)
	var room: Room = kit.add_room(node_name, title, map_px, Vector2(columns * TILE, height_px), depth)
	room.fire_allowed = true
	room.fire_start_pips = start_pips
	room.backdrop_theme = Backdrop.Look.EMBERWOOD
	room.backdrop_altitude = Backdrop.Altitude.SURFACE
	_ground(room, 0, 0, columns, 1)
	_ground(room, 0, 0, 1, rows)
	_ground(room, columns - 1, 0, 1, rows)
	return room


## Opens the gap in the room's right wall onto `exit_floor`, and remembers that
## floor's map height for the next room of the run-in.
func _exit_right(room: Room, exit_floor: int) -> void:
	var last_column: int = int(room.room_size.x / TILE) - 1
	kit.clear(room, last_column, exit_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	chain_floor_px = room.position.y + exit_floor * TILE


## The next room of a wing going LEFT: `columns` x `rows` tiles, entered through a
## gap in its RIGHT wall onto the floor row `entry_floor`, right of the last room.
## Call _exit_left when its floors are painted.
func _wing_room(node_name: String, title: String, columns: int, rows: int, entry_floor: int, start_pips: int) -> Room:
	var map_px: Vector2 = Vector2(wing_right_px - columns * TILE, wing_floor_px - entry_floor * TILE)
	var room: Room = _fire_room(node_name, title, map_px, columns, rows, 0, start_pips)
	kit.clear(room, columns - 1, entry_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	wing_right_px = map_px.x
	return room


## Opens the gap in the room's LEFT wall onto `exit_floor`, and remembers that
## floor's map height for the wing's next room.
func _exit_left(room: Room, exit_floor: int) -> void:
	kit.clear(room, 0, exit_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	wing_floor_px = room.position.y + exit_floor * TILE


func _ground(room: Room, column: int, row: int, width: int, height: int) -> void:
	kit.fill(room, &"ground", column, row, width, height)


## A brazier standing on `floor_row`, over the tile line left of `column` (it is
## 2 tiles wide, columns column-1 and column).
func _brazier(room: Room, node_name: String, column: int, floor_row: int) -> Node2D:
	return kit.place(room, &"brazier", node_name, LevelKit.corner(column, floor_row))


## A door filling a wall gap: its top-left at (column, top_row), opened by `switches`.
func _door(room: Room, node_name: String, column: int, top_row: int, switches: Array, all_switches: bool = false) -> Node2D:
	var door: Node2D = kit.place(room, &"door", node_name, LevelKit.corner(column, top_row),
		{&"door_size": DOOR_SIZE, &"link_mode": Door.LinkMode.ALL if all_switches else Door.LinkMode.ANY})
	kit.link(door, &"switches", switches)
	return door


## A fire diamond floating one tile over the floor row `floor_row` in `column`.
func _diamond(room: Room, node_name: String, column: int, floor_row: int) -> void:
	kit.place(room, &"fire_diamond", node_name, Vector2(column * TILE + TILE / 2.0, floor_row * TILE - TILE))


## A signpost standing on `floor_row`, its post on the left edge of `column`.
func _sign(room: Room, node_name: String, column: int, floor_row: int, text: String) -> void:
	kit.place(room, &"signpost", node_name, Vector2(column * TILE, floor_row * TILE), {&"text": text})


func _shard(room: Room, slot: int, column: int, row: int) -> void:
	kit.place(room, &"relic_shard", "RelicShard%d" % slot, LevelKit.corner(column, row), {&"slot": slot, &"element": FIRE})


# --- The run-in: the edge of the wood ------------------------------------------------

## Room1 "Kindling", 2 pips: the fireball. A wall closes the way on, with a door in
## its foot; the brazier that opens it stands on a shelf 9 rows over the floor, out
## of jumping reach (3.7): throw a fireball up at it (Q with Up and Right held, or
## hold Q to aim). The second pip is the spare for a miss. The golden feather hangs
## over a low step on the way.
## A shelf under a brazier starts right under it, never further left: a fireball
## thrown up at 45 degrees would hit a longer shelf's corner first.
func _build_kindling() -> Room:
	chain_floor_px = 18 * TILE
	var room: Room = _chain_room("Room1", "Kindling", 40, SCREEN_ROWS, 18, 2, false)
	_ground(room, 1, 18, 38, 5)
	_ground(room, 10, 16, 4, 2)                   # a low step: the feather hangs over it
	_ground(room, 24, 9, 4, 1)                    # the brazier's shelf
	_ground(room, 32, 1, 2, 13)                   # the wall, its door below (column 33 open behind it)
	var brazier: Node2D = _brazier(room, "Brazier", 25, 9)
	_door(room, "Door", 32, 14, [brazier])
	kit.set_spawn(room, 3, 17)
	_sign(room, "SignFireball", 5, 18, "Q: a fireball (arrows aim). Light the brazier.")
	kit.place(room, &"golden_feather", "GoldenFeather", LevelKit.corner(11, 12))
	_exit_right(room, 18)
	return room


## Room2 "Spent", ONE pip: pips run out. Two braziers, both needed (the door waits
## for ALL of them): one on the floor by the door (a fireball straight ahead), one
## high on a shelf (up and right, from about column 12). The fire diamond on the
## way is the second pip. A second throw before taking it fizzles.
func _build_spent() -> void:
	var room: Room = _chain_room("Room2", "Spent", 40, SCREEN_ROWS, 18, 1)
	_ground(room, 1, 18, 38, 5)
	_ground(room, 22, 8, 4, 1)                    # the high shelf
	_ground(room, 32, 1, 2, 13)
	var low: Node2D = _brazier(room, "BrazierLow", 29, 18)
	var high: Node2D = _brazier(room, "BrazierHigh", 23, 8)
	_door(room, "Door", 32, 14, [low, high], true)
	_diamond(room, "FireDiamond", 8, 18)
	kit.set_spawn(room, 2, 17)
	_sign(room, "SignPips", 4, 18, "Each fireball burns a pip. They don't come back.")
	_sign(room, "SignDiamond", 10, 18, "An orange diamond: one more pip.")
	_exit_right(room, 18)


## Room3 "The Fuse" (60 tiles: the camera scrolls), 1 pip: grass burns. A strip of
## grass 44 tiles long runs along the floor to the brazier at its far end, just
## short of the door's wall. One fireball into the grass in front of you lights it; the
## fire runs the whole way (about 15 s) and lights the brazier. Stand on the bare
## ground where you came in while it burns: burning grass kills. The ash it leaves
## never burns again, so the way on is safe once the fire has passed.
func _build_fuse() -> void:
	var room: Room = _chain_room("Room3", "The Fuse", 60, SCREEN_ROWS, 18, 1)
	_ground(room, 1, 18, 58, 5)
	kit.fill(room, &"grass", 6, 18, 44, 1)
	_ground(room, 50, 1, 2, 13)                   # the wall, past the brazier
	var brazier: Node2D = _brazier(room, "Brazier", 48, 18)
	_door(room, "Door", 50, 14, [brazier])
	kit.set_spawn(room, 2, 17)
	_sign(room, "SignGrass", 3, 18, "Burning grass kills. Light it and wait; ash won't burn.")
	_exit_right(room, 18)


## Room4 "First Burst", 3 pips: the flame jet. A 10-tile pit (a jump alone crosses
## 6): jump, then W with Right held (16 tiles). Nothing here kills: the pit is 4
## deep with a step back out. Past it, a ledge 8 rows high (a jump is 3.7, a burst
## from standing 11): W with no arrow goes straight up. The third pip is a spare.
func _build_first_burst() -> void:
	var room: Room = _chain_room("Room4", "First Burst", 40, SCREEN_ROWS, 18, 3)
	_ground(room, 1, 18, 38, 5)
	kit.clear(room, 13, 18, 10, 4)                # the pit: columns 13-22, its floor on row 22
	_ground(room, 13, 20, 2, 2)                   # the step out: 2 up, then 2 more to the floor
	_ground(room, 31, 10, 8, 8)                   # the ledge: its top on row 10
	kit.set_spawn(room, 2, 17)
	_sign(room, "SignJet", 5, 18, "W: a burst of flame. Jump, then W holding Right.")
	_sign(room, "SignUp", 26, 18, "W with no arrow held: straight up.")
	_exit_right(room, 10)


## Room5 "Chain" (31 rows), 2 pips: holding W chains bursts. The exit ledge is 16
## rows over the start floor and 12 tiles out, over a floor of spikes: one burst
## from a jump rises 11, two rise 26. Hold W (with Up, then Right) through the
## first burst and the next pip fires by itself. A fire diamond on the way up is
## the spare. The ledge floats: its underside bonks, so go up past it, then over.
func _build_chain() -> void:
	var room: Room = _chain_room("Room5", "Chain", 40, 31, 28, 2)
	_ground(room, 1, 28, 13, 3)                   # the start floor
	_ground(room, 14, 29, 25, 2)
	kit.spikes(room, 14, 28, 25)                  # spikes over the rest of the floor
	_ground(room, 25, 12, 14, 2)                  # the exit ledge: its top on row 12
	_diamond(room, "FireDiamond", 17, 20)
	kit.set_spawn(room, 2, 27)
	_sign(room, "SignChain", 4, 28, "Hold W: when a burst ends, the next pip fires. Let go to stop.")
	_exit_right(room, 12)


## Room6 "Ash Walk", 2 pips: the jet's flame lights what it touches, the grass under
## you too. The floor is grass up to a ledge 8 rows high: jet up off the grass and
## the fire starts behind you, running back along the floor you came over. Up on
## the ledge you're safe; don't drop back down until it has burnt out.
func _build_ash_walk() -> void:
	var room: Room = _chain_room("Room6", "Ash Walk", 40, SCREEN_ROWS, 18, 2)
	_ground(room, 1, 18, 38, 5)
	kit.fill(room, &"grass", 4, 18, 27, 1)
	_ground(room, 31, 10, 8, 8)                   # the ledge: its top on row 10
	kit.set_spawn(room, 2, 17)
	_sign(room, "SignScorch", 6, 18, "The jet lights the grass under you. Keep going up.")
	_exit_right(room, 10)


# --- The hub and what's behind it ----------------------------------------------------

## Room7 "Ember Hall", the hub: the inside of a great hollow tree, 40 x 50 tiles,
## 3 pips. Four Key lights stand on the floor over the depth gate. A zigzag of
## girders climbs the middle (each 3 rows over the last: a plain jump). From it,
## the four wing ledges are a jet away (9 to 13 tiles across): the left wall's
## middle Wildfire (open: its gap leads left into the wing), the right wall's
## middle Ropes and Weights, top right Sky of Embers. Wild Things goes DOWN into
## the roots, from the floor's right end. The closed ones say so on a sign. Each
## wing comes home through a teleport exit of its color on the hub's floor.
## The Wildfire ledge is on row 28, not lower: below it, the run-in's last room
## lies right behind the hub's left wall.
func _build_hub() -> Room:
	var hub: Room = _chain_room("Room7", "Ember Hall", 40, 50, 46, 3)
	_ground(hub, 0, 0, 40, 2)                     # a thick ceiling
	_ground(hub, 1, 46, 38, 4)
	# The girders: centers alternate between columns 18 and 22, 3 rows apart.
	var girder_index: int = 0
	for row: int in range(42, 5, -3):
		var center_column: int = 18 if girder_index % 2 == 0 else 22
		kit.place(hub, &"metal_platform", "HubGirder%d" % (girder_index + 1), Vector2(center_column * TILE, row * TILE),
			{&"platform_width": GIRDER_WIDTH})
		girder_index += 1
	# [left column of the ledge, its floor row, the sign's column, the wing's name].
	var wing_ledges: Array = [
		[1, WILDFIRE_LEDGE_ROW, 2, "Wildfire"], [33, ROPES_LEDGE_ROW, 35, "Ropes and Weights"], [33, 7, 35, "Sky of Embers"],
	]
	for ledge: Array in wing_ledges:
		_ground(hub, ledge[0], ledge[1], 6, 2)
		if ledge[3] == "Wildfire":
			_sign(hub, "SignWildfire", ledge[2], ledge[1], "The Wildfire wing: the dry undergrowth.")
		elif ledge[3] == "Ropes and Weights":
			_sign(hub, "SignRopesandWeights", ledge[2], ledge[1], "The Ropes and Weights wing: the canopy.")
		else:
			_sign(hub, "Sign%s" % (ledge[3] as String).replace(" ", ""), ledge[2], ledge[1], "The %s wing. Not open yet." % ledge[3])
	kit.clear(hub, 0, WILDFIRE_LEDGE_ROW - GAP_HEIGHT, 1, GAP_HEIGHT)
	kit.place(hub, &"teleport_exit", "WildfireExit", Vector2(8 * TILE, 46 * TILE - TeleportDoor.DOOR_SIZE.y),
		{&"door_color": KEY_COLORS[0], &"is_exit": true})
	kit.clear(hub, 39, ROPES_LEDGE_ROW - GAP_HEIGHT, 1, GAP_HEIGHT)
	kit.place(hub, &"teleport_exit", "RopesExit", Vector2(10 * TILE, 46 * TILE - TeleportDoor.DOOR_SIZE.y),
		{&"door_color": KEY_COLORS[1], &"is_exit": true})
	_sign(hub, "SignWildThings", 34, 46, "The Wild Things wing, down in the roots. Not open yet.")
	_sign(hub, "SignHall", 4, 46, "Four keys, four lights. The gate leads to the crater.")
	var lights: Array = []
	var light_columns: Array[int] = [14, 16, 24, 26]
	for index: int in KEY_COLORS.size():
		lights.append(kit.place(hub, &"key_light", "KeyLight%d" % (index + 1),
			LevelKit.corner(light_columns[index], 46), {&"key_color": KEY_COLORS[index]}))
	kit.depth_gate(hub, "DepthGate", 19, 46)
	kit.set_spawn(hub, 2, 45)

	# The sanctum: one depth behind the hub's bottom screen, so the two gates share
	# a map spot. The Grand door waits for all four Key lights; the Goal is behind it.
	# Off the path, a jet up to a shelf at the left of the floor: relic shard 4.
	var rows_above: int = 50 - SCREEN_ROWS
	var floor_row: int = 46 - rows_above
	var sanctum: Room = _fire_room("RoomSanctum", "The Sanctum", hub.position + Vector2(0.0, rows_above * TILE),
		40, SCREEN_ROWS, 1, 2)
	_ground(sanctum, 1, floor_row, 38, SCREEN_ROWS - floor_row)
	kit.depth_gate(sanctum, "DepthGate", 19, floor_row)
	var door_rows: int = int(GRAND_DOOR_SIZE.y / TILE)
	_ground(sanctum, 28, 1, 2, floor_row - door_rows - 1)  # the wall over the Grand door
	var door: Node2D = kit.place(sanctum, &"grand_door", "GrandDoor", Vector2(28 * TILE, (floor_row - door_rows) * TILE),
		{&"door_size": GRAND_DOOR_SIZE, &"link_mode": Door.LinkMode.ALL})
	kit.link(door, &"switches", lights)
	kit.place(sanctum, &"goal", "Goal", Vector2(33 * TILE, floor_row * TILE - GOAL_SIZE.y), {&"goal_size": GOAL_SIZE})
	_ground(sanctum, 8, floor_row - 9, 5, 1)      # the shard's shelf, 9 rows up: a jet
	_shard(sanctum, 4, 9, floor_row - 11)
	kit.set_spawn(sanctum, 16, floor_row - 1)
	return hub


# --- Wing 1: Wildfire, the dry undergrowth -------------------------------------------

func _build_wildfire(hub: Room) -> void:
	wing_right_px = hub.position.x
	wing_floor_px = hub.position.y + WILDFIRE_LEDGE_ROW * TILE
	_build_dry_grass()
	_build_undergrowth()
	_build_overgrown()
	_build_wildfire_exam()


## WildRoom1 "Dry Grass", 2 pips: fire runs along grass, up its walls and over its
## tops. The door's brazier sits in a closed stone shrine (roof and both sides) on a
## grass mound 6 rows high: no fireball can reach it, only a fire climbing the
## mound. Light the grass floor from the stone you came in on and wait there; then
## a jet over the burnt mound (9 rows with the shrine) to the door.
func _build_dry_grass() -> void:
	var room: Room = _wing_room("WildRoom1", "Dry Grass", 40, SCREEN_ROWS, 18, 2)
	_ground(room, 1, 18, 38, 5)
	kit.fill(room, &"grass", 1, 18, 29, 1)        # the grass floor; stone from column 30
	kit.fill(room, &"grass", 18, 12, 4, 6)        # the mound: columns 18-21, rows 12-17
	_ground(room, 17, 9, 6, 1)                    # the shrine's roof
	_ground(room, 17, 10, 1, 2)                   # ...and its two sides
	_ground(room, 22, 10, 1, 2)
	var brazier: Node2D = _brazier(room, "Brazier", 20, 12)
	_exit_left(room, 18)
	_door(room, "Door", 0, 14, [brazier])
	kit.set_spawn(room, 37, 17)
	_sign(room, "SignClimb", 33, 18, "Fire climbs grass. Light the floor and let it climb.")


## WildRoom2 "Undergrowth", 3 pips: thicket burns right through and crumbles to
## nothing. On the upper floor (row 13) a thicket wall blocks the way; past it the
## floor is a dead end, but six tiles of it are thicket: burnt, they drop you to the
## lower corridor (floor row 21) and its exit. Burning thicket kills: burn it from
## the stone beside it, never from on top.
func _build_undergrowth() -> void:
	var room: Room = _wing_room("WildRoom2", "Undergrowth", 40, SCREEN_ROWS, 13, 3)
	_ground(room, 1, 13, 38, 2)                   # the upper floor
	kit.fill(room, &"thicket", 4, 13, 6, 2)       # its thicket patch: columns 4-9
	kit.fill(room, &"thicket", 22, 1, 3, 12)      # the thicket wall: columns 22-24
	_ground(room, 1, 21, 38, 2)                   # the lower corridor's floor
	_exit_left(room, 21)
	kit.set_spawn(room, 37, 12)
	_sign(room, "SignThicket", 31, 13, "Thicket burns away. Light it from the side, not on top.")


## WildRoom3 "Overgrown", 2 pips: covers. The room looks closed: its left wall is a
## thicket COVER (roots hang from it: the tell) over the way out; fire on any of it
## burns the whole cover at once. Off the path, a grass cover in the floor hides a
## small chamber with relic shard 2 (the secret), 3 rows deep: a jump back out.
func _build_overgrown() -> void:
	var room: Room = _wing_room("WildRoom3", "Overgrown", 40, SCREEN_ROWS, 18, 2)
	_ground(room, 1, 18, 38, 5)
	_ground(room, 1, 1, 5, 13)                    # the left wall over the cover
	kit.fill(room, &"overgrown_thicket", 1, 14, 5, 4)
	kit.fill(room, &"overgrown_grass", 20, 18, 4, 1)  # the floor cover over the chamber
	kit.fill(room, &"hidden_chamber", 18, 19, 8, 2)   # the chamber: rows 19-20, floor row 21
	room.earth_allowed = false                    # the chamber brush turns Earth on: not here
	_shard(room, 2, 21, 19)
	_exit_left(room, 18)
	kit.set_spawn(room, 37, 17)
	_sign(room, "SignCover", 33, 18, "That ground is only roots. Fire takes it all at once.")


## WildRoom4 "Wildfire", the wing's exam (80 tiles), 4 pips and a fire diamond.
## Right to left on the upper floor (row 13): the stone you come in on; a grass
## floor with a thicket wall standing on it (burn the wall and the grass goes up
## both ways: wait on the stone); a 12-tile spike pit (jump + burst); a stone rim
## with the diamond; a thicket patch in the floor: burnt, it drops you to the lower
## level, where a thicket cover stands in front of the red Key orb and the teleport door home.
func _build_wildfire_exam() -> void:
	var room: Room = _wing_room("WildRoom4", "Wildfire", 80, SCREEN_ROWS, 13, 4)
	_ground(room, 1, 13, 78, 2)                   # the upper floor
	_ground(room, 50, 15, 29, 8)                  # solid under its right part
	kit.fill(room, &"grass", 50, 13, 18, 1)       # grass: columns 50-67
	kit.fill(room, &"thicket", 56, 1, 3, 12)      # the thicket wall: columns 56-58
	kit.clear(room, 38, 13, 12, 8)                # the pit: columns 38-49, down to row 20
	_ground(room, 1, 21, 49, 2)                   # the lower floor
	kit.spikes(room, 38, 20, 12)
	_diamond(room, "FireDiamond", 34, 13)
	kit.fill(room, &"thicket", 24, 13, 6, 2)      # the floor's thicket patch: columns 24-29
	kit.fill(room, &"overgrown_thicket", 12, 15, 3, 6)  # the cover: columns 12-14, rows 15-20
	kit.place(room, &"key_orb", "KeyOrb", LevelKit.corner(5, 19), {&"key_color": KEY_COLORS[0]})
	kit.place(room, &"teleport_door", "WayHome", Vector2(8 * TILE, 21 * TILE - TeleportDoor.DOOR_SIZE.y),
		{&"door_color": KEY_COLORS[0]})
	kit.set_spawn(room, 77, 12)
	_sign(room, "SignWildfire", 71, 13, "Everything here burns. Light it, wait, then go.")


# --- Wing 2: Ropes and Weights, the canopy ------------------------------------------

func _build_ropes(hub: Room) -> void:
	chain_left_px = hub.position.x + hub.room_size.x
	chain_floor_px = hub.position.y + ROPES_LEDGE_ROW * TILE
	_build_drawbridge()
	_build_dead_weight()
	_build_lowered()
	_build_counterweights()


## A canopy room of the chain going right: entered on CANOPY_FLOOR, nothing under its
## ledges (the room's bottom is a pit).
func _canopy_room(node_name: String, title: String, columns: int, start_pips: int) -> Room:
	var room: Room = _chain_room(node_name, title, columns, SCREEN_ROWS, CANOPY_FLOOR, start_pips)
	# The shell's side walls only reach down to the ledges: under them is open sky,
	# and a side wall hanging down there would only look like somewhere to stand.
	kit.clear(room, 0, CANOPY_FLOOR + 2, 1, SCREEN_ROWS - CANOPY_FLOOR - 2)
	kit.clear(room, columns - 1, CANOPY_FLOOR + 2, 1, SCREEN_ROWS - CANOPY_FLOOR - 2)
	return room


## A ledge of the canopy: columns `column` to `column + width - 1`, two rows thick.
func _ledge(room: Room, column: int, width: int) -> void:
	_ground(room, column, CANOPY_FLOOR, width, 2)


## A notch one tile deep in the top of the NEAR rim of a gap a plank will fall
## across (columns `column` and `column + 1`). A plank lying flat on both rims has
## its top 4 px over the floor, and planks are one-way: you'd walk in under its
## edge and fall. With its near end in the notch it lies as a gentle slope instead,
## 4 px under the ledge at the near end and over it at the far end: you walk down
## onto it and off it again without a hop.
func _notch(room: Room, column: int) -> void:
	kit.clear(room, column, CANOPY_FLOOR, 2, 1)


## A vine from the ceiling at `anchor_px` down to `end_px` (room px).
func _vine(room: Room, node_name: String, anchor_px: Vector2, end_px: Vector2) -> Node2D:
	return kit.place(room, &"vine", node_name, anchor_px, {&"end_point": end_px - anchor_px})


## A drawbridge: a plank `length` px long standing on end on the rim at x `rim_px`
## (the gap is to its left), leaning a little toward the gap, held up by a vine
## from its top to the ceiling `vine_reach` px to its right.
func _drawbridge(room: Room, node_name: String, rim_px: float, length: float, vine_reach: float) -> void:
	var floor_px: float = CANOPY_FLOOR * TILE
	# Its middle sits 5 px past the rim, half its length up (the Fire G test room's).
	var plank: Node2D = kit.place(room, &"hanging_platform", node_name, Vector2(rim_px + 5.0, floor_px - length / 2.0),
		{&"platform_width": length, &"rotation_degrees": DRAWBRIDGE_ROTATION})
	# Its top end: leaning 2 degrees left moves it 1.5 px left of the middle per 44 px.
	var top: Vector2 = Vector2(rim_px + 5.0 - length / 2.0 * sin(deg_to_rad(2.0)), floor_px - length)
	var vine: Node2D = _vine(room, node_name + "Vine", Vector2(top.x + vine_reach, TILE), top)
	kit.link(plank, &"vines", [vine])


## A metal crate hanging from the ceiling on a vine, its bottom `hang_px` over the
## floor at x `x_px`, over a pressure plate there. Returns the plate.
## The plate lies in a slot one tile deep and three wide, cut into the ledge: the
## crate drops into it, so it can't be pushed off the plate (that would shut the
## door again), and its top is only a tile over the floor: a hop, not a wall.
func _hung_weight(room: Room, node_name: String, x_px: float, hang_px: float) -> Node2D:
	var floor_px: float = CANOPY_FLOOR * TILE
	kit.clear(room, int(x_px / TILE) - 1, CANOPY_FLOOR, 3, 1)
	var plate: Node2D = kit.place(room, &"pressure_plate", node_name + "Plate", Vector2(x_px, floor_px + TILE),
		{&"plate_width": 24.0})
	var crate_bottom: float = floor_px - hang_px
	var vine: Node2D = _vine(room, node_name + "Vine", Vector2(x_px, TILE), Vector2(x_px, crate_bottom - 16.0))
	var crate: Node2D = kit.place(room, &"crate", node_name, Vector2(x_px, crate_bottom), {&"is_metal": true})
	kit.link(crate, &"hung_from", [vine])
	return plate


## A plank grown over with vines, `width` px wide, its middle at (`middle_x_px`,
## `middle_y_px`), hung by a vine at each end straight up to the ceiling.
func _lowered_plank(room: Room, node_name: String, middle_x_px: float, middle_y_px: float, width: float) -> void:
	var plank: Node2D = kit.place(room, &"hanging_platform", node_name, Vector2(middle_x_px, middle_y_px),
		{&"platform_width": width, &"vine_covered": true})
	var vines: Array = []
	for side: float in [-1.0, 1.0]:
		# Each vine is tied 4 px in from its end of the plank (Fire G's swinging plank).
		var tie_x: float = middle_x_px + side * (width / 2.0 - 4.0)
		vines.append(_vine(room, "%sVine%s" % [node_name, "Left" if side < 0.0 else "Right"], Vector2(tie_x, TILE),
			Vector2(tie_x, middle_y_px)))
	kit.link(plank, &"vines", vines)


## RopeRoom1 "Drawbridge", ONE pip: a vine holds a plank on end on the far rim of an
## 8-tile gap (a jump crosses 6). Burn the vine (up and right, over the plank's top)
## and the plank topples across. With one pip, there's none left to jet over.
func _build_drawbridge() -> void:
	var room: Room = _canopy_room("RopeRoom1", "Drawbridge", 40, 1)
	_ledge(room, 1, 13)                           # columns 1-13; the gap is 14-21
	_ledge(room, 22, 17)
	_drawbridge(room, "Drawbridge", 22 * TILE, 80.0, 28.0)
	_notch(room, 12)                              # it falls with its near end on columns 12-13
	_exit_right(room, CANOPY_FLOOR)
	kit.set_spawn(room, 2, CANOPY_FLOOR - 1)
	_sign(room, "SignDrawbridge", 5, CANOPY_FLOOR, "Burn the vine: the plank falls across.")


## RopeRoom2 "Dead Weight", 2 pips: a metal crate (metal never burns) hangs on a vine
## 4 rows over a pressure plate; the plate opens the door. Cut the vine and the
## crate's weight holds the door open. An 8-tile gap first: the second pip is the
## jet over it. Relic shard 3 waits on a ledge 4 rows over the floor: a jump from
## the fallen crate's top (a tile up, in its slot) reaches it, a jump from the floor
## (3.7 rows) doesn't, and a jet up would leave no pip for the gap or the vine.
func _build_dead_weight() -> void:
	var room: Room = _canopy_room("RopeRoom2", "Dead Weight", 40, 2)
	_ledge(room, 1, 10)                           # columns 1-10; the gap is 11-18
	_ledge(room, 19, 20)
	var plate: Node2D = _hung_weight(room, "Weight", 26 * TILE + 4.0, 32.0)
	_ground(room, 33, 1, 2, CANOPY_FLOOR - GAP_HEIGHT - 1)  # the wall, its door below
	_door(room, "Door", 33, CANOPY_FLOOR - GAP_HEIGHT, [plate])
	_ground(room, 29, CANOPY_FLOOR - 4, 4, 1)     # the shard's ledge: 4 rows up, out to the wall
	_shard(room, 3, 30, CANOPY_FLOOR - 6)
	_exit_right(room, CANOPY_FLOOR)
	kit.set_spawn(room, 2, CANOPY_FLOOR - 1)
	_sign(room, "SignWeight", 4, CANOPY_FLOOR, "Metal doesn't burn. Cut what holds it.")


## RopeRoom3 "Lowered", ONE pip: a plank grown over with vines hangs 6 rows over a
## 10-tile gap, 13 tiles wide. A fireball on the PLANK (not a vine) burns every vine
## at once, so it drops level and lands across the rims. Burn just one vine and it
## swings away instead: R.
func _build_lowered() -> void:
	var room: Room = _canopy_room("RopeRoom3", "Lowered", 40, 1)
	_ledge(room, 1, 14)                           # columns 1-14; the gap is 15-24
	_ledge(room, 25, 14)
	_lowered_plank(room, "Bridge", 20 * TILE, (CANOPY_FLOOR - 6) * TILE, 104.0)
	_notch(room, 13)                              # its near end lands on columns 13-14
	_exit_right(room, CANOPY_FLOOR)
	kit.set_spawn(room, 2, CANOPY_FLOOR - 1)
	_sign(room, "SignLowered", 4, CANOPY_FLOOR, "Burn the plank itself: all its vines let go.")


## RopeRoom4 "Counterweights", the wing's exam (60 tiles), 3 pips and a fire
## diamond: a drawbridge over an 8-tile gap, a hung metal weight over the plate of
## the door, and a vine-grown plank over a 12-tile gap. Three fires for three
## pips; the diamond is the spare (or a jet in place of a fire). The orange Key
## orb and the teleport door home are past the last gap.
func _build_counterweights() -> void:
	var room: Room = _canopy_room("RopeRoom4", "Counterweights", 60, 3)
	_ledge(room, 1, 8)                            # columns 1-8; gap A is 9-16
	_ledge(room, 17, 18)                          # columns 17-34; gap B is 35-46
	_ledge(room, 47, 12)
	_drawbridge(room, "Drawbridge", 17 * TILE, 80.0, 28.0)
	_notch(room, 7)                               # it falls with its near end on columns 7-8
	_diamond(room, "FireDiamond", 20, CANOPY_FLOOR)
	var plate: Node2D = _hung_weight(room, "Weight", 26 * TILE + 4.0, 32.0)
	_ground(room, 32, 1, 2, CANOPY_FLOOR - GAP_HEIGHT - 1)
	_door(room, "Door", 32, CANOPY_FLOOR - GAP_HEIGHT, [plate])
	_lowered_plank(room, "Bridge", 41 * TILE, (CANOPY_FLOOR - 6) * TILE, 120.0)
	_notch(room, 33)                              # its near end lands on columns 33-34
	kit.place(room, &"key_orb", "KeyOrb", LevelKit.corner(51, CANOPY_FLOOR - 2), {&"key_color": KEY_COLORS[1]})
	kit.place(room, &"teleport_door", "WayHome", Vector2(55 * TILE, CANOPY_FLOOR * TILE - TeleportDoor.DOOR_SIZE.y),
		{&"door_color": KEY_COLORS[1]})
	kit.set_spawn(room, 2, CANOPY_FLOOR - 1)
	_sign(room, "SignCounterweights", 4, CANOPY_FLOOR, "Three fires, three pips. Choose where they go.")


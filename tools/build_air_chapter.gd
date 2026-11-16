extends Node
## tools/build_air_chapter.gd: writes "Chapter 1 - Air: The Windward Court", the
## Air level that comes right after "Chapter 0 - Basics". Planned with the developer
## (16 Nov 2026) by LEVEL_DESIGN_GUIDE.md: a run-in of tutorial rooms, a hub with five
## Key lights, five themed wings that each end in a Key orb, and the Grand door.
## The look (stage 2): the HIGHLANDS backdrop, a green valley at midday (meadows for
## the first rooms, then the hills seen from floating platforms, the cliffs high up),
## grass on every floor, open voids under the islands, a leaf pile wherever a gust
## is taught so the wind shows.
##
## BUILT SO FAR (stages 1-2 of the plan):
##   Act 1 "First Breath", six small rooms, each teaching one Air move:
##     Room1 Open Air        glide
##     Room2 The Long Drift  breath runs out; a wind crystal refills it
##     Room3 Lift            updrafts (+ a fake wall to RoomSecretLift, a relic shard)
##     Room4 Second Wind     the down-gust as a second jump; dead air
##     Room5 Kickback        the side-gust's recoil; a gust diamond
##     Room6 Still Air       the gust as an air brake
##   Room7 The Windward Court (the hub): five Key lights, the depth gate, an updraft
##     as the elevator, and five ledges where the wings will open.
##   RoomSanctum, one depth behind the hub: the Grand door and the Goal.
## STILL TO COME: the wings (Currents, Gust-work, Slipstream, Wildfire, Storm
## Watch), their Key orbs, the Summit, and relic slots 2 and 3. Until then the Grand door stays shut
## and find_problems() reports the unfinished relic.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_air_chapter.tscn
## It OVERWRITES TARGET_PATH: once that level is edited in the editor, stop running it.
##
## Units: tiles (8 px), (column, row) from a room's top-left tile.
## Reach numbers the rooms are sized by (LEVEL_DESIGN_GUIDE.md §6), MEASURED with
## simulated keys on flat ground, landing at the height of the take-off:
##   jump 51 px across, 29 px up          glide 124 px across
##   down-gust 98 px across, 78 px up     gust left + glide 184 px across
## Every gap here is about 80% of the move it asks for, and wider than the move
## before it can cross. tests/built_levels_smoke_test (windward) replays them.

const TARGET_PATH: String = "res://levels/chapter_1_air_windward.tscn"
const LEVEL_TITLE: String = "Chapter 1 - Air: The Windward Court"
const TILE: int = LevelKit.TILE
const SCREEN_SIZE: Vector2 = Vector2(320, 180)
## Rows of a one-screen room (row 22 is the half row at the bottom).
const SCREEN_ROWS: int = 23
## A gap in a side wall is this many tiles tall, right above the floor it leads onto.
const GAP_HEIGHT: int = 4
## Updrafts are this wide (tools/build_rooms.gd room 3 uses the same).
const UPDRAFT_COLUMNS: int = 6
const UPDRAFT_STRENGTH: float = 60.0
const GRAND_DOOR_SIZE: Vector2 = Vector2(16, 64)
const GOAL_SIZE: Vector2 = Vector2(24, 32)
const AIR: RelicShard.Element = RelicShard.Element.AIR
## The wings, from the hub's lowest ledge to its highest, and their Key colors
## (the hub's Key lights stand in this order, left to right).
const WINGS: Array[String] = ["Currents", "Gust-work", "Slipstream", "Wildfire", "Storm Watch"]
const KEY_COLORS: Array[KeyColors.Name] = [
	KeyColors.Name.BLUE, KeyColors.Name.ORANGE, KeyColors.Name.YELLOW, KeyColors.Name.RED, KeyColors.Name.GREEN,
]

var kit: LevelKit = null
## Where the next room of the run-in goes: its left edge on the map (px), and the
## map height (px) of the floor the last room's exit leads onto. The next room is
## placed so its entry floor is that same height: the two wall gaps line up.
var chain_left_px: float = 0.0
var chain_floor_px: float = 0.0


func _ready() -> void:
	kit = LevelKit.create(LEVEL_TITLE)
	var start_room: Room = _build_open_air()
	_build_long_drift()
	_build_lift()
	_build_second_wind()
	_build_kickback()
	_build_still_air()
	_build_hub()
	kit.set_start_room(start_room)
	for problem: String in kit.find_problems():
		print("[BuildAirChapter] PROBLEM: %s" % problem)
	var error: Error = kit.save(TARGET_PATH)
	print("[BuildAirChapter] %s %s" % ["Wrote" if error == OK else "FAILED to write", TARGET_PATH])
	get_tree().quit()


# --- Helpers -----------------------------------------------------------------------

## The next room of the run-in: `columns` x `rows` tiles, entered through a gap in
## its left wall onto the floor row `entry_floor`. Air only, highlands backdrop at
## `altitude`.
## It comes with its shell (see _shell); call _exit_right when its floors are painted.
func _chain_room(node_name: String, title: String, columns: int, rows: int, entry_floor: int,
		altitude: Backdrop.Altitude, has_entry: bool = true) -> Room:
	var map_px: Vector2 = Vector2(chain_left_px, chain_floor_px - entry_floor * TILE)
	var room: Room = _air_room(node_name, title, map_px, columns, rows, 0, altitude)
	if has_entry:
		kit.clear(room, 0, entry_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	chain_left_px += columns * TILE
	return room


## An Air-only room with its shell, anywhere on the map, in the highlands look at
## `altitude` (set by hand: AUTO would go by height, and the meadows are a choice).
func _air_room(node_name: String, title: String, map_px: Vector2, columns: int, rows: int, depth: int,
		altitude: Backdrop.Altitude) -> Room:
	# A one-screen room is 180 px tall: its 23rd row is half off screen.
	var height_px: float = SCREEN_SIZE.y if rows == SCREEN_ROWS else float(rows * TILE)
	var room: Room = kit.add_room(node_name, title, map_px, Vector2(columns * TILE, height_px), depth)
	room.air_allowed = true
	room.backdrop_theme = Backdrop.Look.HIGHLANDS
	room.backdrop_altitude = altitude
	_shell(room, columns, rows)
	return room


## A room's shell: a one-tile ceiling and two side walls. Floors are each room's own.
func _shell(room: Room, columns: int, rows: int) -> void:
	_ground(room, 0, 0, columns, 1)
	_ground(room, 0, 0, 1, rows)
	_ground(room, columns - 1, 0, 1, rows)


## Opens the gap in the room's right wall onto `exit_floor`, and remembers that
## floor's map height for the next room of the run-in.
func _exit_right(room: Room, exit_floor: int) -> void:
	var last_column: int = int(room.room_size.x / TILE) - 1
	kit.clear(room, last_column, exit_floor - GAP_HEIGHT, 1, GAP_HEIGHT)
	chain_floor_px = room.position.y + exit_floor * TILE


func _ground(room: Room, column: int, row: int, width: int, height: int) -> void:
	kit.fill(room, &"ground", column, row, width, height)


## Grass: every floor, ledge and island you stand on (the shells stay rock).
func _grass(room: Room, column: int, row: int, width: int, height: int) -> void:
	kit.fill(room, &"grass", column, row, width, height)


## A leaf pile lying on `floor_row` from `column`: where a gust is taught, so the
## wind shows.
func _leaves(room: Room, node_name: String, column: int, floor_row: int) -> void:
	kit.place(room, &"leaf_pile", node_name, Vector2(column * TILE, floor_row * TILE))


## A spike pit cut into the ground: `depth` rows of open air from `top_row`, spikes
## on its bottom row.
func _spike_pit(room: Room, column: int, width: int, top_row: int, depth: int) -> void:
	kit.clear(room, column, top_row, width, depth)
	kit.spikes(room, column, top_row + depth - 1, width)


## A signpost standing on `floor_row`, its post on the left edge of `column`.
func _sign(room: Room, node_name: String, column: int, floor_row: int, text: String) -> void:
	kit.place(room, &"signpost", node_name, Vector2(column * TILE, floor_row * TILE), {&"text": text})


## An updraft (a WindZone blowing up) UPDRAFT_COLUMNS wide from `column`, filling
## the rows `top_row` to `bottom_row` (both inside it). Glide in it to rise.
func _updraft(room: Room, node_name: String, column: int, top_row: int, bottom_row: int) -> void:
	kit.place(room, &"wind_zone", node_name, Vector2(column * TILE, top_row * TILE), {
		&"zone_size": Vector2(UPDRAFT_COLUMNS * TILE, (bottom_row - top_row + 1) * TILE),
		&"wind_direction": Vector2.UP, &"wind_strength": UPDRAFT_STRENGTH,
	})


## Dead air (a NoGlideZone) over a rectangle of tiles: no gliding inside.
func _dead_air(room: Room, node_name: String, column: int, row: int, width: int, height: int) -> void:
	kit.place(room, &"no_glide_zone", node_name, Vector2(column * TILE, row * TILE),
		{&"zone_size": Vector2(width * TILE, height * TILE)})


func _shard(room: Room, slot: int, column: int, row: int) -> void:
	kit.place(room, &"relic_shard", "RelicShard%d" % slot, LevelKit.corner(column, row), {&"slot": slot, &"element": AIR})


# --- Act 1: First Breath -----------------------------------------------------------

## Room1 "Open Air": the glide. A 12-tile gap (a jump alone crosses 7) with NO
## spikes: the pit is 5 tiles deep with a step back out on the left, so a miss only
## costs the climb. The golden feather hangs in the glide's path.
func _build_open_air() -> Room:
	chain_floor_px = 15 * TILE
	var room: Room = _chain_room("Room1", "Open Air", 40, SCREEN_ROWS, 15, Backdrop.Altitude.UNDERGROUND, false)
	_grass(room, 1, 15, 38, 8)
	kit.clear(room, 13, 15, 12, 5)      # the pit: columns 13-24, its floor on row 20
	_grass(room, 13, 18, 3, 2)          # the step out: 2 tiles up from the pit, 3 more to the floor
	kit.set_spawn(room, 2, 14)
	_sign(room, "SignGlide", 9, 15, "Jump, then press Jump again in the air and hold it: you glide.")
	kit.place(room, &"golden_feather", "GoldenFeather", LevelKit.corner(19, 11))
	_exit_right(room, 15)
	return room


## Room2 "The Long Drift" (60 tiles: the camera scrolls): breath. Two spike pits,
## each launched from a pillar 3 tiles high. The first is 14 tiles: a plain glide.
## The second is 26: breath runs out about two thirds across, so the wind crystal
## 100 px in (where a glide from the pillar's edge passes) has to be taken. The
## landing is 2 tiles lower than the first floor, which is what makes the far side
## reachable after the refill (108 px to go, 135 px of glide: 80%).
func _build_long_drift() -> void:
	var room: Room = _chain_room("Room2", "The Long Drift", 60, SCREEN_ROWS, 18, Backdrop.Altitude.UNDERGROUND)
	_grass(room, 1, 18, 58, 5)
	_grass(room, 4, 15, 4, 3)           # pillar A
	_spike_pit(room, 8, 14, 18, 3)
	_grass(room, 26, 15, 4, 3)          # pillar B
	_spike_pit(room, 30, 26, 18, 3)
	kit.clear(room, 56, 18, 3, 2)       # the low landing: its floor on row 20
	kit.place(room, &"wind_crystal", "WindCrystal", Vector2(30 * TILE + 100, 106))
	kit.set_spawn(room, 1, 17)
	_sign(room, "SignBreath", 3, 18, "Gliding uses your breath: the bar over your head. A wind crystal fills it again.")
	_exit_right(room, 20)


## Room3 "Lift" (two screens tall): updrafts. One lift up to a ledge, a hop into a
## second lift, out at the top right. Nothing here kills: a fall lands on the floor
## (the one room past the meadows that keeps a floor: the first updraft is a lesson).
## The first lift goes higher than the ledge needs. At its top a one-tile lip sticks
## out of the left wall, under a FAKE WALL: through it, RoomSecretLift.
func _build_lift() -> void:
	var room: Room = _chain_room("Room3", "Lift", 40, 46, 43, Backdrop.Altitude.SURFACE)
	_grass(room, 1, 43, 38, 3)
	_ground(room, 1, 10, 4, 11)                   # the thick left wall the secret is in
	kit.fill(room, &"hidden_chamber", 0, 15, 5, 3)  # the fake wall: rows 15-17, out through the edge
	room.earth_allowed = false                    # the chamber brush turns Earth on: not in this level
	_ground(room, 5, 18, 1, 1)                    # the lip to stand on in front of it
	_updraft(room, "UpdraftLow", 6, 13, 42)
	_grass(room, 14, 24, 9, 2)                    # the island between the lifts
	_updraft(room, "UpdraftHigh", 26, 4, 30)
	_grass(room, 33, 8, 6, 2)                     # the exit ledge
	kit.set_spawn(room, 2, 42)
	_sign(room, "SignUpdraft", 4, 43, "Rising wind lifts a glider. Glide into it and hold on.")
	_exit_right(room, 8)

	# Behind the fake wall: a glide over spikes to relic shard 1, and the same way back.
	var secret: Room = _air_room("RoomSecretLift", "Behind the Lift", room.position - Vector2(SCREEN_SIZE.x, 0.0), 40, SCREEN_ROWS, 0,
		Backdrop.Altitude.SURFACE)
	_grass(secret, 1, 18, 38, 5)
	_spike_pit(secret, 12, 12, 18, 3)
	kit.clear(secret, 39, 15, 1, 3)               # the opening the fake wall leads to
	kit.set_spawn(secret, 36, 17)
	_shard(secret, 1, 5, 16)


## Room4 "Second Wind": the down-gust. A floating island 8 tiles above the floor,
## starting 1 tile past its end (void under both: an island over the floor's end
## would catch your head before the gust lifts you)
## (a jump is 3.5, a jump with a down-gust nearly 10), then a 9-tile gap of open
## void under dead air to a second island: no glide, and a plain jump crosses 6, so
## the same down-gust carries the jump across (12). A leaf pile lies where the
## first down-gust is tried, so it blows.
func _build_second_wind() -> void:
	var room: Room = _chain_room("Room4", "Second Wind", 40, 31, 28, Backdrop.Altitude.SURFACE)
	_grass(room, 1, 28, 13, 3)                    # the floor (columns 1-13)
	_grass(room, 14, 20, 7, 4)                    # island A (columns 14-20): its top on row 20
	_grass(room, 30, 20, 9, 4)                    # island B, past the void (columns 21-29)
	_dead_air(room, "DeadAir", 21, 1, 9, 30)
	_leaves(room, "LeafPile", 7, 28)
	kit.set_spawn(room, 2, 27)
	_sign(room, "SignDownGust", 4, 28, "In the air, hold Down and press Z: a gust under you is a second jump. One gust per jump.")
	_sign(room, "SignDeadAir", 15, 20, "Dead air: you can't glide in it. Gust across.")
	_exit_right(room, 20)


## Room5 "Kickback" (60 tiles): the recoil. An 18-tile gap of open void, too wide for a
## glide alone (15.5): gust LEFT to be thrown right, then glide (23). After it, a
## cliff 12 tiles high: one down-gust tops out under 10, so the gust diamond beside
## it (two gusts this airtime) is needed.
func _build_kickback() -> void:
	var room: Room = _chain_room("Room5", "Kickback", 60, 31, 24, Backdrop.Altitude.SURFACE)
	_grass(room, 1, 24, 7, 7)                     # the take-off
	_grass(room, 26, 24, 33, 7)                   # the far side, past the void (columns 8-25)
	_grass(room, 40, 12, 19, 12)                  # the cliff: its top on row 12
	_leaves(room, "LeafPile", 3, 24)
	# In a standing jump's path, 20 px from the cliff's face.
	kit.place(room, &"gust_diamond", "GustDiamond", Vector2(300, 166))
	kit.set_spawn(room, 2, 23)
	_sign(room, "SignRecoil", 4, 24, "A gust pushes you the other way. Jump, gust LEFT to fly right, then glide.")
	_sign(room, "SignDiamond", 33, 24, "A gust diamond: two gusts in one jump.")
	_exit_right(room, 12)


## Room6 "Still Air" (two screens tall, going DOWN to the hub): the air brake.
## A long drop through dead air, past two storm cloud decks. Each deck has a
## 4-tile hole; the second hole is 7 tiles to the right of the first, 9 rows lower.
## Falling at full speed there's time to drift about 3 tiles: a gust with no arrow
## (or a down-gust) stops the fall for long enough to line up.
func _build_still_air() -> void:
	var room: Room = _chain_room("Room6", "Still Air", 40, 46, 6, Backdrop.Altitude.SURFACE)
	_grass(room, 1, 6, 8, 2)                      # the ledge you walk in on
	kit.fill(room, &"storm_cloud", 1, 24, 9, 2)   # deck 1: its hole is columns 10-13
	kit.fill(room, &"storm_cloud", 14, 24, 25, 2)
	kit.fill(room, &"storm_cloud", 1, 35, 16, 2)  # deck 2: its hole is columns 17-20
	kit.fill(room, &"storm_cloud", 21, 35, 18, 2)
	_grass(room, 1, 42, 38, 4)
	_dead_air(room, "DeadAir", 1, 8, 38, 34)
	kit.set_spawn(room, 2, 5)
	_sign(room, "SignBrake", 4, 6, "Z with no arrow held: a blast all around that stops you in the air. Drop, then brake.")
	_exit_right(room, 42)


# --- The hub and what's behind it ----------------------------------------------------

## Room7 "The Windward Court": the hub, 40 x 60 tiles. Five Key lights and the depth
## gate stand on the floor; an updraft up the middle is the elevator. Five ledges,
## alternating sides from the lowest wing (Currents) to the highest (Storm Watch),
## are where the wings will open (their wall gaps are still closed; a sign on each
## says so). Riding the lift past the top ledge reaches an alcove in the ceiling
## with relic shard 4. Leaf piles on the floor show the gusts.
func _build_hub() -> void:
	var hub: Room = _chain_room("Room7", "The Windward Court", 40, 60, 56, Backdrop.Altitude.SURFACE)
	_ground(hub, 0, 0, 40, 4)                     # a thick ceiling, with the alcove cut into it
	kit.clear(hub, 18, 1, 4, 3)
	_grass(hub, 1, 56, 38, 4)
	_updraft(hub, "Lift", 17, 1, 55)
	# Each wing's ledge (WINGS order, lowest first): [left column, floor row, the
	# sign's column]. Left and right in turn, 9 rows apart.
	var wing_ledges: Array = [[1, 48, 3], [34, 39, 37], [1, 30, 3], [34, 21, 37], [1, 12, 3]]
	for wing_index: int in WINGS.size():
		var ledge: Array = wing_ledges[wing_index]
		_grass(hub, ledge[0], ledge[1], 5, 2)
		_sign(hub, "Sign%s" % WINGS[wing_index].replace(" ", "").replace("-", ""), ledge[2], ledge[1],
			"The %s wing. Not open yet." % WINGS[wing_index])
	_leaves(hub, "LeafPileLeft", 6, 56)
	_leaves(hub, "LeafPileRight", 30, 56)
	var lights: Array = []
	var light_columns: Array[int] = [11, 13, 15, 25, 27]
	for index: int in KEY_COLORS.size():
		lights.append(kit.place(hub, &"key_light", "KeyLight%d" % (index + 1),
			LevelKit.corner(light_columns[index], 56), {&"key_color": KEY_COLORS[index]}))
	kit.depth_gate(hub, "DepthGate", 19, 56)
	kit.set_spawn(hub, 2, 55)
	_shard(hub, 4, 20, 2)

	# The sanctum: one depth behind the hub's bottom screen, so the two gates share
	# a map spot. The Grand door waits for all five Key lights; the Goal is behind it.
	var rows_above: int = 60 - SCREEN_ROWS
	var floor_row: int = 56 - rows_above
	var sanctum: Room = _air_room("RoomSanctum", "The Sanctum", hub.position + Vector2(0.0, rows_above * TILE), 40, SCREEN_ROWS, 1,
		Backdrop.Altitude.SURFACE)
	_grass(sanctum, 1, floor_row, 38, SCREEN_ROWS - floor_row)
	kit.depth_gate(sanctum, "DepthGate", 19, floor_row)
	var door_rows: int = int(GRAND_DOOR_SIZE.y / TILE)
	_ground(sanctum, 28, 1, 2, floor_row - door_rows - 1)
	var door: Node2D = kit.place(sanctum, &"grand_door", "GrandDoor", Vector2(28 * TILE, (floor_row - door_rows) * TILE),
		{&"door_size": GRAND_DOOR_SIZE, &"link_mode": Door.LinkMode.ALL})
	kit.link(door, &"switches", lights)
	kit.place(sanctum, &"goal", "Goal", Vector2(33 * TILE, floor_row * TILE - GOAL_SIZE.y), {&"goal_size": GOAL_SIZE})
	kit.set_spawn(sanctum, 16, floor_row - 1)

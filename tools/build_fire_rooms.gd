extends "res://tools/build_earth_rooms.gd"
## tools/build_fire_rooms.gd — generator for the Fire chapter's test rooms.
##
## It EXTENDS the Earth room generator (tools/build_earth_rooms.gd, read its header):
## `extends "path"` inherits a script by its file path, so every helper there
## (_begin_room, _grass_frame, _grass, _gray, _spike_pit, _add, _finish_room ...)
## works here too, and Fire rooms get the same painted ground (GroundPainter) and
## grass blades as the Earth ones (Fire_bending.md §13). Only _ready() is replaced:
## overriding it without calling super() means the Earth rooms are NOT rebuilt.
##
## It writes (one test room per Fire stage, all in tests/fire_test_world.tscn):
##   - tests/rooms/room_fire_a.tscn   Stage F1 fire bar + fire diamonds (_build_room_fire_a)
##   - tests/rooms/room_fire_b.tscn   Stage F3 flame jet: gap, chain shaft, fuel route (_build_room_fire_b)
##   - tests/rooms/room_fire_c.tscn   Stage F4 fireball + braziers opening doors (_build_room_fire_c)
##   - tests/rooms/room_fire_d.tscn   Stage F5 burning grass: fuse, shelter, jet run (_build_room_fire_d)
##
## Ground: grass BURNS since Stage F5, so rooms are built of earth (never burns, still
## painted like grass's neighbour) and grass is only laid where a room wants fire to
## run. Rooms A-C were grass-framed before F5 and are earth-framed now, so a jet
## take-off doesn't set their floors alight.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_fire_rooms.tscn
## Running it again OVERWRITES the test rooms. Pass room names after `--` to build
## only those, e.g. `-- fire_b` (names: fire_a, fire_b, fire_c, fire_d).

const FIRE_DIAMOND_SCENE: PackedScene = preload("res://scenes/objects/fire/fire_diamond.tscn")
const BRAZIER_SCENE: PackedScene = preload("res://scenes/objects/fire/brazier.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/objects/door.tscn")


func _ready() -> void:
	log_prefix = "[BuildFireRooms]"
	# The tilesets already exist (the Earth generator made them); these only load them.
	_load_or_create_earth_tileset()
	_load_or_create_grass_tileset()
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if wanted.is_empty() or wanted.has("fire_a"):
		_build_room_fire_a()
	if wanted.is_empty() or wanted.has("fire_b"):
		_build_room_fire_b()
	if wanted.is_empty() or wanted.has("fire_c"):
		_build_room_fire_c()
	if wanted.is_empty() or wanted.has("fire_d"):
		_build_room_fire_d()
	print("[BuildFireRooms] Done.")
	get_tree().quit()


## Makes the room being built a Fire-only room (Air and Earth off) that starts the
## player with `start_pips` fire pips.
func _fire_only(start_pips: int) -> void:
	room.air_allowed = false
	room.earth_allowed = false
	room.fire_allowed = true
	room.fire_start_pips = start_pips


## The usual frame of a one-screen room in EARTH (grass burns since Stage F5):
## ceiling, side walls, 3-row floor body.
func _earth_frame() -> void:
	_earth(0, 0, 40, 1)
	_earth(0, 0, 1, 23)
	_earth(39, 0, 1, 23)
	_earth(0, 20, 40, 3)


## A fire diamond centered at `position_px`: `pip_amount` 1 = single, 2 = double.
func _fire_diamond(node_name: String, position_px: Vector2, pip_amount: int) -> void:
	_add(FIRE_DIAMOND_SCENE, node_name, position_px, {"pip_amount": pip_amount})


# --- Rooms -------------------------------------------------------------------------

## Fire test room A (Stage F1, the fire bar). Fire-only, starts with 2 pips. Left to right:
##   - two single diamonds and a double at walking height on the floor: walking
##     through all three gives 2 + 1 + 1 + 2 = 6, and the cap is 5, so one is lost
##   - a step and a ledge with a double diamond above it: you reach it with a full
##     bar, so it STAYS (a diamond is only used up when it adds a pip). Spend one
##     with W (a jet burst) and touch it again: now it's taken.
##   - a spike pit to die in: dying (or R) brings back the 2 starting pips and every
##     diamond.
func _build_room_fire_a() -> void:
	_begin_room("RoomFireA", "Fire A - Fire Bar",
		"Stage F1 test room. Fire-only, starts with 2 pips. Fire diamonds: single +1, double +2, single use until R. The cap is 5. W (flame jet) spends a pip. F1 shows the count. R or dying resets pips and diamonds.")
	_fire_only(2)
	_earth_frame()
	# Floor diamonds at walking height (the player's middle is ~5 px above the feet).
	_fire_diamond("FireDiamondSingle1", Vector2(88, 152), 1)
	_fire_diamond("FireDiamondSingle2", Vector2(120, 152), 1)
	_fire_diamond("FireDiamondDouble1", Vector2(152, 151), 2)
	# Step (2 tiles up) and ledge (5 tiles up), each hop under a full jump.
	_earth(20, 18, 2, 2)
	_earth(24, 15, 7, 1)
	_fire_diamond("FireDiamondDouble2", Vector2(220, 110), 2)
	# Spike pit near the right wall.
	_spike_pit("SpikePit", 33, 4)
	_finish_room(Vector2(24, 160), "res://tests/rooms/room_fire_a.tscn")


## A spike pit `width` tiles wide from `column` in a floor whose top row is
## `floor_row` (the 3-row floor of a taller room): two rows cut out, spikes on the
## bottom, gray rock under them. The same as _spike_pit, at any floor height.
func _spike_pit_at(node_name: String, column: int, width: int, floor_row: int) -> void:
	_open(column, floor_row, width, 2)
	_gray(column, floor_row + 2, width, 1)
	_spikes(node_name, column, floor_row + 1, width)


## Fire test room B (Stage F3, the flame jet). Fire-only, two screens tall
## (320×360), starts with 0 pips. Floor at row 42 (y 336).
##   1. The gap: a single fire diamond on the floor just before a 10-tile spike pit
##      (cols 13-22, 80 px). One burst steered right (or up-right from a running
##      jump) carries you over.
##   2. The shaft: on the far side, a double and a single diamond (3 pips), then a
##      gray wall on the left and a high ledge (row 14, 28 tiles = 224 px above the
##      floor) on the right. Hold W with no arrow: three chained bursts, each a
##      visible pump, then steer right onto the ledge.
##   3. The fuel route: from the ledge, one single diamond to start, then two more
##      singles hanging in the air to the left, each about one burst apart. Jet left
##      holding W: every burst runs into the next diamond, so the chain keeps going
##      to the far-left platform. Miss one and the chain sputters out.
func _build_room_fire_b() -> void:
	_begin_room("RoomFireB", "Fire B - Flame Jet",
		"Stage F3 test room. Fire-only, starts with 0 pips. W = jet burst (1 pip, steer with arrows, no arrow = up), hold W to chain, C cuts it short. Gap: grab the diamond, one burst crosses 10 tiles. Shaft: 3 pips, hold W to chain up to the ledge. Fuel route: jet left from the ledge through the floating diamonds to the far platform.",
		Vector2(320, 360))
	_fire_only(0)
	# Frame: ceiling, walls, 3-row floor (rows 42-44).
	_earth(0, 0, 40, 1)
	_earth(0, 0, 1, 45)
	_earth(39, 0, 1, 45)
	_earth(0, 42, 40, 3)

	# 1. The gap. Diamond at walking height (the player's middle is ~5 px above the feet).
	_fire_diamond("GapDiamond", Vector2(84, 330), 1)
	_spike_pit_at("GapSpikes", 13, 10, 42)

	# 2. The shaft: diamonds on the landing, a gray wall to its left, the ledge up right.
	_fire_diamond("ShaftDiamondDouble", Vector2(212, 329), 2)
	_fire_diamond("ShaftDiamondSingle", Vector2(228, 330), 1)
	_gray(25, 17, 1, 17)
	_earth(32, 14, 7, 2)

	# 3. The fuel route, at the ledge's walking height (ledge top y 112).
	_fire_diamond("RouteDiamond1", Vector2(292, 106), 1)
	_fire_diamond("RouteDiamond2", Vector2(196, 106), 1)
	_fire_diamond("RouteDiamond3", Vector2(116, 106), 1)
	_earth(1, 14, 6, 2)

	_finish_room(Vector2(24, 336), "res://tests/rooms/room_fire_b.tscn")


## A brazier standing on the floor at tile column `column` (its post's foot on the top
## of row `floor_row`). `burn_time` 0 = permanent.
func _brazier(node_name: String, column: int, floor_row: int, burn_time: float = 0.0) -> Node2D:
	return _add(BRAZIER_SCENE, node_name, Vector2(column * TILE + TILE / 2.0, floor_row * TILE),
		{"burn_time": burn_time})


## A door `height_tiles` tall in tile column `column`, its top at `top_row`, opened by
## `switch_node`. It retracts up into the ceiling.
func _door(node_name: String, column: int, top_row: int, height_tiles: int, switch_node: Node2D) -> Node2D:
	var door: Node2D = _add(DOOR_SCENE, node_name, Vector2(column * TILE, top_row * TILE),
		{"door_size": Vector2(TILE, height_tiles * TILE)})
	var door_switches: Array[Switch] = [switch_node as Switch]
	door.set("switches", door_switches)
	return door


## Fire test room C (Stage F4, fireball and braziers). Fire-only, 400×180 (scrolls),
## starts with 2 pips. Floor at row 20. Left to right:
##   1. Across the spike pit (cols 8-15), a permanent brazier (col 18) opens the
##      full-height door at col 21. Tap Q facing right: the fireball flies over the
##      pit and lights it. Then jet over the pit (your second pip).
##   2. A fire diamond (+1), then a TIMED brazier (1.8 s, notched post) at col 24 and
##      its door at col 35, 11 tiles away: light it and run. Hold Q to aim in slow
##      motion; C cancels the aim and keeps the pip.
##   3. Behind that door, a grass block with a low corridor into a chimney (cols
##      44-46) that bends left at the top into a tunnel with a brazier at its end
##      (col 39). From the floor no straight fireball can reach it: grab the double
##      diamond, jet up the chimney (hold W to chain), steer left along the tunnel,
##      and the plume lights the brazier as you pass.
func _build_room_fire_c() -> void:
	_begin_room("RoomFireC", "Fire C - Fireball & Braziers",
		"Stage F4 test room. Fire-only, starts with 2 pips. Q = fireball (tap throws, hold aims in slow motion, C cancels and keeps the pip; 0 pips = fizzle). 1: fireball the brazier across the pit to open the door, jet over. 2: timed brazier (notched post, 1.8 s) races its door. 3: the tunnel brazier can only be reached with the jet: fly up the chimney and along the tunnel.",
		Vector2(400, 180))
	_fire_only(2)
	# Frame (50 columns).
	_earth(0, 0, 50, 1)
	_earth(0, 0, 1, 23)
	_earth(49, 0, 1, 23)
	_earth(0, 20, 50, 3)

	# 1. Pit, brazier, door.
	_spike_pit_at("PitSpikes", 8, 8, 20)
	var first_brazier: Node2D = _brazier("BrazierPit", 18, 20)
	_door("DoorPit", 21, 1, 19, first_brazier)

	# 2. Diamond, timed brazier, its door.
	_fire_diamond("DiamondTimed", Vector2(22 * TILE + 4, 152), 1)
	var timed_brazier: Node2D = _brazier("BrazierTimed", 25, 20, 1.8)
	_door("DoorTimed", 35, 1, 19, timed_brazier)

	# 3. The block with the corridor, chimney and tunnel.
	_earth(37, 1, 12, 19)
	_open(37, 16, 10, 4)   # corridor, 4 tiles tall, from the door into the chimney
	_open(44, 4, 3, 12)    # chimney up
	_open(38, 4, 6, 3)     # tunnel left at the top
	_fire_diamond("DiamondChimney", Vector2(40 * TILE + 4, 151), 2)
	_brazier("BrazierTunnel", 39, 7)

	_finish_room(Vector2(24, 160), "res://tests/rooms/room_fire_c.tscn")


## Fire test room D (Stage F5, burning grass). Fire-only, 480×180 (scrolls), starts
## with 2 pips. Earth frame, floor at row 20; grass only where fire should run.
##   1. The fuse (cols 6-30): a grass strip along the floor that climbs a grassy step
##      (cols 16-21, 2 tiles high: up its left side, over its top, down its right
##      side) and ends under a brazier (col 30), which opens the door at col 33.
##      Tap Q facing right: the fireball hits the step and the fire runs both ways,
##      back toward you (it stops at the earth you stand on) and on to the brazier.
##      A gray-rock shelter (cols 24-27, 3 tiles up) hangs over the fuse: wait on it
##      while the front passes under you, then walk on over the ash.
##   2. The jet run (behind the door): a double diamond, then three grass patches on
##      the floor split by gray rock (cols 38-41, 43-46, 49-52). A fireball lights one
##      patch; jetting low along the floor (Right + W, hold W to chain) lights all
##      three behind you. Taking off from grass leaves a fire where you stood.
func _build_room_fire_d() -> void:
	_begin_room("RoomFireD", "Fire D - Burning Grass",
		"Stage F5 test room. Fire-only, starts with 2 pips. 1: fireball the grassy step: the fire runs along the grass, up the step and on to the brazier, which opens the door. Wait on the gray ledge while it passes; ash is safe to walk on. 2: grab the double diamond and jet right along the floor: the plume lights each grass patch behind you. R puts all the grass back.",
		Vector2(480, 180))
	_fire_only(2)
	# Frame (60 columns).
	_earth(0, 0, 60, 1)
	_earth(0, 0, 1, 23)
	_earth(59, 0, 1, 23)
	_earth(0, 20, 60, 3)

	# 1. The fuse, the step on it, the shelter over it, the brazier at its end.
	_grass(6, 20, 25, 1)
	_grass(16, 18, 6, 2)
	_gray(24, 17, 4, 1)
	var fuse_brazier: Node2D = _brazier("BrazierFuse", 30, 20)
	_door("DoorFuse", 33, 1, 19, fuse_brazier)

	# 2. The jet run.
	_fire_diamond("RunDiamond", Vector2(35 * TILE + 4, 151), 2)
	_grass(38, 20, 4, 1)
	_gray(42, 20, 1, 1)
	_grass(43, 20, 4, 1)
	_gray(47, 20, 2, 1)
	_grass(49, 20, 4, 1)

	_finish_room(Vector2(24, 160), "res://tests/rooms/room_fire_d.tscn")

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
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_fire_rooms.tscn
## Running it again OVERWRITES the test rooms. Pass room names after `--` to build
## only those, e.g. `-- fire_b` (names: fire_a, fire_b).

const FIRE_DIAMOND_SCENE: PackedScene = preload("res://scenes/objects/fire/fire_diamond.tscn")


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
	print("[BuildFireRooms] Done.")
	get_tree().quit()


## Makes the room being built a Fire-only room (Air and Earth off) that starts the
## player with `start_pips` fire pips.
func _fire_only(start_pips: int) -> void:
	room.air_allowed = false
	room.earth_allowed = false
	room.fire_allowed = true
	room.fire_start_pips = start_pips


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
	_grass_frame()
	# Floor diamonds at walking height (the player's middle is ~5 px above the feet).
	_fire_diamond("FireDiamondSingle1", Vector2(88, 152), 1)
	_fire_diamond("FireDiamondSingle2", Vector2(120, 152), 1)
	_fire_diamond("FireDiamondDouble1", Vector2(152, 151), 2)
	# Step (2 tiles up) and ledge (5 tiles up), each hop under a full jump.
	_grass(20, 18, 2, 2)
	_grass(24, 15, 7, 1)
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
	_grass(0, 0, 40, 1)
	_grass(0, 0, 1, 45)
	_grass(39, 0, 1, 45)
	_grass(0, 42, 40, 3)

	# 1. The gap. Diamond at walking height (the player's middle is ~5 px above the feet).
	_fire_diamond("GapDiamond", Vector2(84, 330), 1)
	_spike_pit_at("GapSpikes", 13, 10, 42)

	# 2. The shaft: diamonds on the landing, a gray wall to its left, the ledge up right.
	_fire_diamond("ShaftDiamondDouble", Vector2(212, 329), 2)
	_fire_diamond("ShaftDiamondSingle", Vector2(228, 330), 1)
	_gray(25, 17, 1, 17)
	_grass(32, 14, 7, 2)

	# 3. The fuel route, at the ledge's walking height (ledge top y 112).
	_fire_diamond("RouteDiamond1", Vector2(292, 106), 1)
	_fire_diamond("RouteDiamond2", Vector2(196, 106), 1)
	_fire_diamond("RouteDiamond3", Vector2(116, 106), 1)
	_grass(1, 14, 6, 2)

	_finish_room(Vector2(24, 336), "res://tests/rooms/room_fire_b.tscn")

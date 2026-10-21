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
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_fire_rooms.tscn
## Running it again OVERWRITES the test rooms. Pass room names after `--` to build
## only those, e.g. `-- fire_a` (names: fire_a).

const FIRE_DIAMOND_SCENE: PackedScene = preload("res://scenes/objects/fire/fire_diamond.tscn")


func _ready() -> void:
	log_prefix = "[BuildFireRooms]"
	# The tilesets already exist (the Earth generator made them); these only load them.
	_load_or_create_earth_tileset()
	_load_or_create_grass_tileset()
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if wanted.is_empty() or wanted.has("fire_a"):
		_build_room_fire_a()
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
##     with F (the temporary debug key) and touch it again: now it's taken.
##   - a spike pit to die in: dying (or R) brings back the 2 starting pips and every
##     diamond.
func _build_room_fire_a() -> void:
	_begin_room("RoomFireA", "Fire A - Fire Bar",
		"Stage F1 test room. Fire-only, starts with 2 pips. Fire diamonds: single +1, double +2, single use until R. The cap is 5. F (temporary debug key) spends a pip. F1 shows the count. R or dying resets pips and diamonds.")
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

extends "res://tools/build_earth_rooms.gd"
## tools/build_earth_chapter.gd: generator for the Earth chapter's 10 rooms
## (Stage E7), saved as scenes/rooms/earth/earth_01.tscn ... earth_10.tscn and placed
## side by side in scenes/earth_world.tscn (written by hand, not by this tool).
##
## It EXTENDS the test-room builder (tools/build_earth_rooms.gd): `extends "path"`
## inherits every helper (_earth, _grass, _gray, _open, _hidden, _spike_pit, _add,
## _finish_room...) like a Python subclass, and this _ready() replaces the parent's,
## so running this tool builds only the chapter, never the test rooms.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_earth_chapter.tscn
## Pass room numbers after `--` to build only those, e.g. `-- 3 7`.
## Running it OVERWRITES the chapter rooms: once you edit one in the editor, edit it
## there instead (and stop rebuilding it).
##
## Layout units: tiles (8 px), (column, row) from the room's top-left tile. A
## one-screen room is 40 x 23 tiles (row 22 is half off screen, part of the floor).
## Rooms touch edge to edge; the player walks (or jumps) through a 4-tile gap in a
## side wall into the next room. Each room is described by its ENTRY and EXIT floor
## rows: the floor row right under the gap. A room's exit row must equal the next
## room's entry row (ROOM_FLOORS below), or the gaps won't line up.
##
## Difficulty ramp (Earth_bending.md §9, extended to 10 rooms):
##   1-4   platform/puzzle: super jump, spending earth, rock footholds, big rock + hidden tunnel
##   5     first enemies: wisps (thrown rocks, snake ram)
##   6     platform: the long bridge (snake shape planning)
##   7     enemies: sentries + wisp, an enemy gate
##   8     puzzle: the snake head pushes a crate onto a plate
##   9-10  wider rooms (the camera scrolls), everything together, the Goal

const PLATE_SCENE: PackedScene = preload("res://scenes/objects/pressure_plate.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/objects/door.tscn")
const ENEMY_GATE_SCENE: PackedScene = preload("res://scenes/objects/enemy_gate.tscn")
const GOAL_SCENE: PackedScene = preload("res://scenes/objects/goal.tscn")

const ROOM_FOLDER: String = "res://scenes/rooms/earth/"
## Height of a wall gap, tiles (the player is 11 px tall: 4 tiles is roomy).
const GAP_HEIGHT: int = 4
## Every room's [entry floor row, exit floor row]. -1 = no gap (room 1's left wall,
## room 10's right wall). Checked by tests/earth_chapter_smoke_test.gd.
const ROOM_FLOORS: Array[Vector2i] = [
	Vector2i(-1, 13), Vector2i(13, 6), Vector2i(6, 13), Vector2i(13, 20), Vector2i(20, 20),
	Vector2i(20, 17), Vector2i(17, 20), Vector2i(20, 17), Vector2i(17, 8), Vector2i(8, -1),
]


func _ready() -> void:
	_load_or_create_earth_tileset()
	_load_or_create_grass_tileset()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOM_FOLDER))
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	# Callables (a function as a value, like a Python function object), one per room.
	var builders: Array[Callable] = [_build_01, _build_02, _build_03, _build_04, _build_05,
		_build_06, _build_07, _build_08, _build_09, _build_10]
	for room_index: int in builders.size():
		if wanted.is_empty() or wanted.has(str(room_index + 1)):
			builders[room_index].call()
	print("[BuildEarthChapter] Done.")
	get_tree().quit()


# --- Helpers ---------------------------------------------------------------------

## Starts room `number` (1-10): Earth-only (Air off), `width_tiles` wide, with a grass
## ceiling and side walls that have gaps at ROOM_FLOORS[number - 1].
func _begin_chapter_room(number: int, title: String, description: String, width_tiles: int = 40) -> void:
	_begin_room("Earth%02d" % number, "%d - %s" % [number, title], description,
		Vector2(width_tiles * TILE, 180))
	room.air_allowed = false
	room.earth_allowed = true
	var floors: Vector2i = ROOM_FLOORS[number - 1]
	_grass(0, 0, width_tiles, 1)
	_grass(0, 0, 1, 23)
	_grass(width_tiles - 1, 0, 1, 23)
	if floors.x >= 0:
		_open(0, floors.x - GAP_HEIGHT, 1, GAP_HEIGHT)
	if floors.y >= 0:
		_open(width_tiles - 1, floors.y - GAP_HEIGHT, 1, GAP_HEIGHT)


## A spike strip on a pit's bottom: open air from `top_row` down to row 21, spikes on
## row 21, GRAY under them (row 22), so the bend shadow can't cross the pit.
func _chasm(node_name: String, column: int, width: int, top_row: int) -> void:
	_open(column, top_row, width, 22 - top_row)
	_gray(column, 22, width, 1)
	_spikes(node_name, column, 21, width)


func _save(number: int, spawn_px: Vector2) -> void:
	_finish_room(spawn_px, ROOM_FOLDER + "earth_%02d.tscn" % number)


## Feet position (bottom-center) for an object standing on tile row `floor_row`, in
## the middle of tile column `column`.
func _on_floor(column: int, floor_row: int) -> Vector2:
	return Vector2(column * TILE + TILE / 2, floor_row * TILE)


# --- Rooms -----------------------------------------------------------------------

## 1 "Solid Ground": what earth looks like, and the super jump. A small grass step
## (jump it), then a ledge 7 tiles high: too high to jump. The brown-yellow patch at
## its foot: quick-tap A for a column under you (the super jump), steer onto the ledge.
func _build_01() -> void:
	_begin_chapter_room(1, "Solid Ground",
		"Brown-yellow ground is earth. Jump the little step. The ledge is too high to jump: stand on the earth at its foot and TAP A, a pillar throws you up. Steer onto the ledge.")
	_grass(0, 20, 40, 3)
	_grass(9, 18, 3, 2)        # a 2-tile step to jump
	_earth(17, 20, 5, 1)       # the earth patch
	_grass(22, 13, 18, 7)      # the ledge (top 56 px above the floor)
	_save(1, _on_floor(2, 20))


## 2 "Spending Earth": each earth tile works once. A spike pit under the entrance
## ledge (jump it), then two towers, each 7 tiles above the last, with ONE earth tile
## at the foot of each: super jump, super jump. Wasting the first tile means R.
func _build_02() -> void:
	_begin_chapter_room(2, "Spending Earth",
		"Each earth tile bends once, then it's spent (dark) until you die or press R. Jump the pit, then one tile, one super jump, per tower.")
	_grass(0, 13, 6, 10)       # entrance ledge
	_grass(6, 20, 34, 3)       # floor
	_chasm("PitSpikes", 6, 6, 20)
	_earth(16, 20, 1, 1)       # tower A's earth tile
	_grass(17, 13, 7, 7)       # tower A (top row 13)
	_earth(23, 13, 1, 1)       # tower B's earth tile, on tower A's edge
	_grass(24, 6, 15, 14)      # tower B (top row 6) up to the exit
	_save(2, _on_floor(2, 13))


## 3 "Stone Throw": rocks as footholds. A tower 7 tiles high with an earth face. The
## earth patch on the floor sits under a low overhang, so a super jump just bonks.
## Press S to tear out a rock, S again to throw it: straight at the wall = a step at
## the bottom, up-right = a step higher up. Stuck rocks are ledges: climb them.
func _build_03() -> void:
	_begin_chapter_room(3, "Stone Throw",
		"S tears a rock out of the earth; S again throws it (arrows aim). Throw it at the tower's earth face: it sticks as a step. Straight throw = low step, up-right = higher. White rock = perfect throw. Under the overhang a super jump only bonks.")
	_grass(0, 6, 5, 17)        # entrance ledge (high: drop down)
	_grass(5, 20, 35, 3)       # floor
	_grass(17, 1, 11, 14)      # low overhang over the patch (bottom at row 15)
	_earth(19, 20, 7, 1)       # rock patch, under the overhang
	_grass(30, 13, 10, 7)      # the tower (top row 13 = 56 px up)
	_earth(30, 13, 1, 7)       # its earth face
	_save(3, _on_floor(2, 6))


## 4 "Breakthrough": the big rock and a hidden tunnel. A cracked wall from the ceiling
## to the ledge blocks the way: only a BIG rock (hold S) breaks it. Past it, thick
## earth hides a tunnel: dig a 2x2 hole with another big rock and drop in, then follow
## the tunnel down and out.
func _build_04() -> void:
	_begin_chapter_room(4, "Breakthrough",
		"Hold S: the rock grows into a big rock. Throw it at the cracked wall: it breaks (small rocks just shatter). Past it, the dark earth hides a tunnel: tear a big rock out of it and drop into the hole.")
	_grass(0, 13, 14, 10)      # ledge A
	_earth(4, 13, 9, 2)        # its thick earth (2 deep: big rocks)
	_grass(14, 13, 2, 10)      # under the cracked wall
	_add(CRACKED_WALL_SCENE, "CrackedWall", Vector2(14 * TILE, 1 * TILE), {"wall_size_tiles": Vector2i(2, 12)})
	_grass(16, 13, 23, 10)     # ledge B: one solid mass down to the floor
	_earth(16, 13, 12, 2)      # its thick earth
	# The hidden way: a 2-wide shaft under the earth, then a tunnel to the exit.
	_hidden(22, 15, 2, 1)
	_hidden(22, 16, 17, 4)
	# The exit gap too: it opens into the tunnel, so it must look like earth until the
	# tunnel is revealed, or a pocket of open air would give the secret away.
	_hidden(39, 16, 1, 4)
	_save(4, _on_floor(2, 13))


## 5 "First Wisp": enemies. A wisp patrols the floor: hit it with a thrown rock. A
## second patrols a low ledge over a spike pit: bend a snake (hold A until the shadow
## leaves your feet) out of the ledge's earth top and steer it right: the head rams
## the wisp into the spikes. Or throw a rock up at it.
func _build_05() -> void:
	_begin_chapter_room(5, "First Wisp",
		"Wisps kill on touch. A perfect throw (the rock turns white) or a big rock defeats one; a sloppy small rock only shoves it. Hold A until the shadow leaves your feet: a snake comes out instead of a pillar; steer it with the arrows, A again hardens it. Its head shoves a wisp: ram the ledge wisp into the spikes.")
	_grass(0, 20, 40, 3)       # floor
	_earth(1, 20, 10, 2)       # rock patch at the start
	_grass(24, 17, 8, 3)       # the low ledge (3 tiles: jumpable)
	_earth(24, 17, 4, 3)       # its earth (12 tiles: one full snake)
	_chasm("PitSpikes", 32, 4, 20)
	_add(WISP_SCENE, "FloorWisp", _on_floor(17, 20))
	_add(WISP_SCENE, "LedgeWisp", _on_floor(29, 17), {"start_direction": -1})
	_save(5, _on_floor(2, 20))


## 6 "The Long Bridge": snake bridges, with exactly enough earth. A spike chasm with an
## island. The near ledge's earth (10 tiles) bridges the first gap (9 tiles) if the
## snake comes out of the ledge's SIDE at the top (release when the shadow has just
## wrapped over the edge). The island has 6 tiles for the 6-tile second gap: the same
## trick again, with no tile to spare.
func _build_06() -> void:
	_begin_chapter_room(6, "The Long Bridge",
		"Release A when the shadow has just crawled over the ledge's edge onto its side: the snake comes out sideways and runs straight across. The island has exactly enough earth for the second gap.")
	_grass(0, 20, 5, 3)        # start floor
	_grass(5, 17, 5, 6)        # near ledge (3 tiles up)
	_earth(5, 17, 5, 2)        # its earth: 10 tiles
	_chasm("SpikesNear", 10, 9, 17)
	_grass(19, 17, 2, 6)       # the island
	_earth(19, 17, 2, 2)       # its earth: 6 tiles (top 2, and its right side down 3)
	_earth(20, 19, 1, 2)
	_chasm("SpikesFar", 21, 6, 17)
	_grass(27, 17, 13, 6)      # far ledge to the exit
	_save(6, _on_floor(2, 20))


## 7 "Sentry Line": sentries. One on the floor, one on a ledge by the exit, a wisp
## between. The exit door opens when all three are beaten (the pips above it). Block
## orbs with a snake wall or a rock you're holding; destroy sentries with thrown rocks.
## The ledge sentry is reached from a floating earth platform at its height.
func _build_07() -> void:
	_begin_chapter_room(7, "Sentry Line",
		"Sentries shoot orbs at you. A snake wall blocks them, so does a rock you hold. A perfect throw (or a big rock) destroys a sentry: for the high one, super jump onto the floating platform and throw straight from there. The door opens when every enemy is beaten.")
	_grass(0, 17, 6, 6)        # entrance ledge
	_grass(6, 20, 34, 3)       # floor
	_earth(6, 20, 13, 2)       # earth floor (26 tiles)
	_grass(32, 14, 7, 2)       # the high sentry's ledge, over the exit
	# A floating platform level with that ledge: super jump onto it from the earth floor
	# (its right end), tear a rock out of its earth top and throw it STRAIGHT: from up
	# here chest height is the sentry's eye height. It also puts you in the sentry's
	# line of fire. (From the floor only a perfect high lob from the far left reaches it.)
	# Its left side is right beside the floor's last earth tile, so holding Right during
	# the super jump presses you against its side (like a ledge) instead of under it.
	_grass(19, 14, 5, 2)
	_earth(19, 14, 5, 1)
	var wisp: Node2D = _add(WISP_SCENE, "Wisp", _on_floor(22, 20), {"start_direction": -1})
	var floor_sentry: Node2D = _add(SENTRY_SCENE, "FloorSentry", Vector2(28 * TILE, 160))
	var ledge_sentry: Node2D = _add(SENTRY_SCENE, "LedgeSentry", Vector2(34 * TILE + 4, 14 * TILE))
	var gate: Node2D = _add(ENEMY_GATE_SCENE, "EnemyGate", Vector2(300, 124))
	var gate_enemies: Array[Node2D] = [wisp, floor_sentry, ledge_sentry]
	gate.set("enemies", gate_enemies)
	var door: Node2D = _add(DOOR_SCENE, "ExitDoor", Vector2(38 * TILE, 16 * TILE), {"door_size": Vector2(8, 32)})
	var door_switches: Array[Switch] = [gate as Switch]
	door.set("switches", door_switches)
	_save(7, _on_floor(2, 17))


## 8 "Heavy Earth": the snake head pushes. A crate, a pressure plate and a door. Bend
## a snake out of the earth just behind the crate, up one tile, then right: each tile
## it grows shoves the crate one tile. The patch has exactly the tiles to push it onto
## the plate (12): spend some on a wrong turn and it falls short.
func _build_08() -> void:
	_begin_chapter_room(8, "Heavy Earth",
		"The plate needs something heavy. Bend a snake out of the earth behind the crate, steer it up one tile, then right: its head shoves the crate along. The patch has exactly enough earth to reach the plate.")
	_grass(0, 20, 40, 3)       # floor
	_earth(4, 20, 6, 2)        # the patch (12 tiles)
	_add(CRATE_SCENE, "Crate", Vector2(11 * TILE, 160))
	var plate: Node2D = _add(PLATE_SCENE, "Plate", Vector2(21 * TILE, 160))
	_grass(30, 1, 1, 15)       # the wall above the door
	var door: Node2D = _add(DOOR_SCENE, "Door", Vector2(30 * TILE, 16 * TILE), {"door_size": Vector2(8, 32)})
	var door_switches: Array[Switch] = [plate as Switch]
	door.set("switches", door_switches)
	_grass(33, 17, 7, 3)       # the exit step (3 tiles: jumpable)
	_save(8, _on_floor(2, 20))


## 9 "Siege" (480 px: the camera scrolls). A cracked wall hides a sentry; a wisp
## patrols behind it; then a tower 12 tiles high with an earth face and a second
## sentry on top. Big rock for the wall, rocks or a snake staircase for the tower,
## snake walls or held rocks against the orbs.
func _build_09() -> void:
	_begin_chapter_room(9, "Siege",
		"Break the cracked wall with a big rock: a sentry waits behind it, and a wisp. Then climb the tower: stick rocks into its earth face, or steer a snake into a staircase. The sentry on top shoots at climbers.", 60)
	_grass(0, 17, 5, 6)        # entrance ledge
	_grass(5, 20, 55, 3)       # floor
	_earth(5, 20, 12, 2)       # earth for big rocks (2 deep)
	_grass(20, 1, 2, 10)       # the overhang the cracked wall hangs from
	_add(CRACKED_WALL_SCENE, "CrackedWall", Vector2(20 * TILE, 11 * TILE), {"wall_size_tiles": Vector2i(2, 9)})
	_add(SENTRY_SCENE, "WallSentry", _on_floor(27, 20))
	_add(WISP_SCENE, "Wisp", _on_floor(33, 20))
	_earth(30, 20, 10, 1)      # thin earth at the tower's foot (10 tiles)
	_grass(40, 8, 20, 12)      # the tower (top row 8 = 96 px up)
	_earth(40, 8, 1, 10)       # its earth face
	_add(SENTRY_SCENE, "TowerSentry", _on_floor(46, 8))
	_save(9, _on_floor(2, 17))


## 10 "Summit" (640 px: the camera scrolls). Everything: a cracked wall (big rock), a
## snake bridge over a spike chasm with exactly enough earth (and a wisp waiting on
## the far side), a ceiling sentry over the far ledge, then the goal tower 10 tiles
## high with a sentry on top and a wisp at its foot. The Goal is on the tower.
func _build_10() -> void:
	_begin_chapter_room(10, "Summit",
		"Everything you've learned. Big rock through the wall, a bridge with no earth to spare, a ceiling sentry, and the last climb under fire. The flag is the end.", 80)
	_grass(0, 8, 10, 15)       # ledge A (entrance)
	_earth(3, 8, 7, 2)         # thick earth: big rocks
	_grass(10, 8, 2, 15)
	_add(CRACKED_WALL_SCENE, "CrackedWall", Vector2(10 * TILE, 1 * TILE), {"wall_size_tiles": Vector2i(2, 7)})
	_grass(12, 8, 9, 15)       # ledge B
	_earth(15, 8, 6, 2)        # 12 tiles: one bridge of 12
	_chasm("ChasmSpikes", 21, 12, 8)
	_grass(33, 8, 18, 6)       # far ledge C (rows 8-13), open below
	_grass(33, 20, 47, 3)      # the floor under it and on to the tower
	_add(WISP_SCENE, "BridgeWisp", _on_floor(40, 8), {"start_direction": -1})
	_add(SENTRY_SCENE, "CeilingSentry", Vector2(46 * TILE, 1 * TILE), {"mounted_on_ceiling": true})
	_earth(52, 20, 12, 1)      # thin earth before the tower
	_add(WISP_SCENE, "FloorWisp", _on_floor(58, 20))
	_grass(66, 10, 13, 10)     # the goal tower (top row 10 = 80 px up)
	_earth(66, 10, 1, 10)      # its earth face
	_add(SENTRY_SCENE, "TowerSentry", _on_floor(70, 10))
	_add(GOAL_SCENE, "Goal", Vector2(74 * TILE, 6 * TILE), {"goal_size": Vector2(24, 32)})
	_save(10, _on_floor(2, 8))

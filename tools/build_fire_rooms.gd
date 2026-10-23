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
##   - tests/rooms/room_fire_e.tscn   Stage F6 thicket and an overgrown cover (_build_room_fire_e)
##   - tests/rooms/room_fire_f.tscn   Stage F7 bonfires, hot updrafts, air diamond conversion (_build_room_fire_f)
##   - tests/rooms/room_fire_g.tscn   Stage F8 vines (drawbridge, swinging plank), burning crate, leaf platform and sail (_build_room_fire_g)
##   - tests/rooms/room_fire_j.tscn   Stage F11 enemies vs fire and the vine monkey (_build_room_fire_j)
##   - tests/rooms/room_fire_l.tscn   Stage F11b the thicket elephant: climb and ride, charge, stone wall, bolt (_build_room_fire_l)
##   - resources/tiles/thicket_tileset.tres  (Stage F6) the thicket tile and the
##                                    grass-looking cover tile, solid on layer 1.
##                                    Only written when missing.
##
## Plant terrain (Stage F6): _thicket() paints cells of the room's "Thicket" layer
## (ThicketLayer), _overgrown() cells of its "Overgrown" layer (OvergrownLayer), as
## grass-looking or thicket-looking cover. Both erase whatever else was painted there.
## The layers are added through the Earth generator's _make_extra_layers() hook.
##
## Ground: grass BURNS since Stage F5, so rooms are built of earth (never burns, still
## painted like grass's neighbour) and grass is only laid where a room wants fire to
## run. Rooms A-C were grass-framed before F5 and are earth-framed now, so a jet
## take-off doesn't set their floors alight.
##
## Run it from the project folder (console build):
##   godot --headless --path . res://tools/build_fire_rooms.tscn
## Running it again OVERWRITES the test rooms. Pass room names after `--` to build
## only those, e.g. `-- fire_b` (names: fire_a … fire_g, fire_j, fire_l).

const FIRE_DIAMOND_SCENE: PackedScene = preload("res://scenes/objects/fire/fire_diamond.tscn")
const BRAZIER_SCENE: PackedScene = preload("res://scenes/objects/fire/brazier.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/objects/door.tscn")
const LEAF_PILE_SCENE: PackedScene = preload("res://scenes/objects/leaf_pile.tscn")
const GUST_DIAMOND_SCENE: PackedScene = preload("res://scenes/objects/gust_diamond.tscn")
const VINE_SCENE: PackedScene = preload("res://scenes/objects/fire/vine.tscn")
const HANGING_PLATFORM_SCENE: PackedScene = preload("res://scenes/objects/fire/hanging_platform.tscn")
const PLATE_SCENE: PackedScene = preload("res://scenes/objects/pressure_plate.tscn")
const LEAF_SCENE: PackedScene = preload("res://scenes/objects/leaf_platform.tscn")
const SAIL_SCENE: PackedScene = preload("res://scenes/objects/sail_platform.tscn")
const MONKEY_SCENE: PackedScene = preload("res://scenes/enemies/vine_monkey.tscn")
const ELEPHANT_SCENE: PackedScene = preload("res://scenes/enemies/thicket_elephant.tscn")
const STONE_WALL_SCENE: PackedScene = preload("res://scenes/objects/stone_wall.tscn")
const THICKET_LAYER_SCRIPT: Script = preload("res://scenes/objects/fire/thicket_layer.gd")
const OVERGROWN_LAYER_SCRIPT: Script = preload("res://scenes/objects/fire/overgrown_layer.gd")
## Thicket tile picture colors: dark bramble green, lighter branches, brown thorns.
const THICKET_BODY_COLOR: Color = Color(0.1, 0.22, 0.11)
const THICKET_BRANCH_COLOR: Color = Color(0.27, 0.39, 0.16)
const THICKET_THORN_COLOR: Color = Color(0.36, 0.27, 0.14)

## Plant terrain of the room being built (sets: Vector2i -> true / atlas coords).
var thicket_cells: Dictionary = {}
## Overgrown cover cells -> ThicketLayer.GRASS_LOOK_TILE or THICKET_TILE.
var overgrown_cells: Dictionary = {}


func _ready() -> void:
	log_prefix = "[BuildFireRooms]"
	# The tilesets already exist (the Earth generator made them); these only load them.
	_load_or_create_earth_tileset()
	_load_or_create_grass_tileset()
	_load_or_create_thicket_tileset()
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if wanted.is_empty() or wanted.has("fire_a"):
		_build_room_fire_a()
	if wanted.is_empty() or wanted.has("fire_b"):
		_build_room_fire_b()
	if wanted.is_empty() or wanted.has("fire_c"):
		_build_room_fire_c()
	if wanted.is_empty() or wanted.has("fire_d"):
		_build_room_fire_d()
	if wanted.is_empty() or wanted.has("fire_e"):
		_build_room_fire_e()
	if wanted.is_empty() or wanted.has("fire_f"):
		_build_room_fire_f()
	if wanted.is_empty() or wanted.has("fire_g"):
		_build_room_fire_g()
	if wanted.is_empty() or wanted.has("fire_j"):
		_build_room_fire_j()
	if wanted.is_empty() or wanted.has("fire_l"):
		_build_room_fire_l()
	print("[BuildFireRooms] Done.")
	get_tree().quit()


# --- Plant terrain (Stage F6) ------------------------------------------------------

## The thicket tile pictures, side by side in one 16x8 image: [thicket | grass look].
## Only the editor ever shows them (the GroundPainter draws the room), so they just
## need to read as "brambles" and "grass" while painting.
func _make_thicket_image() -> Image:
	var image: Image = Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
	image.fill(THICKET_BODY_COLOR)
	for i: int in TILE:
		image.set_pixel(i, i, THICKET_BRANCH_COLOR)  # two crossing branches
		image.set_pixel(TILE - 1 - i, (i + 3) % TILE, THICKET_BRANCH_COLOR)
	for pixel: Vector2i in [Vector2i(0, 2), Vector2i(7, 5), Vector2i(4, 7)]:
		image.set_pixelv(pixel, THICKET_THORN_COLOR)
	var grass_look: Image = _make_grass_image()
	image.blit_rect(grass_look, Rect2i(0, 0, TILE, TILE), Vector2i(TILE, 0))
	return image


func _load_or_create_thicket_tileset() -> void:
	if ResourceLoader.exists(ThicketLayer.TILESET_PATH):
		return
	var new_tile_set: TileSet = TileSet.new()
	new_tile_set.tile_size = Vector2i(TILE, TILE)
	new_tile_set.add_physics_layer()
	new_tile_set.set_physics_layer_collision_layer(0, 1)  # layer 1, "world": solid ground
	new_tile_set.set_physics_layer_collision_mask(0, 0)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_make_thicket_image())
	source.texture_region_size = Vector2i(TILE, TILE)
	new_tile_set.add_source(source, 0)
	var half: float = TILE / 2.0
	for atlas_coords: Vector2i in [ThicketLayer.THICKET_TILE, ThicketLayer.GRASS_LOOK_TILE]:
		source.create_tile(atlas_coords)
		var tile_data: TileData = source.get_tile_data(atlas_coords, 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
		]))
	ResourceSaver.save(new_tile_set, ThicketLayer.TILESET_PATH)
	print("[BuildFireRooms] Wrote %s" % ThicketLayer.TILESET_PATH)


## Starting a room also forgets the last room's plant terrain.
func _begin_room(node_name: String, title: String, description: String,
		size_px: Vector2 = Vector2(320, 180)) -> void:
	super(node_name, title, description, size_px)
	thicket_cells.clear()
	overgrown_cells.clear()


## Thicket: solid brambles that burn away (erases whatever was painted there).
func _thicket(column: int, row: int, width: int, height: int) -> void:
	_open(column, row, width, height)
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			thicket_cells[Vector2i(x, y)] = true


## An overgrown cover that looks like grass ground (`looks_like_thicket` false) or a
## thicket wall (true). Erases whatever was painted there.
func _overgrown(column: int, row: int, width: int, height: int, looks_like_thicket: bool = false) -> void:
	_open(column, row, width, height)
	for x: int in range(column, column + width):
		for y: int in range(row, row + height):
			overgrown_cells[Vector2i(x, y)] = ThicketLayer.THICKET_TILE if looks_like_thicket else ThicketLayer.GRASS_LOOK_TILE


## The Earth generator's hook: "Thicket" and "Overgrown" layers, only in rooms that
## have such cells.
func _make_extra_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	# _open() in another helper may have cleared a cell after we painted it: only
	# cells still free of other kinds are kept.
	if not thicket_cells.is_empty():
		var thicket: TileMapLayer = TileMapLayer.new()
		thicket.name = "Thicket"
		thicket.set_script(THICKET_LAYER_SCRIPT)
		thicket.tile_set = load(ThicketLayer.TILESET_PATH) as TileSet
		for cell: Vector2i in thicket_cells:
			if not cell_kinds.has(cell):
				thicket.set_cell(cell, 0, ThicketLayer.THICKET_TILE)
		layers.append(thicket)
	if not overgrown_cells.is_empty():
		var overgrown: TileMapLayer = TileMapLayer.new()
		overgrown.name = "Overgrown"
		overgrown.set_script(OVERGROWN_LAYER_SCRIPT)
		overgrown.tile_set = load(ThicketLayer.TILESET_PATH) as TileSet
		for cell: Vector2i in overgrown_cells:
			if not cell_kinds.has(cell):
				overgrown.set_cell(cell, 0, overgrown_cells[cell])
		layers.append(overgrown)
	return layers


## Makes the room being built a Fire test room that starts the player with
## `start_pips` fire pips. Every element is allowed (F7 play-test: test rooms are for
## trying things out, mixed moves included); the Fire CHAPTER rooms (Stage F14) will
## be Fire-only.
func _fire_room(start_pips: int) -> void:
	room.air_allowed = true
	room.earth_allowed = true
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

## Fire test room A (Stage F1, the fire bar). All elements, starts with 2 pips. Left to right:
##   - two single diamonds and a double at walking height on the floor: walking
##     through all three gives 2 + 1 + 1 + 2 = 6, and the cap is 5, so one is lost
##   - a step and a ledge with a double diamond above it: you reach it with a full
##     bar, so it STAYS (a diamond is only used up when it adds a pip). Spend one
##     with W (a jet burst) and touch it again: now it's taken.
##   - a spike pit to die in: dying (or R) brings back the 2 starting pips and every
##     diamond.
func _build_room_fire_a() -> void:
	_begin_room("RoomFireA", "Fire A - Fire Bar",
		"Stage F1 test room. All elements, starts with 2 pips. Fire diamonds: single +1, double +2, single use until R. The cap is 5. W (flame jet) spends a pip. F1 shows the count. R or dying resets pips and diamonds.")
	_fire_room(2)
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


## Fire test room B (Stage F3, the flame jet). All elements, two screens tall
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
		"Stage F3 test room. All elements, starts with 0 pips. W = jet burst (1 pip, steer with arrows, no arrow = up), hold W to chain, C cuts it short. Gap: grab the diamond, one burst crosses 10 tiles. Shaft: 3 pips, hold W to chain up to the ledge. Fuel route: jet left from the ledge through the floating diamonds to the far platform.",
		Vector2(320, 360))
	_fire_room(0)
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


## Fire test room C (Stage F4, fireball and braziers). All elements, 400×180 (scrolls),
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
		"Stage F4 test room. All elements, starts with 2 pips. Q = fireball (tap throws, hold aims in slow motion, C cancels and keeps the pip; 0 pips = fizzle). 1: fireball the brazier across the pit to open the door, jet over. 2: timed brazier (notched post, 1.8 s) races its door. 3: the tunnel brazier can only be reached with the jet: fly up the chimney and along the tunnel.",
		Vector2(400, 180))
	_fire_room(2)
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


## Fire test room D (Stage F5, burning grass). All elements, 480×180 (scrolls), starts
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
		"Stage F5 test room. All elements, starts with 2 pips. 1: fireball the grassy step: the fire runs along the grass, up the step and on to the brazier, which opens the door. Wait on the gray ledge while it passes; ash is safe to walk on. 2: grab the double diamond and jet right along the floor: the plume lights each grass patch behind you. R puts all the grass back.",
		Vector2(480, 180))
	_fire_room(2)
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


## Fire test room E (Stage F6, thicket and overgrown covers). All elements, 400×180
## (scrolls), starts with 3 pips. Earth frame, floor at row 20. Left to right:
##   1. A thicket wall (cols 12-13), ceiling to floor: tap Q facing right. It glows,
##      burns through (thicket lights its 4 neighbours) and crumbles: the way is open.
##   2. A step (cols 14-15) and an earth block (cols 16-21, top at row 14), then a
##      thicket FLOOR (cols 22-27, rows 14-15) over a lower corridor (rows 16-19). The
##      upper floor runs on (earth, cols 28-33) into a gray barrier (cols 34-35,
##      ceiling to row 15): a dead end. Burn the thicket floor (a fireball down at
##      it, or take off from it with W and come back down through the hole) and
##      drop into the corridor, which runs under the barrier.
##   3. Past the barrier: an earth block (cols 41-48, rows 12-19) whose left face
##      (cols 41-42, rows 15-19) is an overgrown cover that passes for a thicket bush
##      (tell: browner leaves, a shade off, roots poking out of its side). Behind it, a hidden chamber
##      (cols 43-47, rows 15-19) with a double fire diamond. A grass fuse on the
##      floor (cols 36-40) ends in a tuft against the cover: light the fuse (or hit
##      the cover itself) and the whole cover flashes over.
func _build_room_fire_e() -> void:
	_begin_room("RoomFireE", "Fire E - Thicket & Overgrown",
		"Stage F6 test room. All elements, starts with 3 pips. 1: fireball the thicket wall: it glows, burns through and crumbles away. 2: the upper way ends at a gray barrier: burn the thicket floor (fireball it, or jet off it) and drop to the corridor below. 3: a grass fuse runs to a bush that is really an overgrown cover (browner leaves, roots): when the fire reaches it, the whole cover flashes over and opens a chamber with a fire diamond. R brings it all back.",
		Vector2(400, 180))
	_fire_room(3)
	# Frame (50 columns).
	_earth(0, 0, 50, 1)
	_earth(0, 0, 1, 23)
	_earth(49, 0, 1, 23)
	_earth(0, 20, 50, 3)

	# 1. The thicket wall.
	_thicket(12, 1, 2, 19)

	# 2. Step, block, thicket floor over the corridor, upper dead end at the barrier.
	_earth(14, 17, 2, 3)
	_earth(16, 14, 6, 6)
	_thicket(22, 14, 6, 2)
	_earth(28, 14, 6, 2)
	_gray(34, 1, 2, 15)

	# 3. The fuse, the block with its overgrown face and the hidden chamber.
	_grass(36, 20, 5, 1)
	_grass(40, 19, 1, 1)
	_earth(41, 12, 8, 8)
	_overgrown(41, 15, 2, 5, true)
	_hidden(43, 15, 5, 5)
	_fire_diamond("ChamberDiamond", Vector2(45 * TILE + 4, 151), 2)

	_finish_room(Vector2(24, 160), "res://tests/rooms/room_fire_e.tscn")


## Fire test room F (Stage F7, bonfires, hot updrafts, air diamond conversion; reworked
## after the F7 play-test: the LEAVES burn). All elements, 480×180 (scrolls), starts
## with 5 pips. Earth frame, floor at row 20 (y 160). Left to right:
##   1. The bonfire elevator: a leaf pile (col 8) on a grass patch (cols 6-10), then
##      an earth wall (cols 11-14) 7 tiles high. Fireball the pile: the leaves catch
##      one after another, the heap glows amber, a low flame breaks out and rises to a
##      full bonfire; the grass under it catches (stand back). Jump, press C again to
##      glide, and drift over the flame: the hot updraft lifts you to about 72 px
##      (feet), above the wall's top (56 px): steer right and land on it. Or light it
##      from above (jet over it, fireball down) while gliding and ride it up.
##   2. The hidden crystal: a wide, tall leaf pile (col 26, 52 px) with a wind crystal
##      under its right end. Burn it: the crystal turns orange (+1), but the bonfire is
##      as wide as the heap, so the crystal sits in its flame: gust the heap apart from
##      close by (the bonfire goes out, the leaves fly off as embers), then take it.
##   3. The ember rain: a small pile (col 33) on a grass patch (cols 30-37; it stops short of the wide pile's bonfire). Gust it
##      up (Up + X) and fireball the falling cloud: the embers chain through it and
##      light the grass where they land. Lone burning leaves are harmless.
##   4. The conversion across a gap: a 10-tile spike pit (cols 38-47) with a gust
##      diamond hanging over its middle at walking height. Tap Q facing right from the
##      edge: the fireball turns it into a +2 fire diamond. Then jet over and grab it
##      on the way.
func _build_room_fire_f() -> void:
	_begin_room("RoomFireF", "Fire F - Bonfires & Air Diamonds",
		"Stage F7 test room. All elements, starts with 5 pips. The LEAVES burn: a lone burning leaf is a harmless ember, 6+ lying together make a bonfire (amber, then a low flame, then tall). 1: fireball the pile, glide over the bonfire: you rise; steer onto the wall. 2: burn the wide pile: the crystal it hid turns orange, but it's in the flame: gust the bonfire apart from close by, then take it (+1). 3: gust the small pile up and fireball the falling leaves: an ember rain lights the grass. 4: fireball the blue gust diamond over the pit: +2; jet across and grab it. R puts it all back.",
		Vector2(480, 180))
	_fire_room(5)
	# Frame (60 columns).
	_earth(0, 0, 60, 1)
	_earth(0, 0, 1, 23)
	_earth(59, 0, 1, 23)
	_earth(0, 20, 60, 3)

	# 1. The bonfire elevator.
	_grass(6, 20, 5, 1)
	_add(LEAF_PILE_SCENE, "ElevatorPile", Vector2(8 * TILE + 4, 160),
		{"pile_width": 24.0, "leaf_count": 60, "random_seed": 3})
	_earth(11, 13, 4, 7)

	# 2. The pile hiding a crystal under its right end.
	_add(CRYSTAL_SCENE, "HiddenCrystal", Vector2(224, 156))
	_add(LEAF_PILE_SCENE, "HidingPile", Vector2(208, 160),
		{"pile_width": 52.0, "pile_height": 12.0, "leaf_count": 170, "random_seed": 11})

	# 3. The ember rain: a small pile on grass.
	_grass(30, 20, 8, 1)
	_add(LEAF_PILE_SCENE, "RainPile", Vector2(33 * TILE + 4, 160),
		{"pile_width": 20.0, "pile_height": 5.0, "leaf_count": 40, "random_seed": 5})

	# 4. The pit and the gust diamond over it.
	_spike_pit_at("GapSpikes", 38, 10, 20)
	_add(GUST_DIAMOND_SCENE, "GapGustDiamond", Vector2(344, 150))

	_finish_room(Vector2(24, 160), "res://tests/rooms/room_fire_f.tscn")


## A vine from `from_px` to `to_px` (room pixels).
func _vine(node_name: String, from_px: Vector2, to_px: Vector2) -> Node2D:
	return _add(VINE_SCENE, node_name, from_px, {"end_point": to_px - from_px})


## Fire test room G (Stage F8, vines and burning Air objects; reworked after the F8
## play-test: vines are burning ropes and planks swing). All elements, 560×180
## (scrolls), starts with 5 pips. Earth frame, floor at row 20 (y 160). Left to right:
##   1. The drawbridge: an 88 px plank stands on end on the far rim of a 9-tile spike
##      pit (cols 6-14), leaning a little toward you, held upright by a vine from its
##      top up to the ceiling on the right. Throw a fireball over the plank's top at
##      the vine: the vine burns through, the plank topples and falls across the
##      pit, a bridge. The two halves of the vine burn away as they dangle.
##   2. The swinging plank: an 88 px plank hung flat from two vines over a second
##      pit (cols 20-28). Burn one vine: that end drops and the plank swings on the
##      other vine. Burn that one too and it falls (into the pit, or across it if
##      it's flat when it goes).
##   3. The crate on a plate: the plate (col 35) holds the door at col 42 SHUT (it's
##      open while the plate is off). Grass under the plate (cols 32-38). Fireball the
##      crate: it burns 1.5 s (deadly), lights the grass, collapses into ash, the plate
##      lifts and the door opens. Wait on the earth (cols 29-31) while the grass burns.
##   4. A leaf platform (x 360) under a fire diamond (puff to ride it up; light it
##      under you and you have 0.8 s), and a sail across an 18-tile spike pit (cols
##      47-64). Gust right to sail, then fireball (or jet) the sail: it stops catching
##      wind and coasts on to the end of its rail.
## (The F8 vine gate was dropped after the play-test: a door a vine holds shut did
## nothing a thicket wall doesn't.)
func _build_room_fire_g() -> void:
	_begin_room("RoomFireG", "Fire G - Vines & Burning Objects",
		"Stage F8 test room. All elements, starts with 5 pips. 1: fireball the vine holding the standing plank (over its top): it burns through, the plank topples across the pit. 2: burn one vine of the hanging plank and it swings on the other; burn both and it falls. 3: burn the crate on the plate (wait on the earth while the grass burns): it collapses, the plate lifts, the door opens. 4: a leaf platform (burns away in 0.8 s, harmless) and a sail: gust right to sail over the pit, burn the sail and it coasts to the end. R brings everything back.",
		Vector2(560, 180))
	_fire_room(5)
	# Frame (70 columns).
	_earth(0, 0, 70, 1)
	_earth(0, 0, 1, 23)
	_earth(69, 0, 1, 23)
	_earth(0, 20, 70, 3)

	# 1. The drawbridge: the pit (x 48-120), the plank standing on the far rim (its
	#    foot at x 126.5, its top at y 72, leaning 2 degrees left), its vine.
	_spike_pit_at("BridgePitSpikes", 6, 9, 20)
	var bridge_vine: Node2D = _vine("DrawbridgeVine", Vector2(152, 8), Vector2(123.5, 72))
	var drawbridge: Node2D = _add(HANGING_PLATFORM_SCENE, "Drawbridge", Vector2(125, 116),
		{"platform_width": 88.0, "rotation_degrees": -92.0})
	var drawbridge_vines: Array[Switch] = [bridge_vine as Switch]
	drawbridge.set("vines", drawbridge_vines)

	# 2. The swinging plank (x 152-240, its middle line at y 50) over the second pit
	#    (x 160-232), a vine 4 px in from each end.
	_spike_pit_at("SwingPitSpikes", 20, 9, 20)
	var left_vine: Node2D = _vine("SwingVineLeft", Vector2(156, 8), Vector2(156, 50))
	var right_vine: Node2D = _vine("SwingVineRight", Vector2(236, 8), Vector2(236, 50))
	var swing_plank: Node2D = _add(HANGING_PLATFORM_SCENE, "SwingPlank", Vector2(196, 50), {"platform_width": 88.0})
	var swing_vines: Array[Switch] = [left_vine as Switch, right_vine as Switch]
	swing_plank.set("vines", swing_vines)

	# 3. The crate on the plate, grass under it, and the door the plate holds shut.
	_grass(32, 20, 7, 1)
	var plate: Node2D = _add(PLATE_SCENE, "CratePlate", Vector2(284, 160), {"plate_width": 24.0})
	_add(CRATE_SCENE, "PlateCrate", Vector2(284, 160))
	var plate_door: Node2D = _door("PlateDoor", 42, 1, 19, plate)
	plate_door.set("open_when_off", true)

	# 4. The leaf platform under a fire diamond, and the sail over the long pit.
	_add(LEAF_SCENE, "BurnLeaf", Vector2(360, 136), {"leaf_width": 24.0, "travel": Vector2(0, -48)})
	_fire_diamond("LeafDiamond", Vector2(360, 78), 1)
	_spike_pit_at("SailPitSpikes", 47, 18, 20)
	_add(SAIL_SCENE, "BurnSail", Vector2(392, 152), {"rail_start": Vector2(0, 0), "rail_end": Vector2(128, 0)})

	_finish_room(Vector2(24, 160), "res://tests/rooms/room_fire_g.tscn")


## Fire test room J (Stage F11, enemies against fire and the vine monkey). All
## elements, 640×180 (scrolls), starts with 5 pips. Earth frame, floor at row 20
## (y 160). Left to right:
##   1. A wisp patrolling a grass strip between two 1-tile bumps (cols 8-17). Light
##      the grass (a fireball from the left bump, aimed down-right) and time it: the
##      wisp walks into the fire and burns up. Or just fireball the wisp.
##   2. A sentry on a block (x 268). Fireball it: destroyed. Throw a fireball at an
##      orb: both burst. A wall (col 36) hangs from the ceiling past it, so the
##      sentry can't see the rooms to the right.
##   3. A vine monkey running back and forth across a spike strip (cols 39-47)
##      between two 3-tile walls: spikes don't hurt it. A platform above (row 12)
##      lets you cross.
##   4. A monkey on a ledge (cols 51-56, row 15) next to a leaf pile on the floor
##      (x 456-480). Light the pile; when the bonfire is tall, jump and gust the
##      monkey right off the ledge: it drifts up in the hot air instead of falling.
##   5. A monkey running a grass floor (cols 62-68), hopping a 2-tile spike pit
##      (cols 69-70) to more grass and a leaf pile (cols 71-78), and back. Fireball
##      it: it runs as a torch, lighting the grass. Light it while it's on the far
##      side (or mid-hop) and it sets the far grass and the pile on fire. A gust puts
##      a burning monkey out: it smolders, stunned, then carries on.
func _build_room_fire_j() -> void:
	_begin_room("RoomFireJ", "Fire J - Enemies & Vine Monkey",
		"Stage F11 test room. All elements, starts with 5 pips. 1: burn the grass (or fireball the wisp): it walks into the fire and burns up. 2: fireball the sentry; fireball an orb and both burst. 3: a vine monkey runs over spikes unharmed (cross on the platform above). 4: light the leaf pile, then gust the ledge monkey into the hot air: it floats up. 5: fireball the monkey that hops the pit: it runs as a torch and lights the grass; light it on the far side for the leaf pile. Gust a burning monkey to put it out. R brings everything back.",
		Vector2(640, 180))
	_fire_room(5)
	# Frame (80 columns).
	_earth(0, 0, 80, 1)
	_earth(0, 0, 1, 23)
	_earth(79, 0, 1, 23)
	_earth(0, 20, 80, 3)

	# 1. The wisp on its grass strip.
	_earth(7, 19, 1, 1)
	_earth(18, 19, 1, 1)
	_grass(8, 20, 10, 1)
	_add(WISP_SCENE, "FuseWisp", Vector2(104, 160))

	# 2. The sentry on its block, and the wall hanging past it.
	_earth(32, 18, 3, 2)
	_add(SENTRY_SCENE, "FireSentry", Vector2(268, 144))
	_earth(36, 1, 1, 15)

	# 3. The spike-strip monkey, its walls, and the platform to cross on.
	_earth(38, 17, 1, 3)
	_earth(48, 17, 1, 3)
	_spikes("StripSpikes", 39, 19, 9)
	_add(MONKEY_SCENE, "SpikeMonkey", Vector2(348, 160), {"hops_gaps": false})
	_earth(40, 12, 7, 1)

	# 4. The ledge monkey and the leaf pile beside its ledge.
	_earth(51, 15, 6, 1)
	_add(MONKEY_SCENE, "LedgeMonkey", Vector2(432, 120), {"hops_gaps": false})
	_add(LEAF_PILE_SCENE, "UpdraftPile", Vector2(468, 160),
		{"pile_width": 24.0, "leaf_count": 60, "random_seed": 7})

	# 5. The fuse monkey: grass, the pit it hops, more grass and a leaf pile.
	_earth(61, 19, 1, 1)
	_grass(62, 20, 7, 1)
	_spike_pit_at("FusePitSpikes", 69, 2, 20)
	_grass(71, 20, 8, 1)
	_add(LEAF_PILE_SCENE, "FarPile", Vector2(604, 160),
		{"pile_width": 20.0, "leaf_count": 40, "random_seed": 9})
	_add(MONKEY_SCENE, "FuseMonkey", Vector2(520, 160))

	_finish_room(Vector2(24, 160), "res://tests/rooms/room_fire_j.tscn")


## Fire test room L (Stage F11b, the thicket elephant: 96x60, a walking boulder). All
## elements, 720×180 (scrolls), starts with 5 pips. Earth frame, floor at row 20
## (y 160): an elephant's back is at y 100, 60 px up, out of jumping reach (30 px).
## It charges whenever it sees you on its level in front of it. Left to right:
##   1. The climb and the ride: an elephant walks a 20-tile spike strip (cols 8-27)
##      between two 3-tile walls. Get onto its back (from the left wall: a dash or
##      gust up, the jet, a column next to it...) and ride it; a fire diamond hangs
##      high over the spikes (y 64). Standing on the wall in front of it, it charges
##      and is stunned by the wall: a moment to climb.
##   2. The stone wall: an elephant in a pen between a low wall (col 31) and a STONE
##      wall (cols 54-55, rows 11-19) only an elephant can break, a fire diamond in the
##      chamber behind. Stand between it and the stone wall: it charges you; jump onto
##      the ledge by the wall (cols 47-51, row 10) and it smashes the wall. Another
##      ledge (cols 34-41, row 10) to dodge on. Burn its trunk and it charges twice as
##      fast; a thrown big rock stops a charge.
##   3. The thicket: an elephant in front of a thicket wall (cols 82-83). Burn its tail
##      from the left: it bolts (twice as fast) through the thicket. Burn all three
##      spots and it crumbles to ash. Burning its back makes the tail strike over it.
func _build_room_fire_l() -> void:
	_begin_room("RoomFireL", "Fire L - Thicket Elephant",
		"Stage F11b test room. All elements, starts with 5 pips. A huge earth elephant: its front kills, its back is a ride (60 px up: dash, gust, jet or a column), its tail wiggles, rises and whips. It charges whenever it sees you on its level. 1: climb on and ride over the spikes to the high diamond. 2: lure its charge into the STONE wall (only elephants break it): jump onto the ledge as it comes. 3: burn its tail from the left: it bolts through the thicket. Burn all three spots and it crumbles. R resets.",
		Vector2(720, 180))
	_fire_room(5)
	# Frame (90 columns).
	_earth(0, 0, 90, 1)
	_earth(0, 0, 1, 23)
	_earth(89, 0, 1, 23)
	_earth(0, 20, 90, 3)

	# 1. The climb and the ride over the spikes, the high diamond.
	_earth(7, 17, 1, 3)
	_spikes("RideSpikes", 8, 19, 20)
	_earth(28, 17, 1, 3)
	_add(ELEPHANT_SCENE, "RideElephant", Vector2(144, 160))
	_fire_diamond("RideDiamond", Vector2(152, 64), 1)

	# 2. The pen with the stone wall, two ledges, the chamber behind.
	_earth(31, 18, 1, 2)
	_earth(34, 10, 8, 1)
	_earth(47, 10, 5, 1)
	_add(ELEPHANT_SCENE, "ChargeElephant", Vector2(352, 160), {"start_direction": -1})
	_add(STONE_WALL_SCENE, "StoneWall", Vector2(54 * TILE, 11 * TILE), {"wall_size_tiles": Vector2i(2, 9)})
	_earth(54, 1, 2, 10)
	_fire_diamond("ChamberDiamond", Vector2(460, 150), 2)
	_earth(60, 17, 1, 3)

	# 3. The thicket wall.
	_thicket(82, 10, 2, 10)
	_earth(82, 1, 2, 9)
	_add(ELEPHANT_SCENE, "ThicketElephant", Vector2(560, 160))

	_finish_room(Vector2(24, 160), "res://tests/rooms/room_fire_l.tscn")

class_name Room
extends Node2D
## One room (one "screen", or a bit more if it scrolls). Base script for every room scene.
##
## A room is just a rectangle in world space plus its contents:
##   - bounds:       starts at this node's position, size `room_size`
##   - SpawnPoint:   a Marker2D child; the player respawns here after dying in this room
##   - solids:       a TileMapLayer child named "Tiles" (the real rooms, room_01..05),
##                   painted with resources/tiles/placeholder_tileset.tres. The
##                   tileset gives every tile collision on layer 1 ("world"), so the
##                   TileMapLayer IS the ground; this script doesn't need to touch it.
##                   Older test rooms instead list `solid_rects` (an editable list in
##                   the Inspector), turned into blocks in _ready(). Both can be mixed.
##   - anything else (spikes, crates, enemies...) as child nodes
##
## Rooms are placed next to each other in one world scene. "Exits" are simply openings
## in the walls: walking through one puts the player inside the neighbouring room's
## bounds, and RoomManager (the world's root script) notices and slides the camera over.
## Rooms don't know about each other or the camera; RoomManager does all of that.
##
## Earth (Earth chapter): an optional second TileMapLayer child named "Earth" with the
## EarthLayer script (scenes/objects/earth/earth_layer.gd), painted with the earth
## tileset. It's solid like "Tiles", but each of its cells can be bent once.
## Rooms with an Earth layer also get a GroundPainter (made in _ready): it draws the
## ground as lumpy, depth-shaded earth, turf and stone instead of tiles (Stage E4b),
## and a PebbleField (Stage E4d) for the pebbles earth bending leaves lying around.
## Rooms with `painted_ground` on (the level editor's) get the painter too.
## Rooms where fire is allowed that have a "Grass" layer also get a FireGrid (Stage
## F5): the grass there burns, spreads and turns to ash. So do rooms with a
## "Thicket" (ThicketLayer) or "Overgrown" (OvergrownLayer) layer (Stage F6): thicket
## burns away, covers flash over.
## Rooms with a "Water" layer (WaterLayer, Stage W1) get a WaterWorld: the painted
## water becomes pools that slosh, flow and spill (Water_bending.md §6). Water is
## there whether or not Water bending is allowed in the room (`water_allowed`).
##
## Resetting: puzzle objects (crates, windmills, leaves, doors) join the group
## RESETTABLE_GROUP and have a reset() method. RoomManager calls reset_objects() on
## the room when the player respawns in it, so a crate pushed into a corner never
## leaves the room unsolvable: dying or pressing R puts everything back.

## Color for solid ground (GAME_DESIGN.md §2: dark gray).
const SOLID_COLOR: Color = Color(0.25, 0.25, 0.28)
## Group for objects that go back to their starting state on reset_objects().
const RESETTABLE_GROUP: StringName = &"room_resettable"
## DEPTHS (Level_editor.md §5a): rooms can sit BEHIND other rooms. Depth 0 is the
## front, 1 is behind it, 2 behind that... On the map a room has a MAP position;
## in the world each depth lives in its own BAND, this far further down
## (world = map + depth * DEPTH_SPACING), so rooms of different depths never touch:
## no physics between them, and everything that works room to room (RoomManager,
## the camera, room sleeping) works inside a band unchanged. A room's depth is
## simply which band it's in (get_depth), so it can never disagree with its place.
## 20 000 px is over 100 screens: no level comes near it, and positions this big
## are still exact to a hundredth of a pixel.
const DEPTH_SPACING: float = 20000.0
## The RoomEdgeRim every room makes in _ready.
const RIM_NAME: StringName = &"EdgeRim"

## Human-readable name, e.g. "First Breath". Shown in the debug room picker (F2).
@export var display_title: String = ""
## Size of the room in pixels. 320x180 = exactly one screen (camera stays still);
## bigger rooms make the camera scroll inside them.
@export var room_size: Vector2 = Vector2(320, 180)
## Solid blocks, in pixels, relative to the room's top-left corner. Each Rect2 is
## (x, y, width, height). Used by the test rooms; new rooms paint a TileMapLayer instead.
@export var solid_rects: Array[Rect2] = []

@export_group("Elements")
## Which bending elements work in this room. The Earth chapter's rooms are
## Earth-only (Earth_bending.md §11), so a gust or glide can't skip their puzzles.
## The player asks through Player.is_element_allowed(); the room only stores the flags.
## Air: glide and gust.
@export var air_allowed: bool = true
## Earth: column, boulder and snake.
@export var earth_allowed: bool = true
## EXPERIMENT (after Stage E5): one key for column AND snake in this room. A's quick
## tap (released while the shadow is still under the feet) raises a column under you;
## once the shadow has crawled off, releasing A brings a SNAKE out instead of a column.
## D still makes snakes. EarthTuning.one_key_column_snake turns it on everywhere.
@export var one_key_column_snake: bool = false
## Fire: fireball and flame jet (Fire_bending.md). Off by default, unlike Air and
## Earth: the fire pips are always drawn where fire is allowed, so the Air and Earth
## chapters (and their test rooms) keep a clean HUD without being regenerated.
@export var fire_allowed: bool = false
## Fire pips the player has in this room. Pips are PER ROOM (Fire_bending.md §13):
## entering the room, dying or R sets the fire bar to this, and leftovers from the
## previous room are dropped. Clamped to FireTuning.max_pips.
@export_range(0, 10) var fire_start_pips: int = 0
## Water: the water hands and the freeze (Water_bending.md, Stage W3+). Off by
## default like Fire. Painted water (the "Water" layer) is real water either way: it
## sloshes and flows even where the player can't bend it.
@export var water_allowed: bool = false

@export_group("Look")
## Draw this room's ground with a GroundPainter (crust, hatching, lumpy edges) even
## without an Earth layer: gray ground then looks like stone instead of flat tiles.
## Rooms made in the level editor have it on; the chapters' rooms keep their
## plain tiles. (A room with an Earth layer always gets the painter.)
@export var painted_ground: bool = false
## The parallax background behind this room (scenes/backdrop/): a mountain range,
## a temple hall, a forest, a desert or the deep sea. AUTO picks from the room's
## contents (get_backdrop_theme); NONE shows the plain background color. Walking
## into a room with another look scrolls to it.
@export var backdrop_theme: Backdrop.Look = Backdrop.Look.AUTO
## Where in that setting the room is: UNDERGROUND (caves, crypts, roots), SURFACE,
## or SKYLINE (high up). AUTO picks from the room's height compared with the
## level's start room (get_backdrop_altitude), so a level that climbs or digs
## moves through the three by itself; set it by hand where that guess is wrong.
@export var backdrop_altitude: Backdrop.Altitude = Backdrop.Altitude.AUTO

@onready var spawn_point: Marker2D = $SpawnPoint


func _ready() -> void:
	for rect: Rect2 in solid_rects:
		_add_solid_block(rect)
	# Before the painter, which finds the grid and paints burnt grass.
	if fire_allowed and _has_burnable_layer():
		_add_fire_grid()
	if get_node_or_null("Earth") is EarthLayer:
		_add_ground_painter()
		_add_pebble_field()
	elif painted_ground:
		_add_ground_painter()
	if get_node_or_null("Water") is WaterLayer or _has_water_source(self):
		_add_water_world()
	# A crust outside the edge tiles, for when the room is seen from another depth.
	var rim: RoomEdgeRim = RoomEdgeRim.new()
	rim.name = RIM_NAME
	add_child(rim)


## Adds the GroundPainter right after the tile layers, so it draws where the tiles
## did: under every object in the room.
func _add_ground_painter() -> void:
	var painter: GroundPainter = GroundPainter.new()
	painter.name = "GroundPainter"
	var last_layer_index: int = 0
	for child: Node in get_children():
		if child is TileMapLayer:
			last_layer_index = child.get_index()
	add_child(painter)
	move_child(painter, last_layer_index + 1)


## Adds the room's PebbleField at the room's origin (its local coordinates are the
## room's). Added last, so it draws over the ground; its z_index puts it in front of
## the player's feet too.
func _add_pebble_field() -> void:
	var field: PebbleField = PebbleField.new()
	field.name = "PebbleField"
	add_child(field)


## True if the room has ground that burns: grass (Stage F5), thicket or an overgrown
## cover (Stage F6).
func _has_burnable_layer() -> bool:
	return get_node_or_null("Grass") is GrassLayer or get_node_or_null("Thicket") is ThicketLayer \
		or get_node_or_null("Overgrown") is OvergrownLayer


## Adds the room's FireGrid (Stage F5) at the room's origin: the fire states of its
## grass, thicket and covers, spread and flames. Only rooms where fire is allowed
## can burn.
func _add_fire_grid() -> void:
	var grid: FireGrid = FireGrid.new()
	grid.name = "FireGrid"
	add_child(grid)


## Adds the room's WaterWorld (Stage W1) at the room's origin: it turns the painted
## water into pools and moves all the room's water. Like the FireGrid, it belongs to
## play only: RoomLook takes it out of rooms being edited.
func _add_water_world() -> void:
	var water_world: WaterWorld = WaterWorld.new()
	water_world.name = WaterWorld.NODE_NAME
	add_child(water_world)


## Is there a WaterSource (Stage W2) anywhere under `node`? A room with one needs a
## WaterWorld even with no painted water.
func _has_water_source(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is WaterSource or _has_water_source(child):
			return true
	return false


## The nearest Room above `node` in the tree (its own room), or null.
## Static: called on the class, Room.find_room_of(self).
static func find_room_of(node: Node) -> Room:
	var ancestor: Node = node.get_parent()
	while ancestor != null and not ancestor is Room:
		ancestor = ancestor.get_parent()
	return ancestor as Room


## The room's rectangle in world coordinates.
func get_bounds() -> Rect2:
	return Rect2(global_position, room_size)


## How far down (world px) depth `depth`'s band is from the map (depth 0).
static func depth_offset(depth: int) -> Vector2:
	return Vector2(0.0, depth * DEPTH_SPACING)


## The depth whose band holds the world height `world_y` (each band reaches half a
## DEPTH_SPACING above and below its map's 0).
static func depth_at(world_y: float) -> int:
	return roundi(world_y / DEPTH_SPACING)


## A world point moved onto the map (its band's offset taken off).
static func to_map_point(world_point: Vector2) -> Vector2:
	return world_point - depth_offset(depth_at(world_point.y))


## This room's depth: 0 = the front, 1 = behind it... (see DEPTH_SPACING). From
## its middle, so a room reaching a little above its band's 0 still counts.
func get_depth() -> int:
	return depth_at(global_position.y + room_size.y / 2.0)


## The room's top-left corner on the map: where it is, minus its band's offset.
## Rooms of different depths may share map positions (one is behind the other).
func get_map_position() -> Vector2:
	return global_position - depth_offset(get_depth())


## The room's rectangle on the map (get_map_position). Everything that compares
## rooms of different depths by place or height uses this, not get_bounds().
func get_map_bounds() -> Rect2:
	return Rect2(get_map_position(), room_size)


## The backdrop look this room shows (Backdrop asks on every room change).
## backdrop_theme, or for AUTO a guess from what the room holds, one look per
## element's chapter: water -> the deep sea, fire or thicket -> forest, an Earth
## layer -> desert, anything else -> mountains (Air). TEMPLE is only ever chosen.
func get_backdrop_theme() -> Backdrop.Look:
	if backdrop_theme != Backdrop.Look.AUTO:
		return backdrop_theme
	if water_allowed or get_node_or_null("Water") is WaterLayer:
		return Backdrop.Look.UNDERWATER
	if fire_allowed or get_node_or_null("Thicket") is ThicketLayer:
		return Backdrop.Look.FOREST
	if get_node_or_null("Earth") is EarthLayer:
		return Backdrop.Look.DESERT
	return Backdrop.Look.MOUNTAIN


## The backdrop altitude this room shows: backdrop_altitude, or for AUTO, from
## where the room's middle is compared with the level's start room `start_room`
## (the "ground floor"): below its bottom edge -> UNDERGROUND, above its top edge
## -> SKYLINE, otherwise SURFACE. A room level with the start, or overlapping its
## height, is on the surface. Without a start room: SURFACE. Heights are compared
## on the map, so a room behind another reads at the same altitude as it.
func get_backdrop_altitude(start_room: Room) -> Backdrop.Altitude:
	if backdrop_altitude != Backdrop.Altitude.AUTO:
		return backdrop_altitude
	if start_room == null or not is_instance_valid(start_room):
		return Backdrop.Altitude.SURFACE
	var start_bounds: Rect2 = start_room.get_map_bounds()
	var middle_y: float = get_map_bounds().get_center().y
	if middle_y > start_bounds.end.y:
		return Backdrop.Altitude.UNDERGROUND
	if middle_y < start_bounds.position.y:
		return Backdrop.Altitude.SKYLINE
	return Backdrop.Altitude.SURFACE


## Where the player's feet go when respawning in this room.
func get_spawn_position() -> Vector2:
	return spawn_point.global_position


## Puts every resettable object inside THIS room back to its starting state.
## get_nodes_in_group() returns the group's members from the whole game, so we keep
## only our own descendants (is_ancestor_of). Duck typing again: call("reset").
func reset_objects() -> void:
	for member: Node in get_tree().get_nodes_in_group(RESETTABLE_GROUP):
		if is_ancestor_of(member):
			member.call(&"reset")


## Puts only this room's ENEMIES back to their starting state (Stage F11b). The room
## manager calls it when the player walks into the room: creatures sleep outside the
## player's room, so without this they'd be found frozen wherever they were left.
## (Doors, crates, fire and the rest keep their state until a death or R.)
func reset_enemies() -> void:
	for member: Node in get_tree().get_nodes_in_group(EnemyHit.GROUP):
		if is_ancestor_of(member) and member.is_in_group(RESETTABLE_GROUP):
			member.call(&"reset")


## Creates a StaticBody2D (an immovable solid on physics layer 1, "world") with a
## matching collision shape and gray rectangle.
func _add_solid_block(rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.position

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	# CollisionShape2D is positioned by its CENTER, so offset by half the size.
	shape.position = rect.size / 2.0
	body.add_child(shape)

	var visual: ColorRect = ColorRect.new()
	visual.size = rect.size
	visual.color = SOLID_COLOR
	body.add_child(visual)

	add_child(body)

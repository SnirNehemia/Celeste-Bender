class_name PaletteCatalog
extends RefCounted
## PaletteCatalog: everything the level editor can place, one entry per thing
## (Level_editor.md §6). The palette's buttons are built from this list, and the
## editor asks it how to make, find, outline, place and copy each kind of object,
## so the editor itself holds no per-object code.
##
## Families: Terrain (Ground; Earth since L8), Basics (spawn point, goal, spikes;
## Stage L3), Air (Stage L4), Earth (Stage L8). Later stages add Fire and enemies.
## CROSS-TRACK RULE (CLAUDE.md): a stage that adds a placeable object adds its
## entry here. A new entry needs: its scene, how its outline is found (`bounds`
## + the size property or a fixed rectangle), how it lands on the grid
## (`placement`), and the lists the property panel (L5) and links (L6) use.
##
## How a level node is matched to its entry (entry_for_node):
##   - an object made from a scene file: its `scene_file_path` equals the entry's scene
##   - the spawn point: a Marker2D named "SpawnPoint" (Room expects exactly that)
##
## Coordinates: an object's OUTLINE is a rectangle relative to its own origin
## (get_local_bounds). Objects put their origin in different places (a door at its
## top-left corner, a crate at its feet, a crystal at its center), and the outline
## hides that: placing and snapping work on the outline, then convert back.

## What kind of thing an entry is; the editor handles each kind its own way.
enum Kind {
	TERRAIN,      ## a brush that paints a TileMapLayer (TileBrush)
	SPAWN_POINT,  ## the room's SpawnPoint marker: one per room, moved, never deleted
	OBJECT,       ## an instance of `scene`, placed with a click
	STRIP,        ## an instance of `scene` laid along a row or column (spikes)
	ERASER,       ## not a thing to place: the tool that removes whatever is clicked
}

## How an object's outline is worked out, relative to its origin.
enum Bounds {
	SPAWN_MARKER,        ## the small standing figure the overlay draws at the feet
	SPIKE_STRIP,         ## tile_count tiles along the strip, one tile thick
	SIZE_TOP_LEFT,       ## Rect2(origin, <size_property>): door, zones, goal
	SIZE_BOTTOM_CENTER,  ## <size_property> standing on the origin: crate
	WIDTH_CENTERED,      ## <width_property> wide around the origin, `local_rect`'s y and height: platforms, plate
	FIXED,               ## `local_rect` as is: crystals, windmill
}

## Where a newly placed object's OUTLINE goes, relative to the clicked tile.
## Across (and for CENTERED, also up-down), an outline that's an even number of
## tiles wide is centered on the tile line nearest the mouse, so its edges stay on
## the grid; other widths are centered on the tile's middle.
enum Placement {
	TOP_LEFT,  ## its top-left corner on the tile's top-left corner (doors, zones)
	ON_FLOOR,  ## its bottom on the tile's bottom: it stands there (crate, goal, plate)
	HANGING,   ## its top on the tile's top (platforms)
	CENTERED,  ## centered on the tile (crystals, windmill)
}

## One placeable thing. An inner class: PaletteCatalog.Entry.
class Entry:
	extends RefCounted
	var id: StringName
	var display_name: String
	## One or two sentences about what it does: what triggers it (a switch), what it
	## triggers (a door), what breaks or burns it. Shown as the palette button's
	## floating tooltip, in the status line when chosen, and in the property panel.
	var hint: String = ""
	## Palette tab the button goes in.
	var family: String
	var kind: Kind
	## Object kinds: the scene to instantiate.
	var scene: PackedScene = null
	## Outline: how it's found, from these properties / this rectangle.
	var bounds: Bounds = Bounds.FIXED
	var size_property: StringName = &""
	## Pixels per unit of `size_property`: 1 for sizes in pixels (a door's
	## door_size), TILE for sizes in tiles (a wall's wall_size_tiles, a Vector2i).
	var size_unit: int = 1
	var width_property: StringName = &""
	var local_rect: Rect2 = Rect2(-4, -4, 8, 8)
	var placement: Placement = Placement.TOP_LEFT
	## A big see-through area (a wind or no-glide zone) that other things sit
	## inside. Clicking inside it must reach those things, so the editor picks an
	## area only by its outline's edge (or anywhere, with its own tool or the eraser).
	var is_area: bool = false
	## Things the object doesn't draw itself while editing (a wind zone is only
	## moving particles) get a filled stand-in in this color; transparent = none.
	var editor_color: Color = Color.TRANSPARENT
	## A Vector2 property the overlay shows as an arrow from the outline's center
	## (the wind zone's direction). Empty = none.
	var arrow_property: StringName = &""
	## Design settings the property panel shows (Stage L5): never tuning numbers.
	var editable_properties: Array[StringName] = []
	## Vector2 properties that are points relative to the object, given drag
	## handles in Stage L5 (a leaf's travel, a sail's rail ends).
	var point_properties: Array[StringName] = []
	## The Array property that holds this object's links (Stage L6), and the class
	## name its targets must have (e.g. a Door's `switches` <- "Switch").
	var link_property: StringName = &""
	var link_target_class: StringName = &""
	## Positions the object works out once in _ready() from where it stands (a
	## leaf's home, a sail's rail ends) and draws from. Moving it in the editor
	## must update them, or its path stays drawn where it was. Each entry is
	## {runtime property: export offset added to `position`}, &"" = no offset.
	var start_positions: Dictionary = {}
	## Terrain kind: the room's layer name, and the tileset and script a new
	## layer gets (null = a plain TileMapLayer).
	var layer_name: StringName = &""
	var tile_set: TileSet = null
	var layer_script: Script = null
	## Terrain kind: the atlas cells the brush paints, plain and with a top edge
	## (the same cell when the tileset has one tile). See TileBrush.
	var tile_plain: Vector2i = TileBrush.TILE_PLAIN
	var tile_top_edge: Vector2i = TileBrush.TILE_TOP_EDGE
	## Terrain kind: room settings set the first time this terrain is painted in a
	## room ({setting: value}): a room with Earth painted allows Earth (Stage L8).
	var room_settings_on_create: Dictionary = {}

	func _init(new_id: StringName, new_name: String, new_family: String, new_kind: Kind) -> void:
		id = new_id
		display_name = new_name
		family = new_family
		kind = new_kind


const TILE: int = 8
const SPAWN_POINT_NAME: StringName = &"SpawnPoint"
## Same as EditorOverlay's spawn marker: 6x12 standing on the feet point.
const SPAWN_MARKER_SIZE: Vector2 = Vector2(6, 12)
## Light blue, see-through: the air color of GAME_DESIGN.md §2.
const WIND_STAND_IN_COLOR: Color = Color(0.6, 0.85, 1.0, 0.18)

## All entries, in palette order. Built once, on first use.
static var _entries: Array[Entry] = []


static func get_entries() -> Array[Entry]:
	if _entries.is_empty():
		_build()
	return _entries


static func get_entry(id: StringName) -> Entry:
	for entry: Entry in get_entries():
		if entry.id == id:
			return entry
	return null


## The families in palette order (one tab each). Entries without a family (the
## eraser) get no tab: the palette shows them above the tabs.
static func get_families() -> Array[String]:
	var families: Array[String] = []
	for entry: Entry in get_entries():
		if entry.family != "" and not families.has(entry.family):
			families.append(entry.family)
	return families


static func _build() -> void:
	# --- Tools (no family: shown above the tabs) ---
	var eraser: Entry = _add(&"eraser", "Eraser", "", Kind.ERASER)
	eraser.hint = "Removes the object under the mouse (zones from inside too), else the tiles of every layer. Shift+drag: a whole block, objects inside it too."

	# --- Terrain ---
	var ground: Entry = _add(&"ground", "Ground", "Terrain", Kind.TERRAIN)
	ground.hint = "Plain solid stone. Nothing breaks or burns it, and the earth bend shadow can't cross it."
	ground.layer_name = &"Tiles"
	ground.tile_set = preload("res://resources/tiles/placeholder_tileset.tres")

	# --- Basics (Stage L3) ---
	var spawn: Entry = _add(&"spawn_point", "Spawn point", "Basics", Kind.SPAWN_POINT)
	spawn.hint = "Where the player starts (in the start room) and comes back after dying in this room. One per room: move it, it can't be deleted."
	spawn.bounds = Bounds.SPAWN_MARKER

	var goal: Entry = _add_object(&"goal", "Goal", "Basics", preload("res://scenes/objects/goal.tscn"))
	goal.hint = "Touching it finishes the level."
	goal.bounds = Bounds.SIZE_TOP_LEFT
	goal.size_property = &"goal_size"
	goal.placement = Placement.ON_FLOOR
	goal.editable_properties = [&"goal_size"]

	var spikes: Entry = _add(&"spikes", "Spikes", "Basics", Kind.STRIP)
	spikes.hint = "Kill on touch. Knocking an enemy into them defeats it. Drag along a row or column; they point away from the ground next to them (R turns them)."
	spikes.scene = preload("res://scenes/objects/spikes.tscn")
	spikes.bounds = Bounds.SPIKE_STRIP
	spikes.editable_properties = [&"facing", &"tile_count"]

	# --- Air (Stage L4; GAME_DESIGN.md §6) ---
	var wind_zone: Entry = _add_object(&"wind_zone", "Wind zone", "Air", preload("res://scenes/objects/wind_zone.tscn"))
	wind_zone.hint = "Pushes the player while inside, in its direction (currents and updrafts). With Heat on it's a hot updraft (fire)."
	wind_zone.bounds = Bounds.SIZE_TOP_LEFT
	wind_zone.size_property = &"zone_size"
	wind_zone.is_area = true
	wind_zone.editor_color = WIND_STAND_IN_COLOR
	wind_zone.arrow_property = &"wind_direction"
	wind_zone.editable_properties = [&"zone_size", &"wind_direction", &"wind_strength", &"heat"]

	# Crystals bob 1.5 px, so the outline is a little bigger than the diamond.
	var wind_crystal: Entry = _add_object(&"wind_crystal", "Wind crystal", "Air", preload("res://scenes/objects/wind_crystal.tscn"))
	wind_crystal.hint = "Touch: refills the dash and the gust charge. Comes back after a few seconds, or when the room resets."
	wind_crystal.local_rect = Rect2(-6, -7, 12, 14)
	wind_crystal.placement = Placement.CENTERED
	wind_crystal.editable_properties = [&"respawn_time"]

	var gust_diamond: Entry = _add_object(&"gust_diamond", "Gust diamond", "Air", preload("res://scenes/objects/gust_diamond.tscn"))
	gust_diamond.hint = "Touch: two gust charges for this airtime. Comes back after a few seconds, or when the room resets."
	gust_diamond.local_rect = Rect2(-7, -9, 14, 18)
	gust_diamond.placement = Placement.CENTERED
	gust_diamond.editable_properties = [&"respawn_time"]

	var crate: Entry = _add_object(&"crate", "Crate", "Air", preload("res://scenes/objects/crate.tscn"))
	crate.hint = "Pushed only by wind (gusts slide it). Heavy: it holds a pressure plate down. You can stand on it. Fire burns it. Links (L): the vines it hangs from."
	crate.bounds = Bounds.SIZE_BOTTOM_CENTER
	crate.size_property = &"crate_size"
	crate.placement = Placement.ON_FLOOR
	crate.editable_properties = [&"crate_size"]
	# A crate's links are the VINES it hangs from (Fire F8): linked to a plate or
	# windmill it would float, waiting for a vine to snap. Vines join in L9.
	crate.link_property = &"hung_from"
	crate.link_target_class = &"Vine"

	# The hub is the origin; the blades reach Windmill.HIT_RADIUS (11 px) round it.
	var windmill: Entry = _add_object(&"windmill", "Windmill", "Air", preload("res://scenes/objects/windmill.tscn"))
	windmill.hint = "A switch: a gust spins it and powers the doors linked to it for a few seconds, refreshed by every gust."
	windmill.local_rect = Rect2(-11, -11, 22, 22)
	windmill.placement = Placement.CENTERED
	windmill.editable_properties = [&"spin_time", &"post_length"]

	# The origin is the middle of the leaf's top; the pinwheel hangs 8-12 px below.
	var leaf_platform: Entry = _add_object(&"leaf_platform", "Leaf platform", "Air", preload("res://scenes/objects/leaf_platform.tscn"))
	leaf_platform.hint = "One-way platform on a rail: any gust sends it to the far end, then it drifts home. Fire burns it away."
	leaf_platform.bounds = Bounds.WIDTH_CENTERED
	leaf_platform.width_property = &"leaf_width"
	leaf_platform.local_rect = Rect2(0, 0, 0, 12)
	leaf_platform.placement = Placement.HANGING
	leaf_platform.editable_properties = [&"leaf_width", &"travel", &"hover_time"]
	leaf_platform.point_properties = [&"travel"]
	leaf_platform.start_positions = {&"home_position": &""}

	# The origin is the middle of the deck's top; the mast rises 16 px above it.
	var sail_platform: Entry = _add_object(&"sail_platform", "Sail platform", "Air", preload("res://scenes/objects/sail_platform.tscn"))
	sail_platform.hint = "One-way deck on a rail that moves with the wind: gusts and wind zones push it. A burning sail stops catching wind."
	sail_platform.bounds = Bounds.WIDTH_CENTERED
	sail_platform.width_property = &"deck_width"
	sail_platform.local_rect = Rect2(0, -16, 0, 20)
	sail_platform.placement = Placement.ON_FLOOR
	sail_platform.editable_properties = [&"deck_width", &"rail_start", &"rail_end"]
	sail_platform.point_properties = [&"rail_start", &"rail_end"]
	sail_platform.start_positions = {&"rail_start_position": &"rail_start", &"rail_end_position": &"rail_end"}

	var door: Entry = _add_object(&"door", "Door", "Air", preload("res://scenes/objects/door.tscn"))
	door.hint = "Opens or closes by its linked switches (L): pressure plates, windmills. Any or all of them, or inverted. Won't close on you or a crate."
	door.bounds = Bounds.SIZE_TOP_LEFT
	door.size_property = &"door_size"
	door.editable_properties = [&"door_size", &"link_mode", &"open_when_off", &"retract_toward"]
	door.link_property = &"switches"
	door.link_target_class = &"Switch"

	# The origin is the middle of the plate's bottom, on the floor; it's 3 px tall.
	var pressure_plate: Entry = _add_object(&"pressure_plate", "Pressure plate", "Air", preload("res://scenes/objects/pressure_plate.tscn"))
	pressure_plate.hint = "A switch: on while something heavy (a crate) sits on it. The player is too light. Link it to a door from the door (L)."
	pressure_plate.bounds = Bounds.WIDTH_CENTERED
	pressure_plate.width_property = &"plate_width"
	pressure_plate.local_rect = Rect2(0, -4, 0, 4)
	pressure_plate.placement = Placement.ON_FLOOR
	pressure_plate.editable_properties = [&"plate_width"]

	var no_glide_zone: Entry = _add_object(&"no_glide_zone", "No-glide zone", "Air", preload("res://scenes/objects/no_glide_zone.tscn"))
	no_glide_zone.hint = "Dead air: gliding can't start inside it and a glide drifting in ends. Jump, dash and gust still work."
	no_glide_zone.bounds = Bounds.SIZE_TOP_LEFT
	no_glide_zone.size_property = &"zone_size"
	no_glide_zone.is_area = true
	no_glide_zone.editable_properties = [&"zone_size"]

	# --- Earth (Stage L8; Earth_bending.md) ---
	# Bendable earth: the EarthLayer script on an "Earth" layer. A room that has one
	# is drawn by its GroundPainter (RoomLook keeps it up to date while editing).
	var earth: Entry = _add(&"earth", "Earth", "Terrain", Kind.TERRAIN)
	earth.hint = "Bendable earth: each tile bends once (columns, rocks, snake) until the room resets. Painting it turns Earth on in the room."
	earth.layer_name = &"Earth"
	earth.tile_set = preload("res://resources/tiles/earth_tileset.tres")
	earth.layer_script = preload("res://scenes/objects/earth/earth_layer.gd")
	# One tile (tools/build_earth_rooms.gd TILE_EARTH): the painter draws surfaces.
	earth.tile_plain = Vector2i(0, 0)
	earth.tile_top_edge = Vector2i(0, 0)
	earth.room_settings_on_create = {&"earth_allowed": true}

	# Walls are placed by their top-left corner and sized in whole tiles.
	var cracked_wall: Entry = _add_object(&"cracked_wall", "Cracked wall", "Earth", preload("res://scenes/objects/earth/cracked_wall.tscn"))
	cracked_wall.hint = "Solid until a thrown BIG rock hits it: then it breaks open. Small rocks, columns and the snake just bump into it. Fire doesn't burn it. Back on reset."
	cracked_wall.bounds = Bounds.SIZE_TOP_LEFT
	cracked_wall.size_property = &"wall_size_tiles"
	cracked_wall.size_unit = TILE
	cracked_wall.editable_properties = [&"wall_size_tiles"]

	# Only a charging thicket elephant breaks it (Fire F11b); listed with Earth's walls.
	var stone_wall: Entry = _add_object(&"stone_wall", "Stone wall", "Earth", preload("res://scenes/objects/stone_wall.tscn"))
	stone_wall.hint = "Much stronger than a cracked wall: rocks shatter on it and fire does nothing. Only a charging thicket elephant breaks it. Back on reset."
	stone_wall.bounds = Bounds.SIZE_TOP_LEFT
	stone_wall.size_property = &"wall_size_tiles"
	stone_wall.size_unit = TILE
	stone_wall.editable_properties = [&"wall_size_tiles"]

	# Rock spots (RockSpot): a loose rock lies there from the start and after every
	# reset. The origin is the rock's center; it stands on the clicked tile.
	var boulder: Entry = _add_object(&"boulder", "Boulder", "Earth", preload("res://scenes/objects/earth/boulder_spot.tscn"))
	boulder.hint = "A big loose rock lies here from the start and after every reset: stand on it, lift and throw it with S. A thrown big rock breaks cracked walls. At most 3 loose rocks per room."
	boulder.local_rect = Rect2(-8, -8, 16, 16)
	boulder.placement = Placement.ON_FLOOR

	var loose_rock: Entry = _add_object(&"loose_rock", "Loose rock", "Earth", preload("res://scenes/objects/earth/loose_rock_spot.tscn"))
	loose_rock.hint = "A small loose rock lies here from the start and after every reset: lift and throw it with S. Too light to break a cracked wall. At most 3 loose rocks per room."
	loose_rock.local_rect = Rect2(-4, -4, 8, 8)
	loose_rock.placement = Placement.ON_FLOOR


static func _add(id: StringName, display_name: String, family: String, kind: Kind) -> Entry:
	var entry: Entry = Entry.new(id, display_name, family, kind)
	_entries.append(entry)
	return entry


static func _add_object(id: StringName, display_name: String, family: String, scene: PackedScene) -> Entry:
	var entry: Entry = _add(id, display_name, family, Kind.OBJECT)
	entry.scene = scene
	return entry


## The entry a level node was made from, or null if it isn't a catalog object.
static func entry_for_node(node: Node) -> Entry:
	if node is Marker2D and node.name == SPAWN_POINT_NAME:
		return get_entry(&"spawn_point")
	if node.scene_file_path == "":
		return null
	for entry: Entry in get_entries():
		if entry.scene != null and entry.scene.resource_path == node.scene_file_path:
			return entry
	return null


## The object's outline relative to its own origin.
static func get_local_bounds(node: Node2D) -> Rect2:
	var entry: Entry = entry_for_node(node)
	if entry == null:
		return Rect2(Vector2.ZERO, Vector2.ONE * TILE)
	match entry.bounds:
		Bounds.SPAWN_MARKER:
			return Rect2(Vector2(-SPAWN_MARKER_SIZE.x / 2.0, -SPAWN_MARKER_SIZE.y), SPAWN_MARKER_SIZE)
		Bounds.SPIKE_STRIP:
			var spikes: Spikes = node as Spikes
			var length: float = spikes.tile_count * TILE
			var is_horizontal: bool = spikes.facing == Spikes.Facing.UP or spikes.facing == Spikes.Facing.DOWN
			return Rect2(Vector2.ZERO, Vector2(length, TILE) if is_horizontal else Vector2(TILE, length))
		Bounds.SIZE_TOP_LEFT:
			# Vector2(...) also turns a size in tiles (a Vector2i) into a Vector2.
			return Rect2(Vector2.ZERO, Vector2(node.get(entry.size_property)) * entry.size_unit)
		Bounds.SIZE_BOTTOM_CENTER:
			var size: Vector2 = node.get(entry.size_property)
			return Rect2(Vector2(-size.x / 2.0, -size.y), size)
		Bounds.WIDTH_CENTERED:
			var width: float = node.get(entry.width_property)
			return Rect2(-width / 2.0, entry.local_rect.position.y, width, entry.local_rect.size.y)
		_:
			return entry.local_rect


## The object's outline in level (global) coordinates.
static func get_bounds(node: Node2D) -> Rect2:
	var local_bounds: Rect2 = get_local_bounds(node)
	return Rect2(node.global_position + local_bounds.position, local_bounds.size)


## Makes a new object of an OBJECT or STRIP entry (not yet in any room).
static func instantiate(entry: Entry) -> Node2D:
	return entry.scene.instantiate() as Node2D


## Where `node` (an OBJECT entry's, not placed yet) goes, room-local, when clicked
## at `room_point` (room-local pixels). `free`: no grid, its center on the point.
static func placement_position(entry: Entry, node: Node2D, room_point: Vector2, free: bool = false) -> Vector2:
	var outline: Rect2 = get_local_bounds(node)
	var center: Vector2 = room_point
	if not free:
		var cell: Vector2i = Vector2i((room_point / TILE).floor())
		var cell_rect: Rect2 = Rect2(Vector2(cell * TILE), Vector2.ONE * TILE)
		center = Vector2(_snapped_center(room_point.x, outline.size.x, cell_rect.position.x),
			_snapped_center(room_point.y, outline.size.y, cell_rect.position.y))
		match entry.placement:
			Placement.TOP_LEFT:
				center = cell_rect.position + outline.size / 2.0
			Placement.ON_FLOOR:
				center.y = cell_rect.end.y - outline.size.y / 2.0
			Placement.HANGING:
				center.y = cell_rect.position.y + outline.size.y / 2.0
	# Origin = where the outline's top-left must be, minus the outline's offset.
	return center - outline.size / 2.0 - outline.position


## The spawn point's position (room-local feet) for `cell`: bottom middle of the tile.
static func spawn_position(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE)


## True if `target` can be linked from an object of `entry`: its script is the
## entry's `link_target_class` or extends it (a PressurePlate is a Switch).
## A script's class_name is its "global name"; get_base_script() walks up the
## `extends` chain.
static func is_link_target(entry: Entry, target: Node) -> bool:
	if entry == null or entry.link_target_class == &"":
		return false
	var script: Script = target.get_script()
	while script != null:
		if script.get_global_name() == entry.link_target_class:
			return true
		script = script.get_base_script()
	return false


## Updates the start-up positions of `node` (see Entry.start_positions) after it
## moved in the editor, and redraws it.
static func sync_start_positions(node: Node2D) -> void:
	var entry: Entry = entry_for_node(node)
	if entry == null or entry.start_positions.is_empty():
		return
	for runtime_property: StringName in entry.start_positions:
		var offset_property: StringName = entry.start_positions[runtime_property]
		var offset: Vector2 = Vector2.ZERO if offset_property == &"" else node.get(offset_property)
		node.set(runtime_property, node.position + offset)
	node.queue_redraw()


## Copies `source`'s saved script settings onto `target` (a fresh object of the
## same scene): sizes, facing, links... This is how Ctrl+D duplicates. A plain
## Node.duplicate() would also copy the drawing nodes the object built in _ready.
static func copy_settings(source: Node, target: Node) -> void:
	for property: Dictionary in source.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			var value: Variant = source.get(property["name"])
			# Arrays are shared by reference: give the copy its own list.
			target.set(property["name"], value.duplicate() if value is Array else value)


## One axis of a snapped center: an even number of tiles long -> on the tile line
## nearest `point`; otherwise the middle of the tile that starts at `cell_start`.
static func _snapped_center(point: float, length: float, cell_start: float) -> float:
	if is_zero_approx(fmod(length, 2.0 * TILE)):
		return roundf(point / TILE) * TILE
	return cell_start + TILE / 2.0

class_name PaletteCatalog
extends RefCounted
## PaletteCatalog: everything the level editor can place, one entry per thing
## (Level_editor.md §6). The palette's buttons are built from this list, and the
## editor asks it how to make, find, outline, place and copy each kind of object,
## so the editor itself holds no per-object code.
##
## Tabs (`family`, the palette's tabs, TAB_ORDER; reorganized after the L11
## play-test): Terrain, Basics (spawn, goal, spikes, zones), Triggers (switches),
## Activated (what switches work: doors), Crystals (pick-ups), Breakable (walls and
## plant terrain that rocks, elephants or fire open), Objects (crates, platforms,
## rocks, vines, leaves), Enemies. Entries are written below in the order their
## stages added them, with the stage's own family as their ELEMENT (Air, Earth,
## Fire, Water, or none): _assign_tabs() then puts each in its tab (TAB_OF). The element
## colors the palette button (EditorUI) and picks the icon's palette.
## Tools (no tab, a row above the tabs): Select, Eraser, Fill.
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
	SELECT,       ## not a thing to place: picks what's under the mouse (a list if several)
	FILL,         ## not a thing to place: floods a connected area with the last terrain
}

## How an object's outline is worked out, relative to its origin.
enum Bounds {
	SPAWN_MARKER,        ## the small standing figure the overlay draws at the feet
	SPIKE_STRIP,         ## tile_count tiles along the strip, one tile thick
	SIZE_TOP_LEFT,       ## Rect2(origin, <size_property>): door, zones, goal
	SIZE_BOTTOM_CENTER,  ## <size_property> standing on the origin: crate
	WIDTH_CENTERED,      ## <width_property> wide around the origin, `local_rect`'s y and height: platforms, plate
	FIXED,               ## `local_rect` as is: crystals, windmill
	LINE_TO_POINT,       ## from the origin to its first point property, at least LINE_THICKNESS thick: vine
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

## Where the vines an object hangs from are tied to it (its link targets' ends).
## The editor keeps each linked vine's end on that spot when the object is linked,
## moved, resized or turned, and when the vine's anchor moves.
enum TieKind {
	NONE,         ## not a holder
	TOP_CENTER,   ## the middle of its outline's top, half tie_thickness down (a crate)
	CENTER_LINE,  ## the nearest point of its middle line, end to end, turned with it (a plank)
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
	## Palette tab the button goes in ("" = a tool, in the row above the tabs).
	var family: String
	## The chapter element it belongs to: "Air", "Earth", "Fire" or "" (see header).
	var element: String = ""
	var kind: Kind
	## Object kinds: the scene to instantiate.
	var scene: PackedScene = null
	## Outline: how it's found, from these properties / this rectangle.
	var bounds: Bounds = Bounds.FIXED
	var size_property: StringName = &""
	## Pixels per unit of `size_property`: 1 for sizes in pixels (a door's
	## door_size), TILE for sizes in tiles (a wall's wall_size_tiles, a Vector2i).
	var size_unit: int = 1
	## A bool property that, when on, hangs a SIZE_BOTTOM_CENTER outline BELOW the
	## origin instead of standing on it (a sentry mounted on the ceiling).
	var hang_property: StringName = &""
	## Stands on the ground under it, or hangs from the ceiling above it when its
	## `hang_property` is on: placing, dragging or flipping it snaps it there (a
	## sentry, a brazier: things bolted down that would otherwise float).
	var snaps_to_ground: bool = false
	## The outline turns with the node's rotation (a hanging platform stood on end).
	var uses_rotation: bool = false
	## R turns the selected object by this many degrees (0 = R does nothing; spikes
	## turn their own way, through `facing`).
	var rotate_step_degrees: float = 0.0
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
	## Or, instead of a class: the group its targets are in (an EnemyGate's
	## `enemies` <- any enemy, group "enemies"; Stage L10). Enemies join it in
	## _ready(), which runs in the editor too.
	var link_target_group: StringName = &""
	## What a target is called in messages; "" = the class name ("Switch").
	var link_target_label: String = ""
	## Holders (crate, hanging platform): where their linked vines are tied, and how
	## thick they are there (the vine draws coils round anything thicker than 0).
	## The target's first point property is its free end (a vine's end_point).
	var tie_kind: TieKind = TieKind.NONE
	var tie_thickness: float = 0.0
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
	## Terrain kind: layers whose tiles a painted cell ERASES (one terrain per cell, a
	## hidden chamber carved into an earth wall). Same undo step. Set by _assign_carving.
	var carves_layers: Array[StringName] = []
	## More tabs the entry's button also shows in, besides `family` (a hidden chamber
	## is terrain, and also something you break open). Both buttons pick this entry.
	var extra_tabs: Array[String] = []
	## Room settings that come with this thing ({setting: value}). Terrain: set the
	## first time it's painted in a room (a room with Earth painted allows Earth,
	## Stage L8). Objects: set when one is placed or copied there (a brazier turns
	## Fire on, Stage L9). Part of the same undo step.
	var room_settings_on_create: Dictionary = {}

	func _init(new_id: StringName, new_name: String, new_family: String, new_kind: Kind) -> void:
		id = new_id
		display_name = new_name
		family = new_family
		kind = new_kind


const TILE: int = 8
## Terrain layers the carving rule (_assign_carving) treats specially.
const WATER_LAYER_NAME: StringName = &"Water"
const HIDDEN_LAYER_NAME: StringName = &"Hidden"
const SPAWN_POINT_NAME: StringName = &"SpawnPoint"
## Same as EditorOverlay's spawn marker: 6x12 standing on the feet point.
const SPAWN_MARKER_SIZE: Vector2 = Vector2(6, 12)
## Light blue, see-through: the air color of GAME_DESIGN.md §2.
const WIND_STAND_IN_COLOR: Color = Color(0.6, 0.85, 1.0, 0.18)
## The thinnest a LINE_TO_POINT outline gets (a vine is a 1-2 px line), px.
const LINE_THICKNESS: float = 4.0

## The palette's tabs, in order (see the header).
const TAB_ORDER: Array[String] = ["Terrain", "Basics", "Triggers", "Activated", "Crystals", "Breakable", "Objects", "Enemies"]
## Each entry's tab, where it isn't the family it's written with (_assign_tabs).
const TAB_OF: Dictionary = {
	&"wind_zone": "Basics", &"no_glide_zone": "Basics",
	&"pressure_plate": "Triggers", &"windmill": "Triggers", &"brazier": "Triggers", &"enemy_gate": "Triggers",
	&"door": "Activated",
	&"wind_crystal": "Crystals", &"gust_diamond": "Crystals", &"fire_diamond": "Crystals",
	&"cracked_wall": "Breakable", &"stone_wall": "Breakable", &"thicket": "Breakable",
	&"overgrown_grass": "Breakable", &"overgrown_thicket": "Breakable",
	&"crate": "Objects", &"leaf_platform": "Objects", &"sail_platform": "Objects", &"boulder": "Objects",
	&"loose_rock": "Objects", &"vine": "Objects", &"hanging_platform": "Objects", &"leaf_pile": "Objects",
	&"water_source": "Objects", &"water_sink": "Objects",
}
## Elements of entries whose stage family doesn't say it (terrain, enemies).
const ELEMENT_OF: Dictionary = {
	&"earth": "Earth", &"hidden_chamber": "Earth", &"water": "Water", &"ice": "Water", &"thicket": "Fire", &"overgrown_grass": "Fire", &"overgrown_thicket": "Fire",
	&"wisp": "Air", &"sentry": "Air", &"vine_monkey": "Fire", &"thicket_elephant": "Fire", &"shell": "Earth",
}

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


## The families in palette order (one tab each, TAB_ORDER first). Entries without
## a family (the tools) get no tab: the palette shows them above the tabs.
static func get_families() -> Array[String]:
	var families: Array[String] = []
	for family: String in TAB_ORDER:
		for entry: Entry in get_entries():
			if entry.family == family:
				families.append(family)
				break
	for entry: Entry in get_entries():
		if entry.family != "" and not families.has(entry.family):
			families.append(entry.family)
	return families


static func _build() -> void:
	# --- Tools (no family: shown in a row above the tabs) ---
	var select_tool: Entry = _add(&"select", "Select", "", Kind.SELECT)
	select_tool.hint = "Selects the object under the mouse (drag to move it). Where several overlap, a list asks which one. Empty space: the room's settings."
	var eraser: Entry = _add(&"eraser", "Eraser", "", Kind.ERASER)
	eraser.hint = "Removes the object under the mouse (zones from inside too), else the tiles of every layer. Shift+drag: a whole block, objects inside it too."
	var fill: Entry = _add(&"fill", "Fill", "", Kind.FILL)
	fill.hint = "Left: fills the connected area of the same tiles (or of empty air) with the chosen terrain; pick it in the Terrain or Breakable tab. Right: clears that area."

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
	wind_crystal.hint = "Touch: refills the breath (glide) and the gust charge. Comes back after a few seconds, or when the room resets."
	wind_crystal.local_rect = Rect2(-6, -7, 12, 14)
	wind_crystal.placement = Placement.CENTERED
	wind_crystal.editable_properties = [&"respawn_time"]

	var gust_diamond: Entry = _add_object(&"gust_diamond", "Gust diamond", "Air", preload("res://scenes/objects/gust_diamond.tscn"))
	gust_diamond.hint = "Touch: two gust charges for this airtime. Comes back after a few seconds, or when the room resets."
	gust_diamond.local_rect = Rect2(-7, -9, 14, 18)
	gust_diamond.placement = Placement.CENTERED
	gust_diamond.editable_properties = [&"respawn_time"]

	var crate: Entry = _add_object(&"crate", "Crate", "Air", preload("res://scenes/objects/crate.tscn"))
	crate.hint = "Pushed only by wind (gusts slide it). Heavy: it holds a pressure plate down. You can stand on it. Fire burns it. Links (L): the vines it hangs from; on one vine it swings. Is Metal: doesn't burn, and pushes move it half as far."
	crate.bounds = Bounds.SIZE_BOTTOM_CENTER
	crate.size_property = &"crate_size"
	crate.placement = Placement.ON_FLOOR
	crate.editable_properties = [&"crate_size", &"is_metal"]
	# A crate's links are the VINES it hangs from (Fire F8): linked to a plate or
	# windmill it would float, waiting for a vine to snap. Vines join in L9.
	crate.link_property = &"hung_from"
	crate.link_target_class = &"Vine"
	crate.tie_kind = TieKind.TOP_CENTER
	crate.tie_thickness = Crate.KNOT_THICKNESS

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
	no_glide_zone.hint = "Dead air: gliding can't start inside it and a glide drifting in ends. Jump, gust and the flame jet still work."
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

	# Hidden chambers (Stage E4c; in the editor after Stage W2): a "Hidden" layer
	# (HiddenLayer) of open-air cells drawn as deep earth until a dig (or a burnt
	# overgrown cover) reaches them. The brush CARVES: a painted cell loses its solid
	# tiles, so you paint the tunnel's shape into a wall. While editing, a chamber
	# shows open, striped purple (RoomLook, EditorOverlay); a red edge marks where it
	# touches open air (a cover you could walk through). painted_ground: only the
	# GroundPainter draws the cover, and hides it again once it crumbles.
	var hidden_chamber: Entry = _add(&"hidden_chamber", "Hidden chamber", "Terrain", Kind.TERRAIN)
	hidden_chamber.hint = "A secret tunnel: paint it into a wall (it carves the tiles out). In play it looks like deep earth until a dig, a breaking wall or burnt thicket or cover reaches it, then it crumbles open. Red edges: it opens onto the air there, and walking in shows its inside through a mist until you leave. Turns Earth on."
	hidden_chamber.layer_name = &"Hidden"
	hidden_chamber.tile_set = earth.tile_set
	hidden_chamber.layer_script = preload("res://scenes/objects/earth/hidden_layer.gd")
	hidden_chamber.tile_plain = earth.tile_plain
	hidden_chamber.tile_top_edge = earth.tile_plain
	hidden_chamber.extra_tabs = ["Breakable"]
	hidden_chamber.room_settings_on_create = {&"earth_allowed": true, &"painted_ground": true}

	# Breakable walls, painted as terrain (after Stage W2; they were objects sized in
	# tiles before). Each connected group of painted cells is one wall that breaks
	# all at once (WallLayer makes a CrackedWall / StoneWall per group). Breaking one
	# opens the hidden chambers it touches, with a quake. Old wall objects in a level
	# become tiles when it's opened (RoomLook.prepare_for_editing).
	var cracked_wall: Entry = _add(&"cracked_wall", "Cracked wall", "Earth", Kind.TERRAIN)
	cracked_wall.hint = "Paint it like terrain: each connected patch is one wall, solid until a thrown BIG rock hits it, then the whole patch breaks open (and opens hidden chambers behind it). Small rocks, columns and the snake just bump into it. Fire doesn't burn it. Back on reset."
	cracked_wall.layer_name = &"CrackedWalls"
	cracked_wall.tile_set = preload("res://resources/tiles/placeholder_tileset.tres")
	cracked_wall.layer_script = preload("res://scenes/objects/earth/cracked_wall_layer.gd")
	cracked_wall.tile_plain = TileBrush.TILE_PLAIN
	cracked_wall.tile_top_edge = TileBrush.TILE_PLAIN

	# Only a charging thicket elephant breaks it (Fire F11b); listed with Earth's walls.
	var stone_wall: Entry = _add(&"stone_wall", "Stone wall", "Earth", Kind.TERRAIN)
	stone_wall.hint = "Paint it like terrain: each connected patch is one wall, much stronger than a cracked wall: rocks shatter on it and fire does nothing. Only a charging thicket elephant breaks it (and the hidden chambers behind it open). Back on reset."
	stone_wall.layer_name = &"StoneWalls"
	stone_wall.tile_set = cracked_wall.tile_set
	stone_wall.layer_script = preload("res://scenes/objects/stone_wall_layer.gd")
	stone_wall.tile_plain = TileBrush.TILE_TOP_EDGE
	stone_wall.tile_top_edge = TileBrush.TILE_TOP_EDGE

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

	# --- Fire (Stage L9; Fire_bending.md §6, §13) ---
	# Plant terrain, in the Terrain tab. Grass is also the Earth chapter's plain
	# ground, so painting it changes no room setting: it burns only where Fire is
	# allowed. Thicket and covers exist to be burnt, so they turn Fire on. The
	# room's FireGrid (what burns them) is made only in play: Room._ready() makes
	# it, and RoomLook takes it out of rooms being edited.
	var grass: Entry = _add(&"grass", "Grass", "Terrain", Kind.TERRAIN)
	grass.hint = "Green ground the earth shadow can cross. Where Fire is allowed it burns: fire spreads along it, it smolders, then it's ash until the room resets."
	grass.layer_name = &"Grass"
	grass.tile_set = preload("res://resources/tiles/grass_tileset.tres")
	grass.layer_script = preload("res://scenes/objects/earth/grass_layer.gd")
	# tools/build_earth_rooms.gd TILE_GRASS_PLAIN / TILE_GRASS_TOP.
	grass.tile_plain = Vector2i(1, 0)
	grass.tile_top_edge = Vector2i(0, 0)

	var thicket: Entry = _add(&"thicket", "Thicket (burns slowly)", "Terrain", Kind.TERRAIN)
	thicket.hint = "Solid brambles that fire burns THROUGH, tile by tile: a burnt tile crumbles to ash and stays open until the room resets (a burning floor drops you). Burning through opens hidden chambers behind it. Rocks shatter on it. Painting it turns Fire on in the room."
	thicket.layer_name = &"Thicket"
	thicket.tile_set = preload("res://resources/tiles/thicket_tileset.tres")
	thicket.layer_script = preload("res://scenes/objects/fire/thicket_layer.gd")
	thicket.tile_plain = ThicketLayer.THICKET_TILE
	thicket.tile_top_edge = ThicketLayer.THICKET_TILE
	thicket.room_settings_on_create = {&"fire_allowed": true}

	# Two brushes for the same "Overgrown" layer: covers passing for grass ground or
	# for a thicket wall. Fire touching any cell burns the whole connected cover.
	var overgrown_grass: Entry = _add(&"overgrown_grass", "Grass cover (burns at once)", "Terrain", Kind.TERRAIN)
	overgrown_grass.hint = "A cover that looks like grass ground (a shade off, roots poking out): solid, but fire touching it burns the whole connected cover away at once. Hides passages. Turns Fire on."
	overgrown_grass.layer_name = &"Overgrown"
	overgrown_grass.tile_set = thicket.tile_set
	overgrown_grass.layer_script = preload("res://scenes/objects/fire/overgrown_layer.gd")
	overgrown_grass.tile_plain = ThicketLayer.GRASS_LOOK_TILE
	overgrown_grass.tile_top_edge = ThicketLayer.GRASS_LOOK_TILE
	overgrown_grass.room_settings_on_create = {&"fire_allowed": true}

	var overgrown_thicket: Entry = _add(&"overgrown_thicket", "Thicket cover (burns at once)", "Terrain", Kind.TERRAIN)
	overgrown_thicket.hint = "A cover that looks like a thicket wall (a little browner, roots poking out): fire touching ANY tile burns the whole connected cover away at once, unlike real thicket's slow tile-by-tile burn. Opens hidden chambers behind it. Turns Fire on."
	overgrown_thicket.layer_name = &"Overgrown"
	overgrown_thicket.tile_set = thicket.tile_set
	overgrown_thicket.layer_script = overgrown_grass.layer_script
	overgrown_thicket.tile_plain = ThicketLayer.THICKET_TILE
	overgrown_thicket.tile_top_edge = ThicketLayer.THICKET_TILE
	overgrown_thicket.room_settings_on_create = {&"fire_allowed": true}

	# --- Water (Stage W1; Water_bending.md §8.1) ---
	# Painted water: where water stands when the room starts. In play the room's
	# WaterWorld turns it into pools that slosh, flow and spill (Room._ready makes
	# it; RoomLook takes it out of rooms being edited, so here the tiles show).
	var water: Entry = _add(&"water", "Water", "Terrain", Kind.TERRAIN)
	water.hint = "Water, one unit per tile. In play it settles onto the floor under it, makes waves, flows down steps and spills over edges. Not solid: you wade through it. Turns Water on."
	water.layer_name = &"Water"
	water.tile_set = preload("res://resources/tiles/water_tileset.tres")
	water.layer_script = preload("res://scenes/objects/water/water_layer.gd")
	water.tile_plain = WaterLayer.WATER_TILE
	water.tile_top_edge = WaterLayer.WATER_TILE
	water.room_settings_on_create = {&"water_allowed": true}

	# Painted ice (Stage W5; Water_bending.md §7.1): solid ground you slide on. Part of
	# the level: it never melts and doesn't count toward the ice cap.
	var ice: Entry = _add(&"ice", "Ice", "Terrain", Kind.TERRAIN)
	ice.hint = "Solid ice: slow to start and stop on, you keep sliding, and a long run on it builds up speed for a long jump. No grip on its walls. Painted ice never melts."
	ice.layer_name = &"Ice"
	ice.tile_set = preload("res://resources/tiles/ice_tileset.tres")
	ice.layer_script = preload("res://scenes/objects/water/ice_layer.gd")
	ice.tile_plain = IceLayer.ICE_TILE
	ice.tile_top_edge = IceLayer.ICE_TILE

	# Sources and drains (Stage W2; Water_bending.md §6.2, §8.1). A room with a source
	# gets a WaterWorld even without painted water.
	var water_source: Entry = _add_object(&"water_source", "Water source", "Water", preload("res://scenes/objects/water/water_source.tscn"))
	water_source.hint = "Endless water: pours Rate units a second, falling (a waterfall) or, under a pool's surface, into it. Put it over a channel for a stream. Pair it with a Drain, or the room slowly fills."
	water_source.local_rect = Rect2(-4, -5, 8, 6)
	water_source.placement = Placement.CENTERED
	water_source.editable_properties = [&"rate", &"launch_velocity", &"pour_width"]
	water_source.room_settings_on_create = {&"water_allowed": true}

	var water_sink: Entry = _add_object(&"water_sink", "Drain", "Water", preload("res://scenes/objects/water/water_sink.tscn"))
	water_sink.hint = "A drain grate: takes the water that reaches it (up to Max Rate units a second). On a pool's floor it empties the pool; on its side it's an overflow that holds the level at the drain's bottom edge."
	water_sink.bounds = Bounds.SIZE_TOP_LEFT
	water_sink.size_property = &"sink_size"
	water_sink.placement = Placement.TOP_LEFT
	water_sink.editable_properties = [&"sink_size", &"max_rate"]
	water_sink.room_settings_on_create = {&"water_allowed": true}

	# Fire objects turn Fire on in their room. The player still needs pips: the
	# room's Fire Start Pips, or a fire diamond (a play-test warning says so).
	var fire_room: Dictionary = {&"fire_allowed": true}

	var fire_diamond: Entry = _add_object(&"fire_diamond", "Fire diamond", "Fire", preload("res://scenes/objects/fire/fire_diamond.tscn"))
	fire_diamond.hint = "Touch: +1 fire pip (2 for a double). Single use: back only after a death or R. With a full fire bar you leave it there."
	fire_diamond.local_rect = Rect2(-7, -9, 14, 18)
	fire_diamond.placement = Placement.CENTERED
	fire_diamond.editable_properties = [&"pip_amount"]
	fire_diamond.room_settings_on_create = fire_room

	# The origin is where the post meets the floor; the bowl sits post_height above.
	var brazier: Entry = _add_object(&"brazier", "Brazier", "Fire", preload("res://scenes/objects/fire/brazier.tscn"))
	brazier.hint = "A switch: light it (fireball or flame jet) and the doors linked to it open. Burn Time 0: lit until death or R; else it goes out after that many seconds. Gusts can't put it out."
	brazier.local_rect = Rect2(-6, -12, 12, 12)
	brazier.placement = Placement.ON_FLOOR
	brazier.snaps_to_ground = true
	brazier.editable_properties = [&"burn_time", &"post_height"]
	brazier.room_settings_on_create = fire_room

	# The origin is the anchor (click the tile under a ceiling); end_point the free end.
	var vine: Entry = _add_object(&"vine", "Vine", "Fire", preload("res://scenes/objects/fire/vine.tscn"))
	vine.hint = "A rope from the ceiling that holds things: link a hanging platform or a crate to it (select that, then L). Fire cuts it: it snaps and what it held swings or falls. Also a switch: on once it snaps."
	vine.bounds = Bounds.LINE_TO_POINT
	vine.placement = Placement.HANGING
	vine.editable_properties = [&"end_point"]
	vine.point_properties = [&"end_point"]
	vine.room_settings_on_create = fire_room

	# The origin is the plank's center. R stands it on end (a drawbridge).
	var hanging_platform: Entry = _add_object(&"hanging_platform", "Hanging platform", "Fire", preload("res://scenes/objects/fire/hanging_platform.tscn"))
	hanging_platform.hint = "A one-way plank held by vines (L: link them). Burn one vine and it swings on the others; burn them all and it falls. Stood on end (R), cutting its vine topples it across a gap. Vine Covered: a fireball on it burns every vine at once, so it drops level."
	hanging_platform.bounds = Bounds.WIDTH_CENTERED
	hanging_platform.width_property = &"platform_width"
	hanging_platform.local_rect = Rect2(0, -2, 0, 4)
	hanging_platform.placement = Placement.CENTERED
	hanging_platform.uses_rotation = true
	hanging_platform.rotate_step_degrees = 90.0
	hanging_platform.editable_properties = [&"platform_width", &"rotation_degrees", &"vine_covered"]
	hanging_platform.link_property = &"vines"
	hanging_platform.link_target_class = &"Vine"
	hanging_platform.tie_kind = TieKind.CENTER_LINE
	hanging_platform.tie_thickness = HangingPlatform.PLANK_THICKNESS
	hanging_platform.room_settings_on_create = fire_room

	# The origin is the middle of the mound's base, on the floor.
	var leaf_pile: Entry = _add_object(&"leaf_pile", "Leaf pile", "Fire", preload("res://scenes/objects/leaf_pile.tscn"))
	leaf_pile.hint = "Loose leaves drawn in front of everything: hides a plate or a passage. Gusts blow them away. Each leaf burns on its own; a heap of burning leaves is a bonfire (a hot updraft)."
	leaf_pile.bounds = Bounds.WIDTH_CENTERED
	leaf_pile.width_property = &"pile_width"
	leaf_pile.local_rect = Rect2(0, -8, 0, 8)
	leaf_pile.placement = Placement.ON_FLOOR
	leaf_pile.editable_properties = [&"pile_width", &"pile_height", &"leaf_count"]

	# --- Enemies (Stage L10; GAME_DESIGN.md §7, Fire_bending.md §7) ---
	# Every enemy's origin is its feet (bottom-center): it stands on the clicked tile.
	var wisp: Entry = _add_object(&"wisp", "Wisp", "Enemies", preload("res://scenes/enemies/wisp.tscn"))
	wisp.hint = "Walks back and forth, turning at walls and ledges. Touch kills. Gusts knock it back (into spikes, off ledges); fire, a thrown rock or a column beats it."
	wisp.bounds = Bounds.SIZE_BOTTOM_CENTER
	wisp.size_property = &"body_size"
	wisp.placement = Placement.ON_FLOOR
	wisp.editable_properties = [&"start_direction", &"patrol_speed"]

	var sentry: Entry = _add_object(&"sentry", "Sentry", "Enemies", preload("res://scenes/enemies/sentry.tscn"))
	sentry.hint = "A turret that fires slow orbs when it sees you. Gust an orb back into it to beat it. It can hang from a ceiling, never fire (a target for an enemy gate), or throw fireballs like yours (Fire Orbs: painted orange)."
	sentry.bounds = Bounds.SIZE_BOTTOM_CENTER
	sentry.size_property = &"body_size"
	sentry.hang_property = &"mounted_on_ceiling"
	sentry.snaps_to_ground = true
	sentry.placement = Placement.ON_FLOOR
	sentry.editable_properties = [&"mounted_on_ceiling", &"can_fire", &"fire_orbs", &"fire_interval", &"first_shot_delay", &"sight_range"]

	var vine_monkey: Entry = _add_object(&"vine_monkey", "Vine monkey", "Enemies", preload("res://scenes/enemies/vine_monkey.tscn"))
	vine_monkey.hint = "A leafy monkey that walks and hops gaps. Fire turns it into a running torch that lights what it touches. Gusts and rocks knock it about."
	vine_monkey.bounds = Bounds.SIZE_BOTTOM_CENTER
	vine_monkey.size_property = &"body_size"
	vine_monkey.placement = Placement.ON_FLOOR
	vine_monkey.editable_properties = [&"start_direction", &"hops_gaps"]

	var thicket_elephant: Entry = _add_object(&"thicket_elephant", "Thicket elephant", "Enemies", preload("res://scenes/enemies/thicket_elephant.tscn"))
	thicket_elephant.hint = "A huge stone-and-moss elephant you can ride. Seeing you, it charges: only that breaks stone walls. Burning its moss beats it. 12 x 7.5 tiles."
	thicket_elephant.local_rect = Rect2(-48, -60, 96, 60)
	thicket_elephant.placement = Placement.ON_FLOOR
	thicket_elephant.editable_properties = [&"start_direction"]

	# Fire Stage F12 (still being built when L10 was): its scene exists already.
	var shell: Entry = _add_object(&"shell", "Shell", "Enemies", preload("res://scenes/enemies/shell.tscn"))
	shell.hint = "Earth's armored crawler: fireballs and orbs bounce off its dome. Knock it over or into something to beat it."
	shell.local_rect = Rect2(-6, -8, 12, 8)
	shell.placement = Placement.ON_FLOOR
	shell.editable_properties = [&"start_direction"]

	# A row of pips, one per linked enemy, centered on the origin.
	var enemy_gate: Entry = _add_object(&"enemy_gate", "Enemy gate", "Enemies", preload("res://scenes/objects/enemy_gate.tscn"))
	enemy_gate.hint = "A switch that turns on once every enemy linked to it (L) is beaten. Link a door to it (select the door, then L) for a 'beat them all' exit."
	enemy_gate.local_rect = Rect2(-6, -4, 12, 8)
	enemy_gate.placement = Placement.CENTERED
	enemy_gate.link_property = &"enemies"
	enemy_gate.link_target_group = EnemyHit.GROUP
	enemy_gate.link_target_label = "enemy"

	_assign_tabs()
	_assign_carving()


## One terrain per cell (after Stage W2): painting a terrain erases every other
## terrain layer in that cell. Water is the exception: it lies in or on nothing
## solid, so it erases nothing, and only the chamber keeps it (water can stand in a
## hidden chamber). Two brushes sharing a layer (the covers) replace each other's
## tiles through TileBrush.paint_cell.
static func _assign_carving() -> void:
	var layer_names: Array[StringName] = []
	for entry: Entry in _entries:
		if entry.kind == Kind.TERRAIN and not layer_names.has(entry.layer_name):
			layer_names.append(entry.layer_name)
	for entry: Entry in _entries:
		if entry.kind != Kind.TERRAIN or entry.layer_name == WATER_LAYER_NAME:
			continue
		for layer_name: StringName in layer_names:
			if layer_name == entry.layer_name:
				continue
			if entry.layer_name == HIDDEN_LAYER_NAME and layer_name == WATER_LAYER_NAME:
				continue
			entry.carves_layers.append(layer_name)


## Moves every entry from its stage's family (now its element) to its tab.
static func _assign_tabs() -> void:
	for entry: Entry in _entries:
		if entry.family == "":
			continue  # a tool
		if ["Air", "Earth", "Fire", "Water"].has(entry.family):
			entry.element = entry.family
		if ELEMENT_OF.has(entry.id):
			entry.element = ELEMENT_OF[entry.id]
		if TAB_OF.has(entry.id):
			entry.family = TAB_OF[entry.id]


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
			if entry.hang_property != &"" and node.get(entry.hang_property):
				return Rect2(Vector2(-size.x / 2.0, 0.0), size)  # hangs below the origin
			return Rect2(Vector2(-size.x / 2.0, -size.y), size)
		Bounds.LINE_TO_POINT:
			var end: Vector2 = node.get(entry.point_properties[0])
			var line_box: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO).expand(end)
			# Thickened only across: a vertical vine's top stays on its anchor.
			var pad: Vector2 = (Vector2.ONE * LINE_THICKNESS - line_box.size).max(Vector2.ZERO) / 2.0
			return line_box.grow_individual(pad.x, pad.y, pad.x, pad.y)
		Bounds.WIDTH_CENTERED:
			var width: float = node.get(entry.width_property)
			return Rect2(-width / 2.0, entry.local_rect.position.y, width, entry.local_rect.size.y)
		_:
			return entry.local_rect


## The object's outline in level (global) coordinates. An entry with
## `uses_rotation` gives the box around its turned outline (Transform2D * Rect2).
static func get_bounds(node: Node2D) -> Rect2:
	var local_bounds: Rect2 = get_local_bounds(node)
	var entry: Entry = entry_for_node(node)
	if entry != null and entry.uses_rotation and not is_zero_approx(node.rotation):
		return Transform2D(node.global_rotation, node.global_position) * local_bounds
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
## An entry with `link_target_group` takes anything in that group instead.
static func is_link_target(entry: Entry, target: Node) -> bool:
	if entry == null:
		return false
	if entry.link_target_group != &"":
		return target.is_in_group(entry.link_target_group)
	if entry.link_target_class == &"":
		return false
	var script: Script = target.get_script()
	while script != null:
		if script.get_global_name() == entry.link_target_class:
			return true
		script = script.get_base_script()
	return false


## Where along `holder` a vine whose end is at `world_point` is tied: 0..1 from one
## end of its middle line to the other (CENTER_LINE), always 0.5 for TOP_CENTER.
static func get_tie_fraction(holder: Node2D, world_point: Vector2) -> float:
	var entry: Entry = entry_for_node(holder)
	if entry.tie_kind != TieKind.CENTER_LINE:
		return 0.5
	var ends: PackedVector2Array = _get_center_line(holder, entry)
	var along: Vector2 = ends[1] - ends[0]
	if along.length_squared() <= 0.0:
		return 0.5
	return clampf((world_point - ends[0]).dot(along) / along.length_squared(), 0.0, 1.0)


## The tie spot on `holder` at `fraction` (see get_tie_fraction), world coordinates.
static func get_tie_point(holder: Node2D, fraction: float) -> Vector2:
	var entry: Entry = entry_for_node(holder)
	if entry.tie_kind == TieKind.CENTER_LINE:
		var ends: PackedVector2Array = _get_center_line(holder, entry)
		return ends[0].lerp(ends[1], fraction)
	# TOP_CENTER: the knot sits half its thickness down from the top (as Crate ties it).
	var outline: Rect2 = get_bounds(holder)
	return Vector2(outline.get_center().x, outline.position.y + entry.tie_thickness / 2.0)


## The holder's long direction at the tie, pointing toward its middle (the vine
## winds its tendril that way, as HangingPlatform tells it in play).
static func get_tie_axis(holder: Node2D, fraction: float) -> Vector2:
	var axis: Vector2 = holder.global_transform.x.normalized()
	return axis if fraction <= 0.5 else -axis


## A CENTER_LINE holder's two ends (its width along its own x axis, turned with it).
static func _get_center_line(holder: Node2D, entry: Entry) -> PackedVector2Array:
	var half_width: float = float(holder.get(entry.width_property)) / 2.0
	return PackedVector2Array([holder.global_transform * Vector2(-half_width, 0.0),
		holder.global_transform * Vector2(half_width, 0.0)])


## What an entry's link targets are called in messages: "Switch", "Vine", "enemy".
static func link_target_name(entry: Entry) -> String:
	return entry.link_target_label if entry.link_target_label != "" else String(entry.link_target_class)


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

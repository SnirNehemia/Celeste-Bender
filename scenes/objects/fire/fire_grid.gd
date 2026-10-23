class_name FireGrid
extends Node2D
## FireGrid (Stage F5, Fire_bending.md §6.1, §10): the burning grass of one room.
## It owns the fire state of every grass cell:
##
##   GRASS -> BURNING -> SMOLDERING -> ASH
##            kills on touch,  harmless,      solid ground that never burns
##            spreads          charred, specks again: a firebreak
##            (burn_time)      (smolder_time)
##
## Made by Room._ready() (like the PebbleField) in rooms that allow fire and have a
## "Grass" layer. It sits at the room's origin, so its local coordinates are the
## room's, and the grass layer's map cells line up with ours. It joins
## Room.RESETTABLE_GROUP: death or R turns every cell back into grass.
##
## SPREAD: when a cell catches, each grass neighbour ALONG THE SURFACE is queued to
## catch spread_delay ± spread_jitter seconds later (the `pending` queue). Neighbours
## are found with the Earth shadow's surface walking (EarthFace.step_along_surface):
## left/right along floors, up/down grassy walls, around inner and outer corners.
## Fire only steps onto grass that hasn't burnt yet: never through air, gray rock,
## earth or ash. Buried grass (no open side) never burns.
## The CAP: at most max_burning_tiles cells burn at once; a due ignition past the cap
## stays in the queue until a cell stops burning.
##
## HOW FIRE GETS IN: the Flammable contract (flammable.gd). The grid joins the
## "flammable" group and has ignite_at(point, radius, source): fireballs (through
## Flammable.ignite_near) and the jet plume light the grass cells near the point.
## Cells lit by the JET catch spread_delay later instead of at once, so the fire
## starts behind you and never under your own feet (taking off from grass scorches
## the cell under you the same way, FlameJetAbility.begin_burst).
## A cell that catches lights any flammable its flames touch (a fuse reaching a
## brazier).
##
## KILLING: each burning cell has a band of flame grass_fire_hazard_height px deep on
## each open side. The player touching one dies through player.die(), the same path
## as spikes and FireHazard. One check for the whole grid, instead of an Area2D per
## cell. (The grid joins FireHazard.GROUP, so "what kills by fire" stays one list.)
##
## LOOK (made organic after the F5 play-test: the first version lined up with the
## tiles and repeated itself):
##   - The rules work per cell, but the fire doesn't LOOK per cell. Each cell
##     remembers where the fire came in (`ignite_origin`: the hit point, or the edge
##     it shares with the cell that lit it), and the fire CREEPS across it from there
##     at the spread speed (get_creep_delay), so the front moves smoothly instead of
##     jumping a tile at a time.
##   - Flames are FlameTongues (children), a random number per cell at random spots
##     (even a pixel over the cell's edge), each with its own size, lean, flicker,
##     start (when the creep reaches it) and lifetime. A tongue that dies early comes
##     back somewhere else on the cell while the cell still burns.
##   - Each cell burns and smolders for its own jittered time (burn_time_jitter), so
##     neighbours don't go out in step.
##   - A newly appeared tongue flares (longer, white-hot, a soft bright glow at its
##     foot); a dim soft glow sits under every flame. Glows are round and soft, never
##     tile squares.
##   - Smoldering cells show ember specks at random spots that blink out one by one.
##   - The ground colors are the GroundPainter's (it listens to `cells_changed`; it
##     makes the edges between burnt and unburnt ground ragged). The grass blades
##     curl and blacken as the creep reaches each one (get_burn_progress_at).
##
## THICKET and OVERGROWN COVERS (Stage F6, Fire_bending.md §6.1b): two more burnable
## materials, on the room's "Thicket" (ThicketLayer) and "Overgrown" (OvergrownLayer)
## layers. The grid owns their fire too:
##   - Thicket burns through its whole VOLUME: a burning thicket cell lights its 4
##     neighbours (thicket, touching grass, a cover) after thicket_spread_delay, and
##     grass lights touching thicket after spread_delay. Buried thicket catches too.
##     A thicket cell first glows from inside (thicket_glow_share of its burn,
##     harmless), then its flames break out and kill on touch like grass, then it
##     CRUMBLES (GONE): the ThicketLayer erases the tile and it's open air. A burnt
##     floor drops whatever stood on it; the grass under a crumbled cell catches.
##     No smolder, no ash crust: it falls away as a shower of flakes.
##   - Overgrown covers: fire reaching any cell starts a FLASH-OVER of the whole
##     connected cover (flood fill): a bright front races across it in the first half
##     of overgrown_flashover_time, the cover burns as one deadly sheet, then it
##     collapses at once (GONE): freeze frames, a shake, a burst of ash, and any
##     HiddenLayer chamber it touches is revealed (with whatever was hidden inside).
##     The collapse lights the grass and thicket it touched.
## Cells are told apart by get_fuel(). A cell's State is shared by all three
## materials: GRASS means "not burnt yet" whatever the material.
##
## HOT AIR (Stage F7, Fire_bending.md §5.3): every burning cell with an open top gives
## a short, weak updraft (grass_updraft_lift, grass_updraft_height px above the cell)
## while it burns. The grid is a heat source (scenes/objects/fire/heat.gd), so a
## glider passing over a fire gets a little bump and heat receivers are lifted; no
## WindZone per cell (that would be up to max_burning_tiles areas made and freed).
##
## GUSTS (F7 play-test, ahead of Stage F10; Fire_bending.md §5.4): a gust blowing
## over burning cells puts them out (snuff_in, the Flammable contract's gust hook):
## burning grass turns to ash at once (a firebreak), burning thicket crumbles away
## without lighting what's around it. Cells about to catch inside the gust don't, and
## cells only a snuffed cell was about to light don't either. Smoldering cells and a
## flashing cover are left alone. So a gust across a fire front stops it there.
##
## Time: game time (physics delta), so slow motion slows the fire too. Only the room
## on screen burns (like the grass blades); a fire left behind waits.

## The look of these cells changed (they caught, started smoldering, became ash, or
## were reset). GroundPainter repaints them.
signal cells_changed(cells: Array[Vector2i])

## GRASS = not burnt yet (any material). GONE = burnt away: thicket that crumbled, a
## cover that collapsed (open air now). Grass never gets GONE, thicket never ASH.
enum State { GRASS, BURNING, SMOLDERING, ASH, GONE }
## What a cell is made of (see the header). NONE: not burnable (or burnt away).
enum Fuel { NONE, GRASS, THICKET, OVERGROWN }

const GROUP: StringName = &"fire_grid"
## A cell's flames light flammables this many px beyond its hazard band (enough to
## reach the catch area of a brazier standing on the cell: its bottom is 7 px up).
const IGNITE_REACH: float = 4.0
## Charred blades and smoldering crust: almost black.
const CHAR_COLOR: Color = Color(0.09, 0.07, 0.07)
## Ember specks and glows (Fire_bending.md §9.1 ember, and a hotter orange).
const EMBER_COLOR: Color = Color("#8A2410")
const EMBER_HOT_COLOR: Color = Color("#FF8A1E")
const SPECKS_PER_CELL: int = 8
## Colors of the ash flakes left in the PebbleField when grass turns to ash or thicket
## crumbles (§6.1: "ash flakes get kicked like pebbles"; light ones since the F6
## play-test, PebbleField.leave_ash). How many: FireTuning's "Ash flakes" group.
const ASH_FLAKE_COLORS: Array[Color] = [Color("#4A4545"), Color("#7A7470"), Color("#5E5858")]
## Smoldering cells puff a little smoke this often, on average per second.
const SMOLDER_SMOKE_CHANCE: float = 0.8
## A tongue grows in over this many seconds, and dies down over the last part of
## its life (TONGUE_FADE_SHARE).
const TONGUE_GROW_TIME: float = 0.12
const TONGUE_FADE_SHARE: float = 0.35
## A tongue lives this share of its cell's burn time (random in the range)...
const TONGUE_MIN_LIFE: float = 0.4
const TONGUE_MAX_LIFE: float = 0.85
## ...and comes back elsewhere on the cell if at least this many seconds are left.
const TONGUE_REBIRTH_MIN_TIME: float = 0.3
## Tongues may stand this far past the cell's edge, as a share of the tile size.
const TONGUE_OVERHANG: float = 0.15
## Soft glow under a flame: radius as a share of the tongue's length, and its alpha.
const GLOW_RADIUS_SHARE: float = 0.7
const GLOW_ALPHA: float = 0.22
## Size of the shared glow picture, px (it's stretched to each glow's size).
const GLOW_TEXTURE_SIZE: int = 32
## Thicket glowing from inside: glowing branch strokes per cell.
const THICKET_BRANCHES_PER_CELL: int = 3
## A burning thicket cell drops a clump of glowing ash this often, on average per
## second (only if its underside is open).
const THICKET_CLUMP_CHANCE: float = 2.5
## Flames on burning thicket and on a flashing cover are this much longer than grass
## flames: a wall of brambles burns big.
const THICKET_FLAME_SCALE: float = 1.4
const OVERGROWN_FLAME_SCALE: float = 1.7
## The flash-over front crosses the cover in this share of overgrown_flashover_time;
## the rest is the whole sheet burning before it collapses.
const FLASHOVER_FRONT_SHARE: float = 0.5

## One soft round glow picture shared by every glow (made on first use). A `static
## var` belongs to the class, not to one grid, like a Python class attribute.
## WHY a picture: glows used to be 4 stacked draw_circle() calls each. Godot builds
## every circle as a many-sided polygon on the CPU, and with a field of smoldering
## cells (8 specks each) that was ~800 circles a frame and the frame rate fell to
## ~27. A textured rectangle is 2 triangles, and rectangles sharing one texture are
## drawn together in a single batch.
static var glow_texture: GradientTexture2D

## preload() of the .tres returns the same resource object the player holds, so F5
## panel and Remote-tab edits reach the grid at once.
var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
var room: Room
## The room's burnable layers; any of them may be missing (null).
var grass_layer: TileMapLayer
var thicket_layer: ThicketLayer
var overgrown_layer: OvergrownLayer
## The room's HiddenLayer, or null: an overgrown cover's collapse opens the chambers
## it touches.
var hidden_layer: HiddenLayer
## Any one of the burnable layers: they all sit at the room's origin with the same
## tile size, so cell <-> pixel math works with whichever is there.
var geometry_layer: TileMapLayer
## The room's EarthLayer, if any: its is_solid() knows about every tile layer,
## columns and covered hidden chambers. Without one, we look at the tile layers.
var earth_layer: EarthLayer
var solid_layers: Array[TileMapLayer] = []
var tile_size: int = 8
## The room's cells; outside counts as solid (no fire on the far side of the frame).
var cell_bounds: Rect2i

## Cells that aren't plain grass -> State. Missing = GRASS.
var cell_states: Dictionary = {}
## BURNING / SMOLDERING cells -> seconds left in that state.
var time_left: Dictionary = {}
## Burning cells -> this cell's own burn time (jittered); smoldering ones -> its own
## smolder time.
var state_duration: Dictionary = {}
## Cells -> fire_clock when they caught.
var ignite_clock: Dictionary = {}
## Cells -> where the fire came in (local px): the creep starts there.
var ignite_origin: Dictionary = {}
## The spread queue: cells waiting to catch -> fire_clock when they're due, and
## where their fire will come in.
var pending: Dictionary = {}
var pending_origin: Dictionary = {}
## Burning thicket cells -> their glowing branch strokes (local px), laid out when
## they catch: Array of [from, to].
var branches: Dictionary = {}
## How many cells burn right now, and the most ever at once (the smoke test checks
## it never passes the cap).
var burning_count: int = 0
var peak_burning_count: int = 0
## Seconds of fire time (only advances while this room is on screen).
var fire_clock: float = 0.0
## Burning cells -> Array of flames. A flame is a Dictionary:
##   node (FlameTongue), base (local px), direction (unit), length (full, px),
##   start / end (seconds after the cell caught), lean (radians).
var flames: Dictionary = {}
## Smoldering cells -> their ember specks, laid out once when the smolder starts
## (not every frame). A speck: [pixel (local), out_at (0..1 of the smolder),
## pulse speed, pulse phase].
var specks: Dictionary = {}
## The additive child the glows and specks are drawn into.
var glow_layer: Node2D
## Draws every burning cell's tongues as one fire, so a burning run is one sheet of
## flame with many tips, not a row of little fires (F7 play-test, FlameMerge).
var flame_merge: FlameMerge


func _ready() -> void:
	room = get_parent() as Room
	grass_layer = room.get_node_or_null("Grass") as TileMapLayer
	thicket_layer = room.get_node_or_null("Thicket") as ThicketLayer
	overgrown_layer = room.get_node_or_null("Overgrown") as OvergrownLayer
	hidden_layer = room.get_node_or_null("Hidden") as HiddenLayer
	earth_layer = room.get_node_or_null("Earth") as EarthLayer
	for layer: TileMapLayer in [grass_layer, thicket_layer, overgrown_layer]:
		if layer != null:
			geometry_layer = layer
			break
	for child: Node in room.get_children():
		if child is TileMapLayer and not child is HiddenLayer:
			solid_layers.append(child)
	tile_size = geometry_layer.tile_set.tile_size.x
	cell_bounds = Rect2i(Vector2i.ZERO, Vector2i((room.room_size / tile_size).ceil()))
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(Flammable.GROUP)
	add_to_group(FireHazard.GROUP)
	add_to_group(Heat.SOURCE_GROUP)
	z_index = 1  # flames in front of the player's feet, like the grass blades
	glow_layer = Node2D.new()
	glow_layer.name = "Glow"
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = additive
	add_child(glow_layer)
	glow_layer.draw.connect(_draw_glow)
	flame_merge = FlameMerge.make(self)


## The grid of the room containing `world_position`, or null.
static func find_grid_at(tree: SceneTree, world_position: Vector2) -> FireGrid:
	for member: Node in tree.get_nodes_in_group(GROUP):
		var grid: FireGrid = member as FireGrid
		if grid != null and grid.room.get_bounds().has_point(world_position):
			return grid
	return null


# --- Questions -------------------------------------------------------------------

func get_state(cell: Vector2i) -> State:
	return cell_states.get(cell, State.GRASS)


## Seconds since a burning cell caught, or 0.
func get_time_burning(cell: Vector2i) -> float:
	if get_state(cell) != State.BURNING:
		return 0.0
	return fire_clock - float(ignite_clock[cell])


## 0 when a burning cell just caught, 1 when it's about to smolder. 0 for others.
func get_burn_progress(cell: Vector2i) -> float:
	if get_state(cell) != State.BURNING:
		return 0.0
	return clampf(get_time_burning(cell) / maxf(float(state_duration[cell]), 0.001), 0.0, 1.0)


## How long after `cell` caught the fire creeping across it reaches `point` (local
## px): the distance from where it came in, at one tile per spread delay (grass's or
## thicket's). A flashing cover has no creep: its front is the flash-over itself.
func get_creep_delay(cell: Vector2i, point: Vector2) -> float:
	var material: Fuel = get_fuel(cell)
	if material == Fuel.OVERGROWN:
		return 0.0
	var origin: Vector2 = ignite_origin.get(cell, get_cell_rect(cell).get_center())
	return minf(point.distance_to(origin) / tile_size, 1.2) * _get_spread_delay_from(material)


## Like get_burn_progress, but for one spot of the cell (local px): 0 until the creep
## reaches it, then rising to 1 by the time the cell smolders.
func get_burn_progress_at(cell: Vector2i, point: Vector2) -> float:
	if get_state(cell) != State.BURNING:
		return 0.0
	var creep: float = get_creep_delay(cell, point)
	var duration: float = maxf(float(state_duration[cell]) - creep, 0.001)
	return clampf((get_time_burning(cell) - creep) / duration, 0.0, 1.0)


func is_grass_cell(cell: Vector2i) -> bool:
	return grass_layer != null and grass_layer.get_cell_source_id(cell) != -1


## What `cell` is made of right now. A cell that burnt away is NONE (open air).
func get_fuel(cell: Vector2i) -> Fuel:
	if is_grass_cell(cell):
		return Fuel.GRASS
	if thicket_layer != null and thicket_layer.has_thicket(cell):
		return Fuel.THICKET
	if overgrown_layer != null and overgrown_layer.has_cover(cell):
		return Fuel.OVERGROWN
	return Fuel.NONE


## Solid ground for the surface walk: any tile, a column, a covered chamber, or
## outside the room.
func is_solid(cell: Vector2i) -> bool:
	if not cell_bounds.has_point(cell):
		return true
	if earth_layer != null:
		return earth_layer.is_solid(cell)
	for layer: TileMapLayer in solid_layers:
		if layer.get_cell_source_id(cell) != -1:
			return true
	return false


## The open sides of `cell` (normals pointing into the air).
func get_open_sides(cell: Vector2i) -> Array[Vector2i]:
	var sides: Array[Vector2i] = []
	for normal: Vector2i in EarthLayer.FACE_NORMALS:
		if not is_solid(cell + normal):
			sides.append(normal)
	return sides


## True if fire could take hold of `cell`: unburnt grass with at least one open side,
## or unburnt thicket or cover (they burn through their volume: buried ones too).
func can_catch(cell: Vector2i) -> bool:
	if get_state(cell) != State.GRASS:
		return false
	match get_fuel(cell):
		Fuel.GRASS:
			return not get_open_sides(cell).is_empty()
		Fuel.THICKET, Fuel.OVERGROWN:
			return true
	return false


## The grass cells fire spreads to from `cell`: one surface step each way along
## every open side (see the header).
func get_spread_neighbours(cell: Vector2i) -> Array[Vector2i]:
	var neighbours: Array[Vector2i] = []
	for normal: Vector2i in get_open_sides(cell):
		var along: Vector2i = Vector2i(absi(normal.y), absi(normal.x))
		for tangent: Vector2i in [along, -along]:
			var step: Array = EarthFace.step_along_surface(is_solid, cell, normal, tangent)
			var next_cell: Vector2i = step[0]
			# Wrapping round our own corner lands on our own cell: its other sides are
			# walked from the loop above anyway.
			if next_cell != cell and is_grass_cell(next_cell) and not neighbours.has(next_cell):
				neighbours.append(next_cell)
	return neighbours


## Every cell a burning `cell` lights, and after how many seconds (the caller adds
## the jitter): [[cell, delay], ...]. Grass spreads along its surface, and into
## touching thicket and covers; thicket and covers spread to all 4 neighbours of any
## burnable material.
func get_spread_targets(cell: Vector2i) -> Array:
	var targets: Array = []
	var material: Fuel = get_fuel(cell)
	if material == Fuel.GRASS:
		for neighbour: Vector2i in get_spread_neighbours(cell):
			targets.append([neighbour, fire_tuning.spread_delay])
	for normal: Vector2i in EarthLayer.FACE_NORMALS:
		var neighbour: Vector2i = cell + normal
		var neighbour_material: Fuel = get_fuel(neighbour)
		if neighbour_material == Fuel.NONE:
			continue
		if material == Fuel.GRASS and neighbour_material == Fuel.GRASS:
			continue  # grass to grass goes along the surface (above)
		targets.append([neighbour, _get_spread_delay_from(material)])
	return targets


## Grass is the slow fuel: what it lights catches spread_delay later. What burning
## brambles (or a cover) light catches thicket_spread_delay later.
func _get_spread_delay_from(material: Fuel) -> float:
	return fire_tuning.spread_delay if material == Fuel.GRASS else fire_tuning.thicket_spread_delay


## The cell's rectangle in our (= the room's) local coordinates.
func get_cell_rect(cell: Vector2i) -> Rect2:
	var center: Vector2 = geometry_layer.position + geometry_layer.map_to_local(cell)
	return Rect2(center - Vector2.ONE * tile_size / 2.0, Vector2.ONE * tile_size)


## The deadly band of flame on one open side of `cell`, local coordinates. Inset 1 px
## along the side, so brushing past a burning cell's corner isn't a death.
func get_flame_band(cell: Vector2i, normal: Vector2i) -> Rect2:
	var rect: Rect2 = get_cell_rect(cell)
	var depth: float = fire_tuning.grass_fire_hazard_height
	match normal:
		Vector2i.UP:
			return Rect2(rect.position.x + 1.0, rect.position.y - depth, rect.size.x - 2.0, depth)
		Vector2i.DOWN:
			return Rect2(rect.position.x + 1.0, rect.end.y, rect.size.x - 2.0, depth)
		Vector2i.LEFT:
			return Rect2(rect.position.x - depth, rect.position.y + 1.0, depth, rect.size.y - 2.0)
		_:
			return Rect2(rect.end.x, rect.position.y + 1.0, depth, rect.size.y - 2.0)


# --- The Flammable contract ----------------------------------------------------------

## Lights the grass near `world_point`: every cell that can catch whose rectangle,
## grown by `radius`, holds the point. Returns true if any caught (or was queued).
## The jet's flames catch a moment later (spread_delay; see the header).
func ignite_at(world_point: Vector2, radius: float, source: Node) -> bool:
	var point: Vector2 = to_local(world_point)
	var first: Vector2i = geometry_layer.local_to_map(point - Vector2.ONE * (radius + 0.5) - geometry_layer.position)
	var last: Vector2i = geometry_layer.local_to_map(point + Vector2.ONE * (radius + 0.5) - geometry_layer.position)
	var delayed: bool = source is FlameJetAbility
	var any_caught: bool = false
	for x: int in range(first.x, last.x + 1):
		for y: int in range(first.y, last.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			var rect: Rect2 = get_cell_rect(cell)
			if not can_catch(cell) or not rect.grow(radius).has_point(point):
				continue
			any_caught = true
			# The fire comes in at the spot nearest the flame.
			var origin: Vector2 = point.clamp(rect.position, rect.end)
			queue_ignition(cell, fire_tuning.spread_delay if delayed else 0.0, origin)
	if any_caught and not delayed:
		_process_pending()  # a fireball's hit catches this very frame
	return any_caught


## The grid as a whole has no single spot to light: fire gets in through ignite_at.
func ignite(_source: Node) -> void:
	pass


func is_burning() -> bool:
	return burning_count > 0


## The whole grid can't be snuffed at once: gusts put out the cells they blow over
## (snuff_in).
func snuff() -> void:
	pass


## The gust hook (flammable.gd): puts out the burning grass and thicket cells a gust
## blew over (`world_polygon`: its cone, or circle), and stops the cells inside it
## that were about to catch. A cell counts if its middle, a corner, or its flame band
## is inside. Returns how many cells went out.
func snuff_in(world_polygon: PackedVector2Array, _direction: Vector2) -> int:
	if burning_count == 0 and pending.is_empty():
		return 0
	var polygon: PackedVector2Array = PackedVector2Array()
	for world_point: Vector2 in world_polygon:
		polygon.append(to_local(world_point))
	var grass_cells: Array[Vector2i] = []
	var thicket_cells: Array[Vector2i] = []
	for cell: Vector2i in time_left:
		if get_state(cell) != State.BURNING or not _is_cell_in_polygon(cell, polygon):
			continue
		match get_fuel(cell):
			Fuel.GRASS:
				grass_cells.append(cell)
			Fuel.THICKET:
				thicket_cells.append(cell)
	# Cells about to catch inside the gust: blown out before they do.
	var cancelled: Array[Vector2i] = []
	for cell: Vector2i in pending:
		if _is_cell_in_polygon(cell, polygon):
			cancelled.append(cell)
	# And the ones only a snuffed cell was about to light (if another burning cell
	# would light them too, they're queued again below).
	for cell: Vector2i in grass_cells + thicket_cells:
		for target: Array in get_spread_targets(cell):
			if pending.has(target[0]) and not cancelled.has(target[0]):
				cancelled.append(target[0])
	for cell: Vector2i in cancelled:
		pending.erase(cell)
		pending_origin.erase(cell)
	for cell: Vector2i in grass_cells:
		burning_count -= 1
		_remove_flames(cell)
		SmokePuff.spawn(room, to_global(_get_top_point(cell)), 2)  # the gray puff before its ash
		_become_ash(cell)
	if not thicket_cells.is_empty():
		_crumble_thicket(thicket_cells, false)
	_requeue_from_burning_neighbours(cancelled)
	return grass_cells.size() + thicket_cells.size()


## True if `cell` (or its flame band) is inside `polygon` (our local px): its middle,
## a corner of the cell grown by the flame band's depth, or the middle of the band
## on top.
func _is_cell_in_polygon(cell: Vector2i, polygon: PackedVector2Array) -> bool:
	var rect: Rect2 = get_cell_rect(cell).grow(fire_tuning.grass_fire_hazard_height)
	for point: Vector2 in [get_cell_rect(cell).get_center(), rect.position, rect.end,
			Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y),
			Vector2(rect.get_center().x, rect.position.y + 1.0)]:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


## After a gust cancelled `cells`' ignitions: any that a still-burning neighbour would
## light anyway are queued again (that neighbour's fire wasn't blown out).
func _requeue_from_burning_neighbours(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	for burning_cell: Vector2i in time_left:
		if get_state(burning_cell) != State.BURNING:
			continue
		for target: Array in get_spread_targets(burning_cell):
			var neighbour: Vector2i = target[0]
			if cells.has(neighbour) and can_catch(neighbour):
				var neighbour_rect: Rect2 = get_cell_rect(neighbour)
				var entry: Vector2 = get_cell_rect(burning_cell).get_center().clamp(neighbour_rect.position, neighbour_rect.end)
				queue_ignition(neighbour, float(target[1]), entry)


# --- Changing state ----------------------------------------------------------------

## Queues `cell` to catch after `delay` seconds (sooner if it's already queued), its
## fire coming in at `origin` (local px).
func queue_ignition(cell: Vector2i, delay: float, origin: Vector2) -> void:
	if not can_catch(cell):
		return
	var due: float = fire_clock + maxf(delay, 0.0)
	if due < float(pending.get(cell, INF)):
		pending[cell] = due
		pending_origin[cell] = origin


## Due ignitions catch, oldest first, as long as the cap allows. The rest wait.
func _process_pending() -> void:
	if pending.is_empty():
		return
	var due_cells: Array[Vector2i] = []
	for cell: Vector2i in pending:
		if float(pending[cell]) <= fire_clock:
			due_cells.append(cell)
	due_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return pending[a] < pending[b])
	for cell: Vector2i in due_cells:
		if not can_catch(cell):
			pending.erase(cell)
			pending_origin.erase(cell)
		elif burning_count < fire_tuning.max_burning_tiles:
			var origin: Vector2 = pending_origin[cell]
			pending.erase(cell)
			pending_origin.erase(cell)
			_start_burning(cell, origin)
		else:
			break  # at the cap: everything else waits for a cell to burn out


func _start_burning(cell: Vector2i, origin: Vector2) -> void:
	var material: Fuel = get_fuel(cell)
	if material == Fuel.OVERGROWN:
		_start_flashover(cell, origin)
		return
	cell_states[cell] = State.BURNING
	var duration: float = _jitter(fire_tuning.thicket_burn_time if material == Fuel.THICKET else fire_tuning.burn_time)
	time_left[cell] = duration
	state_duration[cell] = duration
	ignite_clock[cell] = fire_clock
	ignite_origin[cell] = origin
	burning_count += 1
	peak_burning_count = maxi(peak_burning_count, burning_count)
	if material == Fuel.THICKET:
		branches[cell] = _make_branches(cell)
	_add_flames(cell)
	# The next cells catch a little later, each with its own jitter, their fire
	# coming in at the edge they share with us.
	var rect: Rect2 = get_cell_rect(cell)
	for target: Array in get_spread_targets(cell):
		var neighbour: Vector2i = target[0]
		var neighbour_rect: Rect2 = get_cell_rect(neighbour)
		var entry: Vector2 = rect.get_center().clamp(neighbour_rect.position, neighbour_rect.end)
		var jitter: float = randf_range(-fire_tuning.spread_jitter, fire_tuning.spread_jitter)
		queue_ignition(neighbour, float(target[1]) + jitter, entry)
	_ignite_touching_flammables(cell)
	EmberEmitter.burst(room, to_global(origin), 3, Vector2.UP, 50.0, 40.0)
	FX.play_sfx(&"fire_ignite")
	_announce_cell(cell)


## Fire reached `start_cell` of an overgrown cover: the whole connected cover flashes
## over. A flood fill (BFS over the 4 neighbours, like HiddenLayer.reveal_chamber)
## gives each cell its step count from where the fire came in. The front reaches
## each cell at its share of FLASHOVER_FRONT_SHARE x overgrown_flashover_time, and
## every cell collapses together at the end (their time_left all run out at once).
func _start_flashover(start_cell: Vector2i, origin: Vector2) -> void:
	var steps: Dictionary = {start_cell: 0}
	var queue: Array[Vector2i] = [start_cell]
	var cover: Array[Vector2i] = []
	var most_steps: int = 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		cover.append(cell)
		most_steps = maxi(most_steps, int(steps[cell]))
		for normal: Vector2i in EarthLayer.FACE_NORMALS:
			var neighbour: Vector2i = cell + normal
			if not steps.has(neighbour) and get_fuel(neighbour) == Fuel.OVERGROWN \
					and get_state(neighbour) == State.GRASS:
				steps[neighbour] = int(steps[cell]) + 1
				queue.append(neighbour)
	var total_time: float = maxf(fire_tuning.overgrown_flashover_time, 0.01)
	var front_time: float = total_time * FLASHOVER_FRONT_SHARE
	for cell: Vector2i in cover:
		pending.erase(cell)
		pending_origin.erase(cell)
		var arrival: float = front_time * float(steps[cell]) / maxf(float(most_steps), 1.0)
		cell_states[cell] = State.BURNING
		# "Caught" when the front arrives: until then get_time_burning() is negative,
		# so its flames and its deadly band wait for the front (is_deadly).
		ignite_clock[cell] = fire_clock + arrival
		ignite_origin[cell] = origin if cell == start_cell else get_cell_rect(cell).get_center()
		state_duration[cell] = total_time - arrival
		time_left[cell] = total_time
		burning_count += 1
		_add_flames(cell)
	peak_burning_count = maxi(peak_burning_count, burning_count)
	EmberEmitter.burst(room, to_global(origin), 6, Vector2.UP, 70.0, 60.0)
	FX.play_sfx(&"fire_ignite")
	cells_changed.emit(cover)
	glow_layer.queue_redraw()


## `base` give or take burn_time_jitter (a fraction), per cell.
func _jitter(base: float) -> float:
	var spread: float = fire_tuning.burn_time_jitter
	return maxf(base * randf_range(1.0 - spread, 1.0 + spread), 0.05)


## A fuse reaching a brazier: anything flammable the new flames touch catches too.
func _ignite_touching_flammables(cell: Vector2i) -> void:
	for target: Node in get_tree().get_nodes_in_group(Flammable.GROUP):
		if target == self or target is FireGrid:
			continue
		# Things that burn in parts (a leaf pile's leaves) catch only where a band
		# is: lit at its middle, reaching its half diagonal.
		var burns_in_parts: bool = target.has_method(Flammable.METHOD_IGNITE_AT)
		var target_rect: Rect2 = Rect2() if burns_in_parts else Flammable.get_fire_rect(target)
		for normal: Vector2i in get_open_sides(cell):
			var band: Rect2 = get_flame_band(cell, normal).grow(IGNITE_REACH)
			band.position = to_global(band.position)
			if burns_in_parts:
				target.call(Flammable.METHOD_IGNITE_AT, band.get_center(), band.size.length() / 2.0, self)
			elif band.intersects(target_rect) or band.has_point(target_rect.position):
				target.call(Flammable.METHOD_IGNITE, self)
				break


func _start_smoldering(cell: Vector2i) -> void:
	cell_states[cell] = State.SMOLDERING
	var duration: float = _jitter(fire_tuning.smolder_time)
	time_left[cell] = duration
	state_duration[cell] = duration
	burning_count -= 1
	_remove_flames(cell)
	specks[cell] = _make_specks(cell)
	SmokePuff.spawn(room, to_global(_get_top_point(cell)), 2)
	_announce_cell(cell)


## Burnt-out thicket cells crumble into falling ash and become open air (the
## ThicketLayer erases them, in one batch). `spread`: the glowing ash lights what the
## cells touched; false when a gust blew them out.
func _crumble_thicket(cells: Array[Vector2i], spread: bool = true) -> void:
	for cell: Vector2i in cells:
		_end_burning(cell)
		var rect: Rect2 = get_cell_rect(cell)
		# Glowing bits that die out on the way down, and gray flakes that stay
		# (PebbleField ash: light, they drift down and swirl round the player).
		AshFall.spawn(room, to_global(rect.get_center()), fire_tuning.thicket_ash_flakes, rect.size, 0.8)
		if randf() < 0.5:
			SmokePuff.spawn(room, to_global(rect.get_center()), 1)
	thicket_layer.remove_cells(cells)
	# After the tiles are gone, so the flakes start in open air.
	for cell: Vector2i in cells:
		var rect: Rect2 = get_cell_rect(cell)
		PebbleField.leave_ash(get_tree(), to_global(rect.get_center()), fire_tuning.ash_flakes_per_thicket_cell,
			rect.size - Vector2(2.0, 2.0), ASH_FLAKE_COLORS)
	_after_cells_gone(cells, spread)


## Smashes the thicket cells overlapping `world_rect` without fire (Stage F11b: a
## charging thicket elephant breaks through brambles). They crumble into flakes and
## open air like burnt thicket, but light nothing. Returns true if any broke.
func crush_thicket_in(world_rect: Rect2) -> bool:
	if thicket_layer == null:
		return false
	var local_rect: Rect2 = Rect2(to_local(world_rect.position), world_rect.size)
	var first: Vector2i = geometry_layer.local_to_map(local_rect.position - geometry_layer.position)
	var last: Vector2i = geometry_layer.local_to_map(local_rect.end - geometry_layer.position)
	var cells: Array[Vector2i] = []
	for x: int in range(first.x, last.x + 1):
		for y: int in range(first.y, last.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if thicket_layer.has_thicket(cell) and get_cell_rect(cell).intersects(local_rect):
				cells.append(cell)
	if cells.is_empty():
		return false
	for cell: Vector2i in cells:
		if get_state(cell) == State.BURNING:
			_end_burning(cell)  # keeps burning_count right
		else:
			cell_states[cell] = State.GONE
		pending.erase(cell)
		pending_origin.erase(cell)
		var rect: Rect2 = get_cell_rect(cell)
		AshFall.spawn(room, to_global(rect.get_center()), fire_tuning.thicket_ash_flakes / 2, rect.size, 0.4)
	thicket_layer.remove_cells(cells)
	_after_cells_gone(cells, false)
	return true


## The flash-over is done: the whole cover collapses at once in a burst of ash and
## embers (freeze frames + shake, like a cracked wall breaking) and becomes open air.
## Hidden chambers it touched open.
func _collapse_cover(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		_end_burning(cell)
		var rect: Rect2 = get_cell_rect(cell)
		AshFall.spawn(room, to_global(rect.get_center()), fire_tuning.thicket_ash_flakes, rect.size, 0.5)
		if randf() < 0.35:
			EmberEmitter.burst(room, to_global(rect.get_center()), 3, Vector2.UP, 90.0, 50.0)
	# Covered chambers next to the cover, found BEFORE its tiles go.
	var chamber_cells: Array[Vector2i] = []
	if hidden_layer != null:
		for cell: Vector2i in cells:
			for normal: Vector2i in EarthLayer.FACE_NORMALS:
				if hidden_layer.is_covered(cell + normal) and not chamber_cells.has(cell + normal):
					chamber_cells.append(cell + normal)
	overgrown_layer.remove_cells(cells)
	for chamber_cell: Vector2i in chamber_cells:
		hidden_layer.reveal_chamber(chamber_cell)  # does nothing if already revealed
	_after_cells_gone(cells)
	FX.shake(fire_tuning.overgrown_shake_strength, fire_tuning.overgrown_shake_time)
	FX.freeze(fire_tuning.overgrown_freeze_time)
	FX.play_sfx(&"overgrown_flashover")


## A burning thicket or cover cell stops burning: it's GONE (open air).
func _end_burning(cell: Vector2i) -> void:
	cell_states[cell] = State.GONE
	time_left.erase(cell)
	state_duration.erase(cell)
	branches.erase(cell)
	burning_count -= 1
	_remove_flames(cell)


## Cells just turned into open air: what they touched burns on. Grass under them
## catches (its top is open now: the glowing ash falls on it), thicket and covers
## they touched catch if the fire hadn't got there yet (not when `spread` is false:
## a gust blew them out), and burning neighbours grow flames on the sides that just
## opened.
func _after_cells_gone(cells: Array[Vector2i], spread: bool = true) -> void:
	for cell: Vector2i in cells:
		for normal: Vector2i in EarthLayer.FACE_NORMALS:
			var neighbour: Vector2i = cell + normal
			if get_state(neighbour) == State.BURNING:
				_add_missing_flames(neighbour)
			elif spread and can_catch(neighbour) and not pending.has(neighbour):
				var neighbour_rect: Rect2 = get_cell_rect(neighbour)
				var entry: Vector2 = get_cell_rect(cell).get_center().clamp(neighbour_rect.position, neighbour_rect.end)
				queue_ignition(neighbour, _get_spread_delay_from(get_fuel(neighbour)), entry)
	cells_changed.emit(cells)
	glow_layer.queue_redraw()


## Burning thicket with an open underside now and then drops a clump of glowing ash.
func _drop_thicket_clumps(delta: float) -> void:
	for cell: Vector2i in branches:
		if randf() >= THICKET_CLUMP_CHANCE * delta or is_solid(cell + Vector2i.DOWN):
			continue
		var rect: Rect2 = get_cell_rect(cell)
		var bottom: Vector2 = Vector2(rect.position.x + randf_range(1.0, rect.size.x - 1.0), rect.end.y)
		AshFall.spawn(room, to_global(bottom), randi_range(2, 3), Vector2(2.0, 1.0), 0.8)


func _become_ash(cell: Vector2i) -> void:
	cell_states[cell] = State.ASH
	time_left.erase(cell)
	state_duration.erase(cell)
	specks.erase(cell)
	PebbleField.leave_ash(get_tree(), to_global(_get_top_point(cell)) + Vector2(0.0, -1.0),
		fire_tuning.ash_flakes_per_grass_cell, Vector2(tile_size, 1.0), ASH_FLAKE_COLORS)
	_announce_cell(cell)


## Tells the painter one cell's look changed, and redraws our own glow (a cell that
## just left its last glowing state must not keep its old specks on screen).
func _announce_cell(cell: Vector2i) -> void:
	var changed: Array[Vector2i] = [cell]
	cells_changed.emit(changed)
	glow_layer.queue_redraw()


## Death or R: every cell is grass again (Room.reset_objects calls this).
func reset() -> void:
	var changed: Array[Vector2i] = []
	for cell: Vector2i in cell_states:
		changed.append(cell)
	for cell: Vector2i in flames.keys():
		_remove_flames(cell)
	cell_states.clear()
	time_left.clear()
	state_duration.clear()
	ignite_clock.clear()
	ignite_origin.clear()
	specks.clear()
	branches.clear()
	pending.clear()
	pending_origin.clear()
	burning_count = 0
	if not changed.is_empty():
		cells_changed.emit(changed)
	glow_layer.queue_redraw()


# --- Every frame -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if GameState.current_room != room:
		return  # not the room on screen: the fire waits
	if time_left.is_empty() and pending.is_empty():
		return
	fire_clock += delta
	# Collect first, change after: a Dictionary must not change while we loop over it.
	var burnt_out: Array[Vector2i] = []
	var smoldered_out: Array[Vector2i] = []
	for cell: Vector2i in time_left:
		var remaining: float = float(time_left[cell]) - delta
		time_left[cell] = remaining
		if remaining <= 0.0:
			if cell_states[cell] == State.BURNING:
				burnt_out.append(cell)
			else:
				smoldered_out.append(cell)
		elif cell_states[cell] == State.SMOLDERING and randf() < SMOLDER_SMOKE_CHANCE * delta:
			SmokePuff.spawn(room, to_global(_get_random_surface_point(cell)), 1)
	# Grass smolders; thicket crumbles and covers collapse, each in one batch, so the
	# layer and the painter redo their tiles once.
	var crumbled: Array[Vector2i] = []
	var collapsed: Array[Vector2i] = []
	for cell: Vector2i in burnt_out:
		match get_fuel(cell):
			Fuel.THICKET:
				crumbled.append(cell)
			Fuel.OVERGROWN:
				collapsed.append(cell)
			_:
				_start_smoldering(cell)
	for cell: Vector2i in smoldered_out:
		_become_ash(cell)
	if not crumbled.is_empty():
		_crumble_thicket(crumbled)
	if not collapsed.is_empty():
		_collapse_cover(collapsed)
	_drop_thicket_clumps(delta)
	_process_pending()
	_check_player()
	if burning_count > 0:
		Heat.heat_receivers(get_tree(), self, delta)


## The heat-source contract (heat.gd): the weak updraft over burning cells. A point
## gets grass_updraft_lift if it is over a burning cell whose top is open, at most
## grass_updraft_height px above that top (inside the cell's columns of x).
func get_heat_lift_at(world_point: Vector2) -> float:
	if burning_count == 0 or GameState.current_room != room:
		return 0.0
	var point: Vector2 = to_local(world_point)
	var column_cell: Vector2i = geometry_layer.local_to_map(point - geometry_layer.position)
	# The burning cell may be under the point, or as far down as the updraft reaches.
	var reach_cells: int = ceili(fire_tuning.grass_updraft_height / tile_size) + 1
	for step: int in range(0, reach_cells + 1):
		var cell: Vector2i = column_cell + Vector2i(0, step)
		if get_state(cell) != State.BURNING or is_solid(cell + Vector2i.UP):
			continue
		var top: float = get_cell_rect(cell).position.y
		if point.y <= top and point.y >= top - fire_tuning.grass_updraft_height:
			return fire_tuning.grass_updraft_lift
	return 0.0


## True if `cell`'s flames kill right now: burning grass from the moment it catches,
## thicket once its flames break out of the inside glow, a cover once the
## flash-over front has reached it.
func is_deadly(cell: Vector2i) -> bool:
	if get_state(cell) != State.BURNING:
		return false
	var since_lit: float = get_time_burning_signed(cell)
	if since_lit < 0.0:
		return false  # the flash-over front isn't here yet
	if get_fuel(cell) == Fuel.THICKET:
		return since_lit >= _get_glow_time(cell)
	return true


## Seconds since `cell` caught: negative while a flash-over front is still on its
## way to it, 0 for cells that aren't burning.
func get_time_burning_signed(cell: Vector2i) -> float:
	if get_state(cell) != State.BURNING:
		return 0.0
	return fire_clock - float(ignite_clock[cell])


## Seconds a burning thicket cell only glows before its flames break out.
func _get_glow_time(cell: Vector2i) -> float:
	return float(state_duration.get(cell, 0.0)) * fire_tuning.thicket_glow_share


## Kills the player if their body touches a burning cell's band of flame.
func _check_player() -> void:
	if burning_count == 0:
		return
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead():
		return
	if is_rect_in_flame(player.get_hitbox_rect()):
		player.die()


## True if `world_rect` touches a burning cell's band of flame. The kill test for the
## player, and (Stage F11, through FireHazard.touches_fire) for enemies walking in.
func is_rect_in_flame(world_rect: Rect2) -> bool:
	if burning_count == 0:
		return false
	var hitbox: Rect2 = Rect2(to_local(world_rect.position), world_rect.size)
	var reach: float = fire_tuning.grass_fire_hazard_height
	var first: Vector2i = geometry_layer.local_to_map(hitbox.position - Vector2.ONE * reach - geometry_layer.position)
	var last: Vector2i = geometry_layer.local_to_map(hitbox.end + Vector2.ONE * reach - geometry_layer.position)
	for x: int in range(first.x, last.x + 1):
		for y: int in range(first.y, last.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not is_deadly(cell):
				continue
			for normal: Vector2i in get_open_sides(cell):
				# intersects() ignores rectangles that only share an edge: standing on
				# the cell NEXT to a burning one is safe.
				if get_flame_band(cell, normal).intersects(hitbox):
					return true
	return false


func _process(_delta: float) -> void:
	if time_left.is_empty():
		return
	_update_flames()
	glow_layer.queue_redraw()


# --- Flames --------------------------------------------------------------------------

## The flames of a cell that just caught: a random number on each open side (floors
## 1 to grass_tongues_per_tile + 1, walls 1-2, ceilings 1), each placed at random.
func _add_flames(cell: Vector2i) -> void:
	var cell_flames: Array[Dictionary] = []
	flames[cell] = cell_flames
	for normal: Vector2i in get_open_sides(cell):
		_add_side_flames(cell, normal)


## Burning `cell` got a new open side (a neighbour burnt away): flames there too.
func _add_missing_flames(cell: Vector2i) -> void:
	if not flames.has(cell):
		return
	var sides_with_flames: Array[Vector2i] = []
	for flame: Dictionary in flames[cell]:
		if not sides_with_flames.has(flame["normal"]):
			sides_with_flames.append(flame["normal"])
	for normal: Vector2i in get_open_sides(cell):
		if not sides_with_flames.has(normal):
			_add_side_flames(cell, normal)


## A random number of flames on one open side of `cell`, added to flames[cell].
func _add_side_flames(cell: Vector2i, normal: Vector2i) -> void:
	var cell_flames: Array[Dictionary] = flames[cell]
	var count: int = 1
	if normal == Vector2i.UP:
		count = randi_range(1, fire_tuning.grass_tongues_per_tile + 1)
	elif normal.x != 0:
		count = randi_range(1, 2)
	for index: int in count:
		var tongue: FlameTongue = FlameTongue.new()
		tongue.base_width = randf_range(2.5, 3.5)
		tongue.fan_width = randf_range(3.2, 4.8)
		tongue.flicker_speed = randf_range(0.8, 1.8)
		tongue.wobble_amount = randf_range(0.3, 0.45)
		tongue.breath_amount = randf_range(0.15, 0.3)
		tongue.fork_amount = randf_range(0.2, 0.6)
		tongue.lick_rate = randf_range(1.5, 4.0)
		tongue.lick_size = 2.5
		tongue.lick_speed = 14.0
		tongue.smoke_rate = fire_tuning.grass_smoke_per_second / float(count)
		tongue.visible = false
		add_child(tongue)
		flame_merge.add_tongue(tongue)
		var flame: Dictionary = {"node": tongue, "normal": normal}
		# A flame added late (a side opened up) starts now, not back at the catch.
		_place_flame(cell, flame, maxf(get_time_burning_signed(cell), 0.0))
		cell_flames.append(flame)


## Puts `flame` at a random spot on its side of `cell`, with a random size and lean,
## starting when the creep reaches it (but not before `earliest`, seconds after the
## cell caught) and living a random share of the cell's burn.
func _place_flame(cell: Vector2i, flame: Dictionary, earliest: float) -> void:
	var normal: Vector2i = flame["normal"]
	var rect: Rect2 = get_cell_rect(cell)
	var across: Vector2 = Vector2(absf(normal.y), absf(normal.x))
	var along: float = randf_range(-0.5 - TONGUE_OVERHANG, 0.5 + TONGUE_OVERHANG) * tile_size
	# Sunk 0-1 px into the ground, so the foot hides in the crust's dents.
	var base: Vector2 = rect.get_center() + Vector2(normal) * (tile_size / 2.0 - randf_range(0.0, 1.0)) + across * along
	var direction: Vector2 = Vector2(normal)
	var length_factor: float = randf_range(0.55, 1.35)
	if normal.x != 0:
		direction = (Vector2(normal) + Vector2.UP * randf_range(1.0, 2.0)).normalized()  # flames rise
		length_factor *= 0.7
	elif normal == Vector2i.DOWN:
		length_factor *= 0.45
	match get_fuel(cell):
		Fuel.THICKET:
			length_factor *= THICKET_FLAME_SCALE
			# The flames break out of the inside glow.
			earliest = maxf(earliest, _get_glow_time(cell))
		Fuel.OVERGROWN:
			length_factor *= OVERGROWN_FLAME_SCALE
	var duration: float = float(state_duration[cell])
	var start: float = maxf(get_creep_delay(cell, base), earliest)
	var life: float = duration * randf_range(TONGUE_MIN_LIFE, TONGUE_MAX_LIFE)
	flame["base"] = base
	flame["direction"] = direction.rotated(randf_range(-0.25, 0.25))
	flame["length"] = fire_tuning.grass_flame_length * length_factor
	flame["start"] = start
	flame["end"] = minf(start + life, duration)
	var tongue: FlameTongue = flame["node"]
	tongue.position = base
	# FlameTongue draws toward its local -Y; -Y has angle -PI/2, hence + PI/2.
	tongue.rotation = (flame["direction"] as Vector2).angle() + PI / 2.0


func _remove_flames(cell: Vector2i) -> void:
	if not flames.has(cell):
		return
	for flame: Dictionary in flames[cell]:
		(flame["node"] as FlameTongue).queue_free()
	flames.erase(cell)


## Every flame's size this frame: hidden until its start, growing in, flaring (1.5x,
## white-hot) for grass_flare_time, then full, dying down over the last part of its
## life. A flame that has died comes back elsewhere while the cell has time left.
func _update_flames() -> void:
	for cell: Vector2i in flames:
		var since_lit: float = get_time_burning(cell)
		var duration: float = float(state_duration[cell])
		for flame: Dictionary in flames[cell]:
			if since_lit >= float(flame["end"]) and duration - since_lit > TONGUE_REBIRTH_MIN_TIME:
				_place_flame(cell, flame, since_lit + randf_range(0.0, 0.15))
			var tongue: FlameTongue = flame["node"]
			var size: float = _get_flame_size(flame, since_lit)
			tongue.visible = size > 0.02
			tongue.length = float(flame["length"]) * size * (1.0 + 0.5 * _get_flare(flame, since_lit))
			tongue.heat = lerpf(0.4, 1.0, _get_flare(flame, since_lit))


## 0..1: how grown a flame is at `since_lit` seconds into its cell's burn.
func _get_flame_size(flame: Dictionary, since_lit: float) -> float:
	var start: float = flame["start"]
	var end: float = flame["end"]
	if since_lit < start or since_lit >= end:
		return 0.0
	var grow: float = clampf((since_lit - start) / TONGUE_GROW_TIME, 0.0, 1.0)
	var fade_time: float = maxf((end - start) * TONGUE_FADE_SHARE, 0.01)
	var fade: float = clampf((end - since_lit) / fade_time, 0.0, 1.0)
	return grow * fade


## 1 the moment a flame appears, easing to 0 over grass_flare_time.
func _get_flare(flame: Dictionary, since_lit: float) -> float:
	var age: float = since_lit - float(flame["start"])
	if age < 0.0:
		return 0.0
	return 1.0 - smoothstep(0.0, maxf(fire_tuning.grass_flare_time, 0.001), age)


## The middle of the cell's top side (or its center if the top is buried), local.
func _get_top_point(cell: Vector2i) -> Vector2:
	var rect: Rect2 = get_cell_rect(cell)
	if not is_solid(cell + Vector2i.UP):
		return Vector2(rect.get_center().x, rect.position.y)
	return rect.get_center()


## A random spot on one of the cell's open sides, local.
func _get_random_surface_point(cell: Vector2i) -> Vector2:
	var sides: Array[Vector2i] = get_open_sides(cell)
	var rect: Rect2 = get_cell_rect(cell)
	if sides.is_empty():
		return rect.get_center()
	var normal: Vector2i = sides[randi() % sides.size()]
	var across: Vector2 = Vector2(absf(normal.y), absf(normal.x))
	return rect.get_center() + Vector2(normal) * tile_size / 2.0 + across * randf_range(-0.4, 0.4) * tile_size


# --- Drawing -------------------------------------------------------------------------

## Additive layer: a soft glow under each flame (brighter and yellow while it
## flares), and the ember specks of smoldering cells.
func _draw_glow() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for cell: Vector2i in flames:
		var since_lit: float = get_time_burning(cell)
		for flame: Dictionary in flames[cell]:
			var size: float = _get_flame_size(flame, since_lit)
			if size <= 0.02:
				continue
			var base: Vector2 = flame["base"]
			var flicker: float = 0.8 + 0.2 * sin(now * 13.0 + base.x * 1.7 + base.y)
			var radius: float = float(flame["length"]) * GLOW_RADIUS_SHARE * size
			_draw_soft_glow(base, radius, Color(EMBER_HOT_COLOR, GLOW_ALPHA * flicker * size))
			var flare: float = _get_flare(flame, since_lit)
			if flare > 0.01:
				_draw_soft_glow(base - Vector2(flame["direction"]) * 1.5, radius * 1.4,
					Color(FlameTongue.INNER_COLOR, 0.35 * flare))
	for cell: Vector2i in specks:
		_draw_specks(cell, now)
	for cell: Vector2i in branches:
		_draw_thicket_glow(cell, now)
	for cell: Vector2i in flames:
		if get_fuel(cell) == Fuel.OVERGROWN:
			_draw_flashover(cell)


## A burning thicket cell glows from inside along its branches: brightening over the
## glow phase, flickering, dimming as it's about to crumble.
func _draw_thicket_glow(cell: Vector2i, now: float) -> void:
	var since_lit: float = get_time_burning(cell)
	var glow_time: float = maxf(_get_glow_time(cell), 0.001)
	var rise: float = clampf(since_lit / glow_time, 0.0, 1.0)
	var fade: float = 1.0 - 0.5 * get_burn_progress(cell)
	var center: Vector2 = get_cell_rect(cell).get_center()
	var flicker: float = 0.75 + 0.25 * sin(now * 17.0 + center.x * 0.9 + center.y * 0.4)
	var strength: float = rise * fade * flicker
	_draw_soft_glow(center, tile_size * 0.8, Color(EMBER_HOT_COLOR, 0.3 * strength))
	for branch: Array in branches[cell]:
		glow_layer.draw_line(branch[0], branch[1], Color(EMBER_HOT_COLOR.lerp(FlameTongue.INNER_COLOR, rise * 0.5), strength), 1.0)


## A flashing cover cell: a white-hot flash as the front reaches it (the bright line
## racing across the cover), then a steady sheet of glow until the collapse.
func _draw_flashover(cell: Vector2i) -> void:
	var since_front: float = get_time_burning_signed(cell)
	if since_front < 0.0:
		return  # the front isn't here yet
	var rect: Rect2 = get_cell_rect(cell)
	var flash: float = 1.0 - smoothstep(0.0, 0.08, since_front)
	if flash > 0.0:
		glow_layer.draw_rect(rect.grow(1.0), Color(FlameTongue.CORE_COLOR, 0.8 * flash))
	_draw_soft_glow(rect.get_center(), tile_size * 1.1, Color(FlameTongue.INNER_COLOR, 0.35 + 0.3 * flash))


## A thicket cell's glowing branches: a few short strokes at random angles through
## the cell (local px), laid out once when it catches.
func _make_branches(cell: Vector2i) -> Array:
	var rect: Rect2 = get_cell_rect(cell).grow(-1.0)
	var cell_branches: Array = []
	for branch_index: int in THICKET_BRANCHES_PER_CELL:
		var from: Vector2 = Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y)).floor() + Vector2(0.5, 0.5)
		var to: Vector2 = (from + Vector2.from_angle(randf() * TAU) * randf_range(3.0, 6.0)).clamp(rect.position, rect.end)
		cell_branches.append([from, to])
	return cell_branches


## A round glow that fades toward its edge: the shared glow picture stretched to
## `radius` and tinted `color` (see glow_texture).
func _draw_soft_glow(center: Vector2, radius: float, color: Color) -> void:
	if radius < 0.5:
		return
	glow_layer.draw_texture_rect(_get_glow_texture(), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
		false, color)


## The shared glow picture: white in the middle fading to transparent at the edge
## (a radial GradientTexture2D, a texture Godot computes from a Gradient).
static func _get_glow_texture() -> GradientTexture2D:
	if glow_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.4))  # falls off fast, then trails
		glow_texture = GradientTexture2D.new()
		glow_texture.gradient = gradient
		glow_texture.fill = GradientTexture2D.FILL_RADIAL
		glow_texture.fill_from = Vector2(0.5, 0.5)
		glow_texture.fill_to = Vector2(1.0, 0.5)
		glow_texture.width = GLOW_TEXTURE_SIZE
		glow_texture.height = GLOW_TEXTURE_SIZE
	return glow_texture


## A smoldering cell's specks: random spots along its open sides, each with its own
## moment to go dark and its own pulse. Made once, when the smolder starts.
func _make_specks(cell: Vector2i) -> Array:
	var cell_specks: Array = []
	var sides: Array[Vector2i] = get_open_sides(cell)
	if sides.is_empty():
		return cell_specks
	var rect: Rect2 = get_cell_rect(cell)
	for speck_index: int in SPECKS_PER_CELL:
		var normal: Vector2i = sides[randi() % sides.size()]
		var across: Vector2 = Vector2(absf(normal.y), absf(normal.x))
		var along: float = randf_range(-0.45, 0.45) * tile_size
		var depth: float = randf_range(0.5, 2.5)
		var pixel: Vector2 = (rect.get_center() + Vector2(normal) * (tile_size / 2.0 - depth) + across * along).floor()
		cell_specks.append([pixel, randf_range(0.15, 1.0), randf_range(4.0, 9.0), randf() * TAU])
	return cell_specks


## The specks blink out one by one over the smolder, each in a faint glow.
func _draw_specks(cell: Vector2i, now: float) -> void:
	var duration: float = maxf(float(state_duration[cell]), 0.001)
	var smolder_progress: float = 1.0 - float(time_left[cell]) / duration
	for speck: Array in specks[cell]:
		var out_at: float = speck[1]
		if smolder_progress >= out_at:
			continue
		var pixel: Vector2 = speck[0]
		var pulse: float = 0.5 + 0.5 * sin(now * float(speck[2]) + float(speck[3]))
		# Dimmer as it nears its moment to go out.
		var life: float = clampf((out_at - smolder_progress) / 0.15, 0.0, 1.0)
		_draw_soft_glow(pixel + Vector2(0.5, 0.5), 2.0, Color(EMBER_COLOR, 0.25 * life))
		glow_layer.draw_rect(Rect2(pixel, Vector2.ONE), Color(EMBER_COLOR.lerp(EMBER_HOT_COLOR, pulse), life))

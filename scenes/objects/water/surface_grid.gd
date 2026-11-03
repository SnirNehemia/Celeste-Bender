class_name SurfaceGrid
extends Node2D
## SurfaceGrid (Stage W8a, Water_bending.md §16 "Planned in Stage W8"): the WET LAYER
## of one room. It keeps one wet state per tile and is what the rest of the game asks
## "is this tile wet? is it mud?". The wet half of what the FireGrid is for fire.
##
## Made by the room's WaterWorld in its _ready (like the PlayerIceLayer), as its
## child, so its local coordinates are the room's. Only rooms with water have one:
## no water, nothing to wet. The WaterWorld resets it with itself (death or R).
##
## WHAT A TILE IS MADE OF (get_ground, read live, so a cell that burns to ash or an
## earth tile torn out changes with it):
##   ROCK     the grey ground ("Tiles"): wet as soon as any water TOUCHES one of its
##            faces (touch()); it soaks nothing, water runs and puddles on it. Wet
##            rock plays like dry rock: it's there to be frozen (W8b).
##   EARTH    the Earth layer (fresh, used, hardened): absorbent, MUD once full.
##   ASH      a grass cell the FireGrid burnt to ASH: absorbent, MUD once full (a
##            darker mud; it never sets into ashstone).
##   GRASS    unburnt grass: absorbent, WET GRASS once full: it won't burn.
##   THICKET  brambles: absorbent, WET THICKET once full: they won't burn.
##   NONE     anything else (stone walls, ice, open air): never wet.
## The WaterWorld does the soaking (its books count the water) and calls wet() when a
## tile is full; this grid only keeps the result.
##
## HEAT DRIES (Water_bending.md §8.2): a DIRECT flame on a wet tile dries it in a puff
## of steam instead of lighting it; the next flame lights it as usual. The grid joins
## the Flammable group with ignite_at() for that: it dries ROCK, EARTH and ASH mud
## itself. Grass and thicket are the FireGrid's: its ignite_at() asks dry_if_wet()
## before lighting a cell, and its can_catch() says no to a wet cell, so fire
## SPREADING from a neighbour never dries one (a wet line is a firebreak). A tile
## that dries tells the WaterWorld (`dried`), so it can soak water up again.
##
## THE ICY COAT (Stage W8b): a wet patch can be frozen into a coat of ice (hold 1
## with nothing to gather, steer the frost cursor onto it, press 2: the water hands
## ask find_wet_patch(), then coat()). A coated tile is still wet underneath (its byte
## says COATED, not DRY), so it soaks nothing and won't burn, but it's ICE to stand on
## (MudContact.is_on_coat: slippery, keeps speed) and not mud. It costs no water and
## isn't player ice (no cap). A direct flame MELTS the whole coated patch it touches
## back to WET (no drying that same frame): the next flame dries it.
##
## MUD (MudContact, scenes/player/abilities/water/mud_contact.gd, reads is_mud_at):
## sticky floor and walls. Where you cling, a hand print is left (add_hand_print).
##
## THE LOOK (_draw): a band along each open face of a wet tile, by material: wet rock
## darker with a light sheen on top, mud glossy brown (ash mud grey-black) that drips
## slowly from its undersides, wet grass a deeper green with a few drops.

## A tile just dried (heat): the WaterWorld lets it soak again.
signal dried(cell: Vector2i)

enum Ground { NONE, ROCK, EARTH, ASH, GRASS, THICKET }

## The byte kept per tile (wet_cells).
const DRY: int = 0
const WET: int = 1
const COATED: int = 2

const GROUP: StringName = &"surface_grid"
const NODE_NAME: StringName = &"SurfaceGrid"
const TILE: int = 8
## The grey ground's layer: the only rock that gets wet.
const ROCK_LAYER_NAME: StringName = &"Tiles"
## How deep the wet band reaches into a tile from each open face, px.
const BAND_DEPTH: float = 3.0
## The look (placeholder colors, Water_bending.md §12.1 water family + mud browns).
const WET_ROCK_COLOR: Color = Color(0.05, 0.07, 0.12, 0.45)
const WET_ROCK_SHEEN_COLOR: Color = Color(0.7, 0.85, 1.0, 0.35)
const MUD_COLOR: Color = Color("#4A3220")
const MUD_GLOSS_COLOR: Color = Color("#8C6A4A")
const ASH_MUD_COLOR: Color = Color("#2A2628")
const ASH_MUD_GLOSS_COLOR: Color = Color("#5E585A")
const WET_GRASS_COLOR: Color = Color(0.05, 0.2, 0.12, 0.45)
const WET_DROP_COLOR: Color = Color(0.65, 0.85, 1.0, 0.8)
const HAND_PRINT_COLOR: Color = Color("#2A1A10")
## A mud drip falls this far under the tile, px, once every DRIP_PERIOD seconds.
const DRIP_LENGTH: float = 5.0
const DRIP_PERIOD: float = 2.2
## Hand prints kept at once (the oldest goes).
const MAX_HAND_PRINTS: int = 24
## Steam specks a dried tile puffs.
const STEAM_SPECKS: int = 3
## The icy coat's look: a glassy band on each open face, a bright line on top.
const COAT_COLOR: Color = Color(0.62, 0.86, 0.97, 0.8)
const COAT_SHINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const COAT_DEPTH: float = 2.0
## The four neighbours a patch joins through (a coat is one connected face).
const PATCH_NEIGHBOURS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var water_world: WaterWorld
var room: Room
var rock_layer: TileMapLayer
var earth_layer: EarthLayer
var grass_layer: TileMapLayer
var thicket_layer: ThicketLayer
## The room's FireGrid, or null: it knows which grass is ash, and owns plants' fire.
var fire_grid: FireGrid
var grid_size: Vector2i = Vector2i.ZERO
## One byte per tile (y * grid_size.x + x): DRY, WET or COATED (wet under ice).
var wet_cells: PackedByteArray = PackedByteArray()
## One byte per tile: 1 = a dry ROCK tile, wet on touch. touch() reads only this, so
## water running over rock costs one byte read per column (§6.5 budget).
var touch_open: PackedByteArray = PackedByteArray()
## How many tiles are wet now, coated ones included (the look only redraws while
## there are some), and how many of them are coated.
var wet_count: int = 0
var coated_count: int = 0
## The physics frame a flame last melted a coat, and the tiles it melted: that same
## frame they don't dry too (one flame melts, the next dries).
var melted_frame: int = -1
var melted_cells: Dictionary = {}
## Hand prints, room-local px (the middle of each print).
var hand_prints: PackedVector2Array = PackedVector2Array()
## Seconds the look has run (drips), game time.
var look_clock: float = 0.0
## Did the last _draw draw a mud drip? Only then does the look redraw every frame.
var has_drips: bool = false


## Makes the grid for `world` (call before world.refresh_solid_cells).
static func create(world: WaterWorld) -> SurfaceGrid:
	var grid: SurfaceGrid = SurfaceGrid.new()
	grid.name = NODE_NAME
	grid.water_world = world
	grid.room = world.room
	grid.rock_layer = world.room.get_node_or_null(NodePath(ROCK_LAYER_NAME)) as TileMapLayer
	grid.earth_layer = world.earth_layer
	grid.grass_layer = world.grass_layer
	grid.thicket_layer = world.room.get_node_or_null("Thicket") as ThicketLayer
	# Made before the WaterWorld (Room._ready adds the FireGrid first).
	grid.fire_grid = world.room.get_node_or_null("FireGrid") as FireGrid
	return grid


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Flammable.GROUP)
	# Drawn over the ground but behind the player: not the WaterWorld's z_index 1.
	z_as_relative = false
	z_index = 0


## The grid of the room containing `world_position`, or null.
static func find_at(tree: SceneTree, world_position: Vector2) -> SurfaceGrid:
	for member: Node in tree.get_nodes_in_group(GROUP):
		var grid: SurfaceGrid = member as SurfaceGrid
		if grid != null and grid.room.get_bounds().has_point(world_position):
			return grid
	return null


## The grid of `target_room`, or null (a room with no water has none).
static func find_for_room(tree: SceneTree, target_room: Room) -> SurfaceGrid:
	for member: Node in tree.get_nodes_in_group(GROUP):
		var grid: SurfaceGrid = member as SurfaceGrid
		if grid != null and grid.room == target_room:
			return grid
	return null


## Sizes the grid to the room and reads which tiles are rock. The WaterWorld calls it
## from refresh_solid_cells (load, reset, tiles changed). A tile that stopped being
## solid (torn earth, crumbled thicket) is dry: there's nothing left to be wet.
func rebuild(new_grid_size: Vector2i) -> void:
	if new_grid_size != grid_size:
		grid_size = new_grid_size
		wet_cells.resize(grid_size.x * grid_size.y)
		wet_cells.fill(DRY)
		wet_count = 0
		coated_count = 0
	touch_open.resize(grid_size.x * grid_size.y)
	touch_open.fill(0)
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			var cell: Vector2i = Vector2i(x, y)
			var index: int = y * grid_size.x + x
			var ground: Ground = get_ground(cell)
			if ground == Ground.NONE and wet_cells[index] != DRY:
				if wet_cells[index] == COATED:
					coated_count -= 1
				wet_cells[index] = DRY
				wet_count -= 1
			if ground == Ground.ROCK and wet_cells[index] == DRY:
				touch_open[index] = 1
	queue_redraw()


## Death or R: everything is dry again.
func reset() -> void:
	wet_cells.fill(DRY)
	wet_count = 0
	coated_count = 0
	melted_cells.clear()
	hand_prints.clear()
	rebuild(grid_size)


# --- Reading ---------------------------------------------------------------------

## What tile `cell` is made of right now (see the header).
func get_ground(cell: Vector2i) -> Ground:
	if grass_layer != null and grass_layer.get_cell_source_id(cell) != -1:
		if fire_grid != null and fire_grid.get_state(cell) == FireGrid.State.ASH:
			return Ground.ASH
		return Ground.GRASS
	if thicket_layer != null and thicket_layer.has_thicket(cell):
		return Ground.THICKET
	if earth_layer != null and earth_layer.get_cell_source_id(cell) != -1:
		return Ground.EARTH
	if rock_layer != null and rock_layer.get_cell_source_id(cell) != -1:
		return Ground.ROCK
	return Ground.NONE


## Can tile `cell` SOAK water up (earth, ash, grass, thicket)? Rock doesn't: it's
## wet on touch. The WaterWorld's soaking asks this.
func is_absorbent(cell: Vector2i) -> bool:
	var ground: Ground = get_ground(cell)
	return ground == Ground.EARTH or ground == Ground.ASH \
		or ground == Ground.GRASS or ground == Ground.THICKET


## Wet, coated or not.
func is_wet(cell: Vector2i) -> bool:
	return _is_inside(cell) and wet_cells[cell.y * grid_size.x + cell.x] != DRY


## Wet under an icy coat (Stage W8b).
func is_coated(cell: Vector2i) -> bool:
	return _is_inside(cell) and wet_cells[cell.y * grid_size.x + cell.x] == COATED


## Is `cell` MUD: wet earth or wet ash, not under a coat (the coat is ice, not mud)?
func is_mud(cell: Vector2i) -> bool:
	if not _is_inside(cell) or wet_cells[cell.y * grid_size.x + cell.x] != WET:
		return false
	var ground: Ground = get_ground(cell)
	return ground == Ground.EARTH or ground == Ground.ASH


## The tile holding the world point `world_point`.
func get_cell_at(world_point: Vector2) -> Vector2i:
	return Vector2i((to_local(world_point) / TILE).floor())


func is_mud_at(world_point: Vector2) -> bool:
	return is_mud(get_cell_at(world_point))


func is_wet_at(world_point: Vector2) -> bool:
	return is_wet(get_cell_at(world_point))


func is_coated_at(world_point: Vector2) -> bool:
	return is_coated(get_cell_at(world_point))


func get_wet_count() -> int:
	return wet_count


# --- Wetting and drying -----------------------------------------------------------

## Tile `cell` is wet now (an absorbent tile soaked full, or water touched rock).
## Returns true if it was dry. Tiles that can't be wet are left alone.
func wet(cell: Vector2i) -> bool:
	if not _is_inside(cell) or get_ground(cell) == Ground.NONE:
		return false
	var index: int = cell.y * grid_size.x + cell.x
	if wet_cells[index] != DRY:
		return false
	wet_cells[index] = WET
	touch_open[index] = 0
	wet_count += 1
	queue_redraw()
	return true


## Water touched tile `cell`: a dry ROCK tile is wet now. One byte read when it isn't
## (the WaterWorld calls this for every column of water standing on rock).
func touch(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return
	if touch_open[cell.y * grid_size.x + cell.x] == 1:
		wet(cell)


## The same by tile index (y * grid_size.x + x), for the WaterWorld's hot loops.
func touch_index(index: int) -> void:
	if index >= 0 and index < touch_open.size() and touch_open[index] == 1:
		wet(Vector2i(index % grid_size.x, floori(float(index) / grid_size.x)))


## Wets every tile that can be wet within `radius` px of `world_point` (Wettable's
## wet_near: water that doused a fire). Returns how many tiles turned wet.
func wet_at(world_point: Vector2, radius: float) -> int:
	var count: int = 0
	for cell: Vector2i in _cells_near(to_local(world_point), radius):
		if wet(cell):
			count += 1
	return count


## Heat on tile `cell`: if it's wet, it dries in a puff of steam (and doesn't catch).
## A COATED tile melts instead: its whole coated patch turns back to wet (melt_coat).
## Returns true if it was wet (or coated). The FireGrid asks this before lighting a
## plant cell.
func dry_if_wet(cell: Vector2i) -> bool:
	if not is_wet(cell):
		return false
	if is_coated(cell):
		melt_coat(cell)
		return true
	# Melted by this same flame a moment ago: wet now, but it stays wet this frame (a
	# flame reaching over several tiles of one patch must not melt AND dry it).
	if melted_frame == Engine.get_physics_frames() and melted_cells.has(cell):
		return true
	var index: int = cell.y * grid_size.x + cell.x
	wet_cells[index] = DRY
	wet_count -= 1
	if get_ground(cell) == Ground.ROCK:
		touch_open[index] = 1
	_puff_steam(cell)
	queue_redraw()
	dried.emit(cell)
	return true


# --- The icy coat (Stage W8b) -------------------------------------------------------

## The connected patch of wet, uncoated tiles (4 neighbours, any mix of wet rock,
## mud and wet grass) touched by a circle of `radius` px round `world_point` (the
## frost cursor). Breadth-first from the touched tiles, so when the patch is bigger
## than `max_tiles` the tiles nearest the cursor are the ones kept. Empty: the
## cursor touches no wet tile.
func find_wet_patch(world_point: Vector2, radius: float, max_tiles: int) -> Array[Vector2i]:
	var patch: Array[Vector2i] = []
	if wet_count - coated_count <= 0:
		return patch
	var seen: Dictionary = {}
	for cell: Vector2i in _cells_near(to_local(world_point), radius):
		if is_wet(cell) and not is_coated(cell) and patch.size() < max_tiles:
			patch.append(cell)
			seen[cell] = true
	# The patch array doubles as the breadth-first queue.
	var next: int = 0
	while next < patch.size() and patch.size() < max_tiles:
		var cell: Vector2i = patch[next]
		next += 1
		for step: Vector2i in PATCH_NEIGHBOURS:
			var neighbour: Vector2i = cell + step
			if seen.has(neighbour) or not is_wet(neighbour) or is_coated(neighbour):
				continue
			seen[neighbour] = true
			patch.append(neighbour)
			if patch.size() >= max_tiles:
				break
	return patch


## Freezes `cells` (from find_wet_patch) into an icy coat. Returns how many tiles
## were coated (wet, uncoated ones only).
func coat(cells: Array[Vector2i]) -> int:
	var count: int = 0
	for cell: Vector2i in cells:
		if not is_wet(cell) or is_coated(cell):
			continue
		wet_cells[cell.y * grid_size.x + cell.x] = COATED
		coated_count += 1
		count += 1
	if count > 0:
		queue_redraw()
	return count


## A flame on a coated tile: the whole connected coated patch it belongs to melts
## back to WET (not dry: the next flame dries it), with a puff of steam where the
## flame touched. Returns how many tiles melted.
func melt_coat(cell: Vector2i) -> int:
	if not is_coated(cell):
		return 0
	var frame: int = Engine.get_physics_frames()
	if melted_frame != frame:
		melted_frame = frame
		melted_cells.clear()
	var queue: Array[Vector2i] = [cell]
	wet_cells[cell.y * grid_size.x + cell.x] = WET
	var next: int = 0
	while next < queue.size():
		var current: Vector2i = queue[next]
		next += 1
		melted_cells[current] = true
		for step: Vector2i in PATCH_NEIGHBOURS:
			var neighbour: Vector2i = current + step
			if is_coated(neighbour):
				# Set at once, so it's never queued twice.
				wet_cells[neighbour.y * grid_size.x + neighbour.x] = WET
				queue.append(neighbour)
	coated_count -= queue.size()
	_puff_steam(cell)
	queue_redraw()
	return queue.size()


func get_coated_count() -> int:
	return coated_count


## A hand print where you cling to mud (room-local px from the world point).
func add_hand_print(world_point: Vector2) -> void:
	var point: Vector2 = to_local(world_point).round()
	for existing: Vector2 in hand_prints:
		if existing.distance_squared_to(point) < 9.0:  # closer than 3 px (squared: 9)
			return  # already one there
	hand_prints.append(point)
	if hand_prints.size() > MAX_HAND_PRINTS:
		hand_prints.remove_at(0)
	queue_redraw()


# --- The Flammable contract (heat dries) --------------------------------------------

## A direct flame at `world_point`, reaching `radius` px: wet rock, earth and ash mud
## there dry (steam); a coat there melts back to wet (dry_if_wet). Never catches: returns false. Plant cells are left to the
## FireGrid (it dries them itself before lighting them).
func ignite_at(world_point: Vector2, radius: float, _source: Node) -> bool:
	if wet_count == 0:
		return false
	for cell: Vector2i in _cells_near(to_local(world_point), radius):
		var ground: Ground = get_ground(cell)
		if fire_grid != null and (ground == Ground.GRASS or ground == Ground.ASH or ground == Ground.THICKET):
			continue  # the FireGrid's cell
		dry_if_wet(cell)
	return false


## The grid as a whole doesn't burn.
func ignite(_source: Node) -> void:
	pass


func is_burning() -> bool:
	return false


func snuff() -> void:
	pass


# --- Helpers ----------------------------------------------------------------------

func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


## The tiles whose rectangle, grown by `radius`, holds the room-local `point`.
func _cells_near(point: Vector2, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var first: Vector2i = Vector2i(((point - Vector2.ONE * radius) / TILE).floor())
	var last: Vector2i = Vector2i(((point + Vector2.ONE * radius) / TILE).floor())
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if _is_inside(cell) and Rect2(Vector2(cell * TILE), Vector2.ONE * TILE).grow(radius).has_point(point):
				cells.append(cell)
	return cells


func _puff_steam(cell: Vector2i) -> void:
	var top: Vector2 = to_global(Vector2(cell * TILE) + Vector2(TILE * 0.5, 0.0))
	var steam: SmokePuff = SmokePuff.spawn(room, top, STEAM_SPECKS)
	# Steam is white, not smoke gray (the same puff, recolored).
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.7))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	steam.color_ramp = fade


## Is `cell` open air for the look (not solid in the WaterWorld's grid)?
func _is_open(cell: Vector2i) -> bool:
	return not water_world.is_cell_solid(cell)


# --- The look -------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Only mud drips move; everything else is drawn once when it changes.
	if has_drips and GameState.current_room == room:
		look_clock += delta
		queue_redraw()


func _draw() -> void:
	has_drips = false
	if wet_count > 0:
		for index: int in wet_cells.size():
			if wet_cells[index] != DRY:
				_draw_wet_cell(Vector2i(index % grid_size.x, floori(float(index) / grid_size.x)))
	for print_point: Vector2 in hand_prints:
		# Two small smudges: a palm and fingers above it.
		draw_rect(Rect2(print_point + Vector2(-1.0, 0.0), Vector2(2.0, 2.0)), HAND_PRINT_COLOR)
		draw_rect(Rect2(print_point + Vector2(-1.0, -2.0), Vector2(1.0, 1.0)), HAND_PRINT_COLOR)
		draw_rect(Rect2(print_point + Vector2(0.5, -2.0), Vector2(1.0, 1.0)), HAND_PRINT_COLOR)


## One wet tile: a band along each open face, colored by material.
func _draw_wet_cell(cell: Vector2i) -> void:
	var ground: Ground = get_ground(cell)
	var origin: Vector2 = Vector2(cell * TILE)
	var band_color: Color = WET_ROCK_COLOR
	var shine_color: Color = WET_ROCK_SHEEN_COLOR
	match ground:
		Ground.EARTH:
			band_color = MUD_COLOR
			shine_color = MUD_GLOSS_COLOR
		Ground.ASH:
			band_color = ASH_MUD_COLOR
			shine_color = ASH_MUD_GLOSS_COLOR
		Ground.GRASS, Ground.THICKET:
			band_color = WET_GRASS_COLOR
			shine_color = WET_DROP_COLOR
	var is_mud_tile: bool = ground == Ground.EARTH or ground == Ground.ASH
	# Mud is the whole tile's face; the others only a damp band.
	var depth: float = float(TILE) if is_mud_tile else BAND_DEPTH
	if _is_open(cell + Vector2i.UP):
		draw_rect(Rect2(origin, Vector2(TILE, depth)), band_color)
		# A sheen line on top (a glossy streak for mud, a light line for rock).
		draw_rect(Rect2(origin + Vector2(1.0, 0.0), Vector2(TILE - 2.0 if is_mud_tile else TILE - 1.0, 1.0)), shine_color)
	if _is_open(cell + Vector2i.LEFT):
		draw_rect(Rect2(origin, Vector2(depth, TILE)), band_color)
		if is_mud_tile:
			draw_rect(Rect2(origin + Vector2(0.0, 2.0), Vector2(1.0, 3.0)), shine_color)
	if _is_open(cell + Vector2i.RIGHT):
		draw_rect(Rect2(origin + Vector2(TILE - depth, 0.0), Vector2(depth, TILE)), band_color)
		if is_mud_tile:
			draw_rect(Rect2(origin + Vector2(TILE - 1.0, 3.0), Vector2(1.0, 3.0)), shine_color)
	if _is_open(cell + Vector2i.DOWN):
		draw_rect(Rect2(origin + Vector2(0.0, TILE - depth), Vector2(TILE, depth)), band_color)
		if is_mud_tile:
			# A slow drip off the underside: a drop that stretches, falls and comes back.
			has_drips = true
			# The small primes mixed from the cell's x and y give each tile its own drip
			# timing and spot, so neighbouring tiles never drip in step.
			var phase: float = fposmod(look_clock / DRIP_PERIOD + float((cell.x * 7 + cell.y * 3) % 11) / 11.0, 1.0)
			var drip_x: float = origin.x + 2.0 + float((cell.x * 5 + cell.y) % 4)
			draw_rect(Rect2(Vector2(drip_x, origin.y + TILE), Vector2(1.0, 1.0 + phase * DRIP_LENGTH)), band_color)
	if ground == Ground.GRASS or ground == Ground.THICKET:
		# A few drops caught in the blades (spots mixed from the cell, like the drips).
		for drop: int in 2:
			var drop_x: float = origin.x + 1.0 + float((cell.x * 3 + drop * 5) % 6)
			draw_rect(Rect2(Vector2(drop_x, origin.y - 1.0 - drop), Vector2(1.0, 1.0)), shine_color)
	if wet_cells[cell.y * grid_size.x + cell.x] == COATED:
		_draw_coat(cell, origin)


## The icy coat over a wet tile: a glassy band on each open face, a bright line on top.
func _draw_coat(cell: Vector2i, origin: Vector2) -> void:
	if _is_open(cell + Vector2i.UP):
		draw_rect(Rect2(origin, Vector2(TILE, COAT_DEPTH)), COAT_COLOR)
		draw_rect(Rect2(origin, Vector2(TILE, 1.0)), COAT_SHINE_COLOR)
	if _is_open(cell + Vector2i.LEFT):
		draw_rect(Rect2(origin, Vector2(COAT_DEPTH, TILE)), COAT_COLOR)
	if _is_open(cell + Vector2i.RIGHT):
		draw_rect(Rect2(origin + Vector2(TILE - COAT_DEPTH, 0.0), Vector2(COAT_DEPTH, TILE)), COAT_COLOR)
	if _is_open(cell + Vector2i.DOWN):
		draw_rect(Rect2(origin + Vector2(0.0, TILE - COAT_DEPTH), Vector2(TILE, COAT_DEPTH)), COAT_COLOR)

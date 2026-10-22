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
## Time: game time (physics delta), so slow motion slows the fire too. Only the room
## on screen burns (like the grass blades); a fire left behind waits.

## The look of these cells changed (they caught, started smoldering, became ash, or
## were reset). GroundPainter repaints them.
signal cells_changed(cells: Array[Vector2i])

enum State { GRASS, BURNING, SMOLDERING, ASH }

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
## Ash flakes left in the PebbleField when a cell turns to ash (§6.1: "ash flakes get
## kicked like pebbles").
const ASH_FLAKE_COLORS: Array[Color] = [Color("#4A4545"), Color("#7A7470")]
const ASH_FLAKES_PER_CELL: int = 2
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
var grass_layer: TileMapLayer
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


func _ready() -> void:
	room = get_parent() as Room
	grass_layer = room.get_node("Grass") as TileMapLayer
	earth_layer = room.get_node_or_null("Earth") as EarthLayer
	for child: Node in room.get_children():
		if child is TileMapLayer and not child is HiddenLayer:
			solid_layers.append(child)
	tile_size = grass_layer.tile_set.tile_size.x
	cell_bounds = Rect2i(Vector2i.ZERO, Vector2i((room.room_size / tile_size).ceil()))
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	add_to_group(Flammable.GROUP)
	add_to_group(FireHazard.GROUP)
	z_index = 1  # flames in front of the player's feet, like the grass blades
	glow_layer = Node2D.new()
	glow_layer.name = "Glow"
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = additive
	add_child(glow_layer)
	glow_layer.draw.connect(_draw_glow)


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
## px): the distance from where it came in, at one tile per spread_delay.
func get_creep_delay(cell: Vector2i, point: Vector2) -> float:
	var origin: Vector2 = ignite_origin.get(cell, get_cell_rect(cell).get_center())
	return minf(point.distance_to(origin) / tile_size, 1.2) * fire_tuning.spread_delay


## Like get_burn_progress, but for one spot of the cell (local px): 0 until the creep
## reaches it, then rising to 1 by the time the cell smolders.
func get_burn_progress_at(cell: Vector2i, point: Vector2) -> float:
	if get_state(cell) != State.BURNING:
		return 0.0
	var creep: float = get_creep_delay(cell, point)
	var duration: float = maxf(float(state_duration[cell]) - creep, 0.001)
	return clampf((get_time_burning(cell) - creep) / duration, 0.0, 1.0)


func is_grass_cell(cell: Vector2i) -> bool:
	return grass_layer.get_cell_source_id(cell) != -1


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


## True if fire could take hold of `cell`: unburnt grass with at least one open side.
func can_catch(cell: Vector2i) -> bool:
	return is_grass_cell(cell) and get_state(cell) == State.GRASS and not get_open_sides(cell).is_empty()


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


## The cell's rectangle in our (= the room's) local coordinates.
func get_cell_rect(cell: Vector2i) -> Rect2:
	var center: Vector2 = grass_layer.position + grass_layer.map_to_local(cell)
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
	var first: Vector2i = grass_layer.local_to_map(point - Vector2.ONE * (radius + 0.5) - grass_layer.position)
	var last: Vector2i = grass_layer.local_to_map(point + Vector2.ONE * (radius + 0.5) - grass_layer.position)
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


## Gusts against burning grass come in Stage F10.
func snuff() -> void:
	pass


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
	cell_states[cell] = State.BURNING
	var duration: float = _jitter(fire_tuning.burn_time)
	time_left[cell] = duration
	state_duration[cell] = duration
	ignite_clock[cell] = fire_clock
	ignite_origin[cell] = origin
	burning_count += 1
	peak_burning_count = maxi(peak_burning_count, burning_count)
	_add_flames(cell)
	# The next cells along the surface catch a little later, each with its own jitter,
	# their fire coming in at the edge they share with us.
	var rect: Rect2 = get_cell_rect(cell)
	for neighbour: Vector2i in get_spread_neighbours(cell):
		var neighbour_rect: Rect2 = get_cell_rect(neighbour)
		var entry: Vector2 = rect.get_center().clamp(neighbour_rect.position, neighbour_rect.end)
		var jitter: float = randf_range(-fire_tuning.spread_jitter, fire_tuning.spread_jitter)
		queue_ignition(neighbour, fire_tuning.spread_delay + jitter, entry)
	_ignite_touching_flammables(cell)
	EmberEmitter.burst(room, to_global(origin), 3, Vector2.UP, 50.0, 40.0)
	FX.play_sfx(&"fire_ignite")
	_announce_cell(cell)


## `base` give or take burn_time_jitter (a fraction), per cell.
func _jitter(base: float) -> float:
	var spread: float = fire_tuning.burn_time_jitter
	return maxf(base * randf_range(1.0 - spread, 1.0 + spread), 0.05)


## A fuse reaching a brazier: anything flammable the new flames touch catches too.
func _ignite_touching_flammables(cell: Vector2i) -> void:
	for target: Node in get_tree().get_nodes_in_group(Flammable.GROUP):
		if target == self or target is FireGrid:
			continue
		var target_rect: Rect2 = Flammable.get_fire_rect(target)
		for normal: Vector2i in get_open_sides(cell):
			var band: Rect2 = get_flame_band(cell, normal).grow(IGNITE_REACH)
			band.position = to_global(band.position)
			if band.intersects(target_rect) or band.has_point(target_rect.position):
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


func _become_ash(cell: Vector2i) -> void:
	cell_states[cell] = State.ASH
	time_left.erase(cell)
	state_duration.erase(cell)
	specks.erase(cell)
	PebbleField.leave_colored_pebbles(get_tree(), to_global(_get_top_point(cell)), ASH_FLAKES_PER_CELL,
		Vector2.UP, ASH_FLAKE_COLORS)
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
	for cell: Vector2i in burnt_out:
		_start_smoldering(cell)
	for cell: Vector2i in smoldered_out:
		_become_ash(cell)
	_process_pending()
	_check_player()


## Kills the player if their body touches a burning cell's band of flame.
func _check_player() -> void:
	if burning_count == 0:
		return
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead():
		return
	var hitbox: Rect2 = player.get_hitbox_rect()
	hitbox.position = to_local(hitbox.position)
	var reach: float = fire_tuning.grass_fire_hazard_height
	var first: Vector2i = grass_layer.local_to_map(hitbox.position - Vector2.ONE * reach - grass_layer.position)
	var last: Vector2i = grass_layer.local_to_map(hitbox.end + Vector2.ONE * reach - grass_layer.position)
	for x: int in range(first.x, last.x + 1):
		for y: int in range(first.y, last.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if get_state(cell) != State.BURNING:
				continue
			for normal: Vector2i in get_open_sides(cell):
				# intersects() ignores rectangles that only share an edge: standing on
				# the cell NEXT to a burning one is safe.
				if get_flame_band(cell, normal).intersects(hitbox):
					player.die()
					return


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
	for normal: Vector2i in get_open_sides(cell):
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
			var flame: Dictionary = {"node": tongue, "normal": normal}
			_place_flame(cell, flame, 0.0)
			cell_flames.append(flame)
	flames[cell] = cell_flames


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

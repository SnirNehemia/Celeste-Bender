class_name EarthLayer
extends TileMapLayer
## The earth in one room (Earth_bending.md §2): a TileMapLayer of earth tiles, each of
## which can be bent ONCE. Fresh earth is brown-yellow; used earth fades to dark brown
## and can't be bent again until the room resets.
##
## Setup: a TileMapLayer child of a Room, named "Earth", with this script and the
## earth tileset (resources/tiles/earth_tileset.tres), painted in the editor like the
## "Tiles" layer. Earth tiles are solid on physics layer 1 ("world"), so they work as
## ground, walls and ceilings exactly like gray tiles.
##
## What it tracks (painting decides WHERE earth is; this script tracks its STATE):
##   - used cells, with a 0..1 fade progress (0 = just used, 1 = fully dark)
##   - shivering cells (a quick bright flicker while the bend shadow passes)
##   - column cells: the tiles of open air that an Earth Column (or, since Stage E4,
##     a stuck Boulder) now fills (register_column / unregister_column). They count
##     as solid used earth, and the bend can start from them (Earth_bending.md §11).
##   - torn cells (Stage E4a): tiles a rock was torn out of. They're erased from the
##     map (open air now), and remembered with their tile id so reset can put them back.
##     Earth that was behind a torn tile is on the surface now, and fresh: thick earth
##     can be dug into, one rock at a time.
##   - hardened cells: earth holding up a pillar (a pyramid under its base) or a stuck
##     rock. Rocks can't tear them out, so nothing is left floating. They can still be
##     bent (columns, snake). Drawn slightly grayer.
## Room reset (death or R) clears all of it: every tile is back and fresh again
## (Room.reset_objects calls reset(), because we join Room.RESETTABLE_GROUP).
##
## Grass and gray (Stage E3 follow-up): the room's other tile layers are solid too,
## but the bend shadow treats them differently. Layers in SHADOW_PASSABLE_GROUP
## (the green "Grass" layer) let the shadow crawl over them; plain gray "Tiles"
## BLOCK it (is_shadow_blocking).
##
## Drawing (Stage E4b): the layer's own tile drawing is switched off (GroundPainter
## sets self_modulate to transparent); the room's GroundPainter draws the ground
## instead. This script only says how each tile should look (get_cell_modulate:
## darker if used, grayer if hardened, flickering brighter while shivering) and
## announces changes with two SIGNALS:
##   shape_changed  tiles appeared or disappeared (a tear, a reset): redraw all
##   look_changed   only states changed (used, fade, shiver, hardened): redraw those
## A signal is how a node says "something happened" without knowing who listens; the
## painter connects to these in its setup.
##
## Who uses it: EarthBendAbility (finds the earth under the player, marks tiles used,
## shivers them) through EarthFace. Lookups by world position go through
## find_layer_at() (every EarthLayer joins GROUP).

## Tiles appeared or disappeared (a tear, a reset). See the header.
signal shape_changed
## Only the look of some tiles changed (used, fading, shivering, hardened).
signal look_changed

## Group of every EarthLayer in the game, for find_layer_at().
const GROUP: StringName = &"earth_layer"
## Tile layers in this group (the "Grass" layer) let the bend shadow pass. Saved in
## the room scene (add_to_group(..., true) in tools/build_earth_rooms.gd).
const SHADOW_PASSABLE_GROUP: StringName = &"shadow_passable"
## Fresh earth color (color key in Earth_bending.md §2: brown-yellow). The tile picture
## itself is painted in this color (tools/build_earth_rooms.gd); kept here for the
## used-color math below and for gravel.
const FRESH_COLOR: Color = Color(0.74, 0.57, 0.27)
## Used earth color (dark brown). Also the color of columns, boulders and snakes later.
const USED_COLOR: Color = Color(0.33, 0.22, 0.13)
## Hardened earth is multiplied by this: a little darker and grayer, like packed stone.
const HARDENED_MODULATE: Color = Color(0.82, 0.8, 0.84)
## The four sides a face can point to, in clockwise order.
const FACE_NORMALS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

## Feel values (fade time, shiver). preload() of the same path returns the SAME
## resource object the player holds, so Remote-tab edits reach this layer too.
var earth_tuning: EarthTuning = preload("res://resources/earth_tuning.tres")
## Used cells -> fade progress (0..1). A cell in here is used, whatever its progress.
## A Dictionary used as a set-with-a-value (Vector2i keys).
var used_fade_progress: Dictionary = {}
## Shivering cells -> real seconds of shiver left.
var shiver_time_remaining: Dictionary = {}
## Real-time clock for the shiver's left/right flipping.
var shiver_clock: float = 0.0
## Other TileMapLayers in the same room ("Tiles", "Grass"): their cells count as
## solid when we decide which faces touch open air.
var neighbour_solid_layers: Array[TileMapLayer] = []
## Cells filled by a risen Earth Column -> that column (Node). Solid, used-earth.
var column_cells: Dictionary = {}
## Cells a rock was torn out of -> [source id, atlas coords] of the tile that was
## there, to paint it back on reset.
var torn_cells: Dictionary = {}
## Hardened cells (a set: Vector2i -> true). See the header.
var hardened_cells: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	for sibling: Node in get_parent().get_children():
		var sibling_layer: TileMapLayer = sibling as TileMapLayer
		if sibling_layer != null and sibling_layer != self:
			neighbour_solid_layers.append(sibling_layer)
	# Nothing animates until a tile is used or shivers (see _process).
	set_process(false)


## Finds the EarthLayer that has an earth tile at `world_position`, or null.
## Static = called on the class: EarthLayer.find_layer_at(get_tree(), point).
static func find_layer_at(tree: SceneTree, world_position: Vector2) -> EarthLayer:
	for node: Node in tree.get_nodes_in_group(GROUP):
		var earth_layer: EarthLayer = node as EarthLayer
		if earth_layer == null:
			continue
		var cell: Vector2i = earth_layer.get_cell_at(world_position)
		if earth_layer.is_earth(cell) or earth_layer.is_column(cell):
			return earth_layer
	return null


# --- Queries ---------------------------------------------------------------------

## The map cell containing `world_position`.
func get_cell_at(world_position: Vector2) -> Vector2i:
	return local_to_map(to_local(world_position))


## The center of `cell` in world coordinates. map_to_local gives the tile's center.
func get_cell_global_center(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))


## Half a tile, px (4 for 8 px tiles).
func get_half_tile_size() -> float:
	return tile_set.tile_size.x / 2.0


func is_earth(cell: Vector2i) -> bool:
	# get_cell_source_id() is -1 where nothing is painted.
	return get_cell_source_id(cell) != -1


func is_fresh(cell: Vector2i) -> bool:
	return is_earth(cell) and not used_fade_progress.has(cell)


## True if a rock may tear `cell` out: fresh earth that isn't holding anything up.
func is_tearable(cell: Vector2i) -> bool:
	return is_fresh(cell) and not hardened_cells.has(cell)


func is_hardened(cell: Vector2i) -> bool:
	return hardened_cells.has(cell)


## True if a risen Earth Column fills `cell`.
func is_column(cell: Vector2i) -> bool:
	return column_cells.has(cell)


## Earth of any kind: an earth tile (fresh or used) or a column. Gravel comes out of it.
func is_earthen(cell: Vector2i) -> bool:
	return is_earth(cell) or is_column(cell)


## Solid = earth, a column, or a tile on another layer of this room ("Tiles", "Grass").
func is_solid(cell: Vector2i) -> bool:
	if is_earth(cell) or is_column(cell):
		return true
	for solid_layer: TileMapLayer in neighbour_solid_layers:
		if solid_layer.get_cell_source_id(cell) != -1:
			return true
	return false


## True if `cell` is plain GRAY rock (a solid the shadow can't cross): solid, but not
## earth, not a column and not on a shadow-passable layer (grass).
func is_shadow_blocking(cell: Vector2i) -> bool:
	if is_earthen(cell):
		return false
	var is_gray: bool = false
	for solid_layer: TileMapLayer in neighbour_solid_layers:
		if solid_layer.get_cell_source_id(cell) != -1:
			if solid_layer.is_in_group(SHADOW_PASSABLE_GROUP):
				return false
			is_gray = true
	return is_gray


## True if `cell` is earth and its `normal` side touches open air (no solid there).
func is_face_exposed(cell: Vector2i, normal: Vector2i) -> bool:
	return is_earth(cell) and not is_solid(cell + normal)


## Like is_face_exposed, but for ANY solid tile (earth or gray): is this side of it
## on the surface? The bend shadow crawls over every surface (Earth_bending.md §11),
## it just can't erupt from gray or used tiles.
func is_surface(cell: Vector2i, normal: Vector2i) -> bool:
	return is_solid(cell) and not is_solid(cell + normal)


# --- Changing state --------------------------------------------------------------

## Spends a tile: it starts fading to dark and can't be bent again until reset.
## Returns false (and does nothing) if it wasn't fresh earth.
func mark_used(cell: Vector2i) -> bool:
	if not is_fresh(cell):
		return false
	used_fade_progress[cell] = 0.0
	_start_animating()
	return true


## Makes a tile flicker for `duration` real seconds (the shadow passing through).
func shiver(cell: Vector2i, duration: float) -> void:
	if not is_earth(cell):
		return
	shiver_time_remaining[cell] = maxf(float(shiver_time_remaining.get(cell, 0.0)), duration)
	_start_animating()


## Tears the tile at `cell` out of the ground (a rock was ripped from it): it becomes
## open air until the room resets. Returns false if there was no fresh earth there.
func tear_out(cell: Vector2i) -> bool:
	if not is_tearable(cell):
		return false
	torn_cells[cell] = [get_cell_source_id(cell), get_cell_atlas_coords(cell)]
	shiver_time_remaining.erase(cell)
	erase_cell(cell)
	# The layer normally rebuilds its collision at the end of the frame. Do it now, so
	# the rock that starts inside the hole doesn't collide with the tile it came from.
	update_internals()
	shape_changed.emit()
	return true


## Hardens the earth under a pillar's base: a pyramid `rows` deep going INTO the
## surface (along -normal), 1 tile wide at the base tile, then 3, then 5...
## Only earth tiles harden; open air and other tiles are skipped.
func harden_foot(base_cell: Vector2i, normal: Vector2i, rows: int) -> void:
	var inward: Vector2i = -normal
	var across: Vector2i = Vector2i(absi(normal.y), absi(normal.x))  # along the surface
	for row: int in rows:
		for offset: int in range(-row, row + 1):
			harden(base_cell + inward * row + across * offset)


## Hardens one earth tile (no effect on anything else).
func harden(cell: Vector2i) -> void:
	if not is_earth(cell):
		return
	hardened_cells[cell] = true
	look_changed.emit()


## A risen Earth Column now fills `cells` (EarthColumn calls this). They become
## solid used earth: the shadow crawls over them, and a bend can start from them.
func register_column(column: Node, cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		column_cells[cell] = column


## The column is gone (room reset): its cells are open air again.
func unregister_column(column: Node) -> void:
	for cell: Vector2i in column_cells.keys():
		if column_cells[cell] == column:
			column_cells.erase(cell)


## Room reset (Room.reset_objects): all earth fresh and still again.
func reset() -> void:
	# Fill the holes again with the exact tiles that were there.
	var had_holes: bool = not torn_cells.is_empty()
	for cell: Vector2i in torn_cells:
		var tile: Array = torn_cells[cell]
		set_cell(cell, tile[0], tile[1])
	torn_cells.clear()
	hardened_cells.clear()
	used_fade_progress.clear()
	shiver_time_remaining.clear()
	column_cells.clear()
	set_process(false)
	# Redrawing the whole ground costs ~0.1 s, so only announce a shape change if
	# holes were actually filled (most deaths don't tear anything).
	if had_holes:
		shape_changed.emit()
	look_changed.emit()


func _start_animating() -> void:
	set_process(true)
	look_changed.emit()


# --- Animation -------------------------------------------------------------------

## Runs only while something fades or shivers (set_process toggles it).
## Uses REAL time (delta undone by Engine.time_scale): the bend's slow motion
## shouldn't slow the earth's own feedback, so the shiver keeps pace with the
## real-time shadow.
func _process(delta: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	var is_animating: bool = false

	var fade_time: float = maxf(earth_tuning.used_fade_time, 0.001)
	for cell: Vector2i in used_fade_progress:
		var progress: float = used_fade_progress[cell]
		if progress < 1.0:
			used_fade_progress[cell] = minf(progress + real_delta / fade_time, 1.0)
			is_animating = true

	shiver_clock += real_delta
	# Collect finished shivers first: erasing from a Dictionary while looping over it
	# is not allowed.
	var finished_shivers: Array[Vector2i] = []
	for cell: Vector2i in shiver_time_remaining:
		var time_left: float = float(shiver_time_remaining[cell]) - real_delta
		if time_left <= 0.0:
			finished_shivers.append(cell)
		else:
			shiver_time_remaining[cell] = time_left
		is_animating = true  # one more update either way, to put the tile back in place
	for cell: Vector2i in finished_shivers:
		shiver_time_remaining.erase(cell)

	look_changed.emit()
	if not is_animating:
		set_process(false)


## Cells whose look differs from plain fresh earth (used, shivering or hardened).
## GroundPainter redraws these on look_changed.
func get_state_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for state: Dictionary in [used_fade_progress, shiver_time_remaining, hardened_cells]:
		for cell: Vector2i in state:
			if not cells.has(cell):
				cells.append(cell)
	return cells


## How tile `cell` should be tinted right now (multiplied onto its fresh colors):
## WHITE for plain fresh earth, darker if used (fading in), grayer if hardened, and
## flickering brighter while shivering.
func get_cell_modulate(cell: Vector2i) -> Color:
	var tile_modulate: Color = Color.WHITE
	if used_fade_progress.has(cell):
		tile_modulate = Color.WHITE.lerp(_get_used_modulate(), used_fade_progress[cell])
	if hardened_cells.has(cell):
		tile_modulate *= HARDENED_MODULATE
	if shiver_time_remaining.has(cell):
		# Bright on every other shiver_flip_interval. Values above 1 brighten.
		var flip_index: int = int(shiver_clock / maxf(earth_tuning.shiver_flip_interval, 0.001))
		if flip_index % 2 == 0:
			var brightness: float = earth_tuning.shiver_brightness
			tile_modulate = Color(tile_modulate.r * brightness, tile_modulate.g * brightness,
				tile_modulate.b * brightness)
	return tile_modulate


## The modulate that turns FRESH_COLOR into USED_COLOR. Modulate MULTIPLIES colors,
## so the factor per channel is used / fresh. Darker speckles darken by the same
## factor, so the texture survives.
func _get_used_modulate() -> Color:
	return Color(USED_COLOR.r / FRESH_COLOR.r, USED_COLOR.g / FRESH_COLOR.g, USED_COLOR.b / FRESH_COLOR.b)

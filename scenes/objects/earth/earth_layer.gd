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
## Room reset (death or R) clears both: every tile is fresh again (Room.reset_objects
## calls reset(), because we join Room.RESETTABLE_GROUP).
##
## How the colors change per tile: TileMapLayer draws the tiles itself, but lets a
## script adjust single tiles at runtime. _use_tile_data_runtime_update() answers
## "does this tile need adjusting?" and _tile_data_runtime_update() changes its
## TileData (a per-tile copy): `modulate` darkens it (used) or flickers it brighter
## (shiver). (A 1 px picture shift was tried first, but it opened a 1 px gap to the
## dark background next to the tile: a flickering black line.) notify_runtime_tile_data_update() asks the
## layer to run those two again after our state changes.
##
## Who uses it: EarthBendAbility (finds the earth under the player, marks tiles used,
## shivers them) through EarthFace. Lookups by world position go through
## find_layer_at() (every EarthLayer joins GROUP).

## Group of every EarthLayer in the game, for find_layer_at().
const GROUP: StringName = &"earth_layer"
## Fresh earth color (color key in Earth_bending.md §2: brown-yellow). The tile picture
## itself is painted in this color (tools/build_earth_rooms.gd); kept here for the
## used-color math below and for gravel.
const FRESH_COLOR: Color = Color(0.74, 0.57, 0.27)
## Used earth color (dark brown). Also the color of columns, boulders and snakes later.
const USED_COLOR: Color = Color(0.33, 0.22, 0.13)
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
## Other TileMapLayers in the same room ("Tiles"): their cells count as solid when we
## decide which faces touch open air.
var neighbour_solid_layers: Array[TileMapLayer] = []


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
		if earth_layer != null and earth_layer.is_earth(earth_layer.get_cell_at(world_position)):
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


## Solid = earth, or a tile on another layer of this room (the gray "Tiles").
func is_solid(cell: Vector2i) -> bool:
	if is_earth(cell):
		return true
	for solid_layer: TileMapLayer in neighbour_solid_layers:
		if solid_layer.get_cell_source_id(cell) != -1:
			return true
	return false


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


## Room reset (Room.reset_objects): all earth fresh and still again.
func reset() -> void:
	used_fade_progress.clear()
	shiver_time_remaining.clear()
	notify_runtime_tile_data_update()
	set_process(false)


func _start_animating() -> void:
	set_process(true)
	notify_runtime_tile_data_update()


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

	notify_runtime_tile_data_update()
	if not is_animating:
		set_process(false)


## TileMapLayer asks this for every tile: "do you want to adjust it at runtime?"
## Only used or shivering tiles do; the rest are drawn straight from the tileset.
func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return used_fade_progress.has(coords) or shiver_time_remaining.has(coords)


## Adjusts one tile's TileData (a copy just for this tile): darker if used, and
## flickering brighter / normal if shivering.
func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	var tile_modulate: Color = Color.WHITE
	if used_fade_progress.has(coords):
		tile_modulate = Color.WHITE.lerp(_get_used_modulate(), used_fade_progress[coords])
	if shiver_time_remaining.has(coords):
		# Bright on every other shiver_flip_interval. Modulate values above 1 brighten.
		var flip_index: int = int(shiver_clock / maxf(earth_tuning.shiver_flip_interval, 0.001))
		if flip_index % 2 == 0:
			var brightness: float = earth_tuning.shiver_brightness
			tile_modulate = Color(tile_modulate.r * brightness, tile_modulate.g * brightness,
				tile_modulate.b * brightness)
	tile_data.modulate = tile_modulate


## The modulate that turns FRESH_COLOR into USED_COLOR. Modulate MULTIPLIES the tile's
## colors, so the factor per channel is used / fresh. Darker speckles in the tile
## picture darken by the same factor, so the texture survives.
func _get_used_modulate() -> Color:
	return Color(USED_COLOR.r / FRESH_COLOR.r, USED_COLOR.g / FRESH_COLOR.g, USED_COLOR.b / FRESH_COLOR.b)

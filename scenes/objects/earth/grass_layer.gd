class_name GrassLayer
extends TileMapLayer
## The grass in one room: a TileMapLayer of green grass tiles (plain ground of the
## Earth rooms; the bend shadow crawls over it, Earth_bending.md §2, §11), plus little
## grass BLADES poking out of every tile with open air above it.
##
## Setup: a TileMapLayer child of a Room, named "Grass", with this script and
## resources/tiles/grass_tileset.tres. tools/build_earth_rooms.gd makes it.
##
## The blades move like springs: each has a sideways bend (px at the tip) that is
## pulled toward a TARGET bend and overshoots a little before settling. The target is
## the sum of:
##   - a slow idle sway (each blade at its own phase, so the field ripples)
##   - wind: a WindZone the blade stands in leans it along the wind's x, and makes it
##     flutter (updrafts make it flutter without leaning)
##   - the player: blades the body overlaps lean the way you run, and part around your
##     feet when you stand still
## A gust (or the dash wake) KICKS the blades' bend speed instead: they whip over and
## spring back. Gusts find the grass through the Pushable contract (pushable.gd), via
## one sensor Area2D per strip of blades, like the leaf pile does.
##
## Why not one node per blade? A room has a few hundred blades. Keeping them in a few
## packed arrays and drawing them all in one draw call is much cheaper. They're drawn
## on a child Node2D ("Blades", z_index 1) through its `draw` SIGNAL, so they appear
## in front of the player's feet and of the tiles. A signal handler can draw on the
## node that emitted `draw` by calling that node's draw_* methods.
##
## Only the current room's grass animates (GameState.current_room); the others stay
## still, which costs nothing.

## Blade colors: two greens, alternating, so a field of blades doesn't look flat.
const BLADE_COLOR: Color = Color(0.48, 0.76, 0.3)
const BLADE_DARK_COLOR: Color = Color(0.36, 0.62, 0.25)
## Blades are rooted this many px INTO the ground (Stage E4b): the ground's top edge
## is drawn with small dents now, and without roots a blade could float over one.
const BLADE_ROOT_DEPTH: float = 2.0
## The gust's sensor strip reaches this high above the tiles, px.
const SENSOR_HEIGHT: float = 8.0

@export_group("Blades")
## How many blades per grass tile with open air above it.
@export var blades_per_tile: int = 3
## Blade height range, px.
@export var blade_min_height: float = 2.0
@export var blade_max_height: float = 5.0
## Spring pulling a blade's bend toward its target (higher = snappier) and the damping
## that stops it wobbling forever (higher = less overshoot).
@export var bend_stiffness: float = 120.0
@export var bend_damping: float = 10.0
## The most a blade tip can lean sideways, px.
@export var max_bend: float = 3.5
## Idle sway: tip movement, px, and speed, radians per second.
@export var idle_sway: float = 0.4
@export var idle_sway_speed: float = 2.0

@export_group("Wind, player, gust")
## Lean per px/s of wind along x. A 60 px/s current leans blades 60 x 0.035 = 2.1 px.
@export var wind_bend_per_speed: float = 0.035
## Flutter in wind: tip wobble per px/s of wind (any direction), px, and its speed.
@export var wind_flutter_per_speed: float = 0.012
@export var wind_flutter_speed: float = 14.0
## Lean per px/s of the player's run speed, for blades the body overlaps.
## Full run speed (90 px/s) x 0.03 = 2.7 px.
@export var run_bend_per_speed: float = 0.03
## Blades under a player standing still part around the feet by this much, px.
@export var part_bend: float = 1.2
## A gust kicks blades within this distance of its origin, px...
@export var gust_reach: float = 64.0
## ...by this much bend speed (px/s) per px/s of gust strength (160 x 0.4 = 64 px/s),
## less with distance.
@export var gust_kick_per_strength: float = 0.4

## Per blade (same index in every array): base position in this layer's local
## coordinates, height, idle phase, current bend and bend speed, and the wind there.
var blade_bases: PackedVector2Array = PackedVector2Array()
var blade_heights: PackedFloat32Array = PackedFloat32Array()
var blade_phases: PackedFloat32Array = PackedFloat32Array()
var blade_bends: PackedFloat32Array = PackedFloat32Array()
var blade_bend_speeds: PackedFloat32Array = PackedFloat32Array()
var blade_winds: PackedVector2Array = PackedVector2Array()
## True once blade_winds was filled (wind zones are found on the first update, when
## every zone in the room has run its _ready).
var winds_found: bool = false
## Seconds since start, for the idle sway and wind flutter.
var sway_clock: float = 0.0
var blades_canvas: Node2D


func _ready() -> void:
	# Tells EarthLayer the shadow may cross this layer (also saved in the room file).
	add_to_group(EarthLayer.SHADOW_PASSABLE_GROUP)
	add_to_group(Pushable.GROUP)
	blades_canvas = Node2D.new()
	blades_canvas.name = "Blades"
	blades_canvas.z_index = 1  # in front of the player's feet
	add_child(blades_canvas)
	blades_canvas.draw.connect(_draw_blades)
	_generate_blades()


## One strip of blades per run of grass tiles that have open air above them.
func _generate_blades() -> void:
	var tile_size: Vector2 = Vector2(tile_set.tile_size)
	var top_cells: Array[Vector2i] = []
	for cell: Vector2i in get_used_cells():
		# Row 0 is the room's top edge: nothing grows on top of the ceiling.
		if cell.y > 0 and not _is_solid_anywhere(cell + Vector2i.UP):
			top_cells.append(cell)
	# Sorting row by row, left to right, makes each run of neighbours consecutive.
	top_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	var strip_start: Vector2i = Vector2i.ZERO
	for cell_index: int in top_cells.size():
		var cell: Vector2i = top_cells[cell_index]
		# Same seed per cell, so the field looks the same every run.
		random.seed = hash(cell)
		var tile_top_left: Vector2 = map_to_local(cell) - tile_size / 2.0
		for blade_index: int in blades_per_tile:
			# Spread evenly across the tile, jittered a little.
			var x: float = (blade_index + 0.5) * tile_size.x / blades_per_tile + random.randf_range(-0.8, 0.8)
			# + 0.5: a 1 px line drawn through a pixel's CENTER covers exactly that pixel.
			blade_bases.append(tile_top_left + Vector2(roundf(x) + 0.5, 0.0))
			blade_heights.append(roundf(random.randf_range(blade_min_height, blade_max_height)))
			blade_phases.append(random.randf_range(0.0, TAU))
			blade_bends.append(0.0)
			blade_bend_speeds.append(0.0)
			blade_winds.append(Vector2.ZERO)
		# A strip ends where the next top cell isn't the right-hand neighbour.
		var is_strip_start: bool = cell_index == 0 or top_cells[cell_index - 1] != cell + Vector2i.LEFT
		if is_strip_start:
			strip_start = cell
		var is_strip_end: bool = cell_index == top_cells.size() - 1 or top_cells[cell_index + 1] != cell + Vector2i.RIGHT
		if is_strip_end:
			_add_gust_sensor(strip_start, cell)


## True if any tile layer of this room (grass, earth, gray) has a tile at `cell`.
func _is_solid_anywhere(cell: Vector2i) -> bool:
	for sibling: Node in get_parent().get_children():
		var layer: TileMapLayer = sibling as TileMapLayer
		if layer != null and layer.get_cell_source_id(cell) != -1:
			return true
	return false


## A sensor Area2D on layer 4 ("pushable") over a strip of blades, from `first_cell`
## to `last_cell` (same row), so the gust's shape query finds the grass.
## Pushable.find_pushable() checks the touched node's parent too: that's us.
func _add_gust_sensor(first_cell: Vector2i, last_cell: Vector2i) -> void:
	var tile_size: Vector2 = Vector2(tile_set.tile_size)
	var left: float = map_to_local(first_cell).x - tile_size.x / 2.0
	var right: float = map_to_local(last_cell).x + tile_size.x / 2.0
	var top: float = map_to_local(first_cell).y - tile_size.y / 2.0
	var sensor: Area2D = Area2D.new()
	sensor.collision_layer = 8  # bit value of layer 4, "pushable"
	sensor.collision_mask = 0   # it only needs to be found, not to find
	sensor.monitoring = false
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(right - left, SENSOR_HEIGHT)
	shape_node.shape = rectangle
	shape_node.position = Vector2((left + right) / 2.0, top - SENSOR_HEIGHT / 2.0)
	sensor.add_child(shape_node)
	add_child(sensor)


func _physics_process(delta: float) -> void:
	var room: Room = get_parent() as Room
	if room != null and GameState.current_room != room:
		return  # not the room on screen: keep still
	if not winds_found:
		_find_winds()
	sway_clock += delta
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	var player_rect: Rect2 = Rect2()
	var player_speed_x: float = 0.0
	if player != null and not player.is_dead():
		# In our local coordinates, grown 1 px so blades right at the edge react too.
		player_rect = Rect2(to_local(player.get_hitbox_rect().position), player.get_hitbox_rect().size).grow(1.0)
		player_speed_x = player.velocity.x
	for blade_index: int in blade_bases.size():
		var target_bend: float = _get_target_bend(blade_index, player_rect, player_speed_x)
		var bend: float = blade_bends[blade_index]
		var bend_speed: float = blade_bend_speeds[blade_index]
		# A damped spring: accelerate toward the target, lose some speed every frame.
		bend_speed += ((target_bend - bend) * bend_stiffness - bend_speed * bend_damping) * delta
		bend = clampf(bend + bend_speed * delta, -max_bend, max_bend)
		blade_bends[blade_index] = bend
		blade_bend_speeds[blade_index] = bend_speed
	blades_canvas.queue_redraw()


## Where blade `blade_index` wants to lean right now, px (see the header).
func _get_target_bend(blade_index: int, player_rect: Rect2, player_speed_x: float) -> float:
	var phase: float = blade_phases[blade_index]
	var target_bend: float = sin(sway_clock * idle_sway_speed + phase) * idle_sway
	var wind: Vector2 = blade_winds[blade_index]
	if wind != Vector2.ZERO:
		target_bend += wind.x * wind_bend_per_speed
		target_bend += sin(sway_clock * wind_flutter_speed + phase * 3.0) * wind.length() * wind_flutter_per_speed
	var base: Vector2 = blade_bases[blade_index]
	# Does the player's body overlap the blade (from its base up to its tip)?
	if player_rect.size != Vector2.ZERO and base.x >= player_rect.position.x and base.x <= player_rect.end.x \
			and player_rect.end.y >= base.y - blade_heights[blade_index] and player_rect.position.y <= base.y:
		if absf(player_speed_x) > 5.0:
			target_bend += player_speed_x * run_bend_per_speed
		else:
			# Standing still: blades part to both sides of the feet.
			target_bend += signf(base.x - player_rect.get_center().x) * part_bend
	return target_bend


## The wind at each blade, from the WindZones in the game (they don't move).
func _find_winds() -> void:
	winds_found = true
	var zones: Array[Node] = get_tree().get_nodes_in_group(WindZone.GROUP)
	for blade_index: int in blade_bases.size():
		var blade_middle: Vector2 = to_global(blade_bases[blade_index] + Vector2(0.0, -blade_heights[blade_index] / 2.0))
		var wind: Vector2 = Vector2.ZERO
		for zone: Node in zones:
			var wind_zone: WindZone = zone as WindZone
			if wind_zone != null and wind_zone.contains_point(blade_middle):
				wind += wind_zone.get_wind_velocity()
		blade_winds[blade_index] = wind


## The Pushable contract (fallback when the gust's origin is unknown).
func receive_gust(direction: Vector2, strength: float) -> void:
	receive_gust_from(direction, strength, Pushable.NO_SOURCE)


## The Pushable contract, with the gust's origin: kicks the blades near it the way
## the air blows them (sideways only: a blade can only lean). A gust straight up or
## down, or the all-around gust, blows each blade away from the origin instead.
func receive_gust_from(direction: Vector2, strength: float, source_position: Vector2) -> void:
	var has_source: bool = source_position.is_finite()
	for blade_index: int in blade_bases.size():
		var base: Vector2 = to_global(blade_bases[blade_index])
		var falloff: float = 1.0
		var push_x: float = direction.x
		if has_source:
			var distance: float = base.distance_to(source_position)
			if distance > gust_reach:
				continue
			falloff = 1.0 - 0.6 * distance / gust_reach
			var away_x: float = signf(base.x - source_position.x)
			if absf(direction.x) < 0.3 or absf(base.x - source_position.x) < 0.5:
				push_x = away_x  # straight up/down: the air spreads out along the ground
			elif signf(push_x) != away_x and absf(base.x - source_position.x) > 8.0:
				continue  # behind an aimed gust
			# The all-around gust hands each object "away from the player" as its
			# direction; for a strip that's along its center, so use per-blade sides.
			if direction.is_equal_approx((global_position - source_position).normalized()):
				push_x = away_x
		blade_bend_speeds[blade_index] += signf(push_x) * strength * gust_kick_per_strength * falloff


## Draws every blade on the Blades child (its `draw` signal calls this): a short root
## down into the ground, then two 1 px segments, the upper one leaning more, so a bent
## blade curves.
func _draw_blades() -> void:
	for blade_index: int in blade_bases.size():
		var base: Vector2 = blade_bases[blade_index]
		var height: float = blade_heights[blade_index]
		var bend: float = blade_bends[blade_index]
		var middle: Vector2 = base + Vector2(bend * 0.35, -height * 0.55)
		var tip: Vector2 = base + Vector2(bend, -height)
		var color: Color = BLADE_COLOR if blade_index % 2 == 0 else BLADE_DARK_COLOR
		blades_canvas.draw_line(base + Vector2(0.0, BLADE_ROOT_DEPTH), base, color, 1.0)
		blades_canvas.draw_line(base, middle, color, 1.0)
		blades_canvas.draw_line(middle, tip, color, 1.0)

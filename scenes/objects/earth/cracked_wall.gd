@tool
class_name CrackedWall
extends StaticBody2D
## Cracked wall (Earth_bending.md §2, §6, Stage E6): a block of gray rock with crack
## lines. Solid like any wall until a thrown rock hits it: then it breaks open (all of
## it at once, gravel and a shake) and the rock shatters. Room reset (death or R)
## puts it back.
##
## Place the node at the wall's TOP-LEFT corner, on the tile grid, and set its size in
## tiles (wall_size_tiles). Or give it any connected shape of cells (`wall_cells`,
## tiles relative to its origin): the level editor paints walls as terrain, and its
## WallLayer makes one CrackedWall per connected group of painted cells. It's not
## part of any solid TileMapLayer, so the bend shadow and the GroundPainter treat its
## cells as open air; it draws itself (_draw). Shape code: WallShape.
##
## Breaking it opens the hidden chambers it touched (HiddenLayer), with a quake.
##
## Who breaks it: Boulder._on_impact() calls break_open() when a FLYING BIG rock (hold
## S) hits it. Nothing else does: a small rock shatters on it, and a hopping rock, a
## column or a snake head just bump into it.
##
## Physics: a StaticBody2D on layer 1 ("world"), so the player stands on it, crates
## and wisps bump into it, sentry orbs pop on it and it blocks a sentry's view, exactly
## like the gray tiles. Broken, it's on no layer at all.
##
## Contracts: Room.RESETTABLE_GROUP + reset(). The `broken` signal is for later puzzles
## (a door that opens when a wall breaks), like a switch's signal.

## Emitted once when a rock breaks it open.
signal broken

## Every cracked wall joins this group (tests, later puzzle code).
const GROUP: StringName = &"cracked_wall"
## Side of one tile, px (the rooms' grid).
const TILE_SIZE: float = 8.0
## Gray like plain solid ground (Room.SOLID_COLOR), a shade lighter so it stands out
## as "something different", with dark cracks and a darker outline.
const BODY_COLOR: Color = Color(0.33, 0.33, 0.36)
const OUTLINE_COLOR: Color = Color(0.16, 0.16, 0.18)
const CRACK_COLOR: Color = Color(0.12, 0.12, 0.14)
## Lighter chips along the cracks: catches the light, reads as broken stone.
const CHIP_COLOR: Color = Color(0.46, 0.46, 0.5)
## Gray gravel when it breaks: from the body color to the cracks' dark gray. Earth
## gravel (FX.spawn_gravel) is brown; a wall of stone should crumble gray.
const RUBBLE_COLORS: Array[Color] = [Color(0.4, 0.4, 0.44), Color(0.2, 0.2, 0.23)]
## The pebbles it leaves lying around: the wall's body, crack and chip grays.
const PEBBLE_COLORS: Array[Color] = [BODY_COLOR, BODY_COLOR, CHIP_COLOR, OUTLINE_COLOR]

## Size in tiles (width, height). 1x3 = a one-tile-wide wall three tiles high.
@export var wall_size_tiles: Vector2i = Vector2i(1, 3):
	set(value):
		wall_size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		_resize_hitbox()
		queue_redraw()
## Any shape: the wall's cells, in tiles from its origin. Empty = the
## wall_size_tiles rectangle.
@export var wall_cells: Array[Vector2i] = []:
	set(value):
		wall_cells = value
		_resize_hitbox()
		queue_redraw()

var is_broken: bool = false
## The first hitbox (one per rectangle of the shape, WallShape.make_hitboxes).
var hitbox: CollisionShape2D
var has_hitboxes: bool = false
## The cracks, made once (seeded from each rectangle's size, so the wall looks the
## same every time and in the editor): each crack is a zigzag polyline in local pixels.
var crack_lines: Array[PackedVector2Array] = []
## Light chip pixels next to the cracks.
var chip_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	collision_layer = 1  # bit value of layer 1, "world": solid like the tiles
	collision_mask = 0   # a static body never needs to detect anything
	has_hitboxes = true
	_resize_hitbox()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)


## The wall's cells, in tiles from its origin (WallShape.get_cells).
func get_cells() -> Array[Vector2i]:
	return WallShape.get_cells(wall_cells, wall_size_tiles)


## The size in pixels of the wall's bounding box (its rectangle, for a rectangle wall).
func get_size_px() -> Vector2:
	return Vector2(WallShape.get_bounds(get_cells()).end) * TILE_SIZE


## The wall's bounding box in world coordinates.
func get_global_rect() -> Rect2:
	var bounds: Rect2i = WallShape.get_bounds(get_cells())
	return Rect2(global_position + Vector2(bounds.position) * TILE_SIZE, Vector2(bounds.size) * TILE_SIZE)


## A thrown rock hit it (Boulder calls this): it breaks open, all at once.
## `hit_direction` = the way the rock was flying (unit vector): the rubble flies on
## that way. `tuning` = the thrower's EarthTuning (gravel counts, shake).
func break_open(hit_direction: Vector2, tuning: EarthTuning) -> void:
	if is_broken:
		return
	is_broken = true
	visible = false
	# Off every physics layer: the rock that hit it, the player, orbs pass through now.
	collision_layer = 0
	# Rubble from every tile, flying the way the rock was going (a wide spread, so it
	# reads as the wall bursting rather than a jet).
	var cells: Array[Vector2i] = get_cells()
	for cell: Vector2i in cells:
		var tile_center: Vector2 = to_global((Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE)
		_spawn_rubble(tile_center, tuning.cracked_wall_gravel_per_tile, hit_direction)
		# Pebbles that STAY (PebbleField, Stage E4d), in the wall's own colors, a
		# few per tile: a bigger wall leaves a bigger heap.
		PebbleField.leave_colored_pebbles(get_tree(), tile_center, tuning.cracked_wall_pebbles_per_tile,
			hit_direction, PEBBLE_COLORS)
	FX.shake(tuning.cracked_wall_shake_strength, tuning.cracked_wall_shake_time)
	FX.play_sfx(&"cracked_wall_break")
	# Hidden chambers behind it open, with a quake (after the wall is gone, so the
	# way in is already open air).
	WallShape.reveal_chambers_next_to(self, cells)
	broken.emit()


## Called by Room.reset_objects() (death or R): whole again.
func reset() -> void:
	is_broken = false
	visible = true
	collision_layer = 1


## One hitbox per rectangle of the shape, and the cracks.
func _resize_hitbox() -> void:
	if not has_hitboxes:
		return  # setter ran while the scene was loading; _ready() calls us again
	var hitboxes: Array[CollisionShape2D] = WallShape.make_hitboxes(self, WallShape.get_rectangles(get_cells()))
	hitbox = hitboxes[0] if not hitboxes.is_empty() else null
	_build_cracks()


## Gray rubble: a one-shot burst of 1-2 px squares under gravity, like FX.spawn_gravel
## but stone-colored (and no pebbles: those are earth).
func _spawn_rubble(world_position: Vector2, amount: int, direction: Vector2) -> void:
	var rubble: CPUParticles2D = CPUParticles2D.new()
	rubble.one_shot = true
	rubble.explosiveness = 1.0
	rubble.amount = maxi(amount, 1)
	rubble.lifetime = 0.6
	rubble.direction = direction if direction != Vector2.ZERO else Vector2.UP
	rubble.spread = 70.0
	rubble.gravity = Vector2(0.0, 420.0)
	rubble.initial_velocity_min = 30.0
	rubble.initial_velocity_max = 90.0
	rubble.scale_amount_min = 1.0
	rubble.scale_amount_max = 2.0
	var colors: Gradient = Gradient.new()
	colors.set_color(0, RUBBLE_COLORS[0])
	colors.set_color(1, RUBBLE_COLORS[1])
	rubble.color_initial_ramp = colors
	rubble.z_index = 5  # in front of tiles and objects, like gravel
	# Into the room (our parent), since we're hidden now.
	get_parent().add_child(rubble)
	rubble.global_position = world_position
	rubble.emitting = true
	get_tree().create_timer(rubble.lifetime + 0.1, false).timeout.connect(rubble.queue_free)


## Makes the crack pattern: one zigzag crack per tile of height, each starting on a
## random side edge and running across the wall, plus a chip pixel at each bend.
func _build_cracks() -> void:
	crack_lines.clear()
	chip_points = PackedVector2Array()
	for rectangle: Rect2i in WallShape.get_rectangles(get_cells()):
		_build_cracks_in(rectangle)


## The cracks of one rectangle of the shape (all of a rectangle wall).
func _build_cracks_in(rectangle: Rect2i) -> void:
	var size_px: Vector2 = Vector2(rectangle.size) * TILE_SIZE
	var offset: Vector2 = Vector2(rectangle.position) * TILE_SIZE
	# A seeded random generator: same size = same cracks, so it never flickers when
	# the editor redraws it.
	var crack_random: RandomNumberGenerator = RandomNumberGenerator.new()
	crack_random.seed = hash(rectangle.size)
	for row: int in rectangle.size.y:
		# Start on the left or right edge, somewhere in this tile row (not its edges).
		var from_left: bool = crack_random.randf() < 0.5
		var y: float = row * TILE_SIZE + crack_random.randi_range(2, int(TILE_SIZE) - 2)
		var x: float = 1.0 if from_left else size_px.x - 1.0
		var step_x: float = 2.0 if from_left else -2.0
		var line: PackedVector2Array = PackedVector2Array([Vector2(x, y)])
		# Zigzag 2 px across per step, wandering up or down a pixel, until it has
		# crossed about three quarters of the wall.
		var steps: int = maxi(int(size_px.x * 0.75 / 2.0), 2)
		for step: int in steps:
			x += step_x
			y = clampf(y + crack_random.randi_range(-1, 1) * 2.0, 1.0, size_px.y - 1.0)
			line.append(Vector2(x, y))
			if crack_random.randf() < 0.4:
				chip_points.append(offset + Vector2(x, y - 1.0))
		for point_index: int in line.size():
			line[point_index] += offset
		crack_lines.append(line)


func _draw() -> void:
	var cells: Array[Vector2i] = get_cells()
	for cell: Vector2i in cells:
		draw_rect(Rect2(Vector2(cell) * TILE_SIZE, Vector2.ONE * TILE_SIZE), BODY_COLOR)
	for line: PackedVector2Array in crack_lines:
		draw_polyline(line, CRACK_COLOR, 1.0)
	for chip: Vector2 in chip_points:
		draw_rect(Rect2(chip.floor(), Vector2.ONE), CHIP_COLOR)
	# The outline, 1 px inside the edge, only where the wall meets something else.
	_draw_outline(cells)


## A 1 px line just inside each side of a cell that's on the wall's edge.
func _draw_outline(cells: Array[Vector2i]) -> void:
	var cell_set: Dictionary = {}
	for cell: Vector2i in cells:
		cell_set[cell] = true
	for cell: Vector2i in cells:
		var corner: Vector2 = Vector2(cell) * TILE_SIZE
		if WallShape.is_open_side(cell_set, cell, Vector2i.UP):
			draw_rect(Rect2(corner, Vector2(TILE_SIZE, 1.0)), OUTLINE_COLOR)
		if WallShape.is_open_side(cell_set, cell, Vector2i.DOWN):
			draw_rect(Rect2(corner + Vector2(0.0, TILE_SIZE - 1.0), Vector2(TILE_SIZE, 1.0)), OUTLINE_COLOR)
		if WallShape.is_open_side(cell_set, cell, Vector2i.LEFT):
			draw_rect(Rect2(corner, Vector2(1.0, TILE_SIZE)), OUTLINE_COLOR)
		if WallShape.is_open_side(cell_set, cell, Vector2i.RIGHT):
			draw_rect(Rect2(corner + Vector2(TILE_SIZE - 1.0, 0.0), Vector2(1.0, TILE_SIZE)), OUTLINE_COLOR)

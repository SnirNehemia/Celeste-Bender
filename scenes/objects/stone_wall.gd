@tool
class_name StoneWall
extends StaticBody2D
## Stone wall (Fire_bending.md §7.2, Stage F11b): a wall of big fitted stone blocks,
## much stronger than a CrackedWall. Rocks shatter on it (a thrown big rock too),
## fire does nothing to it, columns and the snake bump into it. Only a CHARGING
## thicket elephant breaks it (ThicketElephant._smash calls break_open). Room reset
## (death or R) puts it back.
##
## Place the node at the wall's TOP-LEFT corner, on the tile grid, and set its size in
## tiles (wall_size_tiles), or give it any connected shape of cells (`wall_cells`;
## the level editor's WallLayer does, one wall per painted group). Like the cracked
## wall it's not part of any solid TileMapLayer: the bend shadow and the
## GroundPainter treat its cells as open air, and it draws itself (_draw). Shape
## code: WallShape. Breaking it opens the hidden chambers it touched, with a quake.
##
## Look: a heap of hardened boulders packed into the wall's box, like the Earth
## chapter's boulders but darker and harder: rows of rounded rocks (corners cut, a
## pixel of jitter on each corner, so no two are alike), each with a dark outline, a
## lit top-left edge and a speck or two, dark crevices between them. Seeded by its
## size, so the same wall always looks the same. The box is filled solid behind the
## rocks, so what you see is what you hit.
##
## Physics: a StaticBody2D on layer 1 ("world"), exactly like the cracked wall. Broken,
## it's on no layer at all.
##
## Contracts: Room.RESETTABLE_GROUP + reset(); the `broken` signal (for puzzles: a
## door that opens when it falls).

## Emitted once when an elephant breaks it.
signal broken

## Every stone wall joins this group (tests, later puzzle code).
const GROUP: StringName = &"stone_wall"
const TILE_SIZE: float = 8.0
## Rock sizes, px: rows are ROW_HEIGHT_MIN..MAX tall, rocks ROCK_WIDTH_MIN..MAX wide.
const ROW_HEIGHT_MIN: int = 7
const ROW_HEIGHT_MAX: int = 11
const ROCK_WIDTH_MIN: int = 7
const ROCK_WIDTH_MAX: int = 13
## How much of each rock's corners is cut off, px (what makes them round).
const CORNER_CUT: float = 2.5
## Hardened earth: darker and grayer than a pushable boulder's brown.
const CREVICE_COLOR: Color = Color(0.11, 0.09, 0.08)
const ROCK_COLOR: Color = Color(0.4, 0.33, 0.27)
const ROCK_LIGHT_COLOR: Color = Color(0.54, 0.46, 0.37)
const ROCK_OUTLINE_COLOR: Color = Color(0.2, 0.15, 0.12)
const SPECK_COLOR: Color = Color(0.27, 0.21, 0.17)
## Rubble and the pebbles it leaves: its browns.
const RUBBLE_COLORS: Array[Color] = [Color(0.48, 0.4, 0.32), Color(0.2, 0.15, 0.12)]
const PEBBLE_COLORS: Array[Color] = [ROCK_COLOR, ROCK_LIGHT_COLOR, ROCK_OUTLINE_COLOR]
## Gravel per tile and the shake when it breaks: bigger than a cracked wall's.
const RUBBLE_PER_TILE: int = 6
const PEBBLES_PER_TILE: int = 2

## Size in tiles (width, height).
@export var wall_size_tiles: Vector2i = Vector2i(2, 4):
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


func _ready() -> void:
	collision_layer = 1  # bit value of layer 1, "world": solid like the tiles
	collision_mask = 0
	has_hitboxes = true
	_resize_hitbox()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)


## The wall's cells, in tiles from its origin (WallShape.get_cells).
func get_cells() -> Array[Vector2i]:
	return WallShape.get_cells(wall_cells, wall_size_tiles)


## The size in pixels of the wall's bounding box.
func get_size_px() -> Vector2:
	return Vector2(WallShape.get_bounds(get_cells()).end) * TILE_SIZE


## The wall's bounding box in world coordinates.
func get_global_rect() -> Rect2:
	var bounds: Rect2i = WallShape.get_bounds(get_cells())
	return Rect2(global_position + Vector2(bounds.position) * TILE_SIZE, Vector2(bounds.size) * TILE_SIZE)


## A charging elephant rammed it: it bursts, all at once. `hit_direction` = the
## elephant's way (the rubble flies on that way).
func break_open(hit_direction: Vector2) -> void:
	if is_broken:
		return
	is_broken = true
	visible = false
	collision_layer = 0
	var cells: Array[Vector2i] = get_cells()
	for cell: Vector2i in cells:
		var tile_center: Vector2 = to_global((Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE)
		_spawn_rubble(tile_center, hit_direction)
		PebbleField.leave_colored_pebbles(get_tree(), tile_center, PEBBLES_PER_TILE, hit_direction, PEBBLE_COLORS)
	FX.shake(4.0, 0.3)
	FX.freeze(0.08)
	FX.play_sfx(&"stone_wall_break")
	WallShape.reveal_chambers_next_to(self, cells)
	broken.emit()


## Called by Room.reset_objects() (death or R): whole again.
func reset() -> void:
	is_broken = false
	visible = true
	collision_layer = 1


## One hitbox per rectangle of the shape.
func _resize_hitbox() -> void:
	if not has_hitboxes:
		return  # setter ran while the scene was loading; _ready() calls us again
	var hitboxes: Array[CollisionShape2D] = WallShape.make_hitboxes(self, WallShape.get_rectangles(get_cells()))
	hitbox = hitboxes[0] if not hitboxes.is_empty() else null


## Stone rubble: a one-shot burst of 1-3 px squares under gravity.
func _spawn_rubble(world_position: Vector2, direction: Vector2) -> void:
	var rubble: CPUParticles2D = CPUParticles2D.new()
	rubble.one_shot = true
	rubble.explosiveness = 1.0
	rubble.amount = RUBBLE_PER_TILE
	rubble.lifetime = 0.7
	rubble.direction = direction if direction != Vector2.ZERO else Vector2.UP
	rubble.spread = 60.0
	rubble.gravity = Vector2(0.0, 420.0)
	rubble.initial_velocity_min = 40.0
	rubble.initial_velocity_max = 120.0
	rubble.scale_amount_min = 1.0
	rubble.scale_amount_max = 3.0
	var colors: Gradient = Gradient.new()
	colors.set_color(0, RUBBLE_COLORS[0])
	colors.set_color(1, RUBBLE_COLORS[1])
	rubble.color_initial_ramp = colors
	rubble.z_index = 5
	get_parent().add_child(rubble)
	rubble.global_position = world_position
	rubble.emitting = true
	get_tree().create_timer(rubble.lifetime + 0.1, false).timeout.connect(rubble.queue_free)


func _draw() -> void:
	for rectangle: Rect2i in WallShape.get_rectangles(get_cells()):
		_draw_rocks_in(rectangle)


## The rocks of one rectangle of the shape (all of a rectangle wall).
func _draw_rocks_in(rectangle: Rect2i) -> void:
	var size_px: Vector2 = Vector2(rectangle.size) * TILE_SIZE
	var offset: Vector2 = Vector2(rectangle.position) * TILE_SIZE
	draw_rect(Rect2(offset, size_px), CREVICE_COLOR)
	# A seeded random generator: the same wall looks the same every time.
	var rock_random: RandomNumberGenerator = RandomNumberGenerator.new()
	rock_random.seed = hash(rectangle.size)
	var y: int = 0
	while y < int(size_px.y):
		var row_height: int = mini(rock_random.randi_range(ROW_HEIGHT_MIN, ROW_HEIGHT_MAX), int(size_px.y) - y)
		# A sliver too thin for a rock joins the row above it.
		if int(size_px.y) - y - row_height < ROW_HEIGHT_MIN:
			row_height = int(size_px.y) - y
		var x: int = 0
		while x < int(size_px.x):
			var rock_width: int = mini(rock_random.randi_range(ROCK_WIDTH_MIN, ROCK_WIDTH_MAX), int(size_px.x) - x)
			if int(size_px.x) - x - rock_width < ROCK_WIDTH_MIN:
				rock_width = int(size_px.x) - x
			_draw_rock(Rect2(offset.x + x, offset.y + y, rock_width, row_height), rock_random)
			x += rock_width
		y += row_height


## One rock filling `cell` (with a pixel of crevice round it): an octagon with its
## corners cut and jittered, filled, lit along the top-left, outlined, specked.
func _draw_rock(cell: Rect2, rock_random: RandomNumberGenerator) -> void:
	var box: Rect2 = cell.grow(-0.5)
	var cut: float = minf(CORNER_CUT, minf(box.size.x, box.size.y) / 3.0)
	var corners: PackedVector2Array = PackedVector2Array([
		Vector2(box.position.x + cut, box.position.y), Vector2(box.end.x - cut, box.position.y),
		Vector2(box.end.x, box.position.y + cut), Vector2(box.end.x, box.end.y - cut),
		Vector2(box.end.x - cut, box.end.y), Vector2(box.position.x + cut, box.end.y),
		Vector2(box.position.x, box.end.y - cut), Vector2(box.position.x, box.position.y + cut)])
	for corner_index: int in corners.size():
		# Whole-pixel jitter keeps the edges on the game's pixel grid.
		corners[corner_index] += Vector2(rock_random.randi_range(-1, 1), rock_random.randi_range(-1, 1)) * 0.5
	draw_colored_polygon(corners, ROCK_COLOR)
	# The lit top-left: the top edge and the upper-left cut.
	draw_polyline(PackedVector2Array([corners[6], corners[7], corners[0], corners[1]]), ROCK_LIGHT_COLOR, 1.0)
	# The shaded rest of the rim: right side and bottom.
	draw_polyline(PackedVector2Array([corners[1], corners[2], corners[3], corners[4], corners[5], corners[6]]), ROCK_OUTLINE_COLOR, 1.0)
	for speck_index: int in rock_random.randi_range(1, 2):
		var speck: Vector2 = cell.position + Vector2(rock_random.randi_range(2, maxi(int(cell.size.x) - 3, 2)),
			rock_random.randi_range(2, maxi(int(cell.size.y) - 3, 2)))
		draw_rect(Rect2(speck, Vector2.ONE), SPECK_COLOR)

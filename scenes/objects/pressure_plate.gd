@tool
class_name PressurePlate
extends Switch
## Pressure plate (GAME_DESIGN.md §6): ON while something heavy sits on it.
##
## Place the node ON the floor surface, at the CENTER of the plate (like the
## player, whose origin is at the feet). The plate is drawn as a thin top set into
## a dark housing on the floor; the top sinks and turns green while pressed.
##
## What presses it:
##   - any body in the group "heavy" (HEAVY_GROUP). Crates join it;
##   - a FALLING BLOCK (painted "FallingBlock" or falling ice) on its way down or
##     resting on it as a body (FallingBlock), and, once it has landed, the tiles it
##     became in its room's FallingBlockLayer (a landed block is no longer a body of
##     its own: FallingBlock._land hands its cells to the layer and goes).
## The player deliberately does NOT: if standing on the plate counted, a "move the
## crate onto the plate" puzzle would be pointless.
##
## Detection: an Area2D child (a thin box just above the floor) looks at physics
## layer 1 ("world"), where crates and falling blocks live. Every physics frame it
## checks the bodies overlapping it, then asks the room's falling-block layers
## directly whether one of their tiles sits on the plate (the tiles themselves, not
## the physics, so the plate stays on through the frame a block turns into tiles).
## The plate isn't solid: things stand on the floor underneath, the plate is only a
## sensor plus a drawing.
##
## Doors listen to the `switched` signal it inherits from Switch.

## The group a body must be in to press plates.
const HEAVY_GROUP: StringName = &"heavy"

## Not in the §2 color key. The moving top: tan when free, the "go" green when pressed.
const PLATE_COLOR_OFF: Color = Color(0.7, 0.56, 0.36)
const PLATE_COLOR_ON: Color = Color(0.4, 0.95, 0.5)
## The top's 1 px highlight (its upper edge catching the light) and its seams.
const PLATE_HIGHLIGHT_OFF: Color = Color(0.86, 0.74, 0.52)
const PLATE_HIGHLIGHT_ON: Color = Color(0.72, 1.0, 0.76)
const PLATE_SEAM_OFF: Color = Color(0.55, 0.42, 0.26)
const PLATE_SEAM_ON: Color = Color(0.28, 0.75, 0.38)
## The housing the top sinks into: a dark frame along the floor with a post at each
## end, so the plate reads as a separate thing set into the floor.
const HOUSING_COLOR: Color = Color(0.3, 0.24, 0.16)
const HOUSING_POST_COLOR: Color = Color(0.22, 0.17, 0.11)
## The little lamp in the middle of the top: dim amber when free, bright when
## pressed, with a faint glow along the top while pressed.
const LAMP_COLOR_OFF: Color = Color(0.45, 0.3, 0.12)
const LAMP_COLOR_ON: Color = Color(0.85, 1.0, 0.85)
const GLOW_COLOR_ON: Color = Color(0.5, 1.0, 0.6, 0.3)
## Heights, px above the floor: the housing's frame and its end posts; the moving
## top (raised when free, nearly flush when pressed) sits on the frame.
const HOUSING_HEIGHT: float = 1.0
const POST_HEIGHT: float = 2.0
const RAISED_HEIGHT: float = 2.0
const PRESSED_HEIGHT: float = 1.0
## The top is inset this far from each end (the posts are there), px.
const TOP_INSET: float = 1.0
## A seam across the top every this many px: one per tile, so its size reads in tiles.
const SEAM_SPACING: float = 8.0
## Lamp width, px.
const LAMP_WIDTH: float = 2.0
## Height of the sensor box above the floor, px. Small, so only things actually
## resting on the plate count, not things flying over it.
const SENSOR_HEIGHT: float = 4.0

## Width of the plate, px. The setter resizes the sensor when edited in the Inspector.
## The level editor places new plates 2 tiles wide (the catalog entry's
## placed_settings); 24 stays the default so plates already saved keep their size
## (Godot saves only values that differ from the default).
@export var plate_width: float = 24.0:
	set(value):
		plate_width = value
		_resize_sensor()
		queue_redraw()

var sensor: Area2D
var sensor_shape_node: CollisionShape2D


func _ready() -> void:
	sensor = Area2D.new()
	sensor.collision_layer = 0  # nothing needs to find the sensor itself
	sensor.collision_mask = 1   # bit value of layer 1, "world" (crates, falling blocks)
	sensor.monitorable = false
	sensor_shape_node = CollisionShape2D.new()
	sensor_shape_node.shape = RectangleShape2D.new()
	sensor.add_child(sensor_shape_node)
	add_child(sensor)
	_resize_sensor()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Re-checked every frame (not only on body_entered/exited) so the plate is
	# always right even after a crate is teleported back by a room reset.
	set_on(_is_pressed())  # only emits `switched` if it changed


## True if something heavy rests on the plate: a heavy body or a falling block in
## the sensor, or a landed block's tiles on it.
func _is_pressed() -> bool:
	for body: Node2D in sensor.get_overlapping_bodies():
		if body.is_in_group(HEAVY_GROUP) or body is FallingBlock:
			return true
	# Landed blocks are tiles of a FallingBlockLayer, a child of the room like the
	# plate (also a layer made at run time for a block falling in from the room
	# above: FallingBlockLayer.ensure_twin_in).
	var parent: Node = get_parent()
	if parent == null:
		return false
	for sibling: Node in parent.get_children():
		if sibling is FallingBlockLayer and _has_tiles_on_plate(sibling as FallingBlockLayer):
			return true
	return false


## True if `layer` has a tile right on the plate: the row just above the floor,
## sampled once per tile across the plate, inside its ends like the sensor.
func _has_tiles_on_plate(layer: FallingBlockLayer) -> bool:
	if layer.get_used_cells().is_empty():
		return false
	# Half the sensor's height above the floor: inside the tile row resting on the
	# floor, never in the floor itself (which may be painted falling block too).
	var sample_y: float = -SENSOR_HEIGHT / 2.0
	var left: float = -plate_width / 2.0 + 1.0
	var right: float = plate_width / 2.0 - 1.0
	var tile_width: float = float(layer.tile_set.tile_size.x)
	var x: float = left
	while true:
		var cell: Vector2i = layer.local_to_map(layer.to_local(to_global(Vector2(x, sample_y))))
		if layer.get_cell_source_id(cell) != -1:
			return true
		if x >= right:
			break
		x = minf(x + tile_width, right)  # the last sample lands exactly on the right end
	return false


## The sensor box: the plate's width (1 px in from each end, so a crate merely
## touching the plate's edge doesn't count) and SENSOR_HEIGHT tall, sitting on the floor.
func _resize_sensor() -> void:
	if sensor_shape_node == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(sensor_shape_node.shape as RectangleShape2D).size = Vector2(plate_width - 2.0, SENSOR_HEIGHT)
	# CollisionShape2D is positioned by its center; y is negative = above the floor.
	sensor_shape_node.position = Vector2(0.0, -SENSOR_HEIGHT / 2.0)


## Drawn bottom up (y is negative above the floor): the housing frame and its two
## end posts, the moving top on the frame with a highlight along its upper edge and
## a seam per tile, the lamp in the middle, and a faint glow over it when pressed.
func _draw() -> void:
	var pressed: bool = is_on()
	var half_width: float = plate_width / 2.0
	# Housing: the frame along the floor and a post at each end.
	draw_rect(Rect2(-half_width, -HOUSING_HEIGHT, plate_width, HOUSING_HEIGHT), HOUSING_COLOR)
	draw_rect(Rect2(-half_width, -POST_HEIGHT, TOP_INSET, POST_HEIGHT), HOUSING_POST_COLOR)
	draw_rect(Rect2(half_width - TOP_INSET, -POST_HEIGHT, TOP_INSET, POST_HEIGHT), HOUSING_POST_COLOR)
	# The moving top, sitting on the frame.
	var top_height: float = PRESSED_HEIGHT if pressed else RAISED_HEIGHT
	var top_left: float = -half_width + TOP_INSET
	var top_width: float = maxf(plate_width - 2.0 * TOP_INSET, 1.0)
	var top_y: float = -HOUSING_HEIGHT - top_height
	draw_rect(Rect2(top_left, top_y, top_width, top_height), PLATE_COLOR_ON if pressed else PLATE_COLOR_OFF)
	draw_rect(Rect2(top_left, top_y, top_width, 1.0), PLATE_HIGHLIGHT_ON if pressed else PLATE_HIGHLIGHT_OFF)
	# Seams one tile apart, counted from the plate's left end (so a plate on the grid
	# has them on the tile lines), under the highlight row. Pressed, the top is one
	# row (all highlight) and shows none.
	if top_height > 1.0:
		var seam_x: float = -half_width + SEAM_SPACING
		while seam_x < half_width - TOP_INSET:
			draw_rect(Rect2(seam_x, top_y + 1.0, 1.0, top_height - 1.0), PLATE_SEAM_ON if pressed else PLATE_SEAM_OFF)
			seam_x += SEAM_SPACING
	# The lamp, in the middle of the top's upper edge.
	draw_rect(Rect2(-LAMP_WIDTH / 2.0, top_y, LAMP_WIDTH, 1.0), LAMP_COLOR_ON if pressed else LAMP_COLOR_OFF)
	if pressed:
		draw_rect(Rect2(top_left, top_y - 1.0, top_width, 1.0), GLOW_COLOR_ON)

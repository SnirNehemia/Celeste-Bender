@tool
class_name MetalPlatform
extends StaticBody2D
## Metal platform: a fixed ONE-WAY platform, a riveted steel girder. You can jump up
## through it from below and land on top, but you can't drop down through it (there
## is no drop-through move: Down only fast-falls), so once you're on it, it's floor.
##
## Unlike the leaf and sail platforms it never moves, burns or floats: it's level
## structure, placed from the editor's Basics tab (PaletteCatalog "metal_platform").
##
## Place the node at the CENTER of its top surface (where your feet go), like the
## leaf platform; `platform_width` grows it to both sides.
##
## One-way: CollisionShape2D.one_way_collision makes the shape solid only against
## bodies coming down onto it from above (its local "up"); a body moving up passes
## through. Why StaticBody2D? It's Godot's body for solids that never move: the
## physics engine skips it until something touches it.
##
## Drawn with _draw() (a Node2D's custom drawing; @tool runs it in the Godot editor
## too, so the level editor and the scene view show the real look).

## Drawn like a sliver of the gray ground (GroundPainter's GRAY palette: crust,
## rim, edge line, hatched inside), so it reads as level terrain, not an object.
## Only rivets and the bolted brackets say "metal".
const PALETTE: Array = GroundPainter.PALETTE[GroundPainter.Kind.GRAY]
## Thickness of the solid top surface, px (the same as the leaf's).
const SURFACE_THICKNESS: float = 4.0
## Height of the drawn girder, px: the solid top plus a lip underneath.
const DRAWN_HEIGHT: float = 6.0
## One rivet every this many px along the plate.
const RIVET_SPACING: float = 8.0
## The support brackets under each end: px wide and px tall.
const BRACKET_SIZE: Vector2 = Vector2(3.0, 3.0)

## Width of the platform, px.
@export var platform_width: float = 32.0:
	set(value):
		platform_width = maxf(value, 8.0)
		_resize_surface()
		queue_redraw()

var surface: CollisionShape2D


func _ready() -> void:
	collision_layer = 1  # layer 1 "world": the player stands on it
	collision_mask = 0   # it never moves, so it doesn't need to detect anything
	surface = CollisionShape2D.new()
	surface.shape = RectangleShape2D.new()
	surface.one_way_collision = true  # solid only from above
	add_child(surface)
	_resize_surface()


## Keeps the solid top as wide as the platform, its top edge on the node's origin.
func _resize_surface() -> void:
	if surface == null:
		return
	(surface.shape as RectangleShape2D).size = Vector2(platform_width, SURFACE_THICKNESS)
	surface.position = Vector2(0.0, SURFACE_THICKNESS / 2.0)


func _draw() -> void:
	var crust_color: Color = PALETTE[0]
	var rim_color: Color = PALETTE[1]
	var edge_color: Color = PALETTE[2]
	var inside_color: Color = PALETTE[3]
	var hatch_color: Color = PALETTE[4]
	var left: float = -platform_width / 2.0
	# The inside, with the ground's diagonal hatch: one 1 px step per row, so each
	# stripe leans like GroundPainter's (HATCH_WIDTH px every HATCH_PERIOD px).
	draw_rect(Rect2(left, 0.0, platform_width, DRAWN_HEIGHT), inside_color)
	for row: int in int(DRAWN_HEIGHT):
		for x: int in int(platform_width):
			if posmod(x + row, GroundPainter.HATCH_PERIOD) < GroundPainter.HATCH_WIDTH:
				draw_rect(Rect2(left + x, row, 1.0, 1.0), hatch_color)
	# The crust round it (1 px), the dark edge line just inside, the rim on top.
	draw_rect(Rect2(left, 0.0, platform_width, DRAWN_HEIGHT), crust_color, false, 1.0)
	draw_rect(Rect2(left + 1.0, DRAWN_HEIGHT - 2.0, platform_width - 2.0, 1.0), edge_color)
	draw_rect(Rect2(left, 0.0, platform_width, 1.0), rim_color)
	# Rivets along the middle, spaced evenly and centered so both ends match.
	var rivet_count: int = maxi(1, floori(platform_width / RIVET_SPACING))
	var spacing: float = platform_width / rivet_count
	for rivet_index: int in rivet_count:
		draw_rect(Rect2(left + spacing * (rivet_index + 0.5) - 0.5, 2.0, 1.0, 1.0), crust_color)
	# Small brackets under both ends, as if bolted to the wall or a post.
	draw_rect(Rect2(Vector2(left + 1.0, DRAWN_HEIGHT), BRACKET_SIZE), edge_color)
	draw_rect(Rect2(Vector2(-left - 1.0 - BRACKET_SIZE.x, DRAWN_HEIGHT), BRACKET_SIZE), edge_color)

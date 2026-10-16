extends Node2D
## Test room for player movement (Stage 1+). One screen: 320x180.
##
## Builds its solid blocks from the list below when the scene starts, so you can
## add or move platforms by editing numbers. Each Rect2 is (x, y, width, height)
## in pixels. Reference numbers: a full-hold jump rises ~27 px; a tap ~6 px.
##
## Areas (Stage 2):
##   - Left: a 32 px wide shaft for climbing with wall jumps. Walk into it under
##     the gap at the bottom of its right wall; climb out at the top-left.
##   - Middle: a low ceiling slab. Jump while your head overlaps its edge by
##     1-4 px and corner correction slides you around it.
##   - Right: a step, a platform and a high ledge for jump-height practice.
## The scene also contains a DebugOverlay (F1 to toggle).

## Ground color from GAME_DESIGN.md §2 (dark gray).
const SOLID_COLOR: Color = Color(0.25, 0.25, 0.28)

## Solid blocks.
var solid_rects: Array[Rect2] = [
	Rect2(0, 160, 320, 20),   # floor (top at y=160)
	Rect2(-8, 0, 8, 180),     # left room wall (also the shaft's left wall)
	Rect2(320, 0, 8, 180),    # right room wall
	# Wall-jump shaft: right wall from y=40 to y=144, leaving a 16 px gap at the
	# bottom to walk in (player is 11 px tall). Inner width 32 px.
	Rect2(32, 40, 8, 104),
	Rect2(40, 40, 56, 8),     # top-of-shaft exit platform
	# Corner-correction slab: bottom at y=128. Standing on the floor your head is at
	# y=149 and a full jump takes it to ~y=122, so a head-on jump bonks.
	Rect2(128, 120, 48, 8),
	# Jump practice on the right.
	Rect2(200, 144, 32, 16),  # step, 16 px up
	Rect2(248, 128, 32, 8),   # platform, 16 px higher, 16 px gap
	Rect2(288, 104, 32, 8),   # ledge on the right wall, 24 px higher (needs a near-full jump)
]


func _ready() -> void:
	for rect: Rect2 in solid_rects:
		_add_solid_block(rect)


## Creates a StaticBody2D (an immovable solid) with a collision shape and a gray rectangle.
func _add_solid_block(rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.position

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	# CollisionShape2D is positioned by its CENTER, so offset by half the size.
	shape.position = rect.size / 2.0
	body.add_child(shape)

	var visual: ColorRect = ColorRect.new()
	visual.size = rect.size
	visual.color = SOLID_COLOR
	body.add_child(visual)

	add_child(body)

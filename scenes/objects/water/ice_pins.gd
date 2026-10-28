@tool
class_name IcePins
extends Spikes
## IcePins (Stage W6, Water_bending.md §16 "Planned in Stage W6", the developer's
## idea): a bed of tall thin needles on a floor. Like spikes they KILL the player
## (the same fairness: a hitbox smaller than drawn, no kill while moving up), so you
## can't walk across a pin bed. Unlike spikes they CATCH ICE:
##   - free ice (an IceBlock: a frozen ball, a frozen ribbon) that touches a pin tip
##     is IMPALED: it stops dead and stays there, at the angle it had (free ice never
##     turns). A frozen ball becomes a fixed step over the pins, a frozen ribbon a
##     fixed slide. IceBlock does the catching (see its _physics_process).
##   - the held water snake's rope DRAPES over the tips (WaterSnake looks for this
##     layer as well as rock), so you can lay a snake along the bed as a slope and
##     freeze it there: a slide resting on the pins.
##   - loose water falls THROUGH the pins (they're too thin to hold it): pins aren't
##     tiles or a water_solid, so a pin bed never fills up.
##
## Extends Spikes (scenes/objects/spikes.gd): placement (top-left of the cell,
## `tile_count` tiles long), the kill check and the Area2D on layer 3 "hazards" are
## the spikes'. Only floor pins exist (tips up, whatever `facing` says). _rebuild()
## makes the needles, the deadly rectangle, and a thin static body along the tips on
## physics layer 7 "ice_catch" (CATCH_LAYER_BIT), which only ice and the snake's rope
## look at: the player, crates and enemies pass into the pins.

## The physics layer the tips are on: layer 7 "ice_catch" (bit value 64).
const CATCH_LAYER_BIT: int = 64
## The tips' body joins this group: what IceBlock looks for in its collisions.
const GROUP: StringName = &"ice_pins"
## Needles per 8 px tile, their height and base width, px.
const NEEDLES_PER_TILE: int = 2
const NEEDLE_HEIGHT: float = 7.0
const NEEDLE_BASE_WIDTH: float = 2.0
## The deadly part, measured from the floor (smaller than the needles, as spikes).
const PIN_HITBOX_HEIGHT: float = 5.0
## How thick the catching strip along the tips is, px: its top is the tips. 4 px, not
## 1, so a snake's rope point sagging a few px in one step can't skip through it.
const CATCH_THICKNESS: float = 4.0
## Placeholder colors (GAME_DESIGN.md §2: hazards are red): pale steel needles with
## red tips, so they read as "ice-blue metal, but deadly".
const NEEDLE_COLOR: Color = Color("#B8C4D0")
const TIP_COLOR: Color = Color(0.9, 0.2, 0.2)


## Tips always point up (only floor pins exist).
func get_tip_direction() -> Vector2:
	return Vector2.UP


func _rebuild() -> void:
	# Only floor pins exist: whatever sets `facing` (the editor's auto-facing, R),
	# they stay pointing up. (Setting it runs its setter, which calls this again.)
	if facing != Facing.UP:
		facing = Facing.UP
		return
	if not is_inside_tree():
		return  # setters also run while the scene loads; _ready() rebuilds after that
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var strip_length: float = tile_count * TILE_SIZE
	# The needles: thin triangles standing on the bottom edge of the cell, each with
	# a red tip (the top third).
	var needle_count: int = tile_count * NEEDLES_PER_TILE
	var spacing: float = TILE_SIZE / NEEDLES_PER_TILE
	for needle_index: int in needle_count:
		var middle_x: float = (needle_index + 0.5) * spacing
		var needle: Polygon2D = Polygon2D.new()
		needle.color = NEEDLE_COLOR
		needle.polygon = PackedVector2Array([
			Vector2(middle_x - NEEDLE_BASE_WIDTH / 2.0, TILE_SIZE),
			Vector2(middle_x + NEEDLE_BASE_WIDTH / 2.0, TILE_SIZE),
			Vector2(middle_x, TILE_SIZE - NEEDLE_HEIGHT),
		])
		add_child(needle)
		var tip: Line2D = Line2D.new()
		tip.default_color = TIP_COLOR
		tip.width = 1.0
		tip.points = PackedVector2Array([Vector2(middle_x, TILE_SIZE - NEEDLE_HEIGHT),
			Vector2(middle_x, TILE_SIZE - NEEDLE_HEIGHT + 2.5)])
		add_child(tip)

	# The deadly rectangle (Spikes' kill check reads hitbox_local_rect).
	hitbox_local_rect = Rect2(HITBOX_END_INSET, TILE_SIZE - PIN_HITBOX_HEIGHT,
		strip_length - 2.0 * HITBOX_END_INSET, PIN_HITBOX_HEIGHT)
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = hitbox_local_rect.size
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = rectangle
	hitbox.position = hitbox_local_rect.get_center()
	add_child(hitbox)

	# The catching strip along the tips: a static body only ice looks at.
	var catcher: StaticBody2D = StaticBody2D.new()
	catcher.name = "Tips"
	catcher.collision_layer = CATCH_LAYER_BIT
	catcher.collision_mask = 0
	catcher.add_to_group(GROUP)
	var catch_shape: CollisionShape2D = CollisionShape2D.new()
	var catch_rectangle: RectangleShape2D = RectangleShape2D.new()
	catch_rectangle.size = Vector2(strip_length, CATCH_THICKNESS)
	catch_shape.shape = catch_rectangle
	catch_shape.position = Vector2(strip_length / 2.0, TILE_SIZE - NEEDLE_HEIGHT + CATCH_THICKNESS / 2.0)
	catcher.add_child(catch_shape)
	add_child(catcher)

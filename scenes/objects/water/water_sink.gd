@tool
class_name WaterSink
extends Node2D
## WaterSink (Stage W2, Water_bending.md §6.2): a drain grate. Every physics frame
## it asks its room's WaterWorld to take the water inside its rectangle (top-left at
## this node, `sink_size` px): every particle in it, and the water of any pool
## standing above its bottom edge, up to `max_rate` units a second. On a pool's
## floor it empties the pool; on a pool's side it's an OVERFLOW (the level can't
## rise past its bottom edge). The water counts as "drained" in the books.
##
## Placed in the editor (palette: Objects tab, "Drain"). Only the room on screen
## drains. @tool: drawn in the Godot editor too.

const GRATE_COLOR: Color = Color("#2B2F36")
const BAR_COLOR: Color = Color("#6E7680")

## The drain's rectangle, px, from this node's position (its top-left corner).
@export var sink_size: Vector2 = Vector2(8, 8):
	set(value):
		sink_size = value
		queue_redraw()
## Most water it takes a second, units.
@export_range(0.0, 50.0) var max_rate: float = 8.0

var world: WaterWorld
## Water taken in all, units (tests read it).
var drained_units: float = 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if world == null:
		world = WaterWorld.find_at(get_tree(), global_position)
		if world == null:
			return
	if GameState.current_room != world.room:
		return
	var rect: Rect2 = Rect2(world.to_local(global_position), sink_size)
	drained_units += world.drain(rect, max_rate * WaterWorld.UNIT_AREA * delta) / WaterWorld.UNIT_AREA


func _draw() -> void:
	# A dark grate with light bars across it.
	draw_rect(Rect2(Vector2.ZERO, sink_size), GRATE_COLOR)
	var bar_x: float = 1.0
	while bar_x < sink_size.x:
		draw_rect(Rect2(bar_x, 0.0, 1.0, sink_size.y), BAR_COLOR)
		bar_x += 3.0

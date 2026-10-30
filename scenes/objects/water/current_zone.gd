@tool
class_name CurrentZone
extends Node2D
## CurrentZone (Stage W7b, Water_bending.md §16 "Planned in Stage W7b"): a rectangle
## that makes the WATER inside it move sideways. It pushes nothing itself: the room's
## WaterWorld reads every zone each physics frame (WaterWorld._apply_currents) and
## moves its water, and everything that rides water (swimmers, crates, rafts,
## floating leaves, a leaf platform on a rail through a pool) reads the water's own
## speed (WaterWorld.get_water_velocity_at). One physics for waves and currents.
##
## Two modes:
##   - FLOW: real flow. The pipes of the water inside the zone are driven toward
##     `strength` px/s (WaterBody's pipe model), so water really moves: in a closed
##     pool it piles up downstream until the tilted surface pushes back as hard as
##     the zone (accepted as real). A stream is a WaterSource upstream plus a
##     WaterSink (or a spill) downstream; the zone just speeds it up.
##   - LOOP: a closed loop (the developer's "turbulence"): the surface runs the
##     zone's way and the bottom runs back, speed changing evenly with depth
##     (+strength at the surface, 0 halfway down, -strength at the floor). It moves
##     no water (the average is zero), so the pool stays level. The height field
##     keeps one depth per column, so the loop isn't stored anywhere: it's worked
##     out from the zone whenever something asks for the water's speed.
##
## The node's position is the zone's TOP-LEFT corner (like WindZone), `zone_size`
## its size. Only the left/right part of `current_direction` counts (water in a
## height field only flows sideways); straight up or down counts as right.
##
## Placed in the editor (palette: Objects tab, "Current"). It draws nothing in game:
## the water itself shows the current (faint streaks in water.gdshader). @tool: in
## the Godot editor it draws a translucent box with arrows.

## Every zone joins this group; each WaterWorld takes the ones in its room.
const GROUP: StringName = &"current_zones"
## A loop fades in over this many px at its two ends (no sudden jump in speed).
const LOOP_EDGE_FADE: float = 8.0
## Editor look: translucent water blue, and lighter arrows.
const EDITOR_FILL_COLOR: Color = Color(0.18, 0.5, 0.82, 0.18)
const EDITOR_ARROW_COLOR: Color = Color(0.75, 0.89, 1.0, 0.8)

enum Mode {
	FLOW,  ## real flow: moves water (a stream; a closed pool tilts)
	LOOP,  ## surface one way, bottom the other: moves no water
}

## Size of the zone, px.
@export var zone_size: Vector2 = Vector2(64, 32):
	set(value):
		zone_size = value
		queue_redraw()
## Which way the water runs (only left or right counts, see the header).
@export var current_direction: Vector2 = Vector2.RIGHT:
	set(value):
		current_direction = value
		queue_redraw()
## How fast the water is driven, px/s (FLOW), or the surface speed (LOOP).
@export_range(0.0, 200.0) var strength: float = 40.0
@export var mode: Mode = Mode.FLOW:
	set(value):
		mode = value
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


## +1 (right) or -1 (left).
func get_sign() -> float:
	return -1.0 if current_direction.x < 0.0 else 1.0


## The zone in the coordinates of `node` (a WaterWorld: the room's coordinates).
func get_rect_in(node: Node2D) -> Rect2:
	return Rect2(node.to_local(global_position), zone_size)


## LOOP: the water's speed at a point `depth_share` of the way from the surface (0)
## to the floor (1), at `x` (room px, `rect` = get_rect_in(world)), px/s. Fades to
## zero over LOOP_EDGE_FADE px at the zone's ends.
func get_loop_speed(rect: Rect2, x: float, depth_share: float) -> float:
	var fade: float = clampf(minf(x - rect.position.x, rect.end.x - x) / LOOP_EDGE_FADE, 0.0, 1.0)
	return get_sign() * strength * (1.0 - 2.0 * clampf(depth_share, 0.0, 1.0)) * fade


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, zone_size), EDITOR_FILL_COLOR)
	# One arrow per row of 16 px: LOOP draws the bottom row backwards.
	var rows: int = maxi(1, int(zone_size.y / 16.0))
	for row: int in rows:
		var y: float = (row + 0.5) * zone_size.y / rows
		var direction: float = get_sign()
		if mode == Mode.LOOP and y > zone_size.y * 0.5:
			direction = -direction
		var tip: Vector2 = Vector2(zone_size.x * 0.5 + direction * 6.0, y)
		draw_line(tip - Vector2(direction * 12.0, 0.0), tip, EDITOR_ARROW_COLOR)
		draw_line(tip, tip + Vector2(-direction * 3.0, -3.0), EDITOR_ARROW_COLOR)
		draw_line(tip, tip + Vector2(-direction * 3.0, 3.0), EDITOR_ARROW_COLOR)

class_name RoomEdgeRim
extends Node2D
## RoomEdgeRim: a thin crust drawn just OUTSIDE a room, along its solid tiles that
## touch the room's edge, wherever no room of the same depth continues past it
## (after the D play-test, Level_editor.md §5a). Display only: no collision.
##
## Why: the GroundPainter treats everything past a room's edge as solid ground,
## so walls that run into the edge end in a straight cut there. Inside a level you
## never see that cut (the camera stays in rooms, and a neighbour room carries the
## ground on). But a room seen from ANOTHER depth (the hazed layer behind, the
## editor's previews) shows it bare: a block with a ruler-straight side. The rim
## gives those sides the same look as every other surface: a dark edge line, the
## crust, and on top a light rim (GroundPainter.PALETTE), with a 1 px wobble.
##
## Made by Room._ready() for every room. Drawn once; the level editor redraws it
## after its changes (RoomLook.refresh and LevelEditor's refresh after each edit).

## Crust thickness outside the edge, px (the wobble takes 1 off here and there).
const CRUST_THICKNESS: int = 3

var room: Room = null


func _ready() -> void:
	room = get_parent() as Room
	# Behind the room's own drawings would hide nothing (it's outside them), but in
	# front of the neighbours' backgrounds.
	queue_redraw.call_deferred()  # once every room of the level is in place


func _draw() -> void:
	if room == null:
		return
	var solid: Dictionary = _get_solid_cells()
	var painter: GroundPainter = room.get_node_or_null(^"GroundPainter") as GroundPainter
	var tile: int = 8
	var cells: Vector2i = Vector2i((room.room_size / tile).ceil())
	for cell: Vector2i in solid:
		var colors: Array = _palette_for(painter, cell)
		var cell_rect: Rect2 = Rect2(Vector2(cell * tile), Vector2.ONE * tile)
		if cell.x == 0:
			_draw_side(cell_rect, Vector2i.LEFT, colors)
		if cell.x == cells.x - 1:
			_draw_side(cell_rect, Vector2i.RIGHT, colors)
		if cell.y == 0:
			_draw_side(cell_rect, Vector2i.UP, colors)
		if cell.y == cells.y - 1:
			_draw_side(cell_rect, Vector2i.DOWN, colors)


## One side of an edge cell: if nothing of this depth continues past it, a strip
## going `outward`: the edge line next to the room, the crust, and on top surfaces
## the light rim.
func _draw_side(cell_rect: Rect2, outward: Vector2i, colors: Array) -> void:
	var probe: Vector2 = room.global_position + cell_rect.get_center() + Vector2(outward) * cell_rect.size.x
	if _is_inside_neighbour(probe):
		return
	var is_vertical_side: bool = outward.x != 0
	for along: int in int(cell_rect.size.x):
		# The wobble: a fixed hash of the world pixel, so it's the same every run.
		var world: Vector2i = Vector2i(room.global_position + cell_rect.position) + (Vector2i(0, along) if is_vertical_side else Vector2i(along, 0))
		var thickness: int = CRUST_THICKNESS - (1 if (world.x * 7 + world.y * 13) % 5 == 0 else 0)
		for step: int in thickness + 1:
			var color: Color = colors[2] if step == 0 else colors[0]
			if outward == Vector2i.UP and step == thickness:
				color = colors[1]  # a top surface: the light rim
			var pixel: Vector2 = _strip_pixel(cell_rect, outward, along, step)
			draw_rect(Rect2(pixel, Vector2.ONE), color)


## The pixel `step` px out from the cell's `outward` side, `along` px along it.
static func _strip_pixel(cell_rect: Rect2, outward: Vector2i, along: int, step: int) -> Vector2:
	match outward:
		Vector2i.LEFT:
			return Vector2(cell_rect.position.x - 1 - step, cell_rect.position.y + along)
		Vector2i.RIGHT:
			return Vector2(cell_rect.end.x + step, cell_rect.position.y + along)
		Vector2i.UP:
			return Vector2(cell_rect.position.x + along, cell_rect.position.y - 1 - step)
	return Vector2(cell_rect.position.x + along, cell_rect.end.y + step)


## True if `world_point` is inside another room of the same depth (the ground
## carries on there).
func _is_inside_neighbour(world_point: Vector2) -> bool:
	var level: Node = room.get_parent()
	if level == null:
		return false
	for child: Node in level.get_children():
		var other: Room = child as Room
		if other != null and other != room and other.get_bounds().has_point(world_point):
			return true
	return false


## Every solid cell of the room's colliding tile layers (like MapView.is_solid_at),
## as a set {cell: true}.
func _get_solid_cells() -> Dictionary:
	var solid: Dictionary = {}
	for child: Node in room.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer == null or layer.tile_set == null or not layer.collision_enabled or layer.tile_set.get_physics_layers_count() == 0:
			continue
		for cell: Vector2i in layer.get_used_cells():
			solid[cell] = true
	return solid


## The painter's colors for `cell` (crust, rim, edge line), gray without a painter.
static func _palette_for(painter: GroundPainter, cell: Vector2i) -> Array:
	var kind: int = GroundPainter.Kind.GRAY
	if painter != null and painter.kinds.has(cell):
		kind = painter.kinds[cell]
	return GroundPainter.PALETTE.get(kind, GroundPainter.PALETTE[GroundPainter.Kind.GRAY])

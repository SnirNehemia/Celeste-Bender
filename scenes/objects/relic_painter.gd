class_name RelicPainter
extends RefCounted
## RelicPainter: draws a level's RELIC, a round medallion broken into four quarters
## (Collectibles.md §2), and its single quarters. A RelicShard draws its own quarter
## with it, and the pause menu's RelicView draws the whole relic with the quarters
## found so far, so a shard really looks like a piece of the thing it completes.
##
## The quarters, by slot (clockwise from the top left, like reading a clock face):
##     1 | 2
##     --+--
##     4 | 3
## The cracks between them are ZIGZAGS, the same for both neighbours (the points of
## each crack depend only on which crack it is), so the pieces fit together.
##
## Static functions only; each takes the CanvasItem to draw on (a Node2D's or a
## Control's _draw()).

## Light color of each element (RelicShard.Element order: Air, Earth, Fire, Water).
const ELEMENT_COLORS: Array[Color] = [Color(0.72, 0.92, 1.0), Color(0.92, 0.7, 0.38),
	Color(1.0, 0.5, 0.25), Color(0.4, 0.66, 1.0)]
const OUTLINE_COLOR: Color = Color("1a1424")
## A missing quarter: a dark silhouette with a faint edge.
const EMPTY_FILL: Color = Color(0.1, 0.1, 0.14, 0.8)
const EMPTY_EDGE: Color = Color(0.45, 0.45, 0.55, 0.6)
## The engraved ring inside the medallion, as a share of its radius.
const RING_FRACTION: float = 0.58
## Points along each quarter's arc.
const ARC_POINTS: int = 6
## The crack's zigzag: points at these shares of the radius, pushed this many px
## sideways (alternating), times the radius / 11 so a big relic cracks the same way.
## (Shallow on purpose: at shard size a deep zigzag turned the quarter into a blob.)
const CRACK_STEPS: Array[float] = [0.4, 0.75]
const CRACK_JAG: float = 0.8
## The gem in the middle of a complete relic.
const GEM_COLOR: Color = Color(1.0, 0.95, 0.75)


## The angle (radians, 0 = right, clockwise in screen space) where quarter `slot`
## (1..4) starts; it spans a quarter turn from there.
static func get_start_angle(slot: int) -> float:
	# Slot 1 (top left) starts pointing left (PI) and turns clockwise to up.
	return PI + (slot - 1) * PI / 2.0


## The outline of quarter `slot` of a relic of `radius` centered at `center`.
static func get_quarter_polygon(slot: int, center: Vector2, radius: float) -> PackedVector2Array:
	var start_angle: float = get_start_angle(slot)
	var end_angle: float = start_angle + PI / 2.0
	var points: PackedVector2Array = PackedVector2Array()
	# Out from the middle along the crack at start_angle...
	points.append(center)
	points.append_array(_get_crack(slot - 1, center, radius, false))
	# ...round the rim...
	for index: int in ARC_POINTS + 1:
		var angle: float = lerpf(start_angle, end_angle, float(index) / ARC_POINTS)
		points.append(center + Vector2.from_angle(angle) * radius)
	# ...and back in along the crack at end_angle.
	points.append_array(_get_crack(slot % 4, center, radius, true))
	return points


## Crack `crack_index` (0..3: left, up, right, down from the middle), its inner
## points from the middle outward (or inward when `reversed`).
static func _get_crack(crack_index: int, center: Vector2, radius: float, reversed: bool) -> PackedVector2Array:
	var direction: Vector2 = Vector2.from_angle(PI + crack_index * PI / 2.0)
	var side: Vector2 = direction.orthogonal()
	var flip: float = 1.0 if crack_index % 2 == 0 else -1.0
	var points: PackedVector2Array = PackedVector2Array()
	for step_index: int in CRACK_STEPS.size():
		var jag: float = CRACK_JAG * radius / 11.0 * (1.0 if step_index % 2 == 0 else -1.0) * flip
		points.append(center + direction * radius * CRACK_STEPS[step_index] + side * jag)
	if reversed:
		points.reverse()
	return points


## The middle of quarter `slot`'s bounding box, relative to the relic's center: a
## shard draws its quarter shifted back by this, so the piece sits on its origin.
static func get_quarter_offset(slot: int, radius: float) -> Vector2:
	var middle_angle: float = get_start_angle(slot) + PI / 4.0
	return Vector2(signf(cos(middle_angle)), signf(sin(middle_angle))) * radius / 2.0


## Draws quarter `slot` filled with `element`'s color: outline, fill, engraved ring,
## and a lighter rim on its upper edge. `alpha` fades all of it (a ghost shard).
static func draw_quarter(item: CanvasItem, slot: int, element: int, center: Vector2,
		radius: float, alpha: float = 1.0) -> void:
	var light: Color = ELEMENT_COLORS[clampi(element, 0, ELEMENT_COLORS.size() - 1)]
	var shape: PackedVector2Array = get_quarter_polygon(slot, center, radius)
	_draw_outlined(item, shape, Color(light.darkened(0.2), alpha), alpha)
	# The engraved ring: a darker arc across the quarter.
	var start_angle: float = get_start_angle(slot)
	item.draw_arc(center, radius * RING_FRACTION, start_angle + 0.12, start_angle + PI / 2.0 - 0.12,
		ARC_POINTS, Color(light.darkened(0.5), alpha), 1.0)
	# Light catching the rim on the top quarters' outer edge.
	if slot == 1 or slot == 2:
		item.draw_arc(center, radius - 1.0, start_angle + 0.15, start_angle + PI / 2.0 - 0.15,
			ARC_POINTS, Color(light.lightened(0.45), alpha), 1.0)


## Draws an EMPTY quarter: where a shard not found yet will go.
static func draw_empty_quarter(item: CanvasItem, slot: int, center: Vector2, radius: float) -> void:
	var shape: PackedVector2Array = get_quarter_polygon(slot, center, radius)
	item.draw_colored_polygon(shape, EMPTY_FILL)
	var closed: PackedVector2Array = shape.duplicate()
	closed.append(shape[0])
	item.draw_polyline(closed, EMPTY_EDGE, 1.0)


## The whole relic of `element`: `found_slots` are the quarters found (1..4), the
## rest are drawn empty. Complete, it gets a gem in the middle.
static func draw_relic(item: CanvasItem, element: int, found_slots: Array, center: Vector2, radius: float) -> void:
	for slot: int in range(1, 5):
		if found_slots.has(slot):
			draw_quarter(item, slot, element, center, radius)
		else:
			draw_empty_quarter(item, slot, center, radius)
	if found_slots.size() >= 4:
		item.draw_circle(center, radius * 0.18 + 1.0, OUTLINE_COLOR)
		item.draw_circle(center, radius * 0.18, GEM_COLOR)


## A polygon with a 1 px dark outline (drawn nudged in four directions under it).
static func _draw_outlined(item: CanvasItem, shape: PackedVector2Array, fill: Color, alpha: float) -> void:
	for nudge: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var shifted: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in shape:
			shifted.append(point + nudge)
		item.draw_colored_polygon(shifted, Color(OUTLINE_COLOR, alpha))
	item.draw_colored_polygon(shape, fill)

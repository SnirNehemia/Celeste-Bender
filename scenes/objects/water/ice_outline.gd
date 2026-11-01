class_name IceOutline
extends RefCounted
## IceOutline (Stage W5; trimmed with the grid ice, Stages I1-I5): the polygon helpers
## the ice outlines use. Pure geometry; no nodes. IceLayer (and PlayerIceLayer) trace
## their tiles into outlines and simplify them here; IceLook measures them; the
## WaterWorld finds a slope tile's top here. (Until the grid ice it also traced the
## metaballs' outline with marching squares: ice kept the exact shape of the water
## that froze. Grid ice is tiles, so that went.)

## A closed loop with points on (nearly) straight runs dropped: Ramer-Douglas-Peucker
## (keep the point farthest from the line between two kept points, if farther than
## `tolerance`, and repeat on both halves), run on the loop cut at its two most
## distant points.
static func simplify(loop: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if loop.size() <= 8:
		return loop
	var far_index: int = 0
	for index: int in loop.size():
		if loop[index].distance_squared_to(loop[0]) > loop[far_index].distance_squared_to(loop[0]):
			far_index = index
	var first_half: PackedVector2Array = loop.slice(0, far_index + 1)
	var second_half: PackedVector2Array = loop.slice(far_index)
	second_half.append(loop[0])
	var result: PackedVector2Array = _simplify_open(first_half, tolerance)
	var rest: PackedVector2Array = _simplify_open(second_half, tolerance)
	result.append_array(rest.slice(1, rest.size() - 1))
	return result


static func _simplify_open(line: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(line.size())
	keep[0] = 1
	keep[line.size() - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, line.size() - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var farthest: int = -1
		var farthest_distance: float = tolerance
		for index: int in range(span.x + 1, span.y):
			var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(line[index], line[span.x], line[span.y])
			var distance: float = nearest.distance_to(line[index])
			if distance > farthest_distance:
				farthest_distance = distance
				farthest = index
		if farthest != -1:
			keep[farthest] = 1
			stack.append(Vector2i(span.x, farthest))
			stack.append(Vector2i(farthest, span.y))
	var result: PackedVector2Array = PackedVector2Array()
	for index: int in line.size():
		if keep[index] == 1:
			result.append(line[index])
	return result


## Signed area of a closed polygon, px² (the shoelace formula).
static func polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area: float = 0.0
	for index: int in polygon.size():
		var here: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		twice_area += here.x * next.y - next.x * here.y
	return twice_area * 0.5


## The box around some polygons.
static func bounds(polygons: Array[PackedVector2Array]) -> Rect2:
	var box: Rect2 = Rect2(polygons[0][0], Vector2.ZERO)
	for polygon: PackedVector2Array in polygons:
		for point: Vector2 in polygon:
			box = box.expand(point)
	return box


## The TOP of some polygons at `x` (the smallest y where a vertical line at x crosses
## one of their edges), or INF if the line misses them all. Stage W6: a one-way slide
## asks this to know whether the player's feet are above it.
static func top_y_at(polygons: Array[PackedVector2Array], x: float) -> float:
	var top: float = INF
	for polygon: PackedVector2Array in polygons:
		for index: int in polygon.size():
			var from: Vector2 = polygon[index]
			var to: Vector2 = polygon[(index + 1) % polygon.size()]
			if x < minf(from.x, to.x) or x > maxf(from.x, to.x):
				continue
			# A vertical edge: its higher end. Otherwise the point on the edge at x.
			var y: float = minf(from.y, to.y) if from.x == to.x else lerpf(from.y, to.y, (x - from.x) / (to.x - from.x))
			top = minf(top, y)
	return top

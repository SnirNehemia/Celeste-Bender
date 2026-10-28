class_name IceOutline
extends RefCounted
## IceOutline (Stage W5, after the first W5 play-test: "freeze the ball in its
## original form"): turns water drawn as dots into the OUTLINE it's seen with, so ice
## has exactly the shape of the water that froze. Pure geometry; no nodes.
##
## The water's metaballs (WaterRenderer) draw each dot as a soft disc whose
## brightness falls from 1 at its center to 0 at blob_dot_radius (stretched along its
## velocity when it moves fast), add the discs up, and call everything brighter than
## blob_threshold water. trace() adds up the same field on a 1 px grid around the
## dots and follows the threshold line with MARCHING SQUARES: each grid cell looks at
## which of its 4 corners are inside, and the outline crosses its edges where the
## field reaches the threshold (found by linear interpolation along the edge). The
## crossing points, linked cell to cell, close into loops: the outline. Loops inside
## other loops (holes, a bubble in a splash) are dropped: ice is filled.
##
## SPEED: the field is added dot by dot over each dot's own footprint (about 100 grid
## points), not over the whole grid per dot. A 4-unit ball (64 dots) costs a few
## thousand steps, done once per freeze.

## Loops with less area than this, px², are dropped (a stray speck).
const MIN_LOOP_AREA: float = 4.0
## Outline points closer than this to the simplified line are dropped, px.
const SIMPLIFY_TOLERANCE: float = 0.4


## The outlines (closed loops of points, room-local) of water drawn as `dots` with
## `velocities` (empty, or one per dot: fast dots are stretched by
## 1 + speed x `stretch_per_speed`, as the renderer draws them), soft discs of
## `radius` px summed and cut at `threshold`.
static func trace(dots: PackedVector2Array, velocities: PackedVector2Array, radius: float,
		stretch_per_speed: float, threshold: float) -> Array[PackedVector2Array]:
	var loops: Array[PackedVector2Array] = []
	if dots.is_empty():
		return loops
	# The grid: every dot's reach, plus a margin, so the outline never touches its edge.
	var longest_reach: float = radius
	for index: int in velocities.size():
		longest_reach = maxf(longest_reach, radius * (1.0 + velocities[index].length() * stretch_per_speed))
	var low: Vector2 = dots[0]
	var high: Vector2 = dots[0]
	for dot: Vector2 in dots:
		low = low.min(dot)
		high = high.max(dot)
	var origin: Vector2i = Vector2i((low - Vector2.ONE * (longest_reach + 2.0)).floor())
	var size: Vector2i = Vector2i((high + Vector2.ONE * (longest_reach + 2.0)).ceil()) - origin + Vector2i.ONE
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(size.x * size.y)
	# Splat each dot: 1 - (stretched distance / radius), where that's positive.
	for index: int in dots.size():
		var center: Vector2 = dots[index] - Vector2(origin)
		var along: Vector2 = Vector2.RIGHT
		var stretch: float = 1.0
		if index < velocities.size() and velocities[index].length() > 0.001:
			along = velocities[index].normalized()
			stretch = 1.0 + velocities[index].length() * stretch_per_speed
		var across: Vector2 = along.orthogonal()
		var reach: float = radius * stretch
		var from_x: int = maxi(0, floori(center.x - reach))
		var to_x: int = mini(size.x - 1, ceili(center.x + reach))
		var from_y: int = maxi(0, floori(center.y - reach))
		var to_y: int = mini(size.y - 1, ceili(center.y + reach))
		for grid_y: int in range(from_y, to_y + 1):
			for grid_x: int in range(from_x, to_x + 1):
				var offset: Vector2 = Vector2(grid_x, grid_y) - center
				var squashed: Vector2 = Vector2(offset.dot(along) / stretch, offset.dot(across))
				var weight: float = 1.0 - squashed.length() / radius
				if weight > 0.0:
					field[grid_y * size.x + grid_x] += weight
	return _march(field, size, origin, threshold)


## Marching squares over `field` (size.x by size.y values, grid point (x, y) at
## room-local origin + (x, y)): the closed loops where it crosses `threshold`.
static func _march(field: PackedFloat32Array, size: Vector2i, origin: Vector2i, threshold: float) -> Array[PackedVector2Array]:
	# Each crossing point sits on a grid edge: edge ids are (y * size.x + x) * 2 for
	# the edge from (x, y) to the right, + 1 for the edge from (x, y) down.
	var points: Dictionary = {}       # edge id -> Vector2 (room-local)
	var links: Dictionary = {}        # edge id -> Array of the edge ids it joins
	for cell_y: int in size.y - 1:
		for cell_x: int in size.x - 1:
			var top_left: float = field[cell_y * size.x + cell_x] - threshold
			var top_right: float = field[cell_y * size.x + cell_x + 1] - threshold
			var bottom_right: float = field[(cell_y + 1) * size.x + cell_x + 1] - threshold
			var bottom_left: float = field[(cell_y + 1) * size.x + cell_x] - threshold
			var case_index: int = (1 if top_left > 0.0 else 0) | (2 if top_right > 0.0 else 0) \
				| (4 if bottom_right > 0.0 else 0) | (8 if bottom_left > 0.0 else 0)
			if case_index == 0 or case_index == 15:
				continue
			var top: int = (cell_y * size.x + cell_x) * 2
			var bottom: int = ((cell_y + 1) * size.x + cell_x) * 2
			var left: int = (cell_y * size.x + cell_x) * 2 + 1
			var right: int = (cell_y * size.x + cell_x + 1) * 2 + 1
			var corner: Vector2 = Vector2(origin) + Vector2(cell_x, cell_y)
			# Where the field reaches the threshold along each edge (linear).
			points[top] = corner + Vector2(_crossing(top_left, top_right), 0.0)
			points[bottom] = corner + Vector2(_crossing(bottom_left, bottom_right), 1.0)
			points[left] = corner + Vector2(0.0, _crossing(top_left, bottom_left))
			points[right] = corner + Vector2(1.0, _crossing(top_right, bottom_right))
			var segments: Array = []
			match case_index:
				1, 14: segments = [[left, top]]
				2, 13: segments = [[top, right]]
				3, 12: segments = [[left, right]]
				4, 11: segments = [[right, bottom]]
				6, 9: segments = [[top, bottom]]
				7, 8: segments = [[left, bottom]]
				5, 10:
					# A saddle: the cell's middle decides which corners join.
					var middle_inside: bool = (top_left + top_right + bottom_right + bottom_left) > 0.0
					if (case_index == 5) == middle_inside:
						segments = [[left, bottom], [top, right]]
					else:
						segments = [[left, top], [right, bottom]]
			for segment: Array in segments:
				_link(links, segment[0], segment[1])
				_link(links, segment[1], segment[0])
	# Walk the links into loops.
	var loops: Array[PackedVector2Array] = []
	var visited: Dictionary = {}
	for start: int in links:
		if visited.has(start):
			continue
		var loop: PackedVector2Array = PackedVector2Array()
		var previous: int = -1
		var current: int = start
		while not visited.has(current):
			visited[current] = true
			loop.append(points[current])
			var next: int = -1
			for neighbour: int in links[current]:
				if neighbour != previous and not visited.has(neighbour):
					next = neighbour
					break
			if next == -1:
				break
			previous = current
			current = next
		if loop.size() >= 3:
			loops.append(loop)
	return _keep_outer_loops(loops)


static func _link(links: Dictionary, from: int, to: int) -> void:
	if not links.has(from):
		links[from] = []
	(links[from] as Array).append(to)


## Where between two corner values (threshold already subtracted, one above 0 and
## one at or below) the field crosses zero, 0..1 from the first.
static func _crossing(first: float, second: float) -> float:
	if absf(second - first) < 0.00001:
		return 0.5
	return clampf(first / (first - second), 0.0, 1.0)


## Drops specks and holes (loops inside another loop), simplifies the rest.
static func _keep_outer_loops(loops: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var kept: Array[PackedVector2Array] = []
	for loop: PackedVector2Array in loops:
		if absf(polygon_area(loop)) < MIN_LOOP_AREA:
			continue
		var is_hole: bool = false
		for other: PackedVector2Array in loops:
			if other != loop and absf(polygon_area(other)) > absf(polygon_area(loop)) \
					and Geometry2D.is_point_in_polygon(loop[0], other):
				is_hole = true
				break
		if not is_hole:
			kept.append(simplify(loop, SIMPLIFY_TOLERANCE))
	return kept


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


## The area-weighted center of some polygons.
static func centroid(polygons: Array[PackedVector2Array]) -> Vector2:
	var total: float = 0.0
	var sum: Vector2 = Vector2.ZERO
	for polygon: PackedVector2Array in polygons:
		var area: float = absf(polygon_area(polygon))
		var middle: Vector2 = Vector2.ZERO
		for point: Vector2 in polygon:
			middle += point
		sum += middle / polygon.size() * area
		total += area
	return sum / total if total > 0.0 else Vector2.ZERO


## The box around some polygons.
static func bounds(polygons: Array[PackedVector2Array]) -> Rect2:
	var box: Rect2 = Rect2(polygons[0][0], Vector2.ZERO)
	for polygon: PackedVector2Array in polygons:
		for point: Vector2 in polygon:
			box = box.expand(point)
	return box


## Some polygons split into CONVEX parts (what physics shapes and the loose water's
## boxes need). A polygon Godot can't split is kept whole.
static func convex_parts(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in polygons:
		var pieces: Array[PackedVector2Array] = Geometry2D.decompose_polygon_in_convex(polygon)
		if pieces.is_empty():
			parts.append(polygon)
		else:
			parts.append_array(pieces)
	return parts


## Every polygon moved by `offset`.
static func moved(polygons: Array[PackedVector2Array], offset: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in polygons:
		var shifted: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in polygon:
			shifted.append(point + offset)
		result.append(shifted)
	return result

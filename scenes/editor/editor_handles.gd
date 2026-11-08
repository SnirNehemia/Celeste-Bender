class_name EditorHandles
extends RefCounted
## EditorHandles: the little squares on the selected object that you drag to
## change its size, its length or one of its points (Level_editor.md §7).
## Which handles an object has comes from its catalog entry (PaletteCatalog):
##   - its outline kind: a size corner, a width edge, or a spike strip's end
##   - its `point_properties`: one handle per point (a leaf's travel, a sail's rail ends)
##   - its `path_property`: one handle per point of a list (a rail platform's corners)
## LevelEditor finds the handle under the mouse (handle_at), asks for the new
## value while dragging (value_for_drag), and records the change for undo.
## EditorOverlay draws them (get_handles).
##
## A handle is a Dictionary: {"property": StringName, "kind": Kind, "position": Vector2}
## with `position` in level (global) coordinates; a PATH_POINT handle also has
## "index", which point of the list it is.

enum Kind {
	SIZE_FROM_TOP_LEFT,   ## bottom-right corner of a top-left outline (door, zones, goal)
	SIZE_FROM_FEET,       ## top-right corner of a standing outline (crate)
	WIDTH,                ## right edge of an outline centered on the origin (platforms, plate)
	STRIP_LENGTH,         ## the far end of a spike strip
	POINT,                ## a point relative to the origin
	PATH_POINT,           ## one point of a list of points relative to the origin (a rail's corner)
}

const TILE: int = 8
## Handles are drawn and picked this many SCREEN pixels across, whatever the zoom.
const HANDLE_SCREEN_SIZE: float = 6.0


## The handles of `node` (empty if it has none).
static func get_handles(node: Node2D) -> Array[Dictionary]:
	var handles: Array[Dictionary] = []
	var entry: PaletteCatalog.Entry = PaletteCatalog.entry_for_node(node)
	if entry == null:
		return handles
	var outline: Rect2 = PaletteCatalog.get_bounds(node)
	# A size or width gets a handle only if it's a design setting the panel lists:
	# an enemy's body_size gives its outline, but isn't for changing.
	var outline_property: StringName = entry.width_property if entry.bounds == PaletteCatalog.Bounds.WIDTH_CENTERED else entry.size_property
	var has_outline_handle: bool = entry.bounds == PaletteCatalog.Bounds.SPIKE_STRIP or entry.editable_properties.has(outline_property)
	# A turned plank's handle would sit on the box around it, not on its end: none
	# then (its width is still in the panel).
	if entry.uses_rotation and not is_zero_approx(node.rotation):
		has_outline_handle = false
	# FIXED has no outline handle: the match below then adds none.
	match entry.bounds if has_outline_handle else PaletteCatalog.Bounds.FIXED:
		PaletteCatalog.Bounds.SIZE_TOP_LEFT:
			handles.append(_handle(entry.size_property, Kind.SIZE_FROM_TOP_LEFT, outline.end))
		PaletteCatalog.Bounds.SIZE_BOTTOM_CENTER:
			handles.append(_handle(entry.size_property, Kind.SIZE_FROM_FEET, Vector2(outline.end.x, outline.position.y)))
		PaletteCatalog.Bounds.WIDTH_CENTERED:
			handles.append(_handle(entry.width_property, Kind.WIDTH, Vector2(outline.end.x, outline.get_center().y)))
		PaletteCatalog.Bounds.SPIKE_STRIP:
			var is_horizontal: bool = _is_horizontal_strip(node as Spikes)
			var far_end: Vector2 = Vector2(outline.end.x, outline.get_center().y) if is_horizontal else Vector2(outline.get_center().x, outline.end.y)
			handles.append(_handle(&"tile_count", Kind.STRIP_LENGTH, far_end))
	for point_property: StringName in entry.point_properties:
		handles.append(_handle(point_property, Kind.POINT, node.global_position + (node.get(point_property) as Vector2)))
	if entry.path_property != &"":
		var points: PackedVector2Array = node.get(entry.path_property)
		for index: int in points.size():
			var handle: Dictionary = _handle(entry.path_property, Kind.PATH_POINT, node.global_position + points[index])
			handle["index"] = index
			handles.append(handle)
	return handles


## The handle of `node` under `world_point`, or an empty Dictionary.
## `zoom_factor`: the editor camera's zoom, so the pick area matches the drawing.
static func handle_at(node: Node2D, world_point: Vector2, zoom_factor: float) -> Dictionary:
	var half_size: float = HANDLE_SCREEN_SIZE / zoom_factor / 2.0 + 1.0
	# Points last in the list are picked first: they can sit on an outline corner.
	var handles: Array[Dictionary] = get_handles(node)
	handles.reverse()
	for handle: Dictionary in handles:
		var position: Vector2 = handle["position"]
		if absf(world_point.x - position.x) <= half_size and absf(world_point.y - position.y) <= half_size:
			return handle
	return {}


## The property's new value when `handle` is dragged to `world_point`: whole tiles,
## or with `free` (Alt) whole pixels. Never smaller than one tile / one pixel.
static func value_for_drag(node: Node2D, handle: Dictionary, world_point: Vector2, free: bool) -> Variant:
	var step: float = 1.0 if free else float(TILE)
	var origin: Vector2 = node.global_position
	match handle["kind"]:
		Kind.SIZE_FROM_TOP_LEFT:
			var unit: int = PaletteCatalog.entry_for_node(node).size_unit
			if unit != 1:
				# A size in whole tiles (a wall's Vector2i), even with Alt.
				var tiles: Vector2 = ((world_point - origin) / unit).round()
				return Vector2i(maxi(int(tiles.x), 1), maxi(int(tiles.y), 1))
			return _at_least((world_point - origin).snapped(Vector2.ONE * step), step)
		Kind.SIZE_FROM_FEET:
			# The crate grows around its feet: twice the distance sideways, all of it up.
			var size: Vector2 = Vector2(2.0 * (world_point.x - origin.x), origin.y - world_point.y)
			return _at_least(size.snapped(Vector2.ONE * step), step)
		Kind.WIDTH:
			return maxf(snappedf(2.0 * (world_point.x - origin.x), step), step)
		Kind.STRIP_LENGTH:
			var along: float = (world_point.x - origin.x) if _is_horizontal_strip(node as Spikes) else (world_point.y - origin.y)
			return clampi(roundi(along / TILE), 1, 40)
		Kind.PATH_POINT:
			# The whole list, with this one point moved. duplicate(): a new list, so
			# the value the drag started from (kept for undo) isn't changed with it.
			var points: PackedVector2Array = (node.get(handle["property"]) as PackedVector2Array).duplicate()
			points[handle["index"]] = (world_point - origin).snapped(Vector2.ONE * step)
			return points
		_:
			return (world_point - origin).snapped(Vector2.ONE * step)


## Spikes pointing up or down lie along a row; left or right, along a column.
static func _is_horizontal_strip(spikes: Spikes) -> bool:
	return spikes.facing == Spikes.Facing.UP or spikes.facing == Spikes.Facing.DOWN


static func _handle(property: StringName, kind: Kind, position: Vector2) -> Dictionary:
	return {"property": property, "kind": kind, "position": position}


static func _at_least(size: Vector2, minimum: float) -> Vector2:
	return Vector2(maxf(size.x, minimum), maxf(size.y, minimum))

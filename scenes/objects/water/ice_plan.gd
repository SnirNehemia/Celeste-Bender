class_name IcePlan
extends RefCounted
## IcePlan (grid ice, Stages I1-I3, Water_bending.md §16 "Re-planned: grid ice"):
## what pressing 2 WOULD make right now. The water hands work one out every frame
## while you hold water, draw it as the GHOST, and hand it to
## WaterWorld.apply_ice_plan() when 2 is pressed, so what you see is exactly what you
## get. Pure data plus the static builders; not a node.
##
## Four kinds:
##   - BLOCK (I1): the held ball, as the most square block its whole units fill
##     (block_size), on the cells nearest the ball.
##   - TRAIL (I2): a water snake, as tiles UNDER its trail (the trail is the surface
##     you walk on): flat runs are full tiles, 45° runs slope tiles, gentle runs
##     (1:2, the "22.5°" tiles) gentle pairs, 90° runs a column. Corners snap to the 8 px grid (for_trail).
##     Every slope tile is BACKED by a full tile under it, so the ramp is solid.
##   - WALL (I2): a waterfall the ball is in, from its source's mouth down to where it
##     lands, as a column of full tiles (for_wall).
##   - RAFT (I3): the ball touching a water surface or under it: a floating slab at
##     the surface, as wide as its whole units in tiles (raft_rect).
## Cells are room-local tile coordinates (the WaterWorld's and the PlayerIceLayer's,
## both at the room's origin). A cell is BLOCKED when ice can't go there (rock, any
## solid tile, you, a crate, a door, water: WaterWorld.is_cell_blocked_for_ice);
## blocked cells are skipped and their water drips. `is_brittle`: the free cells,
## with the player ice they'd join, would hang in mid-air (they'd crumble, I4).

enum Kind { NONE, BLOCK, TRAIL, WALL, RAFT }

const TILE: int = 8
## Tile shape by the trail's height at a cell's left and right edges, px below the
## cell's top (0, 4 or 8): which IceLayer tile has that surface.
const TILE_BY_TOPS: Dictionary = {
	Vector2i(0, 0): IceLayer.ICE_TILE,
	Vector2i(8, 0): IceLayer.SLOPE_UP_RIGHT,
	Vector2i(0, 8): IceLayer.SLOPE_UP_LEFT,
	Vector2i(8, 4): IceLayer.GENTLE_UP_RIGHT_LOW,
	Vector2i(4, 0): IceLayer.GENTLE_UP_RIGHT_HIGH,
	Vector2i(0, 4): IceLayer.GENTLE_UP_LEFT_HIGH,
	Vector2i(4, 8): IceLayer.GENTLE_UP_LEFT_LOW,
}
## The angles a trail run may have, degrees from horizontal (WaterSnake snaps to
## them): flat, the GENTLE slope (1 down per 2 across: the "22.5°" tiles are really
## 26.6°), 45° and straight up.
const GENTLE_ANGLE: float = 26.565
const TRAIL_ANGLES: Array[float] = [0.0, GENTLE_ANGLE, 45.0, 90.0]
## Runs shorter than this after snapping (px of their longer side) are dropped.
const MIN_RUN: float = 0.5

var kind: Kind = Kind.NONE
## The cells, in order (a trail's from its foot to its head), their tiles, and
## whether each is blocked.
var cells: Array[Vector2i] = []
var atlases: Array[Vector2i] = []
var blocked: Array[bool] = []
var is_brittle: bool = false
## RAFT: the slab, room-local px, and the water it holds, px².
var raft_rect: Rect2 = Rect2()
var raft_area: float = 0.0
## WALL: the source it freezes.
var source: WaterSource = null


## The block a ball of `units` whole units freezes into, in tiles (width, height):
## the most square rectangle it fills, wider than tall. 1 -> 1x1, 2 and 3 -> 2x1,
## 4 and 5 -> 2x2, 6, 7 and 8 -> 3x2, 9 -> 3x3.
static func block_size(units: int) -> Vector2i:
	if units <= 0:
		return Vector2i.ZERO
	var side: int = floori(sqrt(float(units)))
	return Vector2i(side + 1, side) if side * (side + 1) <= units else Vector2i(side, side)


## The water a tile `atlas` holds, px² (its shape's area: a full tile is one unit).
static func get_tile_area(atlas: Vector2i) -> float:
	return absf(IceOutline.polygon_area(IceLayer.get_tile_shape(atlas)))


## The plan for the held ball (`center` room-local, `area` px² of water, drawn
## `radius` px out from its center): a RAFT if it touches a water surface (or is
## under one), else a BLOCK. NONE with less than a whole unit.
static func for_ball(world: WaterWorld, center: Vector2, area: float, radius: float) -> IcePlan:
	var plan: IcePlan = IcePlan.new()
	var units: int = floori(area / WaterWorld.UNIT_AREA + 0.02)
	if units <= 0:
		return plan
	var surface: Array = world.find_raft_surface(center, radius)
	if not surface.is_empty():
		plan.kind = Kind.RAFT
		plan.raft_area = units * WaterWorld.UNIT_AREA
		plan.raft_rect = world.fit_raft_rect(center.x, surface[0], units * TILE)
		return plan
	plan.kind = Kind.BLOCK
	var size: Vector2i = block_size(units)
	var origin: Vector2i = Vector2i(roundi(center.x / TILE - size.x * 0.5), roundi(center.y / TILE - size.y * 0.5))
	for y: int in size.y:
		for x: int in size.x:
			plan._add(origin + Vector2i(x, y), IceLayer.ICE_TILE)
	plan._finish(world)
	return plan


## The plan for a snake whose trail runs through `path` (room-local, the foot first,
## then its corners and the ball): tiles under the trail, the path snapped to the
## tile angles and its corners to the grid (see the header).
static func for_trail(world: WaterWorld, path: PackedVector2Array) -> IcePlan:
	var plan: IcePlan = IcePlan.new()
	plan.kind = Kind.TRAIL
	var snapped_path: PackedVector2Array = snap_path(path)
	for index: int in range(1, snapped_path.size()):
		var from: Vector2 = snapped_path[index - 1]
		var to: Vector2 = snapped_path[index]
		if is_equal_approx(from.x, to.x):
			plan._add_column(from, to, _column_side(snapped_path, index))
		else:
			plan._add_sloped(from, to)
	# BACKED SLOPES (after the grid-ice play-test): a full tile under every slope tile.
	# A diagonal's slope tiles only touched at a corner and read as a dotted line; with
	# the backing each one shares an edge with the next, and the ramp looks solid. The
	# backings come after the surface, so a pool short of water leaves them out first.
	var surface_count: int = plan.cells.size()
	for index: int in surface_count:
		if plan.atlases[index] != IceLayer.ICE_TILE:
			plan._add_backing(plan.cells[index] + Vector2i.DOWN)
	plan._finish(world)
	return plan


## `path` (room-local) snapped for tiles: the first point to the nearest grid corner,
## then each run's direction to the nearest of TRAIL_ANGLES (either way) and its
## length to whole tiles along its longer side (16 px steps for 22.5°, so every run
## ends on a grid corner too).
static func snap_path(path: PackedVector2Array) -> PackedVector2Array:
	var snapped_path: PackedVector2Array = PackedVector2Array()
	if path.is_empty():
		return snapped_path
	var cursor: Vector2 = (path[0] / TILE).round() * TILE
	snapped_path.append(cursor)
	for index: int in range(1, path.size()):
		var run: Vector2 = path[index] - path[index - 1]
		if run.length() < 0.01:
			continue
		var angle: float = _snap_angle(rad_to_deg(atan2(absf(run.y), absf(run.x))))
		var sign_x: float = signf(run.x)
		var sign_y: float = signf(run.y)
		var step: Vector2 = Vector2.ZERO
		# (_snap_angle returns exactly 0 or 90 for flat and upright runs; the 1° slack
		# only guards the float compare.)
		if angle >= 89.0:
			step = Vector2(0.0, sign_y * roundf(absf(run.y) / TILE) * TILE)
		elif angle <= 1.0:
			step = Vector2(sign_x * roundf(absf(run.x) / TILE) * TILE, 0.0)
		else:
			# Along the run's own length: the horizontal part is length × cos(angle). A
			# gentle run rises 1 px per 2 across, so it ends on a corner every 16 px.
			var is_gentle: bool = angle < 30.0
			var cell_width: float = TILE * (2.0 if is_gentle else 1.0)
			var width: float = roundf(run.length() * cos(deg_to_rad(angle)) / cell_width) * cell_width
			step = Vector2(sign_x * width, sign_y * width * (0.5 if is_gentle else 1.0))
		if maxf(absf(step.x), absf(step.y)) < MIN_RUN:
			continue
		cursor += step
		snapped_path.append(cursor)
	return snapped_path


## `degrees` (0..90 from horizontal) to the nearest of TRAIL_ANGLES.
static func _snap_angle(degrees: float) -> float:
	var best: float = 0.0
	for angle: float in TRAIL_ANGLES:
		if absf(degrees - angle) < absf(degrees - best):
			best = angle
	return best


## The plan for freezing `water_source`'s waterfall: a column of full tiles from the
## cell just under its mouth down to where the fall lands (solid ground, or a pool's
## surface: the cell holding water is blocked, so the wall stops on it).
static func for_wall(world: WaterWorld, water_source: WaterSource) -> IcePlan:
	var plan: IcePlan = IcePlan.new()
	plan.kind = Kind.WALL
	plan.source = water_source
	var mouth: Vector2 = world.to_local(water_source.global_position)
	var half_width: float = maxf(water_source.pour_width, 1.0) * 0.5
	var first_column: int = floori((mouth.x - half_width) / TILE)
	var last_column: int = floori((mouth.x + half_width - 0.01) / TILE)
	var first_row: int = floori((mouth.y + WaterSource.FROZEN_CHECK_BELOW) / TILE)
	var row: int = first_row
	while row < world.grid_size.y:
		var lands: bool = false
		for column: int in range(first_column, last_column + 1):
			if world.is_cell_solid(Vector2i(column, row)):
				lands = true
		if lands:
			break
		for column: int in range(first_column, last_column + 1):
			plan._add(Vector2i(column, row), IceLayer.ICE_TILE)
		# Into a pool: the cell holding its surface is the last (it's blocked: water).
		if world.is_cell_wet(Vector2i(first_column, row)):
			break
		row += 1
	plan._finish(world)
	return plan


## The cells that will be ice (not blocked).
func get_free_cells() -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for index: int in cells.size():
		if not blocked[index]:
			free.append(cells[index])
	return free


## The water the plan's ice holds, px² (free cells only; a raft its slab's).
func get_cost() -> float:
	if kind == Kind.RAFT:
		return raft_area
	var cost: float = 0.0
	for index: int in cells.size():
		if not blocked[index]:
			cost += get_tile_area(atlases[index])
	return cost


func is_empty() -> bool:
	if kind == Kind.RAFT:
		return raft_area <= 0.0
	return get_free_cells().is_empty()


# --- Building --------------------------------------------------------------------------

func _add(cell: Vector2i, atlas: Vector2i) -> void:
	var index: int = cells.find(cell)
	if index >= 0:
		# A cell two runs share (a corner): a full tile wins over a slope.
		if atlas == IceLayer.ICE_TILE:
			atlases[index] = atlas
		return
	cells.append(cell)
	atlases.append(atlas)


## A full tile under a slope tile (backed slopes, for_trail), unless another run
## already uses that cell (its surface wins: a full tile there would bury it).
func _add_backing(cell: Vector2i) -> void:
	if not cells.has(cell):
		cells.append(cell)
		atlases.append(IceLayer.ICE_TILE)


## A run that isn't vertical, from `from` to `to` (on grid corners): one tile per
## column it crosses, under the line, shaped by the line's height at the column's two
## edges (TILE_BY_TOPS). Added in the run's own direction (foot to head).
func _add_sloped(from: Vector2, to: Vector2) -> void:
	var step: int = 1 if to.x > from.x else -1
	var first: int = roundi(from.x / TILE) if step > 0 else roundi(from.x / TILE) - 1
	var last: int = roundi(to.x / TILE) - 1 if step > 0 else roundi(to.x / TILE)
	var column: int = first
	while (step > 0 and column <= last) or (step < 0 and column >= last):
		var left_x: float = column * TILE
		var left_y: float = from.y + (to.y - from.y) * (left_x - from.x) / (to.x - from.x)
		var right_y: float = from.y + (to.y - from.y) * (left_x + TILE - from.x) / (to.x - from.x)
		# The tile whose top holds the line's higher end (the line runs through it).
		var row: int = floori((minf(left_y, right_y) + 0.01) / TILE)
		var tops: Vector2i = Vector2i(roundi(left_y - row * TILE), roundi(right_y - row * TILE))
		_add(Vector2i(column, row), TILE_BY_TOPS.get(tops, IceLayer.ICE_TILE))
		column += step


## A vertical run from `from` to `to` (on grid corners): full tiles in the column on
## `side` of the line (-1 left, +1 right), between the two heights.
func _add_column(from: Vector2, to: Vector2, side: int) -> void:
	var column: int = roundi(from.x / TILE) + (0 if side > 0 else -1)
	var step: int = 1 if to.y > from.y else -1
	var first: int = roundi(from.y / TILE) if step > 0 else roundi(from.y / TILE) - 1
	var last: int = roundi(to.y / TILE) - 1 if step > 0 else roundi(to.y / TILE)
	var row: int = first
	while (step > 0 and row <= last) or (step < 0 and row >= last):
		_add(Vector2i(column, row), IceLayer.ICE_TILE)
		row += step


## Which side of a vertical run (ending at path[index]) its column goes: toward the
## runs next to it, so the tiles join (a run from the left: left; one going on to the
## left: left); right when neither says.
static func _column_side(path: PackedVector2Array, index: int) -> int:
	var x: float = path[index].x
	if index >= 2 and not is_equal_approx(path[index - 2].x, x):
		return -1 if path[index - 2].x < x else 1
	if index + 1 < path.size() and not is_equal_approx(path[index + 1].x, x):
		return -1 if path[index + 1].x < x else 1
	return 1


## Works out which cells are blocked and whether the rest would hang.
func _finish(world: WaterWorld) -> void:
	blocked.clear()
	for cell: Vector2i in cells:
		blocked.append(world.is_cell_blocked_for_ice(cell))
	is_brittle = world.ice_layer.would_be_brittle(get_free_cells())

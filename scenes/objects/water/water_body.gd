class_name WaterBody
extends RefCounted
## WaterBody (Stage W1, Water_bending.md §6.1): one pool, puddle or stream of still
## or sloshing water, stored as a HEIGHT FIELD. Pure data plus its own physics step;
## it draws nothing and knows nothing about tiles. WaterWorld (water_world.gd) owns
## every body of a room, decides where a body's ends are (a wall, more ground to
## flow onto, or a drop to spill over) and draws them.
##
## A body is a horizontal run of COLUMNS, each `column_width` px wide (2 by
## default). Column i covers x from `left_x + i × column_width` to the next one, in
## the room's local pixels. Each column stores:
##   floor_y  the top of the solid ground under it (y grows DOWNWARD, as in Godot)
##   ceiling_y the bottom of the solid above it (or NO_CEILING: open sky). Only a
##            column under a low wall (a passage joining two pools) has one.
##   depth    how much water stands on it, px. The surface is at floor_y - depth.
##
## THE PIPE MODEL (the "virtual pipes" of shallow-water games). Each pair of
## neighbouring columns is joined by a pipe carrying `flow[i]`: px of depth per
## second moving from column i to column i + 1 (negative = leftward). Each step:
##   1. every pipe's flow speeds up with the difference in surface height across it
##      (water runs from the higher surface to the lower one) and is damped a bit;
##   2. a column never sends out more water than it has (its outflows are scaled
##      down if they would);
##   3. each column's depth changes by what flows in minus what flows out.
## That one rule gives waves that travel and bounce off walls, water that runs down
## steps and levels out, and exact bookkeeping: water only ever moves between
## columns, so the total never changes by itself.
## In math terms (for the curious): d(depth)/dt = flow in - flow out and
## d(flow)/dt = k × (difference in surface height), so depth obeys a wave equation
## with speed sqrt(water_gravity × depth), the speed of shallow-water waves.
##
## A column under a ceiling may hold more water than fits under it: the extra is the
## water's PRESSURE (it pushes on the neighbours through its height). That's what
## makes two pools joined by a passage under a wall settle at the same level. The
## extra isn't drawn (WaterWorld clips the drawing at the ceiling).
##
## RIPPLES: a second, cosmetic layer on top: a spring chain along the surface line
## (`ripple` offsets and their speeds). Drops and swimmers kick it; it moves no water.
## It gives the small, quick rings the bulk model is too coarse for.
##
## SPILLS: `spill_flow_left` / `spill_flow_right` are pipes to the outside, used only
## when WaterWorld says that end is a lip over a drop. Water leaving through them
## piles up in `spilled_left` / `spilled_right` (px², not yet turned into drops),
## which WaterWorld turns into falling drops.

## ceiling_y of a column with nothing above it.
const NO_CEILING: float = -1.0e9
## Water shallower than this, px, counts as a dry column (drawing, trimming).
const DRY_DEPTH: float = 0.01

## What lies past one end of the body, decided by WaterWorld every frame.
enum EndKind {
	WALL,   ## solid at the surface height: nothing leaves
	SPILL,  ## a lip over a drop: water pours out as drops
}

var column_width: float = 2.0
## Left edge of column 0, room-local px. Always a whole number of columns from the
## room's left edge, so two bodies' columns line up when they meet.
var left_x: float = 0.0
var floor_y: PackedFloat32Array = PackedFloat32Array()
var ceiling_y: PackedFloat32Array = PackedFloat32Array()
var depth: PackedFloat32Array = PackedFloat32Array()
## One fewer than the columns: flow[i] runs between column i and i + 1.
var flow: PackedFloat32Array = PackedFloat32Array()
var ripple: PackedFloat32Array = PackedFloat32Array()
var ripple_speed: PackedFloat32Array = PackedFloat32Array()
var left_end: EndKind = EndKind.WALL
var right_end: EndKind = EndKind.WALL
var spill_flow_left: float = 0.0
var spill_flow_right: float = 0.0
var spilled_left: float = 0.0
var spilled_right: float = 0.0
## A calm body sleeps: WaterWorld skips its step until something wakes it.
var is_asleep: bool = false


# --- Building -----------------------------------------------------------------------

## Adds a column at the right end (`at_left` false) or the left end (true). A new
## column starts with no flow and no ripple; its pipe to the old end does too.
func add_column(new_floor_y: float, new_ceiling_y: float, new_depth: float, at_left: bool) -> void:
	if at_left:
		left_x -= column_width
		floor_y.insert(0, new_floor_y)
		ceiling_y.insert(0, new_ceiling_y)
		depth.insert(0, new_depth)
		ripple.insert(0, 0.0)
		ripple_speed.insert(0, 0.0)
		if get_column_count() > 1:
			flow.insert(0, 0.0)
	else:
		floor_y.append(new_floor_y)
		ceiling_y.append(new_ceiling_y)
		depth.append(new_depth)
		ripple.append(0.0)
		ripple_speed.append(0.0)
		if get_column_count() > 1:
			flow.append(0.0)
	is_asleep = false


## Takes the columns of `other`, which must start right where this body ends, into
## this body (the two have met). `other` is left empty.
func absorb_on_right(other: WaterBody) -> void:
	flow.append(0.0)  # the new pipe between our last column and its first one
	# Water that was pouring over its left lip (now our joint) just lands there.
	if other.spilled_left > 0.0:
		other.depth[0] += other.spilled_left / column_width
	floor_y.append_array(other.floor_y)
	ceiling_y.append_array(other.ceiling_y)
	depth.append_array(other.depth)
	flow.append_array(other.flow)
	ripple.append_array(other.ripple)
	ripple_speed.append_array(other.ripple_speed)
	right_end = other.right_end
	spill_flow_right = other.spill_flow_right
	# Our right lip is gone too (it's the joint): what was pouring over it lands in
	# our last column... which is no longer last, so it's at index count_before - 1.
	if spilled_right > 0.0:
		var joint_column: int = get_column_count() - other.get_column_count() - 1
		depth[joint_column] += spilled_right / column_width
	spilled_right = other.spilled_right
	is_asleep = false


## Drops dry columns at either end (a puddle that has finished spreading keeps no
## empty tail), but always keeps one column. Returns the px² of water thrown away
## (only the crumbs below DRY_DEPTH), so the world can keep its books.
func trim_dry_ends() -> float:
	var thrown_away: float = 0.0
	while get_column_count() > 1 and depth[get_column_count() - 1] < DRY_DEPTH \
			and absf(flow[flow.size() - 1]) < DRY_DEPTH:
		thrown_away += depth[get_column_count() - 1] * column_width
		floor_y.remove_at(floor_y.size() - 1)
		ceiling_y.remove_at(ceiling_y.size() - 1)
		depth.remove_at(depth.size() - 1)
		ripple.remove_at(ripple.size() - 1)
		ripple_speed.remove_at(ripple_speed.size() - 1)
		flow.remove_at(flow.size() - 1)
		right_end = EndKind.WALL
		spill_flow_right = 0.0
	while get_column_count() > 1 and depth[0] < DRY_DEPTH and absf(flow[0]) < DRY_DEPTH:
		thrown_away += depth[0] * column_width
		floor_y.remove_at(0)
		ceiling_y.remove_at(0)
		depth.remove_at(0)
		ripple.remove_at(0)
		ripple_speed.remove_at(0)
		flow.remove_at(0)
		left_x += column_width
		left_end = EndKind.WALL
		spill_flow_left = 0.0
	return thrown_away


# --- Questions --------------------------------------------------------------------

func get_column_count() -> int:
	return depth.size()


## Room-local x of the left edge of column `column`.
func get_column_left(column: int) -> float:
	return left_x + column * column_width


func get_right_x() -> float:
	return left_x + get_column_count() * column_width


## The column covering room-local `x`, or -1 if `x` is outside the body.
func get_column_at(x: float) -> int:
	var column: int = floori((x - left_x) / column_width)
	if column < 0 or column >= get_column_count():
		return -1
	return column


## Where the water's surface is in column `column` (bulk only, no ripple), px.
func get_surface_y(column: int) -> float:
	return floor_y[column] - depth[column]


## The surface as drawn: with the ripple, and never above the column's ceiling.
func get_drawn_surface_y(column: int) -> float:
	return maxf(get_surface_y(column) - ripple[column], ceiling_y[column])


## All the water in this body, px² (WaterWorld turns px² into units).
func get_area() -> float:
	var total: float = 0.0
	for column_depth: float in depth:
		total += column_depth
	return total * column_width + spilled_left + spilled_right


func get_max_depth() -> float:
	var deepest: float = 0.0
	for column_depth: float in depth:
		deepest = maxf(deepest, column_depth)
	return deepest


# --- Changing the water -----------------------------------------------------------

## Pours `area` px² of water into `column` (a drop landing, a bucket). Wakes it.
func add_water(column: int, area: float) -> void:
	depth[column] += area / column_width
	is_asleep = false


## Pours `area` px² evenly over `center_column` and `spread` columns each side
## (those that exist): a wide, gentle top-up instead of one column's spike (a
## water snake shortening back into its pool, Stage W4). Wakes it.
func add_water_spread(center_column: int, area: float, spread: int) -> void:
	var first: int = maxi(0, center_column - spread)
	var last: int = mini(get_column_count() - 1, center_column + spread)
	var share: float = area / float(last - first + 1)
	for column: int in range(first, last + 1):
		depth[column] += share / column_width
	is_asleep = false


## Takes up to `area` px² from the columns around `center_column` (spread over
## `spread` columns each side, the nearest giving most). Returns what it got, px².
func remove_water(center_column: int, area: float, spread: int) -> float:
	# Nearest column first: 0, -1, +1, -2, +2...
	var columns: Array[int] = [center_column]
	for offset: int in range(1, spread + 1):
		columns.append(center_column - offset)
		columns.append(center_column + offset)
	columns = columns.filter(func(column: int) -> bool: return column >= 0 and column < get_column_count())
	var taken: float = 0.0
	# Two passes: the first shares what's wanted out evenly over the columns left,
	# the second takes the rest wherever water is left (a thin edge may not have
	# had its share).
	for pass_index: int in 2:
		for index: int in columns.size():
			var column: int = columns[index]
			var wanted: float = area - taken
			if pass_index == 0:
				wanted /= float(columns.size() - index)
			var got: float = minf(wanted / column_width, depth[column])
			depth[column] -= got
			taken += got * column_width
	is_asleep = false
	return taken


## Pushes the water around `column`: `sideways` px/s of flow to the right (negative
## = left), and `downward` px/s pushing the water out from under the point (both
## ways), plus a kick to the ripples. The push is spread over `radius` columns each
## side, strongest in the middle: a wide push moves enough water to make a wave you
## can see. Moves no water by itself: the pipes do, next step.
func push(column: int, sideways: float, downward: float, ripple_kick: float, radius: int = 1) -> void:
	var count: int = get_column_count()
	radius = maxi(radius, 1)
	for distance: int in radius:
		var weight: float = float(radius - distance) / radius
		var left_pipe: int = column - 1 - distance   # the pipe on the left of column - distance
		var right_pipe: int = column + distance      # the pipe on the right of column + distance
		if left_pipe >= 0 and left_pipe < count - 1:
			flow[left_pipe] += (sideways * 0.5 - downward) * weight
		if right_pipe >= 0 and right_pipe < count - 1:
			flow[right_pipe] += (sideways * 0.5 + downward) * weight
		for kicked: int in [column - distance, column + distance]:
			if kicked >= 0 and kicked < count and (distance > 0 or kicked == column):
				ripple_speed[kicked] -= ripple_kick * weight
	is_asleep = false


## Drags the water in columns `first_column`..`last_column` along, like a body
## moving through it: every pipe touching those columns moves `blend` (0..1) of the
## way toward `target_flow` (px of depth per second). The pipes inside cancel out, so
## water leaves the trailing column and piles up at the leading one: a bow wave in
## front, a dip behind. Wakes it.
func drag(first_column: int, last_column: int, target_flow: float, blend: float) -> void:
	var count: int = get_column_count()
	for pipe: int in range(maxi(first_column - 1, 0), mini(last_column, count - 2) + 1):
		flow[pipe] = lerpf(flow[pipe], target_flow, blend)
	is_asleep = false


## Moves water sideways at once: up to `amount` px of depth is taken from the
## columns within `radius` of `column` (most from the middle) and shared out over the
## columns just beyond them on both sides. A dip with a raised ring around it: the
## pipes turn it into waves running outward. A poke, a splash. Wakes it.
func displace(column: int, amount: float, radius: int) -> void:
	var count: int = get_column_count()
	var taken: float = 0.0
	for offset: int in range(-radius, radius + 1):
		var dipped: int = column + offset
		if dipped < 0 or dipped >= count:
			continue
		var share: float = minf(amount * (1.0 - absf(offset) / float(radius + 1)), depth[dipped])
		depth[dipped] -= share
		taken += share
	var ring: Array[int] = []
	for distance: int in range(radius + 1, radius * 2 + 2):
		for raised: int in [column - distance, column + distance]:
			if raised >= 0 and raised < count:
				ring.append(raised)
	if ring.is_empty():
		ring.append(clampi(column, 0, count - 1))  # nowhere to go: put it back
	for raised: int in ring:
		depth[raised] += taken / ring.size()
	is_asleep = false


# --- Physics ----------------------------------------------------------------------

## One sub-step of the pipe model (see the header), `delta` seconds of game time.
## `gravity`, `max_wave_depth`, `damping` (share of the flow lost per second),
## `viscosity` (how fast neighbouring pipes even out, per second) and `min_depth`
## (surface tension: puddles stop spreading this thin) come from WaterTuning.
## SPEED: it runs a few times a frame on every awake column, so it works on local
## copies of the arrays (a local variable is much faster to reach than a member in
## GDScript) and writes them back at the end.
func step_flow(delta: float, gravity: float, max_wave_depth: float, damping: float, viscosity: float,
		min_depth: float) -> void:
	var count: int = depth.size()
	var depths: PackedFloat32Array = depth
	var flows: PackedFloat32Array = flow
	var floors: PackedFloat32Array = floor_y
	var damp: float = maxf(0.0, 1.0 - damping * delta)
	var stiffness_per_depth: float = gravity / (column_width * column_width) * delta
	# 0. Viscosity: each pipe's flow moves a little toward its neighbours' average.
	# It barely touches long waves but quickly kills the column-to-column flicker
	# (a checkerboard of tiny flows) that plain damping would leave running for ages.
	var smoothing: float = minf(0.45, viscosity * delta) * 0.5
	if smoothing > 0.0 and count > 3:
		var previous: float = flows[0]
		for i: int in range(1, count - 2):
			var current: float = flows[i]
			flows[i] = current + smoothing * (previous + flows[i + 1] - 2.0 * current)
			previous = current
	# 1. Pipes speed up with the surface difference across them.
	for i: int in count - 1:
		var left_depth: float = depths[i]
		var right_depth: float = depths[i + 1]
		var left_surface: float = floors[i] - left_depth
		var right_surface: float = floors[i + 1] - right_depth
		# A wave's speed depends on how deep the water is: the deeper side of the pipe
		# sets it (a dry column next to a full one must still fill up).
		var wave_depth: float = minf(maxf(left_depth, right_depth), max_wave_depth)
		# Surface y grows downward: a LOWER surface on the right (bigger y) means
		# water runs right (positive flow).
		var new_flow: float = flows[i] * damp + stiffness_per_depth * wave_depth * (right_surface - left_surface)
		if new_flow > 0.0:
			# Water can't climb onto a step higher than its surface, and only the
			# water ABOVE a step's edge can go over it (without this, momentum would
			# carry a tank's water over its lip until the tank is below the lip).
			# Surface tension: a film no deeper than min_depth doesn't creep onto a
			# column that's just as thin (where a puddle stops spreading).
			if left_depth <= min_depth and right_depth < min_depth:
				new_flow = 0.0
			elif floors[i + 1] < floors[i]:
				new_flow = minf(new_flow, maxf(0.0, floors[i + 1] - left_surface) / delta)
		elif new_flow < 0.0:
			if right_depth <= min_depth and left_depth < min_depth:
				new_flow = 0.0
			elif floors[i] < floors[i + 1]:
				new_flow = maxf(new_flow, -maxf(0.0, floors[i] - right_surface) / delta)
		flows[i] = new_flow
	# The lips: a spilling end drains toward its own floor's edge.
	if left_end == EndKind.SPILL and depths[0] > min_depth:
		spill_flow_left = maxf(0.0, spill_flow_left * damp
			+ stiffness_per_depth * minf(depths[0], max_wave_depth) * depths[0])
	else:
		spill_flow_left = 0.0
	var last: int = count - 1
	if right_end == EndKind.SPILL and depths[last] > min_depth:
		spill_flow_right = maxf(0.0, spill_flow_right * damp
			+ stiffness_per_depth * minf(depths[last], max_wave_depth) * depths[last])
	else:
		spill_flow_right = 0.0
	# 2. No column sends out more than it has: scale its outflows down if needed.
	# Each pipe flows OUT of exactly one column (the sign says which), so each is
	# scaled at most once, and both of its columns see the same flow: conservation.
	for i: int in count:
		var right_out: float = flows[i] if i < last and flows[i] > 0.0 else 0.0
		var left_out: float = -flows[i - 1] if i > 0 and flows[i - 1] < 0.0 else 0.0
		var lip_out: float = 0.0
		if i == 0:
			lip_out += spill_flow_left
		if i == last:
			lip_out += spill_flow_right
		var wanted: float = (right_out + left_out + lip_out) * delta
		if wanted <= depths[i] or wanted <= 0.0:
			continue
		var scale: float = depths[i] / wanted
		if right_out > 0.0:
			flows[i] *= scale
		if left_out > 0.0:
			flows[i - 1] *= scale
		if i == 0:
			spill_flow_left *= scale
		if i == last:
			spill_flow_right *= scale
	# 3. Move the water: what comes in from the left pipe minus what goes out the
	# right one (maxf: float crumbs only, the scaling above already keeps it >= 0).
	var incoming: float = 0.0
	for i: int in count:
		var outgoing: float = flows[i] if i < last else 0.0
		depths[i] = maxf(0.0, depths[i] + (incoming - outgoing) * delta)
		incoming = outgoing
	if spill_flow_left > 0.0:
		depths[0] = maxf(0.0, depths[0] - spill_flow_left * delta)
		spilled_left += spill_flow_left * delta * column_width
	if spill_flow_right > 0.0:
		depths[last] = maxf(0.0, depths[last] - spill_flow_right * delta)
		spilled_right += spill_flow_right * delta * column_width
	depth = depths
	flow = flows


## One step of the ripple springs (cosmetic), once per frame. Semi-implicit Euler:
## speed first, then position with the new speed, which stays stable for stiff
## springs (sqrt(stiffness + 4 × spread) × delta under about 1.5).
func step_ripples(delta: float, stiffness: float, damping: float, spread: float, max_height: float) -> void:
	var count: int = get_column_count()
	var offsets: PackedFloat32Array = ripple
	var speeds: PackedFloat32Array = ripple_speed
	var last: int = count - 1
	for i: int in count:
		var here: float = offsets[i]
		var left_ripple: float = offsets[i - 1] if i > 0 else here
		var right_ripple: float = offsets[i + 1] if i < last else here
		speeds[i] += (-stiffness * here - damping * speeds[i] + spread * (left_ripple + right_ripple - 2.0 * here)) * delta
	for i: int in count:
		offsets[i] = clampf(offsets[i] + speeds[i] * delta, -max_height, max_height)
	ripple = offsets
	ripple_speed = speeds


## True if nothing in it moves any more (WaterWorld then puts it to sleep).
func is_calm(max_flow: float, max_ripple: float) -> bool:
	if spill_flow_left > 0.0 or spill_flow_right > 0.0:
		return false
	for pipe_flow: float in flow:
		if absf(pipe_flow) > max_flow:
			return false
	for i: int in get_column_count():
		if absf(ripple[i]) > max_ripple or absf(ripple_speed[i]) > max_ripple * 10.0:
			return false
	return true


## Falls asleep: the last tiny motion is dropped, so it wakes up calm.
func fall_asleep() -> void:
	flow.fill(0.0)
	ripple.fill(0.0)
	ripple_speed.fill(0.0)
	is_asleep = true

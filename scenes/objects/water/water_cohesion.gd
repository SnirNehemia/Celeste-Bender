class_name WaterCohesion
extends RefCounted
## WaterCohesion (Stage W2, Water_bending.md §6.1 part 2): the one pass that makes
## loose water hold together. WaterWorld calls apply() once per physics frame on its
## particle arrays, before moving them. Nothing else uses it.
##
## Every pair of particles closer than `radius` is joined by a soft spring that
## wants them `rest` px apart (pulled together when further, pushed apart when
## closer), weaker toward the edge of the radius, plus a little viscosity: the pair
## evens out its speeds. That's all: no pressure solve, the expensive part of a
## real fluid simulation (§6.5). Enough for a thrown ball to stay round, a pour to
## bead into drops, and a stretched stream to thin and pinch off.
##
## SPEED (the main risk of the stage): finding neighbours. Instead of comparing every
## pair (400 particles = 80 000 pairs) it uses a SORTED SPATIAL HASH:
##   1. Each particle gets a key: its grid cell (cells `radius` px wide), shifted
##      left, with its own index in the low bits. One packed array of keys.
##   2. keys.sort() (native code, fast) puts particles of the same cell next to
##      each other, cells in row order.
##   3. A particle's neighbours are in the 3 x 3 cells around it. In row order the
##      three cells of one row are consecutive, so ONE binary search
##      (keys.bsearch, also native) per row finds them all: 3 searches per particle.
## Each pair is handled once (only partners with a higher index), and both get
## their share, so momentum is kept.

## Low bits of a key hold the particle's index: up to 4096 particles.
const INDEX_BITS: int = 12
const INDEX_MASK: int = (1 << INDEX_BITS) - 1


## Changes `velocities` in place (packed arrays are passed by reference) for one
## step of `delta` seconds. `grid_columns`: how many cells wide the room is, plus 3.
static func apply(positions: PackedVector2Array, velocities: PackedVector2Array, delta: float,
		radius: float, rest: float, stiffness: float, viscosity: float, repulsion: float,
		grid_columns: int) -> void:
	var count: int = positions.size()
	if count < 2 or count > INDEX_MASK:
		return
	var inverse_cell: float = 1.0 / radius
	var keys: PackedInt64Array = PackedInt64Array()
	keys.resize(count)
	var cell_rows: PackedInt32Array = PackedInt32Array()
	cell_rows.resize(count)
	var cell_columns: PackedInt32Array = PackedInt32Array()
	cell_columns.resize(count)
	for index: int in count:
		var position: Vector2 = positions[index]
		# +1: a particle in the first column still has a column to its left.
		var cell_column: int = int(maxf(position.x, 0.0) * inverse_cell) + 1
		var cell_row: int = int(maxf(position.y, 0.0) * inverse_cell) + 1
		cell_columns[index] = cell_column
		cell_rows[index] = cell_row
		keys[index] = ((cell_row * grid_columns + cell_column) << INDEX_BITS) | index
	keys.sort()
	var radius_squared: float = radius * radius
	var spring_step: float = stiffness * delta
	var viscosity_step: float = minf(viscosity * delta, 0.5)
	for index: int in count:
		var own_position: Vector2 = positions[index]
		var own_velocity: Vector2 = velocities[index]
		var cell_column: int = cell_columns[index]
		for row_offset: int in 3:
			var row_start: int = (cell_rows[index] - 1 + row_offset) * grid_columns
			var lowest_key: int = (row_start + cell_column - 1) << INDEX_BITS
			var past_key: int = (row_start + cell_column + 2) << INDEX_BITS
			var slot: int = keys.bsearch(lowest_key)
			while slot < count:
				var key: int = keys[slot]
				if key >= past_key:
					break
				slot += 1
				var other: int = key & INDEX_MASK
				if other <= index:
					continue  # each pair once, from its lower index
				var offset: Vector2 = positions[other] - own_position
				var distance_squared: float = offset.length_squared()
				if distance_squared >= radius_squared or distance_squared < 0.0001:
					continue
				var distance: float = sqrt(distance_squared)
				var closeness: float = 1.0 - distance / radius
				# The spring: positive pulls the two together, negative pushes apart.
				# Closer than `rest` it pushes `repulsion` times harder: otherwise
				# the many weak pulls of the far neighbours squeeze a ball far
				# smaller than its water (64 particles in a 3 px blob).
				var pull: float = spring_step * (distance - rest) * closeness
				if distance < rest:
					pull *= repulsion
				var other_velocity: Vector2 = velocities[other]
				var change: Vector2 = offset * (pull / distance) \
					+ (other_velocity - own_velocity) * (viscosity_step * closeness * 0.5)
				own_velocity += change
				velocities[other] = other_velocity - change
		velocities[index] = own_velocity

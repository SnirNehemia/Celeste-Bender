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
##   3. A particle's neighbours are in the 3 x 3 cells around it, but each pair only
##      needs finding ONCE, so a particle looks at HALF of them (the
##      "half-neighbourhood"): the particles after it in its own cell, the cell to
##      its right, and the three cells of the row below. Any pair is in exactly one
##      of those from one of its two particles. In sorted order the rest of its own
##      cell and the cell to its right come straight after it (no search at all),
##      and the three cells below are consecutive: ONE binary search
##      (keys.bsearch, also native) per particle.
##      (Was: all 9 cells with 3 searches, then half the pairs thrown away. The
##      half-neighbourhood visits about 40% as many entries, §6.5 perf pass.)
## Both particles of a pair get their share, so momentum is kept.

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
	# Walk the particles in sorted (cell) order: then "the rest of my cell and the
	# cell to my right" is simply the slots after mine.
	for own_slot: int in count:
		var index: int = keys[own_slot] & INDEX_MASK
		var own_position: Vector2 = positions[index]
		var own_velocity: Vector2 = velocities[index]
		var cell_column: int = cell_columns[index]
		var own_row_start: int = cell_rows[index] * grid_columns
		for part: int in 2:
			var slot: int
			var past_key: int
			if part == 0:
				# Own row: the slots after mine, up to the end of the cell to my right.
				slot = own_slot + 1
				past_key = (own_row_start + cell_column + 2) << INDEX_BITS
			else:
				# The row below: its three cells under mine, one search.
				var below_start: int = own_row_start + grid_columns
				slot = keys.bsearch((below_start + cell_column - 1) << INDEX_BITS)
				past_key = (below_start + cell_column + 2) << INDEX_BITS
			while slot < count:
				var key: int = keys[slot]
				if key >= past_key:
					break
				slot += 1
				var other: int = key & INDEX_MASK
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

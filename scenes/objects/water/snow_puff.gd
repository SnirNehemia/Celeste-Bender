class_name SnowPuff
extends Node2D
## SnowPuff (after Stage W7a, developer's idea): the freeze's third rule since it
## replaced the ice crystal. 2 with no water in your hands and no live throw makes a
## puff of SNOWFLAKES: they burst out to snow_puff_radius px around a center, the air
## stops them (snow_flake_drag), and they rain gently down (snow_fall_speed, swaying),
## melting away after snow_flake_life. Every flake freezes the FIRST water it touches:
##   - loose water of a THROW GROUP (an older throw still flying, or a slick): that
##     whole throw, as the freeze does for the last throw (a raft if it's resting on a
##     surface)
##   - other loose water (a waterfall, a spill, spray): the drops joined to it
##     (WaterWorld.take_loose_near): a waterfall becomes an ice column
##   - a pool, a puddle or a stream: an ice SHEET snow_pool_reach px each side of
##     where it lands (WaterWorld.freeze_body_at). Each flake makes its own stretch;
##     a flake landing on ice already there just melts. Black water doesn't freeze.
## Everything one puff freezes counts as ONE freeze for the ice cap (it shares one
## freeze id: WaterWorld.shared_freeze_id).
## A flake also melts when it touches anything solid (rock, painted ice, crates and
## blocks: physics layer 1) or player-made ice.
##
## Tapped, the puff bursts around the player; aimed (2 held, FreezeAbility through
## GustAim), it's TOSSED snow_toss_distance px along the aim first: every flake gets
## that extra speed, which the drag eats up, so the puff drifts there and stops.
##
## The flakes are plain data (packed arrays, positions in WORLD coordinates), not
## nodes: one node draws them all. Made only by SnowPuff.burst().

## Emitted each time a flake freezes something (`ice`: the new IceBlock or IcePiece).
signal froze(ice: Node)

## Physics layers that melt a flake: 1 "world" (rock, crates, ice blocks, painted ice).
const SOLID_MASK: int = 1
## A flake touches a loose drop this close, px.
const DROP_TOUCH: float = 3.0
## Pale frost and white (Water_bending.md §12.1).
const FLAKE_COLOR: Color = Color("#F2FAFF")
const FLAKE_DIM_COLOR: Color = Color("#BFE4FF")
## A flake fades out over its last this-many seconds.
const FADE_TIME: float = 0.5

var tuning: WaterTuning
var world: WaterWorld
## The freeze id every freeze of this puff shares (the ice cap counts one).
var freeze_id: int = -1
## Index i is one flake. `alive` 0 = melted (skipped, not drawn).
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var ages: PackedFloat32Array = PackedFloat32Array()
var phases: PackedFloat32Array = PackedFloat32Array()
var alive: PackedByteArray = PackedByteArray()
var alive_count: int = 0
## For tests: everything this puff froze.
var frozen: Array[Node] = []


## A puff around the WORLD point `center`, tossed by `toss` px (ZERO = no toss).
## It's added to the room of that point's WaterWorld (so the room's reset clears
## it), or to `parent` in a room without water. Returns it.
static func burst(parent: Node, center: Vector2, toss: Vector2, water_tuning: WaterTuning) -> SnowPuff:
	var puff: SnowPuff = SnowPuff.new()
	puff.name = "SnowPuff"
	puff.tuning = water_tuning
	puff.z_index = 40  # in front of the water, like the frost of the freeze
	puff.world = WaterWorld.find_at(parent.get_tree(), center)
	if puff.world != null:
		puff.freeze_id = puff.world.new_freeze_id()
	(puff.world.room if puff.world != null else parent).add_child(puff)
	puff.global_position = Vector2.ZERO  # it draws in world coordinates
	# Death or R: snow still falling would freeze the fresh water (Room.reset_objects).
	puff.add_to_group(Room.RESETTABLE_GROUP)
	puff._spawn_flakes(center, toss)
	return puff


## The flakes start at `center` with speeds that the drag turns into the distances
## wanted: a body slowed by `drag` per second from speed v travels v / drag. So each
## flake's speed is (its spot in the disc + the toss) x drag.
func _spawn_flakes(center: Vector2, toss: Vector2) -> void:
	var drag: float = maxf(tuning.snow_flake_drag, 0.1)
	for index: int in tuning.snow_flake_count:
		# Evenly spread over the disc (the sunflower packing), a little jittered.
		var spot: Vector2 = Vector2.from_angle(index * 2.39996 + randf_range(-0.3, 0.3)) \
			* tuning.snow_puff_radius * sqrt((index + 0.5) / tuning.snow_flake_count)
		positions.append(center)
		velocities.append((spot + toss) * drag)
		ages.append(0.0)
		phases.append(randf() * TAU)
		alive.append(1)
	alive_count = tuning.snow_flake_count


func _physics_process(delta: float) -> void:
	if alive_count <= 0:
		queue_free()
		return
	var keep: float = maxf(0.0, 1.0 - tuning.snow_flake_drag * delta)
	# The fall: a pull that the drag balances at snow_fall_speed.
	var fall_pull: float = tuning.snow_fall_speed * tuning.snow_flake_drag * delta
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var point_query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	point_query.collision_mask = SOLID_MASK
	for index: int in positions.size():
		if alive[index] == 0:
			continue
		var age: float = ages[index] + delta
		ages[index] = age
		if age >= tuning.snow_flake_life:
			_melt(index)
			continue
		var velocity: Vector2 = velocities[index] * keep
		velocity.y += fall_pull
		velocities[index] = velocity
		# The sway: side to side, on top of the velocity (it doesn't build up).
		var sway: float = sin(age * 3.0 + phases[index]) * tuning.snow_sway
		var position_now: Vector2 = positions[index] + (velocity + Vector2(sway, 0.0)) * delta
		positions[index] = position_now
		if world != null and _try_freeze_at(position_now):
			_melt(index)
			continue
		point_query.position = position_now
		if not space.intersect_point(point_query, 1).is_empty():
			_melt(index)  # landed on something solid: it melts
			continue
		if world != null and world.is_point_in_ice(world.to_local(position_now)):
			_melt(index)
	queue_redraw()


## Freezes the water at the WORLD point, if any (see the header). True = it touched
## water (froze it, or touched black water that can't freeze): the flake is spent.
func _try_freeze_at(point: Vector2) -> bool:
	var local: Vector2 = world.to_local(point)
	var group: int = world.find_drop_group_near(local, DROP_TOUCH)
	var ice: Node = null
	world.shared_freeze_id = freeze_id
	if group >= 0:
		var taken: Array = world.take_group_particles(group) if group > 0 \
			else world.take_loose_near(local, tuning.freeze_loose_reach, tuning.freeze_join_distance)
		if group > 0 and group == world.last_group_id:
			world.last_group_area = 0.0  # frozen: the last throw isn't live any more
		ice = world.freeze_particles(taken[0], taken[1], taken[2])
	elif not world.find_water_at(local).is_empty():
		ice = world.freeze_body_at(local, tuning.snow_pool_reach)
	else:
		world.shared_freeze_id = -1
		return false
	world.shared_freeze_id = -1
	if ice != null:
		frozen.append(ice)
		world.sparkle(local, 3)
		froze.emit(ice)
	return true


## The room resets (Room.RESETTABLE_GROUP): the snow still falling goes.
func reset() -> void:
	queue_free()


func _melt(index: int) -> void:
	alive[index] = 0
	alive_count -= 1


func _draw() -> void:
	for index: int in positions.size():
		if alive[index] == 0:
			continue
		var fade: float = clampf((tuning.snow_flake_life - ages[index]) / FADE_TIME, 0.0, 1.0)
		var center: Vector2 = positions[index].round()
		# Every third flake is a little cross, the rest single specks.
		draw_rect(Rect2(center, Vector2.ONE), Color(FLAKE_COLOR, fade))
		if index % 3 == 0:
			var arm_color: Color = Color(FLAKE_DIM_COLOR, fade * 0.7)
			for arm: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_rect(Rect2(center + arm, Vector2.ONE), arm_color)

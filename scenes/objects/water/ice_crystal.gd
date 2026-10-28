class_name IceCrystal
extends Node2D
## IceCrystal (Stage W5, the freeze's third rule): a thin shard of ice thrown by 2
## (FreezeAbility) when you hold no water and your last throw isn't live any more. It
## flies straight (no gravity) at crystal_speed for crystal_range px, and freezes the
## FIRST water it touches:
##   - loose water of a THROW GROUP (an older throw still flying): that whole throw,
##     like the freeze does for the last throw
##   - other loose water (a waterfall, a spill, spray): the drops joined to the hit
##     (WaterWorld.take_loose_near): a waterfall becomes an ice column
##   - a pool, a puddle or a stream: an ice SHEET over a stretch of its surface
##     (WaterWorld.freeze_body_at; a shallow stream freezes through: a dam)
## It shatters harmlessly on anything solid (physics layer 1: rock, crates, ice) or at
## the end of its range. Each step is cut into STEP px pieces so a fast crystal can't
## skip over a thin stream of drops.
##
## Made only by IceCrystal.launch() (FreezeAbility.throw_crystal). Positions are world
## coordinates; the room's WaterWorld converts them.

## Emitted when it froze something (`ice`: the new IceBlock or IcePiece), or hit
## nothing it could freeze (null) and shattered.
signal froze(ice: Node)
signal shattered

## Physics layers that stop it: 1 "world" (bit value).
const HIT_MASK: int = 1
## Longest piece of one physics step, px.
const STEP: float = 2.0
## It touches a loose drop this close, px.
const DROP_TOUCH: float = 3.0
## Pale cyan shard with a white core (Water_bending.md §7.3).
const SHARD_COLOR: Color = Color("#9FE6FF")
const CORE_COLOR: Color = Color.WHITE
## Trail points kept (one per physics frame).
const TRAIL_LENGTH: int = 4

var direction: Vector2 = Vector2.RIGHT
var tuning: WaterTuning
var world: WaterWorld
var flown: float = 0.0
var trail: PackedVector2Array = PackedVector2Array()
var is_done: bool = false


## Throws a crystal from the WORLD point `start` along `throw_direction` (normalized),
## as a child of `parent`. Returns it.
static func launch(parent: Node, start: Vector2, throw_direction: Vector2, water_tuning: WaterTuning) -> IceCrystal:
	var crystal: IceCrystal = IceCrystal.new()
	crystal.name = "IceCrystal"
	crystal.direction = throw_direction.normalized()
	crystal.tuning = water_tuning
	crystal.z_index = 40
	parent.add_child(crystal)
	crystal.global_position = start
	crystal.world = WaterWorld.find_at(crystal.get_tree(), start)
	return crystal


func _physics_process(delta: float) -> void:
	if is_done:
		return
	trail.insert(0, global_position)
	if trail.size() > TRAIL_LENGTH:
		trail.resize(TRAIL_LENGTH)
	var travel: float = tuning.crystal_speed * delta
	var pieces: int = maxi(1, ceili(travel / STEP))
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for piece: int in pieces:
		var next: Vector2 = global_position + direction * (travel / pieces)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, next, HIT_MASK)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit["position"]
			_finish(null)
			return
		flown += global_position.distance_to(next)
		global_position = next
		if _try_freeze_here():
			return
		if flown >= tuning.crystal_range:
			_finish(null)
			return
	queue_redraw()


## Freezes the water where the crystal is now, if any. True = it hit water (and is
## done).
func _try_freeze_here() -> bool:
	if world == null:
		return false
	var point: Vector2 = world.to_local(global_position)
	var group: int = world.find_drop_group_near(point, DROP_TOUCH, get_physics_process_delta_time())
	if group >= 0:
		var taken: Array = world.take_group_particles(group) if group > 0 \
			else world.take_loose_near(point, tuning.freeze_loose_reach, tuning.freeze_join_distance)
		if group > 0 and group == world.last_group_id:
			world.last_group_area = 0.0  # frozen: the last throw isn't live any more
		_finish(world.freeze_particles(taken[0], taken[1], taken[2]))
		return true
	if not world.find_water_at(point).is_empty():
		_finish(world.freeze_body_at(point))
		return true
	return false


## Done: a frost burst where it ended, the signal, and it goes away.
func _finish(ice: Node) -> void:
	is_done = true
	if world != null:
		world.sparkle(world.to_local(global_position), 6 if ice != null else 3)
	if ice != null:
		froze.emit(ice)
	else:
		shattered.emit()
	queue_free()


func _draw() -> void:
	# A thin diamond along the flight, a white core, and a short fading trail.
	var tip: Vector2 = direction * 3.0
	var side: Vector2 = direction.orthogonal() * 1.0
	draw_colored_polygon(PackedVector2Array([tip, side, -tip, -side]), SHARD_COLOR)
	draw_rect(Rect2(Vector2(-0.5, -0.5), Vector2.ONE), CORE_COLOR)
	for index: int in range(1, trail.size()):
		var trail_point: Vector2 = to_local(trail[index])
		draw_rect(Rect2(trail_point.round(), Vector2.ONE), Color(SHARD_COLOR, 0.6 - index * 0.15))

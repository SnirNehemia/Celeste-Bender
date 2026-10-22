class_name PebbleField
extends Node2D
## Pebble field (Stage E4d): the small stones that earth bending leaves lying around.
## One per room with an Earth layer, made by Room._ready() (like the GroundPainter).
##
## Where pebbles come from (EarthTuning > Pebbles):
##   - bends that USE ground call leave_pebbles_for_tiles(): pebbles per tile used,
##     so the more earth a bend spends, the more it leaves (a column or small rock:
##     1 tile, a big rock: 4)
##   - FX.spawn_gravel(), the helper every other earth effect uses (impacts,
##     shatters, the shadow's path), calls leave_pebbles() for a few per gravel bit
## Both find the field of the room the point is in. The gravel bits still fade away;
## the pebbles STAY.
##
## What moves them (the same ideas as the leaf pile, scenes/objects/leaf_pile.gd):
##   - the player, crates and wisps walking or landing on them kick them up
##   - a gust (or dash wake) blows the ones near its origin (the Pushable contract)
##   - a wind zone pulls them along: a sideways current rolls them over the floor
## Unlike leaves, pebbles are stones: they fall fast, bounce a little, and roll to a
## stop on the ground. A resting pebble falls again when the ground under it goes (a
## torn tile, an opened door) and pops out if something solid moves onto it (a rock
## sticking into the wall, a rising pillar).
##
## Like the leaf pile, this is ONE node keeping arrays (position, velocity... per
## pebble), moving them with its own tiny simulation (point queries ask the physics
## world "is this point solid?") and drawing them all in one _draw().
## Only the room the player is in simulates; the others keep their pebbles frozen.
## Capped per room (oldest go first); a room reset (death / R) clears them all.
##
## Physics: a sensor Area2D covering the whole room, on layer 4 ("pushable") so gusts
## find it, looking at layers 1, 2 and 5 to notice crates, the player and wisps.
##
## ASH FLAKES (after the F6 play-test): the field also holds light gray flakes that
## fire leaves behind (leave_ash: burnt grass, crumbled thicket). Same arrays, flagged
## in pebble_is_ash, with their own cap (FireTuning.ash_max_per_room). They follow
## other rules than stones (_apply_ash_forces): light gravity and strong air drag, so
## they drift down slowly with a flutter; they take on the wind's speed in every
## direction (an updraft lifts them); anything moving within ash_kick_reach of them
## stirs them, in the air too; gusts blow them further; they never bounce.

## Every field joins this group, so leave_pebbles() can find the right one.
const GROUP: StringName = &"pebble_fields"
## Gravel's directions are fanned out by this much (±, radians), like FX's 40°.
const SPAWN_SPREAD: float = deg_to_rad(40.0)
## A buried pebble looks this far (px) for a free spot: up, left or right.
const MAX_UNBURY_DISTANCE: int = 16
const UNBURY_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
## Below this speed (px/s) a pebble on the ground stops simulating: it's resting.
const REST_SPEED: float = 3.0
## Bumping a wall sideways, a pebble bounces back with this share of its speed.
const WALL_BOUNCE: float = 0.3
## Kicks only reach pebbles this far above (negative) / below a body's feet, px.
const KICK_REACH_ABOVE: float = 10.0
const KICK_REACH_BELOW: float = 2.0
## Pebbles that fall this far below the room (a pit) are dropped.
const LOST_DISTANCE: float = 64.0
## Pebble colors: fresh earth to dark used earth, plus a stony gray-brown.
const STONE_COLOR: Color = Color(0.45, 0.4, 0.36)
## "No color given: pick an earth one" (fully transparent black, never a real pebble).
const PICK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)

## Feel values. preload() returns the same resource the player holds, so Remote-tab
## edits reach the pebbles too.
var earth_tuning: EarthTuning = preload("res://resources/earth_tuning.tres")
## Ash flake values (the fire's tuning).
var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")

## Per-pebble state, in this node's local coordinates (= the room's). Index i =
## pebble i; index 0 is the oldest, so the cap removes from the front.
## A pebble's position is its BOTTOM-CENTER: the point that rests on the ground.
var pebble_positions: PackedVector2Array = PackedVector2Array()
var pebble_velocities: PackedVector2Array = PackedVector2Array()
## 1 = moving (simulated every frame), 0 = resting (only checked now and then).
var pebble_is_moving: PackedByteArray = PackedByteArray()
## 1 = touching the ground (rolls, can be kicked), 0 = in the air.
var pebble_is_grounded: PackedByteArray = PackedByteArray()
## Size in px (1x1, 2x1 or 2x2) and color, picked when the pebble is made.
var pebble_sizes: PackedVector2Array = PackedVector2Array()
var pebble_colors: PackedColorArray = PackedColorArray()
## 1 = an ash flake (see the header), 0 = a stone. And each one's flutter phase.
var pebble_is_ash: PackedByteArray = PackedByteArray()
var pebble_phases: PackedFloat32Array = PackedFloat32Array()
## How many of the pebbles are ash flakes (for the two caps).
var ash_count: int = 0
## Seconds this field has simulated, for the flakes' flutter.
var flutter_clock: float = 0.0

## The room we belong to (our parent), for its bounds and "is it the current room?".
var room: Room
## The wind zones overlapping our room, found once in _ready().
var room_wind_zones: Array[WindZone] = []
## Randomness for spawns and kicks.
var pebble_random: RandomNumberGenerator = RandomNumberGenerator.new()
## Reused for every "is this point solid?" question (saves allocating one per pebble).
var point_query: PhysicsPointQueryParameters2D
var sensor: Area2D


func _ready() -> void:
	room = get_parent() as Room
	z_index = 1  # in front of the ground and the player's feet, like grass and leaves
	sensor = Area2D.new()
	sensor.collision_layer = 8  # bit value of layer 4, "pushable"
	sensor.collision_mask = 1 | 2 | 16  # crates ("world"), the player, wisps ("enemies")
	var sensor_shape_node: CollisionShape2D = CollisionShape2D.new()
	var sensor_rectangle: RectangleShape2D = RectangleShape2D.new()
	sensor_rectangle.size = room.room_size
	sensor_shape_node.shape = sensor_rectangle
	sensor_shape_node.position = room.room_size / 2.0  # shapes are placed by their center
	sensor.add_child(sensor_shape_node)
	add_child(sensor)
	point_query = PhysicsPointQueryParameters2D.new()
	point_query.collision_mask = 1  # rest on "world": ground, crates, doors, rocks
	point_query.collide_with_areas = false
	pebble_random.randomize()
	add_to_group(GROUP)
	add_to_group(Pushable.GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	# Wind zones are placed with the room and never move, so look them up once.
	# Deferred: zones further down the tree join their group in their own _ready().
	_find_room_wind_zones.call_deferred()


## Adds the pebbles a gravel burst of `gravel_amount` bits leaves behind:
## gravel × pebbles_per_gravel × `pebble_fraction` (the shadow's path leaves only a
## few). Called by FX.spawn_gravel().
## Static: called on the class (PebbleField.leave_pebbles(...)), no field reference needed.
static func leave_pebbles(tree: SceneTree, world_position: Vector2, gravel_amount: int,
		direction: Vector2, pebble_fraction: float) -> void:
	var field: PebbleField = _find_field(tree, world_position)
	if field != null:
		field.add_pebbles(world_position,
			gravel_amount * field.earth_tuning.pebbles_per_gravel * pebble_fraction, direction)


## Adds the pebbles a bend leaves for using `tile_count` tiles of ground:
## tile_count × pebbles_per_used_tile, thrown out of `world_position` along `direction`.
static func leave_pebbles_for_tiles(tree: SceneTree, world_position: Vector2, tile_count: int,
		direction: Vector2) -> void:
	var field: PebbleField = _find_field(tree, world_position)
	if field != null:
		field.add_pebbles(world_position, tile_count * field.earth_tuning.pebbles_per_used_tile, direction)


## Exactly ONE pebble at `world_position`, thrown toward `direction` (Stage E4e: a
## flying rock shedding a chip, a rising pillar crumbling).
static func leave_one_pebble(tree: SceneTree, world_position: Vector2, direction: Vector2) -> void:
	var field: PebbleField = _find_field(tree, world_position)
	if field != null:
		field.add_pebble(world_position, direction)


## `count` pebbles at `world_position`, thrown toward `direction`, each a random pick
## from `colors` (Stage E6: a cracked wall crumbles into gray stone, not earth).
static func leave_colored_pebbles(tree: SceneTree, world_position: Vector2, count: int,
		direction: Vector2, colors: Array[Color]) -> void:
	var field: PebbleField = _find_field(tree, world_position)
	if field == null or colors.is_empty():
		return
	for pebble_number: int in count:
		field.add_pebble(world_position, direction, colors[field.pebble_random.randi() % colors.size()])


## `count` ash flakes (see the header) scattered over `area` px centered on
## `world_position`, drifting off with a little speed. `colors`: picked at random.
static func leave_ash(tree: SceneTree, world_position: Vector2, count: int, area: Vector2,
		colors: Array[Color]) -> void:
	var field: PebbleField = _find_field(tree, world_position)
	if field == null or colors.is_empty():
		return
	for flake_number: int in count:
		var spot: Vector2 = world_position + Vector2(field.pebble_random.randf_range(-0.5, 0.5) * area.x,
			field.pebble_random.randf_range(-0.5, 0.5) * area.y)
		var drift: Vector2 = Vector2(field.pebble_random.randf_range(-12.0, 12.0), field.pebble_random.randf_range(-15.0, 5.0))
		field.add_ash_flake(spot, drift, colors[field.pebble_random.randi() % colors.size()])


## The field of the room containing `world_position`, or null (no Earth room there).
static func _find_field(tree: SceneTree, world_position: Vector2) -> PebbleField:
	for member: Node in tree.get_nodes_in_group(GROUP):
		var field: PebbleField = member as PebbleField
		if field != null and field.room.get_bounds().has_point(world_position):
			return field
	return null


## About `expected_count` pebbles: the part after the decimal point is rolled as a
## chance (2.4 = 2 pebbles, 40% chance of a 3rd), so even a 1-bit gravel burst
## sometimes leaves a pebble.
func add_pebbles(world_position: Vector2, expected_count: float, direction: Vector2) -> void:
	var pebble_count: int = int(expected_count)
	if pebble_random.randf() < expected_count - pebble_count:
		pebble_count += 1
	for pebble_number: int in pebble_count:
		add_pebble(world_position, direction)


## One new pebble at `world_position`, thrown out toward `direction` (±40°); ZERO =
## any upward direction. It spawns moving and lands wherever it falls.
## `color`: the pebble's color, or PICK_COLOR (the default) for an earth color.
func add_pebble(world_position: Vector2, direction: Vector2, color: Color = PICK_COLOR) -> void:
	# Over the cap: the oldest stone goes first.
	while pebble_positions.size() - ash_count >= earth_tuning.pebble_max_per_room:
		_remove_oldest(false)
	var throw_direction: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.UP
	var spread: float = SPAWN_SPREAD if direction != Vector2.ZERO else PI / 2.0
	throw_direction = throw_direction.rotated(pebble_random.randf_range(-spread, spread))
	var speed: float = pebble_random.randf_range(earth_tuning.pebble_spawn_speed_min,
		earth_tuning.pebble_spawn_speed_max)
	# Gravel is often made right ON a surface (an impact point, a tile face): start
	# 2 px out along the direction, so most pebbles begin in open air. Any that are
	# still inside a solid pop out on their first step (_unbury_pebble).
	_append_pebble(to_local(world_position) + throw_direction * 2.0, throw_direction * speed,
		_pick_pebble_size(), _pick_pebble_color() if color == PICK_COLOR else color, false)


## One ash flake at `world_position` with `start_velocity` (see the header). Over the
## ash cap, the oldest flake goes first. Mostly single pixels, a few 2x1.
func add_ash_flake(world_position: Vector2, start_velocity: Vector2, color: Color) -> void:
	if fire_tuning.ash_max_per_room <= 0:
		return
	while ash_count >= fire_tuning.ash_max_per_room:
		_remove_oldest(true)
	var flake_size: Vector2 = Vector2(2, 1) if pebble_random.randf() < 0.3 else Vector2(1, 1)
	_append_pebble(to_local(world_position), start_velocity, flake_size, color, true)


## Adds one moving pebble or flake to every per-pebble array (same index in each).
func _append_pebble(local_position: Vector2, start_velocity: Vector2, pebble_size: Vector2, color: Color,
		is_ash: bool) -> void:
	pebble_positions.append(local_position)
	pebble_velocities.append(start_velocity)
	pebble_is_moving.append(1)
	pebble_is_grounded.append(0)
	pebble_sizes.append(pebble_size)
	pebble_colors.append(color)
	pebble_is_ash.append(1 if is_ash else 0)
	pebble_phases.append(pebble_random.randf() * TAU)
	if is_ash:
		ash_count += 1
	queue_redraw()


## Removes the oldest ash flake (`is_ash`) or the oldest stone.
func _remove_oldest(is_ash: bool) -> void:
	var wanted: int = 1 if is_ash else 0
	for pebble_index: int in pebble_positions.size():
		if pebble_is_ash[pebble_index] == wanted:
			_remove_pebble(pebble_index)
			return


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	pebble_positions.clear()
	pebble_velocities.clear()
	pebble_is_moving.clear()
	pebble_is_grounded.clear()
	pebble_sizes.clear()
	pebble_colors.clear()
	pebble_is_ash.clear()
	pebble_phases.clear()
	ash_count = 0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if pebble_positions.is_empty() or not _is_current_room():
		return
	flutter_clock += delta
	var any_changed: bool = _kick_from_moving_bodies()
	if _check_resting_pebbles():
		any_changed = true
	# Backwards, so removing a lost pebble doesn't skip the next one.
	for pebble_index: int in range(pebble_positions.size() - 1, -1, -1):
		if pebble_is_moving[pebble_index] == 1:
			any_changed = true
			_move_pebble(pebble_index, delta)
	if any_changed:
		queue_redraw()


## The Pushable contract (fallback when the gust's origin is unknown). Without an
## origin we can't tell which pebbles are near, so blow none: every gust in the game
## passes its origin, this only exists to satisfy the contract.
func receive_gust(_direction: Vector2, _strength: float) -> void:
	pass


## The Pushable contract, with the gust's origin: pebbles within pebble_gust_reach are
## blown, harder the closer they are, fanned out a little (same as the leaf pile).
func receive_gust_from(direction: Vector2, strength: float, source_position: Vector2) -> void:
	if not source_position.is_finite():
		return
	# The all-around (neutral) gust hands each object "away from the player, toward
	# YOUR origin" (AirBlast.push_around). Our origin is the room's corner, which
	# means nothing here, so then blow each pebble straight away from the player.
	var is_all_around: bool = global_position != source_position \
		and direction.is_equal_approx((global_position - source_position).normalized())
	var reach: float = earth_tuning.pebble_gust_reach
	for pebble_index: int in pebble_positions.size():
		var from_source: Vector2 = to_global(pebble_positions[pebble_index]) - source_position
		var distance: float = from_source.length()
		if distance > reach:
			continue
		var outward: Vector2 = from_source / distance if distance > 0.01 else direction
		var push_direction: Vector2 = outward
		if not is_all_around:
			if outward.dot(direction) < -0.2:
				continue  # behind an aimed gust
			push_direction = (direction * 0.6 + outward * 0.4).normalized()
		var falloff: float = 1.0 - 0.5 * distance / reach
		var launch_speed: float = strength * earth_tuning.pebble_gust_strength_scale \
			* falloff * pebble_random.randf_range(0.5, 1.0)
		if pebble_is_ash[pebble_index] == 1:
			launch_speed *= fire_tuning.ash_gust_strength_scale  # light: it flies
		# Plus a small hop: air gets under a stone lying on the floor, so it doesn't
		# just scrape along the ground.
		_launch_pebble(pebble_index, push_direction * launch_speed
			+ Vector2(0.0, -pebble_random.randf_range(30.0, 60.0)))


## One moving pebble, one physics step. X and Y are moved separately, so a pebble
## hitting the floor still slides sideways and one hitting a wall still falls.
func _move_pebble(pebble_index: int, delta: float) -> void:
	if _unbury_pebble(pebble_index):
		return
	var tuning: EarthTuning = earth_tuning
	var position_now: Vector2 = pebble_positions[pebble_index]
	var velocity: Vector2 = pebble_velocities[pebble_index]
	var wind: Vector2 = _get_wind_at(position_now)
	var is_on_ground: bool = _is_solid(position_now + Vector2.DOWN)
	var is_ash: bool = pebble_is_ash[pebble_index] == 1
	var motion: Vector2 = Vector2.ZERO

	if is_ash:
		velocity = _apply_ash_forces(velocity, wind, is_on_ground, delta)
		if not is_on_ground:
			# Flutter: a sideways sway on top of the velocity (it doesn't build up).
			motion.x = sin(flutter_clock * 5.0 + pebble_phases[pebble_index]) * fire_tuning.ash_flutter_speed * delta
	else:
		# Wind: pull the sideways speed toward the (scaled) wind speed. Vertical wind
		# only pushes a little (it can't lift a stone, but an updraft slows its fall).
		var wind_target: Vector2 = wind * tuning.pebble_wind_speed_scale
		if wind.x != 0.0:
			velocity.x = lerpf(velocity.x, wind_target.x, minf(tuning.pebble_wind_grip * delta, 1.0))
		velocity.y += wind_target.y * tuning.pebble_wind_grip * delta

		if is_on_ground and velocity.y >= 0.0:
			# Rolling on the floor: no falling, friction slows it (exponential decay)
			# down to the wind's speed (0 without wind), so a current keeps it rolling.
			velocity.y = 0.0
			velocity.x = wind_target.x + (velocity.x - wind_target.x) * exp(-tuning.pebble_ground_friction * delta)
		else:
			velocity.y += tuning.pebble_gravity * delta

	motion += velocity * delta
	if motion.x != 0.0:
		var position_sideways: Vector2 = position_now + Vector2(motion.x, 0.0)
		if _is_solid(position_sideways):
			velocity.x *= -WALL_BOUNCE
		else:
			position_now = position_sideways
	if motion.y != 0.0:
		var position_vertical: Vector2 = position_now + Vector2(0.0, motion.y)
		if not _is_solid(position_vertical):
			position_now = position_vertical
		elif motion.y > 0.0:
			# Landed: step down whole pixels until the next one is solid, so the
			# pebble rests right on the surface instead of hovering above it.
			for step: int in ceili(motion.y):
				if _is_solid(position_now + Vector2.DOWN):
					break
				position_now.y += 1.0
			# Half a pixel into its last free pixel: a stable spot to re-check from.
			position_now.y = floorf(position_now.y) + 0.5
			velocity.y = 0.0 if is_ash else -velocity.y * tuning.pebble_bounce  # flakes never bounce
			if -velocity.y < tuning.pebble_settle_speed:
				velocity.y = 0.0
		else:
			velocity.y = 0.0  # hit a ceiling

	var is_grounded_now: bool = velocity.y == 0.0 and _is_solid(position_now + Vector2.DOWN)
	if is_grounded_now:
		# Same half-pixel spot however it got onto the ground (a landing, or a slow
		# fall that ended within a pixel of the floor).
		position_now.y = floorf(position_now.y) + 0.5
	pebble_positions[pebble_index] = position_now
	pebble_velocities[pebble_index] = velocity
	pebble_is_grounded[pebble_index] = 1 if is_grounded_now else 0
	# Stopped on the ground, and no wind to roll it on (or lift a flake): it rests.
	if is_grounded_now and absf(velocity.x) < REST_SPEED and wind.x == 0.0 and not (is_ash and wind.y < 0.0):
		pebble_velocities[pebble_index] = Vector2.ZERO
		pebble_is_moving[pebble_index] = 0
	elif position_now.y > room.room_size.y + LOST_DISTANCE:
		_remove_pebble(pebble_index)  # fell into a pit


## The forces on an ash flake for one step (see the header): on the ground it slides
## to a stop (or with the wind), and an updraft lifts it off; in the air it takes on
## the air's speed (air drag toward the wind, still air = 0) while light gravity
## pulls, so it falls at about ash_gravity / ash_air_drag px/s.
func _apply_ash_forces(velocity: Vector2, wind: Vector2, is_on_ground: bool, delta: float) -> Vector2:
	var air: Vector2 = wind * fire_tuning.ash_wind_speed_scale
	if is_on_ground and velocity.y >= 0.0:
		velocity.x = air.x + (velocity.x - air.x) * exp(-fire_tuning.ash_ground_friction * delta)
		velocity.y = minf(air.y, 0.0)  # an updraft lifts it off the floor
		return velocity
	velocity += (air - velocity) * minf(fire_tuning.ash_air_drag * delta, 1.0)
	velocity.y += fire_tuning.ash_gravity * delta
	return velocity


## Resting pebbles are checked every 4th frame (each on a different frame, so the
## work is spread out): did the ground go from under it, did something solid move
## onto it, did it end up in a sideways wind? Returns true if any woke up.
func _check_resting_pebbles() -> bool:
	var any_woke: bool = false
	var check_slot: int = Engine.get_physics_frames() % 4
	for pebble_index: int in pebble_positions.size():
		if pebble_is_moving[pebble_index] == 1 or pebble_index % 4 != check_slot:
			continue
		var resting_position: Vector2 = pebble_positions[pebble_index]
		# Buried (a rock stuck into the wall over it) or nothing underneath (a torn
		# tile): wake it, and _move_pebble pops it out or lets it fall.
		var wind: Vector2 = _get_wind_at(resting_position)
		var lifts_ash: bool = pebble_is_ash[pebble_index] == 1 and wind.y < 0.0  # an updraft
		if _is_solid(resting_position) or not _is_solid(resting_position + Vector2.DOWN) \
				or wind.x != 0.0 or lifts_ash:
			_launch_pebble(pebble_index, Vector2.ZERO)
			pebble_is_grounded[pebble_index] = 0
			any_woke = true
	return any_woke


## If the pebble is inside something solid, moves it to the nearest free spot (up,
## left or right, 1 px at a time) with a small push out. Returns true if it was buried.
func _unbury_pebble(pebble_index: int) -> bool:
	var buried_position: Vector2 = pebble_positions[pebble_index]
	if not _is_solid(buried_position):
		return false
	for step: int in range(1, MAX_UNBURY_DISTANCE + 1):
		for exit_direction: Vector2 in UNBURY_DIRECTIONS:
			var candidate: Vector2 = buried_position + exit_direction * step
			if not _is_solid(candidate):
				pebble_positions[pebble_index] = candidate
				pebble_velocities[pebble_index] = exit_direction * 20.0
				pebble_is_grounded[pebble_index] = 0
				return true
	# Deep inside a big solid: nothing sensible to do, so it just disappears.
	_remove_pebble(pebble_index)
	return true


## Players, crates and wisps moving over pebbles kick up the ones at their feet.
## Returns true if any pebble was kicked.
func _kick_from_moving_bodies() -> bool:
	var tuning: EarthTuning = earth_tuning
	var any_kicked: bool = false
	for body: Node2D in sensor.get_overlapping_bodies():
		# Only things that move by script; the room's own ground never kicks.
		var mover: CharacterBody2D = body as CharacterBody2D
		if mover == null or mover.velocity.length() < tuning.pebble_kick_min_speed:
			continue
		# The player, crates and wisps all have their origin at the bottom-center.
		var feet: Vector2 = to_local(mover.global_position)
		var half_width: float = _get_body_half_width(mover) + 1.0
		if ash_count > 0:
			_stir_ash(mover, feet, half_width)
		for pebble_index: int in pebble_positions.size():
			if pebble_is_ash[pebble_index] == 1:
				continue  # flakes were stirred above
			# Only pebbles on the ground: one already kicked into the air would get
			# kicked again every frame while it's still by the feet.
			if pebble_is_moving[pebble_index] == 1 and pebble_is_grounded[pebble_index] == 0:
				continue
			var offset: Vector2 = pebble_positions[pebble_index] - feet
			if absf(offset.x) > half_width or offset.y < -KICK_REACH_ABOVE or offset.y > KICK_REACH_BELOW:
				continue
			# Sideways: carried along with the kicker. Standing still and landing (all
			# vertical speed): sprayed out to either side, away from the feet.
			var kick_x: float = mover.velocity.x * pebble_random.randf_range(
				tuning.pebble_kick_carry_min, tuning.pebble_kick_carry_max)
			if absf(mover.velocity.x) < tuning.pebble_kick_min_speed:
				kick_x += signf(offset.x if offset.x != 0.0 else pebble_random.randf() - 0.5) \
					* pebble_random.randf_range(20.0, 50.0)
			_launch_pebble(pebble_index, Vector2(kick_x, -pebble_random.randf_range(
				tuning.pebble_kick_up_speed_min, tuning.pebble_kick_up_speed_max)))
			any_kicked = true
	return any_kicked


## Ash flakes near a moving body swirl: any flake (on the ground or in the air) within
## ash_kick_reach px of its box is pulled toward ash_kick_carry of the body's speed and
## pushed away from its middle; ones on the ground are lifted too. Pulled, not set,
## so a flake by the body every frame drifts along instead of shooting off.
func _stir_ash(mover: CharacterBody2D, feet: Vector2, half_width: float) -> void:
	var reach: float = fire_tuning.ash_kick_reach
	var body_height: float = 12.0  # about the player's 11 px; crates and wisps are close
	var stir_area: Rect2 = Rect2(feet.x - half_width - reach, feet.y - body_height - reach,
		(half_width + reach) * 2.0, body_height + reach + KICK_REACH_BELOW)
	var middle: Vector2 = feet + Vector2(0.0, -body_height / 2.0)
	var carried: Vector2 = mover.velocity * fire_tuning.ash_kick_carry
	for pebble_index: int in pebble_positions.size():
		if pebble_is_ash[pebble_index] == 0:
			continue
		var flake: Vector2 = pebble_positions[pebble_index]
		if not stir_area.has_point(flake):
			continue
		var away: Vector2 = (flake - middle).normalized() * 20.0
		var velocity: Vector2 = pebble_velocities[pebble_index].lerp(carried + away, 0.25)
		if pebble_is_grounded[pebble_index] == 1:
			velocity.y = -fire_tuning.ash_kick_up_speed * pebble_random.randf_range(0.5, 1.5)
		_launch_pebble(pebble_index, velocity)


func _launch_pebble(pebble_index: int, launch_velocity: Vector2) -> void:
	pebble_is_moving[pebble_index] = 1
	pebble_is_grounded[pebble_index] = 0
	pebble_velocities[pebble_index] = launch_velocity


func _remove_pebble(pebble_index: int) -> void:
	if pebble_is_ash[pebble_index] == 1:
		ash_count -= 1
	pebble_is_ash.remove_at(pebble_index)
	pebble_phases.remove_at(pebble_index)
	pebble_positions.remove_at(pebble_index)
	pebble_velocities.remove_at(pebble_index)
	pebble_is_moving.remove_at(pebble_index)
	pebble_is_grounded.remove_at(pebble_index)
	pebble_sizes.remove_at(pebble_index)
	pebble_colors.remove_at(pebble_index)
	queue_redraw()


## True while the player is in our room. Outside a world (a test scene with no room
## tracking) GameState.current_room is null: then always simulate.
func _is_current_room() -> bool:
	return GameState.current_room == null or GameState.current_room == room


func _find_room_wind_zones() -> void:
	for member: Node in get_tree().get_nodes_in_group(WindZone.GROUP):
		var zone: WindZone = member as WindZone
		if zone != null and Rect2(zone.global_position, zone.zone_size).intersects(room.get_bounds()):
			room_wind_zones.append(zone)


## The wind at a pebble's position (local), px/s: the sum of every zone it's in.
func _get_wind_at(local_point: Vector2) -> Vector2:
	var wind: Vector2 = Vector2.ZERO
	if room_wind_zones.is_empty():
		return wind
	# The pebble's bottom-center sits on the floor; test 1 px higher, so a zone that
	# ends exactly at floor level still holds the pebbles lying on that floor.
	var world_point: Vector2 = to_global(local_point + Vector2.UP)
	for zone: WindZone in room_wind_zones:
		if zone.contains_point(world_point):
			wind += zone.get_wind_velocity()
	return wind


## Half the width of a body's first rectangle collision shape (4 px fallback).
func _get_body_half_width(body: CharacterBody2D) -> float:
	for child: Node in body.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			return (shape_node.shape as RectangleShape2D).size.x / 2.0
	return 4.0


## "Is this point (local coordinates) inside something solid?", asked of the physics world.
func _is_solid(local_point: Vector2) -> bool:
	point_query.position = to_global(local_point)
	return not get_world_2d().direct_space_state.intersect_point(point_query, 1).is_empty()


## Mostly single pixels, some 2x1 chips, a few 2x2 stones.
func _pick_pebble_size() -> Vector2:
	var roll: float = pebble_random.randf()
	if roll < 0.5:
		return Vector2(1, 1)
	if roll < 0.85:
		return Vector2(2, 1)
	return Vector2(2, 2)


## Somewhere between fresh and dark used earth; now and then a gray stone.
func _pick_pebble_color() -> Color:
	if pebble_random.randf() < 0.2:
		return STONE_COLOR
	return EarthLayer.FRESH_COLOR.lerp(EarthLayer.USED_COLOR, pebble_random.randf_range(0.15, 0.7))


func _draw() -> void:
	for pebble_index: int in pebble_positions.size():
		var pebble_size: Vector2 = pebble_sizes[pebble_index]
		var bottom_center: Vector2 = pebble_positions[pebble_index]
		# Snapped to whole pixels, bottom row on the pebble's own pixel row (so a
		# resting pebble sits right on the ground, pixel art stays crisp).
		var top_left: Vector2 = Vector2(floorf(bottom_center.x - pebble_size.x / 2.0 + 0.5),
			floorf(bottom_center.y) + 1.0 - pebble_size.y)
		draw_rect(Rect2(top_left, pebble_size), pebble_colors[pebble_index])

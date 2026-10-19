class_name Boulder
extends CharacterBody2D
## Boulder (Earth_bending.md §6, §11, Stages E4 + E4a): since E4a an 8x8 ROCK torn
## out of one earth tile (which becomes a hole), popped out, and thrown. Small: a
## ranged attack, or a one-tile step stuck into a far earth wall.
## (All sizes come from earth_tuning.boulder_size, so the code works for any size.)
##
## Phases (`phase`):
##   POPPING  the time between the tear and the throw (the player can throw it all
##            through this phase). Three steps, all in game time:
##              1. TEAR: starts inside the hole it was torn from and rumbles slowly
##                 out of it, one tile along the surface's normal (boulder_tear_time)
##              2. HOP: jumps up boulder_hop_height (its bottom ends above the
##                 player's head) and drifts AWAY from the player (from a wall: away
##                 from the wall, faster), under gravity
##              3. lands with a thud and RESTS for boulder_land_rest_time, then
##                 crumbles. (Hits a wall on the way: slides down it.)
##            PERFECT WINDOW: the moment the rock's middle comes back DOWN level
##            with the player's middle (± boulder_perfect_window; on the way up it
##            doesn't count, changed after the E4a play-test). Worked out in advance
##            from the hop's math (get_perfect_time); the player is rooted, so it holds.
##            The rest after landing is what keeps the way-down window open: a floor
##            rock lands almost exactly at the player's middle height.
##            Never thrown = it crumbles after the rest, or when boulder_hold_time
##            runs out. A rock the player let go of (drop()) shatters when it lands.
##   FLYING   thrown. Flies straight for float_time_remaining (no gravity), then falls.
##            On impact:
##              - an EARTH face (the "Earth" layer, fresh or used): STUCK
##              - a risen Earth Column: bounces off it, keeps flying
##              - anything else (gray rock, grass, a crate, a stuck boulder): shatters
##   STUCK    snapped onto the tile grid against the earth face it hit (and that
##            tile hardens, so it can't be torn out from under it): a solid
##            one-tile block on physics layer 1 ("world"), so you stand on it and wall-jump off
##            it. It tells the EarthLayer which cells it fills (like a risen column),
##            so the bend shadow crawls over it and you can start a bend standing on it.
##   SHATTERED a gravel burst, then the node is freed.
##
## Created by BoulderAbility.try_tear(): Boulder.new(), setup(), then added as a child of
## the ROOM so Room.reset_objects() finds it (RESETTABLE_GROUP) and reset() frees it.
##
## Why a CharacterBody2D? move_and_collide() moves it and reports exactly what it hit
## (which node, which way the surface faces), which is all the impact rules need.
## While moving it's on NO physics layer (collision_layer = 0): nothing collides with
## it, so the player isn't bumped by a boulder flying past. Its mask is layer 1
## ("world"), so it hits tiles, columns, crates and stuck boulders, but passes through
## the player and wisps (enemy hits come in Stage E6).
##
## Origin: the CENTER of the boulder (unlike the player and crates, whose origin is at
## the feet), since it pops and flies in every direction.

enum Phase { POPPING, FLYING, STUCK, SHATTERED }

## Group of every boulder, for tests and future enemy code.
const GROUP: StringName = &"boulder"
## Drawn in used-earth color (Earth_bending.md §2: creations are used earth), with a
## darker outline and a lighter top-left edge so it reads as a lump, not a tile.
const BODY_COLOR: Color = EarthLayer.USED_COLOR
const OUTLINE_COLOR: Color = Color(0.2, 0.13, 0.08)
const HIGHLIGHT_COLOR: Color = Color(0.48, 0.34, 0.2)
## How long the boulder stays white after a perfect throw, seconds.
const PERFECT_FLASH_TIME: float = 0.12
## Physics layers checked when looking for a free spot to stick into: world (1),
## player (2) and enemies (5), so a boulder never sticks inside someone.
const STICK_BLOCKING_MASK: int = 1 | 2 | 16
## The free-spot check uses a box this much smaller on each side, px, so touching the
## earth face it sticks to doesn't count as overlapping it.
const STICK_CHECK_INSET: float = 0.5
## While moving, the hitbox is this much smaller than the rock on each side, px. A
## rock exactly as wide as its hole touches both neighbouring tiles, and Godot's
## collision safety margin (~0.08 px) then counts those as blocking: it couldn't pop
## out. Stuck, it gets its full size back (flush, solid ground).
const MOVING_HITBOX_INSET: float = 0.25

## Feel values (sizes, timings, speeds). The player's EarthTuning, passed in setup().
var earth_tuning: EarthTuning
var phase: Phase = Phase.POPPING
## Unit vector out of the surface it was torn from: the tear direction.
var pop_normal: Vector2 = Vector2.UP
## Center position at the start of the tear (inside the hole: where the tile was).
var pop_start_position: Vector2
## Sideways speed of the hop, px/s (signed): away from the player, or the wall.
var hop_velocity_x: float = 0.0
## The player's middle (world y) when the rock was torn out. The player stays rooted
## while holding, so the perfect windows can be worked out once, in setup().
var player_center_y: float = 0.0
## Seconds (game time) since the tear started. The throw timing is measured on this.
var pop_elapsed: float = 0.0
## The pop_elapsed moment the rock's middle comes down level with the player's
## (the middle of the perfect window), or INF if it never does.
var perfect_time: float = INF
## POPPING steps: true once the hop has started / once it has landed.
var is_hopping: bool = false
var is_resting: bool = false
## Seconds of rest left after landing.
var rest_remaining: float = 0.0
## True once the player let go without throwing (Jump during BoulderHold): it can't
## be thrown any more, it just drops and shatters.
var is_dropped: bool = false
## FLYING: seconds of "no gravity" left, and seconds flown so far.
var float_time_remaining: float = 0.0
var flight_time: float = 0.0
## Seconds left of the white flash after a perfect throw.
var perfect_flash_remaining: float = 0.0
## STUCK: the EarthLayer we registered our cells with (to unregister on reset).
var stuck_layer: EarthLayer = null

var hitbox: CollisionShape2D


## Call before adding to the tree. `start_center` = where the rock's center starts
## (the middle of the torn tile), `normal` = the surface's outward direction,
## `away_velocity_x` = the hop's sideways speed (signed, away from the player or the
## wall), `player_middle_y` = the player's middle (world y), for the perfect window.
func setup(start_center: Vector2, normal: Vector2, away_velocity_x: float, player_middle_y: float,
		tuning: EarthTuning) -> void:
	earth_tuning = tuning
	pop_start_position = start_center
	pop_normal = normal
	hop_velocity_x = away_velocity_x
	player_center_y = player_middle_y
	perfect_time = get_perfect_time()


func _ready() -> void:
	collision_layer = 0  # nothing collides with a moving boulder (see the header)
	collision_mask = 1   # bit value of layer 1, "world"
	global_position = pop_start_position
	add_to_group(GROUP)
	add_to_group(Room.RESETTABLE_GROUP)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2.ONE * (earth_tuning.boulder_size - MOVING_HITBOX_INSET * 2.0)
	hitbox = CollisionShape2D.new()
	hitbox.shape = shape
	add_child(hitbox)
	z_index = 4  # in front of tiles, behind the bend shadow (6) and gravel (5)


# --- Questions the ability asks ------------------------------------------------------

## Upward speed of the hop, px/s: enough to rise boulder_hop_height under gravity
## (v² = 2·g·h, the same formula as a jump).
func get_hop_speed() -> float:
	return sqrt(2.0 * earth_tuning.boulder_gravity * earth_tuning.boulder_hop_height)


## The pop_elapsed moment the rock's middle (y) comes back DOWN level with the
## player's, from the planned hop (a parabola). INF if the hop never gets that high.
## Collisions aren't predicted; the player is rooted, so this stays true unless the
## rock hits something on the way.
func get_perfect_time() -> float:
	var tear_time: float = maxf(earth_tuning.boulder_tear_time, 0.001)
	var hop_start_y: float = pop_start_position.y + pop_normal.y * earth_tuning.boulder_size
	# During the hop: y(s) = hop_start_y - v·s + g·s²/2 (s = time since the hop
	# started; y grows downward). Level when y(s) = player_center_y, a quadratic:
	# (g/2)·s² - v·s + (hop_start_y - player_center_y) = 0. Its larger root is the
	# way down (the smaller one is the way up, which doesn't count).
	var gravity: float = earth_tuning.boulder_gravity
	var hop_speed: float = get_hop_speed()
	var discriminant: float = hop_speed * hop_speed - 2.0 * gravity * (hop_start_y - player_center_y)
	if discriminant < 0.0:
		return INF
	return tear_time + (hop_speed + sqrt(discriminant)) / gravity


## Seconds from now to the perfect moment (INF if there is none). BoulderAbility
## turns this into the throw quality.
func get_time_from_perfect() -> float:
	return absf(pop_elapsed - perfect_time)


## True while the player can still throw it.
func is_throwable() -> bool:
	return phase == Phase.POPPING and not is_dropped \
		and pop_elapsed < earth_tuning.boulder_hold_time


## True inside the perfect window (±boulder_perfect_window around perfect_time).
func is_in_perfect_window() -> bool:
	return get_time_from_perfect() <= earth_tuning.boulder_perfect_window


# --- Actions -------------------------------------------------------------------------

## Throws it toward `direction` (unit vector) at `speed`, ignoring gravity for
## `float_time` seconds. `is_perfect` adds the white flash. Called by BoulderAbility.
func throw(direction: Vector2, speed: float, float_time: float, is_perfect: bool) -> void:
	if not is_throwable():
		return
	if not is_hopping:
		# Still tearing out of its hole: yank it the rest of the way out first, or the
		# throw would slam it into the side of its own hole. (The way-up perfect window
		# starts while it's still coming out.)
		move_and_collide(pop_start_position + pop_normal * earth_tuning.boulder_size - global_position)
	phase = Phase.FLYING
	velocity = direction * speed
	float_time_remaining = float_time
	flight_time = 0.0
	if is_perfect:
		perfect_flash_remaining = PERFECT_FLASH_TIME
	queue_redraw()


## The player let go without throwing: it shatters when it lands (or right away if
## it already has).
func drop() -> void:
	is_dropped = true


# --- Movement ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	perfect_flash_remaining = maxf(perfect_flash_remaining - delta, 0.0)
	match phase:
		Phase.POPPING:
			_update_pop(delta)
		Phase.FLYING:
			_update_flight(delta)
	queue_redraw()  # the white flash and the window tint change over time


## The pop: tear, hop, land and rest (see the header). Not thrown in time = shatter.
func _update_pop(delta: float) -> void:
	pop_elapsed += delta
	var tear_time: float = maxf(earth_tuning.boulder_tear_time, 0.001)
	if pop_elapsed >= earth_tuning.boulder_hold_time:
		shatter()  # never thrown: "drops and shatters" (Earth_bending.md §6)
	elif not is_hopping:
		# 1) Tear: slowly out of the hole, one tile along the normal. A straight
		#    line; the rumble is only drawn (see _draw).
		var progress: float = minf(pop_elapsed / tear_time, 1.0)
		var target: Vector2 = pop_start_position + pop_normal * earth_tuning.boulder_size * progress
		move_and_collide(target - global_position)
		if progress >= 1.0:
			_start_hop()
	elif is_resting:
		# 3) Landed: rest a moment (still throwable), then crumble.
		rest_remaining -= delta
		if rest_remaining <= 0.0 or is_dropped:
			shatter()
	else:
		# 2) Hop: a small jump under gravity, drifting away from the player.
		velocity.y = move_toward(velocity.y, earth_tuning.boulder_max_fall_speed, earth_tuning.boulder_gravity * delta)
		var collision: KinematicCollision2D = move_and_collide(velocity * delta)
		if collision != null:
			_on_pop_contact(collision)


## Out of the ground: the hop starts, with a little burst of gravel from the hole.
func _start_hop() -> void:
	is_hopping = true
	velocity = Vector2(hop_velocity_x, -get_hop_speed())
	FX.spawn_gravel(global_position, 3, Vector2.UP)


## The hopping rock touched something. Ground under it: land and rest (or shatter, if
## the player let go). A wall: slide down it. A ceiling: stop rising.
func _on_pop_contact(collision: KinematicCollision2D) -> void:
	var surface_normal: Vector2 = collision.get_normal()
	if surface_normal.y < -0.7:
		if is_dropped:
			shatter()
			return
		is_resting = true
		rest_remaining = earth_tuning.boulder_land_rest_time
		velocity = Vector2.ZERO
		FX.spawn_gravel(collision.get_position(), 2, Vector2.UP)
		FX.play_sfx(&"boulder_land")
	else:
		velocity = velocity.slide(surface_normal)


## Thrown: straight while floating, then gravity. Reacts to the first thing it hits.
func _update_flight(delta: float) -> void:
	flight_time += delta
	if float_time_remaining > 0.0:
		float_time_remaining -= delta
	else:
		velocity.y = move_toward(velocity.y, earth_tuning.boulder_max_fall_speed, earth_tuning.boulder_gravity * delta)
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision != null:
		_on_impact(collision)
	elif flight_time >= earth_tuning.boulder_max_flight_time:
		shatter()  # thrown out of the room: don't fly forever


## What happens on impact depends on WHAT it hit (the collider node).
func _on_impact(collision: KinematicCollision2D) -> void:
	var collider: Object = collision.get_collider()
	var surface_normal: Vector2 = collision.get_normal()  # points from the surface back at us
	if collider is EarthColumn:
		_bounce_off(surface_normal, collision.get_position())
	elif collider is EarthLayer:
		if not _stick_into(collider as EarthLayer, surface_normal, collision.get_position()):
			shatter()
	else:
		shatter()


## A risen column springs it away (Earth_bending.md §5): mirror the velocity off the
## column's face, and leave it at least boulder_column_bounce_speed along the normal.
func _bounce_off(surface_normal: Vector2, contact_point: Vector2) -> void:
	velocity = velocity.bounce(surface_normal)
	var speed_off_face: float = velocity.dot(surface_normal)
	if speed_off_face < earth_tuning.boulder_column_bounce_speed:
		velocity += surface_normal * (earth_tuning.boulder_column_bounce_speed - speed_off_face)
	FX.spawn_gravel(contact_point, earth_tuning.column_hit_gravel_count, surface_normal)
	FX.play_sfx(&"column_launch")


## Snaps onto the tile grid against the earth face it hit and becomes solid.
## Returns false (the caller shatters it) if no free spot is found there.
func _stick_into(earth_layer: EarthLayer, surface_normal: Vector2, contact_point: Vector2) -> bool:
	var spot: Vector2 = _find_stick_spot(earth_layer, surface_normal)
	if spot == Vector2.INF:
		return false
	phase = Phase.STUCK
	# Back to rock color: once stuck, _physics_process stops, so a perfect throw's
	# white flash would never count down and the rock would stay white.
	perfect_flash_remaining = 0.0
	velocity = Vector2.ZERO
	global_position = spot
	collision_layer = 1  # solid "world" now: standable, wall-jumpable
	(hitbox.shape as RectangleShape2D).size = Vector2.ONE * earth_tuning.boulder_size
	set_physics_process(false)
	stuck_layer = earth_layer
	earth_layer.register_column(self, _get_covered_cells(earth_layer))
	# Harden the earth it's stuck into, so a rock can't tear it out from under this one
	# and leave it floating. It's the tile just past our side that touched the face.
	var behind_point: Vector2 = global_position - surface_normal * (earth_tuning.boulder_size / 2.0 + 1.0)
	earth_layer.harden(earth_layer.get_cell_at(behind_point))
	FX.spawn_gravel(contact_point, earth_tuning.boulder_stick_gravel_count, surface_normal)
	FX.shake(earth_tuning.boulder_impact_shake_strength, earth_tuning.boulder_impact_shake_time)
	FX.play_sfx(&"boulder_stick")
	queue_redraw()
	return true


## A grid-aligned center for the stuck boulder, or Vector2.INF if none is free.
## Along the hit normal, the boulder's edge is rounded onto the face's grid line
## (it was touching it, give or take Godot's ~0.08 px safety margin). Across it, the
## nearest grid line is tried first, then the one on the other side.
func _find_stick_spot(earth_layer: EarthLayer, surface_normal: Vector2) -> Vector2:
	var tile_size: float = earth_layer.get_half_tile_size() * 2.0
	var half_size: float = earth_tuning.boulder_size / 2.0
	# Work in the layer's own coordinates, where tile corners are multiples of tile_size.
	var corner: Vector2 = earth_layer.to_local(global_position) - Vector2.ONE * half_size
	var is_horizontal_hit: bool = absf(surface_normal.x) > absf(surface_normal.y)
	var along_normal: float = corner.x if is_horizontal_hit else corner.y
	var across: float = corner.y if is_horizontal_hit else corner.x
	var snapped_along: float = roundf(along_normal / tile_size) * tile_size
	var across_options: Array[float] = [roundf(across / tile_size) * tile_size]
	for other: float in [floorf(across / tile_size) * tile_size, ceilf(across / tile_size) * tile_size]:
		if not across_options.has(other):
			across_options.append(other)
	for snapped_across: float in across_options:
		var snapped_corner: Vector2 = Vector2(snapped_along, snapped_across) if is_horizontal_hit \
			else Vector2(snapped_across, snapped_along)
		var center: Vector2 = earth_layer.to_global(snapped_corner + Vector2.ONE * half_size)
		if _is_spot_free(center):
			return center
	return Vector2.INF


## True if a boulder centered at `center` would overlap no solid, player or enemy.
func _is_spot_free(center: Vector2) -> bool:
	var check_shape: RectangleShape2D = RectangleShape2D.new()
	check_shape.size = Vector2.ONE * (earth_tuning.boulder_size - STICK_CHECK_INSET * 2.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = check_shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = STICK_BLOCKING_MASK
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## The tile cells the stuck rock fills (1 for an 8x8 rock), in `earth_layer`'s map
## coordinates.
func _get_covered_cells(earth_layer: EarthLayer) -> Array[Vector2i]:
	var half_size: float = earth_tuning.boulder_size / 2.0
	# Just inside the top-left corner, so the cell lookup can't land on a neighbour.
	var top_left_cell: Vector2i = earth_layer.get_cell_at(global_position - Vector2.ONE * (half_size - 1.0))
	var tiles_across: int = roundi(earth_tuning.boulder_size / (earth_layer.get_half_tile_size() * 2.0))
	var cells: Array[Vector2i] = []
	for x: int in tiles_across:
		for y: int in tiles_across:
			cells.append(top_left_cell + Vector2i(x, y))
	return cells


## Breaks into gravel and disappears.
func shatter() -> void:
	if phase == Phase.SHATTERED:
		return
	phase = Phase.SHATTERED
	set_physics_process(false)
	FX.spawn_gravel(global_position, earth_tuning.boulder_shatter_gravel_count, Vector2.ZERO)
	FX.shake(earth_tuning.boulder_impact_shake_strength, earth_tuning.boulder_impact_shake_time)
	FX.play_sfx(&"boulder_shatter")
	queue_free()


## Called by Room.reset_objects() (death or R): boulders don't survive a reset.
func reset() -> void:
	if stuck_layer != null:
		stuck_layer.unregister_column(self)
	phase = Phase.SHATTERED
	queue_free()


# --- Drawing -------------------------------------------------------------------------

## A dark-earth square with an outline and a light top-left edge. White while it can
## be thrown perfectly (the timing cue) and for a moment after a perfect throw.
func _draw() -> void:
	var half_size: float = earth_tuning.boulder_size / 2.0
	var rect: Rect2 = Rect2(-Vector2.ONE * half_size, Vector2.ONE * earth_tuning.boulder_size)
	if phase == Phase.POPPING and not is_hopping:
		# Tearing: rumble sideways along the surface (drawn only; the body moves straight).
		var along_surface: Vector2 = Vector2(-pop_normal.y, pop_normal.x)
		rect.position += along_surface * roundf(sin(pop_elapsed * 90.0) * earth_tuning.boulder_tear_rumble)
	var is_white: bool = perfect_flash_remaining > 0.0 or (is_throwable() and is_in_perfect_window())
	draw_rect(rect, Color.WHITE if is_white else BODY_COLOR)
	draw_rect(rect.grow(-0.5), OUTLINE_COLOR, false, 1.0)
	if not is_white:
		draw_line(rect.position + Vector2(1.5, 1.5), Vector2(rect.end.x - 2.0, rect.position.y + 1.5), HIGHLIGHT_COLOR, 1.0)
		draw_line(rect.position + Vector2(1.5, 1.5), Vector2(rect.position.x + 1.5, rect.end.y - 2.0), HIGHLIGHT_COLOR, 1.0)

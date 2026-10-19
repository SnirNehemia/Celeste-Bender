class_name EarthColumn
extends StaticBody2D
## Earth Column (Earth_bending.md §5, Stage E3): an 8x24 pillar of earth that shoots
## out of an earth face, perpendicular to it: up from a floor, sideways from a wall,
## down from a ceiling.
##
## Two phases:
##   RISING (column_rise_time, 0.1 s): the column grows from 0 to full length. Its
##     TIP acts like a piston: whatever it sweeps over (the player, crates, wisps) is
##     pushed along with the tip and LAUNCHED away from it, once. This is the "spring":
##     the momentum of the pillar throws you. A column rising under the player is the
##     super jump.
##   RISEN: a plain solid platform you can stand on and wall-jump off. It throws
##     nothing any more. It stays until the room resets.
## Squeezed: if a pushed thing can't move (a ceiling is in the way), the player and
## enemies get crushed (Player.die / Pushable.try_crush); a crate can't be crushed,
## so the column stops short of it instead.
##
## Created by EarthColumnAbility.erupt(): EarthColumn.new(), setup(face, tuning),
## then added as a child of the ROOM, so Room.reset_objects() finds it (we join
## Room.RESETTABLE_GROUP) and reset() deletes it.
##
## Its FOOT: as it rises, the earth under its base hardens in a pyramid
## (EarthLayer.harden_foot, column_foot_rows deep), so rocks can't dig it loose and
## leave it floating (Earth_bending.md §11, Stage E4a).
##
## Once risen, it tells its EarthLayer which tile cells it fills (register_column):
## to the bend shadow it's then solid used earth, so the shadow crawls over it, and
## the player can start a bend standing on it (Earth_bending.md §11).
##
## It's a StaticBody2D on physics layer 1 ("world"), so everything stands on it like
## on a tile. Its collision shape is resized every physics frame while it rises.
##
## Finding what the tip sweeps: a direct physics SHAPE QUERY (like the gust's cone):
## "which bodies on layers 2 (player) and 4 (pushable) overlap this rectangle right
## now?" Unlike an Area2D, a query answers immediately, in the same frame.
##
## Coordinates: the node sits at the middle of the face it rose from (the column's
## BASE). `normal` points out of the surface, toward the tip.

## Drawn in used-earth color (Earth_bending.md §5), with a darker outline and a
## lighter edge on the tip so you can see which way it grew.
const BODY_COLOR: Color = EarthLayer.USED_COLOR
const OUTLINE_COLOR: Color = Color(0.2, 0.13, 0.08)
const TIP_COLOR: Color = Color(0.48, 0.34, 0.2)
## Physics layers the tip pushes: bit values of layer 2 "player" and layer 4 "pushable".
const PUSH_MASK: int = 2 | 8
## The sweep reaches this far past the tip, px, so a body resting right on the
## surface (Godot keeps bodies ~0.08 px apart) is caught as soon as the column moves.
const TOUCH_MARGIN: float = 0.5
## The sweep is this much narrower on each side than the column, px, so a body
## standing on the NEXT tile, side by side with the column, isn't caught.
const SIDE_INSET: float = 1.0
## Max bodies one sweep query reports.
const MAX_SWEEP_RESULTS: int = 16

## Feel values (sizes, launch speeds). The player's EarthTuning, passed in setup().
var earth_tuning: EarthTuning
## World position of the base (the middle of the face it rose from).
var base_position: Vector2
## The face it rose from: its layer and tile, used to register the cells it fills.
var source_face: EarthFace
## Unit vector out of the surface: (0, -1) from a floor, (0, 1) from a ceiling...
var normal: Vector2
## How long it will be once risen: column_length, or less under a low ceiling.
var full_length: float = 0.0
## Current length, px (grows during the rise).
var length: float = 0.0
## Seconds since the rise started (game time).
var rise_elapsed: float = 0.0
var is_rising: bool = true
## Everything this column already threw: each thing is launched once per column.
var launched_bodies: Array[Node2D] = []

var hitbox: CollisionShape2D
var hitbox_shape: RectangleShape2D
var sweep_shape: RectangleShape2D


## Call before adding to the tree. `face` = the earth face it rises from.
func setup(face: EarthFace, tuning: EarthTuning) -> void:
	earth_tuning = tuning
	source_face = face
	base_position = face.get_global_center()
	normal = Vector2(face.normal)
	# Grow only as far as the open air in front of the face: count free tiles along
	# the normal (up to the full length). "Solid" = any tile of the room, earth or gray.
	var tile_size: float = face.layer.get_half_tile_size() * 2.0
	var max_tiles: int = ceili(tuning.column_length / tile_size)
	var open_tiles: int = 0
	while open_tiles < max_tiles and not face.layer.is_solid(face.cell + face.normal * (open_tiles + 1)):
		open_tiles += 1
	full_length = minf(tuning.column_length, open_tiles * tile_size)


func _ready() -> void:
	collision_layer = 1  # bit value of layer 1, "world": solid like the tiles
	collision_mask = 0   # a static body never needs to detect anything
	global_position = base_position
	add_to_group(Room.RESETTABLE_GROUP)
	source_face.layer.harden_foot(source_face.cell, source_face.normal, earth_tuning.column_foot_rows)
	hitbox_shape = RectangleShape2D.new()
	hitbox = CollisionShape2D.new()
	hitbox.shape = hitbox_shape
	hitbox.disabled = true  # zero length: nothing to collide with yet
	add_child(hitbox)
	sweep_shape = RectangleShape2D.new()


## Only runs while rising; set_physics_process(false) stops it once risen.
func _physics_process(delta: float) -> void:
	rise_elapsed += delta
	var rise_fraction: float = clampf(rise_elapsed / maxf(earth_tuning.column_rise_time, 0.001), 0.0, 1.0)
	var target_length: float = full_length * rise_fraction
	# Push (and launch) whatever is in the way BEFORE growing the collision shape,
	# so nothing ends up inside the column. May come back shorter if jammed.
	var reached_length: float = _push_bodies_out_of(target_length)
	var is_jammed: bool = reached_length < target_length - 0.01
	length = maxf(length, reached_length)
	_update_hitbox()
	queue_redraw()
	if rise_fraction >= 1.0 or is_jammed:
		# Risen (or stuck against the player / a crate under a ceiling): from now on
		# a plain platform.
		is_rising = false
		set_physics_process(false)
		_register_cells()


## Pushes every player / pushable body that the column at `target_length` would
## overlap out past its tip, and launches it. Returns the length the column can
## really reach: shorter than `target_length` if something uncrushable (a crate)
## is stuck between the tip and a solid.
func _push_bodies_out_of(target_length: float) -> float:
	var reached_length: float = target_length
	for body: CharacterBody2D in _find_swept_bodies(target_length):
		var body_rect: Rect2 = _get_body_rect(body)
		# How far the body's near side is from the base, along the normal.
		var half_extent_along_normal: float = absf(body_rect.size.dot(normal)) / 2.0
		var near_side_distance: float = (body_rect.get_center() - base_position).dot(normal) - half_extent_along_normal
		var depth: float = target_length - near_side_distance
		if depth <= 0.0:
			continue  # in the margin, but the tip hasn't reached it yet
		var travel: float = _push_body(body, depth)
		if travel < depth - 0.01:
			# Blocked (a ceiling or a wall on the other side): squeezed.
			var squeezed_player: Player = body as Player
			if squeezed_player != null:
				squeezed_player.die()
				_puff_at(body_rect.get_center())
				continue
			if Pushable.try_crush(body):
				_puff_at(body_rect.get_center())
				continue
			# Can't be crushed: the column stops where the body's near side is now,
			# and there's no room to throw it anywhere.
			reached_length = minf(reached_length, near_side_distance + travel)
			continue
		_launch(body, body_rect)
	return reached_length


## The player and pushable bodies overlapping the column's sweep (from the base to
## `target_length` + TOUCH_MARGIN, slightly narrower than the column).
func _find_swept_bodies(target_length: float) -> Array[CharacterBody2D]:
	var sweep_rect: Rect2 = _get_local_rect(target_length + TOUCH_MARGIN)
	var across: Vector2 = Vector2(absf(normal.y), absf(normal.x))  # the axis across the column
	sweep_rect = sweep_rect.grow_individual(-SIDE_INSET * across.x, -SIDE_INSET * across.y,
		-SIDE_INSET * across.x, -SIDE_INSET * across.y)
	sweep_shape.size = sweep_rect.size
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = sweep_shape
	# A query shape is placed by its center, in world space.
	query.transform = Transform2D(0.0, global_position + sweep_rect.get_center())
	query.collision_mask = PUSH_MASK
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var sweep_global_rect: Rect2 = Rect2(global_position + sweep_rect.position, sweep_rect.size)
	var bodies: Array[CharacterBody2D] = []
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, MAX_SWEEP_RESULTS):
		# Only things that move by script: the player, crates, wisps. (A leaf
		# platform is pushable too, but it's an AnimatableBody2D on its own track.)
		var body: CharacterBody2D = result.collider as CharacterBody2D
		if body == null or bodies.has(body):
			continue
		# The physics world may still know a body at its position from before a
		# teleport (a respawn this frame): confirm with its real rectangle now.
		if not sweep_global_rect.intersects(_get_body_rect(body)):
			continue
		var player: Player = body as Player
		if player != null and player.is_dead():
			continue
		if player != null or Pushable.find_pushable(body) != null:
			bodies.append(body)
	return bodies


## Moves `body` `distance` px along the normal, as far as it can go without entering
## a solid. Returns how far it moved. move_and_collide(..., test_only = true) asks
## the physics engine "how far could this body move?" without moving it.
func _push_body(body: CharacterBody2D, distance: float) -> float:
	var motion: Vector2 = normal * distance
	var collision: KinematicCollision2D = body.move_and_collide(motion, true)
	var travel: Vector2 = motion if collision == null else collision.get_travel()
	body.global_position += travel
	return travel.length()


## Throws `body` away from the tip, once per column.
func _launch(body: CharacterBody2D, body_rect: Rect2) -> void:
	if launched_bodies.has(body):
		return
	launched_bodies.append(body)
	var player: Player = body as Player
	if player != null:
		player.launch_from_column(normal)
	else:
		Pushable.try_launch(body, normal * earth_tuning.column_launch_speed)
	_puff_at(body_rect.get_center())
	FX.play_sfx(&"column_launch")


## A gravel puff where the tip met something, spraying out along the normal.
func _puff_at(world_point: Vector2) -> void:
	var tip_point: Vector2 = base_position + normal * length
	# On the tip's line, at the body's position across the column.
	var across: Vector2 = Vector2(absf(normal.y), absf(normal.x))
	var puff_position: Vector2 = tip_point + (world_point - tip_point) * across
	FX.spawn_gravel(puff_position, earth_tuning.column_hit_gravel_count, normal)


## The world-space rectangle of a body's hitbox: its first CollisionShape2D child
## with a rectangle (the player, crates and wisps all have one).
func _get_body_rect(body: CharacterBody2D) -> Rect2:
	for child: Node in body.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			var size: Vector2 = (shape_node.shape as RectangleShape2D).size
			return Rect2(shape_node.global_position - size / 2.0, size)
	return Rect2(body.global_position, Vector2.ZERO)


## The column's rectangle at length `column_length`, relative to the base:
## `column_width` across the surface, `column_length` along the normal.
func _get_local_rect(column_length: float) -> Rect2:
	var across: Vector2 = Vector2(absf(normal.y), absf(normal.x)) * earth_tuning.column_width
	var corner_at_base: Vector2 = -across / 2.0
	var corner_at_tip: Vector2 = normal * column_length + across / 2.0
	# expand() grows a rectangle to include a point, so the corners' order doesn't matter.
	return Rect2(corner_at_base, Vector2.ZERO).expand(corner_at_tip)


func _update_hitbox() -> void:
	hitbox.disabled = length <= 0.0
	var rect: Rect2 = _get_local_rect(length)
	hitbox_shape.size = rect.size
	hitbox.position = rect.get_center()


## Tells the earth layer which tile cells the risen column fills: one per started
## tile of length (a jammed column of 13 px fills 2), at least 1.
func _register_cells() -> void:
	var tile_size: float = source_face.layer.get_half_tile_size() * 2.0
	var cells: Array[Vector2i] = []
	for tile_index: int in maxi(roundi(length / tile_size), 1):
		cells.append(source_face.cell + source_face.normal * (tile_index + 1))
	source_face.layer.register_column(self, cells)


## Called by Room.reset_objects() (death or R): columns don't survive a reset.
func reset() -> void:
	source_face.layer.unregister_column(self)
	queue_free()


func _draw() -> void:
	if length <= 0.0:
		return
	var rect: Rect2 = _get_local_rect(length)
	draw_rect(rect, BODY_COLOR)
	draw_rect(rect.grow(-0.5), OUTLINE_COLOR, false, 1.0)
	# A lighter line just inside the tip edge.
	var tip_center: Vector2 = normal * (length - 1.5)
	var half_across: Vector2 = Vector2(absf(normal.y), absf(normal.x)) * (earth_tuning.column_width / 2.0 - 1.0)
	draw_line(tip_center - half_across, tip_center + half_across, TIP_COLOR, 1.0)

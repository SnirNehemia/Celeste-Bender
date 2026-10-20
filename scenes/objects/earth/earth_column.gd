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
##
## LOOK (Stage E4e): piled earth, not a brown rectangle. It's drawn row by row (one
## pixel row across the column per pixel of length), counted from the TIP down, so
## the pattern travels out of the ground with the tip as it rises:
##   - layered BANDS: 2-4 rows thick, alternating lighter / darker earth, like strata
##   - ROUGH SIDES: each row may be cut in by a pixel on either side, with the dark
##     outline following the cut
##   - a CRACKED TIP: the top row is dark with its corners cut, a lit row under it,
##     and a crack running down from a notch in the top edge
##   - its BASE grows out of the ground like the snake's: a root into the ground tile
##     and a fillet on each side (EarthBaseLook)
## The rows are random once per column (_build_look). The drawing uses a transform
## whose x axis runs ACROSS the column and y axis along `normal`, so one piece of
## code draws a column pointing up, down, left or right.
## While rising it crumbles a few pebbles off its sides (PebbleField.leave_one_pebble).

## Drawn in used-earth color (Earth_bending.md §5), with a darker outline and a
## lighter edge on the tip so you can see which way it grew.
const BODY_COLOR: Color = EarthLayer.USED_COLOR
const OUTLINE_COLOR: Color = Color(0.2, 0.13, 0.08)
const TIP_COLOR: Color = Color(0.48, 0.34, 0.2)
## The bands alternate between BODY_COLOR and these two, a shade either way.
const BAND_LIGHT_COLOR: Color = Color(0.39, 0.27, 0.16)
const BAND_DARK_COLOR: Color = Color(0.28, 0.18, 0.1)
const CRACK_COLOR: Color = Color(0.17, 0.11, 0.06)
## A band is this many rows thick (random, inclusive).
const BAND_MIN_ROWS: int = 2
const BAND_MAX_ROWS: int = 4
## Chance that a row's side is cut in by a pixel (each side rolls on its own).
const SIDE_CUT_CHANCE: float = 0.35
## The tip's crack runs this many rows down (random, inclusive).
const CRACK_MIN_ROWS: int = 3
const CRACK_MAX_ROWS: int = 5
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

## LOOK (Stage E4e, see the header). Index = row counted from the tip (0 = the tip).
var look_random: RandomNumberGenerator = RandomNumberGenerator.new()
## Pixels cut off each row on the left / right side (0 or 1).
var row_left_cuts: PackedInt32Array = PackedInt32Array()
var row_right_cuts: PackedInt32Array = PackedInt32Array()
## Each row's band color.
var row_colors: PackedColorArray = PackedColorArray()
## The crack: one pixel per row from the tip down, x across the column (whole
## pixels, 0 = the left edge). Row 0's pixel is the notch in the top edge.
var crack_pixel_xs: PackedInt32Array = PackedInt32Array()
## Pebbles crumbled off the sides so far during the rise.
var pebbles_crumbled: int = 0


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
	look_random.randomize()
	_build_look()


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
	_crumble_pebbles(rise_fraction)
	if rise_fraction >= 1.0 or is_jammed:
		# Risen (or stuck against the player / a crate under a ceiling): from now on
		# a plain platform.
		_crumble_pebbles(1.0)  # jammed early: drop the rest now
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


# --- Look (Stage E4e) ----------------------------------------------------------------

## Rolls the per-row look once (see "LOOK" in the header): side cuts, band colors and
## the tip's crack, for every row the full-length column could have.
func _build_look() -> void:
	var row_count: int = ceili(earth_tuning.column_length) + 1
	var width_pixels: int = roundi(earth_tuning.column_width)
	var band_colors: Array[Color] = [BODY_COLOR, BAND_LIGHT_COLOR, BODY_COLOR, BAND_DARK_COLOR]
	var band_index: int = look_random.randi() % band_colors.size()
	var rows_left_in_band: int = look_random.randi_range(BAND_MIN_ROWS, BAND_MAX_ROWS)
	for row_index: int in row_count:
		row_left_cuts.append(1 if look_random.randf() < SIDE_CUT_CHANCE else 0)
		row_right_cuts.append(1 if look_random.randf() < SIDE_CUT_CHANCE else 0)
		row_colors.append(band_colors[band_index])
		rows_left_in_band -= 1
		if rows_left_in_band <= 0:
			band_index = (band_index + 1) % band_colors.size()
			rows_left_in_band = look_random.randi_range(BAND_MIN_ROWS, BAND_MAX_ROWS)
	# The crack wanders down from the tip, a pixel left, right or straight each row,
	# kept 2 px away from the sides (where the outline and the cuts are).
	var crack_x: int = look_random.randi_range(2, width_pixels - 3)
	for crack_row: int in look_random.randi_range(CRACK_MIN_ROWS, CRACK_MAX_ROWS):
		crack_pixel_xs.append(crack_x)
		crack_x = clampi(crack_x + look_random.randi_range(-1, 1), 2, width_pixels - 3)


## While rising: drops pebbles off the sides, `column_rise_pebble_count` spread over
## the rise (`rise_fraction` 0 → 1). 1.0 drops whatever is still owed.
func _crumble_pebbles(rise_fraction: float) -> void:
	var owed: int = floori(earth_tuning.column_rise_pebble_count * rise_fraction)
	var across: Vector2 = Vector2(-normal.y, normal.x)
	while pebbles_crumbled < owed and length > 0.0:
		pebbles_crumbled += 1
		# A random spot along a random side, falling off sideways and a bit outward.
		var side: float = -1.0 if look_random.randf() < 0.5 else 1.0
		var spot: Vector2 = base_position + normal * look_random.randf_range(0.0, length) \
			+ across * side * earth_tuning.column_width / 2.0
		PebbleField.leave_one_pebble(get_tree(), spot, (across * side + normal * 0.5).normalized())


func _draw() -> void:
	if length <= 0.0:
		return
	# Draw in "column space": x across the column (0 = its left edge), y along the
	# normal (0 = the base, length = the tip). Transform2D(x axis, y axis, origin)
	# maps that onto the node; for a floor column, x = right and y = up.
	var across: Vector2 = Vector2(-normal.y, normal.x)
	var half_width: float = earth_tuning.column_width / 2.0
	draw_set_transform_matrix(Transform2D(across, normal, -across * half_width))
	var width_pixels: int = roundi(earth_tuning.column_width)
	# Rows counted from the tip: row k covers length-k-1 .. length-k (the last one,
	# at the base, may be cut short).
	for row_index: int in mini(ceili(length), row_colors.size()):
		var row_top: float = length - row_index
		var row_bottom: float = maxf(row_top - 1.0, 0.0)
		var row_height: float = row_top - row_bottom
		# No side cuts in the 2 rows at the base: the fillets (below) join there.
		var is_base_row: bool = row_bottom < 2.0
		var left_x: int = 0 if is_base_row else row_left_cuts[row_index]
		var right_x: int = width_pixels - 1 - (0 if is_base_row else row_right_cuts[row_index])  # last filled pixel
		if row_index == 0:
			# The tip's edge: dark, corners cut, with the crack's notch left open.
			for pixel_x: int in range(left_x + 1, right_x):
				if crack_pixel_xs.is_empty() or pixel_x != crack_pixel_xs[0]:
					draw_rect(Rect2(pixel_x, row_bottom, 1.0, row_height), OUTLINE_COLOR)
			continue
		var fill_color: Color = TIP_COLOR if row_index == 1 else row_colors[row_index]
		draw_rect(Rect2(left_x, row_bottom, right_x - left_x + 1, row_height), fill_color)
		# The outline follows the cuts, so the sides look rough.
		draw_rect(Rect2(left_x, row_bottom, 1.0, row_height), OUTLINE_COLOR)
		draw_rect(Rect2(right_x, row_bottom, 1.0, row_height), OUTLINE_COLOR)
		if row_index < crack_pixel_xs.size():
			draw_rect(Rect2(crack_pixel_xs[row_index], row_bottom, 1.0, row_height), CRACK_COLOR)
	# Where it leaves the ground: a root and fillets, like the snake's (EarthBaseLook),
	# in the color of the band at the base so the two run together.
	var base_row_index: int = mini(ceili(length), row_colors.size()) - 1
	var base_color: Color = TIP_COLOR if base_row_index == 1 else row_colors[base_row_index]
	EarthBaseLook.draw(self, source_face, earth_tuning.column_width, base_color, OUTLINE_COLOR, [])

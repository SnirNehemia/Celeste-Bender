@tool
class_name RailPlatform
extends AnimatableBody2D
## Rail platform: a one-way steel platform that waits at the start of its RAIL and,
## once TRIGGERED, rides the rail at a constant speed (asked for after the W8c
## play-test). The rail can bend: it is several straight pieces, corner to corner.
##
## Triggered by:
##   - its linked SWITCHES (`switches`, linked in the level editor with L, like a
##     door): the first time any of them turns on, it starts.
##   - with no switches linked: standing on it. The first time you (or a crate)
##     land on it, it starts.
## Once started it doesn't stop for the switch turning off again: "after it is
## triggered, it starts moving". At the end of the rail, `end_behavior` says what
## happens: STOP there, go BACK_AND_FORTH along the rail forever, or LOOP (a straight
## piece back from the last corner to the start, round and round).
## Death or R puts it back at the start, waiting (Room.RESETTABLE_GROUP).
##
## The rail: the node's position is the START (where it waits); `rail_points` are the
## corners after it, relative to the start, in px. [(48, 0)] = 48 px to the right;
## [(48, 0), (48, -32)] = right, then up. In the level editor each corner has a drag
## handle, and the panel's buttons add or remove the last corner.
##
## Place the node at the CENTER of the platform's top surface (where your feet go),
## like the leaf and metal platforms; `platform_width` grows it to both sides.
##
## Why AnimatableBody2D? Godot's body for solids moved by script: setting its position
## in _physics_process (sync_to_physics) lets Godot work out its velocity, so a player
## standing on it is carried along smoothly. One-way: the shape's one_way_collision
## makes it solid only from above (jump up through it, land on top).
##
## It only moves in the room you're in (GameState.current_room), so in the level
## editor (no room is "current") it never starts, whatever crates or plates do there.

enum EndBehavior { STOP, BACK_AND_FORTH, LOOP }

## Thickness of the solid top, px (the same as the leaf and metal platforms').
const SURFACE_THICKNESS: float = 4.0
## Height of the drawn plate, px.
const DRAWN_HEIGHT: float = 5.0
## The rail runs this far under the top's middle, through the clamp under the plate.
const RAIL_OFFSET: Vector2 = Vector2(0.0, 8.0)
## One rivet every this many px along the plate.
const RIVET_SPACING: float = 8.0
## Not in the §2 color key: blue-gray steel, the rail's color family (RailTrack), so
## platform and rail read as one machine.
const PLATE_COLOR: Color = Color(0.42, 0.47, 0.56)
const RIM_COLOR: Color = Color(0.68, 0.73, 0.82)
const EDGE_COLOR: Color = Color(0.24, 0.27, 0.33)
## The lamp on the plate: red while it waits, green while it moves, gray when done.
const LAMP_WAITING_COLOR: Color = Color(0.85, 0.25, 0.2)
const LAMP_MOVING_COLOR: Color = Color(0.4, 1.0, 0.45)
const LAMP_DONE_COLOR: Color = Color(0.5, 0.5, 0.55)
## Editor-only dashed lines to the linked switches (Godot's own editor; the level
## editor draws links itself).
const LINK_LINE_COLOR: Color = Color(0.6, 0.72, 0.9, 0.6)

## Physics frames after a reset during which landing on it doesn't count: a rider's
## last floor contact (from before the reset) still names this platform for a frame.
const RESET_GRACE_FRAMES: int = 2

## Width of the platform, px.
@export var platform_width: float = 24.0:
	set(value):
		platform_width = maxf(value, 8.0)
		_resize_surface()
		queue_redraw()
## The rail's corners after the start, relative to it, px (see the header).
@export var rail_points: PackedVector2Array = PackedVector2Array([Vector2(48, 0)]):
	set(value):
		rail_points = value
		queue_redraw()
## Speed along the rail once triggered, px/s. Constant: no easing at the corners.
@export var speed: float = 40.0:
	set(value):
		speed = maxf(value, 1.0)
## What it does at the end of the rail.
@export var end_behavior: EndBehavior = EndBehavior.STOP:
	set(value):
		end_behavior = value
		queue_redraw()  # LOOP draws the closing piece of rail
## The switches that start it. None: standing on it starts it.
@export var switches: Array[Switch] = []:
	set(value):
		switches = value
		queue_redraw()

## The start, in the parent's coordinates (the room).
var home_position: Vector2
## How far along the rail it is, px (0 = the start).
var distance_along_rail: float = 0.0
## +1 going out along the rail, -1 coming back (BACK_AND_FORTH only).
var direction_sign: float = 1.0
## Triggered and moving; and stopped for good at the end (STOP), for the lamp.
var is_running: bool = false
var has_finished: bool = false
var reset_grace_left: int = 0

var surface: CollisionShape2D


func _ready() -> void:
	collision_layer = 1  # layer 1 "world": the player stands on it
	collision_mask = 0   # it moves by script; it doesn't need to detect anything
	surface = CollisionShape2D.new()
	surface.shape = RectangleShape2D.new()
	surface.one_way_collision = true  # solid only from above
	add_child(surface)
	_resize_surface()
	set_process(Engine.is_editor_hint())  # _process only draws link lines in Godot's editor
	if Engine.is_editor_hint():
		return
	home_position = position
	add_to_group(Room.RESETTABLE_GROUP)
	for linked_switch: Switch in switches:
		if linked_switch == null:
			push_warning("[RailPlatform] %s has an empty slot in `switches`" % name)
			continue
		# The signal passes the switch's new state: on = go.
		linked_switch.switched.connect(_on_switch_changed)


func _process(_delta: float) -> void:
	# Godot's own editor only: keep the link lines following the switches as they move.
	if Engine.is_editor_hint():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _is_in_current_room():
		return
	if not is_running:
		if reset_grace_left > 0:
			reset_grace_left -= 1
		elif not has_finished and switches.is_empty() and _is_stood_on():
			trigger()
		return
	_advance(delta)
	# Moving an AnimatableBody2D = setting its position inside _physics_process.
	# round() keeps it on whole pixels, so it and a rider don't shimmer by a sub-pixel.
	position = home_position + get_offset_at(distance_along_rail).round()
	queue_redraw()  # the rail stays still on screen while the plate moves along it


## Starts it moving (once: a running or finished platform ignores it).
func trigger() -> void:
	if is_running or has_finished or not _is_in_current_room():
		return
	is_running = true
	direction_sign = 1.0
	queue_redraw()  # the lamp turns green


func _on_switch_changed(is_now_on: bool) -> void:
	if is_now_on:
		trigger()


## One physics frame along the rail at `speed`, and what happens at its end.
func _advance(delta: float) -> void:
	var rail_length: float = get_rail_length()
	if rail_length <= 0.0:
		is_running = false
		has_finished = true
		return
	distance_along_rail += speed * delta * direction_sign
	match end_behavior:
		EndBehavior.STOP:
			if distance_along_rail >= rail_length:
				distance_along_rail = rail_length
				is_running = false
				has_finished = true
		EndBehavior.BACK_AND_FORTH:
			# Past an end: bounce back by however far it overshot.
			if distance_along_rail >= rail_length:
				distance_along_rail = 2.0 * rail_length - distance_along_rail
				direction_sign = -1.0
			elif distance_along_rail <= 0.0:
				distance_along_rail = -distance_along_rail
				direction_sign = 1.0
		EndBehavior.LOOP:
			distance_along_rail = fposmod(distance_along_rail, rail_length)


## The rail's corners from the start, relative to it: (0, 0), then rail_points, and
## for LOOP the start again (the closing piece).
func get_corners() -> PackedVector2Array:
	var corners: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	corners.append_array(rail_points)
	if end_behavior == EndBehavior.LOOP and not rail_points.is_empty():
		corners.append(Vector2.ZERO)
	return corners


## The whole rail's length, px.
func get_rail_length() -> float:
	var corners: PackedVector2Array = get_corners()
	var length: float = 0.0
	for index: int in corners.size() - 1:
		length += corners[index].distance_to(corners[index + 1])
	return length


## Where the platform is `distance` px along the rail, relative to the start.
func get_offset_at(distance: float) -> Vector2:
	var corners: PackedVector2Array = get_corners()
	var left: float = maxf(distance, 0.0)
	for index: int in corners.size() - 1:
		var piece_length: float = corners[index].distance_to(corners[index + 1])
		if left <= piece_length and piece_length > 0.0:
			return corners[index].lerp(corners[index + 1], left / piece_length)
		left -= piece_length
	return corners[corners.size() - 1]  # past the end: at the last corner


## Is the room it's in the one being played? (Never true in the level editor.)
func _is_in_current_room() -> bool:
	return GameState.current_room != null and GameState.current_room == get_parent()


## Is the player or a crate standing on it? Each is a CharacterBody2D whose last
## move_and_slide() ended on our top: Godot keeps that move's collisions.
func _is_stood_on() -> bool:
	var standers: Array[Node] = get_tree().get_nodes_in_group(WaterWorld.SOLID_GROUP)
	var player: Node = get_tree().get_first_node_in_group(Player.GROUP)
	if player != null and not standers.has(player):
		standers.append(player)
	for member: Node in standers:
		var character: CharacterBody2D = member as CharacterBody2D
		if character == null or not character.is_on_floor():
			continue
		for collision_index: int in character.get_slide_collision_count():
			if character.get_slide_collision(collision_index).get_collider() == self:
				return true
	return false


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	is_running = false
	has_finished = false
	distance_along_rail = 0.0
	direction_sign = 1.0
	reset_grace_left = RESET_GRACE_FRAMES
	position = home_position
	queue_redraw()


## Keeps the solid top as wide as the platform, its top edge on the node's origin.
func _resize_surface() -> void:
	if surface == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	(surface.shape as RectangleShape2D).size = Vector2(platform_width, SURFACE_THICKNESS)
	surface.position = Vector2(0.0, SURFACE_THICKNESS / 2.0)


func _draw() -> void:
	# The rail first, so it's behind the plate. It stays put while the plate moves:
	# draw it from the start, relative to where the plate is now.
	var home_local: Vector2 = Vector2.ZERO
	if not Engine.is_editor_hint():
		home_local = home_position - position
	var corners: PackedVector2Array = get_corners()
	for index: int in corners.size() - 1:
		RailTrack.draw(self, home_local + corners[index] + RAIL_OFFSET, home_local + corners[index + 1] + RAIL_OFFSET)

	var left: float = -platform_width / 2.0
	# The clamp from the plate down to the rail.
	draw_rect(Rect2(-2.0, DRAWN_HEIGHT, 4.0, RAIL_OFFSET.y - DRAWN_HEIGHT + 1.5), EDGE_COLOR)
	draw_circle(RAIL_OFFSET, 1.5, RIM_COLOR)
	# The plate: body, lit rim on top, dark edge underneath, rivets.
	draw_rect(Rect2(left, 0.0, platform_width, DRAWN_HEIGHT), PLATE_COLOR)
	draw_rect(Rect2(left, 0.0, platform_width, 1.0), RIM_COLOR)
	draw_rect(Rect2(left, DRAWN_HEIGHT - 1.0, platform_width, 1.0), EDGE_COLOR)
	var rivet_count: int = maxi(1, floori(platform_width / RIVET_SPACING))
	var spacing: float = platform_width / rivet_count
	for rivet_index: int in rivet_count:
		draw_rect(Rect2(left + spacing * (rivet_index + 0.5) - 0.5, 2.0, 1.0, 1.0), EDGE_COLOR)
	# The lamp in the middle says what it's doing.
	var lamp_color: Color = LAMP_WAITING_COLOR
	if is_running:
		lamp_color = LAMP_MOVING_COLOR
	elif has_finished:
		lamp_color = LAMP_DONE_COLOR
	draw_rect(Rect2(-1.0, 1.5, 2.0, 2.0), lamp_color)
	if Engine.is_editor_hint():
		for linked_switch: Switch in switches:
			if linked_switch != null:
				draw_dashed_line(Vector2.ZERO, to_local(linked_switch.global_position), LINK_LINE_COLOR, 1.0, 3.0)

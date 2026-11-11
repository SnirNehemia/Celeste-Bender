@tool
class_name RailPlatform
extends AnimatableBody2D
## Rail platform: a one-way steel platform that waits at the start of its RAIL and,
## once TRIGGERED, rides the rail at a constant speed (asked for after the W8c
## play-test). The rail can bend: it is several straight pieces, corner to corner.
##
## Triggered by:
##   - its FORWARD switches (`switches`, linked in the level editor with L, like a
##     door): whenever one turns on, it rides along the rail, away from the start.
##   - its BACKWARD switches (`backward_switches`, L a second time in the editor):
##     whenever one turns on, it rides back toward the start. So one set of
##     switches sends it out and another brings it home (asked for after the hub
##     play-test). A switch that stays on (a step pad) sends it only once; a
##     pressure plate sends it every time something lands on it.
##   - with no switches linked at all: standing on it. The first time you (or a
##     crate) land on it, it starts.
## Once moving it doesn't stop for a switch turning off again. At an end of the
## rail, `end_behavior` says what happens: STOP there (until a switch sends it the
## other way), go BACK_AND_FORTH along the rail forever, or LOOP (a straight piece
## back from the last corner to the start, round and round; backward runs it the
## other way round). Death or R puts it back at the start, waiting
## (Room.RESETTABLE_GROUP).
##
## PASSENGERS: level objects placed standing on its top (a step pad, a pressure
## plate, a key light: their origin on its surface, within its width) ride with
## it. Found once when the level starts (_find_passengers), moved every frame by
## the same amount, put back with it on a reset. Bodies (the player, crates,
## enemies) aren't passengers: they ride by physics, standing on it.
##
## A switch in another room (or another depth) can send it: it remembers the
## order and moves once you're in its room.
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

## A placed object counts as standing on it (a passenger) if its origin is within
## this many px of the top surface's height.
const PASSENGER_TOLERANCE: float = 1.0
## Physics frames after a reset during which landing on it doesn't count: a rider's
## last floor contact (from before the reset) still names this platform for a frame.
## Also how long switches are ignored after a reset (send()).
const RESET_GRACE_FRAMES: int = 3

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
## FORWARD switches: on = ride along the rail. None (and no backward ones either):
## standing on it starts it.
@export var switches: Array[Switch] = []:
	set(value):
		switches = value
		queue_redraw()
## BACKWARD switches: on = ride back toward the start.
@export var backward_switches: Array[Switch] = []:
	set(value):
		backward_switches = value
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
## Level objects standing on it (see PASSENGERS in the header) -> their offset
## from the platform's position.
var passenger_offsets: Dictionary = {}

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
		# The signal passes the switch's new state: on = go. bind() adds one more
		# argument after it, which says which way.
		linked_switch.switched.connect(_on_switch_changed.bind(1.0))
	for linked_switch: Switch in backward_switches:
		if linked_switch == null:
			push_warning("[RailPlatform] %s has an empty slot in `backward_switches`" % name)
			continue
		linked_switch.switched.connect(_on_switch_changed.bind(-1.0))
	_find_passengers()


func _process(_delta: float) -> void:
	# Godot's own editor only: keep the link lines following the switches as they move.
	if Engine.is_editor_hint():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if reset_grace_left > 0:
		reset_grace_left -= 1
	if not _is_in_current_room():
		return
	if not is_running:
		if reset_grace_left > 0:
			pass  # just reset: a stale floor contact doesn't count
		elif not has_finished and switches.is_empty() and backward_switches.is_empty() and _is_stood_on():
			trigger()
		return
	_advance(delta)
	_move_to_rail_position()
	queue_redraw()  # the rail stays still on screen while the plate moves along it


## Puts the platform where distance_along_rail says, and its passengers with it.
func _move_to_rail_position() -> void:
	# Moving an AnimatableBody2D = setting its position inside _physics_process.
	# round() keeps it on whole pixels, so it and a rider don't shimmer by a sub-pixel.
	var target: Vector2 = home_position + get_offset_at(distance_along_rail).round()
	position = target
	# From `target`, not `position`: an AnimatableBody2D that syncs to physics
	# reads back LAST frame's position right after being moved, and the passengers
	# would trail a pixel behind.
	for passenger: Variant in passenger_offsets:
		if is_instance_valid(passenger):
			(passenger as Node2D).position = target + passenger_offsets[passenger]


## Starts it moving forward, along the rail (standing on it, or a forward switch).
func trigger() -> void:
	send(1.0)


## Sends it along the rail (`direction` 1) or back toward the start (-1). A STOP
## platform already at that end stays put. Remembered even when its room isn't
## the one being played (a switch elsewhere): it moves once you're there. Never
## in the level editor (no room is being played there).
func send(direction: float) -> void:
	if GameState.current_room == null:
		return
	# Just reset: ignore switches for a few frames. A switch's Area2D still sees
	# what stood on it before the reset (overlaps refresh a frame late), so a step
	# pad the player died on would send it off again right after the reset.
	if reset_grace_left > 0:
		return
	if end_behavior == EndBehavior.STOP:
		var at_far_end: bool = direction > 0.0 and distance_along_rail >= get_rail_length()
		var at_start: bool = direction < 0.0 and distance_along_rail <= 0.0
		if at_far_end or at_start:
			return
	direction_sign = direction
	is_running = true
	has_finished = false
	queue_redraw()  # the lamp turns green


## A linked switch changed; `direction` is bound per list (1 forward, -1 backward).
func _on_switch_changed(is_now_on: bool, direction: float) -> void:
	if is_now_on:
		send(direction)


## The level objects standing on the platform's top when the level starts: placed
## scene instances (not nodes made in code, not bodies) among the room's children
## whose origin is on the top surface, within its width.
func _find_passengers() -> void:
	passenger_offsets.clear()
	var parent: Node = get_parent()
	if parent == null:
		return
	for sibling: Node in parent.get_children():
		var object: Node2D = sibling as Node2D
		if object == null or object == self or object.scene_file_path == "":
			continue
		if object is PhysicsBody2D:
			continue  # bodies ride by physics (or are other platforms)
		var offset: Vector2 = object.position - position
		if absf(offset.y) <= PASSENGER_TOLERANCE and absf(offset.x) <= platform_width / 2.0:
			passenger_offsets[object] = offset


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
			elif distance_along_rail <= 0.0 and direction_sign < 0.0:
				# Back home: waiting again (red lamp), for a forward switch.
				distance_along_rail = 0.0
				is_running = false
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
	_move_to_rail_position()  # home, with its passengers
	queue_redraw()
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
		# Where the start is from the plate, worked out from distance_along_rail,
		# NOT from `position`: right after a move (a reset), an AnimatableBody2D
		# still reads back its old position, and the rail was drawn shifted by it.
		home_local = -get_offset_at(distance_along_rail).round()
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
		for linked_switch: Switch in switches + backward_switches:
			if linked_switch != null:
				draw_dashed_line(Vector2.ZERO, to_local(linked_switch.global_position), LINK_LINE_COLOR, 1.0, 3.0)

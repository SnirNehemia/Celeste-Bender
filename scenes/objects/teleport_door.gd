@tool
class_name TeleportDoor
extends Area2D
## TeleportDoor: a ONE-WAY door. Stand in an ENTRANCE and press Up (move_up): you
## come out of the EXIT of the same color, anywhere in the level (another room,
## another depth). An exit does nothing when you press Up in it: there is no way
## back through. For shortcuts back to a hub at the end of a long wing.
##
## Pairs are matched by COLOR (`door_color`, the KeyColors list), not by an editor
## link, so the two doors can be in different rooms (links only reach inside one
## room), and the player can tell which door leads where: a red entrance, a red exit.
## `is_exit` says which end a door is. Several entrances may share one exit. An
## entrance with no exit of its color is drawn dim and does nothing.
##
## Looks: both are a door frame in the pair's color. The entrance is open, a dark
## doorway with chevrons moving inward; the exit is shut, a plain panel with a
## chevron pointing out.
##
## Place the node at the TOP-LEFT of the frame (DOOR_SIZE); it stands on the floor,
## like a depth gate.
## Physics: an Area2D on no layer that watches layer 2 ("player").
## Signals: use_requested(door), heard by RoomManager.go_through_teleport (connected
## in its _ready), which moves the player and the camera.
##
## @tool: it draws itself in the editor too.

## Up was pressed while the player stands in this entrance, and it has an exit.
signal use_requested(door: TeleportDoor)

## Every teleport door joins it (RoomManager connects them; find_exit searches it).
const GROUP: StringName = &"teleport_doors"
## The frame's size, px: the depth gate's (one tile wider than the player, three tall).
const DOOR_SIZE: Vector2 = Vector2(16, 24)
const INSIDE_COLOR: Color = Color(0.07, 0.06, 0.1)
const ARROW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
## An entrance with no exit, in play: drawn this dim.
const NO_EXIT_MODULATE: Color = Color(0.55, 0.55, 0.6, 0.7)
## The exit's shut panel: its color this much darker than the frame.
const PANEL_DARKEN: float = 0.45
## How fast the entrance's chevrons drift inward, cycles per second.
const CHEVRON_SPEED: float = 1.2

## Which pair it belongs to.
@export var door_color: KeyColors.Name = KeyColors.Name.BLUE:
	set(value):
		door_color = value
		queue_redraw()
		_refresh_every_door()
## Off: an entrance (Up goes through). On: the exit you come out of.
@export var is_exit: bool = false:
	set(value):
		is_exit = value
		queue_redraw()
		_refresh_every_door()

## The player standing in the door, or null.
var _player_inside: Player = null
## Seconds since the door appeared (the chevrons, the bobbing arrow).
var _time: float = 0.0
## In a running level (its room's parent is a RoomManager), not the editor.
var _is_playing: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 2  # bit value of layer 2, "player"
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = DOOR_SIZE
	shape_node.shape = shape
	shape_node.position = DOOR_SIZE / 2.0  # shapes are positioned by center
	add_child(shape_node)
	if Engine.is_editor_hint():
		return
	var room: Room = Room.find_room_of(self)
	_is_playing = room != null and room.get_parent() is RoomManager
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Deferred: the exit's room may come later in the level and isn't in the group
	# yet; deferred calls run once every node is ready.
	_refresh_every_door.call_deferred()


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if Engine.is_editor_hint() or is_exit or _player_inside == null:
		return
	if Input.is_action_just_pressed("move_up") and not _player_inside.is_dead() and find_exit() != null:
		use_requested.emit(self)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = body as Player


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null


## Where the player's feet go when they come out of this door: the middle of its floor.
func get_feet_position() -> Vector2:
	return global_position + Vector2(DOOR_SIZE.x / 2.0, DOOR_SIZE.y)


## The exit of this door's color in the same level (rooms with the same parent), or
## null. With several, the first in tree order: give each pair its own color.
func find_exit() -> TeleportDoor:
	var room: Room = Room.find_room_of(self)
	if room == null or not is_inside_tree():
		return null
	for member: Node in get_tree().get_nodes_in_group(GROUP):
		var door: TeleportDoor = member as TeleportDoor
		if door == null or door == self or not door.is_exit or door.door_color != door_color:
			continue
		var door_room: Room = Room.find_room_of(door)
		# Only this level's doors: during a play-test the editor's copy of the level
		# is in the tree for a frame, its doors at the very same places.
		if door_room != null and door_room.get_parent() == room.get_parent():
			return door
	return null


## Dims every entrance that has no exit (in play and in the level editor, whose
## level is a RoomManager's too). All of them, not only this one: a new exit, or a
## door whose color changed, changes which OTHER doors lead somewhere.
func _refresh_every_door() -> void:
	if not is_inside_tree():
		return  # a setter running while the scene loads
	for member: Node in get_tree().get_nodes_in_group(GROUP):
		(member as TeleportDoor)._refresh_dim()


func _refresh_dim() -> void:
	if not _is_playing:
		return
	modulate = NO_EXIT_MODULATE if not is_exit and find_exit() == null else Color.WHITE


func _draw() -> void:
	var frame_color: Color = KeyColors.get_color(door_color)
	var width: float = DOOR_SIZE.x
	var height: float = DOOR_SIZE.y
	var middle: float = width / 2.0
	if is_exit:
		# Shut: a panel in the pair's color, darker, with a chevron pointing OUT (down,
		# toward the floor you step onto).
		draw_rect(Rect2(2.0, 2.0, width - 4.0, height - 2.0), frame_color.darkened(PANEL_DARKEN))
		_draw_chevron(Vector2(middle, height * 0.55), 1.0, Color(frame_color, 0.9))
	else:
		# Open: a dark doorway, two chevrons drifting up and in.
		draw_rect(Rect2(2.0, 2.0, width - 4.0, height - 2.0), INSIDE_COLOR)
		for index: int in 2:
			var along: float = fmod(_time * CHEVRON_SPEED + index * 0.5, 1.0)
			var chevron_y: float = roundf(lerpf(height - 5.0, 7.0, along))
			_draw_chevron(Vector2(middle, chevron_y), -1.0, Color(frame_color, 1.0 - along))
	# The frame: two posts and a lintel, in the pair's color.
	draw_rect(Rect2(0.0, 0.0, 2.0, height), frame_color)
	draw_rect(Rect2(width - 2.0, 0.0, 2.0, height), frame_color)
	draw_rect(Rect2(0.0, 0.0, width, 2.0), frame_color)
	draw_rect(Rect2(0.0, 0.0, width, 1.0), frame_color.lightened(0.4))
	# The Up arrow while the player stands in an entrance that leads somewhere.
	if _is_playing and not is_exit and _player_inside != null and find_exit() != null:
		var bob: float = roundf(sin(_time * TAU))
		_draw_chevron(Vector2(middle, -8.0 + bob), -1.0, ARROW_COLOR)
		draw_rect(Rect2(middle - 0.5, -6.0 + bob, 1.0, 3.0), ARROW_COLOR)


## A 5 px wide chevron with its tip at `tip`, pointing up (`direction` -1) or down
## (+1). Whole-pixel rects, so it stays crisp.
func _draw_chevron(tip: Vector2, direction: float, color: Color) -> void:
	for row: int in 3:
		var row_y: float = roundf(tip.y) - row * direction
		draw_rect(Rect2(roundf(tip.x) - row - 0.5, row_y, 1.0, 1.0), color)
		draw_rect(Rect2(roundf(tip.x) + row - 0.5, row_y, 1.0, 1.0), color)

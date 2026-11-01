class_name DepthGate
extends Area2D
## DepthGate: a stone arch with a slowly turning swirl inside, the way between a
## room and the room BEHIND it (Level_editor.md §5a, Stage D2). Gates come in
## pairs: a gate and its TWIN at the same spot on the map, one depth apart. Stand
## in one and press Up (move_up): RoomManager.go_through_gate takes you to the twin,
## into the layer behind (or back out of it).
##
## The twin is FOUND, never stored (find_twin): the gate in a room one depth
## deeper (or shallower) whose map position is within half a tile of this one's.
## So there are no saved links to keep in sync, and nothing breaks when a room is
## copied, imported or moved: a gate simply has no twin until one lines up.
##
## Inside the arch an ARROW says where it leads: up = deeper (into the screen),
## down = back out toward the front (after the D play-test). The bobbing arrow ABOVE
## the gate, while the player stands in it, always points up: Up is the key either way.
##
## Place the node at the TOP-LEFT of the arch (GATE_SIZE); it stands on the floor.
## Physics: an Area2D on no layer that watches layer 2 ("player").
## Signals: use_requested(gate), heard by RoomManager (connected in its _ready).

## Up was pressed while the player stands in this gate, and it has a twin.
signal use_requested(gate: DepthGate)

## Every gate joins it (RoomManager connects them all; find_twin searches it).
const GROUP: StringName = &"depth_gates"
## The arch's size, px: one tile wider than the player, three tiles tall.
const GATE_SIZE: Vector2 = Vector2(16, 24)
## How far apart (map px) a gate and its twin may be and still pair up.
const TWIN_REACH: float = 4.0
## Placeholder colors (GAME_DESIGN.md §2): cool gray stone, and the haze blue of
## the layer behind (back_room_haze.gdshader) for the swirl, so the arch reads as
## "a window into the hazed layer". Switches are yellow and doors brown: no clash.
const STONE_COLOR: Color = Color(0.42, 0.45, 0.55)
const STONE_EDGE_COLOR: Color = Color(0.62, 0.66, 0.78)
const SWIRL_COLOR: Color = Color(0.55, 0.7, 1.0)
const INSIDE_COLOR: Color = Color(0.2, 0.24, 0.38, 0.85)
const ARROW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
## Turns per second of the swirl, and how fast the glow pulses (per second).
const SWIRL_SPEED: float = 0.25
const GLOW_PULSE_SPEED: float = 1.6
## A gate with no twin, in play: drawn this dim, and it does nothing (Stage D4).
const NO_TWIN_MODULATE: Color = Color(0.55, 0.55, 0.6, 0.7)
## The arrow inside the arch (where the gate leads).
const INNER_ARROW_COLOR: Color = Color(0.9, 0.96, 1.0, 1.0)
## The arrows' shape (_draw_arrow): head rows, and the stem's length, px.
const ARROW_HEAD_ROWS: int = 3
const ARROW_STEM_LENGTH: float = 3.0

var collision_shape_node: CollisionShape2D
## The player standing in the gate (body_entered / body_exited), or null.
var _player_inside: Player = null
## Seconds since the gate appeared: turns the swirl and pulses the glow.
var _time: float = 0.0
## In a running level (its room's parent is a RoomManager), not the editor.
var _is_playing: bool = false
## Where the twin is: +1 behind (deeper), -1 in front, 0 none (refresh_twin).
var _twin_direction: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 2  # bit value of layer 2, "player"
	collision_shape_node = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = GATE_SIZE
	collision_shape_node.shape = shape
	collision_shape_node.position = GATE_SIZE / 2.0  # shapes are positioned by center
	add_child(collision_shape_node)
	var room: Room = Room.find_room_of(self)
	_is_playing = room != null and room.get_parent() is RoomManager
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Deferred: the twin's room may come later in the level and isn't ready (in
	# the group) yet; deferred calls run once every node is ready.
	refresh_twin.call_deferred()


## Looks for the twin again: the inner arrow's direction, and in play a gate with
## no twin is dimmed (Stage D4): it leads nowhere. The editor calls it after every
## change (the gate doesn't run while editing).
func refresh_twin() -> void:
	if not is_inside_tree():
		return
	var twin: DepthGate = find_twin()
	_twin_direction = 0 if twin == null else signi(twin.get_depth() - get_depth())
	if _is_playing:
		modulate = NO_TWIN_MODULATE if twin == null else Color.WHITE
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _player_inside != null and Input.is_action_just_pressed("move_up") and not _player_inside.is_dead():
		if find_twin() != null:
			use_requested.emit(self)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = body as Player


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null


## Where the inner arrow points: +1 up (leads deeper), -1 down (leads out), 0 no twin.
func get_twin_direction() -> int:
	return _twin_direction


## True while the player stands in the gate (the Up arrow shows).
func is_player_inside() -> bool:
	return _player_inside != null


## The arch's rectangle in world coordinates.
func get_gate_rect() -> Rect2:
	return Rect2(global_position, GATE_SIZE)


## This gate's depth: its band's (Room.depth_at).
func get_depth() -> int:
	return Room.depth_at(global_position.y + GATE_SIZE.y / 2.0)


## The twin `direction` depths away (+1: the gate behind, -1: the one in front),
## or null. See the header.
func find_twin_in(direction: int) -> DepthGate:
	return find_gate_at(get_tree(), Room.find_room_of(self), global_position + Room.depth_offset(direction), self)


## The twin Up leads to: the one behind if there is one, else the one in front.
## (A gate with twins on both sides leads behind; put gates side by side to chain
## depths.) Null: no twin, Up does nothing.
func find_twin() -> DepthGate:
	var behind: DepthGate = find_twin_in(1)
	return behind if behind != null else find_twin_in(-1)


## The gate of the same level as `room` (rooms with the same parent) whose
## top-left is within TWIN_REACH of `world_point`, `ignore` aside; the closest one,
## or null. Static, so the editor can ask about a spot before a gate is there.
static func find_gate_at(tree: SceneTree, room: Room, world_point: Vector2, ignore: DepthGate = null) -> DepthGate:
	if tree == null or room == null:
		return null
	var level: Node = room.get_parent()
	var best: DepthGate = null
	var best_distance: float = TWIN_REACH
	for member: Node in tree.get_nodes_in_group(GROUP):
		var gate: DepthGate = member as DepthGate
		if gate == null or gate == ignore or not gate.is_inside_tree():
			continue
		var gate_room: Room = Room.find_room_of(gate)
		# Only this level's gates: during a play-test the editor's copy of the level
		# is in the tree for a frame, its gates at the very same places.
		if gate_room == null or gate_room.get_parent() != level:
			continue
		var distance: float = gate.global_position.distance_to(world_point)
		if distance <= best_distance:
			best = gate
			best_distance = distance
	return best


func _draw() -> void:
	var width: float = GATE_SIZE.x
	var height: float = GATE_SIZE.y
	var arch_radius: float = width / 2.0
	var arch_center: Vector2 = Vector2(arch_radius, arch_radius)
	# The opening: a dark hazed inside, a round top on straight sides.
	var opening: PackedVector2Array = PackedVector2Array()
	for step: int in 9:
		var angle: float = PI + PI * step / 8.0  # left side over the top to the right
		opening.append(arch_center + Vector2(cos(angle), sin(angle)) * (arch_radius - 2.0))
	opening.append(Vector2(width - 2.0, height))
	opening.append(Vector2(2.0, height))
	draw_colored_polygon(opening, INSIDE_COLOR)
	# The swirl: three arms turning, brighter while the glow pulses (play only;
	# in the editor the level doesn't run, so it stays still).
	var glow: float = 0.65 + 0.35 * sin(_time * TAU * GLOW_PULSE_SPEED / 2.0)
	var swirl_center: Vector2 = Vector2(arch_radius, height * 0.55)
	for arm: int in 3:
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in 7:
			var along: float = step / 6.0
			# Each arm curls about 2.4 radians (~140 degrees) from the middle outward.
			var angle: float = _time * TAU * SWIRL_SPEED + arm * TAU / 3.0 + along * 2.4
			points.append(swirl_center + Vector2(cos(angle), sin(angle)) * (1.0 + along * 5.0))
		# Dimmer behind an arrow, so the arrow reads first.
		draw_polyline(points, Color(SWIRL_COLOR, (0.45 if _twin_direction != 0 else 0.8) * glow), 1.0)
	# Where it leads: the same arrow as the one above the gate, in the opening,
	# bobbing the way it points: up = deeper, down = toward the front.
	if _twin_direction != 0:
		var pointing_up: bool = _twin_direction > 0
		var bob: float = roundf(sin(_time * TAU)) * (-1.0 if pointing_up else 1.0)
		var tip_y: float = roundf(height * 0.55) + (-3.0 if pointing_up else 3.0) + bob
		# Pulses gently with the glow, but never fades into the swirl.
		_draw_arrow(Vector2(arch_radius, tip_y), pointing_up, Color(INNER_ARROW_COLOR, INNER_ARROW_COLOR.a * (0.75 + 0.25 * glow)))
	# The stone: two pillars and the arch over them, with a lighter rim.
	draw_rect(Rect2(0.0, arch_radius, 2.0, height - arch_radius), STONE_COLOR)
	draw_rect(Rect2(width - 2.0, arch_radius, 2.0, height - arch_radius), STONE_COLOR)
	draw_arc(arch_center, arch_radius - 1.0, PI, TAU, 12, STONE_COLOR, 2.0)
	draw_arc(arch_center, arch_radius, PI, TAU, 12, STONE_EDGE_COLOR, 1.0)
	# A keystone on top, and the Up arrow while the player stands inside (Stage D4).
	draw_rect(Rect2(arch_radius - 1.5, -1.0, 3.0, 3.0), STONE_EDGE_COLOR)
	if _is_playing and _player_inside != null and find_twin() != null:
		var bob: float = roundf(sin(_time * TAU) * 1.0)
		_draw_arrow(Vector2(arch_radius, -9.0 + bob), true, ARROW_COLOR)


## A small pixel arrow pointing up or down, its tip in the pixel column right of
## `tip`'s x (the arch's middle line falls between two pixels): a head of rows 1, 3
## and 5 px wide, then a 1 px stem 3 px long. Whole-pixel rects, so it stays crisp.
## Both arrows of the gate use it.
func _draw_arrow(tip: Vector2, pointing_up: bool, color: Color) -> void:
	var step: float = 1.0 if pointing_up else -1.0  # from the tip toward the stem
	var tip_row: float = roundf(tip.y)
	for row: int in ARROW_HEAD_ROWS:
		var row_y: float = tip_row + row * step
		draw_rect(Rect2(roundf(tip.x) - row, row_y if pointing_up else row_y - 1.0, row * 2 + 1, 1.0), color)
	var stem_start: float = tip_row + ARROW_HEAD_ROWS * step
	draw_rect(Rect2(roundf(tip.x), stem_start if pointing_up else stem_start - ARROW_STEM_LENGTH, 1.0, ARROW_STEM_LENGTH), color)

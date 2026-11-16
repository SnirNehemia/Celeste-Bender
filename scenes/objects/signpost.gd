@tool
class_name Signpost
extends Node2D
## Signpost: a small wooden sign that shows one line of text (`text`) in a box
## above it while the player stands by it. For tutorials: "Hold C to jump higher".
##
## Place the node ON the floor, at the post's bottom middle (like a key light): a
## 2x2-tile square standing on the floor.
##
## How it works: an Area2D around the sign watches physics layer 2 ("player").
## While the player is inside, the text box fades in; it fades out when they leave.
## The box is a Label child (a Control node: Godot's UI building block, which also
## works inside the 2D world). It is kept inside the room's left and right edges, so
## a sign near a wall doesn't push its text off screen.
## Nothing to reset: the sign has no state a death could change.
##
## @tool: it draws itself in the editor too.

## The line shown. Long lines wrap (TEXT_BOX_WIDTH).
@export var text: String = "A sign.":
	set(value):
		text = value
		if text_label != null:
			text_label.text = text

## The look, px: the board on a post. Wood browns, like the crate (GAME_DESIGN.md §2).
const BOARD_RECT: Rect2 = Rect2(-7, -15, 14, 8)
const POST_RECT: Rect2 = Rect2(-1, -7, 2, 7)
const BOARD_COLOR: Color = Color(0.62, 0.45, 0.25)
const BOARD_EDGE_COLOR: Color = Color(0.36, 0.25, 0.14)
const WRITING_COLOR: Color = Color(0.25, 0.17, 0.1)
## The area the player must stand in, relative to the origin, px.
const READ_RECT: Rect2 = Rect2(-16, -24, 32, 24)
## The text box: its widest, how far above the board, and its colors.
const TEXT_BOX_WIDTH: float = 128.0
const TEXT_BOX_GAP: float = 4.0
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const TEXT_BACK_COLOR: Color = Color(0.08, 0.07, 0.12, 0.85)
const TEXT_FONT_SIZE: int = PixelFont.FONT_SIZE
## How fast the box fades in and out, per second.
const FADE_SPEED: float = 6.0
## Above the darkness of dark rooms (DarkRoomOverlay.DRAW_Z_INDEX), like the HUD-like
## world drawings: a sign can be read in the dark.
const TEXT_Z_INDEX: int = 40

var text_label: Label
var read_area: Area2D
## 0 = hidden, 1 = fully shown.
var shown_amount: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	read_area = Area2D.new()
	read_area.collision_layer = 0
	read_area.collision_mask = 2  # bit value of layer 2, "player"
	read_area.monitorable = false
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = READ_RECT.size
	shape_node.shape = shape
	shape_node.position = READ_RECT.get_center()
	read_area.add_child(shape_node)
	add_child(read_area)
	_build_label()


## The text box: a Label with a dark, rounded-off background (a StyleBoxFlat is a
## plain colored box a Control can draw behind itself).
func _build_label() -> void:
	text_label = Label.new()
	text_label.text = text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Whole pixels only (PixelFont): the box is part of the 320x180 world.
	text_label.add_theme_font_override("font", PixelFont.get_font())
	text_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	text_label.add_theme_color_override("font_color", TEXT_COLOR)
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = TEXT_BACK_COLOR
	back.set_content_margin_all(3.0)
	text_label.add_theme_stylebox_override("normal", back)
	text_label.z_index = TEXT_Z_INDEX
	text_label.z_as_relative = false
	text_label.modulate.a = 0.0
	text_label.visible = false
	add_child(text_label)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var wanted: float = 1.0 if _is_player_reading() else 0.0
	shown_amount = move_toward(shown_amount, wanted, FADE_SPEED * delta)
	text_label.modulate.a = shown_amount
	text_label.visible = shown_amount > 0.0
	if text_label.visible:
		_place_label()


func _is_player_reading() -> bool:
	for body: Node2D in read_area.get_overlapping_bodies():
		var player: Player = body as Player
		if player != null and not player.is_dead():
			return true
	return false


## Sizes the box to its text (no wider than TEXT_BOX_WIDTH) and puts it centered
## above the board, pushed back inside the room where it would stick out.
func _place_label() -> void:
	var font: Font = text_label.get_theme_font("font")
	var one_line_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_FONT_SIZE).x + 8.0
	text_label.size = Vector2(minf(one_line_width, TEXT_BOX_WIDTH), 0.0)
	text_label.size = Vector2(text_label.size.x, text_label.get_minimum_size().y)
	var box_position: Vector2 = Vector2(-text_label.size.x / 2.0, BOARD_RECT.position.y - TEXT_BOX_GAP - text_label.size.y)
	var room: Room = Room.find_room_of(self)
	if room != null:
		var bounds: Rect2 = room.get_bounds()
		var left: float = global_position.x + box_position.x
		box_position.x += maxf(bounds.position.x + 2.0 - left, 0.0)
		box_position.x -= maxf(left + text_label.size.x - (bounds.end.x - 2.0), 0.0)
	text_label.position = box_position.round()


func _draw() -> void:
	draw_rect(POST_RECT, BOARD_EDGE_COLOR)
	draw_rect(BOARD_RECT, BOARD_EDGE_COLOR)
	draw_rect(BOARD_RECT.grow(-1.0), BOARD_COLOR)
	# Two lines of "writing".
	draw_rect(Rect2(-4, -13, 8, 1), WRITING_COLOR)
	draw_rect(Rect2(-4, -11, 5, 1), WRITING_COLOR)

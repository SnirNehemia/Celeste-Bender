class_name Room
extends Node2D
## One room (one "screen", or a bit more if it scrolls). Base script for every room scene.
##
## A room is just a rectangle in world space plus its contents:
##   - bounds:       starts at this node's position, size `room_size`
##   - SpawnPoint:   a Marker2D child; the player respawns here after dying in this room
##   - solids:       built from `solid_rects` (an editable list in the Inspector)
##   - anything else (spikes, later crates, enemies...) as child nodes
##
## Rooms are placed next to each other in one world scene. "Exits" are simply openings
## in the walls: walking through one puts the player inside the neighbouring room's
## bounds, and RoomManager (the world's root script) notices and slides the camera over.
## Rooms don't know about each other or the camera; RoomManager does all of that.
##
## Stage 9 replaces `solid_rects` with a TileMapLayer for real level editing.

## Color for solid ground (GAME_DESIGN.md §2: dark gray).
const SOLID_COLOR: Color = Color(0.25, 0.25, 0.28)

## Size of the room in pixels. 320x180 = exactly one screen (camera stays still);
## bigger rooms make the camera scroll inside them.
@export var room_size: Vector2 = Vector2(320, 180)
## Solid blocks, in pixels, relative to the room's top-left corner. Each Rect2 is
## (x, y, width, height). Edit the list in the Inspector to reshape the room.
@export var solid_rects: Array[Rect2] = []

@onready var spawn_point: Marker2D = $SpawnPoint


func _ready() -> void:
	for rect: Rect2 in solid_rects:
		_add_solid_block(rect)


## The room's rectangle in world coordinates.
func get_bounds() -> Rect2:
	return Rect2(global_position, room_size)


## Where the player's feet go when respawning in this room.
func get_spawn_position() -> Vector2:
	return spawn_point.global_position


## Creates a StaticBody2D (an immovable solid on physics layer 1, "world") with a
## matching collision shape and gray rectangle.
func _add_solid_block(rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.position

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	# CollisionShape2D is positioned by its CENTER, so offset by half the size.
	shape.position = rect.size / 2.0
	body.add_child(shape)

	var visual: ColorRect = ColorRect.new()
	visual.size = rect.size
	visual.color = SOLID_COLOR
	body.add_child(visual)

	add_child(body)

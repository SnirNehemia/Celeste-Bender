class_name Room
extends Node2D
## One room (one "screen", or a bit more if it scrolls). Base script for every room scene.
##
## A room is just a rectangle in world space plus its contents:
##   - bounds:       starts at this node's position, size `room_size`
##   - SpawnPoint:   a Marker2D child; the player respawns here after dying in this room
##   - solids:       a TileMapLayer child named "Tiles" (the real rooms, room_01..05),
##                   painted with resources/tiles/placeholder_tileset.tres. The
##                   tileset gives every tile collision on layer 1 ("world"), so the
##                   TileMapLayer IS the ground; this script doesn't need to touch it.
##                   Older test rooms instead list `solid_rects` (an editable list in
##                   the Inspector), turned into blocks in _ready(). Both can be mixed.
##   - anything else (spikes, crates, enemies...) as child nodes
##
## Rooms are placed next to each other in one world scene. "Exits" are simply openings
## in the walls: walking through one puts the player inside the neighbouring room's
## bounds, and RoomManager (the world's root script) notices and slides the camera over.
## Rooms don't know about each other or the camera; RoomManager does all of that.
##
## Earth (Earth chapter): an optional second TileMapLayer child named "Earth" with the
## EarthLayer script (scenes/objects/earth/earth_layer.gd), painted with the earth
## tileset. It's solid like "Tiles", but each of its cells can be bent once.
##
## Resetting: puzzle objects (crates, windmills, leaves, doors) join the group
## RESETTABLE_GROUP and have a reset() method. RoomManager calls reset_objects() on
## the room when the player respawns in it, so a crate pushed into a corner never
## leaves the room unsolvable: dying or pressing R puts everything back.

## Color for solid ground (GAME_DESIGN.md §2: dark gray).
const SOLID_COLOR: Color = Color(0.25, 0.25, 0.28)
## Group for objects that go back to their starting state on reset_objects().
const RESETTABLE_GROUP: StringName = &"room_resettable"

## Human-readable name, e.g. "First Breath". Shown in the debug room picker (F2).
@export var display_title: String = ""
## Size of the room in pixels. 320x180 = exactly one screen (camera stays still);
## bigger rooms make the camera scroll inside them.
@export var room_size: Vector2 = Vector2(320, 180)
## Solid blocks, in pixels, relative to the room's top-left corner. Each Rect2 is
## (x, y, width, height). Used by the test rooms; new rooms paint a TileMapLayer instead.
@export var solid_rects: Array[Rect2] = []

@export_group("Elements")
## Which bending elements work in this room. The Earth chapter's rooms are
## Earth-only (Earth_bending.md §11), so a dash can't skip their puzzles.
## The player asks through Player.is_element_allowed(); the room only stores the flags.
## Air: dash, glide and gust.
@export var air_allowed: bool = true
## Earth: column, boulder and snake.
@export var earth_allowed: bool = true

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


## Puts every resettable object inside THIS room back to its starting state.
## get_nodes_in_group() returns the group's members from the whole game, so we keep
## only our own descendants (is_ancestor_of). Duck typing again: call("reset").
func reset_objects() -> void:
	for member: Node in get_tree().get_nodes_in_group(RESETTABLE_GROUP):
		if is_ancestor_of(member):
			member.call(&"reset")


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

class_name RoomLook
extends RefCounted
## RoomLook: keeps a room's drawn ground in step with its tiles while it's being
## edited (Stage L8).
##
## Rooms with an "Earth" layer, or with `painted_ground` on (rooms the editor
## makes), don't show their tiles: Room._ready() adds a GroundPainter that draws
## all their ground as one picture (lumpy earth, turf, stone; Earth_bending.md,
## Stage E4b) and hides the tile layers. The painter works
## out its picture once, from the layers it finds in _ready(); in play only bending
## changes it, through the EarthLayer's signals. In the editor tiles change all the
## time (brush strokes, undo, a resized room), so after each change the editor
## calls refresh(): the old painter goes and a fresh one is built from the room as
## it is now. The first Earth stroke in a room makes its painter this way too.
##
## While a stroke is being painted the picture would lag behind the mouse, so
## show_tiles_while_painting() makes the painted layer's own tiles visible until
## refresh() hides them again.
##
## It calls Room's own _add_ground_painter() / _add_pebble_field(), the ones
## Room._ready() uses, so a room looks the same in the editor as in play.

const PAINTER_NAME: StringName = &"GroundPainter"
const PEBBLE_FIELD_NAME: StringName = &"PebbleField"
## The layer a room needs before it gets a painter (see Room._ready).
const EARTH_LAYER_NAME: StringName = &"Earth"


## Rebuilds `room`'s ground picture if it has (or now needs) one, or takes the
## painter away if it no longer needs one (painted_ground switched off).
static func refresh(room: Room) -> void:
	var has_earth: bool = room.get_node_or_null(NodePath(EARTH_LAYER_NAME)) is EarthLayer
	var old_painter: Node = room.get_node_or_null(NodePath(PAINTER_NAME))
	if old_painter != null:
		# Out of the room now (its name is free for the new one), freed at frame end.
		room.remove_child(old_painter)
		old_painter.queue_free()
	if not has_earth and not room.painted_ground:
		# No painter: the tiles draw themselves again.
		for child: Node in room.get_children():
			if child is TileMapLayer:
				(child as TileMapLayer).self_modulate = Color.WHITE
		return
	room._add_ground_painter()
	if has_earth and room.get_node_or_null(NodePath(PEBBLE_FIELD_NAME)) == null:
		room._add_pebble_field()


## While painting `layer` in a room with a painter, its tiles show as they are.
static func show_tiles_while_painting(room: Room, layer: TileMapLayer) -> void:
	if room.get_node_or_null(NodePath(PAINTER_NAME)) != null:
		layer.self_modulate = Color.WHITE

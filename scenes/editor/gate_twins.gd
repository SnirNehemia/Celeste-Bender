class_name GateTwins
extends RefCounted
## GateTwins: how the level editor keeps a depth gate's twins with it
## (Level_editor.md §5a). A gate's twin is the gate at the same map spot one depth
## behind or in front (DepthGate.find_gate_at); the gates only work in pairs, so
## every edit of a gate edits its twins in the same undo step:
##   - placed where a room is behind: its twin is made there (add_twin_steps);
##   - moved: its twins move by as much, or the move is refused if one would leave
##     its room (find_twins + find_room_left);
##   - deleted: its twins go too (find_twins);
##   - the map's "Add missing gate twins" (add_missing).
## Only static functions: nothing to keep between calls. LevelEditor calls them and
## owns the undo action; they add their steps to it through
## LevelEditor.add_object_steps.


## The twins (behind and in front) of a gate whose top-left is `local_position`
## in `room`: the gates at the same map spot one depth either way.
static func find_twins(room: Room, local_position: Vector2) -> Array[DepthGate]:
	var twins: Array[DepthGate] = []
	if room == null:
		return twins
	for direction: int in [1, -1]:
		var spot: Vector2 = room.global_position + local_position + Room.depth_offset(direction)
		var twin: DepthGate = DepthGate.find_gate_at(room.get_tree(), room, spot)
		if twin != null:
			twins.append(twin)
	return twins


## True if a gate at `local_position` fits wholly inside `room`.
static func is_inside(room: Room, local_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, room.room_size).encloses(Rect2(local_position, DepthGate.GATE_SIZE))


## The room one of `twins` would leave if they all moved by `shift`, or null if
## they all still fit.
static func find_room_left(twins: Array[DepthGate], shift: Vector2) -> Room:
	for twin: DepthGate in twins:
		var twin_room: Room = Room.find_room_of(twin)
		if not is_inside(twin_room, twin.position + shift):
			return twin_room
	return null


## The room a twin of a gate at `local_position` in `room` would go in, `direction`
## depths away (it must fit wholly inside), or null. Null too if a gate is
## already there.
static func get_twin_room(editor: LevelEditor, room: Room, local_position: Vector2, direction: int) -> Room:
	var spot: Vector2 = room.global_position + local_position + Room.depth_offset(direction)
	# The room under the twin's middle (its top-left could sit on a room's edge).
	var twin_room: Room = editor.room_at(spot + DepthGate.GATE_SIZE / 2.0)
	if twin_room == null or not is_inside(twin_room, spot - twin_room.global_position):
		return null
	if DepthGate.find_gate_at(room.get_tree(), room, spot) != null:
		return null
	return twin_room


## Inside the editor's undo action being made: a twin for a gate at
## `local_position` in `room`, `direction` depths away, if a room is there for it.
## Returns the twin (not in the tree yet) or null.
static func add_twin_steps(editor: LevelEditor, room: Room, local_position: Vector2, direction: int) -> DepthGate:
	var twin_room: Room = get_twin_room(editor, room, local_position, direction)
	if twin_room == null:
		return null
	var twin: DepthGate = PaletteCatalog.instantiate(PaletteCatalog.get_entry(&"depth_gate")) as DepthGate
	# Objects' positions are room-local: from the map spot to the twin room's corner.
	twin.position = room.global_position + local_position + Room.depth_offset(direction) - twin_room.global_position
	editor.add_object_steps(twin_room, twin)
	return twin


## The map's "Add missing gate twins": every gate in `rooms` with no twin gets one
## behind (or, with no room there, in front), where a room is there for it. One
## undo step of its own. Returns how many were made.
static func add_missing(editor: LevelEditor, rooms: Array[Room]) -> int:
	editor.undo_redo.create_action("Add gate twins")
	var made: int = 0
	for room: Room in rooms:
		for child: Node in room.get_children():
			var gate: DepthGate = child as DepthGate
			if gate == null or gate.find_twin() != null:
				continue
			# Behind first; `or` only tries in front if no twin was made behind.
			if add_twin_steps(editor, room, gate.position, 1) != null or add_twin_steps(editor, room, gate.position, -1) != null:
				made += 1
	editor.undo_redo.commit_action()
	return made

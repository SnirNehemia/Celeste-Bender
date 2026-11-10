@tool
class_name GrandDoor
extends Door
## Grand door: a big stone slab for the end of a hub room. It works exactly like a
## Door (it extends it: switches, link mode, retract direction, won't close on you),
## but it LOOKS like the terrain and opens like an event:
##   - the slab is painted the way the ground is painted (PatchPainter: crust, rim,
##     edge line, hatched inside, basalt-like column joints), in a temple-stone palette;
##   - one SOCKET per linked switch is set into its face, in a column (a row if the
##     door is wider than tall). A KeyLight's socket is its key's color, dim until
##     that light is lit; any other switch's socket is white. So the door itself
##     tells the player what it is waiting for;
##   - when every switch is in, the sockets flash for OPEN_DELAY seconds, then the
##     slab grinds open slowly (open_time) with a rumble and falling grit, and lands
##     with a thud.
## Set it up: place it, size it in whole tiles (door_size), link it (L) to the
## KeyLights of the room and set Link Mode to All.
##
## The slab SLIDES (moves as one piece into retract_toward) instead of shrinking
## like the plain door: the visible part of the picture moves with it and is cut at
## the doorway's edge, as if it went into a slot in the ceiling (or floor, or wall).
##
## Godot concepts used:
##   - Inheritance: `extends Door` gets all the door's logic; the functions defined
##     again here (_draw, _physics_process) REPLACE the door's, and super(...) calls
##     the door's version from inside them.
##   - draw_texture_rect_region(): draws one rectangle cut out of a texture.

## The palette (PatchPainter's order: crust, rim, edge, inside, hatch, fleck, grain):
## a cool temple stone, between the grey rock and the basalt, with a pale rim.
const SLAB_PALETTE: Array[Color] = [Color(0.4, 0.4, 0.44), Color(0.62, 0.62, 0.66),
	Color(0.14, 0.14, 0.17), Color(0.13, 0.13, 0.16), Color(0.18, 0.18, 0.22),
	Color(0.55, 0.55, 0.6), Color(0.27, 0.27, 0.32)]
## The picture is painted in tiles of this many px (the rooms' grid).
const TILE_PX: int = 8
## Sockets: radius px, the gap between two, the dark ring round each.
const SOCKET_RADIUS: float = 2.5
const SOCKET_SPACING: float = 8.0
const SOCKET_RING_COLOR: Color = Color("1a1424")
## A switch that isn't a KeyLight: a white socket.
const PLAIN_SOCKET_COLOR: Color = Color(0.92, 0.94, 1.0)
## Dim sockets are their color this dark.
const SOCKET_DIM_DARKEN: float = 0.6
## A carved ring round the sockets: px beyond them.
const CARVING_MARGIN: float = 3.0
## The slot it slides into: a dark line along that edge of the doorway.
const SLOT_COLOR: Color = Color(0.05, 0.05, 0.07)
## Seconds the sockets flash before the slab starts to move.
const OPEN_DELAY: float = 0.7
## Rumble while moving (shake px), the thud at the end, grit every GRIT_INTERVAL s.
const RUMBLE_STRENGTH: float = 1.0
const THUD_STRENGTH: float = 3.0
const GRIT_INTERVAL: float = 0.12
const GRIT_AMOUNT: int = 3

## Seconds the door has wanted to open while still shut (the flashing beat).
var open_delay_elapsed: float = 0.0
var grit_remaining: float = 0.0
## The painted slab, [texture, origin] (PatchPainter.paint), for `painted_size`.
var slab_picture: Array = []
var painted_size: Vector2 = Vector2.ZERO


func _init() -> void:
	# Defaults for a NEW grand door (a saved one overrides them): two tiles wide,
	# six tall, slow and heavy.
	door_size = Vector2(16, 48)
	open_time = 1.4
	close_time = 0.8


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# The beat before it moves: wanting to open while fully shut.
	if wants_open and open_amount == 0.0 and snap_frames_remaining == 0:
		open_delay_elapsed += delta
		queue_redraw()  # the sockets flash
		if open_delay_elapsed < OPEN_DELAY:
			return
	elif not wants_open:
		open_delay_elapsed = 0.0
	var amount_before: float = open_amount
	super(delta)  # Door's opening / closing
	if open_amount == amount_before or snap_frames_remaining > 0:
		return
	# Moving: rumble and grit; a thud when it gets there.
	FX.shake(RUMBLE_STRENGTH, 0.1)
	grit_remaining -= delta
	if grit_remaining <= 0.0:
		grit_remaining = GRIT_INTERVAL
		var edge: Vector2 = _get_moving_edge_center()
		FX.spawn_gravel(to_global(edge), GRIT_AMOUNT, Vector2.DOWN, 0.0)
	if open_amount == 1.0 or open_amount == 0.0:
		FX.shake(THUD_STRENGTH, 0.25)
		FX.play_sfx(&"grand_door_thud")


## The middle of the slab's edge that faces the open side (where grit falls from).
func _get_moving_edge_center() -> Vector2:
	var closed_rect: Rect2 = _get_closed_rect()
	match retract_toward:
		RetractToward.UP:
			return Vector2(closed_rect.get_center().x, closed_rect.end.y)
		RetractToward.DOWN:
			return Vector2(closed_rect.get_center().x, closed_rect.position.y)
		RetractToward.LEFT:
			return Vector2(closed_rect.end.x, closed_rect.end.y)
		_:
			return Vector2(closed_rect.position.x, closed_rect.end.y)


## Door's handler, plus a redraw: a socket lights as soon as its switch does.
func _on_switch_changed(is_now_on: bool) -> void:
	super(is_now_on)
	queue_redraw()


## How far the slab has slid, local px: toward retract_toward, open_amount of its size.
func _get_slide_offset() -> Vector2:
	match retract_toward:
		RetractToward.UP:
			return Vector2(0.0, -door_size.y * open_amount)
		RetractToward.DOWN:
			return Vector2(0.0, door_size.y * open_amount)
		RetractToward.LEFT:
			return Vector2(-door_size.x * open_amount, 0.0)
		_:
			return Vector2(door_size.x * open_amount, 0.0)


## Paints the slab picture again if the size changed (it's cached otherwise).
func _ensure_picture() -> void:
	if painted_size == door_size and not slab_picture.is_empty():
		return
	painted_size = door_size
	var tiles: Vector2i = Vector2i(maxi(1, ceili(door_size.x / TILE_PX)), maxi(1, ceili(door_size.y / TILE_PX)))
	var cells: Array = []
	for y: int in tiles.y:
		for x: int in tiles.x:
			cells.append(Vector2i(x, y))
	# No other ground around: the slab has its crust on every side, a block of its own.
	slab_picture = PatchPainter.paint(cells, Vector2i(TILE_PX, TILE_PX),
		func(_cell: Vector2i) -> bool: return false, SLAB_PALETTE, PatchPainter.Grain.COLUMNS)


## Where each linked switch's socket sits on the slab (slab px, before sliding).
func _get_socket_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var count: int = 0
	for linked_switch: Switch in switches:
		if linked_switch != null:
			count += 1
	var along_x: bool = door_size.x > door_size.y
	var span: float = SOCKET_SPACING * (count - 1)
	for index: int in count:
		var shift: float = -span / 2.0 + SOCKET_SPACING * index
		positions.append(door_size / 2.0 + (Vector2(shift, 0.0) if along_x else Vector2(0.0, shift)))
	return positions


func _draw() -> void:
	_ensure_picture()
	var doorway: Rect2 = Rect2(Vector2.ZERO, door_size)
	var offset: Vector2 = _get_slide_offset()
	# The slot the slab slides into, along that edge of the doorway.
	if open_amount > 0.0:
		var slot: Rect2
		match retract_toward:
			RetractToward.UP:
				slot = Rect2(0.0, 0.0, door_size.x, 1.0)
			RetractToward.DOWN:
				slot = Rect2(0.0, door_size.y - 1.0, door_size.x, 1.0)
			RetractToward.LEFT:
				slot = Rect2(0.0, 0.0, 1.0, door_size.y)
			_:
				slot = Rect2(door_size.x - 1.0, 0.0, 1.0, door_size.y)
		draw_rect(slot, SLOT_COLOR)
	# The slab: the part of the slid picture still inside the doorway.
	var visible_rect: Rect2 = Rect2(offset, door_size).intersection(doorway)
	if visible_rect.size.x >= 0.5 and visible_rect.size.y >= 0.5:
		var texture: Texture2D = slab_picture[0]
		var picture_origin: Vector2 = slab_picture[1]
		var source: Rect2 = Rect2(visible_rect.position - offset - picture_origin, visible_rect.size)
		draw_texture_rect_region(texture, visible_rect, source)
		_draw_sockets(offset, visible_rect)
	if Engine.is_editor_hint():
		for linked_switch: Switch in switches:
			if linked_switch != null:
				draw_dashed_line(door_size / 2.0, to_local(linked_switch.global_position),
					LINK_LINE_COLOR, 1.0, 3.0)


## The carved ring and one socket per linked switch, moved by `offset`, only those
## still fully inside `visible_rect` (the slab's part in the doorway).
func _draw_sockets(offset: Vector2, visible_rect: Rect2) -> void:
	var positions: Array[Vector2] = _get_socket_positions()
	if positions.is_empty():
		return
	# Flashing during the beat before opening: sockets pulse bright.
	var flash: float = 0.0
	if open_delay_elapsed > 0.0 and open_amount == 0.0:
		flash = 0.5 + 0.5 * sin(open_delay_elapsed * TAU * 4.0)
	# The carved frame round the sockets: a dark rounded slot.
	var first: Vector2 = positions[0] + offset
	var last: Vector2 = positions[positions.size() - 1] + offset
	var reach: float = SOCKET_RADIUS + CARVING_MARGIN
	var carving: Rect2 = Rect2(first.min(last) - Vector2.ONE * reach, (last - first).abs() + Vector2.ONE * reach * 2.0)
	if visible_rect.encloses(carving):
		draw_rect(carving, SLAB_PALETTE[PatchPainter.EDGE])
		draw_rect(carving.grow(-1.0), SLAB_PALETTE[PatchPainter.INSIDE])
	var index: int = 0
	for linked_switch: Switch in switches:
		if linked_switch == null:
			continue
		var center: Vector2 = positions[index] + offset
		index += 1
		# Fully on the slab, 1 px in from its cut edge (abs(): a sliver of slab
		# thinner than 2 px would give the shrunk rectangle a negative size).
		if not visible_rect.grow(-1.0).abs().has_point(center) or minf(visible_rect.size.x, visible_rect.size.y) < 2.0:
			continue
		var lit_color: Color = PLAIN_SOCKET_COLOR
		if linked_switch is KeyLight:
			lit_color = KeyColors.get_color((linked_switch as KeyLight).key_color)
		var is_lit: bool = linked_switch.is_on() and not Engine.is_editor_hint()
		var color: Color = lit_color if is_lit else lit_color.darkened(SOCKET_DIM_DARKEN)
		color = color.lerp(Color.WHITE, flash * 0.6)
		draw_circle(center, SOCKET_RADIUS + 1.0, SOCKET_RING_COLOR)
		draw_circle(center, SOCKET_RADIUS, color)
		if is_lit:
			draw_rect(Rect2((center + Vector2(-1.0, -1.0)).floor(), Vector2.ONE), Color.WHITE)

@tool
class_name KeyLight
extends Switch
## Key light: a glass ball on a stone pedestal that lights up once the KeyOrb of its
## color (KeyColors) has been collected, and stays lit for the rest of the run.
## It is a Switch, so a door (best: a GrandDoor, link mode ALL) linked to several of
## them opens when every color is in. The hub-room puzzle:
##     KeyOrb RED (end of path 1)  ->  KeyLight RED  \
##     KeyOrb BLUE (end of path 2) ->  KeyLight BLUE  >-- GrandDoor (ALL)
##     KeyOrb GREEN (path 3)       ->  KeyLight GREEN/
## The orb and the light match by COLOR, not by an editor link, so they can be in
## different rooms (links only reach inside one room).
##
## Place the node ON the floor, at the pedestal's bottom middle (like a pressure plate).
## It lives on the tile grid: a 2x2-tile square standing on the floor, its middle on
## a tile line (the editor snaps it there and onto the ground).
##
## WHEN it lights: a key collected far away doesn't light the ball where nobody sees
## it. The light waits (`is_pending`) until the player walks into its room, then
## ignites a beat later, several lights one after another left to right, each with a
## flare, and only then is it ON: the door opens in front of the player. A light in
## the room the key is collected in lights after the same beat. Unlit, the ball shows
## its color dimly, so the player knows which key it waits for.
##
## Not in Room.RESETTABLE_GROUP: deaths and R don't put it out.
##
## Godot concepts used:
##   - Autoload signals: GameState.key_collected (a key went in the bag) and
##     GameState.room_entered (the player is in a new room) reach every light in the
##     level, whichever room it is in.
##   - Groups: every light joins LIGHTS_GROUP, so the lights of a room can find each
##     other to take turns igniting.

## Group of every KeyLight in the tree.
const LIGHTS_GROUP: StringName = &"key_lights"

## The color of the key it waits for.
@export var key_color: KeyColors.Name = KeyColors.Name.RED:
	set(value):
		key_color = value
		if glow != null:
			glow.color = KeyColors.get_color(key_color)
		queue_redraw()

## The look, in px. The pedestal: a wide base, a narrower neck, a cup holding the ball.
## All of it, outline included, fits the 2x2-tile (16 px) square.
const BALL_RADIUS: float = 4.0
const BASE_SIZE: Vector2 = Vector2(14, 2)
const NECK_SIZE: Vector2 = Vector2(6, 3)
const CUP_SIZE: Vector2 = Vector2(10, 2)
## Stone colors: the crumbling rock's crust, rim and edge (PatchPainter.ROCK_PALETTE),
## so the pedestal is carved from the same ground as the rooms.
const STONE_COLOR: Color = Color(0.5, 0.46, 0.42)
const STONE_RIM_COLOR: Color = Color(0.66, 0.61, 0.55)
const STONE_DARK_COLOR: Color = Color(0.22, 0.19, 0.18)
const OUTLINE_COLOR: Color = Color("1a1424")
## Igniting: seconds after entering the room before the first light, and between lights.
const IGNITE_DELAY: float = 0.6
const IGNITE_STAGGER: float = 0.4
## The flare when it ignites: seconds, and how far its ring grows, px.
const FLARE_TIME: float = 0.5
const FLARE_RADIUS: float = 20.0
## The glow while lit (HeatGlow): radius px, strength; it breathes slowly.
const GLOW_RADIUS: float = 18.0
const GLOW_STRENGTH: float = 0.6
const PULSE_SPEED: float = 1.2

## True when its key is collected but the player hasn't seen it light yet.
var is_pending: bool = false
## Seconds left of the ignition flare (0 = none).
var flare_remaining: float = 0.0
## Seconds since start, for the pulse.
var pulse_time: float = 0.0
## Bumped by every ignition order, so an older await gives up (two room entries).
var ignite_order: int = 0
var glow: HeatGlow


func _ready() -> void:
	glow = HeatGlow.new()
	glow.radius = GLOW_RADIUS
	glow.strength = GLOW_STRENGTH
	glow.flicker_amount = 0.08
	glow.color = KeyColors.get_color(key_color)
	glow.position = _get_ball_center()
	glow.show_behind_parent = true
	glow.visible = false
	add_child(glow)
	if Engine.is_editor_hint():
		return
	add_to_group(LIGHTS_GROUP)
	add_to_group(DarkRoomOverlay.LIGHT_GROUP)
	GameState.key_collected.connect(_on_key_collected)
	GameState.room_entered.connect(_on_room_entered)
	# Already collected this run (a reloaded room): lit from the start, no show.
	if GameState.has_key(key_color):
		_is_on = true  # no signal: doors read is_on() in their own _ready()
		glow.visible = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	pulse_time += delta
	if flare_remaining > 0.0:
		flare_remaining = maxf(flare_remaining - delta, 0.0)
	if is_on():
		glow.strength = GLOW_STRENGTH * (0.85 + 0.15 * sin(pulse_time * TAU * PULSE_SPEED)) \
			+ GLOW_STRENGTH * 1.5 * (flare_remaining / FLARE_TIME)
		queue_redraw()


func _on_key_collected(collected_color: int) -> void:
	if collected_color != key_color or is_on():
		return
	is_pending = true
	if Room.find_room_of(self) == GameState.current_room:
		_ignite_after(IGNITE_DELAY)


func _on_room_entered(room: Room) -> void:
	if not is_pending or room != Room.find_room_of(self):
		return
	# Take turns with the other pending lights of this room, left to right.
	var turn: int = 0
	for other: Node in get_tree().get_nodes_in_group(LIGHTS_GROUP):
		var other_light: KeyLight = other as KeyLight
		if other_light != self and other_light.is_pending \
				and Room.find_room_of(other_light) == room \
				and other_light.global_position.x < global_position.x:
			turn += 1
	_ignite_after(IGNITE_DELAY + IGNITE_STAGGER * turn)


## Waits `delay` seconds (game time), then lights up, unless the player left the room.
func _ignite_after(delay: float) -> void:
	ignite_order += 1
	var this_order: int = ignite_order
	await get_tree().create_timer(delay, false).timeout
	if this_order != ignite_order or not is_pending:
		return
	if Room.find_room_of(self) != GameState.current_room:
		return  # left before it lit: it'll light on the next visit
	is_pending = false
	flare_remaining = FLARE_TIME
	glow.visible = true
	FX.shake(1.0, 0.1)
	FX.play_sfx(&"key_light")
	set_on(true)


## Its light in a dark room (DarkRoomOverlay), while lit.
func get_dark_lights() -> Array[Vector4]:
	var lights: Array[Vector4] = []
	if is_on() and is_visible_in_tree():
		var center: Vector2 = to_global(_get_ball_center())
		lights.append(Vector4(center.x, center.y, GLOW_RADIUS * 2.0, 0.8))
	return lights


## The ball's middle, local px: sitting in the cup on top of the pedestal.
func _get_ball_center() -> Vector2:
	return Vector2(0.0, -(BASE_SIZE.y + NECK_SIZE.y + CUP_SIZE.y + BALL_RADIUS - 1.0))


func _draw() -> void:
	# The pedestal, bottom up, each piece with a dark outline and a light top edge.
	var base: Rect2 = Rect2(-BASE_SIZE.x / 2.0, -BASE_SIZE.y, BASE_SIZE.x, BASE_SIZE.y)
	var neck: Rect2 = Rect2(-NECK_SIZE.x / 2.0, base.position.y - NECK_SIZE.y, NECK_SIZE.x, NECK_SIZE.y)
	var cup: Rect2 = Rect2(-CUP_SIZE.x / 2.0, neck.position.y - CUP_SIZE.y, CUP_SIZE.x, CUP_SIZE.y)
	for piece: Rect2 in [base, neck, cup]:
		draw_rect(piece.grow(1.0), OUTLINE_COLOR)
	for piece: Rect2 in [base, neck, cup]:
		draw_rect(piece, STONE_COLOR)
		draw_rect(Rect2(piece.position, Vector2(piece.size.x, 1.0)), STONE_RIM_COLOR)
		draw_rect(Rect2(piece.position + Vector2(0.0, piece.size.y - 1.0), Vector2(piece.size.x, 1.0)),
			STONE_DARK_COLOR)
	# The ball.
	var center: Vector2 = _get_ball_center()
	var lit: bool = is_on() and not Engine.is_editor_hint()
	var color: Color = KeyColors.get_color(key_color) if lit else KeyColors.get_unlit_color(key_color)
	draw_circle(center, BALL_RADIUS + 1.0, OUTLINE_COLOR)
	draw_circle(center, BALL_RADIUS, color)
	if lit:
		draw_circle(center + Vector2(-0.5, -0.5), BALL_RADIUS * 0.55, color.lightened(0.4))
		draw_rect(Rect2((center + Vector2(-2.0, -2.0)).floor(), Vector2.ONE), Color.WHITE)
	else:
		# Dull glass: only a faint highlight.
		draw_rect(Rect2((center + Vector2(-2.0, -2.0)).floor(), Vector2.ONE), Color(1, 1, 1, 0.25))
	# The ignition flare: a ring bursting out, fading.
	if flare_remaining > 0.0:
		var progress: float = 1.0 - flare_remaining / FLARE_TIME
		draw_arc(center, lerpf(BALL_RADIUS, FLARE_RADIUS, progress), 0.0, TAU, 24,
			Color(color.lightened(0.5), 1.0 - progress), 1.0)

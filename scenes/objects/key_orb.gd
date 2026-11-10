@tool
class_name KeyOrb
extends Area2D
## Key orb: a glowing colored ball the player collects ONCE per run. It is the key
## of a hub room: every KeyLight of the same color (KeyColors), in any room of the
## level, lights up, and a GrandDoor linked to those lights opens when all are lit.
##
## Place the node where the CENTER of the orb should be: it lives on the tile grid,
## a 2x2-tile square centered on a tile corner (the editor snaps it there). Everything (the hitbox, the
## look) is built in code, so key_orb.tscn is a single node.
##
## Touching it:
##   1. GameState.collect_key(key_color) at once: the key is the player's from that
##      frame on, a death a moment later doesn't take it back.
##   2. A short show: the orb swells and flashes (GROWING, HOLDING), then shrinks
##      and flies into the player's backpack (FLYING), whose lid pops open to take it.
##      The game doesn't stop for it: you keep moving while it flies to you.
## It is NOT in Room.RESETTABLE_GROUP: deaths and R leave it collected. Coming back
## (or a level where the key was already taken) shows a faint GHOST ring where it was,
## like Celeste's collected strawberries.
##
## Area2D on physics layer 3 (triggers), looking at layer 2 ("player"), like the
## wind crystal. @tool so the orb is drawn (in its color) while placing it.
##
## Godot concepts used:
##   - _draw(): a CanvasItem paints itself with draw_* calls; queue_redraw() asks for
##     a new _draw() next frame. The whole orb, its flight included, is drawn here.
##   - Autoload signal: GameState.key_collected tells KeyLights in other rooms.

## The phases of the orb's life.
enum Phase { WAITING, GROWING, HOLDING, FLYING, COLLECTED }

## Which key this is. Matches KeyLights of the same color.
@export var key_color: KeyColors.Name = KeyColors.Name.RED:
	set(value):
		key_color = value
		if glow != null:
			glow.color = KeyColors.get_color(key_color)
		queue_redraw()

## Orb radius, px, and the hitbox's (bigger: pick-ups should be generous).
## (5 px + outline + bob fills its 2x2-tile square.)
const ORB_RADIUS: float = 5.0
const HITBOX_RADIUS: float = 7.0
## Gentle up-down float: amplitude px, cycles per second (a wind crystal's).
const BOB_AMPLITUDE: float = 1.5
const BOB_FREQUENCY: float = 0.8
## Two sparkles circle the orb: their distance from the middle, px, and turns per second.
const SPARKLE_DISTANCE: float = 7.0
const SPARKLE_SPEED: float = 0.35
## The show: seconds to swell to GROW_SCALE, to hold there, then to fly to the pack
## while shrinking to FLY_END_SCALE.
const GROW_TIME: float = 0.22
const HOLD_TIME: float = 0.25
const FLY_TIME: float = 0.32
const GROW_SCALE: float = 2.2
const FLY_END_SCALE: float = 0.25
## The ring that bursts out of it when touched: how far it grows, px.
const BURST_RADIUS: float = 18.0
## Glow round the orb (additive soft circle, HeatGlow's picture): radius px, strength.
const GLOW_RADIUS: float = 14.0
const GLOW_STRENGTH: float = 0.55
## Rim and highlight.
const RIM_COLOR: Color = Color("1a1424")  # the player's outline color: same pixel art
const HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
## The ghost ring left where a collected orb was.
const GHOST_ALPHA: float = 0.22

var phase: Phase = Phase.WAITING
## Seconds into the current phase.
var phase_time: float = 0.0
## Seconds since start: drives the bob and the sparkles.
var idle_time: float = 0.0
## Where the orb is drawn, relative to this node (moves during the flight).
var orb_offset: Vector2 = Vector2.ZERO
var orb_scale: float = 1.0
## Where the flight starts (local) and the player it flies to.
var flight_start: Vector2 = Vector2.ZERO
var collector: Player = null
## The soft glow behind the orb: a child drawn additively.
var glow: HeatGlow


func _ready() -> void:
	collision_layer = 4  # bit value of layer 3
	collision_mask = 2   # bit value of layer 2, "player"
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = HITBOX_RADIUS
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = circle
	add_child(hitbox)
	glow = HeatGlow.new()
	glow.radius = GLOW_RADIUS
	glow.strength = GLOW_STRENGTH
	glow.flicker_amount = 0.1
	glow.show_behind_parent = true  # under the orb, not over it
	glow.color = KeyColors.get_color(key_color)
	add_child(glow)
	if Engine.is_editor_hint():
		return
	add_to_group(DarkRoomOverlay.LIGHT_GROUP)
	# Already in the bag (taken earlier this run, the room reloaded): only the ghost.
	if GameState.has_key(key_color):
		_set_phase(Phase.COLLECTED)


func _physics_process(delta: float) -> void:
	idle_time += delta
	phase_time += delta
	match phase:
		Phase.WAITING:
			# Only the drawing bobs; the hitbox stays put so touching is predictable.
			orb_offset = Vector2(0.0, roundf(sin(idle_time * TAU * BOB_FREQUENCY) * BOB_AMPLITUDE))
			if not Engine.is_editor_hint():
				_check_touch()
		Phase.GROWING:
			# ease out: fast at first, settling at the big size.
			orb_scale = lerpf(1.0, GROW_SCALE, ease(minf(phase_time / GROW_TIME, 1.0), 0.4))
			if phase_time >= GROW_TIME:
				_set_phase(Phase.HOLDING)
		Phase.HOLDING:
			if phase_time >= HOLD_TIME:
				flight_start = orb_offset
				_set_phase(Phase.FLYING)
		Phase.FLYING:
			_fly()
	glow.position = orb_offset
	glow.radius = GLOW_RADIUS * orb_scale
	queue_redraw()


## A live player overlapping the hitbox collects the key.
func _check_touch() -> void:
	for body: Node2D in get_overlapping_bodies():
		var touched_player: Player = body as Player
		if touched_player != null and not touched_player.is_dead():
			collector = touched_player
			GameState.collect_key(key_color)  # the key is ours from THIS frame on
			FX.play_sfx(&"key")
			FX.shake(1.5, 0.12)
			FX.freeze(0.05)  # a tiny hit-stop: "you got something"
			_set_phase(Phase.GROWING)
			return


## FLYING: from where it swelled to the pack, shrinking, the pack followed as it moves.
func _fly() -> void:
	var progress: float = minf(phase_time / FLY_TIME, 1.0)
	# ease in: starts slow, snaps into the bag.
	var eased: float = ease(progress, 2.4)
	var target: Vector2 = to_local(_get_pack_position())
	orb_offset = flight_start.lerp(target, eased)
	orb_scale = lerpf(GROW_SCALE, FLY_END_SCALE, eased)
	if progress >= 1.0:
		if is_instance_valid(collector) and collector.body_look != null:
			collector.body_look.pop_lid()
		_set_phase(Phase.COLLECTED)


## The collecting player's pack, or where the orb is if the player is gone.
func _get_pack_position() -> Vector2:
	if is_instance_valid(collector) and collector.body_look != null:
		return collector.body_look.get_pack_global_position()
	return to_global(orb_offset)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_time = 0.0
	if new_phase == Phase.COLLECTED:
		orb_offset = Vector2.ZERO
		orb_scale = 1.0
		glow.visible = false
		remove_from_group(DarkRoomOverlay.LIGHT_GROUP)


## Its light in a dark room (DarkRoomOverlay), until collected.
func get_dark_lights() -> Array[Vector4]:
	var lights: Array[Vector4] = []
	if phase != Phase.COLLECTED and is_visible_in_tree():
		var center: Vector2 = to_global(orb_offset)
		lights.append(Vector4(center.x, center.y, GLOW_RADIUS * 2.0 * orb_scale, 0.8))
	return lights


func _draw() -> void:
	var color: Color = KeyColors.get_color(key_color)
	if phase == Phase.COLLECTED:
		# The ghost: a faint ring where the orb was.
		draw_arc(Vector2.ZERO, ORB_RADIUS, 0.0, TAU, 16, Color(color, GHOST_ALPHA), 1.0)
		return
	var radius: float = ORB_RADIUS * orb_scale
	# The burst ring while it swells and holds: grows and fades.
	if phase == Phase.GROWING or phase == Phase.HOLDING:
		var burst_progress: float = (phase_time + (GROW_TIME if phase == Phase.HOLDING else 0.0)) \
			/ (GROW_TIME + HOLD_TIME)
		draw_arc(orb_offset, lerpf(radius, BURST_RADIUS, burst_progress), 0.0, TAU, 24,
			Color(color.lightened(0.5), 1.0 - burst_progress), 1.0)
	# The orb: dark rim, the color, a lighter core, one bright highlight pixel up-left.
	draw_circle(orb_offset, radius + 1.0, RIM_COLOR)
	draw_circle(orb_offset, radius, color)
	draw_circle(orb_offset + Vector2(-0.5, -0.5) * orb_scale, radius * 0.55, color.lightened(0.35))
	draw_rect(Rect2((orb_offset + Vector2(-2.0, -2.0) * orb_scale).floor(), Vector2.ONE * maxf(1.0, orb_scale)),
		HIGHLIGHT_COLOR)
	# Two sparkles circling it while it waits.
	if phase == Phase.WAITING:
		for index: int in 2:
			var angle: float = idle_time * TAU * SPARKLE_SPEED + PI * index
			var sparkle: Vector2 = orb_offset + Vector2(cos(angle), sin(angle) * 0.6) * SPARKLE_DISTANCE
			draw_rect(Rect2(sparkle.floor(), Vector2.ONE), Color(color.lightened(0.6), 0.8))

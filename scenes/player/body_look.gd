class_name PlayerBodyLook
extends Node2D
## Draws the player's body in the BACKPACK style (PlayerTuning.body_style): the white
## body with a dark outline, two dot eyes, and a small pack on the back.
## Looks only: nothing here touches movement or the hitbox.
##
## A direct child of the Player (player.tscn), drawn over SquashPivot/Visual (the
## plain white rectangle). Each frame it decides which of the two shows: itself for
## BACKPACK, Visual for PLAIN_RECTANGLE, neither while the player is dead
## (Player.set_body_hidden).
##
## It follows the body the rest of the game already moves:
##   - size: SquashPivot's scale (MovementEffects' squash & stretch) and Visual's
##     height (Player.set_tucked makes it half as tall for the belly slide);
##   - which way it faces: Player.facing_direction;
##   - motion: Player.velocity and is_on_floor().
##
## The life in it is all in the pack and the eyes (the body stays firm):
##   - the pack trails up to pack_lag_pixels behind the motion on a damped spring,
##     and swings to the other side pack_turn_delay late on a turn;
##   - the pack's lid lifts while falling, flutters faster the faster you fall, and
##     slaps shut on landing; the pack dips a pixel on a hard landing;
##   - the eyes look the way you face, glance up/down in the air, squint on landing
##     and blink now and then.
## All the amounts are in PlayerTuning, group "Look".
##
## How it's drawn: _draw() fills 1-pixel rects on the 320x180 grid, so the character
## stays pixel art at any squash (a scaled Node would smear the 1 px eyes). The
## outline isn't a separate pass: dark rects 1 px bigger go down FIRST, then the
## fills on top. Where the pack touches the body, its fill covers the body's outline;
## when the pack trails a pixel away, the outline shows between them as a seam.
##
## Godot concepts used:
##   - _draw() and queue_redraw(): a CanvasItem draws itself in _draw(), and only
##     when asked to with queue_redraw(), which we do every frame.
##   - draw_rect(): fills a rectangle in this node's local coordinates.

## Colors (GAME_DESIGN.md §2): the white body, a near-black outline and eyes, and
## the pack in two browns plus a dark inside that shows when the lid opens.
const BODY_COLOR: Color = Color(1.0, 1.0, 1.0)
const OUTLINE_COLOR: Color = Color("1a1424")
const PACK_COLOR: Color = Color("9a6a3c")
const LID_COLOR: Color = Color("6a4524")
const PACK_INSIDE_COLOR: Color = Color("3a2416")

## The body the face is designed on: 8 wide, 11 tall (the hitbox).
const BASE_WIDTH: int = 8
const BASE_HEIGHT: int = 11
## Face layout, in pixels of that 8x11 body FACING RIGHT, (0, 0) at its top-left.
## Mirrored when facing left; x < 0 is behind the body.
const EYES: Array[Rect2i] = [Rect2i(4, 3, 1, 2), Rect2i(6, 3, 1, 2)]
## The pack: 2 wide, 5 tall, right behind the body; its top row is the lid.
const PACK: Rect2i = Rect2i(-2, 3, 2, 5)

## The pack's landing dip: a stiff spring, kicked down by a landing.
const PACK_DIP_STIFFNESS: float = 220.0
const PACK_DIP_DAMPING: float = 22.0
## The kick a full-hardness landing gives the dip spring, px/s (about 1 px of dip).
const PACK_DIP_KICK: float = 40.0
## The extra downward kick a landing gives the trailing spring: the pack keeps
## going a moment after the body stops. px/s at full hardness.
const PACK_LAND_KICK: float = 30.0
## The lid: a quick spring toward how open it should be (0 shut, 1 lifted, 2 tipped up).
const LID_STIFFNESS: float = 300.0
const LID_DAMPING: float = 20.0

## The Player, our parent.
var player: Player
## The node MovementEffects scales for squash & stretch (origin at the feet).
var squash_pivot: Node2D
## The plain white rectangle (PLAIN_RECTANGLE style). Its height is the body's
## standing or tucked height (Player.set_tucked changes it).
## Found by path, not through player.visual: a child's _ready runs BEFORE its
## parent's, so the Player's @onready vars aren't filled in yet when ours runs.
var plain_visual: ColorRect

## Where the pack trails to, in world pixels (x right, y down), and its speed.
var pack_lag: Vector2 = Vector2.ZERO
var pack_lag_velocity: Vector2 = Vector2.ZERO
## The pack's landing dip in pixels (down = positive), and its speed.
var pack_dip: float = 0.0
var pack_dip_velocity: float = 0.0
## Counts down after a turn; while > 0 the pack is still drawn on the old side.
var pack_turn_remaining: float = 0.0
## How open the lid is, 0..2, and its speed.
var lid_open: float = 0.0
var lid_velocity: float = 0.0
## Running clock for the lid's flutter, seconds.
var flutter_clock: float = 0.0

## The eyes' timers, seconds: until the next blink, how long the blink still lasts,
## how long the landing squint still lasts.
var blink_wait_remaining: float = 2.0
var blink_remaining: float = 0.0
var squint_remaining: float = 0.0

## Last frame's floor contact, facing, and the fall speed while airborne, to notice
## landings and turns ourselves (no signal from the Player needed).
var was_on_floor: bool = true
var last_facing: float = 1.0
var last_air_fall_speed: float = 0.0


func _ready() -> void:
	player = get_parent() as Player
	squash_pivot = player.get_node("SquashPivot") as Node2D
	plain_visual = player.get_node("SquashPivot/Visual") as ColorRect
	last_facing = player.facing_direction
	blink_wait_remaining = player.tuning.blink_interval
	update_visibility()


## Shows this node or the plain Visual rectangle, from the tuning and from
## Player.is_body_hidden (the Dead state hides both). Called every frame, and right
## away by Player.set_body_hidden so a death hides the body on that very frame.
func update_visibility() -> void:
	var use_backpack: bool = player.tuning.body_style == PlayerTuning.BodyStyle.BACKPACK
	visible = use_backpack and not player.is_body_hidden
	plain_visual.visible = not use_backpack and not player.is_body_hidden


func _process(delta: float) -> void:
	update_visibility()
	if not visible:
		return
	_update_motion(delta)
	queue_redraw()


## Steps the pack, the lid and the eyes by `delta` seconds.
func _update_motion(delta: float) -> void:
	var tuning: PlayerTuning = player.tuning
	var velocity: Vector2 = player.velocity
	var on_floor: bool = player.is_on_floor()

	# --- Landings and turns ---------------------------------------------------
	if not on_floor:
		# On the landing frame velocity.y is already 0, so remember the fall speed
		# from the frames before.
		last_air_fall_speed = velocity.y
	elif not was_on_floor:
		_on_landed(last_air_fall_speed)
	was_on_floor = on_floor
	if signf(player.facing_direction) != signf(last_facing):
		pack_turn_remaining = tuning.pack_turn_delay
	last_facing = player.facing_direction
	pack_turn_remaining = maxf(pack_turn_remaining - delta, 0.0)

	# --- The pack trails behind the motion --------------------------------------
	# Target: against the velocity, a full pack_lag_pixels at the "full" speeds.
	# (maxf: a full speed tuned down to 0 in the panel must not divide by zero.)
	var lag_target: Vector2 = Vector2(
		clampf(-velocity.x / maxf(tuning.pack_lag_full_speed_x, 1.0), -1.0, 1.0),
		clampf(-velocity.y / maxf(tuning.pack_lag_full_speed_y, 1.0), -1.0, 1.0)) * tuning.pack_lag_pixels
	# A damped spring (stiffness pulls toward the target, damping eats the speed):
	# it catches up when you stop, with a small overshoot.
	pack_lag_velocity += (tuning.pack_spring_stiffness * (lag_target - pack_lag)
		- tuning.pack_spring_damping * pack_lag_velocity) * delta
	pack_lag += pack_lag_velocity * delta
	# Never further than the lag plus a little overshoot, whatever a teleport does.
	var lag_limit: float = tuning.pack_lag_pixels * 1.4
	pack_lag = pack_lag.clamp(Vector2(-lag_limit, -lag_limit), Vector2(lag_limit, lag_limit))

	# --- The landing dip ------------------------------------------------------
	pack_dip_velocity += (-PACK_DIP_STIFFNESS * pack_dip - PACK_DIP_DAMPING * pack_dip_velocity) * delta
	pack_dip = clampf(pack_dip + pack_dip_velocity * delta, -1.0, 1.4)

	# --- The lid: open while falling, fluttering faster the faster you fall ----
	var lid_target: float = 0.0
	if not on_floor and velocity.y > tuning.lid_open_fall_speed:
		# 0 at the opening speed .. 1 at the full speed.
		var fall_amount: float = clampf(inverse_lerp(tuning.lid_open_fall_speed,
			tuning.lid_full_fall_speed, velocity.y), 0.0, 1.0)
		var flutter_rate: float = lerpf(tuning.lid_flutter_rate_slow, tuning.lid_flutter_rate_fast, fall_amount)
		flutter_clock += delta * flutter_rate
		# 1 = lifted; faster falls swing between about 1 and 2 (tipped up).
		lid_target = 1.0 + fall_amount * (0.6 + 0.6 * sin(flutter_clock * TAU))
	lid_velocity += (LID_STIFFNESS * (lid_target - lid_open) - LID_DAMPING * lid_velocity) * delta
	lid_open = clampf(lid_open + lid_velocity * delta, 0.0, 2.0)

	# --- The eyes ---------------------------------------------------------------
	squint_remaining = maxf(squint_remaining - delta, 0.0)
	blink_remaining = maxf(blink_remaining - delta, 0.0)
	blink_wait_remaining -= delta
	if blink_wait_remaining <= 0.0:
		blink_remaining = tuning.blink_time
		blink_wait_remaining = tuning.blink_interval + randf() * tuning.blink_interval_random


## Touched down after falling at `fall_speed` px/s: squint, shut the lid, and kick
## the pack down (harder landings kick more, on the same scale as the body's squash).
func _on_landed(fall_speed: float) -> void:
	var tuning: PlayerTuning = player.tuning
	squint_remaining = tuning.land_squint_time
	lid_open = 0.0
	lid_velocity = 0.0
	var hardness: float = clampf(inverse_lerp(tuning.land_effect_min_speed,
		tuning.land_squash_full_speed, fall_speed), 0.0, 1.0)
	pack_dip_velocity += PACK_DIP_KICK * hardness
	if tuning.pack_lag_pixels > 0.0:
		pack_lag_velocity.y += PACK_LAND_KICK * hardness


func _draw() -> void:
	# Our origin is the player's feet. Snap to whole screen pixels so the 1 px eyes
	# and the outline land on the grid: `snap` moves the drawing from the player's
	# exact (fractional) position to the nearest pixel.
	var snap: Vector2 = global_position.round() - global_position

	# The body's size: the 8 px width and the standing (or tucked) height, times the
	# squash. Rounded to whole pixels, never smaller than a few.
	var base_height: float = -plain_visual.offset_top
	var body_width: int = maxi(4, roundi(BASE_WIDTH * squash_pivot.scale.x))
	var body_height: int = maxi(3, roundi(base_height * squash_pivot.scale.y))
	@warning_ignore("integer_division")
	var body: Rect2i = Rect2i(-body_width / 2, -body_height, body_width, body_height)

	var facing: int = 1 if player.facing_direction >= 0.0 else -1
	# The pack sits on the side it was on before a turn, for a beat.
	var pack_facing: int = -facing if pack_turn_remaining > 0.0 else facing

	# Pack rectangle in local pixels, plus the trail and the dip.
	var pack: Rect2i = _face_rect(PACK, body, pack_facing)
	pack.position += Vector2i(roundi(pack_lag.x), roundi(pack_lag.y + pack_dip))
	# The lid's pixels above the pack when it's open (none when shut).
	var lid_pixels: Array[Vector2i] = _lid_pixels(pack, pack_facing, roundi(lid_open))

	# 1. Outlines: a dark rect 1 px bigger than each shape, behind every fill.
	_fill(pack.grow(1), OUTLINE_COLOR, snap)
	for lid_pixel: Vector2i in lid_pixels:
		_fill(Rect2i(lid_pixel - Vector2i.ONE, Vector2i(3, 3)), OUTLINE_COLOR, snap)
	_fill(body.grow(1), OUTLINE_COLOR, snap)
	# 2. The pack: brown, with the lid row dark brown (shut) or the dark inside (open).
	_fill(pack, PACK_COLOR, snap)
	var lid_row: Rect2i = Rect2i(pack.position, Vector2i(pack.size.x, 1))
	_fill(lid_row, LID_COLOR if lid_pixels.is_empty() else PACK_INSIDE_COLOR, snap)
	for lid_pixel: Vector2i in lid_pixels:
		_fill(Rect2i(lid_pixel, Vector2i.ONE), LID_COLOR, snap)
	# 3. The body over the pack: a pack sliding into it tucks behind.
	_fill(body, BODY_COLOR, snap)
	# 4. The eyes.
	var glance: int = _get_glance()
	var eyes_shut: bool = blink_remaining > 0.0 or squint_remaining > 0.0
	for eye_layout: Rect2i in EYES:
		var eye: Rect2i = _face_rect(eye_layout, body, facing)
		eye.position.y += glance
		if eyes_shut:
			# Shut: only the bottom row of each eye, a short dash.
			eye = Rect2i(eye.position.x, eye.end.y - 1, eye.size.x, 1)
		_fill(eye, OUTLINE_COLOR, snap)


## Maps a rect from the 8x11 facing-right layout onto the body as it is now
## (squashed, tucked, facing either way). Columns are centred on the body; rows
## stretch with its height.
func _face_rect(layout: Rect2i, body: Rect2i, facing: int) -> Rect2i:
	# A squashed body is wider or narrower than 8: keep the face centred on it.
	@warning_ignore("integer_division")
	var shift: int = (body.size.x - BASE_WIDTH) / 2
	var x: int = layout.position.x
	if facing < 0:
		# Mirror: column x of a w-wide shape becomes column (7 - x - (w - 1)).
		x = BASE_WIDTH - 1 - layout.position.x - (layout.size.x - 1)
	# Rows scale with the body's height relative to the height the layout was made
	# for (11 standing; squashed or tucked, everything moves with it), but nothing
	# may hang below the feet (the 5 px pack on a 6 px tucked body).
	var y: int = roundi(layout.position.y * float(body.size.y) / float(BASE_HEIGHT))
	y = clampi(y, 0, maxi(0, body.size.y - layout.size.y))
	return Rect2i(body.position.x + shift + x, body.position.y + y, layout.size.x, layout.size.y)


## The open lid's pixels for openness `amount` (0 shut, 1 lifted flat, 2 tipped up).
## It's hinged on the column next to the body and swings up and away from it.
func _lid_pixels(pack: Rect2i, pack_facing: int, amount: int) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	if amount <= 0:
		return pixels
	# Facing right the pack is behind (left of) the body, so its right column touches it.
	var hinge_x: int = pack.end.x - 1 if pack_facing > 0 else pack.position.x
	var away: int = -pack_facing
	var top: int = pack.position.y
	pixels.append(Vector2i(hinge_x, top - 1))
	if amount == 1:
		pixels.append(Vector2i(hinge_x + away, top - 1))   # lifted, still flat
	else:
		pixels.append(Vector2i(hinge_x + away, top - 2))   # tipped up and out
	return pixels


## -1 = eyes a pixel up (rising), +1 = a pixel down (falling), 0 otherwise.
func _get_glance() -> int:
	if player.is_on_floor():
		return 0
	if player.velocity.y < -player.tuning.eye_glance_up_speed:
		return -1
	if player.velocity.y > player.tuning.eye_glance_down_speed:
		return 1
	return 0


## draw_rect for a pixel rect, moved by `snap` onto the screen's pixel grid.
func _fill(rect: Rect2i, color: Color, snap: Vector2) -> void:
	draw_rect(Rect2(Vector2(rect.position) + snap, Vector2(rect.size)), color)

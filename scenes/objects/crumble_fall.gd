class_name CrumbleFall
extends Node2D
## CrumbleFall: the picture of a crumbled platform patch FALLING away (after the
## play-test of Stage W8c: "make it fall instead of disappear"). A look only: the
## patch's tiles (and so its collision) are already gone when this starts, so it
## never lands on or pushes anything; you fall with it, at the same gravity.
##
## Made by CrumblePatches.fall() for the painted crumbling layers (CrumbleRockLayer,
## CrumbleIceLayer). It is added as a child of the layer, so it draws in the room's
## coordinates, and it draws the patch with the layer's own drawing code, passed in
## as a Callable (`draw_piece(canvas)`, the patch in the LAYER's local px): the rock's
## painted picture or the ice's glass look, cracks and all.
##
## Motion: it starts still, then gravity pulls it down, with a slight sideways drift
## and a slow spin round the patch's middle (`pivot`), and it fades out over the last
## FADE_TIME of its life. It goes away early if the room resets (Room.RESETTABLE_GROUP:
## the patch is back in place then, and its falling ghost would be confusing).
##
## Why a Callable? A Callable is a reference to a function (here a small lambda that
## remembers the patch's picture), so this node needs no idea WHAT it draws.

## Px/s² down: a bit under the player's fall, so the pieces drop just behind you.
const FALL_GRAVITY: float = 380.0
## Seconds it lives, and the last part of that it spends fading out.
const LIFETIME: float = 1.1
const FADE_TIME: float = 0.4
## Random sideways drift, px/s, and spin, radians/s (both at most this much).
const MAX_DRIFT: float = 12.0
const MAX_SPIN: float = 0.7

## Draws the patch on the canvas it is given, in the layer's local px.
var draw_piece: Callable
## The patch's middle in the layer's local px: it spins round this.
var pivot: Vector2 = Vector2.ZERO
var fall_velocity: Vector2 = Vector2.ZERO
var spin_speed: float = 0.0
var life_left: float = LIFETIME


## Starts `draw_piece`'s patch falling from where it is in `layer`, its middle at
## `patch_center` (the layer's local px).
static func spawn(layer: Node2D, draw_callable: Callable, patch_center: Vector2) -> CrumbleFall:
	var piece: CrumbleFall = CrumbleFall.new()
	piece.draw_piece = draw_callable
	piece.pivot = patch_center
	piece.position = patch_center
	piece.fall_velocity = Vector2(randf_range(-MAX_DRIFT, MAX_DRIFT), 0.0)
	piece.spin_speed = randf_range(-MAX_SPIN, MAX_SPIN)
	layer.add_child(piece)
	return piece


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)


func _physics_process(delta: float) -> void:
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return
	fall_velocity.y += FALL_GRAVITY * delta
	position += fall_velocity * delta
	rotation += spin_speed * delta
	# modulate tints this node and what it draws: alpha fades it out at the end.
	modulate.a = clampf(life_left / FADE_TIME, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	# The patch is drawn in the layer's coordinates; this node sits at the pivot
	# (moved and turned), so shift back by it first.
	draw_set_transform(-pivot)
	draw_piece.call(self)


## Room reset (death or R): the patch is whole again, so its falling picture goes.
func reset() -> void:
	queue_free()

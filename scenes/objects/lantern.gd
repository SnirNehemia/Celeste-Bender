@tool
class_name Lantern
extends TrailingPickup
## Lantern: a light you carry through DARK ROOMS (Room.is_dark), so darkness works
## in levels without Fire. Touch it and it follows behind your pack (TrailingPickup,
## like a relic shard), lighting a wide circle around itself. It stays with you from
## room to room. A death (or R) sends it flying back to where it was placed.
##
## It is a light source of the DarkRoomOverlay (the base class joins
## DarkRoomOverlay.LIGHT_GROUP; this class only gives a bigger, brighter light):
## the radius and strength are FireTuning.dark_lantern_light_*, next to the other
## dark-room numbers. It shines while waiting too, so it can be found in the dark.
##
## Place the node where the lantern's middle should be.
## Everything else (the states, the chain, changing parent so a frozen room can't
## freeze it) is TrailingPickup's.

## Placeholder colors: a dark iron frame, warm glass (the fire palette's yellow).
const FRAME_COLOR: Color = Color(0.2, 0.18, 0.22)
const GLASS_COLOR: Color = Color(1.0, 0.86, 0.45)
const GLASS_CORE_COLOR: Color = Color(1.0, 0.97, 0.8)
## The glass flickers a little: how much dimmer at its lowest, and cycles per second.
const FLICKER_AMOUNT: float = 0.15
const FLICKER_SPEED: float = 3.0

var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")


func _on_taken() -> void:
	FX.play_sfx(&"lantern_taken")


## Its light in a dark room: much wider than a shard's faint glow.
func get_dark_lights() -> Array[Vector4]:
	var lights: Array[Vector4] = []
	if is_visible_in_tree():
		var center: Vector2 = global_position + bob_offset
		lights.append(Vector4(center.x, center.y, fire_tuning.dark_lantern_light_radius,
			fire_tuning.dark_lantern_light_strength))
	return lights


func _draw() -> void:
	var flicker: float = 1.0 - FLICKER_AMOUNT * (0.5 + 0.5 * sin(idle_time * TAU * FLICKER_SPEED))
	var origin: Vector2 = bob_offset
	# The handle, the cap, the glass and the base, top to bottom (whole pixels).
	draw_rect(Rect2(origin + Vector2(-1, -7), Vector2(2, 1)), FRAME_COLOR)
	draw_rect(Rect2(origin + Vector2(-3, -6), Vector2(6, 2)), FRAME_COLOR)
	draw_rect(Rect2(origin + Vector2(-3, -4), Vector2(6, 7)), FRAME_COLOR)
	draw_rect(Rect2(origin + Vector2(-2, -4), Vector2(4, 7)), Color(GLASS_COLOR * flicker, 1.0))
	draw_rect(Rect2(origin + Vector2(-1, -2), Vector2(2, 3)), GLASS_CORE_COLOR)
	draw_rect(Rect2(origin + Vector2(-4, 3), Vector2(8, 2)), FRAME_COLOR)

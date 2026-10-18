class_name RailTrack
extends RefCounted
## Draws the rail that a wind-driven platform runs along (LeafPlatform, SailPlatform).
##
## Shared drawing only, as a static function (like AirBlast): the platform calls
## RailTrack.draw(self, from, to) at the start of its own _draw(), so the rail is
## behind the platform. `from` and `to` are in the platform's LOCAL coordinates;
## since the platform moves along its rail, it passes its rail ends relative to
## where it is now, so the rail itself stays still on screen.
##
## Look: a thin gray-blue line with small cross ties every 8 px and a dot at each
## end, so "this thing moves between here and here" reads at a glance.

const RAIL_COLOR: Color = Color(0.55, 0.6, 0.7, 0.6)
const END_STOP_COLOR: Color = Color(0.7, 0.75, 0.85, 0.9)
## Distance between cross ties, and their half length, px.
const TIE_SPACING: float = 8.0
const TIE_HALF_LENGTH: float = 1.5


static func draw(canvas: CanvasItem, from: Vector2, to: Vector2) -> void:
	var length: float = from.distance_to(to)
	if length < 1.0:
		return
	var along: Vector2 = (to - from) / length
	# orthogonal() rotates by 90°: the direction the ties stick out.
	var across: Vector2 = along.orthogonal() * TIE_HALF_LENGTH
	canvas.draw_line(from, to, RAIL_COLOR, 1.0)
	var tie_distance: float = TIE_SPACING
	while tie_distance < length:
		var tie_center: Vector2 = from + along * tie_distance
		canvas.draw_line(tie_center - across, tie_center + across, RAIL_COLOR, 1.0)
		tie_distance += TIE_SPACING
	canvas.draw_circle(from, 1.5, END_STOP_COLOR)
	canvas.draw_circle(to, 1.5, END_STOP_COLOR)

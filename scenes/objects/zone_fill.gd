class_name ZoneFill
extends RefCounted
## ZoneFill: how an invisible AREA (a wind zone, dead air) shows its extent without
## looking like a rectangle laid over the picture (art pass: hard-edged translucent
## boxes read as a glitch in front of a painted backdrop, and the same box was used
## for wind, dead air and far cliffs).
##
## Static only. draw_soft_rect() fills the rectangle faintly and lets it fade out
## toward its edge in a few hard STEPS (bands, like every gradient in this game:
## never a smooth blend), with the corners cut, so the eye reads "a patch of air"
## and still sees where it ends.
##
## Used by WindZone and NoGlideZone from their _draw().

## How many bands the fill fades through at the edge, and how wide each is, px.
const EDGE_STEPS: int = 3
const EDGE_STEP_WIDTH: float = 2.0


## Draws `rect` on `canvas` in `color` (its alpha = the fill's strength in the
## middle), fading out to the edge in EDGE_STEPS bands. Each band is one more
## see-through rectangle on top of the last, a step further in, so the alphas add up
## to `color`'s in the middle; each one's corners are cut by its own step width.
static func draw_soft_rect(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var layers: int = EDGE_STEPS + 1
	var layer_color: Color = Color(color, color.a / layers)
	for step: int in layers:
		var inset: float = step * EDGE_STEP_WIDTH
		var inner: Rect2 = rect.grow(-inset)
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			return  # a zone thinner than its own edge: the outer bands are all of it
		var cut: float = minf(EDGE_STEP_WIDTH, minf(inner.size.x, inner.size.y) / 2.0)
		# Three plain rectangles make one with its four corners cut off.
		canvas.draw_rect(Rect2(inner.position.x + cut, inner.position.y, inner.size.x - cut * 2.0, cut), layer_color)
		canvas.draw_rect(Rect2(inner.position.x, inner.position.y + cut, inner.size.x, inner.size.y - cut * 2.0), layer_color)
		canvas.draw_rect(Rect2(inner.position.x + cut, inner.end.y - cut, inner.size.x - cut * 2.0, cut), layer_color)

class_name SignBubble
extends Node2D
## SignBubble: a signpost's text box drawn as a COMIC SPEECH BUBBLE, in colors taken
## from the room's backdrop. Made by Signpost (one per sign), as a child of the
## sign's Label, so it fades and moves with the box.
##
## It draws the WHOLE bubble; show_behind_parent puts its drawing behind the
## Label's own (the letters), so the Label only brings the text. Its background is
## an empty StyleBox (get_label_style) that just keeps the margins around the text.
##
## THE LOOK (picked from three styles compared after a play-test: "bold" and
## "raised" together):
##   - a 2 px ink border with round corners, and a thicker bottom lip
##   - raised paper: a light line inside the top and left, a shade inside the
##     bottom and right, so the bubble looks pressed out of the page
##   - a hard drop shadow (see-through ink) under the bubble and its tail
##   - a tail from the bottom edge down to the sign's board
## Everything is whole-pixel rectangles and StyleBoxFlats with anti-aliasing off, so
## it stays crisp in the 320x180 world.
##
## COLORS (get_colors): the backdrop's MAIN COLOR for the room's look and altitude
## (Backdrop.get_main_color: what the whole picture averages to) gives the hue. The
## fill is a pale "paper" of that hue and the ink (border, tail edge, letters) a deep
## shade of it, so the bubble belongs to the place and the text always reads: the
## paper's value is fixed high and the ink's fixed low, whatever the backdrop's own.

## Fill: the hue's saturation is scaled by this, kept between the limits, at this value.
const FILL_SATURATION_SCALE: float = 0.35
const FILL_SATURATION_MIN: float = 0.05
const FILL_SATURATION_MAX: float = 0.25
const FILL_VALUE: float = 0.96
## Ink: the same hue, more saturated, dark.
const INK_SATURATION_SCALE: float = 1.1
const INK_SATURATION_MIN: float = 0.3
const INK_SATURATION_MAX: float = 0.7
const INK_VALUE: float = 0.18
## A main color less saturated than this has no real hue (grey fallback, headless
## runs): the bubble stays neutral instead of tinting toward red (hue 0).
const NEUTRAL_SATURATION: float = 0.05
## The body: border width, the bottom lip's width and the corner radius, px.
const BORDER_WIDTH: int = 2
const LIP_WIDTH: int = 3
const CORNER_RADIUS: int = 4
## The space between the border and the text, px (the lip adds its extra at the bottom).
const TEXT_MARGIN_X: float = 5.0
const TEXT_MARGIN_Y: float = 4.0
## Raised paper: the light line is the paper pulled this far toward white, the
## shade the paper darkened by this much.
const LIGHT_AMOUNT: float = 0.75
const SHADE_AMOUNT: float = 0.14
## The drop shadow's offset, px, and its strength (ink at this alpha).
const SHADOW_OFFSET: Vector2 = Vector2(2, 2)
const SHADOW_ALPHA: float = 0.55
## The tail: half its width where it leaves the bubble, px. Its base keeps this far
## from the bubble's sides so it never cuts a corner.
const TAIL_BASE_HALF_WIDTH: int = 4
const TAIL_SIDE_CLEARANCE: float = 5.0

var fill_color: Color = Color.WHITE
var ink_color: Color = Color.BLACK
## In the Label's coordinates: the bubble's size, and the x the tail points at.
var bubble_size: Vector2 = Vector2.ZERO
var tail_tip_x: float = 0.0
## How far the tail reaches below the bubble, px (0 = no tail).
var tail_length: int = 0


func _init() -> void:
	show_behind_parent = true  # behind the Label's letters, see the header


## [fill, ink] for a bubble in front of `look` at `altitude` (see the header).
static func get_colors(look: Backdrop.Look, altitude: Backdrop.Altitude) -> Array[Color]:
	var main: Color = Backdrop.get_main_color(look, altitude)
	var fill_saturation: float = 0.0
	var ink_saturation: float = 0.0
	if main.s >= NEUTRAL_SATURATION:
		fill_saturation = clampf(main.s * FILL_SATURATION_SCALE, FILL_SATURATION_MIN, FILL_SATURATION_MAX)
		ink_saturation = clampf(main.s * INK_SATURATION_SCALE, INK_SATURATION_MIN, INK_SATURATION_MAX)
	return [Color.from_hsv(main.h, fill_saturation, FILL_VALUE), Color.from_hsv(main.h, ink_saturation, INK_VALUE)]


## The Label's background: nothing drawn (the bubble draws itself), only the room
## around the text.
static func get_label_style() -> StyleBoxEmpty:
	var margins: StyleBoxEmpty = StyleBoxEmpty.new()
	margins.content_margin_left = TEXT_MARGIN_X
	margins.content_margin_right = TEXT_MARGIN_X
	margins.content_margin_top = TEXT_MARGIN_Y
	margins.content_margin_bottom = TEXT_MARGIN_Y + LIP_WIDTH - BORDER_WIDTH
	return margins


## Sets the colors (from get_colors) and redraws.
func set_colors(fill: Color, ink: Color) -> void:
	fill_color = fill
	ink_color = ink
	queue_redraw()


## Points the tail at `target_x` (Label coordinates), `length` px down from a bubble
## of `size`. The base slides along the bottom edge as near the target as the
## corners allow; the tip leans the rest of the way.
func point_at(size: Vector2, target_x: float, length: int) -> void:
	if size == bubble_size and is_equal_approx(target_x, tail_tip_x) and length == tail_length:
		return  # nothing moved: no redraw
	bubble_size = size
	tail_tip_x = target_x
	tail_length = length
	queue_redraw()


func _draw() -> void:
	if bubble_size.x <= 0.0:
		return
	# Shadow first (under everything), then the body, its raised edges, the tail.
	var shadow_color: Color = Color(ink_color, SHADOW_ALPHA)
	draw_style_box(_make_box(shadow_color, shadow_color), Rect2(SHADOW_OFFSET, bubble_size))
	_draw_tail(SHADOW_OFFSET, shadow_color, shadow_color, false)
	draw_style_box(_make_box(fill_color, ink_color), Rect2(Vector2.ZERO, bubble_size))
	_draw_raised_edges()
	_draw_tail(Vector2.ZERO, fill_color, ink_color, true)


## A StyleBoxFlat in `fill` with the `ink` border, the thicker lip and round corners.
func _make_box(fill: Color, ink: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = ink
	box.set_border_width_all(BORDER_WIDTH)
	box.border_width_bottom = LIP_WIDTH
	box.set_corner_radius_all(CORNER_RADIUS)
	box.anti_aliasing = false
	return box


## Inside the border: a light line along the top and left and a shade along the
## bottom and right, kept clear of the rounded corners.
func _draw_raised_edges() -> void:
	var light: Color = fill_color.lerp(Color.WHITE, LIGHT_AMOUNT)
	var shade: Color = fill_color.darkened(SHADE_AMOUNT)
	var inset: float = BORDER_WIDTH + CORNER_RADIUS - 1
	var bottom: float = bubble_size.y - LIP_WIDTH - 1
	var right: float = bubble_size.x - BORDER_WIDTH - 1
	draw_rect(Rect2(inset, BORDER_WIDTH, bubble_size.x - inset * 2.0, 1), light)
	draw_rect(Rect2(BORDER_WIDTH, inset, 1, bubble_size.y - inset * 2.0), light)
	draw_rect(Rect2(inset, bottom, bubble_size.x - inset * 2.0, 1), shade)
	draw_rect(Rect2(right, inset, 1, bubble_size.y - inset * 2.0), shade)


## The tail, shifted by `offset`: rows narrowing from the bottom edge to the tip,
## `edge` on the outside and `fill` inside. With `open_border` the lip over the
## tail's base is repainted in `fill`, so the bubble opens into it.
func _draw_tail(offset: Vector2, fill: Color, edge: Color, open_border: bool) -> void:
	if tail_length <= 0:
		return
	var lowest_base: float = TAIL_SIDE_CLEARANCE + TAIL_BASE_HALF_WIDTH
	var base_x: float = clampf(tail_tip_x, lowest_base, maxf(lowest_base, bubble_size.x - lowest_base))
	if open_border:
		var open_width: float = TAIL_BASE_HALF_WIDTH * 2 + 1 - BORDER_WIDTH * 2
		draw_rect(Rect2(offset.x + roundf(base_x) - TAIL_BASE_HALF_WIDTH + BORDER_WIDTH,
			offset.y + bubble_size.y - LIP_WIDTH, open_width, LIP_WIDTH), fill)
	for row: int in tail_length:
		var progress: float = float(row) / float(tail_length)
		var half_width: int = roundi(TAIL_BASE_HALF_WIDTH * (1.0 - progress))
		var center_x: float = roundf(lerpf(base_x, tail_tip_x, progress))
		var y: float = offset.y + bubble_size.y + row
		draw_rect(Rect2(offset.x + center_x - half_width, y, half_width * 2 + 1, 1), edge)
		var inside_width: int = half_width * 2 + 1 - BORDER_WIDTH * 2
		if inside_width > 0:
			draw_rect(Rect2(offset.x + center_x - half_width + BORDER_WIDTH, y, inside_width, 1), fill)

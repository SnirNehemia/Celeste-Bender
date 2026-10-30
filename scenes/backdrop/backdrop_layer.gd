class_name BackdropLayer
extends Node2D
## One layer of a backdrop (scenes/backdrop/): a painted strip (BackdropPaint) that
## scrolls slower than the world the further away it is: PARALLAX, the effect that
## makes a flat background feel deep. Made and owned by a BackdropTheme, which
## passes it the camera's movement every frame (follow_camera).
##
## The strip is drawn twice, side by side, and the layer's x position is wrapped
## into [-STRIP_WIDTH, 0] (fposmod), so the two copies always cover the screen
## however far the camera travels: an endless background from one picture.
##
## Optional `draw_extra`: a Callable that draws moving things on top of each copy
## (swaying kelp, flickering torches, light shafts). A layer with one redraws every
## frame; a layer without one never redraws, it only moves (cheap).

## Movement relative to the camera: 0 = stuck to the screen (infinitely far),
## 1 = moves with the world. x and y separately: backdrops move less up and down.
var scroll_factor: Vector2 = Vector2(0.5, 0.1)
## Pixels per second the layer drifts by itself (clouds), on top of the parallax.
var drift_speed: float = 0.0
## The painted strip (null for a layer that only has draw_extra).
var texture: Texture2D = null
## func(layer: BackdropLayer, copy_x: float, time: float) -> void, drawn on each copy.
## copy_x is the copy's left edge in this layer's own coordinates.
var draw_extra: Callable = Callable()
## Seconds since the layer was made; the clock for drift_speed and draw_extra.
var elapsed_time: float = 0.0

## How far a layer may shift up or down with the camera, in px: the strip is that
## much taller than the screen at each end (BackdropPaint.SCREEN_TOP_ROW).
const MAX_VERTICAL_SHIFT: float = 20.0


## Places the layer for a camera that is `camera_offset` px away from where it was
## when the backdrop started.
func follow_camera(camera_offset: Vector2, delta: float) -> void:
	elapsed_time += delta
	var scroll_x: float = camera_offset.x * scroll_factor.x + elapsed_time * drift_speed
	# round(): whole pixels only, or the pixel art shimmers while scrolling.
	position.x = -fposmod(roundf(scroll_x), BackdropPaint.STRIP_WIDTH)
	var shift_y: float = clampf(roundf(-camera_offset.y * scroll_factor.y), -MAX_VERTICAL_SHIFT, MAX_VERTICAL_SHIFT)
	position.y = -BackdropPaint.SCREEN_TOP_ROW + shift_y
	if draw_extra.is_valid():
		queue_redraw()


func _draw() -> void:
	for copy_index: int in 2:
		var copy_x: float = copy_index * BackdropPaint.STRIP_WIDTH
		if texture != null:
			draw_texture(texture, Vector2(copy_x, 0.0))
		if draw_extra.is_valid():
			draw_extra.call(self, copy_x, elapsed_time)

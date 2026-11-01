class_name BackdropTheme
extends Node2D
## One complete backdrop look (a mountain range, a temple hall, a forest...): a stack
## of BackdropLayers from far to near plus BackdropMotes. This is the base script;
## each look is a small script in themes/ that extends it and overrides
## _build_layers(), calling add_painted_layer / add_tall_layer (a slice of a
## picture its look's three altitudes share) / add_split_layer (a tall picture each
## altitude paints its own part of) / add_drawn_layer / add_motes in far-to-near
## order (later children draw on top).
##
## Made by Backdrop (backdrop.gd), which calls build() once and then
## follow_camera() every frame, and scrolls whole themes in and out (their frames).
##
## Painted pictures are cached for the whole run (texture_cache, a STATIC variable:
## one dictionary shared by every BackdropTheme, surviving scene changes), so
## dying, restarting or loading the next Story level never repaints them.

## Painted textures by "<theme script path>:<layer name>".
static var texture_cache: Dictionary = {}
## Tall pictures (BackdropPaint.new_tall) by "<style>:<layer name>": painted once,
## sliced by each altitude of the look.
static var tall_cache: Dictionary = {}

## Which slice of a look's tall pictures each altitude shows (BackdropPaint header).
const SKYLINE_SECTION: int = 0
const SURFACE_SECTION: int = 1
const UNDERGROUND_SECTION: int = 2

## The band of rock drawn when the backdrop breaks through the ground (Backdrop,
## Transition.BREAK): [body, lit rim]. Underground looks set their own rock's.
const DEFAULT_CRUST_COLORS: Array[Color] = [Color(0.07, 0.06, 0.07), Color(0.2, 0.18, 0.17)]
var crust_colors: Array[Color] = DEFAULT_CRUST_COLORS

## Light shafts (draw_light_shafts) are drawn this many rows at a time.
const SHAFT_ROW: int = 1

## The layers and motes, far to near; each has follow_camera(offset, delta).
var _parallax_children: Array[Node2D] = []


## Makes the layers. Called once by Backdrop, before the theme is added to the tree.
func build() -> void:
	_build_layers()


## Override in a theme script: add the layers, far to near.
func _build_layers() -> void:
	pass


## Moves every layer and mote for a camera `camera_offset` px from its start.
func follow_camera(camera_offset: Vector2, delta: float) -> void:
	for child: Node2D in _parallax_children:
		child.call(&"follow_camera", camera_offset, delta)


## Adds a layer whose picture `painter` paints: func() -> Image (a BackdropPaint
## strip). The picture is painted only the first time this run.
func add_painted_layer(layer_name: String, scroll_factor: Vector2, painter: Callable,
		drift_speed: float = 0.0) -> BackdropLayer:
	var cache_key: String = "%s:%s" % [get_script().resource_path, layer_name]
	if not texture_cache.has(cache_key):
		var image: Image = painter.call()
		texture_cache[cache_key] = ImageTexture.create_from_image(image)
	var layer: BackdropLayer = add_drawn_layer(layer_name, scroll_factor, Callable())
	layer.texture = texture_cache[cache_key]
	layer.drift_speed = drift_speed
	return layer


## Adds a layer showing `section`'s slice of a TALL picture that `painter` paints:
## func(tall: Image) -> void, given a BackdropPaint.new_tall() to paint on. The
## same `style_name` + `layer_name` gives the same tall picture to every altitude
## of a look (themes/<look>/style.gd holds the painter), so what one altitude shows
## carries on in the next. Give the layer the same scroll_factor in each.
func add_tall_layer(style_name: String, layer_name: String, scroll_factor: Vector2, painter: Callable,
		section: int, drift_speed: float = 0.0) -> BackdropLayer:
	var tall_key: String = "%s:%s" % [style_name, layer_name]
	var slice_key: String = "%s:%d" % [tall_key, section]
	if not texture_cache.has(slice_key):
		if not tall_cache.has(tall_key):
			var tall: Image = BackdropPaint.new_tall()
			painter.call(tall)
			tall_cache[tall_key] = tall
		texture_cache[slice_key] = ImageTexture.create_from_image(BackdropPaint.tall_slice(tall_cache[tall_key], section))
	var layer: BackdropLayer = add_drawn_layer(layer_name, scroll_factor, Callable())
	layer.texture = texture_cache[slice_key]
	layer.drift_speed = drift_speed
	return layer


## Adds a tall layer (add_tall_layer) whose picture several altitudes paint
## their own parts of: `painters` maps a section (SKYLINE_SECTION...) to a
## func() -> Image painting that altitude's strip, copied into the tall picture
## at its own screen rows only (BackdropPaint.paint_section). This is how a layer
## that only one altitude has (the surface's near pines, the skyline's summit
## ridge) is still in BOTH altitudes' stacks: in the other one it sits off the
## screen, past the edge between them, so a soft change scrolls straight on into
## it and nothing appears or vanishes. No painters: a layer with only `extras`.
## `extras`: moving things, see section_extras. `fade_sections`: those sections'
## parts thin out toward the edge they share with another altitude, in a dither,
## instead of ending in a straight cut there (BackdropPaint.paint_section).
func add_split_layer(style_name: String, layer_name: String, scroll_factor: Vector2, painters: Dictionary,
		section: int, drift_speed: float = 0.0, extras: Dictionary = {}, fade_sections: Array[int] = []) -> BackdropLayer:
	var layer: BackdropLayer = null
	if painters.is_empty():
		layer = add_drawn_layer(layer_name, scroll_factor, Callable())
	else:
		var painter: Callable = func(tall: Image) -> void:
			_paint_split(tall, painters, fade_sections)
		layer = add_tall_layer(style_name, layer_name, scroll_factor, painter, section, drift_speed)
	if not extras.is_empty():
		layer.draw_extra = section_extras(extras, section)
	return layer


## Paints a split layer's tall picture (add_split_layer): each section's strip
## from `painters`, at its own screen rows only.
static func _paint_split(tall: Image, painters: Dictionary, fade_sections: Array[int]) -> void:
	for painted_section: int in painters:
		# Spare rows only where no other altitude's screen is: above the top one,
		# below the bottom one.
		var with_top_margin: bool = painted_section == SKYLINE_SECTION
		var with_bottom_margin: bool = painted_section == UNDERGROUND_SECTION \
			or (painted_section == SURFACE_SECTION and not painters.has(UNDERGROUND_SECTION))
		var strip: Image = painters[painted_section].call()
		BackdropPaint.paint_section(tall, strip, painted_section, with_top_margin, with_bottom_margin,
			fade_sections.has(painted_section))


## A draw_extra (BackdropLayer) for a layer of `section` that draws every
## altitude's moving things: `extras` maps a section to that altitude's own
## draw_extra, drawn moved by whole screens to where its part of the tall
## picture is (above or below this screen). So the skyline's prayer flags or the
## surface's torches are there in both altitudes, and scroll in with the rest.
static func section_extras(extras: Dictionary, section: int) -> Callable:
	return func(layer: BackdropLayer, copy_x: float, time: float) -> void:
		for drawn_section: int in extras:
			layer.draw_set_transform(Vector2(0.0, (drawn_section - section) * BackdropPaint.SCREEN_HEIGHT))
			extras[drawn_section].call(layer, copy_x, time)
		layer.draw_set_transform(Vector2.ZERO)


## Adds a layer with no picture, only moving drawing: `draw_extra` is
## func(layer: BackdropLayer, copy_x: float, time: float) -> void (see BackdropLayer).
func add_drawn_layer(layer_name: String, scroll_factor: Vector2, draw_extra: Callable) -> BackdropLayer:
	var layer: BackdropLayer = BackdropLayer.new()
	layer.name = layer_name
	layer.scroll_factor = scroll_factor
	layer.draw_extra = draw_extra
	add_child(layer)
	_parallax_children.append(layer)
	return layer


## Adds motes (already configured), and scatters them.
func add_motes(motes: BackdropMotes) -> void:
	motes.setup()
	add_child(motes)
	_parallax_children.append(motes)


## Draws slanted light shafts (temple windows, forest sun, underwater rays) for a
## draw_extra: `shaft_xs` are the shafts' tops in strip px, each `width` wide, leaning
## `lean` px sideways per px down, `length` px long. They breathe: each one's alpha
## swells and fades slowly, out of step with the others. `top_y`: the strip row
## they start at.
static func draw_light_shafts(layer: BackdropLayer, copy_x: float, time: float, shaft_xs: Array[float],
		width: float, lean: float, length: float, color: Color, top_y: float = 0.0) -> void:
	for shaft_index: int in shaft_xs.size():
		var top_x: float = copy_x + shaft_xs[shaft_index]
		var breathing: float = 0.65 + 0.35 * sin(time * 0.5 + shaft_index * 1.9)
		var shaft_color: Color = Color(color, color.a * breathing)
		var core_color: Color = Color(shaft_color, shaft_color.a * 0.8)
		# One whole-pixel rect per SHAFT_ROW rows: a see-through polygon is drawn as
		# triangles, and the pixels on their shared edge got blended twice (a dotted
		# line through every shaft). Rects side by side never overlap.
		for y: int in range(0, roundi(length), SHAFT_ROW):
			var along: float = y / length
			# The shaft widens from `width` at the top to 1.6x at the bottom.
			var left: float = roundf(top_x + lean * y)
			var right: float = roundf(top_x + width * (1.0 + 0.6 * along) + lean * y)
			layer.draw_rect(Rect2(left, top_y + y, right - left, SHAFT_ROW), shaft_color)
			# A brighter core down the middle: two tones read better than one.
			var core_left: float = roundf(top_x + width * (0.35 + 0.25 * along) + lean * y)
			var core_right: float = roundf(top_x + width * (0.65 + 0.35 * along) + lean * y)
			layer.draw_rect(Rect2(core_left, top_y + y, maxf(1.0, core_right - core_left), SHAFT_ROW), core_color)


## A soft round glow for a draw_extra (torches, candles, mushrooms, jellyfish):
## three see-through circles, each smaller one adding to the middle, scaled by
## `strength` (0-1, for flicker and pulsing).
static func draw_glow(layer: BackdropLayer, center: Vector2, radius: float, color: Color, strength: float) -> void:
	for ring_index: int in 3:
		layer.draw_circle(center.round(), radius * (1.0 - ring_index * 0.3) * (0.85 + 0.15 * strength), Color(color, color.a * strength))

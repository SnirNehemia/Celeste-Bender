class_name HeatGlow
extends Node2D
## HeatGlow (Stage F13, Fire_bending.md §9.2 item 4): the soft warm light a fire
## throws on the ground, walls and the player around it. No lighting system: an
## ADDITIVE soft circle, stretched from one shared picture, flickering on noise.
##
## Two ways to use it:
##   - as a node: HeatGlow.new(), set radius / color / strength, add it as a child.
##     It draws itself and flickers. A FireDiamond uses one.
##   - as a helper for nodes that draw many glows themselves (the FireGrid, a
##     FlameMerge, the Bonfire): HeatGlow.draw_glow(item, center, radius, color) on
##     any canvas item that has an additive material.
## Every glow shares ONE soft round texture (get_texture). A textured rectangle is 2
## triangles, and rectangles sharing one texture are drawn together in one batch:
## hundreds of glows cost almost nothing. (Before F13 the FireGrid kept this picture
## for itself; draw_circle() glows were far too slow, see FireGrid's history.)
##
## How bright the world glows overall: FireTuning's "Fire look" group
## (heat_glow_strength scales every glow; 0 turns them all off).
##
## Godot concepts used:
##   - GradientTexture2D: a texture Godot computes from a Gradient (here radial:
##     white in the middle, fading to clear at the edge).
##   - CanvasItemMaterial.BLEND_MODE_ADD: colors are ADDED to what's behind, which is
##     what light does.
##   - A `static var` belongs to the class, not to one node (like a Python class
##     attribute), so the texture is made once for the whole game.

## Size of the shared glow picture, px (it's stretched to each glow's size).
const TEXTURE_SIZE: int = 32

static var glow_texture: GradientTexture2D
static var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")

## Radius of the glow, px.
@export var radius: float = 12.0
## Its color; the alpha is how bright it is at full strength.
@export var color: Color = Color(1.0, 0.55, 0.2, 0.18)
## 0 = off, 1 = full. The owner turns it up and down (a brazier going out).
@export_range(0.0, 1.0) var strength: float = 1.0
## How much it flickers: ± this share of its brightness and a third of it in size.
@export_range(0.0, 1.0) var flicker_amount: float = 0.2
## Flicker speed: the noise scrolls this fast.
@export var flicker_speed: float = 6.0

## Seconds of flicker so far, from a random start so two glows never pulse together.
var flicker_time: float = 0.0


func _ready() -> void:
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	flicker_time = randf() * 100.0


func _process(delta: float) -> void:
	flicker_time += delta * flicker_speed
	queue_redraw()


func _draw() -> void:
	var flicker: float = get_flicker(flicker_time, flicker_amount)
	var glow_color: Color = Color(color, color.a * strength * flicker)
	draw_glow(self, Vector2.ZERO, radius * (1.0 + (flicker - 1.0) / 3.0), glow_color)


## A smooth wandering factor around 1 (1 ± `amount`): two sines at unrelated speeds,
## so it never repeats in an obvious beat. `time` is any running clock.
static func get_flicker(time: float, amount: float) -> float:
	var wave: float = sin(time * 1.9) * 0.6 + sin(time * 3.7 + 1.3) * 0.4
	return 1.0 + wave * amount


## Draws one soft glow on `item` (which should be additive), scaled by the game-wide
## heat_glow_strength. Too small to see: nothing.
static func draw_glow(item: CanvasItem, center: Vector2, glow_radius: float, glow_color: Color) -> void:
	var overall: float = fire_tuning.heat_glow_strength
	if glow_radius < 0.5 or overall <= 0.0:
		return
	item.draw_texture_rect(get_texture(), Rect2(center - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2.0),
		false, Color(glow_color, glow_color.a * overall))


## The shared glow picture: white in the middle fading to transparent at the edge.
static func get_texture() -> GradientTexture2D:
	if glow_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.4))  # falls off fast, then trails
		glow_texture = GradientTexture2D.new()
		glow_texture.gradient = gradient
		glow_texture.fill = GradientTexture2D.FILL_RADIAL
		glow_texture.fill_from = Vector2(0.5, 0.5)
		glow_texture.fill_to = Vector2(1.0, 0.5)
		glow_texture.width = TEXTURE_SIZE
		glow_texture.height = TEXTURE_SIZE
	return glow_texture

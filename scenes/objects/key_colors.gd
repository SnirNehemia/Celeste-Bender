class_name KeyColors
extends RefCounted
## KeyColors: the named colors a KeyOrb and a KeyLight can have, and how each looks.
##
## A key orb of color X, once collected, lights every KeyLight of color X in the level
## (they match by color, not by a link, so the orb and its light can sit in different
## rooms: the editor's links only reach inside one room). The color is an ENUM, not a
## free Color, so the property panel shows a drop-down and two objects either match
## exactly or don't.
##
## Static functions only: KeyColors.get_color(KeyColors.Name.RED).

## The key colors. Saved in levels as their number, so only ever ADD at the end.
## OCHRE, RUST, MOSS and SLATE are the earth tones of "Earth - Bedrock" (its four wings).
enum Name { RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE, WHITE, OCHRE, RUST, MOSS, SLATE }

## Bright, saturated "lit" colors, far apart in hue so six of them read side by side.
const LIT_COLORS: Array[Color] = [
	Color("ff4a4a"),  # RED
	Color("ff9a2e"),  # ORANGE
	Color("ffe14a"),  # YELLOW
	Color("5ae06a"),  # GREEN
	Color("4aa8ff"),  # BLUE
	Color("c065ff"),  # PURPLE
	Color("f4f4ff"),  # WHITE
	Color("e0aa3c"),  # OCHRE: yellow-brown
	Color("d2603a"),  # RUST: red-brown
	Color("93ad4c"),  # MOSS: dull green
	Color("8fa9bf"),  # SLATE: blue-gray
]
## An unlit ball is its color this dark: you can still tell WHICH key it waits for.
const UNLIT_DARKEN: float = 0.6


## The bright color of `key_color`.
static func get_color(key_color: Name) -> Color:
	return LIT_COLORS[clampi(key_color, 0, LIT_COLORS.size() - 1)]


## The dim color of `key_color` (an unlit KeyLight's glass).
static func get_unlit_color(key_color: Name) -> Color:
	return get_color(key_color).darkened(UNLIT_DARKEN)


## "Red", "Blue"... for messages and the editor.
static func get_label(key_color: Name) -> String:
	return String(Name.keys()[key_color]).capitalize()

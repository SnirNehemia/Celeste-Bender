class_name PixelFont
extends RefCounted
## PixelFont: the font for text drawn INSIDE the 320x180 world (a signpost's box,
## the ghost's "Best" time), where every pixel is shown four times its size. Godot's
## default font is smoothed (anti-aliased); at 8 px tall that is a blur next to the
## hard-edged pixel art. This one is drawn by hand on a pixel grid: every letter is
## made of whole pixels.
##
## Static only: get_font() loads resources/fonts/pixel.fnt, which
## tools/build_pixel_font.gd writes (the letter shapes are in that tool). Menus and
## the editor's panels keep the smooth default font; they aren't pixel art.
##
## Godot concept, bitmap font: a FontFile made from one picture of all the letters
## (not from outlines), so it has exactly ONE size: always draw it at FONT_SIZE.

const FONT_PATH: String = "res://resources/fonts/pixel.fnt"
## The one size the font has, px (the tool's CELL_HEIGHT).
const FONT_SIZE: int = 9

static var _font: Font = null


## The pixel font, or the default font if the font file is missing (run the tool).
static func get_font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	return _font

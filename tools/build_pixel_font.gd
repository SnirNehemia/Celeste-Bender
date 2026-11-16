extends Node
## tools/build_pixel_font.gd: writes the game's PIXEL FONT, resources/fonts/pixel.png
## + pixel.fnt, from the letter shapes below. Not part of the game.
##   godot --headless --path . res://tools/build_pixel_font.tscn
## then `godot --headless --path . --import` so Godot picks the new files up.
##
## Why a font of our own (art pass): text drawn inside the 320x180 world (a
## signpost's box, the ghost's "Best" time) is shown four times its size. Godot's
## default font is smoothed, which at that size is a blur next to hard pixel art;
## with the smoothing switched off its letters came out unevenly spaced. Here every
## letter is drawn by hand on a pixel grid.
##
## The format: BMFont's text format (.fnt), which Godot imports as a FontFile: one
## picture holding every letter side by side, plus a text file saying where each
## letter is in it and how far the pen moves after it. scenes/ui/pixel_font.gd
## (`PixelFont.get_font()`) loads the result.
##
## The letters: GLYPHS maps a character to its rows, top to bottom, separated by
## "/": "#" is a pixel, "." is empty. A letter may have fewer rows than the cell
## (the rest are empty) and may start with "N:" to skip N rows first (a comma starts
## at row 6). Capitals and digits are 7 rows tall (rows 0-6, row 6 = the baseline);
## small letters sit in rows 2-6 with ascenders up to row 0; descenders use rows 7-8.

const OUTPUT_FOLDER: String = "res://resources/fonts"
const PICTURE_NAME: String = "pixel.png"
const FONT_NAME: String = "pixel.fnt"
## The cell every letter is drawn in, px tall, and the line height with its gap.
const CELL_HEIGHT: int = 9
const LINE_HEIGHT: int = 10
## Rows above the baseline (BMFont's "base").
const BASELINE: int = 7
## Empty px after each letter, and a space's width.
const LETTER_GAP: int = 1
const SPACE_ADVANCE: int = 3
## The picture's width, px; letters wrap onto more rows of cells.
const PICTURE_WIDTH: int = 128

const GLYPHS: Dictionary = {
	"A": ".##./#..#/#..#/####/#..#/#..#/#..#",
	"B": "###./#..#/#..#/###./#..#/#..#/###.",
	"C": ".##./#..#/#.../#.../#.../#..#/.##.",
	"D": "###./#..#/#..#/#..#/#..#/#..#/###.",
	"E": "####/#.../#.../###./#.../#.../####",
	"F": "####/#.../#.../###./#.../#.../#...",
	"G": ".##./#..#/#.../#.##/#..#/#..#/.###",
	"H": "#..#/#..#/#..#/####/#..#/#..#/#..#",
	"I": "###/.#./.#./.#./.#./.#./###",
	"J": "..##/...#/...#/...#/...#/#..#/.##.",
	"K": "#..#/#.#./##../##../#.#./#..#/#..#",
	"L": "#.../#.../#.../#.../#.../#.../####",
	"M": "#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#",
	"N": "#..#/##.#/##.#/#.##/#.##/#..#/#..#",
	"O": ".##./#..#/#..#/#..#/#..#/#..#/.##.",
	"P": "###./#..#/#..#/###./#.../#.../#...",
	"Q": ".##./#..#/#..#/#..#/#..#/#.#./.#.#",
	"R": "###./#..#/#..#/###./#.#./#..#/#..#",
	"S": ".###/#.../#.../.##./...#/...#/###.",
	"T": "#####/..#../..#../..#../..#../..#../..#..",
	"U": "#..#/#..#/#..#/#..#/#..#/#..#/.##.",
	"V": "#...#/#...#/#...#/.#.#./.#.#./..#../..#..",
	"W": "#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#",
	"X": "#..#/#..#/.##./.##./.##./#..#/#..#",
	"Y": "#...#/#...#/.#.#./..#../..#../..#../..#..",
	"Z": "####/...#/..#./.#../#.../#.../####",
	"a": "2:.##./...#/.###/#..#/.###",
	"b": "#.../#.../###./#..#/#..#/#..#/###.",
	"c": "2:.###/#.../#.../#.../.###",
	"d": "...#/...#/.###/#..#/#..#/#..#/.###",
	"e": "2:.##./#..#/####/#.../.###",
	"f": "..#/.#./###/.#./.#./.#./.#.",
	"g": "2:.###/#..#/#..#/#..#/.###/...#/.##.",
	"h": "#.../#.../###./#..#/#..#/#..#/#..#",
	"i": "#/./#/#/#/#/#",
	"j": ".#/../.#/.#/.#/.#/.#/.#/#.",
	"k": "#.../#.../#..#/#.#./##../#.#./#..#",
	"l": "#/#/#/#/#/#/#",
	"m": "2:##.#./#.#.#/#.#.#/#.#.#/#.#.#",
	"n": "2:###./#..#/#..#/#..#/#..#",
	"o": "2:.##./#..#/#..#/#..#/.##.",
	"p": "2:###./#..#/#..#/#..#/###./#.../#...",
	"q": "2:.###/#..#/#..#/#..#/.###/...#/...#",
	"r": "2:#.#/##./#../#../#..",
	"s": "2:.###/#.../.##./...#/###.",
	"t": ".#./.#./###/.#./.#./.#./..#",
	"u": "2:#..#/#..#/#..#/#..#/.###",
	"v": "2:#.#/#.#/#.#/#.#/.#.",
	"w": "2:#...#/#.#.#/#.#.#/#.#.#/.#.#.",
	"x": "2:#.#/#.#/.#./#.#/#.#",
	"y": "2:#..#/#..#/#..#/#..#/.###/...#/.##.",
	"z": "2:####/..#./.#../#.../####",
	"0": ".##./#..#/#.##/##.#/#..#/#..#/.##.",
	"1": ".#./##./.#./.#./.#./.#./###",
	"2": ".##./#..#/...#/..#./.#../#.../####",
	"3": "###./...#/...#/.##./...#/...#/###.",
	"4": "#..#/#..#/#..#/####/...#/...#/...#",
	"5": "####/#.../###./...#/...#/#..#/.##.",
	"6": ".##./#.../#.../###./#..#/#..#/.##.",
	"7": "####/...#/..#./..#./.#../.#../.#..",
	"8": ".##./#..#/#..#/.##./#..#/#..#/.##.",
	"9": ".##./#..#/#..#/.###/...#/...#/.##.",
	".": "6:#",
	",": "6:.#/#.",
	"!": "#/#/#/#/#/./#",
	"?": ".##./#..#/...#/..#./.#../..../.#..",
	":": "2:#/./././#",
	";": "2:.#/../../../.#/#.",
	"'": "#/#",
	"\"": "#.#/#.#",
	"-": "4:###",
	"+": "2:.#./.#./###/.#./.#.",
	"=": "3:###/.../###",
	"/": "...#/...#/..#./..#./.#../.#../#...",
	"\\": "#.../#.../.#../.#../..#./..#./...#",
	"(": ".#/#./#./#./#./#./.#",
	")": "#./.#/.#/.#/.#/.#/#.",
	"[": "##/#./#./#./#./#./##",
	"]": "##/.#/.#/.#/.#/.#/##",
	"<": "1:..#/.#./#../.#./..#",
	">": "1:#../.#./..#/.#./#..",
	"*": "1:#.#/.#./#.#",
	"%": "#..#/...#/..#./.##./.#../#.../#..#",
	"&": ".#.../#.#../#.#../.#.../#.#.#/#..#./.##.#",
	"#": ".#.#./.#.#./#####/.#.#./#####/.#.#./.#.#.",
	"_": "7:####",
	"|": "#/#/#/#/#/#/#",
}
## Characters drawn as another one's letter (typed quotes and dashes from a word
## processor): "this one": "looks like that one".
const ALIASES: Dictionary = {"’": "'", "‘": "'", "“": "\"", "”": "\"", "–": "-", "—": "-"}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_FOLDER))
	var characters: Array = GLYPHS.keys()
	# Where each letter goes in the picture: left to right, a new row of cells when
	# the next one wouldn't fit.
	var boxes: Dictionary = {}  # character -> Rect2i in the picture
	var pen: Vector2i = Vector2i.ZERO
	for character: String in characters:
		var width: int = _glyph_width(GLYPHS[character] as String)
		if pen.x + width > PICTURE_WIDTH:
			pen = Vector2i(0, pen.y + CELL_HEIGHT + 1)
		boxes[character] = Rect2i(pen, Vector2i(width, CELL_HEIGHT))
		pen.x += width + 1
	var picture: Image = Image.create(PICTURE_WIDTH, pen.y + CELL_HEIGHT, false, Image.FORMAT_RGBA8)
	for character: String in characters:
		_paint_glyph(picture, (boxes[character] as Rect2i).position, GLYPHS[character] as String)
	picture.save_png(OUTPUT_FOLDER.path_join(PICTURE_NAME))
	# The .fnt: one "char" line per letter (its unicode number, its box in the
	# picture, and xadvance = how far the pen moves after it).
	var lines: PackedStringArray = PackedStringArray()
	lines.append("info face=\"AttunePixel\" size=%d bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0" % CELL_HEIGHT)
	lines.append("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % [LINE_HEIGHT, BASELINE, picture.get_width(), picture.get_height()])
	lines.append("page id=0 file=\"%s\"" % PICTURE_NAME)
	lines.append("chars count=%d" % (characters.size() + ALIASES.size() + 1))
	lines.append("char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15" % SPACE_ADVANCE)
	for character: String in characters:
		lines.append(_char_line(character.unicode_at(0), boxes[character] as Rect2i))
	for alias: String in ALIASES:
		lines.append(_char_line(alias.unicode_at(0), boxes[ALIASES[alias]] as Rect2i))
	var file: FileAccess = FileAccess.open(OUTPUT_FOLDER.path_join(FONT_NAME), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("[PixelFont] %d letters -> %s" % [characters.size(), OUTPUT_FOLDER.path_join(FONT_NAME)])
	get_tree().quit()


func _char_line(code: int, box: Rect2i) -> String:
	return "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15" % [
		code, box.position.x, box.position.y, box.size.x, box.size.y, box.size.x + LETTER_GAP]


## A letter's rows, top to bottom, from its text (see the header): the rows skipped
## by "N:" come first, as empty strings.
func _glyph_rows(glyph: String) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	var body: String = glyph
	if glyph.length() > 2 and glyph[1] == ":" and glyph[0].is_valid_int():
		for skipped: int in int(glyph[0]):
			rows.append("")
		body = glyph.substr(2)
	rows.append_array(body.split("/"))
	return rows


func _glyph_width(glyph: String) -> int:
	var width: int = 0
	for row: String in _glyph_rows(glyph):
		width = maxi(width, row.length())
	return width


## Writes a letter's "#" pixels in white at `origin` (the font is tinted when drawn).
func _paint_glyph(picture: Image, origin: Vector2i, glyph: String) -> void:
	var rows: PackedStringArray = _glyph_rows(glyph)
	for y: int in mini(rows.size(), CELL_HEIGHT):
		for x: int in rows[y].length():
			if rows[y][x] == "#":
				picture.set_pixel(origin.x + x, origin.y + y, Color.WHITE)

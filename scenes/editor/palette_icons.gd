class_name PaletteIcons
extends RefCounted
## PaletteIcons: the small picture on each level editor palette button (after the
## L11 play-test: "a little visual hint to what each button is"). EditorUI asks
## PaletteIcons.get_icon(entry) for every button.
##
## Each icon is a 10x10 pixel-art picture drawn into an Image from a few shapes,
## in the colors of GAME_DESIGN.md §2 (crates brown, enemies purple, windmills
## yellow...), so it looks like the thing it places. No image files: a new palette
## entry without a drawing here gets a plain square in its element's color.
##
## Godot concepts used:
##   - Image: pixels in memory you can set; ImageTexture: an Image the GPU can draw,
##     here as a Button's icon.

const SIZE: int = 10

## The game's color key (GAME_DESIGN.md §2) plus the elements' own colors.
const GRAY: Color = Color(0.45, 0.45, 0.5)
const DARK_GRAY: Color = Color(0.28, 0.28, 0.32)
const GRASS_GREEN: Color = Color(0.36, 0.7, 0.3)
const DARK_GREEN: Color = Color(0.13, 0.3, 0.13)
const EARTH_BROWN: Color = Color(0.58, 0.38, 0.2)
const EARTH_TAN: Color = Color(0.85, 0.68, 0.4)
const CRATE_BROWN: Color = Color(0.55, 0.36, 0.2)
const RED: Color = Color(0.9, 0.2, 0.2)
const CYAN: Color = Color(0.55, 0.88, 1.0)
const YELLOW: Color = Color(1.0, 0.85, 0.25)
const ORANGE: Color = Color(1.0, 0.55, 0.15)
const PURPLE: Color = Color(0.62, 0.35, 0.85)
const BLUE_GRAY: Color = Color(0.5, 0.58, 0.7)
const TAN: Color = Color(0.82, 0.72, 0.5)
const OLIVE: Color = Color(0.5, 0.55, 0.25)
const CREAM: Color = Color(0.95, 0.9, 0.75)
const WHITE: Color = Color(1.0, 1.0, 1.0)
const LEAF_GOLD: Color = Color(0.7, 0.63, 0.38)
## Water_bending.md §12.1: the body and its light surface line.
const WATER_BLUE: Color = Color("#2F7FD1")
const FOAM_BLUE: Color = Color("#BFE4FF")

## Icons made so far, by entry id (each is drawn once).
static var _icons: Dictionary = {}


## The icon for `entry` (made on first use).
static func get_icon(entry: PaletteCatalog.Entry) -> Texture2D:
	if not _icons.has(entry.id):
		var image: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		_draw_icon(image, entry)
		_icons[entry.id] = ImageTexture.create_from_image(image)
	return _icons[entry.id]


## The element's color: Air cyan, Earth tan, Fire orange, Water blue; gray for none.
static func element_color(element: String) -> Color:
	match element:
		"Air":
			return CYAN
		"Earth":
			return EARTH_TAN
		"Fire":
			return ORANGE
		"Water":
			return WATER_BLUE
	return GRAY


static func _draw_icon(image: Image, entry: PaletteCatalog.Entry) -> void:
	match entry.id:
		# --- Tools ---
		&"select":
			# An arrow cursor.
			for row: int in 8:
				_rect(image, 1, 1 + row, floori(row / 2.0) + 1, 1, WHITE)
			_rect(image, 3, 7, 2, 3, WHITE)
		&"eraser":
			_rect(image, 1, 4, 8, 4, Color(1.0, 0.55, 0.6))
			_rect(image, 1, 4, 3, 4, WHITE)
		&"brush":
			# A paintbrush leaning right: handle, ferrule, a cyan tip.
			for step: int in 5:
				_rect(image, 6 - step, 1 + step, 2, 1, Color(0.75, 0.55, 0.35))
			_rect(image, 2, 6, 2, 1, GRAY)
			_rect(image, 1, 7, 2, 2, CYAN)
		&"fill":
			# A tipped bucket pouring a drop.
			_rect(image, 2, 2, 5, 5, GRAY)
			_rect(image, 3, 3, 3, 3, CYAN)
			_rect(image, 7, 6, 2, 3, CYAN)
		# --- Terrain ---
		&"ground":
			_rect(image, 0, 2, 10, 8, DARK_GRAY)
			_rect(image, 0, 2, 10, 2, GRAY)
		&"earth":
			_rect(image, 0, 2, 10, 8, EARTH_BROWN)
			_rect(image, 0, 2, 10, 2, EARTH_TAN)
		&"hidden_chamber":
			# Earth with a purple-striped tunnel through it (the editor's chamber look).
			_rect(image, 0, 2, 10, 8, EARTH_BROWN)
			_rect(image, 0, 2, 10, 2, EARTH_TAN)
			_rect(image, 2, 5, 6, 3, PURPLE.darkened(0.4))
			for x: int in [2, 5]:
				_rect(image, x, 5, 2, 3, PURPLE)
		&"grass":
			_rect(image, 0, 3, 10, 7, DARK_GREEN)
			_rect(image, 0, 3, 10, 2, GRASS_GREEN)
			for x: int in [1, 4, 7]:
				_rect(image, x, 1, 1, 2, GRASS_GREEN)
		&"water":
			# A pool in a dip of rock, with its light surface line.
			_rect(image, 0, 3, 10, 7, DARK_GRAY)
			_rect(image, 1, 4, 8, 5, WATER_BLUE)
			_rect(image, 1, 4, 8, 1, FOAM_BLUE)
		&"black_water":
			# A pool of ink with an oily violet surface line.
			_rect(image, 0, 3, 10, 7, DARK_GRAY)
			_rect(image, 1, 4, 8, 5, Color("#2A2236"))
			_rect(image, 1, 4, 8, 1, Color("#6B5A80"))
		&"ice":
			_rect(image, 0, 2, 10, 8, CYAN)
			_rect(image, 0, 2, 10, 1, WHITE)
		&"ice_slope_up_right", &"ice_slope_up_left", &"gentle_ice_slope_up_right", &"gentle_ice_slope_up_left":
			# The slope as a staircase of ice columns, rising toward its high side.
			var rises_right: bool = entry.id == &"ice_slope_up_right" or entry.id == &"gentle_ice_slope_up_right"
			var steep: bool = entry.id == &"ice_slope_up_right" or entry.id == &"ice_slope_up_left"
			for column: int in SIZE:
				var from_low: int = column if rises_right else SIZE - 1 - column
				var height: int = from_low + 1 if steep else floori(from_low / 2.0) + 1
				_rect(image, column, SIZE - height, 1, height, CYAN)
				_rect(image, column, SIZE - height, 1, 1, WHITE)
		&"crumble_rock":
			# Rock broken into blocks by dark cracks.
			_rect(image, 0, 2, 10, 8, Color(0.36, 0.34, 0.32))
			_rect(image, 0, 2, 10, 1, Color(0.55, 0.52, 0.48))
			_rect(image, 4, 3, 1, 4, DARK_GRAY)
			_rect(image, 1, 6, 4, 1, DARK_GRAY)
			_rect(image, 6, 5, 1, 5, DARK_GRAY)
		&"storm_cloud":
			# A dark cloud with a lit top and a bolt out of it.
			_rect(image, 1, 2, 8, 5, Color8(62, 56, 86))
			_rect(image, 2, 1, 3, 1, Color8(96, 90, 128))
			_rect(image, 5, 2, 3, 1, Color8(96, 90, 128))
			_rect(image, 5, 4, 1, 3, WHITE)
			_rect(image, 4, 7, 1, 1, WHITE)
			_rect(image, 4, 8, 2, 1, YELLOW)
		&"crumble_ice":
			# Ice with white cracks through it.
			_rect(image, 0, 2, 10, 8, CYAN)
			_rect(image, 0, 2, 10, 1, WHITE)
			_rect(image, 3, 4, 1, 3, WHITE)
			_rect(image, 4, 6, 3, 1, WHITE)
			_rect(image, 7, 7, 1, 3, WHITE)
		&"water_source":
			# A spout pouring a stream of water.
			_rect(image, 2, 1, 6, 2, DARK_GRAY)
			_rect(image, 4, 3, 2, 7, WATER_BLUE)
			_rect(image, 4, 3, 2, 1, FOAM_BLUE)
		&"current_zone":
			# Water with two streaks running right: a current.
			_rect(image, 0, 2, 10, 7, WATER_BLUE)
			_rect(image, 0, 2, 10, 1, FOAM_BLUE)
			_rect(image, 2, 4, 5, 1, FOAM_BLUE)
			_rect(image, 6, 3, 1, 3, FOAM_BLUE)
			_rect(image, 1, 7, 4, 1, FOAM_BLUE)
		&"water_sink":
			# A dark grate with light bars.
			_rect(image, 1, 3, 8, 5, DARK_GRAY)
			for x: int in [2, 4, 6]:
				_rect(image, x, 3, 1, 5, GRAY)
		&"thicket":
			_rect(image, 0, 0, 10, 10, DARK_GREEN)
			for spot: Vector2i in [Vector2i(1, 1), Vector2i(5, 2), Vector2i(2, 5), Vector2i(7, 6), Vector2i(4, 8)]:
				_rect(image, spot.x, spot.y, 2, 1, GRASS_GREEN)
		&"overgrown_grass":
			_rect(image, 0, 3, 10, 7, DARK_GREEN)
			_rect(image, 0, 3, 10, 2, GRASS_GREEN.lerp(EARTH_TAN, 0.3))
			_rect(image, 3, 6, 1, 4, EARTH_BROWN)
			_rect(image, 7, 5, 1, 3, EARTH_BROWN)
		&"overgrown_thicket":
			_rect(image, 0, 0, 10, 10, DARK_GREEN.lerp(EARTH_BROWN, 0.35))
			_rect(image, 2, 2, 2, 1, GRASS_GREEN)
			_rect(image, 6, 6, 2, 1, GRASS_GREEN)
			_rect(image, 4, 4, 1, 5, EARTH_BROWN)
		# --- Basics ---
		&"spawn_point":
			_rect(image, 3, 1, 4, 8, WHITE)
		&"goal":
			_rect(image, 2, 1, 1, 9, WHITE)
			_rect(image, 3, 1, 5, 4, GRASS_GREEN)
		&"spikes":
			for spike: int in 3:
				var x: int = 1 + spike * 3
				_rect(image, x + 1, 4, 1, 2, RED)
				_rect(image, x, 6, 3, 3, RED)
		&"wind_zone":
			_rect(image, 0, 0, 10, 10, Color(CYAN, 0.35))
			for y: int in [2, 5, 8]:
				_rect(image, 2, y, 5, 1, CYAN)
				_rect(image, 6, y - 1, 1, 1, CYAN)
		&"no_glide_zone":
			_rect(image, 0, 0, 10, 10, Color(GRAY, 0.4))
			for step: int in 8:
				_rect(image, 1 + step, 1 + step, 1, 1, RED)
		# --- Crystals ---
		&"wind_crystal":
			_diamond(image, 5, 5, 4, CYAN)
		&"gust_diamond":
			_diamond(image, 5, 5, 4, CYAN.lerp(WHITE, 0.4))
			_diamond(image, 5, 5, 1, WHITE)
		&"fire_diamond":
			_diamond(image, 5, 5, 4, ORANGE)
			_diamond(image, 5, 5, 1, YELLOW)
		# --- Triggers and what they open ---
		&"pressure_plate":
			_rect(image, 1, 7, 8, 2, TAN)
			_rect(image, 0, 9, 10, 1, DARK_GRAY)
		&"step_pad":
			_rect(image, 1, 7, 8, 2, TAN)
			_rect(image, 0, 9, 10, 1, DARK_GRAY)
			_rect(image, 4, 2, 2, 3, WHITE)  # a footstep arrow
			_rect(image, 3, 4, 4, 1, WHITE)
		&"switch_wall":
			_rect(image, 1, 0, 8, 10, GRAY)
			_rect(image, 4, 0, 1, 10, BLUE_GRAY)
		&"windmill":
			_rect(image, 4, 1, 2, 8, YELLOW)
			_rect(image, 1, 4, 8, 2, YELLOW)
			_rect(image, 4, 4, 2, 2, CRATE_BROWN)
		&"brazier":
			_rect(image, 2, 6, 6, 2, DARK_GRAY)
			_rect(image, 4, 8, 2, 2, DARK_GRAY)
			_rect(image, 4, 2, 2, 4, ORANGE)
			_rect(image, 4, 4, 2, 2, YELLOW)
		&"enemy_gate":
			_rect(image, 1, 2, 2, 8, PURPLE)
			_rect(image, 7, 2, 2, 8, PURPLE)
			_rect(image, 1, 1, 8, 2, PURPLE)
		&"depth_gate":
			# A stone arch with the hazed blue of the layer behind inside.
			_rect(image, 2, 3, 6, 7, Color(0.3, 0.4, 0.7))
			_rect(image, 1, 3, 1, 7, BLUE_GRAY)
			_rect(image, 8, 3, 1, 7, BLUE_GRAY)
			_rect(image, 2, 1, 6, 2, BLUE_GRAY)
			_rect(image, 4, 5, 2, 2, CYAN)
		&"door":
			_rect(image, 3, 0, 4, 10, BLUE_GRAY)
			_rect(image, 3, 0, 1, 10, BLUE_GRAY.darkened(0.3))
		# --- Breakable ---
		&"cracked_wall":
			_rect(image, 1, 0, 8, 10, GRAY)
			for step: int in 4:
				_rect(image, 3 + step % 2, 1 + step * 2, 1, 2, DARK_GRAY)
		&"stone_wall":
			_rect(image, 1, 0, 8, 10, DARK_GRAY)
			_rect(image, 1, 3, 8, 1, GRAY)
			_rect(image, 1, 7, 8, 1, GRAY)
			_rect(image, 4, 0, 1, 3, GRAY)
			_rect(image, 6, 4, 1, 3, GRAY)
		&"metal_platform":
			_rect(image, 0, 4, 10, 3, BLUE_GRAY.darkened(0.2))
			_rect(image, 0, 4, 10, 1, WHITE.darkened(0.2))
			_rect(image, 2, 5, 1, 1, DARK_GRAY)
			_rect(image, 7, 5, 1, 1, DARK_GRAY)
			_rect(image, 1, 7, 2, 2, DARK_GRAY)
			_rect(image, 7, 7, 2, 2, DARK_GRAY)
		# --- Objects ---
		&"crate":
			_rect(image, 1, 1, 8, 8, CRATE_BROWN.darkened(0.3))
			_rect(image, 2, 2, 6, 6, CRATE_BROWN)
		&"leaf_platform":
			_rect(image, 0, 5, 10, 2, OLIVE)
			_rect(image, 4, 2, 2, 2, CREAM)
		&"rail_platform":
			# A gray platform on a bent rail.
			_rect(image, 1, 8, 4, 1, BLUE_GRAY)
			_rect(image, 4, 3, 1, 6, BLUE_GRAY)
			_rect(image, 4, 3, 5, 1, BLUE_GRAY)
			_rect(image, 0, 5, 7, 2, GRAY)
			_rect(image, 0, 5, 7, 1, WHITE.darkened(0.3))
		&"sail_platform":
			_rect(image, 0, 7, 10, 2, BLUE_GRAY.darkened(0.2))
			for row: int in 5:
				_rect(image, 4, 2 + row, row + 1, 1, CREAM)
		&"boulder":
			_rect(image, 2, 2, 6, 7, GRAY)
			_rect(image, 1, 4, 8, 4, GRAY)
			_rect(image, 3, 3, 2, 1, WHITE.darkened(0.2))
		&"loose_rock":
			_rect(image, 3, 5, 4, 4, GRAY)
			_rect(image, 4, 5, 1, 1, WHITE.darkened(0.2))
		&"vine":
			for y: int in 10:
				_rect(image, 4 + floori(y / 3.0) % 2, y, 1, 1, GRASS_GREEN)
		&"hanging_platform":
			_rect(image, 2, 0, 1, 6, GRASS_GREEN)
			_rect(image, 7, 0, 1, 6, GRASS_GREEN)
			_rect(image, 0, 6, 10, 2, CRATE_BROWN)
		&"leaf_pile":
			_rect(image, 1, 7, 8, 2, OLIVE)
			_rect(image, 2, 5, 6, 2, LEAF_GOLD)
			_rect(image, 4, 4, 2, 1, OLIVE)
		# --- Enemies (purple, GAME_DESIGN.md §2) ---
		&"wisp":
			_rect(image, 2, 3, 6, 6, PURPLE)
			_rect(image, 3, 4, 1, 1, WHITE)
			_rect(image, 6, 4, 1, 1, WHITE)
		&"leaf_wisp":
			_rect(image, 2, 3, 6, 6, GRASS_GREEN)
			_rect(image, 1, 5, 2, 3, GRASS_GREEN.darkened(0.3))
			_rect(image, 7, 4, 2, 3, GRASS_GREEN.lightened(0.2))
			_rect(image, 3, 4, 1, 1, PURPLE)
			_rect(image, 6, 4, 1, 1, PURPLE)
		&"sentry":
			_rect(image, 2, 5, 6, 4, PURPLE)
			_rect(image, 4, 2, 2, 3, PURPLE.darkened(0.3))
			_rect(image, 4, 6, 2, 2, ORANGE)
		&"vine_monkey":
			_rect(image, 2, 3, 6, 5, PURPLE)
			_rect(image, 1, 1, 8, 2, GRASS_GREEN)
			_rect(image, 3, 8, 1, 2, PURPLE)
			_rect(image, 6, 8, 1, 2, PURPLE)
		&"thicket_elephant":
			_rect(image, 1, 2, 8, 6, PURPLE.darkened(0.2))
			_rect(image, 1, 1, 8, 2, GRASS_GREEN)
			_rect(image, 0, 5, 2, 5, PURPLE.darkened(0.2))
			_rect(image, 6, 8, 2, 2, PURPLE.darkened(0.2))
		&"shell":
			_rect(image, 1, 5, 8, 4, EARTH_TAN)
			_rect(image, 2, 3, 6, 2, EARTH_TAN)
			_rect(image, 1, 8, 8, 1, PURPLE)
		_:
			_rect(image, 2, 2, 6, 6, element_color(entry.element))


## A filled rectangle, clipped to the icon.
static func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var area: Rect2i = Rect2i(x, y, width, height).intersection(Rect2i(0, 0, SIZE, SIZE))
	if area.has_area():
		image.fill_rect(area, color)


## A filled diamond (|dx| + |dy| <= radius) around (center_x, center_y).
static func _diamond(image: Image, center_x: int, center_y: int, radius: int, color: Color) -> void:
	for dy: int in range(-radius, radius + 1):
		var half_width: int = radius - absi(dy)
		_rect(image, center_x - half_width, center_y + dy, half_width * 2 + 1, 1, color)

class_name GroundPalettes
extends RefCounted
## GroundPalettes: the ground's COLORS per backdrop look (after the art pass: one grey,
## one green and one tan with a near-black inside sat in front of every backdrop, so
## the play layer never looked like part of the place behind it).
##
## Static only (never instanced): GroundPainter asks it once per room for the colors
## of the room's look (Room.get_backdrop_theme()), GrassLayer for its blades, and
## RoomEdgeRim and MudLook get theirs through the painter.
##
## A palette is [crust, rim, edge line, inside, hatch stripe, deep]: the five colors
## GroundPainter.PALETTE has always had, plus DEEP, the color the inside fades to far
## from any surface (it used to fade to almost black everywhere). It's the same order
## as BackdropTerrain's palettes.
##
## THE RULES the palettes follow (keep them when adding a look):
##   - Each kind keeps its identity in every look, because it means something in
##     play: GRAY is stone (never digs, never burns), GRASS is green on top (it
##     burns), EARTH is tan (you bend it). A look only TINTS them.
##   - The ground shares the look's temperature (warm stone at dusk, violet stone in
##     the caves), but its crust and rim stay BRIGHTER and more saturated than
##     anything in the backdrop: the play layer reads first (BACKDROP_GUIDE.md §2.6).
##     Copying the backdrop's own colors makes the ground sink into it.
##   - DEEP is a dark shade of the look's air, not black. In the dark looks keep its
##     luminance under ~0.12, so an opened hidden chamber still stands out.
##
## A look with no entry here (and Backdrop.Look.NONE) gets GroundPainter.PALETTE with
## its old near-black deep: exactly the colors from before this file existed.

const CRUST: int = 0
const RIM: int = 1
const EDGE: int = 2
const INSIDE: int = 3
const HATCH: int = 4
const DEEP: int = 5

## Grass blades: the lighter of the two greens is the grass rim; the darker one is
## the rim pulled this far toward the crust.
const BLADE_DARK_BLEND: float = 0.8

## Burnt grass keeps the look's inside, pulled toward these (a fraction each): the
## crust chars, and the ground under it darkens with it.
const BURNING_INSIDE: Color = Color(0.06, 0.04, 0.03)
const BURNING_INSIDE_AMOUNT: float = 0.3
const SMOLDERING_INSIDE: Color = Color(0.06, 0.06, 0.06)
const SMOLDERING_INSIDE_AMOUNT: float = 0.6
const ASH_INSIDE: Color = Color(0.1, 0.1, 0.1)
const ASH_INSIDE_AMOUNT: float = 0.7

## Per look, per GroundPainter.Kind: [crust, rim, edge line, inside, hatch, deep].
const LOOKS: Dictionary = {
	# Night over snow peaks: blue-violet stone, a navy deep.
	Backdrop.Look.MOUNTAIN: {
		GroundPainter.Kind.GRAY: [Color(0.36, 0.37, 0.45), Color(0.54, 0.54, 0.62), Color(0.17, 0.17, 0.24),
			Color(0.15, 0.14, 0.22), Color(0.19, 0.18, 0.27), Color(0.05, 0.045, 0.09)],
		GroundPainter.Kind.GRASS: [Color(0.3, 0.57, 0.3), Color(0.5, 0.77, 0.38), Color(0.1, 0.28, 0.17),
			Color(0.13, 0.15, 0.21), Color(0.17, 0.19, 0.26), Color(0.05, 0.05, 0.09)],
		GroundPainter.Kind.EARTH: [Color(0.7, 0.54, 0.3), Color(0.86, 0.7, 0.44), Color(0.4, 0.24, 0.15),
			Color(0.26, 0.14, 0.14), Color(0.33, 0.18, 0.16), Color(0.07, 0.04, 0.065)],
	},
	# Lantern-lit halls at night: slate-violet stone.
	Backdrop.Look.TEMPLE: {
		GroundPainter.Kind.GRAY: [Color(0.39, 0.36, 0.46), Color(0.62, 0.56, 0.6), Color(0.17, 0.15, 0.23),
			Color(0.17, 0.14, 0.22), Color(0.22, 0.18, 0.27), Color(0.05, 0.04, 0.08)],
		GroundPainter.Kind.GRASS: [Color(0.3, 0.53, 0.3), Color(0.52, 0.73, 0.38), Color(0.1, 0.26, 0.17),
			Color(0.14, 0.14, 0.2), Color(0.18, 0.18, 0.25), Color(0.05, 0.045, 0.08)],
		GroundPainter.Kind.EARTH: [Color(0.68, 0.5, 0.3), Color(0.85, 0.68, 0.44), Color(0.38, 0.22, 0.15),
			Color(0.25, 0.14, 0.14), Color(0.31, 0.18, 0.17), Color(0.07, 0.04, 0.06)],
	},
	# A forest at dusk: mossy stone, leaf-mould soil.
	Backdrop.Look.FOREST: {
		GroundPainter.Kind.GRAY: [Color(0.39, 0.41, 0.37), Color(0.6, 0.62, 0.5), Color(0.17, 0.2, 0.17),
			Color(0.13, 0.15, 0.12), Color(0.17, 0.2, 0.15), Color(0.04, 0.055, 0.04)],
		GroundPainter.Kind.GRASS: [Color(0.31, 0.57, 0.22), Color(0.53, 0.77, 0.3), Color(0.1, 0.28, 0.12),
			Color(0.17, 0.13, 0.09), Color(0.22, 0.17, 0.11), Color(0.05, 0.045, 0.035)],
		GroundPainter.Kind.EARTH: [Color(0.66, 0.5, 0.27), Color(0.84, 0.68, 0.4), Color(0.38, 0.23, 0.12),
			Color(0.25, 0.14, 0.09), Color(0.31, 0.18, 0.11), Color(0.06, 0.04, 0.03)],
	},
	# Mesas at sunset: mauve sandstone, dry grass, a wine-dark deep.
	Backdrop.Look.DESERT: {
		GroundPainter.Kind.GRAY: [Color(0.5, 0.41, 0.41), Color(0.74, 0.6, 0.52), Color(0.26, 0.18, 0.2),
			Color(0.22, 0.14, 0.16), Color(0.28, 0.18, 0.19), Color(0.07, 0.04, 0.06)],
		GroundPainter.Kind.GRASS: [Color(0.4, 0.57, 0.24), Color(0.6, 0.76, 0.32), Color(0.15, 0.29, 0.12),
			Color(0.2, 0.13, 0.11), Color(0.26, 0.17, 0.13), Color(0.07, 0.04, 0.05)],
		GroundPainter.Kind.EARTH: [Color(0.76, 0.56, 0.28), Color(0.9, 0.72, 0.42), Color(0.43, 0.24, 0.13),
			Color(0.28, 0.13, 0.1), Color(0.35, 0.18, 0.12), Color(0.08, 0.04, 0.045)],
	},
	# Under the sea: blue-green rock, sea grass, a deep teal.
	Backdrop.Look.UNDERWATER: {
		GroundPainter.Kind.GRAY: [Color(0.35, 0.43, 0.48), Color(0.54, 0.66, 0.68), Color(0.14, 0.2, 0.26),
			Color(0.1, 0.15, 0.2), Color(0.13, 0.19, 0.25), Color(0.025, 0.05, 0.08)],
		GroundPainter.Kind.GRASS: [Color(0.24, 0.57, 0.36), Color(0.44, 0.77, 0.46), Color(0.08, 0.28, 0.22),
			Color(0.08, 0.15, 0.18), Color(0.11, 0.2, 0.22), Color(0.025, 0.05, 0.07)],
		GroundPainter.Kind.EARTH: [Color(0.66, 0.54, 0.34), Color(0.82, 0.72, 0.48), Color(0.34, 0.26, 0.2),
			Color(0.2, 0.15, 0.15), Color(0.26, 0.19, 0.18), Color(0.04, 0.045, 0.06)],
	},
	# Misty rainforest: green-grey stone, rich soil.
	Backdrop.Look.JUNGLE: {
		GroundPainter.Kind.GRAY: [Color(0.4, 0.44, 0.38), Color(0.62, 0.66, 0.52), Color(0.18, 0.23, 0.18),
			Color(0.14, 0.18, 0.14), Color(0.18, 0.23, 0.17), Color(0.04, 0.07, 0.05)],
		GroundPainter.Kind.GRASS: [Color(0.26, 0.58, 0.22), Color(0.5, 0.8, 0.3), Color(0.08, 0.3, 0.12),
			Color(0.17, 0.14, 0.09), Color(0.22, 0.18, 0.11), Color(0.05, 0.055, 0.035)],
		GroundPainter.Kind.EARTH: [Color(0.64, 0.48, 0.26), Color(0.82, 0.66, 0.38), Color(0.36, 0.22, 0.12),
			Color(0.25, 0.15, 0.09), Color(0.31, 0.19, 0.11), Color(0.06, 0.045, 0.03)],
	},
	# A bright beach: warm cliff stone, sandy earth, brown soil (a daylight look, so
	# the inside stays light).
	Backdrop.Look.SHORE: {
		GroundPainter.Kind.GRAY: [Color(0.5, 0.45, 0.42), Color(0.8, 0.74, 0.62), Color(0.29, 0.24, 0.25),
			Color(0.36, 0.3, 0.3), Color(0.42, 0.35, 0.34), Color(0.2, 0.16, 0.2)],
		GroundPainter.Kind.GRASS: [Color(0.32, 0.61, 0.25), Color(0.64, 0.86, 0.4), Color(0.14, 0.36, 0.17),
			Color(0.4, 0.31, 0.22), Color(0.47, 0.37, 0.26), Color(0.24, 0.18, 0.16)],
		GroundPainter.Kind.EARTH: [Color(0.76, 0.63, 0.4), Color(0.92, 0.84, 0.6), Color(0.44, 0.32, 0.21),
			Color(0.43, 0.31, 0.22), Color(0.5, 0.37, 0.26), Color(0.25, 0.18, 0.16)],
	},
	# Lava fields at night: cool violet basalt (so it stands off the orange), scorched
	# yellow-green grass.
	Backdrop.Look.VOLCANO: {
		GroundPainter.Kind.GRAY: [Color(0.42, 0.36, 0.4), Color(0.72, 0.6, 0.54), Color(0.18, 0.12, 0.15),
			Color(0.18, 0.1, 0.12), Color(0.23, 0.13, 0.14), Color(0.06, 0.03, 0.04)],
		GroundPainter.Kind.GRASS: [Color(0.38, 0.55, 0.2), Color(0.74, 0.74, 0.3), Color(0.13, 0.24, 0.1),
			Color(0.19, 0.11, 0.09), Color(0.24, 0.14, 0.11), Color(0.06, 0.03, 0.035)],
		GroundPainter.Kind.EARTH: [Color(0.6, 0.4, 0.22), Color(0.82, 0.6, 0.34), Color(0.3, 0.16, 0.1),
			Color(0.22, 0.12, 0.1), Color(0.27, 0.15, 0.11), Color(0.06, 0.03, 0.035)],
	},
	# Pale cliffs in daylight: stone a step DARKER than the backdrop's cliffs, brown soil.
	Backdrop.Look.SANCTUM: {
		GroundPainter.Kind.GRAY: [Color(0.46, 0.42, 0.46), Color(0.84, 0.8, 0.72), Color(0.27, 0.23, 0.28),
			Color(0.35, 0.31, 0.35), Color(0.41, 0.36, 0.4), Color(0.2, 0.17, 0.24)],
		GroundPainter.Kind.GRASS: [Color(0.31, 0.61, 0.25), Color(0.62, 0.85, 0.42), Color(0.13, 0.36, 0.18),
			Color(0.38, 0.3, 0.26), Color(0.45, 0.35, 0.3), Color(0.23, 0.18, 0.2)],
		GroundPainter.Kind.EARTH: [Color(0.68, 0.54, 0.36), Color(0.86, 0.74, 0.5), Color(0.4, 0.28, 0.2),
			Color(0.42, 0.3, 0.22), Color(0.49, 0.35, 0.25), Color(0.25, 0.18, 0.18)],
	},
	# Dense green forest in mist.
	Backdrop.Look.DEEPWOOD: {
		GroundPainter.Kind.GRAY: [Color(0.38, 0.44, 0.4), Color(0.6, 0.7, 0.56), Color(0.16, 0.23, 0.2),
			Color(0.13, 0.19, 0.16), Color(0.17, 0.24, 0.19), Color(0.04, 0.08, 0.06)],
		GroundPainter.Kind.GRASS: [Color(0.24, 0.6, 0.24), Color(0.48, 0.84, 0.32), Color(0.07, 0.3, 0.14),
			Color(0.2, 0.15, 0.1), Color(0.26, 0.19, 0.12), Color(0.06, 0.06, 0.04)],
		GroundPainter.Kind.EARTH: [Color(0.64, 0.48, 0.26), Color(0.82, 0.66, 0.38), Color(0.36, 0.22, 0.12),
			Color(0.25, 0.15, 0.09), Color(0.31, 0.19, 0.11), Color(0.06, 0.045, 0.03)],
	},
	# Caves in a mountain range: violet stone, a plum deep.
	Backdrop.Look.CAVERN: {
		GroundPainter.Kind.GRAY: [Color(0.41, 0.38, 0.47), Color(0.64, 0.6, 0.68), Color(0.19, 0.16, 0.25),
			Color(0.17, 0.14, 0.22), Color(0.22, 0.18, 0.27), Color(0.06, 0.045, 0.09)],
		GroundPainter.Kind.GRASS: [Color(0.32, 0.6, 0.26), Color(0.5, 0.78, 0.34), Color(0.1, 0.3, 0.15),
			Color(0.15, 0.13, 0.18), Color(0.2, 0.17, 0.23), Color(0.055, 0.045, 0.08)],
		GroundPainter.Kind.EARTH: [Color(0.74, 0.56, 0.28), Color(0.88, 0.72, 0.42), Color(0.42, 0.24, 0.14),
			Color(0.27, 0.14, 0.13), Color(0.34, 0.18, 0.16), Color(0.08, 0.045, 0.07)],
	},
	# A forest on a volcano's flank at dusk: warm ash-grey rock, grass kept bright
	# (olive like the backdrop's moss sank into the canopy), an umber deep.
	Backdrop.Look.EMBERWOOD: {
		GroundPainter.Kind.GRAY: [Color(0.46, 0.38, 0.38), Color(0.8, 0.66, 0.54), Color(0.2, 0.13, 0.15),
			Color(0.2, 0.12, 0.13), Color(0.25, 0.15, 0.15), Color(0.07, 0.035, 0.05)],
		GroundPainter.Kind.GRASS: [Color(0.4, 0.58, 0.2), Color(0.78, 0.78, 0.32), Color(0.13, 0.26, 0.1),
			Color(0.2, 0.12, 0.1), Color(0.25, 0.15, 0.12), Color(0.07, 0.035, 0.045)],
		GroundPainter.Kind.EARTH: [Color(0.6, 0.4, 0.22), Color(0.82, 0.6, 0.34), Color(0.3, 0.16, 0.1),
			Color(0.22, 0.12, 0.1), Color(0.27, 0.15, 0.11), Color(0.07, 0.035, 0.045)],
	},
	# A green valley at midday: warm stone, brown soil under the turf (a daylight
	# look, so the inside stays light).
	Backdrop.Look.HIGHLANDS: {
		GroundPainter.Kind.GRAY: [Color(0.5, 0.46, 0.43), Color(0.8, 0.76, 0.64), Color(0.29, 0.25, 0.27),
			Color(0.37, 0.32, 0.33), Color(0.43, 0.37, 0.37), Color(0.23, 0.19, 0.24)],
		GroundPainter.Kind.GRASS: [Color(0.3, 0.6, 0.24), Color(0.66, 0.88, 0.42), Color(0.14, 0.36, 0.17),
			Color(0.38, 0.28, 0.22), Color(0.45, 0.33, 0.25), Color(0.23, 0.17, 0.18)],
		GroundPainter.Kind.EARTH: [Color(0.66, 0.52, 0.34), Color(0.84, 0.72, 0.48), Color(0.38, 0.26, 0.18),
			Color(0.4, 0.28, 0.2), Color(0.47, 0.33, 0.23), Color(0.24, 0.17, 0.17)],
	},
}


## The six colors of `kind` (a GroundPainter.Kind: GRAY, GRASS or EARTH) in `look`.
static func get_palette(look: Backdrop.Look, kind: int) -> Array:
	if LOOKS.has(look) and (LOOKS[look] as Dictionary).has(kind):
		return LOOKS[look][kind]
	# No look: the old colors, with the old deep (the inside at its darkest).
	var colors: Array = (GroundPainter.PALETTE[kind] as Array).duplicate()
	colors.append((colors[INSIDE] as Color).darkened(1.0 - GroundPainter.INSIDE_DEEPEST_BRIGHTNESS))
	return colors


## Burnt grass in `look`, for one FireGrid.State (BURNING, SMOLDERING or ASH): the
## charred crust, rim and edge line of GroundPainter.FIRE_PALETTES (fire looks the
## same everywhere), over the look's own grass inside, darkened. Any colors past the
## fifth (ash's pale fleck) are kept. The deep is the grass's.
static func get_fire_palette(look: Backdrop.Look, state: FireGrid.State) -> Array:
	var colors: Array = (GroundPainter.FIRE_PALETTES[state] as Array).duplicate()
	var grass: Array = get_palette(look, GroundPainter.Kind.GRASS)
	var toward: Color = BURNING_INSIDE
	var amount: float = BURNING_INSIDE_AMOUNT
	if state == FireGrid.State.SMOLDERING:
		toward = SMOLDERING_INSIDE
		amount = SMOLDERING_INSIDE_AMOUNT
	elif state == FireGrid.State.ASH:
		toward = ASH_INSIDE
		amount = ASH_INSIDE_AMOUNT
	colors[INSIDE] = (grass[INSIDE] as Color).lerp(toward, amount)
	colors[HATCH] = (grass[HATCH] as Color).lerp(toward.lightened(0.04), amount)
	return colors


## The two blade greens of `look`: [lighter, darker].
static func get_blade_colors(look: Backdrop.Look) -> Array[Color]:
	var grass: Array = get_palette(look, GroundPainter.Kind.GRASS)
	var light: Color = grass[RIM]
	return [light, light.lerp(grass[CRUST] as Color, BLADE_DARK_BLEND)]

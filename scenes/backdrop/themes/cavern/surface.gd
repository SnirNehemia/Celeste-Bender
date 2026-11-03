class_name CavernSurface
extends BackdropTheme
## CAVERN, SURFACE: the upper cave, still inside the mountain. Dusky mauve air
## lit from above: daylight falls in shafts through cracks in the ceiling (the
## open ridge is right above: skyline.gd, through the rock). Walls of rock one
## behind another, holed with big openings, frame each other back into the haze;
## stalactites hang in from the top and a great dark pillar rises in front (all shared with the deep
## below: CavernStyle); bats flutter across and dust hangs in the light.
## Layers far to near; see BackdropTheme.
## (Below it: underground.gd, the deep, the same cave one soft change down.)

const SHAFT_COLOR: Color = Color(0.96, 0.9, 0.86, 0.075)
## The cracks of daylight in the ceiling: strip x of each shaft's top.
const SHAFT_XS: Array[float] = [70.0, 230.0, 390.0, 540.0]
const CRACK_COLOR: Color = Color(1.0, 0.95, 0.85, 0.7)


func _build_layers() -> void:
	# The rock band of the break out to the ridge (Backdrop.BREAK_SKYLINE_LOOKS).
	crust_colors = [CavernStyle.ROCK[BackdropTerrain.INSIDE], CavernStyle.ROCK[BackdropTerrain.CRUST]]
	CavernStyle.add_shared_layers(self, SURFACE_SECTION, func() -> void: pass, _add_shafts)

	var dust: BackdropMotes = BackdropMotes.new()
	dust.shape = BackdropMotes.Shape.DOT
	dust.mote_count = 22
	dust.colors = [Color(0.88, 0.8, 0.86, 0.35), Color(0.95, 0.88, 0.8, 0.25)]
	dust.velocity = Vector2(1.5, 2.0)
	dust.sway_amplitude = 3.0
	dust.sway_speed = 0.2
	dust.scroll_factor = 0.4
	dust.seed_value = 6401
	add_motes(dust)

	# Bats both ways across, fluttering (sway up and down as they fly sideways).
	for flock: int in 2:
		var bats: BackdropMotes = BackdropMotes.new()
		bats.shape = BackdropMotes.Shape.BAT
		bats.mote_count = 1  # two bats on screen in all: one each way
		bats.colors = [Color(0.09, 0.06, 0.11), Color(0.15, 0.1, 0.16)]
		bats.velocity = Vector2(22.0, -2.0) if flock == 0 else Vector2(-17.0, 1.5)
		bats.sway_amplitude = 5.0
		bats.sway_speed = 1.1
		bats.scroll_factor = 0.55
		bats.vertical_range = Vector2(12.0, 110.0)
		bats.seed_value = 6402 + flock
		add_motes(bats)


## Between wall 2 and wall 3 (CavernStyle.add_shared_layers' slot): the light shafts.
func _add_shafts() -> void:
	add_drawn_layer("Shafts", Vector2(0.12, 0.045), draw_shafts)


## Daylight falling in from the ceiling's cracks (BackdropTheme.draw_light_shafts),
## a bright slit at the top of each, a draw_extra.
static func draw_shafts(layer: BackdropLayer, copy_x: float, time: float) -> void:
	var top_y: float = BackdropPaint.row(-6)
	BackdropTheme.draw_light_shafts(layer, copy_x, time, SHAFT_XS, 8.0, 0.22, 175.0, SHAFT_COLOR, top_y)
	for shaft_x: float in SHAFT_XS:
		layer.draw_rect(Rect2(roundf(copy_x + shaft_x + 2.0), top_y + 4.0, 5.0, 1.0), CRACK_COLOR)

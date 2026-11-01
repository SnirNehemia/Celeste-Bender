@tool
class_name WaterSource
extends Node2D
## WaterSource (Stage W2, Water_bending.md §6.2): endless water. It pours `rate`
## units a second into its room's WaterWorld at its position: straight into the
## water when it's under a pool's surface, else as falling particles leaving at
## `launch_velocity`. A source above a lip makes a WATERFALL; one at the top of a
## channel, a STREAM (the water really flows: §6.2). Pair it with a WaterSink
## downstream, or the room slowly fills.
##
## Placed in the editor (palette: Objects tab, "Water source"); the room it's in
## gets a WaterWorld even without painted water (Room._has_water_source). Only the
## room on screen pours. Its water counts as "sourced" in the WaterWorld's books.
## Ice at its mouth stops it: freezing its waterfall into an ICE WALL (the ball in
## the falling water + 2, grid ice Stage I2: IcePlan.for_wall) stops the pour until
## the wall melts.
##
## @tool: the script also runs in the Godot editor, so the spout is drawn there.

const SPOUT_COLOR: Color = Color("#3E4A5C")
const SPOUT_RIM_COLOR: Color = Color("#BFE4FF")
## Ice this many px under the mouth stops the pour (a frozen waterfall). The wall
## starts in the tile holding this point (IcePlan.for_wall).
const FROZEN_CHECK_BELOW: float = 4.0

## Units of water a second (1 unit = one 8x8 tile of water).
@export_range(0.0, 20.0) var rate: float = 2.0
## How fast and which way the water leaves, px/s (straight down slowly by default).
@export var launch_velocity: Vector2 = Vector2(0.0, 30.0)
## The width it pours from, px (a wide source makes a wide waterfall).
@export_range(0.0, 32.0) var pour_width: float = 4.0

var world: WaterWorld
## Water owed but not poured yet, px² (a particle is poured once a whole one is owed).
var owed_area: float = 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if world == null:
		world = WaterWorld.find_at(get_tree(), global_position)
		if world == null:
			return
	if GameState.current_room != world.room:
		return  # only the room on screen pours
	var drop_area: float = world.water_tuning.drop_units * WaterWorld.UNIT_AREA
	var here: Vector2 = world.to_local(global_position)
	# Frozen at the mouth (its waterfall is an ice wall now): no water gets out until
	# the ice melts.
	if world.is_point_in_ice(here + Vector2(0.0, FROZEN_CHECK_BELOW)):
		owed_area = 0.0
		return
	owed_area += rate * WaterWorld.UNIT_AREA * delta
	while owed_area >= drop_area:
		var point: Vector2 = here + Vector2(randf_range(-0.5, 0.5) * pour_width, 0.0)
		# A small random nudge per particle (WaterTuning.pour_jitter_x/_y): enough to
		# keep a pour from being a perfect line of beads, small enough to stay a sheet.
		var tuning: WaterTuning = world.water_tuning
		var jitter: Vector2 = Vector2(randf_range(-1.0, 1.0) * tuning.pour_jitter_x,
			randf_range(-1.0, 1.0) * tuning.pour_jitter_y)
		if not world.pour(point, drop_area, launch_velocity + jitter):
			owed_area = drop_area  # the particle cap is full: wait (don't pile up a debt)
			break
		owed_area -= drop_area


## Death or R don't touch a source (it just keeps pouring); the WaterWorld's reset
## clears its water. Nothing to do here.


func _draw() -> void:
	# A little spout: a dark pipe end with a light rim where the water comes out.
	var half_width: float = maxf(pour_width, 4.0) / 2.0 + 1.0
	draw_rect(Rect2(-half_width, -5.0, half_width * 2.0, 5.0), SPOUT_COLOR)
	draw_rect(Rect2(-half_width, -1.0, half_width * 2.0, 1.0), SPOUT_RIM_COLOR)

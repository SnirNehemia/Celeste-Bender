@tool
class_name NoGlideZone
extends Node2D
## No-glide zone ("dead air"): a rectangle where the air won't hold you. You can't
## start a glide inside it, and a glide that drifts into it ends at once (you drop
## like a normal fall). Jumps, gusts and the flame jet still work, so it turns a pass you
## could float over into one you have to gust, jet or wall-jump through.
##
## The node's position is the zone's TOP-LEFT corner and `zone_size` its size (same
## convention as WindZone).
##
## How it works: the zone doesn't touch the player at all. It joins GROUP, and
## GlideAbility.can_glide() asks "is the player inside any zone of that group?"
## (contains_point()). The Glide state already drops to Fall when can_glide() turns
## false, and starting a glide already checks it, so nothing else needed changing.
## No Area2D needed either: a rectangle check on one point is enough, and it can't
## miss an exit when the player respawns (teleports) out of the zone.
##
## Look (art pass: no box, no border, no hatching): a dim mauve-gray patch that fades
## out toward its edge in steps (ZoneFill), and specks sinking slowly straight down:
## "still, heavy air", clearly not the cyan wind with its racing streaks. The patch
## still ends exactly at the zone's edge.

## Not in the §2 color key: dim mauve-gray, so it can't be mistaken for a wind zone.
const FILL_COLOR: Color = Color(0.5, 0.36, 0.48, 0.22)
const SPECK_COLOR: Color = Color(0.8, 0.65, 0.75, 0.6)
## Every no-glide zone joins this group, so GlideAbility can find them.
const GROUP: StringName = &"no_glide_zones"

## Size of the zone in px.
@export var zone_size: Vector2 = Vector2(64, 96):
	set(value):
		zone_size = value
		_setup_specks()
		queue_redraw()

var specks: CPUParticles2D


func _ready() -> void:
	specks = CPUParticles2D.new()
	add_child(specks)
	_setup_specks()
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


## True if `world_point` is inside this zone.
func contains_point(world_point: Vector2) -> bool:
	return Rect2(global_position, zone_size).has_point(world_point)


func _draw() -> void:
	ZoneFill.draw_soft_rect(self, Rect2(Vector2.ZERO, zone_size), FILL_COLOR)


## A few specks sinking slowly and straight down through the whole zone.
func _setup_specks() -> void:
	if specks == null:
		return  # setter ran while the scene was loading; _ready() calls us again
	var sink_speed: float = 12.0
	specks.position = zone_size / 2.0
	specks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	specks.emission_rect_extents = zone_size / 2.0
	specks.direction = Vector2.DOWN
	specks.spread = 0.0
	specks.gravity = Vector2.ZERO
	specks.initial_velocity_min = sink_speed * 0.7
	specks.initial_velocity_max = sink_speed * 1.3
	specks.lifetime = 2.5
	specks.amount = clampi(int(zone_size.x * zone_size.y / 250.0), 4, 200)
	specks.preprocess = specks.lifetime  # already full when the room appears
	specks.color = SPECK_COLOR
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	specks.color_ramp = fade
	specks.emitting = true

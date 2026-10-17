class_name AirBlastDebugDraw
extends Node2D
## Debug drawing for air blasts (gust and dash wake). Toggle with F3 (`debug_gust_hitbox`).
## Lives under the Player:  Player > AirBlastDebugDraw
##
## When on, it draws:
##   - a faint yellow outline where a gust WOULD go right now (current aim; a
##     circle when no arrow is held = neutral gust)
##   - a bright flash of every real blast's cone for a moment, with a magenta box on
##     each Pushable object it hit
## Abilities report their blasts with record_blast(); this node only draws, it never
## changes the game, so it can be deleted without breaking anything.
##
## top_level = true makes this node ignore its parent's transform, so its own
## coordinates ARE world coordinates. A flash stays where the blast happened while
## the player flies off.

const PREVIEW_COLOR: Color = Color(1.0, 1.0, 0.3, 0.35)
const FLASH_COLOR: Color = Color(1.0, 1.0, 0.3, 0.9)
const HIT_COLOR: Color = Color(1.0, 0.3, 0.9, 1.0)

## True while F3 drawing is on.
var enabled: bool = false
## The player this belongs to. The parent node, set in _ready().
var player: Player
## Recent blasts still flashing. Each entry: {"cone": PackedVector2Array,
## "hits": Array[Vector2] (world positions), "time_left": float}.
var recent_blasts: Array[Dictionary] = []


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	global_position = Vector2.ZERO
	z_index = 50  # on top of the player and the room


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_gust_hitbox"):
		enabled = not enabled
		queue_redraw()  # also clears the drawing when turned off


func _physics_process(delta: float) -> void:
	for blast: Dictionary in recent_blasts:
		blast["time_left"] = float(blast["time_left"]) - delta
	recent_blasts = recent_blasts.filter(func(blast: Dictionary) -> bool: return float(blast["time_left"]) > 0.0)
	if enabled:
		queue_redraw()


## Called by GustAbility / AirDashAbility after every blast.
func record_blast(cone_points: PackedVector2Array, hit_nodes: Array[Node]) -> void:
	var hit_positions: Array[Vector2] = []
	for target: Node in hit_nodes:
		var target_2d: Node2D = target as Node2D
		if target_2d != null:
			hit_positions.append(target_2d.global_position)
	recent_blasts.append({
		"cone": cone_points,
		"hits": hit_positions,
		"time_left": player.tuning.gust_debug_flash_time,
	})


## Coordinates here are world coordinates (top_level, positioned at 0,0).
func _draw() -> void:
	if not enabled or player == null:
		return
	if not player.is_dead():
		_draw_outline(player.gust.build_gust_shape(player.get_aim_input()), PREVIEW_COLOR)
	for blast: Dictionary in recent_blasts:
		var cone: PackedVector2Array = blast["cone"]
		var fill_color: Color = FLASH_COLOR
		fill_color.a = 0.25
		draw_colored_polygon(cone, fill_color)
		_draw_outline(cone, FLASH_COLOR)
		for hit_position: Vector2 in blast["hits"]:
			draw_rect(Rect2(hit_position - Vector2(3, 3), Vector2(6, 6)), HIT_COLOR, false, 1.0)


## A closed outline through `points` (draw_polyline doesn't close the shape itself).
func _draw_outline(points: PackedVector2Array, color: Color) -> void:
	var closed_points: PackedVector2Array = points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, color, 1.0)

@tool
class_name GustTestTarget
extends Area2D
## TEST ONLY (Stage 6): a floating dummy that proves the Pushable contract works.
## Not a game object; Stage 7's crates, windmills and leaves replace it.
##
## It follows the three Pushable steps (scenes/objects/pushable.gd):
##   1. joins the "pushable" group in _ready()
##   2. implements receive_gust(direction, strength)
##   3. is an Area2D on physics layer 4 ("pushable")
## When gusted it flashes white, gets knocked along the gust, slows down, then
## drifts back to where it was placed. A hit counter is drawn under it.
##
## @tool so the box is visible while placing it in the editor.

## Placeholder look: a hollow light-violet box (not in the §2 color key on purpose,
## so it's never mistaken for a real object). Flashes white when hit.
const BOX_COLOR: Color = Color(0.8, 0.7, 1.0)
const FLASH_COLOR: Color = Color(1, 1, 1)
const HALF_SIZE: float = 4.0
## How fast the knock-back slows down, px/s², and how fast it drifts home, px/s.
const KNOCK_DECELERATION: float = 400.0
const RETURN_SPEED: float = 20.0
## How long the white flash lasts, seconds.
const FLASH_TIME: float = 0.12

## Where it was placed; it always drifts back here.
var home_position: Vector2
## Current knock-back speed, px/s.
var knock_velocity: Vector2 = Vector2.ZERO
var flash_remaining: float = 0.0
var hit_count: int = 0


func _ready() -> void:
	collision_layer = 8  # bit value of layer 4, "pushable"
	collision_mask = 0   # it doesn't need to detect anything itself
	var square: RectangleShape2D = RectangleShape2D.new()
	square.size = Vector2.ONE * HALF_SIZE * 2.0
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = square
	add_child(hitbox)
	if Engine.is_editor_hint():
		return
	home_position = position
	# Step 1 of the Pushable contract.
	add_to_group(Pushable.GROUP)


## Step 2 of the Pushable contract: called by GustAbility for every gust that hits us.
func receive_gust(direction: Vector2, strength: float) -> void:
	knock_velocity = direction * strength
	flash_remaining = FLASH_TIME
	hit_count += 1


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	flash_remaining = maxf(flash_remaining - delta, 0.0)
	if knock_velocity != Vector2.ZERO:
		position += knock_velocity * delta
		knock_velocity = knock_velocity.move_toward(Vector2.ZERO, KNOCK_DECELERATION * delta)
	else:
		position = position.move_toward(home_position, RETURN_SPEED * delta)
	queue_redraw()


func _draw() -> void:
	var is_flashing: bool = flash_remaining > 0.0
	var color: Color = FLASH_COLOR if is_flashing else BOX_COLOR
	var box: Rect2 = Rect2(-Vector2.ONE * HALF_SIZE, Vector2.ONE * HALF_SIZE * 2.0)
	if is_flashing:
		draw_rect(box, color)  # solid white flash
	else:
		draw_rect(box, color, false, 1.0)  # hollow outline, 1 px
	if hit_count > 0:
		# Default font, 6 px: just enough to read "3" under the box.
		draw_string(ThemeDB.fallback_font, Vector2(-HALF_SIZE, HALF_SIZE + 7.0), str(hit_count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, color)

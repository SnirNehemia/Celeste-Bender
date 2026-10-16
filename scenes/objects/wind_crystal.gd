@tool
class_name WindCrystal
extends Area2D
## Wind crystal (GAME_DESIGN.md §5.1, §6): a floating green diamond that refills the
## player's dash on touch, then respawns after a short delay.
##
## Place the node where the CENTER of the diamond should be. Everything (shape,
## hitbox) is built in code in _ready(), so wind_crystal.tscn is a single node.
##
## It talks to the player only through AirDashAbility.refill(): if the player
## already has a full dash, refill() returns false and the crystal is NOT used up
## (same as Celeste), so you can't waste a crystal by brushing past it.
##
## Area2D on physics layer 3 ("hazards"/triggers), looking at layer 2 ("player").
## @tool so the diamond is visible while placing it in the editor.

## Green, per the color key (GAME_DESIGN.md §2). Dimmed outline while respawning.
const CRYSTAL_COLOR: Color = Color(0.3, 0.95, 0.5)
const RESPAWNING_COLOR: Color = Color(0.3, 0.95, 0.5, 0.25)
## Half the diamond's width/height, px.
const HALF_SIZE: float = 5.0
## Gentle up-down float: amplitude in px and speed in cycles per second.
const BOB_AMPLITUDE: float = 1.5
const BOB_FREQUENCY: float = 0.8

## Seconds before a used crystal comes back.
@export var respawn_time: float = 2.5

## True while the crystal is available to touch.
var is_available: bool = true
## Seconds since start, drives the bob animation.
var bob_time: float = 0.0

var diamond: Polygon2D


func _ready() -> void:
	collision_layer = 4  # bit value of layer 3
	collision_mask = 2   # bit value of layer 2, "player"

	diamond = Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -HALF_SIZE), Vector2(HALF_SIZE, 0), Vector2(0, HALF_SIZE), Vector2(-HALF_SIZE, 0)])
	diamond.color = CRYSTAL_COLOR
	add_child(diamond)

	# The hitbox is a little bigger than the drawing: pickups should be generous.
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = HALF_SIZE + 2.0
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	hitbox.shape = circle
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	bob_time += delta
	# Only the drawing bobs; the hitbox stays put so touching it is predictable.
	diamond.position.y = roundf(sin(bob_time * TAU * BOB_FREQUENCY) * BOB_AMPLITUDE)

	if Engine.is_editor_hint() or not is_available:
		return
	# Checked every frame (not just on body_entered) so that a player who is ALREADY
	# inside the crystal when they spend their dash gets refilled right away.
	for body: Node2D in get_overlapping_bodies():
		var touched_player: Player = body as Player
		if touched_player != null and not touched_player.is_dead() \
				and touched_player.air_dash.refill():
			_use_up()
			return


## Hide (dimmed outline), wait respawn_time, then come back.
func _use_up() -> void:
	is_available = false
	diamond.color = RESPAWNING_COLOR
	FX.shake(1.0, 0.08)
	# create_timer() makes a one-shot timer; `await` pauses this function (not the game)
	# until it fires. Uses game time, so it also pauses during freeze frames.
	await get_tree().create_timer(respawn_time, false).timeout
	is_available = true
	diamond.color = CRYSTAL_COLOR
	# Quick pop so the player notices it's back.
	diamond.scale = Vector2(1.6, 1.6)
	var pop_tween: Tween = create_tween()
	pop_tween.tween_property(diamond, "scale", Vector2.ONE, 0.15)

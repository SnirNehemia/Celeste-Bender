@tool
class_name WindCrystal
extends Area2D
## Wind crystal (GAME_DESIGN.md §5.1, §6): a floating green diamond that refills the
## player's dash on touch, then respawns after a short delay.
##
## Place the node where the CENTER of the diamond should be. Everything (shape,
## hitbox) is built in code in _ready(), so wind_crystal.tscn is a single node.
##
## It talks to the player only through Player.refill_from_crystal(), which refills
## the dash (or breath) AND the gust charge. If nothing needed refilling it
## returns false and the crystal is NOT used up (same as Celeste), so you can't
## waste a crystal by brushing past it.
##
## Used crystals come back after respawn_time, or at once when the room resets
## (death or R): the crystal joins Room.RESETTABLE_GROUP and has a reset() method.
##
## Area2D on physics layer 3 ("hazards"/triggers), looking at layer 2 ("player").
## @tool so the diamond is visible while placing it in the editor.
##
## Other pickups reuse this script by INHERITING from it (`extends WindCrystal`):
## GustDiamond (gust_diamond.gd) changes the colors and sound in _init() and
## overrides _give_to(), and gets the bobbing, respawn and reset for free.
## FireDiamond (fire/fire_diamond.gd) does the same, and turns off `respawns`.

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

## Look and sound. Plain vars (not consts) so a subclass can change them in _init().
var ready_color: Color = CRYSTAL_COLOR
var respawning_color: Color = RESPAWNING_COLOR
var pickup_sound: StringName = &"crystal"
## False = single use: once used it stays gone until the room resets (death or R),
## instead of coming back after respawn_time. FireDiamond sets it in _init().
var respawns: bool = true

## True while the crystal is available to touch.
var is_available: bool = true
## Seconds since start, drives the bob animation.
var bob_time: float = 0.0
## Goes up on every use and every reset. A respawn timer remembers the value from
## when it started and does nothing if it changed, so a timer left over from before
## a room reset can't "pop" the crystal a second time.
var use_count: int = 0

var diamond: Polygon2D


func _ready() -> void:
	collision_layer = 4  # bit value of layer 3
	collision_mask = 2   # bit value of layer 2, "player"
	# Groups are named tags on nodes; Room.reset_objects() calls reset() on every
	# node in this group inside its room.
	add_to_group(Room.RESETTABLE_GROUP)

	diamond = Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -HALF_SIZE), Vector2(HALF_SIZE, 0), Vector2(0, HALF_SIZE), Vector2(-HALF_SIZE, 0)])
	diamond.color = ready_color
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
				and _give_to(touched_player):
			_use_up()
			return


## What touching does. Returns true if it helped (only then is the crystal used up).
## Subclasses override this: GDScript calls the subclass's version when there is one.
func _give_to(touched_player: Player) -> bool:
	return touched_player.refill_from_crystal()


## Hide (dimmed outline), wait respawn_time, then come back.
func _use_up() -> void:
	is_available = false
	use_count += 1
	var this_use: int = use_count
	diamond.color = respawning_color
	FX.shake(1.0, 0.08)
	FX.play_sfx(pickup_sound)
	if not respawns:
		return  # single use: only reset() brings it back
	# create_timer() makes a one-shot timer; `await` pauses this function (not the game)
	# until it fires. Uses game time, so it also pauses during freeze frames.
	await get_tree().create_timer(respawn_time, false).timeout
	if this_use != use_count:
		return  # a room reset (or a newer use) happened meanwhile: not our timer anymore
	_come_back()
	# Quick pop so the player notices it's back.
	diamond.scale = Vector2(1.6, 1.6)
	var pop_tween: Tween = create_tween()
	pop_tween.tween_property(diamond, "scale", Vector2.ONE, 0.15)


## Available again, full color.
func _come_back() -> void:
	is_available = true
	diamond.color = ready_color


## Called by Room.reset_objects() when the player dies or restarts the room:
## back at once (no pop), and use_count cancels any pending respawn timer.
func reset() -> void:
	use_count += 1
	_come_back()

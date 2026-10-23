class_name RockSpot
extends Node2D
## RockSpot (Stage L8): where a level wants a LOOSE rock lying from the start
## (Earth_bending.md §11 "Loose rocks", Stage E4c3). Loose rocks are made in play,
## by tearing earth and not throwing the rock: there's no rock in a room scene to
## place. So a level places a spot, and the spot makes the rock:
##   - when the room starts (the level loads), and
##   - after every reset (death or R), when Room.reset_objects() has cleared the
##     room's rocks (Boulder.reset frees them): the rock is back where it was put.
## The rock is a plain Boulder (scenes/objects/earth/boulder.gd), set up as if it
## had just been torn out of the ground under it and then settled: everything a
## loose rock does (lift with S, shatter with a tap, fall, the 3-per-room cap) is
## the Boulder's own code.
##
## Two scenes use this script: loose_rock_spot.tscn (a small 8 px rock) and
## boulder_spot.tscn (a big 16 px rock, `is_big`). The palette shows them as
## "Loose rock" and "Boulder" (PaletteCatalog, Earth tab).
##
## Place the node at the rock's CENTER. The rock is added to the spot's room (the
## spot's parent), like rocks torn there in play, because loose rocks count their
## siblings for the per-room cap.
##
## In the level editor the level is shown with processing switched off
## (LevelEditor: PROCESS_MODE_DISABLED); there the spot makes no rock and draws a
## rock-shaped placeholder instead, so you see what you placed.
## Contracts: Room.RESETTABLE_GROUP + reset().

## Brown-yellow like fresh earth (EarthLayer.FRESH_COLOR), see-through: a placeholder.
const EDITOR_FILL: Color = Color(0.74, 0.57, 0.27, 0.8)
const EDITOR_OUTLINE: Color = Color(0.33, 0.22, 0.13)

## A big rock (EarthTuning.big_rock_size, 16 px) instead of a small one (8 px).
@export var is_big: bool = false

## The same EarthTuning resource the player and the rocks use (preload returns
## the shared copy).
var earth_tuning: EarthTuning = preload("res://resources/earth_tuning.tres")
## The rock this spot made last (freed by a reset or a shatter), or null.
var rock: Boulder = null


func _ready() -> void:
	add_to_group(Room.RESETTABLE_GROUP)
	# Deferred: the room is still being built (its other children may not be in
	# the tree yet), and adding a sibling during that is refused.
	_make_rock.call_deferred()


## Called by Room.reset_objects() (death or R). The old rock is being freed by its
## own reset() in the same pass, so the new one comes a moment later (deferred):
## made now, it would count the old one as a loose rock and could crumble it.
func reset() -> void:
	_make_rock.call_deferred()


## The rock's size in pixels.
func get_rock_size() -> float:
	return earth_tuning.big_rock_size if is_big else earth_tuning.boulder_size


func _make_rock() -> void:
	if not is_inside_tree():
		return  # left the tree before this deferred call ran (the editor's copy during a play-test)
	# The level editor shows levels without running them (see the header).
	if not can_process():
		queue_redraw()
		return
	if rock != null and is_instance_valid(rock) and not rock.is_queued_for_deletion():
		return  # still lying there: one rock per spot
	rock = Boulder.new()
	# As if torn out of the ground right here, popping straight up, with no
	# player around for the hop (the hop never happens: it settles at once).
	rock.setup(global_position, Vector2.UP, 0.0, global_position.y, earth_tuning)
	rock.size = get_rock_size()
	get_parent().add_child(rock)
	rock._settle()  # LOOSE from the start, like a rock that came down unthrown
	queue_redraw()  # the placeholder goes: the rock draws itself now


## In the editor only: an eight-cornered rock outline the rock's size.
func _draw() -> void:
	if can_process():
		return
	var half: float = get_rock_size() / 2.0
	var cut: float = half * 0.4  # corners cut off: reads as a stone, not a crate
	var corners: PackedVector2Array = PackedVector2Array([
		Vector2(-half + cut, -half), Vector2(half - cut, -half), Vector2(half, -half + cut), Vector2(half, half - cut),
		Vector2(half - cut, half), Vector2(-half + cut, half), Vector2(-half, half - cut), Vector2(-half, -half + cut)])
	draw_colored_polygon(corners, EDITOR_FILL)
	corners.append(corners[0])
	draw_polyline(corners, EDITOR_OUTLINE, 1.0)

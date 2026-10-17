class_name Pushable
extends RefCounted
## The "Pushable" contract: how any object says "a gust can push me".
##
## GDScript has no interfaces (like Python's abstract base classes). The Godot way
## is DUCK TYPING plus a GROUP:
##   1. Put the object in the group "pushable". A group is a named tag any node can
##      carry; add_to_group(Pushable.GROUP) in _ready(), or Node dock > Groups in the editor.
##   2. Give it this method:
##        func receive_gust(direction: Vector2, strength: float) -> void
##      `direction` is the unit vector the gust blows toward; `strength` is
##      tuning.gust_push_strength (px/s). The object decides what that means:
##      a crate slides, a windmill spins, an enemy gets stunned, an orb reflects.
##   3. Its collision object (Area2D or any body) must be on a physics layer other
##      than "player" (layer 4, "pushable", is reserved for this), so the gust's
##      shape query can find it.
##
## GustAbility only ever calls Pushable.try_push(), so it never needs to know what
## kind of object it hit. New pushable things (Stage 7 crates, Stage 8 enemies) just
## follow the three steps above; no change to the gust code.
##
## This class is never instantiated: it only holds the group name and static helpers
## (a static func is called on the class itself, like Pushable.try_push(...)).

## The group every pushable object joins.
const GROUP: StringName = &"pushable"
## The method every pushable object implements.
const METHOD: StringName = &"receive_gust"


## Returns the pushable node for something the gust touched, or null.
## Checks the node itself, then its parent: a pushable object's hitbox is often a
## child (e.g. an enemy's separate Hurtbox Area2D), so either may carry the group.
static func find_pushable(touched: Node) -> Node:
	for candidate: Node in [touched, touched.get_parent()]:
		if candidate != null and candidate.is_in_group(GROUP) and candidate.has_method(METHOD):
			return candidate
	return null


## Pushes `target` if it is pushable. Returns true if it was.
static func try_push(touched: Node, direction: Vector2, strength: float) -> bool:
	var target: Node = find_pushable(touched)
	if target == null:
		return false
	# call() invokes a method by name: this is the duck-typing part.
	target.call(METHOD, direction, strength)
	return true

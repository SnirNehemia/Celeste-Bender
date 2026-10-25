class_name ElementImmunity
extends Resource
## ElementImmunity (Stage F11, Fire_bending.md §7.2): one enemy's table of "what does
## each kind of hit do to me". Every enemy holds one, and its receive_hit() (the
## EnemyHit contract, enemy_hit.gd) starts by looking the hit up here. That's the
## "each element gets an enemy only it can kill" rule written as data: the wisp's
## table says fire kills, the vine monkey's says only fire kills, the Shell's (F12)
## will say only a big rock kills.
##
## The table only says WHICH reaction; HOW the enemy reacts is its own code (a
## killed wisp pops, a killed monkey becomes a living torch first; a pushed wisp is
## stunned, a pushed monkey is blown further because it's light).
##
## Godot concept, Resource: a data object that can be saved as a .tres file and
## edited in the Inspector (like PlayerTuning). Each enemy builds its default table in
## code (see Wisp._make_immunity()), and its `immunity` export lets you swap in a
## saved one for a single enemy without touching the script.

## What a hit does. Ordered from mildest to worst.
enum Response {
	IGNORE,   ## nothing (a rock clonking off a sentry, spikes under a monkey)
	PUSH,     ## moved and stunned (a gust, a column, a sloppy rock on a wisp)
	STAGGER,  ## stops for a moment and is knocked back a little (the Shell, F12)
	KILL,     ## defeated, in the enemy's own way
	REFLECT,  ## bounces off it unharmed (Stage F12: fireballs and orbs off the Shell).
	          ## Last, so the values above keep their numbers in saved tables.
}

@export_group("Fire")
@export var fireball: Response = Response.IGNORE
@export var flame: Response = Response.IGNORE
@export_group("Earth")
@export var big_rock: Response = Response.IGNORE
@export var perfect_rock: Response = Response.IGNORE
@export var small_rock: Response = Response.IGNORE
@export var earth_push: Response = Response.IGNORE
@export var crush: Response = Response.IGNORE
@export_group("Air")
@export var gust: Response = Response.IGNORE
@export var reflected_orb: Response = Response.IGNORE
@export_group("Creatures")
@export var whip: Response = Response.IGNORE
@export_group("Hazards")
@export var spikes: Response = Response.IGNORE


## A table from {EnemyHit.Type: Response}; types left out are IGNORE.
static func from_table(responses: Dictionary) -> ElementImmunity:
	var immunity: ElementImmunity = ElementImmunity.new()
	for hit_type: EnemyHit.Type in responses:
		immunity.set_response(hit_type, responses[hit_type])
	return immunity


## The table's answer for one hit type.
func get_response(hit_type: EnemyHit.Type) -> Response:
	var value: Variant = get(_get_property_name(hit_type))
	if value == null:
		push_error("[ElementImmunity] no table entry for hit type %s" % EnemyHit.Type.keys()[hit_type])
		return Response.IGNORE
	return value as Response


func set_response(hit_type: EnemyHit.Type, response: Response) -> void:
	set(_get_property_name(hit_type), response)


## The exported variable that holds a hit type's answer: the enum name in lower case
## (FIREBALL -> "fireball"), so the two lists can't drift apart silently: a type with
## no variable is reported by get_response().
static func _get_property_name(hit_type: EnemyHit.Type) -> StringName:
	return StringName((EnemyHit.Type.keys()[hit_type] as String).to_lower())

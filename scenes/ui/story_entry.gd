class_name StoryEntry
extends Resource
## StoryEntry: one level of Story Mode (Level_editor.md §9): the title shown in the
## Story screen and the world scene it plays. The scene can be an editor level
## (res://levels/<slug>.tscn) or a chapter world (scenes/world.tscn,
## scenes/earth_world.tscn...). StoryList holds them in order.
##
## Godot concept, Resource: a data object that can be saved to a .tres file and
## edited in the Inspector, like a dataclass that knows how to serialize itself.
## @export marks the fields that are saved.

## The title shown in the Story screen and on the level-complete card.
@export var title: String = ""
## The world scene the entry plays. Progress is keyed by this path
## (StoryProgress), so renaming or reordering an entry keeps it.
@export_file("*.tscn") var scene_path: String = ""


## A new entry. Arguments are optional because Godot makes Resources with no
## arguments when it loads them from a file.
func _init(new_title: String = "", new_scene_path: String = "") -> void:
	title = new_title
	scene_path = new_scene_path

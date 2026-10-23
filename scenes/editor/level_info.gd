class_name LevelInfo
extends Node
## LevelInfo: the level editor's notes about one level (Level_editor.md §3).
##
## Every editor level is a world scene (RoomManager root, Room children, Player,
## camera, UI) with one extra child: this node, always named "LevelInfo". It holds
## what the game itself doesn't need but the editor and Story Mode do: the level's
## title, which room it starts in, and free notes.
##
## It's a plain Node (no position, nothing drawn): just data that lives inside the
## level scene, so it's saved in the same file as the rooms.
## LevelStorage reads `level_title` straight from the saved file for the level list.

## The node's name inside a level scene. LevelStorage and the editor look it up by this.
const NODE_NAME: StringName = &"LevelInfo"

## Shown in the level library and, later, in Story Mode.
@export var level_title: String = ""
## The room the Player starts in. The level template puts the Player at this
## room's SpawnPoint; the map view (Stage L7) will let you move the start.
## An exported node reference is saved in the scene as a path to that node.
@export var start_room: Room
## Free notes about the level (ideas, what's left to do). Not shown in play.
@export_multiline var notes: String = ""

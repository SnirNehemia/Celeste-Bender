class_name CrackedWallLayer
extends WallLayer
## The room's "CrackedWalls" layer: cracked walls painted as terrain. Each connected
## group of cells is one CrackedWall (see WallLayer).

const WALL_SCENE: PackedScene = preload("res://scenes/objects/earth/cracked_wall.tscn")


func get_wall_scene() -> PackedScene:
	return WALL_SCENE

class_name StoneWallLayer
extends WallLayer
## The room's "StoneWalls" layer: stone walls painted as terrain. Each connected
## group of cells is one StoneWall (see WallLayer).

const WALL_SCENE: PackedScene = preload("res://scenes/objects/stone_wall.tscn")


func get_wall_scene() -> PackedScene:
	return WALL_SCENE

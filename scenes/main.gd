extends Node2D
## Main scene script — the root of the game for now.
##
## This is the scene Godot loads on startup (set as "run/main_scene" in project.godot).
## Right now it only holds a gray floor (child node "Floor"). In later stages the
## player and the room system get instanced under this node.
##
## Nothing to do yet; the script exists so later stages have a place to hook in
## (e.g. loading the first room), and so you can see how a script attaches to a node.


func _ready() -> void:
	# _ready() runs once, when this node and all its children have entered the scene tree.
	# Kept empty on purpose for Stage 0.
	pass

class_name FireTuning
extends Resource
## Every number that affects how FIRE bending feels lives here (Fire_bending.md).
## The Fire twin of PlayerTuning and EarthTuning: the player holds one
## (resources/fire_tuning.tres) in its `fire_tuning` field, and the fire code reads
## it fresh every time, so Remote-tab edits while the game runs take effect at once.
##
## Stages add their own export groups as they need them (Fire_bending.md §11):
## F1 only needs the bar itself.

@export_group("Fire bar")
## Most pips the bar can hold (Fire_bending.md §4.1). Pips gained above this are lost.
## The HUD draws this many slots, so changing it changes the row's width too.
@export_range(1, 10) var max_pips: int = 5

class_name PaintedPatchSettings
extends RefCounted
## PaintedPatchSettings: what the property panel shows for a patch of PAINTED tiles
## picked with the Select tool (a patch isn't a node, so it can't be selected like an
## object). LevelEditor keeps the one picked in `selected_patch`, shows it in the
## PropertyPanel (its settings are ordinary properties, read with get_property_list)
## and the overlay outlines it. Each kind of patch is a class of its own:
##   - CrumblePatchSettings:      a crumbling or falling patch's crumble time
##   - HiddenChamberSettings:     a hidden chamber's cover look (what its fake wall is drawn as)
## They override the functions below.


## Still there (an undo or an erase may have taken it away)?
func is_valid() -> bool:
	return false


## The panel's title.
func get_title() -> String:
	return ""


## The settings the panel shows.
func get_panel_properties() -> Array[StringName]:
	return []


## The panel's text under the settings.
func get_panel_hint() -> String:
	return ""


## The patch's outline in world px, as polylines (the overlay draws them).
func get_world_loops() -> Array[PackedVector2Array]:
	return []

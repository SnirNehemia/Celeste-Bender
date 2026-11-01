extends BackdropTheme
## SANCTUM, SURFACE: the courtyards at the foot of the air monastery. Under the
## soft underside of the cloud sea: the holy mountain's lower terraces with stupas
## and waterfalls, faint floating platforms, low hills along the horizon, the
## monastery's white tower and dzong walls coming down out of the clouds to a
## gallery of prayer wheels, sunbeams, nearer ledges, and right in front a
## prayer-flag pole on its cairn and broad leaves; petals drift, birds fly.
## Every layer is shared with the skyline (SanctumStyle.add_shared_layers), so
## climbing between the two is one picture scrolling on. See BackdropTheme.


func _build_layers() -> void:
	SanctumStyle.add_shared_layers(self, SURFACE_SECTION)

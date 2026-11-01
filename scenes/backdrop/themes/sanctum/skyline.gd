extends BackdropTheme
## SANCTUM, SKYLINE: up on the air monastery, above the clouds. The holy mountain's
## plateau with its air towers, the cloud sea spread below, floating islands with
## stupas and little towers, the monastery's tall tower and the dzong's red band,
## gilded roof and corner towers, prayer flags strung from spire to spire, and
## right in front the flag pole with its flags across the sky; birds and petals.
## Every layer is shared with the surface (SanctumStyle.add_shared_layers), so
## climbing between the two is one picture scrolling on. See BackdropTheme.


func _build_layers() -> void:
	SanctumStyle.add_shared_layers(self, SKYLINE_SECTION)

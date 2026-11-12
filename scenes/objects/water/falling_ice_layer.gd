class_name FallingIceLayer
extends FallingBlockLayer
## FallingIceLayer: FALLING BLOCKS OF ICE painted into a level (asked for with the
## crumbling-ice play-test: "a falling block of ice, darker ice"). A TileMapLayer
## named "FallingIce", painted from the editor's Terrain tab like a falling block
## (the placeholder tileset, hidden: the layer draws its own look).
##
## Everything a falling block does, it does (FallingBlockLayer: the touch, the shake
## and the contour, the drop as one solid FallingBlock, crushing, splashing, landing
## as tiles, the reset). What's different:
##   - it's ICE: the layer (and each FallingBlock while it falls, which checks its
##     layer's group) is in IceLayer.ICE_GROUP, so you slide on it and keep speed,
##     and its walls have no grip;
##   - its LOOK is darker ice: PatchPainter.DARK_ICE_PALETTE with the COLUMNS grain
##     (the joints read as stacked blocks of ice), pale ice dust, a white contour.
## It's a subclass that only overrides FallingBlockLayer's "Kinds" hooks.
##
## Godot concept, a subclass script (`extends FallingBlockLayer`): this node runs all
## of its parent class's code; functions defined again here REPLACE the parent's (and
## the parent's own code calls these when it calls get_palette() etc.).

const ICE_NODE_NAME: StringName = &"FallingIce"
const ICE_DUST_COLOR: Color = Color(0.7, 0.85, 0.95)
const ICE_CONTOUR_COLOR: Color = Color(1.0, 1.0, 1.0)


func _ready() -> void:
	add_to_group(IceLayer.ICE_GROUP)  # slippery (Player.is_ice, IceSlope)
	super()


func get_layer_name() -> StringName:
	return ICE_NODE_NAME


func get_palette() -> Array[Color]:
	return PatchPainter.DARK_ICE_PALETTE


func get_grain() -> PatchPainter.Grain:
	return PatchPainter.Grain.COLUMNS


func get_dust_color() -> Color:
	return ICE_DUST_COLOR


func get_contour_color() -> Color:
	return ICE_CONTOUR_COLOR

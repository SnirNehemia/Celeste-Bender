class_name NonSolidLayer
extends TileMapLayer
## NonSolidLayer: the base of painted terrain layers that are NOT ground: nothing
## stands on them, nothing is stopped by them, and the code that gathers a room's
## solid tiles skips them (`is NonSolidLayer`: the WaterWorld, FireGrid, earth,
## grass, ice and crumbling layers, the editor's spike and solid-cell checks,
## LevelKit). Their tilesets have no collision.
##   - StormCloudLayer: a deadly cloud things pass through
##   - ClueLayer:       painted decorations that hint at hidden chambers or a way
## (Water and hidden chambers aren't solid either, but each has its own rules.)

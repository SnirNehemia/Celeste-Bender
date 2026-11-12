class_name CrumbleDrips
extends RefCounted
## CrumbleDrips: the specks that trickle from the underside of a crumbling patch while
## its countdown runs: grit from crumbling rock (CrumbleRockLayer), water drops from
## crumbling ice (CrumbleIceLayer). A look only: the specks touch nothing.
##
## It isn't a node: a layer owns one, calls advance() from its _physics_process (it
## reads the layer's CrumblePatches to know which patches are crumbling), and draw()
## from its look node's drawing. reset() clears it on a room reset.
## Positions are in the layer's local px.

## Specks per second per crumbling patch.
var per_second: float = 14.0
## How fast they fall, px/s², and how long they last, s.
var gravity: float = 300.0
var lifetime: float = 0.5
## Their color (alpha fades out over the last half of their life).
var color: Color = Color.WHITE

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var lives: PackedFloat32Array = PackedFloat32Array()


func _init(speck_color: Color, specks_per_second: float, fall_gravity: float, speck_lifetime: float) -> void:
	color = speck_color
	per_second = specks_per_second
	gravity = fall_gravity
	lifetime = speck_lifetime


func is_empty() -> bool:
	return lives.is_empty()


## One frame: each crumbling patch of `crumble` may drop a speck from a random cell of
## it with open air below (no tile of `layer` under it); the specks fall and fade.
func advance(layer: TileMapLayer, crumble: CrumblePatches, delta: float) -> void:
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	for patch: Dictionary in crumble.patches:
		if float(patch[&"crack_left"]) < 0.0 or randf() > per_second * delta:
			continue
		var cells: Array[Vector2i] = patch[&"cells"]
		var cell: Vector2i = cells[randi() % cells.size()]
		if layer.get_cell_source_id(cell + Vector2i.DOWN) != -1:
			continue  # more of the patch under it: no speck from here this time
		positions.append(Vector2(cell) * tile_px + Vector2(randf_range(1.0, tile_px.x - 1.0), tile_px.y))
		velocities.append(Vector2(0.0, randf_range(5.0, 20.0)))
		lives.append(lifetime)
	for index: int in range(lives.size() - 1, -1, -1):
		lives[index] -= delta
		if lives[index] <= 0.0:
			positions.remove_at(index)
			velocities.remove_at(index)
			lives.remove_at(index)
			continue
		velocities[index] += Vector2(0.0, gravity * delta)
		positions[index] += velocities[index] * delta


func draw(canvas: CanvasItem) -> void:
	for index: int in positions.size():
		var speck_color: Color = color
		speck_color.a *= clampf(lives[index] / lifetime * 2.0, 0.0, 1.0)
		canvas.draw_rect(Rect2(positions[index].floor(), Vector2.ONE), speck_color)


func reset() -> void:
	positions.clear()
	velocities.clear()
	lives.clear()

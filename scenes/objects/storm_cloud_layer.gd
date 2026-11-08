class_name StormCloudLayer
extends TileMapLayer
## StormCloudLayer: STORM CLOUD painted into a level, a deadly area that only stops
## the player (asked for after the W8c play-test: "a deadly obstacle that objects can
## pass through"). A TileMapLayer named "StormCloud", painted from the editor's Terrain
## tab with resources/tiles/storm_cloud_tileset.tres: one see-through slate tile with
## NO collision, so crates, rocks, fireballs, water, enemies and gusts all pass
## through. Touching it kills YOU: lightning crackles inside it.
##
## Why a cloud (and not poison gas)? It's the air bender's world: a thundercloud
## reads as "soft, things go through it" and its lightning as "but it zaps you", and
## its slate-violet doesn't clash with the green of grass and thicket.
##
## The kill (_physics_process, only in the room you're in): the player's hitbox,
## shrunk by KILL_INSET px on each side (fair, like spikes: grazing the fluffy edge is
## safe), is checked against the painted cells. A hit calls Player.die(), which
## respects the play-test's invincibility cheat.
##
## Not solid ANYWHERE: the room's WaterWorld, FireGrid, earth, grass, ice and crumbling
## layers skip it when they collect the room's solid tiles (they check
## `is StormCloudLayer`, like they skip WaterLayer and HiddenLayer); the editor map
## and RoomEdgeRim only count layers with collision, which it has none of.
##
## THE LOOK: the tiles draw the cloud's body. A child node (CloudLook) adds the fluff
## round its open edges (half-disc bumps, lit on top and shaded underneath), lighter
## wisps drifting across, and every so often a bolt of lightning in a random cell.
## It animates in the level editor too, so the hazard reads while you build.

## Shrinks the player's hitbox before the check, px per side: grazing is safe.
const KILL_INSET: float = 1.5
## The cloud's body color (the tile's), and the lit / shaded fluff on top and below.
const BODY_COLOR: Color = Color8(62, 56, 86, 170)
const TOP_FLUFF_COLOR: Color = Color8(96, 90, 128, 190)
const BOTTOM_FLUFF_COLOR: Color = Color8(40, 36, 58, 190)
## Wisps: lighter streaks drifting across each cell, px/s.
const WISP_COLOR: Color = Color(0.75, 0.72, 0.9, 0.25)
const WISP_SPEED: float = 3.0
const WISP_LENGTH: float = 3.0
## Fluff bumps: two half-discs per open tile edge, this radius, px.
const FLUFF_RADIUS: float = 2.0
const FLUFF_SEGMENTS: int = 6
## Lightning: a bolt every FLASH_MIN_GAP..FLASH_MAX_GAP s, lit for FLASH_TIME s.
const BOLT_COLOR: Color = Color(0.95, 0.92, 1.0, 1.0)
const FLASH_GLOW_COLOR: Color = Color(0.85, 0.8, 1.0, 0.3)
const FLASH_MIN_GAP: float = 0.3
const FLASH_MAX_GAP: float = 0.9
const FLASH_TIME: float = 0.09

## The painted cells, cached (rebuilt when the tiles change).
var cells: Array[Vector2i] = []
## The fluff's half-disc polygons, layer-local px: [polygon, color] pairs.
var fluff: Array[Array] = []
var look_node: Node2D
var wisp_time: float = 0.0
var flash_left: float = 0.0
var next_flash_in: float = FLASH_MIN_GAP
## The cell lit by the current bolt, and the bolt's zigzag (layer-local px).
var bolt_cell: Vector2i = Vector2i.ZERO
var bolt_points: PackedVector2Array = PackedVector2Array()
var is_rebuild_queued: bool = false


func _ready() -> void:
	look_node = Node2D.new()
	look_node.name = "CloudLook"
	look_node.draw.connect(_draw_look)
	add_child(look_node)
	# `changed` fires when the tiles change (the editor paints or erases).
	changed.connect(_queue_rebuild)
	_rebuild()


## The level editor, after a stroke or an undo: the cells may have changed
## (TileMapLayer's `changed` signal doesn't fire for every cell edit).
func rebuild_look() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if is_rebuild_queued:
		return
	is_rebuild_queued = true
	_rebuild.call_deferred()


## Caches the cells and works out the fluff round the open edges.
func _rebuild() -> void:
	is_rebuild_queued = false
	cells = get_used_cells()
	fluff.clear()
	var tile_px: float = float(tile_set.tile_size.x)
	for cell: Vector2i in cells:
		var corner: Vector2 = Vector2(cell) * tile_px
		# Each open side: [outward direction, the side's start corner, its color].
		for side: Array in [[Vector2i.UP, corner, TOP_FLUFF_COLOR],
				[Vector2i.DOWN, corner + Vector2(0.0, tile_px), BOTTOM_FLUFF_COLOR],
				[Vector2i.LEFT, corner, BODY_COLOR],
				[Vector2i.RIGHT, corner + Vector2(tile_px, 0.0), BODY_COLOR]]:
			var outward: Vector2i = side[0]
			if get_cell_source_id(cell + outward) != -1:
				continue  # more cloud there: no edge
			# Along the side: right for top/bottom, down for left/right.
			var along: Vector2 = Vector2.RIGHT if outward.y != 0 else Vector2.DOWN
			for bump_index: int in 2:
				var center: Vector2 = (side[1] as Vector2) + along * (FLUFF_RADIUS + bump_index * 2.0 * FLUFF_RADIUS)
				fluff.append([_half_disc(center, Vector2(outward)), side[2]])
	look_node.queue_redraw()


## A half-disc of FLUFF_RADIUS on `center`, bulging toward `outward`.
static func _half_disc(center: Vector2, outward: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var start_angle: float = outward.angle() - PI / 2.0
	for step: int in FLUFF_SEGMENTS + 1:
		var angle: float = start_angle + PI * step / FLUFF_SEGMENTS
		points.append(center + Vector2.from_angle(angle) * FLUFF_RADIUS)
	return points


func _process(delta: float) -> void:
	if cells.is_empty():
		return
	wisp_time += delta
	flash_left -= delta
	next_flash_in -= delta
	if next_flash_in <= 0.0:
		next_flash_in = randf_range(FLASH_MIN_GAP, FLASH_MAX_GAP)
		_start_bolt()
	look_node.queue_redraw()  # the wisps drift every frame


## Picks a random cell and draws a zigzag bolt down through it.
func _start_bolt() -> void:
	bolt_cell = cells[randi() % cells.size()]
	var tile_px: float = float(tile_set.tile_size.x)
	var top: Vector2 = Vector2(bolt_cell) * tile_px + Vector2(randf_range(2.0, tile_px - 2.0), 1.0)
	bolt_points = PackedVector2Array([top])
	for step: int in 3:
		var last: Vector2 = bolt_points[bolt_points.size() - 1]
		bolt_points.append(last + Vector2(randf_range(-2.0, 2.0), (tile_px - 2.0) / 3.0))
	flash_left = FLASH_TIME


func _physics_process(_delta: float) -> void:
	# Only the room you're in can kill (in the level editor that's never).
	if cells.is_empty() or GameState.current_room != get_parent():
		return
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.is_dead():
		return
	if touches_cloud(player.get_hitbox_rect().grow(-KILL_INSET)):
		player.die()


## Does `global_box` overlap any painted cell? (The player check; tests use it too.)
func touches_cloud(global_box: Rect2) -> bool:
	var local_box: Rect2 = Rect2(to_local(global_box.position), global_box.size)
	var first: Vector2i = local_to_map(local_box.position)
	# Just inside the far edge: a box ending exactly on a tile line doesn't reach the next tile.
	var last: Vector2i = local_to_map(local_box.end - Vector2(0.01, 0.01))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			if get_cell_source_id(Vector2i(x, y)) != -1:
				return true
	return false


# --- The look ------------------------------------------------------------------------

func _draw_look() -> void:
	for bump: Array in fluff:
		look_node.draw_colored_polygon(bump[0], bump[1])
	var tile_px: float = float(tile_set.tile_size.x)
	for cell: Vector2i in cells:
		# A streak per cell, its row and start from a hash of the cell (it never jumps),
		# drifting right and wrapping inside the cell.
		var hash_value: int = absi(cell.x * 73856093 ^ cell.y * 19349663)
		var row: float = 1.0 + hash_value % 6
		var start_x: float = fposmod(float(hash_value % 8) + wisp_time * WISP_SPEED, tile_px)
		var end_x: float = minf(start_x + WISP_LENGTH, tile_px)
		var corner: Vector2 = Vector2(cell) * tile_px
		look_node.draw_line(corner + Vector2(start_x, row), corner + Vector2(end_x, row), WISP_COLOR, 1.0)
	if flash_left > 0.0 and bolt_points.size() > 1:
		look_node.draw_rect(Rect2(Vector2(bolt_cell) * tile_px, Vector2.ONE * tile_px).grow(1.0), FLASH_GLOW_COLOR)
		look_node.draw_polyline(bolt_points, BOLT_COLOR, 1.0)

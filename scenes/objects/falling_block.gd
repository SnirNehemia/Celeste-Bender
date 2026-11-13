class_name FallingBlock
extends AnimatableBody2D
## FallingBlock: one dropped patch of painted FALLING BLOCK (FallingBlockLayer) on its
## way down, a solid body (after the W8c play-test: "the falling ones should remain
## solid and fall straight down, splashing water, killing the player, and breaking
## crates on the way down").
##
## Made by FallingBlockLayer when a patch lets go, as a child of the layer: its
## collision is one square per cell, in the layer's coordinates, and it moves only
## down (position.y = how far it has fallen). It draws the block's picture
## (PatchPainter's, painted by the layer: FallingBlockLayer.draw_picture).
##
## Each physics frame (its room is kept awake while it falls: MOVING_GROUP):
##   1. it speeds up by falling_block_gravity, up to falling_block_max_speed
##      (WaterTuning: a crate's numbers, so a crate on it keeps up);
##   2. CRUSH: what's right under its bottom edges, this frame's step deep, is hit:
##      you die, crates break (Crate.smash), enemies get a CRUSH hit (EnemyHit). An
##      enemy that survives it (a Shell) stops the block like ground;
##   3. it casts its bottom squares down (cast_motion) against the world (layer 1),
##      leaving out you, crates and crushed enemies, and moves as far as it can;
##   4. the props it carries (braziers, fire diamonds: GroundProps) move with it;
##      you and crates ride it by themselves (an AnimatableBody2D carries what
##      stands on it);
##   5. its bottom crossing a pool's surface pushes the water down there (a splash);
##   6. stopped short = LANDED: on the tile grid it hands its cells to the layer
##      (FallingBlockLayer.land) and goes; off the grid (on a platform) it stays here,
##      resting, and falls on if its support goes. Landing also starts any crumbling
##      or falling patch right under it (touch_at_world);
##   7. its middle crossing into ANOTHER room (falling out of the bottom of its own)
##      hands it over (_hand_over): it moves into that room's falling-block layer
##      (made if the room has none), so it lands as that room's tiles, splashes that
##      room's water and is reset with it. Before (play-test), it stopped dead where
##      it crossed: it only fell while you were in the room it was painted in.
##
## Godot concept, AnimatableBody2D: a solid body moved by code (not by forces) that
## pushes and carries CharacterBody2Ds, like a moving platform. sync_to_physics moves
## it in step with the physics, so what stands on it rides smoothly.

const WATER_TUNING: WaterTuning = preload("res://resources/water_tuning.tres")
## Squares are this much narrower than a tile on each side, px, so a block falling
## past a wall (or past the crate beside it) doesn't catch on it.
const SIDE_SLACK: float = 0.5
## Landing within this many px of the tile grid snaps onto it (and becomes tiles).
const GRID_SNAP: float = 3.0
## Landing, it creeps the last px down in steps this small, px.
const CREEP_STEP: float = 0.25
## A resting block (off the grid) looks this far down for its support, px.
const SUPPORT_PROBE: float = 1.0
## Its landing: a shake (strength, seconds) and dust per bottom tile.
const LAND_SHAKE: float = 2.0
const LAND_SHAKE_TIME: float = 0.15
const LAND_DUST_PER_TILE: int = 2
## Pushing the water when it enters it: this share of its speed, px/s.
const SPLASH_SHARE: float = 0.6
## Blocks on their way down (not resting, not landed) are in this group: RoomManager
## keeps their room awake until they land, even when you're far from it, so a block
## you left behind (or rode out of its room) doesn't freeze mid-air.
const MOVING_GROUP: StringName = &"falling_blocks_moving"

var layer: FallingBlockLayer
## Its cells where it was when it let go (the layer's map coords), and its picture
## (PatchPainter's [texture, origin in the layer's px]).
var cells: Array[Vector2i] = []
var picture: Array = []
## The cells with no cell of the block below them: what it lands on and crushes with.
var bottom_cells: Array[Vector2i] = []
var props: Array[Node2D] = []
var fall_speed: float = 0.0
## How far it has fallen, px: its position.y. Kept here because an AnimatableBody2D
## with sync_to_physics reads back last frame's position until the physics catches up.
var fallen: float = 0.0
## How far right of its cells' grid it is, px: 0, unless it was handed to a room
## placed off the tile grid (the map's half-tile steps). Then it can't land as tiles
## and rests as a body instead. Its position is (x_offset, fallen).
var x_offset: float = 0.0
var is_resting: bool = false
## One square, shared by the casts (cast_motion asks for a shape).
var probe_shape: RectangleShape2D = RectangleShape2D.new()


## Starts `block_cells` of `owner_layer` falling, carrying `carried_props`.
static func spawn(owner_layer: FallingBlockLayer, block_cells: Array[Vector2i],
		block_picture: Array, carried_props: Array[Node2D]) -> FallingBlock:
	var block: FallingBlock = FallingBlock.new()
	block.name = "FallingBlock"
	block.layer = owner_layer
	block.cells = block_cells
	block.picture = block_picture
	block.props = carried_props
	owner_layer.add_child(block)
	return block


func _ready() -> void:
	collision_layer = 1  # "world": you stand on it, things land on it
	collision_mask = 0   # moved by code; it asks the world itself (the casts)
	sync_to_physics = true
	add_to_group(WaterWorld.SOLID_GROUP)  # loose water bumps into it; it touches patches
	add_to_group(MOVING_GROUP)
	# A block of falling ice is ice while it falls too: you slide on it.
	if layer.is_in_group(IceLayer.ICE_GROUP):
		add_to_group(IceLayer.ICE_GROUP)
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	probe_shape.size = Vector2(tile_px.x - 2.0 * SIDE_SLACK, tile_px.y)
	for cell: Vector2i in cells:
		var square: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = tile_px
		square.shape = shape
		square.position = Vector2(cell) * tile_px + tile_px / 2.0
		add_child(square)
		if not cells.has(cell + Vector2i.DOWN):
			bottom_cells.append(cell)


func _physics_process(delta: float) -> void:
	if is_resting:
		# Off the grid on a platform: falls on once nothing holds it.
		if _cast_down(SUPPORT_PROBE, []) < 1.0:
			return
		is_resting = false
		add_to_group(MOVING_GROUP)
	fall_speed = minf(fall_speed + WATER_TUNING.falling_block_gravity * delta, WATER_TUNING.falling_block_max_speed)
	var step: float = fall_speed * delta
	var passed: Array[RID] = _crush_below(step)
	var share: float = _cast_down(step, passed)
	var moved: float = step * share
	if share < 1.0:
		# cast_motion's "safe" share is careful (it can stop a few px short at full
		# speed): creep the rest of the way down in small steps.
		var crept: float = 0.0
		while crept < step and _cast_down(moved + crept + CREEP_STEP, passed) >= 1.0:
			crept += CREEP_STEP
		moved += crept
	var bottom_before: float = _get_bottom_y()
	fallen += moved
	position = Vector2(x_offset, fallen)
	for prop: Node2D in props:
		if is_instance_valid(prop):
			prop.global_position.y += moved
	_splash(bottom_before, _get_bottom_y())
	if share < 1.0:
		_land(passed)
	else:
		_hand_over_if_crossed()


## Its middle is in another room now (it fell out of its own): it goes to that room;
## in no room at all (out of the level), it's gone. Rooms are the level's children
## (RoomManager); their boxes don't overlap.
func _hand_over_if_crossed() -> void:
	var own_room: Node = layer.get_parent()
	var middle: Vector2 = get_water_box().get_center()
	if (own_room as Room).get_bounds().has_point(middle):
		return
	for sibling: Node in own_room.get_parent().get_children():
		var room: Room = sibling as Room
		if room != null and room != own_room and room.get_bounds().has_point(middle):
			_hand_over(layer.ensure_twin_in(room))
			return
	# No room there: it fell out of the level (a pit). Gone until the reset, which
	# paints its tiles back (it would otherwise fall, and keep its room awake, forever).
	remove_from_group(MOVING_GROUP)
	remove_from_group(WaterWorld.SOLID_GROUP)
	set_physics_process(false)
	queue_free()


## Moves this block into `new_layer` (another room's), keeping it exactly where it is
## on screen: its cells and picture are shifted to that layer's grid by whole tiles,
## what's left over goes into `fallen` (and x_offset if the rooms aren't lined up on
## the grid). reparent() keeps the node (and its _ready work, its squares); it just
## changes its parent.
func _hand_over(new_layer: FallingBlockLayer) -> void:
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	# Where the block's origin (its cell grid's 0,0) is, in the new layer's px.
	var origin: Vector2 = new_layer.to_local(layer.to_global(Vector2(x_offset, fallen)))
	var shift: Vector2i = Vector2i(roundi(origin.x / tile_px.x), floori(origin.y / tile_px.y))
	x_offset = origin.x - shift.x * tile_px.x
	if absf(x_offset) < 0.01:
		x_offset = 0.0
	fallen = origin.y - shift.y * tile_px.y
	for index: int in cells.size():
		cells[index] += shift
	for index: int in bottom_cells.size():
		bottom_cells[index] += shift
	picture = [picture[0], picture[1] + Vector2(shift) * tile_px]
	for child: Node in get_children():
		var square: CollisionShape2D = child as CollisionShape2D
		if square != null:
			square.position += Vector2(shift) * tile_px
	layer = new_layer
	reparent(new_layer, false)
	position = Vector2(x_offset, fallen)
	queue_redraw()



## Everything under the bottom cells within `step` px: you die, crates break,
## enemies are crushed. Returns what the cast may pass through now (their bodies).
func _crush_below(step: float) -> Array[RID]:
	var passed: Array[RID] = [get_rid()]
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var sweep: RectangleShape2D = RectangleShape2D.new()
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	sweep.size = Vector2(tile_px.x - 2.0 * SIDE_SLACK, step + 1.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = sweep
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = false
	for cell: Vector2i in bottom_cells:
		# A thin box just under the cell's bottom edge, this step deep.
		var bottom_middle: Vector2 = _to_world(Vector2(cell) * tile_px + Vector2(tile_px.x / 2.0, tile_px.y))
		query.transform = Transform2D(0.0, bottom_middle + Vector2(0.0, sweep.size.y / 2.0))
		query.exclude = passed
		for hit: Dictionary in space.intersect_shape(query, 16):
			var collider: Object = hit["collider"]
			var rid: RID = hit["rid"]
			if collider is Player:
				var player: Player = collider as Player
				if not player.is_dead():
					player.die()
				passed.append(rid)
			elif collider is Crate:
				(collider as Crate).smash()
				passed.append(rid)
			elif EnemyHit.is_enemy(collider):
				var response: ElementImmunity.Response = EnemyHit.send(collider, EnemyHit.Type.CRUSH,
					Vector2(0.0, fall_speed), self)
				if response == ElementImmunity.Response.KILL:
					passed.append(rid)
	return passed


## How much of a `distance` px move down the bottom cells can make (0..1) before
## touching the world (layer 1), passing through `passed`.
func _cast_down(distance: float, passed: Array[RID]) -> float:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = probe_shape
	query.collision_mask = 1
	query.collide_with_areas = false
	query.motion = Vector2(0.0, distance)
	var excluded: Array[RID] = passed.duplicate()
	excluded.append(get_rid())
	# You and crates never hold it up: it goes through what it didn't crush (you,
	# riding on top, aren't under it anyway).
	for member: Node in get_tree().get_nodes_in_group(Player.GROUP):
		if member is CollisionObject2D:
			excluded.append((member as CollisionObject2D).get_rid())
	query.exclude = excluded
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	var share: float = 1.0
	for cell: Vector2i in bottom_cells:
		query.transform = Transform2D(0.0, _to_world(Vector2(cell) * tile_px + tile_px / 2.0))
		var result: PackedFloat32Array = space.cast_motion(query)
		share = minf(share, result[0])
	return share


## Would the block, moved down to `offset_y` (its position.y), overlap nothing solid
## (layer 1, but `passed` and you)? Each square is shrunk a little: touching is fine.
func _fits_at(offset_y: float, passed: Array[RID]) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	var square: RectangleShape2D = RectangleShape2D.new()
	square.size = tile_px - Vector2.ONE * 2.0 * SIDE_SLACK
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = square
	query.collision_mask = 1
	query.collide_with_areas = false
	var excluded: Array[RID] = passed.duplicate()
	excluded.append(get_rid())
	query.exclude = excluded
	var layer_origin: Vector2 = layer.global_position + Vector2(x_offset, 0.0)
	for cell: Vector2i in cells:
		query.transform = Transform2D(0.0, layer_origin + Vector2(cell) * tile_px + tile_px / 2.0 + Vector2(0.0, offset_y))
		for hit: Dictionary in space.intersect_shape(query, 4):
			if not hit["collider"] is CharacterBody2D:
				return false
	return true


## A point in the block's own coordinates (the layer's px, before falling) in the
## world, where the block is NOW (see `fallen`).
func _to_world(local_point: Vector2) -> Vector2:
	return layer.to_global(local_point + Vector2(x_offset, fallen))


## The lowest bottom edge, global y.
func _get_bottom_y() -> float:
	var lowest: int = cells[0].y
	for cell: Vector2i in bottom_cells:
		lowest = maxi(lowest, cell.y)
	return _to_world(Vector2(0.0, (lowest + 1) * layer.tile_set.tile_size.y)).y


## Its bottom went from `before_y` to `after_y` (global): crossing a pool's surface
## pushes the water down there (waves and spray, the WaterWorld's own splash).
func _splash(before_y: float, after_y: float) -> void:
	var world: WaterWorld = layer.get_parent().get_node_or_null(NodePath(WaterWorld.NODE_NAME)) as WaterWorld
	if world == null or not world.is_node_ready():
		return
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	for cell: Vector2i in bottom_cells:
		var bottom_middle: Vector2 = _to_world(Vector2(cell) * tile_px + Vector2(tile_px.x / 2.0, tile_px.y))
		var surface_y: float = world.get_surface_y_at(world.to_local(Vector2(bottom_middle.x, after_y)))
		if is_nan(surface_y):
			continue
		var surface_global: float = world.to_global(Vector2(0.0, surface_y)).y
		if before_y < surface_global and after_y >= surface_global:
			world.push_at(Vector2(bottom_middle.x, surface_global), Vector2(0.0, fall_speed * SPLASH_SHARE), tile_px.x)


## Stopped short: a thump, the crumbling or falling ground under it starts, and on the
## grid it becomes the layer's tiles again; off the grid it rests here.
func _land(passed: Array[RID]) -> void:
	var tile_height: float = float(layer.tile_set.tile_size.y)
	# The nearest grid row, if it's within GRID_SNAP and the block fits there (the
	# casts stop a little short; a platform off the grid doesn't let it in).
	var to_grid: float = roundf(fallen / tile_height) * tile_height - fallen
	# Off the grid sideways (handed to a room not lined up on it): it can't be tiles.
	var is_on_grid: bool = x_offset == 0.0 and absf(to_grid) <= GRID_SNAP and _fits_at(fallen + to_grid, passed)
	if is_on_grid:
		fallen += to_grid
		position = Vector2(x_offset, fallen)
		for prop: Node2D in props:
			if is_instance_valid(prop):
				prop.global_position.y += to_grid
	FX.shake(LAND_SHAKE, LAND_SHAKE_TIME)
	FX.play_sfx(&"boulder_land")
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	# Dust along the whole bottom, in one burst.
	var box: Rect2 = get_water_box()
	CrumblePatches.burst(layer, layer.to_local(Vector2(box.get_center().x, box.end.y)), layer.get_dust_color(),
		mini(bottom_cells.size() * LAND_DUST_PER_TILE, CrumblePatches.MAX_BURST_PIECES), Vector2(box.size.x, 2.0))
	for cell: Vector2i in bottom_cells:
		var bottom_middle: Vector2 = _to_world(Vector2(cell) * tile_px + Vector2(tile_px.x / 2.0, tile_px.y))
		for sibling: Node in layer.get_parent().get_children():
			if sibling.has_method(&"touch_at_world"):
				sibling.call(&"touch_at_world", bottom_middle + Vector2(0.0, GRID_SNAP + 1.0))
	fall_speed = 0.0
	remove_from_group(MOVING_GROUP)
	if not is_on_grid:
		is_resting = true  # on a platform, off the grid: stays a body
		return
	var rows_fallen: int = roundi(fallen / tile_height)
	var landed: Array[Vector2i] = []
	for cell: Vector2i in cells:
		landed.append(cell + Vector2i(0, rows_fallen))
	# The same picture, moved down the rows it fell: the block looks the same landed.
	var landed_picture: Array = [picture[0], picture[1] + Vector2(0.0, rows_fallen * tile_height)]
	layer.land(landed, landed_picture)
	# The tiles take its place now: it stops being solid and goes at the frame's end.
	collision_layer = 0
	visible = false
	set_physics_process(false)
	remove_from_group(WaterWorld.SOLID_GROUP)
	queue_free()


## What it touches, for crumbling and falling patches (CrumblePatches): one global box
## per cell. Not get_water_box()'s one box round them all: a block shaped like an L
## would "touch" a patch sitting in its corner as it moved, and start it.
func get_touch_boxes() -> Array[Rect2]:
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	var boxes: Array[Rect2] = []
	for cell: Vector2i in cells:
		boxes.append(Rect2(_to_world(Vector2(cell) * tile_px), tile_px))
	return boxes


## The box loose water bumps into (WaterWorld.SOLID_GROUP), global: round all its cells.
func get_water_box() -> Rect2:
	var tile_px: Vector2 = Vector2(layer.tile_set.tile_size)
	var box: Rect2 = Rect2(Vector2(cells[0]) * tile_px, tile_px)
	for cell: Vector2i in cells:
		box = box.merge(Rect2(Vector2(cell) * tile_px, tile_px))
	return Rect2(_to_world(box.position), box.size)


func _draw() -> void:
	FallingBlockLayer.draw_picture(self, picture)

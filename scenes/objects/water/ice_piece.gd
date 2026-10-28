class_name IcePiece
extends StaticBody2D
## IcePiece (Stage W5, Water_bending.md §7): ice that STAYS where it froze. Two kinds:
##   - a PILLAR: a snake frozen in your hands while its foot is still in its pool
##     (and the ball at its head). It keeps the exact shape the snake was drawn with
##     (IceOutline over the hands' dots) and stands in the pool.
##   - a SHEET: a stretch of pool frozen by the crystal. Its top is the water's
##     surface as it was (frozen waves and all), its bottom ice_sheet_thickness lower
##     (or the pool's floor, where the water was shallower: frozen through). The
##     WaterWorld took the water above the sheet's bottom and gave the columns under
##     it the sheet's bottom as their ceiling (so you can't surface through it, and a
##     column frozen to its floor dams the flow); this node remembers each column's
##     old ceiling and frozen water, to give them back when it melts
##     (WaterWorld._unfreeze_sheet).
## (Free ice, which flies on with its momentum, is IceBlock.)
## SLIDES (Stage W6): a pillar lying flatter than slide_pillar_angle (a snake laid
## along a pin bed and frozen) is a SLIDE, one-way for the player (IceBlock.SLIDE_GROUP:
## you stand on it from above, jump up through it). Steeper pillars and sheets are solid.
##
## A child of the room at the room's origin, so its local coordinates are the room's
## (the WaterWorld's). Its collision is its outline split into convex parts. Drawn by
## IceLook (glass with icicles) through the shared ice material. The WaterWorld made
## it, owns it (player_ice: the ice cap), frees it on reset, and melts it through
## WaterWorld.melt_ice(), which gives its water back exactly: a pillar rains down into
## its pool and refills it, a sheet sinks back.
##
## Physics layer 1 ("world"): the player, crates and enemies stand on it, rocks and
## orbs stop on it. Groups: "ice" (the player slides on it), water_solid (loose water
## bumps off it: get_water_boxes()), flammable (fire melts it: ignite()).

## The water frozen in it, px² (read by WaterWorld.melt_ice).
var water_area: float = 0.0
var world: WaterWorld
var is_sheet: bool = false
## Its outline (room-local) and the same split into convex parts.
var outlines: Array[PackedVector2Array] = []
var parts: Array[PackedVector2Array] = []
var look: IceLook
## A sheet: the box around it (room-local), and per frozen column its x, its old
## ceiling and the water it froze, px².
var sheet_rect: Rect2 = Rect2()
var sheet_xs: PackedFloat32Array = PackedFloat32Array()
var sheet_old_ceilings: PackedFloat32Array = PackedFloat32Array()
var sheet_areas: PackedFloat32Array = PackedFloat32Array()
## Each convex part's box (global), for loose water: worked out once (it never moves).
var water_boxes: Array[Rect2] = []
## A slide (Stage W6): see the header.
var is_slide: bool = false


## A pillar with the outlines `room_outlines` (room-local), holding `area` px² of
## water, added to `owner_world`'s room.
static func make_pillar(owner_world: WaterWorld, room_outlines: Array[PackedVector2Array], area: float) -> IcePiece:
	var piece: IcePiece = IcePiece.new()
	piece.name = "IcePillar"
	piece.world = owner_world
	piece.water_area = area
	piece.outlines = room_outlines
	owner_world.room.add_child(piece)
	return piece


## A frozen stretch of pool: its outline `outline` (room-local), and what each of its
## columns froze (see the header), `area` px² in all, added to `owner_world`'s room.
static func make_sheet(owner_world: WaterWorld, outline: PackedVector2Array, xs: PackedFloat32Array,
		old_ceilings: PackedFloat32Array, frozen_areas: PackedFloat32Array, area: float) -> IcePiece:
	var piece: IcePiece = IcePiece.new()
	piece.name = "IceSheet"
	piece.world = owner_world
	piece.water_area = area
	piece.is_sheet = true
	piece.outlines = [outline]
	piece.sheet_rect = IceOutline.bounds(piece.outlines)
	piece.sheet_xs = xs
	piece.sheet_old_ceilings = old_ceilings
	piece.sheet_areas = frozen_areas
	owner_world.room.add_child(piece)
	return piece


func _ready() -> void:
	collision_layer = 1  # "world": solid like rock
	collision_mask = 0
	z_index = 2  # over the water's surface line
	add_to_group(IceBlock.ICE_GROUP)
	add_to_group(WaterWorld.SOLID_GROUP)
	add_to_group(Flammable.GROUP)
	parts = IceOutline.convex_parts(outlines)
	for part: PackedVector2Array in parts:
		var shape: CollisionPolygon2D = CollisionPolygon2D.new()
		shape.polygon = part
		add_child(shape)
		var box: Rect2 = IceOutline.bounds([part])
		water_boxes.append(Rect2(to_global(box.position), box.size))
	look = IceLook.build(outlines, true)
	material = IceLook.get_material()
	is_slide = not is_sheet and IceOutline.lying_angle_degrees(outlines) < world.water_tuning.slide_pillar_angle
	if is_slide:
		add_to_group(IceBlock.SLIDE_GROUP)


## The top of the ice at `global_x` (global y), or INF where there's none (one-way
## slides: Player._update_one_way_slides).
func get_slide_top_y(global_x: float) -> float:
	var top: float = IceOutline.top_y_at(outlines, to_local(Vector2(global_x, 0.0)).x)
	return to_global(Vector2(0.0, top)).y if top < INF else INF


## The box around it (global).
func get_slide_bounds() -> Rect2:
	return get_bounds()


## Loose water bumps off each part's box (WaterWorld._collect_solid_boxes).
func get_water_boxes() -> Array[Rect2]:
	return water_boxes


## Not a single box (see get_water_boxes); size 0 means "skip me" to code that only
## knows get_water_box() (the hands' shove).
func get_water_box() -> Rect2:
	return Rect2()


## Everything this ice covers (global): what the fire's helpers test against.
func get_bounds() -> Rect2:
	if water_boxes.is_empty():
		return Rect2(global_position, Vector2.ZERO)
	var bounds: Rect2 = water_boxes[0]
	for box: Rect2 in water_boxes:
		bounds = bounds.merge(box)
	return bounds


# --- The Flammable contract: fire MELTS ice (it doesn't burn) -------------------------

func ignite(_source: Node) -> void:
	if is_instance_valid(world):
		world.melt_ice(self)


func is_burning() -> bool:
	return false


func snuff() -> void:
	pass


func get_fire_rect() -> Rect2:
	return get_bounds()


func _draw() -> void:
	if look != null:
		look.draw(self)

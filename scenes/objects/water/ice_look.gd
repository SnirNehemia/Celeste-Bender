class_name IceLook
extends RefCounted
## IceLook (Stage W5, look A + icicles, picked after the first W5 play-test): how
## every piece of ice is drawn, so painted ice, the player's grid ice (each connected
## patch of tiles traced into one outline: IceLayer, PlayerIceLayer) and rafts all
## look like the same GLASS. An outline is drawn as:
##   - a see-through pale blue BODY (the background, or the pool under a sheet, shows
##     through a little)
##   - a darker UNDERSIDE band along its lower edges and a light TOP band along its
##     upper edges: the outline shifted down/up and cut away (Geometry2D.clip_polygons),
##     so any shape gets them, round or long
##   - a 1 px light RIM all round, and a small white SHINE near its upper left
##   - ICICLES hanging from its downward-facing edges over open air (not from a
##     raft)
##   - a GLINT that slides along as the player moves (ice.gdshader, one shared
##     material: update_glint is called once a frame by the room's WaterWorld)
## The geometry is worked out once (build) and drawn from the cache (draw): ice nodes
## call draw() from their _draw(), in their own local coordinates.

const ICE_SHADER: Shader = preload("res://scenes/objects/water/ice.gdshader")
## Water_bending.md §12.1's ice family: pale cyan body, deeper underside, white top.
## See-through (after the grid-ice play-test: the body was 0.8 opaque, now 0.55; the
## glint in ice.gdshader still needs the body at 0.5 or more).
const BODY_COLOR: Color = Color(0.62, 0.86, 0.97, 0.55)
const UNDERSIDE_COLOR: Color = Color(0.22, 0.5, 0.74, 0.65)
const TOP_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)
## The specular highlight: a small white streak near the upper left of each body.
const SHINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const RIM_COLOR: Color = Color(0.92, 0.98, 1.0, 1.0)
## Bands: how far the outline is shifted to cut them, px.
const UNDERSIDE_DEPTH: float = 4.0
const TOP_DEPTH: float = 2.0
## Icicles: one every this many px along a downward edge, this long (px, the hash
## of its position picks a length in between), this wide at the root.
const ICICLE_SPACING: float = 7.0
const ICICLE_MIN_LENGTH: float = 2.0
const ICICLE_MAX_LENGTH: float = 6.0
const ICICLE_WIDTH: float = 2.5
## An edge faces down enough to hang icicles when its outward normal's y is at least this.
const ICICLE_MIN_FACING: float = 0.75

## The one material all ice shares (its glint follows the player).
static var shared_material: ShaderMaterial = null

## What build() worked out for one piece of ice: draw() only reads these.
var bodies: Array[PackedVector2Array] = []
var undersides: Array[PackedVector2Array] = []
var tops: Array[PackedVector2Array] = []
var icicles: Array[PackedVector2Array] = []
## Where each body's shine streak starts (one per body big enough for one).
var shines: PackedVector2Array = PackedVector2Array()


## The material every ice node uses (made on first use).
static func get_material() -> ShaderMaterial:
	if shared_material == null:
		shared_material = ShaderMaterial.new()
		shared_material.shader = ICE_SHADER
	return shared_material


## The glint slides with the player: called once a frame with the player's x.
static func update_glint(player_x: float) -> void:
	get_material().set_shader_parameter(&"glint_offset", player_x * 0.5)


## Works out the look of ice with these outlines (local coordinates). `with_icicles`:
## long shapes and sheets have them, compact blocks don't. `icicle_allowed` (optional,
## a Callable taking an icicle's root point, local, returning bool) leaves out the
## icicles it says no to: painted ice hangs them only over open air.
static func build(outlines: Array[PackedVector2Array], with_icicles: bool,
		icicle_allowed: Callable = Callable()) -> IceLook:
	var look: IceLook = IceLook.new()
	look.bodies = outlines
	for outline: PackedVector2Array in outlines:
		# The part of the outline NOT covered by a copy shifted up = its lower edge band.
		look.undersides.append_array(Geometry2D.clip_polygons(outline, _shifted(outline, Vector2(0.0, -UNDERSIDE_DEPTH))))
		look.tops.append_array(Geometry2D.clip_polygons(outline, _shifted(outline, Vector2(0.0, TOP_DEPTH))))
		if with_icicles:
			for icicle: PackedVector2Array in _make_icicles(outline):
				if not icicle_allowed.is_valid() or icicle_allowed.call((icicle[0] + icicle[1]) / 2.0):
					look.icicles.append(icicle)
		# The shine: a quarter of the way in from the top-left of its box, if that's
		# inside the ice and the ice is big enough to carry it.
		var box: Rect2 = IceOutline.bounds([outline])
		var shine: Vector2 = (box.position + box.size * Vector2(0.28, 0.25)).round()
		if box.size.x >= 8.0 and box.size.y >= 8.0 and Geometry2D.is_point_in_polygon(shine, outline) 				and Geometry2D.is_point_in_polygon(shine + Vector2(2.0, -1.0), outline):
			look.shines.append(shine)
	return look


func draw(canvas: CanvasItem) -> void:
	for body: PackedVector2Array in bodies:
		canvas.draw_colored_polygon(body, BODY_COLOR)
	for band: PackedVector2Array in undersides:
		if band.size() >= 3:
			canvas.draw_colored_polygon(band, UNDERSIDE_COLOR)
	for band: PackedVector2Array in tops:
		if band.size() >= 3:
			canvas.draw_colored_polygon(band, TOP_COLOR)
	for icicle: PackedVector2Array in icicles:
		canvas.draw_colored_polygon(icicle, BODY_COLOR)
		canvas.draw_line(icicle[0], icicle[2], RIM_COLOR, 1.0)
	for shine: Vector2 in shines:
		canvas.draw_rect(Rect2(shine, Vector2(2.0, 1.0)), SHINE_COLOR)
		canvas.draw_rect(Rect2(shine + Vector2(2.0, -1.0), Vector2(1.0, 1.0)), SHINE_COLOR)
		canvas.draw_rect(Rect2(shine + Vector2(-1.0, 2.0), Vector2(1.0, 1.0)), Color(SHINE_COLOR, 0.6))
	for body: PackedVector2Array in bodies:
		var closed: PackedVector2Array = body.duplicate()
		closed.append(body[0])
		canvas.draw_polyline(closed, RIM_COLOR, 1.0)


static func _shifted(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon:
		result.append(point + offset)
	return result


## Icicles under the edges of `outline` that face down: thin triangles every
## ICICLE_SPACING px, their lengths from a hash of their position (the same ice
## always grows the same icicles).
static func _make_icicles(outline: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	# Which side is "outside" depends on the loop's winding.
	var outward_sign: float = -1.0 if IceOutline.polygon_area(outline) > 0.0 else 1.0
	var carried: float = 0.0
	for index: int in outline.size():
		var from: Vector2 = outline[index]
		var to: Vector2 = outline[(index + 1) % outline.size()]
		var edge: Vector2 = to - from
		var length: float = edge.length()
		if length < 0.001:
			continue
		# (-e.y, e.x) points INTO a loop with positive (shoelace) area in y-down
		# coordinates (try the square (0,0) (1,0) (1,1) (0,1)): flipped, it's outside.
		var outward: Vector2 = Vector2(-edge.y, edge.x).normalized() * outward_sign
		if outward.y < ICICLE_MIN_FACING:
			carried = 0.0
			continue
		var along: float = ICICLE_SPACING - carried
		while along < length:
			var root: Vector2 = from + edge * (along / length)
			var hash_value: float = fposmod(sin(root.x * 12.9898 + root.y * 78.233) * 43758.5453, 1.0)
			var icicle_length: float = lerpf(ICICLE_MIN_LENGTH, ICICLE_MAX_LENGTH, hash_value)
			var half: float = ICICLE_WIDTH / 2.0
			result.append(PackedVector2Array([root + Vector2(-half, -0.5), root + Vector2(half, -0.5),
				root + Vector2(0.0, icicle_length)]))
			along += ICICLE_SPACING
		carried = length - (along - ICICLE_SPACING)
	return result

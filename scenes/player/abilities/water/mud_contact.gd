class_name MudContact
extends Node
## Mud component (Stage W8a, Water_bending.md §9.1). Lives as a child of the Player:
##   Player > MudContact
##
## Responsibilities (and only these): knowing whether the player TOUCHES MUD (wet
## earth or wet ash, the room's SurfaceGrid) and turning that into the numbers the
## movement uses. Like SwimAbility it isn't a bending move: mud is sticky in any room.
##
##   - is_on_mud: standing on mud this frame (any of three points under the feet).
##     Runs are slower (get_speed_multiplier) and jumps lower (get_jump_multiplier).
##   - on_landed(): landing on mud kills the sideways speed at once: the brake at the
##     end of an ice runway. Player calls it on every landing.
##   - is_mud_wall(side): a mud wall beside you on `side`. WallSlide CLINGS there
##     while you hold toward it: no sliding (mud_cling_brake stops you fast) and no
##     climbing. Wall jumps still work. leave_hand_print() marks where you hold on.
##   - is_on_coat (Stage W8b): standing on a wet tile under an ICY COAT. Player
##     counts that as ice (is_on_ice): slippery, keeps speed. A coat isn't mud.
##
## It owns no movement: Player.apply_horizontal_movement(), start_ground_jump(), the
## landing check and WallSlide read it. All values are in WaterTuning ("Mud" group).

## How far under the feet the floor is probed, px.
const FOOT_PROBE_DEPTH: float = 1.0
## How far past the hitbox's side a wall is probed, px.
const WALL_PROBE_DISTANCE: float = 1.5

var player: Player
## Standing on mud this frame (set by update_contact).
var is_on_mud: bool = false
## Standing on an icy coat this frame (set by update_contact).
var is_on_coat: bool = false


func _ready() -> void:
	player = get_parent() as Player


## Reads the ground under the player. Player._update_timers() calls it every
## physics frame, right after the swim check.
func update_contact() -> void:
	is_on_mud = player.is_on_floor() and is_mud_under_feet()
	is_on_coat = player.is_on_floor() and is_coat_under_feet()


## Is any of three points just under the feet (the two corners and the middle) mud?
func is_mud_under_feet() -> bool:
	var hitbox: Rect2 = player.get_hitbox_rect()
	var grid: SurfaceGrid = SurfaceGrid.find_at(player.get_tree(), hitbox.get_center())
	if grid == null or grid.get_wet_count() == 0:
		return false
	var probe_y: float = hitbox.end.y + FOOT_PROBE_DEPTH
	for probe_x: float in [hitbox.position.x + 1.0, hitbox.get_center().x, hitbox.end.x - 1.0]:
		if grid.is_mud_at(Vector2(probe_x, probe_y)):
			return true
	return false


## Is any of the same three points an icy coat (Stage W8b)?
func is_coat_under_feet() -> bool:
	var hitbox: Rect2 = player.get_hitbox_rect()
	var grid: SurfaceGrid = SurfaceGrid.find_at(player.get_tree(), hitbox.get_center())
	if grid == null or grid.get_coated_count() == 0:
		return false
	var probe_y: float = hitbox.end.y + FOOT_PROBE_DEPTH
	for probe_x: float in [hitbox.position.x + 1.0, hitbox.get_center().x, hitbox.end.x - 1.0]:
		if grid.is_coated_at(Vector2(probe_x, probe_y)):
			return true
	return false


## Is the wall right beside the player on `side` (-1 left, +1 right) mud? Probed at
## the hitbox's middle and near its feet.
func is_mud_wall(side: float) -> bool:
	return _is_wall_like(side, false)


## Is the wall beside the player on `side` under an icy coat (Stage W8b)? Then it's
## an ice wall: no grip, a faster slide (Player.get_wall_slide_max_speed).
func is_coat_wall(side: float) -> bool:
	return _is_wall_like(side, true)


## The wall probe shared by is_mud_wall and is_coat_wall: the hitbox's middle and near
## its feet, just past its side. `coated`: look for a coat instead of mud.
func _is_wall_like(side: float, coated: bool) -> bool:
	if side == 0.0:
		return false
	var hitbox: Rect2 = player.get_hitbox_rect()
	var grid: SurfaceGrid = SurfaceGrid.find_at(player.get_tree(), hitbox.get_center())
	if grid == null or (grid.get_coated_count() if coated else grid.get_wet_count()) == 0:
		return false
	var probe_x: float = (hitbox.end.x if side > 0.0 else hitbox.position.x) + side * WALL_PROBE_DISTANCE
	for probe_y: float in [hitbox.get_center().y, hitbox.end.y - 2.0]:
		var probe: Vector2 = Vector2(probe_x, probe_y)
		if grid.is_coated_at(probe) if coated else grid.is_mud_at(probe):
			return true
	return false


## A hand print on the mud wall on `side`, at the hands' height.
func leave_hand_print(side: float) -> void:
	var hitbox: Rect2 = player.get_hitbox_rect()
	var grid: SurfaceGrid = SurfaceGrid.find_at(player.get_tree(), hitbox.get_center())
	if grid != null:
		var wall_x: float = (hitbox.end.x if side > 0.0 else hitbox.position.x) + side * 1.0
		grid.add_hand_print(Vector2(wall_x, hitbox.position.y + 3.0))


## Run speed multiplier: mud_run_multiplier on mud, 1 elsewhere.
func get_speed_multiplier() -> float:
	return player.water_tuning.mud_run_multiplier if is_on_mud else 1.0


## Jump multiplier for a jump off the ground: mud_jump_multiplier on mud, 1 elsewhere.
func get_jump_multiplier() -> float:
	return player.water_tuning.mud_jump_multiplier if is_on_mud else 1.0


## The player just landed: on mud, the sideways speed goes (mud_landing_speed_keep of
## it is kept, 0 by default). Returns true if it was mud.
func on_landed() -> bool:
	if not is_mud_under_feet():
		return false
	is_on_mud = true
	player.velocity.x *= player.water_tuning.mud_landing_speed_keep
	player.carries_ice_speed = false
	return true

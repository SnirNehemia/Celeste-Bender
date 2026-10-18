@tool
class_name EnemyGate
extends Switch
## EnemyGate: a switch that turns ON once every enemy linked to it is defeated.
## Wire a Door to it (Door.switches) to make a "beat them all to get out" exit,
## like room 5's sentry pass.
##
## It never looks at enemies every frame. Each enemy (Wisp, Sentry) emits a
## `defeated` signal; the gate connects to it in _ready() and counts. When the
## count reaches the number of linked enemies, it calls set_on(true), and the
## door hears that through the `switched` signal it inherits from Switch.
##
## Place the node where you want its indicator: a row of small squares, one per
## linked enemy, purple while that enemy is alive and green once it's beaten.
## Above the door it opens reads well. In the editor, dashed lines go to each
## linked enemy (like a door's lines to its switches).
##
## Reset: it joins Room.RESETTABLE_GROUP, so dying or R clears the count and turns
## it off. The enemies come back at the same moment (their own reset()).

## Indicator colors: enemy purple (§2) while alive, the "go" green once beaten.
const PIP_ALIVE_COLOR: Color = Color(0.62, 0.3, 0.85)
const PIP_DEFEATED_COLOR: Color = Color(0.4, 0.95, 0.5)
## Dark backing plate behind the pips, so they read against any background.
const PLATE_COLOR: Color = Color(0.12, 0.1, 0.16)
## Size of one pip and the distance between pip centers, px.
const PIP_SIZE: float = 3.0
const PIP_SPACING: float = 5.0
## Editor-only dashed lines to the linked enemies.
const LINK_LINE_COLOR: Color = Color(0.62, 0.3, 0.85, 0.6)

## The enemies that must all be defeated. Anything with a `defeated` signal works
## (Wisp, Sentry). Pick them with the node picker in the Inspector.
@export var enemies: Array[Node2D] = []:
	set(value):
		enemies = value
		queue_redraw()

## Enemies beaten since the last reset. An Array (not a counter) so the same enemy
## can never count twice.
var _defeated_enemies: Array[Node2D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(Room.RESETTABLE_GROUP)
	for enemy: Node2D in enemies:
		if enemy == null or not enemy.has_signal(&"defeated"):
			push_warning("[EnemyGate] %s: a slot in `enemies` is empty or has no `defeated` signal" % name)
			continue
		# bind() adds an extra argument to the call, so one handler knows WHICH
		# enemy just fell (the signal itself carries no arguments).
		enemy.connect(&"defeated", _on_enemy_defeated.bind(enemy))


func _process(_delta: float) -> void:
	# Editor only: keep the link lines following the enemies as you drag them around.
	if Engine.is_editor_hint():
		queue_redraw()


## Called by Room.reset_objects() when the player dies or restarts the room.
func reset() -> void:
	_defeated_enemies.clear()
	set_on(false)
	queue_redraw()


func _on_enemy_defeated(enemy: Node2D) -> void:
	if enemy in _defeated_enemies:
		return
	_defeated_enemies.append(enemy)
	queue_redraw()
	if _defeated_enemies.size() >= _get_linked_enemy_count():
		set_on(true)


## Empty slots in the Inspector list don't count, so a stray empty slot can't make
## the gate impossible to open.
func _get_linked_enemy_count() -> int:
	var count: int = 0
	for enemy: Node2D in enemies:
		if enemy != null:
			count += 1
	return count


func _draw() -> void:
	var linked: Array[Node2D] = []
	for enemy: Node2D in enemies:
		if enemy != null:
			linked.append(enemy)
	# Pips are centered on this node: total width = spacing between the outer two.
	var row_width: float = PIP_SPACING * maxf(linked.size() - 1, 0)
	var first_center: Vector2 = Vector2(-row_width / 2.0, 0.0)
	var plate_half_size: Vector2 = Vector2(row_width / 2.0 + PIP_SIZE, PIP_SIZE)
	draw_rect(Rect2(-plate_half_size, plate_half_size * 2.0), PLATE_COLOR)
	for index: int in linked.size():
		var center: Vector2 = first_center + Vector2(PIP_SPACING * index, 0.0)
		var color: Color = PIP_DEFEATED_COLOR if linked[index] in _defeated_enemies else PIP_ALIVE_COLOR
		draw_rect(Rect2(center - Vector2.ONE * PIP_SIZE / 2.0, Vector2.ONE * PIP_SIZE), color)
	if Engine.is_editor_hint():
		for enemy: Node2D in linked:
			draw_dashed_line(Vector2.ZERO, to_local(enemy.global_position), LINK_LINE_COLOR, 1.0, 3.0)

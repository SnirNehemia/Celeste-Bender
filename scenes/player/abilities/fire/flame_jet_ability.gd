class_name FlameJetAbility
extends Node2D
## FlameJetAbility: the flame jet (Fire_bending.md §5.2, W). A component under the
## player, like GustAbility: it owns the pip spending, the thrust curve, and every
## jet visual (plume, nozzle, embers, ignition ring, pump flare, sputter). The
## MOVEMENT lives in the Jetting state (states/jetting.gd), which calls in here.
##
## Flow:
##   Idle/Run/Jump/Fall/WallSlide/Glide/Launched ask player.try_start_jet() every
##   frame -> try_start(): on the frame W is pressed, spend a pip (FireBar). Paid:
##   the state switches to Jetting, whose enter() calls begin_burst(). No pip: a
##   sputter here (three gasps, then smoke) and nothing else happens.
##   Jetting calls update_thrust() each frame (plume follows the thrust), try_chain()
##   when a burst ends with W still held, and end_jet() when it leaves.
##
## The thrust multiplier (get_thrust_multiplier) is the heart of the feel: it starts
## at jet_thrust_start and tapers to jet_thrust_end over the burst (or follows
## jet_thrust_curve when one is set). It scales the jet's speed and acceleration in
## Jetting, and here it scales the plume: longest and whitest at ignition.
##
## This node sits at the player's feet (its parent's origin). The plume nodes are
## its children, drawn behind the body (z_index -1); sparks, rings and smoke are
## added to the world so they stay where they were made.

## Half the hitbox (8×11): the nozzle sits on the body's edge, opposite the thrust.
const BODY_HALF_SIZE: Vector2 = Vector2(4.0, 5.5)
## How fast the plume turns to follow a new thrust direction, per second (higher =
## snappier). Smoothing only the LOOK: the movement turns by jet_turn_accel.
const PLUME_TURN_RATE: float = 25.0
## The nozzle cone: a small white-hot tongue whose length flickers ±3 px (§9.3).
const NOZZLE_LENGTH: float = 6.0
const NOZZLE_FLICKER: float = 3.0
## Sputter (no pips): three short gasps of flame, then a puff of smoke.
const SPUTTER_GASP_COUNT: int = 3
const SPUTTER_GASP_TIME: float = 0.1  # one gasp + the pause after it
const SPUTTER_GASP_ON_TIME: float = 0.045
## Points along the plume tested for flammables each frame (see _ignite_along_plume).
const PLUME_IGNITE_SAMPLES: int = 4
## Smoke puff sizes (sputter, Jump cancel).
const SPUTTER_SMOKE_COUNT: int = 7
const CANCEL_SMOKE_COUNT: int = 5

## Emitted when a burst starts. `is_chain` = it chained from the previous burst.
signal burst_started(is_chain: bool)
## Emitted when a W press found no pip (also at the end of a chain that ran dry).
signal sputtered

var player: Player
var fire_bar: FireBar
## True from begin_burst() to end_jet().
var is_jetting: bool = false
## Where the jet pushes (unit vector) and the current thrust multiplier, as last
## told by the Jetting state. The plume points the other way.
var thrust_direction: Vector2 = Vector2.UP
var thrust_multiplier: float = 1.0
## Bursts in the current flight (1 = the first, 2+ = chained). For the debug overlay.
var burst_count: int = 0
## The plume's current angle (radians, the exhaust direction), eased toward the target.
var plume_angle: float = PI / 2.0
## Real seconds since a sputter began, or -1 when not sputtering.
var sputter_elapsed: float = -1.0

## The visuals (built in _ready). The plume is a sheaf of tongues, rebuilt when
## jet_plume_tongue_count changes (so the F5 panel can change it live).
var plume_tongues: Array[FlameTongue] = []
## Draws the nozzle and the plume tongues as one flame (no outlines between them).
var plume_merge: FlameMerge
## Per tongue: a fixed length factor (outer tongues shorter, plus a random nudge), so
## the tips never line up.
var tongue_length_factors: Array[float] = []
var nozzle: FlameTongue
var plume_embers: EmberEmitter


func _ready() -> void:
	player = get_parent() as Player
	# Not player.fire_bar: the player's @onready vars aren't set until after its
	# children (this node) are ready.
	fire_bar = player.get_node("FireBar") as FireBar
	_build_plume()


# --- Called by the player and the Jetting state ---------------------------------

## On the frame W is pressed (where fire is allowed): spends a pip and returns true
## so the caller switches to Jetting. With no pip it sputters and returns false.
func try_start() -> bool:
	if not Input.is_action_just_pressed("flame_jet") or not player.is_element_allowed(Player.ELEMENT_FIRE):
		return false
	if fire_bar.spend():
		return true
	start_sputter()
	return false


## A burst ended with W still held: pay for the next one. False (and a sputter)
## when the bar is empty, so the flight ends in a readable cough.
func try_chain() -> bool:
	if fire_bar.spend():
		return true
	start_sputter()
	return false


## The thrust multiplier at `progress` (0 = ignition, 1 = end of the burst).
## Read fresh from FireTuning every call, so panel edits apply to the next frame.
func get_thrust_multiplier(progress: float) -> float:
	var tuning: FireTuning = player.fire_tuning
	if tuning.jet_thrust_curve != null:
		return tuning.jet_thrust_curve.sample(clampf(progress, 0.0, 1.0))
	return lerpf(tuning.jet_thrust_start, tuning.jet_thrust_end, clampf(progress, 0.0, 1.0))


## A burst starts (the pip is already paid). `is_chain`: a pump flare instead of the
## ignition whoomp.
func begin_burst(direction: Vector2, is_chain: bool) -> void:
	var tuning: FireTuning = player.fire_tuning
	thrust_direction = direction
	thrust_multiplier = get_thrust_multiplier(0.0)
	if not is_jetting:
		# Snap the plume to the new direction instead of swinging round from the last one.
		plume_angle = (-direction).angle()
		burst_count = 0
	is_jetting = true
	burst_count += 1
	sputter_elapsed = -1.0
	var nozzle_position: Vector2 = get_nozzle_world_position()
	if is_chain:
		# Pump: a bright flare and a ring of sparks at the nozzle.
		FireRing.spawn(_get_effects_parent(), nozzle_position, 9.0, 0.14)
		EmberEmitter.burst(_get_effects_parent(), nozzle_position, tuning.jet_pump_spark_count,
			-direction, 70.0, 80.0)
		FX.play_sfx(&"jet_pump")
	else:
		# Ignition "whoomp": a wider ring and sparks all around.
		FireRing.spawn(_get_effects_parent(), nozzle_position, 14.0, 0.2)
		EmberEmitter.burst(_get_effects_parent(), nozzle_position, tuning.jet_ignition_spark_count,
			-direction, 180.0, 90.0)
		FX.shake(1.5, 0.1)
		FX.play_sfx(&"jet_start")
		_scorch_take_off_ground()
	_squash_along(direction)
	burst_started.emit(is_chain)


## Every physics frame of a burst: the state's current direction and multiplier.
func update_thrust(direction: Vector2, multiplier: float) -> void:
	if direction != thrust_direction:
		_squash_along(direction)
	thrust_direction = direction
	thrust_multiplier = multiplier
	_ignite_along_plume()
	# A very light constant shake (refreshed every frame, so it lasts the burst).
	FX.shake(player.fire_tuning.jet_shake_strength * multiplier, 0.05)


## The plume lights flammables it touches (Stage F4): a few points from the nozzle
## to the tip, each with the plume's half-width as its reach. Flammable.ignite()
## is cheap to repeat, so doing this every physics frame is fine. Grass (the
## FireGrid, Stage F5) catches spread_delay later, so the fire starts behind you.
func _ignite_along_plume() -> void:
	var tuning: FireTuning = player.fire_tuning
	var nozzle_position: Vector2 = get_nozzle_world_position()
	var exhaust: Vector2 = -thrust_direction
	var plume_length: float = tuning.jet_plume_length * lerpf(0.6, 1.0, _get_thrust_share())
	var reach: float = tuning.jet_plume_fan_width * 0.5
	var flammables: Array[Node] = get_tree().get_nodes_in_group(Flammable.GROUP)
	for step: int in PLUME_IGNITE_SAMPLES:
		var point: Vector2 = nozzle_position + exhaust * plume_length * step / float(PLUME_IGNITE_SAMPLES - 1)
		for target: Node in flammables:
			Flammable.ignite_if_near(target, point, reach, self)


## Taking off from grass scorches the cell under the feet (Fire_bending.md §5.2): it
## catches spread_delay later (FireGrid.ignite_at delays the jet's fire), when you're
## already up and away.
## Only when the flame actually points at the ground (after the F6 play-test): fire
## burns what it touches, so a flame pointing up, or straight sideways (the plume
## itself lights what it brushes), leaves the floor under you alone.
func _scorch_take_off_ground() -> void:
	if not player.is_on_floor():
		return
	var exhaust: Vector2 = -thrust_direction
	if exhaust.y <= 0.0:
		return  # the flame points up or sideways, away from the floor
	var grid: FireGrid = FireGrid.find_grid_at(get_tree(), player.global_position)
	if grid != null:
		# This node's origin = the feet; 2 px down is inside the floor tile.
		grid.ignite_at(player.global_position + Vector2(0.0, 2.0), 0.0, self)


## The flight is over. `snapped_off` (Jump cancel): the flame snaps off in a puff.
func end_jet(snapped_off: bool) -> void:
	if not is_jetting:
		return
	is_jetting = false
	plume_embers.emitting = false
	if snapped_off:
		_spawn_smoke(get_nozzle_world_position(), CANCEL_SMOKE_COUNT)
	player.movement_effects.release_squash()


## No pip: three gasps from the nozzle, then smoke (drawn in _process).
func start_sputter() -> void:
	sputter_elapsed = 0.0
	FX.play_sfx(&"jet_sputter")
	sputtered.emit()


## One line for the debug overlay.
func describe() -> String:
	if not is_jetting:
		return "-"
	return "x%.2f burst %d" % [thrust_multiplier, burst_count]


## Where the flame leaves the body: on the hitbox edge, opposite the thrust.
func get_nozzle_world_position() -> Vector2:
	var exhaust: Vector2 = -thrust_direction
	# Distance from the center to the box edge along `exhaust` (the nearer of the
	# vertical and horizontal edges).
	var edge_distance: float = INF
	if absf(exhaust.x) > 0.001:
		edge_distance = minf(edge_distance, BODY_HALF_SIZE.x / absf(exhaust.x))
	if absf(exhaust.y) > 0.001:
		edge_distance = minf(edge_distance, BODY_HALF_SIZE.y / absf(exhaust.y))
	return player.get_center() + exhaust * edge_distance


# --- Visuals ---------------------------------------------------------------------

func _build_plume() -> void:
	nozzle = FlameTongue.new()
	nozzle.name = "Nozzle"
	nozzle.z_index = -1
	nozzle.heat = 1.0
	nozzle.flicker_speed = 3.0
	nozzle.breath_amount = 0.0  # its flicker is done by hand below (±3 px)
	nozzle.visible = false
	add_child(nozzle)
	plume_merge = FlameMerge.make(self)
	plume_merge.name = "PlumeMerge"
	plume_merge.add_tongue(nozzle)
	plume_embers = EmberEmitter.new()
	plume_embers.name = "PlumeEmbers"
	plume_embers.amount = 24
	plume_embers.lifetime = 0.35
	plume_embers.spread = 14.0
	plume_embers.initial_velocity_min = 60.0
	plume_embers.initial_velocity_max = 120.0
	add_child(plume_embers)


## _process: visuals only, every drawn frame.
func _process(delta: float) -> void:
	var tuning: FireTuning = player.fire_tuning
	var exhaust: Vector2 = -thrust_direction
	# lerp_angle takes the short way round; the weight makes it frame-rate independent.
	plume_angle = lerp_angle(plume_angle, exhaust.angle(), 1.0 - exp(-PLUME_TURN_RATE * delta))
	var plume_direction: Vector2 = Vector2.from_angle(plume_angle)
	# FlameTongue draws toward its local -Y; -Y has angle -PI/2, hence + PI/2.
	var tongue_rotation: float = plume_angle + PI / 2.0
	var nozzle_local: Vector2 = to_local(get_nozzle_world_position())

	if plume_tongues.size() != tuning.jet_plume_tongue_count:
		_rebuild_plume_tongues(tuning.jet_plume_tongue_count)
	for tongue: FlameTongue in plume_tongues:
		tongue.visible = is_jetting
	if is_jetting:
		# Thrust 1.0 = at full thrust (ignition), 0.0 = at the end of the taper. The
		# plume shrinks to 60% and cools from white to orange-red over the burst.
		var thrust_share: float = _get_thrust_share()
		_layout_plume_tongues(nozzle_local, plume_direction, thrust_share)
		plume_embers.position = nozzle_local + plume_direction * 3.0
		plume_embers.direction = plume_direction
		plume_embers.amount = maxi(1, roundi(tuning.jet_embers_per_second * plume_embers.lifetime))
		plume_embers.emitting = true

	# The nozzle: white-hot while jetting, and the three gasps of a sputter.
	var show_nozzle: bool = is_jetting
	if sputter_elapsed >= 0.0:
		sputter_elapsed += delta
		var gasp_index: int = int(sputter_elapsed / SPUTTER_GASP_TIME)
		var time_in_gasp: float = fmod(sputter_elapsed, SPUTTER_GASP_TIME)
		show_nozzle = gasp_index < SPUTTER_GASP_COUNT and time_in_gasp < SPUTTER_GASP_ON_TIME
		if gasp_index >= SPUTTER_GASP_COUNT:
			sputter_elapsed = -1.0
			_spawn_smoke(get_nozzle_world_position(), SPUTTER_SMOKE_COUNT)
		elif not is_jetting:
			# Sputtering from rest: aim the gasps where the jet would have gone.
			var aim: Vector2 = player.get_aim_input()
			thrust_direction = aim if aim != Vector2.ZERO else Vector2.UP
			plume_angle = (-thrust_direction).angle()
	nozzle.visible = show_nozzle
	if show_nozzle:
		nozzle.position = nozzle_local
		nozzle.rotation = tongue_rotation
		# Gasps are short and weak; a burst's nozzle flickers ±3 px around 6.
		var flicker: float = randf_range(-NOZZLE_FLICKER, NOZZLE_FLICKER)
		nozzle.length = (NOZZLE_LENGTH + flicker) * (1.0 if is_jetting else 0.6)
		nozzle.base_width = 4.0
		nozzle.fan_width = 5.0


## (Re)makes `count` FlameTongues for the plume. Each gets its own noise seed (in
## FlameTongue._ready), so they lick out of step.
func _rebuild_plume_tongues(count: int) -> void:
	for tongue: FlameTongue in plume_tongues:
		tongue.queue_free()
	plume_tongues.clear()
	tongue_length_factors.clear()
	for index: int in count:
		var tongue: FlameTongue = FlameTongue.new()
		tongue.name = "PlumeTongue%d" % index
		tongue.z_index = -1  # behind the body
		tongue.flicker_speed = randf_range(1.8, 2.8)
		tongue.wobble_amount = 0.35
		tongue.breath_amount = 0.3  # more length breathing than a lone flame: ragged tips
		tongue.visible = false
		add_child(tongue)
		plume_merge.add_tongue(tongue)
		plume_tongues.append(tongue)
		# Middle tongues longest, outer ones down to ~65%, with a random nudge.
		var spread_position: float = _get_spread_position(index, count)
		tongue_length_factors.append((1.0 - 0.35 * absf(spread_position)) * randf_range(0.85, 1.05))


## Fans the tongues out from the nozzle: side by side across the nozzle width, each
## tilted a little outward (jet_plume_spread_degrees between the outer two), so
## their tips spread to about jet_plume_fan_width.
func _layout_plume_tongues(nozzle_local: Vector2, plume_direction: Vector2, thrust_share: float) -> void:
	var tuning: FireTuning = player.fire_tuning
	var count: int = plume_tongues.size()
	# Perpendicular to the plume: the axis the tongues sit along at the nozzle.
	var across: Vector2 = plume_direction.orthogonal()
	# Each tongue is thinner than the whole plume; neighbours overlap.
	var tongue_base_width: float = tuning.jet_plume_nozzle_width * (0.6 if count > 1 else 1.0)
	var tongue_fan_width: float = tuning.jet_plume_fan_width * (0.5 if count > 1 else 1.0)
	var plume_length: float = tuning.jet_plume_length * lerpf(0.6, 1.0, thrust_share)
	for index: int in count:
		var tongue: FlameTongue = plume_tongues[index]
		var spread_position: float = _get_spread_position(index, count)
		var side_offset: float = spread_position * (tuning.jet_plume_nozzle_width - tongue_base_width) * 0.5
		tongue.position = nozzle_local + across * side_offset
		# FlameTongue draws toward its local -Y; -Y has angle -PI/2, hence + PI/2.
		tongue.rotation = plume_direction.angle() + PI / 2.0 			+ deg_to_rad(spread_position * tuning.jet_plume_spread_degrees * 0.5)
		tongue.length = plume_length * tongue_length_factors[index]
		tongue.base_width = tongue_base_width
		tongue.fan_width = tongue_fan_width * lerpf(0.75, 1.0, thrust_share)
		# The middle tongues burn hottest (whitest).
		tongue.heat = thrust_share * (1.0 - 0.4 * absf(spread_position))
		# The dance: forked tips, and licks torn off them (the rate shared out over
		# the tongues, so the total doesn't grow with the tongue count).
		tongue.fork_amount = tuning.jet_plume_fork_amount
		tongue.lick_rate = tuning.jet_plume_licks_per_second / float(count)
		tongue.lick_lifetime = tuning.jet_plume_lick_lifetime
		tongue.lick_speed = tuning.jet_plume_lick_speed
		tongue.lick_size = tongue_fan_width * 0.8
		tongue.smoke_rate = tuning.jet_plume_smoke_per_second / float(count)


## Where tongue `index` sits across the sheaf: -1 (one edge) .. 0 (middle) .. +1.
func _get_spread_position(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	return float(index) / float(count - 1) * 2.0 - 1.0


## Where the multiplier sits between the end and start values: 1 at ignition, 0 at
## the end of the taper (works for a curve too, clamped).
func _get_thrust_share() -> float:
	var tuning: FireTuning = player.fire_tuning
	var span: float = tuning.jet_thrust_start - tuning.jet_thrust_end
	if absf(span) < 0.001:
		return 1.0
	return clampf((thrust_multiplier - tuning.jet_thrust_end) / span, 0.0, 1.0)


## Squash along the thrust axis while jetting: thinner across, longer along. The
## body pivot only scales on x/y, so a diagonal counts as its larger axis.
func _squash_along(direction: Vector2) -> void:
	var squash: Vector2 = player.fire_tuning.jet_squash
	if absf(direction.x) > absf(direction.y):
		player.movement_effects.hold_squash(Vector2(squash.y, squash.x))
	else:
		player.movement_effects.hold_squash(squash)


## A one-shot puff of smoke (SmokePuff, shared with the fireball and braziers).
func _spawn_smoke(world_position: Vector2, count: int) -> void:
	SmokePuff.spawn(_get_effects_parent(), world_position, count)


## Effects go to the player's parent (the world), so they stay put as we fly on.
func _get_effects_parent() -> Node:
	return player.get_parent()

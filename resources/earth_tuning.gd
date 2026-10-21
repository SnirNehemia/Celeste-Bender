class_name EarthTuning
extends Resource
## Every number that affects how EARTH bending feels lives here (Earth_bending.md).
## The Earth twin of PlayerTuning: the player holds one (resources/earth_tuning.tres)
## in its `earth_tuning` field, and the earth code reads it fresh every frame, so
## Remote-tab edits while the game runs take effect at once.
##
## Earth_bending.md §4 asks for the aim timers to run in REAL time (not slowed by the
## bend's slow motion), so aiming feels the same every time. Values marked
## "real seconds" / "real px/s" follow that rule.

@export_group("Earth tiles")
## How long a tile takes to darken from fresh to used, seconds.
## Fading (instead of snapping) lets the eye follow where the earth was spent.
@export var used_fade_time: float = 0.2
## How long a tile shivers when the shadow passes through it, real seconds.
@export var shiver_time: float = 0.25
## Shiver flicker: the tile's colors are multiplied by this on the bright beats.
@export var shiver_brightness: float = 1.25
## How often the shiver flips between bright and normal, real seconds. Smaller = buzzier.
@export var shiver_flip_interval: float = 0.04

@export_group("Bend: slow motion & shadow")
## World speed while bending (aiming). 0.3 = enemies, orbs and objects at 30% speed.
@export var bend_time_scale: float = 0.3
## The shadow waits under the feet this long before crawling, real seconds.
## Releasing before then is a "quick tap": the move fires right under the player.
@export var shadow_start_delay: float = 0.5
## Shadow crawl speed along the earth surface, real px/s.
@export var shadow_speed: float = 60.0
## The aim phase ends by itself after this long and the move fires, real seconds.
## Stops slow motion from being used to hang around.
@export var bend_max_time: float = 2.5
## Body scale while in the bending stance (x = width, y = height): a slight crouch.
@export var bend_squash: Vector2 = Vector2(1.25, 0.8)
## EXPERIMENT (after Stage E7, kept off after its play-test: the crawl felt more
## natural): YOU move the shadow with the arrows instead of it crawling away by itself. Hold an arrow: it moves that way along the surface (round
## corners too: keep holding the same arrow); let go: it stops. It can come back
## toward you and out the other side. Tick to try it; untick = it crawls by itself.
@export var shadow_steerable: bool = false
## Steered shadow speed along the surface, real px/s.
@export var shadow_steer_speed: float = 70.0
## With a steered shadow the bend fires by itself after this long, real seconds
## (instead of bend_max_time): steering takes longer than watching it crawl.
@export var shadow_steer_max_time: float = 4.0

@export_group("Gravel")
## Bits popped off at the feet when a bend starts.
@export var feet_gravel_count: int = 5
## Bits dropped behind the shadow on each tile it enters.
@export var path_gravel_count: int = 2
## The shadow sheds a bit or two this often while it is moving, real seconds.
@export var shadow_gravel_interval: float = 0.12
## Bits in the burst where a bend erupts.
@export var eruption_gravel_count: int = 12
## Screen shake when a bend erupts: strength (px) and duration (s).
@export var eruption_shake_strength: float = 1.5
@export var eruption_shake_time: float = 0.12

@export_group("Earth Column")
## Column size, px: width across the surface, length out of it (1 x 3 tiles).
## Under a low ceiling the column only grows as far as the open space allows.
@export var column_width: float = 8.0
@export var column_length: float = 24.0
## How long the column takes to rise to full length, seconds (game time).
@export var column_rise_time: float = 0.1
## The RISING tip throws what it hits at this speed, px/s: crates and enemies in any
## direction, the player when the column comes out of a wall or a ceiling.
## Once risen, the column is a plain platform and throws nothing.
@export var column_launch_speed: float = 220.0
## A column rising under the PLAYER throws them up at this speed instead: the super
## jump. 320 px/s climbs about 2x a full regular jump (320² / (2 × 900) ≈ 57 px,
## against ~28 px).
@export var column_super_jump_speed: float = 320.0
## A sideways launch also throws the player UP at this speed, px/s (like Celeste's
## side springs): without it you'd skim the floor and land after a few px.
@export var column_side_launch_lift: float = 140.0
## After a sideways launch, the arrows don't steer for this long, seconds. Without
## it, normal air control would eat the 220 px/s within about 0.2 s.
@export var launch_steer_lock_time: float = 0.15
## After the lock, speed above max run speed fades at this gentle rate, px/s²,
## unless you steer against it. Keeps the throw feeling like a throw.
@export var launch_overspeed_deceleration: float = 300.0
## Gravel bits where the rising tip hits something.
@export var column_hit_gravel_count: int = 6
## The pillar's FOOT: when a column rises, the earth under its base hardens in a
## pyramid this many rows deep (1, 3, 5... tiles wide), into the ground or wall it
## rose from. Hardened earth can't be torn out by rocks, so a pillar can't be dug
## loose and left floating. (It can still be bent: columns, snake.)
@export var column_foot_rows: int = 3

@export_group("Boulder (rock)")
## Rock size, px: one tile (Stage E4a). It's torn out of one earth tile, which
## becomes open air until the room resets.
@export var boulder_size: float = 8.0
## Tear phase: the rock rumbles and slowly works its way out of its hole (one tile
## along the surface's normal) over this long, seconds (game time).
@export var boulder_tear_time: float = 0.15
## Rumble while tearing: the rock jitters up to this far sideways, px (drawn only).
@export var boulder_tear_rumble: float = 0.75
## Then it HOPS: up this high above where it came out, px. 22 px puts the rock's
## bottom well above the player's head (11 px tall), so it arcs over in front of you.
@export var boulder_hop_height: float = 22.0
## ...and drifts AWAY from the player at this speed, px/s, while hopping.
@export var boulder_hop_away_speed: float = 30.0
## A rock torn out of the WALL you slide on hops away from the wall this fast, px/s,
## so it clears the wall instead of rising along it.
@export var boulder_wall_hop_away_speed: float = 90.0
## World speed from the tear until the throw (slow motion, like a bend). The rock moves
## in game time, so the perfect window lasts 1 / this longer in real time.
@export var boulder_time_scale: float = 0.5
## ...but the slow motion ends after this many REAL seconds, throw or not.
@export var boulder_slow_motion_max_time: float = 2.0
## Perfect throw window: within this many seconds (game time) of the moment the
## rock's middle comes back DOWN level with the player's middle.
@export var boulder_perfect_window: float = 0.08
## An un-thrown rock that lands thuds and rests this long (still throwable) before it
## crumbles. A floor rock lands almost exactly at the player's middle height, so
## without the rest the perfect window would be cut off by the landing.
@export var boulder_land_rest_time: float = 0.2
## Outside the window, the throw quality drops linearly to 0 over this many more
## seconds. Quality 0 = boulder_min_throw_speed with normal gravity (a throw at the
## top of the hop, ~0.2 s before the window, is already the weakest).
@export var boulder_throw_falloff_time: float = 0.12
## Throw speed for a perfect throw / the worst throw, px/s. Off-peak throws are
## in between, by quality.
@export var boulder_perfect_throw_speed: float = 320.0
@export var boulder_min_throw_speed: float = 180.0
## A perfect throw ignores gravity for this long, seconds; off-peak throws for
## (this x quality), so a late throw droops right away.
@export var boulder_perfect_float_time: float = 0.3
## Rock gravity and max fall speed (the hop, and after a throw's float time).
@export var boulder_gravity: float = 900.0
@export var boulder_max_fall_speed: float = 300.0
## The player stays rooted holding the boulder at most this long (game time). No throw
## by then = the boulder drops and shatters.
@export var boulder_hold_time: float = 1.0
## A boulder hitting a risen column bounces off it at least this fast along the
## column's face, px/s (the column's spring speed, Earth_bending.md §5).
@export var boulder_column_bounce_speed: float = 220.0
## Gravel bits when it shatters / when it sticks into earth.
@export var boulder_shatter_gravel_count: int = 10
@export var boulder_stick_gravel_count: int = 6
## Screen shake when it sticks or shatters: strength (px) and duration (s).
@export var boulder_impact_shake_strength: float = 1.0
@export var boulder_impact_shake_time: float = 0.1
## A flying boulder that never hits anything (thrown out of the room) shatters after
## this long, seconds.
@export var boulder_max_flight_time: float = 3.0

@export_group("Boulder: hover aim")
## The DEFAULT since the E7 play-test: instead of hopping over your head, the rock
## rises out of its hole and HOVERS beside you at chest height, in slow motion
## (boulder_hover_time_scale). While it hovers the arrows AIM (8 directions, like the
## gust's aim: letting go keeps the last aim), shown by faint GHOSTS of the rock in
## the throw direction. A faint CONTOUR of the rock starts wide and closes in on it:
## press S again just as it fits the rock (the rock turns white) for the perfect
## throw, faster and further. Untick for the old hop (boulder_time_scale then).
@export var boulder_hover_aim: bool = true
## World speed while the rock hovers (slower than the hop's boulder_time_scale: you
## aim AND time it). All the times below are game time, so they last 1 / this longer
## in real time.
@export var boulder_hover_time_scale: float = 0.4
## Out of its hole, the rock glides to its hover spot over this long, s (game time).
@export var boulder_hover_rise_time: float = 0.12
## Gap between the player's side and the hovering rock, px.
@export var boulder_hover_gap: float = 3.0
## Once it's there, the contour closes in on it over this long, s (game time). The
## perfect moment is when it fits (boulder_perfect_window either side).
@export var boulder_hover_ring_time: float = 0.3
## The contour starts this many times the rock's size.
@export var boulder_hover_ring_start_scale: float = 3.0
## Not thrown this long after the tear (s, game time) = it drops and lies loose.
## Longer than the hop's boulder_hold_time: aiming takes a moment.
@export var boulder_hover_hold_time: float = 1.0
## The hovering rock bobs up and down this far, px (drawn only).
@export var boulder_hover_bob: float = 1.0
## The aim GHOSTS: this many faint copies of the rock in the throw direction, this
## far apart (px, center to center: the rock's size plus this gap).
@export var boulder_hover_ghost_count: int = 3
@export var boulder_hover_ghost_gap: float = 3.0

@export_group("Loose rocks")
## A rock that comes down without being thrown lies there as a LOOSE rock (Stage
## E4c3): solid, standable, and S next to it lifts it again. At most this many per
## room: the oldest crumbles.
@export var loose_rock_max_per_room: int = 3
## "Next to": a loose rock within this many px of the player's sides (and level with
## their body, not under their feet) can be lifted.
@export var loose_rock_lift_reach: float = 6.0

@export_group("Shatter creations (tap S)")
## After the E7 play-test: a TAP of S while touching a creation (a stuck or loose rock,
## a hardened snake, a risen pillar: standing on it, or within loose_rock_lift_reach
## of your sides) shatters it into pebbles instead of tearing new earth. A whole snake
## crumbles, tile by tile outward from the one you touch. The earth it used stays spent.
## A loose rock BESIDE you waits to see: S released within this many REAL seconds =
## a tap (shatter); still held = lift it as before.
@export var shatter_tap_time: float = 0.15
## Gravel bits per tile of a shattered creation (they leave pebbles that stay).
@export var shatter_gravel_per_tile: int = 8
## A crumbling snake loses one tile every this many real seconds, from the touched tile out.
@export var snake_crumble_step_time: float = 0.025

@export_group("Big rock (hold S)")
## Holding S until the rock is out of its hole (boulder_tear_time) grows it into a big
## rock this size, px (Stage E4c2): 2x2 tiles, torn out of a 2x2 block.
@export var big_rock_size: float = 16.0
## A big rock is heavier: its throw speed (perfect or not) is multiplied by this.
@export var big_rock_throw_speed_scale: float = 0.85
## Gravel bits and screen shake (strength px, duration s) when it grows.
@export var big_rock_grow_gravel_count: int = 14
@export var big_rock_grow_shake_strength: float = 1.5
@export var big_rock_grow_shake_time: float = 0.15

@export_group("Hidden chambers")
## When a dug hole reaches a hidden chamber (Stage E4c), its cover crumbles away:
## each cell fades out over this many REAL seconds...
@export var hidden_crumble_time: float = 0.25
## ...starting this much later per cell step away from the breach, so the crumble
## spreads along the tunnel instead of vanishing all at once.
@export var hidden_crumble_step_delay: float = 0.03
## Gravel bits each crumbling cell drops.
@export var hidden_crumble_gravel_count: int = 3
## Screen shake when a chamber opens: strength (px) and duration (s).
@export var hidden_crumble_shake_strength: float = 1.5
@export var hidden_crumble_shake_time: float = 0.2
## WIDEN THE BREACH (after the E7 play-test): the player is a tile wide, so a way into
## a chamber only one tile wide is a dead end (you'd have to dig the last tile beside
## it, which is fiddly). When a chamber opens, the thin fresh earth beside the breach
## crumbles too, along the dug hole back up to the surface, so the way in is always
## 2 tiles wide. Untick to dig it yourself.
@export var hidden_widen_breach: bool = true
## Gravel bits per tile that crumbles to widen the breach.
@export var hidden_breach_gravel_count: int = 4

@export_group("Pebbles")
## Earth effects leave pebbles that STAY on the ground (Stage E4d, PebbleField).
## Bends that USE ground (a column's tile, a rock's torn tiles) leave this many per
## tile, so a big rock (4 tiles) leaves 4x a small one's. Fractions are rolled as a
## chance, so 2.5 leaves 2 or 3.
@export var pebbles_per_used_tile: float = 8.0
## Everything else that sprays gravel (impacts, shatters, the shadow's path, a lifted
## loose rock) leaves this many pebbles per gravel bit.
@export var pebbles_per_gravel: float = 0.7
## Along the shadow's path only a few are left (on top of pebbles_per_gravel), so a
## long crawl doesn't carpet the floor.
@export var shadow_path_pebble_fraction: float = 0.4
## At most this many pebbles lie in one room: when a new one would go over, the
## oldest disappears.
@export var pebble_max_per_room: int = 120
## Gravity on a pebble, px/s². Close to the gravel's 420: pebbles are stones.
@export var pebble_gravity: float = 400.0
## Speed a fresh pebble flies out at (min, max), px/s, along the gravel's direction.
@export var pebble_spawn_speed_min: float = 20.0
@export var pebble_spawn_speed_max: float = 60.0
## Hitting the ground, a pebble keeps this much of its fall speed as a bounce...
@export var pebble_bounce: float = 0.3
## ...and bounces slower than this (px/s) just settle.
@export var pebble_settle_speed: float = 25.0
## Rolling on the ground, the sideways speed shrinks by e^(-friction × t).
## 6.0 = a kicked pebble stops rolling after about half a second.
@export var pebble_ground_friction: float = 6.0
## Something moving at least this fast (px/s) kicks the pebbles at its feet.
@export var pebble_kick_min_speed: float = 30.0
## A kick throws a pebble up at (min, max) px/s, and sideways at this share of the
## kicker's own speed (min, max).
@export var pebble_kick_up_speed_min: float = 40.0
@export var pebble_kick_up_speed_max: float = 90.0
@export var pebble_kick_carry_min: float = 0.4
@export var pebble_kick_carry_max: float = 1.0
## Gusts reach pebbles this far from the gust's origin, px...
@export var pebble_gust_reach: float = 48.0
## ...and throw them at this share of the gust strength (pebbles are heavier than
## leaves, so they fly less far).
@export var pebble_gust_strength_scale: float = 0.6
## In a wind zone a pebble is pulled toward this share of the wind speed (and floor
## friction only slows it down to that speed): a sideways current rolls them along. (An updraft can't lift a stone:
## gravity is much stronger than the wind.)
@export var pebble_wind_speed_scale: float = 0.5
## How quickly it reaches that speed, 1/s.
@export var pebble_wind_grip: float = 4.0

@export_group("Rock & pillar look")
## Looks only (Stage E4e): nothing here changes how rocks or pillars play.
## A thrown rock tumbles at this speed, radians per second (14 ≈ 2 turns a second),
## the way it flies (clockwise going right). A big rock turns slower (by its size).
@export var rock_flight_spin_speed: float = 14.0
## While it hops out of the ground it turns gently at this speed, radians per second.
@export var rock_hop_spin_speed: float = 4.0
## Once it rests (lands, lies loose) it turns back to the nearest quarter turn at
## this speed, radians per second, so a loose or stuck rock sits square on the grid.
@export var rock_settle_spin_speed: float = 12.0
## A moving rock (hopping or thrown) sheds a pebble every so often: a random wait
## between these two, seconds (game time).
@export var rock_pebble_shed_interval_min: float = 0.12
@export var rock_pebble_shed_interval_max: float = 0.3
## A rising pillar crumbles this many pebbles off its sides over the rise.
@export var column_rise_pebble_count: int = 4

@export_group("Earth Snake")
## The snake (Earth_bending.md §7, §11, Stage E5): hold A until the shadow crawls off
## your feet, release A and a ribbon of earth comes out at the shadow; steer it with
## the arrows, press A again (or Jump) to harden it. Its head running into you throws
## you off it (like a rising column), or crushes you against the ground.
## Its head moves this fast, px/s, in REAL time (at 0.3x game speed it would crawl).
## 80 px/s = 10 tiles a second.
@export var snake_speed: float = 80.0
## World speed while steering the snake (the bend itself uses bend_time_scale, 0.3).
## Slower than the bend: steering takes your attention, so enemies and orbs barely
## move meanwhile. The snake doesn't care (it moves in real time).
@export var snake_time_scale: float = 0.2
## ONE KEY for column and snake, in every room (chosen after play-testing Stage E5): a
## quick tap of A = a column under you; once the shadow has crawled off your feet,
## releasing A = a snake instead of a column. Untick to go back to "a long A bend = a
## column at the shadow" (then there's no snake at all: D is free; a room can still
## turn one key on for itself: Room.one_key_column_snake).
@export var one_key_column_snake: bool = true
## At most this many tiles long. Each snake tile uses one fresh tile of the patch it
## came out of, so a smaller patch makes a shorter snake.
@export var snake_max_tiles: int = 12
## It hardens by itself after steering this long, real seconds.
@export var snake_max_time: float = 2.5
## Gravel bits from the head each time it enters a new tile.
@export var snake_head_gravel_count: int = 2
## Gravel bits along the snake when it hardens (spread over its tiles).
@export var snake_harden_gravel_count: int = 10
## Screen shake when it hardens: strength (px) and duration (s).
@export var snake_harden_shake_strength: float = 1.0
@export var snake_harden_shake_time: float = 0.1

@export_group("Cracked walls & enemies")
## Stage E6 (Earth_bending.md §2, §6, §7). A thrown rock breaks a CRACKED WALL open
## (any size of rock, one hit): this many gravel bits per tile of wall, and a shake.
@export var cracked_wall_gravel_per_tile: int = 4
## ...and leaves this many gray pebbles per tile lying around (a 2x6 wall: 72, so it
## stays under pebble_max_per_room).
@export var cracked_wall_pebbles_per_tile: int = 6
@export var cracked_wall_shake_strength: float = 2.0
@export var cracked_wall_shake_time: float = 0.15
## A thrown rock hitting a WISP knocks it back along the throw at this speed, px/s...
@export var boulder_enemy_knockback_speed: float = 200.0
## ...and it pops (defeated) this long after the hit, seconds (game time): long
## enough to see it fly, short enough that the hit reads as the kill. Harmless
## meanwhile. A sentry doesn't fly: it's destroyed at once.
@export var boulder_enemy_defeat_delay: float = 0.15
## The snake's HEAD shoving a wisp out of its tile also knocks it back along the
## head's direction at this speed, px/s: stunned and sliding, no hop (a wisp slides
## 120² / (2 x 320) ≈ 22 px on the ground). Ram it off a ledge into spikes. Faster
## (or with a hop like a gust's) and the last shove flings it over a narrow pit.
@export var snake_enemy_knockback_speed: float = 120.0

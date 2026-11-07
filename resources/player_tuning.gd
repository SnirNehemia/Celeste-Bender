class_name PlayerTuning
extends Resource
## Every number that affects how the player FEELS lives here (GAME_DESIGN.md §4).
##
## A Resource is a Godot data container that can be saved to a file (.tres).
## The player holds a reference to one of these (resources/player_tuning.tres).
## The player code reads these values fresh every physics frame (it never copies
## them at startup), so editing them while the game runs takes effect immediately:
## in the editor, open the Scene dock's "Remote" tab, select Player, and expand
## its `tuning` field in the Inspector.
## (Editing the .tres file itself while the game runs does NOT reach the running game,
## and Remote tab edits are lost when the game stops. To keep them, press F4 in game:
## the debug overlay writes the live values into player_tuning.tres.)

## The two ways the player can be drawn (see body_style below).
enum BodyStyle { BACKPACK, PLAIN_RECTANGLE }

@export_group("Look")
## How the player is drawn. Looks only: the hitbox is the same 8x11 either way.
## BACKPACK (default): the white body with a dark outline, two dot eyes and a small
## pack on the back that trails behind the motion and whose lid flaps open while
## falling (PlayerBodyLook, scenes/player/body_look.gd).
## PLAIN_RECTANGLE: the original plain white rectangle (the Visual ColorRect).
@export var body_style: BodyStyle = BodyStyle.BACKPACK
## How far the pack trails behind the motion, px. 1 = one pixel: when running it
## slides a pixel back and a seam of outline shows between pack and body. 0 = no lag.
@export var pack_lag_pixels: float = 1.0
## Horizontal speed at which the pack trails the full pack_lag_pixels, px/s.
@export var pack_lag_full_speed_x: float = 80.0
## Vertical speed at which the pack trails the full pack_lag_pixels, px/s.
## (Rising: it hangs a pixel low; falling: it rides a pixel high.)
@export var pack_lag_full_speed_y: float = 140.0
## How hard the pack's spring pulls it toward where it trails to. Higher = it
## catches up faster when you stop.
@export var pack_spring_stiffness: float = 160.0
## The pack spring's damping. Lower = more overshoot when it catches up.
@export var pack_spring_damping: float = 14.0
## After turning around, the pack stays on the old side this long, seconds, then
## swings across: it reads as a separate thing strapped on.
@export var pack_turn_delay: float = 0.07
## The lid starts to lift once falling faster than this, px/s.
@export var lid_open_fall_speed: float = 40.0
## At this fall speed (or faster) the lid opens widest and flutters fastest, px/s.
@export var lid_full_fall_speed: float = 220.0
## How many times a second the lid flutters, at the slowest and fastest fall.
@export var lid_flutter_rate_slow: float = 2.2
@export var lid_flutter_rate_fast: float = 4.5
## The eyes blink every blink_interval seconds, plus up to blink_interval_random more.
@export var blink_interval: float = 2.2
@export var blink_interval_random: float = 2.0
## How long one blink keeps the eyes shut, seconds.
@export var blink_time: float = 0.1
## How long the eyes squint shut after a landing, seconds.
@export var land_squint_time: float = 0.14
## In the air, the eyes glance up a pixel while rising faster than this, px/s...
@export var eye_glance_up_speed: float = 60.0
## ...and down a pixel while falling faster than this, px/s.
@export var eye_glance_down_speed: float = 90.0

@export_group("Run")
## Top horizontal speed on the ground, px/s.
@export var max_run_speed: float = 90.0
## How fast we speed up toward max_run_speed while a direction is held, px/s².
## High value = snappy start.
@export var run_acceleration: float = 1000.0
## How fast we slow down on the ground when no direction is held, px/s². Gives a short slide.
@export var run_deceleration_ground: float = 400.0
## Multiplier on acceleration/deceleration while airborne (<1 = less air control).
@export var air_acceleration_multiplier: float = 0.65

@export_group("Gravity")
## Downward acceleration, px/s².
@export var gravity: float = 900.0
## Terminal falling speed, px/s.
@export var max_fall_speed: float = 300.0
## Terminal falling speed while holding Down (fast-fall), px/s.
@export var fast_fall_max_speed: float = 500.0

@export_group("Jump")
## Initial upward speed of a jump, px/s (negative = up in Godot's 2D coordinates).
@export var jump_velocity: float = -105.0
## While jump is HELD, upward speed is kept at the launch speed for up to this long
## instead of decaying under gravity. Releasing early cuts the hold short, which is
## what makes jump height variable: tap = ~7 px hop, full hold = ~30 px jump (incl. apex half-gravity).
@export var variable_jump_time: float = 0.2
## While |vertical speed| is below this (near the top of an arc) and jump is held,
## gravity is reduced, giving a floaty, controllable apex. px/s.
@export var apex_gravity_threshold: float = 40.0
## Gravity multiplier used near the apex (see apex_gravity_threshold).
@export var apex_gravity_multiplier: float = 0.5
## Can still jump this long after walking off a ledge, seconds.
@export var coyote_time: float = 0.1
## A jump pressed this long before it becomes possible (landing, touching a wall)
## still happens, seconds.
@export var jump_buffer_time: float = 0.1

@export_group("Wall")
## Max downward speed while sliding on a wall (holding toward it), px/s.
@export var wall_slide_max_speed: float = 40.0
## Horizontal push away from the wall on a wall jump, px/s.
@export var wall_jump_horizontal_speed: float = 130.0
## Upward speed of a wall jump, px/s. Held like a normal jump (variable_jump_time).
@export var wall_jump_vertical_speed: float = -105.0
## After a wall jump, horizontal input is ignored this long so the push away
## isn't instantly cancelled by still holding toward the wall, seconds.
@export var wall_jump_input_lock_time: float = 0.15
## A wall within this many pixels counts as "touching" for wall jumps and wall
## slides, so you don't need pixel-perfect contact (or to press into the wall).
@export var wall_jump_check_distance: float = 2.0

@export_group("Glide")
## Fall speed while gliding, px/s (GAME_DESIGN.md §5.2: 30).
@export var glide_max_fall_speed: float = 30.0
## How fast vertical speed blends toward the glide speed, px/s². High = the glide
## "catches" you almost at once; low = a softer, floatier catch.
@export var glide_vertical_acceleration: float = 900.0
## Seconds of gliding per airtime. Refills on the ground.
@export var glide_stamina_time: float = 1.5
## In an updraft, the zone's upward wind speed is multiplied by this while gliding.
## Example: updraft strength 60 x 2.0 = 120 px/s of lift, minus the 30 px/s glide fall
## = rising at 90 px/s.
@export var glide_updraft_lift_multiplier: float = 2.0
## Stamina drain multiplier inside an updraft (0 = riding an updraft is free, so
## updrafts work as "elevators" of any height; 1 = drains like normal gliding).
@export var glide_updraft_stamina_drain: float = 0.0
## Seconds between the curved gust arcs drawn under the player while gliding.
@export var glide_gust_interval: float = 0.09
## Gliding keeps momentum: horizontal speed ABOVE max_run_speed (from a gust or
## wind) only fades at this rate, px/s², instead of being pulled back by normal air
## control (~650 px/s²). Holding the opposite direction still brakes normally.
## 100 = a 200 px/s gust shove takes ~1.1 s to fade to run speed.
@export var glide_overspeed_deceleration: float = 100.0

@export_group("Gust")
## Length of the gust cone from the player's center, px (GAME_DESIGN.md §5.3: ~40;
## was 32, raised after play-testing enemies).
@export var gust_range: float = 40.0
## Half the cone's opening angle, degrees. 30 = a 60° wedge, 46 px wide at the far end.
@export var gust_cone_half_angle_degrees: float = 30.0
## Half-width of the cone right at the player, px, so things touching the body
## still get hit (a pure point would miss them).
@export var gust_cone_near_half_width: float = 3.0
## Seconds before the next gust is allowed. In the air the charges below are the
## real limit; this mostly stops ground gusts from being spammed every frame.
@export var gust_cooldown: float = 0.6
## Gust CHARGES per airtime: how many gusts you get between leaving the ground and
## landing again. Landing refills them (and a wind crystal tops them back up to this).
## Ground gusts are free: they don't spend a charge. 0 = unlimited (only the cooldown).
@export var gust_charges_per_airtime: int = 1
## A blue gust diamond sets your charges to this for the CURRENT airtime only:
## the next landing brings you back to gust_charges_per_airtime.
@export var gust_diamond_charges: int = 2
## Speed the player is shoved the OPPOSITE way of the gust, px/s.
@export var gust_recoil_speed: float = 120.0
## A DIAGONAL gust's sideways shove, as a share of gust_recoil_speed. Plain geometry
## (a unit-length diagonal) would give 0.71; more rewards the harder-to-aim diagonal
## with more reach. 1.0 = as hard sideways as a straight sideways gust.
@export_range(0.5, 1.5) var gust_diagonal_recoil_share: float = 1.0
## After a sideways (or diagonal) gust in mid-air, the shove's speed above
## max_run_speed is kept for a moment: for this long, s, it fades at only
## gust_overspeed_fade px/s² instead of being pulled back by air control (~650 px/s²).
## Landing ends it. The Glide state has its own rule (glide_overspeed_deceleration).
@export var gust_overspeed_time: float = 0.3
@export var gust_overspeed_fade: float = 150.0
## Gusting while standing on the ground: the recoil is multiplied by this (0.5 = half),
## so you can shove an enemy off a platform without shoving yourself off too.
@export_range(0.0, 1.0) var gust_ground_recoil_multiplier: float = 0.5
## Extra friction on that ground recoil, px/s². It brakes the shove during the
## recoil's input lock (normally nothing slows you then). 1200 stops a 100 px/s
## shove in ~0.08 s, after ~4 px.
@export var gust_ground_recoil_friction: float = 1200.0
## Upward speed from a down-gust in mid-air ("extra jump"), px/s.
## It SETS the vertical speed (doesn't add to it), so it works even mid-fall.
## 120 under full gravity rises ~8 px; holding jump (apex half-gravity) gives a bit more.
## Every mid-air down-gust lifts you: the gust charges are what limit it.
@export var gust_down_boost_speed: float = 120.0
## NEUTRAL gust (no arrow held): a burst in ALL directions instead of a cone.
## Radius of the circle it pushes, px. Things are pushed straight away from you.
@export var gust_neutral_radius: float = 28.0
## A neutral gust is an AIR BRAKE: for this long, gravity is off and your speed
## (both axes) slows toward a stop. Seconds.
@export var gust_neutral_brake_time: float = 0.2
## How hard the air brake slows you, px/s². 1500 stops a 300 px/s fall in 0.2 s.
@export var gust_neutral_brake_deceleration: float = 1500.0
## After the brake (mid-air only), you FLOAT on the air cushion for this long:
## light gravity, a slow fall cap, and full steering. Seconds.
@export var gust_neutral_float_time: float = 0.4
## Gravity multiplier while floating (0.25 = a quarter of normal gravity).
@export var gust_neutral_float_gravity_multiplier: float = 0.25
## Fall speed cap while floating, px/s. At the end of the float you leave at about
## this speed, so normal gravity picks up from a gentle drift, not a standstill drop.
@export var gust_neutral_float_max_fall_speed: float = 25.0
## After a gust, horizontal input is ignored this long so the recoil isn't cancelled
## at once. (Aiming right means holding Right, which would steer you back right.)
@export var gust_recoil_input_lock_time: float = 0.12
## Push strength handed to Pushable objects, px/s. Each object decides what to do with it.
@export var gust_push_strength: float = 160.0
## Small screen shake on every gust (GAME_DESIGN.md §9).
@export var gust_shake_strength: float = 1.0
@export var gust_shake_duration: float = 0.08
## Debug hitbox (F3): how long the cone flash stays visible after a gust, seconds.
@export var gust_debug_flash_time: float = 0.25
## Gust costs breath: when on, a gust spends gust_stamina_cost of the glide
## stamina bar. The bar refills on the ground, so ground gusts stay free;
## only airborne gusts compete with the glide. Off = gusts are free.
## Off by default since the gust charges (one per airtime) took over as the limit;
## kept as a toggle to compare.
@export var gust_uses_stamina: bool = false
## Stamina one gust costs, in glide-seconds (0.3 of 1.5 = 20% of the bar).
@export var gust_stamina_cost: float = 0.3
## Diagonal grace, REAL seconds: after aiming a diagonal (e.g. Down+Right), releasing
## one of its two keys still counts as the diagonal for this long. Fixes diagonals
## turning sideways because one key came up a moment before the gust key.
## Hold the remaining key longer than this to really switch to it. 0 = off.
@export var gust_diagonal_grace_time: float = 0.12

@export_group("Gust: Hold to Aim (experimental)")
## EXPERIMENT: when on, pressing gust slows time and the arrows only AIM (you don't
## move); releasing gust fires. A quick tap fires almost at once, like the normal
## gust. Off = the gust fires the instant you press it. Toggle live to compare.
@export var gust_hold_to_aim: bool = true
## Game speed while aiming (0.25 = quarter speed).
@export_range(0.05, 1.0) var gust_aim_time_scale: float = 0.25
## The gust fires by itself after this many REAL seconds of aiming, so holding Z
## can't be used to hang in slow motion.
@export var gust_aim_max_real_time: float = 0.4

@export_group("Feel: squash & dust")
## Body scale at the start of a jump or wall jump (x = width, y = height). Tall and
## thin reads as "launching". Eases back to (1, 1) over squash_recover_time.
@export var jump_squash: Vector2 = Vector2(0.7, 1.35)
## Body scale on the HARDEST landing (see land_squash_full_speed): short and wide.
## Softer landings use a blend between (1, 1) and this.
@export var land_squash: Vector2 = Vector2(1.45, 0.6)
## Landings slower than this get no squash and no dust, px/s. Keeps small hops
## and stepping down a tile quiet.
@export var land_effect_min_speed: float = 90.0
## Landing at this fall speed (or faster) gets the full land_squash, px/s.
## max_fall_speed is a natural choice.
@export var land_squash_full_speed: float = 300.0
## Body scale the moment you reappear after dying: a quick "pop" in.
@export var respawn_squash: Vector2 = Vector2(0.5, 1.5)
## How long the body takes to spring back to normal after any squash, seconds.
@export var squash_recover_time: float = 0.14
## Dust specks kicked up by a jump or wall jump.
@export var jump_dust_count: int = 4
## Dust specks per side on the hardest landing (fewer on softer ones).
@export var land_dust_count: int = 5

@export_group("Death & rooms")
## How long the death effect plays before the player reappears at the spawn, seconds.
## Short on purpose: dying should cost almost nothing (design pillar "fail fast").
@export var death_respawn_delay: float = 0.3
## On respawn the screen flashes white and fades out over this long, seconds.
## Makes the cut from "dead" to "back at the spawn" read as one clean beat. 0 = off.
@export var respawn_flash_time: float = 0.15
## How long the camera takes to slide to a new room, seconds. The player is frozen
## during the slide.
@export var room_transition_time: float = 0.3
## Upward speed given when entering a room ABOVE (like Celeste), px/s. Without it you
## would arrive at the very top of your jump and drop straight back into the old room.
@export var room_transition_up_boost: float = -160.0

@export_group("Assists")
## How many pixels we may nudge sideways to slip around a ceiling corner
## instead of bonking our head on it.
@export var corner_correction_pixels: int = 4

class_name FireFxBudget
extends RefCounted
## FireFxBudget (Stage F13, Fire_bending.md §9.4): the cap on fire particles. A room
## full of burning grass throws sparks, licks and smoke from every flame; past a
## point they stop adding to the look and only cost frames. So fire effects degrade
## gracefully: FEWER EMBERS FIRST, then less smoke.
##
## It counts what's alive right now (static counters, one for the whole game):
##   - embers: sparks from EmberEmitter.burst and licks torn off FlameTongues
##   - smoke:  SmokePuff.spawn puffs and FlameTongue smoke wisps
## Whoever makes them asks first: get_ember_share() / get_smoke_share() say what
## share (0..1) of what they wanted to make they may make now.
##
##   alive < fire_fx_soft_cap               everything (share 1)
##   soft cap .. hard cap                   embers fall to fire_fx_min_share; smoke full
##   past fire_fx_hard_cap                  embers stay low; smoke falls too
##
## Streams that ARE the effect (the fireball's trail, the jet plume) don't ask: a
## fireball without its trail would look broken. Only extras are cut.
##
## Counting: add_embers / add_smoke when made, the negative amount when they die
## (a burst when its emitter finishes, a tongue's wisp when it fades or the tongue
## is freed). Room changes don't reset it: everything that counted itself also
## uncounts itself when it goes.

static var fire_tuning: FireTuning = preload("res://resources/fire_tuning.tres")
static var live_embers: int = 0
static var live_smoke: int = 0


static func add_embers(count: int) -> void:
	live_embers = maxi(live_embers + count, 0)


static func add_smoke(count: int) -> void:
	live_smoke = maxi(live_smoke + count, 0)


## Every fire particle alive right now.
static func get_live_count() -> int:
	return live_embers + live_smoke


## The share of the embers asked for that may be made now (1 below the soft cap,
## down to fire_fx_min_share at the hard cap and past it).
static func get_ember_share() -> float:
	var soft_cap: float = float(fire_tuning.fire_fx_soft_cap)
	var hard_cap: float = maxf(float(fire_tuning.fire_fx_hard_cap), soft_cap + 1.0)
	var over: float = clampf((get_live_count() - soft_cap) / (hard_cap - soft_cap), 0.0, 1.0)
	return lerpf(1.0, fire_tuning.fire_fx_min_share, over)


## The share of the smoke asked for that may be made now: full until the hard cap,
## then down to fire_fx_min_share by twice the hard cap.
static func get_smoke_share() -> float:
	var hard_cap: float = maxf(float(fire_tuning.fire_fx_hard_cap), 1.0)
	var over: float = clampf((get_live_count() - hard_cap) / hard_cap, 0.0, 1.0)
	return lerpf(1.0, fire_tuning.fire_fx_min_share, over)


## How many of `wanted` embers to make now (at least 1: a burst never vanishes).
static func scale_embers(wanted: int) -> int:
	return maxi(roundi(wanted * get_ember_share()), 1)


## How many of `wanted` smoke particles to make now (at least 1).
static func scale_smoke(wanted: int) -> int:
	return maxi(roundi(wanted * get_smoke_share()), 1)


## Forget everything (tests).
static func clear() -> void:
	live_embers = 0
	live_smoke = 0

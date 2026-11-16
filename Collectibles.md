# Collectibles — spec v1

What a level holds besides the way through it. Three kinds, each with one job:

| Kind | Job | Needed to finish? | Kept after death? | Saved between sittings? |
|---|---|---|---|---|
| **Key orb** (hub keys) | opens a hub's Grand door | yes, where a hub uses it | yes | no (per run) |
| **Relic shard** | the "100%" collectible: 4 per relic, a relic per element | no | only once *secured* | yes (Story Mode) |
| **Golden feather** | the no-death challenge: 1 per level, optional | no | no: a death breaks it | yes (Story Mode) |

They must read apart at a glance: keys are ROUND glowing orbs, shards are ANGULAR
crystal pieces, the feather is the only GOLD thing in the game.

## 1. Key orbs, Key lights, Grand door (built)

A colored orb collected once per run lights every Key light of its color, in any
room; a Grand door linked to the lights (Link Mode: All) opens when all are lit.
Matched by color, not by editor links (links only reach inside one room). A light
lights when the player next walks into its room, a beat later, so the door opens in
front of the player. Code: `key_colors.gd`, `key_orb.gd`, `key_light.gd`,
`grand_door.gd` in `scenes/objects/`.

## 2. Relic shards

### 2.1 Decided
- **Every element has its own relic**, broken into exactly 4 shards. A shard is a
  pair: its **element** (which relic: Air, Earth, Fire, Water, also its color) and
  its **slot** (1–4, which quarter). Changed after the first play-test, where shards
  were counted by slot only and an Air slot 1 and a Water slot 1 overwrote each other.
- A level holds one or more relics: normally one, of its chapter's element; mixed
  levels may hold several (e.g. a Water relic whose shards need water to reach next
  to a Fire relic). Each relic in a level has all 4 of its slots placed, once each:
  the editor warns (play-test warnings) about a slot used twice or a relic missing
  slots. "100%" for a level = every relic in it complete.
- **The four kinds of hiding place** (a design guide, not enforced): 1 precision
  (a hard optional route), 2 secret (hidden chamber, fake wall), 3 element puzzle,
  4 off the beaten path (off-screen, another depth, past the exit).
- **The strawberry rule.** Touching a shard makes it FOLLOW the player. It is
  SECURED (counted) once the player has stood on the ground for
  `RelicShard.SECURE_GROUND_TIME` (0.25 s) without dying. Dying while it follows: it
  flies back home and can be taken again. The risk is the reward.
- A secured shard stays secured for the run (deaths and R don't touch it). In a
  Story Mode run it is saved AT ONCE (StoryProgress), so quitting keeps it.
- A shard saved in an earlier sitting shows as a **ghost** (see-through). It can be
  taken again (it plays the same), but adds nothing new.
- Several followers trail in a chain behind the pack, each behind the one before.
- **The look**: each shard is one QUARTER of its element's relic, a round medallion
  broken in four by zigzag cracks (slot 1 top left, 2 top right, 3 bottom right,
  4 bottom left), in its element's color. `RelicPainter` draws both the quarters
  and the whole relic, so the pieces visibly fit together.
- **On the grid**: key orbs, key lights, shards and the feather are 2x2 tiles; the
  editor snaps them to tile corners (key lights stand on the floor).

### 2.2 Shown where
- The pause menu: the level's relics beside the buttons (`RelicView`), one page per
  element that has shards in the level (or found ones), Left / Right to flip:
  the relic's name, the medallion with found quarters in color and missing ones
  dark, `2/4` (or `complete`, with a gem in the middle), and `< 1/3 >`. Hidden in
  levels with no shards.
- Story Mode's level-complete card and level select: one entry per relic,
  `Air relic` when complete, else `Water 2/4`; then `Gold`.
- The non-story end screen (play-tests, chapters): the same, for this run.

## 3. Golden feather

### 3.1 Decided
- One per level at most, optional, placed by the designer (normally in the first
  room).
- **It can only be taken with zero deaths this run** (R counts as a death, like
  Celeste's Retry). After a death it shows dim, untouchable: "gone for this run".
  So wherever it is placed, carrying it to the Goal means a deathless level.
- Taken, it follows the player like a shard (first in the chain), never "secured".
- **A death while carrying it breaks it**: it shatters into gold flakes and is dim
  for the rest of the run. Retry by starting the level over (Story level select,
  or the editor's play-test).
- Reaching the Goal while carrying it: the level is **gold** (StoryProgress,
  shown as `Gold` on the card and the level select).
- It does not count toward the relic: 100% = 4 shards; gold is a stamp on top.

## 4. Code map
- `scenes/objects/trailing_pickup.gd` (`TrailingPickup`): the shared part of shards
  and the feather: home / following / gone, the chain behind the pack, what a death
  does (overridden), the ghost look flag.
- `scenes/objects/relic_shard.gd` (+ `.tscn`): slot, element, the securing rule.
- `scenes/objects/golden_feather.gd` (+ `.tscn`): zero-death pickup, shatter, gold.
- `GameState`: `secured_shards` (slot -> element), `is_carrying_golden`; cleared by
  `reset_run()`.
- `scenes/objects/relic_painter.gd` (`RelicPainter`): draws a quarter and the whole relic.
- `scenes/ui/relic_view.gd` (`RelicView`): the relic in the pause menu.
- `GameState.secured_shards`: element -> Array of secured slots (`secure_shard`,
  `has_shard`, `count_shards`).
- `StoryProgress`: per level `relic_shards` (element -> Array of slots) and `golden`.
- `LevelEditor.get_relic_warnings()`: duplicate slots and incomplete relics.
- Palette: Crystals tab, "Relic shard" and "Golden feather".

## 5. Ideas parking lot
(Built since: the pause menu's "Restart level", a fresh run of the whole level, for golden attempts.)
- A HUD line that flashes "2/4" for a moment when a shard is secured.
- A relic gallery page in the main menu: every relic found across all levels.
- Per-level relic names and a line of lore when one is completed.

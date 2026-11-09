# State machines in the game

A map of every place the game keeps "what's happening now" state, so a person or an agent can find it, read it and
change it safely. Written Nov 8, 2026 from a sweep of `scripts/` and `scenes/` (not the builders or tests).

## The rule of thumb

- One thing with several modes keeps them in **one `enum State` and one `state` variable** (like `races.gd`,
  `skate_runs.gd`, `crocodillo.gd`). Most of the game already does this.
- Something **many systems share** (the player's controls, the mouse, pausing) must never be a single `true/false`
  that anyone can set: one system finishing would undo another's. Give each system its own named hold instead,
  the way the controls work now (below).
- Small flags inside one script that guard one effect (`_running`, `_arriving`, `revealing`) are fine as they are.

## Shared between systems

| What | Where | How it works now |
|---|---|---|
| The player's controls | `scenes/player/player.gd` `lock_input(who)`, `unlock_input(who)`, `input_locks()`; `Game.hold_controls(who, on)` | **Named holds.** 13 systems hold them: `dialogue`, `race`, `skate_run`, `creator`, `zipline`, `mothership`, `hayride`, `skate_lesson`, `apple_bobbing`, `lab`, `first_night_arrival`, `oak_reveal`, and `legacy` (the old `input_locked = true`, for tools). `input_locked` is read-only in spirit: it's true while anyone holds them. Setting it false lets go for everyone (tools and tests only). `input_lock_changed(locked)` fires when it flips. Test: `tools/test_controls_lock.gd`. |
| Pausing the game | `get_tree().paused` in `bed.gd`, `pause_menu.gd`, `player_menu.gd`, `shop.gd` | Works: each one refuses to open while the game's already paused, so only one ever owns it. |
| The mouse | `Input.mouse_mode` in `spring_arm_3d.gd`, `bed.gd`, `creator.gd`, `dialogue.gd`, `pause_menu.gd`, `player_menu.gd`, `shop.gd`, `skate_lesson.gd` | **Still a single switch.** The menus are guarded by the pause, but `dialogue.gd` (choices) and `skate_lesson.gd` set it without that guard, so one can capture the mouse while the other wants it free. Next candidate for named holds. |
| Being carried | `carried` on the player: `zipline.gd`, `mothership.gd`, `festival_green.gd` (hayride) | Fine for now: each sets and clears its own, and they can't happen together. If a fourth ride appears, give it named holds too. |
| The Void's clock | `Clock.running`, only set by `portals.gd` (with `_froze_clock` so it only restarts what it stopped) | Fine: one owner. |

## Inside one system (already explicit)

`enum State` / `state`: `races.gd` (IDLE, INTRO, COUNTDOWN, RACING, RESULTS), `skate_runs.gd` (IDLE, COUNTDOWN,
RUNNING, LAST_COMBO, RESULTS), `scenes/player/skate.gd` (ROLL, AIR, GRIND, BAIL), `mothership.gd` (CRUISING,
COMING, BEAMING_UP, PILOTED, BEAMING_DOWN), `crocodillo.gd` (WANDER, STALK, CURL, ROLL, DIZZY), `time_goblin.gd`
(WANDER, CHASE, FLEE, DIZZY), `chaos_giant.gd` (WALK, BROOD, CHAOS), `chaos_fight.gd` (`Step`: IDLE, BURSTS, OPEN,
MINIONS, WIND, DAZED, GONE, plus `phase` 1-3 for the fight's thirds), `mini_saucer.gd` (FLY, HOVER, LANDED, TRICK),
`little_alien.gd` (IDLE, MOVE, WAVE), `wanderer.gd` (IDLE, MOVE, REACT), `burrower.gd` (UP, SINKING, UNDER, RISING;
an unnamed enum).

Data-driven steps (the content files are the state machine): `quests.gd` (`state[id].step`, from
`quests/*.json`), `first_night.gd` (`step()`, the First Night's quest steps), `skate_lesson.gd` (`_step` into
`STEPS`).

## Implicit, inside one system (left as they are)

These are groups of flags that together make a mode. Each is private to its script and consistent today, so
turning them into enums would be churn with no change for players. If one of them grows or gets a bug, make it an
`enum State` first.

- `portals.gd`: a trip is `here` ("" in the Void), `_quaking`, `_warned` (time nearly up), `_pulling` (leaving).
- `clock.gd`: `_in_shift` remembers the last frame's `in_shift()` to spot the Shift starting and ending;
  `_pulling` stops a second pull home.
- `scenes/player/skate.gd`: in `State.AIR`, rocket flight is `flying`, `_flew`, `_fly_armed`; hovering is `on_water`.
- `routine.gd`: `_travelling`, `_present` (away indoors or not), `_ready_to_go`, `_jumped`.
- `dialogue.gd`: `_typing`, `_choosing`, the queue and the panel showing.
- `star_popper.gd`: `aiming`, `_on_target`, charging.
- `disco_ball.gd`: `_flying`, `_bounced`.
- Cutscene guards: `lab.gd _running`, `first_night.gd _arriving`, `humming_oak.gd revealing`.

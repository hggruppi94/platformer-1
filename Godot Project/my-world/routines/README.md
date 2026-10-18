# Routines: where people are during the day

One schedule per character, named after their `character_id` (the same one as their dialogue file): `dash.json`,
`rex.json`, `rook.json`, `bramble.json`, `pip.json`, `green_man.json`. `scripts/routine.gd` (the `Routine` node under
each character in `scenes/town/characters.tscn`) follows it, using the game clock.

```json
{
  "speed": 1.3,
  "move_anim": "walk",
  "blocks": [
    {"at": "06:30", "place": "gardens", "do": "wander", "radius": 6, "label": "gardening"},
    {"at": "20:30", "place": "greenhouse", "do": "away", "label": "asleep"}
  ]
}
```

**Blocks** start at their `at` time (24-hour clock, `"18:30"`) and last until the next one starts. The last block runs on
past midnight until the first one of the next day. When a block starts and Nina is near enough to see, they walk there
along the town's paths; otherwise (or after sleeping, loading, or coming out of a building) they're simply there.

| `do` | What they do at `place` |
| --- | --- |
| `idle` | stand there. `"face": [x, z]` turns them toward a spot |
| `wander` | stroll about within `radius` metres (Rex and Rook use their own wandering, so Rook still barks at Nina) |
| `nap` | doze on the spot (slow breathing) |
| `patrol` | go round the places in `route` in turn, stopping `pause` seconds at each (Dash's bike rides, Pip's lamp walks) |
| `follow` | tag along behind someone: `"who": "rex"`. If they're away, wait at `place` |
| `away` | not in town (asleep at home, inside). No one to see or talk to |

**`label`** names what they're up to (`"riding"`, `"campaigning"`). Dialogue lines can depend on it:
`"when": {"activity": "riding"}`, or on the place: `"when": {"place": "town_hall"}` (see `res://dialogue/README.md`).

**Top of the file:** `speed` (metres a second), `move_anim` (the animation for walking: Rex's is `skate`),
`follow_anim` (for running to catch up), `rides: true` (Dash: on his bike whenever he's moving).

## Places

`places.json` holds the named points of the town (doorsteps, the boardwalk, the gardens up the ramp...) and the links
people can walk along between them (`[x, z]` in metres: +x is east, -z is north toward the castle). A `place` can be
any point. People always walk along links, so to reach somewhere new, add a point and link it to a nearby one.
After changing it, run the checker. It tells you what's underfoot at every point and whether any link goes through a
building or prop:

    godot --headless --path "Godot Project/my-world" --script res://tools/check_paths.gd

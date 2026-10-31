# Routines: where people are during the day

One schedule per character, named after their `character_id` (the same one as their dialogue file): `dash.json`,
`rex.json`, `rook.json`, `bramble.json`, `pip.json`, `green_man.json`, `nina.json`, `mr_palmer.json`. `scripts/routine.gd` (the `Routine` node under
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

## People on Earth

The Earth town's people (`scenes/earth/earth.tscn`, made by `tools/build_earth.gd`) have files here too, with
`"world": "earth"` at the top: `palmer_earth`, `ivy`, `theo`, `gus`, `dottie`, `barnaby`, `marigold`, `poppy`, `otis`,
`wren`, `hank`, `kip`, `lionel`, `juniper`, `ozzie`, `nina_earth`, `prue` and `bruno`. They follow Earth's clock (which
always runs: an Earth hour is a real minute, so a walk across town takes an hour or two of their day) and walk Earth's
paths, `earth_places.json`. Don't edit that one: the builder writes it from the buildings (`_write_places()`), with
places like `diner`, `bakery` (inside) and `bakery_door`, `main_46` (Main Street), `maple_w40` (Maple Lane), each
house's gate (`palmer_house`), `gazebo`, `old_oak`, `pond_path`, `skate_yard`, `school` and the Blastoffs' bedrooms
(`nina_room`). A point there can have a third number, the floor's height, for places indoors or up steps.
`tools/test_townsfolk.gd` checks them all.

**The Autumn Festival** (Saturday evenings, 5 to 10 PM: `scripts/festival.gd`): a file can have a `"festival"` list of
blocks next to `"blocks"`, in the same shape. While the festival's on they take over from the day's blocks, like a
quest's override, then the day carries on. The festival's points are `fest_hay`, `fest_apples`, `fest_treats`,
`fest_pies`, `fest_lanterns` and `fest_cider` on a ring round the gazebo, and `fest_<spot>_stall` beside each stall for
whoever runs it (Poppy, Gus, Dottie, Hank, Miss Marigold). Kip calls the hayride from `inn`; Barnaby plays at `gazebo`.

## Places

`places.json` holds the named points of the town (doorsteps, the boardwalk, the gardens up the ramp...) and the links
people can walk along between them (`[x, z]` in metres: +x is east, -z is north toward the castle). A `place` can be
any point. People always walk along links, so to reach somewhere new, add a point and link it to a nearby one.
After changing it, run the checker. It tells you what's underfoot at every point and whether any link goes through a
building or prop:

    godot --headless --path "Godot Project/my-world" --script res://tools/check_paths.gd

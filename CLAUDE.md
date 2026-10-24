# Galaxity: Sofi's game

A Godot 4.7 3D platformer built by Hayden from Sofi's characters and drawings. The player makes their own hero in the
character creator (since Oct 23, 2026: before that the player was Nina, who is now a friend in town). They live in
**Galaxity**, the alien town. During the Shift (midnight to 1 AM, game time) a portal
opens to a small Earth town.

Read this first in every session so each iteration builds on the last one and doesn't start over.

## Where things are

- `Godot Project/my-world/`: the Godot project (`project.godot`)
  - `tools/build_*.gd`: **builders**. They generate the scenes, so never hand-edit a built `.tscn`. Change the
    builder and re-run it.
    - `build_town.gd` → `scenes/town/town.tscn`, plus the terrain, castle and garden `.res` files. Galaxity: the
      lake, Market, homes, Bojnice castle school on its hill, Observatory, Secret Gardens, Cloud Nest, mountains,
      green sky with cream cloud streaks, mothership.
    - `build_school.gd` → `scenes/school/school.tscn`, the castle school interior from Sofi's floor plans
      (`source_art/reference/world/school - *.jpg`). It has 3 floors, the atrium, the Entrance Garden with its
      greenhouse and vegetable beds, and the 3rd-floor window that looks out on the town's real mountains.
    - `build_earth.gd` → `scenes/earth/earth.tscn`, the Earth town (Stars Hollow style): the town green and gazebo,
      shops, the barn dance studio, and the sky's clouds, stars and moon.
    - `build_interiors.gd` (domed rooms: cafe, aquarium, restaurant, Nina's house), `build_scary_world.gd`, and
      `build_centipede/crocodillo/gloop/mothership.gd` for creatures and vehicles.
    - `theme.gd`: the shared look. `THEME = "alien"` maps every colour into the alien palette (oranges → teal,
      reds → magenta, greens → acid lime, whites → lavender). Builders call `tint()` / `light()` / `backdrop()`.
  - `scripts/`: game logic. Autoloads include `Clock` (`clock.gd`, the time of day, the Shift and Earth's own
    clock), `Game`, `Dialogue` and `Quests`. `day_night.gd` handles Galaxity's sky and lamps, and `earth_world.gd`
    handles Earth's full day and night.
  - `dialogue/*.json`, `quests/*.json`, `routines/`, `shop/`: content, each with its own README.
  - `tools/test_*.gd`: tests. `tools/capture_*.gd`: screenshot tools.
- `source_art/`: Blender characters and Sofi's reference pictures (characters, enemies, world, floor plans). These
  are the source of truth for how things look.
- `previews/`: screenshots of recent work, one folder per feature.

## How to work

- **Godot:** `C:\Users\hggru\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- **Build:** `godot --headless --path "Godot Project/my-world" --script res://tools/build_<x>.gd`
  - Rebuilding re-rolls every node's `unique_id`. If a builder's output didn't really change (for example the
    town, after a refactor), revert that `.tscn` instead of committing thousands of ID-only lines.
- **Test:** `godot --headless --path "Godot Project/my-world" --script res://tools/test_<x>.gd`
  - Usual set: layout, map, doors, walk_through, earth, dialogue, plus whatever the change touches (routines,
    quests, town_quests, shop, crocodillo, mothership, scary_world, clock, quick_fixes).
  - Some tests have two runs: run the same test again with `-- --check-load` straight after, before running any
    other test.
  - A test that passes on one run and fails the next usually depends on Hayden's save (tests start from whatever
    time it holds). Find the cause rather than re-running it.
- **Previews:** run `godot --path ... --script res://tools/capture_<x>.gd -- <folder>`. This needs a window, so no
  `--headless`. Look at the shots, then copy them into `previews/<feature>/`.
- **Hayden's save** (`%APPDATA%\Godot\app_userdata\MyWorld\save.json`) must never be lost. Tests and capture tools
  put it aside and restore it. New tools must do the same (copy the backup pattern from an existing one).
- **Git:** commit and push straight to `main`. LFS handles png/jpg/blend/glb. Write commit messages in plain
  language for a kid's game. Don't commit the editor's `project.godot` section shuffle or stray `.uid` files from
  other work.
- Comments in code are full sentences that explain *why*, matching the surrounding style.

## Names and story

- The town and world is **Galaxity** (it was called "Galactopia" until Oct 2026, so don't bring that name back).
- Mr. Palmer is the mayor (on Earth he's just plain old Mr. Palmer). Rex is the skating husky who wants to be mayor,
  and Dash is his twin. The other characters are Bramble, Pip, Rook (says woof), Ivy and Theo (Earth), Madame
  Celeste (Earth dance studio) and the lonely centipede (Scary World).
- In the show, kids are people on Earth and creatures in Galaxity. Nina keeps her Galaxity look on Earth for now.
- The player's hero is whoever the player makes; dialogue never assumes their name or gender (use `{player}`, `{they}`).

## Log (newest first)

- 2026-10-23: The Astronaut, from Sofi's drawing (`source_art/reference/Astronaut.jpg`, `tools/build_astronaut.py`):
  white suit, black visor, antenna, grey backpack and hoses, chest controls, the big red button, US flag patch, blue
  gloves and grey boots, with a floaty idle and a bouncy moon walk. They stand by the Mothership Pad
  (`characters.tscn`, no routine yet) and talk (`dialogue/astronaut.json`): an Earth astronaut who flew up to see
  the mothership and landed in Galaxity (`tools/capture_astronaut.gd`, `previews/astronaut/`).
- 2026-10-23: Create-your-own hero, RPG style. The player is their own hero (`Game.hero`, `scripts/hero.gd`): a body to
  start from (Sofi's hippo, kid, dog-kid, moth, cow or alien bodies), 11 hairstyles (`scripts/hairstyles.gd`, fitted to
  each head), height, head size and build (`scripts/body_shape.gd`), 20-colour swatches for fur, hair, eyes, accent,
  blush, brows and their own top/bottoms/shoes, body extras on or off, a name and pronouns. The creator
  (`scripts/creator.gd`, autoload `Creator`) opens on a new game (and once for a save from before heroes, whose outfit
  carries over), and from the wardrobe. Dialogue uses `{player}`, `{they}`, `{them}`, `{their}` (and capitalised).
  The player lives in My House (`build_interiors.gd _my_house`, the main scene; was "Empty Home"), decorated at its
  Decorate spot (`scripts/home_decor.gd`, `Game.home`: colours and six furniture spots). Nina lives in her own house
  as a friend with a routine (`routines/nina.json`, `dialogue/nina.json`). Player rider id is "hero"
  (`tools/test_creator.gd`, `previews/creator/`).
- 2026-10-23: Character customization and friends' outfits. Everyone has an outfit (`Game.outfits[who]`) and looks
  (`Game.looks[who]`: fur, hair, eyes, an accent like Nina's bow or Dash's cap, blush, from `Clothes.PALETTE`). The
  wardrobe has a "Who" row (Nina, Dash, Rook, Pip, Bramble, the Green Man, Mr. Palmer, Rex) and colour arrows. Clothes
  are made on Nina and fitted to each body (`Clothes.fit_of()`: eyes, head top, neck, chest, hips, hands, feet measured
  from each model); Rex only wears hats. Friends wear their outfits in town (`routine.gd _dress()`) and when skating.
  Mr. Palmer has no routine in town, so only his skating self is dressed (`previews/looks/`).
- 2026-10-23: Clothes, head to toe (`scripts/clothes.gd`). Eight slots (head, face, neck, top, bottoms, feet, hands,
  back), one thing worn in each (`Game.outfit`, saved; `Game.hat` is now the head slot, and old saves' hats carry
  over). Tops, bottoms and shoes restyle Nina's own shirt, overalls and shoes (colours and patterns); the rest are
  pieces fixed to her bones so they move with her; back pieces replace her backpack. 22 clothes are sold at the
  Clothing Boutique (now open, `build_interiors.gd`, the "Boutique" stall in `shop/items.json`), and the "Wardrobe"
  (her house, and the Boutique's mirror) swaps them with arrows. Only Nina wears them, not friends skating in her
  place (`tools/test_clothes.gd`, `previews/clothes/`).
- 2026-10-23: Skating, step 4 (everyone rides). The Skaters' Corner at each park (`scripts/rider_select.gd`, Interact)
  swaps who's skating: Nina (board), Dash (BMX), Rex and Rook (four-paw roller skates), Pip (hover wings, glides
  while Jump is held), Bramble (scooter), the Green Man (leaf board) and Mr. Palmer (the Mayor-mobile). Each has
  their own feel and trick names in `scripts/rides.gd`; rides are built by `scenes/player/ride_kit.gd`, and
  `Player.set_rider()` swaps the model and hides that character's town self. Stepping off makes you Nina again
  (`previews/riders/`).
- 2026-10-23: Skating, step 3 (the town). The Skate Park (`_skate_park()` in `build_town.gd`) has real quarter pipes,
  a funbox with a rail, a flat rail and a ledge, built from `tools/skate_kit.gd` (shared with the Practice Park). The
  benches in the Market Square and the housing park are grindable (`grind_edge()`). Seven goals pay sparkles once
  (`scripts/skate_goals.gd`: S-K-A-T-E letters, combo, grind, manual, 540, special, park score), saved as
  `skate_goal_*` / `skate_letter_*` Dialogue flags, with a goals board (`tools/test_skate_park.gd`,
  `previews/skate_park/`).
- 2026-10-23: Skating, step 2 (tricks). `scenes/player/skate_tricks.gd`: flips (Flip + direction), held grabs
  (Grab + direction), spins, grind types (Grind + direction: 50-50, 5-0, Nosegrind, Boardslide, Lipslide), manuals
  (forward then back quickly), combos that multiply and pay out after landing, repeats worth half, bails lose the
  combo, a special meter and Nina's special, the Galaxy Twirl (Flip + Grab with a full meter). Each ride's trick
  names live in its "tricks" in `scripts/rides.gd`. Score and combo HUD: `scripts/skate_hud.gd`.
- 2026-10-23: Skating, step 1 (the feel). `scenes/player/skate.gd` takes over Nina's physics on the board: push and
  carve, ramps that really pull on her, a hold-to-charge ollie, vert airs off steep quarter pipes, grinds on any
  `GrindRail` (`scripts/grind_rail.gd`) with a balance meter, and comedy bails with no damage. Ride feel numbers live
  in `scripts/rides.gd` so other characters can get their own rides. Practice Park: `tools/build_skate_test.gd` →
  `scenes/skate/test_park.tscn` (`tools/test_skate.gd`, `previews/skating/`). Controls: Space/A ollie, L/Y grind,
  J/X flip, K/B grab (flip and grab are mapped for step 2); pad Y only steps off the board when no rail is in reach.
- 2026-10-23: Nina can fly the mothership. The Mothership Pad (east of the Observatory path) calls it down and its
  tractor beam lifts her into the cockpit. Move keys fly it the way the camera faces, Jump climbs, Roll sinks, and
  Interact beams her down to the ground below. A save made while flying puts her back on the pad
  (`tools/test_mothership.gd`, `previews/mothership/`).
- 2026-10-23: The portal lets Nina through by the clock, not by its fade-in. It used to let her through for a
  moment after the Shift ended or after loading a save made during the Shift.
- 2026-10-23: Renamed Galactopia → Galaxity. Earth got a full day/night sky (clouds, sunrise and sunset, stars,
  moon). The school's Entrance Garden got a greenhouse, vegetable beds, benches and a rose arch. The 3rd-floor
  window now shows the town's real mountains.
- 2026-10-22: Earth barn dance studio. Lilac fairytale Bojnice castle, the Crocodillo enemy, the green sky and the
  mothership (flies a loop; piloting it comes later). Castle school is Bojnice at real size.
- Earlier: Mr. Palmer, Earth town, Scary World, sparkles and shopping, town map, Pip and Bramble quests, Rex's
  campaign, the new town layout, walk-through effects, daily routines, dialogue, the clock, the Shift and sleeping.

## Open ideas / next up

- Skating (Hayden, Oct 23): THPS-style, every character playable with their own ride and moves, on controller and
  keyboard. Steps 1 to 4 are in (see the log). Bruno (SK8 beanie) isn't in the game yet, so he has no ride. Later: gap bonuses, more grindable spots round town (boardwalk edges, castle steps), timed runs.
- Clothes (Hayden, Oct 23): more clothes later. Mr. Palmer's town self could wear his outfit too.
- Add new requests here as they come in, and move them to the log when they're done.

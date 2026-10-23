# Galaxity: Sofi's game

A Godot 4.7 3D platformer built by Hayden from Sofi's characters and drawings. Nina is the
player character. She lives in **Galaxity**, the alien town. During the Shift (midnight to 1 AM, game time) a portal
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
    quests, town_quests, shop, crocodillo, scary_world, clock, quick_fixes).
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

## Log (newest first)

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

- Piloting the mothership (it already goes through `fly()` with a cockpit seat).
- Add new requests here as they come in, and move them to the log when they're done.

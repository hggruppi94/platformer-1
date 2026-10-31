# Galaxity: Sofi's game

A Godot 4.7 3D platformer built by Hayden from Sofi's characters and drawings. The player makes their own hero in the
character creator (since Oct 23, 2026: before that the player was Nina, who is now a friend in town). They live on
**Earth**, in a small Stars Hollow style town. During the Shift (midnight to 1 AM, Earth time) the portal by the old
oak opens to **Galaxity**, the alien town, and that one Earth hour lasts a whole Galaxity day (7 AM to 7 AM). At 1 AM
the portal pulls them home to Earth (since Oct 28, 2026: before that they lived in Galaxity and visited Earth).

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
    - `build_earth.gd` → `scenes/earth/earth.tscn`, the Earth town (Stars Hollow style) and the main scene: the
      player's house with their bed (`My Home`, new games start at `HomeSpawn`), the town green and gazebo, shops,
      the barn dance studio, the portal to Galaxity by the old oak, and the sky's clouds, stars and moon.
    - `build_interiors.gd` (domed rooms: cafe, aquarium, restaurant, Nina's house), `build_scary_world.gd`, and
      `build_centipede/crocodillo/gloop/mothership.gd` for creatures and vehicles.
    - `theme.gd`: the shared look. `THEME = "alien"` maps every colour into the alien palette (oranges → teal,
      reds → magenta, greens → acid lime, whites → lavender). Builders call `tint()` / `light()` / `backdrop()`.
  - `scripts/`: game logic. Autoloads include `Clock` (`clock.gd`: Earth's clock, which always runs, Galaxity's,
    which only runs in the Shift, and the Shift), `Game`, `Dialogue` and `Quests`. `day_night.gd` handles Galaxity's sky and lamps, and `earth_world.gd`
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
    quests, town_quests, shop, crocodillo, mothership, scary_world, clock, quick_fixes, player_menu).
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
- In the show, kids are people on Earth and creatures in Galaxity. Since Oct 31, 2026 Nina is human on Earth (red bob, red
  bow, black turtleneck: `nina_earth`) and stays her alien self in Galaxity. Prue and Bruno's Earth looks are placeholders.
- The player's hero is whoever the player makes; dialogue never assumes their name or gender (use `{player}`, `{they}`).

## Log (newest first)

- 2026-10-31: Rolling hills round Stars Hollow (Hayden: "add more rolling hills"). `EarthLand.ROLLS` is 17 round humps
  (cosine bumps, 2 to 4.8 m high, overlapping into rolls, slopes at most about 24 degrees, so a board rolls up and over)
  in the open ground nothing is built on: the east fields past the Corner Market and the skate yard, south of the dance
  studio, the meadow north of the creek path, west of the creek (by the hill and past Maple Lane's west end) and behind
  Maple Lane's back gardens. Trees and fallen leaves follow them (`_on_ground()`); streets, paths, buildings and routine
  points stay flat, and `earth_places.json` didn't change. Past the walls the flat "Far Fields" boxes are gone:
  `EarthLand.country()` rolls the countryside up from flat at the ground's edge to about 30 m of hills, autumn fields in
  patches and woods on the tops, as a mesh made at load with no collision (`_build_country()`). The map draws each roll
  as a soft hump (`rolls` in `ui/earth_map.json`). `test_earth` checks each roll is there, none is too steep, nothing
  built touches one, and the countryside. `tools/capture_earth_hills.gd` (shots in the project files under
  world/previews/earth_hills, made in the cloud).
- 2026-10-31: Stars Hollow build-out, phase 3: things to do. Earth has days of the week now (`Clock.earth_day()`,
  `Clock.weekday()`: day 1 is a Friday; the HUD says "Earth, Monday"). Most of it is added at play time, so
  `earth.tscn` wasn't rebuilt (only `routines/earth_places.json`, for the festival's points).
  - **Notice board** (`scripts/earth_jobs.gd`, autoload `EarthJobs`): Galaxity's request board with Earth's jobs. It
    extends `requests.gd`, which now has hooks for that (`kinds()`, `board_title()`, `noun()`, the `noted` signal...),
    and `request_board.gd` / `request_spot.gd` / `request_parcel.gd` take a `jobs` source (the board is `earthy`: wood,
    cork cards, a jack-o'-lantern on top). It stands by the gazebo's steps; three jobs every Earth day: take a parcel
    from a shop door to someone, rake the leaf piles round a Maple Lane house, find someone's cat (glowing eyes; it
    follows you home), pick pumpkins at the patch for Poppy, and the grind/combo ones on Earth. Props:
    `scripts/earth_job_prop.gd`. Saved as `"earth_jobs"`.
  - **Shops take sparkles** (one money for both worlds; a second Earth money would split what the player earns):
    `scripts/earth_town.gd` (autoload `EarthTown`) puts shop spots at the bakery and toy shop counters and the diner's
    and Corner Market's doors; 17 Earth things in `shop/items.json` (snacks, the Witch Hat and Pumpkin Hat in
    `cosmetics.gd`, the contest pie).
  - **Autumn Festival** (`scripts/festival.gd`, autoload `Festival`; `festival_green.gd` builds it): Saturdays 5-10 PM
    on the green. Poppy's treats stall, Gus's cider cart, the pie contest (buy a contest pie, Dottie judges via
    `"do": "Festival.judge_pie"`), apple bobbing (`scripts/apple_bobbing.gd`, three timed bites), Miss Marigold's
    lanterns, hay bales, a banner and lantern strings, and the hayride (a tractor driven by Scarecrow Sam, a lap of the
    street, stop by the Maple Inn). At 9 PM 56 sky lanterns go up. Routines can have `"festival"` blocks
    (`routine.gd`), so the townsfolk come. Prizes once a festival; saved as `"festival"`.
  - **Story hints** (`EarthTown`): the old oak hums (made in code with an AudioStreamGenerator: wav files are LFS)
    from 9 PM, louder to midnight and loudest in the Shift, with a green glow; one or two small tremors a night between
    10 PM and midnight (rumble, camera shake, falling leaves, flag `earth_tremor`: Mr. Palmer says "pipes"); a lilac
    envelope on Mr. Palmer's porch addressed to the Mayor in Galaxity (flag `read_palmer_letter`: his "pen pal").
    Lots of new lines for the festival and the hints.
  - Tests: new `tools/test_notice_board.gd` and `tools/test_festival.gd`; `test_earth` checks it all loads;
    `test_townsfolk` runs on a Friday so the festival doesn't move people. Previews: `tools/capture_earth_fun.gd`
    (in the project files under world/previews/earth_fun, made in the cloud). Names made up for Hayden to rename:
    Scarecrow Sam, the cats Duchess, Footnote and Marmalade.
- 2026-10-31: Stars Hollow build-out, phase 2: the people. Everyone on Earth is made like a hero in the creator
  (`scripts/townsfolk.gd`, `Townsfolk`): the Earth kid body dressed and shaped by `Hero.apply()` from a hero-style look
  (`_look()` in `build_earth.gd`: swatch colours, hairstyle, height, head, build, face), grown-ups taller with smaller
  heads, plus their own things made from shapes (`Townsfolk.EXTRAS`: aprons, glasses, a backwards cap, a chef's hat,
  Barnaby's guitar, Nina's bow and turtleneck...). The model is made in `_enter_tree()`, so it isn't saved in the scene
  and the Routine finds its AnimationPlayer. Mr. Palmer is his own human model (`mr_palmer.glb`). Node names can't
  have dots, so the node is "Mr Palmer" and the talk spot says "Mr. Palmer".
  - **Routines on Earth:** a routine file with `"world": "earth"` follows Earth's clock (`Routine.now()`) and Earth's
    paths, `routines/earth_places.json`, which the builder writes from the buildings (`_write_places()`: the green,
    shop fronts, walk-in doors and insides, Main Street, Maple Lane, each house's gate, the park, the hill, the yard,
    the Blastoffs' bedrooms). `TownPaths.get_shared(file)` keeps one graph per file, and a point can carry its floor
    height (`floors`) so indoor places don't land on the roof. An Earth hour is a real minute, so a walk across town
    takes an hour or two of their day: keep far-apart blocks long (Kip runs, at 3.2 m/s).
  - **Who (names made up, Hayden can rename):** Gus (grumpy Hollow Diner owner), Dottie Pennywhistle (chatty Maple
    Inn keeper), Barnaby Quill (troubadour, gazebo and pond, stargazes on Lookout Hill), Miss Marigold Hollis
    (librarian), Poppy Crumb (baker), Otis Gumdrop (toys), Mrs. Wren (strict antiques), Hank Bramblewood (hardware),
    Kip (six jobs: market, fire station, pumpkin patch, library, inn), Lionel Page (bookshop), Juniper Okafor (school
    reporter) and Ozzie Larkspur (skater kid); Miss Ivy is now the diner's waitress, Theo (Pemberton) reads at the
    bookshop and on the green, Madame Celeste stays in her studio. Kids are in school 8-12 and 1-3 (away), out at
    recess and after. Nights: almost everyone's in by 11.
  - **The Blastoffs:** human Nina (`nina_earth`) lives at the Blastoff house (breakfast, school, skate yard, the old
    oak at dusk, her room, bed in her room); Prue (`prue`, lilac, pigtails) and Bruno (`bruno`, SK8 beanie, board)
    are PLACEHOLDERS (`Townsfolk.placeholder`) until there are drawings of them as people.
  - **Talk:** every new person has a hello, lines for what they're doing (`"activity"`) and the time of day, and some
    story hints (the oak hums, a green flicker past the oak, tremors, Mr. Palmer by the oak at midnight: his
    `oak_watch` block, 11:40 PM to 1 AM, and he knows more than he says). Benches on Main Street moved off the shop
    doors, and the footbridge now lines up with its path.
  - Tests: `tools/test_townsfolk.gd` (everyone made, every path link clear and dry, everyone where they should be
    through the day, walking when watched, talk by time, Nina and the placeholders); `test_earth` checks every
    routine's places can be reached from the portal and everyone's on the map. Previews: `tools/capture_earth_people.gd`
    (in the project files under world/previews/earth_people, made in the cloud).
- 2026-10-30: Stars Hollow build-out, phase 1: the town (Hayden: "go" on prompt S, with a Halloweentown fall feel,
  "plenty of railing/ramps scattered around town in spots that actually make sense" and "don't be afraid to let the
  player get BIG AIR"). The green and its buildings stay where they were; the town grows round them
  (`tools/build_earth.gd`, walls now a rectangle x -152..92, z -152..102):
  - **Ground:** `scripts/earth_land.gd` (`EarthLand`) is the one height function for the builder, the game and tests.
    It builds its own mesh and HeightMapShape3D when the town loads (so there's no big LFS ground file): flat town,
    **Willow Pond** (a bowl west of the Town Hall), **Whisper Creek** (from the falls into the pond and out south),
    **Lookout Hill** (6.5 m, gentle slopes, a cliff on the pond side) with **Mossy Falls**. `scripts/water.gd` wades the
    pond and creek (`EarthLand.water_circles()`).
  - **Main Street** north from the green between the diner and bookshop: Crumb & Cauldron Bakery, Gizmo & Gumdrop Toys,
    Lantern Hill Library (on a stone base, steps with two grindable handrails) and the Town Hall (now walk-in: benches,
    podium, "Town meeting tonight" banner), all walk-in (`_walk_in()`: hollow CSG shell, doorway, lights, music, with
    `Doorway` and `Inside` markers); Cobweb Corner Antiques, Nuts & Bolts Hardware (loading dock with a kicker and a
    rail), Fire Station No. 1 (truck out front) and Old Oak Elementary (bell tower, stair set) at the top.
  - **Maple Lane** (south, joined by Hollow Lane): the Blastoffs' house (walk in; living room with fireplace, and a
    bedroom each: Nina's red and black with her bow, Prue's lilac with plushies, Bruno's with skate posters, a board
    and a little ramp; `NinaBed` marker), Mr. Palmer's house (rocking chair and teacup on the porch) and six more
    with mailboxes. The **Old Covered Bridge** carries it over the creek.
  - **Park:** the dock and rowing boat, lily pads, cattails, mist and ducks on the pond, a footbridge with grindable
    rails, the playground (slide with a "We asked for a slide... and we got one!" sign, swings, sandbox), the pumpkin
    patch with scarecrows, the Lookout on the hilltop, a rail all the way down the hill's east slope and the
    **Big Air Kicker** at its foot.
  - **Hollow Skate Yard** beside the school: the Big Vert (two 4.8 m quarter pipes, 86 degrees), a mini ramp, a gap
    jump (kicker, 7 m gap, landing deck), funbox, stair set, ledge, rails, a bank, Skaters' Corner, floodlights and a
    fence. Plus rails/ledges by the Town Hall, the creek path, the pond path and the market.
  - **Autumn/Halloween:** jack-o'-lanterns (always glowing), cornstalks on the lamps, hay bales and scarecrows at the
    green's corners, orange/purple string lights zig-zagging over Main Street and Maple Lane, bunting round the green,
    friendly sheet ghosts in windows, bare twisty trees by the water, ~240 trees and 6000 fallen leaves. Fog is lighter
    (0.0035) for the wider town.
  - **MultiMesh gotcha:** a `--headless` build saves MultiMeshes with no instances (the dummy renderer drops them), so
    the old fallen leaves never showed. `scripts/multi_fill.gd` (`MultiFill.pack()`, used by `multi()` in the
    builder) keeps the transforms and colours on the node and fills the MultiMesh at load. Use it in any builder.
  - **Map:** the builder writes `ui/earth_map.json`; `scripts/map_screen.gd` draws Earth's map from it (streets, places
    coloured by kind, water, hill, labels, the portal) on the Map sheet and the minimap (`on_earth()`).
  - **Saves:** `Game.EARTH_LAYOUT` 2 (`"earth_layout"` in the save). A save from out on Earth before this wakes up at
    home (HomeSpawn) with a "the town's grown" message.
  - Tests: `test_earth` checks every place, a clear way in to every walk-in and each Blastoff bedroom, nothing floating,
    the pond and hill, wading, skate lines, the map and the old-save wake-up. `tools/capture_earth_town.gd` takes 22
    shots (in the project files under world/previews/earth_town, made in the cloud). Names made up for Hayden to rename:
    the shops above, Willow Pond, Whisper Creek, Mossy Falls, Lookout Hill, Hollow Skate Yard, Maple Lane, Hollow Lane,
    and the neighbours Hollis, Okafor, Larkspur, Quill, Pemberton and Bramblewood.
- 2026-10-30: Aiming while riding (Hayden: "make aiming a thing while riding"). Hold Aim (right click / LT) on any ride
  that can shoot and you get the same over-the-shoulder camera, crosshair and shots to the crosshair as on foot;
  her whole body twists round to it (the ride pose). While aiming, the camera is the player's to look round with (it
  doesn't swing back behind her: `follow()` in `spring_arm_3d.gd` waits), and the board steers from where she's going,
  not from the camera (`_camera_dir` in `skate.gd`), so looking about never turns the board. Not in a race, where Aim
  is still the power-up button. `test_skate_popper` checks it; `tools/capture_ride_aim.gd` (shots in the project files
  under world/previews/ride_aim, made in the cloud).
- 2026-10-30: Shooting from a ride looks natural (Hayden, option 1). `PopperArm` in `star_popper.gd` now poses the whole
  upper body on a ride, all in code on the bones every body shares (spine, chest, head, both arms), so it fits every
  hero body and every rider that can shoot, with no new model files. Her spine, chest and head twist towards the shot
  (40/35/25 per cent, up to `TWIST_MAX` 1.5 rad: riding side-on, a shot straight ahead is about a quarter turn, and
  twisting nearly all the way lets the popper arm reach out in front instead of across her chest), her head looks up
  or down at it a little, her left arm swings out to the side and a bit back for balance with a soft elbow, and each
  shot kicks her chest back (`KICK_LEAN`, twice for a big bubble) and lifts the arm a touch, settling over 0.25 s.
  The arm eases round to a new direction (`FOLLOW`) instead of snapping, so it follows through on grinds and
  mid-flip, and the whole pose eases in and out over `EASE` (0.15 s; the modifier's `influence` is eased too). While
  a big bubble charges she crouches a little (`bracing` in `skate.gd _pose`). It's all after the animation, so
  steering and the skate physics never see it; riders with `"popper": false` don't change. Note for anyone reading
  bones in tests: the skeleton keeps its own poses between frames, so `PopperArm` records what it did (`twist`,
  `chest_turned`, `left_arm_turned`, `lean`). `test_skate_popper` checks the ease, twist, balance arm, kick, follow-
  through, crouch and blend-out; `tools/capture_ride_shoot.gd` (before/after shots in the project files under
  world/previews/ride_shoot, made in the cloud).
- 2026-10-29: Races, step 4: Sky Rings, a mothership race (Hayden: "races"). A sky track in `Races.TRACKS` (`"sky":
  true`, rings 24 m wide, 1 lap of about 750 m high over town, the castle and the gardens; opens after the Lake Loop,
  prizes 25/16/10/5). Its points are used as they are, not dropped onto the ground. Fly the mothership through the
  big start ring to begin (`Races._watch_sky()` -> `start_sky()`); no starter to talk to. Three friends race in mini
  saucers scaled up four times (Blip, Nova, Zoomi, pace 23/22/21 m/s, same rubber-banding), and floating boost rings
  speed up the ship (`boost()`, `boosting()` and `is_piloted()` are new in `scripts/mothership.gd`: 1.6x top speed
  while boosting). Leaving the ship or flying 135 m off the line ends the race with no harm done. `test_races` checks
  that the sky line stays 16 m over everything and inside the town's edge, and a whole race; `capture_races` flies it with a bot.
- 2026-10-29: Races, step 3: more tracks, and the routes on the map (Hayden: "maps"). Two new tracks in
  `Races.TRACKS`, each with its own arch, starter and board: the **Meadow Wiggle** (2 laps of S-bends in the south
  meadow, about 272 m a lap; Dart, the orange little alien; against Rook, Pip and the Green Man; prizes 18/12/7/4)
  and **Observatory Hill** (2 laps up and down the hill's lower slopes round the Observatory, about 183 m; Comet,
  the blue one; against Dash, Rex and Mr. Palmer; 20/14/8/4). Tracks open in order (`"after"`: finishing the one
  before, in any place; `Races.finished_once`, saved as `"finished"`). Any starter offers every open track in the
  same place and whizzes you to its grid. The talk is `Dialogue` id "race_starter", choices set `race_go_<track>`.
  The map sheet draws every track's route with a flag and name (faint until it's open), and during a race the gold
  route, the next ring and the friends; the corner minimap is always on in a race (`_draw_races()` in
  `scripts/map_screen.gd`, from `Races.map_tracks()`). `test_races` checks every track (dry, no steep steps, nothing
  in any lane with each lane on its own ground, clear of the portal and of the other tracks' starts) plus unlocking
  and picking. Kerb-height grind rails out in the meadow cross the Meadow Wiggle: they have no collision, so you
  ride over or grind them.
- 2026-10-29: Races, step 2: Zippy's Tune-Up (Hayden: "upgrades"). A workbench under a teal awning past the race
  board (`_tune_up()` in `scripts/race_track.gd`) opens the shop's "Tune-Up" stall. Ride upgrades are items of kind
  `ride_upgrade` in `shop/items.json` (`upgrade`, `level`), sold through `Shop.register_kind()` (shared with the
  gadgets), kept in `Races.upgrades` and saved with the races: Speedy Wheels (+5% pushing and top speed a level),
  Power Push (+15% acceleration), Grippy Grip (+12% turning), Turbo Tank (boost pads and Zoom Stars last 25% longer),
  three levels each, and the Starter Star (every race starts with a Zoom Star). Prices 6 to 20 (test_shop keeps
  prices at 20 or under). They work on every ride, in a race or not: `Races.tuned(ride)` scales the numbers from
  `scripts/rides.gd`, and `Skate.set_ride()` uses the tuned ones (re-tuned when `Races.upgraded` fires).
  `register_kind()` also takes an optional "show" (item -> bool) so the bench lists only the next level of each.
- 2026-10-29: Races, step 1: the Lake Loop (Hayden: "races with cash prizes, boosters, maps, upgrades, powerups").
  The `Races` autoload (`scripts/races.gd`) places each track in `TRACKS` into its scene at play time
  (`scripts/race_track.gd`), so `town.tscn` wasn't rebuilt. A track is a list of checkpoints (x, z); the racing line
  is a Catmull-Rom loop through them, a point a metre, dropped onto whatever static body is under it. The Lake Loop
  goes three laps round the main lake (about 234 m a lap, through the town square, between the portal and the
  housing hedge on the east side). Always there: a lilac start arch with a chequered banner, **Zippy** (the pink
  little alien, with a flag, on the town side of the line: `scripts/race_spot.gd`) and the race board (prizes, best
  time, wins), and 4 boost pads that work any time you ride over one. Only in a race: a glowing ring at each
  checkpoint (the next one gold), 3 rows of Star Boxes and 3 goo puddles. Talk to Zippy and say yes: you're put on
  the grid with three friends on their own rides (`scripts/race_rival.gd`: Dash, Rex and Bramble, or Nina, the Green
  Man or Pip in place of whoever you're riding as), 3-2-1, then the rings in order; a later ring doesn't count. The
  friends follow the line in their own lanes at `RIVAL_PACE` (9.2 / 8.8 / 8.4 m/s, times 0.9 / 1.0 / 1.1 for
  Settings > Assist > Skating landings Relaxed / Normal / Pro), ease off up to 30% when far ahead and pedal up to 20%
  harder when far behind, ride through everyone (no collisions), and get boosted by pads too. Their town selves step
  out of sight while they race. Power-ups from Star Boxes, used with **Aim** (right click / LT, free on the board, now
  in the riding group of `Settings.PAD_GROUPS`): Zoom Star (8 m/s over pushing speed for 2.2 s), Bubble Shield (8 s:
  any fall is a wobble, goo can't touch you) and Super Spring (a huge hop, only from the ground). More Zoom Stars
  when you're 3rd or 4th. Goo slows you to 45% of pushing speed for 1.3 s. New in `scenes/player/skate.gd`:
  `boost()`, `gooed()`, `spring()`, `shielded`, and after a boost a 2.5 s fade back to pushing speed on the flat
  (holding a direction never slowed her, so a boost would otherwise last for ever). Prizes for everyone who
  finishes: 15 / 10 / 6 / 3 sparkles, plus 5 for beating your best time. Stepping off your ride, riding 45 m off
  the line or leaving the place ends a race with no harm done. Saved as `"races"` (best times, wins, races run).
  Race HUD (`scripts/race_hud.gd`): lap, place and time under the day box, the power-up on the left, the countdown
  and results in the middle. `tools/test_races.gd` (the line is dry, has no step too high and nothing in any lane,
  stays clear of the portal; countdown, rings, laps, pace, power-ups, goo, prizes, bonus, stepping off, saving) and
  `tools/capture_races.gd` (a steering bot rides for the racing shots; shots in the project files under
  world/previews/races, made in the cloud). Planned next: a garage for ride upgrades sold through `Shop` (kind
  `ride_upgrade`, with `Shop.register_kind`), more tracks with the route on the minimap, and a mothership sky race.
- 2026-10-29: Gadgets, Ratchet and Clank style (Hayden: "a weapon system like Ratchet and Clank with many
  combinations and upgrades"), slice 1. The `Arsenal` autoload (`scripts/arsenal.gd`) holds her gadgets, their ammo
  and their versions, saved as `"arsenal"` in the save. The Star Popper is the first gadget (endless). New: the
  **Fizz Flinger** (`scripts/fizz_bomb.gd`) lobs a soda bomb in an arc whose splash calls `shot()` on every enemy
  in its radius, and the **Disco Ball** (`scripts/disco_ball.gd`) floats up where it lands and sets enemies near it
  dancing on the spot (their physics is switched off, so no chasing or bumping; rolled-up Crocodillos can't hear it:
  `Crocodillo.shelled()`). Shoot fires whatever is out (`StarPopper.shoot` returns the bubble, bomb or ball); only
  the popper charges. Throws land where she aims, on an enemy in front (`StarPopper.auto_target`) or 9 m ahead.
  Every pop by a gadget is a point for it (`StarPopper.popped` -> `Arsenal.on_pop`), and at 5/14/28/48 points it
  grows V2..V5 (`Arsenal.GADGETS`: more ammo, quicker or bigger, and a Mega trick at V5: the Mega Popper blows two
  bubbles, the Mega Fizz splits into three, the Disco Fever pops its dancers when the song ends). Pops sometimes
  leave an ammo bubble (`scripts/ammo_drop.gd`). The **gadget wheel** (`scripts/gadget_wheel.gd`, on the popper's
  HUD layer): hold Gadget wheel (R / D-pad up, new in Settings > Controls) to open it with the game slowed to 0.2,
  point with the mouse or a stick, let go to pick; a tap swaps back; 1-8 and D-pad left/right pick directly (only
  if not bound to something else). A readout in the bottom right shows the gadget, version, ammo and XP once she has
  more than the popper. **Dash's gadget stall** (`scripts/gadget_stall.gd`, placed at runtime by Arsenal at 105
  degrees and 15.5 m round the fountain, on the south side, not in `town.tscn`) sells them through the Shop: `Shop.register_kind(kind, {can_buy,
  buy, button})` lets another system own a kind (`gadget`, `ammo` here; the races use it too). Test
  `tools/test_arsenal.gd` (uses its own save backup name), previews `tools/capture_arsenal.gd`,
  `previews/arsenal/`. Next slices: buyable upgrades and mods that combine (Freeze, Split, Bounce, Sparkle Magnet),
  then more gadgets (Plushinator, Buzz Bots, Rainbow Ray, Jelly Mines) and ammo crates.
- 2026-10-29: The nightly request board (Hayden, "The First Night" prompt A). A lilac board with a spinning gold star
  stands at the edge of the Market Square (250 degrees round the fountain, mirroring Rex's noticeboard), and Tally,
  the tall yellow little alien, a bit bigger than the crowd and holding a clipboard, walks a ring round the fountain
  between the benches and the stalls. Both are added at runtime by the `Requests` autoload (`scripts/requests.gd`,
  `request_board.gd`, `request_alien.gd`, `request_spot.gd`), not built into `town.tscn`. Every Shift the board rolls
  three requests, once per visit (`Requests.visit_day()`: Galaxity's day at the Shift's dawn, so Galaxity's midnight
  doesn't re-roll), seeded by the visit so a reload keeps them: one easy, one medium, one harder, never the same kind
  twice, asking for a bit more each night (+5% a night, at most +50% by night 11) and paying 3 / 5 / 8 sparkles (+1
  every 4 nights, at most +3). Kinds (`KINDS`): pop Gloops (any way, with the Star Popper only, or stomps only), pop a
  dizzy Crocodillo, grind N metres on one rail, land an N point combo, score N at the Skate Park, bring a friend (Pip,
  Bramble, Rex, Dash, Mr. Palmer, Nina) a snack from the market (bought while the request is open it's wrapped
  instead of eaten, and pays its price back on top) or something from Earth (a parcel waits outside the Hollow Diner,
  Bookshop or Corner Market: `request_parcel.gd`), go to a place (Cozy Cave, Tree House top, Observatory, Scary World
  gate, Cloud Nest), and find a lost watch (only while `Watches.remaining()` is above 0; `watches.gd` calls
  `Requests.note("watch")` on a pickup). Skating kinds need the skateboard. Progress comes through
  `Requests.note()` (from `gloop.gd`/`crocodillo.gd` `_defeat()` and `skate.gd _leave_rail()`, which now counts
  `_grind_metres`), the skater's `banked` combos, `Shop.buy()`, talking to the friend (`Dialogue.finished`) and where
  the player is. Talking to Tally or using the board (`Dialogue.say()`, new: a conversation made up in code) turns
  finished ones in, with confetti and a chime. At the end of the Shift unfinished ones fade with no penalty and
  finished ones not turned in are paid anyway. The board and the Quests sheet (`Quests.log_text()`) update live.
  Saved as "requests" in save.json; old saves start with none and get three on the next Shift.
  `tools/test_request_board.gd` (66 checks), `tools/capture_request_board.gd` (shots are in the project files under
  world/previews/request_board, made in the cloud, which can't upload LFS files).

- 2026-10-29: Lost watches (Hayden, from the lore: everyone who lands on Galaxity has a watch that tracks time their
  own planet's or era's way). Twenty chosen kids lost theirs round Galaxity (`scripts/watches.gd`, autoload `Watches`):
  each a little spinning, glowing model built from shapes (`Watches.model()`: a drip clock, a tide shell, a cuckoo
  locket, a 1985 beep band, a sundial, a moon-nap dial, a robot's bolt watch, the Watch of Many Hands, a chef's egg
  timer, one that runs backwards, a candle clock, an hourglass, a railway pocket watch, a star chart, an orrery, a
  spiral galaxy, a humming crystal ring, a bead calendar, a flower clock and a glow-worm lantern). They're placed so
  finding them takes every way of getting about: on the fountain's water ball, out in the lake and the waterfall
  pond, the tree house deck, the zipline's cable, the rock wall, the Cloud Nest, over the castle hill's long rail,
  high over the Skate Park's quarter pipe, the Gloop King's court, the Agent of Chaos's field, the Spooky Woods, on the
  Town Hall dome, the Observatory dome and the castle's tallest spire (beam down from the mothership), two high in
  the sky (fly the mothership through them), the school's top-floor window sill and greenhouse, and the edge of the
  Scary World. They aren't in the built scenes: `Watches` adds the pickups (`scripts/watch_pickup.gd`) to whichever
  scene is showing, from `WATCHES`, so no builder or `.tscn` changed. A pickup shows a card with a one-line note about
  its owner. Dash collects them: `dialogue/dash.json` has a first ask, a first hand-in and later ones (new dialogue
  keys `watches_to_give`, `no_watches_yet`, `watches_found`, `watches_given`, words `{watches_given}` etc., and a
  conversation's `"do": "Autoload.method"`, whose returned lines are said after its own). Rewards at 5, 10, 15, 20: 15
  sparkles; the Clockwork Star Popper (`StarPopper.COLOURS`, `Game.popper_colour`, saved; a toggle on the Bag page);
  the Tick-Tock Sticker and 10 sparkles; the Time Keeper, worn on the left wrist (hands) or as a pendant (neck), in
  `shop/items.json` as `"reward": true` items of stall "Dash" (never sold). The Bag sheet has a Watches page: a turning
  picture of each one found, a dark silhouette and a vague hint for each still lost. Found ones in town show on the
  map. All saved as Dialogue flags (`watch_found_<id>`, `watch_given_<id>`, `watch_reward_<n>`), so old saves just
  have none. `Watches.remaining()` and `Requests.note("watch")` link it to the nightly request board.
  `tools/test_lost_watches.gd` (66 checks, including each watch reachable its own way),
  `tools/capture_lost_watches.gd` (shots are in the project files under world/previews/lost-watches, made in the
  cloud, which can't upload LFS files).
- 2026-10-29: The Star Popper on your board (Hayden, "Before the First Night" prompt C). Shoot works while riding, from
  the hip only (no aiming on the board, so steering is the same): rolling, in the air, on a grind and in a manual, and
  in the Simple controls too. On the board it looks for an enemy within 26 m and 40 degrees of where she's going
  (`BOARD_RANGE`/`BOARD_ANGLE` in `star_popper.gd`), doesn't turn the board, and her arm still points the popper over
  the skate pose. A bubble that pops an enemy sends `StarPopper.popped(enemy, bubble)`; on the board `Skate.on_pop()`
  turns it into a trick (`SkateTricks.pop()`, `POPS`): "Pop!" for a Gloop (250), "Croc Pop!" (400), "King Pop!"
  (1500). Each is its own combo entry (so it adds to the multiplier), repeats are worth half like any trick, and its
  points fill the special meter like any trick's (a Pop! is about a sixth). A lone pop while rolling is a combo of
  its own, paid out after the usual moment to link a manual. The big bubble still costs 1 MP. Riders with no hand
  free can't shoot (`"popper": false` in `rides.gd`): Rex and Rook (a skate on every paw) and Pip (flying). Everyone
  else can, and each holds the popper up. Two new Skate Park goals: "Pop 3 Gloops in one combo" (5 sparkles) and "Pop
  a Gloop off a grind" (4; a bubble fired from a grind counts even if she's off the rail when it lands). The park's
  goals script also brings sleepy Gloops at play time (`_place_gloops()` in `skate_goals.gd`, named "Skate Gloop N"):
  five round the park and one beside each of the six town rails nearest it. They never chase, amble slowly, and come
  back after 8 s even with her close by (new `respawn_clear` on `gloop.gd`). The town builder wasn't changed, so
  `town.tscn` wasn't rebuilt. Controls: Shoot is now in the riding group of `Settings.PAD_GROUPS`, so remapping
  checks it against the skate buttons; nothing clashes by default (left click / RT), and old settings with Shoot on a
  skate button get it back on RT (`_free_board_shoot()`). New "skate_shoot" tip, and Coach Rook's combo step says pops
  count. `tools/test_skate_popper.gd`, `tools/capture_skate_popper.gd` (shots in the project files under
  world/previews/skate_popper, made in the cloud). `test_shooting` now expects shooting on the board.
- 2026-10-29: The Gloop King, and every Gloop restyled to match him (Hayden, from their picture). Gloops are now
  glossy green goo swirled with gold, with a rainbow sheen like a soap film (`scenes/enemies/gloop_goo.gdshader`), big
  dark glassy eyes in goo rims, three draped layers of goo with rounded tongues hanging off them, and stubby feet that
  waddle; the old toothy grin is gone. They never stop dripping: the tongues slowly stretch and spring back (in the
  shader, from a drip mask in the body mesh's vertex colours), and a drop swells on each tongue's tip, falls into the
  wet puddle under them and splats (`_drip()` in `scripts/gloop.gd`). `tools/build_gloop.gd` builds both scenes;
  the body mesh is shared in `scenes/enemies/gloop_body.tres`. Each layer's rolled edge gets its own rows of the mesh
  that follow its tongues, which is what keeps the edges smooth. Big Gloops are the goldier ones (`goldness` 0.6).
  The Gloop King (`scripts/gloop_king.gd`, `scenes/enemies/gloop_king.tscn`) is the same goo with a little gold
  crown and red gem, 2.5 m tall, holding court in the west fields (`GLOOP_KING` in `build_town.gd`) with three Gloops.
  He's a kid-safe boss: six bubbles or stomps pop him (a big bubble counts for three), a goo meter shows over his
  crown, every few seconds he belly-flops and sends a ring of goo across the ground (it bumps you only if you're on
  the ground, so jump it), and at two-thirds and one-third he calls two more Gloops, which don't respawn. Named
  "The Gloop King" so `find_children("Gloop *")` skips him. Test: `test_gloop_king` (31 checks). Previews:
  `tools/capture_gloop_king.gd` (a studio like the picture, then town by day and night).
- 2026-10-29: Aiming and shooting (Hayden). The hero has a Star Popper, a toy bubble blaster (`scripts/star_popper.gd`,
  made from shapes: lilac body, bubble tank, teal nozzle, gold stars). Shoot (left click / RT) blows a star bubble
  (`scripts/star_bubble.gd`); from the hip it finds an enemy in front of her by itself. Holding Aim (right click / LT)
  moves the camera in over her right shoulder (`aim` in `spring_arm_3d.gd`), shows a crosshair that turns pink on an
  enemy, turns her to face where the camera looks and slows her walk; bubbles go to the crosshair (a controller gets
  a little help onto an enemy near it). Holding Shoot charges a big bubble for 1 MP (the first use of MP) that counts
  for three pops and carries on through. Her right arm points the popper (`PopperArm`, a SkeletonModifier3D on the
  `upper_arm.R`/`forearm.R`/`hand.R` bones every body has), and it's in her hand while aiming and for a moment after a
  shot. Kid-safe: a Gloop hit (`Gloop.shot()`; big ones take two) is caught in a bubble, floats up and pops
  (`StarBubble.carry_off()`) for its XP. Bubbles boing off a rolling Crocodillo's shell; out of its ball one makes it
  dizzy and a second pops it (`Crocodillo.shot()`). Anything else with a `shot(power, point, dir)` method can be hit
  later. On foot only: not on the board, zipline or mothership, or in talks, menus and the creator. Aim and Shoot are
  in Settings > Controls: keys can now be mouse buttons (kept as minus the button number) and controller actions can
  be the triggers (`Settings.PAD_LT`/`PAD_RT`); old settings get the new defaults. A "shoot" tip shows the first time
  there are enemies about. `tools/test_shooting.gd`, `tools/capture_shooting.gd` (shots are in the project files under
  world/previews/shooting, not in `previews/`, as they were made in the cloud, which can't upload LFS files).

- 2026-10-29: Hero creator: more bodies, face sculpting and a secret hero (Hayden). Four new bodies built in Blender
  by `tools/build_hero_bodies.py` (Earth kid, bunny, cat, dino; Dash-sized, on two legs, each with idle/walk/run and
  its own clothes, colours and extras), so the creator has nine. A new Face tab sculpts the eyes, eye spacing, nose,
  ears (with the moth's antennae and the cow's and dino's horns) and mouth, from tiny to huge, and has nine ready-made
  faces to start from (`scripts/face_sculpt.gd`). Faces are sculpted on a copy of the hero's mesh: each body lists
  where its face parts are in `Hero.BODIES[...].face`, the parts are found as connected pieces of the mesh, and their
  points are scaled about their roots, so the head bone still carries them and every animation keeps the face. The
  original mesh stays on the model as meta "unsculpted", and clothes are fitted before sculpting (to the body as
  drawn). The dog-kid gets about on all fours, so it's a secret (`Hero.SECRETS`): finishing Coach Rook's skate lesson
  finds it (saved as item "secret:dog"), it joins the body list with a star, and the Body tab hints at secrets not yet
  found. Bunny and cat ears are their own parts ("Ear", "Ear Lining", in `Clothes.NOT_HEAD`) so hats sit on the head.
  New tools: `capture_faces.gd`, `capture_creator_face.gd`; `test_creator.gd` checks the Face tab and the secret,
  `test_clothing_fit.gd` covers every body (`previews/creator_faces/`).
- 2026-10-28: The Shift flipped to match the story (Hayden). The player lives on Earth: a new game starts in their
  house on the south side of the green (`_my_home()` in `build_earth.gd`, with a bed, and the creator's rug), and
  `earth.tscn` is the main scene. Earth's clock always runs (an Earth hour a real minute). From Earth's midnight to
  1 AM the portal by the old oak (`PortalToGalaxity`, opened by `earth_world.gd`) goes to Galaxity, and that hour is
  one Galaxity day: Galaxity runs from dawn (7 AM) to the next dawn in 20 real minutes while Earth's clock crawls 24x
  slower, wherever the player is. Galaxity's clock waits at dawn between Shifts and its day number goes up once per
  visit. At 6 AM Galaxity warns, and when the Shift ends `Clock` pulls the player home to the old oak from any
  Galaxity scene (`Clock.pulls_home`, off in tests that need it). Galaxity's portal and the pause menu go home early;
  on Earth in the Shift the pause menu goes through to Galaxity. Beds: on Earth, naps stop at midnight and "Until the
  Shift" waits for it; in Galaxity, sleep stops at dawn and ends the visit (`Clock.sleep()`, `end_shift()`).
  `Clock.hour()` and `period()` are local (Earth's on Earth); `hours()`, `time_string()` and `daylight()` stay
  Galaxity's. Saves are version 2; old ones still load: one made in Galaxity carries on there in the Shift (Earth's
  time worked out from Galaxity's), one made on Earth keeps Earth's time. Mr. Palmer on Earth talks to a neighbour
  now. `tools/test_clock.gd` and `tools/test_earth.gd` were rewritten, `tools/capture_shift.gd` (`previews/shift/`).

- 2026-10-28: Mr. Palmer's Galaxity form, an alien mayor with an elephant trunk (`tools/build_mr_palmer_alien.py` →
  `mr_palmer_alien.blend/.glb`; idle, walk, grab). He keeps his tummy, suit, red tie, sash, round glasses and grey
  moustache, with mint-teal spotted skin, lilac ear fins and crest, antennae with gold bobbles, three fingers and a
  stubby tail. The trunk runs on its own chain of bones (`trunk.0`-`trunk.7`): it sways in idle and swings in walk.
  In town (`MrPalmer` in `characters.tscn`, and his Mayor-mobile in `rides.gd`) he's the alien; his human model
  (`mr_palmer.glb`) stays for Earth later. `scripts/palmer_trunk.gd` puts a tea table in front of his office-hours spot
  and every 9-18 s he curls his trunk round the teacup, lifts it and puts it back (the cup follows a BoneAttachment3D
  on the trunk tip, read in `_process` so it stays in step with what's drawn). `tools/test_palmer.gd`,
  `tools/capture_palmer.gd` (previews in `previews/mr_palmer_alien/`).
- 2026-10-28: Skating feels more fun, and you can grind anything (Hayden). Momentum: pushing works up hills (ground up
  to about 40 degrees, `HILL_MIN_Y`; only `uphill_pull` of a hill holds her back while she pushes, all of it when she
  coasts), the first pushes from a standstill are stronger (`push_kick`), glides are longer (`coast` 0.45), and she
  rolls up kerbs and steps up to `STEP` (0.32 m) instead of stopping (`Skate._step_up`). Any edge: `scripts/edge_rails.gd`
  makes the top edges of every upright solid box and the rims of round tops in a place into invisible grind lines the
  first time someone rides there (588 in town: benches, walls, steps, stalls, kerbs, the fountain, the skate park's
  rim). Rails file themselves in an 8 m grid (`GrindRail.near()`), so the skater only checks nearby ones. 70 new
  rails round town (`_town_rails()` in `build_town.gd`, `SkateKit.ground_rail`): beside the main paths and scattered
  over open ground, following hills. Tests can run in a copy of the project with its own save folder (an
  `override.cfg` with `config/use_custom_user_dir`), so they never touch Hayden's save while he plays
  (`tools/test_skate.gd`, `tools/test_skate_park.gd`, `tools/capture_rails.gd`, `previews/rails/`). test_walk_through's
  boardwalk check fails with some saves (on main too); not looked into yet.
- 2026-10-28: Mr. Palmer has a daily routine in town (`routines/mr_palmer.json`), so he no longer stands outside the
  Town Hall all night. Office hours from 7:30 AM by his window (new place `palmers_step`), an evening stroll round the
  market from 5 PM, and at 8:30 PM he walks to the Town Hall door and goes in (away) until morning. He still talks from
  his window (`Palmers Window/Talk`), so the map finds his name there. His town self now wears his wardrobe outfit too.
  `test_routines` checks him and his walk home.
- 2026-10-27: The Agent of Chaos, the giant villain, from Hayden's picture (`tools/build_chaos_giant.py` →
  `chaos_giant.blend/.glb`; idle, walk, chaos): a hooded figure in gold and dark armour and torn bone-white cloth,
  with gold skulls, a broken crown and a cracked clock on his chest running backwards. Built about 2.75 m and scaled
  x4 in town (about 11 m), he stomps slowly back and forth in the far northeast field behind the castle hill
  (`ChaosGiant` in `characters.tscn`, `scripts/chaos_giant.gd`, patrol (128, -232) to (104, -180)), broods, and now
  and then flings his arms up and lets the chaos out. He does that at the player too when they come near, but he
  never chases or hurts anyone. He's solid (a capsule round his legs) and shows on the town map (the
  "map_landmarks" group). Hayden may rename him the Agent of Time: his name is only `NAME` in `chaos_giant.gd`
  (`tools/test_chaos_giant.gd`, `tools/capture_chaos_giant.gd`, `previews/chaos_giant/`).

- 2026-10-27: The little aliens, from Hayden's sheet of tiny space kids: seven colours in shiny hooded suits with huge
  black eyes (blue with a wing cape, purple flowing suit, tall curious yellow, red cape, pink fins, orange wide
  sleeves, green tail), built by `tools/build_little_aliens.py` (`little_alien_<colour>.blend/.glb`; idle, walk, run,
  sit, float, wave). They're scenery, with no collision: `scripts/little_aliens.gd` (the `LittleAliens` node at the
  end of `characters.tscn`) scatters 30 walkers, 7 tiny saucers and 4 jetpack floaters over the town. Walkers
  (`scripts/little_alien.gd`) feel along their surface with rays, so they climb walls, roll over onto roofs and turn
  back at edges, and wave at or scurry from the player; far-off ones are hidden and paused, and ones left behind are
  moved near the player. Saucers (`scripts/mini_saucer.gd`, built from shapes in the mothership's colours) cruise,
  hover, land on roofs, swoop past the player and do spins, darts and loops. `LittleAliens.walkable()` keeps them off
  the invisible edge walls, the lake bed and characters (`tools/test_little_aliens.gd`,
  `tools/capture_little_aliens.gd`, `previews/little_aliens/`).
- 2026-10-27: The little aliens got snouts (Hayden). Hayden picked two shapes (`_snout()` in
  `build_little_aliens.py`, which still has the others: muzzle, long, pig, bulb, wide): a dolphin beak (blue, red,
  pink, green) or a button nose (purple, yellow, orange). The snout is on its own "snout" bone, and
  `LittleAliens.vary_snout()` stretches it to a random length and width for every alien (walkers and pilots), so no
  two look the same (`02b_snouts.png` in `previews/little_aliens/`).
- 2026-10-26: Clothes fit everyone. Pieces used to be moved from Nina by a few bone positions and one width, so hats
  hovered over hair or sank into it, capes and jetpacks floated off backs (they were placed for Nina's backpack),
  gloves sat at the wrist of T-posed arms, a skirt was sized round backpacks, the headphones' band ran front to back
  and under the chin, and Dash's cap and shades stayed on under hats and glasses. Now `Clothes.fit_of()` measures
  each body from its own mesh points and the bone carrying each one (`_cloud()`): the top of the head in the middle
  (not ears, horns or antennae; a hat sits a little down into big spiky hair), the head's width at the eyes and all
  the way up, the neck, chest and middle without arms, hair or bags, the back, and each hand and foot (where it is,
  how big, which way it points). `_fitted()` moves and stretches each piece from that place on Nina to the same
  place on them; `_tailor()` makes glasses' arms, goggle straps and the headphones (cups on the sides of the head, a
  band arched over it) to measure. Whatever a piece goes over comes off (`Clothes.UNDER`: Dash's cap and Nina's bow
  under hats, own glasses under new ones, backpacks under back pieces). Hats sit on top of a hairstyle, and a cap or
  beanie (`Cosmetics.COVERS`) tucks its buns, mohawk or curls away (`hairstyles.gd` tags parts "crown" and "up").
  `Clothes.dress()` takes the hero's hidden parts and hairstyle so everything is fitted together, and returns what it
  hid. `tools/test_clothing_fit.gd` puts every hat and piece on all six hero bodies (with and without a hairstyle)
  and every friend and checks each one touches them; `tools/capture_clothing_fit.gd` takes front and side pictures
  of everyone in five outfits, with a contact sheet each (`previews/clothing_fit/before` and `after`). The clothes
  test failed when the save's hero wasn't a hippo (it looked for Nina's shirt on the hero), so it starts from a hippo.
- 2026-10-26: The player menu (`scripts/player_menu.gd`, autoload `PlayerMenu`): one menu with sheets for Quests, Map,
  Hero, Bag, Skate, Settings and Save. Tab or Back opens it on Quests (`player_menu` action, in Settings > Controls for
  both, Classic and Simple), Q / E or LB / RB (`menu_prev` / `menu_next`, fixed) go along the sheets, and Tab, Esc and
  B close it. Q and M still go straight to their sheet, and close it there. The sheets lend the game's own screens:
  the quest log (`Quests.log_view()`), the big map (`TownMap.map_view()`), the pause menu's settings tabs
  (`PauseMenu.settings_into()`, look from `PauseMenu.make_theme()`), and buttons for the wardrobe, Change your
  hero..., the skate lesson, the how-to tips, saving, a new game and quitting. The quest log has no controller button
  of its own now (Back is the menu); old settings with something on Tab give Tab to the menu (`Settings._claim`).
  Godot's `ui_cancel` is only Esc, so B is checked by hand (`tools/test_player_menu.gd`, `previews/player_menu/`).
- 2026-10-25: The quarter pipes are visible again (town Skate Park and the Practice Park's halfpipes).
  `skate_kit.gd prism()` worked out which way each face points by looking away from the middle of the ramp's side
  outline, which is wrong on a quarter pipe's hollow curve, so the curve was built inside out: Godot only draws the
  front of a face, so it was invisible, though still rideable. It now goes by which way round the outline runs.
  `tools/test_skate_pieces.gd` checks every solid skate piece has a shown, solid mesh with every face outward
  (`previews/skatepark_ramps/`, before and after).
- 2026-10-25: Skating help and control choices. Forgiving bails: `Settings.skate_assist` (Settings → Assist →
  "Skating landings": Relaxed, Normal (the default), Pro = the old strict rules; table `Skate.ASSIST` in `skate.gd`).
  Relaxed and Normal land wider, finish a nearly-done flip, slip off rails and out of manuals instead of falling, keep
  all (Relaxed) or half (Normal) of the combo and the special meter in a bail, and get up sooner. Controls: the
  controller buttons can be changed like the keys (`Settings.pad_bindings`, `PAD_GROUPS` say which may share), and
  there are two layouts (Settings → Controls): Classic, and Simple (`control_style`: one trick button, tap to flip,
  hold to grab, grinds by themselves, Grind on the flat is a manual). Every prompt uses `Settings.prompt(action)` /
  `Settings.fill("{jump}")`, which follow remaps and whether a keyboard or controller was used last. How-to tips
  (`scripts/tips.gd`, autoload `Tips`): first-time pop-ups for walking, jumping, the map, pausing, talking, shopping
  and riding, saved as `tip_*` flags, toggle in Assist, "How-to tips again" in the pause menu. Coach Rook's skate
  lesson (`scripts/skate_lesson.gd`, autoload `SkateLesson`): offered the first time on a ride, at the new Lesson Pad
  in the Skate Park (`skate_kit.gd lesson_pad`, `scripts/lesson_pad.gd`) and in the pause menu; 8 steps (push, ollie,
  spin, flip, grab, grind, manual, combo) saved as `skate_lesson_*` flags, 10 sparkles once. Bruno isn't in the game
  yet, so Rook coaches (he still only says woof) (`tools/test_skate_help.gd`, `previews/skate_tutorial/`).
- 2026-10-24: Character creator fixes. Turning the hero no longer hides the mouse: a click in the world used to reach
  the camera (`spring_arm_3d.gd`), which grabbed the mouse, so the creator now keeps its clicks and the camera leaves the
  mouse alone while it's open. The right stick turns the hero too. Pausing in the creator and resuming keeps the
  mouse. New Game from the pause menu while the creator was open left it stuck on screen over the new game; now it's
  put away when the scene changes and opens again for the new hero. A new game quit before the hero's made asks again
  next time (`needs_creator` is saved). The wardrobe has a "Change your hero..." button (`test_creator.gd`).
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

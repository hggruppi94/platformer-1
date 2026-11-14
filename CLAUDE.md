# The Void: Sofi's game

A Godot 4.7 3D platformer built by Hayden from Sofi's characters and drawings. The player makes their own hero in the
character creator (since Oct 23, 2026: before that the player was Nina, who is now a friend in town). They live on
**Earth**, in a small Stars Hollow style town (since Oct 28, 2026: before that they lived in the Void and visited
Earth). The crack by the old oak leads to **the Void**, the alien town. Since Nov 14, 2026 nothing waits on the clock:
once the oak's awake the crack is open any time, jumping in makes it the Shift (Earth's midnight, the Void's dawn),
the Void's day loops round for as long as they stay, and going home lands them on Earth the next morning. Only The
First Night keeps the old shape (its fall at midnight, the pull home at the Void's dawn).

Read this first in every session so each iteration builds on the last one and doesn't start over.

## Where things are

- `Godot Project/my-world/`: the Godot project (`project.godot`)
  - `tools/build_*.gd`: **builders**. They generate the scenes, so never hand-edit a built `.tscn`. Change the
    builder and re-run it.
    - `build_town.gd` → `scenes/town/town.tscn`, plus the terrain, castle and garden `.res` files. The Void: the
      lake, Market, homes, Bojnice castle school on its hill, Observatory, Secret Gardens, Cloud Nest, mountains,
      green sky with cream cloud streaks, mothership.
    - `build_school.gd` → `scenes/school/school.tscn`, the castle school interior from Sofi's floor plans
      (`source_art/reference/world/school - *.jpg`). It has 3 floors, the atrium, the Entrance Garden with its
      greenhouse and vegetable beds, and the 3rd-floor window that looks out on the town's real mountains.
    - `build_earth.gd` → `scenes/earth/earth.tscn`, the Earth town (Stars Hollow style), where every game starts
      (`Game.START_SCENE`; the main scene is the title screen, `scenes/title/title.tscn`): the
      player's house with their bed (`My Home`, new games start at `HomeSpawn`), the town green and gazebo, shops,
      the barn dance studio, the portal to the Void by the old oak, and the sky's clouds, stars and moon.
    - `build_interiors.gd` (domed rooms: cafe, aquarium, restaurant, Nina's house), `build_scary_world.gd`, and
      `build_centipede/crocodillo/gloop/mothership.gd` for creatures and vehicles.
    - `theme.gd`: the shared look. `THEME = "alien"` maps every colour into the alien palette (oranges → teal,
      reds → magenta, greens → acid lime, whites → lavender). Builders call `tint()` / `light()` / `backdrop()`.
  - `scripts/`: game logic. Autoloads include `Clock` (`clock.gd`: Earth's clock, which always runs, the Void's,
    which only runs in the Shift, and the Shift), `Game`, `Dialogue` and `Quests`. `day_night.gd` handles the Void's sky and lamps, and `earth_world.gd`
    handles Earth's full day and night.
  - `dialogue/*.json`, `quests/*.json`, `routines/`, `shop/`: content, each with its own README.
  - `tools/test_*.gd`: tests. `tools/capture_*.gd`: screenshot tools.
  - `STATE_MACHINES.md`: where every "what's happening now" state lives, and the rule for shared ones (the
    player's controls are named holds: `Game.hold_controls("who", on)`, never `input_locked = true/false`).
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

## GodotPrompter

This is a Godot project with GodotPrompter skills available. Before implementing any game system, you MUST check for a matching `godot-prompter:*` skill and invoke it. This applies to all agents, subagents, and sessions working in this repository.

Key skills: `player-controller`, `state-machine`, `event-bus`, `scene-organization`, `component-system`, `resource-pattern`, `godot-ui`, `hud-system`, `ai-navigation`, `camera-system`, `audio-system`, `save-load`, `inventory-system`, `godot-testing`.

For the full skill list, invoke `godot-prompter:using-godot-prompter`.

- The skills are installed on Hayden's PC only (user scope, with the `router`, `godot` and `disciplines` bundles
  from awesome-gamedev-agent-skills). Cloud sessions that don't have them carry on as usual.
- The skills give general Godot advice. Where they disagree with this file (builders, tests, save safety, style),
  this file wins.

## Names and story

- The town and world is **the Void** (or just "Void"). It was called "Galactopia" until Oct 2026 and "Galaxity" until
  Nov 8, 2026 (Hayden renamed it); don't bring either name back in anything the player sees. Code ids, node names and
  file names still say `galaxity` (e.g. `PortalToGalaxity`, the title screen's `"galaxity"` beat, capture file names):
  they are internal and safe to leave.
- Mr. Palmer is the mayor (on Earth he's just plain old Mr. Palmer). Rex is the skating husky who wants to be mayor,
  and Dash is his twin. The other characters are Bramble (the plant girl, with Snappy the flytrap), Heather (the
  horned cattle girl: Hayden named her Nov 8, 2026; she was "Clover" before that and "Bramble" until Nov 7, and her
  code id is still `clover`), Melody, Pip (they/them: Hayden, "sort of androgynous"), Rook (says woof), Ivy and Theo
  (Earth), Madame Celeste (Earth dance studio) and the lonely centipede (she/her; her school corner, Dark Hollow, and her home
  by the hollow log behind the old Scary World gate, one place at a time).
- The world behind the old gate in the Void's northwest woods (the centipede's home) is called **Dusk's Embrace** in
  everything the player sees (Hayden named it Nov 13, 2026; it was "the Scary World" before). Dark Hollow is a
  different place and keeps its name. Internal names still say scary_world (`scenes/scary_world/`,
  `scripts/scary_world.gd`, the "Scary World Gate" and "FromScaryWorld" nodes, `scary_world_*` flags and
  `scary_world.ogg`): leave them, saves and tests depend on them.
- In the show, kids are people on Earth and creatures in the Void. Since Oct 31, 2026 Nina is human on Earth (`nina_earth`;
  since Nov 7 from Hayden's picture: red-orange bob with a fringe, red bow, freckles, gap teeth, pink pinafore, yellow backpack) and stays her alien self in the Void. Since Nov 1, 2026 Bruno is too (`bruno` on
  Earth, `bruno_alien` in the Void, from Sofi's drawing). Prue's Earth look is still a placeholder.
- The player's hero is whoever the player makes; dialogue never assumes their name or gender (use `{player}`, `{they}`).

## Log (newest first)

- 2026-11-14: **Spray paint shows on windows** (Hayden: "I noticed the paint is behind the window"). The builders make
  windows (and many signs and trims) as thin meshes stuck a little way out from a wall, with only the wall's collision
  behind them, so paint landed on the wall and was hidden behind the glass. `Paint.outside(at, normal)` moves a spot
  out onto the front of any thin, still mesh covering it (`SKIN_THICK` 0.45 m, at most `SKIN_OUT` 0.35 m out; worked
  out in each mesh's own space, found through a 4 m grid built the first time someone paints in a place). `Paint.dab()`
  and `SprayCan.aim_hit()` use it, so spraying and washing both work on the glass. In Stars Hollow 110 of 145 window
  spots had been hidden; now none are. `test_spray` checks a window.

- 2026-11-14: **The voice in your mind speaks out loud** (Hayden: "can we give the brain dialogue in your mind a
  voice?", then picked sample C, "many voices as one"). Built and tested in the cloud (own Godot user folders, no save
  touched).
  - **Every line has its own recording** in `audio/mind/<key>.ogg` (219 lines: the fixed ones, the ones naming each
    world, and every quest goal its hints can remind you of). The key is the first 16 letters of the line's md5
    (`DivineMind.voice_key()`), so a changed line needs a new file. The words stay up until it's finished saying them
    (`VOICE_TAIL`), a line with no file is just shown as before, and nobody babbles over it (`soundscape.gd`). In a
    talk (touching the old oak) its lines are spoken from `Dialogue.raw_line` (the line before `{player}` is filled
    in: the recording leaves the name out), and the voice stops when the talk moves on. It plays on the Voices bus.
  - **The voice:** Kokoro (free, Apache 2.0) with a man's and a woman's voice blended into one, a deep layer an octave
    down, a faint high layer, chorus and echo (`STYLES["C"]` in `tools/make_mind_voice.py`). The lines live as
    constants in `scripts/divine_mind.gd` (`ARRIVAL`, `CRACK_OPENED`, `MENDED`, `OAK_FIRST`, `HINT_*`) and callers use them.
  - **Changing or adding a mind line or a quest goal:** run `tools/dump_mind_lines.gd` (writes `audio/mind/lines.txt`
    from `DivineMind.all_lines()`), then `tools/make_mind_voice.py --model ... --voices ...` (see its header for the
    model files). `tools/test_mind_voice.gd` fails if any line has no recording.
  - My choices Hayden may change: the voice's speed, depth and echo, the name left out of "I chose you".

- 2026-11-14: **Spray paint that stays put until it's washed off** (Hayden's 14 Nov 2026 playtest: "I also want to add
  spray painting that stays put until it is washed offf, allowing the character to create any permanent design they
  want"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **Getting the cans:** "Spray Cans", 3 sparkles, at the Toy Shop in Stars Hollow (`spray_can`) or the Toys stall in
    the Void (`spray_cans`), shop kind `"spray"` (registered by `Paint`). They give the item `spray_can`.
  - **Controls** (`scripts/spray_can.gd`, class `SprayCan`, a "SprayCan" node on the player like the Star Popper): new
    action **Spray paint** (V / R3, on-foot pad group; hidden in Controls until you have the cans) gets the cans out and
    puts them away. With them out the camera's over the shoulder like aiming (`StarPopper.painting`,
    `set_painting()`: her arm points a little spray can, gadgets don't fire). **Hold Shoot** to spray where the
    crosshair is (up to 9 m; closer is a fine line, further a fat one), **hold Aim** to spray water that washes paint
    off. Colour: mouse wheel, 1-0 (and -), or D-pad left/right; the palette is a column of pots down the right side
    with the water drop last, and four button chips beside it ("Spray", "Wash", "Colour", "Done"). The crosshair is a
    ring in the paint's colour, as big as the splat. A puff joins up with the last one, so a sweep is a line. Not on a
    ride, burrowing, swimming, in a talk or a menu (riding puts the cans away). A soft hiss made in code.
  - **The paint** (`scripts/paint.gd`, autoload `Paint`): each puff is a "dab" (spot, normal, colour, size, spin, lift)
    kept per place (scene path) and drawn by one MultiMeshInstance3D "Paint Layer" per place, alpha-scissored splat
    texture made in code, sRGB colours, matt. Newer coats sit a hair further out (`LIFT`, `LIFT_STEP`); painting over
    the same spot recolours the dab there (`SAME_SPOT`), so going over and over doesn't pile up. `MAX_DABS` 9000 a
    place ("Full of paint! Wash some off."). **Saved** in the save as `"paint"` (base64 floats per place), so it's
    there on every later visit until washed. Only still, visible things take paint (`Paint.paintable(collider, at)`):
    no people, rides, moving platforms (AnimatableBody3D), Make's bridges or frost's ice (`TEMPORARY` groups), group
    `no_paint`, or the invisible walls round a world (`NOT_PAINT` names, and a body needs a visible mesh that reaches
    the spot).
  - Tests: new `tools/test_spray.gd`; `test_party` counts 14 on-foot pad actions now; shooting, arsenal, player_menu,
    controls_lock, kid_ui, shop, layout, dash_shop and ui_style pass. Previews: `tools/capture_spray.gd` (shots in the
    project files under world/previews/spray_paint).
  - My choices Hayden may change: V and R3, Aim to wash, the ten colours, 3 sparkles and where they're sold, 9 m
    reach, no paint on things that move, no "wash it all" button.

- 2026-11-14: **Bumps and boinks when you run into things, and echoes in caves and tunnels** (Hayden: "sensory boinks
  and bumps when you collide with surfaces", "a sort of bounce with a puff of smoke when you run into things", "Have
  cave sounds/echo when inside tunnels"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **`scripts/bumps.gd`** (no class_name, preload it): `after_slide(body, velocity_before, model, min, full, ...)` right
    after `move_and_slide()` in `player.gd` (on foot: 4 to 12 m/s) and `skate.gd _move()` (on a ride: 4.5 to 14 m/s,
    after the kerb step-up so kerbs aren't bumps). A knock into a wall or a ceiling (not ground, not a kerb at her feet,
    not enemies or bosses: they have their own hits) at more than `min` m/s straight into it: she **bounces back**
    (`bounce_off()`: some of the speed back out plus a push; soft things bounce further; on foot she can't steer for
    0.14 s, `_bump_timer`, not a stun so hopping on a ride after doesn't bail; on a board bounced straight back she rolls
    away fakie, the board the same way round), a **puff of smoke** (`smoke()`) and coloured bits at the spot, a squash,
    a sound by what it is (`Surfaces.wall_kind()` in `surfaces.gd`: wood bonk, stone clunk, soft boink, crystal and metal
    clink, water squish, grass thud; a node can set meta `"surface"`), a camera nudge towards it, a little shake for big
    ones, rumble, and stars for a head bonk. 0.3 s between bumps, so leaning on a wall doesn't rattle. Landings keep
    their own feedback.
  - **New sounds** in `Juice._make()`: boink, bonk, clunk, clink, squish. `Juice.rumble()` scales by `rumble_scale()`.
  - **Settings > Assist:** "Rumble strength" (0 to 100%, `Settings.rumble_strength`) and "Bumps and boinks"
    (`Settings.bumps`, off: no bumps at all), next to Screen shake and Controller rumble.
  - **`scripts/cave_echo.gd`** ("CaveEcho" on the player): in a `cave_dark` zone (the Undergardens, the Glimmer Caves),
    under a race tunnel's roof (group `race_roof`), in a secret shortcut (`shortcut_at()`), under anything named
    Tunnel/Cave/Grotto/Burrow/Shortcut or in group `"echo"`, or burrowing: a reverb and a soft echo on the SFX bus and a
    quiet cave bed (a hollow hum and drips, made in code) ease in; out again they ease away and come off the bus.
  - Tests: new `tools/test_bumps.gd`; juice, skate_help, races, race_tracks, race_tutorial, earth_race, walk_through,
    layout, swim, burrow and the rest listed in the PR pass. Previews: `tools/capture_bumps.gd` (shots in the project
    files under world/previews/bumps).
  - My choices Hayden may change: how hard a knock has to be, how far she bounces, the sounds, the smoke's colour and
    size, which places echo and how much.

- 2026-11-14: **Speed coins only in races, a whole set puts you in the flow, and a smooth ride up Observatory Hill**
  (Hayden: "the speed coins should be in the races only, not the overworld. Once the player picks up a full "set" of
  coins, they enter a "flow" state where their speed is slightly increased and the screen becomes a little bit blurred
  on the edges and maybe psychedelic-melty", and "The 3rd race, when going uphill, your character kind of plops").
  Built and tested in the cloud (own Godot user folders, no save touched).
  - **No coins in the Void or Stars Hollow** (`scripts/boosters.gd`: strips and ramps stay; the coin code is left in).
  - **Coin sets on every circuit** (`race_track.gd _place_coins()`, `coin_sets`): sets of 5 gold coins (3 m apart, a
    gentle S across the road), as many as fit up to 4 a lap (2 to 3 now: the roads are busy), as evenly round as they
    go, 8.5 m off obstacles, goo, shortcut mouths and the line, 3 m off Star Boxes and 2 m off boost pads (a line of
    coins can run onto a pad). Shown only in a race; a taken coin comes back after 12 s.
  - **The flow** (`Races._take_coins()`, `scripts/race_flow.gd` node "Flow" under `Races`, `race_flow.gdshader`): each
    coin is a little push; all five of one set ("Coins 4/5", then "FLOW!") and for 8 s you're 2 m/s quicker
    (`Skate.flow_speed` on pushing and top speed) and the screen's edges blur, melt and shimmer with colour, fading in
    and out. Another set tops it up. Reduce motion: no melting; Reduce flashing: calmer colours. Ends with the race.
  - **Uphill** (`skate.gd`, `CREASE`): the road's twisted pieces on a climbing bend made her hop off each crease and
    plop back down; she now stays snapped to the road over a crease that small. (Bumps and boinks on collisions are
    another thread's.)
  - Tests: new `tools/test_race_flow.gd`, `test_boosters` (no coins out in the world); skate, skate_park, races,
    race_tracks, race_tutorial, earth_race, race_intros, race_life, first_hour and layout pass. Previews:
    `tools/capture_race_flow.gd` (shots in the project files under world/previews/race_flow).
  - My choices Hayden may change: 5 coins a set, how many sets, 8 s and +2 m/s, the look of the coins and the flow.
- 2026-11-14: **The Frozen Moment's fish and snowmen carry on, Pip's moth wings are a back piece you keep, and the
  Gloop King's subjects fight harder** (Hayden's 14 Nov 2026 playtest: "does it make sense that the fish is jumping
  into an ice lake? Can the snowmen continuously throw snowballs at each other? the moth wings float over the players
  head ... it can become an equipable cape", "the gloop kings subjects arent aggressive enough"). Built and tested in
  the cloud (own Godot user folders, no save touched).
  - **The fish** (`frozen_moment.gd moment_model(0)`): its hole is now a real hole broken through the ice: dark open
    water ("Water"), a ring that ripples once it moves ("Ripple"), nine broken ice slabs tipped up round it and a heap
    of snow. Once thawed (or the world's mended) it keeps leaping out and diving back in every ~3 s
    (`_moments_carry_on()`, `_fish_leap()`, `leaps`).
  - **The snowmen** ("SnowmanL" / "SnowmanR") take turns lobbing snowballs at each other every ~1.1 s for good once
    thawed: the thrower leans back, the ball arcs over and splats, the other wobbles (`_throw_snowball()`, `throws`).
  - **Pip's moth wings** are shop item `moth_wings` (a back piece, `"reward": true`; `clothes.gd hat_or_piece`, node
    `Clothes.MOTH_WINGS` with "WingL"/"WingR" pivots), fitted to the hero's back like the other back pieces (they used
    to be stuck to the Visual at a fixed height, over the head). Pip gives them to keep and puts them on
    (`lanternmoor.gd give_wings()`); old saves that met Pip get them next visit. **They glide wherever you wear them**
    (`player.gd glide_speed()`, `wearing_moth_wings()`, `MOTH_GLIDE` 1.2; `glide_fall` is still how a scene lends a
    glide). They fold back while you walk and spread and beat while you glide (`_flap_moth_wings()`). The final
    fight's Pip section puts them on and puts back what you wore (`chaos_trials.gd _give_wings()`).
  - **His subjects** (`gloop.gd`: new exports `pounce`, `pounce_range`, `pounce_every`, `pounce_speed`, `pack`; off
    for every other Gloop): close up they crouch for 0.45 s (the warning) and leap at you; one that spots you calls
    its pack in (`alert()`, 20 m, 4 s). His four guards (`gloop_kingdom.gd SUBJECT`: sight 16, chase 4.3) and every
    Gloop in his court fight that way. When he wakes, two courtiers jump down off the stands into the fight, then
    another every 14 s (`_jump_down()`, at most 3 at once, `jumpers()`), and he calls three at a time, not two
    (`gloop_king.gd court_stats`, `court_call`). Popping him bubbles the jumpers away.
  - Tests: frozen_moment, lanternmoor (the wings on the back, below the head and behind), gloop_kingdom (jumpers,
    guards, a real crouch and leap), chaos_trials, clothing_fit and the whole suite. Previews:
    `tools/capture_world_tweaks.gd` (shots in the project files under world/previews/world_tweaks).
  - My choices Hayden may change: gliding anywhere in the wings, Pip putting them on for you, how often the fish leaps
    and the snowmen throw, the subjects' numbers (leap range, speed, how many jump in).

- 2026-11-14: **The race circuits come alive: things go off all round you as you race** (Hayden: "I want the maps to
  feel like they are alive and things are happening all around"; our own set pieces, nothing copied). Built and tested
  in the cloud (own Godot user folders, no save touched).
  - **`scripts/race_life.gd`** (no class_name, preload it; a "Life" node `race_circuit.gd` puts on every circuit):
    five set pieces per circuit (`SETS`, by checkpoint), each a "Set <n> <kind>" node with metas `kind`, `d` and
    `fired`. Each goes off when you're 18 to 46 m before it and gets ready again once you're 90 m past, so once a lap,
    always just ahead of you. **Lake Loop:** a Lake Puff leaps out of the lake right over the road, two rows of
    geysers, three saucers swooping low along the road, crystal spires bursting up. **Meadow Wiggle:** giant flowers
    opening (twice), a Bounce Bun leaping over, a swarm of glowing moths crossing, a bunch of balloons let go.
    **Observatory Hill:** shooting stars landing in the fields (twice), a boulder rolling down beside the road,
    saucers, crystals. **Pumpkin Run:** a flock of crows taking off (twice), a hay stack bursting, a hot-air balloon
    going up, fireworks over the road. The crowd in the stand jumps up and cheers as you go by (`cheering`), and a
    blimp with the circuit's name circles overhead.
  - **Nothing is solid** and nothing is ever left on the road: it's all for show, so it can't get in a racer's way.
  - Tests: new `tools/test_race_life.gd` (sets and kinds, nothing solid, nothing on the road before or after, each
    goes off once a lap just ahead of you, the crowd); races, race_tracks, race_tutorial, earth_race and race_intros
    pass. Previews: `tools/capture_race_life.gd` (shots in the project files under world/previews/race_life).
  - My choices Hayden may change: which set pieces go on which circuit and where, how big they are, the blimp.

- 2026-11-14: **The Gloop Gate looks as big outside as the kingdom is inside** (Hayden: "I like the current gloop
  kingdom entrance, but it makes it seem like the kingdom is small and then when you enter it's huge"). Built and
  tested in the cloud (own Godot user folders, no save touched).
  - **The gate itself is unchanged** (the goo mound, crown, gold arch and sign). `scripts/gloop_gate_view.gd` (no
    class_name; `Bosses._place_gloop_gate()` calls its static `build(gate, GATE_RADIUS)`) builds round it in the gate's
    own space: **the Kingdom Wall**, lilac palace-stone walls with goo poured over the top running back from a little
    tower each side of the mound to two tall corner towers with goo roofs, crowns and banners (solid), and goo lantern
    posts by the mouth. Past the edge of the west fields, where nobody can walk, **the kingdom beyond**: a ring of walls
    and 12 towers with goo-falls, a great gate facing the town, goo spires, blobby goo houses with lit windows, and his
    **palace** in the middle, a great tower under a giant goo dome with a giant crown (52 m up), all on a goo bog. Only
    to look at (no collision); seen from the Market too.
  - **Inside** (`gloop_kingdom.gd _ready()`): the same palace (`palace_view()`) stands beyond the Royal Court at
    (0, 0, 175), outside the walls, so the first look up the Bog Road shows the giant dome and crown over the Palace
    Gate.
  - Tests: gloop_kingdom, gloop_king, map, layout, walk_through, boosters, plant_clearance, arsenal, wilds,
    lost_watches and `tools/audit_signs.gd` pass. Previews: new `tools/capture_gloop_gate.gd` (before and after in the
    project files under world/previews/gloop_gate).
  - My choices Hayden may change: how big and how close the city is, the lilac towers (matching the Palace Gate
    inside), the palace's crown, the walls by the mound.

- 2026-11-14: **A cutscene every time a crack opens** (Hayden: "We need to make it more obvious when a crack opens up,
  with a cutscene for each one"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **`scripts/crack_opening.gd`** (node "Crack Opening" under `Portals`: `Portals.opening_cut`), played with
    `scripts/place_intro.gd` (which gained `"shake"` and `"call"` per shot). Skippable (Jump/Interact), about 13 s.
  - **Each portal world's quake** (`quake()`, from `Portals.quake()`): the ground shakes where you are ("A Time
    Quake!"), the camera flies over to the world's spot and the crack only splits open then, on cue, with a pillar of
    the world's light shooting up into the sky and something of that world spilling out (`WORLDS`: crystal sparkles,
    leaves, snowflakes that hang, lantern lights, petals, bubbles, a beat that stumbles, neon sparks), then a look down
    it with a line of its own (the preview wakes at the bottom), then the world's name over a wide shot. Then the
    usual message and the voice in your mind. Skipped, the crack's open all the same. A quake now waits for a quiet
    moment (`Portals._quiet()`: no talk, menu, other cutscene or race). The camera picks a way round the crack that
    no building or tree blocks (`_best_turn()`, `_blocked()`: trees aren't solid, so they're checked by where they
    stand). Headless runs keep the old quick quake unless `force`.
  - **The crack by the old oak** (`earth()`, from `earth_world.gd _show_opening()`): the first time you're in Stars
    Hollow after your first trip to the Void (it's open any time since #110; flag `cut_crack_earth`), the crack's held
    shut (`_held_shut`) till the camera gets there: the oak hums, the green splits open, a look down ("just like the
    night you fell"), "The Crack by the Old Oak", "It's staying open now". Once only.
  - Not given a cutscene: the way home in each world (always open), the little visitor cracks, Dark Hollow (no crack).
  - No spoilers: the words only say what's happening and what you can see; no bosses or reasons (the test checks).
  - Tests: new `tools/test_crack_opening.gd`; portals, cracks, earth (both runs), first_night, opening,
    practice_trips, far_future, lore_order, meetings, rootmind, first_hour and races pass. Previews:
    `tools/capture_crack_opening.gd` (shots in the project files under world/previews/crack_opening).
  - My choices Hayden may change: every caption (first drafts), the pillar of light, what spills out of each, the
    title on the last shot, no cutscene for the ways home.

- 2026-11-14: **No cut-off words anywhere, and Mr. Palmer's window you can see** (Hayden: "when melanie asks you to fix
  the slide, the window is cut off. we need to check every single windowed text in the game and make sure nothing is
  getting cut off", then "We need to fix mr palmers' window/quest"). Built and tested in the cloud (own Godot user
  folders, no save touched).
  - **Melanie's slide quest:** the to-do list said just "Go with her to ask Mr." (`Quests.short_goal()` took "Mr." as
    the end of a sentence). Titles (Mr., Mrs., Ms., Dr., St....) no longer end one (`_is_title()`), for every quest.
  - **Mr. Palmer's Town Hall window:** Tally's request board stood right in front of it, so from the Market Square
    the board hid it (`Requests.BOARD_ANGLE` 250 -> 232), and Mr. Palmer stood on its "knock on the window" sign
    (`routines/places.json palmers_step` to the window's other side, (-78.2, 22.6)). The slide and Doggie Bill quests'
    map stars point at the window now (`"where": ["mr_palmer"]`, was the Town Hall's door).
  - **`tools/ui_watch.gd`** (preload it): lists anything on the screen that's off the edge, has words bigger than their
    box, or words spilling out of their window (scroll lists and round-clipped things count only what shows). Its own
    test: `tools/test_ui_watch.gd`. `tools/audit_ui.gd` uses it, and now also opens the quest card (with the longest
    quest step) and the voice in your mind. **`tools/playthrough.gd -- all --ui-watch`** watches the whole game for
    cut-off words (anything cut off for a second or more is listed at the end).
  - **What it found, fixed:** at a big text and HUD size, the to-do list ran off the bottom (`hud.gd _fit_todo()`:
    shrinks to fit under the stats), the clock covered the stats (`_fit_clock()`: moves right of them, shrinks if
    needed), and cutscene subtitles ran off the bottom (the Agent of Chaos's ending; `UiStyle.bottom_caption()` in
    chaos_ending, dash_goodbye, place_intro and race_intro: never wider than the screen, grows upwards;
    `void_arrival.gd` grows up too). The voice in your mind sits under the clock now and follows the text size
    (`divine_mind.gd _place()`; the HUD is in group `"hud"`).
  - Every menu and card at four screen shapes and four text sizes, and the whole game at normal and big text: nothing
    cut off. Tests: ui_watch, kid_ui, quests, dialogue, routines, palmer, episodes, request_board, chaos_ending,
    dash_goodbye, race_intros, opening, first_night, cracks, ui_style, map, following, town_quests, player_menu,
    layout, walk_through, earth, party, meetings pass. Previews: `tools/capture_text_windows.gd` (before and after in
    the project files under world/previews/text_windows).
  - My choices Hayden may change: where the board and Mr. Palmer stand now, shrinking (not cutting) the to-do list.
- 2026-11-14: **Nothing in the game waits on the clock, and Pass the time is gone** (Hayden, after the 13 Nov Pass the
  time buttons: "I didnt mean to add time skip buttons, I mean everything should be playable all the way through
  without needing to skip time at all"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **The crack by the old oak is open any time** once the oak's awake (`earth_world.gd _door_open()`). Jumping in
    (`Game.go()` -> `_between_worlds()` -> `Clock.into_the_void()`) sets Earth to midnight and the Void to dawn, so
    it's the Shift. Going home (`Clock.home_from_void()`) ends the Shift and lands them at 7 AM the next morning, so
    Earth's day only goes forward and the town's awake. The pause menu's way on Earth is "Go through the crack to the
    Void". A new game's oak is asleep until the hero's made (`HummingOak.awake()` checks `Game.needs_creator`).
  - **The Void's day never ends by itself** (`Clock.endless()`, everything but The First Night): at its dawn Earth's
    clock wraps back to midnight, no 6 AM warning, no pull home, and sleeping there doesn't end the Shift.
  - **The First Night** keeps its fall at midnight, but its evening runs at 12x (`Clock.earth_speed()`), and its home
    step pulls them home by itself 14 s in (`first_night.gd _pull_soon()`), with a warning at 6 s.
  - **No more waits:** Rex's campaign has no waits and no time windows (posters straight after the report, the rally
    any time, Mr. Palmer's window answers any time). A friend the step you're on points at stays out instead of going
    home or to school (`Quests.needs()`, `routine.gd stay_out()`). Your first crop grows 8x as fast (`Farm.first_boost()`).
    Festivals, fairs, Melody's show and seasonal quests are left on their days: they're extras, and the Season Dial
    reaches every season.
  - **Gone:** `scripts/pass_time.gd`, the pause menu's Pass the time page, the bed's "Until the Shift", "Go to the Void
    at midnight", and the midnight / 1 AM messages. The watch, the HUD, the map and the Divine Mind say the crack's open.
  - Tests: test_clock, test_earth, test_cracks, test_quests, test_map, test_time_watch, test_first_hour updated; the
    whole suite and `tools/playthrough.gd -- all` (it now jumps straight back through the crack each visit).
  - My choices Hayden may change: home at 7 AM, the 12x first evening, the 14 s pull home, the 8x first crop.
- 2026-11-14: **Secret shortcuts, road tunnels, sliding bumpers and pop-up walls on every circuit** (Hayden's 13 Nov
  2026 playtest: "The races need a lot of work; moving maps, obstacles, secret shortcuts, tunnels"). Built and tested in
  the cloud (own Godot user folders, no save touched).
  - **Secret shortcuts** (`Races.TRACKS` `"shortcuts"`, built by `scripts/race_circuit.gd _plan_shortcuts()` /
    `_shortcut()`): one per circuit, the Lily Tunnel (Lake Loop), Root Run (Meadow Wiggle), Star Tunnel (Observatory
    Hill) and Corn Cut (Pumpkin Run). A gap in the wall on the inside of a bend (`_open`), hidden behind a curtain of
    vines (cornstalks on Earth) you ride straight through, then a lit tunnel across the middle and back out further
    round, 30 to 60 m shorter. Riding it through moves you on past the rings it skips (`Races._in_shortcut()`,
    `_took_shortcut()`); the first time it shouts "SECRET SHORTCUT!" and pays 3 sparkles (`SHORTCUT_PRIZE`, flag
    `race_shortcut_<track>_<n>`). In at the wrong end counts for nothing. The board says "Secret shortcut: ???" until
    it's found, and Zippy and Pepper drop a hint once you've raced. Rivals stay on the road.
  - **Road tunnels** (`"tunnels"`, `_road_tunnel()`): an arch over the road with lamps and a name: the Crystal Tunnel,
    Mushroom Tunnel, Stargazer Tunnel and the Covered Bridge. Its roof joins group `race_roof`, so the racing line
    isn't dropped onto it (`RaceTrack.ground_at`).
  - **Sliding bumpers** (`"slider"`) glide from side to side across the road, and **pop-up walls** (`"popup"`) glow
    for 0.9 s, then rise out of the road for 1.7 s in every 4.2 (a jelly block with eyes in the Void, a crate on
    Earth). Both bounce you back like a bumper (`race_attacks.gd`), you ride over a pop-up wall when it's down, and
    rivals steer round them. Some obstacles moved a little to keep clear of the shortcuts' mouths.
  - Tests: new `tools/test_race_tracks.gd`; `test_races` (walls skip a shortcut's opening), race_tutorial, earth_race,
    race_intros, boosters, ride_upgrades, map and schematics pass. Previews: `tools/capture_race_tracks.gd` (shots in
    the project files under world/previews/race_tracks).
  - My choices Hayden may change: the names, where each shortcut goes, 3 sparkles, the curtains' look, the obstacles'
    timings. Not done from the note: "moving maps" (if that means parts of the track that move, the sliders and
    pop-up walls are a start).

- 2026-11-14: **Every boss is tougher, the Gloop King faces the right way, and his court floods with goo** (Hayden's
  13 Nov 2026 playtest: "the gloop king faces backwards when you start his fight. Can we add a mechanic where the arena
  fills with slime? And we need to make all the bosses harder with more health"). Built and tested in the cloud (own
  Godot user folders, no save touched).
  - **More health** (damage is unchanged: still bumps, never more): Gloop King 6 to 12, Frost Gloop and Riptide Gloop 6
    to 10, Grandfather Tock and the Dawn Snatcher 8 to 13, Boulderdillo 10 to 16, the Stormram 8 to 13, the Off-Beat 8
    to 12, Captain Glitch 9 to 15, the Hush 8 to 13, the centipede's game 6 to 10 (she burrows from 5), Mama Glorp and
    Big Buzz 9 to 15, the Gloam 8 to 13, the Agent of Chaos 30 to 45 chaos (phases at 30 and 15; the friends' sections
    hold him at 31 / 16 / 1; a rewind gives back 4). Helpers come at about a third and two-thirds.
  - **Tougher attacks:** the Gloop King (and the Gloops built on him) flops every 5 s (was 6), Tock chimes every 6 s
    (7), the Boulderdillo rests 1.6 s between rolls (2), the Riptide pulls every 7.5 s (9), Captain Glitch's volleys
    2.0 s (2.4), the Hush's rings 6 s (7), Big Buzz stays up 4.4 s (5), the Gloam's waves 6.5 s (7.5).
  - **He faces the right way** (`gloop_kingdom.gd _add_king()`): his whole body was turned round to face down the
    court, but Gloops steer by turning their Visual to their world heading, so once he moved he walked backwards. Now
    only his Visual is turned at the start.
  - **The court floods** (`scripts/slime_flood.gd`, node "Slime Flood" at the court's middle): 10 s into his fight,
    then every 20 s (14 when he's cross), the goo-falls gush (a warning, 2.5 s), the court fills with goo 0.6 m deep
    (2 s), stays 6 s and drains (2 s). In it you're slowed to half and every 2 s it bumps you (1, towards the nearest
    pad). Eight gold-rimmed **Royal Lily Pads** (1 m high, `PADS`) and the throne's dais stand clear of it. Each flood
    burps up one Gloop of his court. Popping him drains it for good.
  - **Ammo for boss fights** (`Arsenal.supply_boss(boss, reach, count)`): every boss puts 3 ammo crates (4 round the
    King's court and round the Agent of Chaos) in a ring round where it starts, dropped onto the floor, and they come
    back 25 s after a pop (`ammo_crate.gd regrow`, meta `boss_supply`). The Star Popper's top-up to 10 still works too.
  - Tests: gloop_kingdom (facing, crates, the flood, 12 pops), gloop_king, boss_versions, time_goblins, arena,
    chaos_fight, chaos_trials, far_future, frozen_moment, lanternmoor, arsenal and the rest of the boss worlds updated
    to read each boss's own number; see the PR for the full list.
  - My choices Hayden may change: every number above, the flood's timing and depth, the pads' places, the bump.

- 2026-11-14: **Signs you can read walking in, name tags that stay behind walls, and a slimmer Seer** (Hayden's 13 Nov
  2026 playtest: "the signs arent always orientated the right way for you to read them when entering a new area (the
  gloop kingdom sign when you enter)", "Tally's name is visibile through objects", "Can we make the seer a little
  skinnier"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **Signs:** the Gloop Kingdom's three signs (`gloop_kingdom.gd _sign()`) had their writing on the far side of the
    board, so walking in you saw the back. The label now sits on the board's +Z face. New **`tools/audit_signs.gd`**
    loads every place you arrive in (the Gloop Kingdom, the Star Arena, all nine portal worlds, the four circuits, Dusk's
    Embrace, the Secret Garden, the school, the Observatory) and fails if a flat sign within 120 m of the way in (and on
    your floor) faces away; signs written on both sides and race boards (they face the road) are skipped. Everything else
    already faced the way in.
  - **Name tags:** Tally's name (`request_alien.gd`, node "Name Tag") and every townsfolk name and "Press F" prompt
    (`talker.gd _label()`) are depth tested now, so walls, roofs and stalls hide them. Tally's tag also only shows
    within 12 m (`NAME_RANGE`), like everyone else's only shows close up. `test_request_board` checks it.
  - **The Seer** (`seer.gd`): build 1.12 -> 0.94, and her shawl and skirt are narrower to match.
  - Tests: audit_signs, request_board, gloop_kingdom, council, townsfolk, first_night, layout, walk_through, dialogue
    (both runs), earth, party and meetings pass. Previews in the project files under world/previews/signs_tags_seer.
  - My choices Hayden may change: how slim she is, 12 m for Tally's tag.

- 2026-11-13 (replaced on 14 Nov: Hayden didn't want skip buttons, see the entry above): **No waiting around for the
  clock: Pause > "Pass the time", and "Go to the Void at midnight"** (Hayden:
  "There's a lot locked behind time. We need to make the game playable all the way through without forcing the player
  to wait"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **`scripts/pass_time.gd`** (no class_name, preload it): `choices()` lists where the clock can jump to from here.
    On Earth: morning (7 AM), noon, evening (6 PM), night (9 PM), the crack opening (midnight) and the next **Saturday
    fair** on the green. In the Void: noon, evening (5 PM), night, midnight, early morning (5 AM: still "morning" for
    lines that want the daytime) while that's still in the Shift, and dawn, which ends the Shift and the portal takes
    you home. `run(length)` fades out, races the clock's numbers round, `Clock.sleep()`s, saves and fades back in
    ("Time flies! It's ..."). Routines, watered crops and quest waits follow the jump the way they follow the bed's. Not in a portal world or on a race circuit (their clocks stand still), not mid-race, in a
    talk, a cutscene or anything holding the controls (`why_not()`), and not on Earth while the crack's open (go
    through instead). No HP refill: that's still the bed's.
  - **Pause menu** (`scripts/pause_menu.gd`): a **Pass the time** button (new `clock` icon in `ui_icons.gd`) opens a page
    of those times. On Earth outside the Shift, once they've been through, **Go to the Void at midnight**
    (`way_home()`, so the player menu's Save sheet has it too) passes the time to midnight and goes straight through
    the crack. The pulled-home message, the 1 AM message and the watch (T) say so.
  - **No spoilers, and The First Night's rules:** before the first fall nothing names the crack, the Shift or the Void
    and there's no quick way to the Void; the first day still never passes 6 PM until the town and the board are done
    (`FirstNight.earth_hold_minutes()`); its evening stops at midnight ("Until late at night"), when the ground cracks
    open. The watch's "The crack by the old oak opens at midnight" line now only shows once the oak's awake.
  - **Quest waits in hours** (`Quests.is_waiting()`): a step's `"wait"` can say `"hours"` (the Void's hours, from
    `since_at`, saved in the quest's state; old saves count from that day's dawn). Rex's campaign was the only quest
    with day waits: the posters now take 3 hours and Mr. Palmer's window 8 (after the evening rally, so first thing in
    the morning), with Rex's "come back tomorrow" lines changed to match.
  - Already no waiting before this: the story quests start as soon as the one before is done (scripts/meetings.gd),
    portal worlds open by the story (`Portals.quake_due`), worlds have no timer, the Season Dial switches seasons, and
    practice trips (Settings > Assist) visit any world.
  - Tests: new `tools/test_pass_time.gd`; the whole suite and `tools/playthrough.gd -- all` (see the PR). Previews:
    `tools/capture_pass_time.gd` (shots in the project files under world/previews/pass_time).
  - My choices Hayden may change: the stops and their times, the fair stop, the button names, no HP refill, being able
    to skip a night's Shift by passing the time to the morning.

- 2026-11-14: **Blueprints are prizes now, and winning a race first time wins something** (Hayden's 13 Nov 2026 playtest:
  "Instead of randomly finding blueprints, make them rewards for completing races/quests", "unique rewards for finishing
  first, something to incentivize the player to race"). Built and tested in the cloud (own Godot user folders, no save
  touched). This replaces the 11 Nov rule that gadget blueprints lie in the worlds that fit them.
  - **No gadget blueprint lies on the ground any more** (`Schematics.LIST` `"reward"`): the Star Popper's is Dash's
    thank-you for catching his Buzz Bot (`bb_thanked`, `Meetings.thanks_from_dash()`, his lines and `quests/bike_boy.json`
    say so); the Fizz Flinger, Buzz Bots, Rainbow Ray and Plushinator are the first-win prizes of the Lake Loop, Meadow
    Wiggle, Observatory Hill and Pumpkin Run (`Schematics.for_race()`); the Disco Ball is Melody's thank-you when Rhythm
    Springs is mended and the Jelly Mines Otto's when the Tide Reef is (`teach_lines()`). `Schematics.award(id)` sets
    `schematic_<id>` and says who gave it; old saves that already earned one get it a moment after loading
    (`_check_rewards()`, only outside that world). Rides' schematics stay on their nights.
  - **First-win prizes** (`Races.first_prize()`): the circuits give those blueprints; the Sky Rings the **Aviator Cap**,
    the Hollow Run the **Lantern Hat**, the Skyway Run the **Rocket Helmet** (`FIRST_HATS`); winning all four circuits
    the **Champion's Helmet** (`CHAMPION_HAT`, `champion()`). New hats in `cosmetics.gd` and `shop/items.json`
    (`"reward": true`). Each race's board says what winning it gives ("WIN IT for...", then "Won: ..."), the gate's
    board lists every circuit's prize (smaller text), Zippy and Pepper mention them, and the results say what you won.
  - Tests: `test_schematics` rewritten for rewards, `test_race_tutorial` checks the prizes; races, meetings, arsenal,
    rhythm_springs, tide_reef, dialogue, first_night, nights, shop and more pass, and `tools/playthrough.gd -- all` (now
    buying the gadgets it was given) passes start to ending. Previews: `tools/capture_race_prizes.gd` (shots in the
    project files under world/previews/race_prizes).
  - My choices Hayden may change: which race or friend gives which gadget, the three hats and the helmet.

- 2026-11-14: **A clear start on every circuit, and a race tutorial** (Hayden's 13 Nov 2026 playtest: "THE LAKE LOOP RACE
  STARTS OFF WITH A BUMPER RIGHT IN FRONT OF YOU. there needs to be a tutorial for starting races"). Built and tested in
  the cloud (own Godot user folders, no save touched).
  - **The start:** every circuit had its last obstacle (and on two, a goo puddle) on the grid: the Lake Loop's bumper
    was 14.5 m before the line, 1.5 m in front of you in fifth. They moved back round the last bend (`Races.TRACKS`):
    nothing from 34 m before the line (the grid reaches 22 m back) to 12 m after it. `test_races` and the new
    `test_race_tutorial` check that on every circuit.
  - **`scripts/race_tutorial.gd`** (node "Tutorial" under `Races`, the movement tutorial's calm card, on the left under
    the level box): near a race gate with something to ride, the card says to talk to Zippy (or Pepper) under the arch
    (flag `race_gate_seen`, ticked by talking to them). The first race then teaches as you go, one step at a time:
    ride forward at GO, through the gold ring, ride into a Star Box, press Aim to use it, what the obstacles do, the map
    and the laps (flags `race_tut_<step>`; a race left half way carries on next time). Finishing a race ends it for good
    (`race_tut_done`). A save that's raced before, or tips off, never sees it (the gate card still shows with tips off).
  - Tests: new `tools/test_race_tutorial.gd`; races, earth_race, race_intros, ride_upgrades and boosters pass.
    Previews: `tools/capture_race_tutorial.gd` (shots in the project files under world/previews/race_tutorial).
  - My choices Hayden may change: every card's words, where the card sits, which steps there are.

- 2026-11-14: **Dash shows you round his stall, menus start at the top with a scroll bar, and the Star Popper can run
  out** (Hayden's 13 Nov 2026 playtest: "a tutorial for ... buying gadets from dash's store. maybe after you complete a
  quest for him?", "dash gadget window starts at the bottom and you have to scroll up. Every menu that scrolls, can we
  put a scroll bar on the side? the star popper shouldnt have infinite ammo"). Built and tested in the cloud (own Godot
  user folders, no save touched).
  - **Dash's tour** (`scripts/shop_tour.gd`, a Control in the Shop's CanvasLayer, `Shop.tour`): his stall opens once
    you've caught his Buzz Bot for him (The Bike Boy), and the first time you open it he walks you round the window in
    7 steps (title, your sparkles, a gadget and its blueprint, its Get it! button, ammo and refills, the help button,
    Bye and the workbench), a gold-edged bubble beside the window with an arrow at each part (the window slides left to
    make room; on a small screen the bubble sits over it). Next / Skip, closing the shop ends it. Flag
    `tour_dash_shop` (`Shop.TOUR_FLAG`). The stall now has a **How does it work?** button that shows it again. Not in
    headless runs unless `Shop.auto_tour`. The blueprint line says they're earned "by helping people and winning races"
    (the races thread is making them prizes).
  - **The window starts at the top** (`shop.gd _fill`): it used to focus the first thing you could buy, and
    `follow_focus` scrolled down to it. Now the top row is picked (rows you can't buy yet can still be focused, so a
    pad reads the whole list), the scroll's set to 0 when it opens, and after a buy it stays on that row.
  - **Scroll bars** (`UiStyle.scroll_styles()` in the theme, `UiStyle.scroll_bar(sc)` on each box): a dark track with a
    lavender edge and a chunky lavender thumb (teal when held), 8 px gap from the words, shown whenever there's more
    than fits. On the shop, the player menu's sheets, the pause menu's tabs, the creator and the map's legend.
  - **Star Popper ammo** (`arsenal.gd`): a tank of 40/50/60/70/80 bubbles by version (was -1, endless), and the
    workbench's Bigger Tank fits it now. Refills like every gadget: ammo bubbles from pops, ammo crates, and a 1 sparkle
    **Bubble Refill** at Dash's stall (`popper_refill`). Kid safety net: with fewer than `POPPER_TOP_UP` (10) left and no
    shot for 2.5 s it mixes one new bubble a second, up to 10, never more. Any gadget at a fifth or less is
    "running low" once (`Arsenal.low()`; orange in the readout and wheel). Empty says how to get more. Old saves' -1
    comes back full. The corner readout shows from the first gadget and sits left of the minimap now
    (`TownMap.minimap_width()`). The final fight's Dash section fills the Star Popper too.
  - Tests: new `tools/test_dash_shop.gd`; `test_arsenal` and `test_shooting` updated. 46 tests pass (shop, arsenal,
    shooting, skate_popper, player_menu, ui_style, map, chaos_trials, meetings, schematics, arena, first_night, opening,
    kid_ui, party, gloop_king, gloop_kingdom, boss_versions, earth, dialogue, quests, races, creator, title...),
    `tools/audit_ui.gd --quick` finds nothing cut off, and `tools/playthrough.gd -- all` plays start to ending.
    Previews: `tools/capture_dash_shop.gd` (shots in the project files under world/previews/dash_shop).
  - My choices Hayden may change: the tank sizes, the top-up to 10 (take it out for a stricter game), 1 sparkle
    refills, the tour's steps and Dash's lines (first drafts), the scroll bar's look.

- 2026-11-13: **Bug sweep: the whole suite and the whole-game playthrough, and what they turned up** (Hayden picked "a bug
  sweep"). Ran all 109 tests in the cloud (own Godot user folders, four at a time, no save touched): 106 passed. Then
  read every log for errors and warnings, and ran `tools/playthrough.gd -- all` from a new game to the ending.
  - **Thin discs that never showed** (`tools/build_rootmind/frozen_moment/lanternmoor/rhythm_springs.gd cyl()`): their
    heights snap to 0.1, so anything thinner than 0.05 (clover and moss patches, the Frozen Moment's glints, the Lantern
    Grove's floor, Rhythm Springs' pool beds and pool water discs) became a cylinder with no height: nothing drawn, and
    about 2,000 "Vector3 cannot be normalized" warnings every time one of those worlds loaded. Now at least 0.04 (as
    `build_tide_reef.gd` already did). The four `.tscn` files got only their `height = 0.0` lines changed to 0.04 (what
    the builders now make), not rebuilt, to keep thousands of ID-only lines out.
  - `test_layout`: the "new-layout save puts you back where you were" spot (10, 50) sat on the booster coins between the
    meadow rails, so you rushed off ~7 m. The spot is now (10, 40).
  - `scripts/time_goblin_boss.gd`: his goblins got random names 100-999, and two the same made Godot rename one, so it
    stopped counting as his (`test_time_goblins` "two more at two-thirds"). They're numbered now.
  - `test_wall_crawl`: waited on wall-clock timers, so under load it checked before she'd landed on top. It waits on
    physics frames now.
  - Error spam fixed: `crack.gd fall_in()`'s 1 s timer held the old scene in a lambda (freed by the trip: "Lambda
    capture freed"), the creator focused a button on a page already swapped out, and `move_tutorial.gd outside()` read
    the house's transform mid scene change.
  - `tools/playthrough.gd`: waits for Pip's talk to let go of the controls before the Moon Rock glide (failed once under
    load, passes alone).
  - Left alone: rootmind's squashing "Hit" bodies log a Jolt "scale not supported" error (it rounds to an even scale,
    under 7% off); a few "ObjectDB leaked at exit" lines from test scripts quitting.

- 2026-11-13: **The night the sky cracked: the first trip to the Void is a big, worrying event** (Hayden: "The intro
  to the void needs to be much more significant ... an unprecedented event that has people worried ... the little aliens
  creatures can greet all of the chosen as they are thrown into the new world all at once. Maybe the glowing tree quest
  should be scrapped and getting pulled into the void should be a seemingly more random occurrence which you find out
  was caused by dash and rex later on"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **The oak's quest is gone.** The First Night (`quests/first_night.json`) is now morning, board, **evening**,
    shift, day, home. The listening, Mr. Page's book, the letter, the three glowing acorns, dusk, waiting and the oak's
    reveal are all gone (`scripts/humming_oak.gd`: before the fall it's just a big old oak that "you'd swear hummed";
    its runes stay dark, then glow and the touch hint works from the fall on). Nothing on the first day mentions the
    oak, midnight or the Void. Earth's clock waits at 6 PM only for the morning and the board; the bed's sleep stops at
    midnight that night (`FirstNight.sleep_stops_at_midnight()`, `bed.gd`). Nina goes home for dinner (the evening
    guide shot in `opening.gd` is your house).
  - **The fall** (`scripts/void_arrival.gd`, a CanvasLayer at `FirstNight.arrival`): at midnight on that first night,
    wherever the hero is (in bed, on the green, anywhere on Earth), "Midnight.", the shaking builds, the lights flicker,
    a crack splits open under their feet ("CRACK!"), "Aaaaaah!" and dark (`fall()`, about 4.6 s). Flags `fn_fell` and
    `oak_woken` (so the oak's crack is the way in from the second night). It lands them in the Market Square.
  - **The arrival** (`arrive()`, about 29 s, skippable with Jump/Interact): its own camera and black bars, the Void at
    dawn; seven cracks tear the sky over the square; seven streaks of light land one after another: the hero, Nina,
    Bruno, Pip, Bramble, Melody and Heather (their real town selves, put in place by the `shift` step's overrides at the
    new `arrival_<id>` places in `routines/places.json`, hidden until they land); Mr. Palmer, the Green Man, Rex and Rook
    stare; "(Rex's ears go flat. He looks at Rook. Then he looks at the ground.)" is the only hint at who caused it; 22
    little aliens (`little_alien_<colour>.glb`) come running from every side and swarm everyone; Tally counts
    "SEVEN?! All at ONCE?!"; the title "The Night the Sky Cracked". Then the hero's watch, and Tally waits by them
    (`request_alien.gd stand_by()`). Saying hello to Tally (flag `fn_met_tally`) closes the sky and sends the little
    aliens home (`scatter()`), with the Divine Mind's "Don't be afraid. You're exactly where you're meant to be."
  - **A worried town all that first Void day:** new `first_night:shift` / `day` lines for Tally (rattled, then the board
    how-to), Nina, Bruno, Pip, Bramble, Melody, Heather, Rex ("Totally normal"), Rook, Mr. Palmer (his watch runs
    backwards), the Green Man ("...Already?") and the Astronaut. Back home Nina asks "Did you... FALL too?", and there's
    Mr. Page heard the ground by the old oak crack at midnight too (nothing to see there now).
  - **Old saves** (`FirstNight._migrate_v5()`, flag `fn_v5`): a save on an old oak step goes back to the evening; one
    already past the Shift keeps going, with `fn_fell` set.
  - Tests: `test_first_night` rewritten for the evening, the fall and the arrival (with a forced cutscene run);
    `test_first_hour`'s old-save checks; opening, meetings, creator, following, kid_ui, season_dial, routines and more
    pass (see the PR). `tools/capture_first_night.gd` shoots the fall and every beat of the arrival
    (previews in the project files under world/previews/void_arrival). `tools/capture_humming_oak.gd` is gone.
  - My choices Hayden may change: every line (first drafts), who the seven are, the title, where each one lands, 22
    little aliens, Tally waiting by you, that the oak's crack is the way in from the second night.
- 2026-11-13: **Cracks are invisible until they open, and you tumble in and pop out** (Hayden: "Maybe we can add a
  little animation when you go through and come out of the Crack. Also need to make them invisible until they open").
  Built and tested in the cloud (own Godot user folders, no save touched).
  - **Hidden when shut** (`scripts/crack.gd set_open()`): at 0 nothing shows (no dirt, seam, clods or side cracks), their
    collision is off and the ground is whole again: `scripts/ground_hole.gd cut()` now takes an `undo` list and
    `fill(undo)` puts the ground back (anything another hole changed since is left alone). The crack cuts the ground again
    the moment it starts opening (`_cut()` / `_fill()`), and it **unzips** from a short slit in the middle out to its
    full length by halfway open, with a puff of dirt. So Earth's crack is gone outside the Shift, and a world's crack
    can't be seen before its quake.
  - **Falling in** (`fall_in()`): the player's pulled over the middle with a little hop, then tumbles down 3.4 m in
    0.8 s, getting smaller, while the screen fills with the crack's colour (`_veil()`), then goes through. While it plays
    they're `carried` (no physics) under a `crack` hold. The doors down inside the Earth crack and the Void's way back to
    Earth (`door.gd`, meta `crack`) play it too now.
  - **Popping out** (`pop_out()`, started by `Portals._arrived()` when `came_through()`): once the loading screen's
    gone, the player shoots up out of the nearest open crack within 10 m, flips over and lands on their arrival spot
    (0.75 s), with dirt, sparkles and a squash. A crack can't swallow someone who's popping out of it. Reduce motion: no
    spins; Reduce flashing: no colour flash.
  - Tests: `test_cracks` (hidden at 1 AM, ground whole, unzipping, the tumble, the pop), `test_earth` and `test_portals`
    wait for the pop to land (`_settle()`); earth (both runs), portals, practice_trips, first_night, first_hour, layout,
    walk_through, sunken_secrets, garden_caves, glimmer_caves, lore_order, far_future and the portal worlds' tests pass.
    Previews: `tools/capture_cracks.gd` (now with the tumble and the pop), in the project files under
    world/previews/cracks/animations.
  - My choices Hayden may change: the tumble and flip, how long each takes, the colour wash, the unzip.

- 2026-11-13: **A new game opens with cutscenes and a movement tutorial, and far fewer pop-ups** (Hayden's 12 Nov 2026
  playtest: "There need to be more cutscenes in the beginning to guide the player. and way less popups. maybe a movement
  tutorial", and the line about a blaster when you press Shoot without one was a spoiler). Built and tested in the cloud
  (own Godot user folders, no save touched).
  - **`scripts/opening.gd`** (node "Opening" under `FirstNight`: `FirstNight.opening`): when the hero's made, a
    morning cutscene (`wake_shots()`: over Stars Hollow "A sleepy little town, where nothing much ever happens...", the
    old oak "...well, almost nothing.", home, then inside with a knock at the door). Then **"where to go" shots** as
    The First Night moves on (`GUIDES`, once each, flags `guide_<id>`): Nina when you step out of the door, Mr. Palmer
    and the green after Nina, the notice board, the old oak, the clues (bookshop, Mr. Palmer's porch, the town from
    above), the oak's roots at dusk, and in the Void the Skate Park after Tally's hello. They wait for talks, menus and
    other cutscenes, and only play in the right world. All skippable (Jump/Interact). Headless runs skip the cutscenes
    unless `opening.force`.
  - **`scripts/place_intro.gd`** gained `"start"`/`"start_look"` (cut to a spot, then glide) and `"sound"` per shot.
  - **Movement tutorial** (`scripts/move_tutorial.gd`): one card at the top middle, one thing at a time in the house:
    look, walk, jump, double jump, roll, sprint, then out of the door (flags `tut_<step>`, `tut_done`). It holds nothing:
    walking out ends it. Tips off: only the door step. It replaces the four basics tips (they and the talk tip are
    marked seen).
  - **Fewer pop-ups:** no "Welcome to Stars Hollow" (creator.gd: still says it if a hero's made in the Void), no "Knock
    knock" message, no "New jobs" / "New requests" news during The First Night, the tremor message only the first time,
    no "Pop! That's N of 3 Gloops" (the to-do list counts), the Gloop King only says "One more...", and First Night
    steps with a guide (board, oak, clues, dusk) are `"quiet"` in quests/first_night.json: no "Quest updated" banner
    (`Quests._advance`). Quest banners hide and wait while a cutscene plays.
  - **No blaster line:** Shoot with no gadget does nothing at all (`StarPopper.no_gadget_line()` removed).
  - Tests: new `tools/test_opening.gd`; test_first_night and test_shooting updated; first_hour, creator, meetings,
    following, kid_ui, skate_help, quests, ui_style, arsenal, schematics, gloop_king, gloop_kingdom, festival, earth,
    dialogue, controls_lock, notice_board, boss_versions, save_slots and party pass. Previews:
    `tools/capture_opening.gd` (shots in the project files under world/previews/opening).
  - My choices Hayden may change: every caption (first drafts), which steps get a shot, the tutorial's steps and card.
- 2026-11-12: **The cracks look like real cracks in the ground** (Hayden, with a photo of a real earth fissure: "Im not
  a fan of the cracks that open in the ground. Can you make them look more like this?"). Built and tested in the cloud
  (own Godot user folders, no save touched).
  - **`scripts/crack.gd`** keeps its calls (`make`, `sink`, `set_open`, `fall_in`, `drop_player`) and node names
    ("Swirl", "Lid", "Fall", "Broken Earth", "Fissures", "Lips", "Shaft"), so every crack changed at once: each world's
    crack in the Void, the gold way home in each world, the crack by the old oak and the Void's way back to Earth.
  - **The look:** no more round glowing hole. A long jagged split (`_outline()`: about 7.4 m end to end along the
    crack's x, 1.3 m across at its widest, narrowing to hairline points, both edges ragged with bites out of them),
    dark soil walls that lean in a little and fade to black as they drop (`_walls()`), broken dry dirt round it with a
    lip heaped along the edges that fades into whatever ground it's on (`_deck()`, see-through at its edge; solid over
    the cut), lumps of dirt along the lips and stuck on the walls (`_clods()`), and thin dark side cracks running off
    into the dirt and on past both ends (`_fissures()`). Only the deep middle is a real hole (the ground's still cut
    as a circle, `R` 1.4); towards the ends it's a dark seam just over the ground. The world's colour only glows far
    down, round the swirl (the preview still shows there). Shut, it's a seam of dirt (the lid narrows away as it opens).
    The "Fall" area is now a box along the split. Height samples more than 0.7 m up (a crystal, a root) are ignored, so
    the dirt never climbs things.
  - Tests: cracks, portals, earth (both runs), practice_trips, far_future, sunken_secrets, first_night, lore_order and
    glimmer_caves pass. Previews: new `tools/capture_cracks.gd` (shots in the project files under world/previews/cracks).
  - My choices Hayden may change: the length and width, the dirt colour, how far the dirt patch reaches.
- 2026-11-12: **Nina's human form cleaned up** (Hayden: "Nina's human form is pretty chopped and needs to be worked on.
  she has 2 random holes on her face"). Built and tested in the cloud (own Godot user folders, no save touched).
  - The "holes" were her freckles: round balls sunk into her cheeks, so only one dark bump a side showed.
  - **New body:** `nina_earth` is now the creator's human girl (`"body": "human_girl"`, `tools/build_earth.gd`) with
    the "Bob with bangs" (Hairstyles 17) in her red-orange, warm brown skin (swatch 22), and her pink skirt as the
    pinafore's skirt (bottoms 18). The old ball-of-hair bob and stuck-on fringe extra are gone. Only her lines in
    `earth.tscn` changed (the rest of the rebuild was ID shuffle, left out).
  - **`scripts/townsfolk.gd`:** extras know the human body (`human`): the bow sits on the hair, smaller; the freckles
    are flat dots laid on the head's shape and turned to face out (both bodies); the gap teeth sit inside the top lip;
    the hoops hang at the ears; the pinafore's bib and straps lie flat on the tee; the backpack's straps are slimmer
    and yellow. `_tint_hair` also tints the human body's own close-cut hair. Everyone else is unchanged.
  - Tests: `test_townsfolk` (Nina's body and hair, no fringe, her 8 freckles on the skin), earth, work, earth_race,
    first_night, calendar pass. (`test_routines` fails 3 Void checks, Rook following Rex, the same on main without
    this change: not looked into here.) New `tools/capture_townsfolk.gd -- <name> <folder>`: close-ups of one Stars
    Hollow person on their own. Previews in the project files under characters/nina/human-fix.
  - My choices Hayden may change: the bob, her skin tone, the bow's size and spot, the freckles' pattern.

- 2026-11-12: **The party system finished: the friend wheel, your friend's face on the HUD, and one menu** (Hayden picked
  "2", the party system's "not done" list). Built and tested in the cloud (own Godot user folders, no save touched).
  - **Friend wheel** (`scripts/friend_wheel.gd`, worked by `Party`): a tap of Switch friend (X, **LB**) still goes to
    the next friend; holding it 0.2 s opens a wheel of everyone who's joined and "Nobody" (`Party.ring()`), the game
    slowed to 0.2 like the outfit wheel; point with the mouse or a stick, let go to pick (`Party.pick()`). Not in talks,
    menus, the creator, or with another wheel up (`Party.wheel_ok()`).
  - **The face on the HUD** (`scripts/friend_face.gd`, a "FriendFace" CanvasLayer `Party` puts on the player, so
    cutscenes hide it with the rest of the HUD): bottom left, a round face of whoever's with you
    (`FriendWheel.face()`: little faces drawn in code, Nina and Bruno side by side) with the Friend button under it; an
    empty badge with the wheel's button when nobody's along. When someone else could help right here (Flurry by water:
    `Party.helper()`) a bobbing bubble with their face and a "!" pops up beside it. The switch card moved to its right.
  - **One menu:** the quests and the map are tabs of the player menu (Back), so on a controller they have no buttons of
    their own any more (`Settings.PAD_REBINDABLE`, `PAD_GROUPS`: on foot 13 actions). The map's old LB is the friend
    wheel, and D-pad left goes back to picking gadgets. Old settings move over once (`Settings._one_menu()`, mark
    `menus_v2`; the wheel only takes LB if nothing else is there). Keyboard Q and M still jump straight to those tabs
    (Controls calls them "Menu: Quests" and "Menu: Map"); prompts for them say Back on a controller.
  - Tests: `test_party` (wheel, badge, bubble, the one menu, old settings); player_menu, map, ui_style, kid_ui,
    controls_lock, first_night, quick_outfits, arsenal, dialogue, quests and more pass. Previews: `capture_party.gd`
    now also shoots the wheel and the badge with Flurry's bubble (project files, world/previews/party).
  - My choices Hayden may change: LB for the wheel, the faces' looks, the badge's spot, keeping Q and M on the keyboard.

- 2026-11-12: **The party system: friends walk with you, and their moves go on one Friend button** (plan item 26; Hayden:
  "Go ahead and start on the party system", and lore Part 2 items 12 and 13 locked). Built and tested in the cloud (own
  Godot user folders, no save touched).
  - **`scripts/party.gd`** (autoload `Party`, saved as `"party"`: `joined`, `with`): five friends (`FRIENDS`, `ORDER`):
    Nina and Bruno (Make), Bramble (Burrow), Flurry (Frost breath), Heather (April Showers) and Melody (Groove). One
    walks with you (`with_you`); **Friend** (Z, RB) does their move (`use()`; `player.gd` reads only `friend` now, and a
    press that's a Friend move still doesn't roll). **Switch friend** (X, D-pad left) goes round everyone who's joined and
    "nobody", with a card at the bottom left (`card_text()`). Only shown in Controls once someone's joined (two for
    Switch). Old per-move buttons (B, V, G, H, Z) are gone; `Settings.prompt("burrow")` etc. say the Friend button, so
    old lines still read right.
  - **Joining:** each friend asks once their world's mended (`dialogue/bramble.json`, `melody.json`, `clover.json`,
    Flurry's hub talk in `portals.gd`; choice recorded as `party_join`, flags `party_asked_<id>` / `party_yes_<id>`,
    asked again every third talk if you said not yet). A hint says who wants a word (`party_hint_<id>`). Nina and Bruno
    join when they teach Make. **Old saves** (no `"party"`) get every friend whose move they'd learned.
  - **Walking with you:** in the Void the friend's own town self leaves their routine and follows you
    (`routine.gd` `TAG_ALONG`, `_tag_along()`, passing through you, a block with `"keep": true` stays put: Melody's
    show). Anywhere else (portal worlds, the school, rooms) a copy follows your footsteps (`scripts/party_follower.gd`;
    Nina and Bruno side by side), never in their own home world, and only Nina and Bruno on Earth.
  - **Helping out:** with Flurry joined and water just ahead, Friend breathes frost whoever's with you (she hops in).
    In the final fight each friend section brings its friend along for it (`Party.bring_for()`, `chaos_trials.gd`).
    April Showers no longer comes from holding Interact.
  - Tests: new `tools/test_party.gd`; burrow, groove, powers, heather_moves updated; 28 tests pass (dialogue, winter,
    routines, townsfolk, work, meetings, first_night, controls_lock, ui_style, kid_ui, chaos_fight, chaos_trials, the
    friends' worlds, episodes, races, quests, save_slots, first_hour, portals, lore_order, far_future...). Previews:
    `tools/capture_party.gd` (shots in the project files under world/previews/party).
  - My choices Hayden may change: friends ask to join (not automatic), kinetic stays the hero's own, Z/RB and X/D-pad
    left, tap to switch (no wheel yet), Flurry hopping in by water, Bramble burrowing along beside you. Not done then: talking to a
    follower copy (the wheel, the face and the one menu came next: see above).

- 2026-11-12: **The whole test suite is green again** (Hayden: "lets start implementing your suggestions in the honest
  developer review"; the review's first step: no more "fails on main too"). Ran all 107 tests in the cloud (own Godot
  user folders, four at a time, no save touched): 103 passed, and the 4 that failed are fixed.
  - `test_boosters`: the 12 Nov Star Arena's gate walls stood on a line of booster coins by the woods' rail line
    (`boosters.gd`); the coins moved 9.5 m west, clear of the gate.
  - `test_lost_watches`: the **Bolt Watch**'s meadow rail was taken out in the 11 Nov rail tidy, so it hung over
    nothing. It's now over Town Rail 2 on the castle hill, (21.2, 17.2, -86.8) (`watches.gd`); the hint still fits.
  - `test_heather_moves`: Heather's Blossom Orchard was 7.2 m from a town tree (the test wants 8); `Portals.ORCHARD`
    moved 1.5 m west to (-125.5, -61.5).
  - `test_cracks`: "you arrived beside it" allowed 1.5 m from the marker and she was 1.5 m off with four tests running
    at once; it now allows 2.5 m (still more than 3 m from the crack). It passes on its own either way.
  - The far_future, races, layout, earth, first_hour, wall_crawl and arsenal checks that earlier entries say "fail on
    main too" all passed in this run.
  - Rule from now on: **a test that fails gets fixed in the same change, never logged as "fails on main too".**

- 2026-11-12: **The ending rewritten: nobody's left behind, everyone goes home** (Hayden's lore bible v2,
  story/lore-bible.md Part 3 items 6 to 9: "dash doesnt sacrifice himself. fixing the time shift sets everyone back in
  their homeworld", Rex will be mayor of Lumen City, Lumen City is Stars Hollow's far future on Earth, Rex swapped with
  Rook on purpose testing his Swap-o-Tron, the Agent of Chaos is a chosen kid possessed by Chaos, Otto's Grandad lore
  scrapped). Built and tested in the cloud (own Godot user folders, no save touched).
  - **Loose Ends, rewritten** (`far_future.gd` slice three): after the lever swaps them back for good, Rex says sorry
    to Rook (on purpose, for the science fair), and Dash's `home_lines()` (was `twist_lines()`; flag still
    `dash_told`) say the Shift is mending itself: when the Tomorrow Clock strikes the last crack closes and everyone
    goes back to their own world and time, and the three of them are already home.
  - **The homecoming** (`scripts/dash_goodbye.gd`, same file and flags so saves carry on; ~65 s, skippable): beats
    gather, talk (13 lines: Rex's sorry, Rook forgives him, Dash calls Rex a future mayor, "Lumen City is built right
    where Stars Hollow is... just LATER", the cap), **strike** (three bongs, the faces blaze), **home** (each friend
    lifted home in a beam of their own colour), beam, stitch ("the last crack closes"), title "SEE YOU LATER".
    **Dash stays.** Flag `dash_goodbye` now means "everyone's home" (`after_the_ending.gd everyone_home()`, was
    `dash_gone()`).
  - **After:** Dash, Rex and Rook live in Lumen City: at the clock, with a **REX FOR MAYOR (one day)** banner
    (`_add_banner()`), new lines, Dash's rewritten letter on his bench. In the Void all three (and Dash's bike) are gone
    (`void_changes()`, `HOME_IN_LUMEN`), out of the Void's races (`races.gd _gone_home(id)`: not the Skyway Run) and
    deliveries. **Dash takes the lost watches and the Pieces of That Night in Lumen City** (`far_future.gd
    hand_ins()`); Rex's stand-in lines are gone (`watches.gd REX_REWARD_LINES`, rex.json's after-ending talks).
  - **The Old Oak in Lumen City** (`_add_old_oak()`, `OAK_AT` (14, 30)): Stars Hollow's oak a long time later, with a
    plaque and runes; touching it hums (`oak_lines()`: before the ending only "it sounds exactly like the oak back
    home", after "it's the same tree").
  - **The Agent of Chaos's ending** (`chaos_ending.gd`): the figure of light now speaks (`FIGURE_LINES`): he's
    **Teddy**, a Stars Hollow kid chosen in 1956 who went back for one more trip, and something called **Chaos** got
    into his watch; "You beat it. You didn't end it." Title: "is beaten, and the kid he took is free. But Chaos is still
    out there...". The pocket watch says "T.M.". Light beat 3 s longer (T_SKY 17.5, LENGTH 37.5).
  - **Rex's swap was on purpose:** rex.json `rex_lab:see` (science fair; both experiments sent all three back in time,
    the only time anyone's done it, and it cracked time), `lab.gd` header, the sunken pieces' echoes (Rook's Ball,
    the lever knob) and Dash's all-eight lines ("Neither of us meant THIS").
  - **Otto's Grandad scrapped:** the Tide Reef's chest is the **Reef Chest** (node "Reef Chest", "From everyone on the
    Tide Reef"), his plaza lines say Mum. The sunken watch `old_grandad` (id kept for saves) is now **Teddy's
    wristwatch from 1956**, and the eight-watch line says "Nearly every one of them went home". The seer's bike bottle
    no longer hints at a sacrifice.
  - Tests: `test_dash_goodbye` rewritten (90 checks), `test_chaos_ending` (Teddy and Chaos named), `test_tide_reef`;
    far_future (its Void portal tree check fails on main too), sunken_secrets, portals, dialogue, chaos_fight pass;
    lost_watches fails only its Bolt Watch rail check, as on main. Previews: `tools/capture_dash_goodbye.gd` (shots in
    the project files under characters/dash/homecoming).
  - My choices Hayden may change: every line (first drafts), Teddy's name and 1956, the beams' colours, the banner,
    the oak's spot and look, Dash taking the watches in Lumen City, and that unfinished Void side quests with Dash, Rex
    or Rook can't be finished after the ending.

- 2026-11-12: **Dash's kinetic energy, and Nina and Bruno's making power** (Hayden's lore decisions, 12 Nov 2026: "give
  dash kinetic energy, and nina and bruno share an ability to create, but its weaker for that reason"; the lore bible
  at story/lore-bible.md). Built and tested in the cloud (own Godot user folders, no save touched).
  - **Kinetic** (`scripts/kinetic.gd`, a "Kinetic" node on the player): Dash teaches it when you tell him you popped the
    Gloop King (`Meetings.king_from_dash()` adds `teach_lines()` before he sends you to Pip; saves already past that
    get it from his catch-up talk, `kinetic_from_dash()`, in `dialogue/dash.json`). Flag `kinetic_taught`. **No new
    button:** running (faster than 3 m/s) stores "go" (`METRES_TO_FILL` 32 m fills it), riding fills it slower and a big
    landing adds a bit; it never drains. Full, the next **Roll** is a **kinetic burst**: the roll goes 1.8x as fast
    (`player.gd _roll_boost`), a gold shock ring rolls out 6.5 m and every enemy in it takes 2 bubbles' worth (`shot()`).
    A gold meter at the bottom shows while it fills and says "Roll to let it go!" when full.
  - **Make** (`scripts/make.gd`, a "Make" node on the player): new action **Make** (Z, RB; on-foot pad group), secret
    until taught (`Settings.SECRET_FLAGS` "make": flag `make_taught`, so it isn't in Controls before). On the ground it
    makes a wobbly 4.5 m **bridge** at your feet's height out in front; in the air a **step** under your feet (once a
    jump). Nina's pink and Bruno's blue by turns, two at once at most, each lasts 6 s (game time) then pops. Not on a
    ride, burrowing, swimming, climbing or in a race. **RB still rolls until Make's taught**; after that a press that's a
    Make doesn't roll too (`player.gd made_now`).
  - **Quest "Making Things"** (`quests/make_together.json`, flag `make_start`): Nina (Void) offers it once The Bike Boy's
    done; Bruno and Nina show you they can only make things together, and share it with you (`dialogue/bruno_alien.json`
    sets `make_taught`); make three things (`made_three`); show Nina (`make_showed_nina`). 8 sparkles.
  - Tests: new `tools/test_powers.gd` (46 checks); dialogue, quests, meetings, first_night, skate_help, player_menu,
    ui_style, controls_lock, groove, shooting and burrow pass (heather_moves fails one orchard-tree check on main too).
    Previews: `tools/capture_powers.gd` (shots in the project files under world/previews/powers).
  - My choices Hayden may change: no button for kinetic (Roll lets it go), how fast it fills, the burst's size; Make
    on Z and RB, bridges and steps (not shields), 6 s, two at once; the quest and every line (first drafts). The lore
    bible's pick: these become friend abilities you switch to when the party system arrives (plan item 26).

- 2026-11-12: **The Seer, at home in the Observatory, and the Wizard Lizard as the castle school's principal** (the lore
  bible's part 3, items 13 and 14; Hayden: "the seer still isnt in the game and needs to be added. Im thinking an old
  ... woman, but something not racist", "lets make the wizard lizard the school principal", then "only wizard lizard is
  principal, seer is just that. part of the council"). Built and tested in the cloud (own Godot user folders, no save
  touched).
  - **The Seer** (`scripts/seer.gd`, extends Townsfolk: the grown-up Earth kid body, then her own things from shapes): a
    kindly stargazing grandma. White hair in a bun, round gold glasses, little smile lines, a long skirt, a **shawl of
    night sky** whose stars drift and twinkle (`scripts/star_shawl.gdshader`) with a gold edge and tassels, a
    **clouded-glass lantern** with mist swirling inside (`scripts/seer_lantern.gdshader`) and a soft light, a crooked
    walking stick with a gold crescent moon, and **Hoot**, a sleepy owl on her shoulder who breathes and now and then
    opens one eye. Nothing of the fortune-teller costume (headscarf, coins, tent, caravan, accent), on purpose.
  - **The Observatory has an inside** (`tools/build_interiors.gd _observatory()`, `scenes/interiors/observatory.tscn`;
    the builder now takes names after `--` to build only those): the town's existing Observatory door goes there. A
    dome of slowly turning stars (the shawl's shader, bigger), the big brass telescope on its platform aimed at a slot
    in the dome, **the Council's round table** (a glowing orb, six tall chairs, one with her star cushion), her corner
    (armchair, tea, star books) and three made-up star charts (the Owl, the Teapot, the Lantern). She stands by the
    telescope (`SEER_AT`).
  - **What she says** (`dialogue/seer.json`): the first time, who she is, Hoot and the Council ("a few of us who watch
    the stars and try to see what's coming"); every third visit a chat; otherwise she **reads her lantern**
    (`"do": "Watches/Council.fortune"`, `scripts/council.gd fortune()`): the quest you follow and the step you're on,
    said her way, never anything that hasn't happened yet; a quiet evening with nothing followed. The first time after
    you've found one of her sunken bottles she talks about them (flag `seer_bottles_talked`). Flag `met_seer`.
  - **The Wizard Lizard is the principal** (`scripts/council.gd`, a "Council" node under the Watches autoload, puts it
    in at play time: no school rebuild): his office is the third office of the 3rd floor's middle row (x -7..3,
    z 0..9), renamed "Principal's Office", a PRINCIPAL sign by its door, a sign in the foyer ("Principal's Office: 3rd
    floor"), a chair, a nameplate, books, his **Nap Rock** under a heat lamp, a bookshelf, a rug, a fern and class
    pictures. He's there except while Turtle Independence is on (`Council.lizard_away()`), when he's in the Secret
    Gardens as before (`episodes.gd`: only while it's on now; his look is `LIZARD_LOOK` / `LIZARD_OUTFIT`).
    `dialogue/wizard_lizard.json`: "principal of the castle school, friend of the Seer"; a principal's hello the first
    time at school with his three rules (every version of you is welcome; no running unless something's chasing you;
    naps are allowed) pointing to the Seer, a "hello again" turtle day if you met him at school first, a "the turtles'
    helper!" hello at school if you met him with the turtles first, then tips of the day. Flag `met_lizard`.
  - Tests: new `tools/test_council.gd`; dialogue (both runs), episodes, doors, layout, sunken_secrets, following,
    later_nights and map pass. Previews: `tools/capture_seer.gd` (her on her own) and `tools/capture_council.gd` (the
    Observatory and the office); shots in the project files under characters/seer.
  - My choices Hayden may change: her look, Hoot, "The Seer" with no name, the Observatory as her home, the Council's
    table there, fortunes from the to-do list, every line (first drafts), which office is the principal's, the Nap
    Rock. The Council's other members aren't in the game (the story notes only say they "look into the future").

- 2026-11-12: **The cracks ARE the portals, the oak hums for the Divine Mind, and no more portal time limit** (Hayden,
  lore bible v2 part 3 items 1 to 4: "the crack ARE the portals", "the oak tree can be touched to get a hint of what to
  do next", "i dont want there to be a time limit on the portal worlds anymore"). Built and tested in the cloud.
  - **`scripts/crack.gd`** (no class_name, preload it): one crack model for every way between worlds. `make(colour,
    on_fall)` builds the glowing hole (lips, shaft, swirl and lights at the bottom, a "Lid" of cracked earth when shut,
    a "Fall" area that drops you through when open). `sink(g, scene)` cuts a real hole in the ground with
    `scripts/ground_hole.gd` (which can now also sink a HeightMapShape3D's points: the Earth town's ground) and lays a
    rim of broken earth with fissures over the cut. `set_open(g, k)`, `fall_in(g, player, then)`, `drop_player(g)`.
  - **Portal worlds** (`scripts/portals.gd`): every world's portal in the Void is a crack you jump into (walk in, or
    "look down the crack" and choose "Jump in!"). No rising portal, no ring. The way home in each world is a gold crack
    (`portal_world.gd`), and the Time Stone is gone. **No timer**: FREE_SECONDS, buying time with Remnants, the timer
    HUD and `time_left` in the save are all gone (Remnants stay as money). A practice trip shows only a small card.
  - **Earth** (`earth_world.gd`): from midnight to 1 AM a crack splits the ground open in front of the old oak (2.9 m
    out, the door to the Void down inside it), closing over with cracked earth at 1 AM. No crack exists before the first
    Shift it opens in (no spoilers); after that (flag `earth_crack_seen`) it's always there, shut or open. **The Void's
    Portal to Earth** (`portal.gd`) is a crack too, open in the Shift; the ring and its stone base are hidden/removed at
    run time.
  - **`scripts/divine_mind.gd`** (autoload `DivineMind`): "A voice in your mind" (never named in the game). `say(lines)`
    shows its words softly at the top of the screen a line at a time without stopping play. It speaks when a crack
    opens, when a world is mended and at the oak. **Touching the Humming Oak** (`humming_oak.gd` `touch_lines()`): the
    hum, the first time "Don't be afraid. I chose you...", then `DivineMind.hint()`: an open crack, else your current
    quest goal, else rest. It never looks ahead.
  - Tests: new `tools/test_cracks.gd`; the portal, world, Earth and First Night tests are updated for cracks and no timer.

- 2026-11-12: **New enemies, each with a boss of its own, and the Star Arena** (Hayden: "I want to make more enemies",
  "I want to add an arena with unique bosses, and challenges like slay 100 gloops etc."). Built and tested in the cloud
  (own Godot user folders, no save touched).
  - **Glorps** (`scripts/glorp.gd`, extends gloop.gd, `GLORP.make(size)`): purple Gloops that split into two littler
    ones when popped (`SPLIT_INTO` 0.66, down to `SMALLEST` 0.6), bits boing out either side. **Fizzlers**
    (`scripts/fizzler.gd`, built in code, `FIZZLER.model()`): balls of static with one big eye that zip about, crackle
    up for 0.8 s and let out a little zap ring to jump; a bubble sometimes makes them blink a few metres away.
    **Shadow ghosts** (Dark Hollow's, `shadow_ghost.gd`) now also come out at night in the Void.
  - **Where** (`scripts/wilds.gd`, autoload `Wilds`, put in at play time, no `town.tscn` change): **Glorp Meadow**
    (-58, -120, four Glorps with purple puddles), the **Static Field** (80, -218, five Fizzlers round a fizzing crack),
    and six **night ghosts** in the Spooky Woods' edge (-108, -124), once a night, fading out by morning. Both places
    are on the map. Spots checked flat, off paths and trees, 14 m+ off races.
  - **The Star Arena** (`scripts/arena.gd`, autoload `Arena`; the level `scenes/bosses/arena.tscn` from
    `tools/build_arena.gd`, everything built at load by `scripts/arena_level.gd`, like the Gloop Kingdom): its gate is
    at `GATE` (-64, -96), opens once The First Night's done ("Opening soon!" before). Inside: a round sand floor in a
    bowl of stands full of cheering little aliens, six hatches enemies pop out of, four spotlight towers whose beams
    sweep the floor, the tunnel (barred during a round), **Blip** the yellow little alien announcer and the **Round
    Board** (every round, a star for each won, best times). Talk to Blip to pick a round, see your medals, or stop one.
    - **Challenges** (`CHALLENGES`): Pop 100 Gloops (10 at a time), Glorp Splitter (40, every bit counts), Goblin
      Waves (4, 6, 8 Time Goblins), Fizzler Frenzy (25 in 3 minutes), Shadow Night (20 ghosts, lights down).
    - **Arena bosses**, only met here: **Mama Glorp** (`scripts/glorp_mother.gd`, extends gloop_king.gd: a big purple
      Glorp with a bow, splits a baby off every hit, 9 hits; after Glorp Splitter), **Big Buzz**
      (`scripts/big_buzz.gd`: a huge Fizzler high up, dives and slams a double ring, then is dazed and low enough to
      stomp or bubble, 3 hits a daze, 9 hits; after Fizzler Frenzy) and **the Gloam** (`scripts/the_gloam.gd`: a big
      shadow ghost, only solid in a spotlight beam, steers round them, so lead it in; 8 hits; after Shadow Night).
    - **The Champion's Cup**: all three bosses back to back, once all three are beaten; wins the Champion Cup hat.
    - Prizes: first win 15 to 25 sparkles and 1 to 3 Remnants (the cup 50 and 5), later wins 4 to 10 sparkles.
      Records saved as `"arena"` (wins and best time each); flags `arena_won_<id>`, `arena_met_blip`. Fainting in a
      round starts it over; leaving by the way out lands you in front of the gate.
  - Tests: new `tools/test_arena.gd` (about 90 checks) and `tools/test_wilds.gd`; gloop_king, gloop_kingdom,
    boss_versions, time_goblins, dark_hollow, layout, map, walk_through, dialogue (both runs), shooting, arsenal and
    player_menu pass. Previews: `tools/capture_arena.gd` (shots in the project files under world/previews/arena).
  - My choices Hayden may change: every name (Glorps, Fizzlers, Blip, the Star Arena, Mama Glorp, Big Buzz, the
    Gloam), the rounds and their numbers, the prizes, the unlock order, where everything is.

- 2026-11-12: **Spring before summer, Nina and Bruno, deja vu at home, and visitors who come and go** (Hayden's lore
  rewrite, lore bible v2 Part 3 items 5, 10, 12 and 16: "lets swap the order of the spring and summer worlds", "Nina
  doesnt live alone in the void anymore. she has her family and home back on earth, but she is a chosen", "bruno isnt
  chosen, but maybe him and nina get caught up with the main character when the void opens", "the memories stay the
  same but you have a bit of fuzzy deja vu memory when you go back home", "void townsfolk also have to come and go. no
  one can stay indefinitely except rook, dash and rex. Tally, and the small aliens, as well as the astronaut are void
  residents"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **The world order** (`Portals.WORLDS`, `quake_due()`): Lanternmoor, then **Glenmoor** (fifth, opens spring), the
    **Tide Reef** (sixth), **Rhythm Springs** (seventh, opens summer), then the Far Future, which now waits for all
    three of those to be mended (an old save that mended Rhythm Springs first still gets Glenmoor before the end). The
    final fight's friend sections go Heather, Otto, Melody (`chaos_trials.gd SECTIONS`); `tools/playthrough.gd` plays
    the worlds in the new order. Nothing in the worlds themselves changed.
  - **Nina** (`dialogue/nina.json`, `nina_earth.json`): in the Void she knows you from Stars Hollow, came through right
    behind you, has a watch of her own ("That means I'm chosen, like you"), and her home's on Maple Lane: the yellow
    Void house is just where the Blastoffs nap till it's time to go home. Back home after the First Night: "We're
    chosen, {player}. Both of us."
  - **Bruno** isn't chosen: he grabbed Nina's hand as the oak opened and got pulled through, with no watch
    (`bruno_alien.json` hello; `bruno.json` a new talk after the First Night, flag `bruno_caught_up`).
  - **Deja vu** (`scripts/deja_vu.gd`, "EarthTown/DejaVu"): every time you land in Stars Hollow straight from the Void
    (not the First Night's own way home, not from the Earth race circuit or the title screen) a soft lilac haze and
    blur ripples over the screen for 3.6 s (no ripple with Reduce motion) and a line says it all feels a bit like a
    dream you can still remember. Nothing is forgotten.
  - **Visitors come and go** (`routine.gd VISITORS`: Bramble, Pip, Melody, Heather, Mr. Palmer): when their "away"
    block starts or ends and you're near enough to see, a little glowing crack zigzags open at their feet, they drop
    through (or pop up) in a flash and it zips shut (`scripts/visitor_crack.gd`, group `visitor_crack`). Nina and Bruno
    nap in their Void house like the hero; Dash, Rex and Rook stay. **Tally** says it once (flag `tally_comers`): only
    Tally, the little ones and the Astronaut live in the Void for keeps, and Dash, Rex and Rook can't leave yet.
  - Tests: new `tools/test_lore_order.gd`; portals, season_unlocks, glenmoor, tide_reef, rhythm_springs, chaos_trials
    (the three worlds' quake checks and the sections' order updated), dialogue, routines, earth, first_night, meetings and
    more pass (far_future and heather_moves fail one tree check on main too). Previews: `tools/capture_lore_order.gd`
    (shots in the project files under world/previews/lore_order).
  - My choices Hayden may change: every new line (first drafts), who counts as a visitor, the crack's look, the haze
    and the four deja vu lines, the Far Future waiting for all three worlds.

- 2026-11-11: **The hero changes a little in the Void: their watch, glowing eyes and an alien feature** (Hayden: "maybe
  there is another way we can change the characters when they enter the void? Adding watches to their wrists etc",
  then "Yes to the void changes"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **`scripts/void_look.gd`** (no class_name, preload it; `scenes/player/player.gd` puts it on after `Hero.apply()`):
    in the Void (`in_void()`: any scene but Stars Hollow, the title screen and the Earth race circuit) the hero gets
    their **watch on the left wrist** (the Time Keeper once they have it, else the Shift Watch; nothing before they
    have one, and no second one if they're wearing one in the hands slot; made round the human kids' wrist, `WRIST_R`),
    **a soft glow in their eyes** (the Iris parts) and **one alien feature**: antennae, little horns, pointy ears or a
    tail (`FEATURES`), skin-coloured with glowing tips in their **Void colour** (`GLOWS`, six). Built in code on the
    head bone (the tail on the hips, swishing), in holders named "Void Look ...". On Earth they look just as made.
  - Saved in `Game.hero` as `"void_feature"` and `"void_glow"`. A hero has none until **their first time in the Void**:
    then one's picked at random and, 5 s after landing, a message says what they've got and where to change it (so the
    creator never gives the Void away before they've been: Hayden's no-spoilers rule).
  - **The creator's Void tab** (`Creator.tabs()`: only once they have a Void look): the four features as buttons, a
    line about each, and the six glow colours. While the Void tab is open the hero on the turntable shows their Void
    look, even on Earth (`Creator.previewing_void()`). Surprise me and Start over keep it (`_keep()`).
  - Tests: new `tools/test_void_look.gd`. Previews: `tools/capture_void_look.gd` (shots in the project files under
    world/previews/void_look).
  - My choices Hayden may change: the four features and how they look, the six colours, a random feature on the first
    visit, the watch showing even when they didn't put it on.

- 2026-11-11: **The story's ending: Rex's body back for good, and Dash's goodbye** (Hayden: "we can add the ending
  next", gap 2 of the game-vs-lore audit; the story docs: "Dash learns he must repair the Shift, and the cost is never
  seeing his friends again", "bittersweet with hope"). Built and tested in the cloud (own Godot user folders, no save
  touched).
  - **Quest "Loose Ends"** (`quests/loose_ends.json`, flag `loose_ends_start`): starts as the Agent of Chaos's ending
    finishes (`chaos_ending.gd _finish()`; old saves that beat him get it when the Void or the Far Future loads:
    `after_the_ending.gd start_if_due()`). Steps only say what's next: Dash's lab, then the Tomorrow Clock, then his
    letter. 20 sparkles.
  - **The lever, for good** (`far_future.gd swap_for_good()`, slice three): with his clock stopped the Swap-o-Tron's
    lever is back; the same ZAP, and at the moment the knot pulled them back last time a ring of gold and "It's
    HOLDING!" (flag `rex_home`). Rex is the boy (rook.glb) and Rook the husky from then on, in the Far Future and in the
    Void. In his own body Rex stands up and walks like a boy (`after_the_ending.gd upright()`: his twin's idle,
    walk and run from bike_boy.glb, same 17 bones, copied into that one model; Rook's crawl is untouched).
  - **Dash's twist** (`twist_lines()`, flag `dash_told`): the crack in the Shift has two ends; the far end is inside the
    Tomorrow Clock, it can only be stitched from the inside, and whoever does it stays in the furthest future when it
    shuts. Rex offers; Dash says it was his time experiment, and the Void needs Rex as its mayor one day. Then all three
    wait at the Tomorrow Clock (`_to_the_clock()`).
  - **The goodbye** (`scripts/dash_goodbye.gd`, a CanvasLayer "Goodbye" under the Far Future, like chaos_ending.gd):
    walking up to Dash on the clock's dais plays about a minute, skippable: everyone comes through (Bramble, Pip,
    Melody, Heather, Flurry, Otto as copies; Rex and Rook are the world's own), twelve lines (Dash's goodbyes, Rex,
    Pip's "it's see you later"), **Dash's Cap** for the hero (`dash_cap`, a hat: `cosmetics.gd`, shop/items.json), he
    walks into a door of light in the spire, waves, steps through, a gold beam goes up and a golden seam draws across
    the sky, then "SEE YOU LATER". Own camera, a `dash_goodbye` hold, the HUD hidden, the minimap waiting, **the portal
    trip's timer stands still and is hidden** while any cutscene plays (`portals.gd`), the gentle `chaos_ending` tune (group
    `goodbye_playing`, `soundscape.gd`). Flag `dash_goodbye`.
  - **His letter** waits where he stood in his lab (`_add_letter()`, `letter_lines()`, flag `dash_letter_read`): the
    hope (Lumen City is built where the Void is, so he's "not that far away, just LATER"; every goodbye's a
    see-you-later; the midnight tick is him saying hi, probably).
  - **After** (`scripts/after_the_ending.gd`, no class_name, preload/load it; called from `Portals._hub_changes()`): in
    the Void Rex and Rook swap models (`routine.gd use_model()`: Rex walks, Rook skates on the paw skates; new
    `dress_as` so each is dressed as whose body it is), Dash and his bike are taken out, races (`races.gd _gone_home()`)
    and delivery requests leave him out, and **Rex takes the lost watches** (`dialogue/rex.json`; `watches.gd`
    `REX_REWARD_LINES`: what Dash left ready). His gadget stall stays open. Rex, Rook and Dash have lines for each step
    and after.
  - Not done (another thread had those files): the sunken Pieces of That Night still go to Dash (`sunken_secrets.gd`),
    so after the goodbye nobody takes them; races still show Rex as the husky on paw skates.
  - Tests: new `tools/test_dash_goodbye.gd` (82 checks: nothing before he's beaten, the lever, the twist, the clock,
    the whole goodbye beat by beat and skipped, the cap, the letter, the Void after, races, requests, save and load).
    Previews: `tools/capture_dash_goodbye.gd` (shots in the project files under characters/dash/goodbye).
  - My choices Hayden may change: every line (first drafts), Rex staying in the Void (not going home with Dash), the
    cap and the letter as what he leaves, "Lumen City is built where the Void is", the door of light and the seam,
    reusing the chaos_ending tune.

- 2026-11-11: **The centipede's story goes in order, and she's only ever in one place** (Hayden: "now he is in 3 spots
  at the same time. The events need to go in order", then: walk the ceiling before the gulp, full size in the corner,
  "she can follow you to scary world", "a boss fight herself in her own world and she fully befriends you after").
  Built and tested in the cloud (own Godot user folders, no save touched). Branch `claude/centipede-order`.
  1. **The old gate** (`dialogue/scary_gate.json`): asks yes or no (recorded either way, as before), but a yes no longer
     opens it: it rattles, and a whisper says "...behind the walls... at the school... the far, far corner...". Asked
     again after a yes, it's shut with the whisper. Once Dark Hollow is mended it stands open a crack (her home).
  2. **Her school corner** (`scripts/centipede_corner.gd`): only after that yes (`CentipedeHoles.gate_said_yes()`, which
     also counts old saves' `scary_world_visited` / `dark_hollow_said_yes`). Come near and she walks along the ceiling
     over your head (`Ceiling Walk`, `scripts/centipede_walker.gd` upside down), then drops into her nest at full size
     (`NEST_SCALE` 1.0, coiled tight: `coil()`), and gulps you down to Dark Hollow on a yes. Once Dark Hollow's mended
     the corner's empty: no ceiling crawler, a "gone home!" note.
  3. **Dark Hollow** (`scripts/dark_hollow.gd`): she comes too and follows you round (`centipede_walker.gd`: her head
     follows your path a few steps back, her body follows her head; she keeps further back while the Hush is awake);
     talk to her for what to do. When it's mended she cheers, asks you to come to her home behind the old gate, and
     burrows off. The way home takes you there the first time (`Portals.go_home()`), the school's front gate after.
  4. **Her home** (`scripts/scary_world.gd`, `dialogue/centipede.json`): she's only there once Dark Hollow's mended.
     She asks to play her scary game (will you stay when she's at her scariest? yes or no, recorded as
     `centipede_scary_game`). Her **boss game** (`scripts/centipede_boss.gd`): she scuttles round you, rears up with a
     line on the ground and charges, then she's dizzy: bop her head or bubble her (bubbles boing off otherwise); from
     3 hits she also burrows and pops up under you (a ring warns you). 6 hits and she flops over giggling (flag
     `centipede_fought`), then straight into friends for keeps: her thanks, wall crawl and her holes (flag
     `centipede_gifts`), then naming her. Knock on her hollow log (`LogKnock`) to travel to Dark Hollow or any hole.
     Wall crawl and the holes now wait for `centipede_gifts` (`CentipedeHoles.gifts_given()`; old saves' "thanked"
     counts).
  - Also: Seer's bottle `seer_giant` is open-ended now ("Not everything that seems strange was always strange..."),
    and Pip's "He's asleep standing up" is "They're asleep standing up".
  - Tests: `test_scary_world` (rewritten for the order and her game), `test_dark_hollow`, `test_wall_crawl`,
    `tools/playthrough.gd` updated; portals, practice_trips, sunken_secrets, dialogue, chaos_trials, layout and
    later_nights pass. lost_watches fails one grind-rail watch check (Bolt Watch), nothing to do with this.
  - My choices Hayden may change: the boss game's story (a friendship test, "only a game"), its moves and 6 hits,
    the whisper's words, her following in Dark Hollow, the knock on her log.

- 2026-11-11: **The big map zooms, moves, and has a list of what's on it to switch on and off** (Hayden: "I want to
  rework the map with a zoom and legend with togglable icons"). Built and tested in the cloud (own Godot user folders,
  no save touched). All in `scripts/map_screen.gd` (TownMap).
  - **Zoom and move:** the mouse wheel (zooms where it points), + and -, LT / RT, or the list's − and + buttons; drag,
    WASD or the right stick move it; **Find me** (or R3) puts you in the middle. 1x shows the whole map, up to 6x
    (`ZOOM_MAX`); it opens at 2x on you the first time and remembers after (`zoom`). It never moves past the map's
    edges (`_clamp_focus`). Zoomed right out only the big labels show; small names (buildings, people, stars' quest
    names) come in from 1.6x (`names_shown()`). The place's name sits in its own strip on top, how to zoom and move
    along the bottom.
  - **"Show on the map"** (the legend, on the right, scrolls if long): a row per kind that's on this map, each with
    the map's own picture and a tick box: Quest stars, People, People at home, Places & shops, Portals, Races, Boosters,
    Watches found (`KINDS`, only the ones there are any of: `legend_kinds()`). Clicking a row (or A on it) hides or
    shows that kind on the big map and the minimap. Kept in `Settings.map_hide` (saved with the settings).
  - **Followed quests** (the Follow buttons from the following work): each quest or job you follow gets its own star
    colour (`STAR_COLOURS`, `star_colour()`), a row of its own under Quest stars so you can hide one, and its name
    under its stars when zoomed in. A quest's stars off the edge of a zoomed map show as one star on the edge with an
    arrow pointing the way. The minimap uses the same colours.
  - **A map for every place you go through a door or portal into** (portal worlds, race circuits, the Secret Garden,
    the Gloop Kingdom, the Scary World: `SNAP_FOLDERS`): the first time the map's wanted there, a picture is taken
    from straight above (`_take_snap()`: a SubViewport on the same world, an orthographic camera above everything
    you can reach, no fog, dark worlds brightened a little), over the part you can reach (`snap_bounds()`: anything
    you can walk into or talk to, the "WorldBounds" walls, a circuit's road). So a new world gets a map by itself. The
    minimap now shows there too (it's always up in a race, so the circuits have one now). Indoors still says to step
    outside. Headless runs can't take pictures, so there the map says where you are.
  - **No spoilers:** people only show once you've talked to them (`people()` `met`), races only once they're open
    (`open_tracks()`), and on Earth the old oak only shows as a portal once it's awake (`HummingOak.awake()`).
  - Tests: `tools/test_map.gd` (zoom, limits, the wheel and +, Find me, the list's rows, hiding one quest's stars,
    people met, races, a portal world). following, kid_ui, ui_style, meetings, chaos_ending, player_menu, earth and
    first_hour pass; `tools/audit_ui.gd --quick` finds nothing cut off. Previews: `tools/capture_map_zoom.gd` (shots in
    the project files under world/previews/map_zoom).
  - My choices Hayden may change: opening at 2x, which kinds get rows, the star colours, hiding people you haven't met,
    the 1.6x point where names come in.

- 2026-11-11: **A real Secret Garden, hidden behind an ivy wall** (Hayden's day 1 playtest: "the secret garden needs to
  be much larger, and it's not very secret right now; maybe we can fix that somehow"). Built and tested in the cloud (own
  Godot user folders, no save touched). The Secret Gardens on the hill (your plot, the greenhouse) stay as they were.
  - **The way in** (`scripts/secret_garden_way.gd`, node "SecretGarden" under the Farm autoload, put in at play time; no
    `town.tscn` change): a little **wren** waits up on the Secret Gardens' hill (`TRAIL`) and hops on each time you
    catch up (`CATCH_UP`), then flies down the north cliff to an **old brick wall thick with ivy** at its foot
    (`Farm.SECRET_DOOR` (-74, -75.6), facing north; checked flat, dry, 34 m off the paths, 7 m from the nearest tree)
    and pecks at the ground. Dig there for an **old iron key** (flag `sg_key`); with it the ivy parts and a little door
    opens (`sg_found`). Before that the wall is just a wall. Once found, the door shows open, it's on the map
    ("Secret Garden") and takes you in any time. Flags also `sg_wren_seen`.
  - **The garden** (`scenes/secret_garden/secret_garden.tscn` from `tools/build_secret_garden.gd`; everything built at
    load by `scripts/secret_garden.gd`): 140 by 150 m inside old ivy-covered walls. The **Rose Walk** (rose arches from
    the door, an alcove with a bench), the **Fountain Lawn** (a stone wren on the fountain), the **Hedge Maze** (a real
    7x7 maze, the same every time: seed 77), the **Lily Pond** (wade it; an island with a summerhouse), the **Giant
    Flowers** (a ring of eight, each 0.9 m higher, up to one 8.2 m up in the middle) and the **Great Tree** with a
    swing. Five **sleeping seeds** (rose alcove, maze heart, pond island, tallest flower, behind the tree,
    `sg_seed_<id>`) wake into glowing flowers as you reach them; all five wake the garden (brighter, more petals) for
    20 sparkles and 2 Remnants, once (`sg_awake`). The old door takes you home onto the ground in front of the wall.
    Loading screen "Into the Secret Garden...", and the map says where you are.
  - Tests: new `tools/test_secret_garden.gd` (the wall's spot, really following the wren, the key, the door, the size,
    really walking up the Rose Walk and through the maze to its heart, the flower hops, the seeds, waking once, saving
    inside, the way home). Previews: `tools/capture_secret_garden.gd` (shots in the project files under
    world/previews/secret_garden).
  - My choices Hayden may change: the wren and the key, where the wall is, the garden's layout and what's in it, the
    five seeds and their reward.

- 2026-11-11: **The Gloop King gets a kingdom of his own** (Hayden's day 1 playtest: "I want the gloop king to have his
  own domain instead of just being in a field"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **The Gloop Gate** (`Bosses._place_gloop_gate()`, at play time): a goo dome with gold drips, a crown and a
    "THE GLOOP KINGDOM (knock first)" sign at `Bosses.GATE` (-134, -3) in the west fields, where he used to hold court
    (checked flat, dry, 9.8 m from the nearest tree, 27 m off the nearest path). It's on the map. The King the town
    builder still puts in the field is taken out when the town loads, so `town.tscn` wasn't rebuilt.
  - **The Gloop Kingdom** (`scenes/bosses/gloop_kingdom.tscn` from `tools/build_gloop_kingdom.gd`; everything is built
    at load by `scripts/gloop_kingdom.gd`, like the race circuits): a purple sky over a bog, the **Bog Road** (a gold
    flagstone causeway between sticky goo bogs, `soft_zone.gd` kind `"goo"`: slow going, never harmful), four
    **Royal Guards** in gold helmets, the **Goo Moat** (four bouncy pads to hop, or wade), the **Palace Gate**, and the
    round **Royal Court** with goo-falls and ten courtiers watching from the stands. Everything you walk on is flush
    with the ground (the player can't step up a ledge on foot). The King sits still on his golden throne until you
    come into his court (`WAKE_RANGE`), then hops down and the usual fight is on (`gloop_king.gd`, unchanged). Popped:
    the **Royal Treasure** opens (12 sparkles, once a Void visit: flag `gloop_treasure_<visit day>`) and a goo bubble
    home appears by the throne. There's one by the way in too, any time (`go_home()`: you land on the ground in front
    of the gate, `Bosses.coming_out`). He's back on his throne next visit.
  - The First Night's king step, Rex's and Dash's lines and its map star point to the gate (`quests/first_night.json`).
    The loading screen says "Into the Gloop Kingdom...". An ammo crate moved off the gate's doorstep.
  - Tests: new `tools/test_gloop_kingdom.gd` (the gate's spot, really walking from the way in to his court, the fight,
    the treasure once, the way home, saving inside); test_gloop_king, boss_versions, first_night, soundscape, arsenal
    and `tools/playthrough.gd` now go through the gate. Previews: `tools/capture_gloop_kingdom.gd` (shots in the project
    files under world/previews/gloop_kingdom).
  - My choices Hayden may change: the gate's look and spot, the kingdom's layout and colours, the guards, 12 sparkles,
    the treasure once a visit.

- 2026-11-11: **Races get their own circuits, longer, with obstacles, eight racers and attacks** (Hayden's day 1
  playtest: "a separate instance with option to back out, restart the race", "longer, with more obstacles, more
  racers, and more powerups that attack/defend with racers that attack you"). Built and tested in the cloud (own Godot
  user folders, no save touched).
  - **Circuits** (`scenes/races/<id>.tscn`, made by `tools/build_race_circuits.gd`; re-run it only when a circuit is
    added or renamed): the Lake Loop, Meadow Wiggle, Observatory Hill and Pumpkin Run are levels of their own. Each
    scene is just `scripts/race_circuit.gd`, an Entrance and the player: the sky, ground, a 14 m road with walls and
    kerbs (one ribbon with its own collision, "Road Body"), the lake/meadow/hill/farm in the middle, scenery and a
    grandstand are built at load from the track's `Races.TRACKS` entry (`"circuit"`, `"width"`, Vector3 `"points"`
    with heights). Three laps of 460 to 540 m each. The tests check no bend is tighter than the road can take.
  - **Race gates** (`Races.HUBS`): in the Void and Stars Hollow only an arch, the starter (Zippy by the lake, Pepper
    on Maple Lane), the race board and (in the Void) Zippy's Tune-Up are left, where the old starts were
    (`race_track.gd` "hub_gate" mode). The starter offers every open race (`hub_lines()`); saying which takes you
    there (`enter_circuit()`), the race starts by itself, and the results have **Race again** and **Back to ...**
    buttons (`race_hud.gd show_choices()`). Pause > **Restart the race** / **Leave the race** any time. The clocks
    stand still on a circuit; saving there saves you back at the gate (`save_place()`). Riding off or over a wall
    pops you back on the road (`_back_on_track()`); stepping off just puts you back on.
  - **Obstacles** (`"obstacles"` per track, `race_track.gd`): bumpers (bounce you back; hay bales on Earth),
    sweepers (a turning arm; a windmill on Earth), zappers (an arc across part of the road that's on 1.3 s in every
    3.2, with a warning glow; a sprinkler on Earth) and ramps (a big hop). All of it (and every hit) is worked out in
    `scripts/race_attacks.gd`, nothing has collision.
  - **Eight racers** (seven friends; Pumpkin Run: Nina, Bruno, Ozzie, Juniper, Theo and Prue, copied from town so
    they look like themselves, `kid_look()`), you start fifth. New **power-ups**: Goo Bomb (drops a puddle behind
    you), Bubble Seeker (chases whoever's ahead) and Zap Ring (knocks everyone close round), with Zoom Star, Bubble
    Shield and Super Spring. Rivals pick up boxes too, steer round obstacles and goo, shield up, and **attack you**,
    but only now and then (`ASSIST_WAIT`: 18 / 11 / 7 s between attacks on Relaxed / Normal / Pro). A hit is a
    comedy wipeout, never damage. A track map shows on the right during a race.
  - The Hollow Run and Skyway Run stay in their portal worlds but get the new power-ups and rival attacks; the Sky
    Rings (the mothership race) are unchanged.
  - Tests: `test_races` (rewritten), `test_earth_race` (rewritten), `test_race_intros` (circuits); boosters, nights,
    later_nights, ride_upgrades, dark_hollow, far_future, map, layout, walk_through, dialogue, earth, glenmoor,
    sunken_secrets, portals, practice_trips, groove, rhythm_springs, soundscape pass (wall_crawl fails one mantle check
    on main too). Previews: `tools/capture_race_circuits.gd` (shots in the project files under
    world/previews/race_circuits).
  - My choices Hayden may change: the circuits' shapes and scenery, three laps, which obstacles go where, the new
    power-ups, how often friends attack, starting fifth.

- 2026-11-11: **Who you meet, and in what order, and a quest to meet Dash** (Hayden's day 1 playtest: "more build-up to
  meeting Dash and his gadgets via a quest", then on the order: "I don't want to lock meeting people behind days spent
  in-game ... it should not be a mystery of who to talk to next"). Built and tested in the cloud (own Godot user
  folders, no save touched).
  - **The order** (`scripts/meetings.gd`, a "Meetings" node under `FirstNight`: dialogue says `FirstNight/Meetings.*`):
    the First Night, then **The Bike Boy**, Pip's Lamps (night_2), The Meadow in Bloom (night_3), **Melody and Heather**
    (`quests/meet_friends.json`), then nights 4 to 7. Each story quest starts **as soon as the one before is done**
    (`advance()`), never waiting for a new visit, and the friend you just helped sends you on (reward messages and the
    first step's text, "Dash says...", "Pip says..."). Story quests (`"story": true`) are followed by themselves. The
    night quests keep their ids but their names no longer say "Night N", the "Night N!" landing messages are gone, and
    the Goals page says "Right now" / "Coming up". A night's schematics and held-back things come out when its quest
    starts (`Schematics.out_tonight()`, `FirstNight.held_back()`).
  - **The First Night's Void day**: no Dash at the portal. You land and **Tally** waves you over (flag `fn_met_tally`);
    their first hello sends you to Rex at the Skate Park and says Gloops pop if you jump on them. The day is a request,
    Coach Bruno's push and ollie, three Gloops and the fountain's watch. After the ollie Rex asks you to find his twin.
    The Gloop King step moved to The Bike Boy. Old saves move (`_migrate_v4()`, flag `fn_v4`).
  - **The Bike Boy** (`quests/bike_boy.json`): follow Dash's glowing gold tyre tracks from the Skate Park, pick up the
    three bits he dropped (a coil, a bulb, a cog), find him in the lab (he's out of sight till then), catch his runaway
    **Buzz Bot** (walk into it), and his **gadget stall opens**: it's shut with a "GONE TINKERING" sign till then
    (`shop_stall.gd`, `Meetings.stall_open()`; saves from before the new first day keep it open). Then the Star
    Popper's blueprint and buying it (for the weapons thread's blueprints; already ticked without them), the Gloop King
    and the Gloop Crown, and Dash sends you to Pip. Dash zooms past ("Can't stop! Experiment!") until you meet him.
    Old saves that met Dash the old way have it done (or wait on the King step).
  - **Melody and Heather**: Bramble points to Melody singing in the Market, Melody sends you for her best friend
    Heather in the green meadow, then sings her new song and sends you to Dash.
  - Tests: new `tools/test_meetings.gd`; first_night, nights, later_nights, time_watch, episodes and playthrough updated.
    Previews: `tools/capture_meetings.gd` (shots in the project files under world/previews/meeting_order).
  - My choices Hayden may change: the Bike Boy's steps, the Buzz Bot, every line (first drafts), Melody's song.

- 2026-11-11: **People really do their jobs** (Hayden's day 1 playtest: "I want characters who are performing actions
  to actually be in the locations and performing those actions (librarian climbing a ladder and grabbing a book from a
  bookshelf)"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **Routine `"do": "work"`** with `"job": "<id>"` (`scripts/routine.gd`) hands someone to `scripts/work_job.gd`: they
    walk round the job's steps in `routines/jobs.json` (in the workplace's own frame, +Z its front) over and over for
    the whole block. A step can say where to stand (`to`, `via`), what to face, a pose and for how long, climb a ladder
    first, hold a tool, and take, drop, pick or put things; a job can have `in` and `out` corners walked once. Talking
    stops them (arms down, then back to it); a time jump puts them mid-step carrying what they'd carry; when the block
    ends they put everything back. routines/README.md says how.
  - **Poses** (`scripts/work_pose.gd`, a SkeletonModifier3D put on each person's skeleton when needed): 25 of them
    (reach_high, shelve, knead, stir, sweep, hammer, saw, water, wash, rake, carry...) posed in code on the bones every
    body shares (two-bone IK for the arms, lean, crouch with the feet kept down), on top of their idle animation, eased
    in and out. **Props** (`scripts/work_props.gd`): a library ladder, book cart, kneading table, café tables, a menu
    board, crates, a sawhorse, a bucket and hose, window boxes, produce stands, a grandfather clock, flower beds and
    a watering can rest, plus things held in a hand (books, a broom, a duster, a sponge, a hammer, a saw...) or carried
    in both arms (a crate, a tray, a pie tray: raw dough going into the oven, baked coming out). Put in at play time, so
    no builder or `.tscn` changed.
  - **15 jobs:** Miss Marigold (Library: stamps books, fills her cart, shelves, climbs the ladder for a book off the top
    shelf and hands it over), Poppy (Bakery: kneads, oven in and out, fills the case, wipes up), Mr. Gumdrop (Toy
    Shop), Mr. Palmer (Earth Town Hall), Gus (diner deliveries, the menu board, sweeping), Miss Ivy (the diner's tables
    out front), Hank (sawing and hammering at the hardware store), Kip (the Corner Market's produce stands at 6 AM, the
    fire truck at 10), Dottie (the inn's window boxes), Mr. Page (bookshop cart), Mrs. Wren (antiques out front), and in
    the Void Bramble (her own flower beds by the Secret Gardens path, clear of your garden, and behind her flower stall:
    `places.json` `flower_stall` moved up to it) and Pip (lighting the Market's eight lamps at dusk).
    Patrols can strike a pose at each stop (`"stop_pose"`).
  - Tests: new `tools/test_work.gd` (every spot on its floor with room to stand, every walk goes round things, nothing on
    a path or a race line, everyone goes round their steps holding the right things, the ladder, talking, home time);
    `test_routines` and `test_townsfolk` count "near any spot of their job" for work blocks. routines, townsfolk,
    dialogue, layout, earth, earth_race, races, farming, walk_through, doors, map, first_hour and first_night pass.
    Previews: `tools/capture_work.gd` (shots in the project files under world/previews/npc_jobs).
  - My choices Hayden may change: who does what and when, every pose and prop. The castle school has no staff yet
    (plan item 30, the school overhaul), so nobody works there.

- 2026-11-11: **No weapon until you've found its blueprint and bought it, the Star Popper too** (Hayden's day 1
  playtest: "weapons should not be unlocked until you purchase them, including your starting blaster ... weapon
  blueprints being found in the world where they make the most sense (disco ball in melodys music world)").
  Built and tested in the cloud (own Godot user folders, no save touched).
  - **A new game owns no gadgets** (`Arsenal.owned` starts empty; `Arsenal.armed()`). Shoot and Aim do nothing but
    say "You haven't got a blaster yet. Jump on enemies to pop them!" (`StarPopper.no_gadget_line()`); stomping still
    pops everything. `Arsenal.current` stays "popper" with nothing owned, so code that reads it doesn't break. The first
    gadget bought goes straight into her hand. Mods at the workbench need a gadget first.
  - **The Star Popper has a blueprint** like the rest: in the Market Square at (-84, 55), a few metres from Dash's stall,
    from the first night (`Schematics.LIST` "popper", flag `schematic_popper`), and costs 3 sparkles at his stall (shop
    item `star_popper`). The "Rework quests, the job board and Dash's intro" thread is making Dash's intro quest lead
    to it.
  - **Every other gadget's blueprint is in a portal world** (`"world"` in `Schematics.LIST`, placed in that world's
    scene; `Schematics.where()`, `scene_key()`): Fizz Flinger on Shard Isle's highest islet, Buzz Bots in the
    Rootmind's tall grass (the hive), Rainbow Ray on Lanternmoor's Moon Rock (glide there), Disco Ball on Rhythm
    Springs' Dance Floor, Jelly Mines by the Tide Reef's Kelp Grotto, Plushinator in Glenmoor's Fold with the
    Fluffkins. A world's blueprint is there from your first trip, but its hint (shop note, Goals page) only names the
    world once that world's portal is open (`Schematics.hint_ready()`). None are put out on a practice trip.
  - The rides' schematics stay on their nights. The gadget lines came out of nights 2 to 7 (`quests/night_N.json`,
    `nights.gd` texts, and the friends' lines about them); night 2's Dash's-stall step (`n2_fizz`) is gone. Players see
    "blueprint" for gadgets; the code still says schematic.
  - **Old saves** keep every gadget they own (a save from before gadgets keeps the Star Popper: `Arsenal.old_save()`).
  - Tests: `test_arsenal`, `test_schematics` (every world's blueprint on the ground, clear, found by walking into it,
    bought; no hint before the portal; nothing on a practice trip) and `test_nights` updated; tests that shoot give
    themselves the Star Popper.
  - My choices Hayden may change: which world has which gadget, where in each world, 3 sparkles for the Star Popper,
    the Frozen Moment, Dark Hollow and the Far Future having none.

- 2026-11-11: **Day 1 playtest polish: sprint, skate keys, the skate lesson, oak runes, plants, grass, rails** (Hayden's
  day 1 playtest notes; other threads took the rest). Built and tested in the cloud (own Godot user folders, no save
  touched).
  - **Sprint** (`player.gd`): it only starts from a fresh press of Sprint, and stops when she's carried, rides, burrows,
    swims or wall-crawls, when she's stunned or the controls are locked, and when the window loses focus. It couldn't
    be made to stick in a test, so this is a guard; ask Hayden which actions did it if it happens again.
  - **Skate keys on PC** (`settings.gd`, `project.godot`): flip Shift, grab Ctrl, grind E (were J, K, L, under the mouse
    hand). Old J/K/L settings move over once (`skate_keys_v2`). `rebind` only counts a clash inside a button group
    (PAD_GROUPS), so on foot E (use) and on the board E (grind) can share. E steps off the board only with no rail in
    reach (`game.gd _board_button_free`).
  - **Skate lesson:** Coach Bruno runs it (the First Night checklist said "Coach Rook"). Rook's praise now fits a dog
    in Rex's human body (no tail or paws).
  - **Old oak runes** (`build_earth.gd _rune_glyph`, `RUNE_GLYPHS`): 16 made-up runic glyphs built from thin strokes.
  - **Plants don't grow through things** (`scripts/plant_clearance.gd`, preload it): as a world loads (and again at 1 s
    and 4 s, for things placed at runtime) each Void tree and plant (`trees.gd`, `foliage.gd`) and each Earth tree
    (`earth_world.gd prune_earth_trees`) checks for solid bodies and built meshes where it would be, and leaves itself
    out if so. `blocked_by` says what stopped them. Seasons keeps a left-out tree's leaves hidden (`hide_leaf`).
  - **Grass push** smaller (`foliage.gd`: reach 0.75, push 0.35 for grass; leaves and ferns 1.0).
  - **Grind rails** (`build_town.gd _town_rails`): no more scattered meadow rails; rails only beside straight path
    stretches and as boardwalk railings, never on the courts, soccer field or skate park, nor within 6 to 7 m of a race
    line (`_race_lines` reads races.gd TRACKS). Big mushrooms (solid caps) keep out of race lanes too. 22 rails.
  - New `tools/test_plant_clearance.gd`; `tools/capture_day1_polish.gd` for pictures
    (/mnt/project-files/world/previews/day1_polish/). `test_arsenal`'s Plush Party / Rainbow Ray checks are shaky: in its
    staging one Gloop ends up sitting on the other's head, and which one the shot aims at depends on tiny distances
    (main fails other checks in the same test).

- 2026-11-11: **Follow any quests and side jobs you like, the notice board tutorial, and a first look round the Void**
  (Hayden's day 1 playtest: "all quests and side jobs should be selectable allowing you to change back and forth and
  even showing multiple location markers simultaneously"; "a tutorial for the jobs board that happens at the beginning
  of the game and carries over into the void with a cutscene showing the location when you enter for the first
  time"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **Following** (`Quests.followed`, saved as `"followed"`): quests by id, board jobs by `key_of(r)` (`"req:<kind>"`
    for Tally's, `"job:<kind>"` for Earth's). Every quest card on the Quests sheet, and a new card for each of tonight's
    requests and today's jobs (`Quests.job_card()`), has a **Follow** button. Only followed things get stars on the
    map and minimap (`map_screen.gd quest_markers()`, several at once, each labelled), and the HUD's to-do list shows
    up to three (`Quests.objectives_all()`). A new quest is followed by itself only when nothing else is, so it never
    steals the player's pick; a finished quest or a paid job drops off. Unfollowing everything (`chose_none`) shows
    nothing. Jobs know where they want you (`Requests.markers(r)`: the place, the parcel, the props, who it's for,
    the board once it's done). Talking to either board ends with a choice: follow a job, "Follow them all!", or stop
    following one (`follow_choice()`). Old saves follow the quest their to-do list was on.
  - **Notice board tutorial:** The First Night has a new step `board` after the morning: Nina waits by the gazebo, the
    board (now up from a new game's first morning) has her how-to (`FirstNight.board_tutorial_lines()`), and the
    checklist is read it, follow a job, finish one and turn it in (`fn_board_look`, `fn_board_follow`,
    `fn_board_job`). Saves part way through move on a step (`migrate()`, flag `fn_v3`). Tally's first hello explains
    the Void's board the same way (flag `tally_hi`).
  - **First look round the Void** (`scripts/place_intro.gd`, `FirstNight.void_intro()`): after the arrival swirl, the
    first time only (flag `void_intro_seen`), black bars and a camera of its own glide up over the portal, across to
    the Market Square and down to Tally's board, with captions. Skippable; skipped in headless runs.
  - Tests: new `tools/test_following.gd`; `test_first_night` walks the board step; `test_kid_ui` and `test_first_hour`
    updated; playthrough does the board. Previews: `tools/capture_following.gd` (shots in the project files under
    world/previews/following).

- 2026-11-11: **A whole-game playtest, start to ending, and what it fixed** (Hayden: "Playtest"). Played in the cloud
  (own Godot user folders, no save touched).
  - **`tools/playthrough.gd`** plays the whole story as a player would, chapter by chapter: the First Night, nights 2
    to 7, Bramble's Harvest, all nine portal worlds in order (Dark Hollow through the centipede's gulp), Rex's swap,
    the Agent of Chaos's final fight with every friend's section, and the ending. Each chapter saves to
    `user://playthrough_<chapter>.json` and the next starts from it. Run `-- all` (or one chapter name) headless, or in
    a window with a folder after it for pictures. It puts Hayden's save and settings aside and back like the tests.
  - **Fixed:** that night's schematics sometimes didn't show (the board rolls the night a moment after you land, so
    `schematics.gd` now places them again when the night changes); the lake shore Remnant vein sat in the Lake Loop's
    lanes (moved to (-45, 20), and Bramble's Harvest points there; `test_races` passes again); in the final fight the
    centipede's glitch-cube tower stood so close that his chest clock poked through it and you got stuck halfway up
    (`chaos_trials.gd TOWER_OUT` 5.6). `test_first_hour`'s mouse camera check only runs with a window (it passes there).
  - The full suite passes in the cloud.

- 2026-11-10: **The Agent of Chaos's ending cutscene, and his boss music** (Hayden: "Okay lets do it", the next step
  after the friends' sections). Built and tested in the cloud (own Godot user folders, no save touched).
  - **`scripts/chaos_ending.gd`** (an "Ending" node under `ChaosFight`, a CanvasLayer like `RaceIntro`): the first time
    his chaos runs out (`chaos_fight.gd _win()`, before the flag is set) it plays about 34 s, skippable with
    Jump/Interact/Accept: his chest clock cracks and shatters into glitch cubes with a golden ring rolling out; he sinks
    down and his armour peels away till only a **small figure of light** is left, which looks at the hero and drifts
    up into motes; the **crack in the sky** over his field (the crack in the Shift) zips shut in gold; **the friends
    come through** (Dash, Rex, Rook, Bramble, Flurry, Pip, Melody, Otto, Heather: copies made for the scene, `FRIENDS`)
    and Dash, Rex, Bramble and Pip talk (`LINES`); then the title "The Agent of Chaos is sent out of time. The Void is
    safe... for now." Its own camera, a `chaos_ending` hold on the controls, the HUD hidden, and the minimap waits
    (new group `"cutscene_playing"`, `map_screen.gd`). The friends stay till you walk 30 m off. He leaves **a little
    pocket watch, stopped at midnight** in the grass (flag `chaos_watch_found`; it waits in his field on later visits
    until it's found). Who the figure was is left a mystery on purpose. A rematch win just shrinks him away as before.
  - **Music** (`tools/make_soundscape.py`): `chaos_boss` (D minor, 144 bpm, organ, ticking hats, clock-chime bells) in
    the fight (`soundscape.gd`: ChaosFight is in group `"chaos_fight"`; falls back to `gloop_king` if the file's
    missing) and `chaos_ending` (G major, slow, bells) while the cutscene plays.
  - Tests: new `tools/test_chaos_ending.gd`; `test_chaos_fight` turns the ending off (`ending.off`) and passes;
    chaos_trials, soundscape, far_future and map pass. Previews: `tools/capture_chaos_ending.gd` (shots in the project
    files under characters/chaos-giant/ending).
  - My choices Hayden may change: everything in the cutscene (first drafts), the figure of light and the watch (a hint
    that he was someone once, nothing decided), the friends' lines, both tunes. Rex and Rook swapping back for good is
    still to come (Dash says "soon").

- 2026-11-10: **The Agent of Chaos's final fight gets a section for every friend's move** (Hayden: "let's expand his
  current mechanics to include sections that require you to use all of the skills that you have learned"). Built and
  tested in the cloud (own Godot user folders, no save touched).
  - **`scripts/chaos_trials.gd`** (a "Trials" node under `ChaosFight`): all the broken time from the portal worlds is
    knotted into his clock, so between turns he throws each world's trouble back at you, in the order you mended them.
    While a section's on (`Step.TRIAL`) his clock is shut and bursts stop; doing it takes 2 chaos and leaves him dazed
    7 s with his clock glowing (`trial_over()`). His chaos can't drop into the next phase while that phase has a
    section left (`chaos_floor()`: 21, then 11, then 1). Running out of time: he tries again later; after 3 goes he
    gives it up (`TRIES`). A section only comes up once its move's learned (`learned()`), so old saves that opened the
    fight with the three bosses just get fewer. Calling the fight off resets them.
    - Phase 1: **Bramble**, the Static Storm (static round his feet buzzes you back on foot; burrow to the Root Knot by
      his feet and roots trip him). **Flurry**, the River of Melted Time (a ring of sludge, 16 `water.gd` pools, sweeps
      you back; freeze it and cross on the floes to the Frost Knot). **Pip**, Lights Out (he swallows the daylight:
      `day_night.gd` gained `eclipse`, plus a `cave_dark` zone; Pip's glow wakes three lantern stones,
      `scripts/chaos_lantern.gd`; the third is on a floating rock 5 m up and 18 m across: ride the moth swirl up holding
      Jump, then glide on Pip's moth wings, lent for the section only).
    - Phase 2: **Melody**, the Off-Beat Stomp (rings to jump; three on-beat grooves close enough and he dances).
      **Otto**, the Time Flood (the field floods 3.6 m deep; dive to the plug by his feet). **Heather**, Glitch Fires
      (put out three with April Showers, then a clock gear rises 5 m up in front of his chest: higher than a jump and a
      double jump, not a Spring Step and one, or a rainbow). **Dash**, Glitch Crystals (three shield him; bubbles
      bounce, any other gadget shatters them, `scripts/chaos_crystal.gd`; he throws you ammo).
    - Phase 3: **the centipede**, the Clock Tower (a 10 m tower of glitch cubes in front of his clock: wall crawl up it).
      **Rex and Dash**, the Big Rewind (his clock spins too fast to touch; hold up your watch and the rewind can't take
      you; miss it and time rewinds as before).
  - Fixed: grooving or a Disco Ball near him in the fight used to stop his physics (and the fight) for 4 s; he now has a
    `no_dance` meta that both skip.
  - Tests: new `tools/test_chaos_trials.gd` (70 checks: really burrows, breathes frost, rides the swirl and glides,
    swims, showers, shatters crystals with a Fizz splash, climbs the tower, checks the watch); `test_chaos_fight` turns
    the sections off and passes as before; groove, arsenal, far_future and boss_versions pass. Previews:
    `tools/capture_chaos_trials.gd` (shots in the project files under characters/chaos-giant/friend-sections).
  - My choices Hayden may change: every section's idea, which phase each is in, the lines (first drafts), 2 chaos a
    section, three goes before he gives one up, the gear and tower heights. The ending cutscene and boss music are
    still to do.

- 2026-11-10: **Rex's shot at his own body, and the way to the Agent of Chaos** (Far Future slice two, the reward).
  Hayden: "Sounds good". Built and tested in the cloud (own Godot user folders, no save touched).
  - After Rex's thank-you he heads for Dash's lab and **Rook comes through** to the Far Future (`far_future.gd
    _to_the_lab()`: both wait in the lab whenever the city's mended). The quest **Stop His Clock**
    (`quests/stop_his_clock.json`, flag `swap_try_start`) starts.
  - **The Swap-o-Tron's lever** (`_add_lever()`, `can_try_swap()`, `try_swap()`, a `swap_try` hold): Rex and Rook step
    into the pods, the coil charges and ZAP, for about three seconds each is back in his own body (the two "Model"
    children change places: `_swap_models()`, "HANDS! I've got HANDS!"). Then the Agent of Chaos's cracked clock
    flickers over the machine (`knot_clock_model()`) and snaps them back. Dash reads the machine (`swap_lines()`): the
    swap is knotted into the crack in the Shift, and the other end of the knot is the Agent of Chaos's clock. Flag
    `swap_tried`.
  - **The Agent of Chaos's fight opens** after the try (`chaos_fight.gd unlocked()`: `swap_tried`, or the three old
    boss flags as before, so old saves keep theirs). His hint now mentions the Far Future. The quest's second step is
    popping him (`beat_agent_of_chaos`, 10 sparkles); Rex and Dash have lines for after ("the knot's come loose").
  - Tests: `tools/test_far_future.gd` now checks the swap too; chaos_fight, portals, quests, dialogue and
    practice_trips pass. Previews: `capture_far_future.gd -- <folder> swap` (shots in the project files under
    world/previews/far_future_swap).
  - My choices Hayden may change: the swap only lasting a moment (his body back for good waits for the ending), the knot
    being in the Agent of Chaos's clock, opening the fight without the three bosses, Rook coming through, the quest's
    name and every line (first drafts). Next: the Agent of Chaos ending cutscene and boss music.

- 2026-11-10: **The Far Future, Dash and Rex's world** (plan item 19a world 8, the last portal world, slice one).
  Hayden: "Lets do far future". Built and tested in the cloud (own Godot user folders, no save touched).
  - **The portal** (`Portals.WORLDS` "far_future"): quakes once Glenmoor's mended, at (117, -18) just past the hedge
    behind Rex and Dash's lab, on a glowing **fault line** where their experiments cracked the ground
    (`Portals.fault_line()`, short of the hedge). Checked flat, 33 m off the nearest race, 16 m off the nearest routine
    path, 12.7 m from the nearest tree. 12 Remnants for mending it.
  - **The world** (`tools/build_far_future.gd` -> `scenes/portal_worlds/far_future.tscn`, logic
    `scripts/far_future.gd`): **Lumen City**, a neon city from the furthest future, round a city floor with the
    **Tomorrow Clock** in the middle, Dash's lab (a round lab with a gallery and a glass dome roof), the Fading Plaza
    (holo-globe fountain, a balcony up hover steps), towers, a skyline and hover-pod traffic. It's **fading**: all
    the broken time in the other worlds is catching up with it (`set_fade(k)`: the colour drains, the neon dims, the
    far towers flicker out; each copy has its own sky and materials). Three **Time Cores** bring it back, each a bit
    brighter: **Core 1** Dash's lab: fit the Swap-o-Tron's three Chrono Fuses (Interact or a bubble; one by the
    machine, one on the gallery and one on the roof, with hover lifts up: `fix_fuse()`, `lift()`), and it hums again.
    **Core 2** the **Skyway Run** (`Races.TRACKS` "skyway_run", 2 laps of a road 10 m up in the sky; Countdown, a little
    blue alien, starts it; Dash, Rex and Rook race): finish in any place. Falling off mid-race pops you back up.
    **Core 3** the Fading Plaza: six folk (Juno, Pixel, Grandpa Gizmo, Vega, Bleep, Orla) are fading out of time; get
    close or bubble them and your watch's tick pins them back (`pin()`). Found ids `met_rex`, `met_dash`, `fuse_1..3`,
    `folk_1..6`, `core_1..3`, `thanked`.
  - **Rex** (the husky body) waits by the way in, **Dash** in his lab; their lines say what to do next.
  - **Captain Glitch** (`scripts/captain_glitch.gd`), the Agent of Chaos's lieutenant: a knight of purple glitch cubes
    with a cracked clock on his chest, a flickering statue on the clock's dais until all three cores are home and you
    come within 16 m. He floats and drops chaos bursts (his master's `ChaosBurst`), then crashes down with a ring to
    jump; dazed, his clock glows and bubbles and stomps count (3 at most, then he's back up). Two Time Goblins at 3 and
    6 hits; 9 hits pops him: he shouts that his master's waiting in the Void and blinks off through a rift. The city
    comes back brighter than ever with fireworks (`mend()`).
  - Tests: new `tools/test_far_future.gd` (about 170 checks); portals, practice_trips, earth_race, time_goblins,
    chaos_fight, dark_hollow and glenmoor pass (races fails its vein check on main too; test_glenmoor now clears old
    shouts before checking one Sunfolk cheers, which failed on main too). Previews: `tools/capture_far_future.gd`
    (shots in the project files under world/previews/far_future).
  - My choices Hayden may change: the names Lumen City, Captain Glitch and Countdown, the six folk, the three cores'
    tasks, 9 hits, 12 Remnants, the portal's spot, and every line (first drafts). Slice two: the reward (Rex's shot at
    his own body back in the mended Swap-o-Tron, and the Agent of Chaos's final fight opening from it).

- 2026-11-10: **The centipede's gifts: wall crawl and her holes** (Dark Hollow slice two, the reward). Hayden: "Okay
  what is the centipedes ability?", then "Both" on the card (wall crawl as her ability, and her gulp as fast travel
  between places you've found). Built and tested in the cloud (own Godot user folders, no save touched).
  - **Wall crawl** (`scripts/wall_crawl.gd`, a "WallCrawl" node on the player like Swim): locked until Dark Hollow's
    mended. **No button**: keep walking into a wall for 0.22 s (`GRAB_HOLD`), or jump at one, and you're on it. Push
    towards the wall to climb, away to climb down, sideways to scuttle along (inside corners take you onto the next
    wall); at the top you pull yourself over (`MANTLE_UP`). Climb up into a ceiling and you carry on along it upside
    down (`Mode.CEILING`, `tumble.rotation.z` PI), dropping where it ends. Jump hops off, Roll lets go, a bump knocks
    you off. Only still, solid things (StaticBody3D / CSG) can be climbed, never the invisible walls round a world
    (`CLIMB_NOT`: names starting "WorldBounds", "Edge", "Fence", "Garden Wall", or group `"no_climb"`; `climbable()`).
  - **Her holes** (`scripts/centipede_holes.gd`, put in by `Portals._hub_changes()` -> `_centipede_holes()` once Dark
    Hollow's mended): six burrows in the Void (`HOLES`: by the Market, the Skate Park, the Secret Gardens, Observatory
    Hill, the homes' park and the castle gate; each checked flat, dry and clear of races, paths, trees and portals).
    Walk up to one and you've found it (`Portals.note_found("dark_hollow", "hole_<id>")`) and her head pops up. Knock
    (Interact) and she offers Dark Hollow, her corner in the school and every other hole you've found
    (`travel_choices()`, recorded in `Dialogue.choice_log` as `centipede_travel`), then the same cartoon gulp as her
    corner, a shorter slide and "PTOO!" (`centipede_corner.gd`'s `Gulp` gained `open_up()`): within the Void you're
    put straight there; her corner goes by `Game.go_to_point()` (`CORNER_AT`). Her corner's talk offers the holes you've
    found too (`gulp(to)`, `HOLES.arrive()`).
  - She teaches both in her thank-you (`dark_hollow.gd thank_lines()`), and talks about them after.
  - Tests: new `tools/test_wall_crawl.gd` (a climbing frame high over the Void: locked, a bump doesn't grab, up and
    over, down, sideways, Jump, Roll, ceiling and drop, fence, held controls; then the holes, finding, knocking, travel
    within the Void, to her corner and back from it). dark_hollow, burrow, swim, portals, walk_through, heather_moves and
    controls_lock pass. Previews: `tools/capture_wall_crawl.gd` (shots in the project files under
    world/previews/centipede_gifts).
  - My choices Hayden may change: no button (walk into a wall), the climb speed, ceilings, where the six holes are, the
    holes not being on the map, Dark Hollow reachable from any hole.

- 2026-11-10: **Dark Hollow, the centipede's world** (plan items 19a world 7 and 21, slice one). Hayden: "The entrance
  to dark hollow will actually be hidden until you interact with the centipede in the sliver. She will eat you and that
  will transport you there". Built and tested in the cloud (own Godot user folders, no save touched).
  - **No portal, no quake** (`Portals.WORLDS` "dark_hollow": `"portal": false`, `has_portal()`; `open_worlds()`,
    `_place_portal()` and `_land_by()` skip it, so it's never on the map). **The way in** (`scripts/centipede_corner.gd`,
    put in the school at play time by `Portals._arrived()` at "Floor 2/Behind The Walls/Centipede's Corner"): at the
    west end of the north passage (`CORNER`) the centipede drops down into her nest when you come within 9 m (the
    ceiling crawler hides meanwhile), with roots, glowing fungi and her lost-and-found nest ("my corner (plees nock)").
    Talking to her asks "Go to Dark Hollow? Yes / No", recorded both ways in `Dialogue.choice_log` as
    `dark_hollow_gulp` (flags `dark_hollow_said_yes` / `_no`). Yes: she circles you (`gulp()`, a `gulp` hold), an oval
    of black closes in with "GULP!", a ringed glowy slide ("Wheeeee..."), then `Portals.enter_dark_hollow()`. The
    timer still runs; the **way home** (`go_home`) comes out at the castle school's front gate (`"home_spawn":
    "FromSchool"`), never back through the passage.
  - **The world** (`tools/build_dark_hollow.gd` -> `scenes/portal_worlds/dark_hollow.tscn`, logic
    `scripts/dark_hollow.gd`, meta `always_night` so Pip's glow shines): a misty moonlit hollow stuck at midnight; the
    **Moon Clock** in the sky has lost three **Moon Pieces** (found `piece_1..3`). The **Ghost Glade**: eight
    **shadow ghosts** (`scripts/shadow_ghost.gd`, our own design: inky teardrops with glowing eyes that skitter,
    flicker and sometimes dodge a bubble; a stomp, a roll or a bubble pops them into a wisp; found `ghost_1..8`): all
    eight bring out the first piece. **The Big Hole** in the middle: fall in and it spits you out (`spit()`) on top of
    the 14 m **Crooked Spire** (the second piece), then round three little spouts (`SPIT_ORDER`). **The Hollow Run**
    (`Races.TRACKS` "hollow_run", 2 laps round the hollow; Pip starts it, Rook, the Green Man and Dash race; a starter
    can now have a `"scale"`): finishing in any place gives the third piece.
  - **The Hush** (`scripts/the_hush.gd`): a big shadow ghost asleep on Hush Hill until you come within 16 m with all
    three pieces. In the dark it's only shadow (bubbles and stomps go through); within 6 m of a lit **moon lamp** (four
    round the hill, `lights_hush()`, Pip's glow counts too) it goes pale and can be popped. It hushes out lamps it gets
    right up to (light them with Interact or a bubble; they come back after 14 s), darts off after each hit, breathes a
    "Shhhh" ring to jump every 7 s and calls little ghosts at 3 and 6 hits. 8 hits mends the hollow (`mend()`): 8
    Remnants, the clock ticks on, the stars come out, and the centipede's your friend (flag `dark_hollow_friend`; in her
    corner she says so after).
  - Tests: new `tools/test_dark_hollow.gd`; portals, practice_trips, earth_race, scary_world, lanternmoor,
    glimmer_caves and doors pass (races and layout fail the same checks on main too). Previews:
    `tools/capture_dark_hollow.gd` (shots in the project files under world/previews/dark_hollow).
  - My choices Hayden may change: the corner at the end of the passage that's there (not a new twisting Sliver), the
    Moon Clock and its three pieces, the Hush and its lamps, Pip starting the race, 8 Remnants. The old Scary World
    gate is unchanged. Slice two (her gifts) is the entry above.

- 2026-11-10: **The Season Dial** by the old oak (story flag 48: each season's unlocked once, then you can switch to
  any season you've opened). Hayden picked it from the "what's next" card. Built and tested in the cloud (own Godot
  user folders, no save touched).
  - **`scripts/season_dial.gd`** (node "SeasonDial" under the EarthTown autoload): an old stone sundial grown up out of
    the oak's roots at `DIAL_AT` (-14, 5), beside the old oak, facing the green (off every path, nothing solid round it).
    Its brass face has a quarter per season in its colour with a sign (blossom, sun, leaf, snowflake); a locked season's
    quarter is frosted over and dim. It only shows once a second season's open and the oak's awake (`available()`), and
    the first time it appears a message says so (flag `season_dial_seen`). Interact asks which season (every open one but
    this one, and "Leave it"); the pointer spins round, the screen washes over in the season's colour, and Stars Hollow
    is loaded again where you stood (`Game.go_to_point`), so every seasonal thing is set up fresh. Today's notice board
    jobs are paid if finished and picked again for the new season.
  - **`Clock.dial_to(season)`**: moves the calendar on a whole season at a time (never back) to the same date and
    weekday in that season; the year goes up when it goes round. Left alone, the calendar runs on as before.
  - The Calendar sheet says where the dial is ("Dial hint"); Nina has a line after you first turn it (flag
    `season_dial_turned`). Nina's three seasonal quest offers now come before her other lines in her file.
  - Tests: new `tools/test_season_dial.gd`; dialogue, season_unlocks, calendar, seasons, winter, summer, spring,
    notice_board, first_night, player_menu, quests, townsfolk, earth and ui_style pass (first_hour fails one Void camera
    check on main too). Previews: `tools/capture_season_dial.gd` (shots in the project files under
    world/previews/season_dial).
  - My choices Hayden may change: where it stands, its look, moving the calendar forward (not back), reloading the town.

- 2026-11-10: **Spring in Stars Hollow: the quest "Duckling Day", puddles, and a spring sun** (Hayden: "Okay let's work
  on earth spring now"; spring's lines, tulips and jobs came with Glenmoor). Built and tested in the cloud (own Godot
  user folders, no save touched).
  - **`scripts/duckling_day.gd`** (a "DucklingDay" node under `EarthTown`, `quests/duckling_day.json`): only in spring.
    Nina offers it once The First Night's done: a shower in the night scattered Mother Duck's five ducklings round town
    (`LOST_AT`: by the gazebo, in the playground, outside the bakery, by the footbridge, in the Tulip Field). Walk up to
    one and it falls in behind you; they follow in a line along the path your feet took (`_trail`, `SPACING`). Lead
    them to Mother Duck on Willow Pond's east bank (`MOTHER_AT`), then the whole family paddles round the pond in a line
    for the rest of spring (`SWIM`). Then jump in three **puddles** on the green with Nina (`PUDDLES`; landing in one
    splashes it any time in spring) and share honey buns with Poppy at Crumb & Cauldron. 12 sparkles. Flags
    `duckling_day_start`, `duckling_1..5`, `ducks_home`, `puddle_1..3`, `spring_buns`. Poppy's bun line comes first in
    her file so it plays even if you've never met her.
  - **The spring sun** (`earth_world.gd SPRING`): higher and brighter than autumn's, a soft pale blue sky, up from 5:30
    AM till 7:30 PM. Willow Pond is clear (`seasons.gd SPRING_POND`) and its Halloween mist is gone in spring, as in summer.
  - Tests: `tools/test_spring.gd` now checks the sun and Duckling Day all the way through (every spot outdoors on dry,
    open ground). Previews: `tools/capture_spring.gd` (shots in the project files under world/previews/spring).
  - My choices Hayden may change: ducklings as the spring quest, where they hide, the puddles, honey buns, the sun.

- 2026-11-10: **Glenmoor reworked to day and night, Heather's spring moves, her orchard and spring in Stars Hollow**
  (Glenmoor slice two). Hayden: "my idea with glenmoor was that it would be a sort of continuous looping between day
  and night with factions that prefer both warring over the unpredictable cycle", "we stripped Heather of her
  growing/healing ability to give it to bramble", then "Lets do April showers and the spring step. I want there to be a
  sort of yin and yang theme and after the boss is defeated, the day and night cycles return to normal". Built and
  tested in the cloud (own Godot user folders, no save touched).
  - **Day and night loop** instead of the seasons spinning (`glenmoor.gd set_daylight(k)`, `day_k` 0 noon, 0.5
    midnight; `DAY`/`DUSK`/`NIGHT` looks: sky, fog, sun, ambient, grass and rowans; a moon and stars, "Night Sky").
    **The flux:** `_loop()` picks a new speed every 2 to 5 s, sometimes backwards (`FLUX_SPEEDS`, `BACKWARDS`), a whole
    day in `CYCLE` 10/14/20/28 s by charms. The card says Day, Dusk, Night or Dawn. Snow caps are hidden for good.
  - **Two sides** (`_add_camps()`): the **Sunfolk** (Heather's, by the croft: Goldie, Barley, Sunny Jim, gold banner)
    and the **Moonfolk** (Isla's, up the glen: Morag, Wee Dougal, Nessa, night-blue banner with a crescent), townsfolk
    bodies in their side's colours. Whose time comes round cheers over their heads, the other side grumbles
    (`_cheer()`); each has lines (`folk_lines()`). Heather and Isla are still best friends, on opposite sides.
  - **Three Balance Charms** (ids still `bell_1..3`): the **Sun Charm** (the Fluffkins, for Heather), the **Twilight
    Charm** (the shared garden: sunflowers on beds 1, 3, 5 open by day, moonflowers on 2, 4 open in the dark,
    `is_moonflower()`, `grow_phase()` from the daylight; sing to each while it's open) and the **Moon Charm** (the
    hill race, for Isla). The Stormram's unchanged.
  - **Mended:** the loop eases into a normal day (`NORMAL_DAY` 240 s, steady, from a spring morning), the camps' banners
    come down and a **yin and yang Peace Banner** goes up between them (`_make_peace()`, `PEACE_AT`), everyone gathered
    round it. Spring still opens on Earth.
  - **April Showers** (`scripts/showers.gd`, a "Showers" node on the player): H, or **hold Interact** with nothing in
    reach (no pad button: all taken). A rain cloud comes over the hero for 2.5 s and follows them, then a solid
    **rainbow** arches 14 m ahead the way the camera looks, 3 m high, walkable, for 20 s (two at once). Rain waters
    your Void garden (no faster growing: that's Bramble's) and cools Rhythm Springs' heat. `{showers_how}` in lines.
  - **Spring Step** (`scripts/spring_step.gd`, a "SpringStep" node): no button. Jump again within 0.2 s of landing (the
    jump buffer counts) and it goes 1.3x higher, a third in a row 1.65x with a flip (`player.gd` asks `bound()`).
  - Both locked until Glenmoor's mended (`Settings.SECRET_ACTIONS` "showers"); Heather teaches them in her thank-you.
    The first try, a grow move (`grow.gd`), is gone: growing's Bramble's.
  - **Heather's Blossom Orchard** in the Void (`Portals._blossom_orchard()`, `ORCHARD` (-125.5, -61.5) since 12 Nov, beside Glenmoor's
    portal): nine blossom trees, two Fluffkins, petals and a sign; Heather mentions it in town.
  - **Spring in Stars Hollow** (like summer and winter): 33 spring copies of Earth conversations (the autumn ones now
    say just `"autumn"`); `seasons.gd`: tulips at the pumpkin and scarecrow spots ("Spring Tulips"), the patch sign
    says "Tulip Field", pastel lights and bunting; notice board (`earth_jobs.gd r.spring`): plant tulip bulbs round a
    house ("bulb" props: a tulip pops up), rhubarb for Poppy, rhubarb crumble. No spring quest yet.
  - Tests: new `tools/test_heather_moves.gd` and `tools/test_spring.gd`; `test_glenmoor` rewritten for day and night.
    Previews: `tools/capture_glenmoor.gd` and `tools/capture_heather_moves.gd` (shots in the project files under
    world/previews/glenmoor_daynight and world/previews/heather_moves).
  - My choices Hayden may change: the folk's names and looks, the flux speeds, which task is which charm, the Peace
    Banner, H and hold Interact, the rainbow's size and time, the Spring Step window and heights, the orchard's spot.

- 2026-11-10: **Glenmoor, Heather's world** (plan item 19a world 6, slice one). Hayden: "Lets do glenmoor".
  Built and tested in the cloud (own Godot user folders, no save touched).
  - **Heather:** the cattle girl is called Heather everywhere the player sees (her talk name, race rider name, town
    display name). Her id stays `clover` (dialogue/clover.json, routines, outfits), so saves are untouched.
  - **The portal** (`Portals.WORLDS` "glenmoor"): quakes once the Tide Reef's mended, in the meadow past the farm, west
    of the Secret Gardens, at (-120, -48) (flat, 88 m off the nearest race, 37 m off the nearest routine path, 8 m from
    the nearest tree, 23 m from the Undergardens' Rootwell). 11 Remnants for mending it, and mending it **opens spring**
    on Earth (its `"season"`).
  - **The world** (`tools/build_glenmoor.gd` -> `scenes/portal_worlds/glenmoor.tscn`, logic `scripts/glenmoor.gd`): a
    misty highland glen of dry stone walls, rowan trees, heather and gorse, a wee loch, Heather's croft, barn and
    garden, the Fold (a round stone pen), the Standing Stones and **Ben Bonnie**, a big hill with six cairns spiralling
    up it. **The seasons spin**: spring, summer, autumn, winter round and round (`set_season(k)`: grass, leaves, hills,
    sky, fog, sun, snow caps in winter; each copy has its own materials and sky), a season card under the portal timer.
  - **Three Spring Bells**, each slowing the spin (4, 6, 9 then 14 s a season): **herd the five Fluffkins** (fluffy
    sheep-ish critters that trot away from you, so walk round behind; they only get into the Fold through its gate:
    `fluff_step()`, found `fluff_1..5`), **sing to Heather's plants in full bloom** (five beds that sprout, bloom and
    wilt every 8 s; Interact while one's in bloom keeps it that way: `tend()`, `bed_1..5`) and **race Isla up Ben
    Bonnie** (past the six cairns in order before she gets to the top: `start_race()`, a 3 s countdown with a
    `hill_race` hold). Found ids also `met_heather`, `met_isla`, `bell_1..3`, `thanked`.
  - **Isla**, Heather's best friend from up the glen (working name and look: the cow body in shaggy ginger with a red
    scarf, Scottish; Heather stays Southern as in her town lines).
  - **The Stormram** (`scripts/stormram.gd`, extends `crocodillo_boss.gd`, which gained `title`, `minion_name` and
    `bar_colour`): the Boulderdillo's wild highland cousin, wool and curly horns over its shell and its own storm
    cloud, asleep on the Standing Stones until all three bells ring and you come within 18 m. It curls up and charges
    in a **whirlwind** (see-through spinning cones), each charge ends in a gust ring to jump, and its wool's too thick
    for bubbles or stomps until it's dizzy. Rolling into it bounces you off unless it's dizzy. Squalldillos (little
    ones with cloud puffs) at a third and two-thirds. 8 hits. Popping it mends the world (`mend()`: the seasons settle
    on spring, blossom bursts from the rowans, Heather thanks you) and doesn't set `popped_boulderdillo`.
  - Tests: new `tools/test_glenmoor.gd`; portals (now checks the Far Future as the unbuilt world), boss_versions,
    practice_trips, dialogue, season_unlocks, routines and tide_reef pass (races fails one vein check on main too).
    Previews: `tools/capture_glenmoor.gd` (shots in the project files under world/previews/glenmoor).
  - My choices Hayden may change: Isla's name and look, the Fluffkins, the three bells and their tasks, the hill
    race, the Stormram's numbers, 11 Remnants, the portal's spot. (Slice two reworked the spinning seasons into day and
    night: see the entry above.)

- 2026-11-10: **The Undergardens**, caves under the Secret Gardens hill in the Void (Hayden: "I want to make some of the
  secret garden caves as well", next to Lanternmoor's caves). Built and tested in the cloud (own Godot user folders, no
  save touched), on top of the shared cave pieces from the Lanternmoor thread (`scripts/cave_kit.gd`,
  `scripts/pip_glow.gd`), so both sets of caves look and work the same.
  - **`scripts/garden_caves.gd`** (node "Caves" under the Farm autoload: dialogue says `Farm/Caves.hand_in`): put in
    at play time, nothing in a builder or `town.tscn` changed. The way in is **the Rootwell** at (-97, -46) on top of
    the hill west of the greenhouse: the ground is cut (`scripts/ground_hole.gd`), a ring of fat roots round it, a sign.
    Until Lanternmoor's mended (Pip's glow) a tangle of roots covers it and peering in says it's too dark. A spiral of
    16 root steps goes down the shaft. One loop of caves (`SHAPES`, cave_kit build, about 0.3 s, built each time the
    Void loads) under the whole hill, at least 0.9 m of rock under the ground everywhere: the **Root Hall** under the
    greenhouse (roots with eyes through the ceiling, moth-dust steps that only Pip's glow shows up to a root ledge),
    the **Mushroom Grotto** (four giant caps to climb to a shelf), the **Crystal Pool** (deep water round an island:
    float or swim), the **Deep Crack** (a pit with a pillar in the middle, glow bridges out to it; falling in floats you
    back), and **the Taproot's Hollow**, back to the shaft. A `cave_dark` zone covers it all and the sun's kept off the
    rock (`shade_from_sun`). Big Gloops' homes near the hole are moved 13 m away, and any enemy in the cave is sent home.
  - **The Old Taproot**, the hill's oldest root, asleep with his eyes shut; Pip's glow reaching him wakes him
    (`scripts/taproot_waker.gd`, group `glow_wake`). Quest **The Undergardens** (`quests/undergardens.json`): find the four
    Glowcap spores (walk into them), take them to him; he gives 3 **Glowcap** seeds (new crop in `Farm.CROPS`, look
    "mushroom", glows a little always and properly when ripe, 600 Void minutes, sells for 9 at the Fruit stall; no stall
    sells the seeds) and 15 sparkles. Bramble tells you about the caves once Lanternmoor's mended and the garden's
    yours; going down there starts the quest too. Flags `undergardens_start`, `ug_spore_hall/grotto/pool/chasm`,
    `ug_taproot_woken`, `ug_taproot_met`, `ug_taproot_given`, `ug_bramble_thanks`.
  - Tests: new `tools/test_garden_caves.gd`. Previews: `tools/capture_garden_caves.gd` (shots in the project files
    under world/previews/garden_caves).
  - My choices Hayden may change: the name Undergardens, where the Rootwell is, the rooms, the Old Taproot and his
    lines, the Glowcap crop and the reward.

- 2026-11-10: **Pip's glow and the Glimmer Caves** (Lanternmoor slice two, the reward). Hayden: "Next I want to add
  large intricate caves to pips world for when you gain his ability" and "make pips ability". Built and tested in the
  cloud (own Godot user folders, no save touched).
  - **Pip's glow** (`scripts/pip_glow.gd`, a "PipGlow" node on the player like Burrow): locked until Lanternmoor is
    mended. **No button** (every pad button is taken, and it's kinder for small hands): it comes on by itself inside a
    `"cave_dark"` zone (a warm light 9 m round the hero, motes of light circling) and softly at night out of doors in
    the Void and on Earth (5 m). In a cave the screen's edges go dark (a "Cave Dark" vignette), nearly black without
    it. Groups it drives: `"glow_reveal"` (only there while the glow reaches it), `"glow_solid"` (only there and solid
    while it reaches: glow bridges grow ahead of you), `"glow_wake"` (`glow_wake()` the first time it reaches:
    `scripts/glow_crystal.gd`, crystals that wake and keep shining). `shining()`, `lights(pos)`.
  - **`scripts/cave_kit.gd`** (shared, no class_name, preload it; the Secret Gardens caves use it too): caves from
    rooms, tunnels and shafts (a signed distance field turned into a mesh and a trimesh at load: about 0.4 s for the
    whole Glimmer Caves), rock that never sees the sun (render layer 11, `shade_from_sun()`), `dark_zone()`, and
    stalactites, crystals, mushrooms, glow moss and glow bridges.
  - **The Glimmer Caves** (`scripts/glimmer_caves.gd`, put in by `lanternmoor.gd open_caves()` once it's mended): a
    hollow opens in the moor behind the way in at (8, 37) ("The Glimmer Caves" sign, standing stones), and under it 7
    rooms joined in loops: the Moth Hall, the Crystal Gallery, the Chasm (a glow bridge over a pit), the Echo Pool (a
    lake 30 m down), the Mushroom Grotto (bouncy mushrooms), the Moonroot Chamber (a cache: 3 Remnants) and Lantern
    Roots, reached by the Gloomie Squeeze (shy Gloomies scurry from the glow). **Moth lifts** (hold Jump in the
    swirl) carry you up the hollow and out of the pit. Five lost **moonmoths** only show in the glow (found
    `moth_1..5`); all five: 6 Remnants and 10 sparkles. Pip teaches the glow as the sun comes up
    (`_teach_glow()`, `teach_lines()`), and talks about the caves after.
  - `scripts/ground_hole.gd`: a big triangle that only grazes a hole is now split into small bits first (`_fine`,
    `FINE` 0.6 m) instead of dropped whole, so a second hole near an earlier one (the hollow by the Moon Well) no
    longer tears the ground open between them.
  - Tests: new `tools/test_glimmer_caves.gd` (54 checks); lanternmoor, sunken_secrets (its paving check now samples
    off the paving's seams), portals, practice_trips, burrow, groove, swim, layout, walk_through, player_menu,
    dialogue, frozen_moment, rhythm_springs, rootmind and tide_reef pass. Previews: `tools/capture_glimmer_caves.gd`
    (shots in the project files under world/previews/glimmer_caves).
  - My choices Hayden may change: no button (automatic glow), its reach, the rooms and their names, the Gloomies,
    6 + 3 Remnants, where the hollow is. Pip is they/them (Hayden, Nov 10: "Pip is sort of androgynous").

- 2026-11-10: **Sunken secrets** at the bottom of deep water, for swimmers. Hayden: "Can we bury some secrets underwater
  in most places? Maybe a watch or ... something that has meaning or impact on the lore", then "How about all of these"
  to my three ideas. Built and tested in the cloud (own Godot user folders, no save touched).
  - **`scripts/sunken_secrets.gd`** (node "Sunken" under the Watches autoload, like the Lab: dialogue says
    `Watches/Sunken.hand_in`): 24 secrets, one of each of three kinds in each of 8 places. **Pieces of That Night**
    (bits of Rex's pods and Dash's time core; each plays an echo of the lab night; Dash collects them,
    `dialogue/dash.json`, and with all eight works out that both experiments together cracked the Shift: 6 Remnants
    and 20 sparkles). **Watches of the First Chosen** (kids chosen long before Nina who went home safe and left their
    watches in deep water; all eight: 5 Remnants). **Seer's Bottles** (vague notes from the future seer; all eight: a
    last note and 5 Remnants). Read out with `Dialogue.say` when you swim down to one (`reached()`: only while
    swimming, so floating on top before the Tide Reef's mended isn't enough). Found ones are flags `sunk_<id>`,
    `sunk_given_<id>`, `sunk_pieces_done`; when-keys `sunk_to_give`, `sunk_given`; word `{pieces_given}`.
  - **Where:** the flooded Tide Reef and Willow Pond's deep middle lie on their own beds (`NATURAL`; a secret only
    shows with 2 m of water over it, so the reef's turn up once its sea's in). Everywhere else a **deep pool** is put in
    at play time (`POOLS`, `build_pool()`), **sunk into the ground** (Hayden: "Could you just bury the current
    pools?"): `scripts/ground_hole.gd` cuts a round hole through whatever ground is there, on copies (the Void's
    terrain mesh and trimesh lose the triangles touching it, so its edge is ragged; a portal world's round slab floor
    is made again with a neat hole, and Shard Isle's rock cone has its side pushed out round the basin; little things
    in the hole are hidden, and foliage instances shrunk away). Then a round stone basin 3.4 m across inside sits in
    it: 3.6 m of water with its surface 0.15 m under the ground, a ring of paving over the cut edge following the
    ground (out to `meta rim`), a ledge inside to stand on and jump out from, a glowing floor and its name on a sign.
    You walk straight in. Headless runs keep no mesh data, so only the collision is cut there. The Void's
    **Wishing Well** at (50, -66) by the Portal Plaza, Shard Isle's **Crystal Basin**, the Rootmind's **Dew Cup**, the
    Frozen Moment's **Thaw Pool**, Lanternmoor's **Moon Well**, Rhythm Springs' **Deep Spring**. Each spot checked
    flat and clear (the Void's off races, paths, trees, portals and the plaza's friends). Otto's plaza lines hint at it.
  - Tests: new `tools/test_sunken_secrets.gd`. Previews: `tools/capture_sunken_secrets.gd` (shots in the project
    files under world/previews/sunken_secrets).
  - **All the lore in them is my first draft** (story/flags-to-review.md flag 59): earlier chosen ones, Walter Hollis of
    1893, Otto's Grandad's watch, and the seer's hint that the Agent of Chaos was someone once. Not done: a Bag page
    listing them (the count shows each time you find one); Glenmoor, Dark Hollow and the Far Future aren't built yet.

- 2026-11-10: **Otto's swimming, the Tide Reef's reward** (19a world 5, slice two). Hayden: "Maybe a quest that starts
  above water and allows you to unlock [Otto's] ability that allows you to swim underwater?" Built and tested in the
  cloud (own Godot user folders, no save touched).
  - **The quest:** slice one stays above water. After his thank-you Otto blows a bubble round your head and teaches you
    to swim (`tide_reef.gd teach_lines()`, found `swim_taught`), then the sea pours in over 10 s right over the houses
    and the spire (`start_flood()`, `set_flood(k)`: a scripts/water.gd node "The Sea" up to `SEA_TOP` 13 m, its surface,
    light shafts, bubbles streaming up, fish swimming loops). A mended reef is always flooded. Five **sea lanterns**
    drifted in high up (`LAMPS`, found `lamp_1..5`): swim to each and it lights; then **Grandad's chest** washes into
    the Deep Basin (found `chest`: 4 Remnants and 10 sparkles, once). Under the sea Otto's bubble floats up and down
    with you, and the bubble steps and bubble ride are put away. The reef's fence is now 18 m tall.
  - **Swim** (`scripts/swim.gd`, a "Swim" node on the player like Burrow): any scripts/water.gd water out of her depth
    (1.45 m+) takes over her physics. Before the Tide Reef's mended she just floats up and paddles along the top (nobody
    walks along the bottom). After: hold Jump to swim up, hold Roll to dive, steer as on foot, slow and floaty; she
    stays at whatever depth she's left at; at the top Jump hops her out. No new button and **no breath meter: nobody
    drowns** (my choice). Under: Otto's bubble on her head, bubbles trailing up, the camera comes down closer
    (`CAM_DROP`), and whenever the camera's under water the view goes blue-green and wobbly
    (`scripts/underwater.gdshader`, no wobble with Reduce motion), the fog thickens and sound is muffled (a low-pass on
    Master, taken off again).
  - **Willow Pond** has a deep middle now (`EarthLand.POND_DEEP`, about 3.2 m of water, out past the dock's end).
  - **Otto in the Void** (`Portals._otto_in_hub()`): on the Portal Plaza across from Flurry, with his own lines
    (`otto_hub_lines()`, found `otto_in_hub`). I looked for room for a reef pool by the lake (the old slice two plan):
    nowhere near it is flat and clear of paths, races and trees. The Void's lake is only about 1 m deep, so you wade
    there; deepening it means rebuilding the town's ground (an LFS file), so from the PC.
  - Tests: new `tools/test_swim.gd`; `test_tide_reef.gd` now checks slice two too. Previews: `capture_tide_reef.gd --
    <folder> swim` (shots in the project files under world/previews/tide_reef_swim).
  - My choices Hayden may change: the name Swim, no breath meter, the sea's height, the five lanterns and the chest's
    reward, Otto on the plaza, Willow Pond's depth.

- 2026-11-09: **The Tide Reef, Otto's world** (plan item 19a world 5, slice one). Hayden: "Lets try the next part".
  Built and tested in the cloud (own Godot user folders, no save touched).
  - **The portal** (`Portals.WORLDS` "tide_reef"): quakes once Rhythm Springs is mended, by the lake's south-east
    shore at (50, 28) (flat, clear, 13 m off the nearest race track, 22 m off the nearest routine path, 10 m from the
    nearest tree), facing the lake. 10 Remnants for mending it. No season (the one left, spring, is Glenmoor's). The
    west shore was tried first: one spot sat on a routine path and the next had a tree growing through it, so the
    test now checks `routines/places.json` links and the Trees' `positions` too (trees have nothing solid).
  - **The world** (`tools/build_tide_reef.gd` -> `scenes/portal_worlds/tide_reef.tscn`, logic `scripts/tide_reef.gd`):
    a reef town of coral houses, bubble lamps and shell paths that should be under the sea. The tide's stuck out: a
    dusty sky, dry cracked tide pools, pale corals, a stranded boat. `set_tide(k)` takes everything from stuck out (0)
    to back in (1): sky, haze, corals (materials named "Coral N"), pool water rising, bubbles and leaping fish; the
    pools only become water to wade in (`scripts/water.gd`) once it's right in.
  - **Otto the octopus** (a working name and my own look: orange, goggles pushed up, in a bubble chair he blew
    himself). From the story notes: he has a disability, thinks he's no use, and his strengths turn out to be the
    answer. In the game his bubble chair only floats along when a friend goes with it, so once you've said hello he
    follows you (`otto_goal()`), and nothing only he can do works until you've met him and he's caught up
    (`_need_otto()`). Nothing about him is "fixed" at the end: he still needs a friend, and he knows he was never no
    use (`proud_lines()`). **The story notes say to get input from disabled advisors: his lines are a first draft.**
  - **Three Tide Pearls:** the **Clam Vault** (eight latches that must turn at once: he has eight arms,
    `open_vault()`), the **Kelp Grotto** (three deep holes: you're the eyes, one has a glint and the others have eyes
    blinking back; he's the reach, `try_hole()`; a wrong hole finds a boot or a cross crab, nothing's lost) and the top
    of the **Coral Spire** (at the Bubble Pad he blows eight bubble steps up it, `blow_steps()`; each pops 2 s after
    you land on it and he blows it again 2.5 s later; then a bubble carries you down along the `BubbleRide` path,
    `ride_bubble()`, carried like the zipline). Found ids: `met_otto`, `pearl_1..3`, `vault_open`, `rode_bubble`,
    `thanked`.
  - **The Riptide Gloop** (`scripts/riptide_gloop.gd`, the Gloop King's scene in sea-blue with a coral crown, asleep
    in the Deep Basin, swollen with the tide): wakes when you come near with all 3 pearls. It's too slippery to pop
    (bubbles slide off, stomps bounce) until Otto, from his perch at the basin's edge, wraps his arms round it and
    holds it still (`grab()` -> `hold()`: 5 s into the fight, then 5 s held every 11 s); held, it can't move or bump
    you, and 6 hits pop it. Between holds it flops waves, calls Splash Gloops and now and then sucks the water in (a
    riptide that drags you along the ground for 2.2 s; jump to break free). Popping it mends the world
    (`mend()`: the tide comes in over 6 s) and doesn't set `popped_gloop_king`.
  - Tests: new `tools/test_tide_reef.gd` (147 checks); portals (now checks Glenmoor as the unbuilt world),
    practice_trips, groove, season_unlocks, rhythm_springs, frozen_moment, gloop_king, boss_versions, layout and
    walk_through pass. Previews: `tools/capture_tide_reef.gd` (shots in the project files under
    world/previews/tide_reef).
  - Builder gotcha: the builders' `cyl()` snaps heights to 0.1, so a 0.04-high disc became a cylinder with no height
    (no normals, a warning each, and invisible). `build_tide_reef.gd` keeps at least 0.04.
  - My choices Hayden may change: Otto's name, look and lines, the three pearl puzzles, the hold and riptide timings,
    the portal's spot, 10 Remnants. Slice two still to do: the reward (Otto joins you with a reach-and-grab ability,
    and a reef pool by the Void's lake). The plan's "bubble-ride race" became the bubble ride down the spire.

- 2026-11-09: **Summer in Stars Hollow** (Rhythm Springs' reward on Earth, like the winter overhaul). Hayden: "Lets do
  summer in stars hollow replace all the winter themed things with summer themed and make the sun bright and whatever
  else you can think of". Built and tested in the cloud (own Godot user folders, no save touched). Winter is unchanged.
  - **Lines:** every Earth conversation that had autumn and winter copies now has a summer one too (`"season":
    "summer"`: the Summer Fair, lemonade, ice lollies, sunflowers, swimming, no school); the autumn ones say
    `["spring", "autumn"]`. 17 dialogue files, 35 conversations.
  - **The town** (`seasons.gd`): a sunflower (`sunflower_model()`, static) at each ground-level pumpkin and scarecrow
    spot, the patch sign says "Sunflower Field", sunny string lights and bunting (`BULBS_SUMMER`, `BUNTING_SUMMER`),
    Willow Pond clear blue with no Halloween mist, dandelion fluff in the air by day ("fluff"), fireflies from 9 PM.
  - **The sun** (`earth_world.gd SUMMER`): higher (74 degrees at noon), brighter (1.45, autumn 1.15) and whiter, a bigger glow in
    a deeper blue sky, and long days: the sun's up from 4:30 AM till 9 PM.
  - **Notice board** (`earth_jobs.gd`, `r.summer`): rake leaves -> water the thirsty flowers round a house ("thirsty"
    props perk up and stay that way), pumpkins -> baskets of strawberries in the Sunflower Field, pumpkin pie ->
    strawberry shortcake, and a summer-only **sandcastles on the beach** job (`"sandcastle"`, walk into a heap of
    sand). The board wears a star in summer.
  - **Willow Pond's beach and the quest "Summer Splash"** (`scripts/summer_splash.gd`, a "SummerSplash" node under
    `EarthTown`, `quests/summer_splash.json`): all summer a sandy beach north of the dock with umbrellas, towels and a
    beach ball, and a cannonball off the end of the dock (`cannonball()`, any time in summer). Nina offers the quest
    once The First Night's done: Prue's swim ring by the Blastoffs' door, a bucket and spade at the hardware store,
    build a sandcastle with her on the beach (it stays all summer), cannonball into the pond, pink lemonade with Gus.
    12 sparkles. Flags `summer_splash_start`, `splash_ring`, `splash_bucket`, `splash_castle`, `splash_jumped`,
    `splash_lemonade`.
  - Tests: new `tools/test_summer.gd`; test_seasons and test_notice_board updated. Previews: `tools/capture_summer.gd`
    (shots in the project files under world/previews/summer).
  - My choices Hayden may change: the quest's steps, the jobs, the lights' colours, how long summer days are. Not done:
    spring still uses the autumn lines (and its patch sign says Pumpkin Patch).

- 2026-11-09: **Melody's groove and Melody's Stage** (Rhythm Springs slice two, the reward). Hayden: "Yes". Built and
  tested in the cloud (own Godot user folders, no save touched).
  - **Groove** (`scripts/groove.gd`, a "Groove" node on the player like Burrow and FrostBreath): new action **Groove**
    (G, D-pad right; on-foot pad group), locked until Rhythm Springs is mended (hidden in Controls till then, and
    D-pad right still picks gadgets: `Settings.SECRET_ACTIONS` now lists all three taught moves, `gadget_wheel.gd
    _secret_on()`). Press it and the hero twirls and hops, and a ring of music notes bursts out; enemies it reaches
    stop and dance on the spot for 4 s (like the Disco Ball). Melody's steady beat (0.8 s) is always ticking: grooving
    on it beat after beat builds a streak (a beat card at the bottom pulses with it for 3 s), each one throws the ring
    further (5 m up to 11 m), and from 4 in a row, if you're on the move, it's a speed rush (`Player.boost()`).
  - **Melody teaches it** 3 s after the Off-Beat's back in time (`rhythm_springs.gd _teach_groove()`, `teach_lines()`);
    her lines after are about it and her stage.
  - **Melody's Stage** (`scripts/melody_stage.gd`, put in by `Portals._melody_stage()` once Rhythm Springs is mended) at
    (-29, 43.2) beside her portal, facing the lake (checked flat, clear, 21 m off the Lake Loop): a round purple stage
    with steps, a pink and cream striped canopy, speakers, footlights that pulse on the beat and flash when you groove
    up there, and a sign. **Her evening show:** routines can now have `"mended"` blocks by world id that replace
    their day once that world's mended (`routine.gd today_blocks()`); Melody's do a show on the stage 6 to 9 PM (new
    places `stage_front`, `melody_stage`). Dialogue `when` can say `"mended": "<world>"` (`dialogue.gd`); she has show
    lines. **Dance-off:** on the stage during her show, 8 grooves on the beat in a row is an encore, 6 sparkles once a
    visit (`Portals.stage_prize_day`, saved in `"portals"`).
  - Tests: new `tools/test_groove.gd` (61 checks); rhythm_springs (now expects the lesson), portals, routines,
    dialogue, winter, burrow, player_menu, practice_trips, season_unlocks, ui_style, controls_lock, quick_fixes,
    layout, walk_through, frozen_moment, lanternmoor and rootmind pass. Previews: `tools/capture_groove.gd` (shots in
    the project files under world/previews/groove).
  - My choices Hayden may change: G and D-pad right, the ring sizes, 4 in a row for the rush, the stage's spot and
    look, the show's hours, 8 for an encore and its 6 sparkles. Still to do: summer things on Earth (like the winter
    overhaul: summer lines instead of autumn ones, summer notice board jobs, maybe a summer quest).

- 2026-11-09: **Rhythm Springs, Melody's world** (plan item 19a world 4, slice one). Hayden: "let's do rhythm springs
  but let's add a summer element like fire or extreme heat to the challenge of the world". Built and tested in the
  cloud (own Godot user folders, no save touched).
  - **The portal** (`Portals.WORLDS` "rhythm_springs"): quakes once Lanternmoor's mended, on the lake's south-west
    shore at (-34, 34) (flat, clear, 15 m off the Lake Loop's track), facing the lake. 9 Remnants for mending it, and
    mending it **opens summer** on Earth (its `"season"`).
  - **The world** (`tools/build_rhythm_springs.gd` -> `scenes/portal_worlds/rhythm_springs.tscn`, logic
    `scripts/rhythm_springs.gd`): a sunny sandstone valley with cool spring pools, boiling hot springs, parasol palms,
    Waterfall Mesa with a water slide, a Dance Floor under a striped awning and the Bandstand. Music notes float about.
    The beat's broken, so it drifts from quick to slow (`beat_len()`), and the sun's stuck at its hottest noon.
  - **The heat** (Hayden's summer twist): a **Heat meter** top-centre, under the portal timer. The sun fills it
    (about 45 s), shade cools it slowly (parasol palms, the awning, a parasol halfway up the mesa: `Shade*` markers),
    wading in a cool pool cools it fast (`Cool Pools`, scripts/water.gd), and the hot springs heat you fast. When it's
    full you're "too hot!" and pop out of the nearest cool pool. It never costs HP.
  - **Three Song Shells:** the **Sizzle Steps** (stepping stones over hot coals; each stone flares with fire one beat
    in three, glowing the beat before; touching the coals or a flaring stone sends you back to the start, hotter), the
    top of **Waterfall Mesa** (climb the pads, then ride the water slide down into the pool: `ride_slide()`, carried
    like the zipline), and **dancing with Melody** (press Jump on her steady beat, 8 times; `dance_press()`).
  - **The Off-Beat** (`scripts/off_beat.gd`): a stage-sized wooden metronome with a grumpy face and a red-hot weight,
    stuck between a slow and a quick tempo. Wakes when you come near with all 3 shells. Each tick rolls a heat ring
    (ShockRing) across the stage and lights one of 4 drum pads: land on the lit drum, or bubble his weight (once a
    second), 8 times. Then he shrinks to a happy little metronome, the heat breaks and the sun eases to a golden
    evening (`set_cool()`, own sky per copy). Found ids: `met_melody`, `shell_1..3`, `slid`.
  - Tests: new `tools/test_rhythm_springs.gd` (117 checks); portals (now checks the Tide Reef as the unbuilt world),
    practice_trips (Rhythm Springs shows up by itself), season_unlocks, lanternmoor, frozen_moment, rootmind,
    time_goblins, layout and walk_through pass. Previews: `tools/capture_rhythm_springs.gd` (shots in the project
    files under world/previews/rhythm_springs).
  - My choices Hayden may change: the heat speeds, the three shell tasks, the boss's name and fight, Melody's lines,
    the portal spot. Slice two still to do: the reward (Melody's dance ability, a stage in the Void plaza, summer
    things on Earth like the winter overhaul).

- 2026-11-09: **Lanternmoor, Pip's world** (plan item 19a world 3, slice one). Hayden: "playtest went well, so lets start
  on lanternmoor". Built and tested in the cloud (own Godot user folders, no save touched).
  - **The portal** (`Portals.WORLDS` "lanternmoor"): quakes once the Frozen Moment's mended, in the Spooky Woods at
    (-100, -104), on the way to the Haunted House (the old guess sat on the house itself), facing back towards town.
    8 Remnants for mending it.
  - **The world** (`tools/build_lanternmoor.gd` -> `scenes/portal_worlds/lanternmoor.tscn`, logic `scripts/lanternmoor.gd`):
    a moor under a violet night sky with stars, a moon, lantern trees and glowing moths, where the sun won't rise.
    Three beacons call the dawn back: the **Night Path** (light its 5 lanterns, Interact or a bubble), **Moon Rock**
    (a 22 m gap from the top of the Tall Lantern Tree: only reachable by gliding) and the **Lantern Grove** (catch 3
    runaway lights that flit away from you but never leave the grove; a bubble catches them too). With all three lit,
    **the Dawn Snatcher** (`scripts/dawn_snatcher.gd`, a big Time Goblin built on Grandfather Tock, the dawn glowing in
    his clock hat) wakes on Sunrise Hill when you come near. Pop him (8 hits) and the dawn floats out of his clock and
    up into the sky while the night turns to morning (`set_dawn()`; each copy of the world gets its own sky so the
    preview never changes). Found ids: `met_pip`, `lantern_1..5`, `beacon_1..3`, `light_1..3`.
  - **Pip** waits by the way in and lends you **moth wings** the first time you talk: hold Jump while falling to glide
    (`player.gd glide_fall`/`gliding`, 1.2 m/s; the wings are pink with yellow spots and spread while gliding). Only in
    Lanternmoor: the player is part of each scene, so they're gone everywhere else.
  - `time_goblin_boss.gd` gained `title`, `short_title`, `bar_colour` and `ring_colour` (Tock's are unchanged).
  - Tests: new `tools/test_lanternmoor.gd` (97 checks); portals (now checks Rhythm Springs as the unbuilt world),
    practice_trips (Lanternmoor shows in the list by itself), frozen_moment, rootmind, time_goblins, boss_versions,
    season_unlocks, layout, walk_through, burrow and skate pass. Previews: `tools/capture_lanternmoor.gd` (shots in the
    project files under world/previews/lanternmoor).
  - My choices Hayden may change: the boss's name, the three beacon tasks, glide speed, Pip's lines. Slice two still to
    do: the reward (Pip's glow lights dark caves, lanterns light the Void's paths at night).

- 2026-11-08: Named holds on the player's controls, and a map of the game's state machines (Hayden: "find all of the
  implicit state machines"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **The bug:** `input_locked` on the player was one true/false that 13 systems set and cleared (talks, race and
    skate-run countdowns, the creator, the zipline, the mothership, the hayride, the skate lesson, apple bobbing,
    the Swap-o-Tron, the First Night's arrival, the oak's reveal). Whoever finished first handed the controls back
    for everyone: a talk closes 0.15 s after its last line and unlocked her, so the Swap-o-Tron (started from a
    talk) let her walk off mid-flash, and races and skate runs had to lock her again every frame to cope.
  - **Now** each system holds the controls under its own name: `Game.hold_controls(&"race", true)` /
    `false` (`scenes/player/player.gd lock_input()`, `unlock_input()`, `input_locks()` says who's holding,
    `input_lock_changed` signal). `input_locked` still reads true while anyone holds them; setting it is only for
    tools (true = a "legacy" hold, false = let go for everyone). The `not Dialogue.is_active()` workarounds in the
    lab, the First Night and the oak are gone: a talk keeps its own hold.
  - `STATE_MACHINES.md` lists every state machine (explicit enums, data-driven steps, and the implicit flag groups
    left as they are, with why). Next candidate: `Input.mouse_mode`, which dialogue choices and the skate lesson
    still set as a single switch.
  - Tests: new `tools/test_controls_lock.gd`; `test_creator` now waits for the first landing's swirl to finish before
    checking she can move (the creator closing used to free her mid-swirl). creator, dialogue, festival, first_night,
    quick_fixes, race_intros, skate_help, shooting, skate_runs, mothership, time_watch, portals, rootmind, farming,
    episodes, doors, map, walk_through pass; earth, first_hour, layout and races fail the same checks before and
    after this change (not looked into here).

- 2026-11-08: **Winter in Stars Hollow, and Flurry's frost breath** (Frozen Moment slice two, part two). Hayden: "overhaul
  the winter version of earth to have winter related quests instead of fall quests and anything fall-related needs to
  be replaced by winter things ... add her frost breath as well". Built and tested in the cloud (own Godot user
  folders, no save touched). Same PR as winter unlocks.
  - **Lines:** every Earth townsfolk conversation that talked about autumn (pumpkins, cider, leaves, the Autumn
    Festival) now has a winter copy (`"season": "winter"`, Frost Fair, cocoa, sleighs, snowmen, ice fishing) and the
    old one says `"season": ["spring", "summer", "autumn"]`: 17 dialogue files, about 40 lines.
  - **The town** (`seasons.gd _dress_rest()`): pumpkins, jack-o'-lanterns and scarecrows outside the Autumn Dressing
    only show in autumn (scarecrows are found by their "Sack Head" material: the second one has a made-up node name).
    In winter a snowman stands at each ground-level pumpkin spot (`snowman_model()`, static), the patch sign says
    "Snowman Field", and the string lights and bunting turn red, green, white and blue (`_paint_lights()`).
  - **Notice board** (`earth_jobs.gd`): in winter, rake leaves -> shovel snow drifts, pick pumpkins -> pick
    winterberries in the Snowman Field, a new **build snowmen on the green** job (`"snowman"`, winter only:
    `kinds_for()`; walk into a snowball to roll it into a snowman), pumpkin pie -> blueberry pie; the board wears a
    star, not a jack-o'-lantern.
  - **New quest "The First Snow"** (`quests/first_snow.json`, `scripts/first_snow.gd`, a "FirstSnow" node under
    `EarthTown`): Nina offers it in winter once The First Night's done. Find a carrot at the Corner Market and Prue's old
    scarf at the Blastoffs' door, build the snowman with Nina on the green's north side (it stays all winter), sled
    down Lookout Hill (a red sled on the hilltop, any time in winter: `sled_down()`), then cocoa with Gus at the
    Hollow Diner. 12 sparkles. Flags `first_snow_start`, `snow_carrot`, `snow_scarf`, `snow_built`, `snow_sledded`,
    `snow_cocoa`.
  - **Frost breath** (`scripts/frost_breath.gd`, a "FrostBreath" node on the player): new action **Frost breath** (V,
    D-pad left; on-foot pad group), locked until the Frozen Moment is mended (hidden in Controls till then, and D-pad
    left still picks gadgets). A cone of frost 8 m ahead: over any water (group `"water"`) it freezes round ice floes
    (slippery, group `"ice"`) to walk across, each lasting 25 s (wobbling before it melts, at most 40); enemies in the
    cone are chilled like the Freeze mod (`Arsenal.chill()`). 0.7 s between huffs. Flurry teaches it the first time
    you talk to her in the Void.
  - Tests: new `tools/test_winter.gd`; test_notice_board updated; seasons, festival, fairs, big_days, player_menu,
    season_unlocks, burrow, dialogue, quests, frozen_moment and townsfolk pass. Previews: `tools/capture_winter.gd`
    (shots in the project files under world/previews/winter).
  - My choices Hayden may change: V and D-pad left, the quest's steps, the jobs, the winter lights' colours, how long
    floes last. Not done: the season dial (story flag 48: switch to any unlocked season yourself).

- 2026-11-08: **Winter unlocks, and Flurry comes to the Void** (the Frozen Moment's reward, slice two; plan item 20 for
  winter). Hayden: "Yes". Built and tested in the cloud (own Godot user folders, no save touched).
  - **Seasons unlock one by one** (`Clock.seasons_open`, saved as `"seasons_open"`): a **new game** only has autumn
    (`Game.new_game()`); each other season waits in a portal world (`Portals.WORLDS` `"season"`: winter in the Frozen
    Moment, summer in Rhythm Springs, spring in Glenmoor) and opens when it's mended (`Portals.open_seasons()`, also
    run on load, so a mended world's season is always open). When Earth's day reaches a locked season the calendar
    skips on a whole season at a time to the next open one (`Clock.skip_locked_seasons()`, from `_check_changes` when
    Earth's day changes), so weekdays never move and a new game gets autumn after autumn (Year 2...) until winter's
    unlocked. **Old saves** (no `"seasons_open"`) and tests (`Clock.reset()`) keep all four. Fairs, Hallow's Eve and
    big days only happen on open days (`Clock.is_open()`, festival.gd). The **Calendar** shows a locked season's page
    frosted over with a hint (`player_menu.gd _frosted_page()`, `season_hint()`: names the world once its portal's
    open), and "Coming up" stops at a locked season.
  - **Flurry in the Void** (`Portals._flurry_in_hub()`, once the Frozen Moment's mended): on the Portal Plaza beside
    Shard Isle's portal (`FLURRY_SPOT` in the plaza's frame), on a little snow patch with her own snowfall falling
    round her, turning to look at you. Her first talk says she followed you through; then she chats
    (`flurry_hub_lines()`, found `flurry_in_hub`). `frozen_moment.gd flurry_model()` is static now.
  - Tests: new `tools/test_season_unlocks.gd`; calendar, seasons, fairs, big_days, festival, portals, frozen_moment
    pass. Previews: `tools/capture_season_unlocks.gd` (shots in the project files under world/previews/season_unlocks).
  - My choices Hayden may change: skipping to another autumn (not repeating the same one), Flurry on the plaza, her
    lines. Not done: the season dial (story flag 48), Flurry's frost breath, and winter-flavoured notice board jobs
    (Earth's jobs still offer pumpkins and leaves in winter).

- 2026-11-08: Portal worlds, part four: **the Frozen Moment**, Flurry's home world (plan items 19a world 2 and 23),
  slice one (the world; its reward, winter and Flurry coming to the hub, is slice two). Hayden: "Let's do it". Built
  and tested in the cloud (own Godot user folders, no save touched).
  - **Its quake** once the Rootmind is mended. The portal rises at the foot of the mountains, far north past the
    castle, (46, -226) (checked flat and clear).
  - **The world** (`tools/build_frozen_moment.gd` -> `scenes/portal_worlds/frozen_moment.tscn`, logic
    `scripts/frozen_moment.gd`): a snowy bowl ringed by ice crags and pines, where time has stopped mid-moment.
    Snowflakes hang still in the air (a MultiMesh; `_flakes` keeps their places for tests), and a great clock in the
    sky is stuck on one tick. There's a **frozen lake** (group `"ice"`: slippery, `player.gd on_ice()` / `ICE_GRIP`,
    and any ride skates on it), **Snowball Hill** (four snowy steps) with an **ice slide** down (Interact at the top),
    an **icicle cave**, the **Frost Throne**, and **snow drifts** that slow you (`soft_zone.gd` kind `"snow"`).
    Surfaces: "Snowfield" sounds like soft ground, "Frozen Lake" and "Ice Slide" clink.
  - **Goal:** thaw the three **frozen moments** (found `moment_1..3`): a fish leaping out of the lake, a snowball
    fight on the hilltop, a snowbird in the cave. Three chips each (Interact, or Star Popper bubbles through the
    new `scripts/shot_target.gd`), then the moment carries on. Then the **Frost Gloop** (`scripts/frost_gloop.gd`,
    the Gloop King's scene with an icy look and a crown of icicles) cracks out of its ice block when you come
    within 16 m. It flops a ring of frost, calls Snow Gloops, and takes 6 hits. Popping it mends the world: 7
    Remnants, the snow falls, the clock ticks on. It doesn't set `popped_gloop_king` (`gloop_king.gd` now has `title`
    and `ring_colour` for cousins).
  - **Flurry** (working name), the arctic fox kid: made like the townsfolk from the cat body, white with a blue
    hoodie and scarf, a bushy tail and her stopped pocket watch. She waits by the way in, turns to look at you, and
    her lines (shy at first) say what to do next.
  - `player.gd`: when running on the flat, floor snap leaves no collision to read, so `_floor_node` now falls back to
    a short ray down (`_floor_below()`). Footstep sounds and `ground_kind()` are right while running too.
  - Tests: new `tools/test_frozen_moment.gd`. test_portals (its "never built" check now uses Lanternmoor),
    test_rootmind, test_burrow, test_gloop_king, test_boss_versions and test_walk_through pass. Previews:
    `tools/capture_frozen_moment.gd` (shots in the project files under world/previews/ice_world).
  - My choices Hayden may change: the portal spot, the three moments, three chips to thaw, the Frost Gloop's
    numbers, 7 Remnants, Flurry's look (cat body for now). Next: slice two (winter unlocks, Flurry comes to the hub,
    maybe her frost breath), then Lanternmoor (Pip).

- 2026-11-08: **Bramble's burrow**, the Rootmind's reward (Rootmind slice two). Hayden: "Go ahead but remember it
  needs to be locked until completion of the world". Built and tested in the cloud (own Godot user folders, no save
  touched).
  - **Locked until the Rootmind is mended** (`Portals.is_cleared("rootmind")`): before that, pressing Burrow does
    nothing and Settings > Controls doesn't list it (`Settings.action_shown()`, used by `pause_menu.gd`).
  - **`scripts/burrow.gd`** (no class_name, preloaded by `player.gd` as `BURROW`, a "Burrow" node on the player like
    Skate): new action **Burrow** (B, R3; on-foot pad group; old settings get it through `_claim`). On soft ground
    (`soil()`: the Void's terrain, Stars Hollow's `EarthLand`, anything in group `"soil"`: the Rootmind's moss) the
    hero dives in with a soil puff; underground they're hidden, a soil mound with a sprig (`burrower.gd make_mound()`,
    now static and shared with Bramble's own) races along at 1.45x running speed, nothing can hurt them
    (`is_invulnerable()`) and the popper won't fire. Jump (bigger hop) or Burrow again sprouts them up. Paving, wood,
    water, a ledge, a ride, a zipline or someone talking pops them up by themselves.
  - **Bramble teaches it** a moment after the Thornknot's calmed (`rootmind.gd mend()` -> `_teach_burrow()`,
    `teach_lines()`), and her lines after say how.
  - Tests: new `tools/test_burrow.gd` (30 checks); test_rootmind, test_portals, test_player_menu, test_ui_style,
    test_quick_outfits, test_shooting pass. Previews: `tools/capture_burrow.gd` (shots in the project files under
    world/previews/burrow).
  - My choices Hayden may change: B and R3, press-to-dive (not hold), the speed, what counts as soft ground. Next:
    the Frozen Moment (Flurry).

- 2026-11-08: Portal worlds, part two: **the Rootmind**, Bramble's home world (plan items 19a world 1 and 22). Hayden:
  "Go ahead". Built and tested in the cloud (own Godot user folders, no save touched). Slice one of the world: the
  burrow ability (her reward) waits for slice two.
  - **Its quake** (`Portals.quake_due`): once Shard Isle is mended and Bramble's Harvest has begun. The portal rises up
    on the Secret Gardens hill east of your garden, (-70, -24), facing the ramp (checked flat and clear in a running
    town). Coming home from any world now lands you on the ground in front of its portal (`Portals._land_by()`: the
    resume point can't know the ground's height from inside a world, and this one's up a hill).
  - **The world** (`tools/build_rootmind.gd` -> `scenes/portal_worlds/rootmind.tscn`, logic `scripts/rootmind.gd`): a
    round clearing walled by giant stems (and an invisible fence), huge leaves overhead, clover, roots, a mossy Heart
    Glade in the middle. **Every plant has eyes** (`Eyeplants`): their heads turn to watch you and they all blink
    together in a wave out from the middle every `HIVE_BEAT` (4 s), the hive's heartbeat. **Time runs backwards**:
    petals drift up, ten giant flowers are shut, and the hive's seedling shrinks back towards a seed while you're there.
    Bramble waits by the way in (her own model, idle), quieter than in the Void; talking to her says what to do next.
  - **Goal:** wake the three **Sun Blooms** (found `bloom_1..3`): on the top leaf of a spiral of leaves round a giant
    stem (easy jumps, with a **leaf slide** down a curling vine: Interact at the top, `slide_down()`), hidden in the
    middle of the **tall grass** (210 blades that bend away as you brush through, with a rustle), and at the end of a
    **tunnel of roots** lined with watching flowers (a small Remnant vein there too). Then the **Thornknot**, a grumpy
    tangle of thorny vines coiled round the seedling, out of step with the hive: walk up to it and it lashes a thorn
    ring every beat (`ShockRing`, jump it); just after each hive blink one of its three knots glows, and humming along
    (Interact, or a Star Popper bubble: `scripts/thorn_knot.gd`) calms it (`knot_1..3`). No hurting it: it rejoins.
    All three calm: `Portals.clear()` (6 Remnants), the seedling grows into a flowering sapling, the giant flowers open,
    petals fall the right way, the Thornknot is covered in flowers.
  - **The Void changes** (`Portals._watching_flowers()`): flowers with eyes ring the Rootmind's portal and line the
    south side of your garden (gate kept clear), turning to watch you go by.
  - Tests: new `tools/test_rootmind.gd` (73 checks); `test_portals` still passes. Previews: `tools/capture_rootmind.gd`
    (shots in the project files under world/previews/rootmind).
  - My choices Hayden may change: the portal spot, the Sun Blooms and where they are, how the Thornknot is calmed, the
    hive's beat, 6 Remnants, the watching flowers. Next: slice two (Bramble's burrow ability as the reward), then the
    Frozen Moment (Flurry).

- 2026-11-08: Time quakes and portal worlds, part one (plan items 19 and 19a): the portal system and **Shard Isle**,
  the tutorial world. Hayden agreed the nine worlds in 19a ("Absolutely perfect") and said yes to building the system
  plus Shard Isle first. Built and tested in the cloud (own Godot user folders, no save touched). Nothing is built
  into `town.tscn`: the portals and the plaza go in at play time.
  - **`scripts/portals.gd`** (autoload `Portals`): `WORLDS` lists all of 19a in story order (only Shard Isle has a
    `scene` yet; a world with no scene never quakes; the other spots are rough guesses to check when each is built).
    **Time quakes:** `quake_due(id)` says when the story's got there (Shard Isle: once the First Night is done, so old
    saves past it get theirs on their next visit), and `QUAKE_DELAY` seconds after arriving in the Void the camera
    shakes, the pad rumbles, the Remnant veins flare, a glowing **crack** opens and a crystal-studded obsidian
    **portal ring** rises out of it. Shard Isle's is in the field below Observatory Hill, (62, -58), facing the lake
    (clear of the races, rails and the Crocodillo: checked). **Preview:** within `PREVIEW_NEAR` the portal's swirl
    becomes a live window, a copy of the world's scene in its own SubViewport with its Player taken out and a slowly
    circling camera (`preview_scene()`; the copy has the `preview` meta so its script only sets up the picture). A
    world with `"preview": false` (Dark Hollow, later) keeps its plain swirl. **Going in** asks first (Dialogue.say:
    step through, take extra time for 2 Remnants, not now): `enter(id, extra)`. Every trip gets `FREE_SECONDS` (4
    minutes) and each Remnant buys `SECONDS_PER_REMNANT` (a minute). A **timer** card shows top-centre in a portal
    world. The **Void's clock stands still** while you're away (`Clock.running`), so trips never eat the Shift. When
    the time's up (`time_up()`), or you take the **way home** (`go_home()`), you land just in front of the portal
    (`Game.go_to_point()`, new: like `go()` but to a spot, using the resume point) with everything you found.
    `clear(id)` gives the reward and **changes the hub** (`_hub_changes()`: Shard Isle grows the **Portal Plaza**, a
    round stone floor, crystal pillars and a sign round its portal). Found things are kept for good
    (`note_found()` / `has_found()`), so nothing is ever done twice. Saved as `"portals"` (quakes, cleared, found,
    and the time left if saved inside a world). The map shows open portals; the loading screen says "Through the
    portal to ...".
  - **`scripts/portal_world.gd`**: the root of every portal world; a world's own script extends it. It puts in, at
    the builder's markers: the **way home** (`WayHome`, free, any time), the **Time Stone** (`TimeStone`: a Remnant
    for a minute), small **Remnant veins** (`Vein*`: 2 Remnants a Void day with Bramble's tool), and catches the
    player below `fall_below` and floats them back to where they last stood. `picture()` / `setup()` for the world.
  - **Shard Isle** (`tools/build_shard_isle.gd` -> `scenes/portal_worlds/shard_isle.tscn`, logic
    `scripts/shard_isle.gd`): a pale floating island in a teal-and-lilac sky with three islets, floating crystal
    stepping stones out to each, crystal clusters, and little shards that **stutter** over it (time skipping) until
    it's mended. Goal: the three **Echo Crystals** (one per islet) into the **Heart Stone** in the middle. Reward:
    5 Remnants and the Portal Plaza. No boss.
  - Tests: `tools/test_portals.gd` (77 checks: no quake before the First Night, the quake once, the portal on clear
    dry ground, the preview waking and sleeping, the question, extra time, the frozen clock, the timer, the Time
    Stone, the vein, falling off, every stepping stone a short hop, clearing, time running out, the plaza on flat
    ground, the way home, save/load/old saves). Previews: `tools/capture_portals.gd` (shots in the project files
    under world/previews/portals; the cloud can't push PNGs).
  - My choices Hayden may change: 4 free minutes and a minute per Remnant, where Shard Isle's portal is, the island's
    look, the reward. Next from 19a: the Rootmind (Bramble's world, plan item 22).

- 2026-11-08: Farming with Bramble (plan item 18), with the parts of item 17 (Remnants) that it needs. Hayden: "Let's
  do the farming before working on portal worlds". Built and tested in the cloud (own Godot user folders, no save
  touched). Nothing is built into `town.tscn`: both new autoloads put their things in at play time.
  - **Remnants** (`scripts/remnants.gd`, autoload `Remnants`): the rarer second money, sparkles squeezed into crystals
    (glowing uranium green on obsidian). Sparkles stay the everyday money. `Remnants.count`, `add()`, `spend()`,
    `words(n)` ("◆ 3 Remnants"). Shown on the HUD under the sparkles (`hud.gd remnant_label`) and in the Bag once the
    quest has started or there are any (`Remnants.shown()`), and in the shop's wallet line. Saved as `"remnants"`.
  - **Remnant veins**: five big crystal clusters (`VEINS`: the castle rock, the Spooky Woods, the lake shore, the Secret
    Gardens, the rock wall), each a `use_spot.gd` spot. Without the tool they only say the crystals are too deep. With
    it, Interact brings **Bramble**: a soil mound with a sprig races over, she sprouts up beside the vein (her own
    `plant_girl.glb`, "sprout" then "wave"), the crystals pop (+3 Remnants) and she burrows away. A harvested vein
    shows stubs and regrows the next Void day (`veins_taken`).
  - **Quest "Bramble's Harvest"** (`quests/brambles_harvest.json`, offered by Bramble from the fourth time you talk to
    her, so her first chats stay as they were; "Maybe later" and she asks again every third talk): find the **three tool parts** (a rootwood handle in the Secret
    Gardens, a moonshell scoop by the dock, a hum crystal on the Observatory hill: glowing pickups that only show on
    that step), take them to Bramble and **choose the tool's look** (Leafy Trowel, Crystal Pick or Star Scoop; flags
    `harvest_look_*`, `{tool}` in dialogue), harvest a first vein, **meet Bramble at your garden** (her routine's
    override sends her to the new place `my_garden`), plant and water, then pick your first crop. Reward: Bramble's
    watering can (`watering_can`) and 10 sparkles. Flags: `harvest_start`, `harvest_later`, `harvest_part_*`,
    `harvest_tool_built`, `harvest_first_vein`, `garden_tour`, `farm_planted`, `farm_watered`, `farm_first_harvest`.
  - **The garden** (`scripts/farm.gd`, autoload `Farm`): a fenced plot of twelve beds up on the Secret Gardens' hill,
    in front of the greenhouse where the nursery is on Sofi's town map (Hayden; `GARDEN`, gate turned to face south
    to the ramp, `GARDEN_YAW`), with a "Your Garden" sign, a rain barrel and a wheelbarrow. The builder's decorative
    soil rows there are hidden at play time (`_clear_nursery`).
    Bramble's tour (`"do": "Farm.tour"`) digs the first two beds and gives 3 Blinkberry and 1 Peekaroot seeds; the
    rest you dig yourself with the tool. Each bed is a spot that offers what makes sense: dig, plant (a little
    question when there's more than one kind of seed: `Dialogue.say` + `farm_plant_<crop>` flags), water, check on
    it ("about 3 more Void hours"), pick. **Watering** lasts `WATER_LASTS` (360 Void minutes, about 4 real minutes)
    and plants only grow while they have water and the Void's clock runs (in the Shift). Dry ones droop with a water
    drop over them and wait; **they never die** (Hayden's "never a chore wall"). With the watering can one watering
    does every bed. Growth is counted in Void minutes (`Farm.now()` = day * 1440 + minutes), so it's safe across
    saves and the clock going back.
  - **Crops** (`Farm.CROPS`), all alien plants with a pair of eyes that blink and follow the player: Blinkberry
    (4 Void hours, 3 berries, sells 2), Peekaroot (8 h, 2 roots, 5), Goggle Gourd (12 h, 1 gourd, 14) and the
    **Remnant sprout** (a whole Void day, gives 2 Remnants; its seed costs 1 Remnant). Five looks per bed (dug, seed,
    sprout, growing, nearly, ripe with a glow), rebuilt only when it changes.
  - **Shops** (`shop/items.json`, `Shop.register_kind`): seeds at the Flowers stall, the Remnant sprout seed at the
    Crystals stall; the Fruit stall **buys** crops (a kind registered with `"sells": true` pays the price instead of
    taking it: new in `shop.gd`); the Sweets stall makes Blinkberry Tart, Peekaroot Fries and Goggle Gourd Soup from
    your crops. Items can now cost Remnants (`"currency": "remnant"`, shown "◆ 1"). All only show once the garden's
    yours. The Bag sheet has a "Your garden" line (seeds and crops).
  - **Request board** (`requests.gd`): a new kind, "Pick N crops in your garden" (2 / 4 / 6), once the garden's yours
    (`has_garden()`); `Farm.harvest()` calls `Requests.note("harvest", n)`.
  - `scripts/use_spot.gd`: a reusable Interact spot made in code (an `offer` and an `act` Callable). No class_name on
    purpose: `--script` tools compile class_name scripts before the autoloads exist. Load it with `preload`.
  - Tests: `tools/test_farming.gd` (placement, the whole quest, Bramble's visit, veins regrowing, growing, thirst,
    never dying, the can, the Remnant sprout, shop buy/sell/snacks/Remnant prices, the request kind, HUD, Bag, save,
    load and old saves). Previews: `tools/capture_farming.gd` (shots in the project files under
    world/previews/farming; the cloud can't push PNGs).
  - My choices Hayden may change: the garden's size (12 beds), crop names, growing times (within one visit
    rather than "a few Void days", so kids see results), prices, the part spots, the tool looks, where the veins are.
    Seasons (item 20) can add a `"season"` to a crop or seed later. Portal time for Remnants waits for item 19.

- 2026-11-07: The first hour, reworked from Hayden's playtest: the Humming Oak, a daytime start, people who stop to
  talk, the bench, fewer collectibles at first, and the camera after the portal. Built and tested in the cloud (own
  Godot user folders, no save touched).
  - **The Humming Oak** (Hayden chose "Yes, build it"): a new game now starts at **9 AM** on Earth and The First Night
    (`quests/first_night.json`) has a whole first day before the Void: **morning** (Nina, Mr. Palmer, two hellos; Theo
    and Mr. Page on the bench), **oak** (listen at the old oak: something ticks inside), **clues** (Mr. Page's book,
    *The Legend of the Old Oak*, at Turn the Page; Mr. Palmer's lilac envelope; three glowing acorns by Mossy Falls, the
    pumpkin patch and on Lookout Hill, each with a tremor), **dusk** (lay them in the nook in its roots: the runes
    wake), **wait**, **awaken** (at midnight, walking up to the oak plays the reveal: the camera swings to it, fireflies
    spiral up, runes light one by one, roots lift, the hollow swirls open), then shift/day/king/home as before (Zippy
    is off the day's checklist). Earth's clock waits at 6 PM until the clues are done and at 11 PM until the acorns are
    in; the bed only offers "Until the Shift" from the wait step (`FirstNight.shift_sleep_ok()`).
  - **`scripts/humming_oak.gd`** (autoload `HummingOak`): the oak's spot (listen / put the acorns in), the acorn pickups
    (bob, halo, a faint beam; quest `"at"` stars with the new `"world": "earth"`, map_screen.gd), runes (the shared
    "Oak Rune" material and the "Rune Glow" light), fireflies, the reveal (`start_reveal()`, Jump/Interact skips) and
    `awake()`. The oak's door only opens once it's awake (`earth_world.gd _door_open()`); old saves and anyone not on
    the First Night's early steps find it awake. Flags: `fn_oak_listen`, `fn_book`, `fn_acorn_1..3`, `fn_acorns`,
    `fn_acorns_placed`, `oak_woken`.
  - **The old oak** (`build_earth.gd _portal`): the ring and its "Portal to the Void" sign are gone. A great gnarled oak
    (`OAK_BACK` behind `PORTAL_AT`) with a dark arched hollow framed by thick bark in its front, the swirl inside it,
    runes over the arch, down its sides and spiralling up the trunk, roots round the foot and the Acorn Nook. The door
    area and Entrance marker kept their names. `EarthTown.OAK` follows it.
  - **Old saves** mid-First Night: `FirstNight.migrate()` (called by `Game.load_game()`) moves the old step number to the
    same step now (`OLD_STEPS`), marks the new Earth-day steps done and the oak awake if they'd crossed; flag `fn_v2`.
  - **Fewer collectibles at first** (`FirstNight.held_back(night)`, only for games started since this: flag
    `fresh_start`): night 1 has just the fountain's lost watch (then 8, 14, all from night 4: `Watches.out_tonight()`),
    no S-K-A-T-E letters or booster coins until night 2 (strips and ramps stay; `Boosters.drop_coins()`), no Earth
    notice board until night 2.
  - **Theo and Mr. Page** were both sent to `green_bench`, which was the hay bale on the green's corner, so they stood
    inside each other. Now there's a real bench on the green (`GREEN_BENCH`) with two seats, `green_bench` and
    `green_bench_2`, and a new routine `"do": "sit"` (`townsfolk.gd sit()` poses the legs in code; Dottie sits too).
  - **People stop when you talk:** Earth's townsfolk had no `talking` property, so their routines never paused. Now
    they stop, turn and listen; someone busy skating, riding, scooting or flying a kite carries on (`routine.gd BUSY`,
    or `"busy"` on a block), routines/README.md.
  - **Camera locked after the portal:** the minimap's map picture is much bigger than its circle and the minimap took
    the mouse, so in the Void (with the mouse captured in the middle of the screen) it ate every mouse move. The
    minimap and its picture now ignore the mouse (`map_screen.gd`).
  - Tests: `tools/test_first_night.gd` walks the new day; new `tools/test_first_hour.gd` (bench, stopping to talk,
    busy, the oak asleep, held-back collectibles, the camera in the Void, old-save migration). Previews
    `tools/capture_humming_oak.gd`, shots in project files `world/previews/humming_oak/`.
  - My choices Hayden may change: the acorn spots, 9 AM, the 6 PM hold, what comes out on which night, the BUSY list.

- 2026-11-07: Character creator overhaul + save slots (Hayden's playtest notes: "only one body type, human, boy or
  girl", "the top best 10 hair styles in video games for each gender", "multiple save slots", "the kid body in the
  creator doesnt even have eyes"). Built and tested in the cloud (own Godot user folders, no save touched).
  - **One body: a human kid, girl or boy** (`Hero.BODY_ORDER = ["human_girl", "human_boy"]`), new models from
    `tools/build_hero_bodies.py human_girl human_boy` (Earth kid's head and rig, bigger brighter eyes, lashes for the
    girl, tee + flared skirt / tee + shorts, and jump, fall and skate actions so the player animates). Their own
    "Hair" is a close cap that stays on under every style (`"hair_base"`). The old bodies stay in `Hero.BODIES` for
    townsfolk, racers and episode guests; the creator just doesn't offer them, and no secret bodies are offered
    (`SECRET_ORDER` empty). The old "Kid" body was Dash's model, whose eyes are closed lines: that's the "no eyes".
  - **Old heroes become human kids** on load (`Hero.migrate`): girl if she/her (or they/them on a hippo, cow, bunny,
    moth or cat), else boy; old hairstyle to the nearest new one (`Hairstyles.TO_NEW`); a fur colour that isn't a skin
    tone goes back to their own skin. Name, pronouns, sizes, face and clothes stay.
  - **20 new hairstyles** (`scripts/hair_kit.gd`, `Hairstyles.NAMES` 12-31; 0-11 are the old ball styles townsfolk
    still wear): girls High ponytail, Twin tails, Space buns, Long and straight, Long braid, Bob with bangs, Pixie cut,
    Big curls, Afro puffs, Side ponytail; boys Hero spikes, Swoop fringe, Middle part, Messy mop, Quiff, Faux-hawk,
    Top knot, Curly top, Afro, Buzz cut. Each is a kind of hair game heroes are known for (`HairKit.ABOUT`), not a copy.
    Made from a scalp shell plus tapered locks (darker roots, sheen), round the human head, then moved into Nina's
    space so `clothes.gd` fits them like the old ones; "up" parts tuck under covering hats, an invisible "crown" ball
    sizes hats. If the human head changes, re-measure `HairKit.HEAD_BOX` (Clothes.fit_of head_box).
  - **Creator** (`scripts/creator.gd`): Body tab has big Girl / Boy buttons and skin tones (`Hero.SKIN_TONES`, four new
    swatches 21-24); Hair tab is a grid of named style buttons with a line about each and "Show every style";
    Colours is eyes, blush and brows. Surprise me keeps girl or boy.
  - **Save slots** (`scripts/game.gd`): 3 slots; slot 1 is still `save.json` (old saves are slot 1), others
    `save_slot2.json` / `save_slot3.json`; last slot in `user://slots.cfg`. `use_slot`, `new_game_in`, `delete_slot`,
    `slot_info`. Title screen has **Save Slots** (cards with name, level, day, time played; Empty starts a new game
    there; Delete asks first) and New Game's question offers "Use a different save slot". Tools run with `--script`
    always use slot 1 and never write slots.cfg. **`Game.hold_saves`**: set it in a tool's finish before putting the
    save back (a new game started by a test saved over the restored save otherwise).
  - Tests: `tools/test_creator.gd` (updated), new `tools/test_save_slots.gd`. Previews: `tools/capture_human_creator.gd`,
    shots in project files `world/previews/human_creator/`.

- 2026-11-07: Ride upgrades as you level up: hover and rocket boards and bikes, and the rocket ones FLY (plan item 29,
  Hayden: "new vehicle mechanics as you level up to hover and rocket boards/bikes, with the rocket ones capable of
  flight"). Built and tested in the cloud (own Godot user folders, no save touched); full suite 63/63 green.
  - **Three steps each** (`Rides.LINES`): Skateboard, Overboard (hover, Lv 2), Rocket Board (flies, Lv 5); Bike,
    **Hover Bike** (new, Lv 3, needs the Bike, no schematic), Rocket Bike (flies, Lv 6). `"level"`, `"needs"`,
    `"hover"` and `"flight"` in `Rides.HERO_RIDES`. Schematics still unlock them too; rides an old save owns stay.
  - **`scripts/ride_upgrades.gd`** (autoload `RideUpgrades`): level gates for Zippy's Tune-Up ("Reach Lv N" /
    "Needs the Bike first", note with XP to go), a message when a level-up opens a ride (`Game.leveled_up`, new
    signal), and **XP from riding**: races 25/15/10/6 by place, skate-run medals 8/12/20 (new ones only), 5 per new
    gap. Goals page says which level opens the next ride. Skate page explains hover/rocket.
  - **Hover** (`skate.gd _float_on_water`): hover rides (Overboard, Hover Bike, Saucer) skim over any `scripts/water.gd`
    water (now in group "water", `covers(x, z)`) with ripples, and race goo can't slow them.
  - **Flight** (`skate.gd _fly`): on a rocket ride, Jump again in the air and hold to fire the rockets: climbs at
    7.5 m/s up to 32 m over the ground (`FLY_CEILING`), plane-style steering, 5 s of fuel (fuel bar in the skate HUD)
    that refills on the ground and from any boost; let go and she floats down at most 6 m/s, landing clean facing
    where she's going. No flying in races (`Races.racing()`). The sky schematic at 46 m stays mothership-only.
  - `scenes/player/ride_kit.gd _hover_bike`: the BMX lifted 0.3 m with teal light rings round the wheels and pads
    under them. Tips `rocket_flight` and `hover_ride`.
  - Tests: new `tools/test_ride_upgrades.gd`; `tools/test_schematics.gd` updated for six rides. Capture
    `tools/capture_ride_upgrades.gd`; previews in project files `world/previews/ride_upgrades/`.

- 2026-11-07: The quick outfit wheel and skins (plan item 16). Built and tested in the cloud (own Godot user folders,
  no save touched).
  - **`scripts/quick_outfits.gd`** (autoload `QuickOutfits`, drawn by `scripts/outfit_wheel.gd`): hold **Outfit wheel**
    (C, L3; new in Settings > Controls, in both pad groups) anywhere outside a talk, menu, shop, the creator or a
    cutscene and a wheel of six saved outfits opens, the game slowed to 0.2 like the gadget wheel; point with the mouse
    or a stick, let go to change, with a sparkle puff (spheres moved by one tween), a squash and a chime. A tap does
    nothing (L3 is easy to click by accident). With nothing saved, holding it says how to save one.
  - **Saved outfits** are `Game.saved_outfits` (saved as `"saved_outfits"`, six places, null for an empty one, tidied
    on load by `SavedOutfits.clean()`; old saves have six empty places). Each keeps the hero's clothes, creator colours
    and skin. Changing into one only puts on clothes the player still owns. The wardrobe (hero only) has an "Outfit n"
    row to pick a place, **Save this outfit** and **Forget it**.
  - **Skins** (`scripts/skins.gd`, `Skins`): six colour sets for the hero's body (fur, hair, eyes, accent, blush,
    brows), working on every body; an Earth kid keeps their own skin tone (`KEEP`). Starlight (3 requests turned in),
    Comet Tail (10), Clockwork Brass (5 watches given to Dash), Midnight Hour (15), Checkered Flag (finish a race),
    Champion Gold (win 3). `QuickOutfits.check_skins()` hands them out once a second when earned (items `skin:<id>`,
    with a message). `Game.hero.skin` sits on top of the creator's colours (`Skins.colors_of()`, used by
    `Hero.apply()`), so taking it off gives them back; the wardrobe has a Skin row, and picking a colour the skin
    covers in the creator takes the skin off.
  - Playing as cast members is written up in the plan (item 16) for later, not built.
  - Test `tools/test_quick_outfits.gd` (the buttons, old and odd saves, the wardrobe, skins earned once, the wheel by
    holding, a tap, not in a shop or a talk, owned clothes only, all ten bodies, the creator, saving). Previews
    `tools/capture_quick_outfits.gd`, shots in `/mnt/project-files/world/previews/quick_outfits/`.
  - My choices Hayden may change: C and L3, the six skins (names, colours, what earns them), six places.
- 2026-11-07: One menu look for the whole game (plan item 15). Built and tested in the cloud (own Godot user folders,
  no save touched); the whole suite passes (69 runs).
  - **`scripts/ui_style.gd`** (`UiStyle`) makes the shared theme, saved as `ui/theme.tres` by `tools/make_ui_theme.gd`
    and set as the project theme (`[gui] theme/custom`), so every Control wears it. It's lettered in the subtitles'
    comic font (`UiStyle.FONT_PATH`, Kalam Bold from the subtitles work), in the alien palette: chunky rounded buttons
    with a lip they sink into when pressed, a thick teal focus ring for controllers (yellow in High contrast), folder
    tabs, sliders, scroll bars and text boxes to match. Type variations `SheetTab`, `SheetPanel`, `Card`, `Heading`.
    Menus that follow Settings (text size, High contrast) call `UiStyle.theme()`: the pause menu's `make_theme()`, the
    player menu, the shops and wardrobe (`shop.gd`), the creator. `UiStyle.box()` and `card()` are the panel looks.
  - **Player menu** (`player_menu.gd`): the sheets are folder tabs over a page. **Quests** shows each quest as a card
    (`Quests.cards_view()`/`card()`: a round picture of who gave it, `scripts/quest_picture.gd`, its name, "From ...",
    the steps with ticks and the reward); a quest file can name its `"giver"` (quests/README.md), else the first step's
    place says. The old text log is still there (hidden) for tests, and the extras (requests, the board) underneath.
  - **Quest banner** (`quests.gd _note`): a card that slides in from the right when a quest starts, moves on or ends.
  - **Minimap**: on by default (old settings get it switched on once, `minimap_v2`), round (`clip_children`), with a
    compass ring (N in pink), and icons for quests (stars pinned to the rim when off it), shops (bags), boosters and
    the portal, the same on Earth. HUD messages keep clear of it.
  - Shop windows fit at 1280x720 (the wardrobe's Bye button ran off before: `_fit_scroll`).
  - Test `tools/test_ui_style.gd` (the theme, every menu and sheet opening and closing on keyboard and controller,
    nothing off screen or overlapping at 1280x720 and 1920x1080, the minimap, cards and banner). Previews
    `tools/capture_ui_style.gd`, before and after shots in `/mnt/project-files/world/previews/ui_style/`.
  - My choices Hayden may change: the colours, the font for menus, the button lip, the compass, the quest pictures.
- 2026-11-07: Boosters everywhere (plan item 14). Built and tested in the cloud (own Godot user folders, no save
  touched).
  - **`scripts/boosters.gd`** (autoload `Boosters`): boost strips, booster ramps and booster coins round the Void and
    Stars Hollow, outside races too. Like the lost watches they're put into the scene at play time from `BOOSTERS`
    (no builder or `.tscn` change), each on the ground found under its spot. Strips: along the lakeside (between the
    Lake Loop's own pads), the Homes street, out of the Market, into the Skate Park; on Earth into the Big Air Kicker,
    into the Hollow Skate Yard, Maple Lane and behind Main Street. Ramps: solid little kickers (StaticBody3D in group
    `booster`) that boost you and pop you off the lip (`RAMP_POP` on a ride via `Skate.spring()`, `FOOT_POP` on foot);
    meadow, sports fields, soccer field, the playground and the park by Lookout Hill. Coins: lines between the rails of
    the meadow rail line and the Library-to-woods rail line, down Lookout Hill and round Willow Pond; each a short
    burst, back after `COIN_BACK` seconds. Every boost uses `Races.boost_time()`, so the Turbo Tank helps here too.
  - On foot too: `Player.boost()` (scenes/player/player.gd) hands a ride's boost to `Skate.boost()` and otherwise
    makes her rush past running speed, then ease back down. Going fast never bails.
  - Map and minimap: a small arrow for each (`Boosters.marks()`, `TownMap._draw_boosters()`), teal for strips and
    ramps, gold at the start of a coin line; "➤ Booster" in both legends.
  - Tests: `tools/test_boosters.gd` (on the ground, dry, flat enough, nothing in the way, spread out, not on a race
    pad, boosts on foot and on the board and wear off, a ramp pops you up, coins go and come back, map arrows).
    Previews: `tools/capture_boosters.gd`, shots in `/mnt/project-files/world/previews/boosters/` (PNGs need LFS, so
    they stay out of the repo from the cloud).
- 2026-11-07: The plant girl is **Bramble** (Hayden named her, and chose "Plant girl becomes Bramble fully" on the card).
  "Bramble" had been the horned cow girl's working name, so the two swapped. The plant girl's node now has
  character_id `bramble`, so she has everything that was Bramble's: the Secret Gardens, the flower stall, the
  window-box quest, the pick-me-up that heals, and her part in the slide, Bill of Rights, Rex's campaign and Night 3
  quests. `dialogue/bramble.json` was rewritten in her voice, and `routines/bramble.json` is her old day with a meadow
  burrow in the afternoon (`move_anim` "under"). `plant_girl.json` is gone. The cow girl is **Clover** for now
  (character_id `clover`, a working name until Hayden names her). A farm girl from a long way and a long WHEN away:
  `dialogue/clover.json`, `routines/clover.json` (home park, the green meadow, scooting at the Skate Park, the south
  shore). She keeps her model, her scooter (`Rides` "clover"), her wardrobe (`Clothes.WHO`), the cow hero body
  (`Hero.BODIES.cow.char`) and her place racing the Lake Loop. A save's old `outfits`/`looks` "bramble" moves to
  "clover" on load (`game.gd`). **Snappy is a he, and badly trained** (Hayden): `scripts/snappy.gd` (a "Snappy" node
  under her) makes him lunge and SNAP at whoever she's talking to every other conversation (not the first), right
  after her first line; then she says sorry (`Dialogue.cut_in()` puts lines in next). test_dialogue checks it.
- 2026-11-07: Human Nina's new look, and two new Void kids, Melody and the plant girl (from Hayden's three pictures,
  copied to `source_art/reference/`: "Nina - human form.jpg", "Melody - capybara girl.jpg", "Plant girl.jpg"; Hayden:
  "Plant girl grows in and out of the ground to move around"). Built and tested in the cloud (own Godot user folders,
  no save touched); the whole suite passes (62 runs).
  - **Human Nina** (`tools/build_earth.gd`, `nina_earth`): brown skin and brown eyes, her red bob now a brighter
    red-orange (`look.hair_rgb`: a hair colour of their own beyond the creator's swatches, `Townsfolk._tint_hair()`)
    with a side fringe, her red bow, freckles, a gap-tooth smile, little gold hoops, a white tee under a pink pinafore,
    dark leggings and her yellow backpack. New extras in `scripts/townsfolk.gd`: `fringe`, `hoops`, `gap_teeth`,
    `pinafore`, `backpack`. The black turtleneck is gone. `earth.tscn` rebuilt (only Nina changed; the rest is
    unique_id churn). test_townsfolk checks the new look.
  - **Melody** (`tools/build_melody.py` -> `melody.blend` -> `models/characters/melody.glb`, id `melody`): the capybara
    girl in purple from Sofi's show notes (upbeat pop): golden-brown fur, big blunt snout with a dark nose pad, blue
    eyes with lashes, an auburn quiff and a big ponytail with a purple scrunchie (its own `ponytail` bone, bouncing),
    a purple polo dress (collar, buttons, A-line skirt), white socks, black Mary Janes. Animations: idle (paws at her
    chest, delighted, like the picture), walk, run, jump, fall, `dance` (her pop dance) and `sass` (arms crossed).
    Routine (`routines/melody.json`): home at `housing_north`, busking (dancing) at `market_south` in the morning,
    a dance break in the town square, singing to the flowers in the meadow in the evening. `dialogue/melody.json`.
  - **The plant girl** (`tools/build_plant_girl.py` -> `plant_girl.glb`; first called "Sprout", she's Bramble now:
    see the next entry): round pale green face with closed happy eyes and purple blush, a cap of
    layered leaves, bark antlers wrapped in vines with leaves and dewdrops, a dress of leaves, a branchy leaf hand, a
    Venus flytrap on her other arm ("Snappy", its own `trap` bone so it snaps) and golden roots instead of legs.
    Animations: idle (swaying, the trap breathing), `burrow`, `under`, `sprout`, `snap`, `wave`, plus walk/run/jump/
    fall stand-ins. **She burrows to get about** (`scripts/burrower.gd`, a `Burrower` node next to her Routine): when
    her routine moves her she dives into the ground (soil puff from `Juice.dust`, her model sinks out of sight), a
    little mound of soil with a sprig travels along where she is, and when she stops she sprouts back up with a
    springy pop. It never moves her body, so routines, talking and tests treat her like anyone else. Routine
    `move_anim` "under", speed 2.2.
  - Routines can now say which animation someone plays while standing about or resting between little walks:
    `"anim": "dance"` on an `idle` or `wander` block (`scripts/routine.gd`, README). Voices for both in
    `scripts/soundscape.gd`. Tests: test_routines (both routines, Melody dancing, the plant girl going under and
    coming up), test_dialogue, test_townsfolk. Previews: `tools/capture_new_friends.gd` (in `previews/new_friends/`
    and the project files under characters/melody, characters/plant-girl, characters/nina-human).
  - My choices Hayden may change: the plant girl's name, Melody's home and day, Nina's leggings and shoes (not in the
    picture), the flytrap's name.
- 2026-11-02: A game feel pass on skating and the Star Popper (the coordinator's suggestion, Hayden: "go"; the first
  try of the game-feel skill from awesome-gamedev-agent-skills and GodotPrompter's camera-system). Small, short touches
  on top of what `Juice` already did, all scaled by Settings > Assist > Screen shake and off with Reduce motion.
  `Juice.kick(dir, amount)`: one camera nudge in a screen direction that springs back on the real clock (kicks add up
  to at most `KICK_OFFSET`, 12 cm). `Juice.dust(parent, pos, amount)`: a ring of soft lilac-grey puffs rolling out
  over the ground, made of a few spheres moved by one tween, not one-shot CPUParticles3D (on the PC too, those only
  show a few of their puffs in the first frames, so a burst at someone's feet hardly showed). Skating (`skate.gd`):
  an ollie off the ground puffs dust from the tail; a clean landing puffs dust by how hard it was, kicks the camera
  down (from a 0.2 hard landing up), thuds on a hard one and gets a 0.03 s freeze only on a really big drop; riding off
  a rail flicks a last spray of sparks; every trick into a combo ticks a little higher and bumps the HUD's combo line
  (`skate_hud.gd bump()`); a combo of 1,000+ paid out showers gold round her; a bail gets a 0.05 s freeze, a thud, a
  kick down and a dust cloud. Star Popper (`star_popper.gd`, `star_bubble.gd`): a puff of tiny bubbles at the nozzle
  and the popper squeezing on every shot (not Buzz Bots or Jelly Mines), a small kick up when aiming or for a big
  bubble; whatever a bubble hits squishes, and the bubble that pops it gets a 0.035 s freeze (0.05 for a big one).
  `test_juice` checks the kick (down is down, it adds up to one at most, it springs back exactly, Reduce motion);
  skate, skate_park, skate_popper, shooting, skate_help, gloop_king, arsenal, gaps, skate_runs and races pass, run
  one at a time on the PC with the save checked untouched. Clips: `tools/capture_game_feel.gd` (folders of frames for
  GIFs; stills in `previews/game_feel/`). My choices Hayden may change: every strength and time above.
- 2026-11-01: Sparkly alien trees in the Void (Hayden). `scenes/town/trees.gd` builds them at load from the same
  spots, sizes and colours as before, so `town.tscn` wasn't rebuilt. Three kinds, picked from each tree's spot
  (`kind_of()`, so a rebuild keeps them): **orb trees** (a leaning stalk, a big glowing ball and two little ones on
  side branches), **spire trees** (three faceted seven-sided cones, each turned and nudged off the last so the spire
  twists, with a glowing ball on the tip) and **parasol trees** (a tall stalk, a wide flat cap and glowing bulbs
  hanging round its edge). The canopy shader shimmers, glows at the rim, has slow swirling bands and specks that
  flash white. Eight **twinkles** a tree: camera-facing quads playing a 16-frame sheet made with the pixelfx skill
  (`scenes/town/tree_twinkle.png`, its effect kept in `source_art/fx/tree-twinkle.js` with how to remake it), each
  with its own start and a 1.4 to 3 s cycle (MultiMesh custom data), additive, fading out past 110 m. Nodes under
  "Trees": Canopies, Spires, Trunks, Twinkles; `kinds` and `twinkle_spots` say what was built (the lab's
  `_clear_plot` still shrinks them away by instance). Still nothing solid. Test `tools/test_trees.gd`; previews
  `tools/capture_trees.gd`, `previews/alien_trees/` (before and after). My choices Hayden may change: the three
  shapes, how many twinkles, how fast they wink.
- 2026-11-01: A big day every season (plan item 8, slice 4; Hayden chose 4-week seasons on the card, so they stay).
  `Festival.BIG_DAYS`, each on a Sunday so never on top of a fair, put up by `scripts/big_day.gd` ("Big Day" node,
  `kind`) only in its hours: **Winter Lights** (21 Winter, 5-10 PM: the Winter Tree at `Festival.TREE_AT` on the
  green's west side, with presents and a star, lit at 6 PM), **Kite Day** (14 Spring, 10 AM-5 PM: seven kites over
  Lookout Hill, a kite stand at `KITE_STAND_AT` by the hill path that lends you one (`kite_lines()`, spot "Kite
  Stand"), and it flies over you) and **Firefly Night** (28 Summer, 8:30-11 PM: rockets from a raft in Willow Pond,
  a finale from 10 PM). Being there (by the tree once it's lit, on the hilltop with your kite, by the pond for the
  finale) pays 5 / 3 / 4 sparkles once (`big_day_reached()`, saved as `big_prize_days` and `kite_day`). The six kids
  come (routine blocks `"lights"`, `"kites"`, `"fireworks"`, with lines for each). The firework bursts are a MultiMesh
  moved in code, not CPUParticles3D: one-shot CPUParticles didn't show up in the cloud's screenshots. On the Calendar,
  the Quests sheet, the watch and a loading tip. Test `tools/test_big_days.gd`; previews `tools/capture_big_days.gd`
  (project files, world/previews/big_days). My choices Hayden may change: the days, names, hours and prizes.
- 2026-11-01: A fair every Saturday, and Hallow's Eve (plan item 8, slice 3). `Festival.FAIRS` gives each season its
  own fair on the green: the **Autumn Festival** (as before, 5-10 PM), the **Frost Fair** (4-9 PM: ice fishing in the
  barrel, a sleigh ride, Gus's Cocoa Cart, a gingerbread house for the baking contest), the **Spring Fair** (5-10 PM:
  hook a duck, strawberry tarts, lemonade) and the **Summer Fair** (6-11 PM: blueberry pie, bob for apples).
  `fair()`, `fair_name()`, `start_time()`, `end_time()`, `lantern_time()`, `hours_text()`; `festival_green.gd`
  dresses the stalls, banner, string lights, barrel, wagon and pumpkins for the season (the node keeps the name
  "Autumn Festival", and it's made again if the season changes while it's up). Shop items can have a `"season"`
  (`Shop._in_season`): seven new seasonal treats. **Hallow's Eve** (28 Autumn, 5-9 PM, `Festival.HALLOWS`):
  `scripts/hallows_eve.gd` puts a glowing jack-o'-lantern and a knock spot at ten gates on Maple Lane
  (`HALLOWS_DOORS`); each door gives a treat line and a sparkle once (`knock()`), all ten a 6-sparkle bonus; saved
  in the festival save. The six kids' routines have `"hallows"` blocks (going door to door, then bed) and
  trick-or-treat lines. Test `tools/test_fairs.gd`; shots in `tools/capture_calendar.gd` (project files,
  world/previews/fairs). My choices Hayden may change: the fairs' names, hours and games, the treats, the doors.
- 2026-11-01: The seasons in Stars Hollow (plan item 8, slice 2). New `scripts/seasons.gd`, a "Seasons" node that
  `EarthTown` puts in the Earth scene when it loads (so `earth.tscn` wasn't rebuilt). The town as built is autumn; for
  the other seasons it changes what's there: the trees' leaves (the "Tree Leaves" MultiMesh: fresh green with pink and
  white blossom in spring, deep green in summer, and in winter three in four gone and the rest snow on the branches),
  the fallen leaves (flowers in the grass in spring, a few in summer, snow drifts in winter), the ground and the
  countryside (`EarthLand.recolor(season)`, `EarthLand.season`, `SEASON_GRASS`), the town green, the far hills, snow
  on every roof in winter, Willow Pond iced over (only to look at: it's still water), and the Halloween dressing (the
  "Autumn Dressing" group, its hay bales' collisions too) only in autumn. Something in the air round the player
  outdoors (not in a music zone): snow, petals, drifting leaves, and fireflies on summer nights. It checks once a
  second, so the town turns at midnight on a season's first day. It reads the instances from the builder's saved copy
  (`MultiFill.transforms/colors`), not the MultiMesh, which is empty headless; `shown_leaves` and friends say what's
  showing, for the test. Test `tools/test_seasons.gd`; previews in `tools/capture_calendar.gd` (project files,
  world/previews/seasons). Not changed yet: the pumpkin patch and shop-step pumpkins stay all year.
- 2026-11-01: Earth's calendar (plan item 8, slice 1: "a real calendar"). `Clock` (`scripts/clock.gd`) now has dates:
  four seasons of four weeks (`SEASONS`, `SEASON_DAYS` 28, `YEAR_DAYS` 112), each starting on a Monday, so a date is
  always the same weekday. A new game starts on **Friday 19 Autumn, Year 1** (`CALENDAR_START`), so winter starts on
  day 11. `Clock.date_string()` ("Saturday 20 Autumn"), `season()`, `season_day()`, `year()`, `day_of(season, date)`,
  `is_weekend()`, `school_holiday()` (spring break 8-14 Spring, all of Summer, 22-28 Winter) and `is_school_day()`.
  Functions that take a day use `Clock.TODAY` (not -1) when it's left out, since days before day 1 are real dates on
  the calendar. Saved as `"calendar_offset"`; a save from before the calendar keeps its weekday and lands in the week
  of Monday 15 Autumn (`fit_calendar_to_old_save()`). The HUD and the watch show the date. New **Calendar** sheet in
  the Tab menu (after Map): the season as four weeks with today ringed, weekends and holidays shaded, what's on, and
  "Last season / Next season" buttons; "Coming up" underneath (`Festival.events_on(day)` says what's on). The Autumn
  Festival is now only on **autumn** Saturdays. Routines (`scripts/routine.gd`) can have `"weekend"` and `"holiday"`
  blocks (`today_blocks()`): Nina, Bruno, Prue, Juniper, Theo and Ozzie lie in and go round town at weekends (skate
  yard, diner lunches, the pond, the toy shop, Lookout Hill) instead of going to Old Oak Elementary, with new lines.
  Dialogue `when` can use `"season"`, `"weekday"`, `"weekend"` and `"school_day"`. Tests that set the day reset
  `calendar_offset` first (a save's could put day 2 in another season). Fixed `test_townsfolk`'s count, which had
  counted Pepper (the Pumpkin Run's starter) since the race went in. Test `tools/test_calendar.gd`; previews
  `tools/capture_calendar.gd` (project files, world/previews/calendar). My choices Hayden may change: 4-week seasons,
  the start date, the holidays, the kids' weekends.
- 2026-11-01: Race intro cutscenes for every track (plan item 7, slice 4; Hayden: "I also want to add cutscenes for all
  the tracks"). Saying go to a starter (or flying through the Sky Rings' start ring) now plays a short intro before the
  countdown (`scripts/race_intro.gd`, `RaceIntro`, made by `Races` in `_ready`): black bars, the track's name and
  blurb over a slow swing round the start arch, a flight along the whole racing line (5.5 s, however long the track),
  then a hello to each rival on the grid with their name and ride ("Bruno / SK8 Deck", "Nova / Mini Saucer"). About
  13 s; Jump, Interact or Accept skips it. It uses its own camera (the player's camera and spring arm are untouched),
  hides the player's HUD layers and the minimap while it plays, and keeps the player and rivals still (`Races.State.
  INTRO`; for the Sky Rings the mothership is frozen with `process_mode`, then `_go_sky()` starts the race). Calling a
  race off mid-intro cleans up. Settings > Assist > **Race intros** (on by default, `Settings.race_intros`). Older
  race tests turn it off. Test `tools/test_race_intros.gd` (all five tracks, the camera stays 3 m+ over the ground the
  whole flyover); previews `tools/capture_race_intros.gd` (project files, world/previews/race_intros). My choices: the
  timings and camera moves.
- 2026-11-01: Timed skate runs (plan item 7, slice 3). New autoload `SkateRuns` (`scripts/skate_runs.gd`), like Tony
  Hawk's two-minute sessions. A **Run Clock** (a post with a big clock face and a SKATE RUN sign, put up at play time,
  talk spot `scripts/run_spot.gd`) stands at the Void's Skate Park (just outside the rings, south) and at the Hollow
  Skate Yard (northwest corner, by the Big Vert). Interact, say go: 3-2-1, then 120 s to score anywhere; every combo
  banked counts (gaps too, and they're counted), and a combo you're in at the buzzer counts if you land it within 8 s
  ("Land it!"). Results: score, best, medals (`RUNS`: Skate Park 5,000 / 15,000 / 35,000, Skate Yard 6,000 / 18,000 /
  40,000), each medal paying 3 / 5 / 8 sparkles the first time. Time and score across the top use a `RaceHud`. Stepping
  off the ride or starting a race ends it. Saved as `"skate_runs"` (best, medals); the Skate page lists both runs.
  Test `tools/test_skate_runs.gd`; previews `tools/capture_skate_runs.gd` (project files, world/previews/skate_runs).
  My choices: the medal scores and sparkles, two minutes, where the clocks stand.
- 2026-11-01: Gap bonuses for the skating (plan item 7, slice 2). New autoload `Gaps` (`scripts/skate_gaps.gd`), like
  Tony Hawk's: fly from one spot to another on a ride and "GAP! <name>" goes into the combo as a trick
  (`SkateTricks.gap()`, which also starts the moment to link a manual if the combo was empty, so it's paid out). It
  watches the rider's skate state from outside (leaving the ground or a rail = take-off, coming down on the ground or
  a rail without a bail = landing), so `skate.gd` wasn't changed. A move of more than 3 m in one physics frame (a race
  start, a door, a respawn) cancels the jump, so teleports are never gaps. **Named gaps** (`GAPS`) are circles in the
  frame of a skate piece in the scene (`"piece"`, found by name at scene load, so they follow the builders): Hollow
  Yard Gap (gap kicker onto the landing deck, 500), Yard Funbox Hop and the Void's Funbox Hop (either way, 250), Yard
  Stair Set and School Stair Set (300), Lookout Launch (off the Big Air Kicker, 9 m+, 750), Pond Path Hop (200), Dock
  Drop (off the hardware store's loading dock, 250). **Anywhere gaps** (`ANYWHERE`): Hang Time (2 s up, not a vert air),
  Long Gap (12 m), Big Drop (3.5 m), Rail Transfer (one rail straight onto another). The first landing of each finds it:
  flag `gap_<id>` and 2 sparkles. The Skate page in the Tab menu lists them ("Gaps found: n of 12", the rest as ??? with
  a hint). Test `tools/test_gaps.gd` (zones, fits and misses, both ways, the anywhere gaps, finding pays once, real rides
  off the yard's gap kicker at 11 m/s and the Big Air Kicker at 13 m/s). Previews `tools/capture_gaps.gd` (project files,
  world/previews/gaps). My choices: the names, points and the 2-sparkle reward.
- 2026-11-01: The Pumpkin Run, a race round Stars Hollow on Earth (plan item 7, slice 1: "more races and skating").
  A new track in `Races.TRACKS` (`"pumpkin_run"`, `"scene": EARTH`), placed in the Earth town at play time like the
  others, so `earth.tscn` wasn't rebuilt. Two laps of about 345 m: start on Maple Lane heading east, round past the
  barn dance studio, up the east side past the Corner Market, across Main Street through the gap between the bakery
  and the toy shop on one side and the antiques and hardware shops on the other (z -53.5), down the west side to the
  green, then Hollow Lane back to Maple Lane. Open from the start (no `"after"`). 4 boost pads, 3 rows of Star Boxes,
  3 goo puddles, prizes 16/11/6/3. **Kids are people on Earth**, so: the starter, **Pepper**, is an Earth kid made
  like the townsfolk (a starter can have a hero-style `"look"` and `"extras"` instead of a model: `race_track.gd
  _starter`), and the friends racing are **Nina, Bruno and Ozzie**, copied from their townsfolk in the scene
  (`RaceRival._townsfolk_copy()`, leaving the board, book or clipboard they carry at home) on the rides in
  `Races.TOWNSFOLK_RIDES` (Nina's board, Bruno's SK8 Deck); spares when you ride as one of them are Juniper and Theo
  (`"spares"`). `Races.ride_of()` and `RaceRival.display_name()` replace the direct `Rides.ride()` lookups. Pepper's
  lines don't mention Zippy or the Sky Rings; the Goals page says "talk to Pepper in Stars Hollow"; the Earth map
  (M / Tab) draws the route. Tests: new `tools/test_earth_race.gd` (line dry, nothing in any lane, no steep steps,
  clear of the old oak, inside the walls, Pepper and the Earth kids, a whole race); `test_races` skips tracks in other
  scenes. Previews: `tools/capture_earth_race.gd` (in the project files under world/previews/earth_race). Built and
  tested in the cloud. My choices Hayden may change: the name, Pepper (name and look), the route and the prizes.
- 2026-11-01: Bruno, Nina's little brother, from Sofi's drawing (prompt B; Hayden: "Bruno is in the reference material
  folder so use that to build him"). The drawing is from the "Kids songvideo more ideas" notes (a hippo boy in a black
  SK8 beanie, golden hair, open blue zip hoodie over an olive tee, tongue out); a crop is in
  `source_art/reference/Bruno - SK8 beanie.png`. Built and tested in the cloud (each run with its own Godot user
  folder, so no save was touched).
  - **The Void Bruno** (`tools/build_bruno.py` → `source_art/characters/bruno.blend` → `models/characters/bruno.glb`):
    made like Nina (same head, snout and body code, so they look related), with his own spiky golden mop, the black
    knit beanie with a folded cuff and an SK8 patch (real text), ears out under the cuff, blue eyes, freckles on his
    snout, ONE front tooth (the gap is his lisp), the tongue poking out, the open hoodie (zips, drawstrings, pockets,
    hood bunched at the back), dark jeans and black skate shoes. Animations: idle (hands near his pockets, head
    bobbing), walk, run, jump, fall, skate, push and `tough` (his Godfather bit). In `scenes/town/characters.tscn` next
    to Nina, id `bruno_alien` (`routines/bruno_alien.json`: home in the morning, the Skate Park most of the day,
    lunch by the lake, the home park in the evening; `dialogue/bruno_alien.json`).
  - **Earth Bruno** (`tools/build_earth.gd`, no longer a placeholder): the Earth kid body with golden hair, a bit
    shorter than Nina, freckles, a blue top with the new `open_hoodie` extra (olive tee, zips, hood, drawstrings) and the
    new `bruno_beanie` extra (black, cuffed, SK8 patch) in `scripts/townsfolk.gd`, and his black board under his arm.
    `earth.tscn` was rebuilt (only Bruno changed; the rest is unique_id churn). New lines in `dialogue/bruno.json`.
  - **His lisp and his Godfather voice:** his lines lisp ("Thkate Park", "leththon"). Under stress his voice goes low,
    slow and Italian: during the Aftershock quest (the other Nina's tricks), when Leo's alarm wails in the Void, and
    after two bails on one step of his skate lesson. Parody bursts in our own words, then he's himself again.
  - **His ride** (`scripts/rides.gd` "bruno", after Nina in `ORDER`): the SK8 Deck (`ride_kit.gd` kit `sk8`: Nina's
    board in black with golden wheels and SK8 on the deck). Snappier than Nina's board, steadier grinds, less glide,
    pushes with his own `push` animation. Tricks: Gap-Tooth Flip, Beanie Heelflip, Tre Flip, Meatball Shove-it; Hoodie
    Grab, Nonna's Melon, Nose Boop, Tail Thwip; Fifty-Thifty, Spaghetti Slide, Family Lipslide; Cool Manual; special
    "Offer You Can't Refuse".
  - **Coach Bruno:** the skate lesson (`scripts/skate_lesson.gd`) is his now. Each step has his line ("says") and
    Rook's woof; Rook stands beside him at the Lesson Pad ("Helper Rook") and cheers; their town selves step out of
    sight meanwhile. Rex calls "COACH BRUNO!" in The First Night. Words changed in the lesson pad, pause and player menu,
    nights checklist and the dog-kid hint.
  - Tests updated: test_townsfolk, test_routines, test_dialogue, test_skate_help (Bruno and Rook at the pad, the
    stress line after two bails), test_creator, test_first_night, test_skate_popper. Previews: `tools/capture_bruno.gd`
    (in the project files under characters/bruno/in-game), Blender turnarounds under characters/bruno/previews.
  - My choices Hayden may change: his Earth look (Sofi only drew his hippo self), his trick names, how heavy the lisp
    is, his routine, and that he's a little shorter than Nina.

- 2026-11-01: The Agent of Chaos final boss fight (plan item 6, slice 3 of 3). `scripts/chaos_fight.gd` is hung under
  the giant (`ChaosFight`, added by `Bosses`) and drives him while a fight is on (`chaos_giant.gd` gained `fight`,
  `shot()` and a `size` used only so hip fire aims at his chest). **Locked** until the flags `popped_gloop_king`,
  `popped_grandfather_tock` and `popped_boulderdillo` are all set (walking up before that gives a hint naming who's
  left); then coming within 24 m starts it, and going 70 m away calls it off (he gets all his chaos back). His weak spot
  is the cracked clock on his chest (`ChaosClock`, a StaticBody sphere at 7.2 m up, 1.5 m forward): bubbles only count
  on it while it **glows** (legs and shut clock: "bounce"). 30 chaos in three phases: **1 bursts** (`scripts/
  chaos_burst.gd`: a marked spot that pops in glitch cubes 1.3 s later, bumps you if you're still on it, jumping
  doesn't help; every second volley also a big `ShockRing` to jump), then his clock glows 3.5 s; **2 minions** (glitch
  rifts bring Time Goblins and a Gloop; his clock opens once they're popped or after 14 s); **3 rewind** (every other
  turn his clock spins backwards for 4 s: three hits break it and leave him dazed and open 6 s; otherwise the player is
  pulled back 3.5 s along their trail, the screen flashes purple (softer with Reduce flashing) and he gets 3 chaos
  back, never past the phase start). At zero his clock shatters, he shrinks away out of time (hidden till the town
  reloads, so a rematch is there next visit), flag `beat_agent_of_chaos`, 200 XP and 20 sparkles. Test
  `tools/test_chaos_fight.gd` (29 checks); `tools/capture_chaos_fight.gd` soaks the fight for 25 s of bubbles then poses
  shots → /mnt/project-files/characters/chaos-giant/final-fight/. Tested in the cloud only.
- 2026-11-01: The Boulderdillo, the Crocodillos' boss, and a cross Gloop King (plan item 6, slice 2 of 3). `Bosses`
  now also puts **Boulder Hollow** at (-118, -180) in the northwest (12 mossy boulders with collision in a ring, two
  ways in; on the map) with the Boulderdillo in it: `crocodillo.tscn` with `scripts/crocodillo_boss.gd`, size 2.6
  (about 6 m), boulders grown into its shell and ball, a crown of rocks. **Pinball rolls**: a roll that ends or hits a
  boulder slams a ring out (`ShockRing`) and rolls at you again, 3 in a row, then it's dizzy 3.6 s. **Thick hide**:
  bubbles boing and stomps bounce unless it's dizzy. Two **Pebbledillos** (size 0.6, no respawn) at a third and two
  more at two-thirds; past half it's cross (rolls 25% faster, 4 in a row). 10 hits, flag `popped_boulderdillo`.
  `scripts/crocodillo.gd` gained `size` (scales shapes and visual), `respawns` and the hooks `_roll_ended`,
  `_hurt_message`, `_defeated`; ordinary Crocodillos are unchanged. The Gloop King gets cross past half his goo:
  25% quicker, flops a third more often, and each flop sends a second, wider ring. Test `tools/test_boss_versions.gd`
  (24 checks); previews `tools/capture_boss_versions.gd` → /mnt/project-files/characters/boulderdillo/. Tested in the
  cloud only.
- 2026-11-01: Time Goblins and their boss, Grandfather Tock (plan item 6, slice 1 of 3; Hayden: the Agent of Chaos
  is the final boss, a new enemy "time goblins", and every enemy gets a bigger boss version). New autoload `Bosses`
  (`scripts/bosses.gd`) puts it all in town at play time, so the town wasn't rebuilt: the **Goblin Clockyard**
  (128, -150), a ring of seven tumbledown grandfather clocks east of the Agent's field (on the map through the new
  `scripts/landmark.gd`), 8 Time Goblins (4 in the yard, 2 towards the Observatory, 2 in the Agent's field) and Tock in
  the middle. `tools/build_time_goblin.gd` → `scenes/enemies/time_goblin.tscn` + `time_goblin_boss.tscn` (shapes in
  the palette: teal goblin, pointy ears, amber eyes, top hat with a cog, a gold pocket watch in its belly running
  backwards; Tock wears a grandfather clock as a hat with a swinging pendulum). `scripts/time_goblin.gd`: remembers
  where it's been and **blinks back in time** 2 s (ghost trail, `Juice.blip("rewind")`) when a bubble's about to hit
  it (75%), then it's dizzy 1.4 s and can't blink for 5 s: make it blink, then pop it. Bumping you snatches a sparkle
  (held over its head) and it runs off; popping it gives it back. `scripts/time_goblin_boss.gd`: 8 hits, a blink
  undoes his last hit, his clock strikes three chime rings to jump (`scripts/shock_ring.gd`, shared by the coming
  bosses), two goblins at a third and two more at two-thirds, quicker and more chimes past half, flag
  `popped_grandfather_tock`. `scripts/boss_bar.gd` is the name-and-meter bar for the new bosses. Test
  `tools/test_time_goblins.gd` (31 checks, 5 runs green); previews `tools/capture_time_goblins.gd` →
  /mnt/project-files/characters/time-goblins/. Tested in the cloud only.
- 2026-11-01: Quests from the show's first episodes (plan item 5; Hayden: "time for the next step"). Tested in the
  cloud only (each run with its own Godot user folder, so no save was touched). Nothing new in the save (all progress
  is quest flags) and no scene was rebuilt. One script puts everything in at play time: `scripts/episodes.gd`, node
  "Episodes" under the Watches autoload, like the Lab (dialogue can reach it as `Watches/Episodes.<method>`).
  They come one after another, like a season:
  - **We Need a Slide!** (`quests/slide_mystery.json`, the pilot): Melanie (new, cat body, by the Town Hall from The
    First Night on) wants a water slide. Mr. Palmer says no and lists all the fun the town has (patience); Bramble, Pip
    and Dash each know a bit about the boarded-up old slide; two clues by it (the CLOSED notice about "The Incident",
    a giggling green puddle); Mr. Goldwhistle (new, only on his steps) says think outside the box and offers the
    Haunted House; trying its door lets a giggly green spirit out (the pilot's cliffhanger, left for later). Melanie's
    new plan, the floating cloud slide with a toy store on top, gets a yes: it gives the `cloud_slide` item, so the
    builder's hidden Cloud Water Slide appears from the next visit.
  - **Emergency Prep** (`emergency_prep.json`): Leo (new, bunny, anxious) packs a kit (water jug by the fountain, torch
    on the Library steps, blanket in the Cozy Cave, snacks on the dock) for his bunker in the south meadow (built at
    (11, 35), clear of the race lines). Stocking it, a wail: Leo freezes. Three ways to calm down (breathing, checking
    what's really happening, a happy place), and it was only Rook howling at the mothership: the brain's smoke alarm.
    He becomes "Ready Leo".
  - **The Doggie Bill of Rights** (`dog_rights.json`): Rex, who's learned a lot in a dog's body, writes it. The player
    picks rule two (zoomies, the bubble bath or sniffing); Dash, Bramble, Pip, Nina and Rook (a paw print) sign; Mr.
    Palmer agrees in his window (a different answer for each rule two). A DOGS WELCOME sign and a doggy fountain go up
    by the Market fountain; Rook becomes "Rook, Good Citizen".
  - **Turtle Independence** (`turtle_independence.json`): starts the visit after the Bill of Rights (flag
    `turtle_next_visit` first), with the hero wearing a **Turtle Shell** (new back piece in `clothes.gd`). The Wizard
    Lizard (new, dino in a witch hat, Secret Gardens) explains: magic, a different version of you, every version has
    purpose and value. Three little lake turtles (Tiny, Splash, Pebble, on the south shore) choose their own shells
    from a teacup, a bucket and a flower pot. Keep wearing the shell or take it off (whatever was on their back goes
    back on, remembered in a `turtle_back_was:<id>` flag); the shell's theirs either way.
  - **Aftershock** (`aftershock.json`, Earth): one evening after that (7 to 11:30 PM Earth time) a smaller quake
    (EarthTown.tremor) and Willow Pond glows. Another Nina climbs out (`other_nina`: an Earth kid with orange hair,
    freckles, a red-and-white striped beanie and a black turtleneck, new `striped_beanie` and `freckles` extras in
    `townsfolk.gd`): sweet-looking, mean tricks. Put right her three tricks (tangled gazebo lights, mud pies in the
    bakery, the Town Hall sign saying TOWN SMELL), tell the real Nina (she's not a part of Nina, just another Nina from
    another world), and face her at the pond: she goes back through, "ponds work both ways".
  - `scripts/townsfolk.gd` can now make any hero body (a look with `"body": "cat"`), which is how the Void visitors
    are made. Earth's townsfolk have no body key and are unchanged.
  - `tools/test_episodes.gd` (90 checks, plays all five through) and `tools/capture_episodes.gd` (17 shots, in the
    project files under world/previews/episodes). Full suite green in the cloud.
  - My choices Hayden may change: everyone's looks and names (Melanie, Mr. Goldwhistle, Leo, the Wizard Lizard, the
    turtles), the clue and kit places, the bunker spot, rule two's options, and when each one starts.

- 2026-11-01: Time watches as the clock, then Rex and Dash's lab quest (plan item 4; Hayden: "can you do those").
  Tested in the cloud only (each run with its own Godot user folder, so no save was touched). Nothing in the save is
  new and no scene was rebuilt.
  - **The watch is the clock** (story/how-it-fits.md: "the watch can be the player's clock"). Once the hero has a watch
    (the Shift Watch on their first crossing), the HUD's clock is its face beside the old words
    (`scripts/watch_face.gd`, drawn in code; `scripts/time_watch.gd`, `TimeWatch`, says which watch, what it shows and
    what it says). The **Shift Watch** "ticks Earth's way": its hands always show Earth's time, so in the Void they
    crawl. The **Time Keeper** (all 20 lost watches, wrist or pendant) shows the time where you are, with the other
    world on a little dial. Round the rim: on Earth a moon at twelve and a lavender wedge filling up to it (the portal
    opens when the hour hand gets there); in the Shift, the Void's dawn-to-dawn day with a sun or moon going round, the
    part still to come glowing. **Check your watch** (`check_watch`: T, D-pad down, rebindable) holds it up big with a
    few lines (Earth's day and time, the portal or how much Shift is left, the festival, the night). Settings > Display >
    Clock: watch and words, just the watch, or just words (`Settings.clock_style`). No watch yet: words only. The
    pause menu's `_choice` now matches string values too. `hud.clock_label` keeps its old text, so old tests still read it.
  - **Rex and Dash's lab** (`scripts/lab.gd`, node "Lab" under the Watches autoload, so dialogue calls
    `Watches/Lab.tune_watch` and no new autoload was needed): a shed in the yard past Dash's house, built at play time
    (centre (99, -16), open front facing west): the Swap-o-Tron's two glass pods and coil, a console with the big
    lever (a quest spot added at play time), Dash's workbench, a chalkboard and a framed "Hound Hero" (the show's
    Dog Man easter egg, our own name). The two trees and a plant the builder had scattered there are shrunk away at
    load (`_clear_plot`). The roof has no collision on purpose: routines find the floor by looking down.
    New places `lab`, `lab_pod_rex`, `lab_pod_rook`, `lab_bench` (linked from `housing_ne`).
  - **The quest** (`quests/rex_lab.json`): Rex offers it once The First Night's done ("a helper with hands, and a
    watch"; "not now" sets `lab_later` and he asks again now and then). **see:** Rex and Dash explain the two
    experiments at once and that it won't swap back here; Dash tunes the watch (`lab_tuned`; a hero with no watch
    gets the Shift Watch). **ripples:** three time ripples (Market Square south end, the town square, the
    Observatory path) appear only on this step; the watch's rim gets a pink pointer to the nearest, pulsing faster
    closer, and walking into one catches it (`lab_ripple_1..3`). **rook:** Rook won't come when asked nicely, only for
    a ball (`lab_rook`). **try:** Rex and Rook stand in the pods, pull the lever: the coil charges, a flash (soft with
    Reduce flashing), lavender smoke. **after:** Rex says "Woof!", Rook shouts "I'M REX!", Dash's reading says the
    swap is knotted into the crack in the Shift their experiments made, so it can't undo until that's fixed (Dash
    looks far away for a moment: a hint at his arc, no spoiler). Reward: **Lab Goggles** (face slot, brass with pink
    lenses, `clothes.gd`) and 15 sparkles.
  - `tools/test_time_watch.gd` (52 checks), `tools/capture_time_watch.gd` (shots in the project files under
    world/previews/time_watch, made in the cloud). Full suite green in the cloud apart from `test_soundscape` (waits
    for the generated audio).

- 2026-10-31: Clean-up pass (prompt K in the plan). Tested in the cloud only (each run with its own Godot user
  folder, so no save was touched).
  - **Controller in the shop and wardrobe:** A presses the highlighted button and B backs out, whatever the game's
    buttons are (`scripts/shop.gd`). B is Interact out in the world, so before, B bought things instead of closing.
    The press that opens the shop is ignored by it. The pause menu's B-to-go-back now works too (Godot's `ui_cancel`
    is only Esc, so the old check never fired). `test_shop` presses A and B.
  - **Map legend:** it has its own strip under the map picture (`_map_rect`, `_legend` in `scripts/map_screen.gd`),
    and labels keep out of it, so it no longer sits on the Book Store, Gaming Station and Clothing Boutique labels.
  - **Clothes** (`scripts/clothes.gd`): capes are made to measure (`_cape`): from the shoulders, touching the back,
    leaning out just enough to clear a round body, and outside long hair (Bramble's). The back is now measured
    ignoring anything narrow sticking out behind (the cat's tail has no bone, so wings, jetpacks and capes used to
    float out on it: `_reach`). Hats on a head whose ears stand up past its top (Rex) are squashed down so the ear
    tips poke out (`_under_ears`). The headphones' band is one rounded arch, widened as a whole to clear hair,
    instead of being pushed out bit by bit into a box.
  - **Real bugs the flaky tests found:** the mothership's pulled-back camera never pulled back (the spring arm set
    its own length every frame since aiming came in): others now change `boom_length` and `lift` on
    `scenes/player/spring_arm_3d.gd`. The old oak's hum (`scripts/earth_town.gd`) was made live with an
    AudioStreamGenerator, which sometimes locked up the whole game in the audio thread (the creator test hung about
    half the time); it's now a 4-second loop made once in code, with the tremor's rumble as its own sound. The
    zipline handle is a talk spot like stalls and people (`Dialogue.enter_range`), so the nearest gets Interact.
  - **Tests:** `test_quests` reads the bound Interact key; `test_map` checks the arrow before the player can turn;
    `test_walk_through` stands on the boardwalk itself, not on whoever walks over it; `test_schematics` doesn't let
    the request board count a new night; `test_clothes` allows reward clothes (Shift Watch, Time Keeper) not sold at
    the Boutique; `test_shop` moves passers-by (a request alien) away from the Fruit stall before checking its prompt;
    `test_skate_park` puts her on the park floor instead of dropping her onto it (a drop sometimes landed as a bail).
    `test_soundscape` still fails until the generated music and ambience are copied into `audio/`.

- 2026-10-31: Nights 3 to 7 (Hayden: "Go", the rest of the 7-night plan). Each night is its own skippable quest
  (`quests/night_3.json` to `night_7.json`): meet a friend (Bramble, Dash and Rex wait by the portal through quest
  overrides, the Astronaut at the Mothership Pad, Mr. Palmer at his office window; their first lines in
  `dialogue/<friend>.json` set `n<N>_hi`), then a list of the night's schematics (`schematic_<id>` flags) and its
  spotlight: 3 The Meadow in Bloom (race on any track, from `Races.finished`), 4 Stars Over Observatory Hill (go up
  to the Observatory, have Zippy build a ride), 5 Up in the Mothership (fly it, then fly through the sky schematic),
  6 Rex for Mayor (go inside the castle school), 7 The Agent of Chaos (peek at the Scary World gate, see the giant
  from 45 m). Rewards 10/12/12/14/20. `Nights._start_next()` starts the next night on landing once the one before is
  done or skipped, and only one a visit (flag `night_visit_<visit>`); `_check_later_nights()` ticks the spotlight
  flags. `tools/test_later_nights.gd` walks all five by really doing each thing; `tools/capture_later_nights.gd`
  (shots in the project files under world/previews/later_nights, made in the cloud).
- 2026-10-31: Schematics and new rides (Hayden: "I want the weapon and skateboard unlocks to be significant").
  `scripts/schematics.gd` (autoload `Schematics`) puts glowing blue blueprints (`scripts/schematic_pickup.gd`) into
  the town and school at play time, one or two a night from night 2 (`LIST`: `night`, `at` x/z dropped onto the
  ground, or `sky` for the Rocket Board's, which only the mothership can reach). Found ones are Dialogue flags
  (`schematic_<id>`), so nothing new in the save. **Gadgets:** Dash's stall lists all six from the start, but each
  says "Find its schematic" (`Arsenal._can_buy_gadget`) until it's found; a gadget an old save owns stays owned.
  **Rides:** the hero's own rides are `Rides.HERO_RIDES` (only what differs from BOARD, like `RIDERS`; `tricks_from`
  borrows a friend's tricks, `boost_power` makes boosts stronger, `flames` are rockets): Overboard (hoverboard, long
  glides), Bike (BMX), Rocket Board, Rocket Bike (fastest on wheels) and Flying Saucer (floats and glides). Kits in
  `ride_kit.gd` (`_overboard`, `_rockets`, `_saucer`); rocket flames grow while pushing and boosting (`skate.gd`).
  Zippy's Tune-Up builds them (shop kind `ride`, items `ride_<id>` made in code), owned ones are items `ride:<id>`,
  and `Game.hero_ride` (saved) is the one being ridden, picked on the Skate page ("Your ride"). Races use whatever
  the hero rides. `Shop.register_kind` takes an optional `note` (a line under an item: where its schematic is).
  Night 2's list now has finding the Fizz Flinger's schematic on the promenade; the Goals page points to the next
  schematic and to rides ready to build. Schedule (plan doc F4): night 2 Fizz; 3 Disco, Overboard; 4 Jelly, Bike;
  5 Buzz, Rocket Board (sky); 6 Plushinator (school garden), Rocket Bike; 7 Rainbow, Flying Saucer.
  `tools/test_schematics.gd` (100+ checks), `tools/capture_schematics.gd` (shots in the project files under
  world/previews/schematics, made in the cloud).
- 2026-10-31: Gadgets, slices 2 and 3 (Hayden: "lets start with the next thing", prompts G2 and G3). All in code, so no
  scene was rebuilt; `Arsenal` places the new things at play time like the stall.
  - **Mods** (`Arsenal.MODS`): Freeze, Split, Bounce, Sparkle Magnet, sold at **Dash's workbench** (beside his stall,
    `_workbench()` in `gadget_stall.gd`, shop stall "Workbench", kind `mod`). Every gadget has two slots
    (`Arsenal.slots`, `fit()`, `cycle_mod()`); a mod she owns fits every gadget at once, but not both slots of one.
    Freeze: where a shot pops or splashes, a frosty puff (`scripts/frost_puff.gd`, `Arsenal.impact()`) chills enemies
    for 4 s (`Arsenal.chill()`/`slow()`: Gloops and Crocodillos move at 35%, with a snowflake and sparkles). Split: two
    of every shot, a bit smaller (`StarPopper.shoot`; two more Buzz Bots; two rainbow beams; two jellies). Bounce: off
    the ground or a wall once (bubbles, plush bolts, bot bubbles, fizz bombs, the disco ball; the rainbow beam bends
    once; jelly mines hop at enemies). Magnet: while that gadget is out, sparkles within 9 m fly to her
    (`Sparkle.magnet_to`, group "sparkles") and ammo bubbles drift from 9 m. **Combos** (`Arsenal.COMBOS`, by the two
    mods sorted): Icy Shards (Freeze + Split: puffs throw shards at the 3 nearest enemies, each a hit), Snowball
    Bounce (bounces leave puffs), Pinball (split shots bounce twice), and Magnet with anything doubles ammo drops.
  - **Upgrades** (`Arsenal.UPGRADES`, made into shop items `upgrade_<gadget>_<kind>_<level>` in `_register_shop()`):
    Bigger Tank (+25% ammo a level, not on the Star Popper), Quick Hands (-10% cooldown), Big Splash (+12% radius:
    splash, dance floor, beam, bot reach, plush reach, popper bubble size), three levels each, 4 to 15 sparkles; the
    bench shows only the next level of each for gadgets she owns. They're folded into `Arsenal.stat()`.
  - **Four new gadgets**, each with V1-V5 and a Mega: **Plushinator** (`scripts/plush_bolt.gd`, extends StarBubble):
    turns an enemy into a plushie for 4-8 s (`Arsenal.plush()`: physics off, Visual hidden, a toy built from shapes);
    one touch of anything pops it for 1-2 sparkles; Plush Party (V5) plushes everyone within 3.5 m. Not the Gloop King
    or a shelled Crocodillo. **Buzz Bots** (`scripts/buzz_bots.gd`): 3 gold bots orbit her for 12-20 s and blow bubbles
    (gadget "buzz") at the nearest enemy in reach; Buzz Swarm (V5) is 5. **Rainbow Ray** (`scripts/rainbow_ray.gd`):
    held Shoot (`StarPopper.shine()`, 1 ammo per 0.25 s), a striped beam 10-14 m; enemies in it fill with colour and
    pop; Double Rainbow (V5) goes through a whole row. **Jelly Mines** (`scripts/jelly_mine.gd`): dropped in front of
    her, up to 5 out for 40 s; enemies walking in stick, wobble and pop; Jelly Jamboree (V5) leaves two little ones.
    Sold at the stall (12-20 sparkles) with refills; refills only show for gadgets she owns.
  - `Arsenal.hit(enemy, power, dir, gadget)` is the one way the new gadgets hit things (plushies pop at one touch, pops
    credit the gadget through `StarPopper.popped`); `StarBubble._hit_target()` does the same for bubbles. Fizz and
    disco use it too.
  - **Ammo crates** (`scripts/ammo_crate.gd`, `Arsenal.CRATES`, dropped onto the ground): 10 bubble-wrapped crates
    (Market Square, 3 by the Gloop King, Skate Park, tree house, Spooky Woods, the far field, the lake shore). Pop one
    with anything or walk into it: every gadget refills by half. Back every day.
  - **Sounds** are made in code (`scripts/gadget_sfx.gd`, used by `Audio._stream()` when there's no .wav), since cloud
    sessions can't upload LFS wavs: plush_poof, buzz, rainbow_hum (loops), rainbow_pop, jelly, frost, crate.
  - UI: the wheel has seven slots, each with two mod dots, and names the mods and combo in the middle; the readout
    shows the mod dots. The Bag sheet has a **Gadgets** page (each gadget's version, ammo, upgrades and two "Mod n"
    buttons). The shop's rows now scroll past 60% of the screen.
  - Tests: `tools/test_arsenal.gd` has 120+ checks (every mod on every gadget, combos, upgrades, the new gadgets and
    their Megas, crates on open ground, sounds, saving). New capture `tools/capture_arsenal_mods.gd` (shots in the
    project files under world/previews/arsenal, made in the cloud).
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
- 2026-10-31: The First Night plan, F2 to F6 (Hayden: "Go").
  - **F2 game feel:** `scripts/juice.gd` (autoload `Juice`) is the one helper for feedback: `shake()` (camera
    h/v offset, trauma squared, settles in about a second and gives the camera back exactly), `hitstop()` (at most
    0.1 s, puts back whatever speed was there), `burst()` (`Fx.burst`), `squash()` (springs back to the node's own
    scale), `rumble()`, `blip()` (seven little sounds made in code: chime, pop, tick, whoosh, thud, sparkle, buzz),
    `chime_pickup()` (quick sparkle pickups climb a major scale) and `hit()`. Hooked into jumping, double jumps, rolls,
    landings, getting hurt, sparkles, every gadget's shot and pop, stomps, the Gloop King (belly-flop shake, hits, the
    pop), ollies, landings, grind sparks, bails, combo payouts, race countdowns, boosts and power-ups, quest and
    request complete, watch pickups, buying and doors. Settings > Assist: **Screen shake** (0 to 100%) and
    **Controller rumble**; Reduce motion turns shake and hit-pause off. `tools/test_juice.gd`.
  - **F3 sound:** `scripts/soundscape.gd` (autoload `Soundscape`) picks the music twice a second: a race, the Gloop
    King chasing you, the Autumn Festival on the green, a music zone, the Scary World, the Skate Park and Skate Yard,
    then the Void or Earth by time of day; `Audio.wanted_track()` falls back to `SCENE_MUSIC` for a track that isn't
    there. Ambience loops (birds, wind, water by the lake, creek and pond, the market, the little aliens, the
    mothership). Music ducks 9 dB under dialogue (`Audio.duck()`, kept apart from the Music slider). Voice blips per
    character on a new **Voices** bus with its own slider (Rook barks, the Green Man and the centipede hum). The barn
    studio's zone plays `barn_dance` (renamed at runtime, so `earth.tscn` wasn't rebuilt). Ten songs and six ambience
    loops are made from scratch by `tools/make_soundscape.py` (numpy + ffmpeg), all listed in `audio/CREDITS.md`.
    The .ogg files are LFS, so they were committed from the PC (Nov 1, from the project files'
    `world/galaxity-audio.zip`); re-run the script there to remake them. `tools/test_soundscape.gd`.
  - **F4 nights:** Hayden chose real unlocks (gadgets locked until their schematic is found, then bought at Dash's
    stall; new rides for racing: Overboard, Bike, Rocket Board, Rocket Bike, Flying Saucer). The 7-night plan is in
    the plan doc. Built so far: `scripts/nights.gd` (autoload `Nights`: which night it is, from `Requests.nights`),
    **night 2, Pip's Lamps** (`quests/night_2.json`, skippable: Pip waits at the portal and starts the boardwalk
    lamps, look at Dash's stall, find a S-K-A-T-E letter; 8 sparkles; starts on the first Void landing after the
    First Night is done, so an old save gets it once it's had the First Night it's offered), and the **Goals page** in the Tab menu between Quests and Map
    (tonight, next to aim for in watches, races, gadgets and skating, tomorrow's teaser). `tools/test_nights.gd`.
  - **F5 start:** the main scene is now the title screen (`scripts/title_screen.gd`): the Void at dawn as scenery
    (its Player taken out, the clock held and put back), Continue (hero, night, play time: new `Game.play_time`,
    saved), New Game (asks first with a save), Settings, Quit. The opening (about 35 s, skips with Jump, Interact,
    Esc or a click): Stars Hollow at midnight, the humming oak, the Void outside time, five watches ticking their own
    ways, "Tonight, one of them is you." `Game.continue_game()`, `Game.START_SCENE`. The loading screen
    (`scripts/loading_screen.gd`, autoload `Loading`) shows on trips between worlds from `Game.go()`, with a tip
    and a little waving alien drawn in code. `tools/test_title.gd`; tests that checked the main scene now check
    `Game.START_SCENE`.
  - **F6 playtest kit:** Settings > Assist > **Playtest notes** (off by default) has `scripts/playtest.gd`
    (autoload `Playtest`) write `user://playtest/notes_<date>.jsonl`: First Night and night steps and how long
    each took, stuck moments (3 minutes with nothing new), skips (new `Quests.skipped` signal), bails, menus,
    races and requests. No network code. `tools/playtest_report.gd` sums up the newest file. Guide for Hayden:
    /mnt/project-files/roadmap/playtest-guide.md. `tools/test_playtest.gd`.
  - Previews: `tools/capture_title.gd` (shots in the project files under world/previews/title_and_goals, made in
    the cloud).
- 2026-10-31: The First Night (Hayden: "Go", plan prompt F1). The opening quest line of a new game, so the first hour
  has a clear path: `quests/first_night.json` (six steps, run by Quests like every other quest) plus a little glue
  autoload, `scripts/first_night.gd` (`FirstNight`), for the bits a quest file can't do. **1 evening:** making the hero
  sets Earth to 8 PM (the creator doesn't pause the clock) and Nina knocks; she waits on the green (`green_s`) and says
  the oak hums at midnight; Mr. Palmer at the gazebo teaches talking, the menu and the map; then hello to two more
  people on the green (Dottie, Theo, Mr. Page and Ozzie are kept out by quest overrides). Earth's clock holds at 11 PM
  until this step's done, so a slow first look round never misses the first Shift. **2 wait:** Nina suggests the bed's
  "Until the Shift". **3 shift:** through the oak; the first landing in the Void plays the arrival moment (a swirl
  shader over the screen, gentle with Reduce motion) and puts the new **Shift Watch** on the hero's left wrist
  (`shop:shift_watch`, clothes.gd); Dash waits by the portal: a planet outside time, and some people are "chosen".
  **4 day** (a checklist): Dash at the market hands over the Star Popper (shoot tip), pop 3 Gloops (from
  `Requests.noted`), look at his gadget stall (new `Shop.opened` signal), Rex at the Skate Park lends a board and starts
  Coach Rook's lesson (push and ollie are on the list), finish one of Tally's requests, the fountain's lost watch
  (`water_clock`), say hi to Zippy. **5 king:** rumours point to the west fields (map star from the new `"at": [x, z]`
  in a step's `where`); popping him sets the flag `popped_gloop_king` (gloop_king.gd, for good) and cheers with
  confetti; Dash at `market_far_west` gives the **Gloop Crown** (new hat in cosmetics.gd, worn straight away) and 15
  sparkles, and hints at the Agent of Chaos watching from the far field. **6 home:** `Clock.pull_spawn` puts them in
  bed (HomeSpawn) when the Shift ends ("Was it all a dream?"), and Nina outside says "Same time tomorrow?" (+10).
  Every step can be skipped from the quest log: a quest file's `"skippable": true` gives the Quests sheet a "Skip this
  step" button (`Quests.skip()`). Old saves are offered it, never forced: Nina asks once (`fn_offered`) and the Quests
  sheet has a "Start The First Night" button. All progress is Dialogue flags (`fn_*`), so nothing new in the save.
  Dialogue text can now say any key with `{shoot}`, `{map}`, `{player_menu}`... (Settings.prompt). The creator's
  welcome says Stars Hollow on Earth. Test `tools/test_first_night.gd` walks it all (Shift fast-forwarded); previews
  `tools/capture_first_night.gd`, shots in project files under world/previews/first_night/ (cloud can't push png).
- 2026-10-31: Stars Hollow build-out, phase 3: things to do. Earth has days of the week now (`Clock.earth_day()`,
  `Clock.weekday()`: day 1 is a Friday; the HUD says "Earth, Monday"). Most of it is added at play time, so
  `earth.tscn` wasn't rebuilt (only `routines/earth_places.json`, for the festival's points).
  - **Notice board** (`scripts/earth_jobs.gd`, autoload `EarthJobs`): the Void's request board with Earth's jobs. It
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
    envelope on Mr. Palmer's porch addressed to the Mayor in the Void (flag `read_palmer_letter`: his "pen pal").
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
  `previews/arsenal/`. Slices 2 and 3 (mods, upgrades, four more gadgets, crates) are in: see 2026-10-31.
- 2026-10-29: The nightly request board (Hayden, "The First Night" prompt A). A lilac board with a spinning gold star
  stands at the edge of the Market Square (250 degrees round the fountain, mirroring Rex's noticeboard), and Tally,
  the tall yellow little alien, a bit bigger than the crowd and holding a clipboard, walks a ring round the fountain
  between the benches and the stalls. Both are added at runtime by the `Requests` autoload (`scripts/requests.gd`,
  `request_board.gd`, `request_alien.gd`, `request_spot.gd`), not built into `town.tscn`. Every Shift the board rolls
  three requests, once per visit (`Requests.visit_day()`: the Void's day at the Shift's dawn, so the Void's midnight
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

- 2026-10-29: Lost watches (Hayden, from the lore: everyone who lands on the Void has a watch that tracks time their
  own planet's or era's way). Twenty chosen kids lost theirs round the Void (`scripts/watches.gd`, autoload `Watches`):
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
  1 AM the portal by the old oak (`PortalToGalaxity`, opened by `earth_world.gd`) goes to the Void, and that hour is
  one Void day: the Void runs from dawn (7 AM) to the next dawn in 20 real minutes while Earth's clock crawls 24x
  slower, wherever the player is. The Void's clock waits at dawn between Shifts and its day number goes up once per
  visit. At 6 AM the Void warns, and when the Shift ends `Clock` pulls the player home to the old oak from any
  Void scene (`Clock.pulls_home`, off in tests that need it). The Void's portal and the pause menu go home early;
  on Earth in the Shift the pause menu goes through to the Void. Beds: on Earth, naps stop at midnight and "Until the
  Shift" waits for it; in the Void, sleep stops at dawn and ends the visit (`Clock.sleep()`, `end_shift()`).
  `Clock.hour()` and `period()` are local (Earth's on Earth); `hours()`, `time_string()` and `daylight()` stay
  The Void's. Saves are version 2; old ones still load: one made in the Void carries on there in the Shift (Earth's
  time worked out from the Void's), one made on Earth keeps Earth's time. Mr. Palmer on Earth talks to a neighbour
  now. `tools/test_clock.gd` and `tools/test_earth.gd` were rewritten, `tools/capture_shift.gd` (`previews/shift/`).

- 2026-10-28: Mr. Palmer's Void form, an alien mayor with an elephant trunk (`tools/build_mr_palmer_alien.py` →
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
  the mothership and landed in the Void (`tools/capture_astronaut.gd`, `previews/astronaut/`).
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
- 2026-10-23: Renamed Galactopia → Galaxity (now the Void). Earth got a full day/night sky (clouds, sunrise and sunset, stars,
  moon). The school's Entrance Garden got a greenhouse, vegetable beds, benches and a rose arch. The 3rd-floor
  window now shows the town's real mountains.
- 2026-10-22: Earth barn dance studio. Lilac fairytale Bojnice castle, the Crocodillo enemy, the green sky and the
  mothership (flies a loop; piloting it comes later). Castle school is Bojnice at real size.
- Earlier: Mr. Palmer, Earth town, Scary World, sparkles and shopping, town map, Pip and Bramble quests, Rex's
  campaign, the new town layout, walk-through effects, daily routines, dialogue, the clock, the Shift and sleeping.

## Open ideas / next up

- Skating (Hayden, Oct 23): THPS-style, every character playable with their own ride and moves, on controller and
  keyboard. Steps 1 to 4 are in (see the log). Bruno rides his SK8 Deck and coaches the lesson (Nov 1). Gap bonuses and timed runs are in (Nov 1). Races have their own circuits (Nov 11). Later: more grindable spots round town (boardwalk edges, castle steps).
- Clothes (Hayden, Oct 23): more clothes later. Mr. Palmer's town self could wear his outfit too.
- Add new requests here as they come in, and move them to the log when they're done.

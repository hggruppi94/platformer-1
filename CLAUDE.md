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
- In the show, kids are people on Earth and creatures in Galaxity. Nina keeps her Galaxity look on Earth for now.
- The player's hero is whoever the player makes; dialogue never assumes their name or gender (use `{player}`, `{they}`).

## Log (newest first)

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

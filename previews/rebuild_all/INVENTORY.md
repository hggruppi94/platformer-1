# Every model in the game, for the Hunyuan3D-2.1 rebuild (Nov 25, 2026)

Read-only inventory of `Godot Project/my-world` (made by `C:\Users\hggru\Game_dev\ai3d\runners\inventory.py`). The full
table, one row per .glb, is `inventory.csv`: path, kind, triangles, rigged, bones, animation names, material names,
how many textures, whether it has baked detail, which scripts and scenes load it, file size.

## Model files (.glb): 263

| Group | Files | Rigged | Baked detail | Triangles | Notes |
| --- | --- | --- | --- | --- | --- |
| Characters (`models/characters`) | 32 | 32 (17-25 bones) | 14 | 1,525,005 | Friends, the hero's bodies, Mr. Palmer (both forms), the Astronaut, Rook, the Green Man, Granny Purl, Sir Squiggle, 7 little aliens, the Agent of Chaos, the cyber gorilla, Hermez, Rolo |
| Props (`models/props`, top level) | 77 | 1 | 74 | 88,026 | Lamps, benches, the gazebo, stalls, fences, porches, furniture, signs, the playground, boats, the fire engine... |
| Props by place (`models/props/<place>`) | 154 | 0 | 154 | about 75,000 | Boulder Canyon, Clock Tower, Dark Hollow, Dusk's Embrace, Far Future, Frozen Moment, Glenmoor, Gloop Kingdom, Lanternmoor, nature, race circuits, Rootmind, Secret Garden, Seraph, Shard Isle, Skyreach, Star Arena, surfaces (17 tiling patches), swamp (16), Tide Reef, bosses (5) |

Characters without baked detail yet: the Astronaut, Green Man, Rook, Mr. Palmer, Mr. Palmer's Void form, the 7 little
aliens, Granny Purl, Sir Squiggle, and the bunny, cat, dino and Earth-kid hero bodies.

Oddities found: `mr_palmer.glb` carries a stray unit Icosphere helper mesh at his feet; three little-alien colours
(green, purple, red) and the swamp props aren't named in any script (their paths are built in code).

## What is NOT a model file (built from shapes in code), so the AI tool can't simply replace it

- **Places:** every building, the terrain, the towns (the Void, Stars Hollow), the castle school and every portal
  world, race circuit, lair and arena: `tools/build_*.gd` builders and the scripts that dress places at load.
- **Enemies and bosses:** Gloops and the Gloop King (and his cousins), Glorps, Crocodillos and the Boulderdillo, Time
  Goblins and Grandfather Tock, Fizzlers, shadow ghosts, Bog Wailers and Mucklings, the centipede, Old Ember, the
  Off-Beat, the Hush, the Gloam, the Thornknot, Big Buzz, Captain Glitch, Mama Glorp, the three guardians,
  Old Mossback, the Stormram, Tuskwinter, Grumblefin, the Dawn Snatcher, the Starhorn's old body, and the Seraph's
  body (its eyes, feathers and wheels are .glb parts).
- **Rides** (`scenes/player/ride_kit.gd`), **clothes and hats** (`scripts/clothes.gd`, `cosmetics.gd`), **hairstyles**
  (`hair_kit.gd`), townsfolk extras (`townsfolk.gd`), and many small props made by `detail_props.gd` swaps.

Turning any of those into model files first would be a separate, much bigger job (each script builds and animates its
own shapes), so it's left as Hayden's choice.

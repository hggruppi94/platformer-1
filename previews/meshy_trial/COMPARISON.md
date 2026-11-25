# AI 3D tools trial: Rolo the rhino vs Hermez the crane (Nov 25, 2026)

The plan: make two new characters from Sofi's show notes side by side. **Hermez** (a red-crowned crane by a lily
pond) our usual way, as the control. **Rolo** (a small, curious rhino kid) with an AI 3D generator, first Meshy, then
(after Meshy's free plan turned out to block its API) every free open-source image-to-3D tool on this PC.

## Status

| | |
| --- | --- |
| Hermez (control) | Done: model, rig, 6 animations, baked detail; stands by the new Lily Pond in the Void with his talk |
| Rolo, Meshy | Blocked. Signed in (balance 100 credits), but the API refuses every task on the free plan: "Task creation on the free plan is no longer supported" (402, plan_upgrade_required). Credits spent: 0 |
| Rolo, free tools | Five Rolos made after Hayden's go-ahead (Nov 25): see `rolo_all_tools.png`. Hayden picked the **Hunyuan3D-2.1** one; it's now in the game by the Lily Pond next to Hermez |

## Hermez, our usual way (the control)

| | |
| --- | --- |
| Made with | `tools/build_hermez.py` (Blender 4.5 script on `tools/char_kit.py`), then `tools/build_friend_detail.py hermez` |
| Time | about 25 minutes of writing and fixing the script; the machine time is 20 s to build, 5 s to export and about 65 s to bake the detail |
| Cost | free |
| Mesh | 47,296 triangles, 23,834 vertices, one skinned mesh, 18 named materials (Feather, Feather Grey, Feather Black, Crown, Beak, Satchel...), so the game can recolour parts by name like the friends |
| Rig | 18 bones, the friends' biped layout (same bone names) plus a neck bone |
| Animations | idle (breathing, head bob and look about, a happy wing shake once a loop), walk (high-stepping, head pumping), run, flap (a big wave), jump, fall |
| Textures | the detail set, 3 x 2048 x 2048 PNG (tint, normal, AO) on a second "Detail" UV map: feather rows and barbs, scaly legs, horn on the beak, canvas and leather on the satchel. Eyes, brows and blush stay crisp |
| Hand fixes | bones had to be listed parents-first; the black face mask and a chest puff looked odd, so they came out; the satchel strap sank into the body (moved out); the black flight feathers looked like claws (made wider); the first feather pattern looked like cracked eggshell (redone as soft rounded feather tips) |

Pictures:
- In Godot, as the game draws him (`tools/capture_friend_detail.gd`): `godot/before/` and `godot/after/` (face,
  side, front, middle, back, feet, full), side by side in `godot/cmp_02_face_34.png`, `godot/cmp_05_middle.png` and
  `godot/cmp_08_full.png`.
- In the Void at midday by the Lily Pond (`tools/capture_pond_friends.gd`): `godot/world/01_pond_wide.png`,
  `02_friends.png`, `03_hermez_close.png`.
- Blender (Cycles), before and after side by side: `cmp_hermez_three.png`, `cmp_hermez_face.png`.

Tests: `tools/test_pond_friends.gd` passes (model, idle and walk, rig, baked detail, crisp eyes, height, dialogue no
longer than three lines, the pond on the map, flat, off every path, nothing solid in it, Hermez on the ground,
facing the meadow, talkable, solid, a clear way up to him). `test_friend_detail` passes. `test_dialogue` and
`test_routines` fail the same checks with and without this change (Bramble's and Heather's first lines, Bruno at
10 PM), so those failures aren't from this work.

## Rolo's concept image (the same input for every tool)

`rolo_concept.png`: one of 12 made locally with SDXL-Turbo (diffusers, fp16) on the RTX 4070 SUPER: 4 steps,
768 x 768, about 9 GB VRAM, 3 minutes including the first model download. `rolo_concept_cutout.png` is it with the
background removed (rembg), squared and padded: the image every tool gets.

## Rolo per tool

Every tool got the same cut-out (`rolo_concept_cutout.png`). All renders: Blender Cycles, one fixed camera and sun,
each Rolo stood on the ground and scaled to 1.2 m tall, Hermez at his real 1.57 m. The sheet is
`rolo_all_tools.png` (front, three-quarter, back). Raw models stay outside the repo in
`C:\Users\hggru\Game_dev\ai3d\out` (renders in `C:\Users\hggru\Game_dev\ai3d\renders`).

| Tool | Licence | Ran | Time | VRAM peak | Triangles | UV / texture | How it looks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Meshy (API, free plan) | Meshy terms | no: the free plan can't create tasks | | | | | |
| TripoSR | MIT | yes, locally | 22 s | 2.3 GB | 117,024 | vertex colours only, no UVs | The right idea (tee, tail, ears) but lumpy and soft, washed-out colours, a small horn. Came out lying on its side (Z-up); turned upright for the pictures |
| Hunyuan3D-2 mini | Tencent community licence: **not licensed for use in the EU, UK or South Korea** | yes, locally, shape only | 70 s | 4.6 GB | 842,580, cut to 40,000 | none: its texture painter needs a compiled CUDA extension this PC can't build, and the Space's texture step is broken ("texgen_worker is not defined") | Clean, chunky, very close to the concept: big ears, open smile, tail, tee shape. Would need painting (or our usual materials) |
| Hunyuan3D-2.1 | same Tencent licence | yes, HF Space, shape only | 23 s | (Space) | 284,510 | none: shape + texture needs 270 s of GPU, over the anonymous limit ("Subscribe to Hugging Face PRO") | The cleanest shape: smooth, crisp face, horn, toes and tail. Same need for paint |
| TRELLIS | MIT | yes, HF Space | 26 s | (Space) | 11,724 | yes: UVs and a 1024 texture | The only one painted, and game-sized, but dark charcoal skin and a brown shirt (not lilac and orange), and the face is soft |
| TRELLIS.2 | MIT | no | | | | | Refused: the anonymous ZeroGPU quota was used up ("Try again in 23:59"). A free Hugging Face account token would raise the quota |
| Stable Fast 3D | Stability community licence (free under $1M revenue) | no | | | | | Locally the model is gated (needs a Hugging Face account and accepting its licence); the Space failed twice with no details |
| TripoSG | MIT | yes, locally, shape only | 140 s | 5.7 GB | 2,517,766 (would need cutting down) | none | A good shape with lots of fine detail (tummy swirl, folds), slightly lumpier than Hunyuan 2.1 |

What needed fixing by hand to run them here: TripoSR and TripoSG each need a compiled marching-cubes library
(torchmcubes, diso), so I wrote small stand-ins using scikit-image. TripoSR and Hunyuan need an older `transformers`
(4.44) than today's, and Hunyuan an older `diffusers` (0.31). Nothing could be compiled: there are no Visual Studio
C++ tools or CUDA toolkit on this PC.

Disk used: about 14 GB in `C:\Users\hggru\Game_dev\ai3d` (Python env, repos, outputs) and about 18 GB of model
downloads in `C:\Users\hggru\.cache\huggingface`.

None of the Rolos is rigged or animated yet. Next, once Hayden picks: rig it (UniRig, or our Blender biped bones),
add idle and walk, paint it if it's a shape-only one, bake detail with the `rhino` recipe, and drop it in as
`models/characters/rolo.glb` (the pond already has his spot and lines).

## Rolo, from the AI mesh to the game (Hunyuan3D-2.1, Hayden's pick)

| | Rolo (AI shape + our steps) | Hermez (our usual way) |
| --- | --- | --- |
| Made with | Hunyuan3D-2.1 shape (free HF Space), then `tools/build_rolo.py` (`--prep` once, then the build) and `build_friend_detail.py rolo` | `tools/build_hermez.py`, then `build_friend_detail.py hermez` |
| My time | about 15 minutes from the pick to a painted, rigged, animated model in Blender (most of it working out where his face, tee and feet are on the mesh); about 30 minutes to tested and in the game | about 25 minutes to the model, about 45 to tested and in the game |
| Machine time | 23 s on the Space for the shape; 5 s to build; 40 s to bake the detail | 20 s to build; 65 s to bake |
| Mesh | 284,510 triangles from the AI, cut to 40,000 (47,279 with the added eyes, brows, horn and tongue), one skinned mesh | 47,296 triangles |
| Materials | 17 named: Skin, Snout, Nose, Mouth, Tongue, Ear Inner, Tee, Toenail, Tuft, Horn, Brow, Blush and the eye set; painted onto the AI's faces by where they are on him | 18 named, each part made in its own colour |
| Rig | 21 bones: the friends' biped layout plus 4 tail bones; Blender's automatic (heat) weights | 18 bones; char_kit's distance weights |
| Animations | idle, walk, run, jump, fall | idle, walk, run, flap, jump, fall |
| Detail textures | 3 x 2048 (tint, normal, AO): rhino hide, knit tee, horn | 3 x 2048 |
| Hand fixes | had to add what the AI left off: proper eyes (it made only bumps), brows, the horn, a tongue; centre him on his body, not the box (his long tail pulled it back); a first pass painted the nostril colour into his eye sockets (tightened); 3 loose vertices the automatic weights missed went to the nearest bone | see above |
| Rough edges left | the colour borders follow the AI's triangles, so the tee's hem and the snout's edge are a bit jagged close up; his tail is long (about 1 m behind him); the wrinkle pattern reads a little stripy | |

The AI's shape (`tools/src/rolo_hunyuan21.glb`, 40k triangles, prepped) is kept in the repo as an input, like a
reference picture, so `build_rolo.py` can be run again.

Pictures (Godot):
- Before and after the baked detail: `godot/cmp_rolo_02_face_34.png`, `godot/cmp_rolo_05_middle.png`,
  `godot/cmp_rolo_08_full.png` (full sets in `godot/rolo_before/` and `godot/rolo_after/`).
- Both of them by the Lily Pond in the Void: `godot/world/02_friends.png`, `godot/world/04_rolo_close.png`,
  `godot/world/03_hermez_close.png`, `godot/world/01_pond_wide.png`.

Tests: `test_pond_friends` passes for both (models, idle and walk, rig, detail, crisp eyes, height, lines, standing
on the ground facing the meadow, talkable, solid, a clear way up). `test_friend_detail` passes. `test_dialogue` now
lists Hermez and Rolo; it and `test_routines` only fail the old checks that fail on main too.

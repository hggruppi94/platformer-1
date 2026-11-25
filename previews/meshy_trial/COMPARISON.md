# AI 3D tools trial: Rolo the rhino vs Hermez the crane (Nov 25, 2026)

The plan: make two new characters from Sofi's show notes side by side. **Hermez** (a red-crowned crane by a lily
pond) our usual way, as the control. **Rolo** (a small, curious rhino kid) with an AI 3D generator, first Meshy, then
(after Meshy's free plan turned out to block its API) every free open-source image-to-3D tool on this PC.

## Status

| | |
| --- | --- |
| Hermez (control) | Done: model, rig, 6 animations, baked detail; stands by the new Lily Pond in the Void with his talk |
| Rolo, Meshy | Blocked. Signed in (balance 100 credits), but the API refuses every task on the free plan: "Task creation on the free plan is no longer supported" (402, plan_upgrade_required). Credits spent: 0 |
| Rolo, free tools | Concept image made. Running the generators is waiting for Hayden's own go-ahead (this PC's auto-mode permission check refused to run code from the freshly cloned repos, and to send the concept to a Hugging Face Space, because the plan came from the coordinator, not from Hayden directly) |

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

Filled in as each one runs (same camera and lighting as Hermez).

| Tool | Licence | Ran | Time | VRAM peak | Triangles | UV / texture | How it looks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Meshy (API, free plan) | Meshy terms | no: the free plan can't create tasks | | | | | |
| TripoSR | MIT | waiting | | | | | |
| Hunyuan3D-2 (mini) | Tencent community licence: **not licensed for use in the EU, UK or South Korea** | waiting | | | | | |
| Hunyuan3D-2.1 | same Tencent licence | waiting | | | | | |
| TRELLIS | MIT | waiting | | | | | |
| TRELLIS.2 | MIT | waiting | | | | | |
| Stable Fast 3D | Stability community licence (free under $1M revenue) | waiting | | | | | |
| TripoSG | MIT | waiting | | | | | |

Notes for running them here: the PC has Python 3.12 and a CUDA-ready PyTorch (in `C:\Users\hggru\Game_dev\ai3d\base`),
but no Visual Studio C++ build tools and no CUDA toolkit, so anything that needs a compiled CUDA extension
(Hunyuan's texture painter, TRELLIS's spconv/nvdiffrast, SF3D's texture baker, TripoSG's diso) may not install
locally; those would need the build tools or their Hugging Face Spaces.

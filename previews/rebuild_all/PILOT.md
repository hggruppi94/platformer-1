# Hunyuan3D-2.1 rebuild: the pilot (4 models, Nov 25, 2026)

`tools/ai_rebuild.py <model>` (see its header). Shape made on this PC's RTX 4070 SUPER with Hunyuan3D-2.1 (Tencent
community licence: not licensed for use in the EU, UK or South Korea). Pictures from Godot
(`tools/capture_friend_detail.gd`): `pilot/<model>/before/` and `after/`, side by side in `pilot_sheet.png`. The
picture the AI was given is `pilot/<model>/ai_input.png`.

**Nothing on this branch changes the game yet**: the rebuilt models are kept outside the repo
(`C:\Users\hggru\Game_dev\ai3d\rebuild\<model>\game`), waiting for a decision.

| Model | Kind | Times (render / AI shape / fit / re-bake) | Triangles before → after | Verdict |
| --- | --- | --- | --- | --- |
| Mr. Palmer | human, rigged (17 bones, idle and walk) | 2 s / 65 s / 4 s / 28 s | 56,884 → 56,884 (48,784 AI body + his eyes, glasses and mouth kept) | **Good.** Same design, softer and more sculpted; a little colour noise where the sash meets the suit and round the boots |
| Cyber gorilla | enemy, rigged (17 bones, 7 animations) | 2 s / 64 s / 4 s / 30 s | 65,716 → 65,716 (49,716 + screen, eyes, glows kept) | **Good, one fix needed:** a thin square base under his feet (the AI's floor) that the trim missed; some fur/metal patches swapped on his black side |
| Agent of Chaos | boss, rigged (21 bones, idle, walk, chaos) | 2 s / 63 s / 4 s / 15 s | 77,540 → 77,540 | **Worse.** His many overlapping armour, gold, bone and cloth layers came back as one lumpy surface, so the colours land as camouflage blotches and his arms stretch when posed; `test_friend_detail` also notices a missing part |
| Antique car | baked prop | 2 s / 64 s / 9 s (bake) | 2,828 → 3,000 | **Worse.** From one front view the AI lost the grille's bars and the wheels' spokes; the old colours bake across smeared |

So about 1.5 to 2 minutes of machine time per model, no hand work. The tool does well on **single, chunky, soft
shapes** (people, creatures), and badly on **layered, hard-edged, mechanical** ones (armour, vehicles, most props).

Ideas if Hayden wants to go on: only rebuild the soft characters (most of the 32), keep the layered boss and hard
props as they are; give the AI more than one view (Hunyuan3D-2's multi-view model) for props; trim the floor base by
its shape, not just the footprint.

## Round 2: three views, and better colour carry-over

`pilot/pilot_sheet_mv.png`: original / one view (Hunyuan3D-2.1) / three views (Hunyuan3D-2mv, front, left and back
pictures of the old model at one scale: `ai_rebuild.py <model> --views=3`). Both AI rows use the new colour step:
each new face looks for the old surface along its own normal and only takes a face pointing the same way (so the
suit's colour no longer jumps onto the sash, or the metal onto the fur), then small leftover patches (under 1 face in
500) take their surroundings' colour, and anything in the bottom 3% that isn't near the old model (the AI's floor
tile) is cut away.

| Model | Three-view times (render / AI shape / fit / re-bake) | One view vs three views |
| --- | --- | --- |
| Mr. Palmer | 2 s / 233 s (first run downloads the model) / 11 s / 30 s | **Both good now; three views is closer** to the original's outline and his sash is cleaner |
| Cyber gorilla | 2 s / 140 s / 12 s / 30 s | Three views: the floor tile is gone and his body is closer, but his head came out all black (the fur/metal split on his face got lost). One view: a little of the floor tile is still under one foot |
| Agent of Chaos | 2 s / 137 s / 8 s / 17 s | Three views has truer colours, but both still put his arms in the wrong place, so they stretch out when he moves. Still worse than the original |
| Antique car | 2 s / 147 s / 17 s (bake) | Three views keeps the car's boxy grille and body far better, but the colours bake across dark and patchy. Still worse than the original |

Three views costs about 2.5 minutes of GPU time a model (5.7 GB VRAM) instead of 1. For soft characters it's the
better choice; for layered bosses and hard props neither is good enough yet.

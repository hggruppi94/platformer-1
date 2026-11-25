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

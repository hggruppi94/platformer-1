# Characters made with TRELLIS

`python tools/trellis_character.py <name> <stage>` makes a character from Sofi's art, one stage at a time. Each stage
saves into `previews/rebuild_all/trellis/<name>/` and can be run again on its own. Nothing goes into the game until
Hayden has approved the sheet and the walk.

| Stage | What it does | Stops for Hayden? |
| --- | --- | --- |
| `front` | Sofi's reference to a straight-on picture (SDXL + IP-Adapter, 12 candidates, `front/candidates.png`); save the pick as `front.png` | yes |
| `trellis` | `front.png` to `trellis.glb` with its own texture. TRELLIS.2 on this PC first (`ai3d/trellis_local/serve.bat`, about 90 s, under 5 GB of graphics memory), then the online TRELLIS / TRELLIS.2 | |
| `rig` | stands the character up at game height with feet flat, checks they're square, splits them into named parts, rigs them with the friends' bones, idle and walk, and runs the pose test | |
| `preview` | `sheet.png` (reference, front, model front, 3/4, side, back, face) and `walk_three.gif` / `walk_side.gif` | yes |

## Which generator (bake-off, Nov 27 2026)

All free, all on this PC, the same Nina picture (`previews/rebuild_all/trellis/generator_bakeoff.png`):

| Generator (`trellis.py` backend) | Time | Extra graphics memory | Verdict |
| --- | --- | --- | --- |
| TRELLIS.2, one picture (`local`) | 88 to 137 s | 4.2 GB | **The default.** Closest to the picture, sharp face, clean colours, sensible back |
| Pixal3D, front + side + back (`pixal3d-multi`) | 163 s | 5.6 GB | Close second: crispest bow and hair, but the eyes went green, and it needs side and back pictures (made from a TRELLIS.2 model first) |
| Pixal3D, one picture (`pixal3d`) | 212 s | 5.1 GB | Good face, but she leans forward from the side |
| TRELLIS 1, front + side + back (`local1-multi`) | 74 s | 3.6 GB | Right shape all round, but soft and dull |
| TRELLIS 1, one picture (`local1`) | 65 s | 3.9 GB | Invented a tail at the back, blotchy face |
| Hunyuan3D-2.1, one picture (`hunyuan21`) | 431 s | 7.0 GB | Heavy red blotches for blush, slowest; its licence excludes the EU, UK and South Korea |

Each faces a different way out of its generator; `trellis.py` writes the turn (`yaw`) into `trellis.json` and `rig.py`
uses it. Servers: TRELLIS.2 `ai3d/trellis_local/serve.bat` (port 7960), TRELLIS 1 `ai3d/trellis1_local/serve.bat`
(7961), Hunyuan3D-2.1 `ai3d/hunyuan21_local/hunyuan2-1-spz/serve.bat` (7962); Pixal3D runs as a command
(`ai3d/pixal3d`, its venv made from the TRELLIS.2 build's Python 3.11, with Python's headers added for Triton).

## The character's json

- `reference`, `base`, `paint`, `prompt`, `negative`, `strengths`, `ip_scales`, `seeds`: the `front` stage. `base` is
  any straight-on picture of the character; `paint` fixes it before SDXL redraws it (`poly`, `line`, `warm_skin`).
- `height`: game height in metres.
- `rig`: `box` (the character's box in `front.png`) and `joints` (pixels in `front.png` for hips, spine, chest, neck,
  head_top, and shoulder, elbow, wrist, fingers, hip, knee, ankle for `.L` and `.R`).
- `parts`: named parts in order. Each has `rgb` (one or more colours from the model's texture), and optionally `z`
  (a share of the height) and `absx` (metres from the middle) to say where it can be. Every part is its own material
  on the same texture, so the model looks the same but the game can find, recolour or hide a part by name.
- `weight_rules` (off unless true) and each part's `bones`: which bones a part may follow. **Off for TRELLIS
  characters**: on the TRELLIS.2 Nina the rules made stretching worse (straps 1.2x to 2.4x, hair's worst spot 3x to
  21x), because the clothes are the body's own surface. Use them for a separate layer over the body (a cape, a coat).
- `blend_rings`: how many rings of points round a part's edge may follow the next part's bones too (default 3).

## How the rig squares a character up

TRELLIS doesn't always hand a model back facing the camera, or even straight: Nina's round 2 came back with her body
turned about 24 degrees and her head about 35 degrees off her body. `rig.py`:

- finds her eyes (white texture next to a dark pupil, in the top quarter) to turn her the right way round;
- squares the body by the line between her feet (and the eyes, when the two agree);
- straightens a head that is turned on the body: turns the head bone until the eye line runs left-right and keeps that
  as her rest shape;
- softens the neck first (`soft_neck`, `neck_below`, `neck_above`, `neck_halfwidth`: points round the neck and chin
  blend from the chest bone to the head bone over about 20 cm), so the twist spreads instead of smearing;
- `voxel_weights: true` weights a sealed voxel copy of the model and copies the weights back (smoother across loose
  bits like straps); it's also the fallback when Blender's automatic weights fail.

## The pose test

`rig` strikes six poses (arms forward, arms out, elbows bent, head turned, a big step, a crouch) and writes how far
every edge stretches per part to `posetest.json`: the 95th percentile and the worst edge (1.0 = unchanged). Under 1.5
at the 95th percentile is fine; the worst edge is usually a fold in the armpit. `render_poses.py` draws each pose with
the parts in flat colours and with the real texture.

## Rules for the pictures (from the guide Hayden found)

- **Empty hands.** Anything held melts into the hand and can't be cut out again. Make props on their own.
- **Nothing thin.** Text, logos, wires, thin straps and whiskers get dropped or smeared. Build those in code.
- **Straight on, arms a little away from the body**, so the rig can tell arms from body.
- **Plain white background**, one character.
- **Several views help** (front, side, back) because the back is otherwise a guess. TRELLIS.2 on this PC only uses the
  first picture; TRELLIS 1 (`ai3d/trellis1_local`) uses several.

## To do

- **Crowd copy:** a 3,000-triangle copy of each model for when lots are on screen (the townsfolk, the little aliens).
  A full model is 40,000 to 60,000 triangles, and a crowd of those is slow.
- Run and jump animations, and spring bones in Godot for hair, tails and capes.

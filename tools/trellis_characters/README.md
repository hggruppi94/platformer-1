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

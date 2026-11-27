# Makes a character with TRELLIS (Hayden, Nov 27 2026: "I want to create all of the characters this way"), in stages
# that each save their results in previews/rebuild_all/trellis/<name>/ and can be run again on their own:
#   python tools/trellis_character.py <name> <stage>      stage: front | trellis | rig | preview | all
# The character's setup is tools/trellis_characters/<name>.json.
#   front    a straight-on, neutral-pose picture from Sofi's reference (SDXL + IP-Adapter, several candidates):
#            front/candidates.png and front.png (the pick). STOP here until Hayden approves front.png.
#   trellis  front.png -> trellis.glb: TRELLIS.2 on this PC (start C:/Users/hggru/Game_dev/ai3d/trellis_local/serve.bat
#            first; about 90 s a character, under 5 GB of graphics memory), or the TRELLIS Spaces online as a fallback.
#   rig      stand them up at game height, feet flat, check they're square, rig with the friends' bones, idle and walk
#            (needs the json's "rig": the joints' pixels in front.png). Texture kept exactly as TRELLIS made it.
#   preview  sheet.png (reference | front | model front, 3/4, side, back, face) and walk_three.gif / walk_side.gif.
# Not built yet: splitting the model into named material parts along its texture's colour edges (so clothes.gd can
# recolour and hide them), run and jump animations, hair bones.
# Nothing here touches the game: models are only copied into it once Hayden has approved them.
import json, subprocess, sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
AI3D = REPO.parent / "ai3d"
SDXL_PY = AI3D / "base/Scripts/python.exe"          # the venv with diffusers (outside the repo)
BLENDER = "C:/Program Files/Blender 4.5/blender.exe"
ST = TOOLS / "trellis_stages"


def run(cmd):
    print(">>", " ".join(str(c) for c in cmd), flush=True)
    subprocess.run([str(c) for c in cmd], check=True)


def main(name, stage):
    cfg_path = TOOLS / "trellis_characters" / f"{name}.json"
    cfg = json.load(open(cfg_path))
    out = REPO / "previews/rebuild_all/trellis" / name
    out.mkdir(parents=True, exist_ok=True)
    if stage in ("front", "all"):
        run([SDXL_PY, ST / "front.py", cfg_path, out / "front"])
        print("Pick the best candidate in", out / "front/candidates.png", "and save it as", out / "front.png")
        if stage == "all":
            return
    if stage in ("trellis",):
        run([sys.executable, ST / "trellis.py", out / "front.png", out])
    if stage in ("rig",):
        if "rig" not in cfg:
            sys.exit("Add a \"rig\" section (box and joints in front.png) to " + str(cfg_path))
        run([BLENDER, "-b", "--python", ST / "rig.py", "--", out / "trellis.glb", cfg_path, out])
    if stage in ("preview",):
        run([BLENDER, "-b", "--python", ST / "views.py", "--", out / "rigged.glb", out / "view"])
        run([sys.executable, ST / "sheet.py", REPO / cfg["reference"], out / "front.png", out / "sheet.png"])
        for view, ang in (("three", 35), ("side", 90)):
            run([BLENDER, "-b", out / "rigged.blend", "--python", ST / "render_walk.py", "--", out / f"walk_{view}",
                 "walk", 2, ang])
            from PIL import Image
            fr = [Image.open(out / f"walk_{view}" / f"f{i:03d}.png").convert("RGB") for i in range(60)]
            fr[0].save(out / f"walk_{view}.gif", save_all=True, append_images=fr[1:], duration=33, loop=0)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

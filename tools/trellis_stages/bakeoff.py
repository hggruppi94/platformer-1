# The generator bake-off sheet: every generator's model of the same picture, rendered the same way (front, 3/4, side,
# back, face), one row each, with how long it took and how much graphics memory it used.
#   python bakeoff.py <bakeoff dir> <out png> <backend>[:yaw] ...
# <bakeoff dir>/<backend>/trellis.glb, trellis.json (time) and vram_summary.txt come from the generator stage
# (trellis.py) run through ai3d/bakeoff/run.sh. yaw turns a model to face the camera (the local TRELLIS builds face +X).
import json, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root, dst = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
BLENDER = "C:/Program Files/Blender 4.5/blender.exe"
VIEWS = Path(__file__).with_name("views.py")
NAMES = {"local": "TRELLIS.2, front picture only", "local1": "TRELLIS 1, front picture only",
         "local1-multi": "TRELLIS 1, front + side + back", "hunyuan21": "Hunyuan3D-2.1, front picture only",
         "pixal3d": "Pixal3D, front picture only", "pixal3d-multi": "Pixal3D, front + side + back"}
H = 420
f_big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 24)
rows = []
for arg in sys.argv[3:]:
    b, _, yaw = arg.partition(":")
    d = root / b
    if not (d / "trellis.glb").exists():
        continue
    meta = json.load(open(d / "trellis.json"))
    yaw = yaw or str(meta.get("yaw", -90))
    if not (d / "v_face.png").exists():
        subprocess.run([BLENDER, "-b", "--python", str(VIEWS), "--", str(d / "trellis.glb"), str(d / "v"), yaw],
                       check=True, capture_output=True)
    secs = meta["secs"]
    vram = (d / "vram_summary.txt").read_text().split() if (d / "vram_summary.txt").exists() else []
    mem = f"{(int(vram[-2]) - int(vram[2])) / 1024:.1f} GB more graphics memory" if len(vram) > 4 else "memory not measured"
    ims = [Image.open(d / f"v_{v}.png").convert("RGB") for v in ("front", "three", "side", "back", "face")]
    ims = [im.resize((int(im.width * H / im.height), H)) for im in ims]
    rows.append((f"{NAMES.get(b, b)}   ({secs:.0f} s, {mem})", ims))
ref = root / "in"
inputs = [Image.open(ref / f"{v}.png").convert("RGB") for v in ("front", "side", "back") if (ref / f"{v}.png").exists()]
inputs = [im.resize((int(im.width * H / im.height), H)) for im in inputs]
rows.insert(0, ("The pictures given: front (all), side and back (multi-view only)", inputs))
W = max(sum(i.width + 10 for i in ims) for _, ims in rows) + 10
sheet = Image.new("RGB", (W, len(rows) * (H + 50) + 10), (235, 235, 240))
d = ImageDraw.Draw(sheet)
y = 10
for title, ims in rows:
    d.text((14, y), title, fill=(30, 30, 40), font=f_big)
    y += 36
    x = 10
    for im in ims:
        sheet.paste(im, (x, y))
        x += im.width + 10
    y += H + 14
sheet.save(dst)
print("SHEET", dst, sheet.size)

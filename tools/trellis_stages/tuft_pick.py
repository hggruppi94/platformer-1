# Saves the chosen front candidate as front.png on a plain white background (rembg cuts the character out: the
# Tuftling pictures come back with tinted or grey backgrounds, and TRELLIS wants one character on white).
#   <ai3d venv python> tuft_pick.py <name> <candidate file name>
import sys
from pathlib import Path
from PIL import Image
from rembg import remove

REPO = Path(__file__).resolve().parents[2]
out = REPO / "previews/rebuild_all/trellis" / sys.argv[1]
im = Image.open(out / "front" / sys.argv[2]).convert("RGB")
cut = remove(im)
white = Image.new("RGB", im.size, "white")
white.paste(cut, (0, 0), cut)
white.save(out / "front.png")
(out / "front" / "pick.txt").write_text(sys.argv[2] + "\n")
print("PICK", sys.argv[1], sys.argv[2], cut.getbbox())

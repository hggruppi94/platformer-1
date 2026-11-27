# Stage preview of tools/trellis_character.py: one sheet, Sofi's reference | front.png | the model from the front,
# 3/4, side, back and a face close-up (views.py's view_*.png next to the output).
#   python sheet.py <reference> <front.png> <sheet.png>
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ref, front, dst = sys.argv[1], sys.argv[2], Path(sys.argv[3])
H = 560


def fit(p):
    im = Image.open(p).convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    im = bg.convert("RGB")
    return im.resize((int(im.width * H / im.height), H))


ims = [fit(ref), fit(front)] + [fit(dst.parent / f"view_{v}.png") for v in ("front", "three", "side", "back", "face")]
sheet = Image.new("RGB", (sum(i.width for i in ims) + 10 * len(ims) + 10, H + 70), (235, 235, 240))
d = ImageDraw.Draw(sheet)
d.text((14, 10), "Sofi's art | front picture given to TRELLIS | the model: front, 3/4, side, back, face", fill=(30, 30, 40),
       font=ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26))
x = 10
for im in ims:
    sheet.paste(im, (x, 50))
    x += im.width + 10
sheet.save(dst)

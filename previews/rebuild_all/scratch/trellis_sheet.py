import sys
from PIL import Image, ImageDraw, ImageFont
R = "C:/Users/hggru/Game_dev/ai3d/nina_trellis/r/"
f = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
H = 560
def fit(p, h=H):
    im = Image.open(p).convert("RGBA"); bg = Image.new("RGBA", im.size, (255, 255, 255, 255)); bg.alpha_composite(im)
    im = bg.convert("RGB"); return im.resize((int(im.width * h / im.height), h))
rows = [("Nina: Sofi's art | picture given to TRELLIS | TRELLIS model (front, 3/4, side, back, face)",
         [fit(sys.argv[1]), fit(sys.argv[2])] + [fit(R + "nina_" + v + ".png") for v in ("front", "three", "side", "back", "face")]),
        ("Rolo (TRELLIS, from the trial), same camera, for reference",
         [fit(R + "rolo_" + v + ".png") for v in ("front", "three", "side", "back", "face")])]
W = max(sum(i.width for i in r) + 10 * len(r) for _, r in rows) + 20
sheet = Image.new("RGB", (W, len(rows) * (H + 60) + 10), (235, 235, 240)); d = ImageDraw.Draw(sheet)
y = 10
for title, ims in rows:
    d.text((14, y), title, fill=(30, 30, 40), font=f); y += 40; x = 10
    for im in ims: sheet.paste(im, (x, y)); x += im.width + 10
    y += H + 20
sheet.save(sys.argv[3]); print(sheet.size)

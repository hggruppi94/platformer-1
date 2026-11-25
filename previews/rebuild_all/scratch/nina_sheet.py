# The Nina sheet: Sofi's picture, then each free tool's Nina from the front, three-quarters and back
import os
from PIL import Image, ImageDraw, ImageFont
O = "C:/Users/hggru/Game_dev/ai3d/rebuild/nina/all_free/r/"
ROWS = [("TripoSR", "triposr", "its own colour (vertex colours)"),
        ("Hunyuan3D-2 mini", "hunyuan2mini", "shape only: colour projected from the picture by us"),
        ("Hunyuan3D-2.1", "hunyuan21", "shape only: colour projected from the picture by us"),
        ("TripoSG", "triposg", "shape only: colour projected from the picture by us"),
        ("TRELLIS", "trellis", "its own texture"),
        ("TRELLIS.2", "trellis2", "its own texture"),
        ("Hunyuan3D-2.1 with its paint", "hunyuan21paint", "its own texture"),
        ("Hunyuan3D-2 with its paint", "hunyuan2paint", "its own texture")]
tw, th, lab = 240, 330, 40
font = ImageFont.truetype("arial.ttf", 22); small = ImageFont.truetype("arial.ttf", 16)
W = tw * 4; H = lab + len(ROWS) * (th + lab)
s = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(s)
d.text((10, 8), "Nina from Sofi's original picture, on every free AI 3D tool", fill="black", font=font)
pic = Image.open("C:/Users/hggru/Game_dev/ai3d/concept/nina_main_input.png").convert("RGB")
pic.thumbnail((tw, th * 2)); s.paste(pic, (0, lab + 10))
d.text((10, lab + 10 + pic.size[1] + 4), "Input (Sofi's art, cut out)", fill="black", font=small)
for i, (name, key, note) in enumerate(ROWS):
    y = lab + i * (th + lab)
    d.text((tw + 10, y + 4), f"{name}: {note}", fill="black", font=small)
    for j, v in enumerate(["front", "three", "back"]):
        x = tw * (j + 1)
        f = f"{O}{key}_{v}.png"
        if os.path.exists(f):
            im = Image.open(f).convert("RGB").crop((110, 150, 370, 600)).resize((tw, th - 26))
            s.paste(im, (x, y + 26))
        else:
            d.rectangle([x + 6, y + 30, x + tw - 6, y + th - 4], outline="gray")
            d.text((x + 20, y + th // 2), "quota: not run yet", fill="gray", font=small)
s.save("C:/Users/hggru/Game_dev/pf1-ai-rebuild/previews/rebuild_all/scratch/nina_all_tools.png")
print("sheet", s.size)

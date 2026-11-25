# Sofi's main Nina picture as TRELLIS's input: cropped to her, the letter tiles painted out, the background cut away
import sys
import numpy as np, cv2
from PIL import Image
from rembg import remove
im = cv2.imread(sys.argv[1])
h, w = im.shape[:2]
# the letter tiles: dark grey squares in the lower part of the picture
hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV)
dark = (hsv[..., 2] < 75).astype(np.uint8)
dark[: int(h * 0.68)] = 0          # only the tiles' rows, not her eyes or the backpack's straps
dark[int(h * 0.91):] = 0           # the black bar under the picture is cropped off below
tiles = cv2.dilate(dark, np.ones((9, 9), np.uint8))
# letters on the tiles (yellow, blue) sit inside the tiles' boxes: fill each tile box whole
n, lab, stats, _ = cv2.connectedComponentsWithStats(tiles)
mask = np.zeros_like(tiles)
for i in range(1, n):
    x, y, bw, bh, area = stats[i]
    if area > 400:
        mask[y:y + bh, x:x + bw] = 1
fixed = cv2.inpaint(im, mask * 255, 9, cv2.INPAINT_TELEA)
fixed = fixed[: int(h * 0.905)]
rgba = remove(Image.fromarray(cv2.cvtColor(fixed, cv2.COLOR_BGR2RGB)))
a = np.asarray(rgba)
ys, xs = np.nonzero(a[..., 3] > 20)
box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
cut = rgba.crop(box)
side = int(max(cut.size) * 1.1)
out = Image.new("RGB", (side, side), "white")
out.paste(cut, ((side - cut.size[0]) // 2, (side - cut.size[1]) // 2), cut)
out.save(sys.argv[2])
Image.fromarray((mask * 255).astype(np.uint8)).save(sys.argv[2].replace(".png", "_tiles.png"))
print("done", box)

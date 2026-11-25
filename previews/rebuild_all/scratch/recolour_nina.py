# Sofi's hippo girl turnaround (front view) in Nina's colours from her main reference: red hair, pink overalls and
# straps, warm grey-brown skin; the backpack stays yellow
import sys
from PIL import Image
import numpy as np
from skimage.color import rgb2hsv, hsv2rgb
im = Image.open(sys.argv[1]).convert("RGB").crop((60, 60, 400, 790))
hsv = rgb2hsv(np.asarray(im))
H, S, V = hsv[..., 0], hsv[..., 1], hsv[..., 2]
h, w = H.shape
yy, xx = np.mgrid[0:h, 0:w]
yel = (H > 0.09) & (H < 0.19) & (S > 0.35)
ov = yel & ((xx > int(sys.argv[3])) | ((yy > 520) & (xx > 100))) & (yy > 300)
out = hsv.copy()
out[..., 0] = np.where(ov, 0.94, H); out[..., 1] = np.where(ov, S * 0.55, S)
eyes = (xx > 170) & (xx < 300) & (yy > 150) & (yy < 220)
hair = (H > 0.02) & (H < 0.095) & (S > 0.45) & (yy < 330) & ~eyes
out[..., 0] = np.where(hair, 0.005, out[..., 0]); out[..., 1] = np.where(hair, np.clip(S * 1.1, 0, 1), out[..., 1])
skin = (H > 0.5) & (H < 0.8) & (S > 0.08)
out[..., 0] = np.where(skin, 0.06, out[..., 0]); out[..., 1] = np.where(skin, S * 0.5, out[..., 1])
bow = ((H > 0.85) | (H < 0.02)) & (S > 0.2) & (yy < 90) & (xx > 200)
out[..., 0] = np.where(bow, 0.995, out[..., 0]); out[..., 1] = np.where(bow, 0.85, out[..., 1]); out[..., 2] = np.where(bow, V * 0.9, out[..., 2])
img = Image.fromarray((np.clip(hsv2rgb(out), 0, 1) * 255).astype(np.uint8))
side = max(img.size); sq = Image.new("RGB", (side, side), "white"); sq.paste(img, ((side - img.size[0]) // 2, 0))
sq.save(sys.argv[2])

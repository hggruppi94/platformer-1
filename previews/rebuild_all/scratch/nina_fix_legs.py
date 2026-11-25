# Repaints the part of Nina the letter tiles covered (her lower overalls and legs) with SDXL-Turbo inpainting
import sys, torch, numpy as np
from PIL import Image, ImageFilter
from diffusers import AutoPipelineForInpainting
src, mask_full, out = sys.argv[1], sys.argv[2], sys.argv[3]
box = (91, 177, 923, 1810)
img = Image.open(src).convert("RGB")
m = Image.open(mask_full).convert("L").crop(box)
side = img.size[0]
pad = Image.new("L", (side, side), 0)
pad.paste(m, ((side - m.size[0]) // 2, (side - m.size[1]) // 2))
pad = pad.filter(ImageFilter.MaxFilter(15))
pipe = AutoPipelineForInpainting.from_pretrained("stabilityai/sdxl-turbo", torch_dtype=torch.float16, variant="fp16").to("cuda")
prompt = "3D cartoon hippo girl, pink denim overalls with rolled-up cuffs, short grey-brown legs, pink sneakers, plain white background"
for seed in range(int(sys.argv[4]), int(sys.argv[5])):
    g = torch.Generator("cuda").manual_seed(seed)
    r = pipe(prompt=prompt, image=img.resize((768, 768)), mask_image=pad.resize((768, 768)), strength=0.99,
             num_inference_steps=4, guidance_scale=0.0, generator=g).images[0]
    # only the masked part changes: the rest stays Sofi's picture at full size
    r = r.resize(img.size)
    res = Image.composite(r, img, pad.filter(ImageFilter.GaussianBlur(4)))
    res.save(f"{out}_{seed}.png")
print("done")

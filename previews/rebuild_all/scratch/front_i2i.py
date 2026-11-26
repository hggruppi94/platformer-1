# A straight-on, standing Nina in Sofi's look: our game Nina in her rest pose (front, arms a little out) as the shape
# to follow, repainted by SDXL-Turbo towards Sofi's main picture
import sys, torch
from PIL import Image
from diffusers import AutoPipelineForImage2Image
src = sys.argv[1]
P = ("3D render, cute cartoon baby hippo girl standing straight facing the camera, front view, symmetrical, "
     "grey-brown hippo skin, big brown eyes, long straight bright red hair with fringe, big shiny red bow on top of head, "
     "white t-shirt, pink denim overalls with rolled cuffs, yellow backpack straps, pink sneakers, pixar style, white background")
im = Image.open(src).convert("RGB").resize((768, 768))
pipe = AutoPipelineForImage2Image.from_pretrained("stabilityai/sdxl-turbo", torch_dtype=torch.float16, variant="fp16").to("cuda")
for st in (0.45, 0.55, 0.65):
    for seed in range(4):
        g = torch.Generator("cuda").manual_seed(seed)
        out = pipe(prompt=P, image=im, strength=st, num_inference_steps=4, guidance_scale=0.0, generator=g).images[0]
        out.save(f"front_{int(st*100)}_{seed}.png")
print("done")

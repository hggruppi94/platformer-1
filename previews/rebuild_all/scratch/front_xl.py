# The straight-on Nina repainted in the style and detail of Sofi's main picture: SDXL-Turbo image-to-image from the
# front picture (the pose), with IP-Adapter showing it Sofi's picture (the look)
import sys, torch
from PIL import Image
from diffusers import AutoPipelineForImage2Image
from transformers import CLIPVisionModelWithProjection
enc = CLIPVisionModelWithProjection.from_pretrained("h94/IP-Adapter", subfolder="models/image_encoder", torch_dtype=torch.float16)
pipe = AutoPipelineForImage2Image.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", image_encoder=enc, torch_dtype=torch.float16,
                                                  variant="fp16").to("cuda")
pipe.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter-plus_sdxl_vit-h.safetensors")
base = Image.open(sys.argv[1]).convert("RGB").resize((1024, 1024), Image.LANCZOS)
ref = Image.open(sys.argv[2]).convert("RGB")
P = ("detailed 3D render of a cute baby hippo girl standing facing the camera, front view, long glossy red hair with fringe, "
     "big shiny red bow, pink denim overalls, white t-shirt, yellow backpack, pink sneakers, white background")
for scale in (0.6, 0.8):
    pipe.set_ip_adapter_scale(scale)
    for st in (0.55, 0.7):
        for seed in range(2):
            g = torch.Generator("cuda").manual_seed(seed)
            out = pipe(prompt=P, image=base, ip_adapter_image=ref, strength=st, num_inference_steps=30, guidance_scale=6.0, negative_prompt="blurry, plain, toy, low detail, side view, turned, extra limbs",
                       generator=g).images[0]
            out.save(f"xl_{int(scale*10)}_{int(st*100)}_{seed}.png")
print("done")

# Style test B: draw the character from scratch (not by repainting a picture) in Sofi's style, standing square on for
# TRELLIS: SDXL with IP-Adapter Plus looking at Sofi's own picture (her style and design), and an OpenPose skeleton
# (ControlNet, xinsir/controlnet-openpose-sdxl-1.0) holding her in a front-on A-pose. Optionally a style LoRA (test C).
#   <ai3d venv python> style_b.py <Sofi's picture> <out dir> [lora.safetensors] [lora weight]
import sys
from pathlib import Path
import torch
from PIL import Image, ImageDraw

ref_path, out = Path(sys.argv[1]), Path(sys.argv[2])
lora = sys.argv[3] if len(sys.argv) > 3 else None
lora_w = float(sys.argv[4]) if len(sys.argv) > 4 else 0.9
out.mkdir(parents=True, exist_ok=True)

# The skeleton, in OpenPose's COCO-18 order and colours: her joints as measured on the approved front picture
# (person's right on the picture's left), a chibi body with a big head.
K = [(515, 300), (515, 440), (345, 490), (285, 565), (268, 640), (685, 490), (745, 565), (765, 640),
     (445, 730), (440, 820), (438, 900), (590, 730), (595, 820), (598, 900), (455, 230), (585, 230), (360, 150),
     (670, 150)]
LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10), (1, 11), (11, 12), (12, 13),
         (1, 0), (0, 14), (14, 16), (0, 15), (15, 17)]
COLS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0),
        (0, 255, 85), (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255),
        (170, 0, 255), (255, 0, 255), (255, 0, 170), (255, 0, 85)]
pose = Image.new("RGB", (1024, 1024), (0, 0, 0))
d = ImageDraw.Draw(pose)
for i, (a, b) in enumerate(LIMBS):
    d.line([K[a], K[b]], fill=tuple(int(c * 0.6) for c in COLS[i]), width=10)
for i, p in enumerate(K):
    d.ellipse([p[0] - 6, p[1] - 6, p[0] + 6, p[1] + 6], fill=COLS[i])
pose.save(out / "pose.png")

from diffusers import ControlNetModel, StableDiffusionXLControlNetPipeline   # noqa: E402
from transformers import CLIPVisionModelWithProjection                     # noqa: E402
enc = CLIPVisionModelWithProjection.from_pretrained("h94/IP-Adapter", subfolder="models/image_encoder",
                                                    torch_dtype=torch.float16)
cn = ControlNetModel.from_pretrained("xinsir/controlnet-openpose-sdxl-1.0", torch_dtype=torch.float16)
pipe = StableDiffusionXLControlNetPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", controlnet=cn,
                                                           image_encoder=enc, torch_dtype=torch.float16,
                                                           variant="fp16")
pipe.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter-plus_sdxl_vit-h.safetensors")
if lora:
    pipe.load_lora_weights(lora, adapter_name="style")
    pipe.set_adapters(["style"], adapter_weights=[lora_w])
pipe.enable_model_cpu_offload()
ref = Image.open(ref_path).convert("RGB")
tag = "sofistyle, " if lora else ""
P = (tag + "3d cartoon render of a cute baby hippo girl standing straight and facing the camera, full body, front view, "
     "arms relaxed slightly away from her body, empty hands, warm grey-brown skin, glossy red bob haircut with a "
     "fringe, big red bow on top of her head, big brown eyes with lashes, two buck teeth, happy smile, white t-shirt, "
     "long pink overalls with rolled cuffs, yellow backpack on her back with its straps over her shoulders, pink "
     "sneakers, plain white background")
N = "side view, three quarter view, turned, holding anything, text, letters, watermark, blurry, extra limbs, shorts, multiple characters"
for ip in (0.5, 0.7):
    pipe.set_ip_adapter_scale(ip)
    for cs in (0.7, 0.95):
        for seed in (0, 1):
            im = pipe(prompt=P, negative_prompt=N, image=pose, ip_adapter_image=ref, controlnet_conditioning_scale=cs,
                      num_inference_steps=30, guidance_scale=6.0, width=1024, height=1024,
                      generator=torch.Generator("cuda").manual_seed(seed)).images[0]
            name = f"cand_ip{int(ip * 100)}_cn{int(cs * 100)}_{seed}.png"
            im.save(out / name)
            print("B", name, flush=True)

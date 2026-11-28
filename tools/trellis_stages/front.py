# Stage a of tools/trellis_character.py: a straight-on, neutral-pose picture of a character for TRELLIS.
#   <ai3d venv python> front.py <character json> <out dir>
# TRELLIS builds whatever the picture shows, so the picture has to be the character as Sofi drew them, facing the
# camera, arms a little away from the body (so the rig can tell arms from body). It starts from the character's "base"
# picture (already straight-on), paints the config's fixes onto it (long trousers, a fringe, warmer skin...), then
# SDXL image-to-image redraws it with IP-Adapter looking at Sofi's reference, so the paint turns into real cloth and
# hair in her style. Every candidate is kept; base_painted.png shows what SDXL was given.
import json, sys
from pathlib import Path
import torch
from PIL import Image, ImageDraw

cfg = json.load(open(sys.argv[1]))
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
repo = Path(sys.argv[1]).resolve().parents[2]

base = Image.open(repo / cfg["base"]).convert("RGB").resize((1024, 1024), Image.LANCZOS)
px = base.load()
d = ImageDraw.Draw(base)
for op in cfg.get("paint", []):
    if op["kind"] == "warm_skin":
        # grey skin -> warm grey-brown: greyish pixels (red a little over green and blue, never bluer than green, so
        # pink cloth, red hair, yellow and white are left) inside the character's box, given the warm tint at their own
        # brightness
        x0, y0, x1, y1 = op["box"]
        tr, tg, tb = op["to"]
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, b = px[x, y]
                if 90 < r < 230 and r - b < 58 and r - g < 45 and g >= b - 6 and max(r, g, b) < 232:
                    lum = (r + g + b) / 3
                    px[x, y] = (int(lum * tr), int(lum * tg), int(lum * tb))
    elif op["kind"] == "bg_white":
        # the background to white, flood-filled from each corner (so a colour like the background inside the
        # character is left alone)
        for corner in ((0, 0), (1023, 0), (0, 1023), (1023, 1023)):
            ImageDraw.floodfill(base, corner, (255, 255, 255), thresh=op.get("thresh", 40))
    elif op["kind"] == "poly":
        d.polygon([tuple(p) for p in op["points"]], fill=tuple(op["colour"]))
    elif op["kind"] == "line":
        d.line([tuple(p) for p in op["points"]], fill=tuple(op["colour"]), width=op["width"])
base.save(out / "base_painted.png")

from diffusers import AutoPipelineForImage2Image                      # noqa: E402
from transformers import CLIPVisionModelWithProjection                # noqa: E402
enc = CLIPVisionModelWithProjection.from_pretrained("h94/IP-Adapter", subfolder="models/image_encoder",
                                                    torch_dtype=torch.float16)
pipe = AutoPipelineForImage2Image.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", image_encoder=enc,
                                                  torch_dtype=torch.float16, variant="fp16").to("cuda")
pipe.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter-plus_sdxl_vit-h.safetensors")
if cfg.get("lora"):
    # the style model trained on Sofi's pictures (tools/trellis_stages/train_style.sh); its trigger word goes first
    pipe.load_lora_weights(cfg["lora"], adapter_name="style")
    pipe.set_adapters(["style"], adapter_weights=[cfg.get("lora_weight", 0.9)])
ref = Image.open(repo / cfg["reference"]).convert("RGB")
made = []
for scale in cfg["ip_scales"]:
    pipe.set_ip_adapter_scale(scale)
    for st in cfg["strengths"]:
        for seed in cfg["seeds"]:
            g = torch.Generator("cuda").manual_seed(seed)
            im = pipe(prompt=cfg["prompt"], negative_prompt=cfg["negative"], image=base, ip_adapter_image=ref,
                      strength=st, num_inference_steps=30, guidance_scale=6.0, generator=g).images[0]
            name = f"cand_ip{int(scale * 100)}_s{int(st * 100)}_{seed}.png"
            im.save(out / name)
            made.append(name)
            print("FRONT", name, flush=True)
json.dump(made, open(out / "candidates.json", "w"), indent=1)

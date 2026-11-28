# The front stage for the Tuftlings (Secret Garden folk), drawn from scratch rather than by repainting a picture:
# SDXL with IP-Adapter Plus looking at Hayden's archer picture (its style: fuzzy fur, big dark eyes, pointy ears,
# leaf skirts) and an OpenPose skeleton (ControlNet, xinsir/controlnet-openpose-sdxl-1.0) holding them straight on in
# an A-pose with empty hands, as TRELLIS needs. Like style_b.py (Nina's C5), but with no style LoRA: the LoRA is
# trained on Sofi's art, and the Tuftlings follow Hayden's picture instead.
#   <ai3d venv python> tuft_front.py <character json> [<character json> ...]
# Each json's "front_run" says the picture, the prompt and the sweep; candidates go into
# previews/rebuild_all/trellis/<name>/front/ with candidates.png, a contact sheet to pick from.
import json, sys
from pathlib import Path
import torch
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]

# The skeleton in OpenPose's COCO-18 order (person's right on the picture's left), with the archer's own
# proportions: a head about a quarter of the height, long legs, arms hanging a little away from the body.
K = [(512, 245), (512, 318), (385, 350), (348, 460), (330, 570), (639, 350), (676, 460), (694, 570),
     (455, 520), (448, 735), (444, 905), (569, 520), (576, 735), (580, 905), (468, 212), (556, 212), (395, 205),
     (629, 205)]
LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10), (1, 11), (11, 12), (12, 13),
         (1, 0), (0, 14), (14, 16), (0, 15), (15, 17)]
COLS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0),
        (0, 255, 85), (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255),
        (170, 0, 255), (255, 0, 255), (255, 0, 170), (255, 0, 85)]


def skeleton(scale=1.0):
    # A smaller character (Tumble) is the same skeleton shrunk towards its feet, so the head stays big.
    pts = [(512 + (x - 512) * scale, 905 - (905 - y) * scale) for x, y in K]
    pose = Image.new("RGB", (1024, 1024), (0, 0, 0))
    d = ImageDraw.Draw(pose)
    for i, (a, b) in enumerate(LIMBS):
        d.line([pts[a], pts[b]], fill=tuple(int(c * 0.6) for c in COLS[i]), width=10)
    for i, p in enumerate(pts):
        d.ellipse([p[0] - 6, p[1] - 6, p[0] + 6, p[1] + 6], fill=COLS[i])
    return pose


def contact(paths, out):
    ims = [Image.open(p).convert("RGB").resize((384, 384)) for p in paths]
    cols = 4
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 384, rows * 404), "white")
    d = ImageDraw.Draw(sheet)
    for i, (im, p) in enumerate(zip(ims, paths)):
        x, y = (i % cols) * 384, (i // cols) * 404
        sheet.paste(im, (x, y))
        d.text((x + 6, y + 386), Path(p).stem, fill="black")
    sheet.save(out)


from diffusers import ControlNetModel, StableDiffusionXLControlNetPipeline   # noqa: E402
from transformers import CLIPVisionModelWithProjection                     # noqa: E402
enc = CLIPVisionModelWithProjection.from_pretrained("h94/IP-Adapter", subfolder="models/image_encoder",
                                                    torch_dtype=torch.float16)
cn = ControlNetModel.from_pretrained("xinsir/controlnet-openpose-sdxl-1.0", torch_dtype=torch.float16)
pipe = StableDiffusionXLControlNetPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", controlnet=cn,
                                                           image_encoder=enc, torch_dtype=torch.float16,
                                                           variant="fp16")
pipe.load_ip_adapter("h94/IP-Adapter", subfolder="sdxl_models", weight_name="ip-adapter-plus_sdxl_vit-h.safetensors")
pipe.enable_model_cpu_offload()

for cfg_path in sys.argv[1:]:
    cfg = json.load(open(cfg_path))
    run = cfg["front_run"]
    out = REPO / "previews/rebuild_all/trellis" / cfg["name"] / "front"
    out.mkdir(parents=True, exist_ok=True)
    pose = skeleton(run.get("pose_scale", 1.0))
    pose.save(out / "pose.png")
    ref = Image.open(REPO / cfg["reference"]).convert("RGB")
    made = []
    for ip, cs, seed in run["sweep"]:
        seed = int(seed)
        pipe.set_ip_adapter_scale(ip)
        # SDXL's two text encoders each read 77 tokens: the character in "prompt", the shared style in "prompt_2"
        im = pipe(prompt=run["prompt"], prompt_2=run.get("prompt_2"), negative_prompt=run["negative"],
                  image=pose, ip_adapter_image=ref,
                  controlnet_conditioning_scale=cs, num_inference_steps=30, guidance_scale=6.0, width=1024,
                  height=1024, generator=torch.Generator("cuda").manual_seed(seed)).images[0]
        name = f"cand_ip{int(ip * 100)}_cn{int(cs * 100)}_{seed}.png"
        im.save(out / name)
        made.append(out / name)
        print("FRONT", cfg["name"], name, flush=True)
    contact(made, out / "candidates.png")
    json.dump([p.name for p in made], open(out / "candidates.json", "w"), indent=1)

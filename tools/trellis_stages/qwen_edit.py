# Qwen-Image-Edit-2511 on this PC, through ComfyUI (ai3d/comfyui, its run_nvidia_gpu.bat; API at 127.0.0.1:8188):
# give it one or two pictures and an instruction ("same girl, from the back, A-pose"), get a new picture back.
# The model is unsloth's Q4_K_M GGUF (fits a 12 GB card), with the 4-step Lightning LoRA, so a picture takes seconds.
#   python qwen_edit.py <out.png> "<instruction>" <image1> [image2] [--seed N] [--steps 4] [--size 1024]
# Licences: Qwen-Image-Edit-2511 and the Lightning LoRA are Apache-2.0; ComfyUI is GPL-3.0 (we only call it).
import json, shutil, sys, time, urllib.parse, urllib.request, uuid
from pathlib import Path

COMFY = Path("C:/Users/hggru/Game_dev/ai3d/comfyui/ComfyUI_windows_portable/ComfyUI")
URL = "http://127.0.0.1:8188"
args = [a for a in sys.argv[1:] if not a.startswith("--")]
opts = {sys.argv[i][2:]: sys.argv[i + 1] for i in range(1, len(sys.argv) - 1) if sys.argv[i].startswith("--")}
args = [a for a in args if a not in opts.values()]
out, instr, imgs = Path(args[0]), args[1], args[2:4]
seed, steps, size = int(opts.get("seed", 1)), int(opts.get("steps", 4)), int(opts.get("size", 1024))

names = []
for p in imgs:
    n = "qe_" + uuid.uuid4().hex[:8] + Path(p).suffix
    shutil.copy(p, COMFY / "input" / n)
    names.append(n)

g = {
    "unet": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": "qwen-image-edit-2511-Q4_K_M.gguf"}},
    "lora": {"class_type": "LoraLoaderModelOnly", "inputs": {
        "model": ["unet", 0], "lora_name": "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
        "strength_model": 1.0}},
    "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["lora", 0], "shift": 3.1}},
    "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors",
                                                    "type": "qwen_image"}},
    "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
}
for i, n in enumerate(names):
    g[f"load{i}"] = {"class_type": "LoadImage", "inputs": {"image": n}}
    g[f"img{i}"] = {"class_type": "ImageScaleToTotalPixels",
                    "inputs": {"image": [f"load{i}", 0], "upscale_method": "lanczos", "megapixels": size * size / 1e6}}
pos = {"clip": ["clip", 0], "prompt": instr, "vae": ["vae", 0]}
neg = {"clip": ["clip", 0], "prompt": "", "vae": ["vae", 0]}
for i in range(len(names)):
    pos[f"image{i + 1}"] = [f"img{i}", 0]
    neg[f"image{i + 1}"] = [f"img{i}", 0]
g["pos"] = {"class_type": "TextEncodeQwenImageEditPlus", "inputs": pos}
g["neg"] = {"class_type": "TextEncodeQwenImageEditPlus", "inputs": neg}
g["latent"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["img0", 0], "vae": ["vae", 0]}}
g["sample"] = {"class_type": "KSampler", "inputs": {
    "model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0], "latent_image": ["latent", 0],
    "seed": seed, "steps": steps, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}}
g["decode"] = {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}}
g["save"] = {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "qwen_edit"}}

t = time.time()
req = urllib.request.Request(URL + "/prompt", data=json.dumps({"prompt": g}).encode(),
                             headers={"Content-Type": "application/json"})
pid = json.loads(urllib.request.urlopen(req).read())["prompt_id"]
while True:
    h = json.loads(urllib.request.urlopen(f"{URL}/history/{pid}").read())
    if pid in h:
        st = h[pid].get("status", {})
        if st.get("status_str") == "error":
            sys.exit("QWEN failed: " + json.dumps(st.get("messages", []))[:2000])
        o = h[pid]["outputs"].get("save", {}).get("images")
        if o:
            im = o[0]
            q = urllib.parse.urlencode({"filename": im["filename"], "subfolder": im["subfolder"], "type": im["type"]})
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(urllib.request.urlopen(f"{URL}/view?{q}").read())
            print("QWEN done", out, round(time.time() - t, 1), "s")
            break
    time.sleep(1)

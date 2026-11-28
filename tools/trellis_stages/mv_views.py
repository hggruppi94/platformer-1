# Style test A: new views of a character drawn from Sofi's own picture, in her own style, with MV-Adapter
# (huanngzh/MV-Adapter, Apache-2.0, image-to-multiview on SDXL), cloned to ai3d/mvadapter.
#   <ai3d venv python> mv_views.py <Sofi's picture> <out dir> [azimuths in degrees, comma-separated] [seed]
# Only its multi-view step is used: its mesh helpers import Triton and nvdiffrast (compiled), so this loads just the
# camera code. Its full model wants about 14 GB of graphics memory; on 12 GB the pipeline is offloaded to the CPU a
# part at a time. The picture is cut out with rembg first; MV-Adapter treats it as the view at azimuth 0.
import importlib.util, sys, types
from pathlib import Path
import numpy as np
import torch
from PIL import Image

MV = Path("C:/Users/hggru/Game_dev/ai3d/mvadapter")
sys.path.insert(0, str(MV))
# a stand-in for mvadapter.utils.mesh_utils with only the camera functions (its other files need compiled kernels)
spec = importlib.util.spec_from_file_location("mvadapter.utils.mesh_utils.camera",
                                              MV / "mvadapter/utils/mesh_utils/camera.py")
cam = importlib.util.module_from_spec(spec)
stub = types.ModuleType("mvadapter.utils.mesh_utils")
stub.__path__ = []
sys.modules["mvadapter.utils.mesh_utils"] = stub
utils_stub = types.ModuleType("mvadapter.utils.mesh_utils.utils")      # camera.py only needs LIST_TYPE from it
from typing import Union                                                 # noqa: E402
utils_stub.LIST_TYPE = Union[list, np.ndarray, torch.Tensor]
sys.modules["mvadapter.utils.mesh_utils.utils"] = utils_stub
sys.modules["mvadapter.utils.mesh_utils.camera"] = cam
spec.loader.exec_module(cam)
stub.get_orthogonal_camera = cam.get_orthogonal_camera
from mvadapter.pipelines.pipeline_mvadapter_i2mv_sdxl import MVAdapterI2MVSDXLPipeline   # noqa: E402
from mvadapter.schedulers.scheduling_shift_snr import ShiftSNRScheduler                  # noqa: E402
from mvadapter.utils.geometry import get_plucker_embeds_from_cameras_ortho                # noqa: E402

src, out = Path(sys.argv[1]), Path(sys.argv[2])
az = [float(a) for a in sys.argv[3].split(",")] if len(sys.argv) > 3 else [0, 90, 180, 270]
seed = int(sys.argv[4]) if len(sys.argv) > 4 else 42
out.mkdir(parents=True, exist_ok=True)
H = W = 768

# cut out and centre, the way MV-Adapter's own script does (90% of the frame, grey background)
from rembg import remove                                                                   # noqa: E402
img = remove(Image.open(src).convert("RGB"))
a = np.array(img)
ys, xs = np.where(a[..., 3] > 0)
a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
h, w = a.shape[:2]
k = 0.9 * H / max(h, w)
a = np.array(Image.fromarray(a).resize((int(w * k), int(h * k))))
canvas = np.zeros((H, W, 4), np.uint8)
y0, x0 = (H - a.shape[0]) // 2, (W - a.shape[1]) // 2
canvas[y0:y0 + a.shape[0], x0:x0 + a.shape[1]] = a
f = canvas.astype(np.float32) / 255
ref = Image.fromarray(((f[..., :3] * f[..., 3:] + (1 - f[..., 3:]) * 0.5) * 255).astype(np.uint8))
ref.save(out / "reference.png")

pipe = MVAdapterI2MVSDXLPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16)
pipe.scheduler = ShiftSNRScheduler.from_scheduler(pipe.scheduler, shift_mode="interpolated", shift_scale=8.0)
pipe.init_custom_adapter(num_views=len(az))
pipe.load_custom_adapter("huanngzh/mv-adapter", weight_name="mvadapter_i2mv_sdxl.safetensors")
pipe.to(dtype=torch.float16)
pipe.cond_encoder.to(dtype=torch.float16)
# No CPU offloading: its hooks copy the dict MV-Adapter passes the reference picture's features through, so they get
# lost (KeyError). Everything on the GPU instead, with fewer views (front, both sides, back) to fit in 12 GB.
pipe.to("cuda")
pipe.cond_encoder.to("cuda")
pipe.enable_vae_slicing()
pipe.enable_vae_tiling()
cams = cam.get_orthogonal_camera(elevation_deg=[0] * len(az), distance=[1.8] * len(az), left=-0.55, right=0.55,
                                 bottom=-0.55, top=0.55, azimuth_deg=[x - 90 for x in az], device="cuda")
plucker = get_plucker_embeds_from_cameras_ortho(cams.c2w, [1.1] * len(az), W)
control = ((plucker + 1.0) / 2.0).clamp(0, 1)
ims = pipe("high quality 3D cartoon character, cute baby hippo girl", height=H, width=W, num_inference_steps=40,
           guidance_scale=3.0, num_images_per_prompt=len(az), control_image=control, control_conditioning_scale=1.0,
           reference_image=ref, reference_conditioning_scale=1.0,
           negative_prompt="watermark, ugly, deformed, noisy, blurry, low contrast",
           generator=torch.Generator("cuda").manual_seed(seed)).images
for x, im in zip(az, ims):
    im.save(out / f"view_{int(x):03d}.png")
strip = Image.new("RGB", (W * len(ims), H))
for i, im in enumerate(ims):
    strip.paste(im, (W * i, 0))
strip.save(out / "views.png")
print("MV done", az)

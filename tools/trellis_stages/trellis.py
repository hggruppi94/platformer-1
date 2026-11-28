# Stage b of tools/trellis_character.py, the generator: front.png -> a 3D model with its own texture (trellis.glb). Pluggable:
#   python trellis.py <front.png> <out dir> [local|local1|local1-multi|hunyuan21|pixal3d|pixal3d-multi|space|trellis2-space]
# "local" is TRELLIS.2 on this PC (C:/Users/hggru/Game_dev/ai3d/trellis_local, the TRELLIS.2-stableprojectorz build):
# its API server must be running (run-stableprojectorz.bat, http://127.0.0.1:7960). With no backend named it tries the
# local server, then the TRELLIS Space on Hugging Face, then the TRELLIS.2 Space. The Spaces use a Hugging Face login
# if the PC has one (`hf auth login`, done by Hayden; this never reads or prints the token) and wait politely when the
# free GPU time has run out (a few tries, minutes apart), rather than hammering them.
import json, shutil, sys, time
from pathlib import Path

img, out = Path(sys.argv[1]), Path(sys.argv[2])
want = sys.argv[3] if len(sys.argv) > 3 else None
out.mkdir(parents=True, exist_ok=True)
LOCAL = "http://127.0.0.1:7960"       # TRELLIS.2, ai3d/trellis_local/serve.bat
LOCAL1 = "http://127.0.0.1:7961"      # TRELLIS 1, ai3d/trellis1_local/serve.bat (fp16)
HUNYUAN = "http://127.0.0.1:7962"     # Hunyuan3D-2.1, ai3d/hunyuan21_local/hunyuan2-1-spz/serve.bat
PIXAL = Path("C:/Users/hggru/Game_dev/ai3d/pixal3d")


def post_form(url, fields, files):
    """A multipart form POST with the standard library (the system Python has no requests)."""
    import urllib.request, uuid
    bnd = uuid.uuid4().hex
    nl = chr(13) + chr(10)
    body = b"".join(f'--{bnd}{nl}Content-Disposition: form-data; name="{k}"{nl}{nl}{v}{nl}'.encode()
                    for k, v in fields.items())
    for field, path in files:
        body += (f'--{bnd}{nl}Content-Disposition: form-data; name="{field}"; filename="{Path(path).name}"{nl}'
                 f'Content-Type: image/png{nl}{nl}').encode() + Path(path).read_bytes() + nl.encode()
    body += f"--{bnd}--{nl}".encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": f"multipart/form-data; boundary={bnd}"})
    return urllib.request.urlopen(req, timeout=1800).read()


def local(base=LOCAL, name="local TRELLIS.2", multi=False):
    """TRELLIS.2 (port 7960) or TRELLIS 1 (port 7961, LOCAL1) on this PC. multi: TRELLIS 1 with front.png plus the
    side.png and back.png next to it (views stage), all three at once."""
    import urllib.request
    urllib.request.urlopen(base + "/ping", timeout=3).read()
    t = time.time()
    if base == LOCAL:
        # TRELLIS_RES (512, 1024 or 1536) and TRELLIS_TEX (texture size) trade time and memory for detail
        import os
        fields = {"seed": "2025", "resolution": os.environ.get("TRELLIS_RES", "1024"), "mesh_simplify": "60",
                  "texture_size": os.environ.get("TRELLIS_TEX", "2048")}
    else:
        fields = {"seed": "2025", "ss_sampling_steps": "25", "slat_sampling_steps": "25", "mesh_simplify_ratio": "0.9",
                  "texture_size": "2048"}
    if multi:
        views = [img] + [img.with_name(v) for v in ("side.png", "back.png") if img.with_name(v).exists()]
        post_form(base + "/generate_multi_no_preview", fields, [("file_list", v) for v in views])
    elif base == LOCAL1:
        # TRELLIS 1's single-picture route fails on an uploaded file (v40: "UploadFile has no len()"); its multi route
        # with one picture runs the single-picture pipeline
        post_form(base + "/generate_multi_no_preview", fields, [("file_list", img)])
    else:
        post_form(base + "/generate_no_preview", fields, [("file", img)])
    (out / "trellis.glb").write_bytes(urllib.request.urlopen(base + "/download/model", timeout=120).read())
    # which way the model faces as it comes back, in degrees to turn it to face the camera (-Y): measured on Nina,
    # the local TRELLIS builds face +X from one picture; TRELLIS 1 from several faces the camera already
    return {"backend": name + (" multi-view" if multi else ""), "secs": round(time.time() - t, 1),
            "yaw": 0 if multi else -90}


def hunyuan21():
    """Hunyuan3D-2.1, shape and its own texture, on this PC (ai3d/hunyuan21_local/hunyuan2-1-spz/serve.bat, port
    7962, the 8 GB settings). One picture only. Tencent's licence: free, not for use in the EU, UK or South Korea."""
    import base64, urllib.request
    urllib.request.urlopen(HUNYUAN + "/ping", timeout=3).read()
    t = time.time()
    body = json.dumps({"single_multi_img_input": [base64.b64encode(img.read_bytes()).decode()],
                       "generate_what": "make_meshes_and_tex", "apply_texture": True, "seed": 2025,
                       "octree_resolution": 256, "num_inference_steps": 30, "mesh_simplify": 60,
                       "texture_size": 2048}).encode()
    req = urllib.request.Request(HUNYUAN + "/generate", data=body, headers={"Content-Type": "application/json"})
    urllib.request.urlopen(req, timeout=3600).read()
    (out / "trellis.glb").write_bytes(urllib.request.urlopen(HUNYUAN + "/download/model", timeout=120).read())
    return {"backend": "local Hunyuan3D-2.1", "secs": round(time.time() - t, 1)}


def pixal3d(multi=False):
    """Pixal3D (TencentARC, MIT, built on TRELLIS.2) on this PC (ai3d/pixal3d, IgorAherne's Windows build), run as a
    command, not a server. multi: front.png, side.png and back.png together (inference_mv.py)."""
    import os, subprocess
    root = PIXAL
    # PIXAL3D_TRITON=off: Triton compiles a helper at run time and needs Python's header files, which the portable
    # Python this venv was made from (the TRELLIS.2 build's) doesn't have; Pixal3D then uses its non-Triton paths
    env = dict(os.environ, HF_HOME=str(root / "models"), TORCH_HOME=str(root / "models/torch"), PIXAL3D_TRITON="off")
    py = root / "venv/Scripts/python.exe"
    t = time.time()
    if multi:
        vd = out / "views_in"
        vd.mkdir(exist_ok=True)
        # Pixal3D wants each picture's camera (Blender/NeRF transforms.json, Z up): the front at (0, -d, 0), the side
        # (side_persp.png, made by side_back.py "persp") at +X, the back at +Y, all a 20 degree lens 3.119 m away
        d_ = 3.119
        poses = {"front": [[1, 0, 0, 0], [0, 0, -1, -d_], [0, 1, 0, 0], [0, 0, 0, 1]],
                 "side": [[0, 0, 1, d_], [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1]],
                 "back": [[-1, 0, 0, 0], [0, 0, 1, d_], [0, 1, 0, 0], [0, 0, 0, 1]]}
        frames = []
        for i, v in enumerate(("front", "side", "back")):
            src = img if v == "front" else img.with_name(v + "_persp.png")
            if src.exists():
                name = f"view{i:02d}_{v}.png"
                shutil.copy(src, vd / name)
                frames.append({"file_path": name, "transform_matrix": poses[v]})
        json.dump({"camera_angle_x": 0.3490658503988659, "mesh_scale": 1.0, "frames": frames},
                  open(vd / "transforms.json", "w"), indent=1)
        cmd = [py, "inference_mv.py", "--views_dir", vd, "--output", out / "trellis.glb", "--low_vram"]
    else:
        cmd = [py, "inference.py", "--image", img, "--output", out / "trellis.glb", "--low_vram"]
    subprocess.run([str(c) for c in cmd], cwd=root, env=env, check=True)
    return {"backend": "local Pixal3D" + (" multi-view" if multi else ""), "secs": round(time.time() - t, 1),
            "yaw": 180}                     # Pixal3D's models face +Y (away from the camera), measured on Nina


def space(which):
    from gradio_client import Client, handle_file
    t = time.time()
    if which == "space":
        c = Client("trellis-community/TRELLIS", verbose=False)
        c.predict(api_name="/start_session")
        pre = c.predict(image=handle_file(str(img)), api_name="/preprocess_image")
        r = c.predict(image=handle_file(pre), multiimages=[], seed=2025, ss_guidance_strength=7.5,
                      ss_sampling_steps=12, slat_guidance_strength=3.0, slat_sampling_steps=12,
                      multiimage_algo="stochastic", mesh_simplify=0.95, texture_size=1024,
                      api_name="/generate_and_extract_glb")
        src = r[1]
    else:
        c = Client("microsoft/TRELLIS.2", verbose=False)
        c.predict(api_name="/start_session")
        pre = c.predict(input=handle_file(str(img)), api_name="/preprocess_image")
        c.predict(image=handle_file(pre), seed=2025, resolution="1024", api_name="/image_to_3d")
        src = c.predict(decimation_target=60000, texture_size=2048, api_name="/extract_glb")[0]
    src = src if isinstance(src, str) else src.get("value") or src.get("path")
    shutil.copy(src, out / "trellis.glb")
    return {"backend": which, "secs": round(time.time() - t, 1)}


order = [want] if want else ["local", "space", "trellis2-space"]
for b in order:
    for attempt in range(3 if "space" in b else 1):
        try:
            if b == "local":
                info = local()
            elif b in ("local1", "local1-multi"):
                info = local(LOCAL1, "local TRELLIS 1", b == "local1-multi")
            elif b == "hunyuan21":
                info = hunyuan21()
            elif b in ("pixal3d", "pixal3d-multi"):
                info = pixal3d(b == "pixal3d-multi")
            else:
                info = space(b)
            json.dump(info, open(out / "trellis.json", "w"), indent=1)
            print("TRELLIS done", info)
            sys.exit(0)
        except Exception as e:
            msg = str(e).splitlines()[0][:200]
            print("TRELLIS", b, "failed:", msg)
            if "quota" in msg.lower() and attempt < 2:
                time.sleep(600)
                continue
            break
print("TRELLIS no backend worked")
sys.exit(1)

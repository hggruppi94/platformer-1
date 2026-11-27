# Stage b of tools/trellis_character.py: front.png -> TRELLIS -> trellis.glb, with TRELLIS's own texture.
#   python trellis.py <front.png> <out dir> [local|space|trellis2-space]
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
LOCAL = "http://127.0.0.1:7960"


def local():
    import requests
    requests.get(LOCAL + "/ping", timeout=3).raise_for_status()
    t = time.time()
    with open(img, "rb") as f:
        r = requests.post(LOCAL + "/generate_no_preview", files={"file": f}, timeout=1800,
                          data={"seed": 2025, "resolution": 1024, "mesh_simplify": 60, "texture_size": 2048})
    r.raise_for_status()
    g = requests.get(LOCAL + "/download/model", timeout=120)
    g.raise_for_status()
    (out / "trellis.glb").write_bytes(g.content)
    return {"backend": "local TRELLIS.2", "secs": round(time.time() - t, 1)}


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
    for attempt in range(1 if b == "local" else 3):
        try:
            info = local() if b == "local" else space(b)
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

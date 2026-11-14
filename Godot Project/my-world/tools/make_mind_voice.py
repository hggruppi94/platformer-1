"""Speaks every line of the voice in your mind (scripts/divine_mind.gd) into audio/mind/<key>.ogg.

Hayden, 14 Nov 2026: "can we give the brain dialogue in your mind a voice?". The voice is made with Kokoro
(https://github.com/hexgrad/kokoro, Apache 2.0, free to use in a game): no account, nothing to pay, all on this
computer. Then ffmpeg layers it so it sounds like a huge mind rather than a person.

  1. godot --headless --path "Godot Project/my-world" --script res://tools/dump_mind_lines.gd   (writes lines.txt)
  2. pip install kokoro-onnx soundfile numpy, and get kokoro-v1.0.onnx + voices-v1.0.bin from
     https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0
  3. python tools/make_mind_voice.py --model kokoro-v1.0.onnx --voices voices-v1.0.bin [--style C] [--jobs 4]

Each file is named after the line's text (the first 16 letters of its md5, as DivineMind.voice_key() does), so a
changed line gets a new file and its old one is deleted. Lines that already have a file are skipped unless --redo.
"""
import argparse, hashlib, os, re, subprocess, sys, tempfile
from concurrent.futures import ProcessPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
MIND = os.path.join(HERE, "..", "audio", "mind")

# The three voices Hayden heard as samples. Voice: one Kokoro voice, or a blend of several. Layers: (pitch, loudness)
# copies mixed under/over it. Speed < 1 is slower.
STYLES = {
    "A": {"voice": [("af_heart", 1.0)], "speed": 0.9, "layers": [], "chorus": False},
    "B": {"voice": [("bm_george", 1.0)], "speed": 0.82, "layers": [(0.5, 0.45)], "chorus": False, "lang": "en-gb"},
    "C": {"voice": [("af_heart", 0.5), ("am_onyx", 0.5)], "speed": 0.85, "layers": [(0.5, 0.35), (1.5, 0.18)],
          "chorus": True},
}
ECHO = "aecho=0.8:0.85:70|140|230:0.32|0.22|0.14"


def key(text):
    return hashlib.md5(text.strip().encode("utf-8")).hexdigest()[:16]


def spoken(text):
    # The voice can't know the name the player chose, so it leaves it out; other {tags} are said plainly
    t = text.replace(", {player},", ",").replace(", {player}", "").replace("{player}", "you")
    t = re.sub(r"\{(\w+)\}", lambda m: m.group(1).lower(), t)
    return t


_k = None


def _init(model, voices):
    global _k
    from kokoro_onnx import Kokoro
    _k = Kokoro(model, voices)


def make(job):
    text, out, style = job
    import soundfile as sf
    st = STYLES[style]
    if len(st["voice"]) == 1:
        voice = st["voice"][0][0]
    else:
        voice = sum(_k.get_voice_style(n) * w for n, w in st["voice"])
    samples, sr = _k.create(spoken(text), voice=voice, speed=st["speed"], lang=st.get("lang", "en-us"))
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "raw.wav")
        sf.write(wav, samples, sr)
        n = 1 + len(st["layers"])
        chain = "[0]asplit=%d[m]%s;" % (n, "".join("[l%d]" % i for i in range(len(st["layers"])))) if n > 1 else "[0]anull[m];"
        mix = "[m]"
        for i, (pitch, vol) in enumerate(st["layers"]):
            chain += "[l%d]rubberband=pitch=%s,volume=%s[L%d];" % (i, pitch, vol, i)
            mix += "[L%d]" % i
        fx = "amix=inputs=%d:normalize=0," % n if n > 1 else ""
        if st["chorus"]:
            fx += "chorus=0.6:0.9:50|60:0.3|0.25:0.25|0.4:2|1.5,"
        fx += ECHO + ",volume=1.1"
        graph = chain + mix + fx
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-filter_complex", graph,
                        "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--voices", required=True)
    ap.add_argument("--style", default="C", choices=sorted(STYLES))
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--redo", action="store_true")
    a = ap.parse_args()
    lines = [l.strip() for l in open(os.path.join(MIND, "lines.txt"), encoding="utf-8") if l.strip()]
    want = {key(l): l for l in lines}
    for f in os.listdir(MIND):                       # lines that aren't said any more
        if f.endswith(".ogg") and f[:-4] not in want:
            os.remove(os.path.join(MIND, f))
            if os.path.exists(os.path.join(MIND, f + ".import")):
                os.remove(os.path.join(MIND, f + ".import"))
    jobs = [(t, os.path.join(MIND, k + ".ogg"), a.style) for k, t in want.items()
            if a.redo or not os.path.exists(os.path.join(MIND, k + ".ogg"))]
    print("make_mind_voice: %d lines, %d to make (style %s)" % (len(want), len(jobs), a.style))
    with ProcessPoolExecutor(a.jobs, initializer=_init, initargs=(a.model, a.voices)) as ex:
        for i, _ in enumerate(ex.map(make, jobs), 1):
            if i % 20 == 0 or i == len(jobs):
                print("  %d/%d" % (i, len(jobs)))


if __name__ == "__main__":
    sys.exit(main())

"""
Generates the game's PLACEHOLDER audio: sound effects (audio/sfx/*.wav) and looping music
(audio/music/placeholder/*.ogg). Everything is synthesized from scratch, so it's ours to use.

    python tools/make_placeholder_audio.py          (needs numpy, and ffmpeg on PATH for the .ogg music)

Real music goes in audio/music/<area>.ogg and automatically replaces the placeholder of the same name
(see audio/music/README.md). Real sound effects can simply overwrite the .wav files here.
"""
import os
import shutil
import subprocess
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music", "placeholder")
SR = 22050
rng = np.random.default_rng(7)


# ----------------------------------------------------------------------------- building blocks
def t_(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env(n, a=0.005, d=0.1, sr=SR, curve=3.0):
    """Attack then exponential-ish decay over n samples."""
    t = np.arange(n) / sr
    e = np.minimum(1.0, t / max(a, 1e-4))
    tail = np.clip((t - a) / max(d, 1e-4), 0, None)
    return e * np.exp(-curve * tail)


def sweep(f0, f1, dur, shape="sine", sr=SR, curve=1.0):
    t = t_(dur, sr)
    k = (t / dur) ** curve
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / sr
    return wave_of(ph, shape)


def wave_of(ph, shape):
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == "square":
        return np.sign(np.sin(ph)) * 0.6
    if shape == "saw":
        return ((ph / np.pi) % 2.0) - 1.0
    raise ValueError(shape)


def tone(freq, dur, shape="sine", sr=SR, vib=0.0, vib_rate=5.0):
    t = t_(dur, sr)
    f = freq * (1 + vib * np.sin(2 * np.pi * vib_rate * t))
    return wave_of(2 * np.pi * np.cumsum(f) / sr, shape)


def noise(dur, sr=SR):
    return rng.uniform(-1, 1, int(dur * sr))


def lowpass(x, cutoff, sr=SR):
    a = np.exp(-2 * np.pi * cutoff / sr)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff, sr=SR):
    return x - lowpass(x, cutoff, sr)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*parts, gap=0.0, sr=SR):
    out = []
    for p in parts:
        out.append(p)
        out.append(np.zeros(int(gap * sr)))
    return np.concatenate(out)


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path, x, sr=SR, channels=1):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


# ----------------------------------------------------------------------------- sound effects
def sfx():
    out = {}
    # Nina
    out["jump"] = sweep(260, 720, 0.14, "tri", curve=0.6) * env(int(0.14 * SR), 0.004, 0.08)
    out["land"] = lowpass(noise(0.09), 900) * env(int(0.09 * SR), 0.002, 0.03) * 1.6
    out["step"] = lowpass(noise(0.05), 1600) * env(int(0.05 * SR), 0.001, 0.015)
    out["hurt"] = mix(sweep(480, 140, 0.28, "square"), 0.3 * sweep(500, 150, 0.28, "saw")) * env(int(0.28 * SR), 0.003, 0.18, curve=2)
    out["dash"] = highpass(noise(0.28), 500) * env(int(0.28 * SR), 0.02, 0.12, curve=2) * 0.7 + \
        0.35 * sweep(900, 300, 0.28, "sine") * env(int(0.28 * SR), 0.01, 0.15)
    out["faint"] = sweep(520, 90, 0.9, "tri", curve=0.5) * env(int(0.9 * SR), 0.01, 0.7, curve=1.5)
    # Gloops
    pop = sweep(700, 120, 0.16, "sine", curve=0.4) * env(int(0.16 * SR), 0.002, 0.1)
    squish = lowpass(noise(0.12), 2500) * env(int(0.12 * SR), 0.002, 0.05) * 0.6
    out["stomp"] = mix(pop, squish)
    giggle = []
    for k, f in enumerate([520, 610, 560, 680]):
        n = int(0.07 * SR)
        g = tone(f, 0.07, "tri", vib=0.06, vib_rate=38) * env(n, 0.005, 0.05)
        giggle.append(g * (0.9 - 0.12 * k))
    out["gloop_giggle"] = seq(*giggle, gap=0.035)
    # Items and progress
    notes = [523.25, 659.25, 783.99, 1046.5]
    out["pickup"] = seq(*[tone(f, 0.09, "tri") * env(int(0.09 * SR), 0.003, 0.07) for f in notes], gap=0.0)
    fan = [392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5]
    lvl = seq(*[mix(tone(f, 0.11, "tri"), 0.4 * tone(f * 2, 0.11)) * env(int(0.11 * SR), 0.003, 0.09) for f in fan])
    shimmer = mix(*[0.25 * tone(f, 0.8, "sine", vib=0.004) * env(int(0.8 * SR), 0.05, 0.6, curve=2) for f in [1046.5, 1318.5, 1568]])
    out["level_up"] = np.concatenate([lvl, shimmer])
    # World
    out["door"] = lowpass(noise(0.35), 700) * env(int(0.35 * SR), 0.06, 0.2, curve=2) * 1.4
    out["sliver_sealed"] = mix(tone(110, 0.5, "saw", vib=0.01), 0.5 * tone(113, 0.5, "saw")) * env(int(0.5 * SR), 0.02, 0.4) * 0.5
    out["sliver_open"] = mix(*[0.3 * tone(f, 1.0, "sine", vib=0.01, vib_rate=7) * env(int(1.0 * SR), 0.15, 0.6, curve=2)
                               for f in [880, 1108.7, 1318.5, 1760]])
    # Centipede: clicking legs and a breathy whisper
    sk = np.zeros(int(1.2 * SR))
    for k in range(60):
        at = int(rng.uniform(0, 1.15) * SR)
        c = highpass(noise(0.012), 2500) * env(int(0.012 * SR), 0.0005, 0.004) * rng.uniform(0.3, 1.0)
        sk[at:at + len(c)] += c[: len(sk) - at]
    out["centipede_skitter"] = sk
    wh = lowpass(highpass(noise(1.4), 1200), 4500)
    syll = np.abs(np.sin(2 * np.pi * 2.6 * t_(1.4))) ** 3
    out["centipede_whisper"] = wh * syll * env(len(wh), 0.2, 1.0, curve=1.2)
    # UI
    out["ui_move"] = tone(880, 0.035, "sine") * env(int(0.035 * SR), 0.001, 0.02)
    out["ui_accept"] = seq(tone(660, 0.05, "tri") * env(int(0.05 * SR), 0.002, 0.03),
                           tone(990, 0.07, "tri") * env(int(0.07 * SR), 0.002, 0.05))
    out["ui_back"] = seq(tone(660, 0.05, "tri") * env(int(0.05 * SR), 0.002, 0.03),
                         tone(440, 0.07, "tri") * env(int(0.07 * SR), 0.002, 0.05))
    peaks = {"step": 0.35, "land": 0.6, "ui_move": 0.4, "centipede_skitter": 0.55, "centipede_whisper": 0.6}
    return {k: norm(v, peaks.get(k, 0.85)) for k, v in out.items()}


# ----------------------------------------------------------------------------- music
MSR = 32000


def note_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def place(buf, start, x):
    """Adds x into buf at start, wrapping around the end so the loop stays seamless."""
    n = len(buf)
    idx = (np.arange(len(x)) + start) % n
    np.add.at(buf, idx, x)


def pad(n, dur, sr=MSR, bright=0.3):
    t = t_(dur, sr)
    f = note_hz(n)
    x = sum(np.sin(2 * np.pi * f * d * t + rng.uniform(0, 6)) for d in (1.0, 1.003, 0.997))
    x = x + bright * np.sin(2 * np.pi * f * 2.0 * t)
    a = np.minimum(1, t / (dur * 0.35))
    r = np.minimum(1, (dur - t) / (dur * 0.35))
    return x * a * r / 3


def pluck(n, dur, sr=MSR, shape="tri", decay=6.0):
    t = t_(dur, sr)
    return wave_of(2 * np.pi * note_hz(n) * t, shape) * np.exp(-decay * t) * np.minimum(1, t / 0.004)


def bell(n, dur, sr=MSR):
    t = t_(dur, sr)
    f = note_hz(n)
    return (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-6 * t)) * np.exp(-2.5 * t)


def stereo_delay(mono, sr=MSR, ms=(190, 260), fb=0.35):
    out = []
    for d in ms:
        k = int(sr * d / 1000)
        y = mono.copy()
        echo = mono.copy()
        for _ in range(4):
            echo = np.roll(echo, k) * fb
            y = y + echo
        out.append(y)
    return np.stack(out, axis=1)


def song(bpm, bars, chords, arp=None, arp_voice="tri", arp_div=8, bass=True, bells=None, drone=None, pad_gain=0.25,
         arp_gain=0.18):
    beat = 60.0 / bpm
    bar = beat * 4
    n = int(round(bar * bars * MSR))
    buf = np.zeros(n)
    for b in range(bars):
        ch = chords[b % len(chords)]
        s = int(b * bar * MSR)
        for note in ch:
            place(buf, s, pad_gain * pad(note, bar * 1.25))
        if bass:
            place(buf, s, 0.22 * pluck(ch[0] - 12, bar, shape="sine", decay=1.2))
        if arp:
            steps = arp_div
            for k in range(steps):
                pattern = arp[(b * steps + k) % len(arp)]
                if pattern is None:
                    continue
                note = ch[pattern % len(ch)] + 12 * (pattern // len(ch)) + 12
                place(buf, s + int(k * bar / steps * MSR), arp_gain * pluck(note, bar / steps * 2.5, shape=arp_voice, decay=5))
        if bells:
            for (beat_at, interval) in bells[b % len(bells)]:
                place(buf, s + int(beat_at * beat * MSR), 0.12 * bell(ch[0] + interval + 24, 2.5))
    if drone is not None:
        t = np.arange(n) / MSR
        buf += drone * (np.sin(2 * np.pi * note_hz(chords[0][0] - 24) * t) +
                        0.5 * np.sin(2 * np.pi * note_hz(chords[0][0] - 24) * 1.5 * t + np.sin(2 * np.pi * 0.07 * t)))
    st = stereo_delay(buf)
    return norm(st, 0.7)


def music():
    tracks = {}
    # Town: dreamy alien ambience. Lydian-flavoured pads with a slow twinkling arpeggio.
    tracks["town"] = song(84, 16, [[50, 57, 62, 66], [52, 59, 64, 68], [48, 55, 60, 64], [50, 57, 62, 69]],
                          arp=[0, 2, 1, 3, None, 2, 4, 1], arp_voice="sine", bells=[[(0, 7)], [], [(2, 12)], []])
    # Interiors: cosy, a gentle plucky loop.
    tracks["interior"] = song(92, 8, [[53, 57, 60, 64], [50, 53, 57, 60], [55, 59, 62, 65], [48, 52, 55, 59]],
                              arp=[0, 1, 2, 1, 3, 2, 1, 2], arp_voice="tri", pad_gain=0.18, arp_gain=0.22)
    # School: bouncy and a little odd.
    tracks["school"] = song(104, 8, [[55, 59, 62], [57, 60, 64], [53, 57, 60, 63], [55, 59, 62, 66]],
                            arp=[0, 2, 1, 2, 0, 3, 1, 2], arp_voice="tri", arp_gain=0.2, pad_gain=0.16)
    # Behind the Walls: something lives up there. Low drone, detuned music box, lots of space.
    tracks["behind_walls"] = song(60, 8, [[45, 48, 52], [46, 49, 53], [45, 48, 51], [44, 47, 51]],
                                  arp=[0, None, None, 2, None, 1, None, None, 3, None, None, None, 1, None, None, None],
                                  arp_voice="sine", arp_div=8, bass=False, pad_gain=0.12, arp_gain=0.12,
                                  bells=[[(1, 6)], [], [(3, 1)], []], drone=0.08)
    return tracks


def main():
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, x in sfx().items():
        write_wav(os.path.join(SFX_DIR, name + ".wav"), x)
        print("sfx  ", name)
    have_ffmpeg = shutil.which("ffmpeg") is not None
    for name, st in music().items():
        tmp = os.path.join(MUSIC_DIR, name + ".tmp.wav")
        inter = np.empty(st.size)
        inter[0::2] = st[:, 0]
        inter[1::2] = st[:, 1]
        write_wav(tmp, inter, MSR, channels=2)
        if have_ffmpeg:
            dst = os.path.join(MUSIC_DIR, name + ".ogg")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", dst], check=True)
            os.remove(tmp)
        else:
            os.replace(tmp, os.path.join(MUSIC_DIR, name + ".wav"))
        print("music", name, "%.1fs" % (len(st) / MSR))


if __name__ == "__main__":
    main()

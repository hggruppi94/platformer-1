"""
Makes MyWorld's music and ambience (plan prompt F3). Everything is synthesized here from scratch, so it's ours to ship:
no samples, no recordings, nothing from the show. Each piece is listed in audio/CREDITS.md.

    python tools/make_soundscape.py            (needs numpy, and ffmpeg on PATH for the .ogg files)
    python tools/make_soundscape.py town_day   (just one)

Music goes to audio/music/<name>.ogg (scripts/soundscape.gd picks the track for the area and the time of day), ambience
to audio/ambience/<name>.ogg (scripts/soundscape.gd loops it quietly under the music). Every track is a seamless loop:
it's made a little longer than the loop and the tail is folded back over the start.

Each track is a little song written as data below: a tempo, a key, a chord progression, and which instruments play.
Change a number and run it again; the same seed always makes the same track.
"""
import os
import subprocess
import sys
import wave
import zlib

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
AMB_DIR = os.path.join(ROOT, "audio", "ambience")
SR = 22050

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8,
        "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
SCALES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10],
          "lydian": [0, 2, 4, 6, 7, 9, 11], "mixolydian": [0, 2, 4, 5, 7, 9, 10], "whole": [0, 2, 4, 6, 8, 10],
          "penta": [0, 2, 4, 7, 9], "minpenta": [0, 3, 5, 7, 10]}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


# ----------------------------------------------------------------------------- sound shaping
def lowpass(x, cutoff):
    # Done in the frequency domain, so a whole track filters in a blink
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    f *= 1.0 / np.sqrt(1.0 + (freqs / cutoff) ** 4)
    return np.fft.irfft(f, len(x))


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def adsr(n, a=0.01, d=0.1, s=0.6, r=0.1):
    t = np.arange(n) / SR
    dur = n / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4) * 3.0))
    rel = np.clip((dur - t) / max(r, 1e-4), 0, 1)
    return e * rel


def osc(freq, n, shape, vib=0.0, rate=5.0, phase=0.0):
    t = np.arange(n) / SR
    f = freq * (1.0 + vib * np.sin(2 * np.pi * rate * t))
    ph = 2 * np.pi * np.cumsum(f) / SR + phase
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == "square":
        return np.tanh(np.sin(ph) * 4.0) * 0.6
    if shape == "saw":
        return (((ph / np.pi) % 2.0) - 1.0) * 0.7
    if shape == "bell":                                     # a soft FM bell, for music boxes and twinkles
        return np.sin(ph + 1.8 * np.exp(-t * 6.0) * np.sin(ph * 3.5))
    if shape == "pluck":                                    # a bright pluck that mellows
        return np.sin(ph) * 0.6 + 0.4 * np.exp(-t * 9.0) * np.sin(2 * ph) + 0.2 * np.exp(-t * 14.0) * np.sin(3 * ph)
    if shape == "organ":
        return np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(4 * ph)
    raise ValueError(shape)


INSTR = {
    # shape, attack, decay, sustain, release, volume, vibrato, lowpass cutoff
    "pad": ("saw", 0.35, 0.6, 0.8, 0.5, 0.16, 0.003, 1400),
    "warm_pad": ("tri", 0.4, 0.8, 0.85, 0.6, 0.22, 0.004, 1800),
    "bass": ("tri", 0.005, 0.15, 0.7, 0.05, 0.42, 0.0, 900),
    "synth_bass": ("square", 0.005, 0.1, 0.6, 0.04, 0.26, 0.0, 700),
    "pluck": ("pluck", 0.003, 0.25, 0.0, 0.08, 0.30, 0.0, 3500),
    "bell": ("bell", 0.002, 0.5, 0.0, 0.3, 0.22, 0.0, 5000),
    "lead": ("square", 0.01, 0.2, 0.6, 0.08, 0.15, 0.006, 2600),
    "soft_lead": ("sine", 0.02, 0.3, 0.7, 0.1, 0.25, 0.008, 4000),
    "fiddle": ("saw", 0.03, 0.2, 0.8, 0.06, 0.13, 0.012, 2400),
    "organ": ("organ", 0.02, 0.2, 0.8, 0.08, 0.10, 0.004, 2000),
    "tuba": ("tri", 0.02, 0.2, 0.7, 0.06, 0.45, 0.002, 600),
    "power": ("saw", 0.005, 0.15, 0.7, 0.05, 0.14, 0.0, 1800),
}


def note(instr, midi, dur, tail=0.0):
    shape, a, d, s, r, vol, vib, cut = INSTR[instr]
    n = int((dur + tail) * SR)
    x = osc(hz(midi), n, shape, vib) * adsr(n, a, d, s, r) * vol
    if instr == "power":                                    # a power chord: the fifth on top
        x += osc(hz(midi + 7), n, shape) * adsr(n, a, d, s, r) * vol * 0.8
    return x, cut


# ----------------------------------------------------------------------------- drums
def kick(rng):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 50 + 110 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12) * 0.8


def snare(rng):
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    return (highpass(rng.uniform(-1, 1, n), 1200) * 0.5 + np.sin(2 * np.pi * 190 * t) * 0.3) * np.exp(-t * 20) * 0.7


def hat(rng):
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    return highpass(rng.uniform(-1, 1, n), 6000) * np.exp(-t * 70) * 0.35


def shaker(rng):
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    return highpass(rng.uniform(-1, 1, n), 4000) * np.sin(np.pi * t / t[-1]) * 0.18


def clap(rng):
    n = int(0.15 * SR)
    t = np.arange(n) / SR
    burst = sum(np.exp(-np.clip(t - k * 0.012, 0, None) * 60) * (t >= k * 0.012) for k in range(3))
    return lowpass(highpass(rng.uniform(-1, 1, n), 900), 5000) * burst * 0.35


DRUMS = {"k": kick, "s": snare, "h": hat, "x": shaker, "c": clap}


# ----------------------------------------------------------------------------- songs
def chord_notes(root_pc, scale, degree, octave, size=3):
    # The chord on a scale degree (1-based), stacked in thirds from the scale
    sc = SCALES[scale]
    out = []
    for k in range(size):
        i = degree - 1 + 2 * k
        out.append(12 * (octave + 1) + root_pc + sc[i % len(sc)] + 12 * (i // len(sc)))
    return out


def song(spec):
    rng = np.random.default_rng(spec.get("seed", 1))
    bpm = spec["bpm"]
    beat = 60.0 / bpm
    bar = beat * spec.get("beats", 4)
    prog = spec["chords"]
    repeats = spec.get("repeats", 4)
    bars = len(prog) * repeats
    loop_len = bars * bar
    total = int((loop_len + 2.0) * SR)
    layers = {}

    def put(layer, x, at, cut=None):
        i = int(at * SR)
        if layer not in layers:
            layers[layer] = [np.zeros(total), cut]
        buf = layers[layer][0]
        j = min(total, i + len(x))
        buf[i:j] += x[: j - i]

    root_pc = NOTE[spec["key"]]
    scale = spec["scale"]
    sc = SCALES[scale]
    for b in range(bars):
        deg = prog[b % len(prog)]
        t0 = b * bar
        section = b // len(prog)                             # 0, 1, 2, 3: the tune comes in on the second time round
        ch = chord_notes(root_pc, scale, deg, spec.get("pad_octave", 3))
        if "pad" in spec:
            for m in ch:
                x, cut = note(spec["pad"], m, bar, 0.3)
                put("pad", x, t0, cut)
        if "bass" in spec:
            pattern = spec.get("bass_pattern", [0, None, None, None, 0, None, None, None])
            step = bar / len(pattern)
            for k, off in enumerate(pattern):
                if off is None:
                    continue
                x, cut = note(spec["bass"], ch[0] - 12 + off, step * 0.9)
                put("bass", x, t0 + k * step, cut)
        if "arp" in spec:
            pattern = spec.get("arp_pattern", [0, 1, 2, 1])
            steps = spec.get("arp_steps", 8)
            step = bar / steps
            for k in range(steps):
                if spec.get("arp_from", 0) > section:
                    break
                idx = pattern[k % len(pattern)]
                m = ch[idx % 3] + 12 * (1 + idx // 3)
                x, cut = note(spec["arp"], m, step * 0.95, 0.2)
                put("arp", x * (0.85 + 0.15 * rng.random()), t0 + k * step, cut)
        if "lead" in spec and section >= spec.get("lead_from", 1):
            steps = spec.get("lead_steps", 8)
            step = bar / steps
            k = 0
            while k < steps:
                if rng.random() < spec.get("lead_rest", 0.3):
                    k += 1
                    continue
                length = int(rng.choice([1, 1, 2, 2, 3])) if k + 1 < steps else 1
                length = min(length, steps - k)
                # Chord tones on strong beats, scale steps in between, in a comfy range
                if k % 2 == 0:
                    m = int(rng.choice(ch)) + 12
                else:
                    deg_i = int(rng.integers(0, len(sc)))
                    m = 12 * (spec.get("pad_octave", 3) + 2) + root_pc + sc[deg_i]
                x, cut = note(spec["lead"], m, step * length * 0.92, 0.15)
                put("lead", x, t0 + k * step, cut)
                k += length
        for name, pattern in spec.get("drums", {}).items():
            if spec.get("drums_from", 0) > section:
                continue
            step = bar / len(pattern)
            for k, c in enumerate(pattern):
                if c == "." or c == " ":
                    continue
                hit = DRUMS[name](rng) * (0.7 if c.islower() else 1.0)
                put("drums_" + name, hit, t0 + k * step)
    out = np.zeros(total)
    for layer, (buf, cut) in layers.items():
        out += lowpass(buf, cut) if cut else buf
    # A little room: a quiet echo a beat and a half later
    d = int(beat * 0.75 * SR)
    echo = np.zeros(total)
    echo[d:] = out[:-d] * spec.get("echo", 0.18)
    out = out + echo
    return _loop(out, loop_len)


def _loop(x, loop_len):
    # Fold the tail (notes still ringing past the end) back over the start, so it loops without a click
    n = int(loop_len * SR)
    y = x[:n].copy()
    tail = x[n:]
    k = min(len(tail), n)
    y[:k] += tail[:k]
    m = np.max(np.abs(y)) or 1.0
    return y / m * 0.7                                    # about -3 dB of headroom


SONGS = {
    # Stars Hollow by day: cosy autumn folk, plucks and a warm pad
    "earth_day": {"bpm": 96, "key": "G", "scale": "major", "chords": [1, 5, 6, 4], "seed": 11,
                  "pad": "warm_pad", "bass": "bass", "arp": "pluck", "arp_pattern": [0, 1, 2, 3, 2, 1],
                  "lead": "soft_lead", "drums": {"x": "x.x.x.x.x.x.x.x.", "k": "k.......k.......", "c": "....c.......c..."}},
    # Stars Hollow at night: Halloween-cosy, a music box over a low pad
    "earth_night": {"bpm": 78, "key": "D", "scale": "minor", "chords": [1, 6, 3, 7], "seed": 12,
                    "pad": "warm_pad", "bass": "bass", "bass_pattern": [0, None, None, None, None, None, None, None],
                    "arp": "bell", "arp_pattern": [0, 2, 1, 3], "arp_steps": 8, "lead": "bell", "lead_rest": 0.55,
                    "drums": {"x": "....x.......x..."}, "echo": 0.3},
    # Galaxity by day: dreamy and alien, wide-open (it plays a lot, so it's calm)
    "town_day": {"bpm": 100, "key": "E", "scale": "lydian", "chords": [1, 2, 1, 7], "seed": 13,
                 "pad": "pad", "bass": "bass", "arp": "bell", "arp_pattern": [0, 1, 2, 4, 2, 1], "arp_steps": 12,
                 "lead": "soft_lead", "lead_rest": 0.4, "drums": {"k": "k.......k.......", "h": "..h...h...h...h."},
                 "echo": 0.25},
    # Galaxity at night: slow and twinkly
    "town_night": {"bpm": 70, "key": "A", "scale": "dorian", "chords": [1, 4, 1, 5], "seed": 14,
                   "pad": "pad", "bass": "bass", "bass_pattern": [0, None, None, None, 7, None, None, None],
                   "arp": "bell", "arp_pattern": [0, 2, 4, 2], "arp_steps": 8, "lead": "bell", "lead_rest": 0.6,
                   "echo": 0.35},
    # The Skate Park: upbeat and punky
    "skate_park": {"bpm": 150, "key": "E", "scale": "minor", "chords": [1, 6, 3, 7], "seed": 15,
                   "pad": "power", "pad_octave": 2, "bass": "synth_bass", "bass_pattern": [0, 0, 0, 0, 0, 0, 0, 0],
                   "lead": "lead", "lead_rest": 0.25, "drums": {"k": "k...k...k...k...", "s": "....s.......s...",
                                                               "h": "h.h.h.h.h.h.h.h."}},
    # Races: fast, bright arps
    "race": {"bpm": 160, "key": "C", "scale": "major", "chords": [1, 6, 4, 5], "seed": 16,
             "pad": "pad", "bass": "synth_bass", "bass_pattern": [0, None, 0, 12, 0, None, 0, 12],
             "arp": "lead", "arp_pattern": [0, 1, 2, 3, 2, 1, 0, 2], "arp_steps": 16, "lead": "soft_lead",
             "drums": {"k": "k...k...k...k...", "s": "....s.......s..s", "h": "hhhhhhhhhhhhhhhh"}},
    # The Gloop King: a bouncy, goofy boss march
    "gloop_king": {"bpm": 132, "key": "F", "scale": "mixolydian", "chords": [1, 1, 7, 4], "seed": 17,
                   "bass": "tuba", "bass_pattern": [0, None, 7, None, 0, None, 7, 5], "pad": "organ",
                   "lead": "lead", "lead_rest": 0.2, "drums": {"k": "k...k...k...k...", "s": "..s...s...s...s.",
                                                              "c": "............c..."}},
    # The Scary World: spooky, but never scary. Whole-tone music box, slow
    "scary_world": {"bpm": 66, "key": "C", "scale": "whole", "chords": [1, 2, 1, 4], "seed": 18,
                    "pad": "warm_pad", "arp": "bell", "arp_pattern": [0, 1, 2, 1], "arp_steps": 6, "lead": "bell",
                    "lead_rest": 0.6, "echo": 0.4},
    # The Autumn Festival: a happy jig, fiddle and plucks
    "festival": {"bpm": 116, "key": "F", "scale": "major", "chords": [1, 4, 5, 1], "seed": 19,
                 "bass": "bass", "bass_pattern": [0, None, 7, None, 0, None, 7, None], "arp": "pluck",
                 "arp_pattern": [0, 1, 2, 1], "lead": "fiddle", "lead_rest": 0.15,
                 "drums": {"k": "k.......k.......", "c": "....c.......c...", "x": "xxxxxxxxxxxxxxxx"}},
    # The barn's dance class: four on the floor, an octave bass and a disco string pad
    "barn_dance": {"bpm": 120, "key": "A", "scale": "minor", "chords": [1, 7, 6, 7], "seed": 20,
                   "pad": "pad", "bass": "synth_bass", "bass_pattern": [0, 12, 0, 12, 0, 12, 0, 12],
                   "arp": "pluck", "arp_pattern": [0, 2, 1, 2], "lead": "lead", "lead_rest": 0.35,
                   "drums": {"k": "k...k...k...k...", "c": "....c.......c...", "h": "..h...h...h...h."}},
}


# ----------------------------------------------------------------------------- ambience
def ambience(name):
    rng = np.random.default_rng(zlib.crc32(name.encode()) % 1000)
    dur = 24.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    if name == "birds":
        out += lowpass(rng.uniform(-1, 1, n), 400) * 0.05                       # a soft breeze under them
        for _ in range(26):
            at = int(rng.uniform(0, dur - 1) * SR)
            f0 = rng.uniform(2200, 4200)
            for k in range(int(rng.integers(2, 5))):
                m = int(0.09 * SR)
                tt = np.arange(m) / SR
                f = f0 * (1 + 0.25 * np.sin(np.pi * tt / tt[-1])) * (1 + 0.06 * k)
                chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / tt[-1]) ** 2 * 0.18
                i = at + k * int(0.12 * SR)
                out[i:i + m] += chirp[: max(0, min(m, n - i))]
    elif name == "wind":
        w = lowpass(rng.uniform(-1, 1, n), 600)
        out += w * (0.6 + 0.4 * np.sin(2 * np.pi * t / dur * 2 + 1.0)) * 0.9
    elif name == "water":
        out += lowpass(highpass(rng.uniform(-1, 1, n), 300), 1800) * 0.25
        for _ in range(90):                                                     # little bubbles and laps
            at = int(rng.uniform(0, dur - 0.2) * SR)
            m = int(0.06 * SR)
            tt = np.arange(m) / SR
            f = rng.uniform(500, 1400) * (1 + tt * 8)
            out[at:at + m] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 50) * 0.12
    elif name == "mothership_hum":
        for f, v in [(55, 0.5), (55.4, 0.4), (110.3, 0.2), (165, 0.08)]:
            out += np.sin(2 * np.pi * f * t) * v
        out += lowpass(rng.uniform(-1, 1, n), 200) * 0.2
    elif name == "alien_chirps":
        out += lowpass(rng.uniform(-1, 1, n), 300) * 0.03
        for _ in range(30):
            at = int(rng.uniform(0, dur - 0.5) * SR)
            m = int(rng.uniform(0.08, 0.2) * SR)
            tt = np.arange(m) / SR
            f = rng.uniform(600, 1600) * (1 + rng.uniform(-0.5, 0.8) * tt / tt[-1])
            blip = osc(1.0, m, "sine")
            blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / tt[-1]) * 0.16
            out[at:at + m] += blip
    elif name == "market":
        murmur = lowpass(highpass(rng.uniform(-1, 1, n), 200), 900)
        murmur *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * t * 0.7)) * np.abs(np.sin(2 * np.pi * t * 0.23))
        out += murmur * 0.4
        for _ in range(14):                                                     # cups, coins, a little bell
            at = int(rng.uniform(0, dur - 0.5) * SR)
            m = int(0.3 * SR)
            out[at:at + m] += osc(rng.uniform(1500, 3000), m, "bell") * np.exp(-np.arange(m) / SR * 12) * 0.1
    else:
        raise ValueError(name)
    # Loop it: crossfade the last second into the first
    f = int(1.0 * SR)
    ramp = np.linspace(0, 1, f)
    out[:f] = out[:f] * ramp + out[-f:] * (1 - ramp)
    out = out[:-f]
    m = np.max(np.abs(out)) or 1.0
    return out / m * 0.6


AMBIENCE = ["birds", "wind", "water", "mothership_hum", "alien_chirps", "market"]


# ----------------------------------------------------------------------------- writing
def write_ogg(path, x):
    tmp = path + ".tmp.wav"
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "2", path], check=True)
    os.remove(tmp)


def main():
    only = sys.argv[1:]
    os.makedirs(MUSIC_DIR, exist_ok=True)
    os.makedirs(AMB_DIR, exist_ok=True)
    for name, spec in SONGS.items():
        if only and name not in only:
            continue
        x = song(spec)
        write_ogg(os.path.join(MUSIC_DIR, name + ".ogg"), x)
        print("music %-12s %5.1f s" % (name, len(x) / SR))
    for name in AMBIENCE:
        if only and name not in only:
            continue
        x = ambience(name)
        write_ogg(os.path.join(AMB_DIR, name + ".ogg"), x)
        print("ambience %-14s %5.1f s" % (name, len(x) / SR))


if __name__ == "__main__":
    main()

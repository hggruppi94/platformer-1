# Generates Rook's placeholder bark: one short "woof" (a kid doing a dog voice), audio/sfx/bark.wav.
# Plain Python, no numpy; rook.gd plays it twice per bark.
#
#   python tools/make_bark.py        (from the Godot project folder)

import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx", "bark.wav")


def woof():
    rnd = random.Random(7)
    n = int(0.2 * SR)
    out, ph, lp = [], 0.0, 0.0
    for i in range(n):
        t = i / n
        f = 520 - 260 * t ** 0.7 + 40 * math.sin(2 * math.pi * 3 * t)   # "wuh" drops in pitch
        ph += f / SR
        voice = 2 * (ph % 1) - 1                                            # buzzy saw for the voice
        voice = voice * 0.7 + 0.3 * math.sin(2 * math.pi * ph * 2)
        breath = rnd.uniform(-1, 1) * (0.5 if t < 0.12 else 0.12)           # breathy "w" at the start
        x = voice + breath
        cut = 0.10 + 0.25 * math.exp(-t * 6)                                # opens on "w", closes to "f"
        lp += cut * (x - lp)
        amp = min(1.0, t / 0.03) * math.exp(-max(0.0, t - 0.08) * 14)
        out.append(lp * amp)
    peak = max(abs(v) for v in out)
    return [v / peak * 0.85 for v in out]


def main():
    x = woof()
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in x))
    print("WROTE", os.path.normpath(OUT))


if __name__ == "__main__":
    main()

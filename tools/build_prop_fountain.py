# The Void's fountains and lamp posts, built the detailed way (tools/bake_kit.py; 16 Nov 2026, Hayden: "give
# everything the baked in details"). Each HIGH version is baked onto a LOW one, which is what the game draws.
#
#   fountain    the Market Square's and Island Park's fountain: a carved basin of lilac stone with a rolled lip and
#               a gold band, glowing crystals on the rim, and in the middle a fluted column with a scalloped bowl
#               halfway up and a cup of stone petals at the top that holds the glowing water ball. Sizes match the
#               builder's (tools/build_town.gd: a basin 2.8 m round and 0.8 m high, its column, the ball 0.7 m round
#               2.9 m up), so the old collision, water and water ball (and the lost watch on it) are untouched.
#   void_lamp   a lamp post of dark lilac iron and brass: a fluted post on an eight-sided foot, little curls under
#               a cage of ribs round the glowing bulb, and a crown with a crystal. Made for a bulb 3.5 m up and
#               0.3 m round; the game scales it to each kind of lamp (the Market's, the castle path's, the
#               boardwalks'). The bulb itself stays the builder's, so it still lights up at night (day_night.gd).
#
# Colours are the builder's after the alien tint (sRGB, as they are in town.tscn). Origins are on the ground.
#
#   python tools/build_prop_fountain.py "<out>.glb" <fountain|void_lamp> [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402

KINDS = ["fountain", "void_lamp"]
KIND = next((a for a in sys.argv if a in KINDS), "fountain")
NAME = {"fountain": "void_fountain", "void_lamp": "void_lamp"}[KIND]
OUT = K.out_path(NAME + ".glb")
random.seed(KINDS.index(KIND) * 13 + 7)

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

STONE = (0.56, 0.49, 0.645)       # "Fountain Stone" in the Void, after the alien tint
GOLD = (0.86, 0.7, 0.36)
CRYSTAL = (0.45, 0.95, 0.9)


def crystal(name, at, h, r, tilt, m, col, high):
    """A six-sided crystal with a pointed top, leaning out."""
    seg = 6
    ob = K.lathe(name, [(0.0, 0.0), (r, 0.0), (r, h * 0.72), (0.0, h)], seg=seg, m=m, smooth=False, col=col)
    ob.location = at
    ob.rotation_euler = tilt
    return ob


def fountain():
    stone = K.mat("Fountain Stone", STONE, rough=0.7, pits=0.35, bump=0.3)
    carved = K.mat("Fountain Carving", tuple(c * 0.86 for c in STONE), rough=0.75, pits=0.3, bump=0.25)
    gold = K.mat("Fountain Gold", GOLD, rough=0.3, metal=1.0, pits=0.1)
    glow = K.mat("Fountain Crystal", CRYSTAL, rough=0.15, emit=2.0, emit_rgb=CRYSTAL)

    def build(col, high):
        obs = []
        seg = 96 if high else 32
        # the basin: a plinth step, the wall, a rolled lip, and its inside down to the floor under the water
        basin = [(0.0, 0.0), (2.98, 0.0), (2.98, 0.1), (2.84, 0.12), (2.8, 0.16), (2.78, 0.62), (2.84, 0.66),
                 (2.94, 0.72), (2.95, 0.8), (2.88, 0.86), (2.62, 0.88), (2.4, 0.84), (2.34, 0.78), (2.32, 0.55),
                 (0.0, 0.55)]
        obs.append(K.lathe("Basin", basin, seg=seg, m=stone, col=col, flutes=24 if high else 0, flute_depth=0.035,
                           flute_z=(0.2, 0.58)))
        # a gold band under the lip
        obs.append(K.lathe("Band", [(2.8, 0.6), (2.835, 0.61), (2.835, 0.65), (2.8, 0.66)], seg=seg, m=gold,
                           col=col))
        # carved panels: a raised medallion between each pair of flutes, every third one with a gold star
        if high:
            for k in range(8):
                a = k / 8 * math.tau + math.pi / 8
                x, y = math.cos(a) * 2.79, math.sin(a) * 2.79
                med = K.cyl("Medallion", 0.13, 0.04, at=(x, y, 0.4), seg=24, m=carved, col=col,
                            rot=(0, math.pi / 2, a))
                obs.append(med)
                obs.append(K.cyl("Medallion Gold", 0.07, 0.05, at=(math.cos(a) * 2.8, math.sin(a) * 2.8, 0.4), seg=5,
                                 m=gold, col=col, rot=(0, math.pi / 2, a), smooth=False))
        # glowing crystal clusters on the lip, four round it (off the ways in)
        for k in range(4):
            a = k / 4 * math.tau + math.pi / 4
            cx, cy = math.cos(a) * 2.62, math.sin(a) * 2.62
            n = 3 if high else 2
            for j in range(n):
                off = (j - (n - 1) / 2) * 0.09
                bx = cx + math.cos(a + math.pi / 2) * off
                by = cy + math.sin(a + math.pi / 2) * off
                h = 0.32 - abs(off) * 1.3 + (random.uniform(-0.03, 0.03) if high else 0)
                obs.append(crystal("Crystal", (bx, by, 0.84), h, 0.045, (math.cos(a + math.pi / 2) * 0.25 * (j - 1),
                                                                         math.sin(a + math.pi / 2) * 0.25 * (j - 1), a),
                                   glow, col, high))
        # the middle: a foot in the water, a fluted column, the scalloped bowl, a thinner neck, and the petal cup
        cseg = 48 if high else 16
        obs.append(K.lathe("Column", [(0.0, 0.5), (0.62, 0.5), (0.62, 0.62), (0.5, 0.7), (0.42, 0.78), (0.36, 0.84),
                                      (0.3, 1.25), (0.36, 1.3), (0.34, 1.35)], seg=cseg, m=stone, col=col,
                           flutes=12 if high else 0, flute_depth=0.04, flute_z=(0.88, 1.22)))
        bowl = [(0.34, 1.33), (0.55, 1.36), (0.95, 1.46), (1.15, 1.58), (1.18, 1.66), (1.1, 1.66), (0.9, 1.58),
                (0.5, 1.52), (0.0, 1.52)]
        obs.append(K.lathe("Bowl", bowl, seg=cseg, m=stone, col=col, flutes=12 if high else 0, flute_depth=0.09,
                           flute_z=(1.4, 1.67)))
        obs.append(K.lathe("Bowl Rim", [(1.16, 1.6), (1.19, 1.61), (1.19, 1.64), (1.16, 1.65)], seg=cseg, m=gold,
                           col=col))
        obs.append(K.lathe("Neck", [(0.0, 1.5), (0.26, 1.5), (0.22, 1.62), (0.18, 1.75), (0.2, 1.8), (0.16, 1.85),
                                    (0.15, 2.05), (0.2, 2.1), (0.0, 2.12)], seg=cseg, m=stone, col=col,
                           flutes=8 if high else 0, flute_depth=0.025, flute_z=(1.87, 2.03)))
        obs.append(K.lathe("Neck Ring", [(0.17, 1.95), (0.205, 1.96), (0.205, 1.99), (0.17, 2.0)], seg=cseg, m=gold,
                           col=col))
        # six petals curling up round the water ball (its middle 2.9 up, 0.7 round)
        pseg = 10 if high else 4
        for k in range(6):
            a = k / 6 * math.tau
            pts = []
            for i in range(pseg + 1):
                t = i / pseg
                ang = -0.9 * math.pi / 2 + t * 0.95 * math.pi / 2       # from under the ball, round its side
                rr = 0.78 * math.cos(ang) * (0.35 + 0.65 * t)
                zz = 2.9 + 0.78 * math.sin(ang)
                rr = max(rr, 0.12 + 0.6 * t)
                pts.append((math.cos(a) * rr, math.sin(a) * rr, zz))
            obs.append(K.wire("Petal", pts, 0.06 if high else 0.06, stone, res=8 if high else 2,
                              bevel_res=3 if high else 1, col=col))
            if high:
                tip = pts[-1]
                obs.append(K.sphere("Petal Tip", 0.035, at=tip, m=gold, seg=12, col=col))
        return obs

    return build(HIGH, True), build(LOW, False), True


def void_lamp():
    iron = K.mat("Lamp Iron", (0.32, 0.27, 0.36), rough=0.45, metal=0.7, pits=0.25, bump=0.08)
    brass = K.mat("Lamp Brass", GOLD, rough=0.3, metal=1.0, pits=0.1)
    glow = K.mat("Lamp Crystal", CRYSTAL, rough=0.15, emit=2.0, emit_rgb=CRYSTAL)

    def build(col, high):
        obs = []
        seg = 32 if high else 8
        # the foot: eight-sided, stepped
        obs.append(K.lathe("Foot", [(0.0, 0.0), (0.24, 0.0), (0.24, 0.08), (0.2, 0.1), (0.2, 0.22), (0.15, 0.27),
                                    (0.12, 0.3), (0.0, 0.3)], seg=8, sides=8, m=iron, smooth=False, col=col))
        # the post, fluted, with brass collars
        obs.append(K.lathe("Post", [(0.0, 0.3), (0.095, 0.3), (0.09, 0.4), (0.075, 0.46), (0.07, 2.7), (0.08, 2.75),
                                    (0.0, 2.76)], seg=seg, m=iron, col=col, flutes=8 if high else 0, flute_depth=0.012,
                           flute_z=(0.5, 2.6)))
        for z in (0.42, 2.66):
            obs.append(K.lathe("Collar", [(0.0, z), (0.1, z), (0.1, z + 0.05), (0.0, z + 0.05)], seg=seg, m=brass,
                               col=col))
        # the neck up to the cage, and curls under it
        obs.append(K.lathe("Neck", [(0.0, 2.75), (0.06, 2.75), (0.05, 2.9), (0.09, 3.05), (0.14, 3.12), (0.0, 3.13)],
                           seg=seg, m=iron, col=col))
        if high:
            for k in range(4):
                a = k / 4 * math.tau
                ca, sa = math.cos(a), math.sin(a)
                pts = [(ca * 0.05 * f, sa * 0.05 * f, 2.62) for f in (1.0,)]
                curl = [(ca * (0.06 + 0.2 * t), sa * (0.06 + 0.2 * t), 2.62 + 0.42 * t * t) for t in
                        [i / 6 for i in range(7)]]
                obs.append(K.wire("Arm", pts + curl[1:], 0.013, iron, res=10, bevel_res=2, col=col))
                # a little curl at the end
                sc = K.scroll(0.0, 3.0, 0.05, 1.3, y=0.0, steps=16)
                sc = [(ca * (0.24 + p[0]) - sa * p[1], sa * (0.24 + p[0]) + ca * p[1], p[2]) for p in sc]
                obs.append(K.wire("Curl", sc, 0.01, iron, res=8, bevel_res=2, col=col))
        # the cage: four ribs round the bulb (0.3 round, 3.5 up), clear of it
        n = 4
        for k in range(n):
            a = k / n * math.tau + math.pi / 4
            ca, sa = math.cos(a), math.sin(a)
            pts = []
            steps = 10 if high else 4
            for i in range(steps + 1):
                t = i / steps
                ang = -math.pi / 2 + t * math.pi
                r = 0.13 + 0.27 * math.cos(ang)
                pts.append((ca * r, sa * r, 3.5 + 0.44 * math.sin(ang)))
            obs.append(K.wire("Rib", pts, 0.016, brass, res=8 if high else 2, bevel_res=2 if high else 1, col=col))
        obs.append(K.lathe("Cup", [(0.0, 3.08), (0.16, 3.08), (0.2, 3.12), (0.17, 3.14), (0.0, 3.14)], seg=seg,
                           m=brass, col=col))
        # the crown: a ring over the ribs, a little roof and a crystal on top
        obs.append(K.lathe("Crown", [(0.0, 3.92), (0.17, 3.92), (0.19, 3.96), (0.12, 4.02), (0.05, 4.1),
                                     (0.0, 4.12)], seg=seg, m=iron, col=col))
        if high:
            for k in range(8):
                a = k / 8 * math.tau
                obs.append(K.sphere("Crown Bead", 0.02, at=(math.cos(a) * 0.17, math.sin(a) * 0.17, 3.955), m=brass,
                                    seg=10, col=col))
        obs.append(crystal("Crystal", (0, 0, 4.08), 0.24, 0.04, (0, 0, 0), glow, col, high))
        return obs

    return build(HIGH, True), build(LOW, False), True


fn, size = {"fountain": (fountain, 2048), "void_lamp": (void_lamp, 512)}[KIND]
high, low, emit = fn()
hi_tris = K.tri_count(high)
prop = K.join(NAME, low)
lo_tris = K.tri_count([prop])
K.uv_unwrap(prop, margin=0.006)
maps = K.bake(prop, high, size=size, name=NAME, extrusion=0.04, ray=0.1,
              maps=["normal", "ao", "color", "rough", "metal"] + (["emit"] if emit else []))
K.finish(prop, maps, size, NAME, emit_strength=2.0 if emit else 1.0)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([prop], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

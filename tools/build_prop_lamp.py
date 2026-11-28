# Stars Hollow's street lamp, built the detailed way (tools/bake_kit.py): a cast-iron Victorian post with a fluted
# column, an octagonal base with mouldings, brass collars, a lamplighter's ladder bar, curly scroll brackets and a
# four-sided lantern with glowing panes, a flared roof and a finial. The HIGH version has about 60,000 triangles and
# pitted iron; it's baked onto a LOW version of under 2,000, which is what the game draws (one mesh, one material,
# shared by every lamp in town). Same size and spot as the old pole-and-box lamp (tools/build_earth.gd _lamp_post),
# so its light (3.5 m up) still sits in the lantern.
#
#   python tools/build_prop_lamp.py "Godot Project/my-world/models/props/stars_hollow/street_lamp.glb" [--blend]
#   (or: blender -b --python tools/build_prop_lamp.py -- <out.glb>)
#
# Blender is Z up (the exporter turns it to Godot's Y up). Base at the origin.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402

OUT = K.out_path("street_lamp.glb")
K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

IRON = K.mat("Cast Iron", (0.045, 0.06, 0.055), rough=0.55, metal=0.55, pits=0.18, wear=0.12, bump=0.25)
BRASS = K.mat("Brass", (0.72, 0.52, 0.22), rough=0.32, metal=1.0, pits=0.08, wear=0.15)
GLASS = K.mat("Lamp Glass", (1.0, 0.86, 0.56), rough=0.2, emit=1.0)

# Profiles shared by both versions: (radius, height)
BASE = [(0.0, 0.0), (0.25, 0.0), (0.25, 0.07), (0.225, 0.09), (0.215, 0.15), (0.19, 0.17), (0.17, 0.24),
        (0.15, 0.33), (0.14, 0.42), (0.15, 0.45), (0.15, 0.5), (0.0, 0.5)]
BULB = [(0.0, 0.5), (0.12, 0.5), (0.14, 0.56), (0.15, 0.64), (0.135, 0.74), (0.105, 0.83), (0.085, 0.9),
        (0.095, 0.93), (0.095, 0.96), (0.0, 0.96)]
COL_Z = (0.96, 3.0)
SEAT = [(0.0, 3.28), (0.06, 3.28), (0.09, 3.31), (0.15, 3.36), (0.17, 3.4), (0.17, 3.43), (0.0, 3.43)]
ROOF = [(0.0, 3.86), (0.26, 3.86), (0.25, 3.9), (0.2, 3.94), (0.12, 4.0), (0.07, 4.06), (0.05, 4.1), (0.0, 4.1)]
FINIAL = [(0.0, 4.1), (0.045, 4.1), (0.05, 4.13), (0.03, 4.16), (0.04, 4.2), (0.012, 4.27), (0.0, 4.3)]
LANT_LO, LANT_HI = 3.43, 3.86
W_LO, W_HI = 0.12, 0.175        # the lantern's half width at its bottom and top


def scrolls(col, r, res, bevel_res):
    obs = []
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        pts = [(0.07, 0, 3.02), (0.14, 0, 3.08), (0.2, 0, 3.17), (0.2, 0, 3.24), (0.15, 0, 3.27), (0.12, 0, 3.22),
               (0.14, 0, 3.18)]
        rot = [(math.cos(a) * x - math.sin(a) * y, math.sin(a) * x + math.cos(a) * y, z) for (x, y, z) in pts]
        obs.append(K.wire("Scroll %d" % k, rot, r, IRON, res=res, bevel_res=bevel_res, col=col))
    return obs


def ladder_bar(col, seg, high):
    obs = [K.cyl("Ladder Bar", 0.016, 0.62, at=(0, 0, 2.86), seg=seg, m=IRON, rot=(0, math.pi / 2, 0), col=col)]
    for sx in (-1, 1):
        obs.append(K.sphere("Bar End", 0.03, at=(sx * 0.31, 0, 2.86), m=BRASS, seg=seg, col=col))
        if high:
            obs.append(K.wire("Bar Brace", [(sx * 0.27, 0, 2.86), (sx * 0.17, 0, 2.8), (sx * 0.07, 0, 2.74)],
                              0.009, IRON, col=col))
    return obs


def lantern_frame(col, high):
    obs = []
    seg = 12 if high else 4
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        c, s = math.cos(a) * math.sqrt(2), math.sin(a) * math.sqrt(2)
        lo = (c * W_LO, s * W_LO, LANT_LO)
        hi = (c * W_HI, s * W_HI, LANT_HI)
        if high:
            obs.append(K.wire("Post %d" % k, [lo, ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2), hi],
                              0.014, IRON, res=4, bevel_res=3, col=col))
            obs.append(K.sphere("Post Knob", 0.022, at=hi, m=BRASS, seg=10, col=col))
    # top and bottom rims of the lantern (square rings), and the glass
    obs.append(K.lathe("Lantern Rim Lo", [(0.0, LANT_LO - 0.01), (W_LO * 1.5, LANT_LO - 0.01), (W_LO * 1.5, LANT_LO + 0.02),
                                          (0.0, LANT_LO + 0.02)], 4, IRON, smooth=False, col=col))
    obs.append(K.lathe("Lantern Rim Hi", [(0.0, LANT_HI - 0.02), (W_HI * 1.48, LANT_HI - 0.02), (W_HI * 1.48, LANT_HI + 0.01),
                                          (0.0, LANT_HI + 0.01)], 4, IRON, smooth=False, col=col))
    glass = K.lathe("Glass", [(0.0, LANT_LO), (W_LO * 1.36, LANT_LO), (W_HI * 1.36, LANT_HI), (0.0, LANT_HI)], 4, GLASS,
                    smooth=False, col=col)
    obs.append(glass)
    if high:
        # thin glazing bars across each pane, and a little brass burner inside
        for k in range(4):
            a = k * math.pi / 2
            for t in (0.45,):
                z = LANT_LO + (LANT_HI - LANT_LO) * t
                w = (W_LO + (W_HI - W_LO) * t) * 1.37
                obs.append(K.wire("Glazing", [(math.cos(a) * w - math.sin(a) * -w, math.sin(a) * w + math.cos(a) * -w, z),
                                              (math.cos(a) * w, math.sin(a) * w, z),
                                              (math.cos(a) * w - math.sin(a) * w, math.sin(a) * w + math.cos(a) * w, z)],
                                  0.006, IRON, res=2, bevel_res=2, col=col))
    for o in obs:
        o.rotation_euler[2] += math.pi / 4 if o.name.startswith(("Lantern Rim", "Glass")) else 0.0
    return obs


# ---------------------------------------------------------------- HIGH: as detailed as we like
high = []
high.append(K.lathe("Base", BASE, 8, IRON, sides=8, smooth=False, col=HIGH))
# raised panels on each face of the base
for k in range(8):
    a = k * math.tau / 8 + math.tau / 16
    p = K.box("Base Panel", (0.012, 0.11, 0.07), at=(math.cos(a) * 0.219, math.sin(a) * 0.219, 0.115), m=IRON,
              bevel=0.004, rot=(0, 0, a), col=HIGH)
    high.append(p)
high.append(K.lathe("Bulb", BULB, 96, IRON, flutes=16, flute_depth=0.012, flute_z=(0.56, 0.8), col=HIGH))
col_prof = [(0.0, COL_Z[0]), (0.072, COL_Z[0]), (0.066, 1.6), (0.06, 2.4), (0.056, COL_Z[1]), (0.0, COL_Z[1])]
# many rings up the column, so the flutes stay round
fine = []
for (r, z) in col_prof[1:-1]:
    fine.append((r, z))
dense = [(0.0, COL_Z[0])]
steps = 60
for i in range(steps + 1):
    t = i / steps
    z = COL_Z[0] + (COL_Z[1] - COL_Z[0]) * t
    r = 0.072 + (0.056 - 0.072) * t
    dense.append((r, z))
dense.append((0.0, COL_Z[1]))
high.append(K.lathe("Column", dense, 120, IRON, flutes=12, flute_depth=0.009, flute_z=(1.02, 2.94), col=HIGH))
for z, r in [(0.98, 0.085), (2.0, 0.07), (2.98, 0.075)]:
    high.append(K.lathe("Collar", [(0.0, z - 0.025), (r - 0.008, z - 0.025), (r, z - 0.012), (r, z + 0.012),
                                   (r - 0.008, z + 0.025), (0.0, z + 0.025)], 48, BRASS, col=HIGH))
high.append(K.lathe("Neck", [(0.0, 3.0), (0.05, 3.0), (0.045, 3.15), (0.055, 3.22), (0.06, 3.28), (0.0, 3.28)], 48, IRON,
                    col=HIGH))
high.append(K.lathe("Seat", SEAT, 48, IRON, col=HIGH))
high += ladder_bar(HIGH, 24, True)
high += scrolls(HIGH, 0.011, 24, 4)
high += lantern_frame(HIGH, True)
high.append(K.lathe("Burner", [(0.0, 3.43), (0.03, 3.43), (0.035, 3.5), (0.02, 3.56), (0.0, 3.58)], 24, BRASS, col=HIGH))
roof = K.lathe("Roof", ROOF, 4, IRON, smooth=False, col=HIGH)
roof.rotation_euler[2] = math.pi / 4
high.append(roof)
# little ribs down the roof's corners and a row of drip beads round its eave
for k in range(4):
    a = k * math.pi / 2
    high.append(K.wire("Roof Rib", [(math.cos(a) * 0.255, math.sin(a) * 0.255, 3.885), (math.cos(a) * 0.17, math.sin(a) * 0.17, 3.96),
                                    (math.cos(a) * 0.06, math.sin(a) * 0.06, 4.07)], 0.009, BRASS, res=6, col=HIGH))
for k in range(24):
    a = k * math.tau / 24
    half = math.pi / 4
    ang = (a + half) % (2 * half) - half
    rr = 0.262 * math.cos(half) / math.cos(ang)
    high.append(K.sphere("Bead", 0.009, at=(math.cos(a + math.pi / 4) * rr, math.sin(a + math.pi / 4) * rr, 3.852), m=BRASS,
                         seg=8, col=HIGH))
high.append(K.lathe("Finial", FINIAL, 32, BRASS, col=HIGH))

# ---------------------------------------------------------------- LOW: what the game draws
low = []
low.append(K.lathe("Base", BASE, 8, IRON, sides=8, smooth=False, col=LOW))
low.append(K.lathe("Bulb", BULB, 12, IRON, col=LOW))
low.append(K.lathe("Column", [(0.0, COL_Z[0]), (0.072, COL_Z[0]), (0.056, COL_Z[1]), (0.0, COL_Z[1])], 12, IRON, col=LOW))
for z, r in [(0.98, 0.085), (2.0, 0.07), (2.98, 0.075)]:
    low.append(K.lathe("Collar", [(0.0, z - 0.025), (r, z - 0.012), (r, z + 0.012), (0.0, z + 0.025)], 12, BRASS, col=LOW))
low.append(K.lathe("Neck", [(0.0, 3.0), (0.05, 3.0), (0.045, 3.15), (0.06, 3.28), (0.0, 3.28)], 10, IRON, col=LOW))
low.append(K.lathe("Seat", SEAT, 12, IRON, col=LOW))
low += ladder_bar(LOW, 8, False)
low += scrolls(LOW, 0.013, 6, 1)
low += lantern_frame(LOW, False)
roof_lo = K.lathe("Roof", ROOF, 4, IRON, smooth=False, col=LOW)
roof_lo.rotation_euler[2] = math.pi / 4
low.append(roof_lo)
low.append(K.lathe("Finial", FINIAL, 8, BRASS, col=LOW))

hi_tris = K.tri_count(high)
lamp = K.join("StreetLamp", low)
lo_tris = K.tri_count([lamp])
K.uv_unwrap(lamp, margin=0.006)
maps = K.bake(lamp, high, size=1024, name="street_lamp", extrusion=0.012, ray=0.04)
K.finish(lamp, maps, 1024, "street_lamp", emit_strength=1.3)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([lamp], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

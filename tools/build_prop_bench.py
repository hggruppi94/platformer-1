# Stars Hollow's park bench, built the detailed way (tools/bake_kit.py): cast-iron ends with curling scrolls and
# armrests, seven wooden slats with real wood grain, rounded edges and bolt heads. The HIGH version is baked onto a
# LOW one of about 1,500 triangles, which is what the game draws. Same size as the old box bench
# (tools/build_earth.gd _bench: 1.8 m long, seat 0.45 m up, back 0.24 m behind), and the seat faces Godot's +Z, which
# is Blender's -Y. The bench's collision stays the builder's.
#
#   python tools/build_prop_bench.py "Godot Project/my-world/models/props/park_bench.glb" [--blend] [--preview]

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402

OUT = K.out_path("park_bench.glb")
K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

IRON = K.mat("Bench Iron", (0.05, 0.07, 0.06), rough=0.5, metal=0.5, pits=0.2, wear=0.15, bump=0.2)
WOOD = K.mat("Bench Wood", (0.5, 0.33, 0.2), rough=0.7, grain=(9.0, 0.35), wear=0.08, bump=0.1)
BOLT = K.mat("Bolt", (0.35, 0.33, 0.3), rough=0.4, metal=1.0)

L = 1.84                           # slat length
ENDS = (-0.78, 0.0, 0.78)          # the iron frames along the bench (the middle one holds the slats up)
SEAT_Y = [-0.2, -0.13, -0.06, 0.01, 0.08]     # slat centres front to back (Blender y: -y is the front)
BACK = [(0.27, 0.6), (0.29, 0.71), (0.31, 0.82)]   # back slats (y, z)


def frame_curves(x, r, res, bevel_res, col, arm=True):
    obs = []
    # front leg sweeps out at the foot, up to the seat's front
    obs.append(K.wire("Front Leg", [(x, -0.26, 0.0), (x, -0.22, 0.05), (x, -0.2, 0.2), (x, -0.22, 0.34), (x, -0.25, 0.42)],
                      r, IRON, res=res, bevel_res=bevel_res, col=col))
    # seat rail front to back
    obs.append(K.wire("Seat Rail", [(x, -0.25, 0.42), (x, -0.05, 0.405), (x, 0.17, 0.41), (x, 0.24, 0.43)],
                      r, IRON, res=res, bevel_res=bevel_res, col=col))
    # back leg up into the backrest
    obs.append(K.wire("Back Leg", [(x, 0.28, 0.0), (x, 0.24, 0.12), (x, 0.22, 0.3), (x, 0.25, 0.48), (x, 0.3, 0.7),
                                   (x, 0.33, 0.88), (x, 0.31, 0.93)], r, IRON, res=res, bevel_res=bevel_res, col=col))
    if arm:
        # the armrest: from the back, forward, curling down into a scroll over the front leg
        pts = [(x, 0.27, 0.62), (x, 0.1, 0.64), (x, -0.12, 0.63), (x, -0.25, 0.6)]
        pts += [(x, py, pz) for (_, py, pz) in K.scroll(-0.25, 0.53, 0.07, 0.9, steps=8 if res < 8 else 18,
                                                        plane="yz")[1:]]
        obs.append(K.wire("Arm", pts, r * 1.1, IRON, res=res, bevel_res=bevel_res, col=col))
        # a curl between the leg and the seat
        obs.append(K.wire("Leg Scroll", [(x, py, pz) for (_, py, pz) in K.scroll(-0.1, 0.25, 0.09, 1.2,
                                                                                    steps=8 if res < 8 else 24, plane="yz")],
                          r * 0.7, IRON, res=res, bevel_res=bevel_res, col=col))
    return obs


def slats(col, high):
    obs = []
    for y in SEAT_Y:
        obs.append(K.box("Seat Slat", (L, 0.062, 0.032), at=(0, y, 0.45), m=WOOD, bevel=0.008 if high else 0.0, seg=3,
                         col=col))
    for (y, z) in BACK:
        obs.append(K.box("Back Slat", (L, 0.03, 0.085), at=(0, y, z), m=WOOD, bevel=0.008 if high else 0.0, seg=3,
                         rot=(math.radians(-14), 0, 0), col=col))
    return obs


high = []
for x in ENDS:
    high += frame_curves(x, 0.017, 24, 4, HIGH, arm=x != 0.0)
high += slats(HIGH, True)
# bolt heads where every slat sits on an iron frame
for x in ENDS:
    for y in SEAT_Y:
        high.append(K.sphere("Bolt", 0.009, at=(x, y, 0.467), m=BOLT, seg=10, scale=(1, 1, 0.5), col=HIGH))
    for (y, z) in BACK:
        high.append(K.sphere("Bolt", 0.009, at=(x, y - 0.016, z), m=BOLT, seg=10, scale=(1, 0.5, 1), col=HIGH))
# little feet pads
for x in (ENDS[0], ENDS[2]):
    for y in (-0.26, 0.28):
        high.append(K.cyl("Foot", 0.03, 0.02, at=(x, y, 0.01), seg=16, m=IRON, col=HIGH))

low = []
for x in ENDS:
    low += frame_curves(x, 0.019, 3, 1, LOW, arm=x != 0.0)
low += slats(LOW, False)

hi_tris = K.tri_count(high)
bench = K.join("ParkBench", low)
lo_tris = K.tri_count([bench])
K.uv_unwrap(bench, margin=0.006)
maps = K.bake(bench, high, size=1024, name="park_bench", extrusion=0.01, ray=0.03, maps=["normal", "ao", "color", "rough",
                                                                                          "metal"])
K.finish(bench, maps, 1024, "park_bench")
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([bench], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

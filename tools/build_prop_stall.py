# The Void's Market Square stalls, built the detailed way (tools/bake_kit.py; 16 Nov 2026, Hayden: "Can you give the
# whole game this treatment?"). Six stalls stand round the fountain (tools/build_town.gd _market), each selling
# something different, so there are six versions of this one: a plank counter with boarded sides and trim, four
# turned posts, a striped canvas awning that sags a little between its rails with a scalloped edge hanging off the
# front, and the stall's own goods on the counter (baskets of fruit, jars and lollipops, crystal clusters, pots of
# flowers, crates of records, toy blocks and balls). The HIGH version is baked onto a LOW one, which is what the game
# draws. Same size and place as the builder's stall (table 2.6 x 1.2 x 0.9 m, posts 2.4 m at x +-1.2 and z +-0.5, the
# awning at 2.45 m tipped down to the front) and the goods face Godot's +Z, which is Blender's -Y. The colours are the
# Void's (the builder's colours after theme.gd's alien palette), so a stall matches the plaza round it. The stall's
# collision and its name over it stay the builder's.
#
#   python tools/build_prop_stall.py "<out>.glb" <fruit|sweets|crystals|flowers|records|toys> [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402

KINDS = ["fruit", "sweets", "crystals", "flowers", "records", "toys"]
KIND = next((a for a in sys.argv if a in KINDS), "fruit")
OUT = K.out_path("market_stall_%s.glb" % KIND)
NAME = "market_stall_" + KIND
random.seed(KINDS.index(KIND) * 17 + 3)

# The Void's colours for each stall (scenes/town/town.tscn: "<Kind> Goods 0/1/2", "<Kind> Awning 0", "Awning 1")
GOODS = {
    "fruit": [(0.874, 0.228, 0.499), (0.125, 0.92, 0.898), (0.409, 0.782, 0.236)],
    "sweets": [(0.92, 0.523, 0.727), (0.877, 0.473, 0.92), (0.523, 0.898, 0.92)],
    "crystals": [(0.523, 0.601, 0.92), (0.92, 0.523, 0.898), (0.58, 0.92, 0.523)],
    "flowers": [(0.92, 0.374, 0.65), (0.224, 0.887, 0.92), (0.854, 0.423, 0.92)],
    "records": [(0.165, 0.134, 0.184), (0.874, 0.328, 0.557), (0.39, 0.224, 0.92)],
    "toys": [(0.224, 0.328, 0.92), (0.57, 0.125, 0.92), (0.509, 0.92, 0.324)],
}[KIND]
STRIPE_B = (0.777, 0.671, 0.86)

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

WOOD = K.mat("Stall Wood", (0.204, 0.308, 0.552), rough=0.75, grain=(7.0, 0.3), bump=0.08)
TRIM = K.mat("Stall Trim", (0.15, 0.22, 0.42), rough=0.7, grain=(9.0, 0.2), bump=0.05)
CANVAS_A = K.mat("Awning A", GOODS[0] if KIND != "records" else (0.165, 0.134, 0.184), rough=0.85, bump=0.25)
CANVAS_B = K.mat("Awning B", STRIPE_B, rough=0.85, bump=0.25)
BRASS = K.mat("Stall Brass", (0.85, 0.7, 0.35), rough=0.35, metal=1.0, pits=0.1)
GOOD = [K.mat("Goods %d" % i, c, rough=0.45, emit=0.3, bump=0.05) for i, c in enumerate(GOODS)]
WICKER = K.mat("Wicker", (0.62, 0.48, 0.72), rough=0.8, grain=(30.0, 0.35), bump=0.3)

TOP = 0.9                       # the counter's top
W, D = 2.6, 1.2                 # the counter
POSTS = [(-1.2, -0.5), (-1.2, 0.5), (1.2, -0.5), (1.2, 0.5)]   # (x, Blender y); -y is the front
AWN_Z, AWN_Y, AWN_TILT = 2.45, -0.1, 0.22
AWN_D = 1.7


# ---------------------------------------------------------------- the counter
def counter(col, high):
    obs = []
    if high:
        # planks along the top with little gaps, a front and sides of upright boards, trim rails, corner legs
        for k in range(5):
            y = -0.5 + k * 0.25
            obs.append(K.box("Top Plank", (W + 0.1, 0.235, 0.05), at=(0, y, TOP - 0.025), m=WOOD, bevel=0.008, seg=2,
                             col=col))
        n = 13
        for k in range(n):
            x = -W / 2 + (k + 0.5) * W / n
            obs.append(K.box("Front Board", (W / n - 0.012, 0.03, 0.78), at=(x, -D / 2 + 0.01, 0.43), m=WOOD,
                             bevel=0.005, seg=2, col=col))
            obs.append(K.box("Back Board", (W / n - 0.012, 0.03, 0.78), at=(x, D / 2 - 0.01, 0.43), m=WOOD, bevel=0.005,
                             seg=2, col=col))
        for side in (-1, 1):
            for k in range(6):
                y = -D / 2 + (k + 0.5) * D / 6
                obs.append(K.box("Side Board", (0.03, D / 6 - 0.012, 0.78), at=(side * (W / 2 - 0.01), y, 0.43), m=WOOD,
                                 bevel=0.005, seg=2, col=col))
        for z in (0.06, 0.8):
            obs.append(K.box("Front Rail", (W + 0.02, 0.05, 0.07), at=(0, -D / 2 - 0.015, z), m=TRIM, bevel=0.01, seg=2,
                             col=col))
            obs.append(K.box("Back Rail", (W + 0.02, 0.05, 0.07), at=(0, D / 2 + 0.015, z), m=TRIM, bevel=0.01, seg=2,
                             col=col))
            for side in (-1, 1):
                obs.append(K.box("Side Rail", (0.05, D + 0.02, 0.07), at=(side * (W / 2 + 0.015), 0, z), m=TRIM,
                                 bevel=0.01, seg=2, col=col))
        # a diamond on the front, and brass nails at the rails' ends
        obs.append(K.box("Diamond", (0.26, 0.02, 0.26), at=(0, -D / 2 - 0.02, 0.43), m=TRIM, bevel=0.02, seg=2,
                         rot=(0, math.radians(45), 0), col=col))
        for x in (-W / 2 - 0.01, W / 2 + 0.01):
            for z in (0.06, 0.8):
                obs.append(K.sphere("Nail", 0.012, at=(x * 0.985, -D / 2 - 0.042, z), m=BRASS, seg=8, col=col))
    else:
        obs.append(K.box("Counter", (W + 0.04, D + 0.04, TOP - 0.05), at=(0, 0, (TOP - 0.05) / 2), m=WOOD, col=col))
        obs.append(K.box("Top", (W + 0.1, D + 0.02, 0.05), at=(0, 0, TOP - 0.025), m=WOOD, col=col))
    return obs


# ---------------------------------------------------------------- posts and the awning's frame
def posts(col, high):
    obs = []
    seg = 24 if high else 6
    for (x, y) in POSTS:
        if high:
            prof = [(0.0, 0.0), (0.06, 0.0), (0.06, 0.05), (0.048, 0.07), (0.045, 1.0), (0.058, 1.03), (0.058, 1.07),
                    (0.044, 1.1), (0.04, 2.25), (0.052, 2.28), (0.052, 2.32), (0.04, 2.34), (0.04, 2.42), (0.0, 2.42)]
            obs.append(K.lathe("Post", [(r, z) for (r, z) in prof], seg, WOOD, at=(x, y, 0), col=col))
            obs.append(K.sphere("Finial", 0.05, at=(x, y, 2.47 + y * -AWN_TILT * 0.0), m=BRASS, seg=16, col=col))
        else:
            obs.append(K.cyl("Post", 0.05, 2.42, at=(x, y, 1.21), seg=seg, m=WOOD, col=col))
    # rails along the top that hold the canvas up
    for y in (-0.5, 0.5):
        z = AWN_Z - 0.06 + (y - AWN_Y) * math.sin(AWN_TILT)
        obs.append(K.box("Rail", (2.5, 0.06, 0.06), at=(0, y, z), m=TRIM, bevel=0.01 if high else 0.0, seg=2, col=col))
    return obs


def awning(col, high):
    # Five canvas stripes across the stall. Each is a sheet that sags a little in the middle and droops at the front,
    # with a scalloped flap hanging off its front edge, given some thickness.
    obs = []
    nx, ny = (10, 16) if high else (2, 3)
    sw = W / 5 * 1.115                  # 0.58 m, like the builder's stripes
    for s in range(5):
        x0 = -1.16 - sw / 2 + s * sw + 0.002
        x1 = x0 + sw - 0.004
        m = CANVAS_A if s % 2 == 0 else CANVAS_B
        bm = bmesh.new()
        grid = []
        for j in range(ny + 1):
            row = []
            t = j / ny
            y = AWN_D / 2 - t * AWN_D          # back (+y) to front (-y)
            for i in range(nx + 1):
                u = i / nx
                x = x0 + (x1 - x0) * u
                sag = 0.035 * math.sin(math.pi * t) if high else 0.0
                ripple = 0.006 * math.sin(u * math.pi * 2 + s) * math.sin(math.pi * t) if high else 0.0
                row.append(bm.verts.new((x, y, -sag - ripple)))
            grid.append(row)
        for j in range(ny):
            for i in range(nx):
                bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
        # the flap: hangs straight down from the front edge, its bottom cut into two scallops
        fy = -AWN_D / 2
        steps = 12 if high else 2
        top = [bm.verts.new((x0 + (x1 - x0) * (i / steps), fy, 0.0)) for i in range(steps + 1)]
        bot = []
        for i in range(steps + 1):
            u = i / steps
            depth = 0.16 + (0.06 * abs(math.sin(u * math.pi * 2)) if high else 0.03)
            bot.append(bm.verts.new((x0 + (x1 - x0) * u, fy - 0.004, -depth)))
        for i in range(steps):
            bm.faces.new((top[i], top[i + 1], bot[i + 1], bot[i]))
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = K._obj("Awning Stripe", bm, m, smooth=True, col=col)
        sol = ob.modifiers.new("Solid", "SOLIDIFY")
        sol.thickness = 0.02
        sol.offset = 0.0
        ob.location = (0, AWN_Y, AWN_Z)
        ob.rotation_euler = (AWN_TILT, 0, 0)
        obs.append(ob)
        if high:
            # a hem along the scallops and stitching down the seam
            pts = []
            for i in range(25):
                u = i / 24
                depth = 0.16 + 0.06 * abs(math.sin(u * math.pi * 2))
                pts.append((x0 + (x1 - x0) * u, fy - 0.014, -depth + 0.012))
            hem = K.wire("Hem", pts, 0.006, TRIM, res=4, bevel_res=2, col=col)
            hem.location = (0, AWN_Y, AWN_Z)
            hem.rotation_euler = (AWN_TILT, 0, 0)
            obs.append(hem)
    return obs


# ---------------------------------------------------------------- the goods
def g_fruit(col, high):
    obs = []
    for k, x in enumerate((-0.8, 0.0, 0.8)):
        y = -0.15 + 0.12 * (k % 2)
        if high:
            obs.append(K.lathe("Basket", [(0.0, 0.0), (0.2, 0.0), (0.3, 0.16), (0.32, 0.18), (0.3, 0.18), (0.18, 0.02),
                                          (0.0, 0.02)], 32, WICKER, at=(x, y, TOP), col=col))
            obs.append(K.wire("Rim", [(x + math.cos(a) * 0.31, y + math.sin(a) * 0.31, TOP + 0.185)
                                      for a in [i * math.tau / 16 for i in range(16)]], 0.012, WICKER, closed=True,
                              res=6, col=col))
            # a heap of fruit: a ring and a top
            for ring, (rr, zz, n) in enumerate([(0.18, 0.12, 7), (0.09, 0.22, 4), (0.0, 0.3, 1)]):
                for i in range(n):
                    a = i * math.tau / max(n, 1) + ring * 0.4
                    px, py, pz = x + math.cos(a) * rr, y + math.sin(a) * rr, TOP + zz
                    obs.append(K.sphere("Fruit", 0.075, at=(px, py, pz), m=GOOD[k], seg=20, scale=(1, 1, 0.9),
                                        col=col))
                    obs.append(K.cyl("Stem", 0.006, 0.04, at=(px, py, pz + 0.075), seg=6, m=TRIM, col=col))
        else:
            obs.append(K.lathe("Basket", [(0.0, 0.0), (0.2, 0.0), (0.33, 0.195), (0.0, 0.195)], 10, WICKER, at=(x, y, TOP),
                               col=col))
            for ring, (rr, zz, n) in enumerate([(0.18, 0.12, 7), (0.09, 0.22, 4), (0.0, 0.3, 1)]):
                for i in range(n):
                    a = i * math.tau / max(n, 1) + ring * 0.4
                    obs.append(K.sphere("Fruit", 0.082, at=(x + math.cos(a) * rr, y + math.sin(a) * rr, TOP + zz),
                                        m=GOOD[k], seg=6, scale=(1, 1, 0.9), col=col))
    # a few loose ones at the front
    for i, x in enumerate((-0.4, 0.38, 0.45)):
        obs.append(K.sphere("Loose", 0.075, at=(x, -0.42 + 0.05 * i, TOP + 0.07), m=GOOD[i], seg=20 if high else 6,
                            col=col))
    return obs


def g_sweets(col, high):
    obs = []
    for k, x in enumerate((-0.85, 0.85)):
        seg = 32 if high else 8
        obs.append(K.lathe("Jar", [(0.0, 0.0), (0.14, 0.0), (0.16, 0.04), (0.16, 0.3), (0.11, 0.36), (0.11, 0.38),
                                   (0.0, 0.38)], seg, GOOD[2], at=(x, 0.1, TOP), col=col))
        obs.append(K.lathe("Lid", [(0.0, 0.38), (0.125, 0.38), (0.125, 0.42), (0.04, 0.43), (0.04, 0.47), (0.0, 0.47)],
                           seg, BRASS, at=(x, 0.1, TOP), col=col))
        if high:
            for i in range(14):          # sweets showing round the jar's middle
                a = i * math.tau / 14
                obs.append(K.sphere("Sweet", 0.03, at=(x + math.cos(a) * 0.155, 0.1 + math.sin(a) * 0.155,
                                                       TOP + 0.08 + (i % 3) * 0.07), m=GOOD[i % 2], seg=10, col=col))
    # a stand of lollipops: big swirly discs on sticks
    obs.append(K.box("Stand", (0.6, 0.2, 0.12), at=(0, 0.05, TOP + 0.06), m=TRIM, bevel=0.01 if high else 0, seg=2,
                     col=col))
    for i in range(5):
        x = -0.24 + i * 0.12
        h = 0.35 + 0.08 * (i % 2)
        obs.append(K.cyl("Stick", 0.008, h, at=(x, 0.05, TOP + 0.12 + h / 2), seg=8 if high else 4, m=CANVAS_B,
                         col=col))
        disc = K.cyl("Pop", 0.085, 0.025, at=(x, 0.05, TOP + 0.12 + h + 0.06), seg=32 if high else 8, m=GOOD[i % 2],
                     rot=(math.pi / 2, 0, 0), col=col)
        obs.append(disc)
        if high:                         # the swirl
            pts = [(x + math.cos(a) * r, 0.05 - 0.016, TOP + 0.12 + h + 0.06 + math.sin(a) * r)
                   for a, r in [(t * math.tau * 3, 0.075 * (1 - t)) for t in [j / 40 for j in range(41)]]]
            obs.append(K.wire("Swirl", pts, 0.006, CANVAS_B, res=3, bevel_res=2, col=col))
    # wrapped sweets scattered along the front
    for i in range(7):
        x = -1.0 + i * 0.33
        obs.append(K.sphere("Wrapped", 0.04, at=(x, -0.4, TOP + 0.03), m=GOOD[i % 3], seg=12 if high else 4,
                            scale=(1.6, 1, 0.8), col=col))
    return obs


def crystal(col, high, at, h, r, m, tilt=(0, 0)):
    sides = 6
    prof = [(0.0, 0.0), (r, 0.0), (r, h * 0.75), (0.0, h)]
    ob = K.lathe("Crystal", prof, sides, m, sides=sides, smooth=False, col=col)
    ob.location = at
    ob.rotation_euler = (tilt[0], tilt[1], random.random() * math.tau)
    return ob


def g_crystals(col, high):
    obs = []
    obs.append(K.box("Velvet", (2.3, 0.9, 0.03), at=(0, 0, TOP + 0.015), m=CANVAS_B, bevel=0.012 if high else 0, seg=3,
                     col=col))
    for k, x in enumerate((-0.8, 0.0, 0.8)):
        y = -0.1 + 0.1 * (k % 2)
        obs.append(K.sphere("Rock", 0.16, at=(x, y, TOP + 0.05), m=TRIM, seg=16 if high else 6, scale=(1.2, 1, 0.5),
                            col=col))
        n = 9 if high else 4
        for i in range(n):
            a = i * math.tau / n
            lean = 0.15 + 0.35 * (i % 3) / 2
            rr = 0.06 if i else 0.0
            h = (0.42 if i == 0 else 0.22 + 0.06 * (i % 3))
            obs.append(crystal(col, high, (x + math.cos(a) * rr, y + math.sin(a) * rr, TOP + 0.06), h,
                               0.045 if i == 0 else 0.03, GOOD[k], (math.cos(a) * lean if i else 0,
                                                                    math.sin(a) * lean if i else 0)))
    for i, x in enumerate((-0.42, 0.42)):
        obs.append(crystal(col, high, (x, -0.35, TOP + 0.03), 0.16, 0.025, GOOD[(i + 1) % 3], (1.3, 0)))
    return obs


def g_flowers(col, high):
    obs = []
    pot = K.mat("Pot", (0.55, 0.42, 0.7), rough=0.8, pits=0.2, bump=0.15)
    stem = K.mat("Stem", (0.409, 0.782, 0.236), rough=0.7)
    for k, x in enumerate((-0.9, -0.3, 0.3, 0.9)):
        y = -0.1 + 0.15 * (k % 2)
        seg = 28 if high else 8
        obs.append(K.lathe("Pot", [(0.0, 0.0), (0.1, 0.0), (0.13, 0.18), (0.15, 0.19), (0.15, 0.23), (0.12, 0.23),
                                   (0.0, 0.2)], seg, pot, at=(x, y, TOP), col=col))
        n = 5
        for i in range(n):
            a = i * math.tau / n + k
            rr = 0.06 if i else 0.0
            top = (x + math.cos(a) * rr * 1.8, y + math.sin(a) * rr * 1.8, TOP + 0.45 + 0.06 * (i % 2))
            if high:
                obs.append(K.wire("Stem", [(x + math.cos(a) * rr * 0.5, y + math.sin(a) * rr * 0.5, TOP + 0.2),
                                           ((x + top[0]) / 2, (y + top[1]) / 2, TOP + 0.33), top], 0.006, stem, res=6,
                                  bevel_res=2, col=col))
                for p in range(6):      # petals round a middle
                    pa = p * math.tau / 6
                    obs.append(K.sphere("Petal", 0.03, at=(top[0] + math.cos(pa) * 0.035, top[1] + math.sin(pa) * 0.035,
                                                           top[2]), m=GOOD[(k + i) % 3], seg=10, scale=(1.3, 1, 0.4),
                                        col=col))
                obs.append(K.sphere("Middle", 0.02, at=top, m=BRASS, seg=10, col=col))
            else:
                # a flat head and a thin stem each, the petals baked onto them
                obs.append(K.cyl("Head", 0.085, 0.03, at=top, seg=8, m=GOOD[(k + i) % 3], col=col))
                obs.append(K.cyl("Stem", 0.012, 0.25, at=((x + top[0]) / 2, (y + top[1]) / 2, TOP + 0.32), seg=4,
                                 m=stem, col=col))
    return obs


def g_records(col, high):
    obs = []
    vinyl = K.mat("Vinyl", (0.08, 0.07, 0.1), rough=0.25, bump=0.0)
    for k, x in enumerate((-0.7, 0.55)):
        # a crate of record sleeves standing up
        if high:
            for side in (-1, 1):
                obs.append(K.box("Crate Side", (0.02, 0.4, 0.22), at=(x + side * 0.24, 0, TOP + 0.11), m=TRIM,
                                 bevel=0.004, seg=2, col=col))
                obs.append(K.box("Crate End", (0.5, 0.02, 0.22), at=(x, side * 0.2, TOP + 0.11), m=TRIM, bevel=0.004,
                                 seg=2, col=col))
            obs.append(K.box("Crate Floor", (0.48, 0.4, 0.02), at=(x, 0, TOP + 0.01), m=TRIM, col=col))
            for i in range(14):
                yy = -0.17 + i * 0.026
                obs.append(K.box("Sleeve", (0.44, 0.012, 0.3), at=(x, yy, TOP + 0.16), m=GOOD[1 + (i + k) % 2],
                                 bevel=0.002, seg=1, rot=(math.radians(-8 + (i % 3) * 3), 0, 0), col=col))
        else:
            obs.append(K.box("Crate", (0.5, 0.42, 0.32), at=(x, 0, TOP + 0.16), m=TRIM, col=col))
    # two records standing on a little rack at the front, grooves and a label
    for i, x in enumerate((-0.05, 0.25)):
        seg = 48 if high else 10
        obs.append(K.cyl("Record", 0.15, 0.008, at=(x, -0.32, TOP + 0.16), seg=seg, m=vinyl,
                         rot=(math.pi / 2 - 0.15, 0, 0), col=col))
        if high:
            obs.append(K.cyl("Label", 0.05, 0.01, at=(x, -0.322, TOP + 0.16), seg=24, m=GOOD[1 + i],
                             rot=(math.pi / 2 - 0.15, 0, 0), col=col))
            for g in range(5):
                rr = 0.07 + g * 0.015
                obs.append(K.wire("Groove", [(x + math.cos(a) * rr, -0.326 - math.sin(a) * rr * math.sin(0.15),
                                              TOP + 0.16 + math.sin(a) * rr * math.cos(0.15))
                                             for a in [j * math.tau / 32 for j in range(32)]], 0.0015, vinyl,
                                  closed=True, res=2, bevel_res=1, col=col))
    obs.append(K.box("Rack", (0.6, 0.12, 0.05), at=(0.1, -0.32, TOP + 0.025), m=TRIM, col=col))
    return obs


def g_toys(col, high):
    obs = []
    # a little tower of blocks, two balls, and a toy rocket
    for i, (x, y, z, s) in enumerate([(-0.9, 0.0, 0, 0.16), (-0.72, 0.02, 0, 0.16), (-0.81, 0.01, 0.16, 0.16),
                                      (-0.5, -0.3, 0, 0.12), (-0.3, 0.1, 0, 0.14)]):
        obs.append(K.box("Block", (s, s, s), at=(x, y, TOP + z + s / 2), m=GOOD[i % 3], bevel=0.015 if high else 0,
                         seg=3, rot=(0, 0, 0.3 * i), col=col))
    for i, x in enumerate((0.05, 0.4)):
        r = 0.11 + 0.03 * i
        obs.append(K.sphere("Ball", r, at=(x, -0.05 + 0.2 * i, TOP + r), m=GOOD[i + 1], seg=32 if high else 8, col=col))
        if high:
            obs.append(K.wire("Ball Band", [(x + math.cos(a) * r * 1.01, -0.05 + 0.2 * i + math.sin(a) * r * 1.01, TOP + r)
                                            for a in [j * math.tau / 24 for j in range(24)]], 0.012, CANVAS_B,
                              closed=True, res=4, col=col))
    seg = 24 if high else 8
    rx, ry = 0.85, 0.0
    obs.append(K.lathe("Rocket", [(0.0, 0.0), (0.07, 0.0), (0.08, 0.06), (0.08, 0.3), (0.06, 0.4), (0.03, 0.47),
                                  (0.0, 0.5)], seg, CANVAS_B, at=(rx, ry, TOP + 0.04), col=col))
    for f in range(3):
        a = f * math.tau / 3
        obs.append(K.box("Fin", (0.12, 0.012, 0.12), at=(rx + math.cos(a) * 0.1, ry + math.sin(a) * 0.1, TOP + 0.1),
                         m=GOOD[0], rot=(0, 0, a), col=col))
    if high:
        obs.append(K.sphere("Window", 0.03, at=(rx, ry - 0.078, TOP + 0.32), m=GOOD[1], seg=12, scale=(1, 0.4, 1),
                            col=col))
    return obs


GOODS_OF = {"fruit": g_fruit, "sweets": g_sweets, "crystals": g_crystals, "flowers": g_flowers, "records": g_records,
            "toys": g_toys}

high = counter(HIGH, True) + posts(HIGH, True) + awning(HIGH, True) + GOODS_OF[KIND](HIGH, True)
random.seed(KINDS.index(KIND) * 17 + 3)
low = counter(LOW, False) + posts(LOW, False) + awning(LOW, False) + GOODS_OF[KIND](LOW, False)

hi_tris = K.tri_count(high)
stall = K.join("MarketStall", low)
lo_tris = K.tri_count([stall])
print("TRIS high %d low %d" % (hi_tris, lo_tris))
if K.has_flag("dry"):                   # (just the counts, no bake)
    sys.exit(0)
K.uv_unwrap(stall, margin=0.004)
maps = K.bake(stall, high, size=2048, name=NAME, extrusion=0.02, ray=0.09, ao_samples=32)
K.finish(stall, maps, 2048, NAME, emit_strength=0.3)
K.export([stall], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

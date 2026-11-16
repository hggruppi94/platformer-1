# Melody's island in Rhythm Springs, built the detailed way (tools/bake_kit.py; 16 Nov 2026, batch seven of Hayden's
# "give everything the baked in details", with "try to make it look as much like the original pictures as possible":
# his nine concept pictures of the island). Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the builder's pieces (tools/build_rhythm_springs.gd _palm, _torch_path, _bamboo_grove, _gate) so the
# swap (scripts/detail_props.gd dress_rhythm) puts each exactly where the old one was. Blender's X is Godot's X,
# Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   palm          a coconut palm like the pictures': a ringed trunk 5 m tall curving over towards Godot +X, a crown of
#                 eleven arching fronds and a bunch of coconuts. Stands on the origin (the swap scales it to each
#                 palm's height and turns it to its lean).
#   tiki_torch    a carved wooden post with a woven cup on top full of glowing coals. The builder's flame (2.2 m up)
#                 stays and sits in the cup.
#   grove_lantern a wooden post lantern from the bamboo grove picture: a square post with a crossbar, a lantern of
#                 glowing paper panels in a wooden frame and a little curved roof, on a stone foot.
#   springs_gate  the temple gate: two pillars of pale stacked stone (centred on Godot x +-3.2, 1.3 m square, 5.6 m
#                 tall), a carved lintel 8.4 x 1.6 m from 5.6 to 6.5 m with a crest on top, a stone arch inside the
#                 opening, a glowing gold sun on both faces, purple banners with gold crescents on both faces of each
#                 pillar, and moss and vines. The way through (|x| < 2.55, up to 4 m) is clear.
# Colours are sRGB. Collisions stay the builder's.
#
#   python tools/build_prop_island.py "<out>.glb" <palm|tiki_torch|grove_lantern|springs_gate> [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

KINDS = ["palm", "tiki_torch", "grove_lantern", "springs_gate"]
KIND = next((a for a in sys.argv if a in KINDS), "palm")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")


def mesh_from(name, verts, faces, m, col, smooth=False):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, smooth, col)


def rod(name, a, b, r, m, col, seg=12, r2=None):
    a, b = Vector(a), Vector(b)
    d = b - a
    ob = K.cyl(name, r, d.length, at=(a + b) / 2, seg=seg, m=m, col=col, r2=r2)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return ob


def norm(v):
    ln = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / ln for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def strip(name, pts, widths, sides, m, col, thick=0.006, fold=0.0):
    """A thin ribbon along pts. sides[i] = (across, up) at each point; widths[i] across. fold lifts the middle
    (a palm frond's V) by that share of the width. It has a little thickness, so it shows from both sides."""
    verts, faces = [], []
    n = len(pts)
    for p, w, (sd, up) in zip(pts, widths, sides):
        for s in (-0.5, 0.0, 0.5):
            lift = fold * w * (0.5 - abs(s))
            for t in (-thick / 2, thick / 2):
                verts.append(tuple(p[k] + sd[k] * w * s + up[k] * (t + lift) for k in range(3)))
    # 6 verts per point: (left f, left b, mid f, mid b, right f, right b)
    for i in range(n - 1):
        a, b = i * 6, (i + 1) * 6
        for j in (0, 2):
            faces.append([a + j, a + j + 2, b + j + 2, b + j])               # front
            faces.append([a + j + 1, b + j + 1, b + j + 3, a + j + 3])       # back
        faces.append([a + 0, b + 0, b + 1, a + 1])
        faces.append([a + 4, a + 5, b + 5, b + 4])
    faces.append([0, 1, 3, 2])
    faces.append([2, 3, 5, 4])
    e = (n - 1) * 6
    faces.append([e + 0, e + 2, e + 3, e + 1])
    faces.append([e + 2, e + 4, e + 5, e + 3])
    return mesh_from(name, verts, faces, m, col, smooth=True)


# ================================================================ the coconut palm
PALM_H = 5.0


def palm_curve(t):
    """A point up the trunk (t 0..1): straight at the foot, curving over towards +X near the top."""
    return Vector((0.9 * t ** 2.2, 0.0, PALM_H * t))


def palm():
    bark = K.mat("Palm Bark", (0.62, 0.45, 0.32), rough=0.95, grain=(8.0, 0.18), pits=0.3, bump=0.4)
    ring = K.mat("Palm Bark Ring", (0.5, 0.36, 0.26), rough=0.95, bump=0.3)
    blade = K.mat("Palm Frond", (0.36, 0.7, 0.36), rough=0.8, bump=0.12)
    leaflet = K.mat("Palm Leaflet", (0.44, 0.8, 0.38), rough=0.75, grain=(60.0, 0.12))
    leaflet2 = K.mat("Palm Leaflet Light", (0.56, 0.85, 0.38), rough=0.75, grain=(60.0, 0.12))
    rib = K.mat("Palm Rib", (0.62, 0.66, 0.32), rough=0.8)
    nut = K.mat("Coconut", (0.42, 0.3, 0.18), rough=0.85, bump=0.4)
    nut2 = K.mat("Coconut Green", (0.5, 0.55, 0.22), rough=0.7, bump=0.2)
    top = palm_curve(1.0)

    def build(col, high):
        obs = []
        # The trunk: stacked rings, each a little fatter at its bottom, so the bark steps like the pictures'
        segs = 16
        for s in range(segs):
            t0, t1 = s / segs, (s + 1) / segs
            a, b = palm_curve(t0), palm_curve(t1)
            r0 = 0.25 - 0.08 * t0
            r1 = 0.25 - 0.08 * t1
            if high:
                obs.append(rod("Trunk", a, b + (b - a) * 0.05, r0 + 0.03, bark, col, seg=20, r2=r1))
                obs.append(rod("Ring", a + (b - a) * 0.0, a + (b - a) * 0.18, r0 + 0.045, ring, col, seg=20,
                               r2=r0 + 0.02))
            elif s % 2 == 0:
                b2 = palm_curve((s + 2) / segs)
                obs.append(rod("Trunk", a, b2, r0 + 0.04, bark, col, seg=8, r2=0.25 - 0.08 * (s + 2) / segs + 0.03))
        # a fat knob where the fronds come out
        obs.append(K.sphere("Crown", 0.24, at=top + Vector((0, 0, 0.05)), m=bark, seg=16 if high else 8, col=col))
        # The fronds: each arches up and out and droops at the tip. The low one is the blade's outline; the high one
        # has the same blade (so the bake always finds it) with a rib and rows of leaflets laid over it.
        n = 11
        for i in range(n):
            rnd = random.Random(700 + i)
            ang = i / n * math.tau + rnd.uniform(-0.15, 0.15)
            ln = rnd.uniform(2.6, 3.3)
            rise = rnd.uniform(0.35, 0.7)
            droop = rnd.uniform(1.4, 2.2)
            out = (math.cos(ang), math.sin(ang), 0.0)
            steps = 14 if high else 6
            pts, ws, sides = [], [], []
            for k in range(steps + 1):
                u = k / steps
                p = (top.x + out[0] * ln * u, top.y + out[1] * ln * u, top.z + 0.1 + ln * (rise * u - droop * u * u * 0.6))
                pts.append(p)
                ws.append(0.85 * math.sin(math.pi * min(1.0, 0.1 + u * 0.92)) + 0.03)
            for k in range(steps + 1):
                a = pts[max(0, k - 1)]
                b = pts[min(steps, k + 1)]
                fwd = norm(tuple(b[j] - a[j] for j in range(3)))
                sd = norm(cross(fwd, (0, 0, 1)))
                up = norm(cross(sd, fwd))
                sides.append((sd, up))
            obs.append(strip("Frond", pts, ws, sides, blade, col, thick=0.01, fold=0.22))
            if high:
                obs.append(K.wire("Rib", [(p[0] + s[1][0] * 0.02, p[1] + s[1][1] * 0.02, p[2] + s[1][2] * 0.02 + 0.01)
                                          for p, s in zip(pts[::2], sides[::2])], 0.022, rib, res=6, bevel_res=2,
                                  col=col))
                # leaflets: 26 a side, angled forward along the frond, laid just over the blade
                for k in range(1, 27):
                    u = k / 27.5
                    f = u * steps
                    j = min(steps - 1, int(f))
                    fr = f - j
                    p = tuple(pts[j][q] + (pts[j + 1][q] - pts[j][q]) * fr for q in range(3))
                    sd, up = sides[j]
                    fwd = norm(tuple(pts[j + 1][q] - pts[j][q] for q in range(3)))
                    w = ws[j] * 0.5
                    for side in (-1, 1):
                        r2 = random.Random(9000 + i * 100 + k * 2 + side)
                        lp, lw, ls = [], [], []
                        for e in range(5):
                            v = e / 4
                            d = tuple(side * sd[q] * 0.9 + fwd[q] * 0.45 for q in range(3))
                            lift = 0.25 * w * v * (1 - v) * 4 * 0.3 + 0.015
                            lp.append(tuple(p[q] + d[q] * w * v + up[q] * (lift + 0.012 * side * 0) for q in range(3)))
                            lw.append(0.08 * math.sin(math.pi * min(1.0, 0.1 + v * 0.9)) + 0.01)
                            ax = norm(cross(norm(d), up))
                            ls.append((ax, up))
                        obs.append(strip("Leaflet", lp, lw, ls, leaflet if r2.random() < 0.6 else leaflet2, col,
                                         thick=0.004))
        # a bunch of coconuts under the crown
        for k in range(5):
            rnd = random.Random(40 + k)
            a = k / 5 * math.tau + 0.4
            at = top + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, -0.28 - rnd.uniform(0, 0.12)))
            obs.append(K.sphere("Coconut", 0.15, at=at, m=nut if k % 2 else nut2, seg=16 if high else 8,
                                scale=(1, 1, 1.1), col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the tiki torch
def tiki_torch():
    wood = K.mat("Torch Wood", (0.5, 0.33, 0.2), rough=0.9, grain=(18.0, 0.22), bump=0.3)
    dark = K.mat("Torch Wood Dark", (0.34, 0.22, 0.14), rough=0.9, grain=(18.0, 0.2))
    weave = K.mat("Torch Weave", (0.85, 0.68, 0.42), rough=0.85, grain=(90.0, 0.25), bump=0.4)
    rope = K.mat("Torch Rope", (0.78, 0.6, 0.38), rough=0.85, bump=0.3)
    coal = K.mat("Torch Coals", (0.25, 0.1, 0.05), rough=0.8, emit=2.5, emit_rgb=(1.0, 0.45, 0.12))
    stone = K.mat("Torch Stone", (0.6, 0.55, 0.48), rough=0.95, pits=0.3, bump=0.5)

    def build(col, high):
        obs = []
        sg = 16 if high else 8
        # stones round its foot
        for k in range(6):
            rnd = random.Random(30 + k)
            a = k / 6 * math.tau + rnd.uniform(-0.2, 0.2)
            r = rnd.uniform(0.09, 0.14)
            obs.append(K.sphere("Foot Stone", r, at=(math.cos(a) * 0.22, math.sin(a) * 0.22, r * 0.3),
                                m=stone, seg=12 if high else 6, scale=(1.2, 1.0, 0.6), col=col))
        # the post, a bit thicker at the foot, with carved bands
        obs.append(K.lathe("Post", [(0.0, 0.0), (0.105, 0.0), (0.09, 0.5), (0.075, 1.7), (0.0, 1.7)], seg=sg, m=wood,
                           flutes=6 if high else 0, flute_depth=0.01, flute_z=(0.55, 1.5), col=col))
        for z in ((0.45, 1.25, 1.6) if high else (1.25,)):
            obs.append(K.cyl("Band", 0.1, 0.06, at=(0, 0, z), seg=sg, m=dark, col=col))
        if high:
            # zig-zag carving between the bands
            for k in range(8):
                a = k / 8 * math.tau
                for z in (0.62, 0.78, 0.94, 1.1):
                    obs.append(K.box("Notch", (0.03, 0.02, 0.06), at=(math.cos(a) * 0.082, math.sin(a) * 0.082, z),
                                     rot=(0.6 if (k + int(z * 10)) % 2 else -0.6, 0, a), m=dark, col=col))
        # the woven cup on top, flaring out, with rope lashed round it
        obs.append(K.lathe("Cup", [(0.0, 1.66), (0.08, 1.66), (0.12, 1.75), (0.19, 1.98), (0.21, 2.1), (0.18, 2.1),
                                   (0.0, 2.02)], seg=24 if high else 10, m=weave,
                           flutes=16 if high else 0, flute_depth=0.012, flute_z=(1.76, 2.08), col=col))
        for z, r in ((1.8, 0.135), (2.07, 0.205)):
            obs.append(K.wire("Lashing", [(math.cos(k / 14 * math.tau) * r, math.sin(k / 14 * math.tau) * r, z)
                                          for k in range(14)], 0.012, rope, closed=True, res=4 if high else 2,
                              bevel_res=2 if high else 0, col=col))
        # glowing coals heaped in the cup
        if high:
            for k in range(14):
                rnd = random.Random(60 + k)
                a = rnd.uniform(0, math.tau)
                d = rnd.uniform(0.0, 0.13)
                obs.append(K.sphere("Coal", rnd.uniform(0.035, 0.055), at=(math.cos(a) * d, math.sin(a) * d,
                                    2.06 + rnd.uniform(0, 0.04)), m=coal, seg=8, col=col))
        obs.append(K.cyl("Coal Bed", 0.17, 0.04, at=(0, 0, 2.06), seg=sg, m=coal, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the post lantern from the bamboo grove picture
def grove_lantern():
    wood = K.mat("Lantern Wood", (0.42, 0.27, 0.17), rough=0.85, grain=(16.0, 0.22), bump=0.25)
    roof = K.mat("Lantern Roof", (0.3, 0.2, 0.14), rough=0.85, grain=(30.0, 0.15), bump=0.2)
    paper = K.mat("Lantern Paper", (1.0, 0.72, 0.36), rough=0.6, emit=2.2, emit_rgb=(1.0, 0.68, 0.28))
    iron = K.mat("Lantern Iron", (0.22, 0.2, 0.2), rough=0.5, metal=0.8, pits=0.2)
    stone = K.mat("Lantern Foot Stone", (0.62, 0.58, 0.52), rough=0.95, pits=0.3, bump=0.5)

    def build(col, high):
        obs = []
        bv = 0.012 if high else 0.0
        # a stone foot and the post
        obs.append(K.box("Foot", (0.42, 0.42, 0.16), at=(0, 0, 0.08), m=stone, bevel=0.03 if high else 0, col=col))
        obs.append(K.box("Post", (0.13, 0.13, 1.48), at=(0, 0, 0.16 + 0.74), m=wood, bevel=bv, col=col))
        if high:
            for z in (0.4, 0.75, 1.1):
                obs.append(K.box("Post Band", (0.145, 0.145, 0.03), at=(0, 0, z), m=iron, col=col))
        # the crossbar and its brackets under the lantern
        obs.append(K.box("Crossbar", (0.5, 0.14, 0.07), at=(0, 0, 1.6), m=wood, bevel=bv, col=col))
        for sx in (-1, 1):
            obs.append(K.box("Bracket", (0.05, 0.08, 0.22), at=(sx * 0.12, 0, 1.47), rot=(0, sx * 0.6, 0), m=wood,
                             bevel=bv, col=col))
        # the lantern: glowing paper panels in a wooden frame
        lz0, lz1 = 1.64, 2.06
        h = lz1 - lz0
        obs.append(K.box("Paper", (0.32, 0.32, h - 0.04), at=(0, 0, (lz0 + lz1) / 2), m=paper, col=col))
        for sx in (-1, 1):
            for sy in (-1, 1):
                obs.append(K.box("Corner Post", (0.05, 0.05, h), at=(sx * 0.165, sy * 0.165, (lz0 + lz1) / 2), m=wood,
                                 bevel=bv * 0.5, col=col))
        for z in (lz0 + 0.02, lz1 - 0.02):
            obs.append(K.box("Rim", (0.38, 0.38, 0.04), at=(0, 0, z), m=wood, bevel=bv * 0.5, col=col))
        if high:
            # the lattice on each face: a cross of slats
            for k in range(4):
                a = k * math.pi / 2
                cx, cy = math.cos(a) * 0.163, math.sin(a) * 0.163
                rz = a + math.pi / 2
                obs.append(K.box("Slat", (0.3, 0.012, 0.016), at=(cx, cy, (lz0 + lz1) / 2), rot=(0, 0, rz), m=wood,
                                 col=col))
                obs.append(K.box("Slat", (0.016, 0.012, h - 0.06), at=(cx, cy, (lz0 + lz1) / 2), rot=(0, 0, rz),
                                 m=wood, col=col))
        # a little curved roof with upturned corners and a knob
        rp = [(0.0, 2.06), (0.31, 2.06), (0.28, 2.1), (0.2, 2.17), (0.1, 2.24), (0.0, 2.27)]
        obs.append(K.lathe("Roof", rp, seg=4, m=roof, col=col))
        obs[-1].rotation_euler = (0, 0, math.pi / 4)
        if high:
            for k in range(4):
                a = math.pi / 4 + k * math.pi / 2
                tip = rod("Roof Tip", (math.cos(a) * 0.27, math.sin(a) * 0.27, 2.08), (math.cos(a) * 0.36,
                                                                                  math.sin(a) * 0.36, 2.13), 0.02,
                          roof, col, seg=8, r2=0.008)
                obs.append(tip)
        obs.append(K.sphere("Knob", 0.04, at=(0, 0, 2.29), m=iron, seg=12 if high else 6, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the temple gate
def springs_gate():
    stone = K.mat("Gate Stone", (0.76, 0.69, 0.58), rough=0.95, pits=0.35, wear=0.06, bump=0.6)
    stone2 = K.mat("Gate Stone Grey", (0.66, 0.62, 0.56), rough=0.95, pits=0.35, wear=0.06, bump=0.6)
    joint = K.mat("Gate Mortar", (0.4, 0.36, 0.32), rough=1.0)
    moss = K.mat("Gate Moss", (0.42, 0.62, 0.3), rough=0.9, bump=0.5)
    vine = K.mat("Gate Vine", (0.3, 0.55, 0.28), rough=0.85)
    cloth = K.mat("Gate Banner", (0.38, 0.28, 0.66), rough=0.85, grain=(120.0, 0.08), bump=0.08)
    gold = K.mat("Gate Gold", (1.0, 0.78, 0.32), rough=0.35, metal=0.9, pits=0.1)
    sun = K.mat("Gate Sun", (1.0, 0.7, 0.2), rough=0.4, metal=0.3, emit=3.0, emit_rgb=(1.0, 0.62, 0.15))

    def blocks(obs, col, high, cx, w, z0, z1, d, rnd_seed):
        """A pillar of stacked stones. High: separate bevelled blocks (two a course, staggered) with mortar behind;
        low: one block per course."""
        rnd = random.Random(rnd_seed)
        z = z0
        course = 0
        while z < z1 - 0.01:
            h = min(z1 - z, rnd.choice((0.45, 0.55, 0.6)))
            sh = rnd.uniform(-0.02, 0.02)
            if high:
                obs.append(K.box("Mortar", (w - 0.04, d - 0.04, h), at=(cx, 0, z + h / 2), m=joint, col=col))
                split = 0.45 if course % 2 == 0 else 0.55
                xs = [(cx - w / 2, cx - w / 2 + w * split), (cx - w / 2 + w * split, cx + w / 2)]
                for a, b in xs:
                    mm = stone if rnd.random() < 0.6 else stone2
                    obs.append(K.box("Block", (b - a - 0.02, d + rnd.uniform(-0.01, 0.02), h - 0.025),
                                     at=((a + b) / 2 + sh, rnd.uniform(-0.01, 0.01), z + h / 2), m=mm, bevel=0.045,
                                     seg=2, col=col))
            else:
                obs.append(K.box("Block", (w + 0.01, d + 0.01, h), at=(cx, 0, z + h / 2), m=stone, col=col))
            z += h
            course += 1

    def build(col, high):
        obs = []
        # the pillars (1.3 m square, 5.6 m), each with a stepped plinth and a cap
        for sx in (-1, 1):
            x = sx * 3.2
            obs.append(K.box("Plinth", (1.55, 1.55, 0.35), at=(x, 0, 0.175), m=stone2, bevel=0.04 if high else 0,
                             col=col))
            blocks(obs, col, high, x, 1.3, 0.35, 5.25, 1.3, 11 + sx)
            obs.append(K.box("Cap", (1.55, 1.55, 0.18), at=(x, 0, 5.34), m=stone2, bevel=0.04 if high else 0,
                             col=col))
            obs.append(K.box("Cap Step", (1.42, 1.42, 0.17), at=(x, 0, 5.515), m=stone, bevel=0.03 if high else 0,
                             col=col))
            # banners on both faces (Godot +Z and -Z), on a gold rod, with a crescent and a little ring
            for fy in (-1, 1):
                y = fy * 0.68
                obs.append(rod("Banner Rod", (x - 0.55, y + fy * 0.04, 4.55), (x + 0.55, y + fy * 0.04, 4.55), 0.03,
                               gold, col, seg=10 if high else 5))
                for ex in (-0.55, 0.55):
                    obs.append(K.sphere("Rod End", 0.05, at=(x + ex, y + fy * 0.04, 4.55), m=gold,
                                        seg=10 if high else 5, col=col))
                # the cloth, hanging in soft folds, cut to a point at the bottom
                cols = 9 if high else 3
                verts, faces = [], []
                for i in range(cols + 1):
                    u = i / cols
                    bx = x - 0.45 + 0.9 * u
                    bottom = 2.3 - 0.35 * (1 - abs(u - 0.5) * 2)
                    wob = 0.025 * math.sin(u * math.pi * 4) if high else 0.0
                    for zz in (4.5, bottom):
                        verts.append((bx, y + fy * wob, zz))
                for i in range(cols):
                    a = i * 2
                    faces.append([a, a + 2, a + 3, a + 1])
                cl = mesh_from("Banner", verts, faces, cloth, col, smooth=True)
                sol = cl.modifiers.new("Thick", "SOLIDIFY")
                sol.thickness = 0.03
                obs.append(cl)
                # gold trim down its edges and a crescent and a disc on it
                gy = y + fy * 0.035
                if high:
                    for ex in (-0.43, 0.43):
                        obs.append(rod("Trim", (x + ex, gy, 4.48), (x + ex, gy, 2.32), 0.012, gold, col, seg=6))
                moon = K.lathe("Crescent", [(0.18, -0.015), (0.27, -0.015), (0.27, 0.015), (0.18, 0.015)],
                               seg=32 if high else 12, m=gold, col=col)
                moon.location = (x, gy, 3.75)
                moon.rotation_euler = (math.pi / 2, 0, 0)
                obs.append(moon)
                obs.append(K.cyl("Moon Cut", 0.2, 0.034, at=(x + 0.09, gy + fy * 0.003, 3.8), rot=(math.pi / 2, 0, 0),
                                 seg=24 if high else 10, m=cloth, col=col))
                obs.append(K.cyl("Banner Disc", 0.07, 0.03, at=(x, gy, 3.15), rot=(math.pi / 2, 0, 0),
                                 seg=16 if high else 8, m=gold, col=col))
        # the arch inside the opening: stones on a curve from 4.0 m at the pillars up to 5.6 m
        span = 2.55
        rise = 1.45
        rad = (span ** 2 + rise ** 2) / (2 * rise)
        cz = 5.6 - rad
        a_end = math.asin(span / rad)
        stones = 11 if high else 5
        for i in range(stones):
            a0 = -a_end + 2 * a_end * i / stones
            a1 = -a_end + 2 * a_end * (i + 1) / stones
            gap = 0.012 if high else 0.0
            verts = []
            for a in (a0 + gap, a1 - gap):
                for rr in (rad, rad + 0.5):
                    for yy in (-0.55, 0.55):
                        verts.append((math.sin(a) * rr, yy, cz + math.cos(a) * rr))
            faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
            ob = mesh_from("Arch Stone", verts, faces, stone if i % 2 else stone2, col)
            if high:
                bvm = ob.modifiers.new("Bevel", "BEVEL")
                bvm.width = 0.03
                bvm.segments = 2
            obs.append(ob)
        # fill over the arch up to the lintel
        obs.append(K.box("Spandrel", (5.1, 1.1, 0.25), at=(0, 0, 5.5), m=stone2, col=col))
        # the lintel, its band and the crest
        if high:
            for i in range(6):
                x0 = -4.2 + i * 1.4
                obs.append(K.box("Lintel Block", (1.38, 1.6, 0.9), at=(x0 + 0.7, 0, 6.05), m=stone if i % 2 else stone2,
                                 bevel=0.04, col=col))
        else:
            obs.append(K.box("Lintel", (8.4, 1.6, 0.9), at=(0, 0, 6.05), m=stone, col=col))
        obs.append(K.box("Cornice", (9.0, 1.8, 0.22), at=(0, 0, 6.61), m=stone2, bevel=0.04 if high else 0, col=col))
        obs.append(K.box("Crest", (5.0, 1.2, 0.55), at=(0, 0, 6.995), m=stone, bevel=0.05 if high else 0, col=col))
        obs.append(K.box("Crest Top", (5.3, 1.35, 0.12), at=(0, 0, 7.33), m=stone2, bevel=0.03 if high else 0, col=col))
        # the glowing sun on both faces of the lintel, and a carved row of notes either side of it
        for fy in (-1, 1):
            y = fy * 0.81
            disc = K.cyl("Sun", 0.3, 0.1, at=(0, y, 6.05), rot=(math.pi / 2, 0, 0), seg=32 if high else 12, m=sun,
                         col=col)
            obs.append(disc)
            rays = 16 if high else 8
            for k in range(rays):
                a = k / rays * math.tau
                ln = 0.24 if k % 2 == 0 else 0.15
                r0 = 0.34
                obs.append(K.box("Sun Ray", (0.07, 0.08, ln), at=(math.sin(a) * (r0 + ln / 2), y,
                                 6.05 + math.cos(a) * (r0 + ln / 2)), rot=(0, a, 0), m=sun, col=col))
            for k in range(8):
                xx = -3.6 + k * 0.45 if k < 4 else 1.05 + (k - 4) * 0.45 + 0.8
                xx = (-3.75 + k * 0.42) if k < 4 else (1.1 + (k - 4) * 0.42 + 0.95)
                obs.append(K.sphere("Note", 0.13, at=(xx, y + fy * 0.02, 6.05), m=gold, seg=12 if high else 6,
                                    scale=(1, 0.5, 1), col=col))
        if high:
            # moss on the caps and ledges, and vines trailing down the pillars' outer sides
            for k in range(26):
                rnd = random.Random(300 + k)
                x = rnd.choice((-1, 1)) * rnd.uniform(2.6, 3.9) if k < 10 else rnd.uniform(-4.4, 4.4)
                z = 5.62 if k < 10 else 6.72
                y = rnd.uniform(-0.7, 0.7)
                obs.append(K.sphere("Moss", rnd.uniform(0.08, 0.16), at=(x, y, z), m=moss, seg=10,
                                    scale=(1.6, 1.2, 0.45), col=col))
            for sx in (-1, 1):
                for v in range(3):
                    rnd = random.Random(400 + v + sx * 10)
                    y0 = rnd.uniform(-0.5, 0.5)
                    pts = []
                    for s in range(9):
                        z = 6.5 - s * rnd.uniform(0.35, 0.5)
                        pts.append((sx * 3.86 + sx * 0.01 * math.sin(s), y0 + 0.12 * math.sin(s * 1.3 + v), z))
                    obs.append(K.wire("Vine", pts, 0.02, vine, res=6, bevel_res=1, col=col))
                    for p in pts[1::1]:
                        obs.append(K.sphere("Vine Leaf", 0.06, at=(p[0] + sx * 0.02, p[1] + 0.05, p[2]), m=moss,
                                            seg=8, scale=(0.6, 1.3, 0.9), col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


BUILD = {"palm": (palm, 1024), "tiki_torch": (tiki_torch, 512), "grove_lantern": (grove_lantern, 512),
         "springs_gate": (springs_gate, 2048)}
fn, size = BUILD[KIND]
high, low = fn()
hi_tris = K.tri_count(list(HIGH.all_objects))
prop = K.join(NAME, low)
lo_tris = K.tri_count([prop])
K.uv_unwrap(prop, margin=0.004 if KIND in ("springs_gate", "palm") else 0.006)
emit = KIND in ("tiki_torch", "grove_lantern", "springs_gate")
thin = KIND == "palm"
maps = K.bake(prop, list(HIGH.all_objects), size=size, name=NAME, extrusion=0.02 if thin else 0.03,
              ray=0.06 if thin else 0.1,
              maps=(["ao", "color", "rough", "metal"] if thin else ["normal", "ao", "color", "rough", "metal"])
              + (["emit"] if emit else []))
if thin:
    # The fronds are thin ribbons: like the corn sheaf, it keeps its flat normals and only a gentle share of the
    # shadow, so the crown doesn't bake dark.
    import numpy as np
    a = np.empty(size * size * 4, dtype=np.float32)
    maps["ao"].pixels.foreach_get(a)
    a[0::4] = 0.55 + 0.45 * a[0::4]
    a[1::4] = a[0::4]
    a[2::4] = a[0::4]
    maps["ao"].pixels.foreach_set(a)
K.finish(prop, maps, size, NAME, emit_strength=1.5 if emit else 1.0)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([prop], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

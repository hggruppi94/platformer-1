# Stars Hollow's country things, built the detailed way (tools/bake_kit.py; 16 Nov 2026, batch four of Hayden's
# "give everything the baked in details"): a round hay bale, a sheaf of cornstalks tied with twine, the fire station's
# fire engine and the rowing boat tied up at Willow Pond's dock. Each HIGH version is baked onto a LOW one, which is
# what the game draws.
#
# Sizes match the builder's pieces (tools/build_earth.gd) so the swap (scripts/detail_props.gd) puts each exactly
# where the old one was:
#   hay_bale     a round bale 1.2 m across and 1.2 m long, its middle at the origin and its axis along Blender's Z
#                (Godot's Y): the game puts it inside the builder's cylinder, which lies on its side.
#   corn_sheaf   five or so stalks' worth of dry cornstalks, 2.3 m tall, standing on the origin.
#   fire_truck   the engine on the apron: 2.4 m wide, 5.5 m long, wheels where the builder's were, its front towards
#                Godot's +Z (Blender's -Y), standing on the origin.
#   rowing_boat  a clinker rowing boat about 3.8 m long, its middle at the origin (the builder's hull's middle, just
#                over the water), bow towards Godot's +Z.
# Colours are the builder's (sRGB). Collisions stay the builder's.
#
#   python tools/build_prop_farm.py "<out>.glb" <hay_bale|corn_sheaf|fire_truck|rowing_boat> [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402

KINDS = ["hay_bale", "corn_sheaf", "fire_truck", "rowing_boat"]
KIND = next((a for a in sys.argv if a in KINDS), "hay_bale")
NAME = KIND
OUT = K.out_path(NAME + ".glb")
random.seed(KINDS.index(KIND) * 31 + 7)

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


def strip(name, pts, widths, side, m, col, thick=0.004):
    """A thin ribbon (a leaf, a husk) along pts, widths[i] across at each point, `side` the direction across.
    It has a little thickness, so it shows from both sides once it's in the game."""
    verts, faces = [], []
    n = len(pts)
    for i, (p, w) in enumerate(zip(pts, widths)):
        for s in (-0.5, 0.5):
            for t in (-thick / 2, thick / 2):
                nrm = side[1]
                verts.append((p[0] + side[0][0] * w * s + nrm[0] * t, p[1] + side[0][1] * w * s + nrm[1] * t,
                              p[2] + side[0][2] * w * s + nrm[2] * t))
    # verts per point: (left, front) (left, back) (right, front) (right, back)
    for i in range(n - 1):
        a, b = i * 4, (i + 1) * 4
        faces.append([a + 0, a + 2, b + 2, b + 0])      # front
        faces.append([a + 1, b + 1, b + 3, a + 3])      # back
        faces.append([a + 0, b + 0, b + 1, a + 1])      # left edge
        faces.append([a + 2, a + 3, b + 3, b + 2])      # right edge
    faces.append([0, 1, 3, 2])
    e = (n - 1) * 4
    faces.append([e + 0, e + 2, e + 3, e + 1])
    return mesh_from(name, verts, faces, m, col, smooth=True)


def norm(v):
    ln = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / ln for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


# ================================================================ the hay bale
BALE_R = 0.6
BALE_H = 1.2


def hay_bale():
    straw = K.mat("Hay", (0.88, 0.74, 0.38), rough=0.95, pits=0.35, bump=0.35)
    light = K.mat("Hay Light", (0.95, 0.85, 0.52), rough=0.9)
    dark = K.mat("Hay Dark", (0.7, 0.55, 0.26), rough=0.95)
    twine = K.mat("Bale Twine", (0.86, 0.5, 0.2), rough=0.8, bump=0.2)
    h = BALE_H / 2
    profile = [(0.0, -h), (BALE_R - 0.12, -h), (BALE_R - 0.04, -h + 0.015), (BALE_R - 0.005, -h + 0.06),
               (BALE_R, -h + 0.14), (BALE_R + 0.008, 0.0), (BALE_R, h - 0.14), (BALE_R - 0.005, h - 0.06),
               (BALE_R - 0.04, h - 0.015), (BALE_R - 0.12, h), (0.0, h)]

    def build(col, high):
        obs = []
        obs.append(K.lathe("Bale", profile, seg=56 if high else 18, m=straw, col=col))
        if not high:
            return obs
        # the rolled-up ends: a few spirals of straw on each end, the way a round baler winds it
        for zs in (-1, 1):
            for s in range(3):
                pts = []
                turns = 7
                for i in range(260):
                    t = i / 259
                    a = t * turns * math.tau + s * math.tau / 3
                    r = 0.05 + t * (BALE_R - 0.11)
                    pts.append((math.cos(a) * r, math.sin(a) * r, zs * (h + 0.004)))
                obs.append(K.wire("Spiral", pts, 0.009, (light, dark, straw)[s], res=3, bevel_res=1, col=col))
        # twine bands round the middle
        for z in (-0.38, -0.13, 0.13, 0.38):
            pts = [(math.cos(k / 24 * math.tau) * (BALE_R + 0.012), math.sin(k / 24 * math.tau) * (BALE_R + 0.012), z)
                   for k in range(24)]
            obs.append(K.wire("Twine", pts, 0.006, twine, closed=True, res=4, bevel_res=2, col=col))
        # loose straws lying round the outside, and a few sticking out
        for i in range(520):
            a = random.uniform(0, math.tau)
            z = random.uniform(-h + 0.05, h - 0.05)
            ln = random.uniform(0.1, 0.26)
            tilt = random.uniform(-0.35, 0.35)
            r = BALE_R + 0.008 + random.uniform(0, 0.006)
            obs.append(K.box("Straw", (ln, 0.007, 0.004), at=(math.cos(a) * r, math.sin(a) * r, z),
                             rot=(0, tilt, a + math.pi / 2), m=random.choice((light, dark, straw)), col=col))
        for i in range(70):
            a = random.uniform(0, math.tau)
            zs = random.choice((-1, 1))
            r = BALE_R - random.uniform(0.0, 0.06)
            obs.append(K.box("Stray", (random.uniform(0.08, 0.18), 0.006, 0.004),
                             at=(math.cos(a) * r, math.sin(a) * r, zs * (h - 0.02)),
                             rot=(random.uniform(-0.5, 0.5), zs * random.uniform(0.4, 0.9), a),
                             m=random.choice((light, straw)), col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the cornstalk sheaf
def corn_sheaf():
    stalk = K.mat("Cornstalk", (0.8, 0.68, 0.4), rough=0.9, grain=(30.0, 0.12), bump=0.15)
    leaf = K.mat("Corn Leaf", (0.84, 0.72, 0.45), rough=0.85, grain=(40.0, 0.15), bump=0.2)
    brown = K.mat("Corn Leaf Brown", (0.66, 0.5, 0.3), rough=0.9, grain=(40.0, 0.15))
    twine = K.mat("Sheaf Twine", (0.86, 0.5, 0.2), rough=0.8, bump=0.2)
    kernel = K.mat("Corn Kernel", (0.95, 0.68, 0.18), rough=0.45)
    red = K.mat("Corn Kernel Red", (0.75, 0.22, 0.12), rough=0.45)
    husk = K.mat("Corn Husk", (0.9, 0.82, 0.6), rough=0.8, grain=(30.0, 0.1))
    tie_z = 1.05
    top_z = 2.3

    def build(col, high):
        obs = []
        # The low sheaf has every stalk the high one has, in the same place (each stalk draws from its own seed), so
        # the bake finds the high stalk right where the low one is; the low one just has fewer leaves.
        n = 22
        for i in range(n):
            rnd = random.Random(500 + i)
            a = i / n * math.tau + rnd.uniform(-0.15, 0.15)
            rb = rnd.uniform(0.22, 0.32)
            rw = rnd.uniform(0.05, 0.1)
            rt = rnd.uniform(0.28, 0.42)
            twist = rnd.uniform(0.25, 0.45)
            top = top_z + rnd.uniform(-0.25, 0.1)
            p0 = (math.cos(a) * rb, math.sin(a) * rb, 0.0)
            p1 = (math.cos(a + twist * 0.4) * rw, math.sin(a + twist * 0.4) * rw, tie_z)
            p2 = (math.cos(a + twist) * rt, math.sin(a + twist) * rt, top)
            obs.append(K.wire("Stalk", [p0, p1, p2], 0.017 if high else 0.02, stalk, res=6 if high else 2,
                              bevel_res=2 if high else 0, col=col))
            if high:
                # the nodes up the stalk
                for t in (0.2, 0.45, 0.7):
                    q = tuple(p1[k] + (p2[k] - p1[k]) * t for k in range(3))
                    obs.append(K.cyl("Node", 0.021, 0.025, at=q, seg=8, m=stalk, col=col))
            # dry leaves: from up the stalk, arching out and drooping, some brown and curled
            leaves = 3 if high else (1 if i % 2 == 0 else 0)
            for k in range(leaves):
                rnd = random.Random(9000 + i * 10 + k)
                t = rnd.uniform(0.15, 0.75)
                base = tuple(p1[j] + (p2[j] - p1[j]) * t for j in range(3))
                out = norm((math.cos(a + twist * t + rnd.uniform(-0.6, 0.6)),
                            math.sin(a + twist * t + rnd.uniform(-0.6, 0.6)), 0.0))
                ln = rnd.uniform(0.5, 0.85)
                droop = rnd.uniform(0.6, 1.3)
                pts, ws = [], []
                steps = 9 if high else 4
                for s in range(steps + 1):
                    u = s / steps
                    pts.append((base[0] + out[0] * ln * u, base[1] + out[1] * ln * u,
                                base[2] + ln * (0.55 * u - droop * u * u * 0.8)))
                    ws.append(0.075 * math.sin(math.pi * min(1.0, 0.15 + u * 0.9)) + 0.004)
                side = norm(cross(out, (0, 0, 1)))
                up = norm(cross(side, out))
                obs.append(strip("Leaf", pts, ws, (side, up), brown if rnd.random() < 0.35 else leaf, col,
                                 thick=0.003 if high else 0.006))
            if high:
                # the tassel at the top
                for k in range(5):
                    b = a + k * 1.3
                    tip = (p2[0] + math.cos(b) * 0.09, p2[1] + math.sin(b) * 0.09, p2[2] + rnd.uniform(0.05, 0.16))
                    obs.append(K.wire("Tassel", [p2, ((p2[0] + tip[0]) / 2, (p2[1] + tip[1]) / 2, tip[2] + 0.02), tip],
                                      0.004, husk, res=4, bevel_res=1, col=col))
        # the twine round the waist, wrapped twice, with its knot
        for dz in (-0.03, 0.03):
            pts = [(math.cos(k / 16 * math.tau) * 0.125, math.sin(k / 16 * math.tau) * 0.125, tie_z + dz)
                   for k in range(16)]
            obs.append(K.wire("Twine", pts, 0.012, twine, closed=True, res=4 if high else 2, bevel_res=2 if high else 0,
                              col=col))
        obs.append(K.sphere("Knot", 0.028, at=(0.125, -0.02, tie_z), m=twine, seg=10 if high else 6, col=col))
        # three ears of corn tucked into the twine, husks peeled back
        for e, (ang, mat_k) in enumerate(((-1.9, kernel), (-1.35, red), (-2.45, kernel))):
            cx, cy = math.cos(ang) * 0.16, math.sin(ang) * 0.16
            cz = tie_z + 0.05 + e * 0.04
            lean = 0.35 + e * 0.1
            ear = K.lathe("Ear", [(0.0, -0.12), (0.03, -0.11), (0.042, -0.05), (0.043, 0.04), (0.035, 0.1),
                                  (0.0, 0.13)], seg=16 if high else 8, m=mat_k, col=col)
            ear.location = (cx, cy, cz)
            ear.rotation_euler = (math.sin(ang) * -lean, math.cos(ang) * lean, 0)
            obs.append(ear)
            if high:
                for row in range(14):
                    ra = row / 14 * math.tau
                    for k in range(16):
                        z = -0.1 + k * 0.0135
                        rr = 0.043 if -0.05 < z < 0.04 else 0.036
                        kb = K.sphere("Kernel", 0.0085, at=(math.cos(ra) * rr, math.sin(ra) * rr, z), m=mat_k, seg=6,
                                      col=col)
                        kb.parent = ear
            for h_ in range(3 if high else 2):
                ha = ang + (h_ - 1) * 0.9
                base = (cx, cy, cz - 0.1)
                out = norm((math.cos(ha), math.sin(ha), -0.4))
                pts = [base, (base[0] + out[0] * 0.08, base[1] + out[1] * 0.08, base[2] - 0.02),
                       (base[0] + out[0] * 0.15, base[1] + out[1] * 0.15, base[2] - 0.1)]
                side = norm(cross(out, (0, 0, 1)))
                up = norm(cross(side, out))
                obs.append(strip("Husk", pts, [0.06, 0.07, 0.02], (side, up), husk, col, thick=0.004))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the fire engine
TRUCK_W = 2.4
TRUCK_L = 5.5
WHEEL_R = 0.48
FRONT = -TRUCK_L / 2          # Blender -Y is the front (Godot +Z)
CAB_BACK = -1.05


def fire_truck():
    red = K.mat("Truck Red", (0.85, 0.1, 0.1), rough=0.28, pits=0.05, bump=0.02)
    chrome = K.mat("Truck Chrome", (0.86, 0.86, 0.88), rough=0.15, metal=1.0)
    alum = K.mat("Truck Diamond Plate", (0.72, 0.73, 0.75), rough=0.35, metal=1.0, pits=0.4, bump=0.3)
    tyre = K.mat("Tyre", (0.08, 0.08, 0.09), rough=0.9, bump=0.2)
    black = K.mat("Truck Black", (0.1, 0.1, 0.11), rough=0.6)
    glass = K.mat("Truck Glass", (0.25, 0.35, 0.42), rough=0.08)
    gold = K.mat("Truck Gold", (0.95, 0.75, 0.25), rough=0.3, metal=1.0)
    white = K.mat("Truck White", (0.95, 0.95, 0.94), rough=0.4)
    head = K.mat("Headlight", (1.0, 0.97, 0.88), rough=0.1, emit=2.0, emit_rgb=(1.0, 0.95, 0.8))
    beacon = K.mat("Beacon", (1.0, 0.2, 0.15), rough=0.2, emit=2.5, emit_rgb=(1.0, 0.15, 0.1))
    amber = K.mat("Beacon Amber", (1.0, 0.6, 0.1), rough=0.2, emit=1.5, emit_rgb=(1.0, 0.55, 0.1))
    hose = K.mat("Hose", (0.85, 0.85, 0.8), rough=0.7, bump=0.15)
    ladder = K.mat("Ladder", (0.85, 0.85, 0.88), rough=0.3, metal=1.0)

    def build(col, high):
        obs = []
        bev = 0.03 if high else 0
        hw = TRUCK_W / 2 - 0.02
        # the chassis rails and the body behind the cab: lockers each side, a flat top for the ladder
        obs.append(K.box("Chassis", (1.1, TRUCK_L - 0.3, 0.25), at=(0, 0, 0.55), m=black, col=col))
        body_y0, body_y1 = CAB_BACK + 0.05, TRUCK_L / 2
        obs.append(K.box("Body", (TRUCK_W - 0.04, body_y1 - body_y0, 1.5), at=(0, (body_y0 + body_y1) / 2, 1.4),
                         m=red, bevel=bev, col=col))
        # the cab, a little taller, with its windscreen raked back
        cab_top = 2.75
        outline = [(FRONT, 0.6), (CAB_BACK, 0.6), (CAB_BACK, cab_top), (FRONT + 0.45, cab_top),
                   (FRONT + 0.02, 1.95), (FRONT, 1.85)]
        verts = [(-hw, y, z) for (y, z) in outline] + [(hw, y, z) for (y, z) in outline]
        n = len(outline)
        faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
        for i in range(n):
            j = (i + 1) % n
            faces.append([i, j, n + j, n + i])
        cab = mesh_from("Cab", verts, faces, red, col)
        if high:
            bv = cab.modifiers.new("Bevel", "BEVEL")
            bv.width = 0.04
            bv.segments = 3
            bv.limit_method = "ANGLE"
        obs.append(cab)
        # windscreen and side windows (just proud of the cab)
        wy = (FRONT + 0.02 + FRONT + 0.45) / 2
        ang = math.atan2(0.43, cab_top - 1.95)
        obs.append(K.box("Windscreen", (TRUCK_W - 0.3, 0.02, 0.78), at=(0, wy - 0.012, (1.95 + cab_top) / 2 + 0.02),
                         rot=(-ang, 0, 0), m=glass, col=col))
        for sx in (-1, 1):
            obs.append(K.box("Side Window", (0.02, 0.75, 0.6), at=(sx * (hw + 0.005), FRONT + 0.85, 2.25), m=glass,
                             col=col))
            obs.append(K.box("Rear Window", (0.02, 0.45, 0.5), at=(sx * (hw + 0.005), CAB_BACK - 0.35, 2.3),
                             m=glass, col=col))
            # the door handle, the step and the mirror
            obs.append(K.box("Handle", (0.03, 0.14, 0.03), at=(sx * (hw + 0.02), FRONT + 1.15, 1.75), m=chrome,
                             col=col))
            obs.append(K.box("Cab Step", (0.22, 0.6, 0.05), at=(sx * (hw + 0.06), FRONT + 0.85, 0.75), m=alum,
                             col=col))
            obs.append(K.box("Mirror Arm", (0.25, 0.03, 0.03), at=(sx * (hw + 0.12), FRONT + 0.5, 2.15), m=chrome,
                             col=col))
            obs.append(K.box("Mirror", (0.05, 0.12, 0.32), at=(sx * (hw + 0.26), FRONT + 0.5, 2.1), m=black,
                             bevel=0.01 if high else 0, col=col))
        # the front: bumper, grille, headlights and a crest
        obs.append(K.box("Bumper", (TRUCK_W + 0.1, 0.22, 0.25), at=(0, FRONT - 0.08, 0.62), m=chrome,
                         bevel=0.03 if high else 0, col=col))
        obs.append(K.box("Grille", (1.3, 0.04, 0.7), at=(0, FRONT - 0.01, 1.2), m=chrome, col=col))
        if high:
            for k in range(11):
                obs.append(K.box("Grille Bar", (0.035, 0.03, 0.62), at=(-0.6 + k * 0.12, FRONT - 0.035, 1.2),
                                 m=black, col=col))
        for sx in (-1, 1):
            obs.append(K.cyl("Headlight", 0.13, 0.05, at=(sx * 0.88, FRONT - 0.02, 1.2), rot=(math.pi / 2, 0, 0),
                             m=head, seg=20 if high else 10, col=col))
            obs.append(K.cyl("Headlight Rim", 0.15, 0.04, at=(sx * 0.88, FRONT - 0.005, 1.2),
                             rot=(math.pi / 2, 0, 0), m=chrome, seg=20 if high else 10, col=col))
            obs.append(K.box("Indicator", (0.14, 0.03, 0.08), at=(sx * 0.88, FRONT - 0.02, 0.95), m=amber, col=col))
        obs.append(K.cyl("Crest", 0.12, 0.02, at=(0, FRONT - 0.04, 1.68), rot=(math.pi / 2, 0, 0), m=gold,
                         seg=16 if high else 8, col=col))
        # the light bar on the roof, and beacons on the body's back corners
        obs.append(K.box("Light Bar Base", (1.6, 0.25, 0.06), at=(0, FRONT + 0.75, cab_top + 0.03), m=black, col=col))
        for k in range(5):
            m = beacon if k != 2 else amber
            obs.append(K.box("Light Bar", (0.28, 0.22, 0.12), at=(-0.62 + k * 0.31, FRONT + 0.75, cab_top + 0.12), m=m,
                             bevel=0.02 if high else 0, col=col))
        for sx in (-1, 1):
            obs.append(K.cyl("Beacon", 0.08, 0.12, at=(sx * 1.0, body_y1 - 0.15, 2.2), m=beacon, seg=12 if high else 6,
                             col=col))
            obs.append(K.box("Tail Light", (0.2, 0.03, 0.12), at=(sx * 0.9, body_y1 + 0.01, 0.95), m=beacon, col=col))
        # gold stripe along each side, and the lockers: roll-up doors with chrome handles
        for sx in (-1, 1):
            obs.append(K.box("Stripe", (0.012, TRUCK_L - 0.2, 0.09), at=(sx * (TRUCK_W / 2 + 0.002), 0.05, 1.05),
                             m=gold, col=col))
            obs.append(K.box("Stripe White", (0.012, TRUCK_L - 0.2, 0.03), at=(sx * (TRUCK_W / 2 + 0.002), 0.05, 0.97),
                             m=white, col=col))
            for k in range(3):
                y0 = body_y0 + 0.3 + k * 1.15
                obs.append(K.box("Locker", (0.02, 1.0, 1.0), at=(sx * (TRUCK_W / 2 - 0.005), y0 + 0.5, 1.6), m=alum,
                                 col=col))
                if high:
                    for s in range(16):
                        obs.append(K.box("Slat", (0.012, 0.98, 0.012), at=(sx * (TRUCK_W / 2 + 0.008), y0 + 0.5,
                                                                            1.12 + s * 0.06), m=chrome, col=col))
                obs.append(K.box("Locker Handle", (0.04, 0.4, 0.04), at=(sx * (TRUCK_W / 2 + 0.02), y0 + 0.5, 1.15),
                                 m=chrome, col=col))
        # the rear: a step of diamond plate, the hose reel and grab rails
        obs.append(K.box("Rear Step", (TRUCK_W - 0.1, 0.35, 0.08), at=(0, body_y1 + 0.17, 0.62), m=alum, col=col))
        reel = K.cyl("Hose Reel", 0.42, 1.2, at=(0, body_y1 - 0.55, 2.4), rot=(0, math.pi / 2, 0), m=hose,
                     seg=24 if high else 10, col=col)
        obs.append(reel)
        for sx in (-0.62, 0.62):
            obs.append(K.cyl("Reel Disc", 0.5, 0.04, at=(sx, body_y1 - 0.55, 2.4), rot=(0, math.pi / 2, 0), m=red,
                             seg=24 if high else 10, col=col))
        if high:
            for k in range(9):
                obs.append(K.wire("Hose Wrap", [(math.cos(a) * 0.0 + (-0.55 + k * 0.137),
                                                 body_y1 - 0.55 + math.cos(a) * 0.43, 2.4 + math.sin(a) * 0.43)
                                                for a in [i / 16 * math.tau for i in range(16)]], 0.03, hose,
                                  closed=True, res=4, bevel_res=2, col=col))
            for sx in (-1, 1):
                obs.append(K.wire("Grab Rail", [(sx * 1.15, body_y1 + 0.02, 1.0), (sx * 1.17, body_y1 + 0.06, 1.5),
                                                (sx * 1.15, body_y1 + 0.02, 2.0)], 0.02, chrome, res=6, bevel_res=2,
                                  col=col))
        # the ladder on top
        lz = 2.2
        for sx in (-0.45, 0.45):
            obs.append(K.box("Ladder Rail", (0.06, 4.2, 0.1), at=(sx, (body_y0 + body_y1) / 2 - 0.2, lz + 0.1),
                             m=ladder, col=col))
        for k in range(14 if high else 7):
            y = body_y0 + 0.1 + k * (4.0 / (13 if high else 6))
            obs.append(K.cyl("Rung", 0.022, 0.9, at=(0, y - 0.1, lz + 0.1), rot=(0, math.pi / 2, 0), m=ladder,
                             seg=8 if high else 4, col=col))
        for y in (body_y0 + 0.3, body_y1 - 1.3):
            obs.append(K.box("Ladder Rack", (1.2, 0.08, 0.1), at=(0, y, lz - 0.02), m=black, col=col))
        # wheels: tyres with treads, red rims and a chrome hub; mudguards over them
        for sx in (-1.25, 1.25):
            for sy in (-1.6, 1.8):
                t = K.lathe("Tyre", [(0.0, -0.17), (0.3, -0.175), (WHEEL_R - 0.04, -0.175), (WHEEL_R, -0.13),
                                     (WHEEL_R, 0.13), (WHEEL_R - 0.04, 0.175), (0.3, 0.175), (0.0, 0.17)],
                            seg=32 if high else 14, m=tyre, col=col)
                t.location = (sx, sy, WHEEL_R)
                t.rotation_euler = (0, math.pi / 2, 0)
                obs.append(t)
                side = 1 if sx > 0 else -1
                obs.append(K.cyl("Rim", 0.27, 0.02, at=(sx + side * 0.17, sy, WHEEL_R), rot=(0, math.pi / 2, 0),
                                 m=red, seg=24 if high else 10, col=col))
                obs.append(K.cyl("Hub", 0.11, 0.06, at=(sx + side * 0.19, sy, WHEEL_R), rot=(0, math.pi / 2, 0),
                                 m=chrome, seg=16 if high else 8, col=col))
                if high:
                    for k in range(36):
                        a = k / 36 * math.tau
                        obs.append(K.box("Tread", (0.32, 0.05, 0.03),
                                         at=(sx, sy + math.cos(a) * WHEEL_R, WHEEL_R + math.sin(a) * WHEEL_R),
                                         rot=(a, 0, 0), m=tyre, col=col))
                    for k in range(8):
                        a = k / 8 * math.tau
                        obs.append(K.cyl("Lug", 0.018, 0.03, at=(sx + side * 0.22, sy + math.cos(a) * 0.075,
                                                                  WHEEL_R + math.sin(a) * 0.075),
                                         rot=(0, math.pi / 2, 0), m=chrome, seg=6, col=col))
                obs.append(K.box("Mudguard", (0.4, 1.15, 0.05), at=(sx * 0.98, sy, WHEEL_R * 2 + 0.06), m=black,
                                 col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the rowing boat
BOAT_L = 3.8
BEAM = 1.45
DEPTH = 0.55
SHEER = 0.28          # the gunwale's height in the middle; it rises to the bow and stern


def hull_point(t, u, inset=0.0):
    """t from -1 (bow, Blender -Y = Godot +Z) to 1 (stern), u from 0 (one gunwale) through 0.5 (the keel) to 1."""
    bow = t < 0
    tt = abs(t)
    half = BEAM / 2 * ((1 - tt ** 2.2) ** 0.55 if bow else 1 - 0.45 * tt ** 2.0)
    half = max(half - inset, 0.006)
    top = SHEER + 0.11 * tt ** 2
    depth = max(DEPTH * (1 - 0.35 * tt ** 2) - inset, 0.02)
    ang = u * math.pi
    x = math.cos(ang) * half
    z = top - depth * math.sin(ang) ** 0.75
    return (x, t * BOAT_L / 2, z)


def hull_mesh(name, m_out, m_in, col, nt, nu, high):
    """The hull as one shell: the outside, the inside (a plank's width in) and the rim joining them along the top
    and across the transom."""
    bm = bmesh.new()
    th = 0.035
    outer = [[bm.verts.new(hull_point(-1 + 2 * i / nt, j / nu)) for j in range(nu + 1)] for i in range(nt + 1)]
    inner = [[bm.verts.new(hull_point(-1 + 2 * i / nt, j / nu, th)) for j in range(nu + 1)] for i in range(nt + 1)]
    faces_out, faces_in = [], []
    for i in range(nt):
        for j in range(nu):
            faces_out.append(bm.faces.new((outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j])))
            faces_in.append(bm.faces.new((inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], inner[i][j + 1])))
    for i in range(nt):
        for j in (0, nu):
            faces_out.append(bm.faces.new((outer[i][j], outer[i + 1][j], inner[i + 1][j], inner[i][j])))
    for j in range(nu):
        faces_out.append(bm.faces.new((outer[nt][j], outer[nt][j + 1], inner[nt][j + 1], inner[nt][j])))
        faces_out.append(bm.faces.new((outer[0][j], inner[0][j], inner[0][j + 1], outer[0][j + 1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in faces_in:
        f.material_index = 1
    ob = K._obj(name, bm, m_out, True, col)
    ob.data.materials.append(m_in)
    return ob


def rowing_boat():
    paint = K.mat("Boat Red", (0.7, 0.2, 0.15), rough=0.5, pits=0.15, wear=0.3, bump=0.05)
    wood = K.mat("Boat Wood", (0.62, 0.45, 0.3), rough=0.75, grain=(12.0, 0.3), pits=0.1, bump=0.12)
    trim = K.mat("Boat Trim", (0.95, 0.93, 0.86), rough=0.5, wear=0.3)
    brass = K.mat("Boat Brass", (0.78, 0.62, 0.32), rough=0.3, metal=1.0, pits=0.1)
    rope = K.mat("Boat Rope", (0.86, 0.78, 0.6), rough=0.9, bump=0.3)
    oar = K.mat("Oar Wood", (0.75, 0.58, 0.38), rough=0.6, grain=(14.0, 0.25))

    def build(col, high):
        obs = []
        obs.append(hull_mesh("Hull", paint, wood, col, 28 if high else 12, 16 if high else 8, high))
        # the gunwale: a rubbing strip all along the top, both sides
        steps = 30 if high else 10
        for side in (0.0, 1.0):
            pts = [hull_point(-1 + 2 * i / steps, side, -0.012) for i in range(steps + 1)]
            pts = [(p[0], p[1], p[2] + 0.005) for p in pts]
            obs.append(K.wire("Gunwale", pts, 0.028, trim, res=4 if high else 1, bevel_res=2 if high else 0, col=col))
        if high:
            # clinker planks: a lip at each plank's lower edge on the outside
            for u in (0.08, 0.17, 0.26, 0.35, 0.43, 0.57, 0.65, 0.74, 0.83, 0.92):
                pts = [hull_point(-1 + 2 * i / 30, u, -0.006) for i in range(31)]
                obs.append(K.wire("Strake", pts, 0.009, paint, res=3, bevel_res=1, col=col))
            # ribs inside
            for i in range(1, 12):
                t = -0.85 + i * 1.7 / 12
                pts = [hull_point(t, j / 12, 0.045) for j in range(13)]
                obs.append(K.wire("Rib", pts, 0.016, wood, res=3, bevel_res=1, col=col))
            # floorboards
            for k in range(-2, 3):
                obs.append(K.box("Floorboard", (0.11, 2.2, 0.02), at=(k * 0.13, 0.2, SHEER - DEPTH + 0.1), m=wood,
                                 bevel=0.004, col=col))
            # a white stripe at the waterline
            pts = [hull_point(-1 + 2 * i / 30, 0.22, -0.004) for i in range(31)]
            pts2 = [hull_point(-1 + 2 * i / 30, 0.78, -0.004) for i in range(31)]
            obs.append(K.wire("Stripe", pts, 0.012, trim, res=3, bevel_res=1, col=col))
            obs.append(K.wire("Stripe", pts2, 0.012, trim, res=3, bevel_res=1, col=col))
        # the thwarts (seats) and the stern seat
        for t, wdt in ((-0.25, 0.22), (0.25, 0.22), (0.78, 0.4)):
            hx = hull_point(t, 0.0, 0.03)[0]
            z = SHEER - 0.13
            obs.append(K.box("Thwart", (hx * 2 - 0.04, wdt, 0.04), at=(0, t * BOAT_L / 2, z), m=wood,
                             bevel=0.008 if high else 0, col=col))
        # oarlocks and the oars, shipped inside along the seats
        for sx in (-1, 1):
            p = hull_point(0.25, 0.0 if sx > 0 else 1.0)
            obs.append(K.cyl("Oarlock", 0.025, 0.1, at=(p[0], p[1], p[2] + 0.06), m=brass, seg=8, col=col))
            ox = sx * 0.25
            obs.append(K.cyl("Oar", 0.025, 2.4, at=(ox, 0.15, SHEER - 0.06), rot=(math.pi / 2, 0, sx * 0.05), m=oar,
                             seg=10 if high else 6, col=col))
            obs.append(K.box("Oar Blade", (0.15, 0.55, 0.018), at=(ox + sx * 0.05, 1.55, SHEER - 0.06),
                             rot=(0, 0, sx * 0.05), m=oar, bevel=0.01 if high else 0, col=col))
        # the bow: a brass ring and the painter rope coiled on the bow seat, its end over the side
        bp = hull_point(-0.97, 0.5)
        obs.append(K.wire("Bow Ring", [(0, -BOAT_L / 2 + 0.02 + 0.06 * math.cos(a), SHEER + 0.15 + 0.06 * math.sin(a))
                                      for a in [i / 12 * math.tau for i in range(12)]], 0.01, brass, closed=True,
                          res=3, bevel_res=1, col=col))
        coil = []
        for i in range(120 if high else 40):
            s = i / (119 if high else 39)
            a = s * 5 * math.tau
            r = 0.16 - s * 0.1
            coil.append((math.cos(a) * r, -0.25 * BOAT_L / 2 + math.sin(a) * r, SHEER - 0.08 + s * 0.04))
        obs.append(K.wire("Rope Coil", coil, 0.016, rope, res=2, bevel_res=2 if high else 0, col=col))
        obs.append(K.wire("Painter", [(0, -BOAT_L / 2 + 0.02, SHEER + 0.12), (0.2, -BOAT_L / 2 - 0.25, SHEER + 0.1),
                                      (0.5, -BOAT_L / 2 - 0.55, SHEER - 0.05)], 0.014, rope, res=8,
                          bevel_res=2 if high else 0, col=col))
        _ = bp
        return obs

    return build(HIGH, True), build(LOW, False)


BUILD = {"hay_bale": (hay_bale, 1024), "corn_sheaf": (corn_sheaf, 1024), "fire_truck": (fire_truck, 2048),
         "rowing_boat": (rowing_boat, 1024)}
fn, size = BUILD[KIND]
high, low = fn()
hi_tris = K.tri_count(list(HIGH.all_objects))
prop = K.join(NAME, low)
lo_tris = K.tri_count([prop])
K.uv_unwrap(prop, margin=0.006)
emit = KIND == "fire_truck"
maps = K.bake(prop, list(HIGH.all_objects), size=size, name=NAME, extrusion=0.02 if KIND == "corn_sheaf" else 0.03,
              ray=0.06 if KIND == "corn_sheaf" else 0.1,
              maps=(["ao", "color", "rough", "metal"] if KIND == "corn_sheaf" else ["normal", "ao", "color", "rough", "metal"])
              + (["emit"] if emit else []))
if KIND == "corn_sheaf":
    # The sheaf's stalks are thin wires, so the high stalks never quite line up with the low ones: their baked normals
    # came out tipped every which way and its shadowed middle baked nearly black, which made the whole sheaf look dark
    # in game. It keeps its flat normals and only a gentle share of the shadow.
    import numpy as np
    a = np.empty(size * size * 4, dtype=np.float32)
    maps["ao"].pixels.foreach_get(a)
    a[0::4] = 0.6 + 0.4 * a[0::4]
    a[1::4] = a[0::4]
    a[2::4] = a[0::4]
    maps["ao"].pixels.foreach_set(a)
K.finish(prop, maps, size, NAME, emit_strength=1.5 if emit else 1.0)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([prop], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

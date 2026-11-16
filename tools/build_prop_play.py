# Stars Hollow's playground and Main Street's flower planters, built the detailed way (tools/bake_kit.py; 16 Nov 2026,
# batch five of Hayden's "give everything the baked in details"). Each HIGH version is baked onto a LOW one, which is
# what the game draws.
#
# Sizes match the builder's pieces (tools/build_earth.gd _playground, _main_street) so the swap
# (scripts/detail_props.gd) puts each exactly where the old one was. Blender's X is Godot's X, Blender's -Y is
# Godot's +Z and Blender's Z is Godot's Y.
#   slide_tower  the slide: four posts round a 1.8 m deck 2 m up, a pointed roof, a ladder up the back (Godot -Z)
#                and the yellow chute down to Godot +Z, standing on the origin (the builder's "Slide" node).
#   swing_set    an A-frame 3.6 m wide with a top bar 2.75 m up and two swings at x -0.8 and 0.8 ("Swings").
#   sandbox      a 3 m wooden frame round a 2.8 m bed of sand, a sandcastle, a bucket and a spade.
#   mum_planter  a stone planter 0.9 x 3.2 m and 0.55 high with four mounds of chrysanthemums along it (orange, red,
#                yellow, purple from Godot -Z to +Z, as the builder had them), standing on the origin.
# Colours are the builder's (sRGB). Collisions stay the builder's.
#
#   python tools/build_prop_play.py "<out>.glb" <slide_tower|swing_set|sandbox|mum_planter> [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

KINDS = ["slide_tower", "swing_set", "sandbox", "mum_planter"]
KIND = next((a for a in sys.argv if a in KINDS), "slide_tower")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

POST_RGB = (0.25, 0.55, 0.8)
DECK_RGB = (0.95, 0.5, 0.2)
ROOF_RGB = (0.85, 0.2, 0.25)
YELLOW_RGB = (0.98, 0.82, 0.2)


def mesh_from(name, verts, faces, m, col, smooth=False):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, smooth, col)


def rod(name, a, b, r, m, col, seg=12, r2=None):
    """A round bar from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ob = K.cyl(name, r, d.length, at=(a + b) / 2, seg=seg, m=m, col=col, r2=r2)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return ob


def bolt(name, at, axis, m, col):
    """A round bolt head sticking out along axis ('x', 'y' or 'z' with a sign)."""
    s = 1 if axis[0] == "+" else -1
    ax = axis[1]
    rot = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[ax]
    off = {"x": (s * 0.01, 0, 0), "y": (0, s * 0.01, 0), "z": (0, 0, s * 0.01)}[ax]
    return K.cyl(name, 0.022, 0.02, at=(at[0] + off[0], at[1] + off[1], at[2] + off[2]), rot=rot, seg=8, m=m,
                 col=col)


# ================================================================ the slide tower
DECK_Z = 2.0          # the deck's middle (the builder's solid box, 0.15 thick)
POST_H = 3.4


def chute_path(t):
    """The chute's middle line (Blender y, z) from the deck's front edge (t 0) down to the run-out (t 1): the builder's
    straight chute went from (y -0.79, z 2.06) to (y -4.01, z 0.04). This one curves: steep in the middle, a little
    run-out flat at the bottom."""
    p0, p1, p2, p3 = (-0.85, 2.07), (-1.7, 2.0), (-3.0, 0.35), (-4.2, 0.32)
    u = 1 - t
    y = u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0]
    z = u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]
    return y, z


def chute_mesh(name, m, col, n_along, n_round):
    """A U-shaped trough along chute_path, 0.9 m across with lips 0.3 m up, given a skin 0.04 thick."""
    half, depth, thick = 0.45, 0.22, 0.04
    rings = []
    for i in range(n_along + 1):
        t = i / n_along
        y, z = chute_path(t)
        # the profile across: up the left lip, round the bottom, up the right lip (inner then outer skin)
        inner, outer = [], []
        for k in range(n_round + 1):
            a = math.pi * k / n_round                       # 0 left lip .. pi right lip
            x = -math.cos(a) * half
            h = depth * (1 - math.sin(a)) + 0.08 * (k == 0 or k == n_round)
            inner.append((x, y, z + h))
            outer.append((x * (1 + thick / half), y, z + h - thick * math.sin(a) - thick * 0.4))
        rings.append(inner + list(reversed(outer)))
    verts = [v for r in rings for v in r]
    w = len(rings[0])
    faces = []
    for i in range(n_along):
        for k in range(w):
            a, b = i * w + k, i * w + (k + 1) % w
            faces.append([a, b, b + w, a + w])
    faces.append(list(range(w)))
    faces.append(list(range(n_along * w + w - 1, n_along * w - 1, -1)))
    return mesh_from(name, verts, faces, m, col, smooth=True)


def slide_tower():
    post = K.mat("Play Post", POST_RGB, rough=0.45, pits=0.15, bump=0.02)
    deck = K.mat("Play Deck", DECK_RGB, rough=0.55, pits=0.2, bump=0.05)
    roof = K.mat("Play Roof", ROOF_RGB, rough=0.45, bump=0.03)
    yellow = K.mat("Slide Yellow", YELLOW_RGB, rough=0.22, wear=0.15)
    steel = K.mat("Play Steel", (0.75, 0.76, 0.78), rough=0.3, metal=1.0, pits=0.2)
    green = K.mat("Play Green", (0.3, 0.75, 0.4), rough=0.45, bump=0.03)
    black = K.mat("Play Black", (0.12, 0.12, 0.13), rough=0.7)

    def build(col, high):
        obs = []
        sg = 20 if high else 8
        # the four posts, with round caps and a foot plate each
        for sx in (-0.8, 0.8):
            for sy in (-0.8, 0.8):
                obs.append(K.cyl("Post", 0.08, POST_H, at=(sx, sy, POST_H / 2), seg=sg, m=post, col=col))
                obs.append(K.sphere("Post Cap", 0.1, at=(sx, sy, POST_H), seg=sg, m=yellow, col=col))
                obs.append(K.cyl("Foot", 0.15, 0.05, at=(sx, sy, 0.025), seg=sg, m=steel, col=col))
                if high:
                    for k in range(4):
                        a = k * math.pi / 2 + math.pi / 4
                        obs.append(bolt("Foot Bolt", (sx + math.cos(a) * 0.11, sy + math.sin(a) * 0.11, 0.05), "+z",
                                        steel, col))
        # the deck: a frame round planks (the high one with gaps and bolts)
        obs.append(K.box("Deck Frame", (1.8, 1.8, 0.08), at=(0, 0, DECK_Z - 0.035), m=deck, col=col,
                         bevel=0.01 if high else 0))
        if high:
            for k in range(9):
                obs.append(K.box("Plank", (1.66, 0.17, 0.04), at=(0, -0.76 + k * 0.19, DECK_Z + 0.025), m=deck,
                                 bevel=0.008, col=col))
                for sx in (-0.7, 0.7):
                    obs.append(bolt("Plank Bolt", (sx, -0.76 + k * 0.19, DECK_Z + 0.045), "+z", steel, col))
        else:
            obs.append(K.box("Planks", (1.66, 1.7, 0.04), at=(0, 0, DECK_Z + 0.025), m=deck, col=col))
        # side panels on the two open sides, a green one with round port holes on one side
        for sx in (-1, 1):
            obs.append(K.box("Side Panel", (0.04, 1.5, 0.55), at=(sx * 0.82, 0, DECK_Z + 0.4),
                             m=green if sx < 0 else post, bevel=0.015 if high else 0, col=col))
            obs.append(rod("Side Rail", (sx * 0.84, 0.8, DECK_Z + 0.85), (sx * 0.84, -0.8, DECK_Z + 0.85), 0.035,
                           yellow, col, seg=sg))
            if high:
                for k in (-0.4, 0.4):
                    obs.append(K.cyl("Port Hole", 0.15, 0.06, at=(sx * 0.82, k, DECK_Z + 0.42),
                                     rot=(0, math.pi / 2, 0), seg=24, m=black, col=col))
                    obs.append(K.cyl("Port Ring", 0.18, 0.05, at=(sx * 0.845, k, DECK_Z + 0.42),
                                     rot=(0, math.pi / 2, 0), seg=24, m=yellow, col=col))
        # a steering wheel on the green side, for playing ship
        obs.append(K.cyl("Wheel Hub", 0.05, 0.12, at=(-0.9, 0.0, DECK_Z + 0.55), rot=(0, math.pi / 2, 0), seg=sg,
                         m=yellow, col=col))
        ring = [(-0.95, 0.24 * math.cos(a), DECK_Z + 0.55 + 0.24 * math.sin(a))
                for a in [i / 16 * math.tau for i in range(16)]]
        obs.append(K.wire("Wheel", ring, 0.025, roof, closed=True, res=4 if high else 2, bevel_res=2 if high else 0,
                          col=col))
        if high:
            for k in range(6):
                a = k / 6 * math.tau
                obs.append(rod("Spoke", (-0.95, 0, DECK_Z + 0.55),
                               (-0.95, 0.24 * math.cos(a), DECK_Z + 0.55 + 0.24 * math.sin(a)), 0.012, yellow, col,
                               seg=6))
        # the pointed roof: four sides, a lip round the bottom and a ball on top
        rf = K.cyl("Roof", 1.4, 0.9, at=(0, 0, 3.8), seg=4, r2=0.0, m=roof, col=col, smooth=False)
        rf.rotation_euler = (0, 0, math.pi / 4)
        obs.append(rf)
        obs.append(K.sphere("Roof Ball", 0.12, at=(0, 0, 4.27), seg=sg, m=yellow, col=col))
        if high:
            for k in range(4):                      # ridge trims down the four corners
                a = k * math.pi / 2
                obs.append(rod("Ridge", (0, 0, 4.24), (1.38 * math.cos(a) * 0.98, 1.38 * math.sin(a) * 0.98, 3.37),
                               0.025, yellow, col, seg=8))
            for k in range(4):                      # a strip of shingle lines on each face
                for j in range(5):
                    z = 3.45 + j * 0.15
                    w = (1.4 - (z - 3.35) / 0.9 * 1.4) * math.sqrt(2) * 0.95
                    a = k * math.pi / 2 + math.pi / 4
                    off = (1.4 - (z - 3.35) / 0.9 * 1.4) * math.cos(math.pi / 4) + 0.012
                    obs.append(K.box("Shingle Line", (w, 0.02, 0.025), at=(math.cos(a) * off, math.sin(a) * off, z),
                                     rot=(math.atan2(0.9, 1.0) * 0.0, 0, a + math.pi / 2), m=roof, col=col))
        # the ladder up the back (Blender +Y): rungs between the back posts, rails outside them
        for k in range(6):
            z = 0.3 + k * 0.33
            obs.append(rod("Rung", (-0.72, 0.9, z), (0.72, 0.9, z), 0.03, steel, col, seg=sg))
        for sx in (-0.75, 0.75):
            obs.append(rod("Ladder Rail", (sx, 0.92, 0.0), (sx, 0.92, 2.05), 0.03, yellow, col, seg=sg))
        for sx in (-0.72, 0.72):
            obs.append(rod("Hand Loop", (sx, 0.9, DECK_Z + 0.05), (sx, 0.9, DECK_Z + 0.8), 0.03, yellow, col,
                           seg=sg))
        # the chute down the front, with a hood at the top and two legs under its run-out
        obs.append(chute_mesh("Chute", yellow, col, 40 if high else 14, 16 if high else 6))
        obs.append(rod("Hood Bar", (-0.47, -0.85, DECK_Z + 0.4), (0.47, -0.85, DECK_Z + 0.4), 0.035, post, col,
                       seg=sg))
        for sx in (-0.47, 0.47):
            obs.append(rod("Hood Post", (sx, -0.85, DECK_Z + 0.05), (sx, -0.85, DECK_Z + 0.4), 0.035, post, col,
                           seg=sg))
            obs.append(rod("Chute Leg", (sx * 0.7, -3.7, 0.0), (sx * 0.7, -3.7, 0.3), 0.04, steel, col, seg=sg))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the swing set
BAR_Z = 2.75


def swing_set():
    post = K.mat("Play Post", POST_RGB, rough=0.45, pits=0.15, bump=0.02)
    steel = K.mat("Chain", (0.7, 0.7, 0.72), rough=0.3, metal=1.0, pits=0.2)
    seat = K.mat("Swing Seat", (0.85, 0.2, 0.25), rough=0.7, bump=0.05)
    yellow = K.mat("Slide Yellow", YELLOW_RGB, rough=0.3)

    def build(col, high):
        obs = []
        sg = 20 if high else 8
        for sx in (-1, 1):
            for sy in (-1, 1):
                obs.append(rod("Leg", (sx * 1.85, sy * 0.95, 0.0), (sx * 1.8, sy * 0.06, BAR_Z - 0.02), 0.06, post,
                               col, seg=sg))
                obs.append(K.cyl("Leg Foot", 0.11, 0.05, at=(sx * 1.85, sy * 0.95, 0.025), seg=sg, m=steel, col=col))
            # the cross brace and the top clamp each end
            obs.append(rod("Brace", (sx * 1.835, 0.6, 0.9), (sx * 1.835, -0.6, 0.9), 0.04, post, col, seg=sg))
            obs.append(K.box("Clamp", (0.16, 0.2, 0.2), at=(sx * 1.8, 0, BAR_Z), m=yellow, bevel=0.02 if high else 0,
                             col=col))
        obs.append(rod("Top Bar", (-1.95, 0, BAR_Z), (1.95, 0, BAR_Z), 0.07, post, col, seg=sg))
        for cx in (-0.8, 0.8):
            for rx in (-0.22, 0.22):
                x = cx + rx
                obs.append(K.box("Hanger", (0.05, 0.16, 0.06), at=(x, 0, BAR_Z - 0.06), m=steel, col=col))
                if high:
                    # a real chain of links, each turned a quarter from the last
                    n = 30
                    for k in range(n):
                        z = BAR_Z - 0.1 - (k + 0.5) * (BAR_Z - 0.1 - 0.68) / n
                        ring = [(0.012 * math.cos(a) if k % 2 else 0.0, 0.0 if k % 2 else 0.012 * math.cos(a),
                                 0.03 * math.sin(a)) for a in [i / 10 * math.tau for i in range(10)]]
                        obs.append(K.wire("Link", [(x + p[0], p[1], z + p[2]) for p in ring], 0.005, steel,
                                          closed=True, res=2, bevel_res=1, col=col))
                else:
                    obs.append(rod("Chain", (x, 0, BAR_Z - 0.1), (x, 0, 0.66), 0.016, steel, col, seg=4))
            # the seat: a curved rubber strap with metal ends
            pts = []
            for k in range(13 if high else 7):
                t = k / (12 if high else 6)
                xx = cx - 0.28 + t * 0.56
                pts.append((xx, 0.0, 0.62 + 0.06 * (2 * t - 1) ** 2))
            verts, faces = [], []
            for p in pts:
                for sy, sz in ((-0.13, 0.02), (0.13, 0.02), (0.13, -0.02), (-0.13, -0.02)):
                    verts.append((p[0], p[1] + sy, p[2] + sz))
            for i in range(len(pts) - 1):
                for k in range(4):
                    a, b = i * 4 + k, i * 4 + (k + 1) % 4
                    faces.append([a, b, b + 4, a + 4])
            faces.append([0, 1, 2, 3])
            e = (len(pts) - 1) * 4
            faces.append([e + 3, e + 2, e + 1, e + 0])
            obs.append(mesh_from("Seat", verts, faces, seat, col, smooth=high))
            for sx in (-1, 1):
                obs.append(K.box("Seat End", (0.04, 0.28, 0.06), at=(cx + sx * 0.26, 0, 0.68), m=steel, col=col))
            if high:
                for k in range(8):                     # grip ribs across the seat
                    t = (k + 0.5) / 8
                    xx = cx - 0.24 + t * 0.48
                    obs.append(K.box("Rib", (0.012, 0.24, 0.012), at=(xx, 0, 0.62 + 0.06 * (2 * t - 1) ** 2 + 0.024),
                                     m=seat, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the sandbox
def sand_h(x, y, high):
    """The sand's top (Blender z): a lumpy bed 0.2 up, dug down near the bucket and heaped where the castle is."""
    h = 0.2 + 0.025 * math.sin(x * 3.1 + 0.4) * math.cos(y * 2.7) + 0.015 * math.sin(x * 7.0 + y * 5.0)
    h += 0.05 * math.exp(-((x + 0.55) ** 2 + (y - 0.45) ** 2) / 0.15)          # the castle's mound
    h -= 0.06 * math.exp(-((x - 0.2) ** 2 + (y + 0.55) ** 2) / 0.05)           # a dug hole
    return h


def sandbox():
    wood = K.mat("Bench Wood", (0.5, 0.33, 0.2), rough=0.75, grain=(18, 0.25), wear=0.2)
    sand = K.mat("Sand", (0.9, 0.8, 0.55), rough=0.95, bump=0.35, pits=0.2)
    bucket = K.mat("Bucket", (0.3, 0.6, 0.95), rough=0.35)
    spade = K.mat("Spade", (0.95, 0.35, 0.3), rough=0.35)
    handle = K.mat("Bucket Handle", (0.95, 0.85, 0.2), rough=0.35)

    def build(col, high):
        obs = []
        # the frame: two boards high each side, with a corner seat over each corner
        for sx, sy, sz in ((0, -1.5, (3.0, 0.2, 0.3)), (0, 1.5, (3.0, 0.2, 0.3)), (-1.5, 0, (0.2, 3.0, 0.3)),
                           (1.5, 0, (0.2, 3.0, 0.3))):
            if high:
                for k in range(2):
                    obs.append(K.box("Board", (sz[0] - 0.005, sz[1] - 0.005, 0.145),
                                     at=(sx, -sy, 0.075 + k * 0.15), m=wood, bevel=0.012, col=col))
            else:
                obs.append(K.box("Board", sz, at=(sx, -sy, 0.15), m=wood, col=col))
        for cx in (-1, 1):
            for cy in (-1, 1):
                verts = [(cx * 1.6, cy * 1.6, 0.3), (cx * 1.0, cy * 1.6, 0.3), (cx * 1.6, cy * 1.0, 0.3),
                         (cx * 1.6, cy * 1.6, 0.34), (cx * 1.0, cy * 1.6, 0.34), (cx * 1.6, cy * 1.0, 0.34)]
                faces = [[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]]
                obs.append(mesh_from("Corner Seat", verts, faces, wood, col))
                if high:
                    obs.append(bolt("Seat Bolt", (cx * 1.48, cy * 1.48, 0.34), "+z",
                                    K.mat("Bolt", (0.6, 0.6, 0.62), rough=0.4, metal=1.0), col))
        # the sand: a grid following sand_h
        n = 40 if high else 10
        verts, faces = [], []
        for i in range(n + 1):
            for j in range(n + 1):
                x = -1.4 + 2.8 * i / n
                y = -1.4 + 2.8 * j / n
                verts.append((x, y, sand_h(x, y, high)))
        for i in range(n):
            for j in range(n):
                a = i * (n + 1) + j
                faces.append([a, a + n + 1, a + n + 2, a + 1])
        obs.append(mesh_from("Sand", verts, faces, sand, col, smooth=True))
        # a sandcastle: a big tower and four little ones on the mound
        cx, cy = -0.55, 0.45
        base = sand_h(cx, cy, high)
        obs.append(K.lathe("Castle", [(0.2, base - 0.05), (0.2, base + 0.08), (0.14, base + 0.2), (0.0, base + 0.2)],
                           seg=24 if high else 8, m=sand, at=(cx, cy, 0), col=col))
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            tx, ty = cx + math.cos(a) * 0.2, cy + math.sin(a) * 0.2
            obs.append(K.lathe("Turret", [(0.065, base - 0.03), (0.055, base + 0.12), (0.0, base + 0.12)],
                               seg=16 if high else 6, m=sand, at=(tx, ty, 0), col=col))
            if high:
                for b in range(4):
                    bb = b * math.pi / 2
                    obs.append(K.box("Merlon", (0.02, 0.02, 0.025),
                                     at=(tx + math.cos(bb) * 0.045, ty + math.sin(bb) * 0.045, base + 0.13),
                                     m=sand, col=col))
        # the bucket (the builder's, at Godot (0.6, 0.31, 0.3)), with its handle, and a spade stuck in the sand
        obs.append(K.lathe("Bucket", [(0.0, 0.2), (0.11, 0.2), (0.15, 0.42), (0.135, 0.42), (0.1, 0.22),
                                      (0.0, 0.22)] if high else
                           [(0.0, 0.2), (0.11, 0.2), (0.15, 0.42), (0.0, 0.42)],
                           seg=24 if high else 10, m=bucket, at=(0.6, -0.3, 0), col=col))
        obs.append(K.wire("Bucket Handle", [(0.6 - 0.15, -0.3, 0.4), (0.6, -0.3, 0.58), (0.6 + 0.15, -0.3, 0.4)],
                          0.008, handle, res=8, bevel_res=2 if high else 0, col=col))
        obs.append(K.box("Spade Blade", (0.12, 0.02, 0.16), at=(0.95, 0.6, 0.27), rot=(0.25, 0, 0.4), m=spade,
                         bevel=0.01 if high else 0, col=col))
        obs.append(rod("Spade Handle", (0.95, 0.62, 0.34), (0.95 - 0.04, 0.72, 0.62), 0.015, spade, col,
                       seg=10 if high else 5))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the flower planter
MUMS = [(0.95, 0.55, 0.15), (0.75, 0.2, 0.25), (0.95, 0.8, 0.25), (0.6, 0.3, 0.6)]
PL_W, PL_L, PL_H = 0.9, 3.2, 0.55


def mum_planter():
    stone = K.mat("Planter Stone", (0.62, 0.6, 0.58), rough=0.85, pits=0.5, bump=0.25, wear=0.2)
    soil = K.mat("Planter Soil", (0.25, 0.18, 0.12), rough=0.95, bump=0.3)
    leaf = K.mat("Mum Leaves", (0.2, 0.38, 0.17), rough=0.75, bump=0.2)
    heads = [K.mat("Mums %d" % k, c, rough=0.7, bump=0.15) for k, c in enumerate(MUMS)]
    eyes = [K.mat("Mum Eye %d" % k, tuple(v * 0.7 for v in c), rough=0.7) for k, c in enumerate(MUMS)]

    def build(col, high):
        obs = []
        # the planter: a plinth, the box with a sunk panel each side and a rim round the top
        obs.append(K.box("Plinth", (PL_W + 0.06, PL_L + 0.06, 0.08), at=(0, 0, 0.04), m=stone,
                         bevel=0.015 if high else 0, col=col))
        obs.append(K.box("Box", (PL_W, PL_L, PL_H - 0.12), at=(0, 0, 0.08 + (PL_H - 0.12) / 2 - 0.02), m=stone,
                         col=col))
        obs.append(K.box("Rim", (PL_W + 0.08, PL_L + 0.08, 0.08), at=(0, 0, PL_H - 0.04), m=stone,
                         bevel=0.02 if high else 0, col=col))
        if high:
            for sx in (-1, 1):
                for k in range(3):
                    obs.append(K.box("Panel", (0.02, 0.85, 0.22), at=(sx * (PL_W / 2 + 0.005), -1.0 + k * 1.0, 0.28),
                                     m=stone, bevel=0.01, col=col))
            for sy in (-1, 1):
                obs.append(K.box("End Panel", (0.6, 0.02, 0.22), at=(0, sy * (PL_L / 2 + 0.005), 0.28), m=stone,
                                 bevel=0.01, col=col))
        obs.append(K.box("Soil", (PL_W - 0.1, PL_L - 0.1, 0.04), at=(0, 0, PL_H - 0.03), m=soil, col=col))
        # four mounds of mums: the builder's balls were 0.35 across, 0.7 up, from Godot z -1.2 (orange) to +1.2
        for k in range(4):
            cy = 1.2 - k * 0.8                           # Godot z -1.2 + k * 0.8 is Blender y 1.2 - k * 0.8
            cz = 0.62
            obs.append(K.sphere("Mound", 0.36, at=(0, cy, cz), seg=24 if high else 10, scale=(1.05, 1.05, 0.75),
                                m=leaf if high else heads[k], col=col))
            if high:
                rnd = random.Random(700 + k)
                for f in range(110):
                    # flower heads over the top of the mound, a few leaves showing between them low down
                    a = rnd.uniform(0, math.tau)
                    up = rnd.uniform(0.15, 1.0) ** 0.7
                    r = math.sqrt(1 - up * up)
                    x, y, z = r * math.cos(a) * 0.378, r * math.sin(a) * 0.378, up * 0.27
                    nrm = Vector((r * math.cos(a), r * math.sin(a), up * 1.3)).normalized()
                    p = Vector((x, cy + y, cz + z)) + nrm * 0.02
                    hd = K.sphere("Head", rnd.uniform(0.04, 0.055), at=p, seg=10, scale=(1, 1, 0.45), m=heads[k],
                                  col=col)
                    hd.rotation_mode = "QUATERNION"
                    hd.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(nrm)
                    obs.append(hd)
                    obs.append(K.sphere("Eye", 0.013, at=p + nrm * 0.022, seg=6, m=eyes[k], col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


BUILD = {"slide_tower": (slide_tower, 2048), "swing_set": (swing_set, 1024), "sandbox": (sandbox, 1024),
         "mum_planter": (mum_planter, 1024)}
fn, size = BUILD[KIND]
high, low = fn()
hi_tris = K.tri_count(list(HIGH.all_objects))
prop = K.join(NAME, low)
lo_tris = K.tri_count([prop])
K.uv_unwrap(prop, margin=0.006)
maps = K.bake(prop, list(HIGH.all_objects), size=size, name=NAME, extrusion=0.03,
              ray=0.12 if KIND == "mum_planter" else 0.08,
              maps=(["normal", "ao", "color", "rough", "metal"] if KIND != "swing_set"
                    else ["ao", "color", "rough", "metal"]))
K.finish(prop, maps, size, NAME)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([prop], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

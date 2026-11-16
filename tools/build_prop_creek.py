# Stars Hollow's bridges, Willow Pond's dock and the coin telescope on Lookout Hill, built the detailed way
# (tools/bake_kit.py; 16 Nov 2026, batch six of Hayden's "give everything the baked in details"). Each HIGH version is
# baked onto a LOW one, which is what the game draws.
#
# Sizes match the builder's pieces (tools/build_earth.gd _covered_bridge, _footbridge, _dock, _lookout_hill) so the
# swap (scripts/detail_props.gd) puts each exactly where the old one was. Blender's X is Godot's X, Blender's -Y is
# Godot's +Z and Blender's Z is Godot's Y.
#   covered_bridge  the old red covered bridge: a 15 x 6.6 m plank deck (top 0.15 m up), board-and-batten walls 14 m
#                   long along X at Godot z +-3.3 with three windows each, Burr arches and posts inside, tie beams,
#                   a shingle roof 8 m wide from 3.55 to 5.35 m, and a white trim board over each end (its sign is the
#                   builder's label, just in front of it). Centred on the origin (the builder's "Covered Bridge" node).
#   footbridge      the creek's footbridge: a 2.4 x 10.4 m plank deck along Godot Z, top 0.245 m up, on two arched
#                   stringers, with kick rails (the builder's grind rails stay over it).
#   dock            Willow Pond's dock: a 12.5 x 2.6 m deck along X, top 0.25 m up, on ten piles (x every 3.125 m,
#                   Godot z +-1.2) reaching 2.6 m down, with cleats, a coil of rope and a ladder at the pond end (-X).
#   telescope       the coin telescope: a post, a coin box and a pair of big binocular barrels looking towards
#                   Godot +Z and a little up, standing on the origin.
# Colours are the builder's (sRGB). Collisions stay the builder's.
#
#   python tools/build_prop_creek.py "<out>.glb" <covered_bridge|footbridge|dock|telescope> [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

KINDS = ["covered_bridge", "footbridge", "dock", "telescope"]
KIND = next((a for a in sys.argv if a in KINDS), "covered_bridge")
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
    """A round bar from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ob = K.cyl(name, r, d.length, at=(a + b) / 2, seg=seg, m=m, col=col, r2=r2)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return ob


def beam(name, a, b, w, h, m, col, bevel=0.0):
    """A square timber from point a to point b, w wide and h deep (h measured in the plane the beam turns in)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ob = K.box(name, (w, h, d.length), at=(a + b) / 2, m=m, bevel=bevel, col=col)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return ob


def bolt(name, at, axis, m, col, r=0.022):
    """A round bolt head sticking out along axis ('+x', '-y', ...)."""
    s = 1 if axis[0] == "+" else -1
    ax = axis[1]
    rot = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[ax]
    off = {"x": (s * 0.01, 0, 0), "y": (0, s * 0.01, 0), "z": (0, 0, s * 0.01)}[ax]
    return K.cyl(name, r, 0.02, at=(at[0] + off[0], at[1] + off[1], at[2] + off[2]), rot=rot, seg=8, m=m, col=col)


def planks(obs, name, x0, x1, y0, y1, z_top, thick, along, width, m, col, rnd, gap=0.012):
    """Deck planks laid across the deck: along='y' gives planks running along Y side by side in X."""
    if along == "y":
        n = max(1, round((x1 - x0) / width))
        w = (x1 - x0) / n
        for k in range(n):
            dz = rnd.uniform(-0.004, 0.004)
            obs.append(K.box(name, (w - gap, y1 - y0 - rnd.uniform(0, 0.03), thick),
                             at=(x0 + w * (k + 0.5), (y0 + y1) / 2 + rnd.uniform(-0.01, 0.01), z_top - thick / 2 + dz),
                             rot=(rnd.uniform(-0.004, 0.004), 0, rnd.uniform(-0.003, 0.003)), m=m, bevel=0.008,
                             col=col))
    else:
        n = max(1, round((y1 - y0) / width))
        w = (y1 - y0) / n
        for k in range(n):
            dz = rnd.uniform(-0.004, 0.004)
            obs.append(K.box(name, (x1 - x0 - rnd.uniform(0, 0.03), w - gap, thick),
                             at=((x0 + x1) / 2 + rnd.uniform(-0.01, 0.01), y0 + w * (k + 0.5), z_top - thick / 2 + dz),
                             rot=(0, rnd.uniform(-0.004, 0.004), rnd.uniform(-0.003, 0.003)), m=m, bevel=0.008,
                             col=col))


# ================================================================ the covered bridge
CB_L = 14.0            # the walls' length (the builder's BRIDGE_X span)
CB_W = 6.0             # the street's width; the walls stand at +-(CB_W / 2 + 0.3)
CB_WALL_Y = CB_W / 2 + 0.3
CB_TOP = 3.55          # the walls' top (the builder's walls: 3.4 high, centred 1.85 up)
CB_RIDGE = 5.35        # the roof's ridge (the builder's prism: 1.8 high, centred 4.45 up)
CB_EAVE = 4.0          # the roof's half width (8 m across)


def covered_bridge():
    red = K.mat("Barn Red", (0.62, 0.14, 0.12), rough=0.85, grain=(10, 0.08), wear=0.08, pits=0.15)
    white = K.mat("Barn Trim", (0.96, 0.94, 0.9), rough=0.7, wear=0.05, pits=0.1)
    plank = K.mat("Barn Planks", (0.55, 0.38, 0.24), rough=0.9, grain=(16, 0.3), pits=0.2, bump=0.05)
    timber = K.mat("Bridge Timber", (0.42, 0.29, 0.18), rough=0.85, grain=(12, 0.3), wear=0.1)
    roof = K.mat("Barn Roof", (0.24, 0.22, 0.24), rough=0.85, pits=0.25, bump=0.06)
    glass = K.mat("Bridge Window", (0.15, 0.1, 0.08), rough=0.9)
    iron = K.mat("Bridge Iron", (0.18, 0.18, 0.2), rough=0.5, metal=1.0, pits=0.3)

    def roof_z(y):
        return CB_RIDGE - (CB_RIDGE - CB_TOP) * abs(y) / CB_EAVE

    def build(col, high):
        obs = []
        rnd = random.Random(61)
        # the deck: planks across the road on a deck slab (the builder's 15 x 6.6, top at 0.15)
        if high:
            obs.append(K.box("Deck Under", (CB_L + 1.0, CB_W + 0.6, 0.24), at=(0, 0, -0.12), m=timber, col=col))
            planks(obs, "Deck Plank", -(CB_L + 1.0) / 2, (CB_L + 1.0) / 2, -(CB_W + 0.6) / 2, (CB_W + 0.6) / 2,
                   0.15, 0.06, "y", 0.3, plank, col, rnd)
            # two worn wheel tracks of lengthways running boards
            for ty in (-1.4, -0.6, 0.6, 1.4):
                obs.append(K.box("Runner", (CB_L + 0.9, 0.34, 0.03), at=(0, ty, 0.165), m=plank, bevel=0.006,
                                 col=col))
        else:
            obs.append(K.box("Deck", (CB_L + 1.0, CB_W + 0.6, 0.3), at=(0, 0, 0.0), m=plank, col=col))
        # wheel guards along the foot of each wall
        for sy in (-1, 1):
            obs.append(K.box("Wheel Guard", (CB_L, 0.16, 0.2), at=(0, sy * (CB_WALL_Y - 0.18), 0.25), m=timber,
                             bevel=0.01 if high else 0, col=col))
        # the walls: red boards with battens outside, three windows each, Burr arches and posts inside
        win_x = [-CB_L / 3, 0.0, CB_L / 3]
        for sy in (-1, 1):
            y = sy * CB_WALL_Y
            obs.append(K.box("Wall", (CB_L, 0.2, CB_TOP - 0.15), at=(0, y, (CB_TOP + 0.15) / 2), m=red, col=col))
            if high:
                n = int(CB_L / 0.32)
                for k in range(n + 1):
                    bx = -CB_L / 2 + 0.16 + k * (CB_L - 0.32) / n
                    if any(abs(bx - wx) < 0.78 for wx in win_x):
                        # battens stop under and over a window
                        obs.append(K.box("Batten", (0.06, 0.04, 2.1 - 0.15 - 0.05),
                                         at=(bx, y + sy * 0.12, (0.15 + 2.05) / 2), m=red, bevel=0.008, col=col))
                        obs.append(K.box("Batten", (0.06, 0.04, CB_TOP - 2.75),
                                         at=(bx, y + sy * 0.12, (2.75 + CB_TOP) / 2), m=red, bevel=0.008, col=col))
                    else:
                        obs.append(K.box("Batten", (0.06, 0.04, CB_TOP - 0.2), at=(bx, y + sy * 0.12, CB_TOP / 2 + 0.07),
                                         m=red, bevel=0.008, col=col))
                # a white sill board along the bottom and a trim board along the top
                obs.append(K.box("Sill Board", (CB_L + 0.04, 0.05, 0.18), at=(0, y + sy * 0.155, 0.27), m=white,
                                 bevel=0.008, col=col))
                obs.append(K.box("Top Board", (CB_L + 0.04, 0.05, 0.16), at=(0, y + sy * 0.155, CB_TOP - 0.1),
                                 m=white, bevel=0.008, col=col))
            for wx in win_x:
                # the window: a dark pane in a white frame, outside and in, with a little sill
                obs.append(K.box("Window", (1.4, 0.24, 0.6), at=(wx, y, 2.4), m=glass, col=col))
                for side in (1, -1):
                    fy = y + sy * side * 0.13
                    if high:
                        obs.append(K.box("Frame Top", (1.56, 0.04, 0.08), at=(wx, fy, 2.74), m=white, bevel=0.006,
                                         col=col))
                        obs.append(K.box("Frame Bottom", (1.56, 0.04, 0.08), at=(wx, fy, 2.06), m=white, bevel=0.006,
                                         col=col))
                        for ex in (-0.74, 0.74):
                            obs.append(K.box("Frame Side", (0.08, 0.04, 0.76), at=(wx + ex, fy, 2.4), m=white,
                                             bevel=0.006, col=col))
                        obs.append(K.box("Mullion", (0.04, 0.03, 0.6), at=(wx, fy, 2.4), m=white, col=col))
                    else:
                        obs.append(K.box("Frame", (1.56, 0.04, 0.76), at=(wx, fy, 2.4), m=white, col=col))
                obs.append(K.box("Window Sill", (1.7, 0.14, 0.05), at=(wx, y + sy * 0.18, 2.03), m=white,
                                 bevel=0.008 if high else 0, col=col))
            # inside: posts every third of the way and a Burr arch bolted across them
            iy = y - sy * 0.14
            for k in range(7):
                px = -CB_L / 2 + 0.15 + k * (CB_L - 0.3) / 6
                obs.append(K.box("Post", (0.22, 0.1, CB_TOP - 0.3), at=(px, iy, (CB_TOP + 0.3) / 2), m=timber,
                                 bevel=0.01 if high else 0, col=col))
            seg = 24 if high else 10
            pts = []
            for k in range(seg + 1):
                t = k / seg
                ax = -CB_L / 2 + 0.1 + t * (CB_L - 0.2)
                az = 0.45 + 2.55 * math.sin(math.pi * t)
                pts.append((ax, az))
            for k in range(seg):
                a = (pts[k][0], iy - sy * 0.09, pts[k][1])
                b = (pts[k + 1][0], iy - sy * 0.09, pts[k + 1][1])
                obs.append(beam("Arch", a, b, 0.09, 0.28, timber, col))
            # a lower and an upper chord
            obs.append(K.box("Chord", (CB_L, 0.08, 0.2), at=(0, iy - sy * 0.09, 0.55), m=timber, col=col))
            obs.append(K.box("Chord", (CB_L, 0.08, 0.2), at=(0, iy - sy * 0.09, CB_TOP - 0.25), m=timber, col=col))
            if high:
                for k in range(7):
                    px = -CB_L / 2 + 0.15 + k * (CB_L - 0.3) / 6
                    t = (px - (-CB_L / 2 + 0.1)) / (CB_L - 0.2)
                    az = 0.45 + 2.55 * math.sin(math.pi * t)
                    for bz in (0.55, az, CB_TOP - 0.25):
                        obs.append(bolt("Arch Bolt", (px, iy - sy * 0.13, bz), "-y" if sy > 0 else "+y", iron, col,
                                        r=0.03))
        # tie beams across over the road, and rafters up to the ridge
        for k in range(7):
            px = -CB_L / 2 + 0.15 + k * (CB_L - 0.3) / 6
            obs.append(K.box("Tie Beam", (0.2, CB_W + 0.4, 0.22), at=(px, 0, CB_TOP - 0.05), m=timber,
                             bevel=0.01 if high else 0, col=col))
            for sy in (-1, 1):
                a = (px, sy * (CB_W / 2 + 0.25), CB_TOP + 0.02)
                b = (px, 0.0, CB_RIDGE - 0.26)
                obs.append(beam("Rafter", a, b, 0.14, 0.18, timber, col))
            obs.append(beam("King Post", (px, 0, CB_TOP + 0.06), (px, 0, CB_RIDGE - 0.25), 0.14, 0.14, timber, col))
        # the roof: two slopes with an underside of boards (the builder's prism, 8 m across, 15.2 long)
        rl = CB_L + 1.2
        verts = [(-rl / 2, -CB_EAVE, CB_TOP), (rl / 2, -CB_EAVE, CB_TOP), (rl / 2, 0, CB_RIDGE),
                 (-rl / 2, 0, CB_RIDGE), (-rl / 2, CB_EAVE, CB_TOP), (rl / 2, CB_EAVE, CB_TOP)]
        under = [(x, y, z - 0.12) for x, y, z in verts]
        allv = verts + under
        faces = [[0, 1, 2, 3], [3, 2, 5, 4], [6 + 0, 6 + 3, 6 + 2, 6 + 1], [6 + 3, 6 + 4, 6 + 5, 6 + 2],
                 [0, 6, 6 + 1, 1], [4, 5, 6 + 5, 6 + 4], [0, 3, 6 + 3, 6], [3, 4, 6 + 4, 6 + 3],
                 [1, 6 + 1, 6 + 2, 2], [2, 6 + 2, 6 + 5, 5]]
        obs.append(mesh_from("Roof", allv, faces, roof, col))
        if high:
            # rows of shingles down each slope, staggered, each a little crooked
            slope = math.hypot(CB_EAVE, CB_RIDGE - CB_TOP)
            ang = math.atan2(CB_RIDGE - CB_TOP, CB_EAVE)
            rows = int(slope / 0.22)
            for sy in (-1, 1):
                for r in range(rows):
                    d = (r + 0.5) * slope / rows                   # from the eave up the slope
                    yy = sy * (CB_EAVE - d * math.cos(ang))
                    zz = CB_TOP + d * math.sin(ang) + 0.02
                    n = int(rl / 0.38)
                    off = 0.19 if r % 2 else 0.0
                    for k in range(n):
                        sx = -rl / 2 + 0.19 + off + k * 0.38
                        if sx > rl / 2 - 0.12:
                            continue
                        obs.append(K.box("Shingle", (0.36, 0.28, 0.025),
                                         at=(sx + rnd.uniform(-0.02, 0.02), yy, zz + rnd.uniform(0, 0.008)),
                                         rot=(sy * ang + rnd.uniform(-0.03, 0.03), 0, rnd.uniform(-0.03, 0.03)),
                                         m=roof, col=col))
            obs.append(K.box("Ridge Cap", (rl + 0.05, 0.3, 0.08), at=(0, 0, CB_RIDGE + 0.02), m=roof, bevel=0.02,
                             col=col))
        # each end: red boards up into the gable, the white trim board under the builder's sign, a beam across
        for sx in (-1, 1):
            gx = sx * (CB_L / 2 + 0.02)
            gv = [(gx, -CB_W / 2 - 0.4, CB_TOP + 0.02), (gx, CB_W / 2 + 0.4, CB_TOP + 0.02),
                  (gx, 0, CB_RIDGE - 0.14)]
            g2 = [(gx - sx * 0.12, y, z) for _, y, z in gv]
            obs.append(mesh_from("Gable", gv + g2, [[0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]],
                                 red, col))
            if high:
                for k in range(-9, 10):
                    by = k * 0.38
                    top = roof_z(by) - 0.16
                    if top > CB_TOP + 0.1:
                        obs.append(K.box("Gable Batten", (0.04, 0.06, top - CB_TOP),
                                         at=(gx + sx * 0.02, by, (top + CB_TOP) / 2 + 0.02), m=red, col=col))
            obs.append(K.box("End Trim", (0.2, CB_W + 0.6, 0.7), at=(sx * (CB_L / 2 + 0.1), 0, 3.6), m=white,
                             bevel=0.015 if high else 0, col=col))
            # bargeboards along the roof's edge
            for sy in (-1, 1):
                a = (sx * (rl / 2 + 0.02), sy * (CB_EAVE + 0.02), CB_TOP - 0.1)
                b = (sx * (rl / 2 + 0.02), 0, CB_RIDGE - 0.02)
                obs.append(beam("Bargeboard", a, b, 0.05, 0.22, white, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the footbridge
FB_W, FB_L, FB_TOP = 2.4, 10.4, 0.245


def footbridge():
    wood = K.mat("Bridge Wood", (0.55, 0.38, 0.25), rough=0.85, grain=(16, 0.3), wear=0.15, pits=0.2)
    dark = K.mat("Bridge Beam", (0.42, 0.29, 0.19), rough=0.85, grain=(10, 0.25), wear=0.1)
    iron = K.mat("Bridge Iron", (0.18, 0.18, 0.2), rough=0.5, metal=1.0, pits=0.3)
    moss = K.mat("Bridge Moss", (0.3, 0.45, 0.2), rough=0.95, bump=0.3)

    def build(col, high):
        obs = []
        rnd = random.Random(62)
        # planks across the bridge (the deck runs along Blender Y)
        if high:
            planks(obs, "Plank", -FB_W / 2, FB_W / 2, -FB_L / 2, FB_L / 2, FB_TOP, 0.06, "x", 0.24, wood, col, rnd)
        else:
            obs.append(K.box("Deck", (FB_W, FB_L, 0.06), at=(0, 0, FB_TOP - 0.03), m=wood, col=col))
        # two stringers under it, arched a little, and the edge boards along each side
        seg = 16 if high else 6
        for sx in (-1, 1):
            x = sx * (FB_W / 2 - 0.25)
            pts = [(x, -FB_L / 2 + FB_L * k / seg, FB_TOP - 0.06 - 0.12 - 0.35 * math.sin(math.pi * k / seg)
                    * (1 - 0.0)) for k in range(seg + 1)]
            for k in range(seg):
                obs.append(beam("Stringer", pts[k], pts[k + 1], 0.16, 0.22, dark, col))
            obs.append(K.box("Edge Board", (0.08, FB_L, 0.2), at=(sx * (FB_W / 2 + 0.04), 0, FB_TOP - 0.08), m=dark,
                             bevel=0.01 if high else 0, col=col))
            # a kick rail along the deck's edge (the builder's grind rail runs over it)
            obs.append(K.box("Kick Rail", (0.1, FB_L - 0.2, 0.1), at=(sx * (FB_W / 2 - 0.08), 0, FB_TOP + 0.05),
                             m=dark, bevel=0.012 if high else 0, col=col))
            if high:
                for k in range(9):
                    yy = -FB_L / 2 + 0.6 + k * (FB_L - 1.2) / 8
                    obs.append(bolt("Rail Bolt", (sx * (FB_W / 2 - 0.08), yy, FB_TOP + 0.1), "+z", iron, col))
                    obs.append(bolt("Edge Bolt", (sx * (FB_W / 2 + 0.08), yy, FB_TOP - 0.08),
                                    "+x" if sx > 0 else "-x", iron, col))
        # cross beams under each end and the middle, and a stone sill at each bank
        for yy in (-FB_L / 2 + 0.4, 0.0, FB_L / 2 - 0.4):
            obs.append(K.box("Cross Beam", (FB_W, 0.16, 0.14), at=(0, yy, FB_TOP - 0.13), m=dark, col=col))
        if high:
            # a little moss at the ends where it meets the bank
            for sy in (-1, 1):
                for k in range(14):
                    obs.append(K.sphere("Moss", rnd.uniform(0.04, 0.09),
                                        at=(rnd.uniform(-FB_W / 2, FB_W / 2), sy * (FB_L / 2 - rnd.uniform(0, 0.25)),
                                            FB_TOP - 0.01), scale=(1, 1, 0.3), seg=8, m=moss, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the dock
DK_L, DK_W, DK_TOP = 12.5, 2.6, 0.25


def dock():
    wood = K.mat("Bridge Wood", (0.55, 0.38, 0.25), rough=0.85, grain=(16, 0.3), wear=0.15, pits=0.2)
    post = K.mat("Post Wood", (0.45, 0.32, 0.22), rough=0.85, grain=(8, 0.3), pits=0.3, bump=0.06)
    wet = K.mat("Pile Wet", (0.25, 0.22, 0.17), rough=0.5, bump=0.1)
    iron = K.mat("Dock Iron", (0.2, 0.2, 0.22), rough=0.45, metal=1.0, pits=0.35)
    rope = K.mat("Dock Rope", (0.78, 0.68, 0.5), rough=0.9, bump=0.2)

    def build(col, high):
        obs = []
        rnd = random.Random(63)
        # planks across (the deck runs along X), on bearers
        if high:
            planks(obs, "Plank", -DK_L / 2, DK_L / 2, -DK_W / 2, DK_W / 2, DK_TOP, 0.06, "y", 0.22, wood, col, rnd)
        else:
            obs.append(K.box("Deck", (DK_L, DK_W, 0.06), at=(0, 0, DK_TOP - 0.03), m=wood, col=col))
        for sy in (-1, 1):
            obs.append(K.box("Bearer", (DK_L, 0.12, 0.18), at=(0, sy * 1.2, DK_TOP - 0.15), m=post,
                             bevel=0.01 if high else 0, col=col))
            obs.append(K.box("Fascia", (DK_L, 0.05, 0.2), at=(0, sy * (DK_W / 2 + 0.025), DK_TOP - 0.09), m=wood,
                             bevel=0.008 if high else 0, col=col))
        # the piles: ten round ones, wet and dark low down, each sticking up a little as a post at the corners
        sg = 16 if high else 7
        for k in range(5):
            x = DK_L / 2 - k * DK_L / 4
            x = max(-DK_L / 2 + 0.15, min(DK_L / 2 - 0.15, x))
            for sy in (-1, 1):
                y = sy * 1.2
                corner = k in (0, 4)
                top = DK_TOP + (0.45 if corner else -0.08)
                obs.append(K.cyl("Pile", 0.13, top + 0.6, at=(x, y + sy * 0.12, (top - 0.6) / 2), seg=sg, m=post,
                                 col=col))
                obs.append(K.cyl("Pile Wet", 0.135, 2.0, at=(x, y + sy * 0.12, -0.6 - 1.0), seg=sg, m=wet, col=col))
                if corner:
                    obs.append(K.sphere("Pile Cap", 0.13, at=(x, y + sy * 0.12, top), seg=sg, scale=(1, 1, 0.4),
                                        m=post, col=col))
                if high:
                    for b in range(3):
                        obs.append(K.cyl("Pile Band", 0.14, 0.03, at=(x, y + sy * 0.12, -0.2 - b * 0.5), seg=sg,
                                         m=iron, col=col))
                    # barnacle-ish lumps where the water rises and falls
                    for n in range(6):
                        a = rnd.uniform(0, math.tau)
                        obs.append(K.sphere("Lump", rnd.uniform(0.02, 0.035),
                                            at=(x + math.cos(a) * 0.13, y + sy * 0.12 + math.sin(a) * 0.13,
                                                rnd.uniform(-0.5, -0.25)), seg=6, m=wet, col=col))
        # two cleats on each side, and a coil of rope by the shore end
        for cx in (-DK_L / 2 + 1.5, DK_L / 2 - 3.0):
            for sy in (-1, 1):
                cy = sy * (DK_W / 2 - 0.2)
                obs.append(K.box("Cleat Foot", (0.08, 0.06, 0.08), at=(cx, cy, DK_TOP + 0.04), m=iron, col=col))
                obs.append(K.box("Cleat Horn", (0.34, 0.06, 0.05), at=(cx, cy, DK_TOP + 0.1), m=iron,
                                 bevel=0.02 if high else 0, col=col))
        coil_c = (DK_L / 2 - 2.2, -0.55)
        if high:
            for r in range(4):
                pts = []
                for k in range(25):
                    a = k / 24 * math.tau
                    rr = 0.2 + r * 0.05
                    pts.append((coil_c[0] + math.cos(a) * rr, coil_c[1] + math.sin(a) * rr, DK_TOP + 0.03 + r * 0.004))
                obs.append(K.wire("Rope", pts, 0.022, rope, res=6, bevel_res=2, col=col))
        else:
            obs.append(K.cyl("Rope", 0.36, 0.05, at=(coil_c[0], coil_c[1], DK_TOP + 0.025), seg=10, m=rope, col=col))
        # a ladder down into the water at the pond end
        lx = -DK_L / 2 - 0.06
        for sy in (-0.3, 0.3):
            obs.append(K.box("Ladder Rail", (0.06, 0.06, 1.6), at=(lx, sy, DK_TOP - 0.55), m=iron,
                             bevel=0.01 if high else 0, col=col))
        for k in range(4):
            obs.append(rod("Rung", (lx, -0.3, DK_TOP - 0.15 - k * 0.32), (lx, 0.3, DK_TOP - 0.15 - k * 0.32), 0.018,
                           iron, col, seg=8 if high else 4))
        # the ladder's handles bent up over the deck
        for sy in (-0.3, 0.3):
            obs.append(K.wire("Handle", [(lx, sy, DK_TOP - 0.2), (lx - 0.05, sy, DK_TOP + 0.55), (lx + 0.25, sy, DK_TOP + 0.6),
                                         (lx + 0.35, sy, DK_TOP)], 0.025, iron, res=8, bevel_res=2 if high else 0,
                              col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the coin telescope
def telescope():
    green = K.mat("Scope Metal", (0.3, 0.5, 0.45), rough=0.4, metal=0.6, pits=0.25, wear=0.2)
    brass = K.mat("Scope Brass", (0.85, 0.65, 0.3), rough=0.3, metal=1.0, pits=0.15)
    glass = K.mat("Scope Glass", (0.1, 0.15, 0.2), rough=0.08, metal=0.3)
    black = K.mat("Scope Black", (0.08, 0.08, 0.09), rough=0.6)

    def build(col, high):
        obs = []
        sg = 28 if high else 10
        # a round foot, the post up to the head (the builder's: 1.1 high), a collar
        obs.append(K.lathe("Foot", [(0.0, 0.0), (0.24, 0.0), (0.24, 0.04), (0.16, 0.09), (0.09, 0.14), (0.0, 0.14)],
                           seg=sg, m=green, col=col))
        obs.append(K.lathe("Post", [(0.0, 0.1), (0.075, 0.1), (0.065, 1.0), (0.0, 1.0)], seg=sg, m=green,
                           flutes=8 if high else 0, flute_depth=0.008, flute_z=(0.2, 0.9), col=col))
        obs.append(K.cyl("Collar", 0.1, 0.06, at=(0, 0, 1.02), seg=sg, m=brass, col=col))
        if high:
            for k in range(6):
                a = k / 6 * math.tau
                obs.append(bolt("Foot Bolt", (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.04), "+z", brass, col, r=0.015))
        # the yoke and the head, tilted 21 degrees up, looking towards Blender -Y (Godot +Z)
        tilt = math.radians(21)
        hc = Vector((0, 0, 1.3))
        fwd = Vector((0, -math.cos(tilt), math.sin(tilt)))
        obs.append(K.box("Yoke", (0.42, 0.08, 0.08), at=(0, 0, 1.08), m=green, bevel=0.015 if high else 0, col=col))
        for sx in (-1, 1):
            obs.append(K.box("Yoke Arm", (0.05, 0.08, 0.26), at=(sx * 0.19, 0, 1.2), m=green,
                             bevel=0.012 if high else 0, col=col))
        body = K.box("Head", (0.34, 0.36, 0.24), at=hc, m=green, bevel=0.05 if high else 0, col=col)
        body.rotation_euler = (-tilt, 0, 0)
        obs.append(body)
        # a coin slot and a little plate on top
        if high:
            slot = K.box("Coin Slot", (0.06, 0.012, 0.03), at=hc + Vector((0, 0.05, 0.13)), m=black, col=col)
            slot.rotation_euler = (-tilt, 0, 0)
            obs.append(slot)
            plate = K.box("Coin Plate", (0.12, 0.08, 0.008), at=hc + Vector((0, 0.05, 0.122)), m=brass, col=col)
            plate.rotation_euler = (-tilt, 0, 0)
            obs.append(plate)
        side = Vector((1, 0, 0))
        for sx in (-1, 1):
            base = hc + side * sx * 0.095
            obs.append(rod("Barrel", base + fwd * 0.1, base + fwd * 0.42, 0.075, green, col, seg=sg, r2=0.09))
            obs.append(rod("Lens Ring", base + fwd * 0.41, base + fwd * 0.45, 0.095, brass, col, seg=sg))
            obs.append(rod("Lens", base + fwd * 0.445, base + fwd * 0.452, 0.08, glass, col, seg=sg))
            obs.append(rod("Eyepiece", base - fwd * 0.12, base - fwd * 0.26, 0.04, black, col, seg=sg, r2=0.05))
        # the hood over the eyepieces and a pair of handles to turn it by
        for sx in (-1, 1):
            obs.append(rod("Handle", hc + side * sx * 0.17, hc + side * sx * 0.32, 0.018, brass, col,
                           seg=10 if high else 5))
            obs.append(K.sphere("Knob", 0.035, at=hc + side * sx * 0.33, seg=12 if high else 6, m=brass, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


BUILD = {"covered_bridge": (covered_bridge, 2048), "footbridge": (footbridge, 1024), "dock": (dock, 1024),
         "telescope": (telescope, 512)}
fn, size = BUILD[KIND]
high, low = fn()
hi_tris = K.tri_count(list(HIGH.all_objects))
prop = K.join(NAME, low)
lo_tris = K.tri_count([prop])
K.uv_unwrap(prop, margin=0.004 if KIND == "covered_bridge" else 0.006)
maps = K.bake(prop, list(HIGH.all_objects), size=size, name=NAME, extrusion=0.03,
              ray=0.1 if KIND == "covered_bridge" else 0.08,
              maps=["normal", "ao", "color", "rough", "metal"])
K.finish(prop, maps, size, NAME)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([prop], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

# The town green's gazebo, built the detailed way (tools/bake_kit.py): a white Victorian bandstand with a planked
# deck on a lattice skirt, three steps, turned posts, railings full of turned balusters, gingerbread brackets and a
# carved frieze under the eaves, a bell-curved roof of scalloped shingles with capped ridges, a beadboard ceiling and
# a finial. The HIGH version is baked onto a LOW one, which is what the game draws.
#
# It keeps the old gazebo's size and every spot the game uses (tools/build_earth.gd _gazebo): the deck 4.4 m across
# the corners and 0.6 m up (its collision stays the builder's), the steps on the south (Godot +Z, Blender -Y), the
# eight posts 3.9 m out, railings 1 m high with the front open, and the eaves above the string of bulbs (4.5 m out,
# 3.2 to 3.35 m up), which stay the builder's along with the lights, the "Town Green" label and the pumpkins.
#
#   python tools/build_prop_gazebo.py "Godot Project/my-world/models/props/stars_hollow/gazebo.glb" [--blend] [--preview]

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402

OUT = K.out_path("gazebo.glb")
K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

PAINT = K.mat("Gazebo White", (0.93, 0.92, 0.88), rough=0.55, wear=0.05, bump=0.08)
TRIM = K.mat("Gazebo Trim", (0.36, 0.5, 0.42), rough=0.5, wear=0.08)          # a soft green on the trim
DECK = K.mat("Deck Boards", (0.55, 0.42, 0.3), rough=0.75, grain=(5.0, 0.3), bump=0.1)
SHINGLE = K.mat("Shingles", (0.45, 0.25, 0.22), rough=0.8, pits=0.15, bump=0.3)
GOLD = K.mat("Finial Gold", (0.8, 0.6, 0.25), rough=0.3, metal=1.0)

DECK_R, DECK_H = 4.4, 0.6
POST_R = 3.9
POST_TOP = 3.3
EAVE_R, EAVE_Z = 4.85, 3.42
APEX_Z = 5.45
RAIL_TOP = 1.4


def post_angle(k):
    # the builder's posts at Godot angle k*TAU/8 + PI/8 in the x/z plane; Blender's y is Godot's -z
    return -(k * math.tau / 8 + math.pi / 8)


def front(a):
    # the front (south, Godot +Z) is Blender -Y, at angle -PI/2: no railing there
    return abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < 0.5


def at(a, r, z):
    return (math.cos(a) * r, math.sin(a) * r, z)


def deck(col, high):
    obs = [K.lathe("Deck", [(0.0, 0.0), (DECK_R, 0.0), (DECK_R, DECK_H - 0.08), (DECK_R + 0.06, DECK_H - 0.06),
                            (DECK_R + 0.06, DECK_H), (0.0, DECK_H)], 8, PAINT, sides=8, smooth=False, col=col)]
    obs[0].rotation_euler[2] = math.pi / 8
    if high:
        # planks on top (thin boards with gaps), a lattice skirt round the sides
        for i in range(-21, 22):
            x = i * 0.2
            half = math.sqrt(max(0.0, (DECK_R * 0.97) ** 2 - x * x))
            if half > 0.1:
                obs.append(K.box("Plank", (0.18, half * 2 * 0.98, 0.02), at=(x, 0, DECK_H + 0.005), m=DECK, bevel=0.004,
                                 col=col))
        for k in range(8):
            a = k * math.tau / 8 + math.pi / 8 + math.tau / 16
            mid = at(a, DECK_R * math.cos(math.pi / 8) + 0.015, 0.28)
            side = 2 * DECK_R * math.sin(math.pi / 8) * 0.9
            for j in range(-6, 7):
                for sgn in (1, -1):
                    s = K.box("Lattice", (0.025, side * 0.16, 0.012), at=mid, m=TRIM, col=col,
                              rot=(sgn * math.pi / 4, 0, a))
                    # slide each strip along the face
                    t = j * side / 13
                    s.location = (mid[0] - math.sin(a) * t, mid[1] + math.cos(a) * t, 0.28)
                    obs.append(s)
    return obs


def steps(col):
    obs = []
    for k in range(3):
        h = DECK_H - (k + 1) * 0.2
        y = -(DECK_R * math.cos(math.pi / 8) + 0.15 + k * 0.3)
        obs.append(K.box("Step", (2.4, 0.32, 0.06), at=(0, y, h + 0.17), m=DECK, bevel=0.01, col=col))
        obs.append(K.box("Riser", (2.4, 0.04, 0.2), at=(0, y - 0.14, h + 0.07), m=PAINT, col=col))
    for sx in (-1.25, 1.25):
        obs.append(K.box("Stringer", (0.08, 0.95, 0.2), at=(sx, -(DECK_R * math.cos(math.pi / 8) + 0.45), 0.25), m=PAINT,
                         rot=(math.radians(-32), 0, 0), col=col))
    return obs


def post(col, a, high):
    seg = 32 if high else 8
    p = at(a, POST_R, 0)
    prof = [(0.0, DECK_H), (0.12, DECK_H), (0.12, 0.85), (0.1, 0.9), (0.075, 0.95)]
    if high:
        prof += [(0.08, 1.0), (0.065, 1.08), (0.07, 1.7), (0.085, 1.78), (0.07, 1.86), (0.065, 2.6), (0.08, 2.7),
                 (0.07, 2.78), (0.075, 3.0)]
    else:
        prof += [(0.07, 1.0), (0.068, 3.0)]
    prof += [(0.11, 3.05), (0.11, POST_TOP), (0.0, POST_TOP)]
    o = K.lathe("Post", prof, seg, PAINT, sides=4 if not high else 0, col=col)
    o.location = p
    return [o]


def railing(col, a0, a1, high):
    obs = []
    p0, p1 = at(a0, POST_R, 0), at(a1, POST_R, 0)
    mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
    length = math.dist(p0[:2], p1[:2]) - 0.2
    yaw = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
    obs.append(K.box("Top Rail", (length, 0.12, 0.06), at=(mid[0], mid[1], RAIL_TOP), m=PAINT, bevel=0.012 if high else 0,
                     rot=(0, 0, yaw), col=col))
    obs.append(K.box("Bottom Rail", (length, 0.09, 0.06), at=(mid[0], mid[1], DECK_H + 0.12), m=PAINT,
                     bevel=0.01 if high else 0, rot=(0, 0, yaw), col=col))
    n = 13
    for i in range(n):
        t = (i + 0.5) / n - 0.5
        x, y = mid[0] + math.cos(yaw) * t * length, mid[1] + math.sin(yaw) * t * length
        if high:
            prof = [(0.0, DECK_H + 0.15), (0.03, DECK_H + 0.15), (0.03, 0.85), (0.022, 0.88), (0.038, 1.0), (0.04, 1.1),
                    (0.022, 1.25), (0.025, RAIL_TOP - 0.03), (0.0, RAIL_TOP - 0.03)]
            o = K.lathe("Baluster", prof, 16, PAINT, col=col)
        else:
            o = K.lathe("Baluster", [(0.0, DECK_H + 0.15), (0.028, DECK_H + 0.15), (0.032, 1.0), (0.025, RAIL_TOP - 0.03),
                                     (0.0, RAIL_TOP - 0.03)], 5, PAINT, col=col)
        o.location = (x, y, 0)
        obs.append(o)
    return obs


def frieze(col, a0, a1, high):
    # a band under the eaves between two posts, with a scalloped edge and carved holes (gingerbread)
    obs = []
    p0, p1 = at(a0, POST_R, 0), at(a1, POST_R, 0)
    mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
    length = math.dist(p0[:2], p1[:2]) - 0.2
    yaw = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
    obs.append(K.box("Frieze", (length, 0.04, 0.2), at=(mid[0], mid[1], POST_TOP - 0.12), m=PAINT, rot=(0, 0, yaw),
                     col=col))
    if high:
        n = 9
        for i in range(n):
            t = (i + 0.5) / n - 0.5
            x, y = mid[0] + math.cos(yaw) * t * length, mid[1] + math.sin(yaw) * t * length
            # a carved round "hole": a dark-trimmed ring, and a scallop hanging below
            ring = K.lathe("Rosette", [(0.0, -0.012), (0.06, -0.012), (0.07, 0.0), (0.06, 0.012), (0.0, 0.012)], 24,
                           TRIM, col=col)
            ring.location = (x - math.sin(yaw) * 0.025, y + math.cos(yaw) * 0.025, POST_TOP - 0.12)
            ring.rotation_euler = (math.pi / 2, 0, yaw)
            obs.append(ring)
            sc = K.sphere("Scallop", 0.075, at=(x, y, POST_TOP - 0.22), m=PAINT, seg=16, scale=(1, 0.25, 0.55), col=col)
            sc.rotation_euler = (0, 0, yaw)
            obs.append(sc)
            sp = K.lathe("Spindle", [(0.0, 3.36), (0.012, 3.36), (0.02, 3.38), (0.012, 3.41), (0.0, 3.41)], 8, PAINT,
                         col=col)
            sp.location = (x, y, -0.12)
            obs.append(sp)
    else:
        for i in range(9):
            t = (i + 0.5) / 9 - 0.5
            x, y = mid[0] + math.cos(yaw) * t * length, mid[1] + math.sin(yaw) * t * length
            sc = K.box("Scallop", (length / 9 * 0.95, 0.025, 0.08), at=(x, y, POST_TOP - 0.24), m=PAINT, rot=(0, 0, yaw),
                       col=col)
            obs.append(sc)
    return obs


def brackets(col, a, high):
    # a curly bracket each side of the post's top, holding up the frieze
    obs = []
    p = at(a, POST_R, 0)
    tang = (-math.sin(a), math.cos(a))
    for s in (-1, 1):
        pts = [(p[0] + tang[0] * s * 0.1, p[1] + tang[1] * s * 0.1, 2.75),
               (p[0] + tang[0] * s * 0.14, p[1] + tang[1] * s * 0.14, 2.95),
               (p[0] + tang[0] * s * 0.3, p[1] + tang[1] * s * 0.3, 3.1),
               (p[0] + tang[0] * s * 0.42, p[1] + tang[1] * s * 0.42, 3.15)]
        obs.append(K.wire("Bracket", pts, 0.025 if high else 0.03, PAINT, res=16 if high else 4,
                          bevel_res=3 if high else 1, col=col))
        if high:
            obs.append(K.sphere("Bracket Ball", 0.03, at=(p[0] + tang[0] * s * 0.2, p[1] + tang[1] * s * 0.2, 2.92),
                                m=PAINT, seg=12, col=col))
    return obs


def roof_profile(rings):
    # a bell-curved roof: steep near the top, flaring out to the eaves
    prof = [(0.0, EAVE_Z - 0.1), (EAVE_R - 0.1, EAVE_Z - 0.1), (EAVE_R, EAVE_Z - 0.04)]
    for i in range(rings + 1):
        t = i / rings
        r = EAVE_R * (1.0 - t) ** 1.25
        z = EAVE_Z + (APEX_Z - EAVE_Z) * (1.0 - (1.0 - t) ** 1.6)
        prof.append((max(r, 0.18), z))
    prof.append((0.0, APEX_Z))
    return prof


def roof(col, high):
    obs = []
    if high:
        # shingle courses: each course a ring that steps out at its bottom, scalloped round its edge
        courses = 22
        for c in range(courses):
            t0, t1 = c / courses, (c + 1.25) / courses
            r0, r1 = EAVE_R * (1.0 - t0) ** 1.25, EAVE_R * (1.0 - min(1.0, t1)) ** 1.25
            z0 = EAVE_Z + (APEX_Z - EAVE_Z) * (1.0 - (1.0 - t0) ** 1.6)
            z1 = EAVE_Z + (APEX_Z - EAVE_Z) * (1.0 - (1.0 - min(1.0, t1)) ** 1.6)
            if r0 < 0.25:
                break
            ring = K.lathe("Course", [(r0 - 0.02, z0 - 0.02), (r0 + 0.012, z0 - 0.02), (r0 + 0.012, z0 + 0.01),
                                      (max(r1, 0.2), z1), (0.0, z1)], 256, SHINGLE, sides=8,
                           flutes=int(max(24, r0 * 40)) // 8 * 8, flute_depth=0.012, flute_z=(z0 - 0.03, z0 + 0.012),
                           smooth=False, col=col)
            ring.rotation_euler[2] = math.pi / 8
            obs.append(ring)
        # capped ridges down each hip
        for k in range(8):
            a = k * math.tau / 8 + math.pi / 8
            pts = []
            for i in range(9):
                t = i / 8
                r = EAVE_R * (1.0 - t) ** 1.25 / math.cos(math.pi / 8) * 0.995
                z = EAVE_Z + (APEX_Z - EAVE_Z) * (1.0 - (1.0 - t) ** 1.6) + 0.04
                pts.append(at(a, max(r, 0.2), z))
            obs.append(K.wire("Ridge", pts, 0.035, TRIM, res=16, bevel_res=3, col=col))
        # a fascia board round the eaves
        obs.append(K.lathe("Fascia", [(EAVE_R - 0.15, EAVE_Z - 0.18), (EAVE_R + 0.02, EAVE_Z - 0.18),
                                      (EAVE_R + 0.02, EAVE_Z - 0.04), (EAVE_R - 0.15, EAVE_Z - 0.04)], 8, TRIM, sides=8,
                           smooth=False, col=col))
        obs[-1].rotation_euler[2] = math.pi / 8
        # beadboard ceiling: rings of thin boards under the roof
        for i in range(24):
            r0, r1 = EAVE_R * i / 24, EAVE_R * (i + 1) / 24 - 0.006
            z = EAVE_Z - 0.1 + (APEX_Z - 1.2 - EAVE_Z) * (1.0 - (i / 24))
            ring = K.lathe("Ceiling Board", [(r1, z - 0.04), (max(r0, 0.001), z - 0.04 + 0.04 * (r1 - r0)), (0.0, z - 0.03)],
                           8, PAINT, sides=8, smooth=False, col=col)
            ring.rotation_euler[2] = math.pi / 8
            obs.append(ring)
    else:
        o = K.lathe("Roof", roof_profile(6), 8, SHINGLE, sides=8, smooth=False, col=col)
        o.rotation_euler[2] = math.pi / 8
        obs.append(o)
        cz = EAVE_Z - 0.1
        c = K.lathe("Ceiling", [(0.0, APEX_Z - 1.2), (EAVE_R - 0.1, cz - 0.04), (EAVE_R - 0.1, cz - 0.03)], 8, PAINT, sides=8,
                    smooth=False, col=col)
        c.rotation_euler[2] = math.pi / 8
        obs.append(c)
        f = K.lathe("Fascia", [(EAVE_R - 0.15, EAVE_Z - 0.18), (EAVE_R + 0.02, EAVE_Z - 0.18),
                               (EAVE_R + 0.02, EAVE_Z - 0.04), (EAVE_R - 0.15, EAVE_Z - 0.04)], 8, TRIM, sides=8,
                    smooth=False, col=col)
        f.rotation_euler[2] = math.pi / 8
        obs.append(f)
    fin = [(0.0, APEX_Z - 0.05), (0.2, APEX_Z - 0.05), (0.2, APEX_Z + 0.05), (0.14, APEX_Z + 0.12), (0.1, APEX_Z + 0.2),
           (0.16, APEX_Z + 0.3), (0.1, APEX_Z + 0.4), (0.04, APEX_Z + 0.48), (0.05, APEX_Z + 0.55), (0.012, APEX_Z + 0.8),
           (0.0, APEX_Z + 0.82)]
    obs.append(K.lathe("Finial", fin, 32 if high else 8, GOLD, col=col))
    return obs


def build(col, high):
    obs = deck(col, high) + steps(col)
    for k in range(8):
        a = post_angle(k)
        obs += post(col, a, high)
        obs += brackets(col, a, high)
        a1 = post_angle(k + 1)
        mid = (a + a1) / 2 if abs(a - a1) < math.pi else a - math.tau / 16
        if not front(mid):
            obs += railing(col, a, a1, high)
        obs += frieze(col, a, a1, high)
    obs += roof(col, high)
    return obs


high = build(HIGH, True)
low = build(LOW, False)
hi_tris = K.tri_count(high)
gz = K.join("Gazebo", low)
lo_tris = K.tri_count([gz])
K.uv_unwrap(gz, margin=0.004)
maps = K.bake(gz, high, size=2048, name="gazebo", extrusion=0.025, ray=0.08, ao_samples=32,
              maps=["normal", "ao", "color", "rough", "metal"])
K.finish(gz, maps, 2048, "gazebo")
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([gz], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

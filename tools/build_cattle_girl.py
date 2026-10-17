# Builds the cattle girl (working name: Bramble) from scratch: model, materials, rig, weights and animations.
# Reference: the group picture of Sofi's characters (wild golden hair, little horns, furry legs and hooves,
# denim overall shorts over a purple top, green backpack).
#
#   blender -b --python tools\build_cattle_girl.py
#
# Writes source_art/characters/cattle_girl.blend (overwrites it). Units are meters; feet at the origin;
# she faces -Y. Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "cattle_girl.blend"

K.begin()

# =============================================================================
# Materials (linear colors)
# =============================================================================
mat("Skin", (0.90, 0.56, 0.38))
mat("Nose", (0.80, 0.42, 0.28))
mat("Blush", (0.92, 0.32, 0.30))
mat("Mouth", (0.28, 0.03, 0.04))
mat("Tongue", (0.85, 0.25, 0.25))
mat("Brow", (0.40, 0.20, 0.04))
eye_materials((0.035, 0.018, 0.01), (0.20, 0.09, 0.03))
mat("Hair", (0.93, 0.52, 0.035), rough=0.4)
mat("Hair Shade", (0.72, 0.34, 0.02), rough=0.45)
mat("Horn", (0.30, 0.14, 0.05), rough=0.35)
mat("Horn Tip", (0.55, 0.36, 0.18), rough=0.35)
mat("Top", (0.20, 0.05, 0.36))
mat("Overalls", (0.05, 0.17, 0.47))
mat("Overalls Trim", (0.10, 0.27, 0.62))
mat("Clasp", (0.80, 0.62, 0.20), rough=0.35, metal=0.8)
mat("Fur", (0.30, 0.13, 0.04), rough=0.8)
mat("Fur Light", (0.45, 0.24, 0.09), rough=0.8)
mat("Hoof", (0.06, 0.035, 0.025), rough=0.35)
mat("Backpack", (0.05, 0.28, 0.06), rough=0.5)

HEAD = Ellipsoid((0, 0, 1.10), (0.27, 0.25, 0.27))
TORSO = Ellipsoid((0, 0, 0.64), (0.22, 0.19, 0.245))
HB = ["head"]

# =============================================================================
# Head and face
# =============================================================================
ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HB, u=48, v=24)
capsule("Neck", [(0, 0, 0.84), (0, 0, 0.96)], 0.065, 0.065, "Skin", ["chest", "head"])

for sx, side in ((1, "L"), (-1, "R")):
    x = 0.10 * sx
    ec = HEAD.front(x, 1.105) + Vector((0, 0.024, 0))
    cartoon_eye(side, ec, (0.068, 0.048, 0.084), HB, look=(0.004 * sx, 0))
    arc_on(HEAD, f"Brow.{side}", [(sx * (0.06 + 0.09 * t), 1.212 + 0.018 * math.sin(math.pi * t)) for t in
                                  (i / 7 for i in range(8))], 0.011, "Brow", HB)
    b = HEAD.front(0.165 * sx, 1.025)
    ellipsoid(f"Blush.{side}", b - HEAD.normal(b) * 0.006, (0.042, 0.012, 0.028), "Blush", HB,
              rot=basis_facing(HEAD.normal(b)))
    # Lashes: two flicks at the outer top corner of each eye
    for k, (a, l) in enumerate(((28, 0.026), (8, 0.022))):
        base = ec + Vector((0.062 * sx, -0.02, 0.03 + 0.01 * k))
        tip = base + Vector((math.cos(math.radians(a)) * sx, -0.2, math.sin(math.radians(a)) + 0.4)).normalized() * l
        tube(f"Lash.{side}{k}", [base, base.lerp(tip, 0.5), tip], [(0.007, 0.005), (0.005, 0.0035), (0.0012, 0.0012)],
             "Brow", HB, sides=6)

n = HEAD.front(0, 1.035)
ellipsoid("Nose", n + HEAD.normal(n) * 0.004, (0.024, 0.018, 0.017), "Nose", HB)
smile("Mouth", HEAD, 0.0, 0.985, 0.072, 0.05, HB, curl=0.016)

# Horns: short, curving out, up and then a little forward from the top of her head
for sx, side in ((1, "L"), (-1, "R")):
    base = HEAD.dir_point((0.62 * sx, -0.08, 0.78), offset=-0.01)
    path = [base, base + Vector((0.05 * sx, 0.0, 0.045)), base + Vector((0.095 * sx, -0.01, 0.105)),
            base + Vector((0.105 * sx, -0.05, 0.155))]
    ob = lock(f"Horn.{side}", path, 0.036, "Horn", HB, flat=1.0, tip=0.007, sides=14, taper=0.8)
    paint(ob, "Horn Tip", lambda c, nrm, tip=path[-1]: (c - tip).length < 0.04)

# =============================================================================
# Hair: a cap with the face cut out, side-swept bangs, and a huge wild mane of locks
# =============================================================================
R = rng(7)
scalp_cap("Hair Cap", HEAD, "Hair", HB, thick=0.024,
          hairline=lambda x: 1.265 - 0.42 * ss(0.15, 0.25, abs(x)))


def outward(p):
    d = Vector((p.x, p.y - 0.02, 0))
    return d.normalized() if d.length > 1e-4 else Vector((0, -1, 0))


# Bangs: from the crown, forward over the forehead, swept to her right
for k in range(9):
    u = -1 + 2 * k / 8
    x0 = 0.15 * u
    start = HEAD.dir_point((x0 * 2.0, -0.45, 0.9), offset=0.02)
    mid = HEAD.front(0.17 * u - 0.02, 1.30, offset=0.05)
    end = HEAD.front(0.19 * u - 0.05 - 0.02 * R.random(), 1.215 + 0.02 * R.random() + 0.03 * abs(u), offset=0.035)
    lock(f"Bang.{k}", [start, mid, end], 0.062, "Hair", HB, flat=0.42, normal_fn=lambda p: HEAD.normal(p))

# Mane: locks all around the sides and back, puffing far out and falling to her hips
for layer, (count, reach, end_lo, end_hi, material, r0) in enumerate((
        (18, 1.0, 0.42, 0.62, "Hair", 0.125),
        (14, 0.84, 0.55, 0.75, "Hair Shade", 0.115))):
    for k in range(count):
        th = math.radians(-118 + 236 * (k + 0.5 * layer) / (count - 1)) + R.uniform(-0.05, 0.05)
        hd = Vector((math.sin(th), math.cos(th), 0))         # th = 0 points straight back
        front = max(0.0, -hd.y)                                # locks at her sides/front stay shorter
        start = HEAD.dir_point((hd.x * 0.8, hd.y * 0.8, 0.85 + 0.15 * R.random()), offset=-0.01)
        r_out = (0.40 + 0.06 * R.random()) * reach
        z_end = end_hi - (end_hi - end_lo) * (1 - front) + 0.12 * front + 0.05 * R.random()
        wob = Vector((-hd.y, hd.x, 0)) * R.uniform(-0.05, 0.05)
        ctrl = [start,
                HEAD.c + hd * (r_out * 0.85) + Vector((0, 0, 0.12)),
                HEAD.c + hd * r_out + wob + Vector((0, 0, -0.10)),
                HEAD.c + hd * (r_out * 0.97) - wob + Vector((0, 0, -0.32)),
                Vector((hd.x * r_out * 0.86, HEAD.c.y + hd.y * r_out * 0.86, z_end)) + wob * 1.5]
        lock(f"Mane.{layer}.{k}", ctrl, r0 * R.uniform(0.85, 1.1), material, [("head", 1.0), ("chest", 1.5)],
             flat=0.5, normal_fn=outward, sides=12, taper=0.55)
# A few flyaway wisps at the back of the crown for that wild look
for k in range(4):
    th = math.radians(-60 + 120 * k / 3)
    hd = Vector((math.sin(th) * 0.7, 0.6 + 0.4 * math.cos(th), 0.8))
    s = HEAD.dir_point(hd, offset=0.015)
    nrm = HEAD.normal(s)
    lock(f"Wisp.{k}", [s, s + nrm * 0.05 + Vector((0, 0.03, 0.01)), s + nrm * 0.08 + Vector((0, 0.07, -0.03))],
         0.04, "Hair", HB, flat=0.5, normal_fn=lambda p: HEAD.normal(p))

# =============================================================================
# Body: purple top under denim overall shorts with a bib
# =============================================================================
torso = ellipsoid("Torso", TORSO.c, TORSO.r, "Top", ["hips", "spine", "chest", ("thigh.L", 1.8), ("thigh.R", 1.8)],
                  u=96, v=48)
torso.data.materials.append(MATS["Overalls"])
torso.data.materials.append(MATS["Overalls Trim"])
BIB_TOP, WAIST, BIB_ANGLE = 0.79, 0.52, math.radians(36)
for p in torso.data.polygons:
    c = p.center
    on_bib = abs(math.atan2(c.x, -c.y)) < BIB_ANGLE and c.z < BIB_TOP
    if c.z < WAIST or on_bib:
        p.material_index = 1
        if on_bib and BIB_TOP - 0.018 < c.z < BIB_TOP:
            p.material_index = 2
pocket = TORSO.project((0, -0.3, 0.68), offset=0.004)
ellipsoid("Bib Pocket", pocket, (0.06, 0.008, 0.045), "Overalls Trim", ["spine", "chest"],
          rot=basis_facing(TORSO.normal(pocket)), power=0.45)

for sx, side in ((1, "L"), (-1, "R")):
    pts = []
    for k in range(41):
        t = k / 40
        a = math.radians(-50 + 280 * t)
        x = (0.11 - 0.03 * t) * sx
        pts.append(TORSO.project(Vector((x, -math.cos(a) * 0.3, TORSO.c.z + math.sin(a) * 0.3)), offset=0.006))
    start = next(i for i, p in enumerate(pts) if p.z >= BIB_TOP - 0.015)
    end = next(i for i in range(len(pts) - 1, 0, -1) if pts[i].z >= WAIST + 0.02)
    pts = pts[start:end + 1]
    tube(f"Strap.{side}", pts, [(0.022, 0.006)] * len(pts), "Overalls", ["spine", "chest"], sides=8,
         normal_fn=TORSO.normal)
    s = TORSO.project((0.11 * sx, -0.3, BIB_TOP - 0.01), offset=0.008)
    ellipsoid(f"Clasp.{side}", s, (0.026, 0.008, 0.022), "Clasp", ["chest", "spine"], rot=basis_facing(TORSO.normal(s)),
              power=0.5, u=16, v=8)

# Arms (bare, A-pose) with mitten hands
for sx, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.215 * sx, 0, 0.80)), Vector((0.30 * sx, -0.03, 0.67)), Vector((0.37 * sx, -0.05, 0.56))
    capsule(f"Arm.{side}", [sh, el, wr], 0.055, 0.048, "Skin", [f"upper_arm.{side}", f"forearm.{side}"])
    capsule(f"Top Sleeve.{side}", [sh + Vector((-0.02 * sx, 0, 0.0)), sh.lerp(el, 0.25)], 0.066, 0.062, "Top",
            [f"upper_arm.{side}", ("chest", 1.6)])
    d = (wr - el).normalized()
    ellipsoid(f"Hand.{side}", wr + d * 0.04, (0.052, 0.047, 0.06), "Skin", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", wr + d * 0.028 + Vector((0, -0.04, 0.005)), (0.02, 0.024, 0.028), "Skin", [f"hand.{side}"])

# Legs: denim shorts with rolled cuffs, a bit of knee, then shaggy fur down to two-toed hooves
for sx, side in ((1, "L"), (-1, "R")):
    x = 0.11 * sx
    capsule(f"Shorts.{side}", [(0.10 * sx, 0, 0.52), (x, 0, 0.39)], 0.105, 0.102, "Overalls",
            [("hips", 1.6), f"thigh.{side}"])
    torus(f"Cuff.{side}", (x, 0, 0.375), 0.105, 0.026, "Overalls Trim", [f"thigh.{side}"])
    capsule(f"Knee.{side}", [(x, 0, 0.39), (x, 0, 0.27)], 0.066, 0.064, "Skin", [f"thigh.{side}", f"shin.{side}"])
    capsule(f"Fur Leg.{side}", [(x, 0, 0.29), (x, -0.005, 0.09)], 0.078, 0.094, "Fur",
            [f"thigh.{side}", f"shin.{side}", (f"foot.{side}", 1.4)])
    for k in range(12):                                     # ruff at the top of the fur and over the hooves
        a = 2 * math.pi * k / 12
        d = Vector((math.cos(a), math.sin(a), 0))
        for z0, length, m, bones in ((0.30, 0.07, "Fur Light", [f"shin.{side}", f"thigh.{side}"]),
                                     (0.12, 0.08, "Fur", [f"shin.{side}", f"foot.{side}"])):
            r = 0.082 if z0 > 0.2 else 0.096
            b = Vector((x, -0.005, z0)) + d * (r - 0.012)
            lock(f"Tuft.{side}{k}.{z0}", [b, b + d * 0.03 + Vector((0, 0, -length * 0.5)),
                                          b + d * 0.04 + Vector((0, 0, -length))],
                 0.03, m, bones, flat=0.55, normal_fn=lambda p, d=d: d, sides=8)
    for tx in (-1, 1):
        ellipsoid(f"Hoof.{side}{tx}", (x + 0.036 * tx, -0.03, 0.036), (0.04, 0.072, 0.038), "Hoof", [f"foot.{side}"],
                  power=0.7)

# Backpack (mostly hidden by her hair) with straps over the shoulders
BP = ["chest"]
ellipsoid("Backpack", (0, 0.27, 0.62), (0.16, 0.08, 0.17), "Backpack", BP, power=0.45, u=32, v=16)
for sx, side in ((1, "L"), (-1, "R")):
    path = [(0.10 * sx, 0.22, 0.78), (0.13 * sx, 0.10, 0.88), (0.15 * sx, -0.06, 0.88), (0.17 * sx, -0.16, 0.76),
            (0.19 * sx, -0.15, 0.62), (0.19 * sx, -0.10, 0.52)]
    pts = []
    for a, b in zip(path, path[1:]):
        for k in range(6):
            pts.append(TORSO.project(Vector(a).lerp(Vector(b), k / 6), offset=0.014))
    pts.append(TORSO.project(path[-1], offset=0.014))
    tube(f"Backpack Strap.{side}", pts, [(0.02, 0.006)] * len(pts), "Backpack", BP, sides=8, normal_fn=TORSO.normal)

# =============================================================================
# Rig, skin, animations
# =============================================================================
BONES = biped_bones(shoulder=(0.215, 0, 0.80), elbow=(0.30, -0.03, 0.67), wrist=(0.37, -0.05, 0.56),
                    hand_tip=(0.41, -0.065, 0.49), hip_x=0.11)
rig = build_rig("CattleGirlRig", BONES)
skin_and_join(rig, BONES, "CattleGirl", "Torso")

make_action(rig, "idle", 60, lambda t: biped_idle(BONES, t))
make_action(rig, "walk", 32, lambda t: biped_walk(BONES, t))
make_action(rig, "run", 20, lambda t: biped_run(BONES, t))
rest_pose(rig)
finish(OUT)

# Builds Mr. Palmer, the town mayor, from scratch: model, materials, rig, weights and animations.
# Reference: Hayden's Tripo Studio test render (round tummy, grey hair and moustache, round glasses,
# navy suit, red tie, yellow mayor's sash with a gold rosette, brown shoes, arms out in welcome).
#
#   blender -b --python tools\build_mr_palmer.py
#
# Writes source_art/characters/mr_palmer.blend (overwrites it) with idle / walk actions.
# Units are meters; feet on the ground at the origin; faces -Y. Helpers: tools/char_kit.py.
# He's a grown-up: about 1.8 m tall, so he stands a head above the kids (1.45 m).

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "mr_palmer.blend"

K.begin()
mat("Skin", (0.92, 0.66, 0.52))
mat("Nose", (0.93, 0.55, 0.47))
mat("Blush", (0.93, 0.45, 0.40))
mat("Mouth", (0.35, 0.08, 0.07))
mat("Tongue", (0.85, 0.35, 0.35))
mat("Grey Hair", (0.52, 0.52, 0.53), rough=0.6)
mat("Grey Dark", (0.36, 0.36, 0.37), rough=0.6)
mat("Glasses", (0.06, 0.04, 0.03), rough=0.3)
mat("Suit", (0.055, 0.09, 0.24), rough=0.6)
mat("Suit Shade", (0.035, 0.06, 0.17), rough=0.6)
mat("Shirt", (0.92, 0.92, 0.90), rough=0.6)
mat("Tie", (0.70, 0.04, 0.04), rough=0.5)
mat("Sash", (0.98, 0.72, 0.10), rough=0.45)
mat("Gold", (0.85, 0.60, 0.12), rough=0.3, metal=0.6)
mat("Gold Dark", (0.45, 0.30, 0.05), rough=0.4, metal=0.5)
mat("Shoes", (0.30, 0.15, 0.06), rough=0.45)
mat("Sole", (0.17, 0.08, 0.03), rough=0.7)
eye_materials((0.10, 0.06, 0.03), (0.22, 0.13, 0.06))

HEAD = Ellipsoid((0, 0, 1.46), (0.275, 0.26, 0.285))
JOWL = Ellipsoid((0, -0.02, 1.33), (0.29, 0.25, 0.175))       # round cheeks and chin
TORSO = Ellipsoid((0, 0, 0.80), (0.38, 0.34, 0.42))            # the round tummy (his suit jacket)
HB = ["head"]

ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HB, u=48, v=24)
ellipsoid("Jowls", JOWL.c, JOWL.r, "Skin", HB, u=48, v=24)

# Hair: short, grey and full on top, thick at the sides above the ears, swept back
R = rng(11)
scalp_cap("Hair", HEAD, "Grey Hair", HB, thick=0.03,
          hairline=lambda x: 1.64 - 0.17 * ss(0.12, 0.25, abs(x)), u=96, v=48, bottom=1.38)
ellipsoid("Hair Volume", (0, 0.03, 1.63), (0.25, 0.25, 0.14), "Grey Hair", HB, u=48, v=24)
for k in range(4):
    x = -0.15 + 0.10 * k + R.uniform(-0.01, 0.01)
    root = HEAD.front(x, 1.65, offset=0.015)
    mid = HEAD.project(root + Vector((x * 0.15, 0.10, 0.07)), offset=0.03)
    tip = HEAD.project(root + Vector((x * 0.3, 0.22, 0.06)), offset=0.03)
    lock(f"Top Lock.{k}", [root, mid, tip], 0.085, "Grey Hair", HB, flat=0.3, normal_fn=HEAD.normal, sides=8)
for sx, side in ((1, "L"), (-1, "R")):
    for k in range(4):
        z = 1.43 + 0.05 * k
        root = HEAD.dir_point((sx, -0.25 + 0.15 * k, z - HEAD.c.z), offset=0.015)
        tip = HEAD.dir_point((sx * 0.9, 0.35 + 0.12 * k, z - HEAD.c.z - 0.04), offset=0.03)
        lock(f"Side Tuft.{side}{k}", [root, root.lerp(tip, 0.5) + Vector((0.025 * sx, 0, 0)), tip], 0.045,
             "Grey Hair", HB, flat=0.55, normal_fn=HEAD.normal, sides=8)

# Face: big round eyes behind round glasses, bulb nose, bushy brows, a big moustache over a small smile
for sx, side in ((1, "L"), (-1, "R")):
    ec = HEAD.front(0.095 * sx, 1.47, offset=-0.014)
    cartoon_eye(side, ec, (0.062, 0.035, 0.068), HB)
    n = HEAD.normal(HEAD.front(0.095 * sx, 1.47))
    ring_c = HEAD.front(0.097 * sx, 1.47, offset=0.05)
    torus(f"Glasses Rim.{side}", ring_c, 0.08, 0.01, "Glasses", HB, u=40, v=8,
          rot=n.to_track_quat('Z', 'Y').to_matrix())
    outer = ring_c + Vector((0.079 * sx, 0.01, 0))
    arm = [outer, HEAD.dir_point((sx, -0.3, 0.02), offset=0.018), HEAD.dir_point((sx, 0.15, 0.0), offset=0.012)]
    tube(f"Glasses Arm.{side}", smooth_path(arm, 4), [(0.007, 0.006)] * 9, "Glasses", HB, sides=8)
    brow = [(sx * (0.04 + 0.12 * t), 1.575 + 0.03 * math.sin(math.pi * t) - 0.01 * t) for t in
            (i / 7 for i in range(8))]
    arc_on(HEAD, f"Brow.{side}", brow, 0.024, "Grey Hair", HB, offset=0.012)
    ear = HEAD.dir_point((sx, 0.05, -0.08), offset=-0.01)
    ellipsoid(f"Ear.{side}", ear, (0.04, 0.055, 0.07), "Skin", HB)
    b = JOWL.front(0.19 * sx, 1.36)
    ellipsoid(f"Blush.{side}", b - JOWL.normal(b) * 0.008, (0.04, 0.012, 0.026), "Blush", HB,
              rot=basis_facing(JOWL.normal(b)))
    # Moustache: a thick grey lock from under the nose out to each side, drooping then curling up a little
    m0 = JOWL.front(0.012 * sx, 1.36, offset=0.025)
    m1 = JOWL.front(0.09 * sx, 1.345, offset=0.03)
    m2 = JOWL.front(0.17 * sx, 1.305, offset=0.02)
    m3 = JOWL.front(0.215 * sx, 1.32, offset=0.012)
    lock(f"Moustache.{side}", [m0, m1, m2, m3], 0.055, "Grey Hair", HB, flat=0.6, normal_fn=JOWL.normal,
         sides=12, taper=1.3)
bridge = [HEAD.front(0.03, 1.48, offset=0.055), HEAD.front(0, 1.485, offset=0.06),
          HEAD.front(-0.03, 1.48, offset=0.055)]
tube("Glasses Bridge", bridge, [(0.007, 0.006)] * 3, "Glasses", HB, sides=8)
n0 = HEAD.front(0, 1.40)
ellipsoid("Nose", n0 + HEAD.normal(n0) * 0.035, (0.058, 0.05, 0.05), "Nose", HB)
ellipsoid("Moustache Middle", JOWL.front(0, 1.358, offset=0.03), (0.045, 0.025, 0.03), "Grey Hair", HB)
smile("Smile", JOWL, 0, 1.285, 0.05, 0.034, HB, curl=0.006, offset=0.004)   # open happy smile under the moustache

# Suit jacket over the tummy; trousers show below the hem
BODY_BONES = ["hips", "spine", "chest", ("thigh.L", 1.8), ("thigh.R", 1.8)]
torso = ellipsoid("Torso", TORSO.c, TORSO.r, "Suit", BODY_BONES, u=64, v=32)
ring_on("Hem", TORSO, 0.52, 0.004, 0.02, "Suit Shade", ["hips"])

# Shirt front: a white V from the collar down to the chest, with the red tie in it
V_TOP, V_BOT = 1.19, 0.93


def v_half(z):
    return 0.13 * ((z - V_BOT) / (V_TOP - V_BOT)) ** 0.9


surface_patch("Shirt Front", TORSO, [[(v_half(z) * (j / 8 - 1), z) for j in range(17)]
                                     for z in (V_BOT + (V_TOP - V_BOT) * i / 12 for i in range(13))],
              0.003, "Shirt", ["chest"])
ring_on("Shirt Collar", Ellipsoid((0, -0.01, 1.18), (0.16, 0.15, 0.05)), 1.18, 0.0, 0.03, "Shirt", ["chest"])
for sx in (1, -1):
    arc_on(TORSO, f"Lapel.{sx}", [(sx * (v_half(z) + 0.02), z) for z in
                                  (V_BOT + (V_TOP - V_BOT) * i / 9 for i in range(10))],
           0.03, "Suit Shade", ["chest"], offset=0.006)
knot = TORSO.front(0, 1.155, offset=0.025)
ellipsoid("Tie Knot", knot, (0.035, 0.02, 0.03), "Tie", ["chest"])


def tie_half(z):
    return 0.022 + 0.022 * ss(1.14, 1.0, z) - 0.04 * ss(0.94, 0.905, z)


surface_patch("Tie", TORSO, [[(tie_half(z) * (j / 4 - 1), z) for j in range(9)]
                             for z in (0.905 + (1.14 - 0.905) * i / 14 for i in range(15))],
              0.012, "Tie", ["chest"])
for k, z in enumerate((0.85, 0.73)):
    b = TORSO.front(0.03, z, offset=0.005)
    ellipsoid(f"Button.{k}", b, (0.02, 0.008, 0.02), "Suit Shade", ["spine"], rot=basis_facing(TORSO.normal(b)))
pocket = TORSO.project((-0.22, -0.3, 0.70), offset=0.004)
ellipsoid("Pocket", pocket, (0.10, 0.008, 0.025), "Suit Shade", ["spine"], rot=basis_facing(TORSO.normal(pocket)),
          power=0.5)

# The mayor's sash: a yellow band from his right shoulder across the tummy to his left hip, all the way round
SASH_ELL = Ellipsoid((0, 0, 0.84), (0.385, 0.345, 0.43))
TILT = math.radians(38)
sash = []
for k in range(97):
    a = 2 * math.pi * k / 96
    d = Vector((math.cos(a) * math.cos(TILT), math.sin(a), -math.cos(a) * math.sin(TILT)))
    sash.append(SASH_ELL.dir_point(d, offset=0.018))
tube("Sash", sash, [(0.065, 0.008)] * len(sash), "Sash", BODY_BONES, sides=8, normal_fn=TORSO.normal,
     caps=False)
# Gold rosette where the sash crosses his left hip
d = Vector((math.cos(-1.05) * math.cos(TILT), math.sin(-1.05), -math.cos(-1.05) * math.sin(TILT)))
rc = SASH_ELL.dir_point(d, offset=0.05)                          # sits proud of the sash so its edges stay clear
rn = TORSO.normal(rc)
down = (Vector((0, 0, -1)) - rn * rn.z).normalized()             # straight down along the tummy
for k in range(2):                                              # two ribbon tails hanging below it
    sx = -1 if k == 0 else 1
    side = rn.cross(down).normalized() * sx
    pts = [rc + down * 0.04 + side * 0.02]
    for step in (0.13, 0.24):
        pts.append(TORSO.project(rc + down * step + side * (0.02 + 0.15 * step), offset=0.035))
    lock(f"Rosette Tail.{k}", pts, 0.045, "Sash", BODY_BONES, flat=0.3, normal_fn=TORSO.normal, sides=8,
         taper=0.3)
torus("Rosette Frill", rc, 0.07, 0.022, "Sash", BODY_BONES, u=36, v=8, rot=rn.to_track_quat('Z', 'Y').to_matrix())
ellipsoid("Rosette", rc + rn * 0.008, (0.062, 0.014, 0.062), "Gold", BODY_BONES, rot=basis_facing(rn))
star_prism("Rosette Star", rc + rn * 0.022, rn, 0.04, 0.017, 0.008, "Gold Dark", BODY_BONES)

# Arms: suit sleeves with white shirt cuffs, open welcoming hands
SH, EL, WR = Vector((0.31, 0, 1.09)), Vector((0.46, -0.03, 0.95)), Vector((0.59, -0.06, 0.84))
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda v: Vector((v.x * sx, v.y, v.z))
    sh, el, wr = m(SH), m(EL), m(WR)
    ellipsoid(f"Shoulder.{side}", sh + Vector((-0.02 * sx, 0, 0)), (0.09, 0.09, 0.085), "Suit",
              ["chest", f"upper_arm.{side}"])
    capsule(f"Sleeve.{side}", [sh, el, wr], 0.085, 0.07, "Suit", [f"upper_arm.{side}", f"forearm.{side}"])
    d = (wr - el).normalized()
    capsule(f"Cuff.{side}", [wr, wr + d * 0.025], 0.06, 0.06, "Shirt", [f"forearm.{side}"])
    palm = wr + d * 0.075
    ellipsoid(f"Hand.{side}", palm, (0.06, 0.03, 0.065), "Skin", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    side_dir = d.cross(Vector((0, -1, 0))).normalized() * sx
    for f in range(4):
        base = palm + d * 0.045 + side_dir * (0.035 - 0.023 * f) * -1
        tip = base + (d * (0.07 - 0.008 * abs(f - 1.5)) + side_dir * (0.01 * (f - 1.5)) * -1)
        capsule(f"Finger.{side}{f}", [base, tip], 0.014, 0.012, "Skin", [f"hand.{side}"], sides=10, steps=5)
    thumb0 = palm + Vector((0, -0.03, 0.03))
    capsule(f"Thumb.{side}", [thumb0, thumb0 + Vector((0.025 * sx, -0.03, 0.04))], 0.016, 0.014, "Skin",
            [f"hand.{side}"], sides=10, steps=5)

    # Legs: short navy trousers, chunky brown shoes
    x = 0.15 * sx
    capsule(f"Trousers.{side}", [(0.13 * sx, 0, 0.56), (x, 0, 0.32), (x, 0, 0.12)], 0.13, 0.11, "Suit",
            [("hips", 1.6), f"thigh.{side}", f"shin.{side}"])
    ellipsoid(f"Shoe.{side}", (x, -0.06, 0.07), (0.095, 0.16, 0.07), "Shoes", [f"foot.{side}"], power=0.75)
    ellipsoid(f"Sole.{side}", (x, -0.06, 0.02), (0.1, 0.165, 0.022), "Sole", [f"foot.{side}"], power=0.5)

BONES = biped_bones(hips=0.56, chest=0.95, neck=1.17, head_top=1.80, shoulder=tuple(SH), elbow=tuple(EL),
                    wrist=tuple(WR), hand_tip=(0.67, -0.08, 0.78), hip_x=0.15, knee=0.32, ankle=0.11,
                    toe=(-0.2, 0.04))
rig = build_rig("MrPalmerRig", BONES)
skin_and_join(rig, BONES, "MrPalmer", "Torso")


# Rest pose is arms out wide (the welcome in the reference). Idle and walk drop them only a little,
# because his tummy is in the way.
def arms_low(p, drop, swing_l=(), swing_r=()):
    p.rel("upper_arm.L", (Y, drop), *swing_l)
    p.rel("upper_arm.R", (Y, -drop), *swing_r)
    p.rel("forearm.L", (X, -0.25))
    p.rel("forearm.R", (X, -0.25))


def idle(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    arms_low(p, 0.22 + 0.03 * s, [(X, -0.05)], [(X, -0.05)])
    p.rel("spine", (X, -0.02 + 0.015 * s))                       # leans back a touch, proud
    p.rel("chest", (X, 0.01 * s))
    p.rel("head", (Y, 0.03 * math.sin(2 * math.pi * t + 1.2)), (X, -0.015 * s))
    p.offset = Vector((0, 0, 0.005 * s))
    return p


def walk(t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.32 * s))
    p.rel("thigh.R", (X, 0.32 * s))
    p.rel("shin.L", (X, 0.06 + 0.45 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.06 + 0.45 * max(0.0, c)))
    p.rel("foot.L", (X, -0.1 * s))
    p.rel("foot.R", (X, 0.1 * s))
    arms_low(p, 0.2, [(X, 0.25 * s)], [(X, -0.25 * s)])
    p.rel("spine", (Z, 0.05 * s))                                # a waddle
    p.rel("chest", (Y, 0.03 * s))
    p.rel("head", (Z, -0.06 * s))
    p.offset = Vector((0, 0, 0.015 * abs(math.sin(ph))))
    return p


make_action(rig, "idle", 72, idle)
make_action(rig, "walk", 36, walk)
rest_pose(rig)
finish(OUT)

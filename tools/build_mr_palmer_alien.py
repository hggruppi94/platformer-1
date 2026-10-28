# Builds Mr. Palmer's Galaxity form: the mayor as an alien, the way the kids become creatures in Galaxity.
# He keeps everything that makes him Mr. Palmer (round tummy, navy suit, red tie, yellow sash with the gold rosette,
# round glasses, grey brows and big grey moustache, brown shoes, arms out in welcome) and gets mint-teal skin with
# darker spots, a long bendy elephant trunk (its own chain of bones, so it sways, swings and grabs), lilac ear fins and head crest, two antennae with glowing gold tips,
# three chunky fingers and a stubby tail out from under his jacket. His human self (build_mr_palmer.py) stays for Earth.
#
#   blender -b --python tools\build_mr_palmer_alien.py
#
# Writes source_art/characters/mr_palmer_alien.blend (overwrites it) with idle / walk / grab actions.
# Units are meters; feet on the ground at the origin; faces -Y. Helpers: tools/char_kit.py.
# He's a grown-up: about 1.8 m tall, so he stands a head above the kids (1.45 m).

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "mr_palmer_alien.blend"

K.begin()
mat("Skin", (0.30, 0.66, 0.62))
mat("Snout", (0.74, 0.93, 0.84))
mat("Spots", (0.20, 0.50, 0.50))
mat("Nostril", (0.10, 0.28, 0.30))
mat("Fin", (0.68, 0.52, 0.92), rough=0.45)
mat("Fin Light", (0.84, 0.74, 1.0), rough=0.45)
mat("Antenna Glow", (1.0, 0.62, 0.10), rough=0.3, emit=0.5)
mat("Blush", (0.95, 0.50, 0.62))
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
# The trunk: from between his eyes, forward and down in front of his tummy, the tip curling forward. It hangs off
# its own chain of bones (trunk.0-7, short ones so it bends smoothly), so it can sway, swing and grab.
TRUNK_SHAPE = [Vector(v) for v in ((0, -0.235, 1.43), (0, -0.36, 1.35), (0, -0.43, 1.21), (0, -0.45, 1.06),
                                   (0, -0.44, 0.93), (0, -0.49, 0.85))]
trunk_pts = smooth_path(TRUNK_SHAPE, 8)
TRUNK_N = 8
TRUNK = [trunk_pts[round(k * (len(trunk_pts) - 1) / TRUNK_N)] for k in range(TRUNK_N + 1)]   # the bone joints
TRUNK_BONES = [f"trunk.{k}" for k in range(TRUNK_N)]


def trunk_r(i):
    t = i / (len(trunk_pts) - 1)
    return 0.085 - 0.05 * t


tube("Trunk", trunk_pts, [(trunk_r(i), trunk_r(i)) for i in range(len(trunk_pts))], "Skin", TRUNK_BONES, sides=20)
ellipsoid("Trunk Root", TRUNK[0] + Vector((0, 0.03, -0.01)), (0.1, 0.06, 0.09), "Skin", HB + ["trunk.0"])
# Wrinkle rings down its length, and the pale tip with the nostrils in it
for k in range(5, len(trunk_pts) - 4, 5):
    a, b = trunk_pts[k - 1], trunk_pts[k + 1]
    n = (b - a).normalized()
    torus(f"Trunk Ring.{k}", trunk_pts[k], trunk_r(k) * 0.98, 0.005, "Spots", TRUNK_BONES, u=24, v=6,
          rot=n.to_track_quat('Z', 'Y').to_matrix())
tip, tip_dir = trunk_pts[-1], (trunk_pts[-1] - trunk_pts[-3]).normalized()
ellipsoid("Trunk Tip", tip, (0.04, 0.04, 0.04), "Snout", [TRUNK_BONES[-1]], u=20, v=10)
for sx, side in ((1, "L"), (-1, "R")):
    ellipsoid(f"Nostril.{side}", tip + tip_dir * 0.036 + Vector((0.013 * sx, 0, 0)), (0.009, 0.009, 0.009),
              "Nostril", [TRUNK_BONES[-1]], u=12, v=6)
R = rng(11)

# Spots: darker teal freckles over his head (none on the face or snout)
for k in range(14):
    d = Vector((R.uniform(-1, 1), R.uniform(-0.2, 1.0), R.uniform(0.15, 1.0)))
    if d.y < 0.1 and abs(d.x) < 0.75:
        continue
    sp = HEAD.dir_point(d)
    size = R.uniform(0.022, 0.04)
    ellipsoid(f"Spot.{k}", sp - HEAD.normal(sp) * 0.004, (size, 0.006, size * 0.8), "Spots", HB,
              rot=basis_facing(HEAD.normal(sp)))

# Crest: three soft lilac fins front to back over the top of his head, where his hair used to be
for k, (y, h) in enumerate(((-0.14, 0.14), (0.0, 0.19), (0.14, 0.15))):
    base = HEAD.dir_point((0, y, 1), offset=-0.02)
    tip = base + Vector((0, 0.06 + 0.02 * k, h))
    lock(f"Crest.{k}", [base, base.lerp(tip, 0.55) + Vector((0, -0.01, 0)), tip], 0.085, "Fin", HB, flat=0.35,
         normal_fn=lambda p: Vector((1, 0, 0)), sides=10, taper=1.2)

# Antennae: two springy stalks with glowing gold bobbles (the mayor's are the shiniest in town)
for sx, side in ((1, "L"), (-1, "R")):
    root = HEAD.dir_point((0.45 * sx, -0.15, 0.9), offset=-0.01)
    stalk = [root, root + Vector((0.05 * sx, -0.01, 0.12)), root + Vector((0.13 * sx, 0.0, 0.22))]
    tube(f"Antenna.{side}", smooth_path(stalk, 5), [(0.014, 0.014)] * 11, "Skin", HB, sides=10,
         normal_fn=lambda p: Vector((0, -1, 0)))
    ellipsoid(f"Antenna Bobble.{side}", stalk[-1] + Vector((0.01 * sx, 0, 0.03)), (0.042, 0.042, 0.042),
              "Antenna Glow", HB, u=20, v=10)

# Grey tufts at the sides (he's still the grown-up of the town), swept back over the fins
for sx, side in ((1, "L"), (-1, "R")):
    for k in range(3):
        z = 1.47 + 0.05 * k
        root = HEAD.dir_point((sx, -0.1 + 0.15 * k, z - HEAD.c.z), offset=0.012)
        tip = HEAD.dir_point((sx * 0.9, 0.4 + 0.12 * k, z - HEAD.c.z - 0.03), offset=0.03)
        lock(f"Side Tuft.{side}{k}", [root, root.lerp(tip, 0.5) + Vector((0.025 * sx, 0, 0)), tip], 0.042,
             "Grey Hair", HB, flat=0.55, normal_fn=HEAD.normal, sides=8)

# Face: big round eyes behind round glasses, bushy brows, the big moustache now on top of the snout
EYE_Z = 1.505
for sx, side in ((1, "L"), (-1, "R")):
    ec = HEAD.front(0.1 * sx, EYE_Z, offset=-0.014)
    cartoon_eye(side, ec, (0.064, 0.036, 0.07), HB)
    n = HEAD.normal(HEAD.front(0.1 * sx, EYE_Z))
    ring_c = HEAD.front(0.102 * sx, EYE_Z, offset=0.05)
    torus(f"Glasses Rim.{side}", ring_c, 0.082, 0.01, "Glasses", HB, u=40, v=8,
          rot=n.to_track_quat('Z', 'Y').to_matrix())
    outer = ring_c + Vector((0.081 * sx, 0.01, 0))
    arm = [outer, HEAD.dir_point((sx, -0.3, 0.06), offset=0.018), HEAD.dir_point((sx, 0.15, 0.04), offset=0.012)]
    tube(f"Glasses Arm.{side}", smooth_path(arm, 4), [(0.007, 0.006)] * 9, "Glasses", HB, sides=8)
    brow = [(sx * (0.04 + 0.13 * t), 1.61 + 0.03 * math.sin(math.pi * t) - 0.01 * t) for t in
            (i / 7 for i in range(8))]
    arc_on(HEAD, f"Brow.{side}", brow, 0.026, "Grey Hair", HB, offset=0.012)
    # Ear fins: rounded lilac fans where his ears were, two ribs each, angled back
    ear = HEAD.dir_point((sx, 0.08, -0.02), offset=-0.01)
    fin_rot = Euler((0.0, math.radians(-25 * sx), math.radians(25 * sx))).to_matrix()
    ellipsoid(f"Ear Fin.{side}", ear + Vector((0.04 * sx, 0.03, 0.02)), (0.022, 0.085, 0.11), "Fin", HB,
              rot=fin_rot)
    for r_ in range(2):
        rib0 = ear + Vector((0.05 * sx, 0.0, 0.0))
        rib1 = rib0 + fin_rot @ Vector((0.006 * sx, 0.04 + 0.03 * r_, 0.09 - 0.05 * r_))
        tube(f"Ear Rib.{side}{r_}", [rib0, rib1], [(0.008, 0.008)] * 2, "Fin Light", HB, sides=8)
    b = JOWL.front(0.215 * sx, 1.40)
    ellipsoid(f"Blush.{side}", b - JOWL.normal(b) * 0.008, (0.04, 0.012, 0.026), "Blush", HB,
              rot=basis_facing(JOWL.normal(b)))
    # Moustache: a thick grey lock out from under each side of the trunk, drooping then curling up
    m0 = JOWL.front(0.06 * sx, 1.37, offset=0.04)
    m1 = JOWL.front(0.12 * sx, 1.35, offset=0.035)
    m2 = JOWL.front(0.19 * sx, 1.31, offset=0.025)
    m3 = JOWL.front(0.235 * sx, 1.335, offset=0.02)
    lock(f"Moustache.{side}", [m0, m1, m2, m3], 0.055, "Grey Hair", HB, flat=0.6, normal_fn=JOWL.normal,
         sides=12, taper=1.3)
bridge = [HEAD.front(0.032, EYE_Z + 0.01, offset=0.055), HEAD.front(0, EYE_Z + 0.015, offset=0.06),
          HEAD.front(-0.032, EYE_Z + 0.01, offset=0.055)]
tube("Glasses Bridge", bridge, [(0.007, 0.006)] * 3, "Glasses", HB, sides=8)
smile("Smile", JOWL, 0, 1.30, 0.1, 0.05, HB, curl=0.02, offset=0.004)   # a wide smile peeking out round the trunk

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
rc = SASH_ELL.dir_point(d, offset=0.065)                         # sits proud of the sash so its edges stay clear
rn = TORSO.normal(rc)
down = (Vector((0, 0, -1)) - rn * rn.z).normalized()             # straight down along the tummy
for k in range(2):                                              # two ribbon tails hanging below it
    sx = -1 if k == 0 else 1
    side = rn.cross(down).normalized() * sx
    pts = [rc + down * 0.04 + side * 0.02]
    # Clear of the sash band while over it, then down onto the jacket, stopping well above the hem
    for step, off in ((0.10, 0.058), (0.19, 0.046)):
        pts.append(TORSO.project(rc + down * step + side * (0.02 + 0.3 * step), offset=off))
    lock(f"Rosette Tail.{k}", pts, 0.04, "Sash", BODY_BONES, flat=0.3, normal_fn=TORSO.normal, sides=8,
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
    for f in range(3):                                          # three chunky alien fingers
        base = palm + d * 0.045 + side_dir * (0.03 - 0.03 * f) * -1
        tip = base + (d * (0.065 - 0.01 * abs(f - 1)) + side_dir * (0.014 * (f - 1)) * -1)
        capsule(f"Finger.{side}{f}", [base, tip], 0.019, 0.017, "Skin", [f"hand.{side}"], sides=10, steps=5)
    thumb0 = palm + Vector((0, -0.03, 0.03))
    capsule(f"Thumb.{side}", [thumb0, thumb0 + Vector((0.025 * sx, -0.03, 0.04))], 0.016, 0.014, "Skin",
            [f"hand.{side}"], sides=10, steps=5)

    # Legs: short navy trousers, chunky brown shoes
    x = 0.15 * sx
    capsule(f"Trousers.{side}", [(0.13 * sx, 0, 0.56), (x, 0, 0.32), (x, 0, 0.12)], 0.13, 0.11, "Suit",
            [("hips", 1.6), f"thigh.{side}", f"shin.{side}"])
    ellipsoid(f"Shoe.{side}", (x, -0.06, 0.07), (0.095, 0.16, 0.07), "Shoes", [f"foot.{side}"], power=0.75)
    ellipsoid(f"Sole.{side}", (x, -0.06, 0.02), (0.1, 0.165, 0.022), "Sole", [f"foot.{side}"], power=0.5)

# Tail: a stubby dino tail out from under the back of his jacket, curving down to just off the ground, with
# little lilac fins along the top
tail = [Vector((0, 0.26, 0.5)), Vector((0, 0.42, 0.36)), Vector((0, 0.58, 0.18)), Vector((0, 0.72, 0.1))]
tail_pts = smooth_path(tail, 6)
tube("Tail", tail_pts, [(0.13 * (1 - i / len(tail_pts)) + 0.02, 0.12 * (1 - i / len(tail_pts)) + 0.02)
                        for i in range(len(tail_pts))], "Skin", ["hips"], sides=16)
for k, t in enumerate((0.25, 0.5, 0.75)):
    i = int(t * (len(tail_pts) - 1))
    p0 = tail_pts[i]
    up = (tail_pts[i + 1] - tail_pts[i - 1]).cross(Vector((1, 0, 0))).normalized()
    if up.z < 0:
        up = -up
    rad = 0.13 * (1 - i / len(tail_pts)) + 0.02
    lock(f"Tail Fin.{k}", [p0 + up * (rad - 0.02), p0 + up * (rad + 0.05 - 0.01 * k)], 0.045 - 0.008 * k, "Fin",
         ["hips"], flat=0.35, normal_fn=lambda p: Vector((1, 0, 0)), sides=8)
for k in range(5):
    t = 0.15 + 0.17 * k
    i = int(t * (len(tail_pts) - 1))
    rad = 0.13 * (1 - i / len(tail_pts)) + 0.02
    a = math.radians(R.uniform(40, 140)) * (1 if k % 2 else -1)
    sp = tail_pts[i] + Vector((math.cos(a) * rad, 0, math.sin(a) * rad * 0.9))
    ellipsoid(f"Tail Spot.{k}", sp, (0.02, 0.02, 0.016), "Spots", ["hips"])

BONES = biped_bones(hips=0.56, chest=0.95, neck=1.17, head_top=1.80, shoulder=tuple(SH), elbow=tuple(EL),
                    wrist=tuple(WR), hand_tip=(0.67, -0.08, 0.78), hip_x=0.15, knee=0.32, ankle=0.11,
                    toe=(-0.2, 0.04))
for k, b in enumerate(TRUNK_BONES):
    BONES[b] = (tuple(TRUNK[k]), tuple(TRUNK[k + 1]), "head" if k == 0 else TRUNK_BONES[k - 1])
rig = build_rig("MrPalmerAlienRig", BONES)
skin_and_join(rig, BONES, "MrPalmerAlien", "Torso")


# Rest pose is arms out wide (the welcome in the reference). Idle and walk drop them only a little,
# because his tummy is in the way.
def arms_low(p, drop, swing_l=(), swing_r=()):
    p.rel("upper_arm.L", (Y, drop), *swing_l)
    p.rel("upper_arm.R", (Y, -drop), *swing_r)
    p.rel("forearm.L", (X, -0.25))
    p.rel("forearm.R", (X, -0.25))


def trunk(p, side=lambda u: 0.0, curl=lambda u: 0.0):
    """Trunk pose: side(u) and curl(u) give each bone's turn, u running 0 at his face to 1 at the tip.
    side swings it sideways; curl bends it (+ curls the tip in toward his tummy, - lifts it out in front)."""
    for k, b in enumerate(TRUNK_BONES):
        u = k / (TRUNK_N - 1)
        p.rel(b, (Y, side(u)), (X, curl(u)))


def idle(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    trunk(p, lambda u: 0.03 * math.sin(2 * math.pi * t - 2.0 * u),
          lambda u: -0.025 * math.sin(2 * math.pi * t * 2 + 2.4 * u))
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
    trunk(p, lambda u: 0.08 * math.sin(ph - 2.8 * u),                         # swings side to side as he waddles
          lambda u: -0.03 * abs(math.sin(ph - 2.0 * u)))
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


def grab(t):
    """Reach out in front, curl the tip round something, lift it up to have a look, put it back. Played once
    (not looped) in game; anything he picks up hangs off the last trunk bone (trunk.7)."""
    p = idle(0.0)
    reach = ss(0.0, 0.3, t) * (1 - ss(0.85, 1.0, t))                   # trunk out and down in front of him
    wrap = ss(0.3, 0.45, t) * (1 - ss(0.82, 0.95, t))                  # tip curls round the thing
    lift = ss(0.45, 0.7, t) * (1 - ss(0.78, 0.95, t))                  # ...and lifts it up
    trunk(p, curl=lambda u: (-0.3 * (1 - u) + 0.08 * u) * reach - (0.4 * (1 - u) - 0.1 * u) * lift
          + 0.8 * ss(0.45, 1.0, u) * wrap)
    p.rel("spine", (X, 0.08 * reach - 0.05 * lift))                  # leans in to reach, back to admire it
    p.rel("head", (X, 0.12 * reach - 0.1 * lift))
    return p


make_action(rig, "idle", 72, idle)
make_action(rig, "grab", 60, grab)
make_action(rig, "walk", 36, walk)
rest_pose(rig)
finish(OUT)

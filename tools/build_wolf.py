# Builds the skating wolf (Dash's twin brother, who has his conscience and can speak) from scratch: model, materials, rig, weights and animations.
# Reference: the group picture of Sofi's characters (grey-and-white husky-like wolf with ice-blue eyes and a
# snarl, red vest with a metal ring, roller skates on all four paws).
#
#   blender -b --python tools\build_wolf.py
#
# Writes source_art/characters/wolf.blend (overwrites it). Units are meters; skate wheels on the ground at the
# origin; he faces -Y (nose toward -Y). Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "wolf.blend"

K.begin()

# =============================================================================
# Materials (linear colors)
# =============================================================================
mat("Fur", (0.20, 0.21, 0.24), rough=0.75)
mat("Fur Dark", (0.055, 0.06, 0.07), rough=0.75)
mat("Fur White", (0.84, 0.85, 0.87), rough=0.75)
mat("Ear Inner", (0.75, 0.38, 0.40), rough=0.7)
mat("Nose", (0.01, 0.01, 0.012), rough=0.15)
mat("Mouth", (0.18, 0.02, 0.03))
mat("Teeth", (0.92, 0.91, 0.86), rough=0.3)
mat("Brow", (0.03, 0.03, 0.035), rough=0.7)
eye_materials((0.08, 0.40, 0.80), (0.35, 0.75, 0.95))
mat("Vest", (0.45, 0.05, 0.03), rough=0.6)
mat("Strap", (0.12, 0.05, 0.03), rough=0.6)
mat("Metal", (0.60, 0.61, 0.63), rough=0.3, metal=0.9)
mat("Skate", (0.025, 0.045, 0.20), rough=0.45)
mat("Skate Trim", (0.70, 0.70, 0.72), rough=0.4)
mat("Wheel", (0.50, 0.07, 0.025), rough=0.35)

BODY = Ellipsoid((0, 0.06, 0.60), (0.18, 0.34, 0.19))
CHEST = Ellipsoid((0, -0.20, 0.64), (0.165, 0.16, 0.18))
HEAD = Ellipsoid((0, -0.42, 0.93), (0.16, 0.15, 0.145))
SNOUT = Ellipsoid((0, -0.575, 0.87), (0.082, 0.118, 0.068))
HB = ["head"]

# =============================================================================
# Body, chest and neck: grey with a dark saddle on the back, white belly and chest
# =============================================================================
body = ellipsoid("Body", BODY.c, BODY.r, "Fur", ["hips", "chest", ("thigh.L", 1.6), ("thigh.R", 1.6),
                                                  ("upper_front.L", 1.6), ("upper_front.R", 1.6)], u=64, v=32)
paint(body, "Fur Dark", lambda c, n: c.z > BODY.c.z + 0.12)
paint(body, "Fur White", lambda c, n: c.z < BODY.c.z - 0.11)
chest = ellipsoid("Chest", CHEST.c, CHEST.r, "Fur", ["chest", "neck", ("upper_front.L", 1.6), ("upper_front.R", 1.6)],
                  u=48, v=24)
paint(chest, "Fur White", lambda c, n: n.y < -0.35 and c.z < 0.74)
paint(chest, "Fur Dark", lambda c, n: c.z > CHEST.c.z + 0.13)
neck = capsule("Neck", [(0, -0.22, 0.72), (0, -0.36, 0.86)], 0.105, 0.10, "Fur", ["chest", "neck", "head"])
paint(neck, "Fur White", lambda c, n: n.y < -0.3 and n.z < 0.2)
paint(neck, "Fur Dark", lambda c, n: n.z > 0.75)

# Vest: a red jacket around the chest and middle, two dark straps and a metal ring on his chest
vest_y0, vest_y1 = -0.34, 0.12
for ob, ell in ((body, BODY), (chest, CHEST)):
    paint(ob, "Vest", lambda c, n, e=ell: vest_y0 < c.y < vest_y1 and c.z > e.c.z - 0.13
          and not (n.y < -0.5 and c.z < 0.74))


def girth(name, ell, y, offset, w, material, bones):
    """A strap around the body's cross-section at this y."""
    k = math.sqrt(max(1 - ((y - ell.c.y) / ell.r.y) ** 2, 1e-4))
    pts = []
    for i in range(49):
        a = 2 * math.pi * i / 48
        s = Vector((ell.c.x + ell.r.x * k * math.cos(a), y, ell.c.z + ell.r.z * k * math.sin(a)))
        pts.append(s + ell.normal(s) * offset)
    return tube(name, pts, [(w, 0.006)] * len(pts), material, bones, sides=8, caps=False, normal_fn=ell.normal)


girth("Strap Front", BODY, -0.18, 0.008, 0.02, "Strap", ["chest"])
girth("Strap Back", BODY, 0.08, 0.008, 0.02, "Strap", ["hips", "chest"])
ring_at = CHEST.project((0.06, -0.4, 0.70), offset=0.006)
torus("Vest Ring", ring_at, 0.03, 0.009, "Metal", ["chest"], u=24, v=8, rot=basis_facing(CHEST.normal(ring_at)) @
      Euler((math.radians(90), 0, 0)).to_matrix())
ellipsoid("Vest Button", ring_at, (0.018, 0.006, 0.018), "Vest", ["chest"], rot=basis_facing(CHEST.normal(ring_at)))

# Chest ruff: white tufts hanging off the front of the chest
R = rng(5)
for k in range(9):
    x = -0.09 + 0.0225 * k
    s = CHEST.front(x, 0.62 + 0.04 * R.random(), offset=-0.01)
    lock(f"Ruff.{k}", [s, s + Vector((x * 0.2, -0.03, -0.04)), s + Vector((x * 0.4, -0.02, -0.09))], 0.03, "Fur White",
         ["chest"], flat=0.5, normal_fn=lambda p: Vector((0, -1, 0)), sides=8)

# =============================================================================
# Head: skull, tapered snout with a white muzzle, snarling mouth, angry ice-blue eyes, pointed ears
# =============================================================================
head = ellipsoid("Head", HEAD.c, HEAD.r, "Fur", HB, u=48, v=24)
paint(head, "Fur White", lambda c, n: n.y < -0.25 and c.z < 0.93)
paint(head, "Fur Dark", lambda c, n: c.z > 1.0 and not (n.y < -0.5 and c.z < 1.03))
snout = ellipsoid("Snout", SNOUT.c, SNOUT.r, "Fur", HB, u=48, v=24)
for v in snout.data.vertices:                                     # taper toward the nose
    t = max(0.0, (SNOUT.c.y - v.co.y) / SNOUT.r.y)
    v.co.x = SNOUT.c.x + (v.co.x - SNOUT.c.x) * (1 - 0.3 * t)
    v.co.z = SNOUT.c.z + (v.co.z - SNOUT.c.z) * (1 - 0.2 * t)
paint(snout, "Fur White", lambda c, n: c.z < SNOUT.c.z + 0.005)
ellipsoid("Jaw", (0, -0.55, 0.805), (0.06, 0.10, 0.032), "Fur White", HB)
ellipsoid("Nose", (0, -0.705, 0.89), (0.032, 0.024, 0.024), "Nose", HB)

# Snarl: a dark lip line along each side of the snout with teeth hanging from it, fangs near the front
for sx, side in ((1, "L"), (-1, "R")):
    line = []
    for i in range(10):
        y = -0.50 - 0.165 * i / 9
        x = 0.062 * sx * (1 - 0.35 * i / 9)
        line.append(Vector((x, y, 0.828 + 0.006 * math.sin(math.pi * i / 9))))
    tube(f"Lip.{side}", line, [(0.009, 0.006)] * len(line), "Mouth", HB, sides=8)
    for i in range(1, 9):
        p = line[i] + Vector((0, 0, -0.004))
        long_ = i == 7
        lock(f"Tooth.{side}{i}", [p, p + Vector((0, 0, -0.02 if long_ else -0.011))], 0.008 if long_ else 0.0065,
             "Teeth", HB, flat=1.0, tip=0.0015, sides=6)
    # Wrinkles on top of the snout (the snarl)
    for k in range(2):
        y = -0.57 - 0.03 * k
        pts = [Vector((0.015 * sx, y, 0.0)), Vector((0.035 * sx, y + 0.006, 0.0)), Vector((0.05 * sx, y + 0.012, 0.0))]
        pts = [SNOUT.project(Vector((p.x, p.y, SNOUT.c.z + 0.1)), offset=0.002) for p in pts]
        tube(f"Wrinkle.{side}{k}", pts, [(0.004, 0.003)] * 3, "Fur Dark", HB, sides=6)

    # Eyes with heavy lids, and thick brows angled down toward the nose
    ec = HEAD.front(0.07 * sx, 0.955) + Vector((0, 0.012, 0))
    cartoon_eye(side, ec, (0.042, 0.028, 0.038), HB, look=(-0.003 * sx, 0.002), lid="Fur Dark")
    brow = [HEAD.front(sx * (0.03 + 0.09 * t), 0.985 + 0.045 * t, offset=0.006) for t in (i / 6 for i in range(7))]
    tube(f"Brow.{side}", brow, [(0.014 * (0.6 + 0.4 * math.sin(math.pi * (i + 0.5) / 7)), 0.009) for i in range(7)],
         "Brow", HB, sides=8, normal_fn=HEAD.normal)

    # Ears: tall points with pink insides
    base = HEAD.dir_point((0.55 * sx, 0.15, 0.82), offset=-0.015)
    tip = base + Vector((0.045 * sx, 0.015, 0.15))
    lock(f"Ear.{side}", [base, base.lerp(tip, 0.5) + Vector((0.008 * sx, 0, 0)), tip], 0.062, "Fur Dark", HB, flat=0.45,
         tip=0.006, normal_fn=lambda p: Vector((0, -1, 0)), sides=10, taper=1.0)
    lock(f"Ear Inner.{side}", [base + Vector((0, -0.022, 0.01)), tip + Vector((0, -0.016, -0.03))], 0.04, "Ear Inner",
         HB, flat=0.3, tip=0.004, normal_fn=lambda p: Vector((0, -1, 0)), sides=8, taper=1.0)

    # Cheek fluff sweeping back
    for k in range(4):
        s = HEAD.dir_point((0.9 * sx, -0.4 + 0.15 * k, -0.35 + 0.1 * k), offset=-0.01)
        d = Vector((0.7 * sx, 0.6, -0.25 + 0.1 * k)).normalized()
        lock(f"Cheek Fluff.{side}{k}", [s, s + d * 0.04, s + d * 0.075 + Vector((0, 0, -0.01))], 0.035, "Fur White", HB,
             flat=0.5, normal_fn=lambda p: Vector((0, 0, 1)), sides=8)

# =============================================================================
# Legs on roller skates
# =============================================================================
LEGS = {}
for sx, side in ((1, "L"), (-1, "R")):
    x = 0.10 * sx
    front = capsule(f"Front Leg.{side}", [(x, -0.20, 0.60), (x, -0.21, 0.34), (x, -0.19, 0.15)], 0.074, 0.056, "Fur",
                    [("chest", 1.5), f"upper_front.{side}", f"lower_front.{side}"])
    paint(front, "Fur White", lambda c, n: c.z < 0.32 or n.y < -0.6)
    LEGS[f"front.{side}"] = (Vector((x, -0.20, 0.0)), f"paw_front.{side}")
    xh = 0.11 * sx
    ellipsoid(f"Haunch.{side}", (xh, 0.27, 0.52), (0.075, 0.13, 0.135), "Fur", [("hips", 1.2), f"thigh.{side}"])
    hind = capsule(f"Hind Leg.{side}", [(xh, 0.28, 0.54), (xh, 0.22, 0.36), (xh, 0.32, 0.21), (xh, 0.31, 0.15)],
                   0.068, 0.052, "Fur", [("hips", 1.5), f"thigh.{side}", f"shin.{side}"])
    paint(hind, "Fur White", lambda c, n: c.z < 0.27)
    LEGS[f"hind.{side}"] = (Vector((xh, 0.30, 0.0)), f"paw_back.{side}")

for name, (g, bone) in LEGS.items():
    bones = [bone]
    ellipsoid(f"Paw.{name}", g + Vector((0, -0.02, 0.135)), (0.05, 0.065, 0.04), "Fur White", bones)
    ellipsoid(f"Boot.{name}", g + Vector((0, -0.02, 0.105)), (0.062, 0.09, 0.06), "Skate", bones, power=0.55)
    ellipsoid(f"Boot Toe.{name}", g + Vector((0, -0.075, 0.085)), (0.058, 0.05, 0.038), "Skate Trim", bones)
    torus(f"Boot Cuff.{name}", g + Vector((0, -0.015, 0.155)), 0.05, 0.012, "Skate Trim", bones, u=24, v=8)
    ellipsoid(f"Plate.{name}", g + Vector((0, -0.02, 0.058)), (0.045, 0.10, 0.012), "Skate Trim", bones, power=0.35)
    ellipsoid(f"Toe Stop.{name}", g + Vector((0, -0.125, 0.04)), (0.022, 0.022, 0.024), "Wheel", bones)
    for wy in (-0.08, 0.04):
        for wx in (-1, 1):
            c = g + Vector((0.038 * wx, wy, 0.034))
            cylinder(f"Wheel.{name}{wy}{wx}", c - Vector((0.012, 0, 0)), c + Vector((0.012, 0, 0)), 0.034, "Wheel",
                     bones, sides=16)

# =============================================================================
# Tail: big, bushy, curling up behind him with a white tip
# =============================================================================
tail_ctrl = [(0, 0.36, 0.67), (0, 0.48, 0.74), (0, 0.57, 0.86), (0, 0.58, 0.99), (0, 0.52, 1.07)]
tail = lock("Tail", tail_ctrl, 0.08, "Fur", ["tail1", "tail2"], flat=0.85, tip=0.02, sides=16, taper=0.45,
            normal_fn=lambda p: Vector((1, 0, 0)))
paint(tail, "Fur White", lambda c, n: c.z > 0.99)
paint(tail, "Fur Dark", lambda c, n: 0.80 < c.z < 0.99 and n.y > 0.3)

# =============================================================================
# Rig, skin, animations
#   For bones that point forward (chest, neck, head), +X tips them down; legs point down: -X swings forward.
# =============================================================================
BONES = {
    "root": ((0, 0.06, 0), (0, 0.06, 0.2), None),
    "hips": ((0, 0.30, 0.62), (0, 0.06, 0.62), "root"),
    "chest": ((0, 0.06, 0.62), (0, -0.22, 0.66), "hips"),
    "neck": ((0, -0.22, 0.68), (0, -0.36, 0.86), "chest"),
    "head": ((0, -0.36, 0.86), (0, -0.66, 0.90), "neck"),
    "tail1": ((0, 0.36, 0.67), (0, 0.57, 0.86), "hips"),
    "tail2": ((0, 0.57, 0.86), (0, 0.52, 1.07), "tail1"),
}
for sx, side in ((1, "L"), (-1, "R")):
    x, xh = 0.10 * sx, 0.11 * sx
    BONES.update({
        f"upper_front.{side}": ((x, -0.20, 0.60), (x, -0.21, 0.34), "chest"),
        f"lower_front.{side}": ((x, -0.21, 0.34), (x, -0.19, 0.15), f"upper_front.{side}"),
        f"paw_front.{side}": ((x, -0.19, 0.15), (x, -0.30, 0.10), f"lower_front.{side}"),
        f"thigh.{side}": ((xh, 0.28, 0.56), (xh, 0.22, 0.36), "hips"),
        f"shin.{side}": ((xh, 0.22, 0.36), (xh, 0.32, 0.20), f"thigh.{side}"),
        f"paw_back.{side}": ((xh, 0.32, 0.20), (xh, 0.21, 0.10), f"shin.{side}"),
    })


# Stocky, short-legged build: squash the legs by lowering everything above them (meshes and bones alike)
LEG_DROP = 0.11


def squash(p):
    return Vector((p[0], p[1], p[2] - LEG_DROP * ss(0.16, 0.42, p[2])))


for ob, _ in K.PARTS:
    for v in ob.data.vertices:
        v.co = squash(v.co)
BONES = {n: (tuple(squash(h)), tuple(squash(t)), par) for n, (h, t, par) in BONES.items()}
rig = build_rig("WolfRig", BONES)
skin_and_join(rig, BONES, "Wolf", "Body")


def idle(t):
    # Standing guard: slow breathing, a little head shake while he growls, tail flicking
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    p.rel("chest", (X, 0.015 * s))
    p.rel("neck", (X, -0.02 * s))
    p.rel("head", (Z, 0.05 * math.sin(4 * math.pi * t)), (X, 0.02 * s))
    p.rel("tail1", (Z, 0.12 * s))
    p.rel("tail2", (Z, 0.18 * math.sin(2 * math.pi * t - 0.7)))
    for side in ("L", "R"):
        p.set_abs(f"paw_front.{side}", Matrix.Identity(3))           # skates stay flat on the ground
        p.set_abs(f"paw_back.{side}", Matrix.Identity(3))
    return p


def skate(t):
    # Gliding: hind legs take turns pushing out and back, body sways, head low and forward, tail streaming
    ph = 2 * math.pi * t
    s = math.sin(ph)
    p = Pose(BONES)
    p.rel("hips", (Y, 0.06 * s), (X, -0.04))
    p.rel("chest", (Z, -0.05 * s), (X, 0.05))
    p.rel("neck", (X, 0.18))
    p.rel("head", (X, -0.1), (Z, 0.03 * s))
    p.rel("tail1", (X, 0.45), (Z, 0.1 * s))
    p.rel("tail2", (X, 0.3), (Z, 0.15 * s))
    for side, sx in (("L", 1), ("R", -1)):
        push = max(0.0, s * sx)                                      # left pushes on one half, right on the other
        p.rel(f"thigh.{side}", (X, 0.45 * push), (Y, -0.3 * push * sx))
        p.rel(f"shin.{side}", (X, -0.1 * push))
        p.rel(f"upper_front.{side}", (X, -0.12 + 0.08 * s * sx))
        p.rel(f"lower_front.{side}", (X, 0.1))
        p.set_abs(f"paw_front.{side}", Matrix.Identity(3))
        p.set_abs(f"paw_back.{side}", Matrix.Identity(3))
    p.offset = Vector((0.02 * s, 0, -0.01 * abs(s)))
    return p


def growl(t):
    # Head down, shoulders forward, tail stiff, a shiver of anger
    shiver = 0.02 * math.sin(12 * math.pi * t)
    p = Pose(BONES)
    p.rel("chest", (X, 0.10))
    p.rel("neck", (X, 0.35))
    p.rel("head", (X, -0.25 + shiver))
    p.rel("tail1", (X, 0.15))
    p.rel("tail2", (X, 0.1), (Z, shiver))
    for side in ("L", "R"):
        p.rel(f"upper_front.{side}", (X, 0.15))
        p.rel(f"lower_front.{side}", (X, -0.25))
        p.rel(f"thigh.{side}", (X, -0.1))
        p.set_abs(f"paw_front.{side}", Matrix.Identity(3))
        p.set_abs(f"paw_back.{side}", Matrix.Identity(3))
    p.offset = Vector((0, 0, -0.03))
    return p


make_action(rig, "idle", 60, idle)
make_action(rig, "skate", 36, skate)
make_action(rig, "growl", 30, growl)
rest_pose(rig)
finish(OUT)

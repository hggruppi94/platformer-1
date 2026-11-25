# Builds Hermez the crane from scratch: model, materials, rig, weights and animations (the Meshy trial's "control":
# made our usual way, beside Rolo the rhino, who was made with Meshy; Nov 25, 2026). From Sofi's show notes: "a
# red-crowned crane: a red-crowned, white-and-grey bird by a lily pond". He's a grown-up crane in the friends' chunky
# style: a round white body, a long black-and-white neck under a big round head with a red cap, a long yellow-grey
# beak, big friendly brown eyes, white wings he uses as arms with black flight-feather tips, a fluffy black bustle
# behind, long thin grey legs with knobbly knees and three-toed feet. Hermez is a messenger name, so he wears a little
# teal satchel across his chest (it gives the wardrobe a part to recolour, like the friends' bags).
#
#   blender -b --python tools\build_hermez.py
#   then: powershell -File tools\export_all.ps1 hermez   (or tools/build_friend_detail.py hermez for the baked detail)
#
# Writes source_art/characters/hermez.blend (overwrites it). Units are meters; feet at the origin; he faces -Y.
# Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "hermez.blend"

K.begin()

# =============================================================================
# Materials (linear colours)
# =============================================================================
mat("Feather", (0.80, 0.80, 0.82), rough=0.85)          # white plumage
mat("Feather Grey", (0.42, 0.43, 0.47), rough=0.85)     # soft grey on the wing coverts and back
mat("Feather Black", (0.025, 0.025, 0.03), rough=0.8)   # neck, flight feathers and bustle
mat("Crown", (0.72, 0.03, 0.03), rough=0.6)             # the red crown
mat("Beak", (0.48, 0.42, 0.22), rough=0.4)              # yellowish horn
mat("Beak Tip", (0.20, 0.19, 0.14), rough=0.4)
mat("Leg", (0.12, 0.12, 0.13), rough=0.6)               # dark grey scaly legs
mat("Brow", (0.02, 0.02, 0.02))
mat("Mouth", (0.22, 0.02, 0.03))
mat("Satchel", (0.02, 0.28, 0.30), rough=0.7)           # teal canvas
mat("Satchel Strap", (0.20, 0.08, 0.03), rough=0.6)     # brown leather
mat("Metal", (0.6, 0.45, 0.12), rough=0.3, metal=1.0)   # brass buckle
mat("Blush", (0.62, 0.26, 0.26), rough=0.8)
eye_materials((0.10, 0.04, 0.01), (0.35, 0.16, 0.04))   # warm brown eyes

HB = ["head"]
NB = ["neck", ("head", 2.0)]

# =============================================================================
# Head: big and round, with a red cap on top and a long beak in front
# =============================================================================
HEAD = Ellipsoid((0, -0.04, 1.40), (0.155, 0.17, 0.15))
ellipsoid("Head", HEAD.c, HEAD.r, "Feather", HB, u=48, v=24)
# The red crown: a skin cap over the top front of the head, the crane's famous red patch
crown = ellipsoid("Crown", HEAD.c + Vector((0, -0.02, 0.012)), HEAD.r + Vector((0.006, 0.006, 0.006)), "Crown", HB,
                  u=48, v=24, keep_above=0.52)
# (Real red-crowned cranes have a black face and throat; here the black starts under his chin, down the neck,
# so his face stays open and friendly.)

# The beak: long, straight and a bit chunky (it's a kids' game), pointing forward and a touch down
BEAK_ROOT = Vector((0, -0.19, 1.37))
BEAK_TIP = Vector((0, -0.46, 1.32))
beak_pts = [BEAK_ROOT.lerp(BEAK_TIP, t) for t in (0, 0.25, 0.5, 0.75, 0.92, 1.0)]
tube("Beak", beak_pts, [(0.045, 0.038), (0.038, 0.032), (0.03, 0.025), (0.021, 0.018), (0.012, 0.011),
                        (0.003, 0.003)], "Beak", HB, sides=16)
tip_pts = [BEAK_ROOT.lerp(BEAK_TIP, t) for t in (0.8, 0.9, 1.0)]
tube("Beak Tip", tip_pts, [(0.0165, 0.0145), (0.0105, 0.0098), (0.0035, 0.0035)], "Beak Tip", HB, sides=16)
# A thin dark line where the two halves of the beak meet, curling up into a small smile at the root
line = [BEAK_ROOT.lerp(BEAK_TIP, t) + Vector((0, 0, -0.004)) for t in (0.04, 0.3, 0.6, 0.85)]
for sx, side in ((1, "L"), (-1, "R")):
    pts = [p + Vector((0.0345 * sx * (1 - t), 0, 0)) for p, t in zip(line, (0.0, 0.3, 0.6, 0.85))]
    pts.insert(0, pts[0] + Vector((0.012 * sx, 0.02, 0.016)))
    tube(f"Beak Line.{side}", pts, [(0.0035, 0.0035)] * len(pts), "Mouth", HB, sides=6)
    # Little nostril slits near the root
    ns = BEAK_ROOT + Vector((0.025 * sx, -0.06, 0.02))
    ellipsoid(f"Nostril.{side}", ns, (0.004, 0.014, 0.004), "Beak Tip", HB)

# Eyes: big and friendly, on the sides of the front so he looks straight at you, with a soft brow over each
for sx, side in ((1, "L"), (-1, "R")):
    ec = HEAD.front(0.075 * sx, 1.43, offset=-0.022)
    cartoon_eye(side, ec, (0.048, 0.036, 0.055), HB, look=(0.0, 0.002))
    arc_on(HEAD, f"Brow.{side}", [(sx * (0.035 + 0.08 * t), 1.505 + 0.018 * math.sin(math.pi * t) - 0.01 * t)
                                  for t in (i / 8 for i in range(9))], 0.008, "Brow", HB, offset=0.004)
    bc = HEAD.front(0.115 * sx, 1.355, offset=0.002)
    ellipsoid(f"Blush.{side}", bc, (0.026, 0.008, 0.017), "Blush", HB, rot=basis_facing(HEAD.normal(bc)))
# A tuft of white feathers on the back of his head, so the silhouette isn't a plain ball
for k, (dx, dz) in enumerate(((0.0, 0.0), (0.04, -0.02), (-0.04, -0.02))):
    lock(f"Head Tuft.{k}", [(dx, 0.08, 1.48 + dz), (dx * 1.3, 0.16, 1.47 + dz), (dx * 1.5, 0.21, 1.43 + dz)],
         0.035, "Feather", HB, flat=0.5, tip=0.006)

# =============================================================================
# Neck: long and S-curved, black down the front and white at the back
# =============================================================================
NECK_PATH = [(0, 0.03, 0.96), (0, 0.035, 1.07), (0, 0.0, 1.18), (0, -0.035, 1.28)]
capsule("Neck", NECK_PATH, 0.075, 0.065, "Feather Black", NB)
capsule("Neck Back", [(0, 0.06, 0.98), (0, 0.065, 1.08), (0, 0.035, 1.18), (0, 0.01, 1.27)], 0.062, 0.05,
        "Feather", NB)

# =============================================================================
# Body: a round white body leaning a little forward, grey on the back, a black bustle of feathers behind
# =============================================================================
BODY = Ellipsoid((0, 0.04, 0.78), (0.24, 0.30, 0.25))
TB = ["hips", "spine", "chest", ("thigh.L", 2.2), ("thigh.R", 2.2)]
ellipsoid("Body", BODY.c, BODY.r, "Feather", TB, u=64, v=32)
# A soft grey saddle of feathers over his back
ellipsoid("Back", BODY.c + Vector((0, 0.06, 0.06)), BODY.r * 0.97, "Feather Grey", ["spine", "chest"], u=48, v=24,
          keep_above=0.35)
# The bustle: long drooping black feathers over his tail, like a ruffled skirt
for k in range(9):
    a = math.radians(-64 + 16 * k)
    root = Vector((0.15 * math.sin(a), 0.22 + 0.06 * math.cos(a), 0.80))
    tip = Vector((0.24 * math.sin(a), 0.42 + 0.04 * math.cos(a), 0.52 + 0.04 * abs(math.sin(a))))
    lock(f"Bustle.{k}", [root, root.lerp(tip, 0.4) + Vector((0, 0.06, 0.02)), tip, tip + Vector((0, -0.02, -0.05))],
         0.07, "Feather Black", ["hips", ("spine", 2.0)], flat=0.45, tip=0.012,
         normal_fn=lambda p: Vector((p.x, 0.6, 0.4)).normalized() if abs(p.x) > 1e-3 else Vector((0, 0.6, 0.4)))
# White tail feathers peeking out under the bustle
for k in range(5):
    x = -0.08 + 0.04 * k
    lock(f"Tail.{k}", [(x, 0.3, 0.72), (x * 1.2, 0.42, 0.66), (x * 1.3, 0.5, 0.62)], 0.045, "Feather", ["hips"],
         flat=0.4, tip=0.01, normal_fn=lambda p: Vector((0, 0, 1)))

# The satchel: a little teal bag on his left hip, its strap over his right shoulder
SAT = Vector((0.2, -0.1, 0.62))
ellipsoid("Satchel", SAT, (0.06, 0.1, 0.085), "Satchel", ["hips", ("spine", 1.5)], power=0.55,
          rot=Euler((0, 0, math.radians(-60))).to_matrix())
ellipsoid("Satchel Flap", SAT + Vector((0.035, -0.02, 0.04)), (0.03, 0.1, 0.06), "Satchel",
          ["hips", ("spine", 1.5)], power=0.55, rot=Euler((0, math.radians(20), math.radians(-60))).to_matrix())
ellipsoid("Buckle", SAT + Vector((0.065, -0.045, 0.02)), (0.012, 0.02, 0.016), "Metal", ["hips"])
strap = [BODY.project(Vector(p), offset=0.022) for p in
         ((0.18, -0.12, 0.66), (0.09, -0.24, 0.78), (-0.03, -0.25, 0.90), (-0.15, -0.16, 1.00), (-0.2, 0.0, 1.02),
          (-0.15, 0.2, 0.96), (0.0, 0.3, 0.84), (0.14, 0.2, 0.70))]
tube("Strap", strap, [(0.02, 0.005)] * len(strap), "Satchel Strap", ["chest", "spine", "hips"], sides=6,
     normal_fn=BODY.normal)

# =============================================================================
# Wings, used as arms: white feathered arms with grey coverts, black flight-feather "fingers" at the ends
# =============================================================================
SH, EL, WR, TIP = (0.21, 0.02, 0.92), (0.29, -0.0, 0.76), (0.34, -0.03, 0.62), (0.37, -0.05, 0.52)
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda p: Vector((p[0] * sx, p[1], p[2]))
    sh, el, wr, tp = m(SH), m(EL), m(WR), m(TIP)
    AB = [f"upper_arm.{side}", f"forearm.{side}"]
    capsule(f"Wing.{side}", [sh, el, wr], 0.075, 0.055, "Feather", AB)
    # Flat feather blades hanging along the back edge of the wing, longer towards the hand
    for k in range(6):
        t = k / 5
        root = sh.lerp(el, min(1.0, t * 2)) if t < 0.5 else el.lerp(wr, (t - 0.5) * 2)
        root = root + Vector((0, 0.04, 0))
        down = Vector((0.03 * sx, 0.05, -0.14 - 0.06 * t))
        lock(f"Covert.{side}{k}", [root, root + down * 0.5, root + down], 0.05, "Feather Grey",
             [f"upper_arm.{side}" if t < 0.5 else f"forearm.{side}"], flat=0.35, tip=0.01,
             normal_fn=lambda p, sx=sx: Vector((sx, 0, 0)))
    # The black flight feathers spread like fingers: what he waves, points and holds letters with
    hd = (tp - wr).normalized()
    for j in range(4):
        spread = Vector(((j - 1.5) * 0.02 * sx, 0.012 * (j - 1.5), 0))
        base = wr + hd * 0.02 + spread * 0.5
        end = tp + hd * (0.07 + 0.02 * (j % 2)) + spread * 2.0
        lock(f"Primary.{side}{j}", [base, base.lerp(end, 0.5), end], 0.045, "Feather Black", [f"hand.{side}"],
             flat=0.45, tip=0.006, normal_fn=lambda p, sx=sx: Vector((sx, 0, 0)))
    ellipsoid(f"Wrist Fluff.{side}", wr, (0.06, 0.055, 0.06), "Feather", [f"forearm.{side}", f"hand.{side}"])

# =============================================================================
# Legs: long, thin and grey, with knobbly knees and three big front toes and a little back toe
# =============================================================================
HIP_X, KNEE, ANKLE = 0.1, 0.30, 0.07
for sx, side in ((1, "L"), (-1, "R")):
    x = HIP_X * sx
    # White feathered thighs (the "trousers") tucked under the body
    capsule(f"Thigh.{side}", [(x, 0.03, 0.62), (x, 0.0, 0.48)], 0.075, 0.05, "Feather",
            [("hips", 1.6), f"thigh.{side}"])
    capsule(f"Leg.{side}", [(x, 0.0, 0.5), (x, 0.0, KNEE), (x, 0.0, ANKLE)], 0.024, 0.02, "Leg",
            [f"thigh.{side}", f"shin.{side}"], sides=12)
    ellipsoid(f"Knee.{side}", (x, 0.0, KNEE), (0.033, 0.033, 0.035), "Leg", [f"thigh.{side}", f"shin.{side}"])
    for j, ang in enumerate((-30, 0, 30)):
        a = math.radians(ang)
        tip = Vector((x + 0.11 * math.sin(a), -0.13 * math.cos(a), 0.018))
        capsule(f"Toe.{side}{j}", [(x, -0.01, 0.04), tip], 0.022, 0.014, "Leg", [f"foot.{side}"], sides=10)
        ellipsoid(f"Claw.{side}{j}", tip + Vector((0.008 * math.sin(a), -0.012 * math.cos(a), -0.003)),
                  (0.009, 0.014, 0.008), "Beak Tip", [f"foot.{side}"])
    capsule(f"Back Toe.{side}", [(x, 0.0, 0.05), (x, 0.07, 0.02)], 0.016, 0.01, "Leg", [f"foot.{side}"], sides=10)

# =============================================================================
# Rig: the friends' biped layout (same bone names) with an extra neck bone between the chest and the head
# =============================================================================
BONES = biped_bones(hips=0.62, chest=0.90, neck=1.27, head_top=1.58, shoulder=SH, elbow=EL, wrist=WR, hand_tip=TIP,
                    hip_x=HIP_X, knee=KNEE, ankle=ANKLE, toe=(-0.13, 0.02))
BONES["chest"] = ((0, 0, 0.90), (0, 0.04, 0.97), "spine")
_rest = {k: v for k, v in BONES.items() if k not in ("root", "hips", "spine", "chest", "head")}
BONES = {k: BONES[k] for k in ("root", "hips", "spine", "chest")}    # parents before children, for build_rig()
BONES["neck"] = ((0, 0.04, 0.97), (0, -0.035, 1.28), "chest")
BONES["head"] = ((0, -0.035, 1.28), (0, -0.04, 1.58), "neck")
BONES.update(_rest)
rig = build_rig("HermezRig", BONES)
skin_and_join(rig, BONES, "Hermez", "Body")


def wings_down(p, flap=0.0, extra_l=(), extra_r=(), bend=0.25):
    # Wings resting at his sides; flap > 0 lifts them out
    p.rel("upper_arm.L", (Y, 0.32 - flap), *extra_l)
    p.rel("upper_arm.R", (Y, -0.32 + flap), *extra_r)
    p.rel("forearm.L", (X, -bend), (Y, -0.4 * flap))
    p.rel("forearm.R", (X, -bend), (Y, 0.4 * flap))


def idle(t):
    # Standing tall by his pond: breathing, his head bobbing and turning to look about, and once a loop he gives
    # his wings a happy little flap and shake
    ph = 2 * math.pi * t
    s = math.sin(ph)
    p = Pose(BONES)
    flap = 0.9 * max(0.0, math.sin(math.pi * ss(0.55, 0.85, t))) * (0.75 + 0.25 * math.sin(8 * ph))
    wings_down(p, flap)
    p.rel("spine", (X, 0.03 + 0.015 * s))
    p.rel("chest", (X, -0.02 * s))
    p.rel("neck", (X, 0.06 * math.sin(2 * ph)), (Z, 0.12 * math.sin(ph + 0.6)))
    p.rel("head", (X, -0.05 * math.sin(2 * ph) - 0.03), (Z, 0.1 * math.sin(ph + 0.6)), (Y, 0.05 * s))
    p.offset = Vector((0, 0, 0.006 * s + 0.01 * flap))
    return p


def walk(t):
    # A crane's careful high-stepping walk, the head pumping back and forth with each step
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.42 * s - 0.12 * max(0.0, -c)))
    p.rel("thigh.R", (X, 0.42 * s - 0.12 * max(0.0, c)))
    p.rel("shin.L", (X, 0.08 + 0.7 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.08 + 0.7 * max(0.0, c)))
    p.rel("foot.L", (X, -0.18 * s))
    p.rel("foot.R", (X, 0.18 * s))
    wings_down(p, 0.08, [(X, 0.2 * s)], [(X, -0.2 * s)])
    p.rel("spine", (X, 0.08), (Z, 0.04 * s))
    p.rel("chest", (Z, 0.04 * s))
    pump = math.sin(2 * ph)
    p.rel("neck", (X, 0.12 * pump + 0.06))
    p.rel("head", (X, -0.12 * pump - 0.06), (Z, -0.05 * s))
    p.offset = Vector((0, 0, 0.022 * abs(s)))
    return p


def run(t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.7 * s))
    p.rel("thigh.R", (X, 0.7 * s))
    p.rel("shin.L", (X, 0.25 + 0.8 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.25 + 0.8 * max(0.0, c)))
    wings_down(p, 0.9 + 0.5 * math.sin(2 * ph))        # wings out, flapping as he hurries along
    p.rel("spine", (X, 0.2))
    p.rel("neck", (X, 0.35))
    p.rel("head", (X, -0.35))
    p.offset = Vector((0, 0, 0.04 * abs(s)))
    return p


def flap(t):
    # A big wave of both wings: hello! (and what he does when a letter arrives)
    ph = 2 * math.pi * t
    k = 0.5 + 0.5 * math.sin(2 * ph - math.pi / 2)
    p = Pose(BONES)
    wings_down(p, 0.2 + 1.5 * k)
    p.rel("spine", (X, -0.04))
    p.rel("neck", (X, -0.1 * k))
    p.rel("head", (X, 0.05 * k))
    p.offset = Vector((0, 0, 0.04 * k))
    return p


def jump(t):
    k = ss(0, 1, t)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.5 * k))
    p.rel("thigh.R", (X, -0.3 * k))
    p.rel("shin.L", (X, 0.9 * k))
    p.rel("shin.R", (X, 0.6 * k))
    wings_down(p, 1.4 * k)
    p.rel("neck", (X, -0.12 * k))
    return p


def fall(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.25 + 0.1 * s))
    p.rel("thigh.R", (X, -0.25 - 0.1 * s))
    p.rel("shin.L", (X, 0.4))
    p.rel("shin.R", (X, 0.4))
    wings_down(p, 1.3 + 0.3 * math.sin(4 * math.pi * t))
    return p


make_action(rig, "idle", 90, idle)
make_action(rig, "walk", 36, walk)
make_action(rig, "run", 20, run)
make_action(rig, "flap", 30, flap)
make_action(rig, "jump", 10, jump)
make_action(rig, "fall", 24, fall)
rest_pose(rig)
finish(OUT)

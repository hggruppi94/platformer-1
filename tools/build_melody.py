# Builds Melody, the capybara girl in purple, from scratch: model, materials, rig, weights and animations.
# Reference: Hayden's picture of her (Nov 7, 2026; a copy is in source_art/reference/Melody - capybara girl.jpg) and
# Sofi's show notes ("a capybara girl with an auburn ponytail, a purple dress and Mary Janes, with lots of
# expressions; her music is upbeat pop"): golden-brown fur, a big blunt capybara snout with a dark nose pad, little
# round ears, big blue eyes with lashes, an auburn quiff rolled up off her forehead and a high ponytail with a purple
# scrunchie, a purple short-sleeved polo dress (collar, button placket, A-line skirt), white ankle socks and black
# Mary Janes. She's chubby and cheerful: her idle is the picture's pose, both hands at her chest, delighted.
#
#   blender -b --python tools\build_melody.py
#
# Writes source_art/characters/melody.blend (overwrites it). Units are meters; feet at the origin; she faces -Y.
# Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "melody.blend"

K.begin()

# =============================================================================
# Materials (linear colours picked from the picture)
# =============================================================================
mat("Fur", (0.40, 0.17, 0.05), rough=0.8)             # golden brown
mat("Fur Dark", (0.24, 0.10, 0.04), rough=0.8)        # the snout and paws are a shade darker
mat("Nose", (0.09, 0.045, 0.03), rough=0.45)          # the dark leathery nose pad
mat("Nostril", (0.02, 0.01, 0.008))
mat("Ear Inner", (0.13, 0.05, 0.03), rough=0.8)
mat("Mouth", (0.22, 0.02, 0.03))
mat("Tongue", (0.85, 0.22, 0.27))
mat("Brow", (0.06, 0.02, 0.01))
mat("Hair", (0.30, 0.09, 0.02), rough=0.45)           # auburn
mat("Hair Shine", (0.55, 0.20, 0.05), rough=0.35)
mat("Scrunchie", (0.24, 0.10, 0.62), rough=0.7)
mat("Dress", (0.26, 0.12, 0.56), rough=0.8)           # soft purple
mat("Dress Dark", (0.17, 0.07, 0.40), rough=0.85)
mat("Button", (0.40, 0.25, 0.75), rough=0.4)
mat("Sock", (0.86, 0.86, 0.84), rough=0.9)
mat("Shoe", (0.012, 0.012, 0.014), rough=0.18)        # shiny black patent
mat("Sole", (0.03, 0.03, 0.03), rough=0.7)
mat("Blush", (0.62, 0.22, 0.20), rough=0.8)
eye_materials((0.01, 0.06, 0.32), (0.10, 0.35, 0.85))  # blue eyes

HB = ["head"]

# =============================================================================
# Head: a round skull with a big, tall, blunt capybara snout in front
# =============================================================================
HEAD = Ellipsoid((0, 0.03, 1.15), (0.235, 0.245, 0.235))
SNOUT = Ellipsoid((0, -0.2, 1.065), (0.17, 0.235, 0.158))
ellipsoid("Head", HEAD.c, HEAD.r, "Fur", HB, u=48, v=24)
ellipsoid("Snout", SNOUT.c, SNOUT.r, "Fur", HB, u=64, v=32)
# Cheeks: soft round puffs where the snout meets the head, so the face is chubby
for sx, side in ((1, "L"), (-1, "R")):
    ellipsoid(f"Cheek.{side}", (0.13 * sx, -0.12, 1.02), (0.105, 0.12, 0.1), "Fur", HB)

# The nose pad: a dark, wide, flat-topped shape across the top front of the snout, with two slit nostrils
NOSE_C = SNOUT.front(0.0, 1.13, offset=-0.012)
ellipsoid("Nose", NOSE_C, (0.095, 0.02, 0.05), "Nose", HB, rot=basis_facing(SNOUT.normal(NOSE_C)), power=0.8)
for sx, side in ((1, "L"), (-1, "R")):
    ns = SNOUT.front(0.045 * sx, 1.13, offset=0.014)
    ellipsoid(f"Nostril.{side}", ns, (0.016, 0.006, 0.01), "Nostril", HB,
              rot=basis_facing(SNOUT.normal(ns)) @ Euler((0, math.radians(-25 * sx), 0)).to_matrix())

# Her big open happy smile on the lower front of the snout, tongue showing (the picture's "Eee!")
smile("Mouth", SNOUT, 0.0, 1.005, 0.085, 0.07, HB, tongue=True, curl=0.02, offset=0.003)
# The split upper lip: a little groove from the nose pad down to the smile
arc_on(SNOUT, "Lip Line", [(0.0, 1.085), (0.0, 1.06), (0.0, 1.035), (0.0, 1.012)], 0.005, "Nostril", HB)

# Eyes: big and blue, set high on the front of her head above the snout, with lashes at the outer corners
for sx, side in ((1, "L"), (-1, "R")):
    ec = HEAD.front(0.112 * sx, 1.205, offset=-0.03)
    cartoon_eye(side, ec, (0.06, 0.045, 0.068), HB, look=(0.0, 0.004))
    for k, (dx, dz, ang) in enumerate(((0.055, 0.05, 25), (0.068, 0.032, 5), (0.074, 0.012, -15))):
        base = HEAD.project(ec + Vector((dx * sx, -0.01, dz)), offset=0.001)
        tip = base + Vector((0.03 * sx * math.cos(math.radians(ang)), -0.004, 0.03 * math.sin(math.radians(ang)) + 0.006))
        tube(f"Lash.{side}{k}", [base, base.lerp(tip, 0.5), tip], [(0.007, 0.005), (0.005, 0.003), (0.0015, 0.0015)],
             "Brow", HB, sides=6)
    # A soft lid line over the top of the eye, and a thin arched brow above it
    lid = [HEAD.project(ec + Vector((0.064 * math.cos(a) * sx, -0.012, 0.072 * math.sin(a))), offset=0.002)
           for a in (math.radians(20 + 140 * i / 10) for i in range(11))]
    tube(f"Lid Line.{side}", lid, [(0.004, 0.004)] * len(lid), "Brow", HB, sides=6)
    arc_on(HEAD, f"Brow.{side}", [(sx * (0.06 + 0.11 * t), 1.305 + 0.025 * math.sin(math.pi * t) - 0.012 * t)
                                  for t in (i / 8 for i in range(9))], 0.009, "Brow", HB, offset=0.004)
    # Blush on the cheek puffs
    bc = Vector((0.175 * sx, -0.2, 1.06))
    ellipsoid(f"Blush.{side}", bc, (0.04, 0.012, 0.028), "Blush", HB,
              rot=basis_facing(Vector((0.55 * sx, -1, 0.1)).normalized()))
    # Little round capybara ears, high on the back of her head, darker inside
    ear = Vector((0.185 * sx, 0.12, 1.33))
    er = Euler((0, math.radians(-35 * sx), math.radians(-25 * sx))).to_matrix()
    ellipsoid(f"Ear.{side}", ear, (0.055, 0.03, 0.05), "Fur", HB, rot=er)
    ellipsoid(f"Ear Inner.{side}", ear + er @ Vector((0, -0.017, -0.004)), (0.036, 0.012, 0.032), "Ear Inner", HB,
              rot=er)

# =============================================================================
# Hair: an auburn quiff rolled up off her forehead, swept back, and a high ponytail with a purple scrunchie
# =============================================================================
HAIR = Ellipsoid(HEAD.c, HEAD.r + Vector((0.02, 0.02, 0.02)))
scalp_cap("Hair Cap", HEAD, "Hair", HB, thick=0.02, hairline=lambda x: 1.30 + 0.04 * (abs(x) / 0.2) ** 2,
          bottom=1.06)
# The quiff: a fat roll across the top front, a little higher on her right, with locks sweeping back over the crown
roll = smooth_path([(-0.17, -0.07, 1.33), (-0.08, -0.15, 1.39), (0.04, -0.16, 1.41), (0.15, -0.1, 1.38),
                    (0.19, -0.02, 1.34)], per_segment=8)
tube("Quiff", roll, [(0.05 + 0.025 * math.sin(math.pi * i / (len(roll) - 1)),) * 2 for i in range(len(roll))],
     "Hair", HB, sides=16)
for k in range(7):
    x0 = -0.15 + 0.05 * k
    lock(f"Swept.{k}", [(x0, -0.12, 1.4), (x0 * 0.9, -0.02, 1.43), (x0 * 0.7, 0.1, 1.4), (x0 * 0.5 + 0.06, 0.17, 1.33)],
         0.04, "Hair", HB, flat=0.5, tip=0.01, normal_fn=lambda p: HAIR.normal(p))
# A curl falling over the right of her forehead, and a wave down by each cheek
lock("Fore Curl", [(-0.09, -0.17, 1.37), (-0.13, -0.21, 1.33), (-0.12, -0.23, 1.29), (-0.09, -0.215, 1.285)],
     0.028, "Hair", HB, flat=0.6, tip=0.006)
for sx, side in ((1, "L"), (-1, "R")):
    lock(f"Side Wave.{side}", [(0.17 * sx, -0.07, 1.32), (0.23 * sx, -0.05, 1.22), (0.235 * sx, -0.03, 1.12),
                               (0.215 * sx, -0.06, 1.05)], 0.035, "Hair", HB, flat=0.55, tip=0.008,
         normal_fn=lambda p, sx=sx: Vector((sx, -0.2, 0)).normalized())
# A shine streak along the quiff
lock("Quiff Shine", [(-0.06, -0.205, 1.41), (0.03, -0.215, 1.43), (0.11, -0.17, 1.42)], 0.012, "Hair Shine", HB,
     flat=0.4, tip=0.004, normal_fn=lambda p: Vector((0, -0.6, 1)).normalized())

# The ponytail sits high at the back on her left, bouncing (its own bone), in big glossy curls
PT_ROOT = Vector((0.1, 0.22, 1.3))
torus("Scrunchie", (0, 0, 0), 0.05, 0.026, "Scrunchie", ["ponytail"])
D = bpy.data
scr = D.objects["Scrunchie"]
scr.data.transform(Matrix.Translation(PT_ROOT) @ Euler((math.radians(70), 0, math.radians(-25))).to_matrix().to_4x4())
for k, (dx, dz, end) in enumerate(((0.0, 0.0, (0.2, 0.4, 0.93)), (0.035, -0.02, (0.26, 0.34, 0.96)),
                                   (-0.03, 0.01, (0.13, 0.42, 0.97)))):
    # Three fat, overlapping waves that read as one big glossy ponytail, curling up a little at the ends
    e = Vector(end)
    mid = PT_ROOT + Vector((0.07 + dx, 0.11, dz - 0.02))
    lock(f"Ponytail.{k}", [PT_ROOT + Vector((0, 0.02, 0)), mid, mid.lerp(e, 0.55) + Vector((0.05 - dx, 0.03, 0)), e,
                           e + Vector((-0.03, -0.03, 0.025))], 0.095 - 0.012 * k, "Hair", ["ponytail"], flat=0.85,
         tip=0.02, sides=14, taper=0.6)


# =============================================================================
# Body: a chubby torso in her purple polo dress, puffed short sleeves, the A-line skirt
# =============================================================================
TORSO = Ellipsoid((0, 0, 0.66), (0.245, 0.215, 0.27))
TB = ["hips", "spine", "chest", ("thigh.L", 1.8), ("thigh.R", 1.8)]
ellipsoid("Torso", TORSO.c, TORSO.r, "Dress", TB, u=64, v=32)
capsule("Neck", [(0, 0.0, 0.86), (0, 0.0, 0.98)], 0.12, 0.12, "Fur", ["chest", "head"])

# The skirt flares out from the waist to just below her knees
SK = [(0.60, 0.236, 0.205), (0.54, 0.255, 0.225), (0.46, 0.28, 0.25), (0.38, 0.305, 0.272), (0.31, 0.322, 0.288),
      (0.295, 0.322, 0.288)]
tube("Skirt", [(0, 0, z) for z, _, _ in SK], [(ry, rx) for _, rx, ry in SK], "Dress",
     ["hips", ("thigh.L", 1.6), ("thigh.R", 1.6)], sides=40)
hem = [Vector((0.322 * math.cos(a), 0.288 * math.sin(a), 0.30)) for a in (2 * math.pi * k / 48 for k in range(49))]
tube("Hem", hem, [(0.01, 0.01)] * len(hem), "Dress Dark", ["hips", ("thigh.L", 1.6), ("thigh.R", 1.6)], sides=6,
     caps=False)

# The polo collar: two pointed flaps folded down at the neck, and a placket with three buttons
ring_on("Collar Band", TORSO, 0.88, 0.006, 0.016, "Dress", ["chest"], steps=40)
for sx, side in ((1, "L"), (-1, "R")):
    fc = TORSO.front(0.065 * sx, 0.845, offset=0.012)
    ellipsoid(f"Collar.{side}", fc, (0.07, 0.009, 0.045), "Dress", ["chest"],
              rot=basis_facing(TORSO.normal(fc)) @ Euler((0, math.radians(35 * sx), 0)).to_matrix(), power=0.6)
placket = [TORSO.front(0.0, z, 0.004) for z in (0.86, 0.82, 0.78, 0.74, 0.70)]
tube("Placket", placket, [(0.02, 0.003)] * len(placket), "Dress Dark", ["chest", "spine"], sides=6,
     normal_fn=TORSO.normal)
for k, z in enumerate((0.835, 0.785, 0.735)):
    bp = TORSO.front(0.0, z, 0.008)
    ellipsoid(f"Button.{k}", bp, (0.012, 0.005, 0.012), "Button", ["chest"], rot=basis_facing(TORSO.normal(bp)))

# Arms (A-pose): puffed purple short sleeves over furry arms, darker paws with little fingers
SH, EL, WR, TIP = (0.225, 0, 0.82), (0.305, -0.03, 0.69), (0.37, -0.05, 0.58), (0.405, -0.065, 0.51)
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda p: Vector((p[0] * sx, p[1], p[2]))
    sh, el, wr = m(SH), m(EL), m(WR)
    capsule(f"Arm.{side}", [sh, el, wr], 0.062, 0.052, "Fur", [f"upper_arm.{side}", f"forearm.{side}"])
    mid = sh.lerp(el, 0.55)
    capsule(f"Sleeve.{side}", [sh + Vector((-0.02 * sx, 0, 0.01)), mid], 0.088, 0.08, "Dress",
            [f"upper_arm.{side}", ("chest", 1.6)])
    d = (el - sh).normalized()
    torus(f"Sleeve Hem.{side}", mid, 0.078, 0.012, "Dress Dark", [f"upper_arm.{side}"],
          rot=d.to_track_quat('Z', 'Y').to_matrix())
    hd = (wr - el).normalized()
    paw = wr + hd * 0.04
    ellipsoid(f"Paw.{side}", paw, (0.055, 0.045, 0.06), "Fur Dark", [f"hand.{side}"],
              rot=hd.to_track_quat('-Z', 'Y').to_matrix())
    for j in range(3):
        fp = paw + hd * 0.05 + Vector(((j - 1) * 0.024 * sx, -0.02, 0))
        ellipsoid(f"Finger.{side}{j}", fp, (0.016, 0.016, 0.022), "Fur Dark", [f"hand.{side}"])
    ellipsoid(f"Thumb.{side}", paw + Vector((0.0, -0.045, 0.02)), (0.018, 0.022, 0.025), "Fur Dark", [f"hand.{side}"])

# Legs: short chubby furry legs, white ankle socks, black patent Mary Janes with a strap and a button
for sx, side in ((1, "L"), (-1, "R")):
    x = 0.11 * sx
    LB = [("hips", 1.6), f"thigh.{side}", f"shin.{side}"]
    capsule(f"Leg.{side}", [(x, 0, 0.48), (x, 0, 0.3), (x, -0.005, 0.13)], 0.095, 0.072, "Fur", LB)
    capsule(f"Sock.{side}", [(x, -0.005, 0.16), (x, -0.01, 0.085)], 0.078, 0.074, "Sock", [f"shin.{side}", f"foot.{side}"])
    torus(f"Sock Cuff.{side}", (x, -0.005, 0.165), 0.076, 0.018, "Sock", [f"shin.{side}"])
    ellipsoid(f"Shoe.{side}", (x, -0.05, 0.055), (0.08, 0.125, 0.058), "Shoe", [f"foot.{side}"], power=0.75)
    ellipsoid(f"Sole.{side}", (x, -0.05, 0.016), (0.085, 0.13, 0.018), "Sole", [f"foot.{side}"], power=0.5)
    strap = [Vector((x + 0.075 * math.cos(a), -0.035 - 0.012 * math.sin(a), 0.07 + 0.045 * math.sin(a)))
             for a in (math.pi * k / 12 for k in range(13))]
    tube(f"Strap.{side}", strap, [(0.012, 0.005)] * len(strap), "Shoe", [f"foot.{side}"], sides=6,
         normal_fn=lambda p, x=x: Vector((p.x - x, 0, p.z - 0.07)).normalized() if abs(p.x - x) + abs(p.z - 0.07) > 1e-4
         else Vector((0, 0, 1)))
    ellipsoid(f"Shoe Button.{side}", (x + 0.078 * sx, -0.035, 0.075), (0.008, 0.012, 0.012), "Sock", [f"foot.{side}"])

# =============================================================================
# Rig, skin, animations
# =============================================================================
BONES = biped_bones(hips=0.50, chest=0.76, neck=0.90, head_top=1.45, shoulder=SH, elbow=EL, wrist=WR, hand_tip=TIP,
                    hip_x=0.11, knee=0.30, ankle=0.10, toe=(-0.15, 0.04))
BONES["ponytail"] = (tuple(PT_ROOT), (0.2, 0.4, 0.93), "head")
rig = build_rig("MelodyRig", BONES)
skin_and_join(rig, BONES, "Melody", "Torso")


def tail_swing(p, t, amount=1.0, phase=0.0):
    s = math.sin(2 * math.pi * t + phase)
    p.rel("ponytail", (X, 0.12 * s * amount), (Y, 0.08 * math.cos(2 * math.pi * t + phase) * amount))


def hands_at_chest(p, wiggle=0.0):
    # Both paws up at her chest, the picture's delighted pose (two-bone IK to a spot in front of her collar)
    for sx, side in ((1, "L"), (-1, "R")):
        p.ik(f"upper_arm.{side}", f"forearm.{side}", (0.07 * sx, -0.25, 0.79 + wiggle), (sx, 0.2, -1.0))
        p.aim(f"hand.{side}", Vector((-0.4 * sx, -0.3, 1.0)))


def idle(t):
    # Delighted: paws at her chest, swaying side to side to a song only she can hear, ponytail bouncing
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    p.rel("spine", (Y, 0.04 * s))
    p.rel("chest", (Y, 0.03 * s), (X, -0.02))
    p.rel("head", (Y, -0.08 * s), (X, -0.05))
    hands_at_chest(p, 0.006 * math.sin(4 * math.pi * t))
    tail_swing(p, t, 0.8, 0.9)
    p.offset = Vector((0, 0, 0.006 * math.sin(4 * math.pi * t)))
    return p


def walk(t):
    p = biped_walk(BONES, t, stride=0.38, arm=0.3, bob=0.02)
    tail_swing(p, t * 2, 0.9)
    return p


def run(t):
    p = biped_run(BONES, t)
    tail_swing(p, t * 2, 1.4)
    return p


def jump(t):
    k = ss(0, 1, t)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.5 * k))
    p.rel("thigh.R", (X, -0.3 * k))
    p.rel("shin.L", (X, 0.9 * k))
    p.rel("shin.R", (X, 0.6 * k))
    p.rel("upper_arm.L", (Y, 0.38 - 1.4 * k))
    p.rel("upper_arm.R", (Y, -0.38 + 1.4 * k))
    p.rel("forearm.L", (X, -0.3))
    p.rel("forearm.R", (X, -0.3))
    p.rel("head", (X, -0.12 * k))
    p.rel("ponytail", (X, -0.3 * k))
    return p


def fall(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.25 + 0.15 * s))
    p.rel("thigh.R", (X, -0.25 - 0.15 * s))
    p.rel("shin.L", (X, 0.45))
    p.rel("shin.R", (X, 0.45))
    p.rel("upper_arm.L", (Y, -1.0 + 0.15 * s))
    p.rel("upper_arm.R", (Y, 1.0 + 0.15 * s))
    p.rel("forearm.L", (X, -0.5))
    p.rel("forearm.R", (X, -0.5))
    p.rel("ponytail", (X, -0.5))
    return p


def dance(t):
    # Her upbeat pop dance: bouncing on the beat, hips popping side to side, one arm up then the other
    ph = 2 * math.pi * t
    s = math.sin(ph)
    b = abs(math.sin(2 * ph))
    p = Pose(BONES)
    p.rel("hips", (Y, 0.12 * s))
    p.rel("spine", (Y, -0.08 * s))
    p.rel("chest", (Y, -0.06 * s))
    p.rel("head", (Y, 0.1 * s), (X, -0.06))
    up_l, up_r = max(0.0, s), max(0.0, -s)
    p.rel("upper_arm.L", (Y, 0.38 - 2.1 * up_l), (X, -0.2 * up_l))
    p.rel("upper_arm.R", (Y, -0.38 + 2.1 * up_r), (X, -0.2 * up_r))
    p.rel("forearm.L", (X, -0.4 - 0.5 * (1 - up_l)))
    p.rel("forearm.R", (X, -0.4 - 0.5 * (1 - up_r)))
    p.rel("thigh.L", (X, -0.15 * b))
    p.rel("thigh.R", (X, -0.15 * b))
    p.rel("shin.L", (X, 0.3 * b))
    p.rel("shin.R", (X, 0.3 * b))
    tail_swing(p, t * 2, 1.6)
    p.offset = Vector((0, 0, 0.04 * b - 0.02))
    return p


def sass(t):
    # Arms crossed, head tilted, eyes half-closed: "Mm-hm. Sure." (one of her picture's faces)
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    for sx, side in ((1, "L"), (-1, "R")):
        p.ik(f"upper_arm.{side}", f"forearm.{side}", (-0.09 * sx, -0.31, 0.7 + 0.025 * sx), (sx, -0.6, -0.6))
        p.aim(f"hand.{side}", Vector((-sx, -0.2, 0.1)))
    p.rel("spine", (X, -0.04))
    p.rel("head", (Y, 0.16 + 0.03 * s), (X, 0.05))
    p.rel("hips", (Y, -0.06))
    tail_swing(p, t, 0.4)
    return p


make_action(rig, "idle", 60, idle)
make_action(rig, "walk", 32, walk)
make_action(rig, "run", 20, run)
make_action(rig, "jump", 10, jump)
make_action(rig, "fall", 24, fall)
make_action(rig, "dance", 40, dance)
make_action(rig, "sass", 60, sass)
rest_pose(rig)
finish(OUT)

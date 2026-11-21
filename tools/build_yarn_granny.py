# Builds the yarn granny: a little old Void lady who knits, with her goblin pet on her shoulder. Hayden gave a TV still
# as inspiration (Nov 21, 2026) and asked for a character of our own, not a copy, so only the broad idea is kept (a
# purple-skinned granny in a dark knitted dress with pearls, a curly grey bun with knitting needles through it, yarn
# wound round her, and a little green creature on her shoulder) and everything else is ours: a soft cartoon face in the
# game's style (big kind eyes, rosy cheeks, a round nose, a closed smile), a long ribbed dress, a half-knitted
# striped scarf on her needles with its yarn running down to a ball in her apron pocket, little button boots, and a
# cute goblin with big ears and bigger eyes who peeks round her head.
#
#   blender -b --python tools\build_yarn_granny.py
#
# Writes source_art/characters/yarn_granny.blend (overwrites it) with idle (knitting) / walk / run / jump / fall /
# wave / chuckle actions. Units are meters; feet at the origin; she faces -Y. Helpers: tools/char_kit.py.
# She's a small grown-up, about 1.55 m to the top of her bun, a little stooped.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "yarn_granny.blend"

K.begin()

# =============================================================================
# Materials (linear colours)
# =============================================================================
mat("Skin", (0.36, 0.25, 0.58), rough=0.6)            # soft lavender-purple
mat("Skin Shade", (0.26, 0.17, 0.45), rough=0.6)
mat("Blush", (0.70, 0.24, 0.42), rough=0.7)
mat("Nose", (0.42, 0.27, 0.62), rough=0.55)
mat("Brow", (0.32, 0.32, 0.34), rough=0.6)
mat("Mouth", (0.20, 0.04, 0.08))
mat("Hair", (0.46, 0.45, 0.47), rough=0.65)           # silver-grey curls
mat("Hair Dark", (0.30, 0.29, 0.31), rough=0.7)
mat("Needle", (0.75, 0.46, 0.14), rough=0.35)         # wooden knitting needles
mat("Needle Knob", (0.55, 0.08, 0.22), rough=0.35)
mat("Knit", (0.035, 0.028, 0.05), rough=0.9)          # the dark knitted dress
mat("Knit Rib", (0.06, 0.05, 0.085), rough=0.9)
mat("Apron", (0.30, 0.12, 0.40), rough=0.85)          # a plum apron with a pocket
mat("Pearl", (0.88, 0.84, 0.74), rough=0.18)
mat("Yarn Gold", (0.85, 0.40, 0.04), rough=0.9)
mat("Yarn Cream", (0.88, 0.82, 0.68), rough=0.9)
mat("Scarf A", (0.10, 0.55, 0.45), rough=0.9)         # the scarf she's knitting: teal and pink stripes
mat("Scarf B", (0.85, 0.30, 0.50), rough=0.9)
mat("Boot", (0.02, 0.015, 0.02), rough=0.3)
mat("Boot Button", (0.70, 0.55, 0.20), rough=0.3, metal=0.5)
mat("Goblin", (0.20, 0.50, 0.12), rough=0.6)
mat("Goblin Light", (0.45, 0.72, 0.28), rough=0.6)
mat("Goblin Ear", (0.70, 0.45, 0.48), rough=0.6)
mat("Tooth", (0.95, 0.93, 0.85), rough=0.3)
mat("Tongue", (0.85, 0.30, 0.35))
eye_materials((0.05, 0.22, 0.14), (0.20, 0.55, 0.35))  # her kind green eyes (the goblin's are yellow, below)
mat("Goblin Iris", (0.85, 0.55, 0.02), rough=0.08)

HB = ["head"]

# =============================================================================
# Rig layout first (her shapes follow it)
# =============================================================================
SH, EL, WR, TIP = (0.2, 0.0, 1.08), (0.27, -0.02, 0.9), (0.31, -0.04, 0.74), (0.33, -0.05, 0.66)
BONES = biped_bones(hips=0.74, chest=0.98, neck=1.13, head_top=1.5, shoulder=SH, elbow=EL, wrist=WR, hand_tip=TIP,
                    hip_x=0.09, knee=0.4, ankle=0.08, toe=(-0.12, 0.03))
# The goblin sits on her left shoulder: a body bone and a head bone of his own, so he can peek about
PET = Vector((0.2, 0.04, 1.14))
BONES["pet"] = (tuple(PET), tuple(PET + Vector((0, 0, 0.1))), "chest")
BONES["pet_head"] = (tuple(PET + Vector((0, 0, 0.1))), tuple(PET + Vector((0, 0, 0.24))), "pet")
BONES["bun"] = ((0, 0.1, 1.42), (0, 0.13, 1.6), "head")

# =============================================================================
# Head and face
# =============================================================================
HEAD = Ellipsoid((0, 0.0, 1.3), (0.145, 0.14, 0.16))
ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HB, u=48, v=24)
# Soft round cheeks and a little double chin
for sx, side in ((1, "L"), (-1, "R")):
    ellipsoid(f"Cheek.{side}", (0.075 * sx, -0.075, 1.24), (0.065, 0.06, 0.055), "Skin", HB)
ellipsoid("Chin", (0, -0.08, 1.18), (0.07, 0.05, 0.04), "Skin", HB)
capsule("Neck", [(0, 0.0, 1.08), (0, 0.0, 1.18)], 0.07, 0.07, "Skin", ["chest", "head"])
# Ears, with little pearl drops
for sx, side in ((1, "L"), (-1, "R")):
    ear = Vector((0.142 * sx, 0.0, 1.29))
    ellipsoid(f"Ear.{side}", ear, (0.02, 0.035, 0.045), "Skin", HB)
    ellipsoid(f"Earring.{side}", ear + Vector((0.008 * sx, -0.01, -0.055)), (0.012, 0.012, 0.014), "Pearl", HB)

# The face: kind eyes under heavy happy lids, grey brows, rosy cheeks, a round nose and a closed smile with crinkles
FACE = Ellipsoid(HEAD.c, HEAD.r)
for sx, side in ((1, "L"), (-1, "R")):
    ec = FACE.front(0.058 * sx, 1.32, offset=-0.022)
    cartoon_eye(side, ec, (0.034, 0.03, 0.036), HB, look=(0.0, -0.004))
    # A soft lid line over the top of each eye (no frown: a lid tilted in toward the nose reads as cross)
    lid = [FACE.project(ec + Vector((0.038 * math.cos(a) * sx, -0.03, 0.04 * math.sin(a))), offset=0.002)
           for a in (math.radians(20 + 140 * i / 10) for i in range(11))]
    tube(f"Lid Line.{side}", lid, [(0.004, 0.004)] * len(lid), "Skin Shade", HB, sides=6)
    arc_on(FACE, f"Brow.{side}", [(sx * (0.03 + 0.06 * t), 1.385 + 0.014 * math.sin(math.pi * t) - 0.016 * t)
                                  for t in (i / 8 for i in range(9))], 0.008, "Brow", HB, offset=0.004)
    # Crinkles at the corner of each eye: she's always smiling
    for k, a in enumerate((-20, 0, 20)):
        r0 = Vector((0.1 * sx, 0, 1.32 + 0.006 * math.sin(math.radians(a))))
        arc_on(FACE, f"Crinkle.{side}{k}", [(r0.x + 0.022 * sx * t * math.cos(math.radians(a)),
                                              r0.z + 0.022 * t * math.sin(math.radians(a))) for t in (0, 0.5, 1)],
               0.003, "Skin Shade", HB, offset=0.002)
    bc = Vector((0.085 * sx, -0.11, 1.245))
    ellipsoid(f"Blush.{side}", bc, (0.03, 0.01, 0.02), "Blush", HB,
              rot=basis_facing(Vector((0.5 * sx, -1, 0)).normalized()))
nose = FACE.front(0, 1.27, offset=0.012)
ellipsoid("Nose", nose, (0.03, 0.028, 0.028), "Nose", HB)
arc_on(FACE, "Smile", [(0.058 * math.cos(math.pi * (0.08 + 0.84 * t)), 1.212 - 0.024 * math.sin(math.pi * t))
                       for t in (i / 10 for i in range(11))], 0.006, "Mouth", HB, offset=0.004)
for sx, side in ((1, "L"), (-1, "R")):
    arc_on(FACE, f"Smile Line.{side}", [(0.066 * sx + 0.008 * sx * t, 1.235 - 0.02 * t) for t in (0, 0.5, 1)],
           0.003, "Skin Shade", HB, offset=0.003)

# =============================================================================
# Hair: tight silver curls all round, swept up into a big curly bun with two knitting needles through it
# =============================================================================
scalp_cap("Hair Cap", HEAD, "Hair", HB, thick=0.018, hairline=lambda x: 1.39 + 0.05 * (abs(x) / 0.14) ** 2,
          bottom=1.22)
r = K.rng(7)
HAIR = Ellipsoid(HEAD.c, HEAD.r + Vector((0.03, 0.03, 0.03)))
k = 0
for row, z in enumerate((1.25, 1.3, 1.35, 1.4)):
    n = 12 + row * 2
    for i in range(n):
        a = math.pi * 2 * i / n + row * 0.3
        d = Vector((math.cos(a), math.sin(a), (z - HEAD.c.z) / HEAD.r.z * 1.2))
        if d.y < -0.35 and z < 1.42:        # keep the curls off her face
            continue
        p = HAIR.dir_point(d, offset=-0.004)
        s = 0.028 + 0.008 * r.random()
        ellipsoid(f"Curl.{k}", p, (s, s, s * 0.9), "Hair" if r.random() < 0.75 else "Hair Dark", HB, u=12, v=8)
        k += 1
# A fringe of little curls across the top of her forehead
for i in range(7):
    x = -0.09 + 0.03 * i
    p = FACE.front(x, 1.41 + 0.01 * math.cos(x * 20), offset=0.012)
    ellipsoid(f"Fringe.{i}", p, (0.026, 0.022, 0.022), "Hair", HB, u=12, v=8)
# The bun: a cluster of curls on the back of her crown
BUN = Vector((0, 0.08, 1.49))
BB = ["bun"]
ellipsoid("Bun", BUN, (0.075, 0.07, 0.065), "Hair", BB, u=24, v=12)
for i in range(14):
    d = Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-0.3, 1))).normalized()
    p = BUN + Vector((d.x * 0.07, d.y * 0.065, d.z * 0.06))
    s = 0.03 + 0.008 * r.random()
    ellipsoid(f"Bun Curl.{i}", p, (s, s, s), "Hair" if i % 3 else "Hair Dark", BB, u=12, v=8)
# Two knitting needles crossed through the bun, with knobs on the ends
for sx, side in ((1, "L"), (-1, "R")):
    a = BUN + Vector((-0.06 * sx, 0.02, -0.05))
    b = BUN + Vector((0.07 * sx, -0.01, 0.15))
    cylinder(f"Hair Needle.{side}", a, b, 0.0065, "Needle", BB, sides=8)
    ellipsoid(f"Hair Knob.{side}", b, (0.015, 0.015, 0.015), "Needle Knob", BB, u=12, v=8)

# =============================================================================
# Body: a little round body in a long knitted dress, ribbed all the way down, a plum apron with a pocket
# =============================================================================
TORSO = Ellipsoid((0, 0.01, 0.92), (0.2, 0.17, 0.24))
TB = ["hips", "spine", "chest", ("thigh.L", 1.8), ("thigh.R", 1.8)]
ellipsoid("Torso", TORSO.c, TORSO.r, "Knit", TB, u=48, v=24)
# The skirt falls from the waist to her ankles, flaring a little
SK = [(0.82, 0.2, 0.17), (0.7, 0.225, 0.195), (0.55, 0.245, 0.215), (0.38, 0.262, 0.232), (0.22, 0.275, 0.245),
      (0.1, 0.285, 0.255), (0.09, 0.285, 0.255)]
SKB = ["hips", ("thigh.L", 1.6), ("thigh.R", 1.6), ("shin.L", 2.5), ("shin.R", 2.5)]
tube("Skirt", [(0, 0.01, z) for z, _, _ in SK], [(ry, rx) for _, rx, ry in SK], "Knit", SKB, sides=40)


def skirt_r(z):
    for (z0, rx0, ry0), (z1, rx1, ry1) in zip(SK, SK[1:]):
        if z1 <= z <= z0:
            t = (z0 - z) / (z0 - z1)
            return rx0 + (rx1 - rx0) * t, ry0 + (ry1 - ry0) * t
    return SK[-1][1], SK[-1][2]


# Knit ribs down the skirt
for i in range(28):
    a = 2 * math.pi * i / 28
    pts = []
    for z in [0.8 - 0.07 * j for j in range(11)]:
        rx, ry = skirt_r(z)
        pts.append(Vector((rx * math.cos(a), 0.01 + ry * math.sin(a), z)))
    tube(f"Rib.{i}", pts, [(0.006, 0.006)] * len(pts), "Knit Rib", SKB, sides=5)
hem = [Vector((0.287 * math.cos(a), 0.01 + 0.257 * math.sin(a), 0.1)) for a in (2 * math.pi * k / 48 for k in range(49))]
tube("Hem", hem, [(0.014, 0.014)] * len(hem), "Knit Rib", SKB, sides=6, caps=False)

# The apron: a panel down her front from waist to knee with a big pocket, a tie round her waist
apron = []
for i in range(9):
    z = 0.84 - 0.06 * i
    rx, ry = skirt_r(min(z, 0.82))
    row = []
    for j in range(11):
        a = math.radians(-90 + (j - 5) * 9 * (1 + 0.04 * i))
        row.append(Vector(((rx + 0.008) * math.cos(a), 0.01 + (ry + 0.008) * math.sin(a), z)))
    apron.append(row)
bm = K.bmesh.new()
vs = [[bm.verts.new(p) for p in row] for row in apron]
for r0, r1 in zip(vs, vs[1:]):
    for j in range(len(r0) - 1):
        bm.faces.new((r0[j], r0[j + 1], r1[j + 1], r1[j]))
ap = K.new_obj("Apron", bm, "Apron", SKB)
ap.modifiers.new("Solid", 'SOLIDIFY').thickness = 0.008
ring_on("Apron Tie", Ellipsoid((0, 0.01, 0.82), (0.2, 0.17, 0.3)), 0.83, 0.008, 0.012, "Apron", ["hips", "spine"])
# The pocket, and the yarn ball peeking out of it
PK = Vector((0.08, -0.215, 0.6))
ellipsoid("Pocket", PK, (0.075, 0.012, 0.06), "Apron", SKB, power=0.5,
          rot=basis_facing(Vector((0.3, -1, 0)).normalized()))
BALL = PK + Vector((0.0, -0.02, 0.06))
ellipsoid("Yarn Ball", BALL, (0.05, 0.045, 0.05), "Yarn Cream", ["hips"], u=20, v=10)
for i in range(6):
    t = Euler((r.uniform(0, 3), r.uniform(0, 3), r.uniform(0, 3))).to_matrix()
    torus(f"Ball Wrap.{i}", BALL, 0.049, 0.004, "Yarn Cream", ["hips"], u=28, v=4, rot=t)

# Yarn wound round her middle: three loose gold loops with a wobble, like she's been tangled up in it
for i in range(3):
    zc = 0.84 + 0.07 * i
    pts = []
    for k in range(41):
        a = 2 * math.pi * k / 40
        rr = 1.0 + 0.04 * math.sin(3 * a + i)
        z = zc + 0.03 * math.sin(a + i * 1.3) - 0.04 * (k / 40)
        e = TORSO if z > 0.82 else Ellipsoid((0, 0.01, 0.82), (0.205, 0.175, 0.3))
        p = _ring_pt = K._ring_point(e, a, max(min(z, 1.05), 0.75), 0.01) if True else None
        pts.append(Vector((p.x * rr, p.y * rr, z)))
    tube(f"Yarn Loop.{i}", pts, [(0.007, 0.007)] * len(pts), "Yarn Gold", ["hips", "spine", "chest"], sides=6,
         caps=False)

# A V neck with a little collar, and two strands of pearls
for sx, side in ((1, "L"), (-1, "R")):
    c = TORSO.front(0.04 * sx, 1.07, offset=0.01)
    ellipsoid(f"Collar.{side}", c, (0.06, 0.008, 0.03), "Knit Rib", ["chest"],
              rot=basis_facing(TORSO.normal(c)) @ Euler((0, math.radians(-40 * sx), 0)).to_matrix(), power=0.6)
for strand, (drop, bead, count) in enumerate(((0.08, 0.013, 21), (0.15, 0.016, 25))):
    for i in range(count):
        t = i / (count - 1)
        a = math.pi * (0.1 + 0.8 * t)
        x = 0.11 * math.cos(a)
        z = 1.1 - drop * math.sin(a)
        p = TORSO.front(x, z, offset=0.016 + 0.003 * strand)
        ellipsoid(f"Pearl.{strand}.{i}", p, (bead, bead, bead), "Pearl", ["chest"], u=10, v=6)

# Arms in long knitted sleeves with ribbed cuffs, purple hands
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda p: Vector((p[0] * sx, p[1], p[2]))
    sh, el, wr = m(SH), m(EL), m(WR)
    capsule(f"Sleeve.{side}", [sh + Vector((-0.03 * sx, 0, 0.0)), el, wr], 0.065, 0.05, "Knit",
            [f"upper_arm.{side}", f"forearm.{side}", ("chest", 1.6)])
    d = (wr - el).normalized()
    torus(f"Cuff.{side}", wr - d * 0.02, 0.05, 0.012, "Knit Rib", [f"forearm.{side}"],
          rot=d.to_track_quat('Z', 'Y').to_matrix())
    hd = d
    hand = wr + hd * 0.045
    ellipsoid(f"Hand.{side}", hand, (0.038, 0.03, 0.045), "Skin", [f"hand.{side}"],
              rot=hd.to_track_quat('-Z', 'Y').to_matrix())
    for j in range(4):
        fp = hand + hd * 0.045 + Vector(((j - 1.5) * 0.016 * sx, -0.012, 0))
        ellipsoid(f"Finger.{side}{j}", fp, (0.009, 0.009, 0.022), "Skin", [f"hand.{side}"],
                  rot=hd.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", hand + Vector((-0.012 * sx, -0.032, 0.012)), (0.011, 0.015, 0.016), "Skin",
              [f"hand.{side}"])
    # Each hand holds a knitting needle, pointing forward and in
    nd = Vector((-0.6 * sx, -1.0, 0.25)).normalized()
    a = hand + Vector((0, -0.02, 0)) - nd * 0.07
    b = hand + nd * 0.17
    cylinder(f"Needle.{side}", a, b, 0.0055, "Needle", [f"hand.{side}"], sides=8)
    ellipsoid(f"Needle Knob.{side}", a, (0.012, 0.012, 0.012), "Needle Knob", [f"hand.{side}"], u=10, v=6)

# The half-knitted scarf hangs down in front of her tummy, under her needles, in teal and pink stripes, its yarn
# trailing to the ball in her pocket. It follows her body, not her hands: a hand turns a long way as it knits, and a
# scarf swinging round with it read as a plank sticking out of her chest.
SC = Vector((0.0, -0.27, 0.8))
SCB = ["spine", ("hips", 1.5)]
for i in range(8):
    z = SC.z - 0.03 * i
    ellipsoid(f"Scarf.{i}", (SC.x + 0.004 * math.sin(i), SC.y + 0.004 * i, z), (0.055, 0.01, 0.017),
              "Scarf A" if i % 2 == 0 else "Scarf B", SCB, power=0.55)
tube("Scarf Yarn", smooth_path([SC + Vector((0.03, 0.006, -0.22)), SC + Vector((0.06, 0.02, -0.25)),
                                BALL + Vector((-0.02, -0.03, 0.03))], per_segment=6),
     [(0.004, 0.004)] * 13, "Yarn Cream", ["hips"], sides=5)

# Little black button boots peeking out under the hem
for sx, side in ((1, "L"), (-1, "R")):
    x = 0.09 * sx
    ellipsoid(f"Boot.{side}", (x, -0.05, 0.05), (0.055, 0.1, 0.05), "Boot", [f"foot.{side}"], power=0.75)
    capsule(f"Boot Top.{side}", [(x, -0.01, 0.06), (x, 0.0, 0.14)], 0.05, 0.048, "Boot", [f"shin.{side}", f"foot.{side}"])
    for j in range(3):
        ellipsoid(f"Boot Button.{side}{j}", (x + 0.045 * sx, -0.04, 0.06 + 0.025 * j), (0.007, 0.007, 0.007),
                  "Boot Button", [f"shin.{side}", f"foot.{side}"], u=8, v=4)

# =============================================================================
# The goblin pet on her left shoulder: big round head, huge pointy ears, huge yellow eyes, a cheeky one-tooth grin
# =============================================================================
PB, PH = ["pet"], ["pet_head"]
ellipsoid("Goblin Body", PET + Vector((0, 0.0, 0.05)), (0.05, 0.045, 0.06), "Goblin", PB)
ellipsoid("Goblin Belly", PET + Vector((0, -0.03, 0.045)), (0.034, 0.02, 0.04), "Goblin Light", PB)
GH = Ellipsoid(PET + Vector((0, -0.01, 0.17)), (0.07, 0.065, 0.065))
ellipsoid("Goblin Head", GH.c, GH.r, "Goblin", PH, u=32, v=16)
for sx, side in ((1, "L"), (-1, "R")):
    # The ears: long leaves sticking out sideways and a little up, pink inside
    base = GH.c + Vector((0.06 * sx, 0.01, 0.01))
    tip = base + Vector((0.11 * sx, 0.02, 0.05))
    lock(f"Goblin Ear.{side}", [base, base.lerp(tip, 0.5) + Vector((0, 0, 0.012)), tip], 0.035, "Goblin", PH,
         flat=0.3, tip=0.003, normal_fn=lambda p: Vector((0, -1, 0.2)).normalized())
    lock(f"Goblin Ear In.{side}", [base + Vector((0, -0.008, 0)), base.lerp(tip, 0.5) + Vector((0, -0.01, 0.01)),
                                   tip + Vector((-0.02 * sx, -0.006, -0.008))], 0.022, "Goblin Ear", PH,
         flat=0.3, tip=0.002, normal_fn=lambda p: Vector((0, -1, 0.2)).normalized())
    ec = GH.front(0.03 * sx, GH.c.z + 0.012, offset=-0.012)
    ellipsoid(f"Goblin Eye.{side}", ec, (0.024, 0.02, 0.026), "Eye White", PH)
    ellipsoid(f"Goblin Iris.{side}", ec + Vector((0, -0.016, -0.002)), (0.017, 0.006, 0.019), "Goblin Iris", PH)
    ellipsoid(f"Goblin Pupil.{side}", ec + Vector((0, -0.021, -0.002)), (0.009, 0.004, 0.012), "Pupil", PH)
    ellipsoid(f"Goblin Shine.{side}", ec + Vector((0.006, -0.024, 0.008)), (0.004, 0.002, 0.004), "Eye Shine", PH)
    # Little arms holding on to her shoulder, and his feet tucked under
    capsule(f"Goblin Arm.{side}", [PET + Vector((0.035 * sx, -0.02, 0.07)), PET + Vector((0.05 * sx, -0.06, 0.02))],
            0.013, 0.011, "Goblin", PB, sides=10)
    ellipsoid(f"Goblin Paw.{side}", PET + Vector((0.05 * sx, -0.065, 0.012)), (0.016, 0.014, 0.012), "Goblin Light", PB)
    ellipsoid(f"Goblin Foot.{side}", PET + Vector((0.03 * sx, -0.03, -0.005)), (0.018, 0.026, 0.012), "Goblin Light", PB)
ellipsoid("Goblin Nose", GH.front(0, GH.c.z - 0.012, offset=0.006), (0.012, 0.01, 0.01), "Goblin Light", PH)
smile("Goblin Mouth", GH, 0.0, GH.c.z - 0.03, 0.03, 0.018, PH, tongue=True, curl=0.01, offset=0.002)
tp = GH.front(0.01, GH.c.z - 0.033, offset=0.003)
ellipsoid("Goblin Tooth", tp + Vector((0, 0, -0.005)), (0.006, 0.003, 0.007), "Tooth", PH)
lock("Goblin Tail", [PET + Vector((0, 0.04, 0.02)), PET + Vector((0.03, 0.1, -0.03)), PET + Vector((0.0, 0.14, -0.1)),
                     PET + Vector((-0.03, 0.12, -0.14))], 0.012, "Goblin", PB, flat=1.0, tip=0.004)

# =============================================================================
# Rig, skin, animations
# =============================================================================
rig = build_rig("GrannyRig", BONES)
skin_and_join(rig, BONES, "YarnGranny", "Torso")


def stoop(p, amount=1.0):
    p.rel("spine", (X, 0.05 * amount))
    p.rel("chest", (X, 0.04 * amount))


def knitting(p, t, speed=2.0):
    # Both hands in front of her tummy, the needles clicking: the hands take turns to dip and push
    ph = 2 * math.pi * t * speed
    for sx, side in ((1, "L"), (-1, "R")):
        dip = 0.02 * math.sin(ph + (0 if sx > 0 else math.pi))
        p.ik(f"upper_arm.{side}", f"forearm.{side}", (0.07 * sx, -0.27, 0.82 + dip), (sx, 0.3, -1.0))
        p.aim(f"hand.{side}", Vector((-0.7 * sx, -0.8, 0.1 + 3 * dip)))


def pet_peek(p, t, look=1.0):
    # The goblin looks about: left, right, a little bob, a quick peek round her head now and then
    s = math.sin(2 * math.pi * t)
    peek = ss(0.55, 0.65, t) * (1 - ss(0.8, 0.9, t))
    p.rel("pet", (Y, -0.15 * peek), (X, 0.04 * s))
    p.rel("pet_head", (Z, (0.35 * s - 0.5 * peek) * look), (X, -0.1 * math.sin(4 * math.pi * t)))


def idle(t):
    # Knitting away, rocking gently, humming to herself; the goblin looks about
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    stoop(p)
    p.rel("hips", (Y, 0.02 * s))
    p.rel("head", (X, 0.1), (Z, 0.05 * s), (Y, 0.04 * math.sin(2 * math.pi * t + 1)))
    knitting(p, t, 3.0)
    pet_peek(p, t)
    p.rel("bun", (Y, 0.0))
    return p


def walk(t):
    # A little shuffle, still knitting as she goes
    p = biped_walk(BONES, t, stride=0.22, arm=0.0, bob=0.01)
    stoop(p, 1.3)
    knitting(p, t, 2.0)
    pet_peek(p, t * 2, 0.6)
    return p


def run(t):
    # In a hurry: knitting tucked to her chest, little quick steps
    p = biped_walk(BONES, t, stride=0.36, arm=0.0, bob=0.03)
    stoop(p, 2.2)
    for sx, side in ((1, "L"), (-1, "R")):
        p.ik(f"upper_arm.{side}", f"forearm.{side}", (0.05 * sx, -0.22, 0.95), (sx, 0.3, -1.0))
    p.rel("pet", (X, -0.25))
    p.rel("pet_head", (X, -0.2))
    return p


def jump(t):
    k = ss(0, 1, t)
    p = Pose(BONES)
    stoop(p, 1 - k)
    p.rel("thigh.L", (X, -0.4 * k))
    p.rel("thigh.R", (X, -0.3 * k))
    p.rel("shin.L", (X, 0.7 * k))
    p.rel("shin.R", (X, 0.5 * k))
    knitting(p, 0.0, 0.0)
    p.rel("pet", (X, -0.3 * k))
    p.rel("pet_head", (X, 0.3 * k))
    return p


def fall(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.2 + 0.1 * s))
    p.rel("thigh.R", (X, -0.2 - 0.1 * s))
    p.rel("shin.L", (X, 0.35))
    p.rel("shin.R", (X, 0.35))
    p.rel("upper_arm.L", (Y, -0.9 + 0.12 * s))
    p.rel("upper_arm.R", (Y, 0.9 + 0.12 * s))
    p.rel("forearm.L", (X, -0.4))
    p.rel("forearm.R", (X, -0.4))
    p.rel("pet", (X, 0.3), (Y, -0.2))
    p.rel("pet_head", (Z, 0.4 * s))
    return p


def wave(t):
    # Hello, dear! Her right hand waves, the knitting held in her left; the goblin waves too
    s = math.sin(2 * math.pi * t * 2)
    p = Pose(BONES)
    stoop(p)
    p.rel("head", (Y, -0.08), (X, 0.05))
    p.ik("upper_arm.L", "forearm.L", (0.08, -0.27, 0.82), (1, 0.3, -1.0))
    p.ik("upper_arm.R", "forearm.R", (-0.4, -0.16, 1.3), (-1, 0.5, -0.4))
    p.aim("hand.R", Vector((-0.25 * s, -0.2, 1.0)))
    p.rel("pet", (Y, -0.1 + 0.08 * s))
    p.rel("pet_head", (Z, 0.15 * s))
    return p


def chuckle(t):
    # A little giggle: shoulders bouncing, head tipped back, the goblin bouncing along
    b = abs(math.sin(2 * math.pi * t * 3))
    p = Pose(BONES)
    stoop(p, 0.5)
    p.rel("chest", (X, -0.04 * b))
    p.rel("head", (X, -0.12 - 0.04 * b))
    knitting(p, 0.0, 0.0)
    p.rel("pet", (X, -0.08 * b))
    p.rel("pet_head", (X, -0.15 * b))
    p.offset = Vector((0, 0, 0.006 * b))
    return p


make_action(rig, "idle", 60, idle)
make_action(rig, "walk", 36, walk)
make_action(rig, "run", 24, run)
make_action(rig, "jump", 10, jump)
make_action(rig, "fall", 24, fall)
make_action(rig, "wave", 40, wave)
make_action(rig, "chuckle", 40, chuckle)
rest_pose(rig)
finish(OUT)

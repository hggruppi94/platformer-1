# Builds the cyber gorilla from Hayden's drawing (Nov 21, 2026): a big grey-brown gorilla who's half machine. His head
# is split down the middle (his right half fur, with a glowing red eye and a smile; his left half black metal, with a
# little white eye and a fang), his left arm and right leg are black metal, his right arm ends in a light-blue cyber
# blaster (Hayden: "His right hand is a blaster"), and the oval screen on his belly shows a skull face that matches the
# Agent of Chaos's gold skulls (Hayden: "His stomach head is supposed to match the agent of chaos skull concept"; the
# skull is the same shape as skull() in build_chaos_giant.py: a gold cranium, dark sockets with a burning spark in
# each, a nose hole and a row of teeth), shown as if on a screen, with a magenta glitch crack through it.
#
#   blender -b --python tools\build_cyber_gorilla.py
#
# Writes source_art/characters/cyber_gorilla.blend (overwrites it) with idle / walk / run / jump / fall / blast /
# chest_beat actions. Units are meters; feet at the origin; he faces -Y, so his right side is -X. Helpers:
# tools/char_kit.py. He's big: about 1.95 m to the top of his head, with long arms and short thick legs.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "cyber_gorilla.blend"

K.begin()

# =============================================================================
# Materials (linear colours)
# =============================================================================
mat("Fur", (0.27, 0.21, 0.16), rough=0.85)             # the drawing's grey-brown
mat("Fur Dark", (0.17, 0.13, 0.10), rough=0.9)
mat("Fur Light", (0.40, 0.33, 0.27), rough=0.85)       # the paler belly oval round the screen
mat("Skin", (0.12, 0.09, 0.08), rough=0.6)             # muzzle, palm and sole leather
mat("Metal", (0.018, 0.018, 0.024), rough=0.32, metal=0.75)   # the black machine half
mat("Metal Edge", (0.06, 0.06, 0.075), rough=0.3, metal=0.8)
mat("Cyber", (0.38, 0.62, 0.88), rough=0.3, metal=0.55)        # the light-blue blaster and screen frame
mat("Cyber Dark", (0.12, 0.24, 0.40), rough=0.35, metal=0.6)
mat("Cyber Glow", (0.30, 0.75, 1.0), emit=6.0)
mat("Screen", (0.22, 0.42, 0.70), rough=0.1, emit=1.2)
mat("Screen Gold", (0.80, 0.52, 0.13), rough=0.3, emit=0.5)    # the skull on the screen, in the Agent's gold
mat("Screen Gold Dark", (0.40, 0.24, 0.06), rough=0.3, emit=0.4)
mat("Screen Bone", (0.90, 0.84, 0.66), rough=0.3, emit=0.6)
mat("Void", (0.004, 0.0, 0.012), rough=0.9)
mat("Eye Fire", (1.0, 0.1, 0.01), emit=4.0)             # the skull's burning sparks (dimmer than the Agent's,
                                                         # so on the bright screen they stay ember-red)
mat("Chaos Magenta", (0.95, 0.04, 0.32), emit=5.0)
mat("Red Eye", (1.0, 0.05, 0.03), rough=0.1, emit=6.0)
mat("Mouth", (0.03, 0.015, 0.015))
mat("Tooth", (0.95, 0.93, 0.85), rough=0.3)
eye_materials((0.02, 0.02, 0.02), (0.08, 0.08, 0.1))   # his little white machine eye, dark iris

HB = ["head"]
RA, LA = "R", "L"
# Which half is which (his right is -X): fur on his right, metal on his left; legs the other way round (the drawing)
METAL_SIDE = 1          # +X: his left

# =============================================================================
# Rig layout first
# =============================================================================
SH, EL, WR, TIP = (0.40, 0.0, 1.42), (0.58, -0.04, 1.08), (0.66, -0.08, 0.76), (0.70, -0.10, 0.62)
BONES = biped_bones(hips=0.78, chest=1.30, neck=1.55, head_top=1.99, shoulder=SH, elbow=EL, wrist=WR, hand_tip=TIP,
                    hip_x=0.17, knee=0.42, ankle=0.10, toe=(-0.2, 0.05))

# =============================================================================
# Body: a big round gorilla tummy with a paler oval and the screen
# =============================================================================
TORSO = Ellipsoid((0, 0.0, 1.13), (0.39, 0.32, 0.52))
ellipsoid("Torso", TORSO.c, TORSO.r, "Fur", [("hips", 1.6), "spine", "chest"], u=48, v=24)
# Hayden: "The gorilla should be much more muscular". A big V: a barrel chest much wider than his waist, two
# heavy pecs over the screen, traps sloping up to his neck, huge round deltoids, lats flaring out behind his arms,
# obliques either side of the belly and a big silverback hump.
ellipsoid("Chest", (0, 0.02, 1.38), (0.5, 0.33, 0.24), "Fur", ["chest"], u=40, v=20)
for sx in (1, -1):
    metal = sx == METAL_SIDE
    ellipsoid(f"Pec.{sx}", (0.19 * sx, -0.2, 1.42), (0.2, 0.13, 0.12), "Metal" if metal else "Fur", ["chest"],
              rot=Euler((0, -0.15 * sx, 0)).to_matrix(), u=24, v=12)
    ellipsoid(f"Trap.{sx}", (0.2 * sx, 0.06, 1.57), (0.2, 0.17, 0.11), "Metal" if metal else "Fur", ["chest"],
              rot=Euler((0, 0.45 * sx, 0)).to_matrix(), u=24, v=12)
    ellipsoid(f"Shoulder.{sx}", (0.42 * sx, 0.02, 1.45), (0.22, 0.24, 0.2), "Metal" if metal else "Fur",
              ["chest", (f"upper_arm.{'L' if sx > 0 else 'R'}", 0.6)], u=28, v=14)
    ellipsoid(f"Lat.{sx}", (0.33 * sx, 0.1, 1.22), (0.15, 0.2, 0.26), "Fur", ["chest", "spine"],
              rot=Euler((0, -0.25 * sx, 0)).to_matrix(), u=24, v=12)
    ellipsoid(f"Oblique.{sx}", (0.3 * sx, -0.1, 0.98), (0.1, 0.15, 0.2), "Fur", ["spine", ("hips", 0.6)], u=20, v=10)
ellipsoid("Hump", (0, 0.15, 1.53), (0.36, 0.24, 0.2), "Fur", ["chest"], u=32, v=16)
ellipsoid("Hips", (0, 0.02, 0.8), (0.3, 0.25, 0.16), "Fur", ["hips"], u=36, v=16)

# The paler belly oval (the drawing's inner outline)
BELLY = Ellipsoid(TORSO.c, TORSO.r + Vector((0.004, 0.004, 0.004)))
grid = [[(0.3 * math.sin(a) * math.sqrt(max(1 - ((z - 1.05) / 0.4) ** 2, 0.0)), z)
         for a in (math.pi * (i / 16 - 0.5) for i in range(17))] for z in (0.66 + 0.78 * k / 20 for k in range(21))]
surface_patch("Belly", BELLY, grid, 0.004, "Fur Light", ["spine", ("hips", 1.5)])

# The screen: an oval of glowing blue in a light-blue frame, set into the belly
SC = Vector((0, 0, 1.08))
SCR_W, SCR_H = 0.17, 0.23
scr_c = TORSO.front(SC.x, SC.z, offset=0.0)
N = TORSO.normal(scr_c)
SB = basis_facing(N)


def on_screen(x, z, out=0.0):
    """A point on the screen's plane: x right-left across it, z up it, out toward the viewer."""
    return scr_c + SB @ Vector((x, -out, z))


ellipsoid("Screen", on_screen(0, 0, 0.0), (SCR_W, 0.03, SCR_H), "Screen", ["spine"], rot=SB, u=40, v=20)
frame = [on_screen(SCR_W * 1.04 * math.cos(a), SCR_H * 1.04 * math.sin(a), 0.026)
         for a in (2 * math.pi * k / 48 for k in range(49))]
tube("Screen Frame", frame, [(0.018, 0.022)] * len(frame), "Cyber", ["spine"], sides=10, caps=False)
for k in range(6):
    a = math.pi * 2 * k / 6 + 0.5
    ellipsoid(f"Screen Bolt.{k}", on_screen(SCR_W * 1.04 * math.cos(a), SCR_H * 1.04 * math.sin(a), 0.045),
              (0.012, 0.008, 0.012), "Cyber Glow", ["spine"], rot=SB, u=8, v=4)


# The skull on the screen: the Agent of Chaos's skull (see build_chaos_giant.py skull()), flattened like a picture
def screen_skull(s):
    depth = 0.28                           # squash the skull's depth so it sits on the glass like an image

    def at(x, y, z):
        return on_screen(x * s, z * s, 0.03 + (-y) * s * depth)

    def sz(rx, ry, rz):
        return (rx * s, ry * s * depth, rz * s)
    bones = ["spine"]
    ellipsoid("Skull Cranium", at(0, 0, 0.1), sz(0.9, 0.85, 0.85), "Screen Gold", bones, rot=SB, power=0.85, u=24, v=12)
    ellipsoid("Skull Brow", at(0, -0.62, 0.12), sz(0.78, 0.22, 0.16), "Screen Gold Dark", bones, rot=SB, u=14, v=6)
    ellipsoid("Skull Cheeks", at(0, -0.4, -0.3), sz(0.72, 0.5, 0.48), "Screen Gold", bones, rot=SB, power=0.85,
              u=16, v=8)
    ellipsoid("Skull Jaw", at(0, -0.35, -0.72), sz(0.5, 0.42, 0.24), "Screen Gold Dark", bones, rot=SB, u=14, v=7)
    for sx in (1, -1):
        ellipsoid(f"Skull Socket.{sx}", at(0.33 * sx, -0.8, -0.14), sz(0.3, 0.22, 0.22), "Void", bones,
                  rot=SB @ Euler((0, -0.5 * sx, 0)).to_matrix(), power=0.7, u=12, v=6)
        ellipsoid(f"Skull Spark.{sx}", at(0.31 * sx, -1.0, -0.15), sz(0.09, 0.05, 0.055), "Eye Fire", bones,
                  rot=SB @ Euler((0, -0.5 * sx, 0)).to_matrix(), u=10, v=5)
    ellipsoid("Skull Nose", at(0, -0.86, -0.42), sz(0.12, 0.1, 0.15), "Void", bones, rot=SB, u=8, v=4)
    for k in range(6):
        x = -0.3 + 0.12 * k
        ellipsoid(f"Skull Tooth.{k}", at(x, -0.78 + 0.12 * abs(x), -0.6), sz(0.06, 0.05, 0.12), "Screen Bone",
                  bones, rot=SB, u=6, v=4)


screen_skull(0.165)
# A magenta glitch crack across the glass, like the cracks of chaos in the Agent's armour
crack = [on_screen(x, z, 0.078) for x, z in ((-0.1, 0.17), (-0.05, 0.12), (-0.075, 0.07), (-0.03, 0.03))]
tube("Screen Crack", crack, [(0.004, 0.003)] * len(crack), "Chaos Magenta", ["spine"], sides=6)
# Little scan lines over the glass
for k in range(5):
    z = -0.16 + 0.08 * k
    hw = SCR_W * math.sqrt(max(1 - (z / SCR_H) ** 2, 0)) * 0.9
    line = [on_screen(-hw + 2 * hw * t, z, 0.031) for t in (0, 0.5, 1)]
    tube(f"Scan Line.{k}", line, [(0.0025, 0.0015)] * 3, "Cyber Glow", ["spine"], sides=4)

# =============================================================================
# Head: split down the middle, fur on his right (-X), black metal on his left (+X)
# =============================================================================
HEAD = Ellipsoid((0, -0.1, 1.75), (0.23, 0.215, 0.235))


def split(ob, metal="Metal"):
    paint(ob, metal, lambda c, n: c.x * METAL_SIDE > 0.0)
    return ob


split(ellipsoid("Head", HEAD.c, HEAD.r, "Fur", HB, u=48, v=24))
split(ellipsoid("Crest", (0, -0.04, 1.92), (0.12, 0.14, 0.1), "Fur", HB, u=24, v=12))      # a gorilla's crest
split(ellipsoid("Brow Ridge", (0, -0.28, 1.81), (0.19, 0.065, 0.05), "Fur Dark", HB, u=32, v=12), "Metal Edge")
MUZZLE = Ellipsoid((0, -0.28, 1.64), (0.15, 0.1, 0.095))
split(ellipsoid("Muzzle", MUZZLE.c, MUZZLE.r, "Skin", HB, u=32, v=16))
capsule("Neck", [(0, -0.02, 1.48), (0, -0.06, 1.6)], 0.14, 0.13, "Fur", ["chest", "head"])
for sx in (1, -1):
    # Nostrils: a big gorilla nose
    ellipsoid(f"Nostril.{sx}", MUZZLE.front(0.035 * sx, 1.69, offset=-0.004), (0.02, 0.01, 0.014), "Mouth", HB)
# The seam where fur meets metal, glowing a little, from the chin up over the top and down the back
seam = [HEAD.dir_point((0.0, -math.cos(a), math.sin(a)), offset=0.004) for a in
        (math.radians(-55 + 235 * k / 30) for k in range(31))]
tube("Head Seam", seam, [(0.006, 0.006)] * len(seam), "Cyber Glow", HB, sides=6, caps=False)
# Rivets on the metal half
for k, (dz, dy) in enumerate(((0.06, 0.9), (0.14, 0.2), (-0.06, 0.6), (0.0, -0.2))):
    p = HEAD.dir_point((0.95 * METAL_SIDE, dy - 0.4, dz * 5), offset=0.002)
    ellipsoid(f"Rivet.{k}", p, (0.01, 0.01, 0.01), "Metal Edge", HB, u=8, v=4)

# Ears: small and round; in the drawing his right ear is black and his left one fur
for sx in (1, -1):
    ear = Vector((0.23 * sx, -0.06, 1.79))
    m = "Metal" if sx != METAL_SIDE else "Fur"
    ellipsoid(f"Ear.{sx}", ear, (0.035, 0.03, 0.045), m, HB)
    ellipsoid(f"Ear Inner.{sx}", ear + Vector((0.004 * sx, -0.018, 0)), (0.02, 0.012, 0.028),
              "Metal Edge" if m == "Metal" else "Skin", HB)

# His fur side's eye: big and glowing red, in a dark rim
FACE = Ellipsoid(HEAD.c, HEAD.r)
red = FACE.front(-0.085 * METAL_SIDE, 1.765, offset=-0.008)
ellipsoid("Eye Rim.R", red, (0.042, 0.02, 0.032), "Mouth", HB, rot=basis_facing(FACE.normal(red)))
ellipsoid("Red Eye", red + FACE.normal(red) * 0.006, (0.034, 0.016, 0.025), "Red Eye", HB,
          rot=basis_facing(FACE.normal(red)))
ellipsoid("Red Eye Shine", red + FACE.normal(red) * 0.018 + Vector((0.008, 0, 0.008)), (0.008, 0.004, 0.006),
          "Eye Shine", HB)
# His metal side's eye: a little white eye with a dark iris, in a glowing ring
wh = FACE.front(0.085 * METAL_SIDE, 1.765, offset=-0.012)
cartoon_eye("L" if METAL_SIDE > 0 else "R", wh, (0.028, 0.022, 0.026), HB, look=(-0.004 * METAL_SIDE, 0.0))
ring = [FACE.project(wh + Vector((0.034 * math.cos(a), -0.03, 0.032 * math.sin(a))), offset=0.003)
        for a in (2 * math.pi * k / 24 for k in range(25))]
tube("Eye Ring", ring, [(0.004, 0.004)] * len(ring), "Cyber Glow", HB, sides=6, caps=False)

# The smile: a curve right across the muzzle, and a fang hanging down on the metal side
smile_pts = [MUZZLE.front(0.105 * (2 * t - 1), 1.6 - 0.022 * math.sin(math.pi * t) + 0.012 * (2 * t - 1) ** 2,
                          offset=0.003) for t in (i / 14 for i in range(15))]
tube("Smile", smile_pts, [(0.005, 0.005)] * len(smile_pts), "Mouth", HB, sides=6)
fang_top = MUZZLE.front(0.05 * METAL_SIDE, 1.588, offset=0.004)
tube("Fang", [fang_top, fang_top + Vector((0, -0.006, -0.025)), fang_top + Vector((0.003 * METAL_SIDE, -0.008, -0.05))],
     [(0.012, 0.008), (0.008, 0.006), (0.001, 0.001)], "Tooth", HB, sides=8)

# =============================================================================
# Arms: his right a fur arm ending in the cyber blaster, his left all black metal with a big fist
# =============================================================================
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda p: Vector((p[0] * sx, p[1], p[2]))
    up = [m(SH) + Vector((0, 0.02, 0.04)), m(EL)]
    fore = [m(EL), m(WR)]
    ua, fa, hb = f"upper_arm.{side}", f"forearm.{side}", f"hand.{side}"
    if sx == METAL_SIDE:
        # Black machine arm, chunky, with glowing seams at the joints
        capsule(f"Upper Arm.{side}", up, 0.165, 0.13, "Metal", [ua], sides=24)
        mid = Vector(up[0]).lerp(Vector(up[1]), 0.5)
        ellipsoid(f"Bicep.{side}", mid + Vector((0, -0.07, 0)), (0.13, 0.11, 0.17), "Metal", [ua], u=20, v=10)
        ellipsoid(f"Tricep.{side}", mid + Vector((0.02 * sx, 0.07, 0.02)), (0.12, 0.1, 0.18), "Metal", [ua], u=20, v=10)
        capsule(f"Forearm.{side}", fore, 0.16, 0.115, "Metal", [fa], sides=24)
        ellipsoid(f"Elbow.{side}", m(EL), (0.13, 0.13, 0.11), "Metal Edge", [ua, fa], u=16, v=8)
        for t, b in ((0.35, ua), (0.75, ua)):
            p = Vector(up[0]).lerp(Vector(up[1]), t)
            d = (Vector(up[1]) - Vector(up[0])).normalized()
            torus(f"Arm Seam.{side}{t}", p, 0.16 if t < 0.5 else 0.15, 0.006, "Cyber Glow", [b], u=24, v=6,
                  rot=d.to_track_quat('Z', 'Y').to_matrix())
        p = Vector(fore[0]).lerp(Vector(fore[1]), 0.55)
        d = (Vector(fore[1]) - Vector(fore[0])).normalized()
        torus(f"Arm Seam.{side}f", p, 0.145, 0.006, "Cyber Glow", [fa], u=24, v=6,
              rot=d.to_track_quat('Z', 'Y').to_matrix())
        # The big black fist: a knuckly block with a thumb
        fist = m(WR) + (m(TIP) - m(WR)) * 0.55
        ellipsoid(f"Fist.{side}", fist, (0.13, 0.125, 0.13), "Metal", [hb], power=0.8, u=20, v=10)
        for k in range(4):
            ellipsoid(f"Knuckle.{side}{k}", fist + Vector((0.025 * sx, -0.075 + 0.05 * k, -0.11)),
                      (0.05, 0.032, 0.035), "Metal Edge", [hb], u=10, v=6)
        ellipsoid(f"Thumb.{side}", fist + Vector((-0.08 * sx, -0.09, -0.02)), (0.045, 0.04, 0.06), "Metal", [hb])
    else:
        # Fur upper arm down to the elbow, then the light-blue blaster for a forearm and hand
        capsule(f"Upper Arm.{side}", up, 0.165, 0.13, "Fur", [ua], sides=24)
        mid = Vector(up[0]).lerp(Vector(up[1]), 0.5)
        ellipsoid(f"Bicep.{side}", mid + Vector((0, -0.07, 0)), (0.13, 0.11, 0.17), "Fur", [ua], u=20, v=10)
        ellipsoid(f"Tricep.{side}", mid + Vector((0.02 * sx, 0.07, 0.02)), (0.12, 0.1, 0.18), "Fur", [ua], u=20, v=10)
        ellipsoid(f"Elbow.{side}", m(EL), (0.13, 0.13, 0.11), "Fur", [ua, fa], u=16, v=8)
        a0, a1 = Vector(m(EL)), Vector(m(TIP)) + (Vector(m(TIP)) - Vector(m(WR))) * 0.3
        d = (a1 - a0).normalized()
        Rb = d.to_track_quat('Z', 'Y').to_matrix()
        torus(f"Blaster Cuff.{side}", a0 + d * 0.05, 0.13, 0.025, "Cyber Dark", [fa], u=24, v=8, rot=Rb)
        # The blaster: a chunky squarish light-blue housing with vents, a sight on top, a glowing power cell and a
        # stripe down each side, then a wide barrel with a glowing muzzle
        L = (a1 - a0).length
        ellipsoid(f"Blaster.{side}", a0 + d * L * 0.45, (0.12, 0.125, L * 0.45), "Cyber", [fa, hb], rot=Rb, power=0.45,
                  u=28, v=16)
        for k in range(3):
            torus(f"Blaster Vent.{side}{k}", a0 + d * L * (0.22 + 0.1 * k), 0.122, 0.01, "Cyber Dark", [fa],
                  u=4, v=6, rot=Rb @ Euler((0, 0, math.pi / 4)).to_matrix())
        sight = a0 + d * L * 0.6 + Rb @ Vector((0, 0.128, 0))
        ellipsoid(f"Blaster Sight.{side}", sight, (0.025, 0.04, 0.09), "Cyber Dark", [fa, hb], rot=Rb, power=0.6)
        ellipsoid(f"Sight Light.{side}", sight + Rb @ Vector((0, 0.03, -0.06)), (0.012, 0.012, 0.012), "Red Eye",
                  [fa, hb])
        for sgn in (1, -1):
            stripe = [a0 + d * L * t + Rb @ Vector((0.122 * sgn, 0, 0)) for t in (0.3, 0.55, 0.8)]
            tube(f"Blaster Stripe.{side}{sgn}", stripe, [(0.006, 0.012)] * 3, "Cyber Glow", [fa, hb], sides=6)
        cell = a0 + d * L * 0.45 + Rb @ Vector((0, -0.125, 0))
        ellipsoid(f"Power Cell.{side}", cell, (0.045, 0.025, 0.08), "Cyber Glow", [fa], rot=Rb)
        muzzle = a0 + d * L * 0.86
        cylinder(f"Barrel.{side}", muzzle, a1, 0.095, "Cyber Dark", [hb], sides=24)
        torus(f"Muzzle Ring.{side}", a1, 0.095, 0.022, "Cyber", [hb], u=28, v=8, rot=Rb)
        ellipsoid(f"Muzzle Hole.{side}", a1 + d * 0.003, (0.072, 0.072, 0.012), "Void", [hb], rot=Rb)
        ellipsoid(f"Muzzle Glow.{side}", a1 - d * 0.004, (0.045, 0.045, 0.012), "Cyber Glow", [hb], rot=Rb)
        BLASTER_TIP = a1

# =============================================================================
# Legs: his right leg black metal, his left leg fur; chunky round feet with toes
# =============================================================================
for sx, side in ((1, "L"), (-1, "R")):
    metal = sx != METAL_SIDE
    mm = "Metal" if metal else "Fur"
    hip, knee, ankle = Vector((0.17 * sx, 0, 0.82)), Vector((0.17 * sx, -0.02, 0.42)), Vector((0.17 * sx, 0, 0.12))
    th, sh, ft = f"thigh.{side}", f"shin.{side}", f"foot.{side}"
    capsule(f"Thigh.{side}", [hip, knee], 0.2, 0.15, mm, [th], sides=24)
    ellipsoid(f"Quad.{side}", hip.lerp(knee, 0.45) + Vector((0, -0.07, 0)), (0.15, 0.12, 0.2), mm, [th], u=20, v=10)
    capsule(f"Shin.{side}", [knee, ankle], 0.15, 0.115, mm, [sh], sides=24)
    ellipsoid(f"Calf.{side}", knee.lerp(ankle, 0.3) + Vector((0, 0.06, 0)), (0.12, 0.11, 0.14), mm, [sh], u=20, v=10)
    ellipsoid(f"Knee.{side}", knee + Vector((0, -0.04, 0)), (0.12, 0.1, 0.1), "Metal Edge" if metal else "Fur",
              [th, sh], u=16, v=8)
    if metal:
        for z in (0.62, 0.28):
            torus(f"Leg Seam.{side}{z}", Vector((0.17 * sx, -0.01, z)), 0.18 if z > 0.5 else 0.14, 0.006,
                  "Cyber Glow", [th if z > 0.5 else sh], u=24, v=6)
    foot = Vector((0.17 * sx, -0.08, 0.075))
    ellipsoid(f"Foot.{side}", foot, (0.13, 0.19, 0.08), mm, [ft], power=0.9, u=24, v=12)
    for k in range(3):
        ellipsoid(f"Toe.{side}{k}", foot + Vector((-0.07 + 0.07 * k, -0.17, -0.015)), (0.05, 0.05, 0.05), mm, [ft],
                  u=12, v=8)
    ellipsoid(f"Sole.{side}", foot + Vector((0, 0, -0.06)), (0.12, 0.18, 0.02), "Metal Edge" if metal else "Skin",
              [ft], u=20, v=6)

# A few tufts of fur so he isn't too smooth (on the fur parts only)
r = K.rng(11)
for k in range(26):
    a = r.uniform(0, 2 * math.pi)
    z = r.uniform(0.75, 1.55)
    d = Vector((math.cos(a), math.sin(a), (z - TORSO.c.z) / TORSO.r.z * 1.1))
    p = TORSO.dir_point(d, offset=-0.01)
    if p.y < -0.15 and abs(p.x) < 0.33:     # keep them off his belly
        continue
    if p.y > 0.15 and abs(p.x) < 0.27 and 0.92 < p.z < 1.42:     # and off the panel on his back
        continue
    n = TORSO.normal(p)
    lock(f"Tuft.{k}", [p, p + n * 0.04 + Vector((0, 0, -0.02)), p + n * 0.06 + Vector((0, 0, -0.06))], 0.03,
         "Fur Dark" if k % 3 == 0 else "Fur", [("spine", 1.0), ("chest", 1.2)], flat=0.4, sides=6)

# =============================================================================
# Cyber panels (Hayden: "give the gorilla a cybernetic panel in his head and back"): a bolted plate set into the
# metal side of his skull, and a bigger one on his back with vents, glowing circuit lines and a humming core
# =============================================================================
def panel_basis(n, up=Vector((0, 0, 1))):
    """Rotation for a plate lying on a surface with normal n: its local -Y points out, its local Z points up."""
    out = Vector(n).normalized()
    z = (Vector(up) - out * Vector(up).dot(out)).normalized()
    y = -out
    x = y.cross(z).normalized()
    return Matrix((x, y, z)).transposed()


def panel(name, c, n, w, h, bones, core=False):
    R = panel_basis(n)

    def at(px, pz, out=0.0):
        return c + R @ Vector((px, -out, pz))
    ellipsoid(f"{name} Plate", at(0, 0, -0.004), (w, 0.022, h), "Metal Edge", bones, rot=R, power=0.35, u=24, v=12)
    ellipsoid(f"{name} Inset", at(0, 0, 0.004), (w * 0.86, 0.016, h * 0.84), "Metal", bones, rot=R, power=0.35,
              u=24, v=12)
    for sx in (1, -1):
        for sz in (1, -1):
            ellipsoid(f"{name} Bolt.{sx}{sz}", at(sx * w * 0.86, sz * h * 0.84, 0.016), (0.011, 0.007, 0.011),
                      "Cyber", bones, rot=R, u=10, v=5)
    # Glowing circuit lines running across the plate
    for k, row in enumerate(((-0.6, 0.45), (-0.2, -0.1), (0.25, 0.35))):
        x0, zz = row
        pts = [at(w * x0, h * zz, 0.021), at(w * (x0 + 0.25), h * zz, 0.021),
               at(w * (x0 + 0.38), h * (zz - 0.22), 0.021), at(w * (x0 + 0.6), h * (zz - 0.22), 0.021)]
        tube(f"{name} Circuit.{k}", pts, [(0.004, 0.0025)] * 4, "Cyber Glow", bones, sides=5)
        ellipsoid(f"{name} Node.{k}", pts[-1], (0.008, 0.005, 0.008), "Cyber Glow", bones, rot=R, u=8, v=4)
    # A little vent grill along the bottom
    for k in range(4):
        vx = w * (-0.45 + 0.3 * k)
        tube(f"{name} Vent.{k}", [at(vx, -h * 0.55, 0.021), at(vx, -h * 0.3, 0.021)], [(0.006, 0.003)] * 2,
             "Void", bones, sides=5)
    if core:
        ellipsoid(f"{name} Core Rim", at(w * 0.45, h * 0.05, 0.02), (0.05, 0.012, 0.05), "Cyber", bones, rot=R)
        ellipsoid(f"{name} Core", at(w * 0.45, h * 0.05, 0.028), (0.036, 0.01, 0.036), "Cyber Glow", bones, rot=R)
        ellipsoid(f"{name} Light", at(-w * 0.55, h * 0.62, 0.02), (0.012, 0.008, 0.012), "Red Eye", bones, rot=R)


hp = HEAD.dir_point(Vector((0.5 * METAL_SIDE, 0.2, 0.85)), offset=-0.016)
panel("Head Panel", hp, HEAD.normal(hp), 0.095, 0.075, HB, core=True)
BACK = Ellipsoid(TORSO.c, TORSO.r)
bp = BACK.dir_point(Vector((0.0, 1.0, 0.05)), offset=-0.006)
panel("Back Panel", bp, BACK.normal(bp), 0.17, 0.16, ["spine", "chest"], core=True)

rig = build_rig("GorillaRig", BONES)
skin_and_join(rig, BONES, "CyberGorilla", "Torso")


# =============================================================================
# Animations. Arms hang out to the sides (his tummy's too big to tuck them in), shoulders hunched like a gorilla.
# =============================================================================
def hunch(p, amount=1.0):
    p.rel("spine", (X, 0.08 * amount))
    p.rel("chest", (X, 0.06 * amount))
    p.rel("head", (X, -0.1 * amount))


def arms_hang(p, swing=0.0, bend=0.25, out=0.08):
    p.rel("upper_arm.L", (Y, out), (X, swing))
    p.rel("upper_arm.R", (Y, -out), (X, -swing))
    p.rel("forearm.L", (X, -bend))
    p.rel("forearm.R", (X, -bend))


def idle(t):
    # Big slow breaths, looking about; the blaster arm twitches now and then
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    hunch(p)
    arms_hang(p, 0.03 * s)
    p.rel("spine", (X, 0.08 + 0.025 * s))
    p.rel("chest", (X, 0.06), (Z, 0.02 * s))
    p.rel("head", (X, -0.1), (Z, 0.15 * math.sin(2 * math.pi * t + 0.7)))
    twitch = ss(0.6, 0.65, t) * (1 - ss(0.72, 0.8, t))
    p.rel("forearm.R", (X, -0.25 - 0.35 * twitch))
    p.offset = Vector((0, 0, 0.008 * s))
    return p


def walk(t):
    # A heavy rolling walk, shoulders swaying
    p = biped_walk(BONES, t, stride=0.38, arm=0.0, bob=0.025)
    s = math.sin(2 * math.pi * t)
    hunch(p)
    arms_hang(p, 0.35 * s)
    p.rel("chest", (Z, 0.08 * s))
    return p


def run(t):
    # Charging: leaning right in, arms pumping
    p = biped_run(BONES, t)
    s = math.sin(2 * math.pi * t)
    hunch(p, 2.2)
    p.rel("upper_arm.L", (Y, 0.05), (X, 0.8 * s))
    p.rel("upper_arm.R", (Y, -0.05), (X, -0.8 * s))
    p.rel("forearm.L", (X, -0.8))
    p.rel("forearm.R", (X, -0.8))
    return p


def jump(t):
    k = ss(0, 1, t)
    p = Pose(BONES)
    hunch(p, 1 - k)
    p.rel("thigh.L", (X, -0.5 * k))
    p.rel("thigh.R", (X, -0.4 * k))
    p.rel("shin.L", (X, 0.8 * k))
    p.rel("shin.R", (X, 0.6 * k))
    p.rel("upper_arm.L", (Y, -0.5 * k))
    p.rel("upper_arm.R", (Y, 0.5 * k))
    return p


def fall(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.25 + 0.1 * s))
    p.rel("thigh.R", (X, -0.25 - 0.1 * s))
    p.rel("shin.L", (X, 0.4))
    p.rel("shin.R", (X, 0.4))
    p.rel("upper_arm.L", (Y, -0.7 + 0.15 * s))
    p.rel("upper_arm.R", (Y, 0.7 + 0.15 * s))
    p.rel("forearm.L", (X, -0.3))
    p.rel("forearm.R", (X, -0.3))
    return p


def blast(t):
    # Raises the blaster straight out in front, fires (a kick back), and lowers it again
    up = ss(0.0, 0.25, t) * (1 - ss(0.75, 1.0, t))
    kick = ss(0.4, 0.45, t) * (1 - ss(0.45, 0.6, t))
    p = Pose(BONES)
    hunch(p, 1 - 0.5 * up)
    arms_hang(p)
    p.rel("chest", (X, 0.03 - 0.06 * kick), (Z, 0.18 * up))
    target = Vector((-0.25, -1.0 + 0.15 * kick, 1.42 + 0.03 * kick))
    rest_hand = Vector((-0.66, -0.12, 0.76))
    if up > 0.001:
        p.ik("upper_arm.R", "forearm.R", rest_hand.lerp(target, up), (-1, 0.2, -0.5))
        p.aim("hand.R", Vector((0.05, -1, 0.05 * kick)).lerp(Vector((-0.12, -0.03, -0.14)), 1 - up))
    p.rel("head", (X, -0.1), (Z, -0.15 * up))
    return p


def chest_beat(t):
    # Thump thump: the fist and the blaster take turns on his chest, either side of the screen
    p = Pose(BONES)
    p.rel("spine", (X, -0.06))
    p.rel("chest", (X, -0.05))
    p.rel("head", (X, -0.25))
    for sx, side, ph in ((1, "L", 0.0), (-1, "R", 0.5)):
        h = abs(math.sin(2 * math.pi * (t * 3 + ph)))
        p.ik(f"upper_arm.{side}", f"forearm.{side}", (0.23 * sx, -0.42 - 0.12 * h, 1.33), (sx, 0.6, -0.6))
        p.aim(f"hand.{side}", Vector((-0.6 * sx, -0.2, 0.3)))
    p.offset = Vector((0, 0, 0.01 * abs(math.sin(2 * math.pi * t * 3))))
    return p


make_action(rig, "idle", 60, idle)
make_action(rig, "walk", 36, walk)
make_action(rig, "run", 22, run)
make_action(rig, "jump", 10, jump)
make_action(rig, "fall", 24, fall)
make_action(rig, "blast", 36, blast)
make_action(rig, "chest_beat", 36, chest_beat)
rest_pose(rig)
finish(OUT)

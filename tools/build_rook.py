# Builds Rook, Dash's twin, from scratch: model, materials, rig, weights and animations.
# Same body, head and hair as Dash (tools/build_bike_boy.py) in different clothes: no cap or sunglasses
# (big brown eyes and scruffy hair instead), a red T-shirt with a white paw print, ripped jean shorts,
# green sneakers and a studded dog collar with a gold tag. He gets about on all fours like a dog
# (hands and feet, bottom up) with his tongue out, and barks.
#
#   blender -b --python tools\build_rook.py
#
# Writes source_art/characters/rook.blend (overwrites it), with idle / walk / run / bark actions,
# all on all fours. Export with tools\export_all.ps1 rook.
#
# Units are meters; feet on the ground at the origin; faces -Y. Helpers: tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "rook.blend"

K.begin()
mat("Skin", (0.86, 0.50, 0.33))
mat("Nose", (0.78, 0.40, 0.26))
mat("Blush", (0.90, 0.30, 0.28))
mat("Mouth", (0.25, 0.04, 0.04))
mat("Tongue", (0.88, 0.32, 0.36))
mat("Brow", (0.12, 0.05, 0.02))
mat("Hair", (0.20, 0.08, 0.025), rough=0.45)
eye_materials((0.22, 0.10, 0.03), (0.45, 0.24, 0.08))
mat("Shirt", (0.62, 0.06, 0.04), rough=0.7)
mat("Shirt Shade", (0.42, 0.03, 0.02), rough=0.7)
mat("Print", (0.92, 0.92, 0.90), rough=0.7)
mat("Denim", (0.10, 0.20, 0.42), rough=0.8)
mat("Denim Light", (0.45, 0.55, 0.70), rough=0.85)
mat("Collar", (0.05, 0.05, 0.06), rough=0.45)
mat("Stud", (0.75, 0.76, 0.78), rough=0.2, metal=0.9)
mat("Tag", (0.85, 0.62, 0.12), rough=0.25, metal=0.9)
mat("Shoes", (0.10, 0.42, 0.14), rough=0.55)
mat("Sole", (0.88, 0.88, 0.88))

# Same head and body shapes as Dash
HEAD = Ellipsoid((0, 0, 1.10), (0.26, 0.24, 0.26))
TORSO = Ellipsoid((0, 0, 0.65), (0.23, 0.20, 0.25))
HB = ["head"]

ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HB, u=48, v=24)
capsule("Neck", [(0, 0, 0.84), (0, 0, 0.96)], 0.065, 0.065, "Skin", ["chest", "head"])

# Hair: Dash's short brown hair, but with no cap on it sticks up in scruffy tufts all over
scalp_cap("Hair", HEAD, "Hair", HB, thick=0.016, hairline=lambda x: 1.235 - 0.13 * ss(0.17, 0.25, abs(x)), u=96,
          v=48, bottom=1.0)
for k in range(5):
    x = -0.12 + 0.06 * k
    s = HEAD.front(x, 1.26, offset=0.012)
    lock(f"Fringe.{k}", [s, HEAD.front(x - 0.02, 1.225, offset=0.02), HEAD.front(x - 0.035, 1.20, offset=0.016)],
         0.035, "Hair", HB, flat=0.45, normal_fn=lambda p: HEAD.normal(p), sides=8)
R = rng(11)
tufts = [(0, -0.35, 1), (0.35, -0.3, 0.9), (-0.35, -0.3, 0.9), (0.15, 0.1, 1), (-0.18, 0.05, 1), (0.5, 0.2, 0.7),
         (-0.5, 0.2, 0.7), (0.2, 0.5, 0.7), (-0.2, 0.5, 0.7), (0, 0.75, 0.4), (0.55, 0.55, 0.2), (-0.55, 0.55, 0.2),
         (0.7, -0.05, 0.45), (-0.7, -0.05, 0.45)]
for k, d in enumerate(tufts):
    s = HEAD.dir_point(d, offset=0.008)
    n = HEAD.normal(s)
    lean = Vector((R.uniform(-0.3, 0.3), 0.5 + R.uniform(0, 0.3), 0)).normalized()   # swept back a bit
    ln = 0.045 + R.uniform(0, 0.025)
    lock(f"Tuft.{k}", [s, s + n * ln * 0.5 + lean * ln * 0.35, s + n * ln * 0.8 + lean * ln * 0.9], 0.05, "Hair", HB,
         flat=0.5, tip=0.012, taper=0.7, normal_fn=lambda p: HEAD.normal(p), sides=8)

# Face: big brown eyes (no sunglasses), little nose, an open panting smile with the tongue hanging out
for sx, side in ((1, "L"), (-1, "R")):
    p = HEAD.front(0.092 * sx, 1.10)
    cartoon_eye(side, p - HEAD.normal(p) * 0.014, (0.056, 0.036, 0.066), HB, look=(0.0, 0.004))
    arc_on(HEAD, f"Brow.{side}", [(sx * (0.045 + 0.10 * t), 1.20 + 0.018 * math.sin(math.pi * t)) for t in
                                  (i / 7 for i in range(8))], 0.011, "Brow", HB, offset=0.005)
    ear = HEAD.dir_point((sx, 0.05, -0.05), offset=-0.005)
    ellipsoid(f"Ear.{side}", ear, (0.035, 0.05, 0.062), "Skin", HB)
    b = HEAD.front(0.165 * sx, 1.0)
    ellipsoid(f"Blush.{side}", b - HEAD.normal(b) * 0.006, (0.035, 0.012, 0.022), "Blush", HB,
              rot=basis_facing(HEAD.normal(b)))
n0 = HEAD.front(0, 1.03)
ellipsoid("Nose", n0 + HEAD.normal(n0) * 0.006, (0.026, 0.022, 0.022), "Nose", HB)
smile("Mouth", HEAD, 0.0, 0.985, 0.07, 0.05, HB)
tp = HEAD.front(0.012, 0.945, offset=0.012)
ellipsoid("Tongue Out", tp, (0.03, 0.014, 0.04), "Tongue", HB,
          rot=basis_facing(HEAD.normal(tp)) @ Euler((math.radians(-25), 0, 0)).to_matrix())

# Dog collar: black band with silver studs and a gold tag at the front
NECK_BAND = Ellipsoid((0, 0, 0.895), (0.074, 0.072, 0.05))
ring_on("Collar", NECK_BAND, 0.895, 0.0, 0.02, "Collar", ["chest", "head"], sides=10)
for k in range(10):
    a = 2 * math.pi * (k + 0.5) / 10
    if abs(math.sin(a) + 1) < 0.15:                                  # leave the front for the tag
        continue
    d = Vector((math.cos(a) * 0.074, math.sin(a) * 0.072, 0))
    ellipsoid(f"Stud.{k}", Vector((0, 0, 0.895)) + d * 1.27, (0.009, 0.009, 0.009), "Stud", ["chest", "head"],
              u=10, v=6)
capsule("Tag Ring", [(0, -0.093, 0.885), (0, -0.095, 0.872)], 0.004, 0.004, "Stud", ["chest"], sides=6)
ellipsoid("Tag", (0, -0.098, 0.852), (0.022, 0.005, 0.024), "Tag", ["chest"], u=16, v=8)

# T-shirt: red with a white paw print, short sleeves, darker collar and hem
torso = ellipsoid("Torso", TORSO.c, TORSO.r, "Shirt", ["hips", "spine", "chest", ("thigh.L", 1.8),
                                                      ("thigh.R", 1.8)], u=64, v=32)
paint(torso, "Denim", lambda c, n: c.z < 0.475)                    # below the hem it's his shorts
ring_on("Shirt Collar", Ellipsoid((0, 0, 0.87), (0.09, 0.085, 0.05)), 0.87, 0.0, 0.016, "Shirt Shade", ["chest"])
ring_on("Hem", TORSO, 0.48, 0.004, 0.018, "Shirt Shade", ["hips"])
pad = TORSO.front(0, 0.63, offset=0.002)
ellipsoid("Paw Pad", pad, (0.055, 0.006, 0.045), "Print", ["spine", "chest"], rot=basis_facing(TORSO.normal(pad)))
for k, (tx, tz) in enumerate(((-0.065, 0.695), (-0.024, 0.72), (0.024, 0.72), (0.065, 0.695))):
    toe = TORSO.front(tx, tz, offset=0.002)
    ellipsoid(f"Paw Toe.{k}", toe, (0.019, 0.005, 0.023), "Print", ["chest"], rot=basis_facing(TORSO.normal(toe)))

for sx, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.225 * sx, 0, 0.80)), Vector((0.31 * sx, -0.03, 0.67)), Vector((0.38 * sx, -0.05, 0.56))
    mid = sh.lerp(el, 0.6)
    capsule(f"Sleeve.{side}", [sh, mid], 0.07, 0.064, "Shirt", ["chest", f"upper_arm.{side}"])
    torus(f"Sleeve Hem.{side}", mid, 0.062, 0.012, "Shirt Shade", [f"upper_arm.{side}"],
          rot=(el - sh).normalized().to_track_quat('Z', 'Y').to_matrix())
    capsule(f"Arm.{side}", [sh.lerp(el, 0.3), el, wr], 0.05, 0.045, "Skin", [f"upper_arm.{side}", f"forearm.{side}"])
    d = (wr - el).normalized()
    ellipsoid(f"Hand.{side}", wr + d * 0.05, (0.052, 0.047, 0.06), "Skin", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", wr + d * 0.035 + Vector((0, -0.04, 0.005)), (0.02, 0.024, 0.028), "Skin",
              [f"hand.{side}"])
    # Ripped jean shorts: a frayed light cuff and a patch on one leg
    x = 0.11 * sx
    capsule(f"Shorts.{side}", [(0.10 * sx, 0, 0.52), (x, 0, 0.36)], 0.108, 0.104, "Denim", [("hips", 1.6),
                                                                                          f"thigh.{side}"])
    torus(f"Shorts Cuff.{side}", (x, 0, 0.355), 0.102, 0.014, "Denim Light", [f"thigh.{side}"])
    for k in range(7):
        a = 2 * math.pi * (k + R.uniform(0, 0.4)) / 7
        fp = Vector((x + 0.104 * math.cos(a), 0.104 * math.sin(a), 0.345))
        lock(f"Fray.{side}{k}", [fp, fp + Vector((0.004 * math.cos(a), 0.004 * math.sin(a), -0.02))], 0.008,
             "Denim Light", [f"thigh.{side}"], flat=0.6, sides=6)
    capsule(f"Leg.{side}", [(x, 0, 0.37), (x, 0, 0.12)], 0.062, 0.058, "Skin", [f"thigh.{side}", f"shin.{side}"])
    ellipsoid(f"Shoe.{side}", (x, -0.045, 0.07), (0.076, 0.125, 0.064), "Shoes", [f"foot.{side}"], power=0.75)
    ellipsoid(f"Sole.{side}", (x, -0.045, 0.022), (0.082, 0.13, 0.024), "Sole", [f"foot.{side}"], power=0.5)
    ellipsoid(f"Toe.{side}", (x, -0.135, 0.045), (0.06, 0.045, 0.036), "Sole", [f"foot.{side}"])
    for k, yy in enumerate((-0.085, -0.055, -0.025)):
        ellipsoid(f"Lace.{side}{k}", (x, yy, 0.125 - k * 0.004), (0.04, 0.007, 0.006), "Sole", [f"foot.{side}"],
                  power=0.6, u=12, v=6)
patch = Vector((0.115, -0.1, 0.43))
ellipsoid("Patch", patch, (0.035, 0.006, 0.03), "Denim Light", ["thigh.L"], rot=basis_facing(Vector((0.3, -1, 0))),
          power=0.4)

BONES = biped_bones(shoulder=(0.225, 0, 0.80), elbow=(0.31, -0.03, 0.67), wrist=(0.38, -0.05, 0.56),
                    hand_tip=(0.43, -0.065, 0.49), hip_x=0.11, knee=0.33)
rig = build_rig("RookRig", BONES)
skin_and_join(rig, BONES, "Rook", "Torso")

# =============================================================================
# On all fours: hands and feet on the ground, bottom up (his arms are short, so his back slopes down to
# his shoulders), head tipped up to look ahead. Everything is in place; the game moves him around.
# =============================================================================
HIP_Y, HIP_Z = 0.13, 0.45          # where his hips sit
PITCH = 1.95                       # how far his body tips forward from standing (radians)
HEAD_LOOK = -1.72                  # head tipped back up from that
WRIST_Z = 0.072                    # hands flat on the ground
ANKLE_Z = 0.10                     # same as standing: feet flat


def step(u, stride, lift, duty=0.5):
    """One leg's loop: on the ground sliding back for 'duty' of it, then lifted and swung forward.
    Returns (forward/back offset along +Y, height off the ground)."""
    u %= 1.0
    if u < duty:
        s = u / duty
        return stride * (s - 0.5), 0.0
    s = (u - duty) / (1 - duty)
    return stride * (0.5 - ss(0, 1, s)), lift * math.sin(math.pi * s)


def all_fours(t=0.0, stride=0.0, lift=0.0, phases=(0, 0, 0, 0), duty=0.5, bob=0.0, flex=0.0, sway=0.0,
              head=0.0, tilt=0.0, lift_front=0.0):
    """phases: (left hand, right hand, left foot, right foot). flex tips the body up (+) / down (-),
    head tips the head further up, lift_front raises the shoulders (bark)."""
    p = Pose(BONES)
    p.offset = Vector((0, HIP_Y, HIP_Z - BONES["hips"][0][2] + bob))
    p.rel("hips", (X, PITCH - flex - lift_front))
    p.rel("spine", (Z, sway))
    p.rel("chest", (Z, sway))
    p.rel("head", (X, HEAD_LOOK - head + flex + lift_front), (Y, tilt))
    for i, side in enumerate(("L", "R")):
        s = 1 if side == "L" else -1
        dy, dz = step(t + phases[i], stride, lift, duty)
        shoulder = p.head(f"upper_arm.{side}")
        wrist = Vector((0.235 * s, shoulder.y - 0.02 + dy, WRIST_Z + dz))
        p.ik(f"upper_arm.{side}", f"forearm.{side}", wrist, Vector((0.2 * s, 1, 0)))       # elbows point back
        p.aim(f"hand.{side}", Vector((0.1 * s, -1, -0.12 - 1.5 * dz)))
        dy, dz = step(t + phases[2 + i], stride, lift, duty)
        ankle = Vector((0.115 * s, HIP_Y + 0.06 + dy, ANKLE_Z + dz))
        p.ik(f"thigh.{side}", f"shin.{side}", ankle, Vector((0, -1, 0.2)))                 # knees forward
        p.set_abs(f"foot.{side}", Matrix.Rotation(-2.0 * dz, 3, 'X'))                     # toes drop when lifted
    return p


def idle(t):
    # Panting (quick little chest bobs), head tilting side to side
    ph = 2 * math.pi * t
    return all_fours(bob=0.006 * math.sin(4 * ph), flex=0.015 * math.sin(4 * ph), tilt=0.16 * math.sin(ph),
                     head=0.05 * math.sin(ph + 1.0))


def walk(t):
    # Trot: diagonal pairs move together
    ph = 2 * math.pi * t
    return all_fours(t, stride=0.16, lift=0.05, phases=(0, 0.5, 0.5, 0), duty=0.55,
                     bob=0.012 * abs(math.sin(ph)), sway=0.05 * math.sin(ph), head=0.03 * math.sin(2 * ph))


def run(t):
    # Bounding gallop: both hands land, then both feet; his back bunches and stretches
    ph = 2 * math.pi * t
    return all_fours(t, stride=0.30, lift=0.10, phases=(0.0, 0.08, 0.5, 0.58), duty=0.45,
                     bob=0.03 * math.sin(ph + 0.6), flex=0.1 * math.sin(ph), head=0.06 * math.sin(ph + 2.0))


def bark(t):
    # Woof! woof!: shoulders pop up and the head tosses up twice (the game plays the sound at 0.07 s and 0.42 s)
    b = sum(math.exp(-((t - c) / 0.06) ** 2) for c in (0.1, 0.45))
    return all_fours(lift_front=0.07 * b, head=0.35 * b, bob=0.01 * b)


make_action(rig, "idle", 60, idle)
make_action(rig, "walk", 32, walk)
make_action(rig, "run", 18, run)
make_action(rig, "bark", 30, bark)
rest_pose(rig)
finish(OUT)

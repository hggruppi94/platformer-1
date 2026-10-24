# Builds the Astronaut from scratch: model, materials, rig, weights and animations.
# Reference: Sofi's drawing (source_art/reference/Astronaut.jpg): a chunky white space suit, a round white helmet
# with a big black visor and an antenna on top, a grey backpack that pokes
# up behind the shoulders with grey hoses looping round under the arms into the hips, a chest box with an orange
# stripe and two black knobs, a big red button, a little belt panel with a red light, a US flag patch on the left
# shoulder, a black band on the right wrist, grey cuffs, blue gloves and big grey boots.
#
#   blender -b --python tools\build_astronaut.py
#
# Writes source_art/characters/astronaut.blend (overwrites it) with idle / walk actions.
# Units are meters; feet on the ground at the origin; faces -Y. Helpers: tools/char_kit.py.
# A grown-up in a puffy suit: about 1.8 m to the top of the helmet, 2 m to the tip of the antenna.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "astronaut.blend"

K.begin()
mat("Suit", (0.92, 0.92, 0.90), rough=0.7)
mat("Seam", (0.62, 0.63, 0.65), rough=0.7)
mat("Visor", (0.015, 0.015, 0.025), rough=0.06, metal=0.4)
mat("Visor Shine", (0.85, 0.9, 1.0), rough=0.05, emit=0.8)
mat("Pack", (0.48, 0.49, 0.51), rough=0.6)
mat("Pack Dark", (0.30, 0.31, 0.33), rough=0.6)
mat("Hose", (0.55, 0.56, 0.58), rough=0.5)
mat("Orange", (0.95, 0.45, 0.06), rough=0.5)
mat("Knob", (0.04, 0.04, 0.05), rough=0.35)
mat("Button", (0.92, 0.18, 0.14), rough=0.35)
mat("Light", (1.0, 0.15, 0.1), rough=0.3, emit=1.2)
mat("Flag Red", (0.78, 0.08, 0.10), rough=0.6)
mat("Flag White", (0.96, 0.96, 0.96), rough=0.6)
mat("Flag Blue", (0.08, 0.14, 0.45), rough=0.6)
mat("Band", (0.05, 0.05, 0.06), rough=0.5)
mat("Glove", (0.08, 0.22, 0.85), rough=0.5)
mat("Boot", (0.50, 0.51, 0.53), rough=0.65)
mat("Sole", (0.22, 0.22, 0.24), rough=0.8)

HEAD = Ellipsoid((0, 0, 1.47), (0.30, 0.29, 0.30))          # the helmet
BODY = ["hips", "spine", "chest"]
HB = ["head"]
FRONT_Y = -0.255                                             # the flat front of the boxy suit


def flat_bit(name, x, z, radii, material, bones, proud=0.0, power=0.35):
    """A flat, boxy patch on the front of the suit (panels, stripes, knobs)."""
    return ellipsoid(name, (x, FRONT_Y - radii[1] - proud, z), radii, material, bones, power=power, u=16, v=8)


# Helmet: a white bubble with a big black visor covering most of its front, and a shine on the visor
ellipsoid("Helmet", HEAD.c, HEAD.r, "Suit", HB, u=48, v=24)


def in_visor(p):
    # The wide oval Sofi drew: most of the helmet's width, sitting a little high
    return p.y < 0 and (p.x / 0.25) ** 2 + ((p.z - VISOR_Z) / 0.185) ** 2 < 1


# A thin shell just outside the helmet, trimmed to the visor's oval, so it hugs the helmet's curve
VISOR_Z = 1.50
visor = ellipsoid("Visor", HEAD.c, HEAD.r + Vector((0.006, 0.006, 0.006)), "Visor", HB, u=96, v=48)
bm = bmesh.new()
bm.from_mesh(visor.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if not in_visor(f.calc_center_median())], context='FACES')
bm.to_mesh(visor.data)
bm.free()
rim = [HEAD.front(0.25 * math.cos(a), VISOR_Z + 0.185 * math.sin(a), offset=0.006)
       for a in (2 * math.pi * k / 64 for k in range(65))]
tube("Visor Rim", rim, [(0.012, 0.012)] * len(rim), "Seam", HB, sides=8, caps=False)
sp = HEAD.front(-0.11, 1.585, offset=0.009)
ellipsoid("Visor Shine", sp, (0.055, 0.004, 0.024), "Visor Shine", HB,
          rot=basis_facing(HEAD.normal(sp)) @ Euler((0, math.radians(-30), 0)).to_matrix())
# Antenna straight up from the top, with a round tip
capsule("Antenna", [(0, 0, 1.76), (0, 0, 2.0)], 0.014, 0.008, "Suit", HB, sides=10, steps=4)
ellipsoid("Antenna Tip", (0, 0, 2.005), (0.022, 0.022, 0.022), "Seam", HB, u=12, v=6)
torus("Neck Ring", (0, 0, 1.19), 0.20, 0.035, "Seam", ["chest", "head"], u=40, v=10)

# Suit body: chunky and boxy, with a belt line where the top meets the trousers
torso = ellipsoid("Torso", (0, 0, 0.89), (0.33, 0.255, 0.36), "Suit", BODY + [("thigh.L", 1.8), ("thigh.R", 1.8)],
                  power=0.6, u=48, v=24)
ellipsoid("Belt", (0, 0, 0.615), (0.338, 0.262, 0.018), "Seam", ["hips"], power=0.6, u=48, v=6)
ellipsoid("Collar Line", (0, 0, 1.11), (0.30, 0.235, 0.012), "Seam", ["chest"], power=0.6, u=48, v=6)

# Chest controls: a box with an orange stripe running down it, an oval panel with a black knob each side
flat_bit("Chest Box", 0.0, 0.97, (0.105, 0.03, 0.075), "Suit", ["chest"])
flat_bit("Chest Box Edge", 0.0, 0.97, (0.112, 0.026, 0.082), "Seam", ["chest"])
flat_bit("Orange Stripe", 0.0, 0.98, (0.028, 0.01, 0.10), "Orange", ["chest"], proud=0.045)
flat_bit("Panel", 0.0, 0.85, (0.17, 0.008, 0.075), "Seam", ["spine", "chest"], power=1.0)
flat_bit("Panel Face", 0.0, 0.85, (0.16, 0.006, 0.066), "Suit", ["spine", "chest"], proud=0.004, power=1.0)
flat_bit("Orange Strip", 0.0, 0.84, (0.03, 0.01, 0.07), "Orange", ["spine"], proud=0.01)
flat_bit("Orange Window", 0.0, 0.82, (0.013, 0.004, 0.015), "Seam", ["spine"], proud=0.02, power=0.2)
for sx, side in ((1, "L"), (-1, "R")):
    flat_bit(f"Knob.{side}", 0.165 * sx, 0.86, (0.038, 0.028, 0.048), "Knob", ["spine", "chest"], power=0.8)
# The big red button low on the right of the tummy, and the little belt panel with its red light
flat_bit("Red Button", -0.17, 0.70, (0.065, 0.025, 0.065), "Button", ["hips", "spine"], power=0.9)
flat_bit("Belt Panel", 0.035, 0.67, (0.05, 0.012, 0.055), "Seam", ["hips"])
flat_bit("Belt Panel Face", 0.035, 0.67, (0.042, 0.01, 0.047), "Suit", ["hips"], proud=0.004)
flat_bit("Belt Light", 0.035, 0.65, (0.014, 0.008, 0.014), "Light", ["hips"], proud=0.012, power=1.0)

# Backpack: grey, as wide as the suit, poking up behind the shoulders beside the helmet
ellipsoid("Backpack", (0, 0.31, 1.10), (0.39, 0.12, 0.44), "Pack", ["chest", "spine"], power=0.4, u=32, v=16)
ellipsoid("Backpack Lid", (0, 0.31, 1.535), (0.35, 0.10, 0.02), "Pack Dark", ["chest"], power=0.4, u=32, v=6)

# Hoses: out of the backpack's sides, looping out behind the arms and back round into the hips
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda x, y, z: Vector((x * sx, y, z))
    path = smooth_path([m(0.36, 0.28, 1.22), m(0.48, 0.20, 1.08), m(0.54, 0.13, 0.88), m(0.49, 0.02, 0.70),
                        m(0.33, -0.07, 0.63)], per_segment=6)
    tube(f"Hose.{side}", path, [(0.045, 0.045)] * len(path), "Hose", ["chest", "spine", "hips"], sides=12)
    for k, f in enumerate((0.25, 0.5, 0.75)):                    # ribbed rings round the hose
        i = int(f * (len(path) - 1))
        d = (path[i + 1] - path[i - 1]).normalized()
        torus(f"Hose Rib.{side}{k}", path[i], 0.046, 0.008, "Pack Dark", ["spine"], u=20, v=6,
              rot=d.to_track_quat('Z', 'Y').to_matrix())

# Arms: puffy white sleeves, grey cuffs, a black band on the right wrist, blue gloves with chunky fingers.
# Rest pose is arms out, the way Sofi drew them.
SH, EL, WR = Vector((0.33, 0, 1.08)), Vector((0.47, -0.03, 0.93)), Vector((0.59, -0.06, 0.81))
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda v: Vector((v.x * sx, v.y, v.z))
    sh, el, wr = m(SH), m(EL), m(WR)
    ellipsoid(f"Shoulder.{side}", sh + Vector((-0.03 * sx, 0, 0)), (0.11, 0.11, 0.10), "Suit",
              ["chest", f"upper_arm.{side}"])
    capsule(f"Sleeve.{side}", [sh, el, wr], 0.095, 0.08, "Suit", [f"upper_arm.{side}", f"forearm.{side}"])
    d = (wr - el).normalized()
    ring = d.to_track_quat('Z', 'Y').to_matrix()
    torus(f"Elbow Seam.{side}", el, 0.088, 0.008, "Seam", [f"upper_arm.{side}", f"forearm.{side}"], u=24, v=6,
          rot=ring)
    capsule(f"Cuff.{side}", [wr - d * 0.01, wr + d * 0.045], 0.078, 0.074, "Seam", [f"forearm.{side}"])
    if side == "R":
        capsule("Wrist Band", [wr - d * 0.09, wr - d * 0.035], 0.087, 0.084, "Band", ["forearm.R"])
    palm = wr + d * 0.10
    ellipsoid(f"Glove.{side}", palm, (0.065, 0.04, 0.07), "Glove", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    side_dir = d.cross(Vector((0, -1, 0))).normalized() * sx
    for f in range(4):
        base = palm + d * 0.05 + side_dir * (0.035 - 0.023 * f) * -1
        tip = base + (d * (0.06 - 0.008 * abs(f - 1.5)) + side_dir * (0.012 * (f - 1.5)) * -1)
        capsule(f"Finger.{side}{f}", [base, tip], 0.018, 0.016, "Glove", [f"hand.{side}"], sides=10, steps=5)
    thumb0 = palm + Vector((0, -0.035, 0.03))
    capsule(f"Thumb.{side}", [thumb0, thumb0 + Vector((0.03 * sx, -0.035, 0.045))], 0.02, 0.018, "Glove",
            [f"hand.{side}"], sides=10, steps=5)

    # Legs: wide white trouser legs into big grey boots
    x = 0.16 * sx
    capsule(f"Leg.{side}", [(0.15 * sx, 0, 0.60), (x, 0, 0.36), (x, 0, 0.26)], 0.135, 0.125, "Suit",
            [("hips", 1.6), f"thigh.{side}", f"shin.{side}"])
    torus(f"Knee Seam.{side}", (x, 0, 0.40), 0.128, 0.008, "Seam", [f"thigh.{side}", f"shin.{side}"], u=28, v=6)
    capsule(f"Boot Top.{side}", [(x, 0.0, 0.31), (x, 0.0, 0.12)], 0.14, 0.14, "Boot", [f"shin.{side}", f"foot.{side}"])
    ellipsoid(f"Boot.{side}", (x, -0.07, 0.085), (0.14, 0.22, 0.085), "Boot", [f"foot.{side}"], power=0.65)
    ellipsoid(f"Sole.{side}", (x, -0.07, 0.022), (0.148, 0.228, 0.024), "Sole", [f"foot.{side}"], power=0.45)

# US flag patch on the left upper arm (red and white stripes, blue corner), facing out and a little forward
arm = (EL - SH).normalized()
fn = Vector((0.75, -0.66, 0.0))
fn = (fn - arm * fn.dot(arm)).normalized()                       # straight out from the sleeve
fc = SH.lerp(EL, 0.32) + fn * 0.1
az = -arm                                                        # up the patch: toward the shoulder
ax = (-fn).cross(az).normalized()                                # across, left to right as you look at it
FR = Matrix((ax, -fn, az)).transposed()                          # local x across, -y out of the sleeve, z up
FB = ["upper_arm.L"]
ellipsoid("Flag", fc, (0.056, 0.005, 0.038), "Flag White", FB, rot=FR, power=0.2, u=16, v=8)
for k in range(4):
    zc = 0.029 - k * 0.0195
    ellipsoid(f"Flag Stripe.{k}", fc + az * zc + fn * 0.003, (0.055, 0.004, 0.0056), "Flag Red", FB, rot=FR,
              power=0.2, u=16, v=6)
ellipsoid("Flag Stars", fc - ax * 0.031 + az * 0.017 + fn * 0.007, (0.024, 0.004, 0.02), "Flag Blue", FB, rot=FR,
          power=0.2, u=12, v=6)

BONES = biped_bones(hips=0.62, chest=1.0, neck=1.18, head_top=1.78, shoulder=tuple(SH), elbow=tuple(EL),
                    wrist=tuple(WR), hand_tip=(0.67, -0.08, 0.72), hip_x=0.16, knee=0.38, ankle=0.13,
                    toe=(-0.26, 0.04))
rig = build_rig("AstronautRig", BONES)
skin_and_join(rig, BONES, "Astronaut", "Torso")


# The puffy suit keeps the arms out a bit, so idle and walk only drop them a little from the drawing's pose.
def arms_low(p, drop, swing_l=(), swing_r=()):
    p.rel("upper_arm.L", (Y, drop), *swing_l)
    p.rel("upper_arm.R", (Y, -drop), *swing_r)
    p.rel("forearm.L", (X, -0.2))
    p.rel("forearm.R", (X, -0.2))


def idle(t):
    # Slow and floaty, like there's not much gravity: a gentle bob, the helmet looking about
    ph = 2 * math.pi * t
    s = math.sin(ph)
    p = Pose(BONES)
    arms_low(p, 0.28 + 0.05 * s, [(X, -0.06 * s)], [(X, 0.06 * s)])
    p.rel("spine", (X, 0.015 * s))
    p.rel("head", (Z, 0.12 * math.sin(ph + 0.8)), (X, -0.03 * math.sin(2 * ph)))
    p.offset = Vector((0, 0, 0.012 * s))
    return p


def walk(t):
    # A bouncy moon walk: big slow steps with a little hop on each one
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.38 * s))
    p.rel("thigh.R", (X, 0.38 * s))
    p.rel("shin.L", (X, 0.08 + 0.5 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.08 + 0.5 * max(0.0, c)))
    p.rel("foot.L", (X, -0.1 * s))
    p.rel("foot.R", (X, 0.1 * s))
    arms_low(p, 0.22, [(X, 0.3 * s)], [(X, -0.3 * s)])
    p.rel("spine", (X, 0.03), (Z, 0.05 * s))
    p.rel("head", (Z, -0.05 * s))
    p.offset = Vector((0, 0, 0.05 * abs(math.sin(ph))))
    return p


make_action(rig, "idle", 90, idle)
make_action(rig, "walk", 40, walk)
rest_pose(rig)
finish(OUT)

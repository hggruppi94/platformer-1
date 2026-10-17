# Builds the moth kid (working name: Pip) from scratch: model, materials, rig, weights and animations.
# Reference: openart/images crop of the moth kid by the waterfall (blue skin, big purple eyes,
# antennae with purple tips, spiky orange/purple/teal mane, rainbow chevron bodysuit, pink and
# yellow wings, green backpack straps).
#
#   blender -b --python tools\build_moth_kid.py
#
# Writes source_art/characters/moth_kid.blend (overwrites it). Units are meters; feet at the origin;
# faces -Y. Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "moth_kid.blend"

K.begin()

# =============================================================================
# Materials (linear colors)
# =============================================================================
mat("Skin", (0.10, 0.45, 0.85))
mat("Skin Shade", (0.05, 0.26, 0.60))
mat("Nose", (0.10, 0.12, 0.17))
mat("Blush", (0.85, 0.30, 0.55))
mat("Mouth", (0.20, 0.02, 0.06))
mat("Tongue", (0.85, 0.25, 0.35))
mat("Brow", (0.03, 0.12, 0.35))
eye_materials((0.22, 0.02, 0.50), (0.55, 0.15, 0.85))
mat("Mane Orange", (0.95, 0.33, 0.02), rough=0.45)
mat("Mane Purple", (0.30, 0.05, 0.55), rough=0.45)
mat("Mane Teal", (0.02, 0.45, 0.42), rough=0.45)
mat("Mane Pink", (0.80, 0.08, 0.40), rough=0.45)
mat("Antenna", (0.12, 0.55, 0.80), rough=0.4)
mat("Antenna Tip", (0.40, 0.06, 0.65), rough=0.25)
mat("Suit Navy", (0.02, 0.05, 0.30), rough=0.4)
mat("Suit Blue", (0.03, 0.18, 0.75), rough=0.4)
mat("Suit Yellow", (0.95, 0.65, 0.03), rough=0.4)
mat("Suit Red", (0.80, 0.04, 0.03), rough=0.4)
mat("Wing Pink", (0.92, 0.18, 0.45), rough=0.35)
mat("Wing Yellow", (0.98, 0.78, 0.10), rough=0.35)
mat("Wing Orange", (0.98, 0.40, 0.10), rough=0.35)
mat("Backpack", (0.04, 0.22, 0.10), rough=0.5)

HEAD = Ellipsoid((0, 0, 1.07), (0.27, 0.25, 0.26))
TORSO = Ellipsoid((0, 0, 0.62), (0.20, 0.18, 0.24))
HB = ["head"]

# =============================================================================
# Head and face
# =============================================================================
ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HB, u=48, v=24)
capsule("Neck", [(0, 0, 0.82), (0, 0, 0.94)], 0.06, 0.06, "Skin", ["chest", "head"])

for sx, side in ((1, "L"), (-1, "R")):
    ec = HEAD.front(0.105 * sx, 1.09) + Vector((0, 0.026, 0))
    cartoon_eye(side, ec, (0.076, 0.05, 0.09), HB)
    arc_on(HEAD, f"Brow.{side}", [(sx * (0.06 + 0.09 * t), 1.205 + 0.016 * math.sin(math.pi * t)) for t in
                                  (i / 7 for i in range(8))], 0.009, "Brow", HB)
    b = HEAD.front(0.17 * sx, 1.005)
    ellipsoid(f"Blush.{side}", b - HEAD.normal(b) * 0.006, (0.04, 0.012, 0.027), "Blush", HB,
              rot=basis_facing(HEAD.normal(b)))
    # Little round ears with a curl, low on the sides of the head
    ear = HEAD.dir_point((sx, 0.05, -0.05), offset=0.005)
    er = Euler((0, 0, math.radians(-75 * sx))).to_matrix()
    ellipsoid(f"Ear.{side}", ear, (0.05, 0.03, 0.06), "Skin", HB, rot=er)
    torus(f"Ear Curl.{side}", ear + Vector((0.012 * sx, -0.006, 0.0)), 0.026, 0.009, "Skin Shade", HB, u=16, v=8,
          rot=Euler((math.radians(90), 0, math.radians(90 - 75 * sx))).to_matrix())

n = HEAD.front(0, 1.02)
ellipsoid("Nose", n + HEAD.normal(n) * 0.002, (0.017, 0.012, 0.012), "Nose", HB)
smile("Mouth", HEAD, 0.0, 0.975, 0.062, 0.036, HB, curl=0.018)

# Antennae: thin stalks curving up and out, each ending in a purple ball
ANT = {}
for sx, side in ((1, "L"), (-1, "R")):
    base = HEAD.dir_point((0.32 * sx, -0.15, 1.0), offset=-0.005)
    path = [base, base + Vector((0.03 * sx, 0.0, 0.10)), base + Vector((0.08 * sx, -0.015, 0.20)),
            base + Vector((0.12 * sx, -0.03, 0.26))]
    pts = smooth_path(path)
    tube(f"Antenna.{side}", pts, [(0.012, 0.012)] * len(pts), "Antenna", [f"antenna.{side}"], sides=10)
    ellipsoid(f"Antenna Tip.{side}", path[-1], (0.036, 0.036, 0.036), "Antenna Tip", [f"antenna.{side}"])
    ANT[side] = (base, path[-1])

# =============================================================================
# Mane: a base cap with the face cut out, then lots of colourful spikes all over it
# =============================================================================
R = rng(11)
scalp_cap("Mane Base", HEAD, "Mane Orange", HB, thick=0.02,
          hairline=lambda x: 1.235 - 0.30 * ss(0.17, 0.26, abs(x)))
COLORS = ["Mane Orange"] * 4 + ["Mane Purple"] * 3 + ["Mane Teal"] * 3 + ["Mane Pink"]
N_SPIKES = 150
for k in range(N_SPIKES):                                   # evenly spread over the head (golden spiral)
    zc = 1 - 1.25 * (k + 0.5) / N_SPIKES
    az = k * math.pi * (3 - math.sqrt(5))
    rr = math.sqrt(max(0.0, 1 - zc * zc))
    d = Vector((math.sin(az) * rr, math.cos(az) * rr, zc))
    s = HEAD.dir_point(d, offset=0.005)
    if s.y < HEAD.c.y - 0.08 and s.z < 1.25 and abs(s.x) < 0.25:
        continue                                              # keep the face clear
    elev = math.degrees(math.asin(max(-1.0, min(1.0, zc))))
    nrm = HEAD.normal(s)
    droop = Vector((0, 0.45, -0.7)) * (1 - ss(-10, 70, elev)) + Vector((0, 0.15, 0))
    wobble = Vector((R.uniform(-0.25, 0.25), R.uniform(-0.2, 0.2), R.uniform(-0.15, 0.15)))
    length = R.uniform(0.12, 0.21) * (0.75 if s.y < -0.05 else 1.0)
    tipdir = (nrm + droop + wobble).normalized()
    mid = s + (nrm * 0.6 + tipdir * 0.4) * length * 0.5
    lock(f"Spike.{k}", [s - nrm * 0.015, mid, s + tipdir * length], R.uniform(0.042, 0.055), R.choice(COLORS), HB,
         flat=0.45, normal_fn=lambda p, n0=nrm: n0.cross(Z).cross(n0) if abs(n0.z) < 0.95 else Y, sides=8,
         taper=0.7)
# A tall tuft on top of the head, front and center
for j, (dx, dz, m) in enumerate(((-0.05, 0.16, "Mane Orange"), (0.0, 0.2, "Mane Teal"), (0.05, 0.17, "Mane Orange"),
                                 (0.025, 0.13, "Mane Purple"), (-0.03, 0.12, "Mane Purple"))):
    s = HEAD.dir_point((dx, -0.35, 1.0), offset=0.0)
    lock(f"Tuft.{j}", [s, s + Vector((dx * 0.6, -0.04, dz * 0.5)), s + Vector((dx * 1.4, -0.02, dz))], 0.045, m, HB,
         flat=0.5, normal_fn=lambda p: Vector((0, -1, 0)), sides=8, taper=0.8)

# =============================================================================
# Body: rainbow chevron bodysuit (V shapes pointing down on the front), blue arms and legs
# =============================================================================
torso = ellipsoid("Torso", TORSO.c, TORSO.r, "Suit Navy", ["hips", "spine", "chest", ("thigh.L", 1.8),
                                                            ("thigh.R", 1.8)], u=160, v=80)
BANDS = ["Suit Blue", "Suit Yellow", "Suit Red", "Suit Yellow", "Suit Blue", "Suit Yellow", "Suit Navy"]
idx = {m: add_material(torso, m) for m in set(BANDS)}
for p in torso.data.polygons:
    c = p.center
    if c.y > 0.05 or c.z < 0.44:
        continue                                                   # back and seat stay navy
    v = (0.83 - (c.z - 0.6 * abs(c.x))) / 0.058                     # chevrons point down at the middle
    if v >= 0:
        p.material_index = idx[BANDS[min(int(v), len(BANDS) - 1)]]

for sx, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.20 * sx, 0, 0.78)), Vector((0.29 * sx, -0.03, 0.66)), Vector((0.36 * sx, -0.05, 0.55))
    capsule(f"Arm.{side}", [sh, el, wr], 0.05, 0.045, "Skin", [f"upper_arm.{side}", f"forearm.{side}"])
    capsule(f"Suit Sleeve.{side}", [sh + Vector((-0.02 * sx, 0, 0.0)), sh.lerp(el, 0.2)], 0.06, 0.058, "Suit Navy",
            [f"upper_arm.{side}", ("chest", 1.6)])
    d = (wr - el).normalized()
    ellipsoid(f"Hand.{side}", wr + d * 0.04, (0.05, 0.045, 0.058), "Skin", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", wr + d * 0.026 + Vector((0, -0.038, 0.005)), (0.019, 0.023, 0.027), "Skin",
              [f"hand.{side}"])
    x = 0.105 * sx
    capsule(f"Leg.{side}", [(0.10 * sx, 0, 0.47), (x, 0, 0.30), (x, -0.005, 0.09)], 0.08, 0.066, "Skin",
            [("hips", 1.6), f"thigh.{side}", f"shin.{side}"])
    ellipsoid(f"Foot.{side}", (x, -0.04, 0.05), (0.07, 0.10, 0.05), "Skin", [f"foot.{side}"], power=0.85)
    for t in (-1, 0, 1):
        ellipsoid(f"Toe.{side}{t}", (x + 0.035 * t, -0.13 + 0.01 * abs(t), 0.032), (0.026, 0.03, 0.026), "Skin",
                  [f"foot.{side}"])

# =============================================================================
# Wings: two on each side (big upper, smaller lower), pink with yellow and orange stripes
# =============================================================================
def wing(name, root, direction, length, width, bones, sx):
    ex = Vector(direction).normalized()
    ey = (Vector((0, 1, 0)) - ex * ex.y).normalized()               # the flat side faces backward
    ez = ex.cross(ey)
    Rw = Matrix((ex, ey, ez)).transposed()
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=1.0)
    for vt in bm.verts:
        u = (vt.co.x + 1) / 2
        w = math.sin(math.pi * min(u * 0.92 + 0.04, 1.0)) ** 0.55 * (1 - 0.25 * u)
        local = Vector((u * length, vt.co.y * 0.009, vt.co.z * width * w))
        vt.co = Vector(root) + Rw @ local
    ob = new_obj(name, bm, "Wing Pink", bones)
    yi, oi = add_material(ob, "Wing Yellow"), add_material(ob, "Wing Orange")
    inv = Rw.inverted()
    for p in ob.data.polygons:
        lc = inv @ (p.center - Vector(root))
        a = math.atan2(lc.z, lc.x)                                  # stripes fan out from the root
        r = lc.length / length
        band = int((a + 1.2) / 0.32)
        if 0.18 < r < 0.86:
            if band % 3 == 1:
                p.material_index = yi
            elif band % 3 == 2 and r > 0.4:
                p.material_index = oi
    return ob


WING_ROOT = {}
for sx, side in ((1, "L"), (-1, "R")):
    root = Vector((0.07 * sx, 0.15, 0.70))
    WING_ROOT[side] = root
    wing(f"Wing Upper.{side}", root + Vector((0, 0, 0.03)), (0.95 * sx, 0.22, 0.30), 0.38, 0.14, [f"wing.{side}"], sx)
    wing(f"Wing Lower.{side}", root + Vector((0, 0, -0.06)), (0.90 * sx, 0.22, -0.55), 0.30, 0.10, [f"wing.{side}"], sx)

# Small backpack between the wings, straps over the shoulders
BP = ["chest"]
ellipsoid("Backpack", (0, 0.22, 0.60), (0.11, 0.07, 0.13), "Backpack", BP, power=0.45, u=32, v=16)
for sx, side in ((1, "L"), (-1, "R")):
    path = [(0.07 * sx, 0.18, 0.72), (0.11 * sx, 0.08, 0.84), (0.13 * sx, -0.06, 0.84), (0.15 * sx, -0.15, 0.72),
            (0.16 * sx, -0.14, 0.58), (0.16 * sx, -0.10, 0.50)]
    pts = []
    for a, b in zip(path, path[1:]):
        for k in range(6):
            pts.append(TORSO.project(Vector(a).lerp(Vector(b), k / 6), offset=0.014))
    pts.append(TORSO.project(path[-1], offset=0.014))
    tube(f"Backpack Strap.{side}", pts, [(0.018, 0.006)] * len(pts), "Backpack", BP, sides=8, normal_fn=TORSO.normal)

# =============================================================================
# Rig, skin, animations
# =============================================================================
BONES = biped_bones(hips=0.48, chest=0.74, neck=0.88, head_top=1.36, shoulder=(0.20, 0, 0.78),
                    elbow=(0.29, -0.03, 0.66), wrist=(0.36, -0.05, 0.55), hand_tip=(0.40, -0.065, 0.48),
                    hip_x=0.105, knee=0.30, ankle=0.09)
for sx, side in ((1, "L"), (-1, "R")):
    base, tip = ANT[side]
    BONES[f"antenna.{side}"] = (tuple(base), tuple(tip), "head")
    r = WING_ROOT[side]
    BONES[f"wing.{side}"] = (tuple(r), (0.32 * sx, 0.28, 0.70), "chest")
rig = build_rig("MothKidRig", BONES)
skin_and_join(rig, BONES, "MothKid", "Torso")


def wings_and_antennae(p, t, flap, speed=1):
    """Wings flap about the body's forward axis; antennae bob a little behind the motion."""
    a = flap * math.sin(2 * math.pi * speed * t)
    p.rel("wing.L", (Y, -a), (Z, 0.15 * a))
    p.rel("wing.R", (Y, a), (Z, -0.15 * a))
    b = 0.12 * math.sin(2 * math.pi * t - 0.8)
    p.rel("antenna.L", (Y, b), (X, 0.5 * b))
    p.rel("antenna.R", (Y, -b), (X, 0.5 * b))
    return p


def fly(t):
    # Hovering: legs dangle, arms out for balance, wings beating fast
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.35 + 0.08 * s))
    p.rel("thigh.R", (X, -0.25 - 0.08 * s))
    p.rel("shin.L", (X, 0.55))
    p.rel("shin.R", (X, 0.45))
    p.rel("foot.L", (X, 0.4))
    p.rel("foot.R", (X, 0.4))
    p.rel("upper_arm.L", (Y, -0.25 + 0.06 * s))
    p.rel("upper_arm.R", (Y, 0.25 + 0.06 * s))
    p.rel("forearm.L", (X, -0.4))
    p.rel("forearm.R", (X, -0.4))
    p.rel("spine", (X, 0.08))
    p.rel("head", (X, -0.08))
    p.offset = Vector((0, 0, 0.22 + 0.03 * s))
    return wings_and_antennae(p, t, 0.55, speed=4)


make_action(rig, "idle", 60, lambda t: wings_and_antennae(biped_idle(BONES, t), t, 0.12, speed=2))
make_action(rig, "walk", 32, lambda t: wings_and_antennae(biped_walk(BONES, t), t, 0.08, speed=2))
make_action(rig, "run", 20, lambda t: wings_and_antennae(biped_run(BONES, t), t, 0.25, speed=2))
make_action(rig, "fly", 24, fly)
rest_pose(rig)
finish(OUT)

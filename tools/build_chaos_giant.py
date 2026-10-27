# Builds the agent of chaos, the giant villain, from scratch: model, materials, rig, weights and animations.
# Reference: Hayden's picture of a giant hooded figure in gold and dark armour wrapped in torn bone-white cloth,
# a spiked crown, a big round shoulder plate, a clawed hand raised. Made MORE chaotic and scary (Hayden asked for
# the skulls back, 2026-10-27): gold skulls on the knees, boots, belt, shoulder and crown, everything lopsided,
# a broken crown that won't sit still, the reference's pointed hood and shadowed masked face (2026-10-27), a cracked clock on his chest running
# backwards (he wants time to run out), ember and magenta energy in the cracks, broken bits of time orbiting him.
#
#   blender -b --python tools\build_chaos_giant.py
#
# Writes source_art/characters/chaos_giant.blend (overwrites it) with idle / walk / chaos actions.
# Units are meters; feet on the ground at the origin; faces -Y. Helpers: tools/char_kit.py.
# Built at about 2.75 m (crown tip) so the kit's mesh density stays sane; scale the node in Godot
# (x4 makes him ~11 m, about seven kids tall).

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "chaos_giant.blend"

K.begin()
mat("Gold", (0.80, 0.55, 0.16), rough=0.42, metal=0.7)
mat("Gold Dark", (0.38, 0.24, 0.07), rough=0.42, metal=0.6)
mat("Armour", (0.055, 0.045, 0.05), rough=0.45, metal=0.45)
mat("Armour Plum", (0.07, 0.03, 0.06), rough=0.45, metal=0.35)
mat("Cloth", (0.70, 0.62, 0.48), rough=0.9)
mat("Cloth Shade", (0.42, 0.35, 0.26), rough=0.9)
mat("Bone", (0.86, 0.80, 0.64), rough=0.6)
mat("Void", (0.004, 0.0, 0.012), rough=0.9)
mat("Clock Face", (0.62, 0.56, 0.42), rough=0.6)
mat("Ink", (0.03, 0.02, 0.03), rough=0.5)
mat("Chaos Magenta", (0.95, 0.04, 0.32), emit=5.0)
mat("Eye Fire", (1.0, 0.22, 0.03), emit=14.0)
mat("Eye Gold", (1.0, 0.62, 0.15), emit=14.0)
mat("Chaos Ember", (1.0, 0.38, 0.04), emit=5.0)
mat("Chaos Violet", (0.50, 0.10, 1.0), emit=4.0)
GLOW = ["Chaos Magenta", "Chaos Ember", "Chaos Violet"]

R = rng(7)
TORSO = Ellipsoid((0, 0, 1.40), (0.40, 0.30, 0.42))
PLATE = Ellipsoid((0, -0.10, 1.44), (0.36, 0.23, 0.31))
WAIST = Ellipsoid((0, 0, 1.06), (0.31, 0.25, 0.20))
HOOD = Ellipsoid((0, 0.01, 1.90), (0.19, 0.20, 0.22))
CB = [("chest", 1.0), ("spine", 1.4)]
HB = ["head"]

SH = Vector((0.43, 0.0, 1.63))
EL = Vector((0.63, -0.03, 1.21))
WR = Vector((0.76, -0.08, 0.84))
TIP = Vector((0.81, -0.12, 0.62))
HALO_C = Vector((0.0, 0.10, 2.02))
CLOCK_C = PLATE.front(0.03, 1.47)
CLOCK_N = PLATE.normal(CLOCK_C)


def zigzag(name, a, b, material, bones, jag=0.03, n=7, r=0.007, surf=None, offset=0.006):
    """A crackle of chaos energy from a to b. surf(p) pushes each point back onto a surface."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    side = d.cross(Vector((0, -1, 0.3))).normalized()
    pts = []
    for k in range(n + 1):
        t = k / n
        p = a + d * t + side * (jag * (1 if k % 2 else -1) * R.uniform(0.4, 1.0) if 0 < k < n else 0)
        pts.append(surf(p) if surf else p)
    return tube(name, pts, [(r, r)] * len(pts), material, bones, sides=6)


def on_torso(p):
    return TORSO.project(p, offset=0.006)


def on_limb(a, b, radius):
    a, b = Vector(a), Vector(b)

    def f(p):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        c = a + ab * t
        d = p - c
        return c + d.normalized() * (radius + 0.006) if d.length > 1e-6 else p
    return f


def shard(name, c, size, material, bones, stretch=1.6):
    """A floating diamond (an octahedron, a bit tall), turned at random."""
    rot = Euler((R.uniform(-0.6, 0.6), R.uniform(-0.6, 0.6), R.uniform(0, 3.1)))
    return ellipsoid(name, c, (size, size, size * stretch), material, bones, rot=rot, u=4, v=2)


def glitch_cube(name, c, size, material, bones):
    rot = Euler((R.uniform(0, 1.5), R.uniform(0, 1.5), R.uniform(0, 1.5)))
    return ellipsoid(name, c, (size, size, size), material, bones, rot=rot, power=0.15, u=8, v=4)


def skull(name, c, s, facing, bones, glow=True, tilt=0.0):
    """A gold skull ornament of size s (cranium radius) facing along facing: dark sockets with a burning spark
    in each, a nose hole and a row of teeth."""
    n = Vector(facing).normalized()
    B = basis_facing(n) @ Euler((0, tilt, 0)).to_matrix()
    c = Vector(c)

    def at(x, y, z):
        return c + B @ Vector((x * s, y * s, z * s))
    ellipsoid(name + " Cranium", at(0, 0, 0.1), (0.9 * s, 0.85 * s, 0.85 * s), "Gold", bones, rot=B, power=0.85,
              u=20, v=10)
    ellipsoid(name + " Brow", at(0, -0.62, 0.12), (0.78 * s, 0.22 * s, 0.16 * s), "Gold Dark", bones, rot=B, u=14, v=6)
    ellipsoid(name + " Cheeks", at(0, -0.4, -0.3), (0.72 * s, 0.5 * s, 0.48 * s), "Gold", bones, rot=B, power=0.85,
              u=16, v=8)
    ellipsoid(name + " Jaw", at(0, -0.35, -0.72), (0.5 * s, 0.42 * s, 0.24 * s), "Gold Dark", bones, rot=B, u=14, v=7)
    for sx in (1, -1):
        ellipsoid(f"{name} Socket.{sx}", at(0.33 * sx, -0.8, -0.14), (0.32 * s, 0.22 * s, 0.27 * s), "Void", bones,
                  rot=B @ Euler((0, -0.4 * sx, 0)).to_matrix(), u=12, v=6)
        if glow:
            ellipsoid(f"{name} Spark.{sx}", at(0.31 * sx, -0.97, -0.17), (0.06 * s, 0.04 * s, 0.035 * s), "Eye Fire",
                      bones, u=8, v=4)
    ellipsoid(name + " Nose", at(0, -0.86, -0.42), (0.12 * s, 0.1 * s, 0.15 * s), "Void", bones, rot=B, u=8, v=4)
    for k in range(6):
        x = -0.3 + 0.12 * k
        ellipsoid(f"{name} Tooth.{k}", at(x, -0.72 + 0.12 * abs(x), -0.6), (0.055 * s, 0.05 * s, 0.09 * s), "Bone",
                  bones, u=6, v=4)


def band(name, a, b, t, radius, material, bones, minor=0.022):
    """A gold band around a limb, t along a->b."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    return torus(name, a.lerp(b, t), radius, minor, material, bones, u=24, v=6,
                 rot=d.to_track_quat('Z', 'Y').to_matrix())


def wraps(name, a, b, radius, bones, n=3, t0=0.15, t1=0.85):
    """Torn cloth wound round a limb: a few tilted, slightly lumpy loops (like the reference's bandaging)."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    for k in range(n):
        t = t0 + (t1 - t0) * (k + R.uniform(-0.2, 0.2)) / max(n - 1, 1)
        q = d.to_track_quat('Z', 'Y').to_matrix() @ Euler((R.uniform(-0.35, 0.35), R.uniform(-0.35, 0.35), 0)).to_matrix()
        torus(f"{name}.{k}", a.lerp(b, t), radius, R.uniform(0.022, 0.034), "Cloth" if k % 2 else "Cloth Shade", bones,
              u=24, v=6, rot=q)


def rag(name, top, length, width, bones, facing, sway=(0.0, 0.0), material="Cloth"):
    """A torn strip of cloth hanging down from top, pointed (torn) at the end."""
    top = Vector(top)
    f = Vector(facing).normalized()
    mid = top + Vector((sway[0] * 0.5, sway[1] * 0.5, -length * 0.5)) + f * 0.01
    end = top + Vector((sway[0], sway[1], -length)) + f * 0.02
    return lock(name, [top, mid, end], width, material, bones, flat=0.12, tip=0.004,
                normal_fn=lambda p: f, sides=8, taper=0.55)


# =============================================================================
# Body: dark armour under a gold chest plate, cloth cowl over the shoulders
# =============================================================================
ellipsoid("Torso", TORSO.c, TORSO.r, "Armour", CB, u=40, v=20)
ellipsoid("Chest Upper", (0, 0.02, 1.56), (0.47, 0.31, 0.24), "Armour", CB, u=40, v=20)
plate = ellipsoid("Chest Plate", PLATE.c, PLATE.r, "Armour Plum", CB, power=0.8, u=40, v=20)
paint(plate, "Gold", lambda c, n: abs(c.x) > 0.29 or c.z < 1.2 or c.z > 1.68)
ellipsoid("Waist", WAIST.c, WAIST.r, "Armour Plum", [("spine", 1.0), ("hips", 1.0)], u=36, v=16)
ellipsoid("Hips", (0, 0.01, 0.98), (0.33, 0.25, 0.15), "Armour", ["hips"], u=36, v=16)
ring_on("Belt", WAIST, 1.02, 0.012, 0.04, "Gold", [("hips", 1.0), ("spine", 1.3)], sides=8)
ring_on("Belt Low", WAIST, 0.95, 0.0, 0.025, "Gold Dark", ["hips"], sides=6)

# Belt buckle: a gold skull on a lopsided diamond
bk = WAIST.front(0.02, 1.02, offset=0.04)
star_prism("Buckle", bk + Vector((0, 0.02, 0)), Vector((0, -1, 0)), 0.13, 0.04, 0.03, "Gold Dark", ["hips"], spin=0.18,
           points=4)
skull("Buckle Skull", bk + Vector((0, -0.02, 0.0)), 0.075, (0, -1, 0), ["hips"])

# Cowl: torn cloth draped over the shoulders, bunched at the neck
ellipsoid("Cowl", (0, 0.03, 1.74), (0.33, 0.27, 0.13), "Cloth", [("chest", 1.0), ("head", 2.0)], u=40, v=16)
for k in range(14):                                     # its torn hem all the way around
    a = 2 * math.pi * k / 14 + R.uniform(-0.1, 0.1)
    p = Vector((math.cos(a) * 0.32, 0.03 + math.sin(a) * 0.26, 1.70))
    f = Vector((math.cos(a), math.sin(a), 0))
    rag(f"Cowl Rag.{k}", p, R.uniform(0.12, 0.30), 0.05, CB, f, sway=(f.x * 0.05, f.y * 0.05),
        material="Cloth" if k % 3 else "Cloth Shade")

# Chest: a cracked clock in the middle of the plate, its hands spinning backwards (on the "clock" bone)
cylinder("Clock Back", CLOCK_C - CLOCK_N * 0.01, CLOCK_C + CLOCK_N * 0.035, 0.15, "Gold Dark", CB, sides=32)
cylinder("Clock Face", CLOCK_C + CLOCK_N * 0.03, CLOCK_C + CLOCK_N * 0.045, 0.125, "Clock Face", CB, sides=32)
torus("Clock Rim", CLOCK_C + CLOCK_N * 0.04, 0.135, 0.018, "Gold", CB, u=32, v=6,
      rot=CLOCK_N.to_track_quat('Z', 'Y').to_matrix())
CF = CLOCK_C + CLOCK_N * 0.047
cx_ax = CLOCK_N.cross(Vector((0, 0, 1))).normalized()
cz_ax = cx_ax.cross(CLOCK_N).normalized() * -1
for k in range(12):                                      # ticks, a few knocked out of place
    a = 2 * math.pi * k / 12 + (R.uniform(-0.25, 0.25) if k in (2, 7, 9) else 0)
    rr = 0.10 if k % 3 else 0.093
    p = CF + cx_ax * math.cos(a) * rr + cz_ax * math.sin(a) * rr
    ellipsoid(f"Tick.{k}", p, (0.008, 0.004, 0.008) if k % 3 else (0.013, 0.004, 0.013), "Ink", CB, u=6, v=3)
zigzag("Clock Crack", CF + cx_ax * 0.12 + cz_ax * 0.08, CF - cx_ax * 0.05 - cz_ax * 0.11, "Chaos Magenta", CB,
       jag=0.02, n=6, r=0.006)
zigzag("Plate Crack", PLATE.front(0.13, 1.54, 0.004), PLATE.front(0.30, 1.30, 0.004), "Chaos Magenta", CB, jag=0.025,
       surf=lambda p: PLATE.project(p, offset=0.005))
CH = ["clock"]
tube("Hand Long", [CF + CLOCK_N * 0.004, CF + CLOCK_N * 0.004 + cz_ax * 0.10], [(0.008, 0.004), (0.003, 0.003)],
     "Ink", CH, sides=6)
tube("Hand Short", [CF + CLOCK_N * 0.008, CF + CLOCK_N * 0.008 + cx_ax * 0.065], [(0.01, 0.004), (0.004, 0.003)],
     "Ink", CH, sides=6)
ellipsoid("Hand Pin", CF + CLOCK_N * 0.01, (0.014, 0.006, 0.014), "Gold", CH, u=8, v=4)

# Energy crackling over the dark armour, studs on the gold
for k, (a, b) in enumerate((((-0.36, 1.62), (-0.18, 1.18)), ((0.40, 1.15), (0.20, 1.10)),
                            ((-0.12, 1.20), (0.05, 1.12)))):
    zigzag(f"Torso Crack.{k}", TORSO.front(a[0], a[1], 0.006), TORSO.front(b[0], b[1], 0.006),
           GLOW[k % 2], CB, surf=on_torso)
for k in range(18):
    a = math.pi * (0.15 + 0.7 * k / 17)
    p = PLATE.project(PLATE.c + Vector((math.cos(a) * 0.4, -0.3, -0.24 + 0.05 * math.sin(k))), offset=0.0)
    ellipsoid(f"Stud.{k}", p, (0.014, 0.014, 0.014), "Gold", CB, u=8, v=4)

# Spikes poking out of the back, all different sizes
for k in range(5):
    x = R.uniform(-0.28, 0.28)
    z = R.uniform(1.30, 1.66)
    root = TORSO.project(Vector((x, 0.5, z)), offset=-0.02)
    n = TORSO.normal(root)
    lock(f"Back Spike.{k}", [root, root + n * 0.12 + Vector((0, 0, 0.05)), root + n * R.uniform(0.2, 0.38)
                             + Vector((x * 0.3, 0, 0.12))], 0.045, "Gold Dark", CB, flat=0.7, sides=6, taper=1.2)

# =============================================================================
# Head: the face from the reference. A tall pointed-arch hood of worn, gold-flecked cloth with a gold trim and a
# gold diamond on its point; inside, deep shadow, a dark mask with a long pointed nose plate, and two small
# glowing gold slit eyes.
# =============================================================================
hood = ellipsoid("Hood", HOOD.c + Vector((0, 0.03, 0)), (0.20, 0.21, 0.23), "Cloth", HB, u=40, v=20)
for vt in hood.data.vertices:                           # pinch the top into a gothic arch that leans forward
    c = vt.co
    u = (c.z - HOOD.c.z) / 0.23
    if u > 0:
        c.x *= 1 - 0.5 * u ** 1.5
        c.z += 0.08 * u ** 3
        c.y -= 0.07 * u ** 2
SPOTS = [(hood.data.vertices[R.randrange(len(hood.data.vertices))].co.copy(), R.uniform(0.02, 0.05),
          R.choice(("Cloth Shade", "Cloth Shade", "Gold Dark", "Gold"))) for _ in range(40)]
for m in ("Cloth Shade", "Gold Dark", "Gold"):        # worn patches and gold flecks, like the reference
    paint(hood, m, lambda c, n, m=m: any((c - sc).length < sr and sm == m for sc, sr, sm in SPOTS))
for sx in (1, -1):                                      # gold ribs running from the point down the back
    rib = [Vector((0.015 * sx, -0.06, 2.12)), Vector((0.09 * sx, 0.02, 2.04)), Vector((0.17 * sx, 0.1, 1.9)),
           Vector((0.19 * sx, 0.14, 1.76))]
    tube(f"Hood Rib.{sx}", smooth_path([HOOD.project(p, offset=0.01) if p.z < 2.0 else p for p in rib], 4),
         [(0.014, 0.01)] * 13, "Gold Dark", HB, sides=6)
VOID_C = Vector((0.0, -0.10, 1.86))
ellipsoid("Hood Void", VOID_C, (0.13, 0.12, 0.17), "Void", HB, u=32, v=16)
# The opening: a pointed arch of thick cloth with a thin gold trim just inside it
arch = [(-0.155, 1.72), (-0.15, 1.84), (-0.135, 1.93), (-0.10, 2.0), (-0.05, 2.05), (0.0, 2.08),
        (0.05, 2.05), (0.10, 2.0), (0.135, 1.93), (0.15, 1.84), (0.155, 1.72)]
brim = [Vector((x, -0.20 - 0.35 * max(z - 1.85, 0), z)) for x, z in arch]
tube("Hood Brim", smooth_path(brim, 3), [(0.045, 0.035)] * len(smooth_path(brim, 3)), "Cloth", HB, sides=10)
trim = [Vector((x * 0.82, -0.215 - 0.35 * max(z - 1.85, 0), 1.85 + (z - 1.85) * 0.86)) for x, z in arch]
tube("Hood Trim", smooth_path(trim, 3), [(0.012, 0.012)] * len(smooth_path(trim, 3)), "Gold", HB, sides=6)
shard("Hood Diamond", (0.0, -0.28, 2.12), 0.045, "Gold", HB, stretch=2.0)
for k in range(7):                                      # torn cloth falling from the hood over the shoulders
    a = math.radians(-150 + 50 * k)
    top = HOOD.c + Vector((math.cos(a) * 0.17, 0.03 + math.sin(a) * 0.17 + 0.05, -0.12))
    f = Vector((math.cos(a), math.sin(a) + 0.4, 0)).normalized()
    rag(f"Hood Rag.{k}", top, R.uniform(0.12, 0.26), 0.06, [("head", 1.0), ("chest", 1.5)], f,
        sway=(f.x * 0.05, f.y * 0.05), material="Cloth" if k % 2 else "Cloth Shade")
# In the shadow: a dark mask, angled brow plates and a long pointed nose plate down the middle
ellipsoid("Mask", (0, -0.15, 1.85), (0.10, 0.07, 0.13), "Armour", HB, power=0.8, u=20, v=10)
for sx in (1, -1):
    lock(f"Brow Plate.{sx}", [Vector((0.005 * sx, -0.215, 1.935)), Vector((0.06 * sx, -0.21, 1.915)),
                              Vector((0.10 * sx, -0.19, 1.895))], 0.022, "Gold Dark", HB, flat=0.5,
         normal_fn=lambda p: Vector((0, -1, 0.3)), sides=6, taper=1.2)
lock("Nose Plate", [Vector((0, -0.215, 1.94)), Vector((0, -0.235, 1.85)), Vector((0, -0.24, 1.74))], 0.035,
     "Gold Dark", HB, flat=0.45, normal_fn=lambda p: Vector((0, -1, 0)), sides=6, taper=1.0)
for sx in (1, -1):
    c = Vector((0.055 * sx, -0.205, 1.885))
    slant = Euler((0, 0.3 * sx, 0))                    # tipped down toward the nose: a glare
    ellipsoid(f"Eye Glow.{sx}", c, (0.03, 0.01, 0.009), "Eye Gold", HB, rot=slant, u=12, v=6)

# The broken crown: a gold ring behind the hood with jagged spikes (some snapped short), tilted off-true,
# on its own "halo" bone so it rocks and twitches. Floating shards circle it on the "shards" bone.
HALO_ROT = Euler((math.radians(90 - 10), math.radians(-14), 0)).to_matrix()
torus("Crown Ring", HALO_C, 0.30, 0.022, "Gold", ["halo"], u=48, v=6, rot=HALO_ROT)
torus("Crown Ring Inner", HALO_C, 0.24, 0.012, "Gold Dark", ["halo"], u=40, v=6, rot=HALO_ROT)
HALO_N = HALO_ROT @ Vector((0, 0, 1))
for k in range(13):
    a = math.radians(-25 + 230 * k / 12 + R.uniform(-6, 6))
    out = HALO_ROT @ Vector((math.cos(a), math.sin(a), 0))
    root = HALO_C + out * 0.30
    length = R.uniform(0.10, 0.34) if k not in (3, 9) else 0.06            # two snapped spikes
    if k == 6:
        length = 0.44                                                       # the tall middle one
    bend = HALO_N.cross(out) * R.uniform(-0.06, 0.06)
    lock(f"Crown Spike.{k}", [root - out * 0.02, root + out * length * 0.5 + bend, root + out * length + bend * 2],
         0.03, "Gold" if k % 2 else "Gold Dark", ["halo"], flat=0.45, normal_fn=lambda p: HALO_N, sides=6, taper=1.1)
    if k == 10:
        shard(f"Crown Gem.{k}", root + out * 0.02, 0.022, GLOW[k % 3], ["halo"])
    if k == 6:
        skull("Crown Skull", root + out * 0.01 - HALO_N * 0.02, 0.05, -HALO_N, ["halo"])
for k in range(7):
    a = 2 * math.pi * k / 7 + 0.3
    out = HALO_ROT @ Vector((math.cos(a), math.sin(a), 0))
    shard(f"Halo Shard.{k}", HALO_C + out * R.uniform(0.40, 0.48) + Vector((0, 0.3, 0)) + HALO_N * R.uniform(-0.04, 0.04),
          R.uniform(0.018, 0.035), "Gold" if k % 2 else GLOW[k % 3], ["shards"])

# =============================================================================
# Arms: the right one carries a huge spiked shoulder plate; the left plate has burst apart (its pieces float
# loose, held by crackling energy) and ends in the raised gold claw
# =============================================================================
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda v: Vector((v.x * sx, v.y, v.z))
    sh, el, wr, tip = m(SH), m(EL), m(WR), m(TIP)
    UA, FA, HA = [f"upper_arm.{side}"], [f"forearm.{side}"], [f"hand.{side}"]
    capsule(f"Upper Arm.{side}", [sh, el], 0.16, 0.145, "Armour", [("chest", 2.0), f"upper_arm.{side}"])
    capsule(f"Forearm.{side}", [el, wr], 0.15, 0.125, "Armour", [f"upper_arm.{side}", f"forearm.{side}"])
    ellipsoid(f"Elbow.{side}", el, (0.15, 0.15, 0.15), "Gold Dark", [f"upper_arm.{side}", f"forearm.{side}"],
              u=20, v=10)
    band(f"Arm Band.{side}", sh, el, 0.75, 0.152, "Gold", UA)
    wraps(f"Arm Wrap.{side}", sh, el, 0.155, UA, n=3, t0=0.2, t1=0.6)
    wraps(f"Forearm Wrap.{side}", el, wr, 0.14, FA, n=2, t0=0.12, t1=0.28)
    # Bracer: a big gold cuff on the forearm with a teal gem
    d = (wr - el).normalized()
    cuff = ellipsoid(f"Bracer.{side}", el.lerp(wr, 0.55), (0.17, 0.17, 0.2), "Gold", FA, power=0.7, u=24, v=12,
                     rot=d.to_track_quat('Z', 'Y').to_matrix())
    paint(cuff, "Gold Dark", lambda c, n, d=d, o=el.lerp(wr, 0.55): abs((c - o).dot(d)) > 0.15)
    shard(f"Bracer Gem.{side}", el.lerp(wr, 0.55) + Vector((0.06 * sx, -0.16, 0)), 0.03,
          "Chaos Ember" if sx > 0 else "Chaos Magenta", FA)
    for k in range(3):                                   # a row of spikes down the outside of the forearm
        a = el.lerp(wr, 0.3 + 0.18 * k) + Vector((0.15 * sx, 0.04, 0))
        lock(f"Forearm Spike.{side}{k}", [a, a + Vector((0.12 * sx, 0.03, 0.06 - 0.02 * k))], 0.035, "Gold Dark", FA,
             flat=0.6, sides=6, taper=1.1)
    for k in range(3):
        a = el.lerp(wr, 0.25 + 0.2 * k)
        rag(f"Arm Rag.{side}{k}", a + Vector((0.05 * sx, -0.12 + 0.12 * k, -0.05)), R.uniform(0.2, 0.4), 0.04,
            FA, (sx, -0.3 + 0.3 * k, 0), sway=(0.03 * sx, 0))
    zigzag(f"Arm Crack.{side}", sh.lerp(el, 0.15) + Vector((0.04 * sx, -0.12, 0)), sh.lerp(el, 0.9)
           + Vector((0.03 * sx, -0.13, 0)), GLOW[(sx + 1) // 2], UA, surf=on_limb(sh, el, 0.155))

    if side == "R":
        # The big round shoulder plate with three tall spikes and a gold ridge
        pc = sh + Vector((-0.05, 0.0, 0.08))
        p = ellipsoid("Pauldron.R", pc, (0.27, 0.26, 0.21), "Gold", [("chest", 1.6), "upper_arm.R"], power=0.85,
                      u=32, v=16, keep_above=-0.35)
        paint(p, "Gold Dark", lambda c, n: c.z < pc.z - 0.03)
        ellipsoid("Pauldron Under.R", pc + Vector((0, 0, -0.06)), (0.29, 0.28, 0.12), "Armour Plum", UA, u=32, v=12)
        PE = Ellipsoid(pc, (0.27, 0.26, 0.21))
        for k, (dx, dy, ln) in enumerate(((-0.6, -0.3, 0.34), (-0.4, 0.1, 0.45), (-0.5, 0.5, 0.28))):
            root = PE.dir_point((dx, dy, 0.8), offset=-0.03)
            n = PE.normal(root)
            lock(f"Pauldron Spike.{k}", [root, root + n * ln * 0.5 + Vector((0, 0, 0.06)), root + n * ln
                                         + Vector((0, 0, 0.18))], 0.06, "Gold Dark", [("chest", 1.6), "upper_arm.R"],
                 flat=0.75, sides=8, taper=1.1)
        sp = PE.dir_point((-0.4, -1, 0.15), offset=0.0)
        skull("Pauldron Skull", sp, 0.085, PE.normal(sp), UA)
    else:
        # The burst plate: the core stays on, chunks float off it with energy holding them
        pc = sh + Vector((0.04, 0.0, 0.09))
        ellipsoid("Pauldron.L", pc, (0.2, 0.21, 0.15), "Gold", [("chest", 1.6), "upper_arm.L"], power=0.8, u=28,
                  v=14, keep_above=-0.3)
        for k in range(6):
            a = math.radians(-60 + 34 * k)
            off = Vector((math.cos(a) * 0.3, R.uniform(-0.15, 0.15), 0.08 + math.sin(a) * 0.25))
            if off.z < 0.02:
                off.z = 0.02 + R.uniform(0.0, 0.05)
            c = pc + off
            ellipsoid(f"Plate Chunk.{k}", c, (R.uniform(0.04, 0.07), R.uniform(0.03, 0.06), R.uniform(0.025, 0.045)),
                      "Gold" if k % 2 else "Gold Dark", UA, power=0.35, u=8, v=4,
                      rot=Euler((R.uniform(-1, 1), R.uniform(-1, 1), R.uniform(-1, 1))))
            zigzag(f"Plate Bolt.{k}", pc.lerp(c, 0.45), c, GLOW[k % 2], UA, jag=0.015, n=4, r=0.005)
    # The claws: a gold palm and four long hooked talons on each hand
    palm = wr.lerp(tip, 0.4)
    ellipsoid(f"Palm.{side}", palm, (0.10, 0.075, 0.11), "Gold", HA, power=0.8, u=20, v=10)
    dn = (tip - wr).normalized()
    for k in range(4):
        base = palm + dn * 0.07 + Vector((0.02 * sx, -0.07 + 0.047 * k, 0))
        ln = (0.18, 0.22, 0.2, 0.15)[k]
        mid = base + dn * ln * 0.55 + Vector((0.01 * sx, -0.03, 0))
        end = base + dn * ln + Vector((-0.03 * sx, -0.09, 0.02))
        lock(f"Talon.{side}{k}", [base, mid, end], 0.028, "Gold", HA, flat=0.8, tip=0.004, sides=8, taper=0.9)
        ellipsoid(f"Talon Knuckle.{side}{k}", base, (0.026, 0.026, 0.026), "Gold Dark", HA, u=8, v=4)
    tb = palm + Vector((-0.04 * sx, -0.08, 0.02))
    lock(f"Talon Thumb.{side}", [tb, tb + Vector((-0.04 * sx, -0.06, -0.05)), tb + Vector((-0.02 * sx, -0.12, -0.12))],
         0.026, "Gold", HA, flat=0.8, sides=8)

# =============================================================================
# Legs: thick armoured legs wrapped in torn cloth, gold skulls on spiked knee plates (like the reference),
# heavy boots with a skull on each toe
# =============================================================================
for sx, side in ((1, "L"), (-1, "R")):
    x = 0.22 * sx
    hip, knee, ank = Vector((x, 0, 1.0)), Vector((0.24 * sx, -0.02, 0.62)), Vector((0.24 * sx, 0, 0.16))
    TB, SB = [f"thigh.{side}"], [f"shin.{side}"]
    capsule(f"Thigh.{side}", [hip, knee], 0.20, 0.17, "Armour", [("hips", 1.6), f"thigh.{side}"])
    capsule(f"Shin.{side}", [knee, ank], 0.17, 0.15, "Armour", [f"thigh.{side}", f"shin.{side}"])
    for k, t in enumerate((0.3, 0.75)):
        band(f"Thigh Band.{side}{k}", hip, knee, t, 0.19, "Gold Dark" if k else "Gold", TB, minor=0.026)
    for k, t in enumerate((0.35, 0.85)):
        band(f"Shin Band.{side}{k}", knee, ank, t, 0.16 - 0.01 * k, "Gold", SB, minor=0.024)
    wraps(f"Shin Wrap.{side}", knee, ank, 0.165, SB, n=3, t0=0.45, t1=0.75)
    # Cloth wrapped around the thigh, hanging in torn strips
    ellipsoid(f"Leg Wrap.{side}", hip.lerp(knee, 0.5) + Vector((0, 0, 0.02)), (0.215, 0.215, 0.12), "Cloth",
              TB, u=24, v=10)
    for k in range(5):
        a = math.radians(-160 + 70 * k) if sx > 0 else math.radians(-20 - 70 * k)
        f = Vector((math.cos(a), math.sin(a), 0))
        rag(f"Leg Rag.{side}{k}", hip.lerp(knee, 0.5) + f * 0.2 + Vector((0, 0, -0.05)), R.uniform(0.15, 0.3), 0.045,
            [f"thigh.{side}", (f"shin.{side}", 1.5)], f)
    # Knee: a spiked plate with a gold skull, a crack of energy behind it
    kc = knee + Vector((0, -0.2, 0.0))
    cylinder(f"Knee Plate.{side}", kc + Vector((0, 0.05, 0)), kc, 0.13, "Gold Dark", [f"thigh.{side}", f"shin.{side}"],
             sides=24)
    zigzag(f"Knee Crack.{side}", kc + Vector((-0.11 * sx, -0.006, 0.08)), kc + Vector((0.1 * sx, -0.006, -0.09)),
           GLOW[(sx + 1) // 2], [f"shin.{side}"], jag=0.015, n=5, r=0.006)
    skull(f"Knee Skull.{side}", kc + Vector((0, -0.045, 0.0)), 0.085, (0, -1, 0), [f"shin.{side}"], tilt=0.12 * sx)
    for k in range(3):                                  # spikes around the knee plate
        a = math.radians(60 + 30 * k) if sx > 0 else math.radians(120 - 30 * k)
        o = Vector((math.cos(a), 0, math.sin(a)))
        lock(f"Knee Spike.{side}{k}", [kc + o * 0.1, kc + o * (0.17 + 0.03 * k)], 0.03, "Gold Dark",
             [f"shin.{side}"], flat=0.6, sides=6)
    # Boot
    FB = [f"foot.{side}"]
    ellipsoid(f"Boot.{side}", (0.25 * sx, -0.08, 0.11), (0.19, 0.30, 0.12), "Armour", FB, power=0.7, u=28, v=12)
    ellipsoid(f"Toe Cap.{side}", (0.25 * sx, -0.25, 0.1), (0.16, 0.14, 0.1), "Gold Dark", FB, power=0.75, u=24, v=12)
    ellipsoid(f"Sole.{side}", (0.25 * sx, -0.08, 0.025), (0.2, 0.31, 0.03), "Gold Dark", FB, power=0.5, u=24, v=8)
    skull(f"Boot Skull.{side}", (0.25 * sx, -0.37, 0.13), 0.06, (0, -1, 0.35), FB, glow=False)

# Tabard: long torn strips of cloth hanging from the belt, front and back, uneven lengths
for k in range(11):
    x = -0.30 + 0.06 * k
    for facing, y in (((0, -1, 0), -0.25), ((0, 1, 0), 0.24)):
        top = WAIST.project(Vector((x, y * 4, 0.98)), offset=0.01)
        near = "thigh.L" if x > 0 else "thigh.R"
        ln = R.uniform(0.35, 0.72) if abs(x) < 0.2 else R.uniform(0.2, 0.4)
        rag(f"Tabard.{k}{'F' if y < 0 else 'B'}", top, ln, 0.05, [("hips", 1.0), (near, 1.3)], facing,
            sway=(R.uniform(-0.03, 0.03), facing[1] * 0.05), material="Cloth" if k % 4 else "Cloth Shade")
# The middle panel: a long dark strip down the front with a gold diamond (like the reference)
rag("Tabard Middle", WAIST.front(0.0, 0.96, 0.03), 0.78, 0.08, [("hips", 1.0), ("thigh.L", 1.5), ("thigh.R", 1.5)],
    (0, -1, 0), material="Armour Plum")
star_prism("Tabard Gem", (0, -0.33, 0.5), Vector((0, -1, 0)), 0.06, 0.02, 0.02, "Gold", [("hips", 1.0)], points=4)

# =============================================================================
# Broken time orbiting him: glitchy glowing cubes and gold splinters on the "orbit" bone
# =============================================================================
for k in range(14):
    a = 2 * math.pi * k / 14 + R.uniform(-0.15, 0.15)
    rr = R.uniform(0.75, 1.0)
    c = Vector((math.cos(a) * rr, math.sin(a) * rr, R.uniform(0.5, 2.15)))
    if k % 3 == 2:
        shard(f"Orbit Shard.{k}", c, R.uniform(0.02, 0.04), "Gold", ["orbit"])
    else:
        glitch_cube(f"Orbit Cube.{k}", c, R.uniform(0.025, 0.055), GLOW[k % 3], ["orbit"])

# =============================================================================
# Rig
# =============================================================================
BONES = biped_bones(hips=1.0, chest=1.45, neck=1.75, head_top=2.10, shoulder=tuple(SH), elbow=tuple(EL),
                    wrist=tuple(WR), hand_tip=tuple(TIP), hip_x=0.22, knee=0.62, ankle=0.16, toe=(-0.34, 0.05))
for side, sx in (("L", 1), ("R", -1)):                  # his legs sit a touch wide
    h, t, par = BONES[f"thigh.{side}"]
    BONES[f"thigh.{side}"] = (h, (0.24 * sx, -0.02, 0.62), par)
    BONES[f"shin.{side}"] = ((0.24 * sx, -0.02, 0.62), (0.24 * sx, 0, 0.16), f"thigh.{side}")
    BONES[f"foot.{side}"] = ((0.24 * sx, 0, 0.16), (0.24 * sx, -0.34, 0.05), f"shin.{side}")
BONES["halo"] = (tuple(HALO_C), tuple(HALO_C - HALO_N * 0.2), "head")
BONES["shards"] = (tuple(HALO_C), tuple(HALO_C - HALO_N * 0.2), "head")
BONES["clock"] = (tuple(CF), tuple(CF + CLOCK_N * 0.1), "chest")
BONES["orbit"] = ((0, 0, 1.2), (0, 0, 1.6), "root")


# Stretch him tall: legs get 30% longer and everything above the hips moves up with them, so he stands
# long-legged like the reference instead of stocky.
def lift(z):
    return z * 1.3 if z < 1.0 else z + 0.3


for ob, _ in K.PARTS:
    for vt in ob.data.vertices:
        vt.co.z = lift(vt.co.z)
BONES = {n: ((h[0], h[1], lift(h[2])), (t[0], t[1], lift(t[2])), par) for n, (h, t, par) in BONES.items()}
HALO_C = HALO_C + Vector((0, 0, 0.3))
rig = build_rig("ChaosGiantRig", BONES)
skin_and_join(rig, BONES, "ChaosGiant", "Torso")


# =============================================================================
# Animations. Everything loops; the crown, clock and orbit keep him restless even standing still.
# =============================================================================
def twitch(t, at, width=0.03):
    """A sharp glitch pulse centred on t = at (0 elsewhere)."""
    d = min(abs(t - at), 1 - abs(t - at))
    return max(0.0, 1 - d / width)


def chaos_extras(p, t, speed=1.0):
    p.rel("orbit", (Z, 2 * math.pi * t))
    p.rel("shards", (HALO_N, -2 * math.pi * t * speed))
    p.rel("clock", (CLOCK_N, 4 * math.pi * t * speed + 0.6 * twitch(t, 0.5, 0.05)))   # backwards, with a skip
    p.rel("halo", (HALO_N, 0.18 * math.sin(2 * math.pi * t * 2) * speed + 0.3 * twitch(t, 0.3)
                   - 0.25 * twitch(t, 0.72)), (X, 0.05 * math.sin(2 * math.pi * t)))


def arms_hang(p, s=0.0, swing=0.0):
    p.rel("upper_arm.R", (Y, -0.12 - 0.02 * s), (X, -swing))
    p.rel("forearm.R", (X, -0.25))
    p.rel("upper_arm.L", (Y, 0.05 + 0.02 * s), (X, swing - 0.15))
    p.rel("forearm.L", (X, -0.7))                        # claw held up a little, ready


def idle(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    arms_hang(p, s)
    p.rel("upper_arm.L", (Y, -0.05 + 0.02 * s), (X, -0.8))    # left claw raised, reaching for you
    p.rel("forearm.L", (X, -0.95 - 0.05 * s))
    p.rel("hand.L", (X, -0.35 - 0.3 * twitch(t, 0.72, 0.05)))
    p.rel("spine", (X, 0.08 + 0.02 * s))                 # big slow breaths, hunched
    p.rel("chest", (X, 0.015 * s), (Y, 0.03))
    p.rel("head", (Y, -0.08 + 0.25 * twitch(t, 0.3) - 0.2 * twitch(t, 0.72)), (X, 0.12 - 0.02 * s),
          (Z, 0.15 * twitch(t, 0.3)))
    chaos_extras(p, t)
    p.offset = Vector((0, 0, 0.012 * s))
    return p


def walk(t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(BONES)
    p.rel("thigh.L", (X, -0.3 * s))
    p.rel("thigh.R", (X, 0.3 * s))
    p.rel("shin.L", (X, 0.08 + 0.5 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.08 + 0.5 * max(0.0, c)))
    p.rel("foot.L", (X, -0.1 * s))
    p.rel("foot.R", (X, 0.1 * s))
    arms_hang(p, 0, 0.22 * s)
    p.rel("spine", (X, 0.08), (Z, 0.07 * s), (Y, 0.05 * s))   # heavy lumbering sway
    p.rel("chest", (Z, 0.04 * s))
    p.rel("head", (Z, -0.08 * s), (X, 0.04))
    chaos_extras(p, t)
    p.offset = Vector((0, 0, -0.03 * abs(math.cos(ph)) + 0.01))   # sinks into each stomp
    return p


def chaos(t):
    """Arms flung up, head back, everything spins faster: his big 'everything goes wrong' moment."""
    s = math.sin(2 * math.pi * t * 2)
    p = Pose(BONES)
    lift = 0.9 + 0.1 * s
    p.rel("upper_arm.R", (Y, lift), (X, -0.3))
    p.rel("upper_arm.L", (Y, -lift), (X, -0.3))
    p.rel("forearm.R", (X, -0.4))
    p.rel("forearm.L", (X, -0.4))
    p.rel("spine", (X, -0.1 + 0.03 * s))
    p.rel("chest", (X, -0.08), (Z, 0.08 * math.sin(2 * math.pi * t)))
    p.rel("head", (X, -0.2), (Z, 0.2 * twitch(t, 0.25) - 0.2 * twitch(t, 0.6)))
    chaos_extras(p, t, speed=3.0)
    p.rel("orbit", (Z, 2 * math.pi * t * 2))
    p.offset = Vector((0, 0, 0.02 * s))
    return p


make_action(rig, "idle", 90, idle)
make_action(rig, "walk", 48, walk)
make_action(rig, "chaos", 60, chaos)
rest_pose(rig)
finish(OUT)

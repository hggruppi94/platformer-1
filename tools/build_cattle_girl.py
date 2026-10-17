# Builds the cattle girl (working name: Bramble) from scratch: model, materials, rig, weights and animations.
# Reference: Sofi's alien-world picture of her (golden fur all over, a huge spiky golden mane with lavender and
# teal tips, big silver horns, mint-and-violet eyes, black planet crop top, olive cargo shorts with lavender trim,
# white slouch socks and chunky sneakers with glowing rings, black backpack).
#
#   blender -b --python tools\build_cattle_girl.py
#
# Writes source_art/characters/cattle_girl.blend (overwrites it). Units are meters; feet at the origin;
# she faces -Y. Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "cattle_girl.blend"

K.begin()

# =============================================================================
# Materials (linear colors)
# =============================================================================
mat("Fur", (0.78, 0.47, 0.13), rough=0.8)
mat("Fur Light", (0.90, 0.66, 0.30), rough=0.8)
mat("Muzzle", (0.93, 0.72, 0.42), rough=0.75)
mat("Nose", (0.72, 0.26, 0.26), rough=0.4)
mat("Mouth", (0.25, 0.08, 0.05))
mat("Brow", (0.30, 0.15, 0.04))
eye_materials((0.10, 0.58, 0.45), (0.38, 0.90, 0.72))
MATS["Pupil"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.05, 0.38, 1)
MATS["Pupil"].diffuse_color = (0.16, 0.05, 0.38, 1)                  # her pupils are big and violet
mat("Hair", (0.85, 0.55, 0.10), rough=0.55)
mat("Hair Shade", (0.60, 0.33, 0.05), rough=0.6)
mat("Hair Tip Lavender", (0.66, 0.56, 0.92), rough=0.5)
mat("Hair Tip Teal", (0.42, 0.82, 0.80), rough=0.5)
mat("Horn", (0.60, 0.62, 0.76), rough=0.22, metal=0.55)
mat("Horn Tip", (0.75, 0.68, 0.95), rough=0.2, metal=0.5)
mat("Top", (0.02, 0.02, 0.03), rough=0.6)
mat("Glow Teal", (0.15, 0.95, 0.85), rough=0.3, emit=2.0)
mat("Glow Violet", (0.55, 0.25, 1.0), rough=0.3, emit=3.0)
mat("Shorts", (0.13, 0.19, 0.09), rough=0.75)
mat("Shorts Trim", (0.48, 0.38, 0.85), rough=0.6)
mat("Pocket", (0.30, 0.62, 0.52), rough=0.6)
mat("Belt", (0.025, 0.025, 0.03), rough=0.5)
mat("Metal", (0.70, 0.72, 0.78), rough=0.25, metal=0.9)
mat("Alien Charm", (0.30, 0.80, 0.40), rough=0.4)
mat("Star", (0.95, 0.75, 0.10), rough=0.35, metal=0.3)
mat("Sock", (0.86, 0.86, 0.82), rough=0.9)
mat("Shoe", (0.88, 0.90, 0.88), rough=0.45)
mat("Shoe Panel", (0.32, 0.58, 0.48), rough=0.5)
mat("Sole", (0.70, 0.72, 0.74), rough=0.6)
mat("Backpack", (0.03, 0.03, 0.04), rough=0.5)

HEAD = Ellipsoid((0, 0, 1.10), (0.26, 0.24, 0.26))
TORSO = Ellipsoid((0, 0, 0.64), (0.20, 0.17, 0.245))
HB = ["head"]
R = rng(7)

# =============================================================================
# Head and face: furry, with a lighter muzzle, little pink nose and a closed smile
# =============================================================================
ellipsoid("Head", HEAD.c, HEAD.r, "Fur", HB, u=48, v=24)
capsule("Neck", [(0, 0, 0.84), (0, 0, 0.96)], 0.065, 0.065, "Fur", ["chest", "head"])
mz = HEAD.front(0, 1.0)
ellipsoid("Muzzle", mz - HEAD.normal(mz) * 0.022, (0.085, 0.03, 0.055), "Muzzle", HB, rot=basis_facing(HEAD.normal(mz)))

for sx, side in ((1, "L"), (-1, "R")):
    x = 0.105 * sx
    ec = HEAD.front(x, 1.11) + Vector((0, 0.026, 0))
    cartoon_eye(side, ec, (0.074, 0.05, 0.088), HB, look=(-0.006 * sx, 0))
    arc_on(HEAD, f"Brow.{side}", [(sx * (0.06 + 0.09 * t), 1.225 + 0.016 * math.sin(math.pi * t)) for t in
                                  (i / 7 for i in range(8))], 0.008, "Brow", HB)
    for k, (a, l) in enumerate(((30, 0.03), (10, 0.026))):              # lashes: two flicks at the outer corner
        base = ec + Vector((0.068 * sx, -0.02, 0.032 + 0.01 * k))
        tip = base + Vector((math.cos(math.radians(a)) * sx, -0.2, math.sin(math.radians(a)) + 0.4)).normalized() * l
        tube(f"Lash.{side}{k}", [base, base.lerp(tip, 0.5), tip], [(0.007, 0.005), (0.005, 0.0035), (0.0012, 0.0012)],
             "Brow", HB, sides=6)
    # Fluffy cheeks: a fan of short spikes sticking out below each ear
    for k in range(4):
        s = HEAD.dir_point((0.95 * sx, -0.25 + 0.12 * k, -0.25 - 0.08 * k), offset=-0.01)
        d = (HEAD.normal(s) + Vector((0, 0.1, -0.55 - 0.15 * k))).normalized()
        lock(f"Cheek.{side}{k}", [s, s + d * 0.05, s + d * 0.09 + Vector((0.01 * sx, 0, -0.01))], 0.035,
             "Fur Light" if k % 2 else "Fur", HB, flat=0.5, sides=8)

n = HEAD.front(0, 1.04)
ellipsoid("Nose", n + HEAD.normal(n) * 0.006, (0.021, 0.013, 0.014), "Nose", HB)
arc_on(HEAD, "Mouth", [(-0.04 + 0.08 * i / 8, 0.99 + 5.0 * (-0.04 + 0.08 * i / 8) ** 2) for i in range(9)], 0.009,
       "Mouth", HB, offset=0.004)

# Horns: big silvery crescents, out to the sides and sweeping up
for sx, side in ((1, "L"), (-1, "R")):
    base = HEAD.dir_point((0.62 * sx, 0.02, 0.78), offset=-0.015)
    path = [base, base + Vector((0.09 * sx, 0.0, 0.035)), base + Vector((0.18 * sx, 0.01, 0.12)),
            base + Vector((0.215 * sx, 0.01, 0.25)), base + Vector((0.18 * sx, -0.01, 0.35))]
    ob = lock(f"Horn.{side}", path, 0.06, "Horn", HB, flat=1.0, tip=0.006, sides=16, taper=0.75,
              normal_fn=lambda p: Vector((0, -1, 0)))           # fixed up-vector, so the rings never twist
    paint(ob, "Horn Tip", lambda c, nrm, tip=path[-1]: (c - tip).length < 0.06)

# =============================================================================
# Mane: a huge spiky lion's mane of pointed tufts, golden with lavender and teal tips
# =============================================================================
TIPS = ("Hair Tip Lavender", "Hair Tip Teal")


def spike(name, root, d, length, r0, material, bones, bend=0.0, tip_from=0.62):
    """One pointed tuft from root along d, curling down by bend; its outer part gets a pastel tip."""
    d = d.normalized()
    mid = root + d * (length * 0.5) + Vector((0, 0, -bend * 0.4 * length))
    end = root + d * length + Vector((0, 0, -bend * length))
    ob = lock(name, [root, mid, end], r0, material, bones, flat=0.38,
              normal_fn=lambda p, d=d: (d.cross(Vector((0, 0, 1))).cross(d)).normalized()
              if abs(d.z) < 0.95 else Vector((0, 1, 0)), sides=10, taper=1.0)
    if material == "Hair" and R.random() < 0.75:
        tip_mat = TIPS[R.randrange(2)]
        paint(ob, tip_mat, lambda c, nrm, a=root, e=end: (c - a).dot(e - a) / (e - a).length_squared > tip_from)
    return ob


scalp_cap("Hair Cap", HEAD, "Hair", HB, thick=0.02, hairline=lambda x: 1.275 - 0.40 * ss(0.15, 0.25, abs(x)))
# Under-layer so no body shows between the tufts
ellipsoid("Mane Fill", (0, 0.11, 0.80), (0.33, 0.17, 0.42), "Hair Shade",
          [("head", 2.0), "chest", ("spine", 1.2)], u=32, v=16)

def falling_lock(name, root, out, flare, z_end, r0, material, bones):
    """A thick lock that lifts off the scalp, then falls straight down, flaring out a little at the end."""
    out = Vector((out.x, out.y, 0)).normalized()
    drop = root.z - z_end
    ctrl = [root, root + out * 0.05 + Vector((0, 0, 0.015)),
            root + out * (0.09 + flare * 0.3) + Vector((0, 0, -drop * 0.35)),
            root + out * (0.10 + flare * 0.6) + Vector((0, 0, -drop * 0.7)),
            root + out * (0.10 + flare) + Vector((0, 0, -drop))]
    ob = lock(name, ctrl, r0, material, bones, flat=0.42, normal_fn=lambda p, o=out: o, sides=10, taper=1.1)
    if material == "Hair" and R.random() < 0.7:
        top, end = ctrl[0].z, ctrl[-1].z
        paint(ob, TIPS[R.randrange(2)], lambda cc, nrm: (top - cc.z) / (top - end) > 0.8)
    return ob


# Messy crown: short spikes on top of her head
k = 0
for e_deg in (75, 55):
    e = math.radians(e_deg)
    count = 8
    for j in range(count):
        az = math.radians(-150 + 300 * (j + 0.5 * (e_deg == 55)) / (count - 1)) + R.uniform(-0.08, 0.08)
        hd = Vector((math.sin(az) * math.cos(e), math.cos(az) * math.cos(e), math.sin(e)))
        root = HEAD.dir_point(hd, offset=-0.01)
        spike(f"Crown.{k}", root, HEAD.normal(root) + Vector((0, 0.2, 0.25)), R.uniform(0.13, 0.18),
              R.uniform(0.075, 0.09), "Hair" if R.random() < 0.8 else "Hair Shade", HB)
        k += 1

# Locks framing her face, falling past her cheeks to her shoulders
for sx, side in ((1, "L"), (-1, "R")):
    for j, (e_deg, z_end) in enumerate(((35, 0.86), (15, 0.80), (-5, 0.76), (-25, 0.74))):
        e = math.radians(e_deg)
        root = HEAD.dir_point((sx * math.cos(e) * 0.93, -0.36 * math.cos(e), math.sin(e)), offset=-0.01)
        falling_lock(f"Side Lock.{side}{j}", root, Vector((sx, 0.15, 0)), 0.03 + 0.02 * j, z_end + R.uniform(-0.03, 0.03),
                     R.uniform(0.065, 0.08), "Hair", [("head", 1.0), ("chest", 1.6)])

# The mane: rows of thick locks from all round the back of her head, falling down her back to her knees
k = 0
for row, (e_deg, z_lo, z_hi) in enumerate(((40, 0.50, 0.62), (20, 0.42, 0.55), (0, 0.36, 0.48), (-20, 0.33, 0.44))):
    e = math.radians(e_deg)
    count = 11
    for j in range(count):
        az = math.radians(-112 + 224 * (j + 0.5 * (row % 2)) / count) + R.uniform(-0.04, 0.04)
        hd = Vector((math.sin(az) * math.cos(e), math.cos(az) * math.cos(e), math.sin(e)))
        root = HEAD.dir_point(hd, offset=-0.012)
        side = abs(math.sin(az))                                # sides end a bit higher than the back
        z_end = z_hi - (z_hi - z_lo) * (1 - side) + R.uniform(-0.07, 0.07) + 0.1 * side
        bones = [("head", 1.0), ("chest", 1.0), ("spine", 1.3), ("hips", 1.6)]
        falling_lock(f"Mane.{k}", root, Vector((hd.x, hd.y + 0.35, 0)), (0.05 + 0.04 * row) * R.uniform(0.6, 1.5), z_end,
                     R.uniform(0.09, 0.11), "Hair" if R.random() < 0.82 else "Hair Shade", bones)
        k += 1


# Spiky bangs over the forehead
for j in range(7):
    u = -1 + 2 * j / 6
    root = HEAD.dir_point((0.55 * u, -0.7, 0.75), offset=-0.005)
    end_x = 0.17 * u + 0.015 * R.uniform(-1, 1)
    end = HEAD.front(end_x, 1.235 - 0.02 * abs(u) + 0.015 * R.random(), offset=0.03)
    mid = HEAD.front(end_x * 0.9, 1.31, offset=0.05)
    lock(f"Bang.{j}", [root, mid, end], 0.055, "Hair", HB, flat=0.42, normal_fn=lambda p: HEAD.normal(p), sides=10)

# =============================================================================
# Body: black crop top with a glowing planet, bare furry middle, olive cargo shorts
# =============================================================================
TOP_LO, WAIST = 0.665, 0.57
torso = ellipsoid("Torso", TORSO.c, TORSO.r, "Top", ["hips", "spine", "chest", ("thigh.L", 1.8), ("thigh.R", 1.8)],
                  u=96, v=48)
fur_i, shorts_i = add_material(torso, "Fur"), add_material(torso, "Shorts")
for p in torso.data.polygons:
    if p.center.z < WAIST:
        p.material_index = shorts_i
    elif p.center.z < TOP_LO:
        p.material_index = fur_i
ring_on("Top Hem", TORSO, TOP_LO + 0.006, 0.004, 0.008, "Top", ["spine", "chest"])

# Planet print: a circle with a tilted ring round it, drawn on the chest
PC = (0.0, 0.735)


def on_chest(name, pts_xz, r, material):
    pts = [TORSO.front(x, z, 0.004) for x, z in pts_xz]
    return tube(name, pts, [(r, r * 0.5)] * len(pts), material, ["chest", "spine"], sides=6, normal_fn=TORSO.normal,
                caps=False)


on_chest("Planet", [(PC[0] + 0.032 * math.cos(a), PC[1] + 0.032 * math.sin(a))
                    for a in (2 * math.pi * i / 32 for i in range(33))], 0.004, "Glow Teal")
tilt = math.radians(-14)
ring = []
for i in range(41):
    a = math.pi - 0.45 + (math.pi + 0.9) * i / 40           # the half in front of the planet, plus its outer ends
    x, z = 0.072 * math.cos(a), 0.018 * math.sin(a)
    ring.append((PC[0] + x * math.cos(tilt) - z * math.sin(tilt), PC[1] + x * math.sin(tilt) + z * math.cos(tilt)))
on_chest("Planet Ring", ring, 0.0035, "Glow Teal")
for i, (x, z) in enumerate(((0.07, 0.79), (-0.075, 0.70), (0.06, 0.69))):          # a few little stars
    star_prism(f"Print Star.{i}", TORSO.front(x, z, 0.004), TORSO.normal(TORSO.front(x, z)), 0.009, 0.004, 0.002,
               "Glow Teal", ["chest"])

# Pendant on a thin cord
cord = [TORSO.project(Vector((0.075 * math.cos(a), -0.3 * math.sin(a) + 0.05, 0.83 - 0.035 * math.sin(a))), 0.006)
        for a in (math.pi * i / 20 for i in range(21))]
tube("Cord", cord, [(0.003, 0.003)] * len(cord), "Belt", ["chest"], sides=6, caps=False)
g = TORSO.project((0, -0.3, 0.785), 0.012)
ellipsoid("Pendant", g, (0.013, 0.007, 0.016), "Glow Teal", ["chest"], rot=basis_facing(TORSO.normal(g)))

# Belt, buckle, and a keychain with a little green alien and a gold star
ring_on("Belt", TORSO, WAIST + 0.005, 0.006, 0.014, "Belt", ["hips", "spine"])
b = TORSO.front(0, WAIST + 0.005, 0.02)
ellipsoid("Buckle", b, (0.03, 0.006, 0.02), "Metal", ["hips"], rot=basis_facing(TORSO.normal(b)), power=0.4)
kc = TORSO.front(0.11, WAIST, 0.02)
tube("Key Chain", [kc, kc + Vector((0.005, -0.004, -0.035)), kc + Vector((0.008, -0.006, -0.06))],
     [(0.0025, 0.0025)] * 3, "Metal", ["hips"], sides=6)
ah = kc + Vector((0.008, -0.01, -0.085))
ellipsoid("Alien Charm", ah, (0.016, 0.009, 0.022), "Alien Charm", ["hips"])
for sx in (1, -1):
    ellipsoid(f"Alien Charm Eye.{sx}", ah + Vector((0.007 * sx, -0.007, 0.003)), (0.006, 0.003, 0.0035), "Belt",
              ["hips"], rot=Euler((0, math.radians(25 * sx), 0)).to_matrix())
star_prism("Charm Star", kc + Vector((-0.025, -0.012, -0.075)), Vector((0, -1, 0)), 0.018, 0.008, 0.006, "Star",
           ["hips"])

# Arms (furry, A-pose) with mitten hands, and a glowing gadget on her left wrist
for sx, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.205 * sx, 0, 0.80)), Vector((0.29 * sx, -0.03, 0.67)), Vector((0.36 * sx, -0.05, 0.56))
    capsule(f"Arm.{side}", [sh, el, wr], 0.055, 0.048, "Fur", [f"upper_arm.{side}", f"forearm.{side}"])
    d = (wr - el).normalized()
    ellipsoid(f"Hand.{side}", wr + d * 0.04, (0.052, 0.047, 0.06), "Fur", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", wr + d * 0.028 + Vector((0, -0.04, 0.005)), (0.02, 0.024, 0.028), "Fur",
              [f"hand.{side}"])
    for j in range(3):                                         # fluffy shoulder tufts
        s = sh + Vector((0.03 * sx, 0.0, 0.02 - 0.03 * j))
        spike(f"Shoulder Tuft.{side}{j}", s, Vector((sx, 0.2, -0.6)), 0.06, 0.03, "Fur Light",
              [f"upper_arm.{side}"])
w = Vector((0.345 * 1, -0.045, 0.585))
d = (w - Vector((0.29, -0.03, 0.67))).normalized()
torus("Gadget Band", w, 0.05, 0.016, "Belt", ["forearm.L"], rot=d.to_track_quat('Z', 'Y').to_matrix())
ellipsoid("Gadget Face", w + Vector((0.0, -0.058, 0.004)), (0.024, 0.008, 0.024), "Glow Teal", ["forearm.L"])

# Legs: cargo shorts with lavender cuffs and side pockets, furry shins, slouch socks, chunky glowing sneakers
for sx, side in ((1, "L"), (-1, "R")):
    x = 0.105 * sx
    capsule(f"Shorts.{side}", [(0.095 * sx, 0, 0.52), (x, 0, 0.39)], 0.108, 0.108, "Shorts",
            [("hips", 1.6), f"thigh.{side}"])
    torus(f"Cuff.{side}", (x, 0, 0.38), 0.108, 0.014, "Shorts Trim", [f"thigh.{side}"])
    pc = Vector((x + 0.10 * sx, -0.01, 0.44))
    ellipsoid(f"Cargo Pocket.{side}", pc, (0.02, 0.06, 0.05), "Shorts", [f"thigh.{side}"], power=0.45)
    ellipsoid(f"Pocket Flap.{side}", pc + Vector((0.006 * sx, 0, 0.04)), (0.018, 0.063, 0.016), "Pocket",
              [f"thigh.{side}"], power=0.45)
    strap = [Vector((x + 0.06 * sx, -0.07, 0.56)), Vector((x + 0.10 * sx, -0.06, 0.50)),
             Vector((x + 0.115 * sx, -0.03, 0.46))]
    tube(f"Shorts Strap.{side}", strap, [(0.012, 0.004)] * 3, "Shorts Trim", [("hips", 1.0), f"thigh.{side}"],
         sides=6)
    capsule(f"Fur Leg.{side}", [(x, 0, 0.39), (x, -0.005, 0.2)], 0.068, 0.064, "Fur",
            [f"thigh.{side}", f"shin.{side}"])
    for j in range(8):                                          # tufts peeking under the cuff
        a = 2 * math.pi * j / 8
        dd = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((x, 0, 0.365)) + dd * 0.06
        lock(f"Leg Tuft.{side}{j}", [s, s + dd * 0.02 + Vector((0, 0, -0.03)), s + dd * 0.03 + Vector((0, 0, -0.06))],
             0.028, "Fur Light", [f"shin.{side}", f"thigh.{side}"], flat=0.55, normal_fn=lambda p, dd=dd: dd, sides=8)
    # Slouch socks: a soft tube with a couple of rolls
    capsule(f"Sock.{side}", [(x, -0.005, 0.25), (x, -0.01, 0.09)], 0.078, 0.07, "Sock",
            [f"shin.{side}", (f"foot.{side}", 1.5)])
    for j, z in enumerate((0.235, 0.19, 0.145)):
        torus(f"Sock Roll.{side}{j}", (x, -0.007, z), 0.077 - 0.003 * j, 0.012, "Sock", [f"shin.{side}"])
    # Sneaker
    sb = Vector((x, -0.035, 0.065))
    ellipsoid(f"Shoe.{side}", sb, (0.082, 0.135, 0.06), "Shoe", [f"foot.{side}"], power=0.65, u=32, v=16)
    ellipsoid(f"Sole.{side}", sb + Vector((0, -0.005, -0.04)), (0.09, 0.145, 0.028), "Sole", [f"foot.{side}"],
              power=0.5, u=32, v=12)
    ellipsoid(f"Toe Cap.{side}", sb + Vector((0, -0.09, 0.0)), (0.07, 0.05, 0.045), "Shoe Panel", [f"foot.{side}"],
              power=0.7)
    torus(f"Shoe Collar.{side}", (x, -0.01, 0.11), 0.075, 0.016, "Shoe Panel", [f"foot.{side}", f"shin.{side}"])
    for s2 in (1, -1):                                           # glowing ring on each side of the shoe
        rc = sb + Vector((0.08 * s2, 0.03, 0.005))
        torus(f"Shoe Glow.{side}{s2}", rc, 0.026, 0.006, "Glow Violet", [f"foot.{side}"],
              rot=Euler((0, math.radians(90), 0)).to_matrix())
        ellipsoid(f"Shoe Disc.{side}{s2}", rc, (0.006, 0.02, 0.02), "Shoe Panel", [f"foot.{side}"])

# Backpack: black, slung on her back and poking out at her right side, with glowing rings
BP = ["chest"]
ellipsoid("Backpack", (-0.27, 0.12, 0.62), (0.08, 0.13, 0.16), "Backpack", BP, power=0.5, u=32, v=16)
torus("Backpack Glow", (-0.352, 0.12, 0.62), 0.05, 0.008, "Glow Violet", BP,
      rot=Euler((0, math.radians(90), 0)).to_matrix())
ellipsoid("Backpack Glow Center", (-0.352, 0.12, 0.62), (0.006, 0.032, 0.032), "Glow Teal", BP)
for sx, side in ((1, "L"), (-1, "R")):
    path = [(0.09 * sx, 0.18, 0.80), (0.12 * sx, 0.06, 0.86), (0.13 * sx, -0.08, 0.84), (0.14 * sx, -0.15, 0.74),
            (0.15 * sx, -0.16, 0.66)]
    pts = []
    for a, bb in zip(path, path[1:]):
        for j in range(6):
            pts.append(TORSO.project(Vector(a).lerp(Vector(bb), j / 6), offset=0.012))
    pts.append(TORSO.project(path[-1], offset=0.012))
    tube(f"Backpack Strap.{side}", pts, [(0.022, 0.006)] * len(pts), "Backpack", BP, sides=8, normal_fn=TORSO.normal)

# =============================================================================
# Rig, skin, animations
# =============================================================================
BONES = biped_bones(shoulder=(0.205, 0, 0.80), elbow=(0.29, -0.03, 0.67), wrist=(0.36, -0.05, 0.56),
                    hand_tip=(0.40, -0.065, 0.49), hip_x=0.105)
rig = build_rig("CattleGirlRig", BONES)
skin_and_join(rig, BONES, "CattleGirl", "Torso")

make_action(rig, "idle", 60, lambda t: biped_idle(BONES, t))
make_action(rig, "walk", 32, lambda t: biped_walk(BONES, t))
make_action(rig, "run", 20, lambda t: biped_run(BONES, t))
rest_pose(rig)
finish(OUT)

# Builds the plant girl from scratch: model, materials, rig, weights and animations.
# Reference: Hayden's picture of her (Nov 7, 2026; a copy is in source_art/reference/Plant girl.jpg): a round pale
# green face with her eyes closed in a happy smile, purple blush with little dots, a leaf mark on her forehead, a
# crown of leaves for hair, two pale bark antlers wrapped in vines with leaves and dewdrops hanging off them, a dress
# of layered leaves (green, teal, purple tips, an orange one in the middle), a branchy arm with leaves on her right,
# a curling stem ending in a Venus flytrap on her left, and a tangle of golden roots instead of legs.
# She gets about by burrowing into the ground and sprouting up somewhere else (scripts/burrower.gd), so she has no
# walk: her "under" loop is her curled up below the ground, "burrow" dives in and "sprout" pops back up.
#
#   blender -b --python tools\build_plant_girl.py
#
# Writes source_art/characters/plant_girl.blend (overwrites it). Units are meters; roots at the origin; she faces
# -Y. Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "plant_girl.blend"

K.begin()
R = rng(7)

# =============================================================================
# Materials (linear colours picked from the picture)
# =============================================================================
mat("Skin", (0.42, 0.62, 0.12), rough=0.45)           # pale spring green, a little glossy like a new leaf
mat("Skin Dark", (0.10, 0.30, 0.04), rough=0.5)
mat("Lash", (0.01, 0.07, 0.02))
mat("Mouth", (0.03, 0.09, 0.02))
mat("Blush", (0.45, 0.12, 0.40), rough=0.6)           # purple
mat("Blush Dot", (0.30, 0.05, 0.28))
mat("Leaf Green", (0.05, 0.28, 0.04), rough=0.5)
mat("Leaf Light", (0.18, 0.45, 0.05), rough=0.5)
mat("Leaf Teal", (0.02, 0.22, 0.16), rough=0.5)
mat("Leaf Purple", (0.28, 0.06, 0.38), rough=0.5)
mat("Leaf Pink", (0.55, 0.10, 0.25), rough=0.5)
mat("Leaf Gold", (0.70, 0.40, 0.04), rough=0.5)
mat("Leaf Orange", (0.80, 0.22, 0.02), rough=0.5)
mat("Vein", (0.75, 0.62, 0.15), rough=0.5)
mat("Bark", (0.62, 0.52, 0.36), rough=0.75)           # pale birch-like antlers
mat("Bark Line", (0.25, 0.18, 0.10), rough=0.8)
mat("Vine", (0.12, 0.38, 0.03), rough=0.5)
mat("Root", (0.45, 0.28, 0.07), rough=0.65)           # golden roots
mat("Root Dark", (0.22, 0.12, 0.03), rough=0.7)
mat("Dew", (0.70, 0.85, 1.0), rough=0.02, emit=0.35)  # dewdrops catch the light
mat("Trap", (0.35, 0.50, 0.06), rough=0.45)           # the flytrap: yellow-green outside...
mat("Trap Inside", (0.50, 0.03, 0.08), rough=0.5)     # ...red inside
mat("Trap Teeth", (0.75, 0.70, 0.30), rough=0.5)

TIP_MATS = ["Leaf Purple", "Leaf Teal", "Leaf Pink", "Leaf Gold"]
HB = ["head"]


def leaf(name, base, direction, length, width, normal, material, bones, curl=0.0, tip=None, vein=True, rows=8):
    """A pointed leaf: a curved sheet from base along direction, widest a third of the way, bending toward normal
    by curl. Its outer part takes the tip colour (the picture's leaves fade green -> purple/teal at the ends)."""
    base, d, n = Vector(base), Vector(direction).normalized(), Vector(normal).normalized()
    side = d.cross(n).normalized()
    n = side.cross(d).normalized()
    bm = bmesh.new()
    cols = 5
    grid = []
    for i in range(rows + 1):
        t = i / rows
        w = width * (math.sin(math.pi * min(t * 1.15, 1.0)) ** 0.7) * (1 - 0.25 * t)
        spine = base + d * length * t + n * curl * length * t * t
        grid.append([bm.verts.new(spine + side * w * (j / cols * 2 - 1) + n * 0.15 * w * (1 - (j / cols * 2 - 1) ** 2))
                     for j in range(cols + 1)])
    for r0, r1 in zip(grid, grid[1:]):
        for j in range(cols):
            bm.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1]))
    ob = new_obj(name, bm, material, bones)
    if tip:
        idx = add_material(ob, tip)
        for p in ob.data.polygons:
            if (p.center - base).dot(d) > length * 0.62:
                p.material_index = idx
    if vein:
        pts = [base + d * length * t + n * (curl * length * t * t + 0.004) for t in (k / 6 * 0.85 for k in range(7))]
        tube(name + " Vein", pts, [(0.004 * (1 - k / 7), 0.002) for k in range(7)], "Vein", bones, sides=5)
    return ob


def any_tip():
    return R.choice(TIP_MATS)


# =============================================================================
# Head: a big round pale green face, eyes closed in a happy smile
# =============================================================================
HEAD = Ellipsoid((0, 0, 1.17), (0.25, 0.235, 0.235))
ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HB, u=48, v=24)
# A soft darker shading at the back of her head, like the underside of a leaf
for sx, side in ((1, "L"), (-1, "R")):
    # Closed eyes: happy upside-down arcs with three lashes each, flicking out at the outer corner
    ex = 0.1 * sx
    arc = [(ex + 0.06 * math.cos(a) * sx, 1.165 + 0.026 * math.sin(a)) for a in (math.pi * k / 10 for k in range(11))]
    arc_on(HEAD, f"Eye.{side}", arc, 0.012, "Lash", HB, offset=0.003)
    for k in range(3):
        bx, bz = ex + (0.045 + 0.012 * k) * sx, 1.18 - 0.012 * k
        base = HEAD.front(bx, bz, 0.003)
        tip = base + Vector(((0.028 - 0.004 * k) * sx, -0.008, 0.012 - 0.01 * k))
        tube(f"Lash.{side}{k}", [base, base.lerp(tip, 0.5), tip], [(0.006, 0.004), (0.004, 0.003), (0.0012, 0.0012)],
             "Lash", HB, sides=6)
    # Purple blush with a sprinkle of dots
    bc = HEAD.front(0.155 * sx, 1.1, offset=0.001)
    ellipsoid(f"Blush.{side}", bc, (0.05, 0.008, 0.032), "Blush", HB, rot=basis_facing(HEAD.normal(bc)))
    for k in range(5):
        dp = HEAD.front((0.13 + 0.012 * (k % 3)) * sx + R.uniform(-0.012, 0.012), 1.09 + 0.012 * (k // 3) + R.uniform(-0.008, 0.008), 0.006)
        ellipsoid(f"Blush Dot.{side}{k}", dp, (0.005, 0.002, 0.005), "Blush Dot", HB, rot=basis_facing(HEAD.normal(dp)),
                  u=8, v=4)
    # Faint leaf-vein marks on her temples
    vein = [(sx * (0.07 + 0.04 * t), 1.27 + 0.05 * t) for t in (k / 5 for k in range(6))]
    arc_on(HEAD, f"Temple Vein.{side}", vein, 0.004, "Skin Dark", HB, offset=0.002)
arc_on(HEAD, "Smile", [(-0.045 + 0.09 * k / 10, 1.065 - 0.02 * math.sin(math.pi * k / 10)) for k in range(11)],
       0.007, "Mouth", HB, offset=0.003)
# The leaf mark on her forehead: purple at the tip, gold at the base
fm = HEAD.front(0.0, 1.29, offset=0.004)
leaf("Forehead Leaf", fm + Vector((0, 0, -0.035)), (0, -0.25, 1), 0.08, 0.025, HEAD.normal(fm) * -1 + Vector((0, 0, 0)),
     "Leaf Gold", HB, tip="Leaf Purple", vein=False, rows=6)

# Hair: a cap of big leaves lying over the top of her head and falling down the sides and back like a bob, shorter
# over her forehead like a fringe, tips in mixed colours. Each leaf starts high on her head and follows its curve down.
def head_dir(polar, az):
    return Vector((math.sin(polar) * math.sin(az), -math.sin(polar) * math.cos(az), math.cos(polar)))


for row, (polar, count, size, keep_off) in enumerate(((0.25, 9, 1.0, 2.0), (0.8, 14, 1.0, 2.0), (1.3, 14, 0.95, 0.1),
                                                      (1.8, 12, 0.9, -0.45))):
    # Four rows from the crown down; the lower rows leave her face clear (keep_off: skip leaves this far to the front)
    for k in range(count):
        az = 2 * math.pi * (k + 0.5 * row) / count             # 0 = straight ahead
        if math.cos(az) > keep_off:
            continue
        span = 0.62 if math.cos(az) < 0.6 else (0.75 if row == 0 else 0.34)   # a short fringe at the front
        off = 0.04 - 0.008 * row                                # upper rows lie over the lower ones
        base = HEAD.dir_point(head_dir(polar, az), offset=off - 0.01)
        tip = HEAD.dir_point(head_dir(polar + span, az), offset=off + 0.01)
        out = HEAD.normal(base)
        leaf(f"Hair Leaf.{row}.{k}", base, tip - base, (tip - base).length * 1.12, 0.08 * size, out,
             "Leaf Green" if (k + row) % 3 else "Leaf Light", HB, curl=0.05, tip=any_tip())
# A few leaves standing up out of the crown, between her antlers
for k in range(5):
    az = 2 * math.pi * k / 5 + 0.3
    base = HEAD.dir_point(head_dir(0.15, az), offset=0.01)
    leaf(f"Crown Leaf.{k}", base, head_dir(0.6, az), 0.13, 0.05, head_dir(0.6, az + math.pi / 2), "Leaf Light", HB,
         curl=0.2, tip=any_tip())


# =============================================================================
# Antlers: pale bark branches curving up and out, wrapped in a vine, with leaves and dewdrops hanging off them
# =============================================================================
DEWS = []
for sx, side in ((1, "L"), (-1, "R")):
    ctrl = [(0.09 * sx, 0.02, 1.36), (0.13 * sx, 0.03, 1.55), (0.22 * sx, 0.02, 1.72), (0.36 * sx, 0.0, 1.8),
            (0.46 * sx, -0.02, 1.76)]
    path = smooth_path(ctrl, per_segment=8)
    n = len(path)
    tube(f"Antler.{side}", path, [(0.042 - 0.024 * k / n,) * 2 for k in range(n)], "Bark", HB, sides=12)
    # Bark rings
    for k in range(4, n - 4, 5):
        d = (path[k + 1] - path[k - 1]).normalized()
        torus(f"Bark Ring.{side}{k}", path[k], 0.042 - 0.024 * k / n, 0.004, "Bark Line", HB,
              rot=d.to_track_quat('Z', 'Y').to_matrix(), u=16, v=5)
    # A side branch near the top, and the vine spiralling up the antler
    br = smooth_path([path[n // 2], path[n // 2] + Vector((0.06 * sx, -0.02, 0.1)), path[n // 2] + Vector((0.04 * sx, -0.03, 0.17))], 6)
    tube(f"Antler Branch.{side}", br, [(0.018 - 0.01 * k / len(br),) * 2 for k in range(len(br))], "Bark", HB, sides=8)
    helix = []
    for k in range(n * 3):
        t = k / (n * 3 - 1)
        i = min(int(t * (n - 1)), n - 2)
        p0 = path[i].lerp(path[i + 1], t * (n - 1) - i)
        d = (path[i + 1] - path[i]).normalized()
        s1 = d.cross(Vector((0, 1, 0))).normalized()
        s2 = d.cross(s1).normalized()
        a = t * 2 * math.pi * 4
        r = 0.048 - 0.024 * t
        helix.append(p0 + s1 * math.cos(a) * r + s2 * math.sin(a) * r)
    tube(f"Antler Vine.{side}", helix, [(0.008, 0.008)] * len(helix), "Vine", HB, sides=6)
    # Leaves along it, drooping, and dewdrops hanging under some of them
    for j, k in enumerate((n // 4, n // 2 - 2, n // 2 + 4, 3 * n // 4, n - 3, n - 1)):
        p = path[k]
        down = Vector((0.35 * sx * (1 if j % 2 else -0.4), -0.25, -1)).normalized()
        lf = leaf(f"Antler Leaf.{side}{j}", p, down, 0.13 + 0.03 * (j % 2), 0.05, Vector((0, -1, 0.2)), "Leaf Green", HB,
                  curl=0.3, tip=any_tip())
        if j % 2 == 0 or j == 5:
            drop = p + down * (0.15 + 0.03 * (j % 2)) + Vector((0, 0, -0.035))
            DEWS.append((f"Dew Antler.{side}{j}", drop, HB))
            tube(f"Dew Thread.{side}{j}", [p + down * 0.12, drop + Vector((0, 0, 0.02))], [(0.0025, 0.0025)] * 2,
                 "Vine", HB, sides=4)

# =============================================================================
# Body: a thin stem neck, a dress of layered leaves, and a tangle of roots instead of legs
# =============================================================================
TORSO = Ellipsoid((0, 0, 0.66), (0.14, 0.12, 0.22))
TB = ["hips", "spine", "chest"]
ellipsoid("Torso", TORSO.c, TORSO.r, "Leaf Green", TB, u=32, v=16)
capsule("Neck", [(0, 0, 0.84), (0, 0, 0.98)], 0.04, 0.035, "Skin", ["chest", "head"])
# The collar: a ruff of leaves fanning out round her neck
for k in range(12):
    a = 2 * math.pi * k / 12
    out = Vector((math.sin(a), -math.cos(a), 0))
    leaf(f"Collar Leaf.{k}", Vector((0, 0, 0.88)) + out * 0.04, (out + Vector((0, 0, -0.25))).normalized(), 0.15, 0.05,
         Vector((0, 0, 1)), "Leaf Green", ["chest"], curl=-0.3, tip=any_tip())
# The dress: four rings of leaves pointing down, each ring wider and longer, the middle one at the front orange
for ring, (z, rr, length, count) in enumerate(((0.82, 0.12, 0.22, 8), (0.71, 0.15, 0.25, 9), (0.6, 0.17, 0.27, 10),
                                                (0.49, 0.18, 0.29, 11))):
    bones = ["chest", "spine"] if ring < 2 else ["spine", "hips"]
    for k in range(count):
        a = 2 * math.pi * (k + 0.5 * (ring % 2)) / count
        out = Vector((math.sin(a), -math.cos(a), 0))
        base = Vector((0, 0, z)) + Vector((out.x * rr, out.y * rr * 0.85, 0))
        d = (out * 0.45 + Vector((0, 0, -1))).normalized()
        leaf(f"Dress Leaf.{ring}.{k}", base, d, length, 0.095 + 0.012 * ring, out, R.choice(["Leaf Green", "Leaf Teal",
             "Leaf Green", "Leaf Light"]), bones, curl=0.15, tip=any_tip())
leaf("Heart Leaf", TORSO.front(0.0, 0.79, 0.03), (0, -0.25, -1), 0.3, 0.09, (0, -1, 0.1), "Leaf Gold", ["chest", "spine"],
     curl=0.1, tip="Leaf Orange")

# Roots: a dozen golden roots twisting down from under her dress and spreading over the ground, curling at the tips
for k in range(12):
    a = 2 * math.pi * (k + R.random() * 0.4) / 12
    out = Vector((math.sin(a), -math.cos(a), 0))
    side = "L" if out.x > 0 else "R"
    reach = 0.22 + 0.12 * R.random()
    ctrl = [Vector((0, 0, 0.5)) + out * 0.05, Vector((0, 0, 0.32)) + out * 0.08 + Vector((R.uniform(-0.03, 0.03),) * 2 + (0,)),
            Vector((0, 0, 0.14)) + out * (reach * 0.55), Vector((0, 0, 0.03)) + out * reach,
            Vector((0, 0, 0.0)) + out * (reach + 0.08) + Vector((0, 0, 0.03))]
    path = smooth_path(ctrl, 6)
    tube(f"Root.{k}", path, [(0.045 * (1 - 0.85 * i / len(path)) + 0.004,) * 2 for i in range(len(path))],
         "Root" if k % 3 else "Root Dark", [("hips", 1.2), f"thigh.{side}", f"shin.{side}"], sides=10)
    # A little side rootlet
    mid = path[len(path) // 2]
    tube(f"Rootlet.{k}", smooth_path([mid, mid + out * 0.06 + Vector((0, 0, -0.04)), mid + out * 0.1 + Vector((0.02, 0, -0.1))], 4),
         [(0.012 * (1 - i / 9) + 0.002,) * 2 for i in range(9)], "Root", [f"shin.{side}"], sides=6)

# =============================================================================
# Arms: on her right a branch with a fan of leaves for a hand; on her left a curling stem with a Venus flytrap
# =============================================================================
SH, EL, WR, TIP = (0.13, 0, 0.8), (0.24, -0.03, 0.7), (0.34, -0.05, 0.64), (0.42, -0.06, 0.62)
# Her right arm (-X): a vine-wrapped branch, leaves fanning from the end
r_sh, r_el, r_wr = Vector((-SH[0], SH[1], SH[2])), Vector((-EL[0], EL[1], EL[2])), Vector((-WR[0], WR[1], WR[2]))
capsule("Arm.R", [r_sh, r_el, r_wr], 0.028, 0.022, "Bark", ["upper_arm.R", "forearm.R"], sides=12)
for k in range(3):
    p = r_sh.lerp(r_wr, 0.25 + 0.3 * k)
    torus(f"Arm Vine.R{k}", p, 0.03, 0.007, "Vine", ["upper_arm.R", "forearm.R"],
          rot=(r_wr - r_sh).normalized().to_track_quat('Z', 'Y').to_matrix(), u=14, v=5)
hd = (r_wr - r_el).normalized()
for k, spread in enumerate((-0.5, -0.15, 0.2, 0.55)):
    d = (hd + Vector((-0.3, -spread, 0.3 * spread))).normalized()
    leaf(f"Hand Leaf.R{k}", r_wr, d, 0.14 + 0.02 * (k % 2), 0.045, Vector((0, 0, 1)), "Leaf Green", ["hand.R"], curl=0.2,
         tip=["Leaf Purple", "Leaf Pink", "Leaf Purple", "Leaf Teal"][k])
leaf("Elbow Leaf.R", r_el, (-0.3, -0.5, 0.8), 0.1, 0.04, (0, -1, 0), "Leaf Light", ["forearm.R"], curl=-0.3, tip="Leaf Purple")
DEWS.append(("Dew Hand.R", r_wr + hd * 0.16 + Vector((0, 0, -0.08)), ["hand.R"]))

# Her left arm (+X): a green stem that curls out and up into the flytrap, with two leaves on the way
l_sh, l_el, l_wr = Vector(SH), Vector(EL), Vector(WR)
capsule("Arm.L", [l_sh, l_el, l_wr], 0.026, 0.022, "Vine", ["upper_arm.L", "forearm.L"], sides=12)
curl_pts = smooth_path([l_wr, l_wr + Vector((0.05, -0.01, 0.0)), l_wr + Vector((0.08, -0.02, 0.06)),
                        l_wr + Vector((0.05, -0.02, 0.1)), l_wr + Vector((0.08, -0.02, 0.15))], 5)
tube("Trap Stem", curl_pts, [(0.02, 0.02)] * len(curl_pts), "Vine", ["hand.L"], sides=10)
leaf("Stem Leaf.L0", l_el, (0.5, -0.4, -0.7), 0.13, 0.045, (0, -1, 0), "Leaf Green", ["forearm.L"], curl=0.3, tip="Leaf Pink")
leaf("Stem Leaf.L1", l_wr, (0.2, -0.3, -0.9), 0.15, 0.05, (0, -1, 0), "Leaf Green", ["hand.L"], curl=0.3, tip="Leaf Purple")
DEWS.append(("Dew Stem.L", l_wr + Vector((0.07, -0.08, -0.17)), ["hand.L"]))

# The flytrap: two half-shells hinged at the back, open, red inside, a fringe of teeth round each rim.
# The lower jaw sits on her hand bone, the upper jaw on its own "trap" bone so it can snap shut.
HINGE = curl_pts[-1] + Vector((0.02, 0, 0.03))
TRAP_DIR = Vector((0.3, -1, 0.15)).normalized()                 # the way her trap faces: out in front of her


def jaw(name, upper, bone):
    # Each jaw is a shallow bowl: a half-ellipsoid opening along TRAP_DIR, tilted up (upper) or down (lower)
    open_a = math.radians(32 if upper else -18)
    side = TRAP_DIR.cross(Vector((0, 0, 1))).normalized()
    fwd = Matrix.Rotation(open_a, 3, side) @ TRAP_DIR
    up = fwd.cross(side).normalized() * (1 if upper else -1)
    c = HINGE + fwd * 0.08
    M = Matrix((side, fwd, up)).transposed()
    ellipsoid(name, c, (0.075, 0.085, 0.035), "Trap", [bone], rot=M, keep_below=0.0 if not upper else None,
              keep_above=0.0 if upper else None)
    # The red inside: a thin lining over the jaw's open face (the shell's flat cut side faces the other jaw)
    ellipsoid(name + " Inside", c - up * 0.004, (0.07, 0.08, 0.005), "Trap Inside", [bone], rot=M)
    for k in range(15):                                         # the teeth round the open edge
        a = math.pi * (k + 0.5) / 15 - math.pi / 2
        rim = c + side * math.sin(a) * 0.075 + fwd * math.cos(a) * 0.085 * (1 if a > -9 else 1)
        if (rim - HINGE).dot(fwd) < 0.02:
            continue
        out = (rim - c).normalized()
        tube(f"{name} Tooth.{k}", [rim, rim + out * 0.02 + up * 0.035], [(0.005, 0.005), (0.001, 0.001)], "Trap Teeth",
             [bone], sides=5)
    return c


jaw("Trap Lower", False, "hand.L")
jaw("Trap Upper", True, "trap")
for k in range(2):
    DEWS.append((f"Dew Trap.{k}", HINGE + TRAP_DIR * (0.1 + 0.05 * k) + Vector((0.02 * k, 0, -0.08 - 0.02 * k)), ["hand.L"]))

# Dewdrops: little teardrops of water, round at the bottom and pointed on top
for name, p, bones in DEWS:
    ellipsoid(name, p, (0.016, 0.016, 0.02), "Dew", bones, u=12, v=8)
    capsule(name + " Point", [p, p + Vector((0, 0, 0.028))], 0.012, 0.002, "Dew", bones, steps=4, sides=8)

# =============================================================================
# Rig, skin, animations
# =============================================================================
BONES = biped_bones(hips=0.50, chest=0.76, neck=0.92, head_top=1.45, shoulder=SH, elbow=EL, wrist=WR, hand_tip=TIP,
                    hip_x=0.08, knee=0.28, ankle=0.08, toe=(-0.1, 0.02))
BONES["trap"] = (tuple(HINGE), tuple(HINGE + TRAP_DIR * 0.15), "hand.L")
rig = build_rig("PlantGirlRig", BONES)
skin_and_join(rig, BONES, "PlantGirl", "Torso")


def trap_open(p, amount):
    # amount 1 = wide open (as built), 0 = snapped shut: the upper jaw swings down about the hinge
    side = TRAP_DIR.cross(Vector((0, 0, 1))).normalized()
    p.rel("trap", (side, -math.radians(50) * (1 - amount)))


def sway(p, t, amount=1.0):
    # Swaying like a plant in a breeze: everything above the roots leans and the head lags behind
    s = math.sin(2 * math.pi * t)
    c = math.cos(2 * math.pi * t)
    p.rel("hips", (Y, 0.05 * s * amount), (X, 0.02 * c * amount))
    p.rel("spine", (Y, 0.04 * s * amount))
    p.rel("chest", (Y, 0.03 * s * amount))
    p.rel("head", (Y, -0.06 * math.sin(2 * math.pi * t - 0.8) * amount), (X, -0.03))


def arms_easy(p, t):
    s = math.sin(2 * math.pi * t)
    p.rel("upper_arm.R", (Y, -0.25 - 0.05 * s))
    p.rel("forearm.R", (X, -0.25))
    p.rel("upper_arm.L", (Y, 0.15 + 0.05 * s), (X, -0.2))
    p.rel("forearm.L", (X, -0.35))


def idle(t):
    p = Pose(BONES)
    sway(p, t)
    arms_easy(p, t)
    trap_open(p, 0.75 + 0.25 * math.sin(2 * math.pi * t * 2))   # the flytrap breathes in and out
    return p


def under(t):
    # Curled up tight below the ground while she travels: arms wrapped in, head tucked, a slow wriggle
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    p.rel("spine", (X, 0.3), (Z, 0.15 * s))
    p.rel("chest", (X, 0.2))
    p.rel("head", (X, 0.35))
    for sx, side in ((1, "L"), (-1, "R")):
        p.rel(f"upper_arm.{side}", (Y, 0.9 * sx), (X, -0.7))
        p.rel(f"forearm.{side}", (X, -1.4))
        p.rel(f"thigh.{side}", (X, -0.3 * s * sx))
    trap_open(p, 0.0)
    p.offset = Vector((0, 0, -0.05))
    return p


def burrow(t):
    # Diving in: a little hop up, arms together over her head like a diver, then twisting down
    k = ss(0.0, 0.35, t)
    d = ss(0.35, 1.0, t)
    p = Pose(BONES)
    p.rel("spine", (X, -0.1 * k + 0.3 * d))
    p.rel("head", (X, 0.2 * d))
    for sx, side in ((1, "L"), (-1, "R")):
        p.rel(f"upper_arm.{side}", (Y, (0.3 - 2.6 * k) * sx))
        p.rel(f"forearm.{side}", (X, -0.1))
    p.rel("root", (Z, 2 * math.pi * d))
    trap_open(p, 1.0 - k)
    p.offset = Vector((0, 0, 0.08 * math.sin(math.pi * min(t / 0.5, 1.0))))
    return p


def sprout(t):
    # Popping up: arms flung wide, leaves shaking out, a happy little bounce
    k = ss(0.0, 0.4, t)
    b = math.sin(math.pi * ss(0.3, 1.0, t))
    p = Pose(BONES)
    p.rel("spine", (X, -0.12 * k))
    p.rel("chest", (X, -0.08 * k))
    p.rel("head", (X, -0.15 * k + 0.1 * b), (Y, 0.1 * math.sin(6 * math.pi * t) * (1 - t)))
    for sx, side in ((1, "L"), (-1, "R")):
        p.rel(f"upper_arm.{side}", (Y, (0.35 - 1.5 * k + 0.6 * b) * sx))
        p.rel(f"forearm.{side}", (X, -0.2))
    trap_open(p, k)
    p.offset = Vector((0, 0, 0.06 * b))
    return p


def snap(t):
    # Her flytrap snaps at something (a fly, a sparkle, your hand): open wide, SNAP, then a satisfied chew
    p = Pose(BONES)
    sway(p, t, 0.4)
    reach = ss(0.0, 0.3, t) * (1 - ss(0.5, 0.9, t))
    p.rel("upper_arm.R", (Y, -0.3))
    p.rel("upper_arm.L", (Y, 0.15 - 0.6 * reach), (X, -0.6 * reach))
    p.rel("forearm.L", (X, -0.3))
    p.rel("head", (Y, 0.15 * reach), (X, -0.05))
    if t < 0.3:
        o = 1.0 + 0.2 * ss(0, 0.3, t)
    elif t < 0.36:
        o = 0.0
    else:
        o = 0.1 * abs(math.sin(6 * math.pi * t)) * (1 - t)
    trap_open(p, o)
    return p


def wave(t):
    # Waving hello with her leafy hand
    s = math.sin(4 * math.pi * t)
    p = Pose(BONES)
    sway(p, t, 0.5)
    p.rel("upper_arm.R", (Y, 1.5))
    p.rel("forearm.R", (Y, 0.3 * s), (X, -0.4))
    p.rel("upper_arm.L", (Y, 0.15))
    trap_open(p, 0.8)
    return p


def shuffle(t):
    # A fallback "walk" for anything that asks for one: a little root-shuffle and sway
    p = Pose(BONES)
    sway(p, t * 2, 1.3)
    arms_easy(p, t)
    s = math.sin(2 * math.pi * t)
    p.rel("thigh.L", (X, -0.12 * s))
    p.rel("thigh.R", (X, 0.12 * s))
    p.offset = Vector((0, 0, 0.012 * abs(s)))
    trap_open(p, 0.8)
    return p


def jump(t):
    p = sprout(min(t * 0.6, 1.0))
    return p


def fall(t):
    p = Pose(BONES)
    s = math.sin(2 * math.pi * t)
    p.rel("upper_arm.L", (Y, -1.0 + 0.15 * s))
    p.rel("upper_arm.R", (Y, 1.0 + 0.15 * s))
    p.rel("head", (X, 0.1))
    trap_open(p, 1.0)
    return p


make_action(rig, "idle", 72, idle)
make_action(rig, "under", 40, under)
make_action(rig, "burrow", 20, burrow)
make_action(rig, "sprout", 24, sprout)
make_action(rig, "snap", 48, snap)
make_action(rig, "wave", 40, wave)
make_action(rig, "walk", 36, shuffle)
make_action(rig, "run", 24, shuffle)
make_action(rig, "jump", 12, jump)
make_action(rig, "fall", 24, fall)
rest_pose(rig)
finish(OUT, frame_end=72)

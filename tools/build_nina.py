# Builds Nina the hippo from scratch: model, materials, rig, weights and animations.
# Reference: source_art/reference/Nina - main reference.jpg
#
#   blender -b --python tools\build_nina.py
#
# Writes source_art/characters/nina.blend (overwrites it). Every shape below is a plain
# number you can tweak and rebuild. Units are meters; feet at the origin; she faces -Y.

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "nina.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)
D = bpy.data
scene = bpy.context.scene
scene.render.fps = 30


# =============================================================================
# Materials (linear colors picked from the reference)
# =============================================================================
MATS = {}


def mat(name, rgb, rough=0.55, metal=0.0, emit=0.0):
    m = D.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:                                                    # self-lit, so it stays bright in shade
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*rgb, 1.0)
    MATS[name] = m


mat("Skin", (0.30, 0.21, 0.19))
mat("Blush", (0.82, 0.30, 0.38))
mat("Ear Inner", (0.62, 0.30, 0.30))
mat("Nostril", (0.07, 0.045, 0.04))
mat("Mouth", (0.16, 0.02, 0.03))
mat("Tongue", (0.72, 0.20, 0.24))
mat("Teeth", (0.88, 0.87, 0.82), rough=0.3)
mat("Eye White", (0.90, 0.90, 0.90), rough=0.08)
mat("Iris", (0.16, 0.05, 0.015), rough=0.08)
mat("Iris Light", (0.50, 0.21, 0.05), rough=0.08)
mat("Eye Shine", (1.0, 1.0, 1.0), rough=0.05, emit=1.5)
mat("Pupil", (0.005, 0.004, 0.004), rough=0.05)
mat("Brow", (0.05, 0.025, 0.015))
mat("Hair", (0.72, 0.035, 0.01), rough=0.35)
mat("Bow", (0.62, 0.012, 0.015), rough=0.35)
mat("Shirt", (0.86, 0.86, 0.84))
mat("Overalls", (0.83, 0.24, 0.40))
mat("Overalls Trim", (0.72, 0.18, 0.32))
mat("Clasp", (0.80, 0.62, 0.20), rough=0.35, metal=0.8)
mat("Shoes", (0.80, 0.20, 0.32))
mat("Sole", (0.88, 0.88, 0.88))
mat("Backpack", (0.85, 0.55, 0.03), rough=0.5)
mat("Backpack Mesh", (0.12, 0.10, 0.04), rough=0.8)
mat("Zipper", (0.02, 0.02, 0.02))

# =============================================================================
# Geometry helpers. Every part remembers which bones it follows (for skinning).
# =============================================================================
PARTS = []   # (object, bones) where bones = [name | (name, distance_scale)]


def new_obj(name, bm, material, bones, recalc=True):
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = D.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(MATS[material])
    ob = D.objects.new(name, me)
    scene.collection.objects.link(ob)
    PARTS.append((ob, bones))
    return ob


def basis_facing(n, up=Vector((0, 0, 1))):
    """Rotation whose local -Y points along n (so 'radii[1]' is the thickness along n)."""
    return n.to_track_quat('-Y', 'Z').to_matrix()


def ellipsoid(name, center, radii, material, bones, rot=None, power=1.0, u=24, v=12, keep_below=None):
    """UV sphere scaled to radii. power < 1 makes it boxier (superellipsoid).
    keep_below: cut the sphere at this unit-space z and cap it (e.g. 0 = lower half)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    if keep_below is not None:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, keep_below),
                               plane_no=(0, 0, 1), clear_outer=True)
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    R = rot if isinstance(rot, Matrix) else (Euler(rot).to_matrix() if rot else Matrix.Identity(3))
    for vt in bm.verts:
        c = vt.co
        if power != 1.0:
            c = Vector([math.copysign(abs(x) ** power, x) for x in c])
        vt.co = R @ Vector((c.x * radii[0], c.y * radii[1], c.z * radii[2])) + Vector(center)
    return new_obj(name, bm, material, bones)


def tube(name, pts, radii, material, bones, sides=16, normal_fn=None, caps=True):
    """Tube through pts. radii: per-point (side, normal) half-sizes. normal_fn(p) orients flat ribbons."""
    bm = bmesh.new()
    rings = []
    n = len(pts)
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        up = normal_fn(p) if normal_fn else (Vector((0, 0, 1)) if abs(tan.z) < 0.9 else Vector((1, 0, 0)))
        side = tan.cross(up).normalized()
        up = side.cross(tan).normalized()
        a, b = radii[i]
        rings.append([bm.verts.new(p + side * math.cos(k * 2 * math.pi / sides) * a
                                   + up * math.sin(k * 2 * math.pi / sides) * b) for k in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
    if caps:
        bm.faces.new(rings[0])
        bm.faces.new(rings[-1])
    return new_obj(name, bm, material, bones)


def capsule(name, path, r0, r1, material, bones, steps=10, sides=20):
    """Rounded tube along a polyline path (list of points), radius tapering r0 -> r1, hemispherical ends."""
    path = [Vector(p) for p in path]
    seglen = [(b - a).length for a, b in zip(path, path[1:])]
    total = sum(seglen)

    def at(s):   # point at arc length s
        for a, b, L in zip(path, path[1:], seglen):
            if s <= L or b is path[-1]:
                return a + (b - a) * (min(s, L) / L)
            s -= L
    d0 = (path[1] - path[0]).normalized()
    d1 = (path[-1] - path[-2]).normalized()
    pts, rad = [], []
    for k in range(steps):                                   # start cap
        s = -1 + k / steps
        pts.append(path[0] + d0 * (s * r0))
        r = max(r0 * math.sqrt(1 - s * s), 0.0015)
        rad.append((r, r))
    body = max(4, int(total / 0.02))
    for k in range(body + 1):
        t = k / body
        pts.append(at(t * total))
        r = r0 + (r1 - r0) * t
        rad.append((r, r))
    for k in range(1, steps + 1):                            # end cap
        s = k / steps
        pts.append(path[-1] + d1 * (s * r1))
        r = max(r1 * math.sqrt(max(1 - s * s, 0)), 0.0015)
        rad.append((r, r))
    return tube(name, pts, rad, material, bones, sides=sides)


def torus(name, center, major, minor, material, bones, u=32, v=12):
    bm = bmesh.new()
    rings = []
    for i in range(u):
        a = 2 * math.pi * i / u
        rings.append([bm.verts.new(Vector(center) + Vector((math.cos(a) * (major + minor * math.cos(b)),
                                                            math.sin(a) * (major + minor * math.cos(b)),
                                                            minor * math.sin(b))))
                      for b in (2 * math.pi * j / v for j in range(v))])
    for i in range(u):
        for j in range(v):
            r0, r1 = rings[i], rings[(i + 1) % u]
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % v], r0[(j + 1) % v]))
    return new_obj(name, bm, material, bones)


class Ellipsoid:
    """Analytic ellipsoid for placing things on a surface."""

    def __init__(self, c, r):
        self.c, self.r = Vector(c), Vector(r)

    def project(self, p, offset=0.0):
        d = Vector(p) - self.c
        k = math.sqrt(sum((d[i] / self.r[i]) ** 2 for i in range(3)))
        s = self.c + d / k
        return s + self.normal(s) * offset

    def front(self, x, z, offset=0.0):
        """Point on the front (-Y) surface at this x and z."""
        k = 1 - ((x - self.c.x) / self.r.x) ** 2 - ((z - self.c.z) / self.r.z) ** 2
        s = Vector((x, self.c.y - self.r.y * math.sqrt(max(k, 0.0)), z))
        return s + self.normal(s) * offset

    def inside(self, p, margin=1.0):
        return sum(((Vector(p) - self.c)[i] / self.r[i]) ** 2 for i in range(3)) < margin

    def normal(self, s):
        d = Vector(s) - self.c
        return Vector([d[i] / self.r[i] ** 2 for i in range(3)]).normalized()


# =============================================================================
# Body
# =============================================================================
HEAD = Ellipsoid((0, 0, 1.10), (0.29, 0.27, 0.28))
MUZZLE = Ellipsoid((0, -0.24, 1.03), (0.128, 0.13, 0.085))    # snout pad with the nostrils
JAW = Ellipsoid((0, -0.205, 0.93), (0.128, 0.12, 0.085))       # same width, tucked under the snout; the mouth sits on it
TORSO = Ellipsoid((0, 0, 0.64), (0.27, 0.235, 0.26))
HEADB = ["head"]

ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HEADB, u=48, v=24)
ellipsoid("Muzzle", MUZZLE.c, MUZZLE.r, "Skin", HEADB, u=48, v=24)
ellipsoid("Jaw", JAW.c, JAW.r, "Skin", HEADB, u=48, v=24)

# Torso: one smooth shape, painted shirt / overalls bib by face position
torso = ellipsoid("Torso", TORSO.c, TORSO.r, "Shirt", ["hips", "spine", "chest", ("thigh.L", 1.8), ("thigh.R", 1.8)],
                  u=96, v=48)
torso.data.materials.append(MATS["Overalls"])
torso.data.materials.append(MATS["Overalls Trim"])
BIB_HALF_W, BIB_TOP, WAIST = 0.15, 0.80, 0.53
BIB_ANGLE = math.radians(34)          # half-width of the bib as an angle around the body
for p in torso.data.polygons:
    c = p.center
    on_bib = abs(math.atan2(c.x, -c.y)) < BIB_ANGLE and c.z < BIB_TOP
    if c.z < WAIST or on_bib:
        p.material_index = 1
        if on_bib and BIB_TOP - 0.018 < c.z < BIB_TOP:
            p.material_index = 2                                  # hem along the top of the bib

# Arms (A-pose): skin capsule, white sleeve, mitten hand with a thumb
for sx, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.235 * sx, 0, 0.80)), Vector((0.32 * sx, -0.03, 0.67)), Vector((0.39 * sx, -0.05, 0.56))
    capsule(f"Arm.{side}", [sh, el, wr], 0.060, 0.054, "Skin", [f"upper_arm.{side}", f"forearm.{side}"])
    capsule(f"Sleeve.{side}", [sh + Vector((-0.012 * sx, 0, 0.01)), sh.lerp(el, 0.62)], 0.080, 0.074, "Shirt",
            [f"upper_arm.{side}", ("chest", 1.6)])
    d = (wr - el).normalized()
    ellipsoid(f"Hand.{side}", wr + d * 0.045, (0.058, 0.052, 0.066), "Skin", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", wr + d * 0.03 + Vector((0, -0.045, 0.005)), (0.022, 0.026, 0.03), "Skin", [f"hand.{side}"])

# Legs: overall shorts with rolled cuffs, skin shins, sneakers
for sx, side in ((1, "L"), (-1, "R")):
    x = 0.12 * sx
    capsule(f"Shorts.{side}", [(0.11 * sx, 0, 0.53), (x, 0, 0.35)], 0.115, 0.112, "Overalls",
            [("hips", 1.6), f"thigh.{side}"])
    torus(f"Cuff.{side}", (x, 0, 0.335), 0.117, 0.03, "Overalls Trim", [f"thigh.{side}"])
    capsule(f"Leg.{side}", [(x, 0, 0.37), (x, 0, 0.09)], 0.074, 0.07, "Skin", [f"thigh.{side}", f"shin.{side}"])
    ellipsoid(f"Shoe.{side}", (x, -0.045, 0.072), (0.078, 0.125, 0.066), "Shoes", [f"foot.{side}"], power=0.75)
    ellipsoid(f"Sole.{side}", (x, -0.045, 0.022), (0.084, 0.132, 0.024), "Sole", [f"foot.{side}"], power=0.5)
    ellipsoid(f"Toe.{side}", (x, -0.135, 0.045), (0.062, 0.045, 0.038), "Sole", [f"foot.{side}"])
    for k, yy in enumerate((-0.085, -0.055, -0.025)):           # laces
        ellipsoid(f"Lace.{side}{k}", (x, yy, 0.128 - k * 0.004), (0.042, 0.007, 0.006), "Sole", [f"foot.{side}"],
                  power=0.6, u=12, v=6)

# Overall straps from the bib corners over the shoulders down the back, with clasps
STRAP_W, STRAP_T = 0.024, 0.006
for sx, side in ((1, "L"), (-1, "R")):
    pts = []
    for k in range(41):                                         # front (low) -> over the shoulder -> back (low)
        t = k / 40
        a = math.radians(-50 + 280 * t)                         # sweep angle in the strap's y-z plane
        x = (0.115 - 0.03 * t) * sx
        pts.append(TORSO.project(Vector((x, -math.cos(a) * 0.3, TORSO.c.z + math.sin(a) * 0.3)), offset=0.006))
    start = next(i for i, p in enumerate(pts) if p.z >= BIB_TOP - 0.015)    # starts at the bib's top corner
    end = next(i for i in range(len(pts) - 1, 0, -1) if pts[i].z >= WAIST + 0.02)
    pts = pts[start:end + 1]
    tube(f"Strap.{side}", pts, [(STRAP_W, STRAP_T)] * len(pts), "Overalls", ["spine", "chest"], sides=8,
         normal_fn=TORSO.normal)
    s = TORSO.project((0.115 * sx, -0.3, BIB_TOP - 0.01), offset=0.008)
    ellipsoid(f"Clasp.{side}", s, (0.03, 0.008, 0.024), "Clasp", ["chest", "spine"], rot=basis_facing(TORSO.normal(s)),
              power=0.5, u=16, v=8)

pocket_at = TORSO.project((0, -0.3, 0.69), offset=0.004)
ellipsoid("Bib Pocket", pocket_at, (0.068, 0.008, 0.052), "Overalls Trim", ["spine", "chest"],
          rot=basis_facing(TORSO.normal(pocket_at)), power=0.45, u=24, v=12)

# =============================================================================
# Face
# =============================================================================
for sx, side in ((1, "L"), (-1, "R")):
    ec = Vector((0.105 * sx, -0.215, 1.18))
    ellipsoid(f"Eye.{side}", ec, (0.07, 0.05, 0.08), "Eye White", HEADB)
    ellipsoid(f"Iris.{side}", ec + Vector((-0.004 * sx, -0.043, -0.004)), (0.043, 0.012, 0.05), "Iris", HEADB)
    ellipsoid(f"Iris Light.{side}", ec + Vector((-0.004 * sx, -0.051, -0.014)), (0.032, 0.006, 0.03), "Iris Light", HEADB)
    ellipsoid(f"Pupil.{side}", ec + Vector((-0.004 * sx, -0.054, -0.002)), (0.023, 0.006, 0.027), "Pupil", HEADB)
    ellipsoid(f"Sparkle.{side}", ec + Vector((0.013, -0.061, 0.022)), (0.016, 0.005, 0.018), "Eye Shine", HEADB,
              u=16, v=8)
    ellipsoid(f"Sparkle Small.{side}", ec + Vector((-0.016, -0.06, -0.024)), (0.007, 0.004, 0.007), "Eye Shine", HEADB,
              u=12, v=6)
    # Lashes: three little flicks at the upper outer corner
    for k, a in enumerate((70, 45, 22)):
        ar = math.radians(a)
        base = ec + Vector((0.064 * math.cos(ar) * sx, -0.022, 0.074 * math.sin(ar)))
        tip = base + Vector((0.016 * math.cos(ar) * sx + 0.008 * sx, -0.004, 0.012 + 0.006 * math.sin(ar)))
        tube(f"Lash.{side}{k}", [base, base.lerp(tip, 0.5), tip], [(0.009, 0.006), (0.006, 0.004), (0.0015, 0.0015)],
             "Brow", HEADB, sides=6)
    # Brow: a soft arc on the forehead
    brow = [HEAD.front(sx * (0.075 + 0.11 * t), 1.274 + 0.02 * math.sin(math.pi * t) + 0.012 * (1 - t), offset=0.004)
            for t in (i / 8 for i in range(9))]
    tube(f"Brow.{side}", brow, [(0.006 + 0.008 * math.sin(math.pi * i / 8), 0.004) for i in range(9)], "Brow", HEADB,
         sides=8, normal_fn=HEAD.normal)
    # Cheek blush
    eye_e = Ellipsoid(ec, (0.07, 0.05, 0.08))
    for k in range(20):
        bc = HEAD.project(HEAD.c + Vector(((0.5 + 0.03 * k) * sx, -0.6, 0.04)))
        n = HEAD.normal(bc)
        rim = [bc + basis_facing(n) @ Vector((0.046 * math.cos(a), 0, 0.032 * math.sin(a)))
               for a in (i * math.pi / 8 for i in range(16))]
        if not any(MUZZLE.inside(p, 1.06) or JAW.inside(p, 1.06) or eye_e.inside(p, 1.15) for p in rim):
            break
    ellipsoid(f"Blush.{side}", bc - n * 0.008, (0.046, 0.012, 0.032), "Blush", HEADB, rot=basis_facing(n))
    # Ears with pink insides, poking up through the hair
    ear = Vector((0.215 * sx, 0.03, 1.335))
    er = Euler((0, math.radians(-25 * sx), math.radians(-12 * sx))).to_matrix()
    ellipsoid(f"Ear.{side}", ear, (0.065, 0.035, 0.062), "Skin", HEADB, rot=er)
    ellipsoid(f"Ear Inner.{side}", ear + er @ Vector((0, -0.024, 0.004)), (0.04, 0.014, 0.04), "Ear Inner", HEADB, rot=er)
    # Nostrils on the upper front of the snout
    ns = MUZZLE.front(0.047 * sx, 1.072)
    ellipsoid(f"Nostril.{side}", ns - MUZZLE.normal(ns) * 0.007, (0.02, 0.012, 0.015), "Nostril", HEADB,
              rot=basis_facing(MUZZLE.normal(ns)))


def surface_patch(name, ell, grid, offset, material, bones):
    """A thin skin that follows ell's front surface. grid: rows of (x, z) points."""
    bm = bmesh.new()
    rows = [[bm.verts.new(ell.front(x, z, offset)) for x, z in row] for row in grid]
    for r0, r1 in zip(rows, rows[1:]):
        for j in range(len(r0) - 1):
            f = bm.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1]))
            f.normal_update()
            if f.normal.dot(ell.normal(f.calc_center_median())) < 0:
                f.normal_flip()
    return new_obj(name, bm, material, bones, recalc=False)


# Smile painted onto the snout surface so the two blend: flat-ish top that curls up at the corners,
# round bottom, two little teeth hanging near the corners and a tongue
SMILE_W, SMILE_TOP, SMILE_CURL, SMILE_DEPTH = 0.108, 0.952, 0.022, 0.052   # just under the snout overhang


def smile_top(x):
    return SMILE_TOP + SMILE_CURL * (x / SMILE_W) ** 2


def smile_bottom(x):
    return smile_top(x) - SMILE_DEPTH * math.sqrt(max(0.0, 1 - (x / SMILE_W) ** 2))


cols = [SMILE_W * math.sin(math.pi * (j / 32 - 0.5)) for j in range(33)]   # denser toward the corners
surface_patch("Mouth", JAW, [[(x, smile_top(x) + (smile_bottom(x) - smile_top(x)) * i / 10) for x in cols]
                                for i in range(11)], 0.003, "Mouth", HEADB)
TONGUE_W, TONGUE_H = 0.058, 0.028
tz = smile_bottom(0) + TONGUE_H * 1.05                         # flat top edge; round bottom resting in the mouth
tongue_cols = [math.pi * (j / 16 - 0.5) for j in range(17)]
surface_patch("Tongue", JAW, [[(TONGUE_W * math.sin(a), tz - TONGUE_H * (i / 8) * math.cos(a)) for a in tongue_cols]
                                 for i in range(9)], 0.0045, "Tongue", HEADB)
for sx in (1, -1):
    tx = 0.058 * sx
    tc = JAW.front(tx, smile_top(tx) - 0.013, offset=0.006)
    ellipsoid(f"Tooth.{'L' if sx > 0 else 'R'}", tc, (0.015, 0.006, 0.014), "Teeth", HEADB,
              rot=basis_facing(JAW.normal(tc)), power=0.6, u=16, v=8)

# =============================================================================
# Hair (shell wrapped to the head surface) and bow
# =============================================================================
head_ob = D.objects["Head"]
head_bvh = BVHTree.FromPolygons([v.co.copy() for v in head_ob.data.vertices],
                                [tuple(p.vertices) for p in head_ob.data.polygons])
HC = HEAD.c
NT, NR = 72, 20                 # columns are packed tighter across the bangs (see thetas below)
PH = math.radians(95)
INNER = 0.008
GROOVES = 14                     # strand clumps around the head; bang tips line up with them


def ss(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def p_cut(theta):
    a = abs(math.degrees(theta))
    p = 33 + 111 * ss(45, 100, a) + 8 * ss(100, 180, a)          # bangs above the brows -> shoulder length
    if theta < 0:                                               # side sweep falling past her right temple
        p += 9 * ss(25, 50, a) * (1 - ss(55, 95, a))
    clump = ((1 + math.cos(GROOVES * theta)) / 2) ** 3          # soft pointed tips where the strand clumps are
    p += (7 * (1 - ss(40, 60, a)) + 2 * ss(40, 60, a)) * clump
    return math.radians(p)


def hdir(p, theta):
    return Vector((math.sin(p) * math.sin(theta), -math.sin(p) * math.cos(theta), math.cos(p)))


def scalp(d):
    hit = head_bvh.ray_cast(HC, d)
    return hit[3] if hit[0] is not None else 0.28


def hair_point(p, theta, outer):
    t = p / p_cut(theta)
    a = abs(math.degrees(theta))
    vol = 0.55 + 0.45 * ss(30, 90, a)
    off = (0.03 + 0.03 * t * vol + 0.006 * math.cos(GROOVES * theta) * t * t) if outer else INNER
    if outer and a < 50:                                        # bangs curve in toward the forehead at the tips
        off = INNER + (off - INNER) * (1 - 0.25 * ss(0.75, 1.0, t))
    if p <= PH:
        d = hdir(p, theta)
        return HC + d * (scalp(d) + off)
    d = hdir(PH, theta)
    base = HC + d * (scalp(d) + off)
    drop = (p - PH) * (scalp(d) + off)
    flare = 1 + 0.3 * (p - PH) + (0.004 * math.cos(GROOVES * theta) if outer else 0)
    flare *= 1 - 0.07 * ss(0.8, 1.0, t)                        # ends curl softly inward
    h = base - HC
    return Vector((HC.x + h.x * flare, HC.y + h.y * flare, base.z - drop))


bm = bmesh.new()
# Uneven columns: ~2.3 degrees apart across the bangs (for smooth tips), ~10 degrees at the back
thetas = [math.pi * u * (0.45 + 0.55 * u * u) for u in (-1 + 2 * j / NT for j in range(NT))]
shells = {}
for outer in (True, False):
    top = bm.verts.new(HC + Vector((0, 0, scalp(Vector((0, 0, 1))) + (0.03 if outer else INNER))))
    rows = [[bm.verts.new(hair_point(p_cut(th) * k / NR, th, outer)) for th in thetas] for k in range(1, NR + 1)]
    shells[outer] = (top, rows)
for outer, (top, rows) in shells.items():
    for j in range(NT):
        j2 = (j + 1) % NT
        bm.faces.new((top, rows[0][j], rows[0][j2]))
        for k in range(NR - 1):
            bm.faces.new((rows[k][j], rows[k + 1][j], rows[k + 1][j2], rows[k][j2]))
o_hem, i_hem = shells[True][1][-1], shells[False][1][-1]
for j in range(NT):
    j2 = (j + 1) % NT
    bm.faces.new((o_hem[j], i_hem[j], i_hem[j2], o_hem[j2]))
new_obj("Hair", bm, "Hair", HEADB)

# Big red bow on top, tilted toward her left
bow_c = Vector((0.08, -0.01, 1.435))
bow_r = Euler((math.radians(-12), math.radians(-18), 0)).to_matrix()
for sx in (1, -1):
    lobe_r = bow_r @ Euler((0, math.radians(-28 * sx), math.radians(10 * sx))).to_matrix()
    ellipsoid(f"Bow Lobe.{sx}", bow_c + bow_r @ Vector((0.088 * sx, 0, 0.018)), (0.095, 0.022, 0.066), "Bow", HEADB, power=0.6,
              rot=lobe_r)
    tube(f"Bow Tail.{sx}", [bow_c + bow_r @ Vector((0.01 * sx, -0.01, -0.01)),
                            bow_c + bow_r @ Vector((0.045 * sx, -0.02, -0.07))],
         [(0.022, 0.008), (0.026, 0.006)], "Bow", HEADB, sides=8)
ellipsoid("Bow Knot", bow_c + bow_r @ Vector((0, -0.014, 0)), (0.03, 0.026, 0.034), "Bow", HEADB, power=0.7)

# =============================================================================
# Backpack
# =============================================================================
BP = ["chest"]
ellipsoid("Backpack", (0, 0.30, 0.60), (0.18, 0.09, 0.185), "Backpack", BP, power=0.45, u=32, v=16)
ellipsoid("Backpack Pocket", (0.175, 0.30, 0.53), (0.028, 0.07, 0.09), "Backpack Mesh", BP, power=0.5)
zip_pts = [Vector((0.15 * math.cos(a), 0.302, 0.60 + 0.183 * math.sin(a))) for a in
           (math.radians(20 + 140 * i / 10) for i in range(11))]
tube("Zipper", zip_pts, [(0.005, 0.005)] * len(zip_pts), "Zipper", BP, sides=6)
for sx, side in ((1, "L"), (-1, "R")):
    path = [(0.10 * sx, 0.25, 0.78), (0.14 * sx, 0.12, 0.90), (0.16 * sx, -0.06, 0.90), (0.18 * sx, -0.18, 0.77),
            (0.20 * sx, -0.17, 0.62), (0.205 * sx, -0.12, 0.50)]
    pts = []
    for a, b in zip(path, path[1:]):
        for k in range(6):
            pts.append(TORSO.project(Vector(a).lerp(Vector(b), k / 6), offset=0.014))
    pts.append(TORSO.project(path[-1], offset=0.014))
    tube(f"Backpack Strap.{side}", pts, [(0.021, 0.006)] * len(pts), "Backpack", BP, sides=8, normal_fn=TORSO.normal)

# =============================================================================
# Rig
# =============================================================================
BONES = {
    "root": ((0, 0, 0), (0, 0, 0.25), None),
    "hips": ((0, 0, 0.50), (0, 0, 0.62), "root"),
    "spine": ((0, 0, 0.62), (0, 0, 0.76), "hips"),
    "chest": ((0, 0, 0.76), (0, 0, 0.90), "spine"),
    "head": ((0, 0, 0.90), (0, 0, 1.45), "chest"),
}
for sx, side in ((1, "L"), (-1, "R")):
    BONES.update({
        f"upper_arm.{side}": ((0.235 * sx, 0, 0.80), (0.32 * sx, -0.03, 0.67), "chest"),
        f"forearm.{side}": ((0.32 * sx, -0.03, 0.67), (0.39 * sx, -0.05, 0.56), f"upper_arm.{side}"),
        f"hand.{side}": ((0.39 * sx, -0.05, 0.56), (0.43 * sx, -0.065, 0.49), f"forearm.{side}"),
        f"thigh.{side}": ((0.12 * sx, 0, 0.50), (0.12 * sx, 0, 0.32), "hips"),
        f"shin.{side}": ((0.12 * sx, 0, 0.32), (0.12 * sx, 0, 0.10), f"thigh.{side}"),
        f"foot.{side}": ((0.12 * sx, 0, 0.10), (0.12 * sx, -0.14, 0.04), f"shin.{side}"),
    })

arm_data = D.armatures.new("NinaRig")
rig = D.objects.new("NinaRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, (h, t, parent) in BONES.items():
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = h, t
    if parent:
        eb.parent = arm_data.edit_bones[parent]
        eb.use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')


def seg_dist(p, a, b):
    a, b = Vector(a), Vector(b)
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


for ob, bones in PARTS:
    spec = [(b, 1.0) if isinstance(b, str) else b for b in bones]
    groups = {name: ob.vertex_groups.new(name=name) for name, _ in spec}
    for v in ob.data.vertices:
        if len(spec) == 1:
            groups[spec[0][0]].add([v.index], 1.0, 'REPLACE')
            continue
        raw = {name: 1.0 / ((seg_dist(v.co, *BONES[name][:2]) * s) ** 4 + 1e-9) for name, s in spec}
        total = sum(raw.values())
        w = {n: x / total for n, x in raw.items() if x / total > 0.02}
        total = sum(w.values())
        for n, x in w.items():
            groups[n].add([v.index], x / total, 'REPLACE')

# Join everything into one skinned mesh
bpy.ops.object.select_all(action='DESELECT')
for ob, _ in PARTS:
    ob.select_set(True)
body = D.objects["Torso"]
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = body.data.name = "Nina"
body.parent = rig
mod = body.modifiers.new("Armature", 'ARMATURE')
mod.object = rig
tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
print(f"MESH parts={len(PARTS)} verts={len(body.data.vertices)} tris={tris} materials={len(body.data.materials)}")

# =============================================================================
# Animations (rotations given about world axes in the rest pose; she faces -Y)
#   legs/arms pointing down: -X swings forward, +X swings back
#   left arm: +Y lowers, -Y raises (right arm: mirrored)
# =============================================================================
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'


def local_quat(pb, rots):
    M = pb.bone.matrix_local.to_3x3()
    R = Matrix.Identity(3)
    for axis, ang in rots:
        R = Matrix.Rotation(ang, 3, axis) @ R
    return (M.inverted() @ R @ M).to_quaternion()


def make_action(name, frames, pose_fn):
    act = D.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f in range(frames + 1):
        pose, bob = pose_fn(f / frames)
        for pb in rig.pose.bones:
            pb.rotation_quaternion = local_quat(pb, pose.get(pb.name, []))
            pb.keyframe_insert("rotation_quaternion", frame=f)
        root = rig.pose.bones["root"]
        root.location = (0, bob, 0)                              # root's local Y is world up
        root.keyframe_insert("location", frame=f)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    track.mute = True
    rig.animation_data.action = None


def arms_down(extra_l=(), extra_r=()):
    return {"upper_arm.L": [(Y, 0.38), *extra_l], "upper_arm.R": [(Y, -0.38), *extra_r],
            "forearm.L": [(X, -0.3)], "forearm.R": [(X, -0.3)]}


def idle(t):
    s = math.sin(2 * math.pi * t)
    pose = arms_down([(Y, 0.03 * s)], [(Y, -0.03 * s)])
    pose.update({"spine": [(X, 0.02 * s)], "chest": [(X, 0.015 * s)],
                 "head": [(Y, 0.035 * math.sin(2 * math.pi * t + 1.2)), (X, -0.02 * s)]})
    return pose, 0.006 * s


def run(t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    pose = {
        "thigh.L": [(X, -0.65 * s)], "thigh.R": [(X, 0.65 * s)],
        "shin.L": [(X, 0.25 + 0.75 * max(0.0, -c))], "shin.R": [(X, 0.25 + 0.75 * max(0.0, c))],
        "foot.L": [(X, -0.2 * s)], "foot.R": [(X, 0.2 * s)],
        "upper_arm.L": [(Y, 0.3), (X, 0.7 * s)], "upper_arm.R": [(Y, -0.3), (X, -0.7 * s)],
        "forearm.L": [(X, -1.0)], "forearm.R": [(X, -1.0)],
        "spine": [(X, 0.14)], "chest": [(Z, 0.1 * s)], "head": [(X, -0.1), (Z, -0.06 * s)],
    }
    return pose, 0.035 * abs(math.sin(ph))


def jump(t):
    k = ss(0, 1, t)
    pose = {
        "thigh.L": [(X, -0.55 * k)], "thigh.R": [(X, -0.35 * k)],
        "shin.L": [(X, 0.95 * k)], "shin.R": [(X, 0.6 * k)],
        "upper_arm.L": [(Y, 0.38 - 1.3 * k)], "upper_arm.R": [(Y, -0.38 + 1.3 * k)],
        "forearm.L": [(X, -0.3 - 0.3 * k)], "forearm.R": [(X, -0.3 - 0.3 * k)],
        "spine": [(X, -0.06 * k)], "head": [(X, -0.1 * k)],
    }
    return pose, 0.0


def fall(t):
    s = math.sin(2 * math.pi * t)
    pose = {
        "thigh.L": [(X, -0.25 + 0.15 * s)], "thigh.R": [(X, -0.25 - 0.15 * s)],
        "shin.L": [(X, 0.45)], "shin.R": [(X, 0.45)],
        "upper_arm.L": [(Y, -1.0 + 0.15 * s)], "upper_arm.R": [(Y, 1.0 + 0.15 * s)],
        "forearm.L": [(X, -0.5 - 0.2 * s)], "forearm.R": [(X, -0.5 + 0.2 * s)],
        "head": [(X, 0.08)],
    }
    return pose, 0.0


make_action("idle", 60, idle)
make_action("run", 20, run)
make_action("jump", 10, jump)
make_action("fall", 24, fall)
for pb in rig.pose.bones:                                    # back to the rest pose for editing
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.location = (0, 0, 0)
scene.frame_start, scene.frame_end = 0, 60

# Viewport niceties: a camera and light for quick renders
cam = D.objects.new("Camera", D.cameras.new("Camera"))
scene.collection.objects.link(cam)
scene.camera = cam
sun = D.objects.new("Light", D.lights.new("Light", 'SUN'))
scene.collection.objects.link(sun)

OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
print("SAVED", OUT)

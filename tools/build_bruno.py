# Builds Bruno, Nina's little brother, as the hippo-like alien he is in Galaxity: model, materials, rig, weights and
# animations. Reference: Sofi's drawings of him (the "Kids songvideo more ideas" notes, copied to
# source_art/reference/Bruno - SK8 beanie.png): a grey hippo boy with a mop of golden hair, a black knit SK8 beanie
# pulled down to his ears, an open blue zip hoodie over an olive tee, his tongue poking out of a cheeky grin, and a
# gap where he lost a tooth (that's his lisp).
#
#   blender -b --python tools\build_bruno.py
#
# Writes source_art/characters/bruno.blend (overwrites it). He's made the same way as Nina (tools/build_nina.py):
# the same head, snout and body shapes, so the two look like brother and sister, with his own hair, hat and clothes.
# Every shape below is a plain number you can tweak and rebuild. Units are meters; feet at the origin; he faces -Y.

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "bruno.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)
D = bpy.data
scene = bpy.context.scene
scene.render.fps = 30


# =============================================================================
# Materials (linear colors picked from Sofi's drawing)
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


mat("Skin", (0.25, 0.20, 0.21))                  # a cooler, greyer hippo than Nina, a touch of lilac
mat("Blush", (0.62, 0.30, 0.34))
mat("Ear Inner", (0.72, 0.33, 0.36))
mat("Nostril", (0.06, 0.04, 0.045))
mat("Freckle", (0.12, 0.08, 0.085))
mat("Mouth", (0.16, 0.02, 0.03))
mat("Tongue", (0.80, 0.22, 0.26))
mat("Teeth", (0.88, 0.87, 0.82), rough=0.3)
mat("Eye White", (0.90, 0.90, 0.90), rough=0.08)
mat("Iris", (0.02, 0.05, 0.16), rough=0.08)     # deep blue eyes
mat("Iris Light", (0.10, 0.25, 0.55), rough=0.08)
mat("Eye Shine", (1.0, 1.0, 1.0), rough=0.05, emit=1.5)
mat("Pupil", (0.005, 0.004, 0.004), rough=0.05)
mat("Brow", (0.06, 0.035, 0.02))
mat("Hair", (1.0, 0.64, 0.03), rough=0.4)     # golden yellow, orange in the shadows
mat("Hair Shade", (0.88, 0.40, 0.01), rough=0.4)
mat("Beanie", (0.025, 0.025, 0.028), rough=0.9)
mat("Beanie Rib", (0.012, 0.012, 0.014), rough=0.95)
mat("Patch", (0.10, 0.10, 0.11), rough=0.6)
mat("Patch Text", (0.85, 0.85, 0.85), rough=0.5)
mat("Tee", (0.19, 0.24, 0.035), rough=0.8)      # olive green
mat("Hoodie", (0.012, 0.075, 0.62), rough=0.75)  # bright royal blue
mat("Hoodie Rib", (0.008, 0.05, 0.42), rough=0.85)
mat("Zip", (0.55, 0.55, 0.58), rough=0.3, metal=0.8)
mat("Drawstring", (0.80, 0.80, 0.82), rough=0.6)
mat("Jeans", (0.035, 0.045, 0.09), rough=0.8)    # dark skate jeans
mat("Shoes", (0.02, 0.02, 0.022), rough=0.6)     # black skate shoes
mat("Sole", (0.88, 0.88, 0.88))
mat("Lace", (0.92, 0.92, 0.92))

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
MUZZLE = Ellipsoid((0, -0.22, 1.035), (0.15, 0.095, 0.08))    # short, broad, flat-fronted (brachycephalic) snout
TORSO = Ellipsoid((0, 0, 0.64), (0.27, 0.235, 0.26))
HEADB = ["head"]

# Chubby lower face: the front of the head is pushed forward under the snout, where the mouth is drawn
CHIN_Z, CHIN_SPREAD, CHIN_HALF_W, CHIN_PUSH = 0.925, 0.075, 0.22, 0.05


def chin_push(x, y, z):
    """How far (m) the head surface at this point is pushed toward -Y."""
    frontness = max(0.0, -(y - HEAD.c.y) / HEAD.r.y)
    across = max(0.0, math.cos(math.pi / 2 * min(abs(x) / CHIN_HALF_W, 1.0))) ** 1.5
    return CHIN_PUSH * math.exp(-((z - CHIN_Z) / CHIN_SPREAD) ** 2) * across * frontness


# Chubby cheeks: round bulges beside the snout, under the eyes
CHEEK_X, CHEEK_Z, CHEEK_SPREAD, CHEEK_PUSH = 0.195, 1.04, 0.065, 0.045


def head_offset(p):
    """Where the head surface at p moves to: the chubby chin plus the cheeks."""
    off = Vector((0, -chin_push(p.x, p.y, p.z), 0))
    if p.y < HEAD.c.y:
        for sx in (1, -1):
            d2 = ((p.x - sx * CHEEK_X) ** 2 + (p.z - CHEEK_Z) ** 2) / CHEEK_SPREAD ** 2
            n = HEAD.normal(p)
            forward = Vector((n.x * 0.3, n.y, n.z)).normalized()   # puff forward, not sideways, so the skull stays narrow
            off += forward * CHEEK_PUSH * math.exp(-d2)
    return off


# Philtrum: a soft vertical groove down the front of the snout, from the nose to the smile
PHILTRUM_W, PHILTRUM_DEPTH, PHILTRUM_TOP, PHILTRUM_BOTTOM = 0.02, 0.013, 1.045, 0.99


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def philtrum_dip(x, z):
    return PHILTRUM_DEPTH * math.exp(-(x / PHILTRUM_W) ** 2) * smoothstep(PHILTRUM_TOP, PHILTRUM_BOTTOM, z)


class Face:
    """The head's front surface including the chubby chin and cheeks, for drawing the mouth on."""

    def front(self, x, z, offset=0.0):
        p = HEAD.front(x, z)
        p = p + head_offset(p)
        return p + self.normal(p) * offset if offset else p

    def normal(self, p):
        e = 0.002
        dx = self.front(p.x + e, p.z) - self.front(p.x - e, p.z)
        dz = self.front(p.x, p.z + e) - self.front(p.x, p.z - e)
        n = dz.cross(dx).normalized()
        return n if n.y < 0 else -n


FACE = Face()

head_obj = ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HEADB, u=48, v=24)
for v in head_obj.data.vertices:
    v.co += head_offset(v.co.copy())
muzzle_obj = ellipsoid("Muzzle", MUZZLE.c, MUZZLE.r, "Skin", HEADB, u=96, v=32)
for v in muzzle_obj.data.vertices:
    if v.co.y < MUZZLE.c.y:
        v.co.y += philtrum_dip(v.co.x, v.co.z) * (MUZZLE.c.y - v.co.y) / MUZZLE.r.y

# Torso: one smooth shape, painted shirt / overalls bib by face position

# Torso: his olive tee, with the jeans' waist below it
torso = ellipsoid("Torso", TORSO.c, TORSO.r, "Tee", ["hips", "spine", "chest", ("thigh.L", 1.8), ("thigh.R", 1.8)],
                  u=96, v=48)
torso.data.materials.append(MATS["Jeans"])
WAIST = 0.50
for p in torso.data.polygons:
    if p.center.z < WAIST:
        p.material_index = 1


def solid_shell(name, ell, grow, keep, material, bones, thick=0.012, u=96, v=48):
    """A cloth layer just outside ell: the faces keep(center) says yes to, given a little thickness so it has an
    inside and an outside (an open hoodie can be seen into)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vt in bm.verts:
        vt.co = Vector((vt.co.x * (ell.r.x + grow), vt.co.y * (ell.r.y + grow), vt.co.z * (ell.r.z + grow))) + ell.c
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep(f.calc_center_median())], context='FACES')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
    return new_obj(name, bm, material, bones, recalc=False)


# The hoodie: open down the front to show the tee, from the shoulders to just below the waist
HOOD_GROW, HOOD_BOTTOM, HOOD_TOP = 0.022, 0.43, 0.875
GAP = math.radians(17)                                  # half the open front, as an angle round his body
GAP_WIDEN = math.radians(9)                             # it hangs open a little wider at the bottom


def hoodie_keeps(c):
    if not (HOOD_BOTTOM < c.z < HOOD_TOP):
        return False
    a = abs(math.atan2(c.x, -c.y))
    t = min(max((HOOD_TOP - c.z) / (HOOD_TOP - HOOD_BOTTOM), 0.0), 1.0)
    return a > GAP + GAP_WIDEN * t


HOOD_BONES = ["hips", "spine", "chest", ("thigh.L", 2.2), ("thigh.R", 2.2)]
solid_shell("Hoodie", TORSO, HOOD_GROW, hoodie_keeps, "Hoodie", HOOD_BONES)
HOODIE = Ellipsoid(TORSO.c, TORSO.r + Vector((HOOD_GROW, HOOD_GROW, HOOD_GROW)))


def ring_at(ell, z, a, off=0.0):
    """The point on ell's surface at height z, at angle a round it (0 straight ahead, positive to his left)."""
    k = math.sqrt(max(1 - ((z - ell.c.z) / ell.r.z) ** 2, 0.0))
    p = Vector((ell.c.x + ell.r.x * k * math.sin(a), ell.c.y - ell.r.y * k * math.cos(a), z))
    return p + ell.normal(p) * off


def hoodie_edge(sx, z):
    """The point on the open front's edge at height z, on his left (sx=1) or right (sx=-1)."""
    t = min(max((HOOD_TOP - z) / (HOOD_TOP - HOOD_BOTTOM), 0.0), 1.0)
    return ring_at(HOODIE, z, (GAP + GAP_WIDEN * t) * sx, 0.006)


# Ribbed hem round the bottom, and the zip running down each side of the open front
hem = [ring_at(HOODIE, HOOD_BOTTOM + 0.014, GAP + GAP_WIDEN + (2 * math.pi - 2 * (GAP + GAP_WIDEN)) * k / 60, 0.004)
       for k in range(61)]
tube("Hoodie Hem", hem, [(0.022, 0.012)] * len(hem), "Hoodie Rib", HOOD_BONES, sides=8, caps=True)
for sx, side in ((1, "L"), (-1, "R")):
    edge = [hoodie_edge(sx, HOOD_BOTTOM + 0.005 + (HOOD_TOP - 0.03 - HOOD_BOTTOM) * k / 24) for k in range(25)]
    tube(f"Zip.{side}", edge, [(0.006, 0.006)] * len(edge), "Zip", ["spine", "chest"], sides=6)
    # The hoodie's front pocket on each side, a soft patch with a pouch opening
    pc = HOODIE.project(Vector((0.17 * sx, -0.3, 0.52)), offset=0.006)
    ellipsoid(f"Pocket.{side}", pc, (0.075, 0.009, 0.06), "Hoodie Rib", ["hips", "spine"],
              rot=basis_facing(HOODIE.normal(pc)) @ Euler((0, math.radians(14 * sx), 0)).to_matrix(), power=0.5, u=24, v=12)
# The zip pull, hanging from the top of his left zip
pull = hoodie_edge(1, HOOD_TOP - 0.06)
ellipsoid("Zip Pull", pull + Vector((0.004, -0.006, -0.02)), (0.008, 0.004, 0.02), "Zip", ["chest"], power=0.6, u=12, v=6)

# The hood, bunched round his neck at the back and coming round the front to the collar
hood_pts = []
for k in range(33):
    a = math.radians(-(90 - 28) + (360 - 2 * 28) * k / 32 - 90)      # from the front-left, round the back, to the front-right
    back = max(0.0, math.sin(a))                                     # 1 straight behind him
    r = 0.17 + 0.02 * back
    hood_pts.append(Vector((math.cos(a) * r, math.sin(a) * r + 0.015, 0.855 + 0.03 * back)))
hood_rad = []
for k in range(33):
    back = max(0.0, (hood_pts[k].y - 0.015) / 0.19)
    hood_rad.append((0.032 + 0.045 * back, 0.03 + 0.05 * back))
tube("Hood", hood_pts, hood_rad, "Hoodie", ["chest", ("head", 3.0)], sides=14)
# Drawstrings: two little white cords hanging from the collar, with plastic tips
for sx, side in ((1, "L"), (-1, "R")):
    top = hoodie_edge(sx, HOOD_TOP - 0.02) + Vector((0.02 * sx, -0.012, 0))
    cord = [top + Vector((0.006 * sx * t, -0.01 * math.sin(math.pi * t), -0.15 * t)) for t in (i / 8 for i in range(9))]
    tube(f"Drawstring.{side}", cord, [(0.0055, 0.0055)] * len(cord), "Drawstring", ["chest"], sides=6)
    ellipsoid(f"Drawstring Tip.{side}", cord[-1] + Vector((0, 0, -0.012)), (0.008, 0.008, 0.016), "Drawstring", ["chest"],
              u=10, v=6)

# Arms (A-pose): long blue sleeves with ribbed cuffs, mitten hands with a thumb
for sx, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.235 * sx, 0, 0.80)), Vector((0.32 * sx, -0.03, 0.67)), Vector((0.39 * sx, -0.05, 0.56))
    capsule(f"Arm.{side}", [sh, el, wr], 0.060, 0.054, "Skin", [f"upper_arm.{side}", f"forearm.{side}"])
    capsule(f"Sleeve.{side}", [sh + Vector((-0.014 * sx, 0, 0.012)), el, wr - (wr - el).normalized() * 0.02],
            0.084, 0.074, "Hoodie", [f"upper_arm.{side}", f"forearm.{side}", ("chest", 1.6)])
    d = (wr - el).normalized()
    cuff_c = wr - d * 0.02
    torus(f"Cuff.{side}", (0, 0, 0), 0.066, 0.018, "Hoodie Rib", [f"forearm.{side}"])
    cuff = D.objects[f"Cuff.{side}"]
    cuff.data.transform(Matrix.Translation(cuff_c) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())
    ellipsoid(f"Hand.{side}", wr + d * 0.045, (0.058, 0.052, 0.066), "Skin", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", wr + d * 0.03 + Vector((0, -0.045, 0.005)), (0.022, 0.026, 0.03), "Skin", [f"hand.{side}"])

# Legs: baggy dark jeans down to his shoes, rolled once at the bottom, and black skate shoes with white soles
for sx, side in ((1, "L"), (-1, "R")):
    x = 0.12 * sx
    capsule(f"Jeans.{side}", [(0.11 * sx, 0, 0.50), (x, 0, 0.32), (x, -0.005, 0.15)], 0.112, 0.095, "Jeans",
            [("hips", 1.6), f"thigh.{side}", f"shin.{side}"])
    torus(f"Jeans Roll.{side}", (x, -0.005, 0.145), 0.094, 0.022, "Jeans", [f"shin.{side}"])
    ellipsoid(f"Shoe.{side}", (x, -0.045, 0.075), (0.084, 0.13, 0.07), "Shoes", [f"foot.{side}"], power=0.7)
    ellipsoid(f"Sole.{side}", (x, -0.045, 0.024), (0.09, 0.138, 0.026), "Sole", [f"foot.{side}"], power=0.45)
    ellipsoid(f"Toe Cap.{side}", (x, -0.14, 0.05), (0.068, 0.05, 0.042), "Sole", [f"foot.{side}"])
    for k, yy in enumerate((-0.09, -0.06, -0.03)):              # laces
        ellipsoid(f"Lace.{side}{k}", (x, yy, 0.136 - k * 0.004), (0.045, 0.007, 0.006), "Lace", [f"foot.{side}"],
                  power=0.6, u=12, v=6)
    # The skate shoe's side stripe
    stripe = [Vector((x + 0.086 * sx, -0.10 + 0.13 * t, 0.06 + 0.04 * math.sin(math.pi * t))) for t in (i / 8 for i in range(9))]
    tube(f"Shoe Stripe.{side}", stripe, [(0.008, 0.003)] * len(stripe), "Sole", [f"foot.{side}"], sides=6,
         normal_fn=lambda p, sx=sx: Vector((sx, 0, 0)))

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
    # Lashes: three little flicks at the upper outer corner, rooted on the edge where the eye meets his face
    for k, a in enumerate((70, 45, 22)):
        ar = math.radians(a)

        def on_eye(t):                       # walk from the front of the eye out toward its rim at this angle
            return ec + Vector((0.07 * math.sin(t) * math.cos(ar) * sx, -0.05 * math.cos(t), 0.08 * math.sin(t) * math.sin(ar)))
        lo, hi = 0.0, math.pi / 2
        for _ in range(30):                  # bisect for the first point that sinks into the head
            mid = (lo + hi) / 2
            if HEAD.inside(on_eye(mid)):
                hi = mid
            else:
                lo = mid
        rim = on_eye(lo)
        radial = Vector((rim.x - ec.x, 0, rim.z - ec.z)).normalized()
        base = HEAD.project(rim + radial * 0.006, offset=0.001)     # on the head, just outside the eye's edge
        n = HEAD.normal(base)
        along = (radial - n * radial.dot(n)).normalized()           # away from the eye, along the face
        tip = base + (along * 0.7 + n * 0.55).normalized() * 0.02 + Vector((0, 0, 0.004))
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
        bc0 = HEAD.project(HEAD.c + Vector(((0.5 + 0.03 * k) * sx, -0.6, 0.04)))
        bc, n = FACE.front(bc0.x, bc0.z), FACE.normal(bc0)          # rides on the chubby cheek
        rim = [bc + basis_facing(n) @ Vector((0.046 * math.cos(a), 0, 0.032 * math.sin(a)))
               for a in (i * math.pi / 8 for i in range(16))]
        if not any(MUZZLE.inside(p, 1.06) or eye_e.inside(p, 1.15) for p in rim):
            break
    ellipsoid(f"Blush.{side}", bc - n * 0.008, (0.046, 0.012, 0.032), "Blush", HEADB, rot=basis_facing(n))
    # Ears with pink insides, sticking out sideways from under his beanie
    ear = Vector((0.262 * sx, 0.035, 1.235))
    er = Euler((0, math.radians(-48 * sx), math.radians(-14 * sx))).to_matrix()
    ellipsoid(f"Ear.{side}", ear, (0.065, 0.035, 0.062), "Skin", HEADB, rot=er)
    ellipsoid(f"Ear Inner.{side}", ear + er @ Vector((0, -0.024, 0.004)), (0.04, 0.014, 0.04), "Ear Inner", HEADB, rot=er)
    # Nostrils on the upper front of the snout
    ns = MUZZLE.front(0.05 * sx, 1.052)                          # on the flat front, facing forward
    ellipsoid(f"Nostril.{side}", ns - MUZZLE.normal(ns) * 0.007, (0.022, 0.012, 0.017), "Nostril", HEADB,
              rot=basis_facing(MUZZLE.normal(ns)))
    # Freckles: a few little dots on each side of his snout, under the nostrils
    for k, (fx, fz) in enumerate(((0.098, 1.0), (0.122, 1.012), (0.118, 0.986), (0.138, 0.998))):
        fp = MUZZLE.project(Vector((fx * sx, MUZZLE.c.y - 0.2, fz)), offset=0.0015)
        ellipsoid(f"Freckle.{side}{k}", fp, (0.0055, 0.002, 0.0055), "Freckle", HEADB, rot=basis_facing(MUZZLE.normal(fp)),
                  u=8, v=4)


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
SMILE_W, SMILE_DEPTH = 0.12, 0.052       # smile width (half) and how far it opens below the snout


def snout_seam(x):
    """Height where the snout's underside meets his face at this x, so the smile starts right at the snout."""
    lo, hi = MUZZLE.c.z - MUZZLE.r.z, MUZZLE.c.z
    if abs(x) >= MUZZLE.r.x:
        return lo
    for _ in range(30):                     # bisect: above the seam the snout is in front, below it the face is
        mid = (lo + hi) / 2
        if FACE.front(x, mid).y < MUZZLE.front(x, mid).y + philtrum_dip(x, mid):
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def smile_top(x):
    return snout_seam(x) - 0.003


def smile_bottom(x):
    return smile_top(x) - SMILE_DEPTH * math.sqrt(max(0.0, 1 - (x / SMILE_W) ** 2))


cols = [SMILE_W * math.sin(math.pi * (j / 32 - 0.5)) for j in range(33)]   # denser toward the corners
surface_patch("Mouth", FACE, [[(x, smile_top(x) + (smile_bottom(x) - smile_top(x)) * i / 10) for x in cols]
                                for i in range(11)], 0.003, "Mouth", HEADB)
TONGUE_W, TONGUE_H = 0.058, 0.028
tz = smile_bottom(0) + TONGUE_H * 1.05                         # flat top edge; round bottom resting in the mouth
tongue_cols = [math.pi * (j / 16 - 0.5) for j in range(17)]
surface_patch("Tongue", FACE, [[(TONGUE_W * math.sin(a), tz - TONGUE_H * (i / 8) * math.cos(a)) for a in tongue_cols]
                                 for i in range(9)], 0.0045, "Tongue", HEADB)
for sx in (1,):                    # just his left tooth: the other one fell out, which is where his lisp comes from
    tx = 0.55 * SMILE_W * sx
    tc = FACE.front(tx, smile_top(tx) - 0.012, offset=0.006)
    ellipsoid(f"Tooth.{'L' if sx > 0 else 'R'}", tc, (0.015, 0.006, 0.014), "Teeth", HEADB,
              rot=basis_facing(FACE.normal(tc)), power=0.6, u=16, v=8)

# =============================================================================
# His tongue poking out of the corner of his grin, the way Sofi drew him
tip_x = -0.022
tip = FACE.front(tip_x, smile_bottom(tip_x) + 0.004, offset=0.016)
ellipsoid("Tongue Tip", tip, (0.034, 0.022, 0.026), "Tongue", HEADB,
          rot=basis_facing(FACE.normal(tip)) @ Euler((math.radians(-30), 0, 0)).to_matrix(), u=20, v=10)

# =============================================================================
# Hair (a shell wrapped to the head) and the SK8 beanie over it
# =============================================================================
head_ob = D.objects["Head"]
head_bvh = BVHTree.FromPolygons([v.co.copy() for v in head_ob.data.vertices],
                                [tuple(p.vertices) for p in head_ob.data.polygons])
HC = HEAD.c
NT, NR = 96, 22
PH = math.radians(95)
INNER = 0.008


def ss(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def tri(x):
    """A sawtooth that goes 0 -> 1 -> 0 each whole number: the points of his spiky fringe."""
    f = x - math.floor(x)
    return 1 - abs(2 * f - 1)


TUFTS = 15                       # spiky tufts round his head, poking out from under the beanie


def p_cut(theta):
    """How far down from the top of his head the hair reaches (an angle), all the way round. A messy golden mop:
    a short spiky fringe over his brows, longer tufts down past his ears at the sides, short at the back."""
    a = abs(math.degrees(theta))
    p = 47 + 42 * ss(30, 95, a) - 4 * ss(120, 180, a)
    spike = tri(theta * TUFTS / (2 * math.pi) + 0.35)
    p += (7 + 7 * ss(25, 90, a)) * spike
    if a < 45:                                                  # the fringe falls a little longer on his right
        p += 4 * max(-1.0, min(1.0, math.degrees(theta) / 35)) * (1 - ss(28, 45, a))
    return math.radians(p)


def hdir(p, theta):
    return Vector((math.sin(p) * math.sin(theta), -math.sin(p) * math.cos(theta), math.cos(p)))


def scalp(d):
    hit = head_bvh.ray_cast(HC, d)
    return hit[3] if hit[0] is not None else 0.28


def hair_point(p, theta, outer):
    t = p / p_cut(theta)
    a = abs(math.degrees(theta))
    side = ss(40, 90, a) * (1 - ss(130, 170, a))
    off = (0.02 + 0.03 * t + 0.035 * side * t ** 3) if outer else INNER      # the side tufts flick outward
    if p <= PH:
        d = hdir(p, theta)
        return HC + d * (scalp(d) + off)
    d = hdir(PH, theta)
    base = HC + d * (scalp(d) + off)
    drop = (p - PH) * (scalp(d) + off)
    h = base - HC
    return Vector((HC.x + h.x * 1.1, HC.y + h.y * 1.1, base.z - drop))


bm = bmesh.new()
thetas = [-math.pi + 2 * math.pi * j / NT for j in range(NT)]
shells = {}
for outer in (True, False):
    top = bm.verts.new(HC + Vector((0, 0, scalp(Vector((0, 0, 1))) + (0.02 if outer else INNER))))
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
hair = new_obj("Hair", bm, "Hair", HEADB)
# The tips of the tufts are a darker gold, so the spikes read against his face
hair.data.materials.append(MATS["Hair Shade"])
for poly in hair.data.polygons:
    c = poly.center - HC
    p = math.acos(max(-1.0, min(1.0, c.z / c.length)))
    th = math.atan2(c.x, -c.y)
    if p > p_cut(th) * 0.86:
        poly.material_index = 1

# The beanie: a slouchy black knit dome pulled down to just above his ears and brows, sitting further down at the
# back, with a folded cuff and the SK8 patch on the front of the cuff (on his left)
CUFF_H = math.radians(13)                                      # how deep the folded cuff is


def p_rim(theta):
    """Where the beanie's bottom edge sits (an angle down from the top of his head) all the way round."""
    return math.radians(40 + 42 * (1 - math.cos(theta)) / 2)


def beanie_point(p, theta, extra=0.0, ribs=True):
    d = hdir(p, theta)
    t = p / p_rim(theta)
    lift = 0.15 - 0.10 * t                                     # roomy on top, snug at the cuff
    off = scalp(d) + lift + extra + (0.0025 * math.sin(56 * theta) if ribs else 0.0)
    pt = HC + d * off
    return pt + Vector((0, 0.06 * (1 - t) ** 2, 0.02 * (1 - t)))     # slouches back a little at the top


BR = 18
bm = bmesh.new()
top = bm.verts.new(beanie_point(0.0, 0.0, ribs=False))
rows = [[bm.verts.new(beanie_point(p_rim(th) * k / BR, th)) for th in thetas] for k in range(1, BR + 1)]
for j in range(NT):
    j2 = (j + 1) % NT
    bm.faces.new((top, rows[0][j], rows[0][j2]))
    for k in range(BR - 1):
        bm.faces.new((rows[k][j], rows[k + 1][j], rows[k + 1][j2], rows[k][j2]))
inner = [bm.verts.new(beanie_point(p_rim(th), th, extra=-0.03, ribs=False)) for th in thetas]   # tucked-in edge
for j in range(NT):
    j2 = (j + 1) % NT
    bm.faces.new((rows[-1][j], inner[j], inner[j2], rows[-1][j2]))
new_obj("Beanie", bm, "Beanie", HEADB)

# The folded cuff: a thick ribbed band round the bottom of the beanie
bm = bmesh.new()
CR = 5
bands = []
for k in range(CR + 1):
    t = k / CR
    bulge = 0.012 * math.sin(math.pi * t)
    bands.append([bm.verts.new(beanie_point(p_rim(th) - CUFF_H * (1 - t), th, extra=0.012 + bulge, ribs=False)
                               + Vector((0, 0, 0))) for th in thetas])
inside = [bm.verts.new(beanie_point(p_rim(th), th, extra=-0.025, ribs=False)) for th in thetas]
top_in = [bm.verts.new(beanie_point(p_rim(th) - CUFF_H, th, extra=-0.005, ribs=False)) for th in thetas]
ring_list = bands + [inside, top_in]
for r0, r1 in zip(ring_list, ring_list[1:] + [ring_list[0]]):
    for j in range(NT):
        j2 = (j + 1) % NT
        bm.faces.new((r0[j], r1[j], r1[j2], r0[j2]))
new_obj("Beanie Cuff", bm, "Beanie Rib", HEADB)

# The SK8 patch, stitched on the cuff over his left eye
PATCH_TH = math.radians(24)
pc = beanie_point(p_rim(PATCH_TH) - CUFF_H * 0.5, PATCH_TH, extra=0.026, ribs=False)
pn = (Vector((pc.x, pc.y, 0)).normalized() + Vector((0, 0, 0.35))).normalized()   # faces out from the cuff
pr = basis_facing(pn) @ Euler((0, math.radians(-12), 0)).to_matrix()     # tilted a little, like the drawing
ellipsoid("Patch", pc, (0.05, 0.006, 0.026), "Patch", HEADB, rot=pr, power=0.35, u=24, v=10)
patch_border = [pc + pr @ Vector((0.052 * math.cos(a), -0.004, 0.028 * math.sin(a))) for a in
                (2 * math.pi * k / 40 for k in range(41))]
tube("Patch Stitch", patch_border, [(0.0022, 0.0022)] * len(patch_border), "Patch Text", HEADB, sides=5, caps=False)
txt_curve = D.curves.new("SK8 Text", 'FONT')
txt_curve.body = "SK8"
txt_curve.size = 0.04
txt_curve.extrude = 0.0015
txt_curve.align_x = 'CENTER'
txt_curve.align_y = 'CENTER'
txt_ob = D.objects.new("SK8 Text", txt_curve)
scene.collection.objects.link(txt_ob)
dg = bpy.context.evaluated_depsgraph_get()
txt_me = D.meshes.new_from_object(txt_ob.evaluated_get(dg))
D.objects.remove(txt_ob)
bm = bmesh.new()
bm.from_mesh(txt_me)
# The text is drawn flat in X-Y facing +Z: stand it up to face the patch's front (-Y in patch space)
stand = Matrix.Rotation(math.radians(90), 3, 'X')
for vt in bm.verts:
    vt.co = pc + pr @ (stand @ vt.co + Vector((0, -0.0075, 0)))
new_obj("Patch Text", bm, "Patch Text", HEADB)

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

arm_data = D.armatures.new("BrunoRig")
rig = D.objects.new("BrunoRig", arm_data)
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
body.name = body.data.name = "Bruno"
body.parent = rig
mod = body.modifiers.new("Armature", 'ARMATURE')
mod.object = rig
tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
print(f"MESH parts={len(PARTS)} verts={len(body.data.vertices)} tris={tris} materials={len(body.data.materials)}")

# =============================================================================
# Animations (rotations given about world axes in the rest pose; he faces -Y)
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




def bruno_idle(t):
    # Hands shoved in his hoodie pockets, rocking on his heels a little, head bobbing like there's a song on
    s = math.sin(2 * math.pi * t)
    s2 = math.sin(4 * math.pi * t)
    pose = {"upper_arm.L": [(Y, 0.22 + 0.02 * s), (X, 0.12)], "upper_arm.R": [(Y, -0.22 - 0.02 * s), (X, 0.12)],
            "forearm.L": [(X, -0.55), (Y, -0.25)], "forearm.R": [(X, -0.55), (Y, 0.25)],
            "hand.L": [(X, -0.2)], "hand.R": [(X, -0.2)],
            "spine": [(X, -0.03 + 0.02 * s)], "chest": [(X, 0.015 * s)],
            "head": [(Y, 0.05 * math.sin(2 * math.pi * t + 1.2)), (X, -0.04 * s2), (Z, 0.06)],
            "thigh.L": [(X, 0.02 * s)], "thigh.R": [(X, 0.02 * s)]}
    return pose, 0.004 * s2


def walk(t):
    # A loose, easy-going walk: a bit of swagger in the shoulders
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    pose = {
        "thigh.L": [(X, -0.42 * s)], "thigh.R": [(X, 0.42 * s)],
        "shin.L": [(X, 0.12 + 0.45 * max(0.0, -c))], "shin.R": [(X, 0.12 + 0.45 * max(0.0, c))],
        "foot.L": [(X, -0.15 * s)], "foot.R": [(X, 0.15 * s)],
        "upper_arm.L": [(Y, 0.36), (X, 0.4 * s)], "upper_arm.R": [(Y, -0.36), (X, -0.4 * s)],
        "forearm.L": [(X, -0.45)], "forearm.R": [(X, -0.45)],
        "spine": [(X, 0.04)], "chest": [(Z, 0.09 * s)], "head": [(Z, -0.05 * s), (Y, 0.03 * s)],
    }
    return pose, 0.018 * abs(math.sin(ph))


def skate(t):
    # His riding stance, side-on to the board (the game turns him), lower and cockier than Nina's: knees well bent,
    # back arm loose, front arm out, looking where he's going
    s = math.sin(2 * math.pi * t)
    pose = {
        "thigh.L": [(X, -0.45)], "thigh.R": [(X, -0.45)],
        "shin.L": [(X, 0.8)], "shin.R": [(X, 0.8)],
        "foot.L": [(X, -0.35)], "foot.R": [(X, -0.35)],
        "spine": [(X, 0.18), (Y, 0.06 * s)], "chest": [(Y, 0.05 * s)],
        "upper_arm.L": [(Y, -0.45 + 0.1 * s)], "upper_arm.R": [(Y, 0.1 + 0.05 * s)],
        "forearm.L": [(X, -0.25)], "forearm.R": [(X, -0.6)],
        "head": [(Z, 1.05), (X, -0.1)],
    }
    return pose, -0.03 + 0.008 * s


def push(t):
    # Pushing along: his back foot kicks the ground while he leans over the board
    ph = 2 * math.pi * t
    s = math.sin(ph)
    pose = {
        "thigh.L": [(X, -0.35)], "shin.L": [(X, 0.75)], "foot.L": [(X, -0.3)],
        "thigh.R": [(X, -0.2 + 0.7 * s)], "shin.R": [(X, 0.35 + 0.25 * max(0.0, -s))],
        "spine": [(X, 0.25)], "chest": [(Y, 0.05 * s)],
        "upper_arm.L": [(Y, -0.35), (X, -0.3 * s)], "upper_arm.R": [(Y, 0.35), (X, 0.3 * s)],
        "forearm.L": [(X, -0.4)], "forearm.R": [(X, -0.4)],
        "head": [(Z, 1.0), (X, -0.1)],
    }
    return pose, -0.04 + 0.01 * abs(s)


def tough(t):
    # The Godfather bit (under stress): chin up, one hand waving slowly, very serious
    s = math.sin(2 * math.pi * t)
    pose = {"upper_arm.L": [(Y, 0.3)], "forearm.L": [(X, -0.5)],
            "upper_arm.R": [(Y, -0.9 - 0.12 * s), (X, -0.5)], "forearm.R": [(X, -0.9), (Z, 0.2 * s)],
            "hand.R": [(Y, 0.3 * s)],
            "spine": [(X, -0.06)], "chest": [(X, -0.04)], "head": [(X, 0.12), (Y, 0.08 * s)]}
    return pose, 0.0


make_action("idle", 60, bruno_idle)
make_action("walk", 30, walk)
make_action("run", 20, run)
make_action("jump", 10, jump)
make_action("fall", 24, fall)
make_action("skate", 40, skate)
make_action("push", 24, push)
make_action("tough", 60, tough)
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

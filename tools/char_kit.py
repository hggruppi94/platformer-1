# Shared building blocks for the character builders (build_cattle_girl.py, build_moth_kid.py,
# build_bike_boy.py, build_wolf.py). Same approach as build_nina.py: every shape is a plain number,
# every part remembers which bones it follows, and everything is joined into one skinned mesh with
# a simple rig and a few looping actions.
#
# Units are meters, feet at the origin, characters face -Y (Godot's model front after export).

import math
import random

import bpy  # before bmesh, so this also runs with the standalone bpy module
import bmesh
from mathutils import Euler, Matrix, Vector

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
MATS = {}
PARTS = []   # (object, bones) where bones = [name | (name, distance_scale)]


def begin():
    """Start from an empty scene (safe to call again to build a second model in one run)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
    PARTS.clear()
    bpy.context.scene.render.fps = 30


def ss(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# =============================================================================
# Materials
# =============================================================================
def mat(name, rgb, rough=0.55, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
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


def eye_materials(iris, iris_light):
    """The shared eye set: white, iris (two tones), pupil and sparkle."""
    mat("Eye White", (0.90, 0.90, 0.90), rough=0.08)
    mat("Iris", iris, rough=0.08)
    mat("Iris Light", iris_light, rough=0.08)
    mat("Pupil", (0.005, 0.004, 0.004), rough=0.05)
    mat("Eye Shine", (1.0, 1.0, 1.0), rough=0.05, emit=1.5)


# =============================================================================
# Geometry
# =============================================================================
def new_obj(name, bm, material, bones, recalc=True, smooth=True):
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(MATS[material])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    PARTS.append((ob, bones))
    return ob


def add_material(ob, material):
    """Append a material slot and return its index (for painting faces)."""
    ob.data.materials.append(MATS[material])
    return len(ob.data.materials) - 1


def paint(ob, material, test):
    """Give every face whose center passes test(center, normal) this material."""
    idx = add_material(ob, material)
    for p in ob.data.polygons:
        if test(p.center, p.normal):
            p.material_index = idx


def basis_facing(n):
    """Rotation whose local -Y points along n (so 'radii[1]' is the thickness along n)."""
    return n.to_track_quat('-Y', 'Z').to_matrix()


def as_rot(rot):
    if rot is None:
        return Matrix.Identity(3)
    return rot if isinstance(rot, Matrix) else Euler(rot).to_matrix()


def ellipsoid(name, center, radii, material, bones, rot=None, power=1.0, u=24, v=12, keep_below=None,
              keep_above=None):
    """UV sphere scaled to radii. power < 1 makes it boxier (superellipsoid).
    keep_below / keep_above: cut at this unit-space z and cap it (e.g. keep_above=0 is the top half)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for cut, normal in ((keep_below, (0, 0, 1)), (keep_above, (0, 0, -1))):
        if cut is not None:
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut),
                                   plane_no=normal, clear_outer=True)
            bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    R = as_rot(rot)
    for vt in bm.verts:
        c = vt.co
        if power != 1.0:
            c = Vector([math.copysign(abs(x) ** power, x) for x in c])
        vt.co = R @ Vector((c.x * radii[0], c.y * radii[1], c.z * radii[2])) + Vector(center)
    return new_obj(name, bm, material, bones)


def tube(name, pts, radii, material, bones, sides=16, normal_fn=None, caps=True):
    """Tube through pts. radii: per-point (side, normal) half-sizes. normal_fn(p) orients flat ribbons."""
    pts = [Vector(p) for p in pts]
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


def cylinder(name, a, b, r, material, bones, sides=16):
    """Straight flat-ended cylinder from a to b."""
    return tube(name, [a, b], [(r, r), (r, r)], material, bones, sides=sides)


def torus(name, center, major, minor, material, bones, u=32, v=12, rot=None):
    """Ring lying in the XY plane (rot turns it)."""
    R = as_rot(rot)
    bm = bmesh.new()
    rings = []
    for i in range(u):
        a = 2 * math.pi * i / u
        rings.append([bm.verts.new(Vector(center) + R @ Vector((math.cos(a) * (major + minor * math.cos(b)),
                                                                math.sin(a) * (major + minor * math.cos(b)),
                                                                minor * math.sin(b))))
                      for b in (2 * math.pi * j / v for j in range(v))])
    for i in range(u):
        for j in range(v):
            r0, r1 = rings[i], rings[(i + 1) % u]
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % v], r0[(j + 1) % v]))
    return new_obj(name, bm, material, bones)


def smooth_path(pts, per_segment=6):
    """Catmull-Rom through pts, for soft curves from a few control points."""
    pts = [Vector(p) for p in pts]
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(per_segment):
            t = k / per_segment
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(pts[-1])
    return out


def lock(name, ctrl, r0, material, bones, flat=0.55, tip=0.004, normal_fn=None, sides=10, taper=0.9):
    """A tapered hair lock / spike / tuft along smooth control points, rounded at the root, pointed at the tip.
    flat < 1 squashes it into a ribbon facing normal_fn."""
    pts = smooth_path(ctrl)
    n = len(pts)
    rad = []
    for i in range(n):
        t = i / (n - 1)
        r = tip + (r0 - tip) * (1 - t) ** taper
        if i == 0:
            r *= 0.75                                          # tuck the root in a little
        rad.append((r, r * flat))
    return tube(name, pts, rad, material, bones, sides=sides, normal_fn=normal_fn)


def star_prism(name, center, normal, r_out, r_in, depth, material, bones, spin=0.0, points=5):
    """A flat extruded star lying on a surface (front face along normal)."""
    R = basis_facing(normal)
    bm = bmesh.new()
    front, back = [], []
    for k in range(points * 2):
        a = math.pi / 2 + spin + k * math.pi / points
        r = r_out if k % 2 == 0 else r_in
        local = Vector((math.cos(a) * r, 0, math.sin(a) * r))
        front.append(bm.verts.new(Vector(center) + R @ (local + Vector((0, -depth / 2, 0)))))
        back.append(bm.verts.new(Vector(center) + R @ (local + Vector((0, depth / 2, 0)))))
    cf = bm.verts.new(Vector(center) + R @ Vector((0, -depth / 2, 0)))
    cb = bm.verts.new(Vector(center) + R @ Vector((0, depth / 2, 0)))
    m = len(front)
    for k in range(m):
        k2 = (k + 1) % m
        bm.faces.new((cf, front[k], front[k2]))
        bm.faces.new((cb, back[k2], back[k]))
        bm.faces.new((front[k], back[k], back[k2], front[k2]))
    return new_obj(name, bm, material, bones, smooth=False)


def text_mesh(name, text, center, size, normal, depth, material, bones):
    """Extruded text (e.g. a race number) standing on a surface facing along normal."""
    cu = bpy.data.curves.new(name, 'FONT')
    cu.body = text
    cu.size = size
    cu.extrude = depth / 2
    cu.align_x, cu.align_y = 'CENTER', 'CENTER'
    tmp = bpy.data.objects.new(name + " tmp", cu)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    R = basis_facing(Vector(normal)) @ Matrix.Rotation(math.radians(90), 3, 'X')   # text's +Z -> along -normal side
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    for vt in bm.verts:
        vt.co = Vector(center) + R @ vt.co
    return new_obj(name, bm, material, bones, smooth=False)


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

    def dir_point(self, d, offset=0.0):
        """Surface point in direction d from the center."""
        return self.project(self.c + Vector(d).normalized() * 10, offset)


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


# =============================================================================
# Faces
# =============================================================================
def cartoon_eye(side, ec, r, bones, look=(0.0, 0.0), lid=None):
    """Big glossy cartoon eye in the Nina style. ec: eye center, r: eye white radii.
    look: (x, z) shift of the iris. lid: material name for an upper lid (angry / sleepy looks)."""
    sx = 1 if side == "L" else -1
    lx, lz = look
    front = -r[1]
    ellipsoid(f"Eye.{side}", ec, r, "Eye White", bones)
    ir = (r[0] * 0.62, r[1] * 0.24, r[2] * 0.62)
    ic = ec + Vector((lx - 0.06 * r[0] * sx, front * 0.86, lz - 0.05 * r[2]))
    ellipsoid(f"Iris.{side}", ic, ir, "Iris", bones)
    ellipsoid(f"Iris Light.{side}", ic + Vector((0, -ir[1] * 0.6, -ir[2] * 0.25)),
              (ir[0] * 0.74, ir[1] * 0.5, ir[2] * 0.6), "Iris Light", bones)
    ellipsoid(f"Pupil.{side}", ic + Vector((0, -ir[1] * 0.95, 0.0)), (ir[0] * 0.52, ir[1] * 0.5, ir[2] * 0.54),
              "Pupil", bones)
    ellipsoid(f"Sparkle.{side}", ic + Vector((0.3 * ir[0], -ir[1] * 1.6, 0.42 * ir[2])),
              (ir[0] * 0.37, ir[1] * 0.4, ir[2] * 0.36), "Eye Shine", bones, u=16, v=8)
    ellipsoid(f"Sparkle Small.{side}", ic + Vector((-0.36 * ir[0], -ir[1] * 1.5, -0.46 * ir[2])),
              (ir[0] * 0.16, ir[1] * 0.3, ir[2] * 0.15), "Eye Shine", bones, u=12, v=6)
    if lid:
        # Upper lid: the top of a slightly larger shell, tilted so it comes down toward the nose (a scowl)
        tilt = Euler((0, math.radians(-24 * sx), 0)).to_matrix()
        ellipsoid(f"Lid.{side}", ec + Vector((0, -0.002, 0.004)), (r[0] * 1.08, r[1] * 1.12, r[2] * 1.08), lid, bones,
                  rot=tilt, keep_above=0.28)


def smile(name, face, cx, top_z, half_w, depth, bones, tongue=True, curl=0.012, offset=0.003):
    """Open D-shaped smile drawn on a face surface (an Ellipsoid or anything with front()/normal()).
    The top edge curls up at the corners, the bottom is round; a tongue sits in the bottom."""
    def top(x):
        u = (x - cx) / half_w
        return top_z + curl * u * u

    def bottom(x):
        u = (x - cx) / half_w
        return top(x) - depth * math.sqrt(max(0.0, 1 - u * u))
    cols = [cx + half_w * math.sin(math.pi * (j / 24 - 0.5)) for j in range(25)]
    surface_patch(name, face, [[(x, top(x) + (bottom(x) - top(x)) * i / 8) for x in cols] for i in range(9)],
                  offset, "Mouth", bones)
    if tongue:
        tw, th = half_w * 0.5, depth * 0.5
        tz = bottom(cx) + th * 1.05
        tc = [math.pi * (j / 12 - 0.5) for j in range(13)]
        surface_patch(name + " Tongue", face, [[(cx + tw * math.sin(a), tz - th * (i / 6) * math.cos(a)) for a in tc]
                                                for i in range(7)], offset + 0.0015, "Tongue", bones)
    return top, bottom


def arc_on(face, name, pts_xz, width, material, bones, offset=0.003):
    """A soft tapered stroke (brow, closed smile) drawn on a face surface through (x, z) points."""
    pts = [face.front(x, z, offset) for x, z in pts_xz]
    n = len(pts)
    rad = [(width * (0.35 + 0.65 * math.sin(math.pi * (i + 0.5) / n)), width * 0.6) for i in range(n)]
    return tube(name, pts, rad, material, bones, sides=8, normal_fn=face.normal)


def scalp_cap(name, head, material, bones, thick=0.022, hairline=None, u=64, v=32, bottom=None):
    """A shell over the head (head radii + thick) that leaves the face clear. hairline(x) gives the lowest z
    the hair reaches on the front of the face at that x; below it the shell is tucked just under the skin,
    so the hair edge is a soft curve instead of a stair-step of cut faces. bottom: tuck everything below this z
    too (short hair that stops above the neck)."""
    ob = ellipsoid(name, head.c, head.r + Vector((thick, thick, thick)), material, bones, u=u, v=v)
    if hairline or bottom is not None:
        hairline = hairline or (lambda x: -1e9)
        for vt in ob.data.vertices:
            c = vt.co
            front = ss(-0.15, -0.4, (c.y - head.c.y) / head.r.y)
            below = ss(-0.004, 0.03, hairline(c.x) - c.z)
            f = front * below
            if bottom is not None:
                f = max(f, ss(bottom + 0.015, bottom - 0.015, c.z))
            if f > 0:
                inner = head.c + (head.project(c) - head.c) * 0.9   # inside the head, hidden
                vt.co = c.lerp(inner, f)
    return ob


# =============================================================================
# Rig, skinning, join
# =============================================================================
def biped_bones(hips=0.50, chest=0.76, neck=0.90, head_top=1.45, shoulder=(0.235, 0, 0.80),
                elbow=(0.32, -0.03, 0.67), wrist=(0.39, -0.05, 0.56), hand_tip=(0.43, -0.065, 0.49),
                hip_x=0.12, knee=0.32, ankle=0.10, toe=(-0.14, 0.04)):
    """Kid-sized biped rig in the same layout as Nina's (same bone names, so code can share them)."""
    spine = hips + (chest - hips) * 0.46
    b = {
        "root": ((0, 0, 0), (0, 0, 0.25), None),
        "hips": ((0, 0, hips), (0, 0, spine), "root"),
        "spine": ((0, 0, spine), (0, 0, chest), "hips"),
        "chest": ((0, 0, chest), (0, 0, neck), "spine"),
        "head": ((0, 0, neck), (0, 0, head_top), "chest"),
    }
    for sx, side in ((1, "L"), (-1, "R")):
        m = lambda p: (p[0] * sx, p[1], p[2])
        b.update({
            f"upper_arm.{side}": (m(shoulder), m(elbow), "chest"),
            f"forearm.{side}": (m(elbow), m(wrist), f"upper_arm.{side}"),
            f"hand.{side}": (m(wrist), m(hand_tip), f"forearm.{side}"),
            f"thigh.{side}": ((hip_x * sx, 0, hips), (hip_x * sx, 0, knee), "hips"),
            f"shin.{side}": ((hip_x * sx, 0, knee), (hip_x * sx, 0, ankle), f"thigh.{side}"),
            f"foot.{side}": ((hip_x * sx, 0, ankle), (hip_x * sx, toe[0], toe[1]), f"shin.{side}"),
        })
    return b


def build_rig(name, bones):
    arm_data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for bname, (h, t, parent) in bones.items():
        eb = arm_data.edit_bones.new(bname)
        eb.head, eb.tail = h, t
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    return rig


def seg_dist(p, a, b):
    a, b = Vector(a), Vector(b)
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def skin_and_join(rig, bones, name, main_part):
    """Weight every part to its bones (inverse-distance blend), join into one mesh, bind to the rig."""
    for ob, bl in PARTS:
        spec = [(b, 1.0) if isinstance(b, str) else b for b in bl]
        groups = {n: ob.vertex_groups.new(name=n) for n, _ in spec}
        for v in ob.data.vertices:
            if len(spec) == 1:
                groups[spec[0][0]].add([v.index], 1.0, 'REPLACE')
                continue
            raw = {n: 1.0 / ((seg_dist(v.co, *bones[n][:2]) * s) ** 4 + 1e-9) for n, s in spec}
            total = sum(raw.values())
            w = {n: x / total for n, x in raw.items() if x / total > 0.02}
            total = sum(w.values())
            for n, x in w.items():
                groups[n].add([v.index], x / total, 'REPLACE')
    bpy.ops.object.select_all(action='DESELECT')
    for ob, _ in PARTS:
        ob.select_set(True)
    body = bpy.data.objects[main_part]
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = body.data.name = name
    body.parent = rig
    mod = body.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"MESH {name} parts={len(PARTS)} verts={len(body.data.vertices)} tris={tris} "
          f"materials={len(body.data.materials)}")
    return body


def join_static(name, main_part):
    """Join every part into one unrigged mesh (for props)."""
    bpy.ops.object.select_all(action='DESELECT')
    for ob, _ in PARTS:
        ob.select_set(True)
    body = bpy.data.objects[main_part]
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = body.data.name = name
    return body


# =============================================================================
# Posing and animation
#   Rotations are given about world axes in the rest pose (same convention as build_nina.py):
#   for a bone pointing down (legs, arms), -X swings it forward and +X swings it back;
#   for the spine, +X leans forward. Left arm: +Y lowers it, -Y raises it (right arm mirrored).
# =============================================================================
def rot(rots):
    R = Matrix.Identity(3)
    for axis, ang in rots:
        R = Matrix.Rotation(ang, 3, axis) @ R
    return R


class Pose:
    """One frame of a pose. rel() rotates a bone relative to its parent (world axes, like build_nina.py);
    aim()/ik() set a bone's absolute world rotation, so a hand or foot can be put exactly somewhere."""

    def __init__(self, bones):
        self.bones = bones
        self.spec = {}
        self.absr = {}
        self.offset = Vector((0, 0, 0))        # root (whole character) offset, in world meters

    def rel(self, bone, *rots):
        self.spec[bone] = list(rots)
        self.absr.pop(bone, None)
        return self

    def set_abs(self, bone, R):
        self.absr[bone] = R
        return self

    def abs(self, bone):
        if bone in self.absr:
            return self.absr[bone]
        parent = self.bones[bone][2]
        P = self.abs(parent) if parent else Matrix.Identity(3)
        R = P @ rot(self.spec.get(bone, []))
        self.absr[bone] = R
        return R

    def head(self, bone):
        """Posed world position of a bone's head."""
        h, _, parent = self.bones[bone]
        if not parent:
            return Vector(h) + self.offset
        ph = Vector(self.bones[parent][0])
        return self.head(parent) + self.abs(parent) @ (Vector(h) - ph)

    def aim(self, bone, direction):
        """Point a bone along a world direction (smallest turn from its rest direction)."""
        h, t, _ = self.bones[bone]
        rest = (Vector(t) - Vector(h)).normalized()
        self.absr[bone] = rest.rotation_difference(Vector(direction).normalized()).to_matrix()

    def ik(self, upper, lower, target, pole):
        """Two-bone IK: bend upper+lower so lower's tail reaches target, knee/elbow toward pole direction."""
        a = self.head(upper)
        L1 = (Vector(self.bones[upper][1]) - Vector(self.bones[upper][0])).length
        L2 = (Vector(self.bones[lower][1]) - Vector(self.bones[lower][0])).length
        d = Vector(target) - a
        dist = min(max(d.length, abs(L1 - L2) + 1e-3), (L1 + L2) * 0.999)
        dn = d.normalized()
        cos_a = (L1 * L1 + dist * dist - L2 * L2) / (2 * L1 * dist)
        pv = Vector(pole) - dn * Vector(pole).dot(dn)
        pv = pv.normalized() if pv.length > 1e-6 else Vector((0, -1, 0))
        knee = a + dn * cos_a * L1 + pv * math.sqrt(max(0.0, 1 - cos_a * cos_a)) * L1
        end = a + dn * dist
        self.aim(upper, knee - a)
        self.aim(lower, end - knee)


def make_action(rig, name, frames, pose_fn):
    """Bake pose_fn(t in 0..1) -> Pose into a looping action stored on its own (muted) NLA track."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    root = rig.pose.bones["root"]
    Mroot = root.bone.matrix_local.to_3x3()
    prev = {}
    for f in range(frames + 1):
        p = pose_fn(f / frames)
        for pb in rig.pose.bones:
            parent = p.bones[pb.name][2]
            P = p.abs(parent) if parent else Matrix.Identity(3)
            local = P.inverted() @ p.abs(pb.name)
            M = pb.bone.matrix_local.to_3x3()
            q = (M.inverted() @ local @ M).to_quaternion()
            if pb.name in prev and q.dot(prev[pb.name]) < 0:
                q.negate()                                       # keep spinning parts (wheels) from flipping
            prev[pb.name] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f)
        root.location = Mroot.inverted() @ p.offset
        root.keyframe_insert("location", frame=f)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    track.mute = True
    rig.animation_data.action = None


def ring_on(name, ell, z, offset, r, material, bones, sides=8, steps=48):
    """A closed band around an ellipsoid body at height z (hems, collars, belts)."""
    pts = []
    for k in range(steps + 1):
        a = 2 * math.pi * k / steps
        pts.append(_ring_point(ell, a, z, offset))
    return tube(name, pts, [(r, r)] * len(pts), material, bones, sides=sides, caps=False)


def _ring_point(ell, a, z, offset):
    k = math.sqrt(max(1 - ((z - ell.c.z) / ell.r.z) ** 2, 1e-4))
    s = Vector((ell.c.x + ell.r.x * k * math.cos(a), ell.c.y + ell.r.y * k * math.sin(a), z))
    return s + ell.normal(s) * offset


def rest_pose(rig):
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)


# Shared biped cycles (A-pose rest, arms ~33 degrees out). amount scales how big the motion is.
def arms_down(p, extra_l=(), extra_r=(), bend=0.3):
    p.rel("upper_arm.L", (Y, 0.38), *extra_l)
    p.rel("upper_arm.R", (Y, -0.38), *extra_r)
    p.rel("forearm.L", (X, -bend))
    p.rel("forearm.R", (X, -bend))


def biped_idle(bones, t, sway=1.0):
    s = math.sin(2 * math.pi * t)
    p = Pose(bones)
    arms_down(p, [(Y, 0.03 * s)], [(Y, -0.03 * s)])
    p.rel("spine", (X, 0.02 * s * sway))
    p.rel("chest", (X, 0.015 * s * sway))
    p.rel("head", (Y, 0.035 * math.sin(2 * math.pi * t + 1.2) * sway), (X, -0.02 * s))
    p.offset = Vector((0, 0, 0.006 * s))
    return p


def biped_walk(bones, t, stride=0.42, arm=0.35, bob=0.018):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(bones)
    p.rel("thigh.L", (X, -stride * s))
    p.rel("thigh.R", (X, stride * s))
    p.rel("shin.L", (X, 0.08 + 0.55 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.08 + 0.55 * max(0.0, c)))
    p.rel("foot.L", (X, -0.12 * s))
    p.rel("foot.R", (X, 0.12 * s))
    arms_down(p, [(X, arm * s)], [(X, -arm * s)], bend=0.35)
    p.rel("spine", (X, 0.04), (Z, 0.04 * s))
    p.rel("chest", (Z, 0.05 * s))
    p.rel("head", (Z, -0.06 * s), (X, -0.03))
    p.offset = Vector((0, 0, bob * abs(math.sin(ph))))
    return p


def biped_run(bones, t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(bones)
    p.rel("thigh.L", (X, -0.65 * s))
    p.rel("thigh.R", (X, 0.65 * s))
    p.rel("shin.L", (X, 0.25 + 0.75 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.25 + 0.75 * max(0.0, c)))
    p.rel("foot.L", (X, -0.2 * s))
    p.rel("foot.R", (X, 0.2 * s))
    p.rel("upper_arm.L", (Y, 0.3), (X, 0.7 * s))
    p.rel("upper_arm.R", (Y, -0.3), (X, -0.7 * s))
    p.rel("forearm.L", (X, -1.0))
    p.rel("forearm.R", (X, -1.0))
    p.rel("spine", (X, 0.14))
    p.rel("chest", (Z, 0.1 * s))
    p.rel("head", (X, -0.1), (Z, -0.06 * s))
    p.offset = Vector((0, 0, 0.035 * abs(math.sin(ph))))
    return p


# =============================================================================
# Saving
# =============================================================================
def finish(path, frame_end=60):
    """Camera + light for quick renders, then save."""
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 0, frame_end
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0, -4.5, 0.9)
    cam.rotation_euler = (math.radians(88), 0, 0)
    sun = bpy.data.objects.new("Light", bpy.data.lights.new("Light", 'SUN'))
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print("SAVED", path)


def rng(seed):
    return random.Random(seed)

# Nina from TripoSR (its own vertex colours), with our own cartoon eyes (Hayden, Nov 26 2026: "we are going to use
# tripoSR for everything. I just need you to fix her eyes to look more cartoony and cute").
#   blender -b --python nina_triposr.py -- <triposr glb> <out dir>
# 1. stood up, facing the front (-Y), 1.45 m tall, cut down to a game-friendly count
# 2. her colours a little richer (TripoSR's come out washed out)
# 3. the eye area smoothed flat and painted skin, then big glossy cartoon eyes put on (named materials EyeWhite, Iris,
#    Pupil, Highlight, Lash), placed where Sofi's picture has them
import bpy, bmesh, sys, math
import numpy as np
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
PIC = "C:/Users/hggru/Game_dev/ai3d/concept/nina_main_input.png"
# Sofi's picture: the eyes' middles and sizes (pixels), and the character's outline box in it
EYES = [(668, 492, 58, 66), (885, 505, 78, 74)]
BOX = (482, 81, 1313, 1717)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ms = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in ms:
    o.select_set(True)
bpy.context.view_layer.objects.active = ms[0]
if len(ms) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.parent = None
# TripoSR lies her on her side facing +X: stand her up and turn her to the front
ob.matrix_world = Matrix.Rotation(math.radians(-90), 4, "Z") @ Matrix.Rotation(math.radians(-90), 4, "X") @ ob.matrix_world
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
ob.name = ob.data.name = "Nina"
me = ob.data
vs = [v.co for v in me.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
k = 1.45 / (hi.z - lo.z)
for v in me.vertices:
    v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * k, (v.co.y - (lo.y + hi.y) / 2) * k, (v.co.z - lo.z) * k))
# a game-friendly count (the friends are 45k to 100k)
t = len(me.polygons)
if t > 60000:
    d = ob.modifiers.new("D", "DECIMATE")
    d.ratio = 60000 / t
    bpy.ops.object.modifier_apply(modifier="D")
me = ob.data
for p in me.polygons:
    p.use_smooth = True
ca = me.color_attributes[0]
me.color_attributes.active_color = ca
if ca.domain != "POINT":
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.geometry.color_attribute_convert(domain="POINT", data_type="FLOAT_COLOR")
    ca = me.color_attributes.active_color
print("NINA tris", len(me.polygons), "colours", ca.name, ca.domain, ca.data_type)

# ------------------------------------------------------------------ richer colours
def cols():
    return np.array([c.color[:] for c in ca.data], dtype=np.float32)

def put(c):
    for i, x in enumerate(c):
        ca.data[i].color = tuple(float(y) for y in x)

c = cols()
rgb = c[:, :3]
grey = rgb.mean(axis=1, keepdims=True)
rgb = grey + (rgb - grey) * 1.45                      # more saturation
rgb = (rgb - 0.5) * 1.15 + 0.5 - 0.03                 # a touch more contrast, a touch darker
rgb = np.clip(rgb, 0, 1) ** 1.35                      # deeper (TripoSR's skin comes out nearly white)
c[:, :3] = np.clip(rgb, 0, 1)
put(c)

# ------------------------------------------------------------------ where the eyes go
xs = [v.co.x for v in me.vertices]
zs = [v.co.z for v in me.vertices]
mx0, mx1, mz0, mz1 = min(xs), max(xs), min(zs), max(zs)
bx0, by0, bx1, by1 = BOX

def to_mesh(px, py):
    return (mx0 + (px - bx0) / (bx1 - bx0) * (mx1 - mx0), mz0 + (by1 - py) / (by1 - by0) * (mz1 - mz0))

def surf(x, z):
    hit = ob.ray_cast(Vector((x, -5, z)), Vector((0, 1, 0)))
    return (hit[1], hit[2]) if hit[0] else (None, None)

spots = []
mid = sum(to_mesh(px, py)[0] for px, py, rx, ry in EYES) / len(EYES)
for px, py, rx, ry in EYES:
    x, z = to_mesh(px, py)
    # set a little wider and lower than the picture's (Hayden: cute, cartoony)
    x = mid + (x - mid) * 1.18
    z -= 0.45 * ry / (BOX[3] - BOX[1]) * (max(zs) - min(zs))
    sx = rx / (bx1 - bx0) * (mx1 - mx0)
    sz = ry / (by1 - by0) * (mz1 - mz0)
    loc, n = surf(x, z)
    spots.append((Vector((x, 0, z)), sx, sz, loc, n))
    print("NINA eye at", x, z, "size", sx, sz, "surface", loc)

# ------------------------------------------------------------------ flatten and repaint the old eye area
bm = bmesh.new()
bm.from_mesh(me)
bm.verts.ensure_lookup_table()
layer = bm.verts.layers.float_color[ca.name] if ca.domain == "POINT" else None
front = [v for v in bm.verts if v.normal.y < -0.2]
for centre, sx, sz, loc, n in spots:
    if loc is None:
        continue
    r = 1.35 * max(sx, sz)
    inside = [v for v in front if (v.co - loc).length < r]
    ring = [v for v in front if r < (v.co - loc).length < 1.8 * r and v.co.z < loc.z - 0.3 * r]   # below: not the hair
    # smooth the bumps out
    ids = {v.index for v in inside}
    for _ in range(25):
        new = {}
        for v in inside:
            nb = [e.other_vert(v).co for e in v.link_edges]
            new[v.index] = v.co * 0.4 + (sum(nb, Vector()) / len(nb)) * 0.6
        for v in inside:
            v.co = new[v.index]
    # paint it the skin round it (the middle colour of the ring, so the eye's old dark paint goes)
    if layer is not None and ring:
        rc = np.array([list(v[layer]) for v in ring])
        skin = np.median(rc, axis=0)
        for v in inside:
            d = (v.co - loc).length / r
            w = 1.0 if d < 0.85 else (1 - d) / 0.15
            v[layer] = tuple(float(x) for x in (np.array(list(v[layer])) * (1 - w) + skin * w))
bm.to_mesh(me)
bm.free()
if ca.domain != "POINT":
    print("NINA warning: colours are per corner; eye area not repainted")

# ------------------------------------------------------------------ materials
def lin(c):
    return tuple((x / 255) ** 2.2 for x in c)

def mat(name, srgb, rough=0.5, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(srgb), 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(srgb), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m

body = bpy.data.materials.new("Body")
body.use_nodes = True
vc = body.node_tree.nodes.new("ShaderNodeVertexColor")
vc.layer_name = ca.name
bb = body.node_tree.nodes["Principled BSDF"]
bb.inputs["Roughness"].default_value = 0.7
body.node_tree.links.new(vc.outputs["Color"], bb.inputs["Base Color"])
me.materials.clear()
me.materials.append(body)
M = {"EyeWhite": mat("EyeWhite", (250, 250, 252), 0.2), "Iris": mat("Iris", (150, 78, 30), 0.15),
     "IrisLight": mat("Iris", (196, 120, 56), 0.15), "Pupil": mat("Pupil", (12, 8, 8), 0.1),
     "Highlight": mat("Highlight", (255, 255, 255), 0.05, emit=0.6), "Lash": mat("Lash", (22, 14, 12), 0.5)}
M["IrisLight"].name = "Iris Light"

# ------------------------------------------------------------------ the eyes
parts = []

def piece(name, verts_fn, material):
    bm2 = bmesh.new()
    verts_fn(bm2)
    m2 = bpy.data.meshes.new(name)
    bm2.to_mesh(m2)
    bm2.free()
    o = bpy.data.objects.new(name, m2)
    bpy.context.scene.collection.objects.link(o)
    m2.materials.append(material)
    for p in m2.polygons:
        p.use_smooth = True
    parts.append(o)
    return o

def dome(bm2, c, R, rx, rz, depth, lift=0.0):
    """A shallow dome on the face: an ellipse rx x rz across, bulging depth out of the surface."""
    bmesh.ops.create_uvsphere(bm2, u_segments=32, v_segments=16, radius=1)
    for v in bm2.verts:
        y = v.co.y
        v.co = c + R @ Vector((v.co.x * rx, min(y, 0) * depth - lift + max(y, 0) * depth * 0.2, v.co.z * rz))

def frame(n):
    # columns: x along the face (across), y out of the face (towards the viewer is -y), z up
    out = -n.normalized()
    x = Vector((0, 0, 1)).cross(out).normalized()
    z = out.cross(x).normalized()
    return Matrix((x, out, z)).transposed()

for i, (centre, sx, sz, loc, n) in enumerate(spots):
    if loc is None:
        continue
    side = "L" if i == 0 else "R"
    # sit the eye on the (now flat) surface, facing out a little more forwards than the face does
    loc2, n2 = surf(centre.x, centre.z)
    n2 = (n2.normalized() * 0.6 + Vector((0, -1, 0)) * 0.4).normalized()
    R = frame(n2)
    rx, rz = 1.08 * sx, 1.0 * sz
    base = loc2 + n2 * (0.15 * rx)
    out = R @ Vector((0, -1, 0))
    piece(f"EyeWhite.{side}", lambda b: dome(b, base, R, rx, rz, 0.45 * rx), M["EyeWhite"])
    ic = base + out * (0.36 * rx) + R @ Vector((0.04 * rx * (1 if i == 0 else -1), 0, -0.06 * rz))
    piece(f"Iris.{side}", lambda b: dome(b, ic, R, 0.74 * rx, 0.8 * rz, 0.14 * rx), M["Iris"])
    piece(f"IrisLight.{side}", lambda b: dome(b, ic + out * 0.012 * rx + R @ Vector((0, 0, -0.22 * rz)), R,
                                              0.5 * rx, 0.4 * rz, 0.1 * rx), M["IrisLight"])
    piece(f"Pupil.{side}", lambda b: dome(b, ic + out * (0.05 * rx), R, 0.44 * rx, 0.5 * rz, 0.1 * rx), M["Pupil"])
    piece(f"Highlight.{side}", lambda b: dome(b, ic + out * (0.11 * rx) + R @ Vector((0.28 * rx, 0, 0.3 * rz)), R,
                                              0.2 * rx, 0.22 * rz, 0.06 * rx), M["Highlight"])
    piece(f"HighlightSmall.{side}", lambda b: dome(b, ic + out * (0.11 * rx) + R @ Vector((-0.26 * rx, 0, -0.28 * rz)),
                                                   R, 0.09 * rx, 0.1 * rz, 0.04 * rx), M["Highlight"])
    # the upper lid line: a thin dark arc over the top of the eye, and three curled lashes at the outer corner
    s = 1 if i == 0 else -1    # outer corner: the left eye's outer side is -x in the picture, the right eye's +x
    outer = -1 if i == 0 else 1

    def lid(b, base=base, R=R, rx=rx, rz=rz):
        pts = []
        for j in range(25):
            t = math.pi * (0.05 + 0.9 * j / 24)
            pts.append(base + R @ Vector((math.cos(t) * rx * 1.02, -0.3 * rx * math.sin(t) - 0.12 * rx, math.sin(t) * rz * 1.02)))
        rings = []
        for j, p in enumerate(pts):
            w = 0.05 * rz * (0.5 + 0.8 * math.sin(math.pi * j / 24))
            ring = [b.verts.new(p + R @ Vector((0, math.cos(q) * w * 0.6, math.sin(q) * w)))
                    for q in [2 * math.pi * m / 6 for m in range(6)]]
            rings.append(ring)
        for r1, r2 in zip(rings, rings[1:]):
            for m in range(6):
                b.faces.new([r1[m], r1[(m + 1) % 6], r2[(m + 1) % 6], r2[m]])
    piece(f"Lid.{side}", lid, M["Lash"])
    for j in range(3):
        def lash(b, j=j, base=base, R=R, rx=rx, rz=rz):
            t = math.pi * (0.5 + outer * (0.28 + 0.13 * j))
            root = base + R @ Vector((math.cos(t) * rx, -0.3 * rx * math.sin(t) - 0.12 * rx, math.sin(t) * rz))
            dirv = R @ Vector((math.cos(t) * 0.8 + outer * 0.5, -0.4, math.sin(t) * 0.7 + 0.3)).normalized()
            pts = [root + dirv * (0.28 * rz * q) + R @ Vector((0, 0, 0.06 * rz * q * q)) for q in (0, 0.33, 0.66, 1.0)]
            rings = []
            for q, p in enumerate(pts):
                w = 0.07 * rz * (1 - q / 3.6)
                rings.append([b.verts.new(p + R @ Vector((math.cos(u) * w, math.sin(u) * w * 0.5, 0)))
                              for u in [2 * math.pi * m / 5 for m in range(5)]])
            for r1, r2 in zip(rings, rings[1:]):
                for m in range(5):
                    b.faces.new([r1[m], r1[(m + 1) % 5], r2[(m + 1) % 5], r2[m]])
        piece(f"Lash.{side}{j}", lash, M["Lash"])

# everything joined into one mesh (eyes keep their own materials)
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.join()
bpy.ops.wm.save_as_mainfile(filepath=OUT + "/nina_triposr.blend")
bpy.ops.export_scene.gltf(filepath=OUT + "/nina_triposr.glb", export_format="GLB", export_vertex_color="ACTIVE")
print("NINA done", [m.name for m in ob.data.materials])

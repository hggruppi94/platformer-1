# Nina v3: TripoSR's shape, coloured with clean flat named parts, and our own face, hair finish and bow.
#   blender -b --python nina_v3.py -- <triposr glb> <front picture> <spots json> <out dir>
# spots json (pixels in the picture): {"box": [x0, y0, x1, y1], "eyes": [[x, y, rx, ry], ...], "mouth": [x, y, w, h],
#   "bow": [x, y]}
import bpy, bmesh, sys, math, json
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

a = sys.argv[sys.argv.index("--") + 1:]
SRC, PIC, SPOTS, OUT = a[0], a[1], a[2], a[3]
S = json.load(open(SPOTS))
BOX = S["box"]

# ------------------------------------------------------------------ the shape
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
ob.parent = None
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
if me.has_custom_normals:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
d = ob.modifiers.new("D", "DECIMATE"); d.ratio = min(1.0, 70000 / len(me.polygons))
bpy.ops.object.modifier_apply(modifier="D")
me = ob.data
ca = me.color_attributes[0]
me.color_attributes.active_color = ca
if ca.domain != "POINT":
    bpy.ops.geometry.color_attribute_convert(domain="POINT", data_type="FLOAT_COLOR")
ca = me.color_attributes.active_color
cols = np.array([c.color[:3] for c in ca.data], dtype=np.float32)
cols = np.clip(cols, 0, 1)                  # TripoSR's colours are screen colours (sRGB)
P = np.array([v.co[:] for v in me.vertices], dtype=np.float32)
xs, zs = P[:, 0], P[:, 2]
mx0, mx1, mz0, mz1 = xs.min(), xs.max(), zs.min(), zs.max()
print("V3 tris", len(me.polygons), flush=True)


def to_mesh(px, py):
    return (mx0 + (px - BOX[0]) / (BOX[2] - BOX[0]) * (mx1 - mx0), mz0 + (BOX[3] - py) / (BOX[3] - BOX[1]) * (mz1 - mz0))


def size_x(px):
    return px / (BOX[2] - BOX[0]) * (mx1 - mx0)


def size_z(py):
    return py / (BOX[3] - BOX[1]) * (mz1 - mz0)


# ------------------------------------------------------------------ named parts, flat colours
# Each face is the named part whose colour is nearest TripoSR's colour there, only where that part can be (shoes at
# the feet, the tee on her upper body...). Then the borders are smoothed and specks removed, so each part is one
# clean patch, and its colour is the part's own flat colour (the game recolours it by name).
PARTS = {   # sRGB, where (z range in metres), roughness
    "Skin": ((150, 140, 142), (0.0, 1.5), 0.7),
    "Ear Inner": ((214, 160, 168), (1.25, 1.5), 0.7),
    "Hair": ((214, 28, 20), (0.55, 1.5), 0.35),
    "Shirt": ((246, 244, 244), (0.55, 0.95), 0.8),
    "Overalls": ((240, 168, 192), (0.1, 0.9), 0.8),
    "Straps": ((240, 206, 60), (0.45, 0.95), 0.6),
    "Shoes": ((236, 128, 168), (0.0, 0.13), 0.6),
    "Soles": ((248, 244, 240), (0.0, 0.04), 0.6),
}
names = list(PARTS)
pal = np.array([PARTS[n][0] for n in names], dtype=np.float32) / 255


def lab(c):
    # a rough perceptual space: lightness and two colour axes, colour weighted more (shading changes lightness)
    l = c.mean(axis=-1)
    return np.stack([l * 0.6, (c[..., 0] - c[..., 1]) * 1.4, (c[..., 1] - c[..., 2]) * 1.4,
                     (c[..., 0] - c[..., 2]) * 1.0], axis=-1)


bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table(); bm.verts.ensure_lookup_table()
fc = np.array([cols[[v.index for v in f.verts]].mean(axis=0) for f in bm.faces])
fz = np.array([f.calc_center_median().z for f in bm.faces])
fx = np.array([f.calc_center_median().x for f in bm.faces])
# where the front can see her, the part is read from the picture (it's clean); elsewhere from TripoSR's colours
pic_img = bpy.data.images.load(PIC)
PW, PH = pic_img.size
pic = np.array(pic_img.pixels[:], dtype=np.float32).reshape(PH, PW, 4)[::-1, :, :3]
tree0 = BVHTree.FromBMesh(bm)
far = float(P[:, 1].min()) - 1
for f in bm.faces:
    if f.normal.y > -0.3:
        continue
    cpos = f.calc_center_median()
    hit = tree0.ray_cast(Vector((cpos.x, far, cpos.z)), Vector((0, 1, 0)))
    if hit[2] != f.index:
        continue
    u = int(np.clip(BOX[0] + (cpos.x - mx0) / (mx1 - mx0) * (BOX[2] - BOX[0]), 0, PW - 1))
    r = int(np.clip(BOX[3] - (cpos.z - mz0) / (mz1 - mz0) * (BOX[3] - BOX[1]), 0, PH - 1))
    fc[f.index] = pic[r, u]
L = lab(fc)
d = np.stack([np.linalg.norm(L - lab(pal[i]), axis=1) for i in range(len(names))], axis=1)
for i, n in enumerate(names):
    z0, z1 = PARTS[n][1]
    d[(fz < z0) | (fz > z1), i] = 9
d[np.abs(fx) < 0.14, names.index("Ear Inner")] = 9      # the ears are out at the sides
lab_idx = d.argmin(axis=1)
# her feet are shoes (TripoSR's grey there is shadow), white soles only right at the bottom
lab_idx[fz < 0.1] = names.index("Shoes")
lab_idx[(fz < 0.022) & (fc.mean(axis=1) > 0.75)] = names.index("Soles")
for f, i in zip(bm.faces, lab_idx):
    f.material_index = int(i)


def majority(bm, passes, protect=()):
    for _ in range(passes):
        new = []
        for f in bm.faces:
            cnt = {}
            for e in f.edges:
                for g in e.link_faces:
                    cnt[g.material_index] = cnt.get(g.material_index, 0) + 1
            best = max(cnt, key=cnt.get)
            new.append(f.material_index if f.material_index in protect and cnt.get(f.material_index, 0) >= 2 else best)
        for f, m in zip(bm.faces, new):
            f.material_index = m


def islands(bm, small):
    seen = set()
    for f in bm.faces:
        if f.index in seen:
            continue
        isl, st = [], [f]; seen.add(f.index)
        while st:
            g = st.pop(); isl.append(g)
            for e in g.edges:
                for q in e.link_faces:
                    if q.index not in seen and q.material_index == f.material_index:
                        seen.add(q.index); st.append(q)
        if len(isl) < small:
            ring = {}
            for g in isl:
                for e in g.edges:
                    for q in e.link_faces:
                        if q.material_index != f.material_index:
                            ring[q.material_index] = ring.get(q.material_index, 0) + 1
            if ring:
                m = max(ring, key=ring.get)
                for g in isl:
                    g.material_index = m


majority(bm, 6, protect=(names.index("Straps"), names.index("Ear Inner")))
islands(bm, max(60, len(bm.faces) // 300))
majority(bm, 2)
# straighten the borders (each face is one part, so a border zigzags along the triangles)
surf = BVHTree.FromBMesh(bm)
border = {}
for e in bm.edges:
    if len(e.link_faces) == 2 and e.link_faces[0].material_index != e.link_faces[1].material_index:
        for v in e.verts:
            border.setdefault(v.index, []).append(e.other_vert(v).index)
simple = {i: n for i, n in border.items() if len(n) == 2}
for _ in range(10):
    mv = {i: bm.verts[i].co * 0.5 + (bm.verts[n[0]].co + bm.verts[n[1]].co) * 0.25 for i, n in simple.items()}
    for i, c in mv.items():
        h = surf.find_nearest(c)
        bm.verts[i].co = h[0] if h[0] is not None else c
# her hair: smoothed into glossy shapes (TripoSR leaves it lumpy)
hair_i = names.index("Hair")
hv = {v for f in bm.faces if f.material_index == hair_i for v in f.verts}
for _ in range(12):
    new = {}
    for v in hv:
        nb = [e.other_vert(v).co for e in v.link_edges]
        new[v] = v.co * 0.5 + (sum(nb, Vector()) / len(nb)) * 0.5
    for v, c in new.items():
        v.co = c
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
counts = {n: 0 for n in names}
for p in me.polygons:
    counts[names[p.material_index]] += 1
print("V3 parts", counts, flush=True)


def lin(c):
    return tuple((x / 255) ** 2.2 for x in c)


def mat(name, srgb, rough=0.6, emit=0.0, ao=False):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(srgb), 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(srgb), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


keep_idx = [p.material_index for p in me.polygons]
me.materials.clear()                    # (this resets every face's part, so they're put back after)
for n in names:
    me.materials.append(mat(n, PARTS[n][0], PARTS[n][2]))
for p, i in zip(me.polygons, keep_idx):
    p.material_index = i

# ------------------------------------------------------------------ the face and the bow, made by hand
def surf_hit(x, z):
    h = ob.ray_cast(Vector((x, -5, z)), Vector((0, 1, 0)))
    return (h[1], h[2]) if h[0] else (None, None)


parts = []


def piece(name, fn, material):
    bm2 = bmesh.new(); fn(bm2)
    m2 = bpy.data.meshes.new(name); bm2.to_mesh(m2); bm2.free()
    o = bpy.data.objects.new(name, m2); bpy.context.scene.collection.objects.link(o)
    m2.materials.append(material)
    for p in m2.polygons:
        p.use_smooth = True
    parts.append(o)


def dome(bm2, c, R, rx, rz, depth, segs=32):
    bmesh.ops.create_uvsphere(bm2, u_segments=segs, v_segments=segs // 2, radius=1)
    for v in bm2.verts:
        y = v.co.y
        v.co = c + R @ Vector((v.co.x * rx, min(y, 0) * depth + max(y, 0) * depth * 0.2, v.co.z * rz))


def frame(n):
    out = -n.normalized()
    x = Vector((0, 0, 1)).cross(out).normalized()
    z = out.cross(x).normalized()
    return Matrix((x, out, z)).transposed()


M = {"Eye White": mat("Eye White", (250, 250, 252), 0.2), "Iris": mat("Iris", (140, 74, 30), 0.15),
     "Pupil": mat("Pupil", (12, 8, 8), 0.1), "Highlight": mat("Highlight", (255, 255, 255), 0.05, emit=0.6),
     "Lash": mat("Lash", (34, 22, 18), 0.5), "Brow": mat("Brow", (70, 44, 34), 0.7),
     "Nostril": mat("Nostril", (52, 38, 38), 0.6), "Mouth": mat("Mouth", (92, 22, 34), 0.5),
     "Tongue": mat("Tongue", (232, 110, 120), 0.4), "Teeth": mat("Teeth", (252, 250, 244), 0.25),
     "Blush": mat("Blush", (232, 150, 160), 0.8), "Bow": mat("Bow", (214, 14, 22), 0.25)}

def flatten(x, z, r, iters=25):
    """Smooths TripoSR's own bumps out of the face here (its moulded eyes and nostril holes), before ours go on."""
    loc, n = surf_hit(x, z)
    if loc is None:
        return
    bm3 = bmesh.new(); bm3.from_mesh(ob.data); bm3.verts.ensure_lookup_table(); bm3.normal_update()
    inside = [v for v in bm3.verts if v.normal.y < -0.1 and (v.co - loc).length < r]
    for _ in range(iters):
        new = {}
        for v in inside:
            nb = [e.other_vert(v).co for e in v.link_edges]
            new[v.index] = v.co * 0.35 + (sum(nb, Vector()) / len(nb)) * 0.65
        for v in inside:
            v.co = new[v.index]
    bm3.to_mesh(ob.data); bm3.free()
    ob.data.update()


for (px, py, rpx, rpy) in S["eyes"]:
    x, z = to_mesh(px, py)
    flatten(x, z, 1.35 * max(size_x(rpx), size_z(rpy)))
for (px, py) in S.get("nostrils", []):
    x, z = to_mesh(px, py)
    flatten(x, z, 0.035, 20)

# the eyes: set into the face where the picture has them
eyes = []
for i, (px, py, rpx, rpy) in enumerate(S["eyes"]):
    x, z = to_mesh(px, py)
    loc, n = surf_hit(x, z)
    if loc is None:
        continue
    rx, rz = size_x(rpx) * 1.05, size_z(rpy)
    n2 = (n.normalized() * 0.6 + Vector((0, -1, 0)) * 0.4).normalized()
    R = frame(n2)
    out = R @ Vector((0, -1, 0))
    base = loc - n2 * (0.06 * rx)
    sgn = 1 if i == 0 else -1
    piece(f"EyeWhite.{i}", lambda b: dome(b, base, R, rx, rz, 0.3 * rx), M["Eye White"])
    ic = base + out * (0.24 * rx) + R @ Vector((0.04 * rx * sgn, 0, -0.04 * rz))
    piece(f"Iris.{i}", lambda b: dome(b, ic, R, 0.76 * rx, 0.82 * rz, 0.14 * rx), M["Iris"])
    piece(f"Pupil.{i}", lambda b: dome(b, ic + out * 0.05 * rx, R, 0.44 * rx, 0.5 * rz, 0.1 * rx), M["Pupil"])
    piece(f"Shine.{i}", lambda b: dome(b, ic + out * 0.11 * rx + R @ Vector((0.28 * rx, 0, 0.3 * rz)), R, 0.21 * rx,
                                       0.23 * rz, 0.06 * rx), M["Highlight"])
    piece(f"ShineSmall.{i}", lambda b: dome(b, ic + out * 0.11 * rx + R @ Vector((-0.26 * rx, 0, -0.28 * rz)), R,
                                            0.09 * rx, 0.1 * rz, 0.04 * rx), M["Highlight"])
    # upper lid line and three lashes at the outer corner
    outer = -1 if i == 0 else 1

    def lid(b, base=base, R=R, rx=rx, rz=rz):
        rings = []
        for j in range(25):
            t = math.pi * (0.05 + 0.9 * j / 24)
            p = base + R @ Vector((math.cos(t) * rx * 1.02, -0.22 * rx * math.sin(t) - 0.08 * rx, math.sin(t) * rz * 1.02))
            w = 0.05 * rz * (0.5 + 0.8 * math.sin(math.pi * j / 24))
            rings.append([b.verts.new(p + R @ Vector((0, math.cos(q) * w * 0.6, math.sin(q) * w)))
                          for q in [2 * math.pi * m / 6 for m in range(6)]])
        for r1, r2 in zip(rings, rings[1:]):
            for m in range(6):
                b.faces.new([r1[m], r1[(m + 1) % 6], r2[(m + 1) % 6], r2[m]])
    piece(f"Lid.{i}", lid, M["Lash"])
    for j in range(3):
        def lash(b, j=j, base=base, R=R, rx=rx, rz=rz, outer=outer):
            t = math.pi * (0.5 + outer * (0.28 + 0.13 * j))
            root = base + R @ Vector((math.cos(t) * rx, -0.22 * rx * math.sin(t) - 0.08 * rx, math.sin(t) * rz))
            dv = R @ Vector((math.cos(t) * 0.8 + outer * 0.5, -0.4, math.sin(t) * 0.7 + 0.3)).normalized()
            rings = []
            for q in range(4):
                p = root + dv * (0.28 * rz * q / 3) + R @ Vector((0, 0, 0.06 * rz * (q / 3) ** 2))
                w = 0.07 * rz * (1 - q / 3.6)
                rings.append([b.verts.new(p + R @ Vector((math.cos(u) * w, math.sin(u) * w * 0.5, 0)))
                              for u in [2 * math.pi * m / 5 for m in range(5)]])
            for r1, r2 in zip(rings, rings[1:]):
                for m in range(5):
                    b.faces.new([r1[m], r1[(m + 1) % 5], r2[(m + 1) % 5], r2[m]])
        piece(f"Lash.{i}{j}", lash, M["Lash"])
    # a soft arched brow above, and a blush below and outside
    bl, bn = surf_hit(x, z + 1.25 * rz)
    if bl is not None:
        piece(f"Brow.{i}", lambda b, bl=bl, bn=bn: dome(b, bl + bn * 0.002, frame(bn), 0.85 * rx, 0.12 * rz, 0.01),
              M["Brow"])
    cl, cn = surf_hit(x - sgn * 0.9 * rx, z - 1.3 * rz)
    if cl is not None:
        piece(f"Blush.{i}", lambda b, cl=cl, cn=cn: dome(b, cl - cn * 0.002, frame(cn), 0.75 * rx, 0.45 * rz, 0.008),
              M["Blush"])
    eyes.append((x, z, rx, rz))

# nostrils: two small dots high on the snout, between the eyes and the mouth, like Sofi's
mxp, myp, mw, mh = S["mouth"]
mouth_x, mouth_z = to_mesh(mxp, myp)
ex = sum(e[0] for e in eyes) / max(len(eyes), 1)
ez = sum(e[1] for e in eyes) / max(len(eyes), 1)
gap = abs(eyes[1][0] - eyes[0][0]) if len(eyes) == 2 else 0.2
for (px, py) in S.get("nostrils", []):
    x, z = to_mesh(px, py)
    loc, n = surf_hit(x, z)
    if loc is not None:
        piece(f"Nostril.{px}", lambda b, loc=loc, n=n: dome(b, loc + n * 0.001, frame(n), 0.014, 0.01, 0.003),
              M["Nostril"])

# the mouth: an open smile (a dark D shape, top edge curling up at the corners), a tongue in it, two buck teeth at the
# top in the middle
loc, n = surf_hit(mouth_x, mouth_z)
if loc is not None:
    R = frame((n.normalized() + Vector((0, -1, 0))).normalized())
    hw, hh = size_x(mw) / 2 * 0.85, size_z(mh) / 2 * 1.25
    out = R @ Vector((0, -1, 0))

    def mouth(b):
        top, bottom = [], []
        for j in range(17):
            u = -1 + 2 * j / 16
            top.append(Vector((u * hw, 0, hh * 0.35 + 0.25 * hh * u * u)))
        for j in range(17):
            u = 1 - 2 * j / 16
            bottom.append(Vector((u * hw * 0.92, 0, hh * 0.35 - hh * 1.3 * math.cos(u * math.pi / 2) ** 0.8)))
        pts = top + bottom
        ring = [b.verts.new(loc + R @ p + out * 0.004) for p in pts]
        mid = b.verts.new(loc + R @ Vector((0, 0.0, -hh * 0.2)) + out * 0.002)
        for j in range(len(ring)):
            b.faces.new([ring[j], ring[(j + 1) % len(ring)], mid])
    piece("Mouth", mouth, M["Mouth"])
    piece("Tongue", lambda b: dome(b, loc + R @ Vector((0, 0, -hh * 0.55)) + out * 0.005, R, hw * 0.42, hh * 0.28, 0.004),
          M["Tongue"])
    for sx in (-1, 1):
        def tooth(b, sx=sx):
            bmesh.ops.create_cube(b, size=1.0)
            for v in b.verts:
                v.co = loc + out * 0.007 + R @ Vector((sx * hw * 0.15 + v.co.x * hw * 0.24, v.co.y * 0.006,
                                         hh * 0.35 - hh * 0.28 + v.co.z * hh * 0.5))
        piece(f"Tooth.{sx}", tooth, M["Teeth"])

# the bow: two loops, a knot and two tails, on top of her head where the picture has it
bx, bz = to_mesh(*S["bow"])
top = None
for zz in np.linspace(mz1, mz1 - 0.2, 60):
    h = ob.ray_cast(Vector((bx, -5, zz)), Vector((0, 1, 0)))
    if h[0]:
        top = h[1]
        break
if top is not None:
    c = Vector((bx, top.y + 0.06, max(bz, top.z - 0.01)))
    W = size_x(S.get("bow_w", 170)) / 2

    def loop(b, sx):
        bmesh.ops.create_uvsphere(b, u_segments=24, v_segments=12, radius=1)
        for v in b.verts:
            p = v.co
            v.co = c + Vector((sx * (0.55 * W + p.x * 0.5 * W), p.y * 0.25 * W, p.z * 0.42 * W * (1 - 0.35 * (p.x * sx))))
    piece("Bow.L", lambda b: loop(b, 1), M["Bow"])
    piece("Bow.R", lambda b: loop(b, -1), M["Bow"])
    piece("Bow.Knot", lambda b: dome(b, c + Vector((0, -0.01, 0)), Matrix.Identity(3), 0.22 * W, 0.2 * W, 0.2 * W),
          M["Bow"])
    for sx in (-1, 1):
        def tail(b, sx=sx):
            bmesh.ops.create_cube(b, size=1.0)
            for v in b.verts:
                v.co = c + Vector((sx * (0.12 * W + (v.co.z + 0.5) * 0.25 * W) + v.co.x * 0.18 * W, v.co.y * 0.05 * W,
                                   -0.25 * W - (v.co.z + 0.5) * 0.45 * W))
        piece(f"Bow.Tail{sx}", tail, M["Bow"])

# ------------------------------------------------------------------ soft shadows (AO) in vertex colours, one mesh
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.join()
me = ob.data
for at in list(me.color_attributes):
    me.color_attributes.remove(at)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 48
try:
    pr = bpy.context.preferences.addons["cycles"].preferences; pr.compute_device_type = "OPTIX"; pr.get_devices()
    for dv in pr.devices:
        dv.use = True
    sc.cycles.device = "GPU"
except Exception:
    pass
ao = me.color_attributes.new("AO", "BYTE_COLOR", "POINT")
me.color_attributes.active_color = ao
sc.render.bake.target = "VERTEX_COLORS"
bpy.ops.object.bake(type="AO")
for m in me.materials:
    if m.name in ("Eye White", "Iris", "Pupil", "Highlight", "Teeth", "Lash", "Brow", "Mouth", "Tongue", "Blush", "Nostril"):
        continue                         # the face's little parts stay crisp (soft shadow greys them)
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    base = b.inputs["Base Color"].default_value[:]
    rgb = nt.nodes.new("ShaderNodeRGB"); rgb.outputs[0].default_value = base
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "AO"
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.7
    nt.links.new(rgb.outputs[0], mix.inputs[6]); nt.links.new(vc.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
bpy.ops.wm.save_as_mainfile(filepath=OUT + "/nina_v3.blend")
print("V3 done", [m.name for m in me.materials], flush=True)

# Colours a shape-only AI mesh with the picture it was made from, seen from the front:
#   blender -b --python project_colour.py -- <in.glb> <picture> <out.glb> [max tris]
# Every point the front can see takes the picture's colour there (the mesh's outline is lined up with the character's
# outline in the picture); points the front can't see take the colour of the nearest point that can.
import bpy, bmesh, sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
a = sys.argv[sys.argv.index("--") + 1:]
src, pic, out = a[0], a[1], a[2]
budget = int(a[3]) if len(a) > 3 else 150000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ms = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in ms:
    o.select_set(True)
bpy.context.view_layer.objects.active = ms[0]
if len(ms) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
t = sum(len(p.vertices) - 2 for p in ob.data.polygons)
if t > budget:
    mod = ob.modifiers.new("D", "DECIMATE"); mod.ratio = budget / t
    bpy.ops.object.modifier_apply(modifier="D")
img = bpy.data.images.load(pic)
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1]       # row 0 at the top
fg = np.nonzero(px[..., :3].min(axis=2) < 0.93)
x0, x1, y0, y1 = fg[1].min(), fg[1].max(), fg[0].min(), fg[0].max()
me = ob.data
vs = [v.co.copy() for v in me.vertices]
xs = [v.x for v in vs]; zs = [v.z for v in vs]
mx0, mx1, mz0, mz1 = min(xs), max(xs), min(zs), max(zs)
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table(); bm.normal_update()
tree = BVHTree.FromBMesh(bm)
far = min(v.y for v in vs) - 1.0
cols = [None] * len(vs)
eps = 0.004 * (mz1 - mz0)
for v in bm.verts:
    if v.normal.y > 0.25:            # facing away from the front
        continue
    hit = tree.ray_cast(Vector((v.co.x, far, v.co.z)), Vector((0, 1, 0)))
    if hit[0] is None or abs(hit[0].y - v.co.y) > eps:
        continue
    u = x0 + (v.co.x - mx0) / (mx1 - mx0) * (x1 - x0)
    r = y1 - (v.co.z - mz0) / (mz1 - mz0) * (y1 - y0)
    c = px[int(np.clip(r, 0, H - 1)), int(np.clip(u, 0, W - 1)), :3]
    cols[v.index] = c
seen = [i for i, c in enumerate(cols) if c is not None]
kd = KDTree(len(seen))
for k, i in enumerate(seen):
    kd.insert(vs[i], k)
kd.balance()
for i, c in enumerate(cols):
    if c is None:
        cols[i] = cols[seen[kd.find(vs[i])[1]]]
bm.free()
ca = me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
for i, c in enumerate(cols):
    ca.data[i].color = (float(c[0]), float(c[1]), float(c[2]), 1.0)
me.color_attributes.active_color = ca
m = bpy.data.materials.new("Projected"); m.use_nodes = True
b = m.node_tree.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.6
vc = m.node_tree.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
m.node_tree.links.new(vc.outputs["Color"], b.inputs["Base Color"])
me.materials.clear(); me.materials.append(m)
for p in me.polygons:
    p.use_smooth = True
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_vertex_color="ACTIVE")
print("PROJECTED", out, "seen", len(seen), "of", len(vs))

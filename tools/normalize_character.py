# Rescales a character so it is a given height with its feet at the origin, then applies
# rotation/scale on every mesh (scale = 1, rotation = 0) so it is ready for rigging.
#
#   blender -b source_art\characters\hippo_girl.blend --python tools\normalize_character.py -- 1.6
#
# Saves the .blend in place (Blender keeps the previous version as .blend1).

import sys

import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
target_height = float(args[0]) if args else 1.6

meshes = [ob for ob in bpy.data.objects if ob.type == 'MESH']


def world_vertices():
    # World-space positions of the evaluated (post-modifier) mesh, per object
    dg = bpy.context.evaluated_depsgraph_get()
    out = {}
    for ob in meshes:
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        out[ob.name] = [ev.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    return out


def world_bounds(verts=None):
    # Exact bounds from real vertices (rotated bounding boxes would overestimate)
    allv = [v for vs in (verts or world_vertices()).values() for v in vs]
    lo = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
    hi = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
    return lo, hi


def vertex_fingerprint():
    # Vertex positions normalized by bounds, to prove the shape is unchanged
    verts = world_vertices()
    lo, hi = world_bounds(verts)
    h = hi.z - lo.z
    return {name: [(v - lo) / h for v in vs] for name, vs in verts.items()}


lo, hi = world_bounds()
before = vertex_fingerprint()
scale = target_height / (hi.z - lo.z)
feet = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))   # bottom-center of the character
print(f"BEFORE height={hi.z - lo.z:.3f} feet={tuple(round(v, 3) for v in feet)} -> scale {scale:.4f}")

# Move feet to the origin and scale about it (only top-level objects; children follow their parents)
xform = Matrix.Scale(scale, 4) @ Matrix.Translation(-feet)
for ob in meshes:
    if ob.parent is None:
        ob.matrix_world = xform @ ob.matrix_world

# Apply rotation + scale (not location, so each part keeps its own pivot and mirror modifiers still work)
bpy.ops.object.select_all(action='DESELECT')
for ob in meshes:
    ob.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

lo2, hi2 = world_bounds()
after = vertex_fingerprint()
worst = max((a - b).length for name in before for a, b in zip(before[name], after[name]))
print(f"AFTER  height={hi2.z - lo2.z:.3f} lo={tuple(round(v, 3) for v in lo2)} hi={tuple(round(v, 3) for v in hi2)}")
print(f"SHAPE  max relative vertex drift = {worst:.6f} (0 = identical shape)")
bad = [ob.name for ob in meshes if any(abs(s - 1) > 1e-4 for s in ob.scale) or any(abs(r) > 1e-4 for r in ob.rotation_euler)]
print("UNAPPLIED", bad)

if worst > 1e-3 or bad:
    sys.exit("Shape changed or transforms not applied; NOT saving")
bpy.ops.wm.save_mainfile()
print("SAVED", bpy.data.filepath)

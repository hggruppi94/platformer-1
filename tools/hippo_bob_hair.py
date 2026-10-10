# Replaces the hippo's sphere hair with a bob that wraps her actual head surface.
import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

D = bpy.data
scene = bpy.context.scene
hair_ob = D.objects["Hair"]
head_src = D.objects["Cube.001 (part)"]          # editable head part (with its subdivision)

# ---- Head surface as a BVH (temporarily link the excluded backup so it evaluates) ----
scene.collection.objects.link(head_src)
dg = bpy.context.evaluated_depsgraph_get()
ev = head_src.evaluated_get(dg)
me = ev.to_mesh()
hverts = [ev.matrix_world @ v.co for v in me.vertices]
hpolys = [tuple(p.vertices) for p in me.polygons]
ev.to_mesh_clear()
scene.collection.objects.unlink(head_src)
head = BVHTree.FromPolygons(hverts, hpolys)
lo = Vector((min(v.x for v in hverts), min(v.y for v in hverts), min(v.z for v in hverts)))
hi = Vector((max(v.x for v in hverts), max(v.y for v in hverts), max(v.z for v in hverts)))
c = (lo + hi) / 2
R = (hi - lo).length / (2 * math.sqrt(3))
print(f"HEAD center={tuple(round(v, 4) for v in c)} size={tuple(round(v, 4) for v in hi - lo)}")

# ---- Hair shape ----
NT, NR = 64, 18                 # columns around, rows from crown to hem
PH = math.radians(95)           # below this polar angle the hair hangs straight down instead of hugging the head
INNER = 0.008                 # gap between scalp and the inside of the hair (m)
GROOVES = 16                    # soft strand clumps around the lower hair


def ss(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def p_cut(theta):
    """Polar angle (from the top) where the hair ends, by azimuth theta (0 = face, +/-pi = back)."""
    a = abs(math.degrees(theta))
    p = 52 + 92 * ss(50, 100, a) + 8 * ss(100, 180, a)        # bangs above eyes -> shoulder-length sides and back (Nina ref)
    if a < 50:                                                # side-swept bangs: a little lower on one side
        p += 4 * max(-1.0, min(1.0, math.degrees(theta) / 40)) * (1 - ss(30, 50, a))
    return math.radians(p)


def direction(p, theta):
    return Vector((math.sin(p) * math.sin(theta), -math.sin(p) * math.cos(theta), math.cos(p)))


def scalp(d):
    hit = head.ray_cast(c, d)
    return hit[3] if hit[0] is not None else R


def point(p, theta, outer):
    pc = p_cut(theta)
    t = p / pc
    vol = 0.55 + 0.45 * ss(30, 90, abs(math.degrees(theta)))   # fuller at the sides/back than over the bangs
    off = (0.02 + 0.034 * t * vol + 0.004 * math.sin(GROOVES * theta) * t * t) if outer else INNER
    if p <= PH:
        d = direction(p, theta)
        return c + d * (scalp(d) + off)
    # Hang: continue straight down from the 95-degree ring, flaring out slightly toward the hem
    d = direction(PH, theta)
    base = c + d * (scalp(d) + off)
    drop = (p - PH) * (scalp(d) + off)
    flare = 1 + 0.35 * (p - PH) + (0.003 * math.sin(GROOVES * theta) if outer else 0)
    h = (base - c)
    return Vector((c.x + h.x * flare, c.y + h.y * flare, base.z - drop))


# ---- Rebuild the Hair mesh: keep the bow, replace the hair faces ----
bm = bmesh.new()
bm.from_mesh(hair_ob.data)
mats = [m.name for m in hair_ob.data.materials]
hair_idx = mats.index("Hair")
before_tris = sum(len(f.verts) - 2 for f in bm.faces if f.material_index == hair_idx)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index == hair_idx], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')

thetas = [-math.pi + 2 * math.pi * j / NT for j in range(NT)]
shells = {}
for outer in (True, False):
    top = bm.verts.new(c + Vector((0, 0, 1)) * (scalp(Vector((0, 0, 1))) + (0.02 if outer else INNER)))
    rows = [[bm.verts.new(point(p_cut(th) * k / NR, th, outer)) for th in thetas] for k in range(1, NR + 1)]
    shells[outer] = (top, rows)

new_faces = []
for outer, (top, rows) in shells.items():
    for j in range(NT):
        j2 = (j + 1) % NT
        new_faces.append(bm.faces.new((top, rows[0][j], rows[0][j2])))
        for k in range(NR - 1):
            new_faces.append(bm.faces.new((rows[k][j], rows[k + 1][j], rows[k + 1][j2], rows[k][j2])))
o_hem, i_hem = shells[True][1][-1], shells[False][1][-1]
for j in range(NT):
    j2 = (j + 1) % NT
    new_faces.append(bm.faces.new((o_hem[j], i_hem[j], i_hem[j2], o_hem[j2])))   # rim closing the hem
for f in new_faces:
    f.material_index = hair_idx
    f.smooth = True
bmesh.ops.recalc_face_normals(bm, faces=new_faces)
after_tris = sum(len(f.verts) - 2 for f in new_faces)
bm.to_mesh(hair_ob.data)
bm.free()
hair_ob.data.update()

# Bright red, per Nina's main reference
hm = D.materials["Hair"]
red = (0.72, 0.035, 0.01, 1.0)
hm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = red
hm.diffuse_color = red

# ---- Check: no scalp point under the hair may be outside the hair's inner surface ----
hair_bvh = BVHTree.FromObject(hair_ob, bpy.context.evaluated_depsgraph_get())
covered = poke = 0
for i in range(1, 60):
  for j in range(240):
    theta = -math.pi + 2 * math.pi * j / 240
    p = math.radians(1.5 * i)
    if p < min(p_cut(theta), PH) - math.radians(2):
        d = direction(p, theta)
        dist = scalp(d)
        covered += 1
        hit = hair_bvh.ray_cast(c, d)
        if hit[0] is None or hit[3] < dist:
            poke += 1
            print(f"POKE polar={math.degrees(p):.1f} theta={math.degrees(theta):.1f} scalp={dist:.4f} "
                  f"hair_inner={hit[3] if hit[0] else None} cut={math.degrees(p_cut(theta)):.1f}")
print(f"HAIR tris {before_tris} -> {after_tris}")
print(f"CHECK scalp verts under hair={covered} poking through={poke}")
if poke:
    raise SystemExit("Scalp pokes through the new hair; NOT saving")
bpy.ops.wm.save_mainfile()
print("SAVED")

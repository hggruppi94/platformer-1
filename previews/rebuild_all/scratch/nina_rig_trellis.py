# Rigs the TRELLIS Nina (nina_trellis.glb) with the friends' bone names and gives her idle and walk animations.
#   blender -b --python nina_rig_trellis.py -- <nina_trellis.glb> <out dir>
# The joints are where Sofi's picture has them (it's the picture TripoSR built her from), set in the middle of her
# body's thickness there. Weights: Blender's automatic (heat) weights; the eyes are pinned to the head.
import bpy, sys, math
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0, "C:/Users/hggru/Game_dev/pf1-ai-rebuild/tools")
import char_kit as K                                     # noqa: E402
from char_kit import Pose, X, Y, Z, make_action, build_rig, rest_pose, seg_dist   # noqa: E402

A = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = A[0], A[1]
# The TRELLIS model as it came: joined, stood up at 1.45 m on the ground, centred; its texture is left alone.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ms = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = ms[0]
for o in ms:
    mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
if len(ms) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
ob.name = ob.data.name = "Nina"
me = ob.data
# glTF splits points along texture seams; join them back (UVs live on the corners, so the texture is unchanged)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0002); bpy.ops.object.mode_set(mode="OBJECT")
vs = [v.co for v in me.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
k = 1.45 / (hi.z - lo.z)
for v in me.vertices:
    v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * k, (v.co.y - (lo.y + hi.y) / 2) * k, (v.co.z - lo.z) * k))
# Is she square? the lowest point under each foot, and the middle of her feet against the middle of her head
for side, sgn in (("R", -1), ("L", 1)):
    f = [v.co for v in me.vertices if sgn * v.co.x > 0.03 and v.co.z < 0.12]
    print("FOOT", side, "low z", round(min(c.z for c in f), 4), "front y", round(min(c.y for c in f), 3), "back y", round(max(c.y for c in f), 3), "x", round(sum(c.x for c in f) / len(f), 3))
hd = [v.co for v in me.vertices if v.co.z > 1.1]
ft = [v.co for v in me.vertices if v.co.z < 0.12]
print("LEAN head mid", round(sum(c.x for c in hd)/len(hd), 3), round(sum(c.y for c in hd)/len(hd), 3), "feet mid", round(sum(c.x for c in ft)/len(ft), 3), round(sum(c.y for c in ft)/len(ft), 3))
BOX = (227, 64, 803, 953)
xs = [v.co.x for v in me.vertices]
zs = [v.co.z for v in me.vertices]
mx0, mx1, mz0, mz1 = min(xs), max(xs), min(zs), max(zs)
body_v = [v.co for v in me.vertices]


def J(px, py, r=0.05):
    """The joint at this spot of Sofi's picture: x and height from the picture, depth the middle of her body there."""
    x = mx0 + (px - BOX[0]) / (BOX[2] - BOX[0]) * (mx1 - mx0)
    z = mz0 + (BOX[3] - py) / (BOX[3] - BOX[1]) * (mz1 - mz0)
    near = [v.y for v in body_v if abs(v.x - x) < r and abs(v.z - z) < r]
    y = (min(near) + max(near)) / 2 if near else 0.0
    return Vector((x, y, z))


# The straight-on picture (pixels): her right side is on the picture's left
hips, spine, chest, neck = J(516, 693, 0.08), J(516, 627, 0.08), J(516, 547, 0.08), J(516, 450, 0.08)
head_top = Vector((neck.x, neck.y, mz0 + (BOX[3] - 70) / (BOX[3] - BOX[1]) * (mz1 - mz0)))
def toe(a):
    return a + Vector((0, -0.09, -0.06))
B = {
    "root": ((hips.x, hips.y, 0), (hips.x, hips.y, 0.25), None),
    "hips": (hips, spine, "root"),
    "spine": (spine, chest, "hips"),
    "chest": (chest, neck, "spine"),
    "head": (neck, head_top, "chest"),
    "upper_arm.R": (J(323, 493), J(283, 573), "chest"),
    "forearm.R": (J(283, 573), J(263, 640), "upper_arm.R"),
    "hand.R": (J(263, 640), J(256, 680), "forearm.R"),
    "upper_arm.L": (J(709, 493), J(749, 573), "chest"),
    "forearm.L": (J(749, 573), J(769, 640), "upper_arm.L"),
    "hand.L": (J(769, 640), J(776, 680), "forearm.L"),
    "thigh.R": (J(450, 760), J(450, 853), "hips"),
    "shin.R": (J(450, 853), J(450, 912), "thigh.R"),
    "foot.R": (J(450, 912), toe(J(450, 912)), "shin.R"),
    "thigh.L": (J(583, 760), J(583, 853), "hips"),
    "shin.L": (J(583, 853), J(583, 912), "thigh.L"),
    "foot.L": (J(583, 912), toe(J(583, 912)), "shin.L"),
}
# straight lines: the body's middle bones at one depth, each leg straight down at its hip's depth (the shoes and
# overalls stick out in front, which would lean the legs)
ty = sum(B[k][0].y for k in ("hips", "spine", "chest", "head")) / 4
for k in ("hips", "spine", "chest", "head"):
    h, t, p = B[k]; B[k] = (Vector((h.x, ty, h.z)), Vector((t.x, ty, t.z)), p)
B["root"] = (Vector((B["hips"][0].x, ty, 0)), Vector((B["hips"][0].x, ty, 0.25)), None)
for side in ("L", "R"):
    ly = B[f"thigh.{side}"][0].y
    for k in (f"thigh.{side}", f"shin.{side}"):
        h, t, p = B[k]; B[k] = (Vector((h.x, ly, h.z)), Vector((t.x, ly, t.z)), p)
    h, t, p = B[f"foot.{side}"]; B[f"foot.{side}"] = (Vector((h.x, ly, h.z)), Vector((h.x, ly - 0.09, 0.01)), p)
B = {k: (tuple(h), tuple(t), p) for k, (h, t, p) in B.items()}
for k, (h, t, p) in B.items():
    print("BONE", k, [round(x, 3) for x in h], [round(x, 3) for x in t])
rig = build_rig("NinaRig", B)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
me = ob.data
unweighted = [v for v in me.vertices if not v.groups]
if len(unweighted) > 0.02 * len(me.vertices):
    # the heat method gave up: smooth weights by distance to each bone instead (the two nearest, blended)
    for g in list(ob.vertex_groups):
        ob.vertex_groups.remove(g)
    names = [b for b in B if b != "root"]
    groups = {b: ob.vertex_groups.new(name=b) for b in names}
    for v in me.vertices:
        d = sorted((seg_dist(v.co, Vector(B[b][0]), Vector(B[b][1])), b) for b in names)[:2]
        w = [1 / max(x, 0.01) ** 4 for x, _ in d]
        tot = sum(w)
        for (x, b), wi in zip(d, w):
            groups[b].add([v.index], wi / tot, "REPLACE")
    print("RIG heat weights failed; used distance weights")
    unweighted = []
for v in unweighted:
    best = min((b for b in B if b != "root"), key=lambda b: seg_dist(v.co, Vector(B[b][0]), Vector(B[b][1])))
    (ob.vertex_groups.get(best) or ob.vertex_groups.new(name=best)).add([v.index], 1.0, "REPLACE")
print("RIG unweighted fixed", len(unweighted))


def idle(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(B)
    p.rel("spine", (Y, 0.03 * s))
    p.rel("chest", (X, 0.02 * math.sin(4 * math.pi * t)))
    p.rel("head", (Z, 0.12 * s), (Y, -0.05 * s))
    p.offset = Vector((0, 0, 0.006 * math.sin(4 * math.pi * t)))
    return p


def walk(t):
    # A bouncy little kid walk: short quick steps, a bob up on each step, a little waddle, arms swinging
    p = K.biped_walk(B, t, stride=0.55, arm=0.55, bob=0.04)
    s_ = math.sin(2 * math.pi * t)
    p.rel("hips", (Y, 0.05 * s_))
    p.rel("head", (X, -0.03 + 0.05 * abs(s_)), (Y, 0.07 * s_))
    p.rel("chest", (Y, -0.04 * s_))
    return p


bpy.context.scene.render.fps = 30
make_action(rig, "idle", 72, idle)
make_action(rig, "walk", 30, walk)
rest_pose(rig)
bpy.ops.wm.save_as_mainfile(filepath=OUT + "/nina_trellis_rigged.blend")
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT + "/nina_trellis_rigged.glb", export_format="GLB", use_selection=True, export_animations=True, export_cameras=False,
                          export_lights=False)
print("RIG done", len(me.vertices), "verts", len(me.polygons), "faces")

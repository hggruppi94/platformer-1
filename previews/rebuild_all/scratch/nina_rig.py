# Rigs the TripoSR Nina (nina_triposr.blend) with the friends' bone names and gives her idle and walk animations.
#   blender -b <nina_triposr.blend> --python nina_rig.py -- <out dir>
# The joints are where Sofi's picture has them (it's the picture TripoSR built her from), set in the middle of her
# body's thickness there. Weights: Blender's automatic (heat) weights; the eyes are pinned to the head.
import bpy, sys, math
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0, "C:/Users/hggru/Game_dev/pf1-ai-rebuild/tools")
import char_kit as K                                     # noqa: E402
from char_kit import Pose, X, Y, Z, make_action, build_rig, rest_pose, seg_dist   # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
ob = bpy.data.objects["Nina"]
me = ob.data
BOX = (482, 81, 1313, 1717)
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


# Sofi's picture (pixels): her right side is on the picture's left
hips, spine, chest, neck = J(860, 1290, 0.08), J(860, 1150, 0.08), J(860, 1000, 0.08), J(830, 840, 0.08)
head_top = Vector((neck.x, neck.y, mz0 + (BOX[3] - 160) / (BOX[3] - BOX[1]) * (mz1 - mz0)))
B = {
    "root": ((hips.x, hips.y, 0), (hips.x, hips.y, 0.25), None),
    "hips": (hips, spine, "root"),
    "spine": (spine, chest, "hips"),
    "chest": (chest, neck, "spine"),
    "head": (neck, head_top, "chest"),
    # arms bent, hands up on the backpack straps
    "upper_arm.R": (J(665, 900), J(630, 1060), "chest"),
    "forearm.R": (J(630, 1060), J(700, 990), "upper_arm.R"),
    "hand.R": (J(700, 990), J(720, 940), "forearm.R"),
    "upper_arm.L": (J(985, 905), J(1000, 1080), "chest"),
    "forearm.L": (J(1000, 1080), J(890, 1010), "upper_arm.L"),
    "hand.L": (J(890, 1010), J(870, 960), "forearm.L"),
    "thigh.R": (J(760, 1300), J(760, 1450), "hips"),
    "shin.R": (J(760, 1450), J(745, 1600), "thigh.R"),
    "foot.R": (J(745, 1600), J(690, 1690), "shin.R"),
    "thigh.L": (J(960, 1300), J(985, 1450), "hips"),
    "shin.L": (J(985, 1450), J(1000, 1600), "thigh.L"),
    "foot.L": (J(1000, 1600), J(1060, 1690), "shin.L"),
}
B = {k: (tuple(h), tuple(t), p) for k, (h, t, p) in B.items()}
for k, (h, t, p) in B.items():
    print("BONE", k, [round(x, 3) for x in h], [round(x, 3) for x in t])
rig = build_rig("NinaRig", B)
bpy.ops.object.mode_set(mode="OBJECT")
# the eyes, lids and lashes (every face not in her body's colours) come off while the body is weighted (heat weights
# fail on separate overlapping pieces), then go back on pinned to the head
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
for p in me.polygons:
    p.select = p.material_index > 0
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0005)
bpy.ops.object.mode_set(mode="OBJECT")
eyes = [o for o in bpy.context.selected_objects if o is not ob][0]
eyes.select_set(False)
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
n0 = len(me.vertices)
bpy.ops.object.select_all(action="DESELECT")
eyes.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.join()
me = ob.data
head = ob.vertex_groups.get("head") or ob.vertex_groups.new(name="head")
head.add(list(range(n0, len(me.vertices))), 1.0, "REPLACE")
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
    # A bouncy little kid walk: short quick steps, a bob up on each step, a waddle side to side, her hands staying
    # on her backpack straps (a small swing), and her head nodding along
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(B)
    stride = 0.42
    p.rel("thigh.L", (X, -stride * s))
    p.rel("thigh.R", (X, stride * s))
    p.rel("shin.L", (X, 0.1 + 0.6 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.1 + 0.6 * max(0.0, c)))
    p.rel("foot.L", (X, -0.15 * s))
    p.rel("foot.R", (X, 0.15 * s))
    p.rel("hips", (Y, 0.06 * s), (Z, 0.08 * s))
    p.rel("spine", (X, 0.05), (Y, -0.05 * s))
    p.rel("chest", (Z, -0.06 * s))
    p.rel("upper_arm.L", (X, -0.12 * s))
    p.rel("upper_arm.R", (X, 0.12 * s))
    p.rel("head", (X, -0.04 + 0.05 * abs(s)), (Y, 0.05 * s))
    p.offset = Vector((0, 0, 0.03 * abs(s)))
    return p


bpy.context.scene.render.fps = 30
make_action(rig, "idle", 72, idle)
make_action(rig, "walk", 30, walk)
rest_pose(rig)
bpy.ops.wm.save_as_mainfile(filepath=OUT + "/nina_rigged.blend")
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT + "/nina_triposr.glb", export_format="GLB", use_selection=True,
                          export_vertex_color="ACTIVE", export_animations=True, export_cameras=False,
                          export_lights=False)
print("RIG done", len(me.vertices), "verts", len(me.polygons), "faces")

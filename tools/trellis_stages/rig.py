# Stages c and e of tools/trellis_character.py: stands a TRELLIS character up (game height, feet on the ground,
# texture untouched), checks they're square, rigs them with the friends' bone names and gives them idle and walk.
#   blender -b --python rig.py -- <trellis.glb> <character json> <out dir>
# The joints are where front.png has them (the picture TRELLIS built the character from: the json's "rig"), set in the
# middle of the body's thickness there. Weights: Blender's automatic (heat) weights, or by distance if those fail.
# The objects keep the names "Nina" and "NinaRig" for every character (render_walk.py looks for them).
import bpy, sys, math
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0, "C:/Users/hggru/Game_dev/pf1-ai-rebuild/tools")
import char_kit as K                                     # noqa: E402
from char_kit import Pose, X, Y, Z, make_action, build_rig, rest_pose, seg_dist   # noqa: E402

import json
A = sys.argv[sys.argv.index("--") + 1:]
SRC, CFG, OUT = A[0], json.load(open(A[1])), A[2]
R = CFG["rig"]                     # "box": the character's box in front.png; "joints": picture pixels per joint
HEIGHT = CFG.get("height", 1.45)
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
# Turned to face the camera (-Y): the generator says how much in trellis.json ("yaw"); older runs without it are
# local TRELLIS.2 (faces +X, -90) or the online TRELLIS (faces the camera already)
info = Path(SRC).with_name("trellis.json")
yaw = None
meta = json.load(open(info)) if info.exists() else {}
# Which way is she facing? TRELLIS.2 doesn't always hand models back the same way round, so look for the eyes: the
# whitest bits of texture in the top quarter of the model (eye whites), and turn her so they face the camera (-Y),
# to the nearest quarter turn. Falls back to the generator's own note when no eyes are found.
try:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import parts_lib as _PL                                          # noqa: E402
    import numpy as _np                                              # noqa: E402
    _col = _PL.face_colours(ob)
    _cen = _np.array([(ob.matrix_world @ p_.center)[:] for p_ in ob.data.polygons])
    _top = _cen[:, 2] > _cen[:, 2].min() + 0.75 * (_cen[:, 2].max() - _cen[:, 2].min())
    # an eye white sits right beside a dark pupil; white hair shine or a white collar doesn't
    _white = _top & (_col.min(1) > 225)
    _dark = _top & (_col.max(1) < 60)
    if _white.any() and _dark.any():
        from mathutils.kdtree import KDTree as _KD
        _kd = _KD(int(_dark.sum()))
        for _i, _c in enumerate(_cen[_dark]):
            _kd.insert(_c, _i)
        _kd.balance()
        _span = _cen[:, 2].max() - _cen[:, 2].min()
        _near = _np.array([_kd.find(c)[2] < 0.03 * _span for c in _cen[_white]])
        _w = _np.where(_white)[0][_near]
        _white = _np.zeros(len(_cen), bool)
        _white[_w] = True
    if _white.sum() >= 12:
        _mid = _cen[_top][:, :2].mean(0)
        _d = _cen[_white][:, :2].mean(0) - _mid
        _ang = math.degrees(math.atan2(_d[1], _d[0]))            # facing direction in the ground plane
        yaw = round((-90 - _ang) / 90) * 90                      # turn it to -90 degrees (-Y)
        print("FACING eyes found", int(_white.sum()), "faces; turning", yaw, "(generator said", meta.get("yaw"), ")")
except Exception as e:                                              # noqa: BLE001
    print("FACING eye search failed:", e)
if yaw is None and meta:
    yaw = meta.get("yaw", -90 if "local" in meta.get("backend", "") else 0)
if yaw:
    ob.matrix_world = Matrix.Rotation(math.radians(yaw), 4, "Z") @ ob.matrix_world
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
ob.name = ob.data.name = "Nina"
me = ob.data
# glTF splits points along texture seams; join them back (UVs live on the corners, so the texture is unchanged)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0002); bpy.ops.object.mode_set(mode="OBJECT")
vs = [v.co for v in me.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
k = HEIGHT / (hi.z - lo.z)
for v in me.vertices:
    v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * k, (v.co.y - (lo.y + hi.y) / 2) * k, (v.co.z - lo.z) * k))
# Is she square? the lowest point under each foot, and the middle of her feet against the middle of her head
for side, sgn in (("R", -1), ("L", 1)):
    f = [v.co for v in me.vertices if sgn * v.co.x > 0.03 and v.co.z < 0.12]
    print("FOOT", side, "low z", round(min(c.z for c in f), 4), "front y", round(min(c.y for c in f), 3), "back y", round(max(c.y for c in f), 3), "x", round(sum(c.x for c in f) / len(f), 3))
hd = [v.co for v in me.vertices if v.co.z > 1.1]
ft = [v.co for v in me.vertices if v.co.z < 0.12]
print("LEAN head mid", round(sum(c.x for c in hd)/len(hd), 3), round(sum(c.y for c in hd)/len(hd), 3), "feet mid", round(sum(c.x for c in ft)/len(ft), 3), round(sum(c.y for c in ft)/len(ft), 3))
# Parts (stage "parts"): every face sorted into the json's named parts by its texture colour and height, each part
# its own material on the same texture (so the look doesn't change). The weights below follow the parts.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import parts_lib as PL                                      # noqa: E402
import numpy as np                                          # noqa: E402
PARTS = CFG.get("parts")
part_of_face = None
if PARTS:
    part_of_face, _ = PL.classify(ob, PARTS, HEIGHT)
    PL.apply_parts(ob, PARTS, part_of_face)
    n = np.bincount(part_of_face, minlength=len(PARTS))
    print("PARTS", {p_["name"]: int(c) for p_, c in zip(PARTS, n)})
BOX = R["box"]
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
JP = R["joints"]
hips, spine, chest, neck = (J(*JP[k], 0.08) for k in ("hips", "spine", "chest", "neck"))
head_top = Vector((neck.x, neck.y, mz0 + (BOX[3] - JP["head_top"][1]) / (BOX[3] - BOX[1]) * (mz1 - mz0)))
def toe(a):
    return a + Vector((0, -0.09, -0.06))
B = {
    "root": ((hips.x, hips.y, 0), (hips.x, hips.y, 0.25), None),
    "hips": (hips, spine, "root"),
    "spine": (spine, chest, "hips"),
    "chest": (chest, neck, "spine"),
    "head": (neck, head_top, "chest"),
}
for s_ in ("R", "L"):
    sh, el, wr, fi = (J(*JP[f"{k}.{s_}"]) for k in ("shoulder", "elbow", "wrist", "fingers"))
    hp, kn, an = (J(*JP[f"{k}.{s_}"]) for k in ("hip", "knee", "ankle"))
    B[f"upper_arm.{s_}"] = (sh, el, "chest")
    B[f"forearm.{s_}"] = (el, wr, f"upper_arm.{s_}")
    B[f"hand.{s_}"] = (wr, fi, f"forearm.{s_}")
    B[f"thigh.{s_}"] = (hp, kn, "hips")
    B[f"shin.{s_}"] = (kn, an, f"thigh.{s_}")
    B[f"foot.{s_}"] = (an, toe(an), f"shin.{s_}")
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
# Hair and bow bones (only with "secondary": true): one bone hanging down the back of the head for the hair below
# eye level, one standing in the bow. They swing on their own (baked spring motion below, and in Godot a
# SpringBoneSimulator3D on "hair" and "bow" can do it live instead).
SEC = PARTS and CFG.get("secondary", False)
if SEC:
    names_ = [p_["name"] for p_ in PARTS]
    hair_v, bow_v = set(), set()
    for p_ in me.polygons:
        nm = names_[part_of_face[p_.index]]
        if nm == "Hair":
            hair_v.update(p_.vertices)
        elif nm == "Bow":
            bow_v.update(p_.vertices)
    zc = (B["head"][0].z + B["head"][1].z) / 2 if isinstance(B["head"][0], Vector) else 0
    hz = [me.vertices[i].co for i in hair_v]
    back = max((c.y for c in hz if abs(c.z - zc) < 0.06), default=B["head"][0].y + 0.1)
    low = min((c.z for c in hz), default=zc - 0.25)
    B["hair"] = (Vector((0, back - 0.04, zc)), Vector((0, back, low + 0.02)), "head")
    if bow_v:
        bc = sum((me.vertices[i].co for i in bow_v), Vector()) / len(bow_v)
        B["bow"] = (Vector((bc.x, bc.y, bc.z - 0.03)), Vector((bc.x, bc.y, bc.z + 0.06)), "head")
    print("SECONDARY hair bone", [round(x, 3) for x in B["hair"][0]], "to", round(low, 3), "bow", "bow" in B)
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
    # The heat method gave up (a generated mesh has holes and loose bits). After the guide Hayden found: weight a
    # voxel-remeshed copy (one closed skin) the same way, then copy its weights onto the real mesh from the nearest
    # point of the copy's surface.
    proxy = ob.copy()
    proxy.data = ob.data.copy()
    proxy.modifiers.clear()
    for g in list(proxy.vertex_groups):
        proxy.vertex_groups.remove(g)
    bpy.context.scene.collection.objects.link(proxy)
    proxy.parent = None
    proxy.matrix_world = ob.matrix_world.copy()
    bpy.ops.object.select_all(action="DESELECT")
    proxy.select_set(True)
    bpy.context.view_layer.objects.active = proxy
    proxy.data.remesh_voxel_size = CFG.get("weight_voxel", 0.012)
    bpy.ops.object.voxel_remesh()
    proxy.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    proxy_bad = sum(1 for v in proxy.data.vertices if not v.groups)
    print("RIG heat weights failed on the mesh; voxel copy", len(proxy.data.vertices), "points,", proxy_bad, "unweighted")
    if proxy_bad < 0.02 * len(proxy.data.vertices):
        for g in list(ob.vertex_groups):
            ob.vertex_groups.remove(g)
        for g in proxy.vertex_groups:
            ob.vertex_groups.new(name=g.name)
        dt = ob.modifiers.new("WeightsFromCopy", "DATA_TRANSFER")
        dt.object = proxy
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "POLYINTERP_NEAREST"
        dt.layers_vgroup_select_src = "ALL"
        dt.layers_vgroup_select_dst = "NAME"
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        while ob.modifiers[0].name != "WeightsFromCopy":
            bpy.ops.object.modifier_move_up(modifier="WeightsFromCopy")
        bpy.ops.object.modifier_apply(modifier="WeightsFromCopy")
        bpy.data.objects.remove(proxy)
        me = ob.data
        unweighted = [v for v in me.vertices if not v.groups]
        print("RIG weights copied from the voxel copy; unweighted", len(unweighted))
    else:
        bpy.data.objects.remove(proxy)
if len(unweighted) > 0.02 * len(me.vertices):
    # still nothing usable: smooth weights by distance to each bone instead (the two nearest, blended)
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
if SEC:
    # hair below eye level eases from the head onto the hair bone (all of it by 0.18 m down); the bow is all bow
    gh = ob.vertex_groups.get("hair") or ob.vertex_groups.new(name="hair")
    gb = ob.vertex_groups.get("bow") or ob.vertex_groups.new(name="bow")
    zc_ = B["hair"][0][2]
    gname = {g.index: g.name for g in ob.vertex_groups}
    for vi in hair_v | bow_v:
        v = me.vertices[vi]
        w = 1.0 if vi in bow_v else min(1.0, max(0.0, (zc_ - v.co.z) / 0.18))
        if w <= 0:
            continue
        tgt = gb if vi in bow_v else gh
        for g in list(v.groups):
            n = gname[g.group]
            if n not in ("hair", "bow"):
                ob.vertex_groups[n].add([vi], g.weight * (1 - w), "REPLACE")
        tgt.add([vi], w, "REPLACE")


# Weights by rule (after the guide in Hayden's X link; only with "weight_rules": true in the json). Tested on the
# TRELLIS.2 Nina (Nov 27): the rules made stretching WORSE (straps 1.2x -> 2.4x, hair's worst spot 3x -> 21x in the pose
# test), because a TRELLIS model is one fused skin where the shirt IS the body's surface; Blender's automatic weights
# alone stayed under 1.6x on every part. They're kept for characters with a separate layer over the body (a coat,
# a cape).: a part may only follow the bones its json entry lists, so the
# overalls never follow the arms and the shirt never follows the legs; a point on the edge of two parts may follow
# the bones of either. Nothing is smoothed across parts. A point left with no allowed weight goes to its nearest
# allowed bone.
if PARTS and CFG.get("weight_rules", False):
    bone_names = [b for b in B if b != "root"]
    allowed = [None] * len(me.vertices)
    for p_ in me.polygons:
        rule = PARTS[part_of_face[p_.index]].get("bones", "all")
        ok = set(bone_names) if rule == "all" else set(rule)
        for vi in p_.vertices:
            allowed[vi] = ok if allowed[vi] is None else (allowed[vi] | ok)
    # Soften the edges: points within BLEND rings of another part may also follow that part's bones, so two
    # neighbouring points never follow completely different bones (that's what tears the texture open)
    nbr = [[] for _ in me.vertices]
    for e in me.edges:
        a_, b_ = e.vertices
        nbr[a_].append(b_)
        nbr[b_].append(a_)
    for _ in range(CFG.get("blend_rings", 3)):
        allowed = [(ok or set()).union(*[(allowed[n] or set()) for n in nbr[i]]) or None
                   for i, ok in enumerate(allowed)]
    gname = {g.index: g.name for g in ob.vertex_groups}
    groups = {b: (ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)) for b in bone_names}
    moved = 0
    for v in me.vertices:
        ok = allowed[v.index] or set(bone_names)
        ws = {gname[g.group]: g.weight for g in v.groups if gname[g.group] in groups}
        keep = {b: w for b, w in ws.items() if b in ok and w > 1e-4}
        if len(keep) != len(ws):
            moved += 1
        if not keep:
            best = min(ok, key=lambda b: seg_dist(v.co, Vector(B[b][0]), Vector(B[b][1])))
            keep = {best: 1.0}
        tot = sum(keep.values())
        for b in ws:
            if b not in keep:
                groups[b].remove([v.index])
        for b, w in keep.items():
            groups[b].add([v.index], w / tot, "REPLACE")
    print("RULES points with weights taken off a bone their part may not follow:", moved)


# Pose test (after the same guide): strike hard poses and measure how far every edge stretches or squashes, per part.
# A ratio of 1.0 is no change; 1.5 means an edge 50% longer than at rest (the texture smears there).
def posetest():
    poses = {
        "rest": lambda p: None,
        "arms_forward": lambda p: (p.rel("upper_arm.L", (X, -1.2)), p.rel("upper_arm.R", (X, -1.2))),
        "arms_out": lambda p: (p.rel("upper_arm.L", (Y, -1.2)), p.rel("upper_arm.R", (Y, 1.2))),
        "elbows_bent": lambda p: (p.rel("forearm.L", (X, -1.4)), p.rel("forearm.R", (X, -1.4))),
        "head_turn": lambda p: p.rel("head", (Z, 0.8)),
        "big_step": lambda p: (p.rel("thigh.L", (X, -0.8)), p.rel("thigh.R", (X, 0.5)), p.rel("shin.R", (X, 0.7))),
        "crouch": lambda p: (p.rel("thigh.L", (X, -1.0)), p.rel("thigh.R", (X, -1.0)), p.rel("shin.L", (X, 1.6)),
                             p.rel("shin.R", (X, 1.6))),
    }
    names = list(poses)

    def fn(t):
        p = Pose(B)
        poses[names[min(len(names) - 1, int(round(t * (len(names) - 1))))]](p)
        return p
    make_action(rig, "posetest", len(names) - 1, fn)
    rig.animation_data.action = bpy.data.actions["posetest"]
    for tr in rig.animation_data.nla_tracks:
        tr.mute = True
    edges = [(e.vertices[0], e.vertices[1]) for e in me.edges]
    epart = {}
    if PARTS:
        for p_ in me.polygons:
            for ek in p_.edge_keys:
                epart.setdefault(ek, part_of_face[p_.index])
    ev = [epart.get(tuple(sorted(e)), 0) for e in edges]
    rest_len = None
    report = {}
    dg = bpy.context.evaluated_depsgraph_get()
    for i, nm in enumerate(names):
        bpy.context.scene.frame_set(i)
        dg.update()
        em = ob.evaluated_get(dg).to_mesh()
        co = np.empty(len(em.vertices) * 3)
        em.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        ob.evaluated_get(dg).to_mesh_clear()
        L = np.array([np.linalg.norm(co[a] - co[b]) for a, b in edges]) + 1e-6
        if rest_len is None:
            rest_len = L
            continue
        r = np.maximum(L / rest_len, rest_len / L)
        per = {}
        for k in range(len(PARTS) if PARTS else 1):
            m = np.array(ev) == k
            if m.any():
                per[PARTS[k]["name"] if PARTS else "all"] = [round(float(np.percentile(r[m], 95)), 2), round(float(r[m].max()), 2)]
        report[nm] = per
        worst = max(per.items(), key=lambda kv: kv[1][0])
        print("POSE", nm, "worst part (95th pct, max):", worst[0], worst[1])
    json.dump(report, open(OUT + "/posetest.json", "w"), indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=OUT + "/posetest.blend", copy=True)     # for render_poses.py
    act = bpy.data.actions["posetest"]
    for tr in list(rig.animation_data.nla_tracks):
        if tr.name == "posetest":
            rig.animation_data.nla_tracks.remove(tr)
    rig.animation_data.action = None
    bpy.data.actions.remove(act)
    bpy.context.scene.frame_set(0)


posetest()


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


def run(t):
    # A kid's run: the friends' run with a bigger bounce, the head bobbing and the chest twisting into each stride
    p = K.biped_run(B, t)
    s_ = math.sin(2 * math.pi * t)
    p.rel("hips", (Y, 0.07 * s_))
    p.rel("head", (Y, 0.05 * s_))
    p.offset = Vector((0, 0, 0.06 * abs(s_)))
    return p


def jump(t):
    # Crouch, spring up with her arms thrown up, tuck in the air, land and squash back to standing (one second)
    def ease(x):
        return x * x * (3 - 2 * x)
    p = Pose(B)
    if t < 0.22:                                       # crouch
        k, air, arms = ease(t / 0.22), 0.0, 0.0
    elif t < 0.34:                                     # push off
        k, air, arms = 1 - ease((t - 0.22) / 0.12), 0.0, ease((t - 0.22) / 0.12)
    elif t < 0.78:                                     # in the air
        u = (t - 0.34) / 0.44
        k, air, arms = 0.0, 4 * u * (1 - u), 1 - 0.6 * u
    elif t < 0.9:                                      # land
        k, air, arms = ease((t - 0.78) / 0.12) * 0.8, 0.0, 0.4 * (1 - (t - 0.78) / 0.12)
    else:                                              # stand back up
        k, air, arms = 0.8 * (1 - ease((t - 0.9) / 0.1)), 0.0, 0.0
    tuck = air
    for side, sg in (("L", -1), ("R", 1)):                 # world axes: the left arm (+x) lifts out with a -Y turn
        p.rel(f"thigh.{side}", (X, -0.7 * k - 0.6 * tuck))
        p.rel(f"shin.{side}", (X, 1.2 * k + 0.9 * tuck))
        p.rel(f"foot.{side}", (X, -0.4 * k))
        p.rel(f"upper_arm.{side}", (Y, sg * (0.2 + 1.9 * arms)), (X, -0.5 * arms))
        p.rel(f"forearm.{side}", (X, -0.4 * arms))
    p.rel("spine", (X, 0.25 * k - 0.1 * air))
    p.rel("head", (X, -0.15 * k + 0.1 * air))
    p.offset = Vector((0, 0, -0.12 * k + 0.38 * air))
    return p


make_action(rig, "run", 20, run)
make_action(rig, "jump", 30, jump)


def bake_swing(name, frames, fn):
    """Spring swing for the hair and bow over an action: they lag behind the head's turns and flick with the body's
    bounce, run round the loop three times so the last lap starts where it ends."""
    if not SEC:
        return
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    heads, bounce = [], []
    for f in range(frames + 1):
        p = fn(f / frames)
        e = p.abs("head").to_euler()
        heads.append((e.x, e.y))
        bounce.append(p.offset.z)
    for bone, stiff, damp, flick in (("hair", 90.0, 9.0, 18.0), ("bow", 160.0, 7.0, 10.0)):
        if bone not in B:
            continue
        dt = 1 / 30
        ang = [0.0, 0.0]
        vel = [0.0, 0.0]
        out = []
        for lap in range(3):
            for f in range(frames + 1):
                fp, fn_ = max(0, f - 1), min(frames, f + 1)
                acc_z = (bounce[fn_] - 2 * bounce[f] + bounce[fp]) / (dt * dt)
                for k in (0, 1):
                    # the spring pulls toward hanging straight in the world: minus the head's own tilt
                    target = -heads[f][k] * 0.8
                    force = stiff * (target - ang[k]) - damp * vel[k] + (flick * acc_z * dt if k == 0 else 0)
                    vel[k] += force * dt
                    ang[k] += vel[k] * dt
                if lap == 2:
                    out.append((ang[0], ang[1]))
        pb = rig.pose.bones[bone]
        M = pb.bone.matrix_local.to_3x3()
        for f, (ax, ay) in enumerate(out):
            R = Matrix.Rotation(ax, 3, "X") @ Matrix.Rotation(ay, 3, "Y")
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (M.inverted() @ R @ M).to_quaternion()
            pb.keyframe_insert("rotation_quaternion", frame=f)


for nm_, fr_, fn_ in (("idle", 72, idle), ("walk", 30, walk), ("run", 20, run), ("jump", 30, jump)):
    bake_swing(nm_, fr_, fn_)
rest_pose(rig)
bpy.ops.wm.save_as_mainfile(filepath=OUT + "/rigged.blend")
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT + "/rigged.glb", export_format="GLB", use_selection=True, export_animations=True, export_cameras=False,
                          export_lights=False)
print("RIG done", len(me.vertices), "verts", len(me.polygons), "faces")

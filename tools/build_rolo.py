# Builds Rolo, the small curious rhino kid (Sofi's show notes, "The Multiverse Rhinos"), from a mesh an AI tool made
# (the Meshy trial, Nov 25, 2026). Hayden picked the Hunyuan3D-2.1 one out of five free tools (previews/meshy_trial/
# rolo_all_tools.png): its shape was the cleanest, but it came with no colours, no rig and 285k triangles. This script
# does the rest our usual way, so it can be run again:
#
#   blender -b --python tools\build_rolo.py -- --prep <raw hunyuan21_shape.glb>
#       once: cuts the raw mesh to ~40k triangles, stands it on the ground at 1.2 m with his body over the origin,
#       facing -Y, and saves it as tools/src/rolo_hunyuan21.glb (kept in the repo, like a reference picture)
#   blender -b --python tools\build_rolo.py
#       builds source_art/characters/rolo.blend from tools/src/rolo_hunyuan21.glb: named materials painted onto the
#       mesh by region (Skin, Snout, Nose, Mouth, Ear Inner, Tee, Toenail, Tuft) so the game can recolour him by name,
#       our cartoon eyes and a little horn added (the AI's shape had neither), the friends' biped bones plus a tail,
#       Blender's automatic weights, and idle, walk, run, jump and fall.
#   then: tools/build_friend_detail.py rolo  (exports the .glb with the baked rhino-skin and knit detail)
#
# Units are meters; feet at the origin; he faces -Y (+Z in Godot, like everyone). Helpers from tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "src" / "rolo_hunyuan21.glb"
OUT = ROOT / "source_art" / "characters" / "rolo.blend"
HEIGHT = 1.2
TRIS = 40000
D = bpy.data


def _args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def _import(path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    ms = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    if len(ms) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o is not ob:
            D.objects.remove(o)
    return ob


def prep(raw):
    K.begin()
    ob = _import(raw)
    me = ob.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    mod = ob.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = min(1.0, TRIS / tris)
    bpy.ops.object.modifier_apply(modifier="Decimate")
    vs = [v.co.copy() for v in me.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    k = HEIGHT / (hi.z - lo.z)
    # Centre on his body, not the bounding box: the long tail behind him would pull it back. The middle of the
    # torso, halfway up, is where the body bones go.
    mid_z = lo.z + (hi.z - lo.z) * 0.42
    band = [v for v in vs if abs(v.z - mid_z) < 0.02 * (hi.z - lo.z)]
    cx = (min(v.x for v in band) + max(v.x for v in band)) / 2
    cy = (min(v.y for v in band) + max(v.y for v in band)) / 2
    for v in me.vertices:
        v.co = Vector(((v.co.x - cx) * k, (v.co.y - cy) * k, (v.co.z - lo.z) * k))
    # One smooth surface with clean outward normals
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for p in me.polygons:
        p.use_smooth = True
    ob.name = me.name = "Rolo"
    ob.data.materials.clear()
    SRC.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(SRC), export_format="GLB", use_selection=False)
    print("PREPPED", SRC, "tris", sum(len(p.vertices) - 2 for p in me.polygons))


# =============================================================================
# Painting: every face gets a material by where it is on him (his own coordinates, after prep)
# =============================================================================
def region(c, n):
    x, y, z = c
    ax = abs(x)
    if z > 1.12 and ax < 0.09 and y > -0.45:
        return "Tuft"                                     # the little tuft of hair on top of his head
    if z > 0.72:
        # Ears stand out to the sides; their fronts are pink inside
        if ax > 0.2 and z > 0.93:
            return "Ear Inner" if n.y < -0.35 and ax > 0.24 else "Skin"
        # The big round snout and its nostrils
        sn = (x / 0.135) ** 2 + ((z - 0.925) / 0.115) ** 2
        if sn < 1.0 and y < -0.25:
            for sx in (1, -1):
                if (x - 0.095 * sx) ** 2 + (z - 0.945) ** 2 < 0.028 ** 2 and y < -0.27:
                    return "Nose"
            return "Snout"
        # The wide-open smile: the dark inside of his mouth, under the snout
        if 0.745 < z < 0.84 and ax < 0.15 and y > -0.33 + 0.0 and y < -0.1 and n.z > -0.2:
            return "Mouth"
        return "Skin"
    # His orange tee: the body from the neck to the hem, and short sleeves over his upper arms (not the tail)
    if 0.25 < z < 0.7 and y < 0.22:
        if ax < 0.255 or z > 0.535:
            return "Tee"
    # Toenails on the front of his feet
    if z < 0.07 and n.y < -0.55 and y < -0.12:
        return "Toenail"
    return "Skin"


def paint(ob):
    names = ["Skin", "Snout", "Nose", "Mouth", "Ear Inner", "Tee", "Toenail", "Tuft"]
    me = ob.data
    me.materials.clear()
    for nm in names:
        me.materials.append(K.MATS[nm])
    count = {}
    for p in me.polygons:
        r = region(p.center, p.normal)
        p.material_index = names.index(r)
        count[r] = count.get(r, 0) + 1
    print("PAINT", count)


def surface_y(ob, x, z, start=-2.0):
    """Where a ray straight back from the front hits him at this x and z."""
    hit, loc, nrm, _ = ob.ray_cast(Vector((x, start, z)), Vector((0, 1, 0)))
    return (loc, nrm) if hit else (None, None)


def build():
    K.begin()
    # The concept's colours (linear)
    mat("Skin", (0.30, 0.27, 0.34), rough=0.8)            # soft grey with a touch of lilac
    mat("Snout", (0.42, 0.38, 0.45), rough=0.8)           # a shade lighter
    mat("Nose", (0.12, 0.08, 0.10), rough=0.6)
    mat("Mouth", (0.22, 0.03, 0.04))
    mat("Tongue", (0.85, 0.25, 0.28))
    mat("Ear Inner", (0.80, 0.38, 0.40), rough=0.8)       # pink
    mat("Tee", (0.92, 0.36, 0.08), rough=0.85)            # orange
    mat("Toenail", (0.85, 0.78, 0.66), rough=0.5)         # creamy
    mat("Tuft", (0.18, 0.16, 0.20), rough=0.8)
    mat("Horn", (0.78, 0.72, 0.62), rough=0.45)
    mat("Brow", (0.05, 0.04, 0.05))
    mat("Blush", (0.70, 0.30, 0.32), rough=0.8)
    eye_materials((0.02, 0.05, 0.12), (0.10, 0.22, 0.45))  # dark blue-grey eyes, like the concept

    bpy.ops.import_scene.gltf(filepath=str(SRC))
    body = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    body.name = body.data.name = "RoloShape"
    paint(body)
    K.PARTS.append((body, ["head"]))      # weights come from Blender's automatic weights below, not char_kit's

    HB = ["head"]
    # Our cartoon eyes in the shallow sockets above the snout (the AI's face had only bumps there)
    for sx, side in ((1, "L"), (-1, "R")):
        loc, nrm = surface_y(body, 0.15 * sx, 0.99)
        ec = (loc if loc else Vector((0.15 * sx, -0.5, 0.99))) + Vector((0, 0.012, 0))
        cartoon_eye(side, ec, (0.042, 0.03, 0.048), HB, look=(-0.004 * sx, 0.004))
        # A soft brow arching over each eye
        brow = []
        for i in range(9):
            t = i / 8
            bl, _ = surface_y(body, sx * (0.1 + 0.11 * t), 1.055 + 0.022 * math.sin(math.pi * t) - 0.01 * t)
            if bl:
                brow.append(bl + Vector((0, -0.004, 0)))
        if len(brow) > 3:
            tube(f"Brow.{side}", brow, [(0.007, 0.004)] * len(brow), "Brow", HB, sides=6)
        bl, bn = surface_y(body, 0.205 * sx, 0.88)
        if bl:
            ellipsoid(f"Blush.{side}", bl + bn * 0.002, (0.03, 0.008, 0.02), "Blush", HB, rot=basis_facing(bn))
    # A little rounded horn on top of his snout (Sofi's Rolo has one; the AI left it off)
    top, tn = None, None
    for z in [1.06 - 0.005 * i for i in range(40)]:
        loc, nrm = surface_y(body, 0.0, z)
        if loc and loc.y < -0.2:
            top, tn = loc, nrm
            break
    if top:
        base = top + Vector((0, 0.012, -0.004))
        lock("Horn", [base, base + Vector((0, -0.02, 0.045)), base + Vector((0, -0.005, 0.08))], 0.045, "Horn", HB,
             flat=0.95, tip=0.008, sides=16, taper=1.4)
        lock("Horn Nub", [base + Vector((0, 0.06, 0.01)), base + Vector((0, 0.06, 0.04))], 0.022, "Horn", HB,
             flat=0.95, tip=0.006, sides=12)
    # A tongue in his open smile
    loc, nrm = surface_y(body, 0.0, 0.775)
    if loc:
        ellipsoid("Tongue", loc + Vector((0, 0.03, 0.0)), (0.065, 0.045, 0.02), "Tongue", HB)

    # ------------------------------------------------------------------ rig: the friends' bones and a tail
    BONES = biped_bones(hips=0.33, chest=0.56, neck=0.70, head_top=1.16, shoulder=(0.235, 0.0, 0.62),
                        elbow=(0.31, -0.03, 0.48), wrist=(0.35, -0.06, 0.37), hand_tip=(0.37, -0.08, 0.3),
                        hip_x=0.12, knee=0.16, ankle=0.06, toe=(-0.16, 0.02))
    tail = [(0, 0.27, 0.42), (0, 0.45, 0.31), (0, 0.65, 0.19), (0, 0.88, 0.11), (0, 1.02, 0.13)]
    parent = "hips"
    for i in range(len(tail) - 1):
        BONES[f"tail.{i}"] = (tail[i], tail[i + 1], parent)
        parent = f"tail.{i}"
    rig = build_rig("RoloRig", BONES)
    # The added parts (eyes, brows, horn, tongue) follow the head: join them to the body first
    extras = [o for o, _ in K.PARTS if o is not body]
    bpy.ops.object.select_all(action="DESELECT")
    for o in extras:
        o.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    # The AI's shape is weighted by Blender's heat method; the little parts are pinned to the head afterwards
    head_parts = {v for o in extras for v in range(len(o.data.vertices))}
    n0 = len(body.data.vertices)
    bpy.ops.object.join()
    body.name = body.data.name = "Rolo"
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    head = body.vertex_groups.get("head") or body.vertex_groups.new(name="head")
    for g in body.vertex_groups:
        if g.name != "head":
            g.remove(list(range(n0, len(body.data.vertices))))
    head.add(list(range(n0, len(body.data.vertices))), 1.0, "REPLACE")
    unweighted = sum(1 for v in body.data.vertices if not v.groups)
    print("MESH Rolo verts=%d tris=%d materials=%d unweighted=%d" % (
        len(body.data.vertices), sum(len(p.vertices) - 2 for p in body.data.polygons), len(body.data.materials),
        unweighted))
    if unweighted:
        # Heat weighting can miss a few loose bits: give them to the nearest bone
        for v in body.data.vertices:
            if not v.groups:
                best = min(BONES, key=lambda b: seg_dist(v.co, *BONES[b][:2]) if b != "root" else 9)
                (body.vertex_groups.get(best) or body.vertex_groups.new(name=best)).add([v.index], 1.0, "REPLACE")

    # ------------------------------------------------------------------ animations
    def tail_swing(p, t, amount=1.0):
        s = math.sin(2 * math.pi * t)
        for i in range(len(tail) - 1):
            p.rel(f"tail.{i}", (Z, 0.18 * s * amount * (0.6 + 0.2 * i)), (X, 0.05 * math.cos(2 * math.pi * t)))

    def idle(t):
        # Curious: swaying, looking about this way and that, tail swishing
        p = biped_idle(BONES, t, sway=1.2)
        p.rel("head", (Z, 0.22 * math.sin(2 * math.pi * t)), (X, -0.04 + 0.04 * math.sin(4 * math.pi * t)))
        tail_swing(p, t, 0.8)
        return p

    def walk(t):
        p = biped_walk(BONES, t, stride=0.36, arm=0.32, bob=0.022)
        tail_swing(p, t * 2, 0.6)
        return p

    def run(t):
        p = biped_run(BONES, t)
        tail_swing(p, t * 2, 1.0)
        return p

    def jump(t):
        k = ss(0, 1, t)
        p = Pose(BONES)
        p.rel("thigh.L", (X, -0.5 * k))
        p.rel("thigh.R", (X, -0.3 * k))
        p.rel("shin.L", (X, 0.9 * k))
        p.rel("shin.R", (X, 0.6 * k))
        p.rel("upper_arm.L", (Y, 0.38 - 1.3 * k))
        p.rel("upper_arm.R", (Y, -0.38 + 1.3 * k))
        p.rel("tail.0", (X, -0.3 * k))
        return p

    def fall(t):
        s = math.sin(2 * math.pi * t)
        p = Pose(BONES)
        p.rel("thigh.L", (X, -0.25 + 0.15 * s))
        p.rel("thigh.R", (X, -0.25 - 0.15 * s))
        p.rel("upper_arm.L", (Y, -0.9 + 0.15 * s))
        p.rel("upper_arm.R", (Y, 0.9 + 0.15 * s))
        tail_swing(p, t, 1.5)
        return p

    make_action(rig, "idle", 72, idle)
    make_action(rig, "walk", 32, walk)
    make_action(rig, "run", 20, run)
    make_action(rig, "jump", 10, jump)
    make_action(rig, "fall", 24, fall)
    rest_pose(rig)
    finish(OUT)


a = _args()
if a and a[0] == "--prep":
    prep(a[1])
else:
    build()

# Rebuilds a model's shape with an AI 3D tool (Hunyuan3D-2.1), keeping everything the game leans on (Hayden, Nov 25,
# 2026: "I want you to then work on rebuilding every single model in the game with that tool"). It's a layer on top of
# the usual builders, never a replacement: the original .blend files and build scripts are untouched, and
# `python tools/ai_rebuild.py restore <model>` puts the original back.
#
#   python tools/ai_rebuild.py <model> [--steps=30]       one model, start to end (see MODELS)
#   python tools/ai_rebuild.py restore <model>            the original model back in the game
#
# What happens, step by step (each step can be run on its own: blender -b --python tools/ai_rebuild.py -- <step> ...):
#   1. render: the model as the game has it, from the front in its rest (A) pose on white, so the AI keeps Sofi's
#      design (it's the only picture the AI sees).
#   2. shape: Hunyuan3D-2.1's shape model on this PC's GPU (in its own Python env, outside the repo: AI3D below).
#   3. fit, for a character: the AI's mesh is lined up with the old body (same height, centre and feet), cut down to the
#      old body's triangle budget, painted with the old body's NAMED materials (each new face takes the material of
#      the nearest old face) and skinned with the old weights (Blender's Data Transfer), then put on the old rig. The
#      parts that must stay crisp (eyes, mouths, glasses, glowing bits: KEEP) are kept from the old model exactly.
#      Bones, bone names, animations and material names are the old ones, so outfits, recolours and scripts all work.
#      Saved as source_art/characters/ai/<model>.blend.
#      fit, for a prop: the AI's mesh is fitted to the old prop's box, cut to at most twice its triangles, given UVs,
#      and the old prop's colour, roughness and glow are baked across onto it (and the AI's own fine shape into its
#      normal map). Same material name. Written straight to the game's .glb.
#   4. detail: characters get their baked detail again (tools/build_friend_detail.py <who> --src=<the ai .blend>).
#
# The raw AI meshes and renders live outside the repo (AI3D/rebuild/<model>).

import json
import shutil
import math
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "Godot Project/my-world"
AI3D = Path(os.environ.get("AI3D", r"C:\Users\hggru\Game_dev\ai3d"))
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender 4.5\blender.exe")
FACE_OFF_MAX = 0.02  # the face check's limit (a share of the height) before the old head is kept
EYES = ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine"]

# kind, the original (.blend for characters, the game's .glb for props), body and rig names, the detail recipe's key in
# build_friend_detail.py (None: no detail), and the materials kept from the old model as they are
MODELS = {
    "mr_palmer": {"kind": "character", "blend": "source_art/characters/mr_palmer.blend", "body": "MrPalmer",
                  "rig": "MrPalmerRig", "detail": "palmer", "glb": "models/characters/mr_palmer.glb",
                  "keep": EYES + ["Glasses", "Mouth", "Tongue", "Blush"]},
    "nina": {"kind": "character", "blend": "source_art/characters/nina.blend", "body": "Nina", "rig": "NinaRig",
             "detail": None, "glb": "models/characters/nina.glb",
             "keep": EYES + ["Brow", "Blush", "Mouth", "Tongue", "Teeth", "Nostril"]},
    "cyber_gorilla": {"kind": "character", "blend": "source_art/characters/cyber_gorilla.blend", "body": "CyberGorilla",
                      "rig": "GorillaRig", "detail": "gorilla", "glb": "models/characters/cyber_gorilla.glb",
                      "keep": EYES + ["Screen", "Screen Gold", "Screen Gold Dark", "Void", "Eye Fire", "Screen Bone",
                                      "Chaos Magenta", "Cyber Glow", "Red Eye", "Tooth", "Mouth"]},
    "chaos_giant": {"kind": "character", "blend": "source_art/characters/chaos_giant.blend", "body": "ChaosGiant",
                    "rig": "ChaosGiantRig", "detail": "chaos", "glb": "models/characters/chaos_giant.glb",
                    "keep": ["Void", "Eye Fire", "Clock Face", "Ink", "Chaos Magenta", "Chaos Ember", "Eye Gold",
                             "Chaos Violet"]},
    "antique_car": {"kind": "prop", "glb": "models/props/antique_car.glb", "restore": [
        "python", "tools/build_prop_void.py", "Godot Project/my-world/models/props/antique_car.glb", "antique_car"]},
}


def work(name):
    d = AI3D / "rebuild" / name
    d.mkdir(parents=True, exist_ok=True)
    return d


# =====================================================================================================================
# Driver (plain Python)
# =====================================================================================================================
def blender(step, *a):
    t = time.time()
    r = subprocess.run([BLENDER, "-b", "--python", str(Path(__file__)), "--", step, *map(str, a)],
                       capture_output=True, text=True, encoding="utf-8", errors="ignore")
    for line in r.stdout.splitlines():
        if line.startswith(("AI ", "DETAILED", "Error", "Traceback")) or "Error:" in line:
            print("   ", line)
    if r.returncode != 0 or "Traceback" in r.stdout + r.stderr:
        print(r.stderr[-3000:])
        sys.exit(f"{step} failed")
    return round(time.time() - t, 1)


def run(name, steps=30, views=1):
    """views=1: Hunyuan3D-2.1 from the front picture; views=3: Hunyuan3D-2mv from front, left and back pictures."""
    m = MODELS[name]
    d = work(name)
    if not (d / "before.glb").exists():
        shutil.copy(GAME / m["glb"], d / "before.glb")
    times = {}
    times["render"] = blender("render", name)
    t = time.time()
    py = AI3D / "base/Scripts/python.exe"
    raw = "raw.glb" if views == 1 else "raw_mv.glb"
    if views == 1:
        cmd = [str(py), str(AI3D / "runners/run_hunyuan21.py"), str(AI3D / "hunyuan21"), str(d / "input.png"),
               str(d / raw), str(steps)]
    else:
        cmd = [str(py), str(AI3D / "runners/run_hunyuan2mv.py"), str(AI3D / "hunyuan2"), str(d / "input.png"),
               str(d / "input_left.png"), str(d / "input_back.png"), str(d / raw)]
    if (d / raw).exists() and "--fresh" not in sys.argv:
        cmd = [str(py), "-c", "print('TRIS (reusing the last AI shape: --fresh makes a new one)')"]
    r = subprocess.run(cmd, capture_output=True, text=True, errors="ignore")
    print("   ", [l for l in r.stdout.splitlines() if l.startswith("TRIS")])
    if r.returncode != 0:
        print(r.stderr[-3000:])
        sys.exit("shape failed")
    times["shape"] = round(time.time() - t, 1)
    times["fit"] = blender("fit", name, raw)
    if m["kind"] == "character" and m.get("detail"):
        t = time.time()
        subprocess.run([BLENDER, "-b", "--python", str(ROOT / "tools/build_friend_detail.py"), "--", m["detail"],
                        "--src=" + str(ROOT / "source_art/characters/ai" / (Path(m["blend"]).stem + ".blend"))],
                       check=True, capture_output=True)
        times["detail"] = round(time.time() - t, 1)
    elif m["kind"] == "character":
        blender("export", name)
    tag = "game_sv" if views == 1 else "game_mv"
    (d / tag).mkdir(exist_ok=True)
    glb = GAME / m["glb"]
    for f in [glb] + list(glb.parent.glob(glb.stem + "_*.png")):
        shutil.copy(f, d / tag / f.name)
    (d / f"times_{tag}.json").write_text(json.dumps(times))
    print("AI rebuilt", name, tag, times)


def restore(name):
    m = MODELS[name]
    if m["kind"] == "character":
        if m.get("detail"):
            subprocess.run([BLENDER, "-b", "--python", str(ROOT / "tools/build_friend_detail.py"), "--", m["detail"]],
                           check=True)
        else:
            subprocess.run([BLENDER, "-b", str(ROOT / m["blend"]), "--python", str(ROOT / "tools/export_glb.py"), "--",
                            str(GAME / m["glb"])], check=True)
    else:
        subprocess.run(m["restore"], cwd=ROOT, check=True)
    print("restored", name)


# =====================================================================================================================
# Blender steps
# =====================================================================================================================
def _bpy_steps():
    import bmesh
    import bpy
    from mathutils import Matrix, Vector
    from mathutils.bvhtree import BVHTree

    D = bpy.data

    def clean():
        bpy.ops.wm.read_factory_settings(use_empty=True)

    def import_glb(path):
        before = set(D.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        return [o for o in D.objects if o not in before]

    def bounds(objs):
        dg = bpy.context.evaluated_depsgraph_get()
        lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for o in objs:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            for v in me.vertices:
                w = o.matrix_world @ v.co
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
            ev.to_mesh_clear()
        return lo, hi

    def join(objs, name):
        objs = [o for o in objs if o.type == "MESH"]
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.parent = None
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        ob.name = ob.data.name = name
        return ob

    def tris(ob):
        return sum(len(p.vertices) - 2 for p in ob.data.polygons)

    def decimate(ob, budget):
        t = tris(ob)
        if t > budget:
            mod = ob.modifiers.new("Decimate", "DECIMATE")
            mod.ratio = budget / t
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier="Decimate")
        for p in ob.data.polygons:
            p.use_smooth = True

    def core_bounds(ob):
        """ob's box, but its width and depth from above its lowest 6% only: the AI sometimes stands a model on a wide
        flat base (it read the white ground under it as a floor), which mustn't count."""
        vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
        z0 = min(v.z for v in vs)
        z1 = max(v.z for v in vs)
        up = [v for v in vs if v.z > z0 + 0.06 * (z1 - z0)] or vs
        return (Vector((min(v.x for v in up), min(v.y for v in up), z0)),
                Vector((max(v.x for v in up), max(v.y for v in up), z1)))

    def trim(ob, lo, hi, margin=0.12):
        """Deletes faces outside the old model's footprint (the AI's base, if it made one)."""
        pad = (hi - lo) * margin
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        out = [f for f in bm.faces if any(c < lo[i] - pad[i] or c > hi[i] + pad[i]
                                          for i, c in enumerate(f.calc_center_median()) if i < 2)]
        bmesh.ops.delete(bm, geom=out, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(ob.data)
        bm.free()
        return len(out)

    def smooth_materials(ob, passes=2):
        """Each face takes the material most of its neighbours have, twice over: the nearest-face painting leaves
        speckles where two parts meet."""
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.faces.ensure_lookup_table()
        for _ in range(passes):
            new = []
            for f in bm.faces:
                count = {}
                for e in f.edges:
                    for g in e.link_faces:
                        count[g.material_index] = count.get(g.material_index, 0) + 1
                new.append(max(count, key=count.get) if count else f.material_index)
            for f, mi in zip(bm.faces, new):
                f.material_index = mi
        bm.to_mesh(ob.data)
        bm.free()

    def clean_islands(ob, passes=2):
        """Little patches of one material inside another (fewer than 1 face in 500) take their surroundings'."""
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.faces.ensure_lookup_table()
        small = max(12, len(bm.faces) // 500)
        for _ in range(passes):
            seen = set()
            for f in bm.faces:
                if f.index in seen:
                    continue
                island, stack = [], [f]
                seen.add(f.index)
                while stack:
                    g = stack.pop()
                    island.append(g)
                    for e in g.edges:
                        for k in e.link_faces:
                            if k.index not in seen and k.material_index == f.material_index:
                                seen.add(k.index)
                                stack.append(k)
                if len(island) < small:
                    ring = {}
                    for g in island:
                        for e in g.edges:
                            for k in e.link_faces:
                                if k.material_index != f.material_index:
                                    ring[k.material_index] = ring.get(k.material_index, 0) + 1
                    if ring:
                        mi = max(ring, key=ring.get)
                        for g in island:
                            g.material_index = mi
        bm.to_mesh(ob.data)
        bm.free()

    def trim_floor(ob, old, lo, hi):
        """Deletes what the AI stood the model on that the old model hasn't got (a floor tile under the gorilla's
        feet): faces in the lowest 3% that are further than 1.5% of the height from the old surface."""
        h = hi.z - lo.z
        tree = BVHTree.FromObject(old, bpy.context.evaluated_depsgraph_get())
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        out = []
        for f in bm.faces:
            c = f.calc_center_median()
            if c.z < lo.z + 0.03 * h:
                hit = tree.find_nearest(c)
                if hit[3] is None or hit[3] > 0.015 * h:
                    out.append(f)
        bmesh.ops.delete(bm, geom=out, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(ob.data)
        bm.free()
        return len(out)

    def fit_to(ob, lo, hi, per_axis=False):
        """Scale and move ob so its box matches lo..hi (uniformly by height, or per axis for props)."""
        a, b = core_bounds(ob)
        if per_axis:
            k = Vector([(hi[i] - lo[i]) / max(b[i] - a[i], 1e-6) for i in range(3)])
        else:
            s = (hi.z - lo.z) / max(b.z - a.z, 1e-6)
            k = Vector((s, s, s))
        for v in ob.data.vertices:
            c = v.co
            v.co = Vector((((c.x - (a.x + b.x) / 2) * k.x) + (lo.x + hi.x) / 2,
                           ((c.y - (a.y + b.y) / 2) * k.y) + (lo.y + hi.y) / 2,
                           (c.z - a.z) * k.z + lo.z))

    # ------------------------------------------------------------------------------------------------- render
    def render(name):
        m = MODELS[name]
        clean()
        if m["kind"] == "character":
            # The original .blend in its REST pose: the pose the fit lines the AI's shape up with (a glb's own pose
            # can differ: Nina's has her arms out where her rig's rest has them down)
            bpy.ops.wm.open_mainfile(filepath=str(ROOT / m["blend"]))
            D.objects[m["rig"]].data.pose_position = "REST"
            bpy.context.view_layer.update()
            for o in list(D.objects):
                if o.type not in ("MESH", "ARMATURE"):
                    D.objects.remove(o)
            objs = list(D.objects)
        else:
            # Always the ORIGINAL model (kept as before.glb the first time), never an earlier AI rebuild of it
            objs = import_glb(work(name) / "before.glb")
            for o in objs:
                if o.type == "ARMATURE" and o.animation_data:
                    o.animation_data.action = None
        meshes = [o for o in objs if o.type == "MESH"]
        # Frame the body only: some exports carry a stray helper (mr_palmer.glb has a unit Icosphere at its feet)
        if m.get("body") and any(o.name == m["body"] for o in meshes):
            for o in meshes:
                if o.name != m["body"]:
                    D.objects.remove(o)
            meshes = [D.objects[m["body"]]]
        lo, hi = bounds(meshes)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_EEVEE_NEXT"
        sc.render.resolution_x = sc.render.resolution_y = 1024
        sc.render.film_transparent = False
        sc.view_settings.view_transform = "Standard"
        w = D.worlds.new("W")
        sc.world = w
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
        w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
        for ang, e in ((30, 3.0), (-40, 1.5)):
            s = D.objects.new("Sun", D.lights.new("Sun", "SUN"))
            sc.collection.objects.link(s)
            s.data.energy = e
            s.rotation_euler = (math.radians(55), 0, math.radians(ang))
        cam = D.objects.new("Cam", D.cameras.new("Cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.type = "ORTHO"
        size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) * 1.15
        cam.data.ortho_scale = size
        mid = (lo + hi) / 2
        # front (camera at -Y), left (the model's left side: camera at +X, its face to the picture's left) and back,
        # all at one scale, as Hunyuan3D-2mv wants
        for tag, loc, yaw in (("", (mid.x, lo.y - 5, mid.z), 0), ("_left", (hi.x + 5, mid.y, mid.z), 90),
                              ("_back", (mid.x, hi.y + 5, mid.z), 180)):
            cam.location = loc
            cam.rotation_euler = (math.radians(90), 0, math.radians(yaw))
            sc.render.filepath = str(work(name) / f"input{tag}.png")
            bpy.ops.render.render(write_still=True)
        print("AI render", work(name))

    def dominant_bones(ob):
        """Per face: the bone (vertex group name) carrying it most, from its corners' weights."""
        names = {g.index: g.name for g in ob.vertex_groups}
        best_v = []
        for v in ob.data.vertices:
            w = {}
            for g in v.groups:
                w[g.group] = w.get(g.group, 0) + g.weight
            best_v.append(w)
        out = []
        for p in ob.data.polygons:
            w = {}
            for vi in p.vertices:
                for k, x in best_v[vi].items():
                    w[k] = w.get(k, 0) + x
            out.append(names.get(max(w, key=w.get)) if w else None)
        return out

    def face_offset(old, new, head_faces, mats, keep):
        """The middle distance from the front of the old face (head faces pointing forward, not the kept eyes and
        glasses) to the AI's surface."""
        tree = BVHTree.FromObject(new, bpy.context.evaluated_depsgraph_get())
        ds = []
        for p in old.data.polygons:
            mt = mats[p.material_index]
            if p.index in head_faces and p.normal.y < -0.6 and mt is not None and mt.name not in keep:
                hit = tree.find_nearest(p.center)
                if hit[0] is not None:
                    ds.append(hit[3])
        ds.sort()
        return ds[len(ds) // 2] if ds else 0.0

    def cut_head(new, old, head_faces, h):
        """Takes the AI's own head off: every face inside the old head, or higher than the old head's lowest point."""
        bm = bmesh.new()
        for p in old.data.polygons:
            if p.index in head_faces:
                bm.faces.new([bm.verts.new(old.data.vertices[v].co) for v in p.vertices])
        bm.normal_update()
        tree = BVHTree.FromBMesh(bm)
        z0 = min(v.co.z for v in bm.verts)
        bm.free()
        nb = bmesh.new()
        nb.from_mesh(new.data)
        out = []
        for f in nb.faces:
            c = f.calc_center_median()
            if c.z > z0 + 0.01 * h:
                out.append(f)
                continue
            hit = tree.find_nearest(c)
            if hit[0] is not None and (c - hit[0]).dot(hit[1]) < 0 and hit[3] < 0.08 * h:
                out.append(f)
        bmesh.ops.delete(nb, geom=out, context="FACES")
        bmesh.ops.delete(nb, geom=[v for v in nb.verts if not v.link_faces], context="VERTS")
        nb.to_mesh(new.data)
        nb.free()
        print("AI head taken off:", len(out), "faces")

    def flatten_under(new, old, mats, names, h, reach=0.035, iters=40):
        """Smooths the AI's face flat where the old eyes and glasses go back on: the AI moulds its own copy of them
        into the face (ridges round the eyes, a second pair of glasses in the skin), which would show round the real
        ones. Only the points near those parts move (the mouth, snout and cheeks keep the AI's shape); the edge of the
        patch stays put, so it blends in."""
        bm = bmesh.new()
        for p in old.data.polygons:
            mt = mats[p.material_index]
            if mt is not None and mt.name in names:
                bm.faces.new([bm.verts.new(old.data.vertices[v].co) for v in p.vertices])
        if not bm.faces:
            bm.free()
            return
        parts = BVHTree.FromBMesh(bm)
        bm.free()
        nb = bmesh.new()
        nb.from_mesh(new.data)
        nb.verts.ensure_lookup_table()
        r = reach * h
        move = [v for v in nb.verts if (parts.find_nearest(v.co, r)[0] is not None)]
        ids = {v.index for v in move}
        for _ in range(iters):
            pos = {}
            for v in move:
                ns = [e.other_vert(v).co for e in v.link_edges]
                if ns:
                    pos[v.index] = v.co * 0.3 + (sum(ns, Vector()) / len(ns)) * 0.7
            for i, c in pos.items():
                nb.verts[i].co = c
        nb.to_mesh(new.data)
        nb.free()
        new.data.update()
        print("AI face smoothed under the kept parts:", len(ids), "points")

    def straighten_borders(ob, iters=10):
        """Smooths the zigzag where two parts meet (each face is one part, so a border follows the triangles): the
        points on a border slide along it towards their border neighbours, then back onto the surface."""
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.verts.ensure_lookup_table()
        surface = BVHTree.FromBMesh(bm)
        border = {}
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.link_faces[0].material_index != e.link_faces[1].material_index:
                for v in e.verts:
                    border.setdefault(v.index, []).append(e.other_vert(v).index)
        # only simple border points (on one line between two parts), not where three parts meet
        simple = {i: ns for i, ns in border.items() if len(ns) == 2 and
                  len({f.material_index for f in bm.verts[i].link_faces}) == 2}
        for _ in range(iters):
            moved = {}
            for i, ns in simple.items():
                v = bm.verts[i]
                mid = (bm.verts[ns[0]].co + bm.verts[ns[1]].co) / 2
                moved[i] = v.co * 0.5 + mid * 0.5
            for i, c in moved.items():
                hit = surface.find_nearest(c)
                bm.verts[i].co = hit[0] if hit[0] is not None else c
        bm.to_mesh(ob.data)
        bm.free()
        print("AI borders straightened:", len(simple), "border points")

    def paint_by_picture(new, old, mats, keep, lo, hi, absorb=False):
        """Colour by picture: the AI was shown the old model from the front, left and back, so each new face takes the
        part the AI saw there. Looking along the same view, the first old face the line of sight meets is the part in
        that picture (a flat colour-by-number render of the old model, without the rendering). Each face uses the view
        that sees it most squarely and isn't blocked by the AI's own shape; faces no view sees (under the arms) take
        their neighbours' part. absorb: the old eyes, glasses and mouth count too (they're painted onto the AI's own
        moulded ones instead of being put back on top)."""
        h = hi.z - lo.z
        big = 4 * max(hi - lo)
        use = [mi for mi, mt in enumerate(mats) if mt is not None and (absorb or mt.name not in keep)]
        ob = bmesh.new()
        omi = []
        for p in old.data.polygons:
            if p.material_index in use:
                ob.faces.new([ob.verts.new(old.data.vertices[v].co) for v in p.vertices])
                omi.append(p.material_index)
        old_tree = BVHTree.FromBMesh(ob)
        ob.free()
        nb = bmesh.new()
        nb.from_mesh(new.data)
        nb.faces.ensure_lookup_table()
        new_tree = BVHTree.FromBMesh(nb)
        views = [Vector((0, 1, 0)), Vector((-1, 0, 0)), Vector((0, -1, 0))]   # front, left, back (render())
        eps = 0.004 * h
        label = [None] * len(nb.faces)
        for f in nb.faces:
            c = f.calc_center_median()
            n = f.normal
            best, score = None, 0.15
            for d in views:
                facing = -d.dot(n)
                if facing <= score:
                    continue
                start = c - d * big
                first = new_tree.ray_cast(start, d, 2 * big)
                if first[0] is None or (first[0] - c).length > eps:
                    continue
                hit = old_tree.ray_cast(start, d, 2 * big)
                if hit[2] is None:
                    continue
                best, score = omi[hit[2]], facing
            label[f.index] = best
        # Faces no picture shows take their neighbours' part, ring by ring
        known = sum(x is not None for x in label)
        for _ in range(200):
            todo = [f for f in nb.faces if label[f.index] is None]
            if not todo:
                break
            changed = []
            for f in todo:
                count = {}
                for e in f.edges:
                    for g in e.link_faces:
                        if label[g.index] is not None:
                            count[label[g.index]] = count.get(label[g.index], 0) + 1
                if count:
                    changed.append((f.index, max(count, key=count.get)))
            if not changed:
                break
            for i, mi in changed:
                label[i] = mi
        near = BVHTree.FromBMesh(nb)
        for f in nb.faces:
            mi = label[f.index] if label[f.index] is not None else f.material_index
            f.material_index = mi
        nb.to_mesh(new.data)
        nb.free()
        protect = {mi for mi, mt in enumerate(mats) if mt is not None and mt.name in keep}
        if not absorb:
            smooth_materials(new, passes=2)
        clean_islands_min(new, max(12, len(new.data.polygons) // 500), protect)
        print("AI picture paint: seen by a picture", known, "of", len(label))

    def paint_by_region(new, old, mats, keep, lo, hi):
        """Paints the new body with the old named materials region by region (Hayden: Rolo's clean colours): a face
        may only take a material the old body uses on the same bone (so a sleeve's colour never leaks onto the chest,
        the sash stays on the chest, shoes stay on feet), the nearest old face of those wins (one facing the same way
        first), and the borders are then smoothed hard, so each part is one clean patch."""
        h = hi.z - lo.z
        ob_bone = dominant_bones(old)
        nb_bone = dominant_bones(new)
        allowed = {}
        for p, b in zip(old.data.polygons, ob_bone):
            mt = mats[p.material_index]
            if mt is None or mt.name in keep:
                continue
            allowed.setdefault(b, {}).setdefault(p.material_index, 0)
            allowed[b][p.material_index] += 1
        raw_allowed = {b: set(c) for b, c in allowed.items()}
        for b, c in allowed.items():
            tot = sum(c.values())
            allowed[b] = {mi for mi, n in c.items() if n >= 0.02 * tot} or set(c)
        everything = {mi for c in allowed.values() for mi in c}
        # For the outermost layer, any material on this bone or the bones next to it (thin things like a tie sit on
        # the chest bone while the shirt round them is on the spine's)
        near = {}
        rig = old.parent
        if rig is not None and rig.type == "ARMATURE":
            for bone in rig.data.bones:
                group = [bone.name] + ([bone.parent.name] if bone.parent else []) + [c.name for c in bone.children]
                near[bone.name] = set()
                for g in group:
                    near[bone.name] |= raw_allowed.get(g, set())
        # one tree per material
        trees, normals = {}, {}
        for mi in everything:
            bm = bmesh.new()
            for p in old.data.polygons:
                if p.material_index == mi:
                    bm.faces.new([bm.verts.new(old.data.vertices[v].co) for v in p.vertices])
            trees[mi] = BVHTree.FromBMesh(bm)
            bm.free()
        # Everything the old body is made of (not the kept parts), to find the OUTERMOST layer along each face's
        # normal: what you'd see from outside (the sash over the suit, the tie over the shirt)
        allbm = bmesh.new()
        all_mi = []
        for p in old.data.polygons:
            if p.material_index in everything:
                allbm.faces.new([allbm.verts.new(old.data.vertices[v].co) for v in p.vertices])
                all_mi.append(p.material_index)
        outer = BVHTree.FromBMesh(allbm)
        allbm.free()
        for p, b in zip(new.data.polygons, nb_bone):
            cands = allowed.get(b) or everything
            o = p.center + p.normal * (0.06 * h)
            hit = outer.ray_cast(o, -p.normal, 0.12 * h)
            if hit[2] is not None and hit[1].dot(p.normal) > 0.2 and all_mi[hit[2]] in near.get(b, everything):
                p.material_index = all_mi[hit[2]]
                continue
            best, best_d = None, 1e9
            for mi in cands:
                hit = trees[mi].find_nearest(p.center)
                if hit[0] is None:
                    continue
                d = hit[3] + (0 if hit[1].dot(p.normal) > 0.3 else 0.05 * h)
                if d < best_d:
                    best, best_d = mi, d
            if best is not None:
                p.material_index = best
        smooth_materials(new, passes=10)
        bm = bmesh.new()
        bm.from_mesh(new.data)
        n = len(bm.faces)
        bm.free()
        clean_islands(new, passes=3)
        # bigger patches too (up to 1 face in 150), but never a part the old body has only small pieces of
        clean_islands_min(new, max(30, n // 150), {mi for mi in everything
                                                  if sum(1 for p in old.data.polygons if p.material_index == mi)
                                                  < 0.01 * len(old.data.polygons)})

    def clean_islands_min(ob, small, protect):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.faces.ensure_lookup_table()
        seen = set()
        for f in bm.faces:
            if f.index in seen:
                continue
            island, stack = [], [f]
            seen.add(f.index)
            while stack:
                g = stack.pop()
                island.append(g)
                for e in g.edges:
                    for k in e.link_faces:
                        if k.index not in seen and k.material_index == f.material_index:
                            seen.add(k.index)
                            stack.append(k)
            if len(island) < small and f.material_index not in protect:
                ring = {}
                for g in island:
                    for e in g.edges:
                        for k in e.link_faces:
                            if k.material_index != f.material_index:
                                ring[k.material_index] = ring.get(k.material_index, 0) + 1
                if ring:
                    mi = max(ring, key=ring.get)
                    for g in island:
                        g.material_index = mi
        bm.to_mesh(ob.data)
        bm.free()

    def float_kept(kept, old, new, mats, keep, h):
        """Moves each kept piece (an eye, glasses, a mouth) out or in along its own facing so it sits on the AI's
        surface as it sat on the old one: where the AI's face is fuller, eyes kept where they were end up buried."""
        body = bmesh.new()
        for p in old.data.polygons:
            mt = mats[p.material_index]
            if mt is not None and mt.name not in keep:
                body.faces.new([body.verts.new(old.data.vertices[v].co) for v in p.vertices])
        old_tree = BVHTree.FromBMesh(body)
        body.free()
        new_tree = BVHTree.FromObject(new, bpy.context.evaluated_depsgraph_get())
        bm = bmesh.new()
        bm.from_mesh(kept.data)
        bm.verts.ensure_lookup_table()
        seen = set()
        moved = 0
        # Pieces near each other move together (an eye's white, iris and shine are separate pieces)
        pieces = []
        for v in bm.verts:
            if v.index in seen:
                continue
            stack, piece = [v], []
            seen.add(v.index)
            while stack:
                a = stack.pop()
                piece.append(a)
                for e in a.link_edges:
                    b = e.other_vert(a)
                    if b.index not in seen:
                        seen.add(b.index)
                        stack.append(b)
            pieces.append(piece)
        # Union pieces whose middles are close (an eye's layers, a brow over it), so they move as one
        cs = [sum((v.co for v in piece), Vector()) / len(piece) for piece in pieces]
        root = list(range(len(pieces)))

        def find(i):
            while root[i] != i:
                root[i] = root[root[i]]
                i = root[i]
            return i
        for i in range(len(pieces)):
            for j in range(i + 1, len(pieces)):
                if (cs[i] - cs[j]).length < 0.07 * h:
                    root[find(i)] = find(j)
        merged = {}
        for i, piece in enumerate(pieces):
            merged.setdefault(find(i), []).extend(piece)
        groups = [{"verts": vs} for vs in merged.values()]
        for g in groups:
            vs = g["verts"]
            c = sum((v.co for v in vs), Vector()) / len(vs)
            n = sum((v.normal for v in vs), Vector())
            if n.length < 1e-6:
                continue
            n.normalize()
            start = c + n * 0.15 * h
            a = old_tree.ray_cast(start, -n, 0.4 * h)
            b = new_tree.ray_cast(start, -n, 0.4 * h)
            if a[0] is None or b[0] is None:
                continue
            d = (b[0] - a[0]).dot(n)
            if abs(d) > 0.08 * h:
                continue
            for v in vs:
                v.co += n * d
            moved += 1
        bm.to_mesh(kept.data)
        bm.free()
        print("AI kept pieces moved onto the new surface:", moved, "of", len(groups))

    def export_to(name, tag, path):
        m = MODELS[name]
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / "source_art/characters/ai" / (Path(m["blend"]).stem + tag + ".blend")))
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_renderable=True,
                                  export_apply=True, export_cameras=False, export_lights=False, export_yup=True,
                                  export_animations=True)
        print("AI exported", name, tag, path)

    # ------------------------------------------------------------------------------------------------- fit: character
    def fit_character(name, raw="raw.glb", mode="nearest", tag="", keep_head="auto"):
        m = MODELS[name]
        clean()
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / m["blend"]))
        old = D.objects[m["body"]]
        rig = D.objects[m["rig"]]
        rig.data.pose_position = "REST"
        bpy.context.view_layer.update()
        mats = [s.material for s in old.material_slots]
        keep = set(m["keep"])
        lo, hi = bounds([old])
        # The parts kept as they were: a copy of the old body with every other face deleted
        kept = old.copy()
        kept.data = old.data.copy()
        bpy.context.scene.collection.objects.link(kept)
        bm = bmesh.new()
        bm.from_mesh(kept.data)
        gone = [f for f in bm.faces if mats[f.material_index] is None or mats[f.material_index].name not in keep]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bm.to_mesh(kept.data)
        bm.free()
        old_tris = tris(old) - tris(kept)
        # The AI's shape, lined up with the old body and cut down to its budget
        new = join(import_glb(work(name) / raw), m["body"] + " AI")
        # Region mode matches width and depth too (the AI drew Nina's arms a quarter longer than hers)
        fit_to(new, lo, hi, per_axis=(mode == "region"))
        cut = trim(new, lo, hi)
        cut += trim_floor(new, old, lo, hi)
        # The face check: how far the old face's front is from the AI's surface. The AI sometimes draws the whole face
        # somewhere else (Mr. Palmer's sits lower, his glasses on his nose); then the old head is kept as it was and
        # the AI only gives the body and clothes.
        h = hi.z - lo.z
        bones = dominant_bones(old)
        head_faces = {p.index for p, b in zip(old.data.polygons, bones) if b == m.get("head_bone", "head")}
        off = face_offset(old, new, head_faces, mats, keep)
        use_head = keep_head == "yes" or (keep_head == "auto" and off > FACE_OFF_MAX * h)
        print("AI face check: the old face is %.1f%% of the height from the AI's (%s)"
              % (100 * off / h, "keeping the old head" if use_head else "the AI's face is used"))
        if use_head:
            bm = bmesh.new()
            bm.from_mesh(old.data)
            bm.faces.ensure_lookup_table()
            gone = [f for f in bm.faces if f.index not in head_faces and
                    (mats[f.material_index] is None or mats[f.material_index].name not in keep)]
            bmesh.ops.delete(bm, geom=gone, context="FACES")
            bm.to_mesh(kept.data)
            bm.free()
            old_tris = tris(old) - tris(kept)
            cut_head(new, old, head_faces, h)
        # Region painting works on a finer mesh (so the borders between parts are smooth) and cuts down afterwards
        decimate(new, max(old_tris, 2000) * (4 if mode in ("region", "picture", "picture_absorb") else 1))
        new.data.materials.clear()
        for mt in mats:
            new.data.materials.append(mt)
        if mode == "region":
            # Weights from the rig's bones themselves (Blender's bone heat, as Rolo has): the old weights by nearest
            # surface go wrong where the AI's limbs aren't where the old ones were (Nina's hands took her hair's)
            bpy.ops.object.select_all(action="DESELECT")
            new.select_set(True)
            rig.select_set(True)
            bpy.context.view_layer.objects.active = rig
            bpy.ops.object.parent_set(type="ARMATURE_AUTO")
            for mod in list(new.modifiers):
                new.modifiers.remove(mod)
            mw = new.matrix_world.copy()
            new.parent = None
            new.matrix_world = mw
        else:
            # The old weights, by nearest surface
            dt = new.modifiers.new("Weights", "DATA_TRANSFER")
            dt.object = old
            dt.use_vert_data = True
            dt.data_types_verts = {"VGROUP_WEIGHTS"}
            dt.vert_mapping = "POLYINTERP_NEAREST"
            bpy.context.view_layer.objects.active = new
            bpy.ops.object.datalayout_transfer(modifier="Weights")
            bpy.ops.object.modifier_apply(modifier="Weights")
        if mode in ("picture", "picture_absorb"):
            paint_by_picture(new, old, mats, keep, lo, hi, absorb=(mode == "picture_absorb"))
            decimate(new, max(old_tris, 2000) + (tris(kept) if mode == "picture_absorb" else 0))
            straighten_borders(new)
            if mode == "picture" and not use_head:
                flatten_under(new, old, mats, EYES + ["Glasses", "Lens Shine", "Brow", "Eye", "Lash"], hi.z - lo.z)
        elif mode == "region":
            paint_by_region(new, old, mats, keep, lo, hi)
            decimate(new, max(old_tris, 2000))
        else:
            # Each new face takes the nearest old face's material, ignoring the kept parts (an eye's material mustn't
            # spread over the face round it)
            bm = bmesh.new()
            bm.from_mesh(old.data)
            bm.faces.ensure_lookup_table()
            body_faces = [f for f in bm.faces if not (mats[f.material_index] and mats[f.material_index].name in keep)]
            sub = bmesh.new()
            idx = {}
            for f in body_faces:
                vs = [sub.verts.new(v.co) for v in f.verts]
                nf = sub.faces.new(vs)
                idx[len(idx)] = f.material_index
            sub.faces.ensure_lookup_table()
            tree = BVHTree.FromBMesh(sub)
            h = hi.z - lo.z
            for p in new.data.polygons:
                # Look for the old surface along the new face's own normal (a little in and out), taking only a face that
                # faces the same way: the nearest face alone often belongs to another layer (the sash under the suit,
                # metal under fur). The nearest face is the fallback.
                best = None
                for sign in (1, -1):
                    o = p.center + p.normal * (0.03 * h * sign)
                    hit = tree.ray_cast(o, -p.normal * sign, 0.06 * h)
                    if hit[2] is not None and hit[1].dot(p.normal) > 0.3 and (best is None or hit[3] < best[3]):
                        best = hit
                if best is None:
                    best = tree.find_nearest(p.center)
                if best[2] is not None:
                    p.material_index = idx[best[2]]
            bm.free()
            sub.free()
            smooth_materials(new)
            clean_islands(new)
        if mode == "picture_absorb":
            # The AI's own eyes, glasses and mouth are painted with those parts' colours instead
            D.objects.remove(kept)
        else:
            if not use_head:
                float_kept(kept, old, new, mats, keep, hi.z - lo.z)
            # Put the kept parts in, drop the old body, and the new one takes its name and place on the rig
            bpy.ops.object.select_all(action="DESELECT")
            new.select_set(True)
            kept.select_set(True)
            bpy.context.view_layer.objects.active = new
            for mod in list(kept.modifiers):
                kept.modifiers.remove(mod)
            kept.parent = None
            bpy.ops.object.join()
        D.objects.remove(old)
        new.name = new.data.name = m["body"]
        new.parent = rig
        new.matrix_parent_inverse = rig.matrix_world.inverted()
        mod = new.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        rig.data.pose_position = "POSE"
        out = ROOT / "source_art/characters/ai" / (Path(m["blend"]).stem + tag + ".blend")
        out.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(out))
        print("AI fit", name, "tris", tris(new), "(old", old_tris, "+ kept", tris(new) - old_tris, ")", "base faces cut", cut,
              "materials", len(new.data.materials), "->", out)

    # ------------------------------------------------------------------------------------------------- fit: prop
    def fit_prop(name, raw="raw.glb"):
        m = MODELS[name]
        clean()
        sc = bpy.context.scene
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.samples = 8
        olds = [o for o in import_glb(GAME / m["glb"]) if o.type == "MESH"]
        old = join(olds, "Old")
        omat = old.data.materials[0]
        lo, hi = bounds([old])
        high = join(import_glb(work(name) / raw), "High")
        fit_to(high, lo, hi, per_axis=True)
        trim(high, lo, hi)
        low = high.copy()
        low.data = high.data.copy()
        sc.collection.objects.link(low)
        low.name = low.data.name = Path(m["glb"]).stem
        decimate(low, min(tris(old) * 2, max(tris(old), 3000)))
        bpy.context.view_layer.objects.active = low
        bpy.ops.object.select_all(action="DESELECT")
        low.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
        bpy.ops.object.mode_set(mode="OBJECT")
        size = 1024
        imgs = {}
        new = D.materials.new(omat.name)
        new.use_nodes = True
        nt = new.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        low.data.materials.clear()
        low.data.materials.append(new)

        def target(key, non_color):
            img = D.images.new(f"{low.name}_{key}", size, size)
            img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = img
            for x in nt.nodes:
                x.select = False
            n.select = True
            nt.nodes.active = n
            imgs[key] = (img, n)
            return img

        def bake(kind, key, non_color, src, source_socket=None):
            target(key, non_color)
            undo = []
            if source_socket:
                # Show the old material's map as emission, so EMIT bakes it straight across
                ont = omat.node_tree
                out = next(n for n in ont.nodes if n.type == "OUTPUT_MATERIAL")
                prev = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
                em = ont.nodes.new("ShaderNodeEmission")
                ont.links.new(source_socket(ont), em.inputs["Color"])
                ont.links.new(em.outputs[0], out.inputs["Surface"])
                undo = [(ont, out, prev, em)]
            bpy.ops.object.select_all(action="DESELECT")
            src.select_set(True)
            low.select_set(True)
            bpy.context.view_layer.objects.active = low
            sc.render.bake.use_selected_to_active = True
            sc.render.bake.cage_extrusion = 0.04 * max(hi - lo)
            sc.render.bake.max_ray_distance = 0.12 * max(hi - lo)
            sc.render.bake.margin = 4
            if kind == "NORMAL":
                bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
            else:
                bpy.ops.object.bake(type="EMIT")
            for ont, out, prev, em in undo:
                if prev:
                    ont.links.new(prev, out.inputs["Surface"])
                ont.nodes.remove(em)

        def tex_socket(image_part):
            def f(ont):
                n = next(n for n in ont.nodes if n.type == "TEX_IMAGE" and n.image and n.image.name.endswith(image_part))
                return n.outputs["Color"]
            return f

        bake("EMIT", "color", False, old, tex_socket("_color"))
        bake("EMIT", "orm", True, old, tex_socket("_orm"))
        has_emit = any(n.type == "TEX_IMAGE" and n.image and n.image.name.endswith("_emit") for n in omat.node_tree.nodes)
        if has_emit:
            bake("EMIT", "emit", False, old, tex_socket("_emit"))
        bake("NORMAL", "normal", True, high)
        # Wire the new maps like bake_kit.py does (colour, normal map, ORM: occlusion, roughness, metal; glow)
        nt.links.new(imgs["color"][1].outputs["Color"], bsdf.inputs["Base Color"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(imgs["normal"][1].outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(imgs["orm"][1].outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        if has_emit:
            nt.links.new(imgs["emit"][1].outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 1.0
        for img, _ in imgs.values():
            img.pack()
        D.objects.remove(old)
        D.objects.remove(high)
        bpy.ops.object.select_all(action="DESELECT")
        low.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(GAME / m["glb"]), export_format="GLB", use_selection=True,
                                  export_cameras=False, export_lights=False, export_yup=True)
        print("AI fit", name, "tris", tris(low), "(old", tris(old) if False else "see inventory", ") ->", GAME / m["glb"])

    def export(name):
        m = MODELS[name]
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / "source_art/characters/ai" / (Path(m["blend"]).stem + ".blend")))
        bpy.ops.export_scene.gltf(filepath=str(GAME / m["glb"]), export_format="GLB", use_renderable=True,
                                  export_apply=True, export_cameras=False, export_lights=False, export_yup=True,
                                  export_animations=True)
        print("AI exported", name)

    return {"render": render,
            "fit": lambda n, raw="raw.glb", mode="nearest", tag="", keep_head="auto": (
                fit_character(n, raw, mode, tag, keep_head) if MODELS[n]["kind"] == "character" else fit_prop(n, raw)),
            "export_to": export_to,
            "export": export}


if __name__ == "__main__":
    try:
        import bpy  # noqa: F401
        a = sys.argv[sys.argv.index("--") + 1:]
        _bpy_steps()[a[0]](*a[1:])
    except ImportError:
        a = [x for x in sys.argv[1:] if not x.startswith("--")]
        steps = next((int(x.split("=")[1]) for x in sys.argv if x.startswith("--steps=")), 30)
        views = next((int(x.split("=")[1]) for x in sys.argv if x.startswith("--views=")), 1)
        if a[0] == "restore":
            restore(a[1])
        else:
            run(a[0], steps, views)

# The detailed props pipeline (15 Nov 2026). Hayden: "How do AAA games have such detailed assets that dont slow down
# my pc?" They model a prop in great detail, then pour that detail into textures on a light copy ("baking"), and the
# engine swaps in lighter copies further away (levels of detail). This file is the shared kit for doing that in
# Blender from code, like char_kit.py is for the characters:
#
#   1. a prop's build script makes a HIGH version (as detailed as we like: flutes, scrolls, rivets, wood grain,
#      chipped paint, made with real geometry and Blender's procedural textures),
#   2. and a LOW version: the same silhouette in a few hundred to a few thousand triangles, one material, UVs,
#   3. bake() casts rays from the low copy onto the high one and writes what it finds into textures: a normal map
#      (the carved shapes, so light falls on them as if they were there), ambient occlusion (the dark in the cracks),
#      base colour, roughness, metalness and glow,
#   4. export() writes only the low copy, with those textures, to a .glb. Godot makes its own lighter LOD copies
#      when it imports it (Import > Meshes > Generate LODs is on by default), so nothing else is needed for distance.
#
# What we compared first (Hayden's rule: look at open source before building): GarikDog/autobake_tools (Apache 2.0,
# bakes a bevel shader to a normal map on the same mesh, AO in a second pass), leukbaars/EasyBake and
# danielenger/Principled-Baker (selected-to-active high to low baking with a cage, one pass per map). Ours follows the
# selected-to-active way, because our high versions are different meshes from the low ones, and borrows the
# "emission trick" these add-ons use for maps Cycles can't bake directly (base colour, metalness): each material's
# input is wired to an emission shader for its pass, then wired back.
#
# Run with Blender 4.5 (or pip bpy 4.5 in Python 3.11), e.g.:
#   blender -b --python tools/build_prop_lamp.py -- "Godot Project/my-world/models/props/street_lamp.glb"

import math
import sys
from pathlib import Path

import bpy  # first: with pip bpy, bmesh only exists after bpy is loaded
import bmesh
from mathutils import Vector, Matrix

D = bpy.data


def out_path(default):
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = [a for a in args if not a.startswith("--")]
    return Path(args[0] if args else default).resolve()


def has_flag(name):
    return ("--" + name) in sys.argv


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.bake.margin = 8
    scene.render.bake.margin_type = "EXTEND"
    return scene


# ---------------------------------------------------------------- materials
def _rgba(sockets, name):
    for sk in sockets:
        if sk.name == name and sk.type == "RGBA":
            return sk
    return sockets[name]


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, rough=0.6, metal=0.0, emit=0.0, emit_rgb=None, grain=None, pits=0.0, wear=0.0, bump=0.0):
    """A Principled material. Extra detail that only the high version has, all procedural (it gets baked):
    grain=(scale, strength) wood grain stripes in the colour, pits=strength little dents in roughness,
    wear=strength lighter worn edges (from the pointiness of the mesh), bump=strength of a fine noise bump."""
    # Colours are written the way the Godot builders write them (sRGB, as in Color(0.45, 0.25, 0.22)), so a baked
    # prop matches the builder's pieces round it; Blender's colour inputs are linear, so convert.
    rgb = tuple(srgb_to_linear(c) for c in rgb)
    if emit_rgb:
        emit_rgb = tuple(srgb_to_linear(c) for c in emit_rgb)
    m = D.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*(emit_rgb or rgb), 1.0)
        b.inputs["Emission Strength"].default_value = emit
    col_out = None
    if grain:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "X"
        wave.inputs["Scale"].default_value = grain[0]
        wave.inputs["Distortion"].default_value = 6.0
        wave.inputs["Detail"].default_value = 3.0
        nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*[c * (1.0 - grain[1]) for c in rgb], 1)
        ramp.color_ramp.elements[1].color = (*[min(1.0, c * (1.0 + grain[1] * 0.4)) for c in rgb], 1)
        nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
        col_out = ramp.outputs["Color"]
    if wear:
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        ramp2 = nt.nodes.new("ShaderNodeValToRGB")
        ramp2.color_ramp.elements[0].position = 0.5
        ramp2.color_ramp.elements[1].position = 0.56
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        # the Mix node has float, vector and colour sockets all called A/B/Result: use the colour ones
        a_in, b_in = _rgba(mix.inputs, "A"), _rgba(mix.inputs, "B")
        nt.links.new(geo.outputs["Pointiness"], ramp2.inputs["Fac"])
        nt.links.new(ramp2.outputs["Color"], mix.inputs["Factor"])
        if col_out:
            nt.links.new(col_out, a_in)
        else:
            a_in.default_value = (*rgb, 1)
        b_in.default_value = (*[min(1.0, c + wear) for c in rgb], 1)
        col_out = _rgba(mix.outputs, "Result")
    if col_out:
        nt.links.new(col_out, b.inputs["Base Color"])
    if pits:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 60.0
        noise.inputs["Detail"].default_value = 6.0
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["To Min"].default_value = max(0.0, rough - pits)
        mr.inputs["To Max"].default_value = min(1.0, rough + pits)
        nt.links.new(noise.outputs["Fac"], mr.inputs["Value"])
        nt.links.new(mr.outputs["Result"], b.inputs["Roughness"])
    if bump:
        noise2 = nt.nodes.new("ShaderNodeTexNoise")
        noise2.inputs["Scale"].default_value = 140.0
        noise2.inputs["Detail"].default_value = 8.0
        bn = nt.nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        bn.inputs["Distance"].default_value = 0.002
        nt.links.new(noise2.outputs["Fac"], bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


# ---------------------------------------------------------------- shapes
def _obj(name, bm, m=None, smooth=True, col=None):
    me = D.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = D.objects.new(name, me)
    (col or bpy.context.scene.collection).objects.link(ob)
    if m is not None:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = smooth
    return ob


def lathe(name, profile, seg=32, m=None, at=(0, 0, 0), smooth=True, flutes=0, flute_depth=0.0, flute_z=(0, 0),
          sides=0, col=None):
    """Spins a profile [(radius, z), ...] round Z. flutes=n cuts n rounded grooves between flute_z[0] and [1].
    sides=n makes it n-sided (an octagon for sides=8) instead of round."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for k in range(seg):
            a = k / seg * math.tau
            rr = r
            if sides:
                # a regular polygon: radius to the edge at this angle
                half = math.pi / sides
                ang = (a + half) % (2 * half) - half
                rr = r * math.cos(half) / math.cos(ang)
            if flutes and flute_z[0] <= z <= flute_z[1]:
                rr -= flute_depth * max(0.0, math.cos(a * flutes)) ** 2
            ring.append(bm.verts.new((at[0] + math.cos(a) * rr, at[1] + math.sin(a) * rr, at[2] + z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            a, b = rings[i][k], rings[i][(k + 1) % seg]
            c, d = rings[i + 1][(k + 1) % seg], rings[i + 1][k]
            bm.faces.new((a, b, c, d))
    # caps
    if profile[0][0] > 0.0005:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 0.0005:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, m, smooth, col)


def box(name, size, at=(0, 0, 0), m=None, bevel=0.0, seg=2, rot=(0, 0, 0), col=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = _obj(name, bm, m, smooth=False, col=col)
    ob.location = at
    ob.rotation_euler = rot
    if bevel:
        bv = ob.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel
        bv.segments = seg
        bv.limit_method = "ANGLE"
        ob.modifiers.new("WN", "WEIGHTED_NORMAL").keep_sharp = True
    return ob


def cyl(name, r, h, at=(0, 0, 0), seg=16, m=None, rot=(0, 0, 0), col=None, r2=None, smooth=True):
    ob = lathe(name, [(0.0, -h / 2), (r, -h / 2), (r2 if r2 is not None else r, h / 2), (0.0, h / 2)], seg, m,
               smooth=smooth, col=col)
    ob.location = at
    ob.rotation_euler = rot
    return ob


def sphere(name, r, at=(0, 0, 0), m=None, seg=16, scale=(1, 1, 1), col=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(4, seg // 2), radius=r)
    ob = _obj(name, bm, m, col=col)
    ob.location = at
    ob.scale = scale
    return ob


def wire(name, pts, r, m=None, closed=False, res=12, bevel_res=4, col=None):
    """A round bar along a smooth curve through pts (cast-iron scrolls, railings)."""
    cu = D.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = bevel_res
    cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1.0)
    sp.use_endpoint_u = not closed
    sp.use_cyclic_u = closed
    sp.order_u = 3
    ob = D.objects.new(name, cu)
    (col or bpy.context.scene.collection).objects.link(ob)
    if m:
        cu.materials.append(m)
    return ob


def scroll(cx, cz, r0, turns, y=0.0, flip=1.0, steps=24, plane="xz"):
    """Points of a flat spiral (the curl of a cast-iron scroll), in the x/z plane at y."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * math.tau
        r = r0 * (1.0 - t * 0.85)
        if plane == "xz":
            pts.append((cx + math.cos(a) * r * flip, y, cz + math.sin(a) * r))
        else:
            pts.append((y, cx + math.cos(a) * r * flip, cz + math.sin(a) * r))
    return pts


def to_mesh(ob):
    """Applies modifiers / converts a curve, so the object is a plain mesh."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.view_layer.objects.active


def join(name, obs):
    obs = [to_mesh(o) for o in obs]
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def tri_count(obs):
    deps = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in obs:
        if o.type not in ("MESH", "CURVE"):
            continue
        me = o.evaluated_get(deps).to_mesh()
        me.calc_loop_triangles()
        n += len(me.loop_triangles)
        o.evaluated_get(deps).to_mesh_clear()
    return n


# ---------------------------------------------------------------- baking
def _image(name, size, non_color=False, alpha=False):
    img = D.images.new(name, size, size, alpha=alpha, float_buffer=False)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return img


def _target(low, img):
    """Makes img the bake target on every material of the low object (the active image node)."""
    for m in low.data.materials:
        nt = m.node_tree
        node = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = img
        for n in nt.nodes:
            n.select = False
        node.select = True
        nt.nodes.active = node


def _rewire(highs, socket):
    """The emission trick: each high material's <socket> input (its link or plain value) drives an emission shader
    plugged into the output, so an EMIT bake records just that input. Returns how to put things back."""
    undo = []
    seen = set()
    for o in highs:
        for slot in o.material_slots:
            m = slot.material
            if m is None or m.name in seen:
                continue
            seen.add(m.name)
            nt = m.node_tree
            b = nt.nodes.get("Principled BSDF")
            out = nt.nodes.get("Material Output")
            old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
            em = nt.nodes.new("ShaderNodeEmission")
            em.name = "_bake_emit"
            em.inputs["Strength"].default_value = 1.0
            src = b.inputs[socket]
            if socket == "Emission Color":
                # glow = colour x strength (strength is above 1 for lamps; clamp into the texture's 0..1)
                em.inputs["Strength"].default_value = min(1.0, b.inputs["Emission Strength"].default_value)
            if src.links:
                nt.links.new(src.links[0].from_socket, em.inputs["Color"])
            else:
                v = src.default_value
                if isinstance(v, float):
                    em.inputs["Color"].default_value = (v, v, v, 1.0)
                else:
                    em.inputs["Color"].default_value = tuple(v)
            nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
            undo.append((m, old, em))
    return undo


def _restore(undo):
    for m, old, em in undo:
        nt = m.node_tree
        out = nt.nodes.get("Material Output")
        if old is not None:
            nt.links.new(old, out.inputs["Surface"])
        nt.nodes.remove(em)


def uv_unwrap(low, margin=0.01):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0, correct_aspect=True,
                             scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(low, highs, size=1024, name="prop", extrusion=0.03, ray=0.12, ao_samples=48, maps=None):
    """Bakes the high objects onto the low one. Returns {map: image}. maps: which ones (default all):
    normal, ao, color, rough, metal, emit."""
    scene = bpy.context.scene
    maps = maps or ["normal", "ao", "color", "rough", "metal", "emit"]
    highs = [to_mesh(h) for h in highs]
    # Thousands of little objects (balusters, shingles, beads) make every bake pass spend most of its time loading
    # the scene, so join them first: one object per material bakes the same and far quicker.
    by_mat = {}
    for h in highs:
        key = h.data.materials[0].name if h.data.materials else ""
        by_mat.setdefault(key, []).append(h)
    highs = [join("High " + k, group) if len(group) > 1 else group[0] for k, group in by_mat.items()]
    b = scene.render.bake
    b.use_selected_to_active = True
    b.cage_extrusion = extrusion
    b.max_ray_distance = ray
    out = {}

    def run(kind, img, **kw):
        _target(low, img)
        bpy.ops.object.select_all(action="DESELECT")
        for h in highs:
            h.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active = low
        bpy.ops.object.bake(type=kind, **kw)

    if "normal" in maps:
        scene.cycles.samples = 8
        img = _image(name + "_normal", size, non_color=True)
        run("NORMAL", img, normal_space="TANGENT")
        out["normal"] = img
    if "ao" in maps:
        scene.cycles.samples = ao_samples
        img = _image(name + "_ao", size, non_color=True)
        run("AO", img)
        out["ao"] = img
    scene.cycles.samples = 4
    for key, socket, non_color in [("color", "Base Color", False), ("rough", "Roughness", True),
                                   ("metal", "Metallic", True), ("emit", "Emission Color", False)]:
        if key not in maps:
            continue
        undo = _rewire(highs, socket)
        img = _image(name + "_" + key, size, non_color=non_color)
        run("EMIT", img)
        _restore(undo)
        out[key] = img
    return out


def _orm(maps, size, name):
    """Packs occlusion (R), roughness (G) and metalness (B) into one texture, as glTF and Godot's ORM expect."""
    import numpy as np
    img = _image(name + "_orm", size, non_color=True)
    n = size * size * 4
    px = np.ones(n, dtype=np.float32)

    def chan(key, default):
        if key in maps:
            a = np.empty(n, dtype=np.float32)
            maps[key].pixels.foreach_get(a)
            return a[0::4]
        return np.full(size * size, default, dtype=np.float32)
    px[0::4] = chan("ao", 1.0)
    px[1::4] = chan("rough", 0.6)
    px[2::4] = chan("metal", 0.0)
    img.pixels.foreach_set(px)
    return img


def finish(low, maps, size, name, emit_strength=1.0):
    """Gives the low object one material using the baked textures (packed into the .glb on export)."""
    orm = _orm(maps, size, name)
    m = D.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t_col = nt.nodes.new("ShaderNodeTexImage")
    t_col.image = maps["color"]
    nt.links.new(t_col.outputs["Color"], b.inputs["Base Color"])
    t_orm = nt.nodes.new("ShaderNodeTexImage")
    t_orm.image = orm
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(t_orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], b.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], b.inputs["Metallic"])
    # glTF's occlusion goes through a node group the exporter knows by name
    grp = D.node_groups.get("glTF Material Output") or D.node_groups.new("glTF Material Output", "ShaderNodeTree")
    if not grp.interface.items_tree:
        grp.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    g = nt.nodes.new("ShaderNodeGroup")
    g.node_tree = grp
    nt.links.new(sep.outputs["Red"], g.inputs["Occlusion"])
    if "normal" in maps:
        t_n = nt.nodes.new("ShaderNodeTexImage")
        t_n.image = maps["normal"]
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t_n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    if "emit" in maps:
        t_e = nt.nodes.new("ShaderNodeTexImage")
        t_e.image = maps["emit"]
        nt.links.new(t_e.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emit_strength
    low.data.materials.clear()
    low.data.materials.append(m)
    return m


def export(objs, path, blend=None):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False, export_animations=False,
                              export_image_format="AUTO")
    if blend:
        bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    print("EXPORTED", path)


def new_collection(name, hide=False):
    c = D.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    c.hide_render = hide
    return c


def export_high_preview(collection, path):
    """For before/after pictures only: the HIGH version as its own .glb (never used by the game)."""
    obs = [o for o in collection.all_objects if o.type in ("MESH", "CURVE")]
    obs = [to_mesh(o) for o in obs]
    for m in D.materials:
        b = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
        if b is None:
            continue
        for sk in ("Base Color", "Roughness"):
            for l in list(b.inputs[sk].links):
                m.node_tree.links.remove(l)
    export(obs, path)

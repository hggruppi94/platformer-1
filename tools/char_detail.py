# Baked-in detail for the characters (16 Nov 2026; Hayden, after the props: "i want you to try this on a character.
# lets start with nina"). The props got their detail by baking a HIGH model onto a LOW one (tools/bake_kit.py). A
# character is different: everything in the game leans on her mesh as it is (her rig and animations, Clothes.fit_of()
# measuring her body for every hat and back piece, Hero.apply() and the wardrobe recolouring her parts by material
# name). So her shape, bones, weights and materials stay exactly as built, and the detail goes into three textures
# laid over all of them through one new UV map ("Detail"):
#
#   - a normal map: knit and twill in the cloth, strands in the hair, pores in the skin, soft creases (made from
#     procedural bump in each material: the bevel-and-bump-to-normal way GarikDog/autobake_tools bakes, on her own
#     mesh, so there's no second high mesh to line up with her many overlapping parts),
#   - ambient occlusion: the dark in the creases, under the straps and the backpack, round the hair and the eyes,
#   - a "tint": a grey multiplier (about 0.8 to 1.0) for faded denim, hair streaks, mottled skin. It's multiplied
#     with each material's own colour, so the wardrobe can still recolour a part and keep its detail.
#
# Faces that must stay crisp (eyes, mouth, teeth) get none of it. The .glb is exported from the .blend as before
# (tools/export_glb.py's settings), then the three textures are put into it straight (add_textures()), which keeps
# every other byte of the export as Blender wrote it.
#
# Run with Blender 4.5 or pip bpy 4.5; see build_nina_detail.py.

import json
import math
import struct
import sys
from pathlib import Path

import bpy  # first: with pip bpy, bmesh only exists after bpy is loaded

D = bpy.data
UV = "Detail"


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    return [x for x in a if not x.startswith("--")]


def has_flag(name):
    return ("--" + name) in sys.argv


def open_blend(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.bake.margin = 6
    scene.render.bake.margin_type = "EXTEND"
    scene.render.bake.use_selected_to_active = False
    return scene


def unwrap(body, margin=0.002):
    """A second UV map just for the detail, packed by surface area so every part gets the same texel size."""
    me = body.data
    uv = me.uv_layers.new(name=UV)
    me.uv_layers.active = uv
    uv.active_render = True
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def export_glb(path):
    """The same settings as tools/export_glb.py, so the model is what the game always had (plus the UVs)."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_renderable=True, export_apply=True,
                              export_cameras=False, export_lights=False, export_yup=True, export_animations=True)
    print("EXPORTED", path)


# ---------------------------------------------------------------- procedural detail, as node chains
class Nodes:
    """Little helpers that build texture node chains in one material. Every pattern is in object space (metres)."""

    def __init__(self, m):
        self.nt = m.node_tree
        self.co = self.nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]

    def new(self, kind, **inputs):
        n = self.nt.nodes.new(kind)
        for k, v in inputs.items():
            if hasattr(v, "is_linked") or hasattr(v, "links"):
                self.nt.links.new(v, n.inputs[k])
            else:
                n.inputs[k].default_value = v
        return n

    def math(self, op, a, b=0.0):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation = op
        for i, v in enumerate((a, b)):
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                self.nt.links.new(v, n.inputs[i])
        return n.outputs[0]

    def add(self, *xs):
        out = xs[0]
        for x in xs[1:]:
            out = self.math("ADD", out, x)
        return out

    def mul(self, a, b):
        return self.math("MULTIPLY", a, b)

    def noise(self, size, detail=3.0, rough=0.5, distortion=0.0, vec=None):
        """Soft blobs about `size` metres across."""
        n = self.new("ShaderNodeTexNoise", Vector=vec or self.co, Scale=1.0 / size, Detail=detail,
                     Roughness=rough, Distortion=distortion)
        return n.outputs["Fac"]

    def wave(self, period, direction="X", distortion=0.0, detail=2.0, vec=None, profile="SIN"):
        """Parallel ridges `period` metres apart (Blender's bands go round 20 times a unit at scale 1)."""
        n = self.nt.nodes.new("ShaderNodeTexWave")
        n.wave_type = "BANDS"
        n.bands_direction = direction
        n.wave_profile = profile
        self.nt.links.new(vec or self.co, n.inputs["Vector"])
        n.inputs["Scale"].default_value = 2 * math.pi / 20.0 / period
        n.inputs["Distortion"].default_value = distortion
        n.inputs["Detail"].default_value = detail
        return n.outputs["Fac"]

    def cells(self, size, feature="F1", vec=None):
        n = self.nt.nodes.new("ShaderNodeTexVoronoi")
        n.feature = feature
        self.nt.links.new(vec or self.co, n.inputs["Vector"])
        n.inputs["Scale"].default_value = 1.0 / size
        return n.outputs["Distance"]

    def around(self, centre, radius, height_scale=1.0):
        """Coordinates wrapped round a vertical axis through centre: x = distance round (m at `radius`), z = height.
        Strands of hair run along z, so bands in x make them."""
        sep = self.new("ShaderNodeSeparateXYZ", Vector=self.co)
        dx = self.math("SUBTRACT", sep.outputs["X"], centre[0])
        dy = self.math("SUBTRACT", sep.outputs["Y"], centre[1])
        ang = self.math("ARCTAN2", dx, dy)
        comb = self.new("ShaderNodeCombineXYZ", X=self.mul(ang, radius), Y=0.0,
                        Z=self.mul(self.math("SUBTRACT", sep.outputs["Z"], centre[2]), height_scale))
        return comb.outputs["Vector"]

    def ramp(self, x, lo, hi):
        """Maps 0..1 to lo..hi."""
        n = self.new("ShaderNodeMapRange", Value=x)
        n.inputs["To Min"].default_value = lo
        n.inputs["To Max"].default_value = hi
        n.clamp = True
        return n.outputs["Result"]

    def sharpen(self, x, a, b):
        """Maps a..b to 0..1 (clamped): turns soft noise into crisp lines or spots."""
        n = self.new("ShaderNodeMapRange", Value=x)
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        n.clamp = True
        return n.outputs["Result"]


def dress(m, recipe):
    """Builds a material's detail from its recipe: recipe(N) returns (height, depth, tint), where height is a float
    socket going about 0..1, depth how many metres that is on her (a fraction of a millimetre for cloth), and tint a
    float socket (or a number) between about 0.8 and 1.0. Wires the bump to the Principled BSDF's Normal and keeps the tint ready for
    the tint bake."""
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    N = Nodes(m)
    height, depth, tint = recipe(N)
    if height is not None:
        bump = N.new("ShaderNodeBump", Height=height, Strength=1.0, Distance=depth)
        nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    t = nt.nodes.new("ShaderNodeValue") if isinstance(tint, (int, float)) else None
    if t is not None:
        t.outputs[0].default_value = tint
        tint = t.outputs[0]
    m["_tint"] = True
    # remembered by name so the tint bake can find it
    holder = nt.nodes.new("ShaderNodeMath")
    holder.name = "_tint"
    holder.operation = "ADD"
    nt.links.new(tint, holder.inputs[0])
    holder.inputs[1].default_value = 0.0


def flat(m):
    """No detail for this one (eyes, mouth): its bump stays flat and its tint white, and add_textures() skips it."""
    m["_flat"] = True


# ---------------------------------------------------------------- baking
def _image(name, size, non_color, fill):
    img = D.images.new(name, size, size, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    img.generated_color = fill
    return img


def _target(body, img):
    for m in body.data.materials:
        nt = m.node_tree
        node = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = img
        for n in nt.nodes:
            n.select = False
        node.select = True
        nt.nodes.active = node


def _emit_tint(body):
    undo = []
    for m in body.data.materials:
        nt = m.node_tree
        out = nt.nodes.get("Material Output")
        old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
        em = nt.nodes.new("ShaderNodeEmission")
        tint = nt.nodes.get("_tint")
        if tint is not None:
            nt.links.new(tint.outputs[0], em.inputs["Color"])
        else:
            em.inputs["Color"].default_value = (1, 1, 1, 1)
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
        undo.append((nt, out, old, em))
    return undo


def bake(body, rig, size=2048, name="char", ao_distance=0.025, ao_samples=48):
    scene = bpy.context.scene
    rig.data.pose_position = "REST"        # bake her standing as built, not mid-animation
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    out = {}
    scene.cycles.samples = 4
    img = _image(name + "_normal", size, True, (0.5, 0.5, 1.0, 1.0))
    _target(body, img)
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", uv_layer=UV)
    out["normal"] = img
    scene.cycles.samples = ao_samples
    img = _image(name + "_ao", size, True, (1, 1, 1, 1))
    _target(body, img)
    scene.world = scene.world or D.worlds.new("World")
    scene.world.light_settings.distance = ao_distance
    bpy.ops.object.bake(type="AO", uv_layer=UV)
    out["ao"] = img
    scene.cycles.samples = 4
    undo = _emit_tint(body)
    img = _image(name + "_tint", size, False, (1, 1, 1, 1))
    _target(body, img)
    bpy.ops.object.bake(type="EMIT", uv_layer=UV)
    for nt, outn, old, em in undo:
        if old is not None:
            nt.links.new(old, outn.inputs["Surface"])
        nt.nodes.remove(em)
    out["tint"] = img
    return out


def save_png(img, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    return path


# ---------------------------------------------------------------- putting the textures into the .glb
def _read_glb(path):
    b = Path(path).read_bytes()
    off = 12
    js, binc = None, b""
    while off < len(b):
        ln, kind = struct.unpack("<II", b[off:off + 8])
        chunk = b[off + 8:off + 8 + ln]
        if kind == 0x4E4F534A:
            js = json.loads(chunk)
        elif kind == 0x004E4942:
            binc = chunk
        off += 8 + ln
    return js, bytearray(binc)


def _write_glb(path, js, binc):
    jb = json.dumps(js, separators=(",", ":")).encode()
    jb += b" " * (-len(jb) % 4)
    binc += b"\0" * (-len(binc) % 4)
    total = 12 + 8 + len(jb) + 8 + len(binc)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A) + jb)
        f.write(struct.pack("<II", len(binc), 0x004E4942) + bytes(binc))


def add_textures(glb, pngs, flat_names, name):
    """Gives every material not in flat_names the detail textures: tint as the base colour texture (its factor, the
    material's own colour, is kept), the normal map and the occlusion. Every primitive must have TEXCOORD_0 (the
    Detail UVs: they're the only UV map)."""
    js, binc = _read_glb(glb)
    for mesh in js["meshes"]:
        for p in mesh["primitives"]:
            assert "TEXCOORD_0" in p["attributes"], "a part has no UVs"
    js.setdefault("images", [])
    js.setdefault("textures", [])
    js.setdefault("samplers", []).append({"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071})
    sampler = len(js["samplers"]) - 1
    tex = {}
    for key in ("tint", "normal", "ao"):
        data = Path(pngs[key]).read_bytes()
        binc += b"\0" * (-len(binc) % 4)
        js["bufferViews"].append({"buffer": 0, "byteOffset": len(binc), "byteLength": len(data)})
        binc += data
        js["images"].append({"name": f"detail_{key}", "mimeType": "image/png", "bufferView": len(js["bufferViews"]) - 1})
        js["textures"].append({"sampler": sampler, "source": len(js["images"]) - 1})
        tex[key] = len(js["textures"]) - 1
    js["buffers"][0]["byteLength"] = len(binc)
    done = []
    for m in js["materials"]:
        if m.get("name") in flat_names:
            continue
        pbr = m.setdefault("pbrMetallicRoughness", {})
        pbr["baseColorTexture"] = {"index": tex["tint"]}
        m["normalTexture"] = {"index": tex["normal"]}
        m["occlusionTexture"] = {"index": tex["ao"]}
        done.append(m.get("name"))
    _write_glb(glb, js, binc)
    return done

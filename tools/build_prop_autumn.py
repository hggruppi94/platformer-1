# Stars Hollow's little autumn things, built the detailed way (tools/bake_kit.py; 16 Nov 2026, Hayden: "give
# everything the baked in details"): a pumpkin with deep ribs, lumps and a curly stem, a jack-o'-lantern with a face
# really carved through it and a candle glow inside, a scarecrow in a plaid shirt with a burlap sack head, a rope belt
# and straw poking out everywhere, and a mailbox on its post with a domed lid, a door, a flag and rivets. Each HIGH
# version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the builder's pieces (tools/build_earth.gd _pumpkin, _jack, _scarecrow, _mailbox) so the swap
# (scripts/detail_props.gd) puts each exactly where the old one was. The pumpkins are made for a radius of 1 (the
# builder's ball of radius r squashed to 1.15 x 0.8 x 1.15, its middle 0.7 r up); the game scales them by r. Fronts
# face Godot's +Z, which is Blender's -Y. Colours are the builder's (sRGB). Collisions and labels stay the builder's.
#
#   python tools/build_prop_autumn.py "<out>.glb" <pumpkin|jack|scarecrow|mailbox> [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402

KINDS = ["pumpkin", "jack", "scarecrow", "mailbox"]
KIND = next((a for a in sys.argv if a in KINDS), "pumpkin")
NAME = {"pumpkin": "pumpkin", "jack": "jack_o_lantern", "scarecrow": "scarecrow", "mailbox": "mailbox"}[KIND]
OUT = K.out_path(NAME + ".glb")
random.seed(KINDS.index(KIND) * 31 + 5)

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")


def plaid(name, base, line, cross, rough=0.85, scale=9.0):
    """A plaid cloth: K.mat's material with two sets of bands (across and down) laid over the base colour."""
    m = K.mat(name, base, rough=rough, bump=0.2)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    col = (*[K.srgb_to_linear(c) for c in base], 1)
    for i, (axis, colour) in enumerate([("X", line), ("Z", cross)]):
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = scale
        nt.links.new(sep.outputs[axis], mul.inputs[0])
        frac = nt.nodes.new("ShaderNodeMath")
        frac.operation = "FRACT"
        nt.links.new(mul.outputs[0], frac.inputs[0])
        lt = nt.nodes.new("ShaderNodeMath")
        lt.operation = "LESS_THAN"
        lt.inputs[1].default_value = 0.22
        nt.links.new(frac.outputs[0], lt.inputs[0])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(lt.outputs[0], mix.inputs["Factor"])
        a_in, b_in = K._rgba(mix.inputs, "A"), K._rgba(mix.inputs, "B")
        if i == 0:
            a_in.default_value = col
        else:
            nt.links.new(prev, a_in)
        b_in.default_value = (*[K.srgb_to_linear(c) for c in colour], 1)
        prev = K._rgba(mix.outputs, "Result")
    nt.links.new(prev, b.inputs["Base Color"])
    return m


def mesh_from(name, verts, faces, m, col, smooth=True):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, smooth, col)


def extrude_y(name, outline, y0, y1, m, col, smooth=False):
    """A shape drawn in Blender's x/z plane (a list of (x, z)), pushed out along y from y0 to y1."""
    n = len(outline)
    verts = [(x, y0, z) for (x, z) in outline] + [(x, y1, z) for (x, z) in outline]
    faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return mesh_from(name, verts, faces, m, col, smooth)


# ================================================================ pumpkins
RIBS = 10


def pumpkin_r(theta):
    """The pumpkin's outline before its ribs: (radius, height) at angle theta from the bottom (0) to the top (pi)."""
    r = 1.15 * math.sin(theta)
    z = 0.7 - 0.8 * math.cos(theta)
    top = max(0.0, (theta - 0.78 * math.pi) / (0.22 * math.pi))
    bot = max(0.0, (0.2 * math.pi - theta) / (0.2 * math.pi))
    z -= 0.24 * top * top          # a dimple round the stem
    z += 0.1 * bot * bot           # and a smaller one underneath
    return r, z


def pumpkin_body(name, seg, rings, m, col, lumpy):
    lumps = [random.uniform(0.98, 1.025) for _ in range(RIBS)]
    verts = [(0.0, 0.0, pumpkin_r(0.0)[1])]
    for i in range(1, rings):
        theta = math.pi * i / rings
        r, z = pumpkin_r(theta)
        for k in range(seg):
            a = k / seg * math.tau
            groove = abs(math.cos(a * RIBS / 2.0)) ** 0.55          # 0 in a groove, 1 on a rib
            rr = r * (0.9 + 0.1 * groove)
            if lumpy:
                rib = int((a / math.tau * RIBS + 0.5)) % RIBS
                rr *= lumps[rib] + 0.012 * math.sin(a * 37.0 + theta * 11.0)
            verts.append((math.cos(a) * rr, math.sin(a) * rr, z - (1.0 - groove) * 0.03 * math.sin(theta)))
    verts.append((0.0, 0.0, pumpkin_r(math.pi)[1]))
    top = len(verts) - 1
    faces = []
    for k in range(seg):
        faces.append([0, 1 + (k + 1) % seg, 1 + k])
    for i in range(rings - 2):
        a0 = 1 + i * seg
        b0 = 1 + (i + 1) * seg
        for k in range(seg):
            k2 = (k + 1) % seg
            faces.append([a0 + k, a0 + k2, b0 + k2, b0 + k])
    last = 1 + (rings - 2) * seg
    for k in range(seg):
        faces.append([last + k, last + (k + 1) % seg, top])
    return mesh_from(name, verts, faces, m, col)


def stem(col, high):
    s = K.lathe("Stem", [(0.0, 1.32), (0.13, 1.32), (0.1, 1.42), (0.075, 1.55), (0.085, 1.62), (0.0, 1.63)],
                seg=24 if high else 7, m=STEM, flutes=6 if high else 0, flute_depth=0.018, flute_z=(1.3, 1.6),
                col=col)
    s.rotation_euler = (0.18, -0.1, 0.4)
    s.location = (0.0, 0.0, -0.06)
    obs = [s]
    if high:
        # a curly dried vine off the stem
        pts = [(0.08, 0.0, 1.42)] + [(0.18 + math.cos(t * 1.7) * 0.09 * (1 - t / 6), math.sin(t * 1.7) * 0.09 *
                                      (1 - t / 6), 1.38 + t * 0.012) for t in [i * 0.4 for i in range(16)]]
        obs.append(K.wire("Tendril", pts, 0.012, STEM, res=8, bevel_res=2, col=col))
    return obs


def pumpkin(carved):
    global STEM
    skin = K.mat("Pumpkin Skin", (0.95, 0.5, 0.12), rough=0.55, wear=0.08, bump=0.12)
    STEM = K.mat("Pumpkin Stem", (0.3, 0.45, 0.2), rough=0.8, grain=(14.0, 0.4), bump=0.2)
    high = [pumpkin_body("Pumpkin", 160, 64, skin, HIGH, True)] + stem(HIGH, True)
    emit = carved
    if carved:
        flesh = K.mat("Pumpkin Flesh", (1.0, 0.72, 0.3), rough=0.6, emit=1.0, emit_rgb=(1.0, 0.6, 0.15), bump=0.1)
        glow = K.mat("Candle Glow", (1.0, 0.78, 0.3), rough=0.5, emit=1.0, emit_rgb=(1.0, 0.65, 0.15))
        body = high[0]
        body.data.materials.append(flesh)
        sol = body.modifiers.new("Wall", "SOLIDIFY")
        sol.thickness = 0.07
        sol.offset = -1.0
        sol.material_offset = 1
        # The face: two triangle eyes, a triangle nose and a toothy grin, cut right through the front (-y)
        y0, y1 = -1.6, -0.4
        cutters = [
            extrude_y("Eye", [(-0.52, 0.86), (-0.14, 0.86), (-0.32, 1.12)], y0, y1, None, HIGH),
            extrude_y("Eye", [(0.14, 0.86), (0.52, 0.86), (0.32, 1.12)], y0, y1, None, HIGH),
            extrude_y("Nose", [(-0.1, 0.66), (0.1, 0.66), (0.0, 0.8)], y0, y1, None, HIGH),
        ]
        grin = []
        steps = 12
        for i in range(steps + 1):              # the top edge of the grin, with two teeth hanging down
            t = i / steps
            x = -0.62 + t * 1.24
            z = 0.5 - 0.16 * math.sin(t * math.pi) * 0.0 + 0.12 * (1 - math.sin(t * math.pi))
            if 0.3 < t < 0.4 or 0.6 < t < 0.7:
                z -= 0.09
            grin.append((x, z))
        for i in range(steps, -1, -1):           # the bottom edge, curving down in a smile, one tooth up
            t = i / steps
            x = -0.62 + t * 1.24
            z = 0.42 - 0.2 * math.sin(t * math.pi) + 0.08 * (1 - math.sin(t * math.pi))
            if 0.45 < t < 0.55:
                z += 0.08
            grin.append((x, z))
        cutters.append(extrude_y("Grin", grin, y0, y1, None, HIGH))
        for c in cutters:
            bo = body.modifiers.new("Cut", "BOOLEAN")
            bo.operation = "DIFFERENCE"
            bo.solver = "EXACT"
            bo.object = c
            c.hide_render = True
            c.hide_viewport = True
        body = K.to_mesh(body)
        high[0] = body
        for c in cutters:
            bpy.data.objects.remove(c)
        # the candle's glow behind the holes, on the far wall inside
        inner = pumpkin_body("Glow", 48, 20, glow, HIGH, False)
        inner.scale = (0.84, 0.84, 0.84)
        inner.location = (0.0, 0.0, 0.11)
        high.append(inner)
    low_body = pumpkin_body("Pumpkin", 30, 12, skin, LOW, False)
    low = [low_body] + stem(LOW, False)
    return high, low, emit


# ================================================================ scarecrow
def scarecrow():
    wood = K.mat("Post Wood", (0.45, 0.32, 0.22), rough=0.85, grain=(8.0, 0.35), bump=0.15)
    shirt = plaid("Plaid Shirt", (0.75, 0.3, 0.15), (0.35, 0.12, 0.08), (0.95, 0.8, 0.5))
    patch = plaid("Shirt Patch", (0.3, 0.45, 0.65), (0.15, 0.2, 0.35), (0.85, 0.85, 0.8), scale=14.0)
    straw = K.mat("Straw", (0.92, 0.8, 0.4), rough=0.9, grain=(40.0, 0.35), bump=0.2)
    sack = K.mat("Sack Head", (0.85, 0.72, 0.5), rough=0.95, grain=(70.0, 0.18), bump=0.6)
    stitch = K.mat("Stitch", (0.15, 0.1, 0.08), rough=0.9)
    hat = K.mat("Straw Hat", (0.82, 0.68, 0.38), rough=0.9, grain=(55.0, 0.3), bump=0.3)
    band = K.mat("Hat Band", (0.6, 0.15, 0.12), rough=0.8, bump=0.1)
    rope = K.mat("Rope", (0.7, 0.58, 0.38), rough=0.9, grain=(90.0, 0.4), bump=0.4)
    button = K.mat("Button", (0.25, 0.18, 0.12), rough=0.4)
    leaf = K.mat("Autumn Leaf", (0.85, 0.42, 0.12), rough=0.7)

    def build(col, high):
        obs = []
        seg = 16 if high else 5
        # the post and crossbar: a rough-split pole, and a bar lashed across it
        obs.append(K.box("Post", (0.12, 0.12, 2.3), at=(0, 0, 1.15), m=wood, bevel=0.015 if high else 0, col=col))
        obs.append(K.box("Bar", (1.8, 0.1, 0.1), at=(0, 0, 1.7), m=wood, bevel=0.012 if high else 0, col=col))
        # the shirt: a body a little wider at the shoulders, and sleeves out along the bar, rumpled
        body = K.lathe("Shirt", [(0.0, 1.03), (0.3, 1.04), (0.34, 1.3), (0.36, 1.6), (0.3, 1.82), (0.12, 1.88),
                                 (0.0, 1.88)], seg=24 if high else 8, m=shirt, col=col)
        body.scale = (1.0, 0.55, 1.0)
        obs.append(body)
        for sx in (-1, 1):
            sl = K.lathe("Sleeve", [(0.0, 0.0), (0.13, 0.0), (0.12, 0.2), (0.135, 0.38), (0.11, 0.56), (0.0, 0.56)],
                         seg=seg, m=shirt, col=col)
            sl.rotation_euler = (0, sx * math.pi / 2, 0)
            sl.location = (sx * 0.28, 0, 1.7)
            obs.append(sl)
            # straw poking out of the cuff
            n = 22 if high else 0
            for i in range(n):
                a = i / n * math.tau
                d = random.uniform(0.0, 0.1)
                obs.append(K.cyl("Straw", 0.008, random.uniform(0.12, 0.26), seg=4, m=straw, col=col,
                                 at=(sx * (0.9 + random.uniform(0.0, 0.08)), math.cos(a) * d, 1.7 + math.sin(a) * d),
                                 rot=(random.uniform(-0.4, 0.4), sx * math.pi / 2 + random.uniform(-0.4, 0.4), 0)))
            if not high:
                obs.append(K.cyl("Straw", 0.06, 0.22, seg=5, m=straw, col=col, r2=0.0, at=(sx * 0.95, 0, 1.7),
                                 rot=(0, sx * math.pi / 2, 0)))
        if high:
            # a patch on the chest, buttons down the front, a rope belt, straw out of the hem
            obs.append(K.box("Patch", (0.16, 0.02, 0.16), at=(0.13, -0.19, 1.5), m=patch, bevel=0.005, col=col,
                             rot=(0, 0.12, 0)))
            for i in range(4):
                obs.append(K.cyl("Button", 0.022, 0.012, at=(0, -0.2 + 0.01 * (i == 0), 1.75 - i * 0.17), seg=12,
                                 m=button, rot=(math.pi / 2, 0, 0), col=col))
            obs.append(K.wire("Belt", [(math.cos(a) * 0.33, math.sin(a) * 0.19, 1.12 + 0.01 * math.sin(a * 3))
                                       for a in [i / 24 * math.tau for i in range(24)]], 0.022, rope, closed=True,
                              res=8, bevel_res=3, col=col))
            obs.append(K.wire("Knot", [(-0.05, -0.2, 1.12), (0.0, -0.24, 1.08), (0.03, -0.22, 0.98), (0.06, -0.21, 0.9)],
                              0.018, rope, res=8, bevel_res=3, col=col))
            for i in range(40):
                a = i / 40 * math.tau
                obs.append(K.cyl("Straw", 0.008, random.uniform(0.12, 0.25), seg=4, m=straw, col=col,
                                 at=(math.cos(a) * 0.29, math.sin(a) * 0.16, 0.98),
                                 rot=(math.sin(a) * 0.5 + random.uniform(-0.2, 0.2),
                                      -math.cos(a) * 0.5 + random.uniform(-0.2, 0.2), 0)))
            # a leaf caught on his shoulder
            obs.append(K.sphere("Leaf", 0.06, at=(-0.22, -0.12, 1.86), m=leaf, seg=8, scale=(1.4, 1.0, 0.15), col=col))
        else:
            obs.append(K.cyl("Straw", 0.28, 0.14, seg=6, m=straw, col=col, r2=0.2, at=(0, 0, 0.97)))
        # the sack head, gathered at the neck with rope
        head = K.sphere("Sack", 0.27, at=(0, 0, 2.12), m=sack, seg=32 if high else 10, scale=(1.0, 0.95, 1.05), col=col)
        obs.append(head)
        obs.append(K.lathe("Gather", [(0.0, 1.86), (0.16, 1.86), (0.09, 1.93), (0.13, 1.97), (0.0, 1.97)],
                           seg=20 if high else 6, m=sack, col=col))
        if high:
            obs.append(K.wire("Neck Rope", [(math.cos(a) * 0.1, math.sin(a) * 0.1, 1.93) for a in
                                            [i / 16 * math.tau for i in range(16)]], 0.016, rope, closed=True, res=6,
                              bevel_res=2, col=col))
            # stitched X eyes and a stitched smile, sewn into the front of the sack
            for sx in (-0.09, 0.09):
                for d in (1, -1):
                    obs.append(K.box("Stitch", (0.08, 0.02, 0.016), at=(sx, -0.255, 2.17), m=stitch, col=col,
                                     rot=(0, d * 0.78, 0)))
            for i in range(7):
                t = i / 6
                x = -0.11 + t * 0.22
                z = 2.02 - 0.03 * math.sin(t * math.pi)
                obs.append(K.box("Stitch", (0.035, 0.02, 0.012), at=(x, -0.262 + 0.01 * abs(x) * 3, z), m=stitch,
                                 col=col, rot=(0, -0.3 * (t - 0.5), 0)))
                obs.append(K.box("Stitch", (0.01, 0.02, 0.04), at=(x, -0.262 + 0.01 * abs(x) * 3, z), m=stitch,
                                 col=col))
        # the straw hat, tipped back a little: a wavy brim and a crown with a band
        brim = K.lathe("Brim", [(0.17, 0.0), (0.4, -0.015), (0.42, 0.0), (0.4, 0.02), (0.17, 0.02)],
                       seg=48 if high else 12, m=hat, col=col)
        crown = K.lathe("Crown", [(0.0, 0.0), (0.2, 0.0), (0.18, 0.12), (0.15, 0.22), (0.0, 0.23)],
                        seg=32 if high else 8, m=hat, col=col)
        parts = [brim, crown]
        if high:
            parts.append(K.lathe("Band", [(0.199, 0.015), (0.201, 0.015), (0.19, 0.07), (0.188, 0.07)], seg=32,
                                 m=band, col=col))
            for i in range(28):
                a = i / 28 * math.tau
                parts.append(K.cyl("Straw", 0.006, random.uniform(0.06, 0.12), seg=4, m=straw, col=col,
                                   at=(math.cos(a) * 0.42, math.sin(a) * 0.42, 0.005),
                                   rot=(-math.sin(a) * 1.4, math.cos(a) * 1.4, 0)))
        for p in parts:
            p.location = (0, 0.02, 2.29)
            p.rotation_euler = (0.12, 0, 0)     # tipped forward like the builder's (Godot +z is Blender -y)
            obs.append(p)
        return obs

    return build(HIGH, True), build(LOW, False), False


# ================================================================ mailbox
def mailbox():
    wood = K.mat("Post Wood", (0.45, 0.32, 0.22), rough=0.85, grain=(8.0, 0.35), bump=0.15)
    metal = K.mat("Mailbox", (0.2, 0.25, 0.3), rough=0.45, metal=0.2, pits=0.15, bump=0.05)
    flag = K.mat("Mail Flag", (0.9, 0.2, 0.15), rough=0.45, metal=0.3)
    rivet = K.mat("Rivet", (0.55, 0.57, 0.6), rough=0.35, metal=1.0)

    def arch(r, flat, n):
        """The mailbox's end: a flat bottom and a round top (x, z), centred on its middle at z 0."""
        pts = [(-r, -flat), (r, -flat)]
        for i in range(n + 1):
            a = i / n * math.pi
            pts.append((math.cos(a) * r, math.sin(a) * r * 0.95))
        return pts

    def build(col, high):
        obs = []
        # the post: a square post with a chamfer, set in a little mound of dirt, and an arm holding the box up
        obs.append(K.box("Post", (0.1, 0.1, 1.1), at=(0, 0, 0.55), m=wood, bevel=0.012 if high else 0, col=col))
        obs.append(K.box("Arm", (0.08, 0.5, 0.06), at=(0, 0.0, 1.04), m=wood, bevel=0.01 if high else 0, col=col))
        obs.append(K.box("Brace", (0.05, 0.05, 0.36), at=(0, 0.12, 0.9), m=wood, bevel=0.008 if high else 0,
                         col=col, rot=(-0.7, 0, 0)))
        obs.append(K.box("Brace", (0.05, 0.05, 0.36), at=(0, -0.12, 0.9), m=wood, bevel=0.008 if high else 0,
                         col=col, rot=(0.7, 0, 0)))
        # the box: along Godot's z (Blender's y), 0.6 long, round topped, its middle 1.25 up
        n = 20 if high else 12
        shell = arch(0.18, 0.16, n)
        body = extrude_y("Box", shell, -0.3, 0.3, metal, col, smooth=False)
        body.location = (0, 0, 1.25)
        obs.append(body)
        if high:
            for b in [body]:
                bv = b.modifiers.new("Bevel", "BEVEL")
                bv.width = 0.006
                bv.segments = 2
            # ribs pressed round the top, and rivets along the seams
            for y in (-0.2, 0.0, 0.2):
                rib = extrude_y("Rib", arch(0.188, 0.15, n), y - 0.012, y + 0.012, metal, col)
                rib.location = (0, 0, 1.25)
                obs.append(rib)
            for y in [-0.27 + i * 0.09 for i in range(7)]:
                for sx in (-1, 1):
                    obs.append(K.sphere("Rivet", 0.008, at=(sx * 0.18, y, 1.105), m=rivet, seg=8, col=col))
            # the door at the front (-y): a slightly bigger arch with a pull handle
            door = extrude_y("Door", arch(0.19, 0.17, n), -0.315, -0.3, metal, col)
            door.location = (0, 0, 1.25)
            obs.append(door)
            obs.append(K.wire("Handle", [(-0.05, -0.316, 1.37), (-0.03, -0.35, 1.38), (0.03, -0.35, 1.38),
                                         (0.05, -0.316, 1.37)], 0.009, rivet, res=10, bevel_res=2, col=col))
            obs.append(K.cyl("Hinge", 0.012, 0.3, at=(0, -0.31, 1.09), seg=10, m=rivet, rot=(0, math.pi / 2, 0),
                             col=col))
        # the flag on its +x side, up, with a pivot
        obs.append(K.box("Flag Arm", (0.02, 0.04, 0.25), at=(0.2, 0.1, 1.35), m=flag, bevel=0.004 if high else 0,
                         col=col))
        obs.append(K.box("Flag", (0.02, 0.12, 0.08), at=(0.2, 0.05, 1.45), m=flag, bevel=0.004 if high else 0,
                         col=col))
        if high:
            obs.append(K.cyl("Pivot", 0.022, 0.03, at=(0.205, 0.1, 1.24), seg=12, m=rivet, rot=(0, math.pi / 2, 0),
                             col=col))
        return obs

    return build(HIGH, True), build(LOW, False), False


if KIND in ("pumpkin", "jack"):
    high, low, emit = pumpkin(KIND == "jack")
    size = 512
elif KIND == "scarecrow":
    high, low, emit = scarecrow()
    size = 1024
else:
    high, low, emit = mailbox()
    size = 512

hi_tris = K.tri_count(high)
prop = K.join(NAME, low)
lo_tris = K.tri_count([prop])
K.uv_unwrap(prop, margin=0.008)
maps_wanted = ["normal", "ao", "color", "rough", "metal"] + (["emit"] if emit else [])
maps = K.bake(prop, high, size=size, name=NAME, extrusion=0.08 if KIND in ("pumpkin", "jack") else 0.02,
              ray={"pumpkin": 0.16, "jack": 0.3}.get(KIND, 0.06),
              maps=maps_wanted)
K.finish(prop, maps, size, NAME, emit_strength=3.0 if emit else 1.0)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([prop], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

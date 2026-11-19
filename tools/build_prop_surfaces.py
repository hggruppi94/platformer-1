# Batch fourteen, buildings (19 Nov 2026, Hayden: "start baking nature, buildings, then portal worlds in that
# order"): the outsides of the buildings. A building is far too big, and comes in far too many sizes, to bake whole the
# way a lamp or a bench is; games give big walls and roofs their detail with TILING materials instead: a small patch of
# siding, shingles or brick is modelled in full (every board, nail head and mortar line), baked onto a flat square, and
# that square repeats across the wall. So these are baked patches, not props: each is a 1024 texture set (colour, normal
# map, AO, roughness) on a plain square, exported as a .glb only so Godot extracts the textures the way it does for
# every other bake. scripts/detail_props.gd dress_buildings() puts them on the builders' walls and roofs, repeating
# them in the wall's own space (triplanar), tinted with each building's own colour.
#
# What we compared first (Hayden's rule): the trim sheet / tiling material way AAA games build modular buildings (Ubisoft
# and Insomniac's GDC talks on modular kits and trim sheets), and leukbaars/EasyBake's "bake to a plane" set-up. The
# trick to a seamless patch: the detail is built over 3 x 3 copies of the patch, so whatever runs off one edge comes back
# in at the other, and the bake reads only the middle copy. The copies are kept as separate objects (not joined), so the
# procedural grain and dents, worked out in each object's own space, line up across the edges too.
#
#   clapboard    lap siding, 2 m square: 10 rows of painted boards, butt joints, nail heads, the shadow under each lap
#                (Stars Hollow's walls, the steeple)
#   shingles     cedar shingles, 2 m square, the courses running up the image's X so they follow the ridge of the
#                builders' roofs (every "Roof ..." and the steeples)
#   brick        running bond, 1.2 m square, bricks a little uneven, mortar set back (the Fire Station, the school)
#   stone        ashlar blocks in courses, 2.4 m square, chisel-faced (the library, the Void's dome trims)
#   barn_boards  board and batten, 2 m square (the barn dance studio's red walls)
#   dome_scales  the Void's domes: rows of rounded overlapping scales, 1.6 m square, used along the dome's own UVs
#
#   python tools/build_prop_surfaces.py "<out>.glb" <kind> [--preview]
import math
import os
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402

KINDS = ["clapboard", "shingles", "brick", "stone", "barn_boards", "dome_scales"]
KIND = next((a for a in sys.argv if a in KINDS), "clapboard")
OUT = K.out_path(KIND + ".glb")
TILE = {"clapboard": 2.0, "shingles": 2.0, "brick": 1.2, "stone": 2.4, "barn_boards": 2.0, "dome_scales": 1.6}[KIND]

K.reset()
HIGH = K.new_collection("High")
random.seed(14)


def tile_obj(name, obs):
    """Joins one material's pieces of the patch into one object (its own space is the patch's)."""
    return K.join(name, obs) if len(obs) > 1 else K.to_mesh(obs[0])


# ---------------------------------------------------------------- the patches
# Every patch lies in the X/Y plane facing +Z, from (0, 0) to (TILE, TILE); +Y is up the wall.

def clapboard():
    paint = [K.mat("Clapboard %d" % i, (v, v, v * 0.98), rough=0.7, pits=0.15, bump=0.25)
             for i, v in enumerate([0.9, 0.86, 0.88])]
    nail_m = K.mat("Nail", (0.55, 0.55, 0.55), rough=0.5, metal=0.6)
    back = K.mat("Sheathing", (0.35, 0.33, 0.3), rough=0.95)
    rows = 10
    h = TILE / rows
    pieces = {m.name: [] for m in paint}
    nails = []
    for r in range(rows):
        y0 = r * h
        x = random.uniform(0.0, TILE)
        lengths = [random.uniform(0.9, 2.4) for _ in range(3)]
        k = TILE / sum(lengths)
        for L in lengths:
            L *= k
            m = random.choice(paint)
            # a lap board: thin at the top, thick at the bottom where it laps over the one below
            b = K.box("Board", (L - 0.006, h + 0.03, 0.014), at=(x + L / 2, y0 + h / 2 + 0.008, 0.022), m=m,
                      bevel=0.003, seg=2, rot=(-0.2, 0, 0), col=HIGH)
            pieces[m.name].append(b)
            for nx in range(int(L / 0.4)):
                px = x + 0.2 + nx * 0.4
                nails.append(K.cyl("Nail", 0.006, 0.006, at=(px, y0 + 0.03, 0.036), seg=8, m=nail_m,
                                   rot=(math.pi / 2, 0, 0), col=HIGH))
            x += L
    objs = [tile_obj(n, ob) for n, ob in pieces.items() if ob]
    objs.append(tile_obj("Nails", nails))
    objs.append(K.box("Back", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.02), m=back, col=HIGH))
    return objs


def shingles():
    tones = [K.mat("Shingle %d" % i, (v, v, v), rough=0.85, pits=0.3, bump=0.35, grain=(6.0, 0.12))
             for i, v in enumerate([0.9, 0.82, 0.86, 0.78])]
    felt = K.mat("Felt", (0.25, 0.25, 0.25), rough=0.95)
    rows = 14
    h = TILE / rows
    pieces = {m.name: [] for m in tones}
    for r in range(rows):
        y0 = r * h
        x = random.uniform(0.0, TILE)
        widths = [random.uniform(0.16, 0.34) for _ in range(9)]
        k = TILE / sum(widths)
        for w in widths:
            w *= k
            m = random.choice(tones)
            drop = random.uniform(-0.008, 0.008)
            s = K.box("Shingle", (w - 0.01, h + 0.04, 0.014), at=(x + w / 2, y0 + h / 2 + 0.01 + drop, 0.012),
                      m=m, bevel=0.003, seg=1, rot=(-0.13, 0, random.uniform(-0.015, 0.015)), col=HIGH)
            pieces[m.name].append(s)
            x += w
    objs = [tile_obj(n, ob) for n, ob in pieces.items() if ob]
    objs.append(K.box("Felt", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.012), m=felt, col=HIGH))
    # the builders' roofs run their ridge along the patch's X (the game's triplanar top view), so turn the courses
    for o in objs:
        _turn(o)
    return objs


def _turn(o):
    """Turns a patch object a quarter round the patch's middle (the courses then run up X)."""
    from mathutils import Matrix
    bpy.context.view_layer.update()
    mid = Matrix.Translation((TILE / 2, TILE / 2, 0))
    o.matrix_world = mid @ Matrix.Rotation(math.pi / 2, 4, "Z") @ mid.inverted() @ o.matrix_world


def brick():
    tones = [K.mat("Brick %d" % i, (v, v * 0.97, v * 0.95), rough=0.8, pits=0.35, bump=0.5)
             for i, v in enumerate([0.72, 0.64, 0.78, 0.68, 0.6])]
    mortar = K.mat("Mortar", (0.95, 0.94, 0.9), rough=0.95, bump=0.6)
    rows = 16
    h = TILE / rows
    pitch = TILE / 6
    pieces = {m.name: [] for m in tones}
    for r in range(rows):
        y0 = r * h
        off = (pitch / 2) if r % 2 else 0.0
        for c in range(6):
            x = off + c * pitch
            m = random.choice(tones)
            b = K.box("Brick", (pitch - 0.011 + random.uniform(-0.002, 0.002), h - 0.011, 0.05),
                      at=(x + pitch / 2, y0 + h / 2, random.uniform(-0.002, 0.002)), m=m, bevel=0.004, seg=2,
                      rot=(random.uniform(-0.01, 0.01), random.uniform(-0.01, 0.01), random.uniform(-0.004, 0.004)),
                      col=HIGH)
            pieces[m.name].append(b)
    objs = [tile_obj(n, ob) for n, ob in pieces.items() if ob]
    objs.append(K.box("Mortar", (TILE, TILE, 0.02), at=(TILE / 2, TILE / 2, -0.016), m=mortar, col=HIGH))
    return objs


def stone():
    tones = [K.mat("Stone %d" % i, (v, v * 0.98, v * 1.0), rough=0.9, pits=0.4, bump=1.2)
             for i, v in enumerate([0.86, 0.8, 0.9, 0.76])]
    mortar = K.mat("Joint", (0.6, 0.58, 0.56), rough=0.95, bump=0.5)
    rows = 6
    h = TILE / rows
    pieces = {m.name: [] for m in tones}
    for r in range(rows):
        y0 = r * h
        x = random.uniform(0.0, TILE)
        widths = [random.uniform(0.45, 0.9) for _ in range(4)]
        k = TILE / sum(widths)
        for w in widths:
            w *= k
            m = random.choice(tones)
            b = K.box("Block", (w - 0.02, h - 0.02, 0.12), at=(x + w / 2, y0 + h / 2, random.uniform(-0.006, 0.006)),
                      m=m, bevel=0.025, seg=3, col=HIGH)
            # a chisel-faced block: its face pushed about a little
            dis = b.modifiers.new("Rough", "DISPLACE")
            tex = bpy.data.textures.new("StoneTex", "CLOUDS")
            tex.noise_scale = 0.12
            dis.texture = tex
            dis.texture_coords = "LOCAL"
            dis.strength = 0.012
            sub = b.modifiers.new("Sub", "SUBSURF")
            sub.levels = 0
            b.modifiers.move(len(b.modifiers) - 1, 0)
            pieces[m.name].append(b)
            x += w
    objs = [tile_obj(n, ob) for n, ob in pieces.items() if ob]
    objs.append(K.box("Joints", (TILE, TILE, 0.02), at=(TILE / 2, TILE / 2, -0.05), m=mortar, col=HIGH))
    return objs


def barn_boards():
    wood = [K.mat("Barn Board %d" % i, (v, v, v), rough=0.85, pits=0.3, bump=0.4, grain=(9.0, 0.18))
            for i, v in enumerate([0.88, 0.8, 0.84])]
    nail_m = K.mat("Nail", (0.45, 0.45, 0.45), rough=0.5, metal=0.6)
    back = K.mat("Gap", (0.2, 0.2, 0.2), rough=0.95)
    n = 8
    w = TILE / n
    pieces = {m.name: [] for m in wood}
    nails = []
    for c in range(n):
        x0 = c * w
        y = random.uniform(0.0, TILE)
        lengths = [random.uniform(1.0, 2.0) for _ in range(2)]
        k = TILE / sum(lengths)
        for L in lengths:
            L *= k
            m = random.choice(wood)
            pieces[m.name].append(K.box("Board", (w - 0.012, L - 0.004, 0.02), at=(x0 + w / 2, y + L / 2, 0.0), m=m,
                                        bevel=0.003, seg=1, col=HIGH))
            y += L
        # a batten over the joint, nailed
        m = random.choice(wood)
        pieces[m.name].append(K.box("Batten", (0.06, TILE + 0.002, 0.02), at=(x0, TILE / 2, 0.02), m=m, bevel=0.004,
                                    seg=1, col=HIGH))
        for ny in range(5):
            nails.append(K.cyl("Nail", 0.006, 0.006, at=(x0, 0.2 + ny * 0.4, 0.031), seg=8, m=nail_m, col=HIGH))
    objs = [tile_obj(nm, ob) for nm, ob in pieces.items() if ob]
    objs.append(tile_obj("Nails", nails))
    objs.append(K.box("Back", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.02), m=back, col=HIGH))
    return objs


def dome_scales():
    tones = [K.mat("Scale %d" % i, (v, v * 0.98, v), rough=0.4, pits=0.2, bump=0.2) for i, v in enumerate([0.9, 0.84, 0.94])]
    under = K.mat("Under", (0.45, 0.42, 0.48), rough=0.8)
    stud = K.mat("Stud", (0.97, 0.95, 0.9), rough=0.3, metal=0.4)
    per = 4
    rows = 8
    pitch = TILE / per
    h = TILE / rows
    pieces = {m.name: [] for m in tones}
    studs = []
    for r in range(rows):
        y0 = r * h
        off = pitch / 2 if r % 2 else 0.0
        for c in range(per):
            x = off + c * pitch
            m = random.choice(tones)
            # a round scale lying on the dome, its lower edge lifted over the row below
            s = K.sphere("Scale", pitch * 0.56, at=(x, y0 + h * 0.15, 0.0), m=m, seg=24, scale=(1.0, 1.0, 0.09),
                         col=HIGH)
            s.rotation_euler = (-0.12, 0, 0)
            s.location.z = 0.012
            pieces[m.name].append(s)
            studs.append(K.sphere("Stud", 0.02, at=(x, y0 + h * 0.62, 0.035), m=stud, seg=10, col=HIGH))
    objs = [tile_obj(n, ob) for n, ob in pieces.items() if ob]
    objs.append(tile_obj("Studs", studs))
    objs.append(K.box("Under", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.03), m=under, col=HIGH))
    return objs


# ---------------------------------------------------------------- the bake
def low_square():
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in [(0, 0, 0), (TILE, 0, 0), (TILE, TILE, 0), (0, TILE, 0)]]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.new("UVMap")
    for loop, (u, v) in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop[uv].uv = (u, v)
    ob = K._obj(KIND, bm, K.mat("Bake", (0.5, 0.5, 0.5)), smooth=False)
    return ob


def copies(objs):
    """The patch's eight neighbours: copies of each object (same mesh, same material), so it repeats seamlessly."""
    out = list(objs)
    for o in objs:
        for i in (-1, 0, 1):
            for j in (-1, 0, 1):
                if i == 0 and j == 0:
                    continue
                c = o.copy()
                HIGH.objects.link(c)
                c.matrix_world = o.matrix_world.copy()
                c.location = (o.location.x + i * TILE, o.location.y + j * TILE, o.location.z)
                out.append(c)
    return out


def bake(low, highs, size, ext, ray):
    """K.bake without its joining step: the copies have to stay separate objects, each with its own space, or the
    procedural grain would stop lining up across the patch's edges."""
    scene = bpy.context.scene
    b = scene.render.bake
    b.use_selected_to_active = True
    b.cage_extrusion = ext
    b.max_ray_distance = ray
    out = {}

    def run(kind, img, **kw):
        K._target(low, img)
        bpy.ops.object.select_all(action="DESELECT")
        for h in highs:
            h.select_set(True)
        low.select_set(True)
        bpy.context.view_layer.objects.active = low
        bpy.ops.object.bake(type=kind, **kw)

    scene.cycles.samples = 8
    out["normal"] = K._image(KIND + "_normal", size, non_color=True)
    run("NORMAL", out["normal"], normal_space="TANGENT")
    scene.cycles.samples = 48
    out["ao"] = K._image(KIND + "_ao", size, non_color=True)
    run("AO", out["ao"])
    scene.cycles.samples = 4
    for key, socket, non_color in [("color", "Base Color", False), ("rough", "Roughness", True),
                                   ("metal", "Metallic", True)]:
        undo = K._rewire(highs, socket)
        img = K._image(KIND + "_" + key, size, non_color=non_color)
        run("EMIT", img)
        K._restore(undo)
        out[key] = img
    return out


BUILD = {"clapboard": clapboard, "shingles": shingles, "brick": brick, "stone": stone, "barn_boards": barn_boards,
         "dome_scales": dome_scales}


def main():
    patch = [K.to_mesh(o) for o in BUILD[KIND]()]
    highs = copies(patch)
    hi_tris = K.tri_count(patch)
    low = low_square()
    low.location.z = 0.0
    maps = bake(low, highs, 1024, 0.1, 0.25)
    K.finish(low, maps, 1024, KIND)
    print("TRIS %s patch %d low 2" % (KIND, hi_tris))
    if K.has_flag("preview"):
        d = Path(os.environ.get("BAKE_PREVIEWS", "/tmp/bake_previews"))
        d.mkdir(parents=True, exist_ok=True)
        for img in maps.values():
            img.filepath_raw = str(d / (img.name + ".png"))
            img.file_format = "PNG"
            img.save()
    K.export([low], OUT)


main()

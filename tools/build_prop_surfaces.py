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
# Batch fifteen, the portal worlds (19 Nov 2026), the same way, for the natural stuff they're built from:
#   bark         deep up-and-down furrows between ridges of bark, 1.6 m (Dark Hollow's crooked trees, the Frozen
#                Moment's pines, Lanternmoor's lantern trees, the mangroves, roots)
#   rock         lumpy rock broken into knobs and cracks, 3 m (old stone, standing stones, reef rock, wet rock)
#   ice          clear-ish ice with cracks and frozen bubbles in it, 3 m (crags, icicles, the slide, the throne)
#   snow         soft lumpy snow with wind ripples and sparkly crystals, 3 m (snow caps, drifts, crag snow)
#   coral        knobbly coral full of little pores, 1.2 m (the Tide Reef's houses and coral)
#   metal_panel  riveted metal panels with seams and vents, 2 m (Lumen City's lab walls, the skyway deck, pillars)
#   drystone     a dry stone wall of flat stones, no mortar, 2 m (Glenmoor's walls and croft)
#   glass_facade a glass curtain wall, 3 m (20 Nov 2026, the Far Future's props): tall panes in a grid of metal
#                mullions, a solid band at each floor, a few panes a different tint (Lumen City's towers)
#
# Batch sixteen, the insides (24 Nov 2026, Hayden: "keep baking details on assets in the game already"): the Void's
# rooms and the palace school's inside had the outside siding on their walls and plain floors.
#   floorboards  wooden floorboards, 1.6 m: long planks with staggered ends, a gap between each, grain and nail heads
#                (the rooms with wooden floors)
#   floor_tiles  square tiles laid with grout, 1.2 m, each a little uneven (the rooms with painted floors, the school)
#   plaster      soft trowelled plaster with faint hairline cracks, 2 m (every indoor wall and the domes overhead)
#
# Batch seventeen, the enemies (25 Nov 2026, Hayden: "keep baking details on assets in the game already"):
#   reptile_scales  rows of rounded overlapping scales with a ridge of bony scutes every few rows, 0.8 m (the
#                   Crocodillos' scaly hide, hands and belly)
#   goblin_skin     pebbly, wrinkly skin with little warts and pores, 0.6 m (the Time Goblins' and the Bog Wailers'
#                   skin)
#   tweed           a coarse woven cloth, threads over and under with flecks of darker yarn, 0.5 m (the goblins'
#                   waistcoats, coats and trousers)
#
# Batch eighteen, the rides (25 Nov 2026, the same ask): the boards, scooter, skates, Mayor-mobile, leaf board, saucer
# and rockets were plain colours. Small patches, since a ride is small:
#   maple          a skateboard deck's top ply, 0.6 m: long maple grain running along the board, a few scuffs and
#                  scratches (decks)
#   grip_tape      sandpaper grip, 0.3 m: fine sandy grit with a gentle ripple, no worn patches (they baked as bumps) (grip tape,
#                  handlebar grips)
#   brushed_metal  brushed steel, 0.4 m: fine brush lines one way, scratches across them and the odd ding (trucks,
#                  rods, the saucer's hull, rocket tubes)
#   tread          a rubber tyre's tread, 0.4 m: rows of chunky blocks in a zig-zag with grooves between (tyres)
#   leaf_skin      a leaf's skin, 0.8 m: a midrib with veins branching off and little cells between them (the leaf
#                  board)
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

KINDS = ["clapboard", "shingles", "brick", "stone", "barn_boards", "dome_scales", "bark", "rock", "ice", "snow",
         "coral", "metal_panel", "drystone", "glass_facade", "floorboards", "floor_tiles", "plaster", "reptile_scales", "goblin_skin", "tweed",
         "maple", "grip_tape", "brushed_metal", "tread", "leaf_skin"]
KIND = next((a for a in sys.argv if a in KINDS), "clapboard")
OUT = K.out_path(KIND + ".glb")
TILE = {"clapboard": 2.0, "shingles": 2.0, "brick": 1.2, "stone": 2.4, "barn_boards": 2.0, "dome_scales": 1.6,
        "bark": 1.6, "rock": 3.0, "ice": 3.0, "snow": 3.0, "coral": 1.2, "metal_panel": 2.0, "drystone": 2.0,
        "glass_facade": 3.0, "floorboards": 1.6, "floor_tiles": 1.2, "plaster": 2.0,
        "reptile_scales": 0.8, "goblin_skin": 0.6, "tweed": 0.5,
        "maple": 0.6, "grip_tape": 0.3, "brushed_metal": 0.4, "tread": 0.4, "leaf_skin": 0.8}[KIND]

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


def _lumpy(ob, scale, strength, name="Lump"):
    """Pushes an object's surface about with cloud noise in its own space (so copies of it match exactly)."""
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    dis = ob.modifiers.new("Lumps", "DISPLACE")
    tex = bpy.data.textures.new(name + "Tex", "CLOUDS")
    tex.noise_scale = scale
    dis.texture = tex
    dis.texture_coords = "LOCAL"
    dis.strength = strength
    return ob


def bark():
    tones = [K.mat("Bark %d" % i, (v, v * 0.97, v * 0.94), rough=0.95, pits=0.4, bump=0.8) for i, v in
             enumerate([0.86, 0.78, 0.9])]
    deep = K.mat("Furrow", (0.32, 0.3, 0.28), rough=1.0)
    pieces = {m.name: [] for m in tones}
    x = 0.0
    while x < TILE - 0.05:
        w = random.uniform(0.08, 0.17)
        y = random.uniform(0.0, TILE)
        # a ridge of bark in two or three plates, a little crack between them
        for L in [random.uniform(0.4, 1.1) for _ in range(3)]:
            m = random.choice(tones)
            b = K.box("Ridge", (w * random.uniform(0.75, 0.95), L - 0.03, 0.05), at=(x + w / 2, y + L / 2, 0.0), m=m,
                      bevel=0.02, seg=2, rot=(0, 0, random.uniform(-0.03, 0.03)), col=HIGH)
            pieces[m.name].append(_lumpy(b, 0.05, 0.02))
            y += L
        x += w
    objs = [tile_obj(n, ob) for n, ob in pieces.items() if ob]
    objs.append(K.box("Furrows", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.04), m=deep, col=HIGH))
    return objs


def rock():
    tones = [K.mat("Rock %d" % i, (v, v, v * 0.98), rough=0.9, pits=0.5, bump=1.0) for i, v in
             enumerate([0.85, 0.76, 0.9, 0.8])]
    crack = K.mat("Crack", (0.3, 0.29, 0.28), rough=1.0)
    pieces = {m.name: [] for m in tones}
    n = 7
    step = TILE / n
    for i in range(n):
        for j in range(n):
            m = random.choice(tones)
            r = step * random.uniform(0.75, 0.95)
            k = K.sphere("Knob", r, at=((i + random.uniform(0.25, 0.75)) * step, (j + random.uniform(0.25, 0.75)) * step,
                                        -r * 0.3), m=m, seg=16,
                         scale=(random.uniform(0.9, 1.3), random.uniform(0.9, 1.3), 0.35), col=HIGH)
            pieces[m.name].append(_lumpy(k, 0.15, 0.06))
    objs = [tile_obj(n_, ob) for n_, ob in pieces.items() if ob]
    objs.append(K.box("Cracks", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.1), m=crack, col=HIGH))
    return objs


def ice():
    clear = K.mat("Ice", (0.9, 0.94, 0.98), rough=0.12, bump=0.05)
    frost = K.mat("Frost", (0.98, 0.99, 1.0), rough=0.6, bump=0.2)
    crack_m = K.mat("Ice Crack", (0.62, 0.72, 0.82), rough=0.3)
    bubble_m = K.mat("Bubble", (1.0, 1.0, 1.0), rough=0.2)
    objs = [K.box("Ice", (TILE, TILE, 0.04), at=(TILE / 2, TILE / 2, -0.02), m=clear, col=HIGH)]
    cracks, bubbles, frosts = [], [], []
    for _ in range(9):
        # a crack running off in short kinked strokes
        x, y = random.uniform(0, TILE), random.uniform(0, TILE)
        a = random.uniform(0, math.tau)
        for _s in range(random.randint(3, 6)):
            L = random.uniform(0.15, 0.45)
            cracks.append(K.box("Crack", (L, 0.012, 0.03), at=(x + math.cos(a) * L / 2, y + math.sin(a) * L / 2, 0.0),
                                m=crack_m, rot=(0, 0, a), col=HIGH))
            x += math.cos(a) * L
            y += math.sin(a) * L
            a += random.uniform(-0.7, 0.7)
    for _ in range(60):
        bubbles.append(K.sphere("Bubble", random.uniform(0.006, 0.02), at=(random.uniform(0, TILE),
                                random.uniform(0, TILE), 0.004), m=bubble_m, seg=8, col=HIGH))
    for _ in range(8):
        f = K.sphere("Frost", random.uniform(0.15, 0.35), at=(random.uniform(0, TILE), random.uniform(0, TILE), -0.01),
                     m=frost, seg=16, scale=(1.4, 1.0, 0.04), col=HIGH)
        frosts.append(_lumpy(f, 0.08, 0.01))
    objs += [tile_obj("Cracks", cracks), tile_obj("Bubbles", bubbles), tile_obj("Frosts", frosts)]
    return objs


def snow():
    soft = [K.mat("Snow %d" % i, (v, v, min(1.0, v * 1.02)), rough=0.85, bump=0.3) for i, v in
            enumerate([0.97, 0.93])]
    glint = K.mat("Glint", (1.0, 1.0, 1.0), rough=0.05, metal=0.2)
    pieces = {m.name: [] for m in soft}
    n = 6
    step = TILE / n
    for i in range(n):
        for j in range(n):
            m = random.choice(soft)
            r = step * random.uniform(0.7, 0.95)
            # a soft mound whose top sits just proud of the patch (its lower half under the next mounds)
            lump = K.sphere("Lump", r, at=((i + random.uniform(0.3, 0.7)) * step, (j + random.uniform(0.3, 0.7)) * step,
                                           -r * 0.12), m=m, seg=16, scale=(1.3, 1.0, 0.16), col=HIGH)
            pieces[m.name].append(_lumpy(lump, 0.2, 0.025))
    glints = [K.sphere("Glint", random.uniform(0.006, 0.012), at=(random.uniform(0, TILE), random.uniform(0, TILE),
                       0.03), m=glint, seg=6, col=HIGH) for _ in range(120)]
    objs = [tile_obj(n_, ob) for n_, ob in pieces.items() if ob]
    objs.append(tile_obj("Glints", glints))
    objs.append(K.box("Base", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.08), m=soft[1], col=HIGH))
    return objs


def coral():
    tones = [K.mat("Coral %d" % i, (v, v * 0.97, v * 0.95), rough=0.85, pits=0.5, bump=0.6) for i, v in
             enumerate([0.9, 0.82, 0.94])]
    pore_m = K.mat("Pore", (0.35, 0.3, 0.3), rough=1.0)
    pieces = {m.name: [] for m in tones}
    pores = []
    n = 9
    step = TILE / n
    for i in range(n):
        for j in range(n):
            m = random.choice(tones)
            cx = (i + random.uniform(0.3, 0.7)) * step
            cy = (j + random.uniform(0.3, 0.7)) * step
            r = step * random.uniform(0.45, 0.6)
            pieces[m.name].append(K.sphere("Polyp", r, at=(cx, cy, -r * 0.4), m=m, seg=14, scale=(1, 1, 0.6),
                                           col=HIGH))
            pores.append(K.cyl("Pore", r * 0.28, 0.04, at=(cx, cy, r * 0.12), seg=10, m=pore_m, col=HIGH))
    objs = [tile_obj(n_, ob) for n_, ob in pieces.items() if ob]
    objs.append(tile_obj("Pores", pores))
    objs.append(K.box("Base", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.06), m=pore_m, col=HIGH))
    return objs


def metal_panel():
    plates = [K.mat("Panel %d" % i, (v, v, v), rough=0.35, metal=0.7, pits=0.1, bump=0.05) for i, v in
              enumerate([0.88, 0.82, 0.92])]
    seam = K.mat("Seam", (0.25, 0.25, 0.27), rough=0.6, metal=0.5)
    rivet_m = K.mat("Rivet", (0.95, 0.95, 0.95), rough=0.25, metal=0.9)
    vent_m = K.mat("Vent", (0.2, 0.2, 0.22), rough=0.5, metal=0.6)
    pieces = {m.name: [] for m in plates}
    rivets, vents = [], []
    cols, rows = 2, 4
    pw, ph = TILE / cols, TILE / rows
    for c in range(cols):
        for r in range(rows):
            m = random.choice(plates)
            x0, y0 = c * pw + (pw / 2 if r % 2 else 0), r * ph
            pieces[m.name].append(K.box("Plate", (pw - 0.025, ph - 0.025, 0.02), at=(x0 + pw / 2, y0 + ph / 2, 0.0),
                                        m=m, bevel=0.006, seg=2, col=HIGH))
            for k in range(6):
                for side in (0.03, ph - 0.03):
                    rivets.append(K.sphere("Rivet", 0.011, at=(x0 + 0.06 + k * (pw - 0.12) / 5, y0 + side, 0.012),
                                           m=rivet_m, seg=8, col=HIGH))
            if random.random() < 0.3:
                for v in range(5):
                    vents.append(K.box("Slot", (pw * 0.4, 0.014, 0.02), at=(x0 + pw / 2, y0 + ph * 0.3 + v * 0.04,
                                                                             0.004), m=vent_m, col=HIGH))
    objs = [tile_obj(n_, ob) for n_, ob in pieces.items() if ob]
    objs.append(tile_obj("Rivets", rivets))
    if vents:
        objs.append(tile_obj("Vents", vents))
    objs.append(K.box("Seams", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.016), m=seam, col=HIGH))
    return objs


def drystone():
    tones = [K.mat("Dry Stone %d" % i, (v, v * 0.98, v * 0.95), rough=0.9, pits=0.45, bump=1.0) for i, v in
             enumerate([0.88, 0.78, 0.84, 0.72])]
    gap = K.mat("Gap", (0.2, 0.2, 0.2), rough=1.0)
    pieces = {m.name: [] for m in tones}
    y = 0.0
    while y < TILE - 0.02:
        h = random.uniform(0.08, 0.17)
        x = random.uniform(0.0, TILE)
        widths = [random.uniform(0.18, 0.42) for _ in range(7)]
        k = TILE / sum(widths)
        for w in widths:
            w *= k
            m = random.choice(tones)
            b = K.box("Flat Stone", (w - 0.025, h - 0.02, 0.1), at=(x + w / 2, y + h / 2, random.uniform(-0.01, 0.01)),
                      m=m, bevel=0.02, seg=2, rot=(0, 0, random.uniform(-0.05, 0.05)), col=HIGH)
            pieces[m.name].append(_lumpy(b, 0.06, 0.012))
            x += w
        y += h
    objs = [tile_obj(n_, ob) for n_, ob in pieces.items() if ob]
    objs.append(K.box("Gaps", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.07), m=gap, col=HIGH))
    return objs


def glass_facade():
    # The panes are the darkest and smoothest, the mullions bright metal, the floor band matt: tinted with a tower's own
    # dark glass colour, the grid reads as light lines over dark glass, as a curtain wall does from the street
    panes = [K.mat("Pane %d" % i, (v, v, v * 1.04), rough=0.08, metal=0.7) for i, v in enumerate([0.55, 0.5, 0.62])]
    frame = K.mat("Mullion", (0.95, 0.95, 1.0), rough=0.3, metal=0.9, pits=0.05)
    band = K.mat("Floor Band", (0.78, 0.78, 0.84), rough=0.5, metal=0.5, pits=0.1)
    pieces = {m.name: [] for m in panes}
    bars = []
    cols, floors = 4, 2
    cw, fh = TILE / cols, TILE / floors
    for f in range(floors):
        y0 = f * fh
        bars.append(K.box("Band", (TILE, 0.32, 0.06), at=(TILE / 2, y0 + 0.16, 0.0), m=band, bevel=0.01, col=HIGH))
        bars.append(K.box("Sill", (TILE, 0.05, 0.1), at=(TILE / 2, y0 + 0.345, 0.02), m=frame, bevel=0.01, col=HIGH))
        for c in range(cols):
            x0 = c * cw
            for r, (a, b) in enumerate(((0.37, 1.12), (1.15, 1.5))):
                m = random.choice(panes)
                pieces[m.name].append(K.box("Pane", (cw - 0.06, b - a - 0.02, 0.02),
                                            at=(x0 + cw / 2, y0 + (a + b) / 2, -0.01), m=m, col=HIGH))
            bars.append(K.box("Transom", (cw, 0.035, 0.07), at=(x0 + cw / 2, y0 + 1.135, 0.01), m=frame, bevel=0.008,
                              col=HIGH))
    for c in range(cols):
        bars.append(K.box("Mullion", (0.06, TILE, 0.1), at=(c * cw, TILE / 2, 0.02), m=frame, bevel=0.012, col=HIGH))
    objs = [tile_obj(n_, ob) for n_, ob in pieces.items() if ob]
    objs.append(tile_obj("Frames", bars))
    objs.append(K.box("Back", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.04), m=band, col=HIGH))
    return objs


def floorboards():
    wood = [K.mat("Floorboard %d" % i, (v, v * 0.97, v * 0.94), rough=0.6, pits=0.12, bump=0.3, grain=(16.0, 0.22),
                  wear=0.05) for i, v in enumerate([0.9, 0.82, 0.86, 0.78])]
    nail_m = K.mat("Nail", (0.4, 0.4, 0.4), rough=0.5, metal=0.6)
    gap = K.mat("Gap", (0.18, 0.16, 0.15), rough=0.95)
    n = 8
    w = TILE / n
    pieces = {m.name: [] for m in wood}
    nails = []
    for c in range(n):
        y0 = c * w
        x = random.uniform(0.0, TILE)
        lengths = [random.uniform(0.6, 1.4) for _ in range(2)]
        k = TILE / sum(lengths)
        for L in lengths:
            L *= k
            m = random.choice(wood)
            pieces[m.name].append(K.box("Plank", (L - 0.006, w - 0.008, 0.02), at=(x + L / 2, y0 + w / 2,
                                        random.uniform(-0.0015, 0.0015)), m=m, bevel=0.003, seg=1, col=HIGH))
            for e in (0.04, L - 0.04):
                for side in (0.3, 0.7):
                    nails.append(K.cyl("Nail", 0.004, 0.004, at=(x + e, y0 + w * side, 0.011), seg=8, m=nail_m,
                                       col=HIGH))
            x += L
    objs = [tile_obj(nm, ob) for nm, ob in pieces.items() if ob]
    objs.append(tile_obj("Nails", nails))
    objs.append(K.box("Gaps", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.02), m=gap, col=HIGH))
    return objs


def floor_tiles():
    tones = [K.mat("Tile %d" % i, (v, v, v), rough=0.35, pits=0.08, bump=0.08) for i, v in enumerate([0.92, 0.86, 0.9])]
    grout = K.mat("Grout", (0.55, 0.54, 0.52), rough=0.95, bump=0.3)
    n = 4
    w = TILE / n
    pieces = {m.name: [] for m in tones}
    for i in range(n):
        for j in range(n):
            m = random.choice(tones)
            pieces[m.name].append(K.box("Tile", (w - 0.012, w - 0.012, 0.012), at=(i * w + w / 2, j * w + w / 2,
                                        random.uniform(-0.0012, 0.0012)), m=m, bevel=0.004, seg=2,
                                        rot=(random.uniform(-0.004, 0.004), random.uniform(-0.004, 0.004), 0),
                                        col=HIGH))
    objs = [tile_obj(nm, ob) for nm, ob in pieces.items() if ob]
    objs.append(K.box("Grout", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.008), m=grout, col=HIGH))
    return objs


def plaster():
    coat = K.mat("Plaster", (0.92, 0.91, 0.89), rough=0.85, pits=0.06, bump=0.12)
    crack = K.mat("Hairline", (0.62, 0.6, 0.58), rough=0.95)
    wall = K.box("Plaster", (TILE, TILE, 0.04), at=(TILE / 2, TILE / 2, 0.0), m=coat, col=HIGH)
    # trowel marks: the coat pushed about in soft broad swirls
    sub = wall.modifiers.new("Sub", "SUBSURF")
    sub.levels = 0
    bpy.context.view_layer.objects.active = wall
    rem = wall.modifiers.new("Grid", "REMESH")
    rem.mode = "SHARP"
    rem.octree_depth = 7
    dis = wall.modifiers.new("Trowel", "DISPLACE")
    tex = bpy.data.textures.new("TrowelTex", "CLOUDS")
    tex.noise_scale = 0.35
    dis.texture = tex
    dis.texture_coords = "LOCAL"
    dis.direction = "Z"
    dis.strength = 0.006
    objs = [wall]
    # a few hairline cracks wandering a little way, set into the coat
    lines = []
    for _ in range(3):
        x, y = random.uniform(0.2, TILE - 0.2), random.uniform(0.2, TILE - 0.2)
        a = random.uniform(0, math.tau)
        pts = [(x, y, 0.019)]
        for _k in range(6):
            a += random.uniform(-0.7, 0.7)
            x += math.cos(a) * 0.05
            y += math.sin(a) * 0.05
            pts.append((x, y, 0.019))
        lines.append(K.wire("Crack", pts, 0.0018, crack, res=2, col=HIGH))
    objs.append(tile_obj("Cracks", lines))
    return objs


def reptile_scales():
    tones = [K.mat("Scale %d" % i, (v, v, v * 0.96), rough=0.55, pits=0.25, bump=0.3) for i, v in
             enumerate([0.88, 0.8, 0.92])]
    scute = K.mat("Scute", (0.74, 0.72, 0.66), rough=0.75, pits=0.5, bump=0.6)
    seam = K.mat("Seam", (0.3, 0.3, 0.28), rough=0.95)
    per = 8
    rows = 10
    pitch = TILE / per
    h = TILE / rows
    pieces = {m.name: [] for m in tones}
    scutes = []
    for r in range(rows):
        y0 = r * h
        off = pitch / 2 if r % 2 else 0.0
        bony = r % 5 == 2
        for c in range(per):
            x = off + c * pitch
            if bony:
                # a row of bony scutes: taller, ridged down the middle like a croc's back
                b = K.sphere("Scute", pitch * 0.5, at=(x, y0 + h * 0.5, 0.012), m=scute, seg=16,
                             scale=(0.9, 1.1, 0.32), col=HIGH)
                scutes.append(b)
                scutes.append(K.sphere("Keel", pitch * 0.12, at=(x, y0 + h * 0.5, 0.05), m=scute, seg=10,
                                       scale=(0.6, 3.2, 0.9), col=HIGH))
                continue
            m = random.choice(tones)
            s = K.sphere("Scale", pitch * 0.58, at=(x, y0 + h * 0.4, 0.008), m=m, seg=18,
                         scale=(1.0, 0.85 + random.uniform(-0.08, 0.08), 0.14), col=HIGH)
            s.rotation_euler = (-0.16, 0, random.uniform(-0.05, 0.05))
            pieces[m.name].append(s)
    objs = [tile_obj(n, ob) for n, ob in pieces.items() if ob]
    objs.append(tile_obj("Scutes", scutes))
    objs.append(K.box("Seam", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.012), m=seam, col=HIGH))
    return objs


def goblin_skin():
    hide = K.mat("Hide", (0.9, 0.9, 0.88), rough=0.7, pits=0.35, bump=0.3)
    wart = K.mat("Wart", (0.8, 0.78, 0.72), rough=0.8, pits=0.4, bump=0.4)
    crease = K.mat("Crease", (0.55, 0.54, 0.52), rough=0.9)
    skin = K.box("Hide", (TILE, TILE, 0.03), at=(TILE / 2, TILE / 2, 0.0), m=hide, col=HIGH)
    bpy.context.view_layer.objects.active = skin
    rem = skin.modifiers.new("Grid", "REMESH")
    rem.mode = "SHARP"
    rem.octree_depth = 7
    for nm, sc, st in [("Pebble", 0.025, 0.01), ("Bulge", 0.18, 0.008)]:
        dis = skin.modifiers.new(nm, "DISPLACE")
        tex = bpy.data.textures.new(nm + "Tex", "CLOUDS")
        tex.noise_scale = sc
        dis.texture = tex
        dis.texture_coords = "LOCAL"
        dis.direction = "Z"
        dis.strength = st
    objs = [skin]
    warts = []
    for _ in range(26):
        r = random.uniform(0.006, 0.02)
        warts.append(K.sphere("Wart", r, at=(random.uniform(0, TILE), random.uniform(0, TILE), 0.014), m=wart,
                              seg=10, scale=(1, 1, 0.6), col=HIGH))
    objs.append(tile_obj("Warts", warts))
    # wrinkles: short wavy creases pressed into the skin
    lines = []
    for _ in range(9):
        x, y = random.uniform(0.05, TILE - 0.05), random.uniform(0.05, TILE - 0.05)
        a = random.uniform(-0.4, 0.4)
        pts = []
        for k in range(7):
            pts.append((x + math.cos(a) * k * 0.018, y + math.sin(a) * k * 0.018 + math.sin(k) * 0.004, 0.016))
        lines.append(K.wire("Crease", pts, 0.0022, crease, res=2, col=HIGH))
    objs.append(tile_obj("Creases", lines))
    return objs


def tweed():
    yarn = [K.mat("Yarn %d" % i, (v, v, v * 0.97), rough=0.95, pits=0.1, bump=0.2) for i, v in
            enumerate([0.9, 0.82, 0.88])]
    fleck = K.mat("Fleck", (0.45, 0.42, 0.4), rough=0.95)
    n = 20
    step = TILE / n
    pieces = {m.name: [] for m in yarn}
    flecks = []
    for i in range(n):
        c = (i + 0.5) * step
        for along in (True, False):
            m = fleck if random.random() < 0.12 else random.choice(yarn)
            pts = []
            for k in range(n * 2 + 1):
                t = k * step / 2
                # each thread goes over one, under the next (a twill: shifted one a row)
                z = 0.004 * math.cos(math.pi * (k / 2.0 + i * 0.5 + (0 if along else 1)))
                pts.append((t, c, 0.01 + z) if along else (c, t, 0.01 - z))
            w = K.wire("Thread", pts, step * 0.36, m, res=2, col=HIGH)
            (flecks if m is fleck else pieces[m.name]).append(w)
    objs = [tile_obj(n2, ob) for n2, ob in pieces.items() if ob]
    if flecks:
        objs.append(tile_obj("Flecks", flecks))
    objs.append(K.box("Under", (TILE, TILE, 0.004), at=(TILE / 2, TILE / 2, 0.0), m=fleck, col=HIGH))
    return objs


def _scratches(n, m, depth, length, width, along=None):
    """Thin scratches pressed into a surface: short wires just under its top."""
    out = []
    for _ in range(n):
        x, y = random.uniform(0, TILE), random.uniform(0, TILE)
        a = along if along is not None else random.uniform(0, math.pi)
        a += random.uniform(-0.25, 0.25)
        L = random.uniform(0.4, 1.0) * length
        pts = [(x + math.cos(a) * L * k / 4, y + math.sin(a) * L * k / 4, depth) for k in range(5)]
        out.append(K.wire("Scratch", pts, width, m, res=2, col=HIGH))
    return out


def maple():
    # Grain along the image's Y, so it runs the length of a deck (the deck's long side is its Z: Godot's triplanar
    # lays the patch's Y along it on the top face)
    wood = [K.mat("Maple %d" % i, (v, v * 0.97, v * 0.93), rough=0.55, pits=0.1, bump=0.15, grain=(22.0, 0.18))
            for i, v in enumerate([0.92, 0.86])]
    scuff = K.mat("Scuff", (0.62, 0.6, 0.58), rough=0.8)
    objs = []
    # two veneer strips a little uneven, so the grain changes tone across the board
    for i, m in enumerate(wood):
        objs.append(K.box("Ply %d" % i, (TILE / 2 - 0.002, TILE, 0.01), at=(TILE / 4 + i * TILE / 2, TILE / 2, 0.0),
                          m=m, bevel=0.001, seg=1, col=HIGH))
    objs.append(tile_obj("Scratches", _scratches(16, scuff, 0.0045, 0.12, 0.0012)))
    objs.append(K.box("Under", (TILE, TILE, 0.004), at=(TILE / 2, TILE / 2, -0.006), m=scuff, col=HIGH))
    return objs


def grip_tape():
    grit = K.mat("Grit", (0.9, 0.9, 0.9), rough=0.95, pits=0.05, bump=0.8)
    sheet = K.box("Grit", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, 0.0), m=grit, col=HIGH)
    bpy.context.view_layer.objects.active = sheet
    rem = sheet.modifiers.new("Grid", "REMESH")
    rem.mode = "SHARP"
    rem.octree_depth = 8
    for nm, sc, st in [("Sand", 0.004, 0.0012), ("Ripple", 0.05, 0.0006)]:
        dis = sheet.modifiers.new(nm, "DISPLACE")
        tex = bpy.data.textures.new(nm + "Tex", "CLOUDS")
        tex.noise_scale = sc
        dis.texture = tex
        dis.texture_coords = "LOCAL"
        dis.direction = "Z"
        dis.strength = st
    return [sheet]


def brushed_metal():
    steel = K.mat("Steel", (0.9, 0.9, 0.92), rough=0.32, metal=0.85, pits=0.05)
    line = K.mat("Brush", (0.8, 0.8, 0.82), rough=0.45, metal=0.85)
    dent = K.mat("Ding", (0.7, 0.7, 0.72), rough=0.5, metal=0.8)
    objs = [K.box("Steel", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, 0.0), m=steel, col=HIGH)]
    brush = []
    for i in range(90):
        y = (i + random.uniform(0.1, 0.9)) * TILE / 90
        x0 = random.uniform(-0.1, TILE * 0.5)
        L = random.uniform(0.2, 0.6)
        brush.append(K.wire("Brush", [(x0, y, 0.005), (x0 + L / 2, y + random.uniform(-0.001, 0.001), 0.005),
                                      (x0 + L, y, 0.005)], 0.0006, line, res=2, col=HIGH))
    objs.append(tile_obj("Brush", brush))
    objs.append(tile_obj("Scratches", _scratches(10, dent, 0.005, 0.1, 0.0008)))
    dings = [K.sphere("Ding", random.uniform(0.004, 0.01), at=(random.uniform(0, TILE), random.uniform(0, TILE),
                      0.0045), m=dent, seg=8, scale=(1, 1, 0.3), col=HIGH) for _ in range(5)]
    objs.append(tile_obj("Dings", dings))
    return objs


def tread():
    rubber = K.mat("Rubber", (0.88, 0.88, 0.88), rough=0.9, pits=0.08, bump=0.15)
    groove = K.mat("Groove", (0.4, 0.4, 0.4), rough=0.95)
    blocks = []
    rows, cols = 8, 4
    bw, bh = TILE / cols, TILE / rows
    for r in range(rows):
        for c in range(cols):
            # zig-zag: every other row shifted half a block and leant the other way
            x = c * bw + bw / 2 + (bw / 2 if r % 2 else 0)
            y = r * bh + bh / 2
            b = K.box("Block", (bw * 0.78, bh * 0.66, 0.018), at=(x, y, 0.004), m=rubber, bevel=0.003, seg=2,
                      col=HIGH)
            b.rotation_euler = (0, 0, 0.35 if r % 2 else -0.35)
            blocks.append(b)
    objs = [tile_obj("Blocks", blocks)]
    objs.append(K.box("Grooves", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, -0.006), m=groove, col=HIGH))
    return objs


def leaf_skin():
    skin = K.mat("Leaf", (0.9, 0.92, 0.86), rough=0.55, pits=0.1, bump=0.35)
    vein = K.mat("Vein", (0.98, 1.0, 0.92), rough=0.5)
    objs = [K.box("Leaf", (TILE, TILE, 0.01), at=(TILE / 2, TILE / 2, 0.0), m=skin, col=HIGH)]
    veins = []
    # the midrib up the middle (the length of the board), and veins sweeping off it both ways
    veins.append(K.wire("Midrib", [(TILE / 2, -0.05, 0.005), (TILE / 2, TILE + 0.05, 0.005)], 0.006, vein, res=2,
                        col=HIGH))
    for k in range(8):
        y = (k + 0.5) * TILE / 8
        for side in (-1, 1):
            pts = []
            for t in range(6):
                f = t / 5.0
                pts.append((TILE / 2 + side * f * TILE * 0.5, y + f * f * 0.12, 0.005))
            veins.append(K.wire("Vein", pts, 0.0025 - 0.0005 * (k % 2), vein, res=2, col=HIGH))
            # little side veins off each
            for t in (0.35, 0.65):
                px, py = TILE / 2 + side * t * TILE * 0.5, y + t * t * 0.12
                veins.append(K.wire("Veinlet", [(px, py, 0.005), (px + side * 0.03, py + 0.04, 0.005),
                                                (px + side * 0.035, py + 0.07, 0.005)], 0.0012, vein, res=2,
                                    col=HIGH))
    objs.append(tile_obj("Veins", veins))
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
         "dome_scales": dome_scales, "bark": bark, "rock": rock, "ice": ice, "snow": snow, "coral": coral,
         "metal_panel": metal_panel, "drystone": drystone, "glass_facade": glass_facade, "floorboards": floorboards,
         "floor_tiles": floor_tiles, "plaster": plaster,
         "reptile_scales": reptile_scales, "goblin_skin": goblin_skin, "tweed": tweed,
         "maple": maple, "grip_tape": grip_tape, "brushed_metal": brushed_metal, "tread": tread, "leaf_skin": leaf_skin}


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

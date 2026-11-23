# The Star Arena (scripts/arena_level.gd), built the detailed way (tools/bake_kit.py; 23 Nov 2026, Hayden: "Lets keep
# baking details"): the low wall round the floor, the stands' steps and seats, the four spotlight towers, the six
# hatches the enemies pop out of, the tunnel in, Blip's podium and the Round Board. Each HIGH version is baked onto a
# LOW one, which is what the game draws.
#
# Every piece is made in the space of the plain mesh or node it replaces (arena_level.gd's BoxMesh and CylinderMesh
# are centred on their node), so scripts/detail_props.gd dress_star_arena puts each one where the old one was and
# every collision stays the game's. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   arena_wall       one of the 64 lengths of the low wall, 2.66 x 1.3 x 0.6 (centred; -z faces the floor), with its
#                    gold trim on top (0.12 x 0.7, 0.69 up): lilac blocks in courses, a plinth, studs on the trim and a
#                    gold star on the floor side.
#   stand_step       the top 1.45 m of one block of the stands, 2.8 wide and 2.05 deep, its origin in the middle of its
#                    top (-z faces the floor): a riser of blocks under a gold nosing, a paved walk where the crowd stands
#                    and three bucket seats behind it. The game stretches it to each tier's width.
#   spotlight_tower  a spotlight tower in its node's space (from the ground up): a riveted steel mast tapering from
#                    0.7 to 0.45 over 16 m on a bolted foot, a ladder, a railed platform and the lamp head (a drum with
#                    a glowing lens underneath and a vented cap) at 16.4.
#   arena_hatch      a hatch in its node's space: a gold rim (1.0 to 1.32 across, bolted) round the game's glowing
#                    disc, with a grille of six bars and a hub over it.
#   arena_tunnel     the tunnel in, in its node's space: both walls (0.8 x 4.2 x 15.5 at x +-3.4, z 25 to 40.5) in
#                    blocks with a coping, the roof (7.6 x 0.5 x 8.5) on beams, glowing wall lamps, and a gold frame
#                    round the floor end.
#   blip_podium      Blip's podium in its node's space (0.9 across at the foot to 0.8, 0.6 high): fluted gold with a
#                    star on the front.
#   round_board      the Round Board in its node's space: the dark board (3.6 x 2.6 x 0.2, 2.4 up; its faces stay flat
#                    for the words) in a gold-edged frame, two posts down to the ground and a crest with a star.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_star_arena.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["arena_wall", "stand_step", "spotlight_tower", "arena_hatch", "arena_tunnel", "blip_podium", "round_board"]
KIND = next((a for a in sys.argv if a in KINDS), "arena_wall")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

STONE = (0.78, 0.66, 0.92)
STONE_PALE = (0.87, 0.78, 0.97)
STONE_DARK = (0.64, 0.52, 0.8)
MORTAR = (0.5, 0.4, 0.62)
STANDS = (0.55, 0.45, 0.72)
STANDS_DARK = (0.44, 0.35, 0.6)
GOLD = (1.0, 0.8, 0.3)
GOLD_DARK = (0.82, 0.6, 0.18)
STEEL = (0.35, 0.3, 0.45)
STEEL_DARK = (0.24, 0.2, 0.32)
LAMP = (1.0, 0.95, 0.75)
BOARD = (0.16, 0.1, 0.28)
SEATS = [(1.0, 0.55, 0.75), (0.45, 0.95, 1.0), (1.0, 0.85, 0.35)]


def at(x, y, z):
    """Godot's (x, y, z) in Blender's space."""
    return (x, -z, y)


def gsize(x, y, z):
    return (x, z, y)


def gbox(name, size, pos, m, col, bevel=0.0, rot=(0, 0, 0)):
    """A box given in Godot's terms (size x, y, z and its middle), rotation in Godot's x, y, z."""
    return K.box(name, gsize(*size), at=at(*pos), m=m, bevel=bevel, col=col, rot=(rot[0], -rot[2], rot[1]))


def rod(name, a, b, r, m, col, seg=12, r2=None):
    a, b = Vector(a), Vector(b)
    d = b - a
    ob = K.cyl(name, r, d.length, at=(a + b) / 2, seg=seg, m=m, col=col, r2=r2)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return ob


def grod(name, a, b, r, m, col, seg=12, r2=None):
    return rod(name, at(*a), at(*b), r, m, col, seg=seg, r2=r2)


def gwire(name, pts, r, m, col, closed=False, res=12, bevel_res=4):
    return K.wire(name, [at(*p) for p in pts], r, m=m, closed=closed, res=res, bevel_res=bevel_res, col=col)


def glathe(name, prof, m, col, seg=32, y=0.0, pos=(0, 0, 0), **kw):
    """A lathe round Godot's y, its profile [(r, y)] measured from pos."""
    ob = K.lathe(name, prof, seg=seg, m=m, col=col, **kw)
    ob.location = at(*pos)
    return ob


def blob(name, r, pos, m, col, seed=0, seg=12, lump=0.25, squash=(1.0, 1.0, 1.0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(4, seg // 2), radius=r)
    off = Vector((seed * 3.17, seed * 1.71, seed * 2.33))
    for v in bm.verts:
        n = v.co.normalized()
        v.co = v.co * (1.0 + lump * noise.noise(n * 1.6 + off))
        v.co.x *= squash[0]
        v.co.y *= squash[2]
        v.co.z *= squash[1]
    ob = K._obj(name, bm, m, True, col)
    ob.location = at(*pos)
    return ob


def _nodes(m):
    nt = m.node_tree
    return nt, nt.nodes["Principled BSDF"], nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]


def _mix_rgb(nt, fac, a, b):
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(fac, mix.inputs["Factor"])
    if isinstance(a, tuple):
        K._rgba(mix.inputs, "A").default_value = (*(K.srgb_to_linear(c) for c in a), 1)
    else:
        nt.links.new(a, K._rgba(mix.inputs, "A"))
    K._rgba(mix.inputs, "B").default_value = (*(K.srgb_to_linear(c) for c in b), 1)
    return K._rgba(mix.outputs, "Result")


def _patches(nt, co, scale, lo, hi, detail=6.0, w=None):
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = detail
    if w is not None:
        nz.noise_dimensions = "4D"
        nz.inputs["W"].default_value = w
    nt.links.new(co, nz.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = lo
    mr.inputs["From Max"].default_value = hi
    nt.links.new(nz.outputs["Fac"], mr.inputs["Value"])
    return mr.outputs["Result"]


def mottled(name, a, b, scale=6.0, rough=0.6, metal=0.0, bump=0.0, lo=0.35, hi=0.7, third=None, grain=None):
    m = K.mat(name, a, rough=rough, metal=metal, bump=bump, grain=grain)
    nt, bsdf, co = _nodes(m)
    c = _mix_rgb(nt, _patches(nt, co, scale, lo, hi), a, b)
    if third:
        c = _mix_rgb(nt, _patches(nt, co, scale * 1.7, 0.62, 0.66, w=2.7), c, third)
    nt.links.new(c, bsdf.inputs["Base Color"])
    return m


def glowing(m, rgb, strength):
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Emission Color"].default_value = (*(K.srgb_to_linear(c) for c in rgb), 1.0)
    b.inputs["Emission Strength"].default_value = strength
    return m


def bake_part(name, high, low, size, emit=False, emit_strength=1.0, extrusion=0.03, ray=0.1, ao=True):
    hi_tris = K.tri_count(high)
    prop = K.join(name, low)
    lo_tris = K.tri_count([prop])
    K.uv_unwrap(prop, margin=0.006)
    maps = K.bake(prop, high, size=size, name=name, extrusion=extrusion, ray=ray,
                  maps=["normal"] + (["ao"] if ao else []) + ["color", "rough", "metal"] + (["emit"] if emit else []))
    K.finish(prop, maps, size, name, emit_strength=emit_strength)
    print("TRIS %s high %d low %d" % (name, hi_tris, lo_tris))
    return prop


def stone_mats():
    """Three lilac stones for blocks (picked at random so the courses look laid by hand) and the mortar."""
    return ([mottled("Palace Stone", STONE, STONE_DARK, scale=4.0, rough=0.75, bump=0.35),
             mottled("Palace Stone Pale", STONE_PALE, STONE, scale=5.0, rough=0.7, bump=0.35),
             mottled("Palace Stone Deep", STONE, (0.66, 0.53, 0.82), scale=3.0, rough=0.8, bump=0.4)],
            K.mat("Mortar", MORTAR, rough=0.95, bump=0.3))


def gold_mat(name="Royal Gold"):
    return mottled(name, GOLD, GOLD_DARK, scale=7.0, rough=0.28, metal=0.85, bump=0.08)


def block_face(obs, col, mats, rnd, centre, u, n, width, height, course=0.6, block=(0.9, 1.5), depth=0.08,
               gap=0.035, bevel=0.025):
    """Stone blocks laid in courses over a flat face: centre is the face's middle (Godot), u its across direction
    (a unit x or z), n its outward normal, width and height its size. Each block's front lies on the face."""
    u, n = Vector(u), Vector(n)
    rows = max(1, round(height / course))
    ch = height / rows
    for r in range(rows):
        y = -height / 2 + ch * (r + 0.5)
        x = -width / 2 - (rnd.uniform(0.2, 0.6) if r % 2 else 0.0)
        while x < width / 2 - 0.05:
            w = rnd.uniform(*block)
            x0, x1 = max(x, -width / 2), min(x + w, width / 2)
            if x1 - x0 > 0.12:
                mid = Vector(centre) + u * ((x0 + x1) / 2) + Vector((0, y, 0)) - n * (depth / 2)
                size = u * (x1 - x0 - gap) + Vector((0, ch - gap, 0)) + n * depth
                obs.append(gbox("Block", (abs(size.x), abs(size.y), abs(size.z)), tuple(mid), rnd.choice(mats), col,
                                bevel=bevel))
            x += w




def gstar(name, r, depth, centre, face, m, col, inner=0.45, spin=0.0):
    """A little five-pointed star relief, depth thick, its face looking along face ('-z', '+z' or '+y'/'-y')."""
    bm = bmesh.new()
    pts = []
    for k in range(10):
        a = math.pi / 2 + spin + k * math.pi / 5
        rr = r if k % 2 == 0 else r * inner
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    vs0 = [bm.verts.new((x, y, -depth / 2)) for x, y in pts]
    vs1 = [bm.verts.new((x, y, depth / 2)) for x, y in pts]
    c0 = bm.verts.new((0, 0, -depth / 2))
    c1 = bm.verts.new((0, 0, depth / 2 + depth * 0.6))
    for k in range(10):
        j = (k + 1) % 10
        bm.faces.new((vs0[j], vs0[k], c0))
        bm.faces.new((vs1[k], vs1[j], c1))
        bm.faces.new((vs0[k], vs0[j], vs1[j], vs1[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = K._obj(name, bm, m, False, col)
    # the star is made facing Blender +z; turn it to face the Godot direction asked for
    rot = {"+y": (0, 0, 0), "-y": (math.pi, 0, 0), "-z": (math.pi / 2, 0, 0), "+z": (-math.pi / 2, 0, 0),
           "+x": (0, math.pi / 2, 0), "-x": (0, -math.pi / 2, 0)}[face]
    ob.rotation_euler = rot
    ob.location = at(*centre)
    return ob


def steel_mat(name="Tower Steel"):
    return mottled(name, STEEL, STEEL_DARK, scale=8.0, rough=0.45, metal=0.65, bump=0.1)


# ================================================================ the low wall
def arena_wall():
    stones, mortar = stone_mats()
    gold = gold_mat("Arena Gold")
    L, H, T = 2.66, 1.3, 0.6

    def build(col, high):
        if not high:
            return [gbox("Wall", (L, H, T), (0, 0, 0), stones[0], col),
                    gbox("Trim", (L, 0.12, 0.7), (0, 0.69, 0), gold, col)]
        rnd = random.Random(101)
        obs = [gbox("Core", (L, H - 0.04, T - 0.06), (0, 0, 0), mortar, col)]
        for s in (-1, 1):
            block_face(obs, col, stones, rnd, (0, 0.06, s * T / 2), (1, 0, 0), (0, 0, s), L, H - 0.32, course=0.34,
                       block=(0.45, 0.85), depth=0.06, gap=0.03, bevel=0.018)
            obs.append(gbox("Plinth", (L, 0.2, 0.08), (0, -H / 2 + 0.1, s * (T / 2 + 0.01)), stones[2], col,
                            bevel=0.025))
        obs.append(gbox("Trim", (L, 0.1, 0.7), (0, 0.68, 0), gold, col, bevel=0.025))
        obs.append(gbox("Trim Lip", (L, 0.04, 0.74), (0, 0.635, 0), gold, col, bevel=0.012))
        for s in (-1, 1):                                       # studs along both edges of the trim
            for k in range(6):
                x = -L / 2 + L * (k + 0.5) / 6
                obs.append(K.sphere("Stud", 0.025, at=at(x, 0.66, s * 0.36), m=gold, seg=8, col=col))
        # a gold star on the floor side, in a round stone boss
        boss = glathe("Boss", [(0, 0), (0.26, 0), (0.24, 0.05), (0, 0.06)], stones[1], col, seg=24)
        boss.rotation_euler = (math.pi / 2, 0, 0)
        boss.location = at(0, 0.08, -T / 2)
        obs.append(boss)
        obs.append(gstar("Star", 0.18, 0.04, (0, 0.08, -T / 2 - 0.07), "-z", gold, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a step of the stands
def stand_step():
    stones = [mottled("Stand Stone", STANDS, STANDS_DARK, scale=4.0, rough=0.8, bump=0.35),
              mottled("Stand Stone Pale", (0.62, 0.52, 0.78), STANDS, scale=5.0, rough=0.75, bump=0.35)]
    mortar = K.mat("Stand Mortar", (0.38, 0.3, 0.5), rough=0.95, bump=0.3)
    paving = mottled("Stand Paving", (0.66, 0.58, 0.8), (0.56, 0.48, 0.7), scale=5.0, rough=0.85, bump=0.3)
    gold = gold_mat("Stand Gold")
    seat_m = [mottled("Seat %d" % k, c, tuple(x * 0.82 for x in c), scale=9.0, rough=0.35, bump=0.05)
              for k, c in enumerate(SEATS)]
    leg = steel_mat("Seat Leg")
    W, H, D = 2.8, 1.45, 2.05

    def seats(obs, col, high):
        for k in range(3):
            x = -W / 2 + W * (k + 0.5) / 3
            sm = seat_m[k]
            if not high:
                continue
            obs.append(gbox("Pedestal", (0.12, 0.3, 0.3), (x, 0.15, 0.5), leg, col, bevel=0.02))
            obs.append(gbox("Pedestal Foot", (0.3, 0.04, 0.4), (x, 0.02, 0.5), leg, col, bevel=0.01))
            obs.append(gbox("Seat", (0.62, 0.1, 0.5), (x, 0.36, 0.48), sm, col, bevel=0.04))
            obs.append(gbox("Seat Lip", (0.62, 0.06, 0.08), (x, 0.4, 0.25), sm, col, bevel=0.025))
            obs.append(gbox("Back", (0.62, 0.5, 0.08), (x, 0.66, 0.78), sm, col, bevel=0.04, rot=(-0.12, 0, 0)))
            obs.append(gbox("Back Rim", (0.66, 0.06, 0.1), (x, 0.92, 0.8), sm, col, bevel=0.025))
            obs.append(gstar("Seat Star", 0.07, 0.02, (x, 0.7, 0.73), "-z", gold, col))

    def build(col, high):
        if not high:
            return [gbox("Step", (W, H, D), (0, -H / 2, 0), stones[0], col),
                    gbox("Seat Row", (W - 0.1, 0.14, 0.55), (0, 0.36, 0.48), seat_m[0], col),
                    gbox("Seat Legs", (W - 0.3, 0.3, 0.3), (0, 0.15, 0.5), leg, col),
                    gbox("Back Row", (W - 0.1, 0.6, 0.14), (0, 0.66, 0.8), seat_m[1], col)]
        rnd = random.Random(111)
        obs = [gbox("Core", (W, H - 0.02, D - 0.04), (0, -H / 2 - 0.01, 0), mortar, col)]
        block_face(obs, col, stones, rnd, (0, -H / 2 - 0.08, -D / 2), (1, 0, 0), (0, 0, -1), W, H - 0.2, course=0.42,
                   block=(0.5, 0.95), depth=0.06, gap=0.03, bevel=0.018)
        # the walk on top: flags in two rows, and a gold nosing on the front edge
        for r, z0 in enumerate((-0.98, -0.42, 0.14)):
            x = -W / 2 - (rnd.uniform(0.1, 0.4) if r % 2 else 0.0)
            while x < W / 2 - 0.05:
                w = rnd.uniform(0.5, 0.9)
                x0, x1 = max(x, -W / 2), min(x + w, W / 2)
                if x1 - x0 > 0.1:
                    obs.append(gbox("Flag", (x1 - x0 - 0.025, 0.05, 0.54), ((x0 + x1) / 2, -0.025, z0 + 0.28),
                                    rnd.choice([paving, stones[1]]), col, bevel=0.012))
                x += w
        obs.append(gbox("Nosing", (W, 0.08, 0.1), (0, -0.04, -D / 2 + 0.04), gold, col, bevel=0.02))
        obs.append(gbox("Nosing Front", (W, 0.12, 0.03), (0, -0.1, -D / 2 - 0.005), gold, col, bevel=0.01))
        seats(obs, col, True)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a spotlight tower
def spotlight_tower():
    steel = steel_mat()
    dark = K.mat("Tower Dark", STEEL_DARK, rough=0.5, metal=0.6)
    gold = gold_mat("Tower Gold")
    lens = glowing(K.mat("Lens", LAMP, rough=0.15), LAMP, 2.4)
    stone = mottled("Foot Stone", STONE, STONE_DARK, scale=4.0, rough=0.75, bump=0.35)

    def r_at(y):
        return 0.7 + (0.45 - 0.7) * y / 16.0

    def build(col, high):
        if not high:
            return [glathe("Mast", [(0, 0), (1.0, 0), (1.0, 0.5), (0.72, 0.6), (0.45, 16.0), (0, 16.0)], steel, col,
                           seg=16),
                    gbox("Ladder", (0.5, 15.0, 0.1), (0, 8.0, 0.78), dark, col),
                    glathe("Platform", [(0, 15.2), (1.6, 15.2), (1.6, 15.9), (0, 15.9)], dark, col, seg=24),
                    glathe("Lamp", [(0, 15.85), (0.92, 15.85), (1.25, 16.9), (1.0, 17.25), (0, 17.4)], dark, col,
                           seg=24)]
        rnd = random.Random(121)
        obs = []
        # the foot: a stone plinth and a steel flange with bolts
        obs.append(glathe("Plinth", [(0, 0), (1.0, 0), (1.0, 0.32), (0.92, 0.38), (0, 0.38)], stone, col, seg=48))
        obs.append(glathe("Flange", [(0, 0.38), (0.86, 0.38), (0.86, 0.5), (0.72, 0.56), (0, 0.56)], steel, col,
                          seg=48))
        for k in range(10):
            a = k * math.tau / 10
            obs.append(K.cyl("Bolt", 0.04, 0.08, at=at(math.cos(a) * 0.78, 0.53, math.sin(a) * 0.78), m=gold, seg=6,
                             col=col))
        # the mast, in sections with riveted collars
        prof = [(0, 0.56)]
        for k in range(8):
            y0, y1 = 0.56 + k * (15.3 - 0.56) / 8, 0.56 + (k + 1) * (15.3 - 0.56) / 8
            prof += [(r_at(y0) - 0.01, y0), (r_at(y0 + 0.05), y0 + 0.05), (r_at(y1 - 0.05), y1 - 0.05),
                     (r_at(y1) - 0.01, y1)]
            if k > 0:
                obs.append(glathe("Collar", [(r_at(y0) + 0.0, y0 - 0.1), (r_at(y0) + 0.05, y0 - 0.08),
                                             (r_at(y0) + 0.05, y0 + 0.08), (r_at(y0), y0 + 0.1)], gold if k % 2 else
                                  dark, col, seg=48))
                for j in range(12):
                    a = j * math.tau / 12 + rnd.uniform(-0.04, 0.04)
                    rr = r_at(y0) + 0.055
                    obs.append(K.sphere("Rivet", 0.022, at=at(math.cos(a) * rr, y0, math.sin(a) * rr), m=dark, seg=6,
                                        col=col))
        prof += [(0, 15.3)]
        obs.append(glathe("Mast", prof, steel, col, seg=64))
        # a ladder up the back (+z side)
        for s in (-1, 1):
            obs.append(grod("Rail", (s * 0.22, 0.6, 0.78), (s * 0.22, 15.3, 0.78), 0.03, dark, col, seg=8))
        y = 0.9
        while y < 15.2:
            obs.append(grod("Rung", (-0.22, y, 0.78), (0.22, y, 0.78), 0.02, steel, col, seg=6))
            y += 0.32
        for y in range(2, 15, 3):                                # brackets holding it to the mast
            obs.append(grod("Bracket", (0, y, r_at(y) - 0.05), (0, y, 0.78), 0.025, dark, col, seg=6))
        # the platform under the lamp: a grated deck on struts, and a railing
        obs.append(glathe("Deck", [(0.4, 15.3), (1.55, 15.3), (1.55, 15.38), (0.4, 15.38)], dark, col, seg=48))
        for k in range(24):
            a = k * math.tau / 24
            obs.append(gbox("Grate", (1.1, 0.03, 0.04), (math.cos(a) * 0.98, 15.4, math.sin(a) * 0.98), steel, col,
                            rot=(0, -a, 0)))
        for k in range(6):
            a = k * math.tau / 6
            obs.append(grod("Strut", (math.cos(a) * 0.5, 14.3, math.sin(a) * 0.5),
                            (math.cos(a) * 1.45, 15.3, math.sin(a) * 1.45), 0.035, dark, col, seg=6))
        for k in range(12):
            a = k * math.tau / 12
            obs.append(grod("Post", (math.cos(a) * 1.52, 15.38, math.sin(a) * 1.52),
                            (math.cos(a) * 1.52, 15.88, math.sin(a) * 1.52), 0.025, gold, col, seg=6))
        obs.append(gwire("Railing", [(math.cos(k * math.tau / 16) * 1.52, 15.88, math.sin(k * math.tau / 16) * 1.52)
                                     for k in range(16)], 0.035, gold, col, closed=True, res=8, bevel_res=2))
        # the lamp head: a drum with a glowing lens underneath, gold rings and a vented cap
        obs.append(glathe("Head", [(0.7, 15.9), (0.92, 15.92), (1.22, 16.85), (1.2, 16.95), (0.98, 17.2),
                                   (0.5, 17.32), (0, 17.36)], dark, col, seg=64))
        obs.append(glathe("Lens", [(0, 15.88), (0.86, 15.88), (0.9, 15.93), (0, 15.95)], lens, col, seg=48))
        obs.append(glathe("Lens Ring", [(1.19, 16.2), (1.23, 16.22), (1.25, 16.6), (1.21, 16.62)], lens, col, seg=64))
        for yy in (16.0, 16.85):
            rr = 0.95 + (1.22 - 0.95) * (yy - 15.92) / 0.93
            obs.append(glathe("Head Gold", [(rr, yy - 0.05), (rr + 0.04, yy - 0.03), (rr + 0.04, yy + 0.03),
                                            (rr, yy + 0.05)], gold, col, seg=64))
        for k in range(16):                                      # vents round the cap
            a = k * math.tau / 16
            obs.append(gbox("Vent", (0.05, 0.06, 0.32), (math.cos(a) * 0.78, 17.26, math.sin(a) * 0.78), steel, col,
                            rot=(0, -a + math.pi / 2, 0.25)))
        obs.append(gstar("Finial", 0.22, 0.06, (0, 17.62, 0), "-z", gold, col))
        obs.append(grod("Finial Stem", (0, 17.3, 0), (0, 17.42, 0), 0.04, gold, col, seg=8))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a hatch
def arena_hatch():
    gold = gold_mat("Hatch Gold")
    dark = K.mat("Hatch Dark", STEEL_DARK, rough=0.5, metal=0.6)

    def build(col, high):
        if not high:
            obs = [glathe("Rim", [(1.0, 0.03), (1.34, 0.03), (1.3, 0.12), (1.03, 0.12)], gold, col, seg=32)]
            for k in range(3):
                obs.append(gbox("Bars", (2.06, 0.05, 0.1), (0, 0.105, 0), dark, col, rot=(0, k * math.pi / 3, 0)))
            return obs
        obs = [glathe("Rim", [(1.0, 0.03), (1.34, 0.03), (1.34, 0.06), (1.3, 0.11), (1.05, 0.12), (1.0, 0.1)], gold,
                      col, seg=96)]
        obs.append(glathe("Rim Groove", [(1.16, 0.115), (1.2, 0.125), (1.24, 0.115)], K.mat("Groove", GOLD_DARK,
                                                                                          rough=0.4, metal=0.8), col,
                          seg=96))
        for k in range(12):
            a = k * math.tau / 12
            obs.append(K.cyl("Bolt", 0.035, 0.03, at=at(math.cos(a) * 1.12, 0.125, math.sin(a) * 1.12), m=dark,
                             seg=6, col=col))
        for k in range(6):                                       # a grille of bars from the rim to a hub
            a = k * math.tau / 6
            obs.append(gbox("Bar", (0.92, 0.04, 0.07), (math.cos(a) * 0.55, 0.105, math.sin(a) * 0.55), dark, col,
                            bevel=0.012, rot=(0, -a, 0)))
        obs.append(glathe("Hub", [(0, 0.08), (0.2, 0.08), (0.2, 0.12), (0.14, 0.14), (0, 0.145)], gold, col, seg=32))
        obs.append(gstar("Hub Star", 0.12, 0.02, (0, 0.15, 0), "-z", gold, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the tunnel
def arena_tunnel():
    stones, mortar = stone_mats()
    gold = gold_mat("Tunnel Gold")
    beam_m = mottled("Beam", (0.42, 0.3, 0.5), (0.32, 0.22, 0.4), scale=6.0, rough=0.7, grain=(12.0, 0.25))
    lamp = glowing(K.mat("Tunnel Lamp", LAMP, rough=0.2), LAMP, 2.0)
    Z0, Z1 = 25.0, 40.5
    ZM = (Z0 + Z1) / 2
    L = Z1 - Z0

    def build(col, high):
        if not high:
            obs = []
            for s in (-1, 1):
                obs.append(gbox("Wall", (0.8, 4.2, L), (s * 3.4, 2.1, ZM), stones[0], col))
                obs.append(gbox("Coping", (1.0, 0.2, L), (s * 3.4, 4.3, ZM), stones[1], col))
                obs.append(gbox("Frame", (0.5, 4.2, 0.5), (s * 3.15, 2.1, Z0 + 0.05), gold, col))
            obs.append(gbox("Roof", (7.6, 0.5, 8.5), (0, 4.35, 33.75), stones[0], col))
            obs.append(gbox("Beams", (6.0, 0.25, 8.2), (0, 3.98, 33.75), beam_m, col))
            obs.append(gbox("Lintel", (6.8, 0.5, 0.5), (0, 4.45, Z0 + 0.05), gold, col))
            return obs
        rnd = random.Random(131)
        obs = []
        for s in (-1, 1):
            obs.append(gbox("Core", (0.74, 4.1, L), (s * 3.4, 2.05, ZM), mortar, col))
            for n in (-1, 1):
                block_face(obs, col, stones, rnd, (s * 3.4 + n * 0.4, 2.15, ZM), (0, 0, 1), (n, 0, 0), L, 3.7,
                           course=0.5, block=(0.7, 1.3), depth=0.07)
            obs.append(gbox("Plinth", (0.96, 0.35, L), (s * 3.4, 0.175, ZM), stones[2], col, bevel=0.04))
            obs.append(gbox("Coping", (1.0, 0.2, L), (s * 3.4, 4.3, ZM), stones[1], col, bevel=0.04))
            obs.append(gbox("End", (0.84, 4.2, 0.06), (s * 3.4, 2.1, Z1 + 0.0), stones[1], col, bevel=0.02))
            # the gold frame round the floor end
            obs.append(gbox("Frame", (0.5, 4.2, 0.5), (s * 3.15, 2.1, Z0 + 0.05), gold, col, bevel=0.05))
            obs.append(gbox("Frame Flute", (0.08, 3.6, 0.52), (s * 3.15, 2.1, Z0 + 0.05), K.mat("Flute", GOLD_DARK,
                                                                                               rough=0.35, metal=0.8),
                            col))
            # glowing lamps along the inside of each wall
            for z in (28.0, 32.0, 36.0):
                x = s * 2.98
                obs.append(gbox("Sconce", (0.08, 0.36, 0.26), (x, 2.7, z), gold, col, bevel=0.02))
                obs.append(K.sphere("Lamp", 0.14, at=at(x - s * 0.1, 2.85, z), m=lamp, seg=12, col=col))
                obs.append(grod("Lamp Cap", (x - s * 0.1, 3.0, z), (x - s * 0.1, 3.06, z), 0.12, gold, col, seg=12))
        obs.append(gbox("Lintel", (6.8, 0.5, 0.5), (0, 4.45, Z0 + 0.05), gold, col, bevel=0.05))
        obs.append(gstar("Lintel Star", 0.34, 0.08, (0, 4.45, Z0 - 0.22), "-z", gold, col))
        # the roof: a slab of blocks on top, beams across underneath
        obs.append(gbox("Roof", (7.6, 0.44, 8.5), (0, 4.38, 33.75), stones[0], col, bevel=0.04))
        for k in range(12):
            x = -3.8 + 7.6 * (k + 0.5) / 12
            obs.append(gbox("Roof Block", (7.6 / 12 - 0.04, 0.06, 8.4), (x, 4.62, 33.75), rnd.choice(stones), col,
                            bevel=0.015))
        z = 29.9
        while z < 37.7:
            obs.append(gbox("Beam", (6.0, 0.25, 0.28), (0, 3.98, z), beam_m, col, bevel=0.03))
            z += 1.2
        for s in (-1, 1):
            obs.append(gbox("Joist", (0.22, 0.2, 8.3), (s * 2.7, 3.98, 33.75), beam_m, col, bevel=0.03))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ Blip's podium
def blip_podium():
    gold = gold_mat("Podium Gold")
    dark = K.mat("Podium Dark", GOLD_DARK, rough=0.35, metal=0.85)

    def build(col, high):
        if not high:
            return [glathe("Podium", [(0, 0), (0.95, 0), (0.95, 0.1), (0.8, 0.52), (0.86, 0.6), (0, 0.6)], gold, col,
                           seg=24)]
        obs = [glathe("Podium", [(0, 0), (0.95, 0), (0.95, 0.06), (0.9, 0.1), (0.88, 0.14), (0.8, 0.5), (0.86, 0.53),
                                 (0.86, 0.58), (0.8, 0.6), (0, 0.6)], gold, col, seg=96, flutes=20,
                      flute_depth=0.03, flute_z=(0.16, 0.48))]
        obs.append(glathe("Band", [(0.84, 0.3), (0.88, 0.31), (0.88, 0.35), (0.84, 0.36)], dark, col, seg=96))
        obs.append(gstar("Front Star", 0.14, 0.04, (0, 0.33, 0.86), "+z", gold, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Round Board
def round_board():
    face = mottled("Board Face", BOARD, (0.12, 0.07, 0.22), scale=6.0, rough=0.65, bump=0.05)
    gold = gold_mat("Board Gold")
    frame = mottled("Board Frame", (0.42, 0.3, 0.55), (0.32, 0.22, 0.42), scale=6.0, rough=0.6, grain=(14.0, 0.25))
    steel = steel_mat("Board Steel")

    def build(col, high):
        if not high:
            obs = [gbox("Board", (3.6, 2.6, 0.2), (0, 2.4, 0), face, col)]
            for s in (-1, 1):
                obs.append(gbox("Side", (0.2, 2.9, 0.3), (s * 1.9, 2.4, 0), frame, col))
                obs.append(gbox("Post", (0.24, 1.2, 0.24), (s * 1.6, 0.6, 0), steel, col))
            obs.append(gbox("Top", (4.0, 0.2, 0.3), (0, 3.8, 0), frame, col))
            obs.append(gbox("Bottom", (4.0, 0.16, 0.3), (0, 1.03, 0), frame, col))
            obs.append(gbox("Crest", (1.0, 0.6, 0.12), (0, 4.15, 0), gold, col))
            return obs
        obs = [gbox("Board", (3.6, 2.6, 0.2), (0, 2.4, 0), face, col)]
        for s in (-1, 1):
            obs.append(gbox("Side", (0.2, 2.9, 0.3), (s * 1.9, 2.4, 0), frame, col, bevel=0.03))
            obs.append(gbox("Side Gold", (0.04, 2.7, 0.32), (s * 1.81, 2.4, 0), gold, col, bevel=0.01))
            obs.append(gbox("Post", (0.22, 1.1, 0.22), (s * 1.6, 0.55, 0), steel, col, bevel=0.03))
            obs.append(gbox("Foot", (0.44, 0.1, 0.5), (s * 1.6, 0.05, 0), steel, col, bevel=0.02))
            obs.append(K.sphere("Knob", 0.1, at=at(s * 1.9, 3.95, 0), m=gold, seg=12, col=col))
            for z in (-0.16, 0.16):
                for y in (1.4, 2.4, 3.4):
                    obs.append(K.sphere("Stud", 0.025, at=at(s * 1.9, y, z), m=gold, seg=8, col=col))
        obs.append(gbox("Top", (4.0, 0.2, 0.3), (0, 3.8, 0), frame, col, bevel=0.03))
        obs.append(gbox("Top Gold", (3.7, 0.04, 0.32), (0, 3.71, 0), gold, col, bevel=0.01))
        obs.append(gbox("Bottom", (4.0, 0.16, 0.3), (0, 1.03, 0), frame, col, bevel=0.03))
        # the crest: a gold scroll with a star
        crest = [(-0.5 + k / 10, 3.9 + 0.22 * math.sin(math.pi * k / 10), 0) for k in range(11)]
        obs.append(gwire("Crest", crest, 0.05, gold, col, res=8, bevel_res=2))
        obs.append(gstar("Crest Star", 0.26, 0.1, (0, 4.18, 0), "-z", gold, col))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "arena_wall": (arena_wall, 1024, 0.06, 0.15, True, False),
    "stand_step": (stand_step, 1024, 0.06, 0.15, True, False),
    "spotlight_tower": (spotlight_tower, 2048, 0.08, 0.2, True, True),
    "arena_hatch": (arena_hatch, 512, 0.03, 0.06, True, False),
    "arena_tunnel": (arena_tunnel, 2048, 0.08, 0.2, True, True),
    "blip_podium": (blip_podium, 512, 0.03, 0.06, True, False),
    "round_board": (round_board, 1024, 0.05, 0.12, True, False),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

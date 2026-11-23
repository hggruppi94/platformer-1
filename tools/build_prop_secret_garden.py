# The Secret Garden (scripts/secret_garden.gd), built the detailed way (tools/bake_kit.py; 23 Nov 2026, Hayden: "Great,
# lets keep going", the next place not baked yet): its ivy-covered brick walls, the Rose Walk's arches, the fountain,
# the Hedge Maze's hedges and sundial, the Lily Pond's summerhouse, the Giant Flowers, the Great Tree and the benches.
# Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Every piece is made in the space of the plain pieces it replaces, so scripts/detail_props.gd dress_secret_garden puts
# each one where the old ones were and every collision stays the game's. Blender's X is Godot's X, Blender's -Y is
# Godot's +Z and Blender's Z is Godot's Y.
#   ivy_wall      a 4 m length of the garden's old brick wall (1 m thick, 5 m high, from the ground), coping stones on
#                 top and ivy thick over its inside face (+z); the game lays as many as fit along each wall.
#   rose_arch     a Rose Walk arch from the ground (posts 1.9 m either side, its curve round 3.2 m up), climbing roses
#                 and their leaves all over it, in the old roses' pink, cream and red.
#   fountain      the fountain's basin, column and bowl, in the Fountain Lawn's space (its water, spray and wren stay).
#   hedge         a maze hedge, 5.1 x 2.8 x 0.9 (centred): clipped leaves over a woody core; turned for the other way.
#   sundial       the maze's sundial from the ground: a carved pedestal and a brass dial with its hours and gnomon.
#   summerhouse   the island's summerhouse, in the Lily Pond's space: six columns, a ring beam with brackets and a
#                 ribbed dome with a finial.
#   flower_head   a giant flower's petals (radius 2 at its top, its top at 0): two rings of veined petals, baked pale
#                 so each flower keeps its own colour.
#   flower_middle its middle (radius 0.9): a dome of little florets, gold.
#   flower_stem   a giant flower's stem, 4 m (centred), radius 0.45 at the foot and 0.35 at the top, ridged; the game
#                 stretches it to each flower's height.
#   great_tree    the Great Tree's trunk, roots and the branch the swing hangs from, in the Great Tree's space (its leaves
#                 are the baked leaf balls, tools/build_prop_nature.py).
#   garden_bench  a bench, 2.0 x 0.45 x 0.6 (centred): carved stone ends and wooden slats.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_secret_garden.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["ivy_wall", "rose_arch", "fountain", "hedge", "sundial", "summerhouse", "flower_head", "flower_middle",
         "flower_stem", "great_tree", "garden_bench"]
KIND = next((a for a in sys.argv if a in KINDS), "ivy_wall")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

BRICK = (0.62, 0.44, 0.52)
BRICK_DARK = (0.5, 0.34, 0.42)
BRICK_PALE = (0.72, 0.55, 0.6)
MORTAR = (0.78, 0.74, 0.74)
COPING = (0.8, 0.74, 0.78)
IVY = (0.18, 0.46, 0.2)
IVY_LIGHT = (0.3, 0.58, 0.24)
IVY_DARK = (0.12, 0.34, 0.16)
HEDGE = (0.16, 0.42, 0.22)
HEDGE_LIGHT = (0.24, 0.52, 0.26)
TWIG = (0.32, 0.24, 0.2)
IRON = (0.3, 0.26, 0.34)
ROSE_PINK = (1.0, 0.5, 0.7)
ROSE_CREAM = (1.0, 0.92, 0.8)
ROSE_RED = (0.92, 0.25, 0.4)
LEAF = (0.2, 0.5, 0.25)
STONE = (0.78, 0.74, 0.8)
STONE_DARK = (0.64, 0.6, 0.68)
MOSS = (0.36, 0.52, 0.3)
BRASS = (0.85, 0.68, 0.35)
WHITE = (0.95, 0.92, 0.96)
ROOF = (0.7, 0.85, 0.75)
ROOF_DARK = (0.55, 0.72, 0.62)
PALE = (0.93, 0.92, 0.94)
GOLD_MID = (1.0, 0.85, 0.3)
GOLD_DEEP = (0.92, 0.58, 0.18)
STEM = (0.3, 0.62, 0.3)
STEM_DARK = (0.22, 0.48, 0.24)
BARK = (0.36, 0.26, 0.3)
BARK_DARK = (0.24, 0.17, 0.2)
WOOD = (0.55, 0.38, 0.32)
WOOD_DARK = (0.42, 0.28, 0.24)

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




def leaves(name, spots, m, col, l=0.13, w=0.09, lift=0.6):
    """Little leaves, one mesh: spots are (Godot position, Godot outward normal, size, rnd). Each leaf is a cupped
    diamond growing out of its spot, tipped out from the surface by `lift` and turned at random about the normal."""
    bm = bmesh.new()
    for p, n, s, rnd in spots:
        P = Vector(at(*p))
        N = Vector(at(*n)).normalized()
        ref = Vector((0, 0, 1)) if abs(N.z) < 0.9 else Vector((1, 0, 0))
        t = N.cross(ref).normalized()
        b = N.cross(t)
        a = rnd.uniform(0, math.tau)
        d = (t * math.cos(a) + b * math.sin(a) + N * lift).normalized()
        side = N.cross(d).normalized()
        L, W = l * s, w * s
        v0 = bm.verts.new(P)
        v1 = bm.verts.new(P + d * L * 0.45 + side * W * 0.5 - N * W * 0.08)
        v2 = bm.verts.new(P + d * L + N * W * 0.1)
        v3 = bm.verts.new(P + d * L * 0.45 - side * W * 0.5 - N * W * 0.08)
        mid = bm.verts.new(P + d * L * 0.5 + N * W * 0.06)
        for f in ((v0, v1, mid), (v1, v2, mid), (v2, v3, mid), (v3, v0, mid)):
            bm.faces.new(f)
    return K._obj(name, bm, m, True, col)


def leaf_mats(prefix, base, light, dark):
    return [mottled(prefix, base, dark, scale=9.0, rough=0.7, bump=0.1),
            mottled(prefix + " Light", light, base, scale=9.0, rough=0.65, bump=0.1),
            mottled(prefix + " Dark", dark, base, scale=9.0, rough=0.75, bump=0.1)]


def leaf_spread(obs, col, mats, rnd, spots_fn, **kw):
    """Splits leaf spots over a few greens, one mesh each."""
    groups = [[] for _ in mats]
    for spot in spots_fn():
        groups[rnd.randrange(len(mats))].append(spot)
    for m, g in zip(mats, groups):
        if g:
            obs.append(leaves("Leaves", g, m, col, **kw))


def flat_spots(rnd, centre, u, v, n, wu, wv, step, size=(0.8, 1.3), out=(0.0, 0.06), jitter=0.5):
    """Leaf spots over a flat face: centre (Godot), u and v its across directions, n its normal, wu x wv in size."""
    centre, u, v, n = Vector(centre), Vector(u), Vector(v), Vector(n)
    nu, nv = max(1, int(wu / step)), max(1, int(wv / step))
    for i in range(nu):
        for j in range(nv):
            x = -wu / 2 + (i + 0.5 + rnd.uniform(-jitter, jitter)) * wu / nu
            y = -wv / 2 + (j + 0.5 + rnd.uniform(-jitter, jitter)) * wv / nv
            x = max(-wu / 2, min(wu / 2, x))
            y = max(-wv / 2, min(wv / 2, y))
            p = centre + u * x + v * y + n * rnd.uniform(*out)
            nn = (n + u * rnd.uniform(-0.3, 0.3) + v * rnd.uniform(-0.3, 0.3)).normalized()
            yield (tuple(p), tuple(nn), rnd.uniform(*size), rnd)


# ================================================================ ivy wall
def ivy_wall():
    bricks = [mottled("Old Brick", BRICK, BRICK_DARK, scale=8.0, rough=0.9, bump=0.4),
              mottled("Old Brick Pale", BRICK_PALE, BRICK, scale=8.0, rough=0.9, bump=0.4),
              mottled("Old Brick Dark", BRICK_DARK, (0.42, 0.3, 0.36), scale=8.0, rough=0.92, bump=0.4)]
    mortar = mottled("Mortar", MORTAR, (0.66, 0.62, 0.62), scale=12.0, rough=0.95, bump=0.3)
    coping = mottled("Coping Stone", COPING, STONE_DARK, scale=5.0, rough=0.8, bump=0.3, third=MOSS)
    ivys = leaf_mats("Ivy", IVY, IVY_LIGHT, IVY_DARK)
    stem = K.mat("Ivy Stem", (0.38, 0.3, 0.26), rough=0.8)
    L, H, T = 4.0, 5.0, 1.0

    def build(col, high):
        if not high:
            return [gbox("Wall", (L, H, T), (0, H / 2, 0), bricks[0], col),
                    gbox("Coping", (L, 0.25, 1.4), (0, H + 0.1, 0), coping, col),
                    gbox("Ivy", (L, 4.6, 0.34), (0, 2.65, T / 2 + 0.17), ivys[0], col)]
        rnd = random.Random(101)
        obs = [gbox("Core", (L, H - 0.02, T - 0.04), (0, H / 2, 0), mortar, col)]
        course, bl = 0.15, 0.42
        rows = int(H / course)
        for s in (-1, 1):
            for r in range(rows):
                y = course * (r + 0.5)
                if s > 0 and 0.55 < y < 4.85 and rnd.random() < 0.85:
                    continue                                    # (the ivy hides most of the inside face)
                x = -L / 2 - (bl / 2 if r % 2 else 0.0)
                while x < L / 2:
                    x0, x1 = max(x, -L / 2), min(x + bl, L / 2)
                    if x1 - x0 > 0.06:
                        obs.append(gbox("Brick", (x1 - x0 - 0.02, course - 0.02, 0.06),
                                        ((x0 + x1) / 2, y, s * (T / 2 - 0.02)), rnd.choice(bricks), col,
                                        bevel=0.008 if s < 0 else 0.0))
                    x += bl
        for k in range(8):                                      # coping stones
            x = -L / 2 + L * (k + 0.5) / 8
            obs.append(gbox("Coping", (L / 8 - 0.02, 0.24, 1.4), (x, H + 0.1, 0), coping, col, bevel=0.03))
        # ivy: woody stems climbing the face, and leaves thick over them
        for k in range(7):
            x = -L / 2 + L * (k + 0.5) / 7 + rnd.uniform(-0.2, 0.2)
            pts = []
            for j in range(9):
                y = 0.1 + 4.7 * j / 8
                pts.append((max(-1.95, min(1.95, x + 0.25 * math.sin(j * 1.3 + k))), y, T / 2 + 0.05))
            obs.append(gwire("Stem", pts, 0.025, stem, col, res=4, bevel_res=2))

        def spots():
            for layer, out in ((0, (0.02, 0.08)), (1, (0.1, 0.18)), (2, (0.18, 0.26))):
                for p in flat_spots(rnd, (0, 2.6 + (0.15 if layer else 0.0), T / 2), (1, 0, 0), (0, 1, 0), (0, 0, 1),
                                    L - 0.12, 4.4 - layer * 0.5, 0.11 + layer * 0.03, size=(0.9, 1.5), out=out):
                    yield p
            for p in flat_spots(rnd, (0, H + 0.24, 0.2), (1, 0, 0), (0, 0, 1), (0, 1, 0), L - 0.1, 0.6, 0.12,
                                size=(0.8, 1.3), out=(0.0, 0.05)):
                if rnd.random() < 0.6:
                    yield p                                     # a little ivy spilling over the top
        leaf_spread(obs, col, ivys, rnd, spots, l=0.16, w=0.13, lift=0.5)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ rose arch
def arch_pt(a, r=1.9, z=0.0):
    return (math.cos(a) * r, 3.2 + math.sin(a) * r, z)


def rose_arch():
    iron = mottled("Old Iron", IRON, (0.2, 0.17, 0.24), scale=6.0, rough=0.5, metal=0.6, bump=0.15)
    vine = K.mat("Rose Vine", (0.3, 0.36, 0.22), rough=0.8)
    leafs = leaf_mats("Rose Leaf", LEAF, (0.28, 0.58, 0.3), (0.14, 0.38, 0.18))
    roses = [glowing(mottled("Rose Pink", ROSE_PINK, (0.9, 0.38, 0.58), scale=14.0, rough=0.55), ROSE_PINK, 0.15),
             glowing(mottled("Rose Cream", ROSE_CREAM, (0.95, 0.84, 0.7), scale=14.0, rough=0.55), ROSE_CREAM, 0.1),
             glowing(mottled("Rose Red", ROSE_RED, (0.75, 0.15, 0.3), scale=14.0, rough=0.55), ROSE_RED, 0.12)]

    def rose(obs, col, m, p, s, rnd):
        """A rose: rings of cupped petals round a tight bud."""
        p = Vector(p)
        obs.append(blob("Bud", 0.05 * s, tuple(p + Vector((0, 0.02 * s, 0))), m, col, seed=rnd.randrange(99), seg=8,
                        lump=0.2))
        for ring, (n_p, rr, size) in enumerate(((5, 0.05, 0.07), (7, 0.09, 0.085), (9, 0.13, 0.09))):
            off = rnd.uniform(0, math.tau)
            for k in range(n_p):
                a = off + k * math.tau / n_p
                q = Vector((math.cos(a), 0, math.sin(a)))
                obs.append(blob("Petal", size * s, tuple(p + q * rr * s + Vector((0, -0.02 * ring * s, 0))), m, col,
                                seed=rnd.randrange(999), seg=8, lump=0.15, squash=(1.0, 0.45, 0.7)))

    def build(col, high):
        if not high:
            obs = [glathe("Post", [(0, 0), (0.2, 0), (0.2, 3.25), (0, 3.25)], vine, col, seg=8, pos=(s * 1.9, 0, 0))
                   for s in (-1, 1)]
            obs.append(gwire("Arch", [arch_pt(math.pi * k / 12) for k in range(13)], 0.44, leafs[0], col, res=4,
                             bevel_res=3))
            return obs
        rnd = random.Random(202)
        obs = []
        for s in (-1, 1):                                       # posts with a foot, a collar and a finial
            obs.append(grod("Post", (s * 1.9, 0, 0), (s * 1.9, 3.2, 0), 0.07, iron, col, seg=12))
            obs.append(glathe("Foot", [(0, 0), (0.14, 0), (0.14, 0.06), (0.09, 0.12), (0.07, 0.2), (0, 0.2)], iron,
                              col, seg=16, pos=(s * 1.9, 0, 0)))
            obs.append(glathe("Collar", [(0.06, -0.04), (0.1, 0), (0.06, 0.04)], iron, col, seg=16,
                              pos=(s * 1.9, 2.4, 0)))
            for k in range(3):                                  # little scrolls between post and arch
                y = 2.5 + k * 0.05
                pts = K.scroll(0.0, 0.0, 0.18, 1.2, steps=18)
                obs.append(gwire("Scroll", [(s * (1.9 - 0.05 - p[0] * 0.8 - 0.15), y + p[2] * 0.8 + 0.2, 0.0)
                                            for p in pts], 0.015, iron, col, res=3, bevel_res=2))
                break
        obs.append(gwire("Arch", [arch_pt(math.pi * k / 24) for k in range(25)], 0.07, iron, col, res=8,
                         bevel_res=3))
        obs.append(gwire("Arch Inner", [arch_pt(math.pi * k / 24, 1.72) for k in range(25)], 0.03, iron, col,
                         res=8, bevel_res=2))
        for k in range(11):                                     # rungs between the two curves
            a = math.pi * (k + 0.5) / 11
            obs.append(grod("Rung", arch_pt(a, 1.72), arch_pt(a, 1.9), 0.018, iron, col, seg=6))
        # the climbing rose: vines spiralling up both posts and over the top
        for s in (-1, 1):
            for v in range(2):
                pts = []
                for j in range(14):
                    y = 0.05 + 3.1 * j / 13
                    a = j * 1.1 + v * math.pi
                    pts.append((s * 1.9 + math.cos(a) * 0.1, y, math.sin(a) * 0.1))
                obs.append(gwire("Vine", pts, 0.02, vine, col, res=4, bevel_res=2))
        for v in range(3):
            pts = [arch_pt(math.pi * j / 20, 1.9 + 0.12 * math.sin(j * 1.4 + v * 2.1),
                           0.12 * math.cos(j * 1.4 + v * 2.1)) for j in range(21)]
            obs.append(gwire("Vine", pts, 0.02, vine, col, res=4, bevel_res=2))

        def spots():
            for j in range(260):                                # leaves all over the curve, thick on top
                a = rnd.uniform(-0.05, math.pi + 0.05)
                ring = rnd.uniform(0.02, 0.3)
                tw = rnd.uniform(0, math.tau)
                rr = 1.81 + math.cos(tw) * ring
                p = Vector(arch_pt(a, rr, math.sin(tw) * ring))
                n = (p - Vector(arch_pt(a, 1.81))).normalized()
                yield (tuple(p), tuple(n), rnd.uniform(0.9, 1.4), rnd)
            for s in (-1, 1):                                   # and up the posts
                for j in range(60):
                    y = rnd.uniform(0.2, 3.1)
                    a = rnd.uniform(0, math.tau)
                    n = Vector((math.cos(a), 0, math.sin(a)))
                    yield (tuple(Vector((s * 1.9, y, 0)) + n * 0.11), tuple(n), rnd.uniform(0.8, 1.2), rnd)
        leaf_spread(obs, col, leafs, rnd, spots, l=0.14, w=0.09, lift=0.5)
        for j in range(22):                                     # roses, most on the curve
            a = math.pi * (j + rnd.uniform(0.1, 0.9)) / 22
            tw = rnd.uniform(0, math.tau)
            p = Vector(arch_pt(a, 1.81 + math.cos(tw) * 0.2, math.sin(tw) * 0.2))
            rose(obs, col, roses[j % 3], tuple(p), rnd.uniform(1.0, 1.5), rnd)
        for s in (-1, 1):
            for j in range(4):
                a = rnd.uniform(0, math.tau)
                rose(obs, col, roses[(j + 1) % 3], (s * 1.9 + math.cos(a) * 0.14, rnd.uniform(1.2, 3.0),
                                                     math.sin(a) * 0.14), 1.0, rnd)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ fountain
def fountain():
    stone = mottled("Garden Stone", STONE, STONE_DARK, scale=4.0, rough=0.8, bump=0.35, third=MOSS)
    pale = mottled("Garden Stone Pale", (0.86, 0.82, 0.88), STONE, scale=5.0, rough=0.75, bump=0.3)
    water = K.mat("Basin Water", (0.4, 0.68, 0.85), rough=0.1)
    basin = [(0, 0.0), (4.3, 0.0), (4.3, 0.12), (4.2, 0.18), (4.12, 0.7), (4.22, 0.74), (4.22, 0.86), (3.95, 0.9),
             (3.78, 0.86), (3.76, 0.72), (0, 0.72)]
    column = [(0, 0.7), (0.9, 0.7), (0.9, 0.85), (0.78, 0.95), (0.7, 1.1), (0.62, 2.2), (0.56, 2.45), (0.7, 2.6),
              (0.7, 2.72), (0, 2.72)]
    bowl = [(0.55, 2.7), (0.9, 2.78), (1.4, 2.95), (1.7, 3.15), (1.74, 3.27), (1.6, 3.3), (1.25, 3.16), (0.5, 3.12),
            (0.3, 3.18), (0.3, 3.3), (0, 3.3)]

    def build(col, high):
        if not high:
            return [glathe("Basin", basin, stone, col, seg=32), glathe("Column", column, pale, col, seg=16),
                    glathe("Bowl", bowl, pale, col, seg=24)]
        rnd = random.Random(303)
        obs = [glathe("Basin", basin, stone, col, seg=128), glathe("Bowl", bowl, pale, col, seg=96),
               K.lathe("Column", column[:5] + [(0.7 - 0.08 * k / 10, 1.1 + 1.1 * k / 10) for k in range(1, 10)]
                       + column[5:], seg=96, m=pale, col=col, flutes=16, flute_depth=0.05, flute_z=(1.15, 2.15))]
        obs.append(glathe("Water", [(0, 0.71), (3.77, 0.71), (3.77, 0.72), (0, 0.72)], water, col, seg=64))
        for k in range(24):                                     # carved panels round the basin, with a rosette each
            a = k * math.tau / 24
            q = Vector((math.cos(a), 0, math.sin(a)))
            obs.append(gbox("Pilaster", (0.16, 0.5, 0.06), tuple(q * 4.16 + Vector((0, 0.44, 0))), stone, col,
                            bevel=0.015, rot=(0, -a + math.pi / 2, 0)))
            a2 = a + math.pi / 24
            q2 = Vector((math.cos(a2), 0, math.sin(a2)))
            obs.append(blob("Rosette", 0.07, tuple(q2 * 4.15 + Vector((0, 0.44, 0))), pale, col, seed=k, seg=10,
                            lump=0.3, squash=(1, 1, 0.4)))
        for k in range(8):                                      # shells round the bowl's lip
            a = k * math.tau / 8
            q = Vector((math.cos(a), 0, math.sin(a)))
            for f in range(5):
                fa = (f - 2) * 0.35
                d = (q * math.cos(fa) + Vector((-q.z, 0, q.x)) * math.sin(fa) * 0.6).normalized()
                obs.append(grod("Shell Rib", tuple(q * 1.62 + Vector((0, 3.0, 0))), tuple(q * 1.62 + d * 0.28 +
                                Vector((0, 3.22, 0))), 0.035, pale, col, seg=6, r2=0.06))
        for k in range(30):                                     # moss tucked round the basin's foot
            a = rnd.uniform(0, math.tau)
            q = Vector((math.cos(a), 0, math.sin(a)))
            obs.append(blob("Moss", rnd.uniform(0.12, 0.25), tuple(q * 4.28 + Vector((0, 0.04, 0))),
                            K.mat("Moss", MOSS, rough=0.95, bump=0.3), col, seed=k, seg=8, lump=0.4,
                            squash=(1.3, 0.35, 1.0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ hedge
def hedge():
    hedges = leaf_mats("Hedge", HEDGE, HEDGE_LIGHT, (0.1, 0.32, 0.16))
    core = K.mat("Hedge Inside", (0.08, 0.22, 0.1), rough=0.95)
    X, Y, Z = 5.1, 2.8, 0.9

    def build(col, high):
        if not high:
            return [gbox("Hedge", (X + 0.1, Y + 0.06, Z + 0.12), (0, 0.03, 0), hedges[0], col)]
        rnd = random.Random(404)
        obs = [gbox("Core", (X - 0.04, Y - 0.04, Z - 0.06), (0, 0, 0), core, col)]

        def spots():
            for out in ((0.0, 0.03), (0.03, 0.06)):
                for s in (-1, 1):
                    yield from flat_spots(rnd, (0, 0, s * Z / 2), (1, 0, 0), (0, 1, 0), (0, 0, s), X, Y - 0.02, 0.085,
                                          out=out)
                    yield from flat_spots(rnd, (s * X / 2, 0, 0), (0, 0, 1), (0, 1, 0), (s, 0, 0), Z, Y - 0.02,
                                          0.085, out=out)
                yield from flat_spots(rnd, (0, Y / 2, 0), (1, 0, 0), (0, 0, 1), (0, 1, 0), X, Z, 0.085, out=out)
        leaf_spread(obs, col, hedges, rnd, spots, l=0.1, w=0.07, lift=0.35)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ sundial
def sundial():
    stone = mottled("Garden Stone", STONE, STONE_DARK, scale=5.0, rough=0.8, bump=0.35, third=MOSS)
    brass = mottled("Old Brass", BRASS, (0.6, 0.46, 0.22), scale=7.0, rough=0.35, metal=0.85, bump=0.08)
    verd = mottled("Verdigris", (0.45, 0.7, 0.6), BRASS, scale=9.0, rough=0.6, metal=0.3, lo=0.5, hi=0.75)
    prof = [(0, 0), (0.55, 0), (0.55, 0.1), (0.48, 0.14), (0.45, 0.22), (0.32, 0.3), (0.26, 0.45), (0.3, 0.6),
            (0.24, 0.75), (0.3, 0.85), (0.42, 0.92), (0.42, 1.0), (0, 1.0)]

    def build(col, high):
        if not high:
            return [glathe("Pedestal", prof, stone, col, seg=16),
                    glathe("Dial", [(0, 1.0), (0.62, 1.0), (0.62, 1.09), (0, 1.09)], brass, col, seg=24),
                    gbox("Gnomon", (0.05, 0.32, 0.5), (0, 1.22, 0.1), brass, col)]
        obs = [glathe("Pedestal", prof, stone, col, seg=96)]
        obs.append(glathe("Dial", [(0, 1.0), (0.62, 1.0), (0.62, 1.07), (0.58, 1.085), (0, 1.085)], verd, col,
                          seg=96))
        obs.append(glathe("Ring", [(0.5, 1.084), (0.52, 1.095), (0.54, 1.084)], brass, col, seg=96))
        for k in range(12):                                     # the hours
            a = k * math.tau / 12
            q = Vector((math.cos(a), 0, math.sin(a)))
            obs.append(gbox("Hour", (0.09, 0.012, 0.02), tuple(q * 0.44 + Vector((0, 1.09, 0))), brass, col,
                            rot=(0, -a, 0)))
            obs.append(K.sphere("Pip", 0.012, at=at(*(q * 0.33 + Vector((0, 1.088, 0)))), m=brass, seg=6, col=col))
        bm = bmesh.new()                                        # the gnomon: a thin brass wedge
        pts = [at(0, 1.085, -0.15), at(0, 1.085, 0.35), at(0, 1.36, -0.15)]
        for dx in (-0.018, 0.018):
            pass
        vs = [bm.verts.new(Vector(p) + Vector((dx, 0, 0))) for dx in (-0.018, 0.018) for p in pts]
        bm.faces.new((vs[0], vs[1], vs[2]))
        bm.faces.new((vs[5], vs[4], vs[3]))
        for i in range(3):
            j = (i + 1) % 3
            bm.faces.new((vs[i], vs[i + 3], vs[j + 3], vs[j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obs.append(K._obj("Gnomon", bm, brass, False, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ summerhouse
def summerhouse():
    white = mottled("Summerhouse", WHITE, (0.84, 0.8, 0.86), scale=6.0, rough=0.5, bump=0.12)
    roof = mottled("Summerhouse Roof", ROOF, ROOF_DARK, scale=5.0, rough=0.5, bump=0.15, third=MOSS)
    trim = mottled("Summerhouse Trim", (0.86, 0.72, 0.4), BRASS, scale=8.0, rough=0.4, metal=0.5)
    dome = [(3.0 * math.cos(t), 2.6 + 3.0 * math.sin(t)) for t in [math.pi / 2 * k / 16 for k in range(17)]]
    dome[-1] = (0.0, 5.6)

    def build(col, high):
        posts = [(math.cos(math.tau * k / 6) * 2.6, math.sin(math.tau * k / 6) * 2.6) for k in range(6)]
        if not high:
            obs = [glathe("Post", [(0, 0), (0.15, 0), (0.15, 2.62), (0, 2.62)], white, col, seg=8, pos=(x, 0, z))
                   for x, z in posts]
            obs.append(glathe("Dome", [(3.06, 2.5)] + [(r * 1.02, y) for r, y in dome] + [(0, 6.05)], roof, col,
                              seg=24))
            return obs
        rnd = random.Random(505)
        obs = []
        col_prof = [(0, 0), (0.17, 0), (0.17, 0.08), (0.13, 0.12), (0.1, 0.2)] + \
                   [(0.1 - 0.015 * k / 8, 0.2 + 2.1 * k / 8) for k in range(1, 9)] + \
                   [(0.13, 2.36), (0.12, 2.42), (0.16, 2.5), (0.16, 2.6), (0, 2.6)]
        for x, z in posts:
            ob = K.lathe("Column", col_prof, seg=48, m=white, col=col, flutes=8, flute_depth=0.018,
                         flute_z=(0.25, 2.3))
            ob.location = at(x, 0, z)
            obs.append(ob)
            for s in (-1, 1):                                   # a curled bracket each side up under the beam
                a = math.atan2(z, x) + s * 0.32
                tip = (math.cos(a) * 2.6, 2.55, math.sin(a) * 2.6)
                pts = [(x * (1 - t) + tip[0] * t, 2.1 + 0.45 * math.sin(t * math.pi / 2), z * (1 - t) + tip[2] * t)
                       for t in [k / 8 for k in range(9)]]
                obs.append(gwire("Bracket", pts, 0.025, white, col, res=4, bevel_res=2))
        obs.append(glathe("Ring Beam", [(2.45, 2.5), (2.85, 2.5), (2.92, 2.56), (2.92, 2.68), (2.45, 2.68)], white,
                          col, seg=96))
        obs.append(K.lathe("Dome", dome, seg=128, m=roof, col=col, flutes=16, flute_depth=0.05, flute_z=(2.7, 5.2)))
        for k in range(16):                                     # gilded ribs up the dome
            a = math.tau * (k + 0.5) / 16
            pts = [(math.cos(a) * r * 1.008, y, math.sin(a) * r * 1.008) for r, y in dome[:15]]
            obs.append(gwire("Rib", pts, 0.035, trim, col, res=3, bevel_res=2))
        obs.append(glathe("Drip Edge", [(2.98, 2.58), (3.06, 2.62), (3.04, 2.7), (2.98, 2.72)], trim, col, seg=96))
        obs.append(glathe("Finial", [(0, 5.55), (0.22, 5.58), (0.12, 5.7), (0.16, 5.82), (0.06, 5.95), (0.03, 6.05),
                                     (0, 6.05)], trim, col, seg=24))
        for k in range(40):                                     # moss on the dome's lower curve
            a = rnd.uniform(0, math.tau)
            t = rnd.uniform(0.05, 0.5)
            r, y = 3.0 * math.cos(t), 2.6 + 3.0 * math.sin(t)
            obs.append(blob("Moss", rnd.uniform(0.08, 0.18), (math.cos(a) * r, y, math.sin(a) * r),
                            K.mat("Roof Moss", MOSS, rough=0.95, bump=0.3), col, seed=k, seg=8, lump=0.4,
                            squash=(1.2, 0.4, 1.2)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ giant flower
def petal(name, a, dist, y, length, width, thick, tilt, m, col, seg, veins):
    """A cupped petal pointing out along angle a: its base `dist` from the middle, at height y."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg // 2), radius=1.0)
    for v in bm.verts:
        x, w, h = v.co.x, v.co.y, v.co.z                       # x along the petal, w across, h thickness
        cup = 0.35 * w * w                                       # edges curl up a little
        ridge = 0.0
        if veins and h > 0:
            ridge = -0.12 * abs(math.sin(math.atan2(w, x + 1.2) * 9)) * (1 - x * x)
        v.co = Vector(((x + 1) * length / 2, w * width / 2 * (0.55 + 0.45 * (1 - ((x - 0.2) * 0.8) ** 2)),
                       (h + ridge) * thick / 2 + cup * thick * 2))
    ob = K._obj(name, bm, m, True, col)
    ob.rotation_mode = "XYZ"
    ob.rotation_euler = (0, -tilt, -a)                         # tip up, then round (Blender's z is up)
    ob.location = at(math.cos(a) * dist, y, math.sin(a) * dist)
    return ob


def flower_head():
    pale = mottled("Giant Petal", PALE, (0.84, 0.82, 0.86), scale=7.0, rough=0.55, bump=0.1)
    disc = mottled("Flower Face", PALE, (0.8, 0.78, 0.82), scale=9.0, rough=0.6, bump=0.2)

    def build(col, high):
        rnd = random.Random(606)
        seg = 32 if high else 10
        obs = [glathe("Face", [(0, -0.3), (1.4, -0.3), (1.8, -0.18), (2.0, -0.05), (2.0, 0.0), (0, 0.0)], disc, col,
                      seg=96 if high else 20)]
        for ring, (n, dist, y, length, width, tilt) in enumerate(((8, 1.2, -0.12, 1.95, 1.3, 0.12),
                                                                 (8, 0.8, -0.04, 1.55, 1.05, 0.3))):
            for k in range(n):
                a = math.tau * (k + 0.5 * ring) / n + rnd.uniform(-0.05, 0.05)
                le = length * rnd.uniform(0.95, 1.05)
                obs.append(petal("Petal", a, dist, y, le, width, 0.16 if high else 0.2, tilt, pale, col, seg, high))
        return obs

    return build(HIGH, True), build(LOW, False)


def flower_middle():
    gold = glowing(mottled("Flower Middle", GOLD_MID, GOLD_DEEP, scale=10.0, rough=0.55, bump=0.2), GOLD_MID, 0.3)
    deep = glowing(K.mat("Floret", GOLD_DEEP, rough=0.6), GOLD_DEEP, 0.2)
    prof = [(0, -0.06), (0.9, -0.06), (0.92, 0.0), (0.8, 0.05), (0.5, 0.1), (0, 0.12)]

    def build(col, high):
        if not high:
            return [glathe("Middle", [(0, -0.07), (0.94, -0.07), (0.95, 0.02), (0.8, 0.09), (0.5, 0.15), (0, 0.17)],
                           gold, col, seg=20)]
        obs = [glathe("Middle", prof, gold, col, seg=64)]
        gold_angle = math.pi * (3 - math.sqrt(5))               # florets in a sunflower spiral
        for k in range(260):
            r = 0.86 * math.sqrt((k + 0.5) / 260)
            a = k * gold_angle
            y = 0.12 * (1 - (r / 0.92) ** 2) + 0.005
            obs.append(K.sphere("Floret", 0.03 + 0.012 * r, at=at(math.cos(a) * r, y, math.sin(a) * r),
                                m=deep if k % 3 else gold, seg=6, scale=(1, 1, 0.7), col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


def flower_stem():
    stem = mottled("Giant Stem", STEM, STEM_DARK, scale=4.0, rough=0.7, bump=0.2)
    node = mottled("Stem Node", (0.4, 0.68, 0.34), STEM, scale=8.0, rough=0.65, bump=0.2)

    def r_at(y):
        return 0.45 + (0.35 - 0.45) * (y + 2) / 4

    def build(col, high):
        if not high:
            return [glathe("Stem", [(0, -2), (0.47, -2), (0.37, 2), (0, 2)], stem, col, seg=12)]
        prof = [(0, -2.0)] + [(r_at(-2 + 4 * k / 40), -2 + 4 * k / 40) for k in range(41)] + [(0, 2.0)]
        obs = [K.lathe("Stem", prof, seg=64, m=stem, col=col, flutes=10, flute_depth=0.04, flute_z=(-2.1, 2.1))]
        for y in (-1.2, 0.6):                                   # swollen nodes, like a giant grass stem
            r = r_at(y)
            obs.append(glathe("Node", [(r - 0.02, -0.12), (r + 0.05, -0.04), (r + 0.06, 0.02), (r - 0.02, 0.12)],
                              node, col, seg=48, pos=(0, y, 0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ great tree
def great_tree():
    bark = mottled("Old Bark", BARK, BARK_DARK, scale=3.0, rough=0.95, bump=0.6, third=MOSS)
    moss = K.mat("Tree Moss", MOSS, rough=0.95, bump=0.3)

    def trunk_r(y):
        return 2.4 + (1.6 - 2.4) * y / 12 + 0.9 * max(0.0, 1 - y / 1.6) ** 2

    def limbs(rnd):
        out = []
        for k in range(6):
            a = math.tau * k / 6 + 0.4
            out.append(((math.cos(a) * 0.8, 10.2 + rnd.uniform(-0.6, 0.6), math.sin(a) * 0.8),
                        (math.cos(a) * 4.2, 13.2 + rnd.uniform(-0.5, 0.8), math.sin(a) * 4.2), 0.55, 0.22))
        out.append(((0, 11.5, 0), (0.3, 15.5, -0.2), 0.7, 0.3))
        return out

    def build(col, high):
        rnd = random.Random(707)
        k = 1.0 if high else 1.05
        seg = 12 if high else 6
        if high:
            prof = [(0, 0)] + [(trunk_r(12 * j / 48), 12 * j / 48) for j in range(49)] + [(0, 12)]
            ob = K.lathe("Trunk", prof, seg=96, m=bark, col=col, flutes=22, flute_depth=0.16, flute_z=(0.2, 12))
            for v in ob.data.vertices:                         # knots and lumps in the bark
                n = Vector((v.co.x, v.co.y, 0))
                if n.length > 0.1:
                    v.co += n.normalized() * 0.12 * noise.noise(v.co * 0.9)
        else:
            ob = glathe("Trunk", [(0, 0)] + [(trunk_r(12 * j / 8) * 1.05, 12 * j / 8) for j in range(9)] + [(0, 12)],
                        bark, col, seg=16)
        obs = [ob]
        obs.append(grod("Branch", (1.0, 7.2, 0), (8.0, 9.3, 0), 0.75 * k, bark, col, seg=seg + 4, r2=0.3 * k))
        for j in range(7):
            a = math.tau * j / 7 + 0.3
            obs.append(grod("Root", (math.cos(a) * 1.4, 0.9, math.sin(a) * 1.4), (math.cos(a) * 4.0, -0.1,
                                                                                  math.sin(a) * 4.0),
                            0.55 * k, bark, col, seg=seg, r2=0.15 * k))
        for a, b, r1, r2 in limbs(rnd):
            obs.append(grod("Limb", a, b, r1 * k, bark, col, seg=seg, r2=r2 * k))
        if high:
            for j in range(4):                                  # twigs off the swing branch
                t = 0.3 + 0.15 * j
                p = (1.0 + 7.0 * t, 7.2 + 2.1 * t, 0)
                obs.append(grod("Twig", p, (p[0] + 0.8, p[1] + 1.4, rnd.uniform(-0.8, 0.8)), 0.12, bark, col,
                                seg=6, r2=0.03))
            for j in range(50):                                 # moss on the roots and at the foot
                a = rnd.uniform(0, math.tau)
                rr = rnd.uniform(2.2, 3.6)
                obs.append(blob("Moss", rnd.uniform(0.15, 0.35), (math.cos(a) * rr, 0.1 + max(0, 3.6 - rr) * 0.25,
                                                                   math.sin(a) * rr), moss, col, seed=j, seg=8,
                                lump=0.4, squash=(1.3, 0.4, 1.3)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ bench
def garden_bench():
    stone = mottled("Garden Stone", STONE, STONE_DARK, scale=5.0, rough=0.8, bump=0.35, third=MOSS)
    wood = mottled("Bench Wood", WOOD, WOOD_DARK, scale=4.0, rough=0.7, bump=0.15)
    X, Y, Z = 2.0, 0.45, 0.6

    def build(col, high):
        if not high:
            return [gbox("Bench", (X, Y, Z), (0, 0, 0), wood, col)]
        obs = []
        for s in (-1, 1):                                       # carved stone ends with a scroll
            obs.append(gbox("End", (0.14, Y, Z), (s * (X / 2 - 0.07), 0, 0), stone, col, bevel=0.025))
            obs.append(gbox("End Foot", (0.18, 0.06, Z + 0.02), (s * (X / 2 - 0.07), -Y / 2 + 0.03, 0), stone, col,
                            bevel=0.015))
            for zz in (-1, 1):
                pts = K.scroll(0.0, 0.0, 0.1, 1.5, steps=16)
                obs.append(gwire("Scroll", [(s * (X / 2 - 0.07 - 0.075), -0.05 + p[2] * 0.9, zz * (0.12 + p[0] * 0.9))
                                            for p in pts], 0.014, stone, col, res=3, bevel_res=2))
        for k in range(5):                                      # slats
            z = -Z / 2 + 0.05 + k * (Z - 0.1) / 4
            obs.append(gbox("Slat", (X - 0.3, 0.05, 0.1), (0, Y / 2 - 0.025, z), wood, col, bevel=0.01))
        obs.append(gbox("Rail", (X - 0.28, 0.09, 0.06), (0, Y / 2 - 0.1, -0.2), wood, col, bevel=0.01))
        obs.append(gbox("Rail", (X - 0.28, 0.09, 0.06), (0, Y / 2 - 0.1, 0.2), wood, col, bevel=0.01))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "ivy_wall": (ivy_wall, 2048, 0.12, 0.35, False, False),
    "rose_arch": (rose_arch, 1024, 0.12, 0.45, True, True),
    "fountain": (fountain, 2048, 0.06, 0.15, True, False),
    "hedge": (hedge, 1024, 0.1, 0.3, False, False),
    "sundial": (sundial, 512, 0.03, 0.08, True, False),
    "summerhouse": (summerhouse, 2048, 0.08, 0.2, True, False),
    "flower_head": (flower_head, 1024, 0.06, 0.15, False, False),
    "flower_middle": (flower_middle, 512, 0.05, 0.12, True, True),
    "flower_stem": (flower_stem, 512, 0.06, 0.12, True, False),
    "great_tree": (great_tree, 2048, 0.25, 0.6, True, False),
    "garden_bench": (garden_bench, 512, 0.04, 0.1, True, False),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

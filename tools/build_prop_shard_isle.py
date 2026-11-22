# Shard Isle, the first portal world, built the detailed way (tools/bake_kit.py; 22 Nov 2026, Hayden: "Can we
# continue with baking details", the portal worlds' props after the Rootmind): the floating islands' rock, the
# crystal stepping stones, a rocky mound under each crystal cluster, the Heart Stone's plinth and the Echo Crystals'
# stands. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces tools/build_shard_isle.gd and scripts/shard_isle.gd build from shapes, so the swap
# (scripts/detail_props.gd dress_shard_isle) puts each where the old one was and every collision stays the game's.
# Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   island_rock     a floating island's underside at size 1: its open top at y 0 is 0.95 across (the moss disc
#                   covers it), it bellies out and rounds in to a point at y -1.46. The game scales it by the island's
#                   radius and depth. Lilac rock in pale and dark bands, lumpy and chipped, chunks hanging off it
#                   and moss trailing over the rim.
#   stepping_stone  a 1.7 x 0.5 x 1.7 crystal slab (the old box's size): chipped facets, a glowing seam or two and
#                   frosty inclusions.
#   cluster_base    a new rocky mound for under each crystal cluster on the rim, 1.1 m across and 0.45 m up, with
#                   moss and pebbles.
#   heart_plinth    the Heart Stone's obsidian base (the old six-sided cylinder: 1.8 across at the foot, 1.4 at the
#                   top, 1.2 tall): mouldings, gold bands, a gold rim round each of its three crystal sockets and
#                   green runes glowing on its sides.
#   echo_stand      an Echo Crystal's obsidian stand (0.35 at the foot, 0.25 at the top, 0.7 tall) with a gold
#                   collar and a glowing rune.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_shard_isle.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["island_rock", "stepping_stone", "cluster_base", "heart_plinth", "echo_stand"]
KIND = next((a for a in sys.argv if a in KINDS), "island_rock")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

ROCK = (0.52, 0.46, 0.68)
ROCK_PALE = (0.66, 0.6, 0.8)
ROCK_DARK = (0.34, 0.29, 0.47)
MOSS = (0.36, 0.72, 0.6)
MOSS_DARK = (0.22, 0.5, 0.44)
STONE = (0.6, 0.85, 0.95)
STONE_DEEP = (0.42, 0.7, 0.86)
STONE_PALE = (0.82, 0.95, 1.0)
GLOW = (0.4, 0.95, 0.5)
OBSIDIAN = (0.12, 0.08, 0.18)
OBSIDIAN_SHEEN = (0.2, 0.14, 0.28)
GOLD = (0.95, 0.78, 0.35)


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
    """A round bar between two points given in Godot's terms."""
    return rod(name, at(*a), at(*b), r, m, col, seg=seg, r2=r2)


def gwire(name, pts, r, m, col, closed=False, res=12, bevel_res=4):
    return K.wire(name, [at(*p) for p in pts], r, m=m, closed=closed, res=res, bevel_res=bevel_res, col=col)


def ring_pts(c, n, r, count=16):
    """count points round a circle r across about c (Godot), in the plane facing n."""
    c, n = Vector(c), Vector(n).normalized()
    u = n.cross(Vector((0, 1, 0)))
    if u.length < 0.01:
        u = Vector((1, 0, 0))
    u.normalize()
    v = n.cross(u).normalized()
    return [tuple(c + (u * math.cos(k * math.tau / count) + v * math.sin(k * math.tau / count)) * r)
            for k in range(count)]


def blob(name, r, pos, m, col, seed=0, seg=12, lump=0.25, squash=(1.0, 1.0, 1.0)):
    """A lumpy round thing r across at a Godot position, squashed along Godot x, y, z."""
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
    """A material that wanders between two colours (and a third in rarer patches: paint peeling to wood)."""
    m = K.mat(name, a, rough=rough, metal=metal, bump=bump, grain=grain)
    nt, bsdf, co = _nodes(m)
    c = _mix_rgb(nt, _patches(nt, co, scale, lo, hi), a, b)
    if third:
        c = _mix_rgb(nt, _patches(nt, co, scale * 1.7, 0.62, 0.66, w=2.7), c, third)
    nt.links.new(c, bsdf.inputs["Base Color"])
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



def cone(name, r, y0, y1, m, col, seg=12, rings=8, star=0, star_depth=0.0, rough=0.0, seed=0, droop=0.0, cap=True,
         ripple=0, ripple_depth=0.0):
    """A cone (Godot) from radius r at y0 to a point at y1. star pleats it into points round (fronds), rough lumps it,
    droop pulls the bottom edge down between the pleats, ripple scallops the bottom edge."""
    bm = bmesh.new()
    off = Vector((seed * 2.3, seed * 1.1, seed * 0.7))
    rows = []
    for i in range(rings + 1):
        t = i / rings                                           # 0 at the bottom, 1 at the tip
        ring = []
        for k in range(seg):
            a = k / seg * math.tau
            rr = r * (1 - t)
            if star:
                rr *= 1.0 - star_depth * (0.5 - 0.5 * math.cos(a * star))
            if ripple and i == 0:
                rr *= 1.0 + ripple_depth * math.cos(a * ripple)
            y = y0 + (y1 - y0) * t
            if droop and i == 0:
                y -= droop * (0.5 + 0.5 * math.cos(a * star)) if star else droop
            p = Vector((math.cos(a) * rr, y, math.sin(a) * rr))
            if rough and 0 < i < rings:
                p += Vector((math.cos(a), 0, math.sin(a))) * r * rough * noise.noise(p * 1.7 + off)
            ring.append(bm.verts.new(at(*p)))
        rows.append(ring)
    for i in range(rings):
        for k in range(seg):
            a, b = rows[i][k], rows[i][(k + 1) % seg]
            c, d = rows[i + 1][(k + 1) % seg], rows[i + 1][k]
            bm.faces.new((a, b, c, d))
    if cap:
        mid = bm.verts.new(at(0, rows and y0, 0))
        mid.co = Vector(at(0, y0 + 0.05 * (y1 - y0), 0))
        for k in range(seg):
            bm.faces.new((rows[0][(k + 1) % seg], rows[0][k], mid))
    bmesh.ops.remove_doubles(bm, verts=rows[-1], dist=1e-4)
    return K._obj(name, bm, m, True, col)


def glowing(m, rgb, strength):
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Emission Color"].default_value = (*(K.srgb_to_linear(c) for c in rgb), 1.0)
    b.inputs["Emission Strength"].default_value = strength
    return m


def strata(name, a, pale, dark, moss=None, bands=7.0, rough=0.95, bump=0.6):
    """Rock in wavy pale and dark bands across its height, with moss creeping down from its top edge."""
    m = mottled(name, a, dark, scale=5.0, rough=rough, bump=bump, lo=0.4, hi=0.75)
    nt, bsdf, co = _nodes(m)
    c = bsdf.inputs["Base Color"].links[0].from_socket
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = bands
    wave.inputs["Distortion"].default_value = 4.0
    wave.inputs["Detail"].default_value = 2.0
    nt.links.new(co, wave.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.55
    mr.inputs["From Max"].default_value = 0.8
    nt.links.new(wave.outputs["Fac"], mr.inputs["Value"])
    c = _mix_rgb(nt, mr.outputs["Result"], c, pale)
    if moss:
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(co, sep.inputs["Vector"])
        top = nt.nodes.new("ShaderNodeMapRange")
        top.inputs["From Min"].default_value = moss[0]
        top.inputs["From Max"].default_value = moss[1]
        nt.links.new(sep.outputs["Z"], top.inputs["Value"])
        nz = _patches(nt, co, 9.0, 0.3, 0.6)
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        nt.links.new(top.outputs["Result"], mul.inputs[0])
        nt.links.new(nz, mul.inputs[1])
        c = _mix_rgb(nt, mul.outputs["Value"], c, MOSS_DARK)
    nt.links.new(c, bsdf.inputs["Base Color"])
    return m


def lumpy_lathe(name, prof, m, col, seg, rings, lump, scale, seed=0, keep_top=0.0, sides=0, chip=0.0, outward=False):
    """A lathe of prof [(r, y)] resampled to rings rows, its sides pushed in and out by noise (lump at noise scale)
    and chipped flat in places (chip). Rows at or over keep_top stay as they are, so the top stays flat."""
    pts = []
    for k in range(rings):
        t = k / (rings - 1) * (len(prof) - 1)
        i = min(int(t), len(prof) - 2)
        f = t - i
        pts.append((prof[i][0] * (1 - f) + prof[i + 1][0] * f, prof[i][1] * (1 - f) + prof[i + 1][1] * f))
    ob = K.lathe(name, pts, seg=seg, m=m, col=col, sides=sides)
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.9))
    for v in ob.data.vertices:
        if v.co.z >= keep_top - 1e-4:
            continue
        rr = Vector((v.co.x, v.co.y, 0)).length
        if rr < 1e-4:
            continue
        p = Vector(v.co) * scale + off
        n = noise.noise(p) + 0.45 * noise.noise(p * 2.7)
        k = 1.0 + lump * (max(n, -0.2) + 0.2 if outward else n)
        if chip:
            c = round(noise.noise(p * 0.6 + off) * 3) / 3
            k += chip * (abs(c) if outward else c)
        v.co.x *= k
        v.co.y *= k
    return ob


# ================================================================ island rock
# Round-bellied, so the Crystal Basin (scripts/sunken_secrets.gd, 8 m out on the main island and nearly 5 m down)
# stays inside it. Open at the top: the moss disc covers it, and a pool sunk through the island looks straight down
# into its own basin, not onto a floor of rock.
ISLAND = [(0.95, 0.0), (0.975, -0.03), (0.96, -0.1), (0.94, -0.25), (0.91, -0.45), (0.88, -0.62), (0.8, -0.76),
          (0.64, -0.88), (0.46, -0.98), (0.3, -1.08), (0.17, -1.22), (0.07, -1.36), (0.02, -1.44), (0.0, -1.46)]


def island_rock():
    rock = strata("Island Rock", ROCK, ROCK_PALE, ROCK_DARK, moss=(-0.16, -0.03), bands=9.0)
    moss = mottled("Island Moss", MOSS, MOSS_DARK, scale=12.0, rough=0.95, bump=0.6)
    prof = ISLAND

    def build(col, high):
        if not high:
            # a touch wider than the plain profile, half way out through the lumps
            return [K.lathe("Rock", [(r * 1.04, y) for r, y in prof], seg=20, m=rock, col=col)]
        obs = [lumpy_lathe("Rock", prof, rock, col, 160, 70, 0.06, 3.0, seed=1, keep_top=0.0, chip=0.04,
                           outward=True)]
        rnd = random.Random(3)
        for k in range(14):                                     # chunks hanging off the underside
            a = rnd.uniform(0, math.tau)
            y = rnd.uniform(-0.25, -1.0)
            rr = next(r for r, yy in ISLAND if yy <= y) * 0.97
            q = Vector((math.cos(a), 0, math.sin(a)))
            p = q * rr + Vector((0, y, 0))
            obs.append(blob("Chunk", rnd.uniform(0.04, 0.08), tuple(p), rock, col, seed=k, seg=10, lump=0.4,
                            squash=(1.0, 1.4, 1.0)))
        for k in range(46):                                     # moss trailing over the rim
            a = k / 46 * math.tau + rnd.uniform(-0.05, 0.05)
            q = Vector((math.cos(a), 0, math.sin(a)))
            l = rnd.uniform(0.06, 0.2)
            pts = [tuple(q * (0.975 - j * 0.02) + Vector((0, -0.01 - l * j / 4, 0))) for j in range(5)]
            obs.append(gwire("Moss", pts, rnd.uniform(0.008, 0.016), moss, col, res=4, bevel_res=2))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ stepping stone
def stepping_stone():
    body = mottled("Stone Crystal", STONE, STONE_DEEP, scale=3.0, rough=0.2, bump=0.2, third=STONE_PALE)
    glowing(body, STONE, 0.2)
    seam = glowing(K.mat("Stone Seam", STONE_PALE, rough=0.2), (0.7, 1.0, 0.95), 1.6)
    frost = K.mat("Stone Frost", STONE_PALE, rough=0.5)

    def slab(name, bevel, segs, chip, col):
        ob = K.box(name, gsize(1.7, 0.5, 1.7), at=at(0, 0, 0), m=body, bevel=bevel, seg=segs, col=col)
        if chip:
            # chip the top and sides into flat facets, never past the old box's edges
            for v in ob.data.vertices:
                p = Vector(v.co)
                n = noise.noise(p * 1.3 + Vector((4.0, 1.0, 2.0)))
                k = 1.0 - chip * (0.5 + 0.5 * round(n * 3) / 3)
                v.co.x *= k if abs(v.co.x) > 0.6 else 1.0
                v.co.y *= k if abs(v.co.y) > 0.6 else 1.0
                if v.co.z > 0.2:
                    v.co.z -= chip * 0.4 * (0.5 + 0.5 * n)
        return ob

    def build(col, high):
        if not high:
            return [K.box("Slab", gsize(1.7, 0.5, 1.7), at=at(0, 0, 0), m=body, bevel=0.06, seg=1, col=col)]
        obs = [slab("Slab", 0.07, 4, 0.03, col)]
        rnd = random.Random(5)
        for k in range(3):                                      # glowing seams across the top
            a = rnd.uniform(0, math.pi)
            q = Vector((math.cos(a), 0, math.sin(a)))
            t = Vector((-q.z, 0, q.x))
            c = t * rnd.uniform(-0.35, 0.35)
            pts = [tuple(c + q * (j - 3) * 0.22 + t * rnd.uniform(-0.05, 0.05) + Vector((0, 0.243, 0)))
                   for j in range(7)]
            obs.append(gwire("Seam", pts, 0.012, seam, col, res=3, bevel_res=1))
        for k in range(6):                                      # frosty inclusions just under the faces
            p = (rnd.uniform(-0.65, 0.65), rnd.uniform(-0.1, 0.2), rnd.uniform(-0.65, 0.65))
            obs.append(blob("Frost", rnd.uniform(0.05, 0.1), p, frost, col, seed=k, seg=8, lump=0.5,
                            squash=(1.6, 0.3, 1.0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ cluster base
def cluster_base():
    rock = strata("Mound Rock", ROCK, ROCK_PALE, ROCK_DARK, bands=6.0)
    moss = mottled("Mound Moss", MOSS, MOSS_DARK, scale=10.0, rough=0.95, bump=0.7)
    prof = [(1.15, -0.15), (1.12, 0.0), (1.0, 0.12), (0.8, 0.26), (0.55, 0.37), (0.3, 0.43), (0.0, 0.45)]

    def build(col, high):
        if not high:
            return [K.lathe("Mound", prof, seg=16, m=rock, col=col)]
        obs = [lumpy_lathe("Mound", prof, rock, col, 96, 24, 0.12, 2.2, seed=2, keep_top=0.44, chip=0.06)]
        rnd = random.Random(7)
        for k in range(9):                                      # moss cushions
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(0.2, 0.8)
            y = 0.45 * (1 - (d / 1.12) ** 2) - 0.02
            obs.append(blob("Moss", rnd.uniform(0.12, 0.22), (math.cos(a) * d, y, math.sin(a) * d), moss, col,
                            seed=k + 3, seg=10, lump=0.35, squash=(1.0, 0.35, 1.0)))
        for k in range(10):                                     # pebbles round its foot
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(1.0, 1.12)
            obs.append(blob("Pebble", rnd.uniform(0.04, 0.08), (math.cos(a) * d, 0.02, math.sin(a) * d), rock, col,
                            seed=k + 20, seg=8, lump=0.3, squash=(1.0, 0.7, 1.0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ heart plinth and echo stand
def obsidian(name):
    m = mottled(name, OBSIDIAN, OBSIDIAN_SHEEN, scale=7.0, rough=0.25, metal=0.35, bump=0.15)
    return m


def rune(name, c, q, size, m, col, seed, slope=0.0):
    """A little made-up rune of three glowing strokes on the face at c facing q (Godot). slope is how far the face
    leans in for each metre up, so the strokes lie on it."""
    rnd = random.Random(seed)
    q = Vector(q).normalized()
    t = Vector((-q.z, 0, q.x))
    up = (Vector((0, 1, 0)) - q * slope).normalized()
    c = Vector(c) + q * 0.008
    obs = [gwire(name, [tuple(c - up * size), tuple(c + up * size)], size * 0.09, m, col, res=2, bevel_res=2)]
    for k in range(2):
        s = rnd.choice((-1, 1))
        a = c + up * rnd.uniform(-0.6, 0.6) * size
        b = a + (t * s * rnd.uniform(0.45, 0.7) + up * rnd.uniform(-0.5, 0.5)) * size
        obs.append(gwire(name, [tuple(a), tuple(b)], size * 0.08, m, col, res=2, bevel_res=2))
    return obs


def heart_plinth():
    obs_m = obsidian("Heart Obsidian")
    gold = K.mat("Heart Gold", GOLD, rough=0.3, metal=1.0, bump=0.1)
    runes = glowing(K.mat("Heart Rune", GLOW, rough=0.3), GLOW, 2.5)
    # foot 1.8, top 1.4, 1.2 tall, like the old hexagon, with a plinth step and a cap moulding
    prof = [(0.0, 0.0), (1.86, 0.0), (1.86, 0.1), (1.78, 0.14), (1.76, 0.2), (1.6, 0.62), (1.46, 1.0), (1.5, 1.04),
            (1.5, 1.12), (1.42, 1.16), (1.4, 1.2), (0.0, 1.2)]

    def build(col, high):
        obs = [K.lathe("Plinth", prof, seg=6 * (8 if high else 1), m=obs_m, col=col, sides=6)]
        if not high:
            return obs
        for y, r in ((0.2, 1.765), (1.02, 1.47)):               # gold bands
            ob = K.lathe("Band", [(r + 0.02, y - 0.03), (r + 0.035, y), (r + 0.02, y + 0.03)], seg=48, m=gold,
                         col=col, sides=6)
            obs.append(ob)
        for k in range(3):                                      # gold rims round the sockets
            a = k * math.tau / 3
            c = (math.cos(a) * 0.9, 1.21, math.sin(a) * 0.9)
            obs.append(gwire("Rim", ring_pts(c, (0, 1, 0), 0.24, 24), 0.03, gold, col, closed=True, res=2,
                             bevel_res=3))
        for k in range(6):                                      # a rune on each of its six faces
            a = k * math.tau / 6                                # the lathe's faces face these ways
            q = Vector((math.cos(a), 0, -math.sin(a)))
            # the face's middle at 0.6 up: the hexagon's inradius there (it leans in 0.38 a metre)
            rr = 1.605 * math.cos(math.pi / 6)
            c = q * rr + Vector((0, 0.6, 0))
            obs += rune("Rune", tuple(c), tuple(q), 0.16, runes, col, k, slope=0.38 * math.cos(math.pi / 6))
        return obs

    return build(HIGH, True), build(LOW, False)


def echo_stand():
    obs_m = obsidian("Echo Obsidian")
    gold = K.mat("Echo Gold", GOLD, rough=0.3, metal=1.0, bump=0.1)
    runes = glowing(K.mat("Echo Rune", GLOW, rough=0.3), GLOW, 2.5)
    prof = [(0.0, 0.0), (0.37, 0.0), (0.37, 0.05), (0.34, 0.08), (0.3, 0.4), (0.26, 0.62), (0.28, 0.65),
            (0.28, 0.68), (0.25, 0.7), (0.0, 0.7)]

    def build(col, high):
        obs = [K.lathe("Stand", prof, seg=6 * (8 if high else 1), m=obs_m, col=col, sides=6)]
        if not high:
            return obs
        obs.append(K.lathe("Collar", [(0.3, 0.6), (0.305, 0.63), (0.3, 0.66)], seg=48, m=gold, col=col, sides=6))
        obs.append(K.lathe("Foot", [(0.355, 0.07), (0.36, 0.09), (0.35, 0.11)], seg=48, m=gold, col=col, sides=6))
        for k in range(3):
            aa = k * math.tau / 3
            q = Vector((math.cos(aa), 0, -math.sin(aa)))
            rr = 0.315 * math.cos(math.pi / 6)
            obs += rune("Rune", tuple(q * rr + Vector((0, 0.32, 0))), tuple(q), 0.06, runes, col, k + 10,
                        slope=0.125 * math.cos(math.pi / 6))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "island_rock": (island_rock, 2048, 0.12, 0.3, True, False),
    "stepping_stone": (stepping_stone, 1024, 0.05, 0.12, True, True),
    "cluster_base": (cluster_base, 1024, 0.1, 0.25, True, False),
    "heart_plinth": (heart_plinth, 1024, 0.05, 0.12, True, True),
    "echo_stand": (echo_stand, 512, 0.02, 0.05, True, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

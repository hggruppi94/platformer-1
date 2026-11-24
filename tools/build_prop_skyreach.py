# The Skyreach Trail, the Starhorn's mountain (scripts/skyreach_trail.gd), built the detailed way (tools/bake_kit.py;
# 24 Nov 2026, Hayden: "Okay continue baking details"): the kerb stones along the trail's edge, the rocks ringing the
# summit, the Waystones with their lantern cages, the pines round the foot, the prayer flags, the Star Chest and the
# glowing Star Blooms round the Starhorn's bed. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Every piece is made in the space of the plain mesh it replaces, so scripts/detail_props.gd dress_skyreach puts each
# one where the old one was and every collision stays the game's. Blender's X is Godot's X, Blender's -Y is Godot's
# +Z and Blender's Z is Godot's Y.
#   kerb_stone   a kerb stone 0.7 wide (x), 0.45 high and 0.9 long (z), centred: a chiselled block of lilac granite
#                with worn corners, chisel marks, lichen and a little moss on top.
#   ring_rock    one of the summit's ring rocks at radius 1 (the old ball was r across and 1.4 r tall), centred: a
#                lumpy, weathered boulder with mossy shoulders. The game scales it to each rock's radius.
#   waystone     a Waystone from the ground: a six-sided standing stone (0.42 across at the foot, 0.3 at the top,
#                1.6 tall) carved with a band of runes and a star, and an iron lantern cage round the lamp (the
#                game's own ball at 1.85 up, which still lights) with a little roof and a finial.
#   trail_pine   a mountain pine at size 1, 6 m tall: a ridged trunk with roots and three tiers of drooping needle
#                fronds (the frozen pine's shape without its snow). The game sizes it to each old pine's height.
#   prayer_flag  one prayer flag 0.45 x 0.5 (and 0.03 thick), centred: soft cloth with a hem and the cord through it,
#                a printed star with rays and a border, and a frayed bottom edge. Baked pale, so the game tints each
#                flag its own colour.
#   chest_box    the Star Chest's box from the ground (1.8 x 1.0 x 1.2) with its gold band at 0.75 up: carved stone
#                panels with stars, gold corner brackets and a gold lock plate. The crystal lid stays the game's.
#   star_bloom   a Star Bloom round its middle (the old glowing ball of radius 0.25): a five-pointed glowing flower
#                with a second ring of petals, a bright heart and three leaves under it. Baked pale with its glow.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_skyreach.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["kerb_stone", "ring_rock", "waystone", "trail_pine", "prayer_flag", "chest_box", "star_bloom"]
KIND = next((a for a in sys.argv if a in KINDS), "kerb_stone")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

BARK = (0.4, 0.3, 0.28)              # the trail's "Pine Trunk"
BARK_DARK = (0.24, 0.17, 0.15)
NEEDLE = (0.25, 0.42, 0.45)          # its "Pine"
NEEDLE_DARK = (0.13, 0.27, 0.3)
NEEDLE_LIGHT = (0.36, 0.53, 0.52)
KERB = (0.5, 0.46, 0.58)             # "Kerb Stone"
RING = (0.62, 0.58, 0.72)            # "Ring Stone"
WAY = (0.55, 0.52, 0.66)             # "Waystone"
CHEST = (0.5, 0.48, 0.62)            # "Chest Stone"
GOLD = (0.95, 0.78, 0.35)            # "Chest Gold"
IRON = (0.22, 0.2, 0.26)
LICHEN = (0.8, 0.82, 0.55)
MOSS = (0.36, 0.5, 0.4)
CLOTH = (0.94, 0.93, 0.9)            # flags are baked pale and tinted in the game
BLOOM = (0.88, 0.95, 1.0)


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


# ================================================================ shared
def tube(name, pts, radii, m, col, seg=10, flutes=0, flute_depth=0.0, twist=0.0, rough=0.0, seed=0, cap0=True,
         cap1=True, inward=False):
    """A round, tapering limb swept along Godot points pts with a radius at each (trunks, branches, roots, logs).
    flutes cut grooves along it (bark furrows) that twist round by twist radians a metre; rough lumps it with noise."""
    P = [Vector(at(*p)) for p in pts]
    n = len(P)
    tans = []
    for i in range(n):
        d = P[min(i + 1, n - 1)] - P[max(i - 1, 0)]
        tans.append(d.normalized())
    up = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = tans[0].cross(up).normalized()
    bm = bmesh.new()
    rings = []
    length = 0.0
    off = Vector((seed * 2.1, seed * 1.3, seed * 0.7))
    for i in range(n):
        if i > 0:
            length += (P[i] - P[i - 1]).length
            # parallel transport the frame so the limb never twists by itself
            nrm = (nrm - tans[i] * nrm.dot(tans[i])).normalized()
        bi = tans[i].cross(nrm).normalized()
        ring = []
        for k in range(seg):
            a = k / seg * math.tau
            r = radii[i]
            if flutes:
                r *= 1.0 - flute_depth * max(0.0, math.cos(a * flutes + length * twist)) ** 2
            q = nrm * math.cos(a) + bi * math.sin(a)
            if rough:
                r *= 1.0 + rough * noise.noise(P[i] * 2.5 + q * 1.5 + off)
            ring.append(bm.verts.new(P[i] + q * r))
        rings.append(ring)
    for i in range(n - 1):
        for k in range(seg):
            a, b = rings[i][k], rings[i][(k + 1) % seg]
            c, d = rings[i + 1][(k + 1) % seg], rings[i + 1][k]
            bm.faces.new((d, c, b, a) if inward else (a, b, c, d))
    for ring, cap, end in ((rings[0], cap0, 0), (rings[-1], cap1, n - 1)):
        if cap and radii[end] > 0.0005:
            mid = bm.verts.new(P[end])
            for k in range(seg):
                f = (ring[k], ring[(k + 1) % seg], mid)
                bm.faces.new(f if (end == n - 1) != inward else tuple(reversed(f)))
    return K._obj(name, bm, m, True, col)


def finer(pts, radii, n):
    """The same limb with n rings (for the HIGH version: its furrows and lumps need many rings to show)."""
    out_p, out_r = [], []
    m = len(pts) - 1
    for k in range(n):
        t = k / (n - 1) * m
        i = min(int(t), m - 1)
        f = t - i
        out_p.append(tuple(Vector(pts[i]).lerp(Vector(pts[i + 1]), f)))
        out_r.append(radii[i] * (1 - f) + radii[i + 1] * f)
    return out_p, out_r


def curve(a, b, bend, n):
    """n points from a to b (Godot), bowed sideways and down by bend (a Godot vector added at the middle)."""
    a, b, bend = Vector(a), Vector(b), Vector(bend)
    return [tuple(a.lerp(b, t) + bend * math.sin(math.pi * t)) for t in (k / (n - 1) for k in range(n))]


def mossy(name, a, b, moss, scale=4.0, rough=0.9, bump=0.5, grain=None, up=0.45):
    """Bark that wanders between two colours, with moss on whatever faces up."""
    m = mottled(name, a, b, scale=scale, rough=rough, bump=bump, grain=grain)
    nt, bsdf, co = _nodes(m)
    c = bsdf.inputs["Base Color"].links[0].from_socket
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = up
    mr.inputs["From Max"].default_value = up + 0.2
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nz = _patches(nt, co, scale * 2.0, 0.4, 0.55)
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(mr.outputs["Result"], mul.inputs[0])
    nt.links.new(nz, mul.inputs[1])
    nt.links.new(_mix_rgb(nt, mul.outputs["Value"], c, moss), bsdf.inputs["Base Color"])
    return m






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


def lin(c):
    return tuple(K.srgb_to_linear(v) for v in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def painted(name, rough=0.85, bump=0.4, glow=0.0):
    """A material whose colour is the high mesh's own vertex colours ("Col"), with a fine rough bump: the rock's
    bands are worked out in Python with its shape, so colour and ledges always line up."""
    m = K.mat(name, (0.7, 0.4, 0.3), rough=rough)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], b.inputs["Base Color"])
    if glow > 0.0:
        nt.links.new(attr.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = glow
    co = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 26.0
    nz.inputs["Detail"].default_value = 10.0
    nt.links.new(co, nz.inputs["Vector"])
    bmp = nt.nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = bump
    bmp.inputs["Distance"].default_value = 0.01
    nt.links.new(nz.outputs["Fac"], bmp.inputs["Height"])
    nt.links.new(bmp.outputs["Normal"], b.inputs["Normal"])
    return m


def colour_mesh(bm, col_fn):
    """Sets each corner's vertex colour from col_fn(vertex position in Godot terms, its normal in Godot terms)."""
    layer = bm.loops.layers.color.new("Col")
    cache = {}
    for v in bm.verts:
        p = (v.co.x, v.co.z, -v.co.y)
        n = v.normal
        cache[v.index] = (*lin(col_fn(p, (n.x, n.z, -n.y))), 1.0)
    for f in bm.faces:
        for lp in f.loops:
            lp[layer] = cache[lp.vert.index]




# ================================================================ shared stone
def rounded_block(name, size, rad, cuts, m, col, push=None, colour=None):
    """A box (Godot size, centred) with its edges and corners rounded off by rad, made of a fine grid (cuts a side),
    each point then pushed out along its normal by push(p, n) and coloured by colour(p, n) (Godot terms)."""
    hx, hy, hz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    inner = Vector((hx - rad, hy - rad, hz - rad))
    for v in bm.verts:
        g = Vector((v.co.x * hx, v.co.z * hy, -v.co.y * hz))      # Godot
        c = Vector((max(-inner.x, min(inner.x, g.x)), max(-inner.y, min(inner.y, g.y)), max(-inner.z, min(inner.z, g.z))))
        d = g - c
        n = d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))
        p = c + n * rad
        if push:
            p = p + n * push(p, n)
        v.co = Vector(at(p.x, p.y, p.z))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    if colour:
        colour_mesh(bm, lambda p, n: colour(p, n))
    return K._obj(name, bm, m, True, col)


def stone_colour(base, seed, moss_up=0.7):
    def fn(p, n):
        q = Vector(p) * 3.0 + Vector((seed, 0, 0))
        c = mix(base, mix(base, (1.0, 0.97, 1.0), 0.45), 0.5 + 0.5 * noise.noise(q))
        c = mix(c, mix(base, (0.2, 0.18, 0.26), 0.6), max(0.0, noise.noise(Vector(p) * 9.0 + Vector((0, seed, 3)))) * 0.35)
        speck = noise.noise(Vector(p) * 40.0)
        if speck > 0.5:
            c = mix(c, (0.95, 0.93, 1.0), 0.5)
        lich = noise.noise(Vector(p) * 5.0 + Vector((7, 7, seed)))
        if lich > 0.5:
            c = mix(c, LICHEN, min(0.35, (lich - 0.5) * 2.0))
        if n[1] > moss_up and noise.noise(Vector(p) * 4.0 + Vector((2, seed, 1))) > -0.1:
            c = mix(c, MOSS, 0.7)
        return c
    return fn


def chisel(scale=1.0, seed=0.0):
    def fn(p, n):
        q = Vector(p)
        d = 0.012 * scale * noise.noise(q * 3.0 + Vector((seed, 1, 2)))
        d += 0.004 * scale * noise.noise(q * 18.0)
        # chisel marks: shallow parallel scoops across each face
        d -= 0.003 * scale * max(0.0, math.sin((q.x + q.y * 0.6 + q.z * 0.3) * 70.0))
        return d
    return fn


# ================================================================ kerb stone
def kerb_stone():
    m = painted("Kerb Granite", bump=0.35)
    plain = K.mat("Kerb Low", KERB, rough=0.9)
    hi = rounded_block("Kerb", (0.7, 0.45, 0.9), 0.06, 48, m, HIGH, chisel(1.0, 3.0), stone_colour(KERB, 3.0))
    lo = rounded_block("Kerb", (0.7, 0.45, 0.9), 0.06, 2, plain, LOW)
    return [hi], [lo]


# ================================================================ ring rock
def ring_rock():
    m = painted("Ring Rock", bump=0.5)
    plain = K.mat("Ring Rock Low", RING, rough=0.9)

    def build(col, high):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=6 if high else 3, radius=1.0)
        for v in bm.verts:
            d = v.co.normalized()
            r = 1.0 + 0.14 * noise.noise(d * 1.2 + Vector((4, 0, 0))) + 0.05 * noise.noise(d * 3.0)
            for k in range(6):
                a = Vector((math.sin(k * 2.1 + 1), math.cos(k * 1.3), math.sin(k * 2.9))).normalized()
                t = d.dot(a)
                if t > 0.8:
                    r -= (t - 0.8) * 0.55
            if high:
                r += 0.025 * noise.noise(d * 9.0) + 0.008 * noise.noise(d * 30.0)
            v.co = d * r
            v.co.z *= 0.7
        bm.normal_update()
        if high:
            colour_mesh(bm, stone_colour(RING, 5.0, moss_up=0.55))
        return [K._obj("Rock", bm, m if high else plain, True, col)]

    return build(HIGH, True), build(LOW, False)


# ================================================================ Waystone
RUNES = [  # made-up strokes for each of the six faces: (u0, v0, u1, v1) in the face's band, -1..1
    [(-0.5, -0.8, -0.5, 0.8), (-0.5, 0.0, 0.4, 0.6), (0.4, -0.8, 0.4, 0.6)],
    [(0.0, -0.8, 0.0, 0.8), (-0.5, 0.4, 0.5, 0.4), (-0.4, -0.5, 0.0, 0.0)],
    [(-0.5, -0.8, 0.5, 0.8), (0.5, -0.8, -0.5, 0.8), (-0.6, 0.0, 0.6, 0.0)],
    [(-0.4, 0.8, 0.4, 0.8), (0.0, 0.8, 0.0, -0.8), (-0.5, -0.4, 0.5, -0.8)],
    [(-0.5, -0.8, 0.0, 0.8), (0.0, 0.8, 0.5, -0.8), (-0.2, 0.0, 0.2, 0.0)],
    [(-0.4, -0.8, -0.4, 0.8), (-0.4, 0.8, 0.4, 0.2), (-0.4, 0.2, 0.4, -0.6)],
]
BAND = (0.95, 1.3)              # the rune band's bottom and top


def _seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / max(1e-9, dx * dx + dy * dy)))
    return math.hypot(px - (ax + dx * t), py - (ay + dy * t))


def _star_d(x, y, r):
    """How far inside a five-pointed star of radius r a point is (positive inside)."""
    a = math.atan2(x, y)
    k = math.tau / 5.0
    f = abs(((a % k) + k) % k - k / 2.0) / (k / 2.0)      # 0 at a point, 1 between
    edge = r * (0.42 + 0.58 * (1.0 - f) ** 1.6)
    return edge - math.hypot(x, y)


def waystone_carve(x, y, z):
    """(depth inward, 0..1 how much it's carved) on the pillar at a point: runes in the band and a star under it."""
    a = math.atan2(x, z)
    k = math.tau / 6.0
    face = int(((a + k / 2.0) % math.tau) // k)
    local = ((a + k / 2.0) % k) - k / 2.0               # -k/2..k/2 across the face
    u = local / (k / 2.0) * 0.85
    if BAND[0] < y < BAND[1]:
        v = (y - BAND[0]) / (BAND[1] - BAND[0]) * 2.0 - 1.0
        d = min(_seg_dist(u, v * 1.0, *s) for s in RUNES[face])
        if d < 0.13:
            return 0.012, 1.0 - d / 0.13
    # a ring groove above and below the band
    for yy in (BAND[0] - 0.06, BAND[1] + 0.06):
        if abs(y - yy) < 0.018:
            return 0.008, 1.0
    if face == 0 and 0.45 < y < 0.8:
        s = _star_d(u * 0.2, y - 0.62, 0.15)
        if s > 0.0:
            return 0.01, min(1.0, s / 0.02)
    return 0.0, 0.0


def waystone():
    stone = painted("Waystone Stone", bump=0.35)
    plain = K.mat("Waystone Low", WAY, rough=0.9)
    iron = K.mat("Lantern Iron", IRON, rough=0.5, metal=0.8, bump=0.2)
    gold = K.mat("Lantern Gold", GOLD, rough=0.35, metal=1.0)

    def pillar(col, high):
        bm = bmesh.new()
        seg, rows = (192, 140) if high else (6, 3)
        rings = []
        for j in range(rows + 1):
            y = 1.6 * j / rows
            r0 = 0.42 + (0.3 - 0.42) * (y / 1.6)
            ring = []
            for i in range(seg):
                a = math.tau * i / seg if high else math.tau * i / 6 - math.pi / 6 + math.pi / 6
                half = math.pi / 6
                ang = (a + half) % (2 * half) - half
                rr = r0 * math.cos(half) / math.cos(ang)
                if high:
                    x, z = math.sin(a) * rr, math.cos(a) * rr
                    d, _ = waystone_carve(x, y, z)
                    rr += 0.012 * noise.noise(Vector((x * 4, y * 4, z * 4))) + 0.003 * noise.noise(Vector((x, y, z)) * 20.0) - d
                    # corners worn round
                    rr -= 0.02 * max(0.0, abs(ang) / half - 0.8) * 5.0 * 0.5
                ring.append(bm.verts.new(at(math.sin(a) * rr, y, math.cos(a) * rr)))
            rings.append(ring)
        for j in range(rows):
            for i in range(seg):
                k2 = (i + 1) % seg
                bm.faces.new((rings[j][i], rings[j][k2], rings[j + 1][k2], rings[j + 1][i]))
        top = bm.verts.new(at(0, 1.62 if high else 1.6, 0))
        for i in range(seg):
            bm.faces.new((rings[rows][i], rings[rows][(i + 1) % seg], top))
        bot = bm.verts.new(at(0, 0, 0))
        for i in range(seg):
            bm.faces.new((rings[0][(i + 1) % seg], rings[0][i], bot))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        if high:
            base = stone_colour(WAY, 9.0, moss_up=0.8)

            def colour(p, n):
                c = base(p, n)
                d, w = waystone_carve(*p)
                if w > 0.0:
                    c = mix(c, (0.36, 0.32, 0.48), 0.6 * min(1.0, w * 1.5))
                if p[1] < 0.35 and noise.noise(Vector(p) * 5.0) > -0.2:
                    c = mix(c, MOSS, 0.55 * (1.0 - p[1] / 0.35))
                return c
            colour_mesh(bm, colour)
        return K._obj("Pillar", bm, stone if high else plain, True, col)

    def ring(name, r, y, t, m, col, high):
        if high:
            return gwire(name, ring_pts((0, y, 0), (0, 1, 0), r, 24), t, m, col, closed=True, res=6)
        # a low ring: six short bars round it
        pts = ring_pts((0, y, 0), (0, 1, 0), r, 6)
        return [grod(name, pts[i], pts[(i + 1) % 6], t * 1.4, m, col, seg=4) for i in range(6)]

    def build(col, high):
        obs = [pillar(col, high)]
        cage_r = 0.36
        y0, y1 = 1.58, 2.16
        # a base plate round the lamp's foot, six bars, two rings, a little six-sided roof and a finial
        obs.append(K.cyl("Base Plate", 0.4, 0.05, at=at(0, 1.6, 0), seg=48 if high else 6, m=iron, col=col))
        for i in range(6):
            a = math.tau * (i + 0.5) / 6
            x, z = math.sin(a) * cage_r, math.cos(a) * cage_r
            if high:
                pts = [(x, y0, z), (x * 1.08, (y0 + y1) / 2, z * 1.08), (x, y1, z)]
                obs.append(gwire("Bar", pts, 0.018, iron, col, res=8))
                obs.append(blob("Rivet", 0.025, (x, y1, z), gold, col, seg=8, lump=0.0))
            else:
                obs.append(grod("Bar", (x, y0, z), (x, y1, z), 0.03, iron, col, seg=4))
        for yy in (y0 + 0.04, y1):
            r = ring("Ring", cage_r, yy, 0.02, iron, col, high)
            obs.extend(r if isinstance(r, list) else [r])
        roof = cone("Roof", 0.46, y1, y1 + 0.3, iron, col, seg=6 if not high else 6, rings=1 if not high else 6)
        obs.append(roof)
        if high:
            obs.append(cone("Roof Gold", 0.47, y1 - 0.01, y1 + 0.03, gold, col, seg=6, rings=1))
            obs.append(blob("Finial", 0.06, (0, y1 + 0.34, 0), gold, col, seg=12, lump=0.0))
            obs.append(grod("Spike", (0, y1 + 0.36, 0), (0, y1 + 0.5, 0), 0.015, gold, col, seg=8, r2=0.002))
        else:
            obs.append(grod("Spike", (0, y1 + 0.28, 0), (0, y1 + 0.5, 0), 0.06, gold, col, seg=4, r2=0.01))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ mountain pine
def _tiers():
    return [((2.0 - t * 0.55), 1.6 + t * 1.3) for t in range(3)]   # (radius, bottom) for each tier at size 1


def trail_pine():
    bark = mottled("Pine Trunk", BARK, BARK_DARK, scale=5.0, rough=0.9, bump=0.6, grain=(14.0, 0.3))
    needles = mottled("Pine Fronds", NEEDLE, NEEDLE_LIGHT, scale=9.0, rough=0.85, bump=0.5, third=NEEDLE_DARK,
                      grain=(30.0, 0.5))
    trunk = [(0, y, 0) for y in (0.0, 0.8, 1.6, 2.6, 3.6, 4.6)]
    trunk_r = [0.3, 0.24, 0.2, 0.15, 0.1, 0.05]

    def build(col, high):
        obs = []
        if high:
            tp, tr = finer(trunk, trunk_r, 40)
            obs.append(tube("Trunk", tp, tr, bark, col, seg=24, flutes=8, flute_depth=0.15, twist=0.4, rough=0.08,
                            cap0=False))
            for k in range(4):                                   # roots
                a = k * math.tau / 4 + 0.4
                d = Vector((math.cos(a), 0, math.sin(a)))
                pts = [tuple(d * 0.15 + Vector((0, 0.35, 0))), tuple(d * 0.42 + Vector((0, 0.06, 0))),
                       tuple(d * 0.62 + Vector((0, -0.04, 0)))]
                obs.append(tube("Root", pts, [0.12, 0.07, 0.02], bark, col, seg=10, rough=0.1, seed=k))
        else:
            obs.append(tube("Trunk", trunk, trunk_r, bark, col, seg=6, cap0=False))
        for t, (w, y) in enumerate(_tiers()):
            top = y + 1.8
            if high:
                obs.append(cone("Fronds", w, y, top, needles, col, seg=96, rings=18, star=12, star_depth=0.28,
                                rough=0.05, seed=t, droop=0.22))
                obs.append(cone("Fronds", w * 0.82, y + 0.45, top, needles, col, seg=96, rings=14, star=12,
                                star_depth=0.3, rough=0.05, seed=t + 5, droop=0.18))
                obs.append(cone("Fronds", w * 0.6, y + 0.95, top + 0.05, needles, col, seg=72, rings=10, star=10,
                                star_depth=0.3, rough=0.06, seed=t + 9, droop=0.12))
            else:
                obs.append(cone("Fronds", w * 1.02, y - 0.02, top + 0.06, needles, col, seg=24, rings=3, star=12,
                                star_depth=0.28, droop=0.22))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ prayer flag
def _flag_colour(p, n):
    x, y = p[0], p[1]                                   # -0.225..0.225 across, -0.25..0.25 down
    c = CLOTH
    # the weave, a little uneven
    c = mix(c, (0.82, 0.8, 0.78), 0.25 + 0.25 * math.sin(x * 900.0) * math.sin(y * 900.0))
    c = mix(c, (0.78, 0.76, 0.74), 0.3 * max(0.0, noise.noise(Vector((x * 8, y * 8, 1.0)))))
    ink = (0.5, 0.48, 0.55)
    # a border inset from the edges, under the hem
    bx, by = 0.225 - abs(x), min(0.25 - y - 0.06, y + 0.25)
    if 0.018 < min(bx, by) < 0.03:
        c = mix(c, ink, 0.8)
    # a star with rays in the middle
    s = _star_d(x, y + 0.02, 0.1)
    if s > 0.0:
        c = mix(c, ink, 0.85)
    elif -0.012 < s <= 0.0:
        c = mix(c, (1.0, 1.0, 1.0), 0.6)
    a = math.atan2(x, y + 0.02)
    rr = math.hypot(x, y + 0.02)
    if 0.12 < rr < 0.16 and abs(math.sin(a * 8.0)) < 0.18:
        c = mix(c, ink, 0.7)
    # fraying threads at the bottom
    if y < -0.235 and math.sin(x * 400.0) > 0.2:
        c = mix(c, (0.7, 0.68, 0.66), 0.6)
    # the hem's shadow under the cord
    if y > 0.2:
        c = mix(c, (0.8, 0.78, 0.76), 0.5)
    return c


def prayer_flag():
    cloth = painted("Flag Cloth", rough=0.95, bump=0.15)
    cord = K.mat("Flag Cord", (0.85, 0.8, 0.7), rough=0.9, bump=0.3)
    plain = K.mat("Flag Low", CLOTH, rough=0.95)

    def ripple(p, n):
        x, y = p.x, p.y
        if abs(n.z) < 0.5:
            return 0.0
        return 0.006 * math.sin(x * 22.0 + y * 6.0) + 0.004 * noise.noise(Vector((x * 12, y * 12, 0.5)))

    hi = rounded_block("Flag", (0.45, 0.5, 0.03), 0.012, 60, cloth, HIGH, ripple, _flag_colour)
    hem = gbox("Hem", (0.452, 0.06, 0.036), (0, 0.22, 0), cloth, HIGH, bevel=0.01)
    rope = grod("Cord", (-0.24, 0.22, 0), (0.24, 0.22, 0), 0.012, cord, HIGH, seg=10)
    lo = rounded_block("Flag", (0.45, 0.5, 0.03), 0.01, 2, plain, LOW)
    return [hi, hem, rope], [lo]


# ================================================================ the Star Chest
def chest_carve(p, n):
    x, y, z = p
    d = 0.0
    # each face gets a sunken panel, its edges inset 0.12, above and below the gold band
    if abs(n.z) > 0.7:
        u, v = x, y
        hu = 0.9 - 0.12
    elif abs(n.x) > 0.7:
        u, v = z, y
        hu = 0.6 - 0.12
    else:
        return 0.004 * noise.noise(Vector(p) * 10.0)
    for (v0, v1) in ((-0.38, 0.12), (0.34, 0.42)):
        if abs(u) < hu and v0 < v < v1:
            e = min(hu - abs(u), v - v0, v1 - v)
            d -= 0.02 * min(1.0, e / 0.015)
    # a star in the middle of the long faces' big panels
    if abs(n.z) > 0.7:
        s = _star_d(x, y + 0.13, 0.17)
        if s > 0.0:
            d += 0.02 * min(1.0, s / 0.015)
    d += 0.003 * noise.noise(Vector(p) * 18.0)
    return d


def chest_box():
    stone = painted("Chest Stone", bump=0.35)
    gold = K.mat("Chest Gold", GOLD, rough=0.3, metal=1.0, bump=0.1)
    dark = K.mat("Keyhole", (0.08, 0.07, 0.1), rough=0.8)
    plain = K.mat("Chest Low", CHEST, rough=0.85)
    base = stone_colour(CHEST, 2.0, moss_up=0.95)

    def colour(p, n):
        c = base(p, n)
        if chest_carve(p, Vector(n)) < -0.012:
            c = mix(c, (0.3, 0.28, 0.4), 0.45)
        return c

    def build(col, high):
        obs = []
        if high:
            b = rounded_block("Box", (1.8, 1.0, 1.2), 0.04, 70, stone, col, chest_carve, colour)
        else:
            b = rounded_block("Box", (1.8, 1.0, 1.2), 0.04, 2, plain, col)
        b.location = at(0, 0.5, 0)
        obs.append(b)
        obs.append(gbox("Band", (1.9, 0.14, 1.3), (0, 0.75, 0), gold, col, bevel=0.02 if high else 0.0))
        if high:
            for sx in (-1, 1):
                for sz in (-1, 1):
                    for yy in (0.1, 0.92):
                        obs.append(gbox("Bracket", (0.2, 0.16, 0.03), (sx * 0.8, yy, sz * 0.615), gold, col, bevel=0.008))
                        obs.append(gbox("Bracket", (0.03, 0.16, 0.2), (sx * 0.915, yy, sz * 0.5), gold, col, bevel=0.008))
            for k in range(-4, 5):
                for sz in (-1, 1):
                    obs.append(blob("Rivet", 0.018, (k * 0.2, 0.75, sz * 0.655), gold, col, seg=8, lump=0.0))
            for sz in (-1, 1):
                obs.append(gbox("Lock", (0.22, 0.26, 0.04), (0, 0.72, sz * 0.665), gold, col, bevel=0.01))
                obs.append(gbox("Keyhole", (0.04, 0.09, 0.02), (0, 0.7, sz * 0.685), dark, col))
        else:
            for sz in (-1, 1):
                obs.append(gbox("Lock", (0.22, 0.26, 0.05), (0, 0.72, sz * 0.67), gold, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ Star Bloom
def petal(name, length, width, yaw, tilt, y, m, col, high, curl=0.03):
    nu, nv = (24, 10) if high else (4, 2)
    bm = bmesh.new()
    rows = []
    d = Vector((math.sin(yaw), 0, math.cos(yaw)))
    side = Vector((math.cos(yaw), 0, -math.sin(yaw)))
    for i in range(nu + 1):
        u = i / nu
        w = width * math.sin(math.pi * min(1.0, u ** 0.8)) * (1.0 - 0.6 * u * u) / 2.0
        row = []
        for j in range(nv + 1):
            v = j / nv * 2.0 - 1.0
            p = d * (0.03 + u * length) + side * (v * w)
            p.y = y + tilt * u * length - curl * v * v + (0.004 * noise.noise(p * 40.0) if high else 0.0)
            row.append(bm.verts.new(at(p.x, p.y, p.z)))
        rows.append(row)
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = K._obj(name, bm, m, True, col)
    sol = ob.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = 0.008
    sol.offset = 0.0
    return ob


def star_bloom():
    glow = K.mat("Bloom Petal", BLOOM, rough=0.5, emit=1.0, emit_rgb=BLOOM, bump=0.1)
    heart = K.mat("Bloom Heart", (1.0, 0.95, 0.75), rough=0.4, emit=2.0, emit_rgb=(1.0, 0.95, 0.75))
    leaf = K.mat("Bloom Leaf", (0.3, 0.55, 0.5), rough=0.7, bump=0.2)

    def build(col, high):
        obs = []
        for k in range(5):
            a = math.tau * k / 5
            obs.append(petal("Petal", 0.24, 0.13, a, 0.35, -0.1, glow, col, high))
            obs.append(petal("Petal", 0.15, 0.1, a + math.pi / 5, 0.7, -0.08, glow, col, high))
        for k in range(3):
            a = math.tau * k / 3 + 0.5
            obs.append(petal("Leaf", 0.3, 0.12, a, 0.15, -0.22, leaf, col, high, curl=0.02))
        obs.append(blob("Heart", 0.06, (0, -0.06, 0), heart, col, seg=16 if high else 6, lump=0.1 if high else 0.0))
        obs.append(grod("Stem", (0, -0.25, 0), (0, -0.1, 0), 0.015, leaf, col, seg=8 if high else 4))
        if high:
            for k in range(10):                                 # little stamens round the heart
                a = math.tau * k / 10
                tip = (math.sin(a) * 0.06, -0.01, math.cos(a) * 0.06)
                obs.append(grod("Stamen", (0, -0.07, 0), tip, 0.004, heart, col, seg=6))
                obs.append(blob("Pollen", 0.01, tip, heart, col, seg=6, lump=0.0))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "kerb_stone": (kerb_stone, 512, 0.03, 0.08, True, False),
    "ring_rock": (ring_rock, 1024, 0.12, 0.3, True, False),
    "waystone": (waystone, 1024, 0.03, 0.08, True, False),
    "trail_pine": (trail_pine, 1024, 0.12, 0.3, False, False),
    "prayer_flag": (prayer_flag, 512, 0.02, 0.05, False, False),
    "chest_box": (chest_box, 1024, 0.03, 0.08, True, False),
    "star_bloom": (star_bloom, 512, 0.02, 0.05, False, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao, emit=emit)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

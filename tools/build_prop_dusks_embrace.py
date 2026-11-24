# Dusk's Embrace, the centipede's misty wood behind the old gate (scenes/scary_world/scary_world.tscn, built by
# tools/build_scary_world.gd), built the detailed way (tools/bake_kit.py; 24 Nov 2026, Hayden: "Okay continue baking
# details"). Its crooked trees, hollow log and glowing mushrooms wear Dark Hollow's baked ones
# (tools/build_prop_dark_hollow.py); these are the two pieces only it has. Each HIGH version is baked onto a LOW one,
# which is what the game draws.
#
# Every piece is made in the space of the plain mesh it replaces, so scripts/detail_props.gd dress_dusks_embrace puts
# each one where the old one was and every collision stays the game's. Blender's X is Godot's X, Blender's -Y is
# Godot's +Z and Blender's Z is Godot's Y.
#   path_stone   a stepping stone, centred like the old disc (radius 0.55, 0.12 thick): a worn, flat slab of grey-lilac
#                stone with a lumpy edge, cracks, lichen and moss creeping in from its rim.
#   old_gate     the gate home, in its node's space: two mossy stone pillars (1.4 x 6.5 x 1.6 at x -2.6 and 2.6, from
#                0.5 under the ground) in rough courses with capstones and ivy climbing them, and between them a rusty
#                wrought-iron gate (bars at z 0.6, 4.6 tall) with spear tips, two rails, curls and an arch on top. The
#                game's warm glow, light and sign stay.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_dusks_embrace.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["path_stone", "old_gate"]
KIND = next((a for a in sys.argv if a in KINDS), "path_stone")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

PATH = (0.4, 0.38, 0.45)             # "Path Stone"
PATH_LIGHT = (0.62, 0.59, 0.7)
WALL = (0.32, 0.3, 0.36)             # "Old Wall Stone"
IRON = (0.14, 0.13, 0.16)            # "Gate Iron"
RUST = (0.42, 0.24, 0.16)
LICHEN = (0.62, 0.66, 0.55)
MOSS = (0.2, 0.32, 0.26)
IVY = (0.16, 0.3, 0.22)
IVY_LIGHT = (0.26, 0.42, 0.3)


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




# ================================================================ stepping stone
def path_stone():
    m = painted("Path Slab", bump=0.45)
    plain = K.mat("Path Low", PATH, rough=0.9)

    def colour(p, n):
        # (baked a shade paler than the old flat colour: flat on the ground under dusk light, the old shade read as
        # holes in the moss)
        c = stone_colour(PATH_LIGHT, 2.0, moss_up=2.0)(p, n)
        r = math.hypot(p[0], p[2])
        # moss creeps in from the rim and sits in the cracks
        if r > 0.38 + 0.08 * noise.noise(Vector(p) * 6.0):
            c = mix(c, MOSS, 0.35)
        if crack(p) > 0.0:
            c = mix(c, (0.12, 0.11, 0.14), 0.7)
        return c

    def crack(p):
        q = Vector((p[0], 0, p[2]))
        return 0.012 - abs(noise.noise(q * 2.2 + Vector((3, 1, 0))))

    def build(col, high):
        bm = bmesh.new()
        rings, seg = (24, 96) if high else (3, 14)
        # a flat slab: rings of points out to a lumpy rim, rounded over at the edge, flat underneath
        top = []
        for i in range(rings + 1):
            t = i / rings
            ring = []
            for k in range(seg):
                a = k / seg * math.tau
                rim = 0.55 + 0.06 * noise.noise(Vector((math.cos(a), math.sin(a), 0)) * 1.6 + Vector((5, 0, 0)))
                r = rim * t
                y = 0.06 - 0.05 * t ** 6
                p = Vector((math.cos(a) * r, y, math.sin(a) * r))
                if high:
                    y += 0.006 * noise.noise(p * 8.0) + 0.002 * noise.noise(p * 30.0)
                    if crack(p) > 0.0:
                        y -= 0.008
                ring.append(bm.verts.new(at(p.x, y, p.z)))
            top.append(ring)
        under = [bm.verts.new(at(v.co.x, -0.06, -v.co.y)) for v in top[-1]]
        mid = top[0][0]
        for k in range(seg):
            bm.faces.new((mid, top[1][(k + 1) % seg], top[1][k])) if rings >= 1 else None
        for i in range(1, rings):
            for k in range(seg):
                bm.faces.new((top[i][k], top[i][(k + 1) % seg], top[i + 1][(k + 1) % seg], top[i + 1][k]))
        for k in range(seg):
            bm.faces.new((top[-1][k], top[-1][(k + 1) % seg], under[(k + 1) % seg], under[k]))
        bm.faces.new(list(reversed(under)))
        bmesh.ops.remove_doubles(bm, verts=top[0], dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        if high:
            colour_mesh(bm, colour)
        return [K._obj("Stone", bm, m if high else plain, True, col)]

    return build(HIGH, True), build(LOW, False)


# ================================================================ the old gate
PILLAR_X = 2.6
PILLAR = (1.4, 6.5, 1.6)         # its size; it runs from -0.5 to 6.0
BAR_Z = 0.6
BAR_TOP = 4.6


def old_gate():
    stone = painted("Gate Stone", bump=0.5)
    iron = mottled("Wrought Iron", IRON, RUST, scale=9.0, rough=0.6, metal=0.7, bump=0.3, lo=0.5, hi=0.8)
    ivy = mottled("Ivy", IVY, IVY_LIGHT, scale=14.0, rough=0.7, bump=0.2)
    stone_low = K.mat("Gate Stone Low", WALL, rough=0.95)
    iron_low = K.mat("Gate Iron Low", IRON, rough=0.6, metal=0.7)
    rnd = random.Random(4)

    def build(col, high):
        obs = []
        for side in (-1, 1):
            x0 = side * PILLAR_X
            if high:
                # rough courses of blocks, each a little in or out, with a capstone and a stone ball
                y = -0.5
                k = 0
                while y < 6.0 - 0.01:
                    h = min(rnd.uniform(0.5, 0.75), 6.0 - y)
                    off = rnd.uniform(-0.03, 0.03)
                    sx, sz = PILLAR[0] + off * 2, PILLAR[2] + off * 2
                    obs.append(rounded_block("Course", (sx, h - 0.02, sz), 0.05, 20, stone, col, chisel(1.6, k + side * 9),
                                             stone_colour(WALL, k * 1.7 + side, moss_up=0.6)))
                    obs[-1].location = at(x0, y + h / 2.0, 0)
                    y += h
                    k += 1
                cap = rounded_block("Cap", (PILLAR[0] + 0.24, 0.3, PILLAR[2] + 0.24), 0.06, 20, stone, col,
                                    chisel(1.2, side * 3.0), stone_colour(WALL, 11.0 + side, moss_up=0.5))
                cap.location = at(x0, 6.15, 0)
                obs.append(cap)
                ball = blob("Finial", 0.32, (x0, 6.6, 0), stone, col, seed=side + 3, seg=24, lump=0.08)
                bm = bmesh.new()
                bm.from_mesh(ball.data)
                colour_mesh(bm, stone_colour(WALL, 20.0 + side, moss_up=0.4))
                bm.to_mesh(ball.data)
                obs.append(ball)
                # ivy climbing up the front (+Z, the side that faces into the wood) and over the inner edge
                for v in range(3):
                    vx = x0 + side * rnd.uniform(-0.5, 0.2)
                    pts = []
                    for j in range(14):
                        yy = -0.4 + j * 0.42
                        pts.append((vx + 0.12 * math.sin(j * 1.3 + v), yy, PILLAR[2] / 2 + 0.03))
                    obs.append(gwire("Ivy Stem", pts, 0.02, ivy, col, res=4, bevel_res=2))
                    for (px, py, pz) in pts:
                        for _ in range(3):
                            lx = px + rnd.uniform(-0.18, 0.18)
                            ly = py + rnd.uniform(-0.2, 0.2)
                            leaf = blob("Leaf", rnd.uniform(0.07, 0.11), (lx, ly, pz + 0.03), ivy, col, seed=rnd.randint(0, 99),
                                        seg=8, lump=0.2, squash=(1.0, 1.0, 0.3))
                            obs.append(leaf)
            else:
                b = gbox("Pillar", PILLAR, (x0, 2.75, 0), stone_low, col)
                obs.append(b)
                obs.append(gbox("Cap", (PILLAR[0] + 0.26, 0.32, PILLAR[2] + 0.26), (x0, 6.15, 0), stone_low, col))
                obs.append(blob("Finial", 0.34, (x0, 6.6, 0), stone_low, col, seg=8, lump=0.0))
                # a slab over each front so the ivy bakes onto something
                obs.append(gbox("Ivy Front", (PILLAR[0] + 0.3, 6.4, 0.12), (x0, 2.7, PILLAR[2] / 2 + 0.06), stone_low, col))
        # the iron gate: 7 bars with spear tips, two rails, curls between the rails, an arch with a scroll on top
        m = iron if high else iron_low
        seg = 10 if high else 4
        for k in range(7):
            x = -1.5 + k * 0.5
            obs.append(grod("Bar", (x, 0.0, BAR_Z), (x, BAR_TOP, BAR_Z), 0.05 if high else 0.06, m, col, seg=seg))
            obs.append(cone("Tip", 0.1, BAR_TOP - 0.02, BAR_TOP + 0.28, m, col, seg=4 if high else 4, rings=2, cap=True)
                       if False else grod("Tip", (x, BAR_TOP, BAR_Z), (x, BAR_TOP + 0.28, BAR_Z), 0.1, m, col, seg=4, r2=0.005))
        for y in (0.5, 3.9):
            obs.append(grod("Rail", (-1.8, y, BAR_Z), (1.8, y, BAR_Z), 0.045 if high else 0.055, m, col, seg=seg))
        if high:
            for k in range(6):                         # an S-curl between each pair of bars, under the top rail
                x = -1.25 + k * 0.5
                pts = [(x - 0.2 + 0.2 * math.cos(t), 3.55 + 0.17 * math.sin(t) * (1 if t < math.pi else 1), BAR_Z)
                       for t in [j / 12 * math.tau for j in range(13)]]
                obs.append(gwire("Curl", pts, 0.018, m, col, res=4, bevel_res=3))
            # rust streaks are in the iron's own mottling; rivets where bars cross the rails
            for k in range(7):
                for y in (0.5, 3.9):
                    obs.append(blob("Rivet", 0.04, (-1.5 + k * 0.5, y, BAR_Z + 0.05), m, col, seg=8, lump=0.0))
        # the arch over the gate, from pillar to pillar, with a scroll at the top
        arch = [(-1.9 + 3.8 * t, BAR_TOP + 0.15 + 0.6 * math.sin(math.pi * t), BAR_Z) for t in [j / 16 for j in range(17)]]
        obs.append(gwire("Arch", arch, 0.05 if high else 0.06, m, col, res=4 if high else 2, bevel_res=4 if high else 2))
        if high:
            for s in (-1, 1):
                pts = [(s * (0.35 + 0.22 * math.cos(t) * (1 - t / 14)), BAR_TOP + 0.48 + 0.2 * math.sin(t) * (1 - t / 14), BAR_Z)
                       for t in [j / 10 * 5.5 for j in range(11)]]
                obs.append(gwire("Scroll", pts, 0.022, m, col, res=4, bevel_res=3))
        else:
            obs.append(gbox("Scroll Pad", (1.2, 0.5, 0.06), (0, BAR_TOP + 0.5, BAR_Z), m, col))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "path_stone": (path_stone, 512, 0.02, 0.05, True, False),
    "old_gate": (old_gate, 2048, 0.08, 0.2, True, False),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao, emit=emit)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

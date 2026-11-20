# The Rootmind, Bramble's world, built the detailed way (tools/bake_kit.py; 20 Nov 2026, Hayden: "Then keep baking
# details", the portal worlds' props after the Far Future): its giant stems, their huge leaves, the leaf climb's step
# leaves, the giant flowers' buds and blooms and the root tunnel's arches. Each HIGH version is baked onto a LOW one,
# which is what the game draws.
#
# Sizes match the pieces tools/build_rootmind.gd builds from shapes, so the swap (scripts/detail_props.gd
# dress_rootmind) puts each where the old one was and every collision stays the game's. Blender's X is Godot's X,
# Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   giant_stem   a stem 20 m tall, 1.6 m round at its foot and 0.96 at its top (the game stretches it to each stem's
#                own size): ribbed, with a swollen node every few metres wrapped in a leafy sheath, a rounded crown.
#   giant_leaf   a huge leaf 10 m long and 5.2 wide, like the old squashed ball (5, 0.25, 2.6): a pointed blade along
#                -X with its base at +X, arched along its midrib, its edges drooping and rippled, veins under and over.
#   step_leaf    a leaf of the leaf climb at radius 1 (the game widens it to each leaf's own): a round pad 2.3 by 2,
#                its top at 0.15 (its collision's), a notch where its stalk meets it at -Z and veins out from there.
#   giant_bud    a giant flower's shut bud as a unit ball (the game's Bud stretches it): five wrapped petals with a
#                point at the top, baked pale so each flower keeps its own colour.
#   giant_bloom  a giant flower open, round the middle of its glowing heart: six cupped, veined petals where the old
#                six were and six smaller ones inside them, baked pale too.
#   root_arch    an arch of the root tunnel 3.2 m round (the old torus's): three gnarled roots twisted together, mossy
#                on top, going down into the ground at both ends.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_rootmind.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["giant_stem", "giant_leaf", "step_leaf", "giant_bud", "giant_bloom", "root_arch"]
KIND = next((a for a in sys.argv if a in KINDS), "giant_stem")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

STEM = (0.26, 0.46, 0.2)
STEM_LIGHT = (0.36, 0.57, 0.26)
STEM_DARK = (0.19, 0.35, 0.15)
SHEATH = (0.42, 0.58, 0.26)
LEAF = (0.32, 0.62, 0.22)
LEAF_LIGHT = (0.42, 0.72, 0.28)
LEAF_DARK = (0.23, 0.48, 0.17)
STEP = (0.5, 0.78, 0.22)
STEP_LIGHT = (0.6, 0.85, 0.3)
STEP_DARK = (0.4, 0.66, 0.18)
PALE = (0.97, 0.95, 0.97)
PALE_SHADE = (0.84, 0.8, 0.86)
ROOT = (0.45, 0.32, 0.22)
ROOT_DARK = (0.33, 0.23, 0.16)
MOSS = (0.36, 0.52, 0.22)
STEM_H = 20.0
STEM_R = 1.6
STEM_TOP = 0.96
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




def shell(name, top, bot, nu, nv, m, col):
    """A thin closed sheet (a leaf, a petal): top(u, v) and bot(u, v) give its two faces' Godot points for u and v
    from 0 to 1, and its edges are joined."""
    bm = bmesh.new()
    T = [[bm.verts.new(at(*top(i / nu, j / nv))) for j in range(nv + 1)] for i in range(nu + 1)]
    B = [[bm.verts.new(at(*bot(i / nu, j / nv))) for j in range(nv + 1)] for i in range(nu + 1)]
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((T[i][j], T[i + 1][j], T[i + 1][j + 1], T[i][j + 1]))
            bm.faces.new((B[i][j + 1], B[i + 1][j + 1], B[i + 1][j], B[i][j]))
    for i in range(nu):
        for j in (0, nv):
            bm.faces.new((T[i][j], B[i][j], B[i + 1][j], T[i + 1][j]))
    for j in range(nv):
        for i in (0, nu):
            bm.faces.new((T[i][j], T[i][j + 1], B[i][j + 1], B[i][j]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, True, col)


def _bump(x, w):
    return math.exp(-(x / w) ** 2)


# ================================================================ giant stem
NODES = [3.6, 8.2, 12.4, 16.2, 19.2]


def _stem_r(y):
    r = STEM_R + (STEM_TOP - STEM_R) * min(y, STEM_H) / STEM_H
    return r * (1.0 + sum(0.07 * _bump(y - n, 0.35) for n in NODES))


def giant_stem():
    stem = mottled("Stem", STEM, STEM_LIGHT, scale=3.0, rough=0.7, bump=0.35, third=STEM_DARK, grain=(26.0, 0.35))
    sheath = mottled("Sheath", SHEATH, STEM_LIGHT, scale=5.0, rough=0.75, bump=0.3, grain=(40.0, 0.45))
    crown_y = [STEM_H + d for d in (0.0, 0.25, 0.5, 0.7, 0.82)]
    crown_r = [STEM_TOP, STEM_TOP * 0.9, STEM_TOP * 0.66, STEM_TOP * 0.33, 0.02]

    def build(col, high):
        obs = []
        if high:
            ys = [k * STEM_H / 240 for k in range(241)]
            pts = [(0, y, 0) for y in ys] + [(0, y, 0) for y in crown_y[1:]]
            rs = [_stem_r(y) for y in ys] + crown_r[1:]
            obs.append(tube("Stem", pts, rs, stem, col, seg=64, flutes=16, flute_depth=0.06, twist=0.02, rough=0.025,
                            cap0=False))
            for i, n in enumerate(NODES):
                # a leafy sheath hugging the stem above each node, its top edge in scallops
                r0 = _stem_r(n) * 1.02
                for k in range(5):
                    a = k * math.tau / 5 + i * 0.7
                    obs.append(_sheath(k, n, r0, a, sheath, col))
        else:
            ys = [0.0] + sorted(set([y for n in NODES for y in (n - 0.6, n, n + 0.6)])) + [STEM_H]
            pts = [(0, y, 0) for y in ys] + [(0, y, 0) for y in crown_y[1:]]
            rs = [_stem_r(y) * 1.03 for y in ys] + [r * 1.03 for r in crown_r[1:]]
            obs.append(tube("Stem", pts, rs, stem, col, seg=14, cap0=False))
        return obs

    return build(HIGH, True), build(LOW, False)


def _sheath(k, y0, r0, a, m, col):
    """One leaf of a node's sheath: a strip of the stem's skin from y0 up 1.1 m, a fifth of the way round and a little
    more, standing just off the stem and pointed at its top."""
    span = math.tau / 5 * 1.25

    def pt(u, v, out):
        y = y0 - 0.1 + u * 1.1
        w = (1.0 - u ** 1.6)
        ang = a + (v - 0.5) * span * w
        r = _stem_r(y) * 1.015 + 0.012 + out + 0.03 * u
        return (math.cos(ang) * r, y, math.sin(ang) * r)

    return shell("Sheath", lambda u, v: pt(u, v, 0.022), lambda u, v: pt(u, v, 0.0), 10, 12, m, col)


# ================================================================ giant leaf
def _leaf_w(u, wmax):
    raw = (u ** 0.55) * ((1 - u) ** 0.85)
    peak = (0.55 / 1.4) ** 0.55 * (0.85 / 1.4) ** 0.85
    return max(wmax * raw / peak, 0.004)


def giant_leaf():
    leaf = mottled("Leaf", LEAF, LEAF_LIGHT, scale=1.4, rough=0.55, bump=0.25, third=LEAF_DARK, grain=(10.0, 0.2))

    def vein(u, v, w):
        s = _bump(v * w, 0.09) * 1.6
        for k in range(14):
            u0 = 0.05 + k * 0.066
            s += _bump(u - (u0 + 0.16 * abs(v)), 0.008) * (1 - abs(v)) ** 0.5
        return s

    def surf(u, v, side, high):
        v = v * 2 - 1
        x = 5.0 - 10.0 * u
        w = _leaf_w(u, 2.6)
        z = v * w
        y = 0.18 * math.sin(math.pi * u) - 0.32 * v * v * (w / 2.6)
        t = 0.025 + 0.1 * (1 - v * v) * math.sin(math.pi * u) ** 0.5
        if high:
            y += 0.06 * math.sin(u * 46 + v * 3) * abs(v) ** 4
            vv = vein(u, v, w)
            t += (0.035 * vv) if side < 0 else (-0.012 * vv)
        return (x, y + side * t, z)

    def build(col, high):
        nu, nv = (220, 90) if high else (22, 8)
        return [shell("Leaf", lambda u, v: surf(u, v, 1, high), lambda u, v: surf(u, v, -1, high), nu, nv, leaf, col)]

    return build(HIGH, True), build(LOW, False)


# ================================================================ step leaf
def step_leaf():
    leaf = mottled("Step Leaf", STEP, STEP_LIGHT, scale=2.5, rough=0.55, bump=0.3, third=STEP_DARK, grain=(18.0, 0.2))

    def surf(u, v, side, high):
        # along Z from the stalk's notch (-Z) to the tip (+Z), across X; its top stays flat to stand on
        v = v * 2 - 1
        z = -1.0 + 2.0 * u
        w = 1.15 * max(math.sin(math.pi * u), 0.0) ** 0.5 * (1.0 - 0.22 * _bump(u, 0.12))
        w = max(w, 0.004)
        x = v * w
        y = 0.11 + 0.05 * abs(v) ** 3
        t = 0.04 + 0.06 * (1 - v * v)
        if high:
            ang = math.atan2(x, z + 1.0)
            vv = _bump(math.sin(ang * 9.0), 0.08) * min(1.0, (z + 1.0) * 0.8) + _bump(x, 0.04)
            y += 0.02 * math.sin(u * 30) * abs(v) ** 6
            if side > 0:
                y -= 0.012 * vv
            else:
                y -= 0.02 * vv
        top = y + 0.04
        return (x, top if side > 0 else top - 2 * t - 0.04, z)

    def build(col, high):
        nu, nv = (120, 90) if high else (14, 10)
        return [shell("Step Leaf", lambda u, v: surf(u, v, 1, high), lambda u, v: surf(u, v, -1, high), nu, nv, leaf,
                      col)]

    return build(HIGH, True), build(LOW, False)


# ================================================================ giant bud
def _bud_r(y):
    s = (y + 1.0) / 2.08
    s = min(max(s, 0.0), 1.0)
    return 1.02 * math.sin(math.pi * s) ** 0.75 * (1.0 - 0.28 * s) / 0.86


def giant_bud():
    petal = mottled("Bud", PALE, PALE_SHADE, scale=3.0, rough=0.5, bump=0.2, grain=(22.0, 0.25))

    def build(col, high):
        obs = []
        if high:
            for k in range(5):
                a0 = k * math.tau / 5 + 0.3
                grow = 1.0 + 0.025 * k

                def surf(u, v, side, a0=a0, grow=grow, k=k):
                    y = -1.0 + 2.08 * u
                    span = 1.55 * (1 - 0.6 * u ** 3)
                    ang = a0 + (v - 0.5) * span
                    edge = abs(v - 0.5) * 2
                    r = _bud_r(y) * grow * (1 + 0.035 * edge ** 3) - 0.008 * _bump(math.sin((v - 0.5) * 30), 0.3)
                    r += 0.02 * k / 4
                    if side < 0:
                        r -= 0.03
                    return (math.cos(ang) * r, y, math.sin(ang) * r)

                obs.append(shell("Petal", lambda u, v, s=surf: s(u, v, 1), lambda u, v, s=surf: s(u, v, -1), 60, 40,
                                 petal, col))
        else:
            ys = [-1.0 + 2.08 * k / 14 for k in range(15)]
            obs.append(tube("Bud", [(0, y, 0) for y in ys], [_bud_r(y) * 1.1 + 0.03 for y in ys], petal, col, seg=16))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ giant bloom
def _place(p, centre, yaw, tilt):
    """A petal's point p (its own x along the petal, y up) turned the game's way: Rz(tilt), then Ry(yaw), then moved."""
    x, y, z = p
    x, y = x * math.cos(tilt) - y * math.sin(tilt), x * math.sin(tilt) + y * math.cos(tilt)
    x, z = x * math.cos(yaw) + z * math.sin(yaw), -x * math.sin(yaw) + z * math.cos(yaw)
    return (x + centre[0], y + centre[1], z + centre[2])


def giant_bloom():
    petal = mottled("Bloom", PALE, PALE_SHADE, scale=2.2, rough=0.5, bump=0.2, grain=(16.0, 0.2))
    rings = [(6, 0.0, 1.4, 0.3, 0.5, 1.6, 0.9), (6, math.pi / 6, 0.95, 0.5, 0.95, 1.05, 0.62)]

    def petal_pt(u, v, side, half, wmax, high, seed):
        v = v * 2 - 1
        x = -half + 2 * half * u
        w = max(wmax * math.sin(math.pi * u) ** 0.55 * (0.62 + 0.38 * u) / 0.86, 0.004)
        z = v * w
        y = 0.28 * v * v * (w / wmax) - 0.1 * math.sin(math.pi * u) + 0.06 * u
        t = 0.025 + 0.025 * (1 - v * v)
        if high:
            y += 0.035 * math.sin(u * 13 + seed) * abs(v) ** 3 + 0.04 * math.sin(v * 9 + seed) * u ** 6
            y -= 0.01 * _bump(math.sin(v * w * 16.0), 0.35) * math.sin(math.pi * u)
        return (x, y + (t if side > 0 else -t), z)

    def build(col, high):
        obs = []
        for (n, off, d, h, tilt, half, wmax) in rings:
            for j in range(n):
                pa = j * math.tau / n + off
                c = (math.cos(pa) * d, h, math.sin(pa) * d)

                def f(u, v, side, c=c, pa=pa, half=half, wmax=wmax, j=j):
                    return _place(petal_pt(u, v, side, half, wmax, high, j * 1.7), c, -pa, tilt)

                nu, nv = (90, 50) if high else (10, 6)
                obs.append(shell("Petal", lambda u, v, f=f: f(u, v, 1), lambda u, v, f=f: f(u, v, -1), nu, nv, petal,
                                 col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ root arch
def _arch_pt(t, r=3.2):
    return Vector((math.cos(t) * r, math.sin(t) * r, 0.0))


def root_arch():
    bark = mossy("Root Arch", ROOT, ROOT_DARK, MOSS, scale=3.0, rough=0.9, bump=0.6, grain=(9.0, 0.35), up=0.5)
    t0, t1 = -0.28, math.pi + 0.28

    def build(col, high):
        obs = []
        n = 140 if high else 22
        ts = [t0 + (t1 - t0) * k / (n - 1) for k in range(n)]
        if high:
            for s in range(3):
                pts, rs = [], []
                for t in ts:
                    c = _arch_pt(t)
                    nrm = Vector((math.cos(t), math.sin(t), 0.0))
                    psi = t * 3.2 + s * math.tau / 3
                    p = c + nrm * (0.15 * math.cos(psi)) + Vector((0, 0, 0.15 * math.sin(psi)))
                    pts.append(tuple(p))
                    rs.append(0.19 + 0.03 * math.sin(t * 7 + s) + 0.05 * _bump(t - (0.6 + s * 0.9), 0.08))
                obs.append(tube("Root", pts, rs, bark, col, seg=18, rough=0.14, seed=s, cap0=False, cap1=False))
            rnd = random.Random(3)
            for k in range(10):                                 # knots and little stubs
                t = rnd.uniform(0.15, math.pi - 0.15)
                c = _arch_pt(t, 3.2 + rnd.choice((-1, 1)) * 0.22)
                obs.append(blob("Knot", rnd.uniform(0.09, 0.14), tuple(c), bark, col, seed=k, seg=10, lump=0.3,
                                squash=(1.0, 1.0, 1.3)))
        else:
            obs.append(tube("Root", [tuple(_arch_pt(t)) for t in ts], [0.37] * n, bark, col, seg=10, cap0=False,
                            cap1=False))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao = {
    "giant_stem": (giant_stem, 1024, 0.12, 0.3, True),
    # no AO on the thin sheets: their two faces and the petals over each other shadowed them nearly black
    "giant_leaf": (giant_leaf, 1024, 0.08, 0.2, False),
    "step_leaf": (step_leaf, 512, 0.06, 0.15, False),
    "giant_bud": (giant_bud, 512, 0.08, 0.2, False),
    "giant_bloom": (giant_bloom, 1024, 0.07, 0.18, False),
    "root_arch": (root_arch, 512, 0.15, 0.35, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

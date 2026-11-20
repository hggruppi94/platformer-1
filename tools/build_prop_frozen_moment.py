# The Frozen Moment, Flurry's world, built the detailed way (tools/bake_kit.py; 20 Nov 2026, Hayden: "Then keep
# baking details", the portal worlds' props after Lanternmoor): its snowy pines, the ice crags round the bowl and the
# Frost Gloop's throne. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces tools/build_frozen_moment.gd builds from shapes, so the swap (scripts/detail_props.gd
# dress_frozen_moment) puts each where the old one was and every collision stays the game's. Blender's X is Godot's
# X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   snow_pine     a pine at size 1, 6 m tall: a ridged trunk and three tiers of drooping needle fronds, every tier
#                 heaped with snow, a snowy tip (the old tiers were plain cones with a snow cone on each).
#   ice_crag      an ice crag 2 m across and 5 m tall (the game stretches it to each crag's own size): a faceted
#                 spire of blue ice with cracks, chips and two little shards at its foot, snow draped over its top.
#   frost_throne  the Frost Gloop's dais: a round step of packed ice 9.2 m across with its top at 0.6 m (its
#                 collision's), a frost-carved snowflake on top, a rim of carved scallops and nine clusters of ice
#                 crystals round its edge.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_frozen_moment.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["snow_pine", "ice_crag", "frost_throne"]
KIND = next((a for a in sys.argv if a in KINDS), "snow_pine")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

BARK = (0.35, 0.26, 0.22)
BARK_DARK = (0.2, 0.14, 0.12)
NEEDLE = (0.2, 0.42, 0.38)
NEEDLE_DARK = (0.1, 0.26, 0.24)
NEEDLE_LIGHT = (0.3, 0.52, 0.44)
SNOW = (0.92, 0.94, 1.0)
SNOW_BLUE = (0.78, 0.84, 0.96)
ICE = (0.7, 0.82, 0.95)
ICE_DEEP = (0.45, 0.62, 0.88)
ICE_PALE = (0.86, 0.93, 1.0)
THRONE = (0.62, 0.8, 0.98)


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


# ================================================================ snowy pine
def _tiers():
    return [((2.0 - t * 0.55), 1.6 + t * 1.3) for t in range(3)]   # (radius, bottom) for each tier at size 1


def snow_pine():
    bark = mottled("Pine Trunk", BARK, BARK_DARK, scale=5.0, rough=0.9, bump=0.6, grain=(14.0, 0.3))
    needles = mottled("Pine Fronds", NEEDLE, NEEDLE_LIGHT, scale=9.0, rough=0.85, bump=0.5, third=NEEDLE_DARK,
                      grain=(30.0, 0.5))
    snow = mottled("Pine Snow", SNOW, SNOW_BLUE, scale=4.0, rough=0.9, bump=0.25, lo=0.45, hi=0.7)
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
                # two layers of pleated fronds, the lower one wider and drooping, and snow heaped on the upper half
                obs.append(cone("Fronds", w, y, top, needles, col, seg=96, rings=18, star=12, star_depth=0.28,
                                rough=0.05, seed=t, droop=0.22))
                obs.append(cone("Fronds", w * 0.82, y + 0.45, top, needles, col, seg=96, rings=14, star=12,
                                star_depth=0.3, rough=0.05, seed=t + 5, droop=0.18))
                sw = w * 0.62
                obs.append(cone("Snow", sw, y + 1.05, top + 0.08, snow, col, seg=64, rings=10, rough=0.12, seed=t + 9,
                                ripple=9, ripple_depth=0.18))
                rnd = random.Random(t)
                for k in range(12):                              # snow clumps on the frond tips
                    a = (k + 0.5) * math.tau / 12 + rnd.uniform(-0.05, 0.05)
                    rr = w * rnd.uniform(0.62, 0.86)
                    yy = y + 1.8 * (1 - rr / w) + 0.08
                    obs.append(blob("Clump", rnd.uniform(0.1, 0.16), (math.cos(a) * rr, yy, math.sin(a) * rr), snow,
                                    col, seed=k + t * 20, seg=10, lump=0.3, squash=(1.3, 0.55, 1.0)))
            else:
                # the same pleats and droop as the high fronds (two points per pleat), so every ray finds them
                obs.append(cone("Fronds", w * 1.02, y - 0.02, top + 0.02, needles, col, seg=24, rings=3, star=12,
                                star_depth=0.28, droop=0.22))
                obs.append(cone("Snow", w * 0.64, y + 1.02, top + 0.1, snow, col, seg=18, rings=2, cap=True, ripple=9,
                                ripple_depth=0.18))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ ice crag
def ice_crag():
    ice = mottled("Crag Body", ICE, ICE_DEEP, scale=2.5, rough=0.45, bump=0.4, third=ICE_PALE, lo=0.4, hi=0.75)
    snow = mottled("Crag Cap", SNOW, SNOW_BLUE, scale=5.0, rough=0.9, bump=0.25)
    shards = [((0.95, 0.0, 0.35), 0.38, 1.3, (0.35, 0, -0.25)), ((-0.55, 0.0, 0.85), 0.3, 1.0, (-0.3, 0, 0.35))]

    def facet(name, r, h, m, col, seg, rings, seed, chip):
        ob = cone(name, r, 0.0, h, m, col, seg=seg, rings=rings, rough=0.0, seed=seed)
        if chip:
            # chip it into flat facets: snap each point's radius to a few planes picked by a coarse noise
            for v in ob.data.vertices:
                p = Vector((v.co.x, v.co.z, -v.co.y))
                rr = Vector((p.x, 0, p.z)).length
                if rr < 1e-4 or p.y < 0.01:
                    continue
                n = noise.noise(Vector((p.x * 1.4, p.y * 0.55, p.z * 1.4)) + Vector((seed * 3.0, 0, 0)))
                k = 1.0 + chip * round(n * 4) / 4
                v.co.x *= k
                v.co.y *= k
        return ob

    def build(col, high):
        obs = [facet("Spire", 1.0, 5.0, ice, col, 56 if high else 7, 40 if high else 4, 1, 0.16 if high else 0.0)]
        if high:
            rnd = random.Random(4)
            for k in range(10):                                  # cracks: thin pale seams across the faces
                a = rnd.uniform(0, math.tau)
                y = rnd.uniform(0.4, 3.2)
                rr = 1.0 * (1 - y / 5.0) * 1.0
                q = Vector((math.cos(a), 0, math.sin(a)))
                t = Vector((-q.z, 0, q.x))
                pts = [tuple(q * (rr + 0.01) + t * (j - 2) * 0.12 + Vector((0, y + (j - 2) * rnd.uniform(-0.1, 0.1), 0)))
                       for j in range(5)]
                obs.append(gwire("Crack", pts, 0.012, ice, col, res=4, bevel_res=1))
        for i, (p, r, h, lean) in enumerate(shards):
            s = facet("Shard", r, h, ice, col, 24 if high else 5, 10 if high else 1, i + 7, 0.12 if high else 0.0)
            s.location = at(*p)
            s.rotation_euler = (lean[0], -lean[2], 0)
            obs.append(s)
        # snow draped over the top: a lumpy cap that hangs a little lower on one side
        if high:
            # it starts just wider than the spire there, so it reads as snow lying on it, not a hat
            cap = cone("Snow", 0.44, 3.0, 5.04, snow, col, seg=48, rings=12, rough=0.08, seed=3, ripple=7,
                       ripple_depth=0.08)
            obs.append(cap)
        # the low spire has no cap of its own: the snow bakes straight onto it, so there's no ledge
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ frost throne
def frost_throne():
    ice = mottled("Throne Body", THRONE, ICE_DEEP, scale=1.5, rough=0.4, bump=0.35, third=ICE_PALE)
    frost = K.mat("Throne Frost", (0.9, 0.96, 1.0), rough=0.7)
    crystal = mottled("Throne Crystal", ICE_PALE, ICE, scale=4.0, rough=0.35, bump=0.2)
    prof = [(0.0, 0.0), (4.6, 0.0), (4.62, 0.08), (4.5, 0.2), (4.45, 0.42), (4.3, 0.52), (4.22, 0.6), (0.0, 0.6)]

    def build(col, high):
        obs = [K.lathe("Dais", prof, seg=96 if high else 32, m=ice, col=col, flutes=36 if high else 0,
                       flute_depth=0.02, flute_z=(0.1, 0.45))]
        if high:
            # a snowflake carved in frost on top: six arms with side branches, in a ring
            for k in range(6):
                a = k * math.tau / 6
                q = Vector((math.cos(a), 0, math.sin(a)))
                t = Vector((-q.z, 0, q.x))
                y = 0.61
                obs.append(gwire("Arm", [tuple(q * 0.3 + Vector((0, y, 0))), tuple(q * 3.0 + Vector((0, y, 0)))],
                                 0.05, frost, col, res=2, bevel_res=2))
                for d, l in ((1.1, 0.55), (1.9, 0.45), (2.5, 0.3)):
                    c = q * d + Vector((0, y, 0))
                    for s in (-1, 1):
                        e = c + (q * 0.6 + t * s).normalized() * l
                        obs.append(gwire("Twig", [tuple(c), tuple(e)], 0.035, frost, col, res=2, bevel_res=2))
            obs.append(gwire("Ring", ring_pts((0, 0.61, 0), (0, 1, 0), 3.4, 96), 0.04, frost, col, closed=True,
                             res=2, bevel_res=2))
            obs.append(gwire("Ring", ring_pts((0, 0.61, 0), (0, 1, 0), 0.3, 24), 0.04, frost, col, closed=True,
                             res=2, bevel_res=2))
        # nine clusters of crystals round the edge, the middle one 1.4, 2.1 or 2.8 tall like the old spikes
        for k in range(9):
            a = k * math.tau / 9
            q = Vector((math.cos(a), 0, math.sin(a)))
            t = Vector((-q.z, 0, q.x))
            h = 1.4 + (k % 3) * 0.7
            base = q * 4.0 + Vector((0, 0.55, 0))
            pieces = [(Vector(), h, 0.35, 0.0, 0.0)]
            if True:
                rnd = random.Random(k)
                for j in range(4):
                    s = rnd.choice((-1, 1))
                    pieces.append((t * s * rnd.uniform(0.25, 0.4) + q * rnd.uniform(-0.2, 0.2), h * rnd.uniform(0.35, 0.6),
                                   0.16, s * rnd.uniform(0.25, 0.5), rnd.uniform(-0.3, 0.3)))
            for i, (off, ph, pr, tilt, lean) in enumerate(pieces):
                seg = 6
                c = cone("Crystal", pr * (1.0 if high else 1.06), 0.0, ph * (1.0 if high else 1.02), crystal, col,
                         seg=seg, rings=2 if high else 1)
                p = base + off
                c.location = at(*p)
                ang = math.atan2(q.z, q.x)
                c.rotation_euler = (lean, tilt, -ang)
                obs.append(c)
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao = {
    # no AO: the overlapping cones and shells shadowed each other nearly black
    "snow_pine": (snow_pine, 1024, 0.12, 0.3, False),
    "ice_crag": (ice_crag, 1024, 0.25, 0.5, False),
    "frost_throne": (frost_throne, 1024, 0.1, 0.25, False),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

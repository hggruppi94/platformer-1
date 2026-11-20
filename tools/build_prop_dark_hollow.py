# Dark Hollow, the centipede's world, built the detailed way (tools/bake_kit.py; 20 Nov 2026, Hayden: "Then keep
# baking details", the portal worlds' props after the Tide Reef): its crooked trees, the centipede's hollow log, the
# moon lamps round Hush Hill (and the little lamps along the old run) and its clusters of glowing mushrooms. Each HIGH
# version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces tools/build_dark_hollow.gd builds from shapes, so the swap (scripts/detail_props.gd
# dress_dark_hollow, and dark_hollow.gd moon_lamp_model) puts each where the old one was and every collision stays the
# game's. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   crooked_tree    a bare, gnarled tree 3.9 m tall at size 1: a twisting trunk in furrowed bark with a knot hole and
#                   pale lichen, roots gripping the ground, and spidery branches that bend and droop. Spooky, not scary.
#   hollow_log      the centipede's home: a great log 6 m long and 2.6 across lying along X, open at its +X end into a
#                   dark hollow, sawn at the other with its rings, moss over the top, shelf fungus and glowing
#                   mushrooms (baked to glow).
#   moon_lamp       a moon lamp's iron post 3.3 m tall: claw feet, a twisted shaft with collars, a cage that holds the
#                   game's own glass globe (0.35 across, its middle 2.6 up) and a pointed cap with a crescent moon.
#   glow_mushrooms  a cluster of three mushrooms: warty caps with spots and gills underneath (one part, "Caps", baked
#                   pale and glowing: the game tints and lights it in the cluster's own colour) and their pale stalks
#                   with skirts ("Stalks").
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_dark_hollow.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["crooked_tree", "hollow_log", "moon_lamp", "glow_mushrooms"]
KIND = next((a for a in sys.argv if a in KINDS), "crooked_tree")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

BARK = (0.2, 0.15, 0.22)
BARK_DARK = (0.09, 0.07, 0.11)
LICHEN = (0.45, 0.5, 0.55)
LOG_BARK = (0.3, 0.21, 0.22)
LOG_DARK = (0.14, 0.09, 0.1)
WOOD_END = (0.55, 0.42, 0.36)
MOSS = (0.2, 0.32, 0.26)
INSIDE = (0.06, 0.04, 0.06)
FUNGUS = (0.72, 0.62, 0.55)
TEAL = (0.4, 1.0, 0.9)
IRON = (0.2, 0.18, 0.28)
IRON_LIGHT = (0.32, 0.3, 0.42)
VERDIGRIS = (0.28, 0.5, 0.48)
MOON = (0.9, 0.88, 0.7)
CAP = (0.96, 0.95, 0.93)
SPOT = (1.0, 1.0, 1.0)
GILL = (0.8, 0.78, 0.76)
STALK = (0.78, 0.78, 0.86)

TREE_H = 3.9
LAMP_GLOBE_Y = 2.6
LAMP_GLOBE_R = 0.35


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


# ================================================================ crooked tree
def _tree_plan():
    """The tree's shape, the same for HIGH and LOW (the bake goes black where they differ)."""
    rnd = random.Random(7)
    trunk = []
    for k in range(12):
        t = k / 11
        y = t * 3.0
        trunk.append((0.22 * math.sin(t * 2.6) + 0.12 * t, y, 0.15 * math.sin(t * 3.4 + 1.0)))
    trunk_r = [0.42 - 0.3 * (k / 11) ** 0.8 for k in range(12)]
    trunk_r[0] = 0.55
    limbs = []
    # two leaders at the fork, then spidery branches round the upper trunk
    for k in range(9):
        a = k * 2.4 + rnd.uniform(-0.3, 0.3)
        i = 5 + (k * 6) // 9
        base = Vector(trunk[i])
        length = rnd.uniform(1.0, 1.7) * (1.15 if k < 2 else 1.0)
        d = Vector((math.cos(a), rnd.uniform(0.35, 0.9), math.sin(a))).normalized()
        tip = base + d * length
        bend = Vector((0, -rnd.uniform(0.15, 0.4), 0)) + Vector((-math.sin(a), 0, math.cos(a))) * rnd.uniform(-0.25, 0.25)
        pts = curve(base, tip, bend, 6)
        r0 = trunk_r[i] * 0.55
        radii = [r0 * (1.0 - 0.8 * j / 5) for j in range(6)]
        limbs.append((pts, radii))
        # a twig or two off each, curling up at the end
        for j in range(rnd.randint(1, 2)):
            s = Vector(pts[3 + j])
            a2 = a + rnd.choice((-1, 1)) * rnd.uniform(0.6, 1.1)
            d2 = Vector((math.cos(a2), rnd.uniform(0.2, 0.8), math.sin(a2))).normalized()
            t2 = s + d2 * rnd.uniform(0.45, 0.8)
            tp = curve(s, t2, (0, 0.12, 0), 4)
            rr = radii[3 + j] * 0.7
            limbs.append((tp, [rr, rr * 0.7, rr * 0.45, rr * 0.2]))
    # the top: the trunk carries on as a thin crooked leader
    top = Vector(trunk[-1])
    tp = curve(top, top + Vector((0.35, 0.9, -0.2)), (-0.15, 0, 0.1), 5)
    limbs.append((tp, [trunk_r[-1], trunk_r[-1] * 0.7, trunk_r[-1] * 0.5, 0.04, 0.015]))
    roots = []
    for k in range(6):
        a = k * math.tau / 6 + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        pts = [tuple(d * 0.25 + Vector((0, 0.45, 0))), tuple(d * 0.6 + Vector((0, 0.15, 0))),
               tuple(d * 1.0 + Vector((0, 0.0, 0))), tuple(d * rnd.uniform(1.3, 1.6) + Vector((0, -0.1, 0)))]
        roots.append((pts, [0.2, 0.14, 0.08, 0.03]))
    return trunk, trunk_r, limbs, roots


def crooked_tree():
    bark = mottled("Crooked Bark", BARK, BARK_DARK, scale=5.0, rough=0.92, bump=0.6, lo=0.4, hi=0.65, third=LICHEN)
    hole = K.mat("Knot Hole", INSIDE, rough=1.0)
    trunk, trunk_r, limbs, roots = _tree_plan()

    def build(col, high):
        obs = []
        if high:
            tp, tr = finer(trunk, trunk_r, 70)
            obs.append(tube("Trunk", tp, tr, bark, col, seg=40, flutes=11, flute_depth=0.14, twist=1.3,
                            rough=0.12, cap0=False))
            for i, (pts, rr) in enumerate(limbs):
                pts, rr = finer(pts, rr, 24)
                obs.append(tube("Limb", pts, rr, bark, col, seg=12, flutes=5, flute_depth=0.12, twist=2.0,
                                rough=0.1, seed=i + 1))
            for i, (pts, rr) in enumerate(roots):
                pts, rr = finer(pts, rr, 16)
                obs.append(tube("Root", pts, rr, bark, col, seg=14, flutes=4, flute_depth=0.1, rough=0.15,
                                seed=i + 20))
            # a knot hole low on the trunk, with a lip of bark round it
            p = Vector(trunk[3])
            n = Vector((0, 0, 1))
            c = p + n * (trunk_r[3] * 0.82)
            obs.append(blob("Hole", 0.16, tuple(c + n * 0.02), hole, col, seg=12, lump=0.1, squash=(0.8, 1.2, 0.4)))
            obs.append(gwire("Lip", ring_pts(tuple(c + n * 0.03), n, 0.17, 12), 0.04, bark, col, closed=True,
                             res=6))
            # burls and a few broken stubs
            rnd = random.Random(11)
            for k in range(5):
                i = rnd.randint(2, 9)
                a = rnd.uniform(0, math.tau)
                q = Vector((math.cos(a), 0, math.sin(a)))
                obs.append(blob("Burl", rnd.uniform(0.08, 0.14), tuple(Vector(trunk[i]) + q * trunk_r[i] * 0.85),
                                bark, col, seed=k, seg=10, lump=0.35, squash=(1.0, 1.3, 1.0)))
        else:
            obs.append(tube("Trunk", trunk, trunk_r, bark, col, seg=9, cap0=False))
            for pts, rr in limbs:
                obs.append(tube("Limb", pts, rr, bark, col, seg=5))
            for pts, rr in roots:
                obs.append(tube("Root", pts, rr, bark, col, seg=6))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the centipede's hollow log
LOG_R = 1.3
LOG_Y = 1.2
LOG_HALF = 3.0
LOG_IN = 1.0


def hollow_log():
    bark = mossy("Log Bark", LOG_BARK, LOG_DARK, MOSS, scale=3.0, bump=0.6, up=0.35)
    end = K.mat("Sawn End", WOOD_END, rough=0.85, grain=(14.0, 0.35))
    inside = mottled("Log Inside", INSIDE, (0.14, 0.09, 0.1), scale=3.0, rough=1.0, bump=0.4)
    fungus = mottled("Shelf Fungus", FUNGUS, (0.5, 0.38, 0.34), scale=8.0, rough=0.7, bump=0.3)
    glow = K.mat("Log Mushroom", TEAL, rough=0.5, emit=2.0)
    stalk = K.mat("Log Stalk", STALK, rough=0.8)
    xs = [-LOG_HALF + k * (2 * LOG_HALF) / 7 for k in range(8)]
    sag = [0.05 * math.sin(k * 1.3) for k in range(8)]

    def build(col, high):
        obs = []
        seg = 48 if high else 16
        pts = [(x, LOG_Y + s, 0.06 * math.sin(x)) for x, s in zip(xs, sag)]
        rr = [LOG_R * (1.0 - 0.03 * math.sin(k * 2.1)) for k in range(8)]
        lp_, lr_ = finer(pts, rr, 50) if high else (pts, rr)
        obs.append(tube("Log", lp_, lr_, bark, col, seg=seg, flutes=16 if high else 0, flute_depth=0.06,
                        twist=0.15, rough=0.04 if high else 0.0, cap0=False, cap1=False))
        # the sawn end (-X) with its rings, and the open end (+X): a lip of wood round the dark hollow inside
        e0 = Vector(pts[0])
        obs.append(K.cyl("End", rr[0] * 0.99, 0.04, at=at(e0.x + 0.01, e0.y, e0.z), seg=seg, m=end, col=col,
                         rot=(0, math.pi / 2, 0)))
        e1 = Vector(pts[-1])
        lip = bmesh.new()
        outer, inner = [], []
        for k in range(seg):
            a = k / seg * math.tau
            q = Vector((0, math.cos(a), math.sin(a)))
            outer.append(lip.verts.new(Vector(at(*e1)) + Vector((0, q.y, q.z)) * rr[-1]))
            inner.append(lip.verts.new(Vector(at(*e1)) + Vector((0, q.y, q.z)) * LOG_IN))
        for k in range(seg):
            lip.faces.new((outer[k], outer[(k + 1) % seg], inner[(k + 1) % seg], inner[k]))
        lp = K._obj("Lip", lip, end, True, col)
        obs.append(lp)
        ip = [(e1.x - t * 1.8, e1.y, e1.z) for t in (0.0, 0.5, 1.0)]
        obs.append(tube("Hollow", ip, [LOG_IN] * 3, inside, col, seg=seg // 2 if not high else 32, cap0=False,
                        cap1=True, inward=True))
        if high:
            # rings on the sawn end
            for k in range(1, 9):
                obs.append(gwire("Ring", ring_pts((e0.x - 0.012, e0.y, e0.z), (1, 0, 0), LOG_R * k / 9.5, 24),
                                 0.006, K.mat("Ring", (0.42, 0.3, 0.26), rough=0.9), col, closed=True, res=4,
                                 bevel_res=1))
            # shelf fungus up one side, a couple of broken branch stubs and glowing mushrooms along the top
            rnd = random.Random(5)
            for k in range(6):
                x = rnd.uniform(-2.4, 1.8)
                a = rnd.uniform(-0.6, 0.4)
                c = (x, LOG_Y + math.sin(a) * LOG_R, math.cos(a) * LOG_R + 0.05)
                obs.append(blob("Shelf", 0.22, c, fungus, col, seed=k, seg=12, lump=0.15, squash=(1.0, 0.18, 0.7)))
            for k, x in enumerate((-1.3, 0.9)):
                a = 2.3 + k * 0.5
                base = (x, LOG_Y + math.sin(a) * LOG_R * 0.95, math.cos(a) * LOG_R * 0.95)
                tip = (x + 0.15, LOG_Y + math.sin(a) * (LOG_R + 0.45), math.cos(a) * (LOG_R + 0.45))
                obs.append(tube("Stub", [base, tip], [0.16, 0.11], bark, col, seg=12, flutes=5, flute_depth=0.1,
                                rough=0.1, seed=k + 3))
            for k in range(5):
                x = -2.2 + k * 1.0
                h = 0.12 + 0.05 * (k % 3)
                y = LOG_Y + LOG_R * 0.97
                obs.append(K.cyl("Stalk", 0.04, h, at=at(x, y + h / 2, 0.1 * math.sin(k * 2.0)), seg=10, m=stalk,
                                 col=col))
                obs.append(blob("Cap", 0.16 + k * 0.02, (x, y + h, 0.1 * math.sin(k * 2.0)), glow, col, seed=k,
                                seg=14, lump=0.08, squash=(1.0, 0.5, 1.0)))
        else:
            for k in range(5):
                x = -2.2 + k * 1.0
                h = 0.12 + 0.05 * (k % 3)
                y = LOG_Y + LOG_R * 0.97
                obs.append(blob("Cap", 0.18 + k * 0.02, (x, y + h * 0.6, 0.1 * math.sin(k * 2.0)), glow, col,
                                seed=k, seg=8, lump=0.0, squash=(1.0, 0.6, 1.0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ moon lamp
def moon_lamp():
    iron = mottled("Lamp Iron", IRON, IRON_LIGHT, scale=6.0, rough=0.5, metal=0.6, bump=0.3, third=VERDIGRIS)
    moon = K.mat("Crescent", MOON, rough=0.35, metal=0.7)
    gy = LAMP_GLOBE_Y
    gr = LAMP_GLOBE_R

    def shaft_pts(n):
        return [(0.05 * math.sin(t * 3.0), 0.3 + t * 1.85, 0.03 * math.sin(t * 5.0)) for t in
                (k / (n - 1) for k in range(n))]

    def build(col, high):
        obs = []
        sp = shaft_pts(14 if high else 6)
        top = Vector(sp[-1])
        # the foot: an eight-sided plinth with four curled claws
        obs.append(K.lathe("Plinth", [(0.26, 0.0), (0.26, 0.08), (0.2, 0.12), (0.14, 0.24), (0.11, 0.32), (0.0, 0.32)],
                           seg=32 if high else 8, sides=8, m=iron, col=col))
        obs.append(tube("Shaft", sp, [0.07] * len(sp), iron, col, seg=16 if high else 6, flutes=6 if high else 0,
                        flute_depth=0.25, twist=7.0))
        # the cup that holds the globe, and the cage of four bars round it up to the cap
        cup = [(0.07, 0.0), (0.1, 0.06), (0.19, 0.14), (0.22, 0.2), (0.2, 0.22), (0.0, 0.18)]
        c = K.lathe("Cup", cup, seg=32 if high else 10, m=iron, col=col, flutes=8 if high else 0, flute_depth=0.02,
                    flute_z=(0.04, 0.2))
        c.location = at(top.x, gy - gr - 0.2, top.z)
        obs.append(c)
        cap_y = gy + gr + 0.02
        for k in range(4):
            a = k * math.tau / 4 + 0.4
            q = Vector((math.cos(a), 0, math.sin(a)))
            pp = [tuple(Vector((top.x, 0, top.z)) + q * r + Vector((0, y, 0))) for r, y in
                  ((0.2, gy - gr + 0.02), (gr + 0.07, gy - 0.12), (gr + 0.08, gy + 0.08), (0.22, cap_y))]
            obs.append(gwire("Bar", pp, 0.018, iron, col, res=8 if high else 2, bevel_res=3 if high else 1))
        # the pointed cap with a curl at its tip and a crescent moon
        cap = K.lathe("Cap", [(0.0, 0.0), (0.3, 0.0), (0.33, 0.03), (0.22, 0.09), (0.12, 0.2), (0.05, 0.34),
                              (0.0, 0.42)], seg=32 if high else 10, m=iron, col=col)
        cap.location = at(top.x, cap_y, top.z)
        obs.append(cap)
        cy = cap_y + 0.62
        if high:
            obs.append(K.lathe("Collar", [(0.0, 0.0), (0.11, 0.0), (0.12, 0.03), (0.11, 0.06), (0.0, 0.06)], seg=24,
                               m=iron, col=col, at=at(sp[7][0], sp[7][1] - 0.03, sp[7][2])))
            for i in (1, 12):
                obs.append(K.lathe("Collar", [(0.0, 0.0), (0.1, 0.0), (0.11, 0.04), (0.1, 0.07), (0.0, 0.07)],
                                   seg=24, m=iron, col=col, at=at(sp[i][0], sp[i][1] - 0.035, sp[i][2])))
            for k in range(4):                                  # claws curling out from the plinth
                a = k * math.tau / 4 + math.pi / 4
                q = Vector((math.cos(a), 0, math.sin(a)))
                pp = [tuple(q * r + Vector((0, y, 0))) for r, y in ((0.14, 0.2), (0.26, 0.12), (0.34, 0.04), (0.38, 0.02),
                                                                   (0.36, 0.07))]
                obs.append(gwire("Claw", pp, 0.03, iron, col, res=8))
            # the crescent: a thick arc standing on the cap's tip
            arc = [(top.x + 0.13 * math.cos(t), cy + 0.13 * math.sin(t), top.z) for t in
                   (math.radians(-110 + 220 * k / 10) for k in range(11))]
            obs.append(gwire("Crescent", arc, 0.03, moon, col, res=8))
            obs.append(grod("Stem", (top.x, cap_y + 0.4, top.z), (top.x - 0.04, cy - 0.12, top.z), 0.018, iron, col))
        else:
            arc = [(top.x + 0.13 * math.cos(t), cy + 0.13 * math.sin(t), top.z) for t in
                   (math.radians(-110 + 220 * k / 4) for k in range(5))]
            obs.append(gwire("Crescent", arc, 0.04, moon, col, res=2, bevel_res=1))
            obs.append(grod("Stem", (top.x, cap_y + 0.4, top.z), (top.x - 0.04, cy - 0.12, top.z), 0.025, iron, col,
                            seg=4))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ glowing mushrooms
SHROOMS = [((0.0, 0.0), 0.5, 0.28), ((0.32, 0.18), 0.33, 0.22), ((-0.18, 0.3), 0.22, 0.16)]


def glow_mushrooms():
    cap = mottled("Glow Cap", CAP, (0.86, 0.85, 0.84), scale=8.0, rough=0.45, bump=0.2)
    spot = K.mat("Glow Spot", SPOT, rough=0.4, emit=1.0)
    gill = K.mat("Glow Gill", GILL, rough=0.7)
    stalk = mottled("Glow Stalk", STALK, (0.66, 0.66, 0.74), scale=10.0, rough=0.8, bump=0.3)
    caps_h, caps_l, st_h, st_l = [], [], [], []
    rnd = random.Random(4)
    for i, ((x, z), h, r) in enumerate(SHROOMS):
        lean = (0.06 * (i - 1), 0, 0.04 * i)
        topc = (x + lean[0], h, z + lean[2])
        for high, cl, sl, col in ((True, caps_h, st_h, HIGH), (False, caps_l, st_l, LOW)):
            prof = [(0.0, r * 0.62), (r * 0.5, r * 0.58), (r * 0.85, r * 0.4), (r, r * 0.12), (r * 0.96, 0.0),
                    (r * 0.3, r * 0.05), (0.0, r * 0.1)]
            c = K.lathe("Cap", prof, seg=32 if high else 10, m=cap, col=col)
            c.location = at(topc[0], topc[1] - r * 0.12, topc[2])
            cl.append(c)
            sp = [(x, 0.0, z), (x + lean[0] * 0.5, h * 0.5, z + lean[2] * 0.5), topc]
            sl.append(tube("Stalk", sp, [r * 0.32, r * 0.22, r * 0.2], stalk, col, seg=14 if high else 6,
                           rough=0.1 if high else 0.0, seed=i, cap0=False))
            if high:
                # gills under the cap, a skirt round the stalk, and glowing spots on top
                for k in range(28):
                    a = k * math.tau / 28
                    q = Vector((math.cos(a), 0, math.sin(a)))
                    sl_p = [tuple(Vector(topc) + q * r * 0.25 + Vector((0, -r * 0.05, 0))),
                            tuple(Vector(topc) + q * r * 0.9 + Vector((0, -r * 0.1, 0)))]
                    cl.append(grod("Gill", sl_p[0], sl_p[1], r * 0.03, gill, col, seg=4))
                skirt = K.lathe("Skirt", [(r * 0.2, 0.0), (r * 0.42, -r * 0.18), (r * 0.44, -r * 0.2), (r * 0.21, 0.02)],
                                seg=24, m=stalk, col=col, flutes=10, flute_depth=r * 0.04, flute_z=(-r, r))
                skirt.location = at(x + lean[0] * 0.8, h * 0.78, z + lean[2] * 0.8)
                sl.append(skirt)
                for k in range(7):
                    a = rnd.uniform(0, math.tau)
                    t = rnd.uniform(0.15, 0.75)
                    rr = r * (0.2 + 0.75 * t)
                    yy = r * 0.62 * math.cos(t * math.pi / 2) ** 0.7
                    p = (topc[0] + math.cos(a) * rr, topc[1] - r * 0.12 + yy + 0.004, topc[2] + math.sin(a) * rr)
                    cl.append(blob("Spot", r * rnd.uniform(0.09, 0.15), p, spot, col, seed=k + i * 9, seg=8,
                                   lump=0.2, squash=(1.0, 0.45, 1.0)))
    return (caps_h, caps_l), (st_h, st_l)


if KIND == "glow_mushrooms":
    (ch, cl), (sh, sl) = glow_mushrooms()
    parts = [bake_part("Caps", ch, cl, 512, emit=True, extrusion=0.02, ray=0.05),
             bake_part("Stalks", sh, sl, 256, extrusion=0.02, ray=0.05, ao=False)]
else:
    fn, size, ext, ray, emit, ao = {
        "crooked_tree": (crooked_tree, 1024, 0.06, 0.12, False, True),
        "hollow_log": (hollow_log, 1024, 0.08, 0.16, True, True),
        "moon_lamp": (moon_lamp, 512, 0.03, 0.06, False, True),
    }[KIND]
    high, low = fn()
    parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

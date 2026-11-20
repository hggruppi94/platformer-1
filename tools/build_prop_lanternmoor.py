# Lanternmoor, Pip's world, built the detailed way (tools/bake_kit.py; 20 Nov 2026, Hayden: "Then keep baking
# details", the portal worlds' props after Dark Hollow): its lantern trees, the Night Path's lantern posts and its
# three beacons. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces tools/build_lanternmoor.gd and scripts/lanternmoor.gd build from shapes, so the swap
# (scripts/detail_props.gd dress_lanternmoor, and lanternmoor.gd lantern_model / beacon_model) puts each where the old
# one was and every collision stays the game's. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is
# Godot's Y.
#   lantern_tree  a lantern tree at size 1, 4.7 m tall: a dark twisting trunk in ridged bark with roots, two bent
#                 branches and three round crowns of purple leaves ("Leaves"), and a paper lantern pod hanging from
#                 each branch on a cord ("PodA", "PodB": baked pale and glowing, the game tints each in its old colour).
#   lantern_post  a Night Path lantern's post, 2.3 m: a knotted wooden post on a little cairn, an iron bracket curling
#                 out over +Z with a chain, and the brass lid and foot that hold the game's own paper shade (its middle
#                 1.9 up and 0.42 out; it stays, so it can light up).
#   beacon        a beacon without its flame: a carved stone pillar 2.85 m with rings, crescent moons and moss at its
#                 foot, an iron cage of six curved bars round the game's flame (its middle 3.35 up) and a pointed iron
#                 roof with a star on top.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_lanternmoor.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["lantern_tree", "lantern_post", "beacon"]
KIND = next((a for a in sys.argv if a in KINDS), "lantern_tree")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

BARK = (0.2, 0.13, 0.22)
BARK_DARK = (0.1, 0.06, 0.12)
BARK_PALE = (0.34, 0.26, 0.38)
LEAF = (0.32, 0.2, 0.46)
LEAF_LIGHT = (0.46, 0.3, 0.62)
LEAF_DARK = (0.2, 0.12, 0.3)
PAPER = (0.97, 0.95, 0.9)
CORD = (0.25, 0.2, 0.28)
POST = (0.18, 0.14, 0.22)
POST_LIGHT = (0.3, 0.24, 0.32)
IRON = (0.15, 0.12, 0.18)
IRON_LIGHT = (0.28, 0.24, 0.32)
BRASS = (0.82, 0.62, 0.36)
CAIRN = (0.5, 0.46, 0.6)
STONE = (0.42, 0.38, 0.52)
STONE_LIGHT = (0.5, 0.46, 0.6)
MOSS = (0.2, 0.3, 0.32)
GOLD = (0.95, 0.78, 0.4)


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




def leaves(name, puffs, m, col, per=260, seed=1, size=0.11):
    """A crown of little leaves over each puff (centre, radii in Godot), each a bent diamond lying on the puff's
    surface, all in one mesh."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    for c, rad in puffs:
        c = Vector(c)
        for _ in range(per):
            while True:
                d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
                if 0.2 < d.length <= 1.0 and d.y / d.length > -0.75:
                    break
            d.normalize()
            p = c + Vector((d.x * rad[0], d.y * rad[1], d.z * rad[2])) * rnd.uniform(0.9, 1.04)
            n = Vector(at(*d)).normalized()
            t = n.cross(Vector((0, 0, 1)))
            if t.length < 0.1:
                t = Vector((1, 0, 0))
            t.normalize()
            t.rotate(__import__("mathutils").Quaternion(n, rnd.uniform(0, math.tau)))
            b = n.cross(t).normalized()
            s = size * rnd.uniform(0.75, 1.25)
            P = Vector(at(*p))
            tilt = n * s * 0.35
            vs = [bm.verts.new(P - t * s), bm.verts.new(P + b * s * 0.45 + tilt * 0.5),
                  bm.verts.new(P + t * s + tilt), bm.verts.new(P - b * s * 0.45 + tilt * 0.5),
                  bm.verts.new(P + tilt * 0.6 + n * s * 0.08)]
            for k in range(4):
                bm.faces.new((vs[k], vs[(k + 1) % 4], vs[4]))
    return K._obj(name, bm, m, True, col)


# ================================================================ lantern tree
BRANCH_A = (0.6, 0.6 + 2.75)


def _lantern_plan():
    rnd = random.Random(3)
    trunk = [(0.08 * math.sin(t * 3.0), t * 3.5, 0.06 * math.sin(t * 4.2 + 0.7)) for t in (k / 10 for k in range(11))]
    trunk_r = [0.4 - 0.2 * (k / 10) ** 0.7 for k in range(11)]
    trunk_r[0] = 0.5
    branches = []
    for a in BRANCH_A:
        q = Vector((math.cos(a), 0, math.sin(a)))
        base = Vector(trunk[7])
        tip = q * 1.2 + Vector((0, 3.55, 0))
        pts = curve(base, tip, (0, -0.15, 0), 6)
        branches.append((pts, [0.14, 0.12, 0.1, 0.08, 0.06, 0.05]))
    roots = []
    for k in range(5):
        a = k * math.tau / 5 + 0.3
        d = Vector((math.cos(a), 0, math.sin(a)))
        pts = [tuple(d * 0.2 + Vector((0, 0.4, 0))), tuple(d * 0.5 + Vector((0, 0.1, 0))),
               tuple(d * rnd.uniform(0.8, 1.0) + Vector((0, -0.05, 0)))]
        roots.append((pts, [0.15, 0.09, 0.03]))
    puffs = [((0, 3.8, 0), (1.4, 0.9, 1.4))]
    pods = []
    for a in BRANCH_A:
        puffs.append(((math.cos(a) * 1.1, 3.7, math.sin(a) * 1.1), (1.1, 0.77, 1.1)))
        pods.append((math.cos(a) * 1.3, 2.7, math.sin(a) * 1.3))
    return trunk, trunk_r, branches, roots, puffs, pods


def lantern_tree():
    bark = mottled("Lantern Bark", BARK, BARK_DARK, scale=5.0, rough=0.9, bump=0.6, lo=0.4, hi=0.65, third=BARK_PALE)
    leaf = mottled("Leaf", LEAF, LEAF_LIGHT, scale=7.0, rough=0.7, bump=0.2, third=LEAF_DARK)
    deep = K.mat("Leaf Deep", (0.26, 0.16, 0.38), rough=0.9)
    paper = mottled("Pod Paper", PAPER, (0.9, 0.88, 0.84), scale=12.0, rough=0.6, bump=0.15)
    paper_lit = K.mat("Pod Light", PAPER, rough=0.6, emit=1.0)
    brass = K.mat("Pod Brass", BRASS, rough=0.35, metal=0.8)
    trunk, trunk_r, branches, roots, puffs, pods = _lantern_plan()

    def wood(col, high):
        obs = []
        if high:
            tp, tr = finer(trunk, trunk_r, 60)
            obs.append(tube("Trunk", tp, tr, bark, col, seg=36, flutes=9, flute_depth=0.16, twist=1.6, rough=0.1,
                            cap0=False))
            for i, (pts, rr) in enumerate(branches):
                pts, rr = finer(pts, rr, 24)
                obs.append(tube("Branch", pts, rr, bark, col, seg=14, flutes=5, flute_depth=0.12, twist=2.0,
                                rough=0.1, seed=i + 1))
            for i, (pts, rr) in enumerate(roots):
                pts, rr = finer(pts, rr, 14)
                obs.append(tube("Root", pts, rr, bark, col, seg=12, flutes=4, flute_depth=0.1, rough=0.15,
                                seed=i + 10))
        else:
            obs.append(tube("Trunk", trunk, trunk_r, bark, col, seg=8, cap0=False))
            for pts, rr in branches:
                obs.append(tube("Branch", pts, rr, bark, col, seg=5))
            for pts, rr in roots:
                obs.append(tube("Root", pts, rr, bark, col, seg=5))
        # each pod's brass cap and a little hook up into the leaves, and a tassel underneath
        for p in pods:
            x, y, z = p
            cap = K.lathe("Pod Cap", [(0.0, 0.0), (0.12, 0.0), (0.09, 0.05), (0.04, 0.08), (0.0, 0.08)],
                          seg=24 if high else 8, m=brass, col=col)
            cap.location = at(x, y + 0.27, z)
            obs.append(cap)
            foot = K.lathe("Pod Foot", [(0.0, 0.0), (0.04, 0.0), (0.1, 0.05), (0.0, 0.05)], seg=24 if high else 8,
                           m=brass, col=col)
            foot.location = at(x, y - 0.32, z)
            obs.append(foot)
            obs.append(grod("Hook", (x, y + 0.34, z), (x * 0.96, y + 0.48, z * 0.96), 0.02, brass, col,
                            seg=8 if high else 4))
            obs.append(K.cyl("Tassel", 0.04 if high else 0.035, 0.16, at=at(x, y - 0.4, z), seg=12 if high else 4,
                             m=brass, col=col, r2=0.01))
        return obs

    def crown(col, high):
        if high:
            obs = [leaves("Leaves", puffs, leaf, col, per=900, seed=5, size=0.13)]
            for i, (c, rad) in enumerate(puffs):
                obs.append(blob("Inside", 1.0, c, deep, col, seed=i, seg=16, lump=0.1,
                                squash=tuple(r * 0.88 for r in rad)))
            return obs
        return [blob("Puff", 1.0, c, leaf, col, seed=i, seg=12, lump=0.06, squash=rad) for i, (c, rad) in
                enumerate(puffs)]

    def pod(col, high, p):
        x, y, z = p
        prof = [(0.0, -0.29), (0.08, -0.28), (0.16, -0.22), (0.21, -0.12), (0.225, 0.0), (0.21, 0.12),
                (0.16, 0.22), (0.08, 0.28), (0.0, 0.29)]
        lp = K.lathe("Pod", prof, seg=48 if high else 10, m=paper_lit if not high else paper, col=col,
                     flutes=14 if high else 0, flute_depth=0.012, flute_z=(-0.3, 0.3))
        lp.location = at(x, y, z)
        obs = [lp]
        if high:
            for k in range(3):
                yy = -0.14 + k * 0.14
                r = 0.225 * math.sqrt(max(0.0, 1 - (yy / 0.29) ** 2)) + 0.003
                obs.append(gwire("Band", ring_pts((x, y + yy, z), (0, 1, 0), r, 24), 0.006, paper_lit, col,
                                 closed=True, res=4, bevel_res=1))
        return obs

    return (wood(HIGH, True), wood(LOW, False)), (crown(HIGH, True), crown(LOW, False)), \
        [(pod(HIGH, True, p), pod(LOW, False, p)) for p in pods]


# ================================================================ Night Path lantern post
SHADE = (0.0, 1.9, 0.42)


def lantern_post():
    wood = mottled("Post Wood", POST, POST_LIGHT, scale=6.0, rough=0.85, bump=0.5, grain=(18.0, 0.3))
    iron = mottled("Post Iron", IRON, IRON_LIGHT, scale=8.0, rough=0.5, metal=0.6, bump=0.3)
    brass = K.mat("Post Brass", BRASS, rough=0.35, metal=0.8)
    stone = mossy("Cairn Stone", CAIRN, (0.4, 0.37, 0.5), MOSS, scale=6.0, bump=0.5, up=0.5)
    sx, sy, sz = SHADE
    post_pts = [(0.025 * math.sin(t * 4.0), t * 2.5, 0.015 * math.sin(t * 6.0)) for t in (k / 8 for k in range(9))]
    post_r = [0.1 - 0.035 * (k / 8) for k in range(9)]

    def build(col, high):
        obs = []
        if high:
            pp, pr = finer(post_pts, post_r, 40)
            obs.append(tube("Post", pp, pr, wood, col, seg=20, flutes=7, flute_depth=0.12, twist=0.6, rough=0.12,
                            cap0=False))
            rnd = random.Random(2)
            for k in range(3):                                   # knots
                i = rnd.randint(2, 6)
                a = rnd.uniform(0, math.tau)
                q = Vector((math.cos(a), 0, math.sin(a)))
                obs.append(blob("Knot", 0.03, tuple(Vector(post_pts[i]) + q * post_r[i] * 0.85), wood, col, seed=k,
                                seg=8, lump=0.3))
        else:
            obs.append(tube("Post", post_pts, post_r, wood, col, seg=6, cap0=False))
        top_y = 2.5
        obs.append(K.lathe("Post Top", [(0.0, 0.0), (0.09, 0.0), (0.1, 0.03), (0.05, 0.08), (0.0, 0.12)],
                           seg=24 if high else 6, m=brass, col=col, at=at(post_pts[-1][0], top_y, post_pts[-1][2])))
        # the cairn of stones round its foot
        for k in range(4 if high else 3):
            a = k * math.tau / (4 if high else 3) + 0.4
            obs.append(blob("Cairn", 0.13 - 0.015 * k, (math.cos(a) * 0.14, 0.06, math.sin(a) * 0.14), stone, col,
                            seed=k, seg=12 if high else 6, lump=0.3 if high else 0.1, squash=(1.0, 0.6, 1.0)))
        # the bracket: an arm out over the shade, braced by a scroll, ending in a curl, with a chain to the lid
        arm_y = 2.42
        obs.append(grod("Arm", (0, arm_y, 0.0), (0, arm_y, sz + 0.05), 0.028, iron, col, seg=10 if high else 4))
        curl = [(0, arm_y, sz + 0.05), (0, arm_y + 0.04, sz + 0.12), (0, arm_y + 0.1, sz + 0.1),
                (0, arm_y + 0.08, sz + 0.05)]
        obs.append(gwire("Curl", curl, 0.022, iron, col, res=8 if high else 2, bevel_res=3 if high else 1))
        brace = [(0, 2.02, 0.07), (0, 2.12, 0.22), (0, 2.3, 0.3), (0, 2.4, 0.24)]
        obs.append(gwire("Brace", brace, 0.018, iron, col, res=8 if high else 2, bevel_res=3 if high else 1))
        if high:
            for k in range(3):                                   # chain links
                y = arm_y - 0.03 - k * 0.045
                pts = ring_pts((sx, y, sz), (1, 0, 0) if k % 2 else (0, 0, 1), 0.022, 10)
                obs.append(gwire("Link", pts, 0.006, iron, col, closed=True, res=4, bevel_res=1))
        else:
            obs.append(grod("Chain", (sx, arm_y, sz), (sx, 2.3, sz), 0.012, iron, col, seg=4))
        # the lid over the shade and the foot under it, with a tassel
        obs.append(K.lathe("Lid", [(0.0, 0.0), (0.15, 0.0), (0.16, 0.02), (0.1, 0.06), (0.04, 0.09), (0.0, 0.09)],
                           seg=32 if high else 8, m=brass, col=col, at=at(sx, 2.21, sz)))
        obs.append(K.lathe("Foot", [(0.0, 0.0), (0.05, 0.0), (0.13, 0.05), (0.12, 0.06), (0.0, 0.06)],
                           seg=32 if high else 8, m=brass, col=col, at=at(sx, 1.53, sz)))
        obs.append(K.cyl("Tassel", 0.03, 0.14, at=at(sx, 1.47, sz), seg=12 if high else 4, m=brass, col=col, r2=0.01))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ beacon
def beacon():
    stone = mossy("Beacon Stone", STONE, STONE_LIGHT, MOSS, scale=3.0, bump=0.6, up=0.55)
    carve = K.mat("Beacon Carving", (0.62, 0.58, 0.74), rough=0.8)
    iron = mottled("Beacon Iron", IRON, IRON_LIGHT, scale=8.0, rough=0.5, metal=0.6, bump=0.3)
    gold = K.mat("Beacon Star", GOLD, rough=0.3, metal=0.9)
    prof = [(0.0, 0.0), (0.74, 0.0), (0.74, 0.12), (0.66, 0.2), (0.55, 0.32), (0.5, 0.5), (0.47, 1.4), (0.45, 2.45),
            (0.52, 2.52), (0.7, 2.6), (0.72, 2.72), (0.68, 2.85), (0.0, 2.85)]

    def build(col, high):
        obs = [K.lathe("Pillar", prof, seg=48 if high else 12, m=stone, col=col, flutes=8 if high else 0,
                       flute_depth=0.03, flute_z=(0.55, 2.4))]
        if high:
            for y in (0.62, 2.3):                                # carved bands
                r = 0.5 if y < 1 else 0.455
                obs.append(gwire("Band", ring_pts((0, y, 0), (0, 1, 0), r, 32), 0.025, carve, col, closed=True,
                                 res=4, bevel_res=2))
            for k in range(3):                                   # crescent moons on three sides
                a = k * math.tau / 3 + 0.5
                q = Vector((math.cos(a), 0, math.sin(a)))
                t = Vector((-q.z, 0, q.x))
                c = q * 0.475 + Vector((0, 1.5, 0))
                arc = [tuple(c + t * 0.12 * math.cos(u) + Vector((0, 0.12 * math.sin(u), 0)) + q * 0.0)
                       for u in (math.radians(-120 + 240 * j / 10) for j in range(11))]
                obs.append(gwire("Moon", arc, 0.022, carve, col, res=8))
                rnd = random.Random(k)
                for j in range(3):                               # little star dots round it
                    s = c + t * rnd.uniform(-0.25, 0.25) + Vector((0, rnd.uniform(0.2, 0.32), 0))
                    obs.append(blob("Dot", 0.018, tuple(s), carve, col, seed=j, seg=6, lump=0.1))
            rnd = random.Random(9)
            for k in range(8):                                   # moss lumps round the foot
                a = rnd.uniform(0, math.tau)
                q = Vector((math.cos(a), 0, math.sin(a)))
                obs.append(blob("Moss", rnd.uniform(0.06, 0.1), tuple(q * 0.62 + Vector((0, 0.17, 0))), stone, col,
                                seed=k, seg=8, lump=0.4, squash=(1.0, 0.5, 1.0)))
        # the cage: six bars bowing out round the flame, rings at both ends
        for k in range(6):
            a = k * math.tau / 6
            q = Vector((math.cos(a), 0, math.sin(a)))
            pts = [tuple(q * r + Vector((0, y, 0))) for r, y in ((0.5, 2.85), (0.6, 3.1), (0.63, 3.4), (0.58, 3.7),
                                                               (0.5, 3.96))]
            obs.append(gwire("Bar", pts, 0.035, iron, col, res=8 if high else 2, bevel_res=3 if high else 1))
        for y, r in ((2.88, 0.5), (3.96, 0.5)):
            obs.append(gwire("Ring", ring_pts((0, y, 0), (0, 1, 0), r, 24 if high else 8), 0.03, iron, col,
                             closed=True, res=4 if high else 1, bevel_res=2 if high else 1))
        obs.append(K.lathe("Roof", [(0.0, 0.0), (0.72, 0.0), (0.74, 0.04), (0.5, 0.15), (0.2, 0.36), (0.06, 0.5),
                                    (0.0, 0.55)], seg=48 if high else 10, m=iron, col=col, at=at(0, 3.95, 0),
                           flutes=6 if high else 0, flute_depth=0.03, flute_z=(0.05, 0.45)))
        # the star on top
        sy = 4.62
        if high:
            for k in range(4):
                a = k * math.pi / 4
                d = Vector((math.cos(a), 0, 0)) if k % 2 == 0 else Vector((0, 1, 0))
                d = Vector((math.cos(a), math.sin(a), 0))
                obs.append(grod("Ray", tuple(Vector((0, sy, 0)) - d * 0.13), tuple(Vector((0, sy, 0)) + d * 0.13),
                                0.03, gold, col, seg=8, r2=0.03))
            obs.append(blob("Star", 0.05, (0, sy, 0), gold, col, seg=10, lump=0.0))
        else:
            obs.append(blob("Star", 0.11, (0, sy, 0), gold, col, seg=6, lump=0.0, squash=(1.0, 1.0, 0.35)))
        return obs

    return build(HIGH, True), build(LOW, False)


if KIND == "lantern_tree":
    (wh, wl), (ch, cl), pods = lantern_tree()
    parts = [bake_part("Tree", wh, wl, 1024, extrusion=0.04, ray=0.1, ao=False),
             bake_part("Leaves", ch, cl, 1024, extrusion=0.18, ray=0.35)]
    for name, (ph, pl) in zip(("PodA", "PodB"), pods):
        parts.append(bake_part(name, ph, pl, 256, emit=True, extrusion=0.02, ray=0.05, ao=False))
else:
    fn, size, ext, ray = {
        "lantern_post": (lantern_post, 512, 0.03, 0.06),
        "beacon": (beacon, 1024, 0.04, 0.1),
    }[KIND]
    high, low = fn()
    parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

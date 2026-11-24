# The swamps: the Mothmire past Lanternmoor's moor and the Poison Mire past Dusk's Embrace (scripts/swamp.gd builds
# both from shapes as each world loads), built the detailed way (tools/bake_kit.py; 24 Nov 2026, Hayden: "Can you
# work on baking details in the swamp"). Each HIGH version is baked onto a LOW one, which is what the game draws.
# Each world's pieces are baked in its own colours (--world=lanternmoor or --world=dusk), into
# models/props/swamp/<kind>_<world>.glb.
#
# Every piece is made in the space of the plain mesh (or node) it replaces, so scripts/detail_props.gd dress_swamp
# puts each one where the old one was and every collision stays the game's. Blender's X is Godot's X, Blender's -Y is
# Godot's +Z and Blender's Z is Godot's Y.
#   swamp_tree   a dead mangrove 7 m tall in its tree node's space (the game stretches it to each tree's height): a
#                furrowed, twisting trunk on arching stilt roots, three crooked bare branches, and moss hanging off
#                them in long ragged strands (a second part, baked with no AO).
#   plank        one old boardwalk plank (1.9 x 0.08 x 0.42, like the old box): grain, cracks, nail heads, moss at the
#                ends; the game stretches it for the ramps and the Lookout Tree's stair and platform too.
#   island       an island's mound for radius 5 (the game scales it to each island): a mossy top, flat enough to
#                stand on, with tufts and pebbles, over a muddy bank with roots poking out into the water.
#   stone        a stepping stone in its body's space (top at 0.37): a lumpy wet rock with moss on top.
#   sinker       the same, darker and cracked (the game's glowing cracks stay on top of it).
#   log          a fallen log 6 m long along z (stretched to each bridge): bark plates, moss along its top, knots,
#                broken branch stubs, bracket fungus and rings on its ends.
#   hut          the Old Mire Hut in its node's space: stilts, a planked floor, board walls with gaps and patches, a
#                window frame round the game's own glowing window, a sagging thatched roof, the ladder's rungs.
#   chest_box    the swamp chest's box, in the chest's space, and chest_lid its lid, in the Lid's space (so it
#   chest_lid    still opens): planks, metal bands in the world's trim colour, a clasp.
#   lookout      the Lookout Tree's trunk, roots and top branches, in the Lookout's space (the stair, platform, rails
#                and lantern stay the game's).
# Colours are the game's own (sRGB, scripts/swamp.gd LAYOUTS), a little paler so the detail reads in the gloom.
#
#   python tools/build_prop_swamp.py "<out>.glb" <kind> --world=lanternmoor|dusk [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["swamp_tree", "plank", "island", "stone", "sinker", "log", "hut", "chest_box", "chest_lid", "lookout"]
KIND = next((a for a in sys.argv if a in KINDS), "plank")
WORLD = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--world=")), "dusk")
NAME = KIND
OUT = K.out_path("%s_%s.glb" % (KIND, WORLD))

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")


def _light(c, t):
    return tuple(v + (1.0 - v) * t for v in c)


def _dark(c, t):
    return tuple(v * (1.0 - t) for v in c)


_W = {
    "lanternmoor": {"bark": (0.17, 0.14, 0.2), "moss": (0.36, 0.46, 0.4), "land": (0.16, 0.2, 0.26),
                    "land_top": (0.2, 0.3, 0.3), "stone": (0.4, 0.38, 0.45), "trim": (0.75, 0.7, 0.95)},
    "dusk": {"bark": (0.13, 0.1, 0.14), "moss": (0.3, 0.4, 0.22), "land": (0.14, 0.13, 0.18),
             "land_top": (0.2, 0.22, 0.18), "stone": (0.4, 0.38, 0.45), "trim": (0.7, 0.85, 0.4)},
}[WORLD]
BARK = _light(_W["bark"], 0.12)
BARK_DARK = _dark(_W["bark"], 0.35)
MOSS = _W["moss"]
MOSS_LIGHT = _light(MOSS, 0.2)
LAND = _light(_W["land"], 0.06)
LAND_TOP = _light(_W["land_top"], 0.08)
PLANK = _light(_W["bark"], 0.3)
HUT = _light(_W["bark"], 0.22)
THATCH = (0.3, 0.26, 0.2)
CHEST = _light(_W["bark"], 0.34)
TRIM = _W["trim"]
STONE = _W["stone"]
MUD = _dark(_W["land"], 0.3)
LICHEN = (0.62, 0.66, 0.55)
IRON = (0.14, 0.13, 0.16)
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






# ================================================================ shared
def profile_at(prof, s):
    """A point along a cross-section (list of (r, y)) at s from 0 (its first point) to 1 (its last)."""
    t = s * (len(prof) - 1)
    i = min(int(t), len(prof) - 2)
    f = t - i
    a, b = prof[i], prof[i + 1]
    return a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f


def turned(name, prof, rows, seg, m, col, rim=0.0, seed=0.0, push=None, colour=None):
    """A round thing turned from a cross-section prof ((r, y) from the middle of its top out and down to the rim of
    its bottom), with a lumpy edge (rim) and each point pushed by push(p) -> (out, up) (Godot terms)."""
    bm = bmesh.new()
    off = Vector((seed, 2.0, 1.0))
    grid = []
    for i in range(rows):
        r, y = profile_at(prof, i / (rows - 1))
        ring = []
        for k in range(seg):
            a = k / seg * math.tau
            d = Vector((math.cos(a), 0, math.sin(a)))
            rr = r * (1.0 + rim * noise.noise(d * 1.6 + off) + 0.5 * rim * noise.noise(d * 4.0 + off))
            p = Vector((d.x * rr, y, d.z * rr))
            if push:
                o, u = push(p)
                p = p + d * o + Vector((0, u, 0))
            ring.append(bm.verts.new(at(p.x, p.y, p.z)))
        grid.append(ring)
    for i in range(rows - 1):
        for k in range(seg):
            bm.faces.new((grid[i][k], grid[i][(k + 1) % seg], grid[i + 1][(k + 1) % seg], grid[i + 1][k]))
    r, y = prof[-1]
    mid = bm.verts.new(at(0, y, 0))
    for k in range(seg):
        bm.faces.new((grid[-1][(k + 1) % seg], grid[-1][k], mid))
    bmesh.ops.remove_doubles(bm, verts=grid[0], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    if colour:
        colour_mesh(bm, colour)
    return K._obj(name, bm, m, True, col)


def wood_colour(base, seed, moss_ends=None):
    def fn(p, n):
        q = Vector(p)
        g = math.sin(q.x * 9.0 + 3.0 * noise.noise(q * 2.0 + Vector((seed, 0, 0))) + q.z * 2.0)
        c = mix(base, _dark(base, 0.35), 0.5 + 0.5 * g)
        c = mix(c, _light(base, 0.25), max(0.0, noise.noise(q * 6.0 + Vector((0, seed, 0)))) * 0.6)
        if moss_ends and abs(q.x) > moss_ends + 0.12 * noise.noise(q * 5.0 + Vector((seed, 1, 0))):
            c = mix(c, MOSS, 0.65)
        return c
    return fn


def grain_push(seed, depth=0.004):
    def fn(p, n):
        q = Vector(p)
        d = -depth * abs(math.sin(q.z * 70.0 + 4.0 * noise.noise(q * 1.5 + Vector((seed, 0, 0)))))
        crack = abs(noise.noise(Vector((q.x * 0.8, 0, q.z * 6.0)) + Vector((seed, 3, 0))))
        if crack < 0.04:
            d -= 0.01
        return d
    return fn


def plank_block(name, size, pos, m, col, seed, high, moss_ends=None, rot=(0, 0, 0)):
    if not high:
        return gbox(name, size, pos, m, col, rot=rot)
    ob = rounded_block(name, size, 0.01, 24, m, col, grain_push(seed),
                       wood_colour(PLANK if m.name.startswith("Plank") else HUT, seed, moss_ends))
    ob.location = at(*pos)
    ob.rotation_euler = (rot[0], -rot[2], rot[1])
    return ob


# ================================================================ swamp tree
TREE_H = 7.0


def swamp_tree():
    bark = mossy("Mangrove Bark", BARK, BARK_DARK, MOSS, scale=4.0, bump=0.6, up=0.55)
    hang = mottled("Hanging Moss", MOSS, MOSS_LIGHT, scale=12.0, rough=0.95, bump=0.3)
    bark_low = K.mat("Bark Low", BARK, rough=0.9)
    hang_low = K.mat("Moss Low", MOSS, rough=0.95)
    rnd_seed = 7

    def build(col, high):
        rnd = random.Random(rnd_seed)
        wood, card = [], []
        ys = [-0.2 + (TREE_H + 0.3) * k / 9 for k in range(10)]
        pts = [(0.15 * math.sin(y * 0.7), y, 0.1 * math.sin(y * 0.5 + 1.0)) for y in ys]
        radii = [0.42 + 0.2 * max(0.0, 1.0 - (y + 0.2)) - 0.26 * (y / TREE_H) for y in ys]
        radii[-1] = 0.06
        if high:
            p, r = finer(pts, radii, 80)
            wood.append(tube("Trunk", p, r, bark, col, seg=28, flutes=9, flute_depth=0.22, twist=0.6, rough=0.1, seed=1))
        else:
            wood.append(tube("Trunk", pts, radii, bark_low, col, seg=10, rough=0.1, seed=1))
        for k in range(5):
            ra = math.tau * k / 5 + 0.4
            d = Vector((math.cos(ra), 0, math.sin(ra)))
            a = tuple(d * 0.25 + Vector((0, 1.0 + 0.15 * (k % 2), 0)))
            b = tuple(d * 1.25 + Vector((0, -0.25, 0)))
            cp = curve(a, b, tuple(d * 0.3 + Vector((0, 0.45, 0))), 16 if high else 5)
            rr = [0.14 - 0.07 * i / (len(cp) - 1) for i in range(len(cp))]
            wood.append(tube("Root", cp, rr, bark if high else bark_low, col, seg=12 if high else 6, rough=0.12,
                             seed=k + 3, flutes=5 if high else 0, flute_depth=0.15))
        tips = []
        for k, h in enumerate((3.6, 4.9, 6.1)):
            ba = k * 2.2 + 0.5
            d = Vector((math.cos(ba), 0, math.sin(ba)))
            base = Vector((0.15 * math.sin(h * 0.7), h, 0.1 * math.sin(h * 0.5 + 1.0)))
            ln = 2.2 + 0.2 * k
            end = base + d * ln * 0.85 + Vector((0, ln * 0.5, 0))
            side = Vector((-d.z, 0, d.x)) * 0.35
            cp = curve(tuple(base), tuple(end), tuple(side + Vector((0, -0.3, 0))), 14 if high else 5)
            rr = [0.12 - 0.09 * i / (len(cp) - 1) for i in range(len(cp))]
            wood.append(tube("Branch", cp, rr, bark if high else bark_low, col, seg=10 if high else 5, rough=0.1, seed=k + 9))
            mid = Vector(cp[len(cp) // 2])
            twig = curve(tuple(mid), tuple(mid + Vector((0, 0.9, 0)) + d * 0.4), (0.1, 0, 0.1), 8 if high else 3)
            wood.append(tube("Twig", twig, [0.05 - 0.04 * i / (len(twig) - 1) for i in range(len(twig))],
                             bark if high else bark_low, col, seg=6 if high else 4, seed=k + 20))
            for t in (0.45, 0.75, 0.97):
                tips.append(Vector(cp[min(len(cp) - 1, int(t * (len(cp) - 1)))]))
        # moss hanging straight down from each branch in ragged strands (the low version: thin cards)
        for tp in tips:
            for s in range(2):
                ln = rnd.uniform(0.9, 2.1)
                yaw = rnd.uniform(0, math.pi)
                ox, oz = rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25)
                top = tp + Vector((ox, -0.02, oz))
                u = Vector((math.cos(yaw), 0, -math.sin(yaw)))
                # (The high and low trees draw the same random numbers in the same order, so every low strand sits
                # right where its high one is; a wide card over the gaps between strands baked as dark slabs.)
                lens = [ln * rnd.uniform(0.55, 1.0) for j in range(7)]
                clump_seed = rnd.randint(0, 99)
                for j in range(7):
                    x = -0.13 + 0.26 * j / 6
                    sl = lens[j]
                    if high:
                        sp = [tuple(top + u * (x + 0.02 * math.sin(i * 1.3 + j)) + Vector((0, -sl * i / 9, 0)))
                              for i in range(10)]
                        card.append(tube("Strand", sp, [0.022 - 0.016 * i / 9 for i in range(10)], hang, col, seg=5,
                                         rough=0.3, seed=j + s * 7))
                    else:
                        c = top + u * (x + 0.02 * math.sin(4.5 * 1.3 + j)) + Vector((0, -sl / 2, 0))
                        card.append(gbox("Card", (0.045, sl, 0.045), tuple(c), hang_low, col, rot=(0, yaw, 0)))
                if high:
                    card.append(blob("Clump", 0.12, tuple(top), hang, col, seed=clump_seed, seg=8, lump=0.3,
                                     squash=(1.4, 0.6, 1.0)))
                else:
                    card.append(gbox("Clump", (0.3, 0.1, 0.18), tuple(top), hang_low, col, rot=(0, yaw, 0)))
        return wood, card

    return build(HIGH, True), build(LOW, False)


# ================================================================ boardwalk plank
def plank():
    m = painted("Plank Wood", bump=0.35)
    low = K.mat("Plank Low", PLANK, rough=0.9)

    def build(col, high):
        obs = [plank_block("Plank", (1.9, 0.08, 0.42), (0, 0, 0), m if high else low, col, 3.0, high, moss_ends=0.75)]
        if high:
            for x in (-0.82, 0.82):
                for z in (-0.12, 0.12):
                    obs.append(blob("Nail", 0.022, (x, 0.04, z), m, col, seed=2, seg=8, lump=0.05, squash=(1, 0.4, 1)))
            bm = bmesh.new()
            for ob in obs[1:]:
                pass
        return obs

    h, l = build(HIGH, True), build(LOW, False)
    for ob in h[1:]:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        colour_mesh(bm, lambda p, n: (0.12, 0.1, 0.1))
        bm.to_mesh(ob.data)
    return h, l


# ================================================================ island mound
ISLAND_R = 5.0
ISLAND = [(0.0, 0.04), (2.5, 0.05), (4.2, 0.04), (4.8, 0.02), (5.2, -0.1), (5.5, -0.4), (5.8, -0.9)]


def island():
    m = painted("Island", bump=0.5)
    low = K.mat("Island Low", LAND_TOP, rough=0.95)
    grass = mottled("Tuft", MOSS, MOSS_LIGHT, scale=10.0, rough=0.9)
    root_m = mossy("Island Root", BARK, BARK_DARK, MOSS, scale=4.0, bump=0.5)

    def colour(p, n):
        q = Vector(p)
        r = math.hypot(q.x, q.z)
        top = mix(LAND_TOP, MOSS, 0.5 + 0.5 * noise.noise(q * 0.6 + Vector((1, 2, 3))))
        top = mix(top, _light(LAND_TOP, 0.15), max(0.0, noise.noise(q * 3.0)) * 0.6)
        bank = mix(LAND, MUD, 0.5 + 0.5 * noise.noise(q * 1.5 + Vector((4, 0, 0))))
        edge = 4.5 + 0.35 * noise.noise(Vector((q.x, 0, q.z)) * 0.8 + Vector((0, 7, 0)))
        c = top if r < edge else mix(top, bank, min(1.0, (r - edge) * 2.5))
        if q.y < -0.1:
            c = mix(c, MUD, min(1.0, (-0.1 - q.y) * 2.0))
        return c

    def push(p):
        r = math.hypot(p.x, p.z)
        up = 0.0
        if r < 4.8:
            up = 0.03 * noise.noise(p * 0.9) + 0.01 * noise.noise(p * 5.0)
        out = 0.12 * noise.noise(p * 1.3 + Vector((0, 5, 0))) if r > 4.7 else 0.0
        return out, up

    def build(col, high):
        obs = []
        if high:
            obs.append(turned("Mound", ISLAND, 90, 200, m, col, rim=0.05, seed=4.0, push=push, colour=colour))
            rnd = random.Random(11)
            for _ in range(70):
                a = rnd.uniform(0, math.tau)
                r = math.sqrt(rnd.uniform(0.0, 1.0)) * 4.6
                x, z = math.cos(a) * r, math.sin(a) * r
                for b in range(5):
                    bx, bz = x + rnd.uniform(-0.06, 0.06), z + rnd.uniform(-0.06, 0.06)
                    obs.append(grod("Blade", (bx, 0.02, bz), (bx + rnd.uniform(-0.05, 0.05), rnd.uniform(0.12, 0.24),
                                     bz + rnd.uniform(-0.05, 0.05)), 0.012, grass, col, seg=4, r2=0.002))
            for _ in range(40):
                a = rnd.uniform(0, math.tau)
                r = rnd.uniform(4.3, 5.1)
                obs.append(blob("Pebble", rnd.uniform(0.05, 0.12), (math.cos(a) * r, 0.0, math.sin(a) * r), m, col,
                                seed=rnd.randint(0, 99), seg=8, lump=0.25, squash=(1, 0.5, 1)))
            for b in obs[-40:]:
                bm = bmesh.new()
                bm.from_mesh(b.data)
                colour_mesh(bm, stone_colour(STONE, 3.0, moss_up=2.0))
                bm.to_mesh(b.data)
            for k in range(7):
                a = k / 7 * math.tau + 0.3
                d = Vector((math.cos(a), 0, math.sin(a)))
                cp = curve(tuple(d * 4.6 + Vector((0, 0.0, 0))), tuple(d * 5.6 + Vector((0, -0.45, 0))),
                           (0, 0.12, 0), 10)
                obs.append(tube("Root", cp, [0.07 - 0.04 * i / 9 for i in range(10)], root_m, col, seg=8, rough=0.15,
                                seed=k))
        else:
            obs.append(turned("Mound", ISLAND, len(ISLAND), 36, low, col, rim=0.05, seed=4.0))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ stepping stones
STONE_PROF = [(0.0, 0.36), (0.4, 0.355), (0.65, 0.33), (0.8, 0.25), (0.9, 0.0), (0.95, -0.35)]


def _stone(dark):
    m = painted("Wet Stone", bump=0.55)
    base = _dark(STONE, 0.35) if dark else STONE
    low = K.mat("Stone Low", base, rough=0.8)

    def colour(p, n):
        c = stone_colour(_light(base, 0.05), 5.0 + dark, moss_up=0.55)(p, n)
        if dark and abs(noise.noise(Vector(p) * 2.5 + Vector((3, 0, 1)))) < 0.03:
            c = mix(c, (0.06, 0.06, 0.07), 0.8)
        if p[1] < 0.0:
            c = mix(c, _dark(base, 0.4), min(1.0, -p[1] * 2.5))
        return c

    def push(p):
        r = math.hypot(p.x, p.z)
        o = 0.05 * noise.noise(p * 2.5 + Vector((dark, 0, 0))) + 0.015 * noise.noise(p * 9.0)
        u = 0.008 * noise.noise(p * 6.0) - (0.01 if r < 0.7 else 0.0) if r < 0.8 else 0.0
        return o, min(u, 0.0)

    def build(col, high):
        if high:
            return [turned("Stone", STONE_PROF, 40, 96, m, col, rim=0.06, seed=2.0 + dark, push=push, colour=colour)]
        return [turned("Stone", STONE_PROF, len(STONE_PROF), 16, low, col, rim=0.06, seed=2.0 + dark)]

    return build(HIGH, True), build(LOW, False)


def stone():
    return _stone(0)


def sinker():
    return _stone(1)


# ================================================================ log bridge
LOG_LEN = 6.0


def log():
    bark = mossy("Log Bark", BARK, BARK_DARK, MOSS, scale=3.0, bump=0.6, up=0.35)
    ends = K.mat("Log End", _light(_W["bark"], 0.35), rough=0.85, grain=(28.0, 0.5), bump=0.3)
    moss = mottled("Log Moss", MOSS, MOSS_LIGHT, scale=9.0, rough=0.95, bump=0.4)
    fungus = mottled("Fungus", (0.75, 0.6, 0.45), (0.5, 0.36, 0.28), scale=20.0, rough=0.7)
    low = K.mat("Log Low", BARK, rough=0.9)

    def build(col, high):
        obs = []
        zs = [-LOG_LEN / 2 + LOG_LEN * k / 7 for k in range(8)]
        pts = [(0.03 * math.sin(z), 0.0, z) for z in zs]
        radii = [0.6 - 0.05 * (z + LOG_LEN / 2) / LOG_LEN for z in zs]
        if high:
            p, r = finer(pts, radii, 90)
            obs.append(tube("Log", p, r, bark, col, seg=48, flutes=14, flute_depth=0.07, twist=0.15, rough=0.05, seed=2,
                            cap0=False, cap1=False))
            for e, rr in ((-1, radii[0]), (1, radii[-1])):
                obs.append(grod("End", (0, 0, e * LOG_LEN / 2 - e * 0.02), (0, 0, e * LOG_LEN / 2 + e * 0.01), rr * 0.97,
                                ends, col, seg=48))
            rnd = random.Random(5)
            for k in range(16):
                z = rnd.uniform(-2.7, 2.7)
                obs.append(blob("Moss", rnd.uniform(0.18, 0.32), (rnd.uniform(-0.2, 0.2), 0.54, z), moss, col,
                                seed=k, seg=12, lump=0.35, squash=(1.3, 0.3, 1.8)))
            for k, (z, a) in enumerate(((-1.6, 0.8), (0.4, 2.5), (1.9, -0.6))):
                d = (math.cos(a), math.sin(a) * 0.6, 0)
                obs.append(grod("Stub", (d[0] * 0.5, d[1] * 0.5, z), (d[0] * 0.85, d[1] * 0.85 + 0.05, z + 0.05), 0.08,
                                bark, col, seg=10, r2=0.06))
            for k, z in enumerate((-2.2, -0.9, 1.1, 2.4)):
                side = 1 if k % 2 else -1
                for j in range(3):
                    obs.append(blob("Shelf", 0.12 - j * 0.02, (side * 0.6, -0.05 + j * 0.1, z + j * 0.08), fungus, col,
                                    seed=k * 3 + j, seg=10, lump=0.15, squash=(0.6, 1.0, 0.25)))
        else:
            obs.append(tube("Log", pts, radii, low, col, seg=12, rough=0.05, seed=2))
            for k, (z, a) in enumerate(((-1.6, 0.8), (0.4, 2.5), (1.9, -0.6))):
                d = (math.cos(a), math.sin(a) * 0.6, 0)
                obs.append(grod("Stub", (d[0] * 0.5, d[1] * 0.5, z), (d[0] * 0.85, d[1] * 0.85 + 0.05, z + 0.05), 0.09,
                                low, col, seg=5))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Old Mire Hut
def pyramid(name, half, y0, y1, m, col, cuts=1, push=None):
    bm = bmesh.new()
    tip = Vector((0, y1, 0))
    corners = [Vector((sx * half, y0, sz * half)) for sx, sz in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    for s in range(4):
        a, b = corners[s], corners[(s + 1) % 4]
        rows = []
        for i in range(cuts + 1):
            t = i / cuts                                     # 0 at the eaves, 1 at the tip
            row = []
            for j in range(cuts + 1 - i if False else cuts + 1):
                u = j / cuts
                p = a.lerp(b, u).lerp(tip, t)
                if push:
                    p = p + push(p, t, u, s)
                row.append(bm.verts.new(at(p.x, p.y, p.z)))
            rows.append(row)
        for i in range(cuts):
            for j in range(cuts):
                bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    return K._obj(name, bm, m, True, col)


def hut():
    boards = painted("Planks Hut", bump=0.4)
    thatch = mottled("Thatch", THATCH, _light(THATCH, 0.25), scale=30.0, rough=0.95, bump=0.6)
    post = mossy("Hut Post", BARK, BARK_DARK, MOSS, scale=4.0, bump=0.5)
    board_low = K.mat("Boards Low", HUT, rough=0.9)
    thatch_low = K.mat("Thatch Low", THATCH, rough=0.95)
    post_low = K.mat("Post Low", BARK, rough=0.9)

    def tpush(p, t, u, s):
        d = Vector((p.x, 0, p.z))
        out = d.normalized() if d.length > 1e-4 else Vector()
        layer = 0.04 * ((t * 6.0) % 1.0)                     # rows of thatch, each lapping the one below
        sag = -0.08 * math.sin(math.pi * u) * math.sin(math.pi * min(1.0, t * 1.3))
        straw = 0.012 * noise.noise(Vector((u * 60.0, t * 4.0, s)))
        return out * (layer + straw) + Vector((0, sag, 0))

    def build(col, high):
        obs = []
        rnd = random.Random(2)
        bm_ = boards if high else board_low
        for x in (-1.3, 1.3):
            for z in (-1.3, 1.3):
                if high:
                    obs.append(tube("Stilt", finer([(x, -1.2, z), (x + 0.02, 1.2, z - 0.02)], [0.12, 0.09], 20)[0],
                                    [0.12 - 0.03 * i / 19 for i in range(20)], post, col, seg=12, rough=0.15, seed=x + z))
                else:
                    obs.append(grod("Stilt", (x, -1.2, z), (x, 1.2, z), 0.11, post_low, col, seg=6))
        # cross braces between the stilts, under the floor
        for z in (-1.3, 1.3):
            obs.append(grod("Brace", (-1.3, -0.6, z), (1.3, 0.7, z), 0.05, post if high else post_low, col,
                            seg=8 if high else 4))
        # the floor: planks running across
        if high:
            for k in range(11):
                z = -1.6 + 0.145 + k * 0.29
                obs.append(plank_block("Floor", (3.2, 0.12, 0.27), (0, 1.1, z), bm_, col, k * 1.3, True, moss_ends=1.35))
        else:
            obs.append(gbox("Floor", (3.2, 0.12, 3.2), (0, 1.1, 0), bm_, col))
        # the walls: upright boards with a batten across, the window cut in the side facing the island (-z)
        for side in range(4):
            yaw = side * math.pi / 2
            ca, sa = math.cos(yaw), math.sin(yaw)

            def wp(x, y, z):                                  # a point on this wall, wall-local x along it, z out
                return (x * ca + z * sa, y, -x * sa + z * ca)
            window = side == 2                                # (yaw pi: the wall at z -1.5)
            if high:
                for k in range(12):
                    x = -1.5 + 0.125 + k * 0.25
                    h0, h1 = 1.16, 3.05 + rnd.uniform(-0.05, 0.02)
                    parts = [(h0, h1)]
                    if window and abs(x) < 0.45:
                        parts = [(h0, 2.02), (2.58, h1)]
                    for (a, b) in parts:
                        c = wp(x, (a + b) / 2, 1.5)
                        obs.append(plank_block("Board", (0.23, b - a, 0.07), c, bm_, col, side * 20 + k, True,
                                               rot=(rnd.uniform(-0.01, 0.01), yaw, rnd.uniform(-0.02, 0.02))))
                for y in (1.45, 2.8):
                    obs.append(plank_block("Batten", (3.0, 0.12, 0.05), wp(0, y, 1.55), bm_, col, side * 5 + y, True,
                                           rot=(0, yaw, 0)))
                if window:
                    for (cx, cy, sx, sy) in ((0, 2.0, 0.92, 0.08), (0, 2.6, 0.92, 0.08), (-0.46, 2.3, 0.08, 0.68),
                                             (0.46, 2.3, 0.08, 0.68)):
                        obs.append(plank_block("Frame", (sx, sy, 0.06), wp(cx, cy, 1.57), bm_, col, cx + cy, True,
                                               rot=(0, yaw, 0)))
                    obs.append(gbox("Sill", (1.0, 0.05, 0.14), wp(0, 1.96, 1.6), bm_, col, rot=(0, yaw, 0)))
            else:
                if window:
                    for (cx, cy, sx, sy) in ((0, 1.59, 3.0, 0.86), (0, 2.82, 3.0, 0.5), (-0.97, 2.3, 1.06, 0.56),
                                             (0.97, 2.3, 1.06, 0.56)):
                        obs.append(gbox("Wall", (sx, sy, 0.12), wp(cx, cy, 1.52), bm_, col, rot=(0, yaw, 0)))
                    for (cx, cy, sx, sy) in ((0, 2.0, 0.92, 0.08), (0, 2.6, 0.92, 0.08), (-0.46, 2.3, 0.08, 0.68),
                                             (0.46, 2.3, 0.08, 0.68)):
                        obs.append(gbox("Frame", (sx, sy, 0.08), wp(cx, cy, 1.58), bm_, col, rot=(0, yaw, 0)))
                else:
                    obs.append(gbox("Wall", (3.0, 1.9, 0.14), wp(0, 2.1, 1.52), bm_, col, rot=(0, yaw, 0)))
        # the roof (the old cone's square, turned square to the walls, tipped a little like the old one)
        roof = pyramid("Roof", 1.84, 3.0, 4.4, thatch if high else thatch_low, col, cuts=60 if high else 1,
                       push=tpush if high else None)
        roof.rotation_euler = (0, 0.06, 0)
        obs.append(roof)
        if high:
            for s in range(4):                                 # a ragged fringe of straw hanging off the eaves
                for j in range(26):
                    u = -1.8 + 3.6 * j / 25
                    yaw = s * math.pi / 2
                    x, z = u * math.cos(yaw) + 1.86 * math.sin(yaw), -u * math.sin(yaw) + 1.86 * math.cos(yaw)
                    obs.append(grod("Straw", (x, 3.02, z), (x * 1.02, 2.86 - rnd.uniform(0, 0.08), z * 1.02), 0.025,
                                    thatch, col, seg=4, r2=0.01))
        # the ladder's rungs down to the island, on two rails
        for k in range(6):
            p = (0, 0.15 + k * 0.18, -1.6 - 2.2 + k * 0.38)
            if high:
                obs.append(plank_block("Rung", (1.0, 0.06, 0.12), p, bm_, col, k + 40, True))
            else:
                obs.append(gbox("Rung", (1.0, 0.06, 0.12), p, bm_, col))
        for x in (-0.52, 0.52):
            obs.append(grod("Rail", (x, 0.05, -3.85), (x, 1.13, -1.85), 0.05, post if high else post_low, col,
                            seg=8 if high else 4))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the chest
def _metal():
    return K.mat("Chest Trim", TRIM, rough=0.4, metal=0.5, emit=0.6, emit_rgb=TRIM, pits=0.4)


def chest_box():
    wood = painted("Chest Planks", bump=0.4)
    trim = _metal()
    low_w = K.mat("Chest Low", CHEST, rough=0.9)
    low_t = K.mat("Trim Low", TRIM, rough=0.4, metal=0.5, emit=0.6, emit_rgb=TRIM)

    def build(col, high):
        obs = []
        if high:
            for k in range(3):
                y = 0.1 + k * 0.2
                for (sx, sz, x, z) in ((1.1, 0.06, 0, 0.32), (1.1, 0.06, 0, -0.32), (0.06, 0.64, 0.52, 0),
                                       (0.06, 0.64, -0.52, 0)):
                    ob = rounded_block("Board", (sx, 0.19, sz), 0.008, 16, wood, col, grain_push(k * 3 + x + z),
                                       wood_colour(CHEST, k + x * 3 + z))
                    ob.location = at(x, y, z)
                    obs.append(ob)
            obs.append(gbox("Bottom", (1.04, 0.04, 0.64), (0, 0.02, 0), low_w, col))
            for x in (-0.45, 0.45):
                obs.append(rounded_block("Band", (0.08, 0.62, 0.72), 0.01, 10, trim, col))
                obs[-1].location = at(x, 0.3, 0)
                for y in (0.08, 0.3, 0.52):
                    for z in (-0.37, 0.37):
                        obs.append(blob("Rivet", 0.018, (x, y, z), trim, col, seg=8, lump=0.0))
            for (x, z) in ((-0.53, -0.33), (0.53, -0.33), (-0.53, 0.33), (0.53, 0.33)):
                obs.append(gbox("Corner", (0.06, 0.6, 0.06), (x, 0.3, z), trim, col))
        else:
            obs.append(gbox("Box", (1.1, 0.6, 0.7), (0, 0.3, 0), low_w, col))
            for x in (-0.45, 0.45):
                obs.append(gbox("Band", (0.08, 0.62, 0.72), (x, 0.3, 0), low_t, col))
        return obs

    return build(HIGH, True), build(LOW, False)


def chest_lid():
    wood = painted("Chest Planks", bump=0.4)
    trim = _metal()
    low_w = K.mat("Chest Low", CHEST, rough=0.9)
    low_t = K.mat("Trim Low", TRIM, rough=0.4, metal=0.5, emit=0.6, emit_rgb=TRIM)

    def build(col, high):
        obs = []
        if high:
            for k in range(4):
                z = 0.09 + k * 0.18
                ob = rounded_block("Lid Board", (1.12, 0.2 - abs(k - 1.5) * 0.02, 0.17), 0.01, 16, wood, col,
                                   grain_push(k + 7), wood_colour(CHEST, k + 9))
                ob.location = at(0, 0.11 - abs(k - 1.5) * 0.01, z)
                obs.append(ob)
            for x in (-0.45, 0.45):
                obs.append(rounded_block("Band", (0.08, 0.24, 0.74), 0.01, 10, trim, col))
                obs[-1].location = at(x, 0.11, 0.35)
            obs.append(rounded_block("Clasp", (0.16, 0.16, 0.06), 0.015, 10, trim, col))
            obs[-1].location = at(0, 0.0, 0.72)
            obs.append(gwire("Ring", ring_pts((0, -0.04, 0.76), (0, 0, 1), 0.04, 16), 0.01, trim, col, closed=True,
                             res=4, bevel_res=3))
        else:
            obs.append(gbox("Lid", (1.12, 0.22, 0.72), (0, 0.11, 0.35), low_w, col))
            for x in (-0.45, 0.45):
                obs.append(gbox("Band", (0.08, 0.24, 0.74), (x, 0.11, 0.35), low_t, col))
            obs.append(gbox("Clasp", (0.16, 0.16, 0.08), (0, 0.0, 0.72), low_t, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Lookout Tree
LOOK_TOP = 14.0
LOOK_IN = 0.9


def lookout():
    bark = mossy("Lookout Bark", BARK, BARK_DARK, MOSS, scale=2.5, bump=0.7, up=0.55)
    low = K.mat("Lookout Low", BARK, rough=0.9)
    h = LOOK_TOP + 1.2

    def build(col, high):
        obs = []
        ys = [h * k / 12 for k in range(13)]
        pts = [(0.0, y, 0.0) for y in ys]
        radii = [(LOOK_IN * 1.15 + (LOOK_IN * 0.8 - LOOK_IN * 1.15) * y / h) * 0.96 for y in ys]
        if high:
            p, r = finer(pts, radii, 140)
            obs.append(tube("Trunk", p, r, bark, col, seg=56, flutes=13, flute_depth=0.12, twist=0.35, rough=0.04, seed=3))
            rnd = random.Random(8)
            for k in range(6):                                     # knot holes and burrs
                y = rnd.uniform(2.0, 13.0)
                a = rnd.uniform(0, math.tau)
                rr = radii[0] + (radii[-1] - radii[0]) * y / h
                obs.append(blob("Burr", 0.16, (math.cos(a) * rr, y, math.sin(a) * rr), bark, col, seed=k, seg=12,
                                lump=0.3))
        else:
            obs.append(tube("Trunk", pts, radii, low, col, seg=16, rough=0.04, seed=3))
        for k in range(5):
            a = math.tau * k / 5 + 0.3
            d = Vector((math.cos(a), 0, math.sin(a)))
            cp = curve(tuple(d * 0.85 + Vector((0, 0.7, 0))), tuple(d * 2.2 + Vector((0, -0.3, 0))),
                       (0, 0.15, 0), 16 if high else 5)
            rr = [0.34 - 0.22 * i / (len(cp) - 1) for i in range(len(cp))]
            obs.append(tube("Root", cp, rr, bark if high else low, col, seg=14 if high else 6, rough=0.1, seed=k,
                            flutes=6 if high else 0, flute_depth=0.15))
        for k in range(3):
            a = math.tau * k / 3 + 1.0
            d = Vector((math.cos(a), 0, math.sin(a)))
            cp = curve(tuple(d * 0.45 + Vector((0, h - 0.6, 0))), tuple(d * 2.6 + Vector((0, h + 1.8, 0))),
                       tuple(Vector((-d.z, 0, d.x)) * 0.4), 14 if high else 5)
            rr = [0.2 - 0.15 * i / (len(cp) - 1) for i in range(len(cp))]
            obs.append(tube("Branch", cp, rr, bark if high else low, col, seg=10 if high else 5, rough=0.1, seed=k + 5))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ bake it
SPEC = {
    #  kind        fn          size  ext   ray   ao     emit
    "swamp_tree": (swamp_tree, 1024, 0.05, 0.15, True, False),
    "plank": (plank, 512, 0.02, 0.05, True, False),
    "island": (island, 1024, 0.05, 0.3, True, False),
    "stone": (stone, 512, 0.04, 0.12, True, False),
    "sinker": (sinker, 512, 0.04, 0.12, True, False),
    "log": (log, 1024, 0.06, 0.2, True, False),
    "hut": (hut, 2048, 0.06, 0.15, True, False),
    "chest_box": (chest_box, 1024, 0.03, 0.06, True, True),
    "chest_lid": (chest_lid, 512, 0.03, 0.06, True, True),
    "lookout": (lookout, 2048, 0.08, 0.2, True, False),
}
fn, size, ext, ray, ao, emit = SPEC[KIND]
high, low = fn()
if KIND == "swamp_tree":
    parts = [bake_part(NAME, high[0], low[0], size, extrusion=ext, ray=ray, ao=True),
             bake_part(NAME + "_moss", high[1], low[1], 512, extrusion=0.03, ray=0.08, ao=False)]
else:
    parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao, emit=emit, emit_strength=0.6)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

# The race circuits' big scenery (scenes/races/*.tscn, all built at load by scripts/race_circuit.gd), built the
# detailed way (tools/bake_kit.py; 24 Nov 2026, Hayden: "Okay continue baking details"). Their trees, mushrooms,
# crystals, hay, pumpkins, lamps and the barn wear models baked for other places; these are the pieces only the
# circuits have. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Every piece is made in the space of the plain node it replaces, so scripts/detail_props.gd dress_race_circuit puts
# each one where the old one was. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   stand_earth   the grandstand in its "Stand" node's space (+Z faces the road): three tiers of planked seats (tops
#   stand_void    at 0.9, 1.8 and 2.7, 22 m wide, 2.2 deep), stepped side panels, a corrugated roof 6 m up on posts
#                 with struts. Earth's in brown wood with a red roof; the Void's in lilac with a teal roof and gold.
#   windmill      the Pumpkin Run's mill in its "Windmill" node's space: a whitewashed stone tower (3.4 m across the
#                 foot to 2.0 at 14 m) with a door, windows and bands, and a shingled cap with the sails' shaft.
#   mill_sails    the four sails in the "Sails" node's space (they turn round its Z): a hub, a stock down each arm and
#                 a lattice frame with sailcloth, each arm 7 m long.
#   silo          the farm's silo, from its foot (radius 3, 16 m tall): ribbed steel with seams, a ladder, a concrete
#                 ring and a domed cap with a vent.
#   clock_pillar  the Hollow Run's Moon Clock pillar, in the "Moon Clock" node's space: seven sides tapering from 2.6
#                 to 1.6 over 16 m, in courses of old dark stone with moss, on a plinth, under a cap slab.
#   observatory   Observatory Hill's observatory, from the hill top: a drum with pilasters, a cornice, a door and
#                 glowing windows, a lilac dome with gold ribs and its slit, and the brass telescope.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_race.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["stand_earth", "stand_void", "windmill", "mill_sails", "silo", "clock_pillar", "observatory"]
KIND = next((a for a in sys.argv if a in KINDS), "stand_earth")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

LICHEN = (0.62, 0.66, 0.55)
MOSS = (0.2, 0.32, 0.26)
STAND_EARTH = (0.55, 0.38, 0.25)
STAND_VOID = (0.62, 0.5, 0.95)
ROOF_EARTH = (0.85, 0.2, 0.18)
ROOF_VOID = (0.3, 0.85, 0.85)
GOLD = (1.0, 0.82, 0.35)
MILL = (0.95, 0.92, 0.85)
SAIL = (0.75, 0.55, 0.35)
CLOTH = (0.93, 0.88, 0.78)
SILO = (0.75, 0.75, 0.78)
SILO_CAP = (0.45, 0.45, 0.5)
PILLAR = (0.25, 0.22, 0.32)
OBS = (0.92, 0.88, 0.98)
DOME = (0.62, 0.5, 0.95)
DARK = (0.12, 0.1, 0.16)

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





def ngon(name, n, r0, r1, y0, y1, m, col, phase=0.0, colour=None, smooth=False):
    """An n-sided prism (Godot), corners at phase + k * tau / n round Y measured like Godot's cylinders (sin, cos),
    radius r0 at y0 to r1 at y1."""
    bm = bmesh.new()
    rings = []
    for (r, y) in ((r0, y0), (r1, y1)):
        rings.append([bm.verts.new(at(math.sin(phase + k * math.tau / n) * r, y, math.cos(phase + k * math.tau / n) * r))
                      for k in range(n)])
    for k in range(n):
        bm.faces.new((rings[0][k], rings[0][(k + 1) % n], rings[1][(k + 1) % n], rings[1][k]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    if colour:
        colour_mesh(bm, colour)
    return K._obj(name, bm, m, smooth, col)


def spun(name, prof, m, col, c=(0.0, 0.0), seg=32):
    """A lathe from a Godot profile [(radius, y)] round a vertical axis at Godot (x, z) = c."""
    return K.lathe(name, prof, seg=seg, m=m, at=at(c[0], 0.0, c[1]), col=col)


def plank_mat(name, c, rough=0.8):
    return K.mat(name, c, rough=rough, grain=(14.0, 0.35), bump=0.25)


# ================================================================ grandstand
def stand(void):
    wood_c = STAND_VOID if void else STAND_EARTH
    roof_c = ROOF_VOID if void else ROOF_EARTH

    def build(col, high):
        seat = plank_mat("Seat Wood", mix(wood_c, (1, 1, 1), 0.12))
        frame = K.mat("Stand Frame", mix(wood_c, (0, 0, 0), 0.25), rough=0.75, grain=(10.0, 0.3) if high else None)
        roof = K.mat("Stand Roof", roof_c, rough=0.45, metal=0.3)
        post = K.mat("Stand Post", (0.35, 0.33, 0.38) if not void else mix(wood_c, (0, 0, 0), 0.35), rough=0.5, metal=0.4)
        gold = K.mat("Gold Trim", GOLD, rough=0.3, metal=1.0)
        obs = []
        for s in range(3):
            top = (s + 1) * 0.9
            zc = -s * 2.2
            if high:
                # the riser under each seat row and the planks on top, a hair apart
                obs.append(gbox("Riser", (21.9, 0.86, 0.08), (0, top - 0.47, zc + 1.06), frame, col, bevel=0.01))
                obs.append(gbox("Tier Body", (21.8, top - 0.06, 2.1), (0, (top - 0.06) / 2.0, zc), frame, col))
                for k in range(3):
                    z = zc + 0.72 - k * 0.72
                    obs.append(gbox("Seat Plank", (21.96, 0.07, 0.64), (0, top - 0.035, z), seat, col, bevel=0.012))
                for x in [-11.0 + 2.75 * j for j in range(9)]:          # bolts and leg brackets on each riser
                    obs.append(gbox("Bracket", (0.12, 0.6, 0.04), (x if abs(x) < 10.9 else x * 0.99, top - 0.45, zc + 1.11),
                                    post, col))
                    for dy in (-0.15, 0.15):
                        obs.append(blob("Bolt", 0.025, (x, top - 0.45 + dy, zc + 1.14), post, col, seg=6, lump=0.0))
                if void:
                    obs.append(gbox("Gold Edge", (21.98, 0.05, 0.05), (0, top - 0.02, zc + 1.11), gold, col))
            else:
                obs.append(gbox("Tier", (22.0, top, 2.2), (0, top / 2.0, zc), seat, col))
        # stepped side panels
        for sx in (-1, 1):
            for s in range(3):
                top = (s + 1) * 0.9
                obs.append(gbox("Side Panel", (0.12, top + 0.12, 2.2), (sx * 11.04, (top + 0.12) / 2.0, -s * 2.2), frame, col,
                                bevel=0.02 if high else 0.0))
            if high:
                obs.append(gbox("Handrail", (0.08, 0.08, 6.6), (sx * 11.04, 3.6, -2.2), post, col, bevel=0.01))
                for s in range(3):
                    obs.append(gbox("Rail Post", (0.06, 0.8, 0.06), (sx * 11.04, (s + 1) * 0.9 + 0.48, -s * 2.2 + 0.9), post,
                                    col))
        # back board behind the top row
        obs.append(gbox("Back Board", (22.0, 1.1, 0.12), (0, 3.25, -5.45), frame, col, bevel=0.01 if high else 0.0))
        # posts and roof
        for sx in (-1, 1):
            obs.append(gbox("Post", (0.3, 6.0, 0.3), (sx * 11.0, 3.0, -5.5), post, col, bevel=0.02 if high else 0.0))
            if high:
                obs.append(grod("Strut", (sx * 11.0, 4.4, -5.5), (sx * 11.0, 5.9, -3.2), 0.06, post, col, seg=8))
                obs.append(grod("Strut", (sx * 11.0, 4.6, -5.5), (sx * 9.6, 5.9, -5.5), 0.06, post, col, seg=8))
                obs.append(gbox("Foot", (0.5, 0.15, 0.5), (sx * 11.0, 0.075, -5.5), post, col, bevel=0.02))
        if high:
            obs.append(gbox("Roof Sheet", (23.0, 0.1, 8.0), (0, 5.93, -2.4), roof, col))
            for k in range(58):                      # corrugations running front to back
                x = -11.3 + k * 0.4
                obs.append(grod("Rib", (x, 6.0, -6.38), (x, 6.0, 1.58), 0.055, roof, col, seg=6))
            obs.append(gbox("Fascia", (23.1, 0.3, 0.08), (0, 5.95, 1.62), gold if void else frame, col, bevel=0.01))
            obs.append(gbox("Fascia Back", (23.1, 0.3, 0.08), (0, 5.95, -6.42), frame, col, bevel=0.01))
            for k in range(8):                      # roof beams underneath
                obs.append(gbox("Beam", (0.14, 0.18, 7.9), (-10.5 + k * 3.0, 5.79, -2.4), frame, col))
            if void:
                for k in range(11):                 # little gold stars along the fascia
                    x = -10 + k * 2.0
                    pts = [(x + 0.18 * math.sin(t * math.tau / 10) * (1.0 if t % 2 == 0 else 0.45), 5.95
                            + 0.18 * math.cos(t * math.tau / 10) * (1.0 if t % 2 == 0 else 0.45), 1.68) for t in range(11)]
                    obs.append(gwire("Star", pts, 0.02, gold, col, res=2, bevel_res=2))
        else:
            obs.append(gbox("Roof", (23.0, 0.25, 8.0), (0, 6.0, -2.4), roof, col))
        return obs

    return build(HIGH, True), build(LOW, False)


def stand_earth():
    return stand(False)


def stand_void():
    return stand(True)


# ================================================================ windmill
def mill_r(y):
    return 3.4 - 1.4 * y / 14.0


def windmill():
    def build(col, high):
        wall = (mottled("Mill Wall", MILL, mix(MILL, (0.7, 0.66, 0.6), 0.5), scale=3.0, rough=0.85, bump=0.4)
                if high else K.mat("Mill Wall", MILL, rough=0.85))
        trim = K.mat("Mill Trim", (0.36, 0.28, 0.24), rough=0.7, grain=(12.0, 0.3))
        cap = K.mat("Mill Cap", (0.3, 0.24, 0.22), rough=0.8, grain=(20.0, 0.4) if high else None)
        glass = K.mat("Mill Window", (0.25, 0.3, 0.38), rough=0.2, emit=0.3, emit_rgb=(1.0, 0.8, 0.5))
        obs = []
        seg = 48 if high else 16
        prof = []
        for i in range(29 if high else 2):
            y = 14.0 * i / (28 if high else 1)
            r = mill_r(y)
            if high and i % 2 == 1:
                r -= 0.03                          # the stone courses' mortar lines
            prof.append((r, y))
        obs.append(spun("Tower", [(0.0, 0.0)] + prof + [(0.0, 14.0)], wall, col, seg=seg))
        if high:
            for y in (0.35, 4.8, 9.6):              # tarred bands
                r = mill_r(y)
                obs.append(spun("Band", [(r - 0.02, y - 0.12), (r + 0.06, y - 0.1), (r + 0.06, y + 0.1),
                                         (r - 0.02, y + 0.12)], trim, col, seg=seg))
        # door at +Z and windows round the tower
        r = mill_r(1.1)
        obs.append(gbox("Door", (1.3, 2.3, 0.2), (0, 1.15, r - 0.05), trim, col, bevel=0.02 if high else 0.0))
        if high:
            for x in (-0.33, 0.0, 0.33):
                obs.append(gbox("Door Plank", (0.04, 2.2, 0.04), (x, 1.15, r + 0.06), cap, col))
            obs.append(gbox("Door Hinge", (1.1, 0.06, 0.04), (0, 1.8, r + 0.07), cap, col))
            obs.append(gbox("Door Hinge", (1.1, 0.06, 0.04), (0, 0.5, r + 0.07), cap, col))
            obs.append(gbox("Step", (1.6, 0.2, 0.6), (0, 0.1, r + 0.25), K.mat("Step Stone", (0.55, 0.53, 0.55), rough=0.9),
                            col, bevel=0.03))
        for (y, ang) in ((5.5, 0.0), (8.0, 1.9), (10.5, -1.6), (6.5, math.pi), (11.5, 0.6)):
            r = mill_r(y)
            p = (math.sin(ang) * (r - 0.02), y, math.cos(ang) * (r - 0.02))
            obs.append(gbox("Window", (0.7, 1.0, 0.18), p, glass, col, rot=(0, ang, 0)))
            if high:
                q = (math.sin(ang) * (r + 0.06), y, math.cos(ang) * (r + 0.06))
                obs.append(gbox("Window Frame", (0.86, 0.1, 0.1), (q[0], y + 0.53, q[2]), trim, col, rot=(0, ang, 0)))
                obs.append(gbox("Window Frame", (0.86, 0.1, 0.1), (q[0], y - 0.53, q[2]), trim, col, rot=(0, ang, 0)))
                obs.append(gbox("Window Bar", (0.06, 1.0, 0.06), q, trim, col, rot=(0, ang, 0)))
                obs.append(gbox("Shutter", (0.36, 1.06, 0.05),
                                (q[0] + math.cos(ang) * 0.62, y, q[2] - math.sin(ang) * 0.62), cap, col, rot=(0, ang, 0)))
        # cap: an ogee of shingles
        cprof = [(2.25, 13.7), (2.4, 13.85), (2.35, 14.4), (2.1, 15.2), (1.5, 15.9), (0.8, 16.35), (0.25, 16.6), (0.0, 16.62)]
        if high:
            fine = []
            for i in range(len(cprof) - 1):
                (r0, y0), (r1, y1) = cprof[i], cprof[i + 1]
                for j in range(4):
                    t = j / 4
                    fine.append((r0 + (r1 - r0) * t + (0.03 if j % 2 else 0.0), y0 + (y1 - y0) * t))
            fine.append(cprof[-1])
            cprof = fine
        obs.append(spun("Cap", [(0.0, 13.7)] + cprof, cap, col, seg=seg))
        if high:
            obs.append(spun("Finial", [(0.0, 16.55), (0.1, 16.6), (0.05, 16.9), (0.12, 17.0), (0.0, 17.15)],
                            trim, col, seg=12))
        # windshaft out to the sails (they sit at z 2.4, y 13)
        obs.append(grod("Windshaft", (0, 13.0, 1.4), (0, 13.0, 2.3), 0.28, trim, col, seg=16 if high else 8))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ sails
def mill_sails():
    def arm_at(lx, ly, z, a):
        return (lx * math.cos(a) - ly * math.sin(a), lx * math.sin(a) + ly * math.cos(a), z)

    def build(col, high):
        wood = plank_mat("Sail Wood", SAIL)
        cloth = K.mat("Sailcloth", CLOTH, rough=0.95, bump=0.2 if high else 0.0)
        iron = K.mat("Hub Iron", (0.2, 0.19, 0.22), rough=0.5, metal=0.7)
        obs = [grod("Hub", (0, 0, -0.3), (0, 0, 0.35), 0.45, iron, col, seg=20 if high else 10)]
        for k in range(4):
            a = k * math.pi / 2.0
            obs.append(gbox("Stock", (0.24, 7.2, 0.24), arm_at(0, 3.6, 0.12, a), wood, col, rot=(0, 0, a),
                            bevel=0.02 if high else 0.0))
            if high:
                for sx in (-0.68, 0.68):
                    obs.append(gbox("Sail Bar", (0.07, 5.9, 0.08), arm_at(sx, 4.05, 0.0, a), wood, col, rot=(0, 0, a)))
                for j in range(11):
                    ly = 1.15 + j * 0.58
                    obs.append(gbox("Sail Lath", (1.42, 0.05, 0.06), arm_at(0, ly, 0.0, a), wood, col, rot=(0, 0, a)))
                # the cloth, laced on the trailing side, bellied a little
                for j in range(10):
                    ly = 1.45 + j * 0.58
                    belly = 0.04 * math.sin(math.pi * (j + 0.5) / 10)
                    obs.append(gbox("Cloth", (1.3, 0.55, 0.025), arm_at(0.0, ly, -0.05 - belly, a), cloth, col,
                                    rot=(0, 0, a)))
                obs.append(gbox("Lace", (0.03, 5.8, 0.03), arm_at(-0.66, 4.05, -0.05, a), iron, col, rot=(0, 0, a)))
            else:
                obs.append(gbox("Sail Board", (1.4, 5.8, 0.1), arm_at(0, 4.05, 0.0, a), cloth, col, rot=(0, 0, a)))
        if high:
            obs.append(grod("Hub Cap", (0, 0, 0.35), (0, 0, 0.5), 0.3, iron, col, seg=16, r2=0.12))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ silo
def silo():
    def build(col, high):
        steel = K.mat("Silo Steel", SILO, rough=0.4, metal=0.7, pits=0.2 if high else 0.0)
        cap = K.mat("Silo Cap", SILO_CAP, rough=0.45, metal=0.6)
        conc = K.mat("Silo Foundation", (0.6, 0.58, 0.56), rough=0.95, bump=0.3)
        rust = K.mat("Ladder", (0.42, 0.3, 0.24), rough=0.6, metal=0.5)
        obs = []
        seg = 56 if high else 24
        if high:
            prof = [(0.0, 0.0)]
            n = 128
            for i in range(n + 1):
                y = 16.0 * i / n
                prof.append((3.0 - (0.035 if i % 2 else 0.0), y))
            prof.append((0.0, 16.0))
            obs.append(spun("Silo Wall", prof, steel, col, seg=seg))
            for y in (2.0, 5.0, 8.0, 11.0, 14.0):
                obs.append(spun("Seam", [(2.99, y - 0.06), (3.05, y - 0.05), (3.05, y + 0.05), (2.99, y + 0.06)],
                                cap, col, seg=seg))
            obs.append(spun("Foundation", [(0.0, -0.1), (3.35, -0.1), (3.35, 0.35), (3.0, 0.4), (0.0, 0.4)], conc, col, seg=seg))
            for sz in (-0.25, 0.25):               # the ladder up the +X side
                obs.append(grod("Ladder Rail", (3.2, 0.4, sz), (3.2, 16.3, sz), 0.03, rust, col, seg=6))
            for j in range(40):
                y = 0.8 + j * 0.4
                obs.append(grod("Rung", (3.2, y, -0.25), (3.2, y, 0.25), 0.02, rust, col, seg=6))
            for y in (2.0, 8.0, 14.0):
                obs.append(grod("Ladder Strap", (3.0, y, 0), (3.2, y, 0), 0.03, rust, col, seg=6))
        else:
            obs.append(spun("Silo Wall", [(0.0, 0.0), (3.0, 0.0), (3.0, 16.0), (0.0, 16.0)], steel, col, seg=seg))
        dprof = [(3.02, 16.0)]
        for i in range(1, 9 if high else 5):
            t = i / (8 if high else 4) * math.pi / 2.0
            dprof.append((3.02 * math.cos(t), 16.0 + 1.5 * math.sin(t)))
        obs.append(spun("Dome", [(0.0, 15.9)] + dprof, cap, col, seg=seg))
        obs.append(spun("Vent", [(0.0, 17.4), (0.3, 17.4), (0.3, 17.75), (0.45, 17.75), (0.0, 18.0)], cap, col,
                        seg=16 if high else 8))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ Moon Clock pillar
def pillar_r(y):
    return 2.6 - y / 16.0


def clock_pillar():
    def build(col, high):
        obs = []
        if high:
            stone = painted("Pillar Stone", rough=0.9, bump=0.5)
            mortar = K.mat("Pillar Mortar", mix(PILLAR, (0, 0, 0), 0.4), rough=1.0)
            obs.append(ngon("Pillar Core", 7, pillar_r(0) - 0.25, pillar_r(16) - 0.25, 0.4, 16.0, mortar, col))
            obs.append(ngon("Plinth", 7, 2.95, 2.85, 0.0, 0.6, stone, col,
                            colour=stone_colour(mix(PILLAR, (1, 1, 1), 0.06), 3.0, moss_up=0.6)))
            courses = 18
            h = (15.9 - 0.6) / courses
            rnd = random.Random(7)
            for c in range(courses):
                y = 0.6 + h * (c + 0.5)
                R = pillar_r(y)
                ap = R * math.cos(math.pi / 7)
                w = 2.0 * R * math.sin(math.pi / 7)
                for j in range(7):
                    th = (j + 0.5) * math.tau / 7
                    splits = [(-0.25, 0.5), (0.25, 0.5)] if (c + j) % 2 else [(0.0, 1.0)]
                    for (off, frac) in splits:
                        seed = c * 7 + j + off
                        sz = (w * frac - 0.05, h - 0.05, 0.46)
                        base = mix(PILLAR, (0.4, 0.37, 0.48) if rnd.random() < 0.5 else (0.18, 0.16, 0.24), rnd.random() * 0.5)
                        ob = rounded_block("Stone", sz, 0.05, 4, stone, col, push=chisel(1.0, seed),
                                           colour=stone_colour(base, seed, moss_up=0.5 if c < 5 else 0.8))
                        cx = math.sin(th) * (ap - 0.2) + math.cos(th) * off * w
                        cz = math.cos(th) * (ap - 0.2) - math.sin(th) * off * w
                        ob.location = Vector(at(cx, y, cz))
                        ob.rotation_euler = (0.0, 0.0, th)
                        obs.append(ob)
            obs.append(ngon("Cap Slab", 7, 1.82, 1.72, 15.9, 16.25, stone, col,
                            colour=stone_colour(mix(PILLAR, (1, 1, 1), 0.1), 9.0)))
        else:
            m = K.mat("Pillar Stone", PILLAR, rough=0.9)
            obs.append(ngon("Plinth", 7, 2.95, 2.85, 0.0, 0.6, m, col))
            obs.append(ngon("Pillar", 7, pillar_r(0.6) + 0.03, pillar_r(15.9) + 0.03, 0.6, 15.9, m, col))
            obs.append(ngon("Cap Slab", 7, 1.82, 1.72, 15.9, 16.25, m, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ observatory
def drum_r(y):
    return 6.5 - 0.1 * (y + 0.5)


def observatory():
    def build(col, high):
        wall = K.mat("Observatory Wall", OBS, rough=0.7, bump=0.3 if high else 0.0)
        trim = K.mat("Observatory Trim", mix(OBS, (0.5, 0.45, 0.6), 0.35), rough=0.6)
        dome = K.mat("Observatory Dome", DOME, rough=0.35, metal=0.3, emit=0.3, emit_rgb=DOME)
        gold = K.mat("Observatory Gold", GOLD, rough=0.25, metal=1.0, emit=0.4, emit_rgb=GOLD)
        glass = K.mat("Observatory Window", (0.3, 0.35, 0.6), rough=0.15, emit=0.8, emit_rgb=(0.7, 0.85, 1.0))
        dark = K.mat("Dome Slit", DARK, rough=0.6)
        obs = []
        seg = 64 if high else 24
        obs.append(spun("Drum", [(0.0, -0.5), (6.5, -0.5), (6.0, 4.5), (0.0, 4.5)], wall, col, seg=seg))
        if high:
            obs.append(spun("Base Course", [(6.5, -0.5), (6.65, -0.45), (6.62, 0.3), (6.42, 0.35)], trim, col, seg=seg))
            obs.append(spun("Cornice", [(6.0, 4.0), (6.22, 4.1), (6.3, 4.35), (6.2, 4.55), (5.9, 4.6)], trim, col, seg=seg))
            for k in range(12):                     # pilasters round the drum
                a = k * math.tau / 12 + math.tau / 24
                r = drum_r(1.9) + 0.05
                obs.append(gbox("Pilaster", (0.5, 4.2, 0.2), (math.sin(a) * r, 1.9, math.cos(a) * r), trim, col,
                                rot=(-0.1, a, 0), bevel=0.02))
        for k in range(12):                         # windows between them, the door at +Z
            a = k * math.tau / 12
            r = drum_r(2.6) - 0.03
            if k == 0:
                obs.append(gbox("Door", (1.6, 2.6, 0.3), (0, 0.8, drum_r(0.8) - 0.08), trim, col, rot=(-0.1, 0, 0)))
                if high:
                    obs.append(gbox("Door Arch", (2.0, 0.3, 0.32), (0, 2.2, drum_r(2.2) + 0.02), gold, col,
                                    rot=(-0.1, 0, 0), bevel=0.03))
                continue
            obs.append(gbox("Window", (0.8, 1.4, 0.2), (math.sin(a) * r, 2.6, math.cos(a) * r), glass, col, rot=(-0.1, a, 0)))
            if high:
                q = r + 0.08
                obs.append(gbox("Sill", (1.0, 0.12, 0.3), (math.sin(a) * q, 1.85, math.cos(a) * q), trim, col, rot=(-0.1, a, 0)))
                obs.append(blob("Keystone", 0.12, (math.sin(a) * q, 3.4, math.cos(a) * q), gold, col, seg=6, lump=0.0))
        # the dome: half an ellipsoid, 6 across and 3 up from 4.5
        dp = [(0.0, 4.5)]
        nd = 16 if high else 8
        for i in range(nd + 1):
            t = i / nd * math.pi / 2.0
            dp.append((6.0 * math.cos(t), 4.5 + 3.0 * math.sin(t)))
        obs.append(spun("Dome", dp, dome, col, seg=seg))
        if high:
            for k in range(16):                     # gold ribs
                a = k * math.tau / 16
                pts = [(math.sin(a) * 6.04 * math.cos(t), 4.5 + 3.03 * math.sin(t), math.cos(a) * 6.04 * math.cos(t))
                       for t in [j / 12 * math.pi / 2.0 for j in range(13)]]
                obs.append(gwire("Rib", pts, 0.05, gold, col, res=2, bevel_res=2))
            obs.append(spun("Dome Ring", [(6.0, 4.45), (6.12, 4.5), (6.08, 4.65), (5.98, 4.66)], gold, col, seg=seg))
        # the slit, from the top down towards +X, where the telescope looks out
        for j in range(8):
            t = (j + 0.5) / 8 * math.pi / 2.0 * 0.9
            x, y = 6.02 * math.cos(math.pi / 2 - t), 4.5 + 3.02 * math.sin(math.pi / 2 - t)
            obs.append(gbox("Slit", (0.95, 0.12, 0.9), (x, y, 0.0), dark, col, rot=(0, 0, -t)))
        # the brass telescope from its eyepiece end up and out
        a = Vector((-0.25, 5.32, 0.0))
        b = Vector((4.25, 10.68, 0.0))
        d = (b - a).normalized()
        obs.append(grod("Telescope", tuple(a), tuple(b), 1.15, gold, col, seg=24 if high else 12, r2=0.88))
        if high:
            for f in (0.08, 0.35, 0.62, 0.97):
                p = a + (b - a) * f
                r = 1.15 + (0.88 - 1.15) * f + 0.06
                obs.append(grod("Scope Ring", tuple(p - d * 0.08), tuple(p + d * 0.08), r, trim, col, seg=24))
            obs.append(grod("Lens", tuple(b), tuple(b + d * 0.05), 0.8, glass, col, seg=24))
            obs.append(grod("Finder", tuple(a + d * 2.0 + Vector((-0.75, 0.62, 0.8))), tuple(a + d * 4.0 + Vector((-0.75, 0.62, 0.8))),
                            0.16, gold, col, seg=12))
            obs.append(blob("Finial", 0.25, (0, 7.75, 0), gold, col, seg=10, lump=0.0))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "stand_earth": (stand_earth, 2048, 0.06, 0.15, True, False),
    "stand_void": (stand_void, 2048, 0.06, 0.15, True, False),
    "windmill": (windmill, 1024, 0.08, 0.2, True, True),
    "mill_sails": (mill_sails, 1024, 0.06, 0.15, False, False),
    "silo": (silo, 1024, 0.06, 0.15, True, False),
    "clock_pillar": (clock_pillar, 2048, 0.12, 0.3, True, False),
    "observatory": (observatory, 2048, 0.12, 0.3, True, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao, emit=emit)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

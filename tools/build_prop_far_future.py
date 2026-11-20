# Lumen City, the Far Future, built the detailed way (tools/bake_kit.py; 20 Nov 2026, Hayden: "Then keep baking
# details", the portal worlds' props after the Frozen Moment): the Tomorrow Clock, the Fading Plaza's hologram
# fountain and benches, and the lanes' streetlight posts. Each HIGH version is baked onto a LOW one, which is what the
# game draws. The towers' glass walls are a tiling patch instead (tools/build_prop_surfaces.py glass_facade).
#
# Sizes match the pieces tools/build_far_future.gd builds from shapes, so the swap (scripts/detail_props.gd
# dress_far_future) puts each where the old one was and every collision stays the game's. Nothing here glows: the
# city's neon (the clock's seams and tip, the rims, the bulbs, the hologram) is left as it is, because the city dims it
# while it's fading (scripts/far_future.gd set_fade). Blender's X is Godot's X, Blender's -Y is Godot's +Z and
# Blender's Z is Godot's Y.
#   clock_spire    the Tomorrow Clock without its neon: the round dais 13 m across (top at 0.4, its collision's) with
#                  inlaid rings and seams, the six-sided spire tapering from 2.4 to 1.2 up to 22.4 m with ribbed
#                  edges, panels, collars and a square clock housing behind the four faces, and the three sockets.
#   street_post    a streetlight's post, 3 m: a six-sided foot, a fluted stem with collars, a little display, and a
#                  cradle of three prongs and a ring that holds the old glowing bulb.
#   holo_fountain  the hologram fountain's basin, 2.6 m across and 0.7 tall: fluted sides, a lip, a shallow bowl with
#                  emitter rings and a projector post in the middle (the old turning globe floats over it).
#   hover_bench    a plaza bench, 2.4 x 0.5 x 0.7: a slatted seat on two sculpted feet.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_far_future.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402


KINDS = ["clock_spire", "street_post", "holo_fountain", "hover_bench"]
KIND = next((a for a in sys.argv if a in KINDS), "clock_spire")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

DAIS = (0.35, 0.33, 0.55)
DAIS_DARK = (0.22, 0.2, 0.36)
SPIRE = (0.82, 0.86, 1.0)
SPIRE_DARK = (0.55, 0.6, 0.78)
GOLD = (1.0, 0.8, 0.42)
INLAY = (0.16, 0.16, 0.3)
POST = (0.3, 0.3, 0.45)
FOUNTAIN = (0.75, 0.78, 0.95)
BENCH = (0.85, 0.85, 1.0)

DAIS_R = 13.0
DAIS_H = 0.4
SPIRE_B, SPIRE_T, SPIRE_TOP = 2.4, 1.2, 22.4
HOUSE_Y0, HOUSE_Y1, HOUSE_W = 13.6, 19.2, 2.0


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
def slab(name, c, u, v, w, h, t, m, col):
    """A flat plate (Godot): centred on c, w along u, h along v, t thick out along u x v."""
    c, u, v = Vector(c), Vector(u).normalized(), Vector(v).normalized()
    n = u.cross(v).normalized()
    bm = bmesh.new()
    vs = []
    for dz in (-t / 2, t / 2):
        for du, dv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(bm.verts.new(at(*(c + u * du * w / 2 + v * dv * h / 2 + n * dz))))
    for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, False, col)


def glathe(name, prof, m, col, seg=32, pos=(0, 0, 0), spin=0.0, **kw):
    """K.lathe with the profile in Godot's (radius, y), round Godot's Y, at a Godot position, turned by spin."""
    ob = K.lathe(name, prof, seg=seg, m=m, col=col, **kw)
    ob.location = at(*pos)
    ob.rotation_euler = (0, 0, spin)
    return ob


# ================================================================ the Tomorrow Clock
def clock_spire():
    dais = mottled("Clock Dais", DAIS, DAIS_DARK, scale=0.35, rough=0.4, metal=0.4, bump=0.05, lo=0.42, hi=0.62)
    inlay = K.mat("Clock Inlay", INLAY, rough=0.3, metal=0.6)
    gold = K.mat("Clock Gold", GOLD, rough=0.3, metal=0.9, pits=0.1)
    spire = K.mat("Clock Spire", SPIRE, rough=0.25, metal=0.6, pits=0.05)
    panel = K.mat("Clock Panel", SPIRE_DARK, rough=0.3, metal=0.6, pits=0.08)
    hexa = math.radians(30)          # Godot's 6-sided cylinder has a corner towards +Z; so does this, turned 30

    def ap(y):
        """The spire's half-width across its flats at height y."""
        r = SPIRE_B + (SPIRE_T - SPIRE_B) * (y - DAIS_H) / (SPIRE_TOP - DAIS_H)
        return r * math.cos(math.pi / 6)

    def build(col, high):
        obs = []
        prof = [(0.0, 0.0), (DAIS_R + 0.3, 0.0), (DAIS_R + 0.28, 0.08), (DAIS_R + 0.06, 0.3), (DAIS_R, DAIS_H),
                (0.0, DAIS_H)]
        obs.append(glathe("Dais", prof, dais, col, seg=128 if high else 48, flutes=96 if high else 0,
                          flute_depth=0.03, flute_z=(0.06, 0.28)))
        obs.append(glathe("Spire", [(0.0, DAIS_H - 0.05), (SPIRE_B, DAIS_H - 0.05), (SPIRE_T, SPIRE_TOP),
                                    (0.0, SPIRE_TOP)], spire, col, seg=6, spin=hexa, smooth=False))
        # the clock's housing: a square block round the spire behind the four faces, a cornice top and bottom
        mid = (HOUSE_Y0 + HOUSE_Y1) / 2
        obs.append(gbox("Housing", (HOUSE_W * 2, HOUSE_Y1 - HOUSE_Y0, HOUSE_W * 2), (0, mid, 0), spire, col,
                        bevel=0.04 if high else 0.0))
        for y, w in ((HOUSE_Y0 + 0.12, HOUSE_W + 0.14), (HOUSE_Y1 - 0.12, HOUSE_W + 0.18)):
            obs.append(gbox("Cornice", (w * 2, 0.24, w * 2), (0, y, 0), gold if high else spire, col,
                            bevel=0.05 if high else 0.0))
        # the three sockets round the spire's foot
        sock = [(0.0, DAIS_H - 0.05), (0.95, DAIS_H - 0.05), (0.92, DAIS_H + 0.12), (0.76, DAIS_H + 0.2),
                (0.7, DAIS_H + 0.85), (0.82, DAIS_H + 0.9), (0.82, DAIS_H + 1.0), (0.0, DAIS_H + 1.0)]
        for i in range(3):
            a = math.pi / 2 + (i - 1) * 2.1
            p = (math.cos(a) * 4.6, 0, math.sin(a) * 4.6)
            obs.append(glathe("Socket", sock, dais, col, seg=8, pos=p, smooth=False))
            if high:
                for y in (DAIS_H + 0.3, DAIS_H + 0.75):
                    obs.append(gwire("Band", ring_pts((p[0], y, p[2]), (0, 1, 0), 0.76 if y > 1 else 0.82, 32),
                                     0.03, gold, col, closed=True, res=2, bevel_res=3))
                obs.append(gwire("Cup", ring_pts((p[0], DAIS_H + 1.0, p[2]), (0, 1, 0), 0.6, 32), 0.05, gold, col,
                                 closed=True, res=2, bevel_res=3))
        if not high:
            return obs
        # ---- the dais' top: inlaid rings, seams between them, a ring of round plates, a compass of gold
        for r in (3.4, 7.0, 10.6, 12.6):
            obs.append(gwire("Ring", ring_pts((0, DAIS_H, 0), (0, 1, 0), r, 160), 0.06, inlay, col, closed=True,
                             res=2, bevel_res=2))
        for k in range(24):
            a = k * math.tau / 24
            q = Vector((math.cos(a), 0, math.sin(a)))
            r0 = 3.4 if k % 2 == 0 else 7.0
            obs.append(gwire("Seam", [tuple(q * r0 + Vector((0, DAIS_H, 0))), tuple(q * 12.6 + Vector((0, DAIS_H, 0)))],
                             0.035, inlay, col, res=2, bevel_res=2))
        for k in range(24):
            a = (k + 0.5) * math.tau / 24
            q = Vector((math.cos(a), 0, math.sin(a))) * 8.8
            obs.append(gwire("Plate", ring_pts((q.x, DAIS_H, q.z), (0, 1, 0), 0.45, 24), 0.04, gold, col,
                             closed=True, res=2, bevel_res=2))
        for k in range(4):
            a = k * math.tau / 4
            q = Vector((math.cos(a), 0, math.sin(a)))
            t = Vector((-q.z, 0, q.x))
            tip = q * 6.6 + Vector((0, DAIS_H, 0))
            for s in (-1, 1):
                obs.append(gwire("Point", [tuple(q * 3.6 + t * s * 0.5 + Vector((0, DAIS_H, 0))), tuple(tip)], 0.04,
                                 gold, col, res=2, bevel_res=2))
        # ---- the spire: a rib up each corner, collars, panels on its six sides with slits between
        for k in range(6):
            a = hexa + k * math.tau / 6
            d0 = Vector((math.cos(a), 0, -math.sin(a)))
            obs.append(grod("Rib", tuple(d0 * SPIRE_B + Vector((0, DAIS_H, 0))), tuple(d0 * SPIRE_T + Vector((0, SPIRE_TOP, 0))),
                            0.08, panel, col, seg=8))
        for y in (2.4, 6.0, 9.6, 12.6, 20.2):
            r = SPIRE_B + (SPIRE_T - SPIRE_B) * (y - DAIS_H) / (SPIRE_TOP - DAIS_H)
            obs.append(glathe("Collar", [(0.0, y - 0.14), (r + 0.1, y - 0.14), (r + 0.14, y - 0.07), (r + 0.14, y + 0.07),
                                         (r + 0.1, y + 0.14), (0.0, y + 0.14)], gold, col, seg=6, spin=hexa,
                              smooth=False))
        slope = math.atan((SPIRE_B - SPIRE_T) * math.cos(math.pi / 6) / (SPIRE_TOP - DAIS_H))
        for k in range(6):
            a = k * math.tau / 6                       # each flat side faces this way (between two corners)
            q = Vector((math.cos(a), 0, math.sin(a)))
            t = Vector((-q.z, 0, q.x))
            up = (Vector((0, 1, 0)) * math.cos(slope) - q * math.sin(slope)).normalized()
            for y0, y1 in ((0.7, 2.2), (2.7, 5.8), (6.3, 9.4), (9.9, 12.4), (19.6, 20.0), (20.5, 22.0)):
                y = (y0 + y1) / 2
                w = ap(y) * math.tan(math.pi / 6) * 2 * 0.7
                c = q * (ap(y) + 0.02) + Vector((0, y, 0))
                obs.append(slab("Panel", c, t, up, w, y1 - y0, 0.06, panel, col))
                if y1 - y0 > 2.0:
                    obs.append(slab("Slit", c + q * 0.03, t, up, w * 0.16, (y1 - y0) * 0.7, 0.04, inlay, col))
        # ---- the housing: pilasters on its corners (the faces cover the rest of it)
        for sx in (-1, 1):
            for sz in (-1, 1):
                obs.append(gbox("Pilaster", (0.3, HOUSE_Y1 - HOUSE_Y0 - 0.5, 0.3),
                                (sx * (HOUSE_W - 0.05), (HOUSE_Y0 + HOUSE_Y1) / 2, sz * (HOUSE_W - 0.05)), gold, col,
                                bevel=0.04))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a streetlight's post
def street_post():
    post = K.mat("Post Metal", POST, rough=0.4, metal=0.6, pits=0.1)
    trim = K.mat("Post Trim", (0.75, 0.78, 0.95), rough=0.3, metal=0.8)
    screen = K.mat("Post Screen", (0.12, 0.14, 0.25), rough=0.15, metal=0.3)

    def build(col, high):
        obs = [glathe("Foot", [(0.0, 0.0), (0.26, 0.0), (0.26, 0.1), (0.2, 0.18), (0.13, 0.24), (0.0, 0.24)], post, col,
                      seg=6, smooth=False),
               glathe("Stem", [(0.0, 0.2), (0.1, 0.2), (0.07, 2.78), (0.0, 2.78)], post, col, seg=24 if high else 8,
                      flutes=8 if high else 0, flute_depth=0.012, flute_z=(0.3, 2.7)),
               glathe("Cup", [(0.0, 2.72), (0.08, 2.72), (0.15, 2.84), (0.13, 2.9), (0.0, 2.88)], trim, col,
                      seg=24 if high else 8)]
        bulb_y, ring_r = 3.1, 0.31
        obs.append(gwire("Ring", ring_pts((0, bulb_y, 0), (0, 1, 0), ring_r, 32 if high else 10), 0.022, trim, col,
                         closed=True, res=2 if high else 1, bevel_res=3 if high else 1))
        for k in range(3):
            a = k * math.tau / 3
            q = Vector((math.cos(a), 0, math.sin(a)))
            pts = [tuple(q * 0.1 + Vector((0, 2.84, 0))), tuple(q * 0.24 + Vector((0, 2.92, 0))),
                   tuple(q * ring_r + Vector((0, bulb_y, 0)))]
            obs.append(gwire("Prong", pts, 0.022, trim, col, res=8 if high else 2, bevel_res=3 if high else 1))
        obs.append(gbox("Display", (0.1, 0.34, 0.16), (0.08, 1.45, 0), post, col, bevel=0.015 if high else 0.0))
        if high:
            obs.append(gbox("Screen", (0.02, 0.26, 0.12), (0.135, 1.47, 0), screen, col))
            for y in (0.32, 0.95, 2.1, 2.6):
                obs.append(glathe("Collar", [(0.0, y - 0.04), (0.115 - y * 0.012, y - 0.04), (0.13 - y * 0.012, y),
                                             (0.115 - y * 0.012, y + 0.04), (0.0, y + 0.04)], trim, col, seg=24))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the hologram fountain's basin
def holo_fountain():
    basin = mottled("Fountain Basin", FOUNTAIN, (0.62, 0.65, 0.85), scale=1.2, rough=0.3, metal=0.4, bump=0.04)
    bowl = K.mat("Fountain Bowl", (0.2, 0.22, 0.38), rough=0.15, metal=0.5)
    trim = K.mat("Fountain Trim", GOLD, rough=0.3, metal=0.9)
    prof = [(0.0, 0.0), (2.62, 0.0), (2.62, 0.06), (2.56, 0.1), (2.42, 0.6), (2.5, 0.64), (2.5, 0.72), (2.28, 0.72),
            (2.2, 0.62), (0.6, 0.5), (0.46, 0.55), (0.38, 0.95), (0.5, 1.0), (0.5, 1.06), (0.0, 1.06)]

    def build(col, high):
        obs = [glathe("Basin", prof, basin, col, seg=96 if high else 32, flutes=32 if high else 0, flute_depth=0.05,
                      flute_z=(0.14, 0.56))]
        if not high:
            return obs
        # the bowl's floor in a darker glassy colour, with emitter rings, and a lens on the projector post
        obs.append(glathe("Floor", [(0.0, 0.51), (0.6, 0.506), (2.2, 0.626), (2.2, 0.634), (0.6, 0.514), (0.0, 0.518)],
                          bowl, col, seg=96))
        for r in (0.95, 1.45, 1.95):
            y = 0.5 + (r - 0.6) / 1.6 * 0.12 + 0.005
            obs.append(gwire("Emitter", ring_pts((0, y, 0), (0, 1, 0), r, 96), 0.03, trim, col, closed=True, res=2,
                             bevel_res=3))
        obs.append(gwire("Lip", ring_pts((0, 0.72, 0), (0, 1, 0), 2.39, 128), 0.035, trim, col, closed=True, res=2,
                         bevel_res=3))
        obs.append(K.sphere("Lens", 0.24, at=at(0, 1.06, 0), m=bowl, seg=24, scale=(1, 1, 0.45), col=col))
        for k in range(8):
            a = k * math.tau / 8
            q = Vector((math.cos(a), 0, math.sin(a)))
            obs.append(slab("Vent", q * 0.43 + Vector((0, 0.78, 0)), Vector((-q.z, 0, q.x)), Vector((0, 1, 0)), 0.12,
                            0.22, 0.04, bowl, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a plaza bench
def hover_bench():
    seat = mottled("Bench Seat", BENCH, (0.72, 0.72, 0.9), scale=3.0, rough=0.4, metal=0.4, bump=0.03)
    foot = K.mat("Bench Foot", (0.55, 0.55, 0.75), rough=0.35, metal=0.6, pits=0.08)
    gap = K.mat("Bench Gap", (0.2, 0.2, 0.32), rough=0.5, metal=0.4)

    def build(col, high):
        obs = []
        if high:
            for i in range(7):
                z = -0.3 + i * 0.1
                obs.append(gbox("Slat", (2.4, 0.1, 0.085), (0, 0.45, z), seat, col, bevel=0.025))
            obs.append(gbox("Under", (2.3, 0.04, 0.66), (0, 0.42, 0), gap, col))
            for sx in (-1.18, 1.18):
                obs.append(gbox("End", (0.06, 0.13, 0.72), (sx, 0.44, 0), foot, col, bevel=0.02))
        else:
            obs.append(gbox("Seat", (2.42, 0.12, 0.72), (0, 0.44, 0), seat, col))
        for sx in (-0.82, 0.82):
            obs.append(glathe("Foot", [(0.0, 0.0), (0.3, 0.0), (0.3, 0.05), (0.16, 0.12), (0.12, 0.3), (0.2, 0.38),
                                       (0.0, 0.38)], foot, col, seg=24 if high else 8, pos=(sx, 0, 0)))
            if high:
                obs.append(gwire("Band", ring_pts((sx, 0.22, 0), (0, 1, 0), 0.13, 24), 0.018, gap, col, closed=True,
                                 res=2, bevel_res=2))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao = {
    "clock_spire": (clock_spire, 2048, 0.25, 0.45, True),
    "street_post": (street_post, 512, 0.04, 0.1, True),
    "holo_fountain": (holo_fountain, 1024, 0.06, 0.15, True),
    "hover_bench": (hover_bench, 512, 0.05, 0.12, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

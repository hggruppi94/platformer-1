# Parts of the bosses that are built from shapes in code, made the detailed way (tools/bake_kit.py; 25 Nov 2026,
# Hayden: "keep baking details on assets in the game already"). Each HIGH version is baked onto a LOW one, which is
# what the game draws (scripts/detail_props.gd swaps it in for the plain shapes; the boss's own nodes stay, so
# nothing that moves changes).
#
# Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   king_crown   the Gloop King's little crown (tools/build_gloop.gd _crown) at ten times its size: a gold band of
#                radius 1 from y 0 to 0.6, carved with scrolls between beaded edges, five flat points round it
#                (radius 0.92, up to y 1.6), each with a raised rim, an engraved teardrop and a ball on its tip, and
#                the red gem at the front in a ring of gold with four prongs. The game scales it by 0.1.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_bosses.py "<out>.glb" <kind> [--preview]
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["king_crown"]
KIND = next((a for a in sys.argv if a in KINDS), "king_crown")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

GOLD = (1.0, 0.74, 0.22)             # the crown's gold (tools/build_gloop.gd)
GOLD_DARK = (0.6, 0.38, 0.1)
GOLD_PALE = (1.0, 0.9, 0.6)
GEM = (0.78, 0.02, 0.2)
GEM_GLOW = (0.9, 0.05, 0.25)


def at(x, y, z):
    """Godot's (x, y, z) in Blender's space."""
    return Vector((x, -z, y))


def to_godot(v):
    return Vector((v.x, v.z, -v.y))


def lin(c):
    return tuple(K.srgb_to_linear(v) for v in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def painted(name, rough=0.5, metal=0.0, bump=0.0, bump_scale=60.0):
    """A material whose colour is the high mesh's own vertex colours ("Col")."""
    m = K.mat(name, (0.7, 0.7, 0.7), rough=rough, metal=metal)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], b.inputs["Base Color"])
    if bump > 0.0:
        co = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = bump_scale
        nz.inputs["Detail"].default_value = 8.0
        nt.links.new(co, nz.inputs["Vector"])
        bmp = nt.nodes.new("ShaderNodeBump")
        bmp.inputs["Strength"].default_value = bump
        bmp.inputs["Distance"].default_value = 0.004
        nt.links.new(nz.outputs["Fac"], bmp.inputs["Height"])
        nt.links.new(bmp.outputs["Normal"], b.inputs["Normal"])
    return m


def colour_mesh(bm, col_fn):
    bm.normal_update()
    layer = bm.loops.layers.color.new("Col")
    cache = {}
    for v in bm.verts:
        cache[v.index] = (*lin(col_fn(to_godot(v.co), to_godot(v.normal))), 1.0)
    for f in bm.faces:
        for lp in f.loops:
            lp[layer] = cache[lp.vert.index]


def colour_obj(ob, col_fn):
    """Vertex colours on an object already made (cylinders, spheres)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    mw = ob.matrix_world.copy()
    bm.normal_update()
    layer = bm.loops.layers.color.new("Col")
    rot = mw.to_3x3()
    for f in bm.faces:
        for lp in f.loops:
            p = mw @ lp.vert.co
            n = (rot @ lp.vert.normal).normalized()
            lp[layer] = (*lin(col_fn(to_godot(p), to_godot(n))), 1.0)
    bm.to_mesh(ob.data)
    bm.free()


def grid_mesh(name, nu, nv, fn, m, coll, closed_u=False, closed_v=False, col_fn=None):
    """A surface from fn(u, v) -> a Godot point, u and v from 0 to 1 over nu by nv quads."""
    bm = bmesh.new()
    cu = nu if closed_u else nu + 1
    cv = nv if closed_v else nv + 1
    vs = [[bm.verts.new(at(*fn(i / nu, j / nv))) for j in range(cv)] for i in range(cu)]
    for i in range(nu):
        for j in range(nv):
            a = vs[i][j]
            b = vs[(i + 1) % cu][j]
            c = vs[(i + 1) % cu][(j + 1) % cv]
            d = vs[i][(j + 1) % cv]
            if len({a, b, c, d}) == 4:
                bm.faces.new((a, b, c, d))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.verts.index_update()
    if col_fn:
        colour_mesh(bm, col_fn)
    return K._obj(name, bm, m, True, coll)


def ring(name, y, R, section, nu, nv, m, coll, push=None, col_fn=None):
    """A ring round Godot's Y at height y and radius R; section(phi) -> (out, up) is its tube's shape, and
    push(theta, phi) moves each point out along the tube (carvings)."""
    def fn(s, t):
        th, ph = s * math.tau, t * math.tau
        radial = Vector((math.sin(th), 0, math.cos(th)))
        sx, sy = section(ph)
        nrm = radial * math.cos(ph) + Vector((0, 1, 0)) * math.sin(ph)
        d = push(th, ph) if push else 0.0
        return tuple(radial * (R + sx) + Vector((0, y + sy, 0)) + nrm * d)
    return grid_mesh(name, nu, nv, fn, m, coll, True, True, col_fn)


def gsphere(name, c, r, m, coll, seg=16, scale=(1, 1, 1)):
    ob = K.sphere(name, r, at=at(*c), m=m, seg=seg, col=coll)
    ob.scale = (scale[0], scale[2], scale[1])
    return ob


def bake_part(name, high, low, size, emit=False, emit_strength=1.0, extrusion=0.03, ray_d=0.1, ao=True):
    hi_tris = K.tri_count(high)
    prop = K.join(name, low)
    lo_tris = K.tri_count([prop])
    K.uv_unwrap(prop, margin=0.004)
    maps = K.bake(prop, high, size=size, name=name, extrusion=extrusion, ray=ray_d,
                  maps=["normal"] + (["ao"] if ao else []) + ["color", "rough", "metal"] + (["emit"] if emit else []))
    K.finish(prop, maps, size, name, emit_strength=emit_strength)
    print("TRIS %s high %d low %d" % (name, hi_tris, lo_tris))
    return prop


# ================================================================ the Gloop King's crown
BAND_R = 1.02
BAND_Y = 0.3                          # the band's middle (it runs from 0 to 0.6)
BAND_HALF = 0.3
BAND_W = 0.05
POINT_R = 0.92
POINT_BASE = 0.55
POINT_TIP = 1.6
POINT_HALF_W = 0.44
POINT_THICK = 0.075
GEM_AT = (0.0, 0.35, 1.1)


def _gold(p, n):
    """Gold that's darker in the hollows and pale on the tops."""
    nz = noise.noise(Vector(p) * 7.0)
    return mix(mix(GOLD, GOLD_DARK, 0.2 + 0.15 * nz), GOLD_PALE, 0.3 * max(0.0, n.y))


def _band_section(ph):
    c, s = math.cos(ph), math.sin(ph)
    p = 6.0
    return (BAND_W * math.copysign(abs(c) ** (2 / p), c), BAND_HALF * math.copysign(abs(s) ** (2 / p), s))


def _scrolls(th, ph):
    """S-shaped scrolls carved round the band's outside, ten round, with a little curl at each end."""
    if math.cos(ph) < 0.4:
        return 0.0
    y = math.sin(ph)                                  # -1 bottom .. 1 top
    if abs(y) > 0.8:
        return 0.0
    cell = (th / math.tau * 10) % 1.0
    x = (cell - 0.5) * 2                              # -1 .. 1 across each scroll
    yy = y / 0.8
    wave = 0.55 * math.sin(math.pi * x)
    d = abs(yy - wave)
    for cx, cy, sg in ((-0.85, -0.35, 1), (0.85, 0.35, -1)):
        r = math.hypot(x - cx, yy - cy)
        d = min(d, abs(r - 0.22))
    if d < 0.07:
        return 0.012
    if d < 0.12:
        return 0.004
    return -0.004


def _point(j, high, low, gold, gold_low):
    """One flat point standing on the band, in the plane facing out at angle j."""
    a = math.tau * j / 5.0
    out = Vector((math.sin(a), 0, math.cos(a)))
    side = Vector((math.cos(a), 0, -math.sin(a)))

    def width(s):
        return POINT_HALF_W * (1 - s) ** 1.15

    def face(sign):
        def fn(u, v):
            x = u * 2 - 1
            s = v
            w = width(s)
            h = POINT_THICK * (1 - abs(x) ** 6) ** 0.5
            # the engraving: a groove that follows the outline, and a raised teardrop in the middle
            carve = 0.0
            if 0.08 < s < 0.85:
                edge = abs(abs(x) - 0.72)
                if edge < 0.06:
                    carve = -0.018
                tx, ty = x * w, s - 0.35
                drop = math.hypot(tx / 0.16, ty / 0.24 if ty < 0 else ty / 0.34)
                if drop < 1.0:
                    carve = 0.02 * (1 - drop ** 4)
            p = out * (POINT_R + sign * (h + max(carve, -h * 0.5))) + side * x * w + Vector((0, POINT_BASE + s *
                                                                                              (POINT_TIP - POINT_BASE), 0))
            return tuple(p)
        return fn
    for sign in (1, -1):
        high.append(grid_mesh("Point", 64, 96, face(sign), gold, HIGH, col_fn=_gold))
    # a raised rim all round its edge
    rim = []
    for k in range(41):
        s = k / 40
        rim.append(at(*(out * POINT_R - side * width(s) + Vector((0, POINT_BASE + s * (POINT_TIP - POINT_BASE), 0)))))
    for k in range(40, -1, -1):
        s = k / 40
        rim.append(at(*(out * POINT_R + side * width(s) + Vector((0, POINT_BASE + s * (POINT_TIP - POINT_BASE), 0)))))
    w = K.wire("Rim", rim, POINT_THICK * 1.1, m=gold, col=HIGH)
    K.to_mesh(w)
    colour_obj(w, _gold)
    high.append(w)
    tip = out * POINT_R + Vector((0, POINT_TIP + 0.04, 0))
    ball = gsphere("Tip", tuple(tip), 0.11, gold, HIGH, seg=24)
    colour_obj(ball, _gold)
    high.append(ball)
    # the low point: a flat plate with the same outline and a little ball
    bm = bmesh.new()
    th = POINT_THICK * 1.6
    front, back = [], []
    for k, s in enumerate((0.0, 0.35, 0.7, 1.0)):
        for sgn in (-1, 1):
            p = out * POINT_R + side * sgn * width(s) * 1.08 + Vector((0, POINT_BASE + s * (POINT_TIP - POINT_BASE) +
                                                                          (0.08 if s == 1.0 else 0.0), 0))
            front.append(bm.verts.new(at(*(p + out * th))))
            back.append(bm.verts.new(at(*(p - out * th))))
    for k in range(3):
        a0, a1, b1, b0 = k * 2, k * 2 + 1, k * 2 + 3, k * 2 + 2
        bm.faces.new((front[a0], front[a1], front[b1], front[b0]))
        bm.faces.new((back[b0], back[b1], back[a1], back[a0]))
        bm.faces.new((front[a0], front[b0], back[b0], back[a0]))
        bm.faces.new((front[b1], front[a1], back[a1], back[b1]))
    bm.faces.new((front[0], back[0], back[1], front[1]))
    bm.faces.new((front[7], front[6], back[6], back[7]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    low.append(K._obj("Point", bm, gold_low, False, LOW))
    low.append(gsphere("Tip", tuple(tip), 0.15, gold_low, LOW, seg=8))


def king_crown():
    gold = painted("Crown Gold", rough=0.28, metal=1.0, bump=0.025, bump_scale=120)
    gem = K.mat("Crown Gem", GEM, rough=0.05, metal=0.3, emit=0.6, emit_rgb=GEM_GLOW)
    gold_low = K.mat("Crown Low", GOLD, rough=0.3, metal=1.0)
    gem_low = K.mat("Gem Low", GEM, rough=0.05, emit=0.6, emit_rgb=GEM_GLOW)
    high, low = [], []
    high.append(ring("Band", BAND_Y, BAND_R, _band_section, 960, 48, gold, HIGH, push=_scrolls, col_fn=_gold))
    for s in (-1, 1):
        y = BAND_Y + s * (BAND_HALF - 0.02)
        high.append(ring("Edge", y, BAND_R + 0.01, lambda ph: (0.075 * math.cos(ph), 0.035 * math.sin(ph)),
                         480, 12, gold, HIGH, col_fn=_gold))
        for k in range(60):
            th = math.tau * (k + 0.5 * (s > 0)) / 60
            c = Vector((math.sin(th), 0, math.cos(th))) * (BAND_R + 0.075) + Vector((0, y, 0))
            b = gsphere("Bead", tuple(c), 0.032, gold, HIGH, seg=10)
            colour_obj(b, _gold)
            high.append(b)
    for j in range(5):
        _point(j, high, low, gold, gold_low)
    # the gem at the front, in a ring of gold with four prongs
    g = Vector(GEM_AT)
    stone = gsphere("Gem", GEM_AT, 0.24, gem, HIGH, seg=8, scale=(1.0, 1.3, 0.6))
    high.append(stone)
    bm = bmesh.new()
    nu, nv = 96, 12
    vs = []
    for i in range(nu):
        th = math.tau * i / nu
        row = []
        for k in range(nv):
            ph = math.tau * k / nv
            rr = 0.27 + 0.035 * math.cos(ph)
            p = g + Vector((math.cos(th) * rr, math.sin(th) * rr * 1.3, -0.02 + 0.035 * math.sin(ph)))
            row.append(bm.verts.new(at(*p)))
        vs.append(row)
    for i in range(nu):
        for k in range(nv):
            bm.faces.new((vs[i][k], vs[(i + 1) % nu][k], vs[(i + 1) % nu][(k + 1) % nv], vs[i][(k + 1) % nv]))
    colour_mesh(bm, _gold)
    high.append(K._obj("Setting", bm, gold, True, HIGH))
    for k in range(4):
        pa = math.tau * (k + 0.5) / 4
        p = g + Vector((math.cos(pa) * 0.22, math.sin(pa) * 0.29, 0.1))
        pr = gsphere("Prong", tuple(p), 0.045, gold, HIGH, seg=10)
        colour_obj(pr, _gold)
        high.append(pr)
    low.append(ring("Band", BAND_Y, BAND_R, lambda ph: ((BAND_W + 0.11) * math.cos(ph) + 0.05,
                                                        (BAND_HALF + 0.05) * math.sin(ph)), 40, 8, gold_low, LOW))
    low.append(gsphere("Gem", tuple(g + Vector((0, 0, 0.04))), 0.32, gem_low, LOW, seg=8, scale=(1.0, 1.3, 0.6)))
    return high, low


fn, size, ext, ray_d, ao, emit, strength = {
    "king_crown": (king_crown, 1024, 0.1, 0.25, True, True, 1.0),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray_d=ray_d, ao=ao, emit=emit, emit_strength=strength)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

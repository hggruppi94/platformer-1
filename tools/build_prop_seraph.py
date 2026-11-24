# The Seraph, the Skyreach Trail's angel (scripts/starhorn.gd), built the detailed way (tools/bake_kit.py; 24 Nov
# 2026, Hayden: "Can you bake detail into the seraph", "Like a lot of detail"). Each HIGH version is baked onto a LOW
# one, which is what the game draws. The game's own nodes (pivots, spinners, eyes) stay as they are, so its wings
# still beat, its wheels still turn and every eye still blinks: these meshes only stand in for the plain shapes.
#
# Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   seraph_eye      an eye of radius 1 looking down Godot's +Z: a white with faint veins, a glowing sky-blue iris of
#                   fine fibres with a gold ring round the pupil, a dark limbal ring and a sunken pupil. The game
#                   scales it to each eye's radius and keeps its own shine ball.
#   seraph_feather  one wing feather in the space of the game's feather ball (unit size, long along x, wide along y,
#                   thin along z; the game stretches it to (length, 0.42, 0.14)): a cupped vane of barbs with a few
#                   splits at its edge, a tapering quill down the middle and a gold tip.
#   seraph_wheel    one wheel in Godot's XZ plane at radius 2.7 (the game scales it to each wheel's radius): an outer
#                   rim carved with a band of runes between twisted gold cords, a fluted inner rim, braces with beads
#                   between them, and round each of its eight eyes a beaded bezel and a sunburst of rays.
#   seraph_glory    a sunburst disc in Godot's XY plane facing +Z, 2.1 across: long and short rays round two beaded
#                   rings. It glows behind the great eye.
#   seraph_crown    the crown its holy fire burns on, radius 1.1 round Godot's Y: a gold band carved with arches, beads
#                   along both edges, a cup under each of its twelve flames and a glowing gem between each pair.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_seraph.py "<out>.glb" <kind> [--preview]
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector, noise  # noqa: E402

KINDS = ["seraph_eye", "seraph_feather", "seraph_wheel", "seraph_glory", "seraph_crown"]
KIND = next((a for a in sys.argv if a in KINDS), "seraph_eye")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

GOLD = (1.0, 0.76, 0.3)              # the Seraph's gold
GOLD_DARK = (0.62, 0.4, 0.12)
GOLD_PALE = (1.0, 0.9, 0.62)
WHITE = (0.96, 0.95, 0.92)           # its eyes' whites
VEIN = (0.9, 0.62, 0.6)
IRIS = (0.45, 0.75, 1.0)             # the sky-blue iris
IRIS_DEEP = (0.16, 0.36, 0.78)
IRIS_PALE = (0.78, 0.92, 1.0)
PUPIL = (0.06, 0.06, 0.14)
FEATHER = (0.93, 0.91, 0.86)
FEATHER_SHADE = (0.82, 0.8, 0.78)
QUILL = (0.98, 0.95, 0.85)
GEM_BLUE = (0.6, 0.85, 1.0)
GEM_ROSE = (1.0, 0.62, 0.78)


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


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def painted(name, rough=0.5, metal=0.0, bump=0.0, emit_k=0.0, bump_scale=60.0):
    """A material whose colour is the high mesh's own vertex colours ("Col"): the patterns are worked out in Python
    with the shape, so colour and carving always line up. emit_k makes it glow that much of its own colour."""
    m = K.mat(name, (0.7, 0.7, 0.7), rough=rough, metal=metal)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], b.inputs["Base Color"])
    if emit_k > 0.0:
        sc = nt.nodes.new("ShaderNodeVectorMath")
        sc.operation = "SCALE"
        sc.inputs["Scale"].default_value = emit_k
        nt.links.new(attr.outputs["Color"], sc.inputs[0])
        nt.links.new(sc.outputs["Vector"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = 1.0
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
    """Sets each corner's vertex colour from col_fn(vertex position in Godot terms, its normal in Godot terms)."""
    bm.normal_update()
    layer = bm.loops.layers.color.new("Col")
    cache = {}
    for v in bm.verts:
        cache[v.index] = (*lin(col_fn(to_godot(v.co), to_godot(v.normal))), 1.0)
    for f in bm.faces:
        for lp in f.loops:
            lp[layer] = cache[lp.vert.index]


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


def torus(name, c, axis, R, r, nu, nv, m, coll, push=None, col_fn=None, section=None):
    """A ring of radius R round axis (Godot) through c, its tube r across. push(theta, phi) moves each point out
    along its tube's normal (carvings); section(phi) -> (x, y) gives another tube shape (a rounded band)."""
    c, axis = Vector(c), Vector(axis).normalized()
    u0 = axis.cross(Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))).normalized()
    v0 = axis.cross(u0).normalized()

    def fn(s, t):
        th, ph = s * math.tau, t * math.tau
        radial = u0 * math.cos(th) + v0 * math.sin(th)
        if section:
            sx, sy = section(ph)
            nrm = (radial * math.cos(ph) + axis * math.sin(ph))
        else:
            sx, sy = math.cos(ph) * r, math.sin(ph) * r
            nrm = radial * math.cos(ph) + axis * math.sin(ph)
        d = push(th, ph) if push else 0.0
        p = c + radial * (R + sx) + axis * sy + nrm * d
        return tuple(p)
    return grid_mesh(name, nu, nv, fn, m, coll, True, True, col_fn)


def gsphere(name, c, r, m, coll, seg=16, scale=(1, 1, 1)):
    ob = K.sphere(name, r, at=at(*c), m=m, seg=seg, col=coll)
    ob.scale = (scale[0], scale[2], scale[1])
    return ob


def frame_for(out):
    """Two tangents across the plane facing out (Godot)."""
    out = Vector(out).normalized()
    t1 = out.cross(Vector((0, 1, 0)) if abs(out.y) < 0.9 else Vector((1, 0, 0))).normalized()
    return t1, out.cross(t1).normalized()


def star_plate(name, c, n_axis, pts, r_in, r_out, thick, m, coll, rot=0.0, alt=None):
    """A flat star of pts rays (Godot centre and facing), thick deep: a solid low piece for rays to bake onto."""
    t1, t2 = frame_for(n_axis)
    n = Vector(n_axis).normalized()
    c = Vector(c)
    bm = bmesh.new()
    ring = []
    for k in range(pts * 2):
        a = rot + math.pi * k / pts
        rr = r_out if k % 2 == 0 else r_in
        if alt and k % 4 == 2:
            rr = alt
        ring.append(c + (t1 * math.cos(a) + t2 * math.sin(a)) * rr)
    top = [bm.verts.new(at(*(p + n * thick * 0.5))) for p in ring]
    bot = [bm.verts.new(at(*(p - n * thick * 0.5))) for p in ring]
    ct = bm.verts.new(at(*(c + n * thick * 0.5)))
    cb = bm.verts.new(at(*(c - n * thick * 0.5)))
    m_ = len(ring)
    for k in range(m_):
        a, b = k, (k + 1) % m_
        bm.faces.new((ct, top[a], top[b]))
        bm.faces.new((cb, bot[b], bot[a]))
        bm.faces.new((top[a], bot[a], bot[b], top[b]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, False, coll)


def ray(name, base, tip, w0, w1, n_axis, depth, m, coll, ridge=True, seg=10):
    """A tapering ray from base to tip lying in the plane facing n_axis (Godot), with a raised ridge down its middle."""
    base, tip, n = Vector(base), Vector(tip), Vector(n_axis).normalized()
    d = tip - base
    side = n.cross(d).normalized()

    def fn(s, t):
        w = w0 + (w1 - w0) * s
        x = (t * 2 - 1)
        h = depth * (1 - abs(x) ** 1.6) * (1.0 if ridge else 0.5) * (1 - 0.5 * s)
        p = base + d * s + side * x * w + n * h
        return tuple(p)
    top = grid_mesh(name, seg, 6, fn, m, coll)
    return top


def bead_ring(name, c, axis, R, count, r, m, coll, phase=0.0, seg=8):
    c, axis = Vector(c), Vector(axis).normalized()
    t1, t2 = frame_for(axis)
    obs = []
    for k in range(count):
        a = phase + math.tau * k / count
        obs.append(gsphere(name, tuple(c + (t1 * math.cos(a) + t2 * math.sin(a)) * R), r, m, coll, seg=seg))
    return obs


def cord(name, c, axis, R, r, strands, twists, m, coll, nu=360):
    """Twisted cord round a circle: strands little tubes winding round each other twists times round."""
    c, axis = Vector(c), Vector(axis).normalized()
    t1, t2 = frame_for(axis)
    obs = []
    for s in range(strands):
        off = math.tau * s / strands

        def fn(u, v, off=off):
            th = u * math.tau
            radial = t1 * math.cos(th) + t2 * math.sin(th)
            w = th * twists + off
            centre = c + radial * (R + math.cos(w) * r) + axis * (math.sin(w) * r)
            ph = v * math.tau
            p = centre + (radial * math.cos(ph) + axis * math.sin(ph)) * r * 0.75
            return tuple(p)
        obs.append(grid_mesh(name, nu, 6, fn, m, coll, True, True))
    return obs


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


# ================================================================ the eye
def _eye_angle(p):
    """How far round from the front (Godot +Z) a point on the eye is, and which way round the front."""
    q = Vector(p).normalized()
    return math.acos(max(-1.0, min(1.0, q.z))), math.atan2(q.y, q.x)


IRIS_A = 0.62
PUPIL_A = 0.21


def _eye_colour(p, n):
    th, az = _eye_angle(p)
    if th > IRIS_A + 0.03:
        # the white: warmer towards the back, with faint branching veins reaching in towards the iris
        c = mix(WHITE, (0.88, 0.86, 0.86), smooth(1.6, 2.8, th))
        v = abs(noise.noise(Vector((math.cos(az) * 3.0, math.sin(az) * 3.0, th * 6.0))))
        vein = (1.0 - smooth(0.0, 0.05, v)) * smooth(2.2, 0.9, th) * 0.55
        return mix(c, VEIN, vein)
    if th > IRIS_A - 0.04:
        return mix(IRIS_DEEP, (0.08, 0.1, 0.24), 0.6)        # the dark limbal ring round the iris
    if th < PUPIL_A:
        return PUPIL
    # the iris: fine fibres running out from the pupil, a gold ring of collarette close in and paler flecks
    k = (th - PUPIL_A) / (IRIS_A - PUPIL_A)
    fib = 0.5 + 0.5 * math.sin(az * 90 + 4 * noise.noise(Vector((az * 2.0, k * 3, 0.5))))
    fib2 = 0.5 + 0.5 * noise.noise(Vector((math.cos(az) * 18, math.sin(az) * 18, k * 4)))
    c = mix(IRIS_DEEP, IRIS, 0.25 + 0.55 * k + 0.25 * (fib - 0.5))
    c = mix(c, IRIS_PALE, smooth(0.6, 0.95, fib2) * 0.6)
    gold = math.exp(-((k - 0.22) / 0.07) ** 2)
    c = mix(c, (1.0, 0.82, 0.4), gold * 0.85)
    c = mix(c, IRIS_DEEP, smooth(0.8, 1.0, k) * 0.5)
    return c


def seraph_eye():
    white = painted("Eye White", rough=0.25, bump=0.05)
    iris = painted("Eye Iris", rough=0.2, emit_k=1.0, bump=0.0)

    def surface(u, v, sclera, hi):
        th = v * math.pi
        az = u * math.tau
        q = Vector((math.sin(th) * math.cos(az), math.sin(th) * math.sin(az), math.cos(th)))
        r = 1.0
        if hi:
            if th < IRIS_A:
                k = max(0.0, (th - PUPIL_A) / (IRIS_A - PUPIL_A))
                # the iris sits a little inside the white, its fibres standing up in fine ridges, the pupil sunk
                r = 0.985 + 0.006 * math.sin(az * 90 + 4 * noise.noise(Vector((az * 2.0, k * 3, 0.5)))) * (k > 0)
                if th < PUPIL_A:
                    r = 0.965
                r += 0.004 * math.exp(-((k - 0.22) / 0.06) ** 2)
            elif th < IRIS_A + 0.05:
                r = 0.99
        return tuple(q * r)

    def high_part(name, m, v0, v1, nv):
        return grid_mesh(name, 720, nv, lambda u, v: surface(u, v0 + (v1 - v0) * v, False, True), m, HIGH,
                         True, False, _eye_colour)
    # two pieces: the glowing iris cap and the rest, so only the iris glows
    split = (IRIS_A + 0.03) / math.pi
    high = [high_part("Iris", iris, 0.0, split, 120), high_part("White", white, split, 1.0, 240)]
    low = [K.sphere("Eye", 1.0, m=white, seg=32, col=LOW)]
    low[0].rotation_euler = (math.pi / 2, 0, 0)       # its poles front and back, so the iris gets round rings
    return high, low


# ================================================================ the feather
def _feather_w(t):
    """Half the width of the vane t of the way from its root to its tip (0..0.5)."""
    root = smooth(0.0, 0.14, t)
    tip = math.sqrt(max(0.0, 1.0 - ((t - 0.42) / 0.58) ** 2)) if t > 0.42 else 1.0
    return 0.5 * root * tip * (0.95 + 0.05 * math.sin(t * 9))


def _feather_point(t, v, side, hi):
    """A point on the vane: t along its length, v across (-1..1), side +1 for its top face and -1 for its under."""
    x = -0.5 + t
    w = _feather_w(t)
    if hi:
        # splits at its edge: here and there the barbs part and the edge bites in
        for c in (0.36, 0.58, 0.71):
            w *= 1.0 - 0.18 * math.exp(-((t - c) / 0.012) ** 2) * smooth(0.6, 1.0, abs(v)) * (1 if v > 0 else 0.6)
    y = v * w
    cup = 0.18 * (v * v) - 0.06                   # curled up at its edges like a real feather
    th = 0.16 * (1 - v * v) * smooth(0.0, 0.08, t) * (1.0 - 0.6 * t)
    z = cup + side * th * 0.5
    if hi and abs(v) > 0.04:
        # the barbs: fine ridges sweeping out and towards the tip from the quill
        ph = (t * 1.0 - abs(v) * w * 0.55) * 260
        z += side * 0.012 * (0.5 + 0.5 * math.sin(ph)) * (1 - abs(v) ** 4)
    return (x, y, z)


def _feather_colour(p, n):
    t = p.x + 0.5
    w = max(1e-4, _feather_w(t))
    v = abs(p.y) / w
    c = mix(FEATHER, FEATHER_SHADE, 0.25 * smooth(0.6, 1.0, v) + 0.2 * (1 - smooth(0.05, 0.3, t)))
    c = mix(c, (1.0, 0.98, 0.95), 0.4 * (1 - v) * smooth(0.2, 0.6, t))
    # the gold creeping in from the tip, in a soft feathered edge
    g = smooth(0.74, 0.86, t + 0.04 * noise.noise(Vector((p.y * 20, 0.3, 0.7))))
    return mix(c, mix(GOLD, GOLD_PALE, 0.35 * (1 - v)), g)


def seraph_feather():
    vane = painted("Vane", rough=0.55, bump=0.08, bump_scale=200.0)
    gold = painted("Vane Gold", rough=0.3, metal=0.75, emit_k=0.4)
    quill = K.mat("Quill", QUILL, rough=0.3)

    def piece(name, m, coll, t0, t1, nu, nv, hi):
        obs = []
        for side in (1.0, -1.0):
            obs.append(grid_mesh(name, nu, nv,
                                 lambda u, v, side=side: _feather_point(t0 + (t1 - t0) * u, (v * 2 - 1) * side, side,
                                                                        hi),
                                 m, coll, col_fn=_feather_colour))
        return obs
    high = piece("Vane", vane, HIGH, 0.0, 0.8, 600, 120, True) + piece("Tip", gold, HIGH, 0.79, 1.0, 160, 120, True)
    # the quill: a tapering round shaft along the middle, standing proud of the vane
    pts = [(-0.55 + 0.9 * k / 30, 0.0, -0.06 + 0.05) for k in range(31)]
    for k in range(30):
        a, b = pts[k], pts[k + 1]
        r0 = 0.05 * (1 - k / 30) + 0.008
        r1 = 0.05 * (1 - (k + 1) / 30) + 0.008
        ob = K.cyl("Quill", r0, (Vector(b) - Vector(a)).length, at=(at(*a) + at(*b)) / 2, seg=16, m=quill, col=HIGH,
                   r2=r1)
        ob.rotation_euler = (0, math.pi / 2, 0)
        high.append(ob)
    low = piece("Feather", vane, LOW, 0.0, 1.0, 20, 6, False)
    low.append(K.cyl("Quill", 0.06, 0.25, at=at(-0.43, 0, -0.01), seg=6, m=quill, col=LOW, r2=0.03))
    low[-1].rotation_euler = (0, math.pi / 2, 0)
    return high, low


# ================================================================ the wheel
WHEEL_R = 2.7
RIM_T = 0.13
INNER_R = WHEEL_R - 0.32
EYE_R = 0.27


def _rune_band(th, ph):
    """How deep the rim's carving is at angle th round the wheel and phi round its tube: a band of little runes on
    its outside face between two grooves."""
    if abs(math.cos(ph)) < 0.55:
        return 0.0
    # 8 eye bezels cover parts of the rim: leave the carving out round them
    cell = (th / math.tau * 8) % 1.0
    if abs(cell - 0.5) > 0.36:
        return 0.0
    y = math.sin(ph)                                # -1 .. 1 across the band
    if abs(abs(y) - 0.62) < 0.07:
        return -0.012                               # the grooves along each side
    if abs(y) > 0.55:
        return 0.004
    # runes: each little cell a pattern of strokes picked from a hash
    k = int(th / math.tau * 8 * 9)
    f = (th / math.tau * 8 * 9) % 1.0
    h = (k * 2654435761) & 0xFFFF
    strokes = [((h >> b) & 1) for b in range(6)]
    d = 0.0
    if strokes[0] and abs(f - 0.5) < 0.08:
        d = 1.0
    if strokes[1] and abs(y) < 0.08 and 0.2 < f < 0.8:
        d = 1.0
    if strokes[2] and abs(y - (f - 0.5) * 1.4) < 0.08:
        d = 1.0
    if strokes[3] and abs(y + (f - 0.5) * 1.4) < 0.08:
        d = 1.0
    if strokes[4] and abs(y - 0.35) < 0.07 and f < 0.6:
        d = 1.0
    if strokes[5] and ((f - 0.5) ** 2 + (y + 0.25) ** 2) < 0.02:
        d = 1.0
    return -0.01 * d


def _gold_colour(p, n):
    """Gold that's darker in the hollows (the carving's far side) and pale on the tops."""
    nz = noise.noise(Vector(p) * 9.0)
    return mix(mix(GOLD, GOLD_DARK, 0.25 + 0.15 * nz), GOLD_PALE, 0.25 * max(0.0, n.y))


def seraph_wheel():
    gold = painted("Wheel Gold", rough=0.28, metal=0.95, emit_k=0.35, bump=0.04, bump_scale=120)
    gold_low = K.mat("Wheel Gold Low", GOLD, rough=0.3, metal=0.9)
    high, low = [], []
    up = (0, 1, 0)
    # the outer rim, carved, and twisted cords top and bottom
    high.append(torus("Rim", (0, 0, 0), up, WHEEL_R, RIM_T, 1440, 40, gold, HIGH, push=_rune_band,
                      col_fn=_gold_colour))
    for s in (-1, 1):
        high += cord("Cord", (0, s * RIM_T * 0.92, 0), up, WHEEL_R, 0.03, 3, 140, gold, HIGH)
    # the inner rim with twisted flutes
    high.append(torus("Inner Rim", (0, 0, 0), up, INNER_R, 0.06, 1080, 24, gold, HIGH,
                      push=lambda th, ph: 0.012 * math.cos(ph * 6 + th * 60), col_fn=_gold_colour))
    low.append(torus("Rim", (0, 0, 0), up, WHEEL_R, RIM_T + 0.045, 96, 10, gold_low, LOW))
    low.append(torus("Inner Rim", (0, 0, 0), up, INNER_R, 0.075, 96, 6, gold_low, LOW))
    for j in range(8):
        a = math.tau * j / 8
        out = Vector((math.cos(a), 0, math.sin(a)))
        c = out * WHEEL_R
        # the bezel round the eye: a ring a little out from the rim with beads, and a sunburst of rays behind it
        bc = c + out * 0.1
        high.append(torus("Bezel", tuple(bc), tuple(out), EYE_R + 0.01, 0.045, 160, 16, gold, HIGH,
                          push=lambda th, ph: 0.006 * math.cos(th * 24), col_fn=_gold_colour))
        high += bead_ring("Bead", tuple(bc + out * 0.01), tuple(out), EYE_R + 0.09, 16, 0.022, gold, HIGH, seg=10)
        rc = c - out * 0.02
        t1, t2 = frame_for(out)
        for k in range(12):
            ra = math.tau * (k + 0.5) / 12
            dvec = t1 * math.cos(ra) + t2 * math.sin(ra)
            long = 0.6 if k % 2 == 0 else 0.46
            high.append(ray("Ray", tuple(rc + dvec * 0.33), tuple(rc + dvec * long), 0.055, 0.0, tuple(out), 0.03,
                            gold, HIGH))
        low.append(torus("Bezel", tuple(bc), tuple(out), EYE_R + 0.04, 0.085, 20, 6, gold_low, LOW))
        low.append(star_plate("Rays", tuple(rc + out * 0.01), tuple(out), 12, 0.36, 0.62, 0.07, gold_low, LOW,
                              rot=math.pi / 12, alt=0.48))
        # a brace between this eye and the next, from the inner rim to the outer, with a bead on it
        b = math.tau * (j + 0.5) / 8
        bo = Vector((math.cos(b), 0, math.sin(b)))
        for k in range(10):
            t0, t1_ = k / 10, (k + 1) / 10
            p0 = bo * (INNER_R + (WHEEL_R - INNER_R) * t0)
            p1 = bo * (INNER_R + (WHEEL_R - INNER_R) * t1_)
            r0 = 0.03 + 0.012 * math.cos(t0 * math.tau * 2)
            ob = K.cyl("Brace", r0, (p1 - p0).length, at=at(*((p0 + p1) / 2)), seg=14, m=gold, col=HIGH)
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((at(*p1) - at(*p0)).normalized())
            colour_obj(ob, _gold_colour)
            high.append(ob)
        high.append(gsphere("Brace Bead", tuple(bo * (INNER_R + WHEEL_R) * 0.5), 0.055, gold, HIGH, seg=16))
        colour_obj(high[-1], _gold_colour)
        mid = bo * (INNER_R + WHEEL_R) * 0.5
        ob = K.cyl("Brace", 0.06, WHEEL_R - INNER_R, at=at(*mid), seg=6, m=gold_low, col=LOW)
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(at(*bo).normalized())
        low.append(ob)
    for ob in high:
        if "Col" not in ob.data.color_attributes:
            colour_obj(ob, _gold_colour)
    return high, low


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


# ================================================================ the glory
def seraph_glory():
    gold = painted("Glory Gold", rough=0.3, metal=0.6, emit_k=0.9)
    gold_low = K.mat("Glory Low", GOLD_PALE, rough=0.3, metal=0.5)
    front = (0, 0, 1)
    high, low = [], []

    def glow_colour(p, n):
        r = Vector((p.x, p.y)).length
        return mix(GOLD_PALE, GOLD, smooth(0.9, 2.1, r))
    # a thin gold disc behind it all, so the rays have something to stand on
    high.append(torus("Back", (0, 0, -0.015), front, 0.9, 0.0, 720, 30, gold, HIGH,
                      section=lambda ph: (max(-0.9, min(0.55, 0.9 * math.cos(ph))), 0.012 * math.sin(ph)),
                      col_fn=glow_colour))
    for k in range(32):
        a = math.tau * k / 32
        d = Vector((math.cos(a), math.sin(a), 0))
        long = 2.1 if k % 2 == 0 else 1.65
        w = 0.13 if k % 2 == 0 else 0.09
        r = ray("Ray", tuple(d * 1.0), tuple(d * long), w, 0.0, front, 0.05, gold, HIGH, seg=40)
        colour_obj(r, glow_colour)
        high.append(r)
        # little flames of light between the long rays
        if k % 2 == 1:
            r2 = ray("Spark", tuple(d * 1.7), tuple(d * 1.92), 0.04, 0.0, front, 0.02, gold, HIGH, seg=10)
            colour_obj(r2, glow_colour)
            high.append(r2)
    for R, n in ((1.02, 48), (1.42, 64)):
        high.append(torus("Band", (0, 0, 0.0), front, R, 0.035, 720, 16, gold, HIGH,
                          push=lambda th, ph: 0.008 * math.cos(th * 96), col_fn=glow_colour))
        for ob in bead_ring("Bead", (0, 0, 0.035), front, R, n, 0.026, gold, HIGH, seg=10):
            colour_obj(ob, glow_colour)
            high.append(ob)
    low.append(star_plate("Glory", (0, 0, 0.0), front, 32, 1.15, 2.14, 0.1, gold_low, LOW, alt=1.7))
    return high, low


# ================================================================ the crown
CROWN_R = 1.1
BAND_W = 0.05
BAND_H = 0.11


def _band_section(ph):
    """A rounded oblong round phi: wide in Y (its height), thin across."""
    c, s = math.cos(ph), math.sin(ph)
    p = 6.0
    x = BAND_W * math.copysign(abs(c) ** (2 / p), c)
    y = BAND_H * math.copysign(abs(s) ** (2 / p), s)
    return x, y


def _arches(th, ph):
    """Gothic arches carved round the band's outside, one between each pair of flames."""
    if math.cos(ph) < 0.5:
        return 0.0
    y = math.sin(ph)
    cell = (th / math.tau * 12) % 1.0
    x = (cell - 0.5) * 2                              # -1 .. 1 across each arch
    if abs(y) > 0.85:
        return 0.004
    # an arch: straight sides from the bottom, a pointed top
    inside = abs(x) < 0.6 and (y < 0.25 or (abs(x) + (y - 0.25) * 1.2) < 0.6 * (1 - (y - 0.25) * 0.9))
    edge = abs(x) < 0.72 and (y < 0.35 or (abs(x) + (y - 0.25) * 1.1) < 0.78)
    if inside and y > -0.7:
        return -0.014
    if edge and y > -0.8:
        return 0.006
    return 0.0


def seraph_crown():
    gold = painted("Crown Gold", rough=0.25, metal=0.95, emit_k=0.15, bump=0.03, bump_scale=150)
    gem_b = K.mat("Gem Blue", GEM_BLUE, rough=0.08, emit=1.0, emit_rgb=GEM_BLUE)
    gem_r = K.mat("Gem Rose", GEM_ROSE, rough=0.08, emit=1.0, emit_rgb=GEM_ROSE)
    gold_low = K.mat("Crown Low", GOLD, rough=0.3, metal=0.9)
    up = (0, 1, 0)
    high, low = [], []
    high.append(torus("Band", (0, 0, 0), up, CROWN_R, 0.0, 1440, 48, gold, HIGH, push=_arches, col_fn=_gold_colour,
                      section=_band_section))
    for s in (-1, 1):
        for ob in bead_ring("Bead", (0, s * (BAND_H + 0.012), 0), up, CROWN_R, 96, 0.018, gold, HIGH, seg=10):
            colour_obj(ob, _gold_colour)
            high.append(ob)
        high.append(torus("Edge", (0, s * BAND_H * 0.92, 0), up, CROWN_R, 0.0, 720, 12, gold, HIGH,
                          section=lambda ph: (0.062 * math.cos(ph), 0.016 * math.sin(ph)), col_fn=_gold_colour))
    for j in range(12):
        a = math.tau * j / 12
        out = Vector((math.cos(a), 0, math.sin(a)))
        # a cup under each flame: a little gold lily of six petals round a ring
        base = out * CROWN_R + Vector((0, BAND_H, 0))
        cup = K.lathe("Cup", [(0.05, 0.0), (0.12, 0.02), (0.17, 0.08), (0.185, 0.1), (0.16, 0.11), (0.0, 0.11)],
                      seg=48, m=gold, at=at(*base), flutes=12, flute_depth=0.015, flute_z=(0.0, 0.1), col=HIGH)
        colour_obj(cup, _gold_colour)
        high.append(cup)
        for k in range(6):
            pa = math.tau * k / 6
            d = Vector((math.cos(pa), 0, math.sin(pa)))
            r = ray("Petal", tuple(base + d * 0.14 + Vector((0, 0.08, 0))),
                    tuple(base + d * 0.26 + Vector((0, 0.18, 0))), 0.05, 0.0, tuple(d.cross(Vector((0, 1, 0)))
                                                                                    .cross(d).normalized() * -1),
                    0.015, gold, HIGH, seg=12)
            colour_obj(r, _gold_colour)
            high.append(r)
        # (the low cup is a dish that dips down to the high cup's mouth: a flat lid over the petals baked black)
        low.append(K.lathe("Cup", [(0.05, 0.0), (0.2, 0.06), (0.28, 0.19), (0.2, 0.16), (0.1, 0.115), (0.0, 0.11)],
                           seg=10, m=gold_low,
                           at=at(*base), col=LOW))
        # a gem between this flame and the next, in a gold setting with four prongs
        g = math.tau * (j + 0.5) / 12
        go = Vector((math.cos(g), 0, math.sin(g)))
        gc = go * (CROWN_R + BAND_W + 0.025)
        gm = gem_b if j % 2 == 0 else gem_r
        gem = gsphere("Gem", tuple(gc), 0.045, gm, HIGH, seg=8)
        gem.rotation_mode = "QUATERNION"
        gem.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(at(*go))
        gem.scale = (1.0, 1.0, 0.6)
        high.append(gem)
        setting = torus("Setting", tuple(gc - go * 0.01), tuple(go), 0.05, 0.012, 48, 8, gold, HIGH,
                        col_fn=_gold_colour)
        high.append(setting)
        t1, t2 = frame_for(go)
        for k in range(4):
            pa = math.tau * (k + 0.5) / 4
            d = t1 * math.cos(pa) + t2 * math.sin(pa)
            pr = gsphere("Prong", tuple(gc + d * 0.045 + go * 0.015), 0.01, gold, HIGH, seg=8)
            colour_obj(pr, _gold_colour)
            high.append(pr)
    low.append(torus("Band", (0, 0, 0), up, CROWN_R, 0.0, 72, 8, gold_low, LOW,
                     section=lambda ph: ((BAND_W + 0.07) * math.cos(ph) + 0.03, (BAND_H + 0.035) * math.sin(ph))))
    return high, low


fn, size, ext, ray_d, ao, emit, strength = {
    "seraph_eye": (seraph_eye, 2048, 0.03, 0.06, False, True, 1.6),
    "seraph_feather": (seraph_feather, 1024, 0.04, 0.1, True, True, 1.0),
    "seraph_wheel": (seraph_wheel, 2048, 0.06, 0.14, True, True, 1.0),
    "seraph_glory": (seraph_glory, 1024, 0.08, 0.15, False, True, 1.0),
    "seraph_crown": (seraph_crown, 1024, 0.1, 0.25, False, True, 2.2),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray_d=ray_d, ao=ao, emit=emit, emit_strength=strength)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

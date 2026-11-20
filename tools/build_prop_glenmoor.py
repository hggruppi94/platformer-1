# Glenmoor, Heather's world, built the detailed way (tools/bake_kit.py; 19 Nov 2026, Hayden: "Then keep baking
# details", the portal worlds' props, starting with Glenmoor): the Standing Stones, the cairns up Ben Bonnie with their
# tartan flags, Heather's croft and her barn. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces tools/build_glenmoor.gd builds from shapes, so the swap (scripts/detail_props.gd
# dress_glenmoor) puts each exactly where the old one was and every collision stays the game's. Blender's X is Godot's
# X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   standing_stone a tall old stone 1.2 wide, 0.8 thick and 4 tall, its middle at the origin (the game stretches it to
#                  each stone's own height): weathered and lumpy, with a carved spiral and cup-and-ring marks, lichen
#                  and a collar of moss round its foot.
#   cairn          a cairn of dry-laid stones 1.6 m high, with a pole and a tartan flag (the four on the way up).
#   summit_cairn   the same, 2.3 m high (the one on top of Ben Bonnie).
#   croft          Heather's croft: a whitewashed house 9 x 4 x 6 with a slate roof, stone chimneys with pots, a red
#                  panelled door, sash windows that glow a little, and the porch with its posts, red roof and a
#                  rocking chair. Its front (the door) faces -Z, like the builder's.
#   barn           her red barn, 8 x 6 x 10: boards and battens, white corners, a slate gambrel roof, white double
#                  doors with crossed braces and a hayloft door on its -X side, and a weathervane.
# Colours are the game's own (sRGB; Glenmoor isn't tinted to the alien palette).
#
#   python tools/build_prop_glenmoor.py "<out>.glb" <kind> [--preview]
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["standing_stone", "cairn", "summit_cairn", "croft", "barn"]
KIND = next((a for a in sys.argv if a in KINDS), "standing_stone")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

STONE = (0.6, 0.6, 0.62)
STONE_DARK = (0.48, 0.48, 0.52)
MOSS = (0.38, 0.55, 0.3)
LICHEN = (0.78, 0.8, 0.6)
LICHEN_GOLD = (0.85, 0.7, 0.35)
WHITEWASH = (0.95, 0.93, 0.88)
SLATE = (0.35, 0.38, 0.45)
BARN_RED = (0.72, 0.22, 0.2)
PORCH_WOOD = (0.62, 0.45, 0.3)
WINDOW = (1.0, 0.9, 0.6)
TARTAN = (0.75, 0.2, 0.25)
TARTAN_STRIPE = (0.2, 0.35, 0.6)
TARTAN_GREEN = (0.15, 0.4, 0.25)
POLE = (0.5, 0.36, 0.25)
IRON = (0.18, 0.17, 0.19)
BRASS = (0.85, 0.66, 0.32)
POT = (0.72, 0.4, 0.28)


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


def mesh_from(name, verts, faces, m, col, smooth=False):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, smooth, col)


def gprism(name, outline, z0, z1, m, col):
    """A flat shape given as a Godot (x, y) outline, made z0..z1 thick along Godot z (a gable end, a roof slope)."""
    n = len(outline)
    verts = [at(x, y, z0) for x, y in outline] + [at(x, y, z1) for x, y in outline]
    faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return mesh_from(name, verts, faces, m, col)


def blob(name, r, pos, m, col, seed=0, seg=12, lump=0.25, squash=(1.0, 1.0, 1.0)):
    """A lumpy round stone r across at a Godot position, squashed along Godot x, y, z."""
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


def lichen_stone(name, base, rough=0.92, bump=0.5):
    """Old weathered stone: wandering darker and lighter patches, pale grey-green lichen and a few gold spots."""
    m = K.mat(name, base, rough=rough, bump=bump)
    nt, bsdf, co = _nodes(m)
    darker = tuple(c * 0.78 for c in base)
    c = _mix_rgb(nt, _patches(nt, co, 3.0, 0.4, 0.65), base, darker)
    c = _mix_rgb(nt, _patches(nt, co, 5.5, 0.6, 0.66, w=1.3), c, LICHEN)
    c = _mix_rgb(nt, _patches(nt, co, 14.0, 0.7, 0.73, w=4.1), c, LICHEN_GOLD)
    nt.links.new(c, bsdf.inputs["Base Color"])
    return m


def mottled(name, a, b, scale=6.0, rough=0.6, metal=0.0, bump=0.0, lo=0.35, hi=0.7):
    """A material that wanders between two colours (weathered whitewash, old slate)."""
    m = K.mat(name, a, rough=rough, metal=metal, bump=bump)
    nt, bsdf, co = _nodes(m)
    nt.links.new(_mix_rgb(nt, _patches(nt, co, scale, lo, hi), a, b), bsdf.inputs["Base Color"])
    return m


def tartan(name):
    """A red tartan: blue and green bands both ways and a thin gold line, crossing into darker squares."""
    m = K.mat(name, TARTAN, rough=0.85, bump=0.3)
    nt, bsdf, co = _nodes(m)

    def bands(axis, freq, lo, hi):
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(co, sep.inputs["Vector"])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = freq
        nt.links.new(sep.outputs[axis], mul.inputs[0])
        fr = nt.nodes.new("ShaderNodeMath")
        fr.operation = "FRACT"
        nt.links.new(mul.outputs[0], fr.inputs[0])
        a = nt.nodes.new("ShaderNodeMath")
        a.operation = "GREATER_THAN"
        a.inputs[1].default_value = lo
        nt.links.new(fr.outputs[0], a.inputs[0])
        b = nt.nodes.new("ShaderNodeMath")
        b.operation = "LESS_THAN"
        b.inputs[1].default_value = hi
        nt.links.new(fr.outputs[0], b.inputs[0])
        both = nt.nodes.new("ShaderNodeMath")
        both.operation = "MULTIPLY"
        nt.links.new(a.outputs[0], both.inputs[0])
        nt.links.new(b.outputs[0], both.inputs[1])
        return both.outputs[0]

    def half(fac):
        h = nt.nodes.new("ShaderNodeMath")
        h.operation = "MULTIPLY"
        h.inputs[1].default_value = 0.6
        nt.links.new(fac, h.inputs[0])
        return h.outputs[0]

    c = TARTAN
    out = _mix_rgb(nt, half(bands("X", 4.0, 0.15, 0.4)), c, TARTAN_STRIPE)
    out = _mix_rgb(nt, half(bands("Z", 4.0, 0.15, 0.4)), out, TARTAN_STRIPE)
    out = _mix_rgb(nt, half(bands("X", 4.0, 0.6, 0.75)), out, TARTAN_GREEN)
    out = _mix_rgb(nt, half(bands("Z", 4.0, 0.6, 0.75)), out, TARTAN_GREEN)
    out = _mix_rgb(nt, bands("X", 4.0, 0.52, 0.55), out, (0.95, 0.8, 0.35))
    out = _mix_rgb(nt, bands("Z", 4.0, 0.52, 0.55), out, (0.95, 0.8, 0.35))
    nt.links.new(out, bsdf.inputs["Base Color"])
    return m


def lump_box(name, half, m, col, cuts, amp, fine, seed=0, taper=0.0, round_k=0.35, carve=None, top_round=0.0):
    """A rounded, weathered block: a cube cut into a grid, rounded off, tapered towards its top, pushed in and out by
    noise (amp for the big lumps both versions share, fine for the little ones only the high one has), and carved by
    carve(x, y, z, face) -> how far in, in Godot's terms. half is its half size in Godot's x, y, z."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    off = Vector((seed * 2.1, seed * 1.3, seed * 0.7))
    hx, hy, hz = half
    for v in bm.verts:
        # Blender (x, y, z) -> Godot (x, z, -y)
        gx, gy, gz = v.co.x, v.co.z, -v.co.y
        face = "front" if gz > 0.999 else "back" if gz < -0.999 else ""
        p = Vector((gx, gy, gz))
        p = p.lerp(p.normalized() * max(abs(gx), abs(gy), abs(gz)), round_k)
        t = (p.y + 1.0) * 0.5
        sx = hx * (1.0 - taper * t)
        sz = hz * (1.0 - taper * 0.6 * t)
        y = p.y * hy
        if top_round and p.y > 0:
            y -= top_round * (p.x * p.x) * p.y * hy
        q = Vector((p.x * sx, y, p.z * sz))
        n = Vector((p.x / max(sx, 0.01), p.y / max(hy, 0.01) * 0.4, p.z / max(sz, 0.01))).normalized()
        d = amp * noise.noise(q * 0.9 + off) + 0.4 * amp * noise.noise(q * 2.3 + off * 2.0)
        if fine:
            d += fine * noise.noise(q * 9.0 + off) + 0.5 * fine * noise.noise(q * 24.0 + off)
        if carve:
            d -= carve(q.x, q.y, q.z, face)
        q += n * d
        v.co = Vector(at(q.x, q.y, q.z))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, True, col)


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


# ================================================================ standing stone
# 1.2 wide (x), 0.8 thick (z), 4 tall, its middle at the origin. Its broad faces are its front and back (the builder
# turns each one to face round the ring).
SS_H = 4.0


def _spiral_carve(x, y, z, face):
    if face == "front":
        # a spiral of two and a half turns high on the front, and three little cups under it
        cx, cy = 0.02, 0.75
        u, v = x - cx, y - cy
        rho = math.hypot(u, v)
        if rho < 0.36:
            phi = math.atan2(v, u) % math.tau
            b = 0.36 / (2.5 * math.tau)
            k = round((rho / b - phi) / math.tau)
            d = abs(rho - b * (phi + k * math.tau))
            if d < 0.022:
                return 0.03 * (1.0 - (d / 0.022) ** 2)
        for (px, py) in ((-0.25, -0.1), (0.2, -0.25), (-0.05, -0.45)):
            r = math.hypot(x - px, y - py)
            if r < 0.06:
                return 0.035 * (1.0 - (r / 0.06) ** 2)
    if face == "back":
        # cup-and-ring marks: a cup with a ring round it, and two plain cups
        r = math.hypot(x - 0.1, y - 0.4)
        if r < 0.055:
            return 0.035 * (1.0 - (r / 0.055) ** 2)
        if abs(r - 0.16) < 0.018:
            return 0.022
        for (px, py) in ((-0.28, 0.05), (0.22, -0.3)):
            r = math.hypot(x - px, y - py)
            if r < 0.05:
                return 0.03 * (1.0 - (r / 0.05) ** 2)
    return 0.0


def standing_stone():
    stone = lichen_stone("Standing Stone", STONE)
    moss = mottled("Stone Moss", MOSS, (0.3, 0.45, 0.22), scale=9.0, rough=0.98, bump=0.8)

    def build(col, high):
        obs = [lump_box("Stone", (0.6, SS_H / 2, 0.4), stone, col, 44 if high else 5, 0.05, 0.012 if high else 0.0,
                        seed=3, taper=0.16, round_k=0.3, top_round=0.08, carve=_spiral_carve if high else None)]
        n = 16 if high else 8
        for k in range(n):                                   # the collar of moss round its foot
            a = k / n * math.tau
            x, z = math.cos(a) * 0.62, math.sin(a) * 0.42
            obs.append(blob("Moss", 0.16 if high else 0.18, (x, -SS_H / 2 + 0.08, z), moss, col, seed=k,
                            seg=10 if high else 5, lump=0.4 if high else 0.15, squash=(1.3, 0.55, 1.0)))
        if high:
            for k in range(7):                               # creeping up the corners a bit
                a = (k * 0.9 + 0.3) % math.tau
                x, z = math.cos(a) * 0.55, math.sin(a) * 0.36
                obs.append(blob("Moss", 0.09, (x, -SS_H / 2 + 0.3 + 0.12 * (k % 3), z), moss, col, seed=20 + k,
                                seg=8, lump=0.5, squash=(1.0, 0.7, 0.6)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ cairns
# The builder stacks balls up to 1.6 m (four) or 2.3 m (six) round the origin, with a pole 0.6 m out along +X from
# the ground to 2.6 m and a flag 0.9 x 0.55 on it, its middle at (1.05, 2.3).
def _cairn(top):
    stone = lichen_stone("Cairn Stone", STONE, bump=0.6)
    pole = K.mat("Flag Pole", POLE, rough=0.8, grain=(30.0, 0.25))
    iron = K.mat("Pole Iron", IRON, rough=0.5, metal=0.8)
    cloth = tartan("Tartan")

    def build(col, high):
        obs = []
        if high:
            layers = max(4, int(top / 0.17))
            for i in range(layers):
                t = i / layers
                y = 0.06 + i * (top - 0.15) / layers
                r = 0.6 * (1.0 - 0.78 * t)
                n = max(1, int(math.tau * r / 0.27))
                for k in range(n):
                    a = (k + 0.5 * (i % 2)) / n * math.tau
                    s = 0.13 + 0.05 * abs(noise.noise(Vector((i * 1.3, k * 0.7, 0.5))))
                    obs.append(blob("Cairn Stone", s, (math.cos(a) * r, y, math.sin(a) * r), stone, col,
                                    seed=i * 31 + k, seg=10, lump=0.3, squash=(1.3, 0.6, 1.0)))
                if r > 0.2:
                    obs.append(blob("Fill", r * 0.8, (0, y, 0), stone, col, seed=99 + i, seg=10, lump=0.2,
                                    squash=(1.0, 0.35, 1.0)))
            obs.append(blob("Cap", 0.16, (0.02, top - 0.05, 0), stone, col, seed=7, seg=12, lump=0.3,
                            squash=(1.3, 0.6, 1.1)))
        else:
            prof = []
            rows = 6
            for i in range(rows + 1):
                t = i / rows
                prof.append((0.7 * (1.0 - 0.78 * t) + 0.04, -0.06 + t * (top + 0.02)))
            ob = K.lathe("Cairn", [(0.0, prof[0][1])] + prof + [(0.0, prof[-1][1])], seg=12, m=stone, col=col)
            obs.append(ob)
        # the pole, a knob on top, the flag
        obs.append(grod("Pole", (0.6, -0.1, 0), (0.6, 2.62, 0), 0.04, pole, col, seg=10 if high else 6))
        obs.append(K.sphere("Knob", 0.06, at=at(0.6, 2.66, 0), m=iron, seg=10 if high else 6, col=col))
        nx, ny = (18, 10) if high else (6, 3)
        verts, faces = [], []
        for side in (0, 1):
            for j in range(ny + 1):
                for i in range(nx + 1):
                    u, v = i / nx, j / ny
                    x = 0.62 + u * 0.88
                    y = 2.025 + v * 0.55 - 0.04 * u * u
                    z = 0.05 * math.sin(u * 5.5) * u + (0.012 if side else -0.012)
                    verts.append(at(x, y, z))
        w = nx + 1
        base = w * (ny + 1)
        for j in range(ny):
            for i in range(nx):
                a, b, c, d = j * w + i, j * w + i + 1, (j + 1) * w + i + 1, (j + 1) * w + i
                faces.append([a, d, c, b])
                faces.append([base + a, base + b, base + c, base + d])
        for i in range(nx):                                   # its edges, so it has a thickness
            for j0, j1 in ((0, 0), (ny, ny)):
                a, b = j0 * w + i, j0 * w + i + 1
                faces.append([a, b, base + b, base + a])
        for j in range(ny):
            for i0 in (0, nx):
                a, b = j * w + i0, (j + 1) * w + i0
                faces.append([a, b, base + b, base + a])
        flag = mesh_from("Flag", verts, faces, cloth, col, smooth=True)
        obs.append(flag)
        if high:
            for y in (2.1, 2.5):                              # the ties round the pole
                obs.append(K.cyl("Tie", 0.05, 0.03, at=at(0.6, y, 0), seg=10, m=iron, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


def cairn():
    return _cairn(1.6)


def summit_cairn():
    return _cairn(2.3)


# ================================================================ croft
# The house 9 x 4 x 6 sits on the ground at the origin, its door side to -Z. The porch deck is 9 x 0.3 x 2.4 from
# z -5.4 to -3.0, its posts at x +-1.4 and +-4.2, z -5.2, up to 2.9; its roof is a 9.4 x 2.8 board at y 3.0, z -4.3,
# tipped down to the front. The game's solid boxes stay as they are.
CR_W, CR_H, CR_D = 9.0, 4.0, 6.0
CR_RIDGE = 6.8


def croft():
    wash = mottled("Whitewash", WHITEWASH, (0.83, 0.8, 0.74), scale=4.0, rough=0.95, bump=0.6, lo=0.45, hi=0.75)
    grime = K.mat("Wall Grime", (0.68, 0.64, 0.58), rough=0.95, bump=0.5)
    slate = mottled("Slate", SLATE, (0.27, 0.3, 0.36), scale=10.0, rough=0.7, bump=0.3, lo=0.3, hi=0.7)
    ridge = K.mat("Ridge", (0.3, 0.3, 0.34), rough=0.8, bump=0.3)
    chim = lichen_stone("Chimney Stone", (0.66, 0.64, 0.62))
    pot = K.mat("Chimney Pot", POT, rough=0.8, bump=0.3)
    # No "wear" here: on these subdivided walls Blender's pointiness lightens nearly every face, which baked the red pink.
    red = K.mat("Croft Red", BARN_RED, rough=0.6)
    frame = K.mat("Window Frame", (0.97, 0.96, 0.92), rough=0.6)
    glass = K.mat("Window Glow", WINDOW, rough=0.2, emit=1.0)
    wood = K.mat("Porch Wood", PORCH_WOOD, rough=0.8, grain=(24.0, 0.3))
    brass = K.mat("Brass", BRASS, rough=0.35, metal=0.9)
    sill = K.mat("Sill Stone", (0.72, 0.7, 0.66), rough=0.9, bump=0.4)
    flowers = K.mat("Flowers", (0.85, 0.35, 0.6), rough=0.8)
    leaves = K.mat("Pot Leaves", (0.3, 0.55, 0.28), rough=0.85)

    def build(col, high):
        obs = []
        hw, hd = CR_W / 2, CR_D / 2
        # the walls: harled whitewash, a darker skirt of grime round the foot
        obs.append(gbox("Walls", (CR_W, CR_H, CR_D), (0, CR_H / 2, 0), wash, col, bevel=0.06 if high else 0.0))
        if high:
            obs.append(gbox("Skirt", (CR_W + 0.04, 0.35, CR_D + 0.04), (0, 0.17, 0), grime, col))
        # the gable triangles (as Godot x-y outlines turned to stand along z at each end)
        for sx in (-1, 1):
            g = mesh_from("Gable", [at(sx * hw, CR_H, -hd), at(sx * hw, CR_H, hd), at(sx * hw, CR_RIDGE - 0.1, 0),
                                    at(sx * (hw - 0.3), CR_H, -hd), at(sx * (hw - 0.3), CR_H, hd),
                                    at(sx * (hw - 0.3), CR_RIDGE - 0.1, 0)],
                          [[0, 1, 2], [3, 5, 4], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]], wash, col)
            obs.append(g)
        # the roof: two slopes of slate from the eaves (a little out past the walls) up to the ridge
        over = 0.35
        rise = CR_RIDGE - CR_H
        run = hd + over
        slope = math.atan2(rise + over * rise / hd, run)
        length = math.hypot(run, rise + over * rise / hd)
        for sz in (-1, 1):
            mid_z = sz * run / 2
            mid_y = CR_H - over * rise / hd + (rise + over * rise / hd) / 2
            obs.append(gbox("Roof", (CR_W + 0.6, 0.16, length + 0.08), (0, mid_y, mid_z), slate, col,
                            rot=(sz * slope, 0, 0)))
            if high:
                rows = 16
                for r in range(rows):
                    t = (r + 0.5) / rows
                    zz = sz * run * (1.0 - t)
                    yy = CR_H - over * rise / hd + (rise + over * rise / hd) * t + 0.1
                    cols = 26
                    for c in range(cols):
                        x = -CR_W / 2 - 0.3 + (c + 0.5 * (r % 2) + 0.5) * (CR_W + 0.6) / cols
                        if abs(x) > CR_W / 2 + 0.28:
                            continue
                        jit = 0.02 * noise.noise(Vector((r * 0.7, c * 1.1, sz)))
                        obs.append(gbox("Slate", ((CR_W + 0.6) / cols - 0.03, 0.035, length / rows + 0.06),
                                        (x, yy + jit, zz), slate, col, rot=(sz * slope + 0.04 * sz, 0, jit * 3)))
        obs.append(grod("Ridge", (-hw - 0.3, CR_RIDGE + 0.05, 0), (hw + 0.3, CR_RIDGE + 0.05, 0), 0.12, ridge, col,
                        seg=10 if high else 6))
        # the chimneys at each end, on the ridge, each with two pots
        for sx in (-1, 1):
            cx = sx * 3.6
            obs.append(lump_box("Chimney", (0.48, 1.3, 0.48), chim, col, 14 if high else 1, 0.0, 0.01 if high else 0.0,
                                seed=sx + 5, round_k=0.05))
            obs[-1].location = at(cx, 6.5, 0)
            obs.append(gbox("Chimney Cap", (1.05, 0.14, 1.05), (cx, 7.85, 0), chim, col, bevel=0.02 if high else 0.0))
            for px in (-0.2, 0.2):
                obs.append(K.cyl("Pot", 0.13, 0.4, at=at(cx + px, 8.12, 0), seg=12 if high else 6, m=pot, col=col,
                                 r2=0.11))
        # the front door: red panels, a brass knocker and handle, a stone step
        fz = -hd - 0.02
        obs.append(gbox("Door", (1.2, 2.1, 0.08), (-1.0, 1.05, fz), red, col))
        obs.append(gbox("Door Frame", (1.45, 2.3, 0.06), (-1.0, 1.15, fz + 0.02), frame, col))
        if high:
            for (px, py) in ((-0.28, 1.55), (0.28, 1.55), (-0.28, 0.55), (0.28, 0.55)):
                obs.append(gbox("Panel", (0.42, 0.72 if py > 1 else 0.68, 0.03), (-1.0 + px, py, fz - 0.05), red, col,
                                bevel=0.012))
            obs.append(K.cyl("Knocker", 0.07, 0.015, at=at(-1.0, 1.55, fz - 0.08), rot=(math.pi / 2, 0, 0), seg=14,
                             m=brass, col=col))
            obs.append(K.sphere("Handle", 0.045, at=at(-0.55, 1.0, fz - 0.08), m=brass, seg=10, col=col))
            obs.append(gbox("Letterbox", (0.3, 0.06, 0.02), (-1.0, 1.15, fz - 0.06), brass, col))
        # the windows: white sash frames, glazing bars, glowing panes and stone sills (front and back, and one each end)
        wins = [(-3.2, -1), (2.0, -1), (-3.2, 1), (2.0, 1)]
        for (wx, side) in wins:
            z = side * (hd + 0.02)
            obs.append(gbox("Pane", (1.2, 1.0, 0.04), (wx, 2.2, z), glass, col))
            obs.append(gbox("Sill", (1.45, 0.1, 0.22), (wx, 1.66, z + side * 0.08), sill, col))
            if high:
                obs.append(gbox("Frame Top", (1.3, 0.08, 0.06), (wx, 2.74, z + side * 0.03), frame, col))
                obs.append(gbox("Frame Bottom", (1.3, 0.08, 0.06), (wx, 1.7, z + side * 0.03), frame, col))
                for fx in (-0.62, 0.62):
                    obs.append(gbox("Frame Side", (0.08, 1.1, 0.06), (wx + fx, 2.22, z + side * 0.03), frame, col))
                obs.append(gbox("Sash Rail", (1.2, 0.06, 0.07), (wx, 2.2, z + side * 0.04), frame, col))
                for fx in (-0.2, 0.2):
                    obs.append(gbox("Glazing Bar", (0.03, 1.0, 0.06), (wx + fx, 2.2, z + side * 0.04), frame, col))
                if side < 0:                                  # a window box of flowers under each front window
                    obs.append(gbox("Window Box", (1.1, 0.22, 0.24), (wx, 1.5, z - 0.2), wood, col))
                    for k in range(7):
                        obs.append(blob("Flower", 0.09, (wx - 0.45 + k * 0.15, 1.68, z - 0.2), flowers if k % 2
                                        else leaves, col, seed=k, seg=8, lump=0.3))
        for sx in (-1, 1):
            x = sx * (hw + 0.02)
            obs.append(gbox("End Pane", (0.04, 0.8, 0.8), (x, 2.2, 0), glass, col))
        # the porch: boards, posts with brackets, its red roof, steps and the rocking chair
        obs.append(gbox("Deck", (9.0, 0.3, 2.4), (0, 0.15, -4.2), wood, col))
        if high:
            for k in range(22):
                x = -4.5 + (k + 0.5) * 9.0 / 22
                obs.append(gbox("Board", (9.0 / 22 - 0.02, 0.03, 2.38), (x, 0.31, -4.2), wood, col, bevel=0.005))
            obs.append(gbox("Step", (1.6, 0.15, 0.4), (-1.0, 0.075, -5.6), wood, col, bevel=0.01))
        for x in (-4.2, -1.4, 1.4, 4.2):
            obs.append(grod("Post", (x, 0.3, -5.2), (x, 2.9, -5.2), 0.1, wood, col, seg=10 if high else 6))
            if high:
                obs.append(gbox("Post Foot", (0.26, 0.2, 0.26), (x, 0.4, -5.2), wood, col, bevel=0.02))
                obs.append(gbox("Post Cap", (0.26, 0.12, 0.26), (x, 2.82, -5.2), wood, col, bevel=0.02))
                for sx in (-1, 1):                            # brackets under the roof
                    obs.append(gbox("Bracket", (0.5, 0.07, 0.07), (x + sx * 0.22, 2.62, -5.2), wood, col,
                                    rot=(0, 0, sx * 0.7)))
        obs.append(gbox("Porch Roof", (9.4, 0.2, 2.8), (0, 3.0, -4.3), red, col, rot=(-0.15, 0, 0)))
        if high:
            for k in range(18):                               # its standing seams
                x = -4.6 + k * 9.2 / 17
                obs.append(gbox("Seam", (0.04, 0.05, 2.8), (x, 3.12, -4.3), red, col, rot=(-0.15, 0, 0)))
            obs.append(gbox("Fascia", (9.4, 0.2, 0.06), (0, 2.78, -5.68), frame, col))
            # the rocking chair at (2.6, 0.3, -4.3): two curved rockers, a seat, slats up its back, arms
            cx, cz = 2.6, -4.3
            for sx in (-0.22, 0.22):
                pts = [at(cx + sx, 0.36 + 0.06 * (u - 0.5) ** 2 * 8, cz - 0.4 + u * 0.8) for u in (0, 0.25, 0.5, 0.75, 1)]
                obs.append(K.wire("Rocker", pts, 0.025, m=wood, col=col))
                obs.append(grod("Leg", (cx + sx, 0.38, cz - 0.18), (cx + sx, 0.75, cz - 0.18), 0.025, wood, col))
                obs.append(grod("Leg", (cx + sx, 0.38, cz + 0.18), (cx + sx, 1.45, cz + 0.26), 0.025, wood, col))
                obs.append(gbox("Arm", (0.06, 0.04, 0.5), (cx + sx, 1.0, cz), wood, col))
            obs.append(gbox("Seat", (0.5, 0.05, 0.45), (cx, 0.76, cz), wood, col, bevel=0.01))
            for k in range(5):
                obs.append(gbox("Slat", (0.06, 0.62, 0.02), (cx - 0.16 + k * 0.08, 1.1, cz + 0.22), wood, col,
                                rot=(-0.15, 0, 0)))
            obs.append(gbox("Back Rail", (0.5, 0.06, 0.04), (cx, 1.43, cz + 0.26), wood, col))
        else:
            obs.append(gbox("Chair", (0.5, 0.8, 0.5), (2.6, 0.75, -4.3), wood, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ barn
# 8 x 6 x 10, on the ground at the origin, its long sides along z. The doors and the hayloft are on its -X side
# (x -4), like the builder's. The slate roof is a gambrel from the eaves at 6 up to 9.2.
BN_W, BN_H, BN_D = 8.0, 6.0, 10.0


def barn():
    boards = K.mat("Barn Boards", BARN_RED, rough=0.75, grain=(18.0, 0.35))
    trim = K.mat("Barn Trim", (0.95, 0.93, 0.88), rough=0.6)
    slate = mottled("Barn Slate", SLATE, (0.27, 0.3, 0.36), scale=10.0, rough=0.7, bump=0.3, lo=0.3, hi=0.7)
    base = lichen_stone("Barn Footing", STONE_DARK)
    iron = K.mat("Hinge", IRON, rough=0.5, metal=0.8)
    brass = K.mat("Vane", BRASS, rough=0.35, metal=0.9)
    hay = K.mat("Loft Hay", (0.92, 0.8, 0.42), rough=0.95, bump=0.6)

    def build(col, high):
        obs = []
        hw, hd = BN_W / 2, BN_D / 2
        obs.append(gbox("Barn Walls", (BN_W, BN_H, BN_D), (0, BN_H / 2, 0), boards, col))
        if high:
            obs.append(gbox("Footing", (BN_W + 0.1, 0.4, BN_D + 0.1), (0, 0.2, 0), base, col, bevel=0.03))
            # battens over the board seams, all round
            for k in range(int(BN_D / 0.4)):
                z = -hd + (k + 0.5) * 0.4
                for sx in (-1, 1):
                    if sx < 0 and abs(z) < 3.3:
                        continue                              # behind the doors
                    obs.append(gbox("Batten", (0.04, BN_H - 0.4, 0.06), (sx * (hw + 0.02), BN_H / 2 + 0.2, z), boards,
                                    col))
            for k in range(int(BN_W / 0.4)):
                x = -hw + (k + 0.5) * 0.4
                for sz in (-1, 1):
                    obs.append(gbox("Batten", (0.06, BN_H - 0.4, 0.04), (x, BN_H / 2 + 0.2, sz * (hd + 0.02)), boards,
                                    col))
            for sx in (-1, 1):                                # white corner boards and an eave board
                for sz in (-1, 1):
                    obs.append(gbox("Corner", (0.18, BN_H, 0.18), (sx * hw, BN_H / 2, sz * hd), trim, col))
        # the gable ends of the gambrel (the walls go on up under the roof)
        prof = [(-hw, BN_H), (-hw * 0.62, 8.1), (0, 9.2), (hw * 0.62, 8.1), (hw, BN_H)]
        for sz in (-1, 1):
            z0 = sz * hd
            obs.append(gprism("Gable", prof, z0 - 0.15 * sz if sz > 0 else z0, z0 if sz > 0 else z0 + 0.15, boards,
                              col))
        # the roof: four slopes of slate a little out past the walls
        roof_pts = [(-hw - 0.35, BN_H - 0.2), (-hw * 0.62 - 0.1, 8.2), (0, 9.35), (hw * 0.62 + 0.1, 8.2),
                    (hw + 0.35, BN_H - 0.2)]
        for i in range(4):
            (x0, y0), (x1, y1) = roof_pts[i], roof_pts[i + 1]
            ang = math.atan2(y1 - y0, x1 - x0)
            ln = math.hypot(x1 - x0, y1 - y0)
            obs.append(gbox("Barn Roof", (ln + 0.06, 0.16, BN_D + 0.7), ((x0 + x1) / 2, (y0 + y1) / 2, 0), slate, col,
                            rot=(0, 0, ang)))
            if high:
                rows = max(4, int(ln / 0.32))
                for r in range(rows):
                    t = (r + 0.5) / rows
                    x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                    for c in range(30):
                        z = -hd - 0.35 + (c + 0.5 + 0.5 * (r % 2)) * (BN_D + 0.7) / 30
                        if abs(z) > hd + 0.33:
                            continue
                        jit = 0.015 * noise.noise(Vector((r * 0.7 + i, c * 1.1, 0.3)))
                        obs.append(gbox("Slate", (ln / rows + 0.05, 0.03, (BN_D + 0.7) / 30 - 0.03),
                                        (x, y + 0.1 + jit, z), slate, col, rot=(jit * 3, 0, ang - 0.04)))
        obs.append(grod("Barn Ridge", (0, 9.4, -hd - 0.35), (0, 9.4, hd + 0.35), 0.1, slate, col,
                        seg=10 if high else 6))
        # the doors on the -X side: two white doors with crossed braces, hinges, and the hayloft door over them
        x = -hw - 0.03
        for z in (-1.6, 1.6):
            obs.append(gbox("Door", (0.08, 3.6, 3.2), (x, 1.8, z), trim, col))
            if high:
                for (a, b) in (((0.2, z - 1.45), (3.4, z + 1.45)), ((0.2, z + 1.45), (3.4, z - 1.45))):
                    dy, dz = b[0] - a[0], b[1] - a[1]
                    obs.append(gbox("Brace", (0.05, 0.16, math.hypot(dy, dz)),
                                    (x - 0.06, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2), boards, col,
                                    rot=(-math.atan2(dy, dz), 0, 0)))
                for y in (0.15, 3.45, 1.8):
                    obs.append(gbox("Rail", (0.05, 0.16, 3.1), (x - 0.06, y, z), boards, col))
                for y in (0.6, 3.0):
                    obs.append(gbox("Hinge", (0.03, 0.08, 0.6), (x - 0.1, y, z + (1.2 if z > 0 else -1.2)), iron, col))
        obs.append(gbox("Loft Door", (0.08, 1.6, 1.6), (x, 4.6, 0), trim, col))
        if high:
            obs.append(gbox("Loft Hole", (0.04, 1.3, 1.3), (x - 0.05, 4.6, 0), hay, col))
            for k in range(6):
                obs.append(blob("Hay", 0.22, (x - 0.08, 4.0 + 0.04 * k, -0.5 + k * 0.2), hay, col, seed=k, seg=8,
                                lump=0.5, squash=(0.5, 0.6, 1.0)))
            obs.append(grod("Hoist", (x, 5.7, 0), (x - 1.0, 5.7, 0), 0.06, boards, col))
            obs.append(grod("Rope", (x - 0.95, 5.65, 0), (x - 0.95, 4.2, 0), 0.015, hay, col, seg=6))
            # the weathervane on the ridge: a post, the arrow and a cockerel
            obs.append(grod("Vane Post", (0, 9.4, 0), (0, 10.4, 0), 0.03, iron, col, seg=8))
            obs.append(grod("Arrow", (-0.5, 10.25, 0), (0.5, 10.25, 0), 0.02, brass, col, seg=8))
            obs.append(gbox("Tail", (0.18, 0.18, 0.02), (-0.55, 10.25, 0), brass, col, rot=(0, 0, 0.785)))
            obs.append(gbox("Cockerel", (0.4, 0.3, 0.03), (0.05, 10.55, 0), brass, col, bevel=0.02))
            for k in range(4):                               # the four points of the compass
                a = k * math.pi / 2
                obs.append(grod("Point", (0, 10.0, 0), (math.cos(a) * 0.3, 10.0, math.sin(a) * 0.3), 0.012, iron, col,
                                seg=6))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, emit = {
    "standing_stone": (standing_stone, 512, 0.08, 0.16, False),
    "cairn": (cairn, 512, 0.08, 0.16, False),
    "summit_cairn": (summit_cairn, 512, 0.08, 0.16, False),
    "croft": (croft, 1024, 0.08, 0.16, True),
    "barn": (barn, 1024, 0.08, 0.16, False),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

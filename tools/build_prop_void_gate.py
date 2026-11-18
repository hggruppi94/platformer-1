# The Void's race and skate landmarks, built the detailed way (tools/bake_kit.py; 18 Nov 2026, Hayden: "Keep going",
# scenery batch nine): Tally's request board in the Market Square, the races' start arch, race board and Zippy's
# Tune-Up, and the skate parks' Run Clocks. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces the game builds from shapes (scripts/request_board.gd, scripts/race_track.gd _arch, _board,
# _tune_up, scripts/skate_runs.gd _make_clock), so the swap (scripts/detail_props.gd) puts each exactly where the old
# one was. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   request_board  two carved posts with star finials, a panelled navy board in a gold frame (the game's own words
#                  sit at z 0.07, so the board's face stays behind z 0.065), and a shingled lilac roof. The spinning
#                  star on top is the game's.
#   race_board     the board by the starter: posts with chequered flags, a navy face in a gold frame and a chequered
#                  header (its words at z 0.07 too).
#   tune_up        Zippy's Tune-Up: a bench with drawers, a tool rack, a spare wheel with spokes and tread, a pink oil
#                  can, a pump, a stack of tyres, and a teal awning with a chequered edge (its sign stays the game's).
#   run_clock      a fluted lamp-post with a big clock face (the game's own hand turns over it, so the face stays
#                  behind z 0.1), a gold bezel and crown, and the SKATE RUN sign board on scroll brackets.
#   arch_tower     one of the start arch's two towers, from the ground to the tip (7.2 m): a banded lilac tower on a
#                  plinth with slit windows, gold bands and a gold spire with a star.
#   arch_banner    the banner between them, 12.4 m wide (the game stretches it to each arch): navy cloth with gold
#                  piping, a chequered strip along the bottom and gold tassels (the race's name is the game's label,
#                  at z 0.12 each side, so the cloth stays inside z 0.1).
# Colours are the game's own (sRGB). Collisions stay the game's.
#
#   python tools/build_prop_void_gate.py "<out>.glb" <kind> [--preview]
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["request_board", "race_board", "tune_up", "run_clock", "arch_tower", "arch_banner"]
KIND = next((a for a in sys.argv if a in KINDS), "race_board")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

WOOD = (0.42, 0.2, 0.17)
FACE = (0.98, 0.95, 0.85)
BRASS = (0.85, 0.62, 0.25)
INK = (0.08, 0.05, 0.12)
ROCK = (0.5, 0.44, 0.55)
MOSS = (0.3, 0.6, 0.35)
LILAC = (0.62, 0.5, 0.95)
GOLD = (1.0, 0.82, 0.3)
STALL_WOOD = (0.36, 0.22, 0.42)
TEAL = (0.3, 0.9, 0.82)
PINK = (1.0, 0.5, 0.78)
BOARD = (0.22, 0.16, 0.34)


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


def mesh_from(name, verts, faces, m, col, smooth=False):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, smooth, col)


def prism(name, outline, y0, y1, m, col):
    """A flat shape (Blender x/z outline) given thickness along Blender y from y0 to y1."""
    n = len(outline)
    verts = [(x, y0, z) for x, z in outline] + [(x, y1, z) for x, z in outline]
    faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return mesh_from(name, verts, faces, m, col)


def flat_disc_prism(name, outline, z0, z1, m, col):
    """A flat shape (Blender x/y outline) given thickness along Blender z (Godot y) from z0 to z1."""
    n = len(outline)
    verts = [(x, y, z0) for x, y in outline] + [(x, y, z1) for x, y in outline]
    faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return mesh_from(name, verts, faces, m, col)


def bevel(ob, width, seg=2):
    bv = ob.modifiers.new("Bevel", "BEVEL")
    bv.width = width
    bv.segments = seg
    bv.limit_method = "ANGLE"
    return ob


def _nodes(m):
    nt = m.node_tree
    return nt, nt.nodes["Principled BSDF"], nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]


def _mix_rgb(nt, fac, a, b):
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(fac, mix.inputs["Factor"])
    K._rgba(mix.inputs, "A").default_value = (*(K.srgb_to_linear(c) for c in a), 1)
    K._rgba(mix.inputs, "B").default_value = (*(K.srgb_to_linear(c) for c in b), 1)
    return K._rgba(mix.outputs, "Result")


def mottled(name, a, b, scale=6.0, rough=0.6, metal=0.0, bump=0.0):
    """A material that wanders between two colours (aged brass, dusty paint)."""
    m = K.mat(name, a, rough=rough, metal=metal, bump=bump)
    nt, bsdf, co = _nodes(m)
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 6.0
    nt.links.new(co, nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["From Min"].default_value = 0.35
    ramp.inputs["From Max"].default_value = 0.7
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Value"])
    nt.links.new(_mix_rgb(nt, ramp.outputs["Result"], a, b), bsdf.inputs["Base Color"])
    return m


def star_outline(r_out, r_in, points=5, cx=0.0, cy=0.0, turn=math.pi / 2):
    pts = []
    for i in range(points * 2):
        a = turn + i / (points * 2) * math.tau
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts




CREAM = (0.98, 0.96, 0.9)
DARK = (0.15, 0.1, 0.25)
NAVY = (0.22, 0.16, 0.34)
GOLD_T = (1.0, 0.82, 0.35)


def ring_mesh(name, r_in, r_out, depth, centre, m, col, seg=32):
    """A flat ring facing Godot's +Z (a clock's bezel), centre in Godot terms, depth along Z from its back."""
    cx, cy, cz = centre
    verts = []
    for k in range(seg):
        a = k / seg * math.tau
        for r in (r_in, r_out):
            for z in (cz, cz + depth):
                verts.append(at(cx + math.cos(a) * r, cy + math.sin(a) * r, z))
    faces = []
    for k in range(seg):
        j = (k + 1) % seg
        i0, j0 = k * 4, j * 4
        # (inner back, inner front, outer back, outer front) = +0, +1, +2, +3
        faces += [[i0 + 1, j0 + 1, j0 + 3, i0 + 3], [i0, i0 + 2, j0 + 2, j0], [i0 + 2, i0 + 3, j0 + 3, j0 + 2],
                  [i0, j0, j0 + 1, i0 + 1]]
    return mesh_from(name, verts, faces, m, col)


def checks(name, x0, x1, cells, y0, rows, row_h, z, depth, light, dark, col, bevel_w=0.0):
    obs = []
    w = (x1 - x0) / cells
    for k in range(cells):
        for r in range(rows):
            obs.append(gbox(name, (w, row_h, depth), (x0 + (k + 0.5) * w, y0 + (r + 0.5) * row_h, z),
                            light if (k + r) % 2 == 0 else dark, col, bevel=bevel_w))
    return obs


def check_mats():
    return K.mat("Check White", CREAM, rough=0.55, bump=0.15), K.mat("Check Dark", DARK, rough=0.55, bump=0.15)


# ================================================================ Tally's request board
def request_board():
    WD, HT = 3.4, 2.3
    wood = K.mat("Board Wood", STALL_WOOD, rough=0.6, grain=(8.0, 0.3), bump=0.1)
    navy = K.mat("Board Navy", NAVY, rough=0.6, grain=(5.0, 0.15), bump=0.08)
    inset = K.mat("Board Inset", tuple(c * 0.8 for c in NAVY), rough=0.65, grain=(5.0, 0.12))
    gold = mottled("Board Gold", GOLD_T, (0.82, 0.6, 0.2), scale=8.0, rough=0.3, metal=0.6)
    roof = mottled("Board Roof", LILAC, (0.5, 0.4, 0.82), scale=12.0, rough=0.7)
    roof_dark = K.mat("Roof Under", tuple(c * 0.7 for c in LILAC), rough=0.8)
    A = 0.18

    def rp(x, u, h):
        """A point on the roof: across x, along its slope u (front +), h above its middle plane."""
        return (x, 3.4 + h * math.cos(A) - u * math.sin(A), 0.1 + h * math.sin(A) + u * math.cos(A))

    def build(col, high):
        obs = []
        b = 0.015 if high else 0
        px = WD / 2 + 0.05
        for s in (-1, 1):
            obs.append(gbox("Post", (0.14, 3.3, 0.14), (s * px, 1.65, 0), wood, col, bevel=b))
            if high:
                obs.append(gbox("Post Foot", (0.24, 0.3, 0.24), (s * px, 0.15, 0), wood, col, bevel=0.02))
                obs.append(gbox("Foot Band", (0.26, 0.04, 0.26), (s * px, 0.31, 0), gold, col, bevel=0.008))
                for y in (0.85, 3.15):
                    obs.append(gbox("Post Collar", (0.2, 0.06, 0.2), (s * px, y, 0), gold, col, bevel=0.01))
                # a groove down each face and a star on the front
                for k in range(2):
                    obs.append(gbox("Post Groove", (0.02, 1.8, 0.145), (s * px + (k - 0.5) * 0.06, 1.95, 0),
                                    K.mat("Groove", tuple(c * 0.6 for c in STALL_WOOD), rough=0.8), col))
                obs.append(prism("Post Star", star_outline(0.07, 0.03, cx=s * px, cy=0.55), -0.07, -0.076, gold, col))
        # the board: a frame of wood round a sunken panel of planks (its face stays behind z 0.065)
        obs.append(gbox("Board", (WD, HT, 0.12), (0, 2.0, 0), navy, col, bevel=b / 2))
        if high:
            obs.append(gbox("Inset", (WD - 0.3, HT - 0.3, 0.01), (0, 2.0, 0.058), inset, col))
            for k in range(1, 6):
                obs.append(gbox("Plank Line", (WD - 0.3, 0.012, 0.004), (0, 2.0 - (HT - 0.3) / 2 + k * (HT - 0.3) / 6,
                                                                          0.0625), K.mat("Plank Gap", DARK), col))
            for s in (-1, 1):
                obs.append(gbox("Side Trim", (0.06, HT, 0.14), (s * (WD / 2 - 0.03), 2.0, 0.01), gold, col,
                                bevel=0.008))
        for s in (-1, 1):
            obs.append(gbox("Trim", (WD + 0.2, 0.08, 0.16), (0, 2.0 + s * HT / 2, 0.01), gold, col, bevel=b / 2))
        if high:
            # gold scroll brackets in the corners between the posts and the board
            for sx in (-1, 1):
                for sy in (-1, 1):
                    cx, cy = sx * (WD / 2 - 0.12), 2.0 + sy * (HT / 2 - 0.12)
                    pts = [(p[0], -0.075, p[2]) for p in K.scroll(cx, cy, 0.09, 1.3, steps=20)]
                    obs.append(K.wire("Corner Scroll", pts, 0.008, gold, col=col))
            # studs along the trims
            for k in range(16):
                x = -WD / 2 + 0.15 + k * (WD - 0.3) / 15
                for s in (-1, 1):
                    obs.append(K.sphere("Stud", 0.014, at=at(x, 2.0 + s * HT / 2, 0.092), m=gold, seg=8, col=col))
        # the roof
        if high:
            obs.append(gbox("Roof Deck", (WD + 0.6, 0.04, 0.9), rp(0, 0, -0.03), roof_dark, col, rot=(A, 0, 0)))
            rows = 6
            for r in range(rows):
                u = -0.42 + (r + 0.5) * 0.84 / rows
                n = 13 + (r % 2)
                for k in range(n):
                    x = -(WD + 0.6) / 2 + (k + (0.5 if r % 2 == 0 else 0.0)) * (WD + 0.6) / 13
                    if abs(x) > (WD + 0.6) / 2 - 0.05:
                        continue
                    tilt = 0.05 * math.sin(k * 2.3 + r)
                    obs.append(gbox("Shingle", ((WD + 0.6) / 13 - 0.02, 0.025, 0.2), rp(x, u, 0.0 + 0.01 * (r % 2)),
                                    roof, col, bevel=0.008, rot=(A + 0.08, 0, tilt)))
            obs.append(gbox("Ridge", (WD + 0.66, 0.06, 0.08), rp(0, -0.44, 0.04), gold, col, bevel=0.012, rot=(A, 0, 0)))
            obs.append(gbox("Fascia", (WD + 0.62, 0.1, 0.03), rp(0, 0.45, -0.03), gold, col, bevel=0.008,
                            rot=(A, 0, 0)))
            for k in range(14):
                x = -(WD + 0.5) / 2 + k * (WD + 0.5) / 13
                fl = K.cyl("Scallop", 0.07, 0.02, at=at(*rp(x, 0.46, -0.1)), seg=16, m=roof, col=col,
                           rot=(math.pi / 2 - A, 0, 0))
                obs.append(fl)
        else:
            obs.append(gbox("Roof", (WD + 0.6, 0.1, 0.9), (0, 3.4, 0.1), roof, col, rot=(A, 0, 0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the race board
def race_board():
    wood = K.mat("Board Wood", STALL_WOOD, rough=0.6, grain=(8.0, 0.3), bump=0.1)
    navy = K.mat("Board Navy", NAVY, rough=0.6, grain=(5.0, 0.15), bump=0.08)
    gold = mottled("Board Gold", GOLD_T, (0.82, 0.6, 0.2), scale=8.0, rough=0.3, metal=0.6)
    white, dark = check_mats()

    def build(col, high):
        obs = []
        b = 0.012 if high else 0
        for s in (-1, 1):
            obs.append(gbox("Post", (0.14, 3.3, 0.14), (s * 1.45, 1.65, 0), wood, col, bevel=b))
            if high:
                obs.append(gbox("Post Foot", (0.22, 0.25, 0.22), (s * 1.45, 0.125, 0), wood, col, bevel=0.02))
                obs.append(gbox("Foot Band", (0.24, 0.04, 0.24), (s * 1.45, 0.27, 0), gold, col, bevel=0.008))
                obs.append(K.sphere("Post Ball", 0.06, at=at(s * 1.45, 3.62, 0), m=gold, seg=16, col=col))
            # a little chequered flag on top of each post
            obs.append(gbox("Flag Pole", (0.03, 0.4, 0.03), (s * 1.45, 3.5, 0), gold, col))
            obs += checks("Flag", s * 1.45 + (0.02 if s > 0 else -0.38), s * 1.45 + (0.38 if s > 0 else -0.02), 4,
                          3.4, 2, 0.1, 0, 0.012, white, dark, col)
        obs.append(gbox("Face", (2.9, 2.3, 0.1), (0, 2.05, 0), navy, col, bevel=b / 2))
        obs.append(gbox("Top", (3.1, 0.12, 0.16), (0, 3.25, 0.01), gold, col, bevel=b / 2))
        if high:
            for s in (-1, 1):
                obs.append(gbox("Frame Side", (0.06, 2.3, 0.13), (s * 1.42, 2.05, 0.01), gold, col, bevel=0.008))
            obs.append(gbox("Frame Foot", (3.0, 0.07, 0.14), (0, 0.9, 0.01), gold, col, bevel=0.008))
            for k in range(14):
                obs.append(K.sphere("Stud", 0.013, at=at(-1.35 + k * 2.7 / 13, 3.25, 0.093), m=gold, seg=8, col=col))
        # a chequered header along the top
        obs += checks("Header", -1.5, 1.5, 20, 3.31, 2, 0.08, 0.0, 0.1, white, dark, col, bevel_w=0.004 if high else 0)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ Zippy's Tune-Up
def tune_up():
    wood = K.mat("Bench Wood", STALL_WOOD, rough=0.6, grain=(8.0, 0.3), bump=0.1)
    top = mottled("Bench Top", LILAC, (0.55, 0.43, 0.88), scale=2.0, rough=0.45)
    gold = mottled("Bench Gold", GOLD_T, (0.82, 0.6, 0.2), scale=8.0, rough=0.3, metal=0.6)
    navy = K.mat("Rack Navy", NAVY, rough=0.6)
    teal = K.mat("Awning Teal", (0.3, 0.85, 0.85), rough=0.8, bump=0.25)
    steel = K.mat("Tool Steel", (0.8, 0.82, 0.9), rough=0.3, metal=0.9, pits=0.15)
    tyre = K.mat("Tyre", DARK, rough=0.85, bump=0.3)
    pink = K.mat("Oil Can", (1.0, 0.45, 0.7), rough=0.35, metal=0.4)
    white, dark = check_mats()
    A = 0.2

    def ap(x, u, h):
        return (x, 2.6 + h * math.cos(A) - u * math.sin(A), 0.1 + h * math.sin(A) + u * math.cos(A))

    def build(col, high):
        obs = []
        b = 0.012 if high else 0
        obs.append(gbox("Bench Top", (2.6, 0.12, 1.0), (0, 0.95, 0), top, col, bevel=b))
        for x in (-1.15, 1.15):
            for z in (-0.4, 0.4):
                obs.append(gbox("Leg", (0.1, 0.95, 0.1), (x, 0.47, z), wood, col, bevel=b))
        for x in (-1.3, 1.3):
            obs.append(gbox("Pole", (0.1, 2.6, 0.1), (x, 1.3, -0.45), wood, col, bevel=b))
        obs.append(gbox("Rack", (2.4, 0.9, 0.06), (0, 1.75, -0.45), navy, col, bevel=b / 2))
        # the spare wheel on the bench, standing up and facing out
        if high:
            ring = [(0.75 + math.cos(i / 40 * math.tau) * 0.25, -0.05, 1.34 + math.sin(i / 40 * math.tau) * 0.25)
                    for i in range(40)]
            obs.append(K.wire("Tyre", ring, 0.07, tyre, closed=True, res=4, bevel_res=4, col=col))
            for k in range(28):
                a = k / 28 * math.tau
                obs.append(gbox("Tread", (0.035, 0.05, 0.16), (0.75 + math.cos(a) * 0.318, 1.34 + math.sin(a) * 0.318,
                                                               0.05), tyre, col, rot=(0, 0, a + math.pi / 2)))
            obs.append(K.cyl("Rim", 0.18, 0.08, at=at(0.75, 1.34, 0.05), seg=32, m=steel, col=col,
                             rot=(math.pi / 2, 0, 0)))
            obs.append(K.cyl("Hub", 0.06, 0.14, at=at(0.75, 1.34, 0.05), seg=20, m=gold, col=col,
                             rot=(math.pi / 2, 0, 0)))
            for k in range(6):
                a = k / 6 * math.tau
                obs.append(rod("Spoke", at(0.75 + math.cos(a) * 0.05, 1.34 + math.sin(a) * 0.05, 0.1),
                               at(0.75 + math.cos(a) * 0.17, 1.34 + math.sin(a) * 0.17, 0.1), 0.012, gold, col, seg=6))
        else:
            obs.append(K.cyl("Wheel", 0.32, 0.14, at=at(0.75, 1.34, 0.05), seg=16, m=tyre, col=col,
                             rot=(math.pi / 2, 0, 0)))
        # the oil can
        if high:
            can = K.lathe("Oil Can", [(0, 0), (0.13, 0), (0.13, 0.02), (0.12, 0.2), (0.08, 0.27), (0.03, 0.3),
                                      (0.03, 0.34), (0, 0.34)], seg=24, m=pink, col=col)
            can.location = at(-0.7, 1.01, 0.1)
            obs.append(can)
            obs.append(rod("Spout", at(-0.7, 1.3, 0.1), at(-0.5, 1.42, 0.1), 0.012, gold, col, seg=8))
            obs.append(K.wire("Can Handle", [at(-0.82, 1.22, 0.1), at(-0.9, 1.25, 0.1), at(-0.9, 1.12, 0.1),
                                              at(-0.82, 1.08, 0.1)], 0.012, gold, col=col))
            for y in (1.05, 1.18):
                obs.append(K.cyl("Can Band", 0.132, 0.02, at=at(-0.7, y, 0.1), seg=24, m=gold, col=col))
            # a pump on the bench
            obs.append(K.cyl("Pump", 0.05, 0.36, at=at(-0.15, 1.19, 0.25), seg=16, m=K.mat("Pump", (0.3, 0.85, 0.85),
                                                                                           rough=0.4, metal=0.3), col=col))
            obs.append(gbox("Pump Foot", (0.22, 0.03, 0.1), (-0.15, 1.025, 0.25), steel, col, bevel=0.006))
            obs.append(rod("Pump Rod", at(-0.15, 1.37, 0.25), at(-0.15, 1.46, 0.25), 0.01, steel, col, seg=6))
            obs.append(gbox("Pump Handle", (0.2, 0.03, 0.03), (-0.15, 1.47, 0.25), K.mat("Grip", DARK, rough=0.7), col,
                            bevel=0.008))
            # drawers in the bench front, a shelf underneath with a stack of tyres
            for x in (-0.65, 0.0, 0.65):
                obs.append(gbox("Drawer", (0.58, 0.18, 0.02), (x, 0.78, 0.46), top, col, bevel=0.006))
                obs.append(gbox("Drawer Pull", (0.14, 0.025, 0.025), (x, 0.78, 0.48), gold, col, bevel=0.006))
            obs.append(gbox("Apron", (2.3, 0.22, 0.9), (0, 0.78, 0), wood, col, bevel=0.01))
            obs.append(gbox("Shelf", (2.3, 0.04, 0.8), (0, 0.2, 0), wood, col, bevel=0.008))
            for k in range(3):
                obs.append(K.lathe("Stack Tyre", [(0.1, 0), (0.24, 0), (0.27, 0.04), (0.27, 0.08), (0.24, 0.12),
                                                  (0.1, 0.12)], seg=32, m=tyre, col=col))
                obs[-1].location = at(-0.7, 0.22 + k * 0.125, 0.0)
            # the rack's spanners, biggest to smallest, and a gold rim
            for k in range(6):
                ln = 0.55 - k * 0.06
                x = -0.95 + k * 0.3
                obs.append(gbox("Spanner", (0.05, ln, 0.015), (x, 1.82 - ln / 2 + 0.25, -0.41), steel, col,
                                bevel=0.005))
                for e in (-1, 1):
                    obs.append(K.cyl("Spanner Head", 0.04 - k * 0.003, 0.015,
                                     at=at(x, 1.82 + 0.25 - ln / 2 + e * ln / 2, -0.41), seg=16, m=steel, col=col,
                                     rot=(math.pi / 2, 0, 0)))
                obs.append(rod("Peg", at(x, 2.07, -0.43), at(x, 2.07, -0.39), 0.006, gold, col, seg=6))
            for s in (-1, 1):
                obs.append(gbox("Rack Rim", (2.44, 0.04, 0.08), (0, 1.75 + s * 0.45, -0.45), gold, col, bevel=0.006))
            # the awning: teal with a chequered band along its front
            obs.append(gbox("Awning", (3.0, 0.06, 1.1), ap(0, -0.15, 0), teal, col, bevel=0.01, rot=(A, 0, 0)))
            for k in range(20):
                for r in range(2):
                    obs.append(gbox("Awning Check", (0.15, 0.07, 0.15), ap(-1.5 + (k + 0.5) * 0.15, 0.475 + r * 0.15,
                                                                          0.0), white if (k + r) % 2 == 0 else dark,
                                    col, bevel=0.006, rot=(A, 0, 0)))
            obs.append(gbox("Awning Edge", (3.02, 0.08, 0.03), ap(0, 0.71, -0.01), gold, col, bevel=0.008,
                            rot=(A, 0, 0)))
        else:
            obs.append(gbox("Oil Can", (0.26, 0.3, 0.26), (-0.7, 1.16, 0.1), pink, col))
            obs.append(gbox("Apron", (2.3, 0.22, 0.9), (0, 0.78, 0), wood, col))
            obs.append(gbox("Shelf", (2.3, 0.04, 0.8), (0, 0.2, 0), wood, col))
            obs.append(K.cyl("Stack", 0.27, 0.38, at=at(-0.7, 0.41, 0), seg=12, m=tyre, col=col))
            obs.append(gbox("Pump", (0.22, 0.48, 0.1), (-0.15, 1.25, 0.25), steel, col))
            obs.append(gbox("Awning", (3.04, 0.08, 1.42), (0, 2.6, 0.1), teal, col, rot=(A, 0, 0)))
            obs.append(gbox("Spanners", (1.8, 0.6, 0.04), (0, 1.8, -0.41), steel, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Run Clock
def run_clock():
    post = mottled("Clock Post", LILAC, (0.52, 0.41, 0.85), scale=4.0, rough=0.5)
    gold = mottled("Clock Gold", GOLD_T, (0.82, 0.6, 0.2), scale=8.0, rough=0.3, metal=0.7)
    navy = K.mat("Clock Back", NAVY, rough=0.5)
    face = K.mat("Clock Face", (0.98, 0.95, 0.85), rough=0.4, emit=0.5)
    ink = K.mat("Clock Ink", NAVY, rough=0.5)
    pink = K.mat("Clock Pink", (1.0, 0.45, 0.7), rough=0.4, emit=0.4)
    board = K.mat("Sign Board", NAVY, rough=0.55, grain=(6.0, 0.2))
    C = 3.2

    def build(col, high):
        obs = []
        if high:
            p = K.lathe("Post", [(0, 0), (0.24, 0), (0.24, 0.08), (0.2, 0.12), (0.2, 0.3), (0.15, 0.36), (0.12, 0.42),
                                 (0.12, 0.5), (0.1, 0.55), (0.09, 2.45), (0.12, 2.5), (0.12, 2.6), (0, 2.6)],
                        seg=24, m=post, col=col, flutes=10, flute_depth=0.012, flute_z=(0.6, 2.4))
            obs.append(p)
            for y in (0.42, 1.1, 2.45):
                obs.append(K.cyl("Collar", 0.125 if y > 1 else 0.14, 0.04, at=at(0, y, 0), seg=24, m=gold, col=col))
        else:
            obs.append(K.cyl("Post", 0.11, 2.6, at=at(0, 1.3, 0), seg=10, m=post, col=col, r2=0.09))
            obs.append(K.cyl("Base", 0.24, 0.3, at=at(0, 0.15, 0), seg=10, m=post, col=col))
        # the clock: a navy back, the glowing face, the gold bezel (the hand turns at z 0.12, so all its face stays
        # behind z 0.1)
        obs.append(K.cyl("Clock Back", 0.78, 0.14, at=at(0, C, -0.01), seg=48 if high else 20, m=navy, col=col,
                         rot=(math.pi / 2, 0, 0)))
        obs.append(K.cyl("Face", 0.72, 0.01, at=at(0, C, 0.065), seg=64 if high else 20, m=face, col=col,
                         rot=(math.pi / 2, 0, 0)))
        obs.append(ring_mesh("Bezel", 0.7, 0.86, 0.14, (0, C, -0.04), gold, col, seg=64 if high else 24))
        if high:
            ring = [(math.cos(i / 48 * math.tau) * 0.78, -0.1, C + math.sin(i / 48 * math.tau) * 0.78)
                    for i in range(48)]
            obs.append(K.wire("Bezel Bead", ring, 0.025, gold, closed=True, res=4, bevel_res=3, col=col))
            for k in range(60):
                a = k / 60 * math.tau
                big = k % 5 == 0
                r = 0.58 if big else 0.62
                obs.append(gbox("Mark", (0.04 if big else 0.012, 0.13 if big else 0.04, 0.008),
                                (math.sin(a) * r, C + math.cos(a) * r, 0.073), pink if k % 15 == 0 else ink, col,
                                rot=(0, 0, -a)))
            for k in range(12):
                a = (k + 0.5) / 12 * math.tau
                obs.append(prism("Dial Star", star_outline(0.025, 0.01, cx=math.sin(a) * 0.43,
                                                           cy=C + math.cos(a) * 0.43), -0.071, -0.075, gold, col))
            # a chequered ring inside the marks, like a race flag
            for k in range(24):
                a0, a1 = k / 24 * math.tau, (k + 1) / 24 * math.tau
                for rr, r0, r1 in ((0, 0.3, 0.34), (1, 0.34, 0.38)):
                    pts = [(math.sin(a0) * r0, C + math.cos(a0) * r0), (math.sin(a1) * r0, C + math.cos(a1) * r0),
                           (math.sin(a1) * r1, C + math.cos(a1) * r1), (math.sin(a0) * r1, C + math.cos(a0) * r1)]
                    obs.append(prism("Dial Check", pts, -0.0705, -0.072, ink if (k + rr) % 2 else face, col))
            # the crown on top: a gold cap, a little bell and a star
            obs.append(K.lathe("Crown", [(0, 0), (0.16, 0), (0.18, 0.03), (0.1, 0.1), (0.05, 0.14), (0, 0.15)],
                               seg=24, m=gold, col=col))
            obs[-1].location = at(0, C + 0.84, -0.01)
            obs.append(prism("Crown Star", star_outline(0.07, 0.03, cy=C + 1.06), -0.015, 0.0, gold, col))
            obs.append(rod("Star Stem", at(0, C + 0.98, -0.01), at(0, C + 1.0, -0.01), 0.012, gold, col, seg=6))
        else:
            obs.append(K.cyl("Crown", 0.17, 0.15, at=at(0, C + 0.91, -0.01), seg=12, m=gold, col=col, r2=0.04))
            obs.append(prism("Crown Star", star_outline(0.07, 0.03, cy=C + 1.06), -0.015, 0.0, gold, col))
        # the sign board on scroll brackets
        obs.append(gbox("Sign", (1.9, 0.75, 0.08), (0, 2.05, 0.05), board, col, bevel=0.012 if high else 0))
        if high:
            for s in (-1, 1):
                obs.append(gbox("Sign Frame", (1.96, 0.04, 0.1), (0, 2.05 + s * 0.375, 0.05), gold, col, bevel=0.008))
                obs.append(gbox("Sign Frame", (0.04, 0.79, 0.1), (s * 0.97, 2.05, 0.05), gold, col, bevel=0.008))
                pts = [at(s * 0.1, 2.62, 0.0), at(s * 0.4, 2.62, 0.02), at(s * 0.7, 2.55, 0.04),
                       at(s * 0.85, 2.45, 0.05)]
                obs.append(K.wire("Bracket", pts, 0.015, gold, col=col))
                obs.append(K.wire("Bracket Curl", [(x, -0.04, z) for x, _, z in
                                                   K.scroll(s * 0.42, 2.56, 0.06, 1.2, steps=16)], 0.01, gold, col=col))
                obs.append(K.sphere("Sign Gem", 0.03, at=at(s * 0.97, 2.43, 0.1), m=pink, seg=12, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the start arch
def arch_tower():
    stone = mottled("Tower Stone", LILAC, (0.55, 0.44, 0.86), scale=5.0, rough=0.7)
    band = K.mat("Tower Course", tuple(c * 0.82 for c in LILAC), rough=0.75)
    gold = mottled("Tower Gold", GOLD_T, (0.82, 0.6, 0.2), scale=6.0, rough=0.3, metal=0.7)
    slit = K.mat("Tower Window", (0.15, 0.1, 0.3), rough=0.3, emit=0.6, emit_rgb=(0.4, 0.95, 0.9))

    def build(col, high):
        obs = []
        if high:
            prof = [(0, 0), (0.78, 0), (0.78, 0.3), (0.72, 0.36), (0.66, 0.4)]
            # stone courses: a small step in the radius every 0.45 m as it tapers
            y = 0.4
            while y < 5.6:
                r = 0.6 - (y / 6.0) * 0.15
                prof += [(r + 0.012, y + 0.02), (r + 0.012, y + 0.41), (r, y + 0.43)]
                y += 0.45
            prof += [(0.5, 5.7), (0.62, 5.75), (0.62, 6.05), (0, 6.05)]
            obs.append(K.lathe("Tower", prof, seg=32, m=stone, col=col, sides=0))
            obs.append(K.lathe("Plinth", [(0, 0), (0.8, 0), (0.8, 0.32), (0, 0.32)], seg=8, m=band, col=col, sides=8))
            for y, r in ((2.0, 0.58), (4.4, 0.535)):
                obs.append(K.cyl("Gold Band", r, 0.1, at=at(0, y, 0), seg=32, m=gold, col=col))
            # battlements round the top
            for k in range(8):
                a = k / 8 * math.tau
                obs.append(gbox("Merlon", (0.2, 0.22, 0.14), (math.cos(a) * 0.55, 6.15, math.sin(a) * 0.55), stone,
                                col, bevel=0.015, rot=(0, -a + math.pi / 2, 0)))
            # slit windows that glow teal
            for k in range(4):
                a = k / 4 * math.tau + math.pi / 4
                r = 0.535
                obs.append(gbox("Window", (0.1, 0.5, 0.06), (math.cos(a) * r, 3.3, math.sin(a) * r), slit, col,
                                bevel=0.02, rot=(0, -a + math.pi / 2, 0)))
            # the gold spire with ribs and a star on top
            spire = K.lathe("Spire", [(0, 6.0), (0.7, 6.0), (0.7, 6.08), (0.5, 6.4), (0.3, 6.8), (0.12, 7.1),
                                      (0.04, 7.25), (0, 7.3)], seg=32, m=gold, col=col, flutes=8, flute_depth=0.03,
                            flute_z=(6.1, 7.1))
            obs.append(spire)
            obs.append(K.sphere("Spire Ball", 0.07, at=at(0, 7.3, 0), m=gold, seg=16, col=col))
            for turn in (0, math.pi / 2):
                st = prism("Star", star_outline(0.2, 0.08, cy=7.58), -0.02, 0.02, gold, col)
                st.rotation_euler = (0, 0, turn)
                obs.append(st)
        else:
            obs.append(K.lathe("Tower", [(0, 0), (0.78, 0), (0.78, 0.32), (0.62, 0.4), (0.47, 5.7), (0.62, 5.75),
                                         (0.62, 6.37), (0, 6.37)], seg=16, m=stone, col=col))
            obs.append(K.lathe("Spire", [(0, 6.0), (0.7, 6.0), (0.7, 6.08), (0.3, 6.8), (0, 7.3)], seg=16, m=gold,
                               col=col))
            for turn in (0, math.pi / 2):
                st = prism("Star", star_outline(0.2, 0.08, cy=7.58), -0.02, 0.02, gold, col)
                st.rotation_euler = (0, 0, turn)
                obs.append(st)
        return obs

    return build(HIGH, True), build(LOW, False)


def arch_banner():
    HW = 6.2
    cloth = K.mat("Banner Cloth", NAVY, rough=0.85, bump=0.35)
    gold = mottled("Banner Gold", GOLD_T, (0.82, 0.6, 0.2), scale=6.0, rough=0.3, metal=0.6)
    white, dark = check_mats()

    def build(col, high):
        obs = []
        # the cloth (the race's name is the game's label, at z 0.12 each side, so the cloth stays inside z 0.1)
        obs.append(gbox("Cloth", (HW * 2, 1.3, 0.18), (0, 5.4, 0), cloth, col, bevel=0.02 if high else 0))
        obs += checks("Check", -HW, HW, 24, 4.57, 2, 0.18, 0, 0.24, white, dark, col, bevel_w=0.01 if high else 0)
        if high:
            for y in (6.05, 4.93):
                pts = [(x / 20 * HW * 2 - HW, s * -0.1, y) for x in range(21) for s in (1,)]
                for s in (-1, 1):
                    obs.append(K.wire("Piping", [(p[0], s * 0.09, p[2]) for p in pts], 0.03, gold, col=col))
            # stitched quilting lines on both sides
            for k in range(1, 12):
                for s in (-1, 1):
                    obs.append(gbox("Stitch", (0.012, 1.0, 0.004), (-HW + k * HW * 2 / 12, 5.45, s * 0.091),
                                    K.mat("Stitch", (0.32, 0.24, 0.48), rough=0.9), col))
            # a gold star medallion near each end, both sides
            for x in (-HW + 0.7, HW - 0.7):
                for s in (-1, 1):
                    d = K.cyl("Medallion", 0.42, 0.02, at=at(x, 5.45, s * 0.095), seg=32, m=gold, col=col,
                              rot=(math.pi / 2, 0, 0))
                    obs.append(d)
                    obs.append(prism("Medallion Star", star_outline(0.3, 0.12, cx=x, cy=5.45), -s * 0.105, -s * 0.11,
                                     K.mat("Star Pink", (1.0, 0.45, 0.7), rough=0.4, emit=0.3), col))
            # tassels hanging along the bottom
            for k in range(13):
                x = -HW + 0.4 + k * (HW * 2 - 0.8) / 12
                obs.append(K.sphere("Tassel Knot", 0.05, at=at(x, 4.52, 0), m=gold, seg=12, col=col))
                obs.append(K.lathe("Tassel", [(0, 0), (0.06, 0.02), (0.05, 0.2), (0.02, 0.26), (0, 0.27)], seg=12,
                                   m=gold, col=col, flutes=10, flute_depth=0.01, flute_z=(0.02, 0.2)))
                obs[-1].location = at(x, 4.2, 0)
        else:
            for k in range(13):
                x = -HW + 0.4 + k * (HW * 2 - 0.8) / 12
                obs.append(K.cyl("Tassel", 0.06, 0.32, at=at(x, 4.36, 0), seg=6, m=gold, col=col, r2=0.04))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ bake and export
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


fn, size, emit, ext, ray = {
    "request_board": (request_board, 1024, False, 0.04, 0.1),
    "race_board": (race_board, 1024, False, 0.04, 0.1),
    "tune_up": (tune_up, 1024, False, 0.05, 0.12),
    "run_clock": (run_clock, 1024, True, 0.04, 0.1),
    "arch_tower": (arch_tower, 1024, True, 0.05, 0.12),
    "arch_banner": (arch_banner, 2048, True, 0.05, 0.12),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

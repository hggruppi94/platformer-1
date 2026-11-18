# The Void's park and sports corner, built the detailed way (tools/bake_kit.py; 18 Nov 2026, Hayden: "Yes fix those
# issues then keep going", scenery batch eleven): the basketball hoops, the tennis net, the soccer goals, the Rock
# Wall and the boarded-up old slide by the Haunted House. Each HIGH version is baked onto a LOW one, which is what the
# game draws.
#
# Sizes match the pieces tools/build_town.gd builds from shapes (court(), _soccer_field(), _rock_wall(),
# _old_slide()), so the swap (scripts/detail_props.gd) puts each exactly where the old one was and every collision
# stays the game's. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   basketball_hoop  a padded steel post on a bolted plate, the arm, a white backboard with its orange border and
#                    shooter's square, a pad along its foot, the orange rim on its bracket and a diamond-knotted net.
#   tennis_net       green posts with brass rings and a winder, a dark mesh with a cord grid, the white tape and the
#                    centre strap.
#   soccer_goal      round white posts and crossbar, the frame behind, pegs, and a net of cords over the back, roof
#                    and sides (baked without AO, so its cords stay white).
#   rock_wall        plywood panels with a grid of bolt holes, 55 lumpy holds (my own places), the seven ledges as
#                    chunky jugs on the game's boxes, a planked deck on top and a quilted crash mat with handles.
#   old_slide        weathered posts and rungs with rusty nails and moss at their feet, cross braces, the chute as a
#                    trough of planks with its teal paint peeling, and the planks nailed across the ladder.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_void_sports.py "<out>.glb" <kind> [--preview]
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["basketball_hoop", "tennis_net", "soccer_goal", "rock_wall", "old_slide"]
KIND = next((a for a in sys.argv if a in KINDS), "basketball_hoop")
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






def grod(name, a, b, r, m, col, seg=12, r2=None):
    """A round bar between two points given in Godot's terms."""
    return rod(name, at(*a), at(*b), r, m, col, seg=seg, r2=r2)


def blob(name, r, pos, m, col, seed=0, seg=12, lump=0.25, squash=(1.0, 1.0, 1.0)):
    """A lumpy round stone (a climbing hold), r across, at a Godot position, squashed along Godot x, y, z."""
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


def lerp(a, b, t):
    return a + (b - a) * t


# ================================================================ basketball hoop
# One of the court's two hoops (tools/build_town.gd court()): its post stands at the origin and the hoop faces -X
# (the game turns the other one round). Post 3.4 m, backboard 0.1 x 1.1 x 1.8 at x -0.2, y 3.3; the rim at x -0.55,
# y 3.0, 0.245 m across.
def basketball_hoop():
    steel = mottled("Hoop Steel", (0.75, 0.76, 0.8), (0.62, 0.63, 0.68), scale=10.0, rough=0.4, metal=0.7)
    pad = K.mat("Hoop Pad", (0.25, 0.55, 0.9), rough=0.8, bump=0.25)
    board = K.mat("Backboard", (1.0, 1.0, 1.0), rough=0.25)
    paint = K.mat("Backboard Paint", (1.0, 0.4, 0.1), rough=0.4)
    rim = K.mat("Hoop Rim", (1.0, 0.4, 0.1), rough=0.4, metal=0.5)
    cord = K.mat("Hoop Net", (0.97, 0.97, 0.95), rough=0.8)
    bolt = K.mat("Hoop Bolt", (0.35, 0.36, 0.4), rough=0.4, metal=0.8)

    def net(col, high):
        obs = []
        n = 12
        res = 6 if high else 3
        rows = [(2.98, 0.24), (2.82, 0.205), (2.66, 0.17), (2.52, 0.15)]
        for k in range(n):
            for i in range(len(rows) - 1):
                y0, r0 = rows[i]
                y1, r1 = rows[i + 1]
                for d in (-1, 1):                   # diamonds: each cord runs to the next ring's neighbours
                    a0 = (k + 0.5 * (i % 2)) / n * math.tau
                    a1 = (k + 0.5 * (i % 2) + 0.5 * d) / n * math.tau
                    p0 = (-0.55 + math.cos(a0) * r0, y0, math.sin(a0) * r0)
                    p1 = (-0.55 + math.cos(a1) * r1, y1, math.sin(a1) * r1)
                    obs.append(grod("Net Cord", p0, p1, 0.007 if high else 0.009, cord, col, seg=res))
        obs.append(K.wire("Net Bottom", [at(-0.55 + math.cos(k / 16 * math.tau) * 0.15, 2.52,
                                            math.sin(k / 16 * math.tau) * 0.15) for k in range(16)],
                          0.008, m=cord, closed=True, res=4 if high else 1, bevel_res=2 if high else 0, col=col))
        return obs

    def build(col, high):
        obs = []
        b = 0.015 if high else 0
        if high:
            obs.append(gbox("Post", (0.2, 3.3, 0.2), (0, 1.65, 0), steel, col, bevel=0.03))
            obs.append(gbox("Base Plate", (0.6, 0.05, 0.6), (0, 0.025, 0), steel, col, bevel=0.01))
            for sx in (-1, 1):
                for sz in (-1, 1):
                    obs.append(K.cyl("Bolt", 0.025, 0.05, at=at(sx * 0.22, 0.06, sz * 0.22), seg=6, m=bolt, col=col))
            obs.append(gbox("Pad", (0.3, 1.7, 0.3), (0, 1.05, 0), pad, col, bevel=0.05))
            for k in range(4):
                obs.append(gbox("Pad Seam", (0.31, 0.02, 0.31), (0, 0.45 + k * 0.4, 0), pad, col, bevel=0.008))
            # the arm out to the board: two bars and a brace
            for y in (3.1, 3.5):
                obs.append(gbox("Arm", (0.2, 0.08, 0.08), (-0.05, y, 0), steel, col, bevel=0.01))
            obs.append(grod("Arm Brace", (0.0, 3.1, 0), (-0.15, 3.5, 0), 0.025, steel, col, seg=8))
            obs.append(gbox("Post Cap", (0.24, 0.06, 0.24), (0, 3.33, 0), steel, col, bevel=0.015))
        else:
            obs.append(gbox("Post", (0.22, 3.4, 0.22), (0, 1.7, 0), steel, col))
            obs.append(gbox("Pad", (0.3, 1.7, 0.3), (0, 1.05, 0), pad, col))
            obs.append(gbox("Arm", (0.2, 0.5, 0.08), (-0.05, 3.3, 0), steel, col))
        # the backboard, its painted border and the shooter's square
        obs.append(gbox("Board", (0.1, 1.1, 1.8), (-0.2, 3.3, 0), board, col, bevel=b))
        if high:
            fx = -0.253
            for y in (2.78, 3.82):
                obs.append(gbox("Border", (0.008, 0.05, 1.74), (fx, y, 0), paint, col))
            for z in (-0.87, 0.87):
                obs.append(gbox("Border", (0.008, 1.09, 0.05), (fx, 3.3, z), paint, col))
            for y in (2.98, 3.42):
                obs.append(gbox("Square", (0.008, 0.04, 0.6), (fx, y, 0), paint, col))
            for z in (-0.28, 0.28):
                obs.append(gbox("Square", (0.008, 0.48, 0.04), (fx, 3.2, z), paint, col))
            obs.append(gbox("Board Pad", (0.14, 0.08, 1.84), (-0.2, 2.73, 0), pad, col, bevel=0.025))
            for z in (-0.9, 0.9):
                obs.append(gbox("Board Pad", (0.14, 0.4, 0.06), (-0.2, 2.93, z), pad, col, bevel=0.02))
            for y in (2.9, 3.7):
                for z in (-0.7, 0.7):
                    obs.append(K.cyl("Board Bolt", 0.02, 0.02, at=at(-0.255, y, z), rot=(0, math.pi / 2, 0), seg=8,
                                     m=bolt, col=col))
        else:
            obs.append(gbox("Board Pad", (0.14, 0.08, 1.84), (-0.2, 2.73, 0), pad, col))
        # the rim on its bracket
        obs.append(gbox("Rim Plate", (0.04, 0.16, 0.3), (-0.27, 3.0, 0), rim, col, bevel=b / 2))
        obs.append(gbox("Rim Bracket", (0.06, 0.03, 0.1), (-0.3, 3.0, 0), rim, col))
        obs.append(K.wire("Rim", [at(-0.55 + math.cos(k / 24 * math.tau) * 0.245, 3.0,
                                     math.sin(k / 24 * math.tau) * 0.245) for k in range(24)],
                          0.02, m=rim, closed=True, res=6 if high else 1, bevel_res=3 if high else 1, col=col))
        if high:
            for k in range(12):
                a = k / 12 * math.tau
                obs.append(K.sphere("Net Hook", 0.012, at=at(-0.55 + math.cos(a) * 0.24, 2.98, math.sin(a) * 0.24),
                                    m=rim, seg=6, col=col))
        obs += net(col, high)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ tennis net
# The tennis court's net (court(), not the basketball one): 11 m long along z, from 0.1 to 1.1 m up, on two posts at
# z +-5.5, 1.2 m tall. The game's net was a see-through white box; this one is a dark mesh with a white tape on top.
def tennis_net():
    post = mottled("Net Post", (0.2, 0.42, 0.3), (0.15, 0.33, 0.24), scale=9.0, rough=0.45, metal=0.5)
    mesh = K.mat("Net Mesh", (0.12, 0.13, 0.16), rough=0.85)
    cord = K.mat("Net Cord", (0.38, 0.4, 0.45), rough=0.8)
    tape = K.mat("Net Tape", (0.97, 0.97, 0.95), rough=0.7, bump=0.1)
    brass = K.mat("Net Brass", (0.85, 0.65, 0.3), rough=0.35, metal=0.8)
    L = 5.5

    def build(col, high):
        obs = []
        for s in (-1, 1):
            if high:
                obs.append(K.cyl("Post", 0.055, 1.2, at=at(0, 0.6, s * L), seg=20, m=post, col=col))
                obs.append(K.cyl("Post Foot", 0.08, 0.06, at=at(0, 0.03, s * L), seg=20, m=post, col=col))
                obs.append(K.sphere("Post Cap", 0.07, at=at(0, 1.22, s * L), m=post, seg=16, col=col,
                                    scale=(1, 1, 0.6)))
                for y in (0.2, 1.0):
                    obs.append(K.cyl("Post Ring", 0.065, 0.03, at=at(0, y, s * L), seg=20, m=brass, col=col))
            else:
                obs.append(K.cyl("Post", 0.06, 1.25, at=at(0, 0.625, s * L), seg=8, m=post, col=col))
        if high:
            # the winder on one post
            obs.append(gbox("Winder", (0.1, 0.14, 0.08), (0.08, 0.85, L), brass, col, bevel=0.01))
            obs.append(grod("Winder Arm", (0.13, 0.85, L), (0.2, 0.75, L), 0.012, brass, col, seg=8))
            obs.append(K.sphere("Winder Knob", 0.025, at=at(0.2, 0.73, L), m=post, seg=10, col=col))
        # the mesh: a dark panel with a grid of cords standing out on each face
        top, bot = 1.02, 0.12
        obs.append(gbox("Mesh", (0.02, top - bot, 2 * L - 0.12), (0, (top + bot) / 2, 0), mesh, col))
        if high:
            for sx in (-1, 1):
                k = 0
                z = -L + 0.1
                while z < L - 0.05:
                    obs.append(gbox("Cord", (0.006, top - bot, 0.008), (sx * 0.012, (top + bot) / 2, z), cord, col))
                    z += 0.09
                y = bot + 0.05
                while y < top:
                    obs.append(gbox("Cord", (0.006, 0.008, 2 * L - 0.12), (sx * 0.012, y, 0), cord, col))
                    y += 0.09
            obs.append(gbox("Bottom Cord", (0.03, 0.02, 2 * L - 0.1), (0, bot, 0), mesh, col, bevel=0.005))
        # the white tape over the top, the cable through it and the centre strap
        obs.append(gbox("Tape", (0.05, 0.08, 2 * L - 0.1), (0, 1.06, 0), tape, col, bevel=0.01 if high else 0))
        obs.append(gbox("Strap", (0.04, 1.0, 0.05), (0, 0.55, 0), tape, col))
        if high:
            obs.append(grod("Cable", (0, 1.07, -L), (0, 1.07, L), 0.012, brass, col, seg=8))
            obs.append(gbox("Strap Anchor", (0.1, 0.03, 0.1), (0, 0.02, 0), brass, col, bevel=0.008))
            for z in (-L + 0.3, L - 0.3):
                obs.append(gbox("Side Stick", (0.03, 0.9, 0.03), (0, 0.57, z), tape, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ soccer goal
# One goal of the soccer court (_soccer_field()): the goal line at the origin, the net out towards +X. Posts at
# z +-3 from the turf (0.2) to the crossbar at 2.4, the net 1.2 deep (the game turns the other one round).
def soccer_goal():
    white = K.mat("Goal White", (1.0, 1.0, 1.0), rough=0.35, bump=0.05)
    frame = K.mat("Goal Frame", (0.85, 0.86, 0.9), rough=0.4, metal=0.5)
    cord = K.mat("Goal Net", (0.95, 0.95, 1.0), rough=0.8)
    peg = K.mat("Goal Peg", (1.0, 0.82, 0.3), rough=0.4, metal=0.6)
    Y0, Y1, Z, D = 0.22, 2.4, 3.0, 1.2

    def net(col, high):
        obs = []
        seg = 5 if high else 3
        r = 0.011 if high else 0.014
        step = 0.25
        zs = [-Z + 0.1 + i * step for i in range(int((2 * Z - 0.2) / step) + 1)]
        # the back hangs from a bar 0.2 under the crossbar's height, at D
        ys = [Y0 + 0.05 + i * step for i in range(int((Y1 - 0.25 - Y0) / step) + 1)]
        for z in zs:
            obs.append(grod("Net Back", (D, Y0 + 0.02, z), (D, Y1 - 0.2, z), r, cord, col, seg=seg))
            obs.append(grod("Net Roof", (0.08, Y1, z), (D, Y1 - 0.2, z), r, cord, col, seg=seg))
        for y in ys:
            obs.append(grod("Net Back", (D, y, -Z), (D, y, Z), r, cord, col, seg=seg))
        for x in [0.08 + i * step for i in range(int((D - 0.08) / step) + 1)]:
            yy = Y1 - 0.2 * (x / D)
            obs.append(grod("Net Roof", (x, yy, -Z), (x, yy, Z), r, cord, col, seg=seg))
            for s in (-1, 1):
                obs.append(grod("Net Side", (x, Y0 + 0.02, s * Z), (x, yy, s * Z), r, cord, col, seg=seg))
        for s in (-1, 1):
            for y in ys:
                obs.append(grod("Net Side", (0.08, y, s * Z), (D, y, s * Z), r, cord, col, seg=seg))
        return obs

    def build(col, high):
        obs = []
        seg = 16 if high else 8
        for s in (-1, 1):
            obs.append(K.cyl("Post", 0.1, Y1 - Y0 + 0.1, at=at(0, (Y0 + Y1) / 2 + 0.05, s * Z), seg=seg, m=white,
                             col=col))
            # the frame behind: a bar along the ground and a stay up to the back bar
            obs.append(grod("Ground Bar", (0, Y0 + 0.03, s * Z), (D, Y0 + 0.03, s * Z), 0.035, frame, col,
                            seg=seg // 2))
            obs.append(grod("Stay", (0.05, Y1 - 0.05, s * Z), (D, Y1 - 0.2, s * Z), 0.035, frame, col,
                            seg=seg // 2))
            obs.append(grod("Back Leg", (D, Y0 + 0.03, s * Z), (D, Y1 - 0.2, s * Z), 0.035, frame, col,
                            seg=seg // 2))
            if high:
                obs.append(K.sphere("Joint", 0.11, at=at(0, Y1, s * Z), m=white, seg=16, col=col))
                for x in (0.4, 0.8):
                    obs.append(K.cyl("Peg", 0.02, 0.1, at=at(x, Y0 + 0.02, s * (Z + 0.06)), seg=6, m=peg, col=col))
        obs.append(grod("Crossbar", (0, Y1, -Z - 0.1), (0, Y1, Z + 0.1), 0.1, white, col, seg=seg))
        obs.append(grod("Back Bar", (D, Y0 + 0.03, -Z), (D, Y0 + 0.03, Z), 0.035, frame, col, seg=seg // 2))
        obs.append(grod("Top Back Bar", (D, Y1 - 0.2, -Z), (D, Y1 - 0.2, Z), 0.035, frame, col, seg=seg // 2))
        if high:
            for s in (-1, 1):
                for k in range(3):                       # painted stripes on the posts
                    obs.append(K.cyl("Post Band", 0.103, 0.12, at=at(0, 0.6 + k * 0.6, s * Z), seg=16, m=frame,
                                     col=col))
        obs += net(col, high)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ rock wall
# The park's climbing wall (_rock_wall()): the wall 9 x 10 x 1.6 round (0, 4.5, 0), its face at z 0.8; seven big
# ledges you can stand on (their boxes are the game's collisions, so each jug's top stays at the box's top); the flat
# top 9.4 x 0.4 x 2.4 at y 9.7; the crash mat 10 x 0.4 x 5 at (0, 0.1, 3.2).
HOLD_COLS = [(1.0, 0.3, 0.4), (0.2, 0.8, 1.0), (1.0, 0.85, 0.2), (0.5, 1.0, 0.4), (0.8, 0.4, 1.0)]


def ledge_at(k):
    return (-3.0 + (k % 2) * 3.0 + (1.5 if k % 4 >= 2 else 0.0), 1.1 + k * 1.3, 1.25)


def rock_wall():
    import random
    rng = random.Random(11)
    ply = K.mat("Wall Panel", (0.55, 0.5, 0.6), rough=0.85, grain=(3.0, 0.08), bump=0.35)
    frame = K.mat("Wall Frame", (0.42, 0.36, 0.48), rough=0.7, grain=(8.0, 0.2), bump=0.1)
    tnut = K.mat("T-Nut", (0.2, 0.18, 0.24), rough=0.5, metal=0.6)
    deck = K.mat("Wall Deck", (0.6, 0.48, 0.38), rough=0.7, grain=(10.0, 0.3), bump=0.1)
    matc = K.mat("Crash Mat", (0.25, 0.45, 0.95), rough=0.85, bump=0.3)
    strap = K.mat("Mat Strap", (0.15, 0.2, 0.4), rough=0.7)
    holds = [K.mat("Hold %d" % i, c, rough=0.75, bump=0.6) for i, c in enumerate(HOLD_COLS)]
    small = [(rng.uniform(-4.1, 4.1), rng.uniform(0.5, 9.1), rng.random(), rng.randrange(5), rng.random())
             for _ in range(55)]

    def build(col, high):
        obs = []
        b = 0.02 if high else 0
        obs.append(gbox("Wall", (9.0, 10.0, 1.6), (0, 4.5, 0), ply, col))
        if high:
            # panels: grooves between 1.5 m sheets, and a grid of bolt holes on each
            for k in range(1, 6):
                obs.append(gbox("Panel Groove", (0.02, 9.9, 0.03), (-4.5 + k * 1.5, 4.5, 0.795), frame, col))
            for k in range(1, 7):
                obs.append(gbox("Panel Groove", (8.95, 0.02, 0.03), (0, -0.5 + k * 1.4, 0.795), frame, col))
            for i in range(14):
                for j in range(15):
                    x, y = -4.2 + i * 0.65, 0.1 + j * 0.62
                    obs.append(K.cyl("T-Nut", 0.018, 0.012, at=at(x, y, 0.803), rot=(math.pi / 2, 0, 0), seg=6,
                                     m=tnut, col=col))
            # a painted frame round the edges and studs up the back
            for s in (-1, 1):
                obs.append(gbox("Side Trim", (0.16, 10.1, 1.7), (s * 4.45, 4.5, 0), frame, col, bevel=0.02))
            for k in range(7):
                obs.append(gbox("Back Stud", (0.12, 9.6, 0.1), (-3.9 + k * 1.3, 4.6, -0.82), frame, col))
            for k in range(4):
                obs.append(gbox("Back Rail", (8.8, 0.12, 0.1), (0, 1.0 + k * 2.6, -0.84), frame, col))
            for (x, y, r, c, sd) in small:
                rr = 0.11 + 0.1 * r
                obs.append(blob("Hold", rr, (x, y, 0.8 + rr * 0.35), holds[c], col, seed=int(sd * 97), seg=12,
                                lump=0.3, squash=(1.0, 0.85, 0.55)))
                obs.append(K.cyl("Hold Bolt", 0.02, 0.01, at=at(x, y, 0.8 + rr * 0.7), rot=(math.pi / 2, 0, 0),
                                 seg=6, m=tnut, col=col))
        else:
            for (x, y, r, c, sd) in small:
                rr = 0.11 + 0.1 * r
                obs.append(blob("Hold", rr, (x, y, 0.8 + rr * 0.35), holds[c], col, seed=int(sd * 97), seg=5,
                                lump=0.3, squash=(1.0, 0.85, 0.55)))
        # the seven big ledges: chunky jugs on the box the game stands you on
        for k in range(7):
            p = ledge_at(k)
            m = holds[k % 5]
            obs.append(gbox("Ledge", (1.6, 0.35, 0.9), p, m, col, bevel=0.06 if high else 0))
            if high:
                for i in range(3):
                    obs.append(blob("Ledge Lump", 0.22, (p[0] - 0.5 + i * 0.5, p[1] - 0.12, p[2] + 0.2), m, col,
                                    seed=k * 7 + i, seg=12, lump=0.35, squash=(1.3, 0.7, 0.9)))
                obs.append(K.cyl("Ledge Bolt", 0.03, 0.02, at=at(p[0], p[1] + 0.176, p[2]), seg=8, m=tnut, col=col))
        # the deck on top and the crash mat
        obs.append(gbox("Top", (9.4, 0.4, 2.4), (0, 9.7, 0), deck, col, bevel=b))
        if high:
            for k in range(12):
                obs.append(gbox("Top Plank", (9.3, 0.02, 0.18), (0, 9.905, -1.1 + k * 0.2), deck, col, bevel=0.005))
            for s in (-1, 1):
                obs.append(gbox("Top Kerb", (9.4, 0.12, 0.08), (0, 9.96, s * 1.16), frame, col, bevel=0.015))
        obs.append(gbox("Mat", (10.0, 0.4, 5.0), (0, 0.1, 3.2), matc, col, bevel=0.08 if high else 0))
        if high:
            for k in range(1, 5):
                obs.append(gbox("Mat Seam", (0.04, 0.03, 4.9), (-5.0 + k * 2.0, 0.305, 3.2), strap, col, bevel=0.01))
            obs.append(gbox("Mat Seam", (9.9, 0.03, 0.04), (0, 0.305, 3.2), strap, col, bevel=0.01))
            for x in (-3.0, 3.0):
                obs.append(K.wire("Mat Handle", [at(x - 0.2, 0.25, 5.71), at(x, 0.32, 5.78), at(x + 0.2, 0.25, 5.71)],
                                  0.02, m=strap, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the old slide
# The old water slide by the Haunted House (_old_slide()), boarded up: two posts 7 m tall at x +-0.7 with ten rungs,
# the 13 m chute (1.6 wide) round (0, 3.6, 6.2) tipped 0.55 rad down towards +z, and four planks nailed across the
# ladder's front at z -0.15. The CLOSED sign is the game's.
def old_slide():
    wood = K.mat("Old Slide Wood", (0.36, 0.28, 0.22), rough=0.95, grain=(9.0, 0.35), bump=0.3, wear=0.0)
    plank = K.mat("Haunted Plank", (0.32, 0.22, 0.16), rough=0.95, grain=(9.0, 0.35), bump=0.3)
    paint = mottled("Old Slide Paint", (0.35, 0.58, 0.6), (0.36, 0.28, 0.22), scale=5.0, rough=0.8)
    rust = mottled("Old Slide Rust", (0.45, 0.3, 0.22), (0.25, 0.2, 0.18), scale=14.0, rough=0.7, metal=0.4)
    moss = K.mat("Old Slide Moss", (0.3, 0.42, 0.25), rough=0.95, bump=0.5)
    T = 0.55
    C = (0.0, 3.6, 6.2)

    def ch(x, y, z):
        """A point in the chute's own frame (z along it, y up from its middle) in the slide's frame."""
        return (C[0] + x, C[1] + y * math.cos(T) - z * math.sin(T), C[2] + y * math.sin(T) + z * math.cos(T))

    def cbox(name, size, pos, m, col, bevel=0.0):
        return gbox(name, size, ch(*pos), m, col, bevel=bevel, rot=(T, 0, 0))

    def build(col, high):
        obs = []
        b = 0.015 if high else 0
        for x in (-0.7, 0.7):
            obs.append(gbox("Post", (0.2, 7.0, 0.2), (x, 3.5, 0), wood, col, bevel=b))
            if high:
                for k in range(4):
                    obs.append(gbox("Crack", (0.005, 0.6, 0.03), (x + 0.1, 0.8 + k * 1.6, 0.03 * (k % 2)), plank,
                                    col))
                obs.append(blob("Moss", 0.16, (x, 0.08, 0.0), moss, col, seed=int(x * 10 + 30), seg=10, lump=0.4,
                                squash=(1.2, 0.45, 1.2)))
        for k in range(10):
            y = 0.6 + k * 0.65
            obs.append(gbox("Rung", (1.5, 0.1, 0.12), (0, y, 0), wood, col, bevel=b / 2))
            if high:
                for x in (-0.65, 0.65):
                    obs.append(K.cyl("Nail", 0.012, 0.02, at=at(x, y, 0.065), rot=(math.pi / 2, 0, 0), seg=6,
                                     m=rust, col=col))
        if high:
            # cross braces behind the ladder
            obs.append(grod("Brace", (-0.62, 0.4, 0.14), (0.62, 3.2, 0.14), 0.04, wood, col, seg=6))
            obs.append(grod("Brace", (0.62, 0.4, 0.14), (-0.62, 3.2, 0.14), 0.04, wood, col, seg=6))
        # the chute: a trough of planks, once painted teal, its paint peeling
        obs.append(cbox("Chute", (1.6, 0.2, 13.0), (0, 0, 0), paint, col, bevel=b))
        for s in (-1, 1):
            obs.append(cbox("Chute Side", (0.1, 0.32, 13.0), (s * 0.75, 0.24, 0), wood, col, bevel=b))
        if high:
            for k in range(13):
                obs.append(cbox("Chute Seam", (1.5, 0.006, 0.02), (0, 0.101, -6.0 + k * 1.0), plank, col))
            for k in range(7):
                for s in (-1, 1):
                    obs.append(cbox("Chute Bolt", (0.04, 0.04, 0.04), (s * 0.81, 0.24, -6.0 + k * 2.0), rust, col))
            obs.append(cbox("Chute Lip", (1.6, 0.06, 0.2), (0, 0.1, 6.4), rust, col, bevel=0.01))
        # the planks nailed across the front, as the game tilts them
        for k in range(4):
            r = 0.2 * (k % 2 * 2 - 1)
            obs.append(gbox("Board", (2.2, 0.25, 0.08), (0, 1.0 + k * 0.6, -0.15), plank, col, bevel=b / 2,
                            rot=(0, 0, r)))
            if high:
                for x in (-0.7, 0.7):
                    y = 1.0 + k * 0.6 + math.sin(r) * x
                    obs.append(K.cyl("Nail", 0.015, 0.03, at=at(x * math.cos(r), y, -0.195),
                                     rot=(math.pi / 2, 0, 0), seg=6, m=rust, col=col))
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


fn, size, ext, ray, ao = {
    "basketball_hoop": (basketball_hoop, 1024, 0.03, 0.08, True),
    "tennis_net": (tennis_net, 1024, 0.03, 0.06, True),
    "soccer_goal": (soccer_goal, 1024, 0.03, 0.06, False),
    "rock_wall": (rock_wall, 2048, 0.15, 0.35, True),
    "old_slide": (old_slide, 1024, 0.05, 0.12, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

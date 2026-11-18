# More of the Void's scenery, built the detailed way (tools/bake_kit.py; 18 Nov 2026, Hayden: "More scenery"): the
# Goblin Clockyard's grandfather clocks and cogs, Boulder Hollow's boulders, the ammo crates, and Dash's gadget stall
# and workbench. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces the game builds from shapes (scripts/bosses.gd, scripts/ammo_crate.gd,
# scripts/gadget_stall.gd), so the swap (scripts/detail_props.gd) puts each exactly where the old one was. Blender's
# X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   clock_case     a grandfather clock's trunk, 0.8 x 0.55 m, made CASE_H tall from the ground up: the game stretches
#                  it to each clock (each is h - 0.8 tall below its hood). A plinth with bun feet, pilasters, and a
#                  waist door with a glass window and the brass pendulum behind it.
#   clock_hood     the hood on top, from its foot (h - 0.8 up the clock) to the bonnet: a brass dial plate with a
#                  glowing face and its hour marks (the game's own hand turns over it, so its front stays under
#                  z 0.31), turned columns, a bonnet where the builder's top box was, scrolls and three finials.
#   cog            one cog in the grass: radius 1 and 0.12 thick (the game scales it to each cog's radius). Teeth,
#                  a rim, five spokes, a hub with an axle hole, aged brass.
#   boulder        one of Boulder Hollow's boulders: radius 1 (the game scales it to each one's radius), lumpy and
#                  banded, with moss on its top where the builder's moss cap was.
#   ammo_crate     the crate under the bubble wrap (the game keeps its see-through wrap and spinning star): a lilac
#                  planked crate 0.96 m across with gold corner posts, brackets, rope handles and a star on two sides.
#   gadget_stall   Dash's stall: a panelled counter, a lilac top with a gold edge, turned posts, a striped awning
#                  with a scalloped edge, and the sign board (its words are the game's own label, in front of it).
#   workbench      his workbench beside it: a bench with drawers and a shelf, a lilac top, a pegboard with holes,
#                  four gold tools, a teal vice and a lilac awning.
# Colours are the game's own (sRGB). Collisions stay the game's.
#
#   python tools/build_prop_void_more.py "<out>.glb" <kind> [--preview]

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["clock_case", "clock_hood", "cog", "boulder", "ammo_crate", "gadget_stall", "workbench"]
KIND = next((a for a in sys.argv if a in KINDS), "cog")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

CASE_H = 1.9        # the clock trunk's height as made (scripts/detail_props.gd CLOCK_CASE_H)
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


# ================================================================ the grandfather clock
def clock_mats():
    wood = K.mat("Clock Wood", WOOD, rough=0.5, grain=(7.0, 0.35), bump=0.12)
    dark = K.mat("Clock Wood Dark", tuple(c * 0.7 for c in WOOD), rough=0.55, grain=(9.0, 0.3), bump=0.1)
    brass = mottled("Clock Brass", BRASS, (0.62, 0.43, 0.18), scale=9.0, rough=0.35, metal=0.85)
    glass = K.mat("Clock Glass", (0.12, 0.08, 0.2), rough=0.05, metal=0.3)
    face = K.mat("Clock Face", FACE, rough=0.4, emit=0.6)
    ink = K.mat("Clock Ink", INK, rough=0.5)
    return wood, dark, brass, glass, face, ink


def clock_case():
    wood, dark, brass, glass, face, ink = clock_mats()

    def build(col, high):
        obs = []
        b = 0.02 if high else 0
        # plinth and feet
        obs.append(gbox("Plinth", (0.9, 0.22, 0.63), (0, 0.13, 0), wood, col, bevel=b))
        obs.append(gbox("Plinth Step", (0.84, 0.06, 0.59), (0, 0.27, 0), dark, col, bevel=b / 2))
        # the trunk
        obs.append(gbox("Trunk", (0.76, CASE_H - 0.36, 0.5), (0, 0.3 + (CASE_H - 0.36) / 2, 0), wood, col, bevel=b))
        obs.append(gbox("Waist Moulding", (0.84, 0.07, 0.58), (0, CASE_H - 0.035, 0), dark, col, bevel=b / 2))
        # the waist door, its window and the pendulum behind it
        door_y = 0.35 + (CASE_H - 0.5) / 2
        door_h = CASE_H - 0.6
        obs.append(gbox("Waist Door", (0.5, door_h, 0.03), (0, door_y, 0.26), dark, col, bevel=b / 2))
        win_h = door_h - 0.36
        obs.append(gbox("Window", (0.32, win_h, 0.01), (0, door_y + 0.05, 0.278), glass, col))
        if high:
            # the pendulum: a rod and a big round bob, gold behind the glass
            top = door_y + 0.05 + win_h / 2 - 0.04
            obs.append(gbox("Pendulum Rod", (0.03, win_h * 0.6, 0.008), (0, top - win_h * 0.3, 0.282), brass, col))
            bob = K.cyl("Pendulum Bob", 0.11, 0.014, at=at(0, top - win_h * 0.6 - 0.06, 0.284), seg=32, m=brass,
                        col=col, rot=(math.pi / 2, 0, 0))
            obs.append(bevel(bob, 0.004))
            # a keyhole and a little lock plate
            obs.append(gbox("Lock Plate", (0.05, 0.08, 0.006), (0.2, door_y, 0.278), brass, col, bevel=0.003))
            # pilasters down the trunk's front corners, with capitals and bases
            for s in (-1, 1):
                obs.append(gbox("Pilaster", (0.05, CASE_H - 0.5, 0.03), (s * 0.34, 0.3 + (CASE_H - 0.5) / 2 + 0.07,
                                                                         0.26), dark, col, bevel=0.008))
                for yy in (0.37, CASE_H - 0.12):
                    obs.append(gbox("Pilaster Cap", (0.08, 0.04, 0.045), (s * 0.34, yy, 0.262), brass, col,
                                    bevel=0.005))
            # bun feet
            for sx in (-1, 1):
                for sz in (-1, 1):
                    obs.append(K.sphere("Foot", 0.07, at=at(sx * 0.36, 0.03, sz * 0.24), m=dark, seg=16, col=col,
                                        scale=(1, 1, 0.6)))
            # carved fans on the plinth
            for s in (-1, 1):
                obs.append(K.cyl("Plinth Fan", 0.08, 0.012, at=at(s * 0.25, 0.14, 0.316), seg=24, m=brass,
                                 col=col, rot=(math.pi / 2, 0, 0)))
        return obs

    return build(HIGH, True), build(LOW, False)


def clock_hood():
    wood, dark, brass, glass, face, ink = clock_mats()

    def build(col, high):
        obs = []
        b = 0.02 if high else 0
        obs.append(gbox("Hood", (0.84, 0.8, 0.58), (0, 0.4, 0), wood, col, bevel=b))
        # the dial: a square brass plate, the glowing face in the middle and its marks (all under z 0.31)
        obs.append(gbox("Dial Plate", (0.66, 0.66, 0.012), (0, 0.4, 0.296), brass, col, bevel=b / 4))
        obs.append(K.cyl("Face", 0.3, 0.008, at=at(0, 0.4, 0.302), seg=48 if high else 16, m=face, col=col,
                         rot=(math.pi / 2, 0, 0)))
        if high:
            # (a closed curve, not a lathe: a lathe's caps would fill the ring in over the face)
            ring = [(math.cos(i / 48 * math.tau) * 0.31, -0.304, 0.4 + math.sin(i / 48 * math.tau) * 0.31)
                    for i in range(48)]
            obs.append(K.wire("Bezel", ring, 0.012, brass, closed=True, res=4, bevel_res=3, col=col))
            for k in range(60):
                a = k / 60 * math.tau
                big = k % 5 == 0
                r = 0.255 if big else 0.27
                ln = 0.045 if big else 0.016
                w = 0.012 if big else 0.005
                p = (math.sin(a) * r, 0.4 + math.cos(a) * r, 0.3075)
                obs.append(gbox("Mark", (w, ln, 0.002), p, ink, col, rot=(0, 0, -a)))
            # a ring of little stars between the marks and the middle
            for k in range(12):
                a = (k + 0.5) / 12 * math.tau
                pts = star_outline(0.012, 0.005, cx=math.sin(a) * 0.19, cy=0.4 + math.cos(a) * 0.19)
                obs.append(prism("Dial Star", [(x, z) for x, z in pts], -0.3075, -0.3065, brass, col))
            # the moon dial over the face: a half disc
            arch = [(math.cos(i / 16 * math.pi) * 0.17, 0.705 + math.sin(i / 16 * math.pi) * 0.08) for i in range(17)]
            obs.append(prism("Moon Dial", arch, -0.307, -0.303, glass, col))
            # spandrels in the plate's corners
            for sx in (-1, 1):
                for sy in (-1, 1):
                    c = (sx * 0.27, 0.4 + sy * 0.27)
                    tri = [(c[0], c[1]), (c[0] - sx * 0.07, c[1]), (c[0], c[1] - sy * 0.07)]
                    obs.append(prism("Spandrel", tri, -0.306, -0.302, brass, col))
            # turned columns either side of the dial
            for s in (-1, 1):
                col_ = K.lathe("Column", [(0.0, 0.0), (0.04, 0.0), (0.04, 0.05), (0.028, 0.08), (0.025, 0.4),
                                          (0.028, 0.72), (0.04, 0.75), (0.04, 0.8), (0.0, 0.8)], seg=16, m=dark,
                               col=col)
                col_.location = at(s * 0.385, 0.0, 0.27)
                obs.append(col_)
        # the bonnet where the builder's top box was, and its broken arch with finials
        obs.append(gbox("Bonnet", (0.95, 0.25, 0.65), (0, 0.9, 0), wood, col, bevel=b))
        obs.append(gbox("Cornice", (0.99, 0.05, 0.69), (0, 0.79, 0), dark, col, bevel=b / 2))
        if high:
            for s in (-1, 1):
                pts = [(s * (0.12 + 0.3 * t), 0.0, 1.025 + 0.18 * math.sin(t * math.pi * 0.9)) for t in
                       [i / 10 for i in range(11)]]
                pts = [(x, -0.3, z) for x, _, z in pts]
                obs.append(K.wire("Arch Scroll", pts, 0.03, dark, res=6, bevel_res=2, col=col))
                obs.append(K.wire("Arch Curl", K.scroll(s * 0.13, 1.08, 0.05, 1.2, y=-0.3, flip=-s), 0.012,
                                  brass, res=4, bevel_res=2, col=col))
            for x in (-0.42, 0.0, 0.42):
                fin = K.lathe("Finial", [(0.0, 0.0), (0.04, 0.0), (0.02, 0.05), (0.045, 0.1), (0.03, 0.15),
                                         (0.0, 0.2)], seg=16, m=brass, col=col)
                fin.location = at(x, 1.025, 0.0)
                obs.append(fin)
            # side windows of the hood
            for s in (-1, 1):
                obs.append(gbox("Side Glass", (0.01, 0.4, 0.3), (s * 0.422, 0.4, 0.05), glass, col))
        else:
            for x in (-0.42, 0.0, 0.42):
                obs.append(K.cyl("Finial", 0.035, 0.18, at=at(x, 1.115, 0.0), seg=6, m=brass, col=col))
            for s in (-1, 1):
                obs.append(gbox("Column", (0.07, 0.8, 0.07), (s * 0.385, 0.4, 0.27), dark, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the cog
def cog():
    brass = mottled("Cog Brass", BRASS, (0.5, 0.36, 0.16), scale=4.0, rough=0.4, metal=0.85, bump=0.2)
    green = K.mat("Cog Verdigris", (0.36, 0.62, 0.52), rough=0.8, bump=0.3)
    TEETH = 16
    H = 0.12

    def outline(n_seg):
        pts = []
        for k in range(TEETH):
            a0 = k / TEETH * math.tau
            step = math.tau / TEETH
            for f, r in ((0.0, 0.84), (0.18, 0.84), (0.3, 1.0), (0.7, 1.0), (0.82, 0.84)):
                a = a0 + f * step
                pts.append((math.cos(a) * r, math.sin(a) * r))
        return pts

    def build(col, high):
        obs = []
        if high:
            obs.append(bevel(flat_disc_prism("Teeth", outline(0), -H / 2, H / 2, brass, col), 0.012))
            # a sunken web between the rim and the hub, with five spokes standing proud of it
            web = K.lathe("Web", [(0.18, -0.03), (0.66, -0.03), (0.66, 0.03), (0.18, 0.03)], seg=48, m=brass,
                          col=col)
            obs.append(web)
            for k in range(5):
                a = k / 5 * math.tau
                obs.append(bevel(K.box("Spoke", (0.5, 0.11, H), at=(math.cos(a) * 0.42, math.sin(a) * 0.42, 0),
                                       rot=(0, 0, a), m=brass, col=col), 0.015))
            obs.append(bevel(K.cyl("Hub", 0.2, H + 0.02, seg=32, m=brass, col=col), 0.01))
            obs.append(K.cyl("Axle Hole", 0.07, H + 0.025, seg=24, m=K.mat("Cog Hole", INK, rough=0.9), col=col))
            # patches of green where it's lain in the grass
            for k in range(6):
                a = k * 1.9
                obs.append(K.sphere("Verdigris", 0.06, at=(math.cos(a) * 0.75, math.sin(a) * 0.75, H / 2 - 0.02),
                                    m=green, seg=8, col=col, scale=(1.4, 1.0, 0.35)))
        else:
            obs.append(flat_disc_prism("Teeth", outline(0), -H / 2, H / 2, brass, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the boulder
def _rock_shape(p, high):
    """How far out the boulder's surface is in the direction p (a unit vector): big lumps, and in the high version
    cracks and chips on top of them."""
    big = noise.fractal(p * 1.3 + Vector((3.1, 7.2, 1.4)), 0.5, 2.0, 3) * 0.16
    r = 1.0 + big
    if high:
        r += noise.fractal(p * 5.0 + Vector((9.0, 2.0, 5.0)), 0.55, 2.1, 4) * 0.035
        # a few sharp ledges (strata)
        r -= abs(math.sin(p.z * 9.0 + noise.noise(p * 2.0) * 1.5)) * 0.015
    return r


def boulder():
    rock = K.mat("Boulder Rock", ROCK, rough=0.85, pits=0.2)
    nt, b, co = _nodes(rock)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    # bands of paler and darker stone, wobbling
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 2.5
    wave.inputs["Distortion"].default_value = 4.0
    wave.inputs["Detail"].default_value = 3.0
    nt.links.new(co, wave.inputs["Vector"])
    speck = nt.nodes.new("ShaderNodeTexNoise")
    speck.inputs["Scale"].default_value = 40.0
    speck.inputs["Detail"].default_value = 4.0
    nt.links.new(co, speck.inputs["Vector"])
    bands = _mix_rgb(nt, wave.outputs["Fac"], (0.42, 0.36, 0.48), (0.6, 0.54, 0.64))
    sp_r = nt.nodes.new("ShaderNodeMapRange")
    sp_r.inputs["From Min"].default_value = 0.6
    sp_r.inputs["From Max"].default_value = 0.66
    nt.links.new(speck.outputs["Fac"], sp_r.inputs["Value"])
    speck_mix = nt.nodes.new("ShaderNodeMix")
    speck_mix.data_type = "RGBA"
    nt.links.new(sp_r.outputs["Result"], speck_mix.inputs["Factor"])
    nt.links.new(bands, K._rgba(speck_mix.inputs, "A"))
    K._rgba(speck_mix.inputs, "B").default_value = (*(K.srgb_to_linear(c) for c in (0.82, 0.86, 0.6)), 1)
    # moss over the top: where the surface faces up, with a ragged noisy edge
    edge = nt.nodes.new("ShaderNodeTexNoise")
    edge.inputs["Scale"].default_value = 6.0
    edge.inputs["Detail"].default_value = 8.0
    nt.links.new(co, edge.inputs["Vector"])
    up = nt.nodes.new("ShaderNodeMath")
    up.operation = "MULTIPLY_ADD"
    nt.links.new(edge.outputs["Fac"], up.inputs[0])
    up.inputs[1].default_value = 0.5
    nt.links.new(sep.outputs["Z"], up.inputs[2])
    moss_r = nt.nodes.new("ShaderNodeMapRange")
    moss_r.inputs["From Min"].default_value = 0.85
    moss_r.inputs["From Max"].default_value = 0.95
    nt.links.new(up.outputs[0], moss_r.inputs["Value"])
    moss_col = _mix_rgb(nt, speck.outputs["Fac"], (0.22, 0.48, 0.28), (0.42, 0.72, 0.4))
    final = nt.nodes.new("ShaderNodeMix")
    final.data_type = "RGBA"
    nt.links.new(moss_r.outputs["Result"], final.inputs["Factor"])
    nt.links.new(K._rgba(speck_mix.outputs, "Result"), K._rgba(final.inputs, "A"))
    nt.links.new(moss_col, K._rgba(final.inputs, "B"))
    nt.links.new(K._rgba(final.outputs, "Result"), b.inputs["Base Color"])
    # rough bump over everything, and a fluffier one where the moss is
    bump_n = nt.nodes.new("ShaderNodeTexNoise")
    bump_n.inputs["Scale"].default_value = 30.0
    bump_n.inputs["Detail"].default_value = 10.0
    nt.links.new(co, bump_n.inputs["Vector"])
    bmp = nt.nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = 0.6
    bmp.inputs["Distance"].default_value = 0.01
    nt.links.new(bump_n.outputs["Fac"], bmp.inputs["Height"])
    nt.links.new(bmp.outputs["Normal"], b.inputs["Normal"])

    def build(col, high):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=5 if high else 3, radius=1.0)
        for v in bm.verts:
            p = v.co.normalized()
            r = _rock_shape(p, high)
            v.co = Vector((p.x * r, p.y * r, p.z * r * 0.8))
            # flat underneath, where it sits in the ground
            if v.co.z < -0.72:
                v.co.z = -0.72 + (v.co.z + 0.72) * 0.15
        return [K._obj("Boulder", bm, rock, smooth=True, col=col)]

    return build(HIGH, True), build(LOW, False)


# ================================================================ the ammo crate
def ammo_crate():
    paint = mottled("Crate Paint", LILAC, (0.5, 0.4, 0.82), scale=3.0, rough=0.6, bump=0.15)
    plank = K.mat("Crate Plank", LILAC, rough=0.65, grain=(14.0, 0.25), bump=0.1)
    gold = mottled("Crate Gold", GOLD, (0.82, 0.6, 0.2), scale=8.0, rough=0.35, metal=0.5)
    rope = K.mat("Crate Rope", (0.86, 0.76, 0.56), rough=0.9, bump=0.5)
    stencil = K.mat("Crate Star", (1.0, 0.86, 0.4), rough=0.5)
    S = 0.96
    y0 = 0.5 - S / 2

    def build(col, high):
        obs = []
        if high:
            # planks on every side: four on each wall, running across, with gaps between them
            for face in range(4):
                for k in range(4):
                    yy = y0 + (k + 0.5) * S / 4
                    if face < 2:
                        s = 1 if face == 0 else -1
                        obs.append(gbox("Plank", (S - 0.02, S / 4 - 0.012, 0.03), (0, yy, s * (S / 2 - 0.015)), plank,
                                        col, bevel=0.006))
                    else:
                        s = 1 if face == 2 else -1
                        obs.append(gbox("Plank", (0.03, S / 4 - 0.012, S - 0.02), (s * (S / 2 - 0.015), yy, 0), plank,
                                        col, bevel=0.006))
            for k in range(4):
                obs.append(gbox("Lid Plank", (S / 4 - 0.012, 0.03, S - 0.02), (-S / 2 + (k + 0.5) * S / 4,
                                                                              y0 + S - 0.015, 0), plank, col,
                                bevel=0.006))
            obs.append(gbox("Core", (S - 0.05, S - 0.05, S - 0.05), (0, 0.5, 0), paint, col))
            # battens round the middle of each wall, and gold brackets on the corners
            for s in (-1, 1):
                obs.append(gbox("Batten", (S - 0.12, 0.08, 0.025), (0, 0.5, s * (S / 2 + 0.008)), paint, col,
                                bevel=0.008))
                obs.append(gbox("Batten", (0.025, 0.08, S - 0.12), (s * (S / 2 + 0.008), 0.5, 0), paint, col,
                                bevel=0.008))
            for sx in (-1, 1):
                for sz in (-1, 1):
                    for yy in (y0 + 0.08, y0 + S - 0.08):
                        obs.append(gbox("Bracket", (0.16, 0.1, 0.012), (sx * 0.41, yy, sz * (S / 2 + 0.01)), gold, col,
                                        bevel=0.004))
                        obs.append(gbox("Bracket", (0.012, 0.1, 0.16), (sx * (S / 2 + 0.01), yy, sz * 0.41), gold, col,
                                        bevel=0.004))
                        for t in (-0.05, 0.05):
                            obs.append(K.sphere("Rivet", 0.012, at=at(sx * (0.41 + t), yy, sz * (S / 2 + 0.018)),
                                                m=gold, seg=8, col=col))
            # a big gold star painted on the front and back
            for s in (-1, 1):
                pts = star_outline(0.2, 0.085, cx=0.0, cy=0.5)
                obs.append(prism("Star", pts, -s * (S / 2 + 0.012), -s * (S / 2 + 0.017), stencil, col))
            # rope handles on the sides
            for s in (-1, 1):
                pts = [at(s * (S / 2 + 0.005), 0.66, -0.16)] + [
                    at(s * (S / 2 + 0.06 * math.sin(t * math.pi)), 0.66 - 0.06 * math.sin(t * math.pi),
                       -0.16 + 0.32 * t) for t in [i / 8 for i in range(1, 8)]] + [at(s * (S / 2 + 0.005), 0.66, 0.16)]
                obs.append(K.wire("Rope", pts, 0.018, rope, res=6, bevel_res=3, col=col))
                for zz in (-0.16, 0.16):
                    obs.append(gbox("Rope Plate", (0.012, 0.07, 0.07), (s * (S / 2 + 0.006), 0.66, zz), gold, col,
                                    bevel=0.004))
            # a gold hasp on the lid
            obs.append(gbox("Hasp", (0.08, 0.14, 0.012), (0, y0 + S - 0.06, S / 2 + 0.012), gold, col, bevel=0.004))
        else:
            obs.append(gbox("Crate", (S, S, S), (0, 0.5, 0), paint, col))
        # the corner posts, as the game had them
        for sx in (-1, 1):
            for sz in (-1, 1):
                obs.append(gbox("Post", (0.07, 1.0, 0.07), (sx * 0.47, 0.5, sz * 0.47), gold, col,
                                bevel=0.01 if high else 0))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ Dash's gadget stall
W = 3.0


def stall_mats():
    wood = K.mat("Stall Wood", STALL_WOOD, rough=0.6, grain=(8.0, 0.3), bump=0.1)
    top = mottled("Stall Top", LILAC, (0.55, 0.43, 0.88), scale=2.0, rough=0.4)
    gold = mottled("Stall Gold", GOLD, (0.82, 0.6, 0.2), scale=8.0, rough=0.3, metal=0.6)
    teal = K.mat("Awning Teal", TEAL, rough=0.8, bump=0.25)
    pink = K.mat("Awning Pink", PINK, rough=0.8, bump=0.25)
    board = K.mat("Stall Board", BOARD, rough=0.55, grain=(6.0, 0.2))
    return wood, top, gold, teal, pink, board


def gadget_stall():
    wood, top, gold, teal, pink, board = stall_mats()
    panel = K.mat("Stall Panel", tuple(c * 1.25 for c in STALL_WOOD), rough=0.6, grain=(8.0, 0.25))

    def build(col, high):
        obs = []
        b = 0.015 if high else 0
        obs.append(gbox("Counter", (W, 1.0, 0.8), (0, 0.5, 0), wood, col, bevel=b))
        obs.append(gbox("Counter Top", (W + 0.1, 0.08, 0.9), (0, 1.04, 0), top, col, bevel=b))
        obs.append(gbox("Gold Edge", (W + 0.12, 0.05, 0.05), (0, 1.0, 0.45), gold, col, bevel=b / 2))
        if high:
            # the front panels with frames and gold stars, and a kick plate
            for k in range(3):
                x = -W / 3 + k * W / 3
                obs.append(gbox("Panel", (W / 3 - 0.18, 0.62, 0.02), (x, 0.52, 0.405), panel, col, bevel=0.01))
                obs.append(prism("Panel Star", star_outline(0.1, 0.042, cx=x, cy=0.52), -0.416, -0.422, gold, col))
            for k in range(4):
                obs.append(gbox("Stile", (0.07, 0.8, 0.025), (-W / 2 + 0.04 + k * (W - 0.08) / 3, 0.5, 0.408), wood,
                                col, bevel=0.008))
            obs.append(gbox("Kick Plate", (W, 0.1, 0.03), (0, 0.05, 0.41), gold, col, bevel=0.006))
            obs.append(gbox("Rail", (W, 0.05, 0.025), (0, 0.88, 0.41), wood, col, bevel=0.008))
            # brass studs along the gold edge
            for k in range(15):
                obs.append(K.sphere("Stud", 0.013, at=at(-W / 2 + 0.1 + k * (W - 0.2) / 14, 1.0, 0.478), m=gold,
                                    seg=8, col=col))
        # posts: turned in the high one
        for side in (-1, 1):
            for z in (-0.35, 0.35):
                x = side * (W / 2 - 0.05)
                if high:
                    p = K.lathe("Post", [(0.0, 0.0), (0.06, 0.0), (0.06, 0.06), (0.045, 0.1), (0.04, 1.08),
                                         (0.055, 1.12), (0.04, 1.16), (0.04, 2.5), (0.055, 2.55), (0.055, 2.6),
                                         (0.0, 2.6)], seg=16, m=wood, col=col, flutes=8, flute_depth=0.01,
                                    flute_z=(1.2, 2.45))
                    p.location = at(x, 0, z)
                    obs.append(p)
                else:
                    obs.append(gbox("Post", (0.1, 2.6, 0.1), (x, 1.3, z), wood, col))
        # the striped awning: each stripe sags a little between the posts in the high one
        n = 8
        for i in range(n):
            x = -W / 2 + (i + 0.5) * W / n
            m = (teal, pink)[i % 2]
            if high:
                obs.append(gbox("Stripe", (W / n + 0.01, 0.04, 1.3), (x, 2.65, 0.15), m, col, bevel=0.012,
                                rot=(0.22, 0, 0)))
                # a seam between stripes
                obs.append(gbox("Seam", (0.012, 0.045, 1.3), (x + W / n / 2, 2.65, 0.15), wood, col,
                                rot=(0.22, 0, 0)))
                fl = K.cyl("Flap", W / n / 2, 0.025, at=at(x, 2.48, 0.8), seg=24, m=m, col=col, rot=(math.pi / 2, 0, 0))
                obs.append(bevel(fl, 0.006))
                obs.append(K.sphere("Tassel", 0.025, at=at(x, 2.3, 0.81), m=gold, seg=8, col=col))
            else:
                obs.append(gbox("Stripe", (W / n + 0.01, 0.06, 1.3), (x, 2.65, 0.15), m, col, rot=(0.22, 0, 0)))
                obs.append(K.cyl("Flap", W / n / 2, 0.04, at=at(x, 2.48, 0.8), seg=10, m=m, col=col,
                                 rot=(math.pi / 2, 0, 0)))
        # the sign board, tilted back, with a gold frame round it and two rods holding it up (its words are the
        # game's own label just in front of it: the frame stays behind z 0.34)
        obs.append(gbox("Sign Board", (2.2, 0.5, 0.06), (0, 3.1, 0.3), board, col, bevel=b, rot=(-0.1, 0, 0)))
        if high:
            for s in (-1, 1):
                obs.append(gbox("Frame", (2.26, 0.04, 0.07), (0, 3.1 + s * 0.255 * math.cos(0.1),
                                                              0.3 - s * 0.255 * math.sin(0.1)), gold, col, bevel=0.008,
                                rot=(-0.1, 0, 0)))
                obs.append(gbox("Frame", (0.04, 0.54, 0.07), (s * 1.12, 3.1, 0.3), gold, col, bevel=0.008,
                                rot=(-0.1, 0, 0)))
                obs.append(rod("Sign Rod", at(s * 0.8, 2.76, 0.27), at(s * 0.8, 2.9, 0.29), 0.015, gold, col, seg=8))
                obs.append(K.sphere("Corner Gem", 0.035, at=at(s * 1.12, 3.36, 0.27), m=K.mat(
                    "Gem", TEAL, rough=0.1, metal=0.3, emit=0.6), seg=12, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


def workbench():
    wood, top, gold, teal, pink, board = stall_mats()
    steel = K.mat("Vice Steel", (0.55, 0.55, 0.62), rough=0.35, metal=0.9, pits=0.2)
    vice = K.mat("Vice Teal", TEAL, rough=0.45, metal=0.3)
    handle = K.mat("Tool Grip", PINK, rough=0.6)

    def build(col, high):
        obs = []
        b = 0.012 if high else 0
        if high:
            # legs, a frame, two drawers and a shelf underneath
            for sx in (-1, 1):
                for sz in (-1, 1):
                    obs.append(gbox("Leg", (0.08, 0.85, 0.08), (sx * 0.84, 0.425, sz * 0.32), wood, col, bevel=0.01))
            obs.append(gbox("Apron", (1.7, 0.18, 0.7), (0, 0.76, 0), wood, col, bevel=0.01))
            for x in (-0.42, 0.42):
                obs.append(gbox("Drawer", (0.78, 0.15, 0.02), (x, 0.76, 0.36), top, col, bevel=0.006))
                obs.append(gbox("Drawer Pull", (0.16, 0.025, 0.025), (x, 0.76, 0.38), gold, col, bevel=0.006))
            obs.append(gbox("Shelf", (1.7, 0.04, 0.66), (0, 0.18, 0), wood, col, bevel=0.008))
            # things on the shelf: a toolbox and some tins
            obs.append(gbox("Toolbox", (0.5, 0.22, 0.28), (-0.45, 0.31, 0.05), K.mat("Toolbox", PINK, rough=0.4,
                                                                                    metal=0.3), col, bevel=0.015))
            obs.append(gbox("Toolbox Handle", (0.3, 0.03, 0.03), (-0.45, 0.45, 0.05), gold, col, bevel=0.008))
            for k in range(3):
                obs.append(K.cyl("Tin", 0.07, 0.16, at=at(0.3 + k * 0.17, 0.28, 0.08), seg=20, m=(teal, gold, top)[k],
                                 col=col))
        else:
            obs.append(gbox("Bench", (1.8, 0.85, 0.75), (0, 0.425, 0), wood, col))
        obs.append(gbox("Bench Top", (1.9, 0.07, 0.85), (0, 0.88, 0), top, col, bevel=b))
        for s in (-1, 1):
            obs.append(gbox("Post", (0.08, 2.2, 0.08), (s * 0.85, 1.1, -0.32), wood, col, bevel=b))
        obs.append(gbox("Pegboard", (1.9, 0.8, 0.05), (0, 1.75, -0.36), board, col, bevel=b / 2))
        obs.append(gbox("Awning", (2.0, 0.06, 1.1), (0, 2.25, 0.15), K.mat("Bench Awning", LILAC, rough=0.8,
                                                                            bump=0.25), col, bevel=b, rot=(0.2, 0, 0)))
        if high:
            # the pegboard's holes, and a gold rim round it
            hole = K.mat("Peg Hole", INK, rough=0.9)
            for i in range(17):
                for j in range(7):
                    obs.append(K.cyl("Peg Hole", 0.01, 0.01, at=at(-0.88 + i * 0.11, 1.42 + j * 0.11, -0.334), seg=6,
                                     m=hole, col=col, rot=(math.pi / 2, 0, 0)))
            for s in (-1, 1):
                obs.append(gbox("Peg Rim", (1.94, 0.03, 0.06), (0, 1.75 + s * 0.4, -0.355), gold, col, bevel=0.006))
            # the awning's scalloped edge
            for k in range(8):
                x = -0.875 + k * 0.25
                fl = K.cyl("Flap", 0.125, 0.02, at=at(x, 2.13, 0.69), seg=20, m=pink if k % 2 else teal, col=col,
                           rot=(math.pi / 2 - 0.2, 0, 0))
                obs.append(fl)
            # the vice: jaws, a screw and a tommy bar
            obs.append(gbox("Vice Body", (0.18, 0.1, 0.2), (-0.6, 0.97, 0.05), vice, col, bevel=0.015))
            obs.append(gbox("Vice Jaw", (0.2, 0.08, 0.04), (-0.6, 1.06, -0.02), steel, col, bevel=0.006))
            obs.append(gbox("Vice Jaw", (0.2, 0.08, 0.04), (-0.6, 1.06, 0.15), steel, col, bevel=0.006))
            obs.append(rod("Vice Screw", at(-0.6, 1.0, 0.15), at(-0.6, 1.0, 0.35), 0.015, steel, col, seg=10))
            obs.append(rod("Tommy Bar", at(-0.7, 1.0, 0.35), at(-0.5, 1.0, 0.35), 0.01, steel, col, seg=8))
            # four gold tools on pegs: a spanner, a screwdriver, a hammer and a wrench (where the game's were)
            for k in range(4):
                x = -0.6 + 0.4 * k
                tilt = 0.2 * (k - 1.5)
                if k == 0:      # spanner: a bar with an open jaw at each end
                    obs.append(gbox("Spanner", (0.04, 0.3, 0.015), (x, 1.8, -0.32), gold, col, bevel=0.005,
                                    rot=(0, 0, tilt)))
                    for e in (-1, 1):
                        obs.append(K.cyl("Spanner Head", 0.04, 0.015, at=at(x - math.sin(tilt) * e * 0.15,
                                                                            1.8 + math.cos(tilt) * e * 0.15, -0.32),
                                         seg=16, m=gold, col=col, rot=(math.pi / 2, 0, 0)))
                elif k == 1:    # screwdriver: a pink grip and a gold shaft
                    obs.append(gbox("Screwdriver Grip", (0.05, 0.12, 0.05), (x, 1.9, -0.32), handle, col,
                                    bevel=0.015, rot=(0, 0, tilt)))
                    obs.append(gbox("Screwdriver Shaft", (0.012, 0.2, 0.012), (x + 0.02, 1.74, -0.32), gold, col,
                                    rot=(0, 0, tilt)))
                elif k == 2:    # hammer: a handle and a head
                    obs.append(gbox("Hammer Handle", (0.03, 0.3, 0.03), (x, 1.78, -0.32), handle, col, bevel=0.008,
                                    rot=(0, 0, tilt)))
                    obs.append(gbox("Hammer Head", (0.14, 0.05, 0.05), (x - 0.02, 1.93, -0.32), gold, col,
                                    bevel=0.01, rot=(0, 0, tilt)))
                else:           # wrench: a bar with a round head
                    obs.append(gbox("Wrench", (0.035, 0.28, 0.015), (x, 1.78, -0.32), gold, col, bevel=0.005,
                                    rot=(0, 0, tilt)))
                    obs.append(K.cyl("Wrench Head", 0.05, 0.02, at=at(x - 0.04, 1.93, -0.32), seg=16, m=gold, col=col,
                                     rot=(math.pi / 2, 0, 0)))
                obs.append(rod("Peg", at(x, 1.95, -0.34), at(x, 1.95, -0.3), 0.006, gold, col, seg=6))
        else:
            obs.append(gbox("Vice", (0.18, 0.14, 0.2), (-0.6, 0.98, 0.1), vice, col))
            for k in range(4):
                obs.append(gbox("Tool", (0.05, 0.32, 0.02), (-0.6 + 0.4 * k, 1.8, -0.32), gold, col,
                                rot=(0, 0, 0.2 * (k - 1.5))))
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
    "clock_case": (clock_case, 1024, False, 0.03, 0.08),
    "clock_hood": (clock_hood, 1024, True, 0.03, 0.08),
    "cog": (cog, 512, False, 0.03, 0.08),
    "boulder": (boulder, 1024, False, 0.15, 0.35),
    "ammo_crate": (ammo_crate, 1024, False, 0.04, 0.1),
    "gadget_stall": (gadget_stall, 2048, True, 0.04, 0.12),
    "workbench": (workbench, 1024, False, 0.04, 0.1),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

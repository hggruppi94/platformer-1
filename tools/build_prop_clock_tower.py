# Grandfather Tock's Clockwork Tower (scripts/clock_tower.gd), built the detailed way (tools/bake_kit.py; 23 Nov 2026,
# Hayden: "keep baking details"): the gears, the Pendulum Walk's gear walls, pendulum frames and pendulums, the Cog
# Gate, the tower's round wall (its door bay too), the Big Clock, Tock's dais, the Cuckoo Chest's house and the clock
# floor's rail posts. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Every piece is made in the space of the plain mesh or node it replaces, so scripts/detail_props.gd
# dress_clock_tower puts each one where the old one was and every collision stays the game's. Blender's X is Godot's
# X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   tower_gear      a gear of radius 1 (axle along y, 0.25 thick), sixteen teeth, a sunken web with six spokes and a
#                   bolted hub; the game scales it to each gear's radius in x and z.
#   gear_wall       a 4.6 m bay of the walk's gear walls (1 x 10 x 4.6, from the ground up): framed and panelled
#                   boards, brass bands and rivets, a cornice; both sides alike.
#   pendulum_frame  a pendulum's frame in its z's space: two posts (0.7 square, x +-9) up to a beam at 12.3 with knee
#                   braces, brass bands and a bearing over the pivot at 12.
#   pendulum        the swinging part in its pivot's space: a fluted rod down 10.8 m and the brass bob (radius 1, 0.5
#                   thick, its face along z), leaving the game's glowing middle showing.
#   cog_gate        the Cog Gate in its node's space: two timber towers (3 x 9 x 3 at x +-7, z 46) and the beam at 8.5
#                   (its front at z 45.3 kept flat for the gate's clock).
#   tower_bay       a tenth of the tower's round wall (r 26, 18 high, centred on +z, -18 to 18 degrees), panelled
#                   inside and out, with pilasters, a blind arched window and battlements on top.
#   tower_door      the same with an arched way in (10 m wide, 10 high) in the middle, for the bay over the walk.
#   big_clock       the Big Clock's face in its node's space (radius 8, front -z): numerals, minute ticks, a sunburst,
#                   a beaded brass bezel and a wooden case; the game's hands stay in front.
#   tock_dais       Tock's dais from the ground (r 2.4 to 2.2, 1 high): stepped brass with teeth round its top and an
#                   inlaid wooden top.
#   cuckoo_house    the Cuckoo Chest's little house in its node's space (1.6 x 1.6 x 1.2): carved boards, a shingled
#                   roof, a little clock face and a bird on the ridge; its front stays flat round the game's door.
#   rail_post       one of the clock floor's rail posts (r 0.18, 1 high, centred): a turned brass baluster.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_clock_tower.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["tower_gear", "gear_wall", "pendulum_frame", "pendulum", "cog_gate", "tower_bay", "tower_door", "big_clock",
         "tock_dais", "cuckoo_house", "rail_post"]
KIND = next((a for a in sys.argv if a in KINDS), "tower_gear")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

WOOD = (0.42, 0.2, 0.15)
WOOD_DARK = (0.3, 0.14, 0.1)
WOOD_PALE = (0.55, 0.3, 0.2)
WALL = (0.36, 0.18, 0.14)
BRASS = (0.88, 0.64, 0.26)
BRASS_DARK = (0.66, 0.44, 0.16)
CREAM = (0.98, 0.94, 0.82)
INK = (0.12, 0.08, 0.14)
ROOF = (0.25, 0.5, 0.4)
TEAL = (0.35, 1.0, 0.88)
STONE = (0.5, 0.4, 0.42)
DARK = (0.08, 0.06, 0.1)


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
    return rod(name, at(*a), at(*b), r, m, col, seg=seg, r2=r2)


def gwire(name, pts, r, m, col, closed=False, res=12, bevel_res=4):
    return K.wire(name, [at(*p) for p in pts], r, m=m, closed=closed, res=res, bevel_res=bevel_res, col=col)


def glathe(name, prof, m, col, seg=32, y=0.0, pos=(0, 0, 0), **kw):
    """A lathe round Godot's y, its profile [(r, y)] measured from pos."""
    ob = K.lathe(name, prof, seg=seg, m=m, col=col, **kw)
    ob.location = at(*pos)
    return ob


def blob(name, r, pos, m, col, seed=0, seg=12, lump=0.25, squash=(1.0, 1.0, 1.0)):
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
    m = K.mat(name, a, rough=rough, metal=metal, bump=bump, grain=grain)
    nt, bsdf, co = _nodes(m)
    c = _mix_rgb(nt, _patches(nt, co, scale, lo, hi), a, b)
    if third:
        c = _mix_rgb(nt, _patches(nt, co, scale * 1.7, 0.62, 0.66, w=2.7), c, third)
    nt.links.new(c, bsdf.inputs["Base Color"])
    return m


def glowing(m, rgb, strength):
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Emission Color"].default_value = (*(K.srgb_to_linear(c) for c in rgb), 1.0)
    b.inputs["Emission Strength"].default_value = strength
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



def gstar(name, r, depth, centre, face, m, col, inner=0.45, spin=0.0):
    """A little five-pointed star relief, depth thick, its face looking along face ('-z', '+z' or '+y'/'-y')."""
    bm = bmesh.new()
    pts = []
    for k in range(10):
        a = math.pi / 2 + spin + k * math.pi / 5
        rr = r if k % 2 == 0 else r * inner
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    vs0 = [bm.verts.new((x, y, -depth / 2)) for x, y in pts]
    vs1 = [bm.verts.new((x, y, depth / 2)) for x, y in pts]
    c0 = bm.verts.new((0, 0, -depth / 2))
    c1 = bm.verts.new((0, 0, depth / 2 + depth * 0.6))
    for k in range(10):
        j = (k + 1) % 10
        bm.faces.new((vs0[j], vs0[k], c0))
        bm.faces.new((vs1[k], vs1[j], c1))
        bm.faces.new((vs0[k], vs0[j], vs1[j], vs1[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = K._obj(name, bm, m, False, col)
    # the star is made facing Blender +z; turn it to face the Godot direction asked for
    rot = {"+y": (0, 0, 0), "-y": (math.pi, 0, 0), "-z": (math.pi / 2, 0, 0), "+z": (-math.pi / 2, 0, 0),
           "+x": (0, math.pi / 2, 0), "-x": (0, -math.pi / 2, 0)}[face]
    ob.rotation_euler = rot
    ob.location = at(*centre)
    return ob



def brass_mat(name="Clock Brass"):
    return mottled(name, BRASS, BRASS_DARK, scale=7.0, rough=0.3, metal=0.85, bump=0.08)


def wood_mat(name, base=WOOD, dark=WOOD_DARK, grain=14.0):
    return mottled(name, base, dark, scale=5.0, rough=0.7, bump=0.15, grain=(grain, 0.3))


def arc_prism(name, a0, a1, r0, r1, y0, y1, m, col, seg=1):
    """A curved block round the tower's middle (Godot's y axis), from angle a0 to a1 (0 is +z, sin a is x), between
    radii r0 and r1 and heights y0 and y1."""
    bm = bmesh.new()
    rows = []
    for i in range(seg + 1):
        a = a0 + (a1 - a0) * i / seg
        s, c = math.sin(a), math.cos(a)
        rows.append([bm.verts.new(at(s * r, y, c * r)) for (r, y) in ((r0, y0), (r1, y0), (r1, y1), (r0, y1))])
    for i in range(seg):
        A, B = rows[i], rows[i + 1]
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((A[k], A[j], B[j], B[k]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, False, col)


def zlathe(name, prof, m, col, pos=(0, 0, 0), seg=48, **kw):
    """A lathe whose axis is Godot's z (a clock face, a pendulum bob): prof is [(r, z)]."""
    ob = K.lathe(name, prof, seg=seg, m=m, col=col, **kw)
    ob.rotation_euler = (math.pi / 2, 0, 0)
    ob.location = at(*pos)
    return ob


def text(name, s, size, pos, m, col, depth=0.03):
    """Raised letters on a face looking towards Godot's -z (the way the Big Clock looks)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = s
    cu.size = size
    cu.extrude = depth
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    ob = bpy.data.objects.new(name, cu)
    col.objects.link(ob)
    cu.materials.append(m)
    ob.rotation_euler = (-math.pi / 2, math.pi, 0)
    ob.location = at(*pos)
    return ob


def boards(obs, col, mats, rnd, centre, u, n, width, y0, y1, bw=0.3, depth=0.05, gap=0.02):
    """Upright boards over a flat face: centre is the face's middle at the ground (Godot), u its across direction, n
    its outward normal. Each board's front lies on the face, give or take a little."""
    u, n = Vector(u), Vector(n)
    k = max(1, round(width / bw))
    w = width / k
    for i in range(k):
        x = -width / 2 + w * (i + 0.5)
        d = depth + rnd.uniform(-0.012, 0.012)
        mid = Vector(centre) + u * x + Vector((0, (y0 + y1) / 2, 0)) - n * (d / 2 - 0.01)
        size = u * (w - gap) + Vector((0, y1 - y0, 0)) + n * d
        obs.append(gbox("Board", (abs(size.x), abs(size.y), abs(size.z)), tuple(mid), rnd.choice(mats), col,
                        bevel=0.01))


# ================================================================ a gear
def tower_gear():
    brass = brass_mat("Gear Brass")
    deep = K.mat("Gear Brass Deep", BRASS_DARK, rough=0.4, metal=0.85)
    wood = wood_mat("Gear Hub Wood")

    def build(col, high):
        teeth = []
        for k in range(16):
            a = k * math.tau / 16
            teeth.append(gbox("Tooth", (0.24, 0.24, 0.2), (math.cos(a) * 1.08, 0, math.sin(a) * 1.08), brass, col,
                              bevel=0.03 if high else 0.0, rot=(0, -a, 0)))
        if not high:
            return teeth + [K.cyl("Disc", 1.0, 0.25, seg=32, m=brass, col=col),
                            K.cyl("Hub", 0.25, 0.4, seg=16, m=wood, col=col)]
        obs = teeth
        obs.append(glathe("Wheel", [(0, -0.06), (0.3, -0.06), (0.74, -0.06), (0.77, -0.125), (0.97, -0.125),
                                    (1.0, -0.1), (1.0, 0.1), (0.97, 0.125), (0.77, 0.125), (0.74, 0.06), (0.3, 0.06),
                                    (0, 0.06)], brass, col, seg=96))
        for s in (-1, 1):                                       # a groove round each face of the rim
            obs.append(glathe("Groove", [(0.85, s * 0.125), (0.87, s * 0.132), (0.89, s * 0.125)], deep, col, seg=96))
        for k in range(6):                                      # spokes across the sunken web
            a = k * math.tau / 6 + math.pi / 6
            obs.append(gbox("Spoke", (0.5, 0.2, 0.14), (math.cos(a) * 0.52, 0, math.sin(a) * 0.52), brass, col,
                            bevel=0.03, rot=(0, -a, 0)))
        obs.append(glathe("Boss", [(0, -0.15), (0.32, -0.15), (0.34, -0.1), (0.34, 0.1), (0.32, 0.15), (0, 0.15)],
                          brass, col, seg=48))
        obs.append(glathe("Hub", [(0, -0.2), (0.22, -0.2), (0.25, -0.17), (0.25, 0.17), (0.22, 0.2), (0, 0.2)], wood,
                          col, seg=32))
        for k in range(6):
            a = k * math.tau / 6
            for s in (-1, 1):
                obs.append(K.sphere("Bolt", 0.035, at=at(math.cos(a) * 0.29, s * 0.155, math.sin(a) * 0.29), m=deep,
                                    seg=8, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a bay of the walk's gear walls
def gear_wall():
    woods = [wood_mat("Wall Board", WALL, WOOD_DARK), wood_mat("Wall Board Pale", WOOD, WALL),
             wood_mat("Wall Board Dark", (0.32, 0.15, 0.11), (0.24, 0.1, 0.08))]
    frame = wood_mat("Wall Frame", WOOD_DARK, (0.22, 0.1, 0.07), grain=10.0)
    brass = brass_mat("Wall Brass")
    stone = mottled("Wall Plinth", STONE, (0.4, 0.32, 0.34), scale=4.0, rough=0.85, bump=0.35)
    L = 4.6

    def build(col, high):
        if not high:
            return [gbox("Wall", (1.0, 10.0, L), (0, 5.0, 0), woods[0], col),
                    gbox("Cornice", (1.2, 0.3, L), (0, 9.85, 0), frame, col),
                    gbox("Plinth", (1.14, 0.45, L), (0, 0.225, 0), stone, col)]
        rnd = random.Random(201)
        obs = [gbox("Core", (0.9, 10.0, L), (0, 5.0, 0), frame, col)]
        for s in (-1, 1):
            for (y0, y1) in ((0.45, 4.85), (5.15, 9.55)):
                boards(obs, col, woods, rnd, (s * 0.5, 0, 0), (0, 0, 1), (s, 0, 0), L - 0.3, y0, y1, bw=0.32)
            for z in (-L / 2 + 0.06, L / 2 - 0.06):             # the frame's posts at both ends
                obs.append(gbox("Post", (0.1, 9.6, 0.24), (s * 0.5, 5.0, z), frame, col, bevel=0.02))
            for y in (0.55, 5.0, 9.45):                          # rails, each with a brass band and rivets
                obs.append(gbox("Rail", (0.08, 0.3, L), (s * 0.5, y, 0), frame, col, bevel=0.02))
                obs.append(gbox("Band", (0.03, 0.08, L), (s * 0.545, y, 0), brass, col, bevel=0.008))
                for k in range(9):
                    obs.append(K.sphere("Rivet", 0.025, at=at(s * 0.56, y, -L / 2 + L * (k + 0.5) / 9), m=brass, seg=6,
                                        col=col))
            for (y0, y1, flip) in ((0.75, 4.75, 1), (5.25, 9.25, -1)):   # a brace across each panel
                dz, dy = L - 0.5, y1 - y0
                ang = math.atan2(dy, dz) * flip
                obs.append(gbox("Brace", (0.05, 0.2, math.hypot(dz, dy)), (s * 0.52, (y0 + y1) / 2, 0), frame, col,
                                bevel=0.015, rot=(ang, 0, 0)))
            for z in (-L / 2 + 0.06, L / 2 - 0.06):             # brass corner plates where rails meet posts
                for y in (0.55, 5.0, 9.45):
                    obs.append(gbox("Plate", (0.02, 0.4, 0.4), (s * 0.555, y, z), brass, col, bevel=0.01))
        obs.append(gbox("Plinth", (1.14, 0.45, L), (0, 0.225, 0), stone, col, bevel=0.03))
        obs.append(gbox("Cornice", (1.1, 0.16, L), (0, 9.72, 0), frame, col, bevel=0.02))
        obs.append(gbox("Cornice Top", (1.22, 0.16, L), (0, 9.9, 0), frame, col, bevel=0.03))
        obs.append(gbox("Cornice Brass", (1.24, 0.03, L), (0, 9.81, 0), brass, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a pendulum's frame
def pendulum_frame():
    wood = wood_mat("Frame Wood")
    dark = wood_mat("Frame Dark", WOOD_DARK, (0.22, 0.1, 0.07))
    brass = brass_mat("Frame Brass")
    stone = mottled("Frame Plinth", STONE, (0.4, 0.32, 0.34), scale=4.0, rough=0.85, bump=0.35)

    def build(col, high):
        if not high:
            obs = [gbox("Beam", (19.0, 0.7, 0.9), (0, 12.3, 0), wood, col)]
            for s in (-1, 1):
                obs.append(gbox("Post", (0.7, 12.6, 0.7), (s * 9.0, 6.3, 0), wood, col))
                obs.append(gbox("Plinth", (1.0, 0.6, 1.0), (s * 9.0, 0.3, 0), stone, col))
                obs.append(grod("Knee", (s * 9.0, 10.5, 0), (s * 7.4, 11.95, 0), 0.12, dark, col, seg=6))
            obs.append(gbox("Bearing", (0.8, 0.35, 1.0), (0, 11.95, 0), brass, col))
            return obs
        obs = [gbox("Beam", (19.0, 0.7, 0.9), (0, 12.3, 0), wood, col, bevel=0.05)]
        for x in (-9.5, 9.5):
            obs.append(gbox("Beam Cap", (0.08, 0.78, 0.98), (x, 12.3, 0), brass, col, bevel=0.015))
        for k in range(19):
            x = -9.0 + k
            for z in (-0.46, 0.46):
                obs.append(K.sphere("Rivet", 0.03, at=at(x, 12.55, z), m=brass, seg=6, col=col))
                obs.append(K.sphere("Rivet", 0.03, at=at(x, 12.05, z), m=brass, seg=6, col=col))
        for s in (-1, 1):
            obs.append(gbox("Post", (0.66, 11.2, 0.66), (s * 9.0, 6.2, 0), wood, col, bevel=0.06))
            obs.append(gbox("Plinth", (1.0, 0.45, 1.0), (s * 9.0, 0.225, 0), stone, col, bevel=0.04))
            obs.append(gbox("Base", (0.82, 0.25, 0.82), (s * 9.0, 0.57, 0), dark, col, bevel=0.03))
            obs.append(gbox("Capital", (0.84, 0.3, 0.84), (s * 9.0, 11.8, 0), dark, col, bevel=0.03))
            obs.append(gbox("Capital Top", (0.76, 0.2, 0.76), (s * 9.0, 12.0, 0), wood, col, bevel=0.02))
            for y in (2.5, 5.5, 8.5):
                obs.append(gbox("Band", (0.72, 0.14, 0.72), (s * 9.0, y, 0), brass, col, bevel=0.02))
                for k in range(4):
                    a = k * math.pi / 2
                    obs.append(K.sphere("Rivet", 0.03, at=at(s * 9.0 + math.cos(a) * 0.36, y, math.sin(a) * 0.36),
                                        m=brass, seg=6, col=col))
            obs.append(grod("Knee", (s * 9.0, 10.5, 0), (s * 7.4, 11.95, 0), 0.1, dark, col, seg=8))
            obs.append(gbox("Knee Plate", (0.3, 0.3, 0.92), (s * 7.5, 11.95, 0), brass, col, bevel=0.02))
        obs.append(gbox("Bearing", (0.7, 0.3, 1.0), (0, 11.95, 0), brass, col, bevel=0.04))
        for z in (-0.5, 0.5):
            obs.append(zlathe("Bearing Cap", [(0, 0), (0.2, 0), (0.18, 0.06), (0, 0.07)], brass, col,
                              pos=(0, 12.0, z * 1.02), seg=24))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a pendulum
def pendulum():
    brass = brass_mat("Bob Brass")
    deep = K.mat("Bob Deep", BRASS_DARK, rough=0.4, metal=0.85)
    ARM = 10.8

    def build(col, high):
        if not high:
            return [gbox("Arm", (0.18, ARM - 0.7, 0.18), (0, -(ARM - 0.7) / 2, 0), brass, col),
                    zlathe("Bob", [(0, -0.25), (1.0, -0.25), (1.0, 0.25), (0, 0.25)], brass, col,
                           pos=(0, -ARM, 0), seg=32)]
        obs = [glathe("Rod", [(0, -ARM + 0.9), (0.08, -ARM + 0.9), (0.08, -0.2), (0, -0.2)], brass, col, seg=32,
                      flutes=8, flute_depth=0.02, flute_z=(-ARM + 1.0, -0.4))]
        for y in (-0.25, -3.0, -6.0, -8.6):
            obs.append(glathe("Collar", [(0.07, y - 0.12), (0.12, y - 0.1), (0.13, y), (0.12, y + 0.1),
                                         (0.07, y + 0.12)], deep, col, seg=32))
        obs.append(zlathe("Hanger", [(0.12, -0.1), (0.2, -0.1), (0.2, 0.1), (0.12, 0.1)], brass, col, pos=(0, 0, 0),
                          seg=32))
        obs.append(gbox("Yoke", (0.34, 0.5, 0.3), (0, -ARM + 1.05, 0), brass, col, bevel=0.05))
        obs.append(zlathe("Bob", [(0, -0.25), (0.55, -0.25), (0.6, -0.23), (0.82, -0.23), (0.86, -0.27),
                                  (0.97, -0.27), (1.0, -0.22), (1.0, 0.22), (0.97, 0.27), (0.86, 0.27), (0.82, 0.23),
                                  (0.6, 0.23), (0.55, 0.25), (0, 0.25)], brass, col, pos=(0, -ARM, 0), seg=96))
        for s in (-1, 1):
            obs.append(zlathe("Ring", [(0.68, s * 0.23), (0.7, s * 0.245), (0.72, s * 0.23)], deep, col,
                              pos=(0, -ARM, 0), seg=96))
            for k in range(12):
                a = k * math.tau / 12
                obs.append(K.sphere("Stud", 0.03, at=at(math.cos(a) * 0.915, -ARM + math.sin(a) * 0.915, s * 0.275),
                                    m=deep, seg=6, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Cog Gate
def cog_gate():
    woods = [wood_mat("Gate Board", WOOD, WOOD_DARK), wood_mat("Gate Board Pale", WOOD_PALE, WOOD),
             wood_mat("Gate Board Dark", WALL, WOOD_DARK)]
    frame = wood_mat("Gate Frame", WOOD_DARK, (0.22, 0.1, 0.07), grain=10.0)
    brass = brass_mat("Gate Brass")
    stone = mottled("Gate Plinth", STONE, (0.4, 0.32, 0.34), scale=4.0, rough=0.85, bump=0.35)
    shadow = K.mat("Gate Shadow", DARK, rough=0.9)
    Z = 46.0

    def build(col, high):
        if not high:
            obs = [gbox("Beam", (17.0, 1.2, 1.4), (0, 8.5, Z), frame, col)]
            for s in (-1, 1):
                obs.append(gbox("Tower", (3.0, 9.0, 3.0), (s * 7.0, 4.5, Z), woods[0], col))
                obs.append(gbox("Cornice", (3.3, 0.25, 3.3), (s * 7.0, 9.1, Z), frame, col))
                obs.append(gbox("Plinth", (3.24, 0.6, 3.24), (s * 7.0, 0.3, Z), stone, col))
                obs.append(grod("Knee", (s * 5.5, 6.4, Z), (s * 4.0, 7.9, Z), 0.13, frame, col, seg=6))
            return obs
        rnd = random.Random(211)
        obs = []
        for s in (-1, 1):
            x0 = s * 7.0
            obs.append(gbox("Core", (2.8, 9.0, 2.8), (x0, 4.5, Z), frame, col))
            for (u, n, c) in (((1, 0, 0), (0, 0, -1), (x0, 0, Z - 1.5)), ((1, 0, 0), (0, 0, 1), (x0, 0, Z + 1.5)),
                              ((0, 0, 1), (-1, 0, 0), (x0 - 1.5, 0, Z)), ((0, 0, 1), (1, 0, 0), (x0 + 1.5, 0, Z))):
                for (y0, y1) in ((0.6, 4.4), (4.6, 8.8)):
                    boards(obs, col, woods, rnd, c, u, n, 2.4, y0, y1, bw=0.3)
            for (dx, dz) in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
                obs.append(gbox("Corner", (0.36, 8.6, 0.36), (x0 + dx * 1.36, 4.6, Z + dz * 1.36), frame, col,
                                bevel=0.04))
                for y in (1.0, 4.5, 8.0):
                    obs.append(gbox("Corner Band", (0.42, 0.14, 0.42), (x0 + dx * 1.36, y, Z + dz * 1.36), brass, col,
                                    bevel=0.015))
            for y in (0.7, 4.5, 8.7):
                obs.append(gbox("Rail", (3.08, 0.22, 3.08), (x0, y, Z), frame, col, bevel=0.03))
            obs.append(gbox("Plinth", (3.24, 0.6, 3.24), (x0, 0.3, Z), stone, col, bevel=0.05))
            obs.append(gbox("Cornice", (3.3, 0.22, 3.3), (x0, 9.1, Z), frame, col, bevel=0.03))
            obs.append(gbox("Cornice Brass", (3.34, 0.04, 3.34), (x0, 9.0, Z), brass, col))
            # a blind arched door on the front of each tower, in a brass frame
            arch = [(x0 - 0.7, 0.6, Z - 1.56)]
            for k in range(13):
                t = math.pi * k / 12
                arch.append((x0 - math.cos(t) * 0.7, 2.8 + math.sin(t) * 0.7, Z - 1.56))
            arch.append((x0 + 0.7, 0.6, Z - 1.56))
            obs.append(gbox("Door Shadow", (1.36, 2.2, 0.04), (x0, 1.7, Z - 1.53), shadow, col))
            obs.append(zlathe("Door Shadow Top", [(0, 0), (0.68, 0), (0.68, 0.04), (0, 0.04)], shadow, col,
                              pos=(x0, 2.8, Z - 1.55), seg=32))
            obs.append(gwire("Door Frame", arch, 0.06, brass, col, res=8, bevel_res=2))
            obs.append(K.sphere("Door Knob", 0.07, at=at(x0 + 0.42, 1.6, Z - 1.6), m=brass, seg=10, col=col))
            # a brass roundel over it, like a little clock
            obs.append(zlathe("Roundel", [(0, -0.02), (0.42, -0.02), (0.45, 0.0), (0.42, 0.04), (0, 0.04)], brass, col,
                              pos=(x0, 6.6, Z - 1.58), seg=48))
            for k in range(12):
                a = k * math.tau / 12
                obs.append(gbox("Roundel Mark", (0.04, 0.12, 0.03), (x0 - math.sin(a) * 0.32, 6.6 + math.cos(a) * 0.32,
                                                                     Z - 1.6), shadow, col, rot=(0, 0, a)))
            obs.append(grod("Knee", (s * 5.5, 6.4, Z), (s * 4.0, 7.9, Z), 0.12, frame, col, seg=8))
            obs.append(gbox("Knee Plate", (0.5, 0.5, 1.44), (s * 5.45, 6.4, Z), brass, col, bevel=0.03))
        # the beam: timber with brass bands and rivets, its middle kept flat for the gate's clock
        obs.append(gbox("Beam", (17.0, 1.2, 1.4), (0, 8.5, Z), frame, col, bevel=0.05))
        for x in (-5.6, -3.2, 3.2, 5.6):
            obs.append(gbox("Beam Band", (0.14, 1.26, 1.46), (x, 8.5, Z), brass, col, bevel=0.02))
        for k in range(21):
            x = -8.0 + k * 0.8
            if abs(x) < 1.6:
                continue
            for y in (7.98, 9.02):
                obs.append(K.sphere("Rivet", 0.035, at=at(x, y, Z - 0.71), m=brass, seg=6, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the tower's round wall
R_IN, R_OUT = 25.7, 26.3
HALF = math.pi / 10


def _arch_y(x, half, spring):
    """The underside of an arch at x along the wall (half its width, where it springs)."""
    return spring + math.sqrt(max(0.0, half * half - x * x))


def _bay(door):
    woods = [wood_mat("Bay Board", WALL, WOOD_DARK), wood_mat("Bay Board Pale", WOOD, WALL),
             wood_mat("Bay Board Dark", (0.3, 0.14, 0.11), (0.22, 0.1, 0.08))]
    frame = wood_mat("Bay Frame", WOOD_DARK, (0.22, 0.1, 0.07), grain=10.0)
    brass = brass_mat("Bay Brass")
    stone = mottled("Bay Stone", STONE, (0.4, 0.32, 0.34), scale=4.0, rough=0.85, bump=0.35)
    shadow = K.mat("Bay Shadow", DARK, rough=0.9)
    D_HALF, D_SPRING = 5.0, 5.0                     # the way in: 10 wide, round topped at 10
    W_HALF, W_SPRING, W_BOT = 2.0, 11.5, 3.6        # the blind window
    pil = HALF * (0.75 if door else 0.55)

    def bottom(x):
        return _arch_y(x, D_HALF, D_SPRING) if door and abs(x) < D_HALF else 0.0

    def build(col, high):
        obs = []
        if not high:
            n = 40 if door else 12
            for i in range(n):
                a0, a1 = -HALF + 2 * HALF * i / n, -HALF + 2 * HALF * (i + 1) / n
                y0 = bottom((a0 + a1) / 2 * R_IN)
                obs.append(arc_prism("Wall", a0, a1, R_IN, R_OUT, y0, 17.4, woods[0], col))
            obs.append(arc_prism("Cornice", -HALF, HALF, R_IN - 0.15, R_OUT + 0.15, 17.4, 18.0, frame, col, seg=12))
            for i in range(6):
                ac = -HALF + 2 * HALF * (i + 0.5) / 6
                obs.append(arc_prism("Merlon", ac - 0.02, ac + 0.02, R_IN, R_OUT, 18.0, 18.9, frame, col))
            for s in (-1, 1):
                obs.append(arc_prism("Pilaster", s * pil - 0.018, s * pil + 0.018, R_IN - 0.4, R_IN, 0, 17.4, frame,
                                     col))
            return obs
        rnd = random.Random(221 if door else 231)
        # the core, then boards on both faces (the inside one round the window or the way in)
        n = 60 if door else 24
        for i in range(n):
            a0, a1 = -HALF + 2 * HALF * i / n, -HALF + 2 * HALF * (i + 1) / n
            obs.append(arc_prism("Core", a0, a1, R_IN + 0.06, R_OUT - 0.06, bottom((a0 + a1) / 2 * R_IN), 17.4, frame,
                                 col))
        bw = 0.42 / R_IN
        k = round(2 * HALF / bw)
        bw = 2 * HALF / k
        for i in range(k):
            a0, a1 = -HALF + bw * i + 0.0004, -HALF + bw * (i + 1) - 0.0004
            x = (a0 + a1) / 2 * R_IN
            m = rnd.choice(woods)
            d = rnd.uniform(0.0, 0.02)
            spans = [(bottom(x) + (0.0 if bottom(x) > 0 else 0.7), 17.2)]
            if not door and abs(x) < W_HALF:
                spans = [(0.7, W_BOT), (_arch_y(x, W_HALF, W_SPRING), 17.2)]
            for (y0, y1) in spans:
                if y1 - y0 > 0.05:
                    obs.append(arc_prism("Board", a0, a1, R_IN - 0.02 - d, R_IN + 0.07, y0, y1, m, col))
            yb = bottom(x) + (0.0 if bottom(x) > 0 else 0.7)
            obs.append(arc_prism("Board Out", a0, a1, R_OUT - 0.07, R_OUT + 0.02 + d, yb, 17.2, rnd.choice(woods),
                                 col))
        # the blind window: dark glass behind brass mullions, in a brass frame
        if not door:
            wn = 14
            for i in range(wn):
                x0, x1 = -W_HALF + 2 * W_HALF * i / wn, -W_HALF + 2 * W_HALF * (i + 1) / wn
                obs.append(arc_prism("Window", x0 / R_IN, x1 / R_IN, R_IN + 0.02, R_IN + 0.06, W_BOT,
                                     _arch_y((x0 + x1) / 2, W_HALF, W_SPRING), shadow, col))
            pts = [(-W_HALF, W_BOT, 0)] + [(-math.cos(t) * W_HALF, W_SPRING + math.sin(t) * W_HALF, 0)
                                           for t in [math.pi * j / 16 for j in range(17)]] + [(W_HALF, W_BOT, 0)]
            pts = [(math.sin(x / (R_IN - 0.05)) * (R_IN - 0.05), y, math.cos(x / (R_IN - 0.05)) * (R_IN - 0.05))
                   for (x, y, _) in pts]
            obs.append(gwire("Window Frame", pts, 0.09, brass, col, res=6, bevel_res=2))
            obs.append(arc_prism("Sill", -W_HALF / R_IN - 0.01, W_HALF / R_IN + 0.01, R_IN - 0.25, R_IN, W_BOT - 0.2,
                                 W_BOT, stone, col, seg=4))
            for x in (-0.7, 0.7):
                obs.append(arc_prism("Mullion", x / R_IN - 0.002, x / R_IN + 0.002, R_IN - 0.02, R_IN + 0.04, W_BOT,
                                     _arch_y(x, W_HALF, W_SPRING), brass, col))
            for y in (6.6, 9.6):
                obs.append(arc_prism("Transom", -W_HALF / R_IN, W_HALF / R_IN, R_IN - 0.02, R_IN + 0.04, y - 0.05,
                                     y + 0.05, brass, col, seg=6))
            ring = [(math.sin(math.cos(t) * 1.0 / R_IN) * (R_IN - 0.03), W_SPRING + 0.5 + math.sin(t) * 1.0,
                     math.cos(math.cos(t) * 1.0 / R_IN) * (R_IN - 0.03)) for t in [math.tau * j / 20 for j in range(20)]]
            obs.append(gwire("Rose", ring, 0.05, brass, col, closed=True, res=6, bevel_res=2))
        else:
            # the way in: brass round the arch on both faces, a keystone, and stone jambs
            for r in (R_IN - 0.04, R_OUT + 0.04):
                pts = [(-D_HALF, 0.0)] + [(-math.cos(t) * D_HALF, D_SPRING + math.sin(t) * D_HALF)
                                          for t in [math.pi * j / 24 for j in range(25)]] + [(D_HALF, 0.0)]
                obs.append(gwire("Arch Brass", [(math.sin(x / r) * r, y, math.cos(x / r) * r) for (x, y) in pts], 0.12,
                                 brass, col, res=6, bevel_res=2))
            obs.append(arc_prism("Keystone", -0.03, 0.03, R_IN - 0.15, R_OUT + 0.15, D_SPRING + D_HALF - 0.2,
                                 D_SPRING + D_HALF + 1.2, stone, col))
            for s in (-1, 1):
                obs.append(arc_prism("Jamb", s * (D_HALF / R_IN) - (0.012 if s > 0 else -0.012) * 0,
                                     s * (D_HALF / R_IN + 0.03), R_IN - 0.12, R_OUT + 0.12, 0.0, D_SPRING, stone, col))
        # pilasters on the inside, with bases and capitals and brass flutes
        for s in (-1, 1):
            c = s * pil
            obs.append(arc_prism("Pilaster", c - 0.018, c + 0.018, R_IN - 0.36, R_IN, 0.7, 16.6, frame, col))
            obs.append(arc_prism("Pilaster Base", c - 0.024, c + 0.024, R_IN - 0.46, R_IN, 0.0, 1.0, stone, col))
            obs.append(arc_prism("Pilaster Cap", c - 0.024, c + 0.024, R_IN - 0.46, R_IN, 16.4, 17.0, frame, col))
            for f in (-0.009, 0.0, 0.009):
                obs.append(arc_prism("Flute", c + f - 0.0012, c + f + 0.0012, R_IN - 0.38, R_IN - 0.34, 1.4, 16.0,
                                     brass, col))
        # brass bands with rivets inside and out, broken by the window or the way in
        for (y, r0, r1) in ((0.8, R_IN - 0.06, R_IN), (8.8, R_IN - 0.06, R_IN), (16.9, R_IN - 0.06, R_IN),
                            (0.8, R_OUT, R_OUT + 0.06), (8.8, R_OUT, R_OUT + 0.06), (16.9, R_OUT, R_OUT + 0.06)):
            gaps = []
            if door and y < D_SPRING + D_HALF:
                gaps.append(D_HALF + 0.2)
            if not door and r0 < R_IN and W_BOT < y < W_SPRING + W_HALF:
                gaps.append(W_HALF + 0.2)
            pieces = [(-HALF, HALF)] if not gaps else [(-HALF, -gaps[0] / R_IN), (gaps[0] / R_IN, HALF)]
            for (a0, a1) in pieces:
                obs.append(arc_prism("Band", a0, a1, r0, r1, y - 0.1, y + 0.1, brass, col, seg=8))
                nr = int((a1 - a0) * R_IN / 0.8)
                for j in range(nr):
                    a = a0 + (a1 - a0) * (j + 0.5) / nr
                    rr = r0 - 0.01 if r0 < R_IN else r1 + 0.01
                    obs.append(K.sphere("Rivet", 0.035, at=at(math.sin(a) * rr, y, math.cos(a) * rr), m=brass, seg=6,
                                        col=col))
        # the plinth, the cornice and the battlements
        pn = 40 if door else 12
        for i in range(pn):
            a0, a1 = -HALF + 2 * HALF * i / pn, -HALF + 2 * HALF * (i + 1) / pn
            if bottom((a0 + a1) / 2 * R_IN) > 0:
                continue
            obs.append(arc_prism("Plinth", a0, a1, R_IN - 0.12, R_OUT + 0.12, 0.0, 0.7, stone, col))
        obs.append(arc_prism("Cornice", -HALF, HALF, R_IN - 0.12, R_OUT + 0.12, 17.4, 17.7, frame, col, seg=16))
        obs.append(arc_prism("Cornice Top", -HALF, HALF, R_IN - 0.22, R_OUT + 0.22, 17.7, 18.0, frame, col, seg=16))
        obs.append(arc_prism("Cornice Brass", -HALF, HALF, R_IN - 0.24, R_OUT + 0.24, 17.68, 17.72, brass, col,
                             seg=16))
        for i in range(6):
            ac = -HALF + 2 * HALF * (i + 0.5) / 6
            obs.append(arc_prism("Merlon", ac - 0.02, ac + 0.02, R_IN, R_OUT, 18.0, 18.8, frame, col))
            obs.append(arc_prism("Merlon Cap", ac - 0.022, ac + 0.022, R_IN - 0.05, R_OUT + 0.05, 18.8, 18.9, brass,
                                 col))
        return obs

    return build(HIGH, True), build(LOW, False)


def tower_bay():
    return _bay(False)


def tower_door():
    return _bay(True)


# ================================================================ the Big Clock
def big_clock():
    cream = mottled("Face Cream", CREAM, (0.92, 0.86, 0.72), scale=3.0, rough=0.55, bump=0.05)
    ink = K.mat("Face Ink", INK, rough=0.5)
    shade = K.mat("Face Shade", (0.86, 0.78, 0.62), rough=0.6)
    brass = brass_mat("Clock Bezel")
    deep = K.mat("Clock Brass Deep", BRASS_DARK, rough=0.4, metal=0.85)
    wood = wood_mat("Clock Case", WOOD, WOOD_DARK)

    def build(col, high):
        if not high:
            return [zlathe("Face", [(0, -0.2), (7.85, -0.2), (7.95, -0.45), (8.6, -0.45), (8.75, -0.3), (9.3, -0.25),
                                    (9.3, 0.35), (0, 0.35)], cream, col, seg=64)]
        obs = [zlathe("Face", [(0, -0.2), (7.85, -0.2), (7.85, 0.2), (0, 0.2)], cream, col, seg=128)]
        obs.append(zlathe("Bezel", [(7.84, -0.18), (7.9, -0.4), (8.1, -0.48), (8.5, -0.48), (8.72, -0.36),
                                    (8.76, -0.2), (8.76, 0.25), (7.84, 0.25)], brass, col, seg=128))
        obs.append(zlathe("Case", [(8.7, -0.3), (9.25, -0.24), (9.36, -0.1), (9.36, 0.2), (9.3, 0.35), (8.7, 0.35)],
                          wood, col, seg=128))
        for k in range(96):                                    # beads round the bezel
            a = k * math.tau / 96
            obs.append(K.sphere("Bead", 0.07, at=at(-math.sin(a) * 8.3, math.cos(a) * 8.3, -0.5), m=brass, seg=8,
                                col=col))
        for k in range(12):                                    # brass studs on the case
            a = k * math.tau / 12
            obs.append(K.sphere("Stud", 0.12, at=at(-math.sin(a) * 9.02, math.cos(a) * 9.02, -0.28), m=deep, seg=10,
                                col=col))
        # rings, minute ticks, hour diamonds and the numerals (III on the right as you look at it)
        for r in (5.0, 6.95, 7.65):
            pts = [(-math.sin(t) * r, math.cos(t) * r, -0.215) for t in [math.tau * j / 96 for j in range(96)]]
            obs.append(gwire("Ring", pts, 0.03, ink, col, closed=True, res=4, bevel_res=1))
        for k in range(60):
            a = k * math.tau / 60
            big = k % 5 == 0
            obs.append(gbox("Tick", (0.22 if big else 0.07, 0.6 if big else 0.4, 0.04),
                            (-math.sin(a) * 7.3, math.cos(a) * 7.3, -0.22), ink, col, rot=(0, 0, a)))
        numerals = ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
        for k in range(12):
            a = k * math.tau / 12
            t = text("Numeral", numerals[k], 1.15, (-math.sin(a) * 6.0, math.cos(a) * 6.0, -0.2), ink, col, depth=0.03)
            t.rotation_euler = (-math.pi / 2, math.pi, 0)
            t.rotation_mode = "XYZ"
            obs.append(t)
        for k in range(24):                                    # a sunburst round the middle
            a = (k + 0.5) * math.tau / 24
            obs.append(gbox("Ray", (0.16 if k % 2 else 0.28, 2.6, 0.03), (-math.sin(a) * 2.4, math.cos(a) * 2.4, -0.21),
                            shade, col, rot=(0, 0, a)))
        obs.append(zlathe("Boss", [(0, -0.3), (0.5, -0.3), (0.62, -0.24), (0.62, -0.2), (0, -0.2)], brass, col, seg=48))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ Tock's dais
def tock_dais():
    brass = brass_mat("Dais Brass")
    deep = K.mat("Dais Brass Deep", BRASS_DARK, rough=0.4, metal=0.85)
    wood = wood_mat("Dais Wood")

    def build(col, high):
        teeth = []
        for k in range(28):
            a = k * math.tau / 28
            teeth.append(gbox("Tooth", (0.24, 0.16, 0.3), (math.cos(a) * 2.32, 0.9, math.sin(a) * 2.32), brass, col,
                              bevel=0.03 if high else 0.0, rot=(0, -a, 0)))
        if not high:
            return teeth + [glathe("Dais", [(0, 0), (2.45, 0), (2.45, 0.25), (2.32, 0.32), (2.24, 0.98), (2.0, 1.0),
                                            (2.0, 1.05), (0, 1.05)], brass, col, seg=32)]
        obs = teeth
        obs.append(glathe("Dais", [(0, 0), (2.45, 0), (2.46, 0.2), (2.42, 0.25), (2.34, 0.28), (2.33, 0.34),
                                   (2.27, 0.36), (2.22, 0.96), (2.18, 1.0), (0, 1.0)], brass, col, seg=128,
                          flutes=40, flute_depth=0.025, flute_z=(0.4, 0.78)))
        for y in (0.36, 0.8):
            obs.append(glathe("Band", [(2.2, y - 0.03), (2.29, y - 0.02), (2.3, y), (2.29, y + 0.02), (2.2, y + 0.03)],
                              deep, col, seg=128))
        for k in range(24):
            a = k * math.tau / 24
            obs.append(K.sphere("Rivet", 0.04, at=at(math.cos(a) * 2.44, 0.12, math.sin(a) * 2.44), m=deep, seg=6,
                                col=col))
        obs.append(glathe("Top", [(0, 1.0), (2.0, 1.0), (2.0, 1.04), (1.96, 1.06), (0, 1.06)], wood, col, seg=96))
        for r in (0.7, 1.45, 1.85):
            obs.append(gwire("Inlay", [(math.cos(t) * r, 1.062, math.sin(t) * r)
                                       for t in [math.tau * j / 64 for j in range(64)]], 0.025, brass, col, closed=True,
                             res=4, bevel_res=1))
        for k in range(12):
            a = k * math.tau / 12
            obs.append(gbox("Pip", (0.26, 0.02, 0.08), (math.cos(a) * 1.65, 1.065, math.sin(a) * 1.65), brass, col,
                            rot=(0, -a, 0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Cuckoo Chest's house
def cuckoo_house():
    woods = [wood_mat("House Board", WOOD, WOOD_DARK), wood_mat("House Board Pale", WOOD_PALE, WOOD)]
    trim = wood_mat("House Trim", (0.62, 0.38, 0.24), WOOD, grain=10.0)
    roof = mottled("House Roof", ROOF, (0.18, 0.38, 0.3), scale=6.0, rough=0.7, bump=0.2)
    cream = K.mat("House Face", CREAM, rough=0.5)
    ink = K.mat("House Ink", INK, rough=0.5)
    brass = brass_mat("House Brass")
    bird_m = K.mat("House Bird", (0.95, 0.5, 0.65), rough=0.5)
    beak = K.mat("House Beak", (1.0, 0.8, 0.2), rough=0.5)

    def gable(name, m, y0, y1, half_w, z0, z1, col):
        bm = bmesh.new()
        v = [bm.verts.new(at(x, y, z)) for (x, y) in ((-half_w, y0), (half_w, y0), (0, y1)) for z in (z0, z1)]
        bm.faces.new((v[0], v[2], v[4]))
        bm.faces.new((v[1], v[5], v[3]))
        bm.faces.new((v[0], v[1], v[3], v[2]))
        bm.faces.new((v[2], v[3], v[5], v[4]))
        bm.faces.new((v[4], v[5], v[1], v[0]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return K._obj(name, bm, m, False, col)

    def build(col, high):
        obs = [gable("Gable", woods[0], 1.6, 2.1, 0.8, -0.6, 0.6, col)]
        for s in (-1, 1):
            obs.append(gbox("Roof", (1.12, 0.1, 1.44), (s * 0.44, 1.86, 0), roof, col, bevel=0.02 if high else 0.0,
                            rot=(0, 0, -s * 0.58)))
        if not high:
            return obs + [gbox("House", (1.6, 1.6, 1.2), (0, 0.8, 0), woods[0], col)]
        rnd = random.Random(241)
        obs.append(gbox("Core", (1.54, 1.6, 1.14), (0, 0.8, 0), trim, col))
        for k in range(8):                                     # planks laid flat on all four sides
            y = 0.1 + k * 0.2
            m = rnd.choice(woods)
            obs.append(gbox("Plank", (1.58, 0.18, 0.03), (0, y, 0.585), m, col, bevel=0.008))
            obs.append(gbox("Plank", (0.03, 0.18, 1.18), (-0.785, y, 0), m, col, bevel=0.008))
            obs.append(gbox("Plank", (0.03, 0.18, 1.18), (0.785, y, 0), m, col, bevel=0.008))
            if not (0.1 < y < 0.8):                            # the front, kept flat round the door
                obs.append(gbox("Plank", (1.58, 0.18, 0.03), (0, y, -0.585), m, col, bevel=0.008))
            else:
                for s in (-1, 1):
                    obs.append(gbox("Plank", (0.44, 0.18, 0.03), (s * 0.57, y, -0.585), m, col, bevel=0.008))
        for (dx, dz) in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
            obs.append(gbox("Corner", (0.08, 1.6, 0.08), (dx * 0.78, 0.8, dz * 0.58), trim, col, bevel=0.015))
        for s in (-1, 1):                                      # a carved frame round the door
            obs.append(gbox("Door Jamb", (0.07, 0.72, 0.04), (s * 0.35, 0.45, -0.61), trim, col, bevel=0.01))
        obs.append(gbox("Door Head", (0.8, 0.08, 0.05), (0, 0.84, -0.61), trim, col, bevel=0.015))
        obs.append(gbox("Door Sill", (0.8, 0.06, 0.06), (0, 0.11, -0.61), trim, col, bevel=0.01))
        # the little clock face, with leaves carved round it
        obs.append(zlathe("Face", [(0, -0.03), (0.34, -0.03), (0.34, 0.0), (0, 0.0)], cream, col, pos=(0, 1.2, -0.6),
                          seg=48))
        obs.append(zlathe("Bezel", [(0.33, -0.02), (0.36, -0.05), (0.4, -0.05), (0.41, 0.0)], brass, col,
                          pos=(0, 1.2, -0.6), seg=48))
        for k in range(12):
            a = k * math.tau / 12
            obs.append(gbox("Tick", (0.02, 0.06, 0.01), (-math.sin(a) * 0.27, 1.2 + math.cos(a) * 0.27, -0.635), ink,
                            col, rot=(0, 0, a)))
        obs.append(gbox("Hour Hand", (0.03, 0.16, 0.01), (0.04, 1.26, -0.64), ink, col, rot=(0, 0, 0.6)))
        obs.append(gbox("Minute Hand", (0.02, 0.24, 0.01), (0, 1.3, -0.645), ink, col))
        for s in (-1, 1):
            for k in range(4):
                a = 0.6 + k * 0.5
                obs.append(K.sphere("Leaf", 0.07, at=at(s * math.cos(a) * 0.5, 1.2 - math.sin(a) * 0.45 + 0.25, -0.62),
                                    m=trim, seg=8, scale=(1.0, 0.4, 0.6), col=col))
        # shingles on the roof, a ridge and a little bird
        for s in (-1, 1):
            for row in range(5):
                t = (row + 0.5) / 5
                x = s * (0.02 + t * 0.92)
                y = 2.13 - t * 0.6
                for j in range(7):
                    z = -0.66 + (j + (0.5 if row % 2 else 0.0)) * 0.2
                    if abs(z) > 0.7:
                        continue
                    obs.append(gbox("Shingle", (0.24, 0.03, 0.19), (x, y + 0.02, z), roof, col, bevel=0.01,
                                    rot=(0, 0, -s * 0.58)))
        obs.append(grod("Ridge", (0, 2.17, -0.74), (0, 2.17, 0.74), 0.05, trim, col, seg=8))
        for s in (-1, 1):                                      # bargeboards on the front gable
            obs.append(gbox("Barge", (0.98, 0.07, 0.04), (s * 0.42, 1.85, -0.72), trim, col, bevel=0.01,
                            rot=(0, 0, -s * 0.58)))
        obs.append(K.sphere("Bird", 0.1, at=at(0, 2.3, 0.1), m=bird_m, seg=12, col=col))
        obs.append(K.sphere("Bird Head", 0.065, at=at(0, 2.38, -0.02), m=bird_m, seg=10, col=col))
        obs.append(gbox("Bird Beak", (0.04, 0.03, 0.08), (0, 2.38, -0.1), beak, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ a rail post
def rail_post():
    brass = brass_mat("Post Brass")
    prof = [(0, -0.5), (0.2, -0.5), (0.2, -0.42), (0.15, -0.38), (0.11, -0.22), (0.15, -0.02), (0.09, 0.2),
            (0.1, 0.32), (0.16, 0.36), (0.16, 0.42), (0.09, 0.45), (0, 0.46)]

    def build(col, high):
        if not high:
            return [glathe("Post", prof, brass, col, seg=12),
                    K.sphere("Ball", 0.12, at=at(0, 0.54, 0), m=brass, seg=8, col=col)]
        obs = [glathe("Post", prof, brass, col, seg=48, flutes=8, flute_depth=0.015, flute_z=(-0.2, 0.18)),
               K.sphere("Ball", 0.12, at=at(0, 0.54, 0), m=brass, seg=24, col=col)]
        obs.append(glathe("Ring", [(0.1, -0.24), (0.13, -0.23), (0.13, -0.19), (0.1, -0.18)],
                          K.mat("Post Deep", BRASS_DARK, rough=0.4, metal=0.85), col, seg=48))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao = {
    "tower_gear": (tower_gear, 1024, 0.04, 0.1, False),  # (its flat discs baked black with AO)
    "gear_wall": (gear_wall, 1024, 0.05, 0.12, True),
    "pendulum_frame": (pendulum_frame, 1024, 0.05, 0.12, True),
    "pendulum": (pendulum, 512, 0.04, 0.1, True),
    "cog_gate": (cog_gate, 2048, 0.06, 0.15, True),
    "tower_bay": (tower_bay, 2048, 0.08, 0.2, True),
    "tower_door": (tower_door, 2048, 0.08, 0.2, True),
    "big_clock": (big_clock, 2048, 0.06, 0.15, False),   # (its flat face baked black with AO)
    "tock_dais": (tock_dais, 1024, 0.04, 0.1, True),
    "cuckoo_house": (cuckoo_house, 1024, 0.03, 0.08, True),
    "rail_post": (rail_post, 256, 0.02, 0.05, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

# More of the Void, built the detailed way (tools/bake_kit.py; 19 Nov 2026, Hayden: "Work on baking more scenery",
# scenery batch twelve): the boardwalks round the lake and the dock and their piles, the posts Pip's
# lanterns hang from, the Mothership Pad, Rex's noticeboard by the fountain and the Hot Springs' cave mouths with the
# stones round their pools. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces tools/build_town.gd builds from shapes (boardwalk(), the Pip's Lanterns loop, the Mothership
# Pad, the Noticeboard, the Hot Springs), so the swap (scripts/detail_props.gd) puts each exactly where the old one was
# and every collision stays the game's. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is
# Godot's Y.
#   boardwalk      a 4 m length of deck 3 m wide (its top at 0.3, like the game's): planks across with gaps, grain
#                  and nail heads, an edge board each side and the bearers under it. The game lays as many as fit.
#   boardwalk_pile a pile (2 m, its top at the deck's top) with iron bands and a worn cap.
#   lantern_post   the post Pip's lanterns hang from: a turned post with an arm out to the side and a hook.
#   mothership_pad the pad's metal disc: panels with seams and rivets, grooves the game's glowing rings sit in, a
#                  bevelled rim with stripes and little lights.
#   noticeboard    Rex's noticeboard: carved posts, a framed cork board with pin holes and pins, a little shingled roof.
#   spring_cave    a cave mouth in the cliff: a ring of lumpy rock with moss, glints of crystal and drips hanging in
#                  the mouth, open right through (the game digs the cave behind it).
#   spring_rim     the stones round a spring's pool.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_void_5.py "<out>.glb" <kind> [--preview]
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["boardwalk", "boardwalk_pile", "lantern_post", "mothership_pad", "noticeboard",
         "spring_cave", "spring_rim"]
KIND = next((a for a in sys.argv if a in KINDS), "boardwalk")
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


# The game's colours after the alien theme (as the built town has them).
BW_WOOD = (0.23, 0.57, 0.53)
BW_POST = (0.15, 0.29, 0.41)
PAD_METAL = (0.61, 0.52, 0.71)
PAD_BLUE = (0.5, 0.88, 1.0)
NB_WOOD = (0.2, 0.31, 0.55)
NB_CORK = (0.2, 0.55, 0.51)
CAVE_DARK = (0.11, 0.06, 0.08)
CAVE_ROCK = (0.37, 0.34, 0.43)
LAMP_BRASS = (0.85, 0.66, 0.32)


# ================================================================ boardwalk
# A 4 m length (along z, -2..2) of a boardwalk 3 m wide (x), from the water's 0 up to its top at 0.3 like the game's
# box. The game stretches each length a little so whole ones fit, and squeezes x for the narrower dock.
def boardwalk():
    plank = K.mat("Board", BW_WOOD, rough=0.85, grain=(9.0, 0.3), bump=0.15)
    edge = K.mat("Board Edge", (0.19, 0.48, 0.45), rough=0.85, grain=(9.0, 0.25))
    under = K.mat("Board Under", BW_POST, rough=0.9, grain=(7.0, 0.2))
    nail = K.mat("Nail", (0.3, 0.3, 0.34), rough=0.4, metal=0.8)

    def build(col, high):
        obs = []
        if not high:
            obs.append(gbox("Deck", (3.0, 0.3, 4.0), (0, 0.15, 0), plank, col))
            return obs
        n = 20
        w = 4.0 / n
        for i in range(n):
            z = -2.0 + w * (i + 0.5)
            sag = 0.006 * noise.noise(Vector((i * 0.7, 0.3, 0.1)))
            ln = 2.8 + 0.08 * noise.noise(Vector((i * 1.3, 2.0, 0.0)))
            obs.append(gbox("Plank", (ln, 0.055, w - 0.022), (0.04 * noise.noise(Vector((i, 5.0, 1.0))),
                            0.272 + sag, z), plank, col, bevel=0.008, rot=(0, 0.01 * noise.noise(Vector((i, 9, 2))), 0)))
            for x in (-1.25, -0.42, 0.42, 1.25):
                for dz in (-0.04, 0.04):
                    obs.append(K.cyl("Nail", 0.011, 0.01, at=at(x, 0.3, z + dz), seg=6, m=nail, col=col))
        for s in (-1, 1):
            obs.append(gbox("Edge Board", (0.12, 0.26, 4.0), (s * 1.44, 0.17, 0), edge, col, bevel=0.012))
        for x in (-1.0, 0.0, 1.0):
            obs.append(gbox("Joist", (0.12, 0.2, 4.0), (x, 0.14, 0), under, col, bevel=0.01))
        for z in (-1.5, 0.5):
            obs.append(gbox("Bearer", (3.0, 0.14, 0.16), (0, 0.07, z), under, col, bevel=0.01))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ boardwalk pile
# A pile at the deck's side (the game's is 2 m from -1.7 to 0.3), its top just over the deck.
def boardwalk_pile():
    wood = K.mat("Pile", BW_POST, rough=0.9, grain=(5.0, 0.3), bump=0.25)
    iron = mottled("Pile Band", (0.3, 0.3, 0.36), (0.42, 0.32, 0.3), scale=12.0, rough=0.5, metal=0.7)
    slime = K.mat("Pile Weed", (0.25, 0.55, 0.35), rough=0.9, bump=0.3)

    def build(col, high):
        obs = []
        seg = 16 if high else 8
        if high:
            obs.append(K.lathe("Pile", [(0.0, -1.7), (0.125, -1.7), (0.12, -0.5), (0.122, 0.2), (0.11, 0.31),
                                        (0.0, 0.32)], seg=seg, m=wood, flutes=9, flute_depth=0.008,
                               flute_z=(-1.6, 0.2), col=col))
            for y in (-0.15, -0.9):
                obs.append(K.cyl("Band", 0.132, 0.07, at=at(0, y, 0), seg=seg, m=iron, col=col))
            obs.append(K.cyl("Weed", 0.13, 0.35, at=at(0, -1.45, 0), seg=seg, m=slime, col=col, r2=0.124))
        else:
            obs.append(K.cyl("Pile", 0.13, 2.02, at=at(0, -0.69, 0), seg=seg, m=wood, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ lantern post
# The post Pip's lanterns hang from: it stands at the origin (the deck's top is at 0.3) and its arm reaches out along
# +x to a hook 0.25 out, over the lantern (the game's hangs at 2.2, 0.2 to 0.26 across, so its top is under 2.46).
def lantern_post():
    wood = K.mat("Lantern Post", BW_POST, rough=0.8, grain=(6.0, 0.25))
    iron = mottled("Lantern Iron", (0.22, 0.2, 0.3), (0.32, 0.28, 0.4), scale=10.0, rough=0.45, metal=0.8)
    gold = K.mat("Lantern Gold", GOLD, rough=0.35, metal=0.8)

    def build(col, high):
        obs = []
        seg = 16 if high else 8
        if high:
            obs.append(K.lathe("Post", [(0.0, 0.3), (0.08, 0.3), (0.075, 0.45), (0.06, 0.55), (0.055, 2.5),
                                        (0.065, 2.56), (0.065, 2.62), (0.0, 2.62)], seg=seg, m=wood, sides=8,
                               col=col))
            obs.append(K.cyl("Ring", 0.07, 0.04, at=at(0, 0.5, 0), seg=seg, m=iron, col=col))
            obs.append(K.cyl("Ring", 0.068, 0.04, at=at(0, 2.4, 0), seg=seg, m=iron, col=col))
            obs.append(K.lathe("Finial", [(0.0, 2.62), (0.05, 2.62), (0.035, 2.68), (0.045, 2.72), (0.0, 2.8)],
                               seg=seg, m=gold, at=(0, 0, 0), col=col))
            obs.append(gbox("Arm", (0.34, 0.045, 0.045), (0.17, 2.55, 0), iron, col, bevel=0.008))
            obs.append(K.wire("Brace", [at(0.05, 2.32, 0), at(0.08, 2.44, 0), at(0.16, 2.52, 0), at(0.24, 2.53, 0)],
                              0.012, m=iron, res=8, bevel_res=2, col=col))
            obs.append(K.sphere("Arm Tip", 0.03, at=at(0.34, 2.55, 0), m=gold, seg=10, col=col))
            obs.append(K.wire("Hook", [at(0.25, 2.55, 0), at(0.26, 2.51, 0), at(0.25, 2.49, 0), at(0.23, 2.5, 0)],
                              0.007, m=iron, res=6, bevel_res=2, col=col))
        else:
            obs.append(K.cyl("Post", 0.075, 2.32, at=at(0, 1.46, 0), seg=seg, m=wood, col=col))
            obs.append(gbox("Arm", (0.36, 0.05, 0.05), (0.17, 2.55, 0), iron, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ mothership pad
# The pad's metal disc: 4.0 across the top at 0.1, 4.3 at the bottom at -0.3 (the game's cylinder and collision).
# The game's three glowing rings lie in it at 0.11, round 1.125, 2.225 and 3.325.
def mothership_pad():
    metal = mottled("Pad Plate", PAD_METAL, (0.55, 0.47, 0.66), scale=3.0, rough=0.35, metal=0.6, bump=0.04)
    dark = K.mat("Pad Seam", (0.25, 0.2, 0.33), rough=0.5, metal=0.6)
    rivet = K.mat("Pad Rivet", (0.82, 0.8, 0.9), rough=0.3, metal=0.9)
    stripe = K.mat("Pad Stripe", (1.0, 0.82, 0.3), rough=0.5, metal=0.2)
    light = K.mat("Pad Light", PAD_BLUE, rough=0.2)
    RINGS = (1.125, 2.225, 3.325)

    def build(col, high):
        obs = []
        if not high:
            obs.append(K.lathe("Pad", [(0.0, -0.3), (4.3, -0.3), (4.0, 0.1), (0.0, 0.1)], seg=40, m=metal, col=col))
            return obs
        prof = [(0.0, 0.1)]
        for rr in RINGS:                              # a shallow channel each glowing ring lies in
            prof += [(rr - 0.2, 0.1), (rr - 0.16, 0.075), (rr + 0.16, 0.075), (rr + 0.2, 0.1)]
        prof += [(3.85, 0.1), (3.95, 0.09), (4.0, 0.07), (4.3, -0.3), (0.0, -0.3)]
        obs.append(K.lathe("Pad", prof, seg=96, m=metal, col=col))
        obs.append(K.cyl("Hub", 0.5, 0.03, at=at(0, 0.11, 0), seg=40, m=dark, col=col))
        obs.append(K.cyl("Hub Plate", 0.42, 0.02, at=at(0, 0.125, 0), seg=40, m=metal, col=col))
        # panel seams running out between the rings, and rivets along them
        for k in range(12):
            a = k / 12 * math.tau
            for r0, r1 in ((0.55, 0.9), (1.35, 2.0), (2.45, 3.1), (3.55, 3.85)):
                mid = (r0 + r1) / 2
                obs.append(gbox("Seam", (r1 - r0, 0.01, 0.025), (math.cos(a) * mid, 0.1, math.sin(a) * mid), dark,
                                col, rot=(0, -a, 0)))
                for rr in (r0 + 0.06, r1 - 0.06):
                    for s in (-1, 1):
                        b = a + s * 0.05 / rr
                        obs.append(K.sphere("Rivet", 0.018, at=at(math.cos(b) * rr, 0.1, math.sin(b) * rr), m=rivet,
                                            seg=8, col=col, scale=(1, 1, 0.5)))
        # stripes and little lights round the slanted rim
        for k in range(32):
            a0 = k / 32 * math.tau
            a1 = (k + 1) / 32 * math.tau
            m = stripe if k % 2 == 0 else dark
            vs = []
            for r, y in ((4.0 + 0.012, 0.07), (4.3 + 0.012, -0.3)):
                for a in (a0, a1):
                    vs.append(at(math.cos(a) * r, y, math.sin(a) * r))
            obs.append(mesh_from("Rim Stripe", [vs[0], vs[1], vs[3], vs[2]], [[0, 1, 2, 3]], m, col))
        for k in range(16):
            a = k / 16 * math.tau
            obs.append(K.sphere("Rim Light", 0.05, at=at(math.cos(a) * 3.92, 0.1, math.sin(a) * 3.92), m=light,
                                seg=10, col=col, scale=(1, 1, 0.45)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ noticeboard
# Rex's noticeboard by the fountain (its front, the side the notes are on, towards +z): posts at x +-0.95 from the
# ground to 2.4, the cork 2.1 x 1.3 round y 1.55 with its front at 0.05 (the game's notes sit just over it), the
# little roof 2.3 x 0.1 x 0.4 round (0, 2.3, 0.05) tipped 0.2 forward.
def noticeboard():
    wood = K.mat("Notice Wood", NB_WOOD, rough=0.8, grain=(7.0, 0.3))
    wood_dk = K.mat("Notice Trim", (0.15, 0.22, 0.42), rough=0.8, grain=(7.0, 0.25))
    cork = K.mat("Notice Cork", NB_CORK, rough=0.95, pits=0.5, bump=0.35)
    shingle = K.mat("Notice Shingle", (0.62, 0.5, 0.95), rough=0.8, bump=0.15)
    gold = K.mat("Notice Gold", GOLD, rough=0.35, metal=0.8)
    pins = [K.mat("Pin %d" % i, c, rough=0.3) for i, c in enumerate((PINK, TEAL, GOLD, (1.0, 0.4, 0.3)))]

    def build(col, high):
        obs = []
        seg = 12 if high else 8
        for px in (-0.95, 0.95):
            if high:
                obs.append(K.lathe("Post", [(0.0, 0.0), (0.1, 0.0), (0.1, 0.12), (0.075, 0.18), (0.068, 2.25),
                                            (0.08, 2.3), (0.08, 2.36), (0.0, 2.4)], seg=seg, m=wood, sides=8,
                                   at=(px, 0, 0), col=col))
            else:
                obs.append(K.cyl("Post", 0.075, 2.4, at=at(px, 1.2, 0), seg=seg, m=wood, col=col))
        obs.append(gbox("Cork", (2.1, 1.3, 0.1), (0, 1.55, 0), cork, col))
        if high:
            for y in (0.88, 2.22):
                obs.append(gbox("Frame", (2.2, 0.07, 0.13), (0, y, 0.005), wood_dk, col, bevel=0.012))
            for x in (-1.07, 1.07):
                obs.append(gbox("Frame", (0.07, 1.4, 0.13), (x, 1.55, 0.005), wood_dk, col, bevel=0.012))
            for x in (-1.07, 1.07):
                for y in (0.88, 2.22):
                    obs.append(K.sphere("Corner Stud", 0.03, at=at(x, y, 0.075), m=gold, seg=10, col=col))
            # spare pins stuck about the cork, clear of where the game's three notes are
            for i, (x, y) in enumerate(((0.1, 2.0), (0.3, 1.1), (-0.2, 1.05), (0.4, 1.95), (-0.2, 1.6),
                                        (0.15, 1.45))):
                obs.append(K.sphere("Pin", 0.018, at=at(x, y, 0.07), m=pins[i % 4], seg=8, col=col))
                obs.append(grod("Pin Shaft", (x, y, 0.05), (x, y, 0.07), 0.003, gold, col, seg=4))
            # a ledge under the board
            obs.append(gbox("Ledge", (2.0, 0.04, 0.14), (0, 0.86, 0.06), wood, col, bevel=0.01))
        # the roof: shingles in rows on a board, tipped forward
        th = 0.2
        obs.append(gbox("Roof", (2.3, 0.06, 0.4), (0, 2.3, 0.05), wood_dk, col, rot=(th, 0, 0)))
        if high:
            for row in range(3):
                dz = -0.14 + row * 0.13
                for i in range(12):
                    x = -1.1 + (i + 0.5 * (row % 2)) * 0.19
                    if abs(x) > 1.12:
                        continue
                    y = 2.34 + row * -0.001
                    yy = 2.3 + 0.045 * math.cos(th) - dz * math.sin(th)
                    zz = 0.05 + 0.045 * math.sin(th) + dz * math.cos(th)
                    obs.append(gbox("Shingle", (0.18, 0.025, 0.16), (x, yy, zz), shingle, col, bevel=0.008,
                                    rot=(th + 0.06, 0, 0)))
            obs.append(gbox("Ridge", (2.34, 0.06, 0.06), (0, 2.37, -0.15), wood, col, bevel=0.012, rot=(th, 0, 0)))
        else:
            obs.append(gbox("Shingles", (2.3, 0.05, 0.42), (0, 2.35, 0.05), shingle, col, rot=(th, 0, 0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ spring cave
# A Hot Springs cave mouth set in the plateau's cliff, its mouth towards +z: the game's rock was a 3.2 m disc 2.5 deep
# round (0, 1, 0) and a dark 2.4 m disc over it. This is a lumpy ring of rock, open right through, so you can walk
# into the tunnel and grotto the game digs behind it.
def _rock_ring(name, m, col, seg, rows, high):
    """A lumpy ring of rock round Godot's z axis through (0, 1, 0): the inside of the mouth to the outer face."""
    prof = [(2.3, 0.3), (2.36, 0.7), (2.42, 1.05), (2.62, 1.38), (2.95, 1.45), (3.22, 1.2), (3.32, 0.4),
            (3.36, -1.3)]
    pts = []
    for i in range(rows + 1):                      # resample the profile evenly
        t = i / rows * (len(prof) - 1)
        j = min(int(t), len(prof) - 2)
        f = t - j
        pts.append((lerp(prof[j][0], prof[j + 1][0], f), lerp(prof[j][1], prof[j + 1][1], f)))
    bm = bmesh.new()
    grid = []
    for i, (r, z) in enumerate(pts):
        ring = []
        for k in range(seg):
            a = k / seg * math.tau
            d = Vector((math.cos(a), math.sin(a), z * 0.6))
            bump = 0.28 * noise.noise(d * 1.3) + (0.1 * noise.noise(d * 4.0) if high else 0.0)
            if i == 0 or i == rows:
                bump *= 0.5
            rr = r + bump * (1.0 if r > 2.6 else 0.6)
            ring.append(bm.verts.new(at(math.cos(a) * rr, 1.0 + math.sin(a) * rr, z + 0.15 * bump)))
        grid.append(ring)
    for i in range(rows):
        for k in range(seg):
            bm.faces.new((grid[i][k], grid[i][(k + 1) % seg], grid[i + 1][(k + 1) % seg], grid[i + 1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, True, col)


def _hollow(name, m, col, seg, r=2.32, back=0.35, front=1.25):
    """The inside of the cave mouth: a dark tube seen from inside (open at the front), a back wall and a floor just
    over the ground, so whatever ground runs through the cliff behind never shows in the mouth."""
    bm = bmesh.new()
    rings = []
    for z in (back, front):
        rings.append([bm.verts.new(at(math.cos(k / seg * math.tau) * r, 1.0 + math.sin(k / seg * math.tau) * r, z))
                      for k in range(seg)])
    for k in range(seg):
        a, b = rings[0][k], rings[0][(k + 1) % seg]
        c, d = rings[1][(k + 1) % seg], rings[1][k]
        bm.faces.new((d, c, b, a))                 # wound to face in, towards the tube's middle
    for flip in (False, True):                     # the back wall, both ways round, so it shows from anywhere
        cap = [bm.verts.new(v.co.copy()) for v in rings[0]]
        bm.faces.new(cap if flip else list(reversed(cap)))
    ob = K._obj(name, bm, m, True, col)
    bm2 = bmesh.new()
    w = math.sqrt(r * r - 1.0) - 0.05             # where the floor (at y 0.02) meets the tube's wall
    for v in ((-w, back), (w, back), (w, front), (-w, front)):
        bm2.verts.new(at(v[0], 0.02, v[1]))
    bm2.faces.new(list(bm2.verts))
    bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
    for f in bm2.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return [ob, K._obj(name + " Floor", bm2, m, False, col)]


def spring_cave():
    rock = mottled("Cave Stone", CAVE_ROCK, (0.3, 0.27, 0.36), scale=2.5, rough=0.95, bump=0.4)
    moss = K.mat("Cave Moss", (0.3, 0.62, 0.4), rough=0.95, bump=0.5)
    crystal = K.mat("Cave Crystal", (1.0, 0.6, 0.35), rough=0.2, metal=0.1)
    wet = K.mat("Cave Drip", (0.22, 0.18, 0.26), rough=0.3)

    def build(col, high):
        obs = [_rock_ring("Rock", rock, col, 48 if high else 20, 14 if high else 6, high)]
        # (20 Nov 2026) no hollow any more: the mouth is open right through, and the game digs a tunnel and a warm
        # grotto into the cliff behind it (scripts/spring_grottos.gd). Hayden: "The hot springs doorways dont
        # actually go anywhere".
        if high:
            for k in range(9):                                  # icicles of rock hanging in the mouth's top
                a = math.pi / 2 + (k - 4) * 0.17
                r = 2.3
                x, y = math.cos(a) * r, 1.0 + math.sin(a) * r
                ln = 0.25 + 0.2 * abs(noise.noise(Vector((k * 1.7, 0.4, 0.2))))
                obs.append(K.cyl("Drip", 0.07, ln, at=at(x, y - ln / 2, 1.1 - 0.05 * (k % 3)), seg=8, m=wet, col=col,
                                 r2=0.005))
            for k in range(14):                                 # moss along the top and down the sides
                a = math.pi * (0.1 + 0.8 * k / 13)
                r = 3.05 + 0.1 * noise.noise(Vector((k, 1.0, 3.0)))
                obs.append(blob("Moss", 0.32, (math.cos(a) * r, 1.0 + math.sin(a) * r, 0.9), moss, col, seed=k,
                                seg=10, lump=0.4, squash=(1.0, 0.6, 0.8)))
            for k in range(6):                                  # warm crystals poking out of the rock
                a = (0.05 + 0.15 * k) * math.pi if k < 3 else (0.95 - 0.15 * (k - 3)) * math.pi
                r = 2.55
                x, y = math.cos(a) * r, 1.0 + math.sin(a) * r
                ob = K.cyl("Crystal", 0.08, 0.35, at=at(x, y, 1.25), seg=6, m=crystal, col=col, r2=0.01)
                ob.rotation_euler = (0.4 + 0.2 * k, 0.3 * (k % 2 - 0.5), a - math.pi / 2)
                obs.append(ob)
            for k in range(7):                                  # boulders at the foot
                x = -3.4 + k * 1.15
                if abs(x) < 2.0:
                    continue
                obs.append(blob("Boulder", 0.45, (x, 0.1, 1.2 + 0.2 * (k % 2)), rock, col, seed=10 + k, seg=12,
                                lump=0.35, squash=(1.0, 0.7, 0.9)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ spring rim
# The stones round a Hot Spring's pool (the game's water disc is 2.2 across, its top at 0.125): a ring of rounded
# stones just outside it, nothing solid.
def spring_rim():
    stone = mottled("Rim Stone", CAVE_ROCK, (0.45, 0.42, 0.52), scale=4.0, rough=0.85, bump=0.3)
    moss = K.mat("Rim Moss", (0.3, 0.62, 0.4), rough=0.95, bump=0.4)

    def build(col, high):
        obs = []
        n = 18
        for k in range(n):
            a = (k + 0.3 * noise.noise(Vector((k, 0.5, 0.5)))) / n * math.tau
            r = 2.38 + 0.08 * noise.noise(Vector((k * 0.9, 2.0, 1.0)))
            s = 0.3 + 0.08 * noise.noise(Vector((k * 1.3, 4.0, 2.0)))
            obs.append(blob("Stone", s, (math.cos(a) * r, 0.05, math.sin(a) * r), stone, col, seed=k,
                            seg=12 if high else 6, lump=0.3 if high else 0.2, squash=(1.2, 0.55, 0.9)))
            ob = obs[-1]
            ob.rotation_euler = (0, 0, -a)
            if high and k % 3 == 0:
                obs.append(blob("Moss", s * 0.5, (math.cos(a) * r, 0.05 + s * 0.45, math.sin(a) * r), moss, col,
                                seed=50 + k, seg=8, lump=0.4, squash=(1.2, 0.35, 1.0)))
        return obs

    return build(HIGH, True), build(LOW, False)


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


fn, size, ext, ray = {
    "boardwalk": (boardwalk, 1024, 0.05, 0.12),
    "boardwalk_pile": (boardwalk_pile, 256, 0.02, 0.05),
    "lantern_post": (lantern_post, 256, 0.03, 0.06),
    "mothership_pad": (mothership_pad, 1024, 0.04, 0.08),
    "noticeboard": (noticeboard, 512, 0.04, 0.08),
    "spring_cave": (spring_cave, 1024, 0.25, 0.5),
    "spring_rim": (spring_rim, 512, 0.06, 0.12),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

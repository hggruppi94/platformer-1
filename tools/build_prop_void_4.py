# Batch ten of the Void's scenery, built the detailed way (tools/bake_kit.py; 18 Nov 2026, Hayden: "Keep going"): the
# Tree House, Rex and Dash's lab, the deep pools' stone (the Wishing Well and the portal worlds' pools) and the Remnant
# veins. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces the game builds from shapes (tools/build_town.gd _tree_house, scripts/lab.gd _build,
# scripts/sunken_secrets.gd build_pool, scripts/remnants.gd vein_model), so the swap (scripts/detail_props.gd) puts
# each exactly where the old one was. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   tree_house     the trunk with bark ridges, roots and branches, the eleven spiral steps (boards, bearers, nails) on
#                  their posts, the planked deck on joists and braces, the railing with its gap for the steps, and the
#                  little house: siding, corner boards, a planked door, shuttered windows, a shingled roof. Its leaves,
#                  zipline and sign stay the game's.
#   lab_shed       the lab's floor (tiles), walls (panels, rivets, portholes), striped front posts, ribbed roof, the
#                  sign board's gold frame (its words are the game's, at z 4.66) and the radar dish.
#   lab_kit        the Swap-o-Tron's pod bases and caps, the cables, the console (its buttons and lever are the
#                  game's), Dash's workbench (his beakers are the game's), the chalkboard's frame (its words at z -4.08)
#                  and Hound Hero's gold frame (the picture is the game's).
#   pool_wall      a deep pool's wall: courses of stone blocks, wet lower down. Baked pale: the game tints it.
#   pool_lip       the coping round its top, with a bead along the inside. Baked pale too.
#   vein_rock      a Remnant vein's glassy obsidian lumps, with green flecks.
#   vein_crystals  its nine glowing crystals and little side crystals.
#   vein_stubs     the snapped-off stubs left after harvesting.
# Colours are the game's own (sRGB). Collisions stay the game's.
#
#   python tools/build_prop_void_4.py "<out>.glb" <kind> [--preview]
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["tree_house", "lab_shed", "lab_kit", "pool_wall", "pool_lip", "vein_rock", "vein_crystals", "vein_stubs"]
KIND = next((a for a in sys.argv if a in KINDS), "vein_rock")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")


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



def mesh_obj(name, bm, m, col, smooth=True):
    return K._obj(name, bm, m, smooth, col)


def lumpy(name, r, centre, squash, seed, m, col, subdiv=3, amp=0.18):
    """A rough rock: an icosphere pushed in and out by noise (Godot centre), flattened by squash."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in bm.verts:
        n = v.co.normalized()
        d = noise.noise(n * 1.6 + off) * amp + noise.noise(n * 4.0 + off) * amp * 0.35
        v.co = n * r * (1.0 + d)
        v.co.z *= squash
    ob = mesh_obj(name, bm, m, col, smooth=subdiv > 1)
    ob.location = at(*centre)
    return ob


def ring_y(name, r_in, r_out, y0, y1, m, col, seg=48, a0=0.0, a1=math.tau):
    """A ring (or arc) round Godot's Y between two radii and two heights: a wall, a kerb."""
    full = abs(a1 - a0 - math.tau) < 1e-6
    n = seg if full else seg + 1
    bm = bmesh.new()
    rings = []
    for k in range(n):
        a = a0 + (a1 - a0) * k / seg
        c, s = math.cos(a), math.sin(a)
        rings.append([bm.verts.new(at(c * r, y, s * r)) for (r, y) in
                      ((r_in, y0), (r_out, y0), (r_out, y1), (r_in, y1))])
    for k in range(seg):
        a, b = rings[k], rings[(k + 1) % n]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if not full:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, m, col, smooth=False)


def gable(name, cx, cz, w, h, d, y0, m, col):
    """The tree house's roof: a prism with its ridge along Godot's Z (PrismMesh size (w, h, d) based at y0)."""
    v = []
    for z in (cz - d / 2, cz + d / 2):
        v += [at(cx - w / 2, y0, z), at(cx + w / 2, y0, z), at(cx, y0 + h, z)]
    return mesh_from(name, v, [[0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]], m, col)


# ================================================================ the Tree House
BARK = (0.148, 0.173, 0.386)
TH_WOOD = (0.247, 0.644, 0.6)
TH_WALL = (0.285, 0.782, 0.727)
TH_ROOF = (0.782, 0.236, 0.465)
DECK_Y = 7.0
STEP_R = 5.6
GAP_A = 4 * math.tau / 14
CAB = (-1.2, -1.2)              # the little house's middle (x, z); its walls are 3.6 x 2.6 x 3.0, from the deck up


def tree_house():
    bark = mottled("Bark", BARK, (0.09, 0.1, 0.25), scale=3.0, rough=0.9, bump=0.6)
    wood = K.mat("Plank", TH_WOOD, rough=0.85, grain=(8.0, 0.25), bump=0.2)
    wood_dk = K.mat("Plank Dark", (0.17, 0.46, 0.44), rough=0.9, grain=(8.0, 0.2))
    wall = K.mat("Siding", TH_WALL, rough=0.85, grain=(10.0, 0.18), bump=0.15)
    roof = mottled("Shingle", TH_ROOF, (0.62, 0.17, 0.37), scale=9.0, rough=0.8, bump=0.25)
    trim = K.mat("Trim", (0.95, 0.92, 1.0), rough=0.6)
    glass = K.mat("Window", (0.55, 0.85, 1.0), rough=0.15, emit=0.35, emit_rgb=(1.0, 0.85, 0.5))
    iron = K.mat("Iron", (0.25, 0.22, 0.3), rough=0.5, metal=0.7)

    def build(col, high):
        obs = []
        seg = 40 if high else 12
        prof = [(1.75, 0.0), (1.6, 0.4), (1.45, 2.0), (1.3, 6.0), (1.2, 10.0), (1.1, 14.0)]
        obs.append(K.lathe("Trunk", prof, seg=seg, m=bark, col=col, flutes=16 if high else 0, flute_depth=0.07,
                           flute_z=(0.2, 13.8)))
        # roots spreading out over the ground, and branches up into the leaves
        for k in range(7):
            a = k / 7 * math.tau + 0.3
            c, s = math.cos(a), math.sin(a)
            obs.append(rod("Root", at(c * 1.2, 0.9, s * 1.2), at(c * 2.9, -0.15, s * 2.9), 0.42, bark, col,
                           seg=10 if high else 6, r2=0.12))
        for k in range(5):
            a = k * 1.3
            c, s = math.cos(a), math.sin(a)
            obs.append(rod("Branch", at(c * 0.6, 11.0 + (k % 2), s * 0.6), at(c * 3.3, 14.0 + (k % 2) * 1.2, s * 3.3),
                           0.45, bark, col, seg=10 if high else 6, r2=0.18))
        if high:
            # knots and burls on the trunk
            for k in range(9):
                a = k * 2.4
                y = 1.5 + k * 1.3
                r = 1.55 - y * 0.032
                obs.append(K.sphere("Burl", 0.22, at=at(math.cos(a) * r, y, math.sin(a) * r), m=bark, seg=10,
                                    scale=(1, 1, 1.4), col=col))
        # the steps spiralling up, each on a post
        for k in range(11):
            a = GAP_A - (10 - k) * 0.52
            y = 0.55 + k * (DECK_Y + 0.075 - 0.55) / 10
            px, pz = math.cos(a) * STEP_R, math.sin(a) * STEP_R
            if high:
                for i in range(4):                     # four boards across, with little gaps
                    t = -0.525 + i * 0.35
                    obs.append(gbox("Step Board", (2.2, 0.1, 0.32), (px - math.sin(a) * t, y + 0.075, pz + math.cos(a) * t),
                                    wood, col, bevel=0.02, rot=(0, -a, 0)))
                for t in (-0.55, 0.55):               # and two bearers under them
                    obs.append(gbox("Bearer", (2.1, 0.15, 0.12), (px - math.sin(a) * t, y - 0.05, pz + math.cos(a) * t),
                                    wood_dk, col, rot=(0, -a, 0)))
                for i in range(4):
                    for e in (-0.9, 0.9):
                        t = -0.525 + i * 0.35
                        obs.append(K.cyl("Nail", 0.022, 0.02, at=at(px + math.cos(a) * e - math.sin(a) * t, y + 0.128,
                                                                    pz + math.sin(a) * e + math.cos(a) * t), seg=8, m=iron, col=col))
            else:
                obs.append(gbox("Step", (2.2, 0.25, 1.4), (px, y, pz), wood, col, rot=(0, -a, 0)))
            if k > 0:
                obs.append(rod("Post", at(px, 0, pz), at(px, y - 0.1, pz), 0.1, wood_dk if high else wood, col,
                               seg=10 if high else 6))
        # the deck: boards across, a rim band, joists and braces under it
        if high:
            z = -4.35
            while z < 4.4:
                L = 2 * math.sqrt(max(4.45 ** 2 - z * z, 0.01))
                obs.append(gbox("Deck Board", (L, 0.1, 0.27), (0, DECK_Y + 0.15, z), wood, col, bevel=0.015))
                z += 0.3
            obs.append(ring_y("Deck Rim", 4.3, 4.5, DECK_Y - 0.2, DECK_Y + 0.12, wood_dk, col, seg=64))
            for x in (-3.0, -1.0, 1.0, 3.0):
                L = 2 * math.sqrt(4.3 ** 2 - x * x)
                obs.append(gbox("Joist", (0.18, 0.22, L), (x, DECK_Y - 0.1, 0), wood_dk, col))
            for k in range(6):
                a = k / 6 * math.tau + 0.4
                c, s = math.cos(a), math.sin(a)
                obs.append(rod("Brace", at(c * 1.3, DECK_Y - 2.4, s * 1.3), at(c * 3.6, DECK_Y - 0.2, s * 3.6), 0.11,
                               wood_dk, col, seg=8))
        else:
            obs.append(K.cyl("Deck", 4.5, 0.4, at=at(0, DECK_Y, 0), seg=24, m=wood, col=col))
        # the railing: thirteen posts, with a top rail and a middle one round all but the gap the steps arrive at
        posts = [k for k in range(14) if k != 4]
        for k in posts:
            a = k * math.tau / 14
            c, s = math.cos(a), math.sin(a)
            if high:
                obs.append(gbox("Rail Post", (0.12, 1.0, 0.12), (c * 4.3, DECK_Y + 0.6, s * 4.3), wood, col, bevel=0.02,
                                rot=(0, -a, 0)))
                obs.append(K.sphere("Post Cap", 0.09, at=at(c * 4.3, DECK_Y + 1.13, s * 4.3), m=wood, seg=10, col=col))
            else:
                obs.append(gbox("Rail Post", (0.12, 1.0, 0.12), (c * 4.3, DECK_Y + 0.6, s * 4.3), wood, col, rot=(0, -a, 0)))
        a0, a1 = 5 * math.tau / 14, (3 + 14) * math.tau / 14
        for y, h in ((DECK_Y + 1.05, 0.08), (DECK_Y + 0.6, 0.06)):
            obs.append(ring_y("Rail", 4.24, 4.36, y - h, y + h * (1 if high else 1), wood, col,
                              seg=96 if high else 24, a0=a0, a1=a1))
        if high:                                     # balusters between the posts
            for k in posts:
                for i in range(1, 4):
                    a = (k + i / 4) * math.tau / 14
                    if 3 * math.tau / 14 < a < 5 * math.tau / 14:
                        continue
                    obs.append(gbox("Baluster", (0.05, 0.42, 0.05), (math.cos(a) * 4.3, DECK_Y + 0.33, math.sin(a) * 4.3),
                                    wood_dk, col))
        # the little house
        cx, cz = CAB
        y0 = DECK_Y + 0.2
        if high:
            # boards running round it, each overlapping the one under
            for i in range(10):
                y = y0 + 0.13 + i * 0.26
                for (w, d, ox, oz, r) in ((3.66, 0.08, 0, 1.5, 0), (3.66, 0.08, 0, -1.5, 0),
                                          (3.06, 0.08, 1.8, 0, math.pi / 2), (3.06, 0.08, -1.8, 0, math.pi / 2)):
                    obs.append(gbox("Siding", (w, 0.27, d), (cx + ox, y, cz + oz), wall, col, bevel=0.01,
                                    rot=(0.08 if oz > 0 else (-0.08 if oz < 0 else 0), r, 0)))
            obs.append(gbox("Siding Core", (3.5, 2.6, 2.9), (cx, y0 + 1.3, cz), wall, col))
            for sx in (-1, 1):
                for sz in (-1, 1):
                    obs.append(gbox("Corner", (0.16, 2.66, 0.16), (cx + sx * 1.8, y0 + 1.33, cz + sz * 1.5), trim, col,
                                    bevel=0.02))
            # the door on the front (towards the steps), clear of the trunk
            dx = cx - 0.95
            obs.append(gbox("Door", (0.9, 1.8, 0.06), (dx, y0 + 0.9, cz + 1.56), wood_dk, col, bevel=0.01))
            for i in range(3):
                obs.append(gbox("Door Plank Line", (0.012, 1.7, 0.01), (dx - 0.3 + i * 0.3, y0 + 0.9, cz + 1.595), iron, col))
            for y in (0.4, 1.4):
                obs.append(gbox("Hinge", (0.5, 0.06, 0.02), (dx - 0.2, y0 + y, cz + 1.6), iron, col))
            obs.append(K.sphere("Knob", 0.05, at=at(dx + 0.3, y0 + 0.9, cz + 1.62), m=iron, seg=10, col=col))
            for (w, h, x, y) in ((1.04, 0.08, dx, y0 + 1.84), (0.08, 1.9, dx - 0.5, y0 + 0.95), (0.08, 1.9, dx + 0.5, y0 + 0.95)):
                obs.append(gbox("Door Frame", (w, h, 0.08), (x, y, cz + 1.57), trim, col))
            # square windows with shutters on the sides and back (the trunk comes out through the front, by the door)
            for (wx, wz, r) in ((cx - 1.81, cz, math.pi / 2), (cx, cz - 1.51, 0.0), (cx + 1.81, cz - 0.4, math.pi / 2)):
                ox, oz = (0.02 if wx > cx + 1 else (-0.02 if wx < cx - 1 else 0)), (-0.02 if wz < cz - 1 else 0)
                obs.append(gbox("Window", (0.7, 0.7, 0.03), (wx + ox, y0 + 1.5, wz + oz), glass, col, rot=(0, r, 0)))
                for (w, h, u, v) in ((0.84, 0.07, 0, 0.385), (0.84, 0.07, 0, -0.385), (0.07, 0.84, 0.385, 0),
                                     (0.07, 0.84, -0.385, 0), (0.7, 0.04, 0, 0), (0.04, 0.7, 0, 0)):
                    px = wx + ox * 2 + (u if r == 0 else 0)
                    pz = wz + oz * 2 + (u if r != 0 else 0)
                    obs.append(gbox("Window Frame", (w, h, 0.05), (px, y0 + 1.5 + v, pz), trim, col, rot=(0, r, 0)))
                for side in (-1, 1):
                    u = side * 0.62
                    px = wx + ox * 2 + (u if r == 0 else 0)
                    pz = wz + oz * 2 + (u if r != 0 else 0)
                    obs.append(gbox("Shutter", (0.36, 0.8, 0.04), (px, y0 + 1.5, pz), K.mat("Shutter", TH_ROOF, rough=0.7),
                                    col, bevel=0.01, rot=(0, r, 0)))
                obs.append(gbox("Sill", (0.9, 0.06, 0.12), (wx + ox * 3 + 0, y0 + 1.1, wz + oz * 3), trim, col,
                                rot=(0, r, 0)))
            # the roof: shingles in rows down both slopes, a ridge, barge boards at the ends
            sl = math.atan2(1.6, 2.1)
            L = math.hypot(2.1, 1.6)
            for side in (-1, 1):
                nx, ny = side * math.sin(sl), math.cos(sl)
                for i in range(9):
                    t = (i + 0.5) / 9
                    x = cx + side * 2.1 * (1 - t)
                    y = 9.8 + 1.6 * t
                    for j in range(12):
                        z = cz - 1.8 + (j + 0.5) * 3.6 / 12 + (0.075 if i % 2 else 0)
                        if abs(z - cz) > 1.85:
                            continue
                        obs.append(gbox("Shingle", (L / 9 * 1.35, 0.05, 3.6 / 12 - 0.02),
                                        (x + nx * 0.04, y + ny * 0.04, z), roof, col, bevel=0.01,
                                        rot=(0, 0, -side * sl)))
            obs.append(gable("Roof Core", cx, cz, 4.2, 1.6, 3.6, 9.8, roof, col))
            obs.append(gbox("Ridge", (0.22, 0.14, 3.75), (cx, 11.42, cz), wood_dk, col, bevel=0.03))
            for e in (-1, 1):
                for side in (-1, 1):
                    mx, my = cx + side * 1.05, 9.8 + 0.8
                    obs.append(gbox("Barge", (L + 0.15, 0.16, 0.06), (mx + side * 0.05, my + 0.05, cz + e * 1.83), trim, col,
                                    rot=(0, 0, -side * sl)))
            obs.append(gbox("Lantern Hook", (0.05, 0.3, 0.05), (dx - 0.65, 9.55, cz + 1.62), iron, col))
            obs.append(K.cyl("Lantern", 0.1, 0.22, at=at(dx - 0.65, 9.3, cz + 1.62), seg=12, m=glass, col=col))
        else:
            obs.append(gbox("House", (3.6, 2.6, 3.0), (cx, y0 + 1.3, cz), wall, col))
            obs.append(gable("Roof", cx, cz, 4.3, 1.65, 3.8, 9.78, roof, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ Rex and Dash's lab
LAB_WALL = (0.62, 0.55, 0.8)
LAB_TRIM = (0.3, 0.8, 0.75)
LAB_ROOF = (0.85, 0.35, 0.7)
LAB_FLOOR = (0.32, 0.28, 0.42)
LAB_METAL = (0.75, 0.78, 0.85)
LAB_DARK = (0.15, 0.12, 0.22)
PODS = (-3.5, -0.5)


def lab_shed():
    wall = K.mat("Lab Wall", LAB_WALL, rough=0.75, bump=0.1)
    trim = K.mat("Lab Trim", LAB_TRIM, rough=0.5)
    roof = K.mat("Lab Roof", LAB_ROOF, rough=0.6, metal=0.2)
    floor = mottled("Lab Floor", LAB_FLOOR, (0.26, 0.22, 0.36), scale=4.0, rough=0.85)
    seam = K.mat("Seam", (0.22, 0.18, 0.32), rough=0.8)
    metal = K.mat("Lab Metal", LAB_METAL, rough=0.3, metal=0.8, pits=0.2)
    bolt = K.mat("Bolt", (0.85, 0.85, 0.9), rough=0.3, metal=0.9)
    navy = K.mat("Sign Board", (0.12, 0.1, 0.3), rough=0.7)
    gold = K.mat("Sign Gold", (1.0, 0.82, 0.35), rough=0.3, metal=0.7)
    porthole = K.mat("Lab Porthole", (0.6, 0.9, 1.0), rough=0.1, emit=0.6, emit_rgb=(0.7, 0.9, 1.0))
    stripe = K.mat("Hazard", (1.0, 0.85, 0.3), rough=0.5)

    def build(col, high):
        obs = []
        b = 0.02 if high else 0
        obs.append(gbox("Floor", (12, 0.12, 9), (0, 0.06, 0), floor, col))
        obs.append(gbox("Back Wall", (12, 4, 0.3), (0, 2, -4.35), wall, col, bevel=b))
        for sx in (-1, 1):
            obs.append(gbox("Side Wall", (0.3, 4, 9), (sx * 5.85, 2, 0), wall, col, bevel=b))
            obs.append(gbox("Front Post", (0.4, 4.1, 0.4), (sx * 5.85, 2.05, 4.4), trim, col, bevel=b))
        obs.append(gbox("Roof", (12.8, 0.3, 9.8), (0, 4.15, 0), roof, col, bevel=b))
        obs.append(gbox("Front Beam", (12.9, 0.2, 0.3), (0, 3.9, 4.6), trim, col, bevel=b))
        obs.append(gbox("Sign Board", (6.4, 1.3, 0.15), (0, 4.95, 4.55), navy, col, bevel=b))
        obs.append(rod("Dish Pole", at(4.5, 4.3, -2.5), at(4.5, 5.5, -2.5), 0.08, metal, col, seg=12 if high else 6))
        if high:
            # floor tiles
            for i in range(1, 12):
                obs.append(gbox("Tile Line", (0.03, 0.01, 9), (-6 + i, 0.121, 0), seam, col))
            for i in range(1, 9):
                obs.append(gbox("Tile Line", (12, 0.01, 0.03), (0, 0.121, -4.5 + i), seam, col))
            # panels and rivets on the walls, inside and out
            for z_face in (-4.19, -4.51):
                for i in range(1, 6):
                    obs.append(gbox("Panel Seam", (0.04, 3.9, 0.02), (-6 + i * 2, 2, z_face), seam, col))
                obs.append(gbox("Panel Seam", (11.9, 0.04, 0.02), (0, 3.3, z_face), seam, col))
                for i in range(25):
                    for y in (0.25, 3.15, 3.45):
                        obs.append(K.sphere("Rivet", 0.03, at=at(-5.9 + i * 0.49, y, z_face), m=bolt, seg=6, col=col))
            for sx in (-1, 1):
                for x_face in (sx * 5.69, sx * 6.01):
                    for i in range(1, 5):
                        obs.append(gbox("Panel Seam", (0.02, 3.9, 0.04), (x_face, 2, -4.5 + i * 1.8), seam, col))
                    obs.append(gbox("Panel Seam", (0.02, 0.04, 8.9), (x_face, 3.3, 0), seam, col))
                    for i in range(19):
                        for y in (0.25, 3.15, 3.45):
                            obs.append(K.sphere("Rivet", 0.03, at=at(x_face, y, -4.4 + i * 0.49), m=bolt, seg=6, col=col))
                    # two portholes each side
                    for z in (-2.2, 1.6):
                        d = 1 if x_face * sx > 5.85 else -1
                        obs.append(K.cyl("Porthole Rim", 0.42, 0.05, at=at(x_face + sx * d * 0.025, 2.2, z), seg=24, m=bolt,
                                         col=col, rot=(0, math.pi / 2, 0)))
                        obs.append(K.cyl("Porthole Glass", 0.33, 0.05, at=at(x_face + sx * d * 0.04, 2.2, z), seg=24,
                                         m=porthole, col=col, rot=(0, math.pi / 2, 0)))
                # hazard stripes up the front posts
                for i in range(8):
                    y = 0.25 + i * 0.5
                    obs.append(gbox("Stripe", (0.42, 0.18, 0.42), (sx * 5.85, y, 4.4), stripe, col, rot=(0.0, 0, 0)))
            # the roof: ribs across it, and a lip all round
            for i in range(13):
                obs.append(gbox("Roof Rib", (0.12, 0.08, 9.8), (-6 + i, 4.33, 0), roof, col, bevel=0.02))
            obs.append(gbox("Roof Lip", (12.85, 0.12, 0.08), (0, 4.36, 4.9), trim, col))
            obs.append(gbox("Roof Lip", (12.85, 0.12, 0.08), (0, 4.36, -4.9), trim, col))
            # bolts along the beam, a gold frame round the sign (its words are the game's, at z 4.66)
            for i in range(26):
                obs.append(K.sphere("Bolt", 0.035, at=at(-6.25 + i * 0.5, 3.9, 4.76), m=bolt, seg=6, col=col))
            for (w, h, x, y) in ((6.4, 0.08, 0, 5.56), (6.4, 0.08, 0, 4.34), (0.08, 1.3, -3.16, 4.95), (0.08, 1.3, 3.16, 4.95)):
                obs.append(gbox("Sign Frame", (w, h, 0.04), (x, y, 4.63), gold, col, bevel=0.01))
            for x in (-3.0, 3.0):
                for y in (4.45, 5.45):
                    obs.append(K.sphere("Sign Bolt", 0.04, at=at(x, y, 4.64), m=gold, seg=8, col=col))
            # the radar dish: ribs, a horn on an arm
            dish = K.lathe("Dish", [(0.0, 0.0), (0.3, 0.02), (0.6, 0.09), (0.85, 0.22), (0.9, 0.3), (0.86, 0.3),
                                    (0.58, 0.12), (0.28, 0.05), (0.0, 0.03)], seg=48, m=metal, col=col)
            ribs = []
            for k in range(8):
                a = k / 8 * math.tau
                ribs.append(rod("Dish Rib", (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.0),
                                (math.cos(a) * 0.86, math.sin(a) * 0.86, 0.22), 0.02, bolt, col, seg=6))
            arm = rod("Dish Arm", (0, 0, 0.03), (0, 0, 0.7), 0.025, bolt, col, seg=8)
            horn = K.cyl("Horn", 0.07, 0.14, at=(0, 0, 0.76), seg=12, m=bolt, col=col, r2=0.03)
            parts = [dish, arm, horn] + ribs
            d = K.join("Dish All", [K.to_mesh(p) for p in parts])
            d.location = at(4.5, 5.45, -2.5)
            d.rotation_euler = (-2.4 + math.pi, 0.0, 0.4)
            obs.append(d)
        else:
            d = K.lathe("Dish", [(0.0, 0.0), (0.6, 0.09), (0.9, 0.3), (0.0, 0.05)], seg=16, m=metal, col=col)
            d.location = at(4.5, 5.45, -2.5)
            d.rotation_euler = (-2.4 + math.pi, 0.0, 0.4)
            obs.append(d)
        return obs

    return build(HIGH, True), build(LOW, False)


def lab_kit():
    trim = K.mat("Pod Trim", LAB_TRIM, rough=0.45, metal=0.3)
    metal = K.mat("Console Metal", LAB_METAL, rough=0.3, metal=0.8, pits=0.25)
    dark = K.mat("Dark", LAB_DARK, rough=0.7)
    bolt = K.mat("Bolt", (0.85, 0.85, 0.9), rough=0.3, metal=0.9)
    pink = K.mat("Pod Light", (1.0, 0.5, 0.85), rough=0.3, emit=1.2)
    bench = K.mat("Bench Wood", (0.55, 0.4, 0.3), rough=0.8, grain=(9.0, 0.3))
    bench_dk = K.mat("Bench Dark", (0.4, 0.28, 0.22), rough=0.85, grain=(9.0, 0.2))
    slate = mottled("Slate", (0.12, 0.25, 0.2), (0.17, 0.3, 0.25), scale=5.0, rough=0.95)
    chalk_wood = K.mat("Board Frame", (0.55, 0.38, 0.25), rough=0.8, grain=(7.0, 0.25))
    chalk = K.mat("Chalk", (0.95, 0.95, 0.9), rough=0.9)
    gold = K.mat("Frame Gold", (0.95, 0.75, 0.3), rough=0.35, metal=0.7, wear=0.0)
    vent = K.mat("Vent", (0.3, 0.3, 0.38), rough=0.5, metal=0.6)
    stripe = K.mat("Hazard", (1.0, 0.85, 0.3), rough=0.5)

    def build(col, high):
        obs = []
        seg = 48 if high else 16
        for x in PODS:
            base_prof = [(0.0, 0.12), (0.9, 0.12), (0.9, 0.42)] if not high else \
                [(0.0, 0.12), (0.92, 0.12), (0.95, 0.17), (0.95, 0.3), (0.9, 0.34), (0.86, 0.42), (0.0, 0.42)]
            obs.append(K.lathe("Pod Base", base_prof + ([(0.0, 0.42)] if not high else []), seg=seg, m=trim,
                               at=at(x, 0, -1.8), col=col))
            cap_prof = [(0.0, 2.82), (0.9, 2.82), (0.9, 3.12), (0.0, 3.12)] if not high else \
                [(0.0, 2.82), (0.86, 2.82), (0.92, 2.86), (0.94, 3.0), (0.88, 3.08), (0.6, 3.14), (0.3, 3.2), (0.0, 3.2)]
            obs.append(K.lathe("Pod Cap", cap_prof, seg=seg, m=trim, at=at(x, 0, -1.8), col=col))
            if high:
                for k in range(16):
                    a = k / 16 * math.tau
                    for y in (0.24, 2.95):
                        obs.append(K.sphere("Pod Bolt", 0.035, at=at(x + math.cos(a) * 0.955, y, -1.8 + math.sin(a) * 0.955),
                                            m=bolt, seg=6, col=col))
                obs.append(ring_y("Pod Glow", 0.75, 0.86, 0.425, 0.44, pink, col, seg=48))
                for k in range(6):                     # vents on the cap
                    a = k / 6 * math.tau
                    obs.append(gbox("Cap Vent", (0.06, 0.03, 0.25), (x + math.cos(a) * 0.45, 3.16, -1.8 + math.sin(a) * 0.45),
                                    vent, col, rot=(0, -a, 0)))
            # the cable to the console, in a bundle with bands
            x0, x1 = (x, 2.2) if x < 2.2 else (2.2, x)
            if high:
                for dz in (-0.05, 0.05):
                    obs.append(rod("Cable", at(x0, 0.16, -1.2 + dz), at(x1, 0.16, -1.2 + dz), 0.045, dark, col, seg=10))
                for i in range(int(abs(x1 - x0) / 0.6)):
                    obs.append(K.cyl("Cable Band", 0.07, 0.05, at=at(x0 + 0.3 + i * 0.6, 0.16, -1.2), seg=12, m=bolt,
                                     col=col, rot=(0, math.pi / 2, 0)))
            else:
                obs.append(gbox("Cable", (abs(x1 - x0), 0.1, 0.16), ((x0 + x1) / 2, 0.16, -1.2), dark, col))
        # the console (its buttons and lever are the game's, on its top at 1.055)
        obs.append(gbox("Console", (1.4, 1.0, 0.8), (2.2, 0.5, -1.3), metal, col, bevel=0.03 if high else 0))
        obs.append(gbox("Console Top", (1.2, 0.05, 0.6), (2.2, 1.03, -1.3), dark, col))
        if high:
            for i in range(6):
                obs.append(gbox("Grille", (0.9, 0.03, 0.02), (2.2, 0.25 + i * 0.07, -0.89), vent, col))
            for sx in (-1, 1):
                for i in range(4):
                    obs.append(gbox("Side Vent", (0.02, 0.04, 0.5), (2.2 + sx * 0.71, 0.4 + i * 0.1, -1.3), vent, col))
            for i in range(5):
                obs.append(gbox("Stripe", (0.14, 0.08, 0.02), (1.65 + i * 0.27, 0.06, -0.895), stripe, col, rot=(0, 0, 0.6)))
            obs.append(gbox("Dial Plate", (0.5, 0.3, 0.02), (2.2, 0.8, -0.89), dark, col))
            for i in range(3):
                obs.append(K.cyl("Dial", 0.06, 0.02, at=at(2.05 + i * 0.15, 0.8, -0.875), seg=16, m=bolt, col=col,
                                 rot=(math.pi / 2, 0, 0)))
            for sx in (-1, 1):
                for sz in (-1, 1):
                    obs.append(K.sphere("Console Bolt", 0.025, at=at(2.2 + sx * 0.66, 1.0, -1.3 + sz * 0.36), m=bolt, seg=6,
                                        col=col))
        # Dash's workbench: a planked top (its beakers are the game's), legs, a shelf, drawers and a vice
        if high:
            for i in range(5):
                obs.append(gbox("Bench Top", (3.0, 0.08, 0.19), (3.9, 0.86, -3.8 + i * 0.2), bench, col, bevel=0.01))
            for sx in (-1, 1):
                for sz in (-1, 1):
                    obs.append(gbox("Bench Leg", (0.1, 0.82, 0.1), (3.9 + sx * 1.4, 0.41, -3.4 + sz * 0.42), bench_dk, col))
            obs.append(gbox("Bench Shelf", (2.8, 0.05, 0.85), (3.9, 0.2, -3.4), bench_dk, col))
            obs.append(gbox("Apron", (2.9, 0.18, 0.04), (3.9, 0.73, -2.92), bench_dk, col))
            for i in range(3):
                obs.append(gbox("Drawer", (0.7, 0.14, 0.03), (2.95 + i * 0.95, 0.73, -2.89), bench, col, bevel=0.01))
                obs.append(K.sphere("Pull", 0.025, at=at(2.95 + i * 0.95, 0.73, -2.87), m=bolt, seg=8, col=col))
            obs.append(gbox("Vice", (0.2, 0.18, 0.25), (5.25, 0.99, -2.95), vent, col, bevel=0.01))
            obs.append(rod("Vice Handle", at(5.25, 0.98, -2.82), at(5.25, 0.98, -2.62), 0.015, bolt, col, seg=6))
            obs.append(gbox("Toolbox", (0.5, 0.2, 0.25), (3.9, 0.3, -3.4), K.mat("Toolbox", (1.0, 0.4, 0.4), rough=0.5), col,
                            bevel=0.015))
        else:
            # the low one keeps the bench's open frame: a solid block would bake black where the high one's open
            obs.append(gbox("Bench Top", (3.0, 0.26, 1.0), (3.9, 0.77, -3.4), bench, col))
            obs.append(gbox("Bench Shelf", (2.8, 0.05, 0.85), (3.9, 0.2, -3.4), bench_dk, col))
            for sx in (-1, 1):
                for sz in (-1, 1):
                    obs.append(gbox("Bench Leg", (0.1, 0.82, 0.1), (3.9 + sx * 1.4, 0.41, -3.4 + sz * 0.42), bench_dk, col))
        # the chalkboard (its words are the game's, at z -4.08: the slate stays behind -4.095)
        obs.append(gbox("Slate", (3.2, 1.8, 0.08), (3.0, 2.4, -4.15), slate, col))
        if high:
            for (w, h, x, y) in ((3.36, 0.1, 3.0, 3.33), (3.36, 0.1, 3.0, 1.47), (0.1, 1.96, 1.35, 2.4), (0.1, 1.96, 4.65, 2.4)):
                obs.append(gbox("Board Frame", (w, h, 0.07), (x, y, -4.12), chalk_wood, col, bevel=0.015))
            obs.append(gbox("Chalk Tray", (2.8, 0.04, 0.1), (3.0, 1.43, -4.06), chalk_wood, col))
            for i in range(3):
                obs.append(rod("Chalk", at(2.2 + i * 0.25, 1.47, -4.06), at(2.3 + i * 0.25, 1.47, -4.05), 0.012, chalk, col,
                               seg=6))
            obs.append(gbox("Eraser", (0.2, 0.05, 0.06), (3.8, 1.48, -4.06), K.mat("Eraser", (0.3, 0.22, 0.4)), col))
        # Hound Hero's gold frame (the picture itself is the game's)
        if high:
            for (w, h, x, y) in ((1.3, 0.1, -4.6, 3.25), (1.3, 0.1, -4.6, 1.75), (0.1, 1.6, -5.2, 2.5), (0.1, 1.6, -4.0, 2.5)):
                obs.append(gbox("Frame", (w, h, 0.1), (x, y, -4.15), gold, col, bevel=0.03))
            obs.append(gbox("Frame Back", (1.15, 1.45, 0.04), (-4.6, 2.5, -4.16), gold, col))
            for (x, y) in ((-5.2, 3.25), (-4.0, 3.25), (-5.2, 1.75), (-4.0, 1.75)):
                obs.append(K.sphere("Frame Rosette", 0.06, at=at(x, y, -4.1), m=gold, seg=10, col=col))
        else:
            obs.append(gbox("Frame", (1.3, 1.6, 0.1), (-4.6, 2.5, -4.15), gold, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the deep pools' stone (the Wishing Well and the rest)
POOL_R = 3.4
POOL_WALL = 0.5
WALL_H = 3.6 + 0.15 + 0.5


def pool_wall():
    # Baked pale, so the game can tint it to each pool's stone colour
    stone = mottled("Pool Stone", (0.93, 0.92, 0.95), (0.78, 0.77, 0.82), scale=3.0, rough=0.85, bump=0.4)
    mortar = K.mat("Mortar", (0.55, 0.54, 0.58), rough=0.95)
    moss = mottled("Wet Stone", (0.7, 0.75, 0.74), (0.6, 0.66, 0.65), scale=5.0, rough=0.4, bump=0.3)

    def build(col, high):
        obs = []
        r_in, r_out = POOL_R, POOL_R + POOL_WALL
        if not high:
            obs.append(ring_y("Wall", r_in, r_out, -WALL_H, 0.0, stone, col, seg=40))
            return obs
        obs.append(ring_y("Mortar", r_in + 0.03, r_out, -WALL_H, -0.01, mortar, col, seg=64))
        course = 0.36
        n_courses = int(WALL_H / course) + 1
        rng_seed = 0
        for c in range(n_courses):
            y1 = -c * course
            y0 = max(y1 - course + 0.025, -WALL_H)
            if y1 - y0 < 0.05:
                continue
            m = moss if c >= 3 else stone
            n = 26
            off = (c % 2) * 0.5
            for k in range(n):
                rng_seed += 1
                jitter = (noise.noise(Vector((rng_seed * 0.7, c * 0.3, 0.1))) * 0.25)
                a0 = (k + off + 0.02 + jitter * 0.1) / n * math.tau
                a1 = (k + off + 0.98 + jitter * 0.1) / n * math.tau
                inset = 0.012 * (1 + noise.noise(Vector((k * 0.9, c * 1.3, 0.5))))
                b = ring_y("Block", r_in - inset, r_out, y0, y1 - 0.012, m, col, seg=4, a0=a0, a1=a1)
                bevel(b, 0.02, 2)
                obs.append(b)
        return obs

    return build(HIGH, True), build(LOW, False)


def pool_lip():
    stone = mottled("Coping", (0.97, 0.96, 0.98), (0.85, 0.84, 0.88), scale=4.0, rough=0.6, bump=0.2)

    def build(col, high):
        obs = []
        r_in, r_out = POOL_R - 0.06, POOL_R + POOL_WALL + 0.06
        if not high:
            obs.append(ring_y("Lip", r_in, r_out, 0.0, 0.1, stone, col, seg=48))
            return obs
        n = 24
        for k in range(n):
            a0 = (k + 0.01) / n * math.tau
            a1 = (k + 0.99) / n * math.tau
            b = ring_y("Coping Stone", r_in, r_out, 0.0, 0.1, stone, col, seg=6, a0=a0, a1=a1)
            bevel(b, 0.025, 3)
            obs.append(b)
            # a little carved bead along the inner edge
            mid = (a0 + a1) / 2
            for s in (-0.3, 0.3):
                a = mid + s / n * math.tau
                obs.append(K.sphere("Bead", 0.025, at=at(math.cos(a) * (r_in + 0.04), 0.1, math.sin(a) * (r_in + 0.04)),
                                    m=stone, seg=8, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ Remnant veins
OBSIDIAN = (0.12, 0.08, 0.18)
CRYSTAL_GREEN = (0.45, 1.0, 0.3)


def _crystal(name, r, h, base, tilt, spin, m, col, high, snapped=False):
    """A six-sided crystal (Godot base point, tilt (x, z) radians), pointed, or snapped off short."""
    bm = bmesh.new()
    rings = []
    prof = [(r, 0.0), (r * 0.95, h * 0.8), (r * 0.15, h)] if not snapped else \
        [(r, 0.0), (r * 0.97, h * 0.7), (r * 0.8, h)]
    for i, (rr, z) in enumerate(prof):
        ring = []
        for k in range(6):
            a = k / 6 * math.tau + spin
            zz = z
            if snapped and i == 2:
                zz = z + (0.06 if k % 2 else -0.04) * r * 4     # a jagged broken top
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, zz)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(6):
            j = (k + 1) % 6
            bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
    bm.faces.new(list(reversed(rings[0])))
    if snapped:
        bm.faces.new(rings[-1])
    else:
        tip = bm.verts.new((0, 0, h * 1.08))
        for k in range(6):
            bm.faces.new((rings[-1][k], rings[-1][(k + 1) % 6], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = mesh_obj(name, bm, m, col, smooth=False)
    ob.location = at(*base)
    ob.rotation_euler = (tilt[0], -tilt[1], 0)      # Godot's x tilt is Blender's x, its z tilt Blender's -y
    return ob


def _vein_layout():
    out = []
    for k in range(9):
        a = k * math.tau / 9 + noise.noise(Vector((k * 0.7, 0.3, 0.1))) * 0.3
        d = 0.15 + (0.5 + noise.noise(Vector((k * 1.3, 0.9, 0.2))) * 0.5) * 0.8
        h = (1.0 + (0.5 + noise.noise(Vector((k * 0.4, 2.1, 0.5)))) * 1.4) * (1.3 if d < 0.4 else 1.0)
        r = 0.14 + (0.5 + noise.noise(Vector((k * 2.2, 0.1, 0.9)))) * 0.12
        out.append((a, d, h, r))
    return out


def vein_rock():
    rock = mottled("Obsidian", OBSIDIAN, (0.22, 0.14, 0.3), scale=5.0, rough=0.2, metal=0.4)
    fleck = K.mat("Fleck", CRYSTAL_GREEN, rough=0.2, emit=1.2, emit_rgb=(0.35, 1.0, 0.25))

    def build(col, high):
        obs = []
        for k in range(5):
            a = k * math.tau / 5
            r = 0.75 + 0.15 * math.sin(k * 2.1)
            obs.append(lumpy("Lump", r, (math.cos(a) * 0.7, 0.15, math.sin(a) * 0.7), 0.72, k + 1, rock, col,
                             subdiv=4 if high else 2, amp=0.22))
        if high:
            for k in range(14):
                a = k * 2.39
                rr = 0.9 + (k % 3) * 0.3
                y = 0.25 + (k % 4) * 0.12
                obs.append(_crystal("Fleck", 0.05, 0.16, (math.cos(a) * rr, y, math.sin(a) * rr),
                                    (math.sin(a) * 0.8, -math.cos(a) * 0.8), k, fleck, col, True))
        return obs

    return build(HIGH, True), build(LOW, False)


def _vein_crystals(snapped):
    glow = K.mat("Remnant Crystal", CRYSTAL_GREEN, rough=0.15, metal=0.3, emit=1.0, emit_rgb=(0.35, 1.0, 0.25))
    deep = K.mat("Crystal Deep", (0.2, 0.7, 0.2), rough=0.2, metal=0.3, emit=0.6, emit_rgb=(0.2, 0.8, 0.15))

    def build(col, high):
        obs = []
        for k, (a, d, h, r) in enumerate(_vein_layout()):
            if snapped:
                h = 0.3
                r = 0.14
            tilt = (math.sin(a) * 0.35 * d, -math.cos(a) * 0.35 * d)
            base = (math.cos(a) * d, 0.3 if not snapped else 0.35, math.sin(a) * d)
            obs.append(_crystal("Crystal", r, h, base, tilt, k * 0.4, glow, col, high, snapped))
            if high:
                # a darker foot (no bright core: it washed the bake out pale)
                obs.append(_crystal("Foot", r * 1.04, h * 0.18, base, tilt, k * 0.4, deep, col, high, True))
                if not snapped:
                    for s in (-1, 1):                    # little crystals growing off its side
                        aa = a + s * 0.6
                        obs.append(_crystal("Side", r * 0.4, h * 0.35,
                                            (base[0] + math.cos(aa) * r * 0.9, base[1] + h * 0.15, base[2] + math.sin(aa) * r * 0.9),
                                            (tilt[0] + math.sin(aa) * 0.5, tilt[1] - math.cos(aa) * 0.5), k + s, glow, col,
                                            high))
        return obs

    return build(HIGH, True), build(LOW, False)


def vein_crystals():
    return _vein_crystals(False)


def vein_stubs():
    return _vein_crystals(True)


# ================================================================ bake and export
def bake_part(name, high, low, size, emit=False, emit_strength=1.0, extrusion=0.03, ray=0.1, ao=True):
    hi_tris = K.tri_count(high)
    prop = K.join(name, low)
    lo_tris = K.tri_count([prop])
    K.uv_unwrap(prop, margin=0.004)
    maps = K.bake(prop, high, size=size, name=name, extrusion=extrusion, ray=ray,
                  maps=["normal"] + (["ao"] if ao else []) + ["color", "rough", "metal"] + (["emit"] if emit else []))
    K.finish(prop, maps, size, name, emit_strength=emit_strength)
    print("TRIS %s high %d low %d" % (name, hi_tris, lo_tris))
    return prop


fn, size, emit, ext, ray, emit_s = {
    "tree_house": (tree_house, 2048, True, 0.06, 0.15, 1.0),
    "lab_shed": (lab_shed, 2048, True, 0.05, 0.12, 1.0),
    "lab_kit": (lab_kit, 1024, True, 0.04, 0.1, 1.0),
    "pool_wall": (pool_wall, 1024, False, 0.05, 0.1, 1.0),
    "pool_lip": (pool_lip, 512, False, 0.04, 0.08, 1.0),
    "vein_rock": (vein_rock, 1024, True, 0.15, 0.35, 1.4),
    "vein_crystals": (vein_crystals, 512, True, 0.04, 0.1, 1.0),
    "vein_stubs": (vein_stubs, 256, True, 0.04, 0.1, 1.0),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, emit_strength=emit_s, extrusion=ext, ray=ray)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

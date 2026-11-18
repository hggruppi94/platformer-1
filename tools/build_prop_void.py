# The Void's crystals, sailboats, dome doors, antique car and picnic baskets, built the detailed way
# (tools/bake_kit.py; 18 Nov 2026, Hayden: "what about going back to baking details", then "More scenery"). Each
# HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the builder's pieces (tools/build_town.gd) so the swap (scripts/detail_props.gd dress_void()) puts each
# exactly where the old one was. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   crystal        one shard of the glowing clusters (_crystals): five-sided, 0.8 r across at the foot, r at the
#                  shoulder (0.65 up) and a point at the top, made for r = 0.18 and a height of 1 (the game scales
#                  it to each shard). Bevelled edges, growth lines, cloudy inclusions and glowing cracks inside. Baked
#                  nearly white: the game tints each cluster its own colour (albedo and glow).
#   sailboat       the lake's sailboats (_boats): a 1 x 2.6 m hull (top 0.2 m over the boat's origin) with its bow to
#                  Godot +Z, a mast, a boom and a mainsail 1.8 m along and 2.4 m up where the builder's was. Two
#                  parts: "sailboat_hull" in the hull's colour, and "sailboat_sail" baked white, tinted per boat.
#   dome_door      the door of every dome building (dome_building): a rounded wooden door 1.6 x 2.4 m with planks,
#                  iron straps and studs, a porthole and a ring, in a frame of teal stone blocks with a keystone, and
#                  a step. Its front is at Godot z +0.3 (the builder's door box is 0.6 deep), its foot at y -0.2.
#   antique_car    the old car in the South Meadow picnic park (_antique_car): the builder's sizes, its front to
#                  Godot +Z. Louvred hood, a brass radiator with a grille, lamps, sweeping fenders, running boards,
#                  wooden-spoked wheels, buttoned seats, a steering wheel, a horn, a canvas roof and the spare.
#   picnic_basket  the picnic park's baskets: woven wicker 0.6 x 0.4 m and 0.4 m high, two lids, a handle and a
#                  checked cloth peeking out.
# Colours are the builder's as they are in town.tscn (after the alien tint, sRGB). Collisions stay the builder's.
#
#   python tools/build_prop_void.py "<out>.glb" <crystal|sailboat|dome_door|antique_car|picnic_basket> [--preview]

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

KINDS = ["crystal", "sailboat", "dome_door", "antique_car", "picnic_basket"]
KIND = next((a for a in sys.argv if a in KINDS), "crystal")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")
D = K.D


def rod(name, a, b, r, m, col, seg=12, r2=None):
    """A round bar from point a to point b."""
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
    # written as sRGB like everywhere else in the kit; Blender's colour inputs are linear
    K._rgba(mix.inputs, "A").default_value = (*(K.srgb_to_linear(c) for c in a), 1)
    K._rgba(mix.inputs, "B").default_value = (*(K.srgb_to_linear(c) for c in b), 1)
    return K._rgba(mix.outputs, "Result")


# ================================================================ the crystal shard
CR = 0.18           # the model's shoulder radius (its height is 1)


def crystal_mat():
    """Nearly white, cloudy inside, with growth lines across the faces and glowing cracks."""
    m = K.mat("Crystal", (0.93, 0.93, 0.95), rough=0.12, metal=0.2)
    nt, b, co = _nodes(m)
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 5.0
    nt.links.new(co, vor.inputs["Vector"])
    edge = nt.nodes.new("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.0
    edge.inputs["From Max"].default_value = 0.02
    edge.inputs["To Min"].default_value = 1.0
    edge.inputs["To Max"].default_value = 0.0
    nt.links.new(vor.outputs["Distance"], edge.inputs["Value"])
    # only a few of the cell edges are cracks: a big soft noise picks them, so it doesn't read as a tiled pattern
    pick = nt.nodes.new("ShaderNodeTexNoise")
    pick.inputs["Scale"].default_value = 3.0
    nt.links.new(co, pick.inputs["Vector"])
    pick_r = nt.nodes.new("ShaderNodeMapRange")
    pick_r.inputs["From Min"].default_value = 0.55
    pick_r.inputs["From Max"].default_value = 0.65
    nt.links.new(pick.outputs["Fac"], pick_r.inputs["Value"])
    crack = nt.nodes.new("ShaderNodeMath")
    crack.operation = "MULTIPLY"
    nt.links.new(edge.outputs["Result"], crack.inputs[0])
    nt.links.new(pick_r.outputs["Result"], crack.inputs[1])
    cloud = nt.nodes.new("ShaderNodeTexNoise")
    cloud.inputs["Scale"].default_value = 7.0
    cloud.inputs["Detail"].default_value = 6.0
    nt.links.new(co, cloud.inputs["Vector"])
    # colour: cloudy inclusions a little darker, cracks bright
    base = _mix_rgb(nt, cloud.outputs["Fac"], (0.72, 0.72, 0.76), (0.98, 0.98, 1.0))
    mix2 = nt.nodes.new("ShaderNodeMix")
    mix2.data_type = "RGBA"
    nt.links.new(crack.outputs[0], mix2.inputs["Factor"])
    nt.links.new(base, K._rgba(mix2.inputs, "A"))
    K._rgba(mix2.inputs, "B").default_value = (1, 1, 1, 1)
    nt.links.new(K._rgba(mix2.outputs, "Result"), b.inputs["Base Color"])
    # glow: brighter in the cracks and the clear patches, dimmer in the cloudy ones
    glow = nt.nodes.new("ShaderNodeMath")
    glow.operation = "MULTIPLY_ADD"
    nt.links.new(cloud.outputs["Fac"], glow.inputs[0])
    glow.inputs[1].default_value = 0.3
    glow.inputs[2].default_value = 0.12
    glow2 = nt.nodes.new("ShaderNodeMath")
    glow2.operation = "ADD"
    glow2.use_clamp = True
    nt.links.new(glow.outputs[0], glow2.inputs[0])
    nt.links.new(crack.outputs[0], glow2.inputs[1])
    gc = nt.nodes.new("ShaderNodeCombineColor")
    for ch in ("Red", "Green", "Blue"):
        nt.links.new(glow2.outputs[0], gc.inputs[ch])
    nt.links.new(gc.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.0
    # bump: growth lines round the shard, and the cracks cut in
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 4.0
    wave.inputs["Distortion"].default_value = 3.0
    wave.inputs["Detail"].default_value = 2.0
    nt.links.new(co, wave.inputs["Vector"])
    h = nt.nodes.new("ShaderNodeMath")
    h.operation = "SUBTRACT"
    nt.links.new(wave.outputs["Fac"], h.inputs[0])
    nt.links.new(crack.outputs[0], h.inputs[1])
    bn = nt.nodes.new("ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.8
    bn.inputs["Distance"].default_value = 0.006
    nt.links.new(h.outputs[0], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def crystal():
    m = crystal_mat()

    def build(col, high):
        if high:
            # more rings up the sides so the bevel follows the shape, the point's edges a little rounded
            # growth steps up the sides: each a little ledge, so light catches the lines across the faces
            prof = [(0.0, -0.04), (0.8 * CR, -0.04)]
            steps = 7
            for i in range(1, steps + 1):
                t0, t1 = (i - 1) / steps, i / steps
                r0 = 0.8 * CR + 0.2 * CR * t0
                r1 = 0.8 * CR + 0.2 * CR * t1
                prof.append((r0 - 0.004, 0.65 * t0 + 0.012))
                prof.append((r1 - 0.004, 0.65 * t1 - 0.012))
                prof.append((r1, 0.65 * t1))
            for i in range(1, 6):
                t = i / 6
                prof.append((CR * (1 - t), 0.65 + 0.35 * t))
            prof.append((0.0, 1.0))
            ob = K.lathe("Shard", prof, seg=5, m=m, smooth=False, col=col)
            bevel(ob, 0.01, 3)
            return [ob]
        return [K.lathe("Shard", [(0.0, -0.04), (0.8 * CR, -0.04), (CR, 0.65), (0.0, 1.0)], seg=5, m=m, smooth=False,
                        col=col)]

    return build(HIGH, True), build(LOW, False)


# ================================================================ the sailboat
HULL_W, HULL_L, HULL_TOP, HULL_KEEL = 1.0, 2.6, 0.2, -0.2
HULL_RGB = (0.736, 0.642, 0.817)        # "Boat Hull" after the tint


def hull_point(t, u, inset=0.0):
    """t from -1 (bow, Blender -Y) to 1 (stern); u from 0 (one side's gunwale) through 0.5 (the keel) to 1."""
    tt = abs(t)
    half = HULL_W / 2 * ((1 - tt ** 2.0) ** 0.6 if t < 0 else 1 - 0.3 * tt ** 2.5)
    half = max(half - inset, 0.006)
    top = HULL_TOP + 0.06 * (tt ** 2 if t < 0 else 0.0)
    depth = max((top - HULL_KEEL) * (1 - 0.3 * tt ** 2) - inset, 0.02)
    ang = u * math.pi
    return (math.cos(ang) * half, t * HULL_L / 2, top - depth * math.sin(ang) ** 0.8)


def hull_shell(name, m, col, nt, nu):
    bm = bmesh.new()
    th = 0.03
    outer = [[bm.verts.new(hull_point(-1 + 2 * i / nt, j / nu)) for j in range(nu + 1)] for i in range(nt + 1)]
    inner = [[bm.verts.new(hull_point(-1 + 2 * i / nt, j / nu, th)) for j in range(nu + 1)] for i in range(nt + 1)]
    for i in range(nt):
        for j in range(nu):
            bm.faces.new((outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j]))
            bm.faces.new((inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], inner[i][j + 1]))
        for j in (0, nu):
            bm.faces.new((outer[i][j], outer[i + 1][j], inner[i + 1][j], inner[i][j]))
    for j in range(nu):
        bm.faces.new((outer[nt][j], outer[nt][j + 1], inner[nt][j + 1], inner[nt][j]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, True, col)


MAST_Y = -0.25              # Blender y of the mast (a little forward of the middle)
BOOM_Z, SAIL_TOP = 0.42, 2.72
SAIL_LEN = 1.8


def sail_mesh(name, m, col, high, jib=False):
    """A sail: a triangle from its luff's foot A along its foot to the clew B and up to the head C (Blender y, z), with
    a little belly out to the side. Two thin sides joined round the edges."""
    if jib:
        A, B, C = (-HULL_L / 2 + 0.12, HULL_TOP + 0.12), (MAST_Y - 0.14, HULL_TOP + 0.3), (MAST_Y - 0.04, SAIL_TOP - 0.3)
    else:
        A, B, C = (MAST_Y + 0.06, BOOM_Z + 0.04), (MAST_Y + SAIL_LEN, BOOM_Z + 0.04), (MAST_Y + 0.06, SAIL_TOP)
    nu, nv = (16, 20) if high else (8, 10)
    verts, faces = [], []
    for side in (0, 1):
        for i in range(nv + 1):
            v = i / nv                                        # 0 along the foot, 1 at the head
            for j in range(nu + 1):
                u = j / nu                                    # 0 at the luff, 1 at the leech
                y = A[0] + (1 - v) * u * (B[0] - A[0]) + v * (C[0] - A[0])
                z = A[1] + (1 - v) * u * (B[1] - A[1]) + v * (C[1] - A[1])
                belly = 0.09 * math.sin(math.pi * u) * math.sin(math.pi * min(1.0, v + 0.15)) * (1 - v * 0.6)
                verts.append((belly + (0.006 if side else -0.006), y, z))
    row = nu + 1
    per = (nv + 1) * row
    for side in (0, 1):
        for i in range(nv):
            for j in range(nu):
                a = side * per + i * row + j
                q = (a, a + 1, a + row + 1, a + row)
                faces.append(q if side else tuple(reversed(q)))
    for i in range(nv):
        for j in (0, nu):
            a, b = i * row + j, (i + 1) * row + j
            faces.append((a, b, b + per, a + per))
    for j in range(nu):
        faces.append((j, j + per, j + 1 + per, j + 1))
    ob = mesh_from(name, verts, faces, m, col, smooth=True)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.0001)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def sailcloth_mat():
    """Canvas, baked white: panels sewn across with seams, a weave, and gentle creases."""
    m = K.mat("Sailcloth", (0.96, 0.95, 0.92), rough=0.75)
    nt, b, co = _nodes(m)
    seams = nt.nodes.new("ShaderNodeTexWave")
    seams.wave_type = "BANDS"
    seams.bands_direction = "Z"
    seams.wave_profile = "SAW"
    seams.inputs["Scale"].default_value = 1.6
    nt.links.new(co, seams.inputs["Vector"])
    sharp = nt.nodes.new("ShaderNodeMapRange")
    sharp.inputs["From Min"].default_value = 0.93
    sharp.inputs["From Max"].default_value = 1.0
    nt.links.new(seams.outputs["Fac"], sharp.inputs["Value"])
    weave = nt.nodes.new("ShaderNodeTexWave")
    weave.inputs["Scale"].default_value = 90.0
    nt.links.new(co, weave.inputs["Vector"])
    crease = nt.nodes.new("ShaderNodeTexNoise")
    crease.inputs["Scale"].default_value = 3.0
    crease.inputs["Distortion"].default_value = 1.5
    nt.links.new(co, crease.inputs["Vector"])
    h = nt.nodes.new("ShaderNodeMath")
    h.operation = "MULTIPLY_ADD"
    nt.links.new(weave.outputs["Fac"], h.inputs[0])
    h.inputs[1].default_value = 0.15
    nt.links.new(crease.outputs["Fac"], h.inputs[2])
    h2 = nt.nodes.new("ShaderNodeMath")
    h2.operation = "ADD"
    nt.links.new(h.outputs[0], h2.inputs[0])
    nt.links.new(sharp.outputs["Result"], h2.inputs[1])
    bn = nt.nodes.new("ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.4
    bn.inputs["Distance"].default_value = 0.004
    nt.links.new(h2.outputs[0], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    col = _mix_rgb(nt, sharp.outputs["Result"], (0.97, 0.96, 0.93), (0.82, 0.8, 0.76))
    nt.links.new(col, b.inputs["Base Color"])
    return m


def sailboat():
    paint = K.mat("Hull Paint", HULL_RGB, rough=0.45, pits=0.1, bump=0.04)
    deck = K.mat("Hull Wood", (0.66, 0.5, 0.34), rough=0.7, grain=(14.0, 0.3), bump=0.1)
    trim = K.mat("Hull Trim", (0.95, 0.93, 0.98), rough=0.4)
    spar = K.mat("Spar Wood", (0.7, 0.54, 0.36), rough=0.55, grain=(18.0, 0.25))
    brass = K.mat("Boat Brass", (0.82, 0.66, 0.34), rough=0.3, metal=1.0, pits=0.1)
    rope = K.mat("Boat Rope", (0.88, 0.82, 0.68), rough=0.9, bump=0.3)
    cloth = sailcloth_mat()

    def hull(col, high):
        obs = [hull_shell("Hull", paint, col, 32 if high else 12, 14 if high else 6)]
        steps = 32 if high else 10
        for side in (0.0, 1.0):
            pts = [hull_point(-1 + 2 * i / steps, side, -0.01) for i in range(steps + 1)]
            obs.append(K.wire("Gunwale", pts, 0.022, trim, res=4 if high else 1, bevel_res=2 if high else 0, col=col))
        # a little foredeck and a cockpit seat, and a deck plank floor
        obs.append(K.box("Foredeck", (0.62, 0.55, 0.03), at=(0, -0.95, HULL_TOP - 0.02), m=deck,
                         bevel=0.008 if high else 0, col=col))
        obs.append(K.box("Floor", (0.6, 1.9, 0.02), at=(0, 0.2, HULL_KEEL + 0.12), m=deck, col=col))
        for yy in (0.55, 1.05):
            obs.append(K.box("Thwart", (0.82, 0.2, 0.035), at=(0, yy, HULL_TOP - 0.1), m=deck,
                             bevel=0.006 if high else 0, col=col))
        if high:
            for u in (0.12, 0.24, 0.36, 0.64, 0.76, 0.88):
                pts = [hull_point(-1 + 2 * i / 30, u, -0.005) for i in range(31)]
                obs.append(K.wire("Strake", pts, 0.006, paint, res=3, bevel_res=1, col=col))
            pts = [hull_point(-1 + 2 * i / 30, 0.3, -0.004) for i in range(31)]
            pts2 = [hull_point(-1 + 2 * i / 30, 0.7, -0.004) for i in range(31)]
            obs.append(K.wire("Stripe", pts, 0.012, trim, res=3, bevel_res=1, col=col))
            obs.append(K.wire("Stripe", pts2, 0.012, trim, res=3, bevel_res=1, col=col))
            for k in range(-2, 3):
                obs.append(K.box("Floor Plank", (0.1, 1.85, 0.012), at=(k * 0.12, 0.2, HULL_KEEL + 0.135), m=deck,
                                 bevel=0.003, col=col))
        # the mast, the boom and the rigging, all part of the hull's piece (only the sails are tinted)
        obs.append(K.cyl("Mast", 0.035, SAIL_TOP + 0.2 - HULL_KEEL, at=(0, MAST_Y, (SAIL_TOP + 0.2 + HULL_KEEL) / 2),
                         m=spar, seg=12 if high else 6, r2=0.025, col=col))
        obs.append(rod("Boom", (0, MAST_Y, BOOM_Z), (0, MAST_Y + SAIL_LEN + 0.1, BOOM_Z), 0.03, spar, col,
                       seg=10 if high else 5))
        obs.append(K.cyl("Mast Cap", 0.045, 0.06, at=(0, MAST_Y, SAIL_TOP + 0.2), m=brass, seg=10 if high else 5,
                         col=col))
        stay = 0.008 if high else 0.012
        for (a, b) in (((0, MAST_Y, SAIL_TOP + 0.15), (0, -HULL_L / 2 + 0.02, HULL_TOP + 0.07)),
                       ((0, MAST_Y, SAIL_TOP + 0.1), (0.46, MAST_Y + 0.15, HULL_TOP + 0.01)),
                       ((0, MAST_Y, SAIL_TOP + 0.1), (-0.46, MAST_Y + 0.15, HULL_TOP + 0.01)),
                       ((0, MAST_Y + SAIL_LEN, BOOM_Z), (0, MAST_Y + SAIL_LEN - 0.1, HULL_TOP + 0.02))):
            obs.append(rod("Stay", a, b, stay, rope, col, seg=6 if high else 3))
        if high:
            obs.append(K.cyl("Cleat", 0.02, 0.12, at=(0.3, 0.9, HULL_TOP), rot=(math.pi / 2, 0, 0), m=brass, seg=8,
                             col=col))
            coil = []
            for i in range(80):
                s = i / 79
                a = s * 4 * math.tau
                r = 0.1 - s * 0.05
                coil.append((0.2 + math.cos(a) * r, 0.75 + math.sin(a) * r, HULL_KEEL + 0.16 + s * 0.03))
            obs.append(K.wire("Rope Coil", coil, 0.012, rope, res=2, bevel_res=2, col=col))
            obs.append(K.box("Rudder", (0.03, 0.22, 0.45), at=(0, HULL_L / 2 + 0.06, -0.05), m=deck, bevel=0.008,
                             col=col))
            obs.append(rod("Tiller", (0, HULL_L / 2 + 0.05, 0.16), (0, HULL_L / 2 - 0.5, 0.3), 0.018, spar, col))
        else:
            obs.append(K.box("Rudder", (0.03, 0.22, 0.45), at=(0, HULL_L / 2 + 0.06, -0.05), m=deck, col=col))
            obs.append(rod("Tiller", (0, HULL_L / 2 + 0.05, 0.16), (0, HULL_L / 2 - 0.5, 0.3), 0.018, spar, col, seg=4))
        return obs

    def sails(col, high):
        return [sail_mesh("Mainsail", cloth, col, high), sail_mesh("Jib", cloth, col, high, jib=True)]

    return (hull(HIGH, True), hull(LOW, False)), (sails(HIGH, True), sails(LOW, False))


# ================================================================ the dome door
DOOR_W, DOOR_H = 1.5, 2.3           # the door leaf; its frame is 1.9 wide and 2.6 tall like the builder's box
DOOR_FRONT = -0.3                   # Blender y of the door's front face (Godot z +0.3)
DOOR_RGB = (0.101, 0.207, 0.23)     # "Door"
TRIM_RGB = (0.057, 0.782, 0.752)    # "Dome Trim"


def arch_outline(w, h, n):
    """Points round a round-topped opening, from the bottom left up over the arch to the bottom right."""
    r = w / 2
    spring = h - r
    pts = [(-r, 0.0)]
    for i in range(n + 1):
        a = math.pi - i / n * math.pi
        pts.append((math.cos(a) * r, spring + math.sin(a) * r))
    pts.append((r, 0.0))
    return pts


def slab_from_outline(name, outline, y0, y1, m, col):
    """A flat piece in the x/z plane (Blender), the outline's shape, from y0 to y1 thick."""
    n = len(outline)
    verts = [(x, y0, z) for x, z in outline] + [(x, y1, z) for x, z in outline]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return mesh_from(name, verts, faces, m, col)


def dome_door():
    wood = K.mat("Door Wood", DOOR_RGB, rough=0.75, grain=(10.0, 0.45), pits=0.15, bump=0.15)
    iron = K.mat("Door Iron", (0.12, 0.12, 0.14), rough=0.55, metal=0.8, pits=0.3, bump=0.2)
    brass = K.mat("Door Brass", (0.86, 0.68, 0.32), rough=0.3, metal=1.0, pits=0.1)
    stone = K.mat("Door Stone", TRIM_RGB, rough=0.7, pits=0.3, bump=0.3)
    glass = K.mat("Door Glass", (0.3, 0.18, 0.9), rough=0.1, emit=0.35, emit_rgb=(0.3, 0.18, 0.9))
    step = K.mat("Door Step", tuple(c * 0.8 for c in TRIM_RGB), rough=0.8, pits=0.3, bump=0.3)
    foot = -0.2

    def build(col, high):
        obs = []
        # the leaf: one slab in the low one, planks (with gaps) in the high one, sitting a little back in its frame
        leaf = arch_outline(DOOR_W, DOOR_H, 24 if high else 8)
        leaf = [(x, z + foot) for x, z in leaf]
        if high:
            planks = 6
            pw = DOOR_W / planks
            for k in range(planks):
                x0 = -DOOR_W / 2 + k * pw + 0.006
                x1 = x0 + pw - 0.012
                # each plank's top follows the arch
                pts = [(x0, foot), (x1, foot)]
                top = []
                for i in range(7):
                    x = x1 - (x1 - x0) * i / 6
                    r = DOOR_W / 2
                    z = foot + DOOR_H - r + math.sqrt(max(0.0, r * r - x * x))
                    top.append((x, z))
                ob = slab_from_outline("Plank", pts + top, DOOR_FRONT + 0.06, DOOR_FRONT + 0.2, wood, col)
                obs.append(bevel(ob, 0.006, 2))
            # iron straps with studs, a ring, a lock plate, hinge knuckles
            for zz in (0.35, 1.2, 1.75):
                obs.append(K.box("Strap", (DOOR_W - 0.08, 0.02, 0.09), at=(0, DOOR_FRONT + 0.05, foot + zz), m=iron,
                                 bevel=0.006, col=col))
                for k in range(9):
                    x = -DOOR_W / 2 + 0.12 + k * (DOOR_W - 0.24) / 8
                    obs.append(K.sphere("Stud", 0.018, at=(x, DOOR_FRONT + 0.035, foot + zz), m=iron, seg=8,
                                        scale=(1, 0.6, 1), col=col))
            for zz in (0.35, 1.75):
                obs.append(K.cyl("Hinge", 0.035, 0.16, at=(-DOOR_W / 2 + 0.02, DOOR_FRONT + 0.06, foot + zz), m=iron,
                                 seg=10, col=col))
            ring = [(0.48 + 0.07 * math.sin(a), DOOR_FRONT + 0.03, foot + 0.98 - 0.07 * math.cos(a))
                    for a in [i / 16 * math.tau for i in range(16)]]
            obs.append(K.wire("Ring", ring, 0.011, brass, closed=True, res=3, bevel_res=2, col=col))
            obs.append(K.cyl("Ring Boss", 0.04, 0.02, at=(0.48, DOOR_FRONT + 0.05, foot + 1.05),
                             rot=(math.pi / 2, 0, 0), m=brass, seg=12, col=col))
            obs.append(K.box("Lock Plate", (0.09, 0.015, 0.2), at=(0.48, DOOR_FRONT + 0.05, foot + 1.25), m=brass,
                             bevel=0.008, col=col))
            # the porthole: a brass ring round glowing glass
            obs.append(K.cyl("Porthole Rim", 0.2, 0.05, at=(0, DOOR_FRONT + 0.05, foot + 1.48),
                             rot=(math.pi / 2, 0, 0), m=brass, seg=32, col=col))
            obs.append(K.cyl("Porthole", 0.15, 0.06, at=(0, DOOR_FRONT + 0.04, foot + 1.48), rot=(math.pi / 2, 0, 0),
                             m=glass, seg=32, col=col))
            for k in range(8):
                a = k / 8 * math.tau
                obs.append(K.sphere("Rivet", 0.012, at=(math.cos(a) * 0.175, DOOR_FRONT + 0.022,
                                                       foot + 1.48 + math.sin(a) * 0.175), m=brass, seg=8, col=col))
        else:
            obs.append(slab_from_outline("Leaf", leaf, DOOR_FRONT + 0.06, DOOR_FRONT + 0.2, wood, col))
            obs.append(K.cyl("Porthole", 0.2, 0.05, at=(0, DOOR_FRONT + 0.05, foot + 1.48), rot=(math.pi / 2, 0, 0),
                             m=glass, seg=12, col=col))
        # the frame: stone blocks round the arch, a keystone, two jamb pillars, buried into the dome behind
        r_in, r_out = DOOR_W / 2 + 0.02, DOOR_W / 2 + 0.22
        spring = foot + DOOR_H - DOOR_W / 2
        blocks = 9 if high else 1
        if high:
            for k in range(blocks):
                a0 = math.pi - k / blocks * math.pi + 0.012
                a1 = math.pi - (k + 1) / blocks * math.pi - 0.012
                ro = r_out + (0.07 if k == blocks // 2 else 0.0)
                pts = []
                for i in range(5):
                    a = a0 + (a1 - a0) * i / 4
                    pts.append((math.cos(a) * r_in, spring + math.sin(a) * r_in))
                for i in range(5):
                    a = a1 + (a0 - a1) * i / 4
                    pts.append((math.cos(a) * ro, spring + math.sin(a) * ro))
                ob = slab_from_outline("Voussoir", pts, DOOR_FRONT - (0.08 if k == blocks // 2 else 0.05), 0.3, stone,
                                       col)
                obs.append(bevel(ob, 0.012, 2))
            for s in (-1, 1):
                for j in range(4):
                    z0 = foot + j * (spring - foot) / 4
                    z1 = foot + (j + 1) * (spring - foot) / 4 - 0.015
                    wdt = 0.2 if j % 2 == 0 else 0.26
                    obs.append(K.box("Jamb Block", (wdt, 0.36, z1 - z0), at=(s * (r_in + wdt / 2), DOOR_FRONT + 0.13,
                                                                           (z0 + z1) / 2),
                                     m=stone, bevel=0.012, col=col))
        else:
            # outline: the arch ring plus both jambs, as one band
            band = [(-r_out - 0.035, foot), (-r_in, foot)]
            for i in range(9):
                a = math.pi - i / 8 * math.pi
                band.append((math.cos(a) * r_in, spring + math.sin(a) * r_in))
            band.append((r_in, foot))
            band.append((r_out + 0.035, foot))
            for i in range(9):
                a = i / 8 * math.pi
                band.append((math.cos(a) * (r_out + 0.035), spring + math.sin(a) * (r_out + 0.035)))
            obs.append(slab_from_outline("Frame", band, DOOR_FRONT - 0.065, 0.3, stone, col))
        # the step
        obs.append(K.box("Step", (DOOR_W + 0.6, 0.45, 0.24), at=(0, DOOR_FRONT - 0.2, foot + 0.12), m=step,
                         bevel=0.02 if high else 0, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the antique car
def antique_car():
    paint = K.mat("Car Paint", (0.6, 0.08, 0.14), rough=0.28, metal=0.3, pits=0.05)
    black = K.mat("Car Black", (0.06, 0.05, 0.07), rough=0.5, metal=0.2, pits=0.1)
    brass = K.mat("Car Brass", (0.9, 0.7, 0.3), rough=0.25, metal=0.95, pits=0.1)
    cream = K.mat("Car Cream", (0.95, 0.9, 0.78), rough=0.8, bump=0.25)
    leather = K.mat("Car Leather", (0.32, 0.17, 0.1), rough=0.55, bump=0.2)
    spoke = K.mat("Car Spokes", (0.86, 0.78, 0.6), rough=0.5, grain=(20.0, 0.2))
    tyre = K.mat("Car Tyre", (0.09, 0.09, 0.09), rough=0.85, bump=0.3)
    lamp = K.mat("Car Lamp", (1.0, 0.95, 0.8), rough=0.1, emit=0.6)

    def build(col, high):
        obs = []
        s32, s16, s8 = (32, 16, 8) if high else (14, 8, 4)
        # Godot (x, y, z) -> Blender (x, -z, y)
        def at(x, y, z):
            return (x, -z, y)
        obs.append(K.box("Chassis", (1.7, 3.9, 0.3), at=at(0, 0.75, 0), m=black, bevel=0.02 if high else 0, col=col))
        # hood with louvres and a centre hinge
        obs.append(K.box("Hood", (1.15, 1.3, 0.62), at=at(0, 1.2, 1.2), m=paint, bevel=0.06 if high else 0.03, seg=3,
                         col=col))
        if high:
            for s in (-1, 1):
                for k in range(9):
                    obs.append(K.box("Louvre", (0.02, 0.05, 0.28), at=at(s * 0.58, 1.18, 0.75 + k * 0.1), m=black,
                                     bevel=0.005, col=col))
            obs.append(rod("Hood Hinge", at(0, 1.52, 0.56), at(0, 1.52, 1.84), 0.018, brass, col))
        # radiator: a brass shell round a grille, a cap with a little mascot
        obs.append(K.box("Radiator", (1.0, 0.12, 0.78), at=at(0, 1.22, 1.88), m=brass, bevel=0.04 if high else 0,
                         col=col))
        if high:
            for k in range(11):
                obs.append(K.box("Grille", (0.015, 0.02, 0.62), at=at(-0.4 + k * 0.08, 1.2, 1.95), m=black, col=col))
            obs.append(K.cyl("Rad Cap", 0.05, 0.06, at=at(0, 1.65, 1.86), m=brass, seg=12, col=col))
            obs.append(K.sphere("Mascot", 0.05, at=at(0, 1.72, 1.86), m=brass, seg=12, scale=(0.6, 1.4, 1), col=col))
        # body (the tub), with a moulding line and doors
        obs.append(K.box("Body", (1.6, 1.9, 0.8), at=at(0, 1.3, -0.6), m=paint, bevel=0.08 if high else 0.04, seg=3,
                         col=col))
        if high:
            for s in (-1, 1):
                obs.append(K.box("Moulding", (0.02, 1.86, 0.03), at=at(s * 0.805, 1.55, -0.6), m=brass, bevel=0.006,
                                 col=col))
                obs.append(K.box("Door Line", (0.012, 0.012, 0.66), at=at(s * 0.805, 1.28, -0.2), m=black, col=col))
                obs.append(K.box("Door Line", (0.012, 0.012, 0.66), at=at(s * 0.805, 1.28, -1.0), m=black, col=col))
                obs.append(K.box("Handle", (0.03, 0.12, 0.025), at=at(s * 0.82, 1.48, -0.3), m=brass, bevel=0.006,
                                 col=col))
        # seats: buttoned leather, front and back
        for zz in (0.0, -1.0):
            obs.append(K.box("Seat", (1.36, 0.5, 0.18), at=at(0, 1.78, zz - 0.05), m=leather,
                             bevel=0.05 if high else 0, col=col))
            obs.append(K.box("Seat Back", (1.36, 0.14, 0.5), at=at(0, 2.05, zz - 0.32), m=leather,
                             bevel=0.05 if high else 0, col=col))
            if high:
                for i in range(5):
                    for j in range(2):
                        obs.append(K.sphere("Button", 0.014, at=at(-0.5 + i * 0.25, 1.95 + j * 0.18, zz - 0.245),
                                            m=leather, seg=6, col=col))
        # the roof: a cream canvas top on four black posts, with ribs
        obs.append(K.box("Roof", (1.7, 2.0, 0.1), at=at(0, 2.5, -0.65), m=cream, bevel=0.04 if high else 0, col=col))
        if high:
            for k in range(5):
                obs.append(rod("Roof Rib", at(-0.84, 2.46, 0.25 - k * 0.45), at(0.84, 2.46, 0.25 - k * 0.45), 0.018,
                               cream, col))
        for s in (-1, 1):
            for zz in (0.3, -1.6):
                obs.append(K.cyl("Roof Post", 0.035, 0.8, at=at(s * 0.78, 2.05, zz), m=black, seg=s8, col=col))
        # windscreen frame (the glass is the builder's)
        obs.append(K.box("Screen Frame", (1.44, 0.04, 0.04), at=at(0, 2.29, 0.32), m=brass, col=col))
        obs.append(K.box("Screen Frame", (1.44, 0.04, 0.04), at=at(0, 1.71, 0.32), m=brass, col=col))
        # steering wheel on its column
        obs.append(rod("Column", at(-0.35, 1.45, 0.45), at(-0.35, 1.95, 0.15), 0.025, black, col, seg=s8))
        wheel = [(-0.35 + 0.2 * math.cos(a), *at(0, 1.97 + 0.2 * math.sin(a) * 0.5, 0.13 - 0.2 * math.sin(a) * 0.86)[1:])
                 for a in [i / 24 * math.tau for i in range(24)]]
        obs.append(K.wire("Steering Wheel", wheel, 0.018, black, closed=True, res=3 if high else 1,
                          bevel_res=2 if high else 0, col=col))
        # running boards, fenders, wheels
        for s in (-1, 1):
            obs.append(K.box("Running Board", (0.3, 2.6, 0.05), at=at(s * 0.95, 0.6, 0), m=black,
                             bevel=0.01 if high else 0, col=col))
            if high:
                for k in range(12):
                    obs.append(K.box("Board Strip", (0.26, 0.015, 0.012), at=at(s * 0.95, 0.63, -1.15 + k * 0.21),
                                     m=brass, col=col))
            for zz in (1.3, -1.3):
                # fender: a curved shell over the wheel
                fen = K.sphere("Fender", 0.62, at=at(s * 0.88, 0.95, zz), m=paint, seg=s32, col=col,
                               scale=(0.55, 1.0, 1.0))
                obs.append(fen)
                # tyre and spoked wheel
                t = K.lathe("Tyre", [(0.0, -0.12), (0.34, -0.12), (0.46, -0.11), (0.48, -0.06), (0.48, 0.06),
                                     (0.46, 0.11), (0.34, 0.12), (0.0, 0.12)], seg=s32, m=tyre, col=col)
                t.location = at(s * 0.88, 0.48, zz)
                t.rotation_euler = (0, math.pi / 2, 0)
                obs.append(t)
                hub = at(s * 0.88 + s * 0.13, 0.48, zz)
                obs.append(K.cyl("Hub", 0.12, 0.06, at=hub, rot=(0, math.pi / 2, 0), m=brass, seg=s16, col=col))
                if high:
                    for k in range(12):
                        a = k / 12 * math.tau
                        e = (hub[0], hub[1] + math.cos(a) * 0.33, hub[2] + math.sin(a) * 0.33)
                        obs.append(rod("Spoke", hub, e, 0.022, spoke, col, seg=6, r2=0.014))
                    for k in range(40):
                        a = k / 40 * math.tau
                        c = at(s * 0.88, 0.48, zz)
                        obs.append(K.box("Tread", (0.22, 0.04, 0.025), at=(c[0], c[1] + math.cos(a) * 0.475,
                                                                         c[2] + math.sin(a) * 0.475),
                                         rot=(a, 0, 0), m=tyre, col=col))
                else:
                    obs.append(K.cyl("Wheel Disc", 0.34, 0.05, at=hub, rot=(0, math.pi / 2, 0), m=spoke, seg=s16,
                                     col=col))
            # headlamps: brass bowls with glowing lenses, on little stalks
            hp = at(s * 0.48, 1.45, 1.95)
            obs.append(K.sphere("Headlamp", 0.2, at=hp, m=brass, seg=s16, col=col))
            obs.append(K.cyl("Lens", 0.15, 0.04, at=(hp[0], hp[1] - 0.18, hp[2]), rot=(math.pi / 2, 0, 0), m=lamp,
                             seg=s16, col=col))
            obs.append(K.cyl("Lamp Stalk", 0.025, 0.4, at=at(s * 0.48, 1.12, 1.95), m=brass, seg=s8, col=col))
            # side lanterns by the screen
            obs.append(K.box("Side Lamp", (0.12, 0.12, 0.2), at=at(s * 0.84, 1.75, 0.38), m=brass,
                             bevel=0.02 if high else 0, col=col))
        # the horn: a brass trumpet with a black bulb, on the right side
        if high:
            horn = []
            for i in range(9):
                t = i / 8
                horn.append(at(0.72 - 0.0, 1.68, 0.5 + t * 0.7))
            obs.append(K.wire("Horn", horn, 0.02, brass, res=4, bevel_res=2, col=col))
            obs.append(K.cyl("Horn Bell", 0.03, 0.12, at=at(0.72, 1.68, 1.25), rot=(math.pi / 2, 0, 0), m=brass,
                             seg=16, r2=0.09, col=col))
            obs.append(K.sphere("Horn Bulb", 0.06, at=at(0.72, 1.68, 0.46), m=black, seg=12, col=col))
        # bumpers and the spare at the back
        obs.append(rod("Bumper", at(-0.85, 0.62, 2.08), at(0.85, 0.62, 2.08), 0.04, brass, col, seg=s8))
        obs.append(rod("Bumper", at(-0.85, 0.62, -2.05), at(0.85, 0.62, -2.05), 0.04, brass, col, seg=s8))
        sp = K.lathe("Spare", [(0.0, -0.1), (0.25, -0.1), (0.43, -0.09), (0.45, -0.04), (0.45, 0.04), (0.43, 0.09),
                               (0.25, 0.1), (0.0, 0.1)], seg=s32, m=tyre, col=col)
        sp.location = at(0, 1.3, -2.02)
        sp.rotation_euler = (math.pi / 2, 0, 0)
        obs.append(sp)
        obs.append(K.cyl("Spare Cover", 0.27, 0.21, at=at(0, 1.3, -2.02), rot=(math.pi / 2, 0, 0), m=cream, seg=s16,
                         col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the picnic basket
def picnic_basket():
    wicker = K.mat("Wicker", (0.247, 0.644, 0.6), rough=0.85)
    nt, b, co = _nodes(wicker)
    # basket weave: two sets of bands crossing, under and over
    w1 = nt.nodes.new("ShaderNodeTexWave")
    w1.bands_direction = "X"
    w1.inputs["Scale"].default_value = 55.0
    nt.links.new(co, w1.inputs["Vector"])
    w2 = nt.nodes.new("ShaderNodeTexWave")
    w2.bands_direction = "Z"
    w2.inputs["Scale"].default_value = 55.0
    nt.links.new(co, w2.inputs["Vector"])
    mx = nt.nodes.new("ShaderNodeMath")
    mx.operation = "MAXIMUM"
    nt.links.new(w1.outputs["Fac"], mx.inputs[0])
    nt.links.new(w2.outputs["Fac"], mx.inputs[1])
    bn = nt.nodes.new("ShaderNodeBump")
    bn.inputs["Strength"].default_value = 0.5
    bn.inputs["Distance"].default_value = 0.004
    nt.links.new(mx.outputs[0], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    nt.links.new(_mix_rgb(nt, mx.outputs[0], (0.15, 0.42, 0.39), (0.3, 0.72, 0.66)), b.inputs["Base Color"])
    rim = K.mat("Wicker Rim", (0.2, 0.55, 0.5), rough=0.8, bump=0.4)
    cloth = K.mat("Check Cloth", (0.95, 0.4, 0.4), rough=0.9)
    nt, b, co = _nodes(cloth)
    chk = nt.nodes.new("ShaderNodeTexChecker")
    chk.inputs["Scale"].default_value = 14.0
    K._rgba(chk.inputs, "Color1").default_value = (0.9, 0.25, 0.3, 1)
    K._rgba(chk.inputs, "Color2").default_value = (0.98, 0.95, 0.92, 1)
    nt.links.new(co, chk.inputs["Vector"])
    nt.links.new(chk.outputs["Color"], b.inputs["Base Color"])
    leather = K.mat("Basket Strap", (0.4, 0.24, 0.14), rough=0.6)

    def build(col, high):
        obs = []
        W, L, H = 0.6, 0.4, 0.4
        obs.append(K.box("Basket", (W, L, H - 0.06), at=(0, 0, (H - 0.06) / 2), m=wicker, bevel=0.03 if high else 0.015,
                         col=col))
        # two lids hinged in the middle, one propped a little open with the cloth peeking out
        obs.append(K.box("Lid", (W / 2 - 0.01, L + 0.02, 0.03), at=(-W / 4, 0, H - 0.045), m=wicker,
                         bevel=0.01 if high else 0, col=col))
        obs.append(K.box("Lid", (W / 2 - 0.01, L + 0.02, 0.03), at=(W / 4 + 0.02, 0, H - 0.01), rot=(0, -0.25, 0),
                         m=wicker, bevel=0.01 if high else 0, col=col))
        obs.append(K.box("Cloth", (0.22, L - 0.02, 0.06), at=(W / 4, 0.0, H - 0.07), m=cloth,
                         bevel=0.02 if high else 0, col=col))
        if high:
            obs.append(K.box("Cloth Flap", (0.12, 0.16, 0.01), at=(W / 2 + 0.01, 0.05, H - 0.1), rot=(0, 1.2, 0.2),
                             m=cloth, bevel=0.004, col=col))
            for z in (0.04, H - 0.07):
                obs.append(K.box("Rim", (W + 0.012, L + 0.012, 0.025), at=(0, 0, z), m=rim, bevel=0.01, col=col))
            for x in (-W / 2 + 0.06, W / 2 - 0.06):
                obs.append(K.box("Strap", (0.03, L + 0.03, 0.012), at=(x, 0, H - 0.03), m=leather, col=col))
        # the handle: an arch over the lids
        pts = [(math.cos(a) * 0.22, 0.0, H - 0.04 + math.sin(a) * 0.2) for a in [i / 12 * math.pi for i in range(13)]]
        obs.append(K.wire("Handle", pts, 0.016, rim, res=6 if high else 2, bevel_res=2 if high else 0, col=col))
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


if KIND == "sailboat":
    (hh, hl), (sh, sl) = sailboat()
    hull = bake_part("sailboat_hull", hh, hl, 1024)
    # No AO for the sails: the cloth is two sides 12 mm apart, and each side shadowed the other to a dull grey.
    sail = bake_part("sailboat_sail", sh, sl, 512, extrusion=0.02, ray=0.05, ao=False)
    parts = [hull, sail]
else:
    fn, size, emit, strength = {"crystal": (crystal, 512, True, 1.1), "dome_door": (dome_door, 1024, True, 1.0),
                                "antique_car": (antique_car, 2048, True, 1.0),
                                "picnic_basket": (picnic_basket, 512, False, 1.0)}[KIND]
    high, low = fn()
    parts = [bake_part(NAME, high, low, size, emit=emit, emit_strength=strength,
                       extrusion=0.01 if KIND == "crystal" else 0.03, ray=0.03 if KIND == "crystal" else 0.1)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

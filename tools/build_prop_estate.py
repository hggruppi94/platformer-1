# The rebuilt Secret Garden's stonework (scripts/secret_garden_kit.gd and secret_garden_estate.gd, 26 Nov 2026, Hayden:
# "start over from scratch and make it 10x better", "way bigger"), built the detailed way (tools/bake_kit.py). Each HIGH
# version is baked onto a LOW one, which is what the game draws.
#
# Every piece is made in the space of the plain lathe it replaces, so the kit puts each one where the old ones were and
# every collision stays the game's. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   baluster         one vase baluster of the terrace and bridge balustrades, 0.65 m from its foot: fluted belly,
#                    rings at its neck, weathered stone with a little moss low down.
#   urn              a garden urn, 0.82 m from its foot: a gadrooned bowl, egg-and-dart rim, a carved band of leaves,
#                    a stepped foot.
#   tiered_fountain  the Great Fountain's column and its two tiers of basins (6.9 m), in the fountain's space: a
#                    carved column with dolphins' scrolls, scalloped basin lips, lion masks, the finial on top. Its
#                    pool, water sheets and jets stay the game's.
# Colours are the game's own (sRGB); the stone is "Estate Stone".
#
#   python tools/build_prop_estate.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["baluster", "urn", "tiered_fountain", "window_light", "rose_bush", "ivy_clump", "supertree_trunk",
         "supertree_canopy"]
KIND = next((a for a in sys.argv if a in KINDS), "baluster")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

STONE = (0.6, 0.58, 0.6)
STONE_PALE = (0.72, 0.7, 0.72)
STONE_DARK = (0.47, 0.46, 0.5)
MOSS = (0.36, 0.48, 0.28)
WATER = (0.36, 0.62, 0.58)


def at(x, y, z):
    """Godot's (x, y, z) in Blender's space."""
    return (x, -z, y)


def glathe(name, prof, m, col, seg=32, pos=(0, 0, 0), **kw):
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


def _patches(nt, co, scale, lo, hi, w=None):
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 6.0
    if w is not None:
        nz.noise_dimensions = "4D"
        nz.inputs["W"].default_value = w
    nt.links.new(co, nz.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = lo
    mr.inputs["From Max"].default_value = hi
    nt.links.new(nz.outputs["Fac"], mr.inputs["Value"])
    return mr.outputs["Result"]


def weathered(name, scale=5.0):
    """The estate's grey stone, mottled paler and darker, with lichen patches."""
    m = K.mat(name, STONE, rough=0.85, bump=0.35)
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    co = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    c = _mix_rgb(nt, _patches(nt, co, scale, 0.35, 0.7), STONE_PALE, STONE_DARK)
    c = _mix_rgb(nt, _patches(nt, co, scale * 1.7, 0.63, 0.67, w=2.7), c, MOSS)
    nt.links.new(c, bsdf.inputs["Base Color"])
    return m


def bake_part(name, high, low, size, extrusion=0.03, ray=0.1, ao=True, emit=False, emit_strength=1.0):
    hi_tris = K.tri_count(high)
    prop = K.join(name, low)
    lo_tris = K.tri_count([prop])
    K.uv_unwrap(prop, margin=0.006)
    maps = K.bake(prop, high, size=size, name=name, extrusion=extrusion, ray=ray,
                  maps=["normal"] + (["ao"] if ao else []) + ["color", "rough", "metal"] + (["emit"] if emit else []))
    K.finish(prop, maps, size, name, emit_strength=emit_strength)
    print("TRIS %s high %d low %d" % (name, hi_tris, lo_tris))
    return prop


def ring_of(obs, n, r, y, make):
    """n copies round Godot's y at radius r and height y: make(name, pos, angle)."""
    for k in range(n):
        a = k * math.tau / n
        obs.append(make(k, (math.cos(a) * r, y, math.sin(a) * r), a))


# ================================================================ baluster
# The same profile as secret_garden_kit.gd finish(), so it stands where the plain one did.
BALUSTER = [(0.1, 0.0), (0.1, 0.05), (0.065, 0.08), (0.05, 0.13), (0.105, 0.27), (0.115, 0.33), (0.085, 0.42),
            (0.042, 0.52), (0.052, 0.56), (0.085, 0.6), (0.085, 0.65)]


def baluster():
    stone = weathered("Estate Stone", scale=14.0)
    moss = K.mat("Moss", MOSS, rough=0.95, bump=0.3)

    def build(col, high):
        if not high:
            return [glathe("Baluster", BALUSTER, stone, col, seg=10)]
        prof = []
        for i in range(len(BALUSTER) - 1):             # many rings so the belly's flutes and the neck's beads read
            (r0, y0), (r1, y1) = BALUSTER[i], BALUSTER[i + 1]
            for s in range(6):
                t = s / 6
                prof.append((r0 + (r1 - r0) * t, y0 + (y1 - y0) * t))
        prof.append(BALUSTER[-1])
        obs = [glathe("Baluster", prof, stone, col, seg=96, flutes=12, flute_depth=0.008, flute_z=(0.16, 0.4))]
        for y, r in [(0.05, 0.104), (0.535, 0.05), (0.6, 0.088)]:   # beads at the foot, the neck and under the cap
            obs.append(glathe("Bead", [(r, y - 0.008), (r + 0.008, y), (r, y + 0.008)], stone, col, seg=64))
        rnd = random.Random(11)
        for k in range(6):                              # a little moss at the foot
            a = rnd.uniform(0, math.tau)
            obs.append(blob("Moss", rnd.uniform(0.02, 0.035), (math.cos(a) * 0.1, 0.01, math.sin(a) * 0.1), moss, col,
                            seed=k, seg=8, lump=0.4, squash=(1.3, 0.4, 1.0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ urn
URN = [(0.0, 0.0), (0.19, 0.0), (0.19, 0.07), (0.1, 0.11), (0.08, 0.22), (0.15, 0.28), (0.3, 0.44), (0.36, 0.6),
       (0.34, 0.7), (0.41, 0.74), (0.41, 0.8), (0.3, 0.82), (0.0, 0.8)]


def urn():
    stone = weathered("Estate Stone", scale=8.0)
    soil = K.mat("Urn Soil", (0.26, 0.2, 0.18), rough=1.0, bump=0.4)
    leaf = K.mat("Urn Leaf", (0.24, 0.42, 0.22), rough=0.8)

    def build(col, high):
        if not high:
            return [glathe("Urn", URN, stone, col, seg=14)]
        prof = [URN[0], URN[1], URN[2], URN[3], URN[4], URN[5]]
        for s in range(1, 9):                           # the bowl, gadrooned (fluted) up from the stem
            t = s / 8
            prof.append((0.15 + (0.3 - 0.15) * t, 0.28 + 0.16 * t))
        prof += [URN[7], URN[8], URN[9], URN[10], URN[11], URN[12]]
        obs = [glathe("Urn", prof, stone, col, seg=128, flutes=20, flute_depth=0.022, flute_z=(0.28, 0.5))]
        obs.append(glathe("Soil", [(0.0, 0.79), (0.3, 0.79), (0.3, 0.8), (0.0, 0.8)], soil, col, seg=48))
        for y, r in [(0.07, 0.19), (0.22, 0.085), (0.74, 0.412)]:
            obs.append(glathe("Bead", [(r, y - 0.012), (r + 0.012, y), (r, y + 0.012)], stone, col, seg=96))

        def egg(k, pos, a):                             # egg-and-dart round the rim
            return blob("Egg", 0.022, pos, stone, col, seed=k, seg=8, lump=0.1, squash=(1.0, 1.4, 0.7))
        ring_of(obs, 40, 0.41, 0.77, egg)

        def leafy(k, pos, a):                           # a band of acanthus leaves round the belly
            return blob("Leaf Carving", 0.05, pos, stone, col, seed=k + 50, seg=10, lump=0.3, squash=(0.8, 1.5, 0.4))
        ring_of(obs, 16, 0.355, 0.6, leafy)
        rnd = random.Random(5)
        for k in range(10):                             # a few trailing leaves spilling over the rim
            a = rnd.uniform(0, math.tau)
            obs.append(blob("Trailing Leaf", rnd.uniform(0.04, 0.06), (math.cos(a) * 0.38, 0.8, math.sin(a) * 0.38),
                            leaf, col, seed=k, seg=8, lump=0.3, squash=(1.2, 0.5, 1.0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ tiered fountain
# The same profile as secret_garden_estate.gd _tiered_fountain()'s plain lathe.
TIERS = [(1.6, 0.0), (1.6, 0.5), (1.0, 0.7), (0.7, 1.2), (0.6, 2.6), (3.2, 2.9), (3.4, 3.3), (3.0, 3.35), (0.5, 3.4),
         (0.45, 4.8), (1.9, 5.0), (2.0, 5.3), (1.7, 5.35), (0.35, 5.4), (0.3, 6.2), (0.55, 6.5), (0.0, 6.9)]


def tiered_fountain():
    stone = weathered("Estate Stone", scale=2.5)
    water = K.mat("Tier Water", WATER, rough=0.1)

    def build(col, high):
        if not high:
            return [glathe("Fountain Tiers", TIERS, stone, col, seg=24)]
        obs = [glathe("Pedestal", TIERS[:5], stone, col, seg=128, flutes=16, flute_depth=0.06, flute_z=(0.75, 2.5)),
               glathe("Lower Basin", TIERS[4:9], stone, col, seg=160, flutes=36, flute_depth=0.05, flute_z=(2.65, 3.25)),
               glathe("Upper Column", TIERS[8:10], stone, col, seg=96, flutes=12, flute_depth=0.04, flute_z=(3.5, 4.7)),
               glathe("Upper Basin", TIERS[9:14], stone, col, seg=128, flutes=28, flute_depth=0.04, flute_z=(4.85, 5.25)),
               glathe("Finial", TIERS[13:], stone, col, seg=64)]
        obs.append(glathe("Lower Water", [(0.0, 3.3), (3.0, 3.3), (3.0, 3.31), (0.0, 3.31)], water, col, seg=64))
        obs.append(glathe("Upper Water", [(0.0, 5.28), (1.7, 5.28), (1.7, 5.29), (0.0, 5.29)], water, col, seg=48))
        for y, r in [(0.5, 1.6), (3.3, 3.4), (5.3, 2.0)]:   # rolled lips
            obs.append(glathe("Lip", [(r - 0.02, y - 0.06), (r + 0.04, y), (r - 0.02, y + 0.06)], stone, col, seg=160))

        def mask(k, pos, a):                            # lion masks round the pedestal's foot
            return blob("Lion Mask", 0.22, pos, stone, col, seed=k, seg=14, lump=0.35, squash=(1.0, 1.1, 0.55))
        ring_of(obs, 4, 1.62, 0.28, mask)

        def scroll(k, pos, a):                          # scrolled brackets under the lower basin
            return blob("Bracket", 0.28, pos, stone, col, seed=k + 20, seg=12, lump=0.3, squash=(0.6, 1.4, 0.6))
        ring_of(obs, 8, 1.0, 2.55, scroll)

        def shell(k, pos, a):                           # shells round the upper basin's underside
            return blob("Shell", 0.16, pos, stone, col, seed=k + 40, seg=10, lump=0.25, squash=(1.2, 0.6, 0.5))
        ring_of(obs, 10, 1.25, 4.9, shell)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ shared bits for the leafy and steel pieces
LEAF_DARK = (0.16, 0.3, 0.17)
LEAF = (0.22, 0.4, 0.22)
LEAF_PALE = (0.32, 0.5, 0.28)


def surface_points(bm, n, rng, keep=None):
    """n points spread evenly over a bmesh's faces (by area), each with its normal: [(co, normal)]."""
    bm.faces.ensure_lookup_table()
    faces = [f for f in bm.faces if f.calc_area() > 1e-9]
    areas = [f.calc_area() for f in faces]
    total = sum(areas)
    out = []
    tries = 0
    while len(out) < n and tries < n * 20:
        tries += 1
        pick = rng.random() * total
        acc = 0.0
        f = faces[-1]
        for face, a in zip(faces, areas):
            acc += a
            if acc >= pick:
                f = face
                break
        vs = [v.co for v in f.verts]
        # a random point in a random triangle of the face's fan
        k = rng.randrange(1, len(vs) - 1)
        u, v = rng.random(), rng.random()
        if u + v > 1.0:
            u, v = 1.0 - u, 1.0 - v
        p = vs[0] + (vs[k] - vs[0]) * u + (vs[k + 1] - vs[0]) * v
        nrm = f.normal.copy()
        if keep and not keep(p, nrm):
            continue
        out.append((p, nrm))
    return out


def leaves(name, spots, rng, length, mats, col, out=(0.0, 0.04), width=0.45, lift=0.35):
    """A leaf at each spot (co, normal), lying nearly flat on the surface, tip pointing a random way: each a diamond
    folded along its midrib. One object per material, picked at random."""
    bms = [bmesh.new() for _ in mats]
    for p, nrm in spots:
        nrm = nrm.normalized()
        t = nrm.orthogonal().normalized()
        t.rotate(__import__("mathutils").Quaternion(nrm, rng.random() * math.tau))
        b = nrm.cross(t).normalized()
        L = length * rng.uniform(0.7, 1.3)
        base = p + nrm * rng.uniform(*out)
        tip = base + t * L + nrm * L * lift * rng.uniform(0.4, 1.0)
        mid = base + t * L * 0.45 + nrm * L * 0.12
        left = mid + b * L * width * 0.5 - nrm * L * 0.06
        right = mid - b * L * width * 0.5 - nrm * L * 0.06
        bm = bms[rng.randrange(len(mats))]
        vb, vl, vt, vr = (bm.verts.new(c) for c in (base, left, tip, right))
        bm.faces.new((vb, vl, vt))
        bm.faces.new((vb, vt, vr))
    return [K._obj("%s %d" % (name, k), bm, m, False, col) for k, (bm, m) in enumerate(zip(bms, mats))]


def blob_bm(r, seed=0, seg=12, lump=0.25, squash=(1.0, 1.0, 1.0), pos=(0, 0, 0)):
    """blob()'s lumpy ball as a bmesh, in Blender's space, moved to Godot's pos."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(4, seg // 2), radius=r)
    off = Vector((seed * 3.17, seed * 1.71, seed * 2.33))
    o = Vector(at(*pos))
    for v in bm.verts:
        nn = v.co.normalized()
        v.co = v.co * (1.0 + lump * noise.noise(nn * 1.6 + off))
        v.co.x *= squash[0]
        v.co.y *= squash[2]
        v.co.z *= squash[1]
        v.co += o
    bm.normal_update()
    return bm


def beam_bm(a, b, w, bm=None):
    """A square bar from a to b (Blender's space), w across, added to bm."""
    bm = bm or bmesh.new()
    a, b = Vector(a), Vector(b)
    d = b - a
    q = d.normalized().to_track_quat("Z", "Y")
    geo = bmesh.ops.create_cube(bm, size=1.0)
    vs = geo["verts"]
    bmesh.ops.scale(bm, vec=Vector((w, w, d.length)), verts=vs)
    bmesh.ops.rotate(bm, cent=Vector(), matrix=q.to_matrix(), verts=vs)
    bmesh.ops.translate(bm, vec=(a + b) / 2, verts=vs)
    return bm


def glow_mat(name, rgb, strength=3.0):
    return K.mat(name, rgb, rough=0.4, emit=strength, emit_rgb=rgb)


# ================================================================ window light
# One light of the Old House's leaded windows (secret_garden_estate.gd _window()'s "Panes"), 0.8 by 2.4 m, its front
# facing Godot's +Z: diamond quarries of hand-made amber glass in lead cames, a lead border and two iron saddle bars.
# The game stretches it to each light's size.
WIN_W = 0.8
WIN_H = 2.4


def window_light():
    glass = K.mat("Leaded Glass", (1.0, 0.8, 0.5), rough=0.2, emit=2.0, emit_rgb=(1.0, 0.78, 0.45), bump=0.5)
    nt = glass.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    co = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    c = _mix_rgb(nt, _patches(nt, co, 9.0, 0.3, 0.75), (1.0, 0.86, 0.55), (0.92, 0.6, 0.3))
    nt.links.new(c, bsdf.inputs["Base Color"])
    lead = K.mat("Lead Came", (0.2, 0.2, 0.22), rough=0.55, metal=0.6, pits=0.4)
    iron = K.mat("Saddle Bar", (0.16, 0.15, 0.16), rough=0.6, metal=0.7, pits=0.6)

    def build(col, high):
        if not high:
            bm = bmesh.new()                            # only its front shows, so the bake is all front
            vs = [bm.verts.new(at(x, y, 0.03)) for x, y in [(-WIN_W / 2, -WIN_H / 2), (WIN_W / 2, -WIN_H / 2),
                                                            (WIN_W / 2, WIN_H / 2), (-WIN_W / 2, WIN_H / 2)]]
            bm.faces.new(vs)
            return [K._obj("Window Light", bm, glass, False, col)]
        obs = [K.box("Glass", (WIN_W - 0.02, 0.02, WIN_H - 0.02), at=at(0, 0, 0.01), m=glass, col=col)]
        hw, hh = WIN_W / 2 - 0.02, WIN_H / 2 - 0.02
        s = 0.17                                            # quarry size along each diagonal
        for sign in (1.0, -1.0):
            k = -int((hw + hh) / s) - 1
            while k * s < hw + hh + s:
                c0 = k * s                                  # the line x*sign - y = c0
                pts = []
                for x in (-hw, hw):
                    y = x * sign - c0
                    if -hh <= y <= hh:
                        pts.append((x, y))
                for y in (-hh, hh):
                    x = (y + c0) * sign
                    if -hw <= x <= hw:
                        pts.append((x, y))
                if len(pts) >= 2:
                    pts.sort()
                    (x0, y0), (x1, y1) = pts[0], pts[-1]
                    if math.hypot(x1 - x0, y1 - y0) > 0.03:
                        obs.append(K.wire("Came", [at(x0, y0, 0.024), at(x1, y1, 0.024)], 0.007, m=lead, res=2,
                                          bevel_res=2, col=col))
                k += 1
        for x0, y0, x1, y1 in [(-hw, -hh, hw, -hh), (hw, -hh, hw, hh), (hw, hh, -hw, hh), (-hw, hh, -hw, -hh)]:
            obs.append(K.wire("Border", [at(x0, y0, 0.026), at(x1, y1, 0.026)], 0.016, m=lead, res=2, col=col))
        for y in (-WIN_H / 6, WIN_H / 6):
            obs.append(K.wire("Saddle Bar", [at(-hw - 0.02, y, 0.03), at(hw + 0.02, y, 0.03)], 0.011, m=iron, res=2,
                              col=col))
            for x in (-hw * 0.5, 0.0, hw * 0.5):
                obs.append(K.sphere("Tie", 0.012, at=at(x, y, 0.035), m=lead, seg=8, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ rose bush
# The Formal Garden's rose bushes (secret_garden_estate.gd _formal_garden()'s leafy balls and their three roses), in
# the ball's own space: a mound of little leaves with roses opening all over its top, white ones and blush ones mixed.
ROSE_R = 0.45
ROSE_SQUASH = 0.8


def _rose(name, pos, nrm, r, m, col, rng):
    """An open rose at pos (Blender's space), facing nrm: a tight middle and two rings of cupped petals."""
    obs = []
    up = nrm.normalized()
    t = up.orthogonal().normalized()
    b = up.cross(t)
    p = Vector(pos)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=r * 0.35)
    for v in bm.verts:
        v.co = p + up * r * 0.15 + v.co
    obs.append(K._obj(name + " Heart", bm, m, True, col))
    for ring, (n, out, size, tilt) in enumerate([(5, 0.45, 0.5, 0.35), (7, 0.85, 0.55, 0.7)]):
        phase = rng.random() * math.tau
        for k in range(n):
            a = phase + k * math.tau / n
            d = t * math.cos(a) + b * math.sin(a)
            c = p + d * r * out + up * r * (0.12 - 0.12 * ring)
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=r * size)
            for v in bm.verts:
                # a flattened cup: thin along its tilted face normal
                fn = (up * math.cos(tilt) + d * math.sin(tilt)).normalized()
                along = v.co.dot(fn)
                v.co = c + (v.co - fn * along) + fn * along * 0.3
            obs.append(K._obj(name + " Petal", bm, m, True, col))
    return obs


def rose_bush():
    dark = K.mat("Rose Bush Core", (0.08, 0.16, 0.09), rough=0.9)
    lmats = [K.mat("Rose Leaf %d" % k, c, rough=0.7, bump=0.3) for k, c in enumerate([LEAF_DARK, LEAF, LEAF_PALE])]
    white = K.mat("Rose White", (0.97, 0.95, 0.9), rough=0.6, bump=0.2)
    blush = K.mat("Rose Blush", (0.98, 0.74, 0.8), rough=0.6, bump=0.2)

    def build(col, high):
        bm = blob_bm(ROSE_R, seed=5, seg=16, lump=0.14, squash=(1.0, ROSE_SQUASH, 1.0))
        if not high:
            return [K._obj("Rose Bush", bm, dark, True, col)]
        rng = random.Random(11)
        spots = surface_points(bm, 2600, rng)
        obs = leaves("Rose Leaves", spots, rng, 0.07, lmats, col, out=(0.0, 0.035))
        tops = surface_points(bm, 11, random.Random(4), keep=lambda p, n: n.z > 0.15)
        for k, (p, n) in enumerate(tops):
            obs += _rose("Rose", p + n.normalized() * 0.04, n, rng.uniform(0.05, 0.07), white if k % 2 else blush, col,
                         rng)
        obs.append(K._obj("Rose Bush Core", bm, dark, True, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ ivy clump
# The Sunken Quarry Garden's clumps of ivy on its cliffs (secret_garden_rooms.gd "Cliff Ivy"), radius 1 squashed to
# 0.7 tall: thick overlapping ivy leaves over a dark tangle, a few stems showing. The game scales it to each clump.
def ivy_clump():
    dark = K.mat("Ivy Core", (0.06, 0.12, 0.07), rough=0.9)
    lmats = [K.mat("Ivy Leaf %d" % k, c, rough=0.45, bump=0.4)
             for k, c in enumerate([(0.12, 0.27, 0.14), (0.17, 0.34, 0.18), (0.26, 0.43, 0.22)])]
    stem = K.mat("Ivy Stem", (0.32, 0.25, 0.18), rough=0.8)

    def build(col, high):
        bm = blob_bm(1.0, seed=9, seg=18, lump=0.16, squash=(1.0, 0.7, 1.0))
        if not high:
            return [K._obj("Ivy Clump", bm, dark, True, col)]
        rng = random.Random(21)
        obs = leaves("Ivy Leaves", surface_points(bm, 3400, rng), rng, 0.16, lmats, col, out=(0.0, 0.07),
                     width=0.85, lift=0.2)
        for k in range(10):
            a = rng.random() * math.tau
            pts = []
            for i in range(6):
                t = i / 5.0
                el = math.radians(60 - 110 * t)
                pts.append(at(math.cos(a + t * 0.6) * math.cos(el) * 1.02, math.sin(el) * 0.72,
                              math.sin(a + t * 0.6) * math.cos(el) * 1.02))
            obs.append(K.wire("Ivy Vine", pts, 0.012, m=stem, res=6, bevel_res=2, col=col))
        obs.append(K._obj("Ivy Core", bm, dark, True, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ supertree trunk
# The Supertree Grove's planted trunks (secret_garden_groves.gd _supertree()): the hanging garden up its trunk and the
# spiral of steel ribs round it, made for a trunk 13 m tall from radius 1.6 at its foot to 0.8 at its top. The game
# stretches it to each tree (and the solid trunk inside stays the game's). Ferns, bromeliads and moss on the planted
# panels, glowing pink and gold flowers dotted up them, ten steel ribs spiralling round with hoops tying them.
ST_H = 13.0
ST_R0 = 1.6
ST_R1 = 0.8


def _st_r(y, extra=0.0):
    return ST_R0 + (ST_R1 - ST_R0) * (y / ST_H) + extra


def supertree_trunk():
    steel = K.mat("Supertree Steel", (0.42, 0.34, 0.4), rough=0.45, metal=0.6, pits=0.4)
    soil = K.mat("Supertree Moss", (0.12, 0.22, 0.12), rough=0.95, bump=0.6)
    lmats = [K.mat("Supertree Fern %d" % k, c, rough=0.7, bump=0.2)
             for k, c in enumerate([(0.14, 0.32, 0.16), (0.22, 0.42, 0.2), (0.3, 0.5, 0.24), (0.42, 0.3, 0.36)])]
    pink = glow_mat("Supertree Bloom Pink", (1.0, 0.45, 0.85))
    gold = glow_mat("Supertree Bloom Gold", (1.0, 0.8, 0.35))
    violet = glow_mat("Supertree Bloom Violet", (0.75, 0.45, 1.0))

    def lathe_r(name, extra, m, col, seg, y0=0.0, y1=ST_H, rows=14):
        prof = [(_st_r(y0 + (y1 - y0) * i / rows, extra), y0 + (y1 - y0) * i / rows) for i in range(rows + 1)]
        return glathe(name, prof, m, col, seg=seg)

    def build(col, high):
        if not high:
            return [lathe_r("Supertree Garden", 0.42, soil, col, 20)]
        rng = random.Random(31)
        obs = [lathe_r("Planting", 0.12, soil, col, 48, 1.0, ST_H - 1.0, rows=24)]
        # leaves over the planting, sampled from a fine copy of it
        bm = bmesh.new()
        bm.from_mesh(obs[0].data)
        bmesh.ops.translate(bm, vec=obs[0].location, verts=bm.verts)
        bm.normal_update()
        for f in bm.faces:                      # the lathe's faces must face out
            mid = f.calc_center_median()
            if f.normal.dot(Vector((mid.x, mid.y, 0))) < 0:
                f.normal_flip()
        spots = surface_points(bm, 9000, rng)
        obs += leaves("Fern", spots, rng, 0.26, lmats, col, out=(0.0, 0.1), width=0.35, lift=0.5)
        for k, (p, n) in enumerate(surface_points(bm, 140, random.Random(7))):
            m = (pink, gold, violet)[k % 3]
            obs.append(K.sphere("Bloom", rng.uniform(0.06, 0.11), at=tuple(p + n.normalized() * 0.12), m=m, seg=8,
                                col=col))
        # ten ribs spiralling up, hoops every two metres, bolts where they cross
        for i in range(10):
            a = math.tau * i / 10
            pts = []
            for j in range(14):
                y = ST_H * j / 13
                ang = a + 0.9 * j / 13
                r = _st_r(y, 0.22)
                pts.append(at(math.cos(ang) * r, y, math.sin(ang) * r))
            obs.append(K.wire("Rib", pts, 0.07, m=steel, res=4, bevel_res=3, col=col))
        for y in [0.6 + 2.0 * k for k in range(7)]:
            r = _st_r(y, 0.24)
            pts = [at(math.cos(math.tau * k / 40) * r, y, math.sin(math.tau * k / 40) * r) for k in range(40)]
            obs.append(K.wire("Hoop", pts, 0.035, m=steel, closed=True, res=2, bevel_res=2, col=col))
            for i in range(10):
                ang = math.tau * i / 10 + 0.9 * y / ST_H
                obs.append(K.sphere("Bolt", 0.05, at=at(math.cos(ang) * (r + 0.02), y, math.sin(ang) * (r + 0.02)),
                                    m=steel, seg=8, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ supertree canopy
# The steel funnel at a supertree's top (_supertree()'s 16 canopy ribs), in the canopy's space: from radius 0.8 at the
# trunk's top (y 0) out to 5.5 at the rim (y 6). Real bars the game draws, ribs with braces between them and two hoops;
# baked with rivets, a truss in each rib and little ferns caught where the bars cross. The see-through funnel and the
# glowing rings stay the game's.
SC_R0 = 0.8
SC_R1 = 5.5
SC_H = 6.0


def _sc(a, t, out=0.0):
    r = SC_R0 + (SC_R1 - SC_R0) * t + out
    return Vector(at(math.cos(a) * r, SC_H * t, math.sin(a) * r))


def supertree_canopy():
    steel = K.mat("Supertree Steel", (0.42, 0.34, 0.4), rough=0.45, metal=0.6, pits=0.4)
    lmats = [K.mat("Canopy Fern %d" % k, c, rough=0.7) for k, c in enumerate([(0.18, 0.38, 0.2), (0.28, 0.48, 0.24)])]
    n = 16

    def build(col, high):
        if not high:
            bm = bmesh.new()
            for i in range(n):
                a = math.tau * i / n
                beam_bm(_sc(a, 0.0), _sc(a, 1.0), 0.34, bm)
                b = math.tau * (i + 1) / n
                beam_bm(_sc(a, 0.35), _sc(b, 0.7), 0.16, bm)
                beam_bm(_sc(b, 0.35), _sc(a, 0.7), 0.16, bm)
                for t in (0.35, 0.7, 1.0):
                    beam_bm(_sc(a, t), _sc(b, t), 0.2, bm)
            return [K._obj("Canopy Frame", bm, steel, False, col)]
        rng = random.Random(41)
        obs = []
        for i in range(n):
            a = math.tau * i / n
            b = math.tau * (i + 1) / n
            # each rib a little truss: two chords and a zig-zag between them
            for side in (-0.07, 0.07):
                obs.append(K.wire("Chord", [tuple(_sc(a + side / (SC_R0 + (SC_R1 - SC_R0) * t + 0.5), t))
                                            for t in (0.0, 0.5, 1.0)], 0.05, m=steel, res=4, bevel_res=3, col=col))
            for k in range(10):
                t0, t1 = k / 10, (k + 1) / 10
                s = 0.07 if k % 2 else -0.07
                obs.append(K.wire("Lacing", [tuple(_sc(a + s / (SC_R0 + 3 * t0 + 0.5), t0)),
                                             tuple(_sc(a - s / (SC_R0 + 3 * t1 + 0.5), t1))], 0.025, m=steel, res=2,
                                  bevel_res=2, col=col))
            obs.append(K.wire("Brace", [tuple(_sc(a, 0.35)), tuple(_sc(b, 0.7))], 0.06, m=steel, res=2, col=col))
            obs.append(K.wire("Brace", [tuple(_sc(b, 0.35)), tuple(_sc(a, 0.7))], 0.06, m=steel, res=2, col=col))
            for t in (0.35, 0.7, 1.0):
                obs.append(K.wire("Ring Bar", [tuple(_sc(a, t)), tuple(_sc(b, t))], 0.08, m=steel, res=2, col=col))
                obs.append(K.sphere("Rivet", 0.1, at=tuple(_sc(a, t)), m=steel, seg=10, col=col))
            # a tuft of fern where the braces cross
            mid = (_sc(a, 0.525) + _sc(b, 0.525)) / 2
            up = Vector((0, 0, 1))
            spots = [(mid + Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 0.0)),
                      (up + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0))).normalized()) for _ in range(22)]
            obs += leaves("Canopy Fern", spots, rng, 0.3, lmats, col, out=(0.0, 0.05), width=0.3, lift=0.6)
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "baluster": (baluster, 256, 0.02, 0.05, True, 0.0),
    "urn": (urn, 512, 0.03, 0.08, True, 0.0),
    "tiered_fountain": (tiered_fountain, 1024, 0.08, 0.2, True, 0.0),
    "window_light": (window_light, 1024, 0.02, 0.05, True, 1.6),
    "rose_bush": (rose_bush, 512, 0.12, 0.25, False, 0.0),
    "ivy_clump": (ivy_clump, 512, 0.2, 0.4, False, 0.0),
    "supertree_trunk": (supertree_trunk, 1024, 0.3, 0.6, True, 2.0),
    "supertree_canopy": (supertree_canopy, 1024, 0.06, 0.15, True, 0.0),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao, emit=emit > 0.0, emit_strength=max(emit, 1.0))]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

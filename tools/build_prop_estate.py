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

KINDS = ["baluster", "urn", "tiered_fountain"]
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


def bake_part(name, high, low, size, extrusion=0.03, ray=0.1, ao=True):
    hi_tris = K.tri_count(high)
    prop = K.join(name, low)
    lo_tris = K.tri_count([prop])
    K.uv_unwrap(prop, margin=0.006)
    maps = K.bake(prop, high, size=size, name=name, extrusion=extrusion, ray=ray,
                  maps=["normal"] + (["ao"] if ao else []) + ["color", "rough", "metal"])
    K.finish(prop, maps, size, name)
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


fn, size, ext, ray = {
    "baluster": (baluster, 256, 0.02, 0.05),
    "urn": (urn, 512, 0.03, 0.08),
    "tiered_fountain": (tiered_fountain, 1024, 0.08, 0.2),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

# The Gloop Kingdom (scripts/gloop_kingdom.gd), built the detailed way (tools/bake_kit.py; 22 Nov 2026, Hayden:
# "Okay time to bake more details"): the Palace Gate's towers and arch, the Royal Court's wall and its stands, the
# throne and its dais, the Bog Road's goo lanterns, the gooey rock spires round the edge and the Royal Treasure.
# Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Every piece is made in the space of the plain mesh it replaces (gloop_kingdom.gd's BoxMesh and CylinderMesh are
# centred on their node), so scripts/detail_props.gd dress_gloop_kingdom puts each one where the old one was and
# every collision stays the game's. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   gate_tower   a Palace Gate tower: 11 m, 2.6 across at the foot to 2.2 at the top (centred), lilac stone in
#                courses with staggered joints, a plinth, gold bands, glowing arched windows and corbels under its top.
#   gate_arch    the arch across the gate, 10.8 x 1.8 x 2.2: stone blocks, gold trim and a keystone, and a stone arch
#                curving down under it to the towers.
#   court_wall   one of the court wall's 28 pieces, 1.0 x 6.0 x 4.6 (its +x faces out): blocks both sides, a plinth,
#                a gold band, and battlements on top.
#   court_stand  a courtier's stand, 3.2 x 6.6 x 3.2: blocks, glowing arched niches and a gold rim round its top.
#   throne_dais  the throne's three round steps (6.0, 4.6 and 3.2 across, 0.5 high from 0.4 up, the top one gold),
#                in the Throne node's space, with a footing down to the floor, mouldings and gold inlays.
#   throne       the gold chair (seat, back and arms), in the Throne node's space: carved panels, an arched back,
#                pilasters, scrolled arms, rubies and ball feet.
#   goo_lantern  a Bog Road lantern post (0.25 x 3.0, centred): a fluted gold post on a stepped foot with a cage
#                round its glowing goo bulb (the bulb is the game's) and a little crown on top.
#   goo_spire    a rock spire round the kingdom's edge, at 3.5 across the foot, 0.75 at the top and 13 high (centred);
#                the game stretches it to each spire's own size. Banded purple rock with goo oozing down it.
#   chest_box    the Royal Treasure's chest, 1.4 x 0.8 x 0.9 (centred): planks, gold corners, straps and a lock.
#   chest_lid    its lid, 1.5 x 0.3 x 0.95 (centred), which opens: planks, gold bands and studs.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_gloop_kingdom.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["gate_tower", "gate_arch", "court_wall", "court_stand", "throne_dais", "throne", "goo_lantern", "goo_spire",
         "chest_box", "chest_lid"]
KIND = next((a for a in sys.argv if a in KINDS), "gate_tower")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

STONE = (0.74, 0.62, 0.88)
STONE_PALE = (0.84, 0.75, 0.95)
STONE_DARK = (0.6, 0.48, 0.76)
MORTAR = (0.48, 0.38, 0.6)
GOLD = (1.0, 0.78, 0.25)
GOLD_DARK = (0.82, 0.58, 0.16)
GOO = (0.55, 0.78, 0.2)
GOO_DEEP = (0.36, 0.58, 0.12)
GLOW = (0.7, 1.0, 0.35)
ROCK = (0.38, 0.26, 0.5)
ROCK_PALE = (0.5, 0.38, 0.64)
ROCK_DARK = (0.24, 0.16, 0.34)
WOOD = (0.5, 0.28, 0.15)
WOOD_DARK = (0.36, 0.19, 0.1)
RUBY = (0.95, 0.15, 0.25)


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


def stone_mats():
    """Three lilac stones for blocks (picked at random so the courses look laid by hand) and the mortar."""
    return ([mottled("Palace Stone", STONE, STONE_DARK, scale=4.0, rough=0.75, bump=0.35),
             mottled("Palace Stone Pale", STONE_PALE, STONE, scale=5.0, rough=0.7, bump=0.35),
             mottled("Palace Stone Deep", STONE, (0.66, 0.53, 0.82), scale=3.0, rough=0.8, bump=0.4)],
            K.mat("Mortar", MORTAR, rough=0.95, bump=0.3))


def gold_mat(name="Royal Gold"):
    return mottled(name, GOLD, GOLD_DARK, scale=7.0, rough=0.28, metal=0.85, bump=0.08)


def block_face(obs, col, mats, rnd, centre, u, n, width, height, course=0.6, block=(0.9, 1.5), depth=0.08,
               gap=0.035, bevel=0.025):
    """Stone blocks laid in courses over a flat face: centre is the face's middle (Godot), u its across direction
    (a unit x or z), n its outward normal, width and height its size. Each block's front lies on the face."""
    u, n = Vector(u), Vector(n)
    rows = max(1, round(height / course))
    ch = height / rows
    for r in range(rows):
        y = -height / 2 + ch * (r + 0.5)
        x = -width / 2 - (rnd.uniform(0.2, 0.6) if r % 2 else 0.0)
        while x < width / 2 - 0.05:
            w = rnd.uniform(*block)
            x0, x1 = max(x, -width / 2), min(x + w, width / 2)
            if x1 - x0 > 0.12:
                mid = Vector(centre) + u * ((x0 + x1) / 2) + Vector((0, y, 0)) - n * (depth / 2)
                size = u * (x1 - x0 - gap) + Vector((0, ch - gap, 0)) + n * depth
                obs.append(gbox("Block", (abs(size.x), abs(size.y), abs(size.z)), tuple(mid), rnd.choice(mats), col,
                                bevel=bevel))
            x += w


def course_lathe(r0, r1, y0, y1, course, groove=0.03):
    """A tapering round wall's profile from radius r0 at y0 to r1 at y1, with a little groove between courses."""
    prof = []
    rows = max(1, round((y1 - y0) / course))
    ch = (y1 - y0) / rows
    for k in range(rows):
        ya, yb = y0 + k * ch, y0 + (k + 1) * ch
        ra = r0 + (r1 - r0) * (ya - y0) / (y1 - y0)
        rb = r0 + (r1 - r0) * (yb - y0) / (y1 - y0)
        prof += [(ra - groove, ya), (ra, ya + 0.04), (rb, yb - 0.04), (rb - groove, yb)]
    return prof, rows, ch


def joints(obs, col, m, rnd, r0, r1, y0, y1, rows, ch, per_row, depth=0.05):
    """Thin dark joints standing up between the blocks of a round wall, staggered course by course."""
    for k in range(rows):
        ya = y0 + k * ch
        r = r0 + (r1 - r0) * (ya + ch / 2 - y0) / (y1 - y0)
        off = rnd.uniform(0, math.tau) if k % 2 else 0.0
        for j in range(per_row):
            a = off + j * math.tau / per_row + rnd.uniform(-0.05, 0.05)
            q = Vector((math.cos(a), 0, math.sin(a)))
            p = q * (r - depth * 0.3) + Vector((0, ya + ch / 2, 0))
            obs.append(gbox("Joint", (0.035, ch - 0.06, depth), tuple(p), m, col, rot=(0, -a + math.pi / 2, 0)))


def arch_window(obs, col, frame, pane, c, a, w, h, r_out):
    """A glowing arched window on a round wall at angle a (Godot), its middle c up, in a gold frame."""
    q = Vector((math.cos(a), 0, math.sin(a)))
    t = Vector((-q.z, 0, q.x))
    base = q * r_out + Vector((0, c, 0))
    obs.append(gbox("Pane", (w, h, 0.08), tuple(base - Vector((0, 0.1, 0))), pane, col, rot=(0, -a + math.pi / 2, 0)))
    pts = []
    for k in range(9):
        th = math.pi * k / 8
        pts.append(tuple(base + t * (math.cos(th) * w / 2) + Vector((0, h / 2 - 0.1 + math.sin(th) * w / 2, 0))))
    top = base + Vector((0, h / 2 - 0.1, 0))
    obs.append(grod("Pane Top", tuple(top - q * 0.04), tuple(top + q * 0.04), w / 2, pane, col, seg=16))
    side = [tuple(base - t * w / 2 + Vector((0, -h / 2 - 0.1, 0)))] + pts + [tuple(base + t * w / 2 +
                                                                              Vector((0, -h / 2 - 0.1, 0)))]
    obs.append(gwire("Frame", [tuple(Vector(p) + q * 0.03) for p in side], 0.06, frame, col, res=4, bevel_res=2))
    obs.append(gbox("Sill", (w + 0.3, 0.12, 0.25), tuple(base + q * 0.06 + Vector((0, -h / 2 - 0.16, 0))), frame, col,
                    bevel=0.03, rot=(0, -a + math.pi / 2, 0)))


# ================================================================ gate tower
def gate_tower():
    stones, mortar = stone_mats()
    gold = gold_mat()
    pane = glowing(K.mat("Window Goo", GLOW, rough=0.3), GLOW, 1.8)
    y0, y1 = -5.5, 5.5

    def build(col, high):
        if not high:
            return [glathe("Tower", [(0, y0), (2.72, y0), (2.72, y0 + 0.8), (2.55, y0 + 0.9), (2.25, y1 - 0.5),
                                     (2.4, y1 - 0.4), (2.4, y1), (0, y1)], stones[0], col, seg=24)]
        rnd = random.Random(11)
        obs = []
        prof, rows, ch = course_lathe(2.55, 2.22, y0 + 0.9, y1 - 0.5, 0.62)
        obs.append(glathe("Tower", [(0, y0 + 0.9), (2.5, y0 + 0.9)] + prof + [(2.18, y1 - 0.5), (0, y1 - 0.5)],
                          stones[0], col, seg=96))
        joints(obs, col, mortar, rnd, 2.55, 2.22, y0 + 0.9, y1 - 0.5, rows, ch, 14)
        obs.append(glathe("Plinth", [(0, y0), (2.72, y0), (2.72, y0 + 0.55), (2.66, y0 + 0.62), (2.62, y0 + 0.8),
                                     (2.55, y0 + 0.9), (0, y0 + 0.9)], stones[2], col, seg=64))
        obs.append(glathe("Plinth Gold", [(2.73, y0 + 0.5), (2.76, y0 + 0.55), (2.73, y0 + 0.6)], gold, col, seg=64))
        for y in (-1.6, 3.4):                                   # gold bands
            r = 2.55 + (2.22 - 2.55) * (y - y0 - 0.9) / (y1 - y0 - 1.4)
            obs.append(glathe("Band", [(r - 0.02, y - 0.12), (r + 0.05, y - 0.09), (r + 0.05, y + 0.09),
                                       (r - 0.02, y + 0.12)], gold, col, seg=96))
            for k in range(16):                                 # studs on the band
                a = k * math.tau / 16
                obs.append(K.sphere("Stud", 0.05, at=at(math.cos(a) * (r + 0.06), y, math.sin(a) * (r + 0.06)),
                                    m=gold, seg=8, col=col))
        # the top: a cornice on corbels (the goo roof sits on it)
        obs.append(glathe("Cornice", [(2.2, y1 - 0.5), (2.42, y1 - 0.42), (2.42, y1 - 0.12), (2.36, y1 - 0.06),
                                      (2.36, y1), (0, y1)], stones[1], col, seg=96))
        obs.append(glathe("Cornice Gold", [(2.43, y1 - 0.34), (2.46, y1 - 0.3), (2.43, y1 - 0.26)], gold, col,
                          seg=96))
        for k in range(20):
            a = k * math.tau / 20
            q = Vector((math.cos(a), 0, math.sin(a)))
            obs.append(gbox("Corbel", (0.22, 0.4, 0.26), tuple(q * 2.3 + Vector((0, y1 - 0.72, 0))), stones[1], col,
                            bevel=0.03, rot=(0, -a + math.pi / 2, 0)))
        for k in range(4):                                      # windows at two heights, staggered
            a = k * math.tau / 4 + math.pi / 4
            arch_window(obs, col, gold, pane, 0.9, a, 0.7, 1.2, 2.38)
            a2 = a + math.pi / 4
            arch_window(obs, col, gold, pane, -3.4, a2, 0.4, 0.7, 2.5)
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ gate arch
def gate_arch():
    stones, mortar = stone_mats()
    gold = gold_mat()
    W, H, D = 10.8, 1.8, 2.2

    def arch_pts(z, rr=0.0):
        pts = []
        for k in range(17):
            x = -4.25 + 8.5 * k / 16
            y = -0.95 - 2.6 * (abs(x) / 4.25) ** 2
            pts.append((x, y - rr, z))
        return pts

    def build(col, high):
        if not high:
            obs = [gbox("Arch", (W, H, D), (0, 0, 0), stones[0], col)]
            obs.append(gwire("Arch Curve", arch_pts(0), 0.42, stones[0], col, res=6, bevel_res=2))
            return obs
        rnd = random.Random(21)
        obs = [gbox("Core", (W - 0.08, H - 0.08, D - 0.08), (0, 0, 0), mortar, col)]
        for s in (-1, 1):                                       # both faces, and the top and bottom
            block_face(obs, col, stones, rnd, (0, 0, s * D / 2), (1, 0, 0), (0, 0, s), W, H - 0.4, course=0.5,
                       block=(0.8, 1.4))
        for s in (-1, 1):
            obs.append(gbox("Trim", (W, 0.2, D + 0.04), (0, s * (H / 2 - 0.1), 0), gold, col, bevel=0.03))
            # the keystone, proud of the face a little, with a ruby
            obs.append(gbox("Keystone", (0.9, H - 0.4, 0.1), (0, 0, s * (D / 2 + 0.0)), stones[1], col, bevel=0.04))
        ruby = K.mat("Ruby", RUBY, rough=0.1)
        glowing(ruby, RUBY, 0.6)
        obs.append(K.sphere("Gem", 0.16, at=at(0, 0, D / 2 + 0.05), m=ruby, seg=12, col=col))
        # the arch under it, down to the towers: a rounded band of voussoirs
        for z in (-0.75, 0.75):
            pts = arch_pts(z)
            obs.append(gwire("Arch Curve", pts, 0.34, gold if z < 0 else stones[0], col, res=12, bevel_res=4))
        for k in range(16):                                     # the blocks across between the two curves
            p = arch_pts(0)[k]
            q = arch_pts(0)[k + 1]
            mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, 0)
            obs.append(gbox("Voussoir", (0.5, 0.5, 1.1), mid, rnd.choice(stones), col, bevel=0.04,
                            rot=(0, 0, math.atan2(q[1] - p[1], q[0] - p[0]))))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ court wall
def court_wall():
    stones, mortar = stone_mats()
    gold = gold_mat()
    T, H, L = 1.0, 6.0, 4.6

    def build(col, high):
        if not high:
            return [gbox("Wall", (T, H, L), (0, 0, 0), stones[0], col),
                    gbox("Coping", (T + 0.2, 0.3, L), (0, H / 2 - 0.15, 0), stones[1], col),
                    gbox("Plinth", (T + 0.2, 0.5, L), (0, -H / 2 + 0.25, 0), stones[2], col)]
        rnd = random.Random(31)
        obs = [gbox("Core", (T - 0.08, H - 0.1, L), (0, 0, 0), mortar, col)]
        for s in (-1, 1):
            block_face(obs, col, stones, rnd, (s * T / 2, 0.1, 0), (0, 0, 1), (s, 0, 0), L, H - 1.0, course=0.62)
        for s in (-1, 1):
            obs.append(gbox("Plinth", (0.12, 0.5, L), (s * (T / 2 + 0.04), -H / 2 + 0.25, 0), stones[2], col,
                            bevel=0.04))
            obs.append(gbox("Band", (0.06, 0.16, L), (s * (T / 2 + 0.02), 1.2, 0), gold, col, bevel=0.02))
        obs.append(gbox("Coping", (T + 0.2, 0.26, L), (0, H / 2 - 0.13, 0), stones[1], col, bevel=0.05))
        for k in range(3):                                      # battlements, with a gold cap on each
            z = -L / 2 + L * (k + 0.5) / 3
            obs.append(gbox("Merlon", (T, 0.7, 0.9), (0, H / 2 + 0.35, z), rnd.choice(stones), col, bevel=0.05))
            obs.append(gbox("Merlon Cap", (T + 0.1, 0.1, 1.0), (0, H / 2 + 0.75, z), gold, col, bevel=0.03))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ court stand
def court_stand():
    stones, mortar = stone_mats()
    gold = gold_mat()
    pane = glowing(K.mat("Niche Goo", GLOW, rough=0.3), GLOW, 1.4)
    S, H = 3.2, 6.6

    def build(col, high):
        if not high:
            return [gbox("Stand", (S, H, S), (0, 0, 0), stones[0], col),
                    gbox("Top", (S + 0.2, 0.3, S + 0.2), (0, H / 2 - 0.15, 0), stones[1], col)]
        rnd = random.Random(41)
        obs = [gbox("Core", (S - 0.08, H - 0.1, S - 0.08), (0, 0, 0), mortar, col)]
        for u, n in (((1, 0, 0), (0, 0, 1)), ((1, 0, 0), (0, 0, -1)), ((0, 0, 1), (1, 0, 0)), ((0, 0, 1), (-1, 0, 0))):
            c = Vector(n) * S / 2 + Vector((0, 0.05, 0))
            block_face(obs, col, stones, rnd, tuple(c), u, n, S - 0.3, H - 0.9, course=0.6, block=(0.7, 1.2))
            # an arched niche glowing green in the middle of each face
            nn, uu = Vector(n), Vector(u)
            mid = nn * (S / 2 + 0.01) + Vector((0, 0.4, 0))
            obs.append(gbox("Niche", (abs((uu * 0.9 + nn * 0.06).x), 1.6, abs((uu * 0.9 + nn * 0.06).z)),
                            tuple(mid), pane, col))
            top = [tuple(mid + nn * 0.03 + uu * math.cos(math.pi * k / 8) * 0.55 +
                         Vector((0, 0.8 + math.sin(math.pi * k / 8) * 0.55, 0))) for k in range(9)]
            side = [tuple(mid + nn * 0.03 + uu * 0.55 - Vector((0, 0.85, 0)))] + top + \
                   [tuple(mid + nn * 0.03 - uu * 0.55 - Vector((0, 0.85, 0)))]
            obs.append(gwire("Niche Frame", side, 0.07, gold, col, res=4, bevel_res=2))
        for s in (-1, 1):                                       # corner pilasters
            for t in (-1, 1):
                obs.append(gbox("Pilaster", (0.36, H - 0.6, 0.36), (s * (S / 2 - 0.1), 0.0, t * (S / 2 - 0.1)),
                                stones[1], col, bevel=0.05))
        obs.append(gbox("Base", (S + 0.24, 0.45, S + 0.24), (0, -H / 2 + 0.22, 0), stones[2], col, bevel=0.05))
        obs.append(gbox("Top", (S + 0.24, 0.28, S + 0.24), (0, H / 2 - 0.14, 0), stones[1], col, bevel=0.05))
        obs.append(gbox("Gold Rim", (S + 0.3, 0.1, S + 0.3), (0, H / 2 - 0.33, 0), gold, col, bevel=0.03))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ throne dais
def throne_dais():
    stones, mortar = stone_mats()
    gold = gold_mat()
    goo = glowing(K.mat("Dais Goo", GOO, rough=0.15), GLOW, 0.8)

    def step(r, y0, y1, nose=0.08):
        return [(r - 0.06, y0), (r, y0 + 0.06), (r, y1 - 0.12), (r + nose, y1 - 0.08), (r + nose, y1 - 0.02),
                (r, y1)]

    prof = [(0, 0.0), (6.12, 0.0), (6.12, 0.36), (6.0, 0.4)] + step(6.0, 0.4, 0.9)[1:] + \
        [(4.6, 0.9)] + step(4.6, 0.9, 1.4)[1:] + [(3.2, 1.4)] + step(3.2, 1.4, 1.9)[1:] + [(0, 1.9)]

    def build(col, high):
        if not high:
            return [glathe("Dais", [(0, 0), (6.12, 0), (6.12, 0.9), (4.6, 0.9), (4.6, 1.4), (3.2, 1.4), (3.2, 1.9),
                                    (0, 1.9)], stones[0], col, seg=48)]
        rnd = random.Random(51)
        obs = [glathe("Dais", prof[:prof.index((4.6, 0.9))] + [(0, 0.9)], stones[0], col, seg=192)]
        obs.append(glathe("Dais 2", [(0, 0.9)] + prof[prof.index((4.6, 0.9)):prof.index((3.2, 1.4))] + [(0, 1.4)],
                          stones[1], col, seg=160))
        obs.append(glathe("Dais 3", [(0, 1.4)] + prof[prof.index((3.2, 1.4)):], gold, col, seg=128))
        joints(obs, col, mortar, rnd, 6.0, 6.0, 0.42, 0.78, 1, 0.36, 40)
        joints(obs, col, mortar, rnd, 4.6, 4.6, 0.92, 1.28, 1, 0.36, 30)
        for r, y in ((6.0, 0.62), (4.6, 1.12)):                 # a gold inlay round each stone step's riser
            obs.append(glathe("Inlay", [(r - 0.01, y - 0.05), (r + 0.02, y - 0.03), (r + 0.02, y + 0.03),
                                        (r - 0.01, y + 0.05)], gold, col, seg=192))
        for k in range(12):                                     # goo gems set round the gold step's top
            a = k * math.tau / 12
            obs.append(blob("Goo Gem", 0.16, (math.cos(a) * 2.7, 1.9, math.sin(a) * 2.7), goo, col, seed=k, seg=12,
                            lump=0.15, squash=(1.0, 0.45, 1.0)))
        obs.append(gwire("Groove", [(math.cos(a) * 2.2, 1.91, math.sin(a) * 2.2)
                                       for a in (k * math.tau / 48 for k in range(48))], 0.05, mortar, col,
                         closed=True, res=2, bevel_res=2))
        obs.append(glathe("Footing", [(0, 0.0), (6.2, 0.0), (6.2, 0.06), (6.12, 0.1), (0, 0.1)], stones[2], col,
                          seg=96))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ throne
def throne():
    gold = gold_mat()
    deep = mottled("Throne Gold Deep", GOLD_DARK, (0.7, 0.48, 0.12), scale=6.0, rough=0.35, metal=0.85)
    ruby = glowing(K.mat("Ruby", RUBY, rough=0.1), RUBY, 0.6)
    goo = glowing(K.mat("Throne Goo", GOO, rough=0.15), GLOW, 0.5)

    def build(col, high):
        if not high:
            obs = [gbox("Seat", (4.6, 1.2, 3.2), (0, 2.5, 0.6), gold, col),
                   gbox("Back", (5.0, 6.6, 0.8), (0, 5.2, 2.0), gold, col),
                   glathe("Back Top", [(0, -0.4), (2.5, -0.4), (2.5, 0.4), (0, 0.4)], gold, col, seg=24,
                          pos=(0, 8.5, 2.0))]
            obs[-1].rotation_euler = (math.pi / 2, 0, 0)
            obs[-1].scale = (1.0, 1.0, 1.0)
            obs[-1].location = at(0, 8.5, 2.0)
            for s in (-1, 1):
                obs.append(gbox("Arm", (0.7, 1.4, 3.0), (s * 2.6, 3.4, 0.6), gold, col))
                # (the fluted pilasters and the arms' scrolls stand out past the plain shape, so they get their own)
                obs.append(gbox("Pilaster", (0.62, 5.95, 0.62), (s * 2.25, 5.37, 1.6), gold, col))
                obs.append(K.sphere("Finial", 0.32, at=at(s * 2.25, 8.55, 1.6), m=gold, seg=8, col=col))
                scr = K.cyl("Scroll", 0.52, 0.92, at=at(s * 2.6, 3.62, -0.85), seg=12, m=gold, col=col)
                scr.rotation_euler = (0, math.pi / 2, 0)
                obs.append(scr)
            return obs
        obs = []
        # the seat, panelled, with a gold apron and ball feet
        obs.append(gbox("Seat", (4.6, 1.0, 3.2), (0, 2.6, 0.6), gold, col, bevel=0.06))
        obs.append(gbox("Panel", (3.4, 0.5, 0.06), (0, 2.6, -1.02), deep, col, bevel=0.03))
        obs.append(gbox("Apron", (4.7, 0.25, 3.3), (0, 2.03, 0.6), deep, col, bevel=0.05))
        for s in (-1, 1):
            for t in (-1, 1):
                obs.append(K.sphere("Foot", 0.26, at=at(s * 2.05, 1.98, 0.6 + t * 1.35), m=gold, seg=16, col=col))
        obs.append(gwire("Scallop", [(-2.2 + 4.4 * k / 16, 2.0 - 0.12 * abs(math.sin(k * math.pi / 2)), -1.02)
                                     for k in range(17)], 0.05, gold, col, res=6, bevel_res=2))
        # the back: an arched top with a ruby, sunken panels and fluted pilasters
        obs.append(gbox("Back", (5.0, 6.4, 0.8), (0, 5.1, 2.0), gold, col, bevel=0.06))
        arch = K.cyl("Back Top", 2.5, 0.8, at=at(0, 8.3, 2.0), seg=48, m=gold, col=col)
        arch.rotation_euler = (math.pi / 2, 0, 0)
        obs.append(arch)
        obs.append(gbox("Back Panel", (3.6, 4.6, 0.06), (0, 5.4, 1.58), deep, col, bevel=0.04))
        obs.append(gwire("Back Frame", [(-1.85, 3.05, 1.56), (-1.85, 7.7, 1.56)] +
                         [(-math.cos(math.pi * k / 8) * 1.85, 7.7 + math.sin(math.pi * k / 8) * 0.8, 1.56)
                          for k in range(1, 8)] + [(1.85, 7.7, 1.56), (1.85, 3.05, 1.56)], 0.07, gold, col, res=6))
        for s in (-1, 1):
            obs.append(glathe("Pilaster", [(0, 0), (0.28, 0), (0.28, 0.2), (0.22, 0.3), (0.22, 5.6), (0.28, 5.7),
                                           (0.28, 5.9), (0, 5.9)], gold, col, seg=32, flutes=8, flute_depth=0.04,
                              flute_z=(0.4, 5.5), pos=(s * 2.25, 2.4, 1.6)))
            obs.append(K.sphere("Finial", 0.3, at=at(s * 2.25, 8.55, 1.6), m=gold, seg=16, col=col))
        obs.append(K.sphere("Back Gem", 0.35, at=at(0, 8.6, 1.55), m=ruby, seg=16, col=col))
        for k in range(5):                                      # rubies round the arch
            a = math.pi * (k + 1) / 6
            obs.append(K.sphere("Gem", 0.14, at=at(-math.cos(a) * 2.15, 8.3 + math.sin(a) * 2.15 * 0.55, 1.58),
                                m=ruby, seg=10, col=col))
        # goo dripping off the top of the back, as if he's leant on it
        for k in range(7):
            x = -2.2 + 4.4 * k / 6
            y = 8.3 + (1 - (x / 2.5) ** 2) ** 0.5 * 2.5
            l = 0.3 + 0.25 * ((k * 37) % 5) / 4
            obs.append(gwire("Drip", [(x, y + 0.02, 1.58), (x, y - l * 0.5, 1.56), (x, y - l, 1.56)], 0.07, goo, col,
                             res=4, bevel_res=2))
            obs.append(K.sphere("Drop", 0.1, at=at(x, y - l - 0.04, 1.56), m=goo, seg=8, col=col))
        # the arms: scrolled fronts with rubies
        for s in (-1, 1):
            obs.append(gbox("Arm", (0.7, 1.2, 3.0), (s * 2.6, 3.3, 0.7), gold, col, bevel=0.08))
            obs.append(gbox("Arm Top", (0.85, 0.16, 3.1), (s * 2.6, 3.98, 0.65), deep, col, bevel=0.05))
            scr = K.cyl("Scroll", 0.48, 0.85, at=at(s * 2.6, 3.62, -0.85), seg=32, m=gold, col=col)
            scr.rotation_euler = (0, math.pi / 2, 0)
            obs.append(scr)
            obs.append(gwire("Curl", [(s * 3.04, 3.62 + math.cos(a) * r, -0.85 + math.sin(a) * r)
                                      for a, r in ((k * 0.5, 0.42 - k * 0.025) for k in range(14))], 0.04, deep, col,
                             res=4, bevel_res=2))
            obs.append(K.sphere("Arm Gem", 0.13, at=at(s * 3.05, 3.62, -0.85), m=ruby, seg=10, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ goo lantern
def goo_lantern():
    gold = gold_mat()
    deep = mottled("Lantern Gold Deep", GOLD_DARK, (0.66, 0.44, 0.1), scale=8.0, rough=0.35, metal=0.85)
    ruby = glowing(K.mat("Ruby", RUBY, rough=0.1), RUBY, 0.6)
    goo = glowing(K.mat("Lantern Goo", GOO, rough=0.15), GLOW, 0.6)
    y0 = -1.5                                                   # the old post's foot; its bulb's middle is 1.8 up
    bars = 6

    def build(col, high):
        seg = 48 if high else 12
        obs = [glathe("Post", [(0, 0), (0.3, 0), (0.3, 0.12), (0.24, 0.18), (0.24, 0.3), (0.16, 0.38), (0.1, 0.5),
                               (0.09, 2.6), (0.13, 2.68), (0.22, 2.82), (0.25, 2.9), (0, 2.9)],
                      gold, col, seg=seg, pos=(0, y0, 0),
                      **({"flutes": 8, "flute_depth": 0.015, "flute_z": (0.55, 2.55)} if high else {}))]
        cap = [(0, 3.75), (0.3, 3.75), (0.5, 3.8), (0.52, 3.86), (0.3, 3.95), (0.12, 4.05), (0, 4.08)]
        obs.append(glathe("Cap", cap, gold, col, seg=seg, pos=(0, y0, 0)))
        for k in range(bars):                                   # the cage round the bulb
            a = k * math.tau / bars + math.pi / bars
            q = Vector((math.cos(a), 0, math.sin(a)))
            pts = [tuple(q * (0.25 + 0.27 * math.sin(math.pi * t / 6)) + Vector((0, y0 + 2.85 + t * 0.155, 0)))
                   for t in range(7)]
            obs.append(gwire("Bar", pts, 0.025, deep, col, res=6 if high else 2, bevel_res=2 if high else 1))
        if not high:
            return obs
        for y in (0.9, 1.9):                                    # collars
            obs.append(glathe("Collar", [(0.09, y - 0.05), (0.13, y - 0.02), (0.13, y + 0.02), (0.09, y + 0.05)],
                              deep, col, seg=32, pos=(0, y0, 0)))
        obs.append(gwire("Ring", [(math.cos(a) * 0.5, y0 + 3.31, math.sin(a) * 0.5)
                                  for a in (k * math.tau / 24 for k in range(24))], 0.025, gold, col, closed=True,
                         res=2, bevel_res=2))
        for k in range(5):                                      # a little crown on top
            a = k * math.tau / 5
            obs.append(K.cyl("Point", 0.06, 0.18, at=at(math.cos(a) * 0.12, y0 + 4.12, math.sin(a) * 0.12), seg=8,
                             m=gold, col=col, r2=0.0))
        obs.append(K.sphere("Crown Gem", 0.06, at=at(0, y0 + 4.12, 0), m=ruby, seg=10, col=col))
        for k in range(3):                                      # goo running down the post
            a = k * math.tau / 3 + 0.4
            q = Vector((math.cos(a), 0, math.sin(a)))
            l = 0.3 + k * 0.2
            obs.append(gwire("Drip", [tuple(q * 0.12 + Vector((0, y0 + 2.75, 0))),
                                      tuple(q * 0.105 + Vector((0, y0 + 2.75 - l * 0.6, 0))),
                                      tuple(q * 0.1 + Vector((0, y0 + 2.75 - l, 0)))], 0.03, goo, col, res=4,
                             bevel_res=2))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ goo spire
def goo_spire():
    rock = mottled("Goo Rock", ROCK, ROCK_DARK, scale=2.0, rough=0.7, bump=0.5, third=ROCK_PALE)
    goo = glowing(mottled("Spire Goo", GOO, GOO_DEEP, scale=3.0, rough=0.12, bump=0.05), GLOW, 0.35)
    H = 13.0
    prof = [(3.5, -H / 2), (3.3, -H / 2 + 1.5), (2.9, -H / 2 + 3.5), (2.4, -H / 2 + 5.5), (1.9, -H / 2 + 7.5),
            (1.45, -H / 2 + 9.5), (1.05, -H / 2 + 11.2), (0.75, H / 2 - 0.4), (0.4, H / 2 - 0.1), (0.0, H / 2)]

    def lumpy(seg, rings, lump):
        pts = []
        for k in range(rings):
            t = k / (rings - 1) * (len(prof) - 1)
            i = min(int(t), len(prof) - 2)
            f = t - i
            pts.append((prof[i][0] * (1 - f) + prof[i + 1][0] * f, prof[i][1] * (1 - f) + prof[i + 1][1] * f))
        ob = K.lathe("Spire", pts, seg=seg, m=rock, col=HIGH)
        for v in ob.data.vertices:
            rr = Vector((v.co.x, v.co.y, 0)).length
            if rr < 1e-4:
                continue
            p = Vector(v.co) * 0.45
            n = noise.noise(p + Vector((2, 7, 1))) + 0.4 * noise.noise(p * 3.1)
            band = 0.04 * math.sin(v.co.z * 2.2 + noise.noise(p * 0.5) * 3.0)
            k = 1.0 + lump * (max(n, -0.3) + 0.3) + band
            v.co.x *= k
            v.co.y *= k
        return ob

    def build(col, high):
        if not high:
            return [K.lathe("Spire", [(r * 1.05, y) for r, y in prof], seg=12, m=rock, col=col)]
        obs = [lumpy(96, 80, 0.12)]
        rnd = random.Random(61)
        # a cap of goo on top, and runs of goo oozing down from it
        obs.append(blob("Goo Cap", 1.0, (0, H / 2 - 0.55, 0), goo, col, seed=3, seg=20, lump=0.3,
                        squash=(1.0, 0.55, 1.0)))
        for k in range(9):
            a = k * math.tau / 9 + rnd.uniform(-0.2, 0.2)
            q = Vector((math.cos(a), 0, math.sin(a)))
            l = rnd.uniform(2.5, 7.5)
            pts = []
            for j in range(8):
                y = H / 2 - 0.6 - l * j / 7
                t = (y + H / 2) / H
                r = 3.5 + (0.75 - 3.5) * t ** 0.9
                pts.append(tuple(q * (r * 1.08 + 0.05) + Vector((0, y, 0))))
            obs.append(gwire("Ooze", pts, rnd.uniform(0.1, 0.2), goo, col, res=6, bevel_res=3))
            obs.append(blob("Drop", 0.22, pts[-1], goo, col, seed=k + 9, seg=10, lump=0.2, squash=(1, 1.4, 1)))
        for k in range(6):                                      # goo pooled round its foot
            a = rnd.uniform(0, math.tau)
            q = Vector((math.cos(a), 0, math.sin(a)))
            obs.append(blob("Pool", rnd.uniform(0.5, 0.9), tuple(q * 3.6 + Vector((0, -H / 2 + 0.1, 0))), goo, col,
                            seed=k + 30, seg=14, lump=0.25, squash=(1.4, 0.22, 1.0)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Royal Treasure
def planks(obs, col, woods, rnd, size, along, n_planks):
    """A box of planks: size (Godot x, y, z), the planks running along the given axis ('x' or 'z')."""
    sx, sy, sz = size
    for k in range(n_planks):
        h = sy / n_planks
        y = -sy / 2 + h * (k + 0.5)
        obs.append(gbox("Plank", (sx - 0.01, h - 0.025, sz - 0.01), (0, y, 0), rnd.choice(woods), col, bevel=0.012))


def chest_box():
    woods = [mottled("Chest Wood", WOOD, WOOD_DARK, scale=5.0, rough=0.75, grain=(14.0, 0.25)),
             mottled("Chest Wood Dark", (0.45, 0.25, 0.13), WOOD_DARK, scale=6.0, rough=0.8, grain=(16.0, 0.3))]
    gold = gold_mat()
    S = (1.4, 0.8, 0.9)

    def build(col, high):
        if not high:
            return [gbox("Chest", S, (0, 0, 0), woods[0], col)]
        rnd = random.Random(71)
        obs = [gbox("Core", (1.38, 0.78, 0.88), (0, 0, 0), K.mat("Chest Inside", WOOD_DARK, rough=0.9), col)]
        planks(obs, col, woods, rnd, S, "x", 4)
        for s in (-1, 1):                                       # gold corners and straps
            for t in (-1, 1):
                obs.append(gbox("Corner", (0.1, 0.8, 0.1), (s * 0.67, 0, t * 0.42), gold, col, bevel=0.02))
            obs.append(gbox("Strap", (0.12, 0.81, 0.91), (s * 0.4, 0, 0), gold, col, bevel=0.015))
        obs.append(gbox("Rim", (1.42, 0.08, 0.92), (0, 0.37, 0), gold, col, bevel=0.015))
        obs.append(gbox("Foot Rim", (1.42, 0.08, 0.92), (0, -0.37, 0), gold, col, bevel=0.015))
        obs.append(gbox("Lock", (0.26, 0.3, 0.04), (0, 0.15, -0.46), gold, col, bevel=0.02))
        obs.append(gbox("Keyhole", (0.04, 0.1, 0.02), (0, 0.13, -0.48), K.mat("Keyhole", (0.08, 0.05, 0.04)), col))
        for s in (-1, 1):
            for y in (-0.25, 0.25):
                for z in (-0.452, 0.452):
                    obs.append(K.sphere("Stud", 0.025, at=at(s * 0.4 + 0.0, y, z), m=gold, seg=8, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


def chest_lid():
    woods = [mottled("Lid Wood", WOOD, WOOD_DARK, scale=5.0, rough=0.75, grain=(14.0, 0.25)),
             mottled("Lid Wood Dark", (0.45, 0.25, 0.13), WOOD_DARK, scale=6.0, rough=0.8, grain=(16.0, 0.3))]
    gold = gold_mat()
    ruby = glowing(K.mat("Ruby", RUBY, rough=0.1), RUBY, 0.6)
    S = (1.5, 0.3, 0.95)

    def build(col, high):
        if not high:
            return [gbox("Lid", S, (0, 0, 0), gold, col)]
        rnd = random.Random(81)
        obs = [gbox("Core", (1.46, 0.26, 0.91), (0, 0, 0), woods[1], col)]
        for k in range(4):                                      # planks across the top
            z = -0.475 + 0.95 * (k + 0.5) / 4
            obs.append(gbox("Plank", (1.44, 0.04, 0.22), (0, 0.13, z), rnd.choice(woods), col, bevel=0.01))
        obs.append(gbox("Band", (1.5, 0.3, 0.12), (0, 0, 0), gold, col, bevel=0.02))
        for s in (-1, 1):
            obs.append(gbox("Band", (0.12, 0.3, 0.95), (s * 0.45, 0, 0), gold, col, bevel=0.02))
            obs.append(gbox("Edge", (0.06, 0.3, 0.95), (s * 0.72, 0, 0), gold, col, bevel=0.015))
        obs.append(gbox("Edge Front", (1.5, 0.08, 0.06), (0, -0.11, -0.445), gold, col, bevel=0.015))
        obs.append(gbox("Hasp", (0.2, 0.14, 0.03), (0, -0.12, -0.48), gold, col, bevel=0.015))
        obs.append(K.sphere("Gem", 0.07, at=at(0, 0.15, 0), m=ruby, seg=12, col=col))
        for s in (-1, 1):
            for z in (-0.3, 0.3):
                obs.append(K.sphere("Stud", 0.025, at=at(s * 0.45, 0.152, z), m=gold, seg=8, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "gate_tower": (gate_tower, 2048, 0.08, 0.2, True, True),
    "gate_arch": (gate_arch, 2048, 0.08, 0.2, True, True),
    "court_wall": (court_wall, 1024, 0.08, 0.2, True, False),
    "court_stand": (court_stand, 1024, 0.08, 0.2, True, True),
    "throne_dais": (throne_dais, 2048, 0.08, 0.2, True, True),
    "throne": (throne, 2048, 0.1, 0.25, True, True),
    "goo_lantern": (goo_lantern, 512, 0.03, 0.08, True, True),
    "goo_spire": (goo_spire, 2048, 0.3, 0.6, True, True),
    "chest_box": (chest_box, 512, 0.02, 0.05, True, False),
    "chest_lid": (chest_lid, 512, 0.02, 0.05, True, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

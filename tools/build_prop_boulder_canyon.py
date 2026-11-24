# Boulder Canyon, the Boulderdillo's lair (scripts/boulder_canyon.gd), built the detailed way (tools/bake_kit.py;
# 24 Nov 2026, Hayden: "Okay continue baking details"): the canyon's layered red rock (the Rockslide Run's walls and
# the Pinball Pit's rim), the pit's rock pillars, the Rock Arch's slab, the round boulders (heaped, piled into the
# arch, ringing the pit, rolling down the run and falling from the rim), the Rock Throne and the Big Geode. Each HIGH
# version is baked onto a LOW one, which is what the game draws.
#
# Every piece is made in the space of the plain mesh it replaces, so scripts/detail_props.gd dress_boulder_canyon
# puts each one where the old one was and every collision stays the game's. Blender's X is Godot's X, Blender's -Y is
# Godot's +Z and Blender's Z is Godot's Y.
#   canyon_wall     a stretch of canyon wall, 3 wide (x) by 16 high by 4.2 long (z), from the ground up: sandstone in
#                   layers, each band its own colour and sticking out or tucked in a little, with grooves between
#                   them, cracks down it and a lumpy dusty top. Alike on every side, so the game turns it and
#                   stretches it to each stretch of the run's walls and each block of the pit's rim.
#   rock_pillar     one of the pit's four pillars (radius 1.3 at the top, 1.7 at the foot, 4 high, centred): a hoodoo
#                   of the same layered rock with a harder cap.
#   arch_slab       the Rock Arch's slab (16 x 1.4 x 3, centred): layered and chipped, its underside darker.
#   canyon_boulder  a round boulder of radius 1 (no flat side, so it can roll): weathered sandstone, banded and
#                   pitted, with a little dusty lichen.
#   rock_throne     the Rock Throne from the ground at the throne's spot: a stepped stone drum (r 2.6 to 3, 1.2 high)
#                   and the back (5 x 4 x 1.2 at z 3), carved on its front with an armadillo's banded shell and two
#                   rocks on top like horns.
#   geode_base      the Big Geode's bottom half (radius 0.9, from the ground to 0.9 up): a lumpy grey shell, a ring of
#                   pale agate round the rim and purple crystal points lining the bowl.
#   geode_lid       its top half in the lid's space (the hinge at the back: the dome's middle is at z -0.85): the
#                   same shell outside and crystals inside, seen when it opens.
# Colours are the game's own (sRGB).
#
#   python tools/build_prop_boulder_canyon.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["canyon_wall", "rock_pillar", "arch_slab", "canyon_boulder", "rock_throne", "geode_base", "geode_lid"]
KIND = next((a for a in sys.argv if a in KINDS), "canyon_wall")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

# The canyon's rock (boulder_canyon.gd _rock) and a few more shades for the bands between them
BANDS = [(0.7, 0.33, 0.22), (0.85, 0.55, 0.3), (0.78, 0.45, 0.42), (0.6, 0.3, 0.25), (0.8, 0.5, 0.34),
         (0.66, 0.36, 0.28), (0.9, 0.64, 0.42)]
DUST = (0.88, 0.66, 0.46)
GROOVE = (0.42, 0.2, 0.15)
BOULDER = (0.62, 0.5, 0.48)
SHELL = (0.5, 0.45, 0.48)
AGATE = (0.92, 0.88, 0.95)
CRYSTAL = (0.75, 0.45, 1.0)


def at(x, y, z):
    """Godot's (x, y, z) in Blender's space."""
    return (x, -z, y)


def lin(c):
    return tuple(K.srgb_to_linear(v) for v in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


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


def painted(name, rough=0.85, bump=0.4, glow=0.0):
    """A material whose colour is the high mesh's own vertex colours ("Col"), with a fine rough bump: the rock's
    bands are worked out in Python with its shape, so colour and ledges always line up."""
    m = K.mat(name, (0.7, 0.4, 0.3), rough=rough)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], b.inputs["Base Color"])
    if glow > 0.0:
        nt.links.new(attr.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = glow
    co = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 26.0
    nz.inputs["Detail"].default_value = 10.0
    nt.links.new(co, nz.inputs["Vector"])
    bmp = nt.nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = bump
    bmp.inputs["Distance"].default_value = 0.01
    nt.links.new(nz.outputs["Fac"], bmp.inputs["Height"])
    nt.links.new(bmp.outputs["Normal"], b.inputs["Normal"])
    return m


def colour_mesh(bm, col_fn):
    """Sets each corner's vertex colour from col_fn(vertex position in Godot terms, its normal in Godot terms)."""
    layer = bm.loops.layers.color.new("Col")
    cache = {}
    for v in bm.verts:
        p = (v.co.x, v.co.z, -v.co.y)
        n = v.normal
        cache[v.index] = (*lin(col_fn(p, (n.x, n.z, -n.y))), 1.0)
    for f in bm.faces:
        for lp in f.loops:
            lp[layer] = cache[lp.vert.index]


# ================================================================ layered rock
class Strata:
    """The bands of a rock, from the ground up: each band's top, its colour and how far it sticks out."""

    def __init__(self, seed, height, thick=(0.7, 2.2)):
        rnd = random.Random(seed)
        self.tops = []
        self.cols = []
        self.out = []
        y = 0.0
        k = rnd.randrange(len(BANDS))
        while y < height + 2.0:
            y += rnd.uniform(*thick)
            self.tops.append(y)
            k = (k + rnd.choice([1, 2, 3, 4])) % len(BANDS)
            self.cols.append(BANDS[k])
            self.out.append(rnd.uniform(-0.2, 0.12))
        self.seed = seed

    def wobble(self, x, z):
        # the layers aren't quite level: they tilt and wave a little
        return 0.18 * math.sin(0.35 * x + 0.21 * z + self.seed) + 0.08 * noise.noise(Vector((x * 0.3, z * 0.3, 7.7)))

    def at(self, x, y, z):
        """(band index, distance to the nearest band edge) at a point."""
        yy = y + self.wobble(x, z)
        i = 0
        while i < len(self.tops) - 1 and yy > self.tops[i]:
            i += 1
        lo = self.tops[i - 1] if i > 0 else -10.0
        return i, min(abs(yy - lo), abs(self.tops[i] - yy))

    def push(self, x, y, z):
        """How far the rock face sticks out at a point (metres, along its normal)."""
        i, edge = self.at(x, y, z)
        groove = -0.09 * math.exp(-(edge / 0.07) ** 2)
        lumps = 0.07 * noise.noise(Vector((x * 1.3, y * 1.3, z * 1.3)))
        fine = 0.022 * noise.noise(Vector((x * 5.0, y * 5.0, z * 5.0)) + Vector((3.1, 1.2, 0.4)))
        return self.out[i] + groove + lumps + fine

    def colour(self, x, y, z, up):
        i, edge = self.at(x, y, z)
        c = self.cols[i]
        m = noise.noise(Vector((x * 0.9, y * 0.9, z * 0.9)) + Vector((11.0, 2.0, 5.0)))
        c = mix(c, mix(c, (1.0, 0.82, 0.62), 0.5), 0.25 + 0.25 * m)
        if edge < 0.08:
            c = mix(c, GROOVE, 0.65 * (1.0 - edge / 0.08))
        # desert varnish: dark streaks running down from the top
        streak = noise.noise(Vector((x * 2.2, 0.0, z * 2.2)) + Vector((0, 4.0, 0)))
        if streak > 0.35:
            c = mix(c, (0.35, 0.2, 0.17), min(0.45, (streak - 0.35) * 1.6))
        if up > 0.6:
            c = mix(c, DUST, 0.75)
        return c


def block(name, sx, sy, sz, step, m, col, strata=None, cracks=(), lumpy_top=0.15):
    """A box sx by sy by sz (Godot terms, from the ground up, centred in x and z) made of a fine grid, its sides
    pushed out by strata.push (and grooved where cracks are), its top lumpy; without strata a plain box."""
    hx, hz = sx / 2.0, sz / 2.0
    bm = bmesh.new()
    verts = {}

    def vert(p):
        key = (round(p[0], 4), round(p[1], 4), round(p[2], 4))
        v = verts.get(key)
        if v is None:
            v = bm.verts.new(at(*p))
            verts[key] = v
        return v

    def grid(origin, u, v, nu, nv, flip):
        rows = []
        for j in range(nv + 1):
            row = []
            for i in range(nu + 1):
                p = [origin[k] + u[k] * i / nu + v[k] * j / nv for k in range(3)]
                row.append(vert(p))
            rows.append(row)
        for j in range(nv):
            for i in range(nu):
                q = [rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]]
                bm.faces.new(list(reversed(q)) if flip else q)

    nx, ny, nz = max(1, round(sx / step)), max(1, round(sy / step)), max(1, round(sz / step))
    grid((-hx, 0, -hz), (sx, 0, 0), (0, sy, 0), nx, ny, True)        # -z face
    grid((-hx, 0, hz), (sx, 0, 0), (0, sy, 0), nx, ny, False)        # +z
    grid((-hx, 0, -hz), (0, 0, sz), (0, sy, 0), nz, ny, False)       # -x
    grid((hx, 0, -hz), (0, 0, sz), (0, sy, 0), nz, ny, True)         # +x
    grid((-hx, sy, -hz), (sx, 0, 0), (0, 0, sz), nx, nz, True)       # top
    grid((-hx, 0, -hz), (sx, 0, 0), (0, 0, sz), nx, nz, False)       # bottom
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if strata is not None:
        for v in bm.verts:
            x, y, z = v.co.x, v.co.z, -v.co.y
            # each point is pushed along the box's own rounded-off normal, worked out from where it is, so the
            # same point on two faces moves the same way and nothing tears at the edges
            n = Vector((0.0, 0.0, 0.0))
            e = 1e-4
            if x <= -hx + e:
                n.x -= 1
            if x >= hx - e:
                n.x += 1
            if z <= -hz + e:
                n.z -= 1
            if z >= hz - e:
                n.z += 1
            top = y >= sy - e
            if top:
                n.y += 1
            if y <= e:
                continue                                         # the bottom stays in the ground
            if n.length == 0.0:
                continue
            n.normalize()
            d = 0.0
            side = Vector((n.x, 0.0, n.z)).length
            if side > 0.0:
                d += strata.push(x, y, z) * side
                for (cx, cz, w) in cracks:
                    t = min(abs(x - cx) if n.z != 0 else 99.0, abs(z - cz) if n.x != 0 else 99.0)
                    d -= 0.14 * math.exp(-(t / w) ** 2) * side
            if top:
                d += lumpy_top * noise.noise(Vector((x * 0.8, 0.0, z * 0.8)) + Vector((2.0, 9.0, 1.0))) \
                    + 0.04 * noise.noise(Vector((x * 4.0, 1.0, z * 4.0)))
            # the top edge is a little worn round
            if top and side > 0.0:
                d -= 0.12
            p = Vector((x, y, z)) + n * d
            v.co = Vector(at(p.x, p.y, p.z))
        bm.normal_update()
        colour_mesh(bm, lambda p, nn: strata.colour(p[0], p[1], p[2], nn[1]))
    return K._obj(name, bm, m, True, col)


# ================================================================ the walls and the rim
def canyon_wall():
    rock = painted("Canyon Rock")
    plain = K.mat("Canyon Rock Low", BANDS[0], rough=0.85)
    strata = Strata(11, 16.0)
    cracks = [(-0.6, -1.3, 0.05), (0.9, 0.4, 0.06), (0.0, 1.6, 0.04)]
    high = [block("Wall", 3.0, 16.0, 4.2, 0.07, rock, HIGH, strata, cracks)]
    low = [block("Wall", 3.0, 16.0, 4.2, 0.5, plain, LOW)]
    return high, low


# ================================================================ a pillar
def rock_pillar():
    rock = painted("Pillar Rock")
    cap_m = painted("Pillar Cap")
    plain = K.mat("Pillar Low", BANDS[0], rough=0.85)
    strata = Strata(23, 4.0, thick=(0.35, 0.8))
    cap_strata = Strata(29, 1.0, thick=(0.15, 0.3))

    def tower(col, high, m, st, r0, r1, y0, y1, seg, rows):
        bm = bmesh.new()
        ring = []
        for j in range(rows + 1):
            t = j / rows
            y = y0 + (y1 - y0) * t
            r = r0 + (r1 - r0) * t
            row = []
            for i in range(seg):
                a = math.tau * i / seg
                x, z = math.sin(a) * r, math.cos(a) * r
                if high:
                    rr = r + st.push(x, y + 2.0, z)
                    x, z = math.sin(a) * rr, math.cos(a) * rr
                row.append(bm.verts.new(at(x, y, z)))
            ring.append(row)
        for j in range(rows):
            for i in range(seg):
                k = (i + 1) % seg
                bm.faces.new((ring[j][i], ring[j][k], ring[j + 1][k], ring[j + 1][i]))
        top = bm.verts.new(at(0, y1 + (0.12 if high else 0.05), 0))
        for i in range(seg):
            bm.faces.new((ring[rows][i], ring[rows][(i + 1) % seg], top))
        bot = bm.verts.new(at(0, y0, 0))
        for i in range(seg):
            bm.faces.new((ring[0][(i + 1) % seg], ring[0][i], bot))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if high:
            bm.verts.index_update()
            colour_mesh(bm, lambda p, nn: st.colour(p[0], p[1] + 2.0, p[2], nn[1]))
        return K._obj("Pillar", bm, m, True, col)

    def build(col, high):
        m = rock if high else plain
        cm = cap_m if high else plain
        seg, rows = (96, 80) if high else (20, 6)
        # the shaft narrows to a waist under its cap, like a hoodoo; the cap sits over the old top
        body = tower(col, high, m, strata, 1.7, 1.25, -2.0, 1.55, seg, rows)
        cap = tower(col, high, cm, cap_strata, 1.4, 1.2, 1.5, 2.0, seg, max(2, rows // 6))
        return [body, cap]

    return build(HIGH, True), build(LOW, False)


# ================================================================ the arch's slab
def arch_slab():
    rock = painted("Slab Rock")
    plain = K.mat("Slab Low", BANDS[3], rough=0.85)
    strata = Strata(37, 1.4, thick=(0.25, 0.5))
    cracks = [(-4.1, 0.0, 0.05), (2.7, 0.0, 0.05), (6.3, 0.0, 0.04)]
    high = block("Slab", 16.0, 1.4, 3.0, 0.06, rock, HIGH, strata, cracks, lumpy_top=0.1)
    low = block("Slab", 16.0, 1.4, 3.0, 0.5, plain, LOW)
    for ob in (high, low):
        ob.location = at(0, -0.7, 0)
    # (the underside is the slab's own: block() leaves the bottom flat, so give it a few drips of darker stone)
    return [high], [low]


# ================================================================ a round boulder
def _rock_r(p, seed):
    r = 1.0 + 0.16 * noise.noise(p * 1.1 + Vector((seed, 0, 0))) + 0.05 * noise.noise(p * 3.0 + Vector((0, seed, 0)))
    # flattish facets where it's been knocked about
    for k in range(5):
        a = Vector((math.sin(k * 2.4 + seed), math.cos(k * 1.7), math.sin(k * 3.3))).normalized()
        d = p.dot(a)
        if d > 0.82:
            r -= (d - 0.82) * 0.5
    return r


def canyon_boulder():
    rock = painted("Boulder Rock", bump=0.5)
    plain = K.mat("Boulder Low", BOULDER, rough=0.85)

    def colour(p, n):
        x, y, z = p
        c = mix(BOULDER, (0.74, 0.5, 0.4), 0.5 + 0.5 * math.sin(y * 7.0 + 2.0 * noise.noise(Vector(p) * 1.5)))
        c = mix(c, (0.5, 0.34, 0.32), max(0.0, noise.noise(Vector(p) * 4.0 + Vector((5, 1, 2)))))
        pit = noise.noise(Vector(p) * 14.0)
        if pit > 0.45:
            c = mix(c, (0.3, 0.2, 0.2), (pit - 0.45) * 2.0)
        lichen = noise.noise(Vector(p) * 3.0 + Vector((9, 9, 9)))
        if lichen > 0.42 and n[1] > -0.2:
            c = mix(c, (0.82, 0.76, 0.52), min(0.7, (lichen - 0.42) * 3.0))
        return c

    def build(col, high):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=6 if high else 3, radius=1.0)
        for v in bm.verts:
            p = v.co.normalized()
            r = _rock_r(p, 3.0)
            if high:
                r += 0.02 * noise.noise(p * 9.0) + 0.008 * noise.noise(p * 30.0)
            v.co = p * r
        bm.normal_update()
        if high:
            colour_mesh(bm, colour)
        return [K._obj("Boulder", bm, rock if high else plain, smooth=True, col=col)]

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Rock Throne
def rock_throne():
    rock = painted("Throne Rock")
    shell = K.mat("Throne Shell", (0.86, 0.58, 0.36), rough=0.7, bump=0.25)
    plain = K.mat("Throne Low", BANDS[2], rough=0.85)
    horn = K.mat("Throne Horn", BANDS[1], rough=0.85, bump=0.4)
    drum_strata = Strata(41, 1.2, thick=(0.2, 0.4))
    back_strata = Strata(43, 4.0, thick=(0.4, 0.9))

    def drum(col, high, m):
        bm = bmesh.new()
        seg, rows = (128, 40) if high else (24, 4)
        # two steps: a wide foot to 0.45 and the seat up to 1.2
        prof = [(3.05, 0.0), (3.0, 0.42), (2.78, 0.48), (2.72, 1.12), (2.6, 1.2)]
        rings = []
        ys = []
        for j in range(rows + 1):
            t = j / rows
            # walk the profile by height
            y = 1.2 * t
            for a, b in zip(prof, prof[1:]):
                if a[1] <= y <= b[1] + 1e-6:
                    r = a[0] + (b[0] - a[0]) * (y - a[1]) / max(1e-6, b[1] - a[1])
                    break
            ys.append((r, y))
        for (r, y) in ys:
            row = []
            for i in range(seg):
                a = math.tau * i / seg
                x, z = math.sin(a) * r, math.cos(a) * r
                if high:
                    rr = r + drum_strata.push(x, y, z) * 0.5
                    x, z = math.sin(a) * rr, math.cos(a) * rr
                row.append(bm.verts.new(at(x, y, z)))
            rings.append(row)
        for j in range(rows):
            for i in range(seg):
                k = (i + 1) % seg
                bm.faces.new((rings[j][i], rings[j][k], rings[j + 1][k], rings[j + 1][i]))
        top = bm.verts.new(at(0, 1.22, 0))
        for i in range(seg):
            bm.faces.new((rings[rows][i], rings[rows][(i + 1) % seg], top))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if high:
            colour_mesh(bm, lambda p, nn: drum_strata.colour(*p, nn[1]))
        return K._obj("Drum", bm, m, True, col)

    def build(col, high):
        m = rock if high else plain
        obs = [drum(col, high, m)]
        back = block("Back", 5.0, 4.0, 1.2, 0.06 if high else 0.5, m, col, back_strata if high else None,
                     [(-1.3, 0.0, 0.05), (1.6, 0.0, 0.04)] if high else ())
        back.location = at(0, 0, 3.0)
        obs.append(back)
        if high:
            # the armadillo's shell carved on the back's front: arched bands, each a row of little plates
            for k in range(5):
                r = 1.0 + k * 0.32
                for j in range(14 + k * 3):
                    a = math.pi * (j + 0.5) / (14 + k * 3)
                    x, y = math.cos(a) * r, 0.9 + math.sin(a) * r * 0.85
                    if y > 3.8:
                        continue
                    obs.append(K.box("Plate", (0.2, 0.06, 0.14), at=at(x, y, 3.0 - 0.6 - 0.02), m=shell, bevel=0.02,
                                     col=col, rot=(0, -a + math.pi / 2, 0)))
            obs.append(K.sphere("Head", 0.32, at=at(0, 0.95, 3.0 - 0.62), m=shell, seg=16, col=col,
                                scale=(1.0, 0.6, 0.8)))
        # two rocks on top like horns, and rubble round the foot
        rnd = random.Random(5)
        for s in (-1, 1):
            # (a plain rock colour: K.sphere has no vertex colours for the painted rock to read, so it baked white)
            ob = K.sphere("Horn Rock", 0.55, at=at(s * 2.0, 4.2, 3.0), m=horn if high else plain, seg=24 if high else 8, col=col,
                          scale=(0.9, 0.9, 1.3))
            obs.append(ob)
        if high:
            for k in range(14):
                a = rnd.uniform(0, math.tau)
                rr = rnd.uniform(3.0, 3.3)
                obs.append(K.sphere("Rubble", rnd.uniform(0.1, 0.22), at=at(math.sin(a) * rr, 0.06, math.cos(a) * rr),
                                    m=plain, seg=8, col=col, scale=(1.0, 1.0, 0.6)))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Big Geode
def _geode(col, high, top, shell_m, agate_m, crystal_m):
    """A half geode, its middle at the origin: top=False the bottom bowl (y -0.9..0), True the dome (0..0.9)."""
    obs = []
    s = 1.0 if top else -1.0
    bm = bmesh.new()
    seg, rows = (96, 32) if high else (24, 6)
    rings = []
    for j in range(rows + 1):
        t = j / rows                                             # 0 at the rim, 1 at the pole
        ph = t * math.pi / 2
        row = []
        for i in range(seg):
            a = math.tau * i / seg
            d = Vector((math.cos(ph) * math.sin(a), s * math.sin(ph), math.cos(ph) * math.cos(a)))
            r = 0.9
            if high:
                r += 0.06 * noise.noise(d * 3.0) + 0.02 * noise.noise(d * 9.0)
            row.append(bm.verts.new(at(*(d * r))))
        rings.append(row)
    for j in range(rows):
        for i in range(seg):
            k = (i + 1) % seg
            f = (rings[j][i], rings[j][k], rings[j + 1][k], rings[j + 1][i])
            bm.faces.new(f if top else tuple(reversed(f)))
    pole = bm.verts.new(at(0, s * 0.9, 0))
    for i in range(seg):
        f = (rings[rows][i], rings[rows][(i + 1) % seg], pole)
        bm.faces.new(f if top else tuple(reversed(f)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obs.append(K._obj("Shell", bm, shell_m, True, col))
    # the open face: a ring of pale agate and, inside it, a hollow lined with crystals
    obs.append(K.lathe("Agate", [(0.92, 0.0), (0.9, s * 0.015), (0.7, s * 0.02), (0.62, 0.0)], seg=seg,
                       m=agate_m, col=col))
    obs[-1].location = at(0, -s * 0.01, 0)
    cav = K.lathe("Hollow", [(0.64, 0.0), (0.6, s * 0.2), (0.45, s * 0.45), (0.0, s * 0.55)], seg=seg,
                  m=crystal_m, col=col)
    obs.append(cav)
    if high:
        rnd = random.Random(7 if top else 3)
        for k in range(90):
            a = rnd.uniform(0, math.tau)
            t = rnd.uniform(0.05, 0.95)
            r = 0.62 * (1.0 - t * t)
            y = s * 0.5 * t
            base = Vector((math.sin(a) * r, y, math.cos(a) * r))
            tip = base + (Vector((0, -s * 0.15, 0)) - base).normalized() * rnd.uniform(0.08, 0.2)
            ob = K.cyl("Point", rnd.uniform(0.025, 0.05), (tip - base).length, seg=6, m=crystal_m, col=col, r2=0.0)
            ob.location = Vector(at(*((base + tip) / 2)))
            d = Vector(at(*(tip - base))).normalized()
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
            obs.append(ob)
    return obs


def _geode_mats():
    shell = K.mat("Geode Shell", SHELL, rough=0.9, pits=0.3, bump=0.5)
    agate = K.mat("Geode Agate", AGATE, rough=0.35, bump=0.1)
    crystal = K.mat("Geode Crystal", CRYSTAL, rough=0.2, emit=0.6)
    return shell, agate, crystal


def geode_base():
    sh, ag, cr = _geode_mats()

    def build(col, high):
        obs = _geode(col, high, False, sh, ag, cr)
        for ob in obs:
            ob.location = Vector(ob.location) + Vector(at(0, 0.9, 0))
        return obs

    return build(HIGH, True), build(LOW, False)


def geode_lid():
    sh, ag, cr = _geode_mats()

    def build(col, high):
        obs = _geode(col, high, True, sh, ag, cr)
        for ob in obs:
            ob.location = Vector(ob.location) + Vector(at(0, 0, -0.85))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, ao, emit = {
    "canyon_wall": (canyon_wall, 2048, 0.25, 0.6, True, False),
    "rock_pillar": (rock_pillar, 1024, 0.25, 0.6, True, False),
    "arch_slab": (arch_slab, 1024, 0.25, 0.6, True, False),
    "canyon_boulder": (canyon_boulder, 1024, 0.2, 0.45, True, False),
    "rock_throne": (rock_throne, 2048, 0.25, 0.6, True, False),
    "geode_base": (geode_base, 1024, 0.06, 0.15, True, True),
    "geode_lid": (geode_lid, 1024, 0.06, 0.15, True, True),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, extrusion=ext, ray=ray, ao=ao, emit=emit)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

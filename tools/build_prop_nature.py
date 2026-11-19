# Batch thirteen, nature (19 Nov 2026, Hayden: "start baking nature, buildings, then portal worlds in that order"):
# the trees and plants, built the detailed way (tools/bake_kit.py). Each HIGH version is baked onto a LOW one, and the
# LOW one is what the game draws, in place of the plain sphere, cone or cylinder each tree and plant was made of.
#
# Trees and plants are drawn as MultiMeshes (one mesh, hundreds of copies, each with its own size and colour), so
# each piece here is baked PALE and exported at the unit size of the shape it replaces: the game keeps every copy's
# place, size and colour, and only the mesh and its textures change (scripts/detail_props.gd dress_nature_*).
# The detail is built at a typical real size first (so bark grooves, leaves and gills are the size they should be),
# baked there, then the low mesh is scaled down to the unit shape before export.
#
# What we compared first (Hayden's rule): dgreenheck/ez-tree (MIT: a trunk is a tube of sections whose radius tapers
# and wobbles, leaves are small cards scattered on the branches) and leafar-tb/proc-shrooms (no licence, ideas only: a
# mushroom is a lathed cap profile, gills under it and a stem with a ring). Ours bakes those ideas into textures on
# light shapes instead of drawing them, so hundreds of trees stay cheap.
#
#   bark_trunk     Stars Hollow's tree trunks (Tree Trunk): ridged, furrowed bark, five roots flaring into the ground,
#                  knots and a broken stub. Unit: bottom radius 1, top 0.56, height 1, centred.
#   bark_limb      the bare trees' branches (Tree Branch): finer bark, little twig stubs. Bottom 1, top 0.4.
#   leaf_ball      Stars Hollow's balls of leaves (Tree Leaves): 2,200 little leaves on a lumpy ball. Radius 1. The
#                  seasons tint it (orange, green, blossom, snow).
#   void_orb       the Void's tree canopies, parasol caps and bulbs (Canopies): a ball of overlapping round scales
#                  like a pine cone, with beads between. Radius 1.
#   void_spire     the spire trees' tiers (Spires): a seven-sided crystal cone with growth terraces and striations.
#                  Bottom radius 1, height 1, centred.
#   void_stalk     the Void's tree stalks (Trunks): a segmented stalk with nodes, fibres and pores. Bottom radius 0.22,
#                  top 0.12, height 1, centred (scripts/trees.gd's stalk mesh).
#   mushroom_cap   the glowing mushrooms' caps (Caps): warts on top, gills underneath. Radius 1, dome height 1 (the
#                  game squashes it to half), flat underneath at 0.
#   mushroom_stem  their stems (Stems): fibres, a skirt and a bulb at the foot. Bottom 1, top 0.75, height 1, centred.
#   giant_leaf     the giant leaves' texture (Leaves): midrib, veins and quilting, in the leaf's own UV space (U
#                  across, 0.5 the midrib; V along it, base to tip). Only the textures are used.
#
#   python tools/build_prop_nature.py "<out>.glb" <kind> [--preview]
import math
import sys
from pathlib import Path
import os

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector, Matrix, noise  # noqa: E402

KINDS = ["bark_trunk", "bark_limb", "leaf_ball", "void_orb", "void_spire", "void_stalk", "mushroom_cap",
         "mushroom_stem", "giant_leaf"]
KIND = next((a for a in sys.argv if a in KINDS), "bark_trunk")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")


def mesh_obj(name, bm, m, col, smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, smooth, col)


def _nodes(m):
    nt = m.node_tree
    return nt, nt.nodes["Principled BSDF"], nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]


def mottled(name, a, b, scale=6.0, rough=0.6, bump=0.0, stretch=(1.0, 1.0, 1.0)):
    """A pale material wandering between two greys; stretch squashes the noise (long bark streaks)."""
    m = K.mat(name, a, rough=rough, bump=bump)
    nt, bsdf, co = _nodes(m)
    vec = co
    if stretch != (1.0, 1.0, 1.0):
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = stretch
        nt.links.new(co, mp.inputs["Vector"])
        vec = mp.outputs["Vector"]
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 6.0
    nt.links.new(vec, nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["From Min"].default_value = 0.35
    ramp.inputs["From Max"].default_value = 0.7
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(ramp.outputs["Result"], mix.inputs["Factor"])
    K._rgba(mix.inputs, "A").default_value = (*(K.srgb_to_linear(c) for c in a), 1)
    K._rgba(mix.inputs, "B").default_value = (*(K.srgb_to_linear(c) for c in b), 1)
    nt.links.new(K._rgba(mix.outputs, "Result"), bsdf.inputs["Base Color"])
    return m


def tube(name, rows, seg, radius, m, col, smooth=True, cap_top=True, cap_bottom=True):
    """A tube up Z: rows is a list of z, radius(t, a, z) the radius at each point (t 0..1 along it)."""
    bm = bmesh.new()
    rings = []
    z0, z1 = rows[0], rows[-1]
    for z in rows:
        t = (z - z0) / (z1 - z0)
        ring = []
        for k in range(seg):
            a = k / seg * math.tau
            r = radius(t, a, z)
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    return mesh_obj(name, bm, m, col, smooth)


def blob(name, r, subdiv, lump, seed, m, col, smooth=True, freq=2.2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in bm.verts:
        n = v.co.normalized()
        v.co = n * r * (1.0 + lump_at(n, lump, off, freq))
    return mesh_obj(name, bm, m, col, smooth)


def lump_at(n, lump, off, freq=2.2):
    return noise.noise(n * freq + off) * lump + noise.noise(n * freq * 2.3 + off) * lump * 0.3


def rows_between(z0, z1, n, dense_bottom=0):
    """n+1 heights from z0 to z1, with extra rows near the bottom (for roots and bulbs)."""
    out = []
    for i in range(n + 1):
        t = i / n
        if dense_bottom:
            t = t ** 1.6
        out.append(z0 + (z1 - z0) * t)
    return out


def fib_dirs(n, seed=0.0):
    """n directions spread evenly over a sphere (a Fibonacci spiral), nudged by noise so they don't line up."""
    out = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        y = 1.0 - (i + 0.5) / n * 2.0
        r = math.sqrt(max(0.0, 1.0 - y * y))
        a = golden * i + noise.noise(Vector((i * 0.37, seed, 0.3))) * 0.6
        out.append(Vector((math.cos(a) * r, math.sin(a) * r, y)).normalized())
    return out


def frame(n):
    """Two directions at right angles to n (a little leaf or scale's own across and along)."""
    up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    x = up.cross(n).normalized()
    y = n.cross(x).normalized()
    return x, y


# ================================================================ bark
def _bark(name, r0, r1, h, roots, furrows, scale_noise, knots, stubs):
    bark = mottled("Bark", (0.93, 0.9, 0.86), (0.72, 0.68, 0.64), scale=5.0, rough=0.9, bump=0.7,
                   stretch=(3.0, 3.0, 0.4))
    inner = K.mat("Bark Crack", (0.42, 0.38, 0.36), rough=0.95)
    z0, z1 = -h / 2, h / 2

    def base_r(t, a):
        r = r0 + (r1 - r0) * t
        if roots:
            flare = max(0.0, 1.0 - t / 0.13) ** 2
            r *= 1.0 + flare * (0.55 + 0.75 * max(0.0, math.cos(a * roots)) ** 3)
        return r

    def high_r(t, a, z):
        r = base_r(t, a)
        # vertical furrows between plates: noise stretched along the trunk
        f = noise.noise(Vector((math.cos(a) * furrows, math.sin(a) * furrows, z * scale_noise)))
        plates = 1.0 - abs(f) * 2.2
        r *= 1.0 + 0.07 * max(-0.6, plates)
        for (ka, kz, ks) in knots:
            da = math.atan2(math.sin(a - ka), math.cos(a - ka))
            d2 = (da * r) ** 2 + (z - kz) ** 2
            r += ks * math.exp(-d2 / (ks * ks * 2.5))
        return r

    def build(col, high):
        obs = []
        if high:
            rows = rows_between(z0, z1, 160, dense_bottom=1 if roots else 0)
            obs.append(tube("Bark", rows, 72, high_r, bark, col))
            # dark inside the furrows (a slightly thinner core, so the grooves bake dark)
            obs.append(tube("Core", rows, 36, lambda t, a, z: base_r(t, a) * 0.9, inner, col))
            for (sa, sz, sl) in stubs:
                t = (sz - z0) / h
                rr = base_r(t, sa)
                d = Vector((math.cos(sa), math.sin(sa), 0.35)).normalized()
                start = Vector((math.cos(sa) * rr * 0.8, math.sin(sa) * rr * 0.8, sz))
                ob = K.cyl("Stub", rr * 0.32, sl, at=start + d * sl / 2, seg=12, m=bark, col=col, r2=rr * 0.22)
                ob.rotation_mode = "QUATERNION"
                ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
                obs.append(ob)
        else:
            rows = rows_between(z0, z1, 9 if roots else 4, dense_bottom=1 if roots else 0)
            obs.append(tube("Bark", rows, 10 if roots else 8, lambda t, a, z: base_r(t, a) * 1.01, bark, col))
        return obs

    return build(HIGH, True), build(LOW, False)


def bark_trunk():
    # A typical town trunk: 0.32 m at the foot, 5.5 m tall
    knots = [(0.6, -0.6, 0.05), (2.8, 0.9, 0.04), (4.4, 1.9, 0.035)]
    stubs = [(1.9, 0.4, 0.22), (5.1, 1.6, 0.16)]
    return _bark("Trunk", 0.32, 0.18, 5.5, 5, 7.0, 0.7, knots, stubs)


def bark_limb():
    knots = [(1.2, 0.2, 0.012)]
    stubs = [(0.5, -0.3, 0.12), (3.6, 0.5, 0.09)]
    return _bark("Limb", 0.1, 0.04, 2.0, 0, 5.0, 1.6, knots, stubs)


# ================================================================ leaves
def _leaf_card(bm, centre, n, along, size, curl):
    """One small leaf: a pointed oval, cupped a little, with a raised midrib, as a fan of triangles."""
    x = n.cross(along).normalized()
    pts = []
    steps = 7
    for i in range(steps + 1):
        t = i / steps
        w = math.sin(math.pi * t ** 0.8) * 0.42
        pts.append((t, w))
    left, right = [], []
    for (t, w) in pts:
        c = centre + along * (t - 0.35) * size
        cup = n * (w * w) * curl * size
        left.append(bm.verts.new(c - x * w * size * 0.5 + cup))
        right.append(bm.verts.new(c + x * w * size * 0.5 + cup))
    rib = [bm.verts.new(centre + along * (t - 0.35) * size + n * size * 0.025) for (t, w) in pts]
    for i in range(steps):
        for side in (left, right):
            try:
                bm.faces.new((rib[i], side[i], side[i + 1], rib[i + 1]))
            except ValueError:
                pass


def leaf_ball():
    R = 1.8
    leaf = mottled("Leaf", (0.98, 0.97, 0.93), (0.82, 0.8, 0.76), scale=9.0, rough=0.55, bump=0.25)
    inside = K.mat("Leaf Shadow", (0.34, 0.32, 0.3), rough=0.9)
    off = Vector((4.1, 2.7, 1.3))

    def build(col, high):
        obs = []
        if not high:
            obs.append(blob("Leaves", R, 2, 0.13, 4.1, leaf, col))
            return obs
        obs.append(blob("Inside", R * 0.86, 3, 0.13, 4.1, inside, col))
        bm = bmesh.new()
        for i, d in enumerate(fib_dirs(2200, 1.0)):
            surf = R * (1.0 + lump_at(d, 0.13, off))
            depth = 0.94 + 0.1 * (noise.noise(d * 9.0 + off) * 0.5 + 0.5)
            centre = d * surf * depth
            tilt = Vector((noise.noise(d * 5.0), noise.noise(d * 5.0 + off), noise.noise(d * 5.0 - off))) * 0.9
            n = (d + tilt).normalized()
            x, y = frame(n)
            ang = noise.noise(d * 3.3 + off * 2.0) * math.pi * 2.0
            along = (x * math.cos(ang) + y * math.sin(ang)).normalized()
            _leaf_card(bm, centre, n, along, 0.24 + 0.06 * noise.noise(d * 7.0), 0.5)
        obs.append(mesh_obj("Leaf Cards", bm, leaf, col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the Void's trees
def void_orb():
    R = 1.5
    scale_m = mottled("Scale", (0.98, 0.97, 1.0), (0.84, 0.82, 0.88), scale=7.0, rough=0.35, bump=0.15)
    deep = K.mat("Scale Shadow", (0.5, 0.48, 0.55), rough=0.6)
    bead = K.mat("Bead", (1.0, 1.0, 1.0), rough=0.15)

    def build(col, high):
        obs = []
        if not high:
            obs.append(blob("Orb", R, 2, 0.025, 2.0, scale_m, col, freq=1.5))
            return obs
        obs.append(blob("Core", R * 0.95, 4, 0.0, 2.0, deep, col))
        bm = bmesh.new()
        dirs = fib_dirs(520, 3.0)
        for i, d in enumerate(dirs):
            x, y = frame(d)
            # each scale points down the ball a little, like a pine cone's
            down = (Vector((0, 0, -1)) - d * d.z)
            down = down.normalized() if down.length > 0.01 else y
            side = d.cross(down).normalized()
            size = 0.24
            centre = d * R * 0.985
            ring = []
            nseg = 12
            for k in range(nseg):
                a = k / nseg * math.tau
                u, v = math.cos(a), math.sin(a)
                # an oval longer downwards, lifted at its lower edge so it overlaps the next
                p = centre + side * u * size * 0.55 + down * (v * size * 0.7 + size * 0.2)
                lift = max(0.0, v) * size * 0.28 + 0.02
                ring.append(bm.verts.new(p + d * lift))
            mid = bm.verts.new(centre + down * size * 0.2 + d * (size * 0.2))
            for k in range(nseg):
                bm.faces.new((mid, ring[k], ring[(k + 1) % nseg]))
        obs.append(mesh_obj("Scales", bm, scale_m, col))
        # little beads where three scales meet
        bb = bmesh.new()
        for i, d in enumerate(fib_dirs(160, 7.0)):
            m = Matrix.Translation(d * R * 1.02)
            bmesh.ops.create_icosphere(bb, subdivisions=1, radius=0.045, matrix=m)
        obs.append(mesh_obj("Beads", bb, bead, col))
        return obs

    return build(HIGH, True), build(LOW, False)


def void_spire():
    R, H = 1.6, 1.6
    crystal = mottled("Crystal", (0.97, 0.97, 1.0), (0.85, 0.85, 0.92), scale=4.0, rough=0.2, bump=0.12,
                      stretch=(1.0, 1.0, 6.0))
    seam = K.mat("Crystal Seam", (0.55, 0.55, 0.62), rough=0.4)
    sides = 7

    def radius_at(z):
        return R * (0.5 - z / H)               # z from -H/2 (r = R) to H/2 (r = 0)

    def build(col, high):
        obs = []
        if not high:
            obs.append(K.lathe("Spire", [(0.0, -H / 2), (R, -H / 2), (0.0, H / 2)], seg=sides, m=crystal, sides=0,
                               col=col, smooth=False))
            return obs
        # growth terraces: the cone as 16 stepped bands, each a little lip proud of the band above it
        bands = 16
        for i in range(bands):
            za = -H / 2 + H * i / bands
            zb = -H / 2 + H * (i + 1) / bands
            if i == bands - 1:
                zb -= 0.0
            ra, rb = radius_at(za), radius_at(zb)
            prof = [(ra * 1.012, za), (ra * 1.012, za + 0.012), (rb * 1.0 + (ra - rb) * 0.15, zb - 0.004),
                    (max(rb * 0.985, 0.0), zb)]
            obs.append(K.lathe("Band", prof, seg=sides, m=crystal, col=col, smooth=False))
        obs.append(K.lathe("Seam", [(0.0, -H / 2), (R * 0.975, -H / 2), (0.0, H / 2)], seg=sides, m=seam, col=col,
                           smooth=False))
        # thin ridges down each edge
        for k in range(sides):
            a = k / sides * math.tau
            p0 = Vector((math.cos(a) * R, math.sin(a) * R, -H / 2))
            p1 = Vector((0, 0, H / 2))
            mid = (p0 + p1) / 2
            ob = K.cyl("Edge", 0.018, (p1 - p0).length * 0.96, at=mid, seg=6, m=crystal, col=col)
            ob.rotation_mode = "QUATERNION"
            ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((p1 - p0).normalized())
            obs.append(ob)
        return obs

    return build(HIGH, True), build(LOW, False)


def void_stalk():
    r0, r1, H = 0.22, 0.12, 4.0
    stalk = mottled("Stalk", (0.95, 0.93, 0.97), (0.78, 0.76, 0.82), scale=4.0, rough=0.5, bump=0.5,
                    stretch=(4.0, 4.0, 0.3))
    node_m = K.mat("Node", (0.88, 0.86, 0.92), rough=0.4)
    pore = K.mat("Pore", (0.4, 0.38, 0.45), rough=0.8)

    def base_r(t):
        return r0 + (r1 - r0) * t

    def high_r(t, a, z):
        r = base_r(t)
        seg_t = ((z + H / 2) / 0.42) % 1.0                  # a node every 0.42 m
        bulge = math.exp(-((seg_t - 0.5) ** 2) / 0.004) * 0.12
        fib = noise.noise(Vector((math.cos(a) * 9.0, math.sin(a) * 9.0, z * 0.25))) * 0.025
        return r * (1.0 + bulge + fib + 0.03 * math.sin(a * 16.0))

    def build(col, high):
        obs = []
        if not high:
            obs.append(tube("Stalk", rows_between(-H / 2, H / 2, 3), 8, lambda t, a, z: base_r(t) * 1.02, stalk, col))
            return obs
        obs.append(tube("Stalk", rows_between(-H / 2, H / 2, 260), 48, high_r, stalk, col))
        bm = bmesh.new()
        for i in range(70):
            z = -H / 2 + 0.1 + (H - 0.2) * ((i * 0.618) % 1.0)
            a = i * 2.39996
            t = (z + H / 2) / H
            rr = base_r(t) * 1.02
            n = Vector((math.cos(a), math.sin(a), 0))
            bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.012 + 0.01 * (i % 3),
                                       matrix=Matrix.Translation(n * rr + Vector((0, 0, z))))
        obs.append(mesh_obj("Pores", bm, pore, col))
        for k in range(int(H / 0.42)):
            z = -H / 2 + 0.42 * (k + 0.5)
            t = (z + H / 2) / H
            obs.append(K.lathe("Node", [(base_r(t) * 1.08, z - 0.02), (base_r(t) * 1.15, z), (base_r(t) * 1.08, z + 0.02)],
                               seg=48, m=node_m, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ mushrooms
def mushroom_cap():
    # Built at its real shape (radius 1, dome 0.5 high), exported stretched to a dome 1 high: the game squashes it back
    R, HT = 1.0, 0.5
    cap = mottled("Cap", (0.98, 0.98, 1.0), (0.86, 0.86, 0.9), scale=5.0, rough=0.3, bump=0.2)
    wart = K.mat("Wart", (1.0, 1.0, 1.0), rough=0.4)
    gill = K.mat("Gill", (0.62, 0.6, 0.66), rough=0.8)
    gill_deep = K.mat("Gill Deep", (0.28, 0.27, 0.32), rough=0.9)

    def dome(r):
        return HT * max(0.0, 1.0 - (r / R) ** 2) ** 0.6

    def build(col, high):
        obs = []
        n = 24 if not high else 96
        prof = [(0.0, dome(0.0))]
        steps = 6 if not high else 40
        for i in range(1, steps + 1):
            r = R * i / steps
            prof.append((r, dome(r) + (0.0 if r < R * 0.97 else 0.0)))
        prof.append((R, 0.0))
        prof.append((0.0, 0.0))
        obs.append(K.lathe("Cap", prof, seg=n, m=cap, col=col))
        if not high:
            return obs
        # warts on top
        bm = bmesh.new()
        for i, d in enumerate(fib_dirs(140, 5.0)):
            if d.z < 0.15:
                continue
            r = math.sqrt(d.x * d.x + d.y * d.y) * R * 0.92
            a = math.atan2(d.y, d.x)
            z = dome(r)
            s = 0.025 + 0.02 * (noise.noise(d * 6.0) * 0.5 + 0.5)
            m = Matrix.Translation((math.cos(a) * r, math.sin(a) * r, z)) @ Matrix.Diagonal((s, s, s * 0.55, 1.0))
            bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0, matrix=m)
        obs.append(mesh_obj("Warts", bm, wart, col))
        # gills underneath: thin blades from near the stem out to the rim, hanging 4 cm down
        gb = bmesh.new()
        for k in range(110):
            a = k / 110 * math.tau
            r_in = 0.2 if k % 2 == 0 else 0.45
            c, s = math.cos(a), math.sin(a)
            vs = [gb.verts.new((c * r_in, s * r_in, -0.002)), gb.verts.new((c * R * 0.96, s * R * 0.96, -0.002)),
                  gb.verts.new((c * R * 0.96, s * R * 0.96, -0.02)), gb.verts.new((c * r_in, s * r_in, -0.045))]
            gb.faces.new(vs)
        obs.append(mesh_obj("Gills", gb, gill, col, smooth=False))
        obs.append(K.lathe("Gill Shadow", [(0.0, -0.05), (R * 0.95, -0.05), (R * 0.95, -0.049), (0.0, -0.049)],
                           seg=64, m=gill_deep, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


def mushroom_stem():
    r0, r1, H = 0.2, 0.15, 2.2
    stem = mottled("Stem", (0.97, 0.96, 0.98), (0.84, 0.83, 0.87), scale=4.0, rough=0.5, bump=0.4,
                   stretch=(5.0, 5.0, 0.4))
    skirt_m = K.mat("Skirt", (1.0, 1.0, 1.0), rough=0.6)

    def base_r(t):
        r = r0 + (r1 - r0) * t
        return r * (1.0 + 0.35 * max(0.0, 1.0 - t / 0.12) ** 2)      # a bulb at the foot

    def high_r(t, a, z):
        fib = noise.noise(Vector((math.cos(a) * 12.0, math.sin(a) * 12.0, z * 0.3))) * 0.04
        return base_r(t) * (1.0 + fib)

    def build(col, high):
        obs = []
        if not high:
            obs.append(tube("Stem", rows_between(-H / 2, H / 2, 5, dense_bottom=1), 10,
                            lambda t, a, z: base_r(t) * 1.02, stem, col))
            return obs
        obs.append(tube("Stem", rows_between(-H / 2, H / 2, 160, dense_bottom=1), 48, high_r, stem, col))
        zs = H / 2 - H * 0.18
        rs = base_r(0.82)
        prof = []
        for i in range(13):
            t = i / 12
            prof.append((rs * (1.0 + t * 0.9) + 0.01 * math.sin(t * 9.0), zs - t * 0.16))
        prof = prof + [(r - 0.012, z) for (r, z) in reversed(prof)]
        obs.append(K.lathe("Skirt", prof, seg=64, m=skirt_m, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the giant leaf's texture
def giant_leaf():
    # In the leaf's UV space: x across 0..0.5 m (u 0..1, midrib at 0.25), y along 0..1 m (v base 0 to tip 1).
    W, L = 0.5, 1.0
    blade = mottled("Blade", (0.88, 0.88, 0.86), (0.78, 0.78, 0.76), scale=12.0, rough=0.5, bump=0.3)
    vein = K.mat("Vein", (1.0, 1.0, 0.97), rough=0.45)

    def build(col, high):
        obs = []
        if not high:
            bm = bmesh.new()
            vs = [bm.verts.new((0, 0, 0)), bm.verts.new((W, 0, 0)), bm.verts.new((W, L, 0)), bm.verts.new((0, L, 0))]
            bm.faces.new(vs)
            ob = mesh_obj("Leaf", bm, blade, col, smooth=False)
            # its UVs are its place: u = x / W, v = 1 - y / L (glTF flips v, so the game sees v = y / L)
            me = ob.data
            uv = me.uv_layers.new(name="UVMap")
            for loop in me.loops:
                co = me.vertices[loop.vertex_index].co
                uv.data[loop.index].uv = (co.x / W, 1.0 - co.y / L)
            obs.append(ob)
            return obs
        # the blade: quilted between the veins
        bm = bmesh.new()
        nx, ny = 100, 200
        grid = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                x, y = W * i / nx, L * j / ny
                across = abs(x - W / 2) / (W / 2)
                q = math.sin((y * 14.0 - across * 2.6) * math.pi)
                h = 0.006 * (0.5 + 0.5 * q) * (1.0 - across * 0.3) + 0.002 * noise.noise(Vector((x * 40, y * 40, 0.5)))
                row.append(bm.verts.new((x, y, h)))
            grid.append(row)
        for j in range(ny):
            for i in range(nx):
                bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
        obs.append(mesh_obj("Blade", bm, blade, col))
        # the midrib, and the veins curving out from it towards the tip
        obs.append(K.wire("Midrib", [(W / 2, -0.02, 0.006), (W / 2, 0.5, 0.008), (W / 2, 1.02, 0.004)], 0.008,
                          m=vein, col=col))
        for k in range(14):
            y0 = 0.06 + k / 14.0 * 0.95
            for side in (-1.0, 1.0):
                pts = []
                for s in range(6):
                    t = s / 5
                    x = W / 2 + side * t * W / 2 * 1.02
                    y = y0 + t * 0.19 + t * t * 0.03
                    pts.append((x, y, 0.009 - t * 0.004))
                obs.append(K.wire("Vein", pts, 0.0035, m=vein, col=col, res=6, bevel_res=2))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ bake and export
SPECS = {
    # kind: (build, texture size, extrusion, ray, unit scale (x, y, z in Blender), uv margin)
    "bark_trunk": (bark_trunk, 1024, 0.06, 0.15, (1 / 0.32, 1 / 0.32, 1 / 5.5)),
    "bark_limb": (bark_limb, 512, 0.03, 0.06, (1 / 0.1, 1 / 0.1, 1 / 2.0)),
    "leaf_ball": (leaf_ball, 1024, 0.3, 0.6, (1 / 1.8, 1 / 1.8, 1 / 1.8)),
    "void_orb": (void_orb, 1024, 0.12, 0.25, (1 / 1.5, 1 / 1.5, 1 / 1.5)),
    "void_spire": (void_spire, 1024, 0.04, 0.08, (1 / 1.6, 1 / 1.6, 1 / 1.6)),
    "void_stalk": (void_stalk, 512, 0.04, 0.08, (1.0, 1.0, 1 / 4.0)),
    "mushroom_cap": (mushroom_cap, 1024, 0.05, 0.1, (1.0, 1.0, 2.0)),
    "mushroom_stem": (mushroom_stem, 512, 0.06, 0.2, (1 / 0.2, 1 / 0.2, 1 / 2.2)),
    "giant_leaf": (giant_leaf, 1024, 0.02, 0.03, (1.0, 1.0, 1.0)),
}


def main():
    build, size, ext, ray, unit = SPECS[KIND]
    high, low = build()
    hi_tris = K.tri_count(high)
    prop = K.join(NAME, low)
    lo_tris = K.tri_count([prop])
    if KIND != "giant_leaf":
        K.uv_unwrap(prop, margin=0.004)
    maps = K.bake(prop, high, size=size, name=NAME, extrusion=ext, ray=ray,
                  maps=["normal", "ao", "color", "rough"])
    K.finish(prop, maps, size, NAME)
    print("TRIS %s high %d low %d" % (NAME, hi_tris, lo_tris))
    # down to the unit shape the game's MultiMesh copies are sized from
    prop.scale = unit
    bpy.ops.object.select_all(action="DESELECT")
    prop.select_set(True)
    bpy.context.view_layer.objects.active = prop
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if K.has_flag("preview"):
        # the baked maps, to look at; outside the project so they never get committed
        PREVIEW_DIR = Path(os.environ.get("BAKE_PREVIEWS", "/tmp/bake_previews"))
        PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
        for img in maps.values():
            img.filepath_raw = str(PREVIEW_DIR / (img.name + ".png"))
            img.file_format = "PNG"
            img.save()
    K.export([prop], OUT)


main()

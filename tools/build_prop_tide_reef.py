# The Tide Reef, Otto's world, built the detailed way (tools/bake_kit.py; 20 Nov 2026, Hayden: "Then keep baking
# details", the portal worlds' props after Glenmoor): its coral houses, the bubble lamps along the paths and the little
# fishing boat stranded by the way in. Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the pieces tools/build_tide_reef.gd builds from shapes (a house at size 1), so the swap
# (scripts/detail_props.gd dress_tide_reef) puts each exactly where the old one was and every collision stays the
# game's. Blender's X is Godot's X, Blender's -Y is Godot's +Z and Blender's Z is Godot's Y.
#   coral_dome   a house's dome: a ball 2.6 across squashed to 0.95 high, its middle 1.2 up, grown in meandering
#                brain-coral ridges with pores, barnacles and little tube worms. Baked nearly white: the game tints it
#                in the house's own coral colour, which fades and blooms with the tide.
#   coral_trim   the rest of a house: its round blue door of scallop ribs with a pearl knob, the pearly rim round it,
#                the two glowing portholes in riveted shell frames and the scallop shell doorstep. Its door looks +Z.
#   lamp_post    a bubble lamp's post: twisty driftwood 2.6 m tall with knots, barnacles and a curl of kelp, and a
#                shell cup on top that holds the game's own glowing bubble.
#   boat         the stranded fishing boat: a clinker hull in peeling blue paint with barnacles and weed, gunwales and a
#                planked deck, thwarts, the mast with its rings, a patched sail, a coil of rope and an oar.
# Colours are the game's own (sRGB; the Tide Reef isn't tinted to the alien palette).
#
#   python tools/build_prop_tide_reef.py "<out>.glb" <kind> [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

KINDS = ["coral_dome", "coral_trim", "lamp_post", "boat"]
KIND = next((a for a in sys.argv if a in KINDS), "coral_dome")
NAME = KIND
OUT = K.out_path(NAME + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

PALE = (0.94, 0.92, 0.9)
PALE_GROOVE = (0.8, 0.77, 0.75)
DOOR = (0.35, 0.5, 0.75)
TRIM = (1.0, 0.95, 0.88)
PEARL = (1.0, 0.95, 0.9)
GLASS = (1.0, 0.9, 0.55)
DRIFT = (0.75, 0.68, 0.6)
DRIFT_DARK = (0.58, 0.52, 0.46)
SHELL_PINK = (0.98, 0.8, 0.75)
KELP = (0.35, 0.5, 0.25)
BARNACLE = (0.85, 0.82, 0.76)
HULL = (0.35, 0.6, 0.75)
BOAT_WOOD = (0.75, 0.6, 0.45)
SAIL = (1.0, 0.95, 0.85)
PATCH = (0.85, 0.55, 0.45)
ROPE = (0.82, 0.7, 0.48)
WEED = (0.3, 0.45, 0.25)

DOME_R = 2.6
DOME_SQUASH = 0.95
DOME_Y = 1.2
DOOR_C = (0.0, 0.95, 2.45)
PORT_ANG = 0.75
PORT_Y = 1.7
PORT_R = 2.5


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
    """A round bar between two points given in Godot's terms."""
    return rod(name, at(*a), at(*b), r, m, col, seg=seg, r2=r2)


def gwire(name, pts, r, m, col, closed=False, res=12, bevel_res=4):
    return K.wire(name, [at(*p) for p in pts], r, m=m, closed=closed, res=res, bevel_res=bevel_res, col=col)


def ring_pts(c, n, r, count=16):
    """count points round a circle r across about c (Godot), in the plane facing n."""
    c, n = Vector(c), Vector(n).normalized()
    u = n.cross(Vector((0, 1, 0)))
    if u.length < 0.01:
        u = Vector((1, 0, 0))
    u.normalize()
    v = n.cross(u).normalized()
    return [tuple(c + (u * math.cos(k * math.tau / count) + v * math.sin(k * math.tau / count)) * r)
            for k in range(count)]


def blob(name, r, pos, m, col, seed=0, seg=12, lump=0.25, squash=(1.0, 1.0, 1.0)):
    """A lumpy round thing r across at a Godot position, squashed along Godot x, y, z."""
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
    """A material that wanders between two colours (and a third in rarer patches: paint peeling to wood)."""
    m = K.mat(name, a, rough=rough, metal=metal, bump=bump, grain=grain)
    nt, bsdf, co = _nodes(m)
    c = _mix_rgb(nt, _patches(nt, co, scale, lo, hi), a, b)
    if third:
        c = _mix_rgb(nt, _patches(nt, co, scale * 1.7, 0.62, 0.66, w=2.7), c, third)
    nt.links.new(c, bsdf.inputs["Base Color"])
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


# ================================================================ coral dome
def dome_point(theta, phi, r=DOME_R):
    """A point on the dome (Godot): theta round from +Z (the door), phi down from the top."""
    return Vector((r * math.sin(phi) * math.sin(theta), DOME_Y + r * DOME_SQUASH * math.cos(phi),
                   r * math.sin(phi) * math.cos(theta)))


def _near_openings(p):
    """Keep barnacles off the door and the portholes."""
    if p.z > 1.6 and abs(p.x) < 1.25 and p.y < 2.1:
        return True
    for s in (-1, 1):
        a = s * PORT_ANG
        c = Vector((math.sin(a) * PORT_R, PORT_Y, math.cos(a) * PORT_R))
        if (p - c).length < 0.75:
            return True
    return p.y > 2.9 and Vector((p.x, p.z)).length < 2.1          # (the builder's bumps and chimney sit up there)


def _dome_mesh(name, m, col, subdiv, ridges):
    bm = bmesh.new()
    if subdiv:
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    else:
        bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=18, radius=1.0)
    warp = Vector((1.7, 0.4, 2.9))
    for v in bm.verts:
        n = v.co.normalized()
        g = Vector((n.x, n.z, -n.y))                                 # Godot's frame
        d = 0.0
        if ridges:
            q = g * 2.4
            w = Vector((noise.noise(q + warp), noise.noise(q - warp), noise.noise(q * 1.3 + warp * 2.0)))
            r = 1.0 - abs(noise.noise(q * 1.6 + w * 0.9))           # meandering brain-coral ridges
            d = 0.075 * r ** 3 - 0.025
            d += 0.012 * noise.noise(g * 22.0) + 0.006 * noise.noise(g * 55.0)
        p = Vector((g.x * (DOME_R + d), DOME_Y + g.y * (DOME_R + d) * DOME_SQUASH, g.z * (DOME_R + d)))
        # The door and the portholes sit a little way into the dome: keep it flat and back behind them, or the
        # ridges poke out through the glass and the door
        if p.z > 0 and abs(p.x) < 1.0 and p.y < 2.0:
            k = max(0.0, min(1.0, (1.0 - abs(p.x)) / 0.15, (2.0 - p.y) / 0.15))
            p.z = p.z + (min(p.z, 2.28) - p.z) * k
        for side in (-1, 1):
            a = side * PORT_ANG
            n2 = Vector((math.sin(a), 0, math.cos(a)))
            c = Vector((n2.x * PORT_R, PORT_Y, n2.z * PORT_R))
            off = p - c
            lat = (off - n2 * off.dot(n2)).length
            if off.dot(n2) > -0.4 and lat < 0.55:
                k = max(0.0, min(1.0, (0.55 - lat) / 0.1))
                depth = off.dot(n2)
                p -= n2 * (max(0.0, depth + 0.14) * k)
        v.co = Vector(at(p.x, p.y, p.z))
    # Nothing under the ground is ever seen: leave it off the low one so its texture goes on what shows
    gone = [v for v in bm.verts if v.co.z < -0.45]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, True, col)


def coral_dome():
    coral = mottled("Dome Coral", PALE, PALE_GROOVE, scale=7.0, rough=0.8, bump=0.6, lo=0.4, hi=0.7)
    barn = K.mat("Barnacle", BARNACLE, rough=0.9, bump=0.5)
    worm = K.mat("Tube Worm", (0.97, 0.95, 0.92), rough=0.7)
    high = [_dome_mesh("Dome", coral, HIGH, 6, True)]
    rnd = random.Random(7)
    placed = 0
    while placed < 46:
        th = rnd.uniform(-math.pi, math.pi)
        ph = rnd.uniform(0.35, 2.05)
        p = dome_point(th, ph)
        if p.y < 0.1 or _near_openings(p):
            continue
        n = (p - Vector((0, DOME_Y, 0))).normalized()
        r = rnd.uniform(0.05, 0.11)
        high.append(grod("Barnacle", tuple(p - n * 0.03), tuple(p + n * r * 0.9), r, barn, HIGH, seg=10,
                         r2=r * 0.45))
        placed += 1
    for k in range(14):                                          # little white tube worms in clumps near the ground
        th = rnd.uniform(-math.pi, math.pi)
        p = dome_point(th, rnd.uniform(1.75, 2.05))
        if _near_openings(p):
            continue
        n = (p - Vector((0, DOME_Y, 0))).normalized()
        for j in range(3):
            q = p + Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.08, 0.08), rnd.uniform(-0.12, 0.12)))
            tip = q + (n + Vector((0, 0.6, 0))).normalized() * rnd.uniform(0.15, 0.28)
            high.append(grod("Worm", tuple(q - n * 0.03), tuple(tip), 0.025, worm, HIGH, seg=8))
    low = [_dome_mesh("Dome", coral, LOW, 0, False)]
    return high, low


# ================================================================ coral trim
def coral_trim():
    door = mottled("Door", DOOR, (0.28, 0.42, 0.66), scale=5.0, rough=0.55, bump=0.3)
    trim = K.mat("Trim", TRIM, rough=0.4, bump=0.2)
    pearl = K.mat("Pearl", PEARL, rough=0.2, metal=0.3)
    glass = K.mat("Porthole", GLASS, rough=0.2, emit=0.9, emit_rgb=GLASS)
    shell = mottled("Scallop", TRIM, SHELL_PINK, scale=4.0, rough=0.5, bump=0.25)

    def build(col, high):
        obs = []
        cx, cy, cz = DOOR_C
        obs.append(grod("Door", (cx, cy, cz - 0.1), (cx, cy, cz + 0.1), 0.75, door, col, seg=32 if high else 16))
        if high:
            for k in range(10):                               # scallop ribs fanning up from under the knob
                a = math.pi * (0.08 + 0.84 * k / 9.0)
                end = (cx + math.cos(a) * 0.68, cy + math.sin(a) * 0.68 - 0.1, cz + 0.11)
                obs.append(grod("Rib", (cx, cy - 0.45, cz + 0.11), end, 0.035, door, col, seg=8))
            obs.append(grod("Sill", (cx - 0.55, cy - 0.5, cz + 0.11), (cx + 0.55, cy - 0.5, cz + 0.11), 0.04, door,
                            col, seg=8))
        obs.append(gwire("Door Rim", ring_pts((cx, cy, 2.52), (0, 0, 1), 0.82), 0.1, trim, col, closed=True,
                         res=12 if high else 3, bevel_res=4 if high else 1))
        if high:
            for k in range(20):                               # seed pearls set round the rim
                a = k * math.tau / 20
                obs.append(blob("Seed Pearl", 0.045, (cx + math.cos(a) * 0.82, cy + math.sin(a) * 0.82, 2.62), pearl,
                                col, seed=k, seg=8, lump=0.05))
        obs.append(blob("Knob", 0.1, (0.4, cy, 2.62), pearl, col, seg=12 if high else 8, lump=0.0))
        for side in (-1, 1):
            a = side * PORT_ANG
            n = Vector((math.sin(a), 0, math.cos(a)))
            c = Vector((n.x * PORT_R, PORT_Y, n.z * PORT_R))
            obs.append(grod("Glass", tuple(c - n * 0.1), tuple(c + n * 0.1), 0.38, glass, col, seg=24 if high else 12))
            fc = c * 1.02
            fc.y = PORT_Y * 1.02
            obs.append(gwire("Frame", ring_pts(tuple(fc), n, 0.42), 0.07, trim, col, closed=True,
                             res=12 if high else 3, bevel_res=4 if high else 1))
            if high:
                for k in range(8):                            # rivets round the frame
                    p = Vector(ring_pts(tuple(fc + n * 0.06), n, 0.42, 8)[k])
                    obs.append(blob("Rivet", 0.03, tuple(p), pearl, col, seed=k, seg=6, lump=0.0))
                for (u, v) in ((1, 0), (0, 1)):               # a cross of glazing bars
                    side_v = n.cross(Vector((0, 1, 0))).normalized() if u else Vector((0, 1, 0))
                    obs.append(grod("Bar", tuple(c + n * 0.11 - side_v * 0.37), tuple(c + n * 0.11 + side_v * 0.37),
                                    0.018, trim, col, seg=6))
        # The scallop shell doorstep: ribs fanning out from its hinge by the door
        step = blob("Step", 1.0, (0, 0.05, 3.3), shell, col, seg=24 if high else 20, lump=0.0, squash=(1.2, 0.12, 0.9))
        obs.append(step)
        if high:
            for k in range(13):
                a = math.pi * (0.06 + 0.88 * k / 12.0)
                end = (math.cos(a) * 1.12, 0.1, 3.3 - 0.35 + math.sin(a) * 0.95)
                obs.append(grod("Shell Rib", (0, 0.12, 2.55), end, 0.05, shell, col, seg=8, r2=0.02))
            obs.append(gbox("Hinge", (0.6, 0.1, 0.18), (0, 0.12, 2.45), shell, col, bevel=0.04))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ lamp post
LAMP_H = 2.6


def lamp_post():
    wood = mottled("Driftwood", DRIFT, DRIFT_DARK, scale=4.0, rough=0.9, bump=0.5, grain=(30.0, 0.4))
    shell = mottled("Shell Cup", TRIM, SHELL_PINK, scale=3.0, rough=0.45, bump=0.2)
    barn = K.mat("Barnacle", BARNACLE, rough=0.9, bump=0.5)
    kelp = K.mat("Kelp", KELP, rough=0.6, bump=0.3)

    def path(n):
        pts = []
        for k in range(n):
            t = k / (n - 1)
            y = t * (LAMP_H - 0.02)
            pts.append((0.05 * math.sin(t * 5.0), y, 0.05 * math.cos(t * 4.0 + 1.0)))
        return pts

    def build(col, high):
        obs = []
        pts = path(9)
        if high:
            # a twisted driftwood post: three strands wound round each other, with knots
            for s in range(3):
                strand = []
                for k in range(24):
                    t = k / 23
                    base = Vector(path(24)[k])
                    a = s * math.tau / 3 + t * 4.0
                    rr = 0.045 * (1.0 - 0.3 * t)
                    strand.append(tuple(base + Vector((math.cos(a) * rr, 0, math.sin(a) * rr))))
                obs.append(gwire("Strand", strand, 0.055 * 1.0, wood, col, res=8))
            for k, y in enumerate((0.7, 1.5, 2.1)):
                b = Vector(path(24)[int(y / LAMP_H * 23)])
                obs.append(blob("Knot", 0.07, tuple(b + Vector((0.06 * (-1) ** k, 0, 0.04))), wood, col, seed=k, seg=8,
                                lump=0.3))
            rnd = random.Random(3)
            for k in range(9):                                # barnacles low down, where the sea reaches
                y = rnd.uniform(0.05, 0.9)
                a = rnd.uniform(0, math.tau)
                b = Vector(path(24)[int(y / LAMP_H * 23)])
                n = Vector((math.cos(a), 0, math.sin(a)))
                p = b + n * 0.085 + Vector((0, y - b.y, 0))
                obs.append(grod("Barnacle", tuple(p - n * 0.02), tuple(p + n * 0.05), 0.035, barn, col, seg=8,
                                r2=0.015))
            # a curl of kelp wound up the post
            kp = []
            for k in range(30):
                t = k / 29
                y = 0.3 + t * 1.3
                b = Vector(path(24)[int(y / LAMP_H * 23)])
                a = t * 7.0
                kp.append((b.x + math.cos(a) * 0.1, y, b.z + math.sin(a) * 0.1))
            obs.append(gwire("Kelp", kp, 0.022, kelp, col, res=6))
            for k in range(4):
                p = Vector(kp[6 + k * 6])
                obs.append(blob("Kelp Leaf", 0.09, tuple(p + Vector((0.05, -0.05, 0))), kelp, col, seed=k, seg=8,
                                lump=0.2, squash=(0.35, 1.6, 0.12)))
            obs.append(blob("Foot", 0.17, (0, 0.02, 0), wood, col, seg=10, lump=0.35, squash=(1.0, 0.45, 1.0)))
        else:
            obs.append(gwire("Post", pts, 0.085, wood, col, res=2, bevel_res=1))
            obs.append(blob("Foot", 0.17, (0, 0.02, 0), wood, col, seg=8, lump=0.0, squash=(1.0, 0.45, 1.0)))
        # The shell cup on top that holds the bubble (r 0.42, its middle 2.95 up): a fluted shell open upwards
        top = Vector(pts[-1])
        cup = [(0.0, 0.0), (0.12, 0.02), (0.24, 0.1), (0.3, 0.2), (0.31, 0.26), (0.28, 0.24), (0.2, 0.14),
               (0.0, 0.1)]
        lathe = K.lathe("Cup", [(r, z) for r, z in cup], seg=32 if high else 12, m=shell, col=col,
                        flutes=10 if high else 0, flute_depth=0.025 if high else 0.0, flute_z=(0.02, 0.26))
        lathe.location = at(top.x, LAMP_H - 0.08, top.z)
        obs.append(lathe)
        if high:
            for k in range(3):                                # three prongs curling up round the bubble
                a = k * math.tau / 3 + 0.4
                pp = [(top.x + math.cos(a) * r, y, top.z + math.sin(a) * r)
                      for r, y in ((0.27, 2.62), (0.47, 2.85), (0.49, 3.02), (0.43, 3.17))]
                obs.append(gwire("Prong", pp, 0.025, wood, col, res=8))
        else:
            for k in range(3):
                a = k * math.tau / 3 + 0.4
                pp = [(top.x + math.cos(a) * r, y, top.z + math.sin(a) * r)
                      for r, y in ((0.27, 2.62), (0.47, 2.85), (0.49, 3.02), (0.43, 3.17))]
                obs.append(gwire("Prong", pp, 0.025, wood, col, res=2, bevel_res=1))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ stranded boat
HULL_C = (0.0, 0.7, 0.0)
HULL_S = (1.2, 0.8, 2.8)
DECK_Y = 1.05


def _hull(name, m, col, high):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48 if high else 24, v_segments=40 if high else 14, radius=1.0)
    strakes = 7
    for v in bm.verts:
        g = Vector((v.co.x, v.co.z, -v.co.y))
        y = g.y
        if high:
            # clinker strakes: each plank laps over the one under it, a little step in and out
            t = (y + 1.0) / 2.0 * strakes
            lap = (t - math.floor(t))
            g *= 1.0 + 0.012 * lap
            g *= 1.0 + 0.006 * noise.noise(g * 6.0)
        p = Vector((g.x * HULL_S[0], HULL_C[1] + g.y * HULL_S[1], g.z * HULL_S[2]))
        if p.y > DECK_Y:
            p.y = DECK_Y
        v.co = Vector(at(*p))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, True, col)


def _deck_outline(y, inset):
    """The hull's outline at height y, brought in by inset (Godot x, z pairs)."""
    k = 1.0 - ((y - HULL_C[1]) / HULL_S[1]) ** 2
    rx, rz = HULL_S[0] * math.sqrt(k) - inset, HULL_S[2] * math.sqrt(k) - inset
    return rx, rz


def boat():
    hull = mottled("Hull", HULL, (0.28, 0.5, 0.65), scale=5.0, rough=0.7, bump=0.3, third=BOAT_WOOD)
    wood = K.mat("Boat Wood", BOAT_WOOD, rough=0.8, grain=(26.0, 0.4), bump=0.2)
    weed = K.mat("Weed", WEED, rough=0.7, bump=0.4)
    barn = K.mat("Barnacle", BARNACLE, rough=0.9, bump=0.5)
    sail = mottled("Sail", SAIL, (0.88, 0.84, 0.74), scale=4.0, rough=0.95, bump=0.4, third=PATCH)
    rope = K.mat("Rope", ROPE, rough=0.9, bump=0.6)
    iron = K.mat("Iron", (0.25, 0.22, 0.2), rough=0.6, metal=0.7)

    def build(col, high):
        obs = [_hull("Hull", hull, col, high)]
        rx, rz = _deck_outline(DECK_Y, 0.08)
        # the gunwale: a rail round the top of the hull
        rim = [(math.sin(a) * (rx + 0.06), DECK_Y + 0.04, math.cos(a) * (rz + 0.06))
               for a in [k * math.tau / 24 for k in range(24)]]
        obs.append(gwire("Gunwale", rim, 0.07, wood, col, closed=True, res=6 if high else 2,
                         bevel_res=3 if high else 1))
        # the deck, following the hull's outline
        if high:
            for k in range(9):
                x = -rx + (k + 0.5) * 2 * rx / 9
                zz = rz * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2)) - 0.02
                obs.append(gbox("Plank", (2 * rx / 9 - 0.02, 0.1, 2 * zz), (x, DECK_Y - 0.03, 0), wood, col,
                                bevel=0.015))
            for z in (-1.2, 0.0, 1.3):                        # thwarts across the boat
                w = rx * math.sqrt(max(0.0, 1.0 - (z / rz) ** 2))
                obs.append(gbox("Thwart", (2 * w, 0.08, 0.3), (0, DECK_Y + 0.06, z), wood, col, bevel=0.02))
            rnd = random.Random(11)
            for k in range(40):                               # barnacles low on the hull
                a = rnd.uniform(0, math.tau)
                yy = rnd.uniform(0.0, 0.45)
                u = (yy - HULL_C[1]) / HULL_S[1]
                s = math.sqrt(max(0.0, 1.0 - u * u))
                p = Vector((math.sin(a) * HULL_S[0] * s, yy, math.cos(a) * HULL_S[2] * s))
                n = Vector((p.x / HULL_S[0] ** 2, (p.y - HULL_C[1]) / HULL_S[1] ** 2, p.z / HULL_S[2] ** 2)).normalized()
                r = rnd.uniform(0.04, 0.08)
                obs.append(grod("Barnacle", tuple(p - n * 0.02), tuple(p + n * r * 0.8), r, barn, col, seg=8,
                                r2=r * 0.45))
            for k in range(10):                               # weed hanging off the side
                a = rnd.uniform(0, math.tau)
                yy = rnd.uniform(0.3, 0.8)
                u = (yy - HULL_C[1]) / HULL_S[1]
                s = math.sqrt(max(0.0, 1.0 - u * u)) + 0.02
                p = (math.sin(a) * HULL_S[0] * s, yy, math.cos(a) * HULL_S[2] * s)
                obs.append(gwire("Weed", [p, (p[0] * 1.02, p[1] - 0.2, p[2] * 1.02), (p[0] * 1.03, p[1] - 0.45,
                                                                                      p[2] * 1.01)], 0.02, weed, col,
                                 res=6))
            # a coil of rope on the deck and an oar lying across it
            coil = [(0.45 + math.cos(t * 0.5) * (0.22 - t * 0.004), DECK_Y + 0.05 + 0.025 * (t // 12.6),
                     -1.7 + math.sin(t * 0.5) * (0.22 - t * 0.004)) for t in range(40)]
            obs.append(gwire("Rope", coil, 0.03, rope, col, res=8))
            obs.append(grod("Oar", (-0.7, DECK_Y + 0.12, 0.6), (0.4, DECK_Y + 0.12, 2.0), 0.035, wood, col, seg=8))
            obs.append(gbox("Blade", (0.05, 0.04, 0.6), (-0.82, DECK_Y + 0.12, 0.45), wood, col, bevel=0.015,
                            rot=(0, 0.66, 0)))
            obs.append(grod("Bow Ring", (0, 0.95, rz + 0.12), (0, 0.95, rz + 0.18), 0.06, iron, col, seg=10))
        else:
            obs.append(gbox("Deck", (2 * rx * 0.9, 0.08, 2 * rz * 0.88), (0, DECK_Y - 0.02, 0), wood, col))
        # the mast, its rings and the patched sail behind it
        obs.append(grod("Mast", (0, DECK_Y, 0.3), (0, 4.2, 0.3), 0.08, wood, col, seg=12 if high else 6, r2=0.06))
        if high:
            for y in (2.3, 2.9, 3.5):
                obs.append(gwire("Mast Ring", ring_pts((0, y, 0.3), (0, 1, 0), 0.09, 10), 0.02, iron, col,
                                 closed=True, res=6))
            obs.append(grod("Boom", (0, 2.25, 0.3), (0, 2.25, -1.3), 0.04, wood, col, seg=8))
        # the sail: a sheet a little bellied, its edge torn
        bm = bmesh.new()
        nu, nv = (16, 12) if high else (4, 3)
        verts = []
        for j in range(nv + 1):
            for i in range(nu + 1):
                u, v = i / nu, j / nv
                z = 0.2 - u * 1.4
                y = 2.25 + v * 1.55
                x = 0.12 * math.sin(math.pi * u) * math.sin(math.pi * v)
                if high:
                    x += 0.02 * noise.noise(Vector((u * 4, v * 4, 0.5)))
                verts.append(bm.verts.new(at(x, y, z)))
        for j in range(nv):
            for i in range(nu):
                a = j * (nu + 1) + i
                if high and j == nv - 1 and i in (11, 12):
                    continue                                  # a tear at the top
                bm.faces.new([verts[a], verts[a + 1], verts[a + nu + 2], verts[a + nu + 1]])
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.03)
        obs.append(K._obj("Sail", bm, sail, True, col))
        return obs

    return build(HIGH, True), build(LOW, False)


fn, size, ext, ray, emit, ao = {
    "coral_dome": (coral_dome, 1024, 0.12, 0.2, False, True),
    "coral_trim": (coral_trim, 512, 0.06, 0.12, True, True),
    "lamp_post": (lamp_post, 512, 0.05, 0.1, False, True),
    "boat": (boat, 1024, 0.06, 0.12, False, False),
}[KIND]
high, low = fn()
parts = [bake_part(NAME, high, low, size, emit=emit, extrusion=ext, ray=ray, ao=ao)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

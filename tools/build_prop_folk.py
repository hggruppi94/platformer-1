# The Tuftlings' homes in the Secret Garden (28 Nov 2026; Hayden: "I want them to be the inhabitants of the secret
# garden"), built the detailed way (tools/bake_kit.py): each HIGH version is baked onto a LOW one, which is what the
# game draws. scripts/garden_folk.gd puts them round the Great Tree's glade.
#
# Godot's +Z is the front (Blender's -Y). Sizes are for folk about 0.62 m tall.
#   burrow   a grassy mound 2.8 m across and 1.1 m high with a round green door in a ring of stones, a little round
#            window glowing beside it, a stone chimney pot on top, a doorstep and a lantern on a hook.
#
# And the little things their quests send you looking for (each lying where the game puts it, its foot at 0):
#   arrow        one of Fennick's arrows stuck in the ground at a slant: a wooden shaft, a leaf-shaped stone head
#                half buried, three red feathers.
#   posy         a little bunch of garden flowers tied with grass, lying on its side: pink, white and yellow.
#   teacup       a clay cup of tea on a saucer, steam not included (the game adds it).
#   acorn        Bracken's lucky acorn, big as a fist: a glossy nut in a scaly cap with a stalk.
#   shiny_stone  a smooth river pebble with a vein of glittering crystal through it.
#
#   python tools/build_prop_folk.py "<out>.glb" burrow [--preview]
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Euler, Vector, noise  # noqa: E402

KINDS = ["burrow", "arrow", "posy", "teacup", "acorn", "shiny_stone"]
KIND = next((a for a in sys.argv if a in KINDS), "burrow")
OUT = K.out_path(KIND + ".glb")

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

MOUND_R = (1.4, 1.05, 1.25)        # the mound's half-sizes: x, y (height), z
MOUND_Z = -0.25                    # its middle sits a little back, so the front is steep where the door goes
DOOR_R = 0.36
DOOR_Y = 0.4                       # the door's middle over the ground
DOOR_Z = 0.86                      # how far forward the door's face is


def at(x, y, z):
    """Godot's (x, y, z) in Blender's space."""
    return Vector((x, -z, y))


def mound_y(x, z):
    """The mound's height over the ground at (x, z), 0 off it."""
    k = 1 - (x / MOUND_R[0]) ** 2 - ((z - MOUND_Z) / MOUND_R[2]) ** 2
    return MOUND_R[1] * math.sqrt(k) if k > 0 else 0.0


def mound_bm(seg, lump):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=1.0)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, -0.02),
                           plane_no=(0, 0, -1), clear_outer=True)
    for v in bm.verts:
        c = v.co.copy()
        n = noise.noise(c * 2.3) * lump if c.z > 0.05 else 0.0
        g = Vector((c.x * MOUND_R[0], c.y * MOUND_R[2], max(c.z, -0.02) * MOUND_R[1])) * (1 + n)
        v.co = Vector((g.x, g.y - MOUND_Z, g.z))                     # Godot (x, height, MOUND_Z - y)
    # Push the front in where the door's ring stands, so the door sits in a hollow, not on the curve
    for v in bm.verts:
        gx, gz, gy = v.co.x, -v.co.y, v.co.z
        d = math.hypot(gx, gy - DOOR_Y)
        if gz > DOOR_Z - 0.25 and d < DOOR_R + 0.28:
            v.co.y = -min(gz, DOOR_Z - 0.06 + 0.1 * max(0.0, d - DOOR_R) / 0.28)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def burrow():
    grass = K.mat("Burrow Grass", (0.33, 0.52, 0.2), rough=0.9, bump=0.5)
    soil = K.mat("Burrow Soil", (0.36, 0.26, 0.16), rough=0.95, bump=0.6)
    stone = K.mat("Burrow Stone", (0.6, 0.57, 0.55), rough=0.85, pits=0.5, wear=0.4, bump=0.3)
    door = K.mat("Burrow Door", (0.22, 0.45, 0.2), rough=0.6, grain=(9.0, 0.35), wear=0.5)
    wood = K.mat("Burrow Wood", (0.42, 0.27, 0.13), rough=0.7, grain=(12.0, 0.4), wear=0.3)
    iron = K.mat("Burrow Iron", (0.16, 0.15, 0.15), rough=0.55, metal=0.8, pits=0.5)
    brass = K.mat("Burrow Brass", (0.85, 0.65, 0.25), rough=0.3, metal=1.0)
    glow = K.mat("Burrow Window", (1.0, 0.8, 0.45), rough=0.2, emit=2.5, emit_rgb=(1.0, 0.75, 0.4))
    flower_mats = [K.mat("Burrow Flower %d" % i, c, rough=0.6) for i, c in
                   enumerate([(0.98, 0.62, 0.8), (1.0, 0.95, 0.96), (0.98, 0.85, 0.3), (0.7, 0.6, 0.95)])]
    rng = random.Random(2811)

    def build(col, high):
        obs = []
        m = K._obj("Mound", mound_bm(48 if high else 24, 0.05 if high else 0.04), grass, True, col)
        obs.append(m)
        # The door's ring of stones, standing up round the doorway
        n = 13 if high else 1
        if high:
            for k in range(n):
                a = math.tau * k / n
                r = DOOR_R + 0.1
                c = at(math.cos(a) * r, DOOR_Y + math.sin(a) * r, DOOR_Z + 0.02)
                b = K.box("Ring Stone", (0.16 + rng.uniform(-0.02, 0.02), 0.14, 0.13), at=c, m=stone, bevel=0.025,
                          seg=2, rot=(0, -a - math.pi / 2, 0), col=col)
                obs.append(b)
        else:
            ring = K.lathe("Ring", [(DOOR_R - 0.02, -0.07), (DOOR_R + 0.2, -0.07), (DOOR_R + 0.2, 0.07),
                                    (DOOR_R - 0.02, 0.07)], seg=24, m=stone, col=col)
            ring.location = at(0, DOOR_Y, DOOR_Z + 0.02)
            ring.rotation_euler = (math.pi / 2, 0, 0)
            obs.append(ring)
        # A dark doorway behind, so nothing shows round the door's edge
        hole = K.cyl("Doorway", DOOR_R + 0.01, 0.06, at=at(0, DOOR_Y, DOOR_Z - 0.06), seg=24, m=soil,
                     rot=(math.pi / 2, 0, 0), col=col)
        obs.append(hole)
        # The round door: planks with a rim, two iron straps with studs, a brass knob in the middle
        if high:
            for k in range(7):
                x = -DOOR_R + (k + 0.5) * (2 * DOOR_R / 7)
                h = 2 * math.sqrt(max(0.0, DOOR_R ** 2 - x ** 2)) - 0.02
                obs.append(K.box("Plank", (2 * DOOR_R / 7 - 0.008, 0.045, h), at=at(x, DOOR_Y, DOOR_Z), m=door,
                                 bevel=0.008, seg=1, col=col))
            for y in (-0.14, 0.14):
                w = 2 * math.sqrt(DOOR_R ** 2 - y ** 2) - 0.04
                obs.append(K.box("Strap", (w, 0.012, 0.045), at=at(0, DOOR_Y + y, DOOR_Z + 0.028), m=iron,
                                 bevel=0.004, seg=1, col=col))
                for x in (-w / 2 + 0.04, -w / 4, 0.0, w / 4, w / 2 - 0.04):
                    obs.append(K.sphere("Stud", 0.012, at=at(x, DOOR_Y + y, DOOR_Z + 0.036), m=iron, seg=8,
                                        col=col))
            obs.append(K.sphere("Knob", 0.04, at=at(0, DOOR_Y, DOOR_Z + 0.05), m=brass, seg=16, col=col))
            obs.append(K.cyl("Knob Plate", 0.06, 0.01, at=at(0, DOOR_Y, DOOR_Z + 0.03), seg=20, m=brass,
                             rot=(math.pi / 2, 0, 0), col=col))
        else:
            obs.append(K.cyl("Door", DOOR_R, 0.05, at=at(0, DOOR_Y, DOOR_Z), seg=24, m=door,
                             rot=(math.pi / 2, 0, 0), col=col))
            obs.append(K.sphere("Knob", 0.045, at=at(0, DOOR_Y, DOOR_Z + 0.04), m=brass, seg=8, col=col))
        # A doorstep: a flat stone in front
        step = K.cyl("Doorstep", 0.34, 0.06, at=at(0, 0.03, DOOR_Z + 0.25), seg=16 if high else 10, m=stone,
                     col=col)
        step.scale = (1.0, 0.6, 1.0)
        obs.append(step)
        # A little round window to the right of the door, glowing, with a wooden frame and a cross bar
        wx, wy = 0.72, 0.42
        wz = 0.0
        for zz in [z / 100 for z in range(140, -10, -1)]:
            if mound_y(wx, zz) >= wy:
                wz = zz
                break
        nrm = Vector((wx / MOUND_R[0] ** 2, wy / MOUND_R[1] ** 2, (wz - MOUND_Z) / MOUND_R[2] ** 2)).normalized()
        yaw = math.atan2(nrm.x, nrm.z)
        win = K.cyl("Window", 0.13, 0.04, at=at(wx, wy, wz), seg=20 if high else 12, m=glow,
                    rot=(math.pi / 2, 0, yaw), col=col)
        obs.append(win)
        frame = K.lathe("Window Frame", [(0.12, -0.04), (0.17, -0.04), (0.17, 0.04), (0.12, 0.04)],
                        seg=24 if high else 12, m=wood, col=col)
        frame.location = at(wx, wy, wz) + at(nrm.x, nrm.y, nrm.z) * 0.02
        frame.rotation_euler = (math.pi / 2, 0, yaw)
        obs.append(frame)
        if high:
            bar = K.box("Window Bar", (0.26, 0.02, 0.025), at=at(wx, wy, wz) + at(nrm.x, nrm.y, nrm.z) * 0.03,
                        m=wood, col=col)
            bar.rotation_euler = (0, 0, yaw)
            obs.append(bar)
            bar2 = K.box("Window Bar", (0.025, 0.02, 0.26), at=at(wx, wy, wz) + at(nrm.x, nrm.y, nrm.z) * 0.03,
                         m=wood, col=col)
            bar2.rotation_euler = (0, 0, yaw)
            obs.append(bar2)
        # A stone chimney pot poking out of the top, a little back and to the left
        cx, cz = -0.38, -0.45
        cy = mound_y(cx, cz)
        prof = [(0.0, -0.2), (0.11, -0.2), (0.11, 0.18), (0.14, 0.2), (0.14, 0.27), (0.09, 0.27), (0.09, 0.2),
                (0.0, 0.2)]
        if high:
            for k in range(4):
                for j in range(6):
                    a = math.tau * (j + 0.5 * (k % 2)) / 6
                    obs.append(K.box("Chimney Stone", (0.09, 0.08, 0.1),
                                     at=at(cx + math.cos(a) * 0.1, cy - 0.12 + 0.085 * k, cz + math.sin(a) * 0.1),
                                     m=stone, bevel=0.015, seg=1, rot=(0, 0, -a), col=col))
            obs.append(K.lathe("Chimney Cap", [(0.0, 0.0), (0.16, 0.0), (0.16, 0.05), (0.0, 0.05)], seg=16, m=stone,
                               at=at(cx, cy + 0.22, cz), col=col))
        else:
            obs.append(K.lathe("Chimney", prof, seg=10, m=stone, at=at(cx, cy, cz), col=col))
        # A lantern on a curled hook to the left of the door
        lx = -DOOR_R - 0.32
        lz = DOOR_Z - 0.08
        hook = [at(lx + 0.12, 0.62, lz), at(lx + 0.05, 0.72, lz + 0.05), at(lx, 0.7, lz + 0.08)]
        obs.append(K.wire("Hook", hook, 0.012 if high else 0.015, m=iron, res=8 if high else 3,
                          bevel_res=2 if high else 1, col=col))
        obs.append(K.cyl("Lantern", 0.05, 0.11, at=at(lx, 0.6, lz + 0.08), seg=8 if high else 6, m=glow, col=col))
        obs.append(K.cyl("Lantern Lid", 0.06, 0.03, at=at(lx, 0.67, lz + 0.08), seg=8 if high else 6, m=iron,
                         r2=0.02, col=col))
        if high:
            # Grass tufts and little flowers over the mound
            for i in range(320):
                a = rng.uniform(0, math.tau)
                rr = math.sqrt(rng.uniform(0.0, 0.92))
                x, z = math.cos(a) * rr * MOUND_R[0], MOUND_Z + math.sin(a) * rr * MOUND_R[2]
                if z > DOOR_Z - 0.35 and abs(x) < DOOR_R + 0.35:
                    continue
                y = mound_y(x, z)
                if i % 6 == 0:
                    fm = flower_mats[i % len(flower_mats)]
                    obs.append(K.sphere("Flower", 0.03, at=at(x, y + 0.03, z), m=fm, seg=6, scale=(1, 1, 0.5),
                                        col=col))
                else:
                    tilt = (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0)
                    obs.append(K.cyl("Tuft", 0.015, 0.12, at=at(x, y + 0.04, z), seg=4, m=grass, r2=0.002, rot=tilt,
                                     col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


def bake_part(name, high, low, size, extrusion=0.05, ray=0.15):
    hi_tris = K.tri_count(high)
    prop = K.join(name, low)
    lo_tris = K.tri_count([prop])
    K.uv_unwrap(prop, margin=0.006)
    maps = K.bake(prop, high, size=size, name=name, extrusion=extrusion, ray=ray,
                  maps=["normal", "ao", "color", "rough", "metal", "emit"])
    K.finish(prop, maps, size, name, emit_strength=2.0)
    print("TRIS %s high %d low %d" % (name, hi_tris, lo_tris))
    return prop


def arrow():
    wood = K.mat("Arrow Wood", (0.55, 0.36, 0.18), rough=0.6, grain=(30.0, 0.3))
    stone = K.mat("Arrow Head", (0.35, 0.37, 0.4), rough=0.5, pits=0.4)
    feather = K.mat("Arrow Feather", (0.78, 0.22, 0.08), rough=0.7, bump=0.4)
    twine = K.mat("Arrow Twine", (0.85, 0.78, 0.6), rough=0.9, bump=0.5)
    soil = K.mat("Arrow Soil", (0.35, 0.25, 0.15), rough=1.0, bump=0.7)
    tilt = (0.45, 0.0, 0.3)

    def build(col, high):
        obs = []
        L = 0.62
        seg = 8 if high else 5
        shaft = K.cyl("Shaft", 0.011, L, at=(0, 0, L / 2 - 0.05), seg=seg, m=wood, col=col)
        obs.append(shaft)
        for k in range(3):
            a = math.tau * k / 3
            bm = bmesh.new()
            pts = [(0.0, L - 0.2), (0.045, L - 0.17), (0.05, L - 0.06), (0.0, L - 0.04)]
            vs = [bm.verts.new((math.cos(a) * r, math.sin(a) * r, z - 0.05)) for r, z in pts]
            bm.faces.new(vs)
            obs.append(K._obj("Feather", bm, feather, True, col))
        if high:
            for z in (L - 0.22, L - 0.03):
                obs.append(K.cyl("Twine", 0.014, 0.018, at=(0, 0, z - 0.05), seg=10, m=twine, col=col))
        mound = K.sphere("Soil", 0.08, at=(0.03, -0.02, 0.0), m=soil, seg=10 if high else 6, scale=(1.2, 1, 0.35),
                         col=col)
        obs.append(mound)
        # Tilt the arrow's pieces round its foot
        R = Euler(tilt).to_matrix().to_4x4()
        for ob in obs[:-1]:
            ob.matrix_basis = R @ ob.matrix_basis
        return obs
    return build(HIGH, True), build(LOW, False)


def posy():
    stem = K.mat("Posy Stem", (0.3, 0.55, 0.2), rough=0.7)
    tie = K.mat("Posy Tie", (0.75, 0.68, 0.4), rough=0.9, bump=0.5)
    cols = [K.mat("Posy %d" % i, c, rough=0.6, bump=0.2) for i, c in
            enumerate([(0.98, 0.55, 0.75), (1.0, 0.97, 0.97), (1.0, 0.85, 0.25), (0.98, 0.7, 0.85)])]
    heart = K.mat("Posy Heart", (0.95, 0.75, 0.15), rough=0.5)
    rng = random.Random(7)

    def build(col, high):
        obs = []
        for k in range(7):
            a = rng.uniform(-0.35, 0.35)
            end = Vector((0.26, a * 0.3, 0.06 + 0.04 * rng.random()))
            start = Vector((-0.08, 0.0, 0.04))
            obs.append(K.wire("Stem", [start, (start + end) / 2, end], 0.006 if high else 0.008, m=stem,
                              res=4 if high else 2, bevel_res=1, col=col))
            fm = cols[k % len(cols)]
            if high:
                for p in range(5):
                    b = math.tau * p / 5
                    off = Vector((0, math.cos(b) * 0.022, math.sin(b) * 0.022))
                    obs.append(K.sphere("Petal", 0.018, at=end + off + Vector((0.01, 0, 0)), m=fm, seg=8,
                                        scale=(0.4, 1, 1), col=col))
                obs.append(K.sphere("Heart", 0.012, at=end + Vector((0.016, 0, 0)), m=heart, seg=8, col=col))
            else:
                obs.append(K.sphere("Flower", 0.035, at=end + Vector((0.01, 0, 0)), m=fm, seg=6, scale=(0.5, 1, 1),
                                    col=col))
        obs.append(K.cyl("Tie", 0.022, 0.03, at=(0.0, 0, 0.04), seg=8 if high else 6, m=tie, rot=(0, math.pi / 2, 0),
                         col=col))
        return obs
    return build(HIGH, True), build(LOW, False)


def teacup():
    clay = K.mat("Cup Clay", (0.75, 0.45, 0.3), rough=0.5, wear=0.4, bump=0.2)
    glaze = K.mat("Cup Glaze", (0.35, 0.6, 0.65), rough=0.25, bump=0.1)
    tea = K.mat("Cup Tea", (0.45, 0.28, 0.1), rough=0.15)

    def build(col, high):
        seg = 24 if high else 12
        obs = [K.lathe("Saucer", [(0.0, 0.0), (0.06, 0.0), (0.11, 0.012), (0.12, 0.022), (0.1, 0.018),
                                  (0.0, 0.012)], seg=seg, m=glaze, col=col),
               K.lathe("Cup", [(0.0, 0.015), (0.035, 0.015), (0.05, 0.03), (0.058, 0.08), (0.062, 0.095),
                               (0.054, 0.095), (0.05, 0.08), (0.0, 0.08)], seg=seg, m=clay, col=col),
               K.cyl("Tea", 0.05, 0.004, at=(0, 0, 0.082), seg=seg, m=tea, col=col)]
        obs.append(K.wire("Handle", [(0.055, 0, 0.075), (0.085, 0, 0.065), (0.08, 0, 0.035), (0.054, 0, 0.035)],
                          0.007 if high else 0.009, m=clay, res=6 if high else 2, bevel_res=2 if high else 1, col=col))
        if high:
            obs.append(K.cyl("Glaze Band", 0.0605, 0.012, at=(0, 0, 0.07), seg=seg, m=glaze, col=col))
        return obs
    return build(HIGH, True), build(LOW, False)


def acorn():
    nut = K.mat("Acorn Nut", (0.62, 0.38, 0.12), rough=0.25, bump=0.15)
    cap = K.mat("Acorn Cap", (0.42, 0.3, 0.16), rough=0.9, bump=0.6)

    def build(col, high):
        seg = 24 if high else 10
        obs = [K.lathe("Nut", [(0.0, 0.0), (0.03, 0.006), (0.055, 0.03), (0.065, 0.07), (0.062, 0.1), (0.0, 0.1)],
                       seg=seg, m=nut, col=col)]
        if high:
            for k in range(5):
                z = 0.095 + 0.012 * k
                r = 0.072 - 0.012 * k
                for j in range(14 - k):
                    a = math.tau * (j + 0.5 * (k % 2)) / (14 - k)
                    obs.append(K.sphere("Scale", 0.012, at=(math.cos(a) * r, math.sin(a) * r, z), m=cap, seg=6,
                                        scale=(1, 1, 0.6), col=col))
        obs.append(K.lathe("Cap", [(0.0, 0.09), (0.07, 0.09), (0.074, 0.105), (0.055, 0.135), (0.0, 0.145)],
                           seg=seg, m=cap, col=col))
        obs.append(K.cyl("Stalk", 0.008, 0.035, at=(0.004, 0, 0.16), seg=6, m=cap, col=col))
        return obs
    return build(HIGH, True), build(LOW, False)


def shiny_stone():
    rock = K.mat("Pebble", (0.45, 0.47, 0.55), rough=0.35, bump=0.2)
    crystal = K.mat("Pebble Crystal", (0.6, 0.9, 1.0), rough=0.1, emit=1.2, emit_rgb=(0.5, 0.85, 1.0))

    def build(col, high):
        obs = [K.sphere("Pebble", 0.08, at=(0, 0, 0.035), m=rock, seg=20 if high else 10, scale=(1.3, 1.0, 0.55),
                        col=col)]
        if high:
            for k in range(9):
                x = -0.09 + 0.022 * k
                obs.append(K.box("Crystal", (0.02, 0.02, 0.03 + 0.015 * (k % 3)), at=(x, 0.01 * math.sin(k), 0.065),
                                 m=crystal, rot=(0.2 * k, 0.3, 0.5 * k), col=col))
        else:
            obs.append(K.box("Vein", (0.19, 0.03, 0.03), at=(0, 0, 0.065), m=crystal, col=col))
        return obs
    return build(HIGH, True), build(LOW, False)


SPECS = {"burrow": (burrow, 1024, 0.05, 0.15), "arrow": (arrow, 256, 0.01, 0.03), "posy": (posy, 256, 0.01, 0.03),
         "teacup": (teacup, 256, 0.008, 0.02), "acorn": (acorn, 256, 0.01, 0.03),
         "shiny_stone": (shiny_stone, 256, 0.01, 0.03)}
fn, size, ext, ray = SPECS[KIND]
high, low = fn()
parts = [bake_part(KIND, high, low, size, extrusion=ext, ray=ray)]
K.export(parts, OUT)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

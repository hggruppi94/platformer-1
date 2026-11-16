# The Void's sign posts, built the detailed way (tools/bake_kit.py; 16 Nov 2026, Hayden: "give everything the baked
# in details"). The builder's sign (tools/build_town.gd sign_post) is a 2 m pole with a plain board on it, as wide as
# its words need (2.2 m, or 0.32 m a letter and 0.8 m more). This one is a carved six-sided post with rings round it
# and a glowing crystal on top, and a board of three planks in a raised frame with brass corners and nails.
#
# Boards can't stretch far without their grain stretching too, so there are five widths (BOARDS) in one model, each
# its own mesh ("Board24" is 2.4 m...), all sharing one baked texture with the post. The game keeps the nearest width
# and stretches it the last little bit (scripts/detail_props.gd). Colours are the Void's (the builder's after
# theme.gd's alien palette: "Sign Wood" is navy there). The front faces Godot's +Z (Blender's -Y), and nothing in
# front of the board comes out further than the builder's board (its words sit 0.07 m out).
#
#   python tools/build_prop_sign.py "<out>.glb" [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402

OUT = K.out_path("sign_post.glb")
NAME = "sign_post"
BOARDS = [2.4, 3.4, 4.6, 6.4, 9.0]
LIFT = 3.0                       # each piece is baked this far above the last, so their rays never cross
random.seed(11)

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

WOOD = K.mat("Sign Wood", (0.098, 0.116, 0.386), rough=0.8, grain=(7.0, 0.35), bump=0.12)
PLANK = K.mat("Sign Plank", (0.13, 0.15, 0.45), rough=0.78, grain=(9.0, 0.3), bump=0.1)
TRIM = K.mat("Sign Trim", (0.55, 0.45, 0.78), rough=0.6, grain=(12.0, 0.15), bump=0.05)
BRASS = K.mat("Sign Brass", (0.85, 0.7, 0.35), rough=0.35, metal=1.0, pits=0.1)
CRYSTAL = K.mat("Sign Crystal", (0.55, 0.95, 0.9), rough=0.2, emit=1.0, emit_rgb=(0.45, 1.0, 0.9))


def post(col, high, z0):
    obs = []
    seg = 6
    prof = [(0.0, 0.0), (0.1, 0.0), (0.1, 0.12), (0.085, 0.16), (0.08, 1.55), (0.0, 1.55)]
    obs.append(K.lathe("Post", prof, seg=seg, m=WOOD, at=(0, 0, z0), smooth=False, col=col))
    # rings round it, and a cap on top with the crystal
    for zz in ([0.14, 0.5, 1.0] if high else [0.14]):
        obs.append(K.lathe("Ring", [(0.0, zz), (0.097, zz), (0.097, zz + 0.05), (0.0, zz + 0.05)], seg=seg,
                           m=TRIM, at=(0, 0, z0), smooth=False, col=col))
    obs.append(K.lathe("Cap", [(0.0, 2.55), (0.11, 2.55), (0.11, 2.6), (0.07, 2.66), (0.0, 2.66)], seg=seg, m=TRIM,
                       at=(0, 0, z0), smooth=False, col=col))
    obs.append(K.lathe("Crystal", [(0.0, 2.66), (0.05, 2.7), (0.045, 2.84), (0.0, 2.92)], seg=6 if high else 5,
                       m=CRYSTAL, at=(0, 0, z0), smooth=False, col=col))
    if high:
        # notches carved into the post between its rings
        for i in range(10):
            a = i / 10 * math.tau
            obs.append(K.box("Notch", (0.03, 0.012, 0.02), at=(math.cos(a) * 0.082, math.sin(a) * 0.082,
                                                                 z0 + 0.3 + (i % 3) * 0.05), m=TRIM,
                             rot=(0, 0, a), col=col))
    return obs


def board(w, col, high, z0):
    obs = []
    c = z0 + 2.1
    # three planks a hair apart, each a slightly different shade of the same wood (the bake picks it up)
    for k, dz in enumerate([-0.27, 0.0, 0.27]):
        obs.append(K.box("Plank", (w - 0.12, 0.08 if high else 0.1, 0.25), at=(0, 0.005 * (k - 1), c + dz), m=PLANK,
                         bevel=0.012 if high else 0, col=col))
    if not high:
        obs.append(K.box("Back", (w, 0.04, 0.9), at=(0, 0.04, c), m=PLANK, col=col))
    # the raised frame round them
    for sz in (-1, 1):
        obs.append(K.box("Frame", (w, 0.12, 0.08), at=(0, 0, c + sz * 0.41), m=TRIM, bevel=0.015 if high else 0,
                         col=col))
    for sx in (-1, 1):
        obs.append(K.box("Frame", (0.08, 0.12, 0.9), at=(sx * (w / 2 - 0.04), 0, c), m=TRIM,
                         bevel=0.015 if high else 0, col=col))
    if high:
        # brass corner plates and nails along the frame
        for sx in (-1, 1):
            for sz in (-1, 1):
                obs.append(K.box("Corner", (0.16, 0.012, 0.16), at=(sx * (w / 2 - 0.08), -0.062, c + sz * 0.37),
                                 m=BRASS, bevel=0.004, col=col))
                obs.append(K.sphere("Nail", 0.012, at=(sx * (w / 2 - 0.08), -0.068, c + sz * 0.37), m=BRASS, seg=8,
                                    scale=(1, 0.5, 1), col=col))
        n = int(w / 0.5)
        for i in range(n):
            x = -w / 2 + 0.25 + i * (w - 0.5) / max(1, n - 1)
            for sz in (-1, 1):
                obs.append(K.sphere("Nail", 0.01, at=(x, -0.061, c + sz * 0.41), m=BRASS, seg=8, scale=(1, 0.5, 1),
                                    col=col))
        # a few dents and scratches in the planks
        for i in range(int(w * 3)):
            obs.append(K.box("Scratch", (random.uniform(0.05, 0.2), 0.01, 0.006),
                             at=(random.uniform(-w / 2 + 0.2, w / 2 - 0.2), -0.04, c + random.uniform(-0.35, 0.35)),
                             m=WOOD, rot=(0, random.uniform(-0.3, 0.3), 0), col=col))
    return obs


high = post(HIGH, True, 0.0)
low_parts = {"Post": post(LOW, False, 0.0)}
for i, w in enumerate(BOARDS):
    z0 = LIFT * (i + 1)
    high += board(w, HIGH, True, z0)
    low_parts["Board%d" % round(w * 10)] = board(w, LOW, False, z0)

hi_tris = K.tri_count(high)
# Bake everything onto one joined object (one texture), then split it back into its pieces by height
names = list(low_parts.keys())
joined = [K.join(n, obs) for n, obs in low_parts.items()]
prop = K.join(NAME, joined)
lo_tris = K.tri_count([prop])
K.uv_unwrap(prop, margin=0.006)
maps = K.bake(prop, high, size=1024, name=NAME, extrusion=0.02, ray=0.06,
              maps=["normal", "ao", "color", "rough", "metal", "emit"])
K.finish(prop, maps, 1024, NAME, emit_strength=2.0)



def keep_only(ob, test, shift=0.0):
    """Deletes the faces of ob whose middle fails test(z), and moves what's left down by shift."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    gone = [f for f in bm.faces if not test(f.calc_center_median().z)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:
        v.co.z -= shift
    bm.to_mesh(ob.data)
    bm.free()


pieces = []
for i, n in enumerate(names):
    lo, hi = (-1.0, LIFT * 0.99) if i == 0 else (LIFT * i + 1.0, LIFT * i + 2.95)
    new = prop.copy()
    new.data = prop.data.copy()
    new.name = n
    new.data.name = n
    prop.users_collection[0].objects.link(new)
    keep_only(new, lambda z, lo=lo, hi=hi: lo <= z < hi, LIFT * i)
    pieces.append(new)
bpy.data.objects.remove(prop)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
print("PIECES", [(p.name, len(p.data.polygons)) for p in pieces])
K.export(pieces, OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    # the very detailed one, with a 3.4 m board, for pictures
    for o in list(HIGH.all_objects):
        if o.type != "MESH":
            o = K.to_mesh(o)
        o.data.transform(o.matrix_world)          # into world space, so heights are real heights
        o.matrix_world = o.matrix_world.__class__.Identity(4)
        keep_only(o, lambda z: z < LIFT * 0.99 or LIFT * 2 + 1.0 <= z < LIFT * 2 + 2.95)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        for v in bm.verts:
            if v.co.z > LIFT:
                v.co.z -= LIFT * 2
        bm.to_mesh(o.data)
        bm.free()
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

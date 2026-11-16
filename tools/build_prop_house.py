# Stars Hollow's houses from the outside, built the detailed way (tools/bake_kit.py; 16 Nov 2026, Hayden: "give
# everything the baked in details"): white picket fences (a pointed picket with its two rails, and a square post with
# a cap and a ball for the ends), and the front porch of every house on Maple Lane (a deck of boards on a lattice
# skirt with a step, two turned columns with brackets, a beam and a lantern by the door) with its shingled roof.
# Each HIGH version is baked onto a LOW one, which is what the game draws.
#
# Sizes match the builder's pieces (tools/build_earth.gd _picket_fence, _house) so the swap (scripts/detail_props.gd)
# puts each exactly where the old one was:
#   picket      one picket and the rails to the next one, 0.35 m on (the builder's spacing); the game stretches the
#               rails to fit each fence's own spacing. The fence runs along Godot's +Z (Blender's -Y).
#   fence_post  the post at each end of a fence.
#   porch       its origin is the middle of the house's front wall on the ground, the porch out in front (Godot +Z).
#               The deck is 5 x 2 m and 0.3 m high, like the builder's slab (whose collision stays).
#   porch_roof  the roof over it, shingles in a pale grey: the game tints it with the house's own roof colour (and
#               winter's snow, scripts/seasons.gd).
# Colours are the builder's (sRGB). Collisions stay the builder's.
#
#   python tools/build_prop_house.py "<out>.glb" <picket|fence_post|porch|porch_roof> [--blend] [--preview]

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402
import bmesh  # noqa: E402

KINDS = ["picket", "fence_post", "porch", "porch_roof"]
KIND = next((a for a in sys.argv if a in KINDS), "picket")
NAME = KIND
OUT = K.out_path(NAME + ".glb")
random.seed(KINDS.index(KIND) * 17 + 3)

K.reset()
HIGH = K.new_collection("High")
LOW = K.new_collection("Low")

WHITE = (0.96, 0.95, 0.92)
SPACING = 0.35


def mesh_from(name, verts, faces, m, col, smooth=False):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return K._obj(name, bm, m, smooth, col)


def extrude_x(name, outline, x0, x1, m, col):
    """A shape drawn in Blender's y/z plane (a list of (y, z)), pushed out along x from x0 to x1."""
    n = len(outline)
    verts = [(x0, y, z) for (y, z) in outline] + [(x1, y, z) for (y, z) in outline]
    faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return mesh_from(name, verts, faces, m, col)


def bevel(ob, w, seg=2):
    bv = ob.modifiers.new("Bevel", "BEVEL")
    bv.width = w
    bv.segments = seg
    bv.limit_method = "ANGLE"
    return ob


def paint(name="Fence Paint"):
    # White paint over wood: the grain shows through a little, and a few chips
    return K.mat(name, WHITE, rough=0.55, grain=(14.0, 0.06), pits=0.2, bump=0.12)


# ================================================================ fences
def picket_outline(w, h, tip):
    """A picket's face (y across, z up): straight sides and a pointed top with little shoulders."""
    return [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, h - tip * 0.25), (w * 0.22, h - tip * 0.05), (0.0, h + tip * 0.75),
            (-w * 0.22, h - tip * 0.05), (-w / 2, h - tip * 0.25)]


def picket():
    wood = paint()
    nail = K.mat("Nail", (0.35, 0.33, 0.32), rough=0.4, metal=1.0)

    def build(col, high):
        obs = []
        p = extrude_x("Picket", picket_outline(0.1, 1.0, 0.14), -0.018, 0.018, wood, col)
        if high:
            bevel(p, 0.005)
        obs.append(p)
        # the rails, behind the pickets (Blender +x is the fence's back), from this picket to the next
        for z in (0.35, 0.8):
            r = K.box("Rail", (0.04, SPACING + (0.002 if not high else 0.0), 0.08), at=(0.04, -SPACING / 2, z),
                      m=wood, bevel=0.006 if high else 0, col=col)
            obs.append(r)
            if high:
                for dz in (-0.018, 0.018):
                    obs.append(K.cyl("Nail", 0.0055, 0.006, at=(-0.0185, 0.0, z + dz), seg=8, m=nail,
                                     rot=(0, math.pi / 2, 0), col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


def fence_post():
    wood = paint("Post Paint")

    def build(col, high):
        obs = []
        obs.append(K.box("Post", (0.11, 0.11, 1.1), at=(0, 0, 0.55), m=wood, bevel=0.01 if high else 0, col=col))
        # a skirt board round its foot and a cap with a ball on it
        obs.append(K.box("Foot", (0.135, 0.135, 0.12), at=(0, 0, 0.06), m=wood, bevel=0.008 if high else 0, col=col))
        cap = K.lathe("Cap", [(0.0, 1.1), (0.085, 1.1), (0.085, 1.13), (0.07, 1.15), (0.03, 1.19), (0.0, 1.2)],
                      seg=4, m=wood, smooth=False, col=col)
        cap.rotation_euler = (0, 0, math.pi / 4)
        obs.append(cap)
        n = 20 if high else 8
        obs.append(K.lathe("Finial", [(0.0, 1.19), (0.022, 1.2), (0.016, 1.22), (0.05, 1.27), (0.045, 1.31),
                                      (0.0, 1.335)], seg=n, m=wood, col=col))
        if high:
            for z in (0.98, 1.03):
                obs.append(K.box("Moulding", (0.122, 0.122, 0.02), at=(0, 0, z), m=wood, bevel=0.006, col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


# ================================================================ the porch
DECK_W = 5.0
DECK_D = 2.0
DECK_H = 0.3
COL_X = 2.4
COL_Y = -1.85
ROOF_LOW = 2.93          # the old roof's underside (3.0 - 0.075)


def column_profile():
    """A turned porch column from the deck (0.3) to the beam: a square-ish base, a tapering shaft with rings,
    and a capital."""
    z0, z1 = DECK_H, ROOF_LOW - 0.2
    return [(0.0, z0), (0.13, z0), (0.13, z0 + 0.12), (0.11, z0 + 0.14), (0.1, z0 + 0.2), (0.085, z0 + 0.24),
            (0.08, z0 + 0.45), (0.09, z0 + 0.5), (0.078, z0 + 0.55), (0.07, z1 - 0.35), (0.082, z1 - 0.3),
            (0.07, z1 - 0.26), (0.075, z1 - 0.12), (0.11, z1 - 0.04), (0.125, z1), (0.0, z1)]


def porch():
    wood = paint("Porch Trim")
    deck = K.mat("Porch Wood", (0.55, 0.4, 0.28), rough=0.8, grain=(10.0, 0.3), pits=0.15, bump=0.15)
    lattice = K.mat("Lattice", (0.9, 0.88, 0.84), rough=0.7, grain=(16.0, 0.08), bump=0.1)
    dark = K.mat("Under Porch", (0.08, 0.07, 0.06), rough=1.0)
    brass = K.mat("Lantern Brass", (0.75, 0.6, 0.32), rough=0.35, metal=1.0, pits=0.1)
    glass = K.mat("Lantern Glass", (1.0, 0.86, 0.55), rough=0.15, emit=1.5, emit_rgb=(1.0, 0.8, 0.45))

    def build(col, high):
        obs = []
        # the deck: boards running out from the house, a nosing round the front, a dark gap under it
        if high:
            n = int(DECK_W / 0.14)
            w = DECK_W / n
            for i in range(n):
                x = -DECK_W / 2 + (i + 0.5) * w
                obs.append(K.box("Board", (w - 0.012, DECK_D - 0.05, 0.035), at=(x, -DECK_D / 2 + 0.01, DECK_H - 0.0175),
                                 m=deck, bevel=0.004, col=col))
            obs.append(K.box("Deck Bed", (DECK_W - 0.02, DECK_D - 0.06, 0.04), at=(0, -DECK_D / 2, DECK_H - 0.05),
                             m=dark, col=col))
        else:
            obs.append(K.box("Deck", (DECK_W, DECK_D - 0.04, 0.04), at=(0, -DECK_D / 2 + 0.01, DECK_H - 0.02),
                             m=deck, col=col))
        obs.append(K.box("Nosing", (DECK_W + 0.06, 0.06, 0.05), at=(0, -DECK_D + 0.01, DECK_H - 0.015), m=deck,
                         bevel=0.012 if high else 0, col=col))
        for sx in (-1, 1):
            obs.append(K.box("Nosing", (0.06, DECK_D, 0.05), at=(sx * (DECK_W / 2 + 0.0), -DECK_D / 2, DECK_H - 0.015),
                             m=deck, bevel=0.012 if high else 0, col=col))
        # the skirt: lattice panels between little white posts, front and sides
        skirt_h = DECK_H - 0.04

        def skirt(cx, cy, length, along_x):
            if along_x:
                obs.append(K.box("Skirt", (length, 0.03, skirt_h), at=(cx, cy, skirt_h / 2), m=dark, col=col))
            else:
                obs.append(K.box("Skirt", (0.03, length, skirt_h), at=(cx, cy, skirt_h / 2), m=dark, col=col))
            if not high:
                return
            # lattice: slats on both diagonals, a little in front of the dark gap
            ln = skirt_h * math.sqrt(2.0)
            k = -length / 2 + skirt_h / 2
            while k <= length / 2 - skirt_h / 2 + 0.001:
                for d in (1, -1):
                    if along_x:
                        obs.append(K.box("Slat", (ln, 0.012, 0.025), at=(cx + k, cy - 0.02, skirt_h / 2),
                                         rot=(0, d * math.pi / 4, 0), m=lattice, col=col))
                    else:
                        out = 0.02 if cx > 0 else -0.02
                        obs.append(K.box("Slat", (0.012, ln, 0.025), at=(cx + out, cy + k, skirt_h / 2),
                                         rot=(d * math.pi / 4, 0, 0), m=lattice, col=col))
                k += 0.1
        skirt(-1.65, -DECK_D + 0.04, 1.6, True)
        skirt(1.65, -DECK_D + 0.04, 1.6, True)
        for sx in (-1, 1):
            skirt(sx * (DECK_W / 2 - 0.04), -DECK_D / 2, DECK_D - 0.1, False)
        # the step up in the middle, on two stringers
        obs.append(K.box("Step", (1.5, 0.34, 0.04), at=(0, -DECK_D - 0.18, 0.16), m=deck, bevel=0.008 if high else 0,
                         col=col))
        obs.append(K.box("Riser", (1.4, 0.03, 0.15), at=(0, -DECK_D - 0.02, 0.215), m=wood, col=col))
        for sx in (-0.68, 0.68):
            obs.append(K.box("Stringer", (0.05, 0.36, 0.16), at=(sx, -DECK_D - 0.18, 0.08), m=wood, col=col))
        # columns, with a plinth block each
        seg = 24 if high else 8
        for sx in (-COL_X, COL_X):
            c = K.lathe("Column", column_profile(), seg=seg, m=wood, col=col)
            c.location = (sx, COL_Y, 0)
            obs.append(c)
            if high:
                # brackets: a curl from the column out under the beam, each side
                for d in (-1, 1):
                    if sx * d > 0:
                        continue
                    bx = sx + d * 0.08
                    pts = [(bx, COL_Y, ROOF_LOW - 0.55), (bx + d * 0.05, COL_Y, ROOF_LOW - 0.35),
                           (bx + d * 0.22, COL_Y, ROOF_LOW - 0.22), (bx + d * 0.42, COL_Y, ROOF_LOW - 0.21)]
                    obs.append(K.wire("Bracket", pts, 0.018, wood, res=10, bevel_res=2, col=col))
                    obs.append(K.wire("Bracket", K.scroll(bx + d * 0.1, ROOF_LOW - 0.36, 0.07, 1.2, y=COL_Y,
                                                          flip=d, steps=18), 0.012, wood, res=8, bevel_res=2,
                                      col=col))
        # the beam along the front and the side beams back to the house, with a trim under them
        obs.append(K.box("Beam", (DECK_W + 0.2, 0.16, 0.2), at=(0, COL_Y, ROOF_LOW - 0.1), m=wood,
                         bevel=0.01 if high else 0, col=col))
        for sx in (-COL_X, COL_X):
            obs.append(K.box("Beam", (0.14, -COL_Y, 0.16), at=(sx, COL_Y / 2, ROOF_LOW - 0.08), m=wood,
                             bevel=0.01 if high else 0, col=col))
        if high:
            obs.append(K.box("Beam Trim", (DECK_W + 0.1, 0.18, 0.035), at=(0, COL_Y, ROOF_LOW - 0.21), m=wood,
                             bevel=0.008, col=col))
            # a row of little spindles hanging under the beam between the brackets (gingerbread)
            n = 30
            for i in range(n):
                x = -COL_X + 0.55 + i * (2 * COL_X - 1.1) / (n - 1)
                obs.append(K.lathe("Spindle", [(0.0, ROOF_LOW - 0.36), (0.008, ROOF_LOW - 0.355),
                                                (0.016, ROOF_LOW - 0.33), (0.009, ROOF_LOW - 0.29),
                                                (0.014, ROOF_LOW - 0.25), (0.0, ROOF_LOW - 0.23)],
                                   seg=8, m=wood, col=col, at=(x, COL_Y, 0)))
            obs.append(K.box("Spindle Rail", (2 * COL_X - 1.0, 0.03, 0.025), at=(0, COL_Y, ROOF_LOW - 0.37),
                             m=wood, col=col))
        # a lantern on the wall by the door
        lx, lz = 0.95, 1.95
        obs.append(K.box("Lantern Plate", (0.14, 0.02, 0.22), at=(lx, -0.012, lz), m=brass, bevel=0.005 if high else 0,
                         col=col))
        obs.append(K.box("Lantern Arm", (0.03, 0.12, 0.03), at=(lx, -0.07, lz + 0.05), m=brass, col=col))
        obs.append(K.cyl("Lantern Glass", 0.055, 0.17, at=(lx, -0.14, lz - 0.02), seg=6 if high else 6, m=glass,
                         col=col, smooth=False))
        obs.append(K.cyl("Lantern Top", 0.075, 0.06, r2=0.02, at=(lx, -0.14, lz + 0.09), seg=6, m=brass, col=col,
                         smooth=False))
        obs.append(K.cyl("Lantern Base", 0.065, 0.025, at=(lx, -0.14, lz - 0.115), seg=6, m=brass, col=col,
                         smooth=False))
        if high:
            for k in range(6):
                a = k / 6 * math.tau + math.pi / 6
                obs.append(K.box("Lantern Bar", (0.008, 0.008, 0.17),
                                 at=(lx + math.cos(a) * 0.056, -0.14 + math.sin(a) * 0.056, lz - 0.02), m=brass,
                                 col=col))
        return obs

    return build(HIGH, True), build(LOW, False)


ROOF_W = 5.6
ROOF_D = 2.35
ROOF_WALL = 3.3          # the roof's top edge, against the house wall
ROOF_EAVE = 2.98         # its low front edge


def porch_roof():
    shingle = K.mat("Porch Roof", (0.88, 0.87, 0.85), rough=0.85, pits=0.3, bump=0.25)
    gap = K.mat("Shingle Gap", (0.4, 0.4, 0.4), rough=0.95)
    ceiling = K.mat("Porch Ceiling", (0.95, 0.95, 0.94), rough=0.7, grain=(12.0, 0.05))

    def z_at(y):
        # the slope from the wall (y 0) down to the eave (y -ROOF_D)
        return ROOF_WALL + (ROOF_EAVE - ROOF_WALL) * (-y / ROOF_D)

    def slab(col, m, thick, inset=0.0, lift=0.0):
        outline = [(0.05, z_at(0.05) + lift), (-ROOF_D, z_at(-ROOF_D) + lift),
                   (-ROOF_D, z_at(-ROOF_D) + lift - thick), (0.05, z_at(0.05) + lift - thick)]
        return extrude_x("Roof", outline, -ROOF_W / 2 + inset, ROOF_W / 2 - inset, m, col)

    def build(col, high):
        obs = []
        # the roof board (its underside is the porch's ceiling, painted pale), with tar paper on top under the shingles
        obs.append(slab(col, ceiling, 0.12))
        if high:
            obs.append(slab(col, gap, 0.012, inset=0.01, lift=0.002))
            # rows of shingles from the eave up, each row overlapping the one below, tabs a little uneven
            slope = math.atan2(ROOF_WALL - ROOF_EAVE, ROOF_D)
            rows = 9
            depth = (ROOF_D + 0.05) / rows
            for r in range(rows):
                y = -ROOF_D + depth * (r + 0.5) + 0.04
                n = int(ROOF_W / 0.32)
                w = ROOF_W / n
                off = (w / 2) if r % 2 else 0.0
                for i in range(n + 1):
                    x = -ROOF_W / 2 + i * w - off + w / 2
                    if abs(x) > ROOF_W / 2 - w * 0.3:
                        continue
                    tw = min(w - 0.012, (ROOF_W / 2 - abs(x)) * 2 - 0.01)
                    s = K.box("Shingle", (tw, depth + 0.08, 0.018 + random.uniform(-0.003, 0.004)),
                              at=(x, y - 0.02, z_at(y - 0.02) + 0.015 + random.uniform(-0.003, 0.003)),
                              rot=(-slope + random.uniform(-0.03, 0.03), random.uniform(-0.015, 0.015),
                                   random.uniform(-0.02, 0.02)), m=shingle, bevel=0.003, col=col)
                    obs.append(s)
        return obs

    return build(HIGH, True), build(LOW, False)


BUILD = {"picket": (picket, 512), "fence_post": (fence_post, 256), "porch": (porch, 2048),
         "porch_roof": (porch_roof, 1024)}
fn, size = BUILD[KIND]
high, low = fn()
hi_tris = K.tri_count(high)
prop = K.join(NAME, low)
lo_tris = K.tri_count([prop])
K.uv_unwrap(prop, margin=0.006)
emit = KIND == "porch"
maps = K.bake(prop, high, size=size, name=NAME, extrusion=0.03 if KIND != "porch_roof" else 0.06,
              ray=0.08 if KIND != "porch_roof" else 0.12,
              maps=["normal", "ao", "color", "rough", "metal"] + (["emit"] if emit else []))
K.finish(prop, maps, size, NAME, emit_strength=1.5 if emit else 1.0)
print("TRIS high %d low %d" % (hi_tris, lo_tris))
K.export([prop], OUT, OUT.with_suffix(".blend") if K.has_flag("blend") else None)
if K.has_flag("preview"):
    K.export_high_preview(HIGH, OUT.with_name(OUT.stem + "_high_preview.glb"))

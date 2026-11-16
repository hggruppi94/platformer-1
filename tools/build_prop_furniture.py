# Furniture for the buildings' insides, built the detailed way (tools/bake_kit.py): each prop has a HIGH version with
# real tufting, piping, turned legs, carved scrolls and chrome, baked onto a LOW one of a few hundred to a couple of
# thousand triangles, which is what the game draws. Every copy of a prop shares one mesh and one material, so a diner
# full of booths costs the graphics card about what one does.
#
#   python tools/build_prop_furniture.py "Godot Project/my-world/models/props/furniture" <prop> [<prop> ...] [--preview]
#
# Props (sizes match what scripts/insides.gd and tools/build_interiors.gd expect; the front faces Godot's +Z, which is
# Blender's -Y):
#   diner_booth   a red vinyl booth with buttoned seat and back, chrome trim and a wood base: 1.6 wide, seat 0.46 up,
#                 back 1.15 high, 0.62 deep. Two back to back make a booth pair.
#   diner_stool   a chrome counter stool with a buttoned red top and a foot ring: 0.4 across, 0.76 high.
#   mayor_desk    the Void's Town Hall desk: lilac wood, gold scrolls on the front panels, turned fluted legs, a gold
#                 rim: 1.9 wide, 0.9 deep, 0.8 high (the Void's palette, so the builder doesn't tint it).
#   bookshelf     a wooden bookcase full of books (each its own spine, leaning, some lying flat): 1.2 wide, 0.36 deep,
#                 2.0 high. Bookshops, the school, the inn, houses.
#   armchair      a buttoned armchair with rolled arms and turned legs: 0.9 wide, 0.85 deep, seat 0.45, back 1.0.
#   school_desk   a school desk with its chair behind it (the child faces the front, the desk's -Y / Godot's +Z):
#                 0.7 wide, desk 0.72 high, 1.05 deep with the chair.

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake_kit as K  # noqa: E402

ARGS = [a for a in sys.argv[sys.argv.index("--") + 1 if "--" in sys.argv else 1:] if not a.startswith("--")]
OUT_DIR = Path(ARGS[0] if ARGS else "furniture").resolve()
WANT = ARGS[1:] or ["diner_booth", "diner_stool", "mayor_desk"]


def _ring(cx, cy, z, r, n=24):
    return [(cx + math.cos(k / n * math.tau) * r, cy + math.sin(k / n * math.tau) * r, z) for k in range(n)]


# ---------------------------------------------------------------- the diner booth
def diner_booth():
    K.reset()
    high_c = K.new_collection("High")
    low_c = K.new_collection("Low")
    vinyl = K.mat("Booth Vinyl", (0.78, 0.12, 0.14), rough=0.35, bump=0.08, wear=0.06)
    seam = K.mat("Booth Seam", (0.42, 0.05, 0.07), rough=0.5)
    chrome = K.mat("Booth Chrome", (0.86, 0.87, 0.9), rough=0.12, metal=1.0, pits=0.05)
    wood = K.mat("Booth Wood", (0.42, 0.26, 0.15), rough=0.6, grain=(14.0, 0.3), wear=0.05)
    button = K.mat("Booth Button", (0.6, 0.08, 0.1), rough=0.3)
    W, D_, SEAT, TOP = 1.6, 0.62, 0.46, 1.15
    high = []
    # The wood plinth and the seat cushion (two rolls of padding with a seam between) and the back (three rolls)
    high.append(K.box("Plinth", (W, D_ - 0.06, SEAT - 0.14), at=(0, 0.03, (SEAT - 0.14) / 2), m=wood, bevel=0.01,
                      col=high_c))
    for k, y in enumerate((-0.17, 0.05)):
        high.append(K.box("Seat Roll", (W - 0.04, 0.24, 0.14), at=(0, y, SEAT - 0.07), m=vinyl, bevel=0.05, seg=4,
                          col=high_c))
    high.append(K.box("Seat Seam", (W - 0.06, 0.012, 0.1), at=(0, -0.055, SEAT - 0.07), m=seam, col=high_c))
    for k in range(3):
        z = SEAT + 0.08 + k * 0.2
        high.append(K.box("Back Roll", (W - 0.04, 0.16, 0.2), at=(0, 0.21, z + 0.1), m=vinyl, bevel=0.06, seg=4,
                          rot=(math.radians(-8), 0, 0), col=high_c))
    # Buttons (tufting) on the back rolls, little dimples round each
    for k in range(3):
        z = SEAT + 0.18 + k * 0.2
        for i in range(7):
            x = -W / 2 + 0.14 + i * (W - 0.28) / 6
            high.append(K.sphere("Button", 0.016, at=(x, 0.125 + k * 0.03, z + 0.02), m=button, seg=10,
                                 scale=(1, 0.6, 1), col=high_c))
    # Chrome edging along the top of the back and the front of the seat, chrome feet
    high.append(K.wire("Top Trim", [(-W / 2, 0.27, TOP), (0, 0.27, TOP + 0.005), (W / 2, 0.27, TOP)], 0.018, chrome,
                       res=6, col=high_c))
    high.append(K.wire("Seat Trim", [(-W / 2, -0.3, SEAT - 0.15), (0, -0.3, SEAT - 0.15), (W / 2, -0.3, SEAT - 0.15)],
                       0.012, chrome, res=6, col=high_c))
    for sx in (-1, 1):
        high.append(K.box("Side", (0.04, D_, TOP - 0.02), at=(sx * (W / 2 - 0.02), 0.0, (TOP - 0.02) / 2), m=wood,
                          bevel=0.012, col=high_c))
        high.append(K.wire("Side Trim", [(sx * W / 2, -0.3, 0.02), (sx * W / 2, -0.3, SEAT - 0.15),
                                         (sx * W / 2, 0.0, SEAT + 0.1), (sx * W / 2, 0.28, TOP)], 0.012, chrome,
                           res=8, col=high_c))
    # (the low copy follows the rolls one by one, so every ray finds the vinyl it's looking for: one box over all three
    # left black gaps between them)
    low = [K.box("Plinth", (W, D_ - 0.06, SEAT - 0.14), at=(0, 0.03, (SEAT - 0.14) / 2), col=low_c)]
    for y in (-0.17, 0.05):
        low.append(K.box("Seat Roll", (W - 0.03, 0.25, 0.15), at=(0, y, SEAT - 0.07), col=low_c))
    for k in range(3):
        low.append(K.box("Back Roll", (W - 0.03, 0.17, 0.21), at=(0, 0.21, SEAT + 0.18 + k * 0.2),
                         rot=(math.radians(-8), 0, 0), col=low_c))
    low.append(K.box("Back Board", (W - 0.04, 0.03, TOP - SEAT), at=(0, 0.3, (TOP + SEAT) / 2), col=low_c))
    for sx in (-1, 1):
        low.append(K.box("Side", (0.045, D_, TOP - 0.02), at=(sx * (W / 2 - 0.02), 0.0, (TOP - 0.02) / 2), col=low_c))
    return high, low, 0.02, 0.06


# ---------------------------------------------------------------- the counter stool
def diner_stool():
    K.reset()
    high_c = K.new_collection("High")
    low_c = K.new_collection("Low")
    vinyl = K.mat("Stool Vinyl", (0.78, 0.12, 0.14), rough=0.35, bump=0.08)
    chrome = K.mat("Stool Chrome", (0.86, 0.87, 0.9), rough=0.12, metal=1.0, pits=0.04)
    button = K.mat("Stool Button", (0.6, 0.08, 0.1), rough=0.3)
    H = 0.76
    high = [
        K.lathe("Foot", [(0.0, 0.0), (0.2, 0.0), (0.2, 0.015), (0.17, 0.03), (0.06, 0.06), (0.04, 0.09), (0.0, 0.09)],
                48, chrome, col=high_c),
        K.cyl("Pole", 0.032, H - 0.15, at=(0, 0, 0.09 + (H - 0.15) / 2 - 0.02), seg=24, m=chrome, col=high_c),
        K.wire("Foot Ring", _ring(0, 0, 0.3, 0.16), 0.012, chrome, closed=True, res=6, col=high_c),
        K.lathe("Seat Pan", [(0.0, H - 0.1), (0.05, H - 0.1), (0.19, H - 0.085), (0.2, H - 0.07), (0.0, H - 0.07)],
                48, chrome, col=high_c),
        K.lathe("Cushion", [(0.0, H - 0.075), (0.195, H - 0.075), (0.205, H - 0.05), (0.2, H - 0.02),
                            (0.17, H - 0.004), (0.08, H + 0.004), (0.0, H + 0.004)], 48, vinyl, col=high_c),
        K.wire("Piping", _ring(0, 0, H - 0.045, 0.206, 32), 0.006, chrome, closed=True, res=4, col=high_c),
        K.sphere("Button", 0.018, at=(0, 0, H + 0.002), m=button, seg=12, scale=(1, 1, 0.5), col=high_c),
    ]
    for k in range(4):                                    # the ring's struts to the pole
        a = k / 4 * math.tau
        high.append(K.wire("Strut", [(math.cos(a) * 0.03, math.sin(a) * 0.03, 0.34), (math.cos(a) * 0.09,
                                     math.sin(a) * 0.09, 0.32), (math.cos(a) * 0.16, math.sin(a) * 0.16, 0.3)],
                           0.007, chrome, res=4, col=high_c))
    low = [
        K.lathe("Foot", [(0.0, 0.0), (0.205, 0.0), (0.2, 0.025), (0.06, 0.06), (0.04, 0.09), (0.0, 0.09)], 12, col=low_c),
        K.cyl("Pole", 0.035, H - 0.15, at=(0, 0, 0.09 + (H - 0.15) / 2 - 0.02), seg=8, col=low_c),
        K.lathe("Ring", [(0.145, 0.288), (0.175, 0.288), (0.175, 0.312), (0.145, 0.312), (0.145, 0.288)], 12,
                col=low_c),
        K.lathe("Seat", [(0.0, H - 0.1), (0.2, H - 0.09), (0.21, H - 0.05), (0.18, H - 0.002), (0.0, H + 0.006)], 16,
                col=low_c),
    ]
    return high, low, 0.015, 0.05


# ---------------------------------------------------------------- the Void's Town Hall desk
def mayor_desk():
    K.reset()
    high_c = K.new_collection("High")
    low_c = K.new_collection("Low")
    wood = K.mat("Desk Lilac Wood", (0.62, 0.48, 0.78), rough=0.5, grain=(10.0, 0.25), wear=0.08, bump=0.04)
    dark = K.mat("Desk Panel", (0.46, 0.33, 0.62), rough=0.55, grain=(16.0, 0.2))
    gold = K.mat("Desk Gold", (0.98, 0.78, 0.3), rough=0.25, metal=1.0, pits=0.06)
    leather = K.mat("Desk Leather", (0.2, 0.55, 0.55), rough=0.6, bump=0.15)
    W, D_, H = 1.9, 0.9, 0.8
    high = [
        K.box("Top", (W, D_, 0.06), at=(0, 0, H - 0.03), m=wood, bevel=0.02, seg=3, col=high_c),
        K.box("Blotter", (0.9, 0.5, 0.008), at=(0, 0.05, H + 0.004), m=leather, bevel=0.004, col=high_c),
        K.box("Pedestal L", (0.5, D_ - 0.1, H - 0.06), at=(-W / 2 + 0.3, 0, (H - 0.06) / 2), m=wood, bevel=0.015,
              col=high_c),
        K.box("Pedestal R", (0.5, D_ - 0.1, H - 0.06), at=(W / 2 - 0.3, 0, (H - 0.06) / 2), m=wood, bevel=0.015,
              col=high_c),
        K.box("Modesty", (W - 1.1, 0.04, H - 0.25), at=(0, 0.3, H - 0.06 - (H - 0.25) / 2), m=dark, bevel=0.01,
              col=high_c),
    ]
    # The gold rim round the top
    rim = [(-W / 2 - 0.005, -D_ / 2 - 0.005), (W / 2 + 0.005, -D_ / 2 - 0.005), (W / 2 + 0.005, D_ / 2 + 0.005),
           (-W / 2 - 0.005, D_ / 2 + 0.005)]
    for i in range(4):
        a, b = rim[i], rim[(i + 1) % 4]
        high.append(K.wire("Rim", [(a[0], a[1], H - 0.045), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, H - 0.045),
                                   (b[0], b[1], H - 0.045)], 0.008, gold, res=4, col=high_c))
    # Drawers on each pedestal: sunken panels with gold scrolls and round gold pulls
    for sx in (-1, 1):
        cx = sx * (W / 2 - 0.3)
        for k in range(3):
            z = 0.14 + k * 0.22
            high.append(K.box("Drawer", (0.42, 0.02, 0.18), at=(cx, -D_ / 2 + 0.045, z), m=dark, bevel=0.006,
                              col=high_c))
            high.append(K.sphere("Pull", 0.018, at=(cx, -D_ / 2 + 0.025, z), m=gold, seg=12, col=high_c))
            for f in (-1, 1):
                pts = [(cx + px * f, -D_ / 2 + 0.03, pz) for (px, _, pz) in K.scroll(0.1, z, 0.05, 1.1, steps=16)]
                high.append(K.wire("Scroll", pts, 0.004, gold, res=10, bevel_res=2, col=high_c))
    # Turned, fluted feet under each corner
    for sx in (-1, 1):
        for sy in (-1, 1):
            high.append(K.lathe("Foot", [(0.0, 0.0), (0.035, 0.0), (0.045, 0.02), (0.03, 0.05), (0.04, 0.07),
                                         (0.0, 0.07)], 24, gold, at=(sx * (W / 2 - 0.07), sy * (D_ / 2 - 0.07), -0.06),
                                col=high_c))
    # A gold inkwell and a little crystal on the top
    high.append(K.lathe("Inkwell", [(0.0, 0.0), (0.04, 0.0), (0.045, 0.03), (0.02, 0.05), (0.025, 0.06), (0.0, 0.06)],
                        24, gold, at=(0.65, -0.1, H), col=high_c))
    low = [
        K.box("Top", (W, D_, 0.06), at=(0, 0, H - 0.03), col=low_c),
        K.box("Pedestal L", (0.5, D_ - 0.08, H - 0.06), at=(-W / 2 + 0.3, 0, (H - 0.06) / 2), col=low_c),
        K.box("Pedestal R", (0.5, D_ - 0.08, H - 0.06), at=(W / 2 - 0.3, 0, (H - 0.06) / 2), col=low_c),
        K.box("Modesty", (W - 1.1, 0.05, H - 0.25), at=(0, 0.3, H - 0.06 - (H - 0.25) / 2), col=low_c),
        K.cyl("Inkwell", 0.045, 0.06, at=(0.65, -0.1, H + 0.03), seg=8, col=low_c),
    ]
    return high, low, 0.015, 0.05


# ---------------------------------------------------------------- the bookcase
def bookshelf():
    K.reset()
    high_c = K.new_collection("High")
    low_c = K.new_collection("Low")
    wood = K.mat("Shelf Wood", (0.45, 0.29, 0.17), rough=0.6, grain=(12.0, 0.3), wear=0.05)
    back = K.mat("Shelf Back", (0.33, 0.21, 0.13), rough=0.7, grain=(20.0, 0.2))
    covers = [K.mat("Book %d" % k, c, rough=0.55, bump=0.05) for k, c in enumerate([
        (0.62, 0.16, 0.16), (0.16, 0.32, 0.55), (0.2, 0.45, 0.28), (0.85, 0.65, 0.2), (0.45, 0.22, 0.5),
        (0.9, 0.85, 0.72), (0.12, 0.12, 0.14), (0.85, 0.42, 0.18)])]
    gilt = K.mat("Book Gilt", (0.95, 0.78, 0.35), rough=0.3, metal=1.0)
    W, D_, H = 1.2, 0.36, 2.0
    rows = [0.1, 0.56, 1.02, 1.48]
    high = [K.box("Back", (W - 0.04, 0.02, H - 0.04), at=(0, D_ / 2 - 0.015, H / 2), m=back, col=high_c),
            K.box("Top", (W + 0.04, D_ + 0.02, 0.05), at=(0, 0, H - 0.025), m=wood, bevel=0.012, seg=3, col=high_c),
            K.box("Plinth", (W, D_, 0.1), at=(0, 0, 0.05), m=wood, bevel=0.008, col=high_c)]
    for sx in (-1, 1):
        high.append(K.box("Side", (0.04, D_, H - 0.05), at=(sx * (W / 2 - 0.02), 0, (H - 0.05) / 2), m=wood,
                          bevel=0.008, col=high_c))
    for z in rows[1:]:
        high.append(K.box("Shelf", (W - 0.08, D_ - 0.02, 0.03), at=(0, 0, z - 0.015), m=wood, bevel=0.005, col=high_c))
    rnd = random.Random(7)
    for z in rows:
        x = -W / 2 + 0.05
        while x < W / 2 - 0.1:
            if rnd.random() < 0.08:                       # a little stack lying flat now and then
                for k in range(rnd.randint(2, 4)):
                    high.append(K.box("Flat Book", (0.2, 0.22, 0.04), at=(x + 0.1, 0.02, z + 0.02 + k * 0.042),
                                      m=rnd.choice(covers), bevel=0.004, col=high_c))
                x += 0.24
                continue
            w = rnd.uniform(0.025, 0.055)
            h = rnd.uniform(0.24, 0.36)
            d = rnd.uniform(0.2, 0.25)
            lean = rnd.uniform(-0.06, 0.06) if rnd.random() < 0.15 else 0.0
            m = rnd.choice(covers)
            high.append(K.box("Book", (w, d, h), at=(x + w / 2, D_ / 2 - 0.03 - d / 2, z + h / 2), m=m, bevel=0.003,
                              rot=(0, lean, 0), col=high_c))
            if rnd.random() < 0.5:                        # gold bands on the spine
                for bz in (0.25, 0.8):
                    high.append(K.box("Band", (w + 0.002, 0.004, 0.008), at=(x + w / 2, D_ / 2 - 0.03 - d - 0.001,
                                      z + h * bz), m=gilt, col=high_c))
            x += w + 0.003
    low = [K.box("Back", (W - 0.04, 0.03, H - 0.04), at=(0, D_ / 2 - 0.015, H / 2), col=low_c),
           K.box("Top", (W + 0.04, D_ + 0.02, 0.05), at=(0, 0, H - 0.025), col=low_c),
           K.box("Plinth", (W, D_, 0.1), at=(0, 0, 0.05), col=low_c)]
    for sx in (-1, 1):
        low.append(K.box("Side", (0.045, D_, H - 0.05), at=(sx * (W / 2 - 0.02), 0, (H - 0.05) / 2), col=low_c))
    for z in rows[1:]:
        low.append(K.box("Shelf", (W - 0.08, D_ - 0.02, 0.035), at=(0, 0, z - 0.015), col=low_c))
    for z in rows:                                        # one block of books per shelf, as deep as the deepest
        low.append(K.box("Books", (W - 0.09, 0.25, 0.36), at=(0, D_ / 2 - 0.03 - 0.125, z + 0.18), col=low_c))
    return high, low, 0.02, 0.3


# ---------------------------------------------------------------- the armchair
def armchair():
    K.reset()
    high_c = K.new_collection("High")
    low_c = K.new_collection("Low")
    cloth = K.mat("Chair Velvet", (0.55, 0.22, 0.2), rough=0.85, bump=0.12)
    piping = K.mat("Chair Piping", (0.4, 0.14, 0.12), rough=0.7)
    wood = K.mat("Chair Wood", (0.36, 0.22, 0.13), rough=0.5, grain=(14.0, 0.3))
    button = K.mat("Chair Button", (0.35, 0.12, 0.1), rough=0.6)
    W, D_, SEAT, TOP = 0.9, 0.85, 0.45, 1.0
    high = [K.box("Base", (W - 0.04, D_ - 0.08, 0.22), at=(0, 0.02, 0.27), m=cloth, bevel=0.04, seg=3, col=high_c),
            K.box("Cushion", (W - 0.3, D_ - 0.28, 0.12), at=(0, -0.06, SEAT - 0.04), m=cloth, bevel=0.05, seg=4,
                  col=high_c),
            K.box("Back", (W - 0.26, 0.2, TOP - SEAT + 0.08), at=(0, D_ / 2 - 0.13, (TOP + SEAT) / 2), m=cloth,
                  bevel=0.07, seg=4, rot=(math.radians(-10), 0, 0), col=high_c)]
    for sx in (-1, 1):
        high.append(K.box("Arm", (0.15, D_ - 0.1, 0.32), at=(sx * (W / 2 - 0.08), 0.0, 0.5), m=cloth, bevel=0.06, seg=4,
                          col=high_c))
        high.append(K.cyl("Arm Roll", 0.09, D_ - 0.1, at=(sx * (W / 2 - 0.08), 0.0, 0.66), seg=24, m=cloth,
                          rot=(math.pi / 2, 0, 0), col=high_c))
        high.append(K.wire("Piping", [(sx * (W / 2 - 0.08), -D_ / 2 + 0.04, 0.75),
                                      (sx * (W / 2 - 0.08), D_ / 2 - 0.06, 0.75)], 0.008, piping, res=4, col=high_c))
        for sy in (-1, 1):
            high.append(K.lathe("Leg", [(0.0, 0.0), (0.022, 0.0), (0.03, 0.04), (0.022, 0.09), (0.03, 0.14),
                                        (0.0, 0.16)], 16, wood, at=(sx * (W / 2 - 0.08), sy * (D_ / 2 - 0.08), 0.0),
                                col=high_c))
    for i in range(3):
        for k in range(2):
            z = SEAT + 0.2 + k * 0.22
            high.append(K.sphere("Button", 0.014, at=(-0.18 + i * 0.18, D_ / 2 - 0.25 - k * 0.04, z), m=button,
                                 seg=8, scale=(1, 0.6, 1), col=high_c))
    low = [K.box("Base", (W - 0.03, D_ - 0.07, 0.23), at=(0, 0.02, 0.27), col=low_c),
           K.box("Cushion", (W - 0.29, D_ - 0.27, 0.13), at=(0, -0.06, SEAT - 0.04), col=low_c),
           K.box("Back", (W - 0.25, 0.21, TOP - SEAT + 0.09), at=(0, D_ / 2 - 0.13, (TOP + SEAT) / 2),
                 rot=(math.radians(-10), 0, 0), col=low_c)]
    for sx in (-1, 1):
        low.append(K.box("Arm", (0.16, D_ - 0.09, 0.33), at=(sx * (W / 2 - 0.08), 0.0, 0.5), col=low_c))
        low.append(K.cyl("Arm Roll", 0.095, D_ - 0.09, at=(sx * (W / 2 - 0.08), 0.0, 0.66), seg=8,
                         rot=(math.pi / 2, 0, 0), col=low_c))
        for sy in (-1, 1):
            low.append(K.cyl("Leg", 0.03, 0.16, at=(sx * (W / 2 - 0.08), sy * (D_ / 2 - 0.08), 0.08), seg=6, col=low_c))
    return high, low, 0.02, 0.08


# ---------------------------------------------------------------- the school desk and chair
def school_desk():
    K.reset()
    high_c = K.new_collection("High")
    low_c = K.new_collection("Low")
    top_m = K.mat("Desk Top", (0.72, 0.55, 0.36), rough=0.45, grain=(10.0, 0.3), wear=0.1)
    metal = K.mat("Desk Metal", (0.2, 0.42, 0.55), rough=0.35, metal=0.8, pits=0.05)
    seat_m = K.mat("Chair Seat", (0.85, 0.4, 0.18), rough=0.5, bump=0.03)
    pencil = K.mat("Pencil", (0.98, 0.8, 0.15), rough=0.5)
    W, DD, TOP = 0.7, 0.5, 0.72
    cy = 0.5                                              # the chair, behind the desk (+Y, Godot's -Z)
    high = [K.box("Desk Top", (W, DD, 0.035), at=(0, 0, TOP), m=top_m, bevel=0.008, seg=2, col=high_c),
            K.box("Book Tray", (W - 0.06, DD - 0.08, 0.1), at=(0, 0.02, TOP - 0.1), m=metal, bevel=0.005, col=high_c),
            K.cyl("Pencil", 0.006, 0.17, at=(0.15, -0.12, TOP + 0.024), seg=6, m=pencil, rot=(0, math.pi / 2, 0.3),
                  col=high_c),
            K.box("Seat", (0.4, 0.38, 0.03), at=(0, cy, 0.42), m=seat_m, bevel=0.012, seg=3, col=high_c),
            K.box("Chair Back", (0.38, 0.03, 0.22), at=(0, cy + 0.19, 0.66), m=seat_m, bevel=0.012, seg=3,
                  rot=(math.radians(-8), 0, 0), col=high_c)]
    for sx in (-1, 1):
        high.append(K.wire("Desk Leg", [(sx * (W / 2 - 0.05), -DD / 2 + 0.05, 0.0), (sx * (W / 2 - 0.05), -DD / 2 + 0.05,
                                        TOP), (sx * (W / 2 - 0.05), DD / 2 - 0.05, TOP),
                                        (sx * (W / 2 - 0.05), DD / 2 - 0.05, 0.0)], 0.014, metal, res=2, col=high_c))
        high.append(K.wire("Chair Leg", [(sx * 0.17, cy - 0.16, 0.0), (sx * 0.17, cy - 0.16, 0.41),
                                         (sx * 0.17, cy + 0.17, 0.41), (sx * 0.17, cy + 0.19, 0.78)], 0.011, metal,
                           res=3, col=high_c))
        high.append(K.wire("Chair Leg", [(sx * 0.17, cy + 0.17, 0.0), (sx * 0.17, cy + 0.17, 0.41)], 0.011, metal,
                           res=2, col=high_c))
    low = [K.box("Desk Top", (W + 0.01, DD + 0.01, 0.04), at=(0, 0, TOP), col=low_c),
           K.box("Book Tray", (W - 0.05, DD - 0.07, 0.11), at=(0, 0.02, TOP - 0.1), col=low_c),
           K.box("Seat", (0.41, 0.39, 0.04), at=(0, cy, 0.42), col=low_c),
           K.box("Chair Back", (0.39, 0.04, 0.23), at=(0, cy + 0.19, 0.66), rot=(math.radians(-8), 0, 0), col=low_c)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            low.append(K.cyl("Desk Leg", 0.018, TOP, at=(sx * (W / 2 - 0.05), sy * (DD / 2 - 0.05), TOP / 2), seg=6,
                             col=low_c))
            low.append(K.cyl("Chair Leg", 0.015, 0.41, at=(sx * 0.17, cy + sy * 0.165, 0.205), seg=6, col=low_c))
    return high, low, 0.015, 0.06


PROPS = {"diner_booth": diner_booth, "diner_stool": diner_stool, "mayor_desk": mayor_desk, "bookshelf": bookshelf,
         "armchair": armchair, "school_desk": school_desk}

for name in WANT:
    high, low, extrusion, ray = PROPS[name]()
    hi_tris = K.tri_count(high)
    ob = K.join(name, low)
    ob.data.materials.clear()                 # the low pieces have no materials: one plain one to bake into
    ob.data.materials.append(K.D.materials.new(name + " Low"))
    ob.data.materials[0].use_nodes = True
    lo_tris = K.tri_count([ob])
    K.uv_unwrap(ob, margin=0.006)
    maps = K.bake(ob, high, size=1024, name=name, extrusion=extrusion, ray=ray,
                  maps=["normal", "ao", "color", "rough", "metal"])
    K.finish(ob, maps, 1024, name)
    print("TRIS %s high %d low %d" % (name, hi_tris, lo_tris))
    out = OUT_DIR / (name + ".glb")
    K.export([ob], out, out.with_suffix(".blend") if K.has_flag("blend") else None)
    if K.has_flag("preview"):
        K.export_high_preview(K.D.collections["High"], out.with_name(name + "_high_preview.glb"))

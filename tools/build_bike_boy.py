# Builds the bike boy (working name: Dash) and his red "07" bike from scratch: models, materials, rigs,
# weights and animations. Reference: the group picture of Sofi's characters (star cap, sunglasses,
# navy hoodie, khaki shorts, brown backpack, red bike with a number plate).
#
#   blender -b --python tools\build_bike_boy.py
#
# Writes two files (overwrites them):
#   source_art/props/bike.blend             the bike, with a "ride" action (wheels and pedals turning)
#   source_art/characters/bike_boy.blend    the boy, with idle / walk / run / ride actions
# Both share an origin: put the bike and the boy at the same spot in Godot and play "ride" on both,
# and his hands and feet line up with the handlebar and pedals.
#
# Units are meters; feet (and wheels) on the ground at the origin; faces -Y. Helpers: tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT_BIKE = ROOT / "source_art" / "props" / "bike.blend"
OUT_BOY = ROOT / "source_art" / "characters" / "bike_boy.blend"

# =============================================================================
# Bike layout (shared by both models)
# =============================================================================
WHEEL_R, TIRE_R = 0.25, 0.028
REAR, FRONT = Vector((0, 0.40, WHEEL_R)), Vector((0, -0.42, WHEEL_R))
BB = Vector((0, 0.02, 0.27))                 # bottom bracket (crank axle)
CRANK, PEDAL_X = 0.10, 0.11
SEAT_CLUSTER = Vector((0, 0.14, 0.46))
SEAT = Vector((0, 0.16, 0.505))
HEAD_TOP, HEAD_BOT = Vector((0, -0.30, 0.56)), Vector((0, -0.33, 0.45))
STEM_TOP = Vector((0, -0.27, 0.72))
GRIP = {"L": Vector((0.24, -0.20, 0.78)), "R": Vector((-0.24, -0.20, 0.78))}
RIDE_FRAMES = 30
WHEEL_TURNS = 2                              # per loop of the ride action (crank turns once)


def pedal_pos(side, t):
    """Where each pedal is at time t of the ride loop (left starts at the bottom)."""
    a = 2 * math.pi * t
    s = 1 if side == "L" else -1
    return BB + Vector((PEDAL_X * s, CRANK * math.sin(a) * s, -CRANK * math.cos(a) * s))


# =============================================================================
# The bike
# =============================================================================
K.begin()
mat("Frame", (0.75, 0.035, 0.025), rough=0.3, metal=0.2)
mat("Tire", (0.02, 0.02, 0.022), rough=0.8)
mat("Rim", (0.55, 0.56, 0.58), rough=0.25, metal=0.9)
mat("Black", (0.015, 0.015, 0.017), rough=0.5)
mat("Seat", (0.03, 0.03, 0.035), rough=0.6)
mat("Plate", (0.03, 0.06, 0.25), rough=0.4)
mat("Plate Number", (0.92, 0.92, 0.92), rough=0.4)

FB = ["frame"]
for nm, a, b in (("Down Tube", BB, HEAD_BOT), ("Top Tube", SEAT_CLUSTER, HEAD_TOP), ("Seat Tube", BB, SEAT_CLUSTER),
                 ("Head Tube", HEAD_BOT, HEAD_TOP)):
    capsule(nm, [a, b], 0.019 if nm != "Head Tube" else 0.024, 0.019 if nm != "Head Tube" else 0.024, "Frame", FB,
            sides=14)
for sx in (1, -1):
    hub = REAR + Vector((0.045 * sx, 0, 0))
    capsule(f"Chain Stay.{sx}", [BB + Vector((0.03 * sx, 0, 0)), hub], 0.012, 0.011, "Frame", FB, sides=10)
    capsule(f"Seat Stay.{sx}", [SEAT_CLUSTER + Vector((0.02 * sx, 0.01, 0)), hub], 0.011, 0.01, "Frame", FB, sides=10)
    capsule(f"Fork.{sx}", [HEAD_BOT + Vector((0.035 * sx, 0, 0.01)), FRONT + Vector((0.045 * sx, 0, 0))], 0.014, 0.012,
            "Frame", ["fork"], sides=10)
capsule("Seat Post", [SEAT_CLUSTER, SEAT - Vector((0, 0, 0.01))], 0.013, 0.013, "Rim", FB, sides=10)
ellipsoid("Seat", SEAT + Vector((0, 0.01, 0.0)), (0.075, 0.13, 0.03), "Seat", FB, power=0.7)
capsule("Stem", [HEAD_TOP, STEM_TOP], 0.016, 0.016, "Rim", ["fork"], sides=10)
bar = [GRIP["R"], Vector((-0.12, -0.25, 0.75)), STEM_TOP + Vector((0, 0, 0.01)), Vector((0.12, -0.25, 0.75)), GRIP["L"]]
bar_pts = smooth_path(bar, 5)
tube("Handlebar", bar_pts, [(0.012, 0.012)] * len(bar_pts), "Rim", ["fork"], sides=10)
for side, g in GRIP.items():
    d = (bar[-1] - bar[-2]).normalized() if side == "L" else (bar[0] - bar[1]).normalized()
    capsule(f"Grip.{side}", [g - d * 0.07, g + d * 0.01], 0.019, 0.019, "Black", ["fork"], sides=12)
# Number plate on the front of the handlebar
plate_c = Vector((0, -0.315, 0.765))
plate_n = Vector((0, -1, 0.15)).normalized()
ellipsoid("Number Plate", plate_c, (0.095, 0.006, 0.07), "Plate", ["fork"], rot=basis_facing(plate_n), power=0.35)
text_mesh("Number", "07", plate_c + plate_n * 0.007, 0.095, plate_n, 0.004, "Plate Number", ["fork"])

# Wheels: tire, rim, hub and spokes
for nm, c, bone in (("Front", FRONT, "wheel.F"), ("Rear", REAR, "wheel.B")):
    ry = Euler((0, math.radians(90), 0)).to_matrix()                   # ring in the YZ plane
    torus(f"{nm} Tire", c, WHEEL_R - TIRE_R, TIRE_R, "Tire", [bone], u=48, v=12, rot=ry)
    torus(f"{nm} Rim", c, WHEEL_R - TIRE_R * 2.1, 0.009, "Rim", [bone], u=48, v=8, rot=ry)
    capsule(f"{nm} Hub", [c - Vector((0.045, 0, 0)), c + Vector((0.045, 0, 0))], 0.018, 0.018, "Rim", [bone], sides=12)
    for k in range(16):
        a = 2 * math.pi * k / 16
        sx = 1 if k % 2 else -1
        rim_p = c + Vector((0, math.cos(a), math.sin(a))) * (WHEEL_R - TIRE_R * 2.2)
        cylinder(f"{nm} Spoke.{k}", c + Vector((0.035 * sx, 0, 0)), rim_p, 0.0028, "Rim", [bone], sides=5)

# Drive: chainring, rear cog, chain loop, cranks and pedals
ry = Euler((0, math.radians(90), 0)).to_matrix()
ellipsoid("Chainring", BB + Vector((-0.04, 0, 0)), (0.07, 0.07, 0.006), "Rim", ["crank"], rot=ry, power=0.9, u=32)
ellipsoid("Cog", REAR + Vector((-0.05, 0, 0)), (0.035, 0.035, 0.006), "Rim", ["wheel.B"], rot=ry, u=24)
chain = []
for k in range(21):                                                  # top run, bottom run and the two wraps
    t = k / 20
    chain.append(Vector((-0.045, BB.y + (REAR.y - BB.y) * t, BB.z + 0.072 + (REAR.z + 0.038 - BB.z - 0.072) * t)))
for k in range(1, 12):
    a = math.pi / 2 - math.pi * k / 11
    chain.append(Vector((-0.045, REAR.y + 0.038 * math.cos(a), REAR.z + 0.038 * math.sin(a))))
for k in range(1, 21):
    t = k / 20
    chain.append(Vector((-0.045, REAR.y + (BB.y - REAR.y) * t, REAR.z - 0.038 + (BB.z - 0.072 - REAR.z + 0.038) * t)))
for k in range(1, 12):
    a = -math.pi / 2 - math.pi * k / 11
    chain.append(Vector((-0.045, BB.y + 0.072 * math.cos(a), BB.z + 0.072 * math.sin(a))))
tube("Chain", chain, [(0.004, 0.004)] * len(chain), "Black", FB, sides=6, caps=False)
for side in ("L", "R"):
    s = 1 if side == "L" else -1
    p0 = pedal_pos(side, 0)
    capsule(f"Crank Arm.{side}", [BB + Vector((0.06 * s, 0, 0)), p0 - Vector((0.02 * s, 0, 0))], 0.011, 0.011, "Rim",
            ["crank"], sides=8)
    ellipsoid(f"Pedal.{side}", p0 + Vector((0.03 * s, 0, 0)), (0.045, 0.04, 0.012), "Black", [f"pedal.{side}"],
              power=0.4, u=16, v=8)

BIKE_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "frame": (tuple(BB), tuple(HEAD_TOP), "root"),
    "fork": (tuple(HEAD_BOT), tuple(HEAD_TOP), "frame"),
    "wheel.F": (tuple(FRONT), tuple(FRONT + Vector((0, 0, 0.15))), "fork"),
    "wheel.B": (tuple(REAR), tuple(REAR + Vector((0, 0, 0.15))), "frame"),
    "crank": (tuple(BB), tuple(BB + Vector((0, 0, 0.1))), "frame"),
    "pedal.L": (tuple(pedal_pos("L", 0)), tuple(pedal_pos("L", 0) + Vector((0, -0.06, 0))), "crank"),
    "pedal.R": (tuple(pedal_pos("R", 0)), tuple(pedal_pos("R", 0) + Vector((0, -0.06, 0))), "crank"),
}
bike_rig = build_rig("BikeRig", BIKE_BONES)
skin_and_join(bike_rig, BIKE_BONES, "Bike", "Down Tube")
STEER_AXIS = (HEAD_TOP - HEAD_BOT).normalized()


def bike_ride(t):
    p = Pose(BIKE_BONES)
    p.rel("fork", (STEER_AXIS, 0.03 * math.sin(2 * math.pi * t)))
    p.rel("wheel.F", (X, 2 * math.pi * WHEEL_TURNS * t))
    p.rel("wheel.B", (X, 2 * math.pi * WHEEL_TURNS * t))
    p.rel("crank", (X, 2 * math.pi * t))
    for side in ("L", "R"):
        p.set_abs(f"pedal.{side}", Matrix.Identity(3))             # pedals stay level
    return p


make_action(bike_rig, "idle", 1, lambda t: Pose(BIKE_BONES))
make_action(bike_rig, "ride", RIDE_FRAMES, bike_ride)
rest_pose(bike_rig)
finish(OUT_BIKE, frame_end=RIDE_FRAMES)

# =============================================================================
# The boy
# =============================================================================
K.begin()
mat("Skin", (0.86, 0.50, 0.33))
mat("Nose", (0.78, 0.40, 0.26))
mat("Blush", (0.90, 0.30, 0.28))
mat("Mouth", (0.25, 0.04, 0.04))
mat("Brow", (0.12, 0.05, 0.02))
mat("Hair", (0.20, 0.08, 0.025), rough=0.45)
mat("Cap", (0.015, 0.015, 0.018), rough=0.5)
mat("Cap White", (0.85, 0.85, 0.84), rough=0.5)
mat("Glasses", (0.01, 0.01, 0.012), rough=0.05)
mat("Lens Shine", (0.5, 0.6, 0.7), rough=0.05, emit=0.6)
mat("Hoodie", (0.02, 0.04, 0.14), rough=0.7)
mat("Hoodie Shade", (0.012, 0.025, 0.09), rough=0.7)
mat("Zipper", (0.55, 0.56, 0.58), rough=0.3, metal=0.8)
mat("String", (0.85, 0.85, 0.84))
mat("Shorts", (0.55, 0.36, 0.15), rough=0.7)
mat("Shorts Trim", (0.45, 0.28, 0.11), rough=0.7)
mat("Sock", (0.45, 0.46, 0.48), rough=0.8)
mat("Shoes", (0.015, 0.015, 0.017), rough=0.5)
mat("Sole", (0.88, 0.88, 0.88))
mat("Backpack", (0.32, 0.14, 0.04), rough=0.55)
mat("Backpack Dark", (0.18, 0.07, 0.02), rough=0.6)

HEAD = Ellipsoid((0, 0, 1.10), (0.26, 0.24, 0.26))
TORSO = Ellipsoid((0, 0, 0.65), (0.23, 0.20, 0.25))
HB = ["head"]

ellipsoid("Head", HEAD.c, HEAD.r, "Skin", HB, u=48, v=24)
capsule("Neck", [(0, 0, 0.84), (0, 0, 0.96)], 0.065, 0.065, "Skin", ["chest", "head"])

# Hair: short and brown, mostly under the cap (sideburns, the back, a few tufts under the bill)
R = rng(3)
scalp_cap("Hair", HEAD, "Hair", HB, thick=0.016, hairline=lambda x: 1.235 - 0.13 * ss(0.17, 0.25, abs(x)), u=96,
          v=48, bottom=1.0)
for k in range(5):
    x = -0.12 + 0.06 * k
    s = HEAD.front(x, 1.26, offset=0.012)
    lock(f"Fringe.{k}", [s, HEAD.front(x - 0.02, 1.225, offset=0.02), HEAD.front(x - 0.035, 1.20, offset=0.016)],
         0.035, "Hair", HB, flat=0.45, normal_fn=lambda p: HEAD.normal(p), sides=8)

# Cap: black crown with a white front panel and a black star, curved bill
CROWN = Ellipsoid((0, 0.01, 1.17), (0.285, 0.27, 0.245))
crown = ellipsoid("Cap", CROWN.c, CROWN.r, "Cap", HB, u=128, v=64, keep_above=0.0)
# White front panel: a thin skin over the front of the crown, wide at the brim and narrowing to the top
PANEL_LO, PANEL_HI = 1.19, 1.385


def panel_half_w(z):
    return 0.19 - 0.12 * ((z - PANEL_LO) / (PANEL_HI - PANEL_LO)) ** 1.5


surface_patch("Cap Panel", CROWN, [[(panel_half_w(z) * (j / 12 - 1), z) for j in range(25)]
                                   for z in (PANEL_LO + (PANEL_HI - PANEL_LO) * i / 16 for i in range(17))],
              0.002, "Cap White", HB)
ellipsoid("Cap Button", CROWN.c + Vector((0, 0, CROWN.r.z)), (0.025, 0.025, 0.012), "Cap", HB)
star_at = CROWN.front(0, 1.29, offset=0.004)
star_prism("Cap Star", star_at, CROWN.normal(star_at), 0.055, 0.023, 0.008, "Cap", HB)
bill = ellipsoid("Cap Bill", (0, -0.29, 1.185), (0.21, 0.17, 0.014), "Cap", HB, u=48, v=12,
                 rot=Euler((math.radians(10), 0, 0)).to_matrix())
for v in bill.data.vertices:                                       # curve the bill down at its sides
    v.co.z -= 0.6 * v.co.x * v.co.x

# Face: sunglasses over the eyes, little nose, a cool half-smile
for sx, side in ((1, "L"), (-1, "R")):
    lc = HEAD.front(0.095 * sx, 1.10)
    n = HEAD.normal(lc)
    ellipsoid(f"Lens.{side}", lc + n * 0.02, (0.085, 0.013, 0.06), "Glasses", HB, rot=basis_facing(n), power=0.55)
    sh = lc + n * 0.034 + Vector((0.02 * sx, 0, 0.02))
    ellipsoid(f"Lens Shine.{side}", sh, (0.03, 0.004, 0.008), "Lens Shine", HB,
              rot=basis_facing(n) @ Euler((0, math.radians(-30), 0)).to_matrix())
    outer = HEAD.front(0.175 * sx, 1.11, offset=0.025)
    arm = [outer, HEAD.dir_point((sx, -0.35, 0.05), offset=0.018), HEAD.dir_point((sx, 0.05, 0.02), offset=0.012)]
    tube(f"Glasses Arm.{side}", smooth_path(arm, 4), [(0.009, 0.006)] * 9, "Glasses", HB, sides=8)
    arc_on(HEAD, f"Brow.{side}", [(sx * (0.05 + 0.10 * t), 1.19 + 0.012 * math.sin(math.pi * t)) for t in
                                  (i / 7 for i in range(8))], 0.011, "Brow", HB, offset=0.005)
    ear = HEAD.dir_point((sx, 0.05, -0.05), offset=-0.005)
    ellipsoid(f"Ear.{side}", ear, (0.035, 0.05, 0.062), "Skin", HB)
    b = HEAD.front(0.16 * sx, 1.0)
    ellipsoid(f"Blush.{side}", b - HEAD.normal(b) * 0.006, (0.035, 0.012, 0.022), "Blush", HB,
              rot=basis_facing(HEAD.normal(b)))
bridge = [HEAD.front(0.03, 1.115, offset=0.03), HEAD.front(0, 1.12, offset=0.033), HEAD.front(-0.03, 1.115, offset=0.03)]
tube("Glasses Bridge", bridge, [(0.008, 0.006)] * 3, "Glasses", HB, sides=8)
n0 = HEAD.front(0, 1.025)
ellipsoid("Nose", n0 + HEAD.normal(n0) * 0.006, (0.026, 0.022, 0.022), "Nose", HB)
arc_on(HEAD, "Mouth", [(-0.05 + 0.11 * t, 0.962 + 0.02 * (t - 0.4) ** 2 + 0.008 * t) for t in (i / 9 for i in range(10))],
       0.008, "Mouth", HB, offset=0.002)

# Hoodie: navy with a bunched hood at the back, zipper, drawstrings, pocket, hem and long sleeves
torso = ellipsoid("Torso", TORSO.c, TORSO.r, "Hoodie", ["hips", "spine", "chest", ("thigh.L", 1.8),
                                                        ("thigh.R", 1.8)], u=64, v=32)
paint(torso, "Shorts", lambda c, n: c.z < 0.475)                   # below the hem it's his shorts
ellipsoid("Hood", (0, 0.13, 0.87), (0.19, 0.10, 0.075), "Hoodie Shade", ["chest", "head"], power=0.85)
ring_on("Collar", Ellipsoid((0, 0, 0.87), (0.09, 0.085, 0.05)), 0.87, 0.0, 0.03, "Hoodie", ["chest"])
ring_on("Hem", TORSO, 0.48, 0.004, 0.022, "Hoodie Shade", ["hips"])
zip_pts = [TORSO.front(0, z, offset=0.003) for z in (0.86, 0.78, 0.70, 0.62, 0.54, 0.47)]
tube("Zipper", zip_pts, [(0.005, 0.003)] * len(zip_pts), "Zipper", ["spine", "chest"], sides=6, normal_fn=TORSO.normal)
for sx in (1, -1):
    s = TORSO.front(0.035 * sx, 0.86, offset=0.008)
    tube(f"Drawstring.{sx}", [s, TORSO.front(0.04 * sx, 0.80, offset=0.008), TORSO.front(0.045 * sx, 0.73, offset=0.008)],
         [(0.005, 0.005)] * 3, "String", ["chest"], sides=6)
pocket = TORSO.project((0, -0.3, 0.55), offset=0.003)
ellipsoid("Pocket", pocket, (0.12, 0.008, 0.055), "Hoodie Shade", ["hips", "spine"],
          rot=basis_facing(TORSO.normal(pocket)), power=0.5)

for sx, side in ((1, "L"), (-1, "R")):
    sh, el, wr = Vector((0.225 * sx, 0, 0.80)), Vector((0.31 * sx, -0.03, 0.67)), Vector((0.38 * sx, -0.05, 0.56))
    capsule(f"Sleeve.{side}", [sh, el, wr], 0.068, 0.058, "Hoodie", [f"upper_arm.{side}", f"forearm.{side}"])
    d = (wr - el).normalized()
    capsule(f"Cuff.{side}", [wr - d * 0.02, wr + d * 0.01], 0.06, 0.06, "Hoodie Shade", [f"forearm.{side}"])
    ellipsoid(f"Hand.{side}", wr + d * 0.05, (0.052, 0.047, 0.06), "Skin", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", wr + d * 0.035 + Vector((0, -0.04, 0.005)), (0.02, 0.024, 0.028), "Skin",
              [f"hand.{side}"])
    x = 0.11 * sx
    capsule(f"Shorts.{side}", [(0.10 * sx, 0, 0.52), (x, 0, 0.35)], 0.108, 0.104, "Shorts", [("hips", 1.6),
                                                                                            f"thigh.{side}"])
    torus(f"Shorts Cuff.{side}", (x, 0, 0.345), 0.104, 0.016, "Shorts Trim", [f"thigh.{side}"])
    capsule(f"Leg.{side}", [(x, 0, 0.37), (x, 0, 0.12)], 0.062, 0.058, "Skin", [f"thigh.{side}", f"shin.{side}"])
    capsule(f"Sock.{side}", [(x, 0, 0.19), (x, 0, 0.10)], 0.064, 0.064, "Sock", [f"shin.{side}", f"foot.{side}"])
    ellipsoid(f"Shoe.{side}", (x, -0.045, 0.07), (0.076, 0.125, 0.064), "Shoes", [f"foot.{side}"], power=0.75)
    ellipsoid(f"Sole.{side}", (x, -0.045, 0.022), (0.082, 0.13, 0.024), "Sole", [f"foot.{side}"], power=0.5)
    ellipsoid(f"Toe.{side}", (x, -0.135, 0.045), (0.06, 0.045, 0.036), "Sole", [f"foot.{side}"])
    for k, yy in enumerate((-0.085, -0.055, -0.025)):
        ellipsoid(f"Lace.{side}{k}", (x, yy, 0.125 - k * 0.004), (0.04, 0.007, 0.006), "Sole", [f"foot.{side}"],
                  power=0.6, u=12, v=6)

BP = ["chest"]
ellipsoid("Backpack", (0, 0.30, 0.64), (0.17, 0.09, 0.18), "Backpack", BP, power=0.45, u=32, v=16)
ellipsoid("Backpack Flap", (0, 0.33, 0.74), (0.165, 0.07, 0.08), "Backpack Dark", BP, power=0.45, u=32, v=16)
for sx, side in ((1, "L"), (-1, "R")):
    path = [(0.10 * sx, 0.25, 0.80), (0.14 * sx, 0.12, 0.90), (0.16 * sx, -0.06, 0.90), (0.18 * sx, -0.18, 0.77),
            (0.20 * sx, -0.17, 0.62), (0.205 * sx, -0.12, 0.52)]
    pts = []
    for a, b in zip(path, path[1:]):
        for k in range(6):
            pts.append(TORSO.project(Vector(a).lerp(Vector(b), k / 6), offset=0.016))
    pts.append(TORSO.project(path[-1], offset=0.016))
    tube(f"Backpack Strap.{side}", pts, [(0.021, 0.006)] * len(pts), "Backpack Dark", BP, sides=8,
         normal_fn=TORSO.normal)

BONES = biped_bones(shoulder=(0.225, 0, 0.80), elbow=(0.31, -0.03, 0.67), wrist=(0.38, -0.05, 0.56),
                    hand_tip=(0.43, -0.065, 0.49), hip_x=0.11, knee=0.33)
rig = build_rig("BikeBoyRig", BONES)
skin_and_join(rig, BONES, "BikeBoy", "Torso")


def ride(t):
    # Sitting on the saddle leaning forward, hands on the grips, feet on the pedals (same loop as the bike)
    p = Pose(BONES)
    p.offset = SEAT + Vector((0, 0, 0.095)) - Vector(BONES["hips"][0])
    p.rel("hips", (X, 0.15))
    p.rel("spine", (X, 0.22), (Z, 0.03 * math.sin(2 * math.pi * t)))
    p.rel("chest", (X, 0.1))
    p.rel("head", (X, -0.42))
    for side in ("L", "R"):
        s = 1 if side == "L" else -1
        ankle = pedal_pos(side, t) + Vector((0, 0.03, 0.065))
        p.ik(f"thigh.{side}", f"shin.{side}", ankle, Vector((0.15 * s, -1, 0.5)))
        p.aim(f"foot.{side}", Vector((0, -1, -0.35)))
        p.ik(f"upper_arm.{side}", f"forearm.{side}", GRIP[side] + Vector((0, 0.035, 0.02)), Vector((0.6 * s, 0.6, -0.5)))
        p.aim(f"hand.{side}", Vector((0.15 * s, -1, -0.45)))
    return p


make_action(rig, "idle", 60, lambda t: biped_idle(BONES, t))
make_action(rig, "walk", 32, lambda t: biped_walk(BONES, t))
make_action(rig, "run", 20, lambda t: biped_run(BONES, t))
make_action(rig, "ride", RIDE_FRAMES, ride)
rest_pose(rig)
finish(OUT_BOY)

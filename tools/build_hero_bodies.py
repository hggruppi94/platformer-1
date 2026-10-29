# Builds more bodies for the hero creator (Godot Project/my-world/scripts/hero.gd), from scratch: model, materials,
# rig, weights and animations. Each is a kid the size of Dash (tools/build_bike_boy.py) on two legs, so clothes,
# hairstyles and skating fit them the same way, and each has its own face parts as separate pieces (eyes, nose, ears,
# mouth) for face sculpting (scripts/face_sculpt.gd):
#
#   earth_kid   a kid from Earth (in the show, kids are people on Earth): round ears, button nose, T-shirt and jeans
#   bunny       a bunny-kid: long ears, buck teeth, a pink nose, whiskers and a cotton tail, in dungarees
#   cat         a cat-kid: pointed ears, a little pink nose, whiskers and a long curly tail, in a hoodie
#   dino        a Galaxity dino-kid: a round snout with nostrils, little horns, spikes down the back and tail
#
#   blender -b --python tools\build_hero_bodies.py [-- name ...]
#
# Writes source_art/characters/<name>.blend (overwrites them). Export with tools\export_all.ps1 <name>.
# The bunny's and cat's ears are their own parts ("Ear", "Ear Lining"), so hats are fitted to their heads, not the
# tops of their ears. Units are meters; feet at the origin; they face -Y. Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters"

HB = ["head"]
SH, EL, WR, TIP = Vector((0.225, 0, 0.80)), Vector((0.31, -0.03, 0.67)), Vector((0.38, -0.05, 0.56)), (0.43, -0.065, 0.49)


def bones():
    return biped_bones(shoulder=tuple(SH), elbow=tuple(EL), wrist=tuple(WR), hand_tip=TIP, hip_x=0.11, knee=0.33)


# =============================================================================
# Shared parts
# =============================================================================
def face(head, skin, eye_y=1.10, eye_x=0.095, eye_r=(0.056, 0.036, 0.066), nose="button", smile_at=0.975,
         blush=True, brow_y=1.21, look=(0.0, 0.004)):
    """Big cartoon eyes, brows, blush, a nose and an open smile, each its own piece"""
    for sx, side in ((1, "L"), (-1, "R")):
        p = head.front(eye_x * sx, eye_y)
        cartoon_eye(side, p - head.normal(p) * 0.014, eye_r, HB, look=look)
        arc_on(head, f"Brow.{side}", [(sx * (0.045 + 0.10 * t), brow_y + 0.018 * math.sin(math.pi * t)) for t in
                                      (i / 7 for i in range(8))], 0.011, "Brow", HB, offset=0.005)
        if blush:
            b = head.front(0.165 * sx, 1.0)
            ellipsoid(f"Blush.{side}", b - head.normal(b) * 0.006, (0.035, 0.012, 0.022), "Blush", HB,
                      rot=basis_facing(head.normal(b)))
    if nose == "button":
        n0 = head.front(0, 1.035)
        ellipsoid("Nose", n0 + head.normal(n0) * 0.006, (0.026, 0.022, 0.022), "Nose", HB)
    elif nose == "pink":
        # A little upside-down triangle of a nose (cat and bunny)
        n0 = head.front(0, 1.04, offset=0.004)
        nose_ob = ellipsoid("Nose", n0, (0.024, 0.014, 0.016), "Nose", HB, rot=basis_facing(head.normal(n0)))
        for v in nose_ob.data.vertices:
            d = v.co - n0
            v.co.x = n0.x + d.x * (0.55 + 0.45 * ss(-0.016, 0.016, d.z))
    smile("Mouth", head, 0.0, smile_at, 0.06, 0.045, HB)


def whiskers(head, color="Whisker"):
    for sx in (1, -1):
        for k, (dz, tilt) in enumerate(((0.012, 0.025), (-0.004, 0.0), (-0.02, -0.025))):
            root = head.front(0.06 * sx, 1.015 + dz, offset=0.004)
            tip = root + Vector((0.13 * sx, -0.03, tilt))
            tube(f"Whisker.{sx}{k}", [root, root.lerp(tip, 0.5) + Vector((0, -0.006, 0.003)), tip],
                 [(0.0028, 0.0028), (0.0022, 0.0022), (0.0012, 0.0012)], color, HB, sides=6)


def kid_body(top, bottoms, skin, long_sleeves=False, long_legs=False, shoes="Shoes", sole="Sole", torso_r=(0.23, 0.20, 0.25),
             shorts_r=0.108):
    """Neck, torso in a top, arms with hands, legs in shorts or trousers, and sneakers"""
    torso_ell = Ellipsoid((0, 0, 0.65), torso_r)
    capsule("Neck", [(0, 0, 0.84), (0, 0, 0.96)], 0.065, 0.065, skin, ["chest", "head"])
    torso = ellipsoid("Torso", torso_ell.c, torso_ell.r, top, ["hips", "spine", "chest", ("thigh.L", 1.8),
                                                                ("thigh.R", 1.8)], u=64, v=32)
    paint(torso, bottoms, lambda c, n: c.z < 0.475)
    ring_on("Collar", Ellipsoid((0, 0, 0.87), (0.09, 0.085, 0.05)), 0.87, 0.0, 0.016, top + " Shade", ["chest"])
    ring_on("Hem", torso_ell, 0.48, 0.004, 0.018, top + " Shade", ["hips"])
    for sx, side in ((1, "L"), (-1, "R")):
        sh, el, wr = SH * Vector((sx, 1, 1)), EL * Vector((sx, 1, 1)), WR * Vector((sx, 1, 1))
        if long_sleeves:
            capsule(f"Sleeve.{side}", [sh, el, wr], 0.068, 0.058, top, [f"upper_arm.{side}", f"forearm.{side}"])
            d = (wr - el).normalized()
            capsule(f"Cuff.{side}", [wr - d * 0.02, wr + d * 0.01], 0.06, 0.06, top + " Shade", [f"forearm.{side}"])
        else:
            mid = sh.lerp(el, 0.6)
            capsule(f"Sleeve.{side}", [sh, mid], 0.07, 0.064, top, ["chest", f"upper_arm.{side}"])
            torus(f"Sleeve Hem.{side}", mid, 0.062, 0.012, top + " Shade", [f"upper_arm.{side}"],
                  rot=(el - sh).normalized().to_track_quat('Z', 'Y').to_matrix())
            capsule(f"Arm.{side}", [sh.lerp(el, 0.3), el, wr], 0.05, 0.045, skin, [f"upper_arm.{side}", f"forearm.{side}"])
        d = (wr - el).normalized()
        ellipsoid(f"Hand.{side}", wr + d * 0.05, (0.052, 0.047, 0.06), skin, [f"hand.{side}"],
                  rot=d.to_track_quat('-Z', 'Y').to_matrix())
        ellipsoid(f"Thumb.{side}", wr + d * 0.035 + Vector((0, -0.04, 0.005)), (0.02, 0.024, 0.028), skin,
                  [f"hand.{side}"])
        x = 0.11 * sx
        if long_legs:
            capsule(f"Trousers.{side}", [(0.10 * sx, 0, 0.52), (x, 0, 0.33), (x, 0, 0.13)], shorts_r, 0.075, bottoms,
                    [("hips", 1.6), f"thigh.{side}", f"shin.{side}"])
            torus(f"Trouser Cuff.{side}", (x, 0, 0.14), 0.074, 0.014, bottoms + " Shade", [f"shin.{side}"])
        else:
            capsule(f"Shorts.{side}", [(0.10 * sx, 0, 0.52), (x, 0, 0.36)], shorts_r, shorts_r - 0.004, bottoms,
                    [("hips", 1.6), f"thigh.{side}"])
            torus(f"Shorts Cuff.{side}", (x, 0, 0.355), shorts_r - 0.006, 0.014, bottoms + " Shade", [f"thigh.{side}"])
            capsule(f"Leg.{side}", [(x, 0, 0.37), (x, 0, 0.12)], 0.062, 0.058, skin, [f"thigh.{side}", f"shin.{side}"])
        ellipsoid(f"Shoe.{side}", (x, -0.045, 0.07), (0.076, 0.125, 0.064), shoes, [f"foot.{side}"], power=0.75)
        ellipsoid(f"Sole.{side}", (x, -0.045, 0.022), (0.082, 0.13, 0.024), sole, [f"foot.{side}"], power=0.5)
        ellipsoid(f"Toe.{side}", (x, -0.135, 0.045), (0.06, 0.045, 0.036), sole, [f"foot.{side}"])
        for k, yy in enumerate((-0.085, -0.055, -0.025)):
            ellipsoid(f"Lace.{side}{k}", (x, yy, 0.125 - k * 0.004), (0.04, 0.007, 0.006), sole, [f"foot.{side}"],
                      power=0.6, u=12, v=6)
    return torso_ell


def backpack(torso_ell, main="Backpack", dark="Backpack Dark"):
    bp = ["chest"]
    ellipsoid("Backpack", (0, 0.30, 0.64), (0.17, 0.09, 0.18), main, bp, power=0.45, u=32, v=16)
    ellipsoid("Backpack Flap", (0, 0.33, 0.74), (0.165, 0.07, 0.08), dark, bp, power=0.45, u=32, v=16)
    for sx, side in ((1, "L"), (-1, "R")):
        path = [(0.10 * sx, 0.25, 0.80), (0.14 * sx, 0.12, 0.90), (0.16 * sx, -0.06, 0.90), (0.18 * sx, -0.18, 0.77),
                (0.20 * sx, -0.17, 0.62), (0.205 * sx, -0.12, 0.52)]
        pts = []
        for a, b in zip(path, path[1:]):
            for k in range(6):
                pts.append(torso_ell.project(Vector(a).lerp(Vector(b), k / 6), offset=0.016))
        pts.append(torso_ell.project(path[-1], offset=0.016))
        tube(f"Backpack Strap.{side}", pts, [(0.021, 0.006)] * len(pts), dark, bp, sides=8, normal_fn=torso_ell.normal)


def short_hair(head, seed):
    """Short tufty hair (hidden when the creator gives them a hairstyle)"""
    scalp_cap("Hair", head, "Hair", HB, thick=0.016, hairline=lambda x: 1.235 - 0.13 * ss(0.17, 0.25, abs(x)), u=96,
              v=48, bottom=1.0)
    for k in range(5):
        x = -0.12 + 0.06 * k
        s = head.front(x, 1.26, offset=0.012)
        lock(f"Fringe.{k}", [s, head.front(x - 0.02, 1.225, offset=0.02), head.front(x - 0.035, 1.20, offset=0.016)],
             0.035, "Hair", HB, flat=0.45, normal_fn=lambda p: head.normal(p), sides=8)


def tail(name, pts, r0, material, tip=0.01, taper=0.8):
    lock(name, pts, r0, material, ["hips"], flat=1.0, tip=tip, taper=taper, sides=12)


def finish_kid(name, rig_name, main="Torso"):
    b = bones()
    rig = build_rig(rig_name, b)
    skin_and_join(rig, b, name, main)
    make_action(rig, "idle", 60, lambda t: biped_idle(b, t))
    make_action(rig, "walk", 32, lambda t: biped_walk(b, t))
    make_action(rig, "run", 20, lambda t: biped_run(b, t))
    rest_pose(rig)
    finish(OUT / f"{name.lower().replace(' ', '_')}.blend")


# =============================================================================
# Earth kid
# =============================================================================
def earth_kid():
    K.begin()
    mat("Skin", (0.80, 0.52, 0.38))
    mat("Nose", (0.74, 0.44, 0.31))
    mat("Ear Inner", (0.70, 0.40, 0.30))
    mat("Blush", (0.90, 0.36, 0.32))
    mat("Mouth", (0.25, 0.04, 0.04))
    mat("Tongue", (0.88, 0.32, 0.36))
    mat("Brow", (0.10, 0.05, 0.02))
    mat("Hair", (0.09, 0.05, 0.025), rough=0.45)
    eye_materials((0.05, 0.16, 0.06), (0.16, 0.38, 0.14))
    mat("Top", (0.95, 0.72, 0.10), rough=0.7)
    mat("Top Shade", (0.80, 0.52, 0.05), rough=0.7)
    mat("Star", (0.95, 0.95, 0.92), rough=0.6)
    mat("Jeans", (0.10, 0.20, 0.45), rough=0.8)
    mat("Jeans Shade", (0.06, 0.12, 0.30), rough=0.8)
    mat("Shoes", (0.70, 0.08, 0.08), rough=0.55)
    mat("Sole", (0.90, 0.90, 0.90))
    mat("Backpack", (0.10, 0.45, 0.45), rough=0.55)
    mat("Backpack Dark", (0.05, 0.28, 0.30), rough=0.6)
    head = Ellipsoid((0, 0, 1.10), (0.25, 0.23, 0.27))
    ellipsoid("Head", head.c, head.r, "Skin", HB, u=48, v=24)
    short_hair(head, 5)
    face(head, "Skin")
    for sx, side in ((1, "L"), (-1, "R")):
        ear = head.dir_point((sx, 0.05, -0.05), offset=-0.004)
        ellipsoid(f"Ear.{side}", ear, (0.03, 0.045, 0.058), "Skin", HB)
        ellipsoid(f"Ear Inner.{side}", ear + Vector((0.012 * sx, -0.008, 0)), (0.016, 0.03, 0.04), "Ear Inner", HB)
    torso_ell = kid_body("Top", "Jeans", "Skin", long_legs=True)
    star = torso_ell.front(0, 0.66, offset=0.003)
    star_prism("Shirt Star", star, torso_ell.normal(star), 0.06, 0.026, 0.006, "Star", ["spine", "chest"])
    backpack(torso_ell)
    finish_kid("Earth Kid", "EarthKidRig")


# =============================================================================
# Bunny-kid
# =============================================================================
def bunny():
    K.begin()
    mat("Fur", (0.80, 0.74, 0.86))
    mat("Ear", (0.80, 0.74, 0.86))
    mat("Fur Light", (0.95, 0.93, 0.96))
    mat("Ear Lining", (0.92, 0.50, 0.62), rough=0.7)
    mat("Nose", (0.90, 0.38, 0.55), rough=0.35)
    mat("Blush", (0.95, 0.45, 0.60))
    mat("Mouth", (0.25, 0.04, 0.06))
    mat("Tongue", (0.90, 0.35, 0.45))
    mat("Teeth", (0.97, 0.96, 0.92), rough=0.3)
    mat("Brow", (0.35, 0.28, 0.40))
    mat("Whisker", (0.30, 0.26, 0.34), rough=0.5)
    mat("Hair", (0.95, 0.93, 0.96), rough=0.6)
    eye_materials((0.30, 0.12, 0.45), (0.55, 0.30, 0.72))
    mat("Top", (0.55, 0.88, 0.75), rough=0.7)
    mat("Top Shade", (0.36, 0.70, 0.58), rough=0.7)
    mat("Dungarees", (0.95, 0.60, 0.25), rough=0.75)
    mat("Dungarees Shade", (0.78, 0.42, 0.14), rough=0.75)
    mat("Button", (0.95, 0.85, 0.30), rough=0.3, metal=0.6)
    mat("Shoes", (0.35, 0.45, 0.95), rough=0.55)
    mat("Sole", (0.92, 0.92, 0.92))
    mat("Flower", (1.0, 0.85, 0.25), rough=0.5)
    mat("Flower Middle", (0.95, 0.45, 0.15), rough=0.5)
    head = Ellipsoid((0, 0, 1.09), (0.26, 0.24, 0.25))
    ellipsoid("Head", head.c, head.r, "Fur", HB, u=48, v=24)
    # A puffy white muzzle and cheeks, with the nose on top and two big front teeth under it
    for sx in (1, -1):
        c = head.front(0.045 * sx, 1.005, offset=-0.012)
        ellipsoid(f"Cheek.{sx}", c, (0.05, 0.035, 0.04), "Fur Light", HB, rot=basis_facing(head.normal(c)))
    face(head, "Fur", eye_y=1.12, nose="pink", smile_at=0.968, brow_y=1.23)
    for sx in (1, -1):
        t = head.front(0.012 * sx, 0.958, offset=0.008)
        ellipsoid(f"Tooth.{sx}", t, (0.011, 0.006, 0.017), "Teeth", HB, rot=basis_facing(head.normal(t)), power=0.6)
    whiskers(head)
    # Tall ears, flat and a little apart, the right one flopped over at the tip
    for sx, side in ((1, "L"), (-1, "R")):
        base = head.dir_point((0.38 * sx, 0.05, 0.92), offset=-0.02)
        flop = Vector((0.06 * sx, 0.03, -0.08)) if side == "R" else Vector((0, 0, 0))
        pts = [base, base + Vector((0.025 * sx, 0.0, 0.14)), base + Vector((0.05 * sx, 0.01, 0.27)) + flop * 0.4,
               base + Vector((0.06 * sx, 0.02, 0.36)) + flop]
        lock(f"Ear.{side}", pts, 0.06, "Ear", HB, flat=0.38, tip=0.022, taper=0.35, sides=14,
             normal_fn=lambda p: Vector((0, -1, 0)))
        inner = [p + Vector((0, -0.016, 0)) for p in pts[:-1]] + [pts[-1] + Vector((0, -0.014, -0.03))]
        lock(f"Ear Inner.{side}", inner, 0.035, "Ear Lining", HB, flat=0.3, tip=0.012, taper=0.4, sides=12,
             normal_fn=lambda p: Vector((0, -1, 0)))
    # A flower tucked by the left ear (the extras)
    fc = head.dir_point((0.62, -0.25, 0.65), offset=0.01)
    for k in range(5):
        a = 2 * math.pi * k / 5
        ellipsoid(f"Petal.{k}", fc + Vector((0.026 * math.cos(a), -0.01, 0.026 * math.sin(a))), (0.02, 0.008, 0.02),
                  "Flower", HB, rot=basis_facing(head.normal(fc)))
    ellipsoid("Flower Middle", fc + Vector((0, -0.016, 0)), (0.014, 0.008, 0.014), "Flower Middle", HB)
    torso_ell = kid_body("Top", "Dungarees", "Fur")
    # Dungarees: a bib and straps over the top, with gold buttons
    bib = torso_ell.front(0, 0.6, offset=0.004)
    ellipsoid("Bib", bib, (0.12, 0.01, 0.12), "Dungarees", ["spine", "chest"], rot=basis_facing(torso_ell.normal(bib)),
              power=0.5)
    for sx in (1, -1):
        pts = [torso_ell.project((0.08 * sx, -0.2, 0.7), offset=0.008), torso_ell.project((0.11 * sx, -0.1, 0.86), offset=0.01),
               torso_ell.project((0.1 * sx, 0.12, 0.85), offset=0.01), torso_ell.project((0.09 * sx, 0.2, 0.6), offset=0.008)]
        tube(f"Strap.{sx}", smooth_path(pts, 5), [(0.022, 0.005)] * 16, "Dungarees", ["chest"], sides=8,
             normal_fn=torso_ell.normal)
        ellipsoid(f"Button.{sx}", torso_ell.front(0.085 * sx, 0.69, offset=0.012), (0.014, 0.006, 0.014), "Button", ["chest"])
    tail("Tail", [(0, 0.20, 0.45), (0, 0.26, 0.46)], 0.075, "Fur Light", tip=0.05, taper=0.4)
    finish_kid("Bunny", "BunnyRig")


# =============================================================================
# Cat-kid
# =============================================================================
def cat():
    K.begin()
    mat("Fur", (0.95, 0.52, 0.16))
    mat("Ear", (0.95, 0.52, 0.16))
    mat("Fur Light", (0.98, 0.88, 0.72))
    mat("Stripe", (0.72, 0.30, 0.06))
    mat("Ear Lining", (0.95, 0.60, 0.62), rough=0.7)
    mat("Nose", (0.92, 0.45, 0.52), rough=0.35)
    mat("Blush", (0.95, 0.42, 0.40))
    mat("Mouth", (0.25, 0.04, 0.05))
    mat("Tongue", (0.90, 0.35, 0.42))
    mat("Brow", (0.45, 0.18, 0.04))
    mat("Whisker", (0.98, 0.96, 0.92), rough=0.5)
    mat("Hair", (0.72, 0.30, 0.06), rough=0.55)
    eye_materials((0.18, 0.42, 0.06), (0.45, 0.72, 0.15))
    mat("Hoodie", (0.45, 0.22, 0.70), rough=0.7)
    mat("Hoodie Shade", (0.30, 0.13, 0.50), rough=0.7)
    mat("Shorts", (0.20, 0.20, 0.25), rough=0.7)
    mat("Shorts Shade", (0.12, 0.12, 0.16), rough=0.7)
    mat("Shoes", (0.95, 0.95, 0.95), rough=0.55)
    mat("Sole", (0.30, 0.30, 0.32))
    mat("Collar", (0.85, 0.12, 0.25), rough=0.5)
    mat("Bell", (0.95, 0.80, 0.25), rough=0.25, metal=0.9)
    head = Ellipsoid((0, 0, 1.09), (0.27, 0.235, 0.245))
    ellipsoid("Head", head.c, head.r, "Fur", HB, u=48, v=24)
    # Cream muzzle and stripes on the forehead
    m = head.front(0, 1.0, offset=-0.016)
    ellipsoid("Muzzle", m, (0.085, 0.04, 0.055), "Fur Light", HB, rot=basis_facing(head.normal(m)))
    for k, x in enumerate((-0.05, 0.0, 0.05)):
        arc_on(head, f"Stripe.{k}", [(x * 1.2 + 0.0 * t, 1.31 - 0.05 * t) for t in (i / 5 for i in range(6))], 0.012,
               "Stripe", HB, offset=0.003)
    face(head, "Fur", eye_y=1.11, eye_r=(0.058, 0.036, 0.07), nose="pink", smile_at=0.975, brow_y=1.22)
    whiskers(head)
    # Pointed ears
    for sx, side in ((1, "L"), (-1, "R")):
        base = head.dir_point((0.62 * sx, 0.0, 0.78), offset=-0.025)
        tip = base + Vector((0.05 * sx, 0.0, 0.14))
        lock(f"Ear.{side}", [base, base.lerp(tip, 0.5), tip], 0.075, "Ear", HB, flat=0.45, tip=0.008, taper=1.0,
             sides=12, normal_fn=lambda p: Vector((0, -1, 0)))
        lock(f"Ear Inner.{side}", [base + Vector((0, -0.02, 0.01)), tip + Vector((-0.008 * sx, -0.016, -0.03))], 0.045,
             "Ear Lining", HB, flat=0.35, tip=0.006, taper=1.0, sides=10, normal_fn=lambda p: Vector((0, -1, 0)))
    torso_ell = kid_body("Hoodie", "Shorts", "Fur", long_sleeves=True)
    ellipsoid("Hood", (0, 0.13, 0.87), (0.19, 0.10, 0.075), "Hoodie Shade", ["chest", "head"], power=0.85)
    pocket = torso_ell.project((0, -0.3, 0.55), offset=0.003)
    ellipsoid("Pocket", pocket, (0.12, 0.008, 0.055), "Hoodie Shade", ["hips", "spine"],
              rot=basis_facing(torso_ell.normal(pocket)), power=0.5)
    # A bell collar (the extras)
    ring_on("Bell Collar", Ellipsoid((0, 0, 0.905), (0.074, 0.072, 0.05)), 0.905, 0.0, 0.016, "Collar", ["chest", "head"],
            sides=10)
    ellipsoid("Bell", (0, -0.092, 0.875), (0.02, 0.02, 0.02), "Bell", ["chest"], u=16, v=8)
    # A long tail, curling up at the end, with a pale tip
    pts = [(0, 0.18, 0.47), (0, 0.33, 0.40), (0.04, 0.45, 0.48), (0.06, 0.48, 0.64), (0.02, 0.42, 0.75)]
    tail("Tail", pts, 0.045, "Fur", tip=0.03, taper=0.6)
    ellipsoid("Tail Tip", (0.02, 0.42, 0.75), (0.034, 0.034, 0.04), "Fur Light", ["hips"])
    finish_kid("Cat", "CatRig")


# =============================================================================
# Dino-kid (Galaxity)
# =============================================================================
def dino():
    K.begin()
    mat("Skin", (0.20, 0.72, 0.62))
    mat("Spike", (0.95, 0.45, 0.70), rough=0.45)
    mat("Horn", (0.97, 0.92, 0.80), rough=0.4)
    mat("Nostril", (0.05, 0.18, 0.15))
    mat("Blush", (0.95, 0.45, 0.55))
    mat("Mouth", (0.22, 0.04, 0.08))
    mat("Tongue", (0.90, 0.35, 0.50))
    mat("Teeth", (0.98, 0.97, 0.92), rough=0.3)
    mat("Brow", (0.05, 0.30, 0.25))
    mat("Hair", (0.95, 0.45, 0.70), rough=0.5)
    eye_materials((0.55, 0.25, 0.05), (0.90, 0.60, 0.15))
    mat("Top", (0.35, 0.40, 0.95), rough=0.7)
    mat("Top Shade", (0.20, 0.24, 0.70), rough=0.7)
    mat("Shorts", (0.95, 0.80, 0.25), rough=0.7)
    mat("Shorts Shade", (0.80, 0.62, 0.12), rough=0.7)
    mat("Shoes", (0.95, 0.40, 0.25), rough=0.55)
    mat("Sole", (0.95, 0.95, 0.92))
    mat("Scarf", (0.95, 0.30, 0.35), rough=0.75)
    head = Ellipsoid((0, 0.01, 1.10), (0.25, 0.25, 0.25))
    ellipsoid("Head", head.c, head.r, "Skin", HB, u=48, v=24)
    # A big round snout with nostrils on top, and a wide toothy smile
    snout = Ellipsoid((0, -0.2, 1.01), (0.15, 0.11, 0.09))
    ellipsoid("Snout", snout.c, snout.r, "Skin", HB, u=48, v=24)
    for sx in (1, -1):
        n = snout.front(0.05 * sx, 1.05, offset=-0.004)
        ellipsoid(f"Nostril.{sx}", n, (0.016, 0.01, 0.011), "Nostril", HB, rot=basis_facing(snout.normal(n)))
    for sx, side in ((1, "L"), (-1, "R")):
        p = head.front(0.10 * sx, 1.15)
        cartoon_eye(side, p - head.normal(p) * 0.012, (0.058, 0.036, 0.066), HB)
        arc_on(head, f"Brow.{side}", [(sx * (0.05 + 0.10 * t), 1.255 + 0.018 * math.sin(math.pi * t)) for t in
                                      (i / 7 for i in range(8))], 0.012, "Brow", HB, offset=0.005)
        b = head.front(0.17 * sx, 1.04)
        ellipsoid(f"Blush.{side}", b - head.normal(b) * 0.004, (0.035, 0.012, 0.022), "Blush", HB,
                  rot=basis_facing(head.normal(b)))
        # Little ear holes (dinos have no ear flaps): small round bumps on the sides
        ear = head.dir_point((sx, 0.1, 0.0), offset=-0.01)
        ellipsoid(f"Ear.{side}", ear, (0.022, 0.035, 0.035), "Skin", HB)
        # Two little horns up top
        hb = head.dir_point((0.35 * sx, 0.1, 0.93), offset=-0.01)
        lock(f"Horn.{side}", [hb, hb + Vector((0.02 * sx, 0.01, 0.05)), hb + Vector((0.03 * sx, 0.03, 0.09))], 0.03,
             "Horn", HB, flat=1.0, tip=0.004, taper=1.0, sides=10)
    smile("Mouth", snout, 0.0, 0.975, 0.09, 0.04, HB)
    for sx in (1, -1):
        for k in range(2):
            t = snout.front((0.035 + 0.03 * k) * sx, 0.972, offset=0.003)
            ellipsoid(f"Tooth.{sx}{k}", t, (0.008, 0.005, 0.011), "Teeth", HB)
    torso_ell = kid_body("Top", "Shorts", "Skin", torso_r=(0.24, 0.21, 0.26), shorts_r=0.112)
    # A row of spikes from the back of the head down the back and tail
    for k, (y, z, r) in enumerate(((0.21, 1.27, 0.04), (0.24, 1.16, 0.045), (0.22, 1.03, 0.04))):
        p = head.project((0, 1.0, z), offset=-0.005)
        lock(f"Head Spike.{k}", [p, p + Vector((0, 0.05, 0.03))], r, "Spike", HB, flat=0.35, tip=0.004, taper=1.0,
             sides=8, normal_fn=lambda q: Vector((1, 0, 0)))
    for k, z in enumerate((0.82, 0.72, 0.62)):
        p = torso_ell.project((0, 1.0, z), offset=-0.01)
        lock(f"Back Spike.{k}", [p, p + Vector((0, 0.07, 0.02))], 0.05, "Spike", ["spine", "chest"], flat=0.35, tip=0.004,
             taper=1.0, sides=8, normal_fn=lambda q: Vector((1, 0, 0)))
    # A thick tail swinging out behind, with spikes along it
    pts = [Vector((0, 0.15, 0.45)), Vector((0, 0.32, 0.33)), Vector((0.03, 0.48, 0.24)), Vector((0.06, 0.62, 0.20))]
    tail("Tail", pts, 0.1, "Skin", tip=0.015, taper=0.9)
    for k, t in enumerate((0.25, 0.5, 0.75)):
        sp = smooth_path(pts)
        p = sp[int(t * (len(sp) - 1))] + Vector((0, 0, 0.1 * (1 - t) + 0.01))
        lock(f"Tail Spike.{k}", [p, p + Vector((0, 0.03, 0.05))], 0.035 * (1.1 - t * 0.5), "Spike", ["hips"], flat=0.35,
             tip=0.003, taper=1.0, sides=8, normal_fn=lambda q: Vector((1, 0, 0)))
    # A scarf round the neck (the extras)
    ring_on("Scarf", Ellipsoid((0, 0, 0.885), (0.08, 0.078, 0.05)), 0.885, 0.0, 0.03, "Scarf", ["chest", "head"], sides=10)
    lock("Scarf End", [(0.04, -0.08, 0.88), (0.06, -0.11, 0.80), (0.07, -0.11, 0.72)], 0.035, "Scarf", ["chest"], flat=0.35,
         tip=0.03, taper=1.0, sides=8, normal_fn=lambda q: Vector((0, -1, 0)))
    finish_kid("Dino", "DinoRig")


BUILDERS = {"earth_kid": earth_kid, "bunny": bunny, "cat": cat, "dino": dino}
only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for key, build in BUILDERS.items():
    if not only or key in only:
        build()

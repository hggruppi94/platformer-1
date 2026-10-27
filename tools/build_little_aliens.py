# Builds the little aliens: seven tiny space kids in hooded, shiny suits, from the sheet Hayden shared on
# 2026-10-27 ("inspired by your drawing"): blue (wing cape), purple (flowing suit), yellow (tall and curious),
# red (cape), pink (fins), orange (wide sleeves) and green (tail). Every one has a round hood with little ear pads,
# a darker face peeking out of it, two huge glossy black eyes, a lighter stripe down the front of the suit, and
# stubby arms and legs. They're scenery: they wander over the ground, roofs and walls and fly little saucers
# (scripts/little_aliens.gd).
#
#   blender -b --python tools\build_little_aliens.py
#   blender -b --python tools\build_little_aliens.py -- red      (just one)
#
# Writes source_art/characters/little_alien_<colour>.blend (overwrites them). Units are meters; feet at the origin;
# they face -Y. About 0.55 m tall (the yellow one 0.66 m): knee to waist high next to the kids.
# Actions: idle (looking about), walk (a waddle), run (a scurry), sit (in a saucer's seat), float (drifting in the air,
# legs dangling) and wave.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402
import bpy                # noqa: E402
import bmesh              # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "source_art" / "characters"

# colour: suit, face (darker), stripe (lighter), the extra they wear, how tall they are (1 = 0.55 m)
ALIENS = {
    "blue":   dict(suit=(0.02, 0.10, 0.62), face=(0.012, 0.05, 0.32), stripe=(0.35, 0.6, 1.0), extra="wings", snout="beak"),
    "purple": dict(suit=(0.22, 0.04, 0.50), face=(0.10, 0.02, 0.24), stripe=(0.65, 0.42, 0.95), extra="flowing", snout="button"),
    "yellow": dict(suit=(0.88, 0.62, 0.02), face=(0.48, 0.30, 0.01), stripe=(1.0, 0.92, 0.45), extra="tall",
                   snout="button", tall=1.2),
    "red":    dict(suit=(0.62, 0.02, 0.035), face=(0.30, 0.01, 0.015), stripe=(1.0, 0.55, 0.55), extra="cape", snout="beak"),
    "pink":   dict(suit=(0.90, 0.26, 0.46), face=(0.52, 0.10, 0.22), stripe=(1.0, 0.75, 0.85), extra="fins", snout="beak"),
    "orange": dict(suit=(0.92, 0.24, 0.01), face=(0.50, 0.10, 0.005), stripe=(1.0, 0.70, 0.30), extra="sleeves", snout="button"),
    "green":  dict(suit=(0.05, 0.30, 0.05), face=(0.02, 0.15, 0.02), stripe=(0.95, 0.80, 0.10), extra="tail", snout="beak"),
}


def sheet(name, rows, material, bones):
    """A thin two-sided sheet (capes, wings, fins) through rows of points: quads between neighbouring rows."""
    bm = bmesh.new()
    vs = [[bm.verts.new(Vector(p)) for p in row] for row in rows]
    for r0, r1 in zip(vs, vs[1:]):
        for j in range(len(r0) - 1):
            bm.faces.new((r0[j], r0[j + 1], r1[j + 1], r1[j]))
    return new_obj(name, bm, material, bones, recalc=False)


def build(colour, spec):
    K.begin()
    s = spec.get("tall", 1.0)            # stretches the body and legs, not the head
    mat("Suit", spec["suit"], rough=0.3)
    mat("Face", spec["face"], rough=0.35)
    mat("Stripe", spec["stripe"], rough=0.3)
    mat("Eye", (0.004, 0.004, 0.006), rough=0.05)
    mat("Eye Shine", (1.0, 1.0, 1.0), rough=0.05, emit=1.5)
    mat("Glow", spec["stripe"], rough=0.3, emit=2.0)
    for name in ("Suit", "Stripe"):                       # capes and wings are one sheet thick: show both sides
        MATS[name].use_backface_culling = False

    leg = 0.13 * s                       # hip height
    chest = leg + 0.115 * s
    neck = chest + 0.045
    HB = ["head"]

    # Head: a round hood with a darker face peeking out the front, ringed by the hood's rim
    hc = Vector((0, 0, neck + 0.115))
    HOOD = Ellipsoid(hc, (0.15, 0.14, 0.145))
    ellipsoid("Hood", HOOD.c, HOOD.r, "Suit", HB, u=40, v=24)
    FACE = Ellipsoid(hc + Vector((0, -0.052, -0.012)), (0.108, 0.098, 0.1))
    ellipsoid("Face", FACE.c, FACE.r, "Face", HB, u=40, v=24)
    torus("Hood Rim", hc + Vector((0, -0.112, -0.012)), 0.098, 0.02, "Suit", HB, u=40, v=10,
          rot=Euler((math.radians(90), 0, 0)))
    for sx, side in ((1, "L"), (-1, "R")):
        ec = FACE.front(0.047 * sx, hc.z - 0.005, offset=-0.008)
        tilt = Matrix.Rotation(math.radians(-14 * sx), 3, 'Y')
        ellipsoid(f"Eye.{side}", ec, (0.04, 0.022, 0.05), "Eye", HB, rot=basis_facing(FACE.normal(ec)) @ tilt)
        sp = FACE.front(0.036 * sx, hc.z + 0.018, offset=0.011)
        ellipsoid(f"Eye Shine.{side}", sp, (0.009, 0.004, 0.009), "Eye Shine", HB, u=10, v=6)
        sp2 = FACE.front(0.058 * sx, hc.z - 0.028, offset=0.009)
        ellipsoid(f"Eye Shine Small.{side}", sp2, (0.004, 0.003, 0.004), "Eye Shine", HB, u=8, v=4)
        if spec["extra"] != "fins":                      # round ear pads on the hood, like headphones
            ellipsoid(f"Ear Pad.{side}", hc + Vector((0.148 * sx, 0.005, -0.005)), (0.022, 0.05, 0.05), "Suit", HB)
            ellipsoid(f"Ear Dot.{side}", hc + Vector((0.168 * sx, 0.005, -0.005)), (0.006, 0.026, 0.026),
                      "Stripe", HB)
    snout_tip = _snout(spec["snout"], FACE, hc)
    arc_on(FACE, "Mouth", [(-0.014 + 0.028 * i / 6, hc.z - 0.082 + 6.0 * (-0.014 + 0.028 * i / 6) ** 2)
                           for i in range(7)], 0.0035, "Eye", HB, offset=0.001)
    # The seam over the top of the hood, in the stripe colour
    tube("Hood Seam", [HOOD.dir_point((0, -0.6 + 1.6 * k / 10, 1.0 - abs(-0.6 + 1.6 * k / 10) * 0.3), 0.002)
                       for k in range(11)], [(0.008, 0.003)] * 11, "Stripe", HB, sides=6, normal_fn=HOOD.normal)

    # Body: a round little suit with a lighter stripe down the front
    TORSO = Ellipsoid((0, 0, leg + 0.06 * s), (0.085, 0.072, 0.105 * s))
    ellipsoid("Torso", TORSO.c, TORSO.r, "Suit", ["hips", "spine", "chest", ("thigh.L", 2.0), ("thigh.R", 2.0)],
              u=32, v=16)
    tube("Stripe", [TORSO.front(0.0, TORSO.c.z + TORSO.r.z * (0.85 - 1.5 * k / 8), 0.002) for k in range(9)],
         [(0.013, 0.003)] * 9, "Stripe", ["spine", "chest", "hips"], sides=6, normal_fn=TORSO.normal)
    ellipsoid("Belly Light", TORSO.front(0, TORSO.c.z + 0.02, 0.004), (0.012, 0.005, 0.012), "Glow",
              ["spine"], u=10, v=6)

    SH = (0.07, 0.0, chest + 0.005)
    EL = (0.112, -0.012, chest - 0.06 * s)
    WR = (0.135, -0.022, chest - 0.115 * s)
    TIP = (0.145, -0.03, chest - 0.15 * s)
    for sx, side in ((1, "L"), (-1, "R")):
        m = lambda p: Vector((p[0] * sx, p[1], p[2]))
        sh, el, wr = m(SH), m(EL), m(WR)
        capsule(f"Arm.{side}", [sh, el, wr], 0.03, 0.025, "Suit", [f"upper_arm.{side}", f"forearm.{side}"],
                sides=14)
        d = (wr - el).normalized()
        ellipsoid(f"Mitten.{side}", wr + d * 0.02, (0.026, 0.022, 0.03), "Face", [f"hand.{side}"],
                  rot=d.to_track_quat('-Z', 'Y').to_matrix(), u=16, v=8)
        capsule(f"Thumb.{side}", [wr + d * 0.012 + Vector((0, -0.016, 0)), wr + d * 0.02 + Vector((0.006 * sx, -0.034, 0))],
                0.009, 0.008, "Face", [f"hand.{side}"], steps=4, sides=8)
        torus(f"Cuff.{side}", wr - d * 0.004, 0.024, 0.006, "Stripe", [f"forearm.{side}"], u=16, v=6,
              rot=d.to_track_quat('Z', 'Y').to_matrix())
    hip_x = 0.042
    knee = leg * 0.55
    ankle = 0.028
    for sx, side in ((1, "L"), (-1, "R")):
        x = hip_x * sx
        capsule(f"Leg.{side}", [(x, 0, leg), (x, -0.004, knee), (x, 0, ankle)], 0.036, 0.032, "Suit",
                [f"thigh.{side}", f"shin.{side}"], sides=14)
        ellipsoid(f"Boot.{side}", (x * 1.05, -0.018, 0.024), (0.034, 0.05, 0.026), "Face", [f"foot.{side}"], u=16, v=8)
        torus(f"Boot Rim.{side}", (x, -0.004, 0.044), 0.031, 0.006, "Stripe", [f"shin.{side}"], u=16, v=6)

    _extra(spec["extra"], hc, HOOD, TORSO, leg, chest, s, SH, EL, WR)

    BONES = biped_bones(hips=leg, chest=chest, neck=neck, head_top=hc.z + 0.15, shoulder=SH, elbow=EL, wrist=WR,
                        hand_tip=TIP, hip_x=hip_x, knee=knee, ankle=ankle, toe=(-0.07, 0.012))
    # Its own bone, from where the snout meets the face out to its tip, so the game can make each alien's snout a
    # different size (scripts/little_alien.gd) without a model per size
    base = FACE.front(0, hc.z + SNOUT_Z, -0.01)
    BONES["snout"] = (tuple(base), tuple(snout_tip if (snout_tip - base).length > 0.01 else base + Vector((0, -0.03, 0))),
                      "head")
    rig = build_rig("LittleAlienRig", BONES)
    skin_and_join(rig, BONES, "LittleAlien", "Torso")
    make_action(rig, "idle", 90, lambda t: alien_idle(BONES, t))
    make_action(rig, "walk", 24, lambda t: alien_walk(BONES, t))
    make_action(rig, "run", 14, lambda t: alien_run(BONES, t))
    make_action(rig, "sit", 60, lambda t: alien_sit(BONES, t))
    make_action(rig, "float", 60, lambda t: alien_float(BONES, t))
    make_action(rig, "wave", 40, lambda t: alien_wave(BONES, t))
    rest_pose(rig)
    finish(OUT_DIR / f"little_alien_{colour}.blend")


SNOUT_Z = -0.052                          # how far below the middle of the hood the snout sits, under the eyes


def _snout(kind, FACE, hc):
    """Each colour's own snout, all on the "snout" bone. Returns where its tip is."""
    SB = ["snout"]
    z0 = hc.z + SNOUT_Z
    b = FACE.front(0, z0, -0.01)
    fwd = Vector((0, -1, 0))

    def nostrils(at, gap, r=0.0045):
        for sx in (-1, 1):
            ellipsoid(f"Nostril{sx}", at + Vector((gap * sx, 0, 0)), (r, r * 0.7, r * 0.8), "Eye", SB, u=8, v=4)
    if kind == "muzzle":                 # a long rounded muzzle, a little like an anteater's
        tip = b + Vector((0, -0.075, -0.014))
        capsule("Snout", [b, b + Vector((0, -0.04, -0.004)), tip], 0.026, 0.016, "Face", SB, sides=14)
        ellipsoid("Snout Nose", tip + fwd * 0.012, (0.013, 0.008, 0.01), "Eye", SB, u=12, v=6)
    elif kind == "button":               # just a small round button nose
        tip = FACE.front(0, z0, 0.006)
        ellipsoid("Snout", tip, (0.021, 0.017, 0.017), "Face", SB, u=16, v=8)
        nostrils(tip + fwd * 0.015 + Vector((0, 0, -0.004)), 0.007, 0.003)
    elif kind == "long":                 # a long thin nose that curls up at the end: very curious
        tip = b + Vector((0, -0.095, 0.03))
        lock("Snout", [b, b + Vector((0, -0.055, -0.004)), tip], 0.02, "Face", SB, flat=1.0, tip=0.008, taper=0.8)
        ellipsoid("Snout Tip", tip, (0.011, 0.011, 0.011), "Stripe", SB, u=12, v=6)
    elif kind == "pig":                  # a short round pig snout with a flat end and two nostrils
        tip = b + Vector((0, -0.04, 0))
        cylinder("Snout", b, tip, 0.026, "Face", SB, sides=20)
        ellipsoid("Snout End", tip, (0.027, 0.006, 0.023), "Face", SB, u=20, v=8)
        nostrils(tip + fwd * 0.005, 0.009, 0.005)
    elif kind == "beak":                 # a dolphin's bottle nose
        tip = b + Vector((0, -0.065, -0.008))
        capsule("Snout", [b, tip], 0.024, 0.009, "Face", SB, sides=14)
    elif kind == "bulb":                 # a big bulb of a nose
        tip = FACE.front(0, z0, 0.018)
        ellipsoid("Snout", tip, (0.031, 0.028, 0.027), "Face", SB, u=20, v=10)
        nostrils(tip + Vector((0, -0.022, -0.012)), 0.011, 0.005)
    else:                                # "wide": a wide flat frog snout
        tip = FACE.front(0, z0, 0.004)
        ellipsoid("Snout", tip, (0.046, 0.02, 0.017), "Face", SB, u=24, v=10)
        nostrils(tip + Vector((0, -0.016, 0.009)), 0.014, 0.004)
    return Vector(tip)


def _extra(kind, hc, HOOD, TORSO, leg, chest, s, SH, EL, WR):
    back_y = TORSO.c.y + TORSO.r.y
    if kind == "wings":
        # A wing cape: three feathered flaps fanning back and out from each arm
        for sx, side in ((1, "L"), (-1, "R")):
            for k, (out, down, length) in enumerate(((0.15, 0.03, 0.17), (0.18, -0.06, 0.19), (0.13, -0.15, 0.15))):
                root = Vector((SH[0] * sx * 0.9, back_y * 0.6, chest - 0.01 - 0.035 * k))
                ctrl = [root, root + Vector((out * 0.5 * sx, 0.05, down * 0.5)),
                        root + Vector((out * sx, 0.07 + 0.01 * k, down - 0.02 * k))]
                lock(f"Wing.{side}{k}", ctrl, 0.065 - 0.01 * k, "Suit", [f"upper_arm.{side}", "chest"], flat=0.12,
                     tip=0.006, taper=0.7, normal_fn=lambda p: Vector((0, 1, 0)))
    elif kind == "cape":
        # A cape from the shoulders to the knees, flaring out at the hem
        rows = []
        for i in range(7):
            t = i / 6
            z = chest + 0.02 - t * (chest - leg * 0.35)
            half = 0.08 + 0.1 * t
            rows.append([(half * (-1 + 2 * j / 8), back_y + 0.012 + 0.05 * t * t
                          + 0.02 * math.cos(math.pi * (-1 + 2 * j / 8) / 2), z) for j in range(9)])
        sheet("Cape", rows, "Suit", ["chest", "spine", "hips"])
        torus("Cape Clasp", (0, -0.065, chest + 0.01), 0.07, 0.01, "Stripe", ["chest"], u=24, v=6)
    elif kind == "flowing":
        # A flowing suit: flared trouser hems and long ribbons trailing from the wrists and the back
        for sx, side in ((1, "L"), (-1, "R")):
            x = 0.042 * sx
            tube(f"Flare.{side}", [(x, 0, leg * 0.45), (x * 1.1, 0, 0.03)], [(0.037, 0.037), (0.055, 0.055)], "Suit",
                 [f"shin.{side}"], sides=14, caps=False)
            w = Vector(WR) * Vector((sx, 1, 1))
            lock(f"Ribbon.{side}", [w, w + Vector((0.04 * sx, 0.06, -0.04)), w + Vector((0.07 * sx, 0.13, -0.03))],
                 0.022, "Suit", [f"forearm.{side}"], flat=0.2, tip=0.004, normal_fn=lambda p: Vector((0, 0, 1)))
        for k in (-1, 1):
            r = Vector((0.03 * k, back_y, chest - 0.02))
            lock(f"Tail Ribbon{k}", [r, r + Vector((0.03 * k, 0.07, -0.08)), r + Vector((0.05 * k, 0.16, -0.12))],
                 0.03, "Suit", ["chest", "spine"], flat=0.18, tip=0.004, normal_fn=lambda p: Vector((0, 1, 0)))
    elif kind == "tall":
        # Tall and curious: long pointed ears out of the hood and an antenna with a glowing tip
        for sx, side in ((1, "L"), (-1, "R")):
            root = hc + Vector((0.12 * sx, 0.01, 0.05))
            lock(f"Long Ear.{side}", [root, root + Vector((0.06 * sx, 0.01, 0.04)), root + Vector((0.13 * sx, 0.02, 0.05))],
                 0.035, "Suit", ["head"], flat=0.35, tip=0.004, normal_fn=lambda p: Vector((0, -1, 0)))
        top = HOOD.dir_point((0, 0, 1))
        capsule("Antenna", [top - Vector((0, 0, 0.01)), top + Vector((0, 0.01, 0.07))], 0.01, 0.007, "Suit", ["head"],
                steps=4, sides=8)
        ellipsoid("Antenna Tip", top + Vector((0, 0.012, 0.085)), (0.018, 0.018, 0.018), "Glow", ["head"], u=12, v=6)
    elif kind == "fins":
        # Fins: one on each side of the hood, a crest over the top and down the back, and little ones on the arms
        for sx, side in ((1, "L"), (-1, "R")):
            root = hc + Vector((0.14 * sx, 0.02, 0.0))
            lock(f"Head Fin.{side}", [root, root + Vector((0.05 * sx, 0.04, 0.02)), root + Vector((0.08 * sx, 0.09, 0.06))],
                 0.05, "Suit", ["head"], flat=0.15, tip=0.006, taper=0.6, normal_fn=lambda p: Vector((1, 0, 0)))
            e = Vector(EL) * Vector((sx, 1, 1))
            lock(f"Arm Fin.{side}", [e, e + Vector((0.035 * sx, 0.03, 0.0)), e + Vector((0.05 * sx, 0.06, -0.03))],
                 0.025, "Suit", [f"forearm.{side}"], flat=0.15, tip=0.004, normal_fn=lambda p: Vector((1, 0, 0)))
        crest = [HOOD.dir_point((0, -0.2 + 1.2 * k / 6, 1.0 - 0.75 * k / 6), 0.0) for k in range(7)]
        lock("Crest", crest + [crest[-1] + Vector((0, 0.03, -0.03))], 0.04, "Stripe", ["head"], flat=0.18, tip=0.008,
             taper=0.4, normal_fn=lambda p: Vector((1, 0, 0)))
        r = Vector((0, back_y, chest - 0.01))
        lock("Back Fin", [r, r + Vector((0, 0.04, -0.03)), r + Vector((0, 0.06, -0.09))], 0.04, "Suit",
             ["chest", "spine"], flat=0.15, tip=0.006, normal_fn=lambda p: Vector((1, 0, 0)))
    elif kind == "sleeves":
        # Wide sleeves: bell sleeves flaring from the elbow, with ragged flaps hanging under the arms
        for sx, side in ((1, "L"), (-1, "R")):
            e, w = Vector(EL) * Vector((sx, 1, 1)), Vector(WR) * Vector((sx, 1, 1))
            d = (w - e).normalized()
            tube(f"Sleeve.{side}", [e - d * 0.01, w + d * 0.01], [(0.034, 0.034), (0.07, 0.07)], "Suit",
                 [f"forearm.{side}"], sides=16, caps=False)
            for k in range(3):
                root = Vector(SH) * Vector((sx, 1, 1)) + (e - Vector(SH) * Vector((sx, 1, 1))) * (0.3 + 0.35 * k) \
                    + Vector((0, 0.01, -0.02))
                lock(f"Flap.{side}{k}", [root, root + Vector((0.03 * sx, 0.02, -0.05)), root + Vector((0.05 * sx, 0.03, -0.1))],
                     0.03, "Suit", [f"upper_arm.{side}", f"forearm.{side}"], flat=0.15, tip=0.005,
                     normal_fn=lambda p: Vector((0, 1, 0)))
    elif kind == "tail":
        # A tail curling out from the back of the suit, with a stripe tip
        r = Vector((0, back_y * 0.8, leg + 0.01))
        ctrl = [r, r + Vector((0, 0.07, -0.05)), r + Vector((0.03, 0.15, -0.06)), r + Vector((0.07, 0.19, 0.0))]
        lock("Tail", ctrl, 0.03, "Suit", ["hips"], flat=0.9, tip=0.012, taper=0.6)
        ellipsoid("Tail Tip", ctrl[-1] + Vector((0.005, 0.0, 0.01)), (0.016, 0.016, 0.02), "Stripe", ["hips"], u=12, v=6)


# =============================================================================
# Animations: a toddler-ish waddle, all head and wobble
# =============================================================================
def _arms(p, l=(), r=(), bend=0.25):
    p.rel("upper_arm.L", (Y, 0.15), *l)
    p.rel("upper_arm.R", (Y, -0.15), *r)
    p.rel("forearm.L", (X, -bend))
    p.rel("forearm.R", (X, -bend))


def alien_idle(bones, t):
    ph = 2 * math.pi * t
    s = math.sin(ph)
    p = Pose(bones)
    _arms(p, [(Y, 0.04 * s)], [(Y, -0.04 * s)])
    # Looks one way, then the other, then up, with a little bob
    look = math.sin(ph) * 0.45
    up = 0.18 * max(0.0, math.sin(2 * ph + 1.0)) ** 2
    p.rel("spine", (X, 0.02 * s))
    p.rel("head", (Z, look), (X, -up), (Y, 0.08 * math.sin(2 * ph)))
    p.offset = Vector((0, 0, 0.004 * math.sin(2 * ph)))
    return p


def alien_walk(bones, t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(bones)
    p.rel("thigh.L", (X, -0.45 * s))
    p.rel("thigh.R", (X, 0.45 * s))
    p.rel("shin.L", (X, 0.1 + 0.5 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.1 + 0.5 * max(0.0, c)))
    _arms(p, [(X, 0.5 * s)], [(X, -0.5 * s)], bend=0.35)
    p.rel("hips", (Y, 0.1 * s))                          # the waddle: rock side to side
    p.rel("spine", (X, 0.05), (Y, -0.06 * s))
    p.rel("head", (Y, -0.05 * s), (Z, 0.05 * s))
    p.offset = Vector((0.006 * s, 0, 0.012 * abs(s)))
    return p


def alien_run(bones, t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(bones)
    p.rel("thigh.L", (X, -0.8 * s))
    p.rel("thigh.R", (X, 0.8 * s))
    p.rel("shin.L", (X, 0.2 + 0.8 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.2 + 0.8 * max(0.0, c)))
    # Arms flung up and back: a scurry
    p.rel("upper_arm.L", (Y, -0.4), (X, 0.9 + 0.3 * s))
    p.rel("upper_arm.R", (Y, 0.4), (X, 0.9 - 0.3 * s))
    p.rel("forearm.L", (X, -0.4))
    p.rel("forearm.R", (X, -0.4))
    p.rel("spine", (X, 0.22))
    p.rel("head", (X, -0.2), (Y, 0.08 * s))
    p.offset = Vector((0, 0, 0.03 * abs(s)))
    return p


def alien_sit(bones, t):
    s = math.sin(2 * math.pi * t)
    p = Pose(bones)
    leg = bones["thigh.L"][0][2]
    p.offset = Vector((0, 0, -leg * 0.75))
    p.rel("thigh.L", (X, -1.45))
    p.rel("thigh.R", (X, -1.45))
    p.rel("shin.L", (X, 1.4 + 0.15 * s))
    p.rel("shin.R", (X, 1.4 - 0.15 * s))
    _arms(p, [(X, -0.5)], [(X, -0.5)], bend=0.8)          # hands forward on the controls
    p.rel("head", (Z, 0.25 * math.sin(4 * math.pi * t)), (X, -0.05))
    return p


def alien_float(bones, t):
    ph = 2 * math.pi * t
    s = math.sin(ph)
    p = Pose(bones)
    p.rel("thigh.L", (X, -0.25 + 0.1 * s))
    p.rel("thigh.R", (X, -0.1 - 0.1 * s))
    p.rel("shin.L", (X, 0.5))
    p.rel("shin.R", (X, 0.35))
    p.rel("upper_arm.L", (Y, -0.7 + 0.15 * s))
    p.rel("upper_arm.R", (Y, 0.7 - 0.15 * s))
    p.rel("forearm.L", (X, -0.3))
    p.rel("forearm.R", (X, -0.3))
    p.rel("spine", (X, 0.1))
    p.rel("head", (X, -0.12), (Z, 0.15 * math.sin(ph + 0.6)))
    p.offset = Vector((0, 0, 0.02 * s))
    return p


def alien_wave(bones, t):
    ph = 2 * math.pi * t
    s = math.sin(2 * ph)
    p = Pose(bones)
    p.rel("upper_arm.L", (Y, 0.15))
    p.rel("forearm.L", (X, -0.25))
    p.rel("upper_arm.R", (Y, 2.2), (X, -0.3))             # right arm up high
    p.rel("forearm.R", (Y, 0.5 * s))
    p.rel("spine", (Y, 0.06 * s))
    p.rel("head", (Y, -0.15), (Z, 0.1 * s))
    p.offset = Vector((0, 0, 0.01 * abs(math.sin(ph))))
    return p


only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for colour, spec in ALIENS.items():
    if not only or colour in only:
        build(colour, spec)

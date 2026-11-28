# Builds the Tuftlings (working name, 28 Nov 2026): the little furry folk who live in the Secret Garden, from the
# picture Hayden shared (a small tan furry archer with big dark eyes, pointed ears, a green head wrap with a feather, a
# leaf skirt, a bow and quiver, a blue pendant and green toed shoes). Hayden: "A bunch of them that are small like the
# aliens and have them have different personalities, colors, outfits, and quests with male and females", "I want them
# to be the inhabitants of the secret garden". Inspired by the picture, our own look.
#
# Eight of them, each with their own fur, outfit and gear (FOLK). The boys and girls share one body; the girls have
# lashes and either braids or a flower behind an ear. They're knee high to the kids, like the little aliens.
#
#   blender -b --python tools/build_garden_folk.py              (all eight)
#   blender -b --python tools/build_garden_folk.py -- moss      (just one)
#   (or with pip bpy 4.5: python tools/build_garden_folk.py -- moss)
#
# Writes source_art/characters/garden_folk_<id>.blend. Then tools/build_friend_detail.py folk_<id> exports the .glb
# with its baked detail (fur strands, leaf veins, leather, feathers) into models/characters/garden_folk_<id>.glb.
# Units are meters, feet at the origin, facing -Y. Actions: idle, walk, run, wave, cheer, sit.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402
import bpy                # noqa: E402,F401

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "source_art" / "characters"

# Each Tuftling: fur (main, lighter muzzle, darker tufts), girl or boy, what's on their head and its colours, what they
# wear below, the pendant's stone, what they carry and how big they are (1 = about 0.62 m).
FOLK = {
    # The one from Hayden's picture: brave, the garden's lookout and best shot
    "fennick": dict(fur=(0.62, 0.40, 0.18), light=(0.80, 0.62, 0.36), dark=(0.42, 0.25, 0.10), girl=False,
                    head="wrap", head_col=(0.17, 0.32, 0.06), feather=(0.72, 0.25, 0.06),
                    lower="skirt", leaf=(0.75, 0.18, 0.03), leaf2=(0.58, 0.10, 0.02), gem=(0.05, 0.28, 0.85),
                    shoe=(0.13, 0.25, 0.05), gear="bow"),
    # Cheerful, mad about flowers: a flower crown and a petal dress
    "thistle": dict(fur=(0.85, 0.72, 0.52), light=(0.97, 0.92, 0.80), dark=(0.62, 0.48, 0.30), girl=True,
                    head="flowers", head_col=(0.98, 0.55, 0.72), head_col2=(1.0, 0.95, 0.97),
                    lower="dress", leaf=(0.95, 0.52, 0.68), leaf2=(0.98, 0.88, 0.92), gem=(0.95, 0.75, 0.10),
                    shoe=(0.55, 0.62, 0.20), gear="bow", hair="flower"),
    # Sleepy and slow, always nodding off: a leaf hood and a satchel of snacks
    "moss": dict(fur=(0.42, 0.46, 0.38), light=(0.66, 0.70, 0.60), dark=(0.26, 0.30, 0.22), girl=False,
                 head="hood", head_col=(0.20, 0.42, 0.14), lower="skirt", leaf=(0.25, 0.45, 0.12),
                 leaf2=(0.16, 0.32, 0.08), gem=(0.30, 0.80, 0.55), shoe=(0.30, 0.22, 0.12), gear="satchel"),
    # Shy and gentle, writes little notes: snow-white fur, a blue wrap with a white feather
    "bluebell": dict(fur=(0.88, 0.88, 0.90), light=(1.0, 1.0, 1.0), dark=(0.66, 0.68, 0.74), girl=True,
                    head="wrap", head_col=(0.15, 0.30, 0.70), feather=(0.95, 0.95, 0.98),
                    lower="dress", leaf=(0.30, 0.35, 0.78), leaf2=(0.50, 0.30, 0.75), gem=(0.75, 0.40, 0.95),
                    shoe=(0.20, 0.28, 0.55), gear="bow", hair="braids"),
    # Grumpy but kind underneath: dark chocolate fur and an acorn cap
    "bracken": dict(fur=(0.25, 0.14, 0.07), light=(0.48, 0.32, 0.18), dark=(0.14, 0.07, 0.03), girl=False,
                    head="acorn", head_col=(0.20, 0.45, 0.15), head_col2=(0.62, 0.42, 0.16),
                    lower="skirt", leaf=(0.18, 0.55, 0.20), leaf2=(0.10, 0.38, 0.12), gem=(0.85, 0.15, 0.10),
                    shoe=(0.70, 0.18, 0.10), gear="staff"),
    # Curious explorer, always digging: fox-orange fur and a yellow wrap
    "clem": dict(fur=(0.85, 0.32, 0.08), light=(0.98, 0.85, 0.70), dark=(0.55, 0.16, 0.03), girl=True,
                 head="wrap", head_col=(0.95, 0.72, 0.08), feather=(0.15, 0.55, 0.45),
                 lower="skirt", leaf=(0.95, 0.60, 0.05), leaf2=(0.75, 0.38, 0.04), gem=(0.10, 0.70, 0.65),
                 shoe=(0.45, 0.30, 0.15), gear="satchel", hair="braids"),
    # The littlest, giggly, loves hide-and-seek: honey fur and a spotty mushroom cap
    "tumble": dict(fur=(0.85, 0.58, 0.25), light=(0.98, 0.85, 0.60), dark=(0.62, 0.38, 0.12), girl=False,
                   head="mushroom", head_col=(0.80, 0.10, 0.08), head_col2=(1.0, 0.97, 0.90),
                   lower="skirt", leaf=(0.45, 0.70, 0.15), leaf2=(0.30, 0.55, 0.10), gem=(0.95, 0.85, 0.20),
                   shoe=(0.15, 0.40, 0.20), gear="none", size=0.8),
    # The wise old keeper of the garden's lanterns: rosy fur going white, a lilac wrap and a staff
    "rosehip": dict(fur=(0.72, 0.45, 0.45), light=(0.95, 0.88, 0.88), dark=(0.50, 0.30, 0.30), girl=True,
                    head="wrap", head_col=(0.55, 0.35, 0.70), feather=(0.98, 0.80, 0.30),
                    lower="dress", leaf=(0.45, 0.25, 0.50), leaf2=(0.32, 0.16, 0.38), gem=(0.98, 0.55, 0.20),
                    shoe=(0.35, 0.22, 0.40), gear="staff", hair="flower", size=1.05),
}


def build(fid, spec):
    K.begin()
    s = spec.get("size", 1.0)
    mat("Fur", spec["fur"], rough=0.9)
    mat("Muzzle", spec["light"], rough=0.9)
    mat("Fur Dark", spec["dark"], rough=0.9)
    mat("Ear Inner", tuple(min(1.0, c * 0.6 + 0.35 * w) for c, w in zip(spec["fur"], (1.0, 0.55, 0.6))), rough=0.7)
    mat("Nose", (0.30, 0.12, 0.10), rough=0.35)
    mat("Mouth", (0.25, 0.06, 0.05), rough=0.5)
    eye_materials((0.16, 0.07, 0.03), (0.38, 0.20, 0.08))
    mat("Lash", (0.06, 0.03, 0.02), rough=0.5)
    mat("Leaf", spec["leaf"], rough=0.6)
    mat("Leaf Dark", spec["leaf2"], rough=0.6)
    mat("Wrap", spec["head_col"], rough=0.85)
    mat("Wrap Light", spec.get("head_col2", spec["head_col"]), rough=0.7)
    mat("Feather", spec.get("feather", (0.8, 0.5, 0.2)), rough=0.7)
    mat("Leather", (0.36, 0.20, 0.08), rough=0.65)
    mat("Leather Dark", (0.22, 0.12, 0.05), rough=0.7)
    mat("Metal", (0.75, 0.58, 0.22), rough=0.35, metal=0.9)
    mat("Gem", spec["gem"], rough=0.1, emit=0.4)
    mat("Cord", (0.10, 0.25, 0.75) if spec["gem"][2] > 0.5 else (0.45, 0.30, 0.15), rough=0.6)
    mat("Shoe", spec["shoe"], rough=0.8)
    mat("Claw", (0.93, 0.88, 0.76), rough=0.35)
    mat("Bow Wood", (0.45, 0.24, 0.08), rough=0.55)
    mat("Linen", (0.88, 0.80, 0.62), rough=0.9)
    mat("String", (0.20, 0.35, 0.80), rough=0.6)
    for name in ("Leaf", "Leaf Dark", "Feather"):          # leaves and feathers are thin: show both sides
        K.MATS[name].use_backface_culling = False

    # -------------------------------------------------------------- proportions (everything scaled by s)
    def v(x, y, z):
        return Vector((x * s, y * s, z * s))
    ankle, knee, leg = 0.03 * s, 0.12 * s, 0.21 * s
    chest, neck = 0.32 * s, 0.36 * s
    hc = v(0, 0, 0.445)
    HB = ["head"]
    HEAD = Ellipsoid(hc, (0.098 * s, 0.088 * s, 0.092 * s))
    ellipsoid("Head", HEAD.c, HEAD.r, "Fur", HB, u=40, v=24)
    capsule("Neck", [v(0, 0.004, 0.33), v(0, 0.006, 0.395)], 0.03 * s, 0.03 * s, "Fur", ["chest", "head"], sides=14)

    # Face: a short soft muzzle, a little nose, a closed smile, big dark glossy eyes
    MUZ = Ellipsoid(HEAD.front(0, hc.z - 0.034 * s, -0.026 * s), (0.044 * s, 0.032 * s, 0.03 * s))
    ellipsoid("Muzzle", MUZ.c, MUZ.r, "Muzzle", HB, u=24, v=12)
    nose_at = MUZ.front(0, MUZ.c.z + 0.012 * s, -0.002 * s)
    ellipsoid("Nose", nose_at, (0.012 * s, 0.008 * s, 0.008 * s), "Nose", HB, u=12, v=6)
    for sx in (-1, 1):                                   # a little cat smile, two curls either side of the middle
        arc_on(MUZ, f"Mouth{sx}", [(sx * 0.013 * s * (1 - math.cos(math.pi * i / 6)),
                                    MUZ.c.z - 0.006 * s - 0.005 * s * math.sin(math.pi * i / 6) + 0.003 * s * (i / 6) ** 2)
                                   for i in range(7)], 0.0028 * s, "Mouth", HB, offset=0.001)
    # Two little fangs poking down from the top lip (Hayden: "and add fangs")
    for sx in (-1, 1):
        f0 = MUZ.front(0.013 * sx * s, MUZ.c.z - 0.004 * s, -0.002 * s)
        lock(f"Fang.{'L' if sx > 0 else 'R'}", [f0, f0 + v(0.0005 * sx, -0.002, -0.009), f0 + v(0.001 * sx, -0.003, -0.016)],
             0.0042 * s, "Claw", HB, flat=0.8, tip=0.0006, taper=0.9, sides=8)
    arc_on(MUZ, "Philtrum", [(0, MUZ.c.z + 0.004 * s), (0, MUZ.c.z - 0.004 * s)], 0.002 * s, "Mouth", HB, offset=0.001)
    for sx, side in ((1, "L"), (-1, "R")):
        ec = HEAD.front(0.041 * sx * s, hc.z + 0.01 * s, offset=-0.012 * s)
        cartoon_eye(side, ec, (0.028 * s, 0.016 * s, 0.031 * s), HB, look=(0.0, 0.002 * s))
        brow = [(sx * (0.026 + 0.03 * k / 4) * s, hc.z + (0.052 + 0.006 * math.sin(math.pi * k / 4)) * s)
                for k in range(5)]
        arc_on(HEAD, f"Brow.{side}", brow, 0.004 * s, "Fur Dark", HB, offset=0.002)
        # Pointed elf ears, sticking out sideways and a little up, with a pink inside
        root = hc + v(0.082 * sx, 0.012, 0.012)
        ctrl = [root, root + v(0.04 * sx, 0.004, 0.012), root + v(0.085 * sx, 0.012, 0.038)]
        lock(f"Ear.{side}", ctrl, 0.03 * s, "Fur", HB, flat=0.32, tip=0.002, taper=0.8,
             normal_fn=lambda p: Vector((0, -1, 0)))
        ctrl_in = [c + v(0, -0.006, 0) for c in ctrl]
        lock(f"Ear Inner.{side}", [ctrl_in[0] + v(0.012 * sx, 0, 0), ctrl_in[1], ctrl_in[2] - v(0.012 * sx, 0, 0.004)],
             0.017 * s, "Ear Inner", HB, flat=0.25, tip=0.002, taper=0.8, normal_fn=lambda p: Vector((0, -1, 0)))
        if spec["girl"]:
            # Lashes: three little flicks off the outer corner of each eye
            for k in range(3):
                a = HEAD.front((0.058 + 0.005 * k) * sx * s, hc.z + (0.03 - 0.008 * k) * s, offset=0.001)
                lock(f"Lash.{side}{k}", [a, a + v(0.012 * sx, -0.004, 0.008 - 0.003 * k)], 0.003 * s, "Lash", HB,
                     flat=0.6, tip=0.0008, sides=6)

    # -------------------------------------------------------------- body
    TORSO = Ellipsoid(v(0, 0.002, 0.275), (0.064 * s, 0.05 * s, 0.075 * s))
    ellipsoid("Torso", TORSO.c, TORSO.r, "Fur", ["hips", "spine", "chest"], u=28, v=16)
    HIPS = Ellipsoid(v(0, 0.004, 0.215), (0.058 * s, 0.048 * s, 0.045 * s))
    ellipsoid("Hips", HIPS.c, HIPS.r, "Fur", ["hips", ("thigh.L", 2.0), ("thigh.R", 2.0)], u=24, v=12)
    ellipsoid("Chest Tuft", TORSO.front(0, chest - 0.01 * s, -0.012 * s), (0.03 * s, 0.012 * s, 0.025 * s), "Muzzle",
              ["chest"], u=16, v=8)

    SH = v(0.06, 0.0, 0.33)
    EL = v(0.085, -0.004, 0.255)
    WR = v(0.098, -0.012, 0.185)
    TIP = v(0.103, -0.018, 0.152)
    for sx, side in ((1, "L"), (-1, "R")):
        m = lambda p: Vector((p[0] * sx, p[1], p[2]))
        sh, el, wr = m(SH), m(EL), m(WR)
        capsule(f"Arm.{side}", [sh, el, wr], 0.021 * s, 0.017 * s, "Fur", [f"upper_arm.{side}", f"forearm.{side}"],
                sides=14)
        d = (wr - el).normalized()
        ellipsoid(f"Hand.{side}", wr + d * 0.016 * s, (0.02 * s, 0.017 * s, 0.022 * s), "Fur", [f"hand.{side}"],
                  rot=d.to_track_quat('-Z', 'Y').to_matrix(), u=16, v=8)
        capsule(f"Thumb.{side}", [wr + d * 0.008 * s + v(0, -0.012, 0), wr + d * 0.016 * s + v(0.004 * sx, -0.024, 0)],
                0.007 * s, 0.006 * s, "Fur", [f"hand.{side}"], steps=4, sides=8)
        # Little curved claws on each hand (Hayden: "and claws")
        for k in range(3):
            c0 = wr + d * 0.03 * s + v((k - 1) * 0.008 * sx, -0.012, 0)
            lock(f"Claw.{side}{k}", [c0, c0 + d * 0.008 * s + v(0, -0.004, 0), c0 + d * 0.012 * s + v(0, -0.01, 0)],
                 0.0035 * s, "Claw", [f"hand.{side}"], flat=0.8, tip=0.0006, taper=0.9, sides=8)
        # Leather bands on the upper arm and the wrist
        da = (el - sh).normalized()
        torus(f"Arm Band.{side}", sh + (el - sh) * 0.55, 0.023 * s, 0.005 * s, "Leather", [f"upper_arm.{side}"],
              u=16, v=6, rot=da.to_track_quat('Z', 'Y').to_matrix())
        torus(f"Wrist Band.{side}", wr - d * 0.012 * s, 0.02 * s, 0.006 * s, "Leather", [f"forearm.{side}"],
              u=16, v=6, rot=d.to_track_quat('Z', 'Y').to_matrix())

    hip_x = 0.03 * s
    for sx, side in ((1, "L"), (-1, "R")):
        x = hip_x * sx
        capsule(f"Leg.{side}", [(x, 0.004 * s, leg + 0.01 * s), (x, -0.004 * s, knee), (x, 0, ankle + 0.006 * s)],
                0.026 * s, 0.018 * s, "Fur", [f"thigh.{side}", f"shin.{side}"], sides=14)
        # Toed shoes: a soft shoe with four round toes and a buckled strap round the ankle
        ellipsoid(f"Shoe.{side}", (x * 1.1, -0.016 * s, 0.018 * s), (0.026 * s, 0.042 * s, 0.019 * s), "Shoe",
                  [f"foot.{side}"], u=16, v=8)
        for k in range(4):
            tx = x * 1.1 + (k - 1.5) * 0.012 * s
            ellipsoid(f"Toe.{side}{k}", (tx, -0.054 * s + abs(k - 1.5) * 0.004 * s, 0.011 * s),
                      (0.0075 * s, 0.011 * s, 0.009 * s), "Shoe", [f"foot.{side}"], u=10, v=6)
            # ...and a claw poking out of each toe
            c0 = Vector((tx, -0.062 * s + abs(k - 1.5) * 0.004 * s, 0.012 * s))
            lock(f"Toe Claw.{side}{k}", [c0, c0 + v(0, -0.006, -0.002), c0 + v(0, -0.01, -0.008)], 0.0035 * s, "Claw",
                 [f"foot.{side}"], flat=0.8, tip=0.0006, taper=0.9, sides=8)
        torus(f"Ankle Strap.{side}", (x, 0, ankle + 0.01 * s), 0.02 * s, 0.004 * s, "Leather", [f"shin.{side}"],
              u=16, v=6)
        ellipsoid(f"Ankle Buckle.{side}", (x + 0.019 * s * sx, -0.004 * s, ankle + 0.01 * s),
                  (0.004 * s, 0.005 * s, 0.006 * s), "Metal", [f"shin.{side}"], u=8, v=6)

    # -------------------------------------------------------------- outfit
    belt_z = 0.225 * s
    ring_on("Belt", HIPS, belt_z, 0.003 * s, 0.007 * s, "Leather", ["hips"], sides=6)
    ellipsoid("Belt Buckle", HIPS.front(0.012 * s, belt_z, 0.008 * s), (0.012 * s, 0.004 * s, 0.01 * s), "Metal",
              ["hips"], u=12, v=6)
    _lower(spec, HIPS, TORSO, belt_z, leg, knee, s)
    # A strap across the chest, over the left shoulder to the right hip (it holds the quiver or satchel)
    strap = []
    for k in range(13):
        t = k / 12
        x = (0.045 - 0.09 * t) * s
        z = chest + 0.025 * s - (chest + 0.025 * s - belt_z - 0.01 * s) * t
        strap.append(TORSO.project(Vector((x, -1.0, z)), 0.004 * s) if TORSO.inside(Vector((x, TORSO.c.y, z)))
                     else HIPS.project(Vector((x, -1.0, z)), 0.004 * s))
    back = []
    for k in range(13):
        t = k / 12
        x = (-0.045 + 0.09 * t) * s
        z = belt_z + 0.01 * s + (chest + 0.025 * s - belt_z - 0.01 * s) * t
        back.append(TORSO.project(Vector((x, 1.0, z)), 0.004 * s) if TORSO.inside(Vector((x, TORSO.c.y, z)))
                    else HIPS.project(Vector((x, 1.0, z)), 0.004 * s))
    over = [TORSO.project(Vector((0.045 * s, 0, chest + 0.05 * s)), 0.006 * s)]
    tube("Strap", back[:-1] + over + strap[1:], [(0.007 * s, 0.002 * s)] * (len(back) + len(strap) - 1), "Leather",
         ["chest", "spine", "hips"], sides=6, normal_fn=lambda p: TORSO.normal(p), caps=False)
    # The pendant: a cord round the neck and a round stone on the chest
    cord = []
    for k in range(25):
        a = 2 * math.pi * k / 24
        dip = max(0.0, -math.sin(a)) ** 2
        cord.append(Vector((math.cos(a) * 0.034 * s, 0.006 * s + math.sin(a) * 0.032 * s * (1 + 0.25 * dip),
                            0.352 * s - 0.03 * s * dip)))
    tube("Pendant Cord", cord, [(0.0022 * s, 0.0022 * s)] * len(cord), "Cord", ["chest", "head"], sides=6, caps=False)
    gem_at = TORSO.front(0, 0.322 * s, 0.012 * s)
    ellipsoid("Pendant", gem_at, (0.011 * s, 0.006 * s, 0.012 * s), "Gem", ["chest"], u=14, v=8)
    torus("Pendant Rim", gem_at + v(0, 0.001, 0), 0.011 * s, 0.002 * s, "Metal", ["chest"], u=16, v=6,
          rot=Euler((math.radians(90), 0, 0)))

    _head(spec, HEAD, hc, s)
    _gear(spec["gear"], TORSO, HIPS, WR, EL, s)

    BONES = biped_bones(hips=leg, chest=chest, neck=neck, head_top=hc.z + 0.1 * s, shoulder=SH, elbow=EL, wrist=WR,
                        hand_tip=TIP, hip_x=hip_x, knee=knee, ankle=ankle, toe=(-0.06 * s, 0.01 * s))
    rig = build_rig("GardenFolkRig", BONES)
    skin_and_join(rig, BONES, "GardenFolk", "Torso")
    make_action(rig, "idle", 90, lambda t: folk_idle(BONES, t))
    make_action(rig, "walk", 24, lambda t: folk_walk(BONES, t))
    make_action(rig, "run", 16, lambda t: folk_run(BONES, t))
    make_action(rig, "wave", 40, lambda t: folk_wave(BONES, t))
    make_action(rig, "cheer", 30, lambda t: folk_cheer(BONES, t))
    make_action(rig, "sit", 90, lambda t: folk_sit(BONES, t))
    rest_pose(rig)
    finish(OUT_DIR / f"garden_folk_{fid}.blend")


def _lower(spec, HIPS, TORSO, belt_z, leg, knee, s):
    """A skirt of hanging leaves from the belt (boys and girls), or for a dress a leaf top as well and longer leaves."""
    dress = spec["lower"] == "dress"
    if dress:
        # A wrapped top over the chest: a shell just outside the fur, cut above and below
        top = ellipsoid("Dress Top", TORSO.c, TORSO.r + Vector((0.004, 0.004, 0.002)) * s, "Leaf", ["spine", "chest"],
                        u=28, v=16, keep_below=0.62, keep_above=-0.55)
        ring_on("Dress Hem", TORSO, TORSO.c.z + TORSO.r.z * 0.6, 0.004 * s, 0.004 * s, "Leaf Dark", ["chest"], sides=6)
    length = (belt_z - knee + (0.02 if dress else -0.012) * s)
    for layer, (n, mat_, out, drop) in enumerate(((14, "Leaf Dark", 0.004, 1.0), (12, "Leaf", 0.009, 0.82))):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * layer) / n
            d = Vector((math.cos(a), math.sin(a), 0))
            root = HIPS.project(HIPS.c + d * 10 + Vector((0, 0, (belt_z - HIPS.c.z) * 10 / HIPS.r.z * HIPS.r.x)),
                                out * s)
            root.z = belt_z - 0.004 * s
            L = length * drop * (0.92 + 0.12 * ((k * 7) % 5) / 4)
            tip = root + d * 0.03 * s + Vector((0, 0, -L))
            mid = root + d * 0.018 * s + Vector((0, 0, -L * 0.5))
            side = "L" if d.x > 0 else "R"
            lock(f"Skirt Leaf.{layer}.{k}", [root, mid, tip], 0.02 * s, mat_,
                 ["hips", (f"thigh.{side}", 1.5)], flat=0.18, tip=0.002, taper=0.55,
                 normal_fn=lambda p, d=d: d)


def _head(spec, HEAD, hc, s):
    HB = ["head"]

    def v(x, y, z):
        return Vector((x * s, y * s, z * s))
    kind = spec["head"]
    if kind in ("wrap", "hood"):
        hood = kind == "hood"
        # Only over the top of the head: the face, cheeks and chin stay furry (bottom tucks the rest away)
        cap = scalp_cap("Wrap", HEAD, "Wrap", HB, thick=0.012 * s,
                        hairline=lambda x: hc.z + (0.03 if hood else 0.045) * s, u=48, v=24,
                        bottom=hc.z - (0.035 if hood else 0.0) * s)
        if not hood:
            # The wrap's folds: two rolled bands round it, and its two tails hanging down the back
            for k, z in enumerate((0.04, 0.068)):
                ring_on(f"Wrap Fold.{k}", HEAD, hc.z + z * s, 0.009 * s, 0.0065 * s, "Wrap", HB, sides=6)
            for k, sx in enumerate((-1, 1)):
                r = hc + v(0.035 * sx, 0.075, 0.01)
                lock(f"Wrap Tail.{k}", [r, r + v(0.012 * sx, 0.03, -0.05), r + v(0.02 * sx, 0.035, -0.11)], 0.024 * s,
                     "Wrap", ["head", "chest"], flat=0.18, tip=0.008, taper=0.4, normal_fn=lambda p: Vector((0, 1, 0)))
            # The feather, tucked in on the left and sweeping up and back
            f0 = hc + v(0.07, 0.03, 0.06)
            ctrl = [f0, f0 + v(0.03, 0.03, 0.06), f0 + v(0.05, 0.09, 0.12)]
            lock("Feather", ctrl, 0.024 * s, "Feather", HB, flat=0.12, tip=0.002, taper=0.45,
                 normal_fn=lambda p: Vector((1, 0, 0.3)).normalized())
            lock("Feather Quill", [c + v(0.001, 0, 0) for c in ctrl], 0.003 * s, "Linen", HB, flat=0.8, tip=0.001)
        else:
            # A leaf hood: the cap with a pointed leaf tip flopping over at the back and a vein down it
            top = HEAD.dir_point((0, 0.4, 1), 0.01 * s)
            lock("Hood Tip", [top, top + v(0, 0.03, 0.03), top + v(0.01, 0.07, 0.0), top + v(0.015, 0.09, -0.03)],
                 0.03 * s, "Wrap", HB, flat=0.5, tip=0.003, taper=0.6)
            ring_on("Hood Rim", HEAD, hc.z + 0.03 * s, 0.013 * s, 0.005 * s, "Leaf Dark", HB, sides=6)
    elif kind == "flowers":
        # A crown of seven five-petal flowers round the head, pink and white turn about
        for k in range(7):
            a = math.pi * (0.1 + 0.8 * k / 6)
            d = Vector((math.cos(a), 0.15 * math.sin(a) - 0.2, 0.75))
            c = HEAD.dir_point(Vector((math.cos(a), math.sin(a) * 0.6, 0.85)), 0.008 * s)
            n = HEAD.normal(c)
            col = "Wrap" if k % 2 == 0 else "Wrap Light"
            for p in range(5):
                b = 2 * math.pi * p / 5
                R = basis_facing(-n)
                off = R @ Vector((math.cos(b) * 0.011 * s, 0, math.sin(b) * 0.011 * s))
                off = R @ Vector((math.cos(b) * 0.015 * s, 0, math.sin(b) * 0.015 * s))
                ellipsoid(f"Petal.{k}.{p}", c + off, (0.012 * s, 0.004 * s, 0.012 * s), col, HB, rot=R, u=10, v=6)
            ellipsoid(f"Flower Heart.{k}", c + n * 0.004 * s, (0.007 * s, 0.007 * s, 0.006 * s), "Metal", HB, u=10, v=6)
        ring_on("Crown Vine", HEAD, hc.z + 0.058 * s, 0.006 * s, 0.003 * s, "Leaf Dark", HB, sides=6)
    elif kind == "acorn":
        # An acorn cap: a squat scaly cup on top, a stalk, and rings of scales
        cap_c = hc + v(0, 0.004, 0.05)
        ellipsoid("Acorn Cap", cap_c, (0.105 * s, 0.096 * s, 0.07 * s), "Wrap", HB, u=36, v=18, keep_above=0.0)
        for k in range(4):
            z = 0.012 + 0.014 * k
            rr = math.sqrt(max(0.0, 1 - (z / 0.07) ** 2))
            torus(f"Acorn Scales.{k}", cap_c + v(0, 0, z), 0.1 * s * rr, 0.004 * s, "Wrap Light", HB, u=36, v=6)
        capsule("Acorn Stalk", [cap_c + v(0, 0, 0.06), cap_c + v(0.01, 0.01, 0.09)], 0.008 * s, 0.006 * s,
                "Wrap", HB, steps=4, sides=8)
    elif kind == "mushroom":
        # A round red mushroom cap with white spots, tipped back a little
        cap_c = hc + v(0, 0.012, 0.06)
        tilt = Euler((math.radians(-10), 0, 0)).to_matrix()
        CAP = Ellipsoid(cap_c, (0.12 * s, 0.11 * s, 0.075 * s))
        ellipsoid("Mushroom Cap", cap_c, CAP.r, "Wrap", HB, rot=tilt, u=36, v=18, keep_above=-0.1)
        ellipsoid("Mushroom Gills", cap_c + v(0, 0, -0.004), (0.115 * s, 0.105 * s, 0.012 * s), "Wrap Light", HB,
                  rot=tilt, u=36, v=8)
        for k, (dx, dy, dz) in enumerate(((0, -0.3, 0.9), (0.6, -0.2, 0.6), (-0.6, 0.0, 0.6), (0.3, 0.5, 0.75),
                                          (-0.35, 0.5, 0.7), (0.0, 0.2, 1.0), (0.75, 0.45, 0.35), (-0.8, -0.4, 0.3))):
            p = CAP.dir_point((dx, dy, dz), 0.0)
            p = cap_c + tilt @ (p - cap_c)
            n = tilt @ CAP.normal(CAP.dir_point((dx, dy, dz)))
            ellipsoid(f"Mushroom Spot.{k}", p, (0.016 * s, 0.004 * s, 0.016 * s), "Wrap Light", HB,
                      rot=basis_facing(-n), u=12, v=6)
    # Girls: a flower behind the right ear, or two fluffy braids down the back
    hair = spec.get("hair")
    if hair == "flower":
        c = hc + v(-0.075, 0.02, 0.045)
        for p in range(5):
            b = 2 * math.pi * p / 5
            ellipsoid(f"Ear Flower Petal.{p}", c + v(-0.004, math.cos(b) * 0.014, math.sin(b) * 0.014),
                      (0.004 * s, 0.011 * s, 0.011 * s), "Leaf", HB, rot=Euler((b, 0, 0)), u=10, v=6)
        ellipsoid("Ear Flower Heart", c + v(-0.006, 0, 0), (0.005 * s, 0.006 * s, 0.006 * s), "Metal", HB, u=10, v=6)
    elif hair == "braids":
        for k, sx in enumerate((-1, 1)):
            r = hc + v(0.05 * sx, 0.06, -0.02)
            pts = [r + v(0.006 * sx, 0.012 * j, -0.022 * j) for j in range(6)]
            for j, p in enumerate(pts[:-1]):
                ellipsoid(f"Braid.{k}.{j}", p, (0.013 * s, 0.013 * s, 0.014 * s), "Fur Dark", ["head", "chest"],
                          u=12, v=8)
            torus(f"Braid Tie.{k}", pts[-1] + v(0, 0, 0.008), 0.009 * s, 0.003 * s, "Wrap", ["chest"], u=12, v=6)
            lock(f"Braid Tuft.{k}", [pts[-1] + v(0, 0, 0.006), pts[-1] + v(0.004 * sx, 0.006, -0.02)], 0.012 * s,
                 "Fur Dark", ["chest"], flat=0.7, tip=0.003)


def _gear(kind, TORSO, HIPS, WR, EL, s):
    def v(x, y, z):
        return Vector((x * s, y * s, z * s))
    if kind == "bow":
        # A bow in the left hand: a curved stave bulging out from the body, the grip wrapped in linen, a blue string
        hand = Vector(WR) + v(0.006, -0.014, -0.018)
        k, half = 0.04 * s, 0.2 * s
        pts = []
        for i in range(17):
            t = -1 + 2 * i / 16
            pts.append(hand + Vector((k * (1 - t * t) - k + 0.01 * s + 0.012 * s * abs(t) ** 3, 0,
                                      t * half)))
        rad = [((0.0085 - 0.0035 * abs(-1 + 2 * i / 16) ** 2) * s,) * 2 for i in range(17)]
        tube("Bow", pts, rad, "Bow Wood", ["hand.L"], sides=8)
        for j, z in enumerate((-0.12, 0.0, 0.12)):
            t = z / 0.2
            c = hand + Vector((k * (1 - t * t) - k + 0.01 * s, 0, z * s))
            cylinder(f"Bow Wrap.{j}", c - v(0, 0, 0.012), c + v(0, 0, 0.012), 0.0075 * s, "Linen", ["hand.L"], sides=8)
        tube("Bow String", [pts[0], pts[-1]], [(0.0012 * s, 0.0012 * s)] * 2, "String", ["hand.L"], sides=5)
        _quiver(TORSO, s)
    elif kind == "satchel":
        bag = HIPS.c + v(-0.06, -0.012, -0.005)
        ellipsoid("Satchel", bag, (0.022 * s, 0.03 * s, 0.026 * s), "Leather", ["hips", ("thigh.R", 2.0)], power=0.7,
                  u=16, v=10)
        ellipsoid("Satchel Flap", bag + v(-0.008, -0.004, 0.012), (0.018 * s, 0.03 * s, 0.016 * s), "Leather Dark",
                  ["hips"], power=0.7, u=16, v=8)
        ellipsoid("Satchel Button", bag + v(-0.025, -0.004, 0.006), (0.004 * s,) * 3, "Metal", ["hips"], u=8, v=6)
        # A sprig of leaves peeking out the top
        lock("Satchel Sprig", [bag + v(0, 0.01, 0.02), bag + v(0.004, 0.016, 0.05)], 0.01 * s, "Leaf", ["hips"],
             flat=0.3, tip=0.002)
    elif kind == "staff":
        # A crooked walking stick in the right hand, a curl at the top with a leaf
        hand = Vector((-WR[0], WR[1], WR[2])) + v(-0.004, -0.014, -0.016)
        ctrl = [hand + v(0, 0, -0.17), hand + v(-0.004, 0, -0.06), hand + v(0.004, 0, 0.08), hand + v(0, 0, 0.2),
                hand + v(0.025, 0, 0.235), hand + v(0.035, 0, 0.21)]
        lock("Staff", ctrl, 0.008 * s, "Bow Wood", ["hand.R"], flat=1.0, tip=0.004, taper=0.3, sides=8)
        lock("Staff Leaf", [hand + v(0.03, 0, 0.215), hand + v(0.055, -0.005, 0.2), hand + v(0.07, -0.006, 0.17)],
             0.014 * s, "Leaf", ["hand.R"], flat=0.2, tip=0.002, normal_fn=lambda p: Vector((0, 1, 0)))
        ellipsoid("Staff Gem", hand + v(0.012, 0, 0.24), (0.008 * s,) * 3, "Gem", ["hand.R"], u=10, v=6)


def _quiver(TORSO, s):
    def v(x, y, z):
        return Vector((x * s, y * s, z * s))
    base = v(-0.03, 0.07, 0.235)
    top = v(0.04, 0.075, 0.37)
    d = (top - base).normalized()
    tube("Quiver", [base, top], [(0.02 * s, 0.017 * s), (0.023 * s, 0.019 * s)], "Leather", ["chest", "spine"],
         sides=12)
    torus("Quiver Rim", top, 0.023 * s, 0.004 * s, "Leather Dark", ["chest"], u=14, v=6,
          rot=d.to_track_quat('Z', 'Y').to_matrix())
    torus("Quiver Band", base + (top - base) * 0.3, 0.021 * s, 0.003 * s, "Leather Dark", ["chest", "spine"], u=14,
          v=6, rot=d.to_track_quat('Z', 'Y').to_matrix())
    for k, (dx, dy) in enumerate(((-0.007, 0.0), (0.006, -0.004), (0.0, 0.007))):
        a0 = top + v(dx, dy, -0.02)
        a1 = a0 + d * 0.07 * s + v(dx * 0.8, 0, 0)
        cylinder(f"Arrow.{k}", a0, a1, 0.0022 * s, "Bow Wood", ["chest"], sides=6)
        for j, n in enumerate((Vector((1, 0, 0)), Vector((0, 1, 0)))):
            lock(f"Fletching.{k}.{j}", [a1 - d * 0.03 * s, a1 - d * 0.012 * s, a1 + d * 0.004 * s], 0.008 * s,
                 "Feather", ["chest"], flat=0.12, tip=0.002, taper=0.3, normal_fn=lambda p, n=n: n)


# =============================================================================
# Animations: light on their feet, bouncy
# =============================================================================
def _arms(p, l=(), r=(), bend=0.25):
    p.rel("upper_arm.L", (Y, 0.25), *l)
    p.rel("upper_arm.R", (Y, -0.25), *r)
    p.rel("forearm.L", (X, -bend))
    p.rel("forearm.R", (X, -bend))


def folk_idle(bones, t):
    ph = 2 * math.pi * t
    s = math.sin(ph)
    p = Pose(bones)
    _arms(p, [(Y, 0.03 * s)], [(Y, -0.03 * s)])
    p.rel("spine", (X, 0.015 * s))
    # Looks about the garden: one way, the other, and up at the trees
    look = math.sin(ph) * 0.35
    up = 0.15 * max(0.0, math.sin(2 * ph + 1.0)) ** 2
    p.rel("head", (Z, look), (X, -up), (Y, 0.05 * math.sin(2 * ph)))
    p.offset = Vector((0, 0, 0.003 * math.sin(2 * ph)))
    return p


def folk_walk(bones, t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(bones)
    p.rel("thigh.L", (X, -0.5 * s))
    p.rel("thigh.R", (X, 0.5 * s))
    p.rel("shin.L", (X, 0.1 + 0.6 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.1 + 0.6 * max(0.0, c)))
    _arms(p, [(X, 0.4 * s)], [(X, -0.4 * s)], bend=0.3)
    p.rel("hips", (Z, 0.08 * s))
    p.rel("spine", (X, 0.04), (Z, -0.06 * s))
    p.rel("head", (Z, 0.04 * s))
    p.offset = Vector((0, 0, 0.01 * abs(s)))
    return p


def folk_run(bones, t):
    ph = 2 * math.pi * t
    s, c = math.sin(ph), math.cos(ph)
    p = Pose(bones)
    p.rel("thigh.L", (X, -0.85 * s))
    p.rel("thigh.R", (X, 0.85 * s))
    p.rel("shin.L", (X, 0.25 + 0.9 * max(0.0, -c)))
    p.rel("shin.R", (X, 0.25 + 0.9 * max(0.0, c)))
    _arms(p, [(X, 0.8 * s)], [(X, -0.8 * s)], bend=0.9)
    p.rel("spine", (X, 0.2))
    p.rel("head", (X, -0.15))
    p.offset = Vector((0, 0, 0.022 * abs(s)))
    return p


def folk_wave(bones, t):
    ph = 2 * math.pi * t
    s = math.sin(2 * ph)
    p = Pose(bones)
    p.rel("upper_arm.L", (Y, 0.25))
    p.rel("forearm.L", (X, -0.25))
    p.rel("upper_arm.R", (Y, 2.2), (X, -0.3))             # the right hand up high, waving
    p.rel("forearm.R", (Y, 0.5 * s))
    p.rel("spine", (Z, 0.05 * s))
    p.rel("head", (Y, -0.12), (Z, 0.08 * s))
    p.offset = Vector((0, 0, 0.006 * abs(math.sin(ph))))
    return p


def folk_cheer(bones, t):
    # A happy hop with both arms up
    ph = 2 * math.pi * t
    up = max(0.0, math.sin(ph))
    p = Pose(bones)
    p.rel("upper_arm.L", (Y, -2.3 + 0.2 * up))
    p.rel("upper_arm.R", (Y, 2.3 - 0.2 * up))
    p.rel("forearm.L", (X, -0.2))
    p.rel("forearm.R", (X, -0.2))
    p.rel("thigh.L", (X, -0.25 * up))
    p.rel("thigh.R", (X, -0.25 * up))
    p.rel("shin.L", (X, 0.5 * up))
    p.rel("shin.R", (X, 0.5 * up))
    p.rel("head", (X, -0.2 * up))
    p.offset = Vector((0, 0, 0.06 * up * bones["thigh.L"][0][2] / 0.21))
    return p


def folk_sit(bones, t):
    s = math.sin(2 * math.pi * t)
    p = Pose(bones)
    leg = bones["thigh.L"][0][2]
    p.offset = Vector((0, 0, -leg * 0.86))
    p.rel("thigh.L", (X, -1.5), (Y, 0.15))
    p.rel("thigh.R", (X, -1.5), (Y, -0.15))
    p.rel("shin.L", (X, 1.2 + 0.08 * s))
    p.rel("shin.R", (X, 1.2 - 0.08 * s))
    _arms(p, [(X, -0.3)], [(X, -0.3)], bend=0.6)
    p.rel("spine", (X, 0.05 * s))
    p.rel("head", (Z, 0.2 * math.sin(4 * math.pi * t)), (X, -0.05))
    return p


only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for fid, spec in FOLK.items():
    if not only or fid in only:
        build(fid, spec)

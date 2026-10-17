# Builds the green man (a little bendy-toy alien) from scratch: model, materials, rig, weights and animations.
# Reference: Hayden's photo of the toy: shiny bright green all over, a big upside-down-egg head with a pointed chin,
# huge slanted black eyes, a tiny smile, a thin neck, a slim body, long thin arms with splayed fingers, flat feet.
#
#   blender -b --python tools\build_green_man.py
#
# Writes source_art/characters/green_man.blend (overwrites it). Units are meters; feet at the origin;
# he faces -Y. Shared helpers live in tools/char_kit.py.

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "green_man.blend"

K.begin()

# =============================================================================
# Materials (linear colors): one glossy rubbery green, black eyes
# =============================================================================
mat("Green", (0.06, 0.52, 0.04), rough=0.28)
mat("Green Dark", (0.025, 0.25, 0.02), rough=0.35)
mat("Eye", (0.006, 0.008, 0.006), rough=0.08)
mat("Eye Shine", (1.0, 1.0, 1.0), rough=0.05, emit=1.2)
mat("Mouth", (0.01, 0.03, 0.01), rough=0.4)

HB = ["head"]


class TaperHead(Ellipsoid):
    """An ellipsoid whose lower half narrows to a pointed chin (the classic alien head)."""

    def __init__(self, c, r, chin=0.3):
        super().__init__(c, r)
        self.chin = chin

    def f(self, z):
        u = (z - self.c.z) / self.r.z                       # -1 at the chin, 1 at the top
        return 1.0 - (1.0 - self.chin) * ss(0.15, -1.0, u) ** 0.8

    def front(self, x, z, offset=0.0):
        f = self.f(z)
        k = 1 - ((x - self.c.x) / (self.r.x * f)) ** 2 - ((z - self.c.z) / self.r.z) ** 2
        s = Vector((x, self.c.y - self.r.y * f * math.sqrt(max(k, 0.0)), z))
        return s + self.normal(s) * offset


HEAD = TaperHead((0, 0, 1.12), (0.205, 0.19, 0.27), chin=0.36)
TORSO = Ellipsoid((0, 0, 0.60), (0.12, 0.088, 0.225))

# =============================================================================
# Head and face
# =============================================================================
head = ellipsoid("Head", HEAD.c, HEAD.r, "Green", HB, u=48, v=32)
for vt in head.data.vertices:
    f = HEAD.f(vt.co.z)
    vt.co.x *= f
    vt.co.y *= f

for sx, side in ((1, "L"), (-1, "R")):
    ec = HEAD.front(0.092 * sx, 1.115, offset=-0.004)
    n = HEAD.normal(ec)
    tilt = Matrix.Rotation(math.radians(-32 * sx), 3, 'Y')   # outer corners up
    ellipsoid(f"Eye.{side}", ec, (0.092, 0.02, 0.05), "Eye", HB, rot=basis_facing(n) @ tilt)
    sp = HEAD.front(0.075 * sx, 1.145, offset=0.014)
    ellipsoid(f"Eye Shine.{side}", sp, (0.012, 0.004, 0.008), "Eye Shine", HB, rot=basis_facing(HEAD.normal(sp)),
              u=12, v=6)
    nz = HEAD.front(0.013 * sx, 0.985, offset=0.0)
    ellipsoid(f"Nostril.{side}", nz, (0.004, 0.003, 0.003), "Mouth", HB)

arc_on(HEAD, "Mouth", [(-0.032 + 0.064 * i / 8, 0.938 + 9.0 * (-0.032 + 0.064 * i / 8) ** 2) for i in range(9)],
       0.006, "Mouth", HB, offset=0.002)

# =============================================================================
# Body: thin neck, slim torso, long thin arms with splayed fingers, legs with flat feet
# =============================================================================
capsule("Neck", [(0, 0, 0.77), (0, 0.0, 0.93)], 0.046, 0.04, "Green", ["chest", "head"])
ellipsoid("Torso", TORSO.c, TORSO.r, "Green", ["hips", "spine", "chest", ("thigh.L", 1.8), ("thigh.R", 1.8)],
          u=48, v=24)
ellipsoid("Pelvis", (0, 0, 0.45), (0.11, 0.08, 0.09), "Green", ["hips", ("thigh.L", 1.5), ("thigh.R", 1.5)])
# The faint moulding line down his chest
tube("Chest Line", [TORSO.front(0.0, z, 0.0) for z in (0.74, 0.70, 0.66, 0.62)], [(0.004, 0.002)] * 4, "Green Dark",
     ["spine", "chest"], sides=6, normal_fn=TORSO.normal)

SH, EL, WR, TIP = (0.105, 0, 0.765), (0.20, -0.02, 0.61), (0.285, -0.035, 0.48), (0.32, -0.045, 0.39)
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda p: Vector((p[0] * sx, p[1], p[2]))
    sh, el, wr = m(SH), m(EL), m(WR)
    capsule(f"Arm.{side}", [sh, el, wr], 0.038, 0.03, "Green", [f"upper_arm.{side}", f"forearm.{side}"])
    d = (wr - el).normalized()
    palm = wr + d * 0.03
    ellipsoid(f"Palm.{side}", palm, (0.03, 0.016, 0.036), "Green", [f"hand.{side}"],
              rot=d.to_track_quat('-Z', 'Y').to_matrix())
    # Four long fingers fanning out, and a thumb pointing forward-out
    for j, (spread, length) in enumerate(((-0.55, 0.075), (-0.18, 0.09), (0.18, 0.085), (0.55, 0.07))):
        fd = (d + Vector((sx * spread * 0.9, 0, 0))).normalized()
        base = palm + d * 0.025 + Vector((sx * spread * 0.035, -0.002, 0))
        capsule(f"Finger.{side}{j}", [base, base + fd * length], 0.011, 0.008, "Green", [f"hand.{side}"],
                steps=4, sides=10)
    tb = palm + Vector((0, -0.02, 0.01))
    capsule(f"Thumb.{side}", [tb, tb + Vector((0.035 * sx, -0.04, -0.02))], 0.011, 0.009, "Green", [f"hand.{side}"],
            steps=4, sides=10)

for sx, side in ((1, "L"), (-1, "R")):
    x = 0.07 * sx
    capsule(f"Leg.{side}", [(x, 0, 0.47), (x * 1.05, -0.01, 0.28), (x * 1.1, 0, 0.09)], 0.056, 0.04, "Green",
            [f"thigh.{side}", f"shin.{side}", (f"foot.{side}", 1.5)])
    toe = Vector((x * 1.35, -0.12, 0.022))
    capsule(f"Foot.{side}", [(x * 1.1, 0.015, 0.035), toe], 0.04, 0.026, "Green", [f"foot.{side}"])
    ellipsoid(f"Sole.{side}", (x * 1.2, -0.045, 0.018), (0.05, 0.1, 0.018), "Green", [f"foot.{side}"],
              rot=Euler((0, 0, math.radians(-10 * sx))).to_matrix())

# =============================================================================
# Rig, skin, animations
# =============================================================================
BONES = biped_bones(hips=0.46, chest=0.70, neck=0.84, head_top=1.39, shoulder=SH, elbow=EL, wrist=WR, hand_tip=TIP,
                    hip_x=0.07, knee=0.28, ankle=0.09, toe=(-0.12, 0.03))
rig = build_rig("GreenManRig", BONES)
skin_and_join(rig, BONES, "GreenMan", "Torso")

make_action(rig, "idle", 72, lambda t: biped_idle(BONES, t, sway=1.4))
make_action(rig, "walk", 32, lambda t: biped_walk(BONES, t))
make_action(rig, "run", 20, lambda t: biped_run(BONES, t))
rest_pose(rig)
finish(OUT)

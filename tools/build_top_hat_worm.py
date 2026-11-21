# Builds the top-hat worm from Hayden's drawing (Nov 21, 2026; a copy is in
# source_art/reference/Top hat worm - drawing.jpg): a long, round, bright pink worm with dark red stripes all the way
# along him, a little smiley face (two dot eyes and a curved smile) near the top, and a tall black top hat with a gold
# buckle on its band. His arms and legs are drawn as dotted lines, so here they are strings of little black beads on a
# thin black thread, with small round mitten hands and feet. He stands up from a bend like a letter L: the back half
# of him lies along the ground behind and the front half rises up to his face.
#
# His body is a chain of bones (hips, spine, chest, neck, head up; tail1-5 back along the ground), the way a snake or a
# tentacle is rigged. Before writing it we read open-source worm and snake work (Hayden's rule):
# muratkamci/snakey-locomotion (MIT: a body as a chain of segments, each turned a little later than the one before,
# so a wave runs along it), quecot/procedural-animals (MIT: a chain that keeps its segment lengths) and
# daim1993/blender-tail-control-rig (an FK bone chain for tails). Ideas only, no code copied: every action here turns
# each link of the chain by the same wave with a delay down the chain.
#
#   blender -b --python tools\build_top_hat_worm.py
#
# Writes source_art/characters/top_hat_worm.blend (overwrites it) with idle / walk / run / jump / fall / dance /
# tip_hat actions. Units are meters; the bend sits on the ground at the origin; he faces -Y. Helpers: tools/char_kit.py.
# With his hat on he's about 1.3 m tall, a little shorter than the kids (1.45 m).

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_kit import *   # noqa: E402,F401,F403
import char_kit as K      # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "source_art" / "characters" / "top_hat_worm.blend"

K.begin()

# =============================================================================
# Materials (linear colours picked from the drawing)
# =============================================================================
mat("Worm", (0.78, 0.12, 0.55), rough=0.45)           # the bright magenta-pink felt pen
mat("Worm Belly", (0.90, 0.32, 0.66), rough=0.5)      # a lighter streak where the pen went over it less
mat("Stripe", (0.36, 0.02, 0.07), rough=0.5)          # the dark red rings
mat("Ink", (0.012, 0.010, 0.012), rough=0.5)          # the black outline pen: face, beads, hands
mat("Hat", (0.015, 0.014, 0.018), rough=0.35)
mat("Hat Band", (0.05, 0.04, 0.06), rough=0.6)
mat("Buckle", (1.0, 0.52, 0.06), rough=0.3, metal=0.6)
mat("Blush", (0.95, 0.30, 0.45), rough=0.7)
mat("Mouth", (0.10, 0.01, 0.02))
mat("Tongue", (0.85, 0.25, 0.35))
eye_materials((0.05, 0.03, 0.02), (0.18, 0.10, 0.05))   # big warm brown eyes

R_BODY = 0.115           # how fat he is
BEND = Vector((0, 0, R_BODY))


# =============================================================================
# The bone chain: up from the bend to his head, and back along the ground to the tip of his tail
# =============================================================================
UP = [(0, 0.0, R_BODY), (0, 0.0, 0.34), (0, -0.01, 0.55), (0, -0.005, 0.74), (0, 0.01, 0.88), (0, 0.02, 1.02)]
# Hayden (Nov 21): "the tail end needs to be much longer": about 1.4 m of tail behind him, curling up at the tip
BACK = [(0, 0.0, R_BODY), (0, 0.28, R_BODY), (0, 0.58, R_BODY), (0, 0.88, R_BODY + 0.003), (0, 1.15, R_BODY + 0.02),
        (0, 1.38, R_BODY + 0.13)]
BONES = {"root": ((0, 0, 0), (0, 0, 0.25), None)}
for name, a, b, parent in (("hips", UP[0], UP[1], "root"), ("spine", UP[1], UP[2], "hips"),
                           ("chest", UP[2], UP[3], "spine"), ("neck", UP[3], UP[4], "chest"),
                           ("head", UP[4], UP[5], "neck"),
                           ("tail1", BACK[0], BACK[1], "hips"), ("tail2", BACK[1], BACK[2], "tail1"),
                           ("tail3", BACK[2], BACK[3], "tail2"), ("tail4", BACK[3], BACK[4], "tail3"),
                           ("tail5", BACK[4], BACK[5], "tail4")):
    BONES[name] = (a, b, parent)
CHAIN_UP = ["hips", "spine", "chest", "neck", "head"]
CHAIN_BACK = ["tail1", "tail2", "tail3", "tail4", "tail5"]
BODY_BONES = CHAIN_UP + CHAIN_BACK

# The hat has its own bone, so he can tip it
HAT_BASE = Vector((0.0, 0.03, 1.115))
BONES["hat"] = (tuple(HAT_BASE), tuple(HAT_BASE + Vector((0, 0, 0.2))), "head")

# Dotted arms come out of his sides a little below his face, dotted legs out of the bend
SH, EL, WR, TIP = (0.105, -0.01, 0.60), (0.24, -0.03, 0.50), (0.35, -0.05, 0.42), (0.40, -0.06, 0.38)
HIP, KNEE, ANKLE, TOE = (0.10, -0.03, 0.17), (0.2, -0.07, 0.13), (0.26, -0.09, 0.045), (0.27, -0.17, 0.03)
for sx, side in ((1, "L"), (-1, "R")):
    m = lambda p: (p[0] * sx, p[1], p[2])
    BONES.update({
        f"upper_arm.{side}": (m(SH), m(EL), "chest"),
        f"forearm.{side}": (m(EL), m(WR), f"upper_arm.{side}"),
        f"hand.{side}": (m(WR), m(TIP), f"forearm.{side}"),
        f"thigh.{side}": (m(HIP), m(KNEE), "hips"),
        f"shin.{side}": (m(KNEE), m(ANKLE), f"thigh.{side}"),
        f"foot.{side}": (m(ANKLE), m(TOE), f"shin.{side}"),
    })


# =============================================================================
# The body: one smooth round tube from the tail tip, along the ground, round the bend and up to a round head
# =============================================================================
ctrl = [(0, 1.43, R_BODY + 0.17), (0, 1.36, R_BODY + 0.08), (0, 1.2, R_BODY + 0.02), (0, 0.98, R_BODY),
        (0, 0.72, R_BODY), (0, 0.46, R_BODY), (0, 0.2, R_BODY),
        (0, 0.05, R_BODY + 0.01), (0, -0.005, 0.2), (0, -0.01, 0.38), (0, -0.01, 0.58), (0, 0.0, 0.78),
        (0, 0.015, 0.92), (0, 0.02, 1.0)]
PATH = smooth_path(ctrl, per_segment=10)
lens = [0.0]
for a, b in zip(PATH, PATH[1:]):
    lens.append(lens[-1] + (b - a).length)
TOTAL = lens[-1]


def body_r(s):
    """Radius along the worm (s from the tail tip 0 to the head 1): a blunt tapered tail, full in the middle,
    the head end a touch fatter than the neck, like the drawing."""
    tail = ss(0.0, 0.2, s)
    return R_BODY * (0.55 + 0.45 * tail) * (1.0 + 0.06 * ss(0.8, 1.0, s))


rad = [(body_r(L / TOTAL),) * 2 for L in lens]
# Round the ends off: a half-sphere cap on the head and the tail tip
def cap(p, d, r, flip):
    pts, rr = [], []
    for k in range(1, 9):
        a = k / 8 * math.pi / 2
        pts.append(p + d * (math.sin(a) * r))
        rr.append((max(r * math.cos(a), 0.003),) * 2)
    return (pts[::-1], rr[::-1]) if flip else (pts, rr)


tail_dir = (PATH[0] - PATH[1]).normalized()
head_dir = (PATH[-1] - PATH[-2]).normalized()
tp, tr = cap(PATH[0], tail_dir, rad[0][0], True)
hp, hr = cap(PATH[-1], head_dir, rad[-1][0], False)
body = tube("Body", tp + PATH + hp, tr + rad + hr, "Worm", BODY_BONES, sides=28)


def along(s):
    """Point, direction and radius at fraction s along the body (tail tip 0, top of the head 1)."""
    target = s * TOTAL
    for i in range(1, len(lens)):
        if lens[i] >= target:
            t = (target - lens[i - 1]) / max(lens[i] - lens[i - 1], 1e-9)
            return PATH[i - 1].lerp(PATH[i], t), (PATH[i] - PATH[i - 1]).normalized(), body_r(s)
    return PATH[-1], head_dir, body_r(1.0)


# The dark red stripes: thin rings all round him, from the tail tip up to just under his face
# (painted on: half sunk into the skin, so they read as stripes, not hoops)
n_stripes = 44
for k in range(n_stripes):
    s = 0.04 + 0.86 * k / (n_stripes - 1)
    p, d, r = along(s)
    torus(f"Stripe.{k}", p, r - 0.001, 0.0055, "Stripe", BODY_BONES, u=40, v=6,
          rot=d.to_track_quat('Z', 'Y').to_matrix())
# A lighter streak down his front (the drawing's pen is lighter there), on the upright part only
streak = []
for k in range(60):
    p, d, r = along(k / 59)
    if 0.3 < p.z < 0.86 and p.y < 0.05:
        streak.append(p + Vector((0, -1, 0)) * (r - 0.012))
tube("Belly", streak, [(0.035, 0.016)] * len(streak), "Worm Belly", BODY_BONES, sides=10,
     normal_fn=lambda p: Vector((0, -1, 0)))

# =============================================================================
# The face (Hayden: "his face should be more expressive"): big shiny cartoon eyes with sparkles, eyebrows raised
# high and happy, a wide open grin with a tongue, and pink cheeks
# =============================================================================
class WormFace:
    """The front of his head end, as it's really built: a straight tube below the top of the path (z 1.0) and the
    round cap above it, so everything drawn on the face sits right on the skin instead of sinking under it."""
    TOP = 1.0
    MID_Y = 0.012
    R = R_BODY * 1.08

    def _centre(self, z):
        return Vector((0, self.MID_Y, min(z, self.TOP)))

    def front(self, x, z, offset=0.0):
        c = self._centre(z)
        dz = max(z - self.TOP, 0.0)
        k = self.R * self.R - x * x - dz * dz
        s = Vector((x, c.y - math.sqrt(max(k, 0.0)), z))
        return s + self.normal(s) * offset

    def normal(self, s):
        s = Vector(s)
        d = s - self._centre(s.z)
        return d.normalized()


HEAD = WormFace()
HB = ["head"]
for sx, side in ((1, "L"), (-1, "R")):
    ec = HEAD.front(0.043 * sx, 1.0, offset=-0.008)
    cartoon_eye(side, ec, (0.03, 0.022, 0.04), HB, look=(-0.003 * sx, 0.002))
    arc_on(HEAD, f"Brow.{side}", [(sx * (0.018 + 0.05 * t), 1.055 + 0.016 * math.sin(math.pi * (0.2 + 0.7 * t)) - 0.01 * t)
                                  for t in (i / 8 for i in range(9))], 0.008, "Ink", HB, offset=0.004)
    bc = HEAD.front(0.078 * sx, 0.95, offset=0.001)
    ellipsoid(f"Blush.{side}", bc, (0.022, 0.004, 0.013), "Blush", HB, rot=basis_facing(HEAD.normal(bc)))
smile("Grin", HEAD, 0.0, 0.935, 0.058, 0.045, HB, curl=0.014, offset=0.003)

# =============================================================================
# The top hat: a wide flat brim, a tall crown that's a little wider at the top, a band and a gold buckle
# =============================================================================
TB = ["hat"]
hat_tilt = Euler((math.radians(-6), math.radians(8), 0)).to_matrix()
def hat_pt(x, y, z):
    return HAT_BASE + hat_tilt @ Vector((x, y, z))


brim = ellipsoid("Hat Brim", (0, 0, 0), (0.17, 0.165, 0.012), "Hat", TB, u=40, v=8, power=0.6)
brim.data.transform(Matrix.Translation(HAT_BASE) @ hat_tilt.to_4x4())
crown_rings = [(0.0, 0.098), (0.02, 0.1), (0.14, 0.106), (0.215, 0.112), (0.225, 0.11)]
crown = tube("Hat Crown", [hat_pt(0, 0, z) for z, _ in crown_rings], [(r, r) for _, r in crown_rings], "Hat", TB,
             sides=36)
band_rings = [(0.012, 0.102), (0.055, 0.103)]
tube("Hat Band", [hat_pt(0, 0, z) for z, _ in band_rings], [(r, r) for _, r in band_rings], "Hat Band", TB, sides=36,
     caps=False)
bk = hat_pt(0, -0.104, 0.034)
ellipsoid("Buckle", bk, (0.022, 0.006, 0.02), "Buckle", TB, rot=hat_tilt @ basis_facing(Vector((0, -1, 0))), power=0.35)
ellipsoid("Buckle Hole", bk + hat_tilt @ Vector((0, -0.004, 0)), (0.009, 0.004, 0.011), "Hat Band", TB,
          rot=hat_tilt @ basis_facing(Vector((0, -1, 0))), power=0.35)


# =============================================================================
# Dotted arms and legs: beads on a thread, like the drawing's dotted lines, with round mittens and little feet
# =============================================================================
def dotted(name, pts, bones, bead=0.016, gap=0.038):
    path = smooth_path(pts, per_segment=8)
    tube(f"{name} Thread", path, [(0.0045, 0.0045)] * len(path), "Ink", bones, sides=6)
    acc, last = 0.0, path[0]
    k = 0
    for p in path[1:]:
        acc += (p - last).length
        last = p
        if acc >= gap:
            acc = 0.0
            ellipsoid(f"{name} Dot.{k}", p, (bead, bead, bead), "Ink", bones, u=10, v=6)
            k += 1


for sx, side in ((1, "L"), (-1, "R")):
    m = lambda p: Vector((p[0] * sx, p[1], p[2]))
    sh, el, wr, tip = m(SH), m(EL), m(WR), m(TIP)
    dotted(f"Arm.{side}", [sh + Vector((-0.02 * sx, 0, 0)), sh.lerp(el, 0.5) + Vector((0, 0, 0.012)), el,
                           el.lerp(wr, 0.5), wr], [f"upper_arm.{side}", f"forearm.{side}", ("chest", 2.0)])
    # A round mitten with three little fingers, like the curled hand at the top of the drawing
    hd = (tip - wr).normalized()
    palm = wr + hd * 0.035
    ellipsoid(f"Hand.{side}", palm, (0.03, 0.022, 0.032), "Ink", [f"hand.{side}"], rot=hd.to_track_quat('-Z', 'Y').to_matrix())
    for j in range(3):
        fp = palm + hd * 0.038 + Vector(((j - 1) * 0.016 * sx, -0.006, (1 - abs(j - 1)) * 0.004))
        ellipsoid(f"Finger.{side}{j}", fp, (0.009, 0.009, 0.016), "Ink", [f"hand.{side}"],
                  rot=hd.to_track_quat('-Z', 'Y').to_matrix())
    ellipsoid(f"Thumb.{side}", palm + Vector((-0.01 * sx, -0.03, 0.012)), (0.01, 0.014, 0.01), "Ink", [f"hand.{side}"])

    hip, knee, ankle, toe = m(HIP), m(KNEE), m(ANKLE), m(TOE)
    dotted(f"Leg.{side}", [hip, hip.lerp(knee, 0.5) + Vector((0, 0, 0.015)), knee, knee.lerp(ankle, 0.5), ankle],
           [f"thigh.{side}", f"shin.{side}", ("hips", 2.0)])
    # A little rounded foot like a sock, pointing forward
    fd = (toe - ankle).normalized()
    ellipsoid(f"Foot.{side}", ankle.lerp(toe, 0.55) + Vector((0, 0, -0.005)), (0.034, 0.06, 0.024), "Ink",
              [f"foot.{side}"], rot=fd.to_track_quat('-Y', 'Z').to_matrix())


# =============================================================================
# Rig, skin, animations
# =============================================================================
rig = build_rig("WormRig", BONES)
skin_and_join(rig, BONES, "TopHatWorm", "Body")


def wave(p, t, amount=1.0, side=0.0, fwd=0.0, back=0.0, speed=1.0, phase=0.0):
    """A wave running up his body (each link turns the same way a little after the one below, so it travels up)
    and back along his tail. side: sway left/right, fwd: bob forward/back, back: lift and drop the tail."""
    for i, b in enumerate(CHAIN_UP):
        ph = 2 * math.pi * (t * speed) - 0.9 * i + phase
        p.rel(b, (Y, side * amount * math.sin(ph)), (X, fwd * amount * math.sin(ph + 1.2)))
    for i, b in enumerate(CHAIN_BACK):
        ph = 2 * math.pi * (t * speed) - 0.9 * (i + 1) + phase
        p.rel(b, (Z, side * 1.5 * amount * math.sin(ph)), (X, -back * amount * math.sin(ph)))


def arms_rest(p, swing=0.0, lift=0.0):
    p.rel("upper_arm.L", (Y, 0.35 - lift), (X, swing))
    p.rel("upper_arm.R", (Y, -0.35 + lift), (X, -swing))
    p.rel("forearm.L", (X, -0.35))
    p.rel("forearm.R", (X, -0.35))


def legs_rest(p, kick_l=0.0, kick_r=0.0):
    p.rel("thigh.L", (X, -kick_l))
    p.rel("thigh.R", (X, -kick_r))
    p.rel("shin.L", (X, 0.5 * max(kick_l, 0.0)))
    p.rel("shin.R", (X, 0.5 * max(kick_r, 0.0)))


def idle(t):
    # Happy and bouncy: a slow wave sways up him, his arms swing a little and his hat wobbles
    p = Pose(BONES)
    wave(p, t, 1.0, side=0.06, fwd=0.03, back=0.05)
    arms_rest(p, 0.12 * math.sin(2 * math.pi * t))
    legs_rest(p, 0.08 * math.sin(2 * math.pi * t), -0.08 * math.sin(2 * math.pi * t))
    p.rel("hat", (Y, 0.05 * math.sin(2 * math.pi * t - 2.0)))
    p.offset = Vector((0, 0, 0.008 * abs(math.sin(2 * math.pi * t))))
    return p


def walk(t):
    # A wiggly inch along: the wave runs up him twice a step, his dotted legs step and his arms swing
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    wave(p, t, 1.0, side=0.09, fwd=0.05, back=0.12, speed=2.0)
    arms_rest(p, 0.4 * s)
    legs_rest(p, 0.45 * s, -0.45 * s)
    p.rel("hat", (Y, 0.06 * math.sin(4 * math.pi * t - 2.0)))
    p.offset = Vector((0, 0, 0.02 * abs(s)))
    return p


def run(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    wave(p, t, 1.0, side=0.12, fwd=0.08, back=0.2, speed=2.0)
    for i, b in enumerate(CHAIN_UP[1:]):
        p.spec[b] = p.spec[b] + [(X, 0.05)]                # leaning into it
    arms_rest(p, 0.8 * s, 0.2)
    p.rel("forearm.L", (X, -0.9))
    p.rel("forearm.R", (X, -0.9))
    legs_rest(p, 0.7 * s, -0.7 * s)
    p.offset = Vector((0, 0, 0.04 * abs(s)))
    return p


def jump(t):
    # He springs straight up out of the bend: the tail flicks down, arms fly up, hat stays on (just)
    k = ss(0, 1, t)
    p = Pose(BONES)
    p.rel("tail1", (X, 0.35 * k))
    p.rel("tail2", (X, 0.3 * k))
    p.rel("tail3", (X, 0.25 * k))
    p.rel("spine", (X, -0.06 * k))
    p.rel("upper_arm.L", (Y, 0.35 - 1.6 * k))
    p.rel("upper_arm.R", (Y, -0.35 + 1.6 * k))
    legs_rest(p, -0.4 * k, -0.4 * k)
    p.rel("hat", (X, 0.12 * k))
    return p


def fall(t):
    s = math.sin(2 * math.pi * t)
    p = Pose(BONES)
    wave(p, t, 1.0, side=0.08, fwd=0.03, back=0.0, speed=2.0)
    p.rel("tail1", (X, -0.25))
    p.rel("tail2", (X, -0.2 + 0.1 * s))
    p.rel("upper_arm.L", (Y, -1.1 + 0.2 * s))
    p.rel("upper_arm.R", (Y, 1.1 + 0.2 * s))
    legs_rest(p, 0.3 + 0.2 * s, 0.3 - 0.2 * s)
    p.rel("hat", (X, 0.18))
    return p


def dance(t):
    # The drawing's pose, danced: his right arm curls up over his head, his left stays low, he leans and wiggles,
    # and his dotted legs kick out in turn on the beat
    ph = 2 * math.pi * t
    s = math.sin(ph)
    b = abs(math.sin(2 * ph))
    p = Pose(BONES)
    wave(p, t, 1.0, side=0.14, fwd=0.05, back=0.25, speed=2.0)
    p.spec["spine"] = p.spec["spine"] + [(Y, -0.12)]
    p.rel("upper_arm.R", (Y, 1.75 + 0.15 * s), (X, -0.2))
    p.rel("forearm.R", (Y, 0.9), (X, -0.4))
    p.rel("hand.R", (Y, 0.6))
    p.rel("upper_arm.L", (Y, 0.55 + 0.25 * s), (X, 0.25 * s))
    p.rel("forearm.L", (X, -0.6))
    legs_rest(p, 0.9 * max(0.0, s), 0.9 * max(0.0, -s))
    p.rel("hat", (Y, 0.1 * math.sin(2 * ph)))
    p.offset = Vector((0, 0, 0.05 * b))
    return p


def tip_hat(t):
    # Hello! He lifts his hat off his head with his right hand, holds it up, and puts it back
    k = ss(0.0, 0.3, t) * (1 - ss(0.7, 1.0, t))
    p = Pose(BONES)
    wave(p, t, 1.0 - k * 0.6, side=0.05, fwd=0.03, back=0.05)
    p.rel("upper_arm.R", (Y, -0.35 + 1.9 * k), (X, -0.3 * k))
    p.rel("forearm.R", (X, -1.2 * k))
    p.rel("upper_arm.L", (Y, 0.35))
    p.rel("forearm.L", (X, -0.35))
    p.rel("head", (X, 0.15 * k))
    p.rel("hat", (X, 0.0), (Y, 0.0))
    # The hat rises off his head and leans the way his hand lifts it
    p.rel("hat", (Y, -0.45 * k))
    p.offset = Vector((0, 0, 0.0))
    return p


make_action(rig, "idle", 60, idle)
make_action(rig, "walk", 32, walk)
make_action(rig, "run", 20, run)
make_action(rig, "jump", 10, jump)
make_action(rig, "fall", 24, fall)
make_action(rig, "dance", 48, dance)
make_action(rig, "tip_hat", 45, tip_hat)
rest_pose(rig)
finish(OUT)

# The friends with baked-in detail (24 Nov 2026; Hayden: "I want you to keep baking details on assets in the game
# already as well"). The same way Nina was done (tools/build_nina_detail.py, tools/char_detail.py says why): each
# friend's model is exported from their .blend exactly as before (same shape, rig, weights, animations and material
# names, so the wardrobe, Clothes.fit_of() and every recolour still work), with a "Detail" UV map and three baked
# textures laid over every part: a normal map (fur strands, knit, twill, leaf veins, bark, horn rings, pores), the
# shadows where parts meet (AO) and a soft grey tint that's multiplied with each part's own colour. Eyes, mouths,
# teeth and anything that glows stay crisp (FLAT).
#
#   python tools/build_friend_detail.py <who> [<out.glb>] [--size=2048]
#   (or: blender -b --python tools/build_friend_detail.py -- <who> [<out.glb>])
#
#   <who>: rex (wolf), dash (bike_boy), pip (moth_kid), bruno, melody, heather (cattle_girl), bramble (plant_girl),
#   chaos (chaos_giant, the Agent of Chaos), gorilla (cyber_gorilla),
#   girl (human_girl) and boy (human_boy), the hero's two bodies in the creator, or "all". The out path defaults
#   to the model in models/characters/. Reads source_art/characters/<model>.blend and never saves over it. About 3 to 5 minutes each on 4 cloud cores.

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import char_detail as K  # noqa: E402  (imports bpy first)

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "Godot Project/my-world/models/characters"

# Every face that must stay crisp: eyes, mouths, teeth, shines and glows
EYES = ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine", "Mouth", "Tongue", "Teeth"]


# ---------------------------------------------------------------- recipes: recipe(N, c) -> (height, depth, tint)
# c is the character's own numbers (their hair's middle and spread), worked out from their mesh.
def folds(N, size=0.045):
    return N.noise(size, detail=2.0, rough=0.45, distortion=0.8)


def skin(N, c, depth=0.0003):
    pores = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.002), 0.0, 0.3))
    mottle = N.noise(0.01, detail=3.0)
    h = N.add(N.mul(pores, 0.15), N.mul(mottle, 0.85))
    return h, depth, N.ramp(N.noise(0.03, detail=3.0), 0.9, 1.0)


def nose(N, c):
    # A pet's nose: little bumpy cells, like leather
    h = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.0025), 0.0, 0.45))
    return h, 0.0006, N.ramp(N.noise(0.01), 0.85, 1.0)


def _strands(N, c, fine_n, clump_n, sway=0.012):
    """Strands running down the head or body: bands round a vertical axis through the hair's middle."""
    wrapped = N.around(c["centre"], c["radius"])
    shift = N.new("ShaderNodeCombineXYZ", X=N.mul(N.math("SUBTRACT", N.noise(0.05, detail=2.0), 0.5), sway),
                  Y=0.0, Z=0.0).outputs["Vector"]
    add = N.nt.nodes.new("ShaderNodeVectorMath")
    add.operation = "ADD"
    N.nt.links.new(wrapped, add.inputs[0])
    N.nt.links.new(shift, add.inputs[1])
    vec = add.outputs["Vector"]
    n = 2 * 3.14159265 * c["radius"]
    return N.wave(n / fine_n, "X", vec=vec), N.wave(n / clump_n, "X", vec=vec)


def hair(N, c):
    fine, clumps = _strands(N, c, 220, 48)
    h = N.add(N.mul(fine, 0.25), N.mul(clumps, 0.6), N.mul(N.noise(0.015, detail=2.0), 0.15))
    streak = N.add(N.mul(clumps, 0.55), N.mul(N.noise(0.025), 0.45))
    return h, 0.0012, N.ramp(streak, 0.8, 1.0)


def fur(N, c):
    # Short fur all over: fine strands combed downwards, soft tufts, and a little light and dark through it
    fine = N.wave(0.0022, "X", distortion=6.0, detail=3.0)
    tufts = N.noise(0.012, detail=4.0, rough=0.6, distortion=1.5)
    h = N.add(N.mul(fine, 0.35), N.mul(tufts, 0.65))
    return h, 0.0010, N.ramp(N.add(N.mul(tufts, 0.7), N.mul(N.noise(0.04), 0.3)), 0.84, 1.0)


def shag(N, c):
    # A gorilla's shaggy coat (Hayden, Nov 25: "more hairy"): noise stretched long and thin down the body makes
    # strands, a coarser stretched noise bunches them into locks, and soft tufts break the locks up. The gaps between
    # strands go dark and the tips stay pale, deeper than the friends' short fur. Waves were tried first: they read
    # as woven sacking.
    def streaks(size, long, sway):
        wrapped = N.around(c["centre"], c["radius"], height_scale=1.0 / long)
        bend = N.new("ShaderNodeCombineXYZ", X=N.mul(N.math("SUBTRACT", N.noise(0.06, detail=2.0), 0.5), sway),
                     Y=0.0, Z=0.0).outputs["Vector"]
        add = N.nt.nodes.new("ShaderNodeVectorMath")
        add.operation = "ADD"
        N.nt.links.new(wrapped, add.inputs[0])
        N.nt.links.new(bend, add.inputs[1])
        return N.noise(size, detail=3.0, rough=0.55, vec=add.outputs["Vector"])
    fine = N.sharpen(streaks(0.009, 7.0, 0.03), 0.3, 0.72)
    locks = N.sharpen(streaks(0.03, 4.0, 0.06), 0.25, 0.78)
    tufts = N.noise(0.04, detail=4.0, rough=0.6, distortion=1.5)
    h = N.add(N.mul(fine, 0.45), N.mul(locks, 0.4), N.mul(tufts, 0.15))
    return h, 0.012, N.ramp(N.add(N.mul(fine, 0.5), N.mul(locks, 0.35), N.mul(tufts, 0.15)), 0.45, 1.0)


def mane(N, c):
    # Pip's fluffy mane: long soft locks
    fine, clumps = _strands(N, c, 160, 30, sway=0.02)
    h = N.add(N.mul(fine, 0.2), N.mul(clumps, 0.5), N.mul(N.noise(0.02, detail=3.0, distortion=1.0), 0.3))
    return h, 0.0014, N.ramp(N.add(N.mul(clumps, 0.5), N.mul(N.noise(0.03), 0.5)), 0.82, 1.0)


def knit(N, c):
    """Jersey knit: a tee, a hoodie, a sporty suit."""
    cols = N.add(N.wave(0.003, "X"), N.wave(0.003, "Y"))
    f = folds(N)
    h = N.add(N.mul(cols, 0.12), N.mul(N.wave(0.0026, "Z"), 0.08), N.mul(f, 0.8))
    return h, 0.0012, N.ramp(f, 0.9, 1.0)


def rib(N, c):
    """Ribbed knit: cuffs, socks, a beanie."""
    ribs = N.wave(0.0035, "X", vec=N.around(c["centre"], c["radius"]))
    h = N.add(N.mul(ribs, 0.7), N.mul(folds(N, 0.03), 0.3))
    return h, 0.0010, N.ramp(N.noise(0.02), 0.88, 1.0)


def cotton(N, c):
    """A dress or a vest: plain weave and soft folds."""
    weave = N.add(N.wave(0.0022, "X"), N.wave(0.0022, "Z"))
    f = folds(N, 0.05)
    h = N.add(N.mul(weave, 0.12), N.mul(f, 0.88))
    return h, 0.0012, N.ramp(f, 0.88, 1.0)


def denim(N, c, rib_=False):
    twill = N.wave(0.0026, "DIAGONAL")
    f = folds(N, 0.04)
    parts = [N.mul(twill, 0.18), N.mul(f, 0.82)]
    if rib_:
        parts.append(N.mul(N.wave(0.005, "Z"), 0.25))
    fade = N.add(N.mul(N.noise(0.009, detail=6.0), 0.6), N.mul(f, 0.4))
    return N.add(*parts), 0.0012, N.ramp(fade, 0.84, 1.0)


def canvas(N, c):
    h = N.add(N.mul(N.wave(0.003, "X"), 0.2), N.mul(N.wave(0.003, "Z"), 0.2), N.mul(folds(N, 0.02), 0.6))
    return h, 0.0005, N.ramp(N.noise(0.015), 0.9, 1.0)


def leather(N, c):
    grain = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.0018), 0.0, 0.35))
    h = N.add(N.mul(grain, 0.35), N.mul(folds(N, 0.02), 0.65))
    return h, 0.0006, N.ramp(N.noise(0.012, detail=5.0), 0.82, 1.0)


def sole(N, c):
    nz = N.new("ShaderNodeSeparateXYZ", Vector=N.nt.nodes.new("ShaderNodeNewGeometry").outputs["Normal"])
    side = N.math("SUBTRACT", 1.0, N.sharpen(N.math("ABSOLUTE", nz.outputs["Z"]), 0.4, 0.75))
    return N.mul(N.wave(0.005, "Z"), side), 0.0012, N.ramp(N.noise(0.02), 0.92, 1.0)


def ripstop(N, c):
    weave = N.add(N.wave(0.003, "X"), N.wave(0.003, "Z"))
    grid = N.math("MAXIMUM", N.sharpen(N.wave(0.012, "X"), 0.8, 1.0), N.sharpen(N.wave(0.012, "Z"), 0.8, 1.0))
    h = N.add(N.mul(weave, 0.12), N.mul(grid, 0.2), N.mul(folds(N, 0.03), 0.68))
    return h, 0.0007, N.ramp(N.noise(0.02), 0.88, 1.0)


def satin(N, c):
    f = folds(N, 0.02)
    return N.add(N.mul(f, 0.85), N.mul(N.wave(0.004, "DIAGONAL"), 0.15)), 0.0012, N.ramp(f, 0.88, 1.0)


def cord(N, c):
    # A twisted string or lace
    return N.wave(0.002, "DIAGONAL"), 0.0004, N.ramp(N.noise(0.01), 0.9, 1.0)


def metal(N, c):
    return N.noise(0.0008), 0.0001, N.ramp(N.noise(0.01), 0.95, 1.0)


def plastic(N, c):
    return N.noise(0.003), 0.00005, 0.97


def rubber(N, c):
    return N.noise(0.0015, detail=4.0), 0.0003, N.ramp(N.noise(0.01), 0.9, 1.0)


def horn(N, c):
    # Growth rings round Heather's horns, with fine lines along them
    rings = N.wave(0.006, "Z", distortion=2.0)
    lines = N.wave(0.0015, "X", distortion=4.0)
    h = N.add(N.mul(rings, 0.7), N.mul(lines, 0.3))
    return h, 0.0010, N.ramp(N.add(N.mul(rings, 0.6), N.mul(N.noise(0.01), 0.4)), 0.82, 1.0)


def leaf(N, c):
    # A network of veins (the edges of big cells) over fine cells, and a soft light and dark across each leaf
    veins = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.012, feature="DISTANCE_TO_EDGE"), 0.0, 0.08))
    fine = N.cells(0.002)
    h = N.add(N.mul(veins, 0.7), N.mul(fine, 0.3))
    return h, 0.0008, N.ramp(N.add(N.mul(veins, 0.5), N.mul(N.noise(0.02), 0.5)), 0.84, 1.0)


def bark(N, c):
    ridges = N.wave(0.006, "X", distortion=8.0, detail=4.0)
    cracks = N.sharpen(N.cells(0.01, feature="DISTANCE_TO_EDGE"), 0.0, 0.1)
    h = N.add(N.mul(ridges, 0.6), N.mul(cracks, 0.4))
    return h, 0.0016, N.ramp(N.add(N.mul(ridges, 0.6), N.mul(N.noise(0.02), 0.4)), 0.8, 1.0)


def wing(N, c):
    # Butterfly wing scales: tiny overlapping cells, and a soft shimmer of light and dark
    scales = N.sharpen(N.cells(0.0016), 0.0, 0.5)
    h = N.add(N.mul(scales, 0.4), N.mul(N.noise(0.02, detail=2.0), 0.6))
    return h, 0.0004, N.ramp(N.noise(0.015, detail=3.0), 0.86, 1.0)


def armour(N, c):
    # Dark plate armour: hammered dents, fine scratches and a little pitting, darker in the dents
    dents = N.noise(0.045, detail=1.0, rough=0.3)
    scratch = N.sharpen(N.wave(0.002, "DIAGONAL", distortion=12.0, detail=3.0), 0.85, 1.0)
    pits = N.noise(0.004, detail=2.0)
    h = N.add(N.mul(dents, 0.75), N.mul(scratch, 0.15), N.mul(pits, 0.1))
    return h, 0.0014, N.ramp(N.add(N.mul(dents, 0.6), N.mul(N.noise(0.05), 0.4)), 0.78, 1.0)


def gold(N, c):
    # Engraved gold: curling scrollwork cut into it, and wear that's brighter on the raised bits
    scroll = N.sharpen(N.wave(0.012, "X", distortion=9.0, detail=2.0, profile="SAW"), 0.6, 0.95)
    fine = N.noise(0.0015, detail=3.0)
    h = N.add(N.mul(scroll, 0.7), N.mul(fine, 0.3))
    return h, 0.0010, N.ramp(N.add(N.mul(scroll, 0.6), N.mul(N.noise(0.03), 0.4)), 0.8, 1.0)


def bone(N, c):
    # Old bone: tiny pores, growth lines and fine cracks, a little yellowed in patches
    pores = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.003), 0.0, 0.25))
    lines = N.wave(0.006, "Z", distortion=3.0)
    cracks = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.03, feature="DISTANCE_TO_EDGE"), 0.0, 0.04))
    h = N.add(N.mul(pores, 0.3), N.mul(lines, 0.3), N.mul(cracks, 0.4))
    return h, 0.0012, N.ramp(N.noise(0.04, detail=4.0), 0.78, 1.0)


def linen(N, c):
    # Old torn linen: a coarse weave, big heavy folds and grubby stains
    weave = N.add(N.wave(0.005, "X"), N.wave(0.005, "Z"))
    f = folds(N, 0.09)
    h = N.add(N.mul(weave, 0.15), N.mul(f, 0.85))
    stain = N.add(N.mul(N.noise(0.06, detail=5.0), 0.7), N.mul(f, 0.3))
    return h, 0.0022, N.ramp(stain, 0.72, 1.0)


def panel(N, c):
    # Sci-fi plating: panel seams in a grid, little vents and a fine brushed grain
    seams = N.math("MAXIMUM", N.sharpen(N.wave(0.05, "X", profile="SAW"), 0.93, 1.0),
                   N.sharpen(N.wave(0.05, "Z", profile="SAW"), 0.93, 1.0))
    brush = N.wave(0.0008, "X", distortion=1.0)
    h = N.add(N.mul(N.math("SUBTRACT", 1.0, seams), 0.7), N.mul(brush, 0.1), N.mul(N.noise(0.02), 0.2))
    return h, 0.0012, N.ramp(N.noise(0.03, detail=3.0), 0.85, 1.0)


def feather(N, c):
    # Hermez's plumage: rows of overlapping feathers (the edges of stretched cells, each one darker at its root and
    # pale at its tip) with fine barbs running down them
    rows = N.around(c["centre"], c["radius"], height_scale=1.6)
    tips = N.sharpen(N.cells(0.014, vec=rows), 0.15, 0.7)          # soft rounded feather ends
    barbs = N.wave(0.0016, "X", distortion=3.0, vec=rows)
    h = N.add(N.mul(tips, 0.6), N.mul(barbs, 0.25), N.mul(N.noise(0.03), 0.15))
    return h, 0.0009, N.ramp(N.add(N.mul(tips, 0.5), N.mul(N.noise(0.04), 0.5)), 0.88, 1.0)


def scaly(N, c):
    # A bird's legs and toes: little overlapping scales
    s = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.006), 0.0, 0.45))
    return N.add(N.mul(s, 0.8), N.mul(N.noise(0.01), 0.2)), 0.0008, N.ramp(N.noise(0.01), 0.85, 1.0)


def rhino(N, c):
    # Rolo's thick rhino hide: big soft wrinkles and folds, a pebbly leather grain and a little mottling
    wrinkles = N.wave(0.03, "Z", distortion=4.0, detail=3.0)
    pebble = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.004), 0.0, 0.4))
    h = N.add(N.mul(wrinkles, 0.45), N.mul(pebble, 0.35), N.mul(folds(N, 0.05), 0.2))
    return h, 0.0016, N.ramp(N.add(N.mul(N.noise(0.03, detail=4.0), 0.7), N.mul(wrinkles, 0.3)), 0.84, 1.0)


R = {
    "feather": feather, "scaly": scaly, "rhino": rhino,
    "skin": skin, "nose": nose, "hair": hair, "fur": fur, "shag": shag, "mane": mane, "knit": knit, "rib": rib,
    "cotton": cotton, "denim": denim, "denim_rib": lambda N, c: denim(N, c, True), "canvas": canvas,
    "leather": leather, "sole": sole, "ripstop": ripstop, "satin": satin, "cord": cord, "metal": metal,
    "plastic": plastic, "rubber": rubber, "horn": horn, "leaf": leaf, "bark": bark, "wing": wing,
    "armour": armour, "gold": gold, "bone": bone, "linen": linen, "panel": panel,
}

# Each friend: their model's file, the body and rig in the .blend, the parts whose spread sets where hair strands
# fan out from, the parts left crisp, and a recipe for each part (anything not listed is skin).
CHARS = {
    "rex": {
        "model": "wolf", "body": "Wolf", "rig": "WolfRig", "hair": ["Fur", "Fur Dark", "Fur White"],
        "flat": EYES,
        "parts": {"Fur": "fur", "Fur Dark": "fur", "Fur White": "fur", "Brow": "fur", "Vest": "cotton",
                  "Strap": "leather", "Metal": "metal", "Nose": "nose", "Ear Inner": "skin", "Skate": "leather",
                  "Skate Trim": "canvas", "Wheel": "rubber"},
    },
    "dash": {
        "model": "bike_boy", "body": "BikeBoy", "rig": "BikeBoyRig", "hair": ["Hair"],
        "flat": EYES + ["Lens Shine"],
        "parts": {"Hoodie": "knit", "Hoodie Shade": "knit", "Shorts": "denim", "Shorts Trim": "denim_rib",
                  "Hair": "hair", "Cap": "canvas", "Cap White": "canvas", "Glasses": "plastic", "Zipper": "metal",
                  "String": "cord", "Sock": "rib", "Shoes": "canvas", "Sole": "sole", "Backpack": "ripstop",
                  "Backpack Dark": "ripstop"},
    },
    "pip": {
        "model": "moth_kid", "body": "MothKid", "rig": "MothKidRig",
        "hair": ["Mane Orange", "Mane Teal", "Mane Purple", "Mane Pink"],
        "flat": EYES,
        "parts": {"Suit Navy": "knit", "Suit Yellow": "knit", "Suit Blue": "knit", "Suit Red": "knit",
                  "Mane Orange": "mane", "Mane Teal": "mane", "Mane Purple": "mane", "Mane Pink": "mane",
                  "Wing Pink": "wing", "Wing Yellow": "wing", "Wing Orange": "wing", "Backpack": "ripstop",
                  "Antenna Tip": "plastic"},
    },
    "bruno": {
        "model": "bruno", "body": "Bruno", "rig": "BrunoRig", "hair": ["Hair", "Hair Shade"],
        "flat": EYES + ["Patch Text"],
        "parts": {"Tee": "knit", "Jeans": "denim", "Hoodie": "knit", "Hoodie Rib": "rib", "Zip": "metal",
                  "Drawstring": "cord", "Shoes": "canvas", "Sole": "sole", "Lace": "cord", "Hair": "hair",
                  "Hair Shade": "hair", "Beanie": "rib", "Beanie Rib": "rib", "Patch": "canvas"},
    },
    "melody": {
        "model": "melody", "body": "Melody", "rig": "MelodyRig", "hair": ["Hair", "Hair Shine"],
        "flat": EYES,
        "parts": {"Dress": "cotton", "Dress Dark": "cotton", "Fur": "fur", "Fur Dark": "fur", "Nose": "nose",
                  "Hair": "hair", "Hair Shine": "hair", "Scrunchie": "satin", "Button": "plastic", "Sock": "rib",
                  "Shoe": "leather", "Sole": "sole"},
    },
    "heather": {
        "model": "cattle_girl", "body": "CattleGirl", "rig": "CattleGirlRig",
        "hair": ["Hair", "Hair Shade", "Hair Tip Teal", "Hair Tip Lavender"],
        "flat": EYES + ["Glow Teal", "Glow Violet"],
        "parts": {"Top": "knit", "Fur": "fur", "Fur Light": "fur", "Shorts": "denim", "Shorts Trim": "denim_rib",
                  "Pocket": "denim", "Muzzle": "skin", "Nose": "nose", "Horn": "horn", "Horn Tip": "horn",
                  "Hair": "hair", "Hair Shade": "hair", "Hair Tip Teal": "hair", "Hair Tip Lavender": "hair",
                  "Belt": "leather", "Metal": "metal", "Alien Charm": "plastic", "Star": "metal", "Sock": "rib",
                  "Shoe": "leather", "Sole": "sole", "Shoe Panel": "canvas", "Backpack": "ripstop"},
    },
    "bramble": {
        "model": "plant_girl", "body": "PlantGirl", "rig": "PlantGirlRig",
        "hair": ["Leaf Green", "Leaf Gold", "Leaf Purple", "Leaf Teal", "Leaf Pink", "Leaf Orange"],
        "flat": EYES + ["Lash", "Trap Teeth", "Dew"],
        "parts": {"Leaf Green": "leaf", "Leaf Gold": "leaf", "Leaf Purple": "leaf", "Leaf Light": "leaf",
                  "Leaf Teal": "leaf", "Leaf Pink": "leaf", "Leaf Orange": "leaf", "Vein": "leaf", "Trap": "leaf",
                  "Bark": "bark", "Bark Line": "bark", "Vine": "bark", "Root": "bark", "Root Dark": "bark",
                  "Trap Inside": "skin"},
    },
    "girl": {
        "model": "human_girl", "body": "Human Girl", "rig": "HumanGirlRig", "hair": ["Hair"],
        "flat": EYES + ["Lash", "Blush", "Badge"],
        "parts": {"Top": "knit", "Top Shade": "knit", "Skirt": "cotton", "Skirt Shade": "cotton", "Hair": "hair",
                  "Brow": "hair", "Shoes": "canvas", "Sole": "sole"},
    },
    "boy": {
        "model": "human_boy", "body": "Human Boy", "rig": "HumanBoyRig", "hair": ["Hair"],
        "flat": EYES + ["Blush", "Star"],
        "parts": {"Top": "knit", "Top Shade": "knit", "Shorts": "denim", "Shorts Shade": "denim", "Hair": "hair",
                  "Brow": "hair", "Shoes": "canvas", "Sole": "sole"},
    },
    "chaos": {
        # The Agent of Chaos: built 2.75 m tall (x4 in town), so his shadows reach further
        "model": "chaos_giant", "body": "ChaosGiant", "rig": "ChaosGiantRig", "hair": ["Cloth"], "ao": 0.07,
        "flat": ["Void", "Eye Fire", "Clock Face", "Ink", "Chaos Magenta", "Chaos Ember", "Eye Gold",
                 "Chaos Violet"],
        "parts": {"Armour": "armour", "Armour Plum": "armour", "Gold": "gold", "Gold Dark": "gold",
                  "Bone": "bone", "Cloth": "linen", "Cloth Shade": "linen"},
    },
    "hermez": {
        # The crane by the lily pond (the Meshy trial's control, built by tools/build_hermez.py)
        "model": "hermez", "body": "Hermez", "rig": "HermezRig", "hair": ["Feather", "Feather Grey"],
        "flat": EYES + ["Brow", "Blush", "Eye Shine"],
        "parts": {"Feather": "feather", "Feather Grey": "feather", "Feather Black": "feather", "Crown": "skin",
                  "Beak": "horn", "Beak Tip": "horn", "Leg": "scaly", "Satchel": "canvas", "Satchel Strap": "leather",
                  "Metal": "metal"},
    },
    "gorilla": {
        "model": "cyber_gorilla", "body": "CyberGorilla", "rig": "GorillaRig", "hair": ["Fur"], "ao": 0.04,
        "flat": EYES + ["Screen", "Screen Gold", "Screen Gold Dark", "Void", "Eye Fire", "Screen Bone",
                        "Chaos Magenta", "Cyber Glow", "Red Eye", "Tooth"],
        "parts": {"Fur": "shag", "Fur Light": "shag", "Fur Dark": "shag", "Metal": "armour", "Metal Edge": "metal",
                  "Cyber": "panel", "Cyber Dark": "panel", "Skin": "skin"},
    },
}


def _spread(body, names):
    """The middle (x, y over the hair, z near its top) and the radius of the parts named, in the body's own space."""
    me = body.data
    idx = {i for i, m in enumerate(me.materials) if m and m.name in names}
    vs = set()
    for p in me.polygons:
        if p.material_index in idx:
            vs.update(p.vertices)
    if not vs:
        vs = range(len(me.vertices))
    co = [me.vertices[i].co for i in vs]
    xs, ys, zs = [v.x for v in co], [v.y for v in co], [v.z for v in co]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    r = max(0.05, max(max(xs) - min(xs), max(ys) - min(ys)) / 2)
    return {"centre": (cx, cy, (min(zs) + max(zs)) / 2), "radius": r}


def build(who, out=None, size=2048):
    c = CHARS[who]
    out = Path(out or MODELS / (c["model"] + ".glb")).resolve()
    K.open_blend(ROOT / "source_art" / "characters" / (c["model"] + ".blend"))
    body = K.D.objects[c["body"]]
    rig = K.D.objects[c["rig"]]
    # The detail UVs must be the only UV map, so the glb's TEXCOORD_0 is them (Bruno's old map had nothing on it)
    for uv in list(body.data.uv_layers):
        body.data.uv_layers.remove(uv)
    K.unwrap(body)
    K.export_glb(out)
    spread = _spread(body, c["hair"])
    names = [m.name for m in body.data.materials]
    for m in body.data.materials:
        if m.name in c["flat"]:
            K.flat(m)
        else:
            recipe = R[c["parts"].get(m.name, "skin")]
            K.dress(m, lambda N, r=recipe: r(N, spread))
    maps = K.bake(body, rig, size=size, name=c["model"], ao_distance=c.get("ao", 0.025))
    tmp = out.parent / f"_{c['model']}_detail"
    pngs = {k: K.save_png(img, tmp / f"{c['model']}_{k}.png") for k, img in maps.items()}
    done = K.add_textures(out, pngs, c["flat"], c["model"])
    for p in pngs.values():
        p.unlink()
    tmp.rmdir()
    print("DETAILED", who, len(done), "of", len(names), "materials:", ", ".join(done))


def main():
    a = K.args()
    size = 2048
    for x in sys.argv:
        if x.startswith("--size="):
            size = int(x.split("=")[1])
    who = a[0] if a else "all"
    if who == "all":
        for w in CHARS:
            build(w, size=size)
    else:
        build(who, a[1] if len(a) > 1 else None, size)


main()

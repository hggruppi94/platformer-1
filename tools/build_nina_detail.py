# Nina with baked-in detail (16 Nov 2026; Hayden: "try this on a character. lets start with nina"). Her model is
# built by tools/build_nina.py and is unchanged here: same shape, rig, weights, animations and materials. This adds
# the Detail UV map and bakes three textures laid over all her parts (tools/char_detail.py says why that way):
# jersey knit in her shirt, denim twill and soft creases in her overalls, canvas shoes with ridged soles, ripstop
# and mesh on the backpack, strands and streaks in her hair, satin folds in the bow, fine pores and mottling in her
# skin, and the shadows where they all meet. Her eyes, mouth and teeth stay crisp.
#
#   python tools/build_nina_detail.py "Godot Project/my-world/models/characters/nina.glb" [--size=2048]
#   (or: blender -b --python tools/build_nina_detail.py -- <out.glb>)
#
# Reads source_art/characters/nina.blend (never saves over it). About 4 minutes on 4 cloud cores.

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import char_detail as K  # noqa: E402  (imports bpy first)

ROOT = Path(__file__).resolve().parent.parent
BLEND = ROOT / "source_art" / "characters" / "nina.blend"
HAIR_C = (0.0, 0.0, 1.10)          # the middle of her head (build_nina.py HEAD): her hair's strands fan out from here
HAIR_R = 0.30                      # strands are counted round a circle this big, so they meet up at the back

FLAT = ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine", "Mouth", "Tongue", "Teeth"]


def folds(N, size=0.045):
    """Soft cloth creases: stretched noise, gentle."""
    return N.noise(size, detail=2.0, rough=0.45, distortion=0.8)


def skin(N, depth=0.0003):
    pores = N.math("SUBTRACT", 1.0, N.sharpen(N.cells(0.002), 0.0, 0.3))
    mottle = N.noise(0.01, detail=3.0)
    h = N.add(N.mul(pores, 0.15), N.mul(mottle, 0.85))
    return h, depth, N.ramp(N.noise(0.03, detail=3.0), 0.9, 1.0)


def hair(N):
    # The strands wave a little side to side (3D noise added to the distance round, so they still meet at the back)
    wrapped = N.around(HAIR_C, HAIR_R)
    sway = N.new("ShaderNodeCombineXYZ", X=N.mul(N.math("SUBTRACT", N.noise(0.05, detail=2.0), 0.5), 0.012),
                 Y=0.0, Z=0.0).outputs["Vector"]
    add = N.nt.nodes.new("ShaderNodeVectorMath")
    add.operation = "ADD"
    N.nt.links.new(wrapped, add.inputs[0])
    N.nt.links.new(sway, add.inputs[1])
    vec = add.outputs["Vector"]
    n = 2 * 3.14159265 * HAIR_R
    fine = N.wave(n / 220, "X", vec=vec)                 # 220 strands round, about 8.5 mm apart
    clumps = N.wave(n / 48, "X", vec=vec)                # and 48 locks
    wobble = N.noise(0.015, detail=2.0)
    h = N.add(N.mul(fine, 0.25), N.mul(clumps, 0.6), N.mul(wobble, 0.15))
    streak = N.add(N.mul(clumps, 0.55), N.mul(N.noise(0.025), 0.45))
    return h, 0.0012, N.ramp(streak, 0.8, 1.0)


def shirt(N):
    cols = N.add(N.wave(0.003, "X"), N.wave(0.003, "Y"))
    rows = N.wave(0.0026, "Z")
    f = folds(N)
    h = N.add(N.mul(cols, 0.12), N.mul(rows, 0.08), N.mul(f, 0.8))
    return h, 0.0012, N.ramp(f, 0.9, 1.0)


def denim(N, rib=False):
    twill = N.wave(0.0026, "DIAGONAL")
    f = folds(N, 0.04)
    parts = [N.mul(twill, 0.18), N.mul(f, 0.82)]
    if rib:
        parts.append(N.mul(N.wave(0.005, "Z"), 0.25))
    h = N.add(*parts)
    fade = N.add(N.mul(N.noise(0.009, detail=6.0), 0.6), N.mul(f, 0.4))
    return h, 0.0012, N.ramp(fade, 0.84, 1.0)


def canvas(N):
    h = N.add(N.mul(N.wave(0.003, "X"), 0.2), N.mul(N.wave(0.003, "Z"), 0.2), N.mul(folds(N, 0.02), 0.6))
    return h, 0.0005, N.ramp(N.noise(0.015), 0.9, 1.0)


def sole(N):
    # Ridges round the sides of the sole only (the rubber toe cap on top stays smooth)
    nz = N.new("ShaderNodeSeparateXYZ", Vector=N.nt.nodes.new("ShaderNodeNewGeometry").outputs["Normal"])
    side = N.math("SUBTRACT", 1.0, N.sharpen(N.math("ABSOLUTE", nz.outputs["Z"]), 0.4, 0.75))
    return N.mul(N.wave(0.005, "Z"), side), 0.0012, N.ramp(N.noise(0.02), 0.92, 1.0)


def ripstop(N):
    weave = N.add(N.wave(0.003, "X"), N.wave(0.003, "Z"))
    grid = N.math("MAXIMUM", N.sharpen(N.wave(0.012, "X"), 0.8, 1.0), N.sharpen(N.wave(0.012, "Z"), 0.8, 1.0))
    h = N.add(N.mul(weave, 0.12), N.mul(grid, 0.2), N.mul(folds(N, 0.03), 0.68))
    return h, 0.0007, N.ramp(N.noise(0.02), 0.88, 1.0)


def mesh_pocket(N):
    solid = N.sharpen(N.cells(0.0035), 0.25, 0.4)       # 1 on the threads, 0 in the holes
    return solid, 0.0015, N.ramp(solid, 0.35, 1.0)


def bow(N):
    f = folds(N, 0.02)
    h = N.add(N.mul(f, 0.85), N.mul(N.wave(0.004, "DIAGONAL"), 0.15))
    return h, 0.0012, N.ramp(f, 0.88, 1.0)


def metal(N):
    return N.noise(0.0008), 0.0001, N.ramp(N.noise(0.01), 0.95, 1.0)


RECIPES = {
    "Skin": skin, "Blush": lambda N: skin(N, 0.0003), "Ear Inner": lambda N: skin(N, 0.0003),
    "Nostril": lambda N: skin(N, 0.0002), "Brow": lambda N: skin(N, 0.0002),
    "Hair": hair, "Bow": bow, "Shirt": shirt,
    "Overalls": denim, "Overalls Trim": lambda N: denim(N, rib=True),
    "Shoes": canvas, "Sole": sole, "Backpack": ripstop, "Backpack Mesh": mesh_pocket,
    "Clasp": metal, "Zipper": metal,
}


def main():
    out = Path(K.args()[0] if K.args() else ROOT / "Godot Project/my-world/models/characters/nina.glb").resolve()
    size = 2048
    for a in sys.argv:
        if a.startswith("--size="):
            size = int(a.split("=")[1])
    K.open_blend(BLEND)
    body = K.D.objects["Nina"]
    rig = K.D.objects["NinaRig"]
    K.unwrap(body)
    K.export_glb(out)                          # her model as always, now with the Detail UVs
    names = [m.name for m in body.data.materials]
    for m in body.data.materials:
        if m.name in FLAT:
            K.flat(m)
        else:
            K.dress(m, RECIPES.get(m.name, skin))
    maps = K.bake(body, rig, size=size, name="nina")
    tmp = out.parent / "_nina_detail"
    pngs = {k: K.save_png(img, tmp / f"nina_{k}.png") for k, img in maps.items()}
    done = K.add_textures(out, pngs, FLAT, "nina")
    for p in pngs.values():
        p.unlink()
    tmp.rmdir()
    print("DETAILED", len(done), "of", len(names), "materials:", ", ".join(done))


main()

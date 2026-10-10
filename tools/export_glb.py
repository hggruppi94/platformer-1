# Exports one .blend file to a game-ready .glb for Godot.
#
# Usage (normally called by export_all.ps1):
#   blender -b path\to\model.blend --python tools\export_glb.py -- path\to\output.glb
#
# The .blend file itself is never modified or saved.

import sys
from pathlib import Path

import bpy

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not args:
    sys.exit("export_glb.py: pass the output .glb path after '--'")

out = Path(args[0])
out.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.export_scene.gltf(
    filepath=str(out),
    export_format='GLB',
    use_renderable=True,     # skip objects hidden from render (reference images, helpers)
    export_apply=True,       # bake modifiers (subdivision, mirror, ...) into the mesh
    export_cameras=False,
    export_lights=False,
    export_yup=True,         # Godot is Y-up; Blender is Z-up
    export_animations=True,  # picks up actions / NLA tracks once characters are rigged
)
print(f"EXPORTED {bpy.data.filepath} -> {out}")

# Applies Nina's colors (per source_art/reference/Nina - main reference.jpg) and gives her
# brown irises with black pupils and highlights. Safe to re-run.
#
#   blender -b source_art\characters\hippo_girl.blend --python tools\nina_look.py

import bmesh
import bpy
from mathutils import Matrix, Vector

D = bpy.data

# Linear-space colors picked from the reference
COLORS = {
    "Skin":     (0.30, 0.21, 0.19, 1.0),    # warm taupe grey
    "Bow":      (0.62, 0.012, 0.015, 1.0),  # red bow
    "Overalls": (0.83, 0.24, 0.40, 1.0),    # pink overalls
    "Shoes":    (0.80, 0.20, 0.32, 1.0),    # pink sneakers
    "Nostril":  (0.07, 0.045, 0.04, 1.0),   # dark brown-grey
    "Iris":     (0.16, 0.05, 0.015, 1.0),   # brown eyes
    "Pupil":    (0.005, 0.004, 0.004, 1.0),
}


def set_color(m, rgba):
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
    m.diffuse_color = rgba


eyes = D.objects["Eyes"]
if "Iris" not in D.materials:
    # The old black "Pupil" spheres become the brown irises
    D.materials["Pupil"].name = "Iris"
    pupil_mat = D.materials.new("Pupil")
    eyes.data.materials.append(pupil_mat)

    mats = [m.name for m in eyes.data.materials]
    pupil_idx, white_idx = mats.index("Pupil"), mats.index("Eye White")
    bm = bmesh.new()
    bm.from_mesh(eyes.data)
    for iris_name, white_name in (("Sphere.009", "Sphere"), ("Sphere.010", "Sphere.001")):
        def center_radius(name):
            ob = D.objects[f"{name} (part)"]
            pts = [ob.matrix_basis @ v.co for v in ob.data.vertices]   # backups are excluded: use matrix_basis
            c = sum(pts, Vector()) / len(pts)
            return c, max((p - c).length for p in pts)
        ic, ir = center_radius(iris_name)
        wc, _ = center_radius(white_name)
        fwd = (ic - wc).normalized()                 # out of the eyeball, through the iris
        side = fwd.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(fwd).normalized()
        for radius, pos, mat_idx in ((ir * 0.62, ic + fwd * ir * 0.5, pupil_idx),
                                     (ir * 0.2, ic + fwd * ir * 0.9 + up * ir * 0.35 - side * ir * 0.3, white_idx)):
            geom = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius,
                                             matrix=Matrix.Translation(pos))
            for f in {f for v in geom["verts"] for f in v.link_faces}:
                f.material_index = mat_idx
                f.smooth = True
    bm.to_mesh(eyes.data)
    bm.free()
    print("EYES added pupils + highlights")

for name, rgba in COLORS.items():
    set_color(D.materials[name], rgba)
print("COLORS", {n: tuple(round(v, 3) for v in c[:3]) for n, c in COLORS.items()})
bpy.ops.wm.save_mainfile()
print("SAVED")

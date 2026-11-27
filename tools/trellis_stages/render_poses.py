# Renders the pose test (posetest.blend from rig.py): one 3/4 picture per pose, each part in its own flat colour
# (top) and the real texture (bottom), so a stretch number can be matched to what it looks like.
#   blender -b posetest.blend --python render_poses.py -- <out prefix>
import bpy, math, sys
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
sc = bpy.context.scene
rig = bpy.data.objects["NinaRig"]
ob = bpy.data.objects["Nina"]
rig.animation_data.action = bpy.data.actions["posetest"]
n = int(bpy.data.actions["posetest"].frame_range[1]) + 1
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 320, 400
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.87, 0.9, 1)
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3; sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C")); sc.collection.objects.link(cam); sc.camera = cam
t = Vector((0, 0, 0.62))
cam.location = t + Vector((2.6 * math.sin(math.radians(35)), -2.6 * math.cos(math.radians(35)), 0.3))
cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
real = [s.material for s in ob.material_slots]
pal = [(0.9, 0.75, 0.6), (0.2, 0.4, 0.9), (0.95, 0.5, 0.7), (1, 0.85, 0.1), (0.95, 0.95, 0.95), (0.2, 0.9, 0.3),
       (0.8, 0.1, 0.1), (0.1, 0.1, 0.1), (0.6, 0.3, 0.9), (0.3, 0.8, 0.9)]
flat = []
for i, m in enumerate(real):
    f = bpy.data.materials.new("flat_" + m.name); f.use_nodes = True
    f.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*pal[i % len(pal)], 1)
    flat.append(f)
for i in range(1, n):
    sc.frame_set(i)
    for mats, tag in ((flat, "p"), (real, "t")):
        for k, m in enumerate(mats):
            ob.material_slots[k].material = m
        sc.render.filepath = f"{out}_{i}{tag}.png"
        bpy.ops.render.render(write_still=True)
print("POSES", n - 1, [m.name for m in real])

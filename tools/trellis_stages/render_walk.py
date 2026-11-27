# Stage preview of tools/trellis_character.py: renders the rig (objects "NinaRig") walking from one side, 512 px.
#   blender -b rigged.blend --python render_walk.py -- <frames dir> <action> [cycles] [view degrees]
import bpy, math, sys, os
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
out, act = a[0], a[1]
cycles = int(a[2]) if len(a) > 2 else 2
ang = float(a[3]) if len(a) > 3 else 35
os.makedirs(out, exist_ok=True)
sc = bpy.context.scene
rig = bpy.data.objects["NinaRig"]
rig.animation_data.action = bpy.data.actions[act]
for t in rig.animation_data.nla_tracks:
    t.mute = True
n = int(bpy.data.actions[act].frame_range[1])
sc.render.engine = "CYCLES"
sc.cycles.samples = 24
sc.cycles.use_denoising = True
try:
    pr = bpy.context.preferences.addons["cycles"].preferences; pr.compute_device_type = "OPTIX"; pr.get_devices()
    for d in pr.devices:
        d.use = True
    sc.cycles.device = "GPU"
except Exception:
    pass
sc.view_settings.view_transform = "Standard"
sc.render.resolution_x, sc.render.resolution_y = 512, 512
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.85, 0.9, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 2.6; sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
import bmesh
fl = bpy.data.objects.new("Floor", bpy.data.meshes.new("Floor"))
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=3); bm.to_mesh(fl.data); bm.free()
fm = bpy.data.materials.new("F"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.65, 0.5, 1)
fl.data.materials.append(fm); sc.collection.objects.link(fl)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
target = Vector((0, 0, 0.7))
t = math.radians(ang)
cam.location = target + Vector((3.3 * math.sin(t), -3.3 * math.cos(t), 0.4))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
k = 0
for c in range(cycles):
    for f in range(n):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(out, f"f{k:03d}.png")
        bpy.ops.render.render(write_still=True)
        k += 1
print("WALK frames", k)

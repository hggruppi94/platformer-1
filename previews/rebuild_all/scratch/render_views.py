# blender -b <blend> --python render_views.py -- <out prefix> [views...]: front, three, side, back, face close-up
import bpy, math, sys
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]
views = a[1:] or ["front", "three", "face"]
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 64
try:
    pr = bpy.context.preferences.addons["cycles"].preferences; pr.compute_device_type = "OPTIX"; pr.get_devices()
    for d in pr.devices:
        d.use = True
    sc.cycles.device = "GPU"
except Exception:
    pass
sc.view_settings.view_transform = "Standard"
sc.render.resolution_x, sc.render.resolution_y = 600, 800
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.85, 0.9, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 2.6; sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
for name in views:
    if name == "face":
        target, dist, ang, lens = Vector((-0.1, 0, 1.02)), 1.9, 15, 70
    else:
        ang = {"front": 0, "three": 35, "side": 90, "back": 180}[name]
        target, dist, lens = Vector((0, 0, 0.72)), 4.2, 50
    t = math.radians(ang)
    cam.data.lens = lens
    cam.location = target + Vector((dist * math.sin(t), -dist * math.cos(t), 0.15))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)

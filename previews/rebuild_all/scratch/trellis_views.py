# blender -b --python views.py -- <glb> <out prefix> [yaw]   front/three/side/back/face, texture kept as is
import bpy, math, sys, bmesh
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--") + 1:]
glb, out = a[0], a[1]; yaw = float(a[2]) if len(a) > 2 else 0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc = bpy.context.scene
meshes = [o for o in sc.objects if o.type == "MESH"]
lo, hi = Vector((1e9,)*3), Vector((-1e9,)*3)
for o in meshes:
    for v in o.data.vertices:
        w = o.matrix_world @ v.co; lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
print("BOUNDS", lo, hi)
h = bpy.data.objects.new("H", None); sc.collection.objects.link(h)
for o in sc.objects:
    if o.parent is None and o is not h: o.parent = h
k = 1.2 / (hi.z - lo.z)
c = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
h.matrix_world = Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(k, 4) @ Matrix.Translation(-c)
sc.render.engine = "CYCLES"; sc.cycles.samples = 48; sc.cycles.use_denoising = True
try:
    p = bpy.context.preferences.addons["cycles"].preferences; p.compute_device_type = "OPTIX"; p.get_devices()
    for d in p.devices: d.use = True
    sc.cycles.device = "GPU"
except Exception: pass
sc.view_settings.view_transform = "Standard"
fl = bpy.data.objects.new("F", bpy.data.meshes.new("F")); bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=4); bm.to_mesh(fl.data); bm.free()
fm = bpy.data.materials.new("FM"); fm.use_nodes = True; fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.5, 0.4, 1)
fl.data.materials.append(fm); sc.collection.objects.link(fl)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C")); sc.collection.objects.link(cam); sc.camera = cam
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (math.radians(45), 0, math.radians(-35))
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.74, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
def shot(name, ang, target, dist, lens, rx, ry):
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    t = math.radians(ang); cam.data.lens = lens
    cam.location = target + Vector((dist*math.sin(t), -dist*math.cos(t), 0.15))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = f"{out}_{name}.png"; bpy.ops.render.render(write_still=True)
T = Vector((0, 0, 0.62))
for n, ang in (("front", 0), ("three", 35), ("side", 90), ("back", 180)):
    shot(n, ang, T, 3.4, 50, 420, 560)
shot("face", 15, Vector((0, 0, 0.98)), 1.1, 60, 420, 420)

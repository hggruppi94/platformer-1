# Stage views of tools/trellis_character.py: side and back pictures that match front.png, for a generator that uses
# several views (TRELLIS 1). Rendered from a first, front-only model (TRELLIS.2), flat lit on white, so the side and
# back agree with the front exactly. Then they wait for Hayden's OK with the front.
#   blender -b --python side_back.py -- <model.glb> <out dir> [yaw to face front] [persp]
import bpy, math, sys
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--") + 1:]
glb, out = a[0], a[1]
yaw = float(a[2]) if len(a) > 2 else 0.0
# "persp": Pixal3D's multi-view cameras (a 20 degree lens 3.119 m away, the model 1 m tall centred on the middle)
PERSP = len(a) > 3 and a[3] == "persp"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc = bpy.context.scene
meshes = [o for o in sc.objects if o.type == "MESH"]
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in meshes:
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
h = bpy.data.objects.new("H", None); sc.collection.objects.link(h)
for o in sc.objects:
    if o.parent is None and o is not h:
        o.parent = h
k = 1.0 / (hi.z - lo.z)
c = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2 if PERSP else lo.z))
h.matrix_world = Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(k, 4) @ Matrix.Translation(-c)
sc.render.engine = "CYCLES"; sc.cycles.samples = 32; sc.cycles.use_denoising = True
try:
    p = bpy.context.preferences.addons["cycles"].preferences; p.compute_device_type = "OPTIX"; p.get_devices()
    for d in p.devices: d.use = True
    sc.cycles.device = "GPU"
except Exception:
    pass
sc.view_settings.view_transform = "Standard"
sc.render.resolution_x = sc.render.resolution_y = 1024
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C")); sc.collection.objects.link(cam); sc.camera = cam
if PERSP:
    cam.data.sensor_fit = "HORIZONTAL"; cam.data.angle = 0.3490658503988659
else:
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 1.15
mid, dist = (0.0, 3.119) if PERSP else (0.5, 5.0)
for name, ang in (("front", 0), ("side", 90), ("back", 180)):
    t = math.radians(ang)
    cam.location = Vector((dist * math.sin(t), -dist * math.cos(t), mid))
    cam.rotation_euler = (Vector((0, 0, mid)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = f"{out}/{name}.png"
    bpy.ops.render.render(write_still=True)

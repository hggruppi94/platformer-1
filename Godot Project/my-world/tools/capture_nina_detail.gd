extends SceneTree

# Close-ups of Void Nina's model on her own, to compare her baked-in detail (tools/build_nina_detail.py) with how she
# was. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_nina_detail.gd -- <output folder> [<model path>]
#
# The model defaults to res://models/characters/nina.glb; pass a copy of the old one to take the "before" shots.
# Touches no save.

var out_dir := "user://nina_detail"
var model := "res://models/characters/nina.glb"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		model = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1000, 1000))
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = false
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-38, 35, 0)
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(8, 8)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.62, 0.5)
	floor_mesh.material_override = fm
	world.add_child(floor_mesh)
	var body: Node3D = load(model).instantiate()
	world.add_child(body)
	var anim: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.3, true)
		anim.pause()
	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	cam.current = true
	# glTF -Y forward comes in facing +Z, so the camera sits on +Z to see her face.
	var shots := [
		["01_face", Vector3(0.0, 1.12, 0.85), Vector3(0, 1.06, 0)],
		["02_face_34", Vector3(0.55, 1.18, 0.62), Vector3(0, 1.08, 0)],
		["03_hair_side", Vector3(0.85, 1.25, -0.1), Vector3(0, 1.1, 0)],
		["04_front", Vector3(0.0, 0.85, 1.7), Vector3(0, 0.7, 0)],
		["05_overalls", Vector3(0.3, 0.62, 0.75), Vector3(0, 0.55, 0)],
		["06_back", Vector3(-0.45, 0.85, -1.3), Vector3(0, 0.65, 0)],
		["07_shoes", Vector3(0.35, 0.22, 0.6), Vector3(0.05, 0.08, 0)],
		["08_full", Vector3(1.4, 1.1, 2.6), Vector3(0, 0.7, 0)],
	]
	for s in shots:
		cam.look_at_from_position(s[1], s[2])
		for i in 10:
			await process_frame
		var img := root.get_texture().get_image()
		var path: String = out_dir.path_join("%s.png" % s[0])
		img.save_png(path)
		print("SHOT ", path)
	quit()

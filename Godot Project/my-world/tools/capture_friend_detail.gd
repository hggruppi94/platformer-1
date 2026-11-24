extends SceneTree

# Close-ups of one character's model on its own, to compare their baked-in detail (tools/build_friend_detail.py)
# with how they were, like capture_nina_detail.gd but framed to each character's own height. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_friend_detail.gd -- <output folder> <model path>
#
# Pass a copy of the old model to take the "before" shots. Touches no save.

var out_dir := "user://friend_detail"
var model := "res://models/characters/wolf.glb"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		model = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1000, 1000))
	_run.call_deferred()


func _height(n: Node) -> float:
	var top := 0.0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		top = maxf(top, box.end.y)
	return maxf(top, 0.5)


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
	await process_frame
	var h := _height(body)
	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	cam.current = true
	# glTF -Y forward comes in facing +Z, so the camera sits on +Z to see the face. Every place is a share of height.
	var head := h * 0.8
	var shots := [
		["01_face", Vector3(0.0, head, h * 0.55), Vector3(0, head - h * 0.03, 0)],
		["02_face_34", Vector3(h * 0.38, head + h * 0.03, h * 0.42), Vector3(0, head - h * 0.02, 0)],
		["03_side", Vector3(h * 0.6, h * 0.75, -h * 0.05), Vector3(0, h * 0.7, 0)],
		["04_front", Vector3(0.0, h * 0.55, h * 1.2), Vector3(0, h * 0.48, 0)],
		["05_middle", Vector3(h * 0.22, h * 0.42, h * 0.52), Vector3(0, h * 0.38, 0)],
		["06_back", Vector3(-h * 0.3, h * 0.6, -h * 0.9), Vector3(0, h * 0.45, 0)],
		["07_feet", Vector3(h * 0.25, h * 0.15, h * 0.42), Vector3(0.03, h * 0.06, 0)],
		["08_full", Vector3(h, h * 0.75, h * 1.8), Vector3(0, h * 0.48, 0)],
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

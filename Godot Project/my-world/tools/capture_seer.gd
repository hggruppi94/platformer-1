extends SceneTree

# Pictures of the Seer (scripts/seer.gd) on her own, as the game draws her: front, three-quarter, her face and Hoot
# the owl, and from behind (the shawl). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_seer.gd -- <output folder>
#
# Touches no save: nothing here loads or writes one.

var out_dir := "user://seer"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1000, 1000))
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.14, 0.26)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.72, 0.85)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-35, -25, 0)
	world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.2, 1.6, 1.6)
	fill.light_color = Color(1.0, 0.85, 0.7)
	fill.light_energy = 0.6
	fill.omni_range = 5.0
	world.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.26, 0.4)
	floor_mesh.material_override = fm
	world.add_child(floor_mesh)
	var seer := Node3D.new()
	seer.set_script(load("res://scripts/seer.gd"))
	world.add_child(seer)
	var cam := Camera3D.new()
	cam.fov = 35
	world.add_child(cam)
	cam.make_current()
	for k in 30:
		await process_frame
	var shots := [
		["01_the_seer", Vector3(0.0, 1.0, 3.6), Vector3(0, 0.8, 0)],
		["02_three_quarter", Vector3(-2.2, 1.2, 2.6), Vector3(0, 0.8, 0)],
		["03_face_and_hoot", Vector3(-0.25, 1.35, 1.25), Vector3(0.05, 1.22, 0)],
		["04_shawl_from_behind", Vector3(1.2, 1.4, -2.8), Vector3(0, 0.85, 0)],
		["05_lantern", Vector3(-1.0, 0.75, 1.0), Vector3(-0.45, 0.48, 0.1)],
	]
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2])
		if str(s[0]) == "03_face_and_hoot":
			seer.set("_peek", -0.5)                 # catch Hoot with one eye open
		for k in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		var path := out_dir.path_join(str(s[0]) + ".png")
		img.save_png(path)
		print("saved ", path)
	quit()

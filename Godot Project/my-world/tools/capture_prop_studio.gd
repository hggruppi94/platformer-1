extends SceneTree

# Pictures of baked props on their own (16 Nov 2026, the detailed props pipeline): each prop twice on a plain floor,
# left the very detailed version (models/props/_preview/<name>_high_preview.glb, from a build script's --preview,
# never used by the game) and right the one the game draws (models/props/<name>.glb), then a close look at each.
# No save is touched (nothing here loads or writes one).
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_prop_studio.gd -- <folder> <name> [<name>...]

var out_dir := ""
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://prop_studio"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred(args.slice(1))


func _run(names: Array) -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	w.add_child(sun)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.5, 0.4)
	floor_m.material_override = fm
	w.add_child(floor_m)
	cam = Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	cam.make_current()
	for n in names:
		var lo_path := "res://models/props/%s.glb" % n
		var hi_path := "res://models/props/_preview/%s_high_preview.glb" % n
		if not ResourceLoader.exists(lo_path):
			print("MISSING ", lo_path)
			continue
		var parts := []
		var size := Vector3.ONE
		for side in [-1.0, 1.0]:
			var path := hi_path if side < 0 else lo_path
			if not ResourceLoader.exists(path):
				continue
			var m := (load(path) as PackedScene).instantiate() as Node3D
			w.add_child(m)
			# (a sign post holds a board of every width: show the 3.4 m one)
			if m.find_child("Board34", true, false):
				for b in m.find_children("Board*", "", true, false):
					if b.name != "Board34":
						b.queue_free()
				await process_frame
			size = _bounds(m).size
			parts.append([m, side])
		var gap := maxf(size.x, size.z) * 0.75 + 0.3
		for p in parts:
			(p[0] as Node3D).position = Vector3(p[1] * gap, 0, 0)
		var h := size.y
		var d := maxf(gap * 2.0 + size.x, h) * 1.45
		cam.global_position = Vector3(0, h * 0.75, d)
		cam.look_at(Vector3(0, h * 0.45, 0))
		await _shot(n)
		for side in [-1.0, 1.0]:
			var dd := maxf(size.x, h) * 1.4
			cam.global_position = Vector3(side * gap + dd * 0.35, h * 0.8, dd)
			cam.look_at(Vector3(side * gap, h * 0.55, 0))
			await _shot("%s_close_%s" % [n, "detailed" if side < 0 else "game"])
		for p in parts:
			(p[0] as Node3D).queue_free()
		await process_frame
	quit()


func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _shot(file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)

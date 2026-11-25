extends SceneTree

# Close-ups of the shape-built bosses' baked parts (tools/build_prop_bosses.py, scripts/detail_props.gd): the Gloop
# King's crown, a Time Goblin's cog, Grandfather Tock's clock hat and the Boulderdillo's boulders, in a plain studio.
# With --old-props it shoots the same views with the detail pipeline off, to compare. Opens a window:
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_detail.gd -- <folder> [--old-props]
#
# Only makes the bosses in an empty scene: no save or setting is touched.

var out_dir := "user://boss_detail_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	_run.call_deferred()


func _make(path: String, script := "", size := 0.0) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	if script != "":
		n.set_script(load(script))
		n.set("size", size)
	return n


func _middle(n: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "VisualInstance3D", true, false):
		var v := m as VisualInstance3D
		if not v.is_visible_in_tree() or v.layers == 0:
			continue
		var a: AABB = v.global_transform * v.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box.get_center() if not first else n.global_position


func _run() -> void:
	if "--old-props" in OS.get_cmdline_user_args():
		root.get_node("WorldDetail").set("detail_props", false)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	# A sky, so gold and brass have something to shine back (a plain colour leaves metal looking dark)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.6, 0.85)
	sky_mat.sky_horizon_color = Color(0.85, 0.82, 0.9)
	sky_mat.ground_horizon_color = Color(0.6, 0.55, 0.6)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.3, 0.38)
	floor.material_override = fm
	stage.add_child(floor)
	var shots := [
		# name, scene, script, size, place, the part to look at (or "" for the middle), how far, camera direction
		["king", "res://scenes/enemies/gloop_king.tscn", "", 0.0, Vector3(0, 0, 0), "Visual/Body/Crown", 1.3, Vector3(0.5, 0.45, 1)],
		["king_full", "", "", 0.0, Vector3(0, 0, 0), "", 6.0, Vector3(0.5, 0.35, 1)],
		["goblin", "res://scenes/enemies/time_goblin.tscn", "", 0.0, Vector3(20, 0, 0), "", 2.6, Vector3(0.5, 0.3, 1)],
		["tock", "res://scenes/enemies/time_goblin_boss.tscn", "", 0.0, Vector3(40, 0, 0), "Visual/Head/Clock", 2.4, Vector3(0.6, 0.3, 1)],
		["tock_full", "", "", 0.0, Vector3(40, 0, 0), "", 7.0, Vector3(0.5, 0.3, 1)],
		["boulderdillo", "res://scenes/enemies/crocodillo.tscn", "res://scripts/crocodillo_boss.gd", 2.6, Vector3(60, 0, 0), "", 11.0, Vector3(0.7, 0.45, 1)],
		["boulderdillo_back", "", "", 0.0, Vector3(60, 0, 0), "", 10.0, Vector3(0.6, 0.6, -1)],
	]
	var made := {}
	for s in shots:
		if s[1] != "":
			var n := _make(s[1], s[2], s[3])
			n.position = s[4]
			# Frozen before it goes in, so nothing wanders off or turns round before the picture
			n.process_mode = Node.PROCESS_MODE_DISABLED
			stage.add_child(n)
			made[s[4]] = n
	for i in 8:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 45
	stage.add_child(cam)
	cam.make_current()
	for s in shots:
		var boss: Node3D = made[s[4]]
		var at: Vector3 = _middle(boss)
		if s[5] != "" and boss.has_node(s[5]):
			at = (boss.get_node(s[5]) as Node3D).global_position
		# Seen from the boss's front, a little to one side and above
		var b: Basis = boss.get_node("Visual").global_transform.basis if boss.has_node("Visual") else boss.global_transform.basis
		var fwd: Vector3 = b.z
		fwd.y = 0
		fwd = fwd.normalized()
		var side := Vector3(fwd.z, 0, -fwd.x)
		var d: Vector3 = s[7]
		cam.global_position = at + (side * d.x + Vector3.UP * d.y + fwd * d.z).normalized() * float(s[6])
		cam.look_at(at, Vector3.UP)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % s[0]))
	quit()

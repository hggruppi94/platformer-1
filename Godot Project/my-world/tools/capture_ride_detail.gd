extends SceneTree

# Close-ups of the rides' baked patches (tools/build_prop_surfaces.py maple|grip_tape|brushed_metal|tread|leaf_skin,
# scripts/detail_props.gd dress_ride, called by RideKit.build): the skateboard and SK8 Deck's maple, grip and trucks, the
# Rocket Board's tubes, the skates' boots, the scooter, the leaf board's veins, the Segway's tyres, the Overboard and the
# Saucer, in a plain studio. With --old-props it shoots the same views with the detail pipeline off, to compare. Opens a
# window:
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_ride_detail.gd -- <folder> [--old-props]
#
# Only builds the rides in an empty scene: no save or setting is touched.

var out_dir := "user://ride_detail_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	_run.call_deferred()


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
	# name, kit, place, how far, camera direction (side, up, front)
	var shots := [
		["board", "board", Vector3(0, 0, 0), 1.4, Vector3(0.8, 0.9, 0.6)],
		["board_close", "", Vector3(0, 0, 0), 0.6, Vector3(0.3, 1, 0.2)],
		["board_under", "", Vector3(0, 0, 0), 0.9, Vector3(0.9, -0.25, 0.4)],
		["sk8", "sk8", Vector3(6, 0, 0), 1.4, Vector3(0.8, 0.9, 0.6)],
		["rocket_board", "rocket_board", Vector3(12, 0, 0), 1.8, Vector3(0.9, 0.6, -0.6)],
		["skates", "skates", Vector3(18, 0, 0), 1.0, Vector3(0.8, 0.5, 1)],
		["paw_skates", "paw_skates", Vector3(24, 0, 0), 1.3, Vector3(0.8, 0.5, 1)],
		["scooter", "scooter", Vector3(30, 0, 0), 2.0, Vector3(0.9, 0.5, 0.6)],
		["leaf", "leaf", Vector3(36, 0, 0), 1.6, Vector3(0.5, 1, 0.5)],
		["segway", "segway", Vector3(42, 0, 0), 2.0, Vector3(0.9, 0.4, 0.8)],
		["segway_close", "", Vector3(42, 0, 0), 0.9, Vector3(1, 0.2, 0.2)],
		["overboard", "overboard", Vector3(48, 0, 0), 1.6, Vector3(0.8, 0.8, 0.6)],
		["saucer", "saucer", Vector3(54, 0, 0), 2.6, Vector3(0.8, 0.6, 0.8)],
	]
	var made := {}
	for s in shots:
		if s[1] != "":
			var ride := Node3D.new()
			ride.position = s[2]
			stage.add_child(ride)
			# The model is a stand-in kept beside the ride: build() frees whatever's in the ride first
			var model := Node3D.new()
			stage.add_child(model)
			RideKit.build(s[1], ride, model)
			ride.position.y = 0.3
			made[s[2]] = ride
	for i in 8:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 45
	cam.near = 0.02
	stage.add_child(cam)
	cam.make_current()
	for s in shots:
		var ride: Node3D = made[s[2]]
		var at: Vector3 = _middle(ride)
		var d: Vector3 = s[4]
		cam.global_position = at + Vector3(d.x, d.y, d.z).normalized() * float(s[3])
		cam.look_at(at, Vector3.UP)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % s[0]))
	quit()

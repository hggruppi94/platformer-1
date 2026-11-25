extends SceneTree

# Close-ups of the shape-built bosses' baked parts (tools/build_prop_bosses.py, scripts/detail_props.gd): the Gloop
# King's crown, a Time Goblin's cog, Grandfather Tock's clock hat and the Boulderdillo's boulders, and the skins of
# Tuskwinter, Grumblefin, the Dawn Snatcher and the Stormram, and (part three) Old Ember, Glimmerwing, Old
# Bubblebeard, the centipede, the Thornknot and the Off-Beat, and (--enemies) a Crocodillo, a Time Goblin, Tock, a
# Bog Wailer and a Peeper, in a plain studio.
# With --old-props it shoots the same views with the detail pipeline off, to compare. Opens a window:
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_detail.gd -- <folder> [--part3|--enemies] [--old-props]
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
	if path.begins_with("new:"):
		return _made_in_code(path.trim_prefix("new:"))
	var n := (load(path) as PackedScene).instantiate() as Node3D
	if script != "":
		n.set_script(load(script))
		n.set("size", size)
	return n


func _made_in_code(what: String) -> Node3D:
	# The bosses that are built in code rather than from a scene
	match what:
		"ember":
			var e := CharacterBody3D.new()
			e.set_script(load("res://scripts/old_ember.gd"))
			return e
		"star_well", "bubble_spring":
			var gs: GDScript = load("res://scripts/guardian.gd")
			var k: Dictionary = gs.KINDS[what]
			var g := CharacterBody3D.new()
			g.set_script(gs)
			g.set("id", what)
			g.set("title", str(k.name))
			g.set("colour", k.colour)
			g.set("moves", k.moves)
			g.set("height", float(k.height))
			g.set("floats", float(k.floats))
			return g
		"centipede":
			var c := Node3D.new()
			c.set_script(load("res://scripts/centipede_friend.gd"))
			return c
		"thornknot":
			return (load("res://scripts/rootmind.gd") as GDScript).call("thornknot_model")
		"offbeat":
			return (load("res://scripts/off_beat.gd") as GDScript).call("model")
		"wailer":
			var w := CharacterBody3D.new()
			w.set_script(load("res://scripts/bog_wailer.gd"))
			return w
		"peeper":
			var p := Node3D.new()
			p.set_script(load("res://scripts/peeper.gd"))
			return p
	return Node3D.new()


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
	var part3 := "--part3" in OS.get_cmdline_user_args()
	var shots := [
		# name, scene, script, size, place, the part to look at (or "" for the middle), how far, camera direction
		["king", "res://scenes/enemies/gloop_king.tscn", "", 0.0, Vector3(0, 0, 0), "Visual/Body/Crown", 1.3, Vector3(0.5, 0.45, 1)],
		["king_full", "", "", 0.0, Vector3(0, 0, 0), "", 6.0, Vector3(0.5, 0.35, 1)],
		["goblin", "res://scenes/enemies/time_goblin.tscn", "", 0.0, Vector3(20, 0, 0), "", 2.6, Vector3(0.5, 0.3, 1)],
		["tock", "res://scenes/enemies/time_goblin_boss.tscn", "", 0.0, Vector3(40, 0, 0), "Visual/Head/Clock", 2.4, Vector3(0.6, 0.3, 1)],
		["tock_full", "", "", 0.0, Vector3(40, 0, 0), "", 7.0, Vector3(0.5, 0.3, 1)],
		["boulderdillo", "res://scenes/enemies/crocodillo.tscn", "res://scripts/crocodillo_boss.gd", 2.6, Vector3(60, 0, 0), "", 11.0, Vector3(0.7, 0.45, 1)],
		["boulderdillo_back", "", "", 0.0, Vector3(60, 0, 0), "", 10.0, Vector3(0.6, 0.6, -1)],
		["tuskwinter", "res://scenes/enemies/gloop_king.tscn", "res://scripts/frost_gloop.gd", 2.2, Vector3(80, 0, 0), "", 5.0, Vector3(0.6, 0.35, 1)],
		["tuskwinter_close", "", "", 0.0, Vector3(80, 0, 0), "", 2.4, Vector3(0.9, 0.5, 0.5)],
		["grumblefin", "res://scenes/enemies/gloop_king.tscn", "res://scripts/riptide_gloop.gd", 2.4, Vector3(100, 0, 0), "", 5.0, Vector3(0.6, 0.3, 1)],
		["grumblefin_close", "", "", 0.0, Vector3(100, 0, 0), "", 2.4, Vector3(0.9, 0.3, 0.5)],
		["snatcher", "res://scenes/enemies/time_goblin_boss.tscn", "res://scripts/dawn_snatcher.gd", 2.4, Vector3(120, 0, 0), "", 5.0, Vector3(0.6, 0.3, 1)],
		["snatcher_close", "", "", 0.0, Vector3(120, 0, 0), "", 2.2, Vector3(0.8, 0.4, -0.6)],
		["stormram", "res://scenes/enemies/crocodillo.tscn", "res://scripts/stormram.gd", 2.2, Vector3(140, 0, 0), "", 8.0, Vector3(0.8, 0.35, 1)],
		["stormram_close", "", "", 0.0, Vector3(140, 0, 0), "", 3.5, Vector3(1, 0.5, 0.2)],
	]
	if part3:
		# --part3: only the bosses baked in part three
		shots = [
			["ember", "new:ember", "", 0.0, Vector3(0, 0, 0), "", 9.0, Vector3(0.7, 0.4, 1)],
			["ember_close", "", "", 0.0, Vector3(0, 0, 0), "Visual", 4.0, Vector3(0.9, 0.5, 0.6)],
			["glimmerwing", "new:star_well", "", 0.0, Vector3(30, 0, 0), "", 5.0, Vector3(0.6, 0.3, 1)],
			["bubblebeard", "new:bubble_spring", "", 0.0, Vector3(60, 0, 0), "", 5.0, Vector3(0.6, 0.3, 1)],
			["bubblebeard_close", "", "", 0.0, Vector3(60, 0, 0), "", 2.6, Vector3(0.8, 0.4, 0.6)],
			["centipede", "new:centipede", "", 0.0, Vector3(90, 0, 0), "", 6.0, Vector3(0.7, 0.6, 1)],
			["centipede_close", "", "", 0.0, Vector3(90, 0, 0), "", 2.5, Vector3(0.9, 0.5, 0.5)],
			["thornknot", "new:thornknot", "", 0.0, Vector3(120, 0, 0), "", 7.0, Vector3(0.5, 0.45, 1)],
			["thornknot_close", "", "", 0.0, Vector3(120, 0, 0), "", 3.0, Vector3(0.9, 0.4, 0.5)],
			["offbeat", "new:offbeat", "", 0.0, Vector3(150, 0, 0), "", 11.0, Vector3(0.5, 0.25, 1)],
			["offbeat_close", "", "", 0.0, Vector3(150, 0, 0), "", 4.0, Vector3(0.9, 0.2, 0.6)],
		]
	if "--enemies" in OS.get_cmdline_user_args():
		# --enemies: the everyday enemies (scripts/detail_props.gd dress_crocodillo, dress_goblin_skin,
		# dress_bog_wailer, dress_peeper)
		shots = [
			["croc", "res://scenes/enemies/crocodillo.tscn", "", 0.0, Vector3(0, 0, 0), "", 4.5, Vector3(0.7, 0.45, 1)],
			["croc_close", "", "", 0.0, Vector3(0, 0, 0), "", 1.8, Vector3(0.9, 0.5, 0.5)],
			["croc_back", "", "", 0.0, Vector3(0, 0, 0), "", 3.5, Vector3(0.5, 0.8, -1)],
			["goblin", "res://scenes/enemies/time_goblin.tscn", "", 0.0, Vector3(20, 0, 0), "", 2.6, Vector3(0.5, 0.3, 1)],
			["goblin_close", "", "", 0.0, Vector3(20, 0, 0), "", 1.2, Vector3(0.7, 0.2, 1)],
			["tock", "res://scenes/enemies/time_goblin_boss.tscn", "", 0.0, Vector3(40, 0, 0), "", 6.0, Vector3(0.5, 0.3, 1)],
			["wailer", "new:wailer", "", 0.0, Vector3(60, 0, 0), "", 6.0, Vector3(0.6, 0.3, 1)],
			["wailer_close", "", "", 0.0, Vector3(60, 0, 0), "", 2.8, Vector3(0.7, 0.6, 1)],
			["peeper", "new:peeper", "", 0.0, Vector3(80, 0, 0), "", 1.3, Vector3(0.5, 0.35, 1)],
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

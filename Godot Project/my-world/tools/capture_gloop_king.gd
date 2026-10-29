extends SceneTree

# Screenshots of the Gloop King and the restyled Gloops (tools/build_gloop.gd). First a little studio like Hayden's
# picture (a wet dark floor, teal and purple lights), then the real town at midday and at night. Opens a window
# (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_gloop_king.gd -- <output folder> [studio]
#
# Pass "studio" to skip the town shots. Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.gloop_king_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://gloop_king_shots"
var studio_only := false
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	studio_only = args.has("studio")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	await _studio()
	if not studio_only:
		await _town()
	_finish()


func _studio() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.3, 0.45)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.4
	# A bright, colourful sky for the reflections, so the goo has something to shine with
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.1, 0.5)
	sm.sky_horizon_color = Color(0.1, 0.6, 0.7)
	sm.ground_bottom_color = Color(0.05, 0.03, 0.1)
	sm.ground_horizon_color = Color(0.4, 0.2, 0.6)
	sky.sky_material = sm
	e.sky = sky
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment = e
	stage.add_child(env)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.06, 0.06, 0.08)
	fm.roughness = 0.15
	fm.metallic = 0.5
	floor_mi.material_override = fm
	stage.add_child(floor_mi)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.4
	key.light_color = Color(1.0, 0.92, 0.8)
	key.shadow_enabled = true
	stage.add_child(key)
	key.rotation_degrees = Vector3(-40, 30, 0)
	for l in [[Vector3(-3, 2.5, 1.5), Color(0.2, 0.7, 1.0)], [Vector3(3, 2.0, -0.5), Color(0.7, 0.3, 1.0)],
			[Vector3(0.5, 3.5, 3.5), Color(1.0, 0.85, 0.5)]]:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = 3.0
		o.omni_range = 9.0
		stage.add_child(o)
	var king := (load("res://scenes/enemies/gloop_king.tscn") as PackedScene).instantiate() as Node3D
	king.set("size", 1.0)
	stage.add_child(king)
	king.set_physics_process(false)
	cam = Camera3D.new()
	cam.fov = 35
	stage.add_child(cam)
	cam.make_current()
	for i in 150:                                  # let the drips get going
		await _frame()
	await _view("01_king_like_the_picture", Vector3(0.0, 0.62, 2.9), Vector3(0, 0.5, 0))
	await _view("02_king_three_quarter", Vector3(1.9, 1.0, 2.2), Vector3(0, 0.5, 0))
	await _view("03_king_side", Vector3(2.9, 0.7, 0.2), Vector3(0, 0.5, 0))
	await _view("04_king_back", Vector3(-1.2, 1.3, -2.6), Vector3(0, 0.55, 0))
	await _view("05_drips_close_up", Vector3(0.7, 0.45, 1.3), Vector3(0.05, 0.33, 0.2))
	# The King with two of his Gloops (ordinary Gloops have no crown)
	king.scale = Vector3.ONE * 1.8
	(king.get_node("Puddle") as Node3D).scale = Vector3(1, 1, 0.85)
	for x in [-1.6, 1.6]:
		var g := (load("res://scenes/enemies/gloop.tscn") as PackedScene).instantiate() as Node3D
		stage.add_child(g)
		g.set_physics_process(false)
		g.position = Vector3(x, 0, 0.9)
		(g.get_node("Visual") as Node3D).rotation.y = -0.35 * signf(x)
	for i in 20:
		await _frame()
	await _view("06_king_and_his_gloops", Vector3(0.0, 1.4, 5.6), Vector3(0, 0.75, 0))
	stage.queue_free()
	await process_frame


func _town() -> void:
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	root.get_node("Settings").tips = false
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as Node3D
	player.get_node("HUD").visible = false
	var king := town.find_child("The Gloop King", true, false) as Node3D
	if king == null:
		print("NO KING IN TOWN")
		return
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	cam.make_current()
	# Hold the Gloops still near him for the picture, the hero watching from a few steps away
	for g in town.find_child("Enemies", true, false).get_children():
		g.set_physics_process(false)
	player.global_position = king.global_position + Vector3(2.5, 1.5, 9.0)
	var k := king.global_position
	for i in 30:
		await process_frame
	var front := k + Vector3(3.0, 3.0, 8.5)
	_face(town, front)
	await _view("07_in_town_the_king", front, k + Vector3(0, 1.4, 0))
	var court_cam := k + Vector3(-9.0, 6.5, 13.0)
	_face(town, court_cam)
	await _view("08_in_town_his_court", court_cam, k + Vector3(0, 0.5, 0))
	# His belly-flop: the ring of goo spreading out (jump over it)
	cam.global_position = k + Vector3(8.0, 9.0, 14.0)
	cam.look_at(k + Vector3(0, 0.5, 0))
	king.call("_land")
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("09_belly_flop_goo_ring.png"))
	print("SHOT 09_belly_flop_goo_ring")
	var g0 := town.find_child("Gloop 0", true, false) as Node3D
	var gp := g0.global_position
	_face(town, gp + Vector3(1.0, 1.0, 2.6))
	await _view("10_in_town_a_gloop", gp + Vector3(1.0, 1.0, 2.6), gp + Vector3(0, 0.45, 0))
	root.get_node("Clock").set_time(1, 22 * 60.0, true)
	for i in 30:
		await _frame()
	await _view("11_at_night_the_king", front, k + Vector3(0, 1.4, 0))


func _face(town: Node, at: Vector3) -> void:
	# Turn every Gloop to look at the camera, so the pictures show their faces
	for g in town.find_child("Enemies", true, false).get_children():
		if g.has_method("_drip"):
			var d: Vector3 = at - (g as Node3D).global_position
			(g.get_node("Visual") as Node3D).rotation.y = atan2(d.x, d.z)


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8:
		await _frame()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frame() -> void:
	# The Gloops are held still (physics off), so keep their bobbing and dripping going by hand
	await process_frame
	for g in root.get_tree().get_nodes_in_group("enemies"):
		if g.has_method("_drip") and not g.is_physics_processing():
			g._t += 1.0 / 60.0
			g._animate(1.0 / 60.0, 0.0, false)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()

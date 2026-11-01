extends SceneTree

# Screenshots of the Time Goblins and Grandfather Tock (tools/build_time_goblin.gd): a little studio first, then the
# Goblin Clockyard in town by day, a goblin blinking back in time, Tock's chime ring, and the clockyard at night.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_time_goblins.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.time_goblins_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://time_goblin_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	await _studio()
	await _town()
	_finish()


func _studio() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.04, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.45, 0.6)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	env.environment = e
	stage.add_child(env)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.12, 0.1, 0.16)
	fm.roughness = 0.4
	floor_mi.material_override = fm
	stage.add_child(floor_mi)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.93, 0.82)
	key.shadow_enabled = true
	stage.add_child(key)
	key.rotation_degrees = Vector3(-40, 25, 0)
	for l in [[Vector3(-3, 2.5, 1.5), Color(0.2, 0.9, 0.9)], [Vector3(3, 2.0, -0.5), Color(0.7, 0.35, 1.0)]]:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = 2.5
		o.omni_range = 9.0
		stage.add_child(o)
	var g := (load("res://scenes/enemies/time_goblin.tscn") as PackedScene).instantiate() as Node3D
	stage.add_child(g)
	g.set_physics_process(false)
	cam = Camera3D.new()
	cam.fov = 35
	stage.add_child(cam)
	cam.make_current()
	await _view("01_time_goblin", Vector3(0.0, 0.75, 3.0), Vector3(0, 0.6, 0))
	await _view("02_time_goblin_three_quarter", Vector3(1.9, 1.1, 2.2), Vector3(0, 0.6, 0))
	await _view("03_pocket_watch_close_up", Vector3(0.25, 0.6, 1.0), Vector3(0, 0.5, 0.2))
	g.position.x = -1.3
	var tock := (load("res://scenes/enemies/time_goblin_boss.tscn") as PackedScene).instantiate() as Node3D
	tock.set("size", 2.4)
	stage.add_child(tock)
	tock.set_physics_process(false)
	tock.position = Vector3(1.4, 0, -0.8)
	(tock.get_node("Visual") as Node3D).scale = Vector3.ONE * 2.4
	(tock.get_node("Visual") as Node3D).rotation.y = -0.3
	(g.get_node("Visual") as Node3D).rotation.y = 0.4
	await _view("04_grandfather_tock_and_a_goblin", Vector3(0.0, 2.6, 8.5), Vector3(0.3, 1.9, 0))
	await _view("05_tock_close_up", Vector3(1.9, 4.3, 2.7), Vector3(1.4, 3.6, -0.8))
	stage.queue_free()
	await process_frame


func _town() -> void:
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	root.get_node("Settings").tips = false
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as Node3D
	player.get_node("HUD").visible = false
	var yard := town.get_node("Goblin Clockyard") as Node3D
	var tock := town.find_child("Grandfather Tock", true, false) as Node3D
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	cam.make_current()
	for e in town.find_child("Enemies", true, false).get_children():
		e.set_physics_process(false)
	var y := yard.global_position
	player.global_position = y + Vector3(3, 1.5, 15)
	for i in 30:
		await process_frame
	var wide := y + Vector3(6, 9, 22)
	_face(town, wide)
	await _view("06_the_goblin_clockyard", wide, y + Vector3(0, 1.0, 0))
	var near := tock.global_position + Vector3(2.5, 3.5, 8.0)
	_face(town, near)
	await _view("07_tock_in_his_clockyard", near, tock.global_position + Vector3(0, 2.2, 0))
	# A goblin blinking back in time: walk it along, then rewind and catch the ghosts
	var g := town.find_child("Time Goblin 0", true, false) as Node3D
	var start := g.global_position
	g._hist.clear()
	for i in 30:
		g.global_position = start + Vector3(i * 0.2, 0, 0)
		g._hist_t = 0.0
		g._remember(0.0)
	g._blink_cd = 0.0
	var shot_at := start + Vector3(3.0, 2.0, 6.0)
	cam.global_position = shot_at
	cam.look_at(start + Vector3(3.0, 0.6, 0))
	_face(town, shot_at)
	Engine.time_scale = 0.2
	g.blink()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("08_blinking_back_in_time.png"))
	Engine.time_scale = 1.0
	print("SHOT 08_blinking_back_in_time")
	# Tock's chime ring rolling out
	cam.global_position = tock.global_position + Vector3(9.0, 8.0, 12.0)
	cam.look_at(tock.global_position + Vector3(0, 0.5, 0))
	Engine.time_scale = 0.2
	tock.call("_strike")
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("09_tock_chime_ring.png"))
	Engine.time_scale = 1.0
	print("SHOT 09_tock_chime_ring")
	root.get_node("Clock").set_time(1, 22 * 60.0, true)
	for i in 30:
		await process_frame
	await _view("10_clockyard_at_night", near, tock.global_position + Vector3(0, 2.2, 0))


func _face(town: Node, at: Vector3) -> void:
	for g in town.get_tree().get_nodes_in_group("time_goblins"):
		var d: Vector3 = at - (g as Node3D).global_position
		(g.get_node("Visual") as Node3D).rotation.y = atan2(d.x, d.z)


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Engine.time_scale = 1.0
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()

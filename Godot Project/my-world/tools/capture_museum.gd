extends SceneTree

# Pictures of the Void's Museum and the plateau's waterfall beside it (outside from above, the way up, the falls' side,
# then inside), to check how the two fit together (20 Nov 2026, scripts/falls_museum.gd).
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_museum.gd -- <folder> [--old-props] [--outside]
#       [--garden]   (the Museum Garden outside and the Garden Door inside, scripts/museum_garden.gd)
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.museum_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.museum_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://museum_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1800.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var args := OS.get_cmdline_user_args()
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	change_scene_to_file(TOWN)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(40, 2, 120)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()
	var s := current_scene
	var views := []
	var m := (s.get_node("Museum") as Node3D).global_position
	views.append(["01_above", m + Vector3(6, 45, 30), m + Vector3(-4, 0, 4), 11.0])
	views.append(["02_approach", m + Vector3(17, 5, 17), m + Vector3(3, 3, 3), 11.0])
	views.append(["03_falls_side", m + Vector3(8, 6, 22), m + Vector3(-2, 2, 9), 11.0])
	views.append(["04_high_east", m + Vector3(30, 14, 0), m + Vector3(-4, 3, 0), 11.0])
	if "--garden" in args:
		var GARDEN := load("res://scripts/museum_garden.gd")
		var mus := s.get_node("Museum") as Node3D
		var door := GARDEN.spot(s, mus, GARDEN.LOCAL_DOOR, 8.5) as Vector3
		var arbor := GARDEN.spot(s, mus, GARDEN.LOCAL_DOOR, 15.5) as Vector3
		views = [["20_garden_above", m + GARDEN.direction(mus, 0.2) * 30.0 + Vector3(0, 26, 0), m + GARDEN.direction(mus, 0.2) * 11.0, 11.0],
			["21_garden_door", arbor + Vector3(0, 2.2, 0), door + Vector3(0, 1.6, 0), 11.0],
			["22_garden_walk", GARDEN.spot(s, mus, -0.35, 17.0) + Vector3(0, 3, 0), GARDEN.spot(s, mus, 0.4, 12.0), 11.0]]
		for id: String in GARDEN.EXHIBITS:
			var e: Dictionary = GARDEN.EXHIBITS[id]
			var at := GARDEN.spot(s, mus, float(e["theta"]), float(e["r"])) as Vector3
			var toward := (m - at)
			toward.y = 0
			var eye := at + toward.normalized() * 5.0 + toward.normalized().cross(Vector3.UP) * 1.5 + Vector3(0, 2.4, 0)
			views.append(["23_" + id, eye, at + Vector3(0, 0.9, 0), 11.0])
		views.append(["29_garden_dusk", m + GARDEN.direction(mus, 0.3) * 24.0 + Vector3(0, 6, 0), m + GARDEN.direction(mus, 0.3) * 11.0, 19.5])
	for v in views:
		clock.set_time(3, v[3] * 60.0, true)
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])
	if not "--outside" in args:
		change_scene_to_file("res://scenes/interiors/museum.tscn")
		for i in 16:
			await process_frame
		await create_timer(2.0).timeout
		for c in root.find_children("*", "CanvasLayer", true, false):
			(c as CanvasLayer).visible = false
		var pl := current_scene.find_child("Player", true, false) as Node3D
		if pl:
			pl.visible = false
		cam = Camera3D.new()
		cam.fov = 60
		current_scene.add_child(cam)
		cam.make_current()
		var inside := [["10_inside_door", Vector3(0, 2.2, 13.5), Vector3(-4, 2, -3)], ["11_inside_falls", Vector3(3, 3, 2), Vector3(-8, 2.5, -5.5)],
				["12_inside_stream", Vector3(-3, 3, 7), Vector3(-10, 1, 3)]]
		if "--garden" in args:
			var a := 0.884
			inside = [["30_inside_garden_door", Vector3(cos(a), 0, sin(a)) * 6.0 + Vector3(-2, 2.3, 1), Vector3(cos(a), 0, sin(a)) * 15.0 + Vector3(0, 1.6, 0)]]
		for v in inside:
			cam.global_position = v[1]
			cam.look_at(v[2])
			await _shot(v[0])
	_finish()
func _shot(file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(0)

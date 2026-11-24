extends SceneTree

# Shots of the seven virtue trials (scripts/virtue_trial.gd) and the Skyreach Trail's Waystone portals and gates of
# light (scripts/skyreach_trail.gd). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_virtue_trials.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.virtue_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.virtue_capture_backup.cfg"
const SKYREACH := "res://scenes/bosses/skyreach_trail.tscn"
const TRIAL_SCENE := "res://scenes/bosses/virtue_trial.tscn"

var out_dir := "user://virtue_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game._resume = {}
	game.hold_saves = true
	game.sparkles = 40
	root.get_node("Settings").tips = false
	root.get_node("Clock").set("pulls_home", false)
	var virtue: GDScript = load("res://scripts/virtue_trial.gd")

	# The trail: the first Waystone's portal and the gate of light past it
	change_scene_to_file(SKYREACH)
	await _frames(60)
	await create_timer(1.0).timeout
	var s := current_scene as Node3D
	_hide_hud(s)
	var T: GDScript = s.get_script()
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var stone := (s.get("stones") as Array)[1] as Node3D
	var ga := (float(T.STONES[1]) + float(T.GATE_AFTER)) * PI
	var gate_at: Vector3 = T.trail_point(ga)
	p.global_position = T.trail_point(ga - 0.2) + Vector3(0, 1.0, 0)
	cam = _cam(s)
	var back: Vector3 = T.trail_point(float(T.STONES[1]) * PI - 0.12)
	cam.global_position = back + Vector3(0, 3.2, 0) + T.out_dir(float(T.STONES[1]) * PI) * 2.0
	cam.look_at((stone.global_position + gate_at) * 0.5 + Vector3(0, 1.2, 0), Vector3.UP)
	await create_timer(1.5).timeout
	await _shot("01_waystone_and_gate")
	p.global_position = T.trail_point(ga - 0.05) + Vector3(0, 1.0, 0)
	cam.global_position = T.trail_point(ga - 0.13) + Vector3(0, 2.4, 0) + T.out_dir(ga) * 1.2
	cam.look_at(gate_at + Vector3(0, 2.0, 0), Vector3.UP)
	await create_timer(0.6).timeout
	await _shot("02_gate_of_light")

	# Each trial, seen from above the way in
	var views := {
		"humility": [Vector3(9, 9, -2), Vector3(0, 1, 26)],
		"patience": [Vector3(7, 8, 2), Vector3(0, 0, 28)],
		"kindness": [Vector3(0, 22, -2), Vector3(0, 0, 22)],
		"temperance": [Vector3(0, 14, 0), Vector3(0, 0, 24)],
		"charity": [Vector3(0, 18, -1), Vector3(0, 0, 22)],
		"diligence": [Vector3(20, 14, -4), Vector3(0, 9, 24)],
		"purity": [Vector3(6, 10, 0), Vector3(0, 0, 30)],
	}
	for k in virtue.VIRTUES.size():
		var vid := str(virtue.VIRTUES[k].id)
		(current_scene as Node).call("enter_trial", k)
		while current_scene == null or current_scene.scene_file_path != TRIAL_SCENE:
			await process_frame
		await _frames(30)
		await create_timer(1.2).timeout
		s = current_scene as Node3D
		_hide_hud(s)
		cam = _cam(s)
		var v: Array = views[vid]
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		if vid == "patience":
			# (two stones already out of the clouds, the third coming)
			s.call("reveal_next")
			s.call("reveal_next")
		elif vid == "kindness":
			var lamb := s.get_node("Lamb") as Node3D
			lamb.position = Vector3(-1.0, 0, 21.0)
			s.find_child("Player", true, false).global_position = Vector3(0, 1.0, 23.0)
		elif vid == "charity":
			s.call("give_all")
		await create_timer(1.0).timeout
		await _shot("%02d_%s" % [k + 3, vid])
		if vid == "charity":
			var c := (s.get("cherubs") as Array)[0] as Node3D
			cam.global_position = c.global_position + Vector3(2.5, 2.0, -3.0)
			cam.look_at(c.global_position + Vector3(0, 0.9, 0), Vector3.UP)
			await create_timer(0.5).timeout
			await _shot("%02d_%s_cherub" % [k + 3, vid])
		s.call("go_home")
		while current_scene == null or current_scene.scene_file_path != SKYREACH:
			await process_frame
		await _frames(10)
	_finish()


func _hide_hud(s: Node) -> void:
	var p := s.find_child("Player", true, false)
	if p and p.get_node_or_null("HUD"):
		p.get_node("HUD").visible = false


func _cam(s: Node3D) -> Camera3D:
	var c := Camera3D.new()
	c.fov = 60
	c.far = 800.0
	s.add_child(c)
	c.make_current()
	return c


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()

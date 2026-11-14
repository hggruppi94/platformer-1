extends SceneTree

# Screenshots of the pull home to Stars Hollow after mending a world (scripts/home_calls.gd; tools/test_home_calls.gd
# checks it): the green with the crack by the old oak shut, and the chapters' things to find round town (wind chimes,
# plushies, street lamps before and after, bottles by the pond). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_home_calls.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.home_calls_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.home_calls_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://home_calls_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
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
	game.hero["name"] = "Sofi"
	root.get_node("Settings").tips = false
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	dialogue.set_flag("oak_woken")
	dialogue.set_flag("earth_crack_seen")
	dialogue.set_flag("cut_crack_earth")
	var calls: Node = root.get_node("Portals").home_calls
	calls.chapter = "shard_isle"
	for q in ["home_chimes", "home_plushies", "home_lamps", "home_bottles"]:
		dialogue.set_flag(q + "_start")
	for f in ["chimes_asked", "plush_asked", "lamps_asked", "bottles_asked"]:
		dialogue.set_flag(f)
	root.get_node("Clock").set_earth_time(10 * 60.0, true)
	game.go(EARTH, "Entrance", "")
	await _frames(90)
	quests.check()
	await create_timer(3.0).timeout
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var oak := s.get_node("Portal Home/Old Oak") as Node3D
	_cam_in(s)
	_look(oak.global_position + Vector3(9, 5, 12), oak.global_position + Vector3(0, 1.0, 3.0))
	await _shot("01_crack_shut_by_the_old_oak")
	p.get_node("HUD").visible = false
	var holder := s.get_node("Home Calls")
	var picks := [["chime_1", "02_wind_chime"], ["plush_1", "03_plushie_bear"], ["plush_2", "04_plushie_bunny"],
		["lamp_1", "05_street_lamp_out"], ["bottle_2", "07_bottle_by_the_pond"]]
	for k in picks:
		var spot := holder.get_node("Home Spot " + str(k[0])) as Node3D
		p.global_position = spot.global_position + Vector3(0, 0.6, 2.0)
		await create_timer(0.6).timeout
		var tall := 1.6 if str(k[0]).begins_with("lamp") else 0.4
		_look(spot.global_position + Vector3(2.2, 1.4 + tall, 3.0), spot.global_position + Vector3(0, tall, 0))
		await _shot(str(k[1]))
		if str(k[0]) == "lamp_1":
			spot.call("use")
			await create_timer(0.5).timeout
			root.get_node("Clock").set_earth_time(20 * 60.0, true)
			await create_timer(1.5).timeout
			await _shot("06_street_lamp_lit_at_night")
			root.get_node("Clock").set_earth_time(10 * 60.0, true)
			await create_timer(1.0).timeout
	_finish()


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
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

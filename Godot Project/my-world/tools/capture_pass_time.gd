extends SceneTree

# Pictures of Pause > "Pass the time" and "Go to the Void at midnight" (scripts/pass_time.gd): the pause menu on Earth
# just after being pulled home, the Pass the time page, the clock racing round, Stars Hollow after, and the page in
# the Void.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_pass_time.gd -- <folder>
#
# Needs a window (no --headless). Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.pass_time_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.pass_time_capture_backup.cfg"

var out_dir := "user://pass_time_shots"
var _had_save := false
var clock: Node
var pause: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
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
	root.get_node("Settings").tips = false
	clock = root.get_node("Clock")
	pause = root.get_node("PauseMenu")
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	root.get_node("Dialogue").flags["oak_woken"] = true
	root.get_node("Dialogue").flags["earth_crack_seen"] = true
	clock.on_earth = true
	clock.set_earth_time(10 * 60.0 + 10.0, true)
	game.go("res://scenes/earth/earth.tscn", "Entrance", "")
	await _frames(60)
	await create_timer(1.5).timeout
	pause.open()
	await create_timer(0.4).timeout
	await _shot("01_pause_menu_on_earth")
	pause._show_time()
	await create_timer(0.4).timeout
	await _shot("02_pass_the_time_on_earth")
	var evening = null
	for c in load("res://scripts/pass_time.gd").choices():
		if str(c.text).begins_with("Until evening"):
			evening = c
	pause.close()
	load("res://scripts/pass_time.gd").run(float(evening.minutes))
	await create_timer(1.3).timeout
	await _shot("03_time_passes")
	await create_timer(2.5).timeout
	await _shot("04_stars_hollow_at_6_pm")
	load("res://scripts/pass_time.gd").go_to_the_void()
	var t := 0.0
	while (current_scene == null or current_scene.scene_file_path != "res://scenes/town/town.tscn") and t < 20.0:
		await create_timer(0.1).timeout
		t += 0.1
	await _frames(60)
	await create_timer(4.0).timeout
	await _shot("05_straight_to_the_void")
	clock.set_time(clock.day, 13 * 60.0 + 20.0, true)
	await create_timer(0.5).timeout
	pause.open()
	pause._show_time()
	await create_timer(0.4).timeout
	await _shot("06_pass_the_time_in_the_void")
	pause.close()
	_finish()


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

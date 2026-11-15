extends SceneTree

# Before and after shots of the boss finish (scripts/boss_bar.gd _finish_blow, 15 Nov 2026): Grandfather Tock popped
# without it ("before") and with it ("after"), a moment after the last hit. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_finish.gd -- <output folder> before
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_finish.gd -- <output folder> after
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.boss_finish_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.boss_finish_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://boss_finish_shots"
var cam: Camera3D
var _had_save := false
var which := "after"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		which = args[1]
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
	game._resume = {}
	root.get_node("Settings").tips = false
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	root.get_node("Clock").set_time(2, 13 * 60.0, true)
	root.get_node("Portals").quakes = ["shard_isle"]  # (no crack cutscene in the middle of the shot)
	if true:                                   # (one shot a run: a second town load mid-run left Tock half gone)
		change_scene_to_file(TOWN)
		await _frames(60)
		await create_timer(1.5).timeout
		var s := current_scene as Node3D
		var p := s.find_child("Player", true, false) as CharacterBody3D
		p.get_node("HUD").visible = false
		var tock := s.find_child("Grandfather Tock", true, false) as CharacterBody3D
		p.global_position = tock.global_position + Vector3(0, 1.0, 9.0)
		tock.set_physics_process(false)
		cam = Camera3D.new()
		cam.fov = 55
		s.add_child(cam)
		cam.make_current()
		cam.global_position = tock.global_position + Vector3(5.5, 3.2, 7.5)
		cam.look_at(tock.global_position + Vector3(0, 2.0, 0), Vector3.UP)
		await create_timer(0.8).timeout
		if which == "before":
			tock._bar.finished = true                  # what popping him looked like without the finish
			tock._bar.set("_seen_up", false)
		tock.set_physics_process(true)
		tock.shot(tock.stomps_to_defeat - tock.hits, tock.global_position, Vector3.FORWARD)
		for t in 4:                                # (a few, as the ring rolls out: the cloud's window draws slowly)
			await create_timer(0.2, true, false, true).timeout
			await _shot("%s_tock_popped_%d" % [which, t])
	_finish()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Engine.time_scale = 1.0
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()

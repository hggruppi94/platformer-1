extends SceneTree

# Screenshots of following quests and jobs, the notice board tutorial and the first look round the Void
# (tools/test_following.gd checks them): Nina at the notice board, the board's Follow choice, the Quests sheet with
# Follow buttons on quests and jobs, the HUD's to-do list with two things followed, the map with stars for both, and
# the Void's first look (scripts/place_intro.gd). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_following.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.following_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://following_shots"
var game: Node
var clock: Node
var dialogue: Node
var quests: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	var jobs := root.get_node("EarthJobs")
	var settings := root.get_node("Settings")
	settings.tips = false
	game.hold_saves = true
	game._resume = {}
	game.pending_message = ""
	dialogue.reset()
	quests.reset()
	clock.pulls_home = false
	clock.on_earth = true
	clock.set_earth_time(10 * 60.0, true)

	# --- Earth: the notice board tutorial on the First Night's board step ---
	change_scene_to_file(EARTH)
	await _frames(12)
	var earth := current_scene as Node3D
	var player := earth.find_child("Player", true, false) as Node3D
	dialogue.flags["first_night_start"] = true
	for f in ["fn_v2", "fn_v3", "fn_nina", "fn_palmer", "fn_folk"]:
		dialogue.flags[f] = true
	quests.check()
	jobs.roll(5)
	jobs._place_props()
	var board := earth.get_node("Notice Board") as Node3D
	var out := (Vector3(0, 0, 14) - board.global_position).normalized()
	player.global_position = board.global_position + out * 2.2 + Vector3.UP
	player.get_node("Visual").look_at(board.global_position, Vector3.UP)
	await _frames(30)
	dialogue.talk_to(board.get_node("Request Talk"))
	await _frames(4)
	dialogue._finish_typing()
	await _shot("01_nina_explains_the_notice_board", 30)
	for i in 30:
		if dialogue._choosing:
			break
		dialogue._finish_typing()
		dialogue._next()
		await _frames(2)
	await _shot("02_follow_a_job_from_the_board", 20)
	dialogue.current_choices()[0].pressed.emit()
	await _frames(20)
	quests.follow(jobs.key_of(jobs.list[1]), true)
	await _frames(20)
	await _shot("03_two_jobs_followed_on_the_to_do_list", 10)
	root.get_node("PlayerMenu").open("map")
	await _frames(10)
	await _shot("04_map_stars_for_both_jobs", 4)
	root.get_node("PlayerMenu").close()
	await _frames(6)
	root.get_node("PlayerMenu").open("quests")
	await _frames(10)
	await _shot("05_quests_sheet_follow_buttons", 4)
	root.get_node("PlayerMenu").close()
	await _frames(6)

	# --- The Void's first look ---
	clock.on_earth = false
	clock.set_time(2, 7 * 60.0 + 10.0, true)
	change_scene_to_file(TOWN)
	await _frames(12)
	var town := current_scene as Node3D
	var portal := town.find_child("Portal to Earth", true, false) as Node3D
	var p := town.find_child("Player", true, false) as Node3D
	if portal:
		p.global_position = portal.global_position + Vector3(0, 1, 4)
	await _frames(20)
	var fn := root.get_node("FirstNight")
	dialogue.flags.erase("void_intro_seen")
	fn.void_intro(Callable(), true)
	var stamps := [1.0, 3.4, 6.6, 10.4]
	var t := 0.0
	for i in stamps.size():
		await create_timer(stamps[i] - t).timeout
		t = stamps[i]
		await _shot("%02d_void_first_look_%d" % [6 + i, i + 1], 1)
	fn.intro.stop()
	_finish()


func _shot(file: String, settle := 8) -> void:
	await _frames(settle)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()

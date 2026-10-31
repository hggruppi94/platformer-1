extends SceneTree

# Screenshots of nights 3 to 7 (quests/night_3.json to night_7.json): each night's arrival, the friend who meets you
# (Bramble, Dash, the Astronaut, Rex and Mr. Palmer) mid-talk, and the Goals and Quests pages with the night's list.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_later_nights.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.later_nights_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const FRIENDS := {3: "bramble", 4: "dash", 5: "astronaut", 6: "rex", 7: "mr_palmer"}

var out_dir := "user://later_nights_shots"
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
	create_timer(2400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	var requests := root.get_node("Requests")
	root.get_node("Settings").tips = false
	clock.pulls_home = false
	dialogue.reset()
	quests.reset()
	game.needs_creator = false
	game.riding = false
	dialogue.set_flag("first_night_start")
	quests.check()
	for i in 30:
		if quests.is_done("first_night"):
			break
		quests.skip("first_night")
	requests.nights = 2
	await _new_visit()
	for i in 10:
		if quests.is_done("night_2"):
			break
		quests.skip("night_2")
	var menu := root.get_node("PlayerMenu")
	for n in range(3, 8):
		requests.nights = n
		await _new_visit()
		await create_timer(3.6).timeout
		await _shot("%d0_night_%d_arrives" % [n, n])
		var t := _talker(FRIENDS[n])
		if t:
			var body := t.get_parent() as Node3D
			var player := current_scene.find_child("Player", true, false) as Node3D
			player.global_position = body.global_position + body.global_basis.z * 2.4 + Vector3(0, 0.8, 0)
			await _frames(10)
			dialogue.talk_to(t)
			await _frames(4)
			dialogue._finish_typing()
			await _shot("%d1_night_%d_%s" % [n, n, FRIENDS[n]])
			while dialogue.is_active():
				dialogue._finish_typing()
				dialogue._next()
				await _frames(1)
		await _frames(6)
		menu.open("goals" if n % 2 == 1 else "quests")
		await _shot("%d2_night_%d_%s_page" % [n, n, "goals" if n % 2 == 1 else "quests"])
		menu.close()
		for i in 10:
			if quests.is_done("night_%d" % n):
				break
			quests.skip("night_%d" % n)
	_finish()


func _new_visit() -> void:
	clock.set_earth_time(0.3 * 60.0, true)
	clock.set_time(clock.day + 1, 9 * 60.0, true)
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH, 600)
	change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN, 600)


func _talker(id: String) -> Area3D:
	for a in current_scene.find_children("*", "Area3D", true, false):
		if a.get("character_id") == id:
			return a
	return null


func _shot(file: String, settle := 8) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	quit(0)

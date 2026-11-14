extends SceneTree

# Pictures for "Stop text windows getting cut off" (Hayden, 14 Nov 2026: "when melanie asks you to fix the slide, the
# window is cut off", "we need to fix mr palmers' window/quest"): Mr. Palmer's Town Hall window from the Market Square
# and up close, Melanie's ask and the quest card it starts, the voice in your mind under the clock, and the to-do list
# with three quests followed at the biggest HUD and a big text size.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_text_windows.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.text_windows_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.text_windows_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://text_windows_shots"
var cam: Camera3D
var game: Node
var clock: Node
var dialogue: Node
var quests: Node
var episodes: Node
var settings: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	settings = root.get_node("Settings")
	episodes = root.get_node("Watches").get_node("Episodes")
	settings.tips = false
	dialogue.reset()
	quests.reset()
	game.needs_creator = false
	game._resume = {}
	game.riding = false
	game.items.clear()
	game.outfits = {"hero": {}}
	clock.pulls_home = false
	dialogue.set_flag("first_night_start")
	quests.check()
	for i in 30:
		if quests.is_done("first_night"):
			break
		quests.skip("first_night")
	await _to_town(10 * 60.0)
	_make_cam()
	var w := current_scene.find_child("Palmers Window", true, false) as Node3D
	var pane := current_scene.find_child("Palmers Window Pane", true, false) as Node3D
	var sq := current_scene.get_node("Market Square") as Node3D
	var fwd := w.global_basis.z.normalized()
	var player := _player()
	player.global_position = sq.global_position + Vector3(0, 1.0, -8.0)
	await _frames(10)
	await _view("01_palmers_window_from_the_square", sq.global_position + Vector3(0, 4.0, 0), pane.global_position, 20)
	await _view("02_palmers_window_up_close", w.global_position + fwd * 7.0 + Vector3(0, 2.5, 0), pane.global_position, 10)
	# Melanie's ask, and the quest card it starts
	var n: Node3D = episodes.guest("melanie")
	var t: Node3D = n
	for c in n.find_children("*", "Node3D", true, false):
		if c.get("character_id") == "melanie":
			t = c
			break
	player.global_position = n.global_position + n.global_basis.z * 2.0 + Vector3(0, 1.0, 0)
	_face(player, n.global_position)
	cam.queue_free()
	cam = null
	await _frames(10)
	dialogue.talk_to(t)
	for i in 20:
		await _frames(3)
		dialogue._finish_typing()
		if dialogue._choosing:
			break
		dialogue._next()
	await _shot("03_melanie_asks", 6)
	dialogue.current_choices()[0].pressed.emit()
	for i in 20:
		await _frames(3)
		if not dialogue.is_active():
			break
		dialogue._finish_typing()
		dialogue._next()
	for i in 300:
		await process_frame
		if quests.note_text() != "":
			break
	await _shot("04_the_slide_quest_card", 40)
	quests._note_time = 0.0
	# The voice in your mind, under the clock (the HUD at its biggest)
	settings.set_value("hud_size", 1.2)
	await _frames(10)
	root.get_node("DivineMind").say(["Do you feel that? The Shift has broken somewhere new."])
	await _shot("05_voice_under_the_clock", 30)
	root.get_node("DivineMind").clear()
	# The to-do list with three quests followed, at a big text size
	settings.set_value("text_scale", 1.5)
	for id in quests._order:
		if quests.is_started(id) and not quests.is_done(id):
			quests.follow(id, true)
	for f in ["dogs_start", "make_start", "summer_splash_start"]:
		dialogue.set_flag(f)
	quests.check()
	for id in quests._order:
		if quests.is_started(id) and not quests.is_done(id):
			quests.follow(id, true)
	await _settle()
	await _shot("06_todo_list_big_text", 30)
	_finish()


func _flags(names: Array) -> void:
	for f in names:
		dialogue.set_flag(f)
		quests.check()


func _to_town(galaxity_minutes: float) -> void:
	if cam and is_instance_valid(cam):
		cam.queue_free()
	cam = null
	clock.set_earth_time(0.25 * 60.0, true)
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH)
	change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN)
	clock.set_time(clock.day, galaxity_minutes, true)
	await _settle()


func _guest_shot(file: String, id: String, dist: float, offset := Vector3.ZERO) -> void:
	var n: Node3D = episodes.guest(id)
	if n == null:
		print("NO GUEST ", id)
		return
	var player := _player()
	player.global_position = n.global_position + n.global_basis.z * 2.0 + Vector3(0, 1.0, 0)
	_face(player, n.global_position)
	await _frames(10)
	var front := n.global_basis.z.normalized()
	await _view(file, n.global_position + front * dist + n.global_basis.x * 1.2 + Vector3(0, 1.5, 0) + offset,
		n.global_position + Vector3(0, 1.0, 0), 15)


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _face(n: Node3D, at: Vector3) -> void:
	var d := at - n.global_position
	n.rotation.y = atan2(d.x, d.z)


func _make_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		_make_cam()
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 8) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _settle() -> void:
	await create_timer(0.45).timeout
	await _frames(3)


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
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.remove_absolute(SETTINGS)
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()

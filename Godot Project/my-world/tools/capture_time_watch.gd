extends SceneTree

# Screenshots of the hero's watch as the clock (scripts/watch_face.gd, scripts/time_watch.gd) and Rex and Dash's lab
# quest (scripts/lab.gd): the Shift Watch on the HUD on an Earth evening, checking it, the watch in Galaxity during
# the Shift, the Time Keeper, the lab from the front and inside (the Swap-o-Tron, the chalkboard, Hound Hero), a time
# ripple with the watch's pointer, Rex and Rook in the pods, the flash, and the Lab Goggles.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_time_watch.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.time_watch_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://time_watch_shots"
var cam: Camera3D
var game: Node
var clock: Node
var dialogue: Node
var quests: Node
var lab: Node


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
	lab = root.get_node("Watches").get_node("Lab")
	root.get_node("Settings").tips = false
	dialogue.reset()
	quests.reset()
	game.needs_creator = false
	game._resume = {}
	game.riding = false
	game.items.clear()
	game.outfits = {"hero": {}}
	game.items.append("shop:shift_watch")
	game.outfit["hands"] = "shift_watch"
	clock.pulls_home = false

	# --- Earth, an autumn evening: the Shift Watch on the HUD, then checking it ---
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH)
	clock.set_earth_time(18 * 60.0 + 40.0, true)
	_player().global_position = Vector3(6.0, 1.0, 16.0)        # on the green, the gazebo behind
	_face(_player(), Vector3(6.0, 0, 30.0))
	await _frames(40)
	_make_cam()
	cam.global_position = _player().global_position + Vector3(1.5, 2.2, 5.5)
	cam.look_at(Vector3(1.0, 1.6, 8.0))
	var hud := current_scene.find_child("HUD", true, false)
	await _shot("01_the_watch_is_the_clock_earth_evening", 20)
	hud.check_watch()
	await _shot("02_checking_the_watch_on_earth", 10)
	hud.check_watch()

	cam.queue_free()
	cam = null

	# --- Galaxity, in the Shift ---
	clock.set_earth_time(0.3 * 60.0, true)
	change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN)
	clock.set_time(clock.day, 15 * 60.0, true)
	await _frames(30)
	hud = current_scene.find_child("HUD", true, false)
	await _shot("03_in_galaxity_the_shift_watch_ticks_earths_way", 10)
	hud.check_watch()
	await _shot("04_checking_it_in_the_shift", 10)
	hud.check_watch()
	game.items.append("shop:time_keeper_watch")
	game.outfit["hands"] = "time_keeper_watch"
	game.equipment_changed.emit()
	hud.check_watch()
	await _shot("05_the_time_keeper_keeps_your_own_time", 10)
	hud.check_watch()
	game.outfit["hands"] = "shift_watch"
	game.equipment_changed.emit()

	# --- The lab ---
	var built := current_scene.get_node("Rex and Dash's Lab") as Node3D
	var player := _player()
	_make_cam()
	await _view("06_rex_and_dashs_lab", built.to_global(Vector3(3, 3.5, 15)), built.to_global(Vector3(0, 2.0, 0)), 20)
	await _view("07_the_swap_o_tron", built.to_global(Vector3(1.5, 2.2, 3.5)), built.to_global(Vector3(-2.0, 1.8, -2.0)))
	await _view("08_chalkboard_and_hound_hero", built.to_global(Vector3(-1.0, 2.4, 1.5)), built.to_global(Vector3(-1.0, 2.4, -4.2)))

	# The quest: Rex at the lab, a ripple in the Market with the watch pointing at it
	dialogue.set_flag("first_night_start")
	quests.check()
	for i in 30:
		if quests.is_done("first_night"):
			break
		quests.skip("first_night")
	dialogue.set_flag("lab_start")
	quests.check()
	await _frames(4)
	_snap("rex")
	_snap("dash")
	await _frames(10)
	player.global_position = built.to_global(Vector3(0, 0.3, 7))
	_face(player, built.global_position)
	await _frames(10)
	await _view("09_rex_waits_at_the_lab", built.to_global(Vector3(5, 2.6, 11)), built.to_global(Vector3(0, 1.0, 5)), 20)
	dialogue.set_flag("lab_seen")
	dialogue.set_flag("lab_tuned")
	quests.check()
	await _frames(10)
	var ripple := current_scene.find_child("Time Ripple 1", true, false) as Node3D
	if ripple:
		player.global_position = ripple.global_position + Vector3(4.0, -1.0, 7.0)
		_face(player, ripple.global_position)
		await _frames(6)
		var pcam := player.get_viewport().get_camera_3d()
		cam.global_position = player.global_position + Vector3(2.5, 2.4, 4.5)
		cam.look_at(ripple.global_position)
		cam.make_current()
		await _shot("10_a_time_ripple_and_the_watch_pointer", 15)
		if pcam:
			pcam.make_current()
	for id in ["1", "2", "3"]:
		lab.catch(id)
	dialogue.set_flag("lab_rook")
	quests.check()
	await _frames(30)
	_snap("rex")
	_snap("rook")
	_snap("dash")
	await _frames(20)
	player.global_position = built.to_global(Vector3(2.2, 0.3, 0.6))
	_face(player, built.to_global(Vector3(2.2, 0, -1.3)))
	await _frames(10)
	await _view("11_rex_and_rook_in_the_pods", built.to_global(Vector3(4.5, 2.4, 5.0)), built.to_global(Vector3(-2.0, 1.3, -1.8)), 15)
	dialogue.set_flag("lab_lever")
	await create_timer(2.4).timeout
	await _view("12_the_swap_o_tron_charging", built.to_global(Vector3(4.5, 2.4, 5.0)), built.to_global(Vector3(-2.0, 1.3, -1.8)), 2)
	await create_timer(0.5).timeout
	await _shot("13_fzzzt", 2)
	await create_timer(1.5).timeout

	# The goggles
	game.outfit["face"] = "lab_goggles"
	game.equipment_changed.emit()
	player.global_position = built.to_global(Vector3(0, 0.3, 6))
	_face(player, built.to_global(Vector3(0, 0, 20)))
	await _frames(10)
	await _view("14_lab_goggles", player.global_position + player.global_basis.z * 2.2 + Vector3(0.6, 1.3, 0),
		player.global_position + Vector3(0, 1.0, 0), 15)
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _snap(id: String) -> void:
	for r in get_nodes_in_group("routines"):
		if r.get("character_id") == id:
			r.call("snap")


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
	quit()
